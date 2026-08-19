#!/bin/bash
# MOVIVIP — INSTALADOR BOT GENERADOR DE LICENCIAS
# Ejecuta: bash setup-bot-generador.sh

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; WHITE='\033[1;37m'; NC='\033[0m'

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${WHITE}  MOVIVIP — INSTALADOR BOT GENERADOR DE LICENCIAS  ${CYAN}║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
echo ""

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[ERR] Ejecuta como root: sudo bash setup-bot-generador.sh${NC}"
    exit 1
fi

# DEPENDENCIAS
echo -e "${CYAN}  Verificando dependencias...${NC}"
for cmd in openssl curl python3; do
    if ! command -v $cmd &>/dev/null; then
        apt-get update -qq && apt-get install -y -qq $cmd >/dev/null 2>&1
    fi
    echo -e "${GREEN}  [OK] $cmd${NC}"
done

# ESTRUCTURA
echo ""
mkdir -p /etc/movivip/herramientas
mkdir -p /etc/movivip/secrets/encrypted
chmod 700 /etc/movivip/secrets

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# COPIAR ARCHIVOS
echo -e "${CYAN}  Copiando scripts...${NC}"
for f in bot-generador.sh descifrar-secrets.sh; do
    if [[ -f "$SCRIPT_DIR/$f" ]]; then
        cp "$SCRIPT_DIR/$f" /etc/movivip/herramientas/$f
        chmod +x /etc/movivip/herramientas/$f
        echo -e "${GREEN}  [OK] $f${NC}"
    fi
done
cp "$SCRIPT_DIR/descifrar-secrets.sh" /etc/movivip/descifrar-secrets.sh 2>/dev/null
chmod +x /etc/movivip/descifrar-secrets.sh 2>/dev/null

if [[ -f "$SCRIPT_DIR/movivip-bot-generador.service" ]]; then
    cp "$SCRIPT_DIR/movivip-bot-generador.service" /etc/systemd/system/
    echo -e "${GREEN}  [OK] servicio systemd${NC}"
fi

# BOT TOKEN
echo ""
echo -e "${CYAN}  Token del bot de Telegram (@BotFather):${NC}"
read -rp "  > " BOT_TOKEN
BOT_TOKEN="${BOT_TOKEN:-TU_TOKEN_AQUI}"

# MASTER KEY
echo ""
echo -e "${CYAN}  Master Key (para encriptar/desencriptar secrets):${NC}"
echo -e "  ${RED}  GUARDALA — no se puede recuperar${NC}"
read -s -rp "  > " MASTER_KEY
echo ""
if [[ -n "$MASTER_KEY" ]]; then
    echo -n "$MASTER_KEY" > /etc/movivip/.master-key
    chmod 600 /etc/movivip/.master-key
    echo -e "${GREEN}  [OK] Master key instalada${NC}"
fi

# CONFIGURAR SERVICIO
echo ""
if [[ -f /etc/systemd/system/movivip-bot-generador.service ]]; then
    sed -i "s|Environment=MOVIVIP_BOT_TOKEN=.*|Environment=MOVIVIP_BOT_TOKEN=$BOT_TOKEN|" \
        /etc/systemd/system/movivip-bot-generador.service
    systemctl daemon-reload
    systemctl enable movivip-bot-generador >/dev/null 2>&1
    echo -e "${GREEN}  [OK] Servicio configurado y habilitado${NC}"
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  INSTALACION COMPLETADA                            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  SIGUIENTE PASO:"
echo -e "  1. En tu PC, ejecuta: ${CYAN}encriptar-secrets.ps1${NC}"
echo -e "  2. Sube los .enc al VPS:"
echo -e "     ${CYAN}scp *.enc root@VPS:/etc/movivip/secrets/encrypted/${NC}"
echo -e "  3. Inicia el bot:"
echo -e "     ${CYAN}systemctl start movivip-bot-generador${NC}"
echo ""
