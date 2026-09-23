#!/bin/bash
#==================================================
# MoviVIP Network Premium
# Crear Usuario SSH
#==================================================

#======== COLORES ========#
GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
BLUE="\e[1;94m"
CYAN="\e[1;96m"
MAGENTA="\e[1;95m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"
RESET="\e[0m"

# ============================================================
# >>> NEBULA v3.0 <<< Identidad visual heredada del design system
# Redefine los colores locales con la paleta NEBULA (lib/ui.sh)
# Fallback seguro: si ui.sh no carga, se conserva el color local.
# ============================================================
source "${BASE:-/etc/movivip}/lib/ui.sh" 2>/dev/null || true
source "${BASE:-/etc/movivip}/lib/delivery.sh" 2>/dev/null || true
GREEN="${MV_GRN:-$GREEN}"; RED="${MV_RED:-$RED}"; YELLOW="${MV_YLW:-$YELLOW}"; BLUE="${MV_BLU:-$BLUE}"; CYAN="${MV_CYN:-$CYAN}"; MAGENTA="${MV_MAG:-$MAGENTA}"; WHITE="${MV_WHT:-$WHITE}"; GRAY="${MV_DIM:-$GRAY}"; RESET="${MV_R:-$RESET}"


#======== CONFIG ========#

BASE="/etc/movivip"
CONFIG="$BASE/config.conf"

[[ -f "$CONFIG" ]] && source "$CONFIG"

#==================================================
# IDIOMA (multi-idioma para creacion de cuentas)
#==================================================
if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)"
fi

#==================================================
# FUNCION: suavizar texto con trx (fallback espanol)
#==================================================
T() { trx "$1"; }

# Duración días/horas/minutos (lib compartida estilo Chumo)
[[ -f "$BASE/lib/duracion.sh" ]] && source "$BASE/lib/duracion.sh"

while true; do

clear

mv_brand_header "$(T 'CREAR USUARIO SSH')" "$(T 'MoviVIP Network · Alta de cuentas')"

read -rp "$(echo -e "${GREEN}$(T '👤 Usuario')               : ${RESET}")" USER

if [[ -z "$USER" ]]; then
    echo
    echo -e "${RED}✖ $(T 'Debe ingresar un nombre de usuario.')${RESET}"
    sleep 2
    continue
fi

if id "$USER" &>/dev/null; then
    echo
    echo -e "${RED}✖ $(T 'El usuario ya existe.')${RESET}"
    sleep 2
    continue
fi

read -rp "$(echo -e "${GREEN}$(T '🔑 Contraseña')            : ${RESET}")" PASS
echo

if [[ -z "$PASS" ]]; then
    echo
    echo -e "${RED}✖ $(T 'Debe ingresar una contraseña.')${RESET}"
    sleep 2
    continue
fi

if declare -F mv_ask_duracion >/dev/null 2>&1; then
    if ! mv_ask_duracion 30; then
        echo
        echo -e "${YELLOW}← $(T 'Operación cancelada. Volviendo al menú...')${RESET}"
        sleep 1
        continue
    fi
    DIAS="${DUR_DIAS:-30}"; HORAS="${DUR_HORAS:-0}"; MINUTOS="${DUR_MIN:-0}"
else
    read -rp "$(echo -e "${GREEN}$(T '📅 Duración (días)')       : ${RESET}")" DIAS

    [[ -z "$DIAS" ]] && DIAS=30
    HORAS=0; MINUTOS=0
fi

read -rp "$(echo -e "${GREEN}$(T '🌐 Límite (0=Ilimitado)')  : ${RESET}")" LIMITE

[[ -z "$LIMITE" ]] && LIMITE=0

if ! [[ "$LIMITE" =~ ^[0-9]+$ ]]; then
    echo
    echo -e "${RED}✖ $(T 'El límite debe ser un número.')${RESET}"
    sleep 2
    continue
fi

if [[ "$LIMITE" -eq 0 ]]; then
    LIMITE_MOSTRAR="♾️ Ilimitado"
else
    LIMITE_MOSTRAR="$LIMITE"
fi

#==================================================
# LÍMITE DE CONSUMO (DATOS) €” 100GB/200GB/500GB/800GB/1TB/♾️
#==================================================

echo
echo -e "${YELLOW}•”•••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••—${RESET}"
echo -e "${YELLOW}•‘        📊 $(T 'LÍMITE DE CONSUMO (DATOS)')                  •‘${RESET}"
echo -e "${YELLOW}•š•••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••${RESET}"
echo -e "${GREEN}[1]${WHITE} 100 GB"
echo -e "${GREEN}[2]${WHITE} 200 GB"
echo -e "${GREEN}[3]${WHITE} 500 GB"
echo -e "${GREEN}[4]${WHITE} 800 GB"
echo -e "${GREEN}[5]${WHITE} 1 TB"
echo -e "${GREEN}[6]${WHITE} ♾️ Ilimitado"
echo -e "${CYAN}────────────────────────────────────────────────────────────────${RESET}"

