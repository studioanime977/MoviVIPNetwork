#!/bin/bash

# ── i18n shim (auto) ───────────────────────────────
if ! declare -F trx >/dev/null 2>&1; then trx() { printf '%s' "$1"; }; fi
# ─────────────────────────────────────────────────────────

#==================================================
# MoviVIP Network Premium
# SlowDNS Manager v3 (estilo MoviVIP)
# DNSTT dns-server directo en :5300
# iptables: REDIRECT UDP 53 → 5300 (simple y probado)
# SIN dnsdist — el intermediario fallaba en varios VPS
# Compatible:
# • HTTP Injector
# • HTTP Custom
# • UDP Custom
# • TLS Tunnel
#
# FIXES v3:
# • Sin dnsdist: dnstt escucha en 5300 y el NAT redirige 53→5300
# • Blindaje anti-DNAT: RETURN rules antes del catch-all UDP Custom
# • Protección loopback: resolución local del VPS intacta
# • Binario dnstt incluido en protocolos/dnstt/dns-server-amd64
#   (mismo binario probado incluido en MoviVIP)
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

# Sistema de animación/progreso + detección de estado
[[ -f "$BASE/lib/anim.sh" ]] && source "$BASE/lib/anim.sh"

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

    anim_step "Instalando dependencias"

    anim_run "apt update" apt update -y

    anim_run "Instalar paquetes base" apt install -y curl wget iptables dnsutils ca-certificates

    anim_run "Crear directorio $DIR" mkdir -p "$DIR"

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
    anim_step "Descargando SlowDNS Server (${ARCH})"

    if [[ -x "$BIN" ]]; then
        echo "$(trx '✅ SlowDNS Server ya existe.')"
        return 0
    fi

    rm -f "$BIN"

    SUCCESS=0

    # ── Fuente local: binario dnstt incluido (mismo de MoviVIP) ──
    # El nombre local debe coincidir con la arquitectura detectada
    # arriba (amd64/arm64/386); así en ARM se salta el binario amd64
    # y se cae al mirror con el binario correcto.
    LOCAL_NAME="dns-server-${BIN_NAME##*-}"
    for LOCAL_SRC in \
        "$BASE/protocolos/dnstt/$LOCAL_NAME" \
        "$(dirname "$(readlink -f "$0")")/dnstt/$LOCAL_NAME"
    do
        [[ -f "$LOCAL_SRC" ]] || continue

        if cp -f "$LOCAL_SRC" "$BIN" && chmod +x "$BIN" && "$BIN" -h >/dev/null 2>&1; then
            echo "$(trx '✅ SlowDNS Server instalado (binario incluido).')"
            return 0
        fi

        rm -f "$BIN"
    done

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
        echo "$(trx '❌ No fue posible descargar SlowDNS Server.')"
        return 1
    fi

    echo "$(trx '✅ SlowDNS Server instalado.')"

}

#==================================================
# Generar claves
#==================================================

generate_keys(){

    echo "$(trx '🔑 Generando claves...')"

    if [[ ! -f "$PUBKEY" || ! -f "$PRIVKEY" ]]; then

        "$BIN" \
            -gen-key \
            -privkey-file "$PRIVKEY" \
            -pubkey-file "$PUBKEY"

    fi

}

#==================================================
# (v3) SIN dnsdist: dnstt (dns-server) escucha directo
# en :5300 y PREROUTING redirige UDP 53 → 5300.
# Misma receta probada de MoviVIP.
#==================================================

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

    echo "$(trx '✅ Servicio slowdns.service creado.')"

}

#==================================================
# Abrir puerto DNS (v3 estilo MoviVIP)
#
# Receta simplificada (probada):
#   1. loopback ACCEPT      → resolución local del VPS intacta
#   2. REDIRECT 53→5300     → todo UDP 53 entrante va a dnstt
#   3. RETURN 53/5300       → blindaje anti-DNAT (UDP Custom)
#
# NOTA: sin u32, sin dnsdist. Directo como MoviVIP:
# dnstt (dns-server) escucha en :5300 y el NAT lo entrega.
# systemd-resolved NO se toca: las queries del propio VPS
# salen por OUTPUT (no pasan PREROUTING).
#==================================================

