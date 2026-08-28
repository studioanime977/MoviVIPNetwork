#!/bin/bash
# =============================================================
#  MOVIVIP NETWORK — CHECK LICENCIA EN VIVO (por protocolo)
#  -------------------------------------------------------------
#  Este módulo valida la licencia contra Firebase RTDB EN VIVO.
#  Lo llaman TODOS los protocolos y el bot al inicio:
#
#      bash /etc/movivip/check-licencia.sh || exit 1
#
#  CÓDIGOS DE SALIDA:
#    0  = licencia VÁLIDA (activa + no vencida) → se permite operar
#    1  = licencia NO VÁLIDA / vencida / sin key → se BLOQUEA
#    2  = error de red (no se pudo consultar) → se BLOQUEA
#          (fail-closed: sin confirmación de Firebase NO se opera)
#
#  De dónde saca la key:
#    1. /etc/movivip/licencia.conf  (guardada por el gate al instalar)
#    2. Si no existe → intenta ejecutar el gate interactivo
#       (/etc/movivip/validar-licencia.sh) para que el cliente la pida
#
#  REGLA DE NEGOCIO:
#    - La validación es SIEMPRE EN LÍNEA contra Firebase (nunca local)
#    - El archivo local SOLO guarda CUÁL key es; la decisión de si está
#      activa/vencida la toma Firebase en el momento de cada consulta
#    - Sin key guardada         -> pide la key (gate interactivo)
#    - Key vencida / revocada   -> BLOQUEA protocolo + muestra contacto
#    - expira=0 o vacía         -> VITALICIA (de por vida, nunca vence)
#    - Sin internet             -> BLOQUEA (fail-closed, anti-piratería)
# =============================================================

# ================= CONFIGURACIÓN =================
FB_BASE="movivip-network-default-rtdb.firebaseio.com"
FB_LICENCIAS="licencias_movivip"
BASE_DIR="/etc/movivip"
LICENCIA_FILE="$BASE_DIR/licencia.conf"
GATE_LOCAL="$BASE_DIR/validar-licencia.sh"
GATE_LOCAL_LEGACY="$BASE_DIR/gate/validar-licencia.sh"
GATE_URL="https://raw.githubusercontent.com/studioanime977/vps-license-gate/main/gate/validar-licencia.sh"

# ================= COLORES =================
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

# ================= CONTACTO (venta) =================
mostrar_contacto() {
    echo -e "${RED}──────────────────────────────────────────────────────${NC}"
    echo -e "${RED}  ⛔ ACCESO BLOQUEADO — LICENCIA NO VÁLIDA${NC}"
    echo -e "${RED}──────────────────────────────────────────────────────${NC}"
    echo -e "${YELLOW}  Este protocolo requiere una clave de licencia activa.${NC}"
    echo ""
    echo -e "${CYAN}  🔑 Adquiere o renueva tu licencia aquí:${NC}"
    echo -e "${CYAN}  ─────────────────────────────────────────────${NC}"
    echo -e "  💬 Telegram : ${GREEN}@MoviVIP${NC}"
    echo -e "  📱 WhatsApp : ${GREEN}+57 311 700 8185${NC}"
    echo -e "  🌐 Web      : ${GREEN}https://movivip-network.web.app${NC}"
    echo -e "  📢 Canal    : ${GREEN}https://t.me/MoviVIPNetwork${NC}"
    echo -e "  👥 Grupo    : ${GREEN}https://t.me/MoviVIPNet${NC}"
    echo -e "${CYAN}  ─────────────────────────────────────────────${NC}"
    echo ""
}

# ================= HELPERS =================
# Validar formato de key: KEY-XXXXXXXXXX (10 hex)
key_formato_valido() {
    [[ "$1" =~ ^KEY-[0-9A-F]{10}$ ]]
}

# Extraer campo del JSON (sin jq - compatible)
json_get() {
    local json="$1" campo="$2"
    echo "$json" | grep -o "\"${campo}\"[[:space:]]*:[[:space:]]*[^,}]*" | head -n1 | sed "s/\"${campo}\"[[:space:]]*:[[:space:]]*//" | tr -d '"' | tr -d ' '
}

