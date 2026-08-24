#!/bin/bash
# =============================================================================
#  MOVIVIP NETWORK — BOT DE ADMINISTRACIÓN (instalador/activador por plan)
#  ---------------------------------------------------------------------------
#  Este script vive en /etc/movivip/protocolos/bot.sh y se ejecuta desde:
#    - El menú principal  -> opción [10] 🤖 Bot de administración
#    - install-con-licencia.sh  -> tras validar la key según el plan
#
#  QUÉ HACE (según el plan de la licencia en /etc/movivip/licencia.conf):
#    BRONCE    -> avisa que el bot es EXCLUSIVO de planes PREMIUM+
#    PREMIUM+  -> descarga el bot desde GitHub según el plan del cliente,
#                 lo instala en /root/movivip_bots/<cliente>/, crea el
#                 servicio systemd movivip-<cliente>-admin y lo ACTIVA.
#
#  El paquete del bot por cliente se publica en el repo de entregas:
#    https://github.com/studioanime977/movivip-bots/raw/main/<cliente>/
#  (el generador generar-bot-cliente.ps1 produce ese paquete)
#
#  USO:
#    bash bot.sh                 -> menú interactivo (desde el panel)
#    bash bot.sh --install       -> modo automático (desde install-con-licencia)
#    bash bot.sh --status        -> estado del servicio
#    bash bot.sh --sync-pass     -> reescribe VPS_PASSWORD en config.py del bot
# =============================================================================

BASE="/etc/movivip"
CONFIG="$BASE/config.conf"
LICENCIA="$BASE/licencia.conf"

# Cargar funciones multi-distro
[[ -f "$BASE/functions/pkg.sh" ]] && source "$BASE/functions/pkg.sh"

# Cargar idioma
if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)"
fi

# Paquete del bot: se descarga desde el repo principal MoviVIPNetwork
BOT_REPO_RAW="https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/protocolos/bots_extract"
BOT_ROOT="/root/movivip_bots"

RESET="\e[0m"; RED="\e[1;91m"; GREEN="\e[1;92m"; GOLD="\e[1;93m"
BLUE="\e[1;94m"; MAGENTA="\e[1;95m"; CYAN="\e[1;96m"; WHITE="\e[1;97m"; GRAY="\e[1;90m"

# =============================================================================
# LEER LICENCIA (plan + cliente)
# =============================================================================
PLAN=""
CLIENTE=""
if [[ -f "$LICENCIA" ]]; then
    source "$LICENCIA"
    PLAN="${PLAN:-}"
    CLIENTE="${CLIENTE:-}"
fi
PLAN_LO=$(echo "${PLAN,,}" | tr -d ' ')
# Nombre de carpeta/servicio del bot SIEMPRE en minúsculas (lo genera el
# generador: vps-video-vitalicia, netfast, etc.). El CLIENTE de licencia.conf
# puede llevar mayúsculas ("VPS-Video-Vitalicia") -> normalizamos aquí.
CLIENTE_LO=$(echo "${CLIENTE,,}" | tr 'A-Z' 'a-z' | tr -d ' ')

# =============================================================================
# HELPERS
# =============================================================================
H1() { printf "${CYAN}╔"; printf '═%.0s' $(seq 1 60); printf "╗${RESET}\n"; }
H2() { printf "${CYAN}╠"; printf '═%.0s' $(seq 1 60); printf "╣${RESET}\n"; }
H3() { printf "${CYAN}╚"; printf '═%.0s' $(seq 1 60); printf "╝${RESET}\n"; }

bot_dir() {
    # Buscar primero la carpeta del CLIENTE normalizada (minúsculas)
    if [[ -n "$CLIENTE_LO" && -d "$BOT_ROOT/$CLIENTE_LO" ]]; then
        echo "$BOT_ROOT/$CLIENTE_LO"
    elif [[ -n "$CLIENTE" && -d "$BOT_ROOT/$CLIENTE" ]]; then
        echo "$BOT_ROOT/$CLIENTE"
    elif [[ -d "$BOT_ROOT" ]]; then
        find "$BOT_ROOT" -maxdepth 1 -type d -name '*' 2>/dev/null | grep -v "^$BOT_ROOT$" | head -n1
    fi
}

bot_service() {
    local d; d=$(bot_dir)
    [[ -z "$d" ]] && return 1
    local c; c=$(basename "$d")
    echo "movivip-${c}-admin"
}

plan_tiene_bot() {
    case "$PLAN_LO" in
        super|mayorista|premium|platino|vitalicio) return 0 ;;
        *) return 1 ;;
    esac
}

