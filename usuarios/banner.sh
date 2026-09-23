#!/bin/bash
#==================================================
# MoviVIP Network
# Banner SSH / Dropbear (HTML v3.1 - Estructura exacta usuario)
#==================================================

BASE="/etc/movivip"
CONFIG="$BASE/config.conf"
[[ -f "$CONFIG" ]] && source "$CONFIG"

if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)" 2>/dev/null || true
fi

if [[ -f "$BASE/lib/ui.sh" ]]; then
    source "$BASE/lib/ui.sh"
else
    RESET="\e[0m"; GREEN="\e[1;92m"; RED="\e[1;91m"; YELLOW="\e[1;93m"
    CYAN="\e[1;96m"; BLUE="\e[1;94m"; WHITE="\e[1;97m"; GRAY="\e[1;90m"
    MAGENTA="\e[1;95m"
fi

BANNER="/etc/issue.net"
SSHD="/etc/ssh/sshd_config"
DROPBEAR="/etc/default/dropbear"

SELLO_OFF=0

detectar_sello_off() {
    local FP_VALID=0 FP_TIPO="" FP_PLAN=""
    if [[ -f "$BASE/lib/firebase-plan.sh" ]]; then
        source "$BASE/lib/firebase-plan.sh" 2>/dev/null
        firebase_plan "" 2>/dev/null
    fi
    [[ -z "$FP_TIPO" && -f "$BASE/licencia.conf" ]] && source "$BASE/licencia.conf" 2>/dev/null
    case "${FP_TIPO:-$(echo ${TIPO:-} | tr '[:upper:]' '[:lower:]')}" in
        admin|superadmin|super) SELLO_OFF=1 ;;
    esac
    case "${FP_PLAN:-$(echo ${PLAN:-} | tr '[:upper:]' '[:lower:]')}" in
        super|vitalicio|empresarial) SELLO_OFF=1 ;;
    esac
}

applying_sello() {
    [[ ! -f "$BANNER" ]] && return 0
    detectar_sello_off
    if [[ "$SELLO_OFF" != "1" ]]; then
        # Cliente normal: FORZAR emoji grande + sello DENTRO de la estructura HTML
        # (antes de </span></div>, NO fuera de </html>)
        if grep -q '</span></div>' "$BANNER"; then
            local TMP="$BANNER.tmp"
            # Reinsertar emoji grande 🐉 + sello ANTES de </span></div> (DENTRO del HTML)
            if ! grep -q "<font color='#FFD700'><big><big><big>🐉</big></big></big></font>" "$BANNER"; then
                sed "s|</span></div>|<font color='#FFD700'><big><big><big>🐉</big></big></big></font><br>\n<font color=\"#00ffff\"><small><i>🛡SISTEMA PROTEGIDO POR MOVIVIP NETWORK🛡</i></small></font>\n</span></div>|" "$BANNER" > "$TMP" && mv "$TMP" "$BANNER"
            fi
        fi
    fi
    # Si ES admin (SELLO_OFF=1), NO tocar nada: pueden editar/borrar libremente
}

detectar_sello_off

if ! declare -F trx >/dev/null 2>&1; then trx() { printf '%%s' "$1"; }; fi

