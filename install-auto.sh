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
  [setup-linux-amd64]="815e3262a835f9cae27cdd67d7642d7af10291886b108be627525b37cbc361fd"
  [setup-linux-arm64]="19c618352c413c2ad7cdad7392a9c6ac803b5806739f49d965fb6366b0ae87e7"
  [setup-linux-armv7]="4c7586819579546b40592817d500137b5d1f21726f49fe072da048cf3f61cd81"
  [setup-linux-armv6]="b2f914e50bff8b8da69022e0b275c555073fc51f79d910381116eb1ea4cfa1a5"
  [setup-linux-armv5]="871f4a2fccd839b423abca6dbe0f7426575db8349cadf5dd1e5e0fdf5e4cdeff"
  [setup-linux-386]="db4efdcd0f771c1e009ad36f86d2340919c162e096ce631b973810737a8fcd7c"
  [setup-linux-loong64]="ebe619c1294e17cfee85e6bf5e791e193b2c791750636b859cbd414066b7952a"
  [setup-linux-mips]="c4b7ea1c422301e72e312746bee8c2f27ef28706988d19aca933e52a3a8e703c"
  [setup-linux-mipsle]="038179222f34cf71c268d53f75df5fd68d10b8f2d070d2c6459d00e1597234b0"
  [setup-linux-mips64]="93497e332fda0672f408e6f61e3b38e5fed03f2f266ad873f85f2a1b377f273b"
  [setup-linux-mips64le]="67dae43237e13d3360a1f5c7991b5c53c5ef3162e0a38f0c3ea6c51a097a1bba"
  [setup-linux-ppc64]="92561ac8b0f02af393405130fb40998d03f59745d2229c43335d010b55e38a31"
  [setup-linux-ppc64le]="ec8a6f339de9424473b5ea3352dee3e113333195bc30c0ed2d7aa8a77b193fd9"
  [setup-linux-riscv64]="28d0b35d1b29a74068fee153c5c5ee9584a6c32247d5c3aef9dfd600fdd995cf"
  [setup-linux-s390x]="a34acc2fb9c25b2b3df5408be703780c8bcee0df6029cab5a59b3ee2468f5d87"
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
