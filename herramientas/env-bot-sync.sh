#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════
# MoviVIP env-bot-sync — respaldo/restauración del .env-bot
# El contenido del .env-bot se guarda CIFRADO en Firebase
# (config_bot/env.b64, AES-256-CBC con la MASTER KEY del
#  servidor en /root/.master_key.b64 — nunca viaja en claro).
#
# Uso:
#   env-bot-sync.sh sync     → sube /etc/movivip/.env-bot cifrado a Firebase
#   env-bot-sync.sh restore  → baja config_bot/env.b64 y restaura .env-bot
#   env-bot-sync.sh show     → imprime el contenido descifrado (para /show_env)
#   env-bot-sync.sh check    → verifica si hay backup en Firebase
#
# Tambien se auto-integra en bot-generador.sh:
#   - Al arrancar, si falta /etc/movivip/.env-bot → restore automatico
#   - Comandos /sync_env /restore_env /show_env (solo super admin)
# ═══════════════════════════════════════════════════════════
set -uo pipefail

BASE="/etc/movivip"
ENV_BOT="$BASE/.env-bot"
SECRETS_SCRIPT="$BASE/descifrar-secrets.sh"
MASTER_KEY="${MOVIVIP_MASTER_KEY:-}"
MASTER_KEY_FILE="${MOVIVIP_MASTER_KEY_FILE:-/root/.master_key.b64}"
FB_BASE="movivip-network-default-rtdb.firebaseio.com"
FB_PATH="config_bot/env.b64"
LOG_FILE="/var/log/movivip-bot-generador.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; }
log_err() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERR: $1" >> "$LOG_FILE"; }

# ---------------- MASTER KEY ----------------
cargar_master_key() {
    [[ -n "$MASTER_KEY" ]] && return 0
    if [[ -f "$MASTER_KEY_FILE" && -r "$MASTER_KEY_FILE" ]]; then
        MASTER_KEY=$(tr -d '[:space:]' < "$MASTER_KEY_FILE")
    fi
    [[ -n "$MASTER_KEY" ]]
}

# ---------------- CREDENCIALES FIREBASE ----------------
# Para sync se usan las credenciales del .env-bot actual.
# Para restore se usan las del seed (sin BOT_TOKEN) si existen,
# porque el .env-bot puede haber desaparecido.
fb_creds_env() {
    local src="${1:-}" var api email pass ret=1
    if [[ -f "$src" ]]; then
        # shellcheck disable=SC1090
        source "$src" 2>/dev/null || true
    fi
    api="${MOVIVIP_FB_API_KEY:-${FB_API_KEY:-}}"
    email="${MOVIVIP_FB_AUTH_EMAIL:-${FB_AUTH_EMAIL:-}}"
    pass="${MOVIVIP_FB_AUTH_PASS:-${FB_AUTH_PASS:-}}"
    if [[ -n "$api" && -n "$email" && -n "$pass" ]]; then
        FB_API_KEY="$api"; FB_AUTH_EMAIL="$email"; FB_AUTH_PASS="$pass"; ret=0
    fi
    return $ret
}

