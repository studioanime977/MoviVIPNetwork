#!/bin/bash
#==================================================
# MoviVIP Network Premium
# Crear Usuario SSH por HWID (v2 â€” sin contraseÃ±a elegida)
# El vendedor solo ingresa: USUARIO + HWID + DÃAS
# La contraseÃ±a se DERIVA del HWID + secreto del servidor:
#   nadie la elige, es Ãºnica por dispositivo y regenerable.
# Entrega: Usuario + HWID + DÃ­as (config con credencial incrustada)
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

# Cargar idioma
if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)"
fi

[[ -f "$CONFIG" ]] && source "$CONFIG"
HWID_DIR="$BASE/hwids"

[[ -f "$CONFIG" ]] && source "$CONFIG"

mkdir -p "$HWID_DIR" "$SISTEMA"

#==================================================
# SECRETO MAESTRO HWID (crear si no existe)
#==================================================
if [[ -z "$HWID_SECRET" ]]; then
    HWID_SECRET=$(openssl rand -hex 24 2>/dev/null || (echo "mv$(date +%s%N)$RANDOM" | sha256sum | cut -c1-48))
    if grep -q '^HWID_SECRET=' "$CONFIG" 2>/dev/null; then
        sed -i "s|^HWID_SECRET=.*|HWID_SECRET=\"$HWID_SECRET\"|" "$CONFIG"
    else
        echo "" >> "$CONFIG"
        echo "#==============================" >> "$CONFIG"
        echo "# SECRETO MAESTRO HWID" >> "$CONFIG"
        echo "# ContraseÃ±a de cuenta HWID = derivada(HWID + HWID_SECRET)" >> "$CONFIG"
        echo "# No compartirlo. Cambiarlo invalida todas las cuentas HWID." >> "$CONFIG"
        echo "#==============================" >> "$CONFIG"
        echo "HWID_SECRET=\"$HWID_SECRET\"" >> "$CONFIG"
    fi
fi

#==================================================
# DERIVAR CONTRASEÃ‘A desde HWID + SECRETO
# DeterminÃ­stica: mismo HWID => misma contraseÃ±a.
#==================================================
derive_pass() {
    local HW="$1"
    echo -n "${HW}|${HWID_SECRET}" | sha256sum | cut -c1-14
}

while true; do

clear

echo -e "${CYAN}â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—${RESET}"
echo -e "${CYAN}â•‘${MAGENTA}               âšœï¸ MoviVIP Network âšœï¸                ${CYAN}â•‘${RESET}"
echo -e "${CYAN}â•‘${WHITE}       CREAR USUARIO POR HWID ðŸ” (v2)                  ${CYAN}â•‘${RESET}"
echo -e "${CYAN}â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${RESET}"
echo
echo -e "${GRAY} Solo ingresas: Usuario + HWID + DÃ­as. La contraseÃ±a se genera${RESET}"
echo -e "${GRAY} automÃ¡ticamente desde el HWID (nadie la elige, es Ãºnica).${RESET}"
echo

read -rp "$(echo -e "${GREEN}ðŸ‘¤ Usuario            : ${RESET}")" USER

if [[ -z "$USER" ]]; then
    echo
    echo -e "${RED}âŒ Debe ingresar un nombre de usuario.${RESET}"
    sleep 2
    continue
fi

if ! [[ "$USER" =~ ^[a-z0-9_]{3,20}$ ]]; then
    echo
    echo -e "${RED}âŒ Usuario invÃ¡lido (minÃºsculas, nÃºmeros y _ ; 3 a 20 caracteres).${RESET}"
    sleep 2
    continue
fi

if id "$USER" &>/dev/null; then
    echo
    echo -e "${RED}âŒ El usuario ya existe.${RESET}"
    sleep 2
    continue
fi

read -rp "$(echo -e "${GREEN}ðŸ“… DuraciÃ³n (dÃ­as)    : ${RESET}")" DIAS

[[ -z "$DIAS" ]] && DIAS=30

if ! [[ "$DIAS" =~ ^[0-9]+$ ]] || [[ "$DIAS" -lt 1 ]] || [[ "$DIAS" -gt 3650 ]]; then
    echo
    echo -e "${RED}âŒ DÃ­as invÃ¡lido (1 a 3650).${RESET}"
    sleep 2
    continue
fi

read -rp "$(echo -e "${GREEN}ðŸ‘¥ Conexiones mÃ¡x (2): ${RESET}")" MAXCONN

[[ -z "$MAXCONN" ]] && MAXCONN=2

if ! [[ "$MAXCONN" =~ ^[0-9]+$ ]] || [[ "$MAXCONN" -lt 1 ]] || [[ "$MAXCONN" -gt 10 ]]; then
    echo
    echo -e "${RED}âŒ Conexiones invÃ¡lidas (1 a 10).${RESET}"
    sleep 2
    continue
fi

