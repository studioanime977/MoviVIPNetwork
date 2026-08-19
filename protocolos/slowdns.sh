#!/bin/bash

#==================================================
# MoviVIP Network Premium
# SlowDNS + DNSDist Manager
# Compatible:
# â€¢ HTTP Injector
# â€¢ HTTP Custom
# â€¢ UDP Custom
# â€¢ TLS Tunnel
#==================================================

BASE="/etc/movivip"
CONFIG="$BASE/config.conf"

[[ -f "$CONFIG" ]] || {
    echo "âŒ No existe $CONFIG"
    exit 1
}

source "$CONFIG"

# Cargar idioma
if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)"
fi

# ðŸ”‘ GATE DE LICENCIA â€” validaciÃ³n EN VIVO contra Firebase
bash /etc/movivip/check-licencia.sh || exit 1

CYAN="\e[1;96m"
GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
WHITE="\e[1;97m"
RESET="\e[0m"

SERVICE="slowdns"
DNSDIST="dnsdist"

DIR="/etc/slowdns"

BIN="/usr/bin/slowdns-server"

PUBKEY="$DIR/server.pub"
PRIVKEY="$DIR/server.key"

DOMAIN_FILE="$DIR/domain.conf"

DNS_PORT="53"
SLOWDNS_PORT="5300"

STATUS=""
#==================================================
# Instalar dependencias
#==================================================

install_dependencies(){

    echo "ðŸ“¦ Instalando dependencias..."

    apt update -y

    apt install -y \
        curl \
        wget \
        dnsdist \
        iptables \
        dnsutils \
        ca-certificates

    mkdir -p "$DIR"

}

#==================================================
# Descargar SlowDNS Server
#==================================================

install_slowdns_binary(){

    ARCH=$(uname -m)

    case "$ARCH" in
        x86_64)
            BIN_NAME="dnstt-server-linux-amd64"
        ;;
        aarch64|arm64)
            BIN_NAME="dnstt-server-linux-arm64"
        ;;
        i386|i686)
            BIN_NAME="dnstt-server-linux-386"
        ;;
        *)
            echo "âŒ Arquitectura no soportada: $ARCH"
            return 1
        ;;
    esac

    MIRRORS=(
        "https://dnstt.network/$BIN_NAME"
        "https://github.com/bugfloyd/dnstt-deploy/raw/main/bin/$BIN_NAME"
        "https://raw.githubusercontent.com/Dan3651/scripts/main/slowdns-server"
    )

    echo ""
    echo "â¬‡ï¸ Descargando SlowDNS Server..."

    if [[ -x "$BIN" ]]; then
        echo "âœ… SlowDNS Server ya existe."
        return 0
    fi

    rm -f "$BIN"

    SUCCESS=0

    for URL in "${MIRRORS[@]}"
    do
        echo "ðŸŒ Probando: $URL"

        if curl -L -k -s -f "$URL" -o "$BIN"; then

            chmod +x "$BIN"

            if "$BIN" -h >/dev/null 2>&1; then
                SUCCESS=1
                break
            fi
        fi

        rm -f "$BIN"

    done

    if [[ $SUCCESS -eq 0 ]]; then
        echo "âŒ No fue posible descargar SlowDNS Server."
        return 1
    fi

    echo "âœ… SlowDNS Server instalado."

}

#==================================================
# Generar claves
#==================================================

generate_keys(){

    echo "ðŸ”‘ Generando claves..."

    if [[ ! -f "$PUBKEY" || ! -f "$PRIVKEY" ]]; then

        "$BIN" \
            -gen-key \
            -privkey-file "$PRIVKEY" \
            -pubkey-file "$PUBKEY"

    fi

}
#==================================================
# Configurar DNSDist
#==================================================

configure_dnsdist(){

    echo "âš™ï¸ Configurando DNSDist..."

    DOMAIN=$(cat "$DOMAIN_FILE")

    mkdir -p /etc/dnsdist

    cat > /etc/dnsdist/dnsdist.conf <<EOF
-- MoviVIP Network Premium

setLocal("0.0.0.0:5380")
addLocal("[::]:5380")

addACL("0.0.0.0/0")
addACL("::/0")

newServer({
    address="127.0.0.1:5300",
    name="slowdns",
    pool="slowdns"
})

addAction(
    RegexRule("$(echo "$DOMAIN" | sed 's/\./\\\\./g')"),
    PoolAction("slowdns")
)
EOF

if ! dnsdist --check-config >/dev/null 2>&1; then
    echo "âŒ Error en dnsdist.conf"
    dnsdist --check-config
    return 1
fi
    systemctl daemon-reload

    systemctl enable dnsdist >/dev/null 2>&1

}
#==================================================
# Crear servicio SlowDNS
#==================================================

