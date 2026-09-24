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


# ── i18n shim (auto) ───────────────────────────────
if ! declare -F trx >/dev/null 2>&1; then trx() { printf '%s' "$1"; }; fi
# ─────────────────────────────────────────────────────────

# Design System premium + navegación + idioma
[[ -f "$BASE/lib/ui.sh" ]] && source "$BASE/lib/ui.sh"
[[ -f "$BASE/lib/nav.sh" ]] && source "$BASE/lib/nav.sh" 2>/dev/null || true
if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)"
fi

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
# Soporta RANGOS: open_ports "UDP:1-36712" (abre 1:36712 en iptables/ufw)
open_ports() {

    local spec proto ports p

    for spec in "$@"; do
        proto="${spec%%:*}"
        ports="${spec#*:}"

        IFS=',' read -ra PORT_LIST <<< "$ports"

        for p in "${PORT_LIST[@]}"; do
            p=$(echo "$p" | tr -d ' ')

            [[ -z "$p" ]] && continue

            # Convertir rango con guion (1-36712) al formato iptables/ufw (1:36712)
            if [[ "$p" =~ ^[0-9]+-[0-9]+$ ]]; then
                p="${p/-/:}"
            fi

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

                if [[ "$p" =~ ^[0-9]+-[0-9]+$ ]]; then
                    p="${p/-/:}"
                fi

                ufw allow "$p/$proto" >/dev/null 2>&1
            done
        done
    fi

    enable_nat

}
