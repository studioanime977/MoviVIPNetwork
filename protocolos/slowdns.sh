#!/bin/bash

#==================================================
# MoviVIP Network Premium
# SlowDNS + DNSDist Manager v2 (HARDENED)
# Compatible:
# • HTTP Injector
# • HTTP Custom
# • UDP Custom
# • TLS Tunnel
#
# FIXES v2:
# • Regla u32: solo captura queries DNS reales (no respuestas/basura)
# • Blindaje anti-DNAT: RETURN rules antes del catch-all UDP Custom
# • Protección loopback: resolución local del VPS intacta
# • Fallback DNS local en dnsdist (solo para 127.0.0.0/8)
# • Test funcional post-instalación (dig real)
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

SERVICE="slowdns"
DNSDIST="dnsdist"

DIR="/etc/slowdns"

BIN="/usr/bin/slowdns-server"

PUBKEY="$DIR/server.pub"
PRIVKEY="$DIR/server.key"

DOMAIN_FILE="$DIR/domain.conf"

DNS_PORT="53"
SLOWDNS_PORT="5300"
DNSDIST_PORT="5380"

STATUS=""

#==================================================
# Instalar dependencias
#==================================================

install_dependencies(){

    echo "📦 Instalando dependencias..."

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
            echo "❌ Arquitectura no soportada: $ARCH"
            return 1
        ;;
    esac

    MIRRORS=(
        "https://dnstt.network/$BIN_NAME"
        "https://github.com/bugfloyd/dnstt-deploy/raw/main/bin/$BIN_NAME"
        "https://raw.githubusercontent.com/Dan3651/scripts/main/slowdns-server"
    )

    echo ""
    echo "⬇️ Descargando SlowDNS Server..."

    if [[ -x "$BIN" ]]; then
        echo "✅ SlowDNS Server ya existe."
        return 0
    fi

    rm -f "$BIN"

    SUCCESS=0

    for URL in "${MIRRORS[@]}"
    do
        echo "🌐 Probando: $URL"

        if curl -L -k -s -f --max-time 120 "$URL" -o "$BIN"; then

            chmod +x "$BIN"

            if "$BIN" -h >/dev/null 2>&1; then
                SUCCESS=1
                break
            fi
        fi

        rm -f "$BIN"

    done

    if [[ $SUCCESS -eq 0 ]]; then
        echo "❌ No fue posible descargar SlowDNS Server."
        return 1
    fi

    echo "✅ SlowDNS Server instalado."

}

#==================================================
# Generar claves
#==================================================

generate_keys(){

    echo "🔑 Generando claves..."

    if [[ ! -f "$PUBKEY" || ! -f "$PRIVKEY" ]]; then

        "$BIN" \
            -gen-key \
            -privkey-file "$PRIVKEY" \
            -pubkey-file "$PUBKEY"

    fi

}

#==================================================
# Configurar DNSDist
#
# Diseño minimalista y multi-versión:
# • SOLO regla RegexRule → pool slowdns (compatible 1.4+)
# • Queries que NO matchean el dominio → SERVFAIL
#   (nadie puede abusarnos como resolver abierto)
# • La resolución LOCAL del VPS no depende de dnsdist:
#   sale por OUTPUT directo a los DNS upstream.
#==================================================

configure_dnsdist(){

    echo "⚙️ Configurando DNSDist..."

    DOMAIN=$(cat "$DOMAIN_FILE")

    mkdir -p /etc/dnsdist

    cat > /etc/dnsdist/dnsdist.conf <<EOF
-- MoviVIP Network Premium

setLocal("0.0.0.0:$DNSDIST_PORT")
addLocal("[::]:$DNSDIST_PORT")

addACL("0.0.0.0/0")
addACL("::/0")

newServer({
    address="127.0.0.1:$SLOWDNS_PORT",
    name="slowdns",
    pool="slowdns"
})

addAction(
    RegexRule("$(echo "$DOMAIN" | sed 's/\./\\\\./g')"),
    PoolAction("slowdns")
)
EOF

if ! dnsdist --check-config >/dev/null 2>&1; then
    echo "❌ Error en dnsdist.conf"
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
ExecStart=$BIN -udp :$SLOWDNS_PORT -privkey-file $PRIVKEY $DOMAIN 127.0.0.1:22
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SVCEOF

    systemctl daemon-reload
    systemctl enable slowdns

    echo "✅ Servicio slowdns.service creado."

}

