#!/bin/bash
# MOVIVIP — INSTALADOR BOT GENERADOR DE LICENCIAS
# Solo pide: token del bot + ID de Telegram admin
# Firebase ya está configurado en /etc/movivip/.env-bot

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; WHITE='\033[1;37m'; GRAY='\033[0;90m'; NC='\033[0m'

SVC_NAME="movivip-bot-generador"
BOT_DIR="/etc/movivip/herramientas"
BOT_SCRIPT="$BOT_DIR/bot-generador.sh"
SVC_FILE="/etc/systemd/system/${SVC_NAME}.service"
ENV_FILE="/etc/movivip/.env-bot"

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${WHITE}   MOVIVIP — BOT GENERADOR DE LICENCIAS v3.1             ${CYAN}║${NC}"
echo -e "${CYAN}║${GRAY}   @MovivipKeygen_bot — Firebase RTDB                    ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}  [ERR] Ejecuta como root${NC}"
    exit 1
fi

# ================= YA INSTALADO? =================
if [[ -f "$SVC_FILE" ]]; then
    echo -e "${YELLOW}  ⚠️  Bot generador ya está instalado.${NC}"
    echo ""
    if systemctl is-active --quiet "$SVC_NAME" 2>/dev/null; then
        echo -e "  Estado: ${GREEN}🟢 ACTIVO${NC}"
    else
        echo -e "  Estado: ${RED}🔴 INACTIVO${NC}"
    fi
    echo ""
    echo -e "    ${CYAN}[1]${WHITE} 🔄 Reiniciar${NC}"
    echo -e "    ${CYAN}[2]${WHITE} 🔁 Cambiar token / ID${NC}"
    echo -e "    ${CYAN}[3]${WHITE} 🗑️  Desinstalar${NC}"
    echo -e "    ${CYAN}[0]${WHITE} ↩ Volver${NC}"
    echo ""
    read -rp "  Opción: " CHOICE
    case "$CHOICE" in
        1)
            systemctl restart "$SVC_NAME" 2>/dev/null
            sleep 2
            if systemctl is-active --quiet "$SVC_NAME"; then
                echo -e "${GREEN}  ✔ Bot reiniciado y activo${NC}"
            else
                echo -e "${RED}  ✖ Bot no arrancó. Logs: journalctl -u $SVC_NAME -n 20${NC}"
            fi
            read -rp "Presiona Enter para continuar..."
            exit 0
            ;;
        2)
            # Seguir abajo para pedir token + ID nuevos
            ;;
        3)
            systemctl stop "$SVC_NAME" 2>/dev/null
            systemctl disable "$SVC_NAME" 2>/dev/null
            rm -f "$SVC_FILE"
            systemctl daemon-reload
            echo -e "${GREEN}  ✔ Bot desinstalado${NC}"
            read -rp "Presiona Enter para continuar..."
            exit 0
            ;;
        *)
            exit 0
            ;;
    esac
fi

# ================= PEDIR TOKEN + ID =================
echo -e "${CYAN}  Token del bot (@MovivipKeygen_bot):${NC}"
echo -e "  ${GRAY}  @BotFather → /mybots → API Token${NC}"
read -rp "  Token: " BOT_TOKEN
if [[ -z "$BOT_TOKEN" ]]; then
    echo -e "${RED}  Cancelado.${NC}"
    exit 1
fi

# Validar formato
if ! [[ "$BOT_TOKEN" =~ ^[0-9]+:.+$ ]]; then
    echo -e "${RED}  Token inválido. Formato: 123456789:ABCdefGHI...${NC}"
    exit 1
fi

echo ""
echo -e "${CYAN}  Tu ID de Telegram (admin):${NC}"
echo -e "  ${GRAY}  @userinfobot → /start → copia tu ID${NC}"
read -rp "  ID: " ADMIN_TG_ID
if [[ -z "$ADMIN_TG_ID" ]] || ! [[ "$ADMIN_TG_ID" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}  ID inválido (debe ser numérico).${NC}"
    exit 1
fi

# ================= VERIFICAR TOKEN =================
echo ""
echo -e "${CYAN}  Verificando token con Telegram...${NC}"
RESP=$(curl -s --max-time 10 "https://api.telegram.org/bot${BOT_TOKEN}/getMe" 2>/dev/null)
if echo "$RESP" | grep -q '"ok":true'; then
    BOT_NAME=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['result'].get('username','?'))" 2>/dev/null)
    echo -e "  ${GREEN}✔ Bot: @$BOT_NAME${NC}"
