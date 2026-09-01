#!/bin/bash
#==================================================
# MoviVIP Network Premium
# Monitor de CUOTA de datos para cuentas HWID
# (puerto de limitTrafic()/limitarUsuario() de MoviVIP apiAccess)
#
# - Cuenta tráfico por usuario con cadenas iptables
#   (OUTPUT owner-match: el tráfico de túneles SSH se genera
#    con el UID del usuario tras el auth de sshd).
# - Acumula consumo en USED_BYTES dentro del .hwid
# - Si LIMIT_GB > 0 y consumo >= cuota → BLOQUEA la cuenta
#   (passwd -l + kill sesiones) y registra en hwid_bloqueos.log
#
# DOS MODOS:
#   * Cron / headless (sin TTY) → ejecuta el chequeo y sale.
#   * Desde el menú (TTY)      → chequea y muestra panel con
#     consumo, bloqueo/desbloqueo manual y log.
#==================================================

# ── i18n shim (auto) ───────────────────────────────
if ! declare -F trx >/dev/null 2>&1; then trx() { printf '%s' "$1"; }; fi
# ─────────────────────────────────────────────────────────
BASE="/etc/movivip"
HWID_DIR="$BASE/hwids"
LOG="$BASE/sistema/hwid_bloqueos.log"

CYAN="\e[1;96m"
GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
MAGENTA="\e[1;95m"
WHITE="\e[1;97m"
RESET="\e[0m"

mkdir -p "$HWID_DIR" "$BASE/sistema"

[[ -d "$HWID_DIR" ]] || exit 0
command -v iptables >/dev/null 2>&1 || exit 0

#--------------------------------------------------
# upsert_field ARCHIVO CAMPO VALOR
# Reemplaza o agrega "CAMPO: VALOR" sin duplicar
#--------------------------------------------------
upsert_field() {
    local FILE="$1" KEY="$2" VAL="$3"
    if grep -q "^${KEY}:" "$FILE" 2>/dev/null; then
        sed -i "s|^${KEY}:.*|${KEY}: ${VAL}|" "$FILE"
    else
        echo "${KEY}: ${VAL}" >> "$FILE"
    fi
}

