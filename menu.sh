#!/bin/bash

#=========================================================
#   MoviVIP Network - PREMIUM EDITION v2.1
#   Menú principal GENÉRICO — sin datos personales
#   Todo se detecta automáticamente en cada VPS
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
# Colores
#=========================================================

RESET="\e[0m"
RED="\e[1;91m"
GREEN="\e[1;92m"
YELLOW="\e[1;93m"
BLUE="\e[1;94m"
MAGENTA="\e[1;95m"
CYAN="\e[1;96m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"

#=========================================================
# Funciones
#=========================================================

topline()    { printf "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}\n"; }
line()       { printf "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}\n"; }
bottomline() { printf "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}\n"; }

status() {
    [[ "$1" == "ON" ]] && echo -e "${GREEN}🟢 ON${RESET}" || echo -e "${RED}🔴 OFF${RESET}"
}

progress_bar() {
    local percent=$1
    local total=20
    local filled=$((percent*total/100))
    local empty=$((total-filled))
    [[ $filled -gt $total ]] && filled=$total
    printf "${GREEN}"
    for ((i=0;i<filled;i++)); do printf "█"; done
    printf "${GRAY}"
    for ((i=0;i<empty;i++)); do printf "░"; done
    printf "${RESET} ${percent}%%"
}

human() {
    local B=$1
    [[ -z "$B" ]] && B=0
    if [[ $B -ge 1073741824 ]]; then
        echo "$(awk "BEGIN{printf \"%.2f\", $B/1073741824}") GB"
    elif [[ $B -ge 1048576 ]]; then
        echo "$(awk "BEGIN{printf \"%.2f\", $B/1048576}") MB"
    elif [[ $B -ge 1024 ]]; then
        echo "$(awk "BEGIN{printf \"%.2f\", $B/1024}") KB"
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
FREE_RAM=$(free -h | awk '/Mem:/ {print $7}')
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

# Última auditoría
LAST_AUDIT=$(ls -t "$BASE"/logs/lynis-*.log 2>/dev/null | head -n1)
if [[ -n "$LAST_AUDIT" ]]; then
    AUDIT_DATE=$(basename "$LAST_AUDIT" | sed 's/lynis-//;s/.log//')
    AUDIT_DATE=$(date -d "${AUDIT_DATE:0:8}" +"%d/%m/%Y" 2>/dev/null || echo "$AUDIT_DATE")
else
    AUDIT_DATE="nunca"
fi

#=========================================================
# Consumo de red (base de datos VACÍA / auto-detectada)
#=========================================================

NET_TOTAL_IN="—"
NET_TOTAL_OUT="—"

if [[ -f "$STATE" ]]; then
    source "$STATE" 2>/dev/null
    NET_TOTAL_IN=$(human "${TOTAL_IN:-0}")
    NET_TOTAL_OUT=$(human "${TOTAL_OUT:-0}")
else
    # Crear snapshot inicial (punto de partida)
    bash "$BASE/herramientas/network_snapshot.sh" >/dev/null 2>&1
    NET_TOTAL_IN="0 B"
    NET_TOTAL_OUT="0 B"
fi

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
# Conexiones en tiempo real (solo conteo, sin usuarios)
#=========================================================

SSH_CONN=$(ps -C sshd -o args= 2>/dev/null | grep -c "\[priv\]")
DROP_CONN=$(pgrep -x dropbear 2>/dev/null | wc -l)
[[ $DROP_CONN -gt 0 ]] && DROP_CONN=$((DROP_CONN - 1))  # restar proceso maestro
ONLINE_USERS=$(ps -C sshd -o args= 2>/dev/null | grep "\[priv\]" | awk -F'sshd: ' '{print $2}' | awk '{print $1}' | grep -vE '^(root|unknown|invalid|\(null\))$' | sort -u | wc -l)
TOTAL_CONN=$((SSH_CONN + DROP_CONN))
CONN_HORA=$(date '+%d/%m/%Y %H:%M:%S')

#=========================================================
# PANTALLA
#=========================================================

clear
topline
printf "${WHITE}║             ⚡ MoviVIP Network PREMIUM ⚡             ║${RESET}\n"
printf "${GRAY}║              Premium Edition v2.1 — Genérico              ║${RESET}\n"
bottomline
echo ""

# --- SISTEMA ---
echo -e "${CYAN}┌──────────────────── 🖥 SISTEMA ────────────────────┐${RESET}"
printf "${WHITE}│ ${CYAN}OS${WHITE}        %-44s│\n" "$OS"
printf "${WHITE}│ ${CYAN}Kernel${WHITE}    %-44s│\n" "$KERNEL"
printf "${WHITE}│ ${CYAN}CPU${WHITE}       %-44s│\n" "$CPU_CORES Cores ($ARCH)"
printf "${WHITE}│ ${CYAN}Fecha${WHITE}     %-44s│\n" "$FECHA"
printf "${WHITE}│ ${CYAN}Uptime${WHITE}    %-44s│\n" "$UPTIME"
echo -ne "${WHITE}│ ${CYAN}RAM${WHITE}       "
progress_bar "$RAM_USE"
printf "%*s│\n" $((29-${#RAM_USE})) ""
echo -ne "${WHITE}│ ${CYAN}CPU Load${WHITE}  "
progress_bar "$CPU_USE"
printf "%*s│\n" $((29-${#CPU_USE})) ""
printf "${WHITE}│ ${CYAN}Disco${WHITE}     %-44s│\n" "$DISK usado"
echo -e "${CYAN}└───────────────────────────────────────────────────┘${RESET}"
echo ""

# --- RED ---
echo -e "${CYAN}┌───────────────────── 🌐 RED ───────────────────────┐${RESET}"
printf "${WHITE}│ ${CYAN}Dominio CF${WHITE}  %-42s│\n" "${SERVER_DOMAIN:-NO CONFIGURADO}"
printf "${WHITE}│ ${CYAN}IP Local${WHITE}    %-42s│\n" "$IP"
printf "${WHITE}│ ${CYAN}IP Pública${WHITE}  %-42s│\n" "$PUBLIC_IP"
printf "${WHITE}│ ${CYAN}Cloudflare${WHITE}  %-42b│\n" "$(status "${CLOUDFLARE_STATUS:-OFF}")"
echo -e "${CYAN}└───────────────────────────────────────────────────┘${RESET}"
echo ""

# --- CONSUMO DE RED ---
echo -e "${CYAN}┌──────────────── 📊 CONSUMO DE RED ────────────────┐${RESET}"
printf "${WHITE}│ ${CYAN}Descargado${WHITE}  %-42s│\n" "$NET_TOTAL_IN"
printf "${WHITE}│ ${CYAN}Subido${WHITE}      %-42s│\n" "$NET_TOTAL_OUT"
printf "${WHITE}│ ${CYAN}Tiempo Real${WHITE} %-42s│\n" "📈 Ver en Herramientas → [10]"
echo -e "${CYAN}└───────────────────────────────────────────────────┘${RESET}"
echo ""

# --- PROTOCOLOS ---
echo -e "${CYAN}┌──────────────── 🚀 PROTOCOLOS ────────────────────┐${RESET}"
printf "${WHITE}│ %-14s %-6b %-30s│${RESET}\n" "OpenSSH" "$SSH_S" "Puerto 22"
printf "${WHITE}│ %-14s %-6b %-30s│${RESET}\n" "Dropbear" "$DROP_S" "Puerto 90/109/143"
printf "${WHITE}│ %-14s %-6b %-30s│${RESET}\n" "SSL/TLS" "$HA_S" "HAProxy 80/443/8080"
printf "${WHITE}│ %-14s %-6b %-30s│${RESET}\n" "UDP Custom" "$UDP_S" "Puerto 2100"
printf "${WHITE}│ %-14s %-6b %-30s│${RESET}\n" "SlowDNS" "$SLOW_S" "Puerto 5300"
printf "${WHITE}│ %-14s %-6b %-30s│${RESET}\n" "Xray/V2Ray" "$XRAY_S" "Puertos 10001+"
printf "${WHITE}│ %-14s %-6b %-30s│${RESET}\n" "BadVPN" "$BAD_S" "7200/7300"
printf "${WHITE}│ %-14s %-6b %-30s│${RESET}\n" "ZiVPN" "$ZIP_S" "Puerto UDP"
echo -e "${CYAN}└───────────────────────────────────────────────────┘${RESET}"
echo ""

# --- SEGURIDAD ---
echo -e "${CYAN}┌────────────────── 🛡 SEGURIDAD ───────────────────┐${RESET}"
printf "${WHITE}│ ${CYAN}Fail2ban${WHITE}    %-42b│\n" "$SEC_STATUS"
printf "${WHITE}│ ${CYAN}Jails${WHITE}       %-42s│\n" "${SEC_JAILS:--}"
printf "${WHITE}│ ${CYAN}Auditoría${WHITE}   %-42s│\n" "Última: $AUDIT_DATE"
echo -e "${CYAN}└───────────────────────────────────────────────────┘${RESET}"
echo ""

# --- RECURSOS ---
echo -e "${CYAN}┌────────────────── 📊 RECURSOS ────────────────────┐${RESET}"
printf "${WHITE}│ RAM Total : %-12s Libre : %-12s Usada : %-10s│\n" \
    "$TOTAL_RAM" "$FREE_RAM" "$USED_RAM"
echo -e "${CYAN}└───────────────────────────────────────────────────┘${RESET}"
echo ""

# --- CONEXIONES EN TIEMPO REAL ---
echo -e "${CYAN}┌──────────────────────────────────────────────────┐${RESET}"
echo -e "${CYAN}│             👁 CONEXIONES EN VIVO 👁            ${CYAN}│${RESET}"
printf "${WHITE}│ ${CYAN}%-15s${WHITE}: ${GREEN}%-31s${WHITE} │\n" "SSH activas" "$SSH_CONN conexiones"
printf "${WHITE}│ ${CYAN}%-15s${WHITE}: ${GREEN}%-31s${WHITE} │\n" "Dropbear" "$DROP_CONN conexiones"
printf "${WHITE}│ ${CYAN}%-15s${WHITE}: ${GREEN}%-31s${WHITE} │\n" "Total activas" "$TOTAL_CONN conexiones"
printf "${WHITE}│ ${CYAN}%-15s${WHITE}: ${GREEN}%-31s${WHITE} │\n" "Usuarios Online" "$ONLINE_USERS usuarios"
printf "${WHITE}│ ${CYAN}%-15s${WHITE}: ${GREEN}%-31s${WHITE} │\n" "Actualizado" "$CONN_HORA"
echo -e "${CYAN}└──────────────────────────────────────────────────┘${RESET}"
echo ""

#=========================================================
# MENÚ PRINCIPAL
#=========================================================

echo -e "${CYAN}╔══════════════════════ ⚙ MENÚ PRINCIPAL ══════════════════════╗${RESET}"
printf "${WHITE}║ ${YELLOW}[01]${WHITE} 👥 Creación de Usuarios SSH            ║${RESET}\n"
printf "${WHITE}║ ${YELLOW}[02]${WHITE} 📦 Instalador de Protocolos            ║${RESET}\n"
printf "${WHITE}║ ${YELLOW}[03]${WHITE} 🧰 Herramientas                        ║${RESET}\n"
printf "${WHITE}║ ${YELLOW}[04]${WHITE} 🛡 Seguridad (Fail2ban + Auditoría)    ║${RESET}\n"
printf "${WHITE}║ ${YELLOW}[05]${WHITE} 📊 Consumo de Red en Tiempo Real       ║${RESET}\n"
printf "${WHITE}║ ${YELLOW}[06]${WHITE} 🚀 Optimizar VPS            %-9b║${RESET}\n" "$(status "${OPTIMIZAR:-OFF}")"
printf "${WHITE}║ ${YELLOW}[07]${WHITE} 🌐 Cambiar Dominio                     ║${RESET}\n"
printf "${WHITE}║ ${YELLOW}[08]${WHITE} 🔄 Auto Inicio              %-9b║${RESET}\n" "$(status "${AUTO_START:-OFF}")"
printf "${WHITE}║ ${YELLOW}[09]${WHITE} 🛠 Update / Remove                     ║${RESET}\n"
printf "${WHITE}║ ${YELLOW}[00]${WHITE} 🚪 Salir                               ║${RESET}\n"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${RESET}"
echo ""
read -rp "$(echo -e "${CYAN}➜ Seleccione una opción ${WHITE}➤ ${RESET}")" OPCION

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
    echo -e "${WHITE}║                  🛡 SEGURIDAD DEL SERVIDOR                  ║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "${YELLOW} [1]${WHITE} 🛡 Fail2ban (instalar/configurar/desbanear)"
    echo -e "${YELLOW} [2]${WHITE} 🔍 Auditoría completa (rkhunter+chkrootkit+lynis)"
    echo -e "${YELLOW} [0]${WHITE} ↩ Volver"
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
        echo -e "${YELLOW}⚠️ Auto inicio desactivado${RESET}"
    fi
    sleep 2
    exec bash "$BASE/menu.sh"
;;

9)
    clear
    echo -e "${YELLOW} [1]${WHITE} 🗑 Remover Script"
    echo -e "${YELLOW} [2]${WHITE} 🔄 Actualizar Script"
    echo -e "${YELLOW} [0]${WHITE} ↩ Volver"
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
