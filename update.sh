#!/bin/bash
# =============================================================================
#  MoviVIP Network — ACTUALIZADOR (controlado por licencia)
#  ---------------------------------------------------------------------------
#  POLÍTICA DE LICENCIA (confirmada):
#   ✅ NINGÚN plan se desactiva por no pagar la licencia.
#      El panel / los protocolos SIGUEN funcionando normal SIEMPRE.
#   🔄 Solo las ACTUALIZACIONES requieren licencia activa.
#   📢 Si hay actualización disponible y el plan NO está activo:
#      se le NOTIFICA, pero NO se descarga. Renueva para actualizar.
#   ✅ Si el plan está activo: se le notifica y ÉL decide si actualizar o no.
# =============================================================================

BASE="/etc/movivip"
LICENCIA="$BASE/licencia.conf"
VERSION_FILE="$BASE/version.txt"
GIT_REPO="https://github.com/studioanime977/MoviVIPNetwork.git"
RAW_VER="https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/version.txt"
GATE="$BASE/gate/validar-licencia.sh"

RESET="\e[0m"; RED="\e[1;91m"; GREEN="\e[1;92m"; GOLD="\e[1;93m"; CYAN="\e[1;96m"; WHITE="\e[1;97m"; GRAY="\e[1;90m"

# Versión local instalada
ver_local() {
    if [[ -f "$VERSION_FILE" ]]; then
        tr -d ' \n' < "$VERSION_FILE"
    else
        echo "0.0.0"
    fi
}

# Versión disponible en el repo remoto (vacío = sin conexión/repo sin version.txt)
# ⚠️ Usa la API de GitHub (sin caché CDN) y fallback a raw/jsDelivr
ver_remota() {
    local V TMP="/tmp/MoviVIP_ver"
    # Prioridad 1: API de GitHub - SIEMPRE fresca, sin cache CDN
    V=$(curl -fsSL --max-time 8 "https://api.github.com/repos/studioanime977/MoviVIPNetwork/contents/version.txt" 2>/dev/null \
        | grep -o '"content":"[^"]*"' | head -1 | cut -d'"' -f4 | base64 -d 2>/dev/null | tr -d ' \n')
    [[ -n "$V" ]] && { echo "$V"; return 0; }
    # Prioridad 2: git shallow clone - fresco garantizado (sin CDN, sin rate limit de API)
    rm -rf "$TMP"
    if git clone --depth 1 --filter=blob:none --sparse "https://github.com/studioanime977/MoviVIPNetwork.git" "$TMP" >/dev/null 2>&1; then
        git -C "$TMP" sparse-checkout set version.txt >/dev/null 2>&1
        V=$(tr -d ' \n' < "$TMP/version.txt" 2>/dev/null)
        rm -rf "$TMP"
        [[ -n "$V" ]] && { echo "$V"; return 0; }
    fi
    rm -rf "$TMP"
    # Prioridad 3: raw.githubusercontent (cache CDN, puede tardar en propagar)
    V=$(curl -fsSL --max-time 8 "$RAW_VER" 2>/dev/null | tr -d ' \n')
    [[ -n "$V" ]] && { echo "$V"; return 0; }
    # Prioridad 4: jsDelivr CDN
    V=$(curl -fsSL --max-time 8 "https://cdn.jsdelivr.net/gh/studioanime977/MoviVIPNetwork@main/version.txt" 2>/dev/null | tr -d ' \n')
    echo "$V"
}

# Comparar versiones semver (devuelve 0 si la remota es MAYOR que la local)
hay_actualizacion() {
    local l r
    l=$(ver_local); r=$(ver_remota)
    [[ -z "$r" ]] && return 1
    # Descomponer x.y.z
    local l1 l2 l3 r1 r2 r3
    IFS='.' read -r l1 l2 l3 <<< "$l"
    IFS='.' read -r r1 r2 r3 <<< "$r"
    l1=${l1:-0}; l2=${l2:-0}; l3=${l3:-0}
    r1=${r1:-0}; r2=${r2:-0}; r3=${r3:-0}
    if (( r1 > l1 )); then return 0; fi
    if (( r1 == l1 && r2 > l2 )); then return 0; fi
    if (( r1 == l1 && r2 == l2 && r3 > l3 )); then return 0; fi
    return 1
}

# Licencia ACTIVA = existe key + activa en Firebase (o caché local no vencida)
# devuelve 0 activa | 1 no activa | 2 sin licencia instalada
licencia_activa() {
    if [[ ! -f "$LICENCIA" ]]; then
        return 2
    fi
    source "$LICENCIA" 2>/dev/null
    local KEY="${KEY:-}"
    [[ -z "$KEY" ]] && return 2

    if [[ -x "$GATE" ]]; then
        LICENCIA_KEY="$KEY" "$GATE" --check >/dev/null 2>&1
        local g=$?
        if [[ $g -eq 0 ]]; then
            return 0
        fi
        if [[ $g -eq 2 ]]; then
            # Sin conexión al servidor de licencias: usar caché local
            if [[ "${LICENCIA_ACTIVA:-false}" == "true" ]]; then
                local exp="${EXPIRA:-0}"
                if [[ "$exp" =~ ^[0-9]+$ && "$exp" -gt 0 ]]; then
                    [[ "$(date +%s)" -le "$exp" ]] && return 0 || return 1
                fi
                return 0
            fi
        fi
        return 1
    fi

    # Fallback sin gate: usar caché local
    if [[ "${LICENCIA_ACTIVA:-false}" == "true" ]]; then
        local exp="${EXPIRA:-0}"
        if [[ "$exp" =~ ^[0-9]+$ && "$exp" -gt 0 ]]; then
            [[ "$(date +%s)" -le "$exp" ]] && return 0 || return 1
        fi
        return 0
    fi
    return 1
}

