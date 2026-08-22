#!/bin/bash
#==================================================
# MoviVIP Network Premium
# Monitor de CUOTA de datos para cuentas HWID
# (puerto de limitTrafic()/limitarUsuario() de ADMRufu apiAccess)
#
# - Cuenta tráfico por usuario con cadenas iptables
#   (OUTPUT owner-match: el tráfico de túneles SSH se genera
#    con el UID del usuario tras el auth de sshd).
# - Acumula consumo en USED_BYTES dentro del .hwid
# - Si LIMIT_GB > 0 y consumo >= cuota → BLOQUEA la cuenta
#   (passwd -l + kill sesiones) y registra en hwid_bloqueos.log
#
# Ejecutar por cron cada 5 min (lo instala hwid_limite.sh):
#   */5 * * * * bash /etc/movivip/herramientas/hwid_quota_monitor.sh
#==================================================

BASE="/etc/movivip"
HWID_DIR="$BASE/hwids"
LOG="$BASE/sistema/hwid_bloqueos.log"

mkdir -p "$HWID_DIR" "$BASE/sistema"

[[ -d "$HWID_DIR" ]] || exit 0
command -v iptables >/dev/null 2>&1 || exit 0

#--------------------------------------------------
# upsert_field ARCHIVO CAMPO VALOR
# Reemplaza o agrega "CAMPO: VALOR" sin duplicar
#--------------------------------------------------
upsert_field() {
    local FILE="$1" KEY="$2" VAL="$3"
    if grep -q "^${KEY}:" "$FILE" 2>/dev/null; then
        sed -i "s|^${KEY}:.*|${KEY}: ${VAL}|" "$FILE"
    else
        echo "${KEY}: ${VAL}" >> "$FILE"
    fi
}

shopt -s nullglob
for f in "$HWID_DIR"/*.hwid; do

    U=$(grep -m1 "^USER:" "$f" | cut -d' ' -f2)
    [[ -z "$U" ]] && continue
    id "$U" &>/dev/null || continue

    UID_N=$(id -u "$U")

    # Cuota (0 = ilimitado)
    LIMIT_GB=$(grep -m1 "^LIMIT_GB:" "$f" | cut -d' ' -f2)
    [[ "$LIMIT_GB" =~ ^[0-9]+$ ]] || LIMIT_GB=0

    #--------------------------------------------------
    # Cadena iptables contadora (nombre máx 28 chars:
    # MV_HWID_ + 20 de usuario OK)
    #--------------------------------------------------
    CHAIN="MV_HWID_${U}"
    iptables -nL "$CHAIN" &>/dev/null || iptables -N "$CHAIN" 2>/dev/null
    # Regla RETURN que cuenta todo el tráfico que pasa por la cadena
    iptables -S "$CHAIN" 2>/dev/null | grep -q "^-A.*-j RETURN" || \
        iptables -A "$CHAIN" -j RETURN 2>/dev/null
    # Salto desde OUTPUT solo para este UID
    iptables -C OUTPUT -m owner --uid-owner "$UID_N" -j "$CHAIN" 2>/dev/null || \
        iptables -I OUTPUT 1 -m owner --uid-owner "$UID_N" -j "$CHAIN" 2>/dev/null

    # Bytes acumulados en el contador de la regla RETURN
    CUR=$(iptables -vxL "$CHAIN" 2>/dev/null | awk '/-j RETURN|RETURN /{print $2; exit}')
    [[ "$CUR" =~ ^[0-9]+$ ]] || CUR=0

    # Delta contra última lectura (counter se resetea en reboot/flush)
    LAST=$(grep -m1 "^LAST_COUNTER:" "$f" | cut -d' ' -f2)
    [[ "$LAST" =~ ^[0-9]+$ ]] || LAST=0
    USED=$(grep -m1 "^USED_BYTES:" "$f" | cut -d' ' -f2)
    [[ "$USED" =~ ^[0-9]+$ ]] || USED=0

    if (( CUR >= LAST )); then
        DELTA=$((CUR - LAST))
    else
        DELTA=$CUR   # contador reiniciado (reboot) → todo lo actual es nuevo
    fi
    NEW_USED=$((USED + DELTA))

    upsert_field "$f" "USED_BYTES" "$NEW_USED"
    upsert_field "$f" "LAST_COUNTER" "$CUR"
    upsert_field "$f" "QUOTA_CHECK" "$(date +%s)"

    #--------------------------------------------------
    # ¿Cuota agotada? → bloquear
    #--------------------------------------------------
    if (( LIMIT_GB > 0 )); then
        LIMIT_B=$((LIMIT_GB * 1073741824))
        YA_LOCKED=$(grep -m1 "^QUOTA_LOCKED:" "$f" | cut -d' ' -f2)

        if (( NEW_USED >= LIMIT_B )) && [[ "$YA_LOCKED" != "yes" ]]; then
            passwd -l "$U" >/dev/null 2>&1
            pkill -u "$U" >/dev/null 2>&1
            upsert_field "$f" "QUOTA_LOCKED" "yes"
            {
                echo "$(date '+%Y-%m-%d %H:%M:%S') ⚠ CUOTA AGOTADA: $U consumió $(awk "BEGIN{printf \"%.2f\", $NEW_USED/1073741824}")GB de ${LIMIT_GB}GB → cuenta BLOQUEADA"
            } >> "$LOG"
        fi
    fi

done
exit 0
