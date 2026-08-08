#!/bin/bash
#==================================================
# MoviVIP Network Premium
# Crear Usuario SSH con HWID (atado al dispositivo)
#==================================================

#======== COLORES ========#
GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
BLUE="\e[1;94m"
CYAN="\e[1;96m"
MAGENTA="\e[1;95m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"
RESET="\e[0m"

#======== CONFIG ========#

BASE="/etc/movivip"
CONFIG="$BASE/config.conf"

[[ -f "$CONFIG" ]] && source "$CONFIG"

# Ruta donde se guardan los HWID
HWID_DIR="$BASE/hwids"
mkdir -p "$HWID_DIR"

while true; do

clear

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${MAGENTA}               ⚜️ MoviVIP Network ⚜️                ${CYAN}║${RESET}"
echo -e "${CYAN}║${WHITE}             CREAR USUARIO CON HWID 🔐                ${CYAN}║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo

read -rp "$(echo -e "${GREEN}👤 Usuario               : ${RESET}")" USER

if [[ -z "$USER" ]]; then
    echo
    echo -e "${RED}❌ Debe ingresar un nombre de usuario.${RESET}"
    sleep 2
    continue
fi

if id "$USER" &>/dev/null; then
    echo
    echo -e "${RED}❌ El usuario ya existe.${RESET}"
    sleep 2
    continue
fi

read -rsp "$(echo -e "${GREEN}🔑 Contraseña            : ${RESET}")" PASS
echo

if [[ -z "$PASS" ]]; then
    echo
    echo -e "${RED}❌ Debe ingresar una contraseña.${RESET}"
    sleep 2
    continue
fi

read -rp "$(echo -e "${GREEN}📅 Duración (días)       : ${RESET}")" DIAS

[[ -z "$DIAS" ]] && DIAS=30

read -rp "$(echo -e "${GREEN}👥 Límite (0=Ilimitado) : ${RESET}")" LIMITE

[[ -z "$LIMITE" ]] && LIMITE=0

if ! [[ "$LIMITE" =~ ^[0-9]+$ ]]; then
    echo
    echo -e "${RED}❌ El límite debe ser un número.${RESET}"
    sleep 2
    continue
fi

echo
echo -e "${YELLOW}📲 HWID del dispositivo (HTTP Custom → Ajustes → HWID / ID del dispositivo)${RESET}"
read -rp "$(echo -e "${GREEN}🔒 HWID                  : ${RESET}")" HWID

if [[ -z "$HWID" ]]; then
    echo
    echo -e "${RED}❌ Debe ingresar el HWID del dispositivo.${RESET}"
    sleep 2
    continue
fi

