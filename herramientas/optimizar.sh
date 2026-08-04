#!/bin/bash

#=========================================================
#   MoviVIP Network - LIMPIADOR + OPTIMIZADOR EXTREMO
#   Libera RAM, limpia caché/swap/logs y aplica la
#   configuración de red de máximo rendimiento
#   (BBR + FQ + MTU 1470 + buffers 64MB) para túneles
#   de juegos con muchos usuarios sin cuelgues.
#=========================================================

BASE="/etc/movivip"
CONFIG="$BASE/config.conf"

[[ -f "$CONFIG" ]] && source "$CONFIG"

CYAN="\e[1;96m"; GREEN="\e[1;92m"; YELLOW="\e[1;93m"; RED="\e[1;91m"
BLUE="\e[1;94m"; WHITE="\e[1;97m"; GRAY="\e[1;90m"; RESET="\e[0m"

W=58
H1() { printf "${CYAN}╔"; printf '═%.0s' $(seq 1 $W); printf "╗${RESET}\n"; }
H2() { printf "${CYAN}╠"; printf '═%.0s' $(seq 1 $W); printf "╣${RESET}\n"; }
H3() { printf "${CYAN}╚"; printf '═%.0s' $(seq 1 $W); printf "╝${RESET}\n"; }

mem_mb() { # total usado libre swap en MB
    local L
    L=$(free -m | awk '/Mem:/{print $2" "$3" "$4} /Swap:/{print $6}')
    echo "$L"
}

bar() {
    local P=$1 W=12
    [[ $P -gt 100 ]] && P=100
    local F=$((P*W/100)) E=$((W-F)) C="$GREEN"
    [[ $P -gt 70 ]] && C="$YELLOW"
    [[ $P -gt 90 ]] && C="$RED"
    printf "${C}"
    for ((i=0;i<F;i++)); do printf "█"; done
    printf "${GRAY}"
    for ((i=0;i<E;i++)); do printf "░"; done
    printf "${RESET} ${P}%%"
}

