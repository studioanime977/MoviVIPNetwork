#!/bin/bash

#=========================================================
#   MOVIVIP NETWORK — PREMIUM EDITION v5.5
#   Panel de Control · Alto Rendimiento y Seguridad Total
#   Diseño compacto tipo dashboard — 1 pantalla
#   DESIGN SYSTEM NEBULA v3.0 (gradiente + barras % + separadores)
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

# v7.3.11: dominio efectivo CF — manual (config.conf) o automatico (cf.conf CF_SUB_FQDN)
_DOM_EFF="${SERVER_DOMAIN:-}"
if [[ -z "$_DOM_EFF" && -f "$BASE/cf.conf" ]]; then
    _CF_SUB_FQDN="$(grep -E '^CF_SUB_FQDN=' "$BASE/cf.conf" 2>/dev/null | tail -1 | cut -d= -f2- | tr -d '"' )"
    _DOM_EFF="$_CF_SUB_FQDN"
fi

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

# Navegación con flechitas + Design System NEBULA v3
source "$BASE/lib/nav.sh" 2>/dev/null || true
source "$BASE/lib/ui.sh" 2>/dev/null || true
source "$BASE/lib/duracion.sh" 2>/dev/null || true

#=========================================================
# Colores premium MoviVIP (banner oficial)
#=========================================================

RESET="${MV_R:-\e[0m}"; RED="${MV_RED:-\e[1;91m}"; GREEN="${MV_GRN:-\e[1;92m}"; GOLD="${MV_GLD:-\e[1;93m}"
BLUE="${MV_BLU:-\e[1;94m}"; MAGENTA="${MV_MAG:-\e[1;95m}"; CYAN="${MV_CYN:-\e[1;96m}"; WHITE="${MV_WHT:-\e[1;97m}"; GRAY="${MV_DIM:-\e[1;90m}"

#=========================================================
# Marco premium (panel morado — idéntico al banner)
#=========================================================

LINE(){ mv_line; }
TOP(){ local PW; PW=$(mv_panel_width); printf "%b┌%b%s%b┐%b\n" "$MV_MAG" "$MV_MAG" "$(printf '─%.0s' $(seq 1 $PW))" "$MV_MAG" "$MV_R"; }
MID(){ mv_panel_mid; }
BOT(){ mv_panel_bot; }
BAR(){ printf "%b│%b%*s%b│%b\n" "$MV_MAG" "$MV_R" "$(mv_panel_width)" "" "$MV_MAG" "$MV_R"; }

#=========================================================================
# (banner_movivip y mv_brand_header viven en lib/ui.sh — reutilizables
#  en TODOS los menús/submenús: banner centralizado, sin duplicación)
#=========================================================================

#=========================================================
# Funciones
#=========================================================

status() {
    [[ "$1" == "ON" ]] && echo -e "${GREEN}●${RESET}" || echo -e "${RED}●${RESET}"
}

