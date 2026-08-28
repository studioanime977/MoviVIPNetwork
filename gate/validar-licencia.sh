#!/bin/bash
# =============================================================
#  VPS LICENSE GATE — VALIDADOR DE LICENCIA (Firebase RTDB)
#  -------------------------------------------------------------
#  Este es el CORAZÓN del sistema anti-piratería.
#  Valida una clave de licencia contra Firebase Realtime Database.
#
#  MODELO DE NEGOCIO:
#   - El cliente recibe una key al comprar
#   - La key se valida contra Firebase al INSTALAR y al ACTUALIZAR
#   - NINGÚN plan se desactiva por no pagar: el panel y los protocolos
#     siguen funcionando normal SIEMPRE (no hay kill-switch).
#   - La licencia SOLO controla las ACTUALIZACIONES:
#       · plan activo   -> puede actualizar cuando quiera (él decide)
#       · plan vencido  -> se le NOTIFICA la actualización disponible,
#                          pero no se descarga. Renueva para actualizar.
#
#  SEGURIDAD:
#   - La decisión final la toma Firebase (servidor), no el script
#   - La key es imposible de adivinar (10 chars hex aleatorios)
#   - Las reglas RTDB impiden listar/enumerar todas las keys
#   - Se registra cada activación (IP, hostname, fecha) para trazabilidad
#
#  USO:
#    ./validar-licencia.sh                    # pide la key interactiva
#    ./validar-licencia.sh KEY-XXXXXXXXXX     # valida la key dada
#    LICENCIA_KEY=KEY-XXX ./validar-licencia.sh  # vía variable de entorno
#    ./validar-licencia.sh --test KEY-XXX     # modo prueba (no registra)
#    ./validar-licencia.sh --check KEY-XXX    # MODO SILENCIOSO: solo código
#       devuelve: 0 = activa | 1 = no activa/vencida | 2 = error de red
#       (lo usa update.sh para decidir si permite actualizar)
# =============================================================

# ================= CONFIGURACIÓN =================
# URL de la Realtime Database (SIN https:// y SIN .json)
# ── i18n shim (auto) ───────────────────────────────
if ! declare -F trx >/dev/null 2>&1; then trx() { printf '%s' "$1"; }; fi
# ─────────────────────────────────────────────────────────
FB_BASE="movivip-network-default-rtdb.firebaseio.com"
# Rama donde viven las licencias
FB_LICENCIAS="licencias_movivip"
# Rama donde se registran las activaciones (trazabilidad)
FB_ACTIVACIONES="activaciones_movivip"
# Archivo local donde se guarda la licencia activa
LICENCIA_FILE="/etc/movivip/licencia.conf"

# ================= COLORES =================
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

