#!/usr/bin/env bash
# ============================================================================
# MoviVIP Network — Auto-instalador universal
# Detecta arquitectura, descarga el instalador correcto y lo ejecuta.
# Uso: bash -c "$(wget -qO- https://github.com/MOVIVIPNETWORK/movivip-setup/raw/main/install-auto.sh)" TU_CLAVE
# ============================================================================
set -euo pipefail

REPO="MOVIVIPNETWORK/movivip-setup"
BRANCH="main"
KEY="${1:-}"

# Colores
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; C='\033[0;36m'; N='\033[0m'

msg() { printf "${C}[MoviVIP]${N} %s\n" "$*"; }
ok()  { printf "${G}[OK]${N} %s\n" "$*"; }
warn(){ printf "${Y}[AVISO]${N} %s\n" "$*"; }
err() { printf "${R}[ERROR]${N} %s\n" "$*"; exit 1; }

# 1. Validar clave
[[ -n "$KEY" ]] || err "Uso: bash -c \"\$(wget -qO- URL)\" TU_CLAVE_DE_LICENCIA"

# 2. Detectar arquitectura
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64|amd64)     FILE="setup-amd64.sh"; LABEL="x86_64/amd64" ;;
    aarch64|arm64)    FILE="setup-arm64.sh"; LABEL="ARM64/aarch64" ;;
    armv7l|armhf)     err "Arquitectura $ARCH no soportada (binarios VPN requieren ARM64/amd64)" ;;
    i386|i686)        err "Arquitectura $ARCH no soportada (requiere 64 bits)" ;;
    *)                err "Arquitectura desconocida: $ARCH" ;;
esac

msg "Arquitectura detectada: ${G}$LABEL${N} -> ${C}$FILE${N}"

# 3. Verificar root
(( EUID == 0 )) || err "Ejecutar como root (sudo)"

# 4. Verificar SO compatible
if [[ -f /etc/os-release ]]; then
    # shellcheck source=/dev/null
    . /etc/os-release
    case "${ID:-}" in
        ubuntu) [[ "${VERSION_ID%%.*}" -ge 20 ]] || warn "Ubuntu ${VERSION_ID}: mín. 20.04" ;;
        debian) [[ "${VERSION_ID%%.*}" -ge 11 ]] || warn "Debian ${VERSION_ID}: mín. 11" ;;
        *) warn "Distribución no probada: ${PRETTY_NAME:-desconocida}" ;;
    esac
fi

# 5. Descargar instalador
BASE="https://github.com/MOVIVIPNETWORK/movivip-setup/raw/main"
URL="${BASE}/${FILE}"
TMP="/tmp/${FILE}"

msg "Descargando ${C}${FILE}${N}..."
if ! wget -q --show-progress -O "$TMP" "$URL"; then
    err "Descarga fallida. Verifica conexión a github.com"
fi
chmod +x "$TMP"
ok "Descargado: $(du -h "$TMP" | cut -f1)"

# 6. Verificar integridad (sha256 opcional)
SHA_URL="${BASE}/${FILE}.sha256"
if wget -q -O "${TMP}.sha256" "$SHA_URL" 2>/dev/null; then
    msg "Verificando integridad SHA256..."
    if ! sha256sum -c "${TMP}.sha256" 2>/dev/null; then
        warn "SHA256 no coincide (archivo puede estar corrupto)"
    else
        ok "Integridad verificada"
    fi
fi

# 6. Ejecutar instalador con la clave
msg "Iniciando instalador MoviVIP v8.2.16..."
exec bash "$TMP" "$KEY"