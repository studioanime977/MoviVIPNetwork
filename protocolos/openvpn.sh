#!/bin/bash

# ── i18n shim (auto) ───────────────────────────────
if ! declare -F trx >/dev/null 2>&1; then trx() { printf '%s' "$1"; }; fi
# ─────────────────────────────────────────────────────────

#==================================================
# MoviVIP Network Premium
# OpenVPN Server Manager v1 (estilo MoviVIP)
# Servidor OpenVPN UDP con PKI easy-rsa + auth
# usuario/contraseña (chumo-style passwd file).
#
# • Puerto : UDP 1194 (configurable OPENVPN_PORT)
# • Red    : 10.9.0.0/24 (tun)
# • Usuarios: /etc/openvpn/passwd (hash MD5-crypt)
# • Clientes: /etc/openvpn/clients/<user>.ovpn
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
GRAY="\e[1;90m"
RESET="\e[0m"

OVPN_DIR="/etc/openvpn"
OVPN_PKI="$OVPN_DIR/easy-rsa/pki"
OVPN_PASSWD="$OVPN_DIR/passwd"
OVPN_CLIENTS="$OVPN_DIR/clients"
OVPN_PORT="${OPENVPN_PORT:-1194}"
OVPN_SUBNET="${OPENVPN_SUBNET:-10.9.0.0}"
OVPN_NETMASK="${OPENVPN_NETMASK:-255.255.255.0}"
OVPN_POOL="${OPENVPN_POOL:-10.9.0.0}"
OVPN_DNS="${OPENVPN_DNS:-1.1.1.1,8.8.8.8}"

# easy-rsa en modo batch siempre (sin prompts interactivos)
export EASYRSA_BATCH=1
export EASYRSA_NS_COMMENT="MoviVIP Network"

# Función: estado
STATE() { systemctl is-active --quiet "$1" && echo "${GREEN}🟢${RESET}" || echo "${RED}🔴${RESET}"; }

#==================================================
# Instalar dependencias
#==================================================

install_dependencies(){

    anim_step "$(trx 'Instalando dependencias')"
    anim_run "apt update" apt update -y
    anim_run "$(trx 'Instalar openvpn')" apt install -y openvpn easy-rsa openssl

    if ! command -v openvpn >/dev/null 2>&1; then
        echo "$(trx '❌ No se encontró openvpn.')"
        return 1
    fi
    if ! command -v easyrsa >/dev/null 2>&1 && [[ ! -x /usr/share/easy-rsa/easyrsa ]]; then
        echo "$(trx '❌ No se encontró easy-rsa.')"
        return 1
    fi
    return 0
}

easyrsa(){
    local BIN
    BIN=$(type -P easyrsa 2>/dev/null) || BIN="/usr/share/easy-rsa/easyrsa"
    "$BIN" "$@"
}

#==================================================
# Construir PKI (CA + servidor + DH + tls-auth)
#==================================================

build_pki(){

    mkdir -p "$OVPN_DIR/easy-rsa"

    # Init PKI (idempotente: conserva CA existente)
    if [[ ! -f "$OVPN_PKI/ca.crt" ]]; then
        anim_step "$(trx 'Inicializando PKI (easy-rsa)')"
        ( cd "$OVPN_DIR/easy-rsa" && easyrsa init-pki >/dev/null 2>&1 )
        ( cd "$OVPN_DIR/easy-rsa" && EASYRSA_REQ_CN="MoviVIP CA" easyrsa build-ca nopass >/dev/null 2>&1 )
    fi

    if [[ ! -f "$OVPN_PKI/private/server.key" || ! -f "$OVPN_PKI/issued/server.crt" ]]; then
        ( cd "$OVPN_DIR/easy-rsa" && EASYRSA_REQ_CN="server" easyrsa gen-req server nopass >/dev/null 2>&1 )
        ( cd "$OVPN_DIR/easy-rsa" && easyrsa sign-req server server >/dev/null 2>&1 )
    fi

    # DH params (una sola vez; lento en VPS pequeños)
    if [[ ! -f "$OVPN_PKI/dh.pem" ]]; then
        anim_step "$(trx 'Generando parámetros DH (puede tardar 1-3 min)...')"
        ( cd "$OVPN_DIR/easy-rsa" && easyrsa gen-dh >/dev/null 2>&1 )
    fi

    # tls-auth key estática
    if [[ ! -f "$OVPN_DIR/ta.key" ]]; then
        openvpn --genkey secret "$OVPN_DIR/ta.key" 2>/dev/null
    fi

    # CRL inicial
    if [[ ! -f "$OVPN_PKI/crl.pem" ]]; then
        ( cd "$OVPN_DIR/easy-rsa" && easyrsa gen-crl >/dev/null 2>&1 )
    fi

    chmod 600 "$OVPN_DIR/easy-rsa/pki/private/"* 2>/dev/null
    return 0
}

