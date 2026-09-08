#!/bin/bash

# ── i18n shim (auto) ───────────────────────────────
if ! declare -F trx >/dev/null 2>&1; then trx() { printf '%s' "$1"; }; fi
# ─────────────────────────────────────────────────────────

#==================================================
# MoviVIP Network Premium
# BTUN Manager v1 (estilo MoviVIP)
# Túnel VPN ligero sobre TCP/UDP con autenticación
# de usuarios (auth file) y subnet 10.77.0.0/16
#
# • TCP + UDP en puerto 7900 (auto: evita BadVPN 7200/7300)
# • Tunnel: btun0 — subred 10.77.0.0/16
# • Usuarios gestionables desde el propio menú
# • Binario incluido: protocolos/btun/btun-server
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

SERVICE="btun"
DIR="/etc/btun"
BIN="/usr/local/bin/btun-server"
AUTH_FILE="$DIR/users"
BTUN_PORT="${BTUN_PORT:-7900}"
SUBNET="${BTUN_SUBNET:-10.77.0.0/16}"

STATUS=""

#==================================================
# Instalar dependencias
#==================================================

install_dependencies(){

    anim_step "$(trx 'Instalando dependencias')"
    anim_run "apt update" apt update -y
    anim_run "$(trx 'Instalar paquetes base')" apt install -y curl openssl ca-certificates iproute2

    mkdir -p "$DIR"

}

#==================================================
# Detectar arquitectura del sistema (patrón multi-arch)
#==================================================

detect_arch(){

    local arch
    arch=$(uname -m)

    case "$arch" in
        x86_64)            echo "linux-amd64" ;;
        aarch64|arm64)     echo "linux-arm64" ;;
        armv7l|armv6l)     echo "linux-arm" ;;
        i386|i686)         echo "linux-386" ;;
        *)
            echo "$(trx '❌ Arquitectura no soportada:') $arch"
            return 1
            ;;
    esac
}

#==================================================
# Instalar binario BTUN (incluido o fallback)
#==================================================

install_binary(){

    ARCH_TAG=""
    if ARCH_TAG=$(detect_arch 2>/dev/null); then
        :
    else
        detect_arch
        echo "$(trx '   Binarios disponibles: linux-amd64, linux-arm64, linux-arm, linux-386')"
        return 1
    fi

    for LOCAL_SRC in \
        "$BASE/protocolos/btun/btun-server-${ARCH_TAG}" \
        "$BASE/protocolos/btun/btun-server" \
        "$(dirname "$(readlink -f "$0")")/btun-server-${ARCH_TAG}" \
        "$(dirname "$(readlink -f "$0")")/btun-server"
    do
        [[ -f "$LOCAL_SRC" ]] || continue

        if cp -f "$LOCAL_SRC" "$BIN" && chmod +x "$BIN" && "$BIN" -version >/dev/null 2>&1; then
            anim_run "$(trx 'Binario BTUN instalado')" true
            return 0
        fi
        rm -f "$BIN"
    done

    echo "$(trx '❌ No se encontró el binario btun-server.')"
    echo "$(trx '   Debe estar en protocolos/btun/btun-server')"
    echo "$(trx '   o protocolos/btun/btun-server-')${ARCH_TAG}"
    return 1
}

#==================================================
# Crear credenciales default
#==================================================

gen_users(){

    if [[ ! -f "$AUTH_FILE" ]]; then
        PASS=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9')
        echo "movivip:$PASS" > "$AUTH_FILE"
        chmod 600 "$AUTH_FILE"
        echo "$(trx '✅ Credencial BTUN generada:') movivip:$PASS"
    fi

}

#==================================================
# Crear servicio BTUN
#==================================================

