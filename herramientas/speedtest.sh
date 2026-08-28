#!/bin/bash

# ── i18n shim (auto) ───────────────────────────────
if ! declare -F trx >/dev/null 2>&1; then trx() { printf '%s' "$1"; }; fi
# ─────────────────────────────────────────────────────────
BASE="/etc/movivip"

CYAN="\e[1;96m"
GREEN="\e[1;92m"
RED="\e[1;91m"
MAGENTA="\e[1;95m"
RESET="\e[0m"

while true; do

clear

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${MAGENTA}              🚀 SPEEDTEST${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo
echo "$(trx ' [1] ➮ Ejecutar Speedtest')"
echo
echo "$(trx ' [0] ➮ Regresar')"
echo

read -rp "$(trx ' ► Opción: ')" OP

case "$OP" in

1)
    if command -v speedtest >/dev/null 2>&1; then
        speedtest
    else
        echo
        echo -e "${RED}❌ Speedtest oficial no está instalado.${RESET}"
        echo
        echo "$(trx 'Instálalo primero y vuelve a intentarlo.')"
    fi

    echo
    read -n1 -r -p "$(trx 'Presione una tecla para continuar...')"
;;

0)
    exec bash "$BASE/herramientas/menu.sh"
;;

*)
    echo "$(trx '❌ Opción inválida.')"
    sleep 2
;;

esac

done