open_dns_port(){

    echo "$(trx '🛡 Configurando reglas DNS...')"

    # ── Limpieza de reglas viejas (v1, v2 y legados) ──

    # 53 → 5380 (dnsdist v2)
    while iptables -t nat -C PREROUTING \
        -p udp --dport 53 \
        -j REDIRECT --to-ports "$DNSDIST_PORT" 2>/dev/null
    do
        iptables -t nat -D PREROUTING \
            -p udp --dport 53 \
            -j REDIRECT --to-ports "$DNSDIST_PORT"
    done

    # 53 → 5300 (v1 / legado VPS)
    while iptables -t nat -C PREROUTING \
        -p udp --dport 53 \
        -j REDIRECT --to-ports "$SLOWDNS_PORT" 2>/dev/null
    do
        iptables -t nat -D PREROUTING \
            -p udp --dport 53 \
            -j REDIRECT --to-ports "$SLOWDNS_PORT"
    done

    # u32 → 5380 (v2 reinstalaciones)
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

    # RETURN duplicadas (reinstalaciones)
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

    # Loopback duplicado (reinstalaciones)
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

    # ip6 53 → 5380 (legado)
    while ip6tables -t nat -C PREROUTING \
        -p udp --dport 53 \
        -j REDIRECT --to-ports "$DNSDIST_PORT" 2>/dev/null
    do
        ip6tables -t nat -D PREROUTING \
            -p udp --dport 53 \
            -j REDIRECT --to-ports "$DNSDIST_PORT"
    done

    # ── Inserción en orden (top-down) ──

    # (3) Blindaje anti-DNAT: 53/5300 NUNCA deben ser
    #     capturados por reglas DNAT posteriores (UDP Custom).
    #     RETURN = salir de PREROUTING sin NAT.
    for P in "$DNS_PORT" "$SLOWDNS_PORT"; do
        iptables -t nat -I PREROUTING 1 \
            -p udp --dport "$P" -j RETURN 2>/dev/null
        ip6tables -t nat -I PREROUTING 1 \
            -p udp --dport "$P" -j RETURN 2>/dev/null
    done

    # (2) REDIRECT simple: todo UDP 53 → 5300 (dnstt directo,
    #     estilo MoviVIP, sin dnsdist).
    iptables -t nat -I PREROUTING 1 \
        -p udp --dport 53 \
        -j REDIRECT --to-ports "$SLOWDNS_PORT"

    ip6tables -t nat -I PREROUTING 1 \
        -p udp --dport 53 \
        -j REDIRECT --to-ports "$SLOWDNS_PORT"

    # (1) Protección loopback: queries locales sin NAT.
    iptables -t nat -I PREROUTING 1 \
        -i lo -p udp --dport 53 -j ACCEPT

    ip6tables -t nat -I PREROUTING 1 \
        -i lo -p udp --dport 53 -j ACCEPT

    # ── INPUT: permitir puertos del túnel ──
    for P in "$DNS_PORT" "$SLOWDNS_PORT"; do
        iptables -C INPUT -p udp --dport "$P" -j ACCEPT 2>/dev/null \
            || iptables -A INPUT -p udp --dport "$P" -j ACCEPT
    done

    # ── UFW (si está activo) ──
    if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
        for P in "$DNS_PORT" "$SLOWDNS_PORT"; do
            ufw allow "$P"/udp >/dev/null 2>&1
        done
    fi

    # ── Persistencia best-effort ──
    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4 2>/dev/null
    ip6tables-save > /etc/iptables/rules.v6 2>/dev/null

    echo "$(trx '✅ Reglas DNS aplicadas (53→5300, anti-DNAT).')"

}

#==================================================
# Test funcional post-instalación
#==================================================

