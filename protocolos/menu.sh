#!/bin/bash

#=========================================================
#   MOVIVIP NETWORK — MENÚ PROTOCOLOS v5.1
#   Panel de protocolos con estados en vivo · flechitas
#=========================================================

BASE="/etc/movivip"
CONFIG="$BASE/config.conf"

[[ -f "$CONFIG" ]] || { echo "❌ No se encontró config.conf"; exit 1; }
source "$CONFIG" 2>/dev/null

if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)"
fi
if [[ -f "$BASE/languages/protocols.sh" ]]; then
    source "$BASE/languages/protocols.sh"
fi
source "$BASE/lib/nav.sh" 2>/dev/null || true
source "$BASE/lib/ui.sh" 2>/dev/null || true

# i18n shim (auto)
if ! declare -F trx >/dev/null 2>&1; then trx() { printf '%s' "$1"; }; fi

# Paleta premium ANSI-256 (banner oficial v2.1)
RESET="${MV_R}"; RED="${MV_RED}"; GREEN="${MV_GRN}"; GOLD="${MV_GLD}"; YELLOW="${MV_YLW}"
BLUE="${MV_BLU}"; MAGENTA="${MV_MAG}"; CYAN="${MV_CYN}"; WHITE="${MV_WHT}"; GRAY="${MV_DIM}"

W=62
TOP(){ mv_panel_top "${1:-$(trx '⚙️ Protocolos')}"; }
MID(){ mv_panel_mid; }
BOT(){ mv_panel_bot; }

# ── Cache de unidades systemd ────────────────────────────────────────────
# Cada `systemctl list-unit-files` tarda ~0.6s; antes se llamaba ~20 veces
# por render (un svc_status por protocolo) => el menú tardaba 12-16s en
# pintarse. Se inicializa UNA VEZ fuera de subshell ($(svc_status ...))
# y se reutiliza en cada llamada.
_UNITS="$(systemctl list-unit-files 2>/dev/null)"
_units() { printf '%s\n' "$_UNITS"; }

svc_status() {
    local SERVICE="$1" CONF="$2"
    if _units | grep -q "^${SERVICE}.service"; then
        if systemctl is-active --quiet "$SERVICE"; then
            echo -e "${GREEN}●${RESET}"
        else
            echo -e "${RED}●${RESET}"
        fi
    else
        [[ "$CONF" == "ON" ]] && echo -e "${GREEN}●${RESET}" || echo -e "${RED}●${RESET}"
    fi
}

# Reiniciar todos los protocolos instalados
restart_protocols() {
# DTunnel: si está instalado muestra sus puertos reales; si no, "[no instalado]"
if [[ "$DTUNNEL" == "ON" ]]; then
    DT_INFO="[SSL ${DTUNNEL_PORT:-4443}/HTTP ${DTUNNEL_PORT2:-8081}]"
else
    DT_INFO="[no instalado]"
fi

clear
    mv_panel_top "${PB_TITLE:-🔄 REINICIAR PROTOCOLOS}"
    mv_panel_mid "✔ ${PROTO_RESTARTING:-Reiniciando servicios instalados}"
    echo ""

    local SERVICES=(
        ssh
        dropbear_custom
        haproxy
        udp-custom
        slowdns
        xray
        hysteria1-server
        badvpn-udpgw-7200
        badvpn-udpgw
        wg-quick@wg0
        proto-server
        zivpn
        squid
        webmin
        xhttp
        bhttp
        btun
        hcr
        payload-pdirect
        payload-pget
        payload-popen
        payload-ppriv
        payload-ppub
        shadowsocks-libev-server@8388
        openvpn@server
        sockd
        movivip-web
    )

    # systemctl status devuelve 4 cuando la unidad NO existe (evita
    # falsos errores por grep de prefijo: badvpn-udpgw vs -7200,
    # o templates como wg-quick@wg0 sin config).
    local OK=0 FAIL=0 SKIP=0 SVC ST
    for SVC in "${SERVICES[@]}"; do
        systemctl status "$SVC" >/dev/null 2>&1
        ST=$?
        if (( ST == 4 )); then
            echo -e "  ${GRAY}⏭${RESET} $SVC ${GRAY}(no instalado)${RESET}"
            ((SKIP++))
            continue
        fi
        if systemctl restart "$SVC" 2>/dev/null; then
            echo -e "  ${GREEN}✅${RESET} $SVC"
            ((OK++))
        else
            echo -e "  ${RED}❌${RESET} $SVC"
            ((FAIL++))
        fi
    done

    echo ""
    mv_prow_menu "✔ ${OK} reiniciados · ✘ ${FAIL} con errores · ⏭ ${SKIP} no instalados"
    mv_panel_bot
    echo ""
    read -n1 -r -p "$(trx 'Presione una tecla...')"
    exec bash "$BASE/protocolos/menu.sh"
}

