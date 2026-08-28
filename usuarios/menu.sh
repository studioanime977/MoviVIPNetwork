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

# Navegación con flechitas
[[ -f "$BASE/lib/nav.sh" ]] && source "$BASE/lib/nav.sh"

while true; do
clear

RAM=$(free -h | awk '/Mem:/ {print $7}')
CPU=$(top -bn1 | awk -F'id,' '/Cpu/ {split($1,a,","); printf("%.0f%%",100-a[length(a)])}')

movivip_sub_header "${USER_TITLE:-USUARIOS SSH}"

printf " 💾 RAM Libre : %s   ⚡ CPU : %s\n" "${GREEN}${RAM}${RESET}" "${GREEN}${CPU}${RESET}"

echo ""

LBL=("${USER_ADD:-Crear Usuario}" "${USER_DELETE:-Eliminar}" "${USER_EDIT:-Editar/Renovar}" "${USER_LIST:-Lista de Usuarios}" "${USER_CONNECT:-Conectados}" "${USER_BANNER:-Banner SSH}" "${USER_BLOCK:-Bloquear}" "${USER_BACKUP:-Backup}" "${USER_ADD_HWID:-Usuario HWID}" "${USER_LIST_HWID:-HWID List}" "${USER_CHANGE_HWID:-Cambiar HWID}" "${USER_BLOCK_HWID:-HWID Bloqueos}" "${USER_LIMIT_HWID:-HWID Cuota 📊}" "${USER_RENEW_HWID:-Renovar HWID ⏰}")
SEL=$(nav_pick "► ${USER_OPTION:-Opción}:" "${LBL[@]}" "↩ ${USER_BACK:-Volver al Menú Principal}") || SEL=0
[[ $SEL -eq 15 ]] && SEL=0
op="$SEL"

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
13) bash "$BASE/usuarios/hwid_limite.sh" ;;
14) bash "$BASE/usuarios/hwid_renovar.sh" ;;
0) exec bash "$BASE/menu.sh" ;;
*)
    echo ""
    echo -e "${RED}✘ Opción inválida.${RESET}"
    sleep 2
;;
esac

done
