#!/bin/bash
# SUITE v5.3 — patrones inequívosos: ➤(selector nav_pick) + WhatsApp(footer)
PASS=0; FAIL=0
t() { # $1 nombre, $2 timeout, $3 ruta
    OUT=$(timeout "$2" bash "$3" </dev/null 2>&1)
    S=$(echo "$OUT" | grep -c '➤')
    W=$(echo "$OUT" | grep -c 'WhatsApp')
    if [[ $S -ge 1 && $W -ge 1 ]]; then
        echo "OK   $1 (selector=$S footer=$W)"; PASS=$((PASS+1))
    else
        echo "FAIL $1 (selector=$S footer=$W)"; FAIL=$((FAIL+1))
    fi
}

t openssh    10 /etc/movivip/protocolos/openssh.sh
t systemdns  10 /etc/movivip/protocolos/systemdns.sh
t badvpn     10 /etc/movivip/protocolos/badvpn.sh
t udpcustom  10 /etc/movivip/protocolos/udpcustom.sh
t dropbear   10 /etc/movivip/protocolos/dropbear.sh
t checkuser  10 /etc/movivip/protocolos/checkuser.sh
t ssl        12 /etc/movivip/protocolos/ssl.sh
t slowdns    12 /etc/movivip/protocolos/slowdns.sh
t hysteria   15 /etc/movivip/protocolos/hysteria.sh
t v2ray      28 /etc/movivip/protocolos/v2ray.sh
t zipvpn     28 /etc/movivip/protocolos/zipvpn.sh
t usuarios   22 /etc/movivip/usuarios/menu.sh

echo "== RESUMEN: $PASS OK · $FAIL FAIL =="
exit 0