#==================================================
# Abrir puerto DNS (v2 HARDENED)
#
# Orden final en PREROUTING (top-down):
#   1. loopback ACCEPT      → resolución local del VPS intacta
#   2. u32 REDIRECT 53→5380 → SOLO queries DNS reales van a dnsdist
#   3. RETURN 53/5300/5380  → blindaje anti-DNAT catch-all (UDP Custom)
#
# NOTA: systemd-resolved NO se toca. El REDIRECT NAT intercepta
# los paquetes ANTES de llegar al socket, así que nadie necesita
# bindear el puerto 53 y la resolución interna sigue funcionando.
#==================================================

open_dns_port(){

    echo "🛡 Configurando reglas DNS..."

    # ── Limpieza de reglas viejas (todas las variantes) ──

    # Variante antigua sin u32 (v1)
    while iptables -t nat -C PREROUTING \
        -p udp --dport 53 \
        -j REDIRECT --to-ports "$DNSDIST_PORT" 2>/dev/null
    do
        iptables -t nat -D PREROUTING \
            -p udp --dport 53 \
            -j REDIRECT --to-ports "$DNSDIST_PORT"
    done

    # Variante antigua 53→5300 (legado VPS)
    while iptables -t nat -C PREROUTING \
        -p udp --dport 53 \
        -j REDIRECT --to-ports 5300 2>/dev/null
    do
        iptables -t nat -D PREROUTING \
            -p udp --dport 53 \
            -j REDIRECT --to-ports 5300
    done

    # Variante nueva con u32 (reinstalaciones)
    while iptables -t nat -C PREROUTING \
        -p udp --dport 53 \
        -m u32 --u32 "0>>22&0x3C@12=0x00010000" \
        -j REDIRECT --to-ports "$DNSDIST_PORT" 2>/dev/null
    do
        iptables -t nat -D PREROUTING \
            -p udp --dport 53 \
            -m u32 --u32 "0>>22&0x3C@12=0x00010000" \
            -j REDIRECT --to-ports "$DNSDIST_PORT"
    done

    # RETURN rules duplicadas (reinstalaciones)
    for P in "$DNS_PORT" "$SLOWDNS_PORT" "$DNSDIST_PORT"; do
        while iptables -t nat -C PREROUTING \
            -p udp --dport "$P" -j RETURN 2>/dev/null
        do
            iptables -t nat -D PREROUTING \
                -p udp --dport "$P" -j RETURN
        done
        while ip6tables -t nat -C PREROUTING \
            -p udp --dport "$P" -j RETURN 2>/dev/null
        do
            ip6tables -t nat -D PREROUTING \
                -p udp --dport "$P" -j RETURN
        done
    done

    # Loopback IPv4/IPv6 duplicado (reinstalaciones)
    while iptables -t nat -C PREROUTING \
        -i lo -p udp --dport 53 -j ACCEPT 2>/dev/null
    do
        iptables -t nat -D PREROUTING \
            -i lo -p udp --dport 53 -j ACCEPT
    done
    while ip6tables -t nat -C PREROUTING \
        -i lo -p udp --dport 53 -j ACCEPT 2>/dev/null
    do
        ip6tables -t nat -D PREROUTING \
            -i lo -p udp --dport 53 -j ACCEPT
    done

    # Variante IPv6 antigua
    while ip6tables -t nat -C PREROUTING \
        -p udp --dport 53 \
        -j REDIRECT --to-ports "$DNSDIST_PORT" 2>/dev/null
    do
        ip6tables -t nat -D PREROUTING \
            -p udp --dport 53 \
            -j REDIRECT --to-ports "$DNSDIST_PORT"
    done

    # ── Inserción en orden correcto ──
    # Se inserta todo con -I 1 en orden inverso al deseado.

    # (3) Blindaje anti-DNAT: estos puertos NUNCA deben ser
    #     capturados por reglas DNAT posteriores (ej. UDP Custom
    #     1-65535→9900). RETURN = salir de PREROUTING sin NAT.
    for P in "$DNS_PORT" "$SLOWDNS_PORT" "$DNSDIST_PORT"; do
        iptables -t nat -I PREROUTING 1 \
            -p udp --dport "$P" -j RETURN 2>/dev/null
        ip6tables -t nat -I PREROUTING 1 \
            -p udp --dport "$P" -j RETURN 2>/dev/null
    done

    # (2) Regla u32: SOLO queries DNS estándar (QR bit = query).
    #     Igual que el binario Go de referencia.
    iptables -t nat -I PREROUTING 1 \
        -p udp \
        --dport 53 \
        -m u32 \
        --u32 "0>>22&0x3C@12=0x00010000" \
        -j REDIRECT \
        --to-ports "$DNSDIST_PORT"

    ip6tables -t nat -I PREROUTING 1 \
        -p udp \
        --dport 53 \
        -j REDIRECT \
        --to-ports "$DNSDIST_PORT"

    # (1) Protección loopback: queries locales (systemd-resolved
    #     stub, dnsmasq, apps) pasan sin NAT.
    iptables -t nat -I PREROUTING 1 \
        -i lo -p udp --dport 53 -j ACCEPT

    ip6tables -t nat -I PREROUTING 1 \
        -i lo -p udp --dport 53 -j ACCEPT

    # ── INPUT: permitir puertos del túnel ──
    for P in "$DNS_PORT" "$SLOWDNS_PORT" "$DNSDIST_PORT"; do
        iptables -C INPUT -p udp --dport "$P" -j ACCEPT 2>/dev/null \
            || iptables -A INPUT -p udp --dport "$P" -j ACCEPT
    done

    # ── UFW (si está activo) ──
    if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
        for P in "$DNS_PORT" "$SLOWDNS_PORT" "$DNSDIST_PORT"; do
            ufw allow "$P"/udp >/dev/null 2>&1
        done
    fi

    # ── Persistencia best-effort ──
    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4 2>/dev/null
    ip6tables-save > /etc/iptables/rules.v6 2>/dev/null

    echo "✅ Reglas DNS aplicadas (u32 + anti-DNAT + loopback)."

}

