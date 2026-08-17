#!/bin/bash

if [[ -d "/etc/movivip" ]]; then
    echo " Actualización detectada..."
    echo " (la actualización también requiere licencia activa — delegando en update.sh)"
    bash <(curl -fsSL https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/update.sh) || true
    exit 0
fi

# ═══════════════════════════════════════════════════════════════
# COLOR SYSTEM (before language loads)
# ═══════════════════════════════════════════════════════════════
CYAN="\e[1;96m"; GOLD="\e[1;93m"; GREEN="\e[1;92m"; RED="\e[1;91m"
WHITE="\e[1;97m"; GRAY="\e[1;90m"; MAGENTA="\e[1;95m"; RESET="\e[0m"

clear
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GOLD}      🛡️ MoviVIP Network — INSTALADOR v5.0 🛡️${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

if [[ $EUID -ne 0 ]]; then
echo -e "${RED}❌ Necesita root${RESET}"
exec sudo bash "$0" "$@"
fi  
  
#==============================  
  
# UBUNTU CHECK  
  
#==============================  
  
source /etc/os-release  
  
if [[ "$ID" != "ubuntu" ]]; then  
echo "❌ Solo Ubuntu"  
exit 1  
fi  
  
clear  
  
echo "✔ Sistema Ubuntu detectado"  
sleep 1  

# ==============================
# GATE DE LICENCIA (ANTI-PIRATERÍA)
# Valida contra Firebase antes de instalar CUALQUIER cosa.
# Sin licencia válida -> instalación BLOQUEADA.
# ==============================

GATE_URL="https://raw.githubusercontent.com/studioanime977/vps-license-gate/main/gate/validar-licencia.sh"
GATE_TMP="/tmp/validar-licencia-movivip.sh"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "      🔑 VALIDACIÓN DE LICENCIA"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Asegurar curl (si apt estaba roto, usar la auto-reparación del gate)
command -v curl >/dev/null 2>&1 || apt-get install -y curl >/dev/null 2>&1

# Descargar el módulo de validación (siempre la última versión)
if ! curl -fsSL --max-time 30 "$GATE_URL" -o "$GATE_TMP" 2>/dev/null; then
    echo "❌ No se pudo cargar el módulo de validación de licencia."
    echo "   Verifica tu conexión a internet y reintenta."
    exit 1
fi

chmod +x "$GATE_TMP"

# Ejecutar la validación (pide la key interactivamente)
bash "$GATE_TMP"
GATE_RESULT=$?

if [[ $GATE_RESULT -ne 0 ]]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "   ⛔ INSTALACIÓN BLOQUEADA — LICENCIA NO VÁLIDA"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "   Este sistema requiere una clave de licencia válida."
    echo ""
    echo "   🔑 Adquiere tu licencia aquí:"
    echo "   ─────────────────────────────────────────────"
    echo "   💬 Telegram : @MoviVIP"
    echo "   📱 WhatsApp : +57 311 700 8185"
    echo "   🌐 Web      : https://movivip-network.web.app"
    echo "   📢 Canal    : https://t.me/MoviVIPNetwork"
    echo "   👥 Grupo    : https://t.me/MoviVIPNet"
    echo "   ─────────────────────────────────────────────"
    echo ""
    exit 1
fi

echo ""
echo -e "${GREEN}✔ LICENCIA VALIDADA — CONTINUANDO INSTALACIÓN...${RESET}"
echo ""

# Persistir el gate localmente: los protocolos y el bot lo usan
# (check-licencia.sh) para validar la key contra Firebase EN VIVO
# antes de cada instalación/gestión de protocolo.
mkdir -p /etc/movivip
cp "$GATE_TMP" /etc/movivip/validar-licencia.sh
chmod +x /etc/movivip/validar-licencia.sh
# Ruta legacy usada por update.sh
mkdir -p /etc/movivip/gate
cp "$GATE_TMP" /etc/movivip/gate/validar-licencia.sh
chmod +x /etc/movivip/gate/validar-licencia.sh
echo -e "${GREEN}✔ Gate de licencia instalado localmente.${RESET}"

# ═══════════════════════════════════════════════════════════════
# SELECTOR DE IDIOMA — INTERACTIVO
# ═══════════════════════════════════════════════════════════════

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GOLD}      🌐 SELECT LANGUAGE / SELECCIONAR IDIOMA${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

# Lista de idiomas: código|bandera|nombre|región
LANG_LIST=(
    "es|🇪🇸|Español|España/Latinoamérica"
    "en|🇺🇸|English|United States/UK"
    "af|🇪🇹|Afaan Oromoo|Ethiopia/Kenya"
    "fr|🇫🇷|Français|France/Belgique"
    "pt|🇧🇷|Português|Brasil/Portugal"
    "ar|🇸🇦|العربية|السعودية/مصر"
    "sw|🇰🇪|Kiswahili|Kenya/Tanzania"
    "de|🇩🇪|Deutsch|Deutschland/Österreich"
    "zh|🇨🇳|中文|中国"
    "hi|🇮🇳|हिन्दी|भारत"
)

INSTALL_LANG="es"
for i in "${!LANG_LIST[@]}"; do
    IFS='|' read -r code flag name region <<< "${LANG_LIST[$i]}"
    num=$((i + 1))
    printf "  ${CYAN}[%02d]${RESET} ${WHITE}%s %-15s${RESET} ${GRAY}%-20s${RESET}\n" \
        "$num" "$flag" "$name" "$region"
done

echo ""
read -rp "$(echo -e "${CYAN}➜ ${GOLD}Select language [1-10]${WHITE} (default: 1=ES) ➤ ${RESET}")" LANG_CHOICE
LANG_CHOICE="${LANG_CHOICE:-1}"

# Mapear número a código
LANG_CODES=("es" "en" "af" "fr" "pt" "ar" "sw" "de" "zh" "hi")
LANG_IDX=$((LANG_CHOICE - 1))
if [[ $LANG_IDX -ge 0 && $LANG_IDX -lt ${#LANG_CODES[@]} ]]; then
    INSTALL_LANG="${LANG_CODES[$LANG_IDX]}"
else
    INSTALL_LANG="es"
fi

echo -e "${GREEN}✅ Idioma seleccionado: ${WHITE}${INSTALL_LANG^^}${RESET}"
sleep 1

  #==============================
# INSTALAR PAQUETES BÁSICOS
#==============================

echo "📦 Instalando paquetes básicos..."

apt update -y

apt install -y \
curl \
wget \
git \
unzip \
zip \
tar \
sudo \
nano \
cron \
net-tools \
dnsutils \
lsof \
screen \
jq \
bc \
socat \
openssl \
ca-certificates \
fail2ban \
whois \
rkhunter \
chkrootkit \
lynis

echo "✅ Paquetes instalados."

#==============================
# 🔐 SSL/TLS + HAPROXY — INSTALACIÓN AUTOMÁTICA
#==============================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "      🔐 INSTALANDO SSL/TLS + HAPROXY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Instalar haproxy
echo "📦 Instalando haproxy..."
apt-get update -y >/dev/null 2>&1
apt-get install -y haproxy python3 >/dev/null 2>&1

# Generar certificado SSL auto-firmado
if [[ ! -f /etc/haproxy/yha.pem ]]; then
    echo "🔑 Generando certificado SSL..."
    openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
        -keyout /tmp/key.pem -out /tmp/cert.pem \
        -subj "/CN=ssl-tunnel" 2>/dev/null
    cat /tmp/key.pem /tmp/cert.pem > /etc/haproxy/yha.pem
    rm -f /tmp/key.pem /tmp/cert.pem
    chmod 600 /etc/haproxy/yha.pem
    echo "✅ Certificado SSL creado."
fi

# Liberar puertos
for P in 80 443 8080 8443; do
    fuser -k "$P/tcp" >/dev/null 2>&1
done

# ssh-ws-internal.py (WebSocket → SSH)
if [[ ! -f /usr/local/bin/ssh-ws-internal.py ]]; then
    cat > /usr/local/bin/ssh-ws-internal.py <<'PYEOF'
#!/usr/bin/env python3
import asyncio, signal, sys
BUFFER_SIZE = 65536
SSH_HOST = "127.0.0.1"
SSH_PORT = 22
R101 = b"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n"
R200 = b"HTTP/1.1 200 Connection established\r\n\r\n"
active = 0

async def pipe(r, w):
    try:
        while True:
            d = await r.read(BUFFER_SIZE)
            if not d: break
            w.write(d); await w.drain()
    except: pass
    finally:
        try: w.close()
        except: pass

async def handle(cr, cw):
    global active
    active += 1; sw = None
    try:
        try:
            p = await asyncio.wait_for(cr.read(BUFFER_SIZE), timeout=10)
        except asyncio.TimeoutError:
            cw.close(); active -= 1; return
        if not p:
            cw.close(); active -= 1; return
        req = p.decode("utf-8", errors="ignore").upper()
        cw.write(R101 if ("UPGRADE" in req or "WEBSOCKET" in req) else R200)
        await cw.drain()
        try:
            sr, sw = await asyncio.open_connection(SSH_HOST, SSH_PORT)
        except:
            cw.close(); active -= 1; return
        await asyncio.gather(pipe(cr, sw), pipe(sr, cw))
    except: pass
    finally:
        active -= 1
        try: cw.close()
        except: pass
        if sw:
            try: sw.close()
            except: pass

async def start(port):
    s = await asyncio.start_server(handle, "127.0.0.1", port)
    async with s: await s.serve_forever()

def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 10015
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    for sig in (signal.SIGTERM, signal.SIGINT):
        try: loop.add_signal_handler(sig, lambda: loop.stop())
        except: pass
    loop.run_until_complete(start(port))

if __name__ == "__main__":
    main()
PYEOF
    chmod +x /usr/local/bin/ssh-ws-internal.py
    echo "✅ SSH WebSocket internal instalado."
fi

# Servicio systemd para ssh-ws-internal
cat > /etc/systemd/system/ssh-ws-internal.service <<'SVCEOF'
[Unit]
Description=SSH WebSocket Internal (127.0.0.1:10015)
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/ssh-ws-internal.py 10015
Restart=always
RestartSec=3
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
SVCEOF

# Haproxy config
cat > /etc/haproxy/haproxy.cfg <<'HAPCFG'
global
    stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
    stats timeout 1d
    tune.bufsize 1048576
    tune.maxrewrite 3072
    tune.ssl.default-dh-param 2048
    pidfile /run/haproxy.pid
    chroot /var/lib/haproxy
    user haproxy
    group haproxy
    daemon
    ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
    ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
    ssl-default-bind-options no-sslv3 no-tlsv10 no-tlsv11
    ca-base /etc/ssl/certs
    crt-base /etc/ssl/private

defaults
    log global
    mode tcp
    option dontlognull
    option tcp-smart-connect
    timeout connect 5s
    timeout client 24h
    timeout server 24h

frontend multiport_frontend
    mode tcp
    bind *:443 tfo
    tcp-request inspect-delay 10ms
    tcp-request content accept if HTTP
    tcp-request content accept if { req.ssl_hello_type 1 }
    use_backend recir_http_backend if HTTP
    default_backend recir_https_backend

backend recir_https_backend
    mode tcp
    server recir_https_server abns@haproxy-https send-proxy-v2 check

backend recir_http_backend
    mode tcp
    server recir_http_server abns@haproxy-http send-proxy-v2 check

frontend multiports_frontend
    mode tcp
    bind abns@haproxy-http accept-proxy tfo
    default_backend recir_https_www_backend

backend recir_https_www_backend
    mode tcp
    server recir_https_www_server 127.0.0.1:2223 check

frontend ssl_frontend
    mode tcp
    bind *:80 tfo
    bind *:8080 tfo
    bind *:8443 ssl crt /etc/haproxy/yha.pem alpn h2,http/1.1 tfo
    bind abns@haproxy-https accept-proxy ssl crt /etc/haproxy/yha.pem alpn h2,http/1.1 tfo
    tcp-request inspect-delay 200ms
    tcp-request content capture req.ssl_sni len 100
    tcp-request content accept if { req.ssl_hello_type 1 }
    acl acl_upgrade hdr(Connection) -i upgrade
    acl acl_websocket hdr(Upgrade) -i websocket
    acl acl_payload payload(0,7) -m bin 5353482d322e30
    acl acl_http2 ssl_fc_alpn -i h2
    acl acl_path_regex path_reg -i ^\/(.*)
    acl acl_path_vless path_reg -i ^\/vless.*
    acl acl_path_vmess path_reg -i ^\/vmess.*
    acl acl_path_trojan path_reg -i ^\/trojan-ws.*
    acl acl_path_grpc path_reg -i ^\/(vmess-grpc|trojan-grpc|ss-grpc).*
    acl acl_path_ssh path_reg -i ^\/fightertunnelssh.*
    use_backend grpc_backend if acl_http2
    use_backend payload_backend if acl_path_vless
    use_backend vmess_backend if acl_path_vmess
    use_backend payload_backend if acl_path_trojan
    use_backend payload_backend if acl_path_grpc
    use_backend ssh_backend if acl_path_ssh
    use_backend websocket_backend if acl_upgrade acl_websocket
    use_backend websocket_backend if acl_path_regex
    use_backend bot_ftvpn_backend if acl_payload
    default_backend ssh_ws_default_backend

backend websocket_backend
    mode tcp
    server ssh_ws_server 127.0.0.1:10015 check

backend grpc_backend
    mode tcp
    server grpc_server 127.0.0.1:1013 check

backend ssh_ws_default_backend
    mode tcp
    balance roundrobin
    server ssh_ws_server 127.0.0.1:10015 check

backend bot_ftvpn_backend
    mode tcp
    server ssh_direct 127.0.0.1:22 check

backend payload_backend
    mode tcp
    balance roundrobin
    server payload_server_vless   127.0.0.1:10001 check
    server payload_server_vmess   127.0.0.1:10002 check
    server payload_server_trojan  127.0.0.1:10003 check
    server payload_server_grpc    127.0.0.1:10004 check
    server payload_server_vless2  127.0.0.1:10005 check
    server payload_server_vmess2  127.0.0.1:10006 check
    server payload_server_trojan2 127.0.0.1:10007 check
    server payload_server_grpc2   127.0.0.1:10008 check
    server ssh_server             127.0.0.1:10015 check

backend vmess_backend
    mode tcp
    balance roundrobin
    server payload_server_vmess   127.0.0.1:10002 check

backend ssh_backend
    mode tcp
    server ssh_server 127.0.0.1:10015 check
HAPCFG

# Haproxy resilience override
DIR="/etc/systemd/system/haproxy.service.d"
mkdir -p "$DIR"
cat > "${DIR}/10-resilience.conf" <<'RESF'
[Unit]
After=network-online.target ssh-ws-internal.service
Wants=network-online.target ssh-ws-internal.service

[Service]
Restart=always
RestartSec=3
StartLimitIntervalSec=0
ExecStartPre=/bin/mkdir -p /run/haproxy
ExecStartPre=/bin/mkdir -p /var/lib/haproxy
ExecStartPre=/bin/chown -R haproxy:haproxy /var/lib/haproxy /run/haproxy
RESF

# Validar, habilitar e iniciar
if haproxy -c -f /etc/haproxy/haproxy.cfg 2>/dev/null; then
    systemctl daemon-reload
    systemctl enable haproxy ssh-ws-internal 2>/dev/null
    systemctl restart ssh-ws-internal haproxy 2>/dev/null
    echo "✅ SSL/TLS + HAProxy instalado y activo."
else
    echo "⚠️ HAProxy configuración con errores — revisar manualmente."
fi

#==============================
# 🚀 MOVIVIP — OPTIMIZADOR EXTREMO (AUTO)
#==============================

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${GOLD}           🚀 MOVIVIP — OPTIMIZADOR EXTREMO 🚀${RESET}${CYAN}             ║${RESET}"
echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${RESET}"
echo -e "${CYAN}║${WHITE}   Mantén tu VPS como una pluma 🪶 aunque tengas${RESET}${CYAN}        ║${RESET}"
echo -e "${CYAN}║${WHITE}   cientos de usuarios conectados.${RESET}${CYAN}                      ║${RESET}"
echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${RESET}"
echo -e "${CYAN}║${WHITE}   [1] 🧹 Limpiar recursos  (RAM/caché/swap/logs/procesos)${RESET}${CYAN}║${RESET}"
echo -e "${CYAN}║${WHITE}   [2] 🚀 Optimizar red     (BBR+FQ+MTU1470+buffers64MB)${RESET}${CYAN}║${RESET}"
echo -e "${CYAN}║${WHITE}   [3] ⏰ Limpieza automática (cada X tiempo)${RESET}${CYAN}          ║${RESET}"
echo -e "${CYAN}║${WHITE}   [4] ⚙️ Editar valores de red (buffers/MTU/swappiness)${RESET}${CYAN}║${RESET}"
echo -e "${CYAN}║${WHITE}   [5] 📊 Ver recursos      (RAM/CPU/procesos top)${RESET}${CYAN}     ║${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "${CYAN}   → ${GOLD}Instalación automática: Optimizando todo...${RESET}"
echo ""

#==============================
# [1] 🧹 LIMPIAR RECURSOS (RAM/caché/swap/logs/procesos)
#==============================

echo -e "${CYAN}   [1] 🧹 Limpiando recursos...${RESET}"

# Limpiar caché apt (NO autoremove — destruye dependencias)
apt clean
apt autoclean

# Proteger paquetes críticos — NUNCA se eliminan
CRITICAL_PKGS=(
    "python3" "python3.10" "python3.10-minimal" "python3-pip" "python3-setuptools" "python3-wheel" "python3-dev"
    "libpython3-stdlib" "libpython3.10-stdlib" "libpython3.10-minimal"
    "sudo" "wget" "curl" "libcurl3-gnutls" "libcurl4" "libssl1.1"
    "screen" "less" "git" "openssh-server" "openssh-sftp-server"
    "haproxy" "socat" "openssl" "ca-certificates"
    "fail2ban" "iptables" "iproute2" "net-tools" "dnsutils"
    "lsof" "nano" "cron" "jq" "bc" "unzip" "zip"
    "systemd" "systemd-sysv" "sysvinit-utils" "mount" "util-linux"
    "fdisk" "adduser" "login" "passwd" "procps"
    "libpam0g" "libpam-modules" "libpam-modules-bin" "libpam-runtime"
    "netplan.io" "libnetplan0" "libglib2.0-0" "libglib2.0-data"
    "libyaml-0-2" "liburing2" "media-types" "perl" "perl-modules-5.34"
)
for hold_pkg in "${CRITICAL_PKGS[@]}"; do
    apt-mark hold "$hold_pkg" 2>/dev/null
done

# SOLO remover paquetes que NO tienen dependencias cascada
REMOVE_PKGS=(
    "snapd" "lxd-agent" "lxd-installer" "cloud-guest-utils" "cloud-init"
    "cloud-utils" "open-vm-tools" "isc-dhcp-client" "ntfs-3g" "plymouth"
    "plymouth-theme-ubuntu-text" "fonts-ubuntu-console" "fonts-dejavu-core"
    "fonts-freefont-ttf" "command-not-found" "command-not-found-data"
    "friendly-recovery" "installation-report" "landscape-common"
)

for pkg in "${REMOVE_PKGS[@]}"; do
    dpkg -l | grep -q "^ii.*${pkg}" && apt remove -y --no-autoremove "$pkg" 2>/dev/null
done

# Liberar holds
for hold_pkg in "${CRITICAL_PKGS[@]}"; do
    apt-mark unhold "$hold_pkg" 2>/dev/null
done

# Limpiar directorios temporales
rm -rf /tmp/* /var/tmp/* /var/cache/apt/archives/*.deb /var/lib/apt/lists/*
rm -rf /root/.cache /root/.local
rm -rf /var/log/*.gz /var/log/*.[0-9] /var/log/journal/*

# Limpiar logs viejos
journalctl --vacuum-time=1d 2>/dev/null
find /var/log -name "*.log.*" -delete 2>/dev/null
find /var/log -name "*.gz" -delete 2>/dev/null

# Deshabilitar servicios innecesarios
DISABLE_SVCS=(
    "multipathd" "multipathd.socket" "ModemManager" "apport"
    "apport-autoreport.timer" "udisks2" "accounts-daemon" "avahi-daemon"
    "cups" "cups-browsed" "bluetooth" "wpa_supplicant"
    "snapd.service" "snapd.socket" "snapd.seeded.service"
)

for svc in "${DISABLE_SVCS[@]}"; do
    systemctl stop "$svc" 2>/dev/null
    systemctl disable "$svc" 2>/dev/null
done

# Eliminar snaps
snap remove --purge lxd 2>/dev/null
snap remove --purge lxd-agent 2>/dev/null
snap remove --purge core20 2>/dev/null
snap remove --purge core22 2>/dev/null
snap remove --purge snapd 2>/dev/null
rm -rf /snap /var/snap /var/lib/snapd

# Limpiar historial
rm -f /root/.bash_history
history -c 2>/dev/null

echo -e "${GREEN}   ✅ Recursos limpiados.${RESET}"

#==============================
# [2] 🚀 OPTIMIZAR RED (BBR+FQ+MTU1470+buffers64MB)
#==============================

echo -e "${CYAN}   [2] 🚀 Optimizando red (BBR+FQ+MTU1470+buffers64MB)...${RESET}"

cat >/etc/sysctl.d/99-MoviVIP.conf <<'EOF'
# ============ MoviVIP Network — GAMING OPTIMIZED ============
# Congestión BBR (TCP) + cola FQ adaptativa
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr

# Buffers de red — balanceados (no bufferbloat)
net.core.rmem_max=67108864
net.core.wmem_max=67108864
net.core.rmem_default=262144
net.core.wmem_default=262144
net.ipv4.tcp_rmem=4096 262144 67108864
net.ipv4.tcp_wmem=4096 262144 67108864
net.ipv4.tcp_mtu_probing=1
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_low_latency=1

# Colas / conexiones — gaming burst
net.core.somaxconn=8192
net.core.netdev_max_backlog=16384
net.ipv4.tcp_max_syn_backlog=8192
net.ipv4.tcp_fin_timeout=15
net.ipv4.tcp_keepalive_time=300
net.ipv4.tcp_keepalive_intvl=15
net.ipv4.tcp_keepalive_probes=5
net.ipv4.tcp_tw_reuse=1
net.ipv4.ip_local_port_range=1024 65000
net.ipv4.tcp_timestamps=1

# UDP Memory — adaptativo gaming (32M→256M→1G)
net.ipv4.udp_mem=32768 65536 262144

# Conntrack — gaming timeouts (limpio rápido)
net.netfilter.nf_conntrack_max=524288
net.netfilter.nf_conntrack_udp_timeout=5
net.netfilter.nf_conntrack_udp_timeout_stream=15

# Memoria virtual — prioriza rendimiento
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_ratio=10
vm.dirty_background_ratio=2

# Límites
fs.file-max=2097152
EOF

sysctl --system >/dev/null 2>&1
ulimit -n 1048576 2>/dev/null

# MTU 1470 en la interfaz activa
IFACE_NET=$(ip route get 8.8.8.8 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')
[[ -z "$IFACE_NET" ]] && IFACE_NET=$(ls /sys/class/net | grep -E '^(eth|ens|enp)' | head -n1)
ip link set dev "${IFACE_NET:-eth0}" mtu 1470 2>/dev/null

# FQ Gaming
tc qdisc del dev "$IFACE_NET" root 2>/dev/null
tc qdisc add dev "$IFACE_NET" root fq quantum 1492 initial_quantum 14920 flow_limit 1000 limit 10000 horizon 0 refill_delay 10 low_rate_threshold 10Mbit 2>/dev/null

#==============================
# IPTABLES — Reglas base del servidor
#==============================

echo -e "${CYAN}   Configurando iptables base...${RESET}"

# Asegurar que iptables está instalado
apt-get install -y iptables >/dev/null 2>&1

# INPUT: aceptar tráfico de servicios
iptables -A INPUT -p udp --dport 2100 -j ACCEPT          # UDP Custom
iptables -A INPUT -p udp --dport 5667 -j ACCEPT          # ZiVPN
iptables -A INPUT -p udp --dport 6000:19999 -j ACCEPT    # ZiVPN range
iptables -A INPUT -p udp --dport 20000:29999 -j ACCEPT   # UDP Custom range
iptables -A INPUT -p udp --dport 7200 -j ACCEPT          # BadVPN calls/VoIP
iptables -A INPUT -p udp --dport 7300 -j ACCEPT          # BadVPN gaming
iptables -A INPUT -p tcp --dport 7300 -j ACCEPT          # BadVPN gaming TCP
iptables -A INPUT -p tcp --dport 80 -j ACCEPT            # HTTP
iptables -A INPUT -p tcp --dport 443 -j ACCEPT           # HTTPS
iptables -A INPUT -p tcp --dport 8080 -j ACCEPT          # HTTP alt
iptables -A INPUT -p tcp --dport 8443 -j ACCEPT          # HTTPS alt
iptables -A INPUT -p tcp --dport 22 -j ACCEPT            # SSH

# OUTPUT: chain MOVIVIP_OUT para control de usuarios
iptables -N MOVIVIP_OUT >/dev/null 2>&1
iptables -C OUTPUT -j MOVIVIP_OUT >/dev/null 2>&1 || iptables -I OUTPUT 1 -j MOVIVIP_OUT

# MANGLE: DSCP para priorización gaming
iptables -t mangle -A PREROUTING -p udp --dport 7000:7999 -j DSCP --set-dscp-class af41    # Free Fire
iptables -t mangle -A PREROUTING -p udp --dport 3478:3480 -j DSCP --set-dscp-class af41    # COD Mobile
iptables -t mangle -A PREROUTING -p udp --dport 8000:9000 -j DSCP --set-dscp-class af41    # PUBG Mobile

# Persistir reglas
mkdir -p /etc/iptables
iptables-save > /etc/iptables/rules.v4

echo -e "${GREEN}   ✅ iptables base configurado.${RESET}"

echo -e "${GREEN}   ✅ Red optimizada (BBR+FQ+MTU1470+iptables).${RESET}"

#==============================
# [3] ⏰ LIMPIEZA AUTOMÁTICA (cron cada 30 min)
#==============================

echo -e "${CYAN}   [3] ⏰ Configurando limpieza automática (cada 30 min)...${RESET}"

mkdir -p /etc/movivip/scripts

cat > /etc/movivip/scripts/auto-cleanup.sh << 'CLEANEOF'
#!/bin/bash
# MoviVIP Auto-Cleanup — cada 30 minutos

# Limpiar caché apt
apt clean 2>/dev/null

# Limpiar logs viejos (>24h)
find /var/log -name "*.log.*" -mmin +1440 -delete 2>/dev/null
find /var/log -name "*.gz" -delete 2>/dev/null

# Limpiar /tmp (>24h)
find /tmp -type f -mmin +1440 -delete 2>/dev/null
find /var/tmp -type f -mmin +1440 -delete 2>/dev/null

# Limpiar journal (>1d)
journalctl --vacuum-time=1d 2>/dev/null

# Limpiar caché del usuario
rm -rf /root/.cache/pip 2>/dev/null
rm -rf /root/.cache/apt 2>/dev/null

# Liberar swap si está en 0% usage
SWAP_USED=$(free | awk '/Swap/{print $3}')
if [[ "$SWAP_USED" -eq 0 ]]; then
    swapoff -a 2>/dev/null
    swapon -a 2>/dev/null
fi

# Mostrar espacio libre
df -h / | awk 'NR==2 {print "[Auto-Cleanup] "$4" libre ("$5" usado)"}' >> /var/log/movivip-cleanup.log 2>/dev/null
CLEANEOF

chmod +x /etc/movivip/scripts/auto-cleanup.sh

# Cron: cada 30 minutos
if ! crontab -l 2>/dev/null | grep -q "auto-cleanup.sh"; then
    (crontab -l 2>/dev/null; echo "*/30 * * * * bash /etc/movivip/scripts/auto-cleanup.sh >/dev/null 2>&1") | crontab -
fi

echo -e "${GREEN}   ✅ Limpieza automática activada (cada 30 min).${RESET}"

# Auto-update: cada 2 días
chmod +x /etc/movivip/auto-update.sh 2>/dev/null
if ! crontab -l 2>/dev/null | grep -q "auto-update.sh"; then
    (crontab -l 2>/dev/null; echo "0 3 */2 * * bash /etc/movivip/auto-update.sh >/dev/null 2>&1") | crontab -
fi
echo -e "${GREEN}   ✅ Auto-update activado (cada 2 días).${RESET}"

#==============================
# [4] ⚙️ ESTABLECER VALORES DE RED (buffers/MTU/swappiness)
#==============================

echo -e "${CYAN}   [4] ⚙️ Estableciendo valores de red óptimos...${RESET}"

# Guardar MTU en config
MTU_CURRENT=$(ip link show "$IFACE_NET" 2>/dev/null | grep -o "mtu [0-9]*" | awk '{print $2}')
MTU_CURRENT="${MTU_CURRENT:-1470}"

# Guardar valores en config
cat >> /etc/movivip/config.conf << CONFEOF

#==============================
# OPTIMIZADOR DE RED
#==============================

NET_MTU="$MTU_CURRENT"
NET_RMEM="67108864"
NET_WMEM="67108864"
NET_SOMAXCONN="8192"
NET_BACKLOG="16384"
NET_SWAPPINESS="10"
NET_CLEANUP_INTERVAL="30"
CONFEOF

echo -e "${GREEN}   ✅ Valores de red guardados.${RESET}"

#==============================
# [5] 📊 VER RECURSOS (RAM/CPU/procesos top)
#==============================

echo -e "${CYAN}   [5] 📊 Verificando recursos...${RESET}"

# RAM
RAM_TOTAL=$(free -m | awk '/Mem:/{print $2}')
RAM_USED=$(free -m | awk '/Mem:/{print $3}')
RAM_FREE=$(free -m | awk '/Mem:/{print $7}')
RAM_PERCENT=$(( RAM_USED * 100 / RAM_TOTAL ))

# CPU
CPU_CORES=$(nproc)
CPU_LOAD=$(uptime | awk -F'load average:' '{print $2}' | cut -d',' -f1 | tr -d ' ')

# Disco
DISK_USED=$(df -h / | awk 'NR==2 {print $5}')
DISK_FREE=$(df -h / | awk 'NR==2 {print $4}')

# Top procesos por RAM
TOP_RAM=$(ps aux --sort=-%mem | head -5 | awk 'NR>1{printf "     %s %s%% %s\n", $1, $4, $11}')

echo ""
echo -e "${CYAN}   ╔══════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}   ║${GOLD}           📊 RECURSOS DEL VPS 📊${RESET}${CYAN}                ║${RESET}"
echo -e "${CYAN}   ╠══════════════════════════════════════════════════╣${RESET}"
echo -e "${CYAN}   ║${WHITE}  💾 RAM: ${RAM_USED}MB / ${RAM_TOTAL}MB (${RAM_PERCENT}%)${RESET}${CYAN}              ║${RESET}"
echo -e "${CYAN}   ║${WHITE}  ⚡ CPU: ${CPU_CORES} cores | Load: ${CPU_LOAD}${RESET}${CYAN}            ║${RESET}"
echo -e "${CYAN}   ║${WHITE}  💿 Disco: ${DISK_USED} usado | ${DISK_FREE} libre${RESET}${CYAN}         ║${RESET}"
echo -e "${CYAN}   ╠══════════════════════════════════════════════════╣${RESET}"
echo -e "${CYAN}   ║${GOLD}  🏆 Top procesos por RAM:${RESET}${CYAN}                      ║${RESET}"
echo -e "${CYAN}   ║${WHITE}${TOP_RAM}${RESET}${CYAN}  ║${RESET}"
echo -e "${CYAN}   ╚══════════════════════════════════════════════════╝${RESET}"
echo ""

# Guardar espacio final
df -h / | awk 'NR==2 {print "💾 Espacio libre: "$4" ("$5" usado)"}'

#==============================
# INSTALAR OPENSSH
#==============================

echo "🔐 Instalando OpenSSH..."

apt install -y openssh-server

systemctl enable ssh
systemctl restart ssh

echo "✅ OpenSSH instalado y activo en el puerto 22."
sleep 2
#==============================  
  
# CONFIG SERVER  
  
#==============================  

# Asegurar que curl está instalado
apt-get install -y curl >/dev/null 2>&1
  
clear  
  
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"  
echo "        CONFIGURACIÓN DEL SERVIDOR"  
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"  
  
read -p "🌐 Dominio Cloudflare: " SERVER_DOMAIN  
read -p "🌐 Dominio Cloudfront (Enter si no): " CLOUDFRONT_DOMAIN  
read -p "🌐 Dominio No-IP / DDNS (Enter si no): " NOIP_DOMAIN  
  
SERVER_IP=$(curl -s ifconfig.me)  
  
CLOUDFLARE_STATUS="OFF"  
SSL_TUNNEL="OFF"  
DOMAIN_IP_MATCH="NO"  
PROXY_STATUS="UNKNOWN"  
if [[ -n "$SERVER_DOMAIN" ]]; then  
  
echo ""        
echo "🔍 Verificando dominio..."        
    
DOMAIN_IP=$(dig +short "$SERVER_DOMAIN" | head -n1)        
    
if [[ "$DOMAIN_IP" == "$SERVER_IP" ]]; then
    DOMAIN_IP_MATCH="YES"
    echo "✅ Dominio apunta al VPS"
    echo "ℹ️ El certificado SSL se podrá instalar desde el menú."

    SSL_TUNNEL="OFF"

else
    echo "❌ Dominio no apunta al VPS"
    SSL_TUNNEL="OFF"
fi
    
# Cloudflare detect        
CF=$(dig +short NS "$SERVER_DOMAIN" | grep cloudflare)        
    
[[ -n "$CF" ]] && CLOUDFLARE_STATUS="ON"  
  
fi  
BASE="/etc/movivip"  

mkdir -p $BASE/{protocolos,usuarios,sistema,logs}  

#==============================  

# CONFIG FINAL  

#==============================  

# Secreto maestro para derivar contraseñas de cuentas HWID.
# La contraseña de un usuario HWID = f(HWID + este secreto), nadie la elige.
# Si cambias este valor, TODAS las cuentas HWID dejan de funcionar.
HWID_SECRET=$(openssl rand -hex 24 2>/dev/null || (echo "mv$(date +%s%N)$RANDOM" | sha256sum | cut -c1-48))

cat > "$BASE/config.conf" <<EOF
SERVER_DOMAIN="$SERVER_DOMAIN"
CLOUDFRONT_DOMAIN="$CLOUDFRONT_DOMAIN"
NOIP_DOMAIN="$NOIP_DOMAIN"

#==============================
# SECRETO MAESTRO HWID
# Contraseña de cuenta HWID = derivada(HWID + HWID_SECRET).
# No compartirlo. Cambiarlo invalida todas las cuentas HWID.
#==============================

HWID_SECRET="$HWID_SECRET"

CLOUDFLARE_STATUS="$CLOUDFLARE_STATUS"
SSL_TUNNEL="ON"
DOMAIN_IP_MATCH="$DOMAIN_IP_MATCH"
PROXY_STATUS="$PROXY_STATUS"

#==============================
# TRAFICO BASE DEL VPS (bytes)
# Opcional: pon aqui el conteo acumulado que muestra tu proveedor
# para que el panel de consumo muestre el total real del VPS.
# Ej: 6.02 TB = 6020000000000 | 6.6 TB = 6600000000000
#==============================

VPS_TRAFFIC_BASE_RX=0
VPS_TRAFFIC_BASE_TX=0

AUTO_START=OFF

#==============================
# IDIOMA
#==============================

LANGUAGE="$INSTALL_LANG"

#==============================
# PROTOCOLOS
#==============================

OPENSSH=ON
SYSTEMDNS=OFF
WEBSOCKET=OFF
ZIPVPN=OFF
DROPBEAR=OFF
SSL=ON

BADVPN=OFF
UDP_CUSTOM=OFF

SLOWDNS=OFF
V2RAY=OFF

OPENVPN=OFF
SQUID=OFF
TROJAN=OFF
V2RAY=OFF
SHADOWSOCKS=OFF
SOCKS5=OFF
WEBMIN=OFF
FAIL2BAN=ON
BBR=OFF

#==============================
# LÍMITES DE CONSUMO DE RED (bytes)
# 0 = sin límite. Configura desde el menú Herramientas → [10]
#==============================

NET_LIMIT_IN=0
NET_LIMIT_OUT=0
EOF
#==============================  
  
# INSTALACIÓN FINAL  
  
#==============================  
  
echo ""  
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"  
echo "     🚀 FINALIZANDO INSTALACIÓN"  
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"  
  
sleep 2  
  
# permisos  
  
chmod -R 777 $BASE  

  
# comando menu  
  
cat > /usr/local/bin/menu <<EOF
#!/bin/bash
exec bash /etc/movivip/menu.sh
EOF
  
chmod +x /usr/local/bin/menu  
  
#==============================  
  
# RESUMEN FINAL  
  
#==============================  
  
clear  

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "        ✅ INSTALACIÓN COMPLETA"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🌐 Domain : $SERVER_DOMAIN"
echo "🔐 SSL    : $SSL_TUNNEL"
echo "☁️ CF     : $CLOUDFLARE_STATUS"
echo "🌐 Lang   : $INSTALL_LANG"
echo ""
source "$CONFIG" 2>/dev/null
echo "📡 Protocolos activos:"
echo "   🚀 OpenSSH    : $OPENSSH"
echo "   🔐 SSL/TLS    : $SSL"
echo "   🚪 Dropbear   : ${DROPBEAR:-OFF}"
echo "   ⚡ BadVPN     : ${BADVPN:-OFF}"
echo "   📡 UDP Custom : ${UDP_CUSTOM:-OFF}"
echo "   🌐 V2Ray      : ${V2RAY:-OFF}"
echo "   🔒 ZiVPN      : ${ZIPVPN:-OFF}"
echo "   🌍 SlowDNS    : ${SLOWDNS:-OFF}"
echo "   🐟 Squid      : ${SQUID:-OFF}"
echo "   🖥️ Webmin     : ${WEBMIN:-OFF}"
echo ""
echo ""
echo "📦 Estado de la instalación:"
echo "   ✅ Paquetes básicos instalados"
echo "   ✅ Sistema preparado correctamente"
echo "   🌐 Multi-idioma: 10 idiomas disponibles"
echo "   💡 Puedes cambiar protocolos desde el menú principal"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎬 YouTube: https://www.youtube.com/@MoviVIPNetwork"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📥 Descargando MoviVIP Network..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Asegurar que git está instalado
apt-get install -y git >/dev/null 2>&1

cd /root || exit 1

rm -rf /tmp/multi-script

git clone https://github.com/studioanime977/MoviVIPNetwork.git /tmp/multi-script || exit 1

mkdir -p /etc/movivip

cp -a /tmp/multi-script/. /etc/movivip/

chmod -R +x /etc/movivip

rm -rf /tmp/multi-script

if [[ ! -f /etc/movivip/menu.sh ]]; then
    echo "❌ ERROR: menu.sh no fue instalado"
    exit 1
fi

#==============================
# SELECTOR DE PROTOCOLOS
#==============================

CONFIG="/etc/movivip/config.conf"

install_dropbear() {
    echo ""
    echo "🚪 Instalando Dropbear..."
    apt-get install -y dropbear >/dev/null 2>&1
    # Configurar puertos
    DROPBEAR_PORT="${1:-443}"
    cat > /etc/default/dropbear <<DEOF
DROPBEAR_EXTRA_ARGS="-p ${DROPBEAR_PORT}"
NO_START=0
DROPBEAR_PORT=${DROPBEAR_PORT}
DEOF
    systemctl enable dropbear >/dev/null 2>&1
    systemctl restart dropbear >/dev/null 2>&1
    if systemctl is-active --quiet dropbear; then
        sed -i 's/^DROPBEAR=.*/DROPBEAR=ON/' "$CONFIG" 2>/dev/null
        sed -i "s/^DROPBEAR_PORT=.*/DROPBEAR_PORT=\"$DROPBEAR_PORT\"/" "$CONFIG" 2>/dev/null
        grep -q "^DROPBEAR_PORT=" "$CONFIG" 2>/dev/null || echo "DROPBEAR_PORT=\"$DROPBEAR_PORT\"" >> "$CONFIG"
        echo "   ✅ Dropbear ON (puerto $DROPBEAR_PORT)"
    else
        echo "   ❌ Dropbear no inició"
    fi
}

install_badvpn() {
    echo ""
    echo "⚡ Instalando BadVPN UDPGW..."
    apt-get install -y git cmake build-essential >/dev/null 2>&1
    rm -rf /tmp/badvpn
    git clone -q https://github.com/ambrop72/badvpn.git /tmp/badvpn 2>/dev/null
    cd /tmp/badvpn && mkdir -p build && cd build
    cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_BADVPN-UDPGW=1 >/dev/null 2>&1
    make -j$(nproc) >/dev/null 2>&1
    cp /tmp/badvpn/build/badvpn-udpgw/badvpn-udpgw /usr/bin/udpgw 2>/dev/null
    rm -rf /tmp/badvpn
    # Servicio 7200
    cat > /etc/systemd/system/badvpn-udpgw.service <<'SEOF'
[Unit]
Description=BadVPN UDP Gateway 7200
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/udpgw --listen-addr 127.0.0.1:7200 --max-clients 500
Restart=always

[Install]
WantedBy=multi-user.target
SEOF
    systemctl daemon-reload
    systemctl enable badvpn-udpgw >/dev/null 2>&1
    systemctl start badvpn-udpgw >/dev/null 2>&1
    if systemctl is-active --quiet badvpn-udpgw; then
        sed -i 's/^BADVPN=.*/BADVPN=ON/' "$CONFIG" 2>/dev/null
        echo "   ✅ BadVPN ON (puerto 7200)"
    else
        echo "   ❌ BadVPN no inició"
    fi
}

install_udpcustom() {
    echo ""
    echo "📡 Instalando UDP Custom..."
    apt-get install -y curl wget iptables libpam0g >/dev/null 2>&1
    sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1
    grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf 2>/dev/null || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)  URL="https://github.com/Depwisescript/UDP/raw/main/udp-custom-linux-amd64" ;;
        aarch64) URL="https://github.com/Depwisescript/UDP/raw/main/udp-custom-linux-arm" ;;
        *) echo "❌ Arquitectura $ARCH no soportada"; return ;;
    esac
    curl -L -s -f "$URL" -o /usr/bin/udp 2>/dev/null && chmod +x /usr/bin/udp
    if [[ ! -f /usr/bin/udp ]]; then
        echo "   ❌ Error descargando UDP Custom"; return
    fi
    cat > /usr/bin/config.json <<'UEOF'
{
    "listen": ":2100",
    "stream_buffer": 33554432,
    "receive_buffer": 83886080,
    "auth": {
        "mode": "passwords"
    }
}
UEOF
    cat > /etc/systemd/system/udp-custom.service <<'UEOF'
[Unit]
Description=UDP Custom Server MoviVIP
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/usr/bin
ExecStart=/usr/bin/udp server -exclude 2200,7300,7200,7100,323,10008,10004,5667 /usr/bin/config.json
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
UEOF
    systemctl daemon-reload
    systemctl enable udp-custom >/dev/null 2>&1
    systemctl start udp-custom >/dev/null 2>&1
    if systemctl is-active --quiet udp-custom; then
        sed -i 's/^UDP_CUSTOM=.*/UDP_CUSTOM=ON/' "$CONFIG" 2>/dev/null
        grep -q "^UDP_CUSTOM_PORT=" "$CONFIG" 2>/dev/null || echo "UDP_CUSTOM_PORT=2100" >> "$CONFIG"
        echo "   ✅ UDP Custom ON (puerto 2100)"
        echo "   📌 Para asignar usuarios: formato 1-PUERTO"
    else
        echo "   ❌ UDP Custom no inició"
    fi
}

install_v2ray() {
    echo ""
    echo "🌐 Instalando V2Ray/Xray..."
    apt-get install -y curl unzip jq socat cron bash-completion >/dev/null 2>&1
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install 2>/dev/null
    if [[ $? != 0 ]]; then
        echo "   ❌ Error instalando Xray"; return
    fi
    sed -i 's/^V2RAY=.*/V2RAY=ON/' "$CONFIG" 2>/dev/null
    echo "   ✅ V2Ray/Xray instalado"
    echo "   ⚙️ Configúralo desde Menú → Protocolos → [01] V2Ray"
}

install_zipvpn() {
    echo ""
    echo "🔒 Instalando ZiVPN..."
    apt-get install -y curl wget >/dev/null 2>&1
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)  URL="https://github.com/AmnesiaPod/TeamV2ray/raw/main/config/config.zip" ;;
        aarch64) URL="https://github.com/AmnesiaPod/TeamV2ray/raw/main/config/config.zip" ;;
        *) echo "❌ Arquitectura $ARCH no soportada"; return ;;
    esac
    mkdir -p /etc/zivpn
    curl -L -s -f "$URL" -o /tmp/zivpn.zip 2>/dev/null && unzip -o /tmp/zivpn.zip -d /etc/zivpn/ >/dev/null 2>&1
    rm -f /tmp/zivpn.zip
    sed -i 's/^ZIPVPN=.*/ZIPVPN=ON/' "$CONFIG" 2>/dev/null
    echo "   ✅ ZiVPN ON"
    echo "   ⚙️ Configúralo desde Menú → Protocolos → [02] ZiVPN"
}

