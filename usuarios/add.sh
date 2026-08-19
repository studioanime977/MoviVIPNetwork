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

# Cargar idioma
if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)"
fi

while true; do

clear

echo -e "${CYAN}â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—${RESET}"
echo -e "${CYAN}â•‘${MAGENTA}               âšœï¸ MoviVIP Network âšœï¸                ${CYAN}â•‘${RESET}"
echo -e "${CYAN}â•‘${WHITE}                   CREAR USUARIO SSH                    ${CYAN}â•‘${RESET}"
echo -e "${CYAN}â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${RESET}"
echo

read -rp "$(echo -e "${GREEN}ðŸ‘¤ Usuario               : ${RESET}")" USER

if [[ -z "$USER" ]]; then
    echo
    echo -e "${RED}âŒ Debe ingresar un nombre de usuario.${RESET}"
    sleep 2
    continue
fi

if id "$USER" &>/dev/null; then
    echo
    echo -e "${RED}âŒ El usuario ya existe.${RESET}"
    sleep 2
    continue
fi

read -rp "$(echo -e "${GREEN}ðŸ”‘ ContraseÃ±a            : ${RESET}")" PASS
echo

if [[ -z "$PASS" ]]; then
    echo
    echo -e "${RED}âŒ Debe ingresar una contraseÃ±a.${RESET}"
    sleep 2
    continue
fi

read -rp "$(echo -e "${GREEN}ðŸ“… DuraciÃ³n (dÃ­as)       : ${RESET}")" DIAS

[[ -z "$DIAS" ]] && DIAS=30

read -rp "$(echo -e "${GREEN}ðŸ‘¥ LÃ­mite (0=Ilimitado) : ${RESET}")" LIMITE

[[ -z "$LIMITE" ]] && LIMITE=0

if ! [[ "$LIMITE" =~ ^[0-9]+$ ]]; then
    echo
    echo -e "${RED}âŒ El lÃ­mite debe ser un nÃºmero.${RESET}"
    sleep 2
    continue
fi

if [[ "$LIMITE" -eq 0 ]]; then
    LIMITE_MOSTRAR="â™¾ Ilimitado"
else
    LIMITE_MOSTRAR="$LIMITE"
fi

#==================================================
# LÃMITE DE CONSUMO (DATOS) â€” 100GB/200GB/500GB/800GB/1TB/â™¾
#==================================================

echo
echo -e "${YELLOW}â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—${RESET}"
echo -e "${YELLOW}â•‘        ðŸ“¦ LÃMITE DE CONSUMO (DATOS)                  â•‘${RESET}"
echo -e "${YELLOW}â• â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•£${RESET}"
echo -e "${GREEN}[1]${WHITE} 100 GB"
echo -e "${GREEN}[2]${WHITE} 200 GB"
echo -e "${GREEN}[3]${WHITE} 500 GB"
echo -e "${GREEN}[4]${WHITE} 800 GB"
echo -e "${GREEN}[5]${WHITE} 1 TB"
echo -e "${GREEN}[6]${WHITE} â™¾ Ilimitado"
echo -e "${CYAN}â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${RESET}"

read -rp "$(echo -e "${GREEN}ðŸ“¦ LÃ­mite de consumo [6]: ${RESET}")" OPC_CONSUMO

[[ -z "$OPC_CONSUMO" ]] && OPC_CONSUMO=6

case "$OPC_CONSUMO" in
    1) CONSUMO_BYTES=107374182400; CONSUMO_MOSTRAR="100 GB" ;;
    2) CONSUMO_BYTES=214748364800; CONSUMO_MOSTRAR="200 GB" ;;
    3) CONSUMO_BYTES=536870912000; CONSUMO_MOSTRAR="500 GB" ;;
    4) CONSUMO_BYTES=858993459200; CONSUMO_MOSTRAR="800 GB" ;;
    5) CONSUMO_BYTES=1099511627776; CONSUMO_MOSTRAR="1 TB" ;;
    6|0) CONSUMO_BYTES=0; CONSUMO_MOSTRAR="â™¾ Ilimitado" ;;
    *)
        echo
        echo -e "${RED}âŒ OpciÃ³n invÃ¡lida.${RESET}"
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
    echo -e "${RED}âŒ Error al crear el usuario.${RESET}"
    sleep 3
    continue
