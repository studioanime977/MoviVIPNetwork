#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════
# MoviVIP Bot Generador de Licencias v3.0-Firebase
# Botones inline, jerarquia super/proveedor/cliente
# Firebase RTDB como store primario (sin SQLite)
# ═══════════════════════════════════════════════════════════
set -uo pipefail

# ================= RUTAS =================
BASE="/etc/movivip"
SECRETS_SCRIPT="$BASE/descifrar-secrets.sh"
LOG_FILE="/var/log/movivip-bot-generador.log"
STATE_DIR="/etc/movivip/.bot-state"
mkdir -p "$STATE_DIR" 2>/dev/null
OFFSET_FILE="$STATE_DIR/offset"
AUTH_FILE="$STATE_DIR/authenticated_users"

# ================= CONFIG =================
# Source .env-bot as fallback if BOT_TOKEN not set by systemd
if [[ -z "${MOVIVIP_BOT_TOKEN:-}" ]]; then
    [[ -f "$BASE/.env-bot" ]] && source "$BASE/.env-bot" 2>/dev/null
fi
BOT_TOKEN="${MOVIVIP_BOT_TOKEN:-}"
POLL_TIMEOUT=30
FB_TOKEN_CACHE=""
FB_TOKEN_EXPIRES=0

# ================= MASTER KEY (v2) =================
# Se lee en tiempo de ejecucion desde el archivo del servidor (600 root)
MASTER_KEY=""
MASTER_KEY_FILE="${MOVIVIP_MASTER_KEY_FILE:-/root/.master_key.b64}"
if [[ -f "$MASTER_KEY_FILE" && -r "$MASTER_KEY_FILE" ]]; then
    MASTER_KEY=$(tr -d '[:space:]' < "$MASTER_KEY_FILE")
fi

# ================= COLORES =================
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'

# ================= LOG =================
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; }
log_err() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERR: $1" >> "$LOG_FILE"; }

# ================= TELEGRAM API =================
tg_send() {
    local chat_id="$1" text="$2" parse="${3:-}"
    local extra=""
    [[ -n "$parse" ]] && extra="&parse_mode=$parse"
    curl -s --max-time 15 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=$chat_id" --data-urlencode "text=$text" \
        -d "disable_web_page_preview=true" \
        ${extra:+-d "parse_mode=$parse"} >/dev/null 2>&1
}

tg_send_html() {
    local chat_id="$1" text="$2"
    curl -s --max-time 15 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=$chat_id" --data-urlencode "text=$text" \
        -d "parse_mode=HTML" \
        -d "disable_web_page_preview=true" >/dev/null 2>&1
}

