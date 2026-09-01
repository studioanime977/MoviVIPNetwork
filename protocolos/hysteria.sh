#!/bin/bash

# ── i18n shim (auto) ───────────────────────────────
if ! declare -F trx >/dev/null 2>&1; then trx() { printf '%s' "$1"; }; fi
# ─────────────────────────────────────────────────────────

#==================================================
# MoviVIP Network Premium
# Hysteria V1 Manager (UDP QUIC)
# Basado en udphisteria.sh de KevinTech
# Adaptado a marca MOVIVIPNETWORK
#
# HARDENED:
# • Blindaje anti-DNAT: RETURN rule antes del
#   catch-all UDP Custom (1-65535→9900)
# • Validación anti-colisión de puertos
# • Persistencia iptables automática
# • Comando permanente: menuhy
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

CYAN="\e[1;96m"
GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
WHITE="\e[1;97m"
RESET="\e[0m"

HY_VERSION="v1.3.5"

HY_DIR="/etc/hysteria"
HY_CONFIG="$HY_DIR/config.json"
HY_CERT="$HY_DIR/cert.pem"
HY_KEY="$HY_DIR/key.pem"
HY_BIN="/usr/local/bin/hysteria1"
HY_SERVICE="/etc/systemd/system/hysteria1-server.service"

STATUS=""

#==================================================
# Helpers config.conf
#==================================================

config_get(){

    local KEY="$1"

    grep "^${KEY}=" "$CONFIG" 2>/dev/null \
        | head -n1 | cut -d'=' -f2- | tr -d '"'

}

config_set(){

    local KEY="$1"
    local VALUE="$2"

    sed -i "/^${KEY}=/d" "$CONFIG"
    echo "${KEY}=\"${VALUE}\"" >> "$CONFIG"

}

#==================================================
# Dependencias
#==================================================

install_dependencies(){

    echo "$(trx '📦 Instalando dependencias...')"

    apt update -y

    apt install -y \
        curl \
        wget \
        openssl \
        ca-certificates

    mkdir -p "$HY_DIR"

}

#==================================================
# Descargar binario Hysteria V1
#==================================================

install_hysteria_binary(){

    ARCH=$(uname -m)

    case "$ARCH" in
        x86_64)
            BIN_NAME="hysteria-linux-amd64"
        ;;
        aarch64|arm64)
            BIN_NAME="hysteria-linux-arm64"
        ;;
        armv7l|armv6l)
            BIN_NAME="hysteria-linux-arm"
        ;;
        armv5*|armv4*)
            BIN_NAME="hysteria-linux-armv5"
        ;;
        i386|i686)
            BIN_NAME="hysteria-linux-386"
        ;;
        mipsel|mips64el)
            BIN_NAME="hysteria-linux-mipsle"
        ;;
        s390x)
            BIN_NAME="hysteria-linux-s390x"
        ;;
        *)
            echo "❌ Arquitectura no soportada: $ARCH"
            return 1
        ;;
    esac

    if [[ -x "$HY_BIN" ]]; then
        echo "$(trx '✅ Hysteria ya está instalado.')"
        return 0
    fi

    # Misma fuente que KevinTech multi-script (repo oficial apernet/hysteria)
    GH_URL="https://github.com/apernet/hysteria/releases/download/${HY_VERSION}/${BIN_NAME}"

    # Espejos para redes donde GitHub está bloqueado o limitado
    MIRRORS=(
        "$GH_URL"
        "https://ghproxy.net/$GH_URL"
        "https://gh-proxy.com/$GH_URL"
        "https://ghfast.top/$GH_URL"
        "https://github.moeyy.xyz/$GH_URL"
    )

    echo ""
    echo "⬇️ Descargando Hysteria $HY_VERSION..."

    rm -f "$HY_BIN"

    SUCCESS=0

    for URL in "${MIRRORS[@]}"
    do
        echo "🌐 Probando: $URL"

        if curl -L -s -f --max-time 120 "$URL" -o "$HY_BIN"; then

            chmod +x "$HY_BIN"

            if "$HY_BIN" -v >/dev/null 2>&1; then
                SUCCESS=1
                break
            fi
        fi

        rm -f "$HY_BIN"

    done

    if [[ $SUCCESS -eq 0 ]]; then
        echo "$(trx '❌ No fue posible descargar Hysteria.')"
        return 1
    fi

    echo "$(trx '✅ Hysteria instalado.')"

}

