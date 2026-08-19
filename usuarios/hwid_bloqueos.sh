#!/bin/bash
#==================================================
# MoviVIP Network Premium
# Ver bloqueos automáticos por anti-share HWID
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

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${MAGENTA}               ⚜️ MoviVIP Network ⚜️                ${CYAN}║${RESET}"
echo -e "${CYAN}║${WHITE}         🛡 BLOQUEOS POR ANTI-SHARE HWID 🛡          ${CYAN}║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo

if [[ ! -f "$LOG" ]] || [[ ! -s "$LOG" ]]; then
    echo -e "${GREEN}  ✅ No hay bloqueos por anti-share registrados.${RESET}"
    echo
    echo -e "${GRAY}  Los bloqueos aparecen aquí cuando una cuenta HWID excede${RESET}"
    echo -e "${GRAY}  sus conexiones simultáneas (señal de compartición).${RESET}"
    echo
    read -rp "$(echo -e "${YELLOW}Pulse Enter para volver...${RESET}")"
    exit 0
fi

echo -e "${YELLOW}  📋 HISTORIAL DE BLOQUEOS:${RESET}"
echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${RESET}"
while IFS= read -r LINEA; do
    [[ -z "$LINEA" ]] && continue
    echo -e "${WHITE}│ ${RED}⚠${WHITE} ${LINEA:0:96}${CYAN}│${RESET}"
done < "$LOG"
echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${RESET}"
echo

echo -e "${GREEN}  💡 Para desbloquear: Menú Usuarios → [07] Bloquear → desbloquear.${RESET}"
echo -e "${GRAY}  ⚠ Si un cliente fue bloqueado por anti-share, revisa si compartió${RESET}"
echo -e "${GRAY}  su config. Si fue un falso positivo (misma persona, varios túneles),${RESET}"
echo -e "${GRAY}  súbele las conexiones máx con: ${GREEN}Cambiar HWID [11]${RESET} o editando el .hwid.${RESET}"
echo
read -rp "$(echo -e "${YELLOW}Pulse Enter para volver...${RESET}")"
exit 0
