#!/bin/bash
#==================================================
# MoviVIP Network
# Usuarios SSH Online v4 + Consumo GB por usuario
# (Conteo persistente via iptables + estado)
# Uso: online.sh [--quiet]  (--quiet = solo acumula, para cron)
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

get_total()  { grep -E "^$1=" "$ST_TOTAL" 2>/dev/null | cut -d= -f2 | head -1; }
get_snap()   { grep -E "^$1\|" "$ST_SNAP" 2>/dev/null | cut -d'|' -f3 | head -1; }
get_snap_u() { grep -E "^$1\|" "$ST_SNAP" 2>/dev/null | cut -d'|' -f2 | head -1; }

add_total() {
    local U="$1" DELTA="$2" OLD
    [[ -z "$DELTA" || "$DELTA" -lt 0 ]] && DELTA=0
    OLD=$(get_total "$U")
    OLD=${OLD:-0}
    sed -i "/^$U=/d" "$ST_TOTAL" 2>/dev/null
    echo "$U=$((OLD + DELTA))" >> "$ST_TOTAL"
}

set_snap() {
    local KEY="$1" U="$2" VAL="$3"
    sed -i "/^$KEY|/d" "$ST_SNAP" 2>/dev/null
    echo "$KEY|$U|$VAL" >> "$ST_SNAP"
}

#==================================================
# Cadenas de conteo (solo cuenta, no bloquea)
#==================================================

iptables -N MOVIVIP_IN >/dev/null 2>&1
iptables -N MOVIVIP_OUT >/dev/null 2>&1
iptables -C INPUT -j MOVIVIP_IN >/dev/null 2>&1 || iptables -I INPUT 1 -j MOVIVIP_IN >/dev/null 2>&1
iptables -C OUTPUT -j MOVIVIP_OUT >/dev/null 2>&1 || iptables -I OUTPUT 1 -j MOVIVIP_OUT >/dev/null 2>&1

VPS_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
SERVICE_PORTS="22 90 109 143 5300"

#==================================================
# Mapear PID -> usuario (procesos sshd activos)
#==================================================

declare -A PID_USER
declare -A USERS

while read -r PID USER REST; do
    [[ -z "$PID" ]] && continue
    [[ "$REST" == *"[priv]"* ]] && continue
    [[ "$REST" == *"[accepted]"* ]] && continue
    [[ "$REST" == *"[net]"* ]] && continue
    [[ "$REST" == *"listener"* ]] && continue
    U=$(echo "$REST" | sed 's/sshd: //; s/@.*//')
    [[ -z "$U" ]] && continue
    [[ "$U" == "root" ]] && continue
    [[ "$U" == "unknown" ]] && continue
    [[ "$U" == "invalid" ]] && continue
    [[ "$U" == "(null)" ]] && continue
    PID_USER["$PID"]="$U"
    ((USERS["$U"]++))
done < <(ps -C sshd -o pid=,user=,args= 2>/dev/null)

#==================================================
# Conexiones activas: IP real o puerto de túnel
#==================================================

declare -A USER_IPS
declare -A USER_RULES
declare -A ACTIVE_IPS
declare -A ACTIVE_PORTS

