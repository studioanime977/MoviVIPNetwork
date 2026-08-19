#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════
# notify-activation.sh — Notifica activación de key
# Super Admin: datos completos del VPS
# Proveedor: solo IP
# ═══════════════════════════════════════════════════════════
# Usage: notify-activation.sh <KEY>
# Called by install.sh after gate validation succeeds

set -uo pipefail

KEY="${1:-}"
[[ -z "$KEY" ]] && exit 0

BOT_TOKEN="8808614399:AAF0NZiZJTKxt28bblty1hK-ca1guwVH1K4"
SUPER_ADMIN_ID="***REMOVED_ADMIN_ID***"
DB="/etc/movivip/licencias.db"

# ── Collect VPS data ──
VPS_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "?")
VPS_HOSTNAME=$(hostname 2>/dev/null || echo "?")
VPS_OS=$(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2 || echo "?")
VPS_KERNEL=$(uname -r 2>/dev/null || echo "?")
VPS_RAM=$(free -m 2>/dev/null | awk '/Mem:/{print $2}' || echo "?")
VPS_CPU=$(nproc 2>/dev/null || echo "?")
VPS_DISCO=$(df -h / 2>/dev/null | awk 'NR==2{print $2}' || echo "?")
VPS_FECHA=$(date '+%Y-%m-%d %H:%M:%S')

# ── Look up proveedor Telegram ID from SQLite ──
PROV_TG_ID=""
PROV_NAME=""
if [[ -f "$DB" ]] && command -v sqlite3 >/dev/null 2>&1; then
    PROV_TG_ID=$(sqlite3 "$DB" "SELECT telegram_id FROM licencias WHERE key='$KEY' LIMIT 1;" 2>/dev/null)
    PROV_NAME=$(sqlite3 "$DB" "SELECT cliente FROM licencias WHERE key='$KEY' LIMIT 1;" 2>/dev/null)
fi

# ── Notificar Super Admin (datos completos) ──
MSG_SUPER="🔔 <b>NUEVA ACTIVACION</b>

🔑 Key: <code>$KEY</code>
📋 Plan: <b>vitalicio</b>

🖥️ <b>DATOS DEL VPS:</b>
├ IP: <code>$VPS_IP</code>
├ Hostname: <code>$VPS_HOSTNAME</code>
├ OS: <code>$VPS_OS</code>
├ Kernel: <code>$VPS_KERNEL</code>
├ RAM: <code>${VPS_RAM}MB</code>
├ CPU: <code>${VPS_CPU} cores</code>
├ Disco: <code>$VPS_DISCO</code>
└ Fecha: <code>$VPS_FECHA</code>"

curl -s --max-time 10 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d "chat_id=$SUPER_ADMIN_ID" \
    -d "text=$MSG_SUPER" \
    -d "parse_mode=HTML" \
    -d "disable_web_page_preview=true" >/dev/null 2>&1 &

# ── Notificar Proveedor (solo IP) ──
if [[ -n "$PROV_TG_ID" && "$PROV_TG_ID" =~ ^[0-9]+$ ]]; then
    MSG_PROV="🔔 <b>Tu cliente activo una key</b>

🔑 Key: <code>$KEY</code>
🖥️ IP del VPS: <code>$VPS_IP</code>
📅 Fecha: <code>$VPS_FECHA</code>"

    curl -s --max-time 10 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d "chat_id=$PROV_TG_ID" \
        -d "text=$MSG_PROV" \
        -d "parse_mode=HTML" \
        -d "disable_web_page_preview=true" >/dev/null 2>&1 &
fi

wait
exit 0
