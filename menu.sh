#!/bin/bash

#=========================================================
#   MOVIVIP NETWORK — PREMIUM EDITION v5.0
#   Panel de Control · Alto Rendimiento y Seguridad Total
#   Diseño compacto tipo dashboard — 1 pantalla
#=========================================================

# Auto-fix CRLF from Windows uploads (self-healing)
# v5.1 — Reescrito para eliminar el bucle de doble-ejecución.
#   • Guardia MV_CRLF_FIXED evita re-ejecución infinita si el write falla.
#   • Solo procede si $0 es un archivo real y escribible (no pipe/symlink roto).
#   • Usa temporal + mv (no sed -i sobre $0) para no romper symlinks.
#   • Detección por tamaño-de-bytes (tr -d '\r'), portátil GNU/Linux + Cygwin.
if [[ -z "${MV_CRLF_FIXED:-}" && -f "$0" && -w "$0" ]]; then
    export MV_CRLF_FIXED=1
    MV_CRLF_SZ="$(wc -c < "$0" 2>/dev/null)"
    MV_CRLF_CLEAN_SZ="$(tr -d '\r' < "$0" 2>/dev/null | wc -c)"
    if [[ -n "$MV_CRLF_SZ" && -n "$MV_CRLF_CLEAN_SZ" && "$MV_CRLF_SZ" != "$MV_CRLF_CLEAN_SZ" ]]; then
        MV_CRLF_TMP="$(mktemp "$0.MVcrlf.XXXXXX" 2>/dev/null)"
        if [[ -n "$MV_CRLF_TMP" ]] && tr -d '\r' < "$0" > "$MV_CRLF_TMP" 2>/dev/null; then
            chmod --reference="$0" "$MV_CRLF_TMP" 2>/dev/null || chmod 755 "$MV_CRLF_TMP" 2>/dev/null
            if mv -f "$MV_CRLF_TMP" "$0" 2>/dev/null; then
                exec bash "$0" "$@"
            fi
        fi
        rm -f "$MV_CRLF_TMP" 2>/dev/null
    fi
fi
unset MV_CRLF_TMP MV_CRLF_SZ MV_CRLF_CLEAN_SZ

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

# Navegación con flechitas + Design System NEBULA v6
source "$BASE/lib/nav.sh" 2>/dev/null || true
source "$BASE/lib/ui.sh" 2>/dev/null || true

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
    local percent=$1 total=12 filled empty COLOR
    (( percent > 100 )) && percent=100
    (( percent < 0 )) && percent=0
    filled=$((percent*total/100)); empty=$((total-filled))
    if (( percent < 60 )); then COLOR="${GREEN}"
    elif (( percent < 85 )); then COLOR="${GOLD}"
    else COLOR="${RED}"; fi
    printf "%s" "$COLOR"
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
FECHA=$(date +"%d/%m/%Y %H:%M:%S")

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
UPTIME=$(uptime -p | sed -E 's/up //; s/hours?, ?/h/g; s/minutes?/m/g; s/ //g')

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

# Contar conexiones por protocolo (auto-detect puertos activos)
timeout 3 ss -ulnp 2>/dev/null > /tmp/_mv_udp_l 2>/dev/null
timeout 3 ss -tnlp 2>/dev/null > /tmp/_mv_tcp_l 2>/dev/null
timeout 3 ss -unp 2>/dev/null  > /tmp/_mv_udp 2>/dev/null
timeout 3 ss -tnp 2>/dev/null  > /tmp/_mv_tcp 2>/dev/null

UDP_C=0; BAD_C=0; ZIP_C=0; XRAY_C=0; SLOW_C=0

# UDP Custom
if grep -q '"udp"' /tmp/_mv_udp_l 2>/dev/null; then
    for P in $(grep '"udp"' /tmp/_mv_udp_l | awk '{print $4}' | grep -oP ':\K[0-9]+' | sort -un); do
        C=$(awk -v p=":${P}" '$4 ~ p {c++} END{print c+0}' /tmp/_mv_udp 2>/dev/null)
        UDP_C=$((UDP_C + C))
    done
fi

# BadVPN
if grep -q 'badvpn' /tmp/_mv_tcp_l 2>/dev/null; then
    for P in $(grep 'badvpn' /tmp/_mv_tcp_l | awk '{print $4}' | grep -oP ':\K[0-9]+' | sort -un); do
        C=$(awk -v p=":${P}" '$4 ~ p && $1 == "ESTAB" {c++} END{print c+0}' /tmp/_mv_tcp 2>/dev/null)
        BAD_C=$((BAD_C + C))
    done
fi

# ZiVPN
if grep -q 'zivpn' /tmp/_mv_udp_l 2>/dev/null; then
    for P in $(grep 'zivpn' /tmp/_mv_udp_l | awk '{print $4}' | grep -oP ':\K[0-9]+' | sort -un); do
        C=$(awk -v p=":${P}" '$4 ~ p {c++} END{print c+0}' /tmp/_mv_udp 2>/dev/null)
        ZIP_C=$((ZIP_C + C))
    done
fi

# Xray (haproxy public ports + xray local ports)
if grep -q 'xray' /tmp/_mv_tcp_l 2>/dev/null; then
    for P in $(grep 'haproxy\|xray' /tmp/_mv_tcp_l | awk '{print $4}' | grep -oP ':\K[0-9]+' | sort -un); do
        C=$(awk -v p=":${P}" '$4 ~ p && $1 == "ESTAB" {c++} END{print c+0}' /tmp/_mv_tcp 2>/dev/null)
        XRAY_C=$((XRAY_C + C))
    done
fi

# SlowDNS
for P in 53 5300; do
    C=$(awk -v p=":${P}" '$4 ~ p && $1 == "ESTAB" {c++} END{print c+0}' /tmp/_mv_tcp 2>/dev/null)
    SLOW_C=$((SLOW_C + C))
done

rm -f /tmp/_mv_udp_l /tmp/_mv_tcp_l /tmp/_mv_udp /tmp/_mv_tcp

TOTAL_CONN=$((SSH_CONN + DROP_CONN + UDP_C + BAD_C + ZIP_C + XRAY_C + SLOW_C))

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
# PANTALLA — DASHBOARD NEBULA v6.0 (centrado dinámico real)
#=========================================================

# Versión mostrada: version.txt recortado a major.minor (6.0.0 → 6.0)
MV_VER="$(tr -d ' \n\r' < "$BASE/version.txt" 2>/dev/null)"
MV_VER="${MV_VER%.*}"
[[ -n "$MV_VER" ]] && VERSION="$MV_VER"
VERSION="${VERSION:-6.0}"

