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
  [setup-linux-amd64]="dcff94fb229df089d86d32a885d060ee847f86645222f5718e0b47a4552f41a7"
  [setup-linux-arm64]="10f5687166d208adf6392cc35714e1ab72800324ec02fecb712696b8a785860b"
  [setup-linux-armv7]="6ed28f735d531f0c5fabdc2a36b6f60d1478398a4110f787b288de99c4c6e225"
  [setup-linux-armv6]="ffb2d0086b2bd799c9e17b7a5be1b9df47b59ea3a3215505be0035cf242ecdc5"
  [setup-linux-armv5]="3818cf4acd05e0f28477d53ce1cb44ae7cf623170ac7181c25d588fb98c949d9"
  [setup-linux-386]="69c4c11846c119b74ac938b5092daac7aa657159d1afb9538f6175df7df9ac5e"
  [setup-linux-loong64]="eb1df447092f0eadec96967b5f2c3710cf85660c04b9f4a849f2398750055fc7"
  [setup-linux-mips]="a255a932f9edc28e9f4ea87b0066c2fb548c4fe867949bb3bcb79ab0c87a2bf1"
  [setup-linux-mipsle]="2d29b8131817597c905d0a1b7ff9440bb80c9be654d9a778f6e7f7b5cd13f166"
  [setup-linux-mips64]="50635029b4733e15fb0cd85fb63814e37cf7cd06be9c6adb1d95621195b83452"
  [setup-linux-mips64le]="bbe875de2c4c8a506d9a5c5e95c77b8774099761551306e6f0afb8792291d619"
  [setup-linux-ppc64]="28cad82308c36df96200cb23ad6410d24864ffc2c3a3428c332c1e5913815505"
  [setup-linux-ppc64le]="1fdd86012feb60f078731ef3b7be2a43b008bf0f20d4ff4e058e0b87f4ac45ec"
  [setup-linux-riscv64]="e578985c4cb55f9f0d865bec306ff78dc3d3001c2dc6fdc5cd6c79859fcdc1c9"
  [setup-linux-s390x]="047c0dc24bfbd581bcb4a9dbbf2bf38c491c6bd093bcb1c6e56fb0ac90eb5a9d"
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
