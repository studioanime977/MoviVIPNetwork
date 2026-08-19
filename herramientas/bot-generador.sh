#!/bin/bash
# =============================================================
#  MOVIVIP NETWORK — BOT GENERADOR DE LICENCIAS (Telegram)
#  -------------------------------------------------------------
#  Bot de Telegram que genera keys de licencia para clientes.
#  REQUIERE: autenticacion con key mayorista.
#
#  Este script vive en /etc/movivip/bot-generador.sh
#  Se ejecuta como servicio systemd: movivip-bot-generador
#
#  COMANDOS:
#    /start    - Bienvenida
#    /auth     - Autenticarse con key mayorista
#    /generar  - Generar key de cliente (requiere /auth)
#    /renovar  - Renovar key existente (requiere /auth)
#    /stats    - Ver estadisticas (requiere /auth)
#    /cancel   - Cancelar operacion en curso
#    /help     - Ayuda
#
#  SEGURIDAD:
#    - Credenciales en archivo encriptado (descifrar-secrets.sh)
#    - Solo usuarios autenticados con key mayorista generan keys
#    - Logs de todas las operaciones
# =============================================================

set -euo pipefail

# ================= RUTAS =================
BASE="/etc/movivip"
SECRETS_SCRIPT="$BASE/descifrar-secrets.sh"
LOG_FILE="/var/log/movivip-bot-generador.log"
STATE_DIR="/etc/movivip/.bot-state"
mkdir -p "$STATE_DIR" 2>/dev/null
OFFSET_FILE="$STATE_DIR/offset"
AUTH_FILE="$STATE_DIR/authenticated_users"

# ================= CONFIGURACION DEL BOT =================
# El token del bot se obtiene de los secrets encriptados
# O se puede configurar directamente aqui (menos seguro)
BOT_TOKEN="${MOVIVIP_BOT_TOKEN:-}"
POLL_TIMEOUT=30
MAX_POLL_ATTEMPTS=3

# ================= COLORES (para logs) =================
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'

# ================= LOG =================
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg" >> "$LOG_FILE"
    echo -e "${CYAN}$msg${NC}"
}

log_err() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1"
    echo "$msg" >> "$LOG_FILE"
    echo -e "${RED}$msg${NC}"
}

# ================= TELEGRAM API =================
tg_send() {
    local chat_id="$1"
    local text="$2"
    local parse_mode="${3:-Markdown}"

    curl -s --max-time 15 -X POST \
        "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d "chat_id=$chat_id" \
        -d "text=$text" \
        -d "parse_mode=$parse_mode" \
        -d "disable_web_page_preview=true" \
        >/dev/null 2>&1
}

tg_send_html() {
    local chat_id="$1"
    local text="$2"

    curl -s --max-time 15 -X POST \
        "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d "chat_id=$chat_id" \
        -d "text=$text" \
        -d "parse_mode=HTML" \
        -d "disable_web_page_preview=true" \
        >/dev/null 2>&1
}

tg_answer_callback() {
    local callback_id="$1"
    local text="$2"

    curl -s --max-time 15 -X POST \
        "https://api.telegram.org/bot${BOT_TOKEN}/answerCallbackQuery" \
        -d "callback_query_id=$callback_id" \
        -d "text=$text" \
        >/dev/null 2>&1
}

# ================= FIREBASE =================
fb_get() {
    local path="$1"
    local url="https://${FB_BASE}/${path}.json"
    curl -s --max-time 12 "$url" 2>/dev/null
}

fb_put() {
    local path="$1"
    local data="$2"
    local token="$3"
    local url="https://${FB_BASE}/${path}.json?auth=$token"

    curl -s --max-time 20 -X PUT "$url" \
        -H "Content-Type: application/json" \
        -d "$data" 2>/dev/null
}

fb_auth_token() {
    if [[ -z "${FB_API_KEY:-}" || -z "${FB_AUTH_EMAIL:-}" || -z "${FB_AUTH_PASS:-}" ]]; then
        log_err "Faltan variables FB_API_KEY, FB_AUTH_EMAIL, FB_AUTH_PASS"
        return 1
    fi

    local auth_url="https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$FB_API_KEY"
    local auth_resp
    auth_resp=$(curl -s --max-time 15 -X POST "$auth_url" \
        -H "Content-Type: application/json" \
        -d "{\"email\":\"$FB_AUTH_EMAIL\",\"password\":\"$FB_AUTH_PASS\",\"returnSecureToken\":true}" 2>/dev/null)

    local id_token
    id_token=$(echo "$auth_resp" | grep -oP '"idToken"\s*:\s*"([^"]*)"' | sed 's/.*"\(.*\)"/\1/')

    if [[ -z "$id_token" ]]; then
        log_err "Firebase Auth no devolvio token"
        return 1
    fi

    echo "$id_token"
    return 0
}

