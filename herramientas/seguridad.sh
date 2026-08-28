#!/bin/bash
#=========================================================
#  MoviVIP/KevinTech · SEGURIDAD ANTI-MINERO v1.0
#  Detecta y elimina mineros, watchdogs, espías y backdoors
#  Uso:  bash seguridad.sh            (menú interactivo)
#        bash seguridad.sh --scan     (solo escaneo, sin tocar nada)
#        bash seguridad.sh --auto     (modo cron: escanea y cuarentena)
#=========================================================

# ---- BASE auto-detect (MoviVPN o KevinTech) ----
# ── i18n shim (auto) ───────────────────────────────
if ! declare -F trx >/dev/null 2>&1; then trx() { printf '%s' "$1"; }; fi
# ─────────────────────────────────────────────────────────
BASE="/etc/kevintech"
[[ -d "/etc/movivip" ]] && BASE="/etc/movivip"
LOG="/var/log/$(basename $BASE)-seguridad.log"
CUARENTENA="/root/.cuarentena"
FECHA="$(date '+%d/%m/%Y %H:%M:%S')"

C="\e[1;96m"; G="\e[1;92m"; Y="\e[1;93m"; R="\e[1;91m"; W="\e[1;97m"; X="\e[0m"

AMENAZAS=0
DETALLES=""

log() { echo "[$FECHA] $1" >> "$LOG"; }

titulo() {
clear
echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${X}"
echo -e "${W}          🛡  SEGURIDAD ANTI-MINERO  🛡${X}"
echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${X}"
}

