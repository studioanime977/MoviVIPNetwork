#!/bin/bash
#==================================================
# MoviVIP Network
# Usuarios SSH Online v4.0 (OPTIMIZADO v4.3)
# (Conteo persistente via iptables + estado)
# Uso: online.sh [--quiet]  (--quiet = solo acumula, para cron)
#
# v4 fix (Ago 2026): medicion por UID de cuenta (uid-owner).
#  - v1/v2: regla iptables por puerto EFIMERO de cada socket
#    saliente del tunel (995+ sockets -> 3400+ reglas) +
#    forks iptables/sed por regla => ejecuciones de MINUTOS,
#    load >11 en 1 vCore, menu colgado.
#  - v3: media por IP del cliente, PERO los tuneles entran
#    via haproxy -> 127.0.0.1:22 (IP real invisible).
#  - v4: regla por UID de cuenta de sistema (--uid-owner).
#    Cada tunel corre como la cuenta del cliente (UID
#    estable) => pocas reglas, contadores persistentes.
#  - v4.1: renombra la variable del bucle a ACC_UID (UID es
#    readonly en bash).
#  - v4.3: SOLO cadena OUTPUT. En el backend nf_tables el
#    match --uid-owner NO existe en INPUT (skuid solo
#    OUTPUT/POSTROUTING): iptables -A en MOVIVIP_IN devuelve
#    "RULE_APPEND failed (Invalid argument)". El OUTPUT mide
#    el tunel completo (descarga+subida salen por el proceso
#    sshd de la cuenta), asi que es el consumo real.
#==================================================

QUIET=0
[[ "$1" == "--quiet" ]] && QUIET=1

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
SISTEMA="$BASE/sistema"
ST_TOTAL="$SISTEMA/consumo_usuarios.conf"    # USUARIO=BYTES
ST_SNAP="$SISTEMA/consumo_snapshots.conf"    # CLAVE|USUARIO|VALOR

mkdir -p "$SISTEMA" 2>/dev/null
touch "$ST_TOTAL" "$ST_SNAP" 2>/dev/null

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

# --- Cargar totales y snapshots EN MEMORIA (1 sola lectura c/u) ---
declare -A TOTAL_MEM      # USUARIO -> BYTES
declare -A SNAP_VAL       # CLAVE    -> VALOR
declare -A SNAP_USER      # CLAVE    -> USUARIO

while IFS='=' read -r U V; do
    [[ -n "$U" ]] && TOTAL_MEM["$U"]="$V"
done < "$ST_TOTAL"

while IFS='|' read -r KEY USUARIO VALOR; do
    [[ -z "$KEY" ]] && continue
    SNAP_VAL["$KEY"]="$VALOR"
    SNAP_USER["$KEY"]="$USUARIO"
done < "$ST_SNAP"

