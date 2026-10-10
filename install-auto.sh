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
MV_VERSION="8.2.16"

# --- Hashes esperados, incrustados ------------------------------------------
# El hash viaja DENTRO del stub, no en un .sha256 suelto al lado del binario.
# Motivo: los dos artefactos se publican juntos en el mismo commit, asi que no
# pueden desincronizarse; y sigue sin haber ficheros .sha256 en el repo que
# mantener ni que alguien borre por accidente.
#
declare -A MV_SHA=(
  [setup-linux-386]="247c579de0573eb31b09e38d73d172330e74abdf0c4110e670ea2f970adc55ff"
  [setup-linux-amd64]="db6d66b1b814f45d78f54ea2db42551f40b305a4255b0c94e59832b21688bf34"
  [setup-linux-arm64]="c384990120fb356981b10d7427e3398efcbcf42264b95618f9078b7b15a1c58c"
  [setup-linux-armv5]="30a9155dffad015b8d84401c0d6bed46a06a112ebfb993d06e445b30eaa9506d"
  [setup-linux-armv6]="b127c9b9d6ff2df9c60dac7a50ba1bca5120c9884a06f0181ce52f9215398c51"
  [setup-linux-armv7]="c83beeb4d73d0f9588e9479c8a019bf51b01a17ab2a226cb5b15931ba5dfeab9"
  [setup-linux-loong64]="f6f2054981bb695ea29fa5360f852202d857cf4c572bc2b4033b977cc022bb14"
  [setup-linux-mips]="b08ef2ba502faa5d61a85f9ddb68e5d0379ee35872c0cb18d52ecc1f53a55e63"
  [setup-linux-mips64]="0987ebc1c80fb85a72b7a9957c92d9dc35cc346a82bd8427b503d56bdb64a69d"
  [setup-linux-mips64le]="c75ec93c7f0111d48a69c750cc729cdbb74e9a27d7479ce9cd533318f6439d62"
  [setup-linux-mipsle]="6582e1ba8937419bf5e98fbc69ef2573cedbfc1a25d2728dd3493cfc13c5eae1"
  [setup-linux-ppc64]="a7463a21b0d83265e09789d864de9cfd5ee7305c44c2aba625f910aa1659532a"
  [setup-linux-ppc64le]="c8752afcec7583f59928961e48d960fac59ce01e1472f9c4b9361f1e3ebd9b1f"
  [setup-linux-riscv64]="f7019cfd9b6e9866c39c4db7a0e9278b863a4205729b903579b942a1282f4e53"
  [setup-linux-s390x]="b4fd078d141af221ee95d4c787a50de1169ec6dc7bc15bb20435ce385c91519b"
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