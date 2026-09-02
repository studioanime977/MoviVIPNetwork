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
CANALES_FILE="$STATE_DIR/canales"
# Lista de canales/grupos a escanear automaticamente (uno por linea, @ o id)
# Seed con canales oficiales; el super puede editarla con /auto_canales
AUTO_CANALES_FILE="$STATE_DIR/auto_canales"
if [[ ! -f "$AUTO_CANALES_FILE" ]]; then
    cat > "$AUTO_CANALES_FILE" <<'EOF'
@MoviVIPNetwork
@MoviVIPNet
@FreeNetZonevip
@FreeNetZonevips
EOF
fi
EMOJIS_FILE="$BASE/.emojis.conf"
# Plantilla editable: bloques de texto que el super puede personalizar
# (cada bloque es un archivo; si no existe se usa el default del codigo)
PLANTILLA_DIR="$STATE_DIR/plantilla"
mkdir -p "$PLANTILLA_DIR" 2>/dev/null
# Telegram ID del proveedor dueño del bot (configurable por el super admin)
PROV_FILE="$STATE_DIR/bot_provider"
# Ultima key de regalo generada (para publicacion en canal)
LAST_GEN_KEY=""
LAST_GEN_ID=""
LAST_GEN_EXP=""

# ================= CONFIG =================
# Source .env-bot as fallback if BOT_TOKEN not set by systemd
if [[ -z "${MOVIVIP_BOT_TOKEN:-}" ]]; then
    [[ -f "$BASE/.env-bot" ]] && source "$BASE/.env-bot" 2>/dev/null
fi
BOT_TOKEN="${MOVIVIP_BOT_TOKEN:-}"
POLL_TIMEOUT=30
BOT_ID="8808614399"
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
# Path url-safe para Firebase: las keys v2 cortas contienen '+' y '/'.
# Legacy KEY-... no tiene caracteres especiales -> queda igual.
fb_key_path() {
    echo "$1" | tr '+/' '-_'
}

insertar_key() {
    local key="$1" tipo="${2:-cliente}" plan="${3:-premium}" activa="${4:-1}"
    local creada="${5:-$(date +%s)}" expira="${6:-0}" cliente="${7:-}"
    local gen_por="${8:-}" tg_id="${9:-}" max_gen="${10:-0}"
    # Get existing generadas_count if key already exists
    local existing_count="0"
    local existing
    existing=$(fb_get "licencias_movivip/$key" 2>/dev/null)
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
    fb_put "licencias_movivip/$key" "$body" >/dev/null 2>&1
}

obtener_key_info() {
    local key="$1"
    local result
    result=$(fb_get "licencias_movivip/$(fb_key_path "$key")" 2>/dev/null)
    if [[ -z "$result" || "$result" == "null" ]]; then
        echo "{}"
        return
    fi
    echo "$result"
}

verificar_key() {
    local key="$1"
    local json_data
    json_data=$(fb_get "licencias_movivip/$(fb_key_path "$key")" 2>/dev/null)
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
    json_data=$(fb_get "licencias_movivip/$(fb_key_path "$auth_key")" 2>/dev/null)
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
    json_data=$(fb_get "licencias_movivip/$(fb_key_path "$auth_key")" 2>/dev/null)
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
    json_data=$(fb_get "licencias_movivip/$(fb_key_path "$key")" 2>/dev/null)
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
        fb_patch "licencias_movivip/$(fb_key_path "$key")" "$patch_body" >/dev/null 2>&1
    done
}

eliminar_key() {
    local key="$1"
    fb_delete "licencias_movivip/$(fb_key_path "$key")" >/dev/null 2>&1
}

# Buscar una key de REGALO vigente (tipo=regalo, activa, sin expirar)
# Devuelve la key visible (campo 'key' si existe, si no el path). Vacio si no hay.
buscar_regalo_vigente() {
    local json_data
    json_data=$(fb_get "licencias_movivip" 2>/dev/null)
    if [[ -z "$json_data" || "$json_data" == "null" ]]; then
        return
    fi
    python3 - "$json_data" << 'PYEOF'
import sys, json, time
try:
    raw = sys.argv[1]
    d = json.loads(raw) if raw.strip() else {}
    now = int(time.time())
    for k, v in d.items():
        if not isinstance(v, dict):
            continue
        if v.get('tipo') != 'regalo':
            continue
        if not v.get('activa'):
            continue
        exp = int(v.get('expira', 0) or 0)
        if exp > 0 and exp <= now:
            continue
        print(v.get('key') or k)
        sys.exit(0)
except Exception:
    pass
PYEOF
}

# ID del proveedor dueño del bot (configurado por super admin)
obtener_prov_bot() {
    if [[ -f "$PROV_FILE" ]]; then
        tr -d '[:space:]' < "$PROV_FILE"
    fi
}

contar_keys() {
    local json_data
    json_data=$(fb_get "licencias_movivip" 2>/dev/null)
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
    json_data=$(fb_get "licencias_movivip" 2>/dev/null)
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
    json_data=$(fb_get "licencias_movivip" 2>/dev/null)
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
    local chat_id="$1" user_id="$2" username="$3" text="$4" emojis_json="${5:-}" html_text="${6:-}"
    local state=$(get_state "$user_id")

    log "MSG @$username($user_id): $text"

    # ═══ LOS MENSAJES DE GRUPOS/CANALES YA SE FILTRAN EN EL PARSER (Python) ═══
    # Solo llegan aqui los mensajes de grupo/canal en los que el bot fue LLAMADO
    # explicitamente (mencion @MovivipKeygen_bot, comando /, text_mention o reply a un
    # mensaje del bot). El resto se ignora por completo en el parser y NUNCA llega aqui.

    # ═══ COMANDOS GLOBALES (siempre disponibles) ═══
    case "$text" in
        /start|/menu)
            # Auto-regalo si le dio start y hay key de regalo vigente (sin auth)
            local auth_check=$(get_auth_key "$user_id")
            if [[ -z "$auth_check" ]]; then
                local regalo_auto_vigente
                regalo_auto_vigente=$(buscar_regalo_vigente)
                if [[ -n "$regalo_auto_vigente" ]]; then
                    local pt_r
                    pt_r=$(plantilla_key "$regalo_auto_vigente" "REGA" "4hs" "MoviVIP Network")
                    tg_send_html "$chat_id" "$pt_r"
                    tg_send "$chat_id" "🎁 Aqui tienes una key de REGALO de MoviVIP Network. Disfrutala!"
                    return
                fi
                local kb0
                kb0=$(kb_inline \
                    "🔑 Autenticar|/auth_menu" \
                    "🎁 Quiero mi regalo|/regalo_auto" \
                    "❓ Ayuda|/help")
                tg_send_buttons "$chat_id" "👑 <b>MoviVIP Network</b> — Generador de Licencias

<b>Bienvenido, $username.</b>

Selecciona una opcion:" "$kb0" "html"
                clear_user "$user_id"
                return
            fi

            # ✅ AUTENTICADO → MENU COMPLETO DE BOTONES
            local user_tipo_m=$(obtener_tipo_user "$user_id")
            local kb_m
            if [[ "$user_tipo_m" == "super" ]]; then
                kb_m=$(kb_inline \
                    "🆕 Generar Cliente|/gen_cliente" \
                    "🏷️ Generar Proveedor|/gen_proveedor" \
                    "🎁 Generar Regalo|/gen_regalo" \
                    "📢 Canales|/canales" \
                    "🎨 Emojis Premium|/emojis" \
                    "📝 Plantilla|/plantilla" \
                    "🔄 Renovar Key|/renovar_menu" \
                    "📋 Ver Keys|/keys" \
                    "📊 Stats|/stats" \
                    "🎯 ID Proveedor Bot|/set_prov_menu" \
                    "🏠 Menu|/menu" \
                    "🚪 Cerrar Sesion|/cerrar")
            else
                kb_m=$(kb_inline \
                    "🆕 Generar Cliente|/gen_cliente" \
                    "🔄 Renovar Key|/renovar_menu" \
                    "📋 Ver Keys|/keys" \
                    "📊 Stats|/stats" \
                    "🏠 Menu|/menu" \
                    "🚪 Cerrar Sesion|/cerrar")
            fi
            tg_send_buttons "$chat_id" "👑 <b>MoviVIP Network</b> — Panel de Control

<b>Hola, $username.</b> Tipo: <b>$user_tipo_m</b>

Selecciona una opcion:" "$kb_m" "html"
            clear_user "$user_id"
            return
            ;;

        /help)
            tg_send_html "$chat_id" "
<b>📋 Comandos disponibles:</b>

🔑 <b>/auth KEY</b> — Autenticarte con tu key
🆕 <b>/generar</b> — Generar key de licencia
🎁 <b>/gen_regalo</b> — Key gratis (4hs) y publicarla en canal
📡 <b>/canales</b> — Canales/grupos donde está el bot
🎨 <b>/emojis</b> — Configurar emojis premium animados
📝 <b>/plantilla</b> — Editar plantilla del mensaje de key
📝 <b>/plantilla_reset</b> — Restaurar plantilla original
🔄 <b>/renovar KEY</b> — Renovar key (+30 dias)
📊 <b>/stats</b> — Ver estadisticas
📋 <b>/keys</b> — Ver todas las keys
🗑 <b>/delete KEY</b> — Eliminar una key
🚪 <b>/cerrar</b> — Cerrar sesion
❌ <b>/cancel</b> — Cancelar operacion actual"
            return
            ;;

