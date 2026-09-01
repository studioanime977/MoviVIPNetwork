#!/bin/bash

BASE="/etc/movivip"
CONFIG="$BASE/config.conf"

[[ ! -f "$CONFIG" ]] && {
    echo "$(trx '❌ No existe configuración MoviVIP')"
    exit 1
}

source "$CONFIG"

# Cargar idioma
if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)"
fi

CYAN="\e[1;96m"
GREEN="\e[1;92m"
RED="\e[1;91m"
WHITE="\e[1;97m"
RESET="\e[0m"


SERVICE="udp-custom"
PORT="2100"
BIN="/usr/bin/udp"
CONFIG_UDP="/usr/bin/config.json"


set_udp_status(){

if systemctl is-active --quiet "$SERVICE"; then
    STATUS="${GREEN}🟢 ACTIVO${RESET}"
else
    STATUS="${RED}🔴 DETENIDO${RESET}"
fi

}


install_udp(){

clear

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "$(trx '       🚀 INSTALANDO UDP CUSTOM')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"


apt update -y

apt install -y curl wget iptables libpam0g


echo "$(trx '⚙️ Activando IP Forward...')"

sysctl -w net.ipv4.ip_forward=1

grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf || \
echo "$(trx 'net.ipv4.ip_forward=1')" >> /etc/sysctl.conf

# Abrir puerto 2100 UDP + NAT (salida a internet)
if [[ -f "$BASE/herramientas/openports.sh" ]]; then
    source "$BASE/herramientas/openports.sh"
    open_ports "UDP:2100"
else
    iptables -C INPUT -p udp --dport 2100 -j ACCEPT 2>/dev/null \
        || iptables -A INPUT -p udp --dport 2100 -j ACCEPT
    DEV=$(ip -4 route show default | awk '{print $5}' | head -1)
    [[ -n "$DEV" ]] && {
        iptables -t nat -C POSTROUTING -o "$DEV" -j MASQUERADE 2>/dev/null \
            || iptables -t nat -A POSTROUTING -o "$DEV" -j MASQUERADE
    }
fi


ARCH=$(uname -m)


case "$ARCH" in

x86_64)
URL="https://github.com/Depwisescript/UDP/raw/main/udp-custom-linux-amd64"
;;

aarch64)
URL="https://github.com/Depwisescript/UDP/raw/main/udp-custom-linux-arm"
;;

*)
echo "❌ Arquitectura no soportada: $ARCH"
return
;;

esac


echo "$(trx '⬇️ Descargando UDP...')"

curl -L -s -f "$URL" -o "$BIN"


if [[ ! -f "$BIN" ]]; then

echo "$(trx '❌ Error descargando UDP')"

return

fi


chmod +x "$BIN"



echo "$(trx '📝 Creando configuración...')"

cat > "$CONFIG_UDP" <<EOF
{
    "listen": ":2100",
    "stream_buffer": 33554432,
    "receive_buffer": 83886080,
    "auth": {
        "mode": "passwords"
    }
}
EOF



echo "$(trx '⚙️ Creando servicio...')"


cat > /etc/systemd/system/$SERVICE.service <<EOF
[Unit]
Description=UDP Custom Server MoviVIP
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/usr/bin
ExecStart=/usr/bin/udp server -exclude 2200,7300,7200,7100,323,10008,10004 /usr/bin/config.json
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF


systemctl daemon-reload

systemctl enable "$SERVICE"

systemctl restart "$SERVICE"



if systemctl is-active --quiet "$SERVICE"; then

echo "UDP_CUSTOM=ON" >> "$CONFIG"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "$(trx '✅ UDP CUSTOM INSTALADO')"
echo "Puerto: $PORT"
echo ""
echo "$(trx '📌 Para asignar puertos a usuarios')"
echo "$(trx '   usar el formato: 1-PUERTO')"
echo "$(trx '   Ejemplo: 1-2100')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

else

echo "$(trx '❌ UDP no inició')"
journalctl -u "$SERVICE" --no-pager -n 20

fi


