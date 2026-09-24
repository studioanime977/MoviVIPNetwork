#!/bin/bash
#==============================================================
# lib/delivery.sh — Tarjeta de entrega premium (NEBULA PREMIUM)
# MoviVIP Network · Generador de plantillas de cuenta
#==============================================================
# Los DATOS relevantes se envuelven en BACKTICKS literales
# (_BT) para que al pegar la salida en Telegram se renderice
# como bloque de código copiable.
#   ⚠  Un backtick crudo dentro de comillas dobles dispara
#      command substitution en bash → SIEMPRE usa mv_tick().
#==============================================================

[[ "${MV_R:-}" ]] || source "${BASE:-/etc/movivip}/lib/ui.sh" 2>/dev/null || true

# Backtick literal (evita command substitution)
_BT='`'

# Colores de respaldo (por si ui.sh no define MV_*)
[[ -n "${MV_R:-}" ]] || { MV_R=$'\e[0m'; MV_GRN=$'\e[38;5;82m'; MV_GLD=$'\e[38;5;220m'; MV_YLW=$'\e[38;5;226m'; MV_CYN=$'\e[38;5;45m'; MV_MAG=$'\e[38;5;201m'; MV_ORA=$'\e[38;5;208m'; MV_WHT=$'\e[38;5;255m'; MV_DIM=$'\e[38;5;245m'; MV_BLD=$'\e[1m'; MV_RED=$'\e[38;5;203m'; MV_CYN2=$'\e[38;5;51m'; MV_BLU=$'\e[38;5;39m'; }

# Paleta premium (cian➜azul➜morado➜dorado➜naranja➜cian)
_PREMIUM_PAL=(45 39 201 220 208 51)

#--- Ancho seguro ---
_mv_cols(){ local C; C=$(tput cols 2>/dev/null); [[ -z "$C" || ! "$C" =~ ^[0-9]+$ ]] && C="${COLUMNS:-70}"; (( C < 20 )) && C=20; (( C > 110 )) && C=110; echo "$C"; }

#--- Envuelve un valor en backticks literales con color verde ---
mv_tick(){ printf "%b%b%s%b%b" "$MV_GRN" "$_BT" "$1" "$_BT" "$MV_R"; }

#--- Envuelve SIN color (útil para pegar cabeceras/listas crudas) ---
mv_tick_plain(){ printf "%s%s%s" "$_BT" "$1" "$_BT"; }