#==================================================
# Generar certificado autofirmado
#==================================================

generate_certificate(){

    local DOMAIN="$1"

    echo "$(trx '🔐 Generando certificado TLS (EC prime256v1)...')"

    openssl ecparam -genkey -name prime256v1 \
        -out "$HY_KEY" >/dev/null 2>&1

    openssl req -new -x509 \
        -days 36500 \
        -nodes \
        -key "$HY_KEY" \
        -out "$HY_CERT" \
        -subj "/CN=${DOMAIN}" >/dev/null 2>&1

    chmod 600 "$HY_KEY"
    chmod 644 "$HY_CERT"

}

#==================================================
# Generar password aleatorio
#==================================================

gen_password(){

    tr -dc 'A-Za-z0-9' </dev/urandom | head -c16

}

#==================================================
# Validar puerto (anti-colisión)
#==================================================

validate_port(){

    local PORT="$1"

    [[ ! "$PORT" =~ ^[0-9]+$ ]] && return 1
    (( PORT < 1024 || PORT > 65535 )) && return 1

    # Puertos reservados del ecosistema MOVIVIP
    case "$PORT" in
        22|53|80|443|2100|5300|5353|5354|5355|5380|5667|7200|7300|9900|8080|8443)
            return 1
        ;;
    esac

    return 0

}

#==================================================
# Firewall + blindaje anti-DNAT
#
# El catch-all del UDP Custom (DNAT udp 1-65535→9900)
# secuestraría el tráfico QUIC de Hysteria. La regla
# RETURN insertada en la posición 1 lo evita.
#==================================================

open_hysteria_port(){

    local PORT="$1"

    echo "$(trx '🛡 Configurando firewall...')"

    # INPUT: aceptar tráfico UDP del puerto
    iptables -C INPUT -p udp --dport "$PORT" -j ACCEPT 2>/dev/null \
        || iptables -A INPUT -p udp --dport "$PORT" -j ACCEPT

    # Anti-DNAT: este puerto NUNCA debe ser capturado por
    # reglas DNAT posteriores (catch-all UDP Custom).
    while iptables -t nat -C PREROUTING \
        -p udp --dport "$PORT" -j RETURN 2>/dev/null
    do
        iptables -t nat -D PREROUTING \
            -p udp --dport "$PORT" -j RETURN
    done
    iptables -t nat -I PREROUTING 1 \
        -p udp --dport "$PORT" -j RETURN

    # UFW (si está activo)
    if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
        ufw allow "$PORT"/udp >/dev/null 2>&1
    fi

    # Persistencia best-effort
    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4 2>/dev/null

    echo "✅ Puerto UDP $PORT abierto y protegido."

}

close_hysteria_port(){

    local PORT="$1"

    [[ -z "$PORT" || ! "$PORT" =~ ^[0-9]+$ ]] && return 0

    iptables -D INPUT -p udp --dport "$PORT" -j ACCEPT 2>/dev/null
    iptables -t nat -D PREROUTING \
        -p udp --dport "$PORT" -j RETURN 2>/dev/null

    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4 2>/dev/null

}

#==================================================
# Crear servicio systemd
#==================================================

create_service(){

cat > "$HY_SERVICE" <<SVCEOF
[Unit]
Description=MoviVIP Hysteria Server
After=network.target

[Service]
Type=simple
User=root
ExecStart=$HY_BIN -config $HY_CONFIG server
Restart=always
RestartSec=3
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
SVCEOF

    systemctl daemon-reload
    systemctl enable hysteria1-server >/dev/null 2>&1

}

#==================================================
# Instalar Hysteria
#==================================================

