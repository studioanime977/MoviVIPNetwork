#!/usr/bin/env bash
# ============================================================================
# MoviVIP Network — Auto-instalador universal  (v10.1.5)
# Detecta arquitectura, descarga el instalador correcto y lo ejecuta.
# Generado por cmd/stup. No editar a mano.
#
# Uso:
#   curl -fsSL https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/install-auto.sh \
#     | bash -s -- TU_CLAVE_DE_LICENCIA
# ============================================================================
set -euo pipefail

MV_VERSION="10.1.5"
BASE="https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/stubs"

declare -A MV_SHA=(
  [setup-linux-amd64]="0831050935a7472dfcf28a099f25e488ce68917c54087532121c718105aae1c9"
  [setup-linux-arm64]="20431b7318b7b2b5c1089d9b29c8fa38090dffe1c81323f9daa4cf7ece8d7aaa"
  [setup-linux-armv7]="bea12b8bd96d121492fac71a9ac7bb632d413cfeb1d68353927bd74dceaa8825"
  [setup-linux-armv6]="991f3d647ac98c96d7c705913bbf72aa24d25032206d546b9162a6f43ae21d18"
  [setup-linux-armv5]="cedd341ddf782c01e804e309cc0d8513b671d3e753ce1a439626e5bba591529f"
  [setup-linux-386]="05810f0818868aa69b739887f6c18cfadb69ba21530562db709bb7c53125f083"
  [setup-linux-loong64]="b47d8b96602b9d57de402b5be97674ce01cb30f44a1f17d74f8879cb20908c31"
  [setup-linux-mips]="9acd8aef163f6d896e60c96b594f4ef7930beb83c5552c00c9cf43eb10b81afe"
  [setup-linux-mipsle]="5585b2b4bedd4bd81965d8c3052b2ba0ba6ada076f87b00e28126123c2993554"
  [setup-linux-mips64]="9cda4cdc6d093f0d388cede0103838e488a4ebd9cf3935d67d5faa25b3174f9a"
  [setup-linux-mips64le]="d9e49c70b04e6f97aebada0b09fd99130ec4db7c1395ca97c9bcfc26b6a71d68"
  [setup-linux-ppc64]="ea6fc3061a6d769ccb647012c414ff78b18e91a1709fd823fd9c799174c80ddd"
  [setup-linux-ppc64le]="2f7a1e9b6ee2a5814808c9d510cddc60498a0615d070f50df0bd0ceaeeef1ed7"
  [setup-linux-riscv64]="15a359614927b0bc669afb639c10e1b6108e006ba2f1828063f828d5287b2710"
  [setup-linux-s390x]="5a83be87f71c84b54a38fdf1fc1b0e5f4282bf280edd09090327a047238562d5"
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
