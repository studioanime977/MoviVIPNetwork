#!/bin/bash
# =============================================================================
#  MoviVIP Network â€” ACTUALIZADOR (controlado por licencia)
#  ---------------------------------------------------------------------------
#  POLÃTICA DE LICENCIA (confirmada):
#   âœ… NINGÃšN plan se desactiva por no pagar la licencia.
#      El panel / los protocolos SIGUEN funcionando normal SIEMPRE.
#   ðŸ”„ Solo las ACTUALIZACIONES requieren licencia activa.
#   ðŸ“¢ Si hay actualizaciÃ³n disponible y el plan NO estÃ¡ activo:
#      se le NOTIFICA, pero NO se descarga. Renueva para actualizar.
#   âœ… Si el plan estÃ¡ activo: se le notifica y Ã‰L decide si actualizar o no.
# =============================================================================

BASE="/etc/movivip"
LICENCIA="$BASE/licencia.conf"
VERSION_FILE="$BASE/version.txt"
COMMIT_HASH_FILE="$BASE/.last_commit_hash"
GIT_REPO="https://github.com/studioanime977/MoviVIPNetwork.git"
RAW_VER="https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/version.txt"
GATE="$BASE/gate/validar-licencia.sh"

RESET="\e[0m"; RED="\e[1;91m"; GREEN="\e[1;92m"; GOLD="\e[1;93m"; CYAN="\e[1;96m"; WHITE="\e[1;97m"; GRAY="\e[1;90m"

# VersiÃ³n local instalada
ver_local() {
    if [[ -f "$VERSION_FILE" ]]; then
        tr -d ' \n' < "$VERSION_FILE"
    else
        echo "0.0.0"
    fi
}

# VersiÃ³n disponible en el repo remoto (vacÃ­o = sin conexiÃ³n/repo sin version.txt)
# âš ï¸ Usa la API de GitHub (sin cachÃ© CDN) y fallback a raw/jsDelivr
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

# =============================================================================
# DETECCIÃ“N POR COMMIT HASH (detecta cambios aunque version.txt no cambie)
# Usa la API de GitHub para obtener el Ãºltimo SHA del branch main.
# Guarda el Ãºltimo SHA conocido en .last_commit_hash
# =============================================================================

commit_remoto() {
    # Obtener Ãºltimo commit SHA del branch main via GitHub API
    local SHA
    SHA=$(curl -fsSL --max-time 8 "https://api.github.com/repos/studioanime977/MoviVIPNetwork/commits/main" 2>/dev/null \
        | grep -o '"sha":"[a-f0-9]*"' | head -1 | cut -d'"' -f4)
    echo "$SHA"
}

commit_local() {
    if [[ -f "$COMMIT_HASH_FILE" ]]; then
        cat "$COMMIT_HASH_FILE" 2>/dev/null
    else
        echo ""
    fi
}

# Devuelve 0 si hay cambios (commit remoto != commit local)
hay_cambios_commit() {
    local remote_sha local_sha
    remote_sha=$(commit_remoto)
    local_sha=$(commit_local)
    [[ -z "$remote_sha" ]] && return 1
    [[ "$remote_sha" != "$local_sha" ]] && return 0
    return 1
}

# Guardar el commit hash actual como conocido
guardar_commit_hash() {
    local sha
    sha=$(commit_remoto)
    [[ -n "$sha" ]] && echo "$sha" > "$COMMIT_HASH_FILE"
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
    # Mismo version pero diferente commit = hay cambios
    hay_cambios_commit && return 0
    return 1
}

# Licencia ACTIVA = existe key + activa en Firebase (o cachÃ© local no vencida)
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
            # Sin conexiÃ³n al servidor de licencias: usar cachÃ© local
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

    # Fallback sin gate: usar cachÃ© local
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
# APLICAR LA ACTUALIZACIÃ“N
# =============================================================================
aplicar_update() {
    local TMP="/tmp/MoviVIP_update"
    rm -rf "$TMP"
    echo -e "${CYAN}  ðŸ“¥ Descargando actualizaciÃ³n...${RESET}"
    git clone --depth 1 "$GIT_REPO" "$TMP" >/dev/null 2>&1 || {
        echo -e "${RED}  âŒ Error al descargar la actualizaciÃ³n.${RESET}"
        echo -e "${GRAY}  (verifica conexiÃ³n y que el repo sea accesible)${RESET}"
        return 1
    }
    cp -rf "$TMP"/. /etc/movivip/
    chmod -R +x /etc/movivip
    # Guardar commit hash despuÃ©s de actualizar
    local new_sha
    new_sha=$(cd "$TMP" && git rev-parse HEAD 2>/dev/null)
    [[ -n "$new_sha" ]] && echo "$new_sha" > "$COMMIT_HASH_FILE"
    rm -rf "$TMP"
    echo -e "${GREEN}  âœ… ActualizaciÃ³n completada.${RESET}"
    return 0
}

# =============================================================================
# MAIN
# =============================================================================
echo ""
echo -e "${GOLD}  â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€${RESET}"
echo -e "${WHITE}   ðŸ“¥ MOVIVIP NETWORK â€” ACTUALIZADOR${RESET}"
echo -e "${GOLD}  â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€${RESET}"
echo ""

