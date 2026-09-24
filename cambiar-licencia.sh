#!/bin/bash
# =============================================================
#  MOVIVIP NETWORK — CAMBIAR LICENCIA  v2.0
#  -------------------------------------------------------------
#  Quita la licencia actual y registra una nueva.
#  Soporta key legacy (KEY-XXXXXXXXXX) y key v2 (40/64 chars).
#
#  REGLA DE NEGOCIO v2.0 (costo por cambio):
#   - Si la key actual está VENCIDA → cambiar la key cuesta
#     12 USDT. El cliente paga y el ADMINISTRADOR habilita la
#     key nueva en el servidor (activa=true + plan + expira).
#     Este script solo permite el cambio cuando la key nueva
#     ya aparece ACTIVA en Firebase (habilitación manual hecha).
#   - Si la key actual está VIGENTE → se puede cambiar sin
#     costo, pero la key nueva DEBE estar activa en Firebase.
#
#  SEGURIDAD (diseño):
#   - La NUEVA key se valida ANTES de tocar nada:
#       legacy → Firebase (debe existir y activa=true)
#       v2     → runner compilado (firma válida) Y Firebase
#                activa=true (pago/habilitación confirmada)
#     Si no pasa → NO se modifica la licencia actual.
#   - La licencia actual se respalda en licencia.conf.bak-<fecha>.
#   - Después del cambio, el VPS opera con la nueva key.
#   - fail-closed: sin internet NO se permite cambiar.
#
#  USO:
#    bash /etc/movivip/cambiar-licencia.sh
# =============================================================

BASE="/etc/movivip"
LICENCIA_FILE="$BASE/licencia.conf"
FIREBASE_PLAN="$BASE/lib/firebase-plan.sh"
CHECK="$BASE/check-licencia.sh"

# Runner v2 (compilado, tiene la master key adentro — nunca se expone).
# La URL se mantiene alineada con install.sh (bump a v7.0 en release).
MOVIVIP_RUNNER_BIN="$BASE/bin/movivip-runner"
MOVIVIP_RUNNER_RELEASE="v2.0.2"
MOVIVIP_RUNNER_URL="https://github.com/studioanime977/MoviVIPNetwork/releases/download/${MOVIVIP_RUNNER_RELEASE}/movivip-runner-linux-${_MOVIVIP_ARCH:-amd64}"

_detect_runner_arch() {
    local M
    M=$(uname -m 2>/dev/null | tr '[:upper:]' '[:lower:]')
    case "$M" in
        x86_64|amd64)  echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        ppc64le|ppc64) echo "ppc64le" ;;
        riscv64|riscv)  echo "riscv64" ;;
        s390x)         echo "s390x" ;;
        *) echo "amd64" ;;
    esac
}
MOVIVIP_RUNNER_URL="https://github.com/studioanime977/MoviVIPNetwork/releases/download/${MOVIVIP_RUNNER_RELEASE}/movivip-runner-linux-$(_detect_runner_arch)"

RESET="\e[0m"; RED="\e[1;91m"; GREEN="\e[1;92m"; GOLD="\e[1;93m"; CYAN="\e[1;96m"; WHITE="\e[1;97m"; GRAY="\e[1;90m"; BGRED="\e[41m"; BGGREEN="\e[42m"

# ── Cargar idioma + trx + diseño (imprescindible para trx / movivip_sub_header) ──
if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)"
fi
source "$BASE/lib/nav.sh" 2>/dev/null || true

# ================= HELPERS v2 =================
is_v2_key() {
    local key="$1"
    [[ -n "$key" ]] \
        && [[ "${#key}" -eq 40 || "${#key}" -eq 64 ]] \
        && [[ ! "$key" =~ ^KEY-[A-Fa-f0-9]{10}$ ]] \
        && [[ "$key" =~ ^[A-Za-z0-9+/=_-]+$ ]]
}

is_legacy_key() {
    [[ "$1" =~ ^KEY-[0-9A-Fa-f]{10}$ ]]
}

