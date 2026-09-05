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

while true; do

clear

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${MAGENTA}               ◎ MoviVIP Network ◎                ${CYAN}║${RESET}"
echo -e "${CYAN}║${WHITE}                   $(T 'CREAR USUARIO SSH')                    ${CYAN}║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo

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

read -rp "$(echo -e "${GREEN}$(T '📅 Duración (días)')       : ${RESET}")" DIAS

[[ -z "$DIAS" ]] && DIAS=30

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
# LÍMITE DE CONSUMO (DATOS) — 100GB/200GB/500GB/800GB/1TB/♾️
#==================================================

echo
echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${YELLOW}║        📊 $(T 'LÍMITE DE CONSUMO (DATOS)')                  ║${RESET}"
echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════╝${RESET}"
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

FECHA=$(date -d "+$DIAS days" +"%Y-%m-%d")
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

FECHA_MOSTRAR=$(date -d "$FECHA" +"%d/%m/%Y")

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
[[ "$WEBMIN"      == "ON" ]] && P_WEBMIN="${WEBMIN_PORT:-10000}"          || P_WEBMIN="✘"

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

#--- Host para payloads: dominio de regalo MoviVIP ---
PAYLOAD_HOST="${CLOUDFRONT_DOMAIN:-movivipregalo.movivipoppax.uk}"

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

#==================================================
# MOSTRAR PLANTILLA DE ENTREGA COMPLETA
#==================================================

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${MAGENTA}               ◎ MoviVIP Network ◎                ${CYAN}║${RESET}"
echo -e "${CYAN}║${WHITE}               $(T 'CUENTA SSH CREADA CON ÉXITO')                ${CYAN}║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo

echo -e "${YELLOW}               👤 $(T 'INFORMACIÓN DE LA CUENTA')${RESET}"
echo -e "${CYAN}────────────────────────────────────────────────────────────────${RESET}"
printf "${WHITE}┌ 👤 $(T 'Usuario')      : ${GREEN}%-35s${WHITE}┐\n" "$USER"
printf "${WHITE}│ 🔑 $(T 'Contraseña')   : ${GREEN}%-35s${WHITE}│\n" "$PASS"
printf "${WHITE}│ 📅 $(T 'Expira')       : ${GREEN}%-35s${WHITE}│\n" "$FECHA_MOSTRAR"
printf "${WHITE}│ 🌐 $(T 'Límite')       : ${GREEN}%-35s${WHITE}│\n" "$LIMITE_MOSTRAR"
printf "${WHITE}│ 📊 $(T 'Consumo Máx')  : ${GREEN}%-35s${WHITE}│\n" "$CONSUMO_MOSTRAR"
echo -e "${CYAN}└──────────────────────────────────────────────────────────────┘${RESET}"
echo

echo -e "${RED}⚠️  $(T 'ESTOS SERVIDORES SON 100% GRATIS')${RESET}"
echo -e "${RED}🚫 $(T 'NO COMPRES — Nadie tiene derecho a cobrar por estas cuentas.')${RESET}"
echo -e "${RED}📢 $(T 'Si alguien te cobra, reportalo inmediatamente.')${RESET}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${RESET}"
echo

echo -e "${WHITE}🖥️  $(T 'Servidor'): ${GREEN}${SERVER_DOMAIN:-$IP}${RESET}"
[[ -n "$CLOUDFRONT_DOMAIN" ]] && echo -e "${WHITE}☁️  $(T 'Cloudflare'): ${GREEN}$CLOUDFRONT_DOMAIN${RESET}"
[[ -n "$NOIP_DOMAIN" ]]      && echo -e "${WHITE}📍 $(T 'No-IP'): ${GREEN}$NOIP_DOMAIN${RESET}"
echo -e "${WHITE}💻  CPU: ${GREEN}$CPU_MODEL${RESET}"
echo -e "${WHITE}🔥  $(T 'Uso CPU'): ${GREEN}$CPU_USO${RESET}     ██████████"
echo -e "${WHITE}📊  RAM: ${GREEN}$RAM_USO${WHITE} (${GREEN}$RAM_PCT%${WHITE}) ████████"
echo -e "${WHITE}💾  $(T 'Disco'): ${GREEN}$DISCO_USO${WHITE} / ${GREEN}$DISCO_TOTAL${WHITE} (${GREEN}$DISCO_PCT%${WHITE})"
echo -e "${WHITE}⏱️  $(T 'Uptime'): ${GREEN}$UPTIME${RESET}"
echo -e "${WHITE}📈  $(T 'Carga'): ${GREEN}$LOAD${RESET}"
echo

