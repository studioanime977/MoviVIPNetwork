#!/bin/bash

#==================================================
# MoviVIP Network
# Archivo Online
#==================================================

# ── i18n shim (auto) ───────────────────────────────
if ! declare -F trx >/dev/null 2>&1; then trx() { printf '%s' "$1"; }; fi
# ─────────────────────────────────────────────────────────
BASE="/etc/movivip"


# Design System premium + navegación + idioma
[[ -f "$BASE/lib/ui.sh" ]] && source "$BASE/lib/ui.sh"
[[ -f "$BASE/lib/nav.sh" ]] && source "$BASE/lib/nav.sh" 2>/dev/null || true
if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)"
fi


CYAN="${MV_CYN:-\e[1;96m}"
GREEN="${MV_GRN:-\e[1;92m}"
RED="${MV_RED:-\e[1;91m}"
YELLOW="${MV_YLW:-\e[1;93m}"
MAGENTA="${MV_MAG:-\e[1;95m}"
WHITE="${MV_WHT:-\e[1;97m}"
RESET="${MV_R:-\e[0m}"

while true
do

clear

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${MAGENTA}          ☁️ Archivo Online ☁️${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo ""
echo "$(trx ' [1] ➮ Subir Archivo')"
echo "$(trx ' [2] ➮ Ver Archivos del Directorio')"
echo ""
echo "$(trx ' [0] ➮ Regresar')"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

read -rp "$(trx ' ► Opción: ')" OP

case "$OP" in

1)

echo ""
read -rp "$(trx 'Ruta completa del archivo: ')" FILE

if [[ ! -f "$FILE" ]]; then
    echo ""
    echo -e "${RED}❌ Archivo no encontrado.${RESET}"
    sleep 3
    continue
fi

echo ""
echo "$(trx '⏳ Subiendo archivo...')"

URL=$(curl -s --upload-file "$FILE" https://transfer.sh/$(basename "$FILE"))

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}✅ Archivo subido correctamente${RESET}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo "📎 Enlace:"
echo ""
echo "$URL"
echo ""

read -n1 -r -p "$(trx 'Presione una tecla para continuar...')"

;;

2)

clear

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${MAGENTA}          📂 Archivos Disponibles${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

ls -lh

echo ""
read -n1 -r -p "$(trx 'Presione una tecla para continuar...')"

;;

0)

exec bash "$BASE/herramientas/menu.sh"

;;

*)

echo ""
echo -e "${RED}❌ Opción inválida.${RESET}"
sleep 2

;;

esac

done
