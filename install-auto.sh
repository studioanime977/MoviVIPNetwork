#!/usr/bin/env bash
# ============================================================================
# MoviVIP Network — Auto-instalador universal  (v10 Full)
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
  [setup-linux-amd64]="4bf04c1aa4d9c2b3d5a8314e320feb32952a4aafce59276ee1a063af0e34bff7"
  [setup-linux-arm64]="b09b38173b51d1b2f7940cd9f5e0a8a222bda387d942c41a781abbf5d0abe849"
  [setup-linux-armv7]="a5fc4e953d7c1ddbfacb31738a2ee3ff334389929334ad0f5fbf56921cd4fb64"
  [setup-linux-armv6]="c18af3fe27680db5abd2e70231a510e98f126e9832ebc5a297caeaa54479bb72"
  [setup-linux-armv5]="0b204d221b03d3c9c94bfc741b6b1ee51eb2df39805b7c050dddd138cb5d9697"
  [setup-linux-386]="f9a2daa8851b025da52d1523519caa9c79f621cee25af4794c18f52068d4bcf3"
  [setup-linux-loong64]="6aaaaebe9c23db563a8b2d415cfafe85df1b50c643775394ffc5d66845350329"
  [setup-linux-mips]="5963464f42a12686eb49e578f4f0d1295f599662d73dfb5bab321b3ce8d78d2f"
  [setup-linux-mipsle]="68c2859f9609476b98cf29445e14921e5c2b113912ad76c1a7f5a711a347689b"
  [setup-linux-mips64]="5f2d9155481b17eb4a12150b90aa2bdf08a6e498265d1e453ad05c1be0e0dc55"
  [setup-linux-mips64le]="99904ebce2cbe8b91c99cf3016820f82f0bff5c631fd1adc343385b8ab2d3417"
  [setup-linux-ppc64]="4843f2e18cc2edbaa1b45fa0c99ce4e98661da19496baf09bd91dbf3242ddb00"
  [setup-linux-ppc64le]="8504d1a0f0ebe90aee08fc05aa9f9b5dadf85ded5e686adb49518b44f560817f"
  [setup-linux-riscv64]="00550fbbbe8b839061eefcd10deede6213cc4de19349f5bbe417bed3bfaf344b"
  [setup-linux-s390x]="a243c41fd895deebdd4002132dd0c8b9a7f82dda2d29791b2a42795bec8358a2"
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