install_slowdns() {
    echo ""
    echo "🌍 Instalando SlowDNS..."
    apt-get install -y curl wget dnsdist iptables dnsutils ca-certificates >/dev/null 2>&1
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)  BIN_NAME="dnstt-server-linux-amd64" ;;
        aarch64|arm64) BIN_NAME="dnstt-server-linux-arm64" ;;
        *) echo "❌ Arquitectura $ARCH no soportada"; return ;;
    esac
    mkdir -p /etc/slowdns
    MIRRORS=(
        "https://dnstt.network/$BIN_NAME"
        "https://github.com/bugfloyd/dnstt-deploy/raw/main/bin/$BIN_NAME"
    )
    DOWNLOADED=0
    for URL in "${MIRRORS[@]}"; do
        if curl -L -k -s -f "$URL" -o /etc/slowdns/slowdns 2>/dev/null; then
            chmod +x /etc/slowdns/slowdns
            DOWNLOADED=1; break
        fi
    done
    if [[ $DOWNLOADED -eq 1 ]]; then
        sed -i 's/^SLOWDNS=.*/SLOWDNS=ON/' "$CONFIG" 2>/dev/null
        echo "   ✅ SlowDNS Server descargado"
        echo "   ⚙️ Configúralo desde Menú → Protocolos → [13] SlowDNS"
        echo "   📌 Necesitas: dominio + nameserver"
    else
        echo "   ❌ Error descargando SlowDNS"
    fi
}