create_service(){

    mkdir -p /var/lib/btun

    cat > /etc/systemd/system/btun.service <<SVCEOF
[Unit]
Description=MoviVIP BTUN (VPN over TCP/UDP)
After=network.target

[Service]
Type=simple
User=root
ExecStart=$BIN -auth file -auth-file $AUTH_FILE -tcp-listen 0.0.0.0:$BTUN_PORT -udp-listen 0.0.0.0:$BTUN_PORT -subnet $SUBNET -tun btun0 -stats-file /var/lib/btun/stats.json -handshake-timeout 15s -idle-timeout 2m
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SVCEOF

    systemctl daemon-reload
    systemctl enable btun >/dev/null 2>&1

    echo "$(trx '✅ Servicio btun.service creado.')"
}

#==================================================
# Abrir puertos
#==================================================

open_ports(){

    echo "$(trx '🛡 Abriendo puertos...')"

    iptables -C INPUT -p tcp --dport "$BTUN_PORT" -j ACCEPT 2>/dev/null \
        || iptables -A INPUT -p tcp --dport "$BTUN_PORT" -j ACCEPT
    iptables -C INPUT -p udp --dport "$BTUN_PORT" -j ACCEPT 2>/dev/null \
        || iptables -A INPUT -p udp --dport "$BTUN_PORT" -j ACCEPT

    if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
        ufw allow "$BTUN_PORT"/tcp >/dev/null 2>&1
        ufw allow "$BTUN_PORT"/udp >/dev/null 2>&1
    fi

    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4 2>/dev/null

}

#==================================================
# Test funcional
#==================================================

test_btun(){

    echo ""
    echo "$(trx '🧪 Verificando BTUN...')"

    if systemctl is-active --quiet btun && \
       ss -ltnp 2>/dev/null | grep -qE ":$BTUN_PORT "; then
        echo "$(trx '✅ BTUN activo y escuchando (TCP).')"
        return 0
    fi

    if systemctl is-active --quiet btun; then
        echo "$(trx '✅ Servicio activo.')"
        return 0
    fi

    echo "$(trx '⚠️  El servicio no está activo.')"
    echo "$(trx '    Revisa: journalctl -u btun -n 20 --no-pager')"
    return 1
}

#==================================================
# Instalar BTUN
#==================================================

install_btun(){

    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}        🧵 INSTALAR BTUN${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    # Auto-ajuste: BadVPN UDPGW usa 7200/7300 en instalación completa
    # (solo si el puerto no fue forzado por CLI)
    if [[ "${BTUN_PORT_FORCED:-0}" != "1" ]] && \
       systemctl is-active --quiet badvpn-udpgw-7300 2>/dev/null && \
       [[ "$BTUN_PORT" == "7300" ]]; then
        echo -e "  ${YELLOW}⚠  BadVPN ya usa el puerto 7300.${RESET}"
        echo -e "  ${YELLOW}   BTUN usará el alterno ${WHITE}7900${RESET} (BTUN_PORT en $CONFIG).${RESET}"
        echo ""
        BTUN_PORT="7900"
    fi

    anim_init 5
    anim_step "$(trx 'Instalando dependencias')"
    install_dependencies || return

    install_binary || return

    anim_step "$(trx 'Configurando BTUN')"
    gen_users

    create_service

    anim_step "$(trx 'Abriendo puertos')"
    open_ports

    echo ""
    anim_step "$(trx 'Iniciando servicios')"
    anim_run "daemon-reload" systemctl daemon-reload

    systemctl enable btun >/dev/null 2>&1

    svc_restart_anim btun "$(trx 'Arrancando BTUN')"

    if ! systemctl is-active --quiet btun; then
        echo "$(trx '❌ BTUN no pudo iniciar.')"
        journalctl -u btun -n 20 --no-pager
        return 1
    fi

    test_btun

    sleep 3

    if systemctl is-active --quiet btun; then

        sed -i '/^BTUN=/d' "$CONFIG"
        echo "BTUN=ON" >> "$CONFIG"
        sed -i '/^BTUN_PORT=/d' "$CONFIG"
        echo "BTUN_PORT=$BTUN_PORT" >> "$CONFIG"

        source "$CONFIG"

        VPS_IP=$(hostname -I | awk '{print $1}')
        BTUN_USER=$(head -n1 "$AUTH_FILE" 2>/dev/null | cut -d: -f1)
        BTUN_PASS=$(head -n1 "$AUTH_FILE" 2>/dev/null | cut -d: -f2)

        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "$(trx '      ✅ BTUN INSTALADO')"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "🌍 IP        : $VPS_IP"
        echo "🚀 TCP/UDP   : $BTUN_PORT"
        echo "🌐 Subred    : $SUBNET"
        echo "👤 Usuario   : ${BTUN_USER:-movivip}"
        echo "🔑 Clave     : ${BTUN_PASS:-********}"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "$(trx '  📱 CONFIGURACIÓN EN LA APP')"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "   Modo     : $(trx 'VPN / Túnel (BTUN)')"
        echo "   Host     : $VPS_IP"
        echo "   Puerto   : $BTUN_PORT (TCP+UDP)"
        echo ""
        echo "$(trx '  Gestiona usuarios desde el menú:')"
        echo "$(trx '  "Gestionar Usuarios"')"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

    else

        echo ""
        echo "$(trx '❌ Error iniciando BTUN')"
        echo ""
        systemctl status btun --no-pager

    fi

    sleep 4
}

