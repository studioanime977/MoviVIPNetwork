#!/bin/bash
# =============================================================================
#  MOVIVIP NETWORK â€” BOT DE ADMINISTRACIÃ“N (instalador/activador por plan)
#  ---------------------------------------------------------------------------
#  Este script vive en /etc/movivip/protocolos/bot.sh y se ejecuta desde:
#    - El menÃº principal  -> opciÃ³n [10] ðŸ¤– Bot de administraciÃ³n
#    - install-con-licencia.sh  -> tras validar la key segÃºn el plan
#
#  QUÃ‰ HACE (segÃºn el plan de la licencia en /etc/movivip/licencia.conf):
#    BRONCE    -> avisa que el bot es EXCLUSIVO de planes PREMIUM+
#    PREMIUM+  -> descarga el bot desde GitHub segÃºn el plan del cliente,
#                 lo instala en /root/movivip_bots/<cliente>/, crea el
#                 servicio systemd movivip-<cliente>-admin y lo ACTIVA.
#
#  El paquete del bot por cliente se publica en el repo de entregas:
#    https://github.com/studioanime977/movivip-bots/raw/main/<cliente>/
#  (el generador generar-bot-cliente.ps1 produce ese paquete)
#
#  USO:
#    bash bot.sh                 -> menÃº interactivo (desde el panel)
#    bash bot.sh --install       -> modo automÃ¡tico (desde install-con-licencia)
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

# ðŸ”‘ GATE DE LICENCIA â€” validaciÃ³n EN VIVO contra Firebase
bash /etc/movivip/check-licencia.sh || exit 1

# Repo de entregas del bot (paquete por cliente, generado por el vendedor)
BOT_REPO_RAW="https://raw.githubusercontent.com/studioanime977/movivip-bots/main"
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
# Nombre de carpeta/servicio del bot SIEMPRE en minÃºsculas (lo genera el
# generador: vps-video-vitalicia, netfast, etc.). El CLIENTE de licencia.conf
# puede llevar mayÃºsculas ("VPS-Video-Vitalicia") -> normalizamos aquÃ­.
CLIENTE_LO=$(echo "${CLIENTE,,}" | tr 'A-Z' 'a-z' | tr -d ' ')

# =============================================================================
# HELPERS
# =============================================================================
H1() { printf "${CYAN}â•”"; printf 'â•%.0s' $(seq 1 60); printf "â•—${RESET}\n"; }
H2() { printf "${CYAN}â• "; printf 'â•%.0s' $(seq 1 60); printf "â•£${RESET}\n"; }
H3() { printf "${CYAN}â•š"; printf 'â•%.0s' $(seq 1 60); printf "â•${RESET}\n"; }

