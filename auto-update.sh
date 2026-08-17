#!/bin/bash

#=========================================================
#   MOVIVIP NETWORK — AUTO-UPDATE CHECKER
#   Verifica actualizaciones cada 2 días
#   Solo descarga si licencia activa
#   Instala silenciosamente en background
#=========================================================

BASE="/etc/movivip"
CONFIG="$BASE/config.conf"
LICENCIA="$BASE/licencia.conf"
LOG="$BASE/logs/auto-update.log"
LOCK="/tmp/movivip_autoupdate.lock"
VERSION_FILE="$BASE/version.txt"

# Evitar ejecuciones duplicadas
[[ -f "$LOCK" ]] && { AGE=$(( $(date +%s) - $(stat -c %Y "$LOCK" 2>/dev/null || echo 0) )); [[ $AGE -lt 3600 ]] && exit 0; }
echo $$ > "$LOCK"
trap "rm -f '$LOCK'" EXIT

mkdir -p "$BASE/logs"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"
}

log "=== Auto-update check iniciado ==="

#==============================
# VERIFICAR LICENCIA
#==============================

if [[ ! -f "$LICENCIA" ]]; then
    log "Sin archivo de licencia — saltando"
    exit 0
fi

source "$LICENCIA" 2>/dev/null

[[ -z "$KEY" ]] && { log "Sin KEY configurada — saltando"; exit 0; }
[[ "$LICENCIA_ACTIVA" == "false" ]] && { log "Licencia desactivada — saltando"; exit 0; }

# Verificar expiración local
if [[ "$EXPIRA" != "0" && -n "$EXPIRA" ]]; then
    EXPIRA_TS=$(date -d "$EXPIRA" +%s 2>/dev/null || echo 0)
    NOW_TS=$(date +%s)
    if [[ $EXPIRA_TS -gt 0 && $NOW_TS -gt $EXPIRA_TS ]]; then
        log "Licencia vencida local ($EXPIRA) — saltando"
        exit 0
    fi
fi

# Verificación online contra Firebase
FB_BASE="movivip-network-default-rtdb.firebaseio.com"
FB_URL="https://${FB_BASE}/licencias_movivip/${KEY}.json"
FB_DATA=$(curl -fsSL --max-time 10 "$FB_URL" 2>/dev/null)

if [[ -n "$FB_DATA" ]]; then
    FB_ACTIVA=$(echo "$FB_DATA" | grep -o '"activa":[[:space:]]*true' | head -1)
    if [[ -z "$FB_ACTIVA" ]]; then
        log "Firebase: licencia inactiva — saltando"
        exit 0
    fi

    FB_EXPIRA=$(echo "$FB_DATA" | grep -o '"expira":[[:space:]]*"[^"]*"' | cut -d'"' -f4)
    if [[ -n "$FB_EXPIRA" && "$FB_EXPIRA" != "0" ]]; then
        FB_EXPIRA_TS=$(date -d "$FB_EXPIRA" +%s 2>/dev/null || echo 0)
        NOW_TS=$(date +%s)
        if [[ $FB_EXPIRA_TS -gt 0 && $NOW_TS -gt $FB_EXPIRA_TS ]]; then
            log "Firebase: licencia vencida ($FB_EXPIRA) — saltando"
            exit 0
        fi
    fi
else
    log "Sin respuesta Firebase — fall-open, continuando"
fi

#==============================
# VERIFICAR VERSIÓN
#==============================

LOCAL_VER=$(tr -d ' \n' < "$VERSION_FILE" 2>/dev/null || echo "0")
REMOTE_VER=$(curl -fsSL --max-time 5 "https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/version.txt" 2>/dev/null | tr -d ' \n')

if [[ -z "$REMOTE_VER" ]]; then
    log "No se pudo obtener versión remota"
    exit 0
fi

if [[ "$LOCAL_VER" == "$REMOTE_VER" ]]; then
    log "Ya actualizado (v${LOCAL_VER})"
    exit 0
fi

log "Nueva versión: v${LOCAL_VER} → v${REMOTE_VER}"

#==============================
# DESCARGAR Y ACTUALIZAR
#==============================

TEMP_DIR="/tmp/movivip_autoupdate_$$"
REPO="https://github.com/studioanime977/MoviVIPNetwork.git"

git clone --depth 1 "$REPO" "$TEMP_DIR" 2>/dev/null
if [[ $? -ne 0 ]]; then
    log "Error al clonar repositorio"
    rm -rf "$TEMP_DIR"
    exit 1
fi

SCRIPTS_SRC=$(find "$TEMP_DIR" -name "install.sh" -type f -exec dirname {} \; 2>/dev/null | head -1)
if [[ -z "$SCRIPTS_SRC" ]]; then
    log "Scripts no encontrados en repositorio"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Respaldar antes de actualizar
BACKUP_DIR="$BASE/backups/auto_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp "$CONFIG" "$BACKUP_DIR/" 2>/dev/null
cp "$LICENCIA" "$BACKUP_DIR/" 2>/dev/null
cp "$VERSION_FILE" "$BACKUP_DIR/" 2>/dev/null

# Actualizar
UPDATED=0
for f in "$SCRIPTS_SRC"/*; do
    fname=$(basename "$f")
    [[ "$fname" == "config.conf" ]] && continue
    [[ "$fname" == "backups" ]] && continue
    [[ "$fname" == "SESSION-SUMMARY.md" ]] && continue
    [[ "$fname" == "PLAN-"* ]] && continue

    if [[ -d "$f" ]]; then
        mkdir -p "$BASE/$fname"
        cp -r "$f"/* "$BASE/$fname/" 2>/dev/null
    else
        cp "$f" "$BASE/" 2>/dev/null
    fi
    UPDATED=$((UPDATED + 1))
done

echo "$REMOTE_VER" > "$VERSION_FILE"
chmod -R +x "$BASE"/*.sh "$BASE"/protocolos/*.sh "$BASE"/herramientas/*.sh "$BASE"/usuarios/*.sh "$BASE"/languages/*.sh 2>/dev/null

# Fix CRLF from Windows
find "$BASE" -name "*.sh" -type f -exec sed -i 's/\r$//' {} + 2>/dev/null

# iptables gaming
IFACE=$(ip route get 8.8.8.8 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')
[[ -z "$IFACE" ]] && IFACE="eth0"

for RULE in "7000:7999" "3478:3480" "8000:9000"; do
    iptables -t mangle -C PREROUTING -p udp --dport "$RULE" -j DSCP --set-dscp-class af41 2>/dev/null || \
        iptables -t mangle -A PREROUTING -p udp --dport "$RULE" -j DSCP --set-dscp-class af41
done

iptables -N MOVIVIP_OUT >/dev/null 2>&1
iptables -C OUTPUT -j MOVIVIP_OUT >/dev/null 2>&1 || iptables -I OUTPUT 1 -j MOVIVIP_OUT
iptables-save > /etc/iptables/rules.v4 2>/dev/null

rm -rf "$TEMP_DIR"

log "✅ Actualización completada: v${LOCAL_VER} → v${REMOTE_VER} (${UPDATED} módulos)"
