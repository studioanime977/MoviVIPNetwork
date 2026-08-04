#!/bin/bash

#==========================================================
#   MoviVIP Network — HERRAMIENTAS
#   Diseño compacto premium
#==========================================================

BASE="/etc/movivip"

CYAN="\e[1;96m"; BLUE="\e[1;94m"; GOLD="\e[1;93m"; GREEN="\e[1;92m"
RED="\e[1;91m"; WHITE="\e[1;97m"; MAGENTA="\e[1;95m"; RESET="\e[0m"

clear

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${MAGENTA}            🧰 MOVIVIP NETWORK — HERRAMIENTAS 🧰${RESET}${CYAN}            ║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo ""

printf "${CYAN}║${RESET}  ${GREEN}[01]${WHITE} 🚫 Block Torrent     ${CYAN}│${RESET}  ${GREEN}[06]${WHITE} 🔑 Contraseña Root${CYAN}  ║${RESET}\n"
printf "${CYAN}║${RESET}  ${GREEN}[02]${WHITE} 📁 Archivo Online    ${CYAN}│${RESET}  ${GREEN}[07]${WHITE} 🔎 Scanner        ${CYAN}  ║${RESET}\n"
printf "${CYAN}║${RESET}  ${GREEN}[03]${WHITE} ⚡ Speedtest         ${CYAN}│${RESET}  ${GREEN}[08]${WHITE} 🛡 Fail2ban       ${CYAN}  ║${RESET}\n"
printf "${CYAN}║${RESET}  ${GREEN}[04]${WHITE} 🖥 Detalles VPS      ${CYAN}│${RESET}  ${GREEN}[09]${WHITE} 🔍 Auditoría      ${CYAN}  ║${RESET}\n"
printf "${CYAN}║${RESET}  ${GREEN}[05]${WHITE} 🛡 Block Ads         ${CYAN}│${RESET}  ${GREEN}[10]${WHITE} 📊 Consumo Red    ${CYAN}  ║${RESET}\n"
echo ""
printf "${CYAN}║${RESET}  ${RED}[00]${WHITE} ↩ Regresar al Menú Principal${CYAN}                              ║${RESET}\n"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo ""
read -rp "$(echo -e "${CYAN}➜ ${GOLD}Opción${WHITE} ➤ ${RESET}")" OP

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
*)
    echo -e "${RED}❌ Opción inválida${RESET}"
    sleep 2
    exec bash "$BASE/herramientas/menu.sh"
;;

esac
