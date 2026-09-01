#!/bin/bash

# ── i18n shim (auto) ───────────────────────────────
if ! declare -F trx >/dev/null 2>&1; then trx() { printf '%s' "$1"; }; fi
# ─────────────────────────────────────────────────────────
BASE="/etc/movivip"

CYAN="\e[1;96m"
GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
MAGENTA="\e[1;95m"
WHITE="\e[1;97m"
RESET="\e[0m"

#--------------------------------------------------
# Puertos actualmente en ESCUCHA en la máquina
# (Refleja cualquier cambio de puerto que haga el
#  usuario en sus protocolos, sin tocar nada)
#--------------------------------------------------
puertos_en_escucha() {
    local P
    {
        ss -H -tln 2>/dev/null
        ss -H -uln 2>/dev/null
    } | awk '{print $4}' | grep -oE '[0-9]+$' | sort -un
}

#--------------------------------------------------
# Abrir un puerto en iptables + ufw (tcp y udp)
#--------------------------------------------------
abrir_puerto_regla() {
    local PORT="$1" PROTO="$2"
    case "$PROTO" in
        tcp)
            iptables -C INPUT -p tcp --dport "$PORT" -j ACCEPT 2>/dev/null \
                || iptables -A INPUT -p tcp --dport "$PORT" -j ACCEPT
            ;;
        udp)
            iptables -C INPUT -p udp --dport "$PORT" -j ACCEPT 2>/dev/null \
                || iptables -A INPUT -p udp --dport "$PORT" -j ACCEPT
            ;;
        ambos|both|*)
            iptables -C INPUT -p tcp --dport "$PORT" -j ACCEPT 2>/dev/null \
                || iptables -A INPUT -p tcp --dport "$PORT" -j ACCEPT
            iptables -C INPUT -p udp --dport "$PORT" -j ACCEPT 2>/dev/null \
                || iptables -A INPUT -p udp --dport "$PORT" -j ACCEPT
            ;;
    esac
    if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
        ufw allow "$PORT" >/dev/null 2>&1
    fi
}

#--------------------------------------------------
# 1) ABRIR PUERTO (manual)
#--------------------------------------------------
abrir(){

    read -rp "Puerto: " PORT
    [[ "$PORT" =~ ^[0-9]+$ ]] || { echo -e "${RED}❌ Puerto inválido.${RESET}"; sleep 2; return; }

    read -rp "$(trx 'Protocolo [tcp/udp/ambos]: ')" PROTO
    PROTO=$(echo "$PROTO" | tr '[:upper:]' '[:lower:]')

    abrir_puerto_regla "$PORT" "$PROTO"

    echo ""
    echo -e "${GREEN}✅ Puerto $PORT ($PROTO) abierto.${RESET}"
    sleep 2
}

#--------------------------------------------------
# 2) CERRAR PUERTO (manual)
#--------------------------------------------------
cerrar(){

    read -rp "Puerto: " PORT
    [[ "$PORT" =~ ^[0-9]+$ ]] || { echo -e "${RED}❌ Puerto inválido.${RESET}"; sleep 2; return; }

    read -rp "$(trx 'Protocolo [tcp/udp/ambos]: ')" PROTO
    PROTO=$(echo "$PROTO" | tr '[:upper:]' '[:lower:]')

    case "$PROTO" in
        tcp)
            iptables -D INPUT -p tcp --dport "$PORT" -j ACCEPT 2>/dev/null
            ;;
        udp)
            iptables -D INPUT -p udp --dport "$PORT" -j ACCEPT 2>/dev/null
            ;;
        ambos|both|*)
            iptables -D INPUT -p tcp --dport "$PORT" -j ACCEPT 2>/dev/null
            iptables -D INPUT -p udp --dport "$PORT" -j ACCEPT 2>/dev/null
            ;;
    esac

    if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
        ufw delete allow "$PORT" >/dev/null 2>&1
    fi

    echo ""
    echo -e "${GREEN}✅ Puerto $PORT ($PROTO) cerrado.${RESET}"
    sleep 2
}

