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

# =============================================================================
# HELPERS
# =============================================================================
H1() { printf "${CYAN}╔"; printf '═%.0s' $(seq 1 60); printf "╗${RESET}\n"; }
H2() { printf "${CYAN}╠"; printf '═%.0s' $(seq 1 60); printf "╣${RESET}\n"; }
H3() { printf "${CYAN}╚"; printf '═%.0s' $(seq 1 60); printf "╝${RESET}\n"; }

bot_dir() {
    if [[ -n "$CLIENTE" && -d "$BOT_ROOT/$CLIENTE" ]]; then
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
        premium|platino|vitalicio) return 0 ;;
        *) return 1 ;;
    esac
}

# =============================================================================
# INSTALAR EL BOT DESDE GITHUB (según plan + cliente)
# =============================================================================
instalar_bot() {
    [[ -z "$CLIENTE" ]] && CLIENTE="cliente"
    local DEST="$BOT_ROOT/$CLIENTE"
    local RAW="$BOT_REPO_RAW/$CLIENTE"

    echo -e "${CYAN}  📦 Descargando bot para: ${WHITE}$CLIENTE${RESET} (plan ${GOLD}${PLAN}${RESET})"
    echo ""

    if ! curl -fsSL --max-time 20 "$RAW/requirements.txt" -o /tmp/movivip-bot-req.txt 2>/dev/null; then
        echo -e "${RED}  ❌ No se encontró el paquete del bot en el repo de entregas.${RESET}"
        echo -e "${GOLD}  👉 Contacta a tu proveedor: el bot de $CLIENTE aún no fue publicado.${RESET}"
        return 1
    fi

    mkdir -p "$DEST"
    # Archivos mínimos del paquete del bot (el resto lo resuelve config.py)
    for f in requirements.txt config.py admin_bot.py user_bot.py database.py mp_utils.py gen_banners.py deploy.sh menu.sh; do
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

    echo -e "${GREEN}  ✅ Paquete del bot instalado en $DEST${RESET}"
    echo -e "${GOLD}  🚀 Ahora se instalan dependencias y se crea el servicio...${RESET}"
    echo ""
    return 0
}

crear_servicio() {
    local d; d=$(bot_dir)
    [[ -z "$d" ]] && { echo -e "${RED}  ❌ No hay bot instalado.${RESET}"; return 1; }
    local c; c=$(basename "$d")
    local SVC="movivip-${c}-admin"

    # Dependencias
    if [[ ! -d "$d/venv" ]]; then
        echo -e "  ${CYAN}  🐍 Creando entorno virtual...${RESET}"
        python3 -m venv "$d/venv" 2>/dev/null || {
            apt-get install -y python3-venv python3-pip >/dev/null 2>&1
            python3 -m venv "$d/venv" 2>/dev/null
        }
    fi
    if [[ -f "$d/requirements.txt" ]]; then
        echo -e "  ${CYAN}  📚 Instalando dependencias...${RESET}"
        "$d/venv/bin/pip" install --upgrade pip -q 2>/dev/null
        "$d/venv/bin/pip" install -r "$d/requirements.txt" -q 2>/dev/null
    fi

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
    local SVC; SVC=$(bot_service)
    if [[ -n "$SVC" ]]; then
        if systemctl is-active --quiet "$SVC"; then
            echo -e "  ⚡ Servicio: ${GREEN}🟢 ACTIVO${RESET} ($SVC)"
        else
            echo -e "  ⚡ Servicio: ${RED}🔴 INACTIVO${RESET} ($SVC)"
        fi
        systemctl is-enabled "$SVC" >/dev/null 2>&1 && echo -e "  🔄 Arranque : ${GREEN}con el sistema${RESET}" || echo -e "  🔄 Arranque : ${RED}manual${RESET}"
    fi
    if [[ -f "$d/config.py" ]]; then
        local token; token=$(grep -oP 'ADMIN_BOT_TOKEN = "\K[^"]+' "$d/config.py" 2>/dev/null)
        if [[ -n "$token" && "$token" != "IP_DEL_VPS"* ]]; then
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
                    echo -e "${GREEN}  ✅ Bot activado${RESET}"
                else
                    instalar_bot && crear_servicio
                fi
                sleep 2
            ;;
            3)
                local SVC; SVC=$(bot_service)
                [[ -n "$SVC" ]] && systemctl stop "$SVC" >/dev/null 2>&1
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
                    journalctl -u "$SVC" --no-pager -n 30 2>/dev/null || echo -e "${RED}  Sin logs.${RESET}"
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
