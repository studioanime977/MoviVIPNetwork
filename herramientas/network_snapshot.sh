#!/bin/bash

#=========================================================
#   MoviVIP Network - SNAPSHOT DE CONSUMO
#   Base de datos VACÍA — se genera en la primera ejecución
#   Guarda contadores /proc/net/dev + tiempo de inicio
#=========================================================

BASE="/etc/movivip"
SISTEMA="$BASE/sistema"
STATE="$SISTEMA/network_state.conf"
CONFIG="$BASE/config.conf"

mkdir -p "$SISTEMA"

# Interfaz principal: se detecta automáticamente
get_iface() {
    # Prioridad: config.conf -> ruta por defecto -> primera interfaz ethernet
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

# Leer contadores actuales (bytes RX / TX)
read_rx_tx() {
    local line
    line=$(grep "$IFACE" /proc/net/dev | tr ':' ' ')
    RX=$(echo "$line" | awk '{print $2}')
    TX=$(echo "$line" | awk '{print $10}')
    [[ -z "$RX" ]] && RX=0
    [[ -z "$TX" ]] && TX=0
}

read_rx_tx

NOW=$(date +%s)

# Si no existe la base de datos, se crea con el estado ACTUAL (punto de partida = 0 consumo)
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
    echo "init"
    exit 0
fi

# Leer estado previo
source "$STATE" 2>/dev/null

# Si cambió la interfaz, reiniciar base
if [[ "$IFACE" != "$IFACE_STATE" ]] && [[ -n "$IFACE_STATE" ]]; then
    IFACE_STATE="$IFACE"
    LAST_RX=$RX
    LAST_TX=$TX
    LAST_TS=$NOW
fi

# Delta desde el último snapshot (reinicia al reiniciar VPS: no suma tiempo muerto)
DELTA_RX=$(( RX - LAST_RX ))
DELTA_TX=$(( TX - LAST_TX ))
[[ $DELTA_RX -lt 0 ]] && DELTA_RX=0
[[ $DELTA_TX -lt 0 ]] && DELTA_TX=0

# Acumuladores
TOTAL_IN=$(( BASE_IN + DELTA_RX ))
TOTAL_OUT=$(( BASE_OUT + DELTA_TX ))

# Actualizar estado
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
