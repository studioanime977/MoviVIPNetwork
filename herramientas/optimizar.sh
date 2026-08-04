#!/bin/bash

#=========================================================
#   MoviVIP Network - LIMPIADOR + OPTIMIZADOR EXTREMO
#   Libera RAM, limpia caché/swap/logs, red BBR extrema
#   Limpieza automática programable (cron) + edición de
#   valores de red que se reflejan al instante.
#=========================================================

BASE="/etc/movivip"
CONFIG="$BASE/config.conf"
CRON_FILE="/etc/cron.d/movivip-limpieza"
LOG_FILE="/var/log/movivip-limpieza.log"

[[ -f "$CONFIG" ]] && source "$CONFIG"

CYAN="\e[1;96m"; GREEN="\e[1;92m"; YELLOW="\e[1;93m"; RED="\e[1;91m"
BLUE="\e[1;94m"; WHITE="\e[1;97m"; GRAY="\e[1;90m"; GOLD="\e[1;93m"; RESET="\e[0m"

W=58
H1() { printf "${CYAN}╔"; printf '═%.0s' $(seq 1 $W); printf "╗${RESET}\n"; }
H2() { printf "${CYAN}╠"; printf '═%.0s' $(seq 1 $W); printf "╣${RESET}\n"; }
H3() { printf "${CYAN}╚"; printf '═%.0s' $(seq 1 $W); printf "╝${RESET}\n"; }

