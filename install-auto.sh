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
#
# ESTE FICHERO ES UNA PLANTILLA: los marcadores 6beb38538d114dad8464cdf79c6187c8f802e64016a34ab98667eb2f4c5eea59 y
# ea4413c3918528090f0bdb05d3313359aea607de0f6d476e729efbd210caced7 los sustituye wrapper/build-wrapper.ps1 con el hash real
# de cada payload recien compilado. No editar el resultado a mano: se
# regenera. Editar esta plantilla, si.
# ============================================================================
set -euo pipefail

REPO="studioanime977/MoviVIPNetwork"
BRANCH="main"
BASE="https://raw.githubusercontent.com/${REPO}/${BRANCH}"
# Prefijo MV_ a proposito: /etc/os-release define VERSION, NAME, ID, HOME_URL...
# y al hacer ". /etc/os-release" abajo nos sobreescribiria las variables.
MV_VERSION="8.2.16"

# --- Hashes esperados, incrustados ------------------------------------------
# El hash viaja DENTRO del stub, no en un .sha256 suelto al lado del binario.
# Motivo: los dos artefactos se publican juntos en el mismo commit, asi que no
# pueden desincronizarse; y sigue sin haber ficheros .sha256 en el repo que
# mantener ni que alguien borre por accidente.
declare -A MV_SHA=(
  [setup-linux-amd64]="6beb38538d114dad8464cdf79c6187c8f802e64016a34ab98667eb2f4c5eea59"
  [setup-linux-arm64]="ea4413c3918528090f0bdb05d3313359aea607de0f6d476e729efbd210caced7"
)

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

# --- 5. Resolver el hash esperado ANTES de descargar ------------------------
# Hace falta aqui y no en el paso 6 porque la URL de descarga lleva el hash:
# ver el comentario del paso 6.
EXPECT="${MV_SHA[$FILE]:-}"
[[ -n "$EXPECT" ]] || err "Este stub no tiene hash registrado para ${FILE}.
        Significa que install-auto.sh se publico sin regenerar tras compilar
        el payload. Regeneralo con wrapper/build-wrapper.ps1 y vuelve a intentarlo."

# --- 6. Descargar instalador (ELF puro, no wrapper shell) -------------------
TMP="/tmp/${FILE}"
msg "Descargando ${C}${FILE}${N} (v${MV_VERSION})..."

# El hash va en la query, y no por tan solo por cache-busting: es lo que
# convierte un wrapper obsoleto en un fallo ruidoso en vez de una trampa.
#
# raw.githubusercontent.com sirve por CDN y puede devolver durante un rato la
# version anterior del binario. Sin esto pasa esto: un cliente que ejecuta un
# wrapper de hace un rato se baja un payload viejo, lo instala, y le falla mas
# tarde por un motivo que no tiene nada que ver con la causa real. Ya ha
# pasado: un E2E instalo un payload de la compilacion anterior porque el CDN
# aun servia la copia vieja.
#
# Con el hash en la query cada payload tiene una URL unica, asi que el CDN no
# puede confundir una version con otra. Y si este stub va obsoleto (pide el
# hash viejo pero el binario en esa ruta ya es el nuevo), la comparacion del
# paso 7 no cuadra y el script para con un error claro. Falla cerrado.
URL="${BASE}/${FILE}?h=${EXPECT}"
if ! curl -fL --progress-bar -o "$TMP" "$URL"; then
    err "Descarga fallida: $URL"
fi
chmod +x "$TMP"
ok "Descargado: $(du -h "$TMP" | cut -f1)"

# --- 7. Integridad: hash incrustado, fail-closed ----------------------------
# Antes este bloque descargaba "${FILE}.sha256" y, si GitHub devolvia 404,
# avisaba y seguia SIN verificar. Eso es fail-open: una descarga truncada, un
# CDN que devuelve HTML de error, o alguien que sube un binario distinto,
# pasaban igual. Ahora el stub exige conocer el hash de su archivo; si no lo
# conoce, se niega a arrancar en vez de instalar a ciegas.
msg "Verificando integridad SHA256..."
ACTUAL="$(sha256sum "$TMP" | awk '{ print $1 }')"
if [[ "$EXPECT" != "$ACTUAL" ]]; then
    err "SHA256 no coincide: la descarga esta corrupta o manipulada.
        esperado: ${EXPECT}
        obtenido: ${ACTUAL}"
fi
ok "Integridad verificada"

# --- 7. Ejecutar ------------------------------------------------------------
# El stub verifica firma Ed25519, arquitectura y licencia ANTES de extraer nada.
# Con clave se la pasamos; sin clave, que la pida el mismo en la consola.
msg "Iniciando instalador MoviVIP v${MV_VERSION}..."
if [[ -n "$KEY" ]]; then
    exec "$TMP" "$KEY"
fi
msg "No se paso clave: el instalador la pedira en pantalla."
exec "$TMP"