if declare -F mv_header >/dev/null 2>&1; then
    clear
    mv_header "${BRAND_NAME:-MoviVIP Network}" \
        "${MENU_SUBTITLE:-Alto Rendimiento · Seguridad Total}" "v${VERSION}"
    movivip_contacts 2>/dev/null || true
else
    # Fallback clásico si ui.sh no cargó
    SEP(){ printf " \e[1;90m──────────────────────────────────────────────────────────\e[0m\n"; }
    DSEP(){ printf " ${CYAN}════════════════════════════════════════════════════════════${RESET}\n"; }
    sec(){ printf " ${GOLD}◆ %s${RESET}\n" "$1"; }
    BVIS="🛡️  MoviVIP Network  v${VERSION}  🛡️"
    BP=$(( (56 - ${#BVIS} * 2) / 2 )); (( BP < 1 )) && BP=1
    clear
    DSEP
    printf " %*s%b\n" "$BP" "" "${GOLD}🛡️${RESET}  ${CYAN}MoviVIP Network${RESET}  ${WHITE}v${VERSION}${RESET}  ${GOLD}🛡️${RESET}"
fi

SEP(){ printf " ${GRAY}%s${RESET}\n" "$(printf '─%.0s' $(seq 1 $(( $(mv_cols 2>/dev/null || echo 62) - 3 ))))"; }
DSEP(){ printf " ${CYAN}%s${RESET}\n" "$(printf '━%.0s' $(seq 1 $(( $(mv_cols 2>/dev/null || echo 62) - 3 ))))"; }
sec(){ printf "\n ${CYAN}▎${RESET}${GOLD}◆${RESET} ${WHITE}%s${RESET}\n" "$1"; }

# Fila 2 columnas: left se rellena hasta col 29, right continúa
# (usa mv_w — mide SOLO visible, ignorando códigos \e[..m literales)
row2(){
    local lv pad
    lv="$1"
    pad=$(( 27 - $(mv_w "$lv") )); (( pad < 0 )) && pad=0
    printf "  %b%*s%b\n" "$lv" "$pad" "" "$2"
}

# ── Dashboard COMPACTO para MÓVIL (una columna, sin desborde/wrap) ──
# En móvil (ancho < 58) el dashboard de escritorio de 2 columnas desborda el
# terminal y se ve "duplicado". Se muestra una versión compacta en 1 columna.
mv_dash_mobile(){
    local _s
    # SISTEMA
    sec "💻 ${MENU_SYSTEM:-SISTEMA}"
    printf "  ${WHITE}%s${RESET} ${GRAY}·${RESET} ${WHITE}%s${RESET} ${GRAY}·${RESET} ${WHITE}%s${RESET}\n" "$OS" "${CPU_CORES} cores" "$ARCH"
    printf "  ${GRAY}RAM${RESET} ${WHITE}%s%%${RESET}  ${GRAY}CPU${RESET} ${WHITE}%s%%${RESET}  ${GRAY}DISK${RESET} ${WHITE}%s%%${RESET}\n" "$RAM_USE" "$CPU_USE" "$DISK"
    printf "  ${GRAY}⏱${RESET} ${WHITE}%s${RESET}  ${GRAY}🕐${RESET} ${WHITE}%s${RESET}\n" "${UPTIME:-up}" "${FECHA%% *}"
    printf "  ${GRAY}${MENU_KERNEL:-Kernel}${RESET} ${WHITE}%s${RESET}\n" "$KERNEL"
    SEP
    # RED
    sec "🌐 ${MENU_NETWORK:-RED}"
    printf "  ${GRAY}IP${RESET} ${WHITE}%s${RESET}\n" "$PUBLIC_IP"
    printf "  ${GRAY}⬇${RESET} ${WHITE}%s${RESET}  ${GRAY}⬆${RESET} ${WHITE}%s${RESET}  ${GRAY}Tot${RESET} ${GOLD}%s${RESET}\n" "$(speed "$SPD_IN")" "$(speed "$SPD_OUT")" "$NET_TOTAL_SUM"
    printf "  ${GRAY}CF${RESET} %b  ${GRAY}No-IP${RESET} %b\n" "$(status "$CF_STATUS_LIVE")" "$(status "$NOIP_STATUS_LIVE")"
    SEP
    # PROTOCOLOS (compactos, solo activos)
    sec "⚙️ ${MENU_PROTOCOLS:-PROTOCOLOS}"
    [[ "${SVC_ARR[0]}" == "active" ]] && printf "  ${SSH_S} 🔐 OpenSSH        ${GRAY}[22]${RESET}\n"
    [[ "${SVC_ARR[1]}" == "active" ]] && printf "  ${DROP_S} 🚪 Dropbear       ${GRAY}[90,109,143]${RESET}\n"
    [[ "${SVC_ARR[2]}" == "active" ]] && printf "  ${HA_S} 🔒 SSL/TLS(HA)   ${GRAY}[443]${RESET}\n"
    [[ "${SVC_ARR[3]}" == "active" ]] && printf "  ${UDP_S} 🚀 UDP Custom     ${GRAY}[2100]${RESET}\n"
    [[ "${SVC_ARR[4]}" == "active" ]] && printf "  ${SLOW_S} 🌐 SlowDNS        ${GRAY}[53/5300]${RESET}\n"
    [[ "${SVC_ARR[5]}" == "active" ]] && printf "  ${XRAY_S} ☁️ Xray/V2Ray     ${GRAY}[${XRAY_PORT:-443}]${RESET}\n"
    [[ "${SVC_ARR[6]}" == "active" ]] && printf "  ${BAD_S} ⚡ BadVPN        ${GRAY}[7200,7300]${RESET}\n"
    [[ "${SVC_ARR[7]}" == "active" ]] && printf "  ${ZIP_S} 📦 ZiVPN         ${GRAY}[UDP 5667]${RESET}\n"
    [[ "$HY_LIVE" == "active" ]] && printf "  ${HY_S} 🚀 Hysteria       ${GRAY}[UDP ${HYSTERIA_PORT:---}]${RESET}\n"
    printf "  👤 ${GREEN}${ONLINE_USERS}${RESET} online · ${GREEN}${TOTAL_CONN}${RESET} ${MENU_CONN:-Conex}\n"
    SEP
    # SEGURIDAD
    sec "🛡️ ${MENU_SECURITY:-SEGURIDAD}"
    # En móvil: solo estado, sin la lista larga de jails (evita desbordar el ancho)
    printf "  Fail2ban %b\n" "$SEC_STATUS"
    DSEP
}

# Marca centrada + dashboard adaptativo (compacto en móvil, completo en PC)
DSEP

# Notificación de actualización (solo si el remoto es REALMENTE mayor)
_mv_vnum(){ echo "$1" | awk -F. '{printf "%d%02d%02d", $1, $2, $3}' 2>/dev/null; }
if [[ -n "$UPD_RV" && -n "$UPD_LV" ]] && (( $( _mv_vnum "$UPD_RV" ) > $( _mv_vnum "$UPD_LV" ) )); then
    printf " ${GOLD}⬆ v%s disponible${RESET} ${GRAY}— menú [09] ${MENU_UPDATE_TO:-para actualizar}${RESET}\n" "$UPD_RV"
    SEP
fi

# ── Cálculo de velocidad (compartido por dashboard móvil y PC) ──
read_counters; R2=$RX_N; T2=$TX_N
T_END=$(date +%s%N)
ELAPSED_MS=$(( (T_END - T_START) / 1000000 ))
[[ $ELAPSED_MS -lt 1 ]] && ELAPSED_MS=1
SPD_IN=$(( (R2 - R1) * 1000 / ELAPSED_MS )); [[ $SPD_IN -lt 0 ]] && SPD_IN=0
SPD_OUT=$(( (T2 - T1) * 1000 / ELAPSED_MS )); [[ $SPD_OUT -lt 0 ]] && SPD_OUT=0

# ── Estado Hysteria (compartido por dashboard móvil y PC) ──
HY_LIVE=$(systemctl is-active hysteria1-server 2>/dev/null)
if [[ "$HY_LIVE" == "active" ]]; then HY_S="${GREEN}●${RESET}"; else HY_S="${RED}●${RESET}"; fi

# ── Si es MÓVIL: dashboard compacto y saltamos el completo (evita wrap) ──
if mv_simple_mode 2>/dev/null; then
    mv_dash_mobile
    # marca ya impresa; volver al prompt del menú
else

# ── SISTEMA
sec "💻 ${MENU_SYSTEM:-SISTEMA}"
RAM_BAR=$(progress_bar "$RAM_USE")
CPU_BAR=$(progress_bar "$CPU_USE")
printf "   ${WHITE}%s${RESET} ${GRAY}·${RESET} ${WHITE}%s ${MENU_CORES:-cores}${RESET} ${GRAY}·${RESET} ${WHITE}%s${RESET}\n" \
    "$OS" "$CPU_CORES" "$ARCH"
printf "   RAM %b ${WHITE}%s%%${RESET} ${GRAY}(%sMB/%sMB)${RESET}\n" \
    "$RAM_BAR" "$RAM_USE" "$USED_RAM" "$TOTAL_RAM"
printf "   CPU %b ${WHITE}%s%%${RESET}   ${GRAY}DISK${RESET} ${WHITE}%s${RESET}\n" \
    "$CPU_BAR" "$CPU_USE" "$DISK"
printf "   ${GRAY}⏱${RESET} ${WHITE}%s${RESET}  ${GRAY}·🕐${RESET} ${WHITE}%s${RESET}\n" \
    "${UPTIME:-up}" "${FECHA%% *}"
printf "   ${GRAY}${MENU_KERNEL:-Kernel}${RESET} ${WHITE}%s${RESET}\n" "$KERNEL"

SEP

# ── RED
sec "🌐 ${MENU_NETWORK:-RED}"
printf "   IP ${WHITE}%s${RESET} ${GRAY}· ${MENU_PUB:-Pub}${RESET} ${WHITE}%s${RESET}  CF %b ${GRAY}· No-IP${RESET} %b\n" \
    "$IP" "$PUBLIC_IP" "$(status "$CF_STATUS_LIVE")" "$(status "$NOIP_STATUS_LIVE")"

printf "   ${GRAY}⬇${RESET} ${WHITE}%s${RESET}  ${GRAY}⬆${RESET} ${WHITE}%s${RESET}  ${GRAY}| Total${RESET} ${GOLD}%s${RESET}\n" \
    "$(speed "$SPD_IN")" "$(speed "$SPD_OUT")" "$NET_TOTAL_SUM"
printf "   ${GRAY}⬇${RESET} ${WHITE}%s${RESET}   ${GRAY}⬆${RESET} ${WHITE}%s${RESET}\n" \
    "$NET_TOTAL_IN" "$NET_TOTAL_OUT"
DOM_LINE="🏠 ${WHITE}${SERVER_DOMAIN:-${MENU_NODOMAIN:-NO-DOMAIN}}${RESET}"
[[ -n "${NOIP_DOMAIN:-}" ]] && DOM_LINE+="  ${GRAY}·${RESET} 🌍 ${WHITE}${NOIP_DOMAIN}${RESET}"
[[ -n "${CLOUDFRONT_DOMAIN:-}" ]] && DOM_LINE+="  ${GRAY}·${RESET} ☁️ ${WHITE}${CLOUDFRONT_DOMAIN}${RESET}"
printf "   %b\n" "$DOM_LINE"

SEP

# ── PROTOCOLOS (2 columnas CON puertos)
sec "⚙️ ${MENU_PROTOCOLS:-PROTOCOLOS}"
row2 " ${SSH_S} 🔐 ${PROTO_OPENSSH:-OpenSSH}      ${GRAY}[22]${RESET}"          " ${SLOW_S} 🌐 ${PROTO_SLOWDNS:-SlowDNS}    ${GRAY}[53/5300]${RESET}"
row2 " ${ZIP_S} 📦 ${PROTO_ZIPVPN:-ZiVPN}        ${GRAY}[UDP 5667]${RESET}"    " ${XRAY_S} ☁️ ${PROTO_XRAY:-Xray}       ${GRAY}[${XRAY_PORT:-443}]${RESET}"
row2 " ${DROP_S} 🚪 ${PROTO_DROPBEAR:-Dropbear}    ${GRAY}[90,109,143]${RESET}" " ${GRAY}○${RESET}  🔍 ${PROTO_CHECKUSER:-CheckUser}  ${GRAY}[--]${RESET}"
row2 " ${HA_S} 🔒 ${PROTO_SSL:-SSL/TLS}      ${GRAY}[443]${RESET}"           " ${HY_S} 🚀 ${PROTO_HYSTERIA:-Hysteria}    ${GRAY}[UDP ${HYSTERIA_PORT:---}]${RESET}"
row2 " ${BAD_S} ⚡ ${PROTO_BADVPN:-BadVPN}       ${GRAY}[7200,7300]${RESET}"     " ${UDP_S} 🚀 ${PROTO_UDP:-UDP Custom} [2100]${RESET}"
row2 " 👤 ${GREEN}${PROTO_HWID:-HWID}${RESET}      ${GRAY}[--]${RESET}"            " 🟢 ${GREEN}${ONLINE_USERS}${RESET} ${MENU_ONLINE:-online}  ${GRAY}· ${MENU_CONN:-Conex}${RESET} ${GREEN}${TOTAL_CONN}${RESET}"

SEP

# ── SEGURIDAD
sec "🛡️ ${MENU_SECURITY:-SEGURIDAD}"
printf "   Fail2ban %b  ${GRAY}${SEC_JAILS:-Jails}:${RESET} ${WHITE}%s${RESET}\n" "$SEC_STATUS" "$SEC_JAILS"

DSEP

fi   # fin dispatch móvil/PC del dashboard

echo ""
SEL=$(nav_pick "► Opción:" \
    "👥 ${MENU_USERS:-Usuarios}" \
    "🚀 ${MENU_PROTOCOLS_BTN:-Protocolos}" \
    "🧰 ${MENU_TOOLS:-Herramientas}" \
    "🛡 ${MENU_SECURITY_BTN:-Seguridad}" \
    "📊 ${MENU_CONSUMPTION:-Consumo}" \
    "⚡ ${MENU_OPTIMIZE:-Optimizar}" \
    "🌐 ${MENU_DOMAIN:-Dominio}" \
    "🔄 ${MENU_AUTO_START_LABEL:-Auto} Start" \
    "🛠 ${MENU_UPDATE:-Update / Remover}" \
    "🤖 ${MENU_BOT:-Bot Admin}" \
    "☁️ ${MENU_XRAY:-Xray/V2Ray}" \
    "📦 ${MENU_ZIPVPN:-ZiVPN}" \
    "🌐 ${MENU_SLOWDNS:-SlowDNS}" \
    "🔑 ${MENU_LICENSE:-Licencia}" \
    "🔄 ${MENU_REBOOT:-Reiniciar VPS}" \
    "💾 ${MENU_FORMAT:-Formatear VPS}" \
    "🔑 ${MENU_KEYGEN:-Generador de Licencias}" \
    "📞 ${MENU_SUPPORT:-Soporte MoviVIP}" \
    "🌐 ${MENU_LANGUAGE:-Idioma}" \
    "${RED}↩ ${MENU_EXIT:-Salir}${RESET}")

# Mapear selección: 1-18 directos · 19=Idioma(99) · 20/ESC=Salir(0)
case "$SEL" in
    0)  OPCION="0" ;;
    19) OPCION="99" ;;
    20) OPCION="0" ;;
    *)  OPCION="$SEL" ;;
