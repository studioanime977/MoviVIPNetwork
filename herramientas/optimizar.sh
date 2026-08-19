#!/bin/bash

#=========================================================
#   MoviVIP Network - LIMPIADOR + OPTIMIZADOR EXTREMO
#   Libera RAM, limpia cachÃ©/swap/logs, red BBR extrema
#   Limpieza automÃ¡tica programable (cron) + ediciÃ³n de
#   valores de red que se reflejan al instante.
#   FIXED v2: Compatibilidad LXC â€” solo params validos
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
H1() { printf "${CYAN}â•”"; printf 'â•%.0s' $(seq 1 $W); printf "â•—${RESET}\n"; }
H2() { printf "${CYAN}â• "; printf 'â•%.0s' $(seq 1 $W); printf "â•£${RESET}\n"; }
H3() { printf "${CYAN}â•š"; printf 'â•%.0s' $(seq 1 $W); printf "â•${RESET}\n"; }

# title(): tÃ­tulo centrado con cierre de marco
title() {
    local T="$1" LEN=${#1} PAD
    PAD=$(( (W - 2 - LEN) / 2 ))
    [[ $PAD -lt 0 ]] && PAD=0
    printf "${CYAN}â•‘${GOLD}%*s%s%*s${RESET}${CYAN} â•‘${RESET}\n" "$PAD" "" "$T" "$((W - 2 - LEN - PAD))" ""
}

bar() {
    local P=$1 W2=12
    [[ $P -gt 100 ]] && P=100
    local F=$((P*W2/100)) E=$((W2-F)) C="$GREEN"
    [[ $P -gt 70 ]] && C="$YELLOW"
    [[ $P -gt 90 ]] && C="$RED"
    printf "${C}"
    for ((i=0;i<F;i++)); do printf "â–ˆ"; done
    printf "${GRAY}"
    for ((i=0;i<E;i++)); do printf "â–‘"; done
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
# Verificar si un parÃ¡metro sysctl estÃ¡ disponible
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
# NÃºcleo de limpieza (reutilizado por menÃº y por --auto)
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
# servicios ni tÃºneles activos)
# - Mata SOLO copias colgadas de scripts de gestiÃ³n
#   (online.sh/network_snapshot.sh) que llevan >5 min.
# - NO toca: sshd, dropbear, haproxy, badvpn, xray,
#   dnsdist, apt-get, ni tÃºneles con trÃ¡fico real.
# - Acumula el total en PROCS_CLEAN y devuelve cuÃ¡ntos
#   matÃ³ en esta pasada.
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
# Modo automÃ¡tico (cron) â€” sin interacciÃ³n
#=========================================================

if [[ "$1" == "--auto" ]]; then
    LIB=$(run_limpieza)
    echo "$(date '+%d/%m/%Y %H:%M:%S') â€” limpieza automÃ¡tica: +${LIB} MB liberados, ${PROCS_CLEAN} procesos innecesarios limpiados" >> "$LOG_FILE"
    exit 0
fi

#=========================================================
# Red extrema: SOLO parÃ¡metros COMPATIBLES con LXC
# NOTA: rmem_max, wmem_max, default_qdisc, swappiness,
# netdev_max_backlog NO existen o estÃ¡n bloqueados en LXC
#=========================================================

aplicar_red() {
    local RX_MB=$1 TX_MB=$2 MTU_V=$3 SWAP_V=$4
    local RX_B=$((RX_MB*1048576)) TX_B=$((TX_MB*1048576))
    local IFACE_NET
    IFACE_NET=$(get_iface)

    # Construir archivo sysctl SOLO con parÃ¡metros que funcionan
    cat >/etc/sysctl.d/99-MoviVIP.conf <<EOF
# ============ MoviVIP Network â€” OPTIMIZACION LXC ============
# Solo parametros validos para contenedores LXC
# NOTA: rmem_max, wmem_max, swappiness, default_qdisc,
# netdev_max_backlog NO existen o estan bloqueados por el host.

# Congestion TCP â€” BBR
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

    # Aplicar MTU (esto SÃ funciona en LXC)
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
    title "ðŸ§¹ MOVIVIP LIMPIADOR DE RECURSOS ðŸ§¹"
    H2
    printf "${CYAN}â•‘${WHITE}   Memoria ANTES:${RESET}${CYAN}                                            â•‘${RESET}\n"
    printf "${CYAN}â•‘${RESET}   RAM ${GRAY}Total ${WHITE}${T0}Mi${RESET}  ${GRAY}Usada ${YELLOW}${U0}Mi${RESET}  $(bar "$((U0*100/T0))")${CYAN}      â•‘${RESET}\n"
    printf "${CYAN}â•‘${RESET}   Swap ${GRAY}Usado ${WHITE}${S0:-0}Mi${RESET}${CYAN}                                         â•‘${RESET}\n"
    H2
    printf "${CYAN}â•‘${WHITE}   [1/7] Limpiando cachÃ© de RAM...${RESET}${CYAN}                       â•‘${RESET}\n"
    sync; echo 3 >/proc/sys/vm/drop_caches 2>/dev/null
    echo 0 >/proc/sys/vm/drop_caches 2>/dev/null
    sleep 0.3
    printf "${CYAN}â•‘${WHITE}   [2/7] Reciclando swap...${RESET}${CYAN}                               â•‘${RESET}\n"
    if [[ "${S0:-0}" -gt 0 ]]; then
        swapoff -a 2>/dev/null && swapon -a 2>/dev/null
    fi
    sleep 0.3
    printf "${CYAN}â•‘${WHITE}   [3/7] Limpiando procesos zombies...${RESET}${CYAN}                     â•‘${RESET}\n"
    for ppid in $(ps -eo stat=,ppid= | awk '$1=="Z"{print $2}' 2>/dev/null); do
        kill -HUP "$ppid" 2>/dev/null
    done
    sleep 0.3
    printf "${CYAN}â•‘${WHITE}   [4/7] Limpiando procesos innecesarios...${RESET}${CYAN}                â•‘${RESET}\n"
    PROC_NOW=$(limpiar_procesos)
    printf "${CYAN}â•‘${GREEN}         âœ… $PROC_NOW procesos colgados eliminados${RESET}${CYAN}           â•‘${RESET}\n"
    sleep 0.3
    printf "${CYAN}â•‘${WHITE}   [5/7] Purgando logs del sistema...${RESET}${CYAN}                      â•‘${RESET}\n"
    journalctl --vacuum-size=50M >/dev/null 2>&1
    find /var/log -name "*.gz" -mtime +2 -delete 2>/dev/null
    find /var/log -name "*.log.*" -mtime +2 -delete 2>/dev/null
    printf "${CYAN}â•‘${WHITE}   [6/7] Limpiando paquetes huÃ©rfanos...${RESET}${CYAN}                   â•‘${RESET}\n"
    pkg_clean >/dev/null 2>&1
    printf "${CYAN}â•‘${WHITE}   [7/7] Limpiando archivos temporales...${RESET}${CYAN}                  â•‘${RESET}\n"
    find /tmp /var/tmp -type f -mtime +1 -delete 2>/dev/null

    LIB=$(run_limpieza)
    local T1 U1 S1
    read -r T1 U1 S1 <<<"$(free -m | awk '/Mem:/{print $2" "$3} /Swap:/{print $6}')"
    H2
    printf "${CYAN}â•‘${WHITE}   Memoria DESPUÃ‰S:${RESET}${CYAN}${RESET}\n"
    printf "${CYAN}â•‘${RESET}   RAM ${GRAY}Total ${WHITE}${T1}Mi${RESET}  ${GRAY}Usada ${GREEN}${U1}Mi${RESET}  $(bar "$((U1*100/T1))")${CYAN}      â•‘${RESET}\n"
    printf "${CYAN}â•‘${RESET}   Swap ${GRAY}Usado ${WHITE}${S1:-0}Mi${RESET}${CYAN}                                         â•‘${RESET}\n"
    printf "${CYAN}â•‘${GREEN}   âœ… RAM LIBERADA: +${LIB} Mi  â€” el servidor quedÃ³ como pluma ðŸª¶${CYAN}â•‘${RESET}\n"
    printf "${CYAN}â•‘${GREEN}   âœ… PROCESOS LIMPIADOS: ${PROCS_CLEAN} innecesarios en total${CYAN}${RESET}        â•‘${RESET}\n"
    H3
    echo ""
    read -rp "   Presiona Enter para volver al menÃº... " _
    exec bash "$0"
}

#=========================================================
# 2) OPTIMIZAR RED (valores Ã³ptimos para LXC)
#=========================================================

optimizar_red() {
    clear
    H1
    title "ðŸš€ OPTIMIZACIÃ“N DE RED EXTREMA ðŸš€"
    H2
    printf "${CYAN}â•‘${WHITE}   Aplicando BBR + MTU 1470 + buffers 64MB...${RESET}${CYAN}   â•‘${RESET}\n"
    echo ""
    aplicar_red 64 64 1470 10
    IFACE_NET=$(get_iface)

    # Solo mostrar parÃ¡metros que REALMENTE se aplicaron
    printf "${CYAN}â•‘${RESET}   âœ… CongestiÃ³n : ${GREEN}$(sysctl -n net.ipv4.tcp_congestion_control)${RESET}${CYAN}  (BBR)      â•‘${RESET}\n"
    printf "${CYAN}â•‘${RESET}   âœ… MTU         : ${GREEN}$(cat /sys/class/net/$IFACE_NET/mtu)${RESET} ${GRAY}($IFACE_NET)${RESET}${CYAN}  â•‘${RESET}\n"

    if sysctl_available "net.ipv4.tcp_rmem"; then
        printf "${CYAN}â•‘${RESET}   âœ… Buffer RX   : ${GREEN}$(awk '{printf "%.0f MB", \$3/1048576}' /proc/sys/net/ipv4/tcp_rmem)${RESET}${CYAN}       â•‘${RESET}\n"
    fi
    if sysctl_available "net.ipv4.tcp_wmem"; then
        printf "${CYAN}â•‘${RESET}   âœ… Buffer TX   : ${GREEN}$(awk '{printf "%.0f MB", \$3/1048576}' /proc/sys/net/ipv4/tcp_wmem)${RESET}${CYAN}       â•‘${RESET}\n"
    fi

    printf "${CYAN}â•‘${RESET}   âœ… somaxconn   : ${GREEN}$(sysctl -n net.core.somaxconn)${RESET}${CYAN}            â•‘${RESET}\n"
    printf "${CYAN}â•‘${RESET}   âœ… port_range  : ${GREEN}$(sysctl -n net.ipv4.ip_local_port_range)${RESET}${CYAN}    â•‘${RESET}\n"
    printf "${CYAN}â•‘${RESET}   âœ… fin_timeout : ${GREEN}$(sysctl -n net.ipv4.tcp_fin_timeout)${RESET} seg${CYAN}         â•‘${RESET}\n"

    # Advertir sobre parÃ¡metros no disponibles en LXC
    printf "${CYAN}â•‘${RESET}   ${YELLOW}âš  ParÃ¡metros no disponibles en LXC:${RESET}${CYAN}            â•‘${RESET}\n"
    printf "${CYAN}â•‘${RESET}   ${GRAY}  rmem_max, wmem_max, swappiness, default_qdisc${RESET}${CYAN}  â•‘${RESET}\n"
    printf "${CYAN}â•‘${RESET}   ${GRAY}  (bloqueados por el host del contenedor)${RESET}${CYAN}        â•‘${RESET}\n"

    sed -i 's/^OPTIMIZAR=.*/OPTIMIZAR=ON/' "$CONFIG" 2>/dev/null
    grep -q '^OPTIMIZAR=' "$CONFIG" || echo 'OPTIMIZAR=ON' >> "$CONFIG"
    H3
    echo ""
    read -rp "   Presiona Enter para volver al menÃº... " _
    exec bash "$0"
}

#=========================================================
# 3) LIMPIEZA AUTOMÃTICA (cron)
#=========================================================

programar_limpieza() {
    clear
    H1
    title "â° LIMPIEZA AUTOMÃTICA â°"
    H2
    if [[ -f "$CRON_FILE" ]]; then
        printf "${CYAN}â•‘${GREEN}   âœ… Programada actualmente:${CYAN}              â•‘${RESET}\n"
        printf "${CYAN}â•‘${RESET}   ${WHITE}$(grep -v '^#' "$CRON_FILE" | awk '{print $1" "$2" "$3" "$4" "$5}')${RESET}${CYAN}              â•‘${RESET}\n"
    else
        printf "${CYAN}â•‘${RED}   âŒ No hay limpieza programada.${CYAN}              â•‘${RESET}\n"
    fi
    H2
    printf "${CYAN}â•‘${RESET}   ${GREEN}[1]${WHITE} Cada 30 minutos${CYAN}                              â•‘${RESET}\n"
    printf "${CYAN}â•‘${RESET}   ${GREEN}[2]${WHITE} Cada 1 hora ${GRAY}(recomendado)${RESET}${CYAN}                  â•‘${RESET}\n"
    printf "${CYAN}â•‘${RESET}   ${GREEN}[3]${WHITE} Cada 3 horas${CYAN}                                â•‘${RESET}\n"
    printf "${CYAN}â•‘${RESET}   ${GREEN}[4]${WHITE} Cada 6 horas${CYAN}                                â•‘${RESET}\n"
    printf "${CYAN}â•‘${RESET}   ${GREEN}[5]${WHITE} Cada 12 horas${CYAN}                               â•‘${RESET}\n"
    printf "${CYAN}â•‘${RESET}   ${GREEN}[6]${WHITE} Cada 24 horas${CYAN}                               â•‘${RESET}\n"
    printf "${CYAN}â•‘${RESET}   ${RED}[7]${WHITE} Desactivar limpieza automÃ¡tica${CYAN}              â•‘${RESET}\n"
    printf "${CYAN}â•‘${RESET}   ${RED}[0]${WHITE} â†© Regresar${CYAN}                                  â•‘${RESET}\n"
    H3
    echo ""
    read -rp "   â–º OpciÃ³n: " OP

    case "$OP" in
        1) SCHED="*/30 * * * *" ;;
        2) SCHED="0 * * * *" ;;
        3) SCHED="0 */3 * * *" ;;
        4) SCHED="0 */6 * * *" ;;
        5) SCHED="0 */12 * * *" ;;
        6) SCHED="0 3 * * *" ;;
        7) rm -f "$CRON_FILE"; echo ""; echo "   âŒ Limpieza automÃ¡tica desactivada."; sleep 2; exec bash "$0" ;;
        0) exec bash "$0" ;;
        *) exec bash "$0" ;;
    esac

    cat >"$CRON_FILE" <<EOF
