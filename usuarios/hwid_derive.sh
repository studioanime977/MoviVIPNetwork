#!/bin/bash
#==================================================
# MoviVIP Network Premium
# Helper central: derivar contraseÃ±a desde HWID
# Uso: hwid_derive.sh <HWID>
# Salida: contraseÃ±a derivada (14 hex chars)
# Usado por add_hwid.sh, change_hwid.sh y el bot
# (ssh_utils.py ejecuta este script vÃ­a SSH para
#  que TODAS las cuentas HWID usen la misma fÃ³rmula)
#==================================================

BASE="/etc/movivip"
CONFIG="$BASE/config.conf"

[[ -f "$CONFIG" ]] && source "$CONFIG"

# Cargar idioma
if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)"
fi

HWID="$1"

if [[ -z "$HWID" ]] || [[ -z "$HWID_SECRET" ]]; then
    echo ""
    exit 1
fi

echo -n "${HWID}|${HWID_SECRET}" | sha256sum | cut -c1-14