# ================= FUNCIONES =================
log_ok()   { echo -e "${GREEN}[✔]${NC} $1"; }
log_err()  { echo -e "${RED}[✘]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_info() { echo -e "${CYAN}[→]${NC} $1"; }

# Validar formato de key: KEY-XXXXXXXXXX (10 hex)
key_formato_valido() {
    [[ "$1" =~ ^KEY-[0-9A-F]{10}$ ]]
}

# Obtener IP pública
get_ip() {
    local ip
    ip=$(curl -s --max-time 8 ifconfig.me 2>/dev/null)
    [[ -z "$ip" ]] && ip=$(curl -s --max-time 8 api.ipify.org 2>/dev/null)
    [[ -z "$ip" ]] && ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    echo "$ip"
}

# Consultar la licencia en Firebase
# Devuelve 0 = key existe, 1 = key no existe, 2 = error de red
firebase_consulta() {
    local key="$1"
    local url="https://${FB_BASE}/${FB_LICENCIAS}/${key}.json"
    local resp
    resp=$(curl -s --max-time 15 "$url" 2>/dev/null)
    if [[ $? -ne 0 || -z "$resp" ]]; then
        return 2
    fi
    # Si la respuesta es "null" => key no existe
    if [[ "$resp" == "null" ]]; then
        return 1
    fi
    echo "$resp"
    return 0
}

# Extraer campo del JSON (sin jq - compatible con cualquier sistema)
json_get() {
    local json="$1" campo="$2"
    echo "$json" | grep -o "\"${campo}\"[[:space:]]*:[[:space:]]*[^,}]*" | head -n1 | sed "s/\"${campo}\"[[:space:]]*:[[:space:]]*//" | tr -d '"' | tr -d ' '
}

# ================= MAIN =================
main() {
    local KEY="" TEST_MODE=0 CHECK_MODE=0

    # Parsear argumentos
    if [[ "$1" == "--test" ]]; then
        TEST_MODE=1
        shift
    fi
    if [[ "$1" == "--check" ]]; then
        CHECK_MODE=1
        shift
    fi
    KEY="${1:-$LICENCIA_KEY}"

    # ============================================================
    # MODO CHECK (silencioso) — lo usa update.sh para decidir si
    # permite actualizar. Devuelve: 0 activa | 1 no activa | 2 red
    # ============================================================
    if [[ $CHECK_MODE -eq 1 ]]; then
        [[ -z "$KEY" ]] && return 2
        if ! key_formato_valido "$KEY"; then return 1; fi
        local resp
        resp=$(firebase_consulta "$KEY")
        local code=$?
        [[ $code -ne 0 ]] && return "$code"   # 2 = sin red, 1 = no existe
        local activa expira now
        activa=$(json_get "$resp" "activa")
        expira=$(json_get "$resp" "expira")
        if [[ "$activa" != "true" ]]; then return 1; fi
        now=$(date +%s)
        # expira=0 o vacio => VITALICIA (de por vida). Solo expira si expira > 0 y ya paso
        if [[ -n "$expira" && "$expira" =~ ^[0-9]+$ && "$expira" -gt 0 && "$now" -gt "$expira" ]]; then return 1; fi
        return 0
    fi

    # Encabezado
    clear 2>/dev/null
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "$(trx '   🔑 VALIDACIÓN DE LICENCIA')"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Pedir key si no viene
    if [[ -z "$KEY" ]]; then
        read -p "$(trx 'Ingresa tu clave de licencia: ')" KEY
    fi

    # Validar formato
    if ! key_formato_valido "$KEY"; then
        log_err "Formato de clave inválido. Debe ser: KEY-XXXXXXXXXX (10 caracteres hex)"
        echo ""
        log_warn "Ejemplo: KEY-3F8A21C9D4"
        return 1
    fi

    log_info "Consultando servidor de licencias..."
    local resp
    resp=$(firebase_consulta "$KEY")
    local code=$?

    if [[ $code -eq 2 ]]; then
        log_err "No se pudo conectar al servidor de licencias."
        log_err "Verifica la conexión a internet y reintenta."
        return 2
    fi

    if [[ $code -eq 1 ]]; then
        log_err "❌ CLAVE NO VÁLIDA."
        log_err "La clave '$KEY' no existe en el sistema."
        echo ""
        log_warn "💡 Adquiere una licencia válida para instalar este sistema."
        log_warn ""
        log_warn "   Contacto:"
        log_warn "   ───────────────────────────────────────────"
        log_warn "   💬 Telegram : @MoviVIP"
        log_warn "   📱 WhatsApp : +57 311 700 8185"
        log_warn "   🌐 Web      : https://movivip-network.web.app"
        log_warn "   📢 Canal    : https://t.me/MoviVIPNetwork"
        log_warn "   👥 Grupo    : https://t.me/MoviVIPNet"
        log_warn "   ───────────────────────────────────────────"
        return 1
    fi

    # Parsear respuesta
    local activa expira creada cliente plan
    activa=$(json_get "$resp" "activa")
    expira=$(json_get "$resp" "expira")
    creada=$(json_get "$resp" "creada")
    cliente=$(json_get "$resp" "cliente")
    plan=$(json_get "$resp" "plan")

    log_info "Licencia encontrada: ${cliente:-cliente anónimo} (plan: ${plan:-standard})"

    # Verificar que está activa
    if [[ "$activa" != "true" ]]; then
        log_err "❌ LICENCIA DESACTIVADA."
        log_err "Esta clave fue revocada por el proveedor."
        return 1
    fi

    # Verificar expiración
    local now
    now=$(date +%s)
    # expira=0 o vacio => VITALICIA (de por vida). Solo expira si expira > 0 y ya paso
    if [[ -n "$expira" && "$expira" =~ ^[0-9]+$ && "$expira" -gt 0 && "$now" -gt "$expira" ]]; then
        local expira_humano
        expira_humano=$(date -d "@$expira" '+%Y-%m-%d %H:%M' 2>/dev/null || date -r "$expira" '+%Y-%m-%d %H:%M' 2>/dev/null)
        log_err "❌ LICENCIA EXPIRADA."
        log_err "Esta clave venció el: ${expira_humano:-$expira}"
        echo ""
        log_warn "ℹ️  Tu panel y protocolos SIGUEN funcionando normal."
        log_warn "💡 Renueva tu licencia para seguir recibiendo actualizaciones."
        return 1
    fi

    # Mostrar estado
    if [[ -n "$expira" && "$expira" =~ ^[0-9]+$ && "$expira" -gt 0 ]]; then
        local dias_restantes
        dias_restantes=$(( (expira - now) / 86400 ))
        [[ $dias_restantes -lt 0 ]] && dias_restantes=0
        log_ok "Licencia VÁLIDA — plan ${plan:-standard}, ${dias_restantes} día(s) de licencia."
        log_ok "Puedes recibir actualizaciones. (el panel nunca se desactiva)"
    else
        log_ok "Licencia VÁLIDA (sin fecha de expiración). Puedes recibir actualizaciones."
    fi

    # Guardar licencia local
    if [[ $TEST_MODE -eq 0 ]]; then
        mkdir -p /etc/movivip 2>/dev/null
        cat > "$LICENCIA_FILE" <<EOF
KEY="$KEY"
ACTIVADA="$(date '+%Y-%m-%d %H:%M:%S')"
EXPIRA="$expira"
PLAN="$plan"
CLIENTE="$cliente"
LICENCIA_ACTIVA="true"
EOF
        chmod 600 "$LICENCIA_FILE" 2>/dev/null
        log_ok "Licencia guardada en $LICENCIA_FILE"

        # Registrar activación (trazabilidad)
        local ip fecha ts
        ip=$(get_ip)
        fecha=$(date '+%Y-%m-%d %H:%M:%S')
        ts=$(date +%s)
        local host
        host=$(hostname 2>/dev/null || echo "desconocido")
        curl -s --max-time 15 -X PUT \
            "https://${FB_BASE}/${FB_ACTIVACIONES}/${KEY}/${ts}.json" \
            -H "Content-Type: application/json" \
            -d "{\"ip\":\"${ip}\",\"hostname\":\"${host}\",\"fecha\":\"${fecha}\"}" >/dev/null 2>&1
        log_ok "Activación registrada (IP: $ip)"
    else
        log_warn "Modo prueba: no se guardó ni registró la activación."
    fi

    return 0
}

# Ejecutar
main "$@"
exit $?