read -rp "$(echo -e "${GREEN}$(T '📊 Límite de consumo') [6]: ${RESET}")" OPC_CONSUMO

[[ -z "$OPC_CONSUMO" ]] && OPC_CONSUMO=6

case "$OPC_CONSUMO" in
    1) CONSUMO_BYTES=107374182400; CONSUMO_MOSTRAR="100 GB" ;;
    2) CONSUMO_BYTES=214748364800; CONSUMO_MOSTRAR="200 GB" ;;
    3) CONSUMO_BYTES=536870912000; CONSUMO_MOSTRAR="500 GB" ;;
    4) CONSUMO_BYTES=858993459200; CONSUMO_MOSTRAR="800 GB" ;;
    5) CONSUMO_BYTES=1099511627776; CONSUMO_MOSTRAR="1 TB" ;;
    6|0) CONSUMO_BYTES=0; CONSUMO_MOSTRAR="♾️ Ilimitado" ;;
    *)
        echo
        echo -e "${RED}✖ $(T 'Opción inválida.')${RESET}"
        sleep 2
        continue
        ;;
esac

FECHA=$(date -d "+$DIAS days +$HORAS hours +$MINUTOS minutes" +"%Y-%m-%d")
FECHA_HORA=$(date -d "+$DIAS days +$HORAS hours +$MINUTOS minutes" +"%Y-%m-%d %H:%M:%S")
FECHA_TS=$(date -d "+$DIAS days +$HORAS hours +$MINUTOS minutes" +%s)
#==================================================
# CREAR USUARIO SSH
#==================================================

useradd -e "$FECHA" -M -s /usr/sbin/nologin "$USER"

if [[ $? -ne 0 ]]; then
    echo
    echo -e "${RED}✖ $(T 'Error al crear el usuario.')${RESET}"
    sleep 3
    continue
fi

# Establecer contrasena sin validacion PAM (compatible ARM)
HASH=$(openssl passwd -6 "$PASS" 2>/dev/null)
usermod -p "$HASH" "$USER"

if [[ $? -ne 0 ]]; then
    echo
    echo -e "${RED}✖ $(T 'Error al establecer la contraseña.')${RESET}"
    userdel -f "$USER" &>/dev/null
    sleep 3
    continue
fi

# Expiración exacta (hora/minuto) para el verificador cron
if declare -F mv_save_exp_exacta >/dev/null 2>&1; then
    mv_save_exp_exacta "$USER" "$FECHA_TS"
fi

#==================================================
# GUARDAR LÍMITE DE CONSUMO
# (0 = ilimitado; formato USUARIO=BYTES)
#==================================================

LIM_CONF="$BASE/sistema/limites_consumo.conf"
mkdir -p "$BASE/sistema" 2>/dev/null
touch "$LIM_CONF" 2>/dev/null

# Eliminar entrada previa (si el usuario existía) y escribir la nueva
grep -v "^$USER=" "$LIM_CONF" > "$LIM_CONF.tmp" 2>/dev/null
mv "$LIM_CONF.tmp" "$LIM_CONF" 2>/dev/null
echo "$USER=$CONSUMO_BYTES" >> "$LIM_CONF"

#==================================================
# GUARDAR LÍMITE DE CONEXIONES SIMULTÁNEAS
# (0 = ilimitado; formato USUARIO=MAXCONN)
# El monitor corta las conexiones que excedan MAXCONN
# sin bloquear la cuenta (online.sh --quiet / cron)
#==================================================

CONN_LIM_CONF="$BASE/sistema/limites_conexiones.conf"
touch "$CONN_LIM_CONF" 2>/dev/null

grep -v "^$USER=" "$CONN_LIM_CONF" > "$CONN_LIM_CONF.tmp" 2>/dev/null
mv "$CONN_LIM_CONF.tmp" "$CONN_LIM_CONF" 2>/dev/null
echo "$USER=$LIMITE" >> "$CONN_LIM_CONF"

#==================================================
# INFORMACIÓN DEL SERVIDOR
#==================================================

clear

IP=$(curl -4 -s ifconfig.me 2>/dev/null)

[[ -z "$IP" ]] && IP=$(hostname -I | awk '{print $1}')

HOST="${SERVER_DOMAIN:-$IP}"

FECHA_MOSTRAR=$(date -d "$FECHA_HORA" +"%d/%m/%Y %H:%M")

#==================================================
# PREPARAR LÍMITE
#==================================================

if [[ "$LIMITE" == "0" ]]; then
    LIMITE_MOSTRAR="♾️ Ilimitado"
else
    LIMITE_MOSTRAR="$LIMITE $(T 'Conexión(es)')"
fi

if [[ "$CONSUMO_BYTES" == "0" ]]; then
    CONSUMO_MOSTRAR="♾️ Ilimitado"