fi

# Establecer contrasena sin validacion PAM (compatible ARM)
HASH=$(openssl passwd -6 "$PASS" 2>/dev/null)
usermod -p "$HASH" "$USER"

if [[ $? -ne 0 ]]; then
    echo
    echo -e "${RED}âŒ Error al establecer la contraseÃ±a.${RESET}"
    userdel -f "$USER" &>/dev/null
    sleep 3
    continue
fi

#==================================================
# GUARDAR LÃMITE DE CONSUMO
# (0 = ilimitado; formato USUARIO=BYTES)
#==================================================

LIM_CONF="$BASE/sistema/limites_consumo.conf"
mkdir -p "$BASE/sistema" 2>/dev/null
touch "$LIM_CONF" 2>/dev/null

# Eliminar entrada previa (si el usuario existÃ­a) y escribir la nueva
grep -v "^$USER=" "$LIM_CONF" > "$LIM_CONF.tmp" 2>/dev/null
mv "$LIM_CONF.tmp" "$LIM_CONF" 2>/dev/null
echo "$USER=$CONSUMO_BYTES" >> "$LIM_CONF"

#==================================================
# GUARDAR LÃMITE DE CONEXIONES SIMULTÃNEAS
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
# INFORMACIÃ“N DEL SERVIDOR
#==================================================

clear

IP=$(curl -4 -s ifconfig.me 2>/dev/null)

[[ -z "$IP" ]] && IP=$(hostname -I | awk '{print $1}')

HOST="${SERVER_DOMAIN:-$IP}"

FECHA_MOSTRAR=$(date -d "$FECHA" +"%d/%m/%Y")

#==================================================
# PREPARAR LÃMITE
#==================================================

if [[ "$LIMITE" == "0" ]]; then
    LIMITE_MOSTRAR="â™¾ Ilimitado"
else
    LIMITE_MOSTRAR="$LIMITE ConexiÃ³n(es)"
fi

if [[ "$CONSUMO_BYTES" == "0" ]]; then
    CONSUMO_MOSTRAR="â™¾ Ilimitado"
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
[[ "$OPENSSH"   == "ON" ]] && P_SSH="22"       || P_SSH="âœ–"
[[ "$DROPBEAR"  == "ON" ]] && P_DROPBEAR="${DROPBEAR_PORT:-143}" || P_DROPBEAR="âœ–"
[[ "$SSL"       == "ON" ]] && P_SSL="443 | 8443" || P_SSL="âœ–"
[[ "$BADVPN"    == "ON" ]] && P_BADVPN="7300"   || P_BADVPN="âœ–"
[[ "$UDP_CUSTOM" == "ON" ]] && P_UDP="9900"      || P_UDP="âœ–"
[[ "$ZIPVPN"    == "ON" ]] && P_ZIP="${ZIPVPN_PORT:-24075}" || P_ZIP="âœ–"
[[ "$WEBSOCKET" == "ON" ]] && P_HTTP="80"       || P_HTTP="âœ–"
[[ "$WEBSOCKET" == "ON" ]] && P_WS="8080"       || P_WS="âœ–"
[[ "$WEBSOCKET" == "ON" ]] && P_WSS="8880"      || P_WSS="âœ–"

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

echo -e "${CYAN}â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—${RESET}"
echo -e "${CYAN}â•‘${MAGENTA}               âšœï¸ MoviVIP Network âšœï¸                ${CYAN}â•‘${RESET}"
echo -e "${CYAN}â•‘${WHITE}               CUENTA SSH CREADA CON Ã‰XITO                ${CYAN}â•‘${RESET}"
echo -e "${CYAN}â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${RESET}"
echo

echo -e "${YELLOW}               ðŸ‘¤ INFORMACIÃ“N DE LA CUENTA${RESET}"
echo -e "${CYAN}â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”${RESET}"
printf "${WHITE}â”‚ ðŸ‘¤ Usuario      : ${GREEN}%-35s${WHITE}â”‚\n" "$USER"
printf "${WHITE}â”‚ ðŸ”‘ ContraseÃ±a   : ${GREEN}%-35s${WHITE}â”‚\n" "$PASS"
printf "${WHITE}â”‚ ðŸ“… Expira       : ${GREEN}%-35s${WHITE}â”‚\n" "$FECHA_MOSTRAR"
printf "${WHITE}â”‚ ðŸ‘¥ LÃ­mite       : ${GREEN}%-35s${WHITE}â”‚\n" "$LIMITE_MOSTRAR"
printf "${WHITE}â”‚ ðŸ“¦ Consumo MÃ¡x  : ${GREEN}%-35s${WHITE}â”‚\n" "$CONSUMO_MOSTRAR"
echo -e "${CYAN}â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜${RESET}"
echo