# ================= VERIFICAR KEY MAYORISTA =================
verificar_mayorista() {
    local key="$1"
    local resp
    resp=$(fb_get "licencias_movivip/$key")

    if [[ -z "$resp" || "$resp" == "null" ]]; then
        return 1
    fi

    local activa
    activa=$(echo "$resp" | grep -oP '"activa"\s*:\s*(true|false)' | sed 's/.*:\s*//')
    [[ "$activa" == "true" ]] && return 0
    return 1
}

# ================= GENERAR KEY DE LICENCIA =================
generar_licencia() {
    local key_mayorista="$1"
    local cliente="$2"
    local plan="$3"
    local dias="$4"

    # Generar KEY-XXXXXXXXXX
    local hex=$(openssl rand -hex 5 | tr '[:lower:]' '[:upper:]')
    local key="KEY-$hex"

    # Calcular expiracion
    local ahora=$(date +%s)
    local expira=0
    if [[ "$plan" != "vitalicio" ]]; then
        expira=$((ahora + dias * 86400))
    fi

    # Precio
    local precio=0
    case "$plan" in
        bronce)    precio=${PRECIO_BRONCE:-10} ;;
        premium)   precio=${PRECIO_PREMIUM:-20} ;;
        platino)   precio=${PRECIO_PLATINO:-35} ;;
        vitalicio) precio=${PRECIO_VITALICIO:-60} ;;
        mayorista) precio=${PRECIO_MAYORISTA:-100} ;;
    esac

    # Auth token
    local token=$(fb_auth_token)
    if [[ $? -ne 0 ]]; then
        echo "ERROR: No se pudo autenticar en Firebase"
        return 1
    fi

    # Subir a Firebase
    local body="{\"activa\":true,\"creada\":$ahora,\"expira\":$expira,\"cliente\":\"$cliente\",\"plan\":\"$plan\",\"precio\":$precio,\"generada_por\":\"$key_mayorista\"}"
    local resp=$(fb_put "licencias_movivip/$key" "$body" "$token")

    if [[ -z "$resp" ]]; then
        echo "ERROR: Fallo al subir a Firebase"
        return 1
    fi

    # Registrar uso del maestro
    local fecha=$(date '+%Y-%m-%d')
    local uso_body="{\"fecha\":\"$fecha\",\"key_generada\":\"$key\",\"cliente\":\"$cliente\",\"plan\":\"$plan\"}"
    fb_put "usos_maestros/$key_mayorista/$fecha/$key" "$uso_body" "$token" >/dev/null 2>&1

    # Incrementar contador
    local total_actual
    total_actual=$(fb_get "licencias_movivip/$key_mayorista/total_generadas" | grep -oP '\d+' || echo "0")
    local nuevo_total=$((total_actual + 1))
    fb_put "licencias_movivip/$key_mayorista/total_generadas" "$nuevo_total" "$token" >/dev/null 2>&1

    echo "$key"
    return 0
}

# ================= RENOVAR KEY =================
renovar_licencia() {
    local key="$1"
    local dias="${2:-30}"

    # Verificar que la key existe
    local resp
    resp=$(fb_get "licencias_movivip/$key")

    if [[ -z "$resp" || "$resp" == "null" ]]; then
        echo "ERROR: La key '$key' no existe"
        return 1
    fi

    local ahora=$(date +%s)
    local expira_actual
    expira_actual=$(echo "$resp" | grep -oP '"expira"\s*:\s*(\d+)' | sed 's/.*:\s*//')

    # Calcular nueva expiracion
    local nueva_expira
    if [[ "$expira_actual" == "0" ]]; then
        nueva_expira=0  # vitalicia se queda vitalicia
    elif [[ "$expira_actual" -gt "$ahora" ]]; then
        # Aun no vence: agregar dias desde ahora
        nueva_expira=$((ahora + dias * 86400))
    else
        # Ya vencio: agregar desde ahora
        nueva_expira=$((ahora + dias * 86400))
    fi

    # Auth token
    local token=$(fb_auth_token)
    if [[ $? -ne 0 ]]; then
        echo "ERROR: No se pudo autenticar en Firebase"
        return 1
    fi

    # Actualizar en Firebase
    local body="{\"expira\":$nueva_expira}"
    local resp=$(fb_put "licencias_movivip/$key" "$body" "$token")

    if [[ -z "$resp" ]]; then
        echo "ERROR: Fallo al actualizar en Firebase"
        return 1
    fi

    echo "OK"
    return 0
}

