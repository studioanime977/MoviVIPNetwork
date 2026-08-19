#!/bin/bash
#==================================================
# MoviVIP Network
# Editar / Renovar Usuario SSH
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

BASE="/etc/movivip"

# Cargar idioma
if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)"
fi

while true; do

clear

echo -e "${CYAN}â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—${RESET}"
echo -e "${CYAN}â•‘${YELLOW}           â™» EDITAR / RENOVAR USUARIO SSH          ${CYAN}â•‘${RESET}"
echo -e "${CYAN}â• â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•£${RESET}"

USERS=$(awk -F: '$3>=1000 && $1!="nobody"{print $1}' /etc/passwd)

if [[ -z "$USERS" ]]; then
    echo -e "${RED}No existen usuarios SSH.${RESET}"
    sleep 2
    exit
fi

i=1
declare -a LISTA

while read -r USER; do
    FECHA=$(chage -l "$USER" | grep "Account expires" | cut -d: -f2)
    printf "${GREEN}[%02d]${WHITE} %-18s ${GRAY}%s${RESET}\n" "$i" "$USER" "$FECHA"
    LISTA[$i]="$USER"
    ((i++))
done <<< "$USERS"

echo
read -rp "$(echo -e "${GREEN}Seleccione un usuario [0=Salir]: ${RESET}")" NUM

[[ "$NUM" == "0" ]] && exit

USER="${LISTA[$NUM]}"

if [[ -z "$USER" ]]; then
    echo
    echo -e "${RED}Usuario invÃ¡lido.${RESET}"
    sleep 2
    continue
fi

while true; do

clear

FECHA=$(chage -l "$USER" | grep "Account expires" | cut -d: -f2)

human() {
    local B=$1
    [[ -z "$B" ]] && B=0
    if [[ $B -ge 1073741824 ]]; then
        echo "$(awk "BEGIN{printf \"%.2f\", $B/1073741824}") GB"
    elif [[ $B -ge 1048576 ]]; then
        echo "$(awk "BEGIN{printf \"%.2f\", $B/1048576}") MB"
    elif [[ $B -ge 1024 ]]; then
        echo "$(awk "BEGIN{printf \"%.2f\", $B/1024}") KB"
    else
        echo "$B B"
    fi
}

# Cargar consumo total actual si existe el archivo
declare -A TOTAL_MEM
if [[ -f "$BASE/sistema/consumo_usuarios.conf" ]]; then
    while IFS='=' read -r U V; do
        [[ -n "$U" ]] && TOTAL_MEM["$U"]="$V"
    done < "$BASE/sistema/consumo_usuarios.conf"
fi
CONSUMO_ACTUAL="${TOTAL_MEM[$USER]:-0}"

# Cargar lÃ­mite de consumo
declare -A LIMIT_MEM
if [[ -f "$BASE/sistema/limites_consumo.conf" ]]; then
    while IFS='=' read -r U V; do
        [[ -n "$U" ]] && LIMIT_MEM["$U"]="$V"
    done < "$BASE/sistema/limites_consumo.conf"
fi
LIMITE_ACTUAL="${LIMIT_MEM[$USER]:-0}"

if [[ -z "$LIMITE_ACTUAL" || "$LIMITE_ACTUAL" == "0" ]]; then
    LIMITE_H="â™¾ Ilimitado"
else
    LIMITE_H="$(human "$LIMITE_ACTUAL")"
fi

# Cargar lÃ­mite de conexiones simultÃ¡neas
declare -A CONNLIM_MEM
if [[ -f "$BASE/sistema/limites_conexiones.conf" ]]; then
    while IFS='=' read -r U V; do
        [[ -n "$U" ]] && CONNLIM_MEM["$U"]="$V"
    done < "$BASE/sistema/limites_conexiones.conf"
fi
CONNLIM_ACTUAL="${CONNLIM_MEM[$USER]:-0}"

if [[ -z "$CONNLIM_ACTUAL" || "$CONNLIM_ACTUAL" == "0" ]]; then
    CONNLIM_H="â™¾ Ilimitado"
else
    CONNLIM_H="$CONNLIM_ACTUAL ConexiÃ³n(es)"
fi

