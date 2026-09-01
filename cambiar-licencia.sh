#!/bin/bash
# =============================================================
#  MOVIVIP NETWORK — CAMBIAR LICENCIA
#  -------------------------------------------------------------
#  Quita la licencia actual y registra una nueva.
#
#  SEGURIDAD (diseño):
#   - La NUEVA key se valida contra Firebase ANTES de tocar nada.
#     Si es inválida → NO se modifica la licencia actual.
#   - La licencia actual se respalda en licencia.conf.bak-<fecha>.
#   - Después del cambio, el VPS opera con la nueva key.
#
#  USO:
#    bash /etc/movivip/cambiar-licencia.sh
# =============================================================

BASE="/etc/movivip"
LICENCIA_FILE="$BASE/licencia.conf"
GATE="$BASE/validar-licencia.sh"

RESET="\e[0m"; RED="\e[1;91m"; GREEN="\e[1;92m"; GOLD="\e[1;93m"; CYAN="\e[1;96m"; WHITE="\e[1;97m"; GRAY="\e[1;90m"

# ── Cargar idioma + trx + diseño (imprescindible para trx / movivip_sub_header) ──
if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)"
fi
source "$BASE/lib/nav.sh" 2>/dev/null || true

clear
movivip_sub_header "$(trx '🔑 CAMBIAR LICENCIA')"
echo ""

# ---------- 1. Mostrar licencia actual ----------
echo -e "${WHITE}Licencia actual:${RESET}"
if [[ -f "$LICENCIA_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$LICENCIA_FILE" 2>/dev/null
    local_key="${KEY:-}"
    if [[ -n "$local_key" ]]; then
        echo -e "  ${GOLD}Key:${RESET} ${local_key:0:8}****  ${GRAY}(plan: ${PLAN:-standard} · cliente: ${CLIENTE:-?})${RESET}"
    else
        echo -e "  ${GRAY}No hay clave guardada.${RESET}"
    fi
else
    echo -e "  ${GRAY}No hay archivo de licencia.${RESET}"
fi
echo ""

# ---------- 2. Confirmar ----------
echo -e "${RED}⚠️  Al cambiar la licencia, este VPS pasará a usar la NUEVA key.${RESET}"
read -rp "$(echo -e "${CYAN}¿Seguro que deseas CAMBIAR la licencia? [s/N] ➤ ${RESET}")" CONF
case "${CONF,,}" in
    s|si|sí|y|yes) ;;
    *) echo -e "${GOLD}⏭ Cancelado. La licencia actual no se modificó.${RESET}"
       sleep 2
       exit 0 ;;
esac

# ---------- 3. Pedir la nueva key ----------
echo ""
read -rp "$(echo -e "${CYAN}Ingresa la NUEVA clave (formato KEY-XXXXXXXXXX): ${RESET}")" NUEVA_KEY
NUEVA_KEY=$(echo "$NUEVA_KEY" | tr -d ' ' | tr 'a-f' 'A-F')

# ---------- 4. Validar formato ----------
if [[ ! "$NUEVA_KEY" =~ ^KEY-[0-9A-F]{10}$ ]]; then
    echo -e "${RED}❌ Formato inválido. Debe ser: KEY-XXXXXXXXXX (10 caracteres hex).${RESET}"
    echo -e "${GRAY}   Ejemplo: KEY-3F8A21C9D4${RESET}"
    read -n1 -r -p "$(trx '  Presiona ENTER para volver...')"
    exit 1
fi

# ---------- 5. Validar contra Firebase (sin tocar nada aún) ----------
echo ""
echo -e "${CYAN}→ Consultando servidor de licencias...${RESET}"
if [[ -x "$GATE" ]]; then
    if LICENCIA_KEY="$NUEVA_KEY" "$GATE" --check >/dev/null 2>&1; then
        echo -e "${GREEN}✔ La nueva clave es VÁLIDA y está activa.${RESET}"
    else
        echo -e "${RED}❌ La clave '$NUEVA_KEY' NO es válida o no está activa.${RESET}"
        echo -e "${GRAY}   No se modificó la licencia actual.${RESET}"
        read -n1 -r -p "$(trx '  Presiona ENTER para volver...')"
        exit 1
    fi
else
    echo -e "${RED}❌ No se encontró el validador de licencia ($GATE).${RESET}"
    read -n1 -r -p "$(trx '  Presiona ENTER para volver...')"
    exit 1
fi

# ---------- 6. Respaldar la licencia actual ----------
if [[ -f "$LICENCIA_FILE" ]]; then
    cp "$LICENCIA_FILE" "${LICENCIA_FILE}.bak-$(date +%Y%m%d-%H%M%S)" 2>/dev/null
    echo -e "${GREEN}✔ Licencia anterior respaldada.${RESET}"
fi

# ---------- 7. Registrar la nueva (gate guarda licencia.conf) ----------
echo ""
echo -e "${CYAN}→ Guardando la nueva licencia...${RESET}"
LICENCIA_KEY="$NUEVA_KEY" bash "$GATE"
if [[ $? -ne 0 ]]; then
    echo -e "${RED}❌ No se pudo guardar la nueva licencia.${RESET}"
    read -n1 -r -p "$(trx '  Presiona ENTER para volver...')"
    exit 1
fi

# ---------- 8. Verificación final ----------
echo ""
if bash "$BASE/check-licencia.sh" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ ¡Licencia cambiada correctamente! El VPS opera con la nueva key.${RESET}"
else
    echo -e "${RED}⚠️  La licencia quedó guardada pero el validador reporta problemas.${RESET}"
    echo -e "${GRAY}   Revisa la key e intenta de nuevo.${RESET}"
fi
echo ""
read -n1 -r -p "$(trx '  Presiona ENTER para volver al menú...')"
exec bash "$BASE/menu.sh"