fi

#==================================================
# DATOS REALES DEL SISTEMA (plantilla de entrega)
#==================================================

CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^ //')
CPU_USO=$(top -bn1 | awk -F'id,' '/Cpu/ {split($1,a,","); printf("%.0f%%",100-a[length(a)])}')
RAM_TOTAL=$(free -h | awk '/Mem:/ {print $2}')
RAM_USO=$(free -h | awk '/Mem:/ {print $3}')
RAM_PCT=$(free | awk '/Mem:/ {printf "%.1f", $3/$2*100}')
DISCO_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
DISCO_USO=$(df -h / | awk 'NR==2 {print $3}')
DISCO_PCT=$(df -h / | awk 'NR==2 {print $5}')
UPTIME=$(uptime -p | sed 's/up //')
LOAD=$(uptime | awk -F'load average:' '{print $2}')

#--- Puertos por protocolo (solo los activos) con DATOS REALES de config.conf ---
[[ "$OPENSSH"     == "ON" ]] && P_SSH="22"                                || P_SSH="✘"
[[ "$DROPBEAR"    == "ON" ]] && P_DROPBEAR="${DROPBEAR_PORT:-143}"        || P_DROPBEAR="✘"
[[ "$SSL"         == "ON" ]] && P_SSL="80 | 443 | 8080 | 8443"            || P_SSL="✘"
[[ "$BADVPN"      == "ON" ]] && P_BADVPN="1-7300"                         || P_BADVPN="✘"
[[ "$UDP_CUSTOM"  == "ON" ]] && P_UDP="1-${UDP_CUSTOM_PORT:-2100}"        || P_UDP="✘"
[[ "$ZIPVPN"      == "ON" ]] && P_ZIP="${ZIPVPN_PORT:-24075}"             || P_ZIP="✘"
[[ "$WEBSOCKET"   == "ON" ]] && P_HTTP="80"                               || P_HTTP="✘"
[[ "$WEBSOCKET"   == "ON" ]] && P_WS="8080"                               || P_WS="✘"
[[ "$WEBSOCKET"   == "ON" ]] && P_WSS="8880"                              || P_WSS="✘"
[[ "$V2RAY"       == "ON" ]] && P_XRAY="${XRAY_PORT:-443} | 80 | 8080"    || P_XRAY="✘"
[[ "$HYSTERIA"    == "ON" ]] && P_HYSTERIA="${HYSTERIA_PORT:-13901}"      || P_HYSTERIA="✘"
[[ "$SQUID"       == "ON" ]] && P_SQUID="${SQUID_PORT:-3128}"             || P_SQUID="✘"
[[ "$WG"          == "ON" ]] && P_WG="${WG_PORT:-51820}"                  || P_WG="✘"
[[ "$SYSTEMDNS"   == "ON" ]] && P_SYSTEMDNS="53"                          || P_SYSTEMDNS="✘"
[[ "$XHTTP"       == "ON" ]] && P_XHTTP="${XHTTP_PORT:-443} | ${XHTTP_PORT2:-8080}" || P_XHTTP="✘"
[[ "$BHTTP"       == "ON" ]] && P_BHTTP="${BHTTP_PORT:-80} | ${BHTTP_XPORT:-8443}" || P_BHTTP="✘"
[[ "$BTUN"        == "ON" ]] && P_BTUN="${BTUN_PORT:-7900}"               || P_BTUN="✘"
[[ "$SHADOWSOCKS" == "ON" ]] && P_SS="${SHADOWSOCKS_PORT:-8388}"          || P_SS="✘"
[[ "$PAYLOAD"     == "ON" ]] && P_PAY="${PAYLOAD_PORT:-8082-8085}"        || P_PAY="✘"
[[ "$OPENVPN"     == "ON" ]] && P_OPENVPN="${OPENVPN_PORT:-1194}"         || P_OPENVPN="✘"
[[ "$SOCKS5"      == "ON" ]] && P_SOCKS5="${SOCKS5_PORT:-1080}"           || P_SOCKS5="✘"
[[ "$HCR"         == "ON" ]] && P_HCR="443 (TLS · SNI ${HCR_SNI:-hcr})"   || P_HCR="✘"
[[ "$ONLINEAPP"   == "ON" ]] && P_ONLINEAPP="8888"                        || P_ONLINEAPP="✘"

#--- HCR datos reales (target = SSH del sistema) ---
HCR_SNI_VALUE="${HCR_SNI:-hcr}"
HCR_TARGET_VALUE="${HCR_TARGET:-127.0.0.1:22}"

#--- Dominios CDN/SNI (Cloudflare, CloudFront, No-IP) ---
CDN1="${SERVER_DOMAIN:-$IP}"
CDN2="${CLOUDFRONT_DOMAIN:-}"
CDN3="${NOIP_DOMAIN:-}"

