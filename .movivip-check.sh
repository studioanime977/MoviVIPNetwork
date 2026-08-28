#!/bin/bash
# Check temporal: sintaxis + limpieza repo
# ── i18n shim (auto) ───────────────────────────────
if ! declare -F trx >/dev/null 2>&1; then trx() { printf '%s' "$1"; }; fi
# ─────────────────────────────────────────────────────────
cd "$(dirname "$0")" || exit 1

rm -f herramientas/monitor.sh
mv -f herramientas/change-domain herramientas/change-domain.sh 2>/dev/null

echo "$(trx '== SINTAXIS ==')"
FAIL=0
for f in lib/nav.sh menu.sh protocolos/menu.sh herramientas/menu.sh; do
    if bash -n "$f" 2>&1; then
        echo "OK   $f"
    else
        echo "FAIL $f"
        FAIL=1
    fi
done

echo ""
echo "$(trx '== VERIFICACIONES ==')"
grep -q "nav_pick" menu.sh && echo "OK   menu.sh usa nav_pick" || { echo "FAIL nav_pick en menu.sh"; FAIL=1; }
grep -q "movivip_footer" protocolos/menu.sh && echo "OK   protocolos footer" || { echo "FAIL footer"; FAIL=1; }
grep -q "usuarios/online.sh" herramientas/menu.sh && echo "OK   [12] -> online.sh" || { echo "FAIL online.sh ref"; FAIL=1; }
grep -q "movivip_soporte_screen" menu.sh && echo "OK   case 18 Soporte" || { echo "FAIL soporte"; FAIL=1; }
[[ -f herramientas/monitor.sh ]] && { echo "FAIL monitor.sh sigue existiendo"; FAIL=1; } || echo "OK   monitor.sh eliminado"
[[ -f herramientas/change-domain.sh ]] && echo "OK   change-domain.sh renombrado" || { echo "FAIL rename"; FAIL=1; }

exit $FAIL
