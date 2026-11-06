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
  [setup-linux-amd64]="9583541f9f09e13b2b1e01bff1e1a777cd0c3f7a22e2bbe6d165a3698e2b9b66"
  [setup-linux-arm64]="b64a329145b49a475011120ac7bc0bf664563ec3557e4756b0220f1758a276df"
  [setup-linux-armv7]="56db7eed77a1d27c26cd6e429bf04d961e4b05e2bb26844bdb5c5259b44d0f46"
  [setup-linux-armv6]="b585b7cdf51964f668fb23c733ed7839800af59f49115fa661635d885bd43fab"
  [setup-linux-armv5]="624b5cb54aecaf1df9105d18388143fd2aba4e35604534ad4391e06cfda3341f"
  [setup-linux-386]="2efdb2a52b5c6dd1a78a8e0042fb351456c71d6528fbd3418176affe4bdf0e39"
  [setup-linux-loong64]="ff6e566b034ba25c03287d139f4e958cc6c601e2fafb898ac6e7cc3718231360"
  [setup-linux-mips]="caa6015e2c7083a116a462d906ebe3401260b6f412881aaaeeae3172bbab6767"
  [setup-linux-mipsle]="4cbafd8aaa2985ab6508d6b254c1a6dfb7348b7a089a66fd875ea2584876503c"
  [setup-linux-mips64]="c14702bd0b0368256ae67e73a8c186d9e8b5eaed341b6f49771541ad417b69b0"
  [setup-linux-mips64le]="5cda1b8104c15a04d7a16592aa3fefc3ae0ca22dcd5edb560089f13733783365"
  [setup-linux-ppc64]="727aa585a1d89eb05b86b9dea123e10fcb0d2b8a6c028c78a7750d7af82c2359"
  [setup-linux-ppc64le]="952b99a5c8ba43e1770f9f5a46e8950a493fd4646b7c6d82ede16b4fab0438a2"
  [setup-linux-riscv64]="f101721175a752a456d720fd3759614a8a8c30a7a938b4ae2f73ca85fde3e228"
  [setup-linux-s390x]="fb1ab4d8bf7efb2a5c627db3133d00d76bda61c8d12eb2d3e5292e2867c047cf"
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
