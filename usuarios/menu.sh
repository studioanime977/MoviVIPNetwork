#!/bin/bash

#==================================================
#   MoviVIP Network — USUARIOS SSH
#   Panel de administración — diseño premium compacto
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

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${MAGENTA}         🔐 ${USER_TITLE:-MOVIVIP NETWORK — USUARIOS SSH} 🔐${RESET}${CYAN}           ║${RESET}"
printf "${CYAN}║${WHITE} 💾 RAM Libre ${GREEN}%-10s${WHITE} ⚡ CPU ${GREEN}%-5s${CYAN}                        ║${RESET}\n" "$RAM" "$CPU"
echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"
printf "${CYAN}║${RESET}  ${GREEN}[01]${WHITE} 👤 ${USER_ADD:-Crear Usuario}   ${CYAN}│${RESET}  ${GREEN}[05]${WHITE} 🌐 ${USER_CONNECT:-Conectados}   ${CYAN}   ║${RESET}\n"
printf "${CYAN}║${RESET}  ${GREEN}[02]${WHITE} 🗑 ${USER_DELETE:-Eliminar}        ${CYAN}│${RESET}  ${GREEN}[06]${WHITE} 📢 ${USER_BANNER:-Banner SSH}  ${CYAN}   ║${RESET}\n"
printf "${CYAN}║${RESET}  ${GREEN}[03]${WHITE} ♻ ${USER_EDIT:-Editar/Renovar}  ${CYAN}│${RESET}  ${GREEN}[07]${WHITE} 🔒 ${USER_BLOCK:-Bloquear}     ${CYAN}   ║${RESET}\n"
printf "${CYAN}║${RESET}  ${GREEN}[04]${WHITE} 📋 ${USER_LIST:-Lista de Usuarios}${CYAN}│${RESET}  ${GREEN}[08]${WHITE} 💾 ${USER_BACKUP:-Backup}      ${CYAN}   ║${RESET}\n"
printf "${CYAN}║${RESET}  ${GREEN}[09]${WHITE} 🔑 ${USER_ADD_HWID:-Usuario HWID}   ${CYAN}│${RESET}  ${GREEN}[10]${WHITE} 👁 ${USER_LIST_HWID:-HWID List}   ${CYAN}   ║${RESET}\n"
printf "${CYAN}║${RESET}  ${GREEN}[11]${WHITE} 🔄 ${USER_CHANGE_HWID:-Cambiar HWID}   ${CYAN}│${RESET}  ${GREEN}[12]${WHITE} 🛡 ${USER_BLOCK_HWID:-HWID Bloqueos}${CYAN}   ║${RESET}\n"
echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"
printf "${CYAN}║${RESET}  ${RED}[00]${WHITE} ↩ ${USER_BACK:-Volver al Menú Principal}${CYAN}                               ║${RESET}\n"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo ""
read -rp "$(echo -e "${CYAN}➜ ${GOLD}${USER_OPTION:-Opción}${WHITE} ➤ ${RESET}")" op

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
    echo -e "${RED}✘ Opción inválida.${RESET}"
    sleep 2
;;
esac

done
