#!/bin/bash

#=========================================================
#   MoviVIP Network — MENÚ DE HERRAMIENTAS
#   Panel central de gestión / utilidades del servidor.
#   Menú PLANO — todas las herramientas en 1 pantalla:
#     Block Torrent · Archivo Online · Speedtest ·
#     Detalles VPS · Block Ads · Root Pass · Scanner ·
#     Fail2ban · Auditoría · Firewall · OpenPorts ...
#   Design System NEBULA + navegador nav_pick.
#=========================================================

BASE="/etc/movivip"
CONFIG="$BASE/config.conf"

# ── i18n shim (auto) ───────────────────────────────────
if ! declare -F trx >/dev/null 2>&1; then trx() { printf '%s' "$1"; }; fi

# ── Cargar idioma + trx + diseño + navegación ──────────
if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)"
fi
source "$BASE/lib/ui.sh" 2>/dev/null || true
source "$BASE/lib/nav.sh" 2>/dev/null || true

[[ -f "$CONFIG" ]] && source "$CONFIG"

# Colores MoviVIP
RESET="\e[0m"; RED="\e[1;91m"; GREEN="\e[1;92m"; GOLD="\e[1;93m"
BLUE="\e[1;94m"; CYAN="\e[1;96m"; WHITE="\e[1;97m"; GRAY="\e[1;90m"

# ────────────────────────────────────────────────────────
# Executores — siempre vuelven a Herramientas
# $1 = script (herramientas/ o protocolos/)
# ────────────────────────────────────────────────────────
_run_herr() {
    local script="$BASE/herramientas/$1"
    clear
    if [[ -f "$script" ]]; then
        bash "$script"
    else
        echo -e "${RED}❌ $(trx 'No encontrado'): $1${RESET}"
        sleep 2
    fi
    exec bash "$BASE/herramientas/menu.sh"
}

_run_proto() {
    local script="$BASE/protocolos/$1"
    clear
    if [[ -f "$script" ]]; then
        bash "$script"
    else
        echo -e "${RED}❌ $(trx 'No encontrado'): $1${RESET}"
        sleep 2
    fi
    exec bash "$BASE/herramientas/menu.sh"
}

# ────────────────────────────────────────────────────────
# Menú PLANO — todas las herramientas en una sola pantalla
# ────────────────────────────────────────────────────────
clear
mv_header "$(trx '🧰 Herramientas MoviVIP')" "$(trx 'Panel de utilidades y gestión del servidor')" "v6.2"
movivip_contacts 2>/dev/null || true
echo ""
SEL=$(nav_pick "► $(trx 'Opción:'):" \
    "🧲 Block Torrent" \
    "📤 Archivo Online" \
    "🚀 Speedtest" \
    "ℹ️ Detalles VPS" \
    "🚫 Block Ads" \
    "🔑 Cambiar Contraseña Root" \
    "🕵 Scanner host/dominio" \
    "🛡 Fail2ban" \
    "🔍 Auditoría completa" \
    "🐛 Anti-Minero / Scan" \
    "🧱 Firewall" \
    "🔓 Open Ports" \
    "⚡ Optimizar VPS" \
    "🔄 Reiniciar Servicios" \
    "📊 Consumo de Red" \
    "▶️ Auto Start (toggle)" \
    "🌐 Cambiar Dominio" \
    "💣 DDOS Test" \
    "🤖 Bot Admin" \
    "🎫 Bot Generador" \
    "🔑 Generador de Licencias" \
    "🔌 API Access" \
    "📈 HWID Quota Monitor" \
    "🖥 Monitor Live" \
    "📸 Network Snapshot" \
    "🗂 FileBrowser" \
    "🔍 CheckUser" \
    "↩ $(trx 'Volver al Menú Principal')")

case "$SEL" in
    1)  _run_herr "blocktorrent.sh" ;;
    2)  _run_herr "archivoonline.sh" ;;
    3)  _run_herr "speedtest.sh" ;;
    4)  _run_herr "detalles.sh" ;;
    5)  _run_herr "blockads.sh" ;;
    6)  _run_herr "rootpass.sh" ;;
    7)  _run_herr "scanner.sh" ;;
    8)  _run_herr "fail2ban.sh" ;;
    9)  _run_herr "auditoria.sh" ;;
    10) _run_herr "seguridad.sh" ;;
    11) _run_herr "firewall.sh" ;;
    12) _run_herr "openports.sh" ;;
    13) _run_herr "optimizar.sh" ;;
    14) _run_herr "reiniciar.sh" ;;
    15) _run_herr "network_traffic.sh" ;;
    16)
        # ── Toggle Auto Start ──
        FILE="/etc/profile.d/MoviVIP.sh"
        clear
        if [[ "${AUTO_START:-OFF}" == "OFF" ]]; then
            sed -i 's/AUTO_START=OFF/AUTO_START=ON/' "$CONFIG"
            cat > "$FILE" << 'EOF'
#!/bin/bash
if [[ $- == *i* ]]; then
    menu
fi
EOF
            chmod +x "$FILE"
            echo -e "${GREEN}✅ $(trx 'Auto inicio activado')${RESET}"
        else
            sed -i 's/AUTO_START=ON/AUTO_START=OFF/' "$CONFIG"
            rm -f "$FILE"
            echo -e "${GOLD}⚠️ $(trx 'Auto inicio desactivado')${RESET}"
        fi
        sleep 2
        exec bash "$BASE/herramientas/menu.sh"
        ;;
    17) _run_herr "change-domain.sh" ;;
    18) _run_herr "ddos.sh" ;;
    19) _run_proto "bot.sh" ;;
    20) _run_herr "setup-bot-generador.sh" ;;
    21) _run_herr "generador-licencias.sh" ;;
    22) _run_herr "instalar_apiaccess.sh" ;;
    23) _run_herr "hwid_quota_monitor.sh" ;;
    24) _run_herr "monitorlive.sh" ;;
    25) _run_herr "network_snapshot.sh" ;;
    26) _run_herr "filebrowser.sh" ;;
    27) _run_herr "checkuser.sh" ;;
    0|*) exec bash "$BASE/menu.sh" ;;
esac