#==================================================
# Eliminar BTUN
#==================================================

remove_btun(){

    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}        🗑 ELIMINAR BTUN${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    read -rp "$(trx '¿Eliminar BTUN? (s/n): ')" R
    [[ ! "$R" =~ ^[Ss]$ ]] && return

    anim_step "$(trx 'Desinstalando BTUN')"
    anim_run "$(trx 'Detener y deshabilitar')" bash -c "systemctl stop btun 2>/dev/null; systemctl disable btun 2>/dev/null"
    anim_run "$(trx 'Eliminar servicio')" rm -f /etc/systemd/system/btun.service
    anim_run "$(trx 'Eliminar directorio')" rm -rf "$DIR"
    anim_run "$(trx 'Eliminar binario')" rm -f "$BIN"
    anim_run "daemon-reload" systemctl daemon-reload

    iptables -D INPUT -p tcp --dport "$BTUN_PORT" -j ACCEPT 2>/dev/null
    iptables -D INPUT -p udp --dport "$BTUN_PORT" -j ACCEPT 2>/dev/null

    sed -i '/^BTUN=/d' "$CONFIG"
    echo "BTUN=OFF" >> "$CONFIG"

    source "$CONFIG"

    echo ""
    echo "$(trx '✅ BTUN eliminado.')"
    sleep 3
}

#==================================================
# Gestión de usuarios BTUN
#==================================================