test_slowdns(){

    echo ""
    echo "$(trx '🧪 Testeando túnel DNS (puerto 5300)...')"

    DOMAIN=$(cat "$DOMAIN_FILE")

    # dnstt responde a queries del dominio desde el propio VPS
    if dig @127.0.0.1 -p "$SLOWDNS_PORT" "$DOMAIN" \
        +time=3 +tries=1 2>/dev/null | grep -qE "flags:|status:"; then
        echo "$(trx '✅ Túnel DNS responde correctamente.')"
        return 0
    fi

    # Fallback: verificar que dnstt escucha en 5300 y el servicio está activo
    if systemctl is-active --quiet slowdns && \
       ss -ulnp 2>/dev/null | grep -q ":$SLOWDNS_PORT"; then
        echo "$(trx '✅ Túnel DNS activo (servicio + puerto 5300).')"
        return 0
    fi

    echo "$(trx '⚠️  El túnel DNS no respondió al test local.')"
    echo "$(trx '    Revisa: journalctl -u slowdns -n 20 --no-pager')"
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

    read -rp "$(trx '🌐 Dominio NS (Ej: ns.midominio.com): ')" DOMAIN

    [[ -z "$DOMAIN" ]] && {
        echo "$(trx '❌ Dominio inválido.')"
        sleep 2
        return
    }

    anim_init 5
    anim_step "Instalando dependencias"
    install_dependencies || return

    install_slowdns_binary || return

    anim_step "Configurando SlowDNS"
    mkdir -p "$DIR"

    echo "$DOMAIN" > "$DOMAIN_FILE"

    generate_keys || return

    create_slowdns_service

    anim_step "Abriendo puerto DNS"
    open_dns_port

    echo ""
    anim_step "Iniciando servicios"
    anim_run "daemon-reload" systemctl daemon-reload

systemctl enable slowdns >/dev/null 2>&1

svc_restart_anim slowdns "Arrancando SlowDNS"

# Verificar SlowDNS
if ! systemctl is-active --quiet slowdns; then
    echo "$(trx '❌ SlowDNS no pudo iniciar.')"
    journalctl -u slowdns -n 20 --no-pager
    return 1
fi

    test_slowdns

    sleep 3

    if systemctl is-active --quiet slowdns
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
        echo "$(trx '      ✅ SLOWDNS INSTALADO')"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "🌐 Dominio NS : $(cat "$DOMAIN_FILE")"
        echo ""
        echo "$(trx '🔑 Public Key :')"
        echo "$PUBKEY_CONTENT"
        echo ""
        echo "$(trx '🌍 DNS Puerto : 53')"
        echo "$(trx '🐌 DNSTT Puerto: 5300')"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "$(trx '  📋 CONFIGURACIÓN DNS REQUERIDA')"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "$(trx '  Tu dominio debe apuntar DIRECTAMENTE')"
        echo "$(trx '  al VPS (sin proxy Cloudflare):')"
        echo ""
        echo "$(trx '  1. Crea un registro A:')"
        echo "     $(cat "$DOMAIN_FILE") → $VPS_IP"
        echo ""
        echo "$(trx '  2. Crea un registro NS apuntando a:')"
        echo "     <tu-zona> → $(cat "$DOMAIN_FILE")"
        echo ""
        echo "$(trx '  3. En Cloudflare, desactiva el proxy')"
        echo "$(trx '     (nube gris, NO naranja) para este')"
        echo "     subdominio."
        echo ""
        echo "$(trx '  ⚠️  Sin esto, SlowDNS NO funcionará.')"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "$(trx '📌 Para asignar puertos a usuarios')"
        echo "$(trx '   usar el formato: 1-PUERTO')"
        echo "$(trx '   Ejemplo: 1-5300')"
        echo ""

    else

        echo ""
        echo "$(trx '❌ Error iniciando SlowDNS')"
        echo ""

        systemctl status slowdns --no-pager

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

    read -rp "$(trx '¿Eliminar SlowDNS? (s/n): ')" R

    [[ ! "$R" =~ ^[Ss]$ ]] && return

anim_step "Desinstalando SlowDNS"
anim_run "Detener y deshabilitar" bash -c "systemctl stop slowdns 2>/dev/null; systemctl disable slowdns 2>/dev/null"

anim_run "Eliminar archivos de servicio" rm -f /etc/systemd/system/slowdns.service /etc/dnsdist/dnsdist.conf

anim_run "Eliminar directorio $DIR" rm -rf "$DIR"
anim_run "Eliminar binario" rm -f "$BIN"

anim_run "daemon-reload" systemctl daemon-reload

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
    echo "$(trx '✅ SlowDNS eliminado.')"

    sleep 3

}

#==================================================
# Reiniciar servicios
#==================================================

