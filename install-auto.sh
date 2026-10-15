#!/usr/bin/env bash
# ============================================================================
# MoviVIP Network — Auto-instalador universal  (v8.2.20)
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
  [setup-linux-amd64]="c5f01cef5ddbaf612766443e54e7728bf8c3e12a85bf3f5e30126d5cda93ac94"
  [setup-linux-arm64]="f3977a3edf86a23d4919b78c0b5445bf1222eca46d218474d5dad21219dff959"
  [setup-linux-armv7]="2ac1130034992bc253cd6bad05aa6fb4c914110c156f56c4b9e743f6ece8ba42"
  [setup-linux-armv6]="971486fe7b9f2e375b6dd9c331dce2d129d32fed625efaa244614b4002406c7f"
  [setup-linux-armv5]="ec089e99ae5262505be5af3ef575bc904eff5a9204567d4290b3f745690d934e"
  [setup-linux-386]="bcdd2acdd365970ca69177a20447502399eae5b38912562441242790d9b0b3af"
  [setup-linux-loong64]="2c9ee846b2198c0c20202949a721dd0c005733a1b98430843c0b13af48c3d42e"
  [setup-linux-mips]="927a04a4a36637569c9c213c198991c326769503a72c57a249c171bc3c20ab43"
  [setup-linux-mipsle]="4673b6cc7f483b0516585fc09f1094577b7e6875e15dc2b42c0f6da6f0e57c9b"
  [setup-linux-mips64]="1708bc9b5fc0432bc24bde034cc6e6d38e4c192f1507d7fbd944b1f9dd2eea9a"
  [setup-linux-mips64le]="383664bd903b5ecbfe67784a762bdb2a717f3f88c231a8d2b7748dc94e789802"
  [setup-linux-ppc64]="a5aab91bd15c270c2066fff42e5151692d2052d45ca067787dc3c73d2851f714"
  [setup-linux-ppc64le]="7fd89f529f66d95e1da37bcf69520877b75137b76db9c8a27ae7af3d9e9c42ee"
  [setup-linux-riscv64]="a00b0c170ed6ab38c2ce6ae570690d90ae9def9498fbf64115b8732651dc198f"
  [setup-linux-s390x]="f538d49116601e259a4d171d792dd661f1cfdba6093b27059ae2636e5d9eaff5"
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