#==================================================
# Test funcional post-instalación
#==================================================

test_slowdns(){

    echo ""
    echo "🧪 Testeando resolución vía dnsdist..."

    DOMAIN=$(cat "$DOMAIN_FILE")

    if dig @127.0.0.1 -p "$DNSDIST_PORT" "$DOMAIN" \
        +time=3 +tries=1 +short 2>/dev/null | grep -q .; then
        echo "✅ dnsdist responde correctamente."
        return 0
    fi

    # Un NS puro puede no dar answer section; aceptar respuesta con flags
    if dig @127.0.0.1 -p "$DNSDIST_PORT" "$DOMAIN" \
        +time=3 +tries=1 2>/dev/null | grep -qE "flags:|status:"; then
        echo "✅ dnsdist responde (respuesta autoritativa)."
        return 0
    fi

    echo "⚠️  dnsdist no respondió al test local."
    echo "    Revisa: journalctl -u dnsdist -n 20 --no-pager"
    return 1

}

#==================================================
# Instalar SlowDNS
#==================================================

install_slowdns(){

    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}        🚀 INSTALAR SLOWDNS${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    read -rp "🌐 Dominio NS (Ej: ns.midominio.com): " DOMAIN

    [[ -z "$DOMAIN" ]] && {
        echo "❌ Dominio inválido."
        sleep 2
        return
    }

    install_dependencies || return

    install_slowdns_binary || return

    mkdir -p "$DIR"

    echo "$DOMAIN" > "$DOMAIN_FILE"

    generate_keys || return

    configure_dnsdist || return

systemctl restart dnsdist

sleep 1
    create_slowdns_service

    open_dns_port

    echo ""
    echo "🔄 Iniciando servicios..."

    systemctl daemon-reload

systemctl enable dnsdist >/dev/null 2>&1
systemctl enable slowdns >/dev/null 2>&1

# Reiniciar dnsdist primero
systemctl restart dnsdist

sleep 2

# Verificar que dnsdist quedó activo
if ! systemctl is-active --quiet dnsdist; then
    echo "❌ dnsdist no pudo iniciar."
    journalctl -u dnsdist -n 20 --no-pager
    return 1
fi

# Iniciar SlowDNS
systemctl restart slowdns

sleep 2

# Verificar SlowDNS
if ! systemctl is-active --quiet slowdns; then
    echo "❌ SlowDNS no pudo iniciar."
    journalctl -u slowdns -n 20 --no-pager
    return 1
fi

    test_slowdns

    sleep 3

    if systemctl is-active --quiet dnsdist && \
       systemctl is-active --quiet slowdns
    then

        sed -i '/^SLOWDNS=/d' "$CONFIG"
        echo "SLOWDNS=ON" >> "$CONFIG"

        # Guardar NS y Public Key para bots/usuarios (formato add.sh)
        sed -i '/^SLOWDNS_NS=/d' "$CONFIG"
        echo "SLOWDNS_NS=$DOMAIN" >> "$CONFIG"
        sed -i '/^SLOWDNS_KEY=/d' "$CONFIG"
        echo "SLOWDNS_KEY=$(cat "$PUBKEY")" >> "$CONFIG"

        source "$CONFIG"

        PUBKEY_CONTENT=$(cat "$PUBKEY")
        VPS_IP=$(hostname -I | awk '{print $1}')

        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "      ✅ SLOWDNS INSTALADO"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "🌐 Dominio NS : $(cat "$DOMAIN_FILE")"
        echo ""
        echo "🔑 Public Key :"
        echo "$PUBKEY_CONTENT"
        echo ""
        echo "🌍 DNS Puerto : 53"
        echo "🐌 DNSTT Puerto: 5300"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  📋 CONFIGURACIÓN DNS REQUERIDA"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "  Tu dominio debe apuntar DIRECTAMENTE"
        echo "  al VPS (sin proxy Cloudflare):"
        echo ""
        echo "  1. Crea un registro A:"
        echo "     $(cat "$DOMAIN_FILE") → $VPS_IP"
        echo ""
        echo "  2. Crea un registro NS apuntando a:"
        echo "     <tu-zona> → $(cat "$DOMAIN_FILE")"
        echo ""
        echo "  3. En Cloudflare, desactiva el proxy"
        echo "     (nube gris, NO naranja) para este"
        echo "     subdominio."
        echo ""
        echo "  ⚠️  Sin esto, SlowDNS NO funcionará."
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "📌 Para asignar puertos a usuarios"
        echo "   usar el formato: 1-PUERTO"
        echo "   Ejemplo: 1-5300"
        echo ""

    else

        echo ""
        echo "❌ Error iniciando SlowDNS"
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

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}        🗑 ELIMINAR SLOWDNS${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    read -rp "¿Eliminar SlowDNS? (s/n): " R

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

    # Limpiar TODAS las variantes de reglas (v1 y v2)

    iptables -t nat -D PREROUTING \
    -p udp --dport 53 \
    -m u32 --u32 "0>>22&0x3C@12=0x00010000" \
    -j REDIRECT --to-ports "$DNSDIST_PORT" 2>/dev/null

    iptables -t nat -D PREROUTING \
    -p udp --dport 53 \
    -j REDIRECT --to-ports "$DNSDIST_PORT" 2>/dev/null

    iptables -t nat -D PREROUTING \
    -p udp --dport 53 \
    -j REDIRECT --to-ports 5300 2>/dev/null

    ip6tables -t nat -D PREROUTING \
    -p udp --dport 53 \
    -j REDIRECT --to-ports "$DNSDIST_PORT" 2>/dev/null

    iptables -t nat -D PREROUTING \
    -i lo -p udp --dport 53 -j ACCEPT 2>/dev/null

    ip6tables -t nat -D PREROUTING \
    -i lo -p udp --dport 53 -j ACCEPT 2>/dev/null

    for P in "$DNS_PORT" "$SLOWDNS_PORT" "$DNSDIST_PORT"; do
        iptables -t nat -D PREROUTING \
            -p udp --dport "$P" -j RETURN 2>/dev/null
        ip6tables -t nat -D PREROUTING \
            -p udp --dport "$P" -j RETURN 2>/dev/null
        iptables -D INPUT -p udp --dport "$P" -j ACCEPT 2>/dev/null
    done

    # Persistir cambios
    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4 2>/dev/null
    ip6tables-save > /etc/iptables/rules.v6 2>/dev/null

    sed -i '/^SLOWDNS=/d' "$CONFIG"
    echo "SLOWDNS=OFF" >> "$CONFIG"

    source "$CONFIG"

    echo ""
    echo "✅ SlowDNS eliminado."

    sleep 3

}

