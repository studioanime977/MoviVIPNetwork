#!/bin/bash
#=========================================================
# MoviVIP Network — lib/ui.sh · DESIGN SYSTEM "NEBULA" v6.0
# Identidad visual premium propia (propia y original):
#   • Ancho dinámico (se adapta al terminal, máx 110 col)
#   • Sin columnas ║ — estilo "glass dashboard" limpio
#   • Barras de firma con ◆ y gradiente dim→cyan→gold
#   • Centrado matemático con compensación de emojis
#   • Secciones con barra de acento  ▎
#
# Uso:  source "$BASE/lib/ui.sh"
#   mv_header "TITULO" "Subtitulo" "v6.0"
#   mv_section "💻 SISTEMA"
#   mv_kv "IP" "$IP"
#   mv_pill "ON" "Cloudflare"
#   mv_footer_contacts
#=========================================================

[[ -n "$MV_UI_LOADED" ]] && return 0
MV_UI_LOADED=1

# ── Paleta NEBULA ──
MV_R="\e[0m"; MV_RED="\e[1;91m"; MV_GRN="\e[1;92m"; MV_GLD="\e[1;93m"
MV_BLU="\e[1;94m"; MV_MAG="\e[1;95m"; MV_CYN="\e[1;96m"; MV_WHT="\e[1;97m"
MV_DIM="\e[1;90m"; MV_BLD="\e[1m"

# ── Ancho del terminal (cap estético 110, respeta terminal estrecho) ──
# NOTA v5.8: se eliminó el forzado a 80 cuando el ancho < 46. En móvil el
# terminal reporta 40-57 cols; forzar 80 provocaba que las líneas de firma y
# separadores se envuelvan → efecto de "header duplicado". Ahora se respeta
# el ancho real con una cap mínima segura de 30 (evita wrap en móvil).
mv_cols(){
    local C=""
    C=$(tput cols 2>/dev/null) || true
    [[ -z "$C" || ! "$C" =~ ^[0-9]+$ ]] && C="${COLUMNS:-80}"
    (( C < 30 )) && C=30
    (( C > 110 )) && C=110
    echo "$C"
}

