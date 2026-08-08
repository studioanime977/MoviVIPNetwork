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

BANNER="/etc/issue.net"
SSHD="/etc/ssh/sshd_config"
DROPBEAR="/etc/default/dropbear"

# ─── SELLO DE PROTECCION (NO EDITABLE) ─────────────────────────────
# Linea fija del vendedor. Se reinserta automaticamente despues de
# cualquier creacion/edicion/eliminacion. Es CORTA a proposito para
# NO exceder el limite de longitud que hace que dropbear se desactive.
SELLO='<font color="#00ffff"><small><i>SISTEMA PROTEGIDO POR MOVIVIP NETWORK</i></small></font>'

force_sello() {
    # Reinserta el sello en el banner si no esta (despues de crear/editar/eliminar)
    [[ ! -f "$BANNER" ]] && return 0
    # Quitar sello previo donde sea que este (duplicado, fuera del HTML, etc.)
    sed -i '/PROTEGIDO POR MOVIVIP NETWORK/d' "$BANNER" 2>/dev/null
    # Limpiar lineas en blanco que pudieron quedar al final del archivo
    sed -i -e ':a' -e '/^\n*$/{$d;N;ba' -e '}' "$BANNER" 2>/dev/null
    # Insertar el sello ANTES del cierre de </body> (o de </html> si no hay body)
    local TMP="$BANNER.tmp"
    if grep -qi '</body>' "$BANNER"; then
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

echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${MAGENTA}            📢 BANNER SSH / DROPBEAR 📢            ${CYAN}║${RESET}"
echo -e "${CYAN}╠════════════════════════════════════════════════════╣${RESET}"

echo -e "${GREEN}[1]${WHITE} Crear nuevo Banner"
echo -e "${BLUE}[2]${WHITE} Ver Banner actual"
echo -e "${YELLOW}[3]${WHITE} Editar Banner"
echo -e "${RED}[4]${WHITE} Eliminar Banner"
echo -e "${CYAN}[0]${WHITE} Regresar"

echo
read -rp "$(echo -e "${GREEN}Seleccione una opción:${RESET} ")" OP

case "$OP" in

1)

clear

echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${MAGENTA}               CREAR NUEVO BANNER                 ${CYAN}║${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"
echo

read -rp "$(echo -e "${GREEN}Nombre del Servidor:${RESET} ")" SERVER
[[ -z "$SERVER" ]] && SERVER="${SERVER_NAME:-MoviVIP VPN}"

read -rp "$(echo -e "${GREEN}Texto Promocional:${RESET} ")" PROMO
[[ -z "$PROMO" ]] && PROMO="🔥 Bienvenido a $SERVER 🔥"

read -rp "$(echo -e "${GREEN}Canal Telegram (ej. @MoviVIP):${RESET} ")" CHANNEL

read -rp "$(echo -e "${GREEN}Soporte (ej. @TuSoporte):${RESET} ")" SUPPORT

cat > "$BANNER" <<EOF
<html>
<body style='margin:0;padding:0;background:transparent'>
<div style='text-align:center'><span style="font-family:'Comic Sans MS',cursive,sans-serif;font-weight:bold;">

<br><br>
<font color='#FFD700'><big><big>🛡️ $SERVER 🛡️</big></big></font><br>
<font color='#29b6f6'>════════════════════════════</font><br><br>

<font color='#ffffff'><big>$PROMO</big></font><br><br>

<font color='#ffff00'>📢 Canal: $CHANNEL</font><br>
<font color='#00ffff'>👤 Soporte: $SUPPORT</font><br><br>

<font color='#29b6f6'>════════════════════════════</font><br><br>
<font color='#00ff00'><big>✨ Gracias por usar nuestros servicios ✨</big></font><br>
<font color='#00ffff'><small><i>SISTEMA PROTEGIDO POR MOVIVIP NETWORK</i></small></font>

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
echo -e "${GREEN}✔ Banner creado correctamente.${RESET}"
sleep 2
;;

2)

clear

echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${MAGENTA}                 BANNER ACTUAL                    ${CYAN}║${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"
echo

if [[ -f "$BANNER" ]]; then

    echo -e "${GREEN}Ruta:${RESET} $BANNER"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo

    cat "$BANNER"

    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

else

    echo -e "${RED}No existe ningún banner creado.${RESET}"

fi

echo
read -n1 -s -r -p "Presione cualquier tecla para regresar..."

;;

3)

clear

echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${MAGENTA}                 EDITAR BANNER                    ${CYAN}║${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"
echo

# Si no existe el banner, crear uno básico
if [[ ! -f "$BANNER" ]]; then

cat > "$BANNER" <<EOF
<html>
<body style='margin:0;padding:0;background:transparent'>
<div style='text-align:center'><span style="font-family:'Comic Sans MS',cursive,sans-serif;font-weight:bold;">

<br><br>
<font color='#FFD700'><big><big>🛡️ ${SERVER_NAME:-MoviVIP VPN} 🛡️</big></big></font><br>
<font color='#29b6f6'>════════════════════════════</font><br><br>

<font color='#ffffff'><big>Bienvenido a nuestro servidor</big></font><br><br>

<font color='#29b6f6'>════════════════════════════</font><br><br>
<font color='#00ff00'><big>✨ Gracias por usar nuestros servicios ✨</big></font><br>
<font color='#00ffff'><small><i>SISTEMA PROTEGIDO POR MOVIVIP NETWORK</i></small></font>

</span></div>
</body>
</html>
EOF

fi

# Verificar que nano esté instalado
if ! command -v nano >/dev/null 2>&1; then
    echo -e "${RED}Nano no está instalado.${RESET}"
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
echo -e "${GREEN}✔ Banner actualizado correctamente.${RESET}"
sleep 2

;;

4)

clear

echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${MAGENTA}               ELIMINAR BANNER                    ${CYAN}║${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"
echo

if [[ ! -f "$BANNER" ]]; then
    echo -e "${RED}No existe ningún banner para eliminar.${RESET}"
    sleep 2
    continue
fi

read -rp "$(echo -e "${YELLOW}¿Desea eliminar el banner? [S/N]: ${RESET}")" RESP

case "$RESP" in

s|S|si|SI|Sí|sí)

    # Eliminar archivo del banner
    rm -f "$BANNER"

    # Eliminar configuración de OpenSSH
    sed -i '/^Banner /d' "$SSHD"

    # Eliminar configuración de Dropbear
    if [[ -f "$DROPBEAR" ]]; then
        sed -i '/^DROPBEAR_BANNER=/d' "$DROPBEAR"
    fi

    # Recrear banner minimo SOLO con el sello de proteccion (no editable)
    cat > "$BANNER" <<EOF
<html>
<body style='margin:0;padding:0;background:transparent'>
<div style='text-align:center'><span style="font-family:'Comic Sans MS',cursive,sans-serif;font-weight:bold;">

<br><br>
<font color='#00ffff'><small><i>SISTEMA PROTEGIDO POR MOVIVIP NETWORK</i></small></font>

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
    echo -e "${GREEN}✔ Banner eliminado. Se mantiene el sello de protección MoviVIP Network.${RESET}"
    ;;

*)

    echo
    echo -e "${YELLOW}Operación cancelada.${RESET}"
    ;;

esac

sleep 2

;;

0)
break
;;

*)
echo
echo -e "${RED}Opción inválida.${RESET}"
sleep 2
;;

esac

done