while true; do
    clear
    echo ""
    echo -e "${CYAN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${RESET}"
    echo -e "${CYAN}┃  📢 BANNER SSH / DROPBEAR (HTML v3.1)              ┃${RESET}"
    echo -e "${CYAN}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${RESET}"
    echo ""
    echo -e "  ${GREEN}[1]${WHITE} ✨ Crear nuevo Banner (HTML estructura exacta)${RESET}"
    echo -e "  ${GREEN}[2]${WHITE} 👁 Ver Banner actual${RESET}"
    echo -e "  ${GREEN}[3]${WHITE} ✏️ Editar Banner (nano)${RESET}"
    echo -e "  ${GREEN}[4]${WHITE} 🗑 Eliminar Banner${RESET}"
    echo -e "  ${GREEN}[0]${WHITE} ↩ Regresar${RESET}"
    echo ""
    read -rp "$(echo -e "${GREEN}Seleccione una opción:${RESET} ")" OP
    echo ""

    case "$OP" in
    1)
        clear
        echo -e "${CYAN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${RESET}"
        echo -e "${CYAN}┃  ✨ CREAR NUEVO BANNER — HTML ESTILO PROPIO   ┃${RESET}"
        echo -e "${CYAN}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛{RESET}"
        echo ""

        read -rp "$(echo -e "${GREEN}Nombre del Servidor:${RESET} ")" SERVER
        [[ -z "$SERVER" ]] && SERVER="${SERVER_NAME:-MoviVIP VPN}"

        echo -e "${WHITE}Tipo de servidor:${RESET}"
        echo -e "  ${GREEN}[1]${WHITE} PREMIUM${RESET}"
        echo -e "  ${YELLOW}[2]${WHITE} GRATUITO${RESET}"
        read -rp "$(echo -e "${GREEN}Seleccione [1/2]:${RESET} ")" TIPO_SERVER
        case "$TIPO_SERVER" in
            1) SERVER_TYPE="PREMIUM"; TYPE_LINE="<font color='#ffffff'><big> ▶ SERVER PREMIUM ◀</big></font><br>" ;;
            2) SERVER_TYPE="GRATUITO"; TYPE_LINE="<font color='#ffffff'><big> ▶ SERVER GRATUITO ◀ ¡Si lo compraste, te estafaron!</big></font><br>" ;;
            *) SERVER_TYPE="PREMIUM"; TYPE_LINE="<font color='#ffffff'><big> ▶ SERVER PREMIUM ◀</big></font><br>" ;;
        esac

        read -rp "$(echo -e "${GREEN}¿Incluir etiqueta de SOCIO/COMUNIDAD? [S/N]:${RESET} ")" HAS_SOCIO
        SOCIO_BLOCK=""
        if [[ "$HAS_SOCIO" =~ ^[Ss]$ ]]; then
            read -rp "$(echo -e "${GREEN}Título de la sección (ej. COLABORACIÓN / COMUNIDAD SOCIA):${RESET} ")" SOCIO_TITLE
            [[ -z "$SOCIO_TITLE" ]] && SOCIO_TITLE="COLABORACIÓN / COMUNIDAD SOCIA"
            read -rp "$(echo -e "${GREEN}Canal del socio:${RESET} ")" SOCIO_CHANNEL
            read -rp "$(echo -e "${GREEN}Grupo del socio:${RESET} ")" SOCIO_GROUP
            SOCIO_BLOCK="<font color='#29b6f6'>════════════════════════════</font><br><br>
<font color='#ffffff'><big>🤝 ⚡${SOCIO_TITLE} ⚡ 🤝</big></font><br><br>
<font color='#ffff00'>📢 Canal: ${SOCIO_CHANNEL}</font><br>
<font color='#ffff00'>📢 Grupo: ${SOCIO_GROUP}</font><br><br>"
        fi

        read -rp "$(echo -e "${GREEN}Canal principal [t.me/MoviVIPNetwork]:${RESET} ")" MY_CHANNEL
        [[ -z "$MY_CHANNEL" ]] && MY_CHANNEL="t.me/MoviVIPNetwork"
        read -rp "$(echo -e "${GREEN}Grupo principal [t.me/MoviVIPNet]:${RESET} ")" MY_GROUP
        [[ -z "$MY_GROUP" ]] && MY_GROUP="t.me/MoviVIPNet"
        read -rp "$(echo -e "${GREEN}Web [movivip-network.web.app]:${RESET} ")" MY_WEB
        [[ -z "$MY_WEB" ]] && MY_WEB="movivip-network.web.app"
        read -rp "$(echo -e "${GREEN}Soporte [https://t.me/MoviVIPNet]:${RESET} ")" MY_SUPPORT
        [[ -z "$MY_SUPPORT" ]] && MY_SUPPORT="https://t.me/MoviVIPNet"

        read -rp "$(echo -e "${GREEN}Slogan [ULTRA PERFORMANCE & MAXIMUM SPEED]:${RESET} ")" MY_SLOGAN
        [[ -z "$MY_SLOGAN" ]] && MY_SLOGAN="ULTRA PERFORMANCE & MAXIMUM SPEED"

        cat > "$BANNER" <<EOF
<html>
<body style='margin:0;padding:0;background:transparent'>
<div style='text-align:center'><span style="font-family:'Comic Sans MS',cursive,sans-serif;font-weight:bold;">

<br><br>
<font color='#FFD700'><big><big> 🛡  MOVIVIP NETWORK  🛡 </big></big></font><br>
${TYPE_LINE}
<font color='#29b6f6'>════════════════════════════</font><br><br>
<font color='#ffffff'><big>🛡 ⚔️ ${MY_SLOGAN:-ULTRA PERFORMANCE & MAXIMUM SPEED} ⚔️ 🛡</big></font><br><br>
<font color='#ffff00'>📢 Canal: ${MY_CHANNEL}</font><br>
<font color='#ffff00'>📢 Grupo: ${MY_GROUP}</font><br>
<font color='#29b6f6'>════════════════════════════</font><br><br>
${SOCIO_BLOCK}
<font color='#00ffff'>🌐 𝕎𝔼𝔹: ${MY_WEB}</font><br><br>
<font color='#00ffff'>👤 Soporte: ${MY_SUPPORT}</font><br><br>
<font color='#00ff00'><big>⚡️ VINCIT QUI PATITUR ⚡️</big></font><br><br>
<font color='#FFD700'><big><big><big>🐉</big></big></big></font><br>
<font color="#00ffff"><small><i>🛡SISTEMA PROTEGIDO POR MOVIVIP NETWORK🛡</i></small></font>
</span></div>
</body>
</html>
EOF

        if grep -q "^Banner" "$SSHD"; then
            sed -i "s|^Banner.*|Banner $BANNER|" "$SSHD"
        else
            echo "Banner $BANNER" >> "$SSHD"
        fi
        if [[ -f "$DROPBEAR" ]]; then
            if grep -q "^DROPBEAR_BANNER=" "$DROPBEAR"; then
                sed -i 's|^DROPBEAR_BANNER=.*|DROPBEAR_BANNER="$BANNER"|' "$DROPBEAR"
            else
                echo 'DROPBEAR_BANNER="$BANNER"' >> "$DROPBEAR"
            fi
        fi
        systemctl restart ssh 2>/dev/null
        systemctl restart sshd 2>/dev/null
        systemctl restart dropbear 2>/dev/null
        applying_sello

        echo ""
        echo -e "${GREEN}✔ Banner HTML creado con estructura exacta.${RESET}"
        echo -e "${WHITE}  Emoji: 🛡️ 🛡  |  Tipo: ${SERVER_TYPE}  |  Socio: ${HAS_SOCIO}${RESET}"
        sleep 2
        ;;

    2)
        clear
        echo -e "${CYAN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${RESET}"
        echo -e "${CYAN}┃  👁 BANNER ACTUAL                                    ┃${RESET}"
        echo -e "${CYAN}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${RESET}"
        echo ""
        if [[ -f "$BANNER" ]]; then
            echo -e "${GREEN}Ruta:${RESET} $BANNER"
            echo -e "${CYAN}──────────────────────────────────────────────────────${RESET}"
            cat "$BANNER"
            echo -e "${CYAN}──────────────────────────────────────────────────────${RESET}"
        else
            echo -e "${RED}No existe ningún banner creado.${RESET}"
        fi
        read -n1 -s -r -p "$(echo -e "${GRAY}Presione cualquier tecla...${RESET}")"
        ;;

    3)
        clear
        echo -e "${CYAN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${RESET}"
        echo -e "${CYAN}┃  ✏️ EDITAR BANNER                                    ┃${RESET}"
        echo -e "${CYAN}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛{RESET}"
        echo ""
        if [[ ! -f "$BANNER" ]]; then
            cat > "$BANNER" <<EOF
