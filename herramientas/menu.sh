#!/bin/bash

#==========================================================
# MoviVIP Network
# Menú de Herramientas
#==========================================================

BASE="/etc/movivip"

clear

CYAN="\e[1;96m"
BLUE="\e[1;94m"
MAGENTA="\e[1;95m"
YELLOW="\e[1;93m"
GREEN="\e[1;92m"
RED="\e[1;91m"
WHITE="\e[1;97m"
RESET="\e[0m"

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${MAGENTA}          🧰 MoviVIP Herramientas${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

printf "${GREEN} [01]${WHITE} 🚫 Block Torrent\n"
printf "${GREEN} [02]${WHITE} 📁 Archivo Online\n"
printf "${GREEN} [03]${WHITE} ⚡ Speedtest\n"
printf "${GREEN} [04]${WHITE} 🖥 Detalles VPS\n"
printf "${GREEN} [05]${WHITE} 🛡 Block Ads\n"
printf "${GREEN} [06]${WHITE} 🔑 Cambiar contraseña Root\n"
printf "${GREEN} [07]${WHITE} 🔎 Scanner host o dominio\n"
printf "${GREEN} [08]${WHITE} 🛡 FAIL2BAN — Protección SSH\n"
printf "${GREEN} [09]${WHITE} 🔍 Auditoría de Seguridad\n"
printf "${GREEN} [10]${WHITE} 📊 Consumo de Red en Tiempo Real\n"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${YELLOW} [00]${WHITE} ↩ Regresar${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo ""
read -rp " ► Opción: " OP

case "$OP" in

1)
    bash "$BASE/herramientas/blocktorrent.sh"
;;

2)
    bash "$BASE/herramientas/archivoonline.sh"
;;

3)
    bash "$BASE/herramientas/speedtest.sh"
;;

4)
    bash "$BASE/herramientas/detalles.sh"
;;

5)
    bash "$BASE/herramientas/blockads.sh"
;;

6)
    bash "$BASE/herramientas/rootpass.sh"
;;

7)
    bash "$BASE/herramientas/scanner.sh"
;;

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

0)
    exec bash "$BASE/menu.sh"
;;

*)
    echo -e "${RED}❌ Opción inválida${RESET}"
    sleep 2
    exec bash "$BASE/herramientas/menu.sh"
;;

esac
