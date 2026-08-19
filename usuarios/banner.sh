#!/bin/bash
#==================================================
# MoviVIP Network
# Banner SSH / Dropbear
#==================================================

GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
BLUE="\e[1;94m"
CYAN="\e[1;96m"
MAGENTA="\e[1;95m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"
RESET="\e[0m"

#==============================
# CONFIG MoviVIP
#==============================

BASE="/etc/movivip"
CONFIG="$BASE/config.conf"

[[ -f "$CONFIG" ]] && source "$CONFIG"

# Cargar idioma
if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)"
fi

BANNER="/etc/issue.net"
SSHD="/etc/ssh/sshd_config"
DROPBEAR="/etc/default/dropbear"

# â”€â”€â”€ SELLO DE PROTECCION (NO EDITABLE) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
# Linea fija del vendedor. Se reinserta automaticamente despues de
# cualquier creacion/edicion/eliminacion. Es CORTA a proposito para
# NO exceder el limite de longitud que hace que dropbear se desactive.
SELLO='<font color="#00ffff"><small><i>ðŸ›¡SISTEMA PROTEGIDO POR MOVIVIP NETWORKðŸ›¡</i></small></font>'

force_sello() {
    # Reinserta el sello en el banner si no esta (despues de crear/editar/eliminar)
    [[ ! -f "$BANNER" ]] && return 0
    # Quitar sello previo donde sea que este (duplicado, fuera del HTML, etc.)
    sed -i '/PROTEGIDO POR MOVIVIP NETWORK/d' "$BANNER" 2>/dev/null
    # Limpiar lineas en blanco que pudieron quedar al final del archivo
    sed -i -e ':a' -e '/^\n*$/{$d;N;ba' -e '}' "$BANNER" 2>/dev/null
    # Insertar el sello ANTES del cierre de </span></div> (posicion exacta del sello)
    local TMP="$BANNER.tmp"
    if grep -qi '</span></div>' "$BANNER"; then
        sed "s|</span></div>|$SELLO\n</span></div>|" "$BANNER" > "$TMP" 2>/dev/null && mv "$TMP" "$BANNER"
    elif grep -qi '</body>' "$BANNER"; then
        sed "s|</body>|$SELLO\n</body>|" "$BANNER" > "$TMP" 2>/dev/null && mv "$TMP" "$BANNER"
    elif grep -qi '</html>' "$BANNER"; then
        sed "s|</html>|$SELLO\n</html>|" "$BANNER" > "$TMP" 2>/dev/null && mv "$TMP" "$BANNER"
    else
        echo "" >> "$BANNER"
        echo "$SELLO" >> "$BANNER"
    fi
}

while true; do

clear

echo -e "${CYAN}â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—${RESET}"
echo -e "${CYAN}â•‘${MAGENTA}            ðŸ“¢ BANNER SSH / DROPBEAR ðŸ“¢            ${CYAN}â•‘${RESET}"
echo -e "${CYAN}â• â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•£${RESET}"

echo -e "${GREEN}[1]${WHITE} Crear nuevo Banner"
echo -e "${BLUE}[2]${WHITE} Ver Banner actual"
echo -e "${YELLOW}[3]${WHITE} Editar Banner"
echo -e "${RED}[4]${WHITE} Eliminar Banner"
echo -e "${CYAN}[0]${WHITE} Regresar"

echo
read -rp "$(echo -e "${GREEN}Seleccione una opciÃ³n:${RESET} ")" OP

case "$OP" in

1)

clear

echo -e "${CYAN}â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—${RESET}"
echo -e "${CYAN}â•‘${MAGENTA}               CREAR NUEVO BANNER                 ${CYAN}â•‘${RESET}"
echo -e "${CYAN}â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${RESET}"
echo

read -rp "$(echo -e "${GREEN}Nombre del Servidor:${RESET} ")" SERVER
[[ -z "$SERVER" ]] && SERVER="${SERVER_NAME:-MoviVIP VPN}"

read -rp "$(echo -e "${GREEN}Texto Promocional:${RESET} ")" PROMO
[[ -z "$PROMO" ]] && PROMO="ðŸ”¥ Bienvenido a $SERVER ðŸ”¥"

read -rp "$(echo -e "${GREEN}Canal Telegram (ej. @MoviVIP):${RESET} ")" CHANNEL