#--- SlowDNS / Noiz (datos reales desde el sistema) ---
NS_DNS="${SLOWDNS_NS:-}"
KEY_DNS="${SLOWDNS_KEY:-}"
[[ -z "$NS_DNS" && -n "$SERVER_DOMAIN" ]] && NS_DNS="ns.$SERVER_DOMAIN"
if [[ -z "$NS_DNS" && -f /etc/slowdns/domain.conf ]]; then
    NS_DNS=$(head -1 /etc/slowdns/domain.conf 2>/dev/null)
fi
if [[ -z "$KEY_DNS" && -f /etc/slowdns/server.pub ]]; then
    KEY_DNS=$(cat /etc/slowdns/server.pub 2>/dev/null)
fi
# Fallback al dominio oficial MoviVIP (infraestructura real del usuario)
[[ -z "$NS_DNS" ]] && NS_DNS="ns1.movivipoppax.uk"
[[ -z "$KEY_DNS" ]] && KEY_DNS="$(T 'No configurado')"

#--- Host para payloads: dominio digitado en la instalacion (CLOUDFRONT/SERVER_DOMAIN) ---
PAYLOAD_HOST="${CLOUDFRONT_DOMAIN:-${SERVER_DOMAIN:-$IP}}"

#--- Dtunnel (proto-server) datos reales ---
DT_TOKEN="${DTUNNEL_TOKEN:-}"
DT_CFG="/etc/proto-server/config.json"
DT_PORT1=""; DT_PORT2=""
if [[ -f "$DT_CFG" ]]; then
    DT_PORT1=$(grep -A3 '"ssl": true' "$DT_CFG" 2>/dev/null | grep -oE '"port": *[0-9]+' | grep -oE '[0-9]+' | head -1)
    DT_PORT2=$(grep -A3 '"ssl": false' "$DT_CFG" 2>/dev/null | grep -oE '"port": *[0-9]+' | grep -oE '[0-9]+' | head -1)
    [[ -z "$DT_PORT1" ]] && DT_PORT1="4443"
    [[ -z "$DT_PORT2" ]] && DT_PORT2="8082"
    P_DTUNNEL="$DT_PORT1 | $DT_PORT2"
fi

#--- Hysteria datos reales ---
HY_PASSWORD="${HYSTERIA_AUTH:-}"
HY_OBFS="${HYSTERIA_OBFS:-}"

#--- WireGuard datos reales ---
WG_SERVER_PUB=""
if [[ -f /etc/wireguard/server.pub ]]; then
    WG_SERVER_PUB=$(cat /etc/wireguard/server.pub 2>/dev/null)
elif command -v wg &>/dev/null && wg show 2>/dev/null | grep -q 'public key'; then
    WG_SERVER_PUB=$(wg show wg0 public-key 2>/dev/null)
fi

#--- BTUN credenciales reales (/etc/btun/users -> user:pass) ---
BTUN_USER=""; BTUN_PASS=""
if [[ -f /etc/btun/users ]]; then
    BTUN_USER=$(head -n1 /etc/btun/users 2>/dev/null | cut -d: -f1)
    BTUN_PASS=$(head -n1 /etc/btun/users 2>/dev/null | cut -d: -f2)
fi

#--- XHTTP / BHTTP hosts (dominio de instalacion) ---
XHTTP_HOST_V="${XHTTP_HOST:-${SERVER_DOMAIN:-$IP}}"
BHTTP_HOST_V="${BHTTP_HOST:-${SERVER_DOMAIN:-$IP}}"

#--- Shadowsocks URL ss:// lista para compartir ---
SS_URL=""
if [[ "$SHADOWSOCKS" == "ON" && -n "${SS_PASSWORD:-}" ]]; then
    SS_METHOD="aes-256-gcm"
    SS_URL="ss://$(printf '%s' "$SS_METHOD:$SS_PASSWORD@$IP:${SS_PORT:-8388}" | base64 -w0)#MoviVIP"
fi

#--- Payload: master y temp (pwd.pwd) ---
PAY_MASTER=""; PAY_TEMP=""
if [[ -f /etc/movivip/payload/pwd.pwd ]]; then
    PAY_MASTER=$(grep '^master=' /etc/movivip/payload/pwd.pwd 2>/dev/null | cut -d= -f2)
    PAY_TEMP=$(grep -E '^[0-9.]+:22=' /etc/movivip/payload/pwd.pwd 2>/dev/null | cut -d= -f2)
fi

clear
echo

mv_deliv_header "$(T 'CUENTA SSH CREADA CON ÉXITO')"
echo

mv_dcard_top
mv_dcard_row "👤" "$(T 'Usuario')"      "$USER"
mv_dcard_row "🔑" "$(T 'Contraseña')"   "$PASS"
mv_dcard_row "📅" "$(T 'Expira')"       "$FECHA_MOSTRAR"
mv_dcard_row "🌐" "$(T 'Límite')"       "$LIMITE_MOSTRAR"
mv_dcard_row "📊" "$(T 'Consumo Máx')"  "$CONSUMO_MOSTRAR"
mv_dcard_bot
echo