progress_bar() {
    # v5.5: Si el Design System NEBULA v3.0 está cargado, usa la barra
    # con % real (mv_progress). Fallback clásico si no existe ui.sh.
    if command -v mv_progress >/dev/null 2>&1; then
        mv_progress "$1" 100
        return 0
    fi
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
    FAIL2BAN_LIVE="ON"
else
    SEC_STATUS="${RED}●${RESET}"
    SEC_JAILS="-"
    FAIL2BAN_LIVE="OFF"
fi

#=========================================================
# Consumo de red
#=========================================================

VPS_BASE_RX="${VPS_TRAFFIC_BASE_RX//[^0-9]/}"; VPS_BASE_RX="${VPS_BASE_RX:-0}"
VPS_BASE_TX="${VPS_TRAFFIC_BASE_TX//[^0-9]/}"; VPS_BASE_TX="${VPS_BASE_TX:-0}"
NET_TOTAL_IN="—"; NET_TOTAL_OUT="—"

# ── FIX v6.4: saneamiento numérico (protege contra CRLF/basura heredados) ──
if [[ -f "$STATE" ]]; then
    source "$STATE" 2>/dev/null
    [[ -z "${TOTAL_IN:-}" && -n "${ACC_RX:-}" ]] && TOTAL_IN="$ACC_RX"
    [[ -z "${TOTAL_OUT:-}" && -n "${ACC_TX:-}" ]] && TOTAL_OUT="$ACC_TX"
    TOTAL_IN="${TOTAL_IN//[^0-9]/}"; TOTAL_IN="${TOTAL_IN:-0}"
    TOTAL_OUT="${TOTAL_OUT//[^0-9]/}"; TOTAL_OUT="${TOTAL_OUT:-0}"
    RX_TOTAL=$((VPS_BASE_RX + TOTAL_IN))
    TX_TOTAL=$((VPS_BASE_TX + TOTAL_OUT))
    NET_TOTAL_IN=$(human "$RX_TOTAL")
    NET_TOTAL_OUT=$(human "$TX_TOTAL")
else
    bash "$BASE/herramientas/network_snapshot.sh" </dev/null >/dev/null 2>&1
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

#---------------------------------------------------------
# Protocolos EXTRA — detección real (systemd + binario)
#---------------------------------------------------------
# proto_state <servicio-systemd> <binario> → ● verde / ● rojo / ○ gris
proto_state() {
    local svc="$1" bin="$2"
    if [[ -n "$svc" ]] && { svc_exists "$svc" || command -v "$svc" >/dev/null 2>&1; }; then
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            echo -e "${GREEN}●${RESET}"
        else
            echo -e "${RED}●${RESET}"
        fi
        return
    fi
    if [[ -n "$bin" ]] && { pgrep -x "$bin" >/dev/null 2>&1 || pgrep -f "$bin" >/dev/null 2>&1; }; then
        echo -e "${GREEN}●${RESET}"
        return
    fi
    echo -e "${GRAY}○${RESET}"
}

WS_S=$(proto_state ssh-ws-internal "ssh-ws")
BHTTP_S=$(proto_state bhttp "bhttp-server")
BTUN_S=$(proto_state btun "btun-server")
HCR_S=$(proto_state hcr "hcr")
XHTTP_S=$(proto_state xhttp "xhttp-server")
SS_S=$(proto_state "shadowsocks-libev" "ss-server")
STUN_S=$(proto_state stunnel4 "stunnel4")
SOCKS_S=$(proto_state "danted" "danted")
DNSTT_S=$(proto_state "dnstt" "dnstt")
OVPN_S=$(proto_state "openvpn" "openvpn")
WG_S=$(proto_state "wg-quick@wg0" "wg")
SQUID_S=$(proto_state squid "squid")

#=========================================================
# Conexiones en tiempo real
#=========================================================

SSH_CONN=$(ps -C sshd -o args= 2>/dev/null | grep -c "\[priv\]")
DROP_CONN=$(pgrep -x dropbear 2>/dev/null | wc -l)
[[ $DROP_CONN -gt 0 ]] && DROP_CONN=$((DROP_CONN - 1))
ONLINE_USERS=$(ps -C sshd -o args= 2>/dev/null | grep "\[priv\]" | awk -F'sshd: ' '{print $2}' | awk '{print $1}' | grep -vE '^(root|unknown|invalid|\(null\))$' | sort -u | wc -l)

# Contar conexiones por protocolo (auto-detect puertos activos)
timeout 3 ss -ulnp > /tmp/_mv_udp_l 2>/dev/null
timeout 3 ss -tnlp > /tmp/_mv_tcp_l 2>/dev/null
timeout 3 ss -unp  > /tmp/_mv_udp 2>/dev/null
timeout 3 ss -tnp  > /tmp/_mv_tcp 2>/dev/null

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
if [[ -n "$_DOM_EFF" ]]; then
    _parent_domain=$(echo "$_DOM_EFF" | awk -F. '{print $(NF-1)"."$NF}')
    CF_NS=$(dig +short NS "$_parent_domain" 2>/dev/null | grep -ci cloudflare)
    [[ "$CF_NS" -gt 0 ]] && CF_STATUS_LIVE="ON"
fi
[[ "${CLOUDFLARE_STATUS:-OFF}" == "ON" ]] && CF_STATUS_LIVE="ON"
NOIP_STATUS_LIVE="OFF"
if [[ -n "$NOIP_DOMAIN" ]]; then
    NOIP_STATUS_LIVE="ON"
elif [[ -n "$_DOM_EFF" ]]; then
    _noip_check=$(dig +short A "$_DOM_EFF" 2>/dev/null | head -1)
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
    if ! mv_simple_mode 2>/dev/null; then
        # Pantalla completa: el logo 3D YA dice MOVIVIP → NO repetir el nombre
        # Marco superior: logo + título + subtítulo + contactos entre dos ════
        mv_line
        banner_movivip "${MENU_TITLE:-MENÚ PRINCIPAL}"
        [[ -n "${MENU_SUBTITLE:-Alto Rendimiento · Seguridad Total}" ]] && \
            mv_center "${MV_YLW}${MENU_SUBTITLE:-Alto Rendimiento · Seguridad Total}${MV_R}"
        movivip_contacts 2>/dev/null || true
        # (sin mv_line final: el dashboard ya abre con DSEP → cierra el marco)
    else
        # Móvil: header compacto con nombre (sin logo grande)
        mv_header "${BRAND_NAME:-MoviVIP Network}" \
            "${MENU_SUBTITLE:-Alto Rendimiento · Seguridad Total}" "v${VERSION}"
        movivip_contacts 2>/dev/null || true
    fi
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

SEP(){ mv_line_thin; }
DSEP(){ mv_line; }
sec(){ mv_section "$1"; }

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
    local _s _pr
    # SISTEMA
    sec "💻 ${MENU_SYSTEM:-SISTEMA}"
    printf "  ${WHITE}%s${RESET} ${GRAY}·${RESET} ${WHITE}%s${RESET} ${GRAY}·${RESET} ${WHITE}%s${RESET}\n" "$OS" "${CPU_CORES} cores" "$ARCH"
    printf "  ${GRAY}RAM${RESET} ${WHITE}%s%%${RESET}  ${GRAY}CPU${RESET} ${WHITE}%s%%${RESET}  ${GRAY}DISK${RESET} ${WHITE}%s${RESET}\n" "$RAM_USE" "$CPU_USE" "$DISK"
    printf "  ${GRAY}⏱${RESET} ${WHITE}%s${RESET}  ${GRAY}🕐${RESET} ${WHITE}%s${RESET}\n" "${UPTIME:-up}" "${FECHA%% *}"
    printf "  ${GRAY}${MENU_KERNEL:-Kernel}${RESET} ${WHITE}%s${RESET}\n" "$KERNEL"
    SEP
    # RED
    sec "🌐 ${MENU_NETWORK:-RED Y DOMINIOS}"
    printf "  ${GRAY}IP${RESET} ${WHITE}%s${RESET}  ${GRAY}Pub${RESET} ${WHITE}%s${RESET}\n" "$IP" "$PUBLIC_IP"
    printf "  ${GRAY}🏠${RESET} ${WHITE}%s${RESET}\n" "${_DOM_EFF:-${MENU_NODOMAIN:-NO-DOMAIN}}"
    printf "  ${GRAY}⬇${RESET} ${WHITE}%s${RESET}  ${GRAY}⬆${RESET} ${WHITE}%s${RESET}  ${GRAY}Tot${RESET} ${GOLD}%s${RESET}\n" "$(speed "$SPD_IN")" "$(speed "$SPD_OUT")" "$NET_TOTAL_SUM"
    printf "  ${GRAY}CF${RESET} %b  ${GRAY}No-IP${RESET} %b  ${GRAY}Fail2ban${RESET} %b\n" "$(status "$CF_STATUS_LIVE")" "$(status "$NOIP_STATUS_LIVE")" "$(status "${FAIL2BAN_LIVE:-OFF}")"
    SEP
    # USUARIOS CONECTADOS (los servicios VPN viven en 🚀 Protocolos)
    printf "  👤 ${GREEN}%s${RESET} ${MENU_ONLINE:-online} ${GRAY}·${RESET} ${MENU_CONN:-Conex} ${GREEN}%s${RESET}\n" "$ONLINE_USERS" "$TOTAL_CONN"
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

# ── INFORMACIÓN DEL VPS (panel)
sec "💻 ${MENU_VPSINFO:-INFORMACIÓN DEL VPS}"
mv_panel_top "${MENU_SERVER:-SERVIDOR}"
mv_prow "🖥" "${MENU_OS:-Sistema}" "$OS $ARCH"
mv_prow "⚙️" "${MENU_KERNEL:-Kernel}" "$KERNEL"
mv_prow "🧠" "CPU" "${CPU_CORES} ${MENU_CORES:-cores}"
mv_prow "💾" "RAM" "${RAM_USE}% · ${USED_RAM}/${TOTAL_RAM} MB"
mv_prow "🗄" "${MENU_DISK:-Disco}" "$DISK"
mv_prow "⏱" "Uptime" "${UPTIME:-up}"
mv_prow "🕐" "${MENU_DATE:-Fecha}" "$FECHA"
mv_panel_mid
mv_prow_bars "RAM" "${RAM_USE:-0}" "CPU" "${CPU_USE:-0}"
mv_panel_bot

mv_sep_dots

# ── RED Y DOMINIOS (panel)
sec "🌐 ${MENU_NETWORK:-RED Y DOMINIOS}"
mv_panel_top "${MENU_CONNECTION:-CONEXIÓN}"
mv_prow "🏠" "${MENU_LOCALIP:-IP local}" "$IP"
mv_prow "🌍" "${MENU_PUB:-IP pública}" "$PUBLIC_IP"
mv_prow "🔗" "Dominio" "${_DOM_EFF:-${MENU_NODOMAIN:-NO-DOMAIN}}"
if [[ -n "${NOIP_DOMAIN:-}" && "${NOIP_DOMAIN}" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    mv_prow "🛰" "No-IP" "$NOIP_DOMAIN"
fi
if [[ -n "${CLOUDFRONT_DOMAIN:-}" && "${CLOUDFRONT_DOMAIN}" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    mv_prow "☁️" "CloudFront" "$CLOUDFRONT_DOMAIN"
fi
mv_prow "📶" "${MENU_SPEED:-Velocidad}" "⬇ $(speed "$SPD_IN")  ⬆ $(speed "$SPD_OUT")"
mv_prow "📊" "${MENU_TRAFFIC:-Consumo}" "⬇ $NET_TOTAL_IN  ⬆ $NET_TOTAL_OUT"
mv_prow "📈" "Total" "$NET_TOTAL_SUM"
mv_panel_mid "${MENU_SECURITY:-SEGURIDAD}"
if [[ "$CF_STATUS_LIVE" == "ON" ]]; then mv_prow "☁️" "Cloudflare" "● ON"; else mv_prow "☁️" "Cloudflare" "○ OFF"; fi
if [[ "$NOIP_STATUS_LIVE" == "ON" ]]; then mv_prow "🛰" "No-IP" "● ON"; else mv_prow "🛰" "No-IP" "○ OFF"; fi
if [[ "${FAIL2BAN_LIVE:-OFF}" == "ON" ]]; then mv_prow "🛡" "Fail2ban" "● ON"; else mv_prow "🛡" "Fail2ban" "○ OFF"; fi
mv_prow "🧱" "${MENU_JAILS:-Jails}" "$(printf '%.34s' "${SEC_JAILS:--}")"
        # ================= LICENCIA (EN VIVO FIREBASE) =================
        _LIC_KEY=$(grep -oP '^KEY="?\K[^"]+' /etc/movivip/licencia.conf 2>/dev/null | head -n1)
        LIC_STATUS_LIVE="OFF"
        if [[ -n "$_LIC_KEY" ]]; then
            _LIC_NODE=$(echo "$_LIC_KEY" | tr '+/' '-_')
            _LIC_JSON=$(curl -s --max-time 4 "https://movivip-network-default-rtdb.firebaseio.com/licencias_movivip/${_LIC_NODE}.json" 2>/dev/null)
            if echo "$_LIC_JSON" | grep -q '"activa"[[:space:]]*:[[:space:]]*true'; then
                LIC_STATUS_LIVE="ON"
            fi
        fi
        if [[ "$LIC_STATUS_LIVE" == "ON" ]]; then
            mv_prow "🔑" "${MENU_LICENSE:-Licencia}" "[ ${GREEN}ONLINE${RESET} ]"
        else
            mv_prow "🔑" "${MENU_LICENSE:-Licencia}" "[ ${RED}OFFLINE${RESET} ]"
        fi
mv_panel_bot

mv_sep_rainbow

# ── USUARIOS CONECTADOS (los servicios VPN viven en 🚀 Protocolos)
printf "   👤 ${GREEN}%s${RESET} ${MENU_ONLINE:-online}  ${GRAY}· ${MENU_CONN:-Conex}${RESET} ${GREEN}%s${RESET}\n" \
    "$ONLINE_USERS" "$TOTAL_CONN"

DSEP

fi   # fin dispatch móvil/PC del dashboard

echo ""
# ── MENÚ PRINCIPAL ──
# Creación de usuarios primero, luego gestión, luego info/utilidades.
# 🔄 Reiniciar VPS y 💾 Formatear VPS se movieron a 🧰 Herramientas.
SEL=$(nav_pick "► Opción:" \
    "👥 ${MENU_USERS:-Usuarios SSH}" \
    "➕ ${MENU_ADDSSH:-Crear Usuario SSH}" \
    "🎫 ${MENU_ADDACCT:-Crear Cuenta Completa}" \
    "🆔 ${MENU_ADDXRAY:-Crear Usuario HWID}" \
    "🚀 ${MENU_PROTOCOLS_BTN:-Protocolos}" \
    "🧰 ${MENU_TOOLS:-Herramientas}" \
    "☁️ ${MENU_XRAY:-Xray/V2Ray}" \
    "📦 ${MENU_ZIPVPN:-ZiVPN}" \
    "🌐 ${MENU_SLOWDNS:-SlowDNS}" \
    "📊 ${MENU_TRAFFIC:-Consumo de Red}" \
    "🛠 ${MENU_UPDATE:-Update / Remover}" \
    "🔑 ${MENU_LICENSE:-Licencia}" \
    "📞 ${MENU_SUPPORT:-Soporte MoviVIP}" \
    "🌐 ${MENU_LANGUAGE:-Idioma}" \
    "${RED}↩ ${MENU_EXIT:-Salir}${RESET}")

# Mapear selección a los bloques internos del case
case "$SEL" in
    1)  OPCION="1"  ;;   # Usuarios SSH
    2)  OPCION="20" ;;   # Crear Usuario SSH
    3)  OPCION="21" ;;   # Crear Cuenta Completa (SSH + Xray + ZiVPN)
    4)  OPCION="22" ;;   # Crear Usuario HWID
    5)  OPCION="2"  ;;   # Protocolos
    6)  OPCION="3"  ;;   # Herramientas
    7)  OPCION="11" ;;   # Xray/V2Ray
    8)  OPCION="12" ;;   # ZiVPN
    9)  OPCION="13" ;;   # SlowDNS
    10) OPCION="5"  ;;   # Consumo de Red
    11) OPCION="9"  ;;   # Update / Remover
    12) OPCION="14" ;;   # Licencia
    13) OPCION="18" ;;   # Soporte
    14) OPCION="99" ;;   # Idioma
    15) OPCION="0"  ;;   # Salir
    0)  OPCION="0"  ;;   # ESC -> Salir
    *)  OPCION="0"  ;;   # defensivo: nunca caer en un bloque destructivo
