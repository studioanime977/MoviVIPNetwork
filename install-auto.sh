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
  [setup-linux-amd64]="e458712bb7143c89ac6b4159c39a3af2e8ee3f236d0a68cf66e927f309591c42"
  [setup-linux-arm64]="cc734c070145d39eb6d2515a54702026478837d22e5718122f0e150d430ca505"
  [setup-linux-armv7]="563ab5eaf5e69657613d933d74f6f11c518ae8f3f7bc0b387f2045936650f6e4"
  [setup-linux-armv6]="02529077b106dd8c8a0bb034267f52c0371ce784c08dd2bfe8ec3f79ddafcecb"
  [setup-linux-armv5]="1f6a932a3bc4eeee413a63675bf0d4b75f2bae29e42e99e9817b32c6b161ce2b"
  [setup-linux-386]="6b44f5918e1f8e083c3a314502f68feea568221f83ac96df1987f4bd93968e4d"
  [setup-linux-loong64]="9a67078e383f63b0bb8a7d375742cc66982cd950156fe20a0acedf81bd20d65a"
  [setup-linux-mips]="077e19a50a01955299f55d684948200588a53309797ef5b50bfb023b5db6585d"
  [setup-linux-mipsle]="633b1d4a712d5dc69fba3eb30cd342c939aea48e020ea1d0087f80c324189bab"
  [setup-linux-mips64]="d0126d312f82de367973ae78462e9853a385945a763e00188ccfa2780f1624fe"
  [setup-linux-mips64le]="d5ce4542a1393db0a5f4d7e3fa4b72de7f50005523137113cae8860bb0bca1f8"
  [setup-linux-ppc64]="a2c9a53bc2cd5c904514e09ddaf7984b4f328d2853964df3488793cd6e8e66cb"
  [setup-linux-ppc64le]="4f733241f92b371b6b407da868ae72b8084f7f527753f0edf8b87a7880bf8a18"
  [setup-linux-riscv64]="cdb395261393436b8f544631e065ab71de40e49ffb0d652391adee672bd91111"
  [setup-linux-s390x]="b74fed5a3690b6ec3894f139dae3073bc729d04af4e03b38bcb53a8fe7ba43e8"
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
