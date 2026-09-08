#!/bin/bash

# ── i18n shim (auto) ───────────────────────────────
if ! declare -F trx >/dev/null 2>&1; then trx() { printf '%s' "$1"; }; fi
# ─────────────────────────────────────────────────────────

#==================================================
# MoviVIP Network Premium
# Shadowsocks Manager v1 (estilo MoviVIP)
# Proxy SOCKS5 cifrado (shadowsocks-libev)
#
# • Paquete oficial apt: shadowsocks-libev
# • Cifrado aes-256-gcm — puerto 8388 por defecto
# • URL ss:// lista para compartir
#==================================================

BASE="/etc/movivip"
CONFIG="$BASE/config.conf"

[[ -f "$CONFIG" ]] || {
    echo "❌ No existe $CONFIG"
    exit 1
}

source "$CONFIG"

# Cargar idioma
if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)"
fi

# Sistema de animación/progreso
[[ -f "$BASE/lib/anim.sh" ]] && source "$BASE/lib/anim.sh"

CYAN="\e[1;96m"
GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
WHITE="\e[1;97m"
RESET="\e[0m"

DIR="/etc/shadowsocks-libev"
SS_PORT="${SS_PORT:-8388}"
SS_PASSWORD="${SS_PASSWORD:-}"
SS_METHOD="aes-256-gcm"
CONF="$DIR/$SS_PORT.json"

STATUS=""

#==================================================
# Instalar paquete
#==================================================

install_dependencies(){

    anim_step "$(trx 'Instalando Shadowsocks-libev')"
    anim_run "apt update" apt update -y
    anim_run "$(trx 'Instalar shadowsocks-libev')" apt install -y shadowsocks-libev

    [[ -d "$DIR" ]] || mkdir -p "$DIR"

    if ! command -v ss-server >/dev/null 2>&1; then
        echo "$(trx '❌ No se pudo instalar shadowsocks-libev.')"
        return 1
    fi
    return 0
}

#==================================================
# Crear configuración
#==================================================

create_config(){

    [[ -n "$SS_PASSWORD" ]] || SS_PASSWORD=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9')

    cat > "$CONF" <<EOFCONF
{
    "server": "0.0.0.0",
    "server_port": $SS_PORT,
    "password": "$SS_PASSWORD",
    "method": "$SS_METHOD",
    "mode": "tcp_and_udp",
    "fast_open": true
}
EOFCONF

    # DynamicUser en el unit template no puede leer 600 root -> 644
    chmod 644 "$CONF"

    echo "$(trx '✅ Configuración creada.')"
}

#==================================================
# Crear servicio (instancia template)
#==================================================

create_service(){

    systemctl daemon-reload
    systemctl enable "shadowsocks-libev-server@$SS_PORT" >/dev/null 2>&1

    echo "$(trx '✅ Servicio habilitado (shadowsocks-libev-server@8388).')"
}

#==================================================
# Abrir puertos
#==================================================

open_ports(){

    echo "$(trx '🛡 Abriendo puertos...')"

    iptables -C INPUT -p tcp --dport "$SS_PORT" -j ACCEPT 2>/dev/null \
        || iptables -A INPUT -p tcp --dport "$SS_PORT" -j ACCEPT
    iptables -C INPUT -p udp --dport "$SS_PORT" -j ACCEPT 2>/dev/null \
        || iptables -A INPUT -p udp --dport "$SS_PORT" -j ACCEPT

    if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
        ufw allow "$SS_PORT"/tcp >/dev/null 2>&1
        ufw allow "$SS_PORT"/udp >/dev/null 2>&1
    fi

    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4 2>/dev/null

}

#==================================================
# Test funcional
#==================================================

test_shadowsocks(){

    echo ""
    echo "$(trx '🧪 Verificando Shadowsocks...')"

    if systemctl is-active --quiet "shadowsocks-libev-server@$SS_PORT" && \
       ss -ltnp 2>/dev/null | grep -qE ":$SS_PORT "; then
        echo "$(trx '✅ Shadowsocks activo y escuchando.')"
        return 0
    fi

    if systemctl is-active --quiet "shadowsocks-libev-server@$SS_PORT"; then
        echo "$(trx '✅ Servicio activo.')"
        return 0
    fi

    echo "$(trx '⚠️  El servicio no está activo.')"
    echo "$(trx '    Revisa: journalctl -u shadowsocks-libev-server@8388 -n 20 --no-pager')"
    return 1
}

#==================================================
# Instalar Shadowsocks
#==================================================