esac

#=========================================================
# CASE PRINCIPAL
#=========================================================

case "$OPCION" in

1)
    clear
    [[ -f "$BASE/usuarios/menu.sh" ]] && exec bash "$BASE/usuarios/menu.sh" || {
        echo -e "${RED}${ERR_MODULE_USERS:-❌ Módulo de usuarios no instalado}${RESET}"
        sleep 2
        exec bash "$BASE/menu.sh"
    }
;;

2)
    clear
    [[ -f "$BASE/protocolos/menu.sh" ]] && exec bash "$BASE/protocolos/menu.sh" || {
        echo -e "${RED}${ERR_MODULE_PROTO:-❌ Menú de protocolos no instalado}${RESET}"
        sleep 2
        exec bash "$BASE/menu.sh"
    }
;;

3)
    clear
    exec bash "$BASE/herramientas/menu.sh"
;;

4)
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${GOLD}            🛡 ${SEC_TITLE:-SEGURIDAD DEL SERVIDOR} 🛡${RESET}${CYAN}                 ║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    printf "${GOLD} [1]${WHITE} 🛡 ${SEC_FAIL2BAN:-Fail2ban (instalar/configurar/desbanear)}\n"
    printf "${GOLD} [2]${WHITE} 🔍 ${SEC_AUDIT:-Auditoría completa (rkhunter+chkrootkit+lynis)}\n"
    printf "${GOLD} [3]${WHITE} 🐛 ${SEC_ANTIMINER:-Anti-Minero / Escaneo de seguridad}\n"
    printf "${RED} [0]${WHITE} ↩ ${MSG_BACK:-Volver}\n"
    echo ""
    read -rp " ► ${MSG_OPTION:-Opción}: " SEC_OP
    case "$SEC_OP" in
        1) bash "$BASE/herramientas/fail2ban.sh" ;;
        2) bash "$BASE/herramientas/auditoria.sh" ;;
        3) bash "$BASE/herramientas/seguridad.sh" ;;
        *) exec bash "$BASE/menu.sh" ;;
    esac