tg_send_buttons() {
    local chat_id="$1" text="$2" buttons_json="$3"
    local extra=""
    [[ "${4:-}" == "html" ]] && extra="-d parse_mode=HTML"
    local resp
    resp=$(curl -s --max-time 15 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=$chat_id" --data-urlencode "text=$text" \
        --data-urlencode "reply_markup=$buttons_json" \
        -d "disable_web_page_preview=true" \
        $extra 2>&1)
}

tg_edit_buttons() {
    local chat_id="$1" msg_id="$2" text="$3" buttons_json="$4"
    curl -s --max-time 15 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/editMessageText" \
        --data-urlencode "chat_id=$chat_id" -d "message_id=$msg_id" \
        --data-urlencode "text=$text" \
        --data-urlencode "reply_markup=$buttons_json" -d "parse_mode=HTML" \
        -d "disable_web_page_preview=true" >/dev/null 2>&1
}

tg_answer_cb() {
    local cb_id="$1" text="$2"
    curl -s --max-time 10 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/answerCallbackQuery" \
        -d "callback_query_id=$cb_id" -d "text=$text" -d "show_alert=false" >/dev/null 2>&1
}

# ================= FIREBASE RTDB HELPERS =================
fb_get() {
    local path="$1"
    local token="${2:-}"
    if [[ -z "$token" ]]; then
        token=$(fb_auth_token 2>/dev/null) || return 1
    fi
    local base="movivip-network-default-rtdb.firebaseio.com"
    curl -s --max-time 10 "https://$base/$path.json?auth=$token"
}

fb_put() {
    local path="$1" body="$2" token="${3:-}"
    if [[ -z "$token" ]]; then
        token=$(fb_auth_token 2>/dev/null) || return 1
    fi
    local base="movivip-network-default-rtdb.firebaseio.com"
    curl -s --max-time 10 -X PUT "https://$base/$path.json?auth=$token" \
        -H "Content-Type: application/json" -d "$body"
}

fb_delete() {
    local path="$1" token="${2:-}"
    if [[ -z "$token" ]]; then
        token=$(fb_auth_token 2>/dev/null) || return 1
    fi
    local base="movivip-network-default-rtdb.firebaseio.com"
    curl -s --max-time 10 -X DELETE "https://$base/$path.json?auth=$token"
}

fb_patch() {
    local path="$1" body="$2" token="${3:-}"
    if [[ -z "$token" ]]; then
        token=$(fb_auth_token 2>/dev/null) || return 1
    fi
    local base="movivip-network-default-rtdb.firebaseio.com"
    curl -s --max-time 10 -X PATCH "https://$base/$path.json?auth=$token" \
        -H "Content-Type: application/json" -d "$body"
}

# ================= KEY OPERATIONS (Firebase) =================
insertar_key() {
    local key="$1" tipo="${2:-cliente}" plan="${3:-premium}" activa="${4:-1}"
    local creada="${5:-$(date +%s)}" expira="${6:-0}" cliente="${7:-}"
    local gen_por="${8:-}" tg_id="${9:-}" max_gen="${10:-0}"
    # Get existing generadas_count if key already exists
    local existing_count="0"
    local existing
    existing=$(fb_get "licencias/$key" 2>/dev/null)
    if [[ -n "$existing" && "$existing" != "null" ]]; then
        existing_count=$(echo "$existing" | python3 -c "import sys,json; print(json.load(sys.stdin).get('generadas_count',0))" 2>/dev/null)
        [[ -z "$existing_count" ]] && existing_count="0"
    fi
    local body
    # key_real: la key visible/entregable (para v2 el path es url-safe pero la key mostrada es la real)
    local key_real="${11:-$key}"
    body=$(python3 -c "
import json
d = {
    'key': '$key_real',
    'tipo': '$tipo',
    'plan': '$plan',
    'activa': True if '$activa' == '1' else False,
    'creada': $creada,
    'expira': $expira,
    'cliente': '$cliente',
    'generada_por': '$gen_por',
    'telegram_id': '$tg_id',
    'max_generadas': $max_gen,
    'generadas_count': $existing_count
}
print(json.dumps(d))
")
    fb_put "licencias/$key" "$body" >/dev/null 2>&1
}

obtener_key_info() {
    local key="$1"
    local result
    result=$(fb_get "licencias/$key" 2>/dev/null)
    if [[ -z "$result" || "$result" == "null" ]]; then
        echo "{}"
        return
    fi
    echo "$result"
}

verificar_key() {
    local key="$1"
    local json_data
    json_data=$(fb_get "licencias/$key" 2>/dev/null)
    if [[ -z "$json_data" || "$json_data" == "null" ]]; then
        return
    fi
    python3 -c "
import sys, json
try:
    d = json.loads('''$json_data''')
    activa = 1 if d.get('activa') else 0
    tipo = d.get('tipo','')
    expira = d.get('expira',0)
    count = d.get('generadas_count',0)
    maxg = d.get('max_generadas',0)
    print(f'{activa}|{tipo}|{expira}|{count}|{maxg}')
except: pass
" 2>/dev/null
}

obtener_tipo_user() {
    local user_id="$1"
    local auth_key
    auth_key=$(get_auth_key "$user_id")
    [[ -z "$auth_key" ]] && return
    local json_data
    json_data=$(fb_get "licencias/$auth_key" 2>/dev/null)
    if [[ -z "$json_data" || "$json_data" == "null" ]]; then
        return
    fi
    python3 -c "
import sys, json
try:
    d = json.loads('''$json_data''')
    print(d.get('tipo',''))
except: pass
" 2>/dev/null
}

obtener_telegram_id() {
    local user_id="$1"
    local auth_key
    auth_key=$(get_auth_key "$user_id")
    [[ -z "$auth_key" ]] && return
    local json_data
    json_data=$(fb_get "licencias/$auth_key" 2>/dev/null)
    if [[ -z "$json_data" || "$json_data" == "null" ]]; then
        return
    fi
    python3 -c "
import sys, json
try:
    d = json.loads('''$json_data''')
    print(d.get('telegram_id',''))
except: pass
" 2>/dev/null
}

incrementar_contador() {
    local key="$1"
    local json_data
    json_data=$(fb_get "licencias/$key" 2>/dev/null)
    if [[ -z "$json_data" || "$json_data" == "null" ]]; then
        return
    fi
    python3 -c "
import sys, json
try:
    d = json.loads('''$json_data''')
    d['generadas_count'] = d.get('generadas_count',0) + 1
    print(json.dumps({'generadas_count': d['generadas_count']}))
except: pass
" 2>/dev/null | while IFS= read -r patch_body; do
        fb_patch "licencias/$key" "$patch_body" >/dev/null 2>&1
    done
}

eliminar_key() {
    local key="$1"
    fb_delete "licencias/$key" >/dev/null 2>&1
}

contar_keys() {
    local json_data
    json_data=$(fb_get "licencias" 2>/dev/null)
    if [[ -z "$json_data" || "$json_data" == "null" ]]; then
        echo "0"
        return
    fi
    python3 -c "
import sys, json
try:
    d = json.loads('''$(echo "$json_data" | tr "'" "'")''')
    print(len(d) if isinstance(d, dict) else 0)
except: print(0)
" 2>/dev/null
}

contar_keys_activas() {
    local json_data
    json_data=$(fb_get "licencias" 2>/dev/null)
    if [[ -z "$json_data" || "$json_data" == "null" ]]; then
        echo "0"
        return
    fi
    python3 << 'PYEOF'
import sys, json
try:
    raw = sys.stdin.read()
    d = json.loads(raw) if raw.strip() else {}
    count = sum(1 for v in d.values() if isinstance(v, dict) and v.get('activa'))
    print(count)
except: print(0)
PYEOF
    <<< "$json_data"
}

contar_mis_keys() {
    local auth_key="$1"
    local json_data
    json_data=$(fb_get "licencias" 2>/dev/null)
    if [[ -z "$json_data" || "$json_data" == "null" ]]; then
        echo "0"
        return
    fi
    python3 -c "
import sys, json
try:
    raw = sys.stdin.read()
    d = json.loads(raw) if raw.strip() else {}
    count = sum(1 for v in d.values() if isinstance(v, dict) and v.get('generada_por') == '$auth_key')
    print(count)
except: print(0)
" <<< "$json_data" 2>/dev/null
}

# ================= AUTH SYSTEM =================
declare -A AUTH_KEYS  # user_id -> key_auth

get_auth_key() {
    local user_id="$1"
    if [[ -f "$AUTH_FILE" ]]; then
        grep "^${user_id}|" "$AUTH_FILE" 2>/dev/null | cut -d'|' -f2
    fi
}

set_auth_key() {
    local user_id="$1" key="$2"
    mkdir -p "$STATE_DIR"
    # Remove old entry
    if [[ -f "$AUTH_FILE" ]]; then
        grep -v "^${user_id}|" "$AUTH_FILE" > "${AUTH_FILE}.tmp" 2>/dev/null
        mv "${AUTH_FILE}.tmp" "$AUTH_FILE" 2>/dev/null
    fi
    echo "${user_id}|${key}" >> "$AUTH_FILE"
}

clear_auth_key() {
    local user_id="$1"
    if [[ -f "$AUTH_FILE" ]]; then
        grep -v "^${user_id}|" "$AUTH_FILE" > "${AUTH_FILE}.tmp" 2>/dev/null
        mv "${AUTH_FILE}.tmp" "$AUTH_FILE" 2>/dev/null
    fi
}

is_authenticated() {
    local user_id="$1"
    [[ -n "$(get_auth_key "$user_id")" ]] && return 0
    return 1
}

# ================= STATE MACHINE =================
declare -A USER_STATE
declare -A USER_DATA

get_state() { echo "${USER_STATE[$1]:-idle}"; }
set_state() { USER_STATE[$1]="$2"; }
get_data() { echo "${USER_DATA[$1]:-$2:}"; }
set_data() { USER_DATA[$1]="$2:$3"; }
clear_user() { unset USER_STATE[$1]; unset USER_DATA[$1]; }

# ================= KEYBOARD BUILDER =================
kb_inline() {
    # Returns: {"inline_keyboard": [[buttons...],...]}
    local rows=()
    for arg in "$@"; do
        local row_json="["
        IFS=',' read -ra buttons <<< "${arg#*:}"
        local first=true
        for btn in "${buttons[@]}"; do
            local label="${btn%%|*}"
            local data="${btn#*|}"
            $first || row_json+=","
            row_json+="{\"text\":\"$label\",\"callback_data\":\"$data\"}"
            first=false
        done
        row_json+="]"
        rows+=("$row_json")
    done
    local inner="["
    local first=true
    for row in "${rows[@]}"; do
        $first || inner+=","
        inner+="$row"
        first=false
    done
    inner+="]"
    echo "{\"inline_keyboard\":$inner}"
}

# ================= MAIN HANDLER =================
handle_message() {
    local chat_id="$1" user_id="$2" username="$3" text="$4"
    local state=$(get_state "$user_id")

    log "MSG @$username($user_id): $text"

    # ═══ COMANDOS GLOBALES (siempre disponibles) ═══
    case "$text" in
        /start|/menu)
            local kb
            kb=$(kb_inline \
                "🔑 Autenticar|/auth_menu" \
                "❓ Ayuda|/help")
            tg_send_buttons "$chat_id" "👑 <b>MoviVIP Network</b> — Generador de Licencias

<b>Bienvenido, $username.</b>

Selecciona una opcion:" "$kb" "html"
            clear_user "$user_id"
            return
            ;;

        /help)
            tg_send_html "$chat_id" "
<b>📋 Comandos disponibles:</b>

🔑 <b>/auth KEY</b> — Autenticarte con tu key
🆕 <b>/generar</b> — Generar key de licencia
🔄 <b>/renovar KEY</b> — Renovar key (+30 dias)
📊 <b>/stats</b> — Ver estadisticas
📋 <b>/keys</b> — Ver todas las keys
🗑 <b>/delete KEY</b> — Eliminar una key
🚪 <b>/cerrar</b> — Cerrar sesion
❌ <b>/cancel</b> — Cancelar operacion actual"
            return
            ;;

        /cancel)
            clear_user "$user_id"
            local kb
            kb=$(kb_inline "🏠 Menu|/menu")
            tg_send_buttons "$chat_id" "✅ Operacion cancelada." "$kb"
            return
            ;;

        /cerrar|/logout)
            clear_auth_key "$user_id"
            clear_user "$user_id"
            local kb
            kb=$(kb_inline "🔑 Reautenticar|/auth_menu")
            tg_send_buttons "$chat_id" "🚪 Sesion cerrada. Hasta luego, $username." "$kb"
            return
            ;;

        /auth_menu)
            tg_send "$chat_id" "🔑 Envia: /auth TU_KEY"
            return
            ;;
    esac

    # ═══ AUTH CHECK ═══
    local auth_key=$(get_auth_key "$user_id")

    if [[ "$text" != /auth* && "$state" != "esperando_auth" ]]; then
        if [[ -z "$auth_key" ]]; then
            local kb
            kb=$(kb_inline "🔑 Autenticar|/auth_menu")
            tg_send_buttons "$chat_id" "⛔ <b>No autenticado.</b>