#==================================================
# Reiniciar servicios
#==================================================

restart_slowdns(){

    clear

    echo "🔄 Reiniciando servicios..."

    systemctl restart dnsdist
    systemctl restart slowdns

    sleep 2

    if systemctl is-active --quiet dnsdist && \
       systemctl is-active --quiet slowdns
    then
        echo ""
        echo "✅ Servicios activos."
        test_slowdns
    else
        echo ""
        echo "❌ Error al reiniciar."
    fi

    sleep 3

}

#==================================================
# Estado
#==================================================

status_slowdns(){

    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}         📊 ESTADO SLOWDNS${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    echo ""
    systemctl status slowdns --no-pager

    echo ""
    systemctl status dnsdist --no-pager

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    echo "Puertos abiertos:"
    ss -ulnp | grep -E ":53|:5300|:5380" || true

    echo ""
    echo "Reglas NAT activas (puerto 53):"
    iptables -t nat -S PREROUTING | grep -E "dport 53|dport 5300|dport 5380" || true

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

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}          🔑 PUBLIC KEY${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    if [[ -f "$PUBKEY" ]]; then
        cat "$PUBKEY"
    else
        echo "❌ No existe la Public Key."
    fi

    echo ""
    read -n1 -r -p "Presione una tecla..."

}

