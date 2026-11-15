#!/usr/bin/env bash
# ============================================================================
# MoviVIP Network — Auto-instalador universal  (v10.1.4)
# Detecta arquitectura, descarga el instalador correcto y lo ejecuta.
# Generado por cmd/stup. No editar a mano.
#
# Uso:
#   curl -fsSL https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/install-auto.sh \
#     | bash -s -- TU_CLAVE_DE_LICENCIA
# ============================================================================
set -euo pipefail

MV_VERSION="10.1.4"
BASE="https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/stubs"

declare -A MV_SHA=(
  [setup-linux-amd64]="78b221d60248f05e8ddb41b7a9a8ca2de2fdad4e70b345405f2c2483bbab7fb9"
  [setup-linux-arm64]="f8c50767f833f93529cc5e2dee185dcabe50625bf08cf75aad650ef1d005fcd0"
  [setup-linux-armv7]="95224c045b1bf3d7e335e9c2f11cd12390ccc92cd12fc503e603666cc9681fe5"
  [setup-linux-armv6]="e1a08150cbc6be3b72c2f5129b305e29d5cec59779f00f8b9a5e84a43535fb5d"
  [setup-linux-armv5]="7c7fb98faf391e7ca7edd3d180bb1fc3ad4eb7c0c222957364a828e3acf5ac6f"
  [setup-linux-386]="2252ea1fd8fd48284a27a3d66abe9f7792c79335e6f8ad332cec6cd99cad1173"
  [setup-linux-loong64]="9352752644becd7a8e51b3b7701dc38bc127982d1755d2adc4d20faac662c332"
  [setup-linux-mips]="0c565a77fd31313dfb2ced315eb86ddf8134e8a274f4a3058f2fc3bbd3c13d0d"
  [setup-linux-mipsle]="647ad5b38cb7ea60069f4a95c6513618cb6a5c9a52f73c8824049bb8c20600c9"
  [setup-linux-mips64]="86a47db420c5c0e6eeaf1eaa7416acc481f6c6d112d9319243c2b2237c78d53b"
  [setup-linux-mips64le]="69efd19b14a59d70e9108c36ad9af54c35a997a1d6a4c4ac66c301f694705f44"
  [setup-linux-ppc64]="ebe6d24d7dad7a7ae72a9406a819e1967dde5faf013ac18679e7d2d1bf3d4cbc"
  [setup-linux-ppc64le]="57fe10293fe02e4fbf80d645f65b61a7ad37be9a0b680dacb67dcb5df4b1bf83"
  [setup-linux-riscv64]="a421fcbf7c14eebecd64f5189a4f838e6b4671478d3772a285e9366c9f51bbe2"
  [setup-linux-s390x]="546cd06a629c212a0a58ed2d441d0669265215f1c528f2ea4d27dd51352e3e4f"
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