Envia /auth TU_KEY para acceder." "$kb" "html"
            return
        fi
    fi

    # ═══ COMANDOS CON AUTH ═══
    case "$text" in
        /generar)
            if [[ -z "$auth_key" ]]; then
                tg_send "$chat_id" "⛔ Primero autenticame con /auth TU_KEY"
                return
            fi
            local user_tipo=$(obtener_tipo_user "$user_id")
            
            if [[ "$user_tipo" == "super" ]]; then
                # Super admin elige: proveedor o cliente
                local kb
                kb=$(kb_inline \
                    "👤 Generar para Proveedor|/gen_proveedor" \
                    "👤 Generar para Cliente|/gen_cliente" \
                    "❌ Cancelar|/cancel")
                tg_send_buttons "$chat_id" "🆕 <b>Tipo de key a generar:</b>" "$kb" "html"
            else
                # Proveedor solo genera clientes
                _iniciar_flujo_cliente "$chat_id" "$user_id"
            fi
            return
            ;;

        /gen_proveedor)
            if [[ -z "$auth_key" ]]; then return; fi
            local user_tipo=$(obtener_tipo_user "$user_id")
            if [[ "$user_tipo" != "super" ]]; then
                tg_send "$chat_id" "⛔ Solo Super Admin puede generar proveedores."
                return
            fi
            set_state "$user_id" "esperando_tg_id_proveedor"
            tg_send "$chat_id" "📱 Envia el <b>Telegram ID</b> del nuevo proveedor:"
            return
            ;;

        /gen_cliente)
            if [[ -z "$auth_key" ]]; then return; fi
            _iniciar_flujo_cliente "$chat_id" "$user_id"
            return
            ;;

        /stats)
            if [[ -z "$auth_key" ]]; then return; fi
            local total=$(contar_keys)
            local activas=$(contar_keys_activas)
            local user_tipo=$(obtener_tipo_user "$user_id")
            local mis_keys
            mis_keys=$(contar_mis_keys "$auth_key")

            tg_send_html "$chat_id" "
<b>📊 Estadisticas:</b>

