#!/usr/bin/env bash
# install-auto.sh — Instalador automático MoviVIPNetwork
# Descarga el stub correspondiente a la arquitectura, verifica integridad y lo ejecuta.
# main/stubs — NEBULA CYBER-VIP Design System

set -euo pipefail

# =============================================================================
# NEBULA CYBER-VIP DESIGN SYSTEM — Colores y Estilos
# =============================================================================
readonly C_RESET='\033[0m'
readonly C_BOLD='\033[1m'
readonly C_DIM='\033[2m'

# Paleta NEBULA
readonly C_BG='\033[48;2;10;10;15m'       # Fondo oscuro profundo
readonly C_FG='\033[38;2;220;220;230m'    # Texto principal
readonly C_MUTED='\033[38;2;120;120;140m' # Texto secundario
readonly C_ACCENT='\033[38;2;0;200;255m'  # Cian neón (acento principal)
readonly C_ACCENT_DIM='\033[38;2;0;150;200m'
readonly C_GOLD='\033[38;2;255;180;0m'    # Dorado/ámbar
readonly C_GREEN='\033[38;2;0;255;130m'   # Verde éxito
readonly C_RED='\033[38;2;255;60;90m'     # Rojo error
readonly C_ORANGE='\033[38;2;255;140;0m'  # Naranja advertencia
readonly C_PURPLE='\033[38;2;180;100;255m' # Púrpura
readonly C_CYAN='\033[38;2;0;255;255m'    # Cian brillante
readonly C_WHITE='\033[38;2;255;255;255m' # Blanco puro

