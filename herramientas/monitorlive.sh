#!/bin/bash
#==================================================
# MoviVIP Network Premium v5.7 - MONITOR LIVE
# Panel de monitoreo en tiempo real (refresco 2s):
#   · CPU / RAM / DISK / LOAD · Red sube/baja live
#   · Sesiones SSH activas (who)
#   · Usuarios online VPN (conexiones establecidas)
#   · Top procesos por CPU
# Salir: [q] o Ctrl+C
#==================================================

BASE="/etc/movivip"
CONFIG="$BASE/config.conf"
[[ -f "$CONFIG" ]] && source "$CONFIG"

CYAN="\e[1;96m"; GREEN="\e[1;92m"; RED="\e[1;91m"
GOLD="\e[1;93m"; MAGENTA="\e[1;95m"; WHITE="\e[1;97m"; GRAY="\e[1;90m"; RESET="\e[0m"

INTERVAL="${1:-2}"
[[ "$INTERVAL" =~ ^[0-9]+$ ]] || INTERVAL=2

cpu_pct(){   # %CPU global desde delta /proc/stat
    local A B T1 T2 IDLE1 IDLE2
    read -r _ T1 _ _ IDLE1 _ < <(awk '/^cpu /{print $1,$2,$3,$4,$5,$6}' /proc/stat)
    sleep "${1:-1}"
    read -r _ T2 _ _ IDLE2 _ < <(awk '/^cpu /{print $1,$2,$3,$4,$5,$6}' /proc/stat)
    echo $(( (T2-T1-IDLE2+IDLE1) * 100 / (T2-T1) ))
}

ram_pct(){
    read -r T U < <(awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{print t,t-a}' /proc/meminfo)
    echo $(( U * 100 / T ))
}

disk_pct(){
    df / | awk 'NR==2{print int($3*100/$2)}'
}

net_speed(){
    local R1 T1 R2 T2 IFACE
    IFACE=$(ip route | awk '/default/{print $5; exit}')
    [[ -z "$IFACE" ]] && IFACE="eth0"
    read -r R1 T1 < <(awk -v i="$IFACE" '$1==i":"{print $2, $10}' /proc/net/dev)
    sleep "${1:-1}"
    read -r R2 T2 < <(awk -v i="$IFACE" '$1==i":"{print $2, $10}' /proc/net/dev)
    echo "$(( (R2-R1)/1024 )) $(( (T2-T1)/1024 ))"
}

fmt_spd(){   # KB/s -> legible
    local K=$1
    (( K >= 1048576 )) && { printf "%.1f GB/s" "$(echo "scale=1;$K/1048576"|bc)" ; return; }
    (( K >= 1024 ))    && { printf "%.1f MB/s" "$(echo "scale=1;$K/1024"|bc)"; return; }
    printf "%d KB/s" "$K"
}

bar(){  # bar <pct> <ancho>
    local P=$1 W=${2:-20} F
    F=$(( P * W / 100 )); (( F > W )) && F=W; (( F < 0 )) && F=0
    local B=""
    for ((i=0;i<W;i++)); do
        if (( i < F )); then
            (( P >= 80 )) && B+="${RED}█${RESET}" || { (( P >= 60 )) && B+="${GOLD}█${RESET}" || B+="${GREEN}█${RESET}"; }
        else
            B+="${GRAY}░${RESET}"
        fi
    done
    echo -e "$B"
}

vpn_online(){
    # conexiones ESTABLISHED a puertos VPN conocidos, únicas por IP origen
    local PORTS="22 ${DROPBEAR_PORT:-90,143,109} ${ZIPVPN_PORT:-5667} ${XRAY_PORT:-443} ${HYSTERIA_PORT:-19401} 7200 7300 2100"
    local Q=""
    for P in $(echo "$PORTS" | tr ',' ' '); do
        Q+="( sport = :$P ) or "
    done
    Q="${Q%or }"
    ss -tn state established "$Q" 2>/dev/null | \
        grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | grep -v '^127\.' | sort -u | wc -l
}

trap 'tput cnorm; stty echo 2>/dev/null; exit 0' INT TERM

tput civis 2>/dev/null || true
stty -echo 2>/dev/null

while true; do
    CP=$(cpu_pct 1)
    RP=$(ram_pct)
    DP=$(disk_pct)
    read -r RX TX <<< "$(net_speed 1)"
    UP=$(uptime -p | sed 's/up //')
    LD=$(cut -d' ' -f1-3 /proc/loadavg)

    ONLINE=$(vpn_online)
    SSHN=$(who | wc -l)
    TOTAL_RAM=$(awk '/MemTotal/{printf "%d", $2/1024}' /proc/meminfo)
    USED_RAM=$(awk -v p="$RP" '/MemTotal/{printf "%d", $2/1024*p/100}' /proc/meminfo)

    clear
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${MAGENTA}        📊 MONITOR LIVE v5.7 ${GRAY}(q = salir)${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    echo -e " ${GRAY}Uptime:${RESET} ${WHITE}$UP${RESET}   ${GRAY}Load:${RESET} ${WHITE}$LD${RESET}   ${GRAY}Kernel:${RESET} ${WHITE}$(uname -r)${RESET}"
    echo ""

    printf "  ${GRAY}CPU %-4s${RESET} %b\n" "${CP}%..." "$(bar $CP)"
    printf "  ${GRAY}RAM %-4s${RESET} %b ${GRAY}(%sM/%sM)${RESET}\n" "${RP}%..." "$(bar $RP)" "$USED_RAM" "$TOTAL_RAM"
    printf "  ${GRAY}DISK%-4s${RESET} %b\n" "${DP}%..." "$(bar $DP)"
    echo ""
    echo -e "  ${GRAY}⬇ BAJA:${RESET} ${WHITE}$(fmt_spd $RX)${RESET}   ${GRAY}⬆ SUBE:${RESET} ${WHITE}$(fmt_spd $TX)${RESET}"
    echo ""
    echo -e "  ${GRAY}👥 Usuarios VPN online:${RESET} ${GREEN}$ONLINE${RESET}   ${GRAY}Sesiones SSH:${RESET} ${WHITE}$SSHN${RESET}"
    echo ""

    if (( SSHN > 0 )); then
        echo -e "  ${GOLD}── Sesiones SSH ──${RESET}"
        who | while read -r U T FROM REST; do
            [[ -n "$FROM" ]] && FROM="($FROM)"
            echo -e "   ${WHITE}$(printf '%-10s' $U)${RESET} ${GRAY}tty:${RESET}${T%-*} ${GRAY}desde${RESET} ${WHITE}$FROM${RESET}"
        done
        echo ""
    fi

    echo -e "  ${GOLD}── Top Procesos CPU ──${RESET}"
    ps aux --sort=-%cpu | awk 'NR>1 && NR<=6 {
        col="%-12.12s";
        printf "   %-8s " col "%5.1f%% %6.1fMB\n", $1, $11, $3, $6/1024 }' | \
    while IFS= read -r L; do echo -e "  ${GRAY}${L}${RESET}"; done

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    # espera con detección de tecla q (EOF también sale, evita bucle infinito)
    KEY=""; RC=0
    read -rs -n1 -t "$INTERVAL" KEY || RC=$?
    if [[ "${KEY,,}" == "q" ]] || (( RC == 1 )); then
        break
    fi
done

tput cnorm 2>/dev/null
stty echo 2>/dev/null
clear
exec bash "$BASE/herramientas/menu.sh"