;;

5)
    clear
    if [[ -f "$BASE/herramientas/network_traffic.sh" ]]; then
        bash "$BASE/herramientas/network_traffic.sh"
    else
        echo -e "${RED}❌ network_traffic.sh ${ERR_FILE_NOT_FOUND:-no encontrado}${RESET}"
        sleep 2
        exec bash "$BASE/menu.sh"
    fi
;;

6)
    clear
    if [[ -f "$BASE/herramientas/optimizar.sh" ]]; then
        bash "$BASE/herramientas/optimizar.sh"
    else
        echo -e "${RED}❌ optimizar.sh ${ERR_FILE_NOT_FOUND:-no encontrado}${RESET}"
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
        echo -e "${RED}❌ change-domain ${ERR_FILE_NOT_FOUND:-no encontrado}${RESET}"
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
        echo -e "${GREEN}✅ ${AUTO_ON:-Auto inicio activado}${RESET}"
    else
        sed -i 's/AUTO_START=ON/AUTO_START=OFF/' "$CONFIG"
        rm -f "$FILE"
        echo -e "${GOLD}⚠️ ${AUTO_OFF:-Auto inicio desactivado}${RESET}"
    fi
    sleep 2
    exec bash "$BASE/menu.sh"
;;

9)
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${GOLD}            🛠 ${UPD_MENU_TITLE:-ACTUALIZAR / REMOVER} 🛠${RESET}${CYAN}                   ║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    printf "${GOLD} [1]${WHITE} 🔄 ${UPD_UPDATE:-Actualizar Script} (v${UPD_LV:-?} → v${UPD_RV:-?})\n"
    printf "${GOLD} [2]${WHITE} 🗑 ${UPD_REMOVE:-Remover Script}\n"
    printf "${GOLD} [3]${WHITE} 🔑 ${UPD_CHANGE_LICENSE:-Cambiar Licencia}\n"
    printf "${RED} [0]${WHITE} ↩ ${MSG_BACK:-Volver}\n"
    echo ""
    read -rp " ► ${MSG_OPTION:-Opción}: " OP9
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
                echo -e "${GREEN}✅ ${MSG_UPDATED:-Actualizado}${RESET}"
                sleep 2
            fi
            exec bash "$BASE/menu.sh"
        ;;
        2)
            echo -e "${RED}⚠️ ${UPD_REMOVE_CONFIRM:-Esto eliminará todos los scripts.}${RESET}"
            read -rp " ${UPD_REMOVE_CONFIRM_Q:-¿Confirmar? (s/n): }" CONF
            [[ "$CONF" == "s" ]] && {
                rm -rf /etc/movivip
                rm -f /usr/local/bin/menu
                rm -f /etc/profile.d/MoviVIP.sh
                echo -e "${GREEN}✅ ${UPD_REMOVE_DONE:-Script eliminado}${RESET}"
                sleep 2
                exit 0
            }
            exec bash "$BASE/menu.sh"
        ;;
        3)
            if [[ -f "$BASE/cambiar-licencia.sh" ]]; then
                bash "$BASE/cambiar-licencia.sh"
            else
                echo -e "${RED}❌ cambiar-licencia.sh ${ERR_FILE_NOT_FOUND:-no encontrado}${RESET}"
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
        echo -e "${RED}❌ bot.sh ${ERR_FILE_NOT_FOUND:-no encontrado}${RESET}"
        sleep 2
        exec bash "$BASE/menu.sh"
    fi
