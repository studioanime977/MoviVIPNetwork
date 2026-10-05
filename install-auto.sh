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
#
declare -A MV_SHA=(
  [setup-linux-amd64]="2de494cb72bc44607ef8aee84bb15aee7141901a681c3f276b64e3361ed3370a"
  [setup-linux-arm64]="ebe312a431887d87ae68cffe984d32bed71f17c2189c507c9b678837f675ff1b"
  [setup-linux-armv5]="2ae07735591bb331114d2ba854aa7770f69600aaf37bf325e71b661cbe8529f4"
  [setup-linux-armv6]="3d5c2c235cf08aec71067f5606b78cc02f77848ba8e2a946666c3c79c2734374"
  [setup-linux-armv7]="5f4f6f2fbd00c7d3e659a093d105dee0d3b755b857492172418a928982efb01d"
  [setup-linux-386]="19ad073215006d7a8449305e3107b2154bb997f4b475dcc12485dfc953a8bb34"
  [setup-linux-loong64]="63e0c2ba1046caaeaf42149733c4095d45c58304ec20164f35f8827b55859bc1"
  [setup-linux-mips]="3a42bdc61ad762792595c6b5be4b4bee46e98620cf3fd825836e5e239d6cf471"
  [setup-linux-mipsle]="869592ef7f2a1e00c0c040b4e77a9dd6ced4d94ec4bcc78b743c2b005acae6f0"
  [setup-linux-mips64]="dbc3042e3b4c9a080f379ba9afce7b213bf0f12f2eeebb6b2db68b38db9b862a"
  [setup-linux-mips64le]="6230c6c18583a9e4b6ec3a3f46b2db65918435caae50cebd07991a8c527e9693"
  [setup-linux-ppc64]="84fc187d74838cb418cd615f0a6e2b63353798eafcee71ef52b0b28978f84c97"
  [setup-linux-ppc64le]="6add8123207c39effc7c8ac5bbc49eccfe0c19a6b6e20142303d46cc5d8bb5b4"
  [setup-linux-riscv64]="08ce169bbed0286ed66e82087bd7a773e1d4f56e9cc940a96ebdf2106d29d8f1"
  [setup-linux-s390x]="365ad133be8c7d739ec9f1b7c91305761c58dcbec35261ba25b4f994106c0240"
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
# uname -m devuelve el nombre de la maquina, no el GOARCH de Go, asi que
# cada nombre se traduce al binario que se publico para el. Los tres casos
# delicate:
#
#   - armv7l/armhf cae en armv7 (GOARM=7). Es el paquete mas Conservative y
#     funciona en cualquier ARMv7 o superior, Raspberry Pi 3 y 4 incluidos.
#     Bajar a armv5 no aporta nada aqui y sube el riesgo en hardware viejo.
#   - i386/i686 es 32 bits de verdad y cae en 386. Antes se rechazaba con
#     "se requiere 64 bits"; el instalador de 386 existe y funciona.
#   - Los little-endian (mipsle, ppc64le, mips64le) tienen su propio binario y
#     no comparten nada con sus gemelos big-endian.
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64|amd64)     FILE="setup-linux-amd64";   LABEL="x86_64/amd64" ;;
    aarch64|arm64)    FILE="setup-linux-arm64";   LABEL="ARM64/aarch64" ;;
    armv7l|armhf|armv7) FILE="setup-linux-armv7"; LABEL="ARMv7/armhf" ;;
    armv8l)           FILE="setup-linux-armv7";   LABEL="ARMv8 32 bits" ;;
    armv6l)           FILE="setup-linux-armv6";   LABEL="ARMv6 (legacy)" ;;
    armv5l)           FILE="setup-linux-armv5";   LABEL="ARMv5 (legacy)" ;;
    i386|i686)        FILE="setup-linux-386";     LABEL="x86 32 bits" ;;
    loongarch64)      FILE="setup-linux-loong64"; LABEL="LoongArch64" ;;
    mips64el|mips64le) FILE="setup-linux-mips64le"; LABEL="MIPS64 little-endian" ;;
    mips64)           FILE="setup-linux-mips64";  LABEL="MIPS64 big-endian" ;;
    mipsel)           FILE="setup-linux-mipsle";  LABEL="MIPS32 little-endian" ;;
    mips)             FILE="setup-linux-mips";    LABEL="MIPS32 big-endian" ;;
    ppc64le)          FILE="setup-linux-ppc64le"; LABEL="PowerPC64 little-endian" ;;
    ppc64)            FILE="setup-linux-ppc64";   LABEL="PowerPC64 big-endian" ;;
    riscv64)          FILE="setup-linux-riscv64"; LABEL="RISC-V 64" ;;
    s390x)            FILE="setup-linux-s390x";   LABEL="IBM Z (s390x)" ;;
    *)
        err "Arquitectura desconocida: $ARCH
        Soportadas: x86_64, aarch64, armv7l/armv8l, i386, loongarch64,
        mips, mipsel, mips64, mips64el, ppc64, ppc64le, riscv64, s390x."
        ;;
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