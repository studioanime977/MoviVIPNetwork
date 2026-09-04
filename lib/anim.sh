#!/bin/bash
#=========================================================
# MoviVIP Network — lib/anim.sh v1.0
# SISTEMA DE ANIMACIÓN Y PROGRESO PARA PROTOCOLOS
# ========================================================
#  · Barra de progreso EN VIVO sobre la misma línea (\r),
#    mismo patrón visual que install.sh (_anim_bar/run_cmd).
#  · En MÓVIL (terminal táctil <58 cols) la barra \r se
#    desactiva automáticamente: se muestra una línea de
#    estado simple por paso (el \r no sobrescribe bien en
#    teclados táctiles → texto duplicado).
#  · Detección de estado central de servicios (systemd +
#    fallback por binario/proceso) para todos los menús.
#
# Uso típico en un protocolo:
#   source "$BASE/lib/anim.sh" 2>/dev/null || true
#   anim_init 5
#   anim_step "Instalando dependencias"
#   anim_run "apt update" apt-get update -y
#   anim_run "Instalar squid" apt-get install -y squid
#   svc_up squid && { anim_done "Squid activo"; } \
#                 || { anim_fail "Squid no arrancó"; }
#=========================================================

# ── Colores estándar MoviVIP (no pisa si ya están definidos) ──
[[ -n "${CYAN:-}" ]]    || CYAN="\e[1;96m"
[[ -n "${GOLD:-}" ]]    || GOLD="\e[1;93m"
[[ -n "${GREEN:-}" ]]   || GREEN="\e[1;92m"
[[ -n "${RED:-}" ]]     || RED="\e[1;91m"
[[ -n "${WHITE:-}" ]]   || WHITE="\e[1;97m"
[[ -n "${GRAY:-}" ]]    || GRAY="\e[1;90m"
[[ -n "${MAGENTA:-}" ]] || MAGENTA="\e[1;95m"
[[ -n "${RESET:-}" ]]   || RESET="\e[0m"

# ── Config ──
ANIM_LOG="${ANIM_LOG:-/var/log/movivip-install.log}"
ANIM_WIDTH="${ANIM_WIDTH:-30}"

# ── ¿Terminal móvil? (respeta MV_MOBILE si nav.sh ya cargó) ──
anim_is_mobile() {
    [[ "${MV_MOBILE:-}" == "1" ]] && return 0
    if [[ -z "${MV_MOBILE:-}" ]]; then
        local _c
        _c=$(tput cols 2>/dev/null || echo 80)
        if [[ "$_c" =~ ^[0-9]+$ && "$_c" -gt 0 && "$_c" -lt 58 ]] 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# ── Barra en vivo (solo terminal real; en móvil no se dibuja) ──
anim_bar() {
    local pct="$1" label="$2"
    local width="$ANIM_WIDTH"
    local filled=$(( width * pct / 100 ))
    [[ $filled -gt $width ]] && filled=$width
    [[ $filled -lt 0 ]] && filled=0
    local bar="" i
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=filled; i<width; i++)); do bar+="░"; done
    printf "\r      ${CYAN}[${GOLD}%s${CYAN}]${WHITE} %3d%%${GRAY} %-40s${RESET}" \
        "$bar" "$pct" "${label:0:38}"
}

# ── Paso animado: rellena la barra hasta su posición real ──
ANIM_STEP=0
ANIM_TOTAL=0

anim_init() {
    ANIM_TOTAL="${1:-0}"
    ANIM_STEP=0
}

anim_step() {
    local desc="$1"
    ANIM_STEP=$(( ANIM_STEP + 1 ))
    if anim_is_mobile; then
        printf "  ${GREEN}▸${RESET} ${WHITE}%s${RESET} ${GRAY}[%s/%s]${RESET}\n" \
            "$desc" "$ANIM_STEP" "$ANIM_TOTAL"
        return
    fi
    echo ""
    local target=100
    [[ "$ANIM_TOTAL" -gt 0 ]] && target=$(( ANIM_STEP * 100 / ANIM_TOTAL ))
    local p=0
    while [[ $p -lt $target ]]; do
        p=$(( p + 7 ))
        [[ $p -gt $target ]] && p=$target
        anim_bar "$p" "PASO $ANIM_STEP/$ANIM_TOTAL · $desc"
        sleep 0.04
    done
    printf "\n"
}

