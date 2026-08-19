#!/bin/bash

BASE="/etc/movivip"
CONFIG="$BASE/config.conf"

# Cargar funciones multi-distro
[[ -f "$BASE/functions/pkg.sh" ]] && source "$BASE/functions/pkg.sh"

source "$CONFIG"

# Cargar idioma
if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)"
fi

# ðŸ”‘ GATE DE LICENCIA â€” validaciÃ³n EN VIVO contra Firebase
bash /etc/movivip/check-licencia.sh || exit 1

clear

CYAN="\e[1;96m"
GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
WHITE="\e[1;97m"
RESET="\e[0m"

while true; do

clear

echo -e "${CYAN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${RESET}"
echo -e "${WHITE}            ðŸ” OPENSSH MANAGER${RESET}"
echo -e "${CYAN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${RESET}"

if [[ "$OPENSSH" == "ON" ]]; then
    ESTADO="${GREEN}ðŸŸ¢ ACTIVO${RESET}"
else
    ESTADO="${RED}ðŸ”´ DESINSTALADO${RESET}"
fi

echo -e " Estado     : $ESTADO"
echo -e " Puerto     : 22"
echo -e " Servicio   : ssh"
echo ""

echo -e "${CYAN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${RESET}"

if [[ "$OPENSSH" == "ON" ]]; then
cat <<EOF
 [1] âž® Desinstalar OpenSSH
 [2] âž® Reiniciar Servicio
 [3] âž® Ver Estado
 [0] âž® Regresar
EOF
else
cat <<EOF
 [1] âž® Instalar OpenSSH
 [0] âž® Regresar
EOF
fi

echo -e "${CYAN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${RESET}"
read -rp " â–º OpciÃ³n: " OP

case $OP in

1)

if [[ "$OPENSSH" == "ON" ]]; then

echo ""
read -rp "Â¿Desinstalar OpenSSH? (s/n): " R

[[ "$R" != "s" ]] && continue

pkg_remove openssh-server

sed -i 's/OPENSSH=ON/OPENSSH=OFF/' "$CONFIG"

OPENSSH=OFF

echo ""
echo "âœ… OpenSSH desinstalado."

sleep 2

else

apt update

apt install openssh-server -y

systemctl enable ssh

systemctl restart ssh

sed -i 's/OPENSSH=OFF/OPENSSH=ON/' "$CONFIG"

OPENSSH=ON

echo ""
echo "âœ… OpenSSH instalado."

sleep 2

fi

;;

2)

if [[ "$OPENSSH" == "ON" ]]; then

systemctl restart ssh

echo ""
echo "âœ… Servicio reiniciado."

sleep 2

fi

;;

3)

if [[ "$OPENSSH" == "ON" ]]; then

systemctl status ssh --no-pager

echo ""

read -n1 -r -p "Presione una tecla..."

fi

;;

0)

exec bash "$BASE/protocolos/menu.sh"

;;

*)

echo ""

echo "âŒ OpciÃ³n invÃ¡lida."

sleep 2

;;

esac

done