#==================================================
# Crear script de login (auth-user-pass-verify)
#==================================================

create_login_script(){

    cat > "$OVPN_DIR/login.sh" <<'LOGINEOF'
#!/bin/bash
# MoviVIP OpenVPN — verificación usuario/contraseña
# Formato passwd: usuario:$1$salt$hash
# Soporta via-env (username/password) o legacy (args $1/$2)
USER="$1"
PASS="$2"
[ -z "$USER" ] && USER="${username:-}"
[ -z "$PASS" ] && PASS="${password:-}"
[ -z "$USER" ] && exit 1
[ -z "$PASS" ] && exit 1
HASH=$(grep "^${USER}:" /etc/openvpn/passwd 2>/dev/null | cut -d: -f2)
[ -z "$HASH" ] && exit 1
SALT=$(echo "$HASH" | cut -d'$' -f3)
[ -z "$SALT" ] && exit 1
COMPUTED=$(openssl passwd -1 -salt "$SALT" "$PASS" 2>/dev/null)
[ "$COMPUTED" = "$HASH" ] && exit 0
exit 1
LOGINEOF

    chmod 755 "$OVPN_DIR/login.sh"
    touch "$OVPN_PASSWD"
    chmod 600 "$OVPN_PASSWD"
}

#==================================================
# Config servidor
#==================================================

