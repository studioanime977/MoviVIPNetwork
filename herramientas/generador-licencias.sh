#!/bin/bash

#=========================================================
#   MoviVIP Network — GENERADOR DE LICENCIAS
#   Extraído del menú principal (case 17) para vivir como
#   herramienta independiente bajo 🧰 Herramientas → Bots.
#   Solo super admins y proveedores pueden generar keys.
#=========================================================

BASE="/etc/movivip"
CONFIG="$BASE/config.conf"

# ── i18n shim (auto) ───────────────────────────────────
if ! declare -F trx >/dev/null 2>&1; then trx() { printf '%s' "$1"; }; fi

# ── Cargar idioma + trx + diseño + navegación ──────────
if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)"
fi
source "$BASE/lib/ui.sh" 2>/dev/null || true
source "$BASE/lib/nav.sh" 2>/dev/null || true
[[ -f "$CONFIG" ]] && source "$CONFIG"

# Colores MoviVIP
RESET="\e[0m"; RED="\e[1;91m"; GREEN="\e[1;92m"; GOLD="\e[1;93m"
BLUE="\e[1;94m"; CYAN="\e[1;96m"; WHITE="\e[1;97m"; GRAY="\e[1;90m"

K17_FB_BASE="movivip-network-default-rtdb.firebaseio.com"

# ── AUTENTICACIÓN SUPER-ADMIN / MAYORISTA ──
clear
mv_header "🔑 ${KEYGEN_TITLE:-Generador de Licencias}" "Solo super admins y proveedores" "v6.2"
echo ""
echo -e "${CYAN}  ${KEYGEN_ENTER_KEY:-Ingresa tu key (super admin o proveedor):}${RESET}"
read -rp "  > " K17_AUTH_KEY
if [[ -z "$K17_AUTH_KEY" ]]; then
    echo -e "${RED}  ${KEYGEN_CANCELED:-Cancelado.}${RESET}"
    sleep 2
    exec bash "$BASE/herramientas/menu.sh"
fi

echo -e "${CYAN}  ${KEYGEN_VERIFYING:-Verificando key...}${RESET}"
K17_KEY_DATA=$(curl -s --max-time 10 "https://${K17_FB_BASE}/licencias_movivip/${K17_AUTH_KEY}.json" 2>/dev/null)

if [[ -z "$K17_KEY_DATA" || "$K17_KEY_DATA" == "null" ]]; then
    echo -e "${RED}  ✖ ${KEYGEN_NOT_FOUND_FB:-Key no encontrada en Firebase}${RESET}"
    sleep 2
    exec bash "$BASE/herramientas/menu.sh"
fi

K17_ACTIVA=$(echo "$K17_KEY_DATA" | grep -oP '"activa"\s*:\s*(true|false)' | sed 's/.*:\s*//')
if [[ "$K17_ACTIVA" != "true" ]]; then
    echo -e "${RED}  ✖ ${KEYGEN_INACTIVE:-Key inactiva}${RESET}"
    sleep 2
    exec bash "$BASE/herramientas/menu.sh"
fi

K17_TIPO=$(echo "$K17_KEY_DATA" | grep -oP '"tipo"\s*:\s*"[^"]*"' | sed 's/.*"\(.*\)"/\1/')
if [[ "$K17_TIPO" != "super" && "$K17_TIPO" != "mayorista" ]]; then
    echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${RED}║${RESET}  ${WHITE}⚠️  ${KEYGEN_NO_PERMS:-No tienes permisos para generar keys.}${RESET}               ${RED}║${RESET}"
    echo -e "${RED}║${RESET}  ${GOLD}🚀 ${KEYGEN_BECOME_PROVIDER:-¡Conviértete en PROVEEDOR y genera tus propias keys!}${RESET}  ${RED}║${RESET}"
    echo -e "${RED}║${RESET}  ${CYAN}💬 Telegram :${WHITE} @MoviVIP${RESET}                                  ${RED}║${RESET}"
    echo -e "${RED}║${RESET}  ${CYAN}📱 WhatsApp :${WHITE} +57 311 700 8185${RESET}                         ${RED}║${RESET}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    read -rp "${KEYGEN_PRESS_ENTER:-Presiona Enter para volver...}"
    exec bash "$BASE/herramientas/menu.sh"
fi

echo -e "${GREEN}  ✔ ${KEYGEN_AUTH_OK:-Key autenticada} (tipo: ${K17_TIPO:-cliente})${RESET}"
sleep 1