create_slowdns_service(){

    DOMAIN=$(cat "$DOMAIN_FILE")

    cat > /etc/systemd/system/slowdns.service <<SVCEOF
[Unit]
Description=MoviVIP SlowDNS Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$DIR
ExecStart=$BIN -udp :5300 -privkey-file $PRIVKEY $DOMAIN 127.0.0.1:22
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SVCEOF

    systemctl daemon-reload
    systemctl enable slowdns

    echo "âœ… Servicio slowdns.service creado."

}

#==================================================
# Abrir puerto DNS
#==================================================

open_dns_port(){

    echo "ðŸ›¡ Configurando reglas DNS..."

    # Liberar puerto 53 de systemd-resolved si lo estÃ¡ usando
    if systemctl is-active --quiet systemd-resolved; then
        echo "âš ï¸ Deteniendo systemd-resolved para liberar puerto 53..."
        systemctl stop systemd-resolved
        systemctl disable systemd-resolved
        # Configurar resolv.conf para usar DNS directo
        rm -f /etc/resolv.conf
        echo "nameserver 8.8.8.8" > /etc/resolv.conf
        echo "nameserver 1.1.1.1" >> /etc/resolv.conf
    fi

    # Limpiar reglas antiguas IPv4
    while iptables -t nat -C PREROUTING \
        -p udp --dport 53 \
        -j REDIRECT --to-ports 5380 2>/dev/null
    do
        iptables -t nat -D PREROUTING \
            -p udp --dport 53 \
            -j REDIRECT --to-ports 5380
    done

    # Limpiar reglas antiguas IPv6
    while ip6tables -t nat -C PREROUTING \
        -p udp --dport 53 \
        -j REDIRECT --to-ports 5380 2>/dev/null
    do
        ip6tables -t nat -D PREROUTING \
            -p udp --dport 53 \
            -j REDIRECT --to-ports 5380
    done

    # Regla IPv4: REDIRECT todo UDP 53 â†’ 5380 (dnsdist)
    iptables -t nat -I PREROUTING 1 \
        -p udp \
        --dport 53 \
        -j REDIRECT \
        --to-ports 5380

    # Regla IPv6: REDIRECT todo UDP 53 â†’ 5380 (dnsdist)
    ip6tables -t nat -I PREROUTING 1 \
        -p udp \
        --dport 53 \
        -j REDIRECT \
        --to-ports 5380

    echo "âœ… Reglas DNS aplicadas (UDP 53 â†’ 5380)."

}
#==================================================
# Instalar SlowDNS
#==================================================

