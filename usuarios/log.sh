#!/bin/bash
#==================================================
# MoviVIP Network
# Log de Conexiones SSH
#==================================================

GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
BLUE="\e[1;94m"
CYAN="\e[1;96m"
MAGENTA="\e[1;95m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"
RESET="\e[0m"

#======== CONFIG ========#
BASE="/etc/movivip"

# Cargar idioma
if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)"
fi

while true; do

clear

echo -e "${CYAN}â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—${RESET}"
echo -e "${CYAN}â•‘${MAGENTA}                    ðŸ“Š LOG DE CONEXIONES SSH ðŸ“Š                      ${CYAN}â•‘${RESET}"
echo -e "${CYAN}â• â•â•â•â•â•¦â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•¦â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•¦â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•£${RESET}"
printf "${CYAN}â•‘${WHITE} %-2s ${CYAN}â•‘ ${WHITE}%-16s ${CYAN}â•‘ ${WHITE}%-20s ${CYAN}â•‘ ${WHITE}%-20s${CYAN}â•‘${RESET}\n" \
"NÂ°" "USUARIO" "FECHA / HORA" "IP ORIGEN"
echo -e "${CYAN}â• â•â•â•â•â•¬â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•¬â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•¬â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•£${RESET}"

TOTAL=0

last -aiw | grep -vE "reboot|shutdown|wtmp begins" | while read -r USER TTY IP MES DIA HORA RESTO
do

[[ "$USER" == "" ]] && continue
[[ "$USER" == "root" ]] && continue

FECHA="$MES $DIA $HORA"

TOTAL=$((TOTAL+1))

printf "${CYAN}â•‘${WHITE} %02d ${CYAN}â•‘ ${GREEN}%-16s ${CYAN}â•‘ ${WHITE}%-20s ${CYAN}â•‘ ${BLUE}%-20s${CYAN}â•‘${RESET}\n" \
"$TOTAL" "$USER" "$FECHA" "$IP"

done

echo -e "${CYAN}â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${RESET}"

echo
echo -e "${YELLOW}Opciones disponibles:${RESET}"
echo
echo -e "${GREEN}[1]${WHITE} Ver Ãºltimos 50 registros"
echo -e "${GREEN}[2]${WHITE} Buscar usuario"
echo -e "${GREEN}[3]${WHITE} Ver Ãºltimo acceso de un usuario"
echo -e "${RED}[0]${WHITE} Salir"

echo
read -rp "$(echo -e "${GREEN}Seleccione:${RESET} ")" OP

case "$OP" in

1)
clear
echo -e "${CYAN}â•â•â•â•â•â•â•â•â•â• ÃšLTIMOS 50 REGISTROS â•â•â•â•â•â•â•â•â•â•${RESET}"
echo
last -50
echo
read -n1 -s -r -p "Presione cualquier tecla..."
;;

2)

read -rp "Usuario: " USER

clear

echo -e "${CYAN}â•â•â•â•â•â•â•â•â•â• HISTORIAL DE $USER â•â•â•â•â•â•â•â•â•â•${RESET}"
echo

last "$USER"

echo
read -n1 -s -r -p "Presione cualquier tecla..."
;;

3)

read -rp "Usuario: " USER

clear

echo -e "${CYAN}â•â•â•â•â•â•â•â•â•â• ÃšLTIMO ACCESO â•â•â•â•â•â•â•â•â•â•${RESET}"
echo

last "$USER" | head -1

echo
read -n1 -s -r -p "Presione cualquier tecla..."
;;

0)
exit
;;

*)
echo
echo -e "${RED}OpciÃ³n invÃ¡lida.${RESET}"
sleep 2
;;

esac

done
