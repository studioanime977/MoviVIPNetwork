#!/bin/bash

BASE="/etc/movivip"
CONFIG="$BASE/config.conf"

source "$CONFIG"

# ðŸŒ Multi-idioma
if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)"
fi
if [[ -f "$BASE/languages/protocols.sh" ]]; then
    source "$BASE/languages/protocols.sh"
fi

# ðŸ”‘ GATE DE LICENCIA â€” validaciÃ³n EN VIVO contra Firebase
bash /etc/movivip/check-licencia.sh || exit 1

CYAN="\e[1;96m"
GREEN="\e[1;92m"
RED="\e[1;91m"
WHITE="\e[1;97m"
YELLOW="\e[1;93m"
RESET="\e[0m"

SERVICE1="badvpn-udpgw-7300"
SERVICE2="badvpn-udpgw-7200"

PORT1="7300"
PORT2="7200"

BIN="/usr/local/bin/badvpn-udpgw"
while true; do

clear

source "$CONFIG"

if [[ "$BADVPN" == "ON" ]]; then
    STATUS="${GREEN}ðŸŸ¢ ACTIVO${RESET}"
else
    STATUS="${RED}ðŸ”´ DESINSTALADO${RESET}"
fi

echo -e "${CYAN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${RESET}"
echo -e "${WHITE}            ðŸŒ BADVPN MANAGER${RESET}"
echo -e "${CYAN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${RESET}"

echo -e " Estado      : $STATUS"
echo -e " Puerto 1    : $PORT1"
echo -e " Puerto 2    : $PORT2"
echo -e " Servicio    : BadVPN UDPGW"

echo
echo -e "${CYAN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${RESET}"

if [[ "$BADVPN" == "ON" ]]; then
cat <<EOF
 [1] âž® Reinstalar BadVPN
 [2] âž® Reiniciar Servicio
 [3] âž® Ver Estado
 [4] âž® Desinstalar
 [0] âž® Regresar
EOF
else
cat <<EOF
 [1] âž® Instalar BadVPN
 [0] âž® Regresar
EOF
fi

echo -e "${CYAN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${RESET}"

read -rp " â–º OpciÃ³n: " OP

case "$OP" in
1)

clear

echo -e "${CYAN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${RESET}"
echo -e "${WHITE}        INSTALANDO BADVPN UDPGW${RESET}"
echo -e "${CYAN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${RESET}"

echo ""

apt update -y >/dev/null 2>&1

echo "ðŸ“¦ Instalando dependencias..."

apt install -y git cmake build-essential >/dev/null 2>&1


# Abrir puertos 7200/7300 UDP + NAT (salida a internet)
if [[ -f "$BASE/herramientas/openports.sh" ]]; then
    source "$BASE/herramientas/openports.sh"
    open_ports "UDP:7200,7300"
else
    sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1
    for P in 7200 7300; do
        iptables -C INPUT -p udp --dport "$P" -j ACCEPT 2>/dev/null \
            || iptables -A INPUT -p udp --dport "$P" -j ACCEPT
    done
    DEV=$(ip -4 route show default | awk '{print $5}' | head -1)
    [[ -n "$DEV" ]] && {
        iptables -t nat -C POSTROUTING -o "$DEV" -j MASQUERADE 2>/dev/null \
            || iptables -t nat -A POSTROUTING -o "$DEV" -j MASQUERADE
    }
fi


echo "â¬‡ï¸ Descargando BadVPN..."

rm -rf /tmp/badvpn

git clone -q https://github.com/ambrop72/badvpn.git /tmp/badvpn


echo "âš™ï¸ Compilando..."

cd /tmp/badvpn

mkdir -p build

cd build


cmake .. \
-DBUILD_NOTHING_BY_DEFAULT=1 \
-DBUILD_UDPGW=1 >/dev/null 2>&1


make -j$(nproc) >/dev/null 2>&1


if [[ -f "udpgw/badvpn-udpgw" ]]; then

cp udpgw/badvpn-udpgw "$BIN"