echo -e "${CYAN}â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—${RESET}"
echo -e "${CYAN}â•‘${MAGENTA}             ðŸ‘¤ Usuario: ${WHITE}$USER${CYAN}                  â•‘${RESET}"
echo -e "${CYAN}â• â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•£${RESET}"
echo -e "${WHITE} Expira          : ${GREEN}$FECHA${RESET}"
echo -e "${WHITE} Consumo         : ${GREEN}$(human "$CONSUMO_ACTUAL")${RESET}"
echo -e "${WHITE} LÃ­mite consumo  : ${GREEN}$LIMITE_H${RESET}"
echo -e "${WHITE} LÃ­mite conexiÃ³n : ${GREEN}$CONNLIM_H${RESET}"
echo -e "${CYAN}â• â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•£${RESET}"

echo -e "${GREEN}[1]${WHITE} Cambiar contraseÃ±a"
echo -e "${YELLOW}[2]${WHITE} Renovar cuenta"
echo -e "${BLUE}[3]${WHITE} Cambiar contraseÃ±a y renovar"
echo -e "${MAGENTA}[4]${WHITE} Cambiar lÃ­mite de consumo"
echo -e "${CYAN}[5]${WHITE} Cambiar lÃ­mite de conexiones"
echo -e "${RED}[0]${WHITE} Volver"

echo
read -rp "$(echo -e "${GREEN}OpciÃ³n: ${RESET}")" OP

case "$OP" in

1)

read -rp "$(echo -e "${GREEN}Nueva contraseÃ±a: ${RESET}")" PASS
echo

[[ -z "$PASS" ]] && {
echo -e "${RED}ContraseÃ±a vacÃ­a.${RESET}"
sleep 2
continue
}

# Establecer contrasena sin validacion PAM (compatible ARM)
HASH=$(openssl passwd -6 "$PASS" 2>/dev/null)
usermod -p "$HASH" "$USER"

echo
echo -e "${GREEN}âœ” ContraseÃ±a actualizada.${RESET}"
sleep 2
;;

2)

read -rp "$(echo -e "${GREEN}DÃ­as a renovar: ${RESET}")" DIAS

[[ -z "$DIAS" ]] && DIAS=30

FECHA=$(date -d "+$DIAS days" +"%Y-%m-%d")

chage -E "$FECHA" "$USER"

echo
echo -e "${GREEN}âœ” Cuenta renovada hasta:${WHITE} $FECHA${RESET}"
sleep 2
;;

3)

read -rp "$(echo -e "${GREEN}Nueva contraseÃ±a: ${RESET}")" PASS
echo

read -rp "$(echo -e "${GREEN}DÃ­as a renovar: ${RESET}")" DIAS

[[ -z "$DIAS" ]] && DIAS=30

FECHA=$(date -d "+$DIAS days" +"%Y-%m-%d")

# Establecer contrasena sin validacion PAM (compatible ARM)
HASH=$(openssl passwd -6 "$PASS" 2>/dev/null)
usermod -p "$HASH" "$USER"
chage -E "$FECHA" "$USER"

echo
echo -e "${GREEN}âœ” Usuario actualizado correctamente.${RESET}"
echo -e "${WHITE} Usuario : ${GREEN}$USER"
echo -e "${WHITE} Expira  : ${GREEN}$FECHA"
sleep 3
;;

4)

clear

echo -e "${YELLOW}â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—${RESET}"
echo -e "${YELLOW}â•‘        ðŸ“¦ LÃMITE DE CONSUMO (DATOS)                  â•‘${RESET}"
echo -e "${YELLOW}â• â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•£${RESET}"
echo -e "${WHITE} Consumo actual : ${GREEN}$(human "$CONSUMO_ACTUAL")${RESET}"
echo -e "${WHITE} LÃ­mite actual  : ${GREEN}$LIMITE_H${RESET}"
echo -e "${YELLOW}â• â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•£${RESET}"
echo -e "${GREEN}[1]${WHITE} 100 GB"
echo -e "${GREEN}[2]${WHITE} 200 GB"
echo -e "${GREEN}[3]${WHITE} 500 GB"
echo -e "${GREEN}[4]${WHITE} 800 GB"
echo -e "${GREEN}[5]${WHITE} 1 TB"
echo -e "${GREEN}[6]${WHITE} â™¾ Ilimitado"
echo -e "${CYAN}â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${RESET}"

