#!/bin/bash

#=========================================================
#        MoviVIP Network - FAIL2BAN
#        Instalador / Configurador de Seguridad
#=========================================================

BASE="/etc/movivip"
CONFIG="$BASE/config.conf"

[[ -f "$CONFIG" ]] && source "$CONFIG"

# Colores
CYAN="\e[1;96m"
BLUE="\e[1;94m"
GREEN="\e[1;92m"
YELLOW="\e[1;93m"
RED="\e[1;91m"
WHITE="\e[1;97m"
RESET="\e[0m"

clear
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
echo -e "${WHITE}              🛡 FAIL2BAN — PROTECCIÓN SSH / VPS${RESET}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"

# Comprobar root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ Necesita ejecutarse como root${RESET}"
    exit 1
fi

#=========================================================
# Instalar fail2ban si no está
#=========================================================

if ! command -v fail2ban-client >/dev/null 2>&1; then
    echo -e "${YELLOW}📦 Instalando fail2ban...${RESET}"
    apt update -y
    apt install -y fail2ban whois
    echo -e "${GREEN}✅ fail2ban instalado${RESET}"
else
    echo -e "${GREEN}✅ fail2ban ya está instalado${RESET}"
fi

#=========================================================
# Configuración jail.local (genérica, sin datos personales)
#=========================================================

JAIL="/etc/fail2ban/jail.local"

echo -e "${CYAN}⚙️ Configurando jail.local...${RESET}"

cat > "$JAIL" <<'EOF'
[DEFAULT]
# Tiempo de baneo: 1 hora
bantime  = 1h
# Ventana de detección: 10 minutos
findtime = 10m
# Intentos fallidos antes de banear
maxretry = 3
# Ignorar tráfico local
ignoreip = 127.0.0.1/8 ::1
# Acción de baneo (iptables + registro)
banaction = iptables-multiport
banaction_allports = iptables-allports
# Notificaciones (vacío por defecto)
destemail =
sender =
mta = sendmail
# Protocolo de log
backend = auto
# Registro propio de fail2ban
logtarget = /var/log/fail2ban.log

[sshd]
enabled  = true
port     = ssh
filter   = sshd
logpath  = /var/log/auth.log
maxretry = 3
bantime  = 1h

[dropbear]
enabled  = true
port     = 90,109,143
filter   = dropbear
logpath  = /var/log/auth.log
maxretry = 3
bantime  = 1h

[sshd-ddos]
enabled  = true
port     = ssh
filter   = sshd-ddos
logpath  = /var/log/auth.log
maxretry = 5
bantime  = 2h

[recidive]
enabled  = true
logpath  = /var/log/fail2ban.log
banaction = iptables-allports
bantime  = 1w
findtime = 1d
maxretry = 5
EOF

# Solo activar jail de dropbear si el servicio existe
if ! systemctl list-unit-files | grep -q "^dropbear_custom.service"; then
    sed -i '/^\[dropbear\]/,/^bantime  = 1h$/s/^enabled  = true/enabled  = false/' "$JAIL"
fi

#=========================================================
# Activar / reiniciar servicio
#=========================================================

systemctl enable fail2ban >/dev/null 2>&1
systemctl restart fail2ban
sleep 2

if systemctl is-active --quiet fail2ban; then
    echo -e "${GREEN}✅ fail2ban ACTIVO${RESET}"
else
    echo -e "${RED}❌ fail2ban no arrancó. Revisa: journalctl -u fail2ban${RESET}"
fi

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
echo -e "${WHITE}                📊 ESTADO DE SEGURIDAD${RESET}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
echo ""

# Jails activos
JAILS=$(fail2ban-client status 2>/dev/null | grep "Jail list" | sed 's/.*Jail list:[[:space:]]*//')
if [[ -n "$JAILS" ]]; then
    echo -e "${GREEN}🧩 Jails activos:${RESET} $JAILS"
    echo ""
    for J in $JAILS; do
        STATUS=$(fail2ban-client status "$J" 2>/dev/null)
        BANNED=$(echo "$STATUS" | grep "Currently banned" | awk '{print $4}')
        TOTAL=$(echo "$STATUS" | grep "Total banned" | awk '{print $4}')
        echo -e "  ${CYAN}◉ ${WHITE}$J${RESET} → ${RED}Baneados: $BANNED${RESET} | ${YELLOW}Total: $TOTAL${RESET}"
    done
else
    echo -e "${YELLOW}⚠️ No hay jails activos todavía${RESET}"
fi

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
echo -e "${YELLOW} [1]${WHITE} Ver IPs baneadas"
echo -e "${YELLOW} [2]${WHITE} Desbanear una IP"
echo -e "${YELLOW} [3]${WHITE} Añadir IP a lista blanca"
echo -e "${YELLOW} [4]${WHITE} Reinstalar / Reiniciar fail2ban"
echo -e "${YELLOW} [0]${WHITE} Volver"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
echo ""
read -rp " ► Opción: " OP

case "$OP" in

1)
    echo ""
    for J in $(fail2ban-client status 2>/dev/null | grep "Jail list" | sed 's/.*Jail list:[[:space:]]*//'); do
        echo -e "${CYAN}═══ Jail: $J ${RESET}"
        fail2ban-client status "$J" | grep "Banned IP"
    done
    echo ""
    read -rp " ↩ Enter para continuar..."
    exec bash "$BASE/herramientas/fail2ban.sh"
;;

2)
    echo ""
    read -rp " 🌐 IP a desbanear: " UNBAN_IP
    for J in $(fail2ban-client status 2>/dev/null | grep "Jail list" | sed 's/.*Jail list:[[:space:]]*//'); do
        fail2ban-client set "$J" unbanip "$UNBAN_IP" 2>/dev/null
    done
    echo -e "${GREEN}✅ IP $UNBAN_IP desbaneada${RESET}"
    sleep 2
    exec bash "$BASE/herramientas/fail2ban.sh"
;;

3)
    echo ""
    read -rp " 🌐 IP a incluir en whitelist: " WL_IP
    if grep -q "^ignoreip" "$JAIL"; then
        sed -i "s/^ignoreip = .*/ignoreip = 127.0.0.1\/8 ::1 $WL_IP/" "$JAIL"
    else
        echo "ignoreip = 127.0.0.1/8 ::1 $WL_IP" >> "$JAIL"
    fi
    systemctl restart fail2ban
    echo -e "${GREEN}✅ IP $WL_IP añadida a whitelist${RESET}"
    sleep 2
    exec bash "$BASE/herramientas/fail2ban.sh"
;;

4)
    systemctl restart fail2ban
    sleep 2
    echo -e "${GREEN}✅ fail2ban reiniciado${RESET}"
    exec bash "$BASE/herramientas/fail2ban.sh"
;;

0)
    exec bash "$BASE/herramientas/menu.sh"
;;

*)
    echo -e "${RED}❌ Opción inválida${RESET}"
    sleep 2
    exec bash "$BASE/herramientas/fail2ban.sh"
;;

esac