echo -e "${WHITE}🖥️  $(T 'Servidor'): $(mv_tick "${SERVER_DOMAIN:-$IP}")${RESET}"
[[ -n "$CLOUDFRONT_DOMAIN" ]] && echo -e "${WHITE}☁️  $(T 'Cloudflare'): $(mv_tick "$CLOUDFRONT_DOMAIN")${RESET}"
[[ -n "$NOIP_DOMAIN" ]]      && echo -e "${WHITE}📍 $(T 'No-IP'): $(mv_tick "$NOIP_DOMAIN")${RESET}"
echo -e "${WHITE}💻  CPU: $(mv_tick "$CPU_MODEL")${RESET}"
echo -e "${WHITE}🔥  $(T 'Uso CPU'): $(mv_tick "$CPU_USO")${RESET}"
echo -e "${WHITE}📊  RAM: $(mv_tick "$RAM_USO")${WHITE} ($(mv_tick "${RAM_PCT}%"))${RESET}"
echo -e "${WHITE}💾  $(T 'Disco'): $(mv_tick "$DISCO_USO")${WHITE} / $(mv_tick "$DISCO_TOTAL")${WHITE} ($(mv_tick "$DISCO_PCT"))${RESET}"
echo -e "${WHITE}⏱️  $(T 'Uptime'): $(mv_tick "$UPTIME")${RESET}"
echo -e "${WHITE}📈  $(T 'Carga'): $(mv_tick "$LOAD")${RESET}"
echo

mv_line
echo -e "${WHITE}📍  $(T 'IP Principal'): $(mv_tick "$IP")${RESET}"
echo

mv_deliv_sec "$(T 'PUERTOS ACTIVOS (todos los protocolos)')"
[[ "$OPENSSH"   == "ON" ]] && echo -e "${WHITE}🔑 $(T 'SSH Directo'): $(mv_tick "$P_SSH")${RESET}"
[[ "$DROPBEAR"  == "ON" ]] && echo -e "${WHITE}🐻 $(T 'Dropbear'): $(mv_tick "$P_DROPBEAR")${RESET}"
[[ "$SSL"       == "ON" ]] && echo -e "${WHITE}🔒 $(T 'SSL/Stunnel'): $(mv_tick "$P_SSL")${RESET}"
[[ "$BADVPN"    == "ON" ]] && echo -e "${WHITE}🎮 $(T 'BadVPN UDPGW'): $(mv_tick "$P_BADVPN")${RESET}"
[[ "$UDP_CUSTOM" == "ON" ]] && echo -e "${WHITE}⚡ $(T 'UDP Custom'): $(mv_tick "$P_UDP")${RESET}"
[[ "$ZIPVPN"    == "ON" ]] && echo -e "${WHITE}📦 $(T 'ZIPVPN'): $(mv_tick "$P_ZIP")${RESET}"
[[ -n "$P_DTUNNEL" ]]      && echo -e "${WHITE}🔌 $(T 'DTunnel'): $(mv_tick "$P_DTUNNEL")${RESET}"
[[ "$V2RAY"     == "ON" ]] && echo -e "${WHITE}🚀 $(T 'v2ray (VLESS/VMess/Trojan)'): $(mv_tick "$P_XRAY")${RESET}"
[[ "$HYSTERIA"  == "ON" ]] && echo -e "${WHITE}🌀 $(T 'Hysteria'): $(mv_tick "$P_HYSTERIA")${RESET}"
[[ "$SQUID"     == "ON" ]] && echo -e "${WHITE}🦑 $(T 'Squid Proxy'): $(mv_tick "$P_SQUID")${RESET}"
[[ "$WG"        == "ON" ]] && echo -e "${WHITE}🔗 $(T 'WireGuard'): $(mv_tick "$P_WG")${RESET}"
[[ "$WEBSOCKET" == "ON" ]] && echo -e "${WHITE}🌐 $(T 'HTTP/PDirect3'): $(mv_tick "$P_HTTP")${RESET}"
[[ "$WEBSOCKET" == "ON" ]] && echo -e "${WHITE}🌐 $(T 'WebSocket WS'): $(mv_tick "$P_WS")${RESET}"
[[ "$WEBSOCKET" == "ON" ]] && echo -e "${WHITE}🌐 $(T 'WebSocket WSS'): $(mv_tick "$P_WSS")${RESET}"
[[ "$SLOWDNS"   == "ON" ]] && echo -e "${WHITE}🐌 $(T 'SlowDNS'): $(mv_tick 'DNS 53 / DNSTT 5300')${RESET}"
[[ "$SYSTEMDNS" == "ON" ]] && echo -e "${WHITE}🧬 $(T 'SystemDNS'): $(mv_tick "$P_SYSTEMDNS")${RESET}"
[[ "$XHTTP"     == "ON" ]] && echo -e "${WHITE}🚀 $(T 'SSH-XHTTP'): $(mv_tick "$P_XHTTP")${RESET}"
[[ "$BHTTP"     == "ON" ]] && echo -e "${WHITE}📡 $(T 'BHTTP v2'): $(mv_tick "$P_BHTTP")${RESET}"
[[ "$BTUN"      == "ON" ]] && echo -e "${WHITE}🧵 $(T 'BTUN'): $(mv_tick "$P_BTUN")${RESET}"
[[ "$SHADOWSOCKS" == "ON" ]] && echo -e "${WHITE}🐋 $(T 'Shadowsocks'): $(mv_tick "$P_SS")${RESET}"
[[ "$PAYLOAD"   == "ON" ]] && echo -e "${WHITE}🧩 $(T 'Payload'): $(mv_tick "$P_PAY")${RESET}"
[[ "$OPENVPN"   == "ON" ]] && echo -e "${WHITE}🛡 $(T 'OpenVPN'): $(mv_tick "UDP $P_OPENVPN")${RESET}"
[[ "$SOCKS5"    == "ON" ]] && echo -e "${WHITE}🎯 $(T 'SOCKS5 Proxy'): $(mv_tick "$P_SOCKS5")${RESET}"
[[ "$HCR"       == "ON" ]] && echo -e "${WHITE}🚀 $(T 'HCR Relay'): $(mv_tick "$P_HCR")${RESET}"
[[ "$ONLINEAPP" == "ON" ]] && echo -e "${WHITE}🤖 $(T 'OnlineApp'): $(mv_tick "http://$IP:$P_ONLINEAPP/server/online")${RESET}"
echo