if ! [[ "$HWID" =~ ^[A-Za-z0-9_:.-]+$ ]] || [[ ${#HWID} -lt 4 ]] || [[ ${#HWID} -gt 64 ]]; then
    echo
    echo -e "${RED}❌ HWID inválido (solo letras, números y _ : . - ; de 4 a 64 caracteres).${RESET}"
    sleep 2
    continue
fi

if [[ "$LIMITE" -eq 0 ]]; then
    LIMITE_MOSTRAR="♾ Ilimitado"
else
    LIMITE_MOSTRAR="$LIMITE"
fi

FECHA=$(date -d "+$DIAS days" +"%Y-%m-%d")
#==================================================
# CREAR USUARIO SSH
#==================================================

useradd -e "$FECHA" -M -s /usr/sbin/nologin "$USER"

if [[ $? -ne 0 ]]; then
    echo
    echo -e "${RED}❌ Error al crear el usuario.${RESET}"
    sleep 3
    continue
fi

echo "$USER:$PASS" | chpasswd

if [[ $? -ne 0 ]]; then
    echo
    echo -e "${RED}❌ Error al establecer la contraseña.${RESET}"
    userdel -f "$USER" &>/dev/null
    sleep 3
    continue
fi

#==================================================
# GUARDAR HWID (atado al dispositivo)
#==================================================

cat > "$HWID_DIR/$USER.hwid" <<EOF
# MoviVIP Network - Usuario con HWID
USER: $USER
HWID: $HWID
EXPIRE: $FECHA
LIMIT: $LIMITE
CREATED: $(date +"%Y-%m-%d %H:%M:%S")
EOF

if [[ $? -ne 0 ]]; then
    echo
    echo -e "${RED}❌ Error al guardar el HWID.${RESET}"
    userdel -f "$USER" &>/dev/null
    sleep 3
    continue
fi

#==================================================
# INFORMACIÓN DEL SERVIDOR
#==================================================

clear

IP=$(curl -4 -s ifconfig.me)

[[ -z "$IP" ]] && IP=$(hostname -I | awk '{print $1}')

HOST="${SERVER_DOMAIN:-$IP}"

FECHA_MOSTRAR=$(date -d "$FECHA" +"%d/%m/%Y")

#==================================================
# PREPARAR LÍMITE
#==================================================

if [[ "$LIMITE" == "0" ]]; then
    LIMITE_MOSTRAR="♾ Ilimitado"
else
    LIMITE_MOSTRAR="$LIMITE Usuario(s)"
fi
#==================================================
# MOSTRAR INFORMACIÓN DE LA CUENTA
#==================================================

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${MAGENTA}               ⚜️ MoviVIP Network ⚜️                ${CYAN}║${RESET}"
echo -e "${CYAN}║${WHITE}           CUENTA CON HWID CREADA CON ÉXITO            ${CYAN}║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo

echo -e "${YELLOW}               👤 INFORMACIÓN DE LA CUENTA${RESET}"
echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${RESET}"
printf "${WHITE}│ 👤 Usuario      : ${GREEN}%-35s${WHITE}│\n" "$USER"
printf "${WHITE}│ 🔑 Contraseña   : ${GREEN}%-35s${WHITE}│\n" "$PASS"
printf "${WHITE}│ 📅 Expira       : ${GREEN}%-35s${WHITE}│\n" "$FECHA_MOSTRAR"
printf "${WHITE}│ 👥 Límite       : ${GREEN}%-35s${WHITE}│\n" "$LIMITE_MOSTRAR"
printf "${WHITE}│ 🔒 HWID         : ${GREEN}%-35s${WHITE}│\n" "$HWID"
echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${RESET}"
echo

echo -e "${YELLOW}               🌐 INFORMACIÓN DEL SERVIDOR${RESET}"
echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${RESET}"
printf "${WHITE}│ 🌍 Dominio      : ${GREEN}%-35s${WHITE}│\n" "${SERVER_DOMAIN:-$IP}"
printf "${WHITE}│ 🖥 Host/IP      : ${GREEN}%-35s${WHITE}│\n" "$IP"
echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${RESET}"
echo

echo -e "${YELLOW}                 🚪 PUERTOS DISPONIBLES${RESET}"
echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${RESET}"

[[ "$OPENSSH" == "ON" ]]  && printf "${WHITE}│ ✓ SSH           : ${GREEN}22%-37s${WHITE}│\n" ""
[[ "$WEBSOCKET" == "ON" ]] && printf "${WHITE}│ ✓ WebSocket     : ${GREEN}80%-37s${WHITE}│\n" ""
[[ "$DROPBEAR" == "ON" ]] && printf "${WHITE}│ ✓ Dropbear      : ${GREEN}90%-37s${WHITE}│\n" ""
[[ "$SSL" == "ON" ]]      && printf "${WHITE}│ ✓ SSL/TLS       : ${GREEN}443%-36s${WHITE}│\n" ""
[[ "$SLOWDNS" == "ON" ]]  && printf "${WHITE}│ ✓ SlowDNS       : ${GREEN}5300%-35s${WHITE}│\n" ""

echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${RESET}"
echo

echo -e "${YELLOW}                 📲 CONEXIONES DISPONIBLES${RESET}"
echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${RESET}"
# HTTP Direct
if [[ "$WEBSOCKET" == "ON" ]]; then
    printf "${WHITE}│ 🌐 HTTP Direct                                        │\n"
    printf "${GREEN}│ %-58s${WHITE}│\n" "$IP:80@$USER:$PASS"
    printf "${WHITE}├────────────────────────────────────────────────────────────┤\n"
fi

# SSL/TLS (SNI)
if [[ "$SSL" == "ON" ]]; then
    printf "${WHITE}│ 🔒 SSL/TLS (SNI)                                      │\n"
    printf "${GREEN}│ %-58s${WHITE}│\n" "${SERVER_DOMAIN}:443@$USER:$PASS"
    printf "${WHITE}├────────────────────────────────────────────────────────────┤\n"
fi

# SSH UDP
printf "${WHITE}│ 🚀 SSH UDP                                            │\n"
printf "${GREEN}│ %-58s${WHITE}│\n" "$IP:1-65535@$USER:$PASS"

echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${RESET}"
echo

echo -e "${YELLOW}        💡 Este usuario queda ATADO al HWID del dispositivo.${RESET}"
echo -e "${YELLOW}        📁 Registro: ${GRAY}$HWID_DIR/$USER.hwid${RESET}"
echo
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}║             ✅ USUARIO CON HWID CREADO EXITOSAMENTE         ║${RESET}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo

read -rp "$(echo -e "${YELLOW}¿Desea crear otro usuario con HWID? [S/N]: ${RESET}")" RESP

case "$RESP" in
    s|S|si|SI|sí|Sí|y|Y)
        continue
        ;;
    *)
        break
        ;;
esac

done