#=========================================================
# ESCANEO
#=========================================================
escanear() {

echo ""
echo -e "${Y}[1/7] Procesos sospechosos (mineros)...${X}"
MINER_PIDS=$(ps -eo pid,pcpu,args --no-headers | grep -viE 'grep|seguridad\.sh' | \
  grep -iE 'xmrig|stratum\+|cryptonight|kryptex|minergate|nanopool|f2pool|supportxmr|kdevtmpfsi|kinsing|/tmp/[a-z]+\s*$' | awk '{print "- PID "$1" ("$2"% CPU): "$3}')
[[ -n "$MINER_PIDS" ]] && AMENAZAS=$((AMENAZAS+1)) && DETALLES="$DETALLES\n$MINER_PIDS"
[[ -z "$MINER_PIDS" ]] && echo -e "      ${G}✓ Ningún proceso minero activo${X}" || echo -e "      ${R}$MINER_PIDS${X}"

echo -e "${Y}[2/7] Binarios falsos conocidos...${X}"
FAKE=""
for f in /usr/local/bin/systemd /usr/local/bin/xmrig /usr/local/bin/kdevtmpfsi \
         /usr/local/bin/kinsing /usr/local/bin/free_proc.sh /usr/local/bin/watchdog \
         /tmp/xmr /tmp/systemd /dev/shm/xmrig /var/tmp/systemd; do
    [[ -f "$f" ]] && FAKE="$FAKE $f"
done
# falso curl = binario llamado curl en /usr/local/bin mas chico de 100KB (el real pesa ~250KB)
[[ -f /usr/local/bin/curl && $(stat -c%s /usr/local/bin/curl) -lt 100000 ]] && FAKE="$FAKE /usr/local/bin/curl(PEQUEÑO=FAKE)"
if [[ -n "$FAKE" ]]; then
    AMENAZAS=$((AMENAZAS+1)); DETALLES="$DETALLES\nBinarios falsos:$FAKE"
    echo -e "      ${R}✗ ENCONTRADOS:$FAKE${X}"
else
    echo -e "      ${G}✓ Sin binarios falsos${X}"
fi

echo -e "${Y}[3/7] Unidades systemd maliciosas...${X}"
UNITS_MAL=""
for u in systemd.service observed.service xmr.service miner.service sync.service; do
    [[ -f "/etc/systemd/system/$u" ]] && UNITS_MAL="$UNITS_MAL $u"
done
# unidades cuyo ExecStart apunte a binarios ya marcados como falsos
if [[ -n "$FAKE" ]]; then
    for b in $FAKE; do
        bp=$(echo "$b" | cut -d'(' -f1)
        grep -l "$bp" /etc/systemd/system/*.service 2>/dev/null >> /dev/null && \
          UNITS_MAL="$UNITS_MAL $(grep -l "$bp" /etc/systemd/system/*.service 2>/dev/null | xargs -n1 basename | tr '\n' ' ')"
    done
fi
UNITS_MAL=$(echo "$UNITS_MAL" | tr ' ' '\n' | sort -u | tr '\n' ' ')
if [[ -n "${UNITS_MAL// }" ]]; then
    AMENAZAS=$((AMENAZAS+1)); DETALLES="$DETALLES\nUnidades maliciosas:$UNITS_MAL"
    echo -e "      ${R}✗ ENCONTRADAS:$UNITS_MAL${X}"
else
    echo -e "      ${G}✓ Sin unidades maliciosas${X}"
fi

echo -e "${Y}[4/7] Rootkits (ld.so.preload)...${X}"
if [[ -s /etc/ld.so.preload ]]; then
    AMENAZAS=$((AMENAZAS+1))
    DETALLES="$DETALLES\n/etc/ld.so.preload NO vacio: $(cat /etc/ld.so.preload)"
    echo -e "      ${R}✗ ld.so.preload tiene contenido: $(cat /etc/ld.so.preload)${X}"
else
    echo -e "      ${G}✓ Sin rootkit preload${X}"
fi

echo -e "${Y}[5/7] Cron jobs sospechosos...${X}"
CRON_MAL=$( { crontab -l 2>/dev/null; cat /etc/cron.d/* 2>/dev/null; } | \
  grep -E '(curl|wget).*(\| *(ba)?sh|bash)' | grep -vE 'localhost|127\.0\.0\.1' )
[[ -n "$CRON_MAL" ]] && AMENAZAS=$((AMENAZAS+1)) && DETALLES="$DETALLES\nCron sospechoso:\n$CRON_MAL"
[[ -z "$CRON_MAL" ]] && echo -e "      ${G}✓ Crontab limpio${X}" || echo -e "      ${R}✗ $CRON_MAL${X}"

echo -e "${Y}[6/7] Últimos accesos root (revisa IPs desconocidas)...${X}"
last -n 8 -a root 2>/dev/null | head -9

echo -e "${Y}[7/7] Salud del sistema...${X}"
CORES=$(nproc)
LOAD=$(awk '{print int($1*100/('"$CORES"'))}' /proc/loadavg)
MEMAV=$(free -m | awk '/Mem:/{print $7}')
SWAPU=$(free -m | awk '/Swap:/{print $3}')
CT=$(sysctl -n net.netfilter.nf_conntrack_count 2>/dev/null || echo 0)
CTMAX=$(sysctl -n net.netfilter.nf_conntrack_max 2>/dev/null || echo 1)
UDPERR=$(netstat -su 2>/dev/null | awk '/receive buffer errors/{print $1}')
TOPROC=$(ps -eo pcpu,args --no-headers --sort=-pcpu | head -1)
echo -e "      Load: ${W}${LOAD}%${X} de ${W}${CORES} core(s)${X} | RAM libre: ${W}${MEMAV}MB${X} | Swap usado: ${W}${SWAPU}MB${X}"
echo -e "      Conntrack: ${W}${CT}/${CTMAX}${X} | Errores buffer UDP: ${W}${UDPERR:-0}${X}"
echo -e "      Proceso top: ${W}${TOPROC:0:70}${X}"

echo ""
echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${X}"
if [[ $AMENAZAS -eq 0 ]]; then
    echo -e "  ${G}✅ SERVIDOR LIMPIO — sin amenazas detectadas${X}"
    log "SCAN: limpio (load ${LOAD}%, ram ${MEMAV}MB)"
else
    echo -e "  ${R}🚨 $AMENAZAS CATEGORIA(S) DE AMENAZA DETECTADA(S):${X}"
    echo -e "$DETALLES"
    log "SCAN: $AMENAZAS amenazas -> $DETALLES"
fi
echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${X}"
}

#=========================================================
# LIMPIEZA
#=========================================================
limpiar() {
if [[ $AMENAZAS -eq 0 ]]; then
    echo ""
    echo -e "${G}Nada que limpiar.${X}"; sleep 2; return
fi
echo ""
if [[ "$1" != "--forzar" ]]; then
    read -rp "$(echo -e "${R}► ¿Cuarentenar y eliminar TODAS las amenazas? (s/n): ${X}")" CONF
    [[ "$CONF" != "s" && "$CONF" != "S" ]] && return
fi

mkdir -p "$CUARENTENA"
echo ""

# matar procesos mineros
ps -eo pid,args --no-headers | grep -viE 'grep|seguridad\.sh' | grep -iE 'xmrig|stratum\+|cryptonight|kryptex|minergate|kdevtmpfsi|kinsing' | \
  awk '{print $1}' | while read p; do kill -9 "$p" 2>/dev/null && echo -e "${G}✓ Proceso minero $p eliminado${X}"; done
pkill -9 -f free_proc.sh 2>/dev/null

# cuarentenar binarios y unidades
for f in /usr/local/bin/systemd /usr/local/bin/xmrig /usr/local/bin/kdevtmpfsi \
         /usr/local/bin/kinsing /usr/local/bin/free_proc.sh /usr/local/bin/watchdog; do
    [[ -f "$f" ]] && mv "$f" "$CUARENTENA/$(basename $f).$(date +%s)" && echo -e "${G}✓ Cuarentena: $f${X}"
done
[[ -f /usr/local/bin/curl && $(stat -c%s /usr/local/bin/curl) -lt 100000 ]] && \
  mv /usr/local/bin/curl "$CUARENTENA/curl-falso.$(date +%s)" && echo -e "${G}✓ Cuarentena: falso curl${X}"

for u in systemd observed xmr miner sync; do
    if [[ -f "/etc/systemd/system/$u.service" ]]; then
        systemctl stop "$u.service" 2>/dev/null
        systemctl disable "$u.service" 2>/dev/null
        mv "/etc/systemd/system/$u.service" "$CUARENTENA/$u.service.$(date +%s)" && echo -e "${G}✓ Unidad eliminada: $u.service${X}"
    fi
done
# limpiar cron malicioso
if [[ -n "$CRON_MAL" ]]; then
    crontab -l 2>/dev/null | grep -vE '(curl|wget).*(\| *(ba)?sh)' | crontab -
    echo -e "${G}✓ Cron malicioso removido del crontab root${X}"
fi
# preload
[[ -s /etc/ld.so.preload ]] && : > /etc/ld.so.preload && echo -e "${G}✓ ld.so.preload vaciado${X}"
# basura tipica de droppers
rm -rf /tmp/.X11-units /tmp/.font-unix /tmp/curl.log /tmp/config.json /tmp/a /tmp/b 2>/dev/null

systemctl daemon-reload 2>/dev/null
systemctl reset-failed 2>/dev/null

echo ""
echo -e "${W}⏳ Esperando 65s para verificar que nada resucite...${X}"
sleep 65
RECHECK=$(ps -eo args --no-headers | grep -ciE 'xmrig|stratum\+|kryptex|kdevtmpfsi|kinsing' 2>/dev/null)
if [[ "${RECHECK:-0}" -eq 0 ]]; then
    echo -e "${G}✅ VERIFICADO: ninguna amenaza resucitó${X}"
    log "LIMPIEZA OK - nada resucito tras 65s"
else
    echo -e "${R}⚠ Algo resucitó — reinicia el servidor o revisa manualmente${X}"
    log "ALERTA: amenaza resucito tras limpieza"
fi
}

#=========================================================
# MODOS
#=========================================================
case "$1" in
--scan)
    titulo; escanear; exit 0 ;;
--auto)
    # modo cron: silencioso, cuarentena directa si hay amenazas confirmadas
    escanear > /dev/null 2>&1
    if [[ $AMENAZAS -gt 0 ]]; then
        limpiar --forzar >> "$LOG" 2>&1
        log "AUTO: $AMENAZAS amenazas -> CUARENTENA APLICADA AUTOMATICAMENTE"
    else
        log "AUTO: servidor limpio"
    fi
    exit 0 ;;
*)
    titulo
    escanear
    echo ""
    echo -e " ${G}[1]${W} ➮ Limpiar amenazas encontradas"
    echo -e " ${G}[2]${W} ➮ Re-escanear"
    echo -e " ${Y}[0]${W} ➮ Salir"
    echo ""
    read -rp "$(trx ' ► Opción: ')" OP
    case "$OP" in
        1) limpiar ;;
        2) exec bash "$0" --scan ;;
        *) clear ;;
    esac
    ;;
esac