SSH_S=$(svc_status ssh "$OPENSSH")
DROP_S=$(svc_status dropbear_custom "$DROPBEAR")
SSL_S=$(svc_status haproxy "$SSL")
UDP_S=$(svc_status udp-custom "$UDP_CUSTOM")
SLOW_S=$(svc_status slowdns "$SLOWDNS")
XRAY_S=$(svc_status xray "$V2RAY")
HY_S=$(svc_status hysteria1-server "$HYSTERIA")
DT_S=$(svc_status proto-server "$DTUNNEL")

[[ "$ZIPVPN" == "ON" ]] && ZIP_S="${GREEN}●${RESET}" || ZIP_S="${RED}●${RESET}"

SQUID_S=$(svc_status squid "$SQUID")
WEBMIN_S=$(svc_status webmin "$WEBMIN")

# SystemDNS: config SYSTEMDNS + unidad systemd-resolved
SYSTEMDNS_S=$(svc_status systemd-resolved "$SYSTEMDNS")

# Protocolos nuevos v6.2: XHTTP_S · BHTTP v2 · BTUN · Shadowsocks · Payload
XHTTP_S=$(svc_status xhttp "$XHTTP")
BHTTP_S=$(svc_status bhttp "$BHTTP")
BTUN_S=$(svc_status btun "$BTUN")
HCR_S=$(svc_status hcr "$HCR")
WEB_S=$(svc_status movivip-web "OFF")
SS_S=$(svc_status "shadowsocks-libev-server@8388" "$SHADOWSOCKS")
PAY_S=$(svc_status payload-pdirect "$PAYLOAD")
OVPN_S=$(svc_status openvpn@server "$OPENVPN")
SOCKS_S=$(svc_status sockd "$SOCKS5")

# Bot Telegram: cualquier unidad movivip-<cliente>-admin activa
BOT_UNIT=$(systemctl list-units --type=service --all --no-legend 2>/dev/null | awk '{print $1}' | grep -E '^movivip-.*-admin\.service' | head -1)
if [[ -n "$BOT_UNIT" ]]; then
    systemctl is-active --quiet "$BOT_UNIT" 2>/dev/null && BOT_S="${GREEN}●${RESET}" || BOT_S="${RED}●${RESET}"
else
    BOT_S="${RED}●${RESET}"
fi

if _units | grep -qE "badvpn-udpgw-7200|badvpn-udpgw"; then
    if systemctl is-active --quiet badvpn-udpgw-7200 2>/dev/null || systemctl is-active --quiet badvpn-udpgw 2>/dev/null; then
        BAD_S="${GREEN}●${RESET}"
    else
        BAD_S="${RED}●${RESET}"
    fi
else
    BAD_S="${RED}●${RESET}"
fi

[[ -d "$BASE/hwids" && -n "$(ls -A "$BASE/hwids" 2>/dev/null)" ]] && HWID_S="${GREEN}●${RESET}" || HWID_S="${GRAY}○${RESET}"

# WireGuard: estado real del servicio wg-quick@wg0
if systemctl is-active --quiet wg-quick@wg0 2>/dev/null; then
    WG_S="${GREEN}●${RESET}"
elif _units | grep -q "^wg-quick@.service"; then
    WG_S="${RED}●${RESET}"
else
    WG_S="${GRAY}○${RESET}"
fi

# DTunnel: si está instalado muestra sus puertos reales; si no, "[no instalado]"
DT_INFO="[no instalado]"
if [[ "$DTUNNEL" == "ON" ]]; then
    DT_INFO="[SSL ${DTUNNEL_PORT:-4443}/HTTP ${DTUNNEL_PORT2:-8081}]"
fi

# ── Design system: separadores (igual que menu.sh) ──
SEP(){ mv_line_thin; }
DSEP(){ mv_line; }

clear
# ── Cabecera premium (idéntica al menú principal) ──
# logo 3D + título + subtítulo + contactos entre dos ════
mv_line
banner_movivip "${PROTO_TITLE:-🚀 Protocolos}"
[[ -n "${PROTO_LIVE:-Panel de protocolos · estados en vivo}" ]] && \
    mv_center "${MV_YLW}${PROTO_LIVE:-Panel de protocolos · estados en vivo}${MV_R}"
