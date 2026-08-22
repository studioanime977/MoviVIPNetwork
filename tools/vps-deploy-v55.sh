#!/bin/bash
# MoviVIP Network — Deploy v5.5 (2 columnas + dashboard unificado + puertos)
set -u
BASE=/etc/movivip
STG=/tmp/mv55
FAIL=0

echo "== 1) Syntax check staging =="
for f in lib/nav.sh menu.sh protocolos/menu.sh; do
    bash -n "$STG/$f" || { echo "SYNTAX FAIL: $f"; FAIL=1; }
done
[[ $FAIL -eq 1 ]] && { echo ABORT; exit 1; }
echo "OK 3/3"

echo "== 2) Purga backups =="
rm -f "$BASE/.pack-backup/menu.sh" "$BASE/.pack-backup/protocolos/menu.sh"

echo "== 3) Instalar =="
cp -f "$STG/lib/nav.sh" "$BASE/lib/nav.sh"
cp -f "$STG/menu.sh" "$BASE/menu.sh"
cp -f "$STG/protocolos/menu.sh" "$BASE/protocolos/menu.sh"
find "$BASE/lib/nav.sh" "$BASE/menu.sh" "$BASE/protocolos/menu.sh" -exec sed -i 's/\r$//' {} +
chmod +x "$BASE/lib/nav.sh" "$BASE/menu.sh" "$BASE/protocolos/menu.sh"
echo "OK"

echo "== 4) Test runtime =="
ERR=0
OUT=$(timeout 35 bash "$BASE/menu.sh" </dev/null 2>&1)
echo "$OUT" | grep -q '\[01\]' || { echo "FAIL main sin [01]"; ERR=1; }
echo "$OUT" | grep -q '\[11\]' || { echo "FAIL main SIN columna derecha [11]"; ERR=1; }
echo "$OUT" | grep -q 'MoviVIPNetwork' || { echo "FAIL main sin contactos"; ERR=1; }
echo "$OUT" | grep -q '🛡️' || { echo "FAIL sin escudo"; ERR=1; }
if echo "$OUT" | grep -q '║.*║'; then echo "WARN box residual"; fi
P=$(timeout 20 bash "$BASE/protocolos/menu.sh" </dev/null 2>&1)
echo "$P" | grep -q '\[22\]' || { echo "FAIL proto sin puerto 22"; ERR=1; }
echo "$P" | grep -q '\[53/5300\]' || { echo "FAIL proto sin puerto slowdns"; ERR=1; }
echo "$P" | grep -q '\[01\]' || { echo "FAIL proto sin selector"; ERR=1; }
N=$(timeout 20 bash "$BASE/herramientas/menu.sh" </dev/null 2>&1)
echo "$N" | grep -q '\[01\]' || { echo "FAIL tools roto"; ERR=1; }
[[ $ERR -eq 0 ]] && echo "TEST OK" || { echo ABORT-TESTS; exit 1; }

echo "== 5) Re-pack =="
bash "$BASE/tools/ofuscar.sh" "$BASE" 2>&1 | tail -3
echo "== DEPLOY v5.5 COMPLETADO =="