# =============================================================================
# APLICAR LA ACTUALIZACIÓN
# =============================================================================
aplicar_update() {
    local TMP="/tmp/MoviVIP_update"
    rm -rf "$TMP"
    echo -e "${CYAN}  📥 Descargando actualización...${RESET}"
    git clone --depth 1 "$GIT_REPO" "$TMP" >/dev/null 2>&1 || {
        echo -e "${RED}  ❌ Error al descargar la actualización.${RESET}"
        echo -e "${GRAY}  (verifica conexión y que el repo sea accesible)${RESET}"
        return 1
    }
    cp -rf "$TMP"/. /etc/movivip/
    chmod -R +x /etc/movivip
    rm -rf "$TMP"
    echo -e "${GREEN}  ✅ Actualización completada.${RESET}"
    return 0
}

# =============================================================================
# MAIN
# =============================================================================
echo ""
echo -e "${GOLD}  ────────────────────────────────────────────────${RESET}"
echo -e "${WHITE}   📥 MOVIVIP NETWORK — ACTUALIZADOR${RESET}"
echo -e "${GOLD}  ────────────────────────────────────────────────${RESET}"
echo ""

LV=$(ver_local)
RV=$(ver_remota)

# Estado de la licencia
LIC_STATE=$(licencia_activa; echo $?)
PLAN_LOCAL=""
[[ -f "$LICENCIA" ]] && source "$LICENCIA" && PLAN_LOCAL="${PLAN:-}"

if [[ -z "$RV" ]]; then
    echo -e "${GRAY}  (no se pudo consultar el servidor de actualizaciones)${RESET}"
    echo -e "  Versión local: ${WHITE}v$LV${RESET}"
    echo -e "  ${GRAY}Reintenta más tarde. El panel sigue funcionando normal.${RESET}"
elif ! hay_actualizacion; then
    echo -e "  Versión local : ${WHITE}v$LV${RESET}"
    echo -e "  Versión actual: ${WHITE}v$RV${RESET}"
    echo -e "  ${GREEN}  ✅ Ya tienes la última versión instalada.${RESET}"
else
    echo -e "  Versión local : ${WHITE}v$LV${RESET}"
    echo -e "  Disponible    : ${GOLD}v$RV${RESET}"
    echo ""
    # ============ HAY ACTUALIZACIÓN DISPONIBLE ============
    if [[ "$LIC_STATE" -eq 0 ]]; then
        echo -e "  ${GREEN}  🔑 Tu licencia está ACTIVA (plan: ${PLAN_LOCAL:-premium}).${RESET}"
        echo -e "  ${WHITE}  Puedes actualizar cuando quieras.${RESET}"
        echo ""
        read -rp "$(echo -e "${CYAN}  ¿Deseas actualizar ahora? [s/N] ➤ ${RESET}")" CONFIRMA
        case "${CONFIRMA,,}" in
            s|si|sí|y|yes)
                aplicar_update
                echo ""
                read -n1 -r -p "  Presiona ENTER para continuar..."
                exec "$BASE/menu.sh"
            ;;
            *)
                echo -e "  ${GOLD}  ⏭ Omitido. Puedes actualizar luego desde el menú → [09] Update.${RESET}"
                echo -e "  ${GRAY}  El panel sigue funcionando normal.${RESET}"
                echo ""
                read -n1 -r -p "  Presiona ENTER para volver..."
                exec "$BASE/menu.sh"
            ;;
        esac
    else
        # ============ PLAN NO ACTIVO / SIN LICENCIA ============
        echo -e "  ${GOLD}  📢 HAY UNA ACTUALIZACIÓN DISPONIBLE (v$RV)${RESET}"
        echo ""
        if [[ "$LIC_STATE" -eq 2 ]]; then
            echo -e "  ${RED}  ⚠️  Tu servidor no tiene una licencia activa.${RESET}"
        else
            echo -e "  ${RED}  ⚠️  Tu plan (${PLAN_LOCAL:-standard}) no está activo.${RESET}"
        fi
        echo ""
        echo -e "  ✅ Tu panel y protocolos SIGUEN FUNCIONANDO NORMAL."
        echo -e "  🔄 Las actualizaciones requieren licencia activa."
        echo -e "  💡 Renueva tu licencia para recibir esta y futuras actualizaciones."
        echo ""
        echo -e "  ${CYAN}  🔑 Contáctanos para renovar:${RESET}"
        echo -e "  ───────────────────────────────────────────────"
        echo -e "  ${WHITE}  💬 Telegram : @MoviVIP${RESET}"
        echo -e "  ${WHITE}  📱 WhatsApp : +57 311 700 8185${RESET}"
        echo -e "  ${WHITE}  🌐 Web      : https://movivip-network.web.app${RESET}"
        echo -e "  ${WHITE}  📢 Canal    : https://t.me/MoviVIPNetwork${RESET}"
        echo -e "  ${WHITE}  👥 Grupo    : https://t.me/MoviVIPNet${RESET}"
        echo -e "  ───────────────────────────────────────────────"
        echo ""
        echo -e "  ${GRAY}  (No se descargó ni aplicó ningún cambio)${RESET}"
        echo ""
        read -n1 -r -p "  Presiona ENTER para volver..."
        exec "$BASE/menu.sh"
    fi
fi

