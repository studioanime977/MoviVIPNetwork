#!/bin/bash

echo "📥 Actualizando MoviVIP Network..."

TMP="/tmp/MoviVIP_update"

rm -rf "$TMP"

git clone https://github.com/kevinaldaircama/multi-script.git "$TMP" || {
    echo "❌ Error al descargar la actualización."
    exit 1
}

cp -rf "$TMP"/. /etc/movivip/

chmod -R +x /etc/movivip

rm -rf "$TMP"

echo "✅ Actualización completada."

exec /etc/movivip/menu.sh