install_slowdns(){

    clear

    echo -e "${CYAN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${RESET}"
    echo -e "${WHITE}        ðŸš€ INSTALAR SLOWDNS${RESET}"
    echo -e "${CYAN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${RESET}"
    echo ""

    read -rp "ðŸŒ Dominio NS (Ej: ns.midominio.com): " DOMAIN

    [[ -z "$DOMAIN" ]] && {
        echo "âŒ Dominio invÃ¡lido."
        sleep 2
        return
    }

    install_dependencies || return

    install_slowdns_binary || return

    # Abrir puertos 53/5300/5380 UDP + NAT (salida a internet)
    if [[ -f "$BASE/herramientas/openports.sh" ]]; then
        source "$BASE/herramientas/openports.sh"
        open_ports "UDP:53,5300,5380"
    else
        sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1
        for P in 53 5300 5380; do
            iptables -C INPUT -p udp --dport "$P" -j ACCEPT 2>/dev/null \
                || iptables -A INPUT -p udp --dport "$P" -j ACCEPT
        done
        DEV=$(ip -4 route show default | awk '{print $5}' | head -1)
        [[ -n "$DEV" ]] && {
            iptables -t nat -C POSTROUTING -o "$DEV" -j MASQUERADE 2>/dev/null \
                || iptables -t nat -A POSTROUTING -o "$DEV" -j MASQUERADE
        }
    fi

    mkdir -p "$DIR"

    echo "$DOMAIN" > "$DOMAIN_FILE"

    generate_keys || return

    configure_dnsdist
systemctl restart dnsdist

sleep 1
    create_slowdns_service

    open_dns_port

    echo ""
    echo "ðŸ”„ Iniciando servicios..."

    systemctl daemon-reload

systemctl enable dnsdist >/dev/null 2>&1
systemctl enable slowdns >/dev/null 2>&1

# Reiniciar dnsdist primero
systemctl restart dnsdist

sleep 2

# Verificar que dnsdist quedÃ³ activo
if ! systemctl is-active --quiet dnsdist; then
    echo "âŒ dnsdist no pudo iniciar."
    journalctl -u dnsdist -n 20 --no-pager
    return 1
fi

# Iniciar SlowDNS
systemctl restart slowdns

sleep 2

# Verificar SlowDNS
if ! systemctl is-active --quiet slowdns; then
    echo "âŒ SlowDNS no pudo iniciar."
    journalctl -u slowdns -n 20 --no-pager
    return 1
fi

    sleep 3

    if systemctl is-active --quiet dnsdist && \
       systemctl is-active --quiet slowdns
    then

        sed -i '/^SLOWDNS=/d' "$CONFIG"
        echo "SLOWDNS=ON" >> "$CONFIG"

        source "$CONFIG"

        PUBKEY_CONTENT=$(cat "$PUBKEY")

        echo ""
        echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
        echo "      âœ… SLOWDNS INSTALADO"
        echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
        echo ""
        echo "ðŸŒ Dominio NS : $(cat "$DOMAIN_FILE")"
        echo ""
        echo "ðŸ”‘ Public Key :"
        echo "$PUBKEY_CONTENT"
        echo ""
        echo "ðŸŒ DNS Puerto : 53"
        echo "ðŸŒ DNSTT Puerto: 5300"
        echo ""
        echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
        echo "  ðŸ“‹ CONFIGURACIÃ“N DNS REQUERIDA"
        echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
        echo ""
        echo "  Tu dominio debe apuntar DIRECTAMENTE"
        echo "  al VPS (sin proxy Cloudflare):"
        echo ""
        echo "  1. Crea un registro NS:"
        echo "     $(cat "$DOMAIN_FILE" | cut -d. -f1) â†’ $(hostname -I | awk '{print $1}')"
        echo ""
        echo "  2. Crea un registro A:"
        echo "     $(cat "$DOMAIN_FILE") â†’ $(hostname -I | awk '{print $1}')"
        echo ""
        echo "  3. En Cloudflare, desactiva el proxy"
        echo "     (nube gris, NO naranja) para este"
        echo "     subdominio."
        echo ""
        echo "  âš ï¸  Sin esto, SlowDNS NO funcionarÃ¡."
        echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
        echo ""
        echo "ðŸ“Œ Para asignar puertos a usuarios"
        echo "   usar el formato: 1-PUERTO"
        echo "   Ejemplo: 1-5300"
        echo ""

    else

        echo ""
        echo "âŒ Error iniciando SlowDNS"
        echo ""

        systemctl status slowdns --no-pager
        echo ""
        systemctl status dnsdist --no-pager

    fi

    sleep 4

}
#==================================================
# Eliminar SlowDNS
#==================================================

remove_slowdns(){

    clear

    echo -e "${CYAN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${RESET}"
    echo -e "${WHITE}        ðŸ—‘ ELIMINAR SLOWDNS${RESET}"
    echo -e "${CYAN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${RESET}"
    echo ""

    read -rp "Â¿Eliminar SlowDNS? (s/n): " R

    [[ ! "$R" =~ ^[Ss]$ ]] && return

    systemctl stop slowdns 2>/dev/null
    systemctl stop dnsdist 2>/dev/null

    systemctl disable slowdns 2>/dev/null
    systemctl disable dnsdist 2>/dev/null

    rm -f /etc/systemd/system/slowdns.service
    rm -f /etc/dnsdist/dnsdist.conf

    rm -rf "$DIR"

    rm -f "$BIN"

    systemctl daemon-reload

    iptables -t nat -D PREROUTING \
    -p udp \
    --dport 53 \
    -j REDIRECT \
    --to-ports 5380 2>/dev/null

ip6tables -t nat -D PREROUTING \
    -p udp \
    --dport 53 \
    -j REDIRECT \
    --to-ports 5380 2>/dev/null

    sed -i '/^SLOWDNS=/d' "$CONFIG"
    echo "SLOWDNS=OFF" >> "$CONFIG"

    source "$CONFIG"

    echo ""
    echo "âœ… SlowDNS eliminado."

    sleep 3

}

