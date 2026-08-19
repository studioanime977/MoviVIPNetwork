#!/bin/bash
# =============================================================
#  MOVIVIP NETWORK â€” CAMBIAR LICENCIA
#  -------------------------------------------------------------
#  Quita la licencia actual y registra una nueva.
#
#  SEGURIDAD (diseÃ±o):
#   - La NUEVA key se valida contra Firebase ANTES de tocar nada.
#     Si es invÃ¡lida â†’ NO se modifica la licencia actual.
#   - La licencia actual se respalda en licencia.conf.bak-<fecha>.
#   - DespuÃ©s del cambio, el VPS opera con la nueva key.
#
#  USO:
#    bash /etc/movivip/cambiar-licencia.sh
# =============================================================

BASE="/etc/movivip"
LICENCIA_FILE="$BASE/licencia.conf"
GATE="$BASE/validar-licencia.sh"

RESET="\e[0m"; RED="\e[1;91m"; GREEN="\e[1;92m"; GOLD="\e[1;93m"; CYAN="\e[1;96m"; WHITE="\e[1;97m"

clear
echo -e "${CYAN}â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—${RESET}"
echo -e "${CYAN}â•‘${GOLD}          ðŸ”‘ CAMBIAR LICENCIA${RESET}${CYAN}                    â•‘${RESET}"
echo -e "${CYAN}â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${RESET}"
echo ""

# ---------- 1. Mostrar licencia actual ----------
echo -e "${WHITE}Licencia actual:${RESET}"
if [[ -f "$LICENCIA_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$LICENCIA_FILE" 2>/dev/null
    local_key="${KEY:-}"
    if [[ -n "$local_key" ]]; then
        echo -e "  ${GOLD}Key:${RESET} ${local_key:0:8}****  ${GRAY}(plan: ${PLAN:-standard} Â· cliente: ${CLIENTE:-?})${RESET}"
    else
        echo -e "  ${GRAY}No hay clave guardada.${RESET}"
    fi
else
    echo -e "  ${GRAY}No hay archivo de licencia.${RESET}"
fi
echo ""

# ---------- 2. Confirmar ----------
echo -e "${RED}âš ï¸  Al cambiar la licencia, este VPS pasarÃ¡ a usar la NUEVA key.${RESET}"
read -rp "$(echo -e "${CYAN}Â¿Seguro que deseas CAMBIAR la licencia? [s/N] âž¤ ${RESET}")" CONF
case "${CONF,,}" in
    s|si|sÃ­|y|yes) ;;
    *) echo -e "${GOLD}â­ Cancelado. La licencia actual no se modificÃ³.${RESET}"
       sleep 2
       exit 0 ;;
esac

# ---------- 3. Pedir la nueva key ----------
echo ""
read -rp "$(echo -e "${CYAN}Ingresa la NUEVA clave (formato KEY-XXXXXXXXXX): ${RESET}")" NUEVA_KEY
NUEVA_KEY=$(echo "$NUEVA_KEY" | tr -d ' ' | tr 'a-f' 'A-F')

# ---------- 4. Validar formato ----------
if [[ ! "$NUEVA_KEY" =~ ^KEY-[0-9A-F]{10}$ ]]; then
    echo -e "${RED}âŒ Formato invÃ¡lido. Debe ser: KEY-XXXXXXXXXX (10 caracteres hex).${RESET}"
    echo -e "${GRAY}   Ejemplo: KEY-3F8A21C9D4${RESET}"
    read -n1 -r -p "  Presiona ENTER para volver..."
    exit 1
fi

# ---------- 5. Validar contra Firebase (sin tocar nada aÃºn) ----------
echo ""
echo -e "${CYAN}â†’ Consultando servidor de licencias...${RESET}"
if [[ -x "$GATE" ]]; then
    if LICENCIA_KEY="$NUEVA_KEY" "$GATE" --check >/dev/null 2>&1; then
        echo -e "${GREEN}âœ” La nueva clave es VÃLIDA y estÃ¡ activa.${RESET}"
    else
        echo -e "${RED}âŒ La clave '$NUEVA_KEY' NO es vÃ¡lida o no estÃ¡ activa.${RESET}"
        echo -e "${GRAY}   No se modificÃ³ la licencia actual.${RESET}"
        read -n1 -r -p "  Presiona ENTER para volver..."
        exit 1
    fi
else
    echo -e "${RED}âŒ No se encontrÃ³ el validador de licencia ($GATE).${RESET}"
    read -n1 -r -p "  Presiona ENTER para volver..."
    exit 1
fi

# ---------- 6. Respaldar la licencia actual ----------
if [[ -f "$LICENCIA_FILE" ]]; then
    cp "$LICENCIA_FILE" "${LICENCIA_FILE}.bak-$(date +%Y%m%d-%H%M%S)" 2>/dev/null
    echo -e "${GREEN}âœ” Licencia anterior respaldada.${RESET}"
fi

# ---------- 7. Registrar la nueva (gate guarda licencia.conf) ----------
echo ""
echo -e "${CYAN}â†’ Guardando la nueva licencia...${RESET}"
LICENCIA_KEY="$NUEVA_KEY" bash "$GATE"
if [[ $? -ne 0 ]]; then
    echo -e "${RED}âŒ No se pudo guardar la nueva licencia.${RESET}"
    read -n1 -r -p "  Presiona ENTER para volver..."
    exit 1
fi

# ---------- 8. VerificaciÃ³n final ----------
echo ""
if bash "$BASE/check-licencia.sh" >/dev/null 2>&1; then
    echo -e "${GREEN}âœ… Â¡Licencia cambiada correctamente! El VPS opera con la nueva key.${RESET}"
else
    echo -e "${RED}âš ï¸  La licencia quedÃ³ guardada pero el validador reporta problemas.${RESET}"
    echo -e "${GRAY}   Revisa la key e intenta de nuevo.${RESET}"
fi
echo ""
read -n1 -r -p "  Presiona ENTER para volver al menÃº..."
exec bash "$BASE/menu.sh"