# ── Ancho visible real (ignora ANSI; emoji = 2 cols; VS16/ZWJ = 0) ──
# NOTA: los `local` van en líneas separadas — en una sola línea,
# bash expande ${#s} ANTES de asignar s (trampa clásica de `local`)
mv_w(){
    local s="${1:-}"
    local c n w skip clean
    local i=0
    # ── Strip ANSI en DOBLE modo ──
    # 1) byte ESC real   (\x1b[...m)
    # 2) TEXTO literal "\e[...m" (este proyecto define colores con "\e[..."
    #    dentro de comillas dobles y los interpreta luego vía printf %b)
    skip=0; clean=""
    n=${#s}
    while (( i < n )); do
        c="${s:i:1}"
        if (( skip )); then
            [[ "$c" == "m" ]] && skip=0
            ((i++)); continue
        fi
        if [[ "$c" == $'\x1b' ]]; then skip=1; ((i++)); continue; fi
        if [[ "$c" == '\' && "${s:i+1:1}" == "e" && "${s:i+2:1}" == "[" ]]; then
            skip=1; ((i+=3)); continue
        fi
        clean+="$c"
        ((i++))
    done
    s="$clean"
    # ── Ancho visible (emoji = 2 cols; VS16/ZWJ = 0) ──
    local len=${#s}
    w=0
    for ((i=0;i<len;i++)); do
        c="${s:i:1}"
        case "$c" in $'\ufe0f'|$'\u200d'|$'\u20e3') continue ;; esac
        printf -v cp '%d' "'$c" 2>/dev/null || cp=63
        if (( cp >= 126976 )); then ((w+=2)); else ((w+=1)); fi   # U+1F000+
    done
    echo "$w"
}

# ── Imprimir centrado en el ancho actual ──
mv_center(){
    local W txt vis pad
    W=$(mv_cols)
    txt="$1"
    vis=$(mv_w "$txt")
    pad=$(( (W - vis) / 2 )); (( pad < 0 )) && pad=0
    printf "%*s%b\n" "$pad" "" "$txt"
}

# ── Línea horizontal completa ──
# mv_line [carácter] [color]   → defecto: ━ cyan
mv_line(){
    local W ch="${1:-━}" col="${2:-${MV_CYN}}"
    W=$(mv_cols)
    printf "%b%s%b\n" "$col" "$(printf "${ch}%.0s" $(seq 1 $((W-1))))" "$MV_R"
}
mv_line_thin(){ mv_line "─" "$MV_DIM"; }

# ── Barra de firma NEBULA: ──◆────◆──── (dim→cyan→gold) ──
mv_signature(){
    local W seg i part
    W=$(mv_cols)
    seg=$(( (W - 1) / 3 ))
    printf "%b╭%b" "$MV_DIM" "$MV_R"
    printf "%b" "$MV_DIM";   printf '─%.0s' $(seq 1 "$seg");              printf "%b" "$MV_R"
    printf "%b◆%b"  "$MV_GLD" "$MV_R"
    printf "%b" "$MV_CYN";   printf '─%.0s' $(seq 1 "$seg");              printf "%b◆%b" "$MV_GLD" "$MV_R"
    part=$(( W - 2*seg - 4 )); (( part < 1 )) && part=1
    printf "%b" "$MV_GLD";   printf '─%.0s' $(seq 1 "$part");             printf "%b╮%b\n" "$MV_R" "$MV_R"
}

# ── Banner principal ──
mv_header(){
    local TITLE="$1" SUB="${2:-}" VER="${3:-v6.0}"
    mv_signature
    mv_center "${MV_GLD}🛡️${MV_R}  ${MV_BLD}${MV_WHT}${TITLE}${MV_R}  ${MV_DIM}[${MV_R} ${MV_CYN}${VER}${MV_R} ${MV_DIM}]${MV_R}  ${MV_GLD}🛡️${MV_R}"
    [[ -n "$SUB" ]] && mv_center "${MV_GLD}⚡${MV_R} ${MV_DIM}${SUB}${MV_R} ${MV_GLD}🔒${MV_R}"
}

# ── Contactos centrados (chips) ──
movivip_contacts(){
    # En modo móvil (terminal estrecho) se muestran compactos en 2 líneas cortas
    # para que ninguno desborde el ancho de la pantalla.
    if mv_simple_mode 2>/dev/null; then
        mv_center "${MV_DIM}📢${MV_R} ${MV_WHT}t.me/MoviVIPNetwork${MV_R}"
        mv_center "${MV_CYN}📱${MV_R} ${MV_WHT}t.me/MoviVIPNet · @MoviVIP${MV_R}"
        mv_center "${MV_DIM}🌐${MV_R} ${MV_WHT}movivip-network.web.app${MV_R}"
        mv_center "${MV_CYN}+57 311 700 8185${MV_R}"
    else
        mv_center "${MV_DIM}📢${MV_R} ${MV_WHT}t.me/MoviVIPNetwork${MV_R} ${MV_DIM}·${MV_R} ${MV_WHT}t.me/MoviVIPNet${MV_R} ${MV_DIM}·${MV_R} ${MV_WHT}@MoviVIP${MV_R}"
        mv_center "${MV_DIM}🌐${MV_R} ${MV_WHT}movivip-network.web.app${MV_R} ${MV_DIM}·${MV_R} ${MV_CYN}📱${MV_R} ${MV_WHT}+57 311 700 8185${MV_R}"
    fi
}

# ── Header para SUBMENÚS ──
movivip_sub_header(){
    local TITLE="$1"
    mv_line_thin
    mv_center "${MV_CYN}◆${MV_R} ${MV_BLD}${MV_WHT}${TITLE}${MV_R}"
    movivip_contacts
    mv_line_thin
}

# ── Sección interior:  ▎◆ TÍTULO ──
mv_section(){
    local W txt vis dash
    W=$(mv_cols)
    txt="${1:-}"
    vis=$(mv_w "◆ ${txt}")          # $( ) comando — NO $(( )) aritmética
    dash=$(( W - vis - 8 )); (( dash < 1 )) && dash=1
    printf "\n ${MV_CYN}▎${MV_R}${MV_GLD}◆${MV_R} ${MV_BLD}${MV_WHT}%s${MV_R} ${MV_DIM}%s${MV_R}\n" \
        "$txt" "$(printf '─%.0s' $(seq 1 "$dash"))"
}

# ── Clave/valor alineado:   CLAVE ····· valor ──
mv_kv(){
    local key="$1" valc="${2:-${MV_WHT}}" val="${3:-}" W kw pad
    W=$(mv_cols)
    kw=14
    pad=$(( W - kw - ${#val} - 8 )); (( pad < 1 )) && pad=1
    printf "   ${MV_DIM}%-${kw}s${MV_R}${valc}%s${MV_R}\n" "${key}" "$val"
}

# ── Pill de estado:  [● ON] ──
mv_pill(){
    if [[ "$1" == "ON" || "$1" == "on" || "$1" == "active" ]]; then
        printf "${MV_GRN}[● ON]${MV_R}"
    elif [[ "$1" == "WARN" ]]; then
        printf "${MV_GLD}[◐ WARN]${MV_R}"
    else
        printf "${MV_RED}[○ OFF]${MV_R}"
    fi
}

# ── Footer de contactos (despedidas) ──
movivip_footer(){
    echo ""
    mv_line_thin
    mv_center "${MV_DIM}🤝 Socios:${MV_R} ${MV_WHT}t.me/FreeNetZonevip${MV_R} ${MV_DIM}·${MV_R} ${MV_WHT}t.me/FreeNetZonevips${MV_R}"
    mv_line_thin
}
