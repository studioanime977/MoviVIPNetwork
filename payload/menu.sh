#!/bin/bash

# --- MOVIVIP-LICENSE-GUARD --- v4.0.0
__mv_g=/usr/local/bin/movivip-guard; [ -x "$__mv_g" ] || { echo "MOVIVIP: falta $__mv_g. Reinstala el panel." >&2; exit 1; }; "$__mv_g" --gate --as "${BASH_SOURCE[0]:-$0}" || exit $?

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
TOP(){ local PW; PW=$(mv_panel_width); printf "%b┌%b%s%b┐%b\n" "$MV_MAG" "$MV_MAG" "$(mv_rep "─" "$PW")" "$MV_MAG" "$MV_R"; }
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
    # --auto es obligatorio aqui. network_snapshot.sh es un menu: sin el,
    # el read con </dev/null devuelve EOF al instante, el while true gira
    # infinito consumiendo CPU y como la salida va a /dev/null el panel se
    # queda en negro. El menu se colgaba aqui en cada arranque.
    bash "$BASE/herramientas/network_snapshot.sh" --auto </dev/null >/dev/null 2>&1
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

MV_VER="$(tr -d ' \n\r' < "$BASE/version.txt" 2>/dev/null)"
MV_VER="${MV_VER%.*}"
[[ -n "$MV_VER" ]] && VERSION="$MV_VER"
VERSION="${VERSION:-8.2.16}"

if declare -F mv_header >/dev/null 2>&1; then
    clear
    if ! mv_simple_mode 2>/dev/null; then
        mv_line_morado
        banner_movivip "${MENU_TITLE:-MENÚ PRINCIPAL}"
        [[ -n "${MENU_SUBTITLE:-Alto Rendimiento · Seguridad Total}" ]] && \
            mv_center "${MV_DIM}${MENU_SUBTITLE:-Alto Rendimiento · Seguridad Total}${MV_R}"
        echo ""
        movivip_contacts 2>/dev/null || true
        mv_line_morado
    else
        mv_header "${BRAND_NAME:-MoviVIP Network}" \
            "${MENU_SUBTITLE:-Alto Rendimiento · Seguridad Total}" "v${VERSION}"
        movivip_contacts 2>/dev/null || true
    fi
else
    SEP(){ printf " \e[38;5;240m──────────────────────────────────────────────────────────\e[0m\n"; }
    DSEP(){ printf " \e[38;5;141m──────────────────────────────────────────────────────────\e[0m\n"; }
    sec(){ printf " \e[38;5;220m◆ %s\e[0m\n" "$1"; }
    clear
    DSEP
    printf "   \e[38;5;220m⚡\e[0m  \e[38;5;51mMoviVIP Network\e[0m  \e[38;5;255mv%s\e[0m  \e[38;5;220m⚡\e[0m\n" "$VERSION"
    DSEP
fi

SEP(){ mv_line_thin; }
DSEP(){ mv_line_morado; }
sec(){ mv_section "$1"; }

