#!/bin/bash
#==================================================
# MoviVIP Network Premium
# Cambiar HWID de un usuario existente
# (El cliente cambiÃ³ de dispositivo â†’ nuevo HWID)
# La contraseÃ±a se REGENERA automÃ¡ticamente desde
# el nuevo HWID. La cuenta vieja deja de funcionar.
#==================================================

#======== COLORES ========#
GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
CYAN="\e[1;96m"
MAGENTA="\e[1;95m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"
RESET="\e[0m"

#======== CONFIG ========#

BASE="/etc/movivip"
CONFIG="$BASE/config.conf"
HWID_DIR="$BASE/hwids"

# Cargar idioma
if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)"
fi

[[ -f "$CONFIG" ]] && source "$CONFIG"

if [[ -z "$HWID_SECRET" ]]; then
    echo -e "${RED}âŒ No hay HWID_SECRET en config.conf. Crea una cuenta HWID primero.${RESET}"
    sleep 3
    exit 1
fi

#==================================================
# DERIVAR CONTRASEÃ‘A (misma fÃ³rmula que add_hwid.sh)
#==================================================
derive_pass() {
    local HW="$1"
    echo -n "${HW}|${HWID_SECRET}" | sha256sum | cut -c1-14
}

clear

echo -e "${CYAN}â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—${RESET}"
echo -e "${CYAN}â•‘${MAGENTA}               âšœï¸ MoviVIP Network âšœï¸                ${CYAN}â•‘${RESET}"
echo -e "${CYAN}â•‘${WHITE}            CAMBIAR HWID DE USUARIO ðŸ”„               ${CYAN}â•‘${RESET}"
echo -e "${CYAN}â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${RESET}"
echo

if [[ ! -d "$HWID_DIR" ]] || [[ -z "$(ls -A "$HWID_DIR" 2>/dev/null)" ]]; then
    echo -e "${YELLOW}  ðŸ“­ No hay usuarios por HWID registrados todavÃ­a.${RESET}"
    echo
    read -rp "$(echo -e "${YELLOW}Pulse Enter para volver...${RESET}")"
    exit 0
fi

#==================================================
# LISTAR usuarios HWID numerados
#==================================================

count=0
declare -A HWID_MENU      # numero -> usuario