# ================= ESTADO POR USUARIO =================
declare -A USER_STATE     # estado actual del usuario
declare -A USER_DATA      # datos temporales de la operacion

# Estados:
#   idle        = sin operacion en curso
#   esperando_cliente = pide nombre del cliente
#   esperando_plan    = pide plan
#   esperando_dias    = pide dias
#   esperando_auth    = pide key mayorista

get_state() {
    local user_id="$1"
    echo "${USER_STATE[$user_id]:-idle}"
}

set_state() {
    local user_id="$1"
    local state="$2"
    USER_STATE[$user_id]="$state"
}

get_data() {
    local user_id="$1"
    local key="$2"
    echo "${USER_DATA[$user_id]:-$key:}"
}

set_data() {
    local user_id="$1"
    local key="$2"
    local value="$3"
    USER_DATA[$user_id]="$key:$value"
}

clear_user() {
    local user_id="$1"
    unset USER_STATE[$user_id]
    unset USER_DATA[$user_id]
}

# ================= MANEJAR MENSAJES =================
handle_message() {
    local chat_id="$1"
    local user_id="$2"
    local username="$3"
    local text="$4"
    local state=$(get_state "$user_id")

    log "Mensaje de @$username ($user_id): $text"

    # ---- COMANDOS GLOBALES (siempre disponibles) ----
    case "$text" in
        /start)
            tg_send_html "$chat_id" "
<b>🔑 MoviVIP — Generador de Licencias</b>

<b>Bienvenido, vendedor.</b>

<b>Comandos:</b>
/auth KEY — Autenticarte como vendedor
/generar — Generar key de cliente
/renovar KEY — Renovar key existente
/stats — Ver estadisticas
/cancel — Cancelar operacion
/help — Ayuda

<b>Primer paso:</b> /auth TU_KEY_MAYORISTA"
            clear_user "$user_id"
            return
            ;;
        /help)
            tg_send_html "$chat_id" "
<b>📋 Comandos disponibles:</b>

<b>🔑 /auth KEY</b> — Autenticarte con tu key mayorista
<b>🆕 /generar</b> — Generar una key de licencia para un cliente
<b>🔄 /renovar KEY</b> — Renovar una key existente (agrega 30 dias)
<b>📊 /stats</b> — Ver cuantas keys generaste
<b>❌ /cancel</b> — Cancelar la operacion actual

<b>Flujo /generar:</b>
1. /generar
2. Nombre del cliente
3. Plan (bronce/premium/platino/vitalicio)
4. Dias de validez
5. ¡Key generada!

<b>Solo puedes generar si estas autenticado con /auth</b>"
            return
            ;;
        /cancel)
            clear_user "$user_id"
            tg_send "$chat_id" "✅ Operacion cancelada."
            return
            ;;
    esac

    # ---- VERIFICAR AUTENTICACION ----
    local is_auth=false
    if [[ -f "$AUTH_FILE" ]]; then
        grep -q "^${user_id}$" "$AUTH_FILE" 2>/dev/null && is_auth=true
    fi

    if [[ "$is_auth" == "false" && "$state" != "esperando_auth" ]]; then
        tg_send_html "$chat_id" "
<b>⛔ No autenticado.</b>

Usa <code>/auth TU_KEY_MAYORISTA</code> para autenticarte.

Sin autenticacion no puedes generar keys."
        return
    fi

    # ---- COMANDOS REQUIEREN AUTH ----
    case "$text" in
        /generar)
            if [[ "$is_auth" == "false" ]]; then
                tg_send "$chat_id" "⛔ Primero autenticame con /auth TU_KEY_MAYORISTA"
                return
            fi
            set_state "$user_id" "esperando_cliente"
            set_data "$user_id" "step" "cliente"
            tg_send "$chat_id" "📝 Nombre del cliente (o 'anonimo'):"
            return
            ;;
        /stats)
            if [[ "$is_auth" == "false" ]]; then
                tg_send "$chat_id" "⛔ Primero autenticame con /auth TU_KEY_MAYORISTA"
                return
            fi
            # Obtener stats del maestro
            local fecha=$(date '+%Y-%m-%d')
            local total_hoy=$(fb_get "usos_maestros/$AUTH_KEY/$fecha" | grep -c "key_generada" || echo "0")
            local total_general=$(fb_get "licencias_movivip/$AUTH_KEY/total_generadas" | grep -oP '\d+' || echo "0")

            tg_send_html "$chat_id" "
