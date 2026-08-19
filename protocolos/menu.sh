#!/bin/bash

#=========================================================
#   MOVIVIP NETWORK â€” MENÃš PROTOCOLOS v5.0
#   Panel de protocolos con estados en vivo
#=========================================================

BASE="/etc/movivip"
CONFIG="$BASE/config.conf"

[[ -f "$CONFIG" ]] || { echo "âŒ No se encontrÃ³ config.conf"; exit 1; }
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
TOP(){ printf "${CYAN}â•”"; printf 'â•%.0s' $(seq 1 $W); printf "â•—${RESET}\n"; }
MID(){ printf "${CYAN}â• "; printf 'â•%.0s' $(seq 1 $W); printf "â•£${RESET}\n"; }
BOT(){ printf "${CYAN}â•š"; printf 'â•%.0s' $(seq 1 $W); printf "â•${RESET}\n"; }

svc_status() {
    local SERVICE="$1" CONF="$2"
    if systemctl list-unit-files 2>/dev/null | grep -q "^${SERVICE}.service"; then
        if systemctl is-active --quiet "$SERVICE"; then
            echo -e "${GREEN}â—${RESET}"
        else
            echo -e "${RED}â—${RESET}"
        fi
    else
        [[ "$CONF" == "ON" ]] && echo -e "${GREEN}â—${RESET}" || echo -e "${RED}â—${RESET}"
    fi
}

SSH_S=$(svc_status ssh "$OPENSSH")
DROP_S=$(svc_status dropbear_custom "$DROPBEAR")
SSL_S=$(svc_status haproxy "$SSL")
UDP_S=$(svc_status udp-custom "$UDP_CUSTOM")
SLOW_S=$(svc_status slowdns "$SLOWDNS")
XRAY_S=$(svc_status xray "$V2RAY")

[[ "$ZIPVPN" == "ON" ]] && ZIP_S="${GREEN}â—${RESET}" || ZIP_S="${RED}â—${RESET}"

if systemctl list-unit-files 2>/dev/null | grep -qE "badvpn-udpgw-7200|badvpn-udpgw"; then
    if systemctl is-active --quiet badvpn-udpgw-7200 2>/dev/null || systemctl is-active --quiet badvpn-udpgw 2>/dev/null; then
        BAD_S="${GREEN}â—${RESET}"
    else
        BAD_S="${RED}â—${RESET}"
    fi
else
    BAD_S="${RED}â—${RESET}"
fi

[[ -d "$BASE/hwids" && -n "$(ls -A "$BASE/hwids" 2>/dev/null)" ]] && HWID_S="${GREEN}â—${RESET}" || HWID_S="${GRAY}â—‹${RESET}"

clear
TOP
printf "${CYAN}â•‘${RESET}  ${GOLD}ðŸ›¡ï¸  MoviVIP Network${RESET}  ${WHITE}${PROTO_TITLE:-Protocolos}${RESET}${CYAN}                    â•‘${RESET}\n"
printf "${CYAN}â•‘${RESET}  ${GRAY}movivip-network.web.app${RESET}  ${GRAY}Â·${RESET}  ${WHITE}${PROTO_LIVE:-Estados en vivo}${RESET}${CYAN}              â•‘${RESET}\n"
MID

printf "${CYAN}â•‘${RESET}  ${GOLD}[01]${RESET} ${SSH_S}  ðŸ” ${PROTO_OPENSSH:-OpenSSH}      ${GRAY}[22]${RESET}         ${GOLD}[07]${RESET} ${SLOW_S}  ðŸŒ ${PROTO_SLOWDNS:-SlowDNS}      ${GRAY}[5300]${RESET}    ${CYAN}â•‘${RESET}\n"
printf "${CYAN}â•‘${RESET}  ${GOLD}[02]${RESET} ${ZIP_S}  ðŸ“¦ ${PROTO_ZIPVPN:-ZiVPN}        ${GRAY}[UDP 5667]${RESET}    ${GOLD}[08]${RESET} ${XRAY_S}  â˜ï¸  ${PROTO_XRAY:-Xray/V2Ray}   ${GRAY}[80,443,8080,8443]${RESET}  ${CYAN}â•‘${RESET}\n"
printf "${CYAN}â•‘${RESET}  ${GOLD}[03]${RESET} ${DROP_S}  ðŸšª ${PROTO_DROPBEAR:-Dropbear}     ${GRAY}[90,109,143]${RESET}  ${GOLD}[09]${RESET} ${GRAY}â—‹${RESET}   ðŸ” ${PROTO_CHECKUSER:-CheckUser}      ${GRAY}[--]${RESET}         ${CYAN}â•‘${RESET}\n"
printf "${CYAN}â•‘${RESET}  ${GOLD}[04]${RESET} ${SSL_S}  ðŸ”’ ${PROTO_SSL:-SSL/TLS}      ${GRAY}[80,443,8080,8443]${RESET} ${GOLD}[10]${RESET}       ðŸ›   ${PROTO_TOOLS:-Herramientas}${CYAN}%*sâ•‘${RESET}\n" $(( W - 53 )) ""
printf "${CYAN}â•‘${RESET}  ${GOLD}[05]${RESET} ${BAD_S}  âš¡ ${PROTO_BADVPN:-BadVPN}       ${GRAY}[7200,7300]${RESET}  ${GOLD}[11]${RESET}       ðŸ”„ ${PROTO_RESTART:-Reiniciar}${CYAN}%*sâ•‘${RESET}\n" $(( W - 48 )) ""
printf "${CYAN}â•‘${RESET}  ${GOLD}[06]${RESET} ${UDP_S}  ðŸš€ ${PROTO_UDP:-UDP Custom}   ${GRAY}[2100]${RESET}       ${GOLD}[12]${RESET}       ðŸ›¡  ${PROTO_FIREWALL:-Firewall}${CYAN}%*sâ•‘${RESET}\n" $(( W - 48 )) ""

MID
printf "${CYAN}â•‘${RESET}  ${GOLD}[13]${RESET} ${HWID_S}  ðŸ‘¤ ${PROTO_HWID:-Usuario HWID}     ${RED}[00]${RESET} â†© ${PROTO_BACK:-Regresar}${CYAN}%*sâ•‘${RESET}\n" $(( W - 42 )) ""
BOT

echo ""
read -rp "$(echo -e "${CYAN}âžœ ${GOLD}${PROTO_OPTION:-OpciÃ³n}${WHITE} âž¤ ${RESET}")" OP

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
*) echo -e "${RED}âŒ ${PROTO_INVALID:-OpciÃ³n invÃ¡lida}${RESET}"; sleep 2; exec bash "$BASE/protocolos/menu.sh" ;;
esac