for f in "$HWID_DIR"/*.hwid; do
    [[ -e "$f" ]] || continue
    count=$((count + 1))
    U=$(grep -m1 "^USER:" "$f" | cut -d' ' -f2)
    HW=$(grep -m1 "^HWID:" "$f" | cut -d' ' -f2)
    EX=$(grep -m1 "^EXPIRE:" "$f" | cut -d' ' -f2)
    HWID_MENU["$count"]="$U"
    printf "${CYAN}â•‘ ${WHITE}%02d) ${GREEN}%-12s${WHITE} â”‚ HWID: ${YELLOW}%-22s${WHITE} â”‚ Exp: ${GREEN}%s${RESET}\n" "$count" "$U" "$HW" "$EX"
done

echo
echo -e "${WHITE}  Total: ${GREEN}$count${WHITE} usuario(s) por HWID${RESET}"
echo
read -rp "$(echo -e "${CYAN}âžœ ${GOLD}Seleccione el usuario${WHITE} âž¤ ${RESET}")" SEL

if [[ -z "${HWID_MENU[$SEL]:-}" ]]; then
    echo
    echo -e "${RED}âŒ SelecciÃ³n invÃ¡lida.${RESET}"
    sleep 2
    exit 1
fi

USER="${HWID_MENU[$SEL]}"

if ! id "$USER" &>/dev/null; then
    echo
    echo -e "${RED}âŒ El usuario $USER no existe en el sistema (Â¿eliminado?).${RESET}"
    sleep 2
    exit 1
fi

#==================================================
# NUEVO HWID
#==================================================

echo
echo -e "${YELLOW}ðŸ“² Nuevo HWID del dispositivo (HTTP Custom â†’ Ajustes â†’ HWID)${RESET}"
read -rp "$(echo -e "${GREEN}ðŸ”’ Nuevo HWID        : ${RESET}")" NEWHWID

if [[ -z "$NEWHWID" ]]; then
    echo
    echo -e "${RED}âŒ Debe ingresar el nuevo HWID.${RESET}"
    sleep 2
    exit 1
fi

if ! [[ "$NEWHWID" =~ ^[A-Za-z0-9_:.-]+$ ]] || [[ ${#NEWHWID} -lt 4 ]] || [[ ${#NEWHWID} -gt 64 ]]; then
    echo
    echo -e "${RED}âŒ HWID invÃ¡lido (solo letras, nÃºmeros y _ : . - ; de 4 a 64 caracteres).${RESET}"
    sleep 2
    exit 1
fi

# HWID ya registrado en OTRA cuenta?
DUPLICADO=$(grep -rl "^HWID: $NEWHWID$" "$HWID_DIR" 2>/dev/null | grep -v "/$USER.hwid$" | head -n1)
if [[ -n "$DUPLICADO" ]]; then
    echo
    echo -e "${RED}âŒ Ese HWID ya estÃ¡ registrado en: $(basename "$DUPLICADO" .hwid)${RESET}"
    sleep 3
    exit 1
fi

#==================================================
# REGENERAR CONTRASEÃ‘A + ACTUALIZAR REGISTRO
#==================================================

OLDPASS=$(derive_pass "$(grep -m1 "^HWID:" "$HWID_DIR/$USER.hwid" | cut -d' ' -f2)")
NEWPASS=$(derive_pass "$NEWHWID")

# Bloquear sesiones activas del usuario antes de cambiar
pkill -u "$USER" >/dev/null 2>&1

# Establecer contrasena sin validacion PAM (compatible ARM)
HASH=$(openssl passwd -6 "$NEWPASS" 2>/dev/null)
usermod -p "$HASH" "$USER"

if [[ $? -ne 0 ]]; then
    echo
    echo -e "${RED}âŒ Error al regenerar la contraseÃ±a.${RESET}"
    sleep 3
    exit 1
fi

# Actualizar registro .hwid (preservar EXPIRE/MAXCONN/CREATED)
EXPIRE=$(grep -m1 "^EXPIRE:" "$HWID_DIR/$USER.hwid" | cut -d' ' -f2)
MAXCONN=$(grep -m1 "^MAXCONN:" "$HWID_DIR/$USER.hwid" | cut -d' ' -f2)
CREATED=$(grep -m1 "^CREATED:" "$HWID_DIR/$USER.hwid" | cut -d' ' -f2)
[[ -z "$MAXCONN" ]] && MAXCONN=2

cat > "$HWID_DIR/$USER.hwid" <<EOF
# MoviVIP Network - Usuario por HWID (v2)
USER: $USER
HWID: $NEWHWID
PASS: $NEWPASS
EXPIRE: $EXPIRE
MAXCONN: $MAXCONN
CREATED: $CREATED
CHANGED: $(date +"%Y-%m-%d %H:%M:%S")
EOF

clear

echo -e "${CYAN}â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—${RESET}"
echo -e "${CYAN}â•‘${MAGENTA}               âšœï¸ MoviVIP Network âšœï¸                ${CYAN}â•‘${RESET}"
echo -e "${CYAN}â•‘${WHITE}           HWID CAMBIADO CON Ã‰XITO âœ…                 ${CYAN}â•‘${RESET}"
echo -e "${CYAN}â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${RESET}"
echo

echo -e "${YELLOW}              ðŸ‘¤ CUENTA REGENERADA (Usuario + HWID + DÃ­as)${RESET}"
echo -e "${CYAN}â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”${RESET}"
printf "${WHITE}â”‚ ðŸ‘¤ Usuario      : ${GREEN}%-35s${WHITE}â”‚\n" "$USER"
printf "${WHITE}â”‚ ðŸ”’ HWID (nuevo) : ${GREEN}%-35s${WHITE}â”‚\n" "$NEWHWID"
printf "${WHITE}â”‚ ðŸ“… Expira       : ${GREEN}%-35s${WHITE}â”‚\n" "$EXPIRE"
echo -e "${CYAN}â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜${RESET}"
echo

echo -e "${YELLOW}       ðŸ” NUEVA CONTRASEÃ‘A GENERADA (NO compartir)${RESET}"
echo -e "${CYAN}â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”${RESET}"
printf "${WHITE}â”‚ ðŸ”‘ ContraseÃ±a   : ${MAGENTA}%-35s${WHITE}â”‚\n" "$NEWPASS"
echo -e "${CYAN}â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜${RESET}"
echo

echo -e "${GREEN}  âœ… El config del cliente DEBE actualizarse con:${RESET}"
IP=$(curl -4 -s ifconfig.me)
[[ -z "$IP" ]] && IP=$(hostname -I | awk '{print $1}')
HOST="${SERVER_DOMAIN:-$IP}"
printf "${GREEN}  ðŸ“² %s:80@%s:%s${RESET}\n" "$IP" "$USER" "$NEWPASS"
echo
echo -e "${RED}  âš  El config anterior (con el HWID viejo) YA NO FUNCIONA.${RESET}"
echo
read -rp "$(echo -e "${YELLOW}Pulse Enter para volver...${RESET}")"
exit 0