👤 Tipo: <b>$user_tipo</b>
🔑 Key: <code>$auth_key</code>

📈 Keys que generaste: <b>${mis_keys:-0}</b>
📊 Total keys en DB: <b>$total</b>
✅ Keys activas: <b>$activas</b>"
            return
            ;;

        /keys)
            if [[ -z "$auth_key" ]]; then return; fi
            _mostrar_keys "$chat_id" "$user_id" 0
            return
            ;;
    esac

    # ═══ DELETE KEY ═══
    if [[ "$text" =~ ^/delete ]]; then
        if [[ -z "$auth_key" ]]; then return; fi
        local key_del=$(echo "$text" | awk '{print $2}')
        if [[ -z "$key_del" ]]; then
            tg_send "$chat_id" "Uso: /delete KEY-XXXXXXXXXX (o key v2)"
            return
        fi
        # Path Firebase url-safe (las v2 contienen + /)
        key_del=$(echo "$key_del" | tr '+/' '-_')
        # No delete super admin keys
        local tipo_key
        tipo_key=$(obtener_tipo_user "$user_id" 2>/dev/null)
        # Check if the key to delete is super
        local key_info
        key_info=$(fb_get "licencias/$key_del" 2>/dev/null)
        if [[ -n "$key_info" && "$key_info" != "null" ]]; then
            tipo_key=$(echo "$key_info" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tipo',''))" 2>/dev/null)
        fi
        if [[ "$tipo_key" == "super" ]]; then
            tg_send "$chat_id" "⛔ No se puede eliminar una key de Super Admin."
            return
        fi
        eliminar_key "$key_del"
        local kb
        kb=$(kb_inline "📋 Ver keys|/keys" "🏠 Menu|/menu")
        tg_send_buttons "$chat_id" "🗑 Key <code>$key_del</code> eliminada." "$kb" "html"
        return
    fi

    # ═══ RENOVAR ═══
    if [[ "$text" =~ ^/renovar ]]; then
        if [[ -z "$auth_key" ]]; then return; fi
        local key_renovar=$(echo "$text" | awk '{print $2}')
        if [[ -z "$key_renovar" ]]; then
            tg_send "$chat_id" "Uso: /renovar KEY-XXXXXXXXXX (o key v2)"
            return
        fi
        key_renovar=$(echo "$key_renovar" | tr '+/' '-_')
        local ahora=$(date +%s)
        local nueva_expira=$((ahora + 30 * 86400))
        # Update Firebase
        local current_info
        current_info=$(fb_get "licencias/$key_renovar" 2>/dev/null)
        if [[ -n "$current_info" && "$current_info" != "null" ]]; then
            python3 -c "
import sys, json
try:
    d = json.loads('''$(echo "$current_info" | sed "s/'/\\\\'/g")''')
    d['expira'] = $nueva_expira
    d['activa'] = True
    print(json.dumps({k: d[k] for k in ['expira','activa']}))
except: pass
" 2>/dev/null | while IFS= read -r patch_body; do
                fb_patch "licencias/$key_renovar" "$patch_body" >/dev/null 2>&1
            done
        fi
        local kb
        kb=$(kb_inline "📋 Ver keys|/keys" "🏠 Menu|/menu")
        tg_send_buttons "$chat_id" "🔄 Key <code>$key_renovar</code> renovada (+30 dias)." "$kb" "html"
        return
    fi

    # ═══ AUTH COMMAND ═══
    if [[ "$text" =~ ^/auth ]]; then
        local key_auth=$(echo "$text" | awk '{print $2}')
        if [[ -z "$key_auth" ]]; then
            tg_send "$chat_id" "Uso: /auth TU_KEY"
            return
        fi

        tg_send "$chat_id" "🔍 Verificando key..."
        local info
        info=$(verificar_key "$key_auth")
        
        if [[ -z "$info" ]]; then
            local kb
            kb=$(kb_inline "🔑 Intentar de nuevo|/auth_menu")
            tg_send_buttons "$chat_id" "❌ Key no encontrada en la base de datos." "$kb"
            return
        fi

        IFS='|' read -r activa tipo_key expira count max_gen <<< "$info"

        if [[ "$activa" != "1" ]]; then
            tg_send "$chat_id" "❌ Key desactivada."
            return
        fi

        # Check usage limit
        if [[ "$max_gen" -gt 0 && "$count" -ge "$max_gen" ]]; then
            tg_send "$chat_id" "❌ Key agotada ($count/$max_gen usos)."
            return
        fi

        # Check expiration
        if [[ "$expira" -gt 0 ]]; then
            local ahora=$(date +%s)
            if [[ "$ahora" -gt "$expira" ]]; then
                tg_send "$chat_id" "❌ Key expirada."
                return
            fi
        fi

        # Auth OK
        set_auth_key "$user_id" "$key_auth"
        clear_user "$user_id"

        local kb
        kb=$(kb_inline \
            "🆕 Generar key|/generar" \
            "🔄 Renovar key|/renovar_menu" \
            "📊 Stats|/stats" \
            "📋 Ver keys|/keys" \
            "🚪 Cerrar sesion|/cerrar")

        tg_send_buttons "$chat_id" "
✅ <b>Autenticado!</b>

🔑 Key: <code>$key_auth</code>
👤 Tipo: <b>$tipo_key</b>

<b>Comandos:</b>" "$kb" "html"
        return
    fi

    # ═══ RENOVAR MENU (botones) ═══
    if [[ "$text" == "/renovar_menu" ]]; then
        tg_send "$chat_id" "🔄 Envia: /renovar KEY-XXXXXXXXXX"
        return
    fi

    # ═══ STATE MACHINE (flujo interactivo) ═══
    case "$state" in
        # --- Proveedor: esperando Telegram ID ---
        esperando_tg_id_proveedor)
            local tg_id_new="$text"
            [[ ! "$tg_id_new" =~ ^[0-9]+$ ]] && tg_send "$chat_id" "❌ ID invalido. Envia solo numeros." && return
            
            set_data "$user_id" "proveedor_tg" "$tg_id_new"
            set_state "$user_id" "esperando_nombre_proveedor"
            tg_send "$chat_id" "📝 Nombre del proveedor:"
            return
            ;;

        esperando_nombre_proveedor)
            local nombre_prov="$text"
            set_data "$user_id" "proveedor_nombre" "$nombre_prov"
            set_state "$user_id" "esperando_limite_prov"

            local kb
            kb=$(kb_inline \
                "1 uso|/lim_prov_1" \
                "5 usos|/lim_prov_5" \
                "10 usos|/lim_prov_10" \
                "20 usos|/lim_prov_20" \
                "50 usos|/lim_prov_50" \
                "100 usos|/lim_prov_100" \
                "♾️ Infinito|/lim_prov_0" \
                "❌ Cancelar|/cancel")

            tg_send_buttons "$chat_id" "🔢 <b>Limite de uso del proveedor:</b>

