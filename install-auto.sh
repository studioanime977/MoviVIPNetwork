#!/usr/bin/env bash
# ============================================================================
# MoviVIP Network ??? Auto-instalador universal  (v10 Full)
# Detecta arquitectura, descarga el instalador correcto y lo ejecuta.
# Generado por cmd/stup. No editar a mano.
#
# Uso:
#   curl -fsSL https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/install-auto.sh \
#     | bash -s -- TU_CLAVE_DE_LICENCIA
# ============================================================================
set -euo pipefail

MV_VERSION="v10 Full"
BASE="https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/stubs"

declare -A MV_SHA=(
  [setup-linux-amd64]="1e7a8ea49f54cafcf893fb396d6c7fe0fb9046d996f71c17aec5b1205ae0c64c"
  [setup-linux-arm64]="4e72a1d05e2b66769a8600b30ad54a95859ff979877c1a688982796341f480ea"
  [setup-linux-armv7]="360b980d144e59788e84b86abe87272e52886bcb0ef83c6ce0c946c12299951b"
  [setup-linux-armv6]="5b63b018a9b59d5021dd4622fe8351e53436fafa0b1ca532c8dd076d4bbe2c8c"
  [setup-linux-armv5]="51054f408a66fcf7d8f6fa13f3f8876f044557e523cbd2a99052458e63b7365c"
  [setup-linux-386]="7ea1e7ce1a89c432580d3a85bb3a3fa6d41c913a41456705968c23fafe8db576"
  [setup-linux-loong64]="19c0f6c488af3d9060b43a6258504c16e06813e8c4b8faca49734f9641a999c8"
  [setup-linux-mips]="7a53d6952dd85f7c462c776dac9dbdd4328b62694e6a5ef9a770eb125d6bea47"
  [setup-linux-mipsle]="0bd094deed1bd5f4ec405bc5d0f0d09ea82fb22ae9ddc21163dc49fbf9247d02"
  [setup-linux-mips64]="0e6d9355f31be1865abd57cac83dd6ca65b86c920b0e426d4b6dccf882b4d832"
  [setup-linux-mips64le]="b936bfb9c3266edf90596cc822e45c2e2f5fe7f79d4a2718a1ff75b63003272e"
  [setup-linux-ppc64]="66c9b8b590a5bb61b0461d3a9f313f3fc09d4599aca2708d3c7a8892692b0ca9"
  [setup-linux-ppc64le]="4c290f07d6cf72e54d1bf3579e8ccf801893f23dcb2128f5e9563b9f3b88c2d4"
  [setup-linux-riscv64]="64f50d48f5af3224625310ce9e221229b0adf051d187fdb797ed38fb14697e26"
  [setup-linux-s390x]="c73091a41cb178f6af9b9abe18123a663c1d4fd5ef8fd6c9fc6aa311feeaeff8"
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

TMP="$(mktemp "/tmp/${FILE}.XXXXXX")" || { echo "[ERROR] No se pudo crear un archivo temporal" >&2; exit 1; }
trap 'rm -f -- "$TMP"' EXIT
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
    "$TMP" "$KEY"
else
    "$TMP"
fi
