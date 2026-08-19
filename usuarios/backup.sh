#!/bin/bash
#==================================================
# MoviVIP Network
# Backup de Usuarios SSH
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

BACKUP_DIR="/root/MoviVIP-backups"

#======== CONFIG ========#
BASE="/etc/movivip"

# Cargar idioma
if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)"
fi

mkdir -p "$BACKUP_DIR"

while true; do

clear

echo -e "${CYAN}â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—${RESET}"
echo -e "${CYAN}â•‘${MAGENTA}             ðŸ’¾ BACKUP DE USUARIOS SSH ðŸ’¾               ${CYAN}â•‘${RESET}"
echo -e "${CYAN}â• â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•£${RESET}"

echo -e "${GREEN}[1]${WHITE} Crear Backup"
echo -e "${BLUE}[2]${WHITE} Restaurar Backup"
echo -e "${YELLOW}[3]${WHITE} Ver Backups"
echo -e "${RED}[4]${WHITE} Eliminar Backup"
echo -e "${CYAN}[0]${WHITE} Regresar"

echo
read -rp "$(echo -e "${GREEN}Seleccione una opciÃ³n:${RESET} ")" OP

case "$OP" in

1)

FECHA=$(date +%d-%m-%Y_%H-%M-%S)
ARCHIVO="$BACKUP_DIR/backup_$FECHA.tar.gz"

tar -czf "$ARCHIVO" \
/etc/passwd \
/etc/shadow \
/etc/group \
/etc/gshadow 2>/dev/null

echo
echo -e "${GREEN}âœ” Backup creado correctamente.${RESET}"
echo -e "${WHITE}Archivo:${GREEN} $ARCHIVO${RESET}"

sleep 3
;;

2)

clear

echo -e "${CYAN}â•â•â•â•â•â•â•â•â•â•â•â•â•â• BACKUPS DISPONIBLES â•â•â•â•â•â•â•â•â•â•â•â•â•â•${RESET}"
echo

mapfile -t LISTA < <(ls -1 "$BACKUP_DIR"/*.tar.gz 2>/dev/null)

if [ ${#LISTA[@]} -eq 0 ]; then
    echo -e "${RED}No existen backups.${RESET}"
    sleep 2
    continue
fi

i=1
for FILE in "${LISTA[@]}"; do
    echo "[$i] $(basename "$FILE")"
    ((i++))
done

echo
read -rp "Seleccione: " NUM

FILE="${LISTA[$((NUM-1))]}"

[[ -z "$FILE" ]] && {
echo -e "${RED}SelecciÃ³n invÃ¡lida.${RESET}"
sleep 2
continue
}

read -rp "Â¿Restaurar este backup? [S/N]: " RESP

case "$RESP" in
s|S|si|SI|sÃ­|SÃ­)

tar -xzf "$FILE" -C /

echo
echo -e "${GREEN}âœ” Backup restaurado correctamente.${RESET}"
sleep 3
;;

*)
echo
echo -e "${YELLOW}OperaciÃ³n cancelada.${RESET}"
sleep 2
;;
esac
;;

3)

clear

echo -e "${CYAN}â•â•â•â•â•â•â•â•â•â•â•â•â•â• LISTA DE BACKUPS â•â•â•â•â•â•â•â•â•â•â•â•â•â•${RESET}"
echo

if ls "$BACKUP_DIR"/*.tar.gz >/dev/null 2>&1; then

for FILE in "$BACKUP_DIR"/*.tar.gz
do

SIZE=$(du -h "$FILE" | awk '{print $1}')
DATE=$(date -r "$FILE" +"%d/%m/%Y %H:%M")

echo -e "${GREEN}$(basename "$FILE")${RESET}"
echo -e " ${WHITE}TamaÃ±o:${GREEN} $SIZE"
echo -e " ${WHITE}Fecha :${GREEN} $DATE"
echo

done

else

echo -e "${RED}No existen backups.${RESET}"

fi

read -n1 -s -r -p "Presione cualquier tecla..."
;;

4)

clear

mapfile -t LISTA < <(ls -1 "$BACKUP_DIR"/*.tar.gz 2>/dev/null)

if [ ${#LISTA[@]} -eq 0 ]; then
    echo -e "${RED}No existen backups.${RESET}"
    sleep 2
    continue
fi

echo -e "${CYAN}â•â•â•â•â•â•â•â•â•â•â•â•â•â• ELIMINAR BACKUP â•â•â•â•â•â•â•â•â•â•â•â•â•â•${RESET}"
echo

i=1
for FILE in "${LISTA[@]}"
do
echo "[$i] $(basename "$FILE")"
((i++))
done

echo
read -rp "Seleccione: " NUM

FILE="${LISTA[$((NUM-1))]}"

[[ -z "$FILE" ]] && {
echo -e "${RED}SelecciÃ³n invÃ¡lida.${RESET}"
sleep 2
continue
}

rm -f "$FILE"

echo
echo -e "${GREEN}âœ” Backup eliminado.${RESET}"
sleep 2
;;

0)
exit
;;

*)

echo
echo -e "${RED}OpciÃ³n invÃ¡lida.${RESET}"
sleep 2
;;

esac

done