# Validar firma v2 con el runner compilado (descarga/caché como install.sh)
validate_v2_key() {
    local key="$1"
    if [[ ! -x "$MOVIVIP_RUNNER_BIN" ]]; then
        mkdir -p "$(dirname "$MOVIVIP_RUNNER_BIN")"
        if [[ -x /tmp/movivip-runner ]]; then
            cp -f /tmp/movivip-runner "$MOVIVIP_RUNNER_BIN" 2>/dev/null
        fi
    fi
    if [[ ! -x "$MOVIVIP_RUNNER_BIN" ]]; then
        curl -fsSL --max-time 120 "$MOVIVIP_RUNNER_URL" -o "$MOVIVIP_RUNNER_BIN" 2>/dev/null || return 1
        chmod 700 "$MOVIVIP_RUNNER_BIN" 2>/dev/null || return 1
    fi
    if "$MOVIVIP_RUNNER_BIN" verify "$key" >/dev/null 2>&1; then
        return 0
    fi
    # Reintento forzando redescarga (binario cacheado viejo/roto)
    rm -f "$MOVIVIP_RUNNER_BIN"
    curl -fsSL --max-time 120 "$MOVIVIP_RUNNER_URL" -o "$MOVIVIP_RUNNER_BIN" 2>/dev/null || return 1
    chmod 700 "$MOVIVIP_RUNNER_BIN" 2>/dev/null || return 1
    "$MOVIVIP_RUNNER_BIN" verify "$key" >/dev/null 2>&1
}

mostrar_contacto() {
    echo ""
    echo -e "${CYAN}  ─────────────────────────────────────────────${RESET}"
    echo -e "  💬 ${WHITE}Telegram :${RESET} ${GOLD}@MoviVIP${RESET}"
    echo -e "  📱 ${WHITE}WhatsApp :${RESET} ${GOLD}+57 311 700 8185${RESET}"
    echo -e "  🌐 ${WHITE}Web      :${RESET} ${GOLD}https://movivip-network.web.app${RESET}"
    echo -e "  📢 ${WHITE}Canal    :${RESET} ${GOLD}https://t.me/MoviVIPNetwork${RESET}"
    echo -e "  👥 ${WHITE}Grupo    :${RESET} ${GOLD}https://t.me/MoviVIPNet${RESET}"
    echo -e "${CYAN}  ─────────────────────────────────────────────${RESET}"
    echo ""
}

mostrar_banner_costo() {
    echo -e "${BGRED}${WHITE}════════════════════════════════════════════════════════════${RESET}"
    echo -e "${BGRED}${WHITE}   ⛔ LICENCIA VENCIDA — CAMBIO DE KEY CON COSTO (12 USDT)${RESET}"
    echo -e "${BGRED}${WHITE}════════════════════════════════════════════════════════════${RESET}"
    echo ""
    echo -e "${WHITE}  La key actual de este VPS está ${RED}VENCIDA${RESET}."
    echo -e "  ${GOLD}⚡ Cambiar la key tiene un costo de:  ${WHITE}12 USDT${RESET}"
    echo ""
    echo -e "${CYAN}  PASOS:${RESET}"
    echo -e "   ${WHITE}1)${RESET} Escribe al soporte y paga los ${GOLD}12 USDT${RESET}"
    echo -e "   ${WHITE}2)${RESET} El administrador habilita tu ${GOLD}NUEVA key${RESET} en el sistema"
    echo -e "   ${WHITE}3)${RESET} Vuelve aquí, ingresa la key nueva y listo"
    echo ""
}

# ================= INICIO =================
clear
movivip_sub_header "$(trx '🔑 CAMBIAR LICENCIA')"
echo ""