;;

11)
    clear
    if [[ -f "$BASE/protocolos/v2ray.sh" ]]; then
        FROM_MAIN=1 bash "$BASE/protocolos/v2ray.sh"
    else
        echo -e "${RED}❌ v2ray.sh ${ERR_FILE_NOT_FOUND:-no encontrado}${RESET}"
        sleep 2
        exec bash "$BASE/menu.sh"
    fi
;;

12)
    clear
    if [[ -f "$BASE/protocolos/zipvpn.sh" ]]; then
        FROM_MAIN=1 bash "$BASE/protocolos/zipvpn.sh"
    else
        echo -e "${RED}❌ zipvpn.sh ${ERR_FILE_NOT_FOUND:-no encontrado}${RESET}"
        sleep 2
        exec bash "$BASE/menu.sh"
    fi
;;

13)
    clear
    if [[ -f "$BASE/protocolos/slowdns.sh" ]]; then
        FROM_MAIN=1 bash "$BASE/protocolos/slowdns.sh"
    else
        echo -e "${RED}❌ slowdns.sh ${ERR_FILE_NOT_FOUND:-no encontrado}${RESET}"
        sleep 2
        exec bash "$BASE/menu.sh"
    fi
;;

14)
    clear
    if [[ -f "$BASE/cambiar-licencia.sh" ]]; then
        bash "$BASE/cambiar-licencia.sh"
    else
        echo -e "${RED}❌ cambiar-licencia.sh no encontrado${RESET}"
        sleep 2
        exec bash "$BASE/menu.sh"
    fi
;;

15)
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}              ${GOLD}🔄 ${REBOOT_TITLE:-REINICIAR VPS}${RESET}                                   ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "${RED}⚠️  ${REBOOT_MSG:-Esto reiniciará el servidor ahora.}${RESET}"
    echo ""
    printf " ► ${REBOOT_CONFIRM:-Confirmar reinicio (s/n): }"
    read -r CONF_REBOOT
    if [[ "$CONF_REBOOT" == "s" || "$CONF_REBOOT" == "S" ]]; then
        echo -e "${GREEN}✅ ${REBOOT_RESTARTING:-Reiniciando VPS en 3 segundos...}${RESET}"
        sleep 1
        echo -e "${YELLOW}   3...${RESET}"; sleep 1
        echo -e "${YELLOW}   2...${RESET}"; sleep 1
        echo -e "${YELLOW}   1...${RESET}"; sleep 1
        reboot
    else
        echo -e "${GOLD}✔ ${REBOOT_CANCELED:-Reinicio cancelado}${RESET}"
        sleep 2
    fi
    exec bash "$BASE/menu.sh"
;;