install_shadowsocks(){

    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}        🐋 INSTALAR SHADOWSOCKS${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    anim_init 5
    anim_step "$(trx 'Instalando dependencias')"
    install_dependencies || return

    # Evitar conflicto con el servicio global legacy (usa /etc/shadowsocks-libev/config.json)
    systemctl stop shadowsocks-libev.service 2>/dev/null
    systemctl disable shadowsocks-libev.service 2>/dev/null
    rm -f "$DIR/config.json"

    anim_step "$(trx 'Configurando Shadowsocks')"
    create_config

    create_service

    anim_step "$(trx 'Abriendo puertos')"
    open_ports

    echo ""
    anim_step "$(trx 'Iniciando servicios')"
    anim_run "daemon-reload" systemctl daemon-reload

    systemctl enable "shadowsocks-libev-server@$SS_PORT" >/dev/null 2>&1

    svc_restart_anim "shadowsocks-libev-server@$SS_PORT" "$(trx 'Arrancando Shadowsocks')"

    if ! systemctl is-active --quiet "shadowsocks-libev-server@$SS_PORT"; then
        echo "$(trx '❌ Shadowsocks no pudo iniciar.')"
        journalctl -u "shadowsocks-libev-server@$SS_PORT" -n 20 --no-pager
        return 1
    fi

    test_shadowsocks

    sleep 3

    if systemctl is-active --quiet "shadowsocks-libev-server@$SS_PORT"; then

        sed -i '/^SHADOWSOCKS=/d' "$CONFIG"
        echo "SHADOWSOCKS=ON" >> "$CONFIG"
        sed -i '/^SS_PORT=/d' "$CONFIG"
        echo "SS_PORT=$SS_PORT" >> "$CONFIG"
        sed -i '/^SS_PASSWORD=/d' "$CONFIG"
        echo "SS_PASSWORD=$SS_PASSWORD" >> "$CONFIG"

        source "$CONFIG"

        VPS_IP=$(hostname -I | awk '{print $1}')
        SS_URL="ss://$(printf '%s' "$SS_METHOD:$SS_PASSWORD@$VPS_IP:$SS_PORT" | base64 -w0)#MoviVIP"

        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "$(trx '      ✅ SHADOWSOCKS INSTALADO')"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "🌍 IP        : $VPS_IP"
        echo "🚀 Puerto    : $SS_PORT"
        echo "🔑 Clave     : $SS_PASSWORD"
        echo "🔐 Método    : $SS_METHOD"
        echo ""
        echo "$(trx '  📱 URL PARA COMPARTIR:')"
        echo "   $SS_URL"
        echo ""
        echo "$(trx '  Importa la URL en cualquier app')"
        echo "$(trx '  Shadowsocks (ss://).')"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

    else

        echo ""
        echo "$(trx '❌ Error iniciando Shadowsocks')"
        echo ""
        systemctl status "shadowsocks-libev-server@$SS_PORT" --no-pager

    fi

    sleep 4
}

#==================================================
# Eliminar Shadowsocks
#==================================================

remove_shadowsocks(){

    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}        🗑 ELIMINAR SHADOWSOCKS${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    read -rp "$(trx '¿Eliminar Shadowsocks? (s/n): ')" R
    [[ ! "$R" =~ ^[Ss]$ ]] && return

    anim_step "$(trx 'Desinstalando Shadowsocks')"
    anim_run "$(trx 'Detener y deshabilitar')" bash -c "systemctl stop 'shadowsocks-libev-server@$SS_PORT' 2>/dev/null; systemctl disable 'shadowsocks-libev-server@$SS_PORT' 2>/dev/null"
    anim_run "$(trx 'Eliminar configuración')" rm -f "$CONF"
    anim_run "daemon-reload" systemctl daemon-reload

    iptables -D INPUT -p tcp --dport "$SS_PORT" -j ACCEPT 2>/dev/null
    iptables -D INPUT -p udp --dport "$SS_PORT" -j ACCEPT 2>/dev/null

    sed -i '/^SHADOWSOCKS=/d' "$CONFIG"
    echo "SHADOWSOCKS=OFF" >> "$CONFIG"

    source "$CONFIG"

    echo ""
    echo "$(trx '✅ Shadowsocks eliminado.')"
    sleep 3
}

#==================================================
# Reconfigurar (nueva clave)
#==================================================

reconfig_shadowsocks(){

    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}      🔄 NUEVA CLAVE SHADOWSOCKS${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    read -rp "$(trx 'Nueva clave (Enter = aleatoria): ')" NPASS
    [[ -z "$NPASS" ]] && NPASS=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9')

    SS_PASSWORD="$NPASS"
    create_config

    systemctl restart "shadowsocks-libev-server@$SS_PORT" 2>/dev/null

    sed -i '/^SS_PASSWORD=/d' "$CONFIG"
    echo "SS_PASSWORD=$SS_PASSWORD" >> "$CONFIG"

    echo ""
    echo "$(trx '✅ Clave actualizada:') $SS_PASSWORD"
    sleep 3
}

