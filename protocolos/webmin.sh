#!/bin/bash

#==================================================
# MoviVIP Network Premium
# Webmin Manager — Panel de administración web (10000)
# Gestión: instalar · desinstalar · estado · reiniciar
#==================================================

# ── i18n shim (auto) ───────────────────────────────
if ! declare -F trx >/dev/null 2>&1; then trx() { printf '%s' "$1"; }; fi
# ─────────────────────────────────────────────────────────
BASE="/etc/movivip"
CONFIG="$BASE/config.conf"

[[ -f "$CONFIG" ]] || { echo "❌ No existe $CONFIG"; exit 1; }
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

WEBMIN_CONF="/etc/webmin/miniserv.conf"

# Navegación
[[ -f "$BASE/lib/nav.sh" ]] && source "$BASE/lib/nav.sh"

#--------------------------------------------------
# Puerto real de Webmin
#--------------------------------------------------
get_webmin_port() {
    grep -oE '^port=[0-9]+' "$WEBMIN_CONF" 2>/dev/null | cut -d= -f2 | head -1
}

#--------------------------------------------------
# Instalar
#--------------------------------------------------
install_webmin() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}          🛠️ INSTALAR WEBMIN${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    echo "$(trx '📦 Instalando dependencias...')"
    DEBIAN_FRONTEND=noninteractive apt-get install -y curl wget >/dev/null 2>&1

    echo "$(trx '📥 Añadiendo repositorio oficial de Webmin...')"
    curl -o /tmp/webmin-setup-repo.sh https://raw.githubusercontent.com/webmin/webmin/master/webmin-setup-repo.sh 2>/dev/null
    if [[ -f /tmp/webmin-setup-repo.sh ]]; then
        sh /tmp/webmin-setup-repo.sh >/dev/null 2>&1
        rm -f /tmp/webmin-setup-repo.sh
    fi

    echo "$(trx '📦 Instalando webmin...')"
    DEBIAN_FRONTEND=noninteractive apt-get update -qq 2>/dev/null
    DEBIAN_FRONTEND=noninteractive apt-get install -y webmin 2>&1 | tail -3

    if systemctl list-unit-files 2>/dev/null | grep -q "^webmin.service"; then
        systemctl enable webmin >/dev/null 2>&1
        systemctl restart webmin >/dev/null 2>&1 || true

        PORT_REAL=$(get_webmin_port)
        [[ -z "$PORT_REAL" ]] && PORT_REAL="10000"

        iptables -C INPUT -p tcp --dport "$PORT_REAL" -j ACCEPT 2>/dev/null \
            || iptables -A INPUT -p tcp --dport "$PORT_REAL" -j ACCEPT
        if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
            ufw allow "$PORT_REAL/tcp" >/dev/null 2>&1
        fi

        sed -i '/^WEBMIN=/d' "$CONFIG"
        echo "WEBMIN=ON" >> "$CONFIG"
        sed -i '/^WEBMIN_PORT=/d' "$CONFIG"
        echo "WEBMIN_PORT=$PORT_REAL" >> "$CONFIG"
        source "$CONFIG"

        IP_LOCAL=$(hostname -I | awk '{print $1}')
        echo ""
        echo -e "${GREEN}✅ Webmin instalado.${RESET}"
        echo -e "${WHITE}   Accede: ${CYAN}https://$IP_LOCAL:$PORT_REAL${RESET}"
        echo -e "${YELLOW}   (usa tu usuario root / contraseña del VPS, acepta el certificado)${RESET}"
    else
        echo -e "${YELLOW}ℹ️  Webmin no aparece como servicio systemd, revisa:${RESET}"
        echo "   systemctl status webmin"
    fi
    sleep 4
}

#--------------------------------------------------
# Desinstalar
#--------------------------------------------------
remove_webmin() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}          🗑 ELIMINAR WEBMIN${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    read -rp "$(trx '¿Eliminar Webmin? (s/n): ')" R
    [[ ! "$R" =~ ^[Ss]$ ]] && return

    systemctl stop webmin 2>/dev/null
    DEBIAN_FRONTEND=noninteractive apt-get purge -y webmin >/dev/null 2>&1
    rm -rf /etc/webmin 2>/dev/null

    sed -i '/^WEBMIN=/d' "$CONFIG"
    echo "WEBMIN=OFF" >> "$CONFIG"
    sed -i '/^WEBMIN_PORT=/d' "$CONFIG"
    source "$CONFIG"

    echo ""
    echo "$(trx '✅ Webmin eliminado.')"
    sleep 3
}

#--------------------------------------------------
# Reiniciar
#--------------------------------------------------
restart_webmin() {
    echo "$(trx '🔄 Reiniciando webmin...')"
    systemctl restart webmin 2>/dev/null || /etc/webmin/restart 2>/dev/null
    if systemctl is-active --quiet webmin 2>/dev/null; then
        echo "$(trx '✅ Webmin activo.')"
    else
        echo "$(trx '⚠️  Revisa el servicio manualmente.')"
    fi
    sleep 3
}

#--------------------------------------------------
# Estado
#--------------------------------------------------
status_webmin() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}          📊 ESTADO WEBMIN${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    systemctl status webmin --no-pager 2>/dev/null | head -12
    echo ""
    PORT_REAL=$(get_webmin_port)
    echo -e " Puerto Webmin : ${GREEN}${PORT_REAL:-10000}${RESET}"
    IP_LOCAL=$(hostname -I | awk '{print $1}')
    echo -e " URL          : ${CYAN}https://$IP_LOCAL:${PORT_REAL:-10000}${RESET}"
    echo ""
    read -n1 -r -p "$(trx 'Presione una tecla...')"
}

#==================================================
# Menú Principal
#==================================================
while true; do

clear
source "$CONFIG"

if systemctl is-active --quiet webmin 2>/dev/null; then
    STATUS="${GREEN}🟢 ACTIVO${RESET}"
else
    STATUS="${RED}🔴 DETENIDO${RESET}"
fi

mv_header "🛠️ Webmin" "$(trx 'Panel de administración web · puerto ')$(get_webmin_port || echo '10000')" "v6.2"
movivip_contacts 2>/dev/null || true

echo -e " Estado : $STATUS"
echo ""

if [[ "$WEBMIN" == "ON" ]]; then
    LBL=("Desinstalar Webmin" "Reiniciar Servicio" "Ver Estado")
else
    LBL=("Instalar Webmin")
fi
SEL=$(nav_pick "► Opción:" "${LBL[@]}" "↩ Regresar") || SEL=0
[[ $SEL -eq $((${#LBL[@]}+1)) ]] && SEL=0
OP="$SEL"

case "$OP" in
1)
    if [[ "$WEBMIN" == "ON" ]]; then
        remove_webmin
    else
        install_webmin
    fi
;;
2)
    [[ "$WEBMIN" == "ON" ]] && restart_webmin
;;
3)
    [[ "$WEBMIN" == "ON" ]] && status_webmin
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