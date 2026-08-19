#!/bin/bash

#=========================================================
#   MoviVIP Network - LIMPIADOR + OPTIMIZADOR EXTREMO
#   Libera RAM, limpia caché/swap/logs, red BBR extrema
#   Limpieza automática programable (cron) + edición de
#   valores de red que se reflejan al instante.
#   FIXED v2: Compatibilidad LXC — solo params validos
#=========================================================

BASE="/etc/movivip"
CONFIG="$BASE/config.conf"
CRON_FILE="/etc/cron.d/movivip-limpieza"
LOG_FILE="/var/log/movivip-limpieza.log"
PROCS_CLEAN=0

# Cargar funciones multi-distro
[[ -f "$BASE/functions/pkg.sh" ]] && source "$BASE/functions/pkg.sh"

[[ -f "$CONFIG" ]] && source "$CONFIG"

CYAN="\e[1;96m"; GREEN="\e[1;92m"; YELLOW="\e[1;93m"; RED="\e[1;91m"
BLUE="\e[1;94m"; WHITE="\e[1;97m"; GRAY="\e[1;90m"; GOLD="\e[1;93m"; RESET="\e[0m"

W=58
H1() { printf "${CYAN}╔"; printf '═%.0s' $(seq 1 $W); printf "╗${RESET}\n"; }
H2() { printf "${CYAN}╠"; printf '═%.0s' $(seq 1 $W); printf "╣${RESET}\n"; }
H3() { printf "${CYAN}╚"; printf '═%.0s' $(seq 1 $W); printf "╝${RESET}\n"; }

# title(): título centrado con cierre de marco
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
# Detectar si es contenedor LXC
#=========================================================
is_lxc() {
    [[ "$(systemd-detect-virt 2>/dev/null)" == "lxc" ]] && return 0
    [[ -f /.dockerenv ]] && return 0
    grep -qE 'lxc|docker' /proc/1/cgroup 2>/dev/null && return 0
    return 1
}

#=========================================================
# Verificar si un parámetro sysctl está disponible
#=========================================================
sysctl_available() {
    local KEY=$1
    local VAL
    VAL=$(sysctl -n "$KEY" 2>/dev/null)
    if [[ $? -eq 0 && -n "$VAL" ]]; then
        return 0  # disponible
    fi
    return 1  # no disponible
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

    pkg_clean >/dev/null 2>&1

    find /tmp /var/tmp -type f -mtime +1 -delete 2>/dev/null

    limpiar_procesos >/dev/null 2>&1

    read -r T1 U1 F1 S1 <<<"$(free -m | awk '/Mem:/{print $2" "$3" "$4} /Swap:/{print $6}')"
    [[ -z "$F1" ]] && F1=0
    LIB=$(( F1 - F0 ))
    [[ $LIB -lt 0 ]] && LIB=0

    echo "$LIB"
}

#=========================================================
# Limpieza de procesos innecesarios (segura: NO toca
# servicios ni túneles activos)
# - Mata SOLO copias colgadas de scripts de gestión
#   (online.sh/network_snapshot.sh) que llevan >5 min.
# - NO toca: sshd, dropbear, haproxy, badvpn, xray,
#   dnsdist, apt-get, ni túneles con tráfico real.
# - Acumula el total en PROCS_CLEAN y devuelve cuántos
#   mató en esta pasada.
#=========================================================
limpiar_procesos() {
    local MATADOS=0 PID SECS SELF=$$ PAT
    local PATTERNS=("usuarios/online.sh" "herramientas/network_snapshot.sh")
    for PAT in "${PATTERNS[@]}"; do
        while read -r PID; do
            [[ -n "$PID" ]] || continue
            [[ "$PID" == "$SELF" ]] && continue
            SECS=$(ps -o etimes= -p "$PID" 2>/dev/null | tr -d ' ')
            [[ -z "$SECS" ]] && continue
            [[ "$SECS" -lt 300 ]] && continue
            if kill -9 "$PID" 2>/dev/null; then
                MATADOS=$((MATADOS+1))
            fi
        done < <(pgrep -f "$PAT" 2>/dev/null)
    done
    PROCS_CLEAN=$((PROCS_CLEAN + MATADOS))
    echo "$MATADOS"
}