# ── SUB-MENÚ (solo super/mayorista llegan aqui) ──
while true; do
clear
mv_header "🔑 ${KEYGEN_TITLE:-Generador de Licencias}" "${GREEN}✔ ${KEYGEN_AUTH_AS:-Autenticado como}: ${WHITE}${K17_TIPO}${RESET}" "v6.2"
echo ""
SEL=$(nav_pick "➜ ${KEYGEN_OPTION:-Opción}:" \
    "📦 ${KEYGEN_OPT_INSTALL:-Instalar / reinstalar bot keygen}" \
    "🟢 ${KEYGEN_OPT_START:-Iniciar bot Telegram}" \
    "🔴 ${KEYGEN_OPT_STOP:-Detener bot Telegram}" \
    "📋 ${KEYGEN_OPT_LOGS:-Ver logs bot}" \
    "🆕 ${KEYGEN_OPT_GEN_CLI:-Generar key CLI}" \
    "📊 ${KEYGEN_OPT_LIST:-Ver licencias en Firebase}" \
    "🔗 ${KEYGEN_OPT_LINK:-Link bot} @MovivipKeygen_bot" \
    "↩ ${KEYGEN_OPT_BACK} ($(trx 'Volver a Herramientas'))")

case "$SEL" in
    1)
        SETUP_SCRIPT="/etc/movivip/herramientas/setup-bot-generador.sh"
        if [[ -f "$SETUP_SCRIPT" ]]; then
            bash "$SETUP_SCRIPT"
        else
            echo -e "${RED}  ❌ ${MSG_INSTALL_BOT_NOT_FOUND:-No se encontró setup-bot-generador.sh}${RESET}"
            echo -e "${GRAY}  ${MSG_RUN_UPDATER:-Ejecuta updater.sh para descargar los scripts.}${RESET}"
        fi
        read -rp "$(echo -e "${CYAN}➜ ${MSG_ENTER_CONT:-ENTER para continuar}${RESET}")"
        ;;
    2)
        systemctl start movivip-bot-generador
        echo -e "${GREEN}${MSG_BOT_STARTED:-✔ Bot iniciado}${RESET}"
        sleep 2
        ;;
    3)
        systemctl stop movivip-bot-generador
        echo -e "${RED}${MSG_BOT_STOPPED:-✖ Bot detenido}${RESET}"
        sleep 2
        ;;
    4)
        journalctl -u movivip-bot-generador -n 30 --no-pager
        echo ""
        read -rp "${MSG_PRESS_ENTER_BACK:-Presiona Enter para volver...}"
        ;;
    5)
        # ================= GENERAR KEY CLI =================
        clear
        echo -e "${CYAN}  ${KEYGEN_GEN_TITLE:-Generar KEY de licencia}${RESET}"
        echo -e "${CYAN}  ${GREEN}✔ ${KEYGEN_AUTH_AS:-Autenticado}: ${WHITE}${K17_TIPO}${RESET} — key: ${WHITE}${K17_AUTH_KEY}${RESET}"
        echo ""

        echo -e "${CYAN}  ${KEYGEN_CLIENT_NAME:-Nombre del cliente (o 'anonimo'):}${RESET}"
        read -rp "  > " CLI_CLIENTE
        [[ -z "$CLI_CLIENTE" ]] && CLI_CLIENTE="anonimo"

        echo ""
        echo -e "${CYAN}  ${MSG_SEL_PLAN:-Selecciona el plan:}${RESET}"
        echo -e "    ${GOLD}[1]${WHITE} ${MSG_PLAN_BRONCE:-BRONCE}    — S/10${RESET}"
        echo -e "    ${GOLD}[2]${WHITE} ${MSG_PLAN_PREMIUM:-PREMIUM}   — S/20${RESET}"
        echo -e "    ${GOLD}[3]${WHITE} ${MSG_PLAN_PLATINO:-PLATINO}   — S/35${RESET}"
        echo -e "    ${GOLD}[4]${WHITE} ${MSG_PLAN_VITALICIO:-VITALICIO} — S/60${RESET}"
        echo ""
        read -rp "  Plan [1-4]: " CLI_PLAN_NUM
        CLI_PLAN="premium"; CLI_PRECIO=20
        case "$CLI_PLAN_NUM" in
            1) CLI_PLAN="bronce"; CLI_PRECIO=10 ;;
            2) CLI_PLAN="premium"; CLI_PRECIO=20 ;;
            3) CLI_PLAN="platino"; CLI_PRECIO=35 ;;
            4) CLI_PLAN="vitalicio"; CLI_PRECIO=60 ;;
        esac

        echo ""
        echo -e "${CYAN}  ${KEYGEN_DAYS_VALIDITY:-Dias de validez:}${RESET}"
        if [[ "$CLI_PLAN" == "vitalicio" ]]; then
            echo -e "  ${GRAY}  (${KEYGEN_VITALICIO_HINT:-Vitalicio = 36500 dias})${RESET}"
            CLI_DIAS=36500
        else
            echo -e "  ${GRAY}  (${KEYGEN_DAYS_DEFAULT:-default: 30})${RESET}"
            read -rp "  ${KEYGEN_DAYS:-Dias:} " CLI_DIAS
            [[ -z "$CLI_DIAS" || ! "$CLI_DIAS" =~ ^[0-9]+$ ]] && CLI_DIAS=30
        fi

        echo ""
        echo -e "${CYAN}  ${KEYGEN_GENERATING:-Generando key...}${RESET}"
        NEW_KEY="KEY-$(openssl rand -hex 5 | tr '[:lower:]' '[:upper:]')"
        AHORA=$(date +%s)
        if [[ "$CLI_PLAN" == "vitalicio" ]]; then
            EXPIRA=0
        else
            EXPIRA=$((AHORA + CLI_DIAS * 86400))
        fi

        source /etc/movivip/.env-bot 2>/dev/null
        AUTH_URL="https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${FB_API_KEY:-}"
        AUTH_RESP=$(curl -s --max-time 15 -X POST "$AUTH_URL" \
            -H "Content-Type: application/json" \
            -d "{\"email\":\"${FB_AUTH_EMAIL:-}\",\"password\":\"${FB_AUTH_PASS:-}\",\"returnSecureToken\":true}" 2>/dev/null)
        FB_TOKEN=$(echo "$AUTH_RESP" | grep -oP '"idToken"\s*:\s*"([^"]*)"' | sed 's/.*"\(.*\)"/\1/')

        if [[ -z "$FB_TOKEN" ]]; then
            echo -e "${RED}  ${ERR_FIREBASE_AUTH:-✖ Error de autenticacion Firebase}${RESET}"
            echo -e "${GRAY}  ${MSG_FIREBASE_VERIFY:-Verifica /etc/movivip/.env-bot}${RESET}"
            sleep 3
            exec bash "$BASE/herramientas/menu.sh"
        fi

        KEY_BODY="{\"activa\":true,\"creada\":$AHORA,\"expira\":$EXPIRA,\"cliente\":\"$CLI_CLIENTE\",\"plan\":\"$CLI_PLAN\",\"precio\":$CLI_PRECIO,\"generada_por\":\"$K17_AUTH_KEY\"}"
        RESP=$(curl -s --max-time 20 -X PUT \
            "https://${K17_FB_BASE}/licencias_movivip/${NEW_KEY}.json?auth=$FB_TOKEN" \
            -H "Content-Type: application/json" \
            -d "$KEY_BODY" 2>/dev/null)

        if [[ -n "$RESP" ]]; then
            echo ""
            echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${RESET}"
            echo -e "${GREEN}║${RESET}         ${GOLD}${KEYGEN_SUCCESS:-✅ KEY GENERADA EXITOSAMENTE}${RESET}                          ${GREEN}║${RESET}"
            echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${RESET}"
            echo -e "${GREEN}║${RESET}  🔑 Key: ${WHITE}${NEW_KEY}${RESET}                                        ${GREEN}║${RESET}"
            echo -e "${GREEN}║${RESET}  👤 ${KEYGEN_CLIENT_LBL:-Cliente:} ${WHITE}${CLI_CLIENTE}${RESET}                                     ${GREEN}║${RESET}"
            echo -e "${GREEN}║${RESET}  💎 ${KEYGEN_PLAN_LBL:-Plan:} ${WHITE}${CLI_PLAN} (S/${CLI_PRECIO})${RESET}                            ${GREEN}║${RESET}"
            echo -e "${GREEN}║${RESET}  📅 ${KEYGEN_DAYS_LBL:-Dias:} ${WHITE}${CLI_DIAS}${RESET}                                            ${GREEN}║${RESET}"
            echo -e "${GREEN}║${RESET}  🏷️ ${KEYGEN_GEN_BY:-Generada por:} ${WHITE}${K17_AUTH_KEY}${RESET}                          ${GREEN}║${RESET}"
            echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${RESET}"
        else
            echo -e "${RED}  ${MSG_FIREBASE_ERR:-✖ Error al subir a Firebase}${RESET}"
        fi
        echo ""
        read -rp "${MSG_PRESS_ENTER_BACK:-Presiona Enter para volver...}"
        ;;
    6)
        clear
        echo -e "${CYAN}  ${MSG_FIREBASE_LIST:-Licencias en Firebase:}${RESET}"
        echo ""
        curl -s "https://movivip-network-default-rtdb.firebaseio.com/licencias_movivip.json" 2>/dev/null | python3 -m json.tool 2>/dev/null || \
        curl -s "https://movivip-network-default-rtdb.firebaseio.com/licencias_movivip.json" 2>/dev/null
        echo ""
        read -rp "${MSG_PRESS_ENTER_BACK:-Presiona Enter para volver...}"
        ;;
    7)
        echo -e "${WHITE}Link: https://t.me/MovivipKeygen_bot${RESET}"
        sleep 2
        ;;
    0|*)
        exec bash "$BASE/herramientas/menu.sh"
        ;;
esac
done