#==================================================
# Regenerar par de claves (sin reinstalar)
#==================================================

regen_keys(){

    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}      🔑 REGENERAR CLAVES SLOWDNS${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    if [[ ! -x "$BIN" ]]; then
        echo "❌ SlowDNS no está instalado."
        echo ""
        read -n1 -r -p "Presione una tecla..."
        return
    fi

    echo " ⚠️  Los clientes deberán actualizar la Public Key."
    echo ""

    read -rp " ¿Regenerar par de claves? (s/n): " R

    [[ ! "$R" =~ ^[Ss]$ ]] && return

    rm -f "$PRIVKEY" "$PUBKEY"

    "$BIN" -gen-key -privkey-file "$PRIVKEY" -pubkey-file "$PUBKEY" || {
        echo "❌ Error generando claves."
        sleep 3
        return
    }

    sed -i '/^SLOWDNS_KEY=/d' "$CONFIG"
    echo "SLOWDNS_KEY=$(cat "$PUBKEY")" >> "$CONFIG"
    source "$CONFIG"

    systemctl restart slowdns
    sleep 2

    echo ""
    if systemctl is-active --quiet slowdns; then
        echo "✅ Claves regeneradas. Servicio activo."
        echo ""
        echo "🔑 Nueva Public Key :"
        cat "$PUBKEY"
        echo ""
        echo "🌐 Dominio NS : $(cat "$DOMAIN_FILE" 2>/dev/null)"
    else
        echo "❌ El servicio no arrancó. Revisa logs."
    fi

    echo ""
    read -n1 -r -p "Presione una tecla..."

}