# =============================================================================
# INSTALAR EL BOT DESDE GITHUB (según plan + cliente)
# =============================================================================
instalar_bot() {
    [[ -z "$CLIENTE" ]] && CLIENTE="cliente"
    [[ -z "$CLIENTE_LO" ]] && CLIENTE_LO="cliente"

    # Super admin y mayorista usan el bot-generador que ya viene con el sistema
    if [[ "$PLAN_LO" == "super" || "$PLAN_LO" == "mayorista" ]]; then
        echo -e "${CYAN}  📦 Configurando bot generador para: ${WHITE}$CLIENTE${RESET} (plan ${GOLD}${PLAN}${RESET})"
        echo ""

        local BOT_SRC="/etc/movivip/herramientas/bot-generador.sh"
        local BOT_SVC="/etc/movivip/herramientas/movivip-bot-generador.service"
        local DEST="$BOT_ROOT/$CLIENTE_LO"

        if [[ ! -f "$BOT_SRC" ]]; then
            echo -e "${RED}  ❌ No se encontró bot-generador.sh en $BOT_SRC${RESET}"
            return 1
        fi

        mkdir -p "$DEST"
        cp "$BOT_SRC" "$DEST/bot-generador.sh"
        chmod +x "$DEST/bot-generador.sh"

        # Pedir ID de Telegram del administrador
        local ADMIN_TG_ID=""
        echo -e "${CYAN}  ID de Telegram del administrador:${NC}"
        echo -e "${GRAY}  (Para saber tu ID: escribe /start a @userinfobot en Telegram)${NC}"
        if [[ -t 0 ]]; then
            read -rp "$(echo -e "  Tu ID de Telegram: ")" ADMIN_TG_ID
        fi
        if [[ -z "$ADMIN_TG_ID" ]] || ! [[ "$ADMIN_TG_ID" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}  ❌ Debes ingresar un ID numérico válido${RESET}"
            return 1
        fi
        echo -e "  ${GREEN}✔ Admin ID: ${ADMIN_TG_ID}${NC}"

        # Guardar ID en la super key de Firebase
        local MASTER_KEY=$(cat /etc/movivip/.master-key 2>/dev/null)
        if [[ -n "$MASTER_KEY" ]]; then
            echo -n "$ADMIN_TG_ID" > "$DEST/.admin-id"
        fi

        # Copiar servicio si existe
        if [[ -f "$BOT_SVC" ]]; then
            cp "$BOT_SVC" "/etc/systemd/system/movivip-bot-generador.service" 2>/dev/null
        fi

        # Configurar localmente (token, Firebase creds)
        configurar_bot_local "$DEST"

        echo -e "${GREEN}  ✅ Bot generador configurado en $DEST${RESET}"
        echo -e "${GOLD}  🚀 Ahora se crea el servicio...${RESET}"
        echo ""
        return 0
    fi

    # ── CLIENTES: pedir token de SU bot (cada cliente crea su propio bot en BotFather) ──
    local DEST="$BOT_ROOT/$CLIENTE_LO"
    local RAW="$BOT_REPO_RAW"

    echo -e "${CYAN}  📦 Instalando bot para: ${WHITE}$CLIENTE${RESET} (plan ${GOLD}${PLAN}${RESET})"
    echo ""
    echo -e "${YELLOW}  ⚠ Cada cliente debe crear 2 bots en @BotFather${NC}"
    echo -e "${GRAY}  Bot 1: Admin (crea usuarios SSH, gestiona el VPS)${NC}"
    echo -e "${GRAY}  Bot 2: Notificaciones (envía alertas a los clientes)${NC}"
    echo ""

    # Pedir token del bot ADMIN
    local ADMIN_TOKEN=""
    echo -e "${CYAN}  Bot ADMIN (crea usuarios SSH):${NC}"
    echo -e "${GRAY}  @BotFather → /newbot → nombra: 'MiBotAdmin'${NC}"
    if [[ -t 0 ]]; then
        read -rp "$(echo -e "  Token del bot ADMIN: ")" ADMIN_TOKEN
    fi
    if [[ -z "$ADMIN_TOKEN" ]]; then
        echo -e "${RED}  ❌ Debes ingresar el token del bot admin${RESET}"
        return 1
    fi

    # Pedir token del bot NOTIFICACIONES
    local NOTIF_TOKEN=""
    echo ""
    echo -e "${CYAN}  Bot NOTIFICACIONES (envía alertas):${NC}"
    echo -e "${GRAY}  @BotFather → /newbot → nombra: 'MiBotNotif'${NC}"
    if [[ -t 0 ]]; then
        read -rp "$(echo -e "  Token del bot NOTIF: ")" NOTIF_TOKEN
    fi
    if [[ -z "$NOTIF_TOKEN" ]]; then
        echo -e "${RED}  ❌ Debes ingresar el token del bot de notificaciones${RESET}"
        return 1
    fi

    # Pedir ID de Telegram del administrador
    local ADMIN_TG_ID=""
    echo ""
    echo -e "${CYAN}  ID de Telegram del administrador:${NC}"
    echo -e "${GRAY}  (Para saber tu ID: escribe /start a @userinfobot en Telegram)${NC}"
    if [[ -t 0 ]]; then
        read -rp "$(echo -e "  Tu ID de Telegram: ")" ADMIN_TG_ID
    fi
    if [[ -z "$ADMIN_TG_ID" ]] || ! [[ "$ADMIN_TG_ID" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}  ❌ Debes ingresar un ID numérico válido${RESET}"
        return 1
    fi
    echo -e "  ${GREEN}✔ Admin ID: ${ADMIN_TG_ID}${NC}"

    # Pedir credenciales Firebase del cliente (o usar las del sistema)
    echo ""
    echo -e "${GRAY}  Credenciales Firebase (deja vacío para usar las del sistema):${NC}"
    local C_FB_KEY="${FB_API_KEY:-}"
    local C_FB_EMAIL="${FB_AUTH_EMAIL:-}"
    local C_FB_PASS="${FB_AUTH_PASS:-}"
    read -rp "  API Key [$C_FB_KEY]: " INPUT_FB_KEY
    read -rp "  Email [$C_FB_EMAIL]: " INPUT_FB_EMAIL
    read -s -rp "  Password (oculto): " INPUT_FB_PASS
    echo ""
    [[ -n "$INPUT_FB_KEY" ]] && C_FB_KEY="$INPUT_FB_KEY"
    [[ -n "$INPUT_FB_EMAIL" ]] && C_FB_EMAIL="$INPUT_FB_EMAIL"
    [[ -n "$INPUT_FB_PASS" ]] && C_FB_PASS="$INPUT_FB_PASS"

    echo -e "${CYAN}  📥 Descargando paquete del bot desde MoviVIPNetwork...${NC}"

    # Verificar que el repo sea accesible (usamos config.py como prueba)
    if ! curl -fsSL --max-time 20 "$RAW/config.py" -o /dev/null 2>/dev/null; then
        echo -e "${RED}  ❌ No se pudo acceder al repo MoviVIPNetwork.${RESET}"
        echo -e "${GOLD}  👉 Verifica tu conexión a internet.${RESET}"
        return 1
    fi

    mkdir -p "$DEST"

    # Descargar archivos del paquete desde bots_extract/
    # admin_bot_klepernet.py se renombra a admin_bot.py
    echo -e "  ${CYAN}Descargando componentes...${NC}"
    for f in config.py database.py ssh_utils.py notif_bot.py; do
        curl -fsSL --max-time 30 "$RAW/$f" -o "$DEST/$f" 2>/dev/null \
            && echo -e "    ${GREEN}✓${RESET} $f" \
            || echo -e "    ${RED}✗${RESET} $f (requerido)"
    done

    # El admin bot viene como admin_bot_klepernet.py — renombrar
    if curl -fsSL --max-time 30 "$RAW/admin_bot_klepernet.py" -o "$DEST/admin_bot.py" 2>/dev/null; then
        echo -e "    ${GREEN}✓${RESET} admin_bot.py (from admin_bot_klepernet.py)"
    else
        echo -e "    ${RED}✗${RESET} admin_bot.py (requerido)"
    fi

    # Generar requirements.txt inline (no está en el repo)
    cat > "$DEST/requirements.txt" << 'REQEOF'
python-telegram-bot==21.6
paramiko>=3.4.0
REQEOF
    echo -e "    ${GREEN}✓${RESET} requirements.txt (generado)"

    echo ""

    if [[ ! -f "$DEST/config.py" || ! -f "$DEST/admin_bot.py" ]]; then
        echo -e "${RED}  ❌ Paquete incompleto (falta config.py o admin_bot.py).${RESET}"
        return 1
    fi

    # Configurar localmente (tokens/password/IDs) si el paquete trae placeholders
    configurar_bot_local "$DEST"

    # Guardar tokens y credenciales del cliente en .env
    cat > "$DEST/.env" << ENVEOF
ADMIN_BOT_TOKEN=$ADMIN_TOKEN
NOTIF_BOT_TOKEN=$NOTIF_TOKEN
FB_API_KEY=$C_FB_KEY
FB_AUTH_EMAIL=$C_FB_EMAIL
FB_AUTH_PASS=$C_FB_PASS
ENVEOF
    chmod 600 "$DEST/.env"
    echo -e "  ${GREEN}✔ Tokens y credenciales guardados en $DEST/.env${NC}"

    # Escribir tokens directamente en config.py
    if [[ -f "$DEST/config.py" ]]; then
        sed -i "s|^ADMIN_BOT_TOKEN = .*|ADMIN_BOT_TOKEN = \"$ADMIN_TOKEN\"|" "$DEST/config.py" 2>/dev/null
        sed -i "s|^NOTIF_BOT_TOKEN = .*|NOTIF_BOT_TOKEN = \"$NOTIF_TOKEN\"|" "$DEST/config.py" 2>/dev/null
        sed -i "s|^ADMIN_IDS = .*|ADMIN_IDS = [$ADMIN_TG_ID]|" "$DEST/config.py" 2>/dev/null
        sed -i "s|^FB_API_KEY = .*|FB_API_KEY = \"$C_FB_KEY\"|" "$DEST/config.py" 2>/dev/null
        sed -i "s|^FB_AUTH_EMAIL = .*|FB_AUTH_EMAIL = \"$C_FB_EMAIL\"|" "$DEST/config.py" 2>/dev/null
        sed -i "s|^FB_AUTH_PASS = .*|FB_AUTH_PASS = \"$C_FB_PASS\"|" "$DEST/config.py" 2>/dev/null
        # VPS password: configurar si el usuario la proporcionó
        local VPS_PASS_INPUT="${VPS_PASSWORD:-}"
        if [[ -z "$VPS_PASS_INPUT" || "$VPS_PASS_INPUT" == "PONER_PASSWORD_VPS_AQUI" ]]; then
            echo -ne "  ${CYAN}Contraseña root del VPS (para crear cuentas SSH): ${RESET}"
            read -r -s VPS_PASS_INPUT
            echo ""
        fi
        if [[ -n "$VPS_PASS_INPUT" ]]; then
            sed -i "s|^VPS_PASSWORD = .*|VPS_PASSWORD = \"$VPS_PASS_INPUT\"|" "$DEST/config.py" 2>/dev/null
        fi
        # ── Auto-detectar datos del VPS ──
        local VPS_SUB=$(hostname -f 2>/dev/null || echo "")
        local VPS_DOM=$(hostname -d 2>/dev/null || echo "")
        local SLOWDNS_PUB_VAL=$(cat /etc/slowdns/server.pub 2>/dev/null || echo "")

        # Pedir datos del cliente que no se pueden auto-detectar
        echo ""
        echo -e "${CYAN}  📋 Datos del cliente (Enter = valor por defecto):${NC}"

        # Subdominio (auto-detect hostname)
        echo -ne "  Subdominio del VPS [$VPS_SUB]: "
        read -r INPUT_SUB; [[ -n "$INPUT_SUB" ]] && VPS_SUB="$INPUT_SUB"

        # Dominio principal
        echo -ne "  Dominio principal (ej: midominio.com) [$VPS_DOM]: "
        read -r INPUT_DOM; [[ -n "$INPUT_DOM" ]] && VPS_DOM="$INPUT_DOM"

        # Marca / branding
        echo -ne "  Nombre de la marca [MoviVIP]: "
        read -r INPUT_MARCA; [[ -z "$INPUT_MARCA" ]] && INPUT_MARCA="MoviVIP"
        echo -ne "  Key de marca (minúsculas, ej: movivip) [${INPUT_MARCA,,}]: "
        read -r INPUT_MARCA_KEY; [[ -z "$INPUT_MARCA_KEY" ]] && INPUT_MARCA_KEY="${INPUT_MARCA,,}"

        # Canales de Telegram
        echo -ne "  Canal de Telegram [@canal]: "
        read -r INPUT_CANAL
        echo -ne "  Grupo de Telegram [@grupo]: "
        read -r INPUT_GRUPO
        echo -ne "  Bot de marca [@bot_username]: "
        read -r INPUT_BOT_MARCA

        # Monetag (opcional)
        echo ""
        echo -e "${GRAY}  Monetag MiniApp (deja vacío si no usa):${NC}"
        echo -ne "  Zone ID: "
        read -r INPUT_ZONE
        echo -ne "  SDK Function (ej: show_12345678): "
        read -r INPUT_SDK_FUNC

        # ── Reemplazar TODOS los placeholders en config.py ──
        sed -i "s|^VPS_SUBDOMAIN = .*|VPS_SUBDOMAIN = \"$VPS_SUB\"|" "$DEST/config.py" 2>/dev/null
        sed -i "s|^DOMAIN_MAIN = .*|DOMAIN_MAIN = \"$VPS_DOM\"|" "$DEST/config.py" 2>/dev/null
        sed -i "s|^BRAND_NAME = .*|BRAND_NAME = \"$INPUT_MARCA\"|" "$DEST/config.py" 2>/dev/null
        sed -i "s|^MY_BRAND = .*|MY_BRAND = \"$INPUT_MARCA_KEY\"|" "$DEST/config.py" 2>/dev/null
        sed -i "s|^BRAND_BOT = .*|BRAND_BOT = \"$INPUT_BOT_MARCA\"|" "$DEST/config.py" 2>/dev/null
        sed -i "s|^MAIN_CHANNEL = .*|MAIN_CHANNEL = \"$INPUT_CANAL\"|" "$DEST/config.py" 2>/dev/null
        sed -i "s|^SUPPORT_GROUP = .*|SUPPORT_GROUP = \"$INPUT_GRUPO\"|" "$DEST/config.py" 2>/dev/null

        # Monetag
        if [[ -n "$INPUT_ZONE" ]]; then
            sed -i "s|^MONETAG_ZONE_ID = .*|MONETAG_ZONE_ID = \"$INPUT_ZONE\"|" "$DEST/config.py" 2>/dev/null
            sed -i "s|^MONETAG_SDK_FUNC = .*|MONETAG_SDK_FUNC = \"$INPUT_SDK_FUNC\"|" "$DEST/config.py" 2>/dev/null
        fi

        # SlowDNS (auto-detect from VPS)
        if [[ -n "$SLOWDNS_PUB_VAL" ]]; then
            sed -i "s|^SLOWDNS_KEY = .*|SLOWDNS_KEY = \"$SLOWDNS_PUB_VAL\"|" "$DEST/config.py" 2>/dev/null
            sed -i "s|^SLOWDNS_PUB = .*|SLOWDNS_PUB = \"$SLOWDNS_PUB_VAL\"|" "$DEST/config.py" 2>/dev/null
        fi

        # Xray public key (auto-detect from xray config)
        local XRAY_PUB=$(grep -oP '"publicKey"\s*:\s*"\K[^"]+' /usr/local/etc/xray/config.json 2>/dev/null | head -1)
        local XRAY_SHORTID=$(grep -oP '"shortId"\s*:\s*"\K[^"]+' /usr/local/etc/xray/config.json 2>/dev/null | head -1)
        [[ -n "$XRAY_PUB" ]] && sed -i "s|^XRAY_VLESS_REALITY_PUBKEY = .*|XRAY_VLESS_REALITY_PUBKEY = \"$XRAY_PUB\"|" "$DEST/config.py" 2>/dev/null
        [[ -n "$XRAY_SHORTID" ]] && sed -i "s|^XRAY_VLESS_REALITY_SHORTID = .*|XRAY_VLESS_REALITY_SHORTID = \"$XRAY_SHORTID\"|" "$DEST/config.py" 2>/dev/null

        echo -e "  ${GREEN}✔ Todos los datos configurados en config.py${NC}"
    fi

    # Guardar ID del admin en la base de datos SQLite
    local DB_FILE=$(grep -oP 'DB_PATH\s*=\s*"\K[^"]+' "$DEST/config.py" 2>/dev/null)
    if [[ -n "$DB_FILE" ]] && command -v python3 &>/dev/null; then
        python3 -c "
import sqlite3, os
db_path = '$DB_FILE'
conn = sqlite3.connect(db_path)
cur = conn.cursor()
# Crear tabla admins si no existe
cur.execute('''CREATE TABLE IF NOT EXISTS admins (
    tg_id INTEGER PRIMARY KEY,
    added_by INTEGER NOT NULL,
    role TEXT DEFAULT 'admin',
    brand TEXT DEFAULT 'default',
    permissions TEXT DEFAULT '[\"all\"]',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)''')
# Insertar el admin
cur.execute('INSERT OR REPLACE INTO admins (tg_id, added_by, role, brand) VALUES (?, 0, ?, ?)',
    ($ADMIN_TG_ID, 'superadmin', '$CLIENTE_LO'))
conn.commit()
conn.close()
print('OK')
" 2>/dev/null && echo -e "  ${GREEN}✔ Admin ID ${ADMIN_TG_ID} guardado en base de datos${NC}" \
            || echo -e "  ${YELLOW}⚠ No se pudo guardar en DB (se guardará al iniciar el bot)${NC}"
    fi

    echo -e "${GREEN}  ✅ Paquete del bot instalado en $DEST${RESET}"
    echo -e "${GOLD}  🚀 Ahora se instalan dependencias y se crea el servicio...${RESET}"
    echo ""
    return 0
}

# =============================================================================
# CONFIGURAR BOT LOCALMENTE — detecta placeholders en config.py (PONER_TOKEN_*,
# PONER_PASSWORD_*, ADMIN_IDS = [0]) y pide los datos al dueño EN EL VPS.
# Las credenciales NUNCA se publican en GitHub: el repo lleva paquete sanitizado
# y aquí se completan en el servidor del cliente.
# =============================================================================
configurar_bot_local() {
    local d="${1:-}"
    [[ -z "$d" ]] && d=$(bot_dir)
    [[ -z "$d" ]] && return 0
    local CFG="$d/config.py"
    [[ ! -f "$CFG" ]] && return 0

    local CAMBIOS=0

    # 1) VPS_HOST real del VPS (placeholder "IP_DEL_VPS" o "movisvip.servegame.com" de plantilla)
    local IP_REAL; IP_REAL=$(curl -fsSL --max-time 8 ifconfig.me 2>/dev/null || echo "")
    [[ -z "$IP_REAL" ]] && IP_REAL=$(hostname -I 2>/dev/null | awk '{print $1}')
    if [[ -n "$IP_REAL" ]] && grep -q '^VPS_HOST = "IP_DEL_VPS"\|^VPS_HOST = "movisvip\|^VPS_HOST = "[0-9]*\.[0-9]*\.[0-9]*"' "$CFG"; then
        sed -i "s|^VPS_HOST = .*|VPS_HOST = \"$IP_REAL\"|" "$CFG" 2>/dev/null
        CAMBIOS=1
    fi
    # 1b) XRAY_VPS_IP — misma IP real (placeholder heredado del repo)
    if [[ -n "$IP_REAL" ]] && grep -q '^XRAY_VPS_IP = "IP_DEL_VPS"\|^XRAY_VPS_IP = "[0-9]*\.[0-9]*\.[0-9]*"' "$CFG"; then
        sed -i "s|^XRAY_VPS_IP = .*|XRAY_VPS_IP = \"$IP_REAL\"|" "$CFG" 2>/dev/null
        CAMBIOS=1
    fi
    # 1c) MINIAPP_BASE_URL — si apunta a una IP numerica vieja, reemplazar
    if [[ -n "$IP_REAL" ]] && grep -q 'MINIAPP_BASE_URL = "http://[0-9]*\.[0-9]*\.[0-9]*' "$CFG"; then
        sed -i "s|^MINIAPP_BASE_URL = .*|MINIAPP_BASE_URL = \"http://$IP_REAL:5000\"|" "$CFG" 2>/dev/null
        CAMBIOS=1
    fi

    # 2) Token ADMIN: si placeholder, preguntar (con aviso)
    if grep -q 'ADMIN_BOT_TOKEN = "PONER_TOKEN_ADMIN_AQUI"' "$CFG"; then
        echo -e "${GOLD}  ⚠️  El paquete trae ADMIN_BOT_TOKEN sin configurar.${RESET}"
        echo -ne "  ${CYAN}  Token del bot ADMIN (@BotFather): ${RESET}"
        read -r -s TOK
        echo ""
        if [[ -n "$TOK" ]]; then
            sed -i "s|^ADMIN_BOT_TOKEN = .*|ADMIN_BOT_TOKEN = \"$TOK\"|" "$CFG" 2>/dev/null
            CAMBIOS=1
        fi
    fi

    # 3) Token NOTIF: si placeholder o igual al admin, preguntar
    if grep -q 'NOTIF_BOT_TOKEN = "PONER_TOKEN_NOTIF_AQUI"' "$CFG"; then
        echo -e "${GOLD}  ⚠️  El paquete trae NOTIF_BOT_TOKEN sin configurar.${RESET}"
        echo -ne "  ${CYAN}  Token del bot de NOTIFICACIONES (@BotFather, bot DISTINTO): ${RESET}"
        read -r -s TOKN
        echo ""
        if [[ -n "$TOKN" ]]; then
            sed -i "s|^NOTIF_BOT_TOKEN = .*|NOTIF_BOT_TOKEN = \"$TOKN\"|" "$CFG" 2>/dev/null
            CAMBIOS=1
        fi
    fi

    # 4) ADMIN_IDS: si placeholder [0], preguntar
    if grep -q '^ADMIN_IDS = \[0\]' "$CFG"; then
        echo -ne "  ${CYAN}  Tu ID de Telegram (admin, @userinfobot): ${RESET}"
        read -r ADMID
        if [[ -n "$ADMID" ]]; then
            sed -i "s|^ADMIN_IDS = \[0\]|ADMIN_IDS = [$ADMID]|" "$CFG" 2>/dev/null
            CAMBIOS=1
        fi
    fi

    # 5) VPS_PASSWORD: placeholder "PONER_PASSWORD_VPS_AQUI" -> pedir (es el password root)
    if grep -q 'VPS_PASSWORD = "PONER_PASSWORD_VPS_AQUI"' "$CFG"; then
        echo -ne "  ${CYAN}  Contraseña root del VPS (para crear cuentas SSH): ${RESET}"
        read -r -s VPASS
        echo ""
        if [[ -n "$VPASS" ]]; then
            sed -i "s|^VPS_PASSWORD = .*|VPS_PASSWORD = \"$VPASS\"|" "$CFG" 2>/dev/null
            CAMBIOS=1
        fi
    fi

    if [[ "$CAMBIOS" -eq 1 ]]; then
        echo -e "${GREEN}  ✅ Configuración local completada.${RESET}"
    fi
    return 0
}

crear_servicio() {
    local d; d=$(bot_dir)
    [[ -z "$d" ]] && { echo -e "${RED}  ❌ No hay bot instalado.${RESET}"; return 1; }
    local c; c=$(basename "$d")
    local SVC="movivip-${c}-admin"
    local SVC_N="movivip-${c}-notif"

    # Dependencias
    if [[ ! -d "$d/venv" ]]; then
        echo -e "  ${CYAN}  🐍 Creando entorno virtual...${RESET}"
        python3 -m venv "$d/venv" 2>/dev/null || {
            pkg_install python3-venv python3-pip >/dev/null 2>&1
            python3 -m venv "$d/venv" 2>/dev/null
        }
    fi
    if [[ -f "$d/requirements.txt" ]]; then
        echo -e "  ${CYAN}  📚 Instalando dependencias...${RESET}"
        "$d/venv/bin/pip" install --upgrade pip -q 2>/dev/null
        "$d/venv/bin/pip" install -r "$d/requirements.txt" -q 2>/dev/null
    fi

    # Servicio ADMIN
    cat > "/etc/systemd/system/$SVC.service" <<EOF
[Unit]
Description=MoviVIP $c Admin Bot
After=network.target

[Service]
WorkingDirectory=$d
ExecStart=$d/venv/bin/python admin_bot.py
Restart=always
RestartSec=30
StartLimitBurst=5
StartLimitIntervalSec=600
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable "$SVC" >/dev/null 2>&1
    systemctl restart "$SVC" >/dev/null 2>&1
    echo -e "${GREEN}  ✅ Servicio $SVC creado y activado.${RESET}"

    # Servicio NOTIF (si el paquete trae notif_bot.py)
    if [[ -f "$d/notif_bot.py" ]]; then
        mkdir -p /var/log/movivip
        cat > "/etc/systemd/system/$SVC_N.service" <<EOF
[Unit]
Description=MoviVIP $c Notif Bot
After=network.target

[Service]
WorkingDirectory=$d
ExecStart=$d/venv/bin/python notif_bot.py
Restart=always
RestartSec=30
StartLimitBurst=5
StartLimitIntervalSec=600
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable "$SVC_N" >/dev/null 2>&1
        systemctl restart "$SVC_N" >/dev/null 2>&1
        echo -e "${GREEN}  ✅ Servicio $SVC_N creado y activado.${RESET}"
    fi
    return 0
}

# =============================================================================
# SINCRONIZAR CONTRASEÑA — reescribe VPS_PASSWORD en config.py del bot
# (lo llama rootpass.sh al cambiar la contraseña root de la VPS)
# =============================================================================
sync_pass() {
    local d; d=$(bot_dir)
    [[ -z "$d" ]] && return 0
    local CFG="$d/config.py"
    [[ ! -f "$CFG" ]] && return 0

    if [[ -n "$1" ]]; then
        local NEW_PASS="$1"
    else
        echo -ne "  ${CYAN}Nueva contraseña root de la VPS: ${RESET}"
        read -r -s NEW_PASS
        echo ""
    fi
    [[ -z "$NEW_PASS" ]] && { echo -e "${RED}  ❌ Contraseña vacía, no se sincroniza.${RESET}"; return 1; }

    sed -i "s|^VPS_PASSWORD = .*|VPS_PASSWORD = \"$NEW_PASS\"|" "$CFG" 2>/dev/null
    echo -e "${GREEN}  ✅ VPS_PASSWORD actualizado en $(basename "$d")/config.py${RESET}"

    local SVC; SVC=$(bot_service)
    if [[ -n "$SVC" ]] && systemctl list-unit-files 2>/dev/null | grep -q "^$SVC.service"; then
        systemctl restart "$SVC" >/dev/null 2>&1 && echo -e "  ${GREEN}↻ Bot reiniciado con la nueva contraseña.${RESET}"
    fi
    return 0
}

# =============================================================================
# ESTADO
# =============================================================================
status_bot() {
    local d; d=$(bot_dir)
    echo -e "${CYAN}  🤖 ESTADO DEL BOT${RESET}"
    echo -e "${GRAY}  ────────────────────────────────────────${RESET}"
    if [[ -z "$d" ]]; then
        echo -e "  ${RED}  ❌ No hay bot instalado en $BOT_ROOT${RESET}"
        return 0
    fi
    echo -e "  📁 Carpeta : ${WHITE}$d${RESET}"
    local c; c=$(basename "$d")
    local SVC; SVC=$(bot_service)
    local SVC_N="movivip-${c}-notif"
    if [[ -n "$SVC" ]]; then
        if systemctl is-active --quiet "$SVC"; then
            echo -e "  ⚡ Servicio: ${GREEN}🟢 ACTIVO${RESET} ($SVC)"
        else
            echo -e "  ⚡ Servicio: ${RED}🔴 INACTIVO${RESET} ($SVC)"
        fi
        systemctl is-enabled "$SVC" >/dev/null 2>&1 && echo -e "  🔄 Arranque : ${GREEN}con el sistema${RESET}" || echo -e "  🔄 Arranque : ${RED}manual${RESET}"
        if [[ -f "$d/notif_bot.py" ]]; then
            if systemctl is-active --quiet "$SVC_N"; then
                echo -e "  📢 Notif    : ${GREEN}🟢 ACTIVO${RESET} ($SVC_N)"
            else
                echo -e "  📢 Notif    : ${RED}🔴 INACTIVO${RESET} ($SVC_N)"
            fi
        fi
    fi
    if [[ -f "$d/config.py" ]]; then
        local token; token=$(grep -oP 'ADMIN_BOT_TOKEN = "\K[^"]+' "$d/config.py" 2>/dev/null)
        if [[ -n "$token" && "$token" != "PONER_TOKEN_ADMIN_AQUI" && "$token" != "IP_DEL_VPS"* ]]; then
            echo -e "  🎫 Token    : ${GREEN}configurado${RESET}"
        else
            echo -e "  🎫 Token    : ${RED}falta configurar${RESET}"
        fi
    fi
    return 0
}

# =============================================================================
# CAMBIAR TOKEN DEL BOT — cuando Telegram bloquea el token por rate limit
# Actualiza .env, config.py y admin_bot.py sin reinstalar todo
# =============================================================================
change_token() {
    local d; d=$(bot_dir)
    if [[ -z "$d" ]]; then
        echo -e "${RED}  ❌ No hay bot instalado en $BOT_ROOT${RESET}"
        return 1
    fi
    local CFG="$d/config.py"
    local ENV_FILE="$d/.env"

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${GOLD}   🔑 CAMBIAR TOKEN DEL BOT                               ${CYAN}║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${CYAN}║${RESET}   Bot actual: ${WHITE}$(basename "$d")${RESET}"
    echo -e "${CYAN}║${RESET}   ${GRAY}Útil cuando Telegram bloquea el token por rate-limit.${RESET}"
    echo -e "${CYAN}║${RESET}   ${GRAY}Solo cambia el token, NO reinstala todo.${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${RESET}"
    echo ""

    # Mostrar token actual (oculto)
    local OLD_TOKEN=$(grep -oP 'ADMIN_BOT_TOKEN\s*=\s*"\K[^"]+' "$CFG" 2>/dev/null)
    if [[ -n "$OLD_TOKEN" ]]; then
        echo -e "  Token actual: ${GRAY}${OLD_TOKEN:0:10}...${OLD_TOKEN: -5}${RESET}"
    fi
    echo ""

    # Pedir nuevo token
    local NEW_TOKEN=""
    echo -e "${CYAN}  Nuevo token de @BotFather:${RESET}"
    echo -e "${GRAY}  @BotFather → /newbot o /mybots → API Token${RESET}"
    if [[ -t 0 ]]; then
        read -rp "$(echo -e "  Token: ")" NEW_TOKEN
    fi
    if [[ -z "$NEW_TOKEN" ]]; then
        echo -e "${RED}  ❌ Token vacío, cancelado.${RESET}"
        return 1
    fi

    # Validar formato básico (debe tener : en medio y ser numérico:alfanumérico)
    if ! [[ "$NEW_TOKEN" =~ ^[0-9]+:.+$ ]]; then
        echo -e "${RED}  ❌ Formato inválido. Debe ser: 123456789:ABCdefGHI...${RESET}"
        return 1
    fi

    echo -e "  Token nuevo: ${GREEN}${NEW_TOKEN:0:10}...${NEW_TOKEN: -5}${RESET}"
    echo ""

    # Actualizar .env
    if [[ -f "$ENV_FILE" ]]; then
        sed -i "s|^ADMIN_BOT_TOKEN=.*|ADMIN_BOT_TOKEN=$NEW_TOKEN|" "$ENV_FILE" 2>/dev/null
        echo -e "  ${GREEN}✓${RESET} .env actualizado"
    fi

    # Actualizar config.py
    if [[ -f "$CFG" ]]; then
        sed -i "s|^ADMIN_BOT_TOKEN = .*|ADMIN_BOT_TOKEN = \"$NEW_TOKEN\"|" "$CFG" 2>/dev/null
        echo -e "  ${GREEN}✓${RESET} config.py actualizado"
    fi

    # Actualizar admin_bot.py (por si tiene fallback hardcodeado)
    if [[ -f "$d/admin_bot.py" ]]; then
        # Reemplazar cualquier token anterior (el que esté configurado)
        if [[ -n "$OLD_TOKEN" ]]; then
            sed -i "s|$OLD_TOKEN|$NEW_TOKEN|g" "$d/admin_bot.py" 2>/dev/null
        fi
        echo -e "  ${GREEN}✓${RESET} admin_bot.py actualizado"
    fi

    # Probar el token nuevo
    echo ""
    echo -e "${CYAN}  Probando token con Telegram API...${RESET}"
    local RESP=$(curl -s --max-time 10 "https://api.telegram.org/bot$NEW_TOKEN/getMe" 2>/dev/null)
    if echo "$RESP" | grep -q '"ok":true'; then
        local BOT_NAME=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['result'].get('username','?'))" 2>/dev/null)
        echo -e "  ${GREEN}✅ Token válido! Bot: @$BOT_NAME${RESET}"
    else
        echo -e "  ${YELLOW}⚠ Token no respondió (puede estar bien, verifica manualmente)${RESET}"
    fi

    # Reiniciar servicio
    local SVC; SVC=$(bot_service)
    if [[ -n "$SVC" ]] && systemctl list-unit-files 2>/dev/null | grep -q "^$SVC.service"; then
        echo ""
        echo -e "${CYAN}  Reiniciando servicio $SVC...${RESET}"
        systemctl restart "$SVC" 2>/dev/null
        sleep 3
        if systemctl is-active --quiet "$SVC"; then
            echo -e "  ${GREEN}✅ Bot activo con el nuevo token${RESET}"
        else
            echo -e "  ${RED}⚠ Bot no arrancó. Revisa logs: journalctl -u $SVC -n 20${RESET}"
        fi
    fi

    echo ""
    echo -e "${GREEN}  ✅ Token actualizado correctamente.${RESET}"
    return 0
}

# =============================================================================
# MENÚ INTERACTIVO
# =============================================================================
menu() {
    while true; do
        clear
        H1
        printf "${CYAN}║${GOLD}   🤖 BOT DE ADMINISTRACIÓN${RESET}${CYAN}                         ║${RESET}\n"
        H2
        if [[ -n "$PLAN" ]]; then
            printf "${CYAN}║${RESET}   Plan de licencia: ${GOLD}${PLAN^^}${RESET}${CYAN}                  ║${RESET}\n"
        fi
        printf "${CYAN}║${RESET}   Cliente: ${WHITE}${CLIENTE:-no definido}${RESET}${CYAN}                  ║${RESET}\n"
        H2
        echo ""
        if ! plan_tiene_bot; then
            echo -e "${RED}  ⚠️  TU PLAN (${PLAN:-BRONCE}) NO INCLUYE BOT${RESET}"
            echo -e "${GRAY}  El bot admin/user es EXCLUSIVO de los planes:${RESET}"
            echo -e "    ${GOLD}PREMIUM${RESET}   (15 días, 5 dispositivos)"
            echo -e "    ${GOLD}PLATINO${RESET}   (30 días, 10 dispositivos)"
            echo -e "    ${GOLD}VITALICIO${RESET} (de por vida, 10 dispositivos)"
            echo -e "  ${GRAY}Contacta a tu proveedor para subir de plan.${RESET}"
            echo ""
            read -rp "$(echo -e "${CYAN}➜ Presiona ENTER para volver${RESET}")"
            return 0
        fi
        status_bot
        echo ""
        echo -e "  ${GOLD}[1]${WHITE} 📦 Instalar / actualizar bot (desde MoviVIPNetwork)"
        echo -e "  ${GOLD}[2]${WHITE} 🚀 Activar servicio"
        echo -e "  ${GOLD}[3]${WHITE} 🛑 Detener servicio"
        echo -e "  ${GOLD}[4]${WHITE} 🔑 Sincronizar contraseña root del VPS"
        echo -e "  ${GOLD}[5]${WHITE} 📝 Abrir menú del bot (crear cuentas SSH)"
        echo -e "  ${GOLD}[6]${WHITE} 📊 Logs del servicio"
        echo -e "  ${GOLD}[7]${WHITE} 🔄 Cambiar token del bot (si Telegram lo bloqueó)"
        echo -e "  ${RED}[0]${WHITE} ↩ Volver"
        echo ""
        read -rp "$(echo -e "${CYAN}➜ ${GOLD}Opción${WHITE} ➤ ${RESET}")" OPC
        case "$OPC" in
            1)
                instalar_bot && crear_servicio
                read -rp "$(echo -e "${CYAN}➜ ENTER para continuar${RESET}")"
            ;;
            2)
                local SVC; SVC=$(bot_service)
                if [[ -n "$SVC" ]]; then
                    systemctl enable "$SVC" >/dev/null 2>&1
                    systemctl start "$SVC" >/dev/null 2>&1
                    local d2; d2=$(bot_dir)
                    if [[ -n "$d2" && -f "$d2/notif_bot.py" ]]; then
                        systemctl enable "movivip-$(basename "$d2")-notif" >/dev/null 2>&1
                        systemctl start "movivip-$(basename "$d2")-notif" >/dev/null 2>&1
                    fi
                    echo -e "${GREEN}  ✅ Bot activado${RESET}"
                else
                    instalar_bot && crear_servicio
                fi
                sleep 2
            ;;
            3)
                local SVC; SVC=$(bot_service)
                [[ -n "$SVC" ]] && systemctl stop "$SVC" >/dev/null 2>&1
                local d3; d3=$(bot_dir)
                [[ -n "$d3" ]] && systemctl stop "movivip-$(basename "$d3")-notif" >/dev/null 2>&1
                echo -e "${GOLD}  ⚠️  Bot detenido${RESET}"
                sleep 2
            ;;
            4) sync_pass ;;
            5)
                local d; d=$(bot_dir)
                if [[ -f "$d/menu.sh" ]]; then bash "$d/menu.sh"; else
                    echo -e "${RED}  ❌ menu.sh del bot no está. Instala el bot primero (opción 1).${RESET}"
                    sleep 2
                fi
            ;;
            6)
                local SVC; SVC=$(bot_service)
                if [[ -n "$SVC" ]]; then
                    echo -e "${GOLD}  📋 Logs ADMIN ($SVC):${RESET}"
                    journalctl -u "$SVC" --no-pager -n 15 2>/dev/null || echo -e "${RED}  Sin logs.${RESET}"
                    local d6; d6=$(bot_dir)
                    local SVC_N6="movivip-$(basename "$d6")-notif"
                    if [[ -n "$d6" && -f "$d6/notif_bot.py" ]]; then
                        echo ""
                        echo -e "${GOLD}  📋 Logs NOTIF ($SVC_N6):${RESET}"
                        journalctl -u "$SVC_N6" --no-pager -n 15 2>/dev/null || echo -e "${RED}  Sin logs.${RESET}"
                    fi
                else
                    echo -e "${RED}  ❌ Bot no instalado.${RESET}"
                fi
                read -rp "$(echo -e "${CYAN}➜ ENTER para continuar${RESET}")"
            ;;
            7) change_token; read -rp "$(echo -e "${CYAN}➜ ENTER para continuar${RESET}")" ;;
            0) return 0 ;;
            *) sleep 1 ;;
        esac
    done
}

# =============================================================================
# MODO CLI (desde install-con-licencia.sh)
# =============================================================================
case "${1:-}" in
    --install)
        if ! plan_tiene_bot; then
            echo -e "${GRAY}  Plan ${PLAN:-BRONCE}: sin bot (solo script multi-protocolo).${RESET}"
            exit 0
        fi
        instalar_bot && crear_servicio
        exit $?
    ;;
    --status)
        status_bot
        exit 0
    ;;
    --sync-pass)
        sync_pass "$2"
        exit $?
    ;;
    --change-token)
        change_token
        exit $?
    ;;
    *)
        menu
    ;;
esac
