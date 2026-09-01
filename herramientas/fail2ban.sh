#!/bin/bash

#=========================================================
#   MoviVIP Network - FAIL2BAN
#   Protección SSH / VPS contra fuerza bruta
#   Uso: fail2ban.sh            → menú interactivo
#        fail2ban.sh --install  → modo silencioso (install.sh)
#=========================================================

BASE="/etc/movivip"
CONFIG="$BASE/config.conf"

# ── Cargar idioma + trx + diseño (imprescindible para trx / movivip_sub_header) ──
if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)"
fi
source "$BASE/lib/ui.sh" 2>/dev/null || true
source "$BASE/lib/nav.sh" 2>/dev/null || true

# Cargar funciones multi-distro
[[ -f "$BASE/functions/pkg.sh" ]] && source "$BASE/functions/pkg.sh"

[[ -f "$CONFIG" ]] && source "$CONFIG"

# Colores MoviVIP
RESET="\e[0m"; RED="\e[1;91m"; GREEN="\e[1;92m"; GOLD="\e[1;93m"
BLUE="\e[1;94m"; CYAN="\e[1;96m"; WHITE="\e[1;97m"; GRAY="\e[1;90m"

JAIL="/etc/fail2ban/jail.local"

#=========================================================
# Configurar fail2ban (jail.local + arranque)
#=========================================================
configurar_fail2ban() {

    # Instalar si falta
    if ! command -v fail2ban-client >/dev/null 2>&1; then
        pkg_update >/dev/null 2>&1
        pkg_install fail2ban whois >/dev/null 2>&1
    fi

    cat > "$JAIL" <<'EOF'
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 3
ignoreip = 127.0.0.1/8 ::1
banaction = iptables-multiport
banaction_allports = iptables-allports
destemail =
sender =
mta = sendmail
backend = auto
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

    systemctl enable fail2ban >/dev/null 2>&1
    systemctl restart fail2ban >/dev/null 2>&1 || true
    sleep 2
}

#=========================================================
# MODO INSTALACIÓN SILENCIOSA (desde install.sh)
#=========================================================
if [[ "$1" == "--install" ]]; then
    configurar_fail2ban
    exit 0
fi

#=========================================================
# MODO INTERACTIVO
#=========================================================
clear

if declare -F mv_header >/dev/null 2>&1; then
    mv_header "$(trx '🛡 FAIL2BAN')" "$(trx 'Protección SSH / VPS')" "v6.2"
    movivip_contacts 2>/dev/null || true
elif declare -F movivip_sub_header >/dev/null 2>&1; then
    movivip_sub_header "$(trx '🛡 FAIL2BAN — PROTECCIÓN SSH / VPS')"
else
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${GOLD}      🛡 FAIL2BAN — PROTECCIÓN SSH / VPS 🛡${RESET}              ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
fi
echo ""

# Comprobar root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ Necesita ejecutarse como root${RESET}"
    exit 1
fi

echo -e "${GREEN}✅ Configurando fail2ban...${RESET}"
configurar_fail2ban

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

JAILS=$(fail2ban-client status 2>/dev/null | grep "Jail list" | sed 's/.*Jail list:[[:space:]]*//')
if [[ -n "$JAILS" ]]; then
    echo -e "${GREEN}🧩 Jails activos:${RESET} $JAILS"
    echo ""
    for J in $JAILS; do
        STATUS=$(fail2ban-client status "$J" 2>/dev/null)
        BANNED=$(echo "$STATUS" | grep "Currently banned" | awk '{print $4}')
        TOTAL=$(echo "$STATUS" | grep "Total banned" | awk '{print $4}')
        echo -e "  ${CYAN}◉ ${WHITE}$J${RESET} → ${RED}Baneados: $BANNED${RESET} | ${GOLD}Total: $TOTAL${RESET}"
    done
else
    echo -e "${GOLD}⚠️ No hay jails activos todavía${RESET}"
fi

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
printf "${GOLD} [1]${WHITE} Ver IPs baneadas\n"
printf "${GOLD} [2]${WHITE} Desbanear una IP\n"
printf "${GOLD} [3]${WHITE} Añadir IP a lista blanca\n"
printf "${GOLD} [4]${WHITE} Reinstalar / Reiniciar fail2ban\n"
printf "${RED} [0]${WHITE} Volver\n"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
echo ""
read -rp "$(trx ' ► Opción: ')" OP

case "$OP" in

1)
    echo ""
    for J in $(fail2ban-client status 2>/dev/null | grep "Jail list" | sed 's/.*Jail list:[[:space:]]*//'); do
        echo -e "${CYAN}═══ Jail: $J ${RESET}"
        fail2ban-client status "$J" | grep "Banned IP"
    done
    echo ""
    read -rp "$(trx ' ↩ Enter para continuar...')"
    exec bash "$BASE/herramientas/fail2ban.sh"
;;

2)
    echo ""
    read -rp "$(trx ' 🌐 IP a desbanear: ')" UNBAN_IP
    for J in $(fail2ban-client status 2>/dev/null | grep "Jail list" | sed 's/.*Jail list:[[:space:]]*//'); do
        fail2ban-client set "$J" unbanip "$UNBAN_IP" 2>/dev/null
    done
    echo -e "${GREEN}✅ IP $UNBAN_IP desbaneada${RESET}"
    sleep 2
    exec bash "$BASE/herramientas/fail2ban.sh"
;;

3)
    echo ""
    read -rp "$(trx ' 🌐 IP a incluir en whitelist: ')" WL_IP
    if grep -q "^ignoreip" "$JAIL"; then
        sed -i "s/^ignoreip = .*/ignoreip = 127.0.0.1\/8 ::1 $WL_IP/" "$JAIL"
    else
        echo "ignoreip = 127.0.0.1/8 ::1 $WL_IP" >> "$JAIL"
    fi
    systemctl restart fail2ban >/dev/null 2>&1 || true
    echo -e "${GREEN}✅ IP $WL_IP añadida a whitelist${RESET}"
    sleep 2
    exec bash "$BASE/herramientas/fail2ban.sh"
;;

4)
    systemctl restart fail2ban >/dev/null 2>&1 || true
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