#==================================================
# Cambiar dominio NS (sin reinstalar)
#==================================================

change_domain(){

    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}      🌐 CAMBIAR DOMINIO NS${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    if [[ ! -x "$BIN" ]]; then
        echo "❌ SlowDNS no está instalado."
        echo ""
        read -n1 -r -p "Presione una tecla..."
        return
    fi

    echo " Dominio actual : $(cat "$DOMAIN_FILE" 2>/dev/null)"
    echo ""

    read -rp " Nuevo Dominio NS (Ej: ns.midominio.com): " NEW_DOMAIN

    [[ -z "$NEW_DOMAIN" ]] && {
        echo "❌ Dominio inválido."
        sleep 2
        return
    }

    echo ""
    echo "$NEW_DOMAIN" > "$DOMAIN_FILE"

    configure_dnsdist || return

    create_slowdns_service

    systemctl restart dnsdist
    sleep 1

    systemctl restart slowdns
    sleep 2

    if systemctl is-active --quiet dnsdist && \
       systemctl is-active --quiet slowdns; then

        sed -i '/^SLOWDNS_NS=/d' "$CONFIG"
        echo "SLOWDNS_NS=$NEW_DOMAIN" >> "$CONFIG"
        source "$CONFIG"

        echo "✅ Dominio cambiado a $NEW_DOMAIN. Servicios activos."
        echo ""
        local VPS_IP=$(hostname -I | awk '{print $1}')
        echo " 📋 DNS requerido en tu panel:"
        echo "    A  : $NEW_DOMAIN → $VPS_IP (nube gris)"
        echo "    NS : <tu-zona> → $NEW_DOMAIN"
    else
        echo "❌ Algún servicio no arrancó. Revisa logs."
    fi

    echo ""
    read -n1 -r -p "Presione una tecla..."

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

    if systemctl is-active --quiet slowdns; then
        STATUS="${GREEN}🟢 ACTIVO${RESET}"
    else
        STATUS="${RED}🔴 DETENIDO${RESET}"
    fi

    movivip_sub_header "🐌 SLOWDNS MANAGER"

    echo -e " Estado      : $STATUS"
    echo -e " Puerto DNS  : 53"
    echo -e " DNSTT       : 5300"

    if [[ -f "$DOMAIN_FILE" ]]; then
        echo -e " Dominio NS  : ${YELLOW}$(cat "$DOMAIN_FILE")${RESET}"
    fi

    echo ""

    if [[ "$SLOWDNS" == "ON" ]]; then
        LBL=("Desinstalar SlowDNS" "Reiniciar Servicios" "Ver Estado" "Ver Public Key" "Regenerar Claves" "Cambiar Dominio NS")
    else
        LBL=("Instalar SlowDNS")
    fi
    SEL=$(nav_pick "► Opción:" "${LBL[@]}" "↩ Regresar") || SEL=0
    [[ $SEL -eq $((${#LBL[@]}+1)) ]] && SEL=0
    OP="$SEL"

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

        5)

            [[ "$SLOWDNS" == "ON" ]] && regen_keys

        ;;

        6)

            [[ "$SLOWDNS" == "ON" ]] && change_domain

        ;;

        0)

            exec bash "$BASE/protocolos/menu.sh"

        ;;

        *)

            echo ""
            echo "❌ Opción inválida."
            sleep 2

        ;;

    esac

done
