#!/bin/bash
#==================================================
# MoviVIP Network
# openports.sh — Helper común de firewall + NAT
# Compatible ARM/x86_64 (Oracle, AWS, Vultr, etc.)
# Uso:
#   source "$BASE/herramientas/openports.sh"
#   open_ports "TCP:80,443,8080,8443" "UDP:2100"
#   enable_nat
#==================================================

get_default_iface() {
    ip -4 route show default 2>/dev/null | awk '{print $5}' | head -1
}

# Activa ip_forward + MASQUERADE en la interfaz por defecto (salida a internet)
enable_nat() {

    sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1

    grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf 2>/dev/null \
        || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

    local DEV
    DEV=$(get_default_iface)

    if [[ -n "$DEV" ]]; then
        iptables -t nat -C POSTROUTING -o "$DEV" -j MASQUERADE 2>/dev/null \
            || iptables -t nat -A POSTROUTING -o "$DEV" -j MASQUERADE
    fi

}

# Abre puertos TCP/UDP en iptables (y ufw si está activo)
# Uso: open_ports "TCP:80,443,8080,8443" "UDP:2100"
open_ports() {

    local spec proto ports p

    for spec in "$@"; do
        proto="${spec%%:*}"
        ports="${spec#*:}"

        IFS=',' read -ra PORT_LIST <<< "$ports"

        for p in "${PORT_LIST[@]}"; do
            p=$(echo "$p" | tr -d ' ')

            [[ -z "$p" ]] && continue

            iptables -C INPUT -p "$proto" --dport "$p" -j ACCEPT 2>/dev/null \
                || iptables -A INPUT -p "$proto" --dport "$p" -j ACCEPT
        done
    done

    if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
        for spec in "$@"; do
            proto="${spec%%:*}"
            ports="${spec#*:}"

            IFS=',' read -ra PORT_LIST <<< "$ports"

            for p in "${PORT_LIST[@]}"; do
                p=$(echo "$p" | tr -d ' ')

                [[ -z "$p" ]] && continue

                ufw allow "$p/$proto" >/dev/null 2>&1
            done
        done
    fi

    enable_nat

}