/regalo_auto)
            local regalo_aviso
            regalo_aviso=$(buscar_regalo_vigente)
            if [[ -n "$regalo_aviso" ]]; then
                local pt_a
                pt_a=$(plantilla_key "$regalo_aviso" "REGA" "4hs" "MoviVIP Network")
                tg_send_html "$chat_id" "$pt_a"
                tg_send "$chat_id" "🎁 Aqui tienes tu key de REGALO. Disfrutala!"
            else
                tg_send "$chat_id" "😔 Ahora mismo no hay keys de regalo disponibles. Vuelve mas tarde."
            fi
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

        /gen_regalo)
            if [[ -z "$auth_key" ]]; then return; fi
            local user_tipo_r=$(obtener_tipo_user "$user_id")
            if [[ "$user_tipo_r" != "super" ]]; then
                tg_send "$chat_id" "⛔ Solo Super Admin puede generar keys de regalo."
                return
            fi

            # Key v2 de regalo: expira en 4 horas, id REGA, plan bronce
            local ahora_r=$(date +%s)
            local exp_r=$((ahora_r + 14400))
            local id_regalo="REGA"
            local key_v2_r
            key_v2_r=$(generar_key_v2 "$id_regalo" "$exp_r" 1)
            if [[ -z "$key_v2_r" ]]; then
                tg_send "$chat_id" "❌ Error generando key v2 (MASTER_KEY no disponible)."
                return
            fi

            # Firebase: path = key url-safe (las v2 contienen '+' y '/')
            local key_path_r
            key_path_r=$(fb_key_path "$key_v2_r")
            insertar_key "$key_path_r" "regalo" "bronce" 1 "$ahora_r" "$exp_r" "MoviVIP Network" "$auth_key" "" 0 "$key_v2_r"
            incrementar_contador "$auth_key"

            # Guardar para publicacion
            LAST_GEN_KEY="$key_v2_r"
            LAST_GEN_ID="$id_regalo"
            LAST_GEN_EXP="$exp_r"

            # ✅ Envio AUTO al proveedor dueño del bot (si esta configurado)
            local prov_bot_id
            prov_bot_id=$(obtener_prov_bot)
            if [[ -n "$prov_bot_id" ]]; then
                local pt_prov
                pt_prov=$(plantilla_key "$key_v2_r" "$id_regalo" "4hs" "MoviVIP Network")
                local resp_prov
                resp_prov=$(curl -s --max-time 15 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
                    --data-urlencode "chat_id=$prov_bot_id" --data-urlencode "text=$pt_prov" \
                    -d "parse_mode=HTML" -d "disable_web_page_preview=true" 2>/dev/null)
            fi

            tg_send_html "$chat_id" "
🎁 <b>KEY REGALO GENERADA!</b> (expira en 4hs)

🔑 <code>$key_v2_r</code>

📢 <b>¿Dónde la publico?</b>"

            # Botones: canales/grupos detectados
            local kb_rows=("🔒 Enviar solo aqui|/pub_none" "🌐 Publicar en TODOS|/pub_all")
            if [[ -f "$CANALES_FILE" ]]; then
                local idx_c=0
                while IFS='|' read -r cid_c ctype_c ctitle_c cuser_c cstatus_c; do
                    [[ -z "$cid_c" ]] && continue
                    # Saltar chats donde el bot ya no esta
                    [[ "$cstatus_c" == "left" || "$cstatus_c" == "kicked" ]] && continue
                    local icon_c="📢"; [[ "$ctype_c" == "group" || "$ctype_c" == "supergroup" ]] && icon_c="👥"
                    # Marcar canales sin admin (no se podra publicar)
                    if [[ "$ctype_c" == "channel" && "$cstatus_c" != "administrator" && "$cstatus_c" != "creator" ]]; then
                        icon_c="🔇"
                    fi
                    kb_rows+=("${icon_c} ${ctitle_c:-chat $idx_c}|/pub_${idx_c}")
                    idx_c=$((idx_c + 1))
                done < "$CANALES_FILE"
            fi
            kb_rows+=("🆕 Generar otra|/gen_regalo" "🏠 Menu|/menu")
            local kb
            kb=$(kb_inline "${kb_rows[@]}")
            tg_send_buttons "$chat_id" "Selecciona el destino de la key:" "$kb"
            return
            ;;

        /canales)
            if [[ -z "$auth_key" ]]; then return; fi
            local user_tipo_c=$(obtener_tipo_user "$user_id")
            [[ "$user_tipo_c" != "super" ]] && { tg_send "$chat_id" "⛔ Solo Super Admin."; return; }

            if [[ ! -f "$CANALES_FILE" ]]; then
                tg_send_html "$chat_id" "📭 <b>Aún no hay canales/grupos detectados.</b>

Agrega este bot a un canal como <b>administrador</b> (o a un grupo) y escribe /canales de nuevo.

💡 El bot detecta automáticamente cuando es agregado."
                return
            fi

            local idx_c2=0
            local out_c="📡 <b>Canales/grupos donde está el bot:</b>"
            local prov_show
            prov_show=$(obtener_prov_bot)
            prov_show="${prov_show:-no configurado (usa /set_prov_menu)}"
            while IFS='|' read -r cid_c2 ctype_c2 ctitle_c2 cuser_c2 cstatus_c2; do
                [[ -z "$cid_c2" ]] && continue
                local icon_c2="📢"; [[ "$ctype_c2" == "group" || "$ctype_c2" == "supergroup" ]] && icon_c2="👥"
                local pub_ok_c="✅ puede publicar"
                if [[ "$ctype_c2" == "channel" && "$cstatus_c2" != "administrator" && "$cstatus_c2" != "creator" ]]; then
                    pub_ok_c="⚠️ solo miembro (hazlo ADMIN)"
                fi
                out_c+="

${icon_c2} <b>${ctitle_c2:-sin título}</b>
    ${ctype_c2} · ${cuser_c2:-sin @} · status: ${cstatus_c2}
    ${pub_ok_c}"
                idx_c2=$((idx_c2 + 1))
            done < "$CANALES_FILE"

            out_c+="

📋 <b>Proveedor del bot:</b> ${prov_show}
💡 Tip: para publicar el bot debe ser <b>ADMIN</b> del canal.
Usa /gen_regalo para generar y publicar una key.

➕ Si el bot ya está en un canal pero no aparece: usa
<code>/agregar_canal @usuario_del_canal</code> para registrarlo manualmente."
            tg_send_html "$chat_id" "$out_c"
            return
            ;;

        /agregar_canal)
            if [[ -z "$auth_key" ]]; then return; fi
            local user_tipo_ac=$(obtener_tipo_user "$user_id")
            [[ "$user_tipo_ac" != "super" ]] && { tg_send "$chat_id" "⛔ Solo Super Admin."; return; }

            local ref_ac
            ref_ac=$(echo "$text" | awk '{print $2}')
            if [[ -z "$ref_ac" ]]; then
                tg_send_html "$chat_id" "📡 <b>Registrar canal/grupo manualmente</b>

Uso: <code>/agregar_canal @usuario_del_canal</code>
o   <code>/agregar_canal -1001234567890</code>

