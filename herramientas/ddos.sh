#!/bin/bash
#==================================================
# MoviVIP Network Premium v5.7 - ANTI-DDoS MANAGER
# Port mejorado del concepto DDosManager (ADMRufu):
#   · Protección global (SYN cookies + connlimit + ICMP)
#   · Vigilancia POR PUERTO específico
#   · Baneo manual de IPs con LOCK TEMPORAL (auto-expira)
#   · Whitelist persistente vía ipset
#   · Top atacantes + logs históricos
# Reglas etiquetadas comment MOVIVIP-DDOS* para remoción
# precisa sin tocar otras reglas del panel.
#==================================================

BASE="/etc/movivip"
DD="$BASE/ddos"
WL_FILE="$DD/whitelist.list"
BANS_FILE="$DD/bans.list"
PORTS_FILE="$DD/puertos.conf"
LOG_FILE="$DD/bans.log"
GLOBAL_FLAG="$DD/global.state"
SYSCTL_CONF="/etc/sysctl.d/99-movivip-antiddos.conf"
IPSET_WL="MOVI_WL"
DEFAULT_BAN_TIME="3600"   # 1 hora por defecto

CYAN="\e[1;96m"; GREEN="\e[1;92m"; RED="\e[1;91m"
GOLD="\e[1;93m"; MAGENTA="\e[1;95m"; WHITE="\e[1;97m"; GRAY="\e[1;90m"; RESET="\e[0m"

mkdir -p "$DD"
touch "$WL_FILE" "$BANS_FILE" "$PORTS_FILE" "$LOG_FILE" 2>/dev/null

need_ipset(){
    if ! command -v ipset >/dev/null 2>&1; then
        echo -e "${GRAY} ⚙ Instalando ipset...${RESET}"
        apt-get install -y ipset >/dev/null 2>&1
    fi
}

wl_sync(){
    # vuelca whitelist.list -> ipset MOVI_WL (idempotente)
    need_ipset
    ipset list "$IPSET_WL" >/dev/null 2>&1 || \
        ipset create "$IPSET_WL" hash:ip family inet -exist 2>/dev/null
    while read -r IP; do
        [[ -z "$IP" ]] && continue
        ipset add "$IPSET_WL" "$IP" -exist 2>/dev/null
    done < "$WL_FILE"
}

regla(){  # regla <spec>  (idempotente)
    local SPEC="$1"
    iptables -C ${SPEC} 2>/dev/null || iptables -A INPUT ${SPEC}
}

des_regla_por_comment(){
    local CMT="$1"
    iptables-save 2>/dev/null | grep "\-\-comment $CMT" | sed 's/^-A/-D/' | \
        while read -r R; do iptables ${R} 2>/dev/null; done
}

global_on(){
    cat > "$SYSCTL_CONF" <<EOF
# MoviVIP Anti-DDoS
net.ipv4.tcp_syncookies = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
EOF
    sysctl --system >/dev/null 2>&1
    wl_sync
    # whitelist pasa primero (ACCEPT implícito al saltarse los drops):
    regla "-m set ! --match-set $IPSET_WL src -p tcp -m conntrack --ctstate INVALID -j DROP -m comment --comment MOVIVIP-DDOS"
    regla "-m set ! --match-set $IPSET_WL src -p tcp --syn -m connlimit --connlimit-above 80 --connlimit-mask 32 -j DROP -m comment --comment MOVIVIP-DDOS"
    regla "-m set ! --match-set $IPSET_WL src -p tcp --syn -m conntrack --ctstate NEW -m recent --set --name MOVI_SYN -m comment --comment MOVIVIP-DDOS"
    regla "-m set ! --match-set $IPSET_WL src -p tcp --syn -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 40 --name MOVI_SYN -j DROP -m comment --comment MOVIVIP-DDOS"
    regla "-p icmp -m limit --limit 5/s --limit-burst 15 -j ACCEPT -m comment --comment MOVIVIP-DDOS"
    regla "-p icmp -j DROP -m comment --comment MOVIVIP-DDOS"
    echo "ON" > "$GLOBAL_FLAG"
    install_units
}

