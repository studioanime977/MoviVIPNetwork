#!/bin/bash
# =========================================================
#   MOVIVIP NETWORK — LIMPIADOR CRLF GLOBAL
#   Normaliza TODOS los .sh de la base a LF.
#   Esto previene el bug de doble-llamada / re-ejecución en
#   TODA la script cuando los scripts llegan desde Windows
#   con CRLF. Se invoca desde los launchers ANTES de lanzar
#   cualquier menú, de modo que todo el árbol queda en LF.
#   Uso: source /etc/movivip/lib/fixcrlf.sh  (define fix_crlf_all)
#        fix_crlf_all                          (ejecuta)
# =========================================================

MV_BASE="${MV_BASE:-/etc/movivip}"

fix_crlf_all() {
    local f tmp sz clean base="$MV_BASE"
    [[ -d "$base" ]] || return 0
    while IFS= read -r -d '' f; do
        [[ -f "$f" && -w "$f" ]] || continue
        sz=$(wc -c < "$f" 2>/dev/null)
        clean=$(tr -d '\r' < "$f" 2>/dev/null | wc -c)
        [[ -n "$sz" && -n "$clean" && "$sz" != "$clean" ]] || continue
        tmp=$(mktemp "$f.fix.XXXXXX" 2>/dev/null)
        [[ -n "$tmp" ]] || continue
        tr -d '\r' < "$f" > "$tmp" 2>/dev/null || { rm -f "$tmp"; continue; }
        chmod --reference="$f" "$tmp" 2>/dev/null || chmod 755 "$tmp" 2>/dev/null
        mv -f "$tmp" "$f" 2>/dev/null
        rm -f "$tmp" 2>/dev/null
    done < <(find "$base" -type f -name '*.sh' -print0 2>/dev/null)
    return 0
}

# Ejecutar de inmediato si se invoca directamente
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    fix_crlf_all
fi
