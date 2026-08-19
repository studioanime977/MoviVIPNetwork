#!/bin/bash

BASE="/etc/movivip"

clear

echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
echo "      CAMBIAR CONTRASEÃ‘A ROOT"
echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
echo ""

# Verificar que sea root
if [[ $EUID -ne 0 ]]; then
    echo "âŒ Debes ejecutar el script como usuario root."
    echo ""
    echo "Ejecuta:"
    echo "sudo -i"
    echo ""
    read -n1 -r -p "Presiona una tecla para regresar..."
    exec bash "$BASE/protocolos/menu.sh"
fi

read -rsp "ðŸ”‘ Nueva contraseÃ±a: " PASS1
echo
read -rsp "ðŸ”‘ Confirmar contraseÃ±a: " PASS2
echo

if [[ "$PASS1" != "$PASS2" ]]; then
    echo ""
    echo "âŒ Las contraseÃ±as no coinciden."
    sleep 2
    exec bash "$BASE/protocolos/menu.sh"
fi

HASH=$(openssl passwd -6 "$PASS1" 2>/dev/null)
usermod -p "$HASH" root || {
    echo ""
    echo "âŒ No se pudo cambiar la contraseÃ±a."
    sleep 2
    exec bash "$BASE/protocolos/menu.sh"
}

# Habilitar acceso root por SSH
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
grep -q "^PermitRootLogin" /etc/ssh/sshd_config || \
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config

# Habilitar autenticaciÃ³n por contraseÃ±a
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
# SINCRONIZAR CONTRASEÃ‘A CON EL BOT (si estÃ¡ instalado)
# El bot usa VPS_PASSWORD para conectarse al VPS; al cambiar la
# contraseÃ±a root, la misma nueva contraseÃ±a debe surtir efecto
# en el bot. bot.sh --sync-pass reescribe config.py y reinicia.
# ============================================================
if [[ -f "$BASE/protocolos/bot.sh" ]]; then
    bash "$BASE/protocolos/bot.sh" --sync-pass "$PASS1" >/dev/null 2>&1
fi

clear
echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
echo "   âœ… CONTRASEÃ‘A CAMBIADA"
echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
echo ""
echo "Usuario      : root"
echo "ContraseÃ±a   : $PASS1"
echo "SSH Root     : Habilitado"
if [[ -f "$BASE/protocolos/bot.sh" ]] && [[ -d /root/movivip_bots ]]; then
    echo "ðŸ¤– Bot        : ContraseÃ±a sincronizada"
fi
echo ""
read -n1 -r -p "Presiona una tecla para regresar..."

exec bash "$BASE/protocolos/menu.sh"
