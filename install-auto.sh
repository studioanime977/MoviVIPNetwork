#!/usr/bin/env bash
# ============================================================================
# MoviVIP Network — Auto-instalador universal  (v10.1.8)
# Detecta arquitectura, descarga el instalador correcto y lo ejecuta.
# Generado por cmd/stup. No editar a mano.
#
# Uso:
#   curl -fsSL https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/install-auto.sh \
#     | bash -s -- TU_CLAVE_DE_LICENCIA
# ============================================================================
set -euo pipefail

MV_VERSION="10.1.8"
BASE="https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/stubs"

declare -A MV_SHA=(
  [setup-linux-amd64]="8d47be058e44be98203e2242022ac4b2f836bbe81b4268584e4f705cd54ed320"
  [setup-linux-arm64]="45fbe154e633560f4c6a50489910e647b1234ac9b1cc88614d2a5574629797e9"
  [setup-linux-armv7]="18a0894fcfbcaf9b34c77d544793cc65fc661bb92c5737aafc61c35dab7ba37c"
  [setup-linux-armv6]="ed9b6a5b48d7d6d0220e81594fca54467c56616a7dcd9a7e105c9a50e64f2ddd"
  [setup-linux-armv5]="44086cbd0aad8a696b90a191f76a94393bb2603d6abd03500131f6742bb63fa7"
  [setup-linux-386]="c001a6359622635819bc24d9f2211f60791d228c52a98fa3e84eb47b4295200f"
  [setup-linux-loong64]="7a533da58ff60fb81498eff19dd47c13565d0c0eb391b11966c1b1593c95d152"
  [setup-linux-mips]="e272b69870da21f8a05cc85b362a732893f74aaf9448d935d4b85c8854dde949"
  [setup-linux-mipsle]="041b86bc0cb487cae384c0e7b17aaa0f95b80fb0d4e3b38a32ee278de4ee9c79"
  [setup-linux-mips64]="e8ecea2975a2166f70df2e90e5436bba947ef4d18f5f3bad992d1be6e311987b"
  [setup-linux-mips64le]="3309f37fc1566b04ee58ffc5d9b4db5dedc84f89592a11c44896d5b46ffc2c01"
  [setup-linux-ppc64]="9072d0a25c8af8f699ca3f99f4e37c044583672114e445b631b65fa1496d0f9a"
  [setup-linux-ppc64le]="efdae922486c1e12e7280cfeb1e1e58bbfc078b02737e00cc38a9089c9561deb"
  [setup-linux-riscv64]="61ca32d061186665362421b674ca7e52cdc4fa9a34ac5499999373c98294c11c"
  [setup-linux-s390x]="fbf85b92f0de183dbf4a9b14226366ad5793c30be09b4365c8c92cca8253b2cd"
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
