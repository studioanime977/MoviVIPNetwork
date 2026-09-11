#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# MoviVIP Network — INSTALADOR BOOTSTRAP (rama main)
# ═══════════════════════════════════════════════════════════════
# Este script SIEMPRE descarga la ÚLTIMA release publicada.
# Corrige el problema de VPS que obtenían versiones viejas:
#   - raw.githubusercontent.com/main/install.sh  (antes: 404)
#   - movivip-network.web.app/install.sh         (antes: HTML, no script)
# Uso:
#   bash <(curl -fsSL https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/install.sh)
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; RESET='\033[0m'
REL_URL="https://github.com/studioanime977/MoviVIPNetwork/releases/latest/download"
TMP="/tmp/movivip-bootstrap-install.sh"

echo -e "${GREEN}┌──────────────────────────────────────────────┐${RESET}"
echo -e "${GREEN}│  MoviVIP Network — Instalador (bootstrap)      │${RESET}"
echo -e "${GREEN}└──────────────────────────────────────────────┘${RESET}"
echo -e "${YELLOW}⬇ Descargando la última release oficial...${RESET}"

if ! curl -fL --max-time 180 --retry 3 -o "$TMP" "$REL_URL/install.sh" 2>/dev/null; then
    echo -e "${RED}❌ Error descargando el instalador desde:${RESET}"
    echo -e "${RED}   $REL_URL/install.sh${RESET}"
    echo -e "${YELLOW}Verifica tu conexión a GitHub.${RESET}"
    exit 1
fi

# Verificar tamaño mínimo (el instalador real supera 1MB por el payload ofuscado)
SIZE=$(wc -c < "$TMP" 2>/dev/null || echo 0)
if (( SIZE < 1000000 )); then
    echo -e "${RED}❌ Instalador sospechosamente pequeño (${SIZE} B). Abortando.${RESET}"
    rm -f "$TMP"
    exit 1
fi

chmod +x "$TMP"
echo -e "${GREEN}✔ Instalador descargado correctamente (${SIZE} B).${RESET}"
echo -e "${GREEN}▶ Ejecutando instalación...${RESET}"
echo ""
exec bash "$TMP" "$@"