# ── Dashboard COMPACTO para MÓVIL ──
mv_dash_mobile(){
    sec "💻 ${MENU_SYSTEM:-SISTEMA}"
    printf "  ${MV_WHT}%s${MV_R} ${MV_DIM}·${MV_R} ${MV_WHT}%s cores${MV_R} ${MV_DIM}·${MV_R} ${MV_WHT}%s${MV_R}\n" "$OS" "${CPU_CORES}" "$ARCH"
    printf "  ${MV_CYN}RAM${MV_R} ${MV_WHT}%s%%${MV_R}  ${MV_CYN}CPU${MV_R} ${MV_WHT}%s%%${MV_R}  ${MV_CYN}DISCO${MV_R} ${MV_WHT}%s${MV_R}\n" "$RAM_USE" "$CPU_USE" "$DISK"
    printf "  ${MV_DIM}⏱${MV_R} ${MV_WHT}%s${MV_R}  ${MV_DIM}🕐${MV_R} ${MV_WHT}%s${MV_R}\n" "${UPTIME:-up}" "${FECHA%% *}"
    SEP
    sec "🌐 ${MENU_NETWORK:-RED Y CONECTIVIDAD}"
    printf "  ${MV_CYN}IP${MV_R} ${MV_WHT}%s${MV_R}  ${MV_DIM}·${MV_R}  ${MV_CYN}Pub${MV_R} ${MV_WHT}%s${MV_R}\n" "$IP" "$PUBLIC_IP"
    printf "  ${MV_DIM}Dominio:${MV_R} ${MV_WHT}%s${MV_R}\n" "${_DOM_EFF:-${MENU_NODOMAIN:-NO-DOMAIN}}"
    printf "  ${MV_DIM}Tráfico:${MV_R} ⬇ ${MV_WHT}%s${MV_R}  ⬆ ${MV_WHT}%s${MV_R}  ${MV_DIM}Tot:${MV_R} ${MV_GLD}%s${MV_R}\n" "$(speed "$SPD_IN")" "$(speed "$SPD_OUT")" "$NET_TOTAL_SUM"
    printf "  ${MV_DIM}CF:${MV_R} %b  ${MV_DIM}No-IP:${MV_R} %b  ${MV_DIM}F2B:${MV_R} %b\n" "$(mv_pill "$CF_STATUS_LIVE")" "$(mv_pill "$NOIP_STATUS_LIVE")" "$(mv_pill "${FAIL2BAN_LIVE:-OFF}")"
    SEP
    printf "  ${MV_CYN}👤${MV_R} ${MV_GRN}%s${MV_R} ${MENU_ONLINE:-online}  ${MV_PUR}❖${MV_R}  ${MV_GLD}⚡${MV_R} ${MV_GRN}%s${MV_R} ${MENU_CONN:-conexiones}\n" "$ONLINE_USERS" "$TOTAL_CONN"
    DSEP
}

# Notificación de actualización (solo si el remoto es mayor)
_mv_vnum(){ echo "$1" | awk -F. '{printf "%d%02d%02d", $1, $2, $3}' 2>/dev/null; }
if [[ -n "$UPD_RV" && -n "$UPD_LV" ]] && (( $( _mv_vnum "$UPD_RV" ) > $( _mv_vnum "$UPD_LV" ) )); then
    printf "   ${MV_GLD}⬆ v%s disponible${MV_R} ${MV_DIM}— menú [11] ${MENU_UPDATE_TO:-para actualizar}${MV_R}\n" "$UPD_RV"
    SEP
fi

# ── Cálculo de velocidad ──
read_counters; R2=$RX_N; T2=$TX_N
T_END=$(date +%s%N 2>/dev/null || date +%s)
# La redireccion va FUERA del $(( )). Dentro no es aritmetica valida: hacia
# fallar la expansion entera con "syntax error in expression", y como el fallo
# abortaba la linea, ELAPSED_MS se quedaba vacio y todo lo de abajo salia
# corrupto ("printf: : invalid number" y la barra mezclada).
ELAPSED_MS=$(( (T_END - T_START) / 1000000 ))
(( ELAPSED_MS < 1 )) && ELAPSED_MS=1
SPD_IN=$(( (R2 - R1) * 1000 / ELAPSED_MS )); (( SPD_IN < 0 )) && SPD_IN=0
SPD_OUT=$(( (T2 - T1) * 1000 / ELAPSED_MS )); (( SPD_OUT < 0 )) && SPD_OUT=0

# ── Si es MÓVIL: dashboard compacto ──
if mv_simple_mode 2>/dev/null; then
    mv_dash_mobile
else

# ── INFORMACIÓN DEL VPS (Card 1) ──
mv_panel_top "${MENU_SERVER:-INFORMACIÓN DEL VPS}"
mv_prow "🖥" "${MENU_OS:-Sistema}" "$OS $ARCH"
mv_prow "⚙️" "${MENU_KERNEL:-Kernel}" "$KERNEL"
mv_prow "🧠" "CPU" "${CPU_CORES} ${MENU_CORES:-cores}"
mv_prow "💾" "RAM" "${RAM_USE}% · ${USED_RAM}/${TOTAL_RAM} MB"
mv_prow "🗄" "${MENU_DISK:-Disco}" "$DISK"
mv_prow "⏱" "Uptime" "${UPTIME:-up}"
mv_prow "🕐" "${MENU_DATE:-Fecha}" "$FECHA"
mv_panel_mid "${MENU_PERFORMANCE:-RENDIMIENTO EN VIVO}"
mv_prow_bars "RAM" "${RAM_USE:-0}" "CPU" "${CPU_USE:-0}"
mv_panel_bot