# ── Ejecutar comando con barra animada en vivo ──
# Uso: anim_run "descripción" cmd arg1 arg2 ...
# Devuelve 0 si OK, 1 si falló (NO aborta el script).
anim_run() {
    local desc="$1"
    shift
    local tmp_err
    tmp_err=$(mktemp)
    "$@" </dev/null >/dev/null 2>"$tmp_err" &
    local pid=$!

    if anim_is_mobile; then
        wait "$pid"
        local rc=$?
        local err_msg
        err_msg=$(tail -1 "$tmp_err" 2>/dev/null | cut -c1-140)
        rm -f "$tmp_err"
        if [[ $rc -eq 0 ]]; then
            printf "  ${GREEN}✔${RESET} %-46s${GREEN}[OK]${RESET}\n" "${desc:0:44}"
        else
            printf "  ${RED}✘${RESET} %-46s${RED}[FAIL]${RESET}\n" "${desc:0:44}"
            [[ -n "$err_msg" ]] && printf "  ${GRAY}↳ %s${RESET}\n" "$err_msg"
        fi
        return $rc
    fi

    local pct=0
    while kill -0 "$pid" 2>/dev/null; do
        pct=$(( pct + 3 ))
        [[ $pct -gt 92 ]] && pct=92
        anim_bar "$pct" "$desc ..."
        sleep 0.13
    done
    wait "$pid"
    local rc=$?
    local err_msg
    err_msg=$(tail -1 "$tmp_err" 2>/dev/null | cut -c1-140)
    rm -f "$tmp_err"
    if [[ $rc -eq 0 ]]; then
        printf "\r\033[K      ${GREEN}✔${RESET} %-46s${GREEN}[OK]${RESET}\n" "${desc:0:44}"
    else
        printf "\r\033[K      ${RED}✘${RESET} %-46s${RED}[FAIL]${RESET}\n" "${desc:0:44}"
        [[ -n "$err_msg" ]] && printf "      ${GRAY}↳ %s${RESET}\n" "$err_msg"
    fi
    return $rc
}

# ── Feedback final ──
anim_done()   { printf "  ${GREEN}✔ %s${RESET}\n" "$1"; }
anim_fail()   { printf "  ${RED}✘ %s${RESET}\n" "$1"; }
anim_info()   { printf "  ${CYAN}ℹ %s${RESET}\n" "$1"; }
anim_warn()   { printf "  ${GOLD}⚠ %s${RESET}\n" "$1"; }

# ── DETECCIÓN DE ESTADO CENTRAL ──
# svc_up <unit> [binary_name|proceso]
#   0 = activo, 1 = detenido/inexistente
svc_up() {
    local unit="$1" bin="${2:-}"
    if command -v systemctl >/dev/null 2>&1; then
        if systemctl is-active --quiet "$unit" 2>/dev/null; then
            return 0
        fi
        if systemctl list-unit-files 2>/dev/null | grep -q "^${unit}\.service"; then
            return 1
        fi
    fi
    if [[ -n "$bin" ]]; then
        pgrep -x "$bin" >/dev/null 2>&1 && return 0
        pgrep -f "$bin" >/dev/null 2>&1 && return 0
    fi
    return 1
}

# svc_status_text <unit> [bin] → "🟢 ACTIVO" / "🔴 DETENIDO" (sin colores)
svc_status_text() {
    if svc_up "$1" "$2"; then
        echo "🟢 ACTIVO"
    else
        echo "🔴 DETENIDO"
    fi
}

# svc_status_colored <unit> [bin] → línea con colores para echo -e
svc_status_colored() {
    local s
    s=$(svc_status_text "$1" "$2")
    case "$s" in
        *ACTIVO*)  echo "${GREEN}${s}${RESET}" ;;
        *)         echo "${RED}${s}${RESET}" ;;
    esac
}

# svc_line <label> <unit> [bin] [port_value]
#   Ej: svc_line "Estado" xray "" "443"  → " Estado : 🟢 ACTIVO  puerto 443"
svc_line() {
    local label="$1" unit="$2" bin="${3:-}" portv="${4:-}"
    local st
    st=$(svc_status_colored "$unit" "$bin")
    if [[ -n "$portv" ]]; then
        echo -e " ${label} : $st   ${GRAY}puerto ${GOLD}${portv}${RESET}"
    else
        echo -e " ${label} : $st"
    fi
}

# ── Reinicio animado con verificación final ──
# svc_restart_anim <unit> <desc> → reinicia y confirma ACTIVO/DETENIDO
svc_restart_anim() {
    local unit="$1" desc="$2"
    anim_run "$desc" systemctl restart "$unit"
    sleep 2
    if svc_up "$unit"; then
        anim_done "$(trx 'Servicio activo.')"
        return 0
    else
        anim_fail "$(trx 'El servicio no arrancó.')"
        journalctl -u "$unit" -n 12 --no-pager 2>/dev/null | tail -12
        return 1
    fi
}