bot_dir() {
    # Buscar primero la carpeta del CLIENTE normalizada (minÃºsculas)
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
# INSTALAR EL BOT DESDE GITHUB (segÃºn plan + cliente)
# =============================================================================
instalar_bot() {
    [[ -z "$CLIENTE" ]] && CLIENTE="cliente"
    [[ -z "$CLIENTE_LO" ]] && CLIENTE_LO="cliente"

    # Super admin y mayorista usan el bot-generador que ya viene con el sistema
    if [[ "$PLAN_LO" == "super" || "$PLAN_LO" == "mayorista" ]]; then
        echo -e "${CYAN}  ðŸ“¦ Configurando bot generador para: ${WHITE}$CLIENTE${RESET} (plan ${GOLD}${PLAN}${RESET})"
        echo ""

        local BOT_SRC="/etc/movivip/herramientas/bot-generador.sh"
        local BOT_SVC="/etc/movivip/herramientas/movivip-bot-generador.service"
        local DEST="$BOT_ROOT/$CLIENTE_LO"

        if [[ ! -f "$BOT_SRC" ]]; then
            echo -e "${RED}  âŒ No se encontrÃ³ bot-generador.sh en $BOT_SRC${RESET}"
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
            echo -e "${RED}  âŒ Debes ingresar un ID numÃ©rico vÃ¡lido${RESET}"
            return 1
        fi
        echo -e "  ${GREEN}âœ” Admin ID: ${ADMIN_TG_ID}${NC}"

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

        echo -e "${GREEN}  âœ… Bot generador configurado en $DEST${RESET}"
        echo -e "${GOLD}  ðŸš€ Ahora se crea el servicio...${RESET}"
        echo ""
        return 0
    fi

    # â”€â”€ CLIENTES: pedir token de SU bot (cada cliente crea su propio bot en BotFather) â”€â”€
    local DEST="$BOT_ROOT/$CLIENTE_LO"
    local RAW="$BOT_REPO_RAW/$CLIENTE"

    echo -e "${CYAN}  ðŸ“¦ Instalando bot para: ${WHITE}$CLIENTE${RESET} (plan ${GOLD}${PLAN}${RESET})"
    echo ""
    echo -e "${YELLOW}  âš  Cada cliente debe crear 2 bots en @BotFather${NC}"
    echo -e "${GRAY}  Bot 1: Admin (crea usuarios SSH, gestiona el VPS)${NC}"
    echo -e "${GRAY}  Bot 2: Notificaciones (envÃ­a alertas a los clientes)${NC}"
    echo ""

    # Pedir token del bot ADMIN
    local ADMIN_TOKEN=""
    echo -e "${CYAN}  Bot ADMIN (crea usuarios SSH):${NC}"
    echo -e "${GRAY}  @BotFather â†’ /newbot â†’ nombra: 'MiBotAdmin'${NC}"
    if [[ -t 0 ]]; then
        read -rp "$(echo -e "  Token del bot ADMIN: ")" ADMIN_TOKEN
    fi
    if [[ -z "$ADMIN_TOKEN" ]]; then
        echo -e "${RED}  âŒ Debes ingresar el token del bot admin${RESET}"
        return 1
    fi

    # Pedir token del bot NOTIFICACIONES
    local NOTIF_TOKEN=""
    echo ""
    echo -e "${CYAN}  Bot NOTIFICACIONES (envÃ­a alertas):${NC}"
    echo -e "${GRAY}  @BotFather â†’ /newbot â†’ nombra: 'MiBotNotif'${NC}"
    if [[ -t 0 ]]; then
        read -rp "$(echo -e "  Token del bot NOTIF: ")" NOTIF_TOKEN
    fi
    if [[ -z "$NOTIF_TOKEN" ]]; then
        echo -e "${RED}  âŒ Debes ingresar el token del bot de notificaciones${RESET}"
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
        echo -e "${RED}  âŒ Debes ingresar un ID numÃ©rico vÃ¡lido${RESET}"
        return 1
    fi
    echo -e "  ${GREEN}âœ” Admin ID: ${ADMIN_TG_ID}${NC}"

    # Pedir credenciales Firebase del cliente (o usar las del sistema)
    echo ""
    echo -e "${GRAY}  Credenciales Firebase (deja vacÃ­o para usar las del sistema):${NC}"
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

    echo -e "${CYAN}  ðŸ“¥ Descargando paquete del bot...${NC}"

    if ! curl -fsSL --max-time 20 "$RAW/requirements.txt" -o /tmp/movivip-bot-req.txt 2>/dev/null; then
        echo -e "${RED}  âŒ No se encontrÃ³ el paquete del bot en el repo de entregas.${RESET}"
        echo -e "${GOLD}  ðŸ‘‰ Contacta a tu proveedor: el bot de $CLIENTE aÃºn no fue publicado.${RESET}"
        return 1
    fi

    mkdir -p "$DEST"
    # Archivos del paquete del bot (generado por generar-bot-cliente.ps1)
    for f in requirements.txt config.py admin_bot.py notif_bot.py ssh_utils.py database.py deploy.sh menu.sh LEEME.txt; do
        curl -fsSL --max-time 30 "$RAW/$f" -o "$DEST/$f" 2>/dev/null \
            && echo -e "    ${GREEN}âœ“${RESET} $f" \
            || echo -e "    ${GRAY}Â·${RESET} $f (opcional)"
    done
    chmod +x "$DEST/deploy.sh" "$DEST/menu.sh" 2>/dev/null
    echo ""

    if [[ ! -f "$DEST/config.py" ]]; then
        echo -e "${RED}  âŒ config.py no se descargÃ³. Paquete incompleto.${RESET}"
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
    echo -e "  ${GREEN}âœ” Tokens y credenciales guardados en $DEST/.env${NC}"

    # Escribir tokens directamente en config.py
    if [[ -f "$DEST/config.py" ]]; then
        sed -i "s|^ADMIN_BOT_TOKEN = .*|ADMIN_BOT_TOKEN = \"$ADMIN_TOKEN\"|" "$DEST/config.py" 2>/dev/null
        sed -i "s|^NOTIF_BOT_TOKEN = .*|NOTIF_BOT_TOKEN = \"$NOTIF_TOKEN\"|" "$DEST/config.py" 2>/dev/null
        sed -i "s|^ADMIN_IDS = .*|ADMIN_IDS = [$ADMIN_TG_ID]|" "$DEST/config.py" 2>/dev/null
        sed -i "s|^FB_API_KEY = .*|FB_API_KEY = \"$C_FB_KEY\"|" "$DEST/config.py" 2>/dev/null
        sed -i "s|^FB_AUTH_EMAIL = .*|FB_AUTH_EMAIL = \"$C_FB_EMAIL\"|" "$DEST/config.py" 2>/dev/null
        sed -i "s|^FB_AUTH_PASS = .*|FB_AUTH_PASS = \"$C_FB_PASS\"|" "$DEST/config.py" 2>/dev/null
        echo -e "  ${GREEN}âœ” Tokens y Admin ID configurados en config.py${NC}"
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
" 2>/dev/null && echo -e "  ${GREEN}âœ” Admin ID ${ADMIN_TG_ID} guardado en base de datos${NC}" \
            || echo -e "  ${YELLOW}âš  No se pudo guardar en DB (se guardarÃ¡ al iniciar el bot)${NC}"
    fi

    echo -e "${GREEN}  âœ… Paquete del bot instalado en $DEST${RESET}"
    echo -e "${GOLD}  ðŸš€ Ahora se instalan dependencias y se crea el servicio...${RESET}"
    echo ""
    return 0
}

# =============================================================================
# CONFIGURAR BOT LOCALMENTE â€” detecta placeholders en config.py (PONER_TOKEN_*,
# PONER_PASSWORD_*, ADMIN_IDS = [0]) y pide los datos al dueÃ±o EN EL VPS.
# Las credenciales NUNCA se publican en GitHub: el repo lleva paquete sanitizado
# y aquÃ­ se completan en el servidor del cliente.
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
    if [[ -n "$IP_REAL" ]] && grep -q '^VPS_HOST = "IP_DEL_VPS"\|^VPS_HOST = "movisvip\|^VPS_HOST = "151.245.32.224"' "$CFG"; then
        sed -i "s|^VPS_HOST = .*|VPS_HOST = \"$IP_REAL\"|" "$CFG" 2>/dev/null
        CAMBIOS=1
    fi
    # 1b) XRAY_VPS_IP â€” misma IP real (placeholder heredado del repo)
    if [[ -n "$IP_REAL" ]] && grep -q '^XRAY_VPS_IP = "IP_DEL_VPS"\|^XRAY_VPS_IP = "151.245.32.224"' "$CFG"; then
        sed -i "s|^XRAY_VPS_IP = .*|XRAY_VPS_IP = \"$IP_REAL\"|" "$CFG" 2>/dev/null
        CAMBIOS=1
    fi
    # 1c) MINIAPP_BASE_URL â€” si apunta a la IP vieja del vendedor, reemplazar
    if [[ -n "$IP_REAL" ]] && grep -q 'MINIAPP_BASE_URL = "http://151.245.32.224' "$CFG"; then
        sed -i "s|^MINIAPP_BASE_URL = .*|MINIAPP_BASE_URL = \"http://$IP_REAL:5000\"|" "$CFG" 2>/dev/null
        CAMBIOS=1
    fi

    # 2) Token ADMIN: si placeholder, preguntar (con aviso)
    if grep -q 'ADMIN_BOT_TOKEN = "PONER_TOKEN_ADMIN_AQUI"' "$CFG"; then
        echo -e "${GOLD}  âš ï¸  El paquete trae ADMIN_BOT_TOKEN sin configurar.${RESET}"
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
        echo -e "${GOLD}  âš ï¸  El paquete trae NOTIF_BOT_TOKEN sin configurar.${RESET}"
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
        echo -ne "  ${CYAN}  ContraseÃ±a root del VPS (para crear cuentas SSH): ${RESET}"
        read -r -s VPASS
        echo ""
        if [[ -n "$VPASS" ]]; then
            sed -i "s|^VPS_PASSWORD = .*|VPS_PASSWORD = \"$VPASS\"|" "$CFG" 2>/dev/null
            CAMBIOS=1
        fi
    fi

    if [[ "$CAMBIOS" -eq 1 ]]; then
        echo -e "${GREEN}  âœ… ConfiguraciÃ³n local completada.${RESET}"
    fi
    return 0
}

