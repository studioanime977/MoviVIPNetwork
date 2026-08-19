#!/bin/bash
#==================================================
# MoviVIP Network
# Bloquear / Desbloquear Usuarios SSH
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

echo -e "${CYAN}â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—${RESET}"
echo -e "${CYAN}â•‘${MAGENTA}         ðŸ”’ BLOQUEAR / DESBLOQUEAR USUARIOS SSH ðŸ”“        ${CYAN}â•‘${RESET}"
echo -e "${CYAN}â• â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•£${RESET}"

echo -e "${GREEN}[1]${WHITE} Bloquear usuario"
echo -e "${BLUE}[2]${WHITE} Desbloquear usuario"
echo -e "${YELLOW}[3]${WHITE} Ver estado de usuarios"
echo -e "${RED}[0]${WHITE} Regresar"

echo
read -rp "$(echo -e "${GREEN}Seleccione una opciÃ³n:${RESET} ")" OP

case "$OP" in

1)

clear
echo -e "${CYAN}â•â•â•â•â•â•â•â•â•â•â•â•â•â• USUARIOS DISPONIBLES â•â•â•â•â•â•â•â•â•â•â•â•â•â•${RESET}"
echo

awk -F: '$3>=1000 && $1!="nobody"{print NR") "$1}' /etc/passwd

echo
read -rp "Usuario a bloquear: " USER

if id "$USER" &>/dev/null; then
    passwd -l "$USER" >/dev/null 2>&1
    pkill -u "$USER" >/dev/null 2>&1

    echo
    echo -e "${GREEN}âœ” Usuario ${WHITE}$USER${GREEN} bloqueado correctamente.${RESET}"
else
    echo
    echo -e "${RED}El usuario no existe.${RESET}"
fi

sleep 2
;;

2)

clear
echo -e "${CYAN}â•â•â•â•â•â•â•â•â•â•â•â•â•â• USUARIOS BLOQUEADOS â•â•â•â•â•â•â•â•â•â•â•â•â•â•${RESET}"
echo

for U in $(awk -F: '$3>=1000 && $1!="nobody"{print $1}' /etc/passwd)
do
    if passwd -S "$U" 2>/dev/null | awk '{print $2}' | grep -q "L"; then
        echo "â€¢ $U"
    fi
done

echo
read -rp "Usuario a desbloquear: " USER

if id "$USER" &>/dev/null; then
    passwd -u "$USER" >/dev/null 2>&1

    echo
    echo -e "${GREEN}âœ” Usuario ${WHITE}$USER${GREEN} desbloqueado correctamente.${RESET}"
else
    echo
    echo -e "${RED}El usuario no existe.${RESET}"
fi

sleep 2
;;

3)

clear

echo -e "${CYAN}â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—${RESET}"
echo -e "${CYAN}â•‘${MAGENTA}          ESTADO DE LOS USUARIOS             ${CYAN}â•‘${RESET}"
echo -e "${CYAN}â• â•â•â•â•â•¦â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•¦â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•£${RESET}"

printf "${CYAN}â•‘${WHITE} %-2s ${CYAN}â•‘ ${WHITE}%-18s ${CYAN}â•‘ ${WHITE}%-17s${CYAN}â•‘${RESET}\n" \
"NÂ°" "USUARIO" "ESTADO"

echo -e "${CYAN}â• â•â•â•â•â•¬â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•¬â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•£${RESET}"

i=1

for USER in $(awk -F: '$3>=1000 && $1!="nobody"{print $1}' /etc/passwd)
do

if passwd -S "$USER" 2>/dev/null | awk '{print $2}' | grep -q "L"; then
    ESTADO="${RED}Bloqueado"
else
    ESTADO="${GREEN}Activo"
fi

printf "${CYAN}â•‘${WHITE} %02d ${CYAN}â•‘ ${WHITE}%-18s ${CYAN}â•‘ %-26b${CYAN}â•‘${RESET}\n" \
"$i" "$USER" "$ESTADO"

((i++))

done

echo -e "${CYAN}â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${RESET}"

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
