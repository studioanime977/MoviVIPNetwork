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
LIM_CONF="$SISTEMA/limites_consumo.conf"     # USUARIO=BYTES_LIMITE (0 = ilimitado)

# Cargar idioma
if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)"
fi

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

# --- Cargar limites de consumo por usuario (0 = ilimitado) ---
declare -A LIMIT_MEM      # USUARIO -> BYTES_LIMITE
if [[ -f "$LIM_CONF" ]]; then
    while IFS='=' read -r U V; do
        [[ -n "$U" ]] && LIMIT_MEM["$U"]="$V"
    done < "$LIM_CONF"
fi

while IFS='|' read -r KEY USUARIO VALOR; do
    [[ -z "$KEY" ]] && continue
    SNAP_VAL["$KEY"]="$VALOR"
    SNAP_USER["$KEY"]="$USUARIO"
done < "$ST_SNAP"

# --- Mapa de usuarios con HWID registrado (add_hwid.sh) ---
declare -A HWID_MEM      # USUARIO -> 1 (tiene HWID)
declare -A HWID_MAX      # USUARIO -> MAXCONN (conexiones simultaneas permitidas)
if [[ -d "$BASE/hwids" ]]; then
    for HF in "$BASE"/hwids/*.hwid; do
        [[ -e "$HF" ]] || continue
        HWID_MEM["$(basename "$HF" .hwid)"]="1"
        MC=$(grep -m1 "^MAXCONN:" "$HF" 2>/dev/null | cut -d' ' -f2)
        [[ -n "$MC" ]] && HWID_MAX["$(basename "$HF" .hwid)"]="$MC"
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

#==================================================
# BLOQUEO AUTOMATICO POR LIMITE DE CONSUMO
# (tambien en modo cron: el usuario se bloquea solo)
#==================================================

check_limits() {
    local U LIM CONSUMO
    for U in "${!TOTAL_MEM[@]}"; do
        LIM="${LIMIT_MEM[$U]:-0}"
        [[ "$LIM" == "0" || -z "$LIM" ]] && continue
        CONSUMO="${TOTAL_MEM[$U]:-0}"
        if [[ "$CONSUMO" -ge "$LIM" ]]; then
            # Ya esta bloqueado?
            if ! passwd -S "$U" 2>/dev/null | awk '{print $2}' | grep -q "L"; then
                passwd -l "$U" >/dev/null 2>&1
                pkill -u "$U" >/dev/null 2>&1
                echo "$(date '+%d/%m/%Y %H:%M:%S') | $U | BLOQUEADO por limite de consumo ($(human "$CONSUMO") >= $(human "$LIM"))" >> "$SISTEMA/consumo_bloqueos.log" 2>/dev/null
            fi
        fi
    done
}

check_limits

#==================================================
# ANTI-SHARE PARA USUARIOS POR HWID
# Si un usuario HWID excede sus conexiones simultaneas
# (MAXCONN, default 2) => hay alguien mas usando la
# cuenta => BLOQUEO automatico + log. Funciona tambien
# en modo cron (--quiet).
#==================================================

check_hwid_share() {
    local U MC CONN HWID_BLOQUEOS
    HWID_BLOQUEOS="$SISTEMA/hwid_bloqueos.log"
    for ACC_UID in "${!UID_CONN[@]}"; do
        U="${UID_NAME[$ACC_UID]:-}"
        [[ -z "$U" ]] && continue
        [[ -z "${HWID_MEM[$U]:-}" ]] && continue
        MC="${HWID_MAX[$U]:-2}"
        CONN="${UID_CONN[$ACC_UID]:-0}"
        if [[ "$CONN" -gt "$MC" ]]; then
            # Ya esta bloqueado?
            if ! passwd -S "$U" 2>/dev/null | awk '{print $2}' | grep -q "L"; then
                passwd -l "$U" >/dev/null 2>&1
                pkill -u "$U" >/dev/null 2>&1
                echo "$(date '+%d/%m/%Y %H:%M:%S') | $U | BLOQUEADO por anti-share ($CONN conexiones > max $MC). Posible comparticion de cuenta HWID." >> "$HWID_BLOQUEOS" 2>/dev/null
            fi
        fi
    done
}

check_hwid_share

#==================================================
# LIMITE DE CONEXIONES SIMULTANEAS POR USUARIO
# (NO bloquea la cuenta: mata SOLO las conexiones
#  excedentes. Archivo: sistema/limites_conexiones.conf
#  formato USUARIO=MAXCONN, 0 = ilimitado)
#==================================================

CONN_LIM_CONF="$SISTEMA/limites_conexiones.conf"

check_conn_limits() {
    local U MC CONN LIMITADOS
    [[ -f "$CONN_LIM_CONF" ]] || return 0

    while IFS='=' read -r U MC; do
        [[ -z "$U" ]] && continue
        [[ -z "$MC" || "$MC" == "0" ]] && continue
        # Buscar UID de la cuenta (las conexiones se agrupan por UID)
        ACC_UID=$(awk -F: -v n="$U" '$1==n {print $3}' /etc/passwd)
        [[ -z "$ACC_UID" ]] && continue
        CONN="${UID_CONN[$ACC_UID]:-0}"
        [[ "$CONN" -le "$MC" ]] && continue

        # Matar SOLO los procesos sshd excedentes del usuario
        # (los mas recientes primero: menor etimes; conservando
        #  las conexiones mas antiguas/estables)
        EXCESO=$((CONN - MC))
        EXCESO=$(awk "BEGIN{print ($EXCESO<1)?1:$EXCESO}")
        PIDS=$(ps -C sshd -o pid=,uid=,etimes=,args= 2>/dev/null | \
               awk -v u="$ACC_UID" '$2==u && $0 !~ /\[priv\]/ {print $1, $3}' | \
               sort -k2,2n | head -n "$EXCESO" | awk '{print $1}')
        for PID in $PIDS; do
            kill -9 "$PID" >/dev/null 2>&1
            echo "$(date '+%d/%m/%Y %H:%M:%S') | $U | Conexion excedente cortada (PID $PID): $CONN > max $MC" >> "$SISTEMA/conexiones_cortadas.log" 2>/dev/null
        done
        LIMITADOS=1
    done < "$CONN_LIM_CONF"

    # Recalcular conexiones para la pantalla despues de cortar
    if [[ $LIMITADOS -eq 1 ]]; then
        declare -A UID_CONN2
        while read -r PID ACC_UID2 USER REST; do
            [[ -z "$PID" ]] && continue
            [[ "$REST" == *"[priv]"* ]] && continue
            [[ "$REST" == *"[accepted]"* ]] && continue
            [[ "$REST" == *"[net]"* ]] && continue
            [[ "$REST" == *"listener"* ]] && continue
            [[ "$ACC_UID2" == "0" ]] && continue
            [[ "$USER" == "sshd" ]] && continue
            [[ "$ACC_UID2" == "65534" ]] && continue
            UID_CONN2["$ACC_UID2"]=$(( ${UID_CONN2["$ACC_UID2"]:-0} + 1 ))
        done < <(ps -C sshd -o pid=,uid=,user=,args= 2>/dev/null)
        UID_CONN=()
        for K in "${!UID_CONN2[@]}"; do UID_CONN["$K"]="${UID_CONN2[$K]}"; done
    fi
}

check_conn_limits

# Salida silenciosa (modo cron): solo acumular consumo
if [[ $QUIET -eq 1 ]]; then
    exit 0
fi

USER_LIST=$(printf "%s\n" "${!UID_NAME[@]}" | sort -n)

# Icono candado si el usuario tiene HWID registrado
HICON() { [[ -n "${HWID_MEM[$1]:-}" ]] && echo "[C]" || echo "  "; }

clear

#==================================================
# * USUARIOS ONLINE
#==================================================

echo -e "${CYAN}+====================================================+${RESET}"
echo -e "${CYAN}|${MAGENTA}              * USUARIOS ONLINE *              ${CYAN}|${RESET}"
echo -e "${CYAN}+====+====================+=======================+${RESET}"

printf "${CYAN}|${WHITE} %-2s ${CYAN}| ${WHITE}%-18s ${CYAN}| ${WHITE}%-21s${CYAN}|${RESET}\n" \
"ID" "USUARIO" "CONEXIONES"

echo -e "${CYAN}+====+====================+=======================+${RESET}"

TOTAL=0
ID=1

for ACC_UID in $USER_LIST; do
    CONN=${UID_CONN[$ACC_UID]}
    printf "${CYAN}|${WHITE} %02d ${CYAN}| ${GREEN}%-16s%s${CYAN} | ${YELLOW}%-21s${CYAN}|${RESET}\n" \
    "$ID" "${UID_NAME[$ACC_UID]}" "$(HICON "${UID_NAME[$ACC_UID]}")" "$CONN"
    ((TOTAL++))
    ((ID++))
done

if [[ $TOTAL -eq 0 ]]; then
    echo -e "${CYAN}|${RED} No hay usuarios conectados.                  ${CYAN}|${RESET}"
fi

echo -e "${CYAN}+====+====================+=======================+${RESET}"
echo -e "${WHITE} Usuarios Online : ${GREEN}$TOTAL${RESET}"
echo -e "${WHITE} Actualizado     : ${GREEN}$(date '+%d/%m/%Y %H:%M:%S')${RESET}"
echo -e "${GRAY} [C] = usuario con HWID registrado${RESET}"
echo -e "${CYAN}+====================================================+${RESET}"

echo ""

#==================================================
# [NET] CONEXIONES POR PROTOCOLO (AUTO-DETECT)
#==================================================

# Contar conexiones TCP/UDP activas de un proceso
count_estab() {
    local PROC=$1
    timeout 3 ss -tnp 2>/dev/null | awk -v p="$PROC" '$0 ~ p && $1 == "ESTAB" {count++} END{print count+0}'
}

count_udp_proc() {
    local PROC=$1
    timeout 3 ss -unp 2>/dev/null | awk -v p="$PROC" '$0 ~ p {count++} END{print count+0}'
}

PROTO_LINES=""
PROTO_TOTAL=0

# --- Escaneo unico de puertos escuchando ---
ALL_TCP=$(timeout 3 ss -tnlp 2>/dev/null)
ALL_UDP=$(timeout 3 ss -ulnp 2>/dev/null)

# 1) UDP Custom  proceso "udp" en puerto UDP
if echo "$ALL_UDP" | grep -q '"udp"'; then
    U_PORTS=$(echo "$ALL_UDP" | grep '"udp"' | awk '{print $4}' | grep -oP ':\K[0-9]+' | sort -un | tr '\n' ',' | sed 's/,$//')
    U_C=0
    for P in $(echo "$U_PORTS" | tr ',' ' '); do
        C=$(timeout 3 ss -unp 2>/dev/null | awk -v p=":${P}" '$4 ~ p {c++} END{print c+0}')
        U_C=$((U_C + C))
    done
    PROTO_LINES="${PROTO_LINES}   ${WHITE}UDP Custom${RESET}   ${GRAY}[$U_PORTS]${RESET}      ${CYAN}:${RESET}  ${YELLOW}${U_C}${RESET}\n"
    PROTO_TOTAL=$((PROTO_TOTAL + U_C))
fi

# 2) BadVPN  proceso "badvpn-udpgw" en puertos TCP
if echo "$ALL_TCP" | grep -q 'badvpn'; then
    B_PORTS=$(echo "$ALL_TCP" | grep 'badvpn' | awk '{print $4}' | grep -oP ':\K[0-9]+' | sort -un | tr '\n' ',' | sed 's/,$//')
    B_C=0
    for P in $(echo "$B_PORTS" | tr ',' ' '); do
        C=$(timeout 3 ss -tnp 2>/dev/null | awk -v p=":${P}" '$4 ~ p && $1 == "ESTAB" {c++} END{print c+0}')
        B_C=$((B_C + C))
    done
    PROTO_LINES="${PROTO_LINES}  [*] ${WHITE}BadVPN${RESET}       ${GRAY}[$B_PORTS]${RESET}    ${CYAN}:${RESET}  ${YELLOW}${B_C}${RESET}\n"
    PROTO_TOTAL=$((PROTO_TOTAL + B_C))
fi

# 3) ZiVPN  sesiones REALES desde journald (su socket UDP es multiplexado:
#    nunca muestra peers individuales en ss -> conteo por puerto daba 0)
if echo "$ALL_UDP" | grep -q 'zivpn'; then
    Z_PORTS=$(echo "$ALL_UDP" | grep 'zivpn' | awk '{print $4}' | grep -oP ':\K[0-9]+' | sort -un | tr '\n' ',' | sed 's/,$//')
    ZIV_SUMMARY=$(timeout 8 journalctl _COMM=zivpn --since "-24 hours" --no-pager -o cat 2>/dev/null | awk '
        /client connected/ && match($0, /addr": "[^"]+"/) {
            a = substr($0, RSTART+8, RLENGTH-9); gsub(/"/, "", a);
            if (match($0, /[0-9][0-9]:[0-9][0-9]:[0-9][0-9]/)) t = substr($0, RSTART, RLENGTH);
            else t = "?";
            seen[a] = t;
        }
        /client disconnected/ && match($0, /addr": "[^"]+"/) {
            a = substr($0, RSTART+8, RLENGTH-9); gsub(/"/, "", a);
            delete seen[a];
        }
        END {
            c = 0;
            for (a in seen) { c++; if (c <= 10) print a "|" seen[a]; }
            printf "%d\n", c;
        }')
    Z_C=$(tail -n 1 <<<"$ZIV_SUMMARY")
    Z_C=${Z_C:-0}
    ZIV_ROWS="$(sed '/^$/d' <<<"$ZIV_SUMMARY" | head -n -1)"
    PROTO_LINES="${PROTO_LINES}   ${WHITE}ZiVPN${RESET}        ${GRAY}[$Z_PORTS]${RESET}      ${CYAN}:${RESET}  ${YELLOW}${Z_C}${RESET}\n"
    PROTO_TOTAL=$((PROTO_TOTAL + Z_C))
fi

# 4) Xray/V2Ray  detectar puertos publicos de haproxy + puertos locales de xray
if echo "$ALL_TCP" | grep -q 'xray'; then
    # Puertos publicos (haproxy -> xray)
    X_PUB=$(echo "$ALL_TCP" | grep 'haproxy' | awk '{print $4}' | grep -oP ':\K[0-9]+' | sort -un | tr '\n' ',' | sed 's/,$//')
    X_PRIV=$(echo "$ALL_TCP" | grep 'xray' | awk '{print $4}' | grep -oP ':\K[0-9]+' | sort -un | tr '\n' ',' | sed 's/,$//')
    X_C=0
    for P in $(echo "$X_PUB" | tr ',' ' '); do
        C=$(timeout 3 ss -tnp 2>/dev/null | awk -v p=":${P}" '$4 ~ p && $1 == "ESTAB" {c++} END{print c+0}')
        X_C=$((X_C + C))
    done
    for P in $(echo "$X_PRIV" | tr ',' ' '); do
        C=$(timeout 3 ss -tnp 2>/dev/null | awk -v p=":${P}" '$4 ~ p && $1 == "ESTAB" {c++} END{print c+0}')
        X_C=$((X_C + C))
    done
    X_ALL=$(echo "$X_PUB" | tr ',' ' ')
    [[ -n "$X_PRIV" ]] && X_ALL="$X_ALL $(echo "$X_PRIV" | tr ',' ' ')"
    X_ALL=$(echo "$X_ALL" | tr ' ' '\n' | sort -un | tr '\n' ',' | sed 's/,$//')
    PROTO_LINES="${PROTO_LINES}  [X]  ${WHITE}Xray/V2Ray${RESET}  ${GRAY}[$X_ALL]${RESET}    ${CYAN}:${RESET}  ${YELLOW}${X_C}${RESET}\n"
    PROTO_TOTAL=$((PROTO_TOTAL + X_C))
fi

# 5) OpenSSH  sshd listener
if echo "$ALL_TCP" | grep -q 'sshd.*listener\|sshd.*0.0.0.0:\|sshd.*:::'; then
    S_PORTS=$(echo "$ALL_TCP" | grep 'sshd' | grep -v '127.0.0.1' | awk '{print $4}' | grep -oP ':\K[0-9]+' | sort -un | tr '\n' ',' | sed 's/,$//')
    S_C=0
    for P in $(echo "$S_PORTS" | tr ',' ' '); do
        C=$(timeout 3 ss -tnp 2>/dev/null | awk -v p=":${P}" '$4 ~ p && $1 == "ESTAB" {c++} END{print c+0}')
        S_C=$((S_C + C))
    done
    PROTO_LINES="${PROTO_LINES}  [C] ${WHITE}OpenSSH${RESET}     ${GRAY}[$S_PORTS]${RESET}      ${CYAN}:${RESET}  ${YELLOW}${S_C}${RESET}\n"
    PROTO_TOTAL=$((PROTO_TOTAL + S_C))
fi

# 6) Dropbear
if echo "$ALL_TCP" | grep -q 'dropbear'; then
    D_PORTS=$(echo "$ALL_TCP" | grep 'dropbear' | awk '{print $4}' | grep -oP ':\K[0-9]+' | sort -un | tr '\n' ',' | sed 's/,$//')
    D_C=0
    for P in $(echo "$D_PORTS" | tr ',' ' '); do
        C=$(timeout 3 ss -tnp 2>/dev/null | awk -v p=":${P}" '$4 ~ p && $1 == "ESTAB" {c++} END{print c+0}')
        D_C=$((D_C + C))
    done
    PROTO_LINES="${PROTO_LINES}   ${WHITE}Dropbear${RESET}    ${GRAY}[$D_PORTS]${RESET}      ${CYAN}:${RESET}  ${YELLOW}${D_C}${RESET}\n"
    PROTO_TOTAL=$((PROTO_TOTAL + D_C))
fi

# 7) SlowDNS  DNS tunnel en puerto 5300
if echo "$ALL_TCP" | grep -q 'slowdns\|python3.*5300\|python3.*53'; then
    SL_C=0
    for P in 53 5300; do
        C=$(timeout 3 ss -tnp 2>/dev/null | awk -v p=":${P}" '$4 ~ p && $1 == "ESTAB" {c++} END{print c+0}')
        SL_C=$((SL_C + C))
    done
    PROTO_LINES="${PROTO_LINES}  [NET] ${WHITE}SlowDNS${RESET}     ${GRAY}[53,5300]${RESET}    ${CYAN}:${RESET}  ${YELLOW}${SL_C}${RESET}\n"
    PROTO_TOTAL=$((PROTO_TOTAL + SL_C))
fi

if [[ -n "$PROTO_LINES" ]]; then
    echo -e "${CYAN}+====================================================+${RESET}"
    echo -e "${CYAN}|${MAGENTA}         [NET] CONEXIONES POR PROTOCOLO [NET]            ${CYAN}|${RESET}"
    echo -e "${CYAN}+====================================================+${RESET}"
    echo -ne "${PROTO_LINES}"
    echo -e "${CYAN}+====================================================+${RESET}"
    echo -e "${WHITE} Total Protocolos: ${GREEN}${PROTO_TOTAL}${RESET}"
    echo -e "${WHITE} Total SSH Users : ${GREEN}${TOTAL:-0}${RESET}"
    echo -e "${WHITE} TOTAL GENERAL   : ${GOLD}$((PROTO_TOTAL + ${TOTAL:-0}))${RESET}"
    echo -e "${CYAN}+====================================================+${RESET}"
fi

#==================================================
# [>] DETALLE DE USUARIOS POR PROTOCOLO
#==================================================

# --- ZiVPN: peers activos + credenciales configuradas ---
if echo "$ALL_UDP" | grep -q 'zivpn'; then
    echo ""
    echo -e "${CYAN} ZiVPN (${GRAY}$Z_PORTS${RESET}${CYAN}) - sesiones activas: ${YELLOW}${Z_C}${RESET}"
    if [[ -n "$ZIV_ROWS" ]]; then
        echo -e "${CYAN} +-----------------------+----------+${RESET}"
        echo -e "${CYAN} |${WHITE} PEER (IP:PUERTO)      ${CYAN}|${WHITE} DESDE    ${CYAN}|${RESET}"
        echo -e "${CYAN} +-----------------------+----------+${RESET}"
        while IFS='|' read -r zpa zph; do
            [[ -z "$zpa" ]] && continue
            printf "${CYAN} |${RESET} %-21s ${CYAN}|${RESET} %-8s ${CYAN}|${RESET}\n" "$zpa" "$zph"
        done <<< "$ZIV_ROWS"
        echo -e "${CYAN} +-----------------------+----------+${RESET}"
    else
        echo -e "${GRAY} Sin sesiones ziVPN activas en este momento.${RESET}"
    fi
    if command -v jq >/dev/null 2>&1 && [[ -f /etc/zivpn/config.json ]]; then
        Z_CREDS=$(jq -r '.auth.config[]?' /etc/zivpn/config.json 2>/dev/null |
        while IFS= read -r zp; do
            [[ -z "$zp" ]] && continue
            zexp=$(awk -F'|' -v P="$zp" '$1==P{print $2}' /etc/zivpn/expira.conf 2>/dev/null)
            if [[ -z "$zexp" || "$zexp" == "0" ]]; then
                printf '%s [sin expiracion], ' "$zp"
            else
                printf '%s [expira %s], ' "$zp" "$(date -d "@$zexp" '+%d/%m/%y' 2>/dev/null)"
            fi
        done | sed 's/, $//')
        [[ -n "$Z_CREDS" ]] && echo -e "${WHITE} Credenciales:${RESET} ${GREEN}$Z_CREDS${RESET}"
        echo -e "${GRAY} ziVPN no reporta la pass por conexion (la oculta como \"user\" en su log).${RESET}"
    fi
fi

# --- Xray/V2Ray: usuarios registrados, UUID y actividad ---
if echo "$ALL_TCP" | grep -q 'xray'; then
    XRAY_CFG="/usr/local/etc/xray/config.json"
    XRAY_LOG="/var/log/xray/access.log"
    if command -v jq >/dev/null 2>&1 && [[ -f "$XRAY_CFG" ]]; then
        echo ""
        echo -e "${CYAN} Xray/V2Ray - usuarios registrados y actividad reciente:${RESET}"
        declare -A XS_CNT=() XS_LAST=()
        if [[ -f "$XRAY_LOG" ]]; then
            XRAY_STATS=$(timeout 6 tail -c 4000000 "$XRAY_LOG" 2>/dev/null | awk '
                / accepted / && /email:/ {
                    e = $0; sub(/.*email: */, "", e); sub(/[ ].*/, "", e);
                    cnt[e]++;
                    if (match($0, /[0-9][0-9]:[0-9][0-9]:[0-9][0-9]/)) last[e] = substr($0, RSTART, RLENGTH);
                }
                END { for (e in cnt) print e "|" cnt[e] "|" last[e]; }')
            while IFS='|' read -r xse xsc xsl; do
                [[ -z "$xse" ]] && continue
                XS_CNT["$xse"]="$xsc"
                XS_LAST["$xse"]="$xsl"
            done <<< "$XRAY_STATS"
        fi
        echo -e "${CYAN} +-----------------------------+----------------+---------+---------+${RESET}"
        echo -e "${CYAN} |${WHITE} USUARIO                     ${CYAN}|${WHITE} UUID           ${CYAN}|${WHITE} EVENTOS ${CYAN}|${WHITE} HORA    ${CYAN}|${RESET}"
        echo -e "${CYAN} +-----------------------------+----------------+---------+---------+${RESET}"
        jq -r '.inbounds[].settings.clients[]? | [(.email // "-"), (.id // "-")] | @tsv' "$XRAY_CFG" 2>/dev/null |
        while IFS=$'\t' read -r xmail xuuid; do
            [[ -z "$xmail" ]] && continue
            xshort="$xuuid"
            [[ ${#xuuid} -ge 12 ]] && xshort="${xuuid:0:8}..${xuuid: -4}"
            xcnt="${XS_CNT[$xmail]:-0}"
            xlast="${XS_LAST[$xmail]:---}"
            printf "${CYAN} |${RESET} %-27s ${CYAN}|${RESET} %-14s ${CYAN}|${RESET} %7s ${CYAN}|${RESET} %-7s ${CYAN}|${RESET}\n" \
                "$xmail" "$xshort" "$xcnt" "$xlast"
        done
        echo -e "${CYAN} +-----------------------------+----------------+---------+---------+${RESET}"
        echo -e "${GRAY} EVENTOS = peticiones en la ventana reciente del access.log.${RESET}"
        echo -e "${GRAY} IP cliente oculta tras HAProxy (los eventos llegan desde 127.0.0.1).${RESET}"
        unset XS_CNT XS_LAST
    fi
fi

# --- BadVPN: quien usa el gateway (sesion SSH real o tunel ziVPN) ---
if echo "$ALL_TCP" | grep -q 'badvpn'; then
    echo ""
    B_TOTAL=0
    declare -A BV_ROWS=()
    BV_SCAN=$(timeout 5 ss -H -tnp state established 2>/dev/null |
        awk '$4 ~ /:(7200|7300)$/ && match($0, /pid=[0-9]+/) {
            print substr($0, RSTART+4, RLENGTH-4);
        }')
    for bpid in $(printf '%s\n' "$BV_SCAN" | sort -u); do
        [[ "$bpid" =~ ^[0-9]+$ ]] || continue
        bcnt=$(grep -c "^$bpid$" <<< "$BV_SCAN")
        bproc=$(ps -o comm= -p "$bpid" 2>/dev/null)
        brip="-"; buser="$bproc"
        if [[ "$bproc" == "sshd" ]]; then
            buid=$(stat -c %u "/proc/$bpid" 2>/dev/null)
            [[ -n "$buid" ]] && bn=$(getent passwd "$buid" 2>/dev/null | cut -d: -f1)
            buser="${bn:-uid:$buid}"
            # fila de SESION: la cuya direccion LOCAL es un puerto de escucha
            # ssh/dropbear -> su peer es la IP real del cliente
            brip=$(timeout 3 ss -H -tnp state established 2>/dev/null |
                grep "pid=$bpid," | awk '$3 ~ /:(22|8012|54321|90|109|143)$/ {print $4}' | head -1 | sed 's/:[0-9]*$//')
        elif [[ "$bproc" == "zivpn" ]]; then
            buser="via ZiVPN"
        fi
        B_TOTAL=$((B_TOTAL + bcnt))
        BV_ROWS["$buser|$brip"]=$(( ${BV_ROWS["$buser|$brip"]:-0} + bcnt ))
        unset bn buid
    done
    echo -e "${CYAN} BadVPN (:7200,:7300) - conexiones de gateway activas: ${YELLOW}${B_TOTAL}${RESET}"
    if [[ ${#BV_ROWS[@]} -gt 0 ]]; then
        echo -e "${CYAN} +----------------------+--------------------------+-------+${RESET}"
        echo -e "${CYAN} |${WHITE} PROPIETARIO          ${CYAN}|${WHITE} IP CLIENTE               ${CYAN}|${WHITE} CONNS ${CYAN}|${RESET}"
        echo -e "${CYAN} +----------------------+--------------------------+-------+${RESET}"
        bv_n=0
        for bk in "${!BV_ROWS[@]}"; do
            bv_n=$((bv_n + 1))
            [[ $bv_n -gt 8 ]] && break
            bvu="${bk%%|*}"; bvi="${bk#*|}"
            printf "${CYAN} |${RESET} %-20s ${CYAN}|${RESET} %-24s ${CYAN}|${RESET} %5s ${CYAN}|${RESET}\n" \
                "$bvu" "$bvi" "${BV_ROWS[$bk]}"
        done
        echo -e "${CYAN} +----------------------+--------------------------+-------+${RESET}"
        [[ ${#BV_ROWS[@]} -gt 8 ]] && echo -e "${GRAY} (+ $(( ${#BV_ROWS[@]} - 8 )) propietarios mas)${RESET}"
    else
        echo -e "${GRAY} Sin clientes badvpn ahora mismo.${RESET}"
    fi
    unset BV_ROWS
fi

# --- UDP Custom: IPs hablando en los ultimos segundos (muestreo tcpdump) ---
if echo "$ALL_UDP" | grep -q '"udp"'; then
    U_PORTS=$(echo "$ALL_UDP" | grep '"udp"' | awk '{print $4}' | grep -oP ':\K[0-9]+' | sort -un | head -3 | tr '\n' ',' | sed 's/,$//')
    echo ""
    echo -e "${CYAN} UDP Custom ($U_PORTS):${RESET}"
    if command -v tcpdump >/dev/null 2>&1; then
        UC_PEERS=$(timeout 5 tcpdump -ln -i any -c 5000 "udp and port ${U_PORTS%%,*}" 2>/dev/null |
            awk '/^[0-9][0-9]:/ && / > / {
                src = $3;
                n = split(src, a, ".");
                if (n >= 4) ip = a[1]"."a[2]"."a[3]"."a[4]; else ip = src;
                cnt[ip]++;
            }
            END { for (i in cnt) printf "%s|%d\n", i, cnt[i] }' | sort -t'|' -k2 -rn | head -8)
        if [[ -n "$UC_PEERS" ]]; then
            ucn_total=0
            while IFS='|' read -r ui up; do ucn_total=$((ucn_total + up)); done <<< "$UC_PEERS"
            echo -e "${GRAY} IPs transmitiendo en la muestra de 3-4s (${YELLOW}${ucn_total}${GRAY} paquetes):${RESET}"
            while IFS='|' read -r ui up; do
                printf "${CYAN}   *${RESET} %-22s ${GRAY}%s paquetes${RESET}\n" "$ui" "$up"
            done <<< "$UC_PEERS"
        else
            echo -e "${GRAY} Sin trafico en la muestra de 3-4s.${RESET}"
        fi
    else
        echo -e "${GRAY} tcpdump no instalado - no se pueden listar IPs en vivo.${RESET}"
    fi
fi

echo ""

#==================================================
# [#] CONSUMO GB POR USUARIO
#==================================================

echo -e "${CYAN}+====================================================+${RESET}"
echo -e "${CYAN}|${MAGENTA}           [#] CONSUMO GB POR USUARIO [#]           ${CYAN}|${RESET}"
echo -e "${CYAN}+====+====================+==============================+${RESET}"

printf "${CYAN}|${WHITE} %-2s ${CYAN}| ${WHITE}%-18s ${CYAN}| ${WHITE}%-11s ${CYAN}| ${WHITE}%-11s ${CYAN}| ${WHITE}%-5s${CYAN}|${RESET}\n" \
"ID" "USUARIO" "CONSUMO" "LIMITE" "%"

echo -e "${CYAN}+====+====================+==============================+${RESET}"

CID=1
CTOTAL=0
CGRAN=0

for ACC_UID in $USER_LIST; do
    NAME="${UID_NAME[$ACC_UID]}"
    CONN="${UID_CONN[$ACC_UID]}"
    TOTAL_USER="${TOTAL_MEM[$NAME]:-0}"
    CONSUMO_H=$(human "$TOTAL_USER")
    LIM_USER="${LIMIT_MEM[$NAME]:-0}"
    if [[ -z "$LIM_USER" || "$LIM_USER" == "0" ]]; then
        LIM_H=""
        PCT_H=""
    else
        LIM_H=$(human "$LIM_USER")
        PCT=$(awk "BEGIN{printf \"%.0f\", $TOTAL_USER*100/$LIM_USER}")
        [[ "$PCT" -gt 100 ]] && PCT=100
        PCT_H="$PCT%"
    fi
    printf "${CYAN}|${WHITE} %02d ${CYAN}| ${GREEN}%-16s%s${CYAN} | ${MAGENTA}%-11s${CYAN} | ${YELLOW}%-11s${CYAN} | ${RED}%-5s${CYAN}|${RESET}\n" \
    "$CID" "$NAME" "$(HICON "$NAME")" "$CONSUMO_H" "$LIM_H" "$PCT_H"
    CTOTAL=$((CTOTAL + TOTAL_USER))
    ((CID++))
    ((CGRAN++))
done

if [[ $CGRAN -eq 0 ]]; then
    echo -e "${CYAN}|${RED} Sin usuarios con consumo registrado.            ${CYAN}|${RESET}"
fi

echo -e "${CYAN}+====+====================+==============================+${RESET}"
echo -e "${WHITE} Consumo Total   : ${GREEN}$(human "$CTOTAL")${RESET}"
echo -e "${WHITE} Actualizado     : ${GREEN}$(date '+%d/%m/%Y %H:%M:%S')${RESET}"
echo -e "${GRAY} [C] = usuario con HWID registrado |  = sin limite de consumo${RESET}"
echo -e "${CYAN}+====================================================+${RESET}"

echo
read -n1 -s -r -p "Presione cualquier tecla para regresar..."