# --- Mapa de usuarios con HWID registrado (add_hwid.sh) ---
declare -A HWID_MEM      # USUARIO -> 1 (tiene HWID)
if [[ -d "$BASE/hwids" ]]; then
    for HF in "$BASE"/hwids/*.hwid; do
        [[ -e "$HF" ]] || continue
        HWID_MEM["$(basename "$HF" .hwid)"]="1"
    done
fi

#==================================================
# Cadenas de conteo (solo cuenta, no bloquea)
#==================================================

# --- Limpiar cadena IN legada (v4/v4.1 intentaba reglas en
#     INPUT que nft rechaza; el jump sobra) ---
iptables -D INPUT -j MOVIVIP_IN >/dev/null 2>&1
iptables -F MOVIVIP_IN >/dev/null 2>&1
iptables -X MOVIVIP_IN >/dev/null 2>&1

iptables -N MOVIVIP_OUT >/dev/null 2>&1
iptables -C OUTPUT -j MOVIVIP_OUT >/dev/null 2>&1 || iptables -I OUTPUT 1 -j MOVIVIP_OUT >/dev/null 2>&1

#==================================================
# SNAPSHOT UNICO de iptables (3 llamadas TOTALES)
#==================================================

OUT_DETAIL=$(iptables -L MOVIVIP_OUT -v -n -x 2>/dev/null)
# Formato save: "-A MOVIVIP_OUT -m owner --uid-owner 1005" (uid-owner + $NF=UID)
OUT_NAMES=$(iptables -S MOVIVIP_OUT 2>/dev/null)

#==================================================
# Mapear UID de cuenta -> sesiones sshd activas
# (los procesos sshd de tunel corren como la cuenta
#  del cliente; root/listener se ignoran)
#==================================================

declare -A UID_CONN      # UID -> numero de sesiones
declare -A UID_NAME      # UID -> nombre de cuenta

while read -r PID ACC_UID USER REST; do
    [[ -z "$PID" ]] && continue
    [[ "$REST" == *"[priv]"* ]] && continue
    [[ "$REST" == *"[accepted]"* ]] && continue
    [[ "$REST" == *"[net]"* ]] && continue
    [[ "$REST" == *"listener"* ]] && continue
    [[ "$ACC_UID" == "0" ]] && continue
    [[ "$USER" == "sshd" ]] && continue
    [[ "$ACC_UID" == "65534" ]] && continue          # nobody/unknown
    NAME=$(awk -F: -v u="$ACC_UID" '$3==u {print $1; exit}' /etc/passwd)
    [[ -z "$NAME" ]] && continue
    UID_CONN["$ACC_UID"]=$(( ${UID_CONN["$ACC_UID"]:-0} + 1 ))
    UID_NAME["$ACC_UID"]="$NAME"
done < <(ps -C sshd -o pid=,uid=,user=,args= 2>/dev/null)

#==================================================
# Acumular consumo (deltas desde ultimo snapshot)
#==================================================

accumulate() {
    local KEY="$1" U="$2" NOW="$3" OLD DELTA
    OLD="${SNAP_VAL[$KEY]:-}"
    if [[ -n "$OLD" ]]; then
        DELTA=$((NOW - OLD))
        [[ "$DELTA" -lt 0 ]] && DELTA=0
        TOTAL_MEM["$U"]=$(( ${TOTAL_MEM["$U"]:-0} + DELTA ))
    fi
    SNAP_VAL["$KEY"]="$NOW"
    SNAP_USER["$KEY"]="$U"
}

# --- Contadores de UIDs activos (iptables -L -v muestra
#     "... owner UID match 1007" con UID como ULTIMO campo;
#     $2 = bytes) ---
for ACC_UID in "${!UID_CONN[@]}"; do
    BOUT=$(awk -v u="$ACC_UID" '$NF==u && /owner UID match/ {print $2}' <<<"$OUT_DETAIL")
    BOUT=${BOUT:-0}
    accumulate "UID:$ACC_UID" "${UID_NAME[$ACC_UID]}" "$BOUT"
done

#==================================================
# APLICAR reglas por UID de cuenta activa.
# (Pocas reglas: una por cuenta conectada. Gestion
#  individual con -A; iptables-restore descarta
#  silenciosamente reglas sin -j en backend nft.)
#==================================================

EXISTING_UIDS=" $(awk '$0 ~ /uid-owner/ {print $NF}' <<<"$OUT_NAMES" | sort -u | tr '\n' ' ') "
for ACC_UID in "${!UID_CONN[@]}"; do
    if [[ "$EXISTING_UIDS" != *" $ACC_UID "* ]]; then
        iptables -A MOVIVIP_OUT -m owner --uid-owner "$ACC_UID" >/dev/null 2>&1
    fi
done

#==================================================
# Migrar/limpiar snapshots legacy (PORT:*, IP:*, UID:*
#  de cuentas que ya no tienen procesos)
#==================================================

# --- PORT:* legacy (reglas ya flusheadas) ---
for KEY in "${!SNAP_VAL[@]}"; do
    if [[ "$KEY" == PORT:* ]]; then
        PORT="${KEY#PORT:}"
        NOW=0   # reglas PORT:* ya flusheadas
        OLD="${SNAP_VAL[$KEY]:-0}"
        DELTA=$((NOW - OLD)); [[ "$DELTA" -lt 0 ]] && DELTA=0
        TOTAL_MEM["${SNAP_USER[$KEY]:-desconocido}"]=$(( ${TOTAL_MEM["${SNAP_USER[$KEY]:-desconocido}"]:-0} + DELTA ))
        unset SNAP_VAL["$KEY"]; unset SNAP_USER["$KEY"]
    elif [[ "$KEY" == IP:* ]]; then
        NOW=0   # reglas IP:* ya flusheadas
        OLD="${SNAP_VAL[$KEY]:-0}"
        DELTA=$((NOW - OLD)); [[ "$DELTA" -lt 0 ]] && DELTA=0
        TOTAL_MEM["${SNAP_USER[$KEY]:-desconocido}"]=$(( ${TOTAL_MEM["${SNAP_USER[$KEY]:-desconocido}"]:-0} + DELTA ))
        unset SNAP_VAL["$KEY"]; unset SNAP_USER["$KEY"]
    fi
done

# --- UID:* de cuentas ya desconectadas: delta final ---
for KEY in "${!SNAP_VAL[@]}"; do
    if [[ "$KEY" == UID:* ]]; then
        ACC_UID="${KEY#UID:}"
        [[ -n "${UID_CONN[$ACC_UID]}" ]] && continue
        NOW=$(awk -v u="$ACC_UID" '$NF==u && /owner UID match/ {print $2}' <<<"$OUT_DETAIL")
        NOW=${NOW:-0}
        OLD="${SNAP_VAL[$KEY]:-0}"
        DELTA=$((NOW - OLD)); [[ "$DELTA" -lt 0 ]] && DELTA=0
        TOTAL_MEM["${SNAP_USER[$KEY]:-desconocido}"]=$(( ${TOTAL_MEM["${SNAP_USER[$KEY]:-desconocido}"]:-0} + DELTA ))
        unset SNAP_VAL["$KEY"]; unset SNAP_USER["$KEY"]
    fi
done

# --- Reglas residuales uid-owner sin snapshot (limpieza extra) ---
for RULE_UID in $(awk '$0 ~ /uid-owner/ {print $NF}' <<<"$OUT_NAMES" | sort -u); do
    [[ -n "${UID_CONN[$RULE_UID]}" ]] && continue
    [[ -n "${SNAP_VAL["UID:$RULE_UID"]}" ]] && continue
    iptables -D MOVIVIP_OUT -m owner --uid-owner "$RULE_UID" >/dev/null 2>&1
    iptables -D MOVIVIP_IN  -m owner --uid-owner "$RULE_UID" >/dev/null 2>&1
done

#==================================================
# ESCRITURA UNICA del estado
#==================================================

> "$ST_TOTAL"
for U in "${!TOTAL_MEM[@]}"; do
    echo "$U=${TOTAL_MEM[$U]}" >> "$ST_TOTAL"
done

> "$ST_SNAP"
for KEY in "${!SNAP_VAL[@]}"; do
    echo "$KEY|${SNAP_USER[$KEY]}|${SNAP_VAL[$KEY]}" >> "$ST_SNAP"
done

# Salida silenciosa (modo cron): solo acumular consumo
if [[ $QUIET -eq 1 ]]; then
    exit 0
fi

USER_LIST=$(printf "%s\n" "${!UID_NAME[@]}" | sort -n)

# Icono candado si el usuario tiene HWID registrado
HICON() { [[ -n "${HWID_MEM[$1]:-}" ]] && echo "🔒" || echo "  "; }

clear

#==================================================
# 👁 USUARIOS ONLINE
#==================================================

echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${MAGENTA}              👁 USUARIOS ONLINE 👁              ${CYAN}║${RESET}"
echo -e "${CYAN}╠════╦════════════════════╦═══════════════════════╣${RESET}"

printf "${CYAN}║${WHITE} %-2s ${CYAN}║ ${WHITE}%-18s ${CYAN}║ ${WHITE}%-21s${CYAN}║${RESET}\n" \
"ID" "USUARIO" "CONEXIONES"

echo -e "${CYAN}╠════╬════════════════════╬═══════════════════════╣${RESET}"

TOTAL=0
ID=1

for ACC_UID in $USER_LIST; do
    CONN=${UID_CONN[$ACC_UID]}
    printf "${CYAN}║${WHITE} %02d ${CYAN}║ ${GREEN}%-16s%s${CYAN} ║ ${YELLOW}%-21s${CYAN}║${RESET}\n" \
    "$ID" "${UID_NAME[$ACC_UID]}" "$(HICON "${UID_NAME[$ACC_UID]}")" "$CONN"
    ((TOTAL++))
    ((ID++))
done

if [[ $TOTAL -eq 0 ]]; then
    echo -e "${CYAN}║${RED} No hay usuarios conectados.                  ${CYAN}║${RESET}"
fi

echo -e "${CYAN}╠════╩════════════════════╩═══════════════════════╣${RESET}"
echo -e "${WHITE} Usuarios Online : ${GREEN}$TOTAL${RESET}"
echo -e "${WHITE} Actualizado     : ${GREEN}$(date '+%d/%m/%Y %H:%M:%S')${RESET}"
echo -e "${GRAY} 🔒 = usuario con HWID registrado${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"

echo ""

#==================================================
# 📊 CONSUMO GB POR USUARIO
#==================================================

echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${MAGENTA}           📊 CONSUMO GB POR USUARIO 📊           ${CYAN}║${RESET}"
echo -e "${CYAN}╠════╦════════════════════╦══════════════════════════╣${RESET}"

printf "${CYAN}║${WHITE} %-2s ${CYAN}║ ${WHITE}%-18s ${CYAN}║ ${WHITE}%-12s ${CYAN}║ ${WHITE}%-12s${CYAN}║${RESET}\n" \
"ID" "USUARIO" "CONEXIONES" "CONSUMO"

echo -e "${CYAN}╠════╬════════════════════╬══════════════════════════╣${RESET}"

CID=1
CTOTAL=0
CGRAN=0

for ACC_UID in $USER_LIST; do
    NAME="${UID_NAME[$ACC_UID]}"
    CONN="${UID_CONN[$ACC_UID]}"
    TOTAL_USER="${TOTAL_MEM[$NAME]:-0}"
    CONSUMO_H=$(human "$TOTAL_USER")
    printf "${CYAN}║${WHITE} %02d ${CYAN}║ ${GREEN}%-16s%s${CYAN} ║ ${YELLOW}%-12s ${CYAN}║ ${MAGENTA}%-12s${CYAN}║${RESET}\n" \
    "$CID" "$NAME" "$(HICON "$NAME")" "$CONN" "$CONSUMO_H"
    CTOTAL=$((CTOTAL + TOTAL_USER))
    ((CID++))
    ((CGRAN++))
done

if [[ $CGRAN -eq 0 ]]; then
    echo -e "${CYAN}║${RED} Sin usuarios con consumo registrado.            ${CYAN}║${RESET}"
fi

echo -e "${CYAN}╠════╩════════════════════╩══════════════════════════╣${RESET}"
echo -e "${WHITE} Consumo Total   : ${GREEN}$(human "$CTOTAL")${RESET}"
echo -e "${WHITE} Actualizado     : ${GREEN}$(date '+%d/%m/%Y %H:%M:%S')${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"

echo
read -n1 -s -r -p "Presione cualquier tecla para regresar..."