LV=$(ver_local)
RV=$(ver_remota)

# Estado de la licencia
LIC_STATE=$(licencia_activa; echo $?)
PLAN_LOCAL=""
[[ -f "$LICENCIA" ]] && source "$LICENCIA" && PLAN_LOCAL="${PLAN:-}"

if [[ -z "$RV" ]]; then
    echo -e "${GRAY}  (no se pudo consultar el servidor de actualizaciones)${RESET}"
    echo -e "  VersiÃ³n local: ${WHITE}v$LV${RESET}"
    echo -e "  ${GRAY}Reintenta mÃ¡s tarde. El panel sigue funcionando normal.${RESET}"
elif ! hay_actualizacion; then
    echo -e "  VersiÃ³n local : ${WHITE}v$LV${RESET}"
    echo -e "  VersiÃ³n actual: ${WHITE}v$RV${RESET}"
    echo -e "  ${GREEN}  âœ… Ya tienes la Ãºltima versiÃ³n instalada.${RESET}"
    # Mostrar info de commit
    local_sha=$(commit_local)
    remote_sha=$(commit_remoto)
    if [[ -n "$local_sha" && -n "$remote_sha" && "$local_sha" == "$remote_sha" ]]; then
        echo -e "  ${GREEN}  âœ… CÃ³digo sincronizado (commit: ${remote_sha:0:8}).${RESET}"
    elif [[ -n "$remote_sha" ]]; then
        echo -e "  ${GOLD}  âš ï¸  VersiÃ³n igual pero hay cambios en el cÃ³digo.${RESET}"
        echo -e "  ${WHITE}  Actualiza para recibir los Ãºltimos cambios.${RESET}"
    fi
else
    echo -e "  VersiÃ³n local : ${WHITE}v$LV${RESET}"
    echo -e "  Disponible    : ${GOLD}v$RV${RESET}"
    echo ""
    # ============ HAY ACTUALIZACIÃ“N DISPONIBLE ============
    if [[ "$LIC_STATE" -eq 0 ]]; then
        echo -e "  ${GREEN}  ðŸ”‘ Tu licencia estÃ¡ ACTIVA (plan: ${PLAN_LOCAL:-premium}).${RESET}"
        echo -e "  ${WHITE}  Puedes actualizar cuando quieras.${RESET}"
        echo ""
        read -rp "$(echo -e "${CYAN}  Â¿Deseas actualizar ahora? [s/N] âž¤ ${RESET}")" CONFIRMA
        case "${CONFIRMA,,}" in
            s|si|sÃ­|y|yes)
                aplicar_update
                echo ""
                read -n1 -r -p "  Presiona ENTER para continuar..."
                exec "$BASE/menu.sh"
            ;;
            *)
                echo -e "  ${GOLD}  â­ Omitido. Puedes actualizar luego desde el menÃº â†’ [09] Update.${RESET}"
                echo -e "  ${GRAY}  El panel sigue funcionando normal.${RESET}"
                echo ""
                read -n1 -r -p "  Presiona ENTER para volver..."
                exec "$BASE/menu.sh"
            ;;
        esac
    else
        # ============ PLAN NO ACTIVO / SIN LICENCIA ============
        echo -e "  ${GOLD}  ðŸ“¢ HAY UNA ACTUALIZACIÃ“N DISPONIBLE (v$RV)${RESET}"
        echo ""
        if [[ "$LIC_STATE" -eq 2 ]]; then
            echo -e "  ${RED}  âš ï¸  Tu servidor no tiene una licencia activa.${RESET}"
        else
            echo -e "  ${RED}  âš ï¸  Tu plan (${PLAN_LOCAL:-standard}) no estÃ¡ activo.${RESET}"
        fi
        echo ""
        echo -e "  âœ… Tu panel y protocolos SIGUEN FUNCIONANDO NORMAL."
        echo -e "  ðŸ”„ Las actualizaciones requieren licencia activa."
        echo -e "  ðŸ’¡ Renueva tu licencia para recibir esta y futuras actualizaciones."
        echo ""
        echo -e "  ${CYAN}  ðŸ”‘ ContÃ¡ctanos para renovar:${RESET}"
        echo -e "  â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€"
        echo -e "  ${WHITE}  ðŸ’¬ Telegram : @MoviVIP${RESET}"
        echo -e "  ${WHITE}  ðŸ“± WhatsApp : +57 311 700 8185${RESET}"
        echo -e "  ${WHITE}  ðŸŒ Web      : https://movivip-network.web.app${RESET}"
        echo -e "  ${WHITE}  ðŸ“¢ Canal    : https://t.me/MoviVIPNetwork${RESET}"
        echo -e "  ${WHITE}  ðŸ‘¥ Grupo    : https://t.me/MoviVIPNet${RESET}"
        echo -e "  â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€"
        echo ""
        echo -e "  ${GRAY}  (No se descargÃ³ ni aplicÃ³ ningÃºn cambio)${RESET}"
        echo ""
        read -n1 -r -p "  Presiona ENTER para volver..."
        exec "$BASE/menu.sh"
    fi
fi