echo -e "${CYAN}════════════════════════════════════════════════════════════════${RESET}"
echo -e "${WHITE}📍  $(T 'IP Principal'): ${GREEN}$IP${RESET}"
echo

echo -e "${YELLOW}🛰️  $(T 'PUERTOS ACTIVOS (todos los protocolos)')${RESET}"
echo -e "${CYAN}────────────────────────────────────────────────────────────────${RESET}"
[[ "$OPENSSH"     == "ON" ]] && echo -e "${WHITE}🔑 $(T 'SSH Directo'): ${GREEN}► $P_SSH${RESET}"
[[ "$DROPBEAR"    == "ON" ]] && echo -e "${WHITE}🐻 $(T 'Dropbear'): ${GREEN}► $P_DROPBEAR${RESET}"
[[ "$SSL"         == "ON" ]] && echo -e "${WHITE}🔒 $(T 'SSL/Stunnel'): ${GREEN}► $P_SSL${RESET}"
[[ "$BADVPN"      == "ON" ]] && echo -e "${WHITE}🎮 $(T 'BadVPN UDPGW'): ${GREEN}► $P_BADVPN${RESET}"
[[ "$UDP_CUSTOM"  == "ON" ]] && echo -e "${WHITE}⚡ $(T 'UDP Custom'): ${GREEN}► $P_UDP${RESET}"
[[ "$ZIPVPN"      == "ON" ]] && echo -e "${WHITE}📦 $(T 'ZIPVPN'): ${GREEN}► $P_ZIP${RESET}"
[[ -n "$P_DTUNNEL" && "$P_DTUNNEL" != "✘" ]] && echo -e "${WHITE}🔌 $(T 'DTunnel'): ${GREEN}► $P_DTUNNEL${RESET}"
[[ "$V2RAY"       == "ON" ]] && echo -e "${WHITE}🚀 $(T 'v2ray (VLESS/VMess/Trojan)'): ${GREEN}► $P_XRAY${RESET}"
[[ "$HYSTERIA"    == "ON" ]] && echo -e "${WHITE}🌀 $(T 'Hysteria'): ${GREEN}► $P_HYSTERIA${RESET}"
[[ "$SQUID"       == "ON" ]] && echo -e "${WHITE}🦑 $(T 'Squid Proxy'): ${GREEN}► $P_SQUID${RESET}"
[[ "$WG"          == "ON" ]] && echo -e "${WHITE}🔗 $(T 'WireGuard'): ${GREEN}► $P_WG${RESET}"
[[ "$WEBMIN"      == "ON" ]] && echo -e "${WHITE}🌐 $(T 'Webmin Panel'): ${GREEN}► https://$IP:$P_WEBMIN${RESET}"
[[ "$WEBSOCKET"   == "ON" ]] && echo -e "${WHITE}🌐 $(T 'HTTP/PDirect3'): ${GREEN}► $P_HTTP${RESET}"
[[ "$WEBSOCKET"   == "ON" ]] && echo -e "${WHITE}🌐 $(T 'WebSocket WS'): ${GREEN}► $P_WS${RESET}"
[[ "$WEBSOCKET"   == "ON" ]] && echo -e "${WHITE}🌐 $(T 'WebSocket WSS'): ${GREEN}► $P_WSS${RESET}"
[[ "$SLOWDNS"     == "ON" ]] && echo -e "${WHITE}🐌 $(T 'SlowDNS (NS/Key abajo)'): ${GREEN}► DNS 53 / DNSTT 5300${RESET}"
echo

