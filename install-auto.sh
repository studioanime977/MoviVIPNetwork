#!/usr/bin/env bash
# ============================================================================
# MoviVIP Network — Auto-instalador universal  (v8.2.16)
# Detecta arquitectura, descarga el instalador correcto y lo ejecuta.
# Generado por cmd/stup. No editar a mano.
#
# Uso:
#   curl -fsSL https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/install-auto.sh \
#     | bash -s -- TU_CLAVE_DE_LICENCIA
# ============================================================================
set -euo pipefail

MV_VERSION="8.2.16"
BASE="https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/stubs"

declare -A MV_SHA=(
  [setup-linux-amd64]="649f6e1fe2b38f1e312ca05cb9c671391732748275f656371a1bb2e72566f214"
  [setup-linux-arm64]="32c39b5b3bc2fb307734d9f5aca44dbc711a712af39c9b116b1c9397a0564830"
  [setup-linux-armv7]="edc1892d1b0122d20d4c1a4b40f33961a8b088435a2ccf65decf3a185079763a"
  [setup-linux-armv6]="3870994870e392a89dc58b94474accd2b56aa57a298aebaea9597c493bdf2c43"
  [setup-linux-armv5]="f69a123878f495a65261d49c20017d555f294078ae566a5ae31da526a87d1b61"
  [setup-linux-386]="e0781ea5a67a8358d7c0017543ccb46c1732e0bfb79eb87021368c837a11d329"
  [setup-linux-loong64]="24403df46e5428142a7688fc44bebc6ced19a443d397d1c67f305588190d47ac"
  [setup-linux-mips]="385a2ee56147f3ab706b110c2aa444bd606995922a8b4c61c18a7ccbe1875f00"
  [setup-linux-mipsle]="171ecbf5658e47b3f29878339eab8080d0b4b3eecc3ab56af92049038d779619"
  [setup-linux-mips64]="9aa7826327c9b7808f7380b7fe428bc1ed18f9cca36de3843ddf7427495b835d"
  [setup-linux-mips64le]="4455a25c7816b46ae2bcfa84cef4935fabfc946de1301fcdec8b445d7b894cd5"
  [setup-linux-ppc64]="256fafa71b897a94dad7f484042ce13bc64e13ab189882a0a9a72d421118c052"
  [setup-linux-ppc64le]="0bbeb90d1d8ccd2a51b4e01a5fc371cad1ebf1d7efd26675f854c1b49a67e4d5"
  [setup-linux-riscv64]="7d0bf826ab5270eee63f4d1383b1dc98fc02d3c0d25ac0fd7d7826c9bc9036b7"
  [setup-linux-s390x]="832e350b61a154dd76c8c5469dab324d9d5e3f1dd185ffdcdc6be8778f2faa92"
)

if ! command -v curl >/dev/null 2>&1; then
    apt-get update -y >/dev/null 2>&1
    apt-get install -y curl >/dev/null 2>&1
fi
command -v sha256sum >/dev/null 2>&1 || { echo "[ERROR] sha256sum no disponible" >&2; exit 1; }

KEY="${1:-}"
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64|amd64)     FILE="setup-linux-amd64" ;;
    aarch64|arm64)    FILE="setup-linux-arm64" ;;
    armv7l|armhf|armv7) FILE="setup-linux-armv7" ;;
    armv8l)           FILE="setup-linux-armv7" ;;
    armv6l)           FILE="setup-linux-armv6" ;;
    armv5l)           FILE="setup-linux-armv5" ;;
    i386|i686)        FILE="setup-linux-386" ;;
    loongarch64)      FILE="setup-linux-loong64" ;;
    mips64el|mips64le) FILE="setup-linux-mips64le" ;;
    mips64)           FILE="setup-linux-mips64" ;;
    mipsel)           FILE="setup-linux-mipsle" ;;
    mips)             FILE="setup-linux-mips" ;;
    ppc64le)          FILE="setup-linux-ppc64le" ;;
    ppc64)            FILE="setup-linux-ppc64" ;;
    riscv64)          FILE="setup-linux-riscv64" ;;
    s390x)            FILE="setup-linux-s390x" ;;
    *) echo "[ERROR] Arquitectura desconocida: $ARCH" >&2; exit 1 ;;
esac

(( EUID == 0 )) || { echo "[ERROR] Ejecutar como root" >&2; exit 1; }

EXPECT="${MV_SHA[$FILE]:-}"
[[ -n "$EXPECT" ]] || { echo "[ERROR] Sin hash registrado para ${FILE}" >&2; exit 1; }

TMP="/tmp/${FILE}"
URL="${BASE}/${FILE}?h=${EXPECT}"
curl -fL --progress-bar -o "$TMP" "$URL" || { echo "[ERROR] Descarga fallida" >&2; exit 1; }
chmod +x "$TMP"

ACTUAL="$(sha256sum "$TMP" | awk '{ print $1 }')"
if [[ "$EXPECT" != "$ACTUAL" ]]; then
    echo "[ERROR] SHA256 no coincide (descarga corrupta o manipulada)" >&2
    echo "  esperado: ${EXPECT}" >&2
    echo "  obtenido: ${ACTUAL}" >&2
    exit 1
fi

if [[ -n "$KEY" ]]; then
    exec "$TMP" "$KEY"
fi
exec "$TMP"
