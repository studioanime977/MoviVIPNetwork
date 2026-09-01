#!/bin/bash

#==================================================
# MoviVIP Network Premium
# DTunnel Manager v1 (estilo MoviVIP)
# DTProto Server — protocolo DTunnel (DTunnel0)
# Túnel privado + proxy SSL/HTTP con auth PAM
# Multi-arquitectura: amd64 · arm64 · arm · 386
#
# • Binarios oficiales de DTunnel0/DTProto-Server-Releases
# • Detección automática de arquitectura (como slowdns)
# • Verificación sha256 de cada descarga
# • Auth vía usuarios del sistema (PAM)
# • Servicio systemd proto-server.service
#
# Compatible:
# • App oficial DTunnel (DTProto)
# • Clientes DTunnel / HTTP Custom (con token/credencial)
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

# i18n shim (auto)
if ! declare -F trx >/dev/null 2>&1; then trx() { printf '%s' "$1"; }; fi

CYAN="\e[1;96m"
GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
WHITE="\e[1;97m"
RESET="\e[0m"

SERVICE="proto-server"
GITHUB_REPO="DTunnel0/DTProto-Server-Releases"
VERSION_FALLBACK="v3.2.0"

BIN="/usr/local/bin/proto-server"
MENU_BIN="/usr/local/bin/proto"

DIR="/etc/proto-server"
CONFIG_FILE="$DIR/config.json"
STATS_FILE="$DIR/stats.json"
SERVICE_FILE="/etc/systemd/system/proto-server.service"
PAM_SERVICE_FILE="/etc/pam.d/proto-server"
LEGACY_SERVICES=("proto-server.service" "dtproto.service" "proxydt.service" "proxy-443.service" "proxy-80.service")

# Puertos por defecto del proxy DTunnel
DT_PROXY_PORT="${DTUNNEL_PORT:-443}"
DT_PROXY_PORT2="${DTUNNEL_PORT2:-80}"

#==================================================
# Detectar arquitectura (igual patrón que slowdns)
#==================================================

detect_arch(){
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64)        echo "linux-amd64" ;;
        aarch64|arm64) echo "linux-arm64" ;;
        armv7l|armv6l) echo "linux-arm" ;;
        i386|i686)     echo "linux-386" ;;
        *)
            echo "❌ Arquitectura no soportada: $arch"
            return 1
        ;;
    esac
}

#==================================================
# Última versión publicada en GitHub
#==================================================

fetch_latest_version(){
    local version
    version=$(curl -fsSL --max-time 15 \
        "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" 2>/dev/null \
        | grep -o '"tag_name": *"[^"]*"' | head -1 | cut -d'"' -f4)
    [[ -z "$version" ]] && version="$VERSION_FALLBACK"
    echo "$version"
}

#==================================================
# Instalar dependencias
#==================================================

install_dependencies(){
    echo "$(trx '📦 Instalando dependencias...')"
    apt update -y
    apt install -y \
        curl \
        wget \
        ca-certificates \
        jq \
        libpam0g \
        libpam-modules \
        psmisc

    mkdir -p "$DIR"
}

#==================================================
# Descargar proto-server (multi-arquitectura)
#==================================================