mv_deliv_sec "$(T 'SLOWDNS / NOIZ DNS')"
echo -e "${WHITE}🛰  $(T 'NS'): $(mv_tick "${NS_DNS:-$(T 'No configurado')}")${RESET}"
echo -e "${WHITE}🛰  $(T 'Key'): $(mv_tick "${KEY_DNS:-$(T 'No configurado')}")${RESET}"
echo -e "${WHITE}🛰  $(T 'Puertos DNS'): $(mv_tick '53 / 5300')${RESET}"
echo

[[ -n "$P_DTUNNEL" ]] && {
mv_deliv_sec "$(T 'DTUNNEL')"
echo -e "${WHITE}🔌 $(T 'Puertos'): $(mv_tick "$P_DTUNNEL")${RESET}"
[[ -n "$DT_TOKEN" ]] && echo -e "${WHITE}🔌 $(T 'Token'): $(mv_tick "$DT_TOKEN")${RESET}"
echo
}

[[ "$HYSTERIA" == "ON" ]] && {
mv_deliv_sec "$(T 'HYSTERIA')"
echo -e "${WHITE}🌀 $(T 'Puerto'): $(mv_tick "$P_HYSTERIA")${RESET}"
[[ -n "$HY_PASSWORD" ]] && echo -e "${WHITE}🌀 $(T 'Contraseña'): $(mv_tick "$HY_PASSWORD")${RESET}"
[[ -n "$HY_OBFS" ]] && echo -e "${WHITE}🌀 $(T 'Obfuscación'): $(mv_tick "$HY_OBFS")${RESET}"
echo
}

[[ "$WG" == "ON" ]] && {
mv_deliv_sec "$(T 'WIREGUARD')"
echo -e "${WHITE}🔗 $(T 'Puerto'): $(mv_tick "$P_WG")${RESET}"
[[ -n "$WG_SERVER_PUB" ]] && echo -e "${WHITE}🔗 $(T 'Server Public Key'): $(mv_tick "$WG_SERVER_PUB")${RESET}"
echo -e "${WHITE}🔗 $(T 'Network'): $(mv_tick '10.66.66.1/24')${RESET}"
echo
}

[[ "$SYSTEMDNS" == "ON" ]] && {
mv_deliv_sec "$(T 'SYSTEMDNS')"
echo -e "${WHITE}🧬 $(T 'Puerto'): $(mv_tick '53')${RESET}"
echo -e "${WHITE}🧬 $(T 'Servicio'): $(mv_tick 'systemd-resolved')${RESET}"
echo
}

[[ "$XHTTP" == "ON" ]] && {
mv_deliv_sec "$(T 'SSH-XHTTP')"
echo -e "${WHITE}🚀 $(T 'Tipo'): $(mv_tick "$(T 'SSH-XHTTP (Server publish)')")${RESET}"
echo -e "${WHITE}🚀 $(T 'Servidor'): $(mv_tick "$IP")${RESET} · $(T 'Puerto'): $(mv_tick "$P_XHTTP")${RESET}"
echo -e "${WHITE}🚀 $(T 'SNI'): $(mv_tick "$XHTTP_HOST_V")${RESET}"
echo -e "${WHITE}🚀 $(T 'Payload'): $(mv_tick "$(T 'vacío (HTTP/2 directo)')")${RESET}"
echo
}