create_server_conf(){

    cat > "$OVPN_DIR/server.conf" <<CONFEOF
# MoviVIP Network — OpenVPN Server
port $OVPN_PORT
proto udp
dev tun
ca $OVPN_PKI/ca.crt
cert $OVPN_PKI/issued/server.crt
key $OVPN_PKI/private/server.key
dh $OVPN_PKI/dh.pem
tls-auth $OVPN_DIR/ta.key 0
crl-verify $OVPN_PKI/crl.pem

server $OVPN_POOL $OVPN_NETMASK
push "redirect-gateway def1 bypass-dhcp"
keepalive 10 120

# Auth usuario/contraseña (además del certificado)
auth-user-pass-verify $OVPN_DIR/login.sh via-env
verify-client-cert require
username-as-common-name
script-security 3

cipher AES-256-CBC
auth SHA256
tls-version-min 1.2
reneg-sec 0

max-clients 100
client-config-dir $OVPN_DIR/ccd
comp-lzo no
persist-key
persist-tun
status /var/log/openvpn-status.log
log-append /var/log/openvpn.log
verb 3
CONFEOF

    # DNS separados en líneas push independientes
    # (OpenVPN 2.6 rechaza comas dentro de dhcp-option)
    for DNSIP in ${OVPN_DNS//,/ }; do
        echo "push \"dhcp-option DNS $DNSIP\"" >> "$OVPN_DIR/server.conf"
    done

    mkdir -p "$OVPN_DIR/ccd"

    # NAT + forwarding
    if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf 2>/dev/null; then
        echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    fi
    sysctl -p >/dev/null 2>&1 || true

    # iptables NAT para el pool VPN
    IFACE=$(ip route get 8.8.8.8 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')
    [[ -z "$IFACE" ]] && IFACE="eth0"
    iptables -t nat -C POSTROUTING -s "$OVPN_POOL/24" -o "$IFACE" -j MASQUERADE 2>/dev/null \
        || iptables -t nat -A POSTROUTING -s "$OVPN_POOL/24" -o "$IFACE" -j MASQUERADE
}

#==================================================
# Abrir puertos
#==================================================

open_ports(){

    echo "$(trx '🛡 Abriendo puertos...')"

    iptables -C INPUT -p udp --dport "$OVPN_PORT" -j ACCEPT 2>/dev/null \
        || iptables -A INPUT -p udp --dport "$OVPN_PORT" -j ACCEPT

    if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
        ufw allow "$OVPN_PORT"/udp >/dev/null 2>&1
    fi

    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4 2>/dev/null
}

#==================================================
# Crear servicio systemd
#==================================================

create_service(){

    cat > /etc/systemd/system/openvpn@server.service <<SVCEOF
[Unit]
Description=MoviVIP OpenVPN Server (UDP $OVPN_PORT)
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=/usr/sbin/openvpn --status /run/openvpn-server.status 10 --cd /etc/openvpn --script-security 3 --config /etc/openvpn/server.conf
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SVCEOF

    systemctl daemon-reload
    systemctl enable openvpn@server >/dev/null 2>&1
    echo "$(trx '✅ Servicio OpenVPN creado.')"
}

#==================================================
# Gestión de usuarios (cert + passwd + .ovpn)
#==================================================

_ovpn_exists_user(){
    grep -q "^${1}:" "$OVPN_PASSWD" 2>/dev/null
}

make_ovpn(){
    local USER="$1"
    local VPS_IP
    VPS_IP=$(hostname -I | awk '{print $1}')

    {
        echo "client"
        echo "dev tun"
        echo "proto udp"
        echo "remote $VPS_IP $OVPN_PORT"
        echo "resolv-retry infinite"
        echo "nobind"
        echo "persist-key"
        echo "persist-tun"
        echo "remote-cert-tls server"
        echo "auth-user-pass"
        echo "cipher AES-256-CBC"
        echo "auth SHA256"
        echo "verb 3"
        echo "<ca>"
        cat "$OVPN_PKI/ca.crt"
        echo "</ca>"
        echo "<cert>"
        sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' "$OVPN_PKI/issued/$USER.crt"
        echo "</cert>"
        echo "<key>"
        cat "$OVPN_PKI/private/$USER.key"
        echo "</key>"
        echo "<tls-auth>"
        cat "$OVPN_DIR/ta.key"
        echo "</tls-auth>"
        echo "key-direction 1"
    } > "$OVPN_CLIENTS/$USER.ovpn"

    chmod 600 "$OVPN_CLIENTS/$USER.ovpn"
}

add_user(){
    local USER="${1:-}" PASS="${2:-}"
    [[ -z "$USER" ]] && {
        read -rp "$(trx '👤 Usuario: ')" USER
    }
    USER=$(echo "$USER" | tr -d ' /:')
    [[ -z "$USER" ]] && { echo "$(trx '❌ Usuario inválido.')"; return 1; }

    if _ovpn_exists_user "$USER"; then
        echo -e "${YELLOW}⚠️  El usuario '$USER' ya existe.${RESET}"
        read -rp "$(trx '¿Eliminar y recrear? (s/n): ')" R
        [[ ! "$R" =~ ^[Ss]$ ]] && return 1
        remove_user "$USER" >/dev/null 2>&1
    fi

    if [[ -z "$PASS" ]]; then
        read -rsp "$(trx '🔑 Contraseña: ')" PASS
        echo ""
        [[ -z "$PASS" ]] && { echo "$(trx '❌ Contraseña vacía.')"; return 1; }
    fi

    mkdir -p "$OVPN_CLIENTS"

    anim_step "$(trx 'Generando certificado del cliente')"
    ( cd "$OVPN_DIR/easy-rsa" && easyrsa build-client-full "$USER" nopass >/dev/null 2>&1 ) \
        || { echo "$(trx '❌ No se pudo generar el certificado.')"; return 1; }

    # Registrar en passwd (hash MD5-crypt)
    HASH=$(openssl passwd -1 "$PASS")
    echo "${USER}:${HASH}" >> "$OVPN_PASSWD"

    make_ovpn "$USER"

    echo -e "${GREEN}✅ Usuario '$USER' creado.${RESET}"
    echo -e "📄 Config: ${WHITE}$OVPN_CLIENTS/$USER.ovpn${RESET}"
    echo -e "📲 Envíale este archivo al cliente (OpenVPN Connect / KPN / HTTP Injector OpenVPN)."
    return 0
}

remove_user(){
    local USER="${1:-}"
    [[ -z "$USER" ]] && {
        read -rp "$(trx '👤 Usuario a eliminar: ')" USER
    }
    if ! _ovpn_exists_user "$USER"; then
        echo -e "${YELLOW}⚠️  '$USER' no existe en OpenVPN.${RESET}"
        sleep 2
        return 1
    fi

    anim_step "$(trx 'Revocando certificado')"
    ( cd "$OVPN_DIR/easy-rsa" && easyrsa revoke "$USER" >/dev/null 2>&1 )
    ( cd "$OVPN_DIR/easy-rsa" && easyrsa gen-crl >/dev/null 2>&1 )
    cp -f "$OVPN_PKI/crl.pem" "$OVPN_DIR/crl.pem" 2>/dev/null

    sed -i "/^${USER}:/d" "$OVPN_PASSWD"
    rm -f "$OVPN_CLIENTS/$USER.ovpn"

    echo -e "${GREEN}✅ Usuario '$USER' eliminado (certificado revocado).${RESET}"
    sleep 2
    return 0
}

list_users(){
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}         👥 USUARIOS OPENVPN${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    if [[ ! -f "$OVPN_PASSWD" || ! -s "$OVPN_PASSWD" ]]; then
        echo "$(trx 'No hay usuarios.')"
    else
        while IFS=: read -r U H; do
            CONFIG_FILE="$OVPN_CLIENTS/$U.ovpn"
            [[ -f "$CONFIG_FILE" ]] && CFG="📄 sí" || CFG="📄 no"
            echo -e "  ${GREEN}●${RESET} $U  ${GRAY}($CFG)${RESET}"
        done < "$OVPN_PASSWD"
    fi
    echo ""
    read -n1 -r -p "$(trx 'Presione una tecla...')"
}

#==================================================
# Test funcional
#==================================================

test_openvpn(){

    echo ""
    echo "$(trx '🧪 Verificando servidor OpenVPN...')"

    if systemctl is-active --quiet openvpn@server; then
        echo "$(trx '✅ El servidor OpenVPN está ACTIVO.')"
        return 0
    fi

    echo "$(trx '⚠️  OpenVPN no está activo.')"
    journalctl -u openvpn@server -n 15 --no-pager 2>/dev/null | tail -10
    return 1
}

#==================================================
# Instalar OpenVPN
#==================================================

install_openvpn(){

    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}        🛡 INSTALAR OPENVPN${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    anim_init 6
    anim_step "$(trx 'Instalando dependencias')"
    install_dependencies || return

    anim_step "$(trx 'Construyendo PKI (CA + server)')"
    build_pki || return

    anim_step "$(trx 'Creando script de login')"
    create_login_script

    anim_step "$(trx 'Creando configuración del servidor')"
    create_server_conf

    anim_step "$(trx 'Creando servicio systemd')"
    create_service

    anim_step "$(trx 'Abriendo puertos')"
    open_ports

    echo ""
    anim_step "$(trx 'Iniciando servicio')"
    systemctl restart openvpn@server
    svc_restart_anim "openvpn@server" "$(trx 'Arrancando') openvpn@server" 2>/dev/null

    if systemctl is-active --quiet openvpn@server; then

        sed -i '/^OPENVPN=/d' "$CONFIG"
        echo "OPENVPN=ON" >> "$CONFIG"
        source "$CONFIG"

        VPS_IP=$(hostname -I | awk '{print $1}')

        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "$(trx '      ✅ OPENVPN INSTALADO')"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "🌍 IP     : $VPS_IP"
        echo "🚀 Puerto : UDP $OVPN_PORT"
        echo "🌐 Red    : $OVPN_POOL/24"
        echo ""
        echo "$(trx '  Crea usuarios para generar sus archivos .ovpn:')"
        echo "  📌 Desde el menú: Protocolos → OpenVPN → [2] Agregar usuario"
        echo ""
        if [[ ! -s "$OVPN_PASSWD" ]]; then
            echo -e "${YELLOW}  💡 Agrega tu primer usuario ahora desde el menú.${RESET}"
        fi
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
    else
        echo ""
        echo "$(trx '❌ Error iniciando OpenVPN')"
        journalctl -u openvpn@server -n 15 --no-pager 2>/dev/null | tail -10
    fi

    sleep 4
}

#==================================================
# Eliminar OpenVPN
#==================================================

remove_openvpn(){

    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}        🗑 ELIMINAR OPENVPN${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    read -rp "$(trx '¿Eliminar OpenVPN? (s/n): ')" R
    [[ ! "$R" =~ ^[Ss]$ ]] && return

    anim_step "$(trx 'Desinstalando OpenVPN')"

    anim_run "$(trx 'Detener servicio')" bash -c "systemctl stop openvpn@server 2>/dev/null; systemctl disable openvpn@server 2>/dev/null"
    anim_run "$(trx 'Eliminar unidad')" rm -f /etc/systemd/system/openvpn@server.service
    anim_run "daemon-reload" systemctl daemon-reload

    anim_run "$(trx 'Eliminar directorio')" rm -rf "$OVPN_DIR"
    anim_run "$(trx 'Limpiar NAT')" bash -c "iptables -t nat -D POSTROUTING -s $OVPN_POOL/24 -j MASQUERADE 2>/dev/null; true"
    iptables -D INPUT -p udp --dport "$OVPN_PORT" -j ACCEPT 2>/dev/null

    sed -i '/^OPENVPN=/d' "$CONFIG"
    echo "OPENVPN=OFF" >> "$CONFIG"

    source "$CONFIG"

    echo ""
    echo "$(trx '✅ OpenVPN eliminado.')"
    sleep 3
}

#==================================================
# Reiniciar servicios
#==================================================

restart_openvpn(){

    clear

    svc_restart_anim "openvpn@server" "$(trx 'Reiniciando') openvpn@server" 2>/dev/null

    sleep 2
    test_openvpn
    sleep 3
}

#==================================================
# Estado
#==================================================

status_openvpn(){

    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}         📊 ESTADO OPENVPN${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    echo -e "  $(STATE openvpn@server) openvpn@server (UDP $OVPN_PORT)"

    echo ""
    echo "$(trx 'Puertos:')"
    ss -lunp | grep ":$OVPN_PORT " || true

    echo ""
    echo "$(trx 'Usuarios:')"
    if [[ -f "$OVPN_PASSWD" && -s "$OVPN_PASSWD" ]]; then
        wc -l < "$OVPN_PASSWD" | xargs echo "  Total:"
    else
        echo "  $(trx 'No hay usuarios')"
    fi

    echo ""
    read -n1 -r -p "$(trx 'Presione una tecla...')"
}

#==================================================
# Datos de conexión
#==================================================

show_info(){

    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}         📱 DATOS OPENVPN${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    VPS_IP=$(hostname -I | awk '{print $1}')

    echo "🌍 IP     : $VPS_IP"
    echo "🚀 Puerto : UDP $OVPN_PORT"
    echo "🌐 Red    : $OVPN_POOL/24"
    echo "🔑 Auth   : usuario + contraseña (más certificado)"
    echo "📂 Clientes: $OVPN_CLIENTS"
    echo ""
    echo "$(trx '  Apps compatibles:')"
    echo "   ${GREEN}OpenVPN Connect / OpenVPN for Android${RESET}"
    echo "   ${GREEN}KPN Tunnels / HTTP Injector (modo OpenVPN)${RESET}"
    echo "   ${GREEN}Happ / EasyOVPN${RESET}"
    echo ""
    echo "$(trx '  Importar: envía el archivo .ovpn del usuario.')"

    echo ""
    read -n1 -r -p "$(trx 'Presione una tecla...')"
}

#==================================================
# Menú Principal
#==================================================

# Navegación con flechitas
[[ -f "$BASE/lib/nav.sh" ]] && source "$BASE/lib/nav.sh"

# ── CLI headless ──
case "${1:-}" in
    --install)
        install_dependencies >/dev/null 2>&1 && echo "OK deps" || true
        INSTALL_HEADLESS=1
        ;;
    --add-user)
        add_user "$2" "$3"
        exit $?
        ;;
    --remove-user)
        remove_user "$2"
        exit $?
        ;;
    --list)
        list_users
        exit $?
        ;;
    --status)
        test_openvpn
        exit $?
        ;;