echo -e "${YELLOW}🐌 $(T 'SLOWDNS / NOIZ DNS')${RESET}"
echo -e "${WHITE}• $(T 'NS'): ${GREEN}${NS_DNS:-$(T 'No configurado')}${RESET}"
echo -e "${WHITE}• $(T 'Key'): ${GREEN}${KEY_DNS:-$(T 'No configurado')}${RESET}"
echo -e "${WHITE}• $(T 'Puertos DNS'): ${GREEN}53 / 5300${RESET}"
echo

if [[ -n "$P_DTUNNEL" && "$P_DTUNNEL" != "✘" ]]; then
echo -e "${YELLOW}🔌 $(T 'DTUNNEL')${RESET}"
echo -e "${WHITE}• $(T 'Puertos'): ${GREEN}$P_DTUNNEL${RESET}"
[[ -n "$DT_TOKEN" ]] && echo -e "${WHITE}• $(T 'Token'): ${GREEN}$DT_TOKEN${RESET}"
echo
fi

if [[ "$HYSTERIA" == "ON" ]]; then
echo -e "${YELLOW}🌀 $(T 'HYSTERIA')${RESET}"
echo -e "${WHITE}• $(T 'Puerto'): ${GREEN}$P_HYSTERIA${RESET}"
[[ -n "$HY_PASSWORD" ]] && echo -e "${WHITE}• $(T 'Contraseña'): ${GREEN}$HY_PASSWORD${RESET}"
[[ -n "$HY_OBFS" ]] && echo -e "${WHITE}• $(T 'Obfuscación'): ${GREEN}$HY_OBFS${RESET}"
echo
fi

if [[ "$WG" == "ON" ]]; then
echo -e "${YELLOW}🔗 $(T 'WIREGUARD')${RESET}"
echo -e "${WHITE}• $(T 'Puerto'): ${GREEN}$P_WG${RESET}"
[[ -n "$WG_SERVER_PUB" ]] && echo -e "${WHITE}• $(T 'Server Public Key'): ${GREEN}$WG_SERVER_PUB${RESET}"
echo -e "${WHITE}• $(T 'Network'): ${GREEN}10.66.66.1/24${RESET}"
echo
fi

echo -e "${CYAN}════════════════════════════════════════════════════════════════${RESET}"
echo -e "${YELLOW}🚀 $(T 'PAYLOADS AVANZADOS CLOUDFLARE')${RESET}"
echo -e "${WHITE}1. $(T 'Normal WS (Puerto 80)')${RESET}"
echo -e "${GREEN}GET / HTTP/1.1[crlf]Host: ${PAYLOAD_HOST}[crlf]Upgrade: websocket[crlf]Connection: Keep-Alive[crlf][crlf]${RESET}"
echo
echo -e "${WHITE}2. $(T 'WSS / TLS (Puerto 443 SNI)')${RESET}"
echo -e "${GREEN}GET wss://${PAYLOAD_HOST}/ HTTP/1.1[crlf]Host: ${PAYLOAD_HOST}[crlf]Upgrade: Websocket[crlf]Connection: Keep-Alive[crlf][crlf]${RESET}"
echo
echo -e "${WHITE}3. $(T 'HTTP Injector (Modo SNI / Payload)')${RESET}"
echo -e "${GREEN}[method] [host_port] HTTP/1.1[crlf]Host: ${PAYLOAD_HOST}[crlf]Upgrade: websocket[crlf]Connection: Keep-Alive[crlf][crlf]${RESET}"
echo

echo -e "${CYAN}════════════════════════════════════════════════════════════════${RESET}"
echo -e "${WHITE}💬 $(T 'SOPORTE')${RESET}"
echo
echo -e "${GREEN}@MoviVIP${RESET}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${RESET}"
echo
echo -e "${WHITE}📣 $(T 'Canal'): ${GREEN}@MoviVIPNetwork${RESET}"
echo -e "${WHITE}💬 $(T 'Grupo'): ${GREEN}@MoviVIPNet${RESET}"
echo -e "${WHITE}📍 $(T 'Store'): ${GREEN}movivip-network.web.app${RESET}"
echo
echo -e "${GREEN}🙏 $(T 'Gracias por ser parte de MoviVIP Network!') 🔥${RESET}"
echo

echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}║                  ✅ $(T 'USUARIO CREADO EXITOSAMENTE')            ║${RESET}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${RESET}"
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