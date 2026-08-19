#!/bin/bash
# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
#   MOVIVIP NETWORK â€” LANGUAGE LOADER v2.0
#   Carga el idioma seleccionado y ofrece selector global
# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

BASE="/etc/movivip"
CONFIG="$BASE/config.conf"
LANG_DIR="$BASE/languages"
LANG_STATE="$BASE/.current_lang"

# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
# LANGUAGES_DIR â€” busca en /etc/movivip/languages o en el script dir
# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

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

# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
# load_language â€” carga un archivo de idioma
# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

load_language() {
    local lang_code="${1:-es}"
    local lang_file="$(find_lang_dir)/${lang_code}.sh"

    if [[ -f "$lang_file" ]]; then
        source "$lang_file"
        echo "$lang_code" > "$LANG_STATE" 2>/dev/null
        return 0
    else
        # Fallback a espaÃ±ol
        local fallback="$(find_lang_dir)/es.sh"
        if [[ -f "$fallback" ]]; then
            source "$fallback"
            echo "es" > "$LANG_STATE" 2>/dev/null
            return 0
        fi
        return 1
    fi
}

# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
# get_current_language â€” obtiene el idioma actual
# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

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

# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
# set_language â€” cambia el idioma y actualiza config
# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

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

# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
# list_languages â€” retorna lista de idiomas disponibles
# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

list_languages() {
    local lang_dir="$(find_lang_dir)"
    echo "es|ðŸ‡ªðŸ‡¸|EspaÃ±ol|EspaÃ±a/LatinoamÃ©rica"
    echo "en|ðŸ‡ºðŸ‡¸|English|United States/UK"
    echo "af|ðŸ‡ªðŸ‡¹|Afaan Oromoo|Ethiopia/Kenya"
    echo "fr|ðŸ‡«ðŸ‡·|FranÃ§ais|France/Belgique"
    echo "pt|ðŸ‡§ðŸ‡·|PortuguÃªs|Brasil/Portugal"
    echo "ar|ðŸ‡¸ðŸ‡¦|Ø§Ù„Ø¹Ø±Ø¨ÙŠØ©|Ø§Ù„Ø³Ø¹ÙˆØ¯ÙŠØ©/Ù…ØµØ±"
    echo "sw|ðŸ‡°ðŸ‡ª|Kiswahili|Kenya/Tanzania"
    echo "de|ðŸ‡©ðŸ‡ª|Deutsch|Deutschland/Ã–sterreich"
    echo "zh|ðŸ‡¨ðŸ‡³|ä¸­æ–‡|ä¸­å›½"
    echo "hi|ðŸ‡®ðŸ‡³|à¤¹à¤¿à¤¨à¥à¤¦à¥€|à¤­à¤¾à¤°à¤¤"
}

# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
# language_selector â€” selector interactivo de idioma
# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

language_selector() {
    local current="$(get_current_language)"

    # Colores
    CYAN="\e[1;96m"; GOLD="\e[1;93m"; GREEN="\e[1;92m"
    RED="\e[1;91m"; WHITE="\e[1;97m"; GRAY="\e[1;90m"; RESET="\e[0m"

    clear
    echo ""
    echo -e "${CYAN}â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—${RESET}"
    echo -e "${CYAN}â•‘${GOLD}          ðŸŒ SELECT LANGUAGE / SELECCIONAR IDIOMA ðŸŒ${RESET}${CYAN}           â•‘${RESET}"
    echo -e "${CYAN}â•‘${WHITE}          Choose your language / Elige tu idioma${RESET}${CYAN}              â•‘${RESET}"
    echo -e "${CYAN}â• â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•£${RESET}"
    echo ""

    local i=1
    while IFS='|' read -r code flag name region; do
        local marker=" "
        [[ "$code" == "$current" ]] && marker="${GREEN}â—${RESET}"
        printf "  ${CYAN}[%02d]${RESET} ${WHITE}%s %-15s${RESET} ${GRAY}%-20s${RESET} %s\n" \
            "$i" "$flag" "$name" "$region" "$marker"
        ((i++))
    done < <(list_languages)

    echo ""
    echo -e "${CYAN}â• â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•£${RESET}"
    printf "  ${GRAY}â— = idioma actual${RESET}                                       \n"
    echo -e "${CYAN}â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${RESET}"
    echo ""
    read -rp "$(echo -e "${CYAN}âžœ ${GOLD}Select language [1-10]${WHITE} âž¤ ${RESET}")" LANG_CHOICE

    # Mapear nÃºmero a cÃ³digo de idioma
    local langs=("es" "en" "af" "fr" "pt" "ar" "sw" "de" "zh" "hi")
    local idx=$((LANG_CHOICE - 1))

    if [[ $idx -ge 0 && $idx -lt ${#langs[@]} ]]; then
        local selected="${langs[$idx]}"
        set_language "$selected"
        load_language "$selected"
        echo ""
        echo -e "${GREEN}âœ… Language changed / Idioma cambiado: ${WHITE}${LANG_NAME} ${LANG_FLAG}${RESET}"
        sleep 1
        return 0
    else
        echo -e "${RED}âŒ Invalid option${RESET}"
        sleep 1
        return 1
    fi
}

# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
# AUTO-LOAD al hacer source de este archivo
# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

# Si se hace source, cargar idioma actual automÃ¡ticamente
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    _current_lang="$(get_current_language)"
    load_language "$_current_lang"
fi
