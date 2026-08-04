#!/bin/bash

#=========================================================
#   MOVIVIP NETWORK — PREMIUM EDITION v2.1
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

human() {
    local B=$1
    [[ -z "$B" ]] && B=0
    if [[ $B -ge 1000000000000 ]]; then
        echo "$(awk "BEGIN{printf \"%.2f\", $B/1000000000000}") TB"
    elif [[ $B -ge 1000000000 ]]; then
        echo "$(awk "BEGIN{printf \"%.2f\", $B/1000000000}") GB"
    elif [[ $B -ge 1000000 ]]; then
        echo "$(awk "BEGIN{printf \"%.2f\", $B/1000000}") MB"
    elif [[ $B -ge 1000 ]]; then
        echo "$(awk "BEGIN{printf \"%.2f\", $B/1000}") KB"
    else
        echo "$B B"
    fi
}

#=========================================================
# Información del sistema (auto-detectada)
#=========================================================

OS=$(source /etc/os-release && echo "$NAME $VERSION_ID")
KERNEL=$(uname -r)
ARCH=$(uname -m)
CPU_CORES=$(nproc)
IP=$(hostname -I 2>/dev/null | awk '{print $1}')
PUBLIC_IP=$(curl -s --max-time 3 ifconfig.me 2>/dev/null || echo "-")
FECHA=$(date +"%d/%m/%Y %H:%M")

TOTAL_RAM=$(free -h | awk '/Mem:/ {print $2}')
USED_RAM=$(free -h | awk '/Mem:/ {print $3}')
RAM_USE=$(free | awk '/Mem:/ {printf("%.0f"),$3/$2*100}')
CPU_USE=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2+$4)}')
DISK=$(df -h / | awk 'NR==2 {print $5}')
UPTIME=$(uptime -p | sed 's/up //')

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
# Estado de protocolos (auto-detectado por servicio)
#=========================================================

svc_status() {
    local SVC="$1"
    if systemctl list-unit-files 2>/dev/null | grep -q "^${SVC}.service"; then
        if systemctl is-active --quiet "$SVC" 2>/dev/null; then
            echo -e "${GREEN}🟢${RESET}"
        else
            echo -e "${RED}🔴${RESET}"
        fi
    else
        echo -e "${GRAY}⚪${RESET}"
    fi
}

SSH_S=$(svc_status ssh)
DROP_S=$(svc_status dropbear_custom)
HA_S=$(svc_status haproxy)
UDP_S=$(svc_status udp-custom)
SLOW_S=$(svc_status slowdns)
XRAY_S=$(svc_status xray)
BAD_S=$(svc_status badvpn-udpgw-7200)
ZIP_S=$(svc_status zivpn)

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
# PANTALLA — DASHBOARD COMPACTO
#=========================================================

clear
H1
printf "${CYAN}║${GOLD}   ⚡ MOVIVIP NETWORK ⚡ ${CYAN}PREMIUM EDITION v2.1${RESET}      ${WHITE}Control Total${RESET}${CYAN}          ║${RESET}\n"
printf "${CYAN}║${BLUE}   Alto Rendimiento · Seguridad Total · SISTEMA ÓPTIMO ACTIVO${CYAN}   ║${RESET}\n"
H2

# --- SISTEMA (1 línea) ---
printf "${CYAN}║ ${GOLD}🖥 SISTEMA${RESET}${WHITE}  ${OS} ${GRAY}·${WHITE} ${CPU_CORES} Cores ${GRAY}·${WHITE} ${ARCH}${RESET}${CYAN}              ║${RESET}\n"
printf "${CYAN}║${RESET}   RAM ${RESET}"
progress_bar "$RAM_USE"
printf "${WHITE} ${RAM_USE}%% ${GRAY}(${USED_RAM}/${TOTAL_RAM})${RESET}   ${CYAN}CPU${RESET} "
progress_bar "$CPU_USE"
printf "${WHITE} ${CPU_USE}%%${RESET}   ${CYAN}DISK${RESET} ${WHITE}${DISK}${RESET}${CYAN}       ║${RESET}\n"
printf "${CYAN}║${RESET}   ${GRAY}Kernel ${WHITE}${KERNEL}${RESET}   ${GRAY}Up ${WHITE}${UPTIME}${RESET}   ${GRAY}${FECHA}${RESET}${CYAN}                  ║${RESET}\n"
H2

# --- RED + CONSUMO (2 líneas) ---
printf "${CYAN}║ ${GOLD}🌐 RED${RESET}${WHITE}  IP ${IP} ${GRAY}·${WHITE} Pub ${PUBLIC_IP} ${GRAY}·${WHITE} CF $(status "${CLOUDFLARE_STATUS:-OFF}")${RESET}${CYAN}        ║${RESET}\n"
printf "${CYAN}║ ${GOLD}📊 CONSUMO${RESET}${WHITE}  ↓ ${NET_TOTAL_IN}  ${GRAY}·${WHITE} ↑ ${NET_TOTAL_OUT}  ${GRAY}·${WHITE} Total ${NET_TOTAL_SUM}${RESET}${CYAN}   ║${RESET}\n"
printf "${CYAN}║${RESET}   ${GRAY}Dominio: ${WHITE}${SERVER_DOMAIN:-NO CONFIGURADO}${RESET}   ${GRAY}Detalle: menú → [05]${RESET}${CYAN}          ║${RESET}\n"
H2

# --- PROTOCOLOS (1 línea) ---
printf "${CYAN}║ ${GOLD}🚀 PROTOCOLOS${RESET}   ${WHITE}SSH${RESET} ${SSH_S} ${WHITE}Drop${RESET} ${DROP_S} ${WHITE}SSL${RESET} ${HA_S} ${WHITE}UDP${RESET} ${UDP_S} ${WHITE}SlowDNS${RESET} ${SLOW_S} ${WHITE}Xray${RESET} ${XRAY_S}${RESET}${CYAN}    ║${RESET}\n"
printf "${CYAN}║${RESET}   ${WHITE}BadVPN${RESET} ${BAD_S} ${WHITE}ZiVPN${RESET} ${ZIP_S}    ${GRAY}·${WHITE} 👁 Online ${GREEN}${ONLINE_USERS}${RESET} ${GRAY}·${WHITE} Con ${GREEN}${TOTAL_CONN}${RESET} ${GRAY}·${WHITE} ${CONN_HORA}${RESET}${CYAN}      ║${RESET}\n"
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
printf "${CYAN}║${RESET}  ${GOLD}[05]${WHITE} 📊 Consumo Red    ${CYAN}│${RESET}  ${GOLD}[00]${WHITE} 🚪 Salir          ${CYAN}    ║${RESET}\n"
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

*)
    clear
    echo -e "${RED}❌ Opción inválida${RESET}"
    sleep 1
    exec bash "$BASE/menu.sh"
;;

esac