echo -e "${RED}âš ï¸  ESTOS SERVIDORES SON 100% GRATIS${RESET}"
echo -e "${RED}ðŸš« NO COMPRES â€” Nadie tiene derecho a cobrar por estas cuentas.${RESET}"
echo -e "${RED}ðŸ“¢ Si alguien te cobra, reportalo inmediatamente.${RESET}"
echo -e "${CYAN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${RESET}"
echo

echo -e "${WHITE}ðŸ–¥  Servidor: ${GREEN}${SERVER_DOMAIN:-$IP}${RESET}"
[[ -n "$CLOUDFRONT_DOMAIN" ]] && echo -e "${WHITE}â˜ï¸  Cloudflare: ${GREEN}$CLOUDFRONT_DOMAIN${RESET}"
[[ -n "$NOIP_DOMAIN" ]]      && echo -e "${WHITE}ðŸŒ No-IP: ${GREEN}$NOIP_DOMAIN${RESET}"
echo -e "${WHITE}ðŸ’»  CPU: ${GREEN}$CPU_MODEL${RESET}"
echo -e "${WHITE}ðŸ”¥  Uso CPU: ${GREEN}$CPU_USO${RESET}     â–ˆâ–ˆâ–‘â–‘â–‘â–‘â–‘â–‘â–‘"
echo -e "${WHITE}ðŸ“Ÿ  RAM: ${GREEN}$RAM_USO${WHITE} (${GREEN}$RAM_PCT%${WHITE}) â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–‘â–‘â–‘â–‘"
echo -e "${WHITE}ðŸ’¿  Disco: ${GREEN}$DISCO_USO${WHITE} / ${GREEN}$DISCO_TOTAL${WHITE} (${GREEN}$DISCO_PCT%${WHITE})"
echo -e "${WHITE}â±ï¸  Uptime: ${GREEN}$UPTIME${RESET}"
echo -e "${WHITE}ðŸ“Š  Carga: ${GREEN}$LOAD${RESET}"
echo

echo -e "${CYAN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${RESET}"
echo -e "${WHITE}ðŸŒ  IP Principal: ${GREEN}$IP${RESET}"
echo

echo -e "${YELLOW}ðŸ›°  PUERTOS SSH ACTIVOS${RESET}"
echo -e "${CYAN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${RESET}"
[[ "$OPENSSH"    == "ON" ]] && echo -e "${WHITE}ðŸ” SSH Directo: ${GREEN}ðŸŸ¢ $P_SSH${RESET}"
[[ "$DROPBEAR"   == "ON" ]] && echo -e "${WHITE}ðŸ» Dropbear: ${GREEN}ðŸŸ¢ $P_DROPBEAR${RESET}"
[[ "$SSL"        == "ON" ]] && echo -e "${WHITE}ðŸ”’ SSL/Stunnel: ${GREEN}ðŸŸ¢ $P_SSL${RESET}"
[[ "$BADVPN"     == "ON" ]] && echo -e "${WHITE}ðŸŽ® BadVPN UDPGW: ${GREEN}ðŸŸ¢ $P_BADVPN${RESET}"
[[ "$UDP_CUSTOM" == "ON" ]] && echo -e "${WHITE}ðŸŽ® UDP Custom: ${GREEN}ðŸŸ¢ $P_UDP${RESET}"
[[ "$ZIPVPN"     == "ON" ]] && echo -e "${WHITE}ðŸŽ® ZIPVPN: ${GREEN}ðŸŸ¢ $P_ZIP${RESET}"
[[ "$WEBSOCKET"  == "ON" ]] && echo -e "${WHITE}ðŸŒ HTTP/PDirect3: ${GREEN}ðŸŸ¢ $P_HTTP${RESET}"
[[ "$WEBSOCKET"  == "ON" ]] && echo -e "${WHITE}ðŸŒ WebSocket WS: ${GREEN}ðŸŸ¢ $P_WS${RESET}"
[[ "$WEBSOCKET"  == "ON" ]] && echo -e "${WHITE}ðŸŒ WebSocket WSS: ${GREEN}ðŸŸ¢ $P_WSS${RESET}"
echo

