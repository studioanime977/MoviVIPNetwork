#!/bin/bash
#==================================================
# MoviVIP Network Premium - Anti-DDoS
# Proteccion: SYN cookies + ConnLimit + ICMP limit
# Reglas etiquetadas con comment MOVIVIP-DDOS para
# remocion precisa sin tocar otras reglas del panel.
#==================================================

BASE="/etc/movivip"

CYAN="\e[1;96m"
GREEN="\e[1;92m"
RED="\e[1;91m"
MAGENTA="\e[1;95m"
WHITE="\e[1;97m"
RESET="\e[0m"

SYSCTL_CONF="/etc/sysctl.d/99-movivip-antiddos.conf"

reglas_activas(){
    iptables-save 2>/dev/null | grep -c "MOVIVIP-DDOS"
}

aplicar_regla(){
    # aplicar_regla <spec>  -> idempotente (-C antes de -A)
    local SPEC="$1"
    iptables -C ${SPEC} 2>/dev/null || iptables -A INPUT ${SPEC}
}

activar(){

    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${MAGENTA}        🛡 ACTIVAR ANTI-DDOS${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    echo " ⚙️ Aplicando hardening de kernel..."

    cat > "$SYSCTL_CONF" <<EOF
# MoviVIP Anti-DDoS
net.ipv4.tcp_syncookies = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
EOF

    sysctl --system >/dev/null 2>&1

    echo " 🔥 Insertando reglas iptables..."

    # 1) Descartar paquetes INVALIDOS (scans, floods corruptos)
    aplicar_regla "-p tcp -m conntrack --ctstate INVALID -j DROP -m comment --comment MOVIVIP-DDOS"

    # 2) Limite de conexiones simultaneas por IP (SYN flood)
    aplicar_regla "-p tcp --syn -m connlimit --connlimit-above 80 --connlimit-mask 32 -j DROP -m comment --comment MOVIVIP-DDOS"

    # 3) Rate-limit por IP sobre SYNs nuevos (60s ventana)
    aplicar_regla "-p tcp --syn -m conntrack --ctstate NEW -m recent --set --name MOVI_SYN -m comment --comment MOVIVIP-DDOS"
    aplicar_regla "-p tcp --syn -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 40 --name MOVI_SYN -j DROP -m comment --comment MOVIVIP-DDOS"

    # 4) ICMP flood: acepta 5/s con burst 15, descarta el resto
    aplicar_regla "-p icmp -m limit --limit 5/s --limit-burst 15 -j ACCEPT -m comment --comment MOVIVIP-DDOS"
    aplicar_regla "-p icmp -j DROP -m comment --comment MOVIVIP-DDOS"

    # Persistencia (si existe el mecanismo estandar)
    mkdir -p /etc/iptables 2>/dev/null
    if command -v netfilter-persistent >/dev/null 2>&1; then
        netfilter-persistent save >/dev/null 2>&1
    elif [[ -d /etc/iptables ]]; then
        iptables-save > /etc/iptables/rules.v4 2>/dev/null
    fi

    echo ""
    echo -e "${GREEN} ✅ Proteccion Anti-DDoS ACTIVA.${RESET}"
    echo ""
    echo " • SYN cookies        : ON"
    echo " • ConnLimit por IP   : 80"
    echo " • Rate SYN por IP    : 40/min"
    echo " • ICMP               : 5/s (burst 15)"
    echo " • Paquetes invalidos : DROP"

    sleep 4

}

desactivar(){

    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${MAGENTA}       ❌ DESACTIVAR ANTI-DDOS${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    N=$(reglas_activas)

    if [[ "$N" -eq 0 ]]; then
        echo " ℹ️ No hay reglas activas."
        rm -f "$SYSCTL_CONF"
        sleep 2
        return
    fi

    echo " 🗑 Eliminando $N reglas..."

    iptables-save 2>/dev/null | grep "MOVIVIP-DDOS" | \
        sed 's/^-A/-D/' | while read -r RULE; do
            iptables ${RULE} 2>/dev/null
        done

    rm -f "$SYSCTL_CONF"
    sysctl --system >/dev/null 2>&1

    if command -v netfilter-persistent >/dev/null 2>&1; then
        netfilter-persistent save >/dev/null 2>&1
    elif [[ -d /etc/iptables ]]; then
        iptables-save > /etc/iptables/rules.v4 2>/dev/null
    fi

    echo ""
    echo -e "${GREEN} ✅ Proteccion desactivada (${N} reglas eliminadas).${RESET}"

    sleep 3

}

estado(){

    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${MAGENTA}          🛡 ANTI-DDOS ESTADO${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    SC=$(sysctl -n net.ipv4.tcp_syncookies 2>/dev/null)
    N=$(reglas_activas)

    if [[ "$SC" == "1" ]]; then
        echo -e " SYN cookies     : ${GREEN}ACTIVO${RESET}"
    else
        echo -e " SYN cookies     : ${RED}INACTIVO${RESET}"
    fi

    echo -e " Reglas DDOS     : $N"

    if [[ "$N" -gt 0 ]]; then
        echo ""
        echo " ── IPs con mas conexiones ──"
        echo ""
        ss -tn state established 2>/dev/null | \
            grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | \
            grep -v "^127\." | \
            sort | uniq -c | sort -rn | head -10 | \
            while read -r CNT IP; do
                printf " %-18s %s conexiones\n" "$IP" "$CNT"
            done
    fi

    echo ""

    read -n1 -r -p "Presione una tecla..."

}

#==================================================
# Menu Principal
#==================================================

while true
do

    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${MAGENTA}           🛡 ANTI-DDOS${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

cat <<EOF

 [1] ➮ Activar Proteccion
 [2] ➮ Desactivar Proteccion
 [3] ➮ Ver Estado

 [0] ➮ Regresar

EOF

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    read -rp " ► Opcion: " OP

    case "$OP" in

        1) activar ;;
        2) desactivar ;;
        3) estado ;;

        0) exec bash "$BASE/herramientas/menu.sh" ;;

        *)
            echo ""
            echo "❌ Opcion invalida."
            sleep 2
        ;;

    esac

done
