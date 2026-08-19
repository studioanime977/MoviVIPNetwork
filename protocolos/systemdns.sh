#!/bin/bash

BASE="/etc/movivip"
CONFIG="$BASE/config.conf"

source "$CONFIG"

# Cargar idioma
if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)"
fi

# ðŸ”‘ GATE DE LICENCIA â€” validaciÃ³n EN VIVO contra Firebase
bash /etc/movivip/check-licencia.sh || exit 1

CYAN="\e[1;96m"
GREEN="\e[1;92m"
RED="\e[1;91m"
WHITE="\e[1;97m"
RESET="\e[0m"

while true; do

clear

echo -e "${CYAN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${RESET}"
echo -e "${WHITE}          ðŸŒ SYSTEM DNS MANAGER${RESET}"
echo -e "${CYAN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${RESET}"

if [[ "$SYSTEMDNS" == "ON" ]]; then
    ESTADO="${GREEN}ðŸŸ¢ ACTIVO${RESET}"
else
    ESTADO="${RED}ðŸ”´ DESINSTALADO${RESET}"
fi

echo -e " Estado     : $ESTADO"
echo -e " Puerto     : 53"
echo -e " Servicio   : systemd-resolved"

echo ""
echo -e "${CYAN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${RESET}"

if [[ "$SYSTEMDNS" == "ON" ]]; then
cat <<EOF
 [1] âž® Desinstalar System DNS
 [2] âž® Reiniciar Servicio
 [3] âž® Ver Estado
 [0] âž® Regresar
EOF
else
cat <<EOF
 [1] âž® Instalar System DNS
 [0] âž® Regresar
EOF
fi

echo -e "${CYAN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${RESET}"

read -rp " â–º OpciÃ³n: " OP

case "$OP" in

1)

if [[ "$SYSTEMDNS" == "ON" ]]; then

read -rp "Â¿Desinstalar System DNS? (s/n): " R
[[ "$R" != "s" ]] && continue

systemctl stop systemd-resolved
systemctl disable systemd-resolved

sed -i 's/SYSTEMDNS=ON/SYSTEMDNS=OFF/' "$CONFIG"
SYSTEMDNS=OFF

echo ""
echo "âœ… System DNS desinstalado."

sleep 2

else

systemctl enable systemd-resolved
systemctl restart systemd-resolved

sed -i 's/SYSTEMDNS=OFF/SYSTEMDNS=ON/' "$CONFIG"
SYSTEMDNS=ON

echo ""
echo "âœ… System DNS instalado."

sleep 2

fi

;;

2)

if [[ "$SYSTEMDNS" == "ON" ]]; then

systemctl restart systemd-resolved

echo ""
echo "âœ… Servicio reiniciado."

sleep 2

fi

;;

3)

if [[ "$SYSTEMDNS" == "ON" ]]; then

systemctl status systemd-resolved --no-pager

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
