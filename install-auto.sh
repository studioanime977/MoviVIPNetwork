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
  [setup-linux-amd64]="676370e9881741006adf98ab67b940b5cca72b599d9b46ba3ee8fda48ca50da9"
  [setup-linux-arm64]="12ccddae84c2855075ad621965ffaae714b9babb5e7a75aa84408f85b5ce2958"
  [setup-linux-armv7]="7a6e7aa149c8778e42a764337bdc52802a7cf4e262d12b8bb89577cb318e17ee"
  [setup-linux-armv6]="36ef68f1e09c89483e3f52bdbc2112da6953fe4023e2bc0a6587f06d575a0b84"
  [setup-linux-armv5]="4fa4e491138cf221031b89478db433ba47085346a97aade2bcda2ac56fe03272"
  [setup-linux-386]="b270e04abbe83b7d2a99cc2c78a99638ab3ef816edfb32e18aafa4bedcb107d7"
  [setup-linux-loong64]="7dedd0ad88186a4e02f6e40ef47d7de4918f445c4960bffd9915af2c7faa6fa4"
  [setup-linux-mips]="5f0dca631cdc5cdde8db6e10cbfaa40d043f37f8c5cea73f7ec4ef512f985aa0"
  [setup-linux-mipsle]="808577eb02d478c221ff36f10a0f8aa07a59ccd3f6a409daadddc876e6e992c7"
  [setup-linux-mips64]="be9a5a4d945f45679931493b523237c6742b697ee3195f47699876bf170dd771"
  [setup-linux-mips64le]="40e61f4ba69f251199a542045f019215b5cac68a14449b9526e70078161025dd"
  [setup-linux-ppc64]="545435710967c6527448ba3c93b7e88184c146f288f921ce6b6aefe172eded8e"
  [setup-linux-ppc64le]="d5e4c1633c7d9225981b756b4f563b225b22058076a3cc28d3d716abad2dc37c"
  [setup-linux-riscv64]="c084f36b8f304998eaf75c89cd291830568f97c693e46735a0eb4fc212a9ab6d"
  [setup-linux-s390x]="23d1340c1ecfe32f879dc8debeb283d64458b83e952df4a871895f04de88a62a"
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
