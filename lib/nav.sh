#!/bin/bash
#=========================================================
# MoviVIP Network — lib/nav.sh v5.6
# Motor de navegación con FLECHITAS estilo ADMRufu
#
# Uso en cualquier menú:
#   source "$BASE/lib/nav.sh" 2>/dev/null || true
#   SEL=$(nav_pick "Mensaje:" \
#        "🔐 OpenSSH" \
#        "🚪 Dropbear" \
#        "↩ Regresar")
#   case "$SEL" in 1) ... ;; 2) ... ;; 0|*) back ;; esac
#
#   • ↑↓ mueven · ←→ saltan de columna (si 2 col)
#   • ENTER selecciona · números + ENTER directos
#   • q / ESC regresan 0
#   • >9 items => 2 columnas automáticas
#   • Todo el UI sale por STDERR => seguro bajo $( )
#=========================================================

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
        echo -e " 📢 t.me/MoviVIPNetwork · t.me/MoviVIPNet · @MoviVIP"
        echo -e " 🌐 movivip-network.web.app · 📱 +57 311 700 8185"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    fi
}

#=========================================================
# nav_pick — selector interactivo ESTILO ADMRUfu (2 columnas)
#   [01] ➮ Opcion A     [11] ➮ Opcion K    ← normal
#   [02] ➤ Opcion B     [12] ➮ Opcion L    ← activa (barra cyan)
#   [00] ➮ Regresar                        ← última opción siempre [00]
#   • ↑↓ mueven · ←→ saltan de columna · ENTER elige
#   • números+ENTER directos · q/ESC regresan 0
#   • >9 items => 2 columnas automáticas
#   • hint de teclas bajo el prompt
#=========================================================
nav_pick() {
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

    printf >&2 '\033[s'                       # ancla ANTES del bloque

    while :; do
        printf >&2 '\r\033[u'
        printf >&2 " ${GRAY}──────────────────────────────────────────────────────────${R}\n"
        _np_render sel
        printf >&2 " ${GRAY}──────────────────────────────────────────────────────────${R}\n"
        printf >&2 '  %b \033[1;93m%s\033[0m\033[K\033[0m\n' "$PROMPT" "${BUF:+[${BUF}] }"
        printf >&2 '  \033[1;90m%b\033[0m\033[K\n' "$HINT"

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
            (( ${#BUF} < 3 )) && BUF+="$K"
        fi
    done

    # Redibujar bloque limpio (sin highlight) al terminar
    printf >&2 '\r\033[u'
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
