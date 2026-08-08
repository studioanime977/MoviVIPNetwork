#!/bin/bash

#=========================================================
#   MOVIVIP NETWORK — PREMIUM EDITION v4.0
#   Panel de Control · Alto Rendimiento y Seguridad Total
#   Diseño compacto tipo dashboard — 1 pantalla
#=========================================================

BASE="/etc/movivip"
CONFIG="$BASE/config.conf"
SISTEMA="$BASE/sistema"
STATE="$SISTEMA/network_state.conf"

#=========================================================
# Verificar configuración
#=========================================================

[[ ! -f "$CONFIG" ]] && {
    clear
    echo ""
    echo -e "\e[1;91m❌ No se encontró config.conf\e[0m"
    echo -e "\e[1;97m👉 Ejecuta primero install.sh\e[0m"
    echo ""
    exit 1
}

source "$CONFIG"

#=========================================================
# Colores premium MoviVIP (banner oficial)
#=========================================================

RESET="\e[0m"; RED="\e[1;91m"; GREEN="\e[1;92m"; GOLD="\e[1;93m"
BLUE="\e[1;94m"; MAGENTA="\e[1;95m"; CYAN="\e[1;96m"; WHITE="\e[1;97m"; GRAY="\e[1;90m"

#=========================================================
# Marco (ancho fijo)
#=========================================================

W=70
H1() { printf "${CYAN}╔"; printf '═%.0s' $(seq 1 $W); printf "╗${RESET}\n"; }
H2() { printf "${CYAN}╠"; printf '═%.0s' $(seq 1 $W); printf "╣${RESET}\n"; }
H3() { printf "${CYAN}╚"; printf '═%.0s' $(seq 1 $W); printf "╝${RESET}\n"; }

#=========================================================
# Funciones
#=========================================================

status() {
    [[ "$1" == "ON" ]] && echo -e "${GREEN}🟢 ON${RESET}" || echo -e "${RED}🔴 OFF${RESET}"
}

progress_bar() {
    local percent=$1
    local total=14
    local filled=$((percent*total/100))
    local empty=$((total-filled))
    [[ $filled -gt $total ]] && filled=$total
    printf "${GREEN}"
    for ((i=0;i<filled;i++)); do printf "█"; done
    printf "${GRAY}"
    for ((i=0;i<empty;i++)); do printf "░"; done
    printf "${RESET}"
}

# human() — conversión 100% bash (sin awk, sin forks → script más rápido)
human() {
    local B=$1
    [[ -z "$B" ]] && B=0
    if (( B >= 1000000000000 )); then
        echo "$((B/1000000000000)).$(((B%1000000000000)/10000000000)) TB"
    elif (( B >= 1000000000 )); then
        echo "$((B/1000000000)).$(((B%1000000000)/10000000)) GB"
    elif (( B >= 1000000 )); then
        echo "$((B/1000000)).$(((B%1000000)/10000)) MB"
    elif (( B >= 1000 )); then
        echo "$((B/1000)).$(((B%1000)/10)) KB"
    else
        echo "$B B"
    fi
}

# speed() — bytes/segundo → Mbps (megabits por segundo, como el panel del proveedor)
speed() {
    local V=$1
    [[ -z "$V" ]] && V=0
    local B=$(( V * 8 ))
    if (( B >= 1000000 )); then
        echo "$((B/1000000)).$(((B%1000000)/10000)) Mbps"
    elif (( B >= 1000 )); then
        echo "$((B/1000)).$(((B%1000)/10)) Kbps"
    else
        echo "$B bps"
    fi
}