else
    echo -e "${RED}  ✖ Token no responde. Verifica que sea correcto.${NC}"
    exit 1
fi

# ================= ARCHIVOS =================
echo ""
echo -e "${CYAN}  Configurando...${NC}"

mkdir -p "$BOT_DIR" /etc/movivip/secrets/encrypted
chmod 700 /etc/movivip/secrets

# Copiar bot-generador.sh si existe en el mismo directorio
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -f "$SCRIPT_DIR/bot-generador.sh" && "$SCRIPT_DIR" != "$BOT_DIR" ]]; then
    cp "$SCRIPT_DIR/bot-generador.sh" "$BOT_SCRIPT"
    chmod +x "$BOT_SCRIPT"
fi
chmod +x "$BOT_SCRIPT" 2>/dev/null

# Copiar servicio systemd a /etc/systemd/system/
if [[ -f "$SCRIPT_DIR/movivip-bot-generador.service" ]]; then
    cp "$SCRIPT_DIR/movivip-bot-generador.service" "/etc/systemd/system/${SVC_NAME}.service"
    echo -e "  ${GREEN}✔ Servicio systemd instalado${NC}"
elif [[ -f "$SVC_FILE" ]]; then
    echo -e "  ${YELLOW}⚠ Servicio ya existe en systemd${NC}"
else
    echo -e "  ${RED}⚠ No se encontró archivo .service${NC}"
fi

# ================= GUARDAR TOKEN + ID + FIREBASE =================
# Firebase credentials (movivip-network-default-rtdb)
FB_API_KEY="AIzaSyDx7py9fl660hgMdRr_4utQ5fQqJcsGal8"
FB_AUTH_EMAIL="ventas@movivip.com"
FB_AUTH_PASS="MovivipVentas2026!"

# Guardar .env-bot completo (token + Firebase)
cat > "$ENV_FILE" << ENVEOF
MOVIVIP_BOT_TOKEN=$BOT_TOKEN
FB_API_KEY=$FB_API_KEY
FB_AUTH_EMAIL=$FB_AUTH_EMAIL
FB_AUTH_PASS=$FB_AUTH_PASS
ENVEOF
chmod 600 "$ENV_FILE"
echo -e "  ${GREEN}✔ Credenciales guardadas en $ENV_FILE${NC}"

# Guardar ID admin
echo "$ADMIN_TG_ID" > /etc/movivip/.admin-tg-id
chmod 600 /etc/movivip/.admin-tg-id
echo -e "  ${GREEN}✔ Admin Telegram ID: $ADMIN_TG_ID${NC}"

# ================= SERVICIO =================
echo ""
echo -e "${CYAN}  Activando servicio...${NC}"

if [[ -f "$SVC_FILE" ]]; then
    # Actualizar token en service file
    if grep -q "Environment=MOVIVIP_BOT_TOKEN=" "$SVC_FILE"; then
        sed -i "s|Environment=MOVIVIP_BOT_TOKEN=.*|Environment=MOVIVIP_BOT_TOKEN=$BOT_TOKEN|" "$SVC_FILE"
    fi
    systemctl daemon-reload
    systemctl enable "$SVC_NAME" >/dev/null 2>&1
    systemctl restart "$SVC_NAME" 2>/dev/null
    sleep 3
    if systemctl is-active --quiet "$SVC_NAME"; then
        echo -e "  ${GREEN}✔ Bot activo y corriendo${NC}"
    else
        echo -e "  ${YELLOW}⚠ Servicio creado pero no arrancó. Logs: journalctl -u $SVC_NAME -n 20${NC}"
    fi
else
    echo -e "  ${YELLOW}⚠ No se encontró archivo .service. Crea el servicio manualmente.${NC}"
fi

# ================= RESUMEN =================
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ BOT GENERADOR CONFIGURADO                           ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${WHITE}Bot:${NC}     @$BOT_NAME"
echo -e "  ${WHITE}Admin:${NC}   ID $ADMIN_TG_ID"
echo -e "  ${WHITE}Token:${NC}   ${BOT_TOKEN:0:10}...${BOT_TOKEN: -5}"
echo ""
echo -e "  ${CYAN}En Telegram:${NC}"
echo -e "    /start        ${GRAY}# Ver menú${NC}"
echo -e "    /generar      ${GRAY}# Generar key${NC}"
echo -e "    /ver_keys     ${GRAY}# Ver keys${NC}"
echo ""