crear_servicio() {
    local d; d=$(bot_dir)
    [[ -z "$d" ]] && { echo -e "${RED}  âŒ No hay bot instalado.${RESET}"; return 1; }
    local c; c=$(basename "$d")
    local SVC="movivip-${c}-admin"
    local SVC_N="movivip-${c}-notif"

    # Dependencias
    if [[ ! -d "$d/venv" ]]; then
        echo -e "  ${CYAN}  ðŸ Creando entorno virtual...${RESET}"
        python3 -m venv "$d/venv" 2>/dev/null || {
            pkg_install python3-venv python3-pip >/dev/null 2>&1
            python3 -m venv "$d/venv" 2>/dev/null
        }
    fi
    if [[ -f "$d/requirements.txt" ]]; then
        echo -e "  ${CYAN}  ðŸ“š Instalando dependencias...${RESET}"
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
    echo -e "${GREEN}  âœ… Servicio $SVC creado y activado.${RESET}"

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
        echo -e "${GREEN}  âœ… Servicio $SVC_N creado y activado.${RESET}"
    fi
    return 0
}

# =============================================================================
# SINCRONIZAR CONTRASEÃ‘A â€” reescribe VPS_PASSWORD en config.py del bot
# (lo llama rootpass.sh al cambiar la contraseÃ±a root de la VPS)
# =============================================================================
sync_pass() {
    local d; d=$(bot_dir)
    [[ -z "$d" ]] && return 0
    local CFG="$d/config.py"
    [[ ! -f "$CFG" ]] && return 0

    if [[ -n "$1" ]]; then
        local NEW_PASS="$1"
    else
        echo -ne "  ${CYAN}Nueva contraseÃ±a root de la VPS: ${RESET}"
        read -r -s NEW_PASS
        echo ""
    fi
    [[ -z "$NEW_PASS" ]] && { echo -e "${RED}  âŒ ContraseÃ±a vacÃ­a, no se sincroniza.${RESET}"; return 1; }

    sed -i "s|^VPS_PASSWORD = .*|VPS_PASSWORD = \"$NEW_PASS\"|" "$CFG" 2>/dev/null
    echo -e "${GREEN}  âœ… VPS_PASSWORD actualizado en $(basename "$d")/config.py${RESET}"

    local SVC; SVC=$(bot_service)
    if [[ -n "$SVC" ]] && systemctl list-unit-files 2>/dev/null | grep -q "^$SVC.service"; then
        systemctl restart "$SVC" >/dev/null 2>&1 && echo -e "  ${GREEN}â†» Bot reiniciado con la nueva contraseÃ±a.${RESET}"
    fi
    return 0
}