El bot consulta a Telegram la info del chat y lo agrega a la lista.
<i>El bot debe estar agregado al chat para que funcione.</i>"
                return
            fi

            tg_send "$chat_id" "🔍 Consultando info del chat <code>$ref_ac</code>..."

            # Consultar getChat de Telegram (funciona con @username o chat_id)
            local resp_ac
            resp_ac=$(curl -s --max-time 15 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/getChat" \
                --data-urlencode "chat_id=$ref_ac" 2>/dev/null)

            local ok_ac
            ok_ac=$(echo "$resp_ac" | grep -oP '"ok"\s*:\s*(true|false)' | sed 's/.*:\s*//')
            if [[ "$ok_ac" != "true" ]]; then
                local desc_ac
                desc_ac=$(echo "$resp_ac" | grep -oP '"description"\s*:\s*"[^"]*"' | sed 's/.*"description"\s*:\s*"//;s/"$//')
                tg_send "$chat_id" "❌ No pude obtener info de <code>$ref_ac</code>: ${desc_ac:-respuesta vacia}

Verifica que:
• El bot esté agregado al chat
• El @ sea correcto (si es canal, el @ debe ser publico)"
                return
            fi

            local chat_id_ac
            chat_id_ac=$(echo "$resp_ac" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['id'])" 2>/dev/null)
            local chat_type_ac
            chat_type_ac=$(echo "$resp_ac" | python3 -c "import sys,json; print(json.load(sys.stdin)['result'].get('type',''))" 2>/dev/null)
            local chat_title_ac
            chat_title_ac=$(echo "$resp_ac" | python3 -c "import sys,json; print(json.load(sys.stdin)['result'].get('title','') or '')" 2>/dev/null)
            local chat_user_ac
            chat_user_ac=$(echo "$resp_ac" | python3 -c "import sys,json; print(json.load(sys.stdin)['result'].get('username','') or '')" 2>/dev/null)

            # Verificar si el bot es admin (getChatMember)
            local my_status="member"
            local resp_me
            resp_me=$(curl -s --max-time 15 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/getChatMember" \
                --data-urlencode "chat_id=$chat_id_ac" --data-urlencode "user_id=$BOT_ID" 2>/dev/null)
            local ok_me
            ok_me=$(echo "$resp_me" | grep -oP '"ok"\s*:\s*(true|false)' | sed 's/.*:\s*//')
            if [[ "$ok_me" == "true" ]]; then
                my_status=$(echo "$resp_me" | python3 -c "import sys,json; print(json.load(sys.stdin)['result'].get('status','member'))" 2>/dev/null)
            fi

            # Guardar (reemplaza si ya existia)
            chat_detect "$chat_id_ac" "$chat_type_ac" "$chat_title_ac" "$chat_user_ac" "$my_status"

            tg_send_html "$chat_id" "✅ <b>Canal/grupo registrado:</b>

📡 ${chat_title_ac:-sin título} (${chat_type_ac})
🆔 <code>$chat_id_ac</code>
👤 ${chat_user_ac:-sin @}
🚧 Bot status: <b>$my_status</b>

$([[ "$my_status" != "administrator" && "$my_status" != "creator" ]] && echo '⚠️ El bot debe ser ADMIN del canal para publicar keys.')

Ya puedes usar /gen_regalo para publicar."
            return
            ;;

        /auto_canales)
            if [[ -z "$auth_key" ]]; then return; fi
            local user_tipo_au=$(obtener_tipo_user "$user_id")
            [[ "$user_tipo_au" != "super" ]] && { tg_send "$chat_id" "⛔ Solo Super Admin."; return; }

            local ref_au
            ref_au=$(echo "$text" | awk '{print $2}')
            if [[ -n "$ref_au" ]]; then
                if [[ "$ref_au" == "@"* || "$ref_au" == "-100"* || "$ref_au" == "-"* ]]; then
                    auto_canales_add "$ref_au"
                    local rc_add=$?
                    if [[ $rc_add -eq 0 ]]; then
                        tg_send "$chat_id" "✅ <code>$ref_au</code> agregado al auto-scan.

El bot lo detectara automaticamente en el proximo escaneo (menos de 5 min)."
                        auto_scan_canales
                    elif [[ $rc_add -eq 2 ]]; then
                        tg_send "$chat_id" "ℹ️ <code>$ref_au</code> ya estaba en la lista."
                    else
                        tg_send "$chat_id" "❌ Referencia vacía."
                    fi
                else
                    tg_send "$chat_id" "❌ Usa formato <code>@canal</code> o <code>-1001234567890</code>."
                fi
                return
            fi

            # Mostrar lista actual
            local lista_au=""
            local n_au=0
            while IFS= read -r ln_au; do
                ln_au=$(echo "$ln_au" | tr -d '[:space:]')
                [[ -z "$ln_au" || "$ln_au" == \#* ]] && continue
                lista_au+="• <code>$ln_au</code>
"
                n_au=$((n_au + 1))
            done < "$AUTO_CANALES_FILE"

            tg_send_html "$chat_id" "🔎 <b>Auto-scan de canales</b> (${n_au})

El bot escanea automáticamente estos chats cada pocos minutos y registra donde esté agregado (sin necesidad de agregarlo manual):

${lista_au:-<i>vacía</i>}

➕ Para agregar: <code>/auto_canales @tu_canal</code>

Los canales oficiales ya estan pre-cargados."
            return
            ;;

        /set_prov_menu)
            if [[ -z "$auth_key" ]]; then return; fi
            local user_tipo_sp=$(obtener_tipo_user "$user_id")
            [[ "$user_tipo_sp" != "super" ]] && { tg_send "$chat_id" "⛔ Solo Super Admin."; return; }
            local prov_actual
            prov_actual=$(obtener_prov_bot)
            set_state "$user_id" "esperando_prov_bot"
            tg_send_html "$chat_id" "🎯 <b>ID del PROVEEDOR dueño del bot</b>

Este Telegram ID recibe las keys de regalo generadas automaticamente (envio directo a su chat).

<i>Actual: ${prov_actual:-no configurado}</i>

Envia el <b>Telegram ID numerico</b> del proveedor:"
            return
            ;;

        /emojis)
            if [[ -z "$auth_key" ]]; then return; fi
            local user_tipo_e=$(obtener_tipo_user "$user_id")
            [[ "$user_tipo_e" != "super" ]] && { tg_send "$chat_id" "⛔ Solo Super Admin."; return; }
set_state "$user_id" "esperando_emojis"
            tg_send_html "$chat_id" "🎨 <b>Configura tus emojis premium (animados)</b>

<b>IMPORTANTE — cada mensaje = 1 slot.</b>
Si un emoji visual (ej. la barra de destellos ✨) son <b>varios custom emoji pegados</b>, mándalos <b>TODOS juntos en el MISMO mensaje</b>: se guardan como una sola secuencia y no se rompen.

Envía en el orden de los slots:
0 = ✨ (barras de destellos)
1 = ✅ (checks)
2 = 🎁 (regalo)
3 = 🔑 (key/install)
4 = 🔥 (barras de fuego)
5 = ☄️ (compatibilidad)
6 = ⚠️ (aviso)
7 = 🌟 (By)

8 = ➡️ (flecha inicio By)
9 = ⬅️ (flecha final By)

<b>Los que no configures se muestran con el emoji normal de la plantilla.</b>

<b>Puedes mandarlos por partes</b>: 1 mensaje = 1 slot. Cada mensaje se guarda en el siguiente slot libre.
Cuando termines, envia <b>/listo_emojis</b>.

<i>Los que no configures se muestran con el emoji normal.
Manda SOLO los custom emojis de tu pack premium (los animados).</i>"
            return
            ;;

        /reset_emojis)
            if [[ -z "$auth_key" ]]; then return; fi
            local user_tipo_re=$(obtener_tipo_user "$user_id")
            [[ "$user_tipo_re" != "super" ]] && { tg_send "$chat_id" "⛔ Solo Super Admin."; return; }
            rm -f "$EMOJIS_FILE"
            tg_send "$chat_id" "✅ Emojis premium restablecidos a los normales. Usa /emojis para configurar de nuevo."
            return
            ;;

        /listo_emojis)
            if [[ -z "$auth_key" ]]; then return; fi
            local user_tipo_le=$(obtener_tipo_user "$user_id")
            [[ "$user_tipo_le" != "super" ]] && { tg_send "$chat_id" "⛔ Solo Super Admin."; return; }
            clear_user "$user_id"
            local ncapt_le=0
            [[ -f "$EMOJIS_FILE" ]] && ncapt_le=$(grep -c '^[0-9]\+=' "$EMOJIS_FILE" 2>/dev/null || echo 0)
            tg_send_html "$chat_id" "✅ <b>Listo.</b> ${ncapt_le} emojis premium activos.

Ahora usa /gen_regalo para generar una key y publicarla con tus emojis animados.

Recuerda que quien no tenga tu pack verá el emoji normal (fallback)."
            return
            ;;

        /plantilla)
            if [[ -z "$auth_key" ]]; then return; fi
            local user_tipo_p=$(obtener_tipo_user "$user_id")
            [[ "$user_tipo_p" != "super" ]] && { tg_send "$chat_id" "⛔ Solo Super Admin."; return; }

            # Vista previa con datos de ejemplo
            local preview
            preview=$(plantilla_key "ABC123DEF456GHI789JKL012MNO345PQR678STU9" "ABCD" "4 horas" "MoviVIP Network")

            local kb_pl
            kb_pl=$(kb_inline \
                "📝 Todo en 1 msg|/plantilla_todo" \
                "✏️ Titulo|/edit_plantilla_titulo" \
                "✏️ Separador|/edit_plantilla_sep" \
                "✏️ Reseller|/edit_plantilla_reseller" \
                "✏️ Linea ID|/edit_plantilla_id" \
                "✏️ Linea KEY|/edit_plantilla_key" \
                "✏️ Install|/edit_plantilla_install" \
                "✏️ Compatibilidad|/edit_plantilla_compat" \
                "✏️ Contacto|/edit_plantilla_contacto" \
                "✏️ Amigos|/edit_plantilla_amigos" \
                "✏️ Expira|/edit_plantilla_exp" \
                "✏️ By|/edit_plantilla_by" \
                "🔄 Todo original|/plantilla_reset" \
                "🏠 Menu|/menu")

            tg_send_buttons "$chat_id" "📝 <b>Plantilla del mensaje de key</b>

