#!/bin/bash

# ═══════════════════════════════════════════════════════════════
#   MoviVIP Network — 3X-UI PANEL (vaxilu/x-ui)
#   Panel web para gestión de XRay/VLESS/VMess/Trojan
#   Integrado con Design System NEBULA v4.0 + haproxy (IP + cert autofirmado)
# ═══════════════════════════════════════════════════════════════

BASE="/etc/movivip"
CONFIG="$BASE/config.conf"
[[ -f "$CONFIG" ]] && source "$CONFIG"

# ═══════════════════════════════════════════════════════════════
# CARGA DESIGN SYSTEM NEBULA v4.0
# ═══════════════════════════════════════════════════════════════

# i18n shim (auto) — carga idioma + trx()
if ! declare -F trx >/dev/null 2>&1; then trx() { printf '%s' "$1"; }; fi
source "${BASE}/languages/lang.sh" 2>/dev/null || true
load_language "$(get_current_language)" 2>/dev/null || true
source "${BASE}/lib/ui.sh" 2>/dev/null || true
source "${BASE}/lib/nav.sh" 2>/dev/null || true

# Fallback colors si ui.sh no carga
RESET="${MV_R:-\e[0m}"
CYAN="${MV_CYN:-\e[1;96m}"
GREEN="${MV_GRN:-\e[1;92m}"
YELLOW="${MV_YLW:-\e[1;93m}"
RED="${MV_RED:-\e[1;91m}"
BLUE="${MV_BLU:-\e[1;94m}"
MAGENTA="${MV_MAG:-\e[1;95m}"
WHITE="${MV_WHT:-\e[1;97m}"
GRAY="${MV_DIM:-\e[1;90m}"
GOLD="${MV_GLD:-\e[1;93m}"

# ═══════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════

xui_status() {
    systemctl is-active x-ui >/dev/null 2>&1 && echo -e "${GREEN}● ${trx:-ACTIVO}" || echo -e "${RED}● ${trx:-INACTIVO}"
}

xui_port() {
    local port=$(/usr/local/x-ui/x-ui setting -show 2>/dev/null | grep -oP 'port\s*=\s*\K\d+' | head -1)
    [[ -z "$port" ]] && port="54322"
    echo "$port"
}

xui_ip() {
    curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}'
}

# Open firewall port for x-ui panel
xui_open_firewall() {
    local port="${1:-54322}"
    iptables -I INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null
    iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
}
# ═══════════════════════════════════════════════════════════════
# GATE DE PLAN — 3X-UI SOLO PREMIUM / VITALICIO / ADMIN
# Valida EN VIVO contra Firebase (firebase-plan.sh) con fallback a
# licencia.conf. Bloquea instalación/actualización/gestión si el
# plan no está autorizado.
# ═══════════════════════════════════════════════════════════════

XUI_PLAN_OK=()
xui_plan_autorizado() {
    local FP_VALID=0 FP_PLAN="" FP_TIPO="" plan tipo
    if [[ -f "$BASE/lib/firebase-plan.sh" ]]; then
        source "$BASE/lib/firebase-plan.sh"
        firebase_plan "" 2>/dev/null
    fi
    if [[ -z "$FP_PLAN" && -f "$BASE/licencia.conf" ]]; then
        source "$BASE/licencia.conf" 2>/dev/null
        FP_PLAN="${PLAN:-}"
        FP_TIPO="${TIPO:-}"
    fi
    plan=$(echo "${FP_PLAN:-}" | tr '[:upper:]' '[:lower:]')
    tipo=$(echo "${FP_TIPO:-}" | tr '[:upper:]' '[:lower:]')
    case "$plan" in
        premium|vitalicio|admin|super|empresarial) XUI_PLAN_OK=(1 "$FP_PLAN" "$FP_TIPO"); return 0 ;;
    esac
    case "$tipo" in
        admin|superadmin|super|empresarial) XUI_PLAN_OK=(1 "$FP_PLAN" "$FP_TIPO"); return 0 ;;
    esac
    XUI_PLAN_OK=(0 "${FP_PLAN:-}" "${FP_TIPO:-}")
    return 1
}