#==================================================
# Reiniciar servicios
#==================================================

restart_slowdns(){

    clear

    echo "ðŸ”„ Reiniciando servicios..."

    systemctl restart dnsdist
    systemctl restart slowdns

    sleep 2

    if systemctl is-active --quiet dnsdist && \
       systemctl is-active --quiet slowdns
    then
        echo ""
        echo "âœ… Servicios activos."
    else
        echo ""
        echo "âŒ Error al reiniciar."
    fi

    sleep 3

}

#==================================================
# Estado
#==================================================

status_slowdns(){

    clear

    echo -e "${CYAN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${RESET}"
    echo -e "${WHITE}         ðŸ“Š ESTADO SLOWDNS${RESET}"
    echo -e "${CYAN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${RESET}"

    echo ""
    systemctl status slowdns --no-pager

    echo ""
    systemctl status dnsdist --no-pager

    echo ""
    echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"

    echo "Puertos abiertos:"
    ss -ulnp | grep -E "53|5300" || true

    echo ""
    echo "Dominio:"
    [[ -f "$DOMAIN_FILE" ]] && cat "$DOMAIN_FILE"

    echo ""
    echo "Public Key:"
    [[ -f "$PUBKEY" ]] && cat "$PUBKEY"

    echo ""
    read -n1 -r -p "Presione una tecla..."

}

#==================================================
# Mostrar Public Key
#==================================================

show_key(){

    clear

    echo -e "${CYAN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${RESET}"
    echo -e "${WHITE}          ðŸ”‘ PUBLIC KEY${RESET}"
    echo -e "${CYAN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${RESET}"
    echo ""

    if [[ -f "$PUBKEY" ]]; then
        cat "$PUBKEY"
    else
        echo "âŒ No existe la Public Key."
    fi

    echo ""
    read -n1 -r -p "Presione una tecla..."

}
#==================================================
# MenÃº Principal
#==================================================

while true
do

    clear

    source "$CONFIG"

    if systemctl is-active --quiet slowdns; then
        STATUS="${GREEN}ðŸŸ¢ ACTIVO${RESET}"
    else
        STATUS="${RED}ðŸ”´ DETENIDO${RESET}"
    fi

    echo -e "${CYAN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${RESET}"
    echo -e "${WHITE}           ðŸŒ SLOWDNS MANAGER${RESET}"
    echo -e "${CYAN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${RESET}"

    echo -e " Estado      : $STATUS"
    echo -e " Puerto DNS  : 53"
    echo -e " DNSTT       : 5300"

    if [[ -f "$DOMAIN_FILE" ]]; then
        echo -e " Dominio NS  : ${YELLOW}$(cat "$DOMAIN_FILE")${RESET}"
    fi

    echo -e "${CYAN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${RESET}"

    if [[ "$SLOWDNS" == "ON" ]]; then

cat <<EOF

 [1] âž® Desinstalar SlowDNS
 [2] âž® Reiniciar Servicios
 [3] âž® Ver Estado
 [4] âž® Ver Public Key

 [0] âž® Regresar

EOF

    else

cat <<EOF

 [1] âž® Instalar SlowDNS

 [0] âž® Regresar

EOF

    fi

    echo -e "${CYAN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${RESET}"

    read -rp " â–º OpciÃ³n: " OP

    case "$OP" in

        1)

            if [[ "$SLOWDNS" == "ON" ]]; then
                remove_slowdns
            else
                install_slowdns
            fi

        ;;

        2)

            [[ "$SLOWDNS" == "ON" ]] && restart_slowdns

        ;;

        3)

            [[ "$SLOWDNS" == "ON" ]] && status_slowdns

        ;;

        4)

            [[ "$SLOWDNS" == "ON" ]] && show_key

        ;;

        0)

            exec bash "$BASE/protocolos/menu.sh"

        ;;

        *)

            echo ""
            echo "âŒ OpciÃ³n invÃ¡lida."
            sleep 2

        ;;

    esac

done