<b>📊 Tus estadisticas:</b>

🔑 Keys generadas hoy: <b>$total_hoy</b>
📈 Total general: <b>$total_general</b>
👤 Vendedor: <b>@$username</b>"
            return
            ;;
    esac

    # ---- RENOVAR ----
    if [[ "$text" =~ ^/renovar ]]; then
        if [[ "$is_auth" == "false" ]]; then
            tg_send "$chat_id" "⛔ Primero autenticame con /auth TU_KEY_MAYORISTA"
            return
        fi
        local key_renovar=$(echo "$text" | awk '{print $2}')
        if [[ -z "$key_renovar" ]]; then
            tg_send "$chat_id" "Uso: /renovar KEY-XXXXXXXXXX"
            return
        fi
        tg_send "$chat_id" "🔄 Renovando $key_renovar (+30 dias)..."
        local resultado=$(renovar_licencia "$key_renovar" 30)
        if [[ "$resultado" == "OK" ]]; then
            tg_send "$chat_id" "✅ Key $key_renovar renovada (+30 dias)"
        else
            tg_send "$chat_id" "❌ $resultado"
        fi
        return
    fi

    # ---- AUTENTICACION ----
    if [[ "$text" =~ ^/auth ]]; then
        local key_auth=$(echo "$text" | awk '{print $2}')
        if [[ -z "$key_auth" ]]; then
            tg_send "$chat_id" "Uso: /auth TU_KEY_MAYORISTA"
            return
        fi

        tg_send "$chat_id" "🔍 Verificando key mayorista..."
        if verificar_mayorista "$key_auth"; then
            # Guardar autenticacion
            mkdir -p "$STATE_DIR"
            echo "$user_id" >> "$AUTH_FILE"
            AUTH_KEY="$key_auth"
            clear_user "$user_id"
            tg_send_html "$chat_id" "
<b>✅ Autenticado correctamente!</b>

🔑 Key mayorista: <code>$key_auth</code>

Ahora puedes usar:
<b>/generar</b> — Generar key de cliente
<b>/renovar KEY</b> — Renovar key
<b>/stats</b> — Ver estadisticas"
        else
            tg_send_html "$chat_id" "
<b>❌ Key mayorista no valida.</b>

Verifica que:
1. La key existe en Firebase
2. Esta marcada como activa
3. La escribiste correctamente"
        fi
        return
    fi

    # ---- FLUJO INTERACTIVO DE GENERACION ----
    case "$state" in
        esperando_cliente)
            set_data "$user_id" "cliente" "$text"
            set_state "$user_id" "esperando_plan"
            tg_send_html "$chat_id" "
<b>📋 Plan para:</b> $text

<b>Planes disponibles:</b>
[1] BRONCE — S/10 — Solo script
[2] PREMIUM — S/20 — Script + Bot
[3] PLATINO — S/35 — Script + Bot + Soporte
[4] VITALICIO — S/60 — De por vida

<b>Escribe el numero o nombre del plan:</b>"
            return
            ;;
        esperando_plan)
            local plan_input=$(echo "${text,,}" | tr -d ' ')
            local plan=""

            case "$plan_input" in
                1|bronce)    plan="bronce" ;;
                2|premium)   plan="premium" ;;
                3|platino)   plan="platino" ;;
                4|vitalicio) plan="vitalicio" ;;
                *)
                    tg_send "$chat_id" "❌ Plan no valido. Escribe 1-4 o el nombre."
                    return
                    ;;
            esac

            set_data "$user_id" "plan" "$plan"
            set_state "$user_id" "esperando_dias"

            local precio=0
            case "$plan" in
                bronce)    precio=${PRECIO_BRONCE:-10} ;;
                premium)   precio=${PRECIO_PREMIUM:-20} ;;
                platino)   precio=${PRECIO_PLATINO:-35} ;;
                vitalicio) precio=${PRECIO_VITALICIO:-60} ;;
            esac

            local dias_sugeridos=30
            [[ "$plan" == "vitalicio" ]] && dias_sugeridos=36500

            tg_send_html "$chat_id" "
<b>📅 Dias de validez:</b>

Plan: <b>$plan</b> — Precio: <b>S/$precio</b>
Dias sugeridos: <b>$dias_sugeridos</b>

