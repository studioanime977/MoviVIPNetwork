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
BASE="https://raw.githubusercontent.com/${REPO}/${BRANCH}/stubs"
# Prefijo MV_ a proposito: /etc/os-release define VERSION, NAME, ID, HOME_URL...
# y al hacer ". /etc/os-release" abajo nos sobreescribiria las variables.
MV_VERSION="9.0"

# --- Hashes esperados, incrustados ------------------------------------------
# El hash viaja DENTRO del stub, no en un .sha256 suelto al lado del binario.
# Motivo: los dos artefactos se publican juntos en el mismo commit, asi que no
# pueden desincronizarse; y sigue sin haber ficheros .sha256 en el repo que
# mantener ni que alguien borre por accidente.
#
declare -A MV_SHA=(
  [setup-linux-386]="e8757c9da7eb5032e3084d6ffc80bf37781cdcf6dfc94aeee595182220f3fb59"
  [setup-linux-amd64]="535f47a6a099d7dad6a3bdd67b0336edfa222fba9481775e09ccea0d9b1e180f"
  [setup-linux-arm64]="52443f61317cd8795cb8849640aa0633adb72eaf7c277872eb9e408d17772e25"
  [setup-linux-armv5]="31f0f4365254d7cd261c309e59999ca4edba4dd6a9d7922e3d611265ffe33f05"
  [setup-linux-armv6]="1ab0ec4cc195c7b4c074693995583e23ac4d3aa1bb3cad7d01da39fd320de837"
  [setup-linux-armv7]="53f1152195243de948addf97d466651e73bc74a1d768d25cbec722c00460c8f2"
  [setup-linux-loong64]="18ab314c564df23bda542ed3061ee9894dd35e910d7d9b855af2bc5acd86ce33"
  [setup-linux-mips]="46085ab4dd95fadc1312993f1fee2a4529abeee70a8f4dccaf76fb6038cfb306"
  [setup-linux-mips64]="2df80441ea099a09557d3f9f1bf4f98647d96e22894cbce917eba60b53ebf7e5"
  [setup-linux-mips64le]="5a23a6b91df91eb6b5e5a33b44f28a132717426fd15d776a99e8679a8f2b4219"
  [setup-linux-mipsle]="a374e68670d1947e3f73129a838c5236ea8f8a20608ef67d8d0e4a81cd1aef85"
  [setup-linux-ppc64]="d4aa1deb9076363f6e0950ac57458d2cc01ef0562a8b76e63e170103020fc8f8"
  [setup-linux-ppc64le]="c9ef75afa85ae49c7655d4710df78d64c6f61f4c9e0e971f0fc66874d6938598"
  [setup-linux-riscv64]="b741fd63f2f11fd608a731d01e44300f6c8c055f1e0317ac86ee00126b403438"
  [setup-linux-s390x]="892842883f945f2f18b9c5749cd2f0433a2c8156676e9b9a8ada2b15a217a1e5"
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