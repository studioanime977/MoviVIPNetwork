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

while true; do

clear

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${MAGENTA}               ⚜️ MoviVIP Network ⚜️                ${CYAN}║${RESET}"
echo -e "${CYAN}║${WHITE}                   CREAR USUARIO SSH                    ${CYAN}║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo

read -rp "$(echo -e "${GREEN}👤 Usuario               : ${RESET}")" USER

if [[ -z "$USER" ]]; then
    echo
    echo -e "${RED}❌ Debe ingresar un nombre de usuario.${RESET}"
    sleep 2
    continue
fi

if id "$USER" &>/dev/null; then
    echo
    echo -e "${RED}❌ El usuario ya existe.${RESET}"
    sleep 2
    continue
fi

read -rp "$(echo -e "${GREEN}🔑 Contraseña            : ${RESET}")" PASS
echo

if [[ -z "$PASS" ]]; then
    echo
    echo -e "${RED}❌ Debe ingresar una contraseña.${RESET}"
    sleep 2
    continue
fi

read -rp "$(echo -e "${GREEN}📅 Duración (días)       : ${RESET}")" DIAS

[[ -z "$DIAS" ]] && DIAS=30

read -rp "$(echo -e "${GREEN}👥 Límite (0=Ilimitado) : ${RESET}")" LIMITE

[[ -z "$LIMITE" ]] && LIMITE=0

if ! [[ "$LIMITE" =~ ^[0-9]+$ ]]; then
    echo
    echo -e "${RED}❌ El límite debe ser un número.${RESET}"
    sleep 2
    continue
fi

if [[ "$LIMITE" -eq 0 ]]; then
    LIMITE_MOSTRAR="♾ Ilimitado"
else
    LIMITE_MOSTRAR="$LIMITE"
fi

#==================================================
# LÍMITE DE CONSUMO (DATOS) — 100GB/200GB/500GB/800GB/1TB/♾
#==================================================

echo
echo -e "${YELLOW}╔══════════════════════════════════════════════════════╗${RESET}"
echo -e "${YELLOW}║        📦 LÍMITE DE CONSUMO (DATOS)                  ║${RESET}"
echo -e "${YELLOW}╠══════════════════════════════════════════════════════╣${RESET}"
echo -e "${GREEN}[1]${WHITE} 100 GB"
echo -e "${GREEN}[2]${WHITE} 200 GB"
echo -e "${GREEN}[3]${WHITE} 500 GB"
echo -e "${GREEN}[4]${WHITE} 800 GB"
echo -e "${GREEN}[5]${WHITE} 1 TB"
echo -e "${GREEN}[6]${WHITE} ♾ Ilimitado"
echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${RESET}"

read -rp "$(echo -e "${GREEN}📦 Límite de consumo [6]: ${RESET}")" OPC_CONSUMO

[[ -z "$OPC_CONSUMO" ]] && OPC_CONSUMO=6

case "$OPC_CONSUMO" in
    1) CONSUMO_BYTES=107374182400; CONSUMO_MOSTRAR="100 GB" ;;
    2) CONSUMO_BYTES=214748364800; CONSUMO_MOSTRAR="200 GB" ;;
    3) CONSUMO_BYTES=536870912000; CONSUMO_MOSTRAR="500 GB" ;;
    4) CONSUMO_BYTES=858993459200; CONSUMO_MOSTRAR="800 GB" ;;
    5) CONSUMO_BYTES=1099511627776; CONSUMO_MOSTRAR="1 TB" ;;
    6|0) CONSUMO_BYTES=0; CONSUMO_MOSTRAR="♾ Ilimitado" ;;
    *)
        echo
        echo -e "${RED}❌ Opción inválida.${RESET}"
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
    echo -e "${RED}❌ Error al crear el usuario.${RESET}"
    sleep 3
    continue
fi

# Establecer contrasena sin validacion PAM (compatible ARM)
HASH=$(openssl passwd -6 "$PASS" 2>/dev/null)
usermod -p "$HASH" "$USER"

if [[ $? -ne 0 ]]; then
    echo
    echo -e "${RED}❌ Error al establecer la contraseña.${RESET}"
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
    LIMITE_MOSTRAR="♾ Ilimitado"
else
    LIMITE_MOSTRAR="$LIMITE Conexión(es)"
fi

if [[ "$CONSUMO_BYTES" == "0" ]]; then
    CONSUMO_MOSTRAR="♾ Ilimitado"
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