global_off(){
    des_regla_por_comment "MOVIVIP-DDOS "
    rm -f "$SYSCTL_CONF" "$GLOBAL_FLAG"
    sysctl --system >/dev/null 2>&1
}

watch_port(){   # watch_port <puerto>
    local P="$1"
    wl_sync
    regla "-m set ! --match-set $IPSET_WL src -p tcp --dport $P -m conntrack --ctstate NEW -m connlimit --connlimit-above 40 --connlimit-mask 32 -j DROP -m comment --comment MOVIVIP-DDOS-P$P"
    regla "-m set ! --match-set $IPSET_WL src -p tcp --dport $P --syn -m conntrack --ctstate NEW -m recent --set --name MOVI_P$P -m comment --comment MOVIVIP-DDOS-P$P"
    regla "-m set ! --match-set $IPSET_WL src -p tcp --dport $P --syn -m conntrack --ctstate NEW -m recent --update --seconds 30 --hitcount 25 --rcheck --name MOVI_P$P -j DROP -m comment --comment MOVIVIP-DDOS-P$P"
    grep -qx "$P" "$PORTS_FILE" || echo "$P" >> "$PORTS_FILE"
    install_units
}

unwatch_port(){  # unwatch_port <puerto>
    des_regla_por_comment "MOVIVIP-DDOS-P$1"
    sed -i "/^$1$/d" "$PORTS_FILE"
}

