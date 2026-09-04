#!/bin/bash

#=========================================================
#   MoviVIP Network - SNAPSHOT DE CONSUMO
#   Base de datos VACÍA — se genera en la primera ejecución
#   Guarda contadores /proc/net/dev + tiempo de inicio
#
#   DOS MODOS:
#     * Headless (cron / sin TTY) → inicia/actualiza y sale
#     * Menú (TTY) → muestra consumo acumulado + límites
#=========================================================

# ── i18n shim (auto) ───────────────────────────────
if ! declare -F trx >/dev/null 2>&1; then trx() { printf '%s' "$1"; }; fi
# ─────────────────────────────────────────────────────────
BASE="/etc/movivip"
SISTEMA="$BASE/sistema"
STATE="$SISTEMA/network_state.conf"
CONFIG="$BASE/config.conf"

CYAN="\e[1;96m"
GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
MAGENTA="\e[1;95m"
WHITE="\e[1;97m"
RESET="\e[0m"

mkdir -p "$SISTEMA"

# Interfaz principal: se detecta automáticamente
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

read_rx_tx() {
    local line
    line=$(grep "$IFACE" /proc/net/dev | tr ':' ' ')
    RX=$(echo "$line" | awk '{print $2}')
    TX=$(echo "$line" | awk '{print $10}')
    [[ -z "$RX" ]] && RX=0
    [[ -z "$TX" ]] && TX=0
}

#--------------------------------------------------
# snapshot(): itinerancia normal (init o update)
#--------------------------------------------------
snapshot() {
    read_rx_tx
    NOW=$(date +%s)

    if [[ ! -f "$STATE" ]]; then
        cat > "$STATE" <<EOF
#==============================================
# MoviVIP Network — BASE DE DATOS DE CONSUMO
# Generada automáticamente: $(date '+%d/%m/%Y %H:%M')
# Límites configúralos en config.conf:
#   NET_LIMIT_IN  (bytes) — límite de descarga
#   NET_LIMIT_OUT (bytes) — límite de subida
#==============================================
IFACE=$IFACE
BASE_IN=0
BASE_OUT=0
LAST_RX=$RX
LAST_TX=$TX
LAST_TS=$NOW
TOTAL_IN=0
TOTAL_OUT=0
EOF
        chmod 644 "$STATE"
        return
    fi

    source "$STATE" 2>/dev/null

    # ── FIX v6.4: sanear valores heredados (CRLF/basura no rompen el snapshot)
    IFACE_STATE="${IFACE_STATE//[^a-zA-Z0-9_.:-]/}"
    LAST_RX="${LAST_RX//[^0-9]/}"; LAST_RX="${LAST_RX:-0}"
    LAST_TX="${LAST_TX//[^0-9]/}"; LAST_TX="${LAST_TX:-0}"
    BASE_IN="${BASE_IN//[^0-9]/}"; BASE_IN="${BASE_IN:-0}"
    BASE_OUT="${BASE_OUT//[^0-9]/}"; BASE_OUT="${BASE_OUT:-0}"
    LAST_TS="${LAST_TS//[^0-9]/}"; LAST_TS="${LAST_TS:-$NOW}"

    if [[ "$IFACE" != "$IFACE_STATE" ]] && [[ -n "$IFACE_STATE" ]]; then
        IFACE_STATE="$IFACE"
        LAST_RX=$RX
        LAST_TX=$TX
        LAST_TS=$NOW
    fi

    DELTA_RX=$(( RX - LAST_RX ))
    DELTA_TX=$(( TX - LAST_TX ))
    [[ $DELTA_RX -lt 0 ]] && DELTA_RX=0
    [[ $DELTA_TX -lt 0 ]] && DELTA_TX=0

    TOTAL_IN=$(( BASE_IN + DELTA_RX ))
    TOTAL_OUT=$(( BASE_OUT + DELTA_TX ))

    cat > "$STATE" <<EOF
#==============================================
# MoviVIP Network — BASE DE DATOS DE CONSUMO
# Actualizada: $(date '+%d/%m/%Y %H:%M:%S')
#==============================================
IFACE=$IFACE
IFACE_STATE=$IFACE
BASE_IN=$TOTAL_IN
BASE_OUT=$TOTAL_OUT
LAST_RX=$RX
LAST_TX=$TX
LAST_TS=$NOW
TOTAL_IN=$TOTAL_IN
TOTAL_OUT=$TOTAL_OUT
EOF
    chmod 644 "$STATE"
}