install_hysteria(){

    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}      🚀 INSTALAR HYSTERIA [UDP]${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    install_dependencies || return

    install_hysteria_binary || return

    # ── Dominio (SNI) ──
    DOMAIN=$(config_get SERVER_DOMAIN)

    if [[ -z "$DOMAIN" ]]; then
        read -rp "$(trx '🌐 Dominio para SNI/Certificado: ')" DOMAIN
        [[ -z "$DOMAIN" ]] && {
            echo "$(trx '❌ Dominio requerido.')"
            sleep 2
            return
        }
        config_set SERVER_DOMAIN "$DOMAIN"
    else
        echo "🌐 Dominio detectado : $DOMAIN"
    fi

    # ── Puerto ──
    echo ""
    read -rp "$(trx '🔌 Puerto UDP [Enter = aleatorio]: ')" HY_PORT

    if [[ -z "$HY_PORT" ]]; then
        while true; do
            HY_PORT=$((RANDOM % 55000 + 10000))
            validate_port "$HY_PORT" && break
        done
        echo "   → Puerto asignado : $HY_PORT"
    else
        if ! validate_port "$HY_PORT"; then
            echo "$(trx '❌ Puerto inválido o reservado por otro servicio.')"
            sleep 3
            return
        fi
    fi

    # ── Credenciales ──
    HY_AUTH=$(gen_password)
    HY_OBFS=$(gen_password)

    # ── Config JSON (formato validado en producción KevinTech) ──
    cat > "$HY_CONFIG" <<EOF
{
"protocol":"udp",
"listen":":${HY_PORT}",
"obfs":"${HY_OBFS}",
"cert":"${HY_CERT}",
"key":"${HY_KEY}",
"alpn":"h3",
"auth":{
"mode":"password",
"config":{
"password":"${HY_AUTH}"
}
}
}
EOF

    generate_certificate "$DOMAIN"

    create_service

    # Comando permanente de acceso directo
    cat > /usr/local/bin/menuhy <<'MHEOF'
#!/bin/bash
bash /etc/movivip/protocolos/hysteria.sh
MHEOF
    chmod +x /usr/local/bin/menuhy

    open_hysteria_port "$HY_PORT"

    echo ""
    echo "$(trx '🔄 Iniciando servicio...')"

    systemctl restart hysteria1-server
    sleep 2

    if systemctl is-active --quiet hysteria1-server; then

        config_set HYSTERIA "ON"
        config_set HYSTERIA_PORT "$HY_PORT"
        config_set HYSTERIA_AUTH "$HY_AUTH"
        config_set HYSTERIA_OBFS "$HY_OBFS"
        source "$CONFIG"

        VPS_IP=$(hostname -I | awk '{print $1}')

        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "$(trx '     ✅ HYSTERIA INSTALADO')"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo " 🌐 IP       : $VPS_IP"
        echo " 🔌 Puerto   : $HY_PORT (UDP)"
        echo " 🔑 Auth     : $HY_AUTH"
        echo " 🎭 Obfs     : $HY_OBFS"
        echo " 📡 SNI      : $DOMAIN"
        echo " 🔒 ALPN     : h3"
        echo "$(trx ' ⚠️ Insecure : true (cert autofirmado)')"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "$(trx ' 📱 HTTP Injector / HTTP Custom:')"
        echo "$(trx '   Protocolo : Hysteria')"
        echo "   Servidor  : $VPS_IP:$HY_PORT"
        echo "   Auth/Pass : $HY_AUTH"
        echo "   Obfs      : $HY_OBFS"
        echo "   SNI       : $DOMAIN"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

    else

        echo ""
        echo "$(trx '❌ Error iniciando Hysteria.')"
        journalctl -u hysteria1-server -n 20 --no-pager

    fi

    sleep 4

}

#==================================================
# Desinstalar
#==================================================

