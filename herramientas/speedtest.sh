#!/bin/bash

# ── i18n shim (auto) ───────────────────────────────
if ! declare -F trx >/dev/null 2>&1; then trx() { printf '%s' "$1"; }; fi
# ─────────────────────────────────────────────────────────
BASE="/etc/movivip"

CYAN="\e[1;96m"
GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
MAGENTA="\e[1;95m"
WHITE="\e[1;97m"
RESET="\e[0m"

#--------------------------------------------------
# Detectar arquitectura y elegir el binario oficial
#--------------------------------------------------
detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64)   echo "x86_64" ;;
        aarch64|arm64)  echo "aarch64" ;;
        armv7l|armv6l|armhf) echo "armhf" ;;
        armel)          echo "armel" ;;
        i386|i486|i586|i686) echo "i386" ;;
        *)              echo "" ;;
    esac
}

instalar_speedtest() {

    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${MAGENTA}            ⬇️  INSTALANDO SPEEDTEST${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    ARCH=$(detect_arch)

    if [[ -z "$ARCH" ]]; then
        echo -e "${RED}❌ Arquitectura no soportada: $(uname -m)${RESET}"
        echo
        read -n1 -r -p "$(trx 'Presione una tecla para continuar...')"
        return
    fi

    if command -v speedtest >/dev/null 2>&1; then
        echo -e "${YELLOW}ℹ️  Ya hay un speedtest instalado: $(command -v speedtest)${RESET}"
        echo -e "${WHITE}   Se actualizará con la versión oficial de Ookla.${RESET}"
        echo ""
    fi

    echo -e "${WHITE}📥 Descargando Ookla Speedtest CLI (linux-$ARCH)...${RESET}"
    TMP_DIR=$(mktemp -d)
    URL="https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-${ARCH}.tgz"

    if ! curl -fsSL "$URL" -o "$TMP_DIR/speedtest.tgz" 2>/dev/null; then
        echo -e "${RED}❌ No se pudo descargar $URL${RESET}"
        rm -rf "$TMP_DIR"
        echo
        read -n1 -r -p "$(trx 'Presione una tecla para continuar...')"
        return
    fi

    if ! tar -xzf "$TMP_DIR/speedtest.tgz" -C "$TMP_DIR" 2>/dev/null; then
        echo -e "${RED}❌ Error al extraer el paquete.${RESET}"
        rm -rf "$TMP_DIR"
        echo
        read -n1 -r -p "$(trx 'Presione una tecla para continuar...')"
        return
    fi

    if [[ ! -f "$TMP_DIR/speedtest" ]]; then
        echo -e "${RED}❌ Binario speedtest no encontrado en el paquete.${RESET}"
        rm -rf "$TMP_DIR"
        echo
        read -n1 -r -p "$(trx 'Presione una tecla para continuar...')"
        return
    fi

    chmod +x "$TMP_DIR/speedtest"
    if cp -f "$TMP_DIR/speedtest" /usr/local/bin/speedtest 2>/dev/null; then
        echo -e "${GREEN}✅ Speedtest oficial instalado en /usr/local/bin/speedtest${RESET}"
        if "$TMP_DIR/speedtest" --version >/dev/null 2>&1; then
            VERSION=$("$TMP_DIR/speedtest" --version | head -1)
            echo -e "${GREEN}   Versión: $VERSION${RESET}"
        fi
    else
        echo -e "${RED}❌ No se pudo copiar a /usr/local/bin (permiso denegado).${RESET}"
        echo -e "${YELLOW}   Probando con apt...${RESET}"
        if command -v apt-get >/dev/null 2>&1; then
            apt-get update -qq 2>/dev/null
            DEBIAN_FRONTEND=noninteractive apt-get install -y speedtest-cli >/dev/null 2>&1 \
                && echo -e "${GREEN}✅ speedtest-cli instalado vía apt.${RESET}" \
                || echo -e "${RED}❌ apt falló. Ejecuta como root.${RESET}"
        fi
    fi

    rm -rf "$TMP_DIR"
    echo
    read -n1 -r -p "$(trx 'Presione una tecla para continuar...')"
}

while true; do

clear

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${MAGENTA}              🚀 SPEEDTEST${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo
echo -e " $(trx 'Sistema:') ${WHITE}$(uname -m)${RESET}"
if command -v speedtest >/dev/null 2>&1; then
    echo -e " $(trx 'Estado:')  ${GREEN}✅ Speedtest oficial instalado${RESET}"
else
    echo -e " $(trx 'Estado:')  ${RED}❌ No instalado${RESET}"
fi
echo
echo "$(trx ' [1] ➮ Ejecutar Speedtest')"
echo "$(trx ' [2] ➮ Instalar / Actualizar Speedtest')"
echo -e " ${YELLOW}$(trx ' [3] ➮ Desinstalar')${RESET}"
echo
echo "$(trx ' [0] ➮ Regresar')"
echo

read -rp "$(trx ' ► Opción: ')" OP

case "$OP" in

1)
    if command -v speedtest >/dev/null 2>&1; then
        speedtest
    else
        echo
        echo -e "${RED}❌ Speedtest oficial no está instalado.${RESET}"
        echo
        echo -e "${YELLOW}$(trx ' ▶ Selecciona [2] para instalarlo automáticamente.')${RESET}"
    fi

    echo
    read -n1 -r -p "$(trx 'Presione una tecla para continuar...')"
;;

2)
    instalar_speedtest
;;

3)
    if command -v speedtest >/dev/null 2>&1; then
        read -rp "$(trx ' ¿Desinstalar speedtest? [s/N]: ')" CONFIRM
        case "$CONFIRM" in
        s|S|y|Y)
            rm -f /usr/local/bin/speedtest /usr/bin/speedtest /usr/bin/speedtest-cli 2>/dev/null
            echo -e "${GREEN}✅ Speedtest desinstalado.${RESET}"
        ;;
        *)
            echo -e "${YELLOW}Cancelado.${RESET}"
        ;;
        esac
    else
        echo -e "${YELLOW}ℹ️  Speedtest no está instalado.${RESET}"
    fi
    echo
    read -n1 -r -p "$(trx 'Presione una tecla para continuar...')"
;;

0)
    exec bash "$BASE/herramientas/menu.sh"
;;

*)
    echo "$(trx '❌ Opción inválida.')"
    sleep 2
;;

esac

done