#--- Línea arcoíris por segmentos (fallback local si no existe en ui.sh) ---
mv_deliv_rainbow(){
    if declare -F mv_sep_rainbow >/dev/null 2>&1; then mv_sep_rainbow; return; fi
    local W i seg pal=("${_PREMIUM_PAL[@]}") pos
    W=$(_mv_cols); (( W < 20 )) && W=20
    seg=$(( W / ${#pal[@]} )); (( seg < 3 )) && seg=3
    for (( i=0; i<W; i++ )); do
        pos=$(( i / seg )); (( pos >= ${#pal[@]} )) && pos=$(( ${#pal[@]} - 1 ))
        printf "\e[38;5;${pal[$pos]}m─"
    done
    printf "%b\n" "$MV_R"
}

#--- Línea simple con color ---
mv_deliv_line(){
    local ch="${1:-═}" col="${2:-${MV_CYN}}" W
    W=$(_mv_cols)
    printf "%b%s%b" "$col" "$(printf "${ch}%.0s" $(seq 1 $W))" "$MV_R"
}

#--- Eslogan premium (rotativo determinista por hora) ---
mv_deliv_slogan(){
    local slogans=( \
        "⚡ Ultra Performance & Maximum Speed" \
        "🛡️ Seguridad Total · Alta Disponibilidad" \
        "🚀 Velocidad Extrema · Latencia Mínima" \
        "🐉 VINCIT QUI PATITUR · El Que Soporta Vence" \
        "🌐 Premium 24/7 · Soporte Dedicado" \
        "🔐 Servidor Blindado · Protocolos Estables" )
    local idx=$(( (10#$(date +%H) + ${2:-0}) % ${#slogans[@]} ))
    printf "%s" "${slogans[$idx]}"
}

#==============================================================
# CABECERA PREMIUM  ── rainbow ---- MoviVIP ---- TÍTULO
# Reproduce la tarjeta oficial del usuario. LANZAMIENTO:
#   mv_deliv_header "TÍTULO" "SUBTÍTULO"
#==============================================================
mv_deliv_header(){
    local TITLE="$1" SUB="${2:-}"
    echo
    mv_deliv_rainbow
    mv_center_line() {
        local W t="$1" col="$2" len pad
        W=$(_mv_cols)
        len=$(printf '%s' "$t" | sed -e 's/\x1b\[[0-9;]*m//g' | wc -m)
        pad=$(( (W - len) / 2 )); (( pad < 1 )) && pad=1
        printf "%${pad}s%s\n" "" "$t"
    }
    mv_center_line "${MV_MAG}◎${MV_R} ${MV_BLD}${MV_WHT}MoviVIP Network${MV_R} ${MV_MAG}◎${MV_R}" ""
    [[ -n "$SUB" ]] && mv_center_line "${MV_BLD}${MV_WHT}${TITLE}${MV_R}" ""
    [[ -n "$SUB" ]] && mv_center_line "${MV_YLW}${SUB}${MV_R}" ""
    mv_center_line "${MV_DIM}$(mv_deliv_slogan)${MV_R}" ""
    mv_deliv_rainbow
    echo
}

#==============================================================
# PANEL DE DATOS  ┌ label : `valor` ┐ ── caja premium
#   mv_dcard_top  "TÍTULO [opcional]"
#   mv_dcard_row  "👤" "Usuario" "movivip"     → backtick
#   mv_dcard_rowv "👑" "VIP" "activado"        → valor SIN backtick
#   mv_dcard_mid  ["TÍTULO"]
#   mv_dcard_bot
#==============================================================
mv_dcard_top(){
    local TITLE="${1:-}" W bar bar2
    W=$(_mv_cols)
    bar=$(printf '═%.0s' $(seq 1 $((W-2))))
    printf "%b╔%s╗%b\n" "$MV_CYN" "$bar" "$MV_R"
    if [[ -n "$TITLE" ]]; then
        printf "%b┃%b %b%s%b %b──%s%b\n" "$MV_CYN" "$MV_R" "$MV_GLD" "$TITLE" "$MV_R" "$MV_DIM" "$(printf '─%.0s' $(seq 1 $((W - ${#TITLE} - 10))))" "$MV_R"
    fi
}

mv_dcard_row(){
    local icon="$1" label="$2" val="$3" W disp
    printf "%b│ %b%s%b %b%-14s%b : %s %b│%b\n" \
        "$MV_CYN" "$MV_ORA" "$icon" "$MV_R" \
        "$MV_CYN" "$label" "$MV_R" \
        "$(mv_tick "$val")" "$MV_CYN" "$MV_R"
}

mv_dcard_rowv(){
    local icon="$1" label="$2" val="$3"
    printf "%b│ %b%s%b %b%-14s%b : %b%s%b %b│%b\n" \
        "$MV_CYN" "$MV_ORA" "$icon" "$MV_R" \
        "$MV_CYN" "$label" "$MV_R" \
        "$MV_WHT" "$val" "$MV_R" "$MV_CYN" "$MV_R"
}

mv_dcard_mid(){
    local TITLE="${1:-}" W bar
    W=$(_mv_cols)
    bar=$(printf '─%.0s' $(seq 1 $((W-2))))
    printf "%b├%s┤%b\n" "$MV_CYN" "$bar" "$MV_R"
    if [[ -n "$TITLE" ]]; then
        printf "%b┃%b %b%s%b\n" "$MV_CYN" "$MV_R" "$MV_GLD" "$TITLE" "$MV_R"
    fi
}

mv_dcard_add(){
    local icon="$1" label="$2" val="$3"
    mv_dcard_row "$icon" "$label" "$val"
}

mv_dcard_bot(){
    local W bar
    W=$(_mv_cols)
    bar=$(printf '═%.0s' $(seq 1 $((W-2))))
    printf "%b╚%s╝%b\n" "$MV_CYN" "$bar" "$MV_R"
}

#==============================================================
# LÍNEA DE SERVIDOR / DATO SUELTO con backtick
#   mv_deliv_kv "🖥️" "Servidor" "vps.movivip.net"
#==============================================================
mv_deliv_kv(){
    local icon="$1" label="$2" val="$3"
    printf "%b%s%b %b%s%b : %s\n" \
        "$MV_WHT" "$icon" "$MV_R" \
        "$MV_BLD$MV_WHT" "$label" "$MV_R" \
        "$(mv_tick "$val")"
}

#==============================================================
# Seatlet de sección: ◆ TÍTULO (con marcos ──)
#==============================================================
mv_deliv_sec(){
    if declare -F mv_section >/dev/null 2>&1; then
        mv_section "$1" 2>/dev/null || printf "\n ${MV_MAG}┃${MV_R}${MV_GLD}◆${MV_R} ${MV_BLD}${MV_WHT}%s${MV_R}\n" "$1"
    else
        printf "\n ${MV_MAG}┃${MV_R}${MV_GLD}◆${MV_R} ${MV_BLD}${MV_WHT}%s${MV_R}\n" "$1"
    fi
}

#==============================================================
# PIE DE MARCA — eslogan + contacto (hace que la tarjeta se venda sola)
#   mv_deliv_pie [mensaje opcional]
#==============================================================
mv_deliv_pie(){
    local extra="${1:-}"
    echo
    mv_deliv_rainbow
    printf "%b%b %b%s%b %b%s%b\n" \
        "$MV_GLD" "◆" "$MV_BLD" "VINCIT QUI PATITUR" "$MV_R" \
        "$MV_DIM" "- El que soporta, vence" "$MV_R"
    printf "%b%b %b%s%b %b·%b %b%s%b %b·%b %b%s%b\n" \
        "$MV_ORA" "📢" "$MV_R" "t.me/MoviVIPNetwork" "$MV_R" \
        "$MV_DIM" "$MV_R" "$MV_YLW" "@MoviVIP" "$MV_R" \
        "$MV_DIM" "$MV_R" "$MV_CYN" "movivip-network.web.app" "$MV_R"
    [[ -n "$extra" ]] && printf "%b%b %b%s%b\n" "$MV_GLD" "◆" "$MV_R" "$extra" "$MV_R"
    mv_deliv_rainbow
    echo
}

#==============================================================
# FILTRO ANTI-MOJIBIKE: limpia la salida de caracteres rotos
#==============================================================
mv_clean_deliv(){
    sed -e 's/\x1b\[[0-9;]*m//g' \
        -e 's/\x1b\[[0-9;]*[A-Za-z]//g' \
        -e 's/[^[:print:]\n\r\t]//g'
}