16)
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}           ${RED}💾 ${FORMAT_TITLE:-FORMATEAR / REINSTALAR VPS}${RESET}                              ${CYAN}║${RESET}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "${RED}⚠️  ${FORMAT_WARNING:-PELIGRO: Esto eliminará TODO del VPS:}${RESET}"
    echo -e "${RED}   - ${FORMAT_LIST:-Todos los usuarios VPN}${RESET}"
    echo -e "${RED}   - ${FORMAT_LIST2:-Todos los protocolos (Xray, Dropbear, BadVPN, etc)}${RESET}"
    echo -e "${RED}   - ${FORMAT_LIST3:-Todas las configuraciones}${RESET}"
    echo -e "${RED}   - ${FORMAT_REINSTALL_FROM_SCRATCH:-El sistema se reinstalará desde cero}${RESET}"
    echo ""
    echo -e "${WHITE}${FORMAT_REINSTALLING:-El VPS se reiniciará y ejecutará install.sh automáticamente.}${RESET}"
    echo ""
    printf " ${RED}► ${FORMAT_CONFIRM:-Escribe 'CONFIRMAR' para formatear: } ${RESET}"
    read -r CONF_FORMAT
    if [[ "$CONF_FORMAT" != "CONFIRMAR" && "$CONF_FORMAT" != "CONFIRM" ]]; then
        echo -e "${GREEN}✔ ${FORMAT_CANCELED:-Formateo cancelado}${RESET}"
        sleep 2
        exec bash "$BASE/menu.sh"
    fi
    echo ""
    printf " ${RED}► ${FORMAT_SECOND_CONFIRM:-Segunda confirmación (s/n): } ${RESET}"
    read -r CONF_FORMAT2
    if [[ "$CONF_FORMAT2" != "s" && "$CONF_FORMAT2" != "S" ]]; then
        echo -e "${GREEN}✔ ${FORMAT_CANCELED:-Formateo cancelado}${RESET}"
        sleep 2
        exec bash "$BASE/menu.sh"
    fi
    echo ""
    echo -e "${CYAN}▶ ${FORMAT_CLEANING:-Limpiando sistema...}${RESET}"
    # Limpiar todo
    for svc in xray v2ray dropbear dropbear_custom badvpn-udpgw-7300 badvpn-udpgw-7200 udp-custom zivpn slowdns squid haproxy; do
        systemctl stop "$svc" 2>/dev/null
        systemctl disable "$svc" 2>/dev/null
    done
    killall -9 xray v2ray dropbear badvpn-udpgw 2>/dev/null || true
    rm -rf /etc/movivip /etc/xray /usr/local/etc/xray /etc/v2ray
    rm -f /usr/bin/xray /usr/local/bin/xray /usr/bin/dropbear /usr/sbin/dropbear
    rm -f /usr/bin/badvpn-udpgw /usr/bin/udp
    rm -rf /usr/local/SlowDNS /tmp/dnstt* /etc/slowdns /etc/zivpn
    rm -f /etc/systemd/system/xray*.service /etc/systemd/system/v2ray*.service
    rm -f /etc/systemd/system/dropbear*.service /etc/systemd/system/badvpn*.service
    rm -f /etc/systemd/system/udpcustom*.service /etc/systemd/system/slowdns*.service
    rm -f /etc/systemd/system/zivpn*.service /etc/systemd/system/movivip*.service
    rm -f /etc/profile.d/MoviVIP-banner.sh /etc/issue.net
    crontab -r 2>/dev/null || true
    systemctl daemon-reload 2>/dev/null
    # Reset iptables - abrir SSH SIEMPRE
    iptables -F 2>/dev/null; iptables -X 2>/dev/null
    iptables -t nat -F 2>/dev/null; iptables -t nat -X 2>/dev/null
    iptables -t mangle -F 2>/dev/null; iptables -t mangle -X 2>/dev/null
    iptables -P INPUT ACCEPT 2>/dev/null
    iptables -P FORWARD ACCEPT 2>/dev/null
    iptables -P OUTPUT ACCEPT 2>/dev/null
    iptables -I INPUT 1 -p tcp --dport 22 -j ACCEPT
    iptables -I INPUT 2 -p tcp --dport 54321 -j ACCEPT
    iptables -I INPUT 3 -p tcp --dport 8012 -j ACCEPT
    iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
    echo -e "${GREEN}✅ ${FORMAT_REBOOT_CLEAN:-Sistema limpiado. Reiniciando para instalación limpia...}${RESET}"
    sleep 2
    reboot
;;

