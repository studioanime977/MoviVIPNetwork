#!/bin/bash

# ── i18n shim (auto) ───────────────────────────────
if ! declare -F trx >/dev/null 2>&1; then trx() { printf '%s' "$1"; }; fi
# ─────────────────────────────────────────────────────────

BASE="/etc/movivip"
CONFIG="$BASE/config.conf"

source "$CONFIG"

# 🌐 Multi-idioma
if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)"
fi
if [[ -f "$BASE/languages/protocols.sh" ]]; then
    source "$BASE/languages/protocols.sh"
fi

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

# Navegación con flechitas
[[ -f "$BASE/lib/nav.sh" ]] && source "$BASE/lib/nav.sh"

# Sistema de animación/progreso + detección de estado
[[ -f "$BASE/lib/anim.sh" ]] && source "$BASE/lib/anim.sh"

while true; do

clear

source "$CONFIG"

if [[ "$BADVPN" == "ON" ]]; then
    STATUS="${GREEN}🟢 ACTIVO${RESET}"
else
    STATUS="${RED}🔴 DESINSTALADO${RESET}"
fi

mv_header "🌐 BadVPN Manager" "$(trx 'Túneles UDP · UDPGW 7300/7200')" "v6.2"
movivip_contacts 2>/dev/null || true

echo -e " Estado      : $STATUS"
echo -e " Puerto 1    : $PORT1"
echo -e " Puerto 2    : $PORT2"
echo -e "$(trx ' Servicio    : BadVPN UDPGW')"

echo ""

if [[ "$BADVPN" == "ON" ]]; then
    LBL=("Reinstalar BadVPN" "Reiniciar Servicio" "Ver Estado" "Desinstalar")
else
    LBL=("Instalar BadVPN")
fi
SEL=$(nav_pick "► Opción:" "${LBL[@]}" "↩ Regresar") || SEL=0
[[ $SEL -eq $((${#LBL[@]}+1)) ]] && SEL=0
OP="$SEL"

case "$OP" in
1)

clear

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}        INSTALANDO BADVPN UDPGW${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo ""

anim_init 7
anim_step "Instalando dependencias"
anim_run "apt update" apt update -y
anim_run "Instalar git cmake build-essential" apt install -y git cmake build-essential


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


anim_step "Descargando BadVPN"
anim_run "git clone badvpn" git clone -q https://github.com/ambrop72/badvpn.git /tmp/badvpn

anim_step "Compilando BadVPN"

cd /tmp/badvpn

anim_run "Crear build" mkdir -p build

cd build

anim_run "cmake" bash -c "cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1"

anim_run "make -j$(nproc)" bash -c "make -j$(nproc)"


if [[ -f "udpgw/badvpn-udpgw" ]]; then

cp udpgw/badvpn-udpgw "$BIN"

chmod +x "$BIN"


echo "$(trx '✅ Binario instalado.')"

else

echo "$(trx '❌ Error compilando BadVPN.')"

sleep 3
continue

fi
echo "$(trx '⚙️ Creando servicios BadVPN...')"


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


anim_step "Registrando servicios BadVPN"
    anim_run "daemon-reload" systemctl daemon-reload
    anim_run "Habilitar servicios" bash -c "systemctl enable $SERVICE1 >/dev/null 2>&1; systemctl enable $SERVICE2 >/dev/null 2>&1"
    svc_restart_anim "$SERVICE1" "Arrancando BadVPN 7300"
    svc_restart_anim "$SERVICE2" "Arrancando BadVPN 7200"


sed -i 's/^BADVPN=.*/BADVPN=ON/' "$CONFIG"

BADVPN="ON"


echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}       ✅ BADVPN ACTIVADO${RESET}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo ""
echo "🎮 Juegos      : Puerto $PORT1"
echo "📞 Videollamada: Puerto $PORT2"
echo ""
echo "$(trx '📌 Para asignar puertos a usuarios')"
echo "$(trx '   usar el formato: 1-PUERTO')"
echo "$(trx '   Ejemplo: 1-7300')"
echo ""

read -rp "$(trx '¿Iniciar después de reiniciar VPS? (s/n): ')" AUTO

if [[ "$AUTO" =~ ^[Ss]$ ]]; then

systemctl enable $SERVICE1
systemctl enable $SERVICE2

echo "$(trx '✅ Inicio automático activado.')"

else

systemctl disable $SERVICE1
systemctl disable $SERVICE2

echo "$(trx 'ℹ️ Inicio automático desactivado.')"

fi


sleep 3

;;
2)

clear

svc_restart_anim "$SERVICE1" "Reiniciando BadVPN 7300"
svc_restart_anim "$SERVICE2" "Reiniciando BadVPN 7200"

sleep 2

;;


3)

clear

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}        ESTADO BADVPN UDPGW${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo ""

systemctl status $SERVICE1 --no-pager

echo ""

systemctl status $SERVICE2 --no-pager

echo ""

echo "$(trx 'Puertos activos:')"

ss -lunp | grep -E "7300|7200"

echo ""

read -n1 -r -p "$(trx 'Presione una tecla para continuar...')"

;;


4)

clear

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "$(trx '        DESINSTALAR BADVPN')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

read -rp "$(trx '¿Seguro que deseas eliminar BadVPN? (s/n): ')" R


if [[ "$R" =~ ^[Ss]$ ]]; then

anim_init 3
anim_step "Desinstalando BadVPN"
anim_run "Detener y deshabilitar servicios" bash -c "systemctl stop $SERVICE1 2>/dev/null; systemctl stop $SERVICE2 2>/dev/null; systemctl disable $SERVICE1 2>/dev/null; systemctl disable $SERVICE2 2>/dev/null"

anim_run "Eliminar archivos de servicio" rm -f /etc/systemd/system/$SERVICE1.service /etc/systemd/system/$SERVICE2.service
anim_run "Eliminar binario" rm -f "$BIN"

anim_run "daemon-reload" systemctl daemon-reload

sed -i 's/^BADVPN=.*/BADVPN=OFF/' "$CONFIG"


BADVPN="OFF"


echo ""

echo "$(trx '✅ BadVPN eliminado.')"

else

echo "$(trx '❌ Cancelado.')"

fi


sleep 3

;;


0)

exec bash "$BASE/protocolos/menu.sh"

;;


*)

echo "$(trx '❌ Opción inválida.')"

sleep 2

;;

esac

done