esac

#=========================================================
# CASE PRINCIPAL
#=========================================================

case "$OPCION" in

# ══════════════════════════════════════════════════════════
# ACCESOS DIRECTOS DE CREACIÓN DE USUARIOS (v7.6)
# ══════════════════════════════════════════════════════════

20)
    clear
    if [[ -f "$BASE/usuarios/add.sh" ]]; then
        bash "$BASE/usuarios/add.sh"
    else
        echo -e "${RED}${ERR_MODULE_USERS:-❌ Módulo de usuarios no instalado}${RESET}"
        sleep 2
    fi
    exec bash "$BASE/menu.sh"
;;

22)
    clear
    if [[ -f "$BASE/usuarios/add_hwid.sh" ]]; then
        bash "$BASE/usuarios/add_hwid.sh"
    else
        echo -e "${RED}${ERR_MODULE_USERS:-❌ Módulo de usuarios no instalado}${RESET}"
        sleep 2
    fi
    exec bash "$BASE/menu.sh"
;;

21)
    clear
    banner_movivip "🎫 ${MENU_ADDACCT:-CREAR CUENTA COMPLETA}" 2>/dev/null
    if [[ ! -f "$BASE/usuarios/account.sh" ]]; then
        echo -e "${RED}${ERR_MODULE_USERS:-❌ Módulo de usuarios no instalado}${RESET}"
        sleep 2
        exec bash "$BASE/menu.sh"
    fi
    mv_section "🎫 ${MENU_ADDACCT:-Crear Cuenta Completa}"
    printf "   ${GRAY}Enter = valor por defecto${RESET}\n\n"
    printf "   👤 Usuario: "; read -r NU
    if [[ -z "$NU" ]]; then
        echo -e "   ${RED}✘ ${MENU_USER_REQ:-Usuario obligatorio}${RESET}"; sleep 2; exec bash "$BASE/menu.sh"
    fi
    printf "   🔑 Contraseña ${GRAY}[Enter = aleatoria]${RESET}: "; read -r NP
    if [[ -z "$NP" ]]; then
        NP=$(openssl rand -base64 12 2>/dev/null | tr -dc 'A-Za-z0-9' | cut -c1-10)
        echo -e "   ${GOLD}🔑 ${MENU_GENPASS:-Contraseña generada}: ${WHITE}${NP}${RESET}"
    fi
    ND=30; NH=0; NM=0
    if declare -F mv_ask_duracion >/dev/null 2>&1; then
        if ! mv_ask_duracion 30; then
            echo -e "   ${YELLOW}↩ ${MENU_EXIT:-Cancelado}${RESET}"; sleep 1; exec bash "$BASE/menu.sh"
        fi
        ND="${DUR_DIAS:-30}"; NH="${DUR_HORAS:-0}"; NM="${DUR_MIN:-0}"
    else
        printf "   📅 Días ${GRAY}[30]${RESET}: "; read -r ND;  [[ "$ND" =~ ^[0-9]+$ ]] || ND=30
    fi
    printf "   🔗 Conexiones simultáneas ${GRAY}[0 = ilimitado]${RESET}: "; read -r NL; [[ "$NL" =~ ^[0-9]+$ ]] || NL=0
    printf "   📊 Consumo GB ${GRAY}[0 = ilimitado]${RESET}: "; read -r NG; [[ "$NG" =~ ^[0-9]+$ ]] || NG=0
    NC=$(awk -v g="$NG" 'BEGIN{printf "%d", g*1073741824}')
    # ── SELECTOR DE PROTOCOLOS ──────────────────────────
    echo ""
    mv_panel_top "📦 PROTOCOLOS A CREAR"
    mv_prow_menu "[1] 🔐 SSH + derivados"
    mv_prow_menu "[2] ☁️ Xray / V2Ray"
    mv_prow_menu "[3] 📦 ZiVPN (UDP)"
    mv_prow_menu "[4] 🗝 OpenVPN"
    mv_panel_bot
    printf "   ${GRAY}1 = SSH (Dropbear · SSL/TLS · WS · Payload · SOCKS5) · 2 = Xray (VMess · VLESS · Trojan)${RESET}\n"
    printf "   ${GRAY}3 = ZiVPN (contraseña aparte) · 4 = OpenVPN (perfil .ovpn)${RESET}\n"
    printf "   ${GRAY}Elegí los protocolos: 1,2,3 · \"all\" = todos · Enter = 1${RESET}\n"
    printf "   🎫 Selección ${GRAY}[1]${RESET}: "; read -r NSEL
    [[ -z "$NSEL" ]] && NSEL="1"
    NSEL=$(printf '%s' "$NSEL" | tr ' ,' ',')
    NSEL_LC=$(echo "$NSEL" | tr 'A-Z' 'a-z' | tr -d ' ')
    case "$NSEL_LC" in
        all|todos|todo|"*") NSEL="1,2,3,4" ;;
    esac
    WANT_SSH=0; WANT_XRAY=0; WANT_ZIV=0; WANT_OVPN=0
    IFS=',' read -ra _SELARR <<< "$NSEL"
    for _x in "${_SELARR[@]}"; do
        case "${_x// /}" in
            1) WANT_SSH=1  ;;
            2) WANT_XRAY=1 ;;
            3) WANT_ZIV=1  ;;
            4) WANT_OVPN=1 ;;
        esac
    done
    (( WANT_SSH + WANT_XRAY + WANT_ZIV + WANT_OVPN )) || WANT_SSH=1

    NZG=0
    if (( WANT_ZIV )); then
        printf "   📦 Límite ZiVPN GB ${GRAY}[0 = ilimitado]${RESET}: "; read -r NZG
        [[ "$NZG" =~ ^[0-9]+$ ]] || NZG=0
    fi

    echo ""
    printf "   ${GRAY}⏳ ${MENU_PROCESSING:-Procesando…}${RESET}\n"
    echo ""

    # 1) Cuenta Linux (OpenSSH + Dropbear + SSL/TLS + WS + Payload + SOCKS5 …)
    if (( WANT_SSH )); then
        bash "$BASE/usuarios/account.sh" add_ssh_only "$NU" "$NP" "$ND" "$NL" "$NC" "$NH" "$NM"
    fi

    # 2) Xray / V2Ray (cliente propio + expiración y límite por usuario)
    if (( WANT_XRAY )); then
        if [[ -f /usr/local/etc/xray/config.json ]]; then
            bash "$BASE/usuarios/account.sh" xray_add_full "$NU" "$ND" "$NL" "" "$NH" "$NM"
        else
            echo -e "   ${GOLD}⚠ Xray/V2Ray no está instalado — omitido${RESET}"
        fi
    fi

    # 3) ZiVPN (contraseña independiente de la del sistema)
    if (( WANT_ZIV )); then
        if [[ -f /etc/zivpn/config.json ]]; then
            bash "$BASE/usuarios/account.sh" zipvpn_add "$NP" "$ND" "$NZG" "$NH" "$NM"
        else
            echo -e "   ${GOLD}⚠ ZiVPN no está instalado — omitido${RESET}"
        fi
    fi

    # 4) OpenVPN (certificado + perfil .ovpn en /etc/openvpn/clients)
    if (( WANT_OVPN )); then
        if [[ -f "$BASE/protocolos/openvpn.sh" ]] && command -v openvpn >/dev/null 2>&1; then
            printf "   ${GRAY}🗝 Generando certificado OpenVPN (puede tardar)…${RESET}\n"
            bash "$BASE/protocolos/openvpn.sh" --add-user "$NU" "$NP" </dev/null
        else
            echo -e "   ${GOLD}⚠ OpenVPN no está instalado — omitido${RESET}"
        fi
    fi

    echo ""
    printf "   ${GRAY}Enter para volver al menú…${RESET}"; read -r _
    exec bash "$BASE/menu.sh"
