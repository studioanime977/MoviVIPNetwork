#!/bin/bash
# =============================================================================
# MoviVIP — FIX DE NGINX PARA LA MINI APP DE TELEGRAM
# =============================================================================
# Repara el problema de config duplicada en nginx que deja la mini app caida.
# Uso: bash fix-miniapp-nginx.sh
# =============================================================================
set -euo pipefail

CONF_DUP="/etc/nginx/conf.d/botweb.conf"
CONF_OK="/etc/nginx/sites-available/movivip-miniapp"

echo "== MoviVIP: Fix de nginx para la mini app =="

# 1) Si existe el duplicado en conf.d que choca con sites-enabled, respaldarlo
if [ -f "$CONF_DUP" ]; then
    echo ">> Detectada config duplicada: $CONF_DUP"
    mv "$CONF_DUP" "${CONF_DUP}.bak_dup"
    echo ">> Respaldada como ${CONF_DUP}.bak_dup"
fi

# 2) Asegurar que la config correcta este activa (symlink en sites-enabled)
if [ -f "$CONF_OK" ] && [ ! -L /etc/nginx/sites-enabled/movivip-miniapp ]; then
    echo ">> Activando symlink de la config correcta"
    ln -sf "$CONF_OK" /etc/nginx/sites-enabled/movivip-miniapp
fi

# 3) Detener procesos nginx heredados que ocupen el puerto 4432
echo ">> Deteniendo procesos nginx heredados (si los hay)"
systemctl stop nginx 2>/dev/null || true
sleep 1
if pgrep -x nginx >/dev/null; then
    pkill -9 nginx 2>/dev/null || true
    sleep 1
fi
echo ">> Procesos nginx: $(pgrep -c nginx 2>/dev/null || echo 0)"

# 4) Validar config
echo ">> Validando config: nginx -t"
if ! nginx -t; then
    echo "!! ERROR: la config de nginx no es valida. Revisar manualmente."
    exit 1
fi

# 5) Arrancar bajo systemd
echo ">> Arrancando nginx bajo systemd"
systemctl enable nginx >/dev/null 2>&1 || true
systemctl start nginx
sleep 2

if systemctl is-active --quiet nginx; then
    echo "✅ nginx activo (systemd): $(systemctl is-active nginx)"
else
    echo "❌ nginx NO arranco. Estado: $(systemctl is-active nginx)"
    exit 1
fi

# 6) Verificar mini app responde
echo ">> Verificando mini app (dominio -> 4432 -> 5081)"
CODE=$(curl -sk --resolve bot.movivipoppax.uk:443:127.0.0.1 \
    "https://bot.movivipoppax.uk/miniapp" -o /dev/null -w '%{http_code}' -m 10 2>/dev/null || echo "ERROR")
echo ">> Mini app /miniapp => HTTP $CODE"

echo ""
echo "== Fix completado =="
echo "   - Conf duplicada respaldada:  ${CONF_DUP}.bak_dup"
echo "   - Conf correcta activa:       $CONF_OK -> sites-enabled"
echo "   - nginx.service:              $(systemctl is-active nginx)"