#--- Puertos por protocolo (solo los activos) ---
[[ "$OPENSSH"   == "ON" ]] && P_SSH="22"       || P_SSH="✖"
[[ "$DROPBEAR"  == "ON" ]] && P_DROPBEAR="${DROPBEAR_PORT:-143}" || P_DROPBEAR="✖"
[[ "$SSL"       == "ON" ]] && P_SSL="443 | 8443" || P_SSL="✖"
[[ "$BADVPN"    == "ON" ]] && P_BADVPN="7300"   || P_BADVPN="✖"
[[ "$UDP_CUSTOM" == "ON" ]] && P_UDP="9900"      || P_UDP="✖"
[[ "$ZIPVPN"    == "ON" ]] && P_ZIP="${ZIPVPN_PORT:-24075}" || P_ZIP="✖"
[[ "$WEBSOCKET" == "ON" ]] && P_HTTP="80"       || P_HTTP="✖"
[[ "$WEBSOCKET" == "ON" ]] && P_WS="8080"       || P_WS="✖"
[[ "$WEBSOCKET" == "ON" ]] && P_WSS="8880"      || P_WSS="✖"

#--- Dominios CDN/SNI (Cloudflare, CloudFront, No-IP) ---
CDN1="${SERVER_DOMAIN:-$IP}"
CDN2="${CLOUDFRONT_DOMAIN:-}"
CDN3="${NOIP_DOMAIN:-}"

#--- SlowDNS / Noiz ---
NS_DNS="${SLOWDNS_NS:-}"
KEY_DNS="${SLOWDNS_KEY:-}"
[[ -z "$NS_DNS" && -n "$SERVER_DOMAIN" ]] && NS_DNS="ns.$SERVER_DOMAIN"

#==================================================
# MOSTRAR PLANTILLA DE ENTREGA COMPLETA
#==================================================

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${MAGENTA}               ⚜️ MoviVIP Network ⚜️                ${CYAN}║${RESET}"
echo -e "${CYAN}║${WHITE}               CUENTA SSH CREADA CON ÉXITO                ${CYAN}║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo

echo -e "${YELLOW}               👤 INFORMACIÓN DE LA CUENTA${RESET}"
echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${RESET}"
printf "${WHITE}│ 👤 Usuario      : ${GREEN}%-35s${WHITE}│\n" "$USER"
printf "${WHITE}│ 🔑 Contraseña   : ${GREEN}%-35s${WHITE}│\n" "$PASS"
printf "${WHITE}│ 📅 Expira       : ${GREEN}%-35s${WHITE}│\n" "$FECHA_MOSTRAR"
printf "${WHITE}│ 👥 Límite       : ${GREEN}%-35s${WHITE}│\n" "$LIMITE_MOSTRAR"
printf "${WHITE}│ 📦 Consumo Máx  : ${GREEN}%-35s${WHITE}│\n" "$CONSUMO_MOSTRAR"
echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${RESET}"
echo

echo -e "${RED}⚠️  ESTOS SERVIDORES SON 100% GRATIS${RESET}"
echo -e "${RED}🚫 NO COMPRES — Nadie tiene derecho a cobrar por estas cuentas.${RESET}"
echo -e "${RED}📢 Si alguien te cobra, reportalo inmediatamente.${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo

echo -e "${WHITE}🖥  Servidor: ${GREEN}${SERVER_DOMAIN:-$IP}${RESET}"
[[ -n "$CLOUDFRONT_DOMAIN" ]] && echo -e "${WHITE}☁️  Cloudflare: ${GREEN}$CLOUDFRONT_DOMAIN${RESET}"
[[ -n "$NOIP_DOMAIN" ]]      && echo -e "${WHITE}🌐 No-IP: ${GREEN}$NOIP_DOMAIN${RESET}"
echo -e "${WHITE}💻  CPU: ${GREEN}$CPU_MODEL${RESET}"
echo -e "${WHITE}🔥  Uso CPU: ${GREEN}$CPU_USO${RESET}     ██░░░░░░░"
echo -e "${WHITE}📟  RAM: ${GREEN}$RAM_USO${WHITE} (${GREEN}$RAM_PCT%${WHITE}) █████░░░░"
echo -e "${WHITE}💿  Disco: ${GREEN}$DISCO_USO${WHITE} / ${GREEN}$DISCO_TOTAL${WHITE} (${GREEN}$DISCO_PCT%${WHITE})"
echo -e "${WHITE}⏱️  Uptime: ${GREEN}$UPTIME${RESET}"
echo -e "${WHITE}📊  Carga: ${GREEN}$LOAD${RESET}"
echo

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}🌐  IP Principal: ${GREEN}$IP${RESET}"
echo

