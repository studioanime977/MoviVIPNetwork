#!/bin/bash
#====================================================================
# scripts/expira-exacta.sh — Verificador de expiración EXACTA (minuto)
# MoviVIP Network v8.0 · cron: * * * * *
#
# COMPORTAMIENTO v8.0 (suspender, NO eliminar):
#   Al vencer, el usuario NO se borra: se BLOQUEA (passwd -l) + se
#   fuerza expiración (chage -E) y su home/datos se conservan.
#   Se registra en /etc/movivip/sistema/suspendidos.conf para que el
#   admin pueda REACTIVARLO desde el panel (usuarios/reactivar.sh).
#
# Lee /etc/movivip/sistema/expiraciones_exactas.conf (USUARIO|EPOCH)
# Barrido de respaldo: usuarios SSH (UID>=1000, nologin) con chage -E
# vencido que no estén en el conf exacto.
# Log: /etc/movivip/sistema/expira-exacta.log (rota a 200 KB)
#====================================================================
BASE="/etc/movivip"
CONF="$BASE/sistema/expiraciones_exactas.conf"
SUSP="$BASE/sistema/suspendidos.conf"
LOG="$BASE/sistema/expira-exacta.log"
NOW=$(date +%s)

[ -x /usr/sbin/passwd ] && PASSD=/usr/sbin/passwd || PASSD=$(command -v passwd)
[ -x /usr/sbin/usermod ] && USERMOD=/usr/sbin/usermod || USERMOD=$(command -v usermod)
[ -x /usr/sbin/chage ] && CHAGE=/usr/sbin/chage || CHAGE=$(command -v chage)
[ -x /usr/bin/pkill ] && PKILL=/usr/bin/pkill || PKILL=$(command -v pkill)

touch "$SUSP" 2>/dev/null

# Rotar log si excede 200 KB
if [ -f "$LOG" ] && [ "$(wc -c < "$LOG")" -gt 204800 ]; then
    mv -f "$LOG" "$LOG.1" 2>/dev/null
fi

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG" 2>/dev/null; }

# Suspender un usuario vencido (bloquear, NO eliminar)
suspend_user() {
    local U="$1"
    local WHY="$2"
    [ -z "$U" ] && return
    # No tocar root ni UIDs del sistema (UID >= 1000)
    local UID_N="$(id -u "$U" 2>/dev/null)"
    [ -z "$UID_N" ] && return
    if [ "$UID_N" -lt 1000 ]; then log "SKIP $U (uid=$UID_N sistema)"; return; fi
    # ya suspendido? no duplicar
    grep -q "^${U}|" "$SUSP" 2>/dev/null && { log "YA_SUSPENDIDO $U — omitido"; return; }
    # 1) bloquear login
    "$PASSD" -l "$U" >> "$LOG" 2>&1
    # 2) matar conexiones activas
    "$PKILL" -u "$U" >> "$LOG" 2>&1
    # 3) forzar expiración en el sistema (ayer) — doble seguro
    "$CHAGE" -E "$(date -d 'yesterday' +%F)" "$U" >> "$LOG" 2>&1
    # 4) registrar para reactivación
    echo "${U}|${NOW}" >> "$SUSP" 2>/dev/null
    log "SUSPENDIDO $U ($WHY) uid=$UID_N — home conservado"
}

# --- 1) Conf exacta (precisión al minuto) ---
if [ -f "$CONF" ]; then
    while IFS='|' read -r U TS REST; do
        [ -z "$U" ] && continue
        case "$U" in \#*) continue;; esac
        [ -z "$TS" ] && continue
        if [ "$TS" -le "$NOW" ]; then
            suspend_user "$U" "exacta:epoch=$TS"
            # limpiar línea del conf exacto (queda en suspendidos.conf)
            sed -i "/^${U}|/d" "$CONF" 2>/dev/null
        fi
    done < "$CONF"
fi

# --- 2) Barrido respaldo: usuarios SSH vencidos por chage (días) ---
# Solo UID>=1000 con shell nologin; respeta listas de exclusión
if command -v chage >/dev/null 2>&1; then
    awk -F: '$3>=1000 && $3<60000 && $7 ~ /(nologin|false)$/ {print $1, $3}' /etc/passwd 2>/dev/null |
    while read -r U UID_N; do
        [ -z "$U" ] && continue
        case "$U" in \#*) continue;; esac
        # Si está en el conf exacto, ya lo maneja la fase 1 (epoch futuro)
        grep -q "^${U}|" "$CONF" 2>/dev/null && continue
        EXP_CH=$("$CHAGE" -l "$U" 2>/dev/null | awk -F': ' '/Account expires/{print $2}')
        [ -z "$EXP_CH" ] || [ "$EXP_CH" = "never" ] && continue
        EXP_EPOCH=$(date -d "$EXP_CH" +%s 2>/dev/null)
        [ -z "$EXP_EPOCH" ] && continue
        if [ "$EXP_EPOCH" -le "$NOW" ]; then
            suspend_user "$U" "chage:$EXP_CH"
        fi
    done
fi

exit 0