sleep 3

}
remove_udp(){

clear

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "$(trx '       🗑️ ELIMINAR UDP CUSTOM')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"


read -rp "$(trx '¿Eliminar UDP Custom? (s/n): ')" CONFIRM


if [[ ! "$CONFIRM" =~ ^[Ss]$ ]]; then

echo "$(trx '❌ Cancelado')"
sleep 2
return

fi



echo "$(trx '⏳ Deteniendo servicio...')"


systemctl stop "$SERVICE" 2>/dev/null

systemctl disable "$SERVICE" 2>/dev/null



echo "$(trx '🧹 Eliminando archivos...')"


rm -f "/etc/systemd/system/$SERVICE.service"

rm -f "$BIN"

rm -f "$CONFIG_UDP"



systemctl daemon-reload



echo "$(trx '🧹 Limpiando reglas temporales...')"


DEV=$(ip -4 route show default | awk '{print $5}' | head -1)



if [[ -n "$DEV" ]]; then


iptables -t nat -S PREROUTING 2>/dev/null \
| grep "2100" \
| sed 's/-A/-D/' \
| while read RULE
do
iptables -t nat $RULE 2>/dev/null
done



iptables -S INPUT 2>/dev/null \
| grep "2100" \
| sed 's/-A/-D/' \
| while read RULE
do
iptables $RULE 2>/dev/null
done


fi



sed -i '/^UDPCUSTOM=/d' "$CONFIG"

echo "UDP_CUSTOM=OFF" >> "$CONFIG"


echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "$(trx '✅ UDP CUSTOM ELIMINADO')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"


sleep 3

}



restart_udp(){


clear


echo "$(trx '🔄 Reiniciando UDP Custom...')"


systemctl restart "$SERVICE"



sleep 2



if systemctl is-active --quiet "$SERVICE"; then

echo "$(trx '✅ Servicio activo')"

else

echo "$(trx '❌ No pudo iniciar')"

journalctl -u "$SERVICE" --no-pager -n 15

fi


sleep 3


}



status_udp(){


clear


echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "$(trx '       📊 ESTADO UDP CUSTOM')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"


echo ""


systemctl status "$SERVICE" --no-pager



echo ""

echo "Puerto interno: $PORT"


echo ""

echo "$(trx 'Escuchando UDP:')"


ss -ulnp | grep ":$PORT"



echo ""

read -n1 -r -p "$(trx 'Presiona una tecla para continuar...')"

}
# Navegación con flechitas
[[ -f "$BASE/lib/nav.sh" ]] && source "$BASE/lib/nav.sh"

while true
do

clear

source "$CONFIG"


set_udp_status

mv_header "🚀 UDP Custom Manager" "$(trx 'Túnel UDP · bajo consumo')" "v6.2"
movivip_contacts 2>/dev/null || true

echo -e " Estado   : $STATUS"
echo -e " Puerto   : $PORT"
echo -e "$(trx ' Servicio : udp-custom')"

echo ""

if [[ "$UDP_CUSTOM" == "ON" ]]; then
    LBL=("Desinstalar UDP Custom" "Reiniciar Servicio" "Ver Estado")
else
    LBL=("Instalar UDP Custom")
fi
SEL=$(nav_pick "► Opción:" "${LBL[@]}" "↩ Regresar") || SEL=0
[[ $SEL -eq $((${#LBL[@]}+1)) ]] && SEL=0
OP="$SEL"



case "$OP" in


1)


if [[ "$UDP_CUSTOM" == "ON" ]]; then

remove_udp

else

install_udp

fi

;;



2)


if [[ "$UDP_CUSTOM" == "ON" ]]; then

restart_udp

else

echo "$(trx '❌ UDP Custom no está instalado')"

sleep 2

fi

;;



3)


if [[ "$UDP_CUSTOM" == "ON" ]]; then

status_udp

else

echo "$(trx '❌ UDP Custom no está instalado')"

sleep 2

fi

;;



0)


if [[ -f "$BASE/protocolos/menu.sh" ]]; then

exec bash "$BASE/protocolos/menu.sh"

else

clear

echo "$(trx '❌ Menú principal no encontrado')"

sleep 2

exit

fi

;;



*)

echo "$(trx '❌ Opción inválida')"

sleep 2

;;


esac


done
