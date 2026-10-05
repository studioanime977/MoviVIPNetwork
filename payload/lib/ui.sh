#!/bin/bash
#=============================================================
# MoviVIP Network Ã¢â‚¬â€ lib/ui.sh Ã‚Â· DESIGN SYSTEM "NEBULA CYBER-VIP" v9.0
# Identidad visual de ÃƒÂ©lite 2026 Ã¢â‚¬â€ Cyber Luxury UI / Terminal Console
#   Ã¢â‚¬Â¢ Paleta ANSI-256: NeÃƒÂ³n Cyan 51/45 Ã‚Â· Zafiro 39/33 Ã‚Â· VIP Gold 220/226 Ã‚Â·
#     Esmeralda 82/48 Ã‚Â· Ruby 203 Ã‚Â· Ultraviolet 141/201 Ã‚Â· Pure White 255 Ã‚Â· Slate 244
#   Ã¢â‚¬Â¢ Marcos Card-Based con esquinas redondeadas Ã¢â€¢Â­Ã¢â€â‚¬Ã¢â€¢Â® Ã¢â€â€š Ã¢â€¢Â°Ã¢â€â‚¬Ã¢â€¢Â¯ de alineaciÃƒÂ³n perfecta
#   Ã¢â‚¬Â¢ Banner 3D con degradado Cyber fluido por carÃƒÂ¡cter
#   Ã¢â‚¬Â¢ Barras de progreso ultra-suaves con porcentaje real
#   Ã¢â‚¬Â¢ Ejecutores de carga silenciosos: CERO fugas de cÃƒÂ³digo ni logs en pantalla
#=============================================================

# Este guardia tenia "$MV_UI_LOADED" sin defecto. Referenciar una variable no
# asignada con "set -u" activo aborta el script, y hay varios cargadores de este
# fichero que lo llevan: herramientas/facturas.sh va con "set -euo pipefail" y
# menu.sh carga la lib entera. Con ${MV_UI_LOADED:-} la guarda sigue haciendo su
# trabajo y no hay Variable no asignada.
#
# Ojo con las dos librerias de UI: esta (lib/ui.sh, prefijo MV_) la usan el menu
# y las herramientas; lib/mvui.sh (prefijo MVUI_) es aparte y es la que carga
# install.sh, que aborta si no la encuentra.
[[ -n "${MV_UI_LOADED:-}" ]] && return 0
MV_UI_LOADED=1

# Ã¢â€â‚¬Ã¢â€â‚¬ Paleta PREMIUM ANSI-256 Ã¢â€â‚¬Ã¢â€â‚¬
MV_R=$'\e[0m'
MV_BLD=$'\e[1m'
MV_DIM_TXT=$'\e[2m'

# Tonos Principales
MV_RED=$'\e[38;5;203m'
MV_RED_DK=$'\e[38;5;196m'
MV_GRN=$'\e[38;5;82m'
MV_GRN_HI=$'\e[38;5;48m'
MV_GLD=$'\e[38;5;220m'
MV_YLW=$'\e[38;5;226m'
MV_BLU=$'\e[38;5;39m'
MV_BLU2=$'\e[38;5;33m'
MV_BLU_DK=$'\e[38;5;27m'
MV_CYN=$'\e[38;5;45m'
MV_CYN2=$'\e[38;5;51m'
MV_MAG=$'\e[38;5;201m'
MV_PUR=$'\e[38;5;141m'
MV_ORA=$'\e[38;5;208m'
MV_WHT=$'\e[38;5;255m'
MV_DIM=$'\e[38;5;244m'
MV_DARK=$'\e[38;5;238m'

# Fondos para Badges / Pills
MV_BG_CYN=$'\e[48;5;24;38;5;51;1m'
MV_BG_GLD=$'\e[48;5;58;38;5;220;1m'
MV_BG_GRN=$'\e[48;5;22;38;5;82;1m'
MV_BG_RED=$'\e[48;5;52;38;5;203;1m'
MV_BG_PUR=$'\e[48;5;54;38;5;141;1m'

# Ã¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢Â
# GLIFOS CENTRALIZADOS + DEGRADACION AUTOMATICA A ASCII
# Ã¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢Â
#
# Por que esta tabla existe: antes cada linea del panel llevaba su propio glifo
# escrito a mano ("Ã¢â€â‚¬", "Ã¢â€¢Â", "Ã¢â€”â€ ", "Ã¢Ââ€“"...) repartido por todo ui.sh. Eso hacia
# dos cosas malas. Una, cambiar un simbolo obligaba a tocar media docena de
# sitios. Y dos, que es la que se vio: si un archivo llegaba con la codificacion
# rota, el garbage se propagaba a TODAS las pantallas que cargan ui.sh, no solo
# a la linea donde estaba el literal.
#
# Aqui no hay ni un glifo suelto: todo sale de MV_G_*. Y si el terminal o el
# locale no pueden con UTF-8 se carga el set ASCII, de modo que la UI se dibuja
# igual pero con caracteres de un byte. mv_san es la red de seguridad final y
# degrada cualquier no-ASCII que se cuele sin pasar por el diccionario.

# Soporte UTF-8 real. No basta con mirar el locale: si el usuario exporta
# LC_ALL=C sobre un LANG=UTF-8 el locale miente y por ahi entraba el garbage.
# La prueba final es empirica: se emite un caracter multibyte y se comprueba que
# el shell sigue viendo UN solo caracter.
mv_utf8(){
    local L="${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" n
    # 1) Override explicito. Es lo unico que manda sobre la deteccion.
    [[ "${MV_FORCE_ASCII:-0}" == "1" ]] && { echo 0; return; }
    [[ "${MV_FORCE_UTF8:-0}"   == "1" ]] && { echo 1; return; }
    # 2) El locale tiene que declarar UTF-8.
    case "$L" in *UTF-8*|*utf8*|*UTF8*) : ;; *) echo 0; return ;; esac
    # 3) Prueba empirica: el shell debe ver UN caracter multibyte.
    # No se usa TERM como criterio: TERM=dumb aparece en pipes y sesiones no
    # interactivas que manejan UTF-8 sin problema, y usarlo hacia que la UI
    # cayera a ASCII siempre en cualquier consola o instalador.
    n=$'\u2500'
    [[ "${#n}" == "1" ]] || { echo 0; return; }
    echo 1
}