manage_users(){

    while true
    do

        clear

        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
        echo -e "${WHITE}         👤 USUARIOS BTUN${RESET}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
        echo ""

        if [[ -f "$AUTH_FILE" ]]; then
            echo "$(trx 'Usuarios existentes:')"
            echo ""
            while IFS=: read -r U P; do
                echo "   👤 $U  🔑 $P"
            done < "$AUTH_FILE"
        else
            echo "$(trx 'Sin usuarios registrados.')"
        fi

        echo ""

        LBL=("$(trx 'Añadir Usuario')" "$(trx 'Eliminar Usuario')")
        SEL=$(nav_pick "► Opción:" "${LBL[@]}" "↩ Regresar") || SEL=0
        [[ $SEL -eq $((${#LBL[@]}+1)) ]] && SEL=0
        OP="$SEL"

        case "$OP" in

            1)
                echo ""
                read -rp "$(trx 'Nombre de usuario: ')" NUSER
                read -rp "$(trx 'Clave (Enter = aleatoria): ')" NPASS
                [[ -z "$NPASS" ]] && NPASS=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9')
                if [[ -n "$NUSER" ]]; then
                    sed -i "/^$NUSER:/d" "$AUTH_FILE" 2>/dev/null
                    echo "$NUSER:$NPASS" >> "$AUTH_FILE"
                    echo "$(trx '✅ Usuario añadido:') $NUSER:$NPASS"
                    systemctl restart btun 2>/dev/null
                fi
                sleep 3
            ;;

            2)
                echo ""
                read -rp "$(trx 'Nombre de usuario a eliminar: ')" DUSER
                if [[ -n "$DUSER" ]]; then
                    sed -i "/^$DUSER:/d" "$AUTH_FILE" 2>/dev/null
                    echo "$(trx '✅ Usuario eliminado.')"
                    systemctl restart btun 2>/dev/null
                fi
                sleep 3
            ;;

            0)
                return
            ;;

        esac

    done
}

#==================================================
# Reiniciar servicio
#==================================================

restart_btun(){

    clear
    svc_restart_anim btun "$(trx 'Reiniciando BTUN')"
    sleep 2

    if systemctl is-active --quiet btun; then
        echo ""
        echo "$(trx '✅ Servicio activo.')"
        test_btun
    else
        echo ""
        echo "$(trx '❌ Error al reiniciar.')"
    fi
    sleep 3
}

#==================================================
# Estado
#==================================================

status_btun(){

    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}         📊 ESTADO BTUN${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    systemctl status btun --no-pager

    echo ""
    echo "$(trx 'Interfaz TUN:')"
    ip addr show btun0 2>/dev/null || echo "$(trx '(sin interfaz — sin conexiones)')"

    echo ""
    read -n1 -r -p "$(trx 'Presione una tecla...')"
}

#==================================================
# Datos de conexión
#==================================================

show_info(){

    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}         📱 DATOS BTUN${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    VPS_IP=$(hostname -I | awk '{print $1}')
    BTUN_USER=$(head -n1 "$AUTH_FILE" 2>/dev/null | cut -d: -f1)
    BTUN_PASS=$(head -n1 "$AUTH_FILE" 2>/dev/null | cut -d: -f2)

    echo "🌍 IP        : $VPS_IP"
    echo "🚀 TCP/UDP   : $BTUN_PORT"
    echo "🌐 Subred    : $SUBNET"
    echo "👤 Usuario   : ${BTUN_USER:-movivip}"
    echo "🔑 Clave     : ${BTUN_PASS:-********}"

    echo ""
    read -n1 -r -p "$(trx 'Presione una tecla...')"
}

#==================================================
# Menú Principal
#==================================================

# Navegación con flechitas
[[ -f "$BASE/lib/nav.sh" ]] && source "$BASE/lib/nav.sh"

# ── CLI headless: bash btun.sh --install [puerto]
if [[ "${1:-}" == "--install" ]]; then
    [[ -n "${2:-}" ]] && export BTUN_PORT="$2" BTUN_PORT_FORCED=1
    install_btun
    exit $?
fi

while true
do

    clear

    source "$CONFIG"

    if systemctl is-active --quiet btun; then
        STATUS="${GREEN}🟢 ACTIVO${RESET}"
    else
        STATUS="${RED}🔴 DETENIDO${RESET}"
    fi

    mv_header "🧵 BTUN Manager" "$(trx 'VPN TCP/UDP · 7300')" "v6.2"
    movivip_contacts 2>/dev/null || true

    echo -e " Estado      : $STATUS"
    echo -e " Puerto      : $BTUN_PORT"
    echo -e " Subred      : $SUBNET"

    echo ""

    if [[ "$BTUN" == "ON" ]]; then
        LBL=("Gestionar Usuarios" "Desinstalar BTUN" "Reiniciar Servicio" "Ver Estado" "Ver Datos de Conexión")
    else
        LBL=("Instalar BTUN")
    fi
    SEL=$(nav_pick "► Opción:" "${LBL[@]}" "↩ Regresar") || SEL=0
    [[ $SEL -eq $((${#LBL[@]}+1)) ]] && SEL=0
    OP="$SEL"

    case "$OP" in

        1)
            if [[ "$BTUN" == "ON" ]]; then
                manage_users
            else
                install_btun
            fi
        ;;

        2)
            [[ "$BTUN" == "ON" ]] && remove_btun
        ;;

        3)
            [[ "$BTUN" == "ON" ]] && restart_btun
        ;;

        4)
            [[ "$BTUN" == "ON" ]] && status_btun
        ;;

        5)
            [[ "$BTUN" == "ON" ]] && show_info
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