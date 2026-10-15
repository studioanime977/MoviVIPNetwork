#!/usr/bin/env bash
# ============================================================================
# MoviVIP Network — Auto-instalador universal  (v8.2.16)
# Detecta arquitectura, descarga el instalador correcto y lo ejecuta.
# Generado por cmd/stup. No editar a mano.
#
# Uso:
#   curl -fsSL https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/install-auto.sh \
#     | bash -s -- TU_CLAVE_DE_LICENCIA
# ============================================================================
set -euo pipefail

MV_VERSION="8.2.16"
BASE="https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/stubs"

declare -A MV_SHA=(
  [setup-linux-amd64]="0dace8c316245c0d0bdea70cfce4ebc29a557e145bdaee9c2e74f86af4b0b9eb"
  [setup-linux-arm64]="3a0fd7b41bdbc8a7d4fe4cb51db47c358faf6ff2e2df5339d1d6e4d3c460d291"
  [setup-linux-armv7]="41b248cad744dba3530588992b74edac0c7a8dcccb10b3f2425597d08c65b022"
  [setup-linux-armv6]="d2f9140c5bf9e4e48def9f53fbc9dfd0f1e8761f7fac1c81ad9e79a3f0f8ca67"
  [setup-linux-armv5]="d2d1117803b558a946f48bb5039a8fb3f7ef3dee8c7cb148f5600741a83dbc9e"
  [setup-linux-386]="116d16155030396c4fe51e7c71fc359cbaf89ea05e960cc57b0dacb155867052"
  [setup-linux-loong64]="f26f89fb1518235648c1c1242df4540880cad3434022bb8262fab982015f68d0"
  [setup-linux-mips]="073b08b361109aa89e9d94afce8f9702a65cc3c3c63e9028b335b9086a2680de"
  [setup-linux-mipsle]="35f0fb33d5de9cea635f2e7a298bbf77aaef2d6817d58d270f2f9f394649fdd5"
  [setup-linux-mips64]="1bb0e4498b2a0e6335b0d1a6cba33af38fc0f49a4cac9909da388f0d53eadb8d"
  [setup-linux-mips64le]="0efca9efd75a92f3574dc25c4e2d18ca75a5ca62bb79ada188d98f82ff8dcc87"
  [setup-linux-ppc64]="b3d032cc5dc455040508e8af05421bcd5185942b2cef9b73f74860dcbc5c774d"
  [setup-linux-ppc64le]="8d23786bf671f24e00359e3331d651fa535aec1ed3e8636de4ee44807bb3b503"
  [setup-linux-riscv64]="4ff8bade14424164b2092cd56cd8837bc0a5101fd1b3e8d3bfcf144890e98b7f"
  [setup-linux-s390x]="f5660cc16e00b7c5979fc49d0f538c50c2e68c7fc9bb44c95dbf262eacfc0ccb"
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
