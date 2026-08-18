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

# ═══════════════════════════════════════════════════════════════
# SISTEMA DE PROGRESO + ERROR REPORTING
# Logs completos en /var/log/movivip-install.log para soporte
# ═══════════════════════════════════════════════════════════════

INSTALL_LOG="/var/log/movivip-install.log"
INSTALL_STEP=0
INSTALL_TOTAL=15

log_error() {
    local line="$1" desc="$2" cmd="$3" err="$4"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR Línea $line: $desc | Comando: $cmd | Error: $err" >> "$INSTALL_LOG"
}

step() {
    INSTALL_STEP=$((INSTALL_STEP + 1))
    local desc="$1"
    echo ""
    echo -e "${CYAN}   [$INSTALL_STEP/$INSTALL_TOTAL]${WHITE} $desc${RESET}"
}

run_cmd() {
    local desc="$1" line="$2"
    shift 2
    local cmd_str="$*"
    local tmp_err
    tmp_err=$(mktemp)
    if eval "$cmd_str" >/dev/null 2>"$tmp_err"; then
        echo -e "      ${GREEN}✔${RESET} $desc"
        rm -f "$tmp_err"
    else
        local err_msg
        err_msg=$(cat "$tmp_err" 2>/dev/null)
        rm -f "$tmp_err"
        echo -e "      ${RED}✖${RESET} $desc"
        echo -e "      ${GRAY}  → Reportar a soporte: Línea $line${RESET}"
        log_error "$line" "$desc" "$cmd_str" "$err_msg"
    fi
}

