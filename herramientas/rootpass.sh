#!/bin/bash

# ── i18n shim (auto) ───────────────────────────────
if ! declare -F trx >/dev/null 2>&1; then trx() { printf '%s' "$1"; }; fi
# ─────────────────────────────────────────────────────────
BASE="/etc/movivip"

# ── Cargar idioma + diseño + navegación ─────────────
if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)"
fi
source "$BASE/lib/ui.sh" 2>/dev/null || true
source "$BASE/lib/nav.sh" 2>/dev/null || true

RESET="\e[0m"; RED="\e[1;91m"; GREEN="\e[1;92m"; GOLD="\e[1;93m"
BLUE="\e[1;94m"; CYAN="\e[1;96m"; WHITE="\e[1;97m"; GRAY="\e[1;90m"

clear

# Verificar que sea root
if [[ $EUID -ne 0 ]]; then
    echo "$(trx '❌ Debes ejecutar el script como usuario root.')"
    echo ""
    echo "Ejecuta:"
    echo "sudo -i"
    echo ""
    read -n1 -r -p "$(trx 'Presiona una tecla para regresar...')"
    exec bash "$BASE/herramientas/menu.sh"
fi

read -rsp "$(trx '🔑 Nueva contraseña: ')" PASS1
echo
read -rsp "$(trx '🔑 Confirmar contraseña: ')" PASS2
echo

if [[ "$PASS1" != "$PASS2" ]]; then
    echo ""
    echo "$(trx '❌ Las contraseñas no coinciden.')"
    sleep 2
    exec bash "$BASE/herramientas/menu.sh"
fi

HASH=$(openssl passwd -6 "$PASS1" 2>/dev/null)
usermod -p "$HASH" root || {
    echo ""
    echo "$(trx '❌ No se pudo cambiar la contraseña.')"
    sleep 2
    exec bash "$BASE/herramientas/menu.sh"
}

# Habilitar acceso root por SSH
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
grep -q "^PermitRootLogin" /etc/ssh/sshd_config || \
echo "$(trx 'PermitRootLogin yes')" >> /etc/ssh/sshd_config

# Habilitar autenticación por contraseña
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
grep -q "^PasswordAuthentication" /etc/ssh/sshd_config || \
echo "$(trx 'PasswordAuthentication yes')" >> /etc/ssh/sshd_config

# Ubuntu 22.04 y 24.04
mkdir -p /etc/ssh/sshd_config.d
cat >/etc/ssh/sshd_config.d/99-root.conf <<EOF
PermitRootLogin yes
PasswordAuthentication yes
EOF

systemctl restart ssh 2>/dev/null || systemctl restart sshd

# ============================================================
# SINCRONIZAR CONTRASEÑA CON EL BOT (si está instalado)
# El bot usa VPS_PASSWORD para conectarse al VPS; al cambiar la
# contraseña root, la misma nueva contraseña debe surtir efecto
# en el bot. bot.sh --sync-pass reescribe config.py y reinicia.
# ============================================================
if [[ -f "$BASE/protocolos/bot.sh" ]]; then
    bash "$BASE/protocolos/bot.sh" --sync-pass "$PASS1" >/dev/null 2>&1
fi

clear
mv_header "$(trx '🔑 Contraseña Root')" "$(trx 'Credenciales de acceso actualizadas')" "v6.2"
echo ""
echo -e "   ${GREEN}✅ $(trx 'CONTRASEÑA CAMBIADA')${RESET}"
echo ""
echo -e "   ${WHITE}$(trx 'Usuario')${RESET}      : ${GREEN}root${RESET}"
echo -e "   ${WHITE}$(trx 'Contraseña')${RESET}   : ${GREEN}${PASS1}${RESET}"
echo -e "   ${WHITE}$(trx 'SSH Root')${RESET}     : ${GREEN}$(trx 'Habilitado')${RESET}"
if [[ -f "$BASE/protocolos/bot.sh" ]] && [[ -d /root/movivip_bots ]]; then
    echo -e "   ${WHITE}🤖 Bot${RESET}        : ${GREEN}$(trx 'Contraseña sincronizada')${RESET}"
fi
echo ""
mv_enter 2>/dev/null || read -n1 -r -p "$(trx 'Presiona una tecla para regresar...')"

exec bash "$BASE/herramientas/menu.sh"
