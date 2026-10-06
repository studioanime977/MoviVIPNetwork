#!/usr/bin/env bash
# install-auto.sh — Instalador automático MoviVIPNetwork
# Descarga el stub correspondiente a la arquitectura, verifica integridad y lo ejecuta.
# v8.2.18 — NEBULA CYBER-VIP Design System

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
readonly MV_VERSION='v8.2.18'
readonly BASE="https://github.com/studioanime977/MoviVIPNetwork/releases/download/v8.2.18"
readonly REPO='studioanime977/MoviVIPNetwork'
readonly BRANCH='main'

# Hashes SHA256 REALES de los binarios en GitHub Releases v8.2.18
# Solo arquitecturas que SÍ se construyeron y publicaron
declare -A MV_SHA=(
  [setup-linux-amd64]='b5e3ef567f5fdd6a73cb2138e74b860cd1b5e00f0d0a4b722bed9904711f8259'
  [setup-linux-arm64]='e6cdd1af59d5af7fd2e5559b68ef7598a31bb1584130a317b7af59812555bfdc'
  [setup-linux-armv5]='d0ffe4490d549b371da81b40877d703ea1ffd0284fd188077dd4a163424bdb1d'
  [setup-linux-armv6]='85734dad4289aeb0a721e0fa823ef9eed4078c716675ddcfd2d2679fa2bf5056'
  [setup-linux-armv7]='3c5f19b488ccb504b5926d9466e7655be6caed3f0d373544f15787c2c1b51a34'
  [setup-linux-386]='e23ee70fb7c8a4b8a17b4c914e1ae386020e62ae21958c77cd17715ba9828a1f'
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