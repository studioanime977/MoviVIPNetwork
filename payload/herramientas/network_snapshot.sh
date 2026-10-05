#!/bin/bash

# --- MOVIVIP-LICENSE-GUARD --- v4.0.0
__mv_g=/usr/local/bin/movivip-guard; [ -x "$__mv_g" ] || { echo "MOVIVIP: falta $__mv_g. Reinstala el panel." >&2; exit 1; }; "$__mv_g" --gate --as "${BASH_SOURCE[0]:-$0}" || exit $?

#==================================================
# MoviVIP Network - Network Snapshot
#==================================================

BASE="/etc/movivip"

[[ -f "$BASE/lib/ui.sh" ]] && source "$BASE/lib/ui.sh" 2>/dev/null || { echo "ERROR: No se encuentra lib/ui.sh" >&2; exit 1; }
[[ -f "$BASE/lib/nav.sh" ]] && source "$BASE/lib/nav.sh" 2>/dev/null || true
if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh" 2>/dev/null
    load_language "$(get_current_language)" 2>/dev/null || true
fi

if ! declare -F trx >/dev/null 2>&1; then trx() { printf '%s' "$1"; }; fi

SNAPSHOT_DIR="/etc/movivip/herramientas/snapshots"
mkdir -p "$SNAPSHOT_DIR"

# Crea un snapshot del estado de red y devuelve la ruta.
# Se extrajo como funcion para que el menu interactivo y el modo --auto
# compartan exactamente la misma captura.
crear_snapshot() {
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    SNAP_FILE="$SNAPSHOT_DIR/snapshot_$TIMESTAMP.txt"
    {
        echo "=== NETWORK SNAPSHOT $TIMESTAMP ==="
        echo
        echo "=== INTERFACES ==="
        ip -brief addr show
        echo
        echo "=== RUTAS ==="
        ip route show
        echo
        echo "=== PUERTOS ESCUCHANDO ==="
        ss -tuln
        echo
        echo "=== CONEXIONES ESTABLECIDAS ==="
        ss -tn state established
        echo
        echo "=== REGLAS IPTABLES ==="
        iptables -L -n -v 2>/dev/null | head -50
        echo
        echo "=== REGLAS NAT ==="
        iptables -t nat -L -n -v 2>/dev/null | head -30
    } > "$SNAP_FILE"
    echo "$SNAP_FILE"
}

# Modo no interactivo. Lo usan el instalador y cron.
#
# Antes este script solo era un menu (while true + read -rp). El instalador lo
# llamaba sin redirigir entrada y se quedaba colgado para siempre esperando
# teclado en el primer read: la instalacion se comia el timeout entero. Y el
# cron "* * * * *" abria el menu cada minuto. Con --auto hace su trabajo y sale.
case "${1:-}" in
    --auto|--quiet)
        SNAP_FILE=$(crear_snapshot)
        echo "network_snapshot: $SNAP_FILE"
        exit 0
        ;;
esac

while true; do
    clear
    mv_brand_header "$(trx '📸 Network Snapshot')" "$(trx 'Captura y comparación de estado de red')"

    mv_panel_top "$(trx 'OPCIONES')"
    mv_prow "1" "$(trx 'Crear snapshot actual')"
    mv_prow "2" "$(trx 'Listar snapshots')"
    mv_prow "3" "$(trx 'Comparar snapshots')"
    mv_prow "4" "$(trx 'Eliminar snapshot')"
    mv_prow "0" "$(trx 'Regresar')" "$MV_RED"
    mv_panel_bot

    read -rp "$(echo -e "  ${MV_CYN}> ${MV_WHT}$(trx 'Opción'): ${RESET}")" op

    case "$op" in
        1)
            SNAP_FILE=$(crear_snapshot)
            mv_notify_ok "$(trx 'Snapshot creado:') $SNAP_FILE"
            sleep 2
            ;;
        2)
            clear
            mv_brand_header "$(trx '📸 Network Snapshot')" "$(trx 'Snapshots disponibles')"
            mv_panel_top "$(trx 'SNAPSHOTS GUARDADOS')"
            ls -la "$SNAPSHOT_DIR" 2>/dev/null | grep snapshot | sed 's/^/  /' || echo -e "  $(trx 'Sin snapshots')"
            mv_panel_bot
            read -rp "$(trx 'Presiona Enter para volver... ')" _
            ;;
        3)
            echo -e "${CYAN}$(trx 'Ingrese nombre del primer snapshot:')${RESET}"
            read -rp "  " snap1
            echo -e "${CYAN}$(trx 'Ingrese nombre del segundo snapshot:')${RESET}"
            read -rp "  " snap2
            if [[ -f "$SNAPSHOT_DIR/$snap1" && -f "$SNAPSHOT_DIR/$snap2" ]]; then
                clear
                mv_brand_header "$(trx '📸 Network Snapshot')" "$(trx 'Comparación')"
                mv_panel_top "$(trx 'DIFERENCIAS')"
                diff -u "$SNAPSHOT_DIR/$snap1" "$SNAPSHOT_DIR/$snap2" | head -100 | sed 's/^/  /'
                mv_panel_bot
            else
                mv_notify_err "$(trx 'Uno o ambos snapshots no existen')"
            fi
            read -rp "$(trx 'Presiona Enter para volver... ')" _
            ;;
        4)
            read -rp "$(echo -e "  ${MV_GRN}> ${RESET}$(trx 'Nombre del snapshot a eliminar'): ${RESET}")" snap
            if [[ -f "$SNAPSHOT_DIR/$snap" ]]; then
                rm -f "$SNAPSHOT_DIR/$snap"
                mv_notify_ok "$(trx 'Snapshot eliminado')"
            else
                mv_notify_err "$(trx 'Snapshot no encontrado')"
            fi
            sleep 1
            ;;
        0)
            exec bash "$BASE/herramientas/menu.sh"
            ;;
        *)
            mv_notify_err "$(trx 'Opción inválida')"
            sleep 1
            ;;
    esac
done