ban_ip(){   # ban_ip <IP> <segundos> <motivo>
    local IP="$1" SECS="${2:-$DEFAULT_BAN_TIME}" MOTIVO="${3:-manual}"
    [[ "$IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
    grep -qx "$IP" "$WL_FILE" && return 2     # nunca banear whitelist
    local EXP=$(( $(date +%s) + SECS ))
    sed -i "/^$IP:/d" "$BANS_FILE"
    echo "$IP:$EXP" >> "$BANS_FILE"
    iptables -C INPUT -s "$IP"/32 -j DROP -m comment --comment MOVIVIP-DDOS-BAN 2>/dev/null || \
        iptables -A INPUT -s "$IP"/32 -j DROP -m comment --comment MOVIVIP-DDOS-BAN
    echo "$(date '+%F %T') BAN $IP (${SECS}s) motivo=$motivo" >> "$LOG_FILE"
    install_units
}

unban_ip(){  # unban_ip <IP>
    local IP="$1"
    sed -i "/^$IP:/d" "$BANS_FILE"
    iptables -D INPUT -s "$IP"/32 -j DROP -m comment --comment MOVIVIP-DDOS-BAN 2>/dev/null
    echo "$(date '+%F %T') UNBAN $IP (manual)" >> "$LOG_FILE"
}

gc_bans(){  # elimina bans expirados (modo --gc, lo llama el timer)
    [[ -s "$BANS_FILE" ]] || return 0
    local NOW=$(date +%s) KEEP="" IP EXP CHANGED=0
    while IFS=: read -r IP EXP; do
        [[ -z "$IP" ]] && continue
        if (( EXP > NOW )); then
            KEEP+="$IP:$EXP"$'\n'
        else
            iptables -D INPUT -s "$IP"/32 -j DROP -m comment --comment MOVIVIP-DDOS-BAN 2>/dev/null
            echo "$(date '+%F %T') AUTO-UNBAN $IP (lock expirado)" >> "$LOG_FILE"
            CHANGED=1
        fi
    done < "$BANS_FILE"
    (( CHANGED )) && printf "%s" "$KEEP" > "$BANS_FILE"
}

restore_boot(){  # llamado por movivip-ddos.service al arranque
    wl_sync
    gc_bans
    local NOW=$(date +%s) IP EXP
    while IFS=: read -r IP EXP; do
        [[ -z "$IP" ]] && continue
        (( EXP > NOW )) && \
            iptables -C INPUT -s "$IP"/32 -j DROP -m comment --comment MOVIVIP-DDOS-BAN 2>/dev/null || \
            iptables -A INPUT -s "$IP"/32 -j DROP -m comment --comment MOVIVIP-DDOS-BAN
    done < "$BANS_FILE"
    [[ "$(cat "$GLOBAL_FLAG" 2>/dev/null)" == "ON" ]] && global_on
    while read -r P; do
        [[ -n "$P" ]] && watch_port "$P"
    done < "$PORTS_FILE"
}

install_units(){
    cat > /etc/systemd/system/movivip-ddos.service <<EOF
[Unit]
Description=MoviVIP Anti-DDoS restore/GC
After=network-pre.target
Before=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash $BASE/herramientas/ddos.sh --boot

[Install]
WantedBy=multi-user.target
EOF
    cat > /etc/systemd/system/movivip-ddos.timer <<EOF
[Unit]
Description=MoviVIP Anti-DDoS GC timer

[Timer]
OnBootSec=2min
OnUnitActiveSec=60s

[Install]
WantedBy=timers.target
EOF
    cat > /etc/systemd/system/movivip-ddos-gc.service <<EOF
[Unit]
Description=MoviVIP Anti-DDoS GC pass

[Service]
Type=oneshot
ExecStart=/bin/bash $BASE/herramientas/ddos.sh --gc
EOF
    systemctl daemon-reload
    systemctl enable --now movivip-ddos.timer >/dev/null 2>&1
}

persist_rules(){
    if command -v netfilter-persistent >/dev/null 2>&1; then
        netfilter-persistent save >/dev/null 2>&1
    else
        mkdir -p /etc/iptables 2>/dev/null
        iptables-save > /etc/iptables/rules.v4 2>/dev/null
    fi
}

fmt_tiempo(){  # segundos -> "1h 23m"
    local S=$1 H M
    H=$(( S / 3600 )); M=$(( (S % 3600) / 60 ))
    (( H > 0 )) && echo "${H}h ${M}m" || echo "${M}m ${S}s"
}

#──────────────────────────────────────────────
# PANTALLAS
#──────────────────────────────────────────────

scr_estado(){
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${MAGENTA}          🛡 ANTI-DDoS · ESTADO${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    SC=$(sysctl -n net.ipv4.tcp_syncookies 2>/dev/null)
    NGL=$(iptables-save 2>/dev/null | grep -c "MOVIVIP-DDOS " )
    NB=$(wc -l < "$BANS_FILE"); NP=$(wc -l < "$PORTS_FILE"); NW=$(grep -c . "$WL_FILE")
    [[ "$SC" == "1" && -f "$GLOBAL_FLAG" ]] && G="${GREEN}ACTIVA${RESET}" || G="${RED}INACTIVA${RESET}"
    echo -e " Protección global : $G"
    echo -e " Puertos vigilados : ${WHITE}$NP${RESET}   ${GRAY}$(paste -sd, "$PORTS_FILE")${RESET}"
    echo -e " IPs baneadas      : ${RED}$NB${RESET}"
    echo -e " Whitelist         : ${GREEN}$NW${RESET} IPs"
    echo ""
    if (( NB > 0 )); then
        echo -e "${GOLD} ── Locks activos ──${RESET}"
        local NOW=$(date +%s) IP EXP
        while IFS=: read -r IP EXP; do
            [[ -z "$IP" ]] && continue
            if (( EXP > NOW )); then
                printf "  ${RED}%-16s${RESET} expira en %s\n" "$IP" "$(fmt_tiempo $((EXP-NOW)))"
            fi
        done < "$BANS_FILE"
        echo ""
    fi
    echo -e "${GOLD} ── Top conexiones por puerto vigilado ──${RESET}"
    for P in $(cat "$PORTS_FILE"); do
        TOP=$(ss -tn state established "( sport = :$P )" 2>/dev/null | \
              grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort | uniq -c | sort -rn | head -3)
        if [[ -n "$TOP" ]]; then
            echo -e " ${CYAN}▸ Puerto $P${RESET}"
            echo "$TOP" | while read -r C IP; do
                WL=""; grep -qx "$IP" "$WL_FILE" && WL=" ${GREEN}[WL]${RESET}"
                BN=""; grep -q "^$IP:" "$BANS_FILE" && BN=" ${RED}[BAN]${RESET}"
                printf "    %-16s %s conns%s%s\n" "$IP" "$C" "$WL" "$BN"
            done
        fi
    done
    echo ""
    read -n1 -r -p " Presione una tecla..."
}

scr_global_toggle(){
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${MAGENTA}       🛡 PROTECCIÓN GLOBAL ANTI-DDoS${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    if [[ -f "$GLOBAL_FLAG" ]]; then
        read -rp " ► Desactivar protección global? (s/N): " R
        [[ "$R" =~ ^[sS]$ ]] && { global_off; persist_rules; echo -e " ${GREEN}✅ Desactivada${RESET}"; }
    else
        read -rp " ► Activar protección global? (S/n): " R
        if [[ ! "$R" =~ ^[nN]$ ]]; then
            global_on; persist_rules
            echo -e " ${GREEN}✅ ACTIVA${RESET} ${GRAY}· syncookies · connlimit 80/IP · SYN 40/min · ICMP 5/s${RESET}"
        fi
    fi
    sleep 2
}

scr_puerto(){
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${MAGENTA}       🎯 VIGILANCIA POR PUERTO${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    echo -e "${GRAY} Vigilados:${RESET} $(paste -sd' ' "$PORTS_FILE" 2>/dev/null)"
    echo ""
    read -rp " ► Puerto TCP a vigilar (vacío=volver): " P
    [[ -z "$P" ]] && return
    if ! [[ "$P" =~ ^[0-9]+$ ]] || (( P < 1 || P > 65535 )); then
        echo -e " ${RED}❌ Puerto inválido${RESET}"; sleep 2; return
    fi
    if grep -qx "$P" "$PORTS_FILE"; then
        read -rp " ► Puerto $P YA vigilado. Quitar? (s/N): " R
        [[ "$R" =~ ^[sS]$ ]] && { unwatch_port "$P"; persist_rules; echo -e " ${GREEN}✅ Puerto $P liberado${RESET}"; }
    else
        watch_port "$P"; persist_rules
        echo -e " ${GREEN}✅ Puerto $P vigilado${RESET} ${GRAY}(connlimit 40/IP · SYN burst 25/30s)${RESET}"
    fi
    sleep 2
}

scr_ban(){
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${MAGENTA}       ⛔ BANEAR IP (LOCK TEMPORAL)${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    read -rp " ► IP a banear: " IP
    [[ -z "$IP" ]] && return
    if ! [[ "$IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        echo -e " ${RED}❌ IP inválida${RESET}"; sleep 2; return
    fi
    if grep -qx "$IP" "$WL_FILE"; then
        echo -e " ${GOLD}⚠ La IP está en whitelist — quítala antes de banear${RESET}"; sleep 2; return
    fi
    read -rp " ► Duración del lock en minutos [60]: " MIN
    MIN=${MIN:-60}; [[ "$MIN" =~ ^[0-9]+$ ]] || MIN=60
    CONNS=$(ss -tn state established "( sport = :* )" 2>/dev/null | grep -c "$IP" || true)
    ban_ip "$IP" $((MIN*60)) "menu ($CONNS conns)"
    if (( $? == 0 )); then
        persist_rules
        echo -e " ${RED}⛔ $IP bloqueada${RESET} durante ${WHITE}$MIN min${RESET}"
    fi
    sleep 2
}

scr_unban(){
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${MAGENTA}       ✅ DESBANEAR IP${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    local NOW=$(date +%s) ANY=0 IP EXP
    echo -e "${GRAY}  IP               expira en${RESET}"
    while IFS=: read -r IP EXP; do
        [[ -z "$IP" ]] && continue
        ANY=1
        if (( EXP > NOW )); then T="$(fmt_tiempo $((EXP-NOW)))"; else T="${GRAY}expirando...${RESET}"; fi
        printf "  ${WHITE}%-16s${RESET} %s\n" "$IP" "$T"
    done < "$BANS_FILE"
    (( ANY )) || echo -e " ${GRAY}(ninguna)${RESET}"
    echo ""
    read -rp " ► IP a desbanear (vacío=volver): " IP
    [[ -z "$IP" ]] && return
    unban_ip "$IP" && persist_rules && echo -e " ${GREEN}✅ $IP liberada${RESET}"
    sleep 2
}

scr_whitelist(){
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${MAGENTA}       ⭐ WHITELIST (nunca se banean)${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    NW=$(grep -c . "$WL_FILE")
    echo -e " Registradas: ${GREEN}$NW${RESET}"
    nl -ba "$WL_FILE" | sed 's/^/   /'
    echo ""
    echo -e " ${GOLD}[1]${WHITE} Añadir IP   ${GOLD}[2]${WHITE} Quitar IP   ${GRAY}[otro] volver${RESET}"
    read -rp " ► Opción: " WOP
    case "$WOP" in
        1)
            read -rp " ► IP: " IP
            if [[ "$IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
                grep -qx "$IP" "$WL_FILE" || echo "$IP" >> "$WL_FILE"
                wl_sync; persist_rules
                echo -e " ${GREEN}✅ $IP en whitelist${RESET}"
            else
                echo -e " ${RED}❌ inválida${RESET}"
            fi ;;
        2)
            read -rp " ► IP a quitar: " IP
            sed -i "/^$IP$/d" "$WL_FILE"
            need_ipset; ipset del "$IPSET_WL" "$IP" 2>/dev/null
            echo -e " ${GOLD}⚠ removida${RESET}" ;;
    esac
    sleep 2
}

scr_logs(){
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${MAGENTA}       📜 LOG DE BANEOS (últimos 25)${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    tail -25 "$LOG_FILE" 2>/dev/null | nl -ba -v"$(($(wc -l < "$LOG_FILE") - 24 > 0 ? $(wc -l < "$LOG_FILE") - 24 : 1))" || echo " (vacío)"
    echo ""
    read -n1 -r -p " Presione una tecla..."
}

#──────────────────────────────────────────────
# MODOS SILENCIOSOS (systemd / CLI)
#──────────────────────────────────────────────
case "${1:-}" in
    --gc)   gc_bans; exit 0 ;;
    --boot) restore_boot; exit 0 ;;
    --ban)
        # --ban <IP> [minutos]
        ban_ip "$2" "$(( ${3:-60} * 60 ))" "cli" && echo "BAN $2 OK (${3:-60}min)" || echo "BAN $2 RECHAZADO"
        exit $? ;;
    --unban)
        unban_ip "$2"; persist_rules; echo "UNBAN $2 OK"
        exit 0 ;;
esac

#──────────────────────────────────────────────
# MENÚ PRINCIPAL
#──────────────────────────────────────────────
while true
do
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${MAGENTA}           🛡 ANTI-DDoS MANAGER v5.7${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
cat <<EOF

 [1] ➮ Estado General
 [2] ➮ Protección Global ON/OFF
 [3] ➮ Vigilar Puerto Específico
 [4] ➮ Banear IP (Lock Temporal)
 [5] ➮ Desbanear IP
 [6] ➮ Whitelist
 [7] ➮ Log de Baneos

 [0] ➮ Regresar

EOF
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    read -rp " ► Opcion: " OP
    case "$OP" in
        1) scr_estado ;;
        2) scr_global_toggle ;;
        3) scr_puerto ;;
        4) scr_ban ;;
        5) scr_unban ;;
        6) scr_whitelist ;;
        7) scr_logs ;;
        0) exec bash "$BASE/herramientas/menu.sh" ;;
        *) echo -e "${RED}❌ Opcion invalida.${RESET}"; sleep 1 ;;
    esac
done