remove_hysteria(){

    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}       🗑 ELIMINAR HYSTERIA${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    read -rp "$(trx '¿Eliminar Hysteria? (s/n): ')" R

    [[ ! "$R" =~ ^[Ss]$ ]] && return

    OLD_PORT=$(config_get HYSTERIA_PORT)

    systemctl stop hysteria1-server 2>/dev/null
    systemctl disable hysteria1-server 2>/dev/null

    rm -f "$HY_SERVICE"
    rm -rf "$HY_DIR"
    rm -f "$HY_BIN"
    rm -f /usr/local/bin/menuhy

    systemctl daemon-reload

    close_hysteria_port "$OLD_PORT"

    config_set HYSTERIA "OFF"
    sed -i '/^HYSTERIA_PORT=/d' "$CONFIG"
    sed -i '/^HYSTERIA_AUTH=/d' "$CONFIG"
    sed -i '/^HYSTERIA_OBFS=/d' "$CONFIG"
    source "$CONFIG"

    echo ""
    echo "$(trx '✅ Hysteria eliminado.')"

    sleep 3

}

#==================================================
# Reiniciar
#==================================================

restart_hysteria(){

    clear

    echo "$(trx '🔄 Reiniciando Hysteria...')"

    systemctl restart hysteria1-server
    sleep 2

    if systemctl is-active --quiet hysteria1-server; then
        echo "$(trx '✅ Servicio activo.')"
    else
        echo "$(trx '❌ Error al reiniciar.')"
        journalctl -u hysteria1-server -n 20 --no-pager
    fi

    sleep 3

}

#==================================================
# Estado
#==================================================

status_hysteria(){

    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}        📊 ESTADO HYSTERIA${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    echo ""
    systemctl status hysteria1-server --no-pager

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "$(trx 'Puerto escuchando:')"
    ss -ulnp | grep hysteria || true

    echo ""
    echo "$(trx 'Reglas firewall:')"
    PORT=$(config_get HYSTERIA_PORT)
    [[ -n "$PORT" ]] && iptables -S INPUT | grep "dport $PORT" || true
    [[ -n "$PORT" ]] && iptables -t nat -S PREROUTING | grep "dport $PORT" || true

    echo ""
    read -n1 -r -p "$(trx 'Presione una tecla...')"

}

#==================================================
# Ver configuración
#==================================================

show_config(){

    clear

    source "$CONFIG"

    VPS_IP=$(hostname -I | awk '{print $1}')

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}      ⚙ CONFIGURACIÓN HYSTERIA${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    echo " 🌐 IP       : $VPS_IP"
    echo " 🔌 Puerto   : ${HYSTERIA_PORT:-N/A} (UDP)"
    echo " 🔑 Auth     : ${HYSTERIA_AUTH:-N/A}"
    echo " 🎭 Obfs     : ${HYSTERIA_OBFS:-N/A}"
    echo " 📡 SNI      : $(config_get SERVER_DOMAIN)"
    echo " 🔒 ALPN     : h3"
    echo ""

    read -n1 -r -p "$(trx 'Presione una tecla...')"

}

#==================================================
# Modificar puerto
#==================================================

change_port(){

    clear

    source "$CONFIG"

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}       🔌 CAMBIAR PUERTO HYSTERIA${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    echo " Puerto actual : ${HYSTERIA_PORT:-N/A}"
    echo ""

    read -rp "$(trx ' Nuevo puerto UDP: ')" NEW_PORT

    if ! validate_port "$NEW_PORT"; then
        echo "$(trx '❌ Puerto inválido o reservado.')"
        sleep 3
        return
    fi

    close_hysteria_port "$(config_get HYSTERIA_PORT)"

    sed -i "s/\"listen\": \":${HYSTERIA_PORT}\"/\"listen\": \":${NEW_PORT}\"/" "$HY_CONFIG"

    open_hysteria_port "$NEW_PORT"

    config_set HYSTERIA_PORT "$NEW_PORT"
    source "$CONFIG"

    systemctl restart hysteria1-server
    sleep 2

    if systemctl is-active --quiet hysteria1-server; then
        echo "✅ Puerto cambiado a $NEW_PORT. Servicio activo."
    else
        echo "$(trx '❌ El servicio no arrancó. Revisa logs.')"
    fi

    sleep 3

}

#==================================================
# Reconfigurar Auth / Obfs (sin reinstalar)
#==================================================