restart_slowdns(){

    clear

    svc_restart_anim slowdns "Reiniciando SlowDNS"

    sleep 2

    if systemctl is-active --quiet slowdns
    then
        echo ""
        echo "$(trx '✅ Servicios activos.')"
        test_slowdns
    else
        echo ""
        echo "$(trx '❌ Error al reiniciar.')"
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
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    echo "$(trx 'Puertos abiertos:')"
    ss -ulnp | grep -E ":53|:5300" || true

    echo ""
    echo "$(trx 'Reglas NAT activas (puerto 53):')"
    iptables -t nat -S PREROUTING | grep -E "dport 53|dport 5300" || true

    echo ""
    echo "Dominio:"
    [[ -f "$DOMAIN_FILE" ]] && cat "$DOMAIN_FILE"

    echo ""
    echo "$(trx 'Public Key:')"
    [[ -f "$PUBKEY" ]] && cat "$PUBKEY"

    echo ""
    read -n1 -r -p "$(trx 'Presione una tecla...')"

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
        echo "$(trx '❌ No existe la Public Key.')"
    fi

    echo ""
    read -n1 -r -p "$(trx 'Presione una tecla...')"

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
        echo "$(trx '❌ SlowDNS no está instalado.')"
        echo ""
        read -n1 -r -p "$(trx 'Presione una tecla...')"
        return
    fi

    echo "$(trx ' ⚠️  Los clientes deberán actualizar la Public Key.')"
    echo ""

    read -rp "$(trx ' ¿Regenerar par de claves? (s/n): ')" R

    [[ ! "$R" =~ ^[Ss]$ ]] && return

    rm -f "$PRIVKEY" "$PUBKEY"

    "$BIN" -gen-key -privkey-file "$PRIVKEY" -pubkey-file "$PUBKEY" || {
        echo "$(trx '❌ Error generando claves.')"
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
        echo "$(trx '✅ Claves regeneradas. Servicio activo.')"
        echo ""
        echo "$(trx '🔑 Nueva Public Key :')"
        cat "$PUBKEY"
        echo ""
        echo "🌐 Dominio NS : $(cat "$DOMAIN_FILE" 2>/dev/null)"
    else
        echo "$(trx '❌ El servicio no arrancó. Revisa logs.')"
    fi

    echo ""
    read -n1 -r -p "$(trx 'Presione una tecla...')"

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
        echo "$(trx '❌ SlowDNS no está instalado.')"
        echo ""
        read -n1 -r -p "$(trx 'Presione una tecla...')"
        return
    fi

    echo " Dominio actual : $(cat "$DOMAIN_FILE" 2>/dev/null)"
    echo ""

    read -rp "$(trx ' Nuevo Dominio NS (Ej: ns.midominio.com): ')" NEW_DOMAIN

    [[ -z "$NEW_DOMAIN" ]] && {
        echo "$(trx '❌ Dominio inválido.')"
        sleep 2
        return
    }

    echo ""
    echo "$NEW_DOMAIN" > "$DOMAIN_FILE"

    create_slowdns_service

    systemctl restart slowdns
    sleep 2

    if systemctl is-active --quiet slowdns; then

        sed -i '/^SLOWDNS_NS=/d' "$CONFIG"
        echo "SLOWDNS_NS=$NEW_DOMAIN" >> "$CONFIG"
        source "$CONFIG"

        echo "✅ Dominio cambiado a $NEW_DOMAIN. Servicios activos."
        echo ""
        local VPS_IP=$(hostname -I | awk '{print $1}')
        echo "$(trx ' 📋 DNS requerido en tu panel:')"
        echo "    A  : $NEW_DOMAIN → $VPS_IP (nube gris)"
        echo "    NS : <tu-zona> → $NEW_DOMAIN"
    else
        echo "$(trx '❌ Algún servicio no arrancó. Revisa logs.')"
    fi

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

    if systemctl is-active --quiet slowdns; then
        STATUS="${GREEN}🟢 ACTIVO${RESET}"
    else
        STATUS="${RED}🔴 DETENIDO${RESET}"
    fi

    mv_header "🐌 SlowDNS Manager" "$(trx 'Túnel DNS · DNSTT 5300')" "v6.2"
    movivip_contacts 2>/dev/null || true

    echo -e " Estado      : $STATUS"
    echo -e "$(trx ' Puerto DNS  : 53')"
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
            echo "$(trx '❌ Opción inválida.')"
            sleep 2

        ;;

    esac

done
