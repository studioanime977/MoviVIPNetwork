#!/bin/bash

if [[ -d "/etc/movivip" ]]; then
    echo " Actualización detectada..."
    if [[ -d "/etc/movivip/.git" ]]; then
        cd /etc/movivip || exit 1
        git reset --hard
        git pull origin main || git pull
        echo " Sistema actualizado correctamente"
        exit 0
    else
        cd /
        rm -rf /etc/movivip
    fi
fi

clear
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "      🛡️ MoviVIP Network 🛡️"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
if [[ $EUID -ne 0 ]]; then  
echo "❌ Necesita root"  
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
  
clear  
  
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"  
echo "        CONFIGURACIÓN DEL SERVIDOR"  
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"  
  
read -p "🌐 Dominio Cloudflare: " SERVER_DOMAIN  
read -p "🌐 Dominio Cloudfront (Enter si no): " CLOUDFRONT_DOMAIN  
  
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
  
cat > "$BASE/config.conf" <<EOF
SERVER_DOMAIN="$SERVER_DOMAIN"
CLOUDFRONT_DOMAIN="$CLOUDFRONT_DOMAIN"

CLOUDFLARE_STATUS="$CLOUDFLARE_STATUS"
SSL_TUNNEL="$SSL_TUNNEL"
DOMAIN_IP_MATCH="$DOMAIN_IP_MATCH"
PROXY_STATUS="$PROXY_STATUS"

AUTO_START=OFF

#==============================
# PROTOCOLOS
#==============================

OPENSSH=ON
SYSTEMDNS=OFF
WEBSOCKET=OFF
ZIPVPN=OFF
DROPBEAR=OFF
SSL=OFF

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
# SLOWDNS
#==============================

INSTALL_SLOWDNS="n"

echo ""
echo "ℹ️ SlowDNS no se instala durante la instalación inicial."
echo "💡 Puedes instalarlo y configurarlo más tarde desde el menú."
echo ""
  
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
echo ""  
echo ""
echo "📦 Estado de la instalación:"
echo "   ✅ Paquetes básicos instalados"
echo "   ✅ Sistema preparado correctamente"
echo "   ⚙️ Ningún protocolo fue instalado automáticamente"
echo "   💡 Instala los protocolos desde el menú principal"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"  
echo "📥 Descargando MoviVIP Network..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

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
# CONFIGURAR FAIL2BAN (seguridad)
#==============================

echo "🛡️ Configurando fail2ban..."

if [[ -f /etc/movivip/herramientas/fail2ban.sh ]]; then
    bash /etc/movivip/herramientas/fail2ban.sh > /dev/null 2>&1
fi

systemctl enable fail2ban >/dev/null 2>&1
systemctl restart fail2ban

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

    # Cron: acumular consumo cada 5 minutos (persistente)
    if ! crontab -l 2>/dev/null | grep -q "usuarios/online.sh --quiet"; then
        (crontab -l 2>/dev/null; echo "*/5 * * * * bash /etc/movivip/usuarios/online.sh --quiet >/dev/null 2>&1") | crontab -
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
center "🛡 SISTEMA PROTEGIDO POR MOVIVIP NETWORK"
center ""
EOF

chmod +x /etc/profile.d/MoviVIP-banner.sh

#==============================
# BANNER DE LOGIN SSH (issue.net) — marca centrada
#==============================

cat > /etc/issue.net <<'EOF'
<html>
<body style='margin:0;padding:0;background:transparent'>
<div style='text-align:center'><span style="font-family:'Comic Sans MS',cursive,sans-serif;font-weight:bold;">

<br><br>
<font color='#FFD700'><big><big>🛡️ MoviVIP Network 🛡️</big></big></font><br>
<font color='#29b6f6'>════════════════════════════</font><br><br>

<font color='#00FFCC'><big>💠 MOVIVIP NETWORK 💠</big></font><br>
<font color='#00ffff'><b>🌎 OPERADOR INTERNACIONAL</b></font><br>
<font color='#00FFAA'><b>CONECTIVIDAD PREMIUM + VPS</b></font><br><br>

<font color='#29b6f6'>════════════════════════════</font><br><br>
<font color='#00ff00'><big>✨ Gracias por usar nuestros servicios ✨</big></font><br>
<font color='#00ffff'><small><i>SISTEMA PROTEGIDO POR MOVIVIP NETWORK</i></small></font>

</span></div>
</body>
</html>
EOF

# Activar banner en SSH y Dropbear
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

echo "✅ Banner de marca instalado."

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ MoviVIP Network instalado."
echo "🔄 El servidor se reiniciará en 10 segundos..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

sleep 10

reboot
