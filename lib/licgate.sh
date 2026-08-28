#!/bin/bash
# ============================================================
#  MoviVIP Network - LICENSE GATE (licgate.sh)
#  Bloquea TODOS los bots cuando la licencia esta vencida
#  o revocada en Firebase. Los protocolos VPN ya instalados
#  NO se tocan (solo bots).
#
#  Uso: licgate.sh check | enforce | status
#    check   -> exit 0 valida / exit 1 invalida (no toca nada)
#    enforce -> invalida: stop+mask bots | valida: restaura
#    status  -> muestra estado completo
#
#  Tolerancia sin internet: 72h (stamp .lic_lastok)
# ============================================================
BASE="/etc/movivip"
LIC="$BASE/licencia.conf"
STAMP="$BASE/.lic_lastok"
GRACE_SECS=259200
FB_BASE="movivip-network-default-rtdb.firebaseio.com"
UNITS="movivip-bot-generador.service movivip-cliente-admin.service movivip-cliente-notif.service"

check_lic() {
    # --- 1) archivo local ---
    [ -f "$LIC" ] || { echo "sin /etc/movivip/licencia.conf"; return 1; }
    . "$LIC" 2>/dev/null
    KEY="${KEY:-}"
    [ -z "$KEY" ] && { echo "licencia.conf sin KEY"; return 1; }
    [ "${LICENCIA_ACTIVA:-true}" = "false" ] && { echo "LICENCIA_ACTIVA=false local"; return 1; }
    AHORA=$(date +%s)
    if [ -n "${EXPIRA:-}" ] && [ "$EXPIRA" != "0" ] && [ "$EXPIRA" -lt "$AHORA" ] 2>/dev/null; then
        echo "licencia vencida (fecha local EXPIRA=$EXPIRA)"
        return 1
    fi
    # --- 2) Firebase online (fuente de verdad) ---
    RESP=$(curl -s --max-time 8 "https://$FB_BASE/licencias_movivip/$KEY.json" 2>/dev/null)
    if [ -z "$RESP" ]; then
        # red caida: gracia offline desde ultima validacion buena
        LAST=$(stat -c %Y "$STAMP" 2>/dev/null || echo 0)
        if [ $((AHORA - LAST)) -gt "$GRACE_SECS" ]; then
            echo "firebase inaccesible y gracia de 72h vencida"
            return 1
        fi
        echo ""   # dentro de gracia: pasa silencioso
        return 0
    fi
    [ "$RESP" = "null" ] && { echo "KEY $KEY no existe en Firebase (revocada/borrada)"; return 1; }
    ACTIVA=$(echo "$RESP" | grep -o '"activa":[a-z]*' | head -1 | cut -d: -f2)
    [ "$ACTIVA" != "true" ] && { echo "KEY marcada inactiva en Firebase"; return 1; }
    FEXP=$(echo "$RESP" | grep -o '"expira":[0-9]*' | head -1 | cut -d: -f2)
    if [ -n "$FEXP" ] && [ "$FEXP" != "0" ] && [ "$FEXP" -lt "$AHORA" ] 2>/dev/null; then
        echo "licencia vencida segun Firebase"
        return 1
    fi
    echo ""
    return 0
}

bloquear_bots() {
    logger -t movivip-licgate "BLOQUEADO: $1 -- deteniendo bots"
    for u in $UNITS; do
        systemctl stop "$u" 2>/dev/null
        systemctl mask "$u" 2>/dev/null
    done
}

restaurar_bots() {
    for u in $UNITS; do
        systemctl unmask "$u" 2>/dev/null
        # solo arrancar las que estaban habilitadas al boot
        if systemctl is-enabled "$u" >/dev/null 2>&1; then
            systemctl is-active --quiet "$u" 2>/dev/null || systemctl start "$u" 2>/dev/null
        fi
    done
}

case "${1:-status}" in
    check)
        MSG=$(check_lic)
        if [ $? -eq 0 ]; then
            touch "$STAMP" 2>/dev/null
            echo "OK: licencia valida ($KEY)${MSG:+ [$MSG]}"
            exit 0
        fi
        echo "INVALIDA: $MSG"
        exit 1
        ;;
    enforce)
        MSG=$(check_lic)
        if [ $? -eq 0 ]; then
            touch "$STAMP" 2>/dev/null
            restaurar_bots
            echo "OK: licencia valida ($KEY) -- bots operativos"
            exit 0
        fi
        bloquear_bots "$MSG"
        echo "BLOQUEADO: $MSG -- bots detenidos y bloqueados"
        exit 1
        ;;
    status)
        echo "== MoviVIP License Gate =="
        if [ -f "$LIC" ]; then
            grep -E '^(KEY|PLAN|CLIENTE|EXPIRA|LICENCIA_ACTIVA|FECHA_ACTIVACION)' "$LIC" 2>/dev/null || cat "$LIC"
        else
            echo "licencia.conf: NO EXISTE"
        fi
        LAST=$(stat -c %Y "$STAMP" 2>/dev/null || echo 0)
        if [ "$LAST" != "0" ]; then
            AHORA=$(date +%s)
            echo "ultima validacion OK: hace $(( (AHORA - LAST) / 3600 ))h (gracia 72h)"
        else
            echo "nunca validado contra Firebase"
        fi
        MSG=$(check_lic); RC=$?
        [ $RC -eq 0 ] && touch "$STAMP" 2>/dev/null
        echo "verificacion: $( [ $RC -eq 0 ] && echo VALIDA || echo INVALIDA ) ${MSG:+($MSG)}"
        echo "-- estado bots --"
        for u in $UNITS; do
            printf '  %-38s %s / %s\n' "$u" "$(systemctl is-active "$u" 2>/dev/null)" "$(systemctl is-enabled "$u" 2>/dev/null)"
        done
        ;;
    *)
        echo "uso: $0 check|enforce|status"
        exit 2
        ;;
esac
