#!/bin/bash

#=========================================================
#   MoviVIP Network — MENÚ DE HERRAMIENTAS
#   Panel central de gestión / utilidades del servidor.
#   Organizado por secciones profesionales:
#     🛡 Seguridad · ⚡ Sistema · 🌐 Red · 🤖 Bots · 📊 Monitoreo
#   Design System NEBULA + navegador nav_pick (2 columnas).
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
# Executores (evitan repetir el chequeo de existencia)
# $1 = script · $2 = menú destino al volver (sección)
# ────────────────────────────────────────────────────────
_back_to() {  # devuelve "menu_X" si es sección válida o el archivo
    case "$1" in
        sec)   echo "menu_seguridad" ;;
        sis)   echo "menu_sistema" ;;
        red)   echo "menu_red" ;;
        bots)  echo "menu_bots" ;;
        mon)   echo "menu_monitoreo" ;;
        *)     echo "menu.sh" ;;
    esac
}

_run_herr() {  # $1 = script · $2 = sección (sec/sis/red/bots/mon) para volver
    local script="$BASE/herramientas/$1"
    local back
    back=$(_back_to "${2:-}")
    clear
    if [[ -f "$script" ]]; then
        bash "$script"
    else
        echo -e "${RED}❌ $(trx 'No encontrado'): $1${RESET}"
        sleep 2
    fi
    if [[ "$back" == "menu.sh" ]]; then
        exec bash "$BASE/herramientas/menu.sh"
    else
        "$back"
    fi
}

_run_proto() {  # $1 = script dentro de protocolos/
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
# 🛡 SEGURIDAD
# ────────────────────────────────────────────────────────
menu_seguridad() {
    clear
    mv_header "$(trx '🛡 Seguridad del Servidor')" "$(trx 'Protección · Firewall · Anti-Intrusión')" "v6.2"
    movivip_contacts 2>/dev/null || true
    echo ""
    SEL=$(nav_pick "► $(trx 'Opción:'):" \
        "🛡 Fail2ban" \
        "🔍 Auditoría completa" \
        "🐛 Anti-Minero / Scan" \
        "🧱 Firewall" \
        "🧲 Block Torrent" \
        "🚫 Block Ads" \
        "🔓 Open Ports" \
        "🔑 Contraseña Root" \
        "🕵 Scanner host/dominio" \
        "↩ $(trx 'Volver a Herramientas')")
    case "$SEL" in
        1) _run_herr "fail2ban.sh" sec ;;
        2) _run_herr "auditoria.sh" sec ;;
        3) _run_herr "seguridad.sh" sec ;;
        4) _run_herr "firewall.sh" sec ;;
        5) _run_herr "blocktorrent.sh" sec ;;
        6) _run_herr "blockads.sh" sec ;;
        7) _run_herr "openports.sh" sec ;;
        8) _run_herr "rootpass.sh" sec ;;
        9) _run_herr "scanner.sh" sec ;;
        0|*) exec bash "$BASE/herramientas/menu.sh" ;;
    esac
}

# ────────────────────────────────────────────────────────
# ⚡ SISTEMA / PERFORMANCE
# ────────────────────────────────────────────────────────
menu_sistema() {
    clear
    mv_header "$(trx '⚡ Sistema y Optimización')" "$(trx 'Rendimiento · Servicios · Red')" "v6.2"
    movivip_contacts 2>/dev/null || true
    echo ""
    SEL=$(nav_pick "► $(trx 'Opción:'):" \
        "⚡ Optimizar VPS" \
        "🔄 Reiniciar Servicios" \
        "📊 Consumo de Red" \
        "ℹ️ Detalles VPS" \
        "🚀 Speedtest" \
        "▶️ Auto Start (toggle)" \
        "↩ $(trx 'Volver a Herramientas')")
    case "$SEL" in
        1) _run_herr "optimizar.sh" sis ;;
        2) _run_herr "reiniciar.sh" sis ;;
        3) _run_herr "network_traffic.sh" sis ;;
        4) _run_herr "detalles.sh" sis ;;
        5) _run_herr "speedtest.sh" sis ;;
        6)
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
        0|*) exec bash "$BASE/herramientas/menu.sh" ;;
    esac
}