Puedes editar <b>todo el texto en un solo mensaje</b> (recomendado): toca <b>📝 Todo en 1 msg</b>.
O edita cada parte por separado con los botones de abajo.

Los bloques se guardan en disco. Si no has tocado nada, se usa el diseño original.

<b>Placeholders disponibles:</b>
<code>{KEY}</code> <code>{ID}</code> <code>{RESELLER}</code> <code>{EXP}</code>
<code>{E0}</code>..<code>{E10}</code> = emojis premium configurados
<code>{INSTALL}</code> = comando de instalacion

👇 <b>Vista previa (key de ejemplo):</b>
$preview" "$kb_pl" "html"
            return
            ;;

        /plantilla_reset)
            if [[ -z "$auth_key" ]]; then return; fi
            local user_tipo_pr=$(obtener_tipo_user "$user_id")
            [[ "$user_tipo_pr" != "super" ]] && { tg_send "$chat_id" "⛔ Solo Super Admin."; return; }
            rm -rf "$PLANTILLA_DIR" 2>/dev/null
            mkdir -p "$PLANTILLA_DIR" 2>/dev/null
            tg_send "$chat_id" "✅ Plantilla restaurada a la original. Los bloques personalizados fueron borrados."
            return
            ;;

        /plantilla_todo)
            if [[ -z "$auth_key" ]]; then return; fi
            local user_tipo_ptd=$(obtener_tipo_user "$user_id")
            [[ "$user_tipo_ptd" != "super" ]] && { tg_send "$chat_id" "⛔ Solo Super Admin."; return; }
            set_state "$user_id" "edit_plantilla_todo"
            local ejemplo_todo
            ejemplo_todo=$(cat <<'EOF'
━━━━━━━━━━━━━━━
✅ Key MoviVIP Network V6.2 generada ✅
━━━━━━━━━━━━━━━
Reseller: {RESELLER}
━━━━━━━━━━━━━━━
🆔: <code>{ID}</code>
━━━━━━━━━━━━━━━
KEY: <code>{KEY}</code>
━━━━━━━━━━━━━━━
<pre>{INSTALL}</pre>
━━━━━━━━━━━━━━━
▎◆ 🖥️ COMPATIBILIDAD TOTAL (SERVIDOR) ──────────────────────────────────────────────────────────────────
   SO:  ✅ Ubuntu 20.04·22.04·24.04   ✅ Debian 11·12
   Arq: ✅ x86_64/amd64  ✅ ARM64/aarch64  ⚠️ ARMv7/i386
   Nube: ☁ Oracle Cloud (A1/Flex) · AWS Graviton · Google Cloud
        Azure · DigitalOcean · Vultr · Hetzner · Contabo
   Virtualización: KVM ✅ · LXC/OpenVZ 7+ parcial
   Nota: motor API Access (bots) = binario x86_64 (ARM vía qemu)
━━━━━━━━━━━━━━━
▎◆ 📞 CONTACTO OFICIAL ─────────────────────────────────────────────────────────────────────────────────
   📢 Canal oficial ....... t.me/MoviVIPNetwork
   👥 Grupo oficial ........ t.me/MoviVIPNet
   💬 Soporte directo ...... @MoviVIP  (t.me/MoviVIP)
   🌐 Sitio web ............ https://movivip-network.web.app
   📱 WhatsApp ............. +57 311 700 8185

 ▎◆ 🤝 CANALES AMIGOS (FreeNetZone) ─────────────────────────────────────────────────────────────────────
   Canal oficial t.me/FreeNetZonevip   ·  Grupo oficial t.me/FreeNetZonevips
━━━━━━━━━━━━━━━
Esta key expira en {EXP}
➡️ By : @MoviVIP ⬅️
EOF
)
            tg_send_html "$chat_id" "📝 <b>Editar plantilla completa en UN mensaje</b>

Pega el texto completo tal como quieres que salga. Usa los placeholders dinámicos:
<code>{KEY}</code> <code>{ID}</code> <code>{RESELLER}</code> <code>{EXP}</code> <code>{INSTALL}</code>

Los <b>emojis premium de tu pack</b> los pegas <b>directamente</b> en el texto (se guardan tal cual).

Ejemplo de cómo debe verse lo que pegas:
<pre>$ejemplo_todo</pre>

