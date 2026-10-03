#!/usr/bin/env bash
# ============================================================================
# MoviVIP Network — Auto-instalador universal  (v8.2.16)
# Detecta arquitectura, descarga el instalador correcto y lo ejecuta.
#
# Uso (la clave es opcional: si no la pasas, el instalador la pide por pantalla):
#   curl -fsSL https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/install-auto.sh \
#     | bash -s -- TU_CLAVE_DE_LICENCIA
#
#   sudo curl -fsSL https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/install-auto.sh \
#     -o /usr/local/bin/movivip && sudo chmod +x /usr/local/bin/movivip
#   sudo movivip
# ============================================================================
set -euo pipefail

REPO="studioanime977/MoviVIPNetwork"
BRANCH="main"
BASE="https://raw.githubusercontent.com/${REPO}/${BRANCH}"
# Prefijo MV_ a proposito: /etc/os-release define VERSION, NAME, ID, HOME_URL...
# y al hacer ". /etc/os-release" abajo nos sobreescribiria las variables.
MV_VERSION="8.2.16"

# --- Colores: ANSI-C quoting => ESC real, no hay escapes que processar -------
if [[ -t 1 ]] && [[ "${TERM:-dumb}" != "dumb" ]]; then
    R=$'\033[0;31m'; G=$'\033[0;32m'; Y=$'\033[1;33m'
    C=$'\033[0;36m'; B=$'\033[1m';   N=$'\033[0m'
else
    R=''; G=''; Y=''; C=''; B=''; N=''
fi

# Format strings fijos: los colores viajan como argumentos %s, nunca
# interpolados en el formato (evita que printf los trame como literales).
msg() { printf '%s[MoviVIP]%s %s\n' "$C" "$N" "$*"; }
ok()  { printf '%s  [OK]%s %s\n'     "$G" "$N" "$*"; }
warn(){ printf '%s[AVISO]%s %s\n'    "$Y" "$N" "$*"; }
err() { printf '%s[ERROR]%s %s\n'    "$R" "$N" "$*" >&2; exit 1; }

# --- 0. Dependencias --------------------------------------------------------
if ! command -v curl >/dev/null 2>&1; then
    msg "Instalando curl..."
    apt-get update -y >/dev/null 2>&1 || err "apt-get update fallo"
    apt-get install -y curl >/dev/null 2>&1 || err "No se pudo instalar curl"
    ok "curl instalado"
fi
command -v sha256sum >/dev/null 2>&1 || err "sha256sum no disponible (instala coreutils)"

# --- 1. Clave ---------------------------------------------------------------
# Opcional aqui a proposito. Este script solo descarga y arranca el binario; es
# el stub quien muestra "Clave de licencia: " y valida contra el servidor. Si
# este script exigiera la clave, el usuario nunca veria ese prompt.
KEY="${1:-}"

# --- 2. Detectar arquitectura ----------------------------------------------
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64|amd64)   FILE="setup-linux-amd64"; LABEL="x86_64/amd64" ;;
    aarch64|arm64)  FILE="setup-linux-arm64"; LABEL="ARM64/aarch64" ;;
    armv7l|armhf)   err "Arquitectura $ARCH no soportada (se requiere ARM64 o amd64)" ;;
    i386|i686)      err "Arquitectura $ARCH no soportada (se requiere 64 bits)" ;;
    *)              err "Arquitectura desconocida: $ARCH" ;;
esac
msg "Arquitectura: ${G}${LABEL}${N} -> ${C}${FILE}${N}"

# --- 3. Verificar root ------------------------------------------------------
(( EUID == 0 )) || err "Ejecutar como root:  sudo bash install-auto.sh <CLAVE>"

# --- 4. Verificar SO compatible --------------------------------------------
if [[ -f /etc/os-release ]]; then
    # shellcheck source=/dev/null
    . /etc/os-release
    case "${ID:-}" in
        ubuntu) (( ${VERSION_ID%%.*} >= 20 )) || warn "Ubuntu ${VERSION_ID}: minimo 20.04" ;;
        debian) (( ${VERSION_ID%%.*} >= 11 )) || warn "Debian ${VERSION_ID}: minimo 11" ;;
        *)      warn "Distribucion no probada: ${PRETTY_NAME:-desconocida}" ;;
    esac
fi

# --- 5. Descargar instalador (ELF puro, no wrapper shell) -------------------
TMP="/tmp/${FILE}"
msg "Descargando ${C}${FILE}${N} (v${MV_VERSION})..."
if ! curl -fL --progress-bar -o "$TMP" "${BASE}/${FILE}"; then
    err "Descarga fallida: ${BASE}/${FILE}"
fi
chmod +x "$TMP"
ok "Descargado: $(du -h "$TMP" | cut -f1)"

# --- 6. Integridad: si hay .sha256 publicado, DEBE coincidir ---------------
# Fail-closed: nunca se ejecuta un binario cuyo hash no coincida.
if curl -fsSL -o "${TMP}.sha256" "${BASE}/${FILE}.sha256" 2>/dev/null; then
    msg "Verificando integridad SHA256..."
    EXPECT="$(tr -d '\r' < "${TMP}.sha256" | awk 'NF { print $1; exit }')"
    ACTUAL="$(sha256sum "$TMP" | awk '{ print $1 }')"
    [[ -n "$EXPECT" ]] || err "archivo .sha256 vacio o ilegible"
    [[ "$EXPECT" == "$ACTUAL" ]] || err "SHA256 no coincide (archivo corrupto o manipulado)"
    ok "Integridad verificada"
else
    warn "No hay .sha256 publicado: se omite la verificacion de integridad"
fi

# --- 7. Ejecutar ------------------------------------------------------------
# El stub verifica firma Ed25519, arquitectura y licencia ANTES de extraer nada.
# Con clave se la pasamos; sin clave, que la pida el mismo en la consola.
msg "Iniciando instalador MoviVIP v${MV_VERSION}..."
if [[ -n "$KEY" ]]; then
    exec "$TMP" "$KEY"
fi
msg "No se paso clave: el instalador la pedira en pantalla."
exec "$TMP"