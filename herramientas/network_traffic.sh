#!/bin/bash

#=========================================================
#   MoviVIP Network - CONSUMO EN TIEMPO REAL
#   Velocidad actual + consumo acumulado + límites
#   Todo desde la base de datos network_state.conf (vacía)
#=========================================================

BASE="/etc/movivip"
SISTEMA="$BASE/sistema"
STATE="$SISTEMA/network_state.conf"
CONFIG="$BASE/config.conf"

[[ -f "$CONFIG" ]] && source "$CONFIG"

# Colores
CYAN="\e[1;96m"
GREEN="\e[1;92m"
YELLOW="\e[1;93m"
RED="\e[1;91m"
BLUE="\e[1;94m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"
RESET="\e[0m"

#=========================================================
# Detectar interfaz principal
#=========================================================

get_iface() {
    if [[ -n "$NET_IFACE" ]]; then
        echo "$NET_IFACE"
        return
    fi
    local IFACE
    IFACE=$(ip route get 8.8.8.8 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')
    [[ -n "$IFACE" ]] && echo "$IFACE" && return
    IFACE=$(ls /sys/class/net | grep -E '^(eth|ens|enp|eno)' | head -n1)
    echo "${IFACE:-eth0}"
}

IFACE=$(get_iface)

#=========================================================
# Formateadores
#=========================================================

human() {
    local B=$1
    [[ -z "$B" ]] && B=0
    if [[ $B -ge 1073741824 ]]; then
        echo "$(awk "BEGIN{printf \"%.2f\", $B/1073741824}") GB"
    elif [[ $B -ge 1048576 ]]; then
        echo "$(awk "BEGIN{printf \"%.2f\", $B/1048576}") MB"
    elif [[ $B -ge 1024 ]]; then
        echo "$(awk "BEGIN{printf \"%.2f\", $B/1024}") KB"
    else
        echo "$B B"
    fi
}

speed() {
    local V=$1
    [[ -z "$V" ]] && V=0
    if [[ $V -ge 1048576 ]]; then
        echo "$(awk "BEGIN{printf \"%.2f\", $V/1048576}") MB/s"
    elif [[ $V -ge 1024 ]]; then
        echo "$(awk "BEGIN{printf \"%.2f\", $V/1024}") KB/s"
    else
        echo "$V B/s"
    fi
}

bar() {
    local USED=$1
    local LIMIT=$2
    local W=20
    if [[ $LIMIT -le 0 ]]; then
        echo -e "${GRAY}── sin límite ──${RESET}"
        return
    fi
    local P=$(( USED * 100 / LIMIT ))
    [[ $P -gt 100 ]] && P=100
    local F=$(( P * W / 100 ))
    local E=$(( W - F ))
    local COLOR="$GREEN"
    [[ $P -gt 70 ]] && COLOR="$YELLOW"
    [[ $P -gt 90 ]] && COLOR="$RED"
    printf "${COLOR}"
    for ((i=0;i<F;i++)); do printf "█"; done
    printf "${GRAY}"
    for ((i=0;i<E;i++)); do printf "░"; done
    printf "${RESET} ${P}%%"
}

read_counters() {
    local line
    line=$(grep "$IFACE" /proc/net/dev | tr ':' ' ')
    RX_N=$(echo "$line" | awk '{print $2}')
    TX_N=$(echo "$line" | awk '{print $10}')
    [[ -z "$RX_N" ]] && RX_N=0
    [[ -z "$TX_N" ]] && TX_N=0
}

#=========================================================
# Modo monitor continuo (--refresh-only)
#=========================================================

if [[ "$1" == "--refresh-only" ]]; then
    INTERVAL="${2:-2}"
    while true; do
        read_counters
        R1=$RX_N; T1=$TX_N
        sleep 1
        read_counters
        R2=$RX_N; T2=$TX_N
        S_IN=$(( R2 - R1 )); [[ $S_IN -lt 0 ]] && S_IN=0
        S_OUT=$(( T2 - T1 )); [[ $S_OUT -lt 0 ]] && S_OUT=0
        bash "$BASE/herramientas/network_snapshot.sh" >/dev/null 2>&1
        [[ -f "$STATE" ]] && source "$STATE"
        # Compatibilidad: formato ACC_RX/ACC_TX (snapshot antiguo/GitHub) → TOTAL_IN/TOTAL_OUT
        [[ -z "${TOTAL_IN:-}" && -n "${ACC_RX:-}" ]] && TOTAL_IN="$ACC_RX"
        [[ -z "${TOTAL_OUT:-}" && -n "${ACC_TX:-}" ]] && TOTAL_OUT="$ACC_TX"
        clear
        echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
        echo -e "${WHITE}   📊 CONSUMO EN TIEMPO REAL — ${GRAY}MoviVIP  (Ctrl+C para salir)${RESET}"
        echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
        echo ""
        echo -e "  ${CYAN}⬇ DESCARGA${RESET}  Vel: ${GREEN}$(speed "$S_IN")${RESET}  |  Total: ${YELLOW}$(human "${TOTAL_IN:-0}")${RESET}"
        echo -e "  ${CYAN}⬆ SUBIDA${RESET}    Vel: ${GREEN}$(speed "$S_OUT")${RESET}  |  Total: ${YELLOW}$(human "${TOTAL_OUT:-0}")${RESET}"
        echo ""
        echo -e "  ${GRAY}$(date '+%d/%m/%Y %H:%M:%S') — actualizando cada ${INTERVAL}s${RESET}"
        echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
        sleep "$INTERVAL"
    done
    exit 0
fi

#=========================================================
# Modo interactivo normal
#=========================================================

# Si no hay base de datos, crear el primer snapshot (punto de partida)
if [[ ! -f "$STATE" ]]; then
    bash "$BASE/herramientas/network_snapshot.sh" >/dev/null 2>&1
fi

[[ -f "$STATE" ]] && source "$STATE"

NET_LIMIT_IN=${NET_LIMIT_IN:-0}
NET_LIMIT_OUT=${NET_LIMIT_OUT:-0}

# Medición en tiempo real (2 lecturas separadas 1s)
read_counters
R1=$RX_N; T1=$TX_N
sleep 1
read_counters
R2=$RX_N; T2=$TX_N

SPD_IN=$(( R2 - R1 ))
SPD_OUT=$(( T2 - T1 ))
[[ $SPD_IN -lt 0 ]] && SPD_IN=0
[[ $SPD_OUT -lt 0 ]] && SPD_OUT=0

# Actualizar acumulados con el snapshot
bash "$BASE/herramientas/network_snapshot.sh" >/dev/null 2>&1
source "$STATE" 2>/dev/null

# Compatibilidad: formato ACC_RX/ACC_TX (snapshot antiguo/GitHub) → TOTAL_IN/TOTAL_OUT
[[ -z "${TOTAL_IN:-}" && -n "${ACC_RX:-}" ]] && TOTAL_IN="$ACC_RX"
[[ -z "${TOTAL_OUT:-}" && -n "${ACC_TX:-}" ]] && TOTAL_OUT="$ACC_TX"

TOTAL_IN=${TOTAL_IN:-0}
TOTAL_OUT=${TOTAL_OUT:-0}

#=========================================================
# Pantalla
#=========================================================

clear
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
echo -e "${WHITE}        📊 CONSUMO DE RED EN TIEMPO REAL — ${GRAY}MoviVIP${RESET}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
echo ""
echo -e "${GRAY}   Interfaz   :${WHITE} $IFACE"
echo -e "${GRAY}   Actualizado:${WHITE} $(date '+%d/%m/%Y %H:%M:%S')"
echo ""

echo -e "${BLUE}┌────────────── ⬇ DESCARGA (RX) ──────────────┐${RESET}"
echo -e "${WHITE}│ ${CYAN}Velocidad   ${WHITE}: ${GREEN}$(speed "$SPD_IN")${RESET}"
echo -e "${WHITE}│ ${CYAN}Consumido   ${WHITE}: ${YELLOW}$(human "$TOTAL_IN")${RESET}"
echo -e "${WHITE}│ ${CYAN}Límite      ${WHITE}: $( [[ $NET_LIMIT_IN -gt 0 ]] && echo "${RED}$(human "$NET_LIMIT_IN")${RESET}" || echo "${GRAY}sin límite${RESET}" )"
echo -e -n "${WHITE}│ ${CYAN}Uso         ${WHITE}: "; bar "$TOTAL_IN" "$NET_LIMIT_IN"; echo ""
echo -e "${BLUE}└──────────────────────────────────────────────┘${RESET}"

echo ""

echo -e "${BLUE}┌────────────── ⬆ SUBIDA (TX) ────────────────┐${RESET}"
echo -e "${WHITE}│ ${CYAN}Velocidad   ${WHITE}: ${GREEN}$(speed "$SPD_OUT")${RESET}"
echo -e "${WHITE}│ ${CYAN}Consumido   ${WHITE}: ${YELLOW}$(human "$TOTAL_OUT")${RESET}"
echo -e "${WHITE}│ ${CYAN}Límite      ${WHITE}: $( [[ $NET_LIMIT_OUT -gt 0 ]] && echo "${RED}$(human "$NET_LIMIT_OUT")${RESET}" || echo "${GRAY}sin límite${RESET}" )"
echo -e -n "${WHITE}│ ${CYAN}Uso         ${WHITE}: "; bar "$TOTAL_OUT" "$NET_LIMIT_OUT"; echo ""
echo -e "${BLUE}└──────────────────────────────────────────────┘${RESET}"

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
echo -e "${YELLOW} [1]${WHITE} 🔄 Refrescar (modo continuo)"
echo -e "${YELLOW} [2]${WHITE} 🗑 Reiniciar contador de consumo"
echo -e "${YELLOW} [3]${WHITE} ⚙️ Configurar límites (GB)"
echo -e "${YELLOW} [0]${WHITE} ↩ Volver"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
echo ""
read -rp " ► Opción: " OP

case "$OP" in

1)
    # Modo continuo: monitor en vivo hasta Ctrl+C
    bash "$BASE/herramientas/network_traffic.sh" --refresh-only 2