<html>
<body style='margin:0;padding:0;background:transparent'>
<div style='text-align:center'><span style="font-family:'Comic Sans MS',cursive,sans-serif;font-weight:bold;">
<br><br>
<font color='#FFD700'><big><big>🛡  MOVIVIP NETWORK  🛡</big></big></font><br>
<font color='#ffffff'><big> ▶ SERVER GRATUITO ◀ ¡Si lo compraste, te estafaron!</big></font><br><br>
<font color='#29b6f6'>════════════════════════════</font><br><br>
<font color='#ffffff'><big>🛡 ⚔️ ULTRA PERFORMANCE & MAXIMUM SPEED ⚔️ 🛡</big></font><br><br>
<font color='#ffff00'>📢 Canal: https://t.me/FreeNetZonevip</font><br>
<font color='#ffff00'>📢 Grupo: https://t.me/FreeNetZonevips</font><br>
<font color='#29b6f6'>════════════════════════════</font><br><br>
<font color='#ffffff'><big>🤝 ⚡COLABORACIÓN / COMUNIDAD SOCIA ⚡ 🤝</big></font><br><br>
<font color='#ffff00'>📢 Canal: @MoviVIPNetwork</font><br>
<font color='#ffff00'>📢 Grupo: @MoviVIPNet</font><br>
<font color='#00ffff'>🌐 𝕎𝔼𝔹: https://movivip-network.web.app</font><br><br>
<font color='#00ffff'>👤 Soporte: @MoviVIP</font><br><br>
<font color='#00ff00'><big>⚡️ VINCIT QUI PATITUR ⚡️</big></font><br>
<font color='#FFD700'><big><big><big>🐉</big></big></big></font><br>
<font color="#00ffff"><small><i>🛡SISTEMA PROTEGIDO POR MOVIVIP NETWORK🛡</i></small></font>
</span></div>
</body>
</html>
EOF
        fi
        if ! command -v nano >/dev/null 2>&1; then echo -e "${RED}Nano no instalado.${RESET}"; sleep 2; continue; fi
        nano "$BANNER"
        # Solo forzar emoji/sello si NO es admin
        if [[ "$SELLO_OFF" != "1" ]]; then
            applying_sello
        fi
        if grep -q "^Banner" "$SSHD"; then sed -i "s|^Banner.*|Banner $BANNER|" "$SSHD"; else echo "Banner $BANNER" >> "$SSHD"; fi
        if [[ -f "$DROPBEAR" ]]; then
            if grep -q "^DROPBEAR_BANNER=" "$DROPBEAR"; then sed -i 's|^DROPBEAR_BANNER=.*|DROPBEAR_BANNER="$BANNER"|' "$DROPBEAR"; else echo 'DROPBEAR_BANNER="$BANNER"' >> "$DROPBEAR"; fi
        fi
        systemctl restart ssh 2>/dev/null; systemctl restart sshd 2>/dev/null; systemctl restart dropbear 2>/dev/null
        echo -e "${GREEN}✔ Banner actualizado.${RESET}"; sleep 2
        ;;

    4)
        clear
        echo -e "${CYAN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓{RESET}"
        echo -e "${CYAN}┃  🗑 ELIMINAR BANNER                                  ┃${RESET}"
        echo -e "${CYAN}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛{RESET}"
        echo ""
        if [[ ! -f "$BANNER" ]]; then echo -e "${RED}No hay banner.${RESET}"; sleep 2; continue; fi
        read -rp "$(echo -e "${YELLOW}¿Eliminar banner? [S/N]: {RESET})")" RESP
        case "$RESP" in
            s|S|si|SI|Sí|sí)
                rm -f "$BANNER"
                sed -i '/^Banner /d' "$SSHD"
                [[ -f "$DROPBEAR" ]] && sed -i '/^DROPBEAR_BANNER=/d' "$DROPBEAR"
                cat > "$BANNER" <<EOF