#=========================================================
# Modo automático (cron) — sin interacción
#=========================================================

if [[ "$1" == "--auto" ]]; then
    LIB=$(run_limpieza)
    echo "$(date '+%d/%m/%Y %H:%M:%S') — limpieza automática: +${LIB} MB liberados, ${PROCS_CLEAN} procesos innecesarios limpiados" >> "$LOG_FILE"
    exit 0
fi

#=========================================================
# Red extrema: SOLO parámetros COMPATIBLES con LXC
# NOTA: rmem_max, wmem_max, default_qdisc, swappiness,
# netdev_max_backlog NO existen o están bloqueados en LXC
#=========================================================

aplicar_red() {
    local RX_MB=$1 TX_MB=$2 MTU_V=$3 SWAP_V=$4
    local RX_B=$((RX_MB*1048576)) TX_B=$((TX_MB*1048576))
    local IFACE_NET
    IFACE_NET=$(get_iface)

    # Construir archivo sysctl SOLO con parámetros que funcionan
    cat >/etc/sysctl.d/99-MoviVIP.conf <<EOF
# ============ MoviVIP Network — OPTIMIZACION LXC ============
# Solo parametros validos para contenedores LXC
# NOTA: rmem_max, wmem_max, swappiness, default_qdisc,
# netdev_max_backlog NO existen o estan bloqueados por el host.

# Congestion TCP — BBR
net.ipv4.tcp_congestion_control=bbr

# Buffers TCP ($RX_MB MB / $TX_MB MB)
net.ipv4.tcp_rmem=4096 87380 $RX_B
net.ipv4.tcp_wmem=4096 87380 $TX_B
net.ipv4.tcp_mtu_probing=1
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_low_latency=1

# Colas y conexiones
net.core.somaxconn=8192
net.ipv4.tcp_max_syn_backlog=8192
net.ipv4.tcp_fin_timeout=15
net.ipv4.tcp_keepalive_time=300
net.ipv4.tcp_keepalive_intvl=15
net.ipv4.tcp_keepalive_probes=5
net.ipv4.tcp_tw_reuse=1
net.ipv4.ip_local_port_range=1024 65000
net.ipv4.tcp_timestamps=1

# Limites
fs.file-max=2097152
EOF

    # Aplicar sysctl
    sysctl --system >/dev/null 2>&1
    ulimit -n 1048576 2>/dev/null

    # Aplicar MTU (esto SÍ funciona en LXC)
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
    printf "${CYAN}║${WHITE}   [1/7] Limpiando caché de RAM...${RESET}${CYAN}                       ║${RESET}\n"
    sync; echo 3 >/proc/sys/vm/drop_caches 2>/dev/null
    echo 0 >/proc/sys/vm/drop_caches 2>/dev/null
    sleep 0.3
    printf "${CYAN}║${WHITE}   [2/7] Reciclando swap...${RESET}${CYAN}                               ║${RESET}\n"
    if [[ "${S0:-0}" -gt 0 ]]; then
        swapoff -a 2>/dev/null && swapon -a 2>/dev/null
    fi
    sleep 0.3
    printf "${CYAN}║${WHITE}   [3/7] Limpiando procesos zombies...${RESET}${CYAN}                     ║${RESET}\n"
    for ppid in $(ps -eo stat=,ppid= | awk '$1=="Z"{print $2}' 2>/dev/null); do
        kill -HUP "$ppid" 2>/dev/null
    done
    sleep 0.3
    printf "${CYAN}║${WHITE}   [4/7] Limpiando procesos innecesarios...${RESET}${CYAN}                ║${RESET}\n"
    PROC_NOW=$(limpiar_procesos)
    printf "${CYAN}║${GREEN}         ✅ $PROC_NOW procesos colgados eliminados${RESET}${CYAN}           ║${RESET}\n"
    sleep 0.3
    printf "${CYAN}║${WHITE}   [5/7] Purgando logs del sistema...${RESET}${CYAN}                      ║${RESET}\n"
    journalctl --vacuum-size=50M >/dev/null 2>&1
    find /var/log -name "*.gz" -mtime +2 -delete 2>/dev/null
    find /var/log -name "*.log.*" -mtime +2 -delete 2>/dev/null
    printf "${CYAN}║${WHITE}   [6/7] Limpiando paquetes huérfanos...${RESET}${CYAN}                   ║${RESET}\n"
    pkg_clean >/dev/null 2>&1
    printf "${CYAN}║${WHITE}   [7/7] Limpiando archivos temporales...${RESET}${CYAN}                  ║${RESET}\n"
    find /tmp /var/tmp -type f -mtime +1 -delete 2>/dev/null

    LIB=$(run_limpieza)
    local T1 U1 S1
    read -r T1 U1 S1 <<<"$(free -m | awk '/Mem:/{print $2" "$3} /Swap:/{print $6}')"
    H2
    printf "${CYAN}║${WHITE}   Memoria DESPUÉS:${RESET}${CYAN}${RESET}\n"
    printf "${CYAN}║${RESET}   RAM ${GRAY}Total ${WHITE}${T1}Mi${RESET}  ${GRAY}Usada ${GREEN}${U1}Mi${RESET}  $(bar "$((U1*100/T1))")${CYAN}      ║${RESET}\n"
    printf "${CYAN}║${RESET}   Swap ${GRAY}Usado ${WHITE}${S1:-0}Mi${RESET}${CYAN}                                         ║${RESET}\n"
    printf "${CYAN}║${GREEN}   ✅ RAM LIBERADA: +${LIB} Mi  — el servidor quedó como pluma 🪶${CYAN}║${RESET}\n"
    printf "${CYAN}║${GREEN}   ✅ PROCESOS LIMPIADOS: ${PROCS_CLEAN} innecesarios en total${CYAN}${RESET}        ║${RESET}\n"
    H3
    echo ""
    read -rp "   Presiona Enter para volver al menú... " _
    exec bash "$0"
}