[[ "$BHTTP" == "ON" ]] && {
mv_deliv_sec "$(T 'BHTTP v2')"
echo -e "${WHITE}📡 $(T 'Tipo'): $(mv_tick "$(T 'SSH-BHTTP v2 (Server publish)')")${RESET}"
echo -e "${WHITE}📡 $(T 'Servidor'): $(mv_tick "$IP")${RESET} · $(T 'Puertos'): $(mv_tick "$P_BHTTP")${RESET}"
echo -e "${WHITE}📡 $(T 'Host/SNI'): $(mv_tick "$BHTTP_HOST_V")${RESET}"
echo -e "${WHITE}📡 $(T 'Payload'): $(mv_tick "GET / HTTP/1.1[crlf]Host: $BHTTP_HOST_V[crlf][crlf]")${RESET}"
echo
}

[[ "$BTUN" == "ON" ]] && {
mv_deliv_sec "$(T 'BTUN')"
echo -e "${WHITE}🧵 $(T 'Modo'): $(mv_tick "$(T 'VPN / Túnel (BTUN)')")${RESET}"
echo -e "${WHITE}🧵 $(T 'Servidor'): $(mv_tick "$IP")${RESET} · $(T 'Puerto'): $(mv_tick "$P_BTUN (TCP+UDP)")${RESET}"
echo -e "${WHITE}🧵 $(T 'Subred'): $(mv_tick '10.77.0.0/16')${RESET}"
[[ -n "$BTUN_USER" ]] && echo -e "${WHITE}🧵 $(T 'Usuario'): $(mv_tick "$BTUN_USER")${RESET}"
[[ -n "$BTUN_PASS" ]] && echo -e "${WHITE}🧵 $(T 'Clave'): $(mv_tick "$BTUN_PASS")${RESET}"
echo
}

[[ "$SHADOWSOCKS" == "ON" ]] && {
mv_deliv_sec "$(T 'SHADOWSOCKS')"
echo -e "${WHITE}🐋 $(T 'Servidor'): $(mv_tick "$IP:${P_SS}")${RESET}"
[[ -n "$SS_PASSWORD" ]] && echo -e "${WHITE}🐋 $(T 'Clave'): $(mv_tick "$SS_PASSWORD")${RESET}"
echo -e "${WHITE}🐋 $(T 'Método'): $(mv_tick 'aes-256-gcm')${RESET}"
[[ -n "$SS_URL" ]] && echo -e "${WHITE}🐋 $(T 'URL'): $(mv_tick "$SS_URL")${RESET}"
echo
}

[[ "$PAYLOAD" == "ON" ]] && {
mv_deliv_sec "$(T 'PAYLOAD SERVERS')"
echo -e "${WHITE}🧩 PDirect: $(mv_tick "${PAY_PDIRECT:-8083}")${RESET} · PGet: $(mv_tick "${PAY_GET:-8799}")${RESET}"
echo -e "${WHITE}🧩 POpen: $(mv_tick "${PAY_OPEN:-8082}")${RESET} · PPriv: $(mv_tick "${PAY_PRIV:-8084}")${RESET} · PPub: $(mv_tick "${PAY_PUB:-8085}")${RESET}"
[[ -n "$PAY_MASTER" ]] && echo -e "${WHITE}🧩 Master PGet: $(mv_tick "$PAY_MASTER")${RESET}"
[[ -n "$PAY_TEMP" ]] && echo -e "${WHITE}🧩 127.0.0.1:22: $(mv_tick "$PAY_TEMP")${RESET}"
echo -e "${WHITE}🧩 $(T 'Payload'): $(mv_tick "GET / HTTP/1.1[crlf]Host: $IP[crlf][crlf]")${RESET}"
echo
}

[[ "$OPENVPN" == "ON" ]] && {
mv_deliv_sec "$(T 'OPENVPN')"
echo -e "${WHITE}🛡 $(T 'Servidor'): $(mv_tick "$IP")${RESET} · $(T 'Puerto'): $(mv_tick "UDP $P_OPENVPN")${RESET}"
echo -e "${WHITE}🛡 $(T 'Protocolo'): $(mv_tick 'UDP · AES-256-CBC · SHA256')${RESET}"
echo -e "${WHITE}🛡 $(T 'Autenticación'): $(mv_tick "$(T 'usuario + contraseña + certificado')")${RESET}"
echo -e "${WHITE}🛡 $(T 'Apps'): $(mv_tick "$(T 'OpenVPN Connect, KPN, HTTP Injector (OpenVPN)')")${RESET}"
echo -e "${WHITE}🛡 $(T 'Importar'): $(mv_tick "$(T 'archivo .ovpn del usuario (Protocolos ↑ OpenVPN)')")${RESET}"
echo
}