#--------------------------------------------------
# 3) ESTADO
#--------------------------------------------------
estado(){

    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${MAGENTA}            🔥 FIREWALL${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    echo -e "${WHITE}📋 Reglas iptables INPUT:${RESET}"
    echo ""
    iptables -L INPUT -n --line-numbers 2>/dev/null | head -40

    if command -v ufw >/dev/null 2>&1; then
        echo ""
        echo -e "${WHITE}📋 Estado UFW:${RESET}"
        echo ""
        ufw status numbered 2>/dev/null
    fi

    echo ""
    read -n1 -r -p "$(trx 'Presione una tecla...')"
}

#--------------------------------------------------
# 4) SINCRONIZAR PUERTOS DE PROTOCOLOS
#    Abre automáticamente TODO puerto que esté en
#    escucha (cualquier protocolo que el usuario
#    tenga activo y con puerto cambiado)
#--------------------------------------------------
sincronizar(){

    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${MAGENTA}      🔄 SINCRONIZAR PUERTOS DE PROTOCOLOS${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    mapfile -t PORTS < <(puertos_en_escucha)

    if [[ ${#PORTS[@]} -eq 0 ]]; then
        echo -e "${YELLOW}ℹ️  No se detectaron puertos en escucha.${RESET}"
        echo
        read -n1 -r -p "$(trx 'Presione una tecla...')"
        return
    fi

    echo -e "${WHITE}Puertos detectados en escucha (TCP/UDP):${RESET}"
    echo ""
    echo -e "${GREEN}  ${PORTS[*]}${RESET}"
    echo ""

    OPENED=0
    for P in "${PORTS[@]}"; do
        abrir_puerto_regla "$P" ambos
        OPENED=$((OPENED + 1))
    done

    echo -e "${GREEN}✅ $OPENED puertos sincronizados y abiertos (tcp + udp).${RESET}"
    echo -e "${WHITE}   Ahora los servicios con puerto cambiado quedan accesibles.${RESET}"

    reaplicar_extras
    if [[ -f "$EXTRA_CONF" ]] && [[ -s "$EXTRA_CONF" ]]; then
        echo -e "${GREEN}   Puertos extra re-aplicados desde $EXTRA_CONF${RESET}"
    fi
    echo
    read -n1 -r -p "$(trx 'Presione una tecla...')"
}

#--------------------------------------------------
# 5) CERRAR PUERTOS OBSOLETOS
#    Elimina reglas ACCEPT de puertos que YA NO
#    escucha ningún servicio (puertos viejos que el
#    usuario dejó abiertos al cambiar de protocolo)
#--------------------------------------------------
cerrar_obsoletos(){

    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${MAGENTA}     🧹 CERRAR PUERTOS OBSOLETOS${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    mapfile -t PORTS < <(puertos_en_escucha)

    # Recoger reglas ACCEPT tcp/udp con su puerto
    RULES=$(iptables -L INPUT -n --line-numbers 2>/dev/null | grep -E "ACCEPT.*(dpt|spt):[0-9]+" | grep -oE "(tcp|udp).*dpt:[0-9]+")

    if [[ -z "$RULES" ]]; then
        echo -e "${YELLOW}ℹ️  No hay reglas ACCEPT por puerto.${RESET}"
        echo
        read -n1 -r -p "$(trx 'Presione una tecla...')"
        return
    fi

    FOUND=0
    REMOVED=0

    while read -r LINE; do
        PROTO=$(echo "$LINE" | grep -oE "^(tcp|udp)")
        DPORT=$(echo "$LINE" | grep -oE "dpt:[0-9]+" | cut -d: -f2)
        [[ -z "$DPORT" || -z "$PROTO" ]] && continue

        EN_USO=0
        for P in "${PORTS[@]}"; do
            [[ "$P" == "$DPORT" ]] && EN_USO=1
        done

        if [[ "$EN_USO" -eq 0 ]]; then
            FOUND=$((FOUND + 1))
            echo -e "${YELLOW}  ⚠ Puerto $DPORT ($PROTO) — ya NO escucha ningún servicio${RESET}"
            iptables -D INPUT -p "$PROTO" --dport "$DPORT" -j ACCEPT 2>/dev/null
            REMOVED=$((REMOVED + 1))
            if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
                ufw delete allow "$DPORT/$PROTO" >/dev/null 2>&1
            fi
        fi
    done < <(echo "$RULES")

    echo ""
    echo -e "${GREEN}✅ Puertos obsoletos eliminados: $REMOVED${RESET}"
    if [[ "$REMOVED" -eq 0 ]]; then
        echo -e "${WHITE}   Todos los puertos abiertos están en uso. ${GREEN}✔ Bien${RESET}"
    fi
    echo
    read -n1 -r -p "$(trx 'Presione una tecla...')"
}

#--------------------------------------------------
# 6) VER PUERTOS EN ESCUCHA
#--------------------------------------------------
ver_puertos(){

    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${MAGENTA}            📡 PUERTOS EN ESCUCHA${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    echo -e "${WHITE}TCP:${RESET}"
    ss -tlnp 2>/dev/null | grep -vE "127.0.0.1|::1" | head -25
    echo ""
    echo -e "${WHITE}UDP:${RESET}"
    ss -ulnp 2>/dev/null | head -15

    echo ""
    read -n1 -r -p "$(trx 'Presione una tecla...')"
}

#--------------------------------------------------
# PUERTOS EXTRA POR PROTOCOLO
# "Abrir un puerto extra a X protocolo"
# El puerto extra escucha en internet (0.0.0.0) y
# redirige (DNAT) al puerto REAL del protocolo.
# TCP para SSH/SSL/WS..., UDP para udp-custom/hysteria...
#--------------------------------------------------
EXTRA_CONF="$BASE/sistema/puertos_extra.conf"

# Servicios reales escuchando A INTERNET (no loopback)
get_servicios() {
    {
        ss -H -tlnp 2>/dev/null
        ss -H -ulnp 2>/dev/null
    } | grep -vE "127.0.0.1:|\[::1\]:" | while read -r LINE; do
        PROTO=$(echo "$LINE" | awk '{print $1}')
        [[ "$PROTO" == "tcp" || "$PROTO" == "udp" ]] || continue
        PUERTO=$(echo "$LINE" | grep -oE ':[0-9]+' | head -1 | tr -d ':')
        PROC=$(echo "$LINE" | grep -oE 'users:\(\("[^"]+' | sed 's/users:(("//')
        [[ -n "$PUERTO" ]] && echo "$PROTO|$PUERTO|${PROC:-desconocido}"
    done
}

abrir_extra() {

    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${MAGENTA}   ➕ ABRIR PUERTO EXTRA A PROTOCOLO${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    echo -e "${WHITE}El puerto extra escuchará en internet (0.0.0.0) y${RESET}"
    echo -e "${WHITE}redirigirá al puerto real del protocolo (DNAT).${RESET}"
    echo ""

    mapfile -t SERVICIOS < <(get_servicios)

    if [[ ${#SERVICIOS[@]} -eq 0 ]]; then
        echo -e "${YELLOW}ℹ️  No hay servicios escuchando a internet.${RESET}"
        echo
        read -n1 -r -p "$(trx 'Presione una tecla...')"
        return
    fi

    echo -e "${WHITE}Protocolos detectados (escuchando a internet):${RESET}"
    echo ""
    for i in "${!SERVICIOS[@]}"; do
        IFS='|' read -r PROTO REAL PROC <<< "${SERVICIOS[$i]}"
        printf "  ${GREEN}%2d)${RESET} ${WHITE}%-16s${RESET} puerto ${CYAN}%s${RESET} (${YELLOW}%s${RESET})\n" \
            $((i + 1)) "${PROC:-?}" "$REAL" "$PROTO"
    done
    echo ""
    read -rp "$(trx ' ► Elige protocolo [número]: ')" SEL
    [[ "$SEL" =~ ^[0-9]+$ ]] || { echo -e "${RED}❌ Número inválido.${RESET}"; sleep 2; return; }
    IDX=$((SEL - 1))
    [[ -n "${SERVICIOS[$IDX]}" ]] || { echo -e "${RED}❌ Opción inválida.${RESET}"; sleep 2; return; }

    IFS='|' read -r PROTO REAL PROC <<< "${SERVICIOS[$IDX]}"

    echo ""
    read -rp "$(trx ' ► Puerto EXTRA a abrir: ')" EXTRA
    [[ "$EXTRA" =~ ^[0-9]+$ ]] || { echo -e "${RED}❌ Puerto inválido.${RESET}"; sleep 2; return; }

    if ss -H -tln 2>/dev/null | grep -q ":$EXTRA " || ss -H -uln 2>/dev/null | grep -q ":$EXTRA "; then
        echo -e "${RED}❌ El puerto $EXTRA ya está en uso.${RESET}"
        sleep 2
        return
    fi

    # Regla DNAT: puerto extra → 127.0.0.1:puerto_real
    iptables -t nat -C PREROUTING -p "$PROTO" --dport "$EXTRA" -j DNAT --to-destination 127.0.0.1:"$REAL" 2>/dev/null \
        || iptables -t nat -A PREROUTING -p "$PROTO" --dport "$EXTRA" -j DNAT --to-destination 127.0.0.1:"$REAL"

    # Aceptar el puerto extra en INPUT (precaución) y el destino en FORWARD
    iptables -C INPUT -p "$PROTO" --dport "$EXTRA" -j ACCEPT 2>/dev/null \
        || iptables -A INPUT -p "$PROTO" --dport "$EXTRA" -j ACCEPT
    iptables -C FORWARD -p "$PROTO" --dport "$REAL" -j ACCEPT 2>/dev/null \
        || iptables -A FORWARD -p "$PROTO" --dport "$REAL" -j ACCEPT

    # Guardar para re-aplicar tras reboot/sync
    grep -q "^${PROTO}|${EXTRA}|" "$EXTRA_CONF" 2>/dev/null \
        || echo "$PROTO|$EXTRA|$REAL|$PROC" >> "$EXTRA_CONF"

    echo ""
    echo -e "${GREEN}✅ Puerto extra $EXTRA ($PROTO) → ${PROC:-protocolo} (puerto $REAL)${RESET}"
    echo -e "${WHITE}   Ahora se puede conectar a 0.0.0.0:$EXTRA y llega al protocolo.${RESET}"
    echo
    read -n1 -r -p "$(trx 'Presione una tecla...')"
}

cerrar_extra() {

    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${MAGENTA}   🗑️  CERRAR PUERTO EXTRA${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    if [[ ! -f "$EXTRA_CONF" ]] || [[ ! -s "$EXTRA_CONF" ]]; then
        echo -e "${YELLOW}ℹ️  No hay puertos extra configurados.${RESET}"
        echo
        read -n1 -r -p "$(trx 'Presione una tecla...')"
        return
    fi

    echo -e "${WHITE}Puertos extra activos:${RESET}"
    echo ""
    mapfile -t EXTRAS < <(grep -v '^#' "$EXTRA_CONF" 2>/dev/null)
    for i in "${!EXTRAS[@]}"; do
        IFS='|' read -r PROTO EXTRA REAL PROC <<< "${EXTRAS[$i]}"
        printf "  ${GREEN}%2d)${RESET} puerto ${CYAN}%s${RESET} (${YELLOW}%s${RESET}) → %s (puerto %s)\n" \
            $((i + 1)) "$EXTRA" "$PROTO" "${PROC:-protocolo}" "$REAL"
    done
    echo ""
    read -rp "$(trx ' ► Elige puerto extra a cerrar [número]: ')" SEL
    [[ "$SEL" =~ ^[0-9]+$ ]] || { echo -e "${RED}❌ Número inválido.${RESET}"; sleep 2; return; }
    IDX=$((SEL - 1))
    [[ -n "${EXTRAS[$IDX]}" ]] || { echo -e "${RED}❌ Opción inválida.${RESET}"; sleep 2; return; }

    IFS='|' read -r PROTO EXTRA REAL PROC <<< "${EXTRAS[$IDX]}"

    iptables -t nat -D PREROUTING -p "$PROTO" --dport "$EXTRA" -j DNAT --to-destination 127.0.0.1:"$REAL" 2>/dev/null
    iptables -D INPUT -p "$PROTO" --dport "$EXTRA" -j ACCEPT 2>/dev/null
    iptables -D FORWARD -p "$PROTO" --dport "$REAL" -j ACCEPT 2>/dev/null

    sed -i "\|^${PROTO}|${EXTRA}|.*|d" "$EXTRA_CONF" 2>/dev/null

    echo ""
    echo -e "${GREEN}✅ Puerto extra $EXTRA cerrado y reglas eliminadas.${RESET}"
    echo
    read -n1 -r -p "$(trx 'Presione una tecla...')"
}

# Re-aplicar puertos extra guardados (reboot/sync)
reaplicar_extras() {
    [[ -f "$EXTRA_CONF" ]] || return
    while IFS='|' read -r PROTO EXTRA REAL PROC; do
        [[ -z "$EXTRA" || "$PROTO" == "#"* ]] && continue
        iptables -t nat -C PREROUTING -p "$PROTO" --dport "$EXTRA" -j DNAT --to-destination 127.0.0.1:"$REAL" 2>/dev/null \
            || iptables -t nat -A PREROUTING -p "$PROTO" --dport "$EXTRA" -j DNAT --to-destination 127.0.0.1:"$REAL"
        iptables -C INPUT -p "$PROTO" --dport "$EXTRA" -j ACCEPT 2>/dev/null \
            || iptables -A INPUT -p "$PROTO" --dport "$EXTRA" -j ACCEPT
        iptables -C FORWARD -p "$PROTO" --dport "$REAL" -j ACCEPT 2>/dev/null \
            || iptables -A FORWARD -p "$PROTO" --dport "$REAL" -j ACCEPT
    done < "$EXTRA_CONF"
}

while true
do

clear

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${MAGENTA}            🔥 FIREWALL${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo ""
echo "$(trx ' [1] ➮ Abrir Puerto')"
echo "$(trx ' [2] ➮ Cerrar Puerto')"
echo "$(trx ' [3] ➮ Estado Firewall')"
echo -e " ${GREEN}$(trx ' [4] ➮ Sincronizar puertos de protocolos (auto)')${RESET}"
echo -e " ${YELLOW}$(trx ' [5] ➮ Cerrar puertos obsoletos')${RESET}"
echo "$(trx ' [6] ➮ Ver puertos en escucha')"
echo -e " ${MAGENTA}$(trx ' [7] ➮ Abrir puerto EXTRA a un protocolo')${RESET}"
echo -e " ${MAGENTA}$(trx ' [8] ➮ Cerrar puerto extra')${RESET}"
echo ""
echo "$(trx ' [0] ➮ Regresar')"
echo ""

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

read -rp "$(trx ' ► Opción: ')" OP

case "$OP" in

1)
abrir
;;

2)
cerrar
;;

3)
estado
;;

4)
sincronizar
;;

5)
cerrar_obsoletos
;;

6)
ver_puertos
;;

7)
abrir_extra
;;

8)
cerrar_extra
;;

0)
exec bash "$BASE/herramientas/menu.sh"
;;

*)
echo ""
echo -e "${RED}❌ Opción inválida.${RESET}"
sleep 2
;;

esac

done