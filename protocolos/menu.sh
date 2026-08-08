#!/bin/bash

#==================================================
#   MoviVIP Network — PROTOCOLOS
#   Diseño compacto premium con estados en vivo
#==================================================

BASE="/etc/movivip"
CONFIG="$BASE/config.conf"

[[ -f "$CONFIG" ]] || { echo "❌ No se encontró la configuración."; exit 1; }

source "$CONFIG" 2>/dev/null

CYAN="\e[1;96m"; BLUE="\e[1;94m"; GOLD="\e[1;93m"; GREEN="\e[1;92m"
RED="\e[1;91m"; WHITE="\e[1;97m"; GRAY="\e[1;90m"; MAGENTA="\e[1;95m"; RESET="\e[0m"

loading() {
    local MSG="$1"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}        MoviVIP Network${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    echo -ne "${GOLD}$MSG${RESET}"
    for i in {1..4}; do echo -n "."; sleep 0.2; done
    echo ""
}

clear
loading "Verificando protocolos"

status_service() {
    local SERVICE="$1"
    local CONF="$2"
    if systemctl list-unit-files | grep -q "^${SERVICE}.service"; then
        if systemctl is-active --quiet "$SERVICE"; then
            echo -e "${GREEN}🟢 ACTIVO${RESET}"
        else
            echo -e "${RED}🔴 OFF${RESET}"
        fi
    else
        if [[ "$CONF" == "ON" ]]; then
            echo -e "${GREEN}🟢 ACTIVO${RESET}"
        else
            echo -e "${RED}🔴 OFF${RESET}"
        fi
    fi
}

OPENSSH_STATUS=$(status_service ssh "$OPENSSH")
DROPBEAR_STATUS=$(status_service dropbear_custom "$DROPBEAR")
SSL_STATUS=$(status_service haproxy "$SSL")
UDP_STATUS=$(status_service udp-custom "$UDP_CUSTOM")
SLOWDNS_STATUS=$(status_service slowdns "$SLOWDNS")
XRAY_STATUS=$(status_service xray "$V2RAY")

if [[ "$ZIPVPN" == "ON" ]]; then
    ZIPVPN_STATUS="${GREEN}🟢 ACTIVO${RESET}"
else
    ZIPVPN_STATUS="${RED}🔴 OFF${RESET}"
fi

if systemctl list-unit-files | grep -qE "badvpn-udpgw-7200|badvpn-udpgw"; then
    if systemctl is-active --quiet badvpn-udpgw-7200 || systemctl is-active --quiet badvpn-udpgw; then
        BADVPN_STATUS="${GREEN}🟢 ACTIVO${RESET}"
    else
        BADVPN_STATUS="${RED}🔴 OFF${RESET}"
    fi
else
    BADVPN_STATUS="${RED}🔴 OFF${RESET}"
fi

if systemctl list-unit-files | grep -qE "checkuser|check-user"; then
    CHECKUSER_STATUS="${GREEN}🟢 ACTIVO${RESET}"
else
    CHECKUSER_STATUS="${GRAY}⚪ N/A${RESET}"
fi

if [[ -d "$BASE/hwids" ]] && [[ -n "$(ls -A "$BASE/hwids" 2>/dev/null)" ]]; then
    HWID_STATUS="${GREEN}🟢 ACTIVO${RESET}"
else
    HWID_STATUS="${GRAY}⚪ N/A${RESET}"
fi

clear

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${MAGENTA}       🚀 MOVIVIP NETWORK — MENÚ DE PROTOCOLOS 🚀${RESET}${CYAN}       ║${RESET}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"
printf "${CYAN}║${RESET}  ${GOLD}[01]${WHITE} 🔐 OpenSSH      ${RESET}%b${CYAN}   ${GOLD}[07]${WHITE} 🌐 SlowDNS     ${RESET}%b${CYAN}  ║${RESET}\n" "$OPENSSH_STATUS" "$SLOWDNS_STATUS"
printf "${CYAN}║${RESET}  ${GOLD}[02]${WHITE} 📦 ZIPVPN       ${RESET}%b${CYAN}   ${GOLD}[08]${WHITE} ☁️ Xray/V2Ray  ${RESET}%b${CYAN}  ║${RESET}\n" "$ZIPVPN_STATUS" "$XRAY_STATUS"
printf "${CYAN}║${RESET}  ${GOLD}[03]${WHITE} 🚪 Dropbear     ${RESET}%b${CYAN}   ${GOLD}[09]${WHITE} 👤 CheckUser   ${RESET}%b${CYAN}  ║${RESET}\n" "$DROPBEAR_STATUS" "$CHECKUSER_STATUS"
printf "${CYAN}║${RESET}  ${GOLD}[04]${WHITE} 🔒 SSL/TLS      ${RESET}%b${CYAN}   ${GOLD}[10]${WHITE} 🧰 Herramientas${RESET}${CYAN}     ║${RESET}\n" "$SSL_STATUS"
printf "${CYAN}║${RESET}  ${GOLD}[05]${WHITE} ⚡ BadVPN       ${RESET}%b${CYAN}   ${GOLD}[11]${WHITE} 🔄 Reiniciar   ${RESET}${CYAN}      ║${RESET}\n" "$BADVPN_STATUS"
printf "${CYAN}║${RESET}  ${GOLD}[06]${WHITE} 🚀 UDP Custom   ${RESET}%b${CYAN}   ${GOLD}[12]${WHITE} 🔥 Firewall    ${RESET}${CYAN}      ║${RESET}\n" "$UDP_STATUS"
echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"
printf "${CYAN}║${RESET}  ${GOLD}[13]${WHITE} 🔑 Usuario HWID ${RESET}%b${CYAN}   ${RED}[00]${WHITE} ↩ Regresar            ${CYAN}   ║${RESET}\n" "$HWID_STATUS"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo ""
read -rp "$(echo -e "${CYAN}➜ ${GOLD}Opción${WHITE} ➤ ${RESET}")" OP

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
*)
    echo "❌ Opción inválida."
    sleep 2
    exec bash "$BASE/protocolos/menu.sh"
;;
esac