limpiar_recursos() {
    clear
    H1
    printf "${CYAN}║${GOLD}  🧹 MOVIVIP LIMPIADOR DE RECURSOS 🧹${CYAN}${RESET}\n"
    H1

    local T0 U0 F0 S0
    read -r T0 U0 F0 S0 <<<"$(mem_mb)"

    printf "${CYAN}║${WHITE}   Memoria ANTES:${RESET}\n"
    printf "${CYAN}║${RESET}   RAM ${GRAY}Total ${WHITE}${T0}MB${RESET}  ${GRAY}Usada ${YELLOW}${U0}MB${RESET}  $(bar "$((U0*100/T0))")${CYAN}  ║${RESET}\n"
    printf "${CYAN}║${RESET}   Swap ${GRAY}Usado ${WHITE}${S0}MB${RESET}${CYAN}                                                ║${RESET}\n"
    H2

    # 1) Limpiar page cache (dentry, inode, buffers) — NO mata procesos
    printf "${CYAN}║${WHITE}   [1/6] Limpiando caché de RAM...${RESET}                      ${CYAN}║${RESET}\n"
    sync; echo 3 >/proc/sys/vm/drop_caches 2>/dev/null
    echo 0 >/proc/sys/vm/drop_caches 2>/dev/null
    sleep 0.3

    # 2) Reciclar swap (vuelve a quedar en 0)
    printf "${CYAN}║${WHITE}   [2/6] Reciclando swap...${RESET}                              ${CYAN}║${RESET}\n"
    if [[ "$S0" -gt 0 ]]; then
        swapoff -a 2>/dev/null && swapon -a 2>/dev/null
    fi
    sleep 0.3

    # 3) Matar procesos zombies (para que no acumulen memoria)
    printf "${CYAN}║${WHITE}   [3/6] Limpiando procesos zombies...${RESET}                    ${CYAN}║${RESET}\n"
    ZB=$(ps -eo stat= | grep -c '^Z' || true)
    if [[ "$ZB" -gt 0 ]]; then
        for ppid in $(ps -eo stat=,ppid= | awk '$1=="Z"{print $2}'); do
            kill -HUP "$ppid" 2>/dev/null
        done
        sleep 0.3
    fi

    # 4) Vaciar logs del sistema (journal) manteniendo lo último
    printf "${CYAN}║${WHITE}   [4/6] Purgando logs del sistema...${RESET}                     ${CYAN}║${RESET}\n"
    journalctl --vacuum-size=50M >/dev/null 2>&1
    find /var/log -name "*.gz" -mtime +2 -delete 2>/dev/null
    find /var/log -name "*.log.*" -mtime +2 -delete 2>/dev/null

    # 5) Paquetes sobrantes
    printf "${CYAN}║${WHITE}   [5/6] Limpiando paquetes huérfanos...${RESET}                  ${CYAN}║${RESET}\n"
    apt-get -qq autoremove --purge -y >/dev/null 2>&1
    apt-get -qq clean >/dev/null 2>&1

    # 6) Basura temporal (deja lo reciente)
    printf "${CYAN}║${WHITE}   [6/6] Limpiando archivos temporales...${RESET}                 ${CYAN}║${RESET}\n"
    find /tmp /var/tmp -type f -mtime +1 -delete 2>/dev/null

    local T1 U1 F1 S1
    read -r T1 U1 F1 S1 <<<"$(mem_mb)"
    [[ -z "$F1" ]] && F1=0
    local LIB=$(( F1 - F0 ))
    [[ $LIB -lt 0 ]] && LIB=0

    H2
    printf "${CYAN}║${WHITE}   Memoria DESPUÉS:${RESET}\n"
    printf "${CYAN}║${RESET}   RAM ${GRAY}Total ${WHITE}${T1}MB${RESET}  ${GRAY}Usada ${GREEN}${U1}MB${RESET}  $(bar "$((U1*100/T1))")${CYAN}  ║${RESET}\n"
    printf "${CYAN}║${RESET}   Swap ${GRAY}Usado ${WHITE}${S1}MB${RESET}${CYAN}                                                ║${RESET}\n"
    printf "${CYAN}║${GREEN}   ✅ RAM LIBERADA: +${LIB} MB  — el servidor quedó como pluma 🪶${CYAN}║${RESET}\n"
    H3
    echo ""
    read -rp "   Presiona Enter para volver al menú... " _
    exec bash "$BASE/menu.sh"
}