while read -r ST RECV SEND LOCAL PEER INFO; do
    LOCAL_IP=$(echo "$LOCAL" | cut -d: -f1)
    LOCAL_PORT=$(echo "$LOCAL" | rev | cut -d: -f1 | rev)
    PEER_IP=$(echo "$PEER" | cut -d: -f1)
    [[ "$PEER_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || continue
    [[ "$PEER_IP" == "$VPS_IP" ]] && continue
    [[ "$PEER_IP" == "127.0.0.1" ]] && continue
    [[ "$LOCAL_IP" == "127.0.0.1" ]] && continue

    for PID in $(echo "$INFO" | grep -oE 'pid=[0-9]+' | cut -d= -f2); do
        U="${PID_USER[$PID]}"
        [[ -n "$U" ]] || continue

        if [[ " $SERVICE_PORTS " == *" $LOCAL_PORT "* && "$LOCAL_IP" == "$VPS_IP" ]]; then
            # Conexión entrante real: cuenta por IP del cliente
            USER_IPS["$U"]="$PEER_IP"
            ACTIVE_IPS["$PEER_IP"]=1
            [[ -z "${USER_RULES[$U]}" ]] && USER_RULES["$U"]="IP:$PEER_IP" || USER_RULES["$U"]+="|IP:$PEER_IP"
        else
            # Túnel saliente: cuenta por puerto local del socket
            USER_IPS["$U"]="${USER_IPS[$U]:-$PEER_IP}"
            ACTIVE_PORTS["$LOCAL_PORT"]=1
            USER_RULES["$U"]+="|PORT:$LOCAL_PORT"
        fi
    done
done < <(ss -tnp 2>/dev/null | grep "sshd")

#==================================================
# Acumular consumo (deltas desde último snapshot)
#==================================================

accumulate_rule() {
    local KEY="$1" U="$2" NOW="$3"
    local OLD DELTA
    OLD=$(get_snap "$KEY")
    if [[ -n "$OLD" ]]; then
        DELTA=$((NOW - OLD))
        [[ "$DELTA" -lt 0 ]] && DELTA=0
        add_total "$U" "$DELTA"
    fi
    set_snap "$KEY" "$U" "$NOW"
}

# --- Reglas por IP activa (conexión entrante real) ---
for IP in "${!ACTIVE_IPS[@]}"; do
    iptables -C MOVIVIP_IN -s "$IP" >/dev/null 2>&1 || iptables -A MOVIVIP_IN -s "$IP" >/dev/null 2>&1
    iptables -C MOVIVIP_OUT -d "$IP" >/dev/null 2>&1 || iptables -A MOVIVIP_OUT -d "$IP" >/dev/null 2>&1
    BIN=$(iptables -L MOVIVIP_IN -v -n -x 2>/dev/null | awk -v ip="$IP" '$0 ~ " "ip" " {print $2}')
    BOUT=$(iptables -L MOVIVIP_OUT -v -n -x 2>/dev/null | awk -v ip="$IP" '$0 ~ " "ip" " {print $2}')
    BIN=${BIN:-0}; BOUT=${BOUT:-0}
    OWNER=""
    for U in $(printf "%s\n" "${!USER_IPS[@]}"); do
        [[ "${USER_IPS[$U]}" == "$IP" ]] && OWNER="$U" && break
    done
    [[ -z "$OWNER" ]] && OWNER="desconocido"
    accumulate_rule "IP:$IP" "$OWNER" $((BIN + BOUT))
done

# --- Reglas por puerto activo (túnel saliente) ---
for PORT in "${!ACTIVE_PORTS[@]}"; do
    iptables -C MOVIVIP_IN -p tcp --dport "$PORT" >/dev/null 2>&1 || iptables -A MOVIVIP_IN -p tcp --dport "$PORT" >/dev/null 2>&1
    iptables -C MOVIVIP_OUT -p tcp --sport "$PORT" >/dev/null 2>&1 || iptables -A MOVIVIP_OUT -p tcp --sport "$PORT" >/dev/null 2>&1
    BIN=$(iptables -L MOVIVIP_IN -v -n -x 2>/dev/null | awk -v p="dpt:$PORT" '$NF == p {print $2}')
    BOUT=$(iptables -L MOVIVIP_OUT -v -n -x 2>/dev/null | awk -v p="spt:$PORT" '$NF == p {print $2}')
    BIN=${BIN:-0}; BOUT=${BOUT:-0}
    OWNER=""
    for U in $(printf "%s\n" "${!USERS[@]}"); do
        [[ "${USER_RULES[$U]}" == *"PORT:$PORT"* ]] && OWNER="$U" && break
    done
    [[ -z "$OWNER" ]] && OWNER="desconocido"
    accumulate_rule "PORT:$PORT" "$OWNER" $((BIN + BOUT))
done

#==================================================
# Limpieza de snapshots huérfanos (acumula delta final)
#==================================================

cp "$ST_SNAP" "$ST_SNAP.tmp" 2>/dev/null
while IFS='|' read -r KEY USUARIO VALOR; do
    [[ -z "$KEY" ]] && continue
    if [[ "$KEY" == PORT:* ]]; then
        PORT="${KEY#PORT:}"
        [[ -n "${ACTIVE_PORTS[$PORT]}" ]] && continue
        if iptables -C MOVIVIP_IN -p tcp --dport "$PORT" >/dev/null 2>&1; then
            NOW=$(iptables -L MOVIVIP_IN -v -n -x 2>/dev/null | awk -v p="dpt:$PORT" '$NF == p {print $2}')
            NOW=${NOW:-0}
            DELTA=$((NOW - VALOR)); [[ "$DELTA" -lt 0 ]] && DELTA=0
            add_total "$USUARIO" "$DELTA"
            iptables -D MOVIVIP_IN -p tcp --dport "$PORT" >/dev/null 2>&1
            iptables -D MOVIVIP_OUT -p tcp --sport "$PORT" >/dev/null 2>&1
        fi
        sed -i "/^$KEY|/d" "$ST_SNAP" 2>/dev/null
    elif [[ "$KEY" == IP:* ]]; then
        IP="${KEY#IP:}"
        [[ -n "${ACTIVE_IPS[$IP]}" ]] && continue
        if iptables -C MOVIVIP_IN -s "$IP" >/dev/null 2>&1; then
            NOW=$(iptables -L MOVIVIP_IN -v -n -x 2>/dev/null | awk -v ip="$IP" '$0 ~ " "ip" " {print $2}')
            NOW=${NOW:-0}
            DELTA=$((NOW - VALOR)); [[ "$DELTA" -lt 0 ]] && DELTA=0
            add_total "$USUARIO" "$DELTA"
            iptables -D MOVIVIP_IN -s "$IP" >/dev/null 2>&1
            iptables -D MOVIVIP_OUT -d "$IP" >/dev/null 2>&1
        fi
        sed -i "/^$KEY|/d" "$ST_SNAP" 2>/dev/null
    fi
done < "$ST_SNAP.tmp"
rm -f "$ST_SNAP.tmp" 2>/dev/null

# --- Reglas residuales sin snapshot (de versiones viejas) ---
for RULE_PORT in $(iptables -L MOVIVIP_IN -n 2>/dev/null | sed -n 's/.*dpt:\([0-9]*\).*/\1/p' | sort -u); do
    if [[ -z "${ACTIVE_PORTS[$RULE_PORT]}" ]] && ! grep -q "^PORT:$RULE_PORT|" "$ST_SNAP" 2>/dev/null; then
        NOW=$(iptables -L MOVIVIP_IN -v -n -x 2>/dev/null | awk -v p="dpt:$RULE_PORT" '$NF == p {print $2}')
        NOW=${NOW:-0}
        add_total "desconocido" "$NOW"
        iptables -D MOVIVIP_IN -p tcp --dport "$RULE_PORT" >/dev/null 2>&1
        iptables -D MOVIVIP_OUT -p tcp --sport "$RULE_PORT" >/dev/null 2>&1
    fi
done
for RULE_IP in $(iptables -L MOVIVIP_IN -n 2>/dev/null | awk '$1=="all" && $2=="--" && $3 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ {print $3}' | sort -u); do
    if [[ -z "${ACTIVE_IPS[$RULE_IP]}" ]] && ! grep -q "^IP:$RULE_IP|" "$ST_SNAP" 2>/dev/null; then
        NOW=$(iptables -L MOVIVIP_IN -v -n -x 2>/dev/null | awk -v ip="$RULE_IP" '$0 ~ " "ip" " {print $2}')
        NOW=${NOW:-0}
        add_total "desconocido" "$NOW"
        iptables -D MOVIVIP_IN -s "$RULE_IP" >/dev/null 2>&1
        iptables -D MOVIVIP_OUT -d "$RULE_IP" >/dev/null 2>&1
    fi
done

# Salida silenciosa (modo cron): solo acumular consumo
if [[ $QUIET -eq 1 ]]; then
    exit 0
fi

USER_LIST=$(printf "%s\n" "${!USERS[@]}" | sort)

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

for USER in $USER_LIST; do
    CONN=${USERS[$USER]}
    printf "${CYAN}║${WHITE} %02d ${CYAN}║ ${GREEN}%-18s ${CYAN}║ ${YELLOW}%-21s${CYAN}║${RESET}\n" \
    "$ID" "$USER" "$CONN"
    ((TOTAL++))
    ((ID++))
done

if [[ $TOTAL -eq 0 ]]; then
    echo -e "${CYAN}║${RED} No hay usuarios conectados.                  ${CYAN}║${RESET}"
fi

echo -e "${CYAN}╠════╩════════════════════╩═══════════════════════╣${RESET}"
echo -e "${WHITE} Usuarios Online : ${GREEN}$TOTAL${RESET}"
echo -e "${WHITE} Actualizado     : ${GREEN}$(date '+%d/%m/%Y %H:%M:%S')${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"

echo ""

#==================================================
# 📊 CONSUMO GB POR USUARIO
#==================================================

echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${MAGENTA}           📊 CONSUMO GB POR USUARIO 📊           ${CYAN}║${RESET}"
echo -e "${CYAN}╠════╦════════════════════╦════════════╦══════════════╣${RESET}"

printf "${CYAN}║${WHITE} %-2s ${CYAN}║ ${WHITE}%-18s ${CYAN}║ ${WHITE}%-10s ${CYAN}║ ${WHITE}%-12s${CYAN}║${RESET}\n" \
"ID" "USUARIO" "IP" "CONSUMO"

echo -e "${CYAN}╠════╬════════════════════╬════════════╬══════════════╣${RESET}"

CID=1
CTOTAL=0
CGRAN=0

for USER in $USER_LIST; do
    IP_VISIBLE="${USER_IPS[$USER]:--}"
    TOTAL_USER=$(get_total "$USER")
    TOTAL_USER=${TOTAL_USER:-0}
    CONSUMO_H=$(human "$TOTAL_USER")
    printf "${CYAN}║${WHITE} %02d ${CYAN}║ ${GREEN}%-18s ${CYAN}║ ${YELLOW}%-10s ${CYAN}║ ${MAGENTA}%-12s${CYAN}║${RESET}\n" \
    "$CID" "$USER" "$IP_VISIBLE" "$CONSUMO_H"
    CTOTAL=$((CTOTAL + TOTAL_USER))
    ((CID++))
    ((CGRAN++))
done

if [[ $CGRAN -eq 0 ]]; then
    echo -e "${CYAN}║${RED} Sin usuarios con consumo registrado.            ${CYAN}║${RESET}"
fi

echo -e "${CYAN}╠════╩════════════════════╩════════════╩══════════════╣${RESET}"
echo -e "${WHITE} Consumo Total   : ${GREEN}$(human "$CTOTAL")${RESET}"
echo -e "${WHITE} Actualizado     : ${GREEN}$(date '+%d/%m/%Y %H:%M:%S')${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"

echo
read -n1 -s -r -p "Presione cualquier tecla para regresar..."