install_squid() {
    echo ""
    echo "🐟 Instalando Squid Proxy..."
    apt-get install -y squid >/dev/null 2>&1
    systemctl enable squid >/dev/null 2>&1
    systemctl restart squid >/dev/null 2>&1
    if systemctl is-active --quiet squid; then
        sed -i 's/^SQUID=.*/SQUID=ON/' "$CONFIG" 2>/dev/null
        echo "   ✅ Squid Proxy ON (puerto 3128)"
    else
        echo "   ❌ Squid no inició"
    fi
}

install_webmin() {
    echo ""
    echo "🖥️ Instalando Webmin..."
    apt-get install -y curl wget >/dev/null 2>&1
    curl -o /tmp/webmin-setup-repo.sh https://raw.githubusercontent.com/webmin/webmin/master/webmin-setup-repo.sh 2>/dev/null
    sh /tmp/webmin-setup-repo.sh -y >/dev/null 2>&1
    apt-get install -y webmin >/dev/null 2>&1
    rm -f /tmp/webmin-setup-repo.sh
    if systemctl is-active --quiet webmin 2>/dev/null; then
        sed -i 's/^WEBMIN=.*/WEBMIN=ON/' "$CONFIG" 2>/dev/null
        echo "   ✅ Webmin ON (puerto 10000)"
    else
        echo "   ⚠️ Webmin instalado, puerta 10000"
        sed -i 's/^WEBMIN=.*/WEBMIN=ON/' "$CONFIG" 2>/dev/null
    fi
}

