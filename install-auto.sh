#!/usr/bin/env bash
# ============================================================================
# MoviVIP Network ??? Auto-instalador universal  (v8.2.20)
# Detecta arquitectura, descarga el instalador correcto y lo ejecuta.
# Generado por cmd/stup. No editar a mano.
#
# Uso:
#   curl -fsSL https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/install-auto.sh \
#     | bash -s -- TU_CLAVE_DE_LICENCIA
# ============================================================================
set -euo pipefail

MV_VERSION="8.2.20"
BASE="https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/stubs"

declare -A MV_SHA=(
  [setup-linux-amd64]="89420de340ca8386d6ab17899279209642ad2ba52d81639f3603ee1102838a38"
  [setup-linux-arm64]="4f7d905a2da9849ef239b3ac7a401beb799f4db90ed7f7376326caf21d862a89"
  [setup-linux-armv7]="250b1a866f95e326d76bcc14cb1d66bbc8ace99524e1f4bf1f85f793f83fd365"
  [setup-linux-armv6]="7dcd4ebdabe7ba049446ced52b8cbf959f6ecddbb883e4b363bd11da5fceed43"
  [setup-linux-armv5]="699d310ed464de0a7cccb075949069b81e79663c4b25edb6a5d0eeb87581d45f"
  [setup-linux-386]="d3f0c746f8a68738a69d34a2fc268daef388643ea72b8b5e88a0f908c8e9b2d5"
  [setup-linux-loong64]="26b23790bdee3760f62144d3b24437f4cb3797fcad234cca2a0ce608ff837dce"
  [setup-linux-mips]="bd8f7135a037ab095a9e337ec710be6dcb522727317b5c23054f37443cab9eec"
  [setup-linux-mipsle]="7414ac37c5b41173be9e03ae9db1ee8c523a3704c1cea3b927a8850a496f89d5"
  [setup-linux-mips64]="ac3762f0b33700223484bc70b52091baef1c2f9548383f52d53d1cc229bb29bc"
  [setup-linux-mips64le]="51fece9f8181bdc63634a414cf17d5015b2bbf87232bdba1d3db0cfacec683ac"
  [setup-linux-ppc64]="988449dafbe6102d43ecc12e88008c302c58168d25974957fe6021b25c7f2963"
  [setup-linux-ppc64le]="8284f67df4138df549013b389d4572128bc120669ce19719d171999e9d507ff2"
  [setup-linux-riscv64]="5e79e2a1adbf91ece9888b05a55e6fc31f23f45b3e6456f921caa3bee46e4377"
  [setup-linux-s390x]="f786abfe63b8dcfec6627af6d474d37a2792340f08d0c1affb4258286484ac4e"
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
