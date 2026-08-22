#!/bin/bash
# MoviVIP Network — Suite de pruebas v5.4 (rediseño ADMRufu)
BASE=/etc/movivip
LOG=/tmp/test54.log
: > "$LOG"

MENUS="menu.sh protocolos/menu.sh protocolos/openssh.sh protocolos/systemdns.sh protocolos/badvpn.sh protocolos/udpcustom.sh protocolos/dropbear.sh protocolos/checkuser.sh protocolos/ssl.sh protocolos/slowdns.sh protocolos/hysteria.sh protocolos/v2ray.sh protocolos/zipvpn.sh herramientas/menu.sh usuarios/menu.sh"

PASS=0; FAILS=0
ALL_OUT=""

for M in $MENUS; do
    OUT=$(timeout 5 bash "$BASE/$M" </dev/null 2>&1)
    ALL_OUT="$ALL_OUT$OUT"
    if echo "$OUT" | grep -q '➤'; then
        PASS=$((PASS+1)); echo "PASS selector ➤ : $M" >> "$LOG"
    else
        FAILS=$((FAILS+1)); echo "FAIL selector ➤ : $M" >> "$LOG"
    fi
    if echo "$OUT" | grep -q '\[01\]'; then
        PASS=$((PASS+1)); echo "PASS item [01]  : $M" >> "$LOG"
    else
        FAILS=$((FAILS+1)); echo "FAIL item [01]  : $M" >> "$LOG"
    fi
    if echo "$OUT" | grep -q 'MoviVIPNetwork\|WhatsApp'; then
        PASS=$((PASS+1)); echo "PASS contactos  : $M" >> "$LOG"
    else
        FAILS=$((FAILS+1)); echo "FAIL contactos  : $M" >> "$LOG"
    fi
done

if echo "$ALL_OUT" | grep -qE '\[[0-9]\] ?➮'; then
    FAILS=$((FAILS+1)); echo "FAIL estatico residual detectado:" >> "$LOG"
    echo "$ALL_OUT" | grep -nE '\[[0-9]\] ?➮' | head -5 >> "$LOG"
else
    PASS=$((PASS+1)); echo "PASS sin menus estaticos duplicados" >> "$LOG"
fi

echo "" >> "$LOG"
echo "== RESULTADO SUITE v5.4: $PASS PASS · $FAILS FAIL ==" >> "$LOG"
