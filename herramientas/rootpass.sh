#!/bin/bash

# ── i18n shim (auto) ───────────────────────────────
if ! declare -F trx >/dev/null 2>&1; then trx() { printf '%s' "$1"; }; fi
# ─────────────────────────────────────────────────────────
BASE="/etc/movivip"

clear

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "$(trx '      CAMBIAR CONTRASEÑA ROOT')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Verificar que sea root
if [[ $EUID -ne 0 ]]; then
    echo "$(trx '❌ Debes ejecutar el script como usuario root.')"
    echo ""
    echo "Ejecuta:"
    echo "sudo -i"
    echo ""
    read -n1 -r -p "$(trx 'Presiona una tecla para regresar...')"
    exec bash "$BASE/protocolos/menu.sh"
fi

read -rsp "$(trx '🔑 Nueva contraseña: ')" PASS1
echo
read -rsp "$(trx '🔑 Confirmar contraseña: ')" PASS2
echo

if [[ "$PASS1" != "$PASS2" ]]; then
    echo ""
    echo "$(trx '❌ Las contraseñas no coinciden.')"
    sleep 2
    exec bash "$BASE/protocolos/menu.sh"
fi

HASH=$(openssl passwd -6 "$PASS1" 2>/dev/null)
usermod -p "$HASH" root || {
    echo ""
    echo "$(trx '❌ No se pudo cambiar la contraseña.')"
    sleep 2
    exec bash "$BASE/protocolos/menu.sh"
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
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "$(trx '   ✅ CONTRASEÑA CAMBIADA')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "$(trx 'Usuario      : root')"
echo "Contraseña   : $PASS1"
echo "$(trx 'SSH Root     : Habilitado')"
if [[ -f "$BASE/protocolos/bot.sh" ]] && [[ -d /root/movivip_bots ]]; then
    echo "$(trx '🤖 Bot        : Contraseña sincronizada')"
fi
echo ""
read -n1 -r -p "$(trx 'Presiona una tecla para regresar...')"

exec bash "$BASE/protocolos/menu.sh"
