#!/bin/bash
#==================================================
# MoviVIP Network
# Log de Conexiones SSH
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



while true; do

clear

echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${MAGENTA}                    📊 LOG DE CONEXIONES SSH 📊                      ${CYAN}║${RESET}"
echo -e "${CYAN}╠════╦══════════════════╦══════════════════════╦══════════════════════╣${RESET}"
printf "${CYAN}║${WHITE} %-2s ${CYAN}║ ${WHITE}%-16s ${CYAN}║ ${WHITE}%-20s ${CYAN}║ ${WHITE}%-20s${CYAN}║${RESET}\n" \
"N°" "USUARIO" "FECHA / HORA" "IP ORIGEN"
echo -e "${CYAN}╠════╬══════════════════╬══════════════════════╬══════════════════════╣${RESET}"

TOTAL=0

last -aiw | grep -vE "reboot|shutdown|wtmp begins" | while read -r USER TTY IP MES DIA HORA RESTO
do

[[ "$USER" == "" ]] && continue
[[ "$USER" == "root" ]] && continue

FECHA="$MES $DIA $HORA"

TOTAL=$((TOTAL+1))

printf "${CYAN}║${WHITE} %02d ${CYAN}║ ${GREEN}%-16s ${CYAN}║ ${WHITE}%-20s ${CYAN}║ ${BLUE}%-20s${CYAN}║${RESET}\n" \
"$TOTAL" "$USER" "$FECHA" "$IP"

done

echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${RESET}"

echo
echo -e "${YELLOW}Opciones disponibles:${RESET}"
echo
echo -e "${GREEN}[1]${WHITE} Ver últimos 50 registros"
echo -e "${GREEN}[2]${WHITE} Buscar usuario"
echo -e "${GREEN}[3]${WHITE} Ver último acceso de un usuario"
echo -e "${RED}[0]${WHITE} Salir"

echo
read -rp "$(echo -e "${GREEN}Seleccione:${RESET} ")" OP

case "$OP" in

1)
clear
echo -e "${CYAN}══════════ ÚLTIMOS 50 REGISTROS ══════════${RESET}"
echo
last -50
echo
read -n1 -s -r -p "$(trx 'Presione cualquier tecla...')"
;;

2)

read -rp "Usuario: " USER

clear

echo -e "${CYAN}══════════ HISTORIAL DE $USER ══════════${RESET}"
echo

last "$USER"

echo
read -n1 -s -r -p "$(trx 'Presione cualquier tecla...')"
;;

3)

read -rp "Usuario: " USER

clear

echo -e "${CYAN}══════════ ÚLTIMO ACCESO ══════════${RESET}"
echo

last "$USER" | head -1

echo
read -n1 -s -r -p "$(trx 'Presione cualquier tecla...')"
;;

0)
exit
;;

*)
echo
echo -e "${RED}Opción inválida.${RESET}"
sleep 2
;;

esac

done