# ---------- 1. Mostrar licencia actual (EN VIVO contra Firebase) ----------
echo -e "${WHITE}Licencia actual:${RESET}"
CURRENT_KEY=""
if [[ -f "$LICENCIA_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$LICENCIA_FILE" 2>/dev/null
    CURRENT_KEY="${KEY:-}"
fi

CURRENT_EXPIRED=false
if [[ -x "$FIREBASE_PLAN" ]]; then
    source "$FIREBASE_PLAN"
    FP_VALID=0; FP_PLAN=""; FP_CLIENTE=""; FP_TIPO=""; FP_EXPIRA=""; FP_KEY=""
    if [[ -n "$CURRENT_KEY" ]]; then
        firebase_plan "$CURRENT_KEY"
        case $? in
            0)
                echo -e "  ${GREEN}🟢 ${GOLD}Key:${RESET} ${CURRENT_KEY:0:10}****  ${GRAY}(plan: ${FP_PLAN:-standard} · cliente: ${FP_CLIENTE:-?})${RESET}"
                ;;
            1)
                echo -e "  ${RED}🔴 ${GOLD}Key:${RESET} ${CURRENT_KEY:0:10}****  ${GRAY}(INACTIVA / VENCIDA / NO EXISTE)${RESET}"
                # Vencida? (expira = epoch numérico ya pasado)
                if [[ -n "${FP_EXPIRA:-}" && "$FP_EXPIRA" =~ ^[0-9]+$ && "$FP_EXPIRA" -gt 0 && "$(date +%s)" -gt "$FP_EXPIRA" ]]; then
                    CURRENT_EXPIRED=true
                fi
                ;;
            2)
                echo -e "  ${GRAY}⚠  No se pudo consultar el servidor de licencias (sin conexión).${RESET}"
                ;;
        esac
    else
        echo -e "  ${GRAY}No hay clave guardada.${RESET}"
    fi
else
    if [[ -n "$CURRENT_KEY" ]]; then
        echo -e "  ${GRAY}Key: ${CURRENT_KEY:0:10}****  (sin consulta EN VIVO: falta lib/firebase-plan.sh)${RESET}"
    else
        echo -e "  ${GRAY}No hay clave guardada.${RESET}"
    fi
fi
echo ""

# ---------- 2. Banner costo si la key actual está VENCIDA ----------
if [[ "$CURRENT_EXPIRED" == "true" ]]; then
    mostrar_banner_costo
    mostrar_contacto
    echo -e "${GRAY}  Nota: el sistema NO permite completar el cambio hasta que la key${RESET}"
    echo -e "${GRAY}  nueva aparezca ACTIVA (habilitada por el administrador tras el pago).${RESET}"
    echo ""
fi

# ---------- 3. Confirmar ----------
echo -e "${RED}⚠️  Al cambiar la licencia, este VPS pasará a usar la NUEVA key.${RESET}"
read -rp "$(echo -e "${CYAN}¿Seguro que deseas CAMBIAR la licencia? [s/N] ➤ ${RESET}")" CONF
case "${CONF,,}" in
    s|si|sí|y|yes) ;;
    *) echo -e "${GOLD}⏭ Cancelado. La licencia actual no se modificó.${RESET}"
       sleep 2
       exit 0 ;;
esac

# ---------- 4. Pedir la nueva key ----------
echo ""
read -rp "$(echo -e "${CYAN}Ingresa la NUEVA key (KEY-XXXXXXXXXX o v2 de 40/64 caracteres): ${RESET}")" NUEVA_KEY
NUEVA_KEY=$(echo "$NUEVA_KEY" | tr -d '[:space:]')

# ---------- 5. Validar formato ----------
if ! is_legacy_key "$NUEVA_KEY" && ! is_v2_key "$NUEVA_KEY"; then
    echo -e "${RED}❌ Formato inválido.${RESET}"
    echo -e "${GRAY}   Aceptado: KEY-XXXXXXXXXX (10 hex) o key v2 (40/64 caracteres).${RESET}"
    read -n1 -r -p "$(trx '  Presiona ENTER para volver...')"
    exit 1
fi

# ---------- 6. Validar contra Firebase + runner (SIN tocar nada aún) ----------
echo ""
echo -e "${CYAN}→ Consultando servidor de licencias...${RESET}"