$SCHED root /etc/movivip/herramientas/optimizar.sh --auto >> $LOG_FILE 2>&1
EOF
    chmod 644 "$CRON_FILE"
    service cron restart >/dev/null 2>&1 || systemctl restart cron >/dev/null 2>&1

    echo ""
    echo -e "   âœ… Limpieza programada: ${GREEN}${SCHED}${RESET}"
    echo -e "   ðŸ“ Log: ${GRAY}${LOG_FILE}${RESET}"
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

    # Leer valores actuales de tcp_rmem/tcp_wmem (los que SÃ funcionan)
    CUR_RX=$(awk '{print $3}' /proc/sys/net/ipv4/tcp_rmem 2>/dev/null)
    CUR_TX=$(awk '{print $3}' /proc/sys/net/ipv4/tcp_wmem 2>/dev/null)
    CUR_RX=$(( CUR_RX / 1048576 ))
    CUR_TX=$(( CUR_TX / 1048576 ))
    CUR_MTU=$(cat /sys/class/net/$IFACE_NET/mtu 2>/dev/null || echo 1470)
    [[ "$CUR_RX" -le 0 ]] && CUR_RX=64
    [[ "$CUR_TX" -le 0 ]] && CUR_TX=64

    clear
    H1
    title "âš™ï¸ EDITAR VALORES DE RED âš™ï¸"
    H2
    printf "${CYAN}â•‘${RESET}   ${WHITE}Valores actuales:${RESET}${CYAN}                                  â•‘${RESET}\n"
    printf "${CYAN}â•‘${RESET}   ${GRAY}Buffer RX/TX ${YELLOW}${CUR_RX} Mi${RESET}  ${GRAY}MTU ${YELLOW}${CUR_MTU}${RESET}${CYAN}              â•‘${RESET}\n"
    H2
    printf "${CYAN}â•‘${RESET}   ${YELLOW}âš  Este VPS es contenedor LXC${RESET}${CYAN}                      â•‘${RESET}\n"
    printf "${CYAN}â•‘${RESET}   ${GRAY}ParÃ¡metros disponibles para editar:${RESET}${CYAN}                â•‘${RESET}\n"
    printf "${CYAN}â•‘${RESET}   ${GREEN}  âœ… rmem_max â†’ via tcp_rmem (buffers TCP)${RESET}${CYAN}          â•‘${RESET}\n"
    printf "${CYAN}â•‘${RESET}   ${GREEN}  âœ… wmem_max â†’ via tcp_wmem (buffers TCP)${RESET}${CYAN}          â•‘${RESET}\n"
    printf "${CYAN}â•‘${RESET}   ${GREEN}  âœ… MTU â†’ changeable${RESET}${CYAN}                              â•‘${RESET}\n"
    printf "${CYAN}â•‘${RESET}   ${GRAY}ParÃ¡metros bloqueados por el host:${RESET}${CYAN}                â•‘${RESET}\n"
    printf "${CYAN}â•‘${RESET}   ${RED}  âŒ swappiness, default_qdisc, netdev_max_backlog${RESET}${CYAN}  â•‘${RESET}\n"
    H2
    echo ""
    read -rp "   â–º Buffer RX/TX en MB (ej. 64): " BUF_MB
    read -rp "   â–º MTU (ej. 1470): " MTU_V
    BUF_MB="${BUF_MB:-64}"; MTU_V="${MTU_V:-1470}"
    [[ "$BUF_MB" -lt 1 ]] && BUF_MB=1
    [[ "$MTU_V" -lt 576 ]] && MTU_V=576
    [[ "$MTU_V" -gt 9000 ]] && MTU_V=9000

    aplicar_red "$BUF_MB" "$BUF_MB" "$MTU_V" 10

    clear
    H1
    title "âš™ï¸ VALORES APLICADOS âš™ï¸"
    H2

    # Verificar quÃ© se aplicÃ³ realmente
    local ACTUAL_RX ACTUAL_TX ACTUAL_MTU ACTUAL_BBR ACTUAL_SOMAX
    ACTUAL_RX=$(awk '{printf "%.0f", \$3/1048576}' /proc/sys/net/ipv4/tcp_rmem 2>/dev/null)
    ACTUAL_TX=$(awk '{printf "%.0f", \$3/1048576}' /proc/sys/net/ipv4/tcp_wmem 2>/dev/null)
    ACTUAL_MTU=$(cat /sys/class/net/$IFACE_NET/mtu 2>/dev/null)
    ACTUAL_BBR=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    ACTUAL_SOMAX=$(sysctl -n net.core.somaxconn 2>/dev/null)

    printf "${CYAN}â•‘${RESET}   âœ… Buffer RX/TX: ${GREEN}${ACTUAL_RX} / ${ACTUAL_TX} MB${RESET}${CYAN}            â•‘${RESET}\n"
    printf "${CYAN}â•‘${RESET}   âœ… MTU          : ${GREEN}${ACTUAL_MTU}${RESET} ${GRAY}($IFACE_NET)${RESET}${CYAN}        â•‘${RESET}\n"
    printf "${CYAN}â•‘${RESET}   âœ… CongestiÃ³n   : ${GREEN}${ACTUAL_BBR}${RESET} ${GRAY}(BBR)${RESET}${CYAN}              â•‘${RESET}\n"
    printf "${CYAN}â•‘${RESET}   âœ… somaxconn    : ${GREEN}${ACTUAL_SOMAX}${RESET}${CYAN}                  â•‘${RESET}\n"
    printf "${CYAN}â•‘${RESET}   ${YELLOW}âš  ParÃ¡metros bloqueados por LXC:${RESET}${CYAN}                â•‘${RESET}\n"
    printf "${CYAN}â•‘${RESET}   ${GRAY}  swappiness, default_qdisc, rmem_max${RESET}${CYAN}              â•‘${RESET}\n"
    printf "${CYAN}â•‘${GREEN}   Los cambios se reflejan en todo el sistema.${CYAN}      â•‘${RESET}\n"
    H3
    echo ""
    read -rp "   Presiona Enter para volver al menÃº... " _
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
    title "ðŸ“Š RECURSOS DEL SISTEMA â€” MOVIVIP"
    H2
    printf "${CYAN}â•‘${RESET}   ${GRAY}Total ${WHITE}${T}Mi${RESET}  ${GRAY}Usada ${YELLOW}${U}Mi${RESET}  ${GRAY}Libre ${GREEN}${F}Mi${RESET}  ${GRAY}Swap ${WHITE}${S}Mi${RESET}${CYAN}        â•‘${RESET}\n"
    H2
    printf "${CYAN}â•‘${WHITE}   Top 8 procesos por consumo de RAM:${RESET}${CYAN}            â•‘${RESET}\n"
    while read -r PM PID CMD; do
        printf "${CYAN}â•‘${RESET}   %-5s %-7s %s${CYAN}                                    â•‘${RESET}\n" "$PM%" "$PID" "$CMD"
    done < <(ps -eo pmem,pid,comm --sort=-pmem | head -8)
    H3
    echo ""
    read -rp "   Presiona Enter para volver al menÃº... " _
    exec bash "$0"
}