xui_gate() {
    xui_plan_autorizado
    if [[ "${XUI_PLAN_OK[0]}" != "1" ]]; then
        echo ""
        echo -e "${RED}════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${RED}      🔒 ACCESO DENEGADO — 3X-UI PANEL${RESET}"
        echo -e "${RED}════════════════════════════════════════════════════════╝${RESET}"
        echo -e "${WHITE}   El panel 3X-UI es exclusivo para planes:${RESET}"
        echo -e "${GREEN}      ☆ PREMIUM${RESET}"
        echo -e "${GREEN}      ☆ VITALICIO${RESET}"
        echo -e "${GREEN}      ☆ ADMIN / SUPERADMIN${RESET}"
        echo ""
        echo -e "${GRAY}   Licencia detectada: ${YELLOW}${XUI_PLAN_OK[1]:-desconocido}${RESET}${GRAY} / ${CYAN}${XUI_PLAN_OK[2]:-desconocido}${RESET}"
        echo -e "${YELLOW}   💡 Contacta al administrador para mejorar tu plan.${RESET}"
        echo ""
        sleep 4
        return 1
    fi
    return 0
}

# ═══════════════════════════════════════════════════════════════
# HAPROXY CON CERTIFICADO AUTOFIRMADO (POR IP - SIN DNS)
# ═══════════════════════════════════════════════════════════════

xui_haproxy_setup_selfsigned() {
    local ip=$(xui_ip)
    local panel_port=$(xui_port)
    local haproxy_port=54323  # Puerto HTTPS externo para el panel
    local cert_dir="/etc/haproxy/certs"
    local cert_file="$cert_dir/xui-selfsigned.pem"
    local CFG="/etc/haproxy/haproxy.cfg"
    
    echo -e "${CYAN}$(trx 'Configurando haproxy con certificado autofirmado para IP'): $ip${RESET}"
    
    # Crear directorio de certificados
    mkdir -p "$cert_dir"
    
    # Generar certificado autofirmado si no existe
    if [[ ! -f "$cert_file" ]]; then
        echo -e "${CYAN}$(trx 'Generando certificado autofirmado...')${RESET}"
        openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
            -keyout "$cert_dir/key.pem" -out "$cert_dir/cert.pem" \
            -subj "/CN=$ip" -addext "subjectAltName=IP:$ip" \
            2>/dev/null
        
        # Combinar cert + key en un solo archivo para haproxy
        cat "$cert_dir/cert.pem" "$cert_dir/key.pem" > "$cert_file"
        chmod 600 "$cert_file"
        echo -e "${GREEN}✅ $(trx 'Certificado autofirmado generado para IP'): $ip${RESET}"
    fi
    
    # Eliminar bloque 3x-ui previo y cualquier include roto de haproxy-3xui.cfg
    python3 - "$CFG" <<'PYEOF'
import sys, re
p = sys.argv[1]
with open(p, 'r', encoding='utf-8', errors='replace') as f:
    txt = f.read()
# quitar includes obsoletos
txt = re.sub(r'^\s*# 3x-ui Panel config[^\n]*\ninclude /etc/haproxy/haproxy-3xui\.cfg[^\n]*\n?', '', txt, flags=re.M)
txt = re.sub(r'^\s*include /etc/haproxy/haproxy-3xui\.cfg[^\n]*\n?', '', txt, flags=re.M)
# quitar bloques xui_frontend / xui_backend
txt = re.sub(r'\n?frontend xui_frontend\n(?:    [^\n]*\n)+', '\n', txt)
txt = re.sub(r'\n?backend xui_backend\n(?:    [^\n]*\n)+', '\n', txt)
with open(p, 'w', encoding='utf-8') as f:
    f.write(txt)
PYEOF
    
    # Incrustar bloque directo al final (haproxy 2.4 NO soporta include en esta posición)
    cat >> "$CFG" <<EOF

# 3x-ui Panel (vaxilu/x-ui) - HTTPS con certificado autofirmado (por IP)
frontend xui_frontend
    mode http
    bind *:54323 ssl crt $cert_file
    http-request set-header X-Forwarded-Proto https
    http-request set-header X-Forwarded-For %[src]
    default_backend xui_backend

backend xui_backend
    mode http
    server xui_local 127.0.0.1:$(xui_port) check inter 2000 rise 2 fall 3
EOF
    
    # Limpiar archivo intermedio obsoleto
    rm -f /etc/haproxy/haproxy-3xui.cfg
    
    # Abrir puerto en firewall
    iptables -I INPUT -p tcp --dport 54323 -j ACCEPT 2>/dev/null
    iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
    
    # Validar y recargar haproxy
    if haproxy -c -f "$CFG" 2>/dev/null; then
        systemctl reload haproxy 2>/dev/null
        echo -e "${GREEN}✅ $(trx 'haproxy configurado con certificado autofirmado')${RESET}"
        echo -e "${WHITE}   $(trx 'Acceso al panel'): https://$(xui_ip):54323${RESET}"
        echo -e "${YELLOW}⚠️  $(trx 'El navegador advertirá por certificado autofirmado. Clic en Avanzado → Proceder.')${RESET}"
    else
        echo -e "${RED}❌ $(trx 'Error de configuración haproxy — revise /var/log/haproxy.log')${RESET}"
    fi
    return 0
}