# title(): título centrado con cierre de marco (arregla el doble ╔)
title() {
    local T="$1" LEN=${#1} PAD
    PAD=$(( (W - 2 - LEN) / 2 ))
    [[ $PAD -lt 0 ]] && PAD=0
    printf "${CYAN}║${GOLD}%*s%s%*s${RESET}${CYAN} ║${RESET}\n" "$PAD" "" "$T" "$((W - 2 - LEN - PAD))" ""
}

bar() {
    local P=$1 W2=12
    [[ $P -gt 100 ]] && P=100
    local F=$((P*W2/100)) E=$((W2-F)) C="$GREEN"
    [[ $P -gt 70 ]] && C="$YELLOW"
    [[ $P -gt 90 ]] && C="$RED"
    printf "${C}"
    for ((i=0;i<F;i++)); do printf "█"; done
    printf "${GRAY}"
    for ((i=0;i<E;i++)); do printf "░"; done
    printf "${RESET} ${P}%%"
}

get_iface() {
    local I
    I=$(ip route get 8.8.8.8 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')
    [[ -n "$I" ]] && echo "$I" && return
    I=$(ls /sys/class/net 2>/dev/null | grep -E '^(eth|ens|enp|eno)' | head -n1)
    echo "${I:-eth0}"
}

#=========================================================
# Núcleo de limpieza (reutilizado por menú y por --auto)
#=========================================================

run_limpieza() {
    local T0 U0 F0 S0 T1 U1 F1 S1 LIB
    read -r T0 U0 F0 S0 <<<"$(free -m | awk '/Mem:/{print $2" "$3" "$4} /Swap:/{print $6}')"
    [[ -z "$T0" ]] && T0=0; [[ -z "$F0" ]] && F0=0

    sync; echo 3 >/proc/sys/vm/drop_caches 2>/dev/null
    echo 0 >/proc/sys/vm/drop_caches 2>/dev/null
    sleep 0.3

    if [[ "${S0:-0}" -gt 0 ]]; then
        swapoff -a 2>/dev/null && swapon -a 2>/dev/null
    fi

    for ppid in $(ps -eo stat=,ppid= | awk '$1=="Z"{print $2}' 2>/dev/null); do
        kill -HUP "$ppid" 2>/dev/null
    done

    journalctl --vacuum-size=50M >/dev/null 2>&1
    find /var/log -name "*.gz" -mtime +2 -delete 2>/dev/null
    find /var/log -name "*.log.*" -mtime +2 -delete 2>/dev/null

    apt-get -qq autoremove --purge -y >/dev/null 2>&1
    apt-get -qq clean >/dev/null 2>&1

    find /tmp /var/tmp -type f -mtime +1 -delete 2>/dev/null

    read -r T1 U1 F1 S1 <<<"$(free -m | awk '/Mem:/{print $2" "$3" "$4} /Swap:/{print $6}')"
    [[ -z "$F1" ]] && F1=0
    LIB=$(( F1 - F0 ))
    [[ $LIB -lt 0 ]] && LIB=0

    echo "$LIB"
}

#=========================================================
# Modo automático (cron) — sin interacción
#=========================================================

if [[ "$1" == "--auto" ]]; then
    LIB=$(run_limpieza)
    echo "$(date '+%d/%m/%Y %H:%M:%S') — limpieza automática: +${LIB} MB liberados" >> "$LOG_FILE"
    exit 0
fi

#=========================================================
# Red extrema: escribir y aplicar sysctl + MTU
#=========================================================

aplicar_red() {
    local RX_MB=$1 TX_MB=$2 MTU_V=$3 SWAP_V=$4
    local RX_B=$((RX_MB*1048576)) TX_B=$((TX_MB*1048576))
    local IFACE_NET
    IFACE_NET=$(get_iface)

    cat >/etc/sysctl.d/99-MoviVIP.conf <<EOF
# ============ MoviVIP Network — RED EXTREMA ============
# Congestión BBR (TCP) + cola FQ
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr

# Buffers de red (editable: $RX_MB MB / $TX_MB MB)
net.core.rmem_max=$RX_B
net.core.wmem_max=$TX_B
net.core.rmem_default=87380
net.core.wmem_default=87380
net.ipv4.tcp_rmem=4096 87380 $RX_B
net.ipv4.tcp_wmem=4096 87380 $TX_B
net.ipv4.tcp_mtu_probing=1
net.ipv4.tcp_slow_start_after_idle=0

# Colas / conexiones masivas
net.core.somaxconn=4096
net.core.netdev_max_backlog=5000
net.ipv4.tcp_max_syn_backlog=8192
net.ipv4.tcp_fin_timeout=15
net.ipv4.tcp_keepalive_time=300
net.ipv4.tcp_keepalive_intvl=15
net.ipv4.tcp_keepalive_probes=5
net.ipv4.tcp_tw_reuse=1
net.ipv4.ip_local_port_range=1024 65000
net.ipv4.tcp_timestamps=1

# Memoria virtual — prioriza rendimiento
vm.swappiness=$SWAP_V
vm.vfs_cache_pressure=50
vm.dirty_ratio=10
vm.dirty_background_ratio=2

# Límites
fs.file-max=2097152
EOF

    sysctl --system >/dev/null 2>&1
    ulimit -n 1048576 2>/dev/null
    ip link set dev "$IFACE_NET" mtu "$MTU_V" 2>/dev/null
}

#=========================================================
# 1) LIMPIAR RECURSOS AHORA
#=========================================================

limpiar_recursos() {
    local T0 U0 S0 LIB
    read -r T0 U0 S0 <<<"$(free -m | awk '/Mem:/{print $2" "$3} /Swap:/{print $6}')"
    clear
    H1
    title "🧹 MOVIVIP LIMPIADOR DE RECURSOS 🧹"
    H2
    printf "${CYAN}║${WHITE}   Memoria ANTES:${RESET}${CYAN}                                            ║${RESET}\n"
    printf "${CYAN}║${RESET}   RAM ${GRAY}Total ${WHITE}${T0}Mi${RESET}  ${GRAY}Usada ${YELLOW}${U0}Mi${RESET}  $(bar "$((U0*100/T0))")${CYAN}      ║${RESET}\n"
    printf "${CYAN}║${RESET}   Swap ${GRAY}Usado ${WHITE}${S0:-0}Mi${RESET}${CYAN}                                         ║${RESET}\n"
    H2
    printf "${CYAN}║${WHITE}   [1/6] Limpiando caché de RAM...${RESET}${CYAN}                       ║${RESET}\n"
    sync; echo 3 >/proc/sys/vm/drop_caches 2>/dev/null
    echo 0 >/proc/sys/vm/drop_caches 2>/dev/null
    sleep 0.3
    printf "${CYAN}║${WHITE}   [2/6] Reciclando swap...${RESET}${CYAN}                               ║${RESET}\n"
    if [[ "${S0:-0}" -gt 0 ]]; then
        swapoff -a 2>/dev/null && swapon -a 2>/dev/null
    fi
    sleep 0.3
    printf "${CYAN}║${WHITE}   [3/6] Limpiando procesos zombies...${RESET}${CYAN}                     ║${RESET}\n"
    for ppid in $(ps -eo stat=,ppid= | awk '$1=="Z"{print $2}' 2>/dev/null); do
        kill -HUP "$ppid" 2>/dev/null
    done
    sleep 0.3
    printf "${CYAN}║${WHITE}   [4/6] Purgando logs del sistema...${RESET}${CYAN}                      ║${RESET}\n"
    journalctl --vacuum-size=50M >/dev/null 2>&1
    find /var/log -name "*.gz" -mtime +2 -delete 2>/dev/null
    find /var/log -name "*.log.*" -mtime +2 -delete 2>/dev/null
    printf "${CYAN}║${WHITE}   [5/6] Limpiando paquetes huérfanos...${RESET}${CYAN}                   ║${RESET}\n"
    apt-get -qq autoremove --purge -y >/dev/null 2>&1
    apt-get -qq clean >/dev/null 2>&1
    printf "${CYAN}║${WHITE}   [6/6] Limpiando archivos temporales...${RESET}${CYAN}                  ║${RESET}\n"
    find /tmp /var/tmp -type f -mtime +1 -delete 2>/dev/null

    LIB=$(run_limpieza)
    local T1 U1 S1
    read -r T1 U1 S1 <<<"$(free -m | awk '/Mem:/{print $2" "$3} /Swap:/{print $6}')"
    H2
    printf "${CYAN}║${WHITE}   Memoria DESPUÉS:${RESET}${CYAN}${RESET}\n"
    printf "${CYAN}║${RESET}   RAM ${GRAY}Total ${WHITE}${T1}Mi${RESET}  ${GRAY}Usada ${GREEN}${U1}Mi${RESET}  $(bar "$((U1*100/T1))")${CYAN}      ║${RESET}\n"
    printf "${CYAN}║${RESET}   Swap ${GRAY}Usado ${WHITE}${S1:-0}Mi${RESET}${CYAN}                                         ║${RESET}\n"
    printf "${CYAN}║${GREEN}   ✅ RAM LIBERADA: +${LIB} Mi  — el servidor quedó como pluma 🪶${CYAN}║${RESET}\n"
    H3
    echo ""
    read -rp "   Presiona Enter para volver al menú... " _
    exec bash "$0"
}

#=========================================================
# 2) OPTIMIZAR RED (valores óptimos de fábrica)
#=========================================================

optimizar_red() {
    clear
    H1
    title "🚀 OPTIMIZACIÓN DE RED EXTREMA 🚀"
    H2
    printf "${CYAN}║${WHITE}   Aplicando BBR + FQ + MTU 1470 + buffers 64MB...${RESET}${CYAN}   ║${RESET}\n"
    echo ""
    aplicar_red 64 64 1470 10
    IFACE_NET=$(get_iface)
    printf "${CYAN}║${RESET}   ✅ Congestión : ${GREEN}$(sysctl -n net.ipv4.tcp_congestion_control)${RESET}${CYAN}            ║${RESET}\n"
    printf "${CYAN}║${RESET}   ✅ Cola        : ${GREEN}$(sysctl -n net.core.default_qdisc)${RESET}${CYAN}            ║${RESET}\n"
    printf "${CYAN}║${RESET}   ✅ MTU         : ${GREEN}$(cat /sys/class/net/$IFACE_NET/mtu)${RESET} ${GRAY}($IFACE_NET)${RESET}${CYAN}  ║${RESET}\n"
    printf "${CYAN}║${RESET}   ✅ Buffer RX   : ${GREEN}$(sysctl -n net.core.rmem_max | awk '{print $1/1048576" MB"}')${RESET}${CYAN}       ║${RESET}\n"
    printf "${CYAN}║${RESET}   ✅ Buffer TX   : ${GREEN}$(sysctl -n net.core.wmem_max | awk '{print $1/1048576" MB"}')${RESET}${CYAN}       ║${RESET}\n"
    sed -i 's/^OPTIMIZAR=.*/OPTIMIZAR=ON/' "$CONFIG" 2>/dev/null
    grep -q '^OPTIMIZAR=' "$CONFIG" || echo 'OPTIMIZAR=ON' >> "$CONFIG"
    H3
    echo ""
    read -rp "   Presiona Enter para volver al menú... " _
    exec bash "$0"
}

#=========================================================
# 4) EDITAR VALORES DE RED (se aplican al instante)
#=========================================================

editar_red() {
    local IFACE_NET
    IFACE_NET=$(get_iface)
    local CUR_RX CUR_TX CUR_MTU CUR_SW
    CUR_RX=$(( $(sysctl -n net.core.rmem_max 2>/dev/null) / 1048576 ))
    CUR_TX=$(( $(sysctl -n net.core.wmem_max 2>/dev/null) / 1048576 ))
    CUR_MTU=$(cat /sys/class/net/$IFACE_NET/mtu 2>/dev/null || echo 1470)
    CUR_SW=$(sysctl -n vm.swappiness 2>/dev/null || echo 10)
    [[ "$CUR_RX" -le 0 ]] && CUR_RX=64
    [[ "$CUR_TX" -le 0 ]] && CUR_TX=64

    clear
    H1
    title "⚙️ EDITAR VALORES DE RED ⚙️"
    H2
    printf "${CYAN}║${RESET}   ${WHITE}Valores actuales:${RESET}${CYAN}                                  ║${RESET}\n"
    printf "${CYAN}║${RESET}   ${GRAY}Buffer RX ${YELLOW}${CUR_RX} Mi${RESET}  ${GRAY}Buffer TX ${YELLOW}${CUR_TX} Mi${RESET}${CYAN}              ║${RESET}\n"
    printf "${CYAN}║${RESET}   ${GRAY}MTU ${YELLOW}${CUR_MTU}${RESET}  ${GRAY}Swappiness ${YELLOW}${CUR_SW}${RESET}${CYAN}                     ║${RESET}\n"
    H2
    echo ""
    read -rp "   ► Buffer RX/TX en MB (ej. 64): " BUF_MB
    read -rp "   ► MTU (ej. 1470): " MTU_V
    read -rp "   ► Swappiness (ej. 10, 0-100): " SW_V
    BUF_MB="${BUF_MB:-64}"; MTU_V="${MTU_V:-1470}"; SW_V="${SW_V:-10}"
    [[ "$BUF_MB" -lt 1 ]] && BUF_MB=1
    [[ "$MTU_V" -lt 576 ]] && MTU_V=576
    [[ "$MTU_V" -gt 9000 ]] && MTU_V=9000
    [[ "$SW_V" -gt 100 ]] && SW_V=100

    aplicar_red "$BUF_MB" "$BUF_MB" "$MTU_V" "$SW_V"
    CUR_MTU=$(cat /sys/class/net/$IFACE_NET/mtu 2>/dev/null)
    clear
    H1
    title "⚙️ VALORES APLICADOS ⚙️"
    H2
    printf "${CYAN}║${RESET}   ✅ Buffer RX : ${GREEN}$(sysctl -n net.core.rmem_max | awk '{print $1/1048576" Mi"}')${RESET}${CYAN}      ║${RESET}\n"
    printf "${CYAN}║${RESET}   ✅ Buffer TX : ${GREEN}$(sysctl -n net.core.wmem_max | awk '{print $1/1048576" Mi"}')${RESET}${CYAN}      ║${RESET}\n"
    printf "${CYAN}║${RESET}   ✅ MTU       : ${GREEN}${CUR_MTU}${RESET} ${GRAY}($IFACE_NET)${RESET}${CYAN}      ║${RESET}\n"
    printf "${CYAN}║${RESET}   ✅ Swappiness: ${GREEN}$(sysctl -n vm.swappiness)${RESET}${CYAN}      ║${RESET}\n"
    printf "${CYAN}║${RESET}   ✅ Congestión: ${GREEN}$(sysctl -n net.ipv4.tcp_congestion_control)${RESET}${CYAN} + ${GREEN}$(sysctl -n net.core.default_qdisc)${RESET}${CYAN}║${RESET}\n"
    printf "${CYAN}║${GREEN}   Los cambios se reflejan en todo el sistema.${CYAN}      ║${RESET}\n"
    H3
    echo ""
    read -rp "   Presiona Enter para volver al menú... " _
    exec bash "$0"
}

#=========================================================
# 3) LIMPIEZA AUTOMÁTICA (cron)
#=========================================================

programar_limpieza() {
    clear
    H1
    title "⏰ LIMPIEZA AUTOMÁTICA ⏰"
    H2
    if [[ -f "$CRON_FILE" ]]; then
        printf "${CYAN}║${GREEN}   ✅ Programada actualmente:${CYAN}              ║${RESET}\n"
        printf "${CYAN}║${RESET}   ${WHITE}$(grep -v '^#' "$CRON_FILE" | awk '{print $1" "$2" "$3" "$4" "$5}')${RESET}${CYAN}              ║${RESET}\n"
    else
        printf "${CYAN}║${RED}   ❌ No hay limpieza programada.${CYAN}              ║${RESET}\n"
    fi
    H2
    printf "${CYAN}║${RESET}   ${GREEN}[1]${WHITE} Cada 30 minutos${CYAN}                              ║${RESET}\n"
    printf "${CYAN}║${RESET}   ${GREEN}[2]${WHITE} Cada 1 hora ${GRAY}(recomendado)${RESET}${CYAN}                  ║${RESET}\n"
    printf "${CYAN}║${RESET}   ${GREEN}[3]${WHITE} Cada 3 horas${CYAN}                                ║${RESET}\n"
    printf "${CYAN}║${RESET}   ${GREEN}[4]${WHITE} Cada 6 horas${CYAN}                                ║${RESET}\n"
    printf "${CYAN}║${RESET}   ${GREEN}[5]${WHITE} Cada 12 horas${CYAN}                               ║${RESET}\n"
    printf "${CYAN}║${RESET}   ${GREEN}[6]${WHITE} Cada 24 horas${CYAN}                               ║${RESET}\n"
    printf "${CYAN}║${RESET}   ${RED}[7]${WHITE} Desactivar limpieza automática${CYAN}              ║${RESET}\n"
    printf "${CYAN}║${RESET}   ${RED}[0]${WHITE} ↩ Regresar${CYAN}                                  ║${RESET}\n"
    H3
    echo ""
    read -rp "   ► Opción: " OP

    case "$OP" in
        1) SCHED="*/30 * * * *" ;;
        2) SCHED="0 * * * *" ;;
        3) SCHED="0 */3 * * *" ;;
        4) SCHED="0 */6 * * *" ;;
        5) SCHED="0 */12 * * *" ;;
        6) SCHED="0 3 * * *" ;;
        7) rm -f "$CRON_FILE"; echo ""; echo "   ❌ Limpieza automática desactivada."; sleep 2; exec bash "$0" ;;
        0) exec bash "$0" ;;
        *) exec bash "$0" ;;
    esac

    cat >"$CRON_FILE" <<EOF