# read_counters() — lectura instantánea de /proc/net/dev (1 proceso awk)
read_counters() {
    local C
    C=$(awk -v i="${IFACE}:" '$1==i {print $2, $10}' /proc/net/dev 2>/dev/null)
    RX_N=${C% *}; TX_N=${C#* }
    [[ -z "$RX_N" ]] && RX_N=0
    [[ -z "$TX_N" ]] && TX_N=0
}

# get_iface() — interfaz principal (desde config o auto)
get_iface() {
    if [[ -n "$NET_IFACE" ]]; then echo "$NET_IFACE"; return; fi
    local I
    I=$(ip route get 8.8.8.8 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')
    [[ -n "$I" ]] && echo "$I" && return
    I=$(ls /sys/class/net 2>/dev/null | grep -E '^(eth|ens|enp|eno)' | head -n1)
    echo "${I:-eth0}"
}

#=========================================================
# Información del sistema (auto-detectada) — rápido
#=========================================================

OS=$(source /etc/os-release && echo "$NAME $VERSION_ID")
KERNEL=$(uname -r)
ARCH=$(uname -m)
CPU_CORES=$(nproc)
IP=$(hostname -I 2>/dev/null | awk '{print $1}')

# IP pública con caché (5 min) — evita esperar a curl en cada carga
PUB_CACHE="$SISTEMA/.pub_ip"
PUBLIC_IP="-"
if [[ -f "$PUB_CACHE" ]] && (( $(date +%s) - $(stat -c %Y "$PUB_CACHE" 2>/dev/null || echo 0) < 300 )); then
    PUBLIC_IP=$(cat "$PUB_CACHE")
else
    PUBLIC_IP=$(curl -s --max-time 1 ifconfig.me 2>/dev/null || echo "-")
    [[ "$PUBLIC_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && echo "$PUBLIC_IP" > "$PUB_CACHE" 2>/dev/null
fi
FECHA=$(date +"%d/%m/%Y %H:%M")

# RAM con 1 sola llamada (MB)
read -r TOTAL_RAM_MB USED_RAM_MB FREE_RAM_MB <<<"$(free -m | awk '/Mem:/{print $2, $3, $4}')"
TOTAL_RAM=${TOTAL_RAM_MB:-0}; USED_RAM=${USED_RAM_MB:-0}
RAM_USE=$(( TOTAL_RAM > 0 ? USED_RAM*100/TOTAL_RAM : 0 ))

# CPU con /proc/stat (más rápido que top -bn1)
CPU_READ_1=$(awk '/^cpu /{print $2+$3+$4+$5+$6+$7+$8+$9, $5+$6}' /proc/stat)
sleep 0.1
CPU_READ_2=$(awk '/^cpu /{print $2+$3+$4+$5+$6+$7+$8+$9, $5+$6}' /proc/stat)
TOT1=${CPU_READ_1% *}; IDL1=${CPU_READ_1#* }
TOT2=${CPU_READ_2% *}; IDL2=${CPU_READ_2#* }
CPU_USE=0
if [[ "$TOT2" != "$TOT1" ]]; then
    CPU_USE=$(( ( (TOT2-TOT1) - (IDL2-IDL1) ) * 100 / (TOT2-TOT1) ))
fi

DISK=$(df -h / | awk 'NR==2 {print $5}')
UPTIME=$(uptime -p | sed 's/up //')

# =========================================================
# Consumo en tiempo real — contador inicial
# (la velocidad se mide con el tiempo que ya tarda el script,
#  así NO se añade espera extra al menú)
# =========================================================

IFACE=$(get_iface)
read_counters; R1=$RX_N; T1=$TX_N
T_START=$(date +%s%N)

#=========================================================
# Estado de seguridad (auto-detectado)
#=========================================================

if systemctl is-active --quiet fail2ban; then
    SEC_STATUS="${GREEN}🟢 ACTIVO${RESET}"
    SEC_JAILS=$(fail2ban-client status 2>/dev/null | grep "Jail list" | sed 's/.*Jail list:[[:space:]]*//')
else
    SEC_STATUS="${RED}🔴 INACTIVO${RESET}"
    SEC_JAILS="-"
fi

LAST_AUDIT=$(ls -t "$BASE"/logs/lynis-*.log 2>/dev/null | head -n1)
if [[ -n "$LAST_AUDIT" ]]; then
    AUDIT_DATE=$(basename "$LAST_AUDIT" | sed 's/lynis-//;s/.log//')
    AUDIT_DATE=$(date -d "${AUDIT_DATE:0:8}" +"%d/%m/%Y" 2>/dev/null || echo "$AUDIT_DATE")
else
    AUDIT_DATE="nunca"
fi

#=========================================================
# Consumo de red (base del proveedor + medición local)
#=========================================================

VPS_BASE_RX="${VPS_TRAFFIC_BASE_RX:-0}"
VPS_BASE_TX="${VPS_TRAFFIC_BASE_TX:-0}"

NET_TOTAL_IN="—"
NET_TOTAL_OUT="—"

if [[ -f "$STATE" ]]; then
    source "$STATE" 2>/dev/null
    [[ -z "${TOTAL_IN:-}" && -n "${ACC_RX:-}" ]] && TOTAL_IN="$ACC_RX"
    [[ -z "${TOTAL_OUT:-}" && -n "${ACC_TX:-}" ]] && TOTAL_OUT="$ACC_TX"
    TOTAL_IN="${TOTAL_IN:-0}"
    TOTAL_OUT="${TOTAL_OUT:-0}"
    RX_TOTAL=$((VPS_BASE_RX + TOTAL_IN))
    TX_TOTAL=$((VPS_BASE_TX + TOTAL_OUT))
    NET_TOTAL_IN=$(human "$RX_TOTAL")
    NET_TOTAL_OUT=$(human "$TX_TOTAL")
else
    bash "$BASE/herramientas/network_snapshot.sh" >/dev/null 2>&1
    NET_TOTAL_IN=$(human "$VPS_BASE_RX")
    NET_TOTAL_OUT=$(human "$VPS_BASE_TX")
    RX_TOTAL="$VPS_BASE_RX"
    TX_TOTAL="$VPS_BASE_TX"
fi

NET_TOTAL_SUM=$(human $((RX_TOTAL + TX_TOTAL)))

#=========================================================
# Estado de protocolos (auto-detectado) — 1 llamada systemctl
#=========================================================

SVC_ARR=($(systemctl is-active ssh dropbear_custom haproxy udp-custom slowdns xray badvpn-udpgw-7200 zivpn 2>/dev/null))

svc_exists() {
    [[ -f /etc/systemd/system/$1.service || -f /lib/systemd/system/$1.service || -f /usr/lib/systemd/system/$1.service ]]
}

svc_icon() {
    local N=$1 SVC=$2
    if [[ "${SVC_ARR[$((N-1))]}" == "active" ]]; then
        echo -e "${GREEN}🟢${RESET}"
    elif svc_exists "$SVC"; then
        echo -e "${RED}🔴${RESET}"
    else
        echo -e "${GRAY}⚪${RESET}"
    fi
}

SSH_S=$(svc_icon 1 ssh)
DROP_S=$(svc_icon 2 dropbear_custom)
HA_S=$(svc_icon 3 haproxy)
UDP_S=$(svc_icon 4 udp-custom)
SLOW_S=$(svc_icon 5 slowdns)
XRAY_S=$(svc_icon 6 xray)
BAD_S=$(svc_icon 7 badvpn-udpgw-7200)
ZIP_S=$(svc_icon 8 zivpn)

#=========================================================
# Conexiones en tiempo real (solo conteo)
#=========================================================

SSH_CONN=$(ps -C sshd -o args= 2>/dev/null | grep -c "\[priv\]")
DROP_CONN=$(pgrep -x dropbear 2>/dev/null | wc -l)
[[ $DROP_CONN -gt 0 ]] && DROP_CONN=$((DROP_CONN - 1))
ONLINE_USERS=$(ps -C sshd -o args= 2>/dev/null | grep "\[priv\]" | awk -F'sshd: ' '{print $2}' | awk '{print $1}' | grep -vE '^(root|unknown|invalid|\(null\))$' | sort -u | wc -l)
TOTAL_CONN=$((SSH_CONN + DROP_CONN))
CONN_HORA=$(date '+%H:%M:%S')

#=========================================================
# Estado CDN (auto-detectado EN VIVO)
# No confiar en config.conf: el dominio pudo cambiar despues
# de la instalacion y CLOUDFLARE_STATUS quedo desactualizado.
#=========================================================

CF_STATUS_LIVE="OFF"
if [[ -n "$SERVER_DOMAIN" ]]; then
    CF_NS=$(dig +short NS "$SERVER_DOMAIN" 2>/dev/null | grep -ci cloudflare)
    [[ "$CF_NS" -gt 0 ]] && CF_STATUS_LIVE="ON"
elif [[ "${CLOUDFLARE_STATUS:-OFF}" == "ON" ]]; then
    CF_STATUS_LIVE="ON"
fi

# No-IP / DDNS: configurado = ON (es dinamico, no se exige que resuelva)
NOIP_STATUS_LIVE="OFF"
[[ -n "$NOIP_DOMAIN" ]] && NOIP_STATUS_LIVE="ON"

#=========================================================
# PANTALLA — DASHBOARD COMPACTO
#=========================================================

clear
H1
printf "${CYAN}║${GOLD}   ⚡ MOVIVIP NETWORK ⚡ ${CYAN}PREMIUM EDITION v4.0${RESET}      ${WHITE}Control Total${RESET}${CYAN}          ║${RESET}\n"
printf "${CYAN}║${BLUE}   Alto Rendimiento · Seguridad Total · SISTEMA ÓPTIMO ACTIVO${CYAN}   ║${RESET}\n"
H2

# --- NOTIFICACIÓN DE ACTUALIZACIÓN (chequeo ligero, caché 6h) ---
# Avisa que hay una versión nueva. El panel NUNCA se desactiva por licencia;
# la actualización en sí (opción [09]) exige licencia activa.
UPD_CACHE="/tmp/movivip_upd_check"
UPD_VER_FILE="/tmp/movivip_upd_ver"
UPD_NOW=$(date +%s)
if [[ ! -f "$UPD_CACHE" ]] || (( UPD_NOW - $(cat "$UPD_CACHE") > 21600 )); then
    # API de GitHub (sin caché CDN) con fallback a raw
    UPD_RV=$(curl -fsSL --max-time 4 "https://api.github.com/repos/studioanime977/MoviVIPNetwork/contents/version.txt" 2>/dev/null \
        | grep -o '"content":"[^"]*"' | head -1 | cut -d'"' -f4 | base64 -d 2>/dev/null | tr -d ' \n')
    [[ -z "$UPD_RV" ]] && UPD_RV=$(curl -fsSL --max-time 4 "https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/version.txt" 2>/dev/null | tr -d ' \n')
    [[ -n "$UPD_RV" ]] && echo "$UPD_RV" > "$UPD_VER_FILE"
    echo "$UPD_NOW" > "$UPD_CACHE"
fi
UPD_RV=$(cat "$UPD_VER_FILE" 2>/dev/null)
UPD_LV=$(tr -d ' \n' < "$BASE/version.txt" 2>/dev/null)
if [[ -n "$UPD_RV" && -n "$UPD_LV" && "$UPD_RV" != "$UPD_LV" ]]; then
    NOTIF_MSG="📢 ACTUALIZACIÓN v${UPD_RV} DISPONIBLE — menú [09]"
    printf "${CYAN}║${RESET} ${GOLD}${NOTIF_MSG}${RESET}${CYAN}%*s║${RESET}\n" $(( W - 5 - ${#NOTIF_MSG} )) ""
    H2
fi

# --- SISTEMA (1 línea) ---
printf "${CYAN}║ ${GOLD}🖥 SISTEMA${RESET}${WHITE}  ${OS} ${GRAY}·${WHITE} ${CPU_CORES} Cores ${GRAY}·${WHITE} ${ARCH}${RESET}${CYAN}              ║${RESET}\n"
echo -e "${CYAN}║${RESET}   RAM ${RESET}$(progress_bar "$RAM_USE")${WHITE} ${RAM_USE}% ${GRAY}(${USED_RAM}Mi/${TOTAL_RAM}Mi)${RESET}   ${CYAN}CPU${RESET} $(progress_bar "$CPU_USE")${WHITE} ${CPU_USE}%${RESET}   ${CYAN}DISK${RESET} ${WHITE}${DISK}${RESET}${CYAN}       ║${RESET}"
printf "${CYAN}║${RESET}   ${GRAY}Kernel ${WHITE}${KERNEL}${RESET}   ${GRAY}Up ${WHITE}${UPTIME}${RESET}   ${GRAY}${FECHA}${RESET}${CYAN}                  ║${RESET}\n"
H2

# --- RED + CONSUMO (con velocidad en vivo y total) ---
printf "${CYAN}║ ${GOLD}🌐 RED${RESET}${WHITE}  IP ${IP} ${GRAY}·${WHITE} Pub ${PUBLIC_IP} ${GRAY}·${WHITE} CF $(status "$CF_STATUS_LIVE") ${GRAY}· No-IP $(status "$NOIP_STATUS_LIVE")${RESET}${CYAN}  ║${RESET}\n"

# Velocidad real medida con el tiempo que tardó el script (sin espera extra)
read_counters; R2=$RX_N; T2=$TX_N
T_END=$(date +%s%N)
ELAPSED_MS=$(( (T_END - T_START) / 1000000 ))
[[ $ELAPSED_MS -lt 1 ]] && ELAPSED_MS=1
SPD_IN=$(( (R2 - R1) * 1000 / ELAPSED_MS )); [[ $SPD_IN -lt 0 ]] && SPD_IN=0
SPD_OUT=$(( (T2 - T1) * 1000 / ELAPSED_MS )); [[ $SPD_OUT -lt 0 ]] && SPD_OUT=0

printf "${CYAN}║ ${GOLD}📊 CONSUMO${RESET}${WHITE}  ⬇ $(speed "$SPD_IN")  ${GRAY}·${WHITE} ⬆ $(speed "$SPD_OUT")${RESET}  ${GRAY}|${WHITE} Total ${GOLD}${NET_TOTAL_SUM}${RESET}${CYAN}   ║${RESET}\n"
printf "${CYAN}║${RESET}   ${GRAY}⬇ ${WHITE}${NET_TOTAL_IN}${RESET}  ${GRAY}· ⬆ ${WHITE}${NET_TOTAL_OUT}${RESET}  ${GRAY}· Dominio: ${WHITE}${SERVER_DOMAIN:-NO CONFIGURADO}${RESET}${CYAN}   ║${RESET}\n"
[[ -n "$NOIP_DOMAIN" ]] && printf "${CYAN}║${RESET}   ${GRAY}· No-IP: ${WHITE}${NOIP_DOMAIN}${RESET}${CYAN}                              ║${RESET}\n"
H2

# --- PROTOCOLOS (con puertos) ---
echo -e "${CYAN}║ ${GOLD}🚀 PROTOCOLOS${RESET}${CYAN}                                                          ║${RESET}"
echo -e "${CYAN}║${RESET}  🔐 OpenSSH  ${SSH_S} ${GRAY}[22]${RESET}        ${WHITE}🔒 SSL/TLS  ${HA_S} ${GRAY}[80,443,8080]${RESET}${CYAN}  ║${RESET}"
echo -e "${CYAN}║${RESET}  🚪 Dropbear ${DROP_S} ${GRAY}[90,109,143]${RESET} ${WHITE}🚀 UDP Custom ${UDP_S} ${GRAY}[2100]${RESET}${CYAN}      ║${RESET}"
echo -e "${CYAN}║${RESET}  🌐 SlowDNS  ${SLOW_S} ${GRAY}[5300]${RESET}      ${WHITE}☁️ Xray/V2Ray ${XRAY_S} ${GRAY}[10001+]${RESET}${CYAN}    ║${RESET}"
echo -e "${CYAN}║${RESET}  ⚡ BadVPN   ${BAD_S} ${GRAY}[7200,7300]${RESET}   ${WHITE}📦 ZiVPN     ${ZIP_S} ${GRAY}[UDP]${RESET}${CYAN}        ║${RESET}"
echo -e "${CYAN}║${RESET}  ${GRAY}·${WHITE} 👁 Online ${GREEN}${ONLINE_USERS}${RESET} ${GRAY}·${WHITE} Conexiones ${GREEN}${TOTAL_CONN}${RESET} ${GRAY}·${WHITE} ${CONN_HORA}${RESET}${CYAN}                ║${RESET}"
H2

# --- SEGURIDAD (1 línea) ---
printf "${CYAN}║ ${GOLD}🛡 SEGURIDAD${RESET}   ${WHITE}Fail2ban${RESET} ${SEC_STATUS}  ${GRAY}·${WHITE} Jails ${GREEN}${SEC_JAILS}${RESET}  ${GRAY}·${WHITE} Auditoría ${GOLD}${AUDIT_DATE}${RESET}${CYAN}   ║${RESET}\n"
H2

# --- MENÚ PRINCIPAL (2 columnas) ---
printf "${CYAN}║ ${GOLD}⚙ MENÚ PRINCIPAL${RESET}${CYAN}                                                       ║${RESET}\n"
printf "${CYAN}║${RESET}  ${GOLD}[01]${WHITE} 👥 Usuarios SSH   ${CYAN}│${RESET}  ${GOLD}[06]${WHITE} 🚀 Optimizar VPS  ${CYAN}    ║${RESET}\n"
printf "${CYAN}║${RESET}  ${GOLD}[02]${WHITE} 📦 Protocolos     ${CYAN}│${RESET}  ${GOLD}[07]${WHITE} 🌐 Cambiar Dominio${CYAN}    ║${RESET}\n"
printf "${CYAN}║${RESET}  ${GOLD}[03]${WHITE} 🧰 Herramientas   ${CYAN}│${RESET}  ${GOLD}[08]${WHITE} 🔄 Auto Inicio $(status "${AUTO_START:-OFF}")${CYAN}   ║${RESET}\n"
printf "${CYAN}║${RESET}  ${GOLD}[04]${WHITE} 🛡 Seguridad      ${CYAN}│${RESET}  ${GOLD}[09]${WHITE} 🛠 Update / Remove${CYAN}    ║${RESET}\n"
printf "${CYAN}║${RESET}  ${GOLD}[05]${WHITE} 📊 Consumo Red    ${CYAN}│${RESET}  ${GOLD}[10]${WHITE} 🤖 Bot Admin     ${CYAN}    ║${RESET}\n"
printf "${CYAN}║${RESET}  ${GOLD}[00]${WHITE} 🚪 Salir          ${CYAN}│${RESET}  ${GOLD}[11]${WHITE} 🧪 Pruebas       ${CYAN}    ║${RESET}\n"
H3
echo ""
read -rp "$(echo -e "${CYAN}➜ ${GOLD}Opción${WHITE} ➤ ${RESET}")" OPCION

#=========================================================
# CASE PRINCIPAL
#=========================================================

case "$OPCION" in

1)
    clear
    if [[ -f "$BASE/usuarios/menu.sh" ]]; then
        bash "$BASE/usuarios/menu.sh"
    else
        echo -e "${RED}❌ Módulo de usuarios no instalado${RESET}"
        sleep 2
        exec bash "$BASE/menu.sh"
    fi
;;

2)
    clear
    if [[ -f "$BASE/protocolos/menu.sh" ]]; then
        bash "$BASE/protocolos/menu.sh"
    else
        echo -e "${RED}❌ Menú de protocolos no instalado${RESET}"
        sleep 2
        exec bash "$BASE/menu.sh"
    fi
;;

3)
    clear
    bash "$BASE/herramientas/menu.sh"
;;

4)
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${GOLD}            🛡 SEGURIDAD DEL SERVIDOR 🛡${RESET}${CYAN}                    ║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    printf "${GOLD} [1]${WHITE} 🛡 Fail2ban (instalar/configurar/desbanear)\n"
    printf "${GOLD} [2]${WHITE} 🔍 Auditoría completa (rkhunter+chkrootkit+lynis)\n"
    printf "${RED} [0]${WHITE} ↩ Volver\n"
    echo ""
    read -rp " ► Opción: " SEC_OP
    case "$SEC_OP" in
        1) bash "$BASE/herramientas/fail2ban.sh" ;;
        2) bash "$BASE/herramientas/auditoria.sh" ;;
        0) exec bash "$BASE/menu.sh" ;;
        *) exec bash "$BASE/menu.sh" ;;
    esac
;;

5)
    clear
    if [[ -f "$BASE/herramientas/network_traffic.sh" ]]; then
        bash "$BASE/herramientas/network_traffic.sh"
    else
        echo -e "${RED}❌ network_traffic.sh no encontrado — actualiza el sistema (opción 9)${RESET}"
        sleep 2
        exec bash "$BASE/menu.sh"
    fi
