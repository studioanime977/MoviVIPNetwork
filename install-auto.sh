#!/usr/bin/env bash
# ============================================================================
# MoviVIP Network — Auto-instalador universal  (v10.1.3)
# Detecta arquitectura, descarga el instalador correcto y lo ejecuta.
# Generado por cmd/stup. No editar a mano.
#
# Uso:
#   curl -fsSL https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/install-auto.sh \
#     | bash -s -- TU_CLAVE_DE_LICENCIA
# ============================================================================
set -euo pipefail

MV_VERSION="10.1.3"
BASE="https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/stubs"

declare -A MV_SHA=(
  [setup-linux-amd64]="ad90a609fd3f0f81911e27a525e5e0e8298613401df6d40a1e2839a57cee00de"
  [setup-linux-arm64]="2027ad8df94319237161efbb01bed8fd090cc520c69f11a7c3a1ff4d650ebcba"
  [setup-linux-armv7]="11dbbc35f43890cff6a5ead531aeb66f71ca5d322b372de8947f9e349614f936"
  [setup-linux-armv6]="8da7bdf6164185e5f04476ee16dd2fae67e82973c3aae0ef71af3dab120d1e71"
  [setup-linux-armv5]="535a9683dc0956e3e7155ae05890b73ec28e382f07eac3b3b41867d14c150931"
  [setup-linux-386]="3e177fa76cfce54adfb39ccbafeb3fb04ef0d0aaff8cc95dca95b0c6b5e1cfa3"
  [setup-linux-loong64]="36c7ad5200689ddc464e9ce4d4611a894ac20cc03c61b43124b0e0460a142cb6"
  [setup-linux-mips]="0d7e33c976fb9251d9c08942b9495785168891535b616ab4a70d9eb8326ec5d1"
  [setup-linux-mipsle]="a68ceb9851a5c1eb2fe734ca0e6ec62b1ecb51358af8ba41a10ef932f3a09aa4"
  [setup-linux-mips64]="b6890082bf506ea4aeb2a7491ced86fa25a27a0171ae4667eec47814e6877360"
  [setup-linux-mips64le]="3f6b52359648cd20096e75f41bf608abc423c43b4e68509aa0d70a167befb4f4"
  [setup-linux-ppc64]="01c4389370b1eaf76e5f4ccdd70da566347f6d12e4aedbb0ebaa4e777cdf857b"
  [setup-linux-ppc64le]="477cd5cbb4a2d91cea1c3e6f96c83c471c8a793a7fbb1866a7e7a5d188ef0dea"
  [setup-linux-riscv64]="54d4789ab942db26b8c923d176a787d6aa0e5d2aac593dd8b3ade4f7092ea324"
  [setup-linux-s390x]="fcb22e5b015b5b80c9c105eeb6d2ba1455fa16c092f4d1e4ecff0c28b0c3ccf9"
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
