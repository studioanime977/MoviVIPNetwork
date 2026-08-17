#!/bin/bash

#=========================================================
#   MOVIVIP NETWORK — PREMIUM EDITION v5.0
#   Panel de Control · Alto Rendimiento y Seguridad Total
#   Diseño compacto tipo dashboard — 1 pantalla
#=========================================================

BASE="/etc/movivip"
CONFIG="$BASE/config.conf"
SISTEMA="$BASE/sistema"
STATE="$SISTEMA/network_state.conf"

#=========================================================
# Verificar configuración
#=========================================================

[[ ! -f "$CONFIG" ]] && {
    clear
    echo ""
    echo -e "\e[1;91m❌ No se encontró config.conf\e[0m"
    echo -e "\e[1;97m👉 Ejecuta primero install.sh\e[0m"
    echo ""
    exit 1
}

source "$CONFIG"

#=========================================================
# Cargar sistema de idiomas (multi-idioma 10 languages)
#=========================================================

if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    _current_lang="$(get_current_language)"
    load_language "$_current_lang"
fi
if [[ -f "$BASE/languages/protocols.sh" ]]; then
    source "$BASE/languages/protocols.sh"
fi

#=========================================================
# Colores premium MoviVIP (banner oficial)
#=========================================================

RESET="\e[0m"; RED="\e[1;91m"; GREEN="\e[1;92m"; GOLD="\e[1;93m"
BLUE="\e[1;94m"; MAGENTA="\e[1;95m"; CYAN="\e[1;96m"; WHITE="\e[1;97m"; GRAY="\e[1;90m"

#=========================================================
# Marco (ancho fijo)
#=========================================================

W=62
LINE(){ printf "${CYAN}"; printf '═%.0s' $(seq 1 $W); printf "${RESET}\n"; }
TOP(){ printf "${CYAN}╔"; printf '═%.0s' $(seq 1 $W); printf "╗${RESET}\n"; }
MID(){ printf "${CYAN}╠"; printf '═%.0s' $(seq 1 $W); printf "╣${RESET}\n"; }
BOT(){ printf "${CYAN}╚"; printf '═%.0s' $(seq 1 $W); printf "╝${RESET}\n"; }
BAR(){ printf "${CYAN}║${RESET}"; printf "%-$((W))s" ""; printf "${CYAN}║${RESET}\n"; }

#=========================================================
# Funciones
#=========================================================

status() {
    [[ "$1" == "ON" ]] && echo -e "${GREEN}●${RESET}" || echo -e "${RED}●${RESET}"
}

progress_bar() {
    local percent=$1
    local total=12
    local filled=$((percent*total/100))
    local empty=$((total-filled))
    [[ $filled -gt $total ]] && filled=$total
    printf "${GREEN}"
    for ((i=0;i<filled;i++)); do printf "█"; done
    printf "${GRAY}"
    for ((i=0;i<empty;i++)); do printf "░"; done
    printf "${RESET}"
}

human() {
    local B=$1
    [[ -z "$B" ]] && B=0
    if (( B >= 1000000000000 )); then
        echo "$((B/1000000000000)).$(((B%1000000000000)/10000000000))TB"
    elif (( B >= 1000000000 )); then
        echo "$((B/1000000000)).$(((B%1000000000)/10000000))GB"
    elif (( B >= 1000000 )); then
        echo "$((B/1000000)).$(((B%1000000)/10000))MB"
    elif (( B >= 1000 )); then
        echo "$((B/1000)).$(((B%1000)/10))KB"
    else
        echo "${B}B"
    fi
}

speed() {
    local V=$1
    [[ -z "$V" ]] && V=0
    local B=$(( V * 8 ))
    if (( B >= 1000000 )); then
        echo "$((B/1000000)).$(((B%1000000)/10000))Mbps"
    elif (( B >= 1000 )); then
        echo "$((B/1000)).$(((B%1000)/10))Kbps"
    else
        echo "${B}bps"
    fi
}