read -rp "$(echo -e "${GREEN}Nuevo lÃ­mite [6]: ${RESET}")" OPC_CONSUMO

[[ -z "$OPC_CONSUMO" ]] && OPC_CONSUMO=6

case "$OPC_CONSUMO" in
    1) NEW_BYTES=107374182400; NEW_H="100 GB" ;;
    2) NEW_BYTES=214748364800; NEW_H="200 GB" ;;
    3) NEW_BYTES=536870912000; NEW_H="500 GB" ;;
    4) NEW_BYTES=858993459200; NEW_H="800 GB" ;;
    5) NEW_BYTES=1099511627776; NEW_H="1 TB" ;;
    6|0) NEW_BYTES=0; NEW_H="â™¾ Ilimitado" ;;
    *)
        echo
        echo -e "${RED}âŒ OpciÃ³n invÃ¡lida.${RESET}"
        sleep 2
        continue
        ;;
esac

LIM_CONF="$BASE/sistema/limites_consumo.conf"
mkdir -p "$BASE/sistema" 2>/dev/null
touch "$LIM_CONF" 2>/dev/null

grep -v "^$USER=" "$LIM_CONF" > "$LIM_CONF.tmp" 2>/dev/null
mv "$LIM_CONF.tmp" "$LIM_CONF" 2>/dev/null
echo "$USER=$NEW_BYTES" >> "$LIM_CONF"

echo
echo -e "${GREEN}âœ” LÃ­mite de consumo actualizado:${WHITE} $NEW_H${RESET}"

# Si el nuevo lÃ­mite deja margen, desbloquear automÃ¡ticamente
if [[ "$NEW_BYTES" -gt "$CONSUMO_ACTUAL" || "$NEW_BYTES" == "0" ]]; then
    if passwd -S "$USER" 2>/dev/null | awk '{print $2}' | grep -q "L"; then
        passwd -u "$USER" >/dev/null 2>&1
        echo -e "${GREEN}âœ” Usuario desbloqueado (el lÃ­mite ya no estÃ¡ excedido).${RESET}"
    fi
fi

sleep 3
;;

5)

clear

echo -e "${YELLOW}â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—${RESET}"
echo -e "${YELLOW}â•‘        ðŸ‘¥ LÃMITE DE CONEXIONES SIMULTÃNEAS           â•‘${RESET}"
echo -e "${YELLOW}â• â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•£${RESET}"
echo -e "${WHITE} Usuario          : ${GREEN}$USER${RESET}"
echo -e "${WHITE} LÃ­mite actual    : ${GREEN}$CONNLIM_H${RESET}"
echo -e "${GRAY} Las conexiones que excedan el lÃ­mite se cortan,${RESET}"
echo -e "${GRAY} la cuenta NO se bloquea. 0 = ilimitado.${RESET}"
echo -e "${YELLOW}â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${RESET}"

read -rp "$(echo -e "${GREEN}Nuevo lÃ­mite de conexiones [0]: ${RESET}")" NEW_CONNLIM

[[ -z "$NEW_CONNLIM" ]] && NEW_CONNLIM=0

if ! [[ "$NEW_CONNLIM" =~ ^[0-9]+$ ]]; then
    echo
    echo -e "${RED}âŒ El lÃ­mite debe ser un nÃºmero.${RESET}"
    sleep 2
    continue
fi

CONN_LIM_CONF="$BASE/sistema/limites_conexiones.conf"
mkdir -p "$BASE/sistema" 2>/dev/null
touch "$CONN_LIM_CONF" 2>/dev/null

grep -v "^$USER=" "$CONN_LIM_CONF" > "$CONN_LIM_CONF.tmp" 2>/dev/null
mv "$CONN_LIM_CONF.tmp" "$CONN_LIM_CONF" 2>/dev/null
echo "$USER=$NEW_CONNLIM" >> "$CONN_LIM_CONF"

if [[ "$NEW_CONNLIM" == "0" ]]; then
    NEW_CONNLIM_H="â™¾ Ilimitado"
else
    NEW_CONNLIM_H="$NEW_CONNLIM ConexiÃ³n(es)"
fi

echo
echo -e "${GREEN}âœ” LÃ­mite de conexiones actualizado:${WHITE} $NEW_CONNLIM_H${RESET}"
sleep 3
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

break

done
