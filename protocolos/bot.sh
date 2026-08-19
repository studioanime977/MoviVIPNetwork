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

# 🔑 GATE DE LICENCIA — validación EN VIVO contra Firebase
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
    local RAW="$BOT_REPO_RAW/$CLIENTE"

    echo -e "${CYAN}  📦 Instalando bot para: ${WHITE}$CLIENTE${RESET} (plan ${GOLD}${PLAN}${RESET})"
    echo ""
    echo -e "${YELLOW}  ⚠ Cada cliente debe crear su propio bot en @BotFather${NC}"
    echo -e "${GRAY}  1. Abre Telegram → @BotFather → /newbot${NC}"
    echo -e "${GRAY}  2. Copia el token que te dé${NC}"
    echo ""

    # Pedir token del bot del cliente
    local CLIENT_BOT_TOKEN=""
    if [[ -t 0 ]]; then
        read -rp "$(echo -e "${CYAN}  Token del bot de ${WHITE}$CLIENTE${CYAN}: ${RESET}")" CLIENT_BOT_TOKEN
    fi
    if [[ -z "$CLIENT_BOT_TOKEN" ]]; then
        echo -e "${RED}  ❌ Debes ingresar el token del bot${RESET}"
        return 1
    fi

    # Pedir credenciales Firebase del cliente (o usar las del sistema)
    echo ""
    echo -e "${GRAY}  Credenciales Firebase (deja vacío para usar las del sistema):${NC}"
    local C_FB_KEY="${FB_API_KEY:-AIzaSyDx7py9fl660hgMdRr_4utQ5fQqJcsGal8}"
    local C_FB_EMAIL="${FB_AUTH_EMAIL:-ventas@movivip.com}"
    local C_FB_PASS="${FB_AUTH_PASS:-MovivipVentas2026!}"
    read -rp "  API Key [$C_FB_KEY]: " INPUT_FB_KEY
    read -rp "  Email [$C_FB_EMAIL]: " INPUT_FB_EMAIL
    read -s -rp "  Password (oculto): " INPUT_FB_PASS
    echo ""
    [[ -n "$INPUT_FB_KEY" ]] && C_FB_KEY="$INPUT_FB_KEY"
    [[ -n "$INPUT_FB_EMAIL" ]] && C_FB_EMAIL="$INPUT_FB_EMAIL"
    [[ -n "$INPUT_FB_PASS" ]] && C_FB_PASS="$INPUT_FB_PASS"

    echo -e "${CYAN}  📥 Descargando paquete del bot...${NC}"

    if ! curl -fsSL --max-time 20 "$RAW/requirements.txt" -o /tmp/movivip-bot-req.txt 2>/dev/null; then
        echo -e "${RED}  ❌ No se encontró el paquete del bot en el repo de entregas.${RESET}"
        echo -e "${GOLD}  👉 Contacta a tu proveedor: el bot de $CLIENTE aún no fue publicado.${RESET}"
        return 1
    fi

    mkdir -p "$DEST"
    # Archivos del paquete del bot (generado por generar-bot-cliente.ps1)
    for f in requirements.txt config.py admin_bot.py notif_bot.py ssh_utils.py database.py deploy.sh menu.sh LEEME.txt; do
        curl -fsSL --max-time 30 "$RAW/$f" -o "$DEST/$f" 2>/dev/null \
            && echo -e "    ${GREEN}✓${RESET} $f" \
            || echo -e "    ${GRAY}·${RESET} $f (opcional)"
    done
    chmod +x "$DEST/deploy.sh" "$DEST/menu.sh" 2>/dev/null
    echo ""

    if [[ ! -f "$DEST/config.py" ]]; then
        echo -e "${RED}  ❌ config.py no se descargó. Paquete incompleto.${RESET}"
        return 1
    fi

    # Configurar localmente (tokens/password/IDs) si el paquete trae placeholders
    configurar_bot_local "$DEST"

    # Guardar token y credenciales del cliente en .env
    cat > "$DEST/.env" << ENVEOF
