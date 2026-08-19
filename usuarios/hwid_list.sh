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

# Cargar idioma
if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)"
fi

clear

echo -e "${CYAN}â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—${RESET}"
echo -e "${CYAN}â•‘${MAGENTA}               âšœï¸ MoviVIP Network âšœï¸                ${CYAN}â•‘${RESET}"
echo -e "${CYAN}â•‘${WHITE}            LISTA DE USUARIOS CON HWID ðŸ”              ${CYAN}â•‘${RESET}"
echo -e "${CYAN}â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${RESET}"
echo

if [[ ! -d "$HWID_DIR" ]] || [[ -z "$(ls -A "$HWID_DIR" 2>/dev/null)" ]]; then
    echo -e "${YELLOW}  ðŸ“­ No hay usuarios con HWID registrados todavÃ­a.${RESET}"
    echo
    echo -e "${WHITE}  âž¤ Use la opciÃ³n: ${GREEN}[09] Usuario HWID${WHITE} para crear uno.${RESET}"
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
    PASS=$(grep -m1 "^PASS:" "$f" | cut -d' ' -f2)
    EXPIRE=$(grep -m1 "^EXPIRE:" "$f" | cut -d' ' -f2)
    MAXCONN=$(grep -m1 "^MAXCONN:" "$f" | cut -d' ' -f2)

    # Estado: BLOQUEADO / ACTIVO / EXPIRADO
    if ! id "$USER" &>/dev/null; then
        ESTADO="${RED}âŒ SIN CUENTA${RESET}"
    elif passwd -S "$USER" 2>/dev/null | awk '{print $2}' | grep -q "L"; then
        ESTADO="${RED}ðŸ”’ BLOQUEADO${RESET}"
    elif [[ "$EXPIRE" < "$(date +%Y-%m-%d)" ]]; then
        ESTADO="${YELLOW}â° EXPIRADO${RESET}"
    else
        ESTADO="${GREEN}âœ… ACTIVO${RESET}"
    fi

    echo -e "${CYAN}â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”${RESET}"
    printf "${WHITE}â”‚ ðŸ‘¤ Usuario    : ${GREEN}%-35s${WHITE}â”‚\n" "$USER"
    printf "${WHITE}â”‚ ðŸ”’ HWID       : ${YELLOW}%-35s${WHITE}â”‚\n" "$HWID"
    printf "${WHITE}â”‚ ðŸ”‘ ContraseÃ±a : ${MAGENTA}%-35s${WHITE}â”‚\n" "$PASS"
    printf "${WHITE}â”‚ ðŸ“… Expira     : ${GREEN}%-35s${WHITE}â”‚\n" "$EXPIRE"
    printf "${WHITE}â”‚ ðŸ”— Conexiones : ${GREEN}%-35s${WHITE}â”‚\n" "$MAXCONN"
    printf "${WHITE}â”‚ ðŸ“Š Estado     : %b%-35s${WHITE}â”‚\n" "$ESTADO" ""
    echo -e "${CYAN}â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜${RESET}"
    echo
done

echo -e "${GREEN}  Total: $count usuario(s) con HWID${RESET}"
echo
read -rp "$(echo -e "${YELLOW}Pulse Enter para volver...${RESET}")"
exit 0