<b>Cuantos clientes puede generar con esta key?</b>" "$kb" "html"
            return
            ;;

        esperando_limite_prov)
            local max_gen=""
            case "$text" in
                /lim_prov_1)  max_gen=1 ;;
                /lim_prov_5)  max_gen=5 ;;
                /lim_prov_10) max_gen=10 ;;
                /lim_prov_20) max_gen=20 ;;
                /lim_prov_50) max_gen=50 ;;
                /lim_prov_100) max_gen=100 ;;
                /lim_prov_0)  max_gen=0 ;;
                *)
                    max_gen="$text"
                    [[ ! "$max_gen" =~ ^[0-9]+$ ]] && max_gen=0
                    ;;
            esac

            local nombre_prov
            nombre_prov=$(get_data "$user_id" "proveedor_nombre")
            local tg_id_new
            tg_id_new=$(get_data "$user_id" "proveedor_tg")
            
            local hex=$(openssl rand -hex 5 | tr '[:lower:]' '[:upper:]')
            local key_prov="KEY-$hex"
            local ahora=$(date +%s)
            
            insertar_key "$key_prov" "proveedor" "proveedor" 1 "$ahora" 0 "$nombre_prov" "$auth_key" "$tg_id_new" "$max_gen"
            
            clear_user "$user_id"
            
            local lim_text="Infinito"
            [[ "$max_gen" -gt 0 ]] && lim_text="$max_gen usos"
            
            local kb
            kb=$(kb_inline \
                "🆕 Generar otra|/generar" \
                "📋 Ver keys|/keys" \
                "🏠 Menu|/menu")
            
            tg_send_html "$chat_id" "
<b>✅ PROVEEDOR CREADO!</b>

🔑 Key: <code>$key_prov</code>
👤 Nombre: <b>$nombre_prov</b>
📱 Telegram ID: <code>$tg_id_new</code>
🔢 Limite: <b>$lim_text</b>
👤 Tipo: <b>proveedor</b>

<i>Envia esta key al proveedor para que use /auth</i>"
            return
            ;;

        # --- Flujo cliente: nombre ---
        esperando_cliente)
            set_data "$user_id" "cliente" "$text"
            set_state "$user_id" "esperando_plan"
            
            local kb
            kb=$(kb_inline \
                "🥉 Bronce S/10|/plan_bronce" \
                "⭐ Premium S/20|/plan_premium" \
                "💎 Platino S/35|/plan_platino" \
                "♾️ Vitalicio S/60|/plan_vitalicio" \
                "❌ Cancelar|/cancel")
            
            tg_send_buttons "$chat_id" "📋 <b>Plan para:</b> $text

<b>Selecciona el plan:</b>" "$kb" "html"
            return
            ;;

        # --- Plan selection via buttons ---
        esperando_plan)
            # Handle plan buttons
            case "$text" in
                /plan_*)
                    local plan="${text#/plan_}"
                    set_data "$user_id" "plan" "$plan"
                    set_state "$user_id" "esperando_dias"
                    
                    local dias_sugeridos=30
                    [[ "$plan" == "vitalicio" ]] && dias_sugeridos=36500
                    
                    local kb
                    kb=$(kb_inline \
                        "30 dias|/dias_30" \
                        "60 dias|/dias_60" \
                        "90 dias|/dias_90" \
                        "365 dias|/dias_365" \
                        "♾️ Vitalicio|/dias_vitalicio" \
                        "❌ Cancelar|/cancel")
                    
                    tg_send_buttons "$chat_id" "📅 <b>Dias de validez para:</b> $plan

<b>Selecciona o escribe los dias:</b>" "$kb" "html"
                    return
                    ;;
                *)
                    tg_send "$chat_id" "❌ Selecciona un plan con los botones."
                    return
                    ;;
            esac
            ;;

        # --- Dias selection ---
        esperando_dias)
            local dias=""
            case "$text" in
                /dias_30) dias=30 ;;
                /dias_60) dias=60 ;;
                /dias_90) dias=90 ;;
                /dias_365) dias=365 ;;
                /dias_vitalicio) dias=36500 ;;
                *)
                    dias="$text"
                    [[ ! "$dias" =~ ^[0-9]+$ ]] && dias=30
                    ;;
            esac

            set_data "$user_id" "dias" "$dias"
            set_state "$user_id" "esperando_limite"

            local kb
            kb=$(kb_inline \
                "1 uso|/lim_1" \
                "2 usos|/lim_2" \
                "5 usos|/lim_5" \
                "10 usos|/lim_10" \
                "20 usos|/lim_20" \
                "50 usos|/lim_50" \
                "100 usos|/lim_100" \
                "♾️ Infinito|/lim_0" \
                "❌ Cancelar|/cancel")

            tg_send_buttons "$chat_id" "🔢 <b>Limite de uso:</b>