# Unico lugar del proyecto donde se decide que simbolo se pinta.
mv_glyphs(){
    if [[ "$(mv_utf8)" == "1" ]]; then
        MV_ASCII=0
        MV_G_H=$'\u2500'      # Ã¢â€â‚¬ linea simple
        MV_G_D=$'\u2550'      # Ã¢â€¢Â linea doble
        MV_G_TL=$'\u256d'     # Ã¢â€¢Â­ esquina sup izq
        MV_G_TR=$'\u256e'     # Ã¢â€¢Â® esquina sup der
        MV_G_BL=$'\u2570'     # Ã¢â€¢Â° esquina inf izq
        MV_G_BR=$'\u256f'     # Ã¢â€¢Â¯ esquina inf der
        MV_G_V=$'\u2502'      # Ã¢â€â€š vertical
        MV_G_LT=$'\u251c'     # Ã¢â€Å“
        MV_G_RT=$'\u2514'     # Ã¢â€Â¤
        MV_G_RT2=$'\u2524'    # Ã¢â€Â¤ variante ligera
        MV_G_HL=$'\u250c'     # Ã¢â€Å’
        MV_G_HR=$'\u2510'     # Ã¢â€Â
        MV_G_FULL=$'\u2588'   # Ã¢â€“Ë† bloque lleno
        MV_G_LT2=$'\u2591'    # Ã¢â€“â€˜ bloque ligero
        MV_G_MD2=$'\u2592'    # Ã¢â€“â€™ bloque medio
        MV_G_DIA=$'\u25c6'    # Ã¢â€”â€  rombo
        MV_G_STAR=$'\u2756'   # Ã¢Ââ€“ estrella
        MV_G_OK=$'\u2714'     # Ã¢Å“â€
        MV_G_NO=$'\u2716'     # Ã¢Å“â€“
        MV_G_WARN=$'\u26a0'   # Ã¢Å¡Â 
        MV_G_INFO=$'\u2139'   # Ã¢â€žÂ¹
        MV_G_DOT=$'\u25cf'    # Ã¢â€”Â
        MV_G_HALF=$'\u25d0'   # Ã¢â€”Â
        MV_G_CIRC=$'\u25cb'   # Ã¢â€”â€¹
        MV_G_TRI=$'\u25ba'    # Ã¢â€“Âº
        MV_G_ARR=$'\u2192'    # Ã¢â€ â€™
        MV_G_ADD=$'\u2795'    # Ã¢Å¾â€¢
        MV_G_DN=$'\u2b07'     # Ã¢Â¬â€¡
        MV_G_UP=$'\u2b06'     # Ã¢Â¬â€ 
        MV_G_RET=$'\u21a9'    # Ã¢â€ Â©
        MV_G_REP=$'\u21bb'    # Ã¢â€ Â»
        MV_G_MID=$'\u00b7'    # Ã‚Â· punto medio
        MV_G_IDS=$'\uff61'    # Ã¯Â½Â¡
        MV_G_ST2=$'\u22c6'    # Ã¢â€¹â€ 
        MV_G_SQRT=$'\u22b1'   # Ã¢Ë†Å¡
        MV_G_ANG=$'\u22b0'    # Ã¢Ë†Â°
        MV_G_RING=$'\u02da'   # Ã‹Å¡
        MV_G_CLOUD=$'\u2601'  # Ã¢ËœÂ
        MV_G_BOLT=$'\u26a1'    # Ã¢Å¡Â¡
        MV_SPIN=('Ã¢Â â€¹' 'Ã¢Â â„¢' 'Ã¢Â Â¹' 'Ã¢Â Â¸' 'Ã¢Â Â¼' 'Ã¢Â Â´' 'Ã¢Â Â¦' 'Ã¢Â Â§' 'Ã¢Â â€¡' 'Ã¢Â Â')
    else
        MV_ASCII=1
        MV_G_H='-';      MV_G_D='='
        MV_G_TL='+';     MV_G_TR='+';     MV_G_BL='+';     MV_G_BR='+'
        MV_G_V='|';      MV_G_LT='+';     MV_G_RT='+'
        MV_G_RT2='+'
        MV_G_HL='+';     MV_G_HR='+'
        MV_G_FULL='#';   MV_G_LT2='.';    MV_G_MD2=':'
        MV_G_DIA='*';    MV_G_STAR='*'
        MV_G_OK='+';     MV_G_NO='x'
        MV_G_WARN='!';   MV_G_INFO='i'
        MV_G_DOT='*';    MV_G_HALF='o';   MV_G_CIRC='o'
        MV_G_TRI='>';    MV_G_ARR='->'
        MV_G_ADD='+';    MV_G_DN='v';     MV_G_UP='^'
        MV_G_RET='r';    MV_G_REP='r'
        MV_G_MID='.';    MV_G_IDS='.'
        MV_G_ST2='*';    MV_G_SQRT='v';   MV_G_ANG='/'
        MV_G_RING='o';   MV_G_CLOUD='*'
        MV_G_BOLT='*'
        MV_SPIN=('|' '/' '-' '\')
    fi
}

# Red de seguridad: en modo ASCII quita el selector de variacion U+FE0F y
# cualquier resto multibyte (emoji incluidos) para que no puedan aparecer
# como "a??" o "aÃ¢â€šÂ¬". En UTF-8 no toca nada, por eso es seguro en caliente.
# Este sed necesita LC_ALL=C. Sin el, "[\x80-\xff]" lo interpreta GNU sed como
# un rango de colacion entre los caracteres U+0080 y U+00FF en vez de un rango
# de bytes, y en cualquier locale multibyte (UTF-8, y Git Bash en Windows)
# aborta con "Invalid collation character". Con LC_ALL=C el rango es de bytes y
# la red de seguridad funciona en todos los servidores.
mv_san(){
    if [[ "${MV_ASCII:-0}" == "1" ]]; then
        printf '%s' "$1" | LC_ALL=C sed -e 's/\xef\xb8\x8f//g' -e 's/[\x80-\xff]//g'
    else
        printf '%s' "$1"
    fi
}
mv_glyphs

# Ã¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢Â
# UTILIDADES DE TERMINAL & MEDIDAS
# Ã¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢Â

# Ã¢â€â‚¬Ã¢â€â‚¬ Ancho de pantalla con lÃƒÂ­mites estÃƒÂ©ticos seguros (24 a 100 cols) Ã¢â€â‚¬Ã¢â€â‚¬
mv_cols(){
    local C="" T=""
    # Si no hay terminal real se usa COLUMNS. Antes se consultaba "tput cols"
    # primero siempre, y al no haber tty devolvia valores inconsistentes: el
    # mismo panel mide 50 en unas filas y 56 en otras del mismo render.
    if [[ -t 1 ]]; then
        T=$(tput cols 2>/dev/null) || true
    fi
    [[ -n "$T" && "$T" =~ ^[0-9]+$ ]] && C="$T"
    [[ -z "$C" && "${COLUMNS:-}" =~ ^[0-9]+$ ]] && C="$COLUMNS"
    [[ -z "$C" ]] && C=80
    # El suelo era 36, asi que en una terminal de 30 los recuadros se dibujaban
    # de 36 y se salian. Un panel nunca puede ser mas ancho que la pantalla.
    (( C < 24 )) && C=24
    (( C > 100 )) && C=100
    echo "$C"
}

# Ã¢â€â‚¬Ã¢â€â‚¬ Ancho visible exacto (limpia cÃƒÂ³digos ANSI y mide columnas reales) Ã¢â€â‚¬Ã¢â€â‚¬
#
# Se mide aqui y no con "wc -L" por dos motivos concretos que se vieron en
# pantalla:
#
#   1. wc -L depende del locale y del juego de caracteres de cada
#      distribucion. En una cuenta un emoji, en otra dos.
#   2. Los selectores de variacion (U+FE0F) NO los dibuja el terminal, pero
#     wc -L los cuenta. Por eso las filas con icono como "Ã¢Å¡Â¡" o "Ã¢ËœÂÃ¯Â¸Â" salian
#      una o dos columnas descentradas.
#
# Aqui el ancho es fijo y el mismo en cualquier maquina: emoji y CJK ocupan dos
# columnas, los selectores de variacion y los zero-width ocupan cero, y todo lo
# demas una. Es la unica forma de que el recuadro cierre en cualquier sitio.
mv_w(){
    # OJO: la asignacion va partida a proposito. Si se escribiera
    #     local s="${1:-}" i=0 n=${#s}
    # bash expande TODOS los argumentos antes de ejecutar "local", con lo que
    # ${#s} se evaluaria contra un s todavia sin asignar, daria 0, el bucle no
    # se recorreria nunca y mv_w devolveria 0 en todas las llamadas. Por eso s
    # y n se declaran en lineas separadas.
    local s="${1:-}"
    local i=0 total=0 c cp skip=0
    local n=${#s}
    while (( i < n )); do
        c="${s:i:1}"

        # Escapes: se saltan enteros porque no ocupan pantalla. Se cubren los
        # dos formatos, ESC real y la secuencia de dos caracteres "\e[".
        if (( skip )); then
            [[ "$c" == [a-zA-Z] ]] && skip=0
            i=$(( i + 1 )); continue
        fi
        if [[ "$c" == $'\x1b' ]]; then skip=1; i=$(( i + 1 )); continue; fi
        if [[ "$c" == '\' && "${s:i+1:1}" == "e" && "${s:i+2:1}" == "[" ]]; then
            skip=1; i=$(( i + 3 )); continue
        fi

        # printf -v evita el subshell: con $( ) habria un proceso por caracter,
        # y son decenas de llamadas por fotograma.
        printf -v cp '%d' "'$c" 2>/dev/null || cp=63

        if (( cp >= 0x20 && cp <= 0x7E )); then total=$(( total + 1 ))
        elif (( cp == 0xFE0E || cp == 0xFE0F )); then :  # selectores
        elif (( cp == 0x200B || cp == 0x200C || cp == 0x200D )); then :  # zero-width
        elif (( cp >= 0x1F000 && cp <= 0x1F9FF )); then total=$(( total + 2 ))
        elif (( cp >= 0x1FA70 && cp <= 0x1FAFF )); then total=$(( total + 2 ))
        elif (( cp >= 0x1100  && cp <= 0x115F )); then total=$(( total + 2 ))
        elif (( cp >= 0x2E80  && cp <= 0x303E )); then total=$(( total + 2 ))
        elif (( cp >= 0x3041  && cp <= 0x33FF )); then total=$(( total + 2 ))
        elif (( cp >= 0x3400  && cp <= 0x4DBF )); then total=$(( total + 2 ))
        elif (( cp >= 0x4E00  && cp <= 0x9FFF )); then total=$(( total + 2 ))
        elif (( cp >= 0xAC00  && cp <= 0xD7A3 )); then total=$(( total + 2 ))
        elif (( cp >= 0xF900  && cp <= 0xFAFF )); then total=$(( total + 2 ))
        elif (( cp >= 0xFE30  && cp <= 0xFE6F )); then total=$(( total + 2 ))
        elif (( cp >= 0xFF00  && cp <= 0xFF60 )); then total=$(( total + 2 ))
        elif (( cp >= 0xFFE0  && cp <= 0xFFE6 )); then total=$(( total + 2 ))
        else                                                      total=$(( total + 1 ))
        fi
        i=$(( i + 1 ))
    done
    printf '%s' "$total"
}

# Ã¢â€â‚¬Ã¢â€â‚¬ Recorte a ancho maximo respetando el color Ã¢â€â‚¬Ã¢â€â‚¬
#
# Los codigos ANSI se copian tal cual pero no cuentan para el ancho, y al final
# se anade un reset: si se parte una secuencia a medias el resto de la linea
# hereda el color del trozo recortado.
mv_fit(){
    local s="${1:-}" max="${2:-0}" out="" c cp skip=0 vis=0
    (( max < 1 )) && { printf '%s' "$s"; return 0; }
    local i=0 n=${#s}
    while (( i < n )); do
        c="${s:i:1}"
        if (( skip )); then
            out+="$c"; [[ "$c" == [a-zA-Z] ]] && skip=0; i=$(( i + 1 )); continue
        fi
        if [[ "$c" == $'\x1b' ]]; then skip=1; out+="$c"; i=$(( i + 1 )); continue; fi
        if [[ "$c" == '\' && "${s:i+1:1}" == "e" && "${s:i+2:1}" == "[" ]]; then
            skip=1; out+="${s:i:3}"; i=$(( i + 3 )); continue
        fi
        (( vis >= max )) && break
        printf -v cp '%d' "'$c" 2>/dev/null || cp=63
        if (( cp == 0xFE0E || cp == 0xFE0F || (cp >= 0x200B && cp <= 0x200D) )); then :
        elif (( (cp >= 0x1F000 && cp <= 0x1F9FF) || (cp >= 0x1FA70 && cp <= 0x1FAFF) ||
                (cp >= 0x1100  && cp <= 0x115F ) || (cp >= 0x2E80  && cp <= 0xA4CF ) ||
                (cp >= 0xAC00  && cp <= 0xD7A3 ) || (cp >= 0xF900  && cp <= 0xFAFF ) ||
                (cp >= 0xFE30  && cp <= 0xFF60 ) || (cp >= 0xFFE0  && cp <= 0xFFE6 ) )); then
                                                                      vis=$(( vis + 2 ))
        else                                                                        vis=$(( vis + 1 ))
        fi
        out+="$c"; i=$(( i + 1 ))
    done
    printf '%s%s' "$out" "$MV_R"
}

# Ã¢â€â‚¬Ã¢â€â‚¬ Centrado matemÃƒÂ¡tico en pantalla Ã¢â€â‚¬Ã¢â€â‚¬
mv_center(){
    local W txt vis pad
    W=$(mv_cols)
    txt="$1"
    # En modo ASCII se degrada ANTES de medir, para que el centrado siga siendo
    # correcto con el ancho real del texto ya limpio.
    (( ${MV_ASCII:-0} )) && txt=$(mv_san "$txt")
    vis=$(mv_w "$txt")
    # Antes solo se acotaba el relleno a 0 y la linea mas ancha que la
    # pantalla se salia entera: en 40 columnas la banda de contacto se iba a
    # 55. Ahora se recorta al ancho real.
    if (( vis > W )); then txt=$(mv_fit "$txt" "$W"); vis=$(mv_w "$txt"); fi
    pad=$(( (W - vis) / 2 )); (( pad < 0 )) && pad=0
    printf "%*s%b\n" "$pad" "" "$txt"
}

# Ã¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢Â
# GRADIENTES DE COLOR ANSI-256 (SIN DEPENDENCIAS)
# Ã¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢Â

# Ã¢â€â‚¬Ã¢â€â‚¬ Gradiente lineal entre 2 ÃƒÂ­ndices ANSI Ã¢â€â‚¬Ã¢â€â‚¬
mv_grad_txt(){
    local txt="$1" c1="${2:-51}" c2="${3:-33}" bold="${4:-0}" out="" c i n step d ch
    [[ -z "$txt" ]] && return 0
    n=${#txt}
    (( n < 2 )) && n=2
    step=$(( (c2 - c1) * 100 / (n - 1) ))
    for (( i=0; i<n; i++ )); do
        d=$(( c1 + (step * i) / 100 ))
        (( d < 0 )) && d=0; (( d > 255 )) && d=255
        ch="${txt:i:1}"
        [[ "$ch" == '\' ]] && ch='\\'
        if (( bold )); then
            out+="\e[1;38;5;${d}m${ch}"
        else
            out+="\e[38;5;${d}m${ch}"
        fi
    done
    printf "%b%b" "$out" "$MV_R"
}

# Ã¢â€â‚¬Ã¢â€â‚¬ Gradiente Cyber (Cian 51 -> Zafiro 39 -> Violeta 141) Ã¢â€â‚¬Ã¢â€â‚¬
mv_grad_cyber(){
    local txt="$1" bold="${2:-1}" out="" i n seg pals=(51 45 39 33 141 201) j
    [[ -z "$txt" ]] && return 0
    n=${#txt}
    (( n < 1 )) && return 0
    seg=$(( (n + ${#pals[@]} - 1) / ${#pals[@]} ))
    (( seg < 1 )) && seg=1
    j=0
    for (( i=0; i<n; i++ )); do
        if (( i > 0 && i % seg == 0 && j < ${#pals[@]} - 1 )); then
            (( j++ ))
        fi
        if (( bold )); then
            out+="\e[1;38;5;${pals[$j]}m${txt:i:1}"
        else
            out+="\e[38;5;${pals[$j]}m${txt:i:1}"
        fi
    done
    printf "%b%b" "$out" "$MV_R"
}

# Ã¢â€â‚¬Ã¢â€â‚¬ Gradiente ArcoÃƒÂ­ris VIP Ã¢â€â‚¬Ã¢â€â‚¬
mv_grad_rainbow(){
    local txt="$1" bold="${2:-1}" out="" i n seg pal=(203 208 220 82 51 141) j
    [[ -z "$txt" ]] && return 0
    n=${#txt}
    (( n < 1 )) && return 0
    seg=$(( (n + ${#pal[@]} - 1) / ${#pal[@]} ))
    (( seg < 1 )) && seg=1
    j=0
    for (( i=0; i<n; i++ )); do
        if (( i > 0 && i % seg == 0 && j < ${#pal[@]} - 1 )); then
            (( j++ ))
        fi
        if (( bold )); then
            out+="\e[1;38;5;${pal[$j]}m${txt:i:1}"
        else
            out+="\e[38;5;${pal[$j]}m${txt:i:1}"
        fi
    done
    printf "%b%b" "$out" "$MV_R"
}

# Ã¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢Â
# BANNERS Y CABECERAS
# Ã¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢Â

# Ã¢â€â‚¬Ã¢â€â‚¬ Logo 3D Oficial MoviVIP Ã¢â€â‚¬Ã¢â€â‚¬
# Arte de 6 filas de la fuente "big" de figlet: 7 glifos, M O V I V I P.
#
# El anterior tenia 3 filas, o sea solo la mitad superior de las letras. En una
# cabecera tan baja MOVIVIP se leia como un garabato y no parecia un logo. Con
# las 6 filas completas el wordmark tiene cuerpo, y el canto de sombra que se
# dibuja debajo y a la derecha de cada fila le da el volumen.
banner_movivip(){
    local titulo="${1:-}" W i j n w ch canto cara
    local arte=(
        'Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€”   Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€”  Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€”  Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€”   Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€” Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€” Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€”   Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€” Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€” Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€” '
        'Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€” Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€˜ Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€Ã¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€” Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€˜   Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€˜ Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€˜ Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€˜   Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€˜ Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€˜ Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€Ã¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€”'
        'Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€˜ Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€˜   Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€˜ Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€˜   Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€˜ Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€˜ Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€˜   Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€˜ Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€˜ Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€Ã¢â€¢Â'
        'Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€˜Ã¢â€¢Å¡Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€Ã¢â€¢ÂÃ¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€˜ Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€˜   Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€˜ Ã¢â€¢Å¡Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€” Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€Ã¢â€¢Â Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€˜ Ã¢â€¢Å¡Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€” Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€Ã¢â€¢Â Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€˜ Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€Ã¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢Â  '
        'Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€˜ Ã¢â€¢Å¡Ã¢â€¢ÂÃ¢â€¢Â Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€˜ Ã¢â€¢Å¡Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€Ã¢â€¢Â  Ã¢â€¢Å¡Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€Ã¢â€¢Â  Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€˜  Ã¢â€¢Å¡Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€Ã¢â€¢Â  Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€˜ Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€˜      '
        'Ã¢â€¢Å¡Ã¢â€¢ÂÃ¢â€¢Â     Ã¢â€¢Å¡Ã¢â€¢ÂÃ¢â€¢Â  Ã¢â€¢Å¡Ã¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢Â   Ã¢â€¢Å¡Ã¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢Â   Ã¢â€¢Å¡Ã¢â€¢ÂÃ¢â€¢Â   Ã¢â€¢Å¡Ã¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢Â   Ã¢â€¢Å¡Ã¢â€¢ÂÃ¢â€¢Â Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€¢â€˜      '
    )
    # Rampa vertical: cian arriba, violeta abajo.
    #
    # El degradado va por fila y no por caracter a proposito. El arte es
    # multibyte, y en un servidor con LANG=C o POSIX trocear el texto caracter a
    # caracter parte los bytes de los bloques de sombra y el logo sale con
    # basura. Pintar la fila entera de un color no tiene ese problema.
    local degrade=(51 45 39 33 141 201)

    n=${#arte[@]}
    # Igualar anchuras antes de nada. Las filas vienen de 58 y de 59, y sin
    # igualar el canto de sombra descentrada.
    w=0
    for i in "${!arte[@]}"; do
        (( ${#arte[i]} > w )) && w=${#arte[i]}
    done
    for i in "${!arte[@]}"; do
        while (( ${#arte[i]} < w )); do arte[i]+=' '; done
    done

    W=$(mv_cols)
    # Tres motivos para caer al texto plano: terminal estrecha, modo ASCII, o
    # shell sin UTF-8.
    #
    # El tercero se detecta solo, sin adivinar: si el shell no cuenta
    # caracteres sino bytes, las filas miden mas de 59 y el canto saldria
    # descuadrado. Por eso se comprueba w == 59 antes de dibujar nada.
    if (( W >= 62 )) && (( ${MV_ASCII:-0} == 0 )) && (( w == 59 )); then
        for (( i=0; i<=n; i++ )); do
            cara=""; canto=""
            (( i < n )) && cara=$'\e[1;38;5;'"${degrade[i]}"m${arte[i]}"${MV_R}"
            if (( i > 0 )); then
                # El canto son las 2 ultimas columnas de la fila anterior,
                # con los mismos glifos pero en oscuro. Es el lateral del
                # relieve: mismo caracter, misma forma, menos luz.
                for (( j=w-2; j<w; j++ )); do
                    ch="${arte[i-1]:j:1}"
                    if [[ "$ch" == " " ]]; then
                        canto+=" "
                    else
                        canto+="${MV_DARK}${ch}${MV_R}"
                    fi
                done
            fi
            mv_center "${cara}${canto}"
        done
    else
        mv_center "${MV_GLD}${MV_BLD}MOVIVIP${MV_R}"
    fi
    # El titulo se imprime UNA sola vez. Este bloque estaba duplicado literal y
    # por eso "PANEL DE CONTROL" salia dos veces en todas las pantallas que
    # llaman a banner_movivip con argumento.
    if [[ -n "$titulo" ]]; then
        echo ""
        mv_center "${MV_PUR}${MV_G_STAR}${MV_R}  ${MV_GLD}${MV_BLD}${titulo}${MV_R}  ${MV_PUR}${MV_G_STAR}${MV_R}"
    fi
}

mv_banner_3d(){
    banner_movivip "$@"
}

# Ã¢â€â‚¬Ã¢â€â‚¬ Contactos Estilizados en Chips NeÃƒÂ³n Ã¢â€â‚¬Ã¢â€â‚¬
movivip_contacts(){
    local W
    W=$(mv_cols)
    # Los chips largos no caben en movil. mv_center los recorta, pero una linea
    # cortada a mitad de palabra queda peor que una linea por contacto.
    if (( W < 58 )); then
        mv_center "${MV_CYN}Ã°Å¸â€œÂ¢${MV_R} ${MV_WHT}t.me/MoviVIPNetwork${MV_R}"
        mv_center "${MV_PUR}Ã°Å¸â€˜Â¥${MV_R} ${MV_WHT}@MoviVIP${MV_R}"
        mv_center "${MV_GLD}Ã°Å¸Å’Â${MV_R} ${MV_WHT}movivip-network.web.app${MV_R}"
        mv_center "${MV_GRN}Ã°Å¸â€œÂ±${MV_R} ${MV_WHT}+57 311 700 8185${MV_R}"
    elif (( W < 78 )); then
        mv_center "${MV_CYN}Ã°Å¸â€œÂ¢${MV_R} ${MV_WHT}t.me/MoviVIPNetwork${MV_R}  ${MV_DIM}${MV_G_MID}${MV_R}  ${MV_PUR}Ã°Å¸â€˜Â¥${MV_R} ${MV_WHT}@MoviVIP${MV_R}"
        mv_center "${MV_GLD}Ã°Å¸Å’Â${MV_R} ${MV_WHT}movivip-network.web.app${MV_R}  ${MV_DIM}${MV_G_MID}${MV_R}  ${MV_GRN}Ã°Å¸â€œÂ±${MV_R} ${MV_WHT}+57 311 700 8185${MV_R}"
    elif declare -F mv_simple_mode >/dev/null 2>&1 && mv_simple_mode; then
        mv_center "${MV_CYN}Ã°Å¸â€œÂ¢${MV_R} ${MV_WHT}t.me/MoviVIPNetwork${MV_R}  ${MV_DIM}${MV_G_MID}${MV_R}  ${MV_PUR}Ã°Å¸â€˜Â¥${MV_R} ${MV_WHT}@MoviVIP${MV_R}"
        mv_center "${MV_GLD}Ã°Å¸Å’Â${MV_R} ${MV_WHT}movivip-network.web.app${MV_R}  ${MV_DIM}${MV_G_MID}${MV_R}  ${MV_GRN}Ã°Å¸â€œÂ±${MV_R} ${MV_WHT}+57 311 700 8185${MV_R}"
    else
        mv_center "${MV_CYN}Ã°Å¸â€œÂ¢${MV_R} ${MV_WHT}t.me/MoviVIPNetwork${MV_R} ${MV_DIM}${MV_G_MID}${MV_R} ${MV_PUR}Ã°Å¸â€˜Â¥${MV_R} ${MV_WHT}t.me/MoviVIPNet${MV_R} ${MV_DIM}${MV_G_MID}${MV_R} ${MV_GLD}Ã°Å¸Å’Â${MV_R} ${MV_WHT}movivip-network.web.app${MV_R}"
    fi
}

# Ã¢â€â‚¬Ã¢â€â‚¬ Header de Marca Completo (Banner + SubtÃƒÂ­tulo + Chips) Ã¢â€â‚¬Ã¢â€â‚¬
mv_brand_header(){
    local TITLE="$1" SUB="${2:-}"
    mv_line_morado
    banner_movivip "$TITLE"
    [[ -n "$SUB" ]] && mv_center "${MV_DIM}${SUB}${MV_R}"
    echo ""
    movivip_contacts 2>/dev/null || true
    mv_line_morado
}

# Ã¢â€â‚¬Ã¢â€â‚¬ Header EstÃƒÂ¡ndar de SubmenÃƒÂºs Ã¢â€â‚¬Ã¢â€â‚¬
movivip_sub_header(){
    mv_brand_header "$@"
}

# Ã¢â€â‚¬Ã¢â€â‚¬ Header Compacto de Ventana Ã¢â€â‚¬Ã¢â€â‚¬
mv_header(){
    local TITLE="$1" SUB="${2:-}" VER="${3:-v8.2.16}"
    mv_line_morado
    mv_center "${MV_GLD}${MV_G_DIA}${MV_R}  ${MV_BLD}${MV_WHT}${TITLE}${MV_R}  ${MV_DIM}[${MV_R}${MV_CYN2}${VER}${MV_R}${MV_DIM}]${MV_R}  ${MV_GLD}${MV_G_DIA}${MV_R}"
    [[ -n "$SUB" ]] && mv_center "${MV_DIM}${SUB}${MV_R}"
    mv_line_morado
}

mv_gold_header(){
    mv_line_morado
    mv_center "${MV_GLD}${MV_G_H}${MV_G_H} ${MV_G_DIA} M O V I V I P   N E T W O R K ${MV_G_DIA} ${MV_G_H}${MV_G_H}${MV_R}"
    mv_line_morado
}

# Ã¢â€â‚¬Ã¢â€â‚¬ Footer de Despedida VIP Ã¢â€â‚¬Ã¢â€â‚¬
movivip_footer(){
    echo ""
    mv_line_thin
    mv_center "${MV_PUR}${MV_G_IDS}Ã¯Â¾Å¸Ã¯Â¾Å¸Ã¯Â½Â¥${MV_G_IDS}Ã¯Â½Â¥Ã¯Â¾Å¸Ã¯Â¾Å¸${MV_G_IDS} ${MV_R}${MV_CYN2}${MV_G_ST2}${MV_G_IDS}${MV_G_RING}${MV_G_SQRT} ${MV_GLD}${MV_BLD}M O V I V I P   E L I T E${MV_R}${MV_CYN2} ${MV_G_ANG}${MV_G_RING}${MV_G_IDS}${MV_G_ST2}${MV_R} ${MV_PUR}${MV_G_IDS}Ã¯Â¾Å¸Ã¯Â¾Å¸Ã¯Â½Â¥${MV_G_IDS}Ã¯Â½Â¥Ã¯Â¾Å¸Ã¯Â¾Å¸${MV_G_IDS}${MV_R}"
    mv_center "${MV_DIM}Ã°Å¸Â¤Â Socios VIP:${MV_R} ${MV_WHT}t.me/FreeNetZonevip${MV_R} ${MV_DIM}${MV_G_MID}${MV_R} ${MV_WHT}t.me/FreeNetZonevips${MV_R}"
    mv_line_thin
}

# Ã¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢Â
# SEPARADORES Y LÃƒÂNEAS DE CORTE
# Ã¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢Â

# Repite un caracter n veces, en bash puro y sin fork.
#
# Antes cada linea de recuadro hacia "printf 'Ã¢â€â‚¬%.0s' $(seq 1 $n)". Con n=0,
# "seq 1 0" no imprime nada, printf se queda sin argumentos y aun asi escribe
# la parte literal del formato: salia un guion suelto y el panel se iba 2
# columnas de ancho (o 1 si solo un lado daba cero). Era ademas un subshell
# por linea dibujada.
mv_rep(){
    local ch="${1:-${MV_G_H}}" n="${2:-0}" o=""
    (( n < 1 )) && return 0
    (( ${MV_ASCII:-0} )) && ch=$(mv_san "$ch")
    printf -v o '%*s' "$n" ''
    printf '%s' "${o// /$ch}"
}

mv_line(){
    local W ch="${1:-${MV_G_D}}" col="${2:-${MV_CYN}}"
    W=$(mv_cols)
    printf "%b%s%b\n" "$col" "$(mv_rep "$ch" "$W")" "$MV_R"
}

mv_line_thin(){ mv_line "${MV_G_H}" "$MV_DIM"; }
mv_line_morado(){ mv_line "${MV_G_H}" "$MV_PUR"; }
mv_line_double(){ mv_line "${MV_G_D}" "$MV_PUR"; }

mv_sep(){ mv_line "${MV_G_H}" "$MV_PUR"; }
mv_sep_thin(){ mv_line "${MV_G_H}" "$MV_DARK"; }
mv_sep_dots(){
    local W; W=$(mv_cols)
    printf "%b%s%b\n" "$MV_DIM" "$(mv_rep "${MV_G_MID}" "$W")" "$MV_R"
}

mv_sep_gem(){
    local W seg part
    W=$(mv_cols)
    seg=$(( (W - 8) / 3 )); (( seg < 3 )) && seg=3
    part=$(( W - 2*seg - 6 )); (( part < 1 )) && part=1
    printf "%b${MV_G_TL}${MV_G_H}%b${MV_G_DIA}%b" "$MV_PUR" "$MV_GLD" "$MV_DIM"
    mv_rep "${MV_G_H}" "$seg"
    printf "%b${MV_G_DIA}%b" "$MV_CYN2" "$MV_DIM"
    mv_rep "${MV_G_H}" "$seg"
    printf "%b${MV_G_DIA}%b" "$MV_GLD" "$MV_DIM"
    mv_rep "${MV_G_H}" "$part"
    printf "%b${MV_G_H}${MV_G_TR}%b\n" "$MV_PUR" "$MV_R"
}

mv_signature(){ mv_sep_gem; }

mv_sep_rainbow(){
    local W i seg pal=(51 45 39 33 141 220 208) pos
    W=$(mv_cols)
    (( W < 20 )) && W=20
    seg=$(( W / ${#pal[@]} )); (( seg < 2 )) && seg=2
    for (( i=0; i<W; i++ )); do
        pos=$(( i / seg )); (( pos >= ${#pal[@]} )) && pos=$(( ${#pal[@]} - 1 ))
        printf "\e[38;5;${pal[$pos]}m${MV_G_H}"
    done
    printf "%b\n" "$MV_R"
}

# Ã¢â€â‚¬Ã¢â€â‚¬ Wrappers de notificaciÃƒÂ³n (compatibilidad con scripts existentes) Ã¢â€â‚¬Ã¢â€â‚¬
mv_notify_ok()   { mv_section "${MV_GRN}${MV_G_OK} $1${RESET}"; }
mv_notify_err()  { mv_section "${MV_RED}${MV_G_NO} $1${RESET}"; }
mv_notify_warn() { mv_section "${MV_YLW}${MV_G_WARN} $1${RESET}"; }
mv_notify_info() { mv_section "${MV_CYN}${MV_G_INFO} $1${RESET}"; }

# Ã¢â€â‚¬Ã¢â€â‚¬ SecciÃƒÂ³n con estilo Cyber Card Ã¢â€â‚¬Ã¢â€â‚¬
mv_section(){
    local W txt vis dash
    W=$(mv_cols)
    txt="${1:-}"
    vis=$(mv_w "${MV_G_DIA} ${txt}")
    # El formato " Ã¢â€â€šÃ¢â€”â€  TEXTO Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬" tiene 5 caracteres fijos (espacio, Ã¢â€â€š, Ã¢â€”â€ ,
    # espacio y el espacio que separa el texto del relleno). Con - 8 la linea
    # se quedaba en W - 5.
    dash=$(( W - vis - 3 )); (( dash < 1 )) && dash=1
    printf "\n ${MV_PUR}${MV_G_V}${MV_GLD}${MV_G_DIA}${MV_R} ${MV_BLD}${MV_WHT}%s${MV_R} ${MV_DIM}%s${MV_R}\n" \
        "$txt" "$(mv_rep "${MV_G_H}" "$dash")"
}

# Ã¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢Â
# TARJETAS Y PANELES (CARD SYSTEM ROUNDED)
#   Ã¢â€¢Â­Ã¢â€â‚¬Ã¢â€â‚¬ Ã¢â€”â€  TÃƒÂTULO Ã¢â€”â€  Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€¢Â®
#   Ã¢â€â€š Ã°Å¸â€“Â¥ Sistema Ã‚Â· Ubuntu 22.04 LTS (x86_64)                 Ã¢â€â€š
#   Ã¢â€Å“Ã¢â€â‚¬Ã¢â€â‚¬ Ã¢â€”â€  RENDIMIENTO Ã¢â€”â€  Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€Â¤
#   Ã¢â€â€š Ã°Å¸â€™Â¾ RAM [Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€“â€˜Ã¢â€“â€˜Ã¢â€“â€˜Ã¢â€“â€˜] 65%   Ã°Å¸Â§Â  CPU [Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€“Ë†Ã¢â€“â€˜Ã¢â€“â€˜Ã¢â€“â€˜Ã¢â€“â€˜Ã¢â€“â€˜Ã¢â€“â€˜Ã¢â€“â€˜Ã¢â€“â€˜Ã¢â€“â€˜] 25%   Ã¢â€â€š
#   Ã¢â€¢Â°Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€¢Â¯
# Ã¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢Â

mv_panel_width(){
    mv_cols
}

mv_panel_top(){
    local TITLE="$1" PW vis pad rpad tmax
    PW=$(mv_panel_width)
    vis=$(mv_w "$TITLE")
    # "Ã¢â€¢Â­Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€”â€  TITULO Ã¢â€”â€ Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€¢Â®" tiene 10 caracteres fijos: Ã¢â€¢Â­ + 2 guiones + Ã¢â€”â€  + espacio
    # + espacio tras el titulo + Ã¢â€”â€  + 2 guiones + Ã¢â€¢Â®. Antes se restaban 8 y la
    # linea salia dos columnas mas ancha que el panel.
    tmax=$(( PW - 10 )); (( tmax < 4 )) && tmax=4
    if (( vis > tmax )); then TITLE=$(mv_fit "$TITLE" "$tmax"); vis=$(mv_w "$TITLE"); fi
    pad=$(( (PW - vis - 10) / 2 )); (( pad < 0 )) && pad=0
    rpad=$(( PW - vis - 10 - pad )); (( rpad < 0 )) && rpad=0
    printf "%b${MV_G_TL}${MV_G_H}${MV_G_H}%b%s%b${MV_G_DIA} %b%s%b %b${MV_G_DIA}%b%s%b${MV_G_H}${MV_G_H}${MV_G_TR}%b\n" \
        "$MV_PUR" "$MV_DIM" "$(mv_rep "${MV_G_H}" "$pad")" \
        "$MV_GLD" "$MV_BLD$MV_WHT" "$TITLE" "$MV_R" "$MV_GLD" "$MV_DIM" \
        "$(mv_rep "${MV_G_H}" "$rpad")" "$MV_PUR" "$MV_R"
}

mv_prow(){
    local icon="$1" label="$2" val="$3" PW vis pad room
    PW=$(mv_panel_width)
    # Espacio que queda para el valor. Con un valor largo (bytes acumulados,
    # dominios) la fila se salia del panel porque pad solo se acotaba a 0.
    room=$(( PW - 7 - $(mv_w "$icon") - 1 - $(mv_w "$label") - 3 ))
    (( room < 6 )) && room=6
    if (( $(mv_w "$val") > room )); then val=$(mv_fit "$val" "$room"); fi
    vis=$(( $(mv_w "$icon") + 1 + $(mv_w "$label") + 3 + $(mv_w "$val") + 3 ))
    # El formato "Ã¢â€â€š icon label Ã‚Â· val<pad>Ã¢â€â€š" tiene 7 caracteres fijos, no 8:
    # Ã¢â€â€š, el espacio de antes del icono, los dos espacios que rodean al label,
    # el punto medio, el espacio que lo sigue y el Ã¢â€â€š de cierre. Con 8 todas
    # las filas con icono se quedaban en PW - 1.
    pad=$(( PW - vis )); (( pad < 0 )) && pad=0
    printf "%b${MV_G_V} %b%s%b %b%s%b %b${MV_G_MID}%b %b%s%b%*s%b${MV_G_V}%b\n" \
        "$MV_PUR" "$MV_GLD" "$icon" "$MV_R" \
        "$MV_CYN" "$label" "$MV_R" \
        "$MV_DIM" "$MV_R" \
        "$MV_WHT" "$val" "$MV_R" \
        "$pad" "" "$MV_PUR" "$MV_R"
}

mv_prow_bars(){
    local l1="$1" p1="$2" l2="$3" p2="$4" PW b1 b2 vis pad bw
    PW=$(mv_panel_width)
    # mv_progress imprime la barra mas " n%", o sea bw + 5 columnas. Con un
    # ancho fijo de 12 las dos barras no caben en movil y la fila se salia.
    # Se resuelve repartiendo el hueco real y limitando a 12 por barra.
    bw=$(( (PW - 17 - $(mv_w "$l1") - $(mv_w "$l2")) / 2 ))
    (( bw > 12 )) && bw=12
    (( bw < 4 ))  && bw=4
    b1=$(mv_progress "${p1:-0}" 100 "$bw")
    b2=$(mv_progress "${p2:-0}" 100 "$bw")
    vis=$(( $(mv_w "$l1") + 1 + $(mv_w "$b1") + 3 + $(mv_w "$l2") + 1 + $(mv_w "$b2") + 2 ))
    pad=$(( PW - vis )); (( pad < 0 )) && pad=0
    # El formato lleva un %b por color y nada mas.
    #
    # Antes sobraba uno: el %b de mas se comia "$pad", %*s se quedaba sin
    # argumento de ancho y printf soltava "invalid number" al vuelo. Y como la
    # etiqueta y la barra se comian los argumentos equivocados, se veia
    # "CPU  ...  8%51" en vez de la barra de la CPU.
    #
    # Los huecos entre campos son texto literal del formato, nunca %b: un
    # espacio escrito aqui no consume argumentos.
    printf "%b${MV_G_V} %b%s%b %s  %b%s%b %s%*s%b${MV_G_V}%b\n" \
        "$MV_PUR" \
        "$MV_CYN" "$l1" "$MV_R" \
        "$b1" \
        "$MV_CYN" "$l2" "$MV_R" \
        "$b2" \
        "$pad" "" \
        "$MV_PUR" "$MV_R"
}

mv_panel_mid(){
    local TITLE="${1:-}" PW vis pad rpad tmax
    PW=$(mv_panel_width)
    if [[ -n "$TITLE" ]]; then
        vis=$(mv_w "$TITLE")
        tmax=$(( PW - 10 )); (( tmax < 4 )) && tmax=4
        if (( vis > tmax )); then TITLE=$(mv_fit "$TITLE" "$tmax"); vis=$(mv_w "$TITLE"); fi
        pad=$(( (PW - vis - 10) / 2 )); (( pad < 0 )) && pad=0
        rpad=$(( PW - vis - 10 - pad )); (( rpad < 0 )) && rpad=0
        printf "%b${MV_G_LT}${MV_G_H}${MV_G_H}%b%s%b${MV_G_DIA} %b%s%b %b${MV_G_DIA}%b%s%b${MV_G_H}${MV_G_H}${MV_G_RT2}%b\n" \
            "$MV_PUR" "$MV_DIM" "$(mv_rep "${MV_G_H}" "$pad")" \
            "$MV_GLD" "$MV_BLD$MV_WHT" "$TITLE" "$MV_R" "$MV_GLD" "$MV_DIM" \
            "$(mv_rep "${MV_G_H}" "$rpad")" "$MV_PUR" "$MV_R"
    else
        printf "%b${MV_G_LT}%b%s%b${MV_G_RT2}%b\n" "$MV_PUR" "$MV_DIM" "$(mv_rep "${MV_G_H}" $((PW - 2)))" "$MV_PUR" "$MV_R"
    fi
}

mv_panel_bot(){
    local PW
    PW=$(mv_panel_width)
    printf "%b${MV_G_BL}%b%s%b${MV_G_BR}%b\n" "$MV_PUR" "$MV_DIM" "$(mv_rep "${MV_G_H}" $((PW - 2)))" "$MV_PUR" "$MV_R"
}

mv_prow_menu(){
    local txt="$1" PW vis pad
    PW=$(mv_panel_width)
    vis=$(mv_w "$txt")
    pad=$(( PW - vis - 4 )); (( pad < 0 )) && pad=0
    printf "%b${MV_G_V} %b%s%b%*s %b${MV_G_V}%b\n" "$MV_PUR" "$MV_WHT" "$txt" "$MV_R" "$pad" "" "$MV_PUR" "$MV_R"
}

mv_prow_center(){
    local txt="$1" PW vis pad rest
    PW=$(mv_panel_width)
    # El marco interior son PW-2 columnas. Una linea de socios con dos canales
    # se pasaba de largo en movil.
    if (( $(mv_w "$txt") > PW - 2 )); then txt=$(mv_fit "$txt" $(( PW - 2 ))); fi
    vis=$(mv_w "$txt")
    pad=$(( (PW - 2 - vis) / 2 )); (( pad < 0 )) && pad=0
    rest=$(( PW - 2 - vis - pad )); (( rest < 0 )) && rest=0
    printf "%b${MV_G_V}%*s%b%s%b%*s%b${MV_G_V}%b\n" \
        "$MV_PUR" "$pad" "" "$MV_BLD" "$txt" "$MV_R" "$rest" "" "$MV_PUR" "$MV_R"
}

mv_kv(){
    local key="$1" valc="${2:-${MV_WHT}}" val="${3:-}" W kw pad
    W=$(mv_cols)
    kw=14
    pad=$(( W - kw - $(mv_w "$val") - 8 )); (( pad < 1 )) && pad=1
    printf " ${MV_CYN}%-${kw}s${MV_R}${MV_DIM}%s${MV_R}${valc}%s${MV_R}\n" "${key}" \
        "$(mv_rep "${MV_G_MID}" 5)" "$val"
}

# Ã¢â€â‚¬Ã¢â€â‚¬ Badges y Pills NeÃƒÂ³n Ã¢â€â‚¬Ã¢â€â‚¬
mv_pill(){
    local st="$1"
    case "$st" in
        ON|on|active|ACTIVE)
            printf "%b${MV_G_DOT} ON%b" "$MV_GRN" "$MV_R" ;;
        WARN|warn)
            printf "%b${MV_G_HALF} WARN%b" "$MV_GLD" "$MV_R" ;;
        *)
            printf "%b${MV_G_CIRC} OFF%b" "$MV_RED" "$MV_R" ;;
    esac
}

mv_badge(){
    local type="$1" text="$2"
    case "$type" in
        VIP|vip|gold)
            printf "%b[ ${MV_G_BOLT} %s ]%b" "$MV_BG_GLD" "$text" "$MV_R" ;;
        OK|ok|green)
            printf "%b[ ${MV_G_OK} %s ]%b" "$MV_BG_GRN" "$text" "$MV_R" ;;
        FAIL|fail|red)
            printf "%b[ ${MV_G_NO} %s ]%b" "$MV_BG_RED" "$text" "$MV_R" ;;
        CYAN|cyan)
            printf "%b[ ${MV_G_STAR} %s ]%b" "$MV_BG_CYN" "$text" "$MV_R" ;;
        *)
            printf "%b[ %s ]%b" "$MV_BG_PUR" "$text" "$MV_R" ;;
    esac
}

# Ã¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢Â
# BARRAS DE PROGRESO Y EJECUCIÃƒâ€œN SILENCIOSA (CERO FUGAS)
# Ã¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢Â

# Ã¢â€â‚¬Ã¢â€â‚¬ Barra de porcentaje visual suave Ã¢â€â‚¬Ã¢â€â‚¬
mv_progress(){
    local val="${1:-0}" total="${2:-100}" width="${3:-12}"
    local pct f e i color
    (( total < 1 )) && total=1
    pct=$(( val * 100 / total )); (( pct > 100 )) && pct=100; (( pct < 0 )) && pct=0
    f=$(( pct * width / 100 )); e=$(( width - f ))
    if (( pct < 60 )); then color="${MV_GRN}"
    elif (( pct < 85 )); then color="${MV_GLD}"
    else color="${MV_RED}"; fi
    printf "%b" "$color"
    for (( i=0; i<f; i++ )); do printf "${MV_G_FULL}"; done
    printf "%b" "$MV_DARK"
    for (( i=0; i<e; i++ )); do printf "${MV_G_LT2}"; done
    printf "%b %s%3d%%%s" "$MV_R" "$MV_WHT" "$pct" "$MV_R"
}

# Ã¢â€â‚¬Ã¢â€â‚¬ Ejecutor de tareas animado SIN fugas de cÃƒÂ³digo en terminal Ã¢â€â‚¬Ã¢â€â‚¬
mv_fun_bar(){
    local title="$1" cmd="${2:-true}" pid i=0 pct cur wid=16 out_file exit_code=1 sp
    printf "  ${MV_CYN}${MV_G_BOLT} %s${MV_R}\n" "$title"
    out_file=$(mktemp 2>/dev/null || echo "/tmp/mv_exec_$$")
    
    # Ejecuta el comando en subshell 100% silencioso hacia archivo temporal
    eval "$cmd" >"$out_file" 2>&1 &
    pid=$!
    
    # Los frames salen del diccionario central (MV_SPIN), no de literales
    # braille escritos aqui: asi el spinner cae a ASCII en vez de romperse.
    local spin_chars=("${MV_SPIN[@]}")
    while kill -0 "$pid" 2>/dev/null; do
        (( i++ ))
        pct=$(( (i * 4) % 95 + 1 ))
        cur=$(( pct * wid / 100 )); (( cur > wid )) && cur=$wid
        sp="${spin_chars[$(( i % 10 ))]}"
        
        local bar=""
        for (( b=0; b<cur; b++ )); do bar+="${MV_G_FULL}"; done
        for (( b=cur; b<wid; b++ )); do bar+="${MV_G_LT2}"; done
        
        printf "\r  ${MV_CYN}%s${MV_R} [${MV_GRN}%s${MV_DARK}%s${MV_R}] ${MV_GLD}%2d%%${MV_R} " \
            "$sp" "${bar:0:cur}" "${bar:cur}" "$pct"
        sleep 0.08
    done
    
    wait "$pid" 2>/dev/null
    exit_code=$?
    
    local full_bar=""
    for (( b=0; b<wid; b++ )); do full_bar+="${MV_G_FULL}"; done
    
    if (( exit_code == 0 )); then
        printf "\r  ${MV_GRN}${MV_G_OK}${MV_R} [${MV_GRN}%s${MV_R}] ${MV_WHT}100%%${MV_R} ${MV_GRN}[ LISTO ]${MV_R}    \n" "$full_bar"
    else
        printf "\r  ${MV_RED}${MV_G_NO}${MV_R} [${MV_RED}%s${MV_R}] ${MV_WHT}100%%${MV_R} ${MV_RED}[ ERROR ]${MV_R}    \n" "$full_bar"
    fi
    rm -f "$out_file" 2>/dev/null
    return "$exit_code"
}

# Ã¢â€â‚¬Ã¢â€â‚¬ Spinner minimalista para operaciones rÃƒÂ¡pidas Ã¢â€â‚¬Ã¢â€â‚¬
mv_spinner(){
    local title="$1" cmd="${2:-true}" pid i=0 exit_code sp
    local spin_chars=("${MV_SPIN[@]}")
    eval "$cmd" >/dev/null 2>&1 &
    pid=$!
    while kill -0 "$pid" 2>/dev/null; do
        sp="${spin_chars[$(( i % 10 ))]}"
        printf "\r  ${MV_CYN}%s${MV_R} ${MV_WHT}%s...${MV_R} " "$sp" "$title"
        (( i++ )); sleep 0.08
    done
    wait "$pid" 2>/dev/null
    exit_code=$?
    if (( exit_code == 0 )); then
        printf "\r  ${MV_GRN}${MV_G_OK}${MV_R} ${MV_WHT}%s${MV_R} ${MV_GRN}[ OK ]${MV_R}\n" "$title"
    else
        printf "\r  ${MV_RED}${MV_G_NO}${MV_R} ${MV_WHT}%s${MV_R} ${MV_RED}[ FAIL ]${MV_R}\n" "$title"
    fi
    return "$exit_code"
}
