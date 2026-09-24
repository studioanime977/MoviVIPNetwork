#!/bin/bash
#====================================================================
# usuarios/reactivar.sh — REACTIVAR USUARIOS SUSPENDIDOS
# MoviVIP Network v8.0
#
# La expiración exacta SUSPENDE (no elimina): bloquea login, conserva
# home. Este script lista los suspendidos (/etc/movivip/sistema/
# suspendidos.conf) y permite:
#   1) Reactivar con NUEVA duración (días/horas/minutos)
#   2) Reactivar SIN límite (expiración infinita)
#   3) Eliminar definitivamente (borra usuario + home + conf)
#====================================================================
BASE="/etc/movivip"
SUSP="$BASE/sistema/suspendidos.conf"
CONF="$BASE/sistema/expiraciones_exactas.conf"

GREEN="${MV_GRN:-\e[1;92m}"; RED="${MV_RED:-\e[1;91m}"; YELLOW="${MV_YLW:-\e[1;93m}"
BLUE="${MV_BLU:-\e[1;94m}"; CYAN="${MV_CYN:-\e[1;96m}"; MAGENTA="${MV_MAG:-\e[1;95m}"
WHITE="${MV_WHT:-\e[1;97m}"; GRAY="${MV_DIM:-\e[1;90m}"; RESET="${MV_R:-\e[0m}"

# i18n shim
if ! declare -F trx >/dev/null 2>&1; then trx() { printf '%s' "$1"; }; fi

[[ -f "$BASE/lib/ui.sh" ]] && source "$BASE/lib/ui.sh"
[[ -f "$BASE/lib/nav.sh" ]] && source "$BASE/lib/nav.sh" 2>/dev/null || true
[[ -f "$BASE/lib/duracion.sh" ]] && source "$BASE/lib/duracion.sh"
if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)"
fi

# ── Listar suspendidos: prioridad a suspendidos.conf, respaldo passwd -S ──
list_suspended() {
    declare -A _seen
    local U
    if [ -f "$SUSP" ]; then
        while IFS='|' read -r U TS; do
            [ -z "$U" ] && continue
            case "$U" in \#*) continue;; esac
            if id "$U" &>/dev/null 2>&1; then
                _seen["$U"]=1
                echo "$U|$TS|conf"
            fi
        done < "$SUSP"
    fi
    # Respaldo: usuarios con passwd bloqueado (L) que no están en el conf
    if command -v passwd >/dev/null 2>&1; then
        for U in $(awk -F: '$3>=1000 && $3<60000 && $1!="nobody" {print $1}' /etc/passwd 2>/dev/null); do
            [ -n "${_seen[$U]}" ] && continue
            if passwd -S "$U" 2>/dev/null | awk '{print $2}' | grep -q "L"; then
                echo "$U||lock"
            fi
        done
    fi
}

while true; do
clear
mv_brand_header "🔓 REACTIVAR USUARIOS SUSPENDIDOS ♻️" "$(trx 'Suspensión conserva datos · reactiva en segundos')"

mapfile -t SUSPS < <(list_suspended)
TOTAL="${#SUSPS[@]}"

echo -e "${GRAY}────────────────────────────────────────────────────────${RESET}"
if [ "$TOTAL" -eq 0 ]; then
    echo -e "${GREEN}✔ No hay usuarios suspendidos.${RESET}"
    echo
    read -n1 -s -r -p "$(trx 'Presione cualquier tecla...')"
    break
fi

echo -e "${CYAN}  ${WHITE}SUSPENDIDOS (${TOTAL})${RESET}"
echo -e "${GRAY}────────────────────────────────────────────────────────${RESET}"
i=1
for ENT in "${SUSPS[@]}"; do
    U="${ENT%%|*}"; REST="${ENT#*|}"
    TS="${REST%%|*}"
    ORIGIN="${REST##*|}"
    FECHA="—"
    [ -n "$TS" ] && [ "$TS" != "N" ] && FECHA=$(date -d "@${TS}" +"%d/%m/%Y %H:%M" 2>/dev/null || echo "—")
    TAG="conf"
    [ "$ORIGIN" = "lock" ] && TAG="lock"
    printf "${GREEN} %2d)${RESET} ${WHITE}%-20s${RESET} ${GRAY}%s${RESET} %s\n" "$i" "$U" "$FECHA" "$TAG"
    i=$((i+1))