# --- Menu de selección ---
clear
W=62
HEADER="SELECCIONAR PROTOCOLOS A INSTALAR"
SEP=$(printf '━%.0s' $(seq 1 $W))
CTA="\033[1;96m"
CTB="\033[1;93m"
CTD="\033[1;97m"
CTG="\033[1;90m"
CTR="\033[0m"
CTG1="\033[1;92m"
CTE="\033[1;91m"

echo -e "${CTA}╔$(printf '═%.0s' $(seq 1 $((W-2))))╗${CTR}"
echo -e "${CTA}║${CTR}${CTB}$(printf '%*s' $(((${#HEADER}+W-2)/2)) '')${HEADER}$(printf '%*s' $(((W-1-${#HEADER})/2)) '')${CTR}${CTA}║${CTR}"
echo -e "${CTA}╠$(printf '═%.0s' $(seq 1 $((W-2))))╣${CTR}"
echo -e "${CTA}║${CTR}${CTD}  Los protocolos marcados con ✅ ya están activos.     ${CTA}║${CTR}"
echo -e "${CTA}║${CTR}${CTD}  Selecciona los que deseas instalar ahora.           ${CTA}║${CTR}"
echo -e "${CTA}╚$(printf '═%.0s' $(seq 1 $((W-2))))╝${CTR}"
echo ""
echo -e "  ${CTG1}✅ [1]${CTR}  SSL/TLS         ${CTD}Ya instalado (Puerto 443)${CTR}"
echo -e "  ${CTG1}✅ [2]${CTR}  OpenSSH         ${CTD}Ya instalado (Puerto 22)${CTR}"
echo -e "  ${CTG1}   [3]${CTR}  Dropbear        ${CTD}SSH en puertos 80/143/443${CTR}"
echo -e "  ${CTG1}   [4]${CTR}  BadVPN UDPGW    ${CTD}VoIP/Puente UDP (Puerto 7200)${CTR}"
echo -e "  ${CTG1}   [5]${CTR}  UDP Custom      ${CTD}Tunnel UDP (Puerto 2100)${CTR}"
echo -e "  ${CTG1}   [6]${CTR}  V2Ray/Xray      ${CTD}WebSocket+gRPC+XTLS${CTR}"
echo -e "  ${CTG1}   [7]${CTR}  ZiVPN           ${CTD}Protocolo premium UDP${CTR}"
echo -e "  ${CTG1}   [8]${CTR}  SlowDNS         ${CTD}DNS Tunnel (requiere dominio)${CTR}"
echo -e "  ${CTG1}   [9]${CTR}  Squid Proxy     ${CTD}Proxy HTTP (Puerto 3128)${CTR}"
echo -e "  ${CTG1}   [10]${CTR} Webmin          ${CTD}Panel administración (Puerto 10000)${CTR}"
echo -e "  ${CTG1}   [11]${CTR} Todos           ${CTD}Instalar TODOS los protocolos${CTR}"
echo -e "  ${CTG1}   [12]${CTR} Ninguno         ${CTD}Solo lo básico (OpenSSH+SSL)${CTR}"
echo ""
echo -e "  ${CTG}Escribe los números separados por espacio:${CTR}"
echo -e "  ${CTG}Ejemplo: 3 4 5 6  →  Instala Dropbear+BadVPN+UDP+V2Ray${CTR}"
echo ""
read -rp "  ➜ Selección: " SELECTION_INPUT
echo ""