install_dtunnel_binary(){
    local ARCH BIN_NAME VER URL DL
    ARCH=$(detect_arch) || return 1

    if [[ -x "$BIN" ]]; then
        echo "$(trx '✅ DTunnel Server ya existe.')"
        return 0
    fi

    VER=$(fetch_latest_version)
    BIN_NAME="proto-server-${ARCH}"
    DL="https://github.com/${GITHUB_REPO}/releases/download/${VER}/${BIN_NAME}"

    echo ""
    echo "$(trx '⬇️ Instalando DTunnel Server...')"
    echo "   ${GRAY}Versión: ${WHITE}${VER#v}${GRAY} · ${WHITE}${ARCH}${RESET}"

    TMP_DIR=$(mktemp -d)
    trap 'rm -rf "$TMP_DIR"' EXIT

    echo "🌐 Descargando: $URL"

    if ! curl -fsSL --max-time 180 "$DL" -o "$TMP_DIR/$BIN_NAME"; then
        echo "$(trx '❌ Error descargando el binario.')"
        return 1
    fi

    if ! curl -fsSL --max-time 30 "${DL}.sha256" -o "$TMP_DIR/$BIN_NAME.sha256"; then
        echo "$(trx '❌ Error descargando el checksum.')"
        return 1
    fi

    (cd "$TMP_DIR" && sha256sum -c "$BIN_NAME.sha256" >/dev/null 2>&1) || {
        echo "$(trx '❌ El checksum del binario es inválido.')"
        return 1
    }

    install -m 0755 "$TMP_DIR/$BIN_NAME" "$BIN"

    if ! "$BIN" --version >/dev/null 2>&1; then
        echo "$(trx '❌ El binario no es compatible con este sistema.')"
        rm -f "$BIN"
        return 1
    fi

    echo "$(trx '✅ DTunnel Server instalado.')"
    return 0
}

#==================================================
# Configurar sysctl (túneles + BBR)
#==================================================

configure_sysctl(){
    local sysctl_file="/etc/sysctl.d/99-dtproto.conf"
    cat <<'EOF' > "${sysctl_file}"
net.ipv4.ip_forward = 1
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.rmem_default = 33554432
net.core.wmem_default = 33554432
net.ipv4.tcp_rmem = 4096 87380 33554432
net.ipv4.tcp_wmem = 4096 65536 33554432
net.core.netdev_max_backlog = 100000
net.ipv4.tcp_fastopen = 3
EOF
    modprobe tcp_bbr 2>/dev/null || true
    sysctl --system >/dev/null 2>&1 || true
}

#==================================================
# Configuración por defecto (proxy SSL + HTTP)
#==================================================

setup_config(){
    mkdir -p "$DIR"
    cat > "$CONFIG_FILE" <<EOF
{
  "server": {
    "virtual_subnet_cidr": "10.10.0.0/16",
    "stats_file": "$STATS_FILE",
    "auth": {
      "system": true
    },
    "tun": {
      "name": "tun0",
      "buffer_size": 65536
    }
  },
  "proxy": {
    "enabled": true,
    "listen": [
      {
        "host": "0.0.0.0",
        "port": $DT_PROXY_PORT,
        "ssl": true
      },
      {
        "host": "0.0.0.0",
        "port": $DT_PROXY_PORT2,
        "ssl": false
      }
    ]
  }
}
EOF
    echo "$(trx '✅ Configuración creada.')"
}

#==================================================
# Servicio PAM (auth con usuarios del sistema)
#==================================================

install_pam_service(){
    if [[ -f "$PAM_SERVICE_FILE" ]]; then
        return 0
    fi
    mkdir -p "$(dirname "$PAM_SERVICE_FILE")"
    cat > "$PAM_SERVICE_FILE" <<'EOF'
auth required pam_unix.so nodelay
account required pam_unix.so
EOF
    chmod 0644 "$PAM_SERVICE_FILE"
    echo "$(trx '✅ Servicio PAM configurado.')"
}

#==================================================
# Servicio systemd
#==================================================

create_dtunnel_service(){
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=DTunnel Protocolo Server
After=network.target

[Service]
Type=simple
ExecStart=$BIN --config $CONFIG_FILE
Restart=on-failure
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable proto-server >/dev/null 2>&1
    echo "$(trx '✅ Servicio proto-server.service creado.')"
}

#==================================================
# Limpiar instalaciones legadas
#==================================================

cleanup_legacy(){
    for svc in "${LEGACY_SERVICES[@]}"; do
        systemctl stop "${svc}" 2>/dev/null || true
        systemctl disable "${svc}" 2>/dev/null || true
        rm -f "/etc/systemd/system/${svc}"
    done
    systemctl daemon-reload 2>/dev/null || true
    pkill -9 -f "proto-server" 2>/dev/null || true
    pkill -9 -f "proxy-server" 2>/dev/null || true
}

#==================================================
# Instalar DTunnel
#==================================================

