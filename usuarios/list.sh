#!/bin/bash
#==================================================
# MoviVIP Network
# Lista de Usuarios SSH
#==================================================

GREEN="${MV_GRN:-\e[1;92m}"
RED="${MV_RED:-\e[1;91m}"
YELLOW="${MV_YLW:-\e[1;93m}"
BLUE="${MV_BLU:-\e[1;94m}"
CYAN="${MV_CYN:-\e[1;96m}"
MAGENTA="${MV_MAG:-\e[1;95m}"
WHITE="${MV_WHT:-\e[1;97m}"
GRAY="${MV_DIM:-\e[1;90m}"
RESET="${MV_R:-\e[0m}"

#======== CONFIG ========#
BASE="/etc/movivip"

# ── i18n shim (auto) ───────────────────────────────
if ! declare -F trx >/dev/null 2>&1; then trx() { printf '%s' "$1"; }; fi
# ─────────────────────────────────────────────────────────

# Design System premium + navegación + idioma
[[ -f "$BASE/lib/ui.sh" ]] && source "$BASE/lib/ui.sh"
[[ -f "$BASE/lib/nav.sh" ]] && source "$BASE/lib/nav.sh" 2>/dev/null || true
if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)"
fi



clear

echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${MAGENTA}                      📋 USUARIOS REGISTRADOS SSH 📋                      ${CYAN}║${RESET}"
echo -e "${CYAN}╠════╦══════════════════╦══════════════╦════════╦══════════════════════════╣${RESET}"
printf "${CYAN}║${WHITE} %-2s ${CYAN}║ ${WHITE}%-16s ${CYAN}║ ${WHITE}%-12s ${CYAN}║ ${WHITE}%-6s ${CYAN}║ ${WHITE}%-24s${CYAN}║${RESET}\n" \
"N°" "USUARIO" "EXPIRA" "DÍAS" "ESTADO"
echo -e "${CYAN}╠════╬══════════════════╬══════════════╬════════╬══════════════════════════╣${RESET}"

TOTAL=0
ACTIVOS=0
EXPIRADOS=0

for USER in $(awk -F: '$3>=1000 && $1!="nobody"{print $1}' /etc/passwd); do

EXPIRA=$(chage -l "$USER" | awk -F': ' '/Account expires/{print $2}')

if [[ "$EXPIRA" == "never" ]]; then
    FECHA="Nunca"
    DIAS="∞"
    ESTADO="${GREEN}Activo${RESET}"
    ((ACTIVOS++))
else
    FECHA=$(date -d "$EXPIRA" +%Y-%m-%d 2>/dev/null)

    HOY=$(date +%s)
    FIN=$(date -d "$FECHA" +%s)

    REST=$(( (FIN - HOY) / 86400 ))

    if [[ $REST -lt 0 ]]; then
        DIAS="0"
        ESTADO="${RED}Expirado${RESET}"
        ((EXPIRADOS++))
    else
        DIAS="$REST"
        ESTADO="${GREEN}Activo${RESET}"
        ((ACTIVOS++))
    fi
fi

((TOTAL++))

printf "${CYAN}║${WHITE} %02d ${CYAN}║ ${WHITE}%-16s ${CYAN}║ ${WHITE}%-12s ${CYAN}║ ${WHITE}%-6s ${CYAN}║ %-33b${CYAN}║${RESET}\n" \
"$TOTAL" "$USER" "$FECHA" "$DIAS" "$ESTADO"

done

echo -e "${CYAN}╠════╩══════════════════╩══════════════╩════════╩══════════════════════════╣${RESET}"
echo -e "${WHITE} Total Usuarios : ${GREEN}$TOTAL"
echo -e "${WHITE} Activos        : ${GREEN}$ACTIVOS"
echo -e "${WHITE} Expirados      : ${RED}$EXPIRADOS"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════════╝${RESET}"

echo
read -n1 -s -r -p "$(trx 'Presione cualquier tecla para regresar...')"
