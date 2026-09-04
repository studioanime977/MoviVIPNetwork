#!/bin/bash
#=========================================================
# MoviVIP Network — lib/nav.sh v5.7
# Motor de navegación CON DETECCIÓN AUTOMÁTICA DE PLATAFORMA
#
# Uso en cualquier menú:
#   source "$BASE/lib/nav.sh" 2>/dev/null || true
#   SEL=$(nav_pick "Mensaje:" \
#        "🔐 OpenSSH" \
#        "🚪 Dropbear" \
#        "↩ Regresar")
#   case "$SEL" in 1) ... ;; 2) ... ;; 0|*) back ;; esac
#
#   ── EN PC / SERVIDOR (terminal real) ──
#   • ↑↓ mueven · ←→ saltan de columna (si 2 col)
#   • ENTER selecciona · números + ENTER directos
#   • q / ESC regresan 0
#   • >9 items => 2 columnas automáticas
#   • Todo el UI sale por STDERR => seguro bajo $( )
#
#   ── EN MÓVIL (Termux/UserLAnd/etc) ──
#   • DETECCIÓN AUTOMÁTICA: si el terminal es táctil, se activa
#     el modo SIMPLE que NO lee carácter a carácter (causa de
#     duplicación de dígitos con teclados virtuales).
#   • Muestra items numerados y pide "Opción (número):"
#   • Lee la línea COMPLETA con read -r (modo canónico) → el
#     teclado táctil NO puede duplicar porque el terminal espera
#     el ENTER y procesa el buffer de una sola vez.
#   • Fuerza al teclado táctil a modo numérico (hint invisible).
#=========================================================

