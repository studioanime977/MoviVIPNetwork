#!/usr/bin/env bash
# ============================================================================
# MoviVIP Network — Auto-instalador universal  (v10.1.2)
# Detecta arquitectura, descarga el instalador correcto y lo ejecuta.
# Generado por cmd/stup. No editar a mano.
#
# Uso:
#   curl -fsSL https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/install-auto.sh \
#     | bash -s -- TU_CLAVE_DE_LICENCIA
# ============================================================================
set -euo pipefail

MV_VERSION="10.1.2"
BASE="https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/stubs"

declare -A MV_SHA=(
  [setup-linux-amd64]="9c2db90ab4da81f4f05a2caa918c39d7a5a1d5711d7f0a59822e7e45f7758e96"
  [setup-linux-arm64]="b4a654bb28a3fdbb3e53b0ff0ad8753380065f90d361b4788bec17c70dcde30c"
  [setup-linux-armv7]="7bfacb8dc90958ee6cc0361332512bfa902eae0323bb11a751a6f97c68384a69"
  [setup-linux-armv6]="f73be61906563af89355a123a4311b45c6be5d4018d3644f76a493a02beacef0"
  [setup-linux-armv5]="bda96653dce8fab9fbab3ebb2b77b234a44e14051fb2488ca8eafbed2644e358"
  [setup-linux-386]="3714157d904ae0fdb633e60704cb6fd496a24f42187be5cb5a33a68ba1028c3c"
  [setup-linux-loong64]="778570c934ff33edcdfe08b7017cf4ed251a8b8765628050ba5164dcb4fcd4fb"
  [setup-linux-mips]="3b98f69e1ff14271f4bbc074094398786a8375f6a3185b80532a70b3abf4c0b5"
  [setup-linux-mipsle]="c8c0f37596c5e5bc898d7c0db6d1598d47c548e56b9ad9af180fcba0282708d7"
  [setup-linux-mips64]="c59d0b1f5709155b9c0a7b500f0a2fa2a617dffbc0b82fd6f31a843ff15e5f03"
  [setup-linux-mips64le]="0c3dbe0c801cf010d28fb5cae39d33995363f7c73895223cdeb70c313ead66bd"
  [setup-linux-ppc64]="b90383c3b8624efc21952afe540024c213506276c264186feb87f1bee19305ab"
  [setup-linux-ppc64le]="e71b311349b1567c2b242ec4bf577b289fae15ddac08ad76c40633d4af1a664b"
  [setup-linux-riscv64]="b510412758d5666be4668c1c99ca4b2674670e20b5bc36c514a4d6a5a877c9e5"
  [setup-linux-s390x]="7fa6479ba6d7b7b84a1c116c56ebb3dabf0500b6dcb2fefa89980d776421a8d2"
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
