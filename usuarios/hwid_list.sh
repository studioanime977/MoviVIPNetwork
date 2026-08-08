#!/bin/bash
#==================================================
# MoviVIP Network Premium
# Listar Usuarios con HWID
#==================================================

#======== COLORES ========#
GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
CYAN="\e[1;96m"
MAGENTA="\e[1;95m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"
RESET="\e[0m"

#======== CONFIG ========#
BASE="/etc/movivip"
HWID_DIR="$BASE/hwids"

clear

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${MAGENTA}               ⚜️ MoviVIP Network ⚜️                ${CYAN}║${RESET}"
echo -e "${CYAN}║${WHITE}            LISTA DE USUARIOS CON HWID 🔐              ${CYAN}║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo

if [[ ! -d "$HWID_DIR" ]] || [[ -z "$(ls -A "$HWID_DIR" 2>/dev/null)" ]]; then
    echo -e "${YELLOW}  📭 No hay usuarios con HWID registrados todavía.${RESET}"
    echo
    echo -e "${WHITE}  ➤ Use la opción: ${GREEN}[09] Usuario HWID${WHITE} para crear uno.${RESET}"
    echo
    read -rp "$(echo -e "${YELLOW}Pulse Enter para volver...${RESET}")"
    exit 0
fi

count=0
for f in "$HWID_DIR"/*.hwid; do
    [[ -e "$f" ]] || continue
    count=$((count + 1))
    USER=$(grep -m1 "^USER:" "$f" | cut -d' ' -f2)
    HWID=$(grep -m1 "^HWID:" "$f" | cut -d' ' -f2)
    EXPIRE=$(grep -m1 "^EXPIRE:" "$f" | cut -d' ' -f2)
    LIMIT=$(grep -m1 "^LIMIT:" "$f" | cut -d' ' -f2)

    echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${RESET}"
    printf "${WHITE}│ 👤 Usuario    : ${GREEN}%-35s${WHITE}│\n" "$USER"
    printf "${WHITE}│ 🔒 HWID       : ${YELLOW}%-35s${WHITE}│\n" "$HWID"
    printf "${WHITE}│ 📅 Expira     : ${GREEN}%-35s${WHITE}│\n" "$EXPIRE"
    printf "${WHITE}│ 👥 Límite     : ${GREEN}%-35s${WHITE}│\n" "$LIMIT"
    echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${RESET}"
    echo
done

echo -e "${GREEN}  Total: $count usuario(s) con HWID${RESET}"
echo
read -rp "$(echo -e "${YELLOW}Pulse Enter para volver...${RESET}")"
exit 0
