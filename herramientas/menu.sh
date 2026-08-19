#!/bin/bash

#=========================================================
#   MOVIVIP NETWORK â€” MENÃš HERRAMIENTAS v5.0
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
TOP(){ printf "${CYAN}â•”"; printf 'â•%.0s' $(seq 1 $W); printf "â•—${RESET}\n"; }
MID(){ printf "${CYAN}â• "; printf 'â•%.0s' $(seq 1 $W); printf "â•£${RESET}\n"; }
BOT(){ printf "${CYAN}â•š"; printf 'â•%.0s' $(seq 1 $W); printf "â•${RESET}\n"; }

clear
TOP
printf "${CYAN}â•‘${RESET}  ${GOLD}ðŸ›¡ï¸  MoviVIP Network${RESET}  ${WHITE}${TOOLS_TITLE:-Herramientas}${RESET}${CYAN}                    â•‘${RESET}\n"
printf "${CYAN}â•‘${RESET}  ${GRAY}movivip-network.web.app${RESET}  ${GRAY}Â·${RESET}  ${WHITE}${TOOLS_SUBTITLE:-Utilidades del sistema}${RESET}${CYAN}    â•‘${RESET}\n"
MID

printf "${CYAN}â•‘${RESET}  ${GOLD}[01]${WHITE} ðŸš« ${TOOLS_BLOCK_TORRENT:-Block Torrent}     ${CYAN}â”‚${RESET}  ${GOLD}[06]${WHITE} ðŸ”‘ ${TOOLS_ROOT_PASS:-ContraseÃ±a Root}${RESET}  ${CYAN}â•‘${RESET}\n"
printf "${CYAN}â•‘${RESET}  ${GOLD}[02]${WHITE} ðŸ“ ${TOOLS_ARCHIVO:-Archivo Online}    ${CYAN}â”‚${RESET}  ${GOLD}[07]${WHITE} ðŸ”Ž ${TOOLS_SCANNER:-Scanner}${RESET}        ${CYAN}â•‘${RESET}\n"
printf "${CYAN}â•‘${RESET}  ${GOLD}[03]${WHITE} âš¡ ${TOOLS_SPEEDTEST:-Speedtest}         ${CYAN}â”‚${RESET}  ${GOLD}[08]${WHITE} ðŸ›¡ ${TOOLS_FAIL2BAN:-Fail2ban}${RESET}       ${CYAN}â•‘${RESET}\n"
printf "${CYAN}â•‘${RESET}  ${GOLD}[04]${WHITE} ðŸ–¥ ${TOOLS_VPS_DETAILS:-Detalles VPS}      ${CYAN}â”‚${RESET}  ${GOLD}[09]${WHITE} ðŸ” ${TOOLS_AUDIT:-AuditorÃ­a}${RESET}      ${CYAN}â•‘${RESET}\n"
printf "${CYAN}â•‘${RESET}  ${GOLD}[05]${WHITE} ðŸ›¡ ${TOOLS_BLOCK_ADS:-Block Ads}         ${CYAN}â”‚${RESET}  ${GOLD}[10]${WHITE} ðŸ“Š ${TOOLS_NETWORK:-Consumo Red}${RESET}    ${CYAN}â•‘${RESET}\n"

MID
printf "${CYAN}â•‘${RESET}  ${RED}[00]${WHITE} â†© ${PROTO_BACK:-Volver al MenÃº Principal}${CYAN}%*sâ•‘${RESET}\n" $(( W - 32 )) ""
BOT

echo ""
read -rp "$(echo -e "${CYAN}âžœ ${GOLD}${PROTO_OPTION:-OpciÃ³n}${WHITE} âž¤ ${RESET}")" OP

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
        echo -e "${RED}âŒ fail2ban.sh no encontrado${RESET}"
        sleep 2
        exec bash "$BASE/herramientas/menu.sh"
    fi
;;
9)
    if [[ -f "$BASE/herramientas/auditoria.sh" ]]; then
        bash "$BASE/herramientas/auditoria.sh"
    else
        echo -e "${RED}âŒ auditoria.sh no encontrado${RESET}"
        sleep 2
        exec bash "$BASE/herramientas/menu.sh"
    fi
;;
10)
    if [[ -f "$BASE/herramientas/network_traffic.sh" ]]; then
        bash "$BASE/herramientas/network_traffic.sh"
    else
        echo -e "${RED}âŒ network_traffic.sh no encontrado${RESET}"
        sleep 2
        exec bash "$BASE/herramientas/menu.sh"
    fi
;;
0) exec bash "$BASE/menu.sh" ;;
*) echo -e "${RED}âŒ ${PROTO_INVALID:-OpciÃ³n invÃ¡lida}${RESET}"; sleep 2; exec bash "$BASE/herramientas/menu.sh" ;;
esac