;;

1)
    clear
    if [[ -f "$BASE/usuarios/menu.sh" ]]; then
        bash "$BASE/usuarios/menu.sh"
        exec bash "$BASE/menu.sh"
    else
        echo -e "${RED}${ERR_MODULE_USERS:-❌ Módulo de usuarios no instalado}${RESET}"
        sleep 2
        exec bash "$BASE/menu.sh"
    fi
;;

2)
    clear
    if [[ -f "$BASE/protocolos/menu.sh" ]]; then
        bash "$BASE/protocolos/menu.sh"
        exec bash "$BASE/menu.sh"
    else
        echo -e "${RED}${ERR_MODULE_PROTO:-❌ Menú de protocolos no instalado}${RESET}"
        sleep 2
        exec bash "$BASE/menu.sh"
    fi
;;

3)
    clear
    if [[ -f "$BASE/herramientas/menu.sh" ]]; then
        bash "$BASE/herramientas/menu.sh"
    else
        echo -e "${RED}❌ Menú de herramientas no instalado${RESET}"
        sleep 2
    fi
    exec bash "$BASE/menu.sh"
;;

4)
    clear
    mv_brand_header "${SEC_TITLE:-🛡 Seguridad del Servidor}" "$(trx 'Protección, auditoría y escaneo de seguridad')"
    echo ""
    SEC_LBL=(
        "🛡 ${SEC_FAIL2BAN:-Fail2ban (instalar/configurar/desbanear)}"
        "🔍 ${SEC_AUDIT:-Auditoría completa (rkhunter+chkrootkit+lynis)}"
        "🐛 ${SEC_ANTIMINER:-Anti-Minero / Escaneo de seguridad}"
    )
    SEL=$(nav_pick "► ${MSG_OPTION:-Opción}:" "${SEC_LBL[@]}" "↩ ${MSG_BACK:-Volver}") || SEL=0
    case "$SEL" in
        1) bash "$BASE/herramientas/fail2ban.sh"; exec bash "$BASE/menu.sh" ;;
        2) bash "$BASE/herramientas/auditoria.sh"; exec bash "$BASE/menu.sh" ;;
        3) bash "$BASE/herramientas/seguridad.sh"; exec bash "$BASE/menu.sh" ;;
        0|4) exec bash "$BASE/menu.sh" ;;
    esac
