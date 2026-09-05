#!/bin/bash
# =============================================================
#  MOVIVIP NETWORK — FIREBASE PLAN (consulta SEGURA del plan)
#  -------------------------------------------------------------
#  La fuente de verdad del plan/estado es SIEMPRE Firebase.
#  El archivo local licencia.conf es SOLO una caché de la key;
#  NUNCA se confía en su PLAN/CLIENTE/EXPIRA (cualquiera puede
#  editarlo). Cada consulta re-verifica EN VIVO contra Firebase.
#
#  USO:
#    bash firebase-plan.sh [KEY]
#      - Sin argumento: lee la key de licencia.conf / env LICENCIA_KEY
#      - Con argumento: usa esa key (v2 40/64 o legacy KEY-XXXX)
#
#  SALIDA (stdout): una línea por campo, listo para `eval` o `source`:
#    KEY="..." PLAN="..." CLIENTE="..." TIPO="..." EXPIRA="<epoch>" ACTIVA="true|false"
#
#  CÓDIGOS DE SALIDA:
#    0 = key VÁLIDA (activa + no vencida) → PLAN real disponible
#    1 = key NO VÁLIDA (inactiva / vencida / no existe)
#    2 = error de red / sin conexión
#
#  TAMBIÉN deja variables globales cuando se hace `source`:
#    FP_VALID, FP_PLAN, FP_CLIENTE, FP_TIPO, FP_EXPIRA, FP_KEY
# =============================================================

FB_BASE="${MOVIVIP_FB_BASE:-movivip-network-default-rtdb.firebaseio.com}"
FB_LICENCIAS="licencias_movivip"
BASE_DIR="/etc/movivip"
LICENCIA_FILE="$BASE_DIR/licencia.conf"

# ================= HELPERS =================
# Extraer campo del JSON (sin jq - compatible). Preserva espacios internos:
#   json_get '{"cliente":"MoviVIP Network"}' cliente  ->  MoviVIP Network
json_get() {
    local json="$1" campo="$2"
    echo "$json" | grep -o "\"${campo}\"[[:space:]]*:[[:space:]]*[^,}]*" | head -n1 \
        | sed -E "s/^[[:space:]]*\"${campo}\"[[:space:]]*:[[:space:]]*//" \
        | sed -E 's/^"//; s/"$//'
}

# Path url-safe para Firebase: las keys v2 contienen '+' y '/'
# (match exacto con fb_key_path del generador: + -> -, / -> _)
fb_key_path() {
    echo "$1" | tr '+/' '-_'
}

# Formato de key aceptado: legacy KEY-XXXXXXXXXX o v2 40/64 chars
key_formato_valido() {
    local k="$1"
    [[ -z "$k" ]] && return 1
    if [[ "$k" =~ ^KEY-[0-9A-Fa-f]{10}$ ]]; then
        return 0
    fi
    if [[ "${#k}" -eq 40 || "${#k}" -eq 64 ]]; then
        # v2: alfanumérico base64url (+ y / y =) pero sin espacios
        if [[ "$k" =~ ^[A-Za-z0-9+/=_-]+$ ]]; then
            return 0
        fi
    fi
    return 1
}

# ================= CONSULTA PRINCIPAL =================
firebase_plan() {
    local key="${1:-}"
    local resp cur expira activa plan cliente tipo

    # Si no hay key en el argumento, leerla de env o licencia.conf
    if [[ -z "$key" ]]; then
        key="${LICENCIA_KEY:-}"
    fi
    if [[ -z "$key" && -f "$LICENCIA_FILE" ]]; then
        # shellcheck disable=SC1090
        source "$LICENCIA_FILE" 2>/dev/null
        key="${KEY:-}"
    fi
    if [[ -z "$key" ]]; then
        # reset variables globales
        FP_VALID=0; FP_PLAN=""; FP_CLIENTE=""; FP_TIPO=""; FP_EXPIRA=""; FP_KEY=""
        return 1
    fi

    if ! key_formato_valido "$key"; then
        FP_VALID=0; FP_PLAN=""; FP_CLIENTE=""; FP_TIPO=""; FP_EXPIRA=""; FP_KEY="$key"
        return 1
    fi

    # Path url-safe (v2) o directo (legacy)
    local key_path
    key_path=$(fb_key_path "$key")

    # Consultar Firebase EN VIVO
    resp=$(curl -s --max-time 12 "https://${FB_BASE}/${FB_LICENCIAS}/${key_path}.json" 2>/dev/null)
    if [[ -z "$resp" ]]; then
        FP_VALID=0; FP_PLAN=""; FP_CLIENTE=""; FP_TIPO=""; FP_EXPIRA=""; FP_KEY="$key"
        return 2
    fi
    if [[ "$resp" == "null" ]]; then
        FP_VALID=0; FP_PLAN=""; FP_CLIENTE=""; FP_TIPO=""; FP_EXPIRA=""; FP_KEY="$key"
        return 1
    fi

    activa=$(json_get "$resp" "activa")
    expira=$(json_get "$resp" "expira")
    plan=$(json_get "$resp" "plan")
    cliente=$(json_get "$resp" "cliente")
    tipo=$(json_get "$resp" "tipo")

    # Activa?
    if [[ "$activa" != "true" ]]; then
        FP_VALID=0; FP_PLAN=""; FP_CLIENTE=""; FP_TIPO=""; FP_EXPIRA="$expira"; FP_KEY="$key"
        return 1
    fi

    # Vencida? (expira=0 o vacío => vitalicia)
    cur=$(date +%s)
    if [[ -n "$expira" && "$expira" =~ ^[0-9]+$ && "$expira" -gt 0 && "$cur" -gt "$expira" ]]; then
        FP_VALID=0; FP_PLAN=""; FP_CLIENTE=""; FP_TIPO=""; FP_EXPIRA="$expira"; FP_KEY="$key"
        return 1
    fi

    # ✅ Válida → rellenar variables globales
    FP_VALID=1
    FP_PLAN="${plan:-standard}"
    FP_CLIENTE="${cliente:-desconocido}"
    FP_TIPO="${tipo:-cliente}"
    FP_EXPIRA="${expira:-0}"
    FP_KEY="$key"
    return 0
}

# ================= MODO MAIN =================
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    firebase_plan "$@"
    code=$?
    if [[ $code -eq 0 ]]; then
        printf 'KEY="%s" PLAN="%s" CLIENTE="%s" TIPO="%s" EXPIRA="%s" ACTIVA="true"\n' \
            "$FP_KEY" "$FP_PLAN" "$FP_CLIENTE" "$FP_TIPO" "$FP_EXPIRA"
    elif [[ $code -eq 1 ]]; then
        printf 'KEY="%s" PLAN="" CLIENTE="" TIPO="" EXPIRA="" ACTIVA="false"\n' "${FP_KEY:-}"
    fi
    exit $code
fi