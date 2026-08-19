#!/bin/bash

BASE="/etc/movivip"

clear

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "      CAMBIAR CONTRASEÑA ROOT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Verificar que sea root
if [[ $EUID -ne 0 ]]; then
    echo "❌ Debes ejecutar el script como usuario root."
    echo ""
    echo "Ejecuta:"
    echo "sudo -i"
    echo ""
    read -n1 -r -p "Presiona una tecla para regresar..."
    exec bash "$BASE/protocolos/menu.sh"
fi

read -rsp "🔑 Nueva contraseña: " PASS1
echo
read -rsp "🔑 Confirmar contraseña: " PASS2
echo

if [[ "$PASS1" != "$PASS2" ]]; then
    echo ""
    echo "❌ Las contraseñas no coinciden."
    sleep 2
    exec bash "$BASE/protocolos/menu.sh"
fi

HASH=$(openssl passwd -6 "$PASS1" 2>/dev/null)
usermod -p "$HASH" root || {
    echo ""
    echo "❌ No se pudo cambiar la contraseña."
    sleep 2
    exec bash "$BASE/protocolos/menu.sh"
}

# Habilitar acceso root por SSH
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
grep -q "^PermitRootLogin" /etc/ssh/sshd_config || \
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config

# Habilitar autenticación por contraseña
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
grep -q "^PasswordAuthentication" /etc/ssh/sshd_config || \
echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config

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
echo "   ✅ CONTRASEÑA CAMBIADA"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Usuario      : root"
echo "Contraseña   : $PASS1"
echo "SSH Root     : Habilitado"
if [[ -f "$BASE/protocolos/bot.sh" ]] && [[ -d /root/movivip_bots ]]; then
    echo "🤖 Bot        : Contraseña sincronizada"
fi
echo ""
read -n1 -r -p "Presiona una tecla para regresar..."

exec bash "$BASE/protocolos/menu.sh"