;;

5)
    clear
    if [[ -f "$BASE/herramientas/network_traffic.sh" ]]; then
        MV_FROM_MAIN=1 bash "$BASE/herramientas/network_traffic.sh"
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
    mv_brand_header "${UPD_MENU_TITLE:-🛠 Actualizar / Remover}" "$(trx 'Actualiza, remueve o gestiona tu instalación MoviVIP')"
    echo ""
    UPD_LBL=(
        "🔄 ${UPD_UPDATE:-Actualizar Script} (v${UPD_LV:-?} → v${UPD_RV:-?})"
        "🗑 ${UPD_REMOVE:-Remover Script}"
        "🔑 ${UPD_CHANGE_LICENSE:-Cambiar Licencia}"
        "🤖 ${UPD_AUTO_TOGGLE:-Auto-update}: $(grep -q '^AUTO_UPDATE=OFF' "$CONFIG" 2>/dev/null && echo OFF || echo ON)"
    )
    SEL=$(nav_pick "► ${MSG_OPTION:-Opción}:" "${UPD_LBL[@]}" "↩ ${MSG_BACK:-Volver}") || SEL=0
    case "$SEL" in
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
        4)
            clear
            source "$CONFIG" 2>/dev/null
            if [[ "${AUTO_UPDATE:-ON}" != "OFF" ]]; then
                sed -i 's/^AUTO_UPDATE=ON/AUTO_UPDATE=OFF/' "$CONFIG"
                echo -e "${GOLD}⚠️ ${UPD_AUTO_DISABLED:-Auto-update desactivado (el checker solo repara integridad, nunca actualiza)}${RESET}"
            else
                sed -i 's/^AUTO_UPDATE=OFF/AUTO_UPDATE=ON/' "$CONFIG"
                echo -e "${GREEN}✅ ${UPD_AUTO_ENABLED:-Auto-update activado (cron cada 2 días: 03:00)}${RESET}"
            fi
            sleep 2
            exec bash "$BASE/menu.sh"
        ;;
        0|5) exec bash "$BASE/menu.sh" ;;
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
    mv_panel_top "${REBOOT_TITLE:-REINICIAR VPS}"
    mv_prow_center "🔄 ${REBOOT_MSG:-Esto reiniciará el servidor ahora.}"
    mv_panel_bot
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
    mv_panel_top "${FORMAT_TITLE:-FORMATEAR / REINSTALAR VPS}"
    mv_prow_center "💾 ${FORMAT_WARNING:-PELIGRO: Esto eliminará TODO del VPS:}"
    mv_prow_menu "   - ${FORMAT_LIST:-Todos los usuarios VPN}"
    mv_prow_menu "   - ${FORMAT_LIST2:-Todos los protocolos (Xray, Dropbear, BadVPN, etc)}"
    mv_prow_menu "   - ${FORMAT_LIST3:-Todas las configuraciones}"
    mv_prow_menu "   - ${FORMAT_REINSTALL_FROM_SCRATCH:-El sistema se reinstalará desde cero}"
    mv_panel_mid
    mv_prow_center "${FORMAT_REINSTALLING:-El VPS se reiniciará y ejecutará install.sh automáticamente.}"
    mv_panel_bot
    echo ""
    printf " ► ${FORMAT_CONFIRM:-Escribe 'CONFIRMAR' para formatear: } "
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
    mv_panel_top "${KEYGEN_TITLE:-GENERADOR DE LICENCIAS} — MOVIVIP"
    mv_prow_center "🔑 ${KEYGEN_ONLY_ADMINS:-Solo super admins y proveedores pueden generar keys.}"
    mv_panel_bot
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
        echo -e "${RED}  ⚠️  ${KEYGEN_NO_PERMS:-No tienes permisos para generar keys.}${RESET}"
        echo -e "${GOLD}  🚀 ${KEYGEN_BECOME_PROVIDER:-¡Conviértete en PROVEEDOR y genera tus propias keys!}${RESET}"
        echo -e "${CYAN}  💬 Telegram :${WHITE} @MoviVIP${RESET}"
        echo -e "${CYAN}  📱 WhatsApp :${WHITE} +57 311 700 8185${RESET}"
        echo ""
        read -rp "${KEYGEN_PRESS_ENTER:-Presiona Enter para volver...}"
        exec bash "$BASE/menu.sh"
    fi

    echo -e "${GREEN}  ✔ ${KEYGEN_AUTH_OK:-Key autenticada} (tipo: ${K17_TIPO:-cliente})${NC}"
    sleep 1

    # ── SUB-MENÚ (solo super/mayorista llegan aqui) ──
    clear
    mv_panel_top "${KEYGEN_TITLE:-GENERADOR DE LICENCIAS} — MOVIVIP"
    mv_panel_mid "✔ ${KEYGEN_AUTH_AS:-Autenticado}: ${K17_TIPO}"
    mv_prow_menu "[1] 📦 ${KEYGEN_OPT_INSTALL:-Instalar / reinstalar bot keygen}"
    mv_prow_menu "[2] 🟢 ${KEYGEN_OPT_START:-Iniciar bot Telegram}"
    mv_prow_menu "[3] 🔴 ${KEYGEN_OPT_STOP:-Detener bot Telegram}"
    mv_prow_menu "[4] 📋 ${KEYGEN_OPT_LOGS:-Ver logs bot}"
    mv_prow_menu "[5] 🆕 ${KEYGEN_OPT_GEN_CLI:-Generar key CLI}"
    mv_prow_menu "[6] 📊 ${KEYGEN_OPT_LIST:-Ver licencias en Firebase}"
    mv_prow_menu "[7] 🔗 ${KEYGEN_OPT_LINK:-Link bot} @MovivipKeygen_bot"
    mv_prow_menu "[0] ↩ ${KEYGEN_OPT_BACK:-Volver}"
    mv_panel_bot
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
            mv_panel_top "${KEYGEN_GEN_TITLE:-GENERAR KEY DE LICENCIA}"
            mv_panel_mid "✔ ${KEYGEN_AUTH_AS:-Autenticado}: ${K17_TIPO}"
            mv_panel_bot
            echo ""

            # Nombre del cliente
            echo -e "${CYAN}  ${KEYGEN_CLIENT_NAME:-Nombre del cliente (o 'anonimo'):}${NC}"
            read -rp "  > " CLI_CLIENTE
            [[ -z "$CLI_CLIENTE" ]] && CLI_CLIENTE="anonimo"

            # Plan (precios informativos en USDT - la key se genera en premium)
            echo ""
            echo -e "${CYAN}  ${MSG_SEL_PLAN:-Planes y precios (USDT informativos):}${NC}"
            echo -e "    ${GOLD}[BRONCE]${WHITE}        5 USDT  - 1 dispositivo${NC}"
            echo -e "    ${GOLD}[PREMIUM]${WHITE}      15 USDT - 2 dispositivos${NC}"
            echo -e "    ${GOLD}[BETA/VITALICIA]${WHITE} 100 USDT - Ilimitado${NC}"
            echo ""
            CLI_PLAN="premium"
            CLI_PRECIO=15

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
                mv_panel_top "${KEYGEN_SUCCESS:-✅ KEY GENERADA EXITOSAMENTE}"
                mv_prow_menu "🔑 Key: ${NEW_KEY}"
                mv_prow_menu "👤 ${KEYGEN_CLIENT_LBL:-Cliente:} ${CLI_CLIENTE}"
                mv_prow_menu "💎 ${KEYGEN_PLAN_LBL:-Plan:} ${CLI_PLAN} (${CLI_PRECIO} USDT)"
                mv_prow_menu "📅 ${KEYGEN_DAYS_LBL:-Dias:} ${CLI_DIAS}"
                mv_prow_menu "🏷️ ${KEYGEN_GEN_BY:-Generada por:} ${K17_AUTH_KEY}"
                mv_panel_bot
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
    mv_panel_top "${EXIT_MSG:-Gracias por usar MoviVIP Network}"
    mv_panel_mid "🛡 SISTEMA PROTEGIDO POR MOVIVIP 🛡"
    if mv_simple_mode 2>/dev/null; then
        mv_prow_center "📢 t.me/MoviVIPNetwork"
        mv_prow_center "👥 t.me/MoviVIPNet"
        mv_prow_center "💬 t.me/MoviVIP"
        mv_prow_center "🌐 movivip-network.web.app"
        mv_prow_center "📱 +57 311 700 8185"
        mv_prow_center "🤝 Socios: t.me/FreeNetZonevip"
    else
        mv_prow_center "📢 Canal: t.me/MoviVIPNetwork"
        mv_prow_center "👥 Grupo: t.me/MoviVIPNet"
        mv_prow_center "💬 Soporte: t.me/MoviVIP"
        mv_prow_center "🌐 Web: movivip-network.web.app"
        mv_prow_center "📱 WhatsApp: +57 311 700 8185"
        mv_prow_center "🤝 Socios: t.me/FreeNetZonevip · t.me/FreeNetZonevips"
    fi
    mv_line_thin
    mv_center "${MV_GLD}${MV_BLD}M O V I V I P${MV_R}"
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