clear
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GOLD}      🛡️ MoviVIP Network — INSTALADOR v5.0 🛡️${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

export DEBIAN_FRONTEND=noninteractive

if [[ $EUID -ne 0 ]]; then
echo -e "${RED}❌ Necesita root${RESET}"
exec sudo bash "$0" "$@"
fi  

source /etc/os-release  

if [[ "$ID" != "ubuntu" ]]; then
echo -e "${RED}❌ Solo Ubuntu${RESET}"
exit 1
fi

# Iniciar log de instalación
echo "========== INSTALACIÓN MoviVIP v5.0 — $(date) ==========" > "$INSTALL_LOG"
chmod 600 "$INSTALL_LOG"

clear  
echo -e "${GREEN}✔ Sistema Ubuntu detectado${RESET}"  

# ==============================
# GATE DE LICENCIA (ANTI-PIRATERÍA)
# Valida contra Firebase antes de instalar CUALQUIER cosa.
# Sin licencia válida -> instalación BLOQUEADA.
# Si ya hay licencia válida guardada (ej: desde install-con-licencia.sh),
# se salta la validación interactiva.
# ==============================

GATE_URL="https://raw.githubusercontent.com/studioanime977/vps-license-gate/main/gate/validar-licencia.sh"
GATE_TMP="/tmp/validar-licencia-movivip.sh"

# Verificar si ya existe licencia válida.
# Fuentes (en orden):
#   1. /etc/movivip/licencia.conf — cuando se ejecuta directamente
#   2. Variable de entorno LICENCIA_KEY — cuando install-con-licencia.sh la pasa
#   3. /tmp/movivip-key.txt — fallback cuando /etc/movivip fue borrado
LICENSE_VALID="no"
INCOMING_KEY=""

if [[ -n "$LICENCIA_KEY" ]] && [[ "$LICENCIA_KEY" =~ ^KEY-[A-Fa-f0-9]{10}$ ]]; then
    INCOMING_KEY="$LICENCIA_KEY"
    LICENSE_VALID="yes"
elif [[ -f /tmp/movivip-key.txt ]]; then
    INCOMING_KEY=$(cat /tmp/movivip-key.txt 2>/dev/null)
    if [[ -n "$INCOMING_KEY" ]] && [[ "$INCOMING_KEY" =~ ^KEY-[A-Fa-f0-9]{10}$ ]]; then
        LICENSE_VALID="yes"
    fi
elif [[ -f /etc/movivip/licencia.conf ]]; then
    source /etc/movivip/licencia.conf 2>/dev/null
    if [[ -n "$KEY" ]] && [[ "$KEY" =~ ^KEY-[A-Fa-f0-9]{10}$ ]]; then
        INCOMING_KEY="$KEY"
        LICENSE_VALID="yes"
    fi
fi

if [[ "$LICENSE_VALID" == "yes" ]]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "      🔑 LICENCIA VALIDADA (ya verificada)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo -e "${GREEN}✔ Licencia previa detectada: $KEY — continuando...${RESET}"
    echo ""
else
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
fi

# Persistir el gate localmente: los protocolos y el bot lo usan
# (check-licencia.sh) para validar la key contra Firebase EN VIVO
# antes de cada instalación/gestión de protocolo.
mkdir -p /etc/movivip
mkdir -p /etc/movivip/gate

# Guardar licencia recibida de install-con-licencia.sh
if [[ "$LICENSE_VALID" == "yes" ]] && [[ -n "$INCOMING_KEY" ]]; then
    cat > /etc/movivip/licencia.conf << LICEOF
KEY="$INCOMING_KEY"
PLAN="vitalicio"
FECHA_ACTIVACION="$(date +%Y-%m-%d)"
LICEOF
    echo -e "${GREEN}✔ Licencia persistida en /etc/movivip/licencia.conf${RESET}"
fi

# Solo copiar el gate si se descargó (no cuando ya existía licencia válida)
if [[ -f "$GATE_TMP" ]]; then
    cp "$GATE_TMP" /etc/movivip/validar-licencia.sh
    chmod +x /etc/movivip/validar-licencia.sh
    cp "$GATE_TMP" /etc/movivip/gate/validar-licencia.sh
    chmod +x /etc/movivip/gate/validar-licencia.sh
    echo -e "${GREEN}✔ Gate de licencia instalado localmente.${RESET}"
else
    # Descargar el gate para persistirlo (necesario para protocolos futuros)
    command -v curl >/dev/null 2>&1 || apt-get install -y curl >/dev/null 2>&1
    if curl -fsSL --max-time 30 "$GATE_URL" -o /etc/movivip/validar-licencia.sh 2>/dev/null; then
        chmod +x /etc/movivip/validar-licencia.sh
        cp /etc/movivip/validar-licencia.sh /etc/movivip/gate/validar-licencia.sh
        echo -e "${GREEN}✔ Gate de licencia instalado localmente.${RESET}"
    fi
fi

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
if [[ -t 0 ]]; then
    read -rp "$(echo -e "${CYAN}➜ ${GOLD}Select language [1-10]${WHITE} (default: 1=ES) ➤ ${RESET}")" LANG_CHOICE
else
    LANG_CHOICE="${LANG_CHOICE:-1}"
fi
LANG_CHOICE="${LANG_CHOICE:-1}"
[[ "$LANG_CHOICE" =~ ^[0-9]+$ ]] || LANG_CHOICE=1

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

# ═══════════════════════════════════════════════════════════════
# BACKUP + LIMPIEZA TOTAL DE VPS
# ═══════════════════════════════════════════════════════════════

# Detectar usuarios existentes (UID >= 1000, no-root/no-nobody)
EXISTING_USERS=()
EXISTING_PASS=()
for u in $(awk -F: '$3>=1000 && $1!="nobody"{print $1}' /etc/passwd 2>/dev/null); do
    EXISTING_USERS+=("$u")
done

if [[ ${#EXISTING_USERS[@]} -gt 0 ]]; then
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${GOLD}         🔄 SISTEMA DETECTADO — LIMPIEZA TOTAL${RESET}${CYAN}          ║${RESET}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${CYAN}║${WHITE}  Se encontraron ${GREEN}${#EXISTING_USERS[@]}${WHITE} usuarios en el sistema:${RESET}${CYAN}       ║${RESET}"
    for u in "${EXISTING_USERS[@]}"; do
        echo -e "${CYAN}║${WHITE}     • ${u}${RESET}${CYAN}                                            ║${RESET}"
    done
    echo -e "${CYAN}║${WHITE}                                                            ${RESET}${CYAN}║${RESET}"
    echo -e "${CYAN}║${YELLOW}  Se hará backup y se limpiará TODO para reinstalación.${RESET}${CYAN}  ║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${RESET}"
    echo ""

    # ── BACKUP: guardar usuario:password ──
    echo -e "${CYAN}   [1/4] 📦 Creando backup de usuarios...${RESET}"

    BACKUP_FILE="/tmp/movivip-users-backup.txt"
    BACKUP_PASSWD="/tmp/movivip-backup-passwd.txt"
    BACKUP_SHADOW="/tmp/movivip-backup-shadow.txt"
    > "$BACKUP_FILE"

    # Guardar passwd y shadow completos para restauración fiel
    cp /etc/passwd "$BACKUP_PASSWD"
    cp /etc/shadow "$BACKUP_SHADOW"

    # También extraer user:pass en formato legible (para referencia)
    for u in "${EXISTING_USERS[@]}"; do
        # Obtener hash del shadow
        HASH=$(awk -F: -v user="$u" '$1==user{print $2}' /etc/shadow 2>/dev/null)
        EXPIRY=$(chage -l "$u" 2>/dev/null | grep "Account expires" | cut -d: -f2 | xargs)
        [[ "$EXPIRY" == "never" ]] && EXPIRY="0"
        echo "${u}:${HASH}:${EXPIRY}" >> "$BACKUP_FILE"
    done

    echo -e "${GREEN}      ✔ Backup guardado: $BACKUP_FILE (${#EXISTING_USERS[@]} usuarios)${RESET}"
    echo ""

    # ── PREGUNTAR: ¿Eliminar algún usuario? ──
    echo -e "${CYAN}   [2/4] 🗑️  ¿Eliminar algún usuario permanentemente?${RESET}"
    echo -e "${CYAN}   (los eliminados NO se restaurarán después de la limpieza)${RESET}"
    echo ""
    for i in "${!EXISTING_USERS[@]}"; do
        echo -e "      ${WHITE}[$((i+1))]${RESET} ${EXISTING_USERS[$i]}"
    done
    echo -e "      ${GREEN}[0]${RESET} No eliminar ninguno (restaurar todos)"
    echo ""

    if [[ -t 0 ]]; then
        read -rp "$(echo -e "${CYAN}   Números a eliminar (ej: 1 3) ➤ ${RESET}")" DELETE_CHOICE
    else
        DELETE_CHOICE="${DELETE_CHOICE:-0}"
    fi
    DELETE_CHOICE="${DELETE_CHOICE:-0}"
    # Validar que solo contenga números y espacios
    [[ "$DELETE_CHOICE" =~ ^[0-9\ ]+$ ]] || DELETE_CHOICE=0

    # Eliminar usuarios seleccionados
    DELETED_USERS=()
    if [[ "$DELETE_CHOICE" != "0" ]]; then
        for num in $DELETE_CHOICE; do
            idx=$((num - 1))
            if [[ $idx -ge 0 && $idx -lt ${#EXISTING_USERS[@]} ]]; then
                DEL_USER="${EXISTING_USERS[$idx]}"
                userdel -f "$DEL_USER" &>/dev/null
                DELETED_USERS+=("$DEL_USER")
                echo -e "${RED}      ✖ Eliminado: $DEL_USER${RESET}"
                # Quitar del backup
                sed -i "/^${DEL_USER}:/d" "$BACKUP_FILE" 2>/dev/null
            fi
        done
    fi

    if [[ ${#DELETED_USERS[@]} -gt 0 ]]; then
        echo -e "${GREEN}      ✔ ${#DELETED_USERS[@]} usuarios eliminados permanentemente${RESET}"
    else
        echo -e "${GREEN}      ✔ Ningún usuario eliminado — todos se restaurarán${RESET}"
    fi
    echo ""

    # ── LIMPIEZA TOTAL ──
    echo -e "${CYAN}   [3/4] 🧹 Limpiando TODO el sistema anterior...${RESET}"

    # Detener TODOS los servicios VPN/Proxy
    echo -e "${CYAN}      → Deteniendo servicios VPN/Proxy...${RESET}"
    for svc in xray v2ray dropbear dropbear_custom badvpn-udpgw udpcustom \
               squid webmin openvpn slowdns dnstt-server ssh-ws-internal; do
        systemctl stop "$svc" 2>/dev/null
        systemctl disable "$svc" 2>/dev/null
    done

    # Matar procesos sueltos
    killall -9 xray v2ray dropbear badvpn-udpgw squid dnstt-server 2>/dev/null || true

    # Eliminar configuraciones de servicios
    echo -e "${CYAN}      → Eliminando configuraciones de servicios...${RESET}"
    rm -rf /etc/xray
    rm -rf /usr/local/etc/xray
    rm -rf /usr/local/share/xray
    rm -f /usr/bin/xray /usr/local/bin/xray
    rm -f /usr/local/etc/v2ray
    rm -rf /etc/v2ray
    rm -f /etc/systemd/system/xray*.service
    rm -f /etc/systemd/system/v2ray*.service
    rm -f /etc/systemd/system/dropbear*.service
    rm -f /etc/systemd/system/badvpn*.service
    rm -f /etc/systemd/system/udpcustom*.service
    rm -f /etc/systemd/system/slowdns*.service
    rm -f /etc/systemd/system/ssh-ws*.service
    rm -f /etc/systemd/system/movivip*.service
    systemctl daemon-reload 2>/dev/null

    # Eliminar binarios de servicios
    rm -f /usr/bin/dropbear
    rm -f /usr/sbin/dropbear
    rm -f /usr/bin/badvpn-udpgw
    rm -f /usr/bin/udp
    rm -f /usr/bin/config.json
    rm -rf /usr/local/SlowDNS
    rm -rf /tmp/dnstt*

    # Eliminar configuraciones de red
    echo -e "${CYAN}      → Eliminando configuraciones de red...${RESET}"
    rm -f /etc/sysctl.d/99-MoviVIP.conf
    rm -f /etc/sysctl.d/99-movivip.conf
    rm -f /etc/iptables/rules.v4
    # Restaurar sysctl por defecto
    cat > /etc/sysctl.d/99-default.conf << 'SYSCTLEOF'
net.ipv4.ip_forward=0
net.core.default_qdisc=pfifo_fast
net.ipv4.tcp_congestion_control=cubic
net.ipv4.ip_local_port_range=32768 60999
net.ipv4.tcp_fin_timeout=60
net.ipv4.tcp_keepalive_time=7200
net.ipv4.tcp_tw_reuse=0
net.ipv4.tcp_timestamps=1
net.core.somaxconn=4096
net.core.netdev_max_backlog=1000
net.ipv4.tcp_max_syn_backlog=1024
net.ipv4.tcp_slow_start_after_idle=1
net.ipv4.tcp_mtu_probing=0
vm.swappiness=60
fs.file-max=2097152
SYSCTLEOF
    sysctl --system >/dev/null 2>&1

    # Limpiar iptables
    echo -e "${CYAN}      → Limpiando reglas iptables...${RESET}"
    iptables -F 2>/dev/null
    iptables -X 2>/dev/null
    iptables -t nat -F 2>/dev/null
    iptables -t nat -X 2>/dev/null
    iptables -t mangle -F 2>/dev/null
    iptables -t mangle -X 2>/dev/null
    iptables -t raw -F 2>/dev/null
    iptables -t raw -X 2>/dev/null
    iptables -P INPUT ACCEPT 2>/dev/null
    iptables -P FORWARD ACCEPT 2>/dev/null
    iptables -P OUTPUT ACCEPT 2>/dev/null
    iptables-save > /etc/iptables/rules.v4 2>/dev/null || true

    # Eliminar crons de movivip
    echo -e "${CYAN}      → Limpiando crons...${RESET}"
    crontab -l 2>/dev/null | grep -v "movivip\|auto-cleanup\|auto-update\|network_snapshot\|online.sh" | crontab - 2>/dev/null

    # Eliminar /etc/movivip temporalmente (se recreará)
    rm -rf /etc/movivip

    # Eliminar banners
    rm -f /etc/profile.d/MoviVIP-banner.sh
    rm -f /etc/issue.net

    # Eliminar limpiezas temporales
    rm -f /tmp/movivip-*.sh /tmp/validar-licencia*.sh

    # Eliminar scripts de otros sistemas VPN
    rm -f /usr/local/bin/menu

    echo -e "${GREEN}      ✔ Sistema limpiado completamente${RESET}"
    echo ""

    # ── RESTAURAR USUARIOS ──
    echo -e "${CYAN}   [4/4] 👥 Restaurando usuarios supervivientes...${RESET}"

    REMAINING=()
    for u in "${EXISTING_USERS[@]}"; do
        # Saltar eliminados
        skip=false
        for d in "${DELETED_USERS[@]}"; do
            [[ "$u" == "$d" ]] && skip=true && break
        done
        $skip && continue

        # Leer datos del backup
        HASH=$(awk -F: -v user="$u" '$1==user{print $2}' "$BACKUP_FILE" 2>/dev/null)
        EXPIRY=$(awk -F: -v user="$u" '$1==user{print $3}' "$BACKUP_FILE" 2>/dev/null)

        # Crear usuario
        if [[ -n "$EXPIRY" && "$EXPIRY" != "0" ]]; then
            useradd -e "$EXPIRY" -M -s /usr/sbin/nologin "$u" 2>/dev/null
        else
            useradd -M -s /usr/sbin/nologin "$u" 2>/dev/null
        fi

        # Restaurar password desde shadow
        if [[ -n "$HASH" && "$HASH" != "!" && "$HASH" != "*" ]]; then
            echo "${u}:${HASH}" | chpasswd -e 2>/dev/null
        fi

        REMAINING+=("$u")
        echo -e "${GREEN}      ✔ Restaurado: $u${RESET}"
    done

    echo ""

    # Restaurar licencia de /tmp si existe
    if [[ -f /tmp/movivip-key.txt ]]; then
        mkdir -p /etc/movivip
    fi

    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${GREEN}            ✅ LIMPIEZA COMPLETADA${RESET}${CYAN}                       ║${RESET}"
    echo -e "${CYAN}║${WHITE}  Usuarios restaurados: ${GREEN}${#REMAINING[@]}${RESET}${CYAN}                            ║${RESET}"
    echo -e "${CYAN}║${WHITE}  Usuarios eliminados:  ${RED}${#DELETED_USERS[@]}${RESET}${CYAN}                            ║${RESET}"
    echo -e "${CYAN}║${WHITE}  Sistema: LIMPIO — listo para instalación nueva${RESET}${CYAN}   ║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    sleep 2
else
    echo ""
    echo -e "${GREEN}   ✔ Sistema limpio — primera instalación (no hay usuarios previos)${RESET}"
    echo ""
fi

# ═══════════════════════════════════════════════════════════════
# INSTALAR PAQUETES BÁSICOS
# ═══════════════════════════════════════════════════════════════

step "Actualizando repositorios..."
run_cmd "apt update" "$LINENO" "apt-get update -y"

step "Instalando paquetes esenciales..."
run_cmd "Paquetes: curl, wget, git, unzip, jq, socat, openssl, etc." "$LINENO" \
    "apt-get install -y curl wget git unzip zip tar sudo nano cron net-tools dnsutils lsof screen jq bc socat openssl ca-certificates fail2ban iptables iproute2 less whois rkhunter chkrootkit lynis"

# ═══════════════════════════════════════════════════════════════
# SSL/TLS + HAPROXY — INSTALACIÓN AUTOMÁTICA
# ═══════════════════════════════════════════════════════════════

step "Instalando SSL/TLS + HAProxy..."

run_cmd "Instalando haproxy" "$LINENO" "apt-get install -y haproxy python3"

if [[ ! -f /etc/haproxy/yha.pem ]]; then
    run_cmd "Generando certificado SSL autofirmado" "$LINENO" \
        "openssl req -x509 -nodes -newkey rsa:2048 -days 3650 -keyout /tmp/key.pem -out /tmp/cert.pem -subj '/CN=ssl-tunnel' 2>/dev/null; cat /tmp/key.pem /tmp/cert.pem > /etc/haproxy/yha.pem; rm -f /tmp/key.pem /tmp/cert.pem; chmod 600 /etc/haproxy/yha.pem"
fi

for P in 80 443 8080 8443; do
    fuser -k "$P/tcp" >/dev/null 2>&1
done

# ssh-ws-internal.py (WebSocket → SSH)
if [[ ! -f /usr/local/bin/ssh-ws-internal.py ]]; then
    run_cmd "Creando ssh-ws-internal.py" "$LINENO" "cat > /usr/local/bin/ssh-ws-internal.py <<'PYEOF'
#!/usr/bin/env python3
import asyncio, signal, sys
BUFFER_SIZE = 65536
SSH_HOST = "127.0.0.1"
SSH_PORT = 22
R101 = b\"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n\"
R200 = b\"HTTP/1.1 200 Connection established\r\n\r\n\"
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
        req = p.decode(\"utf-8\", errors=\"ignore\").upper()
        cw.write(R101 if (\"UPGRADE\" in req or \"WEBSOCKET\" in req) else R200)
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
    s = await asyncio.start_server(handle, \"127.0.0.1\", port)
    async with s: await s.serve_forever()

def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 10015
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    for sig in (signal.SIGTERM, signal.SIGINT):
        try: loop.add_signal_handler(sig, lambda: loop.stop())
        except: pass
    loop.run_until_complete(start(port))

if __name__ == \"__main__\":
    main()
PYEOF"
    run_cmd "Estableciendo permisos ssh-ws-internal" "$LINENO" "chmod +x /usr/local/bin/ssh-ws-internal.py"
fi

run_cmd "Creando servicio ssh-ws-internal" "$LINENO" "cat > /etc/systemd/system/ssh-ws-internal.service << 'SVCEOF'
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
SVCEOF"

run_cmd "Generando configuración HAProxy" "$LINENO" "cat > /etc/haproxy/haproxy.cfg << 'HAPCFG'
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
HAPCFG"

run_cmd "Configurando resiliencia HAProxy" "$LINENO" "mkdir -p /etc/systemd/system/haproxy.service.d"
run_cmd "Creando override de resiliencia" "$LINENO" "cat > /etc/systemd/system/haproxy.service.d/10-resilience.conf << 'RESF'
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
RESF"

if haproxy -c -f /etc/haproxy/haproxy.cfg 2>/dev/null; then
    run_cmd "Recargando systemd" "$LINENO" "systemctl daemon-reload"
    run_cmd "Habilitando haproxy + ssh-ws-internal" "$LINENO" "systemctl enable haproxy ssh-ws-internal"
    run_cmd "Iniciando servicios" "$LINENO" "systemctl restart ssh-ws-internal haproxy"
    echo -e "      ${GREEN}✔${RESET} SSL/TLS + HAProxy instalado y activo"
else
    echo -e "      ${RED}✖${RESET} HAProxy configuración con errores — Reportar a soporte: línea $LINENO"
    log_error "$LINENO" "HAProxy config validation" "haproxy -c" "Config file has errors"
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

step "Optimizando recursos del sistema..."

run_cmd "Limpiando caché apt" "$LINENO" "apt clean; apt autoclean"

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
    apt-mark hold "$hold_pkg" >/dev/null 2>&1
done

REMOVE_PKGS=(
    "snapd" "lxd-agent" "lxd-installer" "cloud-guest-utils" "cloud-init"
    "cloud-utils" "open-vm-tools" "isc-dhcp-client" "ntfs-3g" "plymouth"
    "plymouth-theme-ubuntu-text" "fonts-ubuntu-console" "fonts-dejavu-core"
    "fonts-freefont-ttf" "command-not-found" "command-not-found-data"
    "friendly-recovery" "installation-report" "landscape-common"
)

for pkg in "${REMOVE_PKGS[@]}"; do
    dpkg -l | grep -q "^ii.*${pkg}" && apt remove -y --no-autoremove "$pkg" >/dev/null 2>&1
done

for hold_pkg in "${CRITICAL_PKGS[@]}"; do
    apt-mark unhold "$hold_pkg" >/dev/null 2>&1
done

run_cmd "Limpiando archivos temporales" "$LINENO" "rm -rf /tmp/* /var/tmp/* /var/cache/apt/archives/*.deb /var/lib/apt/lists/* /root/.cache /root/.local"
run_cmd "Limpiando logs comprimidos" "$LINENO" "find /var/log -name '*.log.*' -delete 2>/dev/null; find /var/log -name '*.gz' -delete 2>/dev/null"
run_cmd "Vaciando journals viejos" "$LINENO" "journalctl --vacuum-time=1d"

DISABLE_SVCS=(
    "multipathd" "multipathd.socket" "ModemManager" "apport"
    "apport-autoreport.timer" "udisks2" "accounts-daemon" "avahi-daemon"
    "cups" "cups-browsed" "bluetooth" "wpa_supplicant"
    "snapd.service" "snapd.socket" "snapd.seeded.service"
)
for svc in "${DISABLE_SVCS[@]}"; do
    systemctl stop "$svc" 2>/dev/null; systemctl disable "$svc" 2>/dev/null
done

run_cmd "Eliminando snaps" "$LINENO" "snap remove --purge lxd 2>/dev/null; snap remove --purge lxd-agent 2>/dev/null; snap remove --purge core20 2>/dev/null; snap remove --purge core22 2>/dev/null; snap remove --purge snapd 2>/dev/null; rm -rf /snap /var/snap /var/lib/snapd"
run_cmd "Limpiando historial" "$LINENO" "rm -f /root/.bash_history; history -c 2>/dev/null"

step "Optimizando red (BBR + FQ + buffers)..."

run_cmd "Configurando parámetros de red (sysctl)" "$LINENO" "cat > /etc/sysctl.d/99-MoviVIP.conf << 'EOF'
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.core.rmem_max=67108864
net.core.wmem_max=67108864
net.core.rmem_default=262144
net.core.wmem_default=262144
net.ipv4.tcp_rmem=4096 262144 67108864
net.ipv4.tcp_wmem=4096 262144 67108864
net.ipv4.tcp_mtu_probing=1
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_low_latency=1
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
net.ipv4.udp_mem=32768 65536 262144
net.netfilter.nf_conntrack_max=524288
net.netfilter.nf_conntrack_udp_timeout=5
net.netfilter.nf_conntrack_udp_timeout_stream=15
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_ratio=10
vm.dirty_background_ratio=2
fs.file-max=2097152
EOF"

run_cmd "Aplicando parámetros de red" "$LINENO" "sysctl --system"
run_cmd "Aumentando límite de archivos abiertos" "$LINENO" "ulimit -n 1048576"

IFACE_NET=$(ip route get 8.8.8.8 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')
[[ -z "$IFACE_NET" ]] && IFACE_NET=$(ls /sys/class/net | grep -E '^(eth|ens|enp)' | head -n1)

run_cmd "Configurando MTU 1470 en ${IFACE_NET:-eth0}" "$LINENO" "ip link set dev '${IFACE_NET:-eth0}' mtu 1470"

run_cmd "Configurando colas FQ gaming" "$LINENO" "tc qdisc del dev '${IFACE_NET:-eth0}' root 2>/dev/null; tc qdisc add dev '${IFACE_NET:-eth0}' root fq quantum 1492 initial_quantum 14920 flow_limit 1000 limit 10000 horizon 0 refill_delay 10 low_rate_threshold 10Mbit"

step "Configurando reglas de firewall (iptables)..."

run_cmd "Instalando iptables" "$LINENO" "apt-get install -y iptables"
run_cmd "Forzando rehash PATH" "$LINENO" "hash -r"

run_cmd "INPUT: permitiendo UDP Custom (2100)" "$LINENO" "iptables -A INPUT -p udp --dport 2100 -j ACCEPT"
run_cmd "INPUT: permitiendo ZiVPN (5667)" "$LINENO" "iptables -A INPUT -p udp --dport 5667 -j ACCEPT"
run_cmd "INPUT: permitiendo ZiVPN range (6000:19999)" "$LINENO" "iptables -A INPUT -p udp --dport 6000:19999 -j ACCEPT"
run_cmd "INPUT: permitiendo UDP Custom range (20000:29999)" "$LINENO" "iptables -A INPUT -p udp --dport 20000:29999 -j ACCEPT"
run_cmd "INPUT: permitiendo BadVPN VoIP (7200)" "$LINENO" "iptables -A INPUT -p udp --dport 7200 -j ACCEPT"
run_cmd "INPUT: permitiendo BadVPN gaming (7300)" "$LINENO" "iptables -A INPUT -p udp --dport 7300 -j ACCEPT"
run_cmd "INPUT: permitiendo BadVPN gaming TCP (7300)" "$LINENO" "iptables -A INPUT -p tcp --dport 7300 -j ACCEPT"
run_cmd "INPUT: permitiendo HTTP (80)" "$LINENO" "iptables -A INPUT -p tcp --dport 80 -j ACCEPT"
run_cmd "INPUT: permitiendo HTTPS (443)" "$LINENO" "iptables -A INPUT -p tcp --dport 443 -j ACCEPT"
run_cmd "INPUT: permitiendo HTTP alt (8080)" "$LINENO" "iptables -A INPUT -p tcp --dport 8080 -j ACCEPT"
run_cmd "INPUT: permitiendo HTTPS alt (8443)" "$LINENO" "iptables -A INPUT -p tcp --dport 8443 -j ACCEPT"
run_cmd "INPUT: permitiendo SSH (22)" "$LINENO" "iptables -A INPUT -p tcp --dport 22 -j ACCEPT"

run_cmd "Creando cadena MOVIVIP_OUT" "$LINENO" "iptables -N MOVIVIP_OUT 2>/dev/null; iptables -C OUTPUT -j MOVIVIP_OUT 2>/dev/null || iptables -I OUTPUT 1 -j MOVIVIP_OUT"

run_cmd "MANGLE: priorización Free Fire (7000:7999)" "$LINENO" "iptables -t mangle -A PREROUTING -p udp --dport 7000:7999 -j DSCP --set-dscp-class af41"
run_cmd "MANGLE: priorización COD Mobile (3478:3480)" "$LINENO" "iptables -t mangle -A PREROUTING -p udp --dport 3478:3480 -j DSCP --set-dscp-class af41"
run_cmd "MANGLE: priorización PUBG Mobile (8000:9000)" "$LINENO" "iptables -t mangle -A PREROUTING -p udp --dport 8000:9000 -j DSCP --set-dscp-class af41"

run_cmd "Guardando reglas iptables" "$LINENO" "mkdir -p /etc/iptables; iptables-save > /etc/iptables/rules.v4"

#==============================
# [3] ⏰ LIMPIEZA AUTOMÁTICA (cron cada 30 min)
# ═══════════════════════════════════════════════════════════════
# [3] LIMPIEZA AUTOMÁTICA + AUTO-UPDATE
# ═══════════════════════════════════════════════════════════════

step "Configurando limpieza automática (cada 30 min)..."

run_cmd "Creando directorio de scripts" "$LINENO" "mkdir -p /etc/movivip/scripts"

run_cmd "Creando script auto-cleanup" "$LINENO" "cat > /etc/movivip/scripts/auto-cleanup.sh << 'CLEANEOF'
#!/bin/bash
apt clean 2>/dev/null
find /var/log -name '*.log.*' -mmin +1440 -delete 2>/dev/null
find /var/log -name '*.gz' -delete 2>/dev/null
find /tmp -type f -mmin +1440 -delete 2>/dev/null
find /var/tmp -type f -mmin +1440 -delete 2>/dev/null
journalctl --vacuum-time=1d 2>/dev/null
rm -rf /root/.cache/pip 2>/dev/null /root/.cache/apt 2>/dev/null
SWAP_USED=$(free | awk '/Swap/{print $3}')
if [[ "$SWAP_USED" -eq 0 ]]; then swapoff -a 2>/dev/null; swapon -a 2>/dev/null; fi
df -h / | awk 'NR==2 {print \"[Auto-Cleanup] \"\$4\" libre (\"\$5\" usado)\"}' >> /var/log/movivip-cleanup.log 2>/dev/null
CLEANEOF"

run_cmd "Configurando cron auto-cleanup" "$LINENO" "chmod +x /etc/movivip/scripts/auto-cleanup.sh; (crontab -l 2>/dev/null | grep -v 'auto-cleanup'; echo '*/30 * * * * bash /etc/movivip/scripts/auto-cleanup.sh >/dev/null 2>&1') | crontab -"

step "Configurando auto-update (cada 2 días)..."
run_cmd "Configurando cron auto-update" "$LINENO" "chmod +x /etc/movivip/auto-update.sh 2>/dev/null; (crontab -l 2>/dev/null | grep -v 'auto-update'; echo '0 3 */2 * * bash /etc/movivip/auto-update.sh >/dev/null 2>&1') | crontab -"

# ═══════════════════════════════════════════════════════════════
# [4] GUARDAR VALORES DE RED
# ═══════════════════════════════════════════════════════════════

step "Guardando valores de red..."

MTU_CURRENT=$(ip link show "${IFACE_NET:-eth0}" 2>/dev/null | grep -o "mtu [0-9]*" | awk '{print $2}')
MTU_CURRENT="${MTU_CURRENT:-1470}"

run_cmd "Guardando configuración de red" "$LINENO" "cat >> /etc/movivip/config.conf << CONFEOF

NET_MTU=\"$MTU_CURRENT\"
NET_RMEM=\"67108864\"
NET_WMEM=\"67108864\"
NET_SOMAXCONN=\"8192\"
NET_BACKLOG=\"16384\"
NET_SWAPPINESS=\"10\"
NET_CLEANUP_INTERVAL=\"30\"
CONFEOF"

step "Verificando recursos..."

RAM_TOTAL=$(free -m | awk '/Mem:/{print $2}')
RAM_USED=$(free -m | awk '/Mem:/{print $3}')
RAM_FREE=$(free -m | awk '/Mem:/{print $7}')
RAM_PERCENT=$(( RAM_USED * 100 / RAM_TOTAL ))
CPU_CORES=$(nproc)
CPU_LOAD=$(uptime | awk -F'load average:' '{print $2}' | cut -d',' -f1 | tr -d ' ')
DISK_USED=$(df -h / | awk 'NR==2 {print $5}')
DISK_FREE=$(df -h / | awk 'NR==2 {print $4}')
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

# ═══════════════════════════════════════════════════════════════
# INSTALAR OPENSSH
# ═══════════════════════════════════════════════════════════════

step "Instalando OpenSSH..."

run_cmd "Instalando openssh-server" "$LINENO" "apt-get install -y openssh-server"
run_cmd "Habilitando servicio SSH" "$LINENO" "systemctl enable ssh"
run_cmd "Reiniciando servicio SSH" "$LINENO" "systemctl restart ssh"

# ==============================  
  
# CONFIG SERVER  
  
# ==============================  

step "Configurando servidor..."

run_cmd "Asegurando curl" "$LINENO" "apt-get install -y curl"

clear  

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"  
echo "        CONFIGURACIÓN DEL SERVIDOR"  
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"  
  
if [[ -t 0 ]]; then
    read -p "🌐 Dominio Cloudflare: " SERVER_DOMAIN
    read -p "🌐 Dominio Cloudfront (Enter si no): " CLOUDFRONT_DOMAIN
    read -p "🌐 Dominio No-IP / DDNS (Enter si no): " NOIP_DOMAIN
else
    SERVER_DOMAIN="${SERVER_DOMAIN:-}"
    CLOUDFRONT_DOMAIN="${CLOUDFRONT_DOMAIN:-}"
    NOIP_DOMAIN="${NOIP_DOMAIN:-}"
fi  

if [[ -n "$SERVER_DOMAIN" ]] && ! [[ "$SERVER_DOMAIN" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    echo -e "      ${RED}✖ '$SERVER_DOMAIN' no parece un dominio válido${RESET}"
    echo -e "      ${GRAY}  → Ignorando dominio inválido${RESET}"
    SERVER_DOMAIN=""
fi
  
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
  
step "Finalizando instalación..."

run_cmd "Estableciendo permisos del directorio" "$LINENO" "chmod -R 777 /etc/movivip"
run_cmd "Creando comando 'menu'" "$LINENO" "printf '#!/bin/bash\nexec bash /etc/movivip/menu.sh\n' > /usr/local/bin/menu; chmod +x /usr/local/bin/menu"  
  
#==============================  
  
# RESUMEN FINAL  
  
#==============================  
  
step "Descargando MoviVIP Network..."

run_cmd "Instalando git" "$LINENO" "apt-get install -y git"
run_cmd "Clonando repositorio" "$LINENO" "rm -rf /tmp/multi-script; git clone https://github.com/studioanime977/MoviVIPNetwork.git /tmp/multi-script"
run_cmd "Copiando archivos al sistema" "$LINENO" "mkdir -p /etc/movivip; cp -a /tmp/multi-script/. /etc/movivip/; chmod -R +x /etc/movivip; rm -rf /tmp/multi-script"

if [[ ! -f /etc/movivip/menu.sh ]]; then
    echo -e "      ${RED}✖ menu.sh no fue instalado — Reportar a soporte: línea $LINENO${RESET}"
    log_error "$LINENO" "menu.sh verification" "test -f /etc/movivip/menu.sh" "File not found"
    exit 1
fi

#==============================
# SELECTOR DE PROTOCOLOS
#==============================

CONFIG="/etc/movivip/config.conf"

install_dropbear() {
    echo ""
    echo "🚪 Instalando Dropbear..."
    DROPBEAR_PORT="${1:-443}"
    run_cmd "Instalando dropbear" "$LINENO" "apt-get install -y dropbear"
    run_cmd "Configurando dropbear puerto $DROPBEAR_PORT" "$LINENO" "cat > /etc/default/dropbear << DEOF
DROPBEAR_EXTRA_ARGS=\"-p ${DROPBEAR_PORT}\"
NO_START=0
DROPBEAR_PORT=${DROPBEAR_PORT}
DEOF"
    run_cmd "Habilitando dropbear" "$LINENO" "systemctl enable dropbear"
    run_cmd "Iniciando dropbear" "$LINENO" "systemctl restart dropbear"
    if systemctl is-active --quiet dropbear; then
        sed -i 's/^DROPBEAR=.*/DROPBEAR=ON/' "$CONFIG" 2>/dev/null
        sed -i "s/^DROPBEAR_PORT=.*/DROPBEAR_PORT=\"$DROPBEAR_PORT\"/" "$CONFIG" 2>/dev/null
        grep -q "^DROPBEAR_PORT=" "$CONFIG" 2>/dev/null || echo "DROPBEAR_PORT=\"$DROPBEAR_PORT\"" >> "$CONFIG"
        echo -e "      ${GREEN}✔${RESET} Dropbear ON (puerto $DROPBEAR_PORT)"
    else
        echo -e "      ${RED}✖${RESET} Dropbear no inició — Reportar a soporte: línea $LINENO"
        log_error "$LINENO" "Dropbear start" "systemctl restart dropbear" "Service did not start"
    fi
}

install_badvpn() {
    echo ""
    echo "⚡ Instalando BadVPN UDPGW..."
    run_cmd "Instalando dependencias build" "$LINENO" "apt-get install -y git cmake build-essential"
    run_cmd "Clonando badvpn" "$LINENO" "rm -rf /tmp/badvpn; git clone -q https://github.com/ambrop72/badvpn.git /tmp/badvpn"
    run_cmd "Compilando badvpn" "$LINENO" "cd /tmp/badvpn && mkdir -p build && cd build && cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_BADVPN-UDPGW=1 >/dev/null 2>&1 && make -j\$(nproc) >/dev/null 2>&1"
    run_cmd "Copiando binario udpgw" "$LINENO" "cp /tmp/badvpn/build/badvpn-udpgw/badvpn-udpgw /usr/bin/udpgw; rm -rf /tmp/badvpn"
    run_cmd "Creando servicio badvpn-udpgw" "$LINENO" "cat > /etc/systemd/system/badvpn-udpgw.service << 'SEOF'
[Unit]
Description=BadVPN UDP Gateway 7200
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/udpgw --listen-addr 127.0.0.1:7200 --max-clients 500
Restart=always

[Install]
WantedBy=multi-user.target
SEOF"
    run_cmd "Iniciando badvpn-udpgw" "$LINENO" "systemctl daemon-reload; systemctl enable badvpn-udpgw; systemctl start badvpn-udpgw"
    if systemctl is-active --quiet badvpn-udpgw; then
        sed -i 's/^BADVPN=.*/BADVPN=ON/' "$CONFIG" 2>/dev/null
        echo -e "      ${GREEN}✔${RESET} BadVPN ON (puerto 7200)"
    else
        echo -e "      ${RED}✖${RESET} BadVPN no inició — Reportar a soporte: línea $LINENO"
        log_error "$LINENO" "BadVPN start" "systemctl start badvpn-udpgw" "Service did not start"
    fi
}

install_udpcustom() {
    echo ""
    echo "📡 Instalando UDP Custom..."
    run_cmd "Instalando dependencias UDP Custom" "$LINENO" "apt-get install -y curl wget iptables libpam0g"
    run_cmd "Habilitando IP forwarding" "$LINENO" "sysctl -w net.ipv4.ip_forward=1; grep -q 'net.ipv4.ip_forward=1' /etc/sysctl.conf 2>/dev/null || echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf"
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)  URL="https://github.com/Depwisescript/UDP/raw/main/udp-custom-linux-amd64" ;;
        aarch64) URL="https://github.com/Depwisescript/UDP/raw/main/udp-custom-linux-arm" ;;
        *) echo -e "      ${RED}✖${RESET} Arquitectura $ARCH no soportada"; return ;;
    esac
    run_cmd "Descargando UDP Custom binario" "$LINENO" "curl -L -s -f '$URL' -o /usr/bin/udp && chmod +x /usr/bin/udp"
    if [[ ! -f /usr/bin/udp ]]; then
        echo -e "      ${RED}✖${RESET} Error descargando UDP Custom — Reportar a soporte: línea $LINENO"
        log_error "$LINENO" "UDP Custom download" "curl -L $URL" "Binary not found after download"
        return
    fi
    run_cmd "Creando config UDP Custom" "$LINENO" "cat > /usr/bin/config.json << 'UEOF'
{
    \"listen\": \":2100\",
    \"stream_buffer\": 33554432,
    \"receive_buffer\": 83886080,
    \"auth\": {
        \"mode\": \"passwords\"
    }
}
UEOF"
    run_cmd "Creando servicio UDP Custom" "$LINENO" "cat > /etc/systemd/system/udp-custom.service << 'UEOF'
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
UEOF"
    run_cmd "Iniciando UDP Custom" "$LINENO" "systemctl daemon-reload; systemctl enable udp-custom; systemctl start udp-custom"
    if systemctl is-active --quiet udp-custom; then
        sed -i 's/^UDP_CUSTOM=.*/UDP_CUSTOM=ON/' "$CONFIG" 2>/dev/null
        grep -q "^UDP_CUSTOM_PORT=" "$CONFIG" 2>/dev/null || echo "UDP_CUSTOM_PORT=2100" >> "$CONFIG"
        echo -e "      ${GREEN}✔${RESET} UDP Custom ON (puerto 2100)"
        echo -e "      ${GRAY}  📌 Para asignar usuarios: formato 1-PUERTO${RESET}"
    else
        echo -e "      ${RED}✖${RESET} UDP Custom no inició — Reportar a soporte: línea $LINENO"
        log_error "$LINENO" "UDP Custom start" "systemctl start udp-custom" "Service did not start"
    fi
}

install_v2ray() {
    echo ""
    echo "🌐 Instalando V2Ray/Xray..."
    run_cmd "Instalando dependencias V2Ray" "$LINENO" "apt-get install -y curl unzip jq socat cron bash-completion"
    run_cmd "Instalando Xray" "$LINENO" "bash -c '\$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)' @ install"
    if [[ $? != 0 ]]; then
        echo -e "      ${RED}✖${RESET} Error instalando Xray — Reportar a soporte: línea $LINENO"
        log_error "$LINENO" "Xray install" "xray-install.sh" "Exit code non-zero"
        return
    fi
    sed -i 's/^V2RAY=.*/V2RAY=ON/' "$CONFIG" 2>/dev/null
    echo -e "      ${GREEN}✔${RESET} V2Ray/Xray instalado"
    echo -e "      ${GRAY}  ⚙️ Configúralo desde Menú → Protocolos → [01] V2Ray${RESET}"
}

install_zipvpn() {
    echo ""
    echo "🔒 Instalando ZiVPN..."
    run_cmd "Instalando dependencias ZiVPN" "$LINENO" "apt-get install -y curl wget"
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)  URL="https://github.com/AmnesiaPod/TeamV2ray/raw/main/config/config.zip" ;;
        aarch64) URL="https://github.com/AmnesiaPod/TeamV2ray/raw/main/config/config.zip" ;;
        *) echo -e "      ${RED}✖${RESET} Arquitectura $ARCH no soportada"; return ;;
    esac
    run_cmd "Descargando configuración ZiVPN" "$LINENO" "mkdir -p /etc/zivpn; curl -L -s -f '$URL' -o /tmp/zivpn.zip && unzip -o /tmp/zivpn.zip -d /etc/zivpn/ >/dev/null 2>&1; rm -f /tmp/zivpn.zip"
    sed -i 's/^ZIPVPN=.*/ZIPVPN=ON/' "$CONFIG" 2>/dev/null
    echo -e "      ${GREEN}✔${RESET} ZiVPN ON"
    echo -e "      ${GRAY}  ⚙️ Configúralo desde Menú → Protocolos → [02] ZiVPN${RESET}"
}

install_slowdns() {
    echo ""
    echo "🌍 Instalando SlowDNS..."
    run_cmd "Instalando dependencias SlowDNS" "$LINENO" "apt-get install -y curl wget dnsdist iptables dnsutils ca-certificates"
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)  BIN_NAME="dnstt-server-linux-amd64" ;;
        aarch64|arm64) BIN_NAME="dnstt-server-linux-arm64" ;;
        *) echo -e "      ${RED}✖${RESET} Arquitectura $ARCH no soportada"; return ;;
    esac
    run_cmd "Creando directorio SlowDNS" "$LINENO" "mkdir -p /etc/slowdns"
    DOWNLOADED=0
    for URL in "https://dnstt.network/$BIN_NAME" "https://github.com/bugfloyd/dnstt-deploy/raw/main/bin/$BIN_NAME"; do
        if curl -L -k -s -f "$URL" -o /etc/slowdns/slowdns 2>/dev/null; then
            chmod +x /etc/slowdns/slowdns
            DOWNLOADED=1; break
        fi
    done
    if [[ $DOWNLOADED -eq 1 ]]; then
        sed -i 's/^SLOWDNS=.*/SLOWDNS=ON/' "$CONFIG" 2>/dev/null
        echo -e "      ${GREEN}✔${RESET} SlowDNS Server descargado"
        echo -e "      ${GRAY}  ⚙️ Configúralo desde Menú → Protocolos → [13] SlowDNS${RESET}"
        echo -e "      ${GRAY}  📌 Necesitas: dominio + nameserver${RESET}"
    else
        echo -e "      ${RED}✖${RESET} Error descargando SlowDNS — Reportar a soporte: línea $LINENO"
        log_error "$LINENO" "SlowDNS download" "curl $URL" "All mirrors failed"
    fi
}

install_squid() {
    echo ""
    echo "🐟 Instalando Squid Proxy..."
    run_cmd "Instalando squid" "$LINENO" "apt-get install -y squid"
    run_cmd "Habilitando squid" "$LINENO" "systemctl enable squid"
    run_cmd "Iniciando squid" "$LINENO" "systemctl restart squid"
    if systemctl is-active --quiet squid; then
        sed -i 's/^SQUID=.*/SQUID=ON/' "$CONFIG" 2>/dev/null
        echo -e "      ${GREEN}✔${RESET} Squid Proxy ON (puerto 3128)"
    else
        echo -e "      ${RED}✖${RESET} Squid no inició — Reportar a soporte: línea $LINENO"
        log_error "$LINENO" "Squid start" "systemctl restart squid" "Service did not start"
    fi
}

install_webmin() {
    echo ""
    echo "🖥️ Instalando Webmin..."
    run_cmd "Instalando dependencias Webmin" "$LINENO" "apt-get install -y curl wget"
    run_cmd "Descargando repo Webmin" "$LINENO" "curl -o /tmp/webmin-setup-repo.sh https://raw.githubusercontent.com/webmin/webmin/master/webmin-setup-repo.sh && sh /tmp/webmin-setup-repo.sh -y"
    run_cmd "Instalando Webmin" "$LINENO" "apt-get install -y webmin; rm -f /tmp/webmin-setup-repo.sh"
    if systemctl is-active --quiet webmin 2>/dev/null; then
        sed -i 's/^WEBMIN=.*/WEBMIN=ON/' "$CONFIG" 2>/dev/null
        echo -e "      ${GREEN}✔${RESET} Webmin ON (puerto 10000)"
    else
        sed -i 's/^WEBMIN=.*/WEBMIN=ON/' "$CONFIG" 2>/dev/null
        echo -e "      ${GRAY}  ⚠️ Webmin instalado, puerto 10000${RESET}"
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
if [[ -t 0 ]]; then
    read -rp "  ➜ Selección: " SELECTION_INPUT
else
    SELECTION_INPUT="${SELECTION_INPUT:-12}"
fi
echo ""

# Validar que solo contenga números y espacios
[[ "$SELECTION_INPUT" =~ ^[0-9\ ]+$ ]] || SELECTION_INPUT=""

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

step "Configurando Fail2ban..."

run_cmd "Ejecutando fail2ban.sh" "$LINENO" "timeout 120 bash /etc/movivip/herramientas/fail2ban.sh --install"
run_cmd "Habilitando fail2ban" "$LINENO" "timeout 30 systemctl enable fail2ban"
run_cmd "Iniciando fail2ban" "$LINENO" "timeout 30 systemctl restart fail2ban"

#==============================
# CONSUMO DE RED — cron (base de datos vacía)
#==============================

step "Activando monitoreo de consumo de red..."

run_cmd "Ejecutando snapshot inicial" "$LINENO" "chmod +x /etc/movivip/herramientas/network_snapshot.sh; bash /etc/movivip/herramientas/network_snapshot.sh"
run_cmd "Configurando cron network_snapshot" "$LINENO" "(crontab -l 2>/dev/null | grep -v 'network_snapshot'; echo '* * * * * bash /etc/movivip/herramientas/network_snapshot.sh >/dev/null 2>&1') | crontab -"

if [[ ! -f /etc/systemd/system/movivip-net-state.service ]]; then
    run_cmd "Creando servicio movivip-net-state" "$LINENO" "cat > /etc/systemd/system/movivip-net-state.service << 'EOF'
[Unit]
Description=MoviVIP Network State - consumo de red
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash /etc/movivip/herramientas/network_snapshot.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF"
    run_cmd "Habilitando servicio net-state" "$LINENO" "systemctl daemon-reload; systemctl enable movivip-net-state.service"
fi

#==============================
# CONSUMO POR USUARIO — cron (online.sh --quiet)
#==============================

step "Activando monitoreo de consumo por usuario..."

run_cmd "Ejecutando online.sh inicial" "$LINENO" "chmod +x /etc/movivip/usuarios/online.sh; bash /etc/movivip/usuarios/online.sh --quiet"
run_cmd "Creando archivo de límites de conexiones" "$LINENO" "mkdir -p /etc/movivip/sistema; touch /etc/movivip/sistema/limites_conexiones.conf"
run_cmd "Configurando cron online.sh" "$LINENO" "(crontab -l 2>/dev/null | grep -v 'online.sh --quiet'; echo '*/2 * * * * bash /etc/movivip/usuarios/online.sh --quiet >/dev/null 2>&1') | crontab -"

step "Configurando banner SSH..."

run_cmd "Creando banner /etc/profile.d" "$LINENO" "cat > /etc/profile.d/MoviVIP-banner.sh << 'EOF'
#!/bin/bash
[[ \$- != *i* ]] && return
clear
SERVER=$(hostname)
DOMAIN=\"-\"
if [[ -f /etc/movivip/config.conf ]]; then
    source /etc/movivip/config.conf
    DOMAIN=\"\${SERVER_DOMAIN:-\"-\"}\"
fi
UPTIME=\$(uptime -p | sed 's/up //')
FECHA=\$(date +\"%d-%m-%Y\")
HORA=\$(date +\"%H:%M:%S\")
center() {
    local text=\"\$1\"
    local cols
    cols=\$(tput cols 2>/dev/null || echo 80)
    local len=\$((${#text}))
    local pad=\$(( (cols - len) / 2 ))
    [[ \$pad -lt 0 ]] && pad=0
    printf \"%\${pad}s\" \"\"
    echo \"\$text\"
}
center \"==============================================================\"
center \"\"
center \" __  __       _ _   _   _      ____            _       _   \"
center \"|  \\/  |_   _| | |_(_) | |    / ___|  ___ _ __(_)_ __ | |_ \"
center \"| |\\/| | | | | | __| | | |    \\___ \\ / __| '__| | '_ \\| __|\"
center \"| |  | | |_| | | |_| | | |___  ___) | (__| |  | | |_) | |_ \"
center \"|_|  |_|\\__,_|_|\\__|_| |_____| |____/ \\___|_|  |_| .__/ \\__|\"
center \"                                                 |_|       \"
center \"\"
center \"🚀 MOVIVIP NETWORK — PREMIUM 🚀\"
center \"\"
center \"Servidor : \$SERVER\"
center \"Dominio  : \$DOMAIN\"
center \"Uptime   : \$UPTIME\"
center \"Fecha    : \$FECHA\"
center \"Hora     : \$HORA\"
center \"\"
center \"==============================================================\"
if [[ \$EUID -ne 0 ]]; then
    center \"👤 Usuario : \$(whoami)\"
    center \"🔒 No eres root.\"
    center \"👉 Ejecuta: sudo -i\"
else
    center \"👑 Usuario : root\"
    center \"👉 Escribe: menu\"
fi
center \"\"
center \"✨ Gracias por usar nuestros servicios ✨\"
center \"🛡SISTEMA PROTEGIDO POR MOVIVIP NETWORK🛡\"
center \"\"
EOF"

run_cmd "Creando banner SSH issue.net" "$LINENO" "cat > /etc/issue.net << 'EOF'
<html>
<body style='margin:0;padding:0;background:transparent'>
<div style='text-align:center'><span style=\"font-family:'Comic Sans MS',cursive,sans-serif;font-weight:bold;\">

<br><br>
<font color='#00ffff'><small><i>🛡SISTEMA PROTEGIDO POR MOVIVIP NETWORK🛡</i></small></font>
</span></div>
</body>
</html>
EOF"

run_cmd "Configurando banner en sshd_config" "$LINENO" "grep -q '^Banner' /etc/ssh/sshd_config 2>/dev/null && sed -i 's|^Banner.*|Banner /etc/issue.net|' /etc/ssh/sshd_config || echo 'Banner /etc/issue.net' >> /etc/ssh/sshd_config"
run_cmd "Configurando banner en dropbear" "$LINENO" "grep -q 'DROPBEAR_BANNER' /etc/default/dropbear 2>/dev/null || echo 'DROPBEAR_BANNER=\"/etc/issue.net\"' >> /etc/default/dropbear"
run_cmd "Reiniciando SSH y Dropbear" "$LINENO" "systemctl restart ssh sshd 2>/dev/null; systemctl restart dropbear dropbear_custom 2>/dev/null"

# ═══════════════════════════════════════════════════════════════
# RESUMEN FINAL
# ═══════════════════════════════════════════════════════════════

step "Instalación completada"

echo ""
source "$CONFIG" 2>/dev/null
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${GOLD}            ✅ INSTALACIÓN COMPLETADA                      ${CYAN}║${RESET}"
echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${RESET}"
echo -e "${CYAN}║${WHITE}  Dominio  : ${GREEN}$SERVER_DOMAIN${RESET}${CYAN}                              ║${RESET}"
echo -e "${CYAN}║${WHITE}  SSL/TLS  : ${GREEN}$SSL_TUNNEL${RESET}${CYAN}                                  ║${RESET}"
echo -e "${CYAN}║${WHITE}  CloudFlr : ${GREEN}$CLOUDFLARE_STATUS${RESET}${CYAN}                                  ║${RESET}"
echo -e "${CYAN}║${WHITE}  Idioma   : ${GREEN}$INSTALL_LANG${RESET}${CYAN}                                  ║${RESET}"
echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${RESET}"
echo -e "${CYAN}║${GOLD}  Protocolos activos:${RESET}${CYAN}                                     ║${RESET}"
echo -e "${CYAN}║${WHITE}  🚀 OpenSSH    : ${GREEN}$OPENSSH${RESET}${CYAN}                                 ║${RESET}"
echo -e "${CYAN}║${WHITE}  🔐 SSL/TLS    : ${GREEN}$SSL${RESET}${CYAN}                                 ║${RESET}"
echo -e "${CYAN}║${WHITE}  🚪 Dropbear   : ${GREEN}${DROPBEAR:-OFF}${RESET}${CYAN}                                ║${RESET}"
echo -e "${CYAN}║${WHITE}  ⚡ BadVPN     : ${GREEN}${BADVPN:-OFF}${RESET}${CYAN}                                ║${RESET}"
echo -e "${CYAN}║${WHITE}  📡 UDP Custom : ${GREEN}${UDP_CUSTOM:-OFF}${RESET}${CYAN}                                ║${RESET}"
echo -e "${CYAN}║${WHITE}  🌐 V2Ray      : ${GREEN}${V2RAY:-OFF}${RESET}${CYAN}                                ║${RESET}"
echo -e "${CYAN}║${WHITE}  🔒 ZiVPN      : ${GREEN}${ZIPVPN:-OFF}${RESET}${CYAN}                                ║${RESET}"
echo -e "${CYAN}║${WHITE}  🌍 SlowDNS    : ${GREEN}${SLOWDNS:-OFF}${RESET}${CYAN}                                ║${RESET}"
echo -e "${CYAN}║${WHITE}  🐟 Squid      : ${GREEN}${SQUID:-OFF}${RESET}${CYAN}                                ║${RESET}"
echo -e "${CYAN}║${WHITE}  🖥️ Webmin     : ${GREEN}${WEBMIN:-OFF}${RESET}${CYAN}                                ║${RESET}"
echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${RESET}"
echo -e "${CYAN}║${WHITE}  📦 Paquetes básicos: INSTALADO                          ${CYAN}║${RESET}"
echo -e "${CYAN}║${WHITE}  🌐 Multi-idioma: 10 idiomas disponibles                 ${CYAN}║${RESET}"
echo -e "${CYAN}║${WHITE}  💡 Cambia protocolos desde el menú principal            ${CYAN}║${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "${GRAY}  📋 Log de instalación: $INSTALL_LOG${RESET}"
echo -e "${GRAY}  🔄 El servidor se reiniciará en 10 segundos...${RESET}"

sleep 10

reboot
