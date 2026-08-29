#!/bin/bash
# MoviVIP Network — Deploy v5.4 (rediseño MoviVIP)
# ── i18n shim (auto) ───────────────────────────────
if ! declare -F trx >/dev/null 2>&1; then trx() { printf '%s' "$1"; }; fi
# ─────────────────────────────────────────────────────────
set -u
BASE=/etc/movivip
STG=/tmp/mv54
FAIL=0

FILES="menu.sh protocolos/menu.sh protocolos/openssh.sh protocolos/systemdns.sh protocolos/badvpn.sh protocolos/udpcustom.sh protocolos/dropbear.sh protocolos/checkuser.sh protocolos/ssl.sh protocolos/slowdns.sh protocolos/hysteria.sh protocolos/v2ray.sh protocolos/zipvpn.sh herramientas/menu.sh usuarios/menu.sh"

echo "$(trx '== 1) Syntax check en staging ==')"
for f in lib/nav.sh $FILES; do
    if ! bash -n "$STG/$f" 2>/tmp/synerr; then
        echo "SYNTAX FAIL: $f"; cat /tmp/synerr; FAIL=1
    fi
done
if [[ $FAIL -eq 1 ]]; then echo "ABORT: errores de sintaxis"; exit 1; fi
echo "$(trx 'OK: 16 archivos con sintaxis valida')"

echo "$(trx '== 2) Purga backups obsoletos (.pack-backup) ==')"
for f in $FILES; do
    rm -f "$BASE/.pack-backup/$f"
done
echo "$(trx 'Purga OK')"

echo "$(trx '== 3) Instalacion ==')"
cp -f "$STG/lib/nav.sh" "$BASE/lib/nav.sh" || FAIL=1
for f in $FILES; do
    cp -f "$STG/$f" "$BASE/$f" || { echo "COPY FAIL: $f"; FAIL=1; }
done
[[ $FAIL -eq 1 ]] && { echo "ABORT instalacion"; exit 1; }
echo "$(trx 'Instalacion OK (16 archivos)')"

echo "$(trx '== 4) CRLF + permisos ==')"
find "$BASE" -name "*.sh" -exec sed -i 's/\r$//' {} +
chmod +x "$BASE"/menu.sh "$BASE"/protocolos/*.sh "$BASE"/herramientas/menu.sh "$BASE"/usuarios/menu.sh "$BASE"/lib/*.sh
echo "OK"

echo "$(trx '== 5) Verificacion de parches ==')"
ERR=0
grep -q 'movivip_sub_header' "$BASE/lib/nav.sh" || { echo "FAIL nav.sh sin sub_header"; ERR=1; }
grep -q '\[00\]' "$BASE/lib/nav.sh" || { echo "FAIL nav.sh sin [00]"; ERR=1; }
grep -q 'movivip_contacts' "$BASE/lib/nav.sh" || { echo "FAIL nav.sh sin contacts"; ERR=1; }
for f in "$BASE"/menu.sh "$BASE"/protocolos/menu.sh "$BASE"/protocolos/openssh.sh "$BASE"/protocolos/systemdns.sh "$BASE"/protocolos/badvpn.sh "$BASE"/protocolos/dropbear.sh "$BASE"/protocolos/checkuser.sh "$BASE"/protocolos/ssl.sh "$BASE"/protocolos/slowdns.sh "$BASE"/protocolos/hysteria.sh "$BASE"/protocolos/v2ray.sh "$BASE"/protocolos/zipvpn.sh "$BASE"/herramientas/menu.sh "$BASE"/usuarios/menu.sh; do
    grep -q 'movivip_sub_header' "$f" || { echo "FAIL header ausente: $f"; ERR=1; }
    if grep -q 'movivip_footer' "$f"; then echo "FAIL footer presente: $f"; ERR=1; fi
done
if grep -rE '\[[0-9]\] ?➮' "$BASE/protocolos" "$BASE/menu.sh" "$BASE/herramientas/menu.sh" "$BASE/usuarios/menu.sh" >/dev/null 2>&1; then
    echo "FAIL menu estatico residual:"; grep -rnE '\[[0-9]\] ?➮' "$BASE/protocolos" | head -3; ERR=1
fi
if [[ $ERR -eq 0 ]]; then echo "VERIFICACION OK"; else echo "ABORT verificacion"; exit 1; fi

echo "$(trx '== 6) Re-pack ==')"
bash "$BASE/tools/ofuscar.sh" "$BASE" 2>&1 | tail -3
echo "Backups empaquetados: $(ls "$BASE/.pack-backup" 2>/dev/null | wc -l)"
echo "$(trx 'DEPLOY v5.4 COMPLETO')"