[[ "$SOCKS5" == "ON" ]] && {
mv_deliv_sec "$(T 'SOCKS5 PROXY')"
echo -e "${WHITE}🎯 $(T 'Servidor'): $(mv_tick "$IP")${RESET} · $(T 'Puerto'): $(mv_tick "$P_SOCKS5 (TCP)")${RESET}"
echo -e "${WHITE}🎯 $(T 'Autenticación'): $(mv_tick "$(T 'usuario + contraseña (misma cuenta)')")${RESET}"
echo -e "${WHITE}🎯 $(T 'Apps'): $(mv_tick "$(T 'HTTP Injector (SOCKS5), Orbot, ProxyDroid')")${RESET}"
echo -e "${WHITE}🎯 $(T 'Nota'): $(mv_tick "$(T 'tráfico no cifrado, solo autenticado')")${RESET}"
echo
}

[[ "$HCR" == "ON" ]] && {
mv_deliv_sec "$(T 'HCR RELAY (HTTP CORE)')"
echo -e "${WHITE}🚀 $(T 'Método'): $(mv_tick "$(T 'SSL/TLS + transporte HCR (HTTP Core Relay)')")${RESET}"
echo -e "${WHITE}🚀 $(T 'Servidor'): $(mv_tick "${SERVER_DOMAIN:-$IP}")${RESET} · $(T 'Puerto'): $(mv_tick '443 (TLS)')${RESET}"
echo -e "${WHITE}🚀 $(T 'SNI'): $(mv_tick "$HCR_SNI_VALUE")${RESET}"
echo -e "${WHITE}🚀 $(T 'User'): $(mv_tick "$USER")${RESET} · $(T 'Pass'): $(mv_tick "$PASS")${RESET}"
echo -e "${WHITE}🚀 $(T 'App'): $(mv_tick 'HTTP Custom')${RESET} ${GRAY}$(T '(transporte HCR · SSL/TLS ON)')${RESET}"
echo
}

[[ "$ONLINEAPP" == "ON" ]] && {
mv_deliv_sec "$(T 'ONLINEAPP (BOT GENERADOR)')"
echo -e "${WHITE}🤖 $(T 'URL'): $(mv_tick "http://$IP:$P_ONLINEAPP/server/online")${RESET}"
echo -e "${WHITE}🤖 $(T 'URL app'): $(mv_tick "http://$IP:$P_ONLINEAPP/server/online_app")${RESET}"
echo -e "${WHITE}🤖 $(T 'Nota'): $(mv_tick "$(T 'genera cuentas SSH/túneles para tus clientes')")${RESET}"
echo
}

mv_line
mv_deliv_sec "$(T 'PAYLOADS AVANZADOS CLOUDFLARE')"
echo -e "${WHITE}1. $(T 'Normal WS (Puerto 80)')${RESET}"
echo -e "${GREEN}$(mv_tick "GET / HTTP/1.1[crlf]Host: ${PAYLOAD_HOST}[crlf]Upgrade: websocket[crlf]Connection: Keep-Alive[crlf][crlf]")${RESET}"
echo
echo -e "${WHITE}2. $(T 'WSS / TLS (Puerto 443 SNI)')${RESET}"
echo -e "${GREEN}$(mv_tick "GET wss://${PAYLOAD_HOST}/ HTTP/1.1[crlf]Host: ${PAYLOAD_HOST}[crlf]Upgrade: Websocket[crlf]Connection: Keep-Alive[crlf][crlf]")${RESET}"
echo
echo -e "${WHITE}3. $(T 'HTTP Injector (Modo SNI / Payload)')${RESET}"
echo -e "${GREEN}$(mv_tick "[method] [host_port] HTTP/1.1[crlf]Host: ${PAYLOAD_HOST}[crlf]Upgrade: websocket[crlf]Connection: Keep-Alive[crlf][crlf]")${RESET}"
echo

mv_line
movivip_contacts 2>/dev/null || {
echo -e "${WHITE}📣 $(T 'Canal'): ${GREEN}@MoviVIPNetwork${RESET}"
echo -e "${WHITE}💬 $(T 'Grupo'): ${GREEN}@MoviVIPNet${RESET}"
echo -e "${WHITE}📍 $(T 'Store'): ${GREEN}movivip-network.web.app${RESET}"
}
mv_line
echo -e "${GREEN}🙏 $(T 'Gracias por ser parte de MoviVIP Network!') 🔥${RESET}"
echo

echo

read -rp "$(echo -e "${YELLOW}¿$(T 'Desea crear otro usuario?') [S/N]: ${RESET}")" RESP

case "$RESP" in
    s|S|si|SI|sí|Sí|y|Y)
        continue
        ;;
    *)
        break
        ;;
esac

done