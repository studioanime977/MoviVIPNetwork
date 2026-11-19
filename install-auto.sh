#!/usr/bin/env bash
# ============================================================================
# MoviVIP Network — Auto-instalador universal  (v10.1.9)
# Detecta arquitectura, descarga el instalador correcto y lo ejecuta.
# Generado por cmd/stup. No editar a mano.
#
# Uso:
#   curl -fsSL https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/install-auto.sh \
#     | bash -s -- TU_CLAVE_DE_LICENCIA
# ============================================================================
set -euo pipefail

MV_VERSION="10.1.9"
BASE="https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/stubs"

declare -A MV_SHA=(
  [setup-linux-amd64]="4fb82e31564517a5c3ac51f918d8df4131033d8c5c6e7e7d1cfc51c1bcd3a95d"
  [setup-linux-arm64]="a6ee2693d9ad86da4020cd03eb690f80ebacff88e0116be42f398649f63696a7"
  [setup-linux-armv7]="f7667cbe6a82db76f5c01512c1f34d41168709f035137edc021387825fdc74c8"
  [setup-linux-armv6]="b6ec2aefa08b5a317d7175d62239818da32a9e9477fb70257a8ed65bf984ca8e"
  [setup-linux-armv5]="f9e2d860747b45fc479d3dbe4591bf06c089aa1ed20fe6e0bf381232de8e864f"
  [setup-linux-386]="fff7449a2e79d0fdbc5eb4a4b010a8cb48c46cc4b4aa868c71e50b2203374611"
  [setup-linux-loong64]="b2ff1739ffe7fa7e2ab0ed995674f3258e0cba8656c1bb46229ad87e3bfba9dd"
  [setup-linux-mips]="537ac845d22b2e2b7c7b6ee39c2314e0dd7fa80dfbb7dde1066a84ea7b92b19b"
  [setup-linux-mipsle]="af1ab0d4e9de7fae2575e084daeff20e3322f3bac3b62aacf58c26379bd92c44"
  [setup-linux-mips64]="584be4be32edf73f8cb5db5c08700a6c232cdf16764468578768c64f330b0eff"
  [setup-linux-mips64le]="6b2b79b54f81efc02e84774829005756f5e3a60d76b0a68710a969b9987c6a0a"
  [setup-linux-ppc64]="a9c0e8edd582eabbf257784481e128008de2c62c8638cc1bafd2c75a3d57f25e"
  [setup-linux-ppc64le]="033defb678509b6149feb2af8d8e3818c10596baa716d585cffcacf1c0bcf0ce"
  [setup-linux-riscv64]="ae41bf45234a43dc80acbe0701d45d7de230eabb7e243da81783da29e9172dad"
  [setup-linux-s390x]="ad1050af3bd27ddaacd67a37b82231ad713b3613b333d2268065bbf17c9a761d"
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