install_dtunnel(){
    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}          🛰 INSTALAR DTUNNEL${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    # Confirmar primero si ya hay algo instalado
    if systemctl list-unit-files 2>/dev/null | grep -q "^proto-server.service"; then
        echo "$(trx '⚠️  proto-server ya está instalado.')"
        read -rp "$(trx ' ¿Reinstalar? (s/n): ')" R
        [[ ! "$R" =~ ^[Ss]$ ]] && return
    fi

    ARCH_DETECTED=$(uname -m)
    echo -e " Arquitectura detectada : ${WHITE}${ARCH_DETECTED}${RESET}"
    echo ""

    read -rp "$(trx ' Puerto Proxy SSL (Default 443): ')" P1
    [[ -n "$P1" && "$P1" =~ ^[0-9]+$ ]] && DT_PROXY_PORT="$P1"

    read -rp "$(trx ' Puerto Proxy HTTP (Default 80): ')" P2
    [[ -n "$P2" && "$P2" =~ ^[0-9]+$ ]] && DT_PROXY_PORT2="$P2"

    echo ""

    install_dependencies || return 1

    install_dtunnel_binary || return 1

    cleanup_legacy

    configure_sysctl

    setup_config

    install_pam_service

    create_dtunnel_service

    echo ""
    echo "$(trx '🔄 Iniciando servicios...')"

    systemctl daemon-reload
    systemctl restart proto-server

    sleep 2

    if systemctl is-active --quiet proto-server; then
        sed -i '/^DTUNNEL=/d' "$CONFIG"
        echo "DTUNNEL=ON" >> "$CONFIG"
        sed -i '/^DTUNNEL_PORT=/d' "$CONFIG"
        echo "DTUNNEL_PORT=$DT_PROXY_PORT" >> "$CONFIG"
        sed -i '/^DTUNNEL_PORT2=/d' "$CONFIG"
        echo "DTUNNEL_PORT2=$DT_PROXY_PORT2" >> "$CONFIG"

        source "$CONFIG"

        IP_LOCAL=$(hostname -I | awk '{print $1}')

        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "$(trx '      ✅ DTUNNEL INSTALADO')"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "🌍 IP            : $IP_LOCAL"
        echo "🔐 Puerto SSL    : $DT_PROXY_PORT"
        echo "🔓 Puerto HTTP   : $DT_PROXY_PORT2"
        echo "🛃 Auth          : Usuarios del sistema (PAM)"
        echo "🗂 Config        : $CONFIG_FILE"
        echo ""
        echo "$(trx '  📋 CONFIGURACIÓN DE CLIENTE')"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "  • Usa la APP oficial DTunnel (DTProto)"
        echo "  • Servidor : $IP_LOCAL:$DT_PROXY_PORT"
        echo "  • Usuario  : crear usuario SSH (menú usuarios)"
        echo "  • Los usuarios del VPS inician sesión"
        echo "    como si fuera SSH normal"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
    else
        echo ""
        echo "$(trx '❌ Error iniciando DTunnel')"
        echo ""
        journalctl -u proto-server -n 20 --no-pager
    fi

    sleep 4
}

#==================================================
# Eliminar DTunnel
#==================================================

remove_dtunnel(){
    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}          🗑 ELIMINAR DTUNNEL${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    read -rp "$(trx '¿Eliminar DTunnel? (s/n): ')" R

    [[ ! "$R" =~ ^[Ss]$ ]] && return

    cleanup_legacy

    rm -f "$BIN"
    rm -f "$MENU_BIN"
    rm -f /etc/systemd/system/proto-server.service
    rm -f /etc/pam.d/proto-server
    rm -rf "$DIR"

    systemctl daemon-reload

    sed -i '/^DTUNNEL=/d' "$CONFIG"
    echo "DTUNNEL=OFF" >> "$CONFIG"
    sed -i '/^DTUNNEL_PORT=/d' "$CONFIG"
    sed -i '/^DTUNNEL_PORT2=/d' "$CONFIG"

    source "$CONFIG"

    echo ""
    echo "$(trx '✅ DTunnel eliminado.')"

    sleep 3
}

#==================================================
# Reiniciar servicios
#==================================================

