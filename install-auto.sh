#!/usr/bin/env bash
# ============================================================================
# MoviVIP Network — Auto-instalador universal  (v10.1.6)
# Detecta arquitectura, descarga el instalador correcto y lo ejecuta.
# Generado por cmd/stup. No editar a mano.
#
# Uso:
#   curl -fsSL https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/install-auto.sh \
#     | bash -s -- TU_CLAVE_DE_LICENCIA
# ============================================================================
set -euo pipefail

MV_VERSION="10.1.6"
BASE="https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/stubs"

declare -A MV_SHA=(
  [setup-linux-amd64]="2a19d46f4e5c17f0bdf3347959da0519e0e40343f413fd2afd8aed37238a656e"
  [setup-linux-arm64]="44cf25a314167c1ff8b4567a32a88718c64e4c262b59c14355a825973ad42220"
  [setup-linux-armv7]="31437d5f6484f941ac0874143d015819568aea20e8b30e650fb20d2b2125c65a"
  [setup-linux-armv6]="b1c043663057d604ba5a5443c8cf3104765ec5f8d510ea6bf2f8dc18fd60d63f"
  [setup-linux-armv5]="5981c8093c94be361cd0ab13f4615ad5f272eaa469c8108191d72a56cf68df08"
  [setup-linux-386]="ba0188368a459f0b3d38abb9a8d5c384ca2ad45b72cb0cae7a7ec4e0c6ccf8a9"
  [setup-linux-loong64]="b1c2deb7281c233dca1cd2e6432b9b49025c3fb19c06d449d3046c93c7de9df6"
  [setup-linux-mips]="8c60edc4ffdbe41eea22728682baf511753193fb09711b0353735c3fbf444c5d"
  [setup-linux-mipsle]="ef3d92c53de2bee7acd37c8fcb7cdd1cf0f19654d61ac834d67434a8cbb6242a"
  [setup-linux-mips64]="8d1f79d4738b155e5f14906eeb0ffd5156280509eac0c5695dadce4d9bc0ba3d"
  [setup-linux-mips64le]="9ac56159f0bccc598b552a13f6766f94bd9336e908fb806c7d2898535b13ecd3"
  [setup-linux-ppc64]="27c01df1a0bba3329c74e72c3effc872ea5ac7564b0b435fb4c9847da6321957"
  [setup-linux-ppc64le]="fa7f9ffabbca2979ec02bc0039576c3aa8e2533d72ed59ef812affc1f162733a"
  [setup-linux-riscv64]="5459d90f0a2c237636b3c18702ad1a288b2002ef57b6bc516e543cd7272cd543"
  [setup-linux-s390x]="7ac5066fed6a572f10d77810954aecfd2748dbbf58b46b53637ef7354b989566"
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