<b>Cuantas keys puede generar con esta key?</b>
(El titular podra generar esa cantidad de clientes)" "$kb" "html"
            return
            ;;

        # --- Limite de uso ---
        esperando_limite)
            local max_gen=""
            case "$text" in
                /lim_1)  max_gen=1 ;;
                /lim_2)  max_gen=2 ;;
                /lim_5)  max_gen=5 ;;
                /lim_10) max_gen=10 ;;
                /lim_20) max_gen=20 ;;
                /lim_50) max_gen=50 ;;
                /lim_100) max_gen=100 ;;
                /lim_0)  max_gen=0 ;;
                *)
                    max_gen="$text"
                    [[ ! "$max_gen" =~ ^[0-9]+$ ]] && max_gen=0
                    ;;
            esac

            local cliente=$(get_data "$user_id" "cliente")
            local plan=$(get_data "$user_id" "plan")
            local dias=$(get_data "$user_id" "dias")

            # Check usage limit of auth key
            local info
            info=$(verificar_key "$auth_key")
            IFS='|' read -r _ _ _ count gen_limit <<< "$info"
            if [[ "$gen_limit" -gt 0 && "$count" -ge "$gen_limit" ]]; then
                tg_send "$chat_id" "❌ Has agotado tu limite de generaciones ($count/$gen_limit)."
                clear_user "$user_id"
                return
            fi

            tg_send "$chat_id" "⏳ Generando key..."

            # Look up proveedor's telegram_id for notifications
            local prov_tg_id
            prov_tg_id=$(obtener_telegram_id "$user_id" 2>/dev/null)

            local key_resultado
            key_resultado=$(generar_licencia "$auth_key" "$cliente" "$plan" "$dias" "$max_gen" "$prov_tg_id")

            # Acepta KEY- (legacy) o key v2 corta (40 chars)
            if [[ "$key_resultado" =~ ^KEY- || "$key_resultado" =~ ^[A-Za-z0-9+/_-]{40}$ ]]; then
                incrementar_contador "$auth_key"
                
                local lim_text="Infinito"
                [[ "$max_gen" -gt 0 ]] && lim_text="$max_gen usos"
                
                local kb
                kb=$(kb_inline \
                    "🆕 Generar otra|/generar" \
                    "📋 Ver keys|/keys" \
                    "🏠 Menu|/menu")
                
                tg_send_html "$chat_id" "
<b>✅ KEY GENERADA!</b>

🔑 <code>$key_resultado</code>

📋 Cliente: <b>$cliente</b>
💎 Plan: <b>$plan</b>
📅 Validez: <b>$dias dias</b>
🔢 Limite: <b>$lim_text</b>

<i>Entrega esta key al cliente.</i>"
            else
                tg_send_html "$chat_id" "
<b>❌ Error:</b> <code>$key_resultado</code>

Intenta con /generar"
            fi
            clear_user "$user_id"
            return
            ;;
    esac

    # ═══ FALLBACK ═══
    tg_send "$chat_id" "❓ No entendi. Usa /help"
}

# ================= FLUJO CLIENTE =================
_iniciar_flujo_cliente() {
    local chat_id="$1" user_id="$2"
    set_state "$user_id" "esperando_cliente"
    tg_send "$chat_id" "📝 Nombre del cliente (o 'anonimo'):"
}

# ================= GENERAR LICENCIA =================
# Cliente/regalo -> KEY v2 corta (40 chars, MoviVIPNetwork)
# Proveedor     -> KEY-xxxxxx legacy (se genera en su propio flujo)
generar_licencia() {
    local key_mayorista="$1" cliente="$2" plan="$3" dias="$4" max_gen="${5:-0}"
    local prov_tg_id="${6:-}"
    local ahora=$(date +%s)
    local expira=0
    [[ "$plan" != "vitalicio" ]] && expira=$((ahora + dias * 86400))

    # Generar KEY v2 corta (40 chars) firmada con la master key
    local id_short
    id_short=$(echo "$cliente" | tr -cd 'A-Za-z0-9' | head -c 4)
    [[ -z "$id_short" ]] && id_short="KVN1"
    local key_v2
    key_v2=$(generar_key_v2 "$id_short" "$expira" 1) || { echo "ERROR_MASTER_KEY_NO_DISPONIBLE"; return 1; }

    # Path Firebase url-safe (la v2 puede contener + y /)
    local key_path
    key_path=$(echo "$key_v2" | tr '+/' '-_')

    # Store in Firebase (path url-safe, key visible = la real)
    insertar_key "$key_path" "cliente" "$plan" 1 "$ahora" "$expira" "$cliente" "$key_mayorista" "$prov_tg_id" "$max_gen" "$key_v2"

    echo "$key_v2"
}

# ================= GENERAR KEY V2 (40 chars, MoviVIPNetwork) =================
# Replica New-ShortKeyV2 del generador PowerShell:
# payload 15B: [0]=v2 [1..4]=id [5..9]=res("kevin") [10..13]=exp uint32 BE [14]=plan
# Ofuscar con XOR(hmac(master,"v2short-xor")[:15]) + firma HMAC-SHA256[:15]
# raw 30B -> base64 raw sin padding = 40 chars
generar_key_v2() {
    local id="${1:-KVN1}" exp_epoch="${2:-0}" plan_code="${3:-1}"
    if [[ -z "$MASTER_KEY" ]]; then
        # Intento tardio de leer la key (env systemd o archivo)
        local mf="${MOVIVIP_MASTER_KEY_FILE:-/root/.master_key.b64}"
        [[ -f "$mf" ]] && MASTER_KEY=$(tr -d '[:space:]' < "$mf")
    fi
    [[ -z "$MASTER_KEY" ]] && { echo ""; return 1; }

    MASTER_KEY_B64="$MASTER_KEY" python3 -c '
import os, sys, hmac, hashlib, base64, struct
master = base64.b64decode(os.environ["MASTER_KEY_B64"])

_id = sys.argv[1].encode("ascii", "ignore")[:4]
exp = int(sys.argv[2])
plan = int(sys.argv[3])

# Payload 15 bytes
payload = bytearray(15)
payload[0] = 2
for i, b in enumerate(_id[:4]):
    payload[1 + i] = b
res = b"kevin"
for i, b in enumerate(res[:5]):
    payload[5 + i] = b
# exp uint32 BE
payload[10:14] = struct.pack(">I", exp & 0xFFFFFFFF)
payload[14] = plan

# Clave XOR derivada
xor_key = hmac.new(master, b"v2short-xor", hashlib.sha256).digest()[:15]
enc = bytearray(b ^ xor_key[i] for i, b in enumerate(payload))

# Firma HMAC-SHA256 truncada a 15 bytes
sig = hmac.new(master, bytes(enc), hashlib.sha256).digest()[:15]

raw = bytes(enc) + sig
print(base64.b64encode(raw).decode().rstrip("="))
' "$id" "$exp_epoch" "$plan_code"
}

