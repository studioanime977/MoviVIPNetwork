#!/bin/bash

#==================================================
#   MoviVIP Network — USUARIOS SSH
#   Panel de administración — diseño premium compacto
#==================================================

BASE="/etc/movivip"

# Navegación con flechitas + Design System premium
[[ -f "$BASE/lib/ui.sh" ]] && source "$BASE/lib/ui.sh"
[[ -f "$BASE/lib/nav.sh" ]] && source "$BASE/lib/nav.sh" 2>/dev/null || true

# Paleta premium ANSI-256 (banner oficial v2.1)
CYAN="${MV_CYN}"; BLUE="${MV_BLU}"; GOLD="${MV_GLD}"; GREEN="${MV_GRN}"
RED="${MV_RED}"; WHITE="${MV_WHT}"; MAGENTA="${MV_MAG}"; RESET="${MV_R}"


while true; do
clear

RAM=$(free -h | awk '/Mem:/ {print $7}')
CPU=$(top -bn1 | awk -F'id,' '/Cpu/ {split($1,a,","); printf("%.0f%%",100-a[length(a)])}')

# Marco premium: ═══ + logo 3D MOVIVIP + título + contactos + ═══
mv_brand_header "${USER_TITLE:-👥 Usuarios SSH}" "$(trx 'Administración de usuarios · conexiones')"

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