reconfigure_auth(){

    clear

    source "$CONFIG"

    mv_header "🔑 Reconfigurar Credenciales" "$(trx 'Auth y Obfs de Hysteria')" "v6.2"
    movivip_contacts 2>/dev/null || true

    echo " Auth actual : ${HYSTERIA_AUTH:-N/A}"
    echo " Obfs actual : ${HYSTERIA_OBFS:-N/A}"

    echo ""

    SEL=$(nav_pick "► Opción:" "Regenerar Auth" "Regenerar Obfs" "Regenerar Ambos" "↩ Cancelar") || SEL=0
    [[ $SEL -eq 5 ]] && SEL=0
    ROP="$SEL"

    local NEW_AUTH="${HYSTERIA_AUTH}"
    local NEW_OBFS="${HYSTERIA_OBFS}"

    case "$ROP" in
        1) NEW_AUTH=$(gen_password) ;;
        2) NEW_OBFS=$(gen_password) ;;
        3)
            NEW_AUTH=$(gen_password)
            NEW_OBFS=$(gen_password)
        ;;
        *) return ;;
    esac

    sed -i "s/\"password\":\"[^\"]*\"/\"password\":\"$NEW_AUTH\"/" "$HY_CONFIG"
    sed -i "s/\"obfs\":\"[^\"]*\"/\"obfs\":\"$NEW_OBFS\"/" "$HY_CONFIG"

    config_set HYSTERIA_AUTH "$NEW_AUTH"
    config_set HYSTERIA_OBFS "$NEW_OBFS"
    source "$CONFIG"

    systemctl restart hysteria1-server
    sleep 2

    echo ""
    if systemctl is-active --quiet hysteria1-server; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "$(trx '      ✅ CREDENCIALES ACTUALIZADAS')"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo " 🔑 Nuevo Auth : $NEW_AUTH"
        echo " 🎭 Nuevo Obfs : $NEW_OBFS"
        echo ""
    else
        echo "$(trx '❌ El servicio no arrancó. Revisa logs.')"
    fi

    sleep 3

}

#==================================================
# Logs
#==================================================

show_logs(){

    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}         📜 LOGS HYSTERIA${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    journalctl -u hysteria1-server -n 50 --no-pager

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

    if systemctl is-active --quiet hysteria1-server; then
        STATUS="${GREEN}🟢 ACTIVO${RESET}"
    else
        STATUS="${RED}🔴 DETENIDO${RESET}"
    fi

    mv_header "🚀 Hysteria Manager" "$(trx 'Protocolo QUIC / HTTP3 · alta velocidad')" "v6.2"
    movivip_contacts 2>/dev/null || true

    echo -e " Estado      : $STATUS"
    echo -e " Puerto UDP  : ${YELLOW}${HYSTERIA_PORT:---}${RESET}"
    echo -e "$(trx ' Protocolo   : QUIC / HTTP3')"

    echo ""

    if [[ "$HYSTERIA" == "ON" ]]; then
        LBL=("Desinstalar Hysteria" "Reiniciar Servicio" "Ver Estado" "Ver Configuración" "Cambiar Puerto" "Cambiar Auth/Obfs" "Ver Logs")
    else
        LBL=("Instalar Hysteria")
    fi
    SEL=$(nav_pick "► Opción:" "${LBL[@]}" "↩ Regresar") || SEL=0
    [[ $SEL -eq $((${#LBL[@]}+1)) ]] && SEL=0
    OP="$SEL"

    case "$OP" in

        1)

            if [[ "$HYSTERIA" == "ON" ]]; then
                remove_hysteria
            else
                install_hysteria
            fi

        ;;

        2)

            [[ "$HYSTERIA" == "ON" ]] && restart_hysteria

        ;;

        3)

            [[ "$HYSTERIA" == "ON" ]] && status_hysteria

        ;;

        4)

            [[ "$HYSTERIA" == "ON" ]] && show_config

        ;;

        5)

            [[ "$HYSTERIA" == "ON" ]] && change_port

        ;;

        6)

            [[ "$HYSTERIA" == "ON" ]] && reconfigure_auth

        ;;

        7)

            [[ "$HYSTERIA" == "ON" ]] && show_logs

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