# Consultar la key en Firebase (EN VIVO)
# 0 = key existe | 1 = no existe | 2 = error de red
firebase_consulta() {
    local key="$1"
    local url="https://${FB_BASE}/${FB_LICENCIAS}/${key}.json"
    local resp
    resp=$(curl -s --max-time 12 "$url" 2>/dev/null)
    if [[ $? -ne 0 || -z "$resp" ]]; then
        return 2
    fi
    if [[ "$resp" == "null" ]]; then
        return 1
    fi
    echo "$resp"
    return 0
}

# ================= MAIN =================
main() {
    local KEY=""

    # 1) Leer key guardada localmente
    if [[ -f "$LICENCIA_FILE" ]]; then
        # shellcheck disable=SC1090
        source "$LICENCIA_FILE" 2>/dev/null
        KEY="${KEY:-}"
    fi

    # 2) Si no hay key → intentar gate interactivo (pedir la key)
    if [[ -z "$KEY" ]]; then
        echo -e "${YELLOW}[!] No hay licencia guardada en este servidor.${NC}"
        # Intentar con el gate local (instalado por install.sh)
        if [[ -x "$GATE_LOCAL" ]]; then
            bash "$GATE_LOCAL" || exit 1
            # Releer la key recién guardada
            [[ -f "$LICENCIA_FILE" ]] && source "$LICENCIA_FILE" 2>/dev/null
            KEY="${KEY:-}"
        elif [[ -x "$GATE_LOCAL_LEGACY" ]]; then
            bash "$GATE_LOCAL_LEGACY" || exit 1
            # Releer la key recién guardada
            [[ -f "$LICENCIA_FILE" ]] && source "$LICENCIA_FILE" 2>/dev/null
            KEY="${KEY:-}"
        else
            # Descargar el gate en caliente como último recurso
            local tmp
            tmp=$(mktemp)
            if curl -fsSL --max-time 15 "$GATE_URL" -o "$tmp" 2>/dev/null; then
                chmod +x "$tmp"
                bash "$tmp" || { rm -f "$tmp"; exit 1; }
                rm -f "$tmp"
                [[ -f "$LICENCIA_FILE" ]] && source "$LICENCIA_FILE" 2>/dev/null
                KEY="${KEY:-}"
            else
                mostrar_contacto
                echo -e "${RED}[✘] No se pudo cargar el módulo de licencia.${NC}"
                exit 1
            fi
        fi
        # Si sigue sin key → bloqueado
        if [[ -z "$KEY" ]]; then
            mostrar_contacto
            echo -e "${RED}[✘] No se pudo registrar una clave de licencia.${NC}"
            exit 1
        fi
    fi

    # 3) Validar formato
    if ! key_formato_valido "$KEY"; then
        mostrar_contacto
        echo -e "${RED}[✘] Clave inválida guardada en $LICENCIA_FILE${NC}"
        exit 1
    fi

    # 4) Consultar Firebase EN VIVO
    local resp code
    resp=$(firebase_consulta "$KEY")
    code=$?

    if [[ $code -eq 2 ]]; then
        # fail-closed: sin internet NO se opera
        mostrar_contacto
        echo -e "${RED}[✘] No se pudo conectar al servidor de licencias.${NC}"
        echo -e "${YELLOW}[!] Verifica la conexión a internet y reintenta.${NC}"
        exit 2
    fi

    if [[ $code -eq 1 ]]; then
        mostrar_contacto
        echo -e "${RED}[✘] La clave '$KEY' no existe en el sistema.${NC}"
        exit 1
    fi

    # 5) Analizar respuesta
    local activa expira now
    activa=$(json_get "$resp" "activa")
    expira=$(json_get "$resp" "expira")

    if [[ "$activa" != "true" ]]; then
        mostrar_contacto
        echo -e "${RED}[✘] LICENCIA DESACTIVADA (revocada por el proveedor).${NC}"
        exit 1
    fi

    now=$(date +%s)
    # expira=0 o vacío => VITALICIA. Solo vence si expira > 0 y ya pasó
    if [[ -n "$expira" && "$expira" =~ ^[0-9]+$ && "$expira" -gt 0 && "$now" -gt "$expira" ]]; then
        mostrar_contacto
        echo -e "${RED}[✘] LICENCIA EXPIRADA. Renueva para seguir usando los protocolos.${NC}"
        exit 1
    fi

    # 6) VÁLIDA
    exit 0
}

main "$@"
exit $?