# ────────────────────────────────────────────────────────
# 🌐 RED / DOMINIO
# ────────────────────────────────────────────────────────
menu_red() {
    clear
    mv_header "$(trx '🌐 Red y Dominio')" "$(trx 'Dominio · Túneles · Tráfico')" "v6.2"
    movivip_contacts 2>/dev/null || true
    echo ""
    SEL=$(nav_pick "► $(trx 'Opción:'):" \
        "🌐 Cambiar Dominio" \
        "📤 Archivo Online" \
        "💣 DDOS Test" \
        "↩ $(trx 'Volver a Herramientas')")
    case "$SEL" in
        1) _run_herr "change-domain.sh" red ;;
        2) _run_herr "archivoonline.sh" red ;;
        3) _run_herr "ddos.sh" red ;;
        0|*) exec bash "$BASE/herramientas/menu.sh" ;;
    esac
}

# ────────────────────────────────────────────────────────
# 🤖 BOTS / AUTOMATIZACIÓN
# ────────────────────────────────────────────────────────
menu_bots() {
    clear
    mv_header "$(trx '🤖 Bots y Automatización')" "$(trx 'Bot Admin · Generador · API')" "v6.2"
    movivip_contacts 2>/dev/null || true
    echo ""
    SEL=$(nav_pick "► $(trx 'Opción:'):" \
        "🤖 Bot Admin" \
        "🎫 Bot Generador" \
        "🔑 Generador de Licencias" \
        "🔌 API Access" \
        "📈 HWID Quota Monitor" \
        "↩ $(trx 'Volver a Herramientas')")
    case "$SEL" in
        1) _run_proto "bot.sh" ;;
        2) _run_herr "setup-bot-generador.sh" bots ;;
        3) _run_herr "generador-licencias.sh" bots ;;
        4) _run_herr "instalar_apiaccess.sh" bots ;;
        5) _run_herr "hwid_quota_monitor.sh" bots ;;
        0|*) exec bash "$BASE/herramientas/menu.sh" ;;
    esac
}

# ────────────────────────────────────────────────────────
# 📊 MONITOREO
# ────────────────────────────────────────────────────────
menu_monitoreo() {
    clear
    mv_header "$(trx '📊 Monitoreo')" "$(trx 'Estado en vivo · Tráfico · Archivos')" "v6.2"
    movivip_contacts 2>/dev/null || true
    echo ""
    SEL=$(nav_pick "► $(trx 'Opción:'):" \
        "🖥 Monitor Live" \
        "📸 Network Snapshot" \
        "🗂 FileBrowser" \
        "🔍 CheckUser" \
        "↩ $(trx 'Volver a Herramientas')")
    case "$SEL" in
        1) _run_herr "monitorlive.sh" mon ;;
        2) _run_herr "network_snapshot.sh" mon ;;
        3) _run_herr "filebrowser.sh" mon ;;
        4) _run_herr "checkuser.sh" mon ;;
        0|*) exec bash "$BASE/herramientas/menu.sh" ;;
    esac
}

# ────────────────────────────────────────────────────────
# MENÚ PRINCIPAL DE HERRAMIENTAS
# ────────────────────────────────────────────────────────
clear
mv_header "$(trx '🧰 Herramientas MoviVIP')" "$(trx 'Panel de utilidades y gestión del servidor')" "v6.2"
movivip_contacts 2>/dev/null || true
echo ""
SEL=$(nav_pick "► $(trx 'Seleccione una sección:'):" \
    "🛡 $(trx 'Seguridad')" \
    "⚡ $(trx 'Sistema / Optimización')" \
    "🌐 $(trx 'Red / Dominio')" \
    "🤖 $(trx 'Bots / Automatización')" \
    "📊 $(trx 'Monitoreo')" \
    "↩ $(trx 'Volver al Menú Principal')")

case "$SEL" in
    1) menu_seguridad ;;
    2) menu_sistema ;;
    3) menu_red ;;
    4) menu_bots ;;
    5) menu_monitoreo ;;
    0|*) exec bash "$BASE/menu.sh" ;;
esac