# Utilidades de salida
_mov_print() { printf '%b\n' "$*"; }
_mov_banner() {
    local title="$1"
    local subtitle="${2:-}"
    local width=64
    local pad=$(( (width - ${#title}) / 2 ))
    printf '\n'
    printf '%b%s%b\n' "${C_BG}${C_ACCENT}" "$(printf '═%.0s' $(seq 1 $width))" "${C_RESET}"
    printf '%b%*s%s%*s%b\n' "${C_BG}${C_BOLD}${C_WHITE}" $pad "" "$title" $((width - pad - ${#title})) "" "${C_RESET}"
    if [[ -n "$subtitle" ]]; then
        local pad2=$(( (width - ${#subtitle}) / 2 ))
        printf '%b%*s%s%*s%b\n' "${C_BG}${C_MUTED}" $pad2 "" "$subtitle" $((width - pad2 - ${#subtitle})) "" "${C_RESET}"
    fi
    printf '%b%s%b\n\n' "${C_BG}${C_ACCENT}" "$(printf '═%.0s' $(seq 1 $width))" "${C_RESET}"
}
_mov_section() { _mov_print "${C_ACCENT}▶${C_RESET} ${C_BOLD}${C_WHITE}$*${C_RESET}"; }
_mov_step()  { _mov_print "  ${C_CYAN}◆${C_RESET} ${C_FG}$*${C_RESET}"; }
_mov_ok()    { _mov_print "  ${C_GREEN}✓${C_RESET} ${C_FG}$*${C_RESET}"; }
_mov_warn()  { _mov_print "  ${C_ORANGE}⚠${C_RESET} ${C_ORANGE}$*${C_RESET}"; }
_mov_err()   { _mov_print "  ${C_RED}✗${C_RESET} ${C_RED}$*${C_RESET}"; }
_mov_info()  { _mov_print "  ${C_MUTED}ℹ${C_RESET} ${C_MUTED}$*${C_RESET}"; }
_mov_kv()    { _mov_print "  ${C_DIM}${C_MUTED}$1:${C_RESET} ${C_WHITE}$2${C_RESET}"; }

# Spinner para descargas
_mov_spinner() {
    local pid=$1
    local msg="$2"
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf '\r  %b%s%b %s' "${C_ACCENT}" "${frames[i]}" "${C_RESET}" "$msg"
        i=$(( (i + 1) % ${#frames[@]} ))
        sleep 0.08
    done
    printf '\r%*s\r' $((${#msg} + 10)) ''
}

# =============================================================================
# CONFIGURACIÓN
# =============================================================================
readonly MV_VERSION='main/stubs'
readonly BASE="https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/stubs"
readonly REPO='studioanime977/MoviVIPNetwork'
readonly BRANCH='main'

# Hashes SHA256 REALES de los binarios en GitHub Releases main/stubs
# Solo arquitecturas que SÍ se construyeron y publicaron
declare -A MV_SHA=(
  [setup-linux-amd64]='486f886ac3383f70795026de7c23e37f4a3a5e5582487155604e34fc36bd12aa'
  [setup-linux-arm64]='0a4daa72dff5eaedb864d7635f1f2df96fe6537ffad6da2072c236f6a658a0a6'
  [setup-linux-armv5]='e6627d279321a5f31b844e8cea7872cdbd6179932f655224919c25ec31c2cb2f'
  [setup-linux-armv6]='7fdbdee74b5779d6a836fd5763e488424e6286b5bd3b30ccd753ba4c06ab01d4'
  [setup-linux-armv7]='0540f47a45f6d2567e01bb831db7ec6e9d205e0b76ebeed09ce8ff857a648237'
  [setup-linux-386]='1c16f81dd9b97f61878c427053f71801a1234e7ada07cd6d5cf2c1e6e73defbd'
)

# Mapeo uname -m -> archivo stub
declare -A MV_FILE=(
  [x86_64]='setup-linux-amd64'
  [aarch64]='setup-linux-arm64'
  [armv5]='setup-linux-armv5'
  [armv6]='setup-linux-armv6'
  [armv7]='setup-linux-armv7'
  [i386]='setup-linux-386'
  [i686]='setup-linux-386'
)

# =============================================================================
# FUNCIONES AUXILIARES
# =============================================================================
_mov_die() { _mov_err "$1"; exit 1; }
_mov_require_root() { (( EUID == 0 )) || _mov_die "Ejecutar como root: sudo bash $0 <CLAVE>"; }

_mov_detect_arch() {
    local arch
    arch=$(uname -m)
    FILE="${MV_FILE[$arch]:-}"
    [[ -n "$FILE" ]] || _mov_die "Arquitectura no soportada: $arch\n  Soportadas: ${!MV_FILE[*]}"
}

_mov_verify_sha256() {
    local file="$1" expected="$2"
    local actual
    actual=$(sha256sum "$file" | awk '{print $1}')
    [[ "$actual" == "$expected" ]]
}

# =============================================================================
# BANNER DE INICIO
# =============================================================================
clear
_mov_banner "MOVIVIP NETWORK" "Instalador Automático • ${MV_VERSION}"
_mov_info "Sistema: $(uname -s) $(uname -r) $(uname -m)"
_mov_info "Usuario: $(whoami) @ $(hostname)"
_mov_info "Fecha:   $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo

# =============================================================================
# 1. VERIFICACIONES PREVIAS
# =============================================================================
_mov_section "Verificaciones previas"
_mov_require_root
_mov_ok "Ejecutando como root"

_mov_detect_arch
_mov_kv "Arquitectura detectada" "$(uname -m)"
_mov_kv "Stub seleccionado" "$FILE"

EXPECT="${MV_SHA[$FILE]:-}"
[[ -n "$EXPECT" ]] || _mov_die "No hay hash SHA256 registrado para ${FILE}."
_mov_ok "Hash SHA256 esperado cargado"

# =============================================================================
# 2. DESCARGA DEL STUB
# =============================================================================
_mov_section "Descargando instalador"

TMP="/tmp/${FILE}"
URL="${BASE}/${FILE}?h=${EXPECT}"

_mov_kv "URL" "${BASE}/${FILE}"
_mov_kv "Hash esperado" "${EXPECT:0:16}..."

# Descarga con spinner
_mov_step "Descargando ${FILE}..."
curl -fL --progress-bar -o "$TMP" "$URL" &
CURL_PID=$!
_mov_spinner $CURL_PID "Descargando..."
wait $CURL_PID || _mov_die "Descarga fallida: $URL"
_mov_ok "Descargado: $(du -h "$TMP" | cut -f1)"

chmod +x "$TMP"

# =============================================================================
# 3. VERIFICACIÓN DE INTEGRIDAD (fail-closed)
# =============================================================================
_mov_section "Verificando integridad SHA256"

_mov_step "Calculando hash..."
ACTUAL=$(sha256sum "$TMP" | awk '{print $1}')

if [[ "$ACTUAL" != "$EXPECT" ]]; then
    _mov_err "SHA256 NO COINCIDE — La descarga está corrupta o manipulada"
    _mov_kv "Esperado" "$EXPECT"
    _mov_kv "Obtenido " "$ACTUAL"
    _mov_info "El hash se verifica contra el valor incrustado en install-auto.sh"
    _mov_info "Si el problema persiste, regenera install-auto.sh tras recompilar stubs"
    rm -f "$TMP"
    exit 1
fi
_mov_ok "Integridad verificada ✓"

# =============================================================================
# 4. EJECUCIÓN DEL INSTALADOR
# =============================================================================
_mov_section "Iniciando instalador MoviVIP ${MV_VERSION}"

KEY="${1:-}"
if [[ -n "$KEY" ]]; then
    _mov_kv "Clave de licencia" "Proporcionada como argumento"
    _mov_info "Transfiriendo control al stub..."
    echo
    exec "$TMP" "$KEY"
else
    _mov_warn "No se proporcionó clave de licencia"
    _mov_info "El instalador la solicitará en pantalla"
    echo
    exec "$TMP"
fi