read_counters() {
    local C
    C=$(awk -v i="${IFACE}:" '$1==i {print $2, $10}' /proc/net/dev 2>/dev/null)
    RX_N=${C% *}; TX_N=${C#* }
    [[ -z "$RX_N" ]] && RX_N=0
    [[ -z "$TX_N" ]] && TX_N=0
}

get_iface() {
    if [[ -n "$NET_IFACE" ]]; then echo "$NET_IFACE"; return; fi
    local I
    I=$(ip route get 8.8.8.8 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')
    [[ -n "$I" ]] && echo "$I" && return
    I=$(ls /sys/class/net 2>/dev/null | grep -E '^(eth|ens|enp|eno)' | head -n1)
    echo "${I:-eth0}"
}

svc_exists() {
    [[ -f /etc/systemd/system/$1.service || -f /lib/systemd/system/$1.service || -f /usr/lib/systemd/system/$1.service ]]
}

svc_icon() {
    local N=$1 SVC=$2
    if [[ "${SVC_ARR[$((N-1))]}" == "active" ]]; then
        echo -e "${GREEN}●${RESET}"
    elif svc_exists "$SVC"; then
        echo -e "${RED}●${RESET}"
    else
        echo -e "${GRAY}○${RESET}"
    fi
}

#=========================================================
# Información del sistema
#=========================================================

OS=$(source /etc/os-release 2>/dev/null && echo "$NAME $VERSION_ID")
KERNEL=$(uname -r)
ARCH=$(uname -m)
CPU_CORES=$(nproc)
IP=$(hostname -I 2>/dev/null | awk '{print $1}')

PUB_CACHE="$SISTEMA/.pub_ip"
PUBLIC_IP="-"
if [[ -f "$PUB_CACHE" ]] && (( $(date +%s) - $(stat -c %Y "$PUB_CACHE" 2>/dev/null || echo 0) < 300 )); then
    PUBLIC_IP=$(cat "$PUB_CACHE")
else
    PUBLIC_IP=$(curl -s --max-time 1 ifconfig.me 2>/dev/null || echo "-")
    [[ "$PUBLIC_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && echo "$PUBLIC_IP" > "$PUB_CACHE" 2>/dev/null
fi
FECHA=$(date +"%d/%m/%Y %H:%M")

read -r TOTAL_RAM_MB USED_RAM_MB FREE_RAM_MB <<<"$(free -m | awk '/Mem:/{print $2, $3, $4}')"
TOTAL_RAM=${TOTAL_RAM_MB:-0}; USED_RAM=${USED_RAM_MB:-0}
RAM_USE=$(( TOTAL_RAM > 0 ? USED_RAM*100/TOTAL_RAM : 0 ))

CPU_READ_1=$(awk '/^cpu /{print $2+$3+$4+$5+$6+$7+$8+$9, $5+$6}' /proc/stat)
sleep 0.1
CPU_READ_2=$(awk '/^cpu /{print $2+$3+$4+$5+$6+$7+$8+$9, $5+$6}' /proc/stat)
TOT1=${CPU_READ_1% *}; IDL1=${CPU_READ_1#* }
TOT2=${CPU_READ_2% *}; IDL2=${CPU_READ_2#* }
CPU_USE=0
if [[ "$TOT2" != "$TOT1" ]]; then
    CPU_USE=$(( ( (TOT2-TOT1) - (IDL2-IDL1) ) * 100 / (TOT2-TOT1) ))
fi

DISK=$(df -h / | awk 'NR==2 {print $5}')
UPTIME=$(uptime -p | sed 's/up //')

IFACE=$(get_iface)
read_counters; R1=$RX_N; T1=$TX_N
T_START=$(date +%s%N)

#=========================================================
# Estado de seguridad
#=========================================================

if systemctl is-active --quiet fail2ban; then
    SEC_STATUS="${GREEN}●${RESET}"
    SEC_JAILS=$(fail2ban-client status 2>/dev/null | grep "Jail list" | sed 's/.*Jail list:[[:space:]]*//')
else
    SEC_STATUS="${RED}●${RESET}"
    SEC_JAILS="-"
fi

#=========================================================
# Consumo de red
#=========================================================

VPS_BASE_RX="${VPS_TRAFFIC_BASE_RX:-0}"
VPS_BASE_TX="${VPS_TRAFFIC_BASE_TX:-0}"
NET_TOTAL_IN="—"; NET_TOTAL_OUT="—"

if [[ -f "$STATE" ]]; then
    source "$STATE" 2>/dev/null
    [[ -z "${TOTAL_IN:-}" && -n "${ACC_RX:-}" ]] && TOTAL_IN="$ACC_RX"
    [[ -z "${TOTAL_OUT:-}" && -n "${ACC_TX:-}" ]] && TOTAL_OUT="$ACC_TX"
    TOTAL_IN="${TOTAL_IN:-0}"; TOTAL_OUT="${TOTAL_OUT:-0}"
    RX_TOTAL=$((VPS_BASE_RX + TOTAL_IN))
    TX_TOTAL=$((VPS_BASE_TX + TOTAL_OUT))
    NET_TOTAL_IN=$(human "$RX_TOTAL")
    NET_TOTAL_OUT=$(human "$TX_TOTAL")
else
    bash "$BASE/herramientas/network_snapshot.sh" >/dev/null 2>&1
    NET_TOTAL_IN=$(human "$VPS_BASE_RX")
    NET_TOTAL_OUT=$(human "$VPS_BASE_TX")
    RX_TOTAL="$VPS_BASE_RX"; TX_TOTAL="$VPS_BASE_TX"
fi
NET_TOTAL_SUM=$(human $((RX_TOTAL + TX_TOTAL)))

#=========================================================
# Estado de protocolos
#=========================================================

SVC_ARR=($(systemctl is-active ssh dropbear_custom haproxy udp-custom slowdns xray badvpn-udpgw-7200 zivpn 2>/dev/null))

SSH_S=$(svc_icon 1 ssh)
DROP_S=$(svc_icon 2 dropbear_custom)
HA_S=$(svc_icon 3 haproxy)
UDP_S=$(svc_icon 4 udp-custom)
SLOW_S=$(svc_icon 5 slowdns)
XRAY_S=$(svc_icon 6 xray)
BAD_S=$(svc_icon 7 badvpn-udpgw-7200)
ZIP_S=$(svc_icon 8 zivpn)

#=========================================================
# Conexiones en tiempo real
#=========================================================

SSH_CONN=$(ps -C sshd -o args= 2>/dev/null | grep -c "\[priv\]")
DROP_CONN=$(pgrep -x dropbear 2>/dev/null | wc -l)
[[ $DROP_CONN -gt 0 ]] && DROP_CONN=$((DROP_CONN - 1))
ONLINE_USERS=$(ps -C sshd -o args= 2>/dev/null | grep "\[priv\]" | awk -F'sshd: ' '{print $2}' | awk '{print $1}' | grep -vE '^(root|unknown|invalid|\(null\))$' | sort -u | wc -l)
TOTAL_CONN=$((SSH_CONN + DROP_CONN))

#=========================================================
# Estado CDN
#=========================================================

CF_STATUS_LIVE="OFF"
if [[ -n "$SERVER_DOMAIN" ]]; then
    _parent_domain=$(echo "$SERVER_DOMAIN" | awk -F. '{print $(NF-1)"."$NF}')
    CF_NS=$(dig +short NS "$_parent_domain" 2>/dev/null | grep -ci cloudflare)
    [[ "$CF_NS" -gt 0 ]] && CF_STATUS_LIVE="ON"
fi
[[ "${CLOUDFLARE_STATUS:-OFF}" == "ON" ]] && CF_STATUS_LIVE="ON"
NOIP_STATUS_LIVE="OFF"
if [[ -n "$NOIP_DOMAIN" ]]; then
    NOIP_STATUS_LIVE="ON"
elif [[ -n "$SERVER_DOMAIN" ]]; then
    _noip_check=$(dig +short A "$SERVER_DOMAIN" 2>/dev/null | head -1)
    if [[ -n "$_noip_check" && "$_noip_check" != "$IP" ]]; then
        NOIP_STATUS_LIVE="ON"
    fi
fi

#=========================================================
# Notificación de actualización (caché 6h)
#=========================================================

UPD_CACHE="/tmp/movivip_upd_check"
UPD_VER_FILE="/tmp/movivip_upd_ver"
UPD_NOW=$(date +%s)
if [[ ! -f "$UPD_CACHE" ]] || (( UPD_NOW - $(cat "$UPD_CACHE" 2>/dev/null || echo 0) > 21600 )); then
    UPD_RV=$(curl -fsSL --max-time 4 "https://api.github.com/repos/studioanime977/MoviVIPNetwork/contents/version.txt" 2>/dev/null \
        | grep -o '"content":"[^"]*"' | head -1 | cut -d'"' -f4 | base64 -d 2>/dev/null | tr -d ' \n')
    [[ -z "$UPD_RV" ]] && UPD_RV=$(curl -fsSL --max-time 4 "https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/version.txt" 2>/dev/null | tr -d ' \n')
    [[ -n "$UPD_RV" ]] && echo "$UPD_RV" > "$UPD_VER_FILE"
    echo "$UPD_NOW" > "$UPD_CACHE"
fi
UPD_RV=$(cat "$UPD_VER_FILE" 2>/dev/null)
UPD_LV=$(tr -d ' \n' < "$BASE/version.txt" 2>/dev/null)

#=========================================================
# PANTALLA — DASHBOARD PREMIUM v5.0
#=========================================================

clear
TOP
printf "${CYAN}║${GOLD}  ╔═╗╦═╗╦ ╦╔═╗╔╦╗╔═╗╔╗╔╔╦╗${RESET}  ${WHITE}MoviVIP Network${GRAY} v5.0${RESET}${CYAN}      ║${RESET}\n"
printf "${CYAN}║${GOLD}  ╠═╣╠╦╝╚╦╝║ ║ ║ ║╣ ║║║ ║ ${RESET}  ${GRAY}movivip-network.web.app${RESET}       ${CYAN}║${RESET}\n"
printf "${CYAN}║${GOLD}  ╩ ╩╩   ╩ ╚═╝ ╩ ╚═╝╝╚╝ ╩ ${RESET}  ${WHITE}${MENU_SUBTITLE:-Alto Rendimiento}${RESET}            ${CYAN}║${RESET}\n"
MID

# Notificación de actualización
if [[ -n "$UPD_RV" && -n "$UPD_LV" && "$UPD_RV" != "$UPD_LV" ]]; then
    UPD_MSG="${UPD_AVAILABLE:-⬆ v%s disponible} $(printf "${UPD_AVAILABLE:-⬆ v%s disponible}" "$UPD_RV") — menu [09]"
    printf "${CYAN}║${RESET} ${GOLD}⬆ v${UPD_RV} disponible${RESET} — menu [09] para actualizar${CYAN}%*s║${RESET}\n" $(( W - 48 - ${#UPD_RV} )) ""
    MID
fi

# SISTEMA
printf "${CYAN}║${RESET} ${GOLD}${MENU_SYSTEM:-SISTEMA}${RESET}  ${WHITE}${OS}${RESET} ${GRAY}·${RESET} ${WHITE}${CPU_CORES} ${MENU_CORES:-cores}${RESET} ${GRAY}·${RESET} ${WHITE}${ARCH}${RESET}${CYAN}%*s║${RESET}\n" $(( W - 28 - ${#OS} - ${#ARCH} )) ""
RAM_BAR=$(progress_bar "$RAM_USE")
CPU_BAR=$(progress_bar "$CPU_USE")
echo -e "${CYAN}║${RESET}  RAM ${RAM_BAR}${WHITE} ${RAM_USE}%${RESET} ${GRAY}(${USED_RAM}MB/${TOTAL_RAM}MB)${RESET}  CPU ${CPU_BAR}${WHITE} ${CPU_USE}%${RESET}  DISK ${WHITE}${DISK}${RESET}$(printf '%*s' 8 '')${CYAN}║${RESET}"
printf "${CYAN}║${RESET}  ${GRAY}Kernel${RESET} ${WHITE}${KERNEL}${RESET}  ${GRAY}·${RESET}  ${WHITE}${UPTIME}${RESET}  ${GRAY}·${RESET}  ${WHITE}${FECHA}${RESET}${CYAN}%*s║${RESET}\n" $(( W - 10 - ${#KERNEL} - ${#UPTIME} - ${#FECHA} )) ""
MID

# RED
printf "${CYAN}║${RESET} ${GOLD}${MENU_NETWORK:-RED}${RESET}  ${WHITE}${IP}${RESET} ${GRAY}·${RESET} Pub ${WHITE}${PUBLIC_IP}${RESET} ${GRAY}·${RESET} CF ${WHITE}$(status "$CF_STATUS_LIVE")${RESET} ${GRAY}·${RESET} No-IP ${WHITE}$(status "$NOIP_STATUS_LIVE")${RESET}${CYAN}%*s║${RESET}\n" $(( W - 40 - ${#IP} - ${#PUBLIC_IP} )) ""

read_counters; R2=$RX_N; T2=$TX_N
T_END=$(date +%s%N)
ELAPSED_MS=$(( (T_END - T_START) / 1000000 ))
[[ $ELAPSED_MS -lt 1 ]] && ELAPSED_MS=1
SPD_IN=$(( (R2 - R1) * 1000 / ELAPSED_MS )); [[ $SPD_IN -lt 0 ]] && SPD_IN=0
SPD_OUT=$(( (T2 - T1) * 1000 / ELAPSED_MS )); [[ $SPD_OUT -lt 0 ]] && SPD_OUT=0

printf "${CYAN}║${RESET}  ${GRAY}⬇${RESET} ${WHITE}$(speed "$SPD_IN")${RESET}  ${GRAY}⬆${RESET} ${WHITE}$(speed "$SPD_OUT")${RESET}  ${GRAY}| Total${RESET} ${GOLD}${NET_TOTAL_SUM}${RESET}${CYAN}%*s║${RESET}\n" $(( W - 28 )) ""
printf "${CYAN}║${RESET}  ${GRAY}⬇${RESET} ${WHITE}${NET_TOTAL_IN}${RESET}  ${GRAY}· ⬆${RESET} ${WHITE}${NET_TOTAL_OUT}${RESET}  ${GRAY}·${RESET} ${WHITE}${SERVER_DOMAIN:-NO-DOMAIN}${RESET}${CYAN}%*s║${RESET}\n" $(( W - 30 - ${#NET_TOTAL_IN} - ${#NET_TOTAL_OUT} - ${#SERVER_DOMAIN} )) ""
MID

# PROTOCOLOS
printf "${CYAN}║${RESET} ${GOLD}${MENU_PROTOCOLS:-PROTOCOLOS}${RESET}${CYAN}%*s║${RESET}\n" $(( W - 11 )) ""
printf "${CYAN}║${RESET}  ${SSH_S} OpenSSH ${GRAY}[22]${RESET}     ${HA_S} SSL/TLS ${GRAY}[443]${RESET}       ${CYAN}%*s║${RESET}\n" $(( W - 37 )) ""
printf "${CYAN}║${RESET}  ${DROP_S} Dropbear ${GRAY}[90]${RESET}    ${UDP_S} UDP-C ${GRAY}[2100]${RESET}      ${CYAN}%*s║${RESET}\n" $(( W - 38 )) ""
printf "${CYAN}║${RESET}  ${SLOW_S} SlowDNS ${GRAY}[5300]${RESET}   ${XRAY_S} Xray ${GRAY}[${XRAY_PORT:-443}]${RESET}          ${CYAN}%*s║${RESET}\n" $(( W - 40 )) ""
printf "${CYAN}║${RESET}  ${BAD_S} BadVPN ${GRAY}[7200]${RESET}    ${ZIP_S} ZiVPN ${GRAY}[5667]${RESET}        ${CYAN}%*s║${RESET}\n" $(( W - 38 )) ""
printf "${CYAN}║${RESET}  ${GRAY}·${RESET} ${MENU_ONLINE:-Online} ${GREEN}${ONLINE_USERS}${RESET}  ${GRAY}·${RESET} ${MENU_CONNECTIONS:-Conexiones} ${GREEN}${TOTAL_CONN}${RESET}${CYAN}%*s║${RESET}\n" $(( W - 22 - ${#ONLINE_USERS} - ${#TOTAL_CONN} )) ""
MID

# SEGURIDAD
printf "${CYAN}║${RESET} ${GOLD}${MENU_SECURITY:-SEGURIDAD}${RESET}  Fail2ban ${SEC_STATUS}  ${GRAY}Jails:${RESET} ${WHITE}${SEC_JAILS}${RESET}${CYAN}%*s║${RESET}\n" $(( W - 28 - ${#SEC_JAILS} )) ""
MID

# MENÚ
_MENU_MAIN_LABEL="${MENU_MAIN:-MENU PRINCIPAL}"
printf "${CYAN}║${RESET} ${GOLD}${_MENU_MAIN_LABEL}${RESET}${CYAN}%*s║${RESET}\n" $(( W - ${#_MENU_MAIN_LABEL} - 1 )) ""
printf "${CYAN}║${RESET}  ${GOLD}[01]${WHITE} 👥 ${MENU_USERS:-Usuarios}      ${CYAN}│${RESET}  ${GOLD}[06]${WHITE} ⚡ ${MENU_OPTIMIZE:-Optimizar}${RESET}${CYAN}%*s║${RESET}\n" $(( W - 41 )) ""
printf "${CYAN}║${RESET}  ${GOLD}[02]${WHITE} 🚀 ${MENU_PROTOCOLS_BTN:-Protocolos}    ${CYAN}│${RESET}  ${GOLD}[07]${WHITE} 🌐 ${MENU_DOMAIN:-Dominio}${RESET}${CYAN}%*s║${RESET}\n" $(( W - 41 )) ""
printf "${CYAN}║${RESET}  ${GOLD}[03]${WHITE} 🧰 ${MENU_TOOLS:-Herramientas}  ${CYAN}│${RESET}  ${GOLD}[08]${WHITE} 🔄 ${MENU_AUTO_START_LABEL:-Auto} $(status "${AUTO_START:-OFF}")${RESET}${CYAN}%*s║${RESET}\n" $(( W - 42 )) ""
printf "${CYAN}║${RESET}  ${GOLD}[04]${WHITE} 🛡 ${MENU_SECURITY_BTN:-Seguridad}     ${CYAN}│${RESET}  ${GOLD}[09]${WHITE} 🛠 ${MENU_UPDATE:-Update}${RESET}${CYAN}%*s║${RESET}\n" $(( W - 38 )) ""
printf "${CYAN}║${RESET}  ${GOLD}[05]${WHITE} 📊 ${MENU_CONSUMPTION:-Consumo}       ${CYAN}│${RESET}  ${GOLD}[10]${WHITE} 🤖 ${MENU_BOT:-Bot Admin}${RESET}${CYAN}%*s║${RESET}\n" $(( W - 39 )) ""
printf "${CYAN}║${RESET}  ${GOLD}[11]${WHITE} ☁️ Xray          ${CYAN}│${RESET}  ${GOLD}[12]${WHITE} 📦 ZiVPN${RESET}${CYAN}%*s║${RESET}\n" $(( W - 38 )) ""
printf "${CYAN}║${RESET}  ${GOLD}[13]${WHITE} 🔑 Licencia      ${CYAN}│${RESET}  ${GOLD}[00]${WHITE} 🚪 ${MENU_EXIT:-Salir}${RESET}${CYAN}%*s║${RESET}\n" $(( W - 38 )) ""
printf "${CYAN}║${RESET}  ${GOLD}[99]${WHITE} 🌐 ${MENU_LANGUAGE:-Idioma} ${GRAY}($(get_current_language 2>/dev/null || echo es))${RESET}${CYAN}%*s║${RESET}\n" $(( W - 28 )) ""
BOT

echo ""
read -rp "$(echo -e "${CYAN}➜ ${GOLD}${MSG_SELECT:-Opción}${WHITE} ➤ ${RESET}")" OPCION

#=========================================================
# CASE PRINCIPAL
#=========================================================

case "$OPCION" in

1)
    clear
    [[ -f "$BASE/usuarios/menu.sh" ]] && bash "$BASE/usuarios/menu.sh" || {
        echo -e "${RED}❌ Módulo de usuarios no instalado${RESET}"
        sleep 2
        exec bash "$BASE/menu.sh"
    }
;;

2)
    clear
    [[ -f "$BASE/protocolos/menu.sh" ]] && bash "$BASE/protocolos/menu.sh" || {
        echo -e "${RED}❌ Menú de protocolos no instalado${RESET}"
        sleep 2
        exec bash "$BASE/menu.sh"
    }
;;

3)
    clear
    bash "$BASE/herramientas/menu.sh"
;;

4)
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${GOLD}            🛡 SEGURIDAD DEL SERVIDOR 🛡${RESET}${CYAN}                 ║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    printf "${GOLD} [1]${WHITE} 🛡 Fail2ban (instalar/configurar/desbanear)\n"
    printf "${GOLD} [2]${WHITE} 🔍 Auditoría completa (rkhunter+chkrootkit+lynis)\n"
    printf "${RED} [0]${WHITE} ↩ Volver\n"
    echo ""
    read -rp " ► Opción: " SEC_OP
    case "$SEC_OP" in
        1) bash "$BASE/herramientas/fail2ban.sh" ;;
        2) bash "$BASE/herramientas/auditoria.sh" ;;
        *) exec bash "$BASE/menu.sh" ;;
    esac
;;

5)
    clear
    if [[ -f "$BASE/herramientas/network_traffic.sh" ]]; then
        bash "$BASE/herramientas/network_traffic.sh"
    else
        echo -e "${RED}❌ network_traffic.sh no encontrado${RESET}"
        sleep 2
        exec bash "$BASE/menu.sh"
    fi
;;

6)
    clear
    if [[ -f "$BASE/herramientas/optimizar.sh" ]]; then
        bash "$BASE/herramientas/optimizar.sh"
    else
        echo -e "${RED}❌ optimizar.sh no encontrado${RESET}"
        sleep 2
        exec bash "$BASE/menu.sh"
    fi
;;

7)
    clear
    if [[ -f "$BASE/herramientas/change-domain" ]]; then
        bash "$BASE/herramientas/change-domain"
    elif [[ -f "$BASE/herramientas/change-domain.sh" ]]; then
        bash "$BASE/herramientas/change-domain.sh"
    else
        echo -e "${RED}❌ change-domain no encontrado${RESET}"
        sleep 2
        exec bash "$BASE/menu.sh"
    fi
;;

8)
    FILE="/etc/profile.d/MoviVIP.sh"
    clear
    if [[ "${AUTO_START:-OFF}" == "OFF" ]]; then
        sed -i 's/AUTO_START=OFF/AUTO_START=ON/' "$CONFIG"
        cat > "$FILE" << 'EOF'
#!/bin/bash
if [[ $- == *i* ]]; then
    menu
fi
EOF
        chmod +x "$FILE"
        echo -e "${GREEN}✅ Auto inicio activado${RESET}"
    else
        sed -i 's/AUTO_START=ON/AUTO_START=OFF/' "$CONFIG"
        rm -f "$FILE"
        echo -e "${GOLD}⚠️ Auto inicio desactivado${RESET}"
    fi
    sleep 2
    exec bash "$BASE/menu.sh"
;;

9)
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${GOLD}            🛠 ACTUALIZAR / REMOVER 🛠${RESET}${CYAN}                   ║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    printf "${GOLD} [1]${WHITE} 🔄 Actualizar Script (v${UPD_LV:-?} → v${UPD_RV:-?})\n"
    printf "${GOLD} [2]${WHITE} 🗑 Remover Script\n"
    printf "${GOLD} [3]${WHITE} 🔑 Cambiar Licencia\n"
    printf "${RED} [0]${WHITE} ↩ Volver\n"
    echo ""
    read -rp " ► Opción: " OP9
    case "$OP9" in
        1)
            if [[ -f "$BASE/updater.sh" ]]; then
                bash "$BASE/updater.sh"
            elif [[ -f "$BASE/update.sh" ]]; then
                bash "$BASE/update.sh"
            else
                cd /etc/movivip 2>/dev/null || exit 1
                if [[ -d .git ]]; then
                    git reset --hard >/dev/null 2>&1
                    git pull origin main >/dev/null 2>&1
                else
                    TMP="/tmp/MoviVIP_update"
                    rm -rf "$TMP"
                    git clone https://github.com/studioanime977/MoviVIPNetwork.git "$TMP" >/dev/null 2>&1
                    [[ $? -eq 0 ]] && cp -rf "$TMP"/* /etc/movivip/ && rm -rf "$TMP"
                fi
                chmod -R +x /etc/movivip
                echo -e "${GREEN}✅ Actualizado${RESET}"
                sleep 2
            fi
            exec bash "$BASE/menu.sh"
        ;;
        2)
            echo -e "${RED}⚠️ Esto eliminará todos los scripts.${RESET}"
            read -rp " ¿Confirmar? (s/n): " CONF
            [[ "$CONF" == "s" ]] && {
                rm -rf /etc/movivip
                rm -f /usr/local/bin/menu
                rm -f /etc/profile.d/MoviVIP.sh
                echo -e "${GREEN}✅ Script eliminado${RESET}"
                sleep 2
                exit 0
            }
            exec bash "$BASE/menu.sh"
        ;;
        3)
            if [[ -f "$BASE/cambiar-licencia.sh" ]]; then
                bash "$BASE/cambiar-licencia.sh"
            else
                echo -e "${RED}❌ cambiar-licencia.sh no encontrado${RESET}"
                sleep 2
            fi
            exec bash "$BASE/menu.sh"
        ;;
        *) exec bash "$BASE/menu.sh" ;;
    esac
;;

10)
    clear
    if [[ -f "$BASE/protocolos/bot.sh" ]]; then
        bash "$BASE/protocolos/bot.sh"
    else
        echo -e "${RED}❌ bot.sh no encontrado${RESET}"
        sleep 2
        exec bash "$BASE/menu.sh"
    fi
;;

11)
    clear
    if [[ -f "$BASE/protocolos/v2ray.sh" ]]; then
        bash "$BASE/protocolos/v2ray.sh"
    else
        echo -e "${RED}❌ v2ray.sh no encontrado${RESET}"
        sleep 2
        exec bash "$BASE/menu.sh"
    fi
;;

12)
    clear
    if [[ -f "$BASE/protocolos/zipvpn.sh" ]]; then
        bash "$BASE/protocolos/zipvpn.sh"
    else
        echo -e "${RED}❌ zipvpn.sh no encontrado${RESET}"
        sleep 2
        exec bash "$BASE/menu.sh"
    fi
;;

13)
    clear
    if [[ -f "$BASE/cambiar-licencia.sh" ]]; then
        bash "$BASE/cambiar-licencia.sh"
    else
        echo -e "${RED}❌ cambiar-licencia.sh no encontrado${RESET}"
        sleep 2
        exec bash "$BASE/menu.sh"
    fi
;;

99)
    clear
    if [[ -f "$BASE/languages/lang.sh" ]]; then
        source "$BASE/languages/lang.sh"
        language_selector
    else
        echo -e "${RED}❌ Sistema de idiomas no disponible${RESET}"
        sleep 2
    fi
    exec bash "$BASE/menu.sh"
;;

0)
    clear
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}                                                              ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}     ${GOLD}${EXIT_MSG:-Gracias por usar MoviVIP Network}${RESET}              ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}     ${WHITE}youtube.com/@MoviVIPNetwork${RESET}                           ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}     ${WHITE}Telegram: @MoviVIP${RESET}  ${WHITE}WhatsApp: +573117008185${RESET}       ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}                                                              ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    exit 0
;;

*)
    clear
    echo -e "${RED}❌ ${MSG_INVALID_OPT:-Opción inválida}${RESET}"
    sleep 1
    exec bash "$BASE/menu.sh"
;;

esac
