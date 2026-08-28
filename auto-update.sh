#!/bin/bash

#=========================================================
#   MOVIVIP NETWORK — AUTO-UPDATE CHECKER v2 (v6.0.1)
#   Verifica actualizaciones periodicamente
#   Solo descarga si licencia activa
#   Instala silenciosamente en background
#
#   NUEVO v6.0.1 — MOTOR DE INTEGRIDAD:
#    🧹 Repara BOM invisible en cada ejecucion (sin reinstalar)
#    🔍 Detecta errores de sintaxis y los registra
#    🛡 Copia inteligente: NUNCA pisa config/licencia/datos runtime
#    💾 Backup automatico antes de aplicar cambios
#=========================================================

BASE="/etc/movivip"
CONFIG="$BASE/config.conf"
LICENCIA="$BASE/licencia.conf"
LOG="$BASE/logs/auto-update.log"
LOCK="/tmp/movivip_autoupdate.lock"
VERSION_FILE="$BASE/version.txt"
COMMIT_HASH_FILE="$BASE/.last_commit_hash"
REPO="https://github.com/studioanime977/MoviVIPNetwork.git"

# Evitar ejecuciones duplicadas
[[ -f "$LOCK" ]] && { AGE=$(( $(date +%s) - $(stat -c %Y "$LOCK" 2>/dev/null || echo 0) )); [[ $AGE -lt 3600 ]] && exit 0; }
echo $$ > "$LOCK"
trap "rm -f '$LOCK'" EXIT

mkdir -p "$BASE/logs" "$BASE/backups"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"
}

log "=== Auto-update check iniciado ==="

#==============================
# 🧹 MOTOR DE INTEGRIDAD
#==============================
INTEG_DIR="/tmp/movivip_integ_$$"

reparar_bom() {
    local f="$1"
    [ "$(od -A n -t x1 -N 3 "$f" 2>/dev/null | tr -d ' \n')" = "efbbbf" ] || return 1
    local perms
    perms=$(stat -c%a "$f" 2>/dev/null || echo 755)
    local tmp="$INTEG_DIR/bom.tmp"
    mkdir -p "$INTEG_DIR"
    tail -c +4 "$f" > "$tmp"
    sed -i '/./,$!d' "$tmp"
    cat "$tmp" > "$f"
    rm -f "$tmp"
    chmod "$perms" "$f"
    return 0
}

verificar_integridad() {
    mkdir -p "$INTEG_DIR"
    local boms=0 roto=0 f detalles=""
    while IFS= read -r f; do
        head -c 20 "$f" 2>/dev/null | grep -q "MOVIVIP-PACKED" && continue
        if reparar_bom "$f"; then
            boms=$((boms+1))
            detalles+="BOM reparado: ${f#$BASE/}; "
        fi
        if ! bash -n "$f" >/dev/null 2>&1; then
            roto=$((roto+1))
            detalles+="SINTAXIS ROTA: ${f#$BASE/}; "
        fi
        [[ -x "$f" ]] || chmod +x "$f"
    done < <(find "$BASE" -maxdepth 3 -name "*.sh" ! -path "$BASE/logs/*" ! -path "$BASE/.pack-backup/*" ! -path "$BASE/backups/*" 2>/dev/null | sort)

    # Fix CRLF heredado de ediciones en Windows
    find "$BASE" -maxdepth 3 -name "*.sh" -type f ! -path "$BASE/backups/*" -exec sed -i 's/\r$//' {} + 2>/dev/null

    rm -rf "$INTEG_DIR"

    if [[ $boms -gt 0 || $roto -gt 0 ]]; then
        log "🧹 INTEGRIDAD: $boms BOM reparados, $roto rotos. $detalles"
    fi
}

# La integridad se verifica SIEMPRE, haya o no actualizacion
verificar_integridad

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
# VERIFICAR VERSIÓN + COMMIT HASH
#==============================

LOCAL_VER=$(tr -d ' \n' < "$VERSION_FILE" 2>/dev/null || echo "0")
REMOTE_VER=$(curl -fsSL --max-time 5 "https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/version.txt" 2>/dev/null | tr -d ' \n')
[[ -z "$REMOTE_VER" ]] && REMOTE_VER=$(curl -fsSL --max-time 8 "https://api.github.com/repos/studioanime977/MoviVIPNetwork/contents/version.txt" 2>/dev/null \
    | grep -o '"content":"[^"]*"' | head -1 | cut -d'"' -f4 | base64 -d 2>/dev/null | tr -d ' \n')