#--------------------------------------------------
# MODO HEADLESS (cron / systemd)
#--------------------------------------------------
if [[ ! -t 0 ]] && [[ -z "$FORCE_MENU" ]]; then
    snapshot
    exit 0
fi

#--------------------------------------------------
# MODO MENÚ (interactivo)
#--------------------------------------------------
fmt_bytes() {
    local B=$1
    awk "BEGIN{
        if ($B >= 1073741824) printf \"%.2f GB\", $B/1073741824;
        else if ($B >= 1048576) printf \"%.2f MB\", $B/1048576;
        else if ($B >= 1024) printf \"%.2f KB\", $B/1024;
        else printf \"%d B\", $B;
    }"
}

mostrar_resumen() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${MAGENTA}           📸 SNAPSHOT DE CONSUMO${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    if [[ ! -f "$STATE" ]]; then
        snapshot
        echo -e "${YELLOW}ℹ️  Base de datos creada. El contador inicia desde ahora.${RESET}"
        echo -e "${WHITE}   Ejecuta de nuevo en unos minutos para ver consumo.${RESET}"
        echo ""
        read -n1 -r -p "$(trx 'Presione una tecla...')"
        return
    fi

    snapshot 2>/dev/null
    source "$STATE" 2>/dev/null

    echo -e "${WHITE}Interfaz monitorizada:${GREEN} $IFACE${RESET}"
    echo ""
    echo -e "  ${WHITE}⬇ Descarga acumulada: ${CYAN}$(fmt_bytes "${TOTAL_IN:-0}")${RESET}"
    echo -e "  ${WHITE}⬆ Subida acumulada:   ${CYAN}$(fmt_bytes "${TOTAL_OUT:-0}")${RESET}"
    echo ""
    echo -e "  ${WHITE}Inicio del conteo:    ${GREEN}$(date -d @"${LAST_TS:-$(date +%s)}" '+%d/%m/%Y %H:%M' 2>/dev/null || echo '-')${RESET}"
    echo ""

    # Límites desde config.conf (bytes)
    NET_LIMIT_IN=${NET_LIMIT_IN:-0}
    NET_LIMIT_OUT=${NET_LIMIT_OUT:-0}

    if (( NET_LIMIT_IN > 0 )) || (( NET_LIMIT_OUT > 0 )); then
        echo -e "${WHITE}Límites configurados:${RESET}"
        if (( NET_LIMIT_IN > 0 )); then
            PCT_IN=$(awk "BEGIN{printf \"%d\", ${TOTAL_IN:-0}/$NET_LIMIT_IN*100}")
            [[ $PCT_IN -gt 100 ]] && PCT_IN=100
            echo -e "  ${WHITE}⬇ Descarga límite:    ${YELLOW}$(fmt_bytes "$NET_LIMIT_IN")${RESET} (${GREEN}${PCT_IN}%${RESET})"
        fi
        if (( NET_LIMIT_OUT > 0 )); then
            PCT_OUT=$(awk "BEGIN{printf \"%d\", ${TOTAL_OUT:-0}/$NET_LIMIT_OUT*100}")
            [[ $PCT_OUT -gt 100 ]] && PCT_OUT=100
            echo -e "  ${WHITE}⬆ Subida límite:      ${YELLOW}$(fmt_bytes "$NET_LIMIT_OUT")${RESET} (${GREEN}${PCT_OUT}%${RESET})"
        fi
    else
        echo -e "${YELLOW}ℹ️  Sin límites configurados. Edita NET_LIMIT_IN/NET_LIMIT_OUT en config.conf.${RESET}"
    fi

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    echo "$(trx ' [1] ➮ Reiniciar contador (desde cero)')"
    echo "$(trx ' [0] ➮ Regresar')"
    echo ""
    read -rp "$(trx ' ► Opción: ')" OP

    case "$OP" in
        1)
            read -rp "$(trx ' ¿Reiniciar contador de consumo? [s/N]: ')" CONFIRM
            case "$CONFIRM" in
            s|S|y|Y)
                rm -f "$STATE"
                snapshot
                echo -e "${GREEN}✅ Contador reiniciado. Base creada desde ahora.${RESET}"
                sleep 2
            ;;
            *)
                echo -e "${YELLOW}Cancelado.${RESET}"
                sleep 1
            ;;
            esac
            mostrar_resumen
        ;;
        *)
            return
        ;;
    esac
}

mostrar_resumen

exec bash "$BASE/herramientas/menu.sh"