echo ""

# ── RED Y SEGURIDAD (Card 2) ──
mv_panel_top "${MENU_NETWORK:-RED Y SEGURIDAD}"
mv_prow "🏠" "${MENU_LOCALIP:-IP Local}" "$IP"
mv_prow "🌍" "${MENU_PUB:-IP Pública}" "$PUBLIC_IP"
mv_prow "🔗" "Dominio" "${_DOM_EFF:-${MENU_NODOMAIN:-NO-DOMAIN}}"
if [[ -n "${NOIP_DOMAIN:-}" && "${NOIP_DOMAIN}" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    mv_prow "🛰" "No-IP" "$NOIP_DOMAIN"
fi
mv_prow "📶" "${MENU_SPEED:-Velocidad}" "⬇ $(speed "$SPD_IN")  ⬆ $(speed "$SPD_OUT")"
mv_prow "📊" "${MENU_TRAFFIC:-Consumo}" "⬇ $NET_TOTAL_IN  ⬆ $NET_TOTAL_OUT  ·  Total: $NET_TOTAL_SUM"
mv_panel_mid "${MENU_SECURITY:-ESTADO & LICENCIA}"
mv_prow "☁️" "Cloudflare" "$(mv_pill "$CF_STATUS_LIVE")"
mv_prow "🛡" "Fail2ban" "$(mv_pill "${FAIL2BAN_LIVE:-OFF}")"

# Estado de licencia.
#
# Antes se consultaba Firebase por curl aquí, en el panel principal, con
# un max-time de 3s. Tres cosas mal: el panel arrancaba más lento, con
# Firebase en deny-all marcaba OFFLINE aunque la licencia fuese válida,
# y el resultado no lo firmaba nadie.
# Ahora es el binario el que dice si la licencia está viva.
LIC_STATUS_LIVE="OFF"
_MV_LIC_BIN=""
for _mv_c in "${MV_LIC_BIN:-}" /usr/local/bin/movivip-lic \
            /etc/movivip/bin/movivip-lic /etc/movivip/movivip-lic; do
    [ -n "$_mv_c" ] && [ -x "$_mv_c" ] && { _MV_LIC_BIN="$_mv_c"; break; }
done
if [ -z "$_MV_LIC_BIN" ]; then
    _mv_c="$(command -v movivip-lic 2>/dev/null || true)"
    [ -n "$_mv_c" ] && _MV_LIC_BIN="$_mv_c"
fi
if [[ -n "$_MV_LIC_BIN" ]]; then
    # --export sale con 0 solo si la licencia está activa y no vencida.
    "$_MV_LIC_BIN" --export >/dev/null 2>&1 && LIC_STATUS_LIVE="ON"
fi
unset _mv_c
if [[ "$LIC_STATUS_LIVE" == "ON" ]]; then
    mv_prow "🔑" "${MENU_LICENSE:-Licencia}" "$(mv_badge "VIP" "ONLINE")"
else
    mv_prow "🔑" "${MENU_LICENSE:-Licencia}" "$(mv_badge "FAIL" "OFFLINE")"
fi
mv_panel_bot

echo ""

# ── RESUMEN DE SESIONES EN VIVO ──
mv_center "${MV_CYN}👤${MV_R} ${MV_GRN}${MV_BLD}${ONLINE_USERS}${MV_R} ${MV_DIM}${MENU_ONLINE:-online}${MV_R}   ${MV_PUR}❖${MV_R}   ${MV_GLD}⚡${MV_R} ${MV_GRN}${MV_BLD}${TOTAL_CONN}${MV_R} ${MV_DIM}${MENU_CONN:-conexiones activas}${MV_R}"

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
    "📞 ${MENU_SUPPORT:-Soporte MoviVIP}" \
    "🔑 ${MENU_MYLIC:-Mi Licencia}" \
    "🌐 ${MENU_LANGUAGE:-Idioma}" \
    "${RED}↩ ${MENU_EXIT:-Salir}${RESET}")

# Mapear selección a los bloques internos del case
case "$SEL" in
    1)  OPCION="1"  ;;   # Usuarios SSH
    2)  OPCION="20" ;;   # Crear Usuario SSH
    3)  OPCION="21" ;;   # Crear una Cuenta Completa (SSH + Xray + ZiVPN)
    4)  OPCION="22" ;;   # Crear Usuario HWID
    5)  OPCION="2"  ;;   # Protocolos
    6)  OPCION="3"  ;;   # Herramientas
    7)  OPCION="11" ;;   # Xray/V2Ray
    8)  OPCION="12" ;;   # ZiVPN
    9)  OPCION="13" ;;   # SlowDNS
    10) OPCION="5"  ;;   # Consumo de Red
    11) OPCION="9"  ;;   # Update / Remover
    12) OPCION="18" ;;   # Soporte
    13) OPCION="23" ;;   # Mi Licencia
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

