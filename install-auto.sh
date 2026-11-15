#!/usr/bin/env bash
# ============================================================================
# MoviVIP Network — Auto-instalador universal  (v10.1.7)
# Detecta arquitectura, descarga el instalador correcto y lo ejecuta.
# Generado por cmd/stup. No editar a mano.
#
# Uso:
#   curl -fsSL https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/install-auto.sh \
#     | bash -s -- TU_CLAVE_DE_LICENCIA
# ============================================================================
set -euo pipefail

MV_VERSION="10.1.7"
BASE="https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/stubs"

declare -A MV_SHA=(
  [setup-linux-amd64]="dbfa45938484a179938bc012cf415c6ba94785d4d2f57c677d701764182d6253"
  [setup-linux-arm64]="989f3cfbdf02ba520fb3cd673aad4c0a657e5a841aa0af6a35a3ac9a9169804f"
  [setup-linux-armv7]="7fe74326c81e84d3b55274b2cefe298bf365481045554e47ae807f45cb6d202c"
  [setup-linux-armv6]="0aba2508692e4703ee6f8a5c58e59e662e1e4b001288c639ad07b4229e0e4b06"
  [setup-linux-armv5]="5d2975efdf6cc6c7c9d5f2be2240fb6cb28e0ccc9f31755d269799d72dafc5b5"
  [setup-linux-386]="d074ee8281015b3f2fe01057d848f6469a9b0df22333f690fa65b144ec7a4d40"
  [setup-linux-loong64]="3fc9f01acf19f6bffa4577ca07684623041360403f08f0d3143345e36fd2f1a2"
  [setup-linux-mips]="73efad1e78a8cee2ede40ae4c07559d50ad8e8873b252ad7cd08d251c075d317"
  [setup-linux-mipsle]="afaafc396ed6eeda32f406578faf8f5c3ad25611c6f65aa14609ccab1a00f9ec"
  [setup-linux-mips64]="1816524ce764a32e8cb37b3f02a0efb3a9e3bcdd9c9e86043be15e6d12d898e7"
  [setup-linux-mips64le]="14ac11b40b77cd9b97ccc41234bf6734fe5b77fd12ce428f155c5578b5edce58"
  [setup-linux-ppc64]="27a2eaf1251037e21fbc53e7d94b48708b69c60fdec0ec34915f661be77a5601"
  [setup-linux-ppc64le]="15c511e7c29ca624e37dea688ad4f62f1e2a17460928ea85655cb2f0cdfd0182"
  [setup-linux-riscv64]="d852c3e11a375a9a91db42517a0839bf632066cef658e245e35845a45d67af9e"
  [setup-linux-s390x]="387fd2394b5cd4ecdbdb8e0f4bdbdaee1008d88870f8dd47c095b48c51d7eb2b"
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