# ──────────────────────────────────────────────────────────
# DETECCIÓN DE PLATAFORMA: ¿Estamos en un terminal MÓVIL?
# ──────────────────────────────────────────────────────────
# Termux (Android) define varias de estas variables de entorno.
# UserLAnd / proot también exponen PREFIX bajo /data o /userdata.
# Se priorizan aquí porque son 100% fiables para UNA app concreta.
mv_is_mobile() {
    # 1) Termux clásico
    [[ -n "${TERMUX_VERSION:-}" ]] && return 0
    [[ -n "${TERMUX_APP__PACKAGE_NAME:-}" ]] && return 0
    # 2) PREFIX en /data(/user)  → proot/Termux/UserLAnd
    [[ "${PREFIX:-}" == /data/* ]] && return 0
    # 3) Variables Android genéricas
    [[ -n "${ANDROID_ROOT:-}" ]] && return 0
    [[ -n "${SHELL:-}" && "${SHELL}" == /data/* ]] && return 0
    [[ -d /data/data/com.termux ]] && return 0
    # 4) proot UserLAnd / proot-distro: HOME en /root pero LD_LIBRARY_PATH
    #    apunta a /data o usr/lib de Android; también TERMUX_APK_RELEASE.
    if [[ -n "${LD_LIBRARY_PATH:-}" && "${LD_LIBRARY_PATH}" == *"/data/"* ]]; then
        return 0
    fi
    # 5) Ancho del terminal COMO HERRAMIENTA FINAL (cubre SSH desde móvil).
    #    Un terminal TÁCTIL (móvil) suele tener < 58 columnas porque el
    #    teléfono es vertical. Los escritorios/PC normales usan 80+ cols.
    #    Cuando el ancho es claramente de móvil (< 58) se activa el modo
    #    simple (números sin flechitas), que además es MEJOR en pantallas
    #    estrechas. El umbral 58 NO afecta a sesiones SSH descritorio típicas.
    local _c
    _c=$(tput cols 2>/dev/null || echo 80)
    if [[ "$_c" -gt 0 && "$_c" -lt 58 ]] 2>/dev/null; then
        return 0
    fi
    return 1
}

# Variable global cacheados (evita recalcular en cada llamada)
# Override manual opcional: MV_SIMPLE=1 fuerza modo simple incluso en PC;
# MV_SIMPLE=0 fuerza modo avanzado (flechas) aunque el ancho sea móvil.
MV_MOBILE="${MV_MOBILE:-}"
if [[ -z "$MV_MOBILE" ]]; then
    if [[ "${MV_SIMPLE:-}" == "1" ]]; then
        MV_MOBILE=1
    elif [[ "${MV_SIMPLE:-}" == "0" ]]; then
        MV_MOBILE=0
    elif mv_is_mobile; then
        MV_MOBILE=1
    else
        MV_MOBILE=0
    fi
    export MV_MOBILE
fi

# ¿Modo simple (móvil)?
mv_simple_mode() { [[ "${MV_MOBILE:-0}" == "1" ]]; }

#=========================================================
# nav_pick_simple — selector NUMÉRICO para terminales MÓVILES.
#
# POR QUÉ ES A PRUEBA DE BUG:
#   El modo interactivo de nav_pick lee carácter a carácter con
#   `read -rsn1` (modo no-canónico). En teclados táctiles el ACK
#   del toque llega DUPLICADO o con retardo, lo que hace que un
#   simple "1" se convierta en "11" y rompa la selección.
#
#   Aquí usamos `read -r` (modo CANÓNICO): el teclado espera el
#   ENTER y el terminal entrega la LÍNEA COMPLETA de una vez.
#   El toque táctil ya NO puede duplicar el dígito en el buffer,
#   porque el terminal no procesa nada hasta pulsar ENTER.
#
#   Muestra los items numerados [1..N] y "0" para volver.
#=========================================================
nav_pick_simple() {
    local PROMPT="${1:-➜ Seleccione una opción}"
    shift
    local -a L=("$@")
    local N=${#L[@]}
    (( N == 0 )) && { echo 0; return; }

    local GOLD="\033[1;93m" CYAN="\033[1;96m" GRAY="\033[1;90m" WHITE="\033[1;97m" R="\033[0m"

    # ── Mostrar items numerados (modo lista simple, 1 columna) ──
    # Se detecta si el ÚLTIMO item es "volver" para no duplicar el [0].
    local _has_back=0
    local _last="${L[N-1]}"
    if [[ "$_last" == *↩* || "$_last" == *Salir* || "$_last" == *Volver* ]]; then
        _has_back=1
    fi
    local i
    for ((i=1; i<=N; i++)); do
        local LBL="${L[i-1]}" NUM
        if [[ "$LBL" == *↩* || "$LBL" == *Salir* || "$LBL" == *Volver* ]]; then
            NUM="0"
        else
            NUM="$i"
        fi
        printf >&2 "  ${GOLD}[%s]${R}  %b${R}\n" "$NUM" "$LBL"
    done
    # Si NO había un "volver" en la lista, añadir [0] como ayuda
    (( _has_back == 0 )) && printf >&2 "  ${GOLD}[0]${R}  ${GRAY}↩ ${WHITE}Cancelar/Salir${R}\n"
    printf >&2 "  ${GRAY}──────────────────────────────────────────────${R}\n"

    local SELX
    while :; do
        printf >&2 '  %b \033[1;93m%s\033[0m ' "$PROMPT" ""
        IFS= read -r SELX || { echo 0; return 0; }
        # Quitar espacios/control
        SELX=$(printf '%s' "$SELX" | tr -d '\r\n\t ')
        if [[ -z "$SELX" ]]; then
            printf >&2 "  ${GRAY}(número entre 0 y %s)${R}\n" "$N"
            continue
        fi
        if [[ "$SELX" =~ ^[0-9]+$ ]]; then
            if (( SELX >= 1 && SELX <= N )); then
                echo "$SELX"
                return 0
            elif (( SELX == 0 )); then
                echo 0
                return 0
            else
                printf >&2 "  ${GRAY}(número entre 0 y %s)${R}\n" "$N"
            fi
        else
            printf >&2 "  ${R}\033[1;91m✘ Introduce solo números${R}\n"
        fi
    done
}

#=========================================================
# mv_enter — "Presione ENTER para continuar" SEGURO para móvil.
#   En PC: espera una tecla cualquiera (read -sn1), cómodo.
#   En MÓVIL: usa read -r canónico (esperar Enter) para evitar
#   que el teclado táctil duplique/deseche la pulsación.
#=========================================================
mv_enter() {
    local MSG="${1:-${MSG_ENTER:-Presione ENTER para continuar...}}"
    if mv_simple_mode; then
        printf >&2 '%s' "$MSG"
        IFS= read -r _
    else
        read -rn1 -s -p "$MSG"
        printf >&2 "\n"
    fi
}

#=========================================================
# mv_prompt_num — input NUMÉRICO canónico multiplataforma.
#   Muestra prompt y lee SOLO dígitos con read -r (canónico).
#   Seguro en móvil: el teclado táctil entrega la línea al dar
#   ENTER, sin duplicación. Devuelve el número (o $DEFAULT).
#   ($1=prompt $2=default $3=min $4=max)
#=========================================================
mv_prompt_num() {
    local PROMPT="$1" DEFAULT="$2" MIN="${3:-0}" MAX="${4:-2147483647}"
    local VAL
    while :; do
        printf >&2 '%b  ' "$PROMPT"
        IFS= read -r VAL || { echo "${DEFAULT:-}"; return 1; }
        VAL=$(printf '%s' "$VAL" | tr -d '\r\n\t ')
        if [[ -z "$VAL" && -n "$DEFAULT" ]]; then
            echo "$DEFAULT"; return 0
        fi
        [[ "$VAL" =~ ^[0-9]+$ ]] || { printf >&2 '  \033[1;91m✘ Solo números\033[0m\n'; continue; }
        if (( VAL >= MIN && VAL <= MAX )); then
            echo "$VAL"; return 0
        fi
        printf >&2 '  \033[1;93m→ Entre %s y %s\033[0m\n' "$MIN" "$MAX"
    done
}

# ── Datos de contacto oficiales MoviVIP Network ──
MOVIVIP_CANAL="https://t.me/MoviVIPNetwork"
MOVIVIP_GRUPO="https://t.me/MoviVIPNet"
MOVIVIP_SOPORTE="https://t.me/MoviVIP"
MOVIVIP_WEB="https://movivip-network.web.app"
MOVIVIP_WA="+57 311 700 8185"
MOVIVIP_SOCIO_CANAL="https://t.me/FreeNetZonevip"
MOVIVIP_SOCIO_GRUPO="https://t.me/FreeNetZonevips"

# Footer de contacto — SOLO para pantallas de salida/despedida
movivip_footer() {
    local GRAY="\e[1;90m" WHITE="\e[1;97m" CYAN="\e[1;96m" RESET="\e[0m"
    echo ""
    echo -e "${GRAY} ──────────────────────────────────────────────────────────${RESET}"
    echo -e " ${CYAN}📢${RESET}${WHITE} Canal:${RESET} t.me/MoviVIPNetwork ${GRAY}|${RESET} ${WHITE}Grupo:${RESET} t.me/MoviVIPNet ${GRAY}|${RESET} ${WHITE}@MoviVIP${RESET}"
    echo -e " ${CYAN}🌐${RESET}${WHITE} Web:${RESET} movivip-network.web.app ${GRAY}|${RESET} ${CYAN}📱${RESET}${WHITE} WhatsApp:${RESET} +57 311 700 8185"
    echo -e " ${GRAY}🤝 Socios:${RESET} t.me/FreeNetZonevip ${GRAY}·${RESET} t.me/FreeNetZonevips"
}

# ── Contactos compactos (2 líneas) para headers de submenús ──
movivip_contacts() {
    local GRAY="\e[1;90m" WHITE="\e[1;97m" CYAN="\e[1;96m" RESET="\e[0m"
    echo -e " ${GRAY}📢${RESET} ${WHITE}t.me/MoviVIPNetwork${RESET} ${GRAY}·${RESET} ${WHITE}t.me/MoviVIPNet${RESET} ${GRAY}·${RESET} ${WHITE}@MoviVIP${RESET}"
    echo -e " ${GRAY}🌐${RESET} ${WHITE}movivip-network.web.app${RESET} ${GRAY}·${RESET} ${CYAN}📱${RESET} ${WHITE}+57 311 700 8185${RESET}"
}

# ── Header estándar para SUBMENÚS — estilo NEBULA v6 (centrado dinámico) ──
movivip_sub_header() {
    local TITLE="$1"
    # Design System NEBULA si está disponible
    if declare -F mv_center >/dev/null 2>&1; then
        mv_line_thin
        mv_center "${MV_CYN}◆${MV_R} ${MV_BLD}${MV_WHT}${TITLE}${MV_R}"
        movivip_contacts
        mv_line_thin
    else
        local CYAN="\e[1;96m" WHITE="\e[1;97m" RESET="\e[0m"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
        echo -e " ${WHITE}${TITLE}${RESET}"
        echo -e "$(trx ' 📢 t.me/MoviVIPNetwork · t.me/MoviVIPNet · @MoviVIP')"
        echo -e "$(trx ' 🌐 movivip-network.web.app · 📱 +57 311 700 8185')"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    fi
}

#=========================================================
# nav_pick — selector interactivo interactivo 2 columnas (2 columnas)
#   [01] ➮ Opcion A     [11] ➮ Opcion K    ← normal
#   [02] ➤ Opcion B     [12] ➮ Opcion L    ← activa (barra cyan)
#   [00] ➮ Regresar                        ← última opción siempre [00]
#   • ↑↓ mueven · ←→ saltan de columna · ENTER elige
#   • números+ENTER directos · q/ESC regresan 0
#   • >9 items => 2 columnas automáticas
#   • hint de teclas bajo el prompt
#
#   ── MÓVIL (MV_MOBILE=1): usa nav_pick_simple — input numérico
#      directo sin flechitas, SIN duplicación de dígitos.
#=========================================================
nav_pick() {
    # En móvil → delegar al modo SIMPLE (sin teclas, solo números)
    if mv_simple_mode; then
        nav_pick_simple "$@"
        return $?
    fi

    local PROMPT="${1:-➜ Seleccione una opción}"
    shift
    local -a L=("$@")
    local N=${#L[@]}
    (( N == 0 )) && { echo 0; return; }

    local SEL=1 BUF="" i r li ri K K2 OUT="" NUM
    local CYAN="\033[1;96m" GOLD="\033[1;93m" GRAY="\033[1;90m" R="\033[0m"

    # Layout: 1 o 2 columnas
    local COLS=1 ROWS=$N COLW=34
    (( N > 9 )) && { COLS=2; ROWS=$(( (N + 1) / 2 )); }

    # Hint de teclas según layout
    local HINT="↑↓ mover · números directos · ENTER elegir"
    (( COLS == 2 )) && HINT="↑↓ mover · ←→ columna · números directos · ENTER elegir"

    # Renderiza UN item rellenando su columna completa
    _np_item(){
        local i=$1
        local LBL="${L[i-1]}" NUM pad
        if [[ "$LBL" == *↩* || "$LBL" == *Salir* ]]; then
            NUM="00"
        else
            NUM=$(printf '%02d' "$i")
        fi
        pad=$(( COLW - 7 - ${#LBL} )); (( pad < 0 )) && pad=0
        if (( i == SEL )); then
            printf >&2 "\033[1;30;106m [%s] \342\236\244 %b%*s \033[0m" "$NUM" "$LBL" "$pad" ""
        else
            printf >&2 " ${GOLD}[%s]${R} ${CYAN}\342\236\256${R} %b%*s" "$NUM" "$LBL" "$pad" ""
        fi
    }

    # Renderiza el bloque completo ($1 = "sel" | "clean")
    _np_render(){
        local MODE="$1"
        for ((r=0; r<ROWS; r++)); do
            li=$((r+1)); ri=$((ROWS+r+1))
            if [[ "$MODE" == "clean" ]]; then
                local SAVE=$SEL; SEL=-1
                _np_item "$li"
                SEL=$SAVE
            else
                _np_item "$li"
            fi
            if (( COLS == 2 && ri <= N )); then
                if [[ "$MODE" == "clean" ]]; then
                    local SAVE2=$SEL; SEL=-2
                    _np_item "$ri"
                    SEL=$SAVE2
                else
                    _np_item "$ri"
                fi
            fi
            printf >&2 '\033[K\n'
        done
    }

    # ── Redibujado PORTABLE (PC + MÓVIL) ──
    # El método clásico \033[s / \033[u (guardar/restaurar cursor) NO es fiable
    # en terminales móviles: al restaurar la posición, el móvil NO sobrescribe,
    # imprime un bloque NUEVO debajo → "menú duplicado" con el número marcado.
    # Solución 100% ANSI: subir EXACTAMENTE el alto del bloque con \033[<n>A y
    # borrar hasta el final con \033[J. Esto funciona en cualquier terminal.
    # Alto del bloque por render: ROWS opciones + 1 sep.sup + 1 sep.inf + 1
    # prompt + 1 hint = ROWS + 4. Se usa igual en el cierre (clean).
    local _blk=$(( ROWS + 4 ))
    local _first=1

    # ── Drenaje de buffer residual (teclado MÓVIL) ──
    # Al abrir el menú, el teclado táctil suele dejar caracteres basura en el
    # buffer del terminal (de tocar/escribir antes). Si no se limpia, nav_pick
    # los lee de inmediato y los interpreta como una selección directa → ejecuta
    # una opción sin que el usuario la confirme. Aquí se descarta todo lo que
    # hubiera quedado pendiente (timeout 0.15s si no hay nada).
    while IFS= read -rsn1 -t 0.15 _flush 2>/dev/null; do :; done

    # Redibuja el bloque: sube el alto previo, borra hacia abajo y re-renderiza.
    _np_redraw(){
        if (( _first )); then
            _first=0                      # primera vez: no subir (cursor ya al inicio)
        else
            printf >&2 "\033[${_blk}A\033[J"
        fi
        printf >&2 " ${GRAY}──────────────────────────────────────────────────────────${R}\n"
        _np_render sel
        printf >&2 " ${GRAY}──────────────────────────────────────────────────────────${R}\n"
        printf >&2 '  %b \033[1;93m%s\033[0m\033[K\033[0m\n' "$PROMPT" "${BUF:+[${BUF}] }"
        printf >&2 '  \033[1;90m%b\033[0m\033[K\n' "$HINT"
    }

    while :; do
        _np_redraw

        IFS= read -rsn1 K || { OUT=0; break; }   # EOF => salir

        if [[ "$K" == $'\x1b' ]]; then
            # Leer el resto de la secuencia de escape con timeout más tolerante
            # (0.15s) para terminales móviles lentos que envían bytes en bloques
            # separados. Un ESC "suelto" (sin [A/B/C/D) en móviles normalmente es
            # ruido de scroll → se ignora en vez de salir del menú.
            if read -rsn2 -t 0.15 K2; then
                case "$K2" in
                    '[A') (( SEL > 1 ))    && (( SEL-- )) ;;
                    '[B') (( SEL < N ))    && (( SEL++ )) ;;
                    '[C') (( SEL + ROWS <= N )) && SEL=$(( SEL + ROWS )) ;;
                    '[D') (( SEL - ROWS >= 1 )) && SEL=$(( SEL - ROWS )) ;;
                    '['*)                               # [1~ [5~ [6~ etc (Home/PageUp/PageDown/scroll) → ignorar
                        : ;;
                    *)                                  # Otras teclas especiales → ignorar (no salir)
                        while read -rsn1 -t 0.02 _z 2>/dev/null; do :; done
                        ;;
                esac
            else
                # ESC suelto sin código posterior: en móvil, probablemente ruido
                # de scroll/touch. Se ignora (no sale) para no "no dejar hacer nada".
                :
            fi
        elif [[ -z "$K" ]]; then                    # ENTER
            if [[ -n "$BUF" ]]; then
                if [[ "$BUF" =~ ^[0-9]+$ ]]; then
                    if (( BUF == 0 )); then OUT=0
                    elif (( BUF >= 1 && BUF <= N )); then OUT=$BUF; SEL=$BUF
                    else BUF=""; continue
                    fi
                else
                    BUF=""
                fi
                [[ -n "$OUT" ]] && break
            else
                OUT=$SEL
                break
            fi
        elif [[ "$K" == "q" || "$K" == "Q" ]]; then
            OUT=0; break
        elif [[ "$K" == $'\x7f' || "$K" == $'\b' ]]; then
            BUF="${BUF%?}"                          # Backspace borra último dígito
        elif [[ "$K" =~ ^[0-9]$ ]]; then
            # ── Anti-duplicado del teclado numérico MÓVIL ──
            # Al tocar un número en el celular, el teclado táctil dispara un ECO
            # DUPLICADO del mismo dígito (y a veces un fantasma distinto) en la
            # MISMA ráfaga. Sin protección, "1" se vuelve "11" y rompe la
            # selección. Solución: tras el dígito real, se DRENA toda la ráfaga
            # de caracteres espurios con un bucle (timeout 0.15s por char).
            # El 2º dígito real de un número de 2 cifras ("12") llega con pausa
            # humana >0.15s, así no se consume.
            local _d=""
            while IFS= read -rsn1 -t 0.15 _d 2>/dev/null; do :; done
            (( ${#BUF} < 3 )) && BUF+="$K"
        fi
    done

    # Redibujar bloque limpio (sin highlight) al terminar — mismo mecanismo portable
    printf >&2 "\033[${_blk}A\033[J"
    printf >&2 " ${GRAY}──────────────────────────────────────────────────────────${R}\n"
    _np_render clean
    printf >&2 " ${GRAY}──────────────────────────────────────────────────────────${R}\n"
    printf >&2 '  %b \033[1;93m%s\033[0m\033[K\033[0m\n' "$PROMPT" "${BUF:+[${BUF}] }"
    printf >&2 '  \033[1;90m%b\033[0m\033[K\n' "$HINT"

    echo "${OUT:-0}"
}

# Pantalla de SOPORTE COMPLETA — NEBULA v6
# Incluye: contactos oficiales, socios, SOs de servidor soportados,
# requisitos, clientes compatibles por plataforma, matriz protocolo/
# puerto, horarios y estado del motor apiAccess (socket /tmp/admAPI.sock)
movivip_soporte_screen() {
    clear
    local W pad line
    W=$(mv_cols 2>/dev/null || echo 80)

    # ── Estado apiAccess (motor de bots/HWID avanzado) ──
    local API_ST="OFF" API_TXT="no requerido"
    if [[ -S /tmp/admAPI.sock ]]; then
        local RESP
        RESP=$(timeout 3 bash -c 'echo "/help" | nc -U /tmp/admAPI.sock 2>/dev/null' | head -1)
        [[ -n "$RESP" ]] && { API_ST="ON"; API_TXT="motor activo"; } || API_TXT="socket sin respuesta"
    fi

    mv_header "Soporte MoviVIP" "Centro de Ayuda · Compatibilidad · Contactos" "v${VERSION:-6.0}"

    # ── CONTACTO OFICIAL ──
    mv_section "${SUP_OFFICIAL:-📞 CONTACTO OFICIAL}"
    printf "   ${MV_CYN}📢 ${SUP_CANAL:-Canal oficial} ....... ${MV_WHT}t.me/MoviVIPNetwork${MV_R}\n"
    printf "   ${MV_CYN}👥 ${SUP_GRUPO:-Grupo oficial} ........ ${MV_WHT}t.me/MoviVIPNet${MV_R}\n"
    printf "   ${MV_GRN}💬 ${SUP_SOPORTE:-Soporte directo} ...... ${MV_WHT}@MoviVIP  (t.me/MoviVIP)${MV_R}\n"
    printf "   ${MV_CYN}🌐 ${SUP_WEB:-Sitio web} ............ ${MV_WHT}https://movivip-network.web.app${MV_R}\n"
    printf "   ${MV_GRN}📱 WhatsApp ............. ${MV_WHT}+57 311 700 8185${MV_R}\n"

    # ── SOCIOS ──
    mv_section "${SUP_AMIGOS:-🤝 CANALES AMIGOS (FreeNetZone)}"
    printf "   ${MV_DIM}${SUP_CANAL:-Canal}${MV_R} ${MV_WHT}t.me/FreeNetZonevip${MV_R}   ${MV_DIM}·${MV_R}  ${MV_DIM}${SUP_GRUPO:-Grupo}${MV_R} ${MV_WHT}t.me/FreeNetZonevips${MV_R}\n"

    # ── COMPATIBILIDAD TOTAL ──
    mv_section "${SUP_COMPAT:-🖥️ COMPATIBILIDAD TOTAL (SERVIDOR)}"
    printf "   ${MV_DIM}SO:${MV_R}  ${MV_GRN}✅${MV_R} ${MV_WHT}Ubuntu 20.04·22.04·24.04${MV_R}   ${MV_GRN}✅${MV_R} ${MV_WHT}Debian 11·12${MV_R}\n"
    printf "   ${MV_DIM}Arq:${MV_R} ${MV_GRN}✅${MV_R} ${MV_WHT}x86_64/amd64${MV_R}  ${MV_GRN}✅${MV_R} ${MV_WHT}ARM64/aarch64${MV_R}  ${MV_GLD}⚠️${MV_R} ${MV_DIM}ARMv7/i386${MV_R}\n"
    printf "   ${MV_DIM}Nube:${MV_R} ${MV_CYN}☁${MV_R} ${MV_WHT}Oracle Cloud${MV_R} ${MV_DIM}(A1/Flex)${MV_R} · ${MV_WHT}AWS Graviton${MV_R} · ${MV_WHT}Google Cloud${MV_R}\n"
    printf "        ${MV_WHT}Azure${MV_R} · ${MV_WHT}DigitalOcean${MV_R} · ${MV_WHT}Vultr${MV_R} · ${MV_WHT}Hetzner${MV_R} · ${MV_WHT}Contabo${MV_R}\n"
    printf "   ${MV_DIM}Virtualización: KVM ✅ · LXC/OpenVZ 7+ parcial${MV_R}\n"
    printf "   ${MV_DIM}Nota: motor API Access (bots) = binario x86_64${MV_R} ${MV_DIM}(ARM vía qemu)${MV_R}\n"

    # ── REQUISITOS ──
    mv_section "${SUP_REQ:-⚙️ REQUISITOS DEL SERVIDOR}"
    printf "   ${MV_DIM}•${MV_R} Acceso ${MV_WHT}root${MV_R} vía SSH          ${MV_DIM}•${MV_R} RAM mínima ${MV_WHT}1 GB${MV_R} ${MV_DIM}(ideal 2 GB)${MV_R}\n"
    printf "   ${MV_DIM}•${MV_R} Disco libre ${MV_WHT}10 GB${MV_R}              ${MV_DIM}•${MV_R} Puerto ${MV_WHT}22${MV_R} + puertos de protocolos abiertos\n"
    printf "   ${MV_DIM}•${MV_R} Dominio opcional ${MV_DIM}(Cloudflare/No-IP integrados en el panel)${MV_R}\n"

    # ── CLIENTES ──
    mv_section "${SUP_CLIENTES:-📱 CLIENTES COMPATIBLES (USUARIO FINAL)}"
    printf "   ${MV_MAG}Android${MV_R} ${MV_WHT}HTTP Custom · HTTP Injector · NPV Tunnel · Spark VPN${MV_R}\n"
    printf "   ${MV_DIM}        SagerNet · v2rayNG · NekoBox · clientes Hysteria${MV_R}\n"
    printf "   ${MV_MAG}iOS${MV_R}     ${MV_WHT}Shadowrocket · Stash · FoXray${MV_R}\n"
    printf "   ${MV_MAG}Windows${MV_R} ${MV_WHT}OpenVPN GUI · WireGuard · NekoRay · Clash Verge/Mihomo${MV_R}\n"
    printf "   ${MV_MAG}Linux${MV_R}   ${MV_WHT}openvpn · wireguard-tools · xray-core · clash/mihomo${MV_R}\n"

    # ── PROTOCOLOS ──
    mv_section "${SUP_PROTO:-🔌 PROTOCOLOS Y PUERTOS DEL PANEL}"
    printf "   🔐 OpenSSH ${MV_DIM}[22]${MV_R}   🚪 Dropbear ${MV_DIM}[90·109·143]${MV_R}   🔒 SSL/TLS ${MV_DIM}[443]${MV_R}\n"
    printf "   🌐 SlowDNS ${MV_DIM}[53·5300]${MV_R} ⚡ BadVPN ${MV_DIM}[7200·7300]${MV_R}  🚀 UDP Custom ${MV_DIM}[2100]${MV_R}\n"
    printf "   ☁️ Xray ${MV_DIM}[VLESS·VMess·Trojan WS/TLS/gRPC · 443]${MV_R}\n"
    printf "   🚀 Hysteria ${MV_DIM}[UDP]${MV_R}  📦 OpenVPN ${MV_DIM}[1194]${MV_R}  📦 ZiVPN ${MV_DIM}[UDP 5667]${MV_R}\n"

    # ── HORARIO + MOTOR ──
    mv_section "${SUP_HORARIO:-🕐 HORARIO DE ATENCIÓN}"
    printf "   ${MV_WHT}Lunes a Sábado${MV_R} ${MV_DIM}·${MV_R} ${MV_WHT}8:00 – 22:00${MV_R} ${MV_DIM}(GMT-5 Colombia)${MV_R}\n"
    printf "   ${MV_DIM}${SUP_RESP_PROM:-Respuesta promedio:}${MV_R} ${MV_GRN}< 24 horas${MV_R}\n"

    mv_section "${SUP_MOTOR:-🧩 MOTOR APIACCESS (integración bots)}"
    printf -v line "   Estado: "; printf "%b" "$line"; mv_pill "$API_ST"; printf "  ${MV_DIM}%s${MV_R}\n" "$API_TXT"
    printf "   ${MV_DIM}Socket${MV_R} ${MV_WHT}/tmp/admAPI.sock${MV_R} ${MV_DIM}· Instalar/reparar:${MV_R} ${MV_CYN}Herramientas → [API Access]${MV_R}\n"

    echo ""
    movivip_footer
    read -rp "$(echo -e "${MV_CYN}➜ ${MV_WHT}${SUP_ENTER:-ENTER para regresar}${MV_R}")"
}

#=========================================================
# CARGA FINAL del Design System NEBULA — SIEMPRE al final de
# nav.sh para que sus funciones (contacts/footer/sub_header)
# SOBRESCRIBAN las versiones legacy de arriba.
# BASE con fallback para source independiente (soporte, bots).
#=========================================================
BASE="${BASE:-/etc/movivip}"
if [[ -f "$BASE/lib/ui.sh" ]]; then
    source "$BASE/lib/ui.sh" 2>/dev/null || true
fi
