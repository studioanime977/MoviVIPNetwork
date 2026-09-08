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
# TRX — TRADUCTOR RUNTIME (diccionario por idioma)
# Formato del archivo <lang>.dict: CLAVE<TAB>TRADUCCIÓN (una por línea)
# Si la clave no existe → se devuelve el texto original (fallback español)
# ═══════════════════════════════════════════════════════════════

declare -gA TRX_TABLE=()

load_trx_table() {
    local lang_code="${1:-es}"
    local dict_file="$(find_lang_dir)/${lang_code}.dict"
    TRX_TABLE=()
    [[ -f "$dict_file" ]] || return 0
    local key val
    while IFS=$'\t' read -r key val; do
        [[ -z "$key" ]] && continue
        [[ "$key" == \#* ]] && continue
        # FIX v6.3: eliminar \r residual (dicts con CRLF rompían el render —
        # el valor quedaba con \r colgado que pisaba la línea siguiente).
        key="${key%$'\r'}"
        val="${val%$'\r'}"
        # FIX v6.4: una línea vacía con CRLF ('\r') NO entraba en el primer
        # guard [[ -z $key ]] → tras el strip quedaba clave '' → TRX_TABLE[""]
        # disparaba "bad array subscript" (bash) al arrancar el menú.
        [[ -z "$key" ]] && continue
        [[ -z "$val" ]] && continue
        TRX_TABLE["$key"]="$val"
    done < "$dict_file"
}

trx() {
    local key="$1"
    local val="${TRX_TABLE[$key]:-}"
    if [[ -n "$val" ]]; then
        printf '%s' "$val"
    else
        printf '%s' "$key"
    fi
}

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
        load_trx_table "$lang_code"
        return 0
    else
        # Fallback a español
        local fallback="$(find_lang_dir)/es.sh"
        if [[ -f "$fallback" ]]; then
            source "$fallback"
            echo "es" > "$LANG_STATE" 2>/dev/null
            load_trx_table "es"
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
    echo "en|🇺🇸|Inglés|Estados Unidos/Reino Unido"
    echo "af|🇪🇹|Afaan Oromoo|Etiopía/Kenia"
    echo "fr|🇫🇷|Francés|Francia/Bélgica"
    echo "pt|🇧🇷|Portugués|Brasil/Portugal"
    echo "ar|🇸🇦|Árabe|Arabia Saudita/Egipto"
    echo "sw|🇰🇪|Kiswahili|Kenia/Tanzania"
    echo "de|🇩🇪|Alemán|Alemania/Austria"
    echo "zh|🇨🇳|Chino|China"
    echo "hi|🇮🇳|Hindi|India"
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
    echo -e "${CYAN}║${GOLD}          🌐 SELECTOR DE IDIOMA / LANGUAGE SELECTOR 🌐${RESET}${CYAN}         ║${RESET}"
    echo -e "${CYAN}║${WHITE}          Elige tu idioma / Choose your language${RESET}${CYAN}              ║${RESET}"
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
    printf "  ${GRAY}● = idioma actual / current language${RESET}                   \n"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    read -rp "$(echo -e "${CYAN}➜ ${GOLD}Selecciona el idioma [1-10]${WHITE} ➤ ${RESET}")" LANG_CHOICE

    # Mapear número a código de idioma
    local langs=("es" "en" "af" "fr" "pt" "ar" "sw" "de" "zh" "hi")
    local idx=$((LANG_CHOICE - 1))

    if [[ $idx -ge 0 && $idx -lt ${#langs[@]} ]]; then
        local selected="${langs[$idx]}"
        set_language "$selected"
        load_language "$selected"
        echo ""
        echo -e "${GREEN}✅ Idioma cambiado correctamente: ${WHITE}${LANG_NAME} ${LANG_FLAG}${RESET}"
        sleep 1
        return 0
    else
        echo -e "${RED}❌ Opción inválida${RESET}"
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