#--------------------------------------------------
# check_all: recorre cuentas, cuenta tráfico, bloquea
#--------------------------------------------------
check_all() {

    shopt -s nullglob
    for f in "$HWID_DIR"/*.hwid; do

        U=$(grep -m1 "^USER:" "$f" | cut -d' ' -f2)
        [[ -z "$U" ]] && continue
        id "$U" &>/dev/null || continue

        UID_N=$(id -u "$U")

        # Cuota (0 = ilimitado)
        LIMIT_GB=$(grep -m1 "^LIMIT_GB:" "$f" | cut -d' ' -f2)
        [[ "$LIMIT_GB" =~ ^[0-9]+$ ]] || LIMIT_GB=0

        #--------------------------------------------------
        # Cadena iptables contadora (nombre máx 28 chars:
        # MV_HWID_ + 20 de usuario OK)
        #--------------------------------------------------
        CHAIN="MV_HWID_${U}"
        iptables -nL "$CHAIN" &>/dev/null || iptables -N "$CHAIN" 2>/dev/null
        iptables -S "$CHAIN" 2>/dev/null | grep -q "^-A.*-j RETURN" || \
            iptables -A "$CHAIN" -j RETURN 2>/dev/null
        iptables -C OUTPUT -m owner --uid-owner "$UID_N" -j "$CHAIN" 2>/dev/null || \
            iptables -I OUTPUT 1 -m owner --uid-owner "$UID_N" -j "$CHAIN" 2>/dev/null

        CUR=$(iptables -vxL "$CHAIN" 2>/dev/null | awk '/-j RETURN|RETURN /{print $2; exit}')
        [[ "$CUR" =~ ^[0-9]+$ ]] || CUR=0

        LAST=$(grep -m1 "^LAST_COUNTER:" "$f" | cut -d' ' -f2)
        [[ "$LAST" =~ ^[0-9]+$ ]] || LAST=0
        USED=$(grep -m1 "^USED_BYTES:" "$f" | cut -d' ' -f2)
        [[ "$USED" =~ ^[0-9]+$ ]] || USED=0

        if (( CUR >= LAST )); then
            DELTA=$((CUR - LAST))
        else
            DELTA=$CUR   # contador reiniciado (reboot) → todo lo actual es nuevo
        fi
        NEW_USED=$((USED + DELTA))

        upsert_field "$f" "USED_BYTES" "$NEW_USED"
        upsert_field "$f" "LAST_COUNTER" "$CUR"
        upsert_field "$f" "QUOTA_CHECK" "$(date +%s)"

        if (( LIMIT_GB > 0 )); then
            LIMIT_B=$((LIMIT_GB * 1073741824))
            YA_LOCKED=$(grep -m1 "^QUOTA_LOCKED:" "$f" | cut -d' ' -f2)

            if (( NEW_USED >= LIMIT_B )) && [[ "$YA_LOCKED" != "yes" ]]; then
                passwd -l "$U" >/dev/null 2>&1
                pkill -u "$U" >/dev/null 2>&1
                upsert_field "$f" "QUOTA_LOCKED" "yes"
                {
                    echo "$(date '+%Y-%m-%d %H:%M:%S') ⚠ CUOTA AGOTADA: $U consumió $(awk "BEGIN{printf \"%.2f\", $NEW_USED/1073741824}")GB de ${LIMIT_GB}GB → cuenta BLOQUEADA"
                } >> "$LOG"
            fi
        fi

    done
}

#--------------------------------------------------
# MODO HEADLESS (cron / systemd)
#--------------------------------------------------
if [[ ! -t 0 ]] && [[ -z "$FORCE_MENU" ]]; then
    check_all
    exit 0
fi

#--------------------------------------------------
# MODO MENÚ (interactivo)
#--------------------------------------------------
gb() { awk "BEGIN{printf \"%.2f\", $1/1073741824}"; }

listar_cuentas() {
    echo ""
    echo -e "${WHITE}┌──────────────────────────────────────────────────────────────┐${RESET}"
    echo -e "${WHITE}│ ${CYAN}USUARIO                USADO     LÍMITE     %    ESTADO${WHITE}        │${RESET}"
    echo -e "${WHITE}├──────────────────────────────────────────────────────────────┤${RESET}"
    shopt -s nullglob
    for f in "$HWID_DIR"/*.hwid; do
        U=$(grep -m1 "^USER:" "$f" | cut -d' ' -f2)
        [[ -z "$U" ]] && continue
        USED=$(grep -m1 "^USED_BYTES:" "$f" | cut -d' ' -f2); [[ "$USED" =~ ^[0-9]+$ ]] || USED=0
        LIM=$(grep -m1 "^LIMIT_GB:" "$f" | cut -d' ' -f2); [[ "$LIM" =~ ^[0-9]+$ ]] || LIM=0
        LOCK=$(grep -m1 "^QUOTA_LOCKED:" "$f" | cut -d' ' -f2)
        if (( LIM > 0 )); then
            PCT=$(awk "BEGIN{printf \"%d\", $USED/1073741824/$LIM*100}")
            [[ $PCT -gt 100 ]] && PCT=100
            LIMS=$(printf "%dGB" "$LIM")
        else
            PCT=0
            LIMS="∞"
        fi
        if [[ "$LOCK" == "yes" ]]; then
            ST="🔒 BLOQ."
            STC=$RED
        else
            ST="● activa"
            STC=$GREEN
        fi
        printf "${WHITE}│${GREEN} %-22s${WHITE} %-9s %-8s %3d%%  ${STC}%s${WHITE}  │${RESET}\n" "$U" "$(gb $USED)GB" "$LIMS" "$PCT" "$ST"
    done
    echo -e "${WHITE}└──────────────────────────────────────────────────────────────┘${RESET}"
    echo ""
}

ver_log() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${MAGENTA}           📜 LOG DE BLOQUEOS HWID${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    if [[ -f "$LOG" ]] && [[ -s "$LOG" ]]; then
        tail -30 "$LOG"
    else
        echo -e "${GREEN}✔ Sin bloqueos registrados.${RESET}"
    fi
    echo ""
}

desbloquear() {
    read -rp "$(trx ' Usuario a desbloquear: ')" U
    [[ -z "$U" ]] && return
    if id "$U" &>/dev/null; then
        passwd -u "$U" 2>/dev/null && echo -e "${GREEN}✅ $U desbloqueado.${RESET}" || echo -e "${RED}❌ Error.${RESET}"
        upsert_field "$HWID_DIR/$U.hwid" "QUOTA_LOCKED" "no"
        upsert_field "$HWID_DIR/$U.hwid" "USED_BYTES" "0"
    else
        echo -e "${RED}❌ El usuario $U no existe.${RESET}"
    fi
    sleep 2
}

bloquear() {
    read -rp "$(trx ' Usuario a bloquear: ')" U
    [[ -z "$U" ]] && return
    if id "$U" &>/dev/null; then
        passwd -l "$U" 2>/dev/null && echo -e "${RED}🔒 $U bloqueado.${RESET}" || echo -e "${RED}❌ Error.${RESET}"
        upsert_field "$HWID_DIR/$U.hwid" "QUOTA_LOCKED" "yes"
    else
        echo -e "${RED}❌ El usuario $U no existe.${RESET}"
    fi
    sleep 2
}

while true; do

clear
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${MAGENTA}       📈 MONITOR DE CUOTA HWID${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

check_all >/dev/null 2>&1
listar_cuentas

echo "$(trx ' [1] ➮ Re-chequear consumo ahora')"
echo "$(trx ' [2] ➮ Desbloquear cuenta')"
echo "$(trx ' [3] ➮ Bloquear cuenta manualmente')"
echo "$(trx ' [4] ➮ Ver log de bloqueos')"
echo ""
echo "$(trx ' [0] ➮ Regresar')"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

read -rp "$(trx ' ► Opción: ')" OP

case "$OP" in
1) check_all >/dev/null 2>&1; echo -e "${GREEN}✅ Chequeo completado.${RESET}"; sleep 1 ;;
2) desbloquear ;;
3) bloquear ;;
4) ver_log; read -n1 -r -p "$(trx 'Presione una tecla...')" ;;
0) exec bash "$BASE/herramientas/menu.sh" ;;
*) echo -e "${RED}❌ Opción inválida.${RESET}"; sleep 2 ;;
esac

done