<html>
<body style='margin:0;padding:0;background:transparent'>
<div style='text-align:center'><span style="font-family:'Comic Sans MS',cursive,sans-serif;font-weight:bold;">
<br><br>
<font color='#FFD700'><big><big>🛡  MOVIVIP NETWORK  🛡</big></big></font><br>
<font color='#ffffff'><big> ▶ SERVER GRATUITO ◀ ¡Si lo compraste, te estafaron!</big></font><br><br>
<font color='#29b6f6'>════════════════════════════</font><br><br>
<font color='#ffffff'><big>🛡 ⚔️ ULTRA PERFORMANCE & MAXIMUM SPEED ⚔️ 🛡</big></font><br><br>
<font color='#ffff00'>📢 Canal: https://t.me/FreeNetZonevip</font><br>
<font color='#ffff00'>📢 Grupo: https://t.me/FreeNetZonevips</font><br>
<font color='#29b6f6'>════════════════════════════</font><br><br>
<font color='#ffffff'><big>🤝 ⚡COLABORACIÓN / COMUNIDAD SOCIA ⚡ 🤝</big></font><br><br>
<font color='#ffff00'>📢 Canal: @MoviVIPNetwork</font><br>
<font color='#ffff00'>📢 Grupo: @MoviVIPNet</font><br>
<font color='#00ffff'>🌐 𝕎𝔼𝔹: https://movivip-network.web.app</font><br><br>
<font color='#00ffff'>👤 Soporte: @MoviVIP</font><br><br>
<font color='#00ff00'><big>⚡️ VINCIT QUI PATITUR ⚡️</big></font><br>
<font color='#FFD700'><big><big><big>🐉</big></big></big></font><br>
<font color="#00ffff"><small><i>🛡SISTEMA PROTEGIDO POR MOVIVIP NETWORK🛡</i></small></font>
</span></div>
</body>
</html>
EOF
                applying_sello
                if grep -q "^Banner" "$SSHD"; then sed -i "s|^Banner.*|Banner $BANNER|" "$SSHD"; else echo "Banner $BANNER" >> "$SSHD"; fi
                [[ -f "$DROPBEAR" ]] && sed -i 's|^DROPBEAR_BANNER=.*|DROPBEAR_BANNER="$BANNER"|' "$DROPBEAR"
                systemctl restart ssh 2>/dev/null; systemctl restart sshd 2>/dev/null; systemctl restart dropbear 2>/dev/null
                echo -e "${GREEN}✔ Banner reseteado a default (sello permanente salvo admin).{RESET}"
                ;;
            *) echo -e "${YELLOW}Cancelado.{RESET}";;
        esac
        sleep 2
        ;;

    0) break ;;
    *) echo -e "${RED}Opción inválida.{RESET}"; sleep 2 ;;
    esac
done