read -rp "$(echo -e "${GREEN}Soporte (ej. @TuSoporte):${RESET} ")" SUPPORT

cat > "$BANNER" <<EOF
<html>
<body style='margin:0;padding:0;background:transparent'>
<div style='text-align:center'><span style="font-family:'Comic Sans MS',cursive,sans-serif;font-weight:bold;">

<br><br>
<font color='#FFD700'><big><big>ðŸ›¡ï¸ $SERVER ðŸ›¡ï¸</big></big></font><br>
<font color='#29b6f6'>â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•</font><br><br>

<font color='#ffffff'><big>$PROMO</big></font><br><br>

<font color='#ffff00'>ðŸ“¢ Canal: $CHANNEL</font><br>
<font color='#00ffff'>ðŸ‘¤ Soporte: $SUPPORT</font><br><br>

<font color='#29b6f6'>â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•</font><br><br>
<font color='#00ff00'><big>âœ¨ Gracias por usar nuestros servicios âœ¨</big></font><br>
<font color='#00ffff'><small><i>ðŸ›¡SISTEMA PROTEGIDO POR MOVIVIP NETWORKðŸ›¡</i></small></font>
</span></div>
</body>
</html>
EOF

# Configurar OpenSSH
if grep -q "^Banner" "$SSHD"; then
    sed -i "s|^Banner.*|Banner $BANNER|" "$SSHD"
else
    echo "Banner $BANNER" >> "$SSHD"
fi

# Configurar Dropbear
if [[ -f "$DROPBEAR" ]]; then
    if grep -q "^DROPBEAR_BANNER=" "$DROPBEAR"; then
        sed -i "s|^DROPBEAR_BANNER=.*|DROPBEAR_BANNER=\"$BANNER\"|" "$DROPBEAR"
    else
        echo "DROPBEAR_BANNER=\"$BANNER\"" >> "$DROPBEAR"
    fi
fi

systemctl restart ssh 2>/dev/null
systemctl restart sshd 2>/dev/null
systemctl restart dropbear 2>/dev/null

# Reforzar sello (siempre presente)
force_sello

echo
echo -e "${GREEN}âœ” Banner creado correctamente.${RESET}"
sleep 2
;;

2)

clear

echo -e "${CYAN}â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—${RESET}"
echo -e "${CYAN}â•‘${MAGENTA}                 BANNER ACTUAL                    ${CYAN}â•‘${RESET}"
echo -e "${CYAN}â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${RESET}"
echo

if [[ -f "$BANNER" ]]; then

    echo -e "${GREEN}Ruta:${RESET} $BANNER"
    echo -e "${CYAN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${RESET}"
    echo

    cat "$BANNER"

    echo
    echo -e "${CYAN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${RESET}"

else

    echo -e "${RED}No existe ningÃºn banner creado.${RESET}"

fi

echo
read -n1 -s -r -p "Presione cualquier tecla para regresar..."

;;

3)

clear

echo -e "${CYAN}â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—${RESET}"
echo -e "${CYAN}â•‘${MAGENTA}                 EDITAR BANNER                    ${CYAN}â•‘${RESET}"
echo -e "${CYAN}â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${RESET}"
echo

# Si no existe el banner, crear uno bÃ¡sico
if [[ ! -f "$BANNER" ]]; then

cat > "$BANNER" <<EOF
<html>
<body style='margin:0;padding:0;background:transparent'>
<div style='text-align:center'><span style="font-family:'Comic Sans MS',cursive,sans-serif;font-weight:bold;">

<br><br>
<font color='#FFD700'><big><big>ðŸ›¡ï¸ ${SERVER_NAME:-MoviVIP VPN} ðŸ›¡ï¸</big></big></font><br>
<font color='#29b6f6'>â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•</font><br><br>

<font color='#ffffff'><big>Bienvenido a nuestro servidor</big></font><br><br>

<font color='#29b6f6'>â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•</font><br><br>
<font color='#00ff00'><big>âœ¨ Gracias por usar nuestros servicios âœ¨</big></font><br>
<font color='#00ffff'><small><i>ðŸ›¡SISTEMA PROTEGIDO POR MOVIVIP NETWORKðŸ›¡</i></small></font>
</span></div>
</body>
</html>
EOF