# =============================================================================
# ESTADO
# =============================================================================
status_bot() {
    local d; d=$(bot_dir)
    echo -e "${CYAN}  ðŸ¤– ESTADO DEL BOT${RESET}"
    echo -e "${GRAY}  â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€${RESET}"
    if [[ -z "$d" ]]; then
        echo -e "  ${RED}  âŒ No hay bot instalado en $BOT_ROOT${RESET}"
        return 0
    fi
    echo -e "  ðŸ“ Carpeta : ${WHITE}$d${RESET}"
    local c; c=$(basename "$d")
    local SVC; SVC=$(bot_service)
    local SVC_N="movivip-${c}-notif"
    if [[ -n "$SVC" ]]; then
        if systemctl is-active --quiet "$SVC"; then
            echo -e "  âš¡ Servicio: ${GREEN}ðŸŸ¢ ACTIVO${RESET} ($SVC)"
        else
            echo -e "  âš¡ Servicio: ${RED}ðŸ”´ INACTIVO${RESET} ($SVC)"
        fi
        systemctl is-enabled "$SVC" >/dev/null 2>&1 && echo -e "  ðŸ”„ Arranque : ${GREEN}con el sistema${RESET}" || echo -e "  ðŸ”„ Arranque : ${RED}manual${RESET}"
        if [[ -f "$d/notif_bot.py" ]]; then
            if systemctl is-active --quiet "$SVC_N"; then
                echo -e "  ðŸ“¢ Notif    : ${GREEN}ðŸŸ¢ ACTIVO${RESET} ($SVC_N)"
            else
                echo -e "  ðŸ“¢ Notif    : ${RED}ðŸ”´ INACTIVO${RESET} ($SVC_N)"
            fi
        fi
    fi
    if [[ -f "$d/config.py" ]]; then
        local token; token=$(grep -oP 'ADMIN_BOT_TOKEN = "\K[^"]+' "$d/config.py" 2>/dev/null)
        if [[ -n "$token" && "$token" != "PONER_TOKEN_ADMIN_AQUI" && "$token" != "IP_DEL_VPS"* ]]; then
            echo -e "  ðŸŽ« Token    : ${GREEN}configurado${RESET}"
        else
            echo -e "  ðŸŽ« Token    : ${RED}falta configurar${RESET}"
        fi
    fi
    return 0
}

