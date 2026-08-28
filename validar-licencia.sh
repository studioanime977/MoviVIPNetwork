#!/bin/bash
# =============================================================
#  MOVIVIP NETWORK — GATE DE LICENCIA (validar-licencia.sh)
#  -------------------------------------------------------------
#  Gate interactivo: pide la key al usuario, la valida contra
#  Firebase EN VIVO, y si es válida la guarda en licencia.conf.
#
#  USO:
#    bash /etc/movivip/validar-licencia.sh
#    bash /etc/movivip/validar-licencia.sh --check   (solo verificar)
#
#  SALIDA:
#    0 = key válida y guardada
#    1 = key inválida / error
# =============================================================

BASE="/etc/movivip"
LICENCIA_FILE="$BASE/licencia.conf"
FB_BASE="movivip-network-default-rtdb.firebaseio.com"

RED='\033[0;31m'; GREEN='\033[0;32m'; GOLD='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

# ================= HELPERS =================
key_formato_valido() {
    [[ "$1" =~ ^KEY-[0-9A-F]{10}$ ]]
}

json_get() {
    local json="$1" campo="$2"
    echo "$json" | grep -o "\"${campo}\"[[:space:]]*:[[:space:]]*[^,}]*" | head -n1 | sed "s/\"${campo}\"[[:space:]]*:[[:space:]]*//" | tr -d '"' | tr -d ' '
}

mostrar_contacto() {
    echo ""
    echo -e "${RED}──────────────────────────────────────────────────────${NC}"
    echo -e "${RED}  ⛔ LICENCIA NO VÁLIDA${NC}"
    echo -e "${RED}──────────────────────────────────────────────────────${NC}"
    echo -e "  💬 Telegram : ${GREEN}@MoviVIP${NC}"
    echo -e "  📱 WhatsApp : ${GREEN}+57 311 700 8185${NC}"
    echo -e "  🌐 Web      : ${GREEN}https://movivip-network.web.app${NC}"
    echo ""
}

# ================= MAIN =================
main() {
    local MODE="interactive"
    local KEY_TO_CHECK=""

    # Modo --check: solo verificar la key en LICENCIA_KEY o licencia.conf
    if [[ "$1" == "--check" ]]; then
        MODE="check"
        if [[ -n "$LICENCIA_KEY" ]]; then
            KEY_TO_CHECK="$LICENCIA_KEY"
        elif [[ -f "$LICENCIA_FILE" ]]; then
            source "$LICENCIA_FILE" 2>/dev/null
            KEY_TO_CHECK="${KEY:-}"
        fi
        if [[ -z "$KEY_TO_CHECK" ]]; then
            echo -e "${RED}No hay key para verificar.${NC}"
            exit 1
        fi
    fi

    # Modo interactivo: pedir la key
    if [[ "$MODE" == "interactive" ]]; then
        clear
        echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${GOLD}          🔑 GATE DE LICENCIA${NC}${CYAN}                  ║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${CYAN}Ingresa tu clave de licencia (formato KEY-XXXXXXXXXX):${NC}"
        echo ""
        read -rp "  > " KEY_TO_CHECK
        KEY_TO_CHECK=$(echo "$KEY_TO_CHECK" | tr -d ' ' | tr 'a-f' 'A-F')
    fi

    # Validar formato
    if ! key_formato_valido "$KEY_TO_CHECK"; then
        echo -e "${RED}❌ Formato inválido. Debe ser: KEY-XXXXXXXXXX (10 caracteres hex).${NC}"
        exit 1
    fi

    # Consultar Firebase EN VIVO
    echo -e "${CYAN}→ Consultando servidor de licencias...${NC}"
    local resp
    resp=$(curl -s --max-time 12 "https://${FB_BASE}/licencias_movivip/${KEY_TO_CHECK}.json" 2>/dev/null)
    local exit_code=$?

    if [[ $exit_code -ne 0 || -z "$resp" ]]; then
        echo -e "${RED}❌ No se pudo conectar al servidor de licencias.${NC}"
        exit 2
    fi

    if [[ "$resp" == "null" ]]; then
        echo -e "${RED}❌ La clave '$KEY_TO_CHECK' no existe en el sistema.${NC}"
        mostrar_contacto
        exit 1
    fi

    # Verificar campos
    local activa expira
    activa=$(json_get "$resp" "activa")
    expira=$(json_get "$resp" "expira")

    if [[ "$activa" != "true" ]]; then
        echo -e "${RED}❌ LICENCIA DESACTIVADA (revocada por el proveedor).${NC}"
        mostrar_contacto
        exit 1
    fi

    local now
    now=$(date +%s)
    if [[ -n "$expira" && "$expira" =~ ^[0-9]+$ && "$expira" -gt 0 && "$now" -gt "$expira" ]]; then
        echo -e "${RED}❌ LICENCIA EXPIRADA. Renueva para seguir usando.${NC}"
        mostrar_contacto
        exit 1
    fi

    # ✅ VÁLIDA — guardar localmente
    local cliente plan
    cliente=$(json_get "$resp" "cliente")
    plan=$(json_get "$resp" "plan")
    [[ -z "$cliente" ]] && cliente="desconocido"
    [[ -z "$plan" ]] && plan="standard"

    mkdir -p "$BASE"
    cat > "$LICENCIA_FILE" <<EOF
# Movivip Network — Licencia (auto-generado por gate)
KEY="$KEY_TO_CHECK"
CLIENTE="$cliente"
PLAN="$plan"
FECHA="$(date -Iseconds)"
EOF
    chmod 644 "$LICENCIA_FILE"

    echo -e "${GREEN}✔ Licencia válida — guardada en $LICENCIA_FILE${NC}"
    exit 0
}

main "$@"