fi

# Verificar que nano estÃ© instalado
if ! command -v nano >/dev/null 2>&1; then
    echo -e "${RED}Nano no estÃ¡ instalado.${RESET}"
    sleep 2
    break
fi

# Abrir editor
nano "$BANNER"

# Reforzar sello (aunque el cliente lo borre con nano, se reinserta)
force_sello

# Configurar OpenSSH
if grep -q "^Banner" "$SSHD"; then
    sed -i "s|^Banner.*|Banner $BANNER|" "$SSHD"
else
    echo "Banner $BANNER" >> "$SSHD"
fi

# Configurar Dropbear
if [[ -f "$DROPBEAR" ]]; then
    if grep -q "^DROPBEAR_BANNER=" "$DROPBEAR"; then
        sed -i "s|^DROPBEAR_BANNER=.*|DROPBEAR_BANNER=\"$BANNER\"|" "$DROPBEAR"
    else
        echo "DROPBEAR_BANNER=\"$BANNER\"" >> "$DROPBEAR"
    fi
fi

# Reiniciar servicios
systemctl restart ssh 2>/dev/null
systemctl restart sshd 2>/dev/null
systemctl restart dropbear 2>/dev/null

echo
echo -e "${GREEN}âœ” Banner actualizado correctamente.${RESET}"
sleep 2

;;

4)

clear

echo -e "${CYAN}â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—${RESET}"
echo -e "${CYAN}â•‘${MAGENTA}               ELIMINAR BANNER                    ${CYAN}â•‘${RESET}"
echo -e "${CYAN}â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${RESET}"
echo

if [[ ! -f "$BANNER" ]]; then
    echo -e "${RED}No existe ningÃºn banner para eliminar.${RESET}"
    sleep 2
    continue
fi

read -rp "$(echo -e "${YELLOW}Â¿Desea eliminar el banner? [S/N]: ${RESET}")" RESP

case "$RESP" in

s|S|si|SI|SÃ­|sÃ­)

    # Eliminar archivo del banner
    rm -f "$BANNER"

    # Eliminar configuraciÃ³n de OpenSSH
    sed -i '/^Banner /d' "$SSHD"

    # Eliminar configuraciÃ³n de Dropbear
    if [[ -f "$DROPBEAR" ]]; then
        sed -i '/^DROPBEAR_BANNER=/d' "$DROPBEAR"
    fi

    # Recrear banner minimo SOLO con el sello de proteccion (no editable)
    cat > "$BANNER" <<EOF
<html>
<body style='margin:0;padding:0;background:transparent'>
<div style='text-align:center'><span style="font-family:'Comic Sans MS',cursive,sans-serif;font-weight:bold;">

<br><br>
<font color='#00ffff'><small><i>ðŸ›¡SISTEMA PROTEGIDO POR MOVIVIP NETWORKðŸ›¡</i></small></font>
</span></div>
</body>
</html>
EOF
    force_sello

    # Reactivar banner en ambos servicios
    if grep -q "^Banner" "$SSHD"; then
        sed -i "s|^Banner.*|Banner $BANNER|" "$SSHD"
    else
        echo "Banner $BANNER" >> "$SSHD"
    fi
    if [[ -f "$DROPBEAR" ]]; then
        if grep -q "^DROPBEAR_BANNER=" "$DROPBEAR"; then
            sed -i "s|^DROPBEAR_BANNER=.*|DROPBEAR_BANNER=\"$BANNER\"|" "$DROPBEAR"
        else
            echo "DROPBEAR_BANNER=\"$BANNER\"" >> "$DROPBEAR"
        fi
    fi

    # Reiniciar servicios
    systemctl restart ssh 2>/dev/null
    systemctl restart sshd 2>/dev/null
    systemctl restart dropbear 2>/dev/null

    echo
    echo -e "${GREEN}âœ” Banner eliminado. Se mantiene el sello de protecciÃ³n MoviVIP Network.${RESET}"
    ;;

*)

    echo
    echo -e "${YELLOW}OperaciÃ³n cancelada.${RESET}"
    ;;

esac

sleep 2

;;

0)
break
;;

*)
echo
echo -e "${RED}OpciÃ³n invÃ¡lida.${RESET}"
sleep 2
;;

esac

done