restart_dtunnel(){
    clear

    echo "$(trx '🔄 Reiniciando servicios...')"

    systemctl restart proto-server

    sleep 2

    if systemctl is-active --quiet proto-server
    then
        echo ""
        echo "$(trx '✅ Servicios activos.')"
    else
        echo ""
        echo "$(trx '❌ Error al reiniciar.')"
    fi

    sleep 3
}

#==================================================
# Estado
#==================================================

status_dtunnel(){
    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}          📊 ESTADO DTUNNEL${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    echo ""
    systemctl status proto-server --no-pager

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    echo "$(trx 'Puertos abiertos:')"
    ss -tlnp | grep -E "proto-server|:${DT_PROXY_PORT}|:${DT_PROXY_PORT2}" || true

    echo ""
    echo "$(trx 'Configuración:')"
    [[ -f "$CONFIG_FILE" ]] && cat "$CONFIG_FILE"

    echo ""
    read -n1 -r -p "$(trx 'Presione una tecla...')"
}

#==================================================
# Mostrar conexión / datos de cliente
#==================================================

show_key(){
    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}          📡 DATOS DE CONEXIÓN${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    if [[ ! -x "$BIN" ]]; then
        echo "$(trx '❌ DTunnel no está instalado.')"
        echo ""
        read -n1 -r -p "$(trx 'Presione una tecla...')"
        return
    fi

    IP_LOCAL=$(hostname -I | awk '{print $1}')

    echo "🌍 Servidor : $IP_LOCAL"
    echo "🔐 SSL      : $DT_PROXY_PORT"
    echo "🔓 HTTP     : $DT_PROXY_PORT2"
    echo ""
    echo "🛃 Usuarios del sistema activos:"
    grep -E ':/home|:/root' /etc/passwd | grep -vE 'nologin|false' | awk -F: '{print "   • "$1}' | head -15
    echo ""
    echo "$(trx '📌 Crea usuarios desde el menú Usuarios SSH.')"
    echo "$(trx '   Se conectan igual que SSH (user/contraseña).')"

    echo ""
    read -n1 -r -p "$(trx 'Presione una tecla...')"
}

#==================================================
# Menú Principal
#==================================================

# Navegación con flechitas
[[ -f "$BASE/lib/nav.sh" ]] && source "$BASE/lib/nav.sh"

while true
do

    clear

    source "$CONFIG"

    if systemctl is-active --quiet proto-server; then
        STATUS="${GREEN}🟢 ACTIVO${RESET}"
    else
        STATUS="${RED}🔴 DETENIDO${RESET}"
    fi

    mv_header "🛰 DTunnel Manager" "$(trx 'Protocolo DTunnel · DTProto Server')" "v6.2"
    movivip_contacts 2>/dev/null || true

    echo -e " Estado      : $STATUS"
    echo -e " Puerto SSL  : $DT_PROXY_PORT"
    echo -e " Puerto HTTP : $DT_PROXY_PORT2"

    if [[ -f "$CONFIG_FILE" ]]; then
        echo -e " Arquitectura: ${YELLOW}$(uname -m)${RESET}"
    fi

    echo ""

    if [[ "$DTUNNEL" == "ON" ]]; then
        LBL=("Desinstalar DTunnel" "Reiniciar Servicios" "Ver Estado" "Ver Datos de Conexión")
    else
        LBL=("Instalar DTunnel")
    fi
    SEL=$(nav_pick "► Opción:" "${LBL[@]}" "↩ Regresar") || SEL=0
    [[ $SEL -eq $((${#LBL[@]}+1)) ]] && SEL=0
    OP="$SEL"

    case "$OP" in

        1)
            if [[ "$DTUNNEL" == "ON" ]]; then
                remove_dtunnel
            else
                install_dtunnel
            fi
        ;;

        2)
            [[ "$DTUNNEL" == "ON" ]] && restart_dtunnel
        ;;

        3)
            [[ "$DTUNNEL" == "ON" ]] && status_dtunnel
        ;;

        4)
            [[ "$DTUNNEL" == "ON" ]] && show_key
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