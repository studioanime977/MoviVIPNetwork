#!/bin/bash

#=========================================================
#   MOVIVIP NETWORK — MENÚ PROTOCOLOS v5.5
#   Panel de protocolos · estados en vivo · flechitas
#   v5.5: bolita ● de estado (verde/roja/○ gris, como la v7)
#         + barra de puertos arriba (chips emoji+puerto)
#         + filas alineadas por columna absoluta en nav_pick
#         + emojis ÚNICOS por protocolo + columna derecha DINÁMICA
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

# ============================================================
# >>> NEBULA v3.0 <<< Identidad visual heredada del design system
# ============================================================
RESET="${MV_R:-$RESET}"; RED="${MV_RED:-$RED}"; GREEN="${MV_GRN:-$GREEN}"; GOLD="${MV_GLD:-$GOLD}"; YELLOW="${MV_YLW:-$YELLOW}"; BLUE="${MV_BLU:-$BLUE}"; MAGENTA="${MV_MAG:-$MAGENTA}"; CYAN="${MV_CYN:-$CYAN}"; WHITE="${MV_WHT:-$WHITE}"; GRAY="${MV_DIM:-$GRAY}"

# ============================================================
# >>> v5.2: CACHE SYSTEMD UNIFICADO <<<
# Una sola consulta para unit-files + UNA para estado.
# ============================================================
declare -A _UFILES=() _UACT=()
while read -r _u _rest; do
    [[ -z "$_u" ]] && continue
    _UFILES["${_u%.service}"]=1
done < <(systemctl list-unit-files --no-legend 2>/dev/null)
while read -r _u _load _act _sub; do
    [[ -z "$_u" ]] && continue
    _UACT["${_u%.service}"]="$_act"
done < <(systemctl list-units --all --type=service --no-legend 2>/dev/null)

# ¿Existe la unidad (o su template base, p.ej. openvpn@server → openvpn@.service)?
svc_exists() {
    local K="$1" BASE_K="${1%%@*}"
    [[ -n "${_UFILES[$K]:-}" || -n "${_UFILES[$BASE_K]:-}" || -n "${_UFILES[${BASE_K}@]:-}" ]]
}
# ¿Está activa?
svc_active() {
    [[ "${_UACT[$1]:-inactive}" == "active" ]]
}

# ============================================================
# >>> v5.5: BOLITA DE ESTADO (como la v7 original) <<<
# ● verde = activo · ● roja = inactivo · ○ gris = no instalado
# ============================================================
_B_ON=$'\033[1;32m●\033[0m'
_B_OFF=$'\033[1;31m●\033[0m'
_B_NA=$'\033[1;90m○\033[0m'

svc_status() {
    local SERVICE="$1" CONF="$2" S
    if svc_exists "$SERVICE"; then
        if svc_active "$SERVICE"; then
            S="$_B_ON"
        else
            S="$_B_OFF"
        fi
    else
        [[ "$CONF" == "ON" ]] && S="$_B_ON" || S="$_B_OFF"
    fi
    echo -e "$S"
}

# Reiniciar todos los protocolos instalados
restart_protocols() {
clear
    mv_panel_top "${PB_TITLE:-🔌 REINICIAR PROTOCOLOS}"
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

    local OK=0 FAIL=0 SKIP=0 SVC
    for SVC in "${SERVICES[@]}"; do
        if ! svc_exists "$SVC"; then
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

[[ "$ZIPVPN" == "ON" ]] && ZIP_S="$_B_ON" || ZIP_S="$_B_OFF"

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
XUI_S=$(svc_status x-ui "$XUI")

# Bot Telegram: cualquier unidad movivip-<cliente>-admin registrada en el cache
BOT_UNIT=""
for _k in "${!_UACT[@]}"; do
    if [[ "$_k" == movivip-*-admin ]]; then
        BOT_UNIT="$_k"
        break
    fi
done
if [[ -n "$BOT_UNIT" ]]; then
    if svc_active "$BOT_UNIT"; then BOT_S="$_B_ON"; else BOT_S="$_B_OFF"; fi
else
    BOT_S="$_B_OFF"
fi

# BadVPN: cualquiera de las dos variantes
if svc_exists "badvpn-udpgw-7200" || svc_exists "badvpn-udpgw"; then
    if svc_active "badvpn-udpgw-7200" || svc_active "badvpn-udpgw"; then
        BAD_S="$_B_ON"
    else
        BAD_S="$_B_OFF"
    fi
else
    BAD_S="$_B_OFF"
fi

[[ -d "$BASE/hwids" && -n "$(ls -A "$BASE/hwids" 2>/dev/null)" ]] && HWID_S="$_B_ON" || HWID_S="$_B_NA"

# WireGuard: estado real del servicio wg-quick@wg0
if svc_active "wg-quick@wg0"; then
    WG_S="$_B_ON"
elif svc_exists "wg-quick@wg0"; then
    WG_S="$_B_OFF"
else
    WG_S="$_B_NA"
fi

# Contador de estado (rediseño): cuántos protocolos están activos
_SUM_ACT=0; _SUM_IN=0
for _svn in \
    ssh dropbear_custom haproxy udp-custom slowdns xray hysteria1-server proto-server \
    squid webmin systemd-resolved xhttp bhttp btun hcr movivip-web \
    shadowsocks-libev-server@8388 payload-pdirect openvpn@server sockd
do
    if svc_active "$_svn"; then ((_SUM_ACT++)); else ((_SUM_IN++)); fi
done
[[ "$ZIPVPN" == "ON" ]] && ((_SUM_ACT++)) || ((_SUM_IN++))
svc_active "wg-quick@wg0" && ((_SUM_ACT++)) || ((_SUM_IN++))
if [[ -n "$BOT_UNIT" ]] && svc_active "$BOT_UNIT"; then ((_SUM_ACT++)); else ((_SUM_IN++)); fi
if svc_exists "badvpn-udpgw-7200" || svc_exists "badvpn-udpgw"; then
    if svc_active "badvpn-udpgw-7200" || svc_active "badvpn-udpgw"; then ((_SUM_ACT++)); else ((_SUM_IN++)); fi
else
    ((_SUM_IN++))
fi

# Fallback seguro para centrado sin bordes (si ui.sh no lo trae)
if ! declare -F mv_center >/dev/null 2>&1; then
    mv_center() { printf '%b\n' "$1"; }
fi

clear
# Marco premium: ═══ + logo 3D MOVIVIP (centrado) + título + contactos + ═══
mv_brand_header "${PROTO_TITLE:-🚀 Protocolos}" "$(trx 'Panel de protocolos · estados en vivo')"
mv_prow_center "${_B_ON} ${_SUM_ACT} activos${RESET}  ${GRAY}·${RESET}  ${_B_OFF} ${_SUM_IN} inactivos${RESET}"

# ============================================================
# >>> v5.5: BARRA DE PUERTOS (chips emoji+puerto) <<<
# Arriba, junto al resumen. Abajo las filas quedan libres
# (solo bolita + emoji + nombre).
# ============================================================
mv_center "🔐22 📦U5667 🚪90·109·143 🔒443 ⚡7200·7300 🌊U36712 🐌53·5300 ☁️${XRAY_PORT:-443}"
mv_center "🌀U${HYSTERIA_PORT:-42726} 🛡U${WG_PORT:-51820} 🛰️${DTUNNEL_PORT:-4443}·${DTUNNEL_PORT2:-8081} 🧭53 🦑3128 🛠️10000 🤖gestion 🛸443·8080"
mv_center "📡80·8443 🧵7300 🐋8388 🧩8082-8085 🗝️U${OPENVPN_PORT:-1194} 🕸️T${SOCKS5_PORT:-1080} 🧱443‡8883 🌐${WEB_PORT:-9617}"
echo ""

# Selector: bolita + emoji + nombre (sin puertos, ya están arriba)
SEL=$(nav_pick "→ ${PROTO_TITLE:-Protocolos}:" \
    "${SSH_S} 🔐 ${PROTO_OPENSSH:-OpenSSH}" \
    "${ZIP_S} 📦 ${PROTO_ZIPVPN:-ZiVPN}" \
    "${DROP_S} 🚪 ${PROTO_DROPBEAR:-Dropbear}" \
    "${SSL_S} 🔒 ${PROTO_SSL:-SSL/TLS}" \
    "${BAD_S} ⚡ ${PROTO_BADVPN:-BadVPN}" \
    "${UDP_S} 🌊 ${PROTO_UDP:-UDP Custom}" \
    "${SLOW_S} 🐌 ${PROTO_SLOWDNS:-SlowDNS}" \
    "${XRAY_S} ☁️ ${PROTO_XRAY:-Xray · VMess/VLESS/Trojan}" \
    "${HY_S} 🌀 ${PROTO_HYSTERIA:-Hysteria}" \
    "${WG_S} 🛡 WireGuard" \
    "${DT_S} 🛰️ ${PROTO_DTUNNEL:-DTunnel}" \
    "${SYSTEMDNS_S} 🧭 ${PROTO_SYSTEMDNS:-SystemDNS}" \
    "${SQUID_S} 🦑 ${PROTO_SQUID:-Squid}" \
    "${WEBMIN_S} 🛠️ ${PROTO_WEBMIN:-Webmin}" \
    "${BOT_S} 🤖 ${PROTO_BOT:-Bot Telegram}" \
    "${XHTTP_S} 🛸 ${PROTO_XHTTP:-SSH-XHTTP}" \
    "${BHTTP_S} 📡 ${PROTO_BHTTP:-BHTTP v2}" \
    "${BTUN_S} 🧵 ${PROTO_BTUN:-BTUN}" \
    "${SS_S} 🐋 ${PROTO_SHADOWSOCKS:-Shadowsocks}" \
    "${PAY_S} 🧩 ${PROTO_PAYLOAD:-Payload}" \
    "${OVPN_S} 🗝️ ${PROTO_OPENVPN:-OpenVPN}" \
    "${SOCKS_S} 🕸️ ${PROTO_SOCKS5:-SOCKS5}" \
    "${HCR_S} 🧱 ${PROTO_HCR:-HCR Relay}" \
    "${WEB_S} 🌐 ${PROTO_WEB:-Web MoviVIP}" \
    "${XUI_S} 🎛️ ${PROTO_XUI:-3X-UI Panel}" \
    "🔌 ${PROTO_RESTART:-Reiniciar protocolos}")

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
25) bash "$BASE/protocolos/xui.sh" ; exec bash "$BASE/protocolos/menu.sh";;
26) echo -e "${YELLOW}⚠️ ${PROTO_RESTART_WARN:-Reiniciar protocolos cortará tu conexión SSH}${RESET}"; read -n1 -r -p "$(trx 'Presione una tecla para continuar...')"; restart_protocols ;;
0) exec bash "$BASE/menu.sh" ;;
*) echo -e "${RED}❌ ${PROTO_INVALID:-Opción inválida}${RESET}"; sleep 1; exec bash "$BASE/protocolos/menu.sh" ;;
esac