Envia el texto completo ahora (o /cancel para salir)."
            return
            ;;

        /edit_plantilla_*)
            if [[ -z "$auth_key" ]]; then return; fi
            local user_tipo_ep=$(obtener_tipo_user "$user_id")
            [[ "$user_tipo_ep" != "super" ]] && { tg_send "$chat_id" "⛔ Solo Super Admin."; return; }

            local bloque="${text#/edit_plantilla_}"
            local nombres_b="titulo|sep|reseller|id|key|install|compat|contacto|amigos|exp|by"
            if [[ ! "$bloque" =~ ^(${nombres_b//|/|})$ ]]; then
                tg_send "$chat_id" "❌ Bloque no valido."
                return
            fi
            set_state "$user_id" "edit_plantilla_${bloque}"
            tg_send_html "$chat_id" "✏️ Envia el <b>nuevo contenido del bloque</b> <code>$bloque</code>.

Puedes incluir emojis premium (los veras animados en el mensaje final).
Usa <code>{KEY}</code> <code>{ID}</code> <code>{RESELLER}</code> <code>{EXP}</code> <code>{E0}</code>..<code>{E10}</code> si los necesitas.

Hoy esta asi:
<pre>$(plantilla_block "$bloque" "(original)")</pre>

Envia /cancel para salir."
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
        key_info=$(fb_get "licencias_movivip/$key_del" 2>/dev/null)
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
        current_info=$(fb_get "licencias_movivip/$key_renovar" 2>/dev/null)
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
                fb_patch "licencias_movivip/$key_renovar" "$patch_body" >/dev/null 2>&1
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

        # Menu completo de botones (igual que /start autenticado)
        local kb
        if [[ "$tipo_key" == "super" ]]; then
            kb=$(kb_inline \
                "🆕 Generar Cliente|/gen_cliente" \
                "🏷️ Generar Proveedor|/gen_proveedor" \
                "🎁 Generar Regalo|/gen_regalo" \
                "📢 Canales|/canales" \
                "🎨 Emojis Premium|/emojis" \
                "📝 Plantilla|/plantilla" \
                "🔄 Renovar Key|/renovar_menu" \
                "📋 Ver Keys|/keys" \
                "📊 Stats|/stats" \
                "🎯 ID Proveedor Bot|/set_prov_menu" \
                "🚪 Cerrar Sesion|/cerrar")
        else
            kb=$(kb_inline \
                "🆕 Generar Cliente|/gen_cliente" \
                "🔄 Renovar Key|/renovar_menu" \
                "📋 Ver Keys|/keys" \
                "📊 Stats|/stats" \
                "🚪 Cerrar Sesion|/cerrar")
        fi

        tg_send_buttons "$chat_id" "
✅ <b>Autenticado!</b>

🔑 Key: <code>$key_auth</code>
👤 Tipo: <b>$tipo_key</b>

<b>Selecciona una opcion:</b>" "$kb" "html"
        return
    fi

    # ═══ RENOVAR MENU (botones) ═══
    if [[ "$text" == "/renovar_menu" ]]; then
        tg_send "$chat_id" "🔄 Envia: /renovar KEY-XXXXXXXXXX"
        return
    fi

    # ═══ STATE MACHINE (flujo interactivo) ═══
    case "$state" in
        # --- Captura de emojis premium (custom emoji) ---
        esperando_prov_bot)
            local prov_bot_id="$text"
            [[ ! "$prov_bot_id" =~ ^[0-9]+$ ]] && tg_send "$chat_id" "❌ ID invalido. Envia solo numeros." && return
            mkdir -p "$STATE_DIR"
            echo "$prov_bot_id" > "$PROV_FILE"
            clear_user "$user_id"
            local kb_pv
            kb_pv=$(kb_inline "🏠 Menu|/menu")
            tg_send_buttons "$chat_id" "✅ <b>Proveedor del bot configurado:</b> <code>$prov_bot_id</code>

A partir de ahora cada key de regalo generada se le envia automaticamente." "$kb_pv" "html"
            return
            ;;

        esperando_emojis)
            if [[ -z "$emojis_json" || "$emojis_json" == "[]" || "$emojis_json" == "null" ]]; then
                tg_send_html "$chat_id" "❌ No detecté custom emojis en ese mensaje.

Envia los <b>emojis animados de tu pack premium</b> (los que se envían como sticker de emoji, con animación).

Puedes mandarlos <b>por partes</b>: cada mensaje agrega emojis al siguiente slot libre.
Cuando termines, envia /listo_emojis (o /reset_emojis para reiniciar desde cero)."
                return
            fi
            # ══ FIX v3: CADA MENSAJE = UN SLOT (secuencia completa junta) ══
            # Los emojis visuales (barra destellos, fuego, etc.) son VARIOS custom emoji pegados.
            # Guardamos TODOS los IDs del mensaje juntos en el siguiente slot libre, separados por coma.
            local next_slot=0
            if [[ -f "$EMOJIS_FILE" ]]; then
                next_slot=$(awk -F= '!/^#/ && NF>1 {n++} END {print n+0}' "$EMOJIS_FILE")
            fi
            local secuencia
            secuencia=$(echo "$emojis_json" | python3 -c "
import json, sys
ids = json.load(sys.stdin)
print(','.join(ids))
" 2>/dev/null)
            if [[ -z "$secuencia" ]]; then
                tg_send_html "$chat_id" "❌ No detecté custom emojis en ese mensaje."; return
            fi
            echo "${next_slot}=${secuencia}" >> "$EMOJIS_FILE" 2>/dev/null
            local ncapt=0
            [[ -f "$EMOJIS_FILE" ]] && ncapt=$(grep -c '^[0-9]\+=' "$EMOJIS_FILE" 2>/dev/null || echo 0)
            local nids=$(echo "$secuencia" | tr ',' '\n' | grep -c . )
            tg_send_html "$chat_id" "✅ <b>Slot ${next_slot} guardado</b> con ${nids} custom emoji en secuencia (quedan juntos).

<b>${ncapt} slots configurados</b> (0=✨ 1=✅ 2=🎁 3=🔑 4=🔥 5=☄️ 6=⚠️ 7=🌟 8=➡️ 9=⬅️).
Puedes <b>seguir enviando</b> el siguiente emoji de tu pack (1 mensaje = 1 slot).
Cuando termines, envia <b>/listo_emojis</b>."
            return
            ;;

        edit_plantilla_*)
            if [[ -z "$auth_key" ]]; then return; fi
            local user_tipo_ep=$(obtener_tipo_user "$user_id")
            [[ "$user_tipo_ep" != "super" ]] && { clear_user "$user_id"; return; }

            local bloque="${state#edit_plantilla_}"

            # ══ MODO TODO: el usuario pegó el texto COMPLETO en un mensaje ══
            if [[ "$bloque" == "todo" ]]; then
                if [[ "$text" == "/cancel" ]]; then
                    clear_user "$user_id"
                    tg_send "$chat_id" "❌ Edicion cancelada."
                    return
                fi
                # Guardar exactamente lo que el usuario pegó (html_text ya trae emojis inline + tags preservados)
                local nuevo_todo="$html_text"
                [[ -z "$nuevo_todo" ]] && nuevo_todo="$text"
                printf '%s' "$nuevo_todo" > "$PLANTILLA_DIR/todo"
                clear_user "$user_id"
                # Mostrar la plantilla completa resultante
                local preview_todo
                preview_todo=$(plantilla_key "ABC123DEF456GHI789JKL012MNO345PQR678STU9" "ABCD" "4 horas" "MoviVIP Network")
                local kb_pt
                kb_pt=$(kb_inline \
                    "✏️ Editar otra parte|/plantilla" \
                    "🏠 Menu|/menu")
                tg_send_buttons "$chat_id" "✅ <b>Plantilla completa guardada.</b>

👇 <b>Así queda (key de ejemplo):</b>
$preview_todo" "$kb_pt" "html"
                return
            fi

            if [[ "$text" == "/cancel" ]]; then
                clear_user "$user_id"
                tg_send "$chat_id" "❌ Edicion cancelada."
                return
            fi
            # Guardar: si el mensaje trae emojis premium usar html_text (con <tg-emoji> inline ya escapado),
            # si no trae emojis, escapar HTML del texto plano (a menos que contenga etiquetas intencionales)
            local nuevo_valor="$text"
            if [[ -n "$html_text" && -n "$emojis_json" && "$emojis_json" != "[]" && "$emojis_json" != "null" ]]; then
                nuevo_valor="$html_text"
            else
                nuevo_valor=$(echo "$text" | python3 -c "
import sys, html, re
t = sys.stdin.read()
# Si ya hay etiquetas HTML intencionales (<b>, <i>, <code>...) se respetan;
# solo se escapan los caracteres peligrosos sueltos & < > que no forman tag
t = re.sub(r'&(?!(amp|lt|gt|quot|#\d+);)', '&amp;', t)
t = re.sub(r'<(?![a-zA-Z/!])', '&lt;', t)
t = re.sub(r'>(?![^<]*<)', '&gt;', t)
print(t, end='')
")
            fi
            printf '%s' "$nuevo_valor" > "$PLANTILLA_DIR/$bloque"
            clear_user "$user_id"
            # ══ Mostrar la plantilla COMPLETA actualizada (texto renderizado), no un menu ══
            local preview_edit
            preview_edit=$(plantilla_key "ABC123DEF456GHI789JKL012MNO345PQR678STU9" "ABCD" "4 horas" "MoviVIP Network")
            local kb_pe
            kb_pe=$(kb_inline \
                "✏️ Editar otra parte|/plantilla" \
                "🏠 Menu|/menu")
            tg_send_buttons "$chat_id" "✅ Bloque <b><code>$bloque</code></b> actualizado.

👇 <b>Plantilla completa (key de ejemplo):</b>
$preview_edit" "$kb_pe" "html"
            return
            ;;

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

                # Determinar reseller: super -> MoviVIP Network; proveedor -> su nombre (campo cliente)
                local reseller_gen="MoviVIP Network"
                local tipo_gen=$(obtener_tipo_user "$user_id")
                if [[ "$tipo_gen" != "super" ]]; then
                    local json_gen
                    json_gen=$(obtener_key_info "$auth_key" 2>/dev/null)
                    local nombre_gen
                    nombre_gen=$(echo "$json_gen" | python3 -c "
import sys, json
try:
    d = json.loads('''$json_gen''')
    print(d.get('cliente','').upper())
except:
    print('')
" 2>/dev/null)
                    [[ -n "$nombre_gen" && "$nombre_gen" != "NONE" ]] && reseller_gen="$nombre_gen"
                fi

                # Texto de expiracion
                local exp_text_gen="$dias dias"
                [[ "$plan" == "vitalicio" || "$dias" == "36500" ]] && exp_text_gen="vitalicio (no expira)"

                local lim_text="Infinito"
                [[ "$max_gen" -gt 0 ]] && lim_text="$max_gen usos"

                # id corto (igual que generar_licencia: primeros 4 alfanum del cliente)
                local id_short
                id_short=$(echo "$cliente" | tr -cd 'A-Za-z0-9' | head -c 4)
                [[ -z "$id_short" ]] && id_short="KVN1"

                # Enviar plantilla premium completa (v2)
                local plantilla_txt
                plantilla_txt=$(plantilla_key "$key_resultado" "$id_short" "$exp_text_gen" "$reseller_gen")
                tg_send_html "$chat_id" "$plantilla_txt"

                local kb
                kb=$(kb_inline \
                    "🆕 Generar otra|/generar" \
                    "📋 Ver keys|/keys" \
                    "🏠 Menu|/menu")
                tg_send_buttons "$chat_id" "📋 <b>Resumen:</b>

Cliente: <b>$cliente</b> · Plan: <b>$plan</b> · Validez: <b>$dias dias</b> · Limite: <b>$lim_text</b>" "$kb" "html"
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
# Cliente/regalo -> KEY v2 corta (40 chars, formato oficial generador-keys-v2.ps1)
# Proveedor     -> KEY-xxxxxx legacy (se genera en su propio flujo)
generar_licencia() {
    local key_mayorista="$1" cliente="$2" plan="$3" dias="$4" max_gen="${5:-0}"
    local prov_tg_id="${6:-}"
    local ahora=$(date +%s)
    local expira=0
    [[ "$plan" != "vitalicio" ]] && expira=$((ahora + dias * 86400))

    # id corto: primeros 4 alfanum del cliente (ej: "Kevin" -> "Kevi")
    local id_short
    id_short=$(echo "$cliente" | tr -cd 'A-Za-z0-9' | head -c 4)
    [[ -z "$id_short" ]] && id_short="KVN1"

    # plan_code v2 = 1 (bronce, mismo que generador PS oficial)
    # vitalicio -> exp=0 -> el runner muestra "Expires: never" (probado)
    local key
    key=$(generar_key_v2 "$id_short" "$expira" 1)
    [[ -z "$key" ]] && { echo "ERROR_GENERAR_V2"; return 1; }
    [[ -z "$cliente" ]] && cliente="anonimo"

    # Path Firebase = key url-safe (las v2 contienen '+' y '/')
    local key_path
    key_path=$(fb_key_path "$key")

    # Store in Firebase (path url-safe + key_real = key visible con +/)
    insertar_key "$key_path" "cliente" "$plan" 1 "$ahora" "$expira" "$cliente" "$key_mayorista" "$prov_tg_id" "$max_gen" "$key"

    echo "$key"
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

# ================= PUBLICACION EN CANALES =================
# Emojis premium: custom_emoji_id capturados via /emojis (slots 0..10)
# FIX v3: un slot = SECUENCIA COMPLETA (ids separados por coma). Se emite un <tg-emoji> por cada id.
emoji_slot() {
    local slot="$1" fallback="$2" raw out="" id
    # Importante: tomar SOLO la primera línea del slot (defensa contra duplicados viejos)
    raw=$(grep -P "^${slot}=" "$EMOJIS_FILE" 2>/dev/null | head -n1 | cut -d= -f2-)
    if [[ -n "$raw" ]]; then
        # Iterar sobre los ids separados por coma
        out=""
        while IFS=',' read -ra ids_arr; do
            for id in "${ids_arr[@]}"; do
                id=$(echo "$id" | tr -d '[:space:]')
                [[ -z "$id" ]] && continue
                out+="<tg-emoji emoji-id=\"$id\">$fallback</tg-emoji>"
            done
        done <<< "$raw"
        if [[ -n "$out" ]]; then
            echo "$out"
        else
            echo "$fallback"
        fi
    else
        echo "$fallback"
    fi
}

# Registrar canal/grupo detectado (via update my_chat_member)
chat_detect() {
    local chat_id="$1" tipo="$2" titulo="$3" username="$4" status="$5"
    [[ -z "$chat_id" ]] && return
    local linea="$chat_id|$tipo|$titulo|$username|$status"
    if [[ -f "$CANALES_FILE" ]] && grep -qP "^${chat_id}\|" "$CANALES_FILE" 2>/dev/null; then
        grep -vP "^${chat_id}\|" "$CANALES_FILE" > "$CANALES_FILE.tmp" 2>/dev/null
        mv "$CANALES_FILE.tmp" "$CANALES_FILE" 2>/dev/null
    fi
    echo "$linea" >> "$CANALES_FILE"
    log "Chat detectado: ${tipo} ${titulo} (${chat_id}) status=${status}"
}

# ================= AUTO-SCAN DE CANALES =================
# Escanea la lista AUTO_CANALES_FILE via getChat/getChatMember.
# Asi el bot detecta canales donde YA esta agregado SIN depender de eventos
# puntuales my_chat_member (que Telegram no reenvia retroactivamente).
auto_scan_canales() {
    local c_ref c_resp c_ok c_id c_type c_title c_user c_me c_status found=0 dirty=0
    while IFS= read -r c_ref; do
        c_ref=$(echo "$c_ref" | tr -d '[:space:]')
        [[ -z "$c_ref" || "$c_ref" == \#* ]] && continue

        # getChat
        c_resp=$(curl -s --max-time 10 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/getChat" \
            --data-urlencode "chat_id=$c_ref" 2>/dev/null)
        c_ok=$(echo "$c_resp" | grep -oP '"ok"\s*:\s*(true|false)' | sed 's/.*:\s*//')
        [[ "$c_ok" != "true" ]] && continue

        c_id=$(echo "$c_resp" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['id'])" 2>/dev/null)
        c_type=$(echo "$c_resp" | python3 -c "import sys,json; print(json.load(sys.stdin)['result'].get('type',''))" 2>/dev/null)
        c_title=$(echo "$c_resp" | python3 -c "import sys,json; print(json.load(sys.stdin)['result'].get('title','') or '')" 2>/dev/null)
        c_user=$(echo "$c_resp" | python3 -c "import sys,json; print(json.load(sys.stdin)['result'].get('username','') or '')" 2>/dev/null)
        [[ -z "$c_id" ]] && continue

        # getChatMember del propio bot
        c_status="member"
        c_me=$(curl -s --max-time 10 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/getChatMember" \
            --data-urlencode "chat_id=$c_id" --data-urlencode "user_id=$BOT_ID" 2>/dev/null)
        if echo "$c_me" | grep -q '"ok"\s*:\s*true'; then
            c_status=$(echo "$c_me" | python3 -c "import sys,json; print(json.load(sys.stdin)['result'].get('status','member'))" 2>/dev/null)
        fi

        # Solo registrar si es canal/grupo real y el bot esta DENTRO (no left)
        if [[ "$c_status" != "left" && "$c_status" != "kicked" ]] && \
           [[ "$c_type" == "channel" || "$c_type" == "supergroup" || "$c_type" == "group" ]]; then
            chat_detect "$c_id" "$c_type" "$c_title" "$c_user" "$c_status"
            found=$((found + 1))
        fi
    done < "$AUTO_CANALES_FILE"

    log "Auto-scan canales: ${found} detectados"
}

# ================= AGREGAR AL AUTO-SCAN =================
auto_canales_add() {
    local ref="$1"
    ref=$(echo "$ref" | tr -d '[:space:]')
    [[ -z "$ref" ]] && return 1
    if grep -qxF "$ref" "$AUTO_CANALES_FILE" 2>/dev/null; then
        return 2
    fi
    echo "$ref" >> "$AUTO_CANALES_FILE"
    return 0
}

# Plantilla completa de key (HTML + custom emojis premium + bloque copiar)
# uso regalo:  plantilla_key "$key" "$id" "4hs" "MoviVIP Network"
# uso cliente: plantilla_key "$key" "$id" "30 dias" "RESELLER NAME"
#
# La plantilla es EDITABLE por el super via /plantilla:
# - Cada bloque del mensaje se guarda como archivo en $PLANTILLA_DIR/
# - Si un bloque no existe, se usa el default de abajo
# - Placeholders: {KEY} {ID} {RESELLER} {EXP} {E0}..{E10} (emojis premium)
plantilla_block() {
    local block="$1" default_text="$2"
    if [[ -s "$PLANTILLA_DIR/$block" ]]; then
        cat "$PLANTILLA_DIR/$block"
    else
        echo "$default_text"
    fi
}

plantilla_render() {
    local key="$1" id_short="$2" exp_text="$3" reseller="$4"
    local INSTALL="apt-get update -y && apt-get install -y curl; rm -rf /root/install.sh; wget --no-cache -O /root/install.sh https://github.com/studioanime977/MoviVIPNetwork/releases/download/v2.0.2/install.sh; chmod +x /root/install.sh; /root/install.sh"
    local B_SEP B_TITULO B_RESELLER B_ID B_KEY B_INSTALL B_COMP B_CONT B_AMI B_EXP B_BY

    # ══ MODO TODO: si el super pegó el texto completo en un solo archivo, se usa tal cual ══
    local out_txt
    if [[ -s "$PLANTILLA_DIR/todo" ]]; then
        out_txt=$(cat "$PLANTILLA_DIR/todo")
    else
        # Modo por bloques (cada sección editable por separado)
        B_SEP=$(plantilla_block "sep" "━━━━━━━━━━━━━━━")
        B_TITULO=$(plantilla_block "titulo" "{E0} Key MoviVIP Network V6.2 generada {E0}")
        B_RESELLER=$(plantilla_block "reseller" "Reseller: {RESELLER}")
        B_ID=$(plantilla_block "id" "{E1}: <code>{ID}</code>")
        B_KEY=$(plantilla_block "key" "KEY: <code>{KEY}</code>")
        B_INSTALL=$(plantilla_block "install" "<pre>{INSTALL}</pre>")
        B_COMP=$(plantilla_block "compat" "▎◆ {E3} COMPATIBILIDAD TOTAL (SERVIDOR) ──────────────────────────────────────────────────────────────────
   SO:  ✅ Ubuntu 20.04·22.04·24.04   ✅ Debian 11·12
   Arq: ✅ x86_64/amd64  ✅ ARM64/aarch64  ⚠️ ARMv7/i386
   Nube: ☁ Oracle Cloud (A1/Flex) · AWS Graviton · Google Cloud
        Azure · DigitalOcean · Vultr · Hetzner · Contabo
   Virtualización: KVM ✅ · LXC/OpenVZ 7+ parcial
   Nota: motor API Access (bots) = binario x86_64 (ARM vía qemu)")
        B_CONT=$(plantilla_block "contacto" "▎◆ {E4} CONTACTO OFICIAL ─────────────────────────────────────────────────────────────────────────────────
   {E6} Canal oficial ....... t.me/MoviVIPNetwork
   {E7} Grupo oficial ........ t.me/MoviVIPNet
   {E8} Soporte directo ...... @MoviVIP  (t.me/MoviVIP)
   {E9} Sitio web ............ https://movivip-network.web.app
   {E10} WhatsApp ............. +57 311 700 8185")
        B_AMI=$(plantilla_block "amigos" "▎◆ {E5} CANALES AMIGOS (FreeNetZone) ─────────────────────────────────────────────────────────────────────
   Canal oficial t.me/FreeNetZonevip   ·  Grupo oficial t.me/FreeNetZonevips")
        B_EXP=$(plantilla_block "exp" "Esta key expira en {EXP}")
        B_BY=$(plantilla_block "by" "➡️ By : @MoviVIP {E2} ⬅️")

        out_txt=$(printf '%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s' \
            "$B_SEP" "$B_TITULO" "$B_SEP" "$B_RESELLER" "$B_SEP" "$B_ID" "$B_SEP" "$B_KEY" "$B_SEP" "$B_INSTALL" "$B_SEP" "$B_COMP" "$B_SEP" "$B_CONT" "$B_SEP" "$B_AMI" "$B_SEP" "$B_EXP" "$B_BY")
    fi

    # Sustitución de placeholders {KEY} {ID} {RESELLER} {EXP} {INSTALL} via python (seguro)
    local PYKEY=$(printf '%s' "$key" | python3 -c "import sys; print(sys.stdin.read().replace(chr(39), chr(92)+chr(39)))")
    local PYID=$(printf '%s' "$id_short" | python3 -c "import sys; print(sys.stdin.read().replace(chr(39), chr(92)+chr(39)))")
    local PYEXP=$(printf '%s' "$exp_text" | python3 -c "import sys; print(sys.stdin.read().replace(chr(39), chr(92)+chr(39)))")
    local PYRES=$(printf '%s' "$reseller" | python3 -c "import sys; print(sys.stdin.read().replace(chr(39), chr(92)+chr(39)))")
    local PYINST=$(printf '%s' "$INSTALL" | python3 -c "import sys; print(sys.stdin.read().replace(chr(39), chr(92)+chr(39)))")
    out_txt=$(echo "$out_txt" | KEY="$PYKEY" ID="$PYID" EXP="$PYEXP" RES="$PYRES" INST="$PYINST" python3 -c "
import os, sys
t = sys.stdin.read()
t = t.replace('{KEY}', os.environ['KEY'])
t = t.replace('{ID}', os.environ['ID'])
t = t.replace('{RESELLER}', os.environ['RES'])
t = t.replace('{EXP}', os.environ['EXP'])
t = t.replace('{INSTALL}', os.environ['INST'])
print(t, end='')
")
    # Completar {E0}..{E10} con emojis premium (fallback normal si no configurado)
    local i2 E2
                local -a FB=("✨" "✅" "🎁" "🔑" "🔥" "☄️" "⚠️" "🌟" "➡️" "⬅️" "💬")
    for i2 in $(seq 0 10); do
        E2=$(emoji_slot "$i2" "${FB[$i2]}")
        out_txt=${out_txt//\{E${i2}\}/$E2}
    done
    echo "$out_txt"
}

plantilla_key() {
    local key="$1" id_short="$2" exp_text="${3:-4hs}" reseller="${4:-MoviVIP Network}"

    # Render editable (usa bloques $PLANTILLA_DIR si existen, si no defaults)
    plantilla_render "$key" "$id_short" "$exp_text" "$reseller"
}

# Enviar plantilla a un chat (canal/grupo/admin) con HTML
# exph: "4hs" o "4" (si numero -> se agrega hs) o "30 dias"
# from_chat: opcional. Privado del propietario desde el que se reenvia (forward)
#            para conservar los emojis premium animados en canales/grupos.
publicar_plantilla() {
    local chat_id="$1" key="$2" id_short="$3" exph="$4" from_chat="${5:-}"
    local exp_text="$exph"
    [[ "$exph" =~ ^[0-9]+$ ]] && exp_text="${exph}hs"
    local txt
    txt=$(plantilla_key "$key" "$id_short" "$exp_text")

    # Flujo forward (conserva emojis premium): enviar al privado del propietario
    # y reenviar al destino, borrando luego el intermedio.
    if [[ -n "$from_chat" ]]; then
        local temp_resp temp_mid
        temp_resp=$(curl -s --max-time 15 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
            --data-urlencode "chat_id=$from_chat" --data-urlencode "text=$txt" \
            -d "parse_mode=HTML" -d "disable_web_page_preview=true" 2>/dev/null)
        temp_mid=$(echo "$temp_resp" | grep -oP '"message_id"\s*:\s*\K[0-9]+' | head -1)
        if [[ -n "$temp_mid" ]]; then
            local resp_fw
            resp_fw=$(curl -s --max-time 15 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/forwardMessage" \
                --data-urlencode "chat_id=$chat_id" \
                --data-urlencode "from_chat_id=$from_chat" \
                --data-urlencode "message_id=$temp_mid" 2>/dev/null)
            # Borrar el mensaje intermedio del privado para no dejar duplicados
            curl -s --max-time 10 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/deleteMessage" \
                --data-urlencode "chat_id=$from_chat" \
                --data-urlencode "message_id=$temp_mid" >/dev/null 2>&1
            echo "$resp_fw"
            return
        fi
    fi

    # Fallback: envio directo al destino
    local resp
    resp=$(curl -s --max-time 15 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=$chat_id" --data-urlencode "text=$txt" \
        -d "parse_mode=HTML" -d "disable_web_page_preview=true" 2>/dev/null)
    echo "$resp"
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
    json_data=$(fb_get "licencias_movivip" 2>/dev/null)

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
    local cb_id="$1" chat_id="$2" user_id="$3" data="$4" cb_mid="${5:-}"

    log "CB @$user_id: $data"

    case "$data" in
        /auth_menu)
            tg_answer_cb "$cb_id" "Envia /auth TU_KEY"
            tg_send "$chat_id" "🔑 Envia tu key: /auth KEY-XXXXX"
            return
            ;;
        /menu|/start)
            # Redirigir al handler de mensajes: el decide si muestra panel
            # de control (autenticado) o menu de autenticar (no autenticado)
            handle_message "$chat_id" "$user_id" "" "/menu"
            tg_answer_cb "$cb_id" "Menu"
            return
            ;;
        /generar|/gen_proveedor|/gen_cliente|/gen_regalo|/canales|/agregar_canal|/auto_canales|/emojis|/reset_emojis|/listo_emojis|/plantilla|/plantilla_todo|/plantilla_reset|/renovar_menu|/stats|/keys|/cerrar|/cancel|/regalo_auto|/set_prov_menu)
            # Redirect to message handler
            handle_message "$chat_id" "$user_id" "" "$data"
            tg_answer_cb "$cb_id" ""
            return
            ;;
        /plan_*|/dias_*|/lim_*|/edit_plantilla_*)
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
            key_info=$(fb_get "licencias_movivip/$(fb_key_path "$key_del")" 2>/dev/null)
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

        /pub_all)
            if [[ -z "$LAST_GEN_KEY" ]]; then
                tg_answer_cb "$cb_id" "Primero genera una key con /gen_regalo"
                return
            fi
            tg_answer_cb "$cb_id" "Publicando en todos..."

            local exph_a=$(( (LAST_GEN_EXP - $(date +%s)) / 3600 ))
            [[ "$exph_a" -lt 1 ]] && exph_a=1

            local ok_all=0 fail_all=0 lista_ok="" lista_fail=""
            if [[ ! -f "$CANALES_FILE" ]]; then
                tg_send_html "$chat_id" "📭 <b>No hay canales detectados.</b>

Usa /auto_canales o agrega el bot a canales/grupos."
                return
            fi

            while IFS='|' read -r cid_a ctype_a ctitle_a cuser_a cstatus_a; do
                [[ -z "$cid_a" ]] && continue
                # Saltar chats donde el bot ya no esta
                if [[ "$cstatus_a" == "left" || "$cstatus_a" == "kicked" ]]; then
                    log "Pub-all: omitido ${ctitle_a:-?} status=${cstatus_a}"
                    continue
                fi
                local resp_a mid_a
                resp_a=$(publicar_plantilla "$cid_a" "$LAST_GEN_KEY" "$LAST_GEN_ID" "$exph_a" "$chat_id")
                mid_a=$(echo "$resp_a" | grep -oP '"message_id"\s*:\s*\K[0-9]+' | head -1)
                if [[ -n "$mid_a" ]]; then
                    ok_all=$((ok_all + 1))
                    lista_ok+="• ${ctitle_a:-chat} (${ctype_a})
"
                    log "Key publicada en ${ctitle_a} (${cid_a}) msg=${mid_a}"
                else
                    fail_all=$((fail_all + 1))
                    lista_fail+="• ${ctitle_a:-chat} (${ctype_a}) — ${cstatus_a:-?}
"
                    log_err "Publicacion fallida en ${cid_a}: ${resp_a}"
                fi
            done < "$CANALES_FILE"

            local resumen_all="✅ <b>Publicada en ${ok_all} chat(s)</b>
${lista_ok}"
            if [[ $fail_all -gt 0 ]]; then
                resumen_all+="

⚠️ <b>Fallo en ${fail_all} (no admin o sin permiso):</b>
${lista_fail}
Haz admin al bot en esos chats o verifica permisos."
            fi
            resumen_all+="

🎁 KEY: <code>$LAST_GEN_KEY</code>"
            tg_send_html "$chat_id" "$resumen_all"
            return
            ;;

        /pub_*)
            local pub_n="${data#/pub_}"
            if [[ -z "$LAST_GEN_KEY" ]]; then
                tg_answer_cb "$cb_id" "Primero genera una key con /gen_regalo"
                return
            fi

            if [[ "$pub_n" == "none" ]]; then
                tg_answer_cb "$cb_id" "Enviando key aqui"
                # Enviar la plantilla COMPLETA como RESPUESTA (reply) con barra vertical citada
                local exph_none=$(( (LAST_GEN_EXP - $(date +%s)) / 3600 ))
                [[ "$exph_none" -lt 1 ]] && exph_none=1
                local txt_none reply_none extra_rep_none=""
                txt_none=$(plantilla_key "$LAST_GEN_KEY" "$LAST_GEN_ID" "${exph_none}hs")
                local reply_target="${cb_mid:-$LAST_MSG_ID}"
                [[ -n "$reply_target" ]] && extra_rep_none="-d reply_to_message_id=$reply_target"
                reply_none=$(curl -s --max-time 15 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
                    --data-urlencode "chat_id=$chat_id" --data-urlencode "text=$txt_none" \
                    -d "parse_mode=HTML" -d "disable_web_page_preview=true" \
                    ${extra_rep_none} 2>/dev/null)
                local mid_none
                mid_none=$(echo "$reply_none" | grep -oP '"message_id"\s*:\s*\K[0-9]+' | head -1)
                if [[ -n "$mid_none" ]]; then
                    tg_send_html "$chat_id" "✅ Key enviada aqui (responde a tu mensaje con la barrita). Puedes copiarla desde ahi."
                else
                    tg_send_html "$chat_id" "⚠️ <b>Error enviando la key.</b>  🎁 KEY: <code>$LAST_GEN_KEY</code>"
                fi
                return
            fi

            # Buscar canal/grupo por índice
            local idx_p=0 cid_p="" ctitle_p=""
            while IFS='|' read -r cid2 ctype2 ctitle2 cuser2 cstatus2; do
                if [[ "$idx_p" == "$pub_n" ]]; then
                    cid_p="$cid2"; ctitle_p="${ctitle2:-chat $pub_n}"
                    break
                fi
                idx_p=$((idx_p + 1))
            done < "$CANALES_FILE"

            if [[ -z "$cid_p" ]]; then
                tg_answer_cb "$cb_id" "Canal no encontrado"
                return
            fi

            tg_answer_cb "$cb_id" "Publicando en ${ctitle_p}..."

            local exph_p=$(( (LAST_GEN_EXP - $(date +%s)) / 3600 ))
            [[ "$exph_p" -lt 1 ]] && exph_p=1

            local resp_p mid_p user_p
            resp_p=$(publicar_plantilla "$cid_p" "$LAST_GEN_KEY" "$LAST_GEN_ID" "$exph_p" "$chat_id")
            mid_p=$(echo "$resp_p" | grep -oP '"message_id"\s*:\s*\K[0-9]+' | head -1)
            user_p=$(echo "$resp_p" | grep -oP '"username"\s*:\s*"\K[^"]+' | head -1)

            if [[ -n "$mid_p" ]]; then
                tg_send_html "$chat_id" "✅ <b>Publicada en:</b> ${ctitle_p}

<a href=\"https://t.me/${user_p:-c}/${mid_p}\">Ver mensaje publicado</a>"
                log "Key publicada en ${ctitle_p} (${cid_p}) msg=${mid_p}"
            else
                tg_send_html "$chat_id" "⚠️ <b>Error publicando en:</b> ${ctitle_p}

Verifica que este bot sea <b>administrador del canal</b> (o tenga permisos para enviar en el grupo).

La key sigue disponible: <code>$LAST_GEN_KEY</code>"
                log_err "Publicacion fallida en ${cid_p}: ${resp_p}"
            fi
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

    # Super admin key real (KEY-37549D57B2) ensure en licencias_movivip
    local super_key="KEY-37549D57B2"
    local existing_super
    existing_super=$(fb_get "licencias_movivip/$super_key" 2>/dev/null)
    if [[ -z "$existing_super" || "$existing_super" == "null" ]]; then
        insertar_key "$super_key" "super" "vitalicio" 1 0 0 "SUPERADMIN-KEVIN" "MANUAL-RECUPERACION" "" 0
        log "Super key $super_key creada en licencias_movivip"
    fi
    log "Super admin keys OK ($super_key)"

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

    # Auto-scan de canales al arrancar (detecta donde el bot YA esta agregado)
    auto_scan_canales
    local cycle_count=0

    while true; do
        if [[ -f "$OFFSET_FILE" ]]; then
            OFFSET=$(cat "$OFFSET_FILE")
        else
            OFFSET=0
        fi

        # Cada 30 ciclos (~sin espera) o ~2.5 min, re-escanear canales conocidos
        cycle_count=$((cycle_count + 1))
        if [[ $((cycle_count % 30)) -eq 0 ]]; then
            auto_scan_canales
            cycle_count=0
        fi

        local response
        response=$(curl -s --max-time $((POLL_TIMEOUT + 10)) \
            "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates" \
            -d "offset=$OFFSET" \
            -d "timeout=$POLL_TIMEOUT" \
            -d "allowed_updates=[\"message\",\"callback_query\",\"my_chat_member\"]" 2>/dev/null)

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
        while IFS='|' read -r type uid chat_id user_id username extra1 extra2 extra3 extra4; do
            case "$type" in
                MSG)
                    # Restaurar pipes escapados (¦ -> |) en texto y html
                    extra1=${extra1//¦/|}
                    extra4=${extra4//¦/|}
                    handle_message "$chat_id" "$user_id" "$username" "$extra1" "$extra3" "$extra4"
                    ;;
                CB)
                    handle_callback "$extra2" "$chat_id" "$user_id" "$extra1" "$extra3"
                    ;;
                CHAT)
                    chat_detect "$chat_id" "$user_id" "$username" "$extra1" "$extra2"
                    ;;
            esac
        done < <(echo "$response" | python3 -c "
import json, sys
try:
    # Forzar UTF-8 en stdout (evita crashes en consolas cp1252)
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
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
            # Custom emoji IDs (emojis premium/animados del admin)
            emojis = []
            # Reconstruir texto HTML con <tg-emoji> inline (para plantilla editable)
            import html as _html
            import re as _re
            # Escape INTELIGENTE: preserva tags HTML intencionales (<b>, <i>, <code>, <pre>, <a>, <tg-emoji>)
            # y escapa solo los caracteres peligrosos sueltos (& < > que no forman tag)
            _known_tag = _re.compile(r'</?(?:b|i|u|s|code|pre|a|tg-emoji)(?:\s+[^<>]*)?>', _re.I)
            def _smart(s):
                _o = []
                _l = 0
                for _m in _known_tag.finditer(s):
                    _o.append(_html.escape(s[_l:_m.start()]))
                    _o.append(_m.group(0))
                    _l = _m.end()
                _o.append(_html.escape(s[_l:]))
                return ''.join(_o)
            entities = sorted([e for e in msg.get('entities', [])
                               if e.get('type') == 'custom_emoji' and e.get('custom_emoji_id')],
                              key=lambda e: e.get('offset', 0))
            html = ''
            prev = 0
            for e in entities:
                off = e.get('offset', 0)
                ln = e.get('length', 0)
                eid = e.get('custom_emoji_id', '')
                if off < prev:
                    continue
                seg = _smart(text[prev:off])
                raw = _html.escape(text[off:off + ln] or 'x')
                html += seg + f'<tg-emoji emoji-id="{eid}">{raw}</tg-emoji>'
                emojis.append(eid)
                prev = off + ln
            html += _smart(text[prev:])
            text_out = text.replace('|', '¦')
            html_out = html.replace('|', '¦')
            # FILTRO DE GRUPOS/CANALES: solo responder si el bot fue llamado
            # (mencion @MovivipKeygen_bot, comando /, text_mention al bot, o reply a un msg del bot)
            # chat_id < 0 => grupo/supergrupo/canal. Si NO fue llamado => ignorar por completo.
            _gchat = msg['chat']['id']
            if _gchat < 0:
                _called = False
                _all_ent = msg.get('entities', []) or []
                for _e in _all_ent:
                    _t = _e.get('type', '')
                    _off = _e.get('offset', 0)
                    _len = _e.get('length', 0)
                    _sl = text[_off:_off + _len]
                    if _t == 'bot_command' and _sl.startswith('/'):
                        _called = True
                        break
                    if _t == 'mention' and _sl.lower() == '@movivipkeygen_bot':
                        _called = True
                        break
                    if _t == 'text_mention' and _e.get('user', {}).get('id') == 8808614399:
                        _called = True
                        break
                if not _called:
                    _rt = msg.get('reply_to_message') or {}
                    if _rt.get('from', {}).get('id') == 8808614399:
                        _called = True
                if not _called:
                    continue
            print(f'MSG|{uid}|{msg[\"chat\"][\"id\"]}|{user.get(\"id\",\"\")}|{user.get(\"username\",\"\")}|{text_out}|{mid}|{json.dumps(emojis)}|{html_out}')

        # my_chat_member: bot agregado/quita de canales/grupos
        mcm = update.get('my_chat_member')
        if mcm:
            chat = mcm.get('chat', {})
            ncm = mcm.get('new_chat_member', {})
            if ncm.get('user', {}).get('is_bot'):
                st = ncm.get('status', '')
                if st in ('member', 'administrator', 'creator'):
                    print(f'CHAT|{uid}|{chat.get(\"id\",\"\")}|{chat.get(\"type\",\"\")}|{chat.get(\"title\",\"\")}|{chat.get(\"username\",\"\")}|{st}')

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
