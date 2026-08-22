#!/bin/bash
# MoviVIP Network — Finalizar deploy v5.4 (hysteria fix + verify corregido + re-pack)
set -u
BASE=/etc/movivip
STG=/tmp/mv54
FAIL=0

echo "== 1) Syntax check hysteria en staging =="
bash -n "$STG/protocolos/hysteria.sh" || { echo "SYNTAX FAIL"; exit 1; }
echo "OK"

echo "== 2) Instalar hysteria actualizado =="
cp -f "$STG/protocolos/hysteria.sh" "$BASE/protocolos/hysteria.sh" || { echo "COPY FAIL"; exit 1; }
sed -i 's/\r$//' "$BASE/protocolos/hysteria.sh"
chmod +x "$BASE/protocolos/hysteria.sh"
rm -f "$BASE/.pack-backup/protocolos/hysteria.sh"
echo "OK"

echo "== 3) Verificacion final (patron corregido) =="
ERR=0
grep -q 'movivip_sub_header' "$BASE/lib/nav.sh" || { echo "FAIL nav.sh sin sub_header"; ERR=1; }
grep -q '\[00\]' "$BASE/lib/nav.sh" || { echo "FAIL nav.sh sin [00]"; ERR=1; }
grep -q 'movivip_contacts' "$BASE/lib/nav.sh" || { echo "FAIL nav.sh sin contacts"; ERR=1; }
for f in "$BASE"/protocolos/menu.sh "$BASE"/protocolos/openssh.sh "$BASE"/protocolos/systemdns.sh "$BASE"/protocolos/badvpn.sh "$BASE"/protocolos/dropbear.sh "$BASE"/protocolos/checkuser.sh "$BASE"/protocolos/ssl.sh "$BASE"/protocolos/slowdns.sh "$BASE"/protocolos/hysteria.sh "$BASE"/protocolos/v2ray.sh "$BASE"/protocolos/zipvpn.sh "$BASE"/herramientas/menu.sh "$BASE"/usuarios/menu.sh; do
    grep -q 'movivip_sub_header' "$f" || { echo "FAIL header ausente: $f"; ERR=1; }
    if grep -q 'movivip_footer' "$f"; then echo "FAIL footer presente: $f"; ERR=1; fi
done
# menu principal: contactos integrados en header (inline)
grep -q 'MoviVIPNetwork\|WhatsApp' "$BASE/menu.sh" || { echo "FAIL menu.sin contactos"; ERR=1; }
if grep -q 'movivip_footer' "$BASE/menu.sh"; then echo "FAIL footer presente: menu.sh"; ERR=1; fi
# catalogo estatico residual single-digit
if grep -rE '\[[0-9]\] ?➮' "$BASE/protocolos" "$BASE/menu.sh" "$BASE/herramientas/menu.sh" "$BASE/usuarios/menu.sh" >/dev/null 2>&1; then
    echo "FAIL menu estatico residual:"; grep -rnE '\[[0-9]\] ?➮' "$BASE/protocolos" "$BASE/herramientas" "$BASE/usuarios" | head -5; ERR=1
fi
if [[ $ERR -eq 0 ]]; then echo "VERIFICACION OK (15 archivos)"; else echo "ABORT"; exit 1; fi

echo "== 4) Re-pack ofuscar =="
bash "$BASE/tools/ofuscar.sh" "$BASE" 2>&1 | tail -4
echo "Backups empaquetados: $(ls "$BASE/.pack-backup" 2>/dev/null | wc -l)"
echo "== DEPLOY v5.4 COMPLETADO =="