movivip_contacts 2>/dev/null || true

# ── Panel resumen de protocolos (dashboard) ──
DSEP
# Contadores de estado (sin coste extra: reutiliza variables ya calculadas)
_ACT=0; _RED=0; _NONE=0
for _s in "$SSH_S" "$ZIP_S" "$DROP_S" "$SSL_S" "$BAD_S" "$UDP_S" "$SLOW_S" "$XRAY_S" "$HY_S" "$WG_S" "$DT_S" "$SYSTEMDNS_S" "$SQUID_S" "$WEBMIN_S" "$BOT_S" "$XHTTP_S" "$BHTTP_S" "$BTUN_S" "$SS_S" "$PAY_S" "$OVPN_S" "$SOCKS_S" "$HCR_S" "$WEB_S"; do
    case "$_s" in
        *"${GREEN}"*) _ACT=$((_ACT+1));;
        *"${RED}"*) _RED=$((_RED+1));;
        *"${GRAY}"*) _NONE=$((_NONE+1));;
    esac
done
mv_panel_top "$(trx '📊 RESUMEN DE PROTOCOLOS')"
mv_prow "🟢" "$(trx 'Activos')" "$_ACT"
mv_prow "🔴" "$(trx 'Inactivos')" "$_RED"
mv_prow "⚪" "$(trx 'No instalados')" "$_NONE"
mv_panel_bot
DSEP

# Selector: estado ● + puerto en cada protocolo (SOLO protocolos)
echo ""
SEL=$(nav_pick "► ${PROTO_TITLE:-Protocolos}:" \
    "${SSH_S} 🔐 ${PROTO_OPENSSH:-OpenSSH} ${GRAY}[22]${RESET}" \
    "${ZIP_S} 📦 ${PROTO_ZIPVPN:-ZiVPN} ${GRAY}[UDP 5667]${RESET}" \
    "${DROP_S} 🚪 ${PROTO_DROPBEAR:-Dropbear} ${GRAY}[90,109,143]${RESET}" \
    "${SSL_S} 🔒 ${PROTO_SSL:-SSL/TLS} ${GRAY}[443]${RESET}" \
    "${BAD_S} ⚡ ${PROTO_BADVPN:-BadVPN} ${GRAY}[7200,7300]${RESET}" \
    "${UDP_S} 🚀 ${PROTO_UDP:-UDP Custom} ${GRAY}[2100]${RESET}" \
    "${SLOW_S} 🌐 ${PROTO_SLOWDNS:-SlowDNS} ${GRAY}[53/5300]${RESET}" \
    "${XRAY_S} ☁️  ${PROTO_XRAY:-Xray · VMess/VLESS/Trojan} ${GRAY}[${XRAY_PORT:-443}]${RESET}" \
    "${HY_S} 🚀 ${PROTO_HYSTERIA:-Hysteria} ${GRAY}[UDP ${HYSTERIA_PORT:-1194}]${RESET}" \
    "${WG_S} 🛡 WireGuard ${GRAY}[UDP ${WG_PORT:-51820}]${RESET}" \
    "${DT_S} 🛰️ ${PROTO_DTUNNEL:-DTunnel} ${GRAY}${DT_INFO}${RESET}" \
    "${SYSTEMDNS_S} 🌐 ${PROTO_SYSTEMDNS:-SystemDNS} ${GRAY}[53]${RESET}" \
    "${SQUID_S} 🌐 ${PROTO_SQUID:-Squid} ${GRAY}[3128]${RESET}" \
    "${WEBMIN_S} 🛠️ ${PROTO_WEBMIN:-Webmin} ${GRAY}[10000]${RESET}" \
    "${BOT_S} 🤖 ${PROTO_BOT:-Bot Telegram} ${GRAY}[gestion]${RESET}" \
    "${XHTTP_S} 🚀 ${PROTO_XHTTP:-SSH-XHTTP} ${GRAY}[443/8080]${RESET}" \
    "${BHTTP_S} 📡 ${PROTO_BHTTP:-BHTTP v2} ${GRAY}[80/8443]${RESET}" \
    "${BTUN_S} 🧵 ${PROTO_BTUN:-BTUN} ${GRAY}[7300]${RESET}" \
    "${SS_S} 🐋 ${PROTO_SHADOWSOCKS:-Shadowsocks} ${GRAY}[8388]${RESET}" \
    "${PAY_S} 🧩 ${PROTO_PAYLOAD:-Payload} ${GRAY}[8082-8085]${RESET}" \
    "${OVPN_S} 🗝️ ${PROTO_OPENVPN:-OpenVPN} ${GRAY}[UDP ${OPENVPN_PORT:-1194}]${RESET}" \
    "${SOCKS_S} 🕸️ ${PROTO_SOCKS5:-SOCKS5} ${GRAY}[TCP ${SOCKS5_PORT:-1080}]${RESET}" \
    "${HCR_S} 🧱 ${PROTO_HCR:-HCR Relay} ${GRAY}[SNI hcr · 443⇄8880]${RESET}" \
    "${WEB_S} 🌐 ${PROTO_WEB:-Web MoviVIP} ${GRAY}[${WEB_PORT:-9617}]${RESET}" \
    "🔄 ${PROTO_RESTART:-Reiniciar protocolos}")