esac

# Modo instalación headless (install.sh lo invoca: bash openvpn.sh --install)
if [[ "${INSTALL_HEADLESS:-}" == "1" ]]; then
    install_dependencies || exit 1
    build_pki || exit 1
    create_login_script
    create_server_conf
    create_service
    open_ports
    systemctl restart openvpn@server
    if systemctl is-active --quiet openvpn@server; then
        sed -i '/^OPENVPN=/d' "$CONFIG"
        echo "OPENVPN=ON" >> "$CONFIG"
        exit 0
    fi
    exit 1
fi

while true
do

    clear

    source "$CONFIG"

    if systemctl is-active --quiet openvpn@server; then
        STATUS="${GREEN}🟢 ACTIVO${RESET}"
    else
        STATUS="${RED}🔴 DETENIDO${RESET}"
    fi

    mv_header "🛡 OpenVPN" "$(trx 'Servidor UDP · easy-rsa PKI · user/pass')" "v1"
    movivip_contacts 2>/dev/null || true

    echo -e " Estado      : $STATUS"
    echo -e " Puerto      : UDP $OVPN_PORT"
    echo -e " Usuarios    : $( [[ -f "$OVPN_PASSWD" ]] && wc -l < "$OVPN_PASSWD" || echo 0 )"

    echo ""

    if [[ "$OPENVPN" == "ON" ]]; then
        LBL=("Desinstalar OpenVPN" "Agregar Usuario" "Eliminar Usuario" "Listar Usuarios" "Reiniciar Servicio" "Ver Estado" "Ver Datos de Conexión")
    else
        LBL=("Instalar OpenVPN")
    fi
    SEL=$(nav_pick "► Opción:" "${LBL[@]}" "↩ Regresar") || SEL=0
    [[ $SEL -eq $((${#LBL[@]}+1)) ]] && SEL=0
    OP="$SEL"

    case "$OP" in

        1)
            if [[ "$OPENVPN" == "ON" ]]; then
                remove_openvpn
            else
                install_openvpn
            fi
        ;;

        2)
            [[ "$OPENVPN" == "ON" ]] && add_user
        ;;

        3)
            [[ "$OPENVPN" == "ON" ]] && remove_user
        ;;

        4)
            [[ "$OPENVPN" == "ON" ]] && list_users
        ;;

        5)
            [[ "$OPENVPN" == "ON" ]] && restart_openvpn
        ;;

        6)
            [[ "$OPENVPN" == "ON" ]] && status_openvpn
        ;;

        7)
            [[ "$OPENVPN" == "ON" ]] && show_info
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