;;

6)
    clear
    if [[ -f "$BASE/herramientas/optimizar.sh" ]]; then
        bash "$BASE/herramientas/optimizar.sh"
    else
        echo -e "${RED}❌ optimizar.sh no encontrado${RESET}"
        sleep 2
        exec bash "$BASE/menu.sh"
    fi
;;

7)
    clear
    if [[ -f "$BASE/herramientas/change-domain" ]]; then
        bash "$BASE/herramientas/change-domain"
    elif [[ -f "$BASE/herramientas/change-domain.sh" ]]; then
        bash "$BASE/herramientas/change-domain.sh"
    else
        echo -e "${RED}❌ change-domain no encontrado${RESET}"
        sleep 2
        exec bash "$BASE/menu.sh"
    fi
;;

8)
    FILE="/etc/profile.d/MoviVIP.sh"
    clear
    if [[ "${AUTO_START:-OFF}" == "OFF" ]]; then
        sed -i 's/AUTO_START=OFF/AUTO_START=ON/' "$CONFIG"
        cat > "$FILE" << 'EOF'
#!/bin/bash
if [[ $- == *i* ]]; then
    menu
fi
EOF
        chmod +x "$FILE"
        echo -e "${GREEN}✅ Auto inicio activado${RESET}"
    else
        sed -i 's/AUTO_START=ON/AUTO_START=OFF/' "$CONFIG"
        rm -f "$FILE"
        echo -e "${GOLD}⚠️ Auto inicio desactivado${RESET}"
    fi
    sleep 2
    exec bash "$BASE/menu.sh"
