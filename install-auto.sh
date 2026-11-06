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
  [setup-linux-amd64]="029f14ecbadf9ac4871581170005eeef85e2123a892e510a5dde2ea618445e97"
  [setup-linux-arm64]="aabef02f3223d5e83218523fb4f7213d991e26d5bd7e5c6b1f46c3b14c8b167e"
  [setup-linux-armv7]="2577d55086a5d32ccc321759c99c05b12d0040cd5fa0c34bda9f795d365955ec"
  [setup-linux-armv6]="d5866391d55de9a1c44d16f5a0a8d39a1a44b3cbad70a6b041a040125b194589"
  [setup-linux-armv5]="3d65c72fe86806fa16dd1b42b726552c200739ba2df8f5f03f4fad03fa3f23d2"
  [setup-linux-386]="8305c47a120c02e690ec80cf3533ebaf064d3147babf1009b0d729d9bfa9d08d"
  [setup-linux-loong64]="dfa94d7356fe747037a5a5912a8dcdf94f3a7d08e82a324234700b84130df864"
  [setup-linux-mips]="be9853c87f119434156ef2ffa7e1e382f0e3c5ca7250d5ebb27c84732c15504e"
  [setup-linux-mipsle]="4eb6c63a021fb6e97e4ead8f4cd889e6bd668a1bfcfc7a0e2fab056bff7b0425"
  [setup-linux-mips64]="85c3def698ec7d2d8779b7d247574d185093a15a5e947c01db00db7c0994e9ad"
  [setup-linux-mips64le]="e46a27653b404ae0fa66de8fa0c16314b1ec3e1701de401bb81bc7d215b843b6"
  [setup-linux-ppc64]="df71093d05a31978c228bde36c8e0039a6d691a12eeff5f19f9e0ebcd7ddb1e6"
  [setup-linux-ppc64le]="f9549ff8bcfc50a677e2231762516e91be32db41c24d43094638583f179552e0"
  [setup-linux-riscv64]="a195b809e0dcfb7de311900bd24113de8d902b6b5be84475711d63c7deef3e13"
  [setup-linux-s390x]="cb717c1fd5fb72795ac21db4c3dd5fb04019f0771c43f5e57e4266f22d3f6086"
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
