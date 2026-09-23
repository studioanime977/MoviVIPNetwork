#!/bin/bash

# ── i18n shim (auto) ───────────────────────────────
if ! declare -F trx >/dev/null 2>&1; then trx() { printf '%s' "$1"; }; fi
# ─────────────────────────────────────────────────────────

BASE="/etc/movivip"


# Design System premium + navegación + idioma
[[ -f "$BASE/lib/ui.sh" ]] && source "$BASE/lib/ui.sh"
[[ -f "$BASE/lib/nav.sh" ]] && source "$BASE/lib/nav.sh" 2>/dev/null || true
if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)"
fi

CONFIG="$BASE/config.conf"

source "$CONFIG"

CYAN="${MV_CYN:-\e[1;96m}"
GREEN="${MV_GRN:-\e[1;92m}"
RED="${MV_RED:-\e[1;91m}"
MAGENTA="${MV_MAG:-\e[1;95m}"
WHITE="${MV_WHT:-\e[1;97m}"
RESET="${MV_R:-\e[0m}"

clear
mv_brand_header "REINICIAR SERVICIOS"
SERVICIOS=(
ssh
dropbear
nginx
stunnel4
badvpn
udp-custom
websocket
slowdns
zipvpn
)

for S in "${SERVICIOS[@]}"
do

if systemctl list-unit-files | grep -q "^${S}.service"; then

printf "%-15s" "$S"

systemctl restart "$S" >/dev/null 2>&1

sleep 1

if systemctl is-active --quiet "$S"; then

echo -e "${GREEN}✅ OK${RESET}"

else

echo -e "${RED}❌ ERROR${RESET}"

fi

fi

done

echo ""
read -n1 -r -p "$(trx 'Presione una tecla para regresar...')"

exec bash "$BASE/herramientas/menu.sh"
