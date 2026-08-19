#!/bin/bash
#==================================================
# MoviVIP Network Premium
# Ver bloqueos automÃ¡ticos por anti-share HWID
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
SISTEMA="$BASE/sistema"
LOG="$SISTEMA/hwid_bloqueos.log"

# Cargar idioma
if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)"
fi

clear

echo -e "${CYAN}â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—${RESET}"
echo -e "${CYAN}â•‘${MAGENTA}               âšœï¸ MoviVIP Network âšœï¸                ${CYAN}â•‘${RESET}"
echo -e "${CYAN}â•‘${WHITE}         ðŸ›¡ BLOQUEOS POR ANTI-SHARE HWID ðŸ›¡          ${CYAN}â•‘${RESET}"
echo -e "${CYAN}â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${RESET}"
echo

if [[ ! -f "$LOG" ]] || [[ ! -s "$LOG" ]]; then
    echo -e "${GREEN}  âœ… No hay bloqueos por anti-share registrados.${RESET}"
    echo
    echo -e "${GRAY}  Los bloqueos aparecen aquÃ­ cuando una cuenta HWID excede${RESET}"
    echo -e "${GRAY}  sus conexiones simultÃ¡neas (seÃ±al de comparticiÃ³n).${RESET}"
    echo
    read -rp "$(echo -e "${YELLOW}Pulse Enter para volver...${RESET}")"
    exit 0
fi

echo -e "${YELLOW}  ðŸ“‹ HISTORIAL DE BLOQUEOS:${RESET}"
echo -e "${CYAN}â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”${RESET}"
while IFS= read -r LINEA; do
    [[ -z "$LINEA" ]] && continue
    echo -e "${WHITE}â”‚ ${RED}âš ${WHITE} ${LINEA:0:96}${CYAN}â”‚${RESET}"
done < "$LOG"
echo -e "${CYAN}â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜${RESET}"
echo

echo -e "${GREEN}  ðŸ’¡ Para desbloquear: MenÃº Usuarios â†’ [07] Bloquear â†’ desbloquear.${RESET}"
echo -e "${GRAY}  âš  Si un cliente fue bloqueado por anti-share, revisa si compartiÃ³${RESET}"
echo -e "${GRAY}  su config. Si fue un falso positivo (misma persona, varios tÃºneles),${RESET}"
echo -e "${GRAY}  sÃºbele las conexiones mÃ¡x con: ${GREEN}Cambiar HWID [11]${RESET} o editando el .hwid.${RESET}"
echo
read -rp "$(echo -e "${YELLOW}Pulse Enter para volver...${RESET}")"
exit 0
