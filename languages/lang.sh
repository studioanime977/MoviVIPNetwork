#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#   MOVIVIP NETWORK — LANGUAGE LOADER v2.0
#   Carga el idioma seleccionado y ofrece selector global
# ═══════════════════════════════════════════════════════════════

BASE="/etc/movivip"
CONFIG="$BASE/config.conf"
LANG_DIR="$BASE/languages"
LANG_STATE="$BASE/.current_lang"

# ═══════════════════════════════════════════════════════════════
# LANGUAGES_DIR — busca en /etc/movivip/languages o en el script dir
# ═══════════════════════════════════════════════════════════════

find_lang_dir() {
    # Prioridad: /etc/movivip/languages > directorio del script > fallback
    if [[ -d "$LANG_DIR" ]]; then
        echo "$LANG_DIR"
    elif [[ -d "$(dirname "$(readlink -f "$0")")/languages" ]]; then
        echo "$(dirname "$(readlink -f "$0")")/languages"
    else
        echo "$LANG_DIR"
    fi
}

# ═══════════════════════════════════════════════════════════════
# load_language — carga un archivo de idioma
# ═══════════════════════════════════════════════════════════════

load_language() {
    local lang_code="${1:-es}"
    local lang_file="$(find_lang_dir)/${lang_code}.sh"

    if [[ -f "$lang_file" ]]; then
        source "$lang_file"
        echo "$lang_code" > "$LANG_STATE" 2>/dev/null
        return 0
    else
        # Fallback a español
        local fallback="$(find_lang_dir)/es.sh"
        if [[ -f "$fallback" ]]; then
            source "$fallback"
            echo "es" > "$LANG_STATE" 2>/dev/null
            return 0
        fi
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════
# get_current_language — obtiene el idioma actual
# ═══════════════════════════════════════════════════════════════

get_current_language() {
    if [[ -f "$LANG_STATE" ]]; then
        cat "$LANG_STATE" 2>/dev/null
    elif [[ -f "$CONFIG" ]]; then
        source "$CONFIG" 2>/dev/null
        echo "${LANGUAGE:-es}"
    else
        echo "es"
    fi
}

# ═══════════════════════════════════════════════════════════════
# set_language — cambia el idioma y actualiza config
# ═══════════════════════════════════════════════════════════════

set_language() {
    local new_lang="$1"

    # Guardar en estado
    echo "$new_lang" > "$LANG_STATE" 2>/dev/null

    # Actualizar config.conf
    if [[ -f "$CONFIG" ]]; then
        if grep -q "^LANGUAGE=" "$CONFIG"; then
            sed -i "s/^LANGUAGE=.*/LANGUAGE=$new_lang/" "$CONFIG"
        else
            echo "LANGUAGE=$new_lang" >> "$CONFIG"
        fi
    fi

    # Recargar idioma
    load_language "$new_lang"
}

# ═══════════════════════════════════════════════════════════════
# list_languages — retorna lista de idiomas disponibles
# ═══════════════════════════════════════════════════════════════

list_languages() {
    local lang_dir="$(find_lang_dir)"
    echo "es|🇪🇸|Español|España/Latinoamérica"
    echo "en|🇺🇸|English|United States/UK"
    echo "af|🇪🇹|Afaan Oromoo|Ethiopia/Kenya"
    echo "fr|🇫🇷|Français|France/Belgique"
    echo "pt|🇧🇷|Português|Brasil/Portugal"
    echo "ar|🇸🇦|العربية|السعودية/مصر"
    echo "sw|🇰🇪|Kiswahili|Kenya/Tanzania"
    echo "de|🇩🇪|Deutsch|Deutschland/Österreich"
    echo "zh|🇨🇳|中文|中国"
    echo "hi|🇮🇳|हिन्दी|भारत"
}

# ═══════════════════════════════════════════════════════════════
# language_selector — selector interactivo de idioma
# ═══════════════════════════════════════════════════════════════

language_selector() {
    local current="$(get_current_language)"

    # Colores
    CYAN="\e[1;96m"; GOLD="\e[1;93m"; GREEN="\e[1;92m"
    RED="\e[1;91m"; WHITE="\e[1;97m"; GRAY="\e[1;90m"; RESET="\e[0m"

    clear
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${GOLD}          🌐 SELECT LANGUAGE / SELECCIONAR IDIOMA 🌐${RESET}${CYAN}           ║${RESET}"
    echo -e "${CYAN}║${WHITE}          Choose your language / Elige tu idioma${RESET}${CYAN}              ║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"
    echo ""

    local i=1
    while IFS='|' read -r code flag name region; do
        local marker=" "
        [[ "$code" == "$current" ]] && marker="${GREEN}●${RESET}"
        printf "  ${CYAN}[%02d]${RESET} ${WHITE}%s %-15s${RESET} ${GRAY}%-20s${RESET} %s\n" \
            "$i" "$flag" "$name" "$region" "$marker"
        ((i++))
    done < <(list_languages)

    echo ""
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"
    printf "  ${GRAY}● = idioma actual${RESET}                                       \n"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    read -rp "$(echo -e "${CYAN}➜ ${GOLD}Select language [1-10]${WHITE} ➤ ${RESET}")" LANG_CHOICE

    # Mapear número a código de idioma
    local langs=("es" "en" "af" "fr" "pt" "ar" "sw" "de" "zh" "hi")
    local idx=$((LANG_CHOICE - 1))

    if [[ $idx -ge 0 && $idx -lt ${#langs[@]} ]]; then
        local selected="${langs[$idx]}"
        set_language "$selected"
        load_language "$selected"
        echo ""
        echo -e "${GREEN}✅ Language changed / Idioma cambiado: ${WHITE}${LANG_NAME} ${LANG_FLAG}${RESET}"
        sleep 1
        return 0
    else
        echo -e "${RED}❌ Invalid option${RESET}"
        sleep 1
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════
# AUTO-LOAD al hacer source de este archivo
# ═══════════════════════════════════════════════════════════════

# Si se hace source, cargar idioma actual automáticamente
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    _current_lang="$(get_current_language)"
    load_language "$_current_lang"
fi