fb_auth_token() {
    local now=$(date +%s) resp token
    if [[ -n "${FB_TOKEN_CACHE:-}" && "$now" -lt "${FB_TOKEN_EXPIRES:-0}" ]]; then
        echo "$FB_TOKEN_CACHE"; return 0
    fi
    resp=$(curl -s --max-time 10 -X POST \
        "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${FB_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "{\"email\":\"${FB_AUTH_EMAIL}\",\"password\":\"${FB_AUTH_PASS}\",\"returnSecureToken\":true}")
    token=$(echo "$resp" | grep -oP '"idToken"\s*:\s*"\K[^"]+')
    if [[ -n "$token" ]]; then
        FB_TOKEN_CACHE="$token"; FB_TOKEN_EXPIRES=$((now + 3500))
        echo "$token"; return 0
    fi
    return 1
}

# ---------------- CIFRADO ----------------
# Cifra stdin -> base64 de una linea en stdout (AES-256-CBC + pbkdf2)
urlsafe_b64() { tr '+/' '-_' | tr -d '\n'; }
urlsafe_b64d() { tr '_-' '+/'; }

cifrar_env() {
    openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -A -base64 \
        -pass pass:"$MASTER_KEY" 2>/dev/null
}

descifrar_env() {
    openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 -A -base64 \
        -pass pass:"$MASTER_KEY" 2>/dev/null
}

# ---------------- ACCIONES ----------------
action_sync() {
    local token
    if [[ ! -f "$ENV_BOT" ]]; then log_err "sync: no existe $ENV_BOT"; echo "ERR_NO_ENV_BOT"; return 1; fi
    cargar_master_key || { log_err "sync: no master key"; echo "ERR_MASTER"; return 1; }
    fb_creds_env "$ENV_BOT" || { log_err "sync: no fb creds en $ENV_BOT"; echo "ERR_FB_CREDS"; return 1; }
    token=$(fb_auth_token) || { log_err "sync: fb auth fail"; echo "ERR_FB_AUTH"; return 1; }

    local payload
    payload=$(cifrar_env < "$ENV_BOT") || { echo "ERR_ENCRYPT"; return 1; }
    payload=$(echo "$payload" | urlsafe_b64)

    local resp
    resp=$(curl -s --max-time 15 -X PUT \
        "https://$FB_BASE/$FB_PATH.json?auth=$token" \
        -H "Content-Type: application/json" \
        -d "{\"env\":\"$payload\",\"size\":$(wc -c < "$ENV_BOT"),\"hash\":$(echo -n "$payload" | md5sum | cut -d' ' -f1 | sed 's/^/"/;s/$/"/'),\"actualizado\":$(date +%s),\"sync_por\":\"${1:-bot}\"}" 2>&1)

    if echo "$resp" | grep -q '"env"'; then
        log "sync: .env-bot subido a Firebase (${#payload} chars)"
        echo "OK: .env-bot sincronizado (config_bot/env.b64 cifrado)"
        return 0
    fi
    log_err "sync: respuesta inesperada: ${resp:0:120}"
    echo "ERR_FB_WRITE"; return 1
}

action_restore() {
    local token
    cargar_master_key || { echo "ERR_MASTER"; return 1; }
    # para restore primero intenta credenciales del .env-bot; si no hay, del seed
    if ! fb_creds_env "$ENV_BOT"; then
        fb_creds_env "$BASE/.env-seed" || { log_err "restore: sin creds (ni .env-bot ni .env-seed)"; echo "ERR_FB_CREDS"; return 1; }
    fi
    token=$(fb_auth_token) || { echo "ERR_FB_AUTH"; return 1; }

    local raw payload
    raw=$(curl -s --max-time 15 "https://$FB_BASE/$FB_PATH.json?auth=$token")
    payload=$(echo "$raw" | python3 -c "import sys,json; print(json.load(sys.stdin).get('env',''))" 2>/dev/null)
    if [[ -z "$payload" ]]; then log_err "restore: no hay backup en Firebase"; echo "ERR_NO_BACKUP"; return 1; fi

    payload=$(echo "$payload" | urlsafe_b64d | tr -d '\n')
    mkdir -p "$BASE"
    if echo "$payload" | base64 -d 2>/dev/null | descifrar_env > "$ENV_BOT.tmp" && [[ -s "$ENV_BOT.tmp" ]]; then
        chmod 600 "$ENV_BOT.tmp"
        mv "$ENV_BOT.tmp" "$ENV_BOT"
        chmod 600 "$ENV_BOT"
        log "restore: .env-bot restaurado desde Firebase"
        echo "OK: .env-bot restaurado"
        return 0
    fi
    rm -f "$ENV_BOT.tmp"
    log_err "restore: descifrado fallo (master key correcta?)"
    echo "ERR_DECRYPT"; return 1
}

action_show() {
    # Muestra en claro (solo super admin). No registra el contenido en log.
    if ! cargar_master_key; then echo "ERR_MASTER"; return 1; fi
    if [[ ! -f "$ENV_BOT" ]]; then echo "ERR_NO_ENV_BOT"; return 1; fi
    cat "$ENV_BOT"
    return 0
}

action_check() {
    local token
    if fb_creds_env "$ENV_BOT" || fb_creds_env "$BASE/.env-seed"; then
        token=$(fb_auth_token 2>/dev/null) || true
    fi
    local raw=""
    if [[ -n "${token:-}" ]]; then
        raw=$(curl -s --max-time 15 "https://$FB_BASE/$FB_PATH.json?auth=$token")
    else
        raw=$(curl -s --max-time 15 "https://$FB_BASE/$FB_PATH.json")
    fi
    local size hash ts
    size=$(echo "$raw" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('size','') if isinstance(d,dict) else '')" 2>/dev/null)
    ts=$(echo "$raw" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('actualizado','')) if isinstance(d,dict) else None" 2>/dev/null)
    echo "Backup en Firebase: ${size:-(nada)}"
    [[ -n "$ts" && "$ts" != "None" ]] && echo "  actualizado: $(date -d @$ts '+%Y-%m-%d %H:%M' 2>/dev/null || echo $ts)"
    return 0
}

# ---------------- MAIN ----------------
case "${1:-}" in
    sync)    action_sync ;;
    restore) action_restore ;;
    show)    action_show ;;
    check)   action_check ;;
    *) echo "Uso: $0 {sync|restore|show|check}"; exit 1 ;;
esac