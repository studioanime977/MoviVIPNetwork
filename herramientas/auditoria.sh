#!/bin/bash

#=========================================================
#   MoviVIP Network - AUDITORÍA DE SEGURIDAD
#   rkhunter + chkrootkit + lynis
#   Genérico — sin datos personales
#=========================================================

# ── i18n shim (auto) ───────────────────────────────
if ! declare -F trx >/dev/null 2>&1; then trx() { printf '%s' "$1"; }; fi
# ─────────────────────────────────────────────────────────
BASE="/etc/movivip"
LOGDIR="$BASE/logs"

mkdir -p "$LOGDIR"

# Colores
CYAN="\e[1;96m"
GREEN="\e[1;92m"
YELLOW="\e[1;93m"
RED="\e[1;91m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"
RESET="\e[0m"

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ Necesita ejecutarse como root${RESET}"
    exit 1
fi

clear
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
echo -e "${WHITE}          🔍 AUDITORÍA DE SEGURIDAD DEL SERVIDOR${RESET}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
echo ""
echo -e "${GRAY} Herramientas: rkhunter + chkrootkit + lynis"
echo -e "${GRAY} Logs        : $LOGDIR${RESET}"
echo ""

#=========================================================
# Instalar herramientas si no están
#=========================================================

install_tools() {
    echo -e "${YELLOW}📦 Instalando herramientas de auditoría...${RESET}"
    apt update -y
    DEBIAN_FRONTEND=noninteractive apt install -y rkhunter chkrootkit lynis
}

if ! command -v rkhunter >/dev/null 2>&1 || ! command -v chkrootkit >/dev/null 2>&1 || ! command -v lynis >/dev/null 2>&1; then
    install_tools
fi

echo -e "${GREEN}✅ Herramientas listas${RESET}"
echo ""

#=========================================================
# 1) RKHUNTER
#=========================================================

echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
echo -e "${WHITE}  [1/3] 🔴 rkhunter — Buscando rootkits, binarios alterados...${RESET}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
echo ""

# Actualizar base de datos si hay internet (no bloqueante)
rkhunter --update >/dev/null 2>&1 &
UPDATE_PID=$!

# Propiedades de los binarios del sistema
rkhunter --propupd >/dev/null 2>&1

wait $UPDATE_PID 2>/dev/null

# Escaneo completo (no interactivo, log a archivo)
rkhunter --check --sk --rwo --report-warnings-only \
    --report-file "$LOGDIR/rkhunter-$(date +%Y%m%d).log" \
    >/dev/null 2>&1

# Resumen
if [[ -f "$LOGDIR/rkhunter-$(date +%Y%m%d).log" ]]; then
    WARN=$(grep -c "Warning" "$LOGDIR/rkhunter-$(date +%Y%m%d).log" 2>/dev/null)
    WARN=${WARN:-0}
    if [[ "$WARN" -eq 0 ]]; then
        echo -e "${GREEN}  ✅ rkhunter: sin advertencias críticas${RESET}"
    else
        echo -e "${YELLOW}  ⚠️ rkhunter: $WARN advertencias — revisa el log${RESET}"
    fi
else
    echo -e "${YELLOW}  ⚠️ rkhunter: no se generó reporte${RESET}"
fi
echo ""

#=========================================================
# 2) CHKROOTKIT
#=========================================================

echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
echo -e "${WHITE}  [2/3] 🟠 chkrootkit — Detectando rootkits conocidos...${RESET}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
echo ""

chkrootkit > "$LOGDIR/chkrootkit-$(date +%Y%m%d).log" 2>&1

INFECTED=$(grep -i "INFECTED" "$LOGDIR/chkrootkit-$(date +%Y%m%d).log" 2>/dev/null)
if [[ -z "$INFECTED" ]]; then
    echo -e "${GREEN}  ✅ chkrootkit: sistema limpio${RESET}"
else
    echo -e "${RED}  ❌ chkrootkit: $INFECTED${RESET}"
fi
echo ""

#=========================================================
# 3) LYNIS
#=========================================================

echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
echo -e "${WHITE}  [3/3] 🟡 lynis — Auditoría completa del sistema...${RESET}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
echo ""

# Lynis requiere respuesta interactiva en la primera ejecución; usamos --quiet
lynis audit system --quiet --logfile "$LOGDIR/lynis-$(date +%Y%m%d).log" >/dev/null 2>&1

if [[ -f "$LOGDIR/lynis-$(date +%Y%m%d).log" ]]; then
    HARDENING=$(grep -oP "Hardening index : \d+" "$LOGDIR/lynis-$(date +%Y%m%d).log" | awk '{print $4}')
    echo -e "  ${WHITE}Hardening index:${RESET} ${GREEN}${HARDENING:-?}${RESET}"
else
    echo -e "${YELLOW}  ⚠️ lynis: no se generó reporte${RESET}"
fi
echo ""

#=========================================================
# RESUMEN FINAL
#=========================================================

echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
echo -e "${WHITE}                 📋 RESUMEN DE AUDITORÍA${RESET}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
echo ""
echo -e "  ${GRAY}Fecha     :${WHITE} $(date '+%d/%m/%Y %H:%M:%S')"
echo -e "  ${GRAY}Hostname  :${WHITE} $(hostname)"
echo -e "  ${GRAY}Kernel    :${WHITE} $(uname -r)"
echo ""
echo -e "  ${GRAY}Logs guardados en:${WHITE} $LOGDIR"
echo ""
echo -e "  ${GREEN}✅ Auditoría completada${RESET}"
echo ""
read -rp "$(trx ' ↩ Presiona Enter para volver...')"
exec bash "$BASE/herramientas/menu.sh"
