#!/bin/bash
# =========================================================
#   MOVIVIP NETWORK — LAUNCHER UNIVERSAL
#   Limpia CRLF de TODO el árbol y ejecuta el script indicado.
#   Todos los launchers de /usr/local/bin delegan aquí:
#     exec bash /etc/movivip/lib/launch.sh <script> "$@"
#   Esto garantiza que ningún script del panel se ejecute con
#   CRLF (evita el bug de doble-llamada/re-ejecución global).
# =========================================================
MV_BASE="/etc/movivip"

if [ -f "$MV_BASE/lib/fixcrlf.sh" ]; then
    # shellcheck disable=SC1091
    source "$MV_BASE/lib/fixcrlf.sh"
    fix_crlf_all
fi

TARGET="${1:?Uso: launch.sh <script> [arg...]}"
shift

exec bash "$TARGET" "$@"