chmod +x "$BIN"


echo "âœ… Binario instalado."

else

echo "âŒ Error compilando BadVPN."

sleep 3
continue

fi
echo "âš™ï¸ Creando servicios BadVPN..."


cat > /etc/systemd/system/$SERVICE1.service <<EOF
[Unit]
Description=BadVPN UDPGW Puerto 7300
After=network.target

[Service]
Type=simple
ExecStart=$BIN --listen-addr 0.0.0.0:$PORT1 --max-clients 999 --max-connections-for-client 10
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF


cat > /etc/systemd/system/$SERVICE2.service <<EOF
[Unit]
Description=BadVPN UDPGW Puerto 7200
After=network.target

[Service]
Type=simple
ExecStart=$BIN --listen-addr 0.0.0.0:$PORT2 --max-clients 999 --max-connections-for-client 10
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF


systemctl daemon-reload


systemctl enable $SERVICE1 >/dev/null 2>&1
systemctl enable $SERVICE2 >/dev/null 2>&1


systemctl restart $SERVICE1
systemctl restart $SERVICE2


sed -i 's/^BADVPN=.*/BADVPN=ON/' "$CONFIG"

BADVPN="ON"


echo ""
echo -e "${GREEN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${RESET}"
echo -e "${GREEN}       âœ… BADVPN ACTIVADO${RESET}"
echo -e "${GREEN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${RESET}"

echo ""
echo "ðŸŽ® Juegos      : Puerto $PORT1"
echo "ðŸ“ž Videollamada: Puerto $PORT2"
echo ""
echo "ðŸ“Œ Para asignar puertos a usuarios"
echo "   usar el formato: 1-PUERTO"
echo "   Ejemplo: 1-7300"
echo ""

read -rp "Â¿Iniciar despuÃ©s de reiniciar VPS? (s/n): " AUTO

if [[ "$AUTO" =~ ^[Ss]$ ]]; then

systemctl enable $SERVICE1
systemctl enable $SERVICE2

echo "âœ… Inicio automÃ¡tico activado."

else

systemctl disable $SERVICE1
systemctl disable $SERVICE2

echo "â„¹ï¸ Inicio automÃ¡tico desactivado."

fi


sleep 3

;;
2)

clear

echo "ðŸ”„ Reiniciando BadVPN..."

systemctl restart $SERVICE1
systemctl restart $SERVICE2

echo ""
echo "âœ… Servicios reiniciados."

sleep 2

;;


3)

clear

echo -e "${CYAN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${RESET}"
echo -e "${WHITE}        ESTADO BADVPN UDPGW${RESET}"
echo -e "${CYAN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${RESET}"

echo ""

systemctl status $SERVICE1 --no-pager

echo ""

systemctl status $SERVICE2 --no-pager

echo ""

echo "Puertos activos:"

ss -lunp | grep -E "7300|7200"

echo ""

read -n1 -r -p "Presione una tecla para continuar..."

;;


4)

clear

echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
echo "        DESINSTALAR BADVPN"
echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"

read -rp "Â¿Seguro que deseas eliminar BadVPN? (s/n): " R


if [[ "$R" =~ ^[Ss]$ ]]; then


systemctl stop $SERVICE1 2>/dev/null
systemctl stop $SERVICE2 2>/dev/null


systemctl disable $SERVICE1 2>/dev/null
systemctl disable $SERVICE2 2>/dev/null


rm -f /etc/systemd/system/$SERVICE1.service
rm -f /etc/systemd/system/$SERVICE2.service


rm -f "$BIN"


systemctl daemon-reload


sed -i 's/^BADVPN=.*/BADVPN=OFF/' "$CONFIG"


BADVPN="OFF"


echo ""

echo "âœ… BadVPN eliminado."

else

echo "âŒ Cancelado."

fi


sleep 3

;;


0)

exec bash "$BASE/protocolos/menu.sh"

;;


*)

echo "âŒ OpciÃ³n invÃ¡lida."

sleep 2

;;

esac

done
