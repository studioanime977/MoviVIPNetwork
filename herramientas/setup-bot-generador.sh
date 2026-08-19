#!/bin/bash
# MOVIVIP — INSTALADOR BOT GENERADOR DE LICENCIAS
# Ejecuta: bash setup-bot-generador.sh
#
# FLUJO:
#   1. Pide token del bot (@MovivipKeygen_bot)
#   2. Pide Super Admin Key (la que te dio el sistema)
#   3. Pide credenciales Firebase
#   4. Registra la super key en Firebase automaticamente
#   5. Instala y habilita el servicio

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; WHITE='\033[1;37m'; GRAY='\033[0;90m'; NC='\033[0m'

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${WHITE}   MOVIVIP — INSTALADOR BOT GENERADOR DE LICENCIAS v3.0  ${CYAN}║${NC}"
echo -e "${CYAN}║${GRAY}   @MovivipKeygen_bot — Firebase RTDB                    ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[ERR] Ejecuta como root: sudo bash setup-bot-generador.sh${NC}"
    exit 1
fi

# ================= DEPENDENCIAS =================
echo -e "${CYAN}  [1/6] Verificando dependencias...${NC}"
for cmd in openssl curl python3; do
    if ! command -v $cmd &>/dev/null; then
        apt-get update -qq && apt-get install -y -qq $cmd >/dev/null 2>&1
    fi
    echo -e "    ${GREEN}✔ $cmd${NC}"
done

# ================= ESTRUCTURA =================
echo ""
echo -e "${CYAN}  [2/6] Creando estructura...${NC}"
mkdir -p /etc/movivip/herramientas
mkdir -p /etc/movivip/secrets/encrypted
chmod 700 /etc/movivip/secrets

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ================= COPIAR ARCHIVOS =================
echo -e "${CYAN}  [3/6] Copiando scripts...${NC}"
for f in bot-generador.sh descifrar-secrets.sh; do
    if [[ -f "$SCRIPT_DIR/$f" ]]; then
        cp "$SCRIPT_DIR/$f" /etc/movivip/herramientas/$f
        chmod +x /etc/movivip/herramientas/$f
        echo -e "    ${GREEN}✔ $f${NC}"
    fi
done
cp "$SCRIPT_DIR/descifrar-secrets.sh" /etc/movivip/descifrar-secrets.sh 2>/dev/null
chmod +x /etc/movivip/descifrar-secrets.sh 2>/dev/null

if [[ -f "$SCRIPT_DIR/movivip-bot-generador.service" ]]; then
    cp "$SCRIPT_DIR/movivip-bot-generador.service" /etc/systemd/system/
    echo -e "    ${GREEN}✔ servicio systemd${NC}"
fi

# ================= BOT TOKEN =================
echo ""
echo -e "${CYAN}  [4/6] Token del bot de Telegram:${NC}"
echo -e "  ${GRAY}  Bot: @MovivipKeygen_bot${NC}"
echo -e "  ${GRAY}  Obtelo de @BotFather en Telegram${NC}"
read -rp "  Token: " BOT_TOKEN
if [[ -z "$BOT_TOKEN" ]]; then
    echo -e "${RED}  [ERR] Debes ingresar el token del bot${NC}"
    exit 1
fi

# ================= SUPER ADMIN KEY =================
echo ""
echo -e "${CYAN}  [5/6] Super Admin Key:${NC}"
echo -e "  ${RED}  ⚠ Esta key te da control TOTAL del sistema de licencias${NC}"
echo -e "  ${RED}  ⚠ Con esta key puedes crear proveedores y generar keys${NC}"
echo -e "  ${GRAY}  Ejemplo: KEY-180DCF2829${NC}"
read -rp "  Key: " SUPER_ADMIN_KEY
if [[ -z "$SUPER_ADMIN_KEY" ]]; then
    echo -e "${RED}  [ERR] Debes ingresar una Super Admin Key${NC}"
    exit 1
fi

# Guardar la key del super admin
echo -n "$SUPER_ADMIN_KEY" > /etc/movivip/.master-key
chmod 600 /etc/movivip/.master-key
echo -e "  ${GREEN}✔ Super Admin Key: ${SUPER_ADMIN_KEY:0:14}...${NC}"

# ================= CREDENCIALES FIREBASE =================
echo ""
echo -e "${CYAN}  Credenciales Firebase:${NC}"
echo -e "  ${GRAY}  (Para Firebase Realtime Database)${NC}"