23)
    # ── MI LICENCIA ────────────────────────────────────────────
    # Vista de solo lectura de la licencia activa. Reutiliza el parser
    # de lib/firebase-plan.sh, que es el unico que sabe leer los LIC_*
    # del binario sin|source ni eval.
    clear
    banner_movivip "🔑 ${MENU_MYLIC:-MI LICENCIA}" 2>/dev/null

    if ! source "$BASE/lib/firebase-plan.sh" 2>/dev/null; then
        mv_panel_top "🔑 ${MENU_MYLIC:-Mi Licencia}"
        mv_prow "⚠" "Error" "no se pudo cargar el lector de licencia"
        mv_panel_bot
        sleep 3
        exec bash "$BASE/menu.sh"
    fi

    firebase_plan
    _fp_rc=$?

    mv_panel_top "🔑 ${MENU_MYLIC:-Mi Licencia}"

    if [[ "$_fp_rc" -eq 0 ]]; then
        # Fecha legible a partir del timestamp que firma el servidor.
        _fp_exp="—"
        if [[ "${FP_EXPIRA:-0}" =~ ^[0-9]+$ ]] && [[ "${FP_EXPIRA:-0}" -gt 0 ]]; then
            _fp_exp="$(date -d "@${FP_EXPIRA}" '+%Y-%m-%d' 2>/dev/null || echo "${FP_EXPIRA}")"
        fi

        # Dias restantes: se usa el valor que trae la licencia firmada.
        # Si el binario no lo emite, se calcula con la fecha, y si tampoco
        # hay fecha se muestra "—" en vez de un 0 que parece un vencimiento.
        _fp_dias="—"
        _fp_num=""
        if [[ "${FP_DIAS:-}" =~ ^-?[0-9]+$ ]]; then
            _fp_num="${FP_DIAS}"
        elif [[ "${FP_EXPIRA:-0}" =~ ^[0-9]+$ ]] && [[ "${FP_EXPIRA:-0}" -gt 0 ]]; then
            _fp_num="$(( ( ${FP_EXPIRA} - $(date +%s) ) / 86400 ))"
        fi
        [[ -n "$_fp_num" ]] && _fp_dias="${_fp_num} ${MENU_LIC_DAYS:-días}"

        # El estado ya no depende solo de "hay licencia".
        #
        # Una licencia con 0 dias se pintaba como "ACTIVA" en verde, junto a
        # un "Restante 0 dias": eso es justo lo que desconcierta ("dice
        # ACTIVA pero no instala nada"). El aviso de vencimiento va antes que
        # el patente de activa, y "0 dias" deja de ser una buena noticia.
        #
        # Se admite el signo porque el calculo por fecha puede dar negativos
        # si la licencia vencio hace dias. Con ^[0-9]+$ un "-5" no encajaba
        # y caia en la rama de "ACTIVA" en verde: el fallo que esto arregla
        # volveria a aparecer solo, y sin licence que lo delate.
        #
        # El color deja de ser decorativo y pasa a ser la senal:
        #   verde  = puedes instalar
        #   dorado = te queda poco
        #   rojo   = no puedes instalar
        if [[ "$_fp_num" =~ ^-?[0-9]+$ ]] && [[ "$_fp_num" -le 0 ]]; then
            mv_prow "⚠️" "${MENU_LIC_STATE:-Estado}" "$(mv_badge "FAIL" "VENCIDA")"
        elif [[ "$_fp_num" =~ ^-?[0-9]+$ ]] && [[ "$_fp_num" -le 7 ]]; then
            mv_prow "⏳" "${MENU_LIC_STATE:-Estado}" "$(mv_badge "VIP" "POR VENCER")"
        else
            mv_prow "✅" "${MENU_LIC_STATE:-Estado}" "$(mv_badge "OK" "ACTIVA")"
        fi

        mv_prow "👤" "${MENU_LIC_CLIENT:-Cliente}" "${FP_CLIENTE:-desconocido}"
        mv_prow "⭐" "${MENU_LIC_PLAN:-Plan}" "${FP_PLAN:-standard}"
        mv_prow "🏷" "${MENU_LIC_TYPE:-Tipo}" "${FP_TIPO:-cliente}"
        mv_prow "📅" "${MENU_LIC_EXP:-Vence}" "$_fp_exp"
        [[ "$_fp_dias" != "—" ]] && mv_prow "⏳" "${MENU_LIC_LEFT:-Restante}" "$_fp_dias"
        [[ -n "${FP_IP:-}" ]]    && mv_prow "🌐" "IP" "${FP_IP}"
        [[ -n "${FP_HWID:-}" ]]  && mv_prow "🖥" "${MENU_LIC_HWID:-HWID}" "${FP_HWID}"

        # La key se muestra completa: es el dato que el cliente necesita
        # para support y para reinstalar. No es un secreto de servidor.
        if [[ -n "${FP_KEY:-}" ]]; then
            echo ""
            mv_panel_mid "${MENU_LIC_KEY:-Tu clave de licencia}"
            printf "   ${GOLD}%s${RESET}\n" "${FP_KEY}"
        fi
    else
        # No se inventa nada: se muestra el motivo real que dio el binario.
        if [[ "$_fp_rc" -eq 2 ]]; then
            mv_prow "🔌" "${MENU_LIC_STATE:-Estado}" "$(mv_badge "WARN" "SIN CONEXIÓN")"
        else
            mv_prow "❌" "${MENU_LIC_STATE:-Estado}" "$(mv_badge "FAIL" "NO ACTIVA")"
        fi
        [[ -n "${FP_DETALLE:-}" ]] && mv_prow "ℹ" "${MENU_LIC_WHY:-Motivo}" "${FP_DETALLE}"
        echo ""
        echo -e "   ${GRAY}${MENU_LIC_HELP:-Para activarla, usa la opción de soporte o reinstall con tu clave.}${RESET}"
    fi

    mv_panel_bot
    echo ""
    read -r -p "   ${GRAY}[Enter] ${MENU_EXIT:-volver}${RESET}" _mv_back
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
        "🔄"" ${UPD_UPDATE:-Actualizar Script} (v${UPD_LV:-?} → v${UPD_RV:-?})"
        "✖ ${UPD_REMOVE:-Remover Script}"
        "🔁 ${UPD_AUTO_TOGGLE:-Auto-update}: $(grep -q '^AUTO_UPDATE=OFF' "$CONFIG" 2>/dev/null && echo OFF || echo ON)"
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
            # Antes era 4) (Auto-update); "Cambiar Licencia" ocupaba el 3)
            # y se elimino, asi que todo lo de abajo sube una posicion.
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
        0|4) exec bash "$BASE/menu.sh" ;;   # 4 = "Volver" (ahora la 4a linea)
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
    # Bloque 14 retirado a proposito: "Cambiar Licencia" ya no se ofrece.
    # El cambio de key se hace desde la activacion (validar-licencia.sh).
    # Ver menu.sh: la seleccion 12 ya no mapea aqui.
    echo -e "${RED}${ERR_NOT_AVAILABLE:-Opcion no disponible}${RESET}"
    sleep 2
    exec bash "$BASE/menu.sh"
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
    # Bloque retirado a proposito.
    # Era un panel de emision de licenses dentro del menu del cliente:
    # autenticaba con una lectura REST a Firebase SIN firma, se logueaba
    # con Firebase Auth y hacia PUT de la licencia nueva. Eso permitia
    # acuñar licenses a quien tuviera acceso al menu, y la firma del
    # proveedor no se comprobaba en ningun punto.
    # El key de emision vive ahora solo en el servidor del proveedor.
    echo -e "${RED}${ERR_NOT_AVAILABLE:-Opcion no disponible}${RESET}"
    sleep 2
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