# ================= LISTAR KEYS =================
_mostrar_keys() {
    local chat_id="$1" user_id="$2" page="${3:-0}"
    local auth_key=$(get_auth_key "$user_id")
    local user_tipo=$(obtener_tipo_user "$user_id")
    local per_page=5
    local offset=$((page * per_page))

    # Get all keys from Firebase
    local json_data
    json_data=$(fb_get "licencias" 2>/dev/null)

    if [[ -z "$json_data" || "$json_data" == "null" ]]; then
        tg_send "$chat_id" "📋 No hay keys en la base de datos."
        return
    fi

    # Filter and paginate with Python
    local result
    result=$(python3 -c "
import sys, json
from datetime import datetime
try:
    raw = sys.stdin.read()
    d = json.loads(raw) if raw.strip() else {}
    all_keys = list(d.values()) if isinstance(d, dict) else []
    # Filter by generada_por if not super
    if '$user_tipo' != 'super':
        all_keys = [k for k in all_keys if isinstance(k, dict) and k.get('generada_por') == '$auth_key']
    # Sort by creada desc
    all_keys.sort(key=lambda x: x.get('creada', 0) if isinstance(x, dict) else 0, reverse=True)
    total = len(all_keys)
    page_keys = all_keys[$offset:$offset+$per_page]
    output = {'keys': page_keys, 'total': total, 'page': $page, 'per_page': $per_page}
    print(json.dumps(output))
except Exception as e:
    print(json.dumps({'keys': [], 'total': 0, 'page': 0, 'per_page': $per_page}))
" <<< "$json_data" 2>/dev/null)

    local total
    total=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('total',0))" 2>/dev/null)

    if [[ "$total" == "0" ]]; then
        tg_send "$chat_id" "📋 No hay keys en la base de datos."
        return
    fi

    local msg="📋 <b>Keys (Pagina $((page+1))/$(( (total+per_page-1)/per_page ))):</b>\n\n"

    # Build rows from result
    echo "$result" | python3 -c "
import sys, json
from datetime import datetime
try:
    data = json.load(sys.stdin)
    for k in data['keys']:
        if not isinstance(k, dict): continue
        status = '✅' if k.get('activa') else '❌'
        tipo = k.get('tipo','?')
        plan = k.get('plan','?')
        cliente = k.get('cliente') or '?'
        expira = k.get('expira',0)
        if expira == 0:
            exp_str = '∞ vitalicia'
        else:
            exp_str = datetime.fromtimestamp(expira).strftime('%d/%m/%Y') if expira > 0 else '?'
        count = k.get('generadas_count',0)
        maxg = k.get('max_generadas',0)
        limit = f'{count}/{maxg}' if maxg > 0 else f'{count}/∞'
        print(f'{status} {k.get(\"key\",\"?\")} | {tipo} | {plan} | {cliente} | vence:{exp_str} | gen:{limit}')
except: pass
" 2>/dev/null | while IFS= read -r line; do
        msg+="$(echo "$line" | sed 's/$/\n/')"
    done

    # Navigation buttons
    local kb="[[{\"text\":\"⬅️ Anterior\",\"callback_data\":\"/keys_${page}\"}"
    if [[ $((page+1)) -lt $(( (total+per_page-1)/per_page )) ]]; then
        kb+=",{\"text\":\"➡️ Siguiente\",\"callback_data\":\"/keys_$((page+1))\"}"
    fi
    kb+="],[{\"text\":\"🏠 Menu\",\"callback_data\":\"/menu\"}]]"

    tg_send_buttons "$chat_id" "$msg" "$kb" "html"
}

# ================= CALLBACK HANDLER =================
handle_callback() {
    local cb_id="$1" chat_id="$2" user_id="$3" data="$4"

    log "CB @$user_id: $data"

    case "$data" in
        /auth_menu)
            tg_answer_cb "$cb_id" "Envia /auth TU_KEY"
            tg_send "$chat_id" "🔑 Envia tu key: /auth KEY-XXXXX"
            return
            ;;
        /menu|/start)
            local kb
            kb=$(kb_inline \
                "🔑 Autenticar|/auth_menu" \
                "❓ Ayuda|/help")
            tg_edit_buttons "$chat_id" "$(echo "$data" | grep -oP 'msg_\K.*' || echo '')" "👑 <b>MoviVIP Network</b>" "$kb"
            tg_answer_cb "$cb_id" "Menu"
            return
            ;;
        /generar|/gen_proveedor|/gen_cliente|/renovar_menu|/stats|/keys|/cerrar|/cancel)
            # Redirect to message handler
            handle_message "$chat_id" "$user_id" "" "$data"
            tg_answer_cb "$cb_id" ""
            return
            ;;
        /plan_*|/dias_*|/lim_*)
            handle_message "$chat_id" "$user_id" "" "$data"
            tg_answer_cb "$cb_id" ""
            return
            ;;
        /keys_*)
            local page="${data#/keys_}"
            _mostrar_keys "$chat_id" "$user_id" "$page"
            tg_answer_cb "$cb_id" ""
            return
            ;;
        /del_*)
            local key_del="${data#/del_}"
            local auth_key=$(get_auth_key "$user_id")
            if [[ -z "$auth_key" ]]; then
                tg_answer_cb "$cb_id" "No autenticado"
                return
            fi
            local tipo_key
            local key_info
            key_info=$(fb_get "licencias/$key_del" 2>/dev/null)
            if [[ -n "$key_info" && "$key_info" != "null" ]]; then
                tipo_key=$(echo "$key_info" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tipo',''))" 2>/dev/null)
            fi
            if [[ "$tipo_key" == "super" ]]; then
                tg_answer_cb "$cb_id" "No se puede eliminar super admin"
                return
            fi
            eliminar_key "$key_del"
            tg_answer_cb "$cb_id" "Key eliminada"
            _mostrar_keys "$chat_id" "$user_id" 0
            return
            ;;
    esac

    tg_answer_cb "$cb_id" ""
}