MOVIVIP_BOT_TOKEN=$CLIENT_BOT_TOKEN
FB_API_KEY=$C_FB_KEY
FB_AUTH_EMAIL=$C_FB_EMAIL
FB_AUTH_PASS=$C_FB_PASS
ENVEOF
    chmod 600 "$DEST/.env"
    echo -e "  ${GREEN}✔ Token y credenciales guardados en $DEST/.env${NC}"

    # Escribir token directamente en config.py (reemplazar placeholders)
    if [[ -f "$DEST/config.py" ]]; then
        sed -i "s|^ADMIN_BOT_TOKEN = .*|ADMIN_BOT_TOKEN = \"$CLIENT_BOT_TOKEN\"|" "$DEST/config.py" 2>/dev/null
        sed -i "s|^NOTIF_BOT_TOKEN = .*|NOTIF_BOT_TOKEN = \"$CLIENT_BOT_TOKEN\"|" "$DEST/config.py" 2>/dev/null
        sed -i "s|^FB_API_KEY = .*|FB_API_KEY = \"$C_FB_KEY\"|" "$DEST/config.py" 2>/dev/null
        sed -i "s|^FB_AUTH_EMAIL = .*|FB_AUTH_EMAIL = \"$C_FB_EMAIL\"|" "$DEST/config.py" 2>/dev/null
        sed -i "s|^FB_AUTH_PASS = .*|FB_AUTH_PASS = \"$C_FB_PASS\"|" "$DEST/config.py" 2>/dev/null
        echo -e "  ${GREEN}✔ Token configurado en config.py${NC}"
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
    if [[ -n "$IP_REAL" ]] && grep -q '^VPS_HOST = "IP_DEL_VPS"\|^VPS_HOST = "movisvip\|^VPS_HOST = "151.245.32.224"' "$CFG"; then
        sed -i "s|^VPS_HOST = .*|VPS_HOST = \"$IP_REAL\"|" "$CFG" 2>/dev/null
        CAMBIOS=1
    fi
    # 1b) XRAY_VPS_IP — misma IP real (placeholder heredado del repo)
    if [[ -n "$IP_REAL" ]] && grep -q '^XRAY_VPS_IP = "IP_DEL_VPS"\|^XRAY_VPS_IP = "151.245.32.224"' "$CFG"; then
        sed -i "s|^XRAY_VPS_IP = .*|XRAY_VPS_IP = \"$IP_REAL\"|" "$CFG" 2>/dev/null
        CAMBIOS=1
    fi
    # 1c) MINIAPP_BASE_URL — si apunta a la IP vieja del vendedor, reemplazar
    if [[ -n "$IP_REAL" ]] && grep -q 'MINIAPP_BASE_URL = "http://151.245.32.224' "$CFG"; then
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
RestartSec=5
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
        cat > "/etc/systemd/system/$SVC_N.service" <<EOF
[Unit]
Description=MoviVIP $c Notif Bot
After=network.target

[Service]
WorkingDirectory=$d
ExecStart=$d/venv/bin/python notif_bot.py
Restart=always
RestartSec=5
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
        echo -e "  ${GOLD}[1]${WHITE} 📦 Instalar / actualizar bot (desde GitHub)"
        echo -e "  ${GOLD}[2]${WHITE} 🚀 Activar servicio"
        echo -e "  ${GOLD}[3]${WHITE} 🛑 Detener servicio"
        echo -e "  ${GOLD}[4]${WHITE} 🔑 Sincronizar contraseña root del VPS"
        echo -e "  ${GOLD}[5]${WHITE} 📝 Abrir menú del bot (crear cuentas SSH)"
        echo -e "  ${GOLD}[6]${WHITE} 📊 Logs del servicio"
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
    *)
        menu
    ;;
esac