echo -e "${YELLOW}🛰  PUERTOS SSH ACTIVOS${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
[[ "$OPENSSH"    == "ON" ]] && echo -e "${WHITE}🔐 SSH Directo: ${GREEN}🟢 $P_SSH${RESET}"
[[ "$DROPBEAR"   == "ON" ]] && echo -e "${WHITE}🐻 Dropbear: ${GREEN}🟢 $P_DROPBEAR${RESET}"
[[ "$SSL"        == "ON" ]] && echo -e "${WHITE}🔒 SSL/Stunnel: ${GREEN}🟢 $P_SSL${RESET}"
[[ "$BADVPN"     == "ON" ]] && echo -e "${WHITE}🎮 BadVPN UDPGW: ${GREEN}🟢 $P_BADVPN${RESET}"
[[ "$UDP_CUSTOM" == "ON" ]] && echo -e "${WHITE}🎮 UDP Custom: ${GREEN}🟢 $P_UDP${RESET}"
[[ "$ZIPVPN"     == "ON" ]] && echo -e "${WHITE}🎮 ZIPVPN: ${GREEN}🟢 $P_ZIP${RESET}"
[[ "$WEBSOCKET"  == "ON" ]] && echo -e "${WHITE}🌐 HTTP/PDirect3: ${GREEN}🟢 $P_HTTP${RESET}"
[[ "$WEBSOCKET"  == "ON" ]] && echo -e "${WHITE}🌐 WebSocket WS: ${GREEN}🟢 $P_WS${RESET}"
[[ "$WEBSOCKET"  == "ON" ]] && echo -e "${WHITE}🌐 WebSocket WSS: ${GREEN}🟢 $P_WSS${RESET}"
echo

echo -e "${YELLOW}🌐 CONEXIONES CDN / SNI${RESET}"
echo -e "${WHITE}• Cloudflare: ${GREEN}$CDN1${RESET}"
[[ -n "$CDN2" ]] && echo -e "${WHITE}• Cloudflare: ${GREEN}$CDN2${RESET}"
[[ -n "$CDN3" ]] && echo -e "${WHITE}• No-IP: ${GREEN}$CDN3${RESET}"
echo

if [[ -n "$NS_DNS" || -n "$KEY_DNS" ]]; then
echo -e "${YELLOW}🐢 SLOWDNS / NOIZ DNS${RESET}"
[[ -n "$NS_DNS" ]] && echo -e "${WHITE}• NS: ${GREEN}$NS_DNS${RESET}"
[[ -n "$KEY_DNS" ]] && echo -e "${WHITE}• Key: ${GREEN}$KEY_DNS${RESET}"
echo
fi

echo -e "${YELLOW}🌐 WS TLS HTTP${RESET}"
echo -e "${WHITE}• WS: ${GREEN}ws://$IP:${P_HTTP:-80}${RESET}"
echo -e "${WHITE}• WSS: ${GREEN}wss://$IP:443${RESET}"
echo -e "${WHITE}• WS CDN: ${GREEN}ws://$IP:${P_WS:-8080}${RESET}"
echo

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${YELLOW}🚀 PAYLOADS AVANZADOS CLOUDFLARE${RESET}"
echo -e "${WHITE}1. Normal WS (Puerto ${P_HTTP:-80})${RESET}"
echo -e "${GREEN}GET / HTTP/1.1[crlf]Host: ${CDN1}[crlf]Upgrade: websocket[crlf]Connection: Keep-Alive[crlf][crlf]${RESET}"
echo
echo -e "${WHITE}2. WSS / TLS (Puerto 443 SNI)${RESET}"
echo -e "${GREEN}GET wss://${CDN1}/ HTTP/1.1[crlf]Host: ${CDN1}[crlf]Upgrade: Websocket[crlf]Connection: Keep-Alive[crlf][crlf]${RESET}"
echo
echo -e "${WHITE}3. HTTP Injector (Modo SNI / Payload)${RESET}"
echo -e "${GREEN}[method] [host_port] HTTP/1.1[crlf]Host: ${CDN1}[crlf]Upgrade: websocket[crlf]Connection: Keep-Alive[crlf][crlf]${RESET}"
echo

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}💬 SOPORTE${RESET}"
echo
echo -e "${GREEN}@MoviVIP${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo
echo -e "${WHITE}📢 Canal: ${GREEN}@MoviVIPNetwork${RESET}"
echo -e "${WHITE}💬 Grupo: ${GREEN}@MoviVIPNet${RESET}"
echo -e "${WHITE}🌐 Store: ${GREEN}movivip-network.web.app${RESET}"
echo
echo -e "${GREEN}🙏 Gracias por ser parte de MoviVIP Network! 🔥${RESET}"
echo

echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}║                  ✅ USUARIO CREADO EXITOSAMENTE            ║${RESET}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo

read -rp "$(echo -e "${YELLOW}¿Desea crear otro usuario? [S/N]: ${RESET}")" RESP

case "$RESP" in
    s|S|si|SI|sí|Sí|y|Y)
        continue
        ;;
    *)
        break
        ;;
esac

done