case "$SEL" in
1) bash "$BASE/protocolos/openssh.sh" ; exec bash "$BASE/protocolos/menu.sh";;
2) bash "$BASE/protocolos/zipvpn.sh" ; exec bash "$BASE/protocolos/menu.sh";;
3) bash "$BASE/protocolos/dropbear.sh" ; exec bash "$BASE/protocolos/menu.sh";;
4) bash "$BASE/protocolos/ssl.sh" ; exec bash "$BASE/protocolos/menu.sh";;
5) bash "$BASE/protocolos/badvpn.sh" ; exec bash "$BASE/protocolos/menu.sh";;
6) bash "$BASE/protocolos/udpcustom.sh" ; exec bash "$BASE/protocolos/menu.sh";;
7) bash "$BASE/protocolos/slowdns.sh" ; exec bash "$BASE/protocolos/menu.sh";;
8) bash "$BASE/protocolos/v2ray.sh" ; exec bash "$BASE/protocolos/menu.sh";;
9) bash "$BASE/protocolos/hysteria.sh" ; exec bash "$BASE/protocolos/menu.sh";;
10) bash "$BASE/protocolos/wireguard.sh" ; exec bash "$BASE/protocolos/menu.sh";;
11) bash "$BASE/protocolos/dtunnel.sh" ; exec bash "$BASE/protocolos/menu.sh";;
12) bash "$BASE/protocolos/systemdns.sh" ; exec bash "$BASE/protocolos/menu.sh";;
13) bash "$BASE/protocolos/squid.sh" ; exec bash "$BASE/protocolos/menu.sh";;
14) bash "$BASE/protocolos/webmin.sh" ; exec bash "$BASE/protocolos/menu.sh";;
15) bash "$BASE/protocolos/bot.sh" ; exec bash "$BASE/protocolos/menu.sh";;
16) bash "$BASE/protocolos/xhttp.sh" ; exec bash "$BASE/protocolos/menu.sh";;
17) bash "$BASE/protocolos/bhttp.sh" ; exec bash "$BASE/protocolos/menu.sh";;
18) bash "$BASE/protocolos/btun.sh" ; exec bash "$BASE/protocolos/menu.sh";;
19) bash "$BASE/protocolos/shadowsocks.sh" ; exec bash "$BASE/protocolos/menu.sh";;
20) bash "$BASE/protocolos/payload.sh" ; exec bash "$BASE/protocolos/menu.sh";;
21) bash "$BASE/protocolos/openvpn.sh" ; exec bash "$BASE/protocolos/menu.sh";;
22) bash "$BASE/protocolos/socks5.sh" ; exec bash "$BASE/protocolos/menu.sh";;
23) bash "$BASE/protocolos/hcr.sh" ; exec bash "$BASE/protocolos/menu.sh";;
24) bash "$BASE/protocolos/web.sh" ; exec bash "$BASE/protocolos/menu.sh";;
25) echo -e "${YELLOW}⚠️ ${PROTO_RESTART_WARN:-Reiniciar protocolos cortará tu conexión SSH}${RESET}"; read -n1 -r -p "$(trx 'Presione una tecla para continuar...')"; restart_protocols ;;
0) exec bash "$BASE/menu.sh" ;;
*) echo -e "${RED}❌ ${PROTO_INVALID:-Opción inválida}${RESET}"; sleep 1; exec bash "$BASE/protocolos/menu.sh" ;;
esac
