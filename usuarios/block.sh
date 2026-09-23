#!/bin/bash
#==================================================
# MoviVIP Network
# Bloquear / Desbloquear Usuarios SSH
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
mv_brand_header "🔒 BLOQUEAR / DESBLOQUEAR USUARIOS SSH 🔓"
read -rp "$(echo -e "${GREEN}Seleccione una opción:${RESET} ")" OP

case "$OP" in

1)

clear
echo -e "${CYAN}══════════════ USUARIOS DISPONIBLES ══════════════${RESET}"
echo

awk -F: '$3>=1000 && $1!="nobody"{print NR") "$1}' /etc/passwd

echo
read -rp "$(trx 'Usuario a bloquear: ')" USER

if id "$USER" &>/dev/null; then
    passwd -l "$USER" >/dev/null 2>&1
    pkill -u "$USER" >/dev/null 2>&1

    echo
    echo -e "${GREEN}✔ Usuario ${WHITE}$USER${GREEN} bloqueado correctamente.${RESET}"
else
    echo
    echo -e "${RED}El usuario no existe.${RESET}"
fi

sleep 2
;;

2)

clear
echo -e "${CYAN}══════════════ USUARIOS BLOQUEADOS ══════════════${RESET}"
echo

for U in $(awk -F: '$3>=1000 && $1!="nobody"{print $1}' /etc/passwd)
do
    if passwd -S "$U" 2>/dev/null | awk '{print $2}' | grep -q "L"; then
        echo "• $U"
    fi
done

echo
read -rp "$(trx 'Usuario a desbloquear: ')" USER

if id "$USER" &>/dev/null; then
    passwd -u "$USER" >/dev/null 2>&1

    echo
    echo -e "${GREEN}✔ Usuario ${WHITE}$USER${GREEN} desbloqueado correctamente.${RESET}"
else
    echo
    echo -e "${RED}El usuario no existe.${RESET}"
fi

sleep 2
;;

3)

clear

echo -e "${CYAN}╔══════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${MAGENTA}          ESTADO DE LOS USUARIOS             ${CYAN}║${RESET}"
echo -e "${CYAN}╠════╦════════════════════╦═══════════════════╣${RESET}"

printf "${CYAN}║${WHITE} %-2s ${CYAN}║ ${WHITE}%-18s ${CYAN}║ ${WHITE}%-17s${CYAN}║${RESET}\n" \
"N°" "USUARIO" "ESTADO"

echo -e "${CYAN}╠════╬════════════════════╬═══════════════════╣${RESET}"

i=1

for USER in $(awk -F: '$3>=1000 && $1!="nobody"{print $1}' /etc/passwd)
do

if passwd -S "$USER" 2>/dev/null | awk '{print $2}' | grep -q "L"; then
    ESTADO="${RED}Bloqueado"
else
    ESTADO="${GREEN}Activo"
fi

printf "${CYAN}║${WHITE} %02d ${CYAN}║ ${WHITE}%-18s ${CYAN}║ %-26b${CYAN}║${RESET}\n" \
"$i" "$USER" "$ESTADO"

((i++))

done

echo -e "${CYAN}╚══════════════════════════════════════════════╝${RESET}"

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