read -rp "  Firebase API Key: " FB_API_KEY
read -rp "  Firebase Auth Email: " FB_AUTH_EMAIL
read -s -rp "  Firebase Auth Password: " FB_AUTH_PASS
echo ""

# Guardar en archivo de secrets
cat > /etc/movivip/.env-bot << ENVEOF
MOVIVIP_BOT_TOKEN=$BOT_TOKEN
FB_API_KEY=$FB_API_KEY
FB_AUTH_EMAIL=$FB_AUTH_EMAIL
FB_AUTH_PASS=$FB_AUTH_PASS
ENVEOF
chmod 600 /etc/movivip/.env-bot
echo -e "  ${GREEN}✔ Credenciales guardadas en /etc/movivip/.env-bot${NC}"

# ================= REGISTRAR SUPER KEY EN FIREBASE =================
echo ""
echo -e "${CYAN}  Registrando Super Admin Key en Firebase...${NC}"

FB_BASE="movivip-network-default-rtdb.firebaseio.com"

# Obtener token de Firebase
AUTH_URL="https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$FB_API_KEY"
AUTH_RESP=$(curl -s --max-time 15 -X POST "$AUTH_URL" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$FB_AUTH_EMAIL\",\"password\":\"$FB_AUTH_PASS\",\"returnSecureToken\":true}" 2>/dev/null)

FB_TOKEN=$(echo "$AUTH_RESP" | grep -oP '"idToken"\s*:\s*"([^"]*)"' | sed 's/.*"\(.*\)"/\1/')

if [[ -n "$FB_TOKEN" ]]; then
    AHORA=$(date +%s)
    SUPER_BODY="{\"activa\":true,\"tipo\":\"super\",\"plan\":\"super\",\"creada\":$AHORA,\"expira\":0,\"ilimitada\":true,\"creada_por\":\"sistema\"}"
    
    curl -s --max-time 20 -X PUT \
        "https://${FB_BASE}/maestros/${SUPER_ADMIN_KEY}.json?auth=$FB_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$SUPER_BODY" >/dev/null 2>&1
    
    if [[ $? -eq 0 ]]; then
        echo -e "  ${GREEN}✔ Super Admin Key registrada en Firebase (maestros/)${NC}"
    else
        echo -e "  ${YELLOW}⚠ No se pudo registrar en Firebase — hazlo manualmente${NC}"
    fi
    
    # También registrar en licencias_movivip para compatibilidad
    curl -s --max-time 20 -X PUT \
        "https://${FB_BASE}/licencias_movivip/${SUPER_ADMIN_KEY}.json?auth=$FB_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$SUPER_BODY" >/dev/null 2>&1
else
    echo -e "  ${YELLOW}⚠ No se pudo autenticar en Firebase — registra la key manualmente${NC}"
fi

# ================= CONFIGURAR SERVICIO =================
echo ""
echo -e "${CYAN}  [6/6] Configurando servicio...${NC}"
if [[ -f /etc/systemd/system/movivip-bot-generador.service ]]; then
    # Actualizar token en el servicio
    sed -i "s|Environment=MOVIVIP_BOT_TOKEN=.*|Environment=MOVIVIP_BOT_TOKEN=$BOT_TOKEN|" \
        /etc/systemd/system/movivip-bot-generador.service
    
    systemctl daemon-reload
    systemctl enable movivip-bot-generador >/dev/null 2>&1
    echo -e "  ${GREEN}✔ Servicio configurado y habilitado${NC}"
fi

# ================= RESUMEN =================
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ INSTALACION COMPLETADA                              ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${WHITE}Bot:${NC}       @MovivipKeygen_bot"
echo -e "  ${WHITE}Super Key:${NC} ${SUPER_ADMIN_KEY:0:14}..."
echo -e "  ${WHITE}Firebase:${NC}  $FB_BASE"
echo ""
echo -e "  ${CYAN}Comandos:${NC}"
echo -e "    systemctl start movivip-bot-generador   ${GRAY}# Iniciar${NC}"
echo -e "    systemctl stop movivip-bot-generador    ${GRAY}# Detener${NC}"
echo -e "    journalctl -u movivip-bot-generador -f  ${GRAY}# Ver logs${NC}"
echo ""
echo -e "  ${CYAN}En Telegram:${NC}"
echo -e "    /auth $SUPER_ADMIN_KEY  ${GRAY}# Autenticarte como super admin${NC}"
echo -e "    /crear_proveedor       ${GRAY}# Crear key de proveedor${NC}"
echo -e "    /generar               ${GRAY}# Generar key de cliente${NC}"
echo ""