# Si viene del pipe (instalación automática), usar todo
if [[ -z "$SELECTION_INPUT" ]]; then
    SELECTION_INPUT="12"
fi

# Detectar si seleccionó "todos"
SELECTED=""
if echo "$SELECTION_INPUT" | grep -qE '(^| )11( |$)'; then
    SELECTED="1 2 3 4 5 6 7 8 9 10"
else
    SELECTED="$SELECTION_INPUT"
fi

# Filtrar protocolos ya instalados (1 y 2)
INSTALLED_PROTOCOLS=""
for NUM in $SELECTED; do
    case "$NUM" in
        1) INSTALLED_PROTOCOLS="$INSTALLED_PROTOCOLS SSL/TLS(443)" ;;
        2) INSTALLED_PROTOCOLS="$INSTALLED_PROTOCOLS OpenSSH(22)" ;;
        3) install_dropbear ;;
        4) install_badvpn ;;
        5) install_udpcustom ;;
        6) install_v2ray ;;
        7) install_zipvpn ;;
        8) install_slowdns ;;
        9) install_squid ;;
        10) install_webmin ;;
        12) ;;
        *) ;;
    esac
done

# Resumen de instalación
echo ""
echo -e "${CTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CTR}"
echo -e "${CTB}   📋 RESUMEN DE INSTALACIÓN${CTR}"
echo -e "${CTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CTR}"
if [[ -n "$INSTALLED_PROTOCOLS" ]]; then
    echo -e "${CTG1}   ✅ Ya activos:${CTR}$INSTALLED_PROTOCOLS"
