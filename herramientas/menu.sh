#!/bin/bash

#=========================================================
#   MOVIVIP NETWORK — MENÚ HERRAMIENTAS v5.1
#   Panel de herramientas · navegación con flechitas
#=========================================================

BASE="/etc/movivip"

if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)"
fi
if [[ -f "$BASE/languages/protocols.sh" ]]; then
    source "$BASE/languages/protocols.sh"
fi
source "$BASE/lib/nav.sh" 2>/dev/null || true

RESET="\e[0m"; RED="\e[1;91m"; GREEN="\e[1;92m"; GOLD="\e[1;93m"
BLUE="\e[1;94m"; MAGENTA="\e[1;95m"; CYAN="\e[1;96m"; WHITE="\e[1;97m"; GRAY="\e[1;90m"

W=62
TOP(){ printf "${CYAN}╔"; printf '═%.0s' $(seq 1 $W); printf "╗${RESET}\n"; }
MID(){ printf "${CYAN}╠"; printf '═%.0s' $(seq 1 $W); printf "╣${RESET}\n"; }
BOT(){ printf "${CYAN}╚"; printf '═%.0s' $(seq 1 $W); printf "╝${RESET}\n"; }

clear
movivip_sub_header "${TOOLS_TITLE:-Herramientas}"

echo ""
SEL=$(nav_pick "► Opción:" \
    "🚫 ${TOOLS_BLOCK_TORRENT:-Block Torrent}" \
    "📁 ${TOOLS_ARCHIVO:-Archivo Online}" \
    "⚡ ${TOOLS_SPEEDTEST:-Speedtest}" \
    "🖥 ${TOOLS_VPS_DETAILS:-Detalles VPS}" \
    "🛡 ${TOOLS_BLOCK_ADS:-Block Ads}" \
    "🔑 ${TOOLS_ROOT_PASS:-Contraseña Root}" \
    "🔎 ${TOOLS_SCANNER:-Scanner}" \
    "🛡 ${TOOLS_FAIL2BAN:-Fail2ban}" \
    "🔍 ${TOOLS_AUDIT:-Auditoría}" \
    "📊 ${TOOLS_NETWORK:-Consumo Red}" \
    "🧱 ${TOOLS_DDOS:-Anti-DDoS}" \
    "👁 ${TOOLS_ONLINE:-Usuarios Online}" \
    "🧩 ${TOOLS_APIACCESS:-API Access (Bots)}")

case "$SEL" in
1) bash "$BASE/herramientas/blocktorrent.sh" ;;
2) bash "$BASE/herramientas/archivoonline.sh" ;;
3) bash "$BASE/herramientas/speedtest.sh" ;;
4) bash "$BASE/herramientas/detalles.sh" ;;
5) bash "$BASE/herramientas/blockads.sh" ;;
6) bash "$BASE/herramientas/rootpass.sh" ;;
7)
    if [[ -f "$BASE/herramientas/scanner.sh" ]]; then
        bash "$BASE/herramientas/scanner.sh"
    else
        echo -e "${RED}❌ scanner.sh no encontrado${RESET}"
        sleep 2
        exec bash "$BASE/herramientas/menu.sh"
    fi
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
11)
    if [[ -f "$BASE/herramientas/ddos.sh" ]]; then
        bash "$BASE/herramientas/ddos.sh"
    else
        echo -e "${RED}❌ ddos.sh no encontrado${RESET}"
        sleep 2
        exec bash "$BASE/herramientas/menu.sh"
    fi
;;
12)
    # Usuarios Online — usa usuarios/online.sh (motor real de conteo)
    if [[ -f "$BASE/usuarios/online.sh" ]]; then
        bash "$BASE/usuarios/online.sh"
    elif [[ -f "$BASE/herramientas/monitor.sh" ]]; then
        bash "$BASE/herramientas/monitor.sh"
    else
        echo -e "${RED}❌ online.sh no encontrado${RESET}"
        sleep 2
        exec bash "$BASE/herramientas/menu.sh"
    fi
;;
13)
    bash "$BASE/herramientas/instalar_apiaccess.sh"
    exec bash "$BASE/herramientas/menu.sh"
;;
0) exec bash "$BASE/menu.sh" ;;
*) echo -e "${RED}❌ ${PROTO_INVALID:-Opción inválida}${RESET}"; sleep 1; exec bash "$BASE/herramientas/menu.sh" ;;
esac