optimizar_red() {
    clear
    H1
    printf "${CYAN}║${GOLD}  🚀 OPTIMIZACIÓN DE RED EXTREMA 🚀${CYAN}${RESET}\n"
    H1
    echo ""
    echo -e "${WHITE}   Aplicando BBR + FQ + MTU 1470 + buffers 64MB...${RESET}"
    echo ""

    cat >/etc/sysctl.d/99-MoviVIP.conf <<EOF
# ============ MoviVIP Network — RED EXTREMA ============
# Congestión BBR (TCP) + cola FQ (fq_codel base)
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr

# Buffers de red 64MB (para túneles de juegos, sin pérdida)
net.core.rmem_max=67108864
net.core.wmem_max=67108864
net.core.rmem_default=87380
net.core.wmem_default=87380
net.ipv4.tcp_rmem=4096 87380 67108864
net.ipv4.tcp_wmem=4096 87380 67108864
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
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_ratio=10
vm.dirty_background_ratio=2

# Límites
fs.file-max=2097152
EOF

    sysctl --system >/dev/null 2>&1
    ulimit -n 1048576 2>/dev/null

    # Aplicar MTU 1470 en la interfaz activa (óptimo para túneles de juegos)
    IFACE=$(ip route get 8.8.8.8 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')
    [[ -z "$IFACE" ]] && IFACE=$(ls /sys/class/net | grep -E '^(eth|ens|enp)' | head -n1)
    IFACE="${IFACE:-eth0}"
    ip link set dev "$IFACE" mtu 1470 2>/dev/null

    sed -i 's/^OPTIMIZAR=.*/OPTIMIZAR=ON/' "$CONFIG" 2>/dev/null
    grep -q '^OPTIMIZAR=' "$CONFIG" || echo 'OPTIMIZAR=ON' >> "$CONFIG"

    echo ""
    echo -e "   ✅ Congestión : ${GREEN}$(sysctl -n net.ipv4.tcp_congestion_control)${RESET}"
    echo -e "   ✅ Cola        : ${GREEN}$(sysctl -n net.core.default_qdisc)${RESET}"
    echo -e "   ✅ MTU         : ${GREEN}$(cat /sys/class/net/$IFACE/mtu)${RESET} (interfaz $IFACE)"
    echo -e "   ✅ Buffer RX   : ${GREEN}$(sysctl -n net.core.rmem_max | awk '{print $1/1048576" MB"}')${RESET}"
    echo -e "   ✅ Buffer TX   : ${GREEN}$(sysctl -n net.core.wmem_max | awk '{print $1/1048576" MB"}')${RESET}"
    echo ""
    read -rp "   Presiona Enter para volver al menú... " _
    exec bash "$BASE/menu.sh"
}

ver_recursos() {
    clear
    H1
    printf "${CYAN}║${GOLD}  📊 RECURSOS DEL SISTEMA — MOVIVIP${CYAN}${RESET}\n"
    H1
    echo ""
    free -h | awk 'NR==1{printf "  %-8s %10s %10s %10s %12s\n",$1,$2,$3,$4,$6} NR==2||NR==3{printf "  %-8s %10s %10s %10s %12s\n",$1,$2,$3,$4,$6}'
    echo ""
    echo -e "${WHITE}   Top 8 procesos por consumo de RAM:${RESET}"
    ps -eo pmem,pid,comm --sort=-pmem | head -9 | awk 'NR==1{printf "  %-6s %-8s %s\n",$1,$2,$3} NR>1{printf "  %-6s %-8s %s\n",$1"%",$2,$3}'
    echo ""
    read -rp "   Presiona Enter para volver al menú... " _
    exec bash "$BASE/menu.sh"
}

# =========================================================
# Menú principal
# =========================================================

clear
H1
printf "${CYAN}║${GOLD}          🚀 MOVIVIP — OPTIMIZADOR EXTREMO 🚀${CYAN}${RESET}\n"
H2
printf "${CYAN}║${WHITE}   Mantén tu VPS como una pluma 🪶 aunque tengas${CYAN}${RESET}\n"
printf "${CYAN}║${WHITE}   cientos de usuarios conectados.${CYAN}${RESET}\n"
H2
printf "${CYAN}║${RESET}   ${GREEN}[1]${WHITE} 🧹 Limpiar recursos  ${GRAY}(libera RAM/caché/swap/logs)${CYAN}   ║${RESET}\n"
printf "${CYAN}║${RESET}   ${GREEN}[2]${WHITE} 🚀 Optimizar red     ${GRAY}(BBR+FQ+MTU1470+buffers64MB)${CYAN}║${RESET}\n"
printf "${CYAN}║${RESET}   ${GREEN}[3]${WHITE} 📊 Ver recursos      ${GRAY}(RAM/CPU/procesos top)${CYAN}     ║${RESET}\n"
printf "${CYAN}║${RESET}   ${RED}[0]${WHITE} ↩ Regresar${CYAN}                                                     ║${RESET}\n"
H3
echo ""
read -rp "   ► Opción: " OP

case "$OP" in
    1) limpiar_recursos ;;
    2) optimizar_red ;;
    3) ver_recursos ;;
    0) exec bash "$BASE/menu.sh" ;;
    *) exec bash "$0" ;;
esac