fi

# Leer estado actual
source "$CONFIG" 2>/dev/null
[[ "$DROPBEAR" == "ON" ]]   && echo -e "${CTG1}   ✅${CTR} Dropbear ON"     || true
[[ "$BADVPN" == "ON" ]]     && echo -e "${CTG1}   ✅${CTR} BadVPN ON"       || true
[[ "$UDP_CUSTOM" == "ON" ]] && echo -e "${CTG1}   ✅${CTR} UDP Custom ON"   || true
[[ "$V2RAY" == "ON" ]]      && echo -e "${CTG1}   ✅${CTR} V2Ray/Xray ON"  || true
[[ "$ZIPVPN" == "ON" ]]     && echo -e "${CTG1}   ✅${CTR} ZiVPN ON"       || true
[[ "$SLOWDNS" == "ON" ]]    && echo -e "${CTG1}   ✅${CTR} SlowDNS ON"     || true
[[ "$SQUID" == "ON" ]]      && echo -e "${CTG1}   ✅${CTR} Squid ON"       || true
[[ "$WEBMIN" == "ON" ]]     && echo -e "${CTG1}   ✅${CTR} Webmin ON"       || true
echo -e "${CTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CTR}"
echo ""

#==============================
# CONFIGURAR FAIL2BAN (seguridad)
#==============================