echo -e "${YELLOW}ðŸŒ CONEXIONES CDN / SNI${RESET}"
echo -e "${WHITE}â€¢ Cloudflare: ${GREEN}$CDN1${RESET}"
[[ -n "$CDN2" ]] && echo -e "${WHITE}â€¢ Cloudflare: ${GREEN}$CDN2${RESET}"
[[ -n "$CDN3" ]] && echo -e "${WHITE}â€¢ No-IP: ${GREEN}$CDN3${RESET}"
echo

if [[ -n "$NS_DNS" || -n "$KEY_DNS" ]]; then
echo -e "${YELLOW}ðŸ¢ SLOWDNS / NOIZ DNS${RESET}"
[[ -n "$NS_DNS" ]] && echo -e "${WHITE}â€¢ NS: ${GREEN}$NS_DNS${RESET}"
[[ -n "$KEY_DNS" ]] && echo -e "${WHITE}â€¢ Key: ${GREEN}$KEY_DNS${RESET}"
echo
fi

echo -e "${YELLOW}ðŸŒ WS TLS HTTP${RESET}"
echo -e "${WHITE}â€¢ WS: ${GREEN}ws://$IP:${P_HTTP:-80}${RESET}"
echo -e "${WHITE}â€¢ WSS: ${GREEN}wss://$IP:443${RESET}"
echo -e "${WHITE}â€¢ WS CDN: ${GREEN}ws://$IP:${P_WS:-8080}${RESET}"
echo

echo -e "${CYAN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${RESET}"
echo -e "${YELLOW}ðŸš€ PAYLOADS AVANZADOS CLOUDFLARE${RESET}"
echo -e "${WHITE}1. Normal WS (Puerto ${P_HTTP:-80})${RESET}"
echo -e "${GREEN}GET / HTTP/1.1[crlf]Host: ${CDN1}[crlf]Upgrade: websocket[crlf]Connection: Keep-Alive[crlf][crlf]${RESET}"
echo
echo -e "${WHITE}2. WSS / TLS (Puerto 443 SNI)${RESET}"
echo -e "${GREEN}GET wss://${CDN1}/ HTTP/1.1[crlf]Host: ${CDN1}[crlf]Upgrade: Websocket[crlf]Connection: Keep-Alive[crlf][crlf]${RESET}"
echo
echo -e "${WHITE}3. HTTP Injector (Modo SNI / Payload)${RESET}"
echo -e "${GREEN}[method] [host_port] HTTP/1.1[crlf]Host: ${CDN1}[crlf]Upgrade: websocket[crlf]Connection: Keep-Alive[crlf][crlf]${RESET}"
echo

echo -e "${CYAN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${RESET}"
echo -e "${WHITE}ðŸ’¬ SOPORTE${RESET}"
echo
echo -e "${GREEN}@MoviVIP${RESET}"
echo -e "${CYAN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${RESET}"
echo
echo -e "${WHITE}ðŸ“¢ Canal: ${GREEN}@MoviVIPNetwork${RESET}"
echo -e "${WHITE}ðŸ’¬ Grupo: ${GREEN}@MoviVIPNet${RESET}"
echo -e "${WHITE}ðŸŒ Store: ${GREEN}movivip-network.web.app${RESET}"
echo
echo -e "${GREEN}ðŸ™ Gracias por ser parte de MoviVIP Network! ðŸ”¥${RESET}"
echo

echo -e "${GREEN}â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—${RESET}"
echo -e "${GREEN}â•‘                  âœ… USUARIO CREADO EXITOSAMENTE            â•‘${RESET}"
echo -e "${GREEN}â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${RESET}"
echo

read -rp "$(echo -e "${YELLOW}Â¿Desea crear otro usuario? [S/N]: ${RESET}")" RESP

case "$RESP" in
    s|S|si|SI|sÃ­|SÃ­|y|Y)
        continue
        ;;
    *)
        break
        ;;
esac

done