# =============================================================================
# CAMBIAR TOKEN DEL BOT â€” cuando Telegram bloquea el token por rate limit
# Actualiza .env, config.py y admin_bot.py sin reinstalar todo
# =============================================================================
change_token() {
    local d; d=$(bot_dir)
    if [[ -z "$d" ]]; then
        echo -e "${RED}  âŒ No hay bot instalado en $BOT_ROOT${RESET}"
        return 1
    fi
    local CFG="$d/config.py"
    local ENV_FILE="$d/.env"

    echo -e "${CYAN}â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—${RESET}"
    echo -e "${CYAN}â•‘${GOLD}   ðŸ”‘ CAMBIAR TOKEN DEL BOT                               ${CYAN}â•‘${RESET}"
    echo -e "${CYAN}â• â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•£${RESET}"
    echo -e "${CYAN}â•‘${RESET}   Bot actual: ${WHITE}$(basename "$d")${RESET}"
    echo -e "${CYAN}â•‘${RESET}   ${GRAY}Ãštil cuando Telegram bloquea el token por rate-limit.${RESET}"
    echo -e "${CYAN}â•‘${RESET}   ${GRAY}Solo cambia el token, NO reinstala todo.${RESET}"
    echo -e "${CYAN}â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${RESET}"
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
    echo -e "${GRAY}  @BotFather â†’ /newbot o /mybots â†’ API Token${RESET}"
    if [[ -t 0 ]]; then
        read -rp "$(echo -e "  Token: ")" NEW_TOKEN
    fi
    if [[ -z "$NEW_TOKEN" ]]; then
        echo -e "${RED}  âŒ Token vacÃ­o, cancelado.${RESET}"
        return 1
    fi

    # Validar formato bÃ¡sico (debe tener : en medio y ser numÃ©rico:alfanumÃ©rico)
    if ! [[ "$NEW_TOKEN" =~ ^[0-9]+:.+$ ]]; then
        echo -e "${RED}  âŒ Formato invÃ¡lido. Debe ser: 123456789:ABCdefGHI...${RESET}"
        return 1
    fi

    echo -e "  Token nuevo: ${GREEN}${NEW_TOKEN:0:10}...${NEW_TOKEN: -5}${RESET}"
    echo ""

    # Actualizar .env
    if [[ -f "$ENV_FILE" ]]; then
        sed -i "s|^ADMIN_BOT_TOKEN=.*|ADMIN_BOT_TOKEN=$NEW_TOKEN|" "$ENV_FILE" 2>/dev/null
        echo -e "  ${GREEN}âœ“${RESET} .env actualizado"
    fi

    # Actualizar config.py
    if [[ -f "$CFG" ]]; then
        sed -i "s|^ADMIN_BOT_TOKEN = .*|ADMIN_BOT_TOKEN = \"$NEW_TOKEN\"|" "$CFG" 2>/dev/null
        echo -e "  ${GREEN}âœ“${RESET} config.py actualizado"
    fi

    # Actualizar admin_bot.py (por si tiene fallback hardcodeado)
    if [[ -f "$d/admin_bot.py" ]]; then
        # Reemplazar cualquier token anterior (el que estÃ© configurado)
        if [[ -n "$OLD_TOKEN" ]]; then
            sed -i "s|$OLD_TOKEN|$NEW_TOKEN|g" "$d/admin_bot.py" 2>/dev/null
        fi
        echo -e "  ${GREEN}âœ“${RESET} admin_bot.py actualizado"
    fi

    # Probar el token nuevo
    echo ""
    echo -e "${CYAN}  Probando token con Telegram API...${RESET}"
    local RESP=$(curl -s --max-time 10 "https://api.telegram.org/bot$NEW_TOKEN/getMe" 2>/dev/null)
    if echo "$RESP" | grep -q '"ok":true'; then
        local BOT_NAME=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['result'].get('username','?'))" 2>/dev/null)
        echo -e "  ${GREEN}âœ… Token vÃ¡lido! Bot: @$BOT_NAME${RESET}"
    else
        echo -e "  ${YELLOW}âš  Token no respondiÃ³ (puede estar bien, verifica manualmente)${RESET}"
    fi

    # Reiniciar servicio
    local SVC; SVC=$(bot_service)
    if [[ -n "$SVC" ]] && systemctl list-unit-files 2>/dev/null | grep -q "^$SVC.service"; then
        echo ""
        echo -e "${CYAN}  Reiniciando servicio $SVC...${RESET}"
        systemctl restart "$SVC" 2>/dev/null
        sleep 3
        if systemctl is-active --quiet "$SVC"; then
            echo -e "  ${GREEN}âœ… Bot activo con el nuevo token${RESET}"
        else
            echo -e "  ${RED}âš  Bot no arrancÃ³. Revisa logs: journalctl -u $SVC -n 20${RESET}"
        fi
    fi

    echo ""
    echo -e "${GREEN}  âœ… Token actualizado correctamente.${RESET}"
    return 0
}