if [[ ! -x "$FIREBASE_PLAN" ]]; then
    echo -e "${RED}❌ No se encontró el validador de licencia ($FIREBASE_PLAN).${RESET}"
    read -n1 -r -p "$(trx '  Presiona ENTER para volver...')"
    exit 1
fi

source "$FIREBASE_PLAN"
FP_VALID=0; FP_PLAN=""; FP_CLIENTE=""; FP_TIPO=""; FP_EXPIRA=""; FP_KEY=""
firebase_plan "$NUEVA_KEY"
FB_CODE=$?

# Para v2: la firma la valida el runner; luego Firebase confirma habilitación (pago OK)
V2_OK=false
if is_v2_key "$NUEVA_KEY"; then
    echo -e "${CYAN}→ Key v2 detectada — validando firma con el runner...${RESET}"
    if validate_v2_key "$NUEVA_KEY"; then
        V2_OK=true
        echo -e "${GREEN}✔ Firma v2 VÁLIDA.${RESET}"
    else
        echo -e "${RED}❌ La firma de la key v2 es INVÁLIDA.${RESET}"
        echo -e "${GRAY}   No se modificó la licencia actual.${RESET}"
        read -n1 -r -p "$(trx '  Presiona ENTER para volver...')"
        exit 1
    fi
fi

if [[ $FB_CODE -eq 2 ]]; then
    echo -e "${RED}❌ No se pudo conectar al servidor de licencias.${RESET}"
    echo -e "${GRAY}   Sin conexión NO se permite cambiar la licencia (fail-closed).${RESET}"
    read -n1 -r -p "$(trx '  Presiona ENTER para volver...')"
    exit 2
fi

if [[ $FB_CODE -ne 0 ]]; then
    echo -e "${RED}❌ La key '$NUEVA_KEY' NO está activa en el sistema.${RESET}"
    echo ""
    echo -e "${GRAY}   Si la key es nueva y pagaste el cambio (12 USDT), el administrador${RESET}"
    echo -e "${GRAY}   debe habilitarla primero. Escríbele con tu key para activarla.${RESET}"
    mostrar_contacto
    echo -e "${GRAY}   La licencia actual NO se modificó.${RESET}"
    read -n1 -r -p "$(trx '  Presiona ENTER para volver...')"
    exit 1
fi

echo -e "${GREEN}✔ La nueva key es VÁLIDA y está ACTIVA.${RESET}"

# ---------- 7. Respaldar la licencia actual ----------
if [[ -f "$LICENCIA_FILE" ]]; then
    cp "$LICENCIA_FILE" "${LICENCIA_FILE}.bak-$(date +%Y%m%d-%H%M%S)" 2>/dev/null
    echo -e "${GREEN}✔ Licencia anterior respaldada.${RESET}"
fi

# ---------- 8. Registrar la nueva licencia (verdades de Firebase) ----------
echo ""
echo -e "${CYAN}→ Guardando la nueva licencia...${RESET}"
mkdir -p "$BASE"
cat > "$LICENCIA_FILE" <<EOF
# Movivip Network — Licencia (sincronizada con Firebase EN VIVO)
# ⚠ NO edites este archivo: se sobreescribe en cada validación.
KEY="$NUEVA_KEY"
PLAN="${FP_PLAN:-standard}"
CLIENTE="${FP_CLIENTE:-desconocido}"
TIPO="${FP_TIPO:-cliente}"
EXPIRA="${FP_EXPIRA:-0}"
FECHA="$(date -Iseconds)"
EOF
chmod 644 "$LICENCIA_FILE"
echo -e "${GREEN}✔ Nueva licencia guardada.${RESET}"

# ---------- 9. Verificación final ----------
echo ""
if bash "$CHECK" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ ¡Licencia cambiada correctamente! El VPS opera con la nueva key.${RESET}"
else
    echo -e "${RED}⚠️  La licencia quedó guardada pero el validador reporta problemas.${RESET}"
    echo -e "${GRAY}   Revisa la key e intenta de nuevo.${RESET}"
fi
echo ""
read -n1 -r -p "$(trx '  Presiona ENTER para volver al menú...')"
exec bash "$BASE/menu.sh"