$SCHED root /etc/movivip/herramientas/optimizar.sh --auto >> $LOG_FILE 2>&1
EOF
    chmod 644 "$CRON_FILE"
    service cron restart >/dev/null 2>&1 || systemctl restart cron >/dev/null 2>&1

    echo ""
    echo -e "   ✅ Limpieza programada: ${GREEN}${SCHED}${RESET}"
    echo -e "   📝 Log: ${GRAY}${LOG_FILE}${RESET}"
    sleep 2
    exec bash "$0"
}

#=========================================================
# 5) VER RECURSOS
#=========================================================

ver_recursos() {
    local T U F S
    read -r T U F S <<<"$(free -m | awk '/Mem:/{print $2" "$3" "$4} /Swap:/{print $6}')"
    [[ -z "$S" ]] && S=0
    clear
    H1
    title "📊 RECURSOS DEL SISTEMA — MOVIVIP"
    H2
    printf "${CYAN}║${RESET}   ${GRAY}Total ${WHITE}${T}Mi${RESET}  ${GRAY}Usada ${YELLOW}${U}Mi${RESET}  ${GRAY}Libre ${GREEN}${F}Mi${RESET}  ${GRAY}Swap ${WHITE}${S}Mi${RESET}${CYAN}        ║${RESET}\n"
    H2
    printf "${CYAN}║${WHITE}   Top 8 procesos por consumo de RAM:${RESET}${CYAN}            ║${RESET}\n"
    while read -r PM PID CMD; do
        printf "${CYAN}║${RESET}   %-5s %-7s %s${CYAN}                                    ║${RESET}\n" "$PM%" "$PID" "$CMD"
    done < <(ps -eo pmem,pid,comm --sort=-pmem | head -8)
    H3
    echo ""
    read -rp "   Presiona Enter para volver al menú... " _
    exec bash "$0"
}

