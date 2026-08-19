#!/bin/bash

#=========================================================
#   MOVIVIP NETWORK — MENÚ PROTOCOLOS v5.0
#   Panel de protocolos con estados en vivo
#=========================================================

BASE="/etc/movivip"
CONFIG="$BASE/config.conf"

[[ -f "$CONFIG" ]] || { echo "❌ No se encontró config.conf"; exit 1; }
source "$CONFIG" 2>/dev/null

# Cargar idiomas
if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)"
fi
if [[ -f "$BASE/languages/protocols.sh" ]]; then
    source "$BASE/languages/protocols.sh"
fi

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

SSH_S=$(svc_status ssh "$OPENSSH")
DROP_S=$(svc_status dropbear_custom "$DROPBEAR")
SSL_S=$(svc_status haproxy "$SSL")
UDP_S=$(svc_status udp-custom "$UDP_CUSTOM")
SLOW_S=$(svc_status slowdns "$SLOWDNS")
XRAY_S=$(svc_status xray "$V2RAY")

[[ "$ZIPVPN" == "ON" ]] && ZIP_S="${GREEN}●${RESET}" || ZIP_S="${RED}●${RESET}"

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

clear
TOP
printf "${CYAN}║${RESET}  ${GOLD}🛡️  MoviVIP Network${RESET}  ${WHITE}${PROTO_TITLE:-Protocolos}${RESET}${CYAN}                    ║${RESET}\n"
printf "${CYAN}║${RESET}  ${GRAY}movivip-network.web.app${RESET}  ${GRAY}·${RESET}  ${WHITE}${PROTO_LIVE:-Estados en vivo}${RESET}${CYAN}              ║${RESET}\n"
MID

printf "${CYAN}║${RESET}  ${GOLD}[01]${RESET} ${SSH_S}  🔐 ${PROTO_OPENSSH:-OpenSSH}      ${GRAY}[22]${RESET}         ${GOLD}[07]${RESET} ${SLOW_S}  🌐 ${PROTO_SLOWDNS:-SlowDNS}      ${GRAY}[5300]${RESET}    ${CYAN}║${RESET}\n"
printf "${CYAN}║${RESET}  ${GOLD}[02]${RESET} ${ZIP_S}  📦 ${PROTO_ZIPVPN:-ZiVPN}        ${GRAY}[UDP 5667]${RESET}    ${GOLD}[08]${RESET} ${XRAY_S}  ☁️  ${PROTO_XRAY:-Xray/V2Ray}   ${GRAY}[80,443,8080,8443]${RESET}  ${CYAN}║${RESET}\n"
printf "${CYAN}║${RESET}  ${GOLD}[03]${RESET} ${DROP_S}  🚪 ${PROTO_DROPBEAR:-Dropbear}     ${GRAY}[90,109,143]${RESET}  ${GOLD}[09]${RESET} ${GRAY}○${RESET}   🔍 ${PROTO_CHECKUSER:-CheckUser}      ${GRAY}[--]${RESET}         ${CYAN}║${RESET}\n"
printf "${CYAN}║${RESET}  ${GOLD}[04]${RESET} ${SSL_S}  🔒 ${PROTO_SSL:-SSL/TLS}      ${GRAY}[80,443,8080,8443]${RESET} ${GOLD}[10]${RESET}       🛠  ${PROTO_TOOLS:-Herramientas}${CYAN}%*s║${RESET}\n" $(( W - 53 )) ""
printf "${CYAN}║${RESET}  ${GOLD}[05]${RESET} ${BAD_S}  ⚡ ${PROTO_BADVPN:-BadVPN}       ${GRAY}[7200,7300]${RESET}  ${GOLD}[11]${RESET}       🔄 ${PROTO_RESTART:-Reiniciar}${CYAN}%*s║${RESET}\n" $(( W - 48 )) ""
printf "${CYAN}║${RESET}  ${GOLD}[06]${RESET} ${UDP_S}  🚀 ${PROTO_UDP:-UDP Custom}   ${GRAY}[2100]${RESET}       ${GOLD}[12]${RESET}       🛡  ${PROTO_FIREWALL:-Firewall}${CYAN}%*s║${RESET}\n" $(( W - 48 )) ""

MID
printf "${CYAN}║${RESET}  ${GOLD}[13]${RESET} ${HWID_S}  👤 ${PROTO_HWID:-Usuario HWID}     ${RED}[00]${RESET} ↩ ${PROTO_BACK:-Regresar}${CYAN}%*s║${RESET}\n" $(( W - 42 )) ""
BOT

echo ""
read -rp "$(echo -e "${CYAN}➜ ${GOLD}${PROTO_OPTION:-Opción}${WHITE} ➤ ${RESET}")" OP

case "$OP" in
1) bash "$BASE/protocolos/openssh.sh" ;;
2) bash "$BASE/protocolos/zipvpn.sh" ;;
3) bash "$BASE/protocolos/dropbear.sh" ;;
4) bash "$BASE/protocolos/ssl.sh" ;;
5) bash "$BASE/protocolos/badvpn.sh" ;;
6) bash "$BASE/protocolos/udpcustom.sh" ;;
7) bash "$BASE/protocolos/slowdns.sh" ;;
8) bash "$BASE/protocolos/v2ray.sh" ;;
9) bash "$BASE/protocolos/checkuser.sh" ;;
10) bash "$BASE/herramientas/menu.sh" ;;
11) bash "$BASE/herramientas/reiniciar.sh" ;;
12) bash "$BASE/herramientas/firewall.sh" ;;
13) bash "$BASE/usuarios/add_hwid.sh" ;;
0) exec bash "$BASE/menu.sh" ;;
*) echo -e "${RED}❌ ${PROTO_INVALID:-Opción inválida}${RESET}"; sleep 2; exec bash "$BASE/protocolos/menu.sh" ;;
esac