;;

2)
    # Reiniciar base de datos: nuevo punto de partida
    rm -f "$STATE"
    bash "$BASE/herramientas/network_snapshot.sh" >/dev/null 2>&1
    echo -e "${GREEN}✅ Contador reiniciado${RESET}"
    sleep 2
    exec bash "$BASE/herramientas/network_traffic.sh"
;;

3)
    echo ""
    read -rp " Límite de DESCARGA en GB (0 = sin límite): " LIM_IN
    read -rp " Límite de SUBIDA en GB (0 = sin límite): " LIM_OUT
    GB=1073741824
    NEW_IN=$(( LIM_IN * GB ))
    NEW_OUT=$(( LIM_OUT * GB ))
    if [[ -f "$CONFIG" ]]; then
        grep -q "^NET_LIMIT_IN=" "$CONFIG" && sed -i "s/^NET_LIMIT_IN=.*/NET_LIMIT_IN=$NEW_IN/" "$CONFIG" || echo "NET_LIMIT_IN=$NEW_IN" >> "$CONFIG"
        grep -q "^NET_LIMIT_OUT=" "$CONFIG" && sed -i "s/^NET_LIMIT_OUT=.*/NET_LIMIT_OUT=$NEW_OUT/" "$CONFIG" || echo "NET_LIMIT_OUT=$NEW_OUT" >> "$CONFIG"
    else
        echo "NET_LIMIT_IN=$NEW_IN" >> "$CONFIG"
        echo "NET_LIMIT_OUT=$NEW_OUT" >> "$CONFIG"
    fi
    echo -e "${GREEN}✅ Límites guardados (Descarga: $LIM_IN GB | Subida: $LIM_OUT GB)${RESET}"
    sleep 2
    exec bash "$BASE/herramientas/network_traffic.sh"
;;

0)
    exec bash "$BASE/herramientas/menu.sh"
;;

*)
    exec bash "$BASE/herramientas/network_traffic.sh"
;;

esac
