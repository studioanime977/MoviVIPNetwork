#!/bin/bash
#==================================================
# MoviVIP Network Premium
# Helper central: derivar contraseña desde HWID
# Uso: hwid_derive.sh <HWID>
# Salida: contraseña derivada (14 hex chars)
# Usado por add_hwid.sh, change_hwid.sh y el bot
# (ssh_utils.py ejecuta este script vía SSH para
#  que TODAS las cuentas HWID usen la misma fórmula)
#==================================================

BASE="/etc/movivip"
CONFIG="$BASE/config.conf"

[[ -f "$CONFIG" ]] && source "$CONFIG"

HWID="$1"

if [[ -z "$HWID" ]] || [[ -z "$HWID_SECRET" ]]; then
    echo ""
    exit 1
fi

echo -n "${HWID}|${HWID_SECRET}" | sha256sum | cut -c1-14