# =============================================================================
# MENÃš INTERACTIVO
# =============================================================================
menu() {
    while true; do
        clear
        H1
        printf "${CYAN}â•‘${GOLD}   ðŸ¤– BOT DE ADMINISTRACIÃ“N${RESET}${CYAN}                         â•‘${RESET}\n"
        H2
        if [[ -n "$PLAN" ]]; then
            printf "${CYAN}â•‘${RESET}   Plan de licencia: ${GOLD}${PLAN^^}${RESET}${CYAN}                  â•‘${RESET}\n"
        fi
        printf "${CYAN}â•‘${RESET}   Cliente: ${WHITE}${CLIENTE:-no definido}${RESET}${CYAN}                  â•‘${RESET}\n"
        H2
        echo ""
        if ! plan_tiene_bot; then
            echo -e "${RED}  âš ï¸  TU PLAN (${PLAN:-BRONCE}) NO INCLUYE BOT${RESET}"
            echo -e "${GRAY}  El bot admin/user es EXCLUSIVO de los planes:${RESET}"
            echo -e "    ${GOLD}PREMIUM${RESET}   (15 dÃ­as, 5 dispositivos)"
            echo -e "    ${GOLD}PLATINO${RESET}   (30 dÃ­as, 10 dispositivos)"
            echo -e "    ${GOLD}VITALICIO${RESET} (de por vida, 10 dispositivos)"
            echo -e "  ${GRAY}Contacta a tu proveedor para subir de plan.${RESET}"
            echo ""
            read -rp "$(echo -e "${CYAN}âžœ Presiona ENTER para volver${RESET}")"
            return 0
        fi
        status_bot
        echo ""
        echo -e "  ${GOLD}[1]${WHITE} ðŸ“¦ Instalar / actualizar bot (desde GitHub)"
        echo -e "  ${GOLD}[2]${WHITE} ðŸš€ Activar servicio"
        echo -e "  ${GOLD}[3]${WHITE} ðŸ›‘ Detener servicio"
        echo -e "  ${GOLD}[4]${WHITE} ðŸ”‘ Sincronizar contraseÃ±a root del VPS"
        echo -e "  ${GOLD}[5]${WHITE} ðŸ“ Abrir menÃº del bot (crear cuentas SSH)"
        echo -e "  ${GOLD}[6]${WHITE} ðŸ“Š Logs del servicio"
        echo -e "  ${GOLD}[7]${WHITE} ðŸ”„ Cambiar token del bot (si Telegram lo bloqueÃ³)"
        echo -e "  ${RED}[0]${WHITE} â†© Volver"
        echo ""
        read -rp "$(echo -e "${CYAN}âžœ ${GOLD}OpciÃ³n${WHITE} âž¤ ${RESET}")" OPC
        case "$OPC" in
            1)
                instalar_bot && crear_servicio
                read -rp "$(echo -e "${CYAN}âžœ ENTER para continuar${RESET}")"
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
                    echo -e "${GREEN}  âœ… Bot activado${RESET}"
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
                echo -e "${GOLD}  âš ï¸  Bot detenido${RESET}"
                sleep 2
            ;;
            4) sync_pass ;;
            5)
                local d; d=$(bot_dir)
                if [[ -f "$d/menu.sh" ]]; then bash "$d/menu.sh"; else
                    echo -e "${RED}  âŒ menu.sh del bot no estÃ¡. Instala el bot primero (opciÃ³n 1).${RESET}"
                    sleep 2
                fi
            ;;
            6)
                local SVC; SVC=$(bot_service)
                if [[ -n "$SVC" ]]; then
                    echo -e "${GOLD}  ðŸ“‹ Logs ADMIN ($SVC):${RESET}"
                    journalctl -u "$SVC" --no-pager -n 15 2>/dev/null || echo -e "${RED}  Sin logs.${RESET}"
                    local d6; d6=$(bot_dir)
                    local SVC_N6="movivip-$(basename "$d6")-notif"
                    if [[ -n "$d6" && -f "$d6/notif_bot.py" ]]; then
                        echo ""
                        echo -e "${GOLD}  ðŸ“‹ Logs NOTIF ($SVC_N6):${RESET}"
                        journalctl -u "$SVC_N6" --no-pager -n 15 2>/dev/null || echo -e "${RED}  Sin logs.${RESET}"
                    fi
                else
                    echo -e "${RED}  âŒ Bot no instalado.${RESET}"
                fi
                read -rp "$(echo -e "${CYAN}âžœ ENTER para continuar${RESET}")"
            ;;
            7) change_token; read -rp "$(echo -e "${CYAN}âžœ ENTER para continuar${RESET}")" ;;
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