17)
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}         ${GOLD}🔑 ${KEYGEN_TITLE:-GENERADOR DE LICENCIAS} — MOVIVIP${RESET}                 ${CYAN}║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${CYAN}║${RESET}  ${WHITE}${KEYGEN_ONLY_ADMINS:-Solo super admins y proveedores pueden generar keys.}${RESET}      ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo ""

    # ── PEDIR KEY SUPER ADMIN AL ENTRAR ──
    echo -e "${CYAN}${KEYGEN_ENTER_KEY:-Ingresa tu key (super admin o proveedor):}${NC}"
    read -rp "  > " K17_AUTH_KEY
    if [[ -z "$K17_AUTH_KEY" ]]; then
        echo -e "${RED}  ${KEYGEN_CANCELED:-Cancelado.}${NC}"
        sleep 2
        exec bash "$BASE/menu.sh"
    fi

    # Verificar key en Firebase
    echo -e "${CYAN}  ${KEYGEN_VERIFYING:-Verificando key...}${NC}"
    K17_FB_BASE="movivip-network-default-rtdb.firebaseio.com"
    K17_KEY_DATA=$(curl -s --max-time 10 "https://${K17_FB_BASE}/licencias_movivip/${K17_AUTH_KEY}.json" 2>/dev/null)

    if [[ -z "$K17_KEY_DATA" || "$K17_KEY_DATA" == "null" ]]; then
        echo -e "${RED}  ✖ ${KEYGEN_NOT_FOUND_FB:-Key no encontrada en Firebase}${NC}"
        sleep 2
        exec bash "$BASE/menu.sh"
    fi

    K17_ACTIVA=$(echo "$K17_KEY_DATA" | grep -oP '"activa"\s*:\s*(true|false)' | sed 's/.*:\s*//')
    if [[ "$K17_ACTIVA" != "true" ]]; then
        echo -e "${RED}  ✖ ${KEYGEN_INACTIVE:-Key inactiva}${NC}"
        sleep 2
        exec bash "$BASE/menu.sh"
    fi

    K17_TIPO=$(echo "$K17_KEY_DATA" | grep -oP '"tipo"\s*:\s*"[^"]*"' | sed 's/.*"\(.*\)"/\1/')
    if [[ "$K17_TIPO" != "super" && "$K17_TIPO" != "mayorista" ]]; then
        echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${RED}║${RESET}  ${WHITE}⚠️  ${KEYGEN_NO_PERMS:-No tienes permisos para generar keys.}${RESET}               ${RED}║${RESET}"
        echo -e "${RED}║${RESET}  ${GOLD}🚀 ${KEYGEN_BECOME_PROVIDER:-¡Conviértete en PROVEEDOR y genera tus propias keys!}${RESET}  ${RED}║${RESET}"
        echo -e "${RED}║${RESET}  ${CYAN}💬 Telegram :${WHITE} @MoviVIP${RESET}                                  ${RED}║${RESET}"
        echo -e "${RED}║${RESET}  ${CYAN}📱 WhatsApp :${WHITE} +57 311 700 8185${RESET}                         ${RED}║${RESET}"
        echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${RESET}"
        echo ""
        read -rp "${KEYGEN_PRESS_ENTER:-Presiona Enter para volver...}"
        exec bash "$BASE/menu.sh"
    fi

    echo -e "${GREEN}  ✔ ${KEYGEN_AUTH_OK:-Key autenticada} (tipo: ${K17_TIPO:-cliente})${NC}"
    sleep 1

    # ── SUB-MENÚ (solo super/mayorista llegan aqui) ──
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}         ${GOLD}🔑 ${KEYGEN_TITLE:-GENERADOR DE LICENCIAS} — MOVIVIP${RESET}                 ${CYAN}║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${CYAN}║${RESET}  ${GREEN}✔ ${KEYGEN_AUTH_AS:-Autenticado como}: ${WHITE}${K17_TIPO}${RESET}                              ${CYAN}║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${CYAN}║${RESET}  ${GOLD}[1]${WHITE} 📦 ${KEYGEN_OPT_INSTALL:-Instalar / reinstalar bot keygen}${RESET}                    ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${GOLD}[2]${WHITE} 🟢 ${KEYGEN_OPT_START:-Iniciar bot Telegram}${RESET}                                ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${GOLD}[3]${WHITE} 🔴 ${KEYGEN_OPT_STOP:-Detener bot Telegram}${RESET}                                ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${GOLD}[4]${WHITE} 📋 ${KEYGEN_OPT_LOGS:-Ver logs bot}${RESET}                                         ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${GOLD}[5]${WHITE} 🆕 ${KEYGEN_OPT_GEN_CLI:-Generar key CLI}${RESET}                                       ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${GOLD}[6]${WHITE} 📊 ${KEYGEN_OPT_LIST:-Ver licencias en Firebase}${RESET}                           ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${GOLD}[7]${WHITE} 🔗 ${KEYGEN_OPT_LINK:-Link bot} @MovivipKeygen_bot${RESET}                          ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${RED}[0]${WHITE} ↩ ${KEYGEN_OPT_BACK:-Volver}${RESET}                                              ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    read -rp "$(echo -e "${CYAN}➜ ${GOLD}${KEYGEN_OPTION:-Opción}${WHITE} ➤ ${RESET}")" BOT_OPT
    case "$BOT_OPT" in
        1)
            # ================= INSTALAR BOT KEYGEN =================
            SETUP_SCRIPT="/etc/movivip/herramientas/setup-bot-generador.sh"
            if [[ -f "$SETUP_SCRIPT" ]]; then
                bash "$SETUP_SCRIPT"
            else
                echo -e "${RED}  ❌ ${MSG_INSTALL_BOT_NOT_FOUND:-No se encontró setup-bot-generador.sh}${RESET}"
                echo -e "${GRAY}  ${MSG_RUN_UPDATER:-Ejecuta updater.sh para descargar los scripts.}${RESET}"
            fi
            read -rp "$(echo -e "${CYAN}➜ ${MSG_ENTER_CONT:-ENTER para continuar}${RESET}")"
            ;;
        2)
            systemctl start movivip-bot-generador
            echo -e "${GREEN}${MSG_BOT_STARTED:-✔ Bot iniciado}${RESET}"
            sleep 2
            ;;
        3)
            systemctl stop movivip-bot-generador
            echo -e "${RED}${MSG_BOT_STOPPED:-✖ Bot detenido}${RESET}"
            sleep 2
            ;;
        4)
            journalctl -u movivip-bot-generador -n 30 --no-pager
            echo ""
            read -rp "${MSG_PRESS_ENTER_BACK:-Presiona Enter para volver...}"
            ;;
        5)
            # ================= GENERAR KEY CLI =================
            clear
            echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
            echo -e "${CYAN}║${RESET}         ${GOLD}🆕 ${KEYGEN_GEN_TITLE:-GENERAR KEY DE LICENCIA}${RESET}                            ${CYAN}║${RESET}"
            echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"
            echo -e "${CYAN}║${RESET}  ${GREEN}✔ ${KEYGEN_AUTH_AS:-Autenticado}: ${WHITE}${K17_TIPO}${RESET} — key: ${WHITE}${K17_AUTH_KEY}${RESET}        ${CYAN}║${RESET}"
            echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
            echo ""

            # Nombre del cliente
            echo -e "${CYAN}  ${KEYGEN_CLIENT_NAME:-Nombre del cliente (o 'anonimo'):}${NC}"
            read -rp "  > " CLI_CLIENTE
            [[ -z "$CLI_CLIENTE" ]] && CLI_CLIENTE="anonimo"

            # Plan
            echo ""
            echo -e "${CYAN}  ${MSG_SEL_PLAN:-Selecciona el plan:}${NC}"
            echo -e "    ${GOLD}[1]${WHITE} ${MSG_PLAN_BRONCE:-BRONCE}    — S/10${NC}"
            echo -e "    ${GOLD}[2]${WHITE} ${MSG_PLAN_PREMIUM:-PREMIUM}   — S/20${NC}"
            echo -e "    ${GOLD}[3]${WHITE} ${MSG_PLAN_PLATINO:-PLATINO}   — S/35${NC}"
            echo -e "    ${GOLD}[4]${WHITE} ${MSG_PLAN_VITALICIO:-VITALICIO} — S/60${NC}"
            echo ""
            read -rp "  Plan [1-4]: " CLI_PLAN_NUM
            CLI_PLAN="premium"
            CLI_PRECIO=20
            case "$CLI_PLAN_NUM" in
                1) CLI_PLAN="bronce"; CLI_PRECIO=10 ;;
                2) CLI_PLAN="premium"; CLI_PRECIO=20 ;;
                3) CLI_PLAN="platino"; CLI_PRECIO=35 ;;
                4) CLI_PLAN="vitalicio"; CLI_PRECIO=60 ;;
            esac

            # Dias
            echo ""
            echo -e "${CYAN}  ${KEYGEN_DAYS_VALIDITY:-Dias de validez:}${NC}"
            if [[ "$CLI_PLAN" == "vitalicio" ]]; then
                echo -e "  ${GRAY}  (${KEYGEN_VITALICIO_HINT:-Vitalicio = 36500 dias})${NC}"
                CLI_DIAS=36500
            else
                echo -e "  ${GRAY}  (${KEYGEN_DAYS_DEFAULT:-default: 30})${NC}"
                read -rp "  ${KEYGEN_DAYS:-Dias:} " CLI_DIAS
                [[ -z "$CLI_DIAS" || ! "$CLI_DIAS" =~ ^[0-9]+$ ]] && CLI_DIAS=30
            fi

            # Generar key
            echo ""
            echo -e "${CYAN}  ${KEYGEN_GENERATING:-Generando key...}${NC}"
            NEW_KEY="KEY-$(openssl rand -hex 5 | tr '[:lower:]' '[:upper:]')"
            AHORA=$(date +%s)
            if [[ "$CLI_PLAN" == "vitalicio" ]]; then
                EXPIRA=0
            else
                EXPIRA=$((AHORA + CLI_DIAS * 86400))
            fi

            # Auth Firebase
            source /etc/movivip/.env-bot 2>/dev/null
            AUTH_URL="https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${FB_API_KEY:-}"
            AUTH_RESP=$(curl -s --max-time 15 -X POST "$AUTH_URL" \
                -H "Content-Type: application/json" \
                -d "{\"email\":\"${FB_AUTH_EMAIL:-}\",\"password\":\"${FB_AUTH_PASS:-}\",\"returnSecureToken\":true}" 2>/dev/null)
            FB_TOKEN=$(echo "$AUTH_RESP" | grep -oP '"idToken"\s*:\s*"([^"]*)"' | sed 's/.*"\(.*\)"/\1/')

            if [[ -z "$FB_TOKEN" ]]; then
                echo -e "${RED}  ${ERR_FIREBASE_AUTH:-✖ Error de autenticacion Firebase}${NC}"
                echo -e "${GRAY}  ${MSG_FIREBASE_VERIFY:-Verifica /etc/movivip/.env-bot}${NC}"
                sleep 3
                exec bash "$BASE/menu.sh"
            fi

            # Subir key a Firebase
            KEY_BODY="{\"activa\":true,\"creada\":$AHORA,\"expira\":$EXPIRA,\"cliente\":\"$CLI_CLIENTE\",\"plan\":\"$CLI_PLAN\",\"precio\":$CLI_PRECIO,\"generada_por\":\"$K17_AUTH_KEY\"}"
            RESP=$(curl -s --max-time 20 -X PUT \
                "https://${K17_FB_BASE}/licencias_movivip/${NEW_KEY}.json?auth=$FB_TOKEN" \
                -H "Content-Type: application/json" \
                -d "$KEY_BODY" 2>/dev/null)

            if [[ -n "$RESP" ]]; then
                echo ""
                echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${RESET}"
                echo -e "${GREEN}║${RESET}         ${GOLD}${KEYGEN_SUCCESS:-✅ KEY GENERADA EXITOSAMENTE}${RESET}                          ${GREEN}║${RESET}"
                echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${RESET}"
                echo -e "${GREEN}║${RESET}  🔑 Key: ${WHITE}${NEW_KEY}${RESET}                                        ${GREEN}║${RESET}"
                echo -e "${GREEN}║${RESET}  👤 ${KEYGEN_CLIENT_LBL:-Cliente:} ${WHITE}${CLI_CLIENTE}${RESET}                                     ${GREEN}║${RESET}"
                echo -e "${GREEN}║${RESET}  💎 ${KEYGEN_PLAN_LBL:-Plan:} ${WHITE}${CLI_PLAN} (S/${CLI_PRECIO})${RESET}                            ${GREEN}║${RESET}"
                echo -e "${GREEN}║${RESET}  📅 ${KEYGEN_DAYS_LBL:-Dias:} ${WHITE}${CLI_DIAS}${RESET}                                            ${GREEN}║${RESET}"
                echo -e "${GREEN}║${RESET}  🏷️ ${KEYGEN_GEN_BY:-Generada por:} ${WHITE}${K17_AUTH_KEY}${RESET}                          ${GREEN}║${RESET}"
                echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${RESET}"
            else
                echo -e "${RED}  ${MSG_FIREBASE_ERR:-✖ Error al subir a Firebase}${NC}"
            fi
            echo ""
            read -rp "${MSG_PRESS_ENTER_BACK:-Presiona Enter para volver...}"
            exec bash "$BASE/menu.sh"
            ;;
        6)
            # ================= VER LICENCIAS =================
            clear
            echo -e "${CYAN}  ${MSG_FIREBASE_LIST:-Licencias en Firebase:}${NC}"
            echo ""
            curl -s "https://movivip-network-default-rtdb.firebaseio.com/licencias_movivip.json" 2>/dev/null | python3 -m json.tool 2>/dev/null || \
            curl -s "https://movivip-network-default-rtdb.firebaseio.com/licencias_movivip.json" 2>/dev/null
            echo ""
            read -rp "${MSG_PRESS_ENTER_BACK:-Presiona Enter para volver...}"
            ;;
        7)
            echo -e "${WHITE}Link: https://t.me/MovivipKeygen_bot${RESET}"
            sleep 2
            ;;
        0|*)
            exec bash "$BASE/menu.sh"
            ;;
    esac
    exec bash "$BASE/menu.sh"
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

