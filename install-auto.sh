#!/usr/bin/env bash
# ============================================================================
# MoviVIP Network — Auto-instalador universal  (v10.1.1)
# Detecta arquitectura, descarga el instalador correcto y lo ejecuta.
# Generado por cmd/stup. No editar a mano.
#
# Uso:
#   curl -fsSL https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/install-auto.sh \
#     | bash -s -- TU_CLAVE_DE_LICENCIA
# ============================================================================
set -euo pipefail

MV_VERSION="10.1.1"
BASE="https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/stubs"

declare -A MV_SHA=(
  [setup-linux-amd64]="606957ad06f0c17e2aae72c436f499b7c7d8399f5fce61d06b01a945fb2f3dd4"
  [setup-linux-arm64]="ab211106e3eb76c8d3517d45b6d26e04c5f06d70ef6c9719a32e9de164cae5e4"
  [setup-linux-armv7]="7c1588e6eb4699e143baf4cfaf617aea26e4873de74b9a6ed94522ded7fba68f"
  [setup-linux-armv6]="22d5dcceccb003f6438b34ffce91eb8d15b3a63922309308a1ba8ee648be395c"
  [setup-linux-armv5]="8b8759fbcc0d4bbe1cc724df7efa29b3ddc98e9fbe34d4fef7632f35e92b63af"
  [setup-linux-386]="78b873d4422e9abfb19b48149751dcfb94c1e9e4a9b6177568679dfbcc6b9660"
  [setup-linux-loong64]="9f39e712c3ee57b35f89350faefdf5ecc87c6888f18e9be54c6a4b56090cc260"
  [setup-linux-mips]="7dacbb4f17d0f6759903cdb188460899cb205345261da0b9a16069769c6a1602"
  [setup-linux-mipsle]="8f81d472682a2e84da6528fa76b38d7c1aac0926f6153cba644e1cbd8386b8d0"
  [setup-linux-mips64]="ec3326f1415a1ada388067051ef1f90f610485a27aba6a168bb8bbb61748e9ab"
  [setup-linux-mips64le]="0b9f0fa6e7e0ad8c77b805f9292c8388a2c2cd7430e9197e52d0145b3e2fa491"
  [setup-linux-ppc64]="3fe4878e59b128cb978a4554a1d1c680ca8c8bb9c04ae10ab4197056798af535"
  [setup-linux-ppc64le]="9d46529ee8ab80d3c206cc05b60f4ac6e74144eb049250ffa4540cfc9d49f8b5"
  [setup-linux-riscv64]="a31ce841400c383639d590d5bec22e43cbc43bceaba27ef94c1155b16ff03744"
  [setup-linux-s390x]="143ac9e886883df9238cb39cefb745eb1d727b0e26b420896f501b83eae91b64"
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