#=========================================================
# 2) OPTIMIZAR RED (valores óptimos para LXC)
#=========================================================

optimizar_red() {
    clear
    H1
    title "🚀 OPTIMIZACIÓN DE RED EXTREMA 🚀"
    H2
    printf "${CYAN}║${WHITE}   Aplicando BBR + MTU 1470 + buffers 64MB...${RESET}${CYAN}   ║${RESET}\n"
    echo ""
    aplicar_red 64 64 1470 10
    IFACE_NET=$(get_iface)

    # Solo mostrar parámetros que REALMENTE se aplicaron
    printf "${CYAN}║${RESET}   ✅ Congestión : ${GREEN}$(sysctl -n net.ipv4.tcp_congestion_control)${RESET}${CYAN}  (BBR)      ║${RESET}\n"
    printf "${CYAN}║${RESET}   ✅ MTU         : ${GREEN}$(cat /sys/class/net/$IFACE_NET/mtu)${RESET} ${GRAY}($IFACE_NET)${RESET}${CYAN}  ║${RESET}\n"

    if sysctl_available "net.ipv4.tcp_rmem"; then
        printf "${CYAN}║${RESET}   ✅ Buffer RX   : ${GREEN}$(awk '{printf "%.0f MB", \$3/1048576}' /proc/sys/net/ipv4/tcp_rmem)${RESET}${CYAN}       ║${RESET}\n"
    fi
    if sysctl_available "net.ipv4.tcp_wmem"; then
        printf "${CYAN}║${RESET}   ✅ Buffer TX   : ${GREEN}$(awk '{printf "%.0f MB", \$3/1048576}' /proc/sys/net/ipv4/tcp_wmem)${RESET}${CYAN}       ║${RESET}\n"
    fi

    printf "${CYAN}║${RESET}   ✅ somaxconn   : ${GREEN}$(sysctl -n net.core.somaxconn)${RESET}${CYAN}            ║${RESET}\n"
    printf "${CYAN}║${RESET}   ✅ port_range  : ${GREEN}$(sysctl -n net.ipv4.ip_local_port_range)${RESET}${CYAN}    ║${RESET}\n"
    printf "${CYAN}║${RESET}   ✅ fin_timeout : ${GREEN}$(sysctl -n net.ipv4.tcp_fin_timeout)${RESET} seg${CYAN}         ║${RESET}\n"

    # Advertir sobre parámetros no disponibles en LXC
    printf "${CYAN}║${RESET}   ${YELLOW}⚠ Parámetros no disponibles en LXC:${RESET}${CYAN}            ║${RESET}\n"
    printf "${CYAN}║${RESET}   ${GRAY}  rmem_max, wmem_max, swappiness, default_qdisc${RESET}${CYAN}  ║${RESET}\n"
    printf "${CYAN}║${RESET}   ${GRAY}  (bloqueados por el host del contenedor)${RESET}${CYAN}        ║${RESET}\n"

    sed -i 's/^OPTIMIZAR=.*/OPTIMIZAR=ON/' "$CONFIG" 2>/dev/null
    grep -q '^OPTIMIZAR=' "$CONFIG" || echo 'OPTIMIZAR=ON' >> "$CONFIG"
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
# 4) EDITAR VALORES DE RED (solo params LXC-compatibles)
#=========================================================

editar_red() {
    local IFACE_NET
    IFACE_NET=$(get_iface)
    local CUR_RX CUR_TX CUR_MTU

    # Leer valores actuales de tcp_rmem/tcp_wmem (los que SÍ funcionan)
    CUR_RX=$(awk '{print $3}' /proc/sys/net/ipv4/tcp_rmem 2>/dev/null)
    CUR_TX=$(awk '{print $3}' /proc/sys/net/ipv4/tcp_wmem 2>/dev/null)
    CUR_RX=$(( CUR_RX / 1048576 ))
    CUR_TX=$(( CUR_TX / 1048576 ))
    CUR_MTU=$(cat /sys/class/net/$IFACE_NET/mtu 2>/dev/null || echo 1470)
    [[ "$CUR_RX" -le 0 ]] && CUR_RX=64
    [[ "$CUR_TX" -le 0 ]] && CUR_TX=64

    clear
    H1
    title "⚙️ EDITAR VALORES DE RED ⚙️"
    H2
    printf "${CYAN}║${RESET}   ${WHITE}Valores actuales:${RESET}${CYAN}                                  ║${RESET}\n"
    printf "${CYAN}║${RESET}   ${GRAY}Buffer RX/TX ${YELLOW}${CUR_RX} Mi${RESET}  ${GRAY}MTU ${YELLOW}${CUR_MTU}${RESET}${CYAN}              ║${RESET}\n"
    H2
    printf "${CYAN}║${RESET}   ${YELLOW}⚠ Este VPS es contenedor LXC${RESET}${CYAN}                      ║${RESET}\n"
    printf "${CYAN}║${RESET}   ${GRAY}Parámetros disponibles para editar:${RESET}${CYAN}                ║${RESET}\n"
    printf "${CYAN}║${RESET}   ${GREEN}  ✅ rmem_max → via tcp_rmem (buffers TCP)${RESET}${CYAN}          ║${RESET}\n"
    printf "${CYAN}║${RESET}   ${GREEN}  ✅ wmem_max → via tcp_wmem (buffers TCP)${RESET}${CYAN}          ║${RESET}\n"
    printf "${CYAN}║${RESET}   ${GREEN}  ✅ MTU → changeable${RESET}${CYAN}                              ║${RESET}\n"
    printf "${CYAN}║${RESET}   ${GRAY}Parámetros bloqueados por el host:${RESET}${CYAN}                ║${RESET}\n"
    printf "${CYAN}║${RESET}   ${RED}  ❌ swappiness, default_qdisc, netdev_max_backlog${RESET}${CYAN}  ║${RESET}\n"
    H2
    echo ""
    read -rp "   ► Buffer RX/TX en MB (ej. 64): " BUF_MB
    read -rp "   ► MTU (ej. 1470): " MTU_V
    BUF_MB="${BUF_MB:-64}"; MTU_V="${MTU_V:-1470}"
    [[ "$BUF_MB" -lt 1 ]] && BUF_MB=1
    [[ "$MTU_V" -lt 576 ]] && MTU_V=576
    [[ "$MTU_V" -gt 9000 ]] && MTU_V=9000

    aplicar_red "$BUF_MB" "$BUF_MB" "$MTU_V" 10

    clear
    H1
    title "⚙️ VALORES APLICADOS ⚙️"
    H2

    # Verificar qué se aplicó realmente
    local ACTUAL_RX ACTUAL_TX ACTUAL_MTU ACTUAL_BBR ACTUAL_SOMAX
    ACTUAL_RX=$(awk '{printf "%.0f", \$3/1048576}' /proc/sys/net/ipv4/tcp_rmem 2>/dev/null)
    ACTUAL_TX=$(awk '{printf "%.0f", \$3/1048576}' /proc/sys/net/ipv4/tcp_wmem 2>/dev/null)
    ACTUAL_MTU=$(cat /sys/class/net/$IFACE_NET/mtu 2>/dev/null)
    ACTUAL_BBR=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    ACTUAL_SOMAX=$(sysctl -n net.core.somaxconn 2>/dev/null)

    printf "${CYAN}║${RESET}   ✅ Buffer RX/TX: ${GREEN}${ACTUAL_RX} / ${ACTUAL_TX} MB${RESET}${CYAN}            ║${RESET}\n"
    printf "${CYAN}║${RESET}   ✅ MTU          : ${GREEN}${ACTUAL_MTU}${RESET} ${GRAY}($IFACE_NET)${RESET}${CYAN}        ║${RESET}\n"
    printf "${CYAN}║${RESET}   ✅ Congestión   : ${GREEN}${ACTUAL_BBR}${RESET} ${GRAY}(BBR)${RESET}${CYAN}              ║${RESET}\n"
    printf "${CYAN}║${RESET}   ✅ somaxconn    : ${GREEN}${ACTUAL_SOMAX}${RESET}${CYAN}                  ║${RESET}\n"
    printf "${CYAN}║${RESET}   ${YELLOW}⚠ Parámetros bloqueados por LXC:${RESET}${CYAN}                ║${RESET}\n"
    printf "${CYAN}║${RESET}   ${GRAY}  swappiness, default_qdisc, rmem_max${RESET}${CYAN}              ║${RESET}\n"
    printf "${CYAN}║${GREEN}   Los cambios se reflejan en todo el sistema.${CYAN}      ║${RESET}\n"
    H3
    echo ""
    read -rp "   Presiona Enter para volver al menú... " _
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
if is_lxc; then
    printf "${CYAN}║${RESET}   ${YELLOW}⚠ VPS detectado como contenedor LXC — params limitados${CYAN}  ║${RESET}\n"
fi
H2
printf "${CYAN}║${RESET}   ${GREEN}[1]${WHITE} 🧹 Limpiar recursos  ${GRAY}(RAM/caché/swap/logs/procesos)${CYAN}║${RESET}\n"
printf "${CYAN}║${RESET}   ${GREEN}[2]${WHITE} 🚀 Optimizar red     ${GRAY}(BBR+MTU1470+buffers64MB)${CYAN}     ║${RESET}\n"
printf "${CYAN}║${RESET}   ${GREEN}[3]${WHITE} ⏰ Limpieza automática ${GRAY}(cada X tiempo)${CYAN}          ║${RESET}\n"
printf "${CYAN}║${RESET}   ${GREEN}[4]${WHITE} ⚙️ Editar valores de red ${GRAY}(buffers/MTU)${CYAN}            ║${RESET}\n"
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