echo "🛡️ Configurando fail2ban..."

# Modo --install = no interactivo (sin esperar input del usuario)
# timeout = protección extra contra cualquier cuelgue futuro
if [[ -f /etc/movivip/herramientas/fail2ban.sh ]]; then
    timeout 120 bash /etc/movivip/herramientas/fail2ban.sh --install >/dev/null 2>&1
fi

timeout 30 systemctl enable fail2ban >/dev/null 2>&1 || true
timeout 30 systemctl restart fail2ban >/dev/null 2>&1 || true

echo "✅ Fail2ban configurado."

#==============================
# CONSUMO DE RED — cron (base de datos vacía)
#==============================

echo "📊 Activando monitoreo de consumo de red..."

if [[ -f /etc/movivip/herramientas/network_snapshot.sh ]]; then
    chmod +x /etc/movivip/herramientas/network_snapshot.sh
    bash /etc/movivip/herramientas/network_snapshot.sh >/dev/null 2>&1

    # Cron: snapshot cada minuto (persistente)
    if ! crontab -l 2>/dev/null | grep -q "network_snapshot.sh"; then
        (crontab -l 2>/dev/null; echo "* * * * * bash /etc/movivip/herramientas/network_snapshot.sh >/dev/null 2>&1") | crontab -
    fi

    # Systemd timer opcional para arranque (persistencia ante reinicios)
    if [[ ! -f /etc/systemd/system/movivip-net-state.service ]]; then
        cat > /etc/systemd/system/movivip-net-state.service <<'EOF'