#==================================================
# Reiniciar servicio
#==================================================

restart_shadowsocks(){

    clear
    svc_restart_anim "shadowsocks-libev-server@$SS_PORT" "$(trx 'Reiniciando Shadowsocks')"
    sleep 2

    if systemctl is-active --quiet "shadowsocks-libev-server@$SS_PORT"; then
        echo ""
        echo "$(trx '✅ Servicio activo.')"
        test_shadowsocks
    else
        echo ""
        echo "$(trx '❌ Error al reiniciar.')"
    fi
    sleep 3
}

#==================================================
# Estado
#==================================================

status_shadowsocks(){

    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}         📊 ESTADO SHADOWSOCKS${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    systemctl status "shadowsocks-libev-server@$SS_PORT" --no-pager

    echo ""
    echo "$(trx 'Puertos:')"
    ss -ltnp | grep -E ":$SS_PORT " || true

    echo ""
    read -n1 -r -p "$(trx 'Presione una tecla...')"
}

#==================================================
# Datos de conexión
#==================================================

show_info(){

    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}         📱 DATOS SHADOWSOCKS${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    VPS_IP=$(hostname -I | awk '{print $1}')
    SS_URL="ss://$(printf '%s' "$SS_METHOD:$SS_PASSWORD@$VPS_IP:$SS_PORT" | base64 -w0)#MoviVIP"

    echo "🌍 IP       : $VPS_IP"
    echo "🚀 Puerto   : $SS_PORT"
    echo "🔑 Clave    : $SS_PASSWORD"
    echo "🔐 Método   : $SS_METHOD"
    echo ""
    echo "📱 URL (importar en la app):"
    echo "   $SS_URL"

    echo ""
    read -n1 -r -p "$(trx 'Presione una tecla...')"
}

#==================================================
# Menú Principal
#==================================================

# Navegación con flechitas
[[ -f "$BASE/lib/nav.sh" ]] && source "$BASE/lib/nav.sh"

# ── CLI headless: bash shadowsocks.sh --install [puerto] [clave]
if [[ "${1:-}" == "--install" ]]; then
    [[ -n "${2:-}" ]] && export SS_PORT="$2"
    [[ -n "${3:-}" ]] && export SS_PASSWORD="$3"
    install_shadowsocks
    exit $?
fi

while true
do

    clear

    source "$CONFIG"

    SVC_NAME="shadowsocks-libev-server@$SS_PORT"

    if systemctl is-active --quiet "$SVC_NAME"; then
        STATUS="${GREEN}🟢 ACTIVO${RESET}"
    else
        STATUS="${RED}🔴 DETENIDO${RESET}"
    fi

    mv_header "🐋 Shadowsocks Manager" "$(trx 'SOCKS5 cifrado · 8388')" "v6.2"
    movivip_contacts 2>/dev/null || true

    echo -e " Estado      : $STATUS"
    echo -e " Puerto      : $SS_PORT"

    echo ""

    if [[ "$SHADOWSOCKS" == "ON" ]]; then
        LBL=("Nueva Clave" "Desinstalar Shadowsocks" "Reiniciar Servicio" "Ver Estado" "Ver Datos de Conexión")
    else
        LBL=("Instalar Shadowsocks")
    fi
    SEL=$(nav_pick "► Opción:" "${LBL[@]}" "↩ Regresar") || SEL=0
    [[ $SEL -eq $((${#LBL[@]}+1)) ]] && SEL=0
    OP="$SEL"

    case "$OP" in

        1)
            if [[ "$SHADOWSOCKS" == "ON" ]]; then
                reconfig_shadowsocks
            else
                install_shadowsocks
            fi
        ;;

        2)
            [[ "$SHADOWSOCKS" == "ON" ]] && remove_shadowsocks
        ;;

        3)
            [[ "$SHADOWSOCKS" == "ON" ]] && restart_shadowsocks
        ;;

        4)
            [[ "$SHADOWSOCKS" == "ON" ]] && status_shadowsocks
        ;;

        5)
            [[ "$SHADOWSOCKS" == "ON" ]] && show_info
        ;;

        0)
            exec bash "$BASE/protocolos/menu.sh"
        ;;

        *)
            echo ""
            echo "$(trx '❌ Opción inválida.')"
            sleep 2
        ;;

    esac

done