#=========================================================
# MENÃš PRINCIPAL
#=========================================================

clear
H1
title "ðŸš€ MOVIVIP â€” OPTIMIZADOR EXTREMO ðŸš€"
H2
printf "${CYAN}â•‘${WHITE}   MantÃ©n tu VPS como una pluma ðŸª¶ aunque tengas${CYAN}  â•‘${RESET}\n"
printf "${CYAN}â•‘${WHITE}   cientos de usuarios conectados.${CYAN}                  â•‘${RESET}\n"
if is_lxc; then
    printf "${CYAN}â•‘${RESET}   ${YELLOW}âš  VPS detectado como contenedor LXC â€” params limitados${CYAN}  â•‘${RESET}\n"
fi
H2
printf "${CYAN}â•‘${RESET}   ${GREEN}[1]${WHITE} ðŸ§¹ Limpiar recursos  ${GRAY}(RAM/cachÃ©/swap/logs/procesos)${CYAN}â•‘${RESET}\n"
printf "${CYAN}â•‘${RESET}   ${GREEN}[2]${WHITE} ðŸš€ Optimizar red     ${GRAY}(BBR+MTU1470+buffers64MB)${CYAN}     â•‘${RESET}\n"
printf "${CYAN}â•‘${RESET}   ${GREEN}[3]${WHITE} â° Limpieza automÃ¡tica ${GRAY}(cada X tiempo)${CYAN}          â•‘${RESET}\n"
printf "${CYAN}â•‘${RESET}   ${GREEN}[4]${WHITE} âš™ï¸ Editar valores de red ${GRAY}(buffers/MTU)${CYAN}            â•‘${RESET}\n"
printf "${CYAN}â•‘${RESET}   ${GREEN}[5]${WHITE} ðŸ“Š Ver recursos      ${GRAY}(RAM/CPU/procesos top)${CYAN}     â•‘${RESET}\n"
printf "${CYAN}â•‘${RESET}   ${RED}[0]${WHITE} â†© Regresar${CYAN}                                    â•‘${RESET}\n"
H3
echo ""
read -rp "   â–º OpciÃ³n: " OP

case "$OP" in
    1) limpiar_recursos ;;
    2) optimizar_red ;;
    3) programar_limpieza ;;
    4) editar_red ;;
    5) ver_recursos ;;
    0) exec bash "$BASE/menu.sh" ;;
    *) exec bash "$0" ;;
esac