# ================= AUTH TOKEN =================
fb_auth_token() {
    local now=$(date +%s)
    if [[ -n "$FB_TOKEN_CACHE" && "$now" -lt "$FB_TOKEN_EXPIRES" ]]; then
        echo "$FB_TOKEN_CACHE"
        return 0
    fi

    local resp
    resp=$(curl -s --max-time 10 -X POST \
        "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${FB_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "{\"email\":\"${FB_AUTH_EMAIL}\",\"password\":\"${FB_AUTH_PASS}\",\"returnSecureToken\":true}")

    local token
    token=$(echo "$resp" | grep -oP '"idToken"\s*:\s*"\K[^"]+')
    if [[ -n "$token" ]]; then
        FB_TOKEN_CACHE="$token"
        FB_TOKEN_EXPIRES=$((now + 3500))
        echo "$token"
        return 0
    fi
    return 1
}

limpiar_secrets() { return 0; }

# ================= MAIN LOOP =================
main() {
    log "Bot v3.0-Firebase iniciado"

    # Verify Firebase connection
    local token
    if token=$(fb_auth_token 2>/dev/null); then
        log "Firebase RTDB: OK (token ${#token} chars)"
    else
        log_err "Firebase auth FAILED"
        exit 1
    fi

    # Super admin keys (ensure they exist in Firebase)
    local existing
    existing=$(fb_get "licencias/KEY-180DCF2829" 2>/dev/null)
    if [[ -z "$existing" || "$existing" == "null" ]]; then
        insertar_key "KEY-180DCF2829" "super" "super" 1 0 0 "" "sistema" "" 0
        log "Super key KEY-180DCF2829 created in Firebase"
    fi
    existing=$(fb_get "licencias/KEY-C9EFD7B9ED" 2>/dev/null)
    if [[ -z "$existing" || "$existing" == "null" ]]; then
        insertar_key "KEY-C9EFD7B9ED" "super" "super" 1 0 0 "" "sistema" "" 0
        log "Super key KEY-C9EFD7B9ED created in Firebase"
    fi
    log "Super admin keys OK"

    # Secrets
    if [[ -f "$SECRETS_SCRIPT" ]]; then
        source "$SECRETS_SCRIPT"
        descifrar_secrets 2>/dev/null
    fi

    [[ -z "$BOT_TOKEN" ]] && { log_err "BOT_TOKEN no configurado"; exit 1; }

    mkdir -p "$STATE_DIR"
    log "Polling (timeout: ${POLL_TIMEOUT}s)..."

    # Track message_id for edit operations
    declare -A MSG_IDS

    while true; do
        if [[ -f "$OFFSET_FILE" ]]; then
            OFFSET=$(cat "$OFFSET_FILE")
        else
            OFFSET=0
        fi

        local response
        response=$(curl -s --max-time $((POLL_TIMEOUT + 10)) \
            "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates" \
            -d "offset=$OFFSET" \
            -d "timeout=$POLL_TIMEOUT" \
            -d "allowed_updates=[\"message\",\"callback_query\"]" 2>/dev/null)

        if [[ -z "$response" ]]; then
            sleep 2
            continue
        fi

        local ok
        ok=$(echo "$response" | grep -oP '"ok"\s*:\s*(true|false)' | sed 's/.*:\s*//')
        if [[ "$ok" != "true" ]]; then
            sleep 5
            continue
        fi

        # Process both messages and callbacks
        # IMPORTANT: Use process substitution (< <(...)) instead of pipe (|)
        # so the while loop runs in the MAIN shell, preserving USER_STATE
        while IFS='|' read -r type uid chat_id user_id username extra1 extra2 extra3; do
            case "$type" in
                MSG)
                    handle_message "$chat_id" "$user_id" "$username" "$extra1"
                    ;;
                CB)
                    handle_callback "$extra2" "$chat_id" "$user_id" "$extra1"
                    ;;
            esac
        done < <(echo "$response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    max_id = -1
    for update in data.get('result', []):
        uid = update['update_id']
        if uid > max_id:
            max_id = uid
        
        # Messages
        msg = update.get('message')
        if msg:
            user = msg.get('from', {})
            text = msg.get('text', '')
            mid = msg.get('message_id', '')
            print(f'MSG|{uid}|{msg[\"chat\"][\"id\"]}|{user.get(\"id\",\"\")}|{user.get(\"username\",\"\")}|{text}|{mid}')
        
        # Callback queries
        cb = update.get('callback_query')
        if cb:
            user = cb.get('from', {})
            cb_data = cb.get('data', '')
            mid = cb.get('message', {}).get('message_id', '')
            cid = cb.get('message', {}).get('chat', {}).get('id', '')
            print(f'CB|{uid}|{cid}|{user.get(\"id\",\"\")}|{user.get(\"username\",\"\")}|{cb_data}|{cb.get(\"id\",\"\")}|{mid}')
    
    if max_id >= 0:
        with open('$OFFSET_FILE', 'w') as f:
            f.write(str(max_id + 1))
except Exception as e:
    print(f'ERR|{e}', file=sys.stderr)
" 2>>"$LOG_FILE")

        limpiar_secrets 2>/dev/null
    done
}

# ================= CLEANUP =================
cleanup() {
    log "Bot detenido"
    limpiar_secrets 2>/dev/null
    rm -f "$OFFSET_FILE" 2>/dev/null
    exit 0
}

trap cleanup SIGINT SIGTERM SIGHUP

main "$@"