echo
echo -e "${YELLOW}ðŸ“² HWID del dispositivo (HTTP Custom â†’ Ajustes â†’ HWID / ID del dispositivo)${RESET}"
read -rp "$(echo -e "${GREEN}ðŸ”’ HWID               : ${RESET}")" HWID

if [[ -z "$HWID" ]]; then
    echo
    echo -e "${RED}âŒ Debe ingresar el HWID del dispositivo.${RESET}"
    sleep 2
    continue
fi

if ! [[ "$HWID" =~ ^[A-Za-z0-9_:.-]+$ ]] || [[ ${#HWID} -lt 4 ]] || [[ ${#HWID} -gt 64 ]]; then
    echo
    echo -e "${RED}âŒ HWID invÃ¡lido (solo letras, nÃºmeros y _ : . - ; de 4 a 64 caracteres).${RESET}"
    sleep 2
    continue
fi

# HWID ya registrado en otra cuenta?
DUPLICADO=$(grep -rl "^HWID: $HWID$" "$HWID_DIR" 2>/dev/null | head -n1)
if [[ -n "$DUPLICADO" ]]; then
    echo
    echo -e "${RED}âŒ Ese HWID ya estÃ¡ registrado en: $(basename "$DUPLICADO" .hwid)${RESET}"
    echo -e "${RED}   Un dispositivo solo puede tener UNA cuenta.${RESET}"
    sleep 3
    continue
fi

#==================================================
# CONTRASEÃ‘A DERIVADA + CREAR USUARIO SSH
#==================================================

PASS=$(derive_pass "$HWID")

FECHA=$(date -d "+$DIAS days" +"%Y-%m-%d")

useradd -e "$FECHA" -M -s /usr/sbin/nologin "$USER"

if [[ $? -ne 0 ]]; then
    echo
    echo -e "${RED}âŒ Error al crear el usuario.${RESET}"
    sleep 3
    continue
fi

# Establecer contrasena sin validacion PAM (compatible ARM)
HASH=$(openssl passwd -6 "$PASS" 2>/dev/null)
usermod -p "$HASH" "$USER"

if [[ $? -ne 0 ]]; then
    echo
    echo -e "${RED}âŒ Error al establecer la contraseÃ±a.${RESET}"
    userdel -f "$USER" &>/dev/null
    sleep 3
    continue
fi

#==================================================
# GUARDAR REGISTRO HWID
#==================================================

cat > "$HWID_DIR/$USER.hwid" <<EOF
# MoviVIP Network - Usuario por HWID (v2)
USER: $USER
HWID: $HWID
PASS: $PASS
EXPIRE: $FECHA
MAXCONN: $MAXCONN
CREATED: $(date +"%Y-%m-%d %H:%M:%S")
EOF

if [[ $? -ne 0 ]]; then
    echo
    echo -e "${RED}âŒ Error al guardar el HWID.${RESET}"
    userdel -f "$USER" &>/dev/null
    sleep 3
    continue
fi

#==================================================
# INFORMACIÃ“N DEL SERVIDOR
#==================================================

clear

IP=$(curl -4 -s ifconfig.me)

[[ -z "$IP" ]] && IP=$(hostname -I | awk '{print $1}')

HOST="${SERVER_DOMAIN:-$IP}"

FECHA_MOSTRAR=$(date -d "$FECHA" +"%d/%m/%Y")

#==================================================
# MOSTRAR INFORMACIÃ“N DE LA CUENTA
# (Entrega: Usuario + HWID + DÃ­as)
#==================================================

echo -e "${CYAN}â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—${RESET}"
echo -e "${CYAN}â•‘${MAGENTA}               âšœï¸ MoviVIP Network âšœï¸                ${CYAN}â•‘${RESET}"
echo -e "${CYAN}â•‘${WHITE}        CUENTA POR HWID CREADA CON Ã‰XITO ðŸŽ‰           ${CYAN}â•‘${RESET}"
echo -e "${CYAN}â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${RESET}"
echo

echo -e "${YELLOW}               ðŸ‘¤ ENTREGA AL CLIENTE (Usuario + HWID + DÃ­as)${RESET}"
echo -e "${CYAN}â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”${RESET}"
printf "${WHITE}â”‚ ðŸ‘¤ Usuario      : ${GREEN}%-35s${WHITE}â”‚\n" "$USER"
printf "${WHITE}â”‚ ðŸ”’ HWID         : ${GREEN}%-35s${WHITE}â”‚\n" "$HWID"
printf "${WHITE}â”‚ ðŸ“… DÃ­as         : ${GREEN}%-35s${WHITE}â”‚\n" "$DIAS"
printf "${WHITE}â”‚ ðŸšª Expira       : ${GREEN}%-35s${WHITE}â”‚\n" "$FECHA_MOSTRAR"
printf "${WHITE}â”‚ ðŸ”‘ Conexiones   : ${GREEN}%-35s${WHITE}â”‚\n" "$MAXCONN (anti-share: se bloquea si excede)"
echo -e "${CYAN}â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜${RESET}"
echo

echo -e "${YELLOW}       ðŸ” CREDENCIAL GENERADA AUTOMÃTICAMENTE (NO compartir)${RESET}"
echo -e "${CYAN}â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”${RESET}"
printf "${WHITE}â”‚ ðŸ”‘ ContraseÃ±a   : ${MAGENTA}%-35s${WHITE}â”‚\n" "$PASS"
echo -e "${CYAN}â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜${RESET}"
echo -e "${GRAY}   La contraseÃ±a deriva del HWID. Si el cliente cambia de${RESET}"
echo -e "${GRAY}   dispositivo, usa 'Cambiar HWID' y se regenera sola.${RESET}"
echo

echo -e "${YELLOW}               ðŸŒ INFORMACIÃ“N DEL SERVIDOR${RESET}"
echo -e "${CYAN}â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”${RESET}"
printf "${WHITE}â”‚ ðŸŒ Dominio      : ${GREEN}%-35s${WHITE}â”‚\n" "${SERVER_DOMAIN:-$IP}"
printf "${WHITE}â”‚ ðŸ–¥ Host/IP      : ${GREEN}%-35s${WHITE}â”‚\n" "$IP"
echo -e "${CYAN}â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜${RESET}"
echo

echo -e "${YELLOW}                 ðŸšª PUERTOS DISPONIBLES${RESET}"
echo -e "${CYAN}â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”${RESET}"

[[ "$OPENSSH" == "ON" ]]  && printf "${WHITE}â”‚ âœ“ SSH           : ${GREEN}22%-37s${WHITE}â”‚\n" ""
[[ "$WEBSOCKET" == "ON" ]] && printf "${WHITE}â”‚ âœ“ WebSocket     : ${GREEN}80%-37s${WHITE}â”‚\n" ""
[[ "$DROPBEAR" == "ON" ]] && printf "${WHITE}â”‚ âœ“ Dropbear      : ${GREEN}90%-37s${WHITE}â”‚\n" ""
[[ "$SSL" == "ON" ]]      && printf "${WHITE}â”‚ âœ“ SSL/TLS       : ${GREEN}443%-36s${WHITE}â”‚\n" ""
[[ "$SLOWDNS" == "ON" ]]  && printf "${WHITE}â”‚ âœ“ SlowDNS       : ${GREEN}5300%-35s${WHITE}â”‚\n" ""

echo -e "${CYAN}â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜${RESET}"
echo

echo -e "${YELLOW}                 ðŸ“² CONEXIONES DISPONIBLES${RESET}"
echo -e "${CYAN}â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”${RESET}"
# HTTP Direct
if [[ "$WEBSOCKET" == "ON" ]]; then
    printf "${WHITE}â”‚ ðŸŒ HTTP Direct                                        â”‚\n"
    printf "${GREEN}â”‚ %-58s${WHITE}â”‚\n" "$IP:80@$USER:$PASS"
    printf "${WHITE}â”œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¤\n"
fi

# SSL/TLS (SNI)
if [[ "$SSL" == "ON" ]]; then
    printf "${WHITE}â”‚ ðŸ”’ SSL/TLS (SNI)                                      â”‚\n"
    printf "${GREEN}â”‚ %-58s${WHITE}â”‚\n" "${SERVER_DOMAIN}:443@$USER:$PASS"
    printf "${WHITE}â”œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¤\n"
fi

# SSH UDP
printf "${WHITE}â”‚ ðŸš€ SSH UDP                                            â”‚\n"
printf "${GREEN}â”‚ %-58s${WHITE}â”‚\n" "$IP:1-65535@$USER:$PASS"

echo -e "${CYAN}â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜${RESET}"
echo

echo -e "${YELLOW}        ðŸ’¡ Este usuario queda ATADO al HWID del dispositivo.${RESET}"
echo -e "${YELLOW}        ðŸ›¡ Anti-share: mÃ¡s de $MAXCONN conexiones simultÃ¡neas = BLOQUEO automÃ¡tico.${RESET}"
echo -e "${YELLOW}        ðŸ“ Registro: ${GRAY}$HWID_DIR/$USER.hwid${RESET}"
echo
echo -e "${GREEN}â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—${RESET}"
echo -e "${GREEN}â•‘             âœ… USUARIO POR HWID CREADO EXITOSAMENTE         â•‘${RESET}"
echo -e "${GREEN}â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${RESET}"
echo

read -rp "$(echo -e "${YELLOW}Â¿Desea crear otro usuario por HWID? [S/N]: ${RESET}")" RESP

case "$RESP" in
    s|S|si|SI|sÃ­|SÃ­|y|Y)
        continue
        ;;
    *)
        break
        ;;
esac

done
