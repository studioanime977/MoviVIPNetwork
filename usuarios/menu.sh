#!/bin/bash

#==================================================
#   MoviVIP Network â€” USUARIOS SSH
#   Panel de administraciÃ³n â€” diseÃ±o premium compacto
#==================================================

BASE="/etc/movivip"

CYAN="\e[1;96m"; BLUE="\e[1;94m"; GOLD="\e[1;93m"; GREEN="\e[1;92m"
RED="\e[1;91m"; WHITE="\e[1;97m"; MAGENTA="\e[1;95m"; RESET="\e[0m"

# Cargar idioma
if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)"
fi

while true; do
clear

RAM=$(free -h | awk '/Mem:/ {print $7}')
CPU=$(top -bn1 | awk -F'id,' '/Cpu/ {split($1,a,","); printf("%.0f%%",100-a[length(a)])}')

echo -e "${CYAN}â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—${RESET}"
echo -e "${CYAN}â•‘${MAGENTA}         ðŸ” ${USER_TITLE:-MOVIVIP NETWORK â€” USUARIOS SSH} ðŸ”${RESET}${CYAN}           â•‘${RESET}"
printf "${CYAN}â•‘${WHITE} ðŸ’¾ RAM Libre ${GREEN}%-10s${WHITE} âš¡ CPU ${GREEN}%-5s${CYAN}                        â•‘${RESET}\n" "$RAM" "$CPU"
echo -e "${CYAN}â• â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•£${RESET}"
printf "${CYAN}â•‘${RESET}  ${GREEN}[01]${WHITE} ðŸ‘¤ ${USER_ADD:-Crear Usuario}   ${CYAN}â”‚${RESET}  ${GREEN}[05]${WHITE} ðŸŒ ${USER_CONNECT:-Conectados}   ${CYAN}   â•‘${RESET}\n"
printf "${CYAN}â•‘${RESET}  ${GREEN}[02]${WHITE} ðŸ—‘ ${USER_DELETE:-Eliminar}        ${CYAN}â”‚${RESET}  ${GREEN}[06]${WHITE} ðŸ“¢ ${USER_BANNER:-Banner SSH}  ${CYAN}   â•‘${RESET}\n"
printf "${CYAN}â•‘${RESET}  ${GREEN}[03]${WHITE} â™» ${USER_EDIT:-Editar/Renovar}  ${CYAN}â”‚${RESET}  ${GREEN}[07]${WHITE} ðŸ”’ ${USER_BLOCK:-Bloquear}     ${CYAN}   â•‘${RESET}\n"
printf "${CYAN}â•‘${RESET}  ${GREEN}[04]${WHITE} ðŸ“‹ ${USER_LIST:-Lista de Usuarios}${CYAN}â”‚${RESET}  ${GREEN}[08]${WHITE} ðŸ’¾ ${USER_BACKUP:-Backup}      ${CYAN}   â•‘${RESET}\n"
printf "${CYAN}â•‘${RESET}  ${GREEN}[09]${WHITE} ðŸ”‘ ${USER_ADD_HWID:-Usuario HWID}   ${CYAN}â”‚${RESET}  ${GREEN}[10]${WHITE} ðŸ‘ ${USER_LIST_HWID:-HWID List}   ${CYAN}   â•‘${RESET}\n"
printf "${CYAN}â•‘${RESET}  ${GREEN}[11]${WHITE} ðŸ”„ ${USER_CHANGE_HWID:-Cambiar HWID}   ${CYAN}â”‚${RESET}  ${GREEN}[12]${WHITE} ðŸ›¡ ${USER_BLOCK_HWID:-HWID Bloqueos}${CYAN}   â•‘${RESET}\n"
echo -e "${CYAN}â• â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•£${RESET}"
printf "${CYAN}â•‘${RESET}  ${RED}[00]${WHITE} â†© ${USER_BACK:-Volver al MenÃº Principal}${CYAN}                               â•‘${RESET}\n"
echo -e "${CYAN}â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${RESET}"
echo ""
read -rp "$(echo -e "${CYAN}âžœ ${GOLD}${USER_OPTION:-OpciÃ³n}${WHITE} âž¤ ${RESET}")" op

case "$op" in
1) bash "$BASE/usuarios/add.sh" ;;
2) bash "$BASE/usuarios/delete.sh" ;;
3) bash "$BASE/usuarios/edit.sh" ;;
4) bash "$BASE/usuarios/list.sh" ;;
5) bash "$BASE/usuarios/online.sh" ;;
6) bash "$BASE/usuarios/banner.sh" ;;
7) bash "$BASE/usuarios/block.sh" ;;
8) bash "$BASE/usuarios/backup.sh" ;;
9) bash "$BASE/usuarios/add_hwid.sh" ;;
10) bash "$BASE/usuarios/hwid_list.sh" ;;
11) bash "$BASE/usuarios/change_hwid.sh" ;;
12) bash "$BASE/usuarios/hwid_bloqueos.sh" ;;
0) exec bash "$BASE/menu.sh" ;;
*)
    echo ""
    echo -e "${RED}âœ˜ OpciÃ³n invÃ¡lida.${RESET}"
    sleep 2
;;
esac

done
