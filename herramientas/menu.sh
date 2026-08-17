#!/bin/bash

#=========================================================
#   MOVIVIP NETWORK — MENÚ HERRAMIENTAS v5.0
#   Panel de herramientas del sistema
#=========================================================

BASE="/etc/movivip"

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

clear
TOP
printf "${CYAN}║${GOLD}  ╔═╗╦═╗╦ ╦╔═╗╔╦╗╔═╗╔╗╔╔╦╗${RESET}  ${WHITE}MoviVIP Network${RESET}${CYAN}           ║${RESET}\n"
printf "${CYAN}║${GOLD}  ╠═╣╠╦╝╚╦╝║ ║ ║ ║╣ ║║║ ║ ${RESET}  ${GRAY}movivip-network.web.app${RESET}     ${CYAN}║${RESET}\n"
printf "${CYAN}║${GOLD}  ╩ ╩╩   ╩ ╚═╝ ╩ ╚═╝╝╚╝ ╩ ${RESET}  ${WHITE}${TOOLS_TITLE:-Herramientas}${RESET}              ${CYAN}║${RESET}\n"
MID

printf "${CYAN}║${RESET}  ${GOLD}[01]${WHITE} 🚫 ${TOOLS_BLOCK_TORRENT:-Block Torrent}     ${CYAN}│${RESET}  ${GOLD}[06]${WHITE} 🔑 ${TOOLS_ROOT_PASS:-Contraseña Root}${RESET}  ${CYAN}║${RESET}\n"
printf "${CYAN}║${RESET}  ${GOLD}[02]${WHITE} 📁 ${TOOLS_ARCHIVO:-Archivo Online}    ${CYAN}│${RESET}  ${GOLD}[07]${WHITE} 🔎 ${TOOLS_SCANNER:-Scanner}${RESET}        ${CYAN}║${RESET}\n"
printf "${CYAN}║${RESET}  ${GOLD}[03]${WHITE} ⚡ ${TOOLS_SPEEDTEST:-Speedtest}         ${CYAN}│${RESET}  ${GOLD}[08]${WHITE} 🛡 ${TOOLS_FAIL2BAN:-Fail2ban}${RESET}       ${CYAN}║${RESET}\n"
printf "${CYAN}║${RESET}  ${GOLD}[04]${WHITE} 🖥 ${TOOLS_VPS_DETAILS:-Detalles VPS}      ${CYAN}│${RESET}  ${GOLD}[09]${WHITE} 🔍 ${TOOLS_AUDIT:-Auditoría}${RESET}      ${CYAN}║${RESET}\n"
printf "${CYAN}║${RESET}  ${GOLD}[05]${WHITE} 🛡 ${TOOLS_BLOCK_ADS:-Block Ads}         ${CYAN}│${RESET}  ${GOLD}[10]${WHITE} 📊 ${TOOLS_NETWORK:-Consumo Red}${RESET}    ${CYAN}║${RESET}\n"

MID
printf "${CYAN}║${RESET}  ${RED}[00]${WHITE} ↩ ${PROTO_BACK:-Volver al Menú Principal}${CYAN}%*s║${RESET}\n" $(( W - 32 )) ""
BOT

echo ""
read -rp "$(echo -e "${CYAN}➜ ${GOLD}${PROTO_OPTION:-Opción}${WHITE} ➤ ${RESET}")" OP

case "$OP" in
1) bash "$BASE/herramientas/blocktorrent.sh" ;;
2) bash "$BASE/herramientas/archivoonline.sh" ;;
3) bash "$BASE/herramientas/speedtest.sh" ;;
4) bash "$BASE/herramientas/detalles.sh" ;;
5) bash "$BASE/herramientas/blockads.sh" ;;
6) bash "$BASE/herramientas/rootpass.sh" ;;
7) bash "$BASE/herramientas/scanner.sh" ;;
8)
    if [[ -f "$BASE/herramientas/fail2ban.sh" ]]; then
        bash "$BASE/herramientas/fail2ban.sh"
    else
        echo -e "${RED}❌ fail2ban.sh no encontrado${RESET}"
        sleep 2
        exec bash "$BASE/herramientas/menu.sh"
    fi
;;
9)
    if [[ -f "$BASE/herramientas/auditoria.sh" ]]; then
        bash "$BASE/herramientas/auditoria.sh"
    else
        echo -e "${RED}❌ auditoria.sh no encontrado${RESET}"
        sleep 2
        exec bash "$BASE/herramientas/menu.sh"
    fi
;;
10)
    if [[ -f "$BASE/herramientas/network_traffic.sh" ]]; then
        bash "$BASE/herramientas/network_traffic.sh"
    else
        echo -e "${RED}❌ network_traffic.sh no encontrado${RESET}"
        sleep 2
        exec bash "$BASE/herramientas/menu.sh"
    fi
;;
0) exec bash "$BASE/menu.sh" ;;
*) echo -e "${RED}❌ ${PROTO_INVALID:-Opción inválida}${RESET}"; sleep 2; exec bash "$BASE/herramientas/menu.sh" ;;
esac