if [[ -z "$REMOTE_VER" ]]; then
    log "No se pudo obtener versión remota"
    exit 0
fi

REMOTE_SHA=$(curl -fsSL --max-time 8 "https://api.github.com/repos/studioanime977/MoviVIPNetwork/commits/main" 2>/dev/null \
    | grep -o '"sha":"[a-f0-9]*"' | head -1 | cut -d'"' -f4)
LOCAL_SHA=""
[[ -f "$COMMIT_HASH_FILE" ]] && LOCAL_SHA=$(cat "$COMMIT_HASH_FILE" 2>/dev/null)

VERSION_CHANGED=false
COMMIT_CHANGED=false

[[ "$LOCAL_VER" != "$REMOTE_VER" ]] && VERSION_CHANGED=true
[[ -n "$REMOTE_SHA" && "$REMOTE_SHA" != "$LOCAL_SHA" ]] && COMMIT_CHANGED=true

if [[ "$VERSION_CHANGED" == "false" && "$COMMIT_CHANGED" == "false" ]]; then
    log "Ya actualizado (v${LOCAL_VER}, commit ok)"
    exit 0
fi

if [[ "$VERSION_CHANGED" == "true" ]]; then
    log "Nueva versión: v${LOCAL_VER} → v${REMOTE_VER}"
else
    log "Cambios detectados en commit: ${LOCAL_SHA:0:8} → ${REMOTE_SHA:0:8}"
fi

#==============================
# DESCARGAR Y ACTUALIZAR (copia inteligente)
#==============================

TEMP_DIR="/tmp/movivip_autoupdate_$$"

git clone --depth 1 "$REPO" "$TEMP_DIR" 2>/dev/null
if [[ $? -ne 0 ]]; then
    log "Error al clonar repositorio"
    rm -rf "$TEMP_DIR"
    exit 1
fi

SCRIPTS_SRC=$(find "$TEMP_DIR" -name "install.sh" -type f -exec dirname {} \; 2>/dev/null | head -1)
if [[ -z "$SCRIPTS_SRC" ]]; then
    SCRIPTS_SRC="$TEMP_DIR"
fi

# Backup completo antes de tocar nada (sin logs ni backups previos)
BK="$BASE/backups/auto_$(date +%Y%m%d_%H%M%S).tar.gz"
tar czf "$BK" -C /etc --exclude='movivip/logs' --exclude='movivip/backups' movivip 2>/dev/null
log "💾 Backup pre-actualizacion: $BK ($(du -h "$BK" 2>/dev/null | cut -f1))"

# Guardar datos runtime que el repo NUNCA debe pisar
KEEP="$TEMP_DIR/_datos_servidor.tar"
tar cf "$KEEP" -C "$BASE" \
    --ignore-failed-read \
    config.conf licencia.conf .last_commit_hash .env-bot .env \
    sistema/consumo_snapshots.conf sistema/consumo_usuarios.conf \
    sistema/limites_conexiones.conf sistema/limites_consumo.conf \
    sistema/network_state.conf sistema/xray_limites.conf sistema/xray_ports.conf \
    ddos/puertos.conf 2>/dev/null

# Copiar todo el repo encima
cp -rf "$SCRIPTS_SRC"/. "$BASE"/ 2>/dev/null
UPDATED=$(find "$SCRIPTS_SRC" -type f | wc -l)

# Restaurar datos del servidor por encima del repo
if [[ -f "$KEEP" ]]; then
    tar xf "$KEEP" -C "$BASE" 2>/dev/null
    log "🛡 Datos runtime protegidos y restaurados (config/licencia/sistema/ddos)"
fi

echo "$REMOTE_VER" > "$VERSION_FILE"
[[ -n "$REMOTE_SHA" ]] && echo "$REMOTE_SHA" > "$COMMIT_HASH_FILE"
chmod -R +x "$BASE"/*.sh "$BASE"/lib/*.sh "$BASE"/protocolos/*.sh "$BASE"/herramientas/*.sh "$BASE"/usuarios/*.sh "$BASE"/languages/*.sh 2>/dev/null
chmod 600 "$BASE/licencia.conf" "$BASE/config.conf" 2>/dev/null

# Fix CRLF from Windows + verificacion final de integridad
find "$BASE" -name "*.sh" -type f ! -path "$BASE/backups/*" -exec sed -i 's/\r$//' {} + 2>/dev/null
verificar_integridad

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

log "✅ Actualización completada: v${LOCAL_VER} → v${REMOTE_VER} (${UPDATED} archivos). Integridad verificada."