18)
    movivip_soporte_screen 2>/dev/null || true
    exec bash "$BASE/menu.sh"
;;

0)
    clear
    echo ""
    if mv_simple_mode 2>/dev/null; then
        # Banner compacto para terminales móviles estrechos (no desborda)
        echo -e "${CYAN}╔══════════════════════════════════════╗${RESET}"
        echo -e "${CYAN}║${RESET}        ${GOLD}Gracias por usar${RESET}         ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET}        ${GOLD}MoviVIP Network${RESET}          ${CYAN}║${RESET}"
        echo -e "${CYAN}╠══════════════════════════════════════╣${RESET}"
        echo -e "${CYAN}║${RESET} ${CYAN}📢${RESET} ${WHITE}t.me/MoviVIPNetwork${RESET}      ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET} ${CYAN}👥${RESET} ${WHITE}t.me/MoviVIPNet${RESET}         ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET} ${GREEN}💬${RESET} ${WHITE}t.me/MoviVIP${RESET}            ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET} ${CYAN}🌐${RESET} ${WHITE}movivip-network.web.app${RESET}  ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET} ${GREEN}📱${RESET} ${WHITE}+57 311 700 8185${RESET}       ${CYAN}║${RESET}"
        echo -e "${GRAY}║${RESET} ${GRAY}🤝 Socios: t.me/FreeNetZonevip${RESET}   ${GRAY}║${RESET}"
        echo -e "${CYAN}╚══════════════════════════════════════╝${RESET}"
    else
        echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${CYAN}║${RESET}                                                              ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET}     ${GOLD}${EXIT_MSG:-Gracias por usar MoviVIP Network}${RESET}              ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET}                                                              ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET}     ${CYAN}📢 Canal :${RESET} ${WHITE}t.me/MoviVIPNetwork${RESET}                    ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET}     ${CYAN}👥 Grupo :${RESET} ${WHITE}t.me/MoviVIPNet${RESET}                       ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET}     ${GREEN}💬 Soporte:${RESET} ${WHITE}t.me/MoviVIP${RESET}                          ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET}     ${CYAN}🌐 Web   :${RESET} ${WHITE}movivip-network.web.app${RESET}                ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET}     ${GREEN}📱 WhatsApp:${RESET} ${WHITE}+57 311 700 8185${RESET}                     ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET}                                                              ${CYAN}║${RESET}"
        echo -e "${GRAY}║${RESET}  🤝 Socios: t.me/FreeNetZonevip · t.me/FreeNetZonevips        ${GRAY}║${RESET}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    fi
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
