#!/bin/bash

#=========================================================
#   MoviVIP Network — MENÚ DE HERRAMIENTAS
#   Panel central de gestión / utilidades del servidor.
#   Menú PLANO — todas las herramientas en 1 pantalla:
#     Block Torrent · Archivo Online · Speedtest ·
#     Detalles VPS · Block Ads · Root Pass · Scanner ·
#     Fail2ban · Auditoría · Firewall · OpenPorts ...
#   Design System NEBULA + navegador nav_pick.
#
#   v7.5 REMODEL (MoviVIP):
#     • 🔁 Reiniciar VPS y 💾 Formatear VPS movidos aquí
#       desde el Menú Principal (petición del usuario).
#     • Fix del prompt: mostraba "► Opción::" (doble ':').
#     • YELLOW añadido a la paleta local.
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
RESET="${MV_R:-\e[0m}"; RED="${MV_RED:-\e[1;91m}"; GREEN="${MV_GRN:-\e[1;92m}"; GOLD="${MV_GLD:-\e[1;93m}"
YELLOW="${MV_YLW:-\e[1;93m}"
BLUE="${MV_BLU:-\e[1;94m}"; CYAN="${MV_CYN:-\e[1;96m}"; WHITE="${MV_WHT:-\e[1;97m}"; GRAY="${MV_DIM:-\e[1;90m}"

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
# Marco premium: ═══ + logo 3D MOVIVIP + título + contactos + ═══
mv_brand_header "$(trx '🧰 Herramientas')" "$(trx 'Panel de utilidades y gestión del servidor')"
echo ""
SEL=$(nav_pick "► $(trx 'Opción:')" \
    "$(trx '🧲 Block Torrent')" \
    "$(trx '📤 Archivo Online')" \
    "🚀 Speedtest" \
    "$(trx 'ℹ️ Detalles VPS')" \
    "🚫 Block Ads" \
    "$(trx '🔑 Cambiar Contraseña Root')" \
    "$(trx '🕵 Scanner host/dominio')" \
    "🛡 Fail2ban" \
    "$(trx '🔍 Auditoría completa')" \
    "$(trx '🐛 Anti-Minero / Scan')" \
    "🧱 Firewall" \
    "🔓 Open Ports" \
    "$(trx '⚡ Optimizar VPS')" \
    "$(trx '🔄 Reiniciar Servicios')" \
    "$(trx '🔁 Reiniciar VPS')" \
    "$(trx '💾 Formatear VPS')" \
    "$(trx '📊 Consumo de Red')" \
    "$(trx '▶️ Auto Start (toggle)')" \
    "$(trx '🌐 Cambiar Dominio')" \
    "💣 DDOS Test" \
    "$(trx '🤖 Bot Admin')" \
    "$(trx '🎫 Bot Generador')" \
    "$(trx '🔑 Generador de Licencias')" \
    "🔌 API Access" \
    "$(trx '📈 HWID Quota Monitor')" \
    "$(trx '🖥 Monitor Live')" \
    "$(trx '📸 Network Snapshot')" \
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

    15)
        # ── 🔁 Reiniciar VPS (movido desde el Menú Principal) ──
        clear
        mv_panel_top "${REBOOT_TITLE:-REINICIAR VPS}"
        mv_prow_center "🔄 ${REBOOT_MSG:-Esto reiniciará el servidor ahora.}"
        mv_panel_bot
        echo ""
        printf " ► ${REBOOT_CONFIRM:-Confirmar reinicio (s/n): }"
        read -r CONF_REBOOT
        if [[ "$CONF_REBOOT" == "s" || "$CONF_REBOOT" == "S" ]]; then
            echo -e "${GREEN}✅ ${REBOOT_RESTARTING:-Reiniciando VPS en 3 segundos...}${RESET}"
            sleep 1
            echo -e "${YELLOW}   3...${RESET}"; sleep 1
            echo -e "${YELLOW}   2...${RESET}"; sleep 1
            echo -e "${YELLOW}   1...${RESET}"; sleep 1
            reboot
        else
            echo -e "${GOLD}✔ ${REBOOT_CANCELED:-Reinicio cancelado}${RESET}"
            sleep 2
        fi
        exec bash "$BASE/herramientas/menu.sh"
        ;;

    16)
        # ── 💾 Formatear / Reinstalar VPS (movido desde el Menú Principal) ──
        clear
        mv_panel_top "${FORMAT_TITLE:-FORMATEAR / REINSTALAR VPS}"
        mv_prow_center "💾 ${FORMAT_WARNING:-PELIGRO: Esto eliminará TODO del VPS:}"
        mv_prow_menu "   - ${FORMAT_LIST:-Todos los usuarios VPN}"
        mv_prow_menu "   - ${FORMAT_LIST2:-Todos los protocolos (Xray, Dropbear, BadVPN, etc)}"
        mv_prow_menu "   - ${FORMAT_LIST3:-Todas las configuraciones}"
        mv_prow_menu "   - ${FORMAT_REINSTALL_FROM_SCRATCH:-El sistema se reinstalará desde cero}"
        mv_panel_mid
        mv_prow_center "${FORMAT_REINSTALLING:-El VPS se reiniciará y ejecutará install.sh automáticamente.}"
        mv_panel_bot
        echo ""
        printf " ► ${FORMAT_CONFIRM:-Escribe 'CONFIRMAR' para formatear: } "
        read -r CONF_FORMAT
        if [[ "$CONF_FORMAT" != "CONFIRMAR" && "$CONF_FORMAT" != "CONFIRM" ]]; then
            echo -e "${GREEN}✔ ${FORMAT_CANCELED:-Formateo cancelado}${RESET}"
            sleep 2
            exec bash "$BASE/herramientas/menu.sh"
        fi
        echo ""
        printf " ${RED}► ${FORMAT_SECOND_CONFIRM:-Segunda confirmación (s/n): } ${RESET}"
        read -r CONF_FORMAT2
        if [[ "$CONF_FORMAT2" != "s" && "$CONF_FORMAT2" != "S" ]]; then
            echo -e "${GREEN}✔ ${FORMAT_CANCELED:-Formateo cancelado}${RESET}"
            sleep 2
            exec bash "$BASE/herramientas/menu.sh"
        fi
        echo ""
        echo -e "${CYAN}▶ ${FORMAT_CLEANING:-Limpiando sistema...}${RESET}"
        # Limpiar todo
        for svc in xray v2ray dropbear dropbear_custom badvpn-udpgw-7300 badvpn-udpgw-7200 udp-custom zivpn slowdns squid haproxy; do
            systemctl stop "$svc" 2>/dev/null
            systemctl disable "$svc" 2>/dev/null
        done
        killall -9 xray v2ray dropbear badvpn-udpgw 2>/dev/null || true
        rm -rf /etc/movivip /etc/xray /usr/local/etc/xray /etc/v2ray
        rm -f /usr/bin/xray /usr/local/bin/xray /usr/bin/dropbear /usr/sbin/dropbear
        rm -f /usr/bin/badvpn-udpgw /usr/bin/udp
        rm -rf /usr/local/SlowDNS /tmp/dnstt* /etc/slowdns /etc/zivpn
        rm -f /etc/systemd/system/xray*.service /etc/systemd/system/v2ray*.service
        rm -f /etc/systemd/system/dropbear*.service /etc/systemd/system/badvpn*.service
        rm -f /etc/systemd/system/udpcustom*.service /etc/systemd/system/slowdns*.service
        rm -f /etc/systemd/system/zivpn*.service /etc/systemd/system/movivip*.service
        rm -f /etc/profile.d/MoviVIP-banner.sh /etc/issue.net
        crontab -r 2>/dev/null || true
        systemctl daemon-reload 2>/dev/null
        # Reset iptables - abrir SSH SIEMPRE
        iptables -F 2>/dev/null; iptables -X 2>/dev/null
        iptables -t nat -F 2>/dev/null; iptables -t nat -X 2>/dev/null
        iptables -t mangle -F 2>/dev/null; iptables -t mangle -X 2>/dev/null
        iptables -P INPUT ACCEPT 2>/dev/null
        iptables -P FORWARD ACCEPT 2>/dev/null
        iptables -P OUTPUT ACCEPT 2>/dev/null
        iptables -I INPUT 1 -p tcp --dport 22 -j ACCEPT
        iptables -I INPUT 2 -p tcp --dport 54321 -j ACCEPT
        iptables -I INPUT 3 -p tcp --dport 8012 -j ACCEPT
        iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
        echo -e "${GREEN}✅ ${FORMAT_REBOOT_CLEAN:-Sistema limpiado. Reiniciando para instalación limpia...}${RESET}"
        sleep 2
        reboot
        ;;

    17) _run_herr "network_traffic.sh" ;;
    18)
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
    19) _run_herr "change-domain.sh" ;;
    20) _run_herr "ddos.sh" ;;
    21) _run_proto "bot.sh" ;;
    22) _run_herr "setup-bot-generador.sh" ;;
    23) _run_herr "generador-licencias.sh" ;;
    24) _run_herr "instalar_apiaccess.sh" ;;
    25) _run_herr "hwid_quota_monitor.sh" ;;
    26) _run_herr "monitorlive.sh" ;;
    27) _run_herr "network_snapshot.sh" ;;
    28) _run_herr "filebrowser.sh" ;;
    29) _run_herr "checkuser.sh" ;;
    0|30) exec bash "$BASE/menu.sh" ;;
    *) exec bash "$BASE/menu.sh" ;;
esac