#=========================================================
# MENÚ PRINCIPAL
#=========================================================

clear
H1
title "🚀 MOVIVIP — OPTIMIZADOR EXTREMO 🚀"
H2
printf "${CYAN}║${WHITE}   Mantén tu VPS como una pluma 🪶 aunque tengas${CYAN}  ║${RESET}\n"
printf "${CYAN}║${WHITE}   cientos de usuarios conectados.${CYAN}                  ║${RESET}\n"
H2
printf "${CYAN}║${RESET}   ${GREEN}[1]${WHITE} 🧹 Limpiar recursos  ${GRAY}(libera RAM/caché/swap/logs)${CYAN}  ║${RESET}\n"
printf "${CYAN}║${RESET}   ${GREEN}[2]${WHITE} 🚀 Optimizar red     ${GRAY}(BBR+FQ+MTU1470+buffers64MB)${CYAN}║${RESET}\n"
printf "${CYAN}║${RESET}   ${GREEN}[3]${WHITE} ⏰ Limpieza automática ${GRAY}(cada X tiempo)${CYAN}          ║${RESET}\n"
printf "${CYAN}║${RESET}   ${GREEN}[4]${WHITE} ⚙️ Editar valores de red ${GRAY}(buffers/MTU/swappiness)${CYAN}║${RESET}\n"
printf "${CYAN}║${RESET}   ${GREEN}[5]${WHITE} 📊 Ver recursos      ${GRAY}(RAM/CPU/procesos top)${CYAN}     ║${RESET}\n"
printf "${CYAN}║${RESET}   ${RED}[0]${WHITE} ↩ Regresar${CYAN}                                    ║${RESET}\n"
H3
echo ""
read -rp "   ► Opción: " OP

case "$OP" in
    1) limpiar_recursos ;;
    2) optimizar_red ;;
    3) programar_limpieza ;;
    4) editar_red ;;
    5) ver_recursos ;;
    0) exec bash "$BASE/menu.sh" ;;
    *) exec bash "$0" ;;
esac