done
echo -e "${GRAY}────────────────────────────────────────────────────────${RESET}"
echo

read -rp "$(echo -e "${YELLOW}${MV_OPT:-►} $(trx 'Usuario a reactivar (0 = volver)'):${RESET} ")" SEL
if [ -z "$SEL" ] || [ "$SEL" = "0" ]; then break; fi
if [[ ! "$SEL" =~ ^[0-9]+$ ]] || [ "$SEL" -lt 1 ] || [ "$SEL" -gt "$TOTAL" ]; then
    echo -e "${RED}✖ $(trx 'Selección inválida')${RESET}"; sleep 2; continue
fi

U="${SUSPS[$((SEL-1))]%%|*}"
if ! id "$U" &>/dev/null 2>&1; then
    echo -e "${RED}✖ El usuario no existe (¿fue eliminado?). Se limpia el registro.${RESET}"
    sed -i "/^${U}|/d" "$SUSP" 2>/dev/null
    sleep 2; continue
fi

clear
mv_brand_header "♻️ ACTIVAR: $U" "$(trx 'Elige cómo reactivar la cuenta')"
echo
echo -e "${GREEN}  1)${RESET} $(trx 'Reactivar con') ${YELLOW}NUEVA DURACIÓN${RESET} (días/horas/min)"
echo -e "${GREEN}  2)${RESET} $(trx 'Reactivar') ${YELLOW}SIN LÍMITE${RESET} (expiración infinita)"
echo -e "${GREEN}  3)${RESET} ${RED}$(trx 'ELIMINAR definitivamente')${RESET} (borra usuario + home)"
echo -e "${GREEN}  0)${RESET} $(trx 'Volver')"
echo
read -rp "$(echo -e "${YELLOW}$(trx 'Opción'):${RESET} ")" OP2

case "$OP2" in
1)
    if ! mv_ask_duracion; then
        echo -e "${YELLOW}← $(trx 'Cancelado')${RESET}"; sleep 1; continue
    fi
    NEW_FECHA="$DUR_FECHA_DIA"
    NEW_TS="$DUR_TS"
    ;;
2)
    NEW_FECHA="never"
    NEW_TS=""
    ;;
3)
    echo
    read -rp "$(echo -e "${RED}⚠ $(trx '¿Seguro que quieres BORRAR a') ${WHITE}$U${RED}? (s/N): ${RESET}")" OK
    [[ "$OK" =~ ^[sSyY]$ ]] || { echo -e "${YELLOW}← Cancelado${RESET}"; sleep 1; continue; }
    userdel -r "$U" >> "$BASE/sistema/expira-exacta.log" 2>&1
    sed -i "/^${U}|/d" "$SUSP" 2>/dev/null
    mv_clear_exp_exacta "$U" "$CONF"
    echo -e "${RED}☠ Usuario $U eliminado definitivamente.${RESET}"
    sleep 2; continue
    ;;
*) echo -e "${RED}✖ Opción inválida${RESET}"; sleep 1; continue;;
esac

# ── Aplicar reactivación ──
# 1) Desbloquear passwd (quitar L)
passwd -u "$U" >> "$BASE/sistema/expira-exacta.log" 2>&1
# 2) Fecha de expiración
if [ -n "$NEW_TS" ]; then
    chage -E "$NEW_FECHA" "$U" >> "$BASE/sistema/expira-exacta.log" 2>&1
    mv_save_exp_exacta "$U" "$NEW_TS" "$CONF"
    MSG="$DUR_MOSTRAR"
else
    chage -E -1 "$U" >> "$BASE/sistema/expira-exacta.log" 2>&1
    mv_clear_exp_exacta "$U" "$CONF"
    MSG="$(trx 'sin límite')"
fi
# 3) Quitar de suspendidos.conf
sed -i "/^${U}|/d" "$SUSP" 2>/dev/null
# 4) Log
echo "[$(date '+%Y-%m-%d %H:%M:%S')] REACTIVADO $U (expira: $MSG)" >> "$BASE/sistema/expira-exacta.log" 2>/dev/null

echo
echo -e "${GREEN}✔ Usuario ${WHITE}$U${GREEN} reactivado — expira: ${YELLOW}${MSG}${GREEN}${RESET}"
echo -e "${GRAY}$(trx 'Ya puede conectarse de nuevo.')${RESET}"
sleep 3
done

exit 0