# ═══════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════

xui_status() {
    systemctl is-active x-ui >/dev/null 2>&1 && echo -e "${GREEN}● ${trx:-ACTIVO}" || echo -e "${RED}● ${trx:-INACTIVO}"
}

xui_port() {
    local port=$(/usr/local/x-ui/x-ui setting -show 2>/dev/null | grep -oP 'port\s*=\s*\K\d+' | head -1)
    [[ -z "$port" ]] && port="54322"
    echo "$port"
}

xui_ip() {
    curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}'
}

# Open firewall port for x-ui panel
xui_open_firewall() {
    local port="${1:-54322}"
    iptables -I INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null
    iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
}

# ═══════════════════════════════════════════════════════════════
# MENU PRINCIPAL 3X-UI (usa design system NEBULA)
# ═══════════════════════════════════════════════════════════════

manage_xui() {
    while true; do
        clear

        # ── HEADER 3D MOVIVIP ──
        if declare -F mv_brand_header >/dev/null 2>&1; then
            mv_brand_header "$(trx '🌐 3X-UI Panel')" "$(trx 'Panel web para gestión de XRay/VLESS/VMess/Trojan')"
        elif declare -F movivip_sub_header >/dev/null 2>&1; then
            movivip_sub_header "$(trx '🌐 3X-UI Panel')"
        else
            echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
            echo -e "${WHITE}       🌐 ${trx:-3X-UI Panel}${RESET}"
            echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
        fi
        echo ""

        # ── PANEL DE ESTADO ──
        local ip=$(xui_ip)
        local panel_port=$(xui_port)
        
        if declare -F mv_panel_top >/dev/null 2>&1; then
            mv_panel_top "$(trx '📊 Estado del Servicio')"
            mv_prow "$(trx 'Estado')" "$(xui_status)"
            mv_prow "$(trx 'Puerto Panel')" "$panel_port (interno)"
            mv_prow "$(trx 'Acceso HTTPS')" "https://$ip:54323"
            mv_prow "$(trx 'IP Pública')" "$ip"
            mv_prow "$(trx 'Usuario')" "admin"
            mv_prow "$(trx 'Contraseña')" "admin"
            mv_panel_bot
        else
            echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
            echo -e "${WHITE} Estado: $(xui_status)"
            echo -e "${WHITE} Puerto Panel: $panel_port (interno)"
            echo -e "${WHITE} Acceso HTTPS: https://$ip:54323"
            echo -e "${WHITE} IP Pública: $ip"
            echo -e "${WHITE} Usuario: admin | Pass: admin"
            echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
        fi
        echo ""

        # ── MENÚ DE OPCIONES ──
        if declare -F mv_panel_top >/dev/null 2>&1; then
            mv_panel_top "$(trx '⚙️ Gestión')"
            mv_prow_menu "[1]  $(trx 'Instalar 3x-ui (con SSL IP auto)')"
            mv_prow_menu "[2]  $(trx 'Actualizar 3x-ui')"
            mv_prow_menu "[3]  $(trx 'Desinstalar 3x-ui')"
            mv_panel_mid "$(trx 'Control del Servicio')"
            mv_prow_menu "[4]  $(trx 'Iniciar')"
            mv_prow_menu "[5]  $(trx 'Detener')"
            mv_prow_menu "[6]  $(trx 'Reiniciar')"
            mv_panel_mid "$(trx 'SSL / Haproxy (por IP)')"
            mv_prow_menu "[7]  $(trx 'Configurar SSL (haproxy + cert autofirmado IP)')"
            mv_panel_mid "$(trx 'Información y Mantenimiento')"
            mv_prow_menu "[8]  $(trx 'Ver estado (systemctl)')"
            mv_prow_menu "[9]  $(trx 'Ver logs (journalctl -f)')"
            mv_prow_menu "[10] $(trx 'Resetear usuario/contraseña a admin')"
            mv_prow_menu "[11] $(trx 'Cambiar puerto del panel')"
            mv_panel_mid "$(trx 'Navegación')"
            mv_prow_menu "[0]  $(trx 'Volver al Menú de Protocolos')"
            mv_panel_bot
        else
            echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
            echo -e "${YELLOW}[1]${WHITE}  $(trx 'Instalar 3x-ui (con SSL IP auto)')"
            echo -e "${YELLOW}[2]${WHITE}  $(trx 'Actualizar 3x-ui')"
            echo -e "${YELLOW}[3]${WHITE}  $(trx 'Desinstalar 3x-ui')"
            echo -e "${YELLOW}[4]${WHITE}  $(trx 'Iniciar')"
            echo -e "${YELLOW}[5]${WHITE}  $(trx 'Detener')"
            echo -e "${YELLOW}[6]${WHITE}  $(trx 'Reiniciar')"
            echo -e "${YELLOW}[7]${WHITE}  $(trx 'Configurar SSL (haproxy + cert autofirmado IP)')"
            echo -e "${YELLOW}[8]${WHITE}  $(trx 'Ver estado (systemctl)')"
            echo -e "${YELLOW}[9]${WHITE}  $(trx 'Ver logs (journalctl -f)')"
            echo -e "${YELLOW}[10]${WHITE} $(trx 'Resetear usuario/contraseña a admin')"
            echo -e "${YELLOW}[11]${WHITE} $(trx 'Cambiar puerto del panel')"
            echo -e "${YELLOW}[0]${WHITE}  $(trx 'Volver al Menú de Protocolos')"
            echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
        fi
        echo ""

        # ── SELECCIÓN ──
        if declare -F nav_pick >/dev/null 2>&1; then
            SEL=$(nav_pick "► $(trx 'Opción'):" \
                "$(trx 'Instalar 3x-ui (con SSL IP auto)')" \
                "$(trx 'Actualizar 3x-ui')" \
                "$(trx 'Desinstalar 3x-ui')" \
                "$(trx 'Iniciar')" \
                "$(trx 'Detener')" \
                "$(trx 'Reiniciar')" \
                "$(trx 'Configurar SSL (haproxy + cert autofirmado IP)')" \
                "$(trx 'Ver estado')" \
                "$(trx 'Ver logs')" \
                "$(trx 'Resetear admin')" \
                "$(trx 'Cambiar puerto')" \
                "$(trx 'Volver')")
        else
            read -rp "$(echo -e "${CYAN}► $(trx 'Opción'): ${RESET}")" SEL
        fi

        case "$SEL" in
            1) install_xui ;;
            2) update_xui ;;
            3) uninstall_xui ;;
            4) systemctl start x-ui >/dev/null 2>&1; echo -e "${GREEN}✅ $(trx 'Iniciado')${RESET}"; sleep 1 ;;
            5) systemctl stop x-ui >/dev/null 2>&1; echo -e "${YELLOW}⏹️ $(trx 'Detenido')${RESET}"; sleep 1 ;;
            6) systemctl restart x-ui >/dev/null 2>&1; echo -e "${GREEN}🔄 $(trx 'Reiniciado')${RESET}"; sleep 1 ;;
            7) xui_haproxy_setup_selfsigned; read -rp "$(echo -e "${CYAN}$(trx 'Presiona Enter para continuar...')")" ;;
            8) systemctl status x-ui --no-pager; read -rp "$(echo -e "${CYAN}$(trx 'Presiona Enter para continuar...')")" ;;
            9) journalctl -u x-ui -e --no-pager -f ;;
            10) /usr/local/x-ui/x-ui setting -username admin -password admin 2>/dev/null; systemctl restart x-ui >/dev/null 2>&1; echo -e "${GREEN}✅ $(trx 'Usuario/contraseña reseteado a admin')${RESET}"; sleep 1 ;;
            11) 
                read -rp "$(echo -e "${CYAN}$(trx 'Nuevo puerto [1-65535]'): ${RESET}")" p
                if [[ "$p" =~ ^[0-9]+$ ]] && (( p >= 1 && p <= 65535 )); then
                    /usr/local/x-ui/x-ui setting -port "$p" 2>/dev/null
                    xui_open_firewall "$p"
                    systemctl restart x-ui >/dev/null 2>&1
                    # Reconfigurar haproxy con nuevo puerto
                    xui_haproxy_setup_selfsigned
                    echo -e "${GREEN}✅ $(trx 'Puerto cambiado a'): $p${RESET}"
                else
                    echo -e "${RED}❌ $(trx 'Puerto inválido')${RESET}"
                fi
                sleep 1
                ;;
            0|*) return ;;
        esac
    done
}