<b>Escribe los dias (default $dias_sugeridos):</b>"
            return
            ;;
        esperando_dias)
            local dias="${text:-30}"
            [[ ! "$dias" =~ ^[0-9]+$ ]] && dias=30

            local cliente=$(get_data "$user_id" "cliente")
            local plan=$(get_data "$user_id" "plan")

            tg_send "$chat_id" "⏳ Generando key..."

            local key_resultado=$(generar_licencia "$AUTH_KEY" "$cliente" "$plan" "$dias")

            if [[ "$key_resultado" =~ ^KEY- ]]; then
                tg_send_html "$chat_id" "
<b>✅ KEY GENERADA EXITOSAMENTE!</b>

🔑 <code>$key_resultado</code>

📋 Cliente: <b>$cliente</b>
💎 Plan: <b>$plan</b>
📅 Validez: <b>$dias dias</b>

<i>Entrega esta key al cliente.</i>"
            else
                tg_send_html "$chat_id" "
<b>❌ Error al generar:</b>
<code>$key_resultado</code>

Intenta de nuevo con /generar"
            fi

            clear_user "$user_id"
            return
            ;;
    esac

    # Si no matchea nada
    tg_send "$chat_id" "❓ No entendi. Usa /help para ver los comandos."
}

# ================= MAIN LOOP =================
main() {
    log "Bot generador de licencias iniciado"

    # Cargar secrets
    if [[ -f "$SECRETS_SCRIPT" ]]; then
        source "$SECRETS_SCRIPT"
        descifrar_secrets 2>/dev/null
        log "Secrets descifrados"
    else
        log_err "Script de secrets no encontrado: $SECRETS_SCRIPT"
        exit 1
    fi

    # Verificar token del bot
    if [[ -z "$BOT_TOKEN" ]]; then
        log_err "MOVIVIP_BOT_TOKEN no configurado"
        log_err "Configura la variable de entorno o el token en el servicio systemd"
        exit 1
    fi

    # Verificar que tenemos credenciales Firebase
    if [[ -z "${FB_API_KEY:-}" || -z "${FB_AUTH_EMAIL:-}" ]]; then
        log_err "Faltan credenciales Firebase (FB_API_KEY, FB_AUTH_EMAIL)"
        exit 1
    fi

    # Crear directorio de estado
    mkdir -p "$STATE_DIR"

    log "Iniciando polling (timeout: ${POLL_TIMEOUT}s)..."

    # Loop principal
    while true; do
        # Leer offset actual del archivo (persistente entre iteraciones)
        if [[ -f "$OFFSET_FILE" ]]; then
            OFFSET=$(cat "$OFFSET_FILE")
        else
            OFFSET=0
        fi

        # Obtener mensajes
        local response
        response=$(curl -s --max-time $((POLL_TIMEOUT + 10)) \
            "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates" \
            -d "offset=$OFFSET" \
            -d "timeout=$POLL_TIMEOUT" \
            -d "allowed_updates=[\"message\"]" 2>/dev/null)

        if [[ -z "$response" ]]; then
            log_err "Respuesta vacia de Telegram"
            sleep 2
            continue
        fi

        # Verificar que es valido
        local ok
        ok=$(echo "$response" | grep -oP '"ok"\s*:\s*(true|false)' | sed 's/.*:\s*//')
        if [[ "$ok" != "true" ]]; then
            log_err "Error en respuesta de Telegram: $response"
            sleep 5
            continue
        fi

        # Procesar mensajes — usar python3 para extraer y guardar offset en archivo
        echo "$response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    max_id = -1
    for update in data.get('result', []):
        msg = update.get('message', {})
        if msg:
            user = msg.get('from', {})
            text = msg.get('text', '')
            uid = update['update_id']
            print(f\"{uid}|{msg['chat']['id']}|{user.get('id','')}|{user.get('username','')}|{text}\")
            if uid > max_id:
                max_id = uid
    if max_id >= 0:
        with open('$OFFSET_FILE', 'w') as f:
            f.write(str(max_id + 1))
except:
    pass
" 2>/dev/null | while IFS='|' read -r update_id chat_id user_id username text; do
                handle_message "$chat_id" "$user_id" "$username" "$text"
            done

        # Limpiar secrets temporales periodicamente
        limpiar_secrets 2>/dev/null
    done
}

# ================= TRAP DE LIMPIEZA =================
cleanup() {
    log "Bot detenido (señal recibida)"
    limpiar_secrets 2>/dev/null
    rm -f "$OFFSET_FILE" 2>/dev/null
    rm -f "$AUTH_FILE" 2>/dev/null
    exit 0
}

trap cleanup SIGINT SIGTERM SIGHUP

# ================= EJECUTAR =================
main "$@"