;;

9)
    clear
    echo -e "${GOLD} [1]${WHITE} 🗑 Remover Script"
    echo -e "${GOLD} [2]${WHITE} 🔄 Actualizar Script"
    echo -e "${RED} [0]${WHITE} ↩ Volver"
    echo ""
    read -rp " ► Opción: " OP9
    case "$OP9" in
        1)
            rm -rf /etc/movivip
            rm -f /usr/local/bin/menu
            rm -f /etc/profile.d/MoviVIP.sh
            echo -e "${GREEN}✅ Script eliminado${RESET}"
            sleep 2
            exit 0
        ;;
        2)
            # Actualizar = controlado por licencia (nunca desactiva el panel)
            if [[ -f "$BASE/update.sh" ]]; then
                bash "$BASE/update.sh"
                exit 0
            fi
            # Fallback si no existe update.sh nuevo
            cd /etc/movivip 2>/dev/null || exit 1
            if [[ -d .git ]]; then
                git reset --hard >/dev/null 2>&1
                git pull origin main >/dev/null 2>&1 || git pull >/dev/null 2>&1
            else
                TMP="/tmp/MoviVIP_update"
                rm -rf "$TMP"
                git clone https://github.com/studioanime977/MoviVIPNetwork.git "$TMP" >/dev/null 2>&1
                [[ $? -eq 0 ]] && cp -rf "$TMP"/* /etc/movivip/ && rm -rf "$TMP"
            fi
            chmod -R +x /etc/movivip
            echo -e "${GREEN}✅ Actualizado${RESET}"
            sleep 2
            exec bash "$BASE/menu.sh"
        ;;
        0) exec bash "$BASE/menu.sh" ;;
        *) exec bash "$BASE/menu.sh" ;;
    esac
;;

0)
    clear
    echo -e "${GREEN}👋 Gracias por usar MoviVIP Network Premium.${RESET}"
    echo ""
    exit 0
;;

10)
    clear
    if [[ -f "$BASE/protocolos/bot.sh" ]]; then
        bash "$BASE/protocolos/bot.sh"
    else
        echo -e "${RED}❌ bot.sh no encontrado — actualiza el sistema (opción 9)${RESET}"
        sleep 2
        exec bash "$BASE/menu.sh"
    fi
;;

11)
    clear
    echo -e "${GOLD}🧪 Módulo de pruebas${RESET}"
    echo ""
    read -rp "$(echo -e "${CYAN}➜ ENTER para volver${RESET}")"
    exec bash "$BASE/menu.sh"
;;

*)
    clear
    echo -e "${RED}❌ Opción inválida${RESET}"
    sleep 1
    exec bash "$BASE/menu.sh"
;;

esac