# ═══════════════════════════════════════════════════════════════
# ACCIONES
# ═══════════════════════════════════════════════════════════════

install_xui() {
    local verbose="${1:-1}"
    xui_gate || return 1
    xui_gate || return 1
    xui_gate || return 1
    [[ "$verbose" -eq 1 ]] && echo -e "${CYAN}$(trx 'Instalando 3x-ui panel...')${RESET}"
    bash <(curl -Ls https://raw.githubusercontent.com/vaxilu/x-ui/master/install.sh)
    if [[ $? -eq 0 ]]; then
        systemctl enable x-ui >/dev/null 2>&1
        systemctl start x-ui >/dev/null 2>&1
        sleep 2
        xui_open_firewall 54322
        [[ "$verbose" -eq 1 ]] && echo -e "${GREEN}✅ $(trx '3x-ui instalado e iniciado')${RESET}"
        [[ "$verbose" -eq 1 ]] && echo -e "${WHITE}   $(trx 'Panel interno'): http://127.0.0.1:54322${RESET}"
        [[ "$verbose" -eq 1 ]] && echo -e "${WHITE}   $(trx 'Usuario'): admin  |  $(trx 'Pass'): admin${RESET}"
        [[ "$verbose" -eq 1 ]] && echo -e "${YELLOW}💡 $(trx 'Ejecuta la opción 7 para configurar SSL automático por IP')${RESET}"
    else
        [[ "$verbose" -eq 1 ]] && echo -e "${RED}❌ $(trx 'Error instalando 3x-ui')${RESET}"
    fi
}

update_xui() {
    local verbose="${1:-1}"
    xui_gate || return 1
    xui_gate || return 1
    xui_gate || return 1
    [[ "$verbose" -eq 1 ]] && echo -e "${YELLOW}⚠️ $(trx 'Se reinstalará la última versión (datos se conservan)')${RESET}"
    [[ "$verbose" -eq 1 ]] && read -rp "$(echo -e "${CYAN}$(trx 'Continuar? [y/N]'): ${RESET}")" yn
    [[ "$yn" =~ ^[Yy]$ ]] || return
    bash <(curl -Ls https://raw.githubusercontent.com/vaxilu/x-ui/master/install.sh)
    systemctl restart x-ui >/dev/null 2>&1
    [[ "$verbose" -eq 1 ]] && echo -e "${GREEN}✅ $(trx '3x-ui actualizado')${RESET}"
}

uninstall_xui() {
    local verbose="${1:-1}"
    xui_gate || return 1
    xui_gate || return 1
    xui_gate || return 1
    [[ "$verbose" -eq 1 ]] && echo -e "${YELLOW}⚠️ $(trx 'Esto ELIMINARÁ 3x-ui y XRay.')${RESET}"
    [[ "$verbose" -eq 1 ]] && read -rp "$(echo -e "${CYAN}$(trx 'Continuar? [y/N]'): ${RESET}")" yn
    [[ "$yn" =~ ^[Yy]$ ]] || return
    systemctl stop x-ui >/dev/null 2>&1
    systemctl disable x-ui >/dev/null 2>&1
    rm -f /etc/systemd/system/x-ui.service
    systemctl daemon-reload
    rm -rf /etc/x-ui /usr/local/x-ui
    # Remove haproxy config (bloque incrustado + include obsoleto)
    rm -f /etc/haproxy/haproxy-3xui.cfg
    python3 - /etc/haproxy/haproxy.cfg <<'PYEOF'
import sys, re
p = sys.argv[1]
with open(p, 'r', encoding='utf-8', errors='replace') as f:
    txt = f.read()
txt = re.sub(r'^\s*# 3x-ui Panel config[^\n]*\ninclude /etc/haproxy/haproxy-3xui\.cfg[^\n]*\n?', '', txt, flags=re.M)
txt = re.sub(r'^\s*include /etc/haproxy/haproxy-3xui\.cfg[^\n]*\n?', '', txt, flags=re.M)
txt = re.sub(r'\n?frontend xui_frontend\n(?:    [^\n]*\n)+', '\n', txt)
txt = re.sub(r'\n?backend xui_backend\n(?:    [^\n]*\n)+', '\n', txt)
with open(p, 'w', encoding='utf-8') as f:
    f.write(txt)
PYEOF
    haproxy -c -f /etc/haproxy/haproxy.cfg 2>/dev/null && systemctl reload haproxy 2>/dev/null
    [[ "$verbose" -eq 1 ]] && echo -e "${GREEN}✅ $(trx '3x-ui desinstalado')${RESET}"
}

# ═══════════════════════════════════════════════════════════════
# ENTRY POINT
# ═══════════════════════════════════════════════════════════════

case "${1:-}" in
    install) install_xui ;;
    update) update_xui ;;
    uninstall) uninstall_xui ;;
    start) systemctl start x-ui; echo -e "${GREEN}✅ $(trx 'Iniciado')${RESET}" ;;
    stop) systemctl stop x-ui; echo -e "${YELLOW}⏹️ $(trx 'Detenido')${RESET}" ;;
    restart) systemctl restart x-ui; echo -e "${GREEN}🔄 $(trx 'Reiniciado')${RESET}" ;;
    status) systemctl status x-ui --no-pager ;;
    log) journalctl -u x-ui -e --no-pager -f ;;
    haproxy) xui_haproxy_setup_selfsigned ;;
    *) xui_gate || exit 1; manage_xui ;;
esac