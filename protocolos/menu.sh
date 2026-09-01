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

# i18n shim (auto)
if ! declare -F trx >/dev/null 2>&1; then trx() { printf '%s' "$1"; }; fi

RESET="\e[0m"; RED="\e[1;91m"; GREEN="\e[1;92m"; GOLD="\e[1;93m"
BLUE="\e[1;94m"; MAGENTA="\e[1;95m"; CYAN="\e[1;96m"; WHITE="\e[1;97m"; GRAY="\e[1;90m"

W=62
TOP(){ printf "${CYAN}╔"; printf '═%.0s' $(seq 1 $W); printf "╗${RESET}\n"; }
MID(){ printf "${CYAN}╠"; printf '═%.0s' $(seq 1 $W); printf "╣${RESET}\n"; }
BOT(){ printf "${CYAN}╚"; printf '═%.0s' $(seq 1 $W); printf "╝${RESET}\n"; }

svc_status() {
    local SERVICE="$1" CONF="$2"
    if systemctl list-unit-files 2>/dev/null | grep -q "^${SERVICE}.service"; then
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
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}          🔄 REINICIAR PROTOCOLOS${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
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
    )

    local OK=0 FAIL=0 SVC SVC_NAME
    for SVC in "${SERVICES[@]}"; do
        SVC_NAME="${SVC%%@*}"
        if systemctl list-unit-files 2>/dev/null | grep -q "^${SVC_NAME}"; then
            if systemctl restart "$SVC" 2>/dev/null; then
                echo -e "  ${GREEN}✅${RESET} $SVC"
                ((OK++))
            else
                echo -e "  ${RED}❌${RESET} $SVC"
                ((FAIL++))
            fi
        fi
    done

    echo ""
    echo -e "  ${GREEN}✔ ${OK}${RESET} reiniciados · ${RED}✘ ${FAIL}${RESET} con errores"
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

if systemctl list-unit-files 2>/dev/null | grep -qE "badvpn-udpgw-7200|badvpn-udpgw"; then
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
elif systemctl list-unit-files 2>/dev/null | grep -q "^wg-quick@.service"; then
    WG_S="${RED}●${RESET}"
else
    WG_S="${GRAY}○${RESET}"
fi

clear
# Banner principal NEBULA — solo protocolos (las herramientas viven en 🧰)
mv_header "${PROTO_TITLE:-🚀 Protocolos}" "$(trx 'Panel de protocolos · estados en vivo')" "v6.2"
movivip_contacts 2>/dev/null || true

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
    "${XRAY_S} ☁️  ${PROTO_XRAY:-Xray/V2Ray} ${GRAY}[${XRAY_PORT:-443}]${RESET}" \
    "${HY_S} 🚀 ${PROTO_HYSTERIA:-Hysteria} ${GRAY}[UDP ${HYSTERIA_PORT:-}--]${RESET}" \
    "${WG_S} 🛡 WireGuard ${GRAY}[UDP ${WG_PORT:-51820}]${RESET}" \
    "${DT_S} 🛰️ ${PROTO_DTUNNEL:-DTunnel} ${GRAY}${DT_INFO}${RESET}" \
    "${SQUID_S} 🌐 ${PROTO_SQUID:-Squid} ${GRAY}[3128]${RESET}" \
    "${WEBMIN_S} 🛠️ ${PROTO_WEBMIN:-Webmin} ${GRAY}[10000]${RESET}" \
    "🔄 ${PROTO_RESTART:-Reiniciar protocolos}")

case "$SEL" in
1) bash "$BASE/protocolos/openssh.sh" ;;
2) bash "$BASE/protocolos/zipvpn.sh" ;;
3) bash "$BASE/protocolos/dropbear.sh" ;;
4) bash "$BASE/protocolos/ssl.sh" ;;
5) bash "$BASE/protocolos/badvpn.sh" ;;
6) bash "$BASE/protocolos/udpcustom.sh" ;;
7) bash "$BASE/protocolos/slowdns.sh" ;;
8) bash "$BASE/protocolos/v2ray.sh" ;;
9) bash "$BASE/protocolos/hysteria.sh" ;;
10) bash "$BASE/protocolos/wireguard.sh" ;;
11) bash "$BASE/protocolos/dtunnel.sh" ;;
12) restart_protocols ;;
13) bash "$BASE/protocolos/squid.sh" ;;
14) bash "$BASE/protocolos/webmin.sh" ;;
0) exec bash "$BASE/menu.sh" ;;
*) echo -e "${RED}❌ ${PROTO_INVALID:-Opción inválida}${RESET}"; sleep 1; exec bash "$BASE/protocolos/menu.sh" ;;
esac