[Unit]
Description=MoviVIP Network State - consumo de red
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash /etc/movivip/herramientas/network_snapshot.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable movivip-net-state.service >/dev/null 2>&1
    fi
fi

echo "✅ Monitoreo de consumo activado."

#==============================
# CONSUMO POR USUARIO — cron (online.sh --quiet)
#==============================

echo "👁️ Activando monitoreo de consumo por usuario..."

if [[ -f /etc/movivip/usuarios/online.sh ]]; then
    chmod +x /etc/movivip/usuarios/online.sh
    bash /etc/movivip/usuarios/online.sh --quiet >/dev/null 2>&1

    # Archivo de límites de conexiones (USUARIO=MAXCONN, 0=ilimitado)
    mkdir -p /etc/movivip/sistema 2>/dev/null
    touch /etc/movivip/sistema/limites_conexiones.conf 2>/dev/null

    # Cron: acumular consumo + cortar conexiones excedentes cada 2 minutos
    if ! crontab -l 2>/dev/null | grep -q "usuarios/online.sh --quiet"; then
        (crontab -l 2>/dev/null; echo "*/2 * * * * bash /etc/movivip/usuarios/online.sh --quiet >/dev/null 2>&1") | crontab -
    fi
fi

echo "✅ Monitoreo de consumo por usuario activado."

cat > /etc/profile.d/MoviVIP-banner.sh << 'EOF'
#!/bin/bash

[[ $- != *i* ]] && return

clear

SERVER=$(hostname)
DOMAIN="-"

if [[ -f /etc/movivip/config.conf ]]; then
    source /etc/movivip/config.conf
    DOMAIN="${SERVER_DOMAIN:-"-"}"
fi
UPTIME=$(uptime -p | sed 's/up //')
FECHA=$(date +"%d-%m-%Y")
HORA=$(date +"%H:%M:%S")

# Centrado automático
center() {
    local text="$1"
    local cols
    cols=$(tput cols 2>/dev/null || echo 80)
    local len=$(( ${#text} ))
    local pad=$(( (cols - len) / 2 ))
    [[ $pad -lt 0 ]] && pad=0
    printf "%${pad}s" ""
    echo "$text"
}

center "=============================================================="
center ""
center " __  __       _ _   _   _      ____            _       _   "
center "|  \/  |_   _| | |_(_) | |    / ___|  ___ _ __(_)_ __ | |_ "
center "| |\/| | | | | | __| | | |    \___ \ / __| '__| | '_ \| __|"
center "| |  | | |_| | | |_| | | |___  ___) | (__| |  | | |_) | |_ "
center "|_|  |_|\__,_|_|\__|_| |_____| |____/ \___|_|  |_| .__/ \__|"
center "                                                 |_|       "
center ""
center "🚀 MOVIVIP NETWORK — PREMIUM 🚀"
center ""
center "Servidor : $SERVER"
center "Dominio  : $DOMAIN"
center "Uptime   : $UPTIME"
center "Fecha    : $FECHA"
center "Hora     : $HORA"
center ""
center "=============================================================="

if [[ $EUID -ne 0 ]]; then
    center "👤 Usuario : $(whoami)"
    center "🔒 No eres root."
    center "👉 Ejecuta: sudo -i"
else
    center "👑 Usuario : root"
    center "👉 Escribe: menu"
fi

center ""
center "✨ Gracias por usar nuestros servicios ✨"
center "🛡SISTEMA PROTEGIDO POR MOVIVIP NETWORK🛡"
center ""
EOF

chmod +x /etc/profile.d/MoviVIP-banner.sh

#==============================
# BANNER DE LOGIN SSH (issue.net) — con SELLO DE PROTECCIÓN fijo
# El usuario puede añadir su propio contenido desde:
#   Usuarios → [06] 📢 Banner SSH / Dropbear
# El sello "SISTEMA PROTEGIDO POR MOVIVIP NETWORK" es corto a
# propósito para no exceder el límite que desactiva dropbear.
#==============================

cat > /etc/issue.net << 'EOF'
<html>
<body style='margin:0;padding:0;background:transparent'>
<div style='text-align:center'><span style="font-family:'Comic Sans MS',cursive,sans-serif;font-weight:bold;">

<br><br>
<font color='#00ffff'><small><i>🛡SISTEMA PROTEGIDO POR MOVIVIP NETWORK🛡</i></small></font>
</span></div>
</body>
</html>
EOF

# Desactivar Banner en sshd (mantener login limpio)
if grep -q "^Banner" /etc/ssh/sshd_config 2>/dev/null; then
    sed -i 's|^Banner.*|Banner /etc/issue.net|' /etc/ssh/sshd_config
else
    echo "Banner /etc/issue.net" >> /etc/ssh/sshd_config
fi

if [[ -f /etc/default/dropbear ]] && ! grep -q "DROPBEAR_BANNER" /etc/default/dropbear; then
    echo 'DROPBEAR_BANNER="/etc/issue.net"' >> /etc/default/dropbear
fi

systemctl restart ssh sshd 2>/dev/null
systemctl restart dropbear dropbear_custom 2>/dev/null

echo "✅ Banner de login en blanco (configúralo desde Usuarios → [06])."

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ MoviVIP Network instalado."
echo "🌐 Idioma: $INSTALL_LANG"
echo "🎬 YouTube: https://www.youtube.com/@MoviVIPNetwork"
echo "🔄 El servidor se reiniciará en 10 segundos..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

sleep 10

reboot
