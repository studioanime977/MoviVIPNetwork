# -*- coding: utf-8 -*-
"""KleperNet Admin Bot v5 — Full operator integration with connection types + V2Ray support
Toda la configuracion (tokens, VPS, branding, Xray, limites) se carga desde config.py."""

import asyncio
import logging
import datetime
import string
import random
import json
import sys
import time as time_module
import subprocess
import re
import base64
import uuid as uuid_mod
from pathlib import Path

from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup, BotCommand
from telegram.ext import (
    Application, CommandHandler, CallbackQueryHandler,
    MessageHandler, ConversationHandler, ContextTypes, filters
)
from telegram.constants import ParseMode
from telegram.error import TelegramError

sys.path.insert(0, str(Path(__file__).parent))
from config import (
    DB_PATH, OPERATOR_PORTS,
    ADMIN_BOT_TOKEN, ADMIN_IDS, BRAND_NAME, MY_BRAND,
    VPS_HOST, VPS_USER, VPS_PASSWORD as VPS_PASS,
    VPS_SUBDOMAIN, CLOUDFLARE_DOMAIN,
    XRAY_VPS_IP, XRAY_VLESS_REALITY_PORT,
    XRAY_VLESS_REALITY_PUBKEY, XRAY_VLESS_REALITY_SHORTID,
    XRAY_VLESS_REALITY_SNI, MAX_DEVICES, MAX_DAYS_CREATE,
)
from database import (
    db, is_admin, get_admin_role, get_admin_brand,
    log_audit, log_debug
)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(f'/var/log/movivip_{BRAND_NAME}.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# =============================================================================
# CONSTANTS (VPS_SUBDOMAIN, XRAY_*, MAX_DEVICES vienen de config.py)
# =============================================================================

# =============================================================================
# ESTADOS (added K_CREATE_CONN_TYPE)
# =============================================================================
(K_MAIN, K_USERS_MENU, K_USER_DETAIL, K_CREATE_OP, K_CREATE_CONN_TYPE,
 K_CREATE_DAYS, K_CREATE_PROFILES, K_CREATE_PLAN, K_CREATE_CONFIRM,
 K_SEARCH, K_EXTEND, K_REDUCE, K_REALTIME, K_USER_CONFIG,
 K_EXTEND_DEVICES, K_CREATE_MODE, K_CREATE_USER, K_CREATE_PASS,
 K_CREATE_HWID) = range(19)

# =============================================================================
# OPERATOR CONFIGS — ELIMINADO DEL REPO PUBLICO
# Los datos de operadores (payloads, SNIs, hosts) son exclusivos del vendedor
# y NO se publican. El bot crea cuentas SSH directas y entrega la plantilla
# generica con los datos del VPS del cliente (ver plantilla-entrega-bot.txt).
# =============================================================================
OPERATORS = {}

# =============================================================================
# V2RAY LINK GENERATORS
# =============================================================================
def _get_xray_uuid(username):
    """Generate deterministic UUID for a user (uuid5-based)."""
    return str(uuid_mod.uuid5(uuid_mod.NAMESPACE_URL, f"{MY_BRAND}-{username}"))

def generate_vmess_link(uuid_val, domain, port=443, path="/vmess", remark="KleperNet", host=None, sni=None):
    """Generate vmess:// share link."""
    config = {
        "v": "2", "ps": remark, "add": domain, "port": str(port),
        "id": uuid_val, "aid": "0", "net": "ws", "type": "none",
        "host": host or domain, "path": path, "tls": "tls",
        "sni": sni or domain, "scy": "auto", "alpn": ""
    }
    return "vmess://" + base64.b64encode(json.dumps(config, separators=(",", ":")).encode()).decode()

def generate_vless_link(uuid_val, domain, port=443, path="/vless", remark="KleperNet", sni=None, host=None):
    """Generate vless:// share link."""
    params = (f"?type=ws&security=tls&sni={sni or domain}&path={path}"
              f"&host={host or domain}&encryption=none&flow=")
    return f"vless://{uuid_val}@{domain}:{port}{params}#{remark}"

def generate_trojan_link(password, domain, port=443, path="/trojan-ws", remark="KleperNet", sni=None, host=None):
    """Generate trojan:// share link."""
    params = (f"?type=ws&security=tls&sni={sni or domain}&path={path}"
              f"&host={host or domain}")
    return f"trojan://{password}@{domain}:{port}{params}#{remark}"

def generate_vless_reality_link(uuid_val, domain, port=9443, remark="KleperNet"):
    """Generate vless:// Reality share link."""
    params = (f"?security=reality&sni={XRAY_VLESS_REALITY_SNI}&fp=chrome"
              f"&pbk={XRAY_VLESS_REALITY_PUBKEY}&sid={XRAY_VLESS_REALITY_SHORTID}"
              f"&type=tcp&encryption=none")
    return f"vless://{uuid_val}@{domain}:{port}{params}#{remark}"

# =============================================================================
# SSH FUNCTIONS
# =============================================================================
import paramiko

def get_ssh_client():
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(VPS_HOST, port=22, username=VPS_USER, password=VPS_PASS, timeout=10)
    return ssh

def get_vps_stats():
    """Get real-time VPS stats: CPU, RAM, Disk, Uptime, Connections"""
    try:
        ssh = get_ssh_client()
        stdin, stdout, stderr = ssh.exec_command("top -bn1 | grep 'Cpu(s)' | awk '{print $2}'")
        cpu = stdout.read().decode().strip() or "N/A"
        stdin, stdout, stderr = ssh.exec_command("free -m | awk 'NR==2{printf \"%s/%sMB (%.1f%%)\", $3, $2, $3*100/$2}'")
        ram = stdout.read().decode().strip() or "N/A"
        stdin, stdout, stderr = ssh.exec_command("df -h / | awk 'NR==2{printf \"%s/%s (%s)\", $3, $2, $5}'")
        disk = stdout.read().decode().strip() or "N/A"
        stdin, stdout, stderr = ssh.exec_command("uptime -p")
        uptime = stdout.read().decode().strip() or "N/A"
        stdin, stdout, stderr = ssh.exec_command("cat /proc/loadavg | awk '{print $1, $2, $3}'")
        load = stdout.read().decode().strip() or "N/A"
        stdin, stdout, stderr = ssh.exec_command("cat /proc/net/dev | grep -E 'eth0|ens' | awk '{print $2, $10}' | head -1")
        net = stdout.read().decode().strip().split()
        net_in = f"{int(net[0])/(1024*1024):.1f}MB" if len(net) >= 1 and net[0].isdigit() else "N/A"
        net_out = f"{int(net[1])/(1024*1024):.1f}MB" if len(net) >= 2 and net[1].isdigit() else "N/A"
        stdin, stdout, stderr = ssh.exec_command(
            "ss -tnp state established '( dport = :80 or dport = :443 or dport = :7300 or dport = :9900 or dport = :22 )' | grep -v Local | wc -l")
        ssh_sessions = stdout.read().decode().strip() or "0"
        stdin, stdout, stderr = ssh.exec_command(
            "systemctl is-active movivip-klepernet movivip-vps-admin movivip-user python80 badvpn stunnel4 2>/dev/null | grep -c active")
        services_up = stdout.read().decode().strip() or "0"
        stdin, stdout, stderr = ssh.exec_command(
            "getent passwd | grep -cE '/home/(vip|ssh|v[0-9])'")
        vps_users = stdout.read().decode().strip() or "0"
        ssh.close()
        return {'cpu': cpu, 'ram': ram, 'disk': disk, 'uptime': uptime, 'load': load,
                'net_in': net_in, 'net_out': net_out, 'ssh_sessions': ssh_sessions,
                'services_up': services_up, 'vps_users': vps_users}
    except Exception as e:
        logger.error(f"Error getting VPS stats: {e}")
        return {'cpu': 'Error', 'ram': 'Error', 'disk': 'Error', 'uptime': 'Error', 'load': 'Error',
                'net_in': 'Error', 'net_out': 'Error', 'ssh_sessions': '0', 'services_up': '0', 'vps_users': '0'}

def get_active_connections(brand_users=None):
    """Get real-time SSH connections + persistent bandwidth from DB"""
    import re as _re
    try:
        ssh = get_ssh_client()
        stdin, stdout, stderr = ssh.exec_command("ps -eo args= --no-headers | grep 'sshd:' | grep -v root | grep -v listener")
        raw = stdout.read().decode('utf-8', errors='replace').strip().split('\n')
        connected_set = set()
        connected_sessions = {}
        for line in raw:
            line = line.strip()
            if not line or '[priv]' not in line:
                continue
            _m = _re.search(r'sshd:\s+(\S+)', line)
            if _m:
                uname = _m.group(1)
                if uname not in connected_sessions:
                    connected_sessions[uname] = 0
                connected_sessions[uname] += 1
                connected_set.add(uname)

        stdin, stdout, stderr = ssh.exec_command("iptables -L OUTPUT -v -n 2>/dev/null | grep 'UID match'")
        bw_lines = stdout.read().decode('utf-8', errors='replace').strip().split('\n')
        live_bytes = {}
        for line in bw_lines:
            match = _re.search(r'(\d+)\s+(\d+)\s+.*owner UID match (\d+)', line)
            if match:
                uid = int(match.group(3))
                try:
                    stdin2, stdout2, stderr2 = ssh.exec_command(f"getent passwd {uid} | cut -d: -f1")
                    uname = stdout2.read().decode('utf-8', errors='replace').strip()
                    if uname:
                        live_bytes[uname] = _parse_bytes(match.group(2))
                except:
                    pass
        ssh.close()

        import sqlite3
        _db = sqlite3.connect(DB_PATH)
        _db.execute("""CREATE TABLE IF NOT EXISTS bandwidth_usage (
            id INTEGER PRIMARY KEY AUTOINCREMENT, username TEXT NOT NULL UNIQUE,
            uid INTEGER, bytes_current INTEGER DEFAULT 0,
            bytes_accumulated INTEGER DEFAULT 0, prev_bytes INTEGER DEFAULT 0,
            last_connected INTEGER DEFAULT 0, updated_at TEXT)""")
        _db.commit()
        db_rows = _db.execute("SELECT username, bytes_accumulated, last_connected FROM bandwidth_usage").fetchall()
        db_map = {r[0]: {'accumulated': r[1], 'last_connected': r[2]} for r in db_rows}
        _db.close()

        ip_map = {}
        if connected_set:
            try:
                ssh2 = get_ssh_client()
                stdin3, stdout3, stderr3 = ssh2.exec_command(
                    "journalctl -u ssh --no-pager -n 500 2>/dev/null | "
                    "grep 'Accepted password' | "
                    "sed -E 's/.*Accepted password for ([^ ]+) from ([^ ]+) port.*/\\1 \\2/'")
                for line in stdout3.read().decode('utf-8', errors='replace').strip().split('\n'):
                    parts = line.strip().split(None, 1)
                    if len(parts) == 2 and parts[0] in connected_set and parts[0] not in ip_map:
                        ip_map[parts[0]] = parts[1]
                for user in connected_set - set(ip_map.keys()):
                    try:
                        stdin4, stdout4, stderr4 = ssh2.exec_command(
                            f"ss -tnp 2>/dev/null | grep 'sshd:{user}' | head -1 | awk '{{print $5}}'")
                        ip_raw = stdout4.read().decode('utf-8', errors='replace').strip()
                        ip_map[user] = ip_raw.rsplit(':', 1)[0] if ':' in ip_raw else 'N/A'
                    except:
                        ip_map[user] = 'N/A'
                for user in connected_set:
                    if user not in ip_map:
                        ip_map[user] = 'N/A'
                ssh2.close()
            except:
                ip_map = {u: 'N/A' for u in connected_set}

        all_users = connected_set.copy()
        for uname in db_map:
            all_users.add(uname)
        connections = []
        for username in all_users:
            if brand_users and username not in brand_users:
                continue
            is_connected = username in connected_set
            sessions = connected_sessions.get(username, 0)
            ip = ip_map.get(username, 'N/A')
            live = live_bytes.get(username, 0)
            db_info = db_map.get(username, {'accumulated': 0, 'last_connected': 0})
            accumulated = db_info['accumulated']
            total = accumulated + live if (is_connected and live > 0) else accumulated
            connections.append({
                'user': username, 'ip': ip, 'sessions': sessions,
                'bytes_total': total, 'bytes_live': live if is_connected else 0,
                'connected': is_connected, 'packets': 0,
            })
        return connections
    except Exception as e:
        logger.error(f"Error getting connections: {e}")
        return []

def _parse_bytes(s):
    try: return int(s)
    except: return 0

# =============================================================================
# FORMAT USER CONFIG — Full V2Ray + SSH support
# =============================================================================
def format_user_config(username, password, operator_code, days, profiles, expires, conn_type=None, hwid=None):
    """Format complete user config for display — cuenta SSH directa del VPS.
    Nota: los datos de operador (payloads/SNIs) se eliminaron del repo publico.
    El bot entrega la plantilla generica con los datos del VPS (plantilla-entrega-bot.txt)."""
    text = (
        f"╔══════════════════════════════╗\n"
        f"║  🌐 KLEPERNET NETWORK       ║\n"
        f"║  Config SSH                 ║\n"
        f"╚══════════════════════════════╝\n\n"
        f"👤 <b>USUARIO:</b> <code>{username}</code>\n"
        f"🔑 <b>PASS:</b> <code>{password}</code>\n"
    )
    if hwid:
        text += f"📱 <b>HWID:</b> <code>{hwid}</code>\n"
    text += (
        f"📅 <b>Expira:</b> {expires}\n"
        f"📱 <b>Perfiles:</b> {profiles}\n"
        f"⏰ <b>Días:</b> {days}\n\n"
        f"{'━' * 28}\n\n"
        f"🖥 <b>Servidor:</b> <code>{VPS_SUBDOMAIN}</code>\n"
        f"📡 <b>SSH Field:</b> <code>{VPS_SUBDOMAIN}@{username}:{password}</code>\n\n"
        f"👆 <i>Copia los campos para usar en tu app VPN</i>"
    )

    return text

# =============================================================================
# BRANDING
# =============================================================================
def brand_header():
    return (
        "🌐 <b>════════════════════════</b>\n"
        "   <b>KLEPERNET NETWORK</b>\n"
        "   Panel de Proveedor\n"
        "🌐 <b>════════════════════════</b>"
    )

def brand_divider():
    return "────────────────────────────"

# =============================================================================
# TECLADOS
# =============================================================================
COUNTRY_FLAGS = {'co': '🇨🇴', 'pe': '🇵🇪', 'ar': '🇦🇷', 'sv': '🇸🇻', 'in': '🇮🇳'}

def kb_main(role, brand):
    return InlineKeyboardMarkup([
        [InlineKeyboardButton("👥 Usuarios KLEPERNET", callback_data="k_users")],
        [InlineKeyboardButton("🟢 Usuarios Conectados", callback_data="k_realtime")],
        [InlineKeyboardButton("➕ Crear Cuenta SSH", callback_data="k_create")],
        [InlineKeyboardButton("📊 Estado VPS", callback_data="k_stats")],
        [InlineKeyboardButton("🔄 Refrescar", callback_data="k_refresh")],
    ])

def kb_user_list(rows, brand):
    buttons = []
    for r in rows:
        try:
            days = (datetime.date.fromisoformat(r['expires_at']) - datetime.date.today()).days
            icon = "✅" if days > 3 else "⚠️" if days > 0 else "❌"
        except:
            icon = "❓"
            days = "?"
        status = "🟢" if r['status'] == 'active' and icon != "❌" else "🔴"
        buttons.append([InlineKeyboardButton(
            f"{status} {r['username']} | {r['operator']} | {icon}{days}d",
            callback_data=f"k_detail_{r['username']}"
        )])
    buttons.append([InlineKeyboardButton("🔙 Volver", callback_data="k_users")])
    return InlineKeyboardMarkup(buttons)

def kb_users():
    return InlineKeyboardMarkup([
        [InlineKeyboardButton("📋 Todos", callback_data="k_users_all"),
         InlineKeyboardButton("✅ Activos", callback_data="k_users_active")],
        [InlineKeyboardButton("⏰ Por Expirar", callback_data="k_users_expiring"),
         InlineKeyboardButton("🔍 Buscar", callback_data="k_users_search")],
        [InlineKeyboardButton("🧹 Limpiar Expirados", callback_data="k_cleanup")],
        [InlineKeyboardButton("🔙 Volver", callback_data="k_back")],
    ])

def kb_user_detail(username):
    return InlineKeyboardMarkup([
        [InlineKeyboardButton("📋 Ver Config", callback_data=f"k_config_{username}")],
        [InlineKeyboardButton("⏰ Extender", callback_data=f"k_extend_{username}"),
         InlineKeyboardButton("📉 Reducir", callback_data=f"k_reduce_{username}")],
        [InlineKeyboardButton("📱 + Dispositivos", callback_data=f"k_devmenu_{username}"),
         InlineKeyboardButton("🗑 Eliminar", callback_data=f"k_delete_{username}")],
        [InlineKeyboardButton("🔙 Volver", callback_data="k_users")],
    ])

def kb_create_ops():
    """Group operators by country"""
    buttons = []
    # Group by country
    countries = {}
    for code, cfg in OPERATORS.items():
        cty = cfg.get('country', 'co')
        if cty not in countries:
            countries[cty] = []
        countries[cty].append((code, cfg))

    for cty in ['co', 'pe', 'in', 'ar', 'sv']:
        if cty not in countries:
            continue
        flag = COUNTRY_FLAGS.get(cty, '🌎')
        country_name = {'co': 'Colombia', 'pe': 'Perú', 'in': 'India', 'ar': 'Argentina', 'sv': 'El Salvador'}.get(cty, cty)
        buttons.append([InlineKeyboardButton(f"─── {flag} {country_name} ───", callback_data="knoop")])
        for code, cfg in countries[cty]:
            ct_count = len(cfg.get('connection_types', []))
            ct_text = f" ({ct_count} tipos)" if ct_count > 1 else ""
            buttons.append([InlineKeyboardButton(
                f"{cfg['flag']} {cfg['name']} {cfg['desc']}{ct_text}",
                callback_data=f"k_op_{code}"
            )])
    buttons.append([InlineKeyboardButton("🔙 Volver", callback_data="k_back")])
    return InlineKeyboardMarkup(buttons)

def kb_create_conn_types(operator_code):
    """Show connection types for selected operator"""
    op = OPERATORS.get(operator_code, {})
    buttons = []
    for ct in op.get('connection_types', []):
        proto_icon = "⚡" if ct.get('protocol') == 'v2ray' else "🔌" if ct.get('protocol') == 'slowdns' else "📦"
        buttons.append([InlineKeyboardButton(
            f"{proto_icon} {ct['label']}",
            callback_data=f"k_conn_{ct['key']}"
        )])
    buttons.append([InlineKeyboardButton("🔙 Volver", callback_data="k_create")])
    return InlineKeyboardMarkup(buttons)

def kb_create_days():
    return InlineKeyboardMarkup([
        [InlineKeyboardButton("1️⃣ 1 Día", callback_data="k_days_1"),
         InlineKeyboardButton("3️⃣ 3 Días", callback_data="k_days_3"),
         InlineKeyboardButton("7️⃣ 7 Días", callback_data="k_days_7")],
        [InlineKeyboardButton("1️⃣5️⃣ 15 Días", callback_data="k_days_15"),
         InlineKeyboardButton("3️⃣0️⃣ 30 Días", callback_data="k_days_30")],
        [InlineKeyboardButton("🔙 Volver", callback_data="k_back_op")],
    ])

def kb_create_profiles():
    return InlineKeyboardMarkup([
        [InlineKeyboardButton("1 Dispositivo", callback_data="k_prof_1"),
         InlineKeyboardButton("2 Dispositivos", callback_data="k_prof_2"),
         InlineKeyboardButton("3 Dispositivos", callback_data="k_prof_3")],
        [InlineKeyboardButton("5 Dispositivos", callback_data="k_prof_5"),
         InlineKeyboardButton("Ilimitado", callback_data="k_prof_999")],
        [InlineKeyboardButton("🔙 Volver", callback_data="k_back_conn")],
    ])

def kb_create_mode():
    return InlineKeyboardMarkup([
        [InlineKeyboardButton("\U0001f3b2 Autom\u00e1tico (user + pass generados)", callback_data="k_mode_auto")],
        [InlineKeyboardButton("\u270f\ufe0f Manual (elegir user y pass)", callback_data="k_mode_manual")],
        [InlineKeyboardButton("\U0001f512 Con HWID (atado al dispositivo)", callback_data="k_mode_hwid")],
        [InlineKeyboardButton("\U0001f519 Volver", callback_data="k_create")],
    ])

def kb_confirm():
    return InlineKeyboardMarkup([
        [InlineKeyboardButton("✅ CONFIRMAR CREACIÓN", callback_data="k_confirm")],
        [InlineKeyboardButton("❌ Cancelar", callback_data="k_back")],
    ])

def kb_extend(username):
    return InlineKeyboardMarkup([
        [InlineKeyboardButton("+1 Día", callback_data=f"k_ext1_{username}"),
         InlineKeyboardButton("+3 Días", callback_data=f"k_ext3_{username}"),
         InlineKeyboardButton("+7 Días", callback_data=f"k_ext7_{username}")],
        [InlineKeyboardButton("+15 Días", callback_data=f"k_ext15_{username}"),
         InlineKeyboardButton("+30 Días", callback_data=f"k_ext30_{username}")],
        [InlineKeyboardButton("🔙 Volver", callback_data=f"k_detail_{username}")],
    ])

def kb_reduce(username):
    return InlineKeyboardMarkup([
        [InlineKeyboardButton("-1 Día", callback_data=f"k_red1_{username}"),
         InlineKeyboardButton("-3 Días", callback_data=f"k_red3_{username}"),
         InlineKeyboardButton("-7 Días", callback_data=f"k_red7_{username}")],
        [InlineKeyboardButton("🔙 Volver", callback_data=f"k_detail_{username}")],
    ])

def kb_extend_devices(username):
    return InlineKeyboardMarkup([
        [InlineKeyboardButton("+1", callback_data=f"k_dev1_{username}"),
         InlineKeyboardButton("+2", callback_data=f"k_dev2_{username}"),
         InlineKeyboardButton("+3", callback_data=f"k_dev3_{username}")],
        [InlineKeyboardButton("+5", callback_data=f"k_dev5_{username}"),
         InlineKeyboardButton("+10", callback_data=f"k_dev10_{username}")],
        [InlineKeyboardButton("🔙 Volver", callback_data=f"k_detail_{username}")],
    ])

# =============================================================================
# START
# =============================================================================
async def cmd_start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    user = update.effective_user
    user_id = user.id
    if user_id not in ADMIN_IDS and not is_admin(user_id):
        await update.message.reply_text("❌ Sin permisos de acceso.")
        return K_MAIN
    role = get_admin_role(user_id)
    brand = get_admin_brand(user_id)
    text = f"""{brand_header()}

👤 <b>Proveedor:</b> {user.first_name} (@{user.username or 'N/A'})
🏷️ <b>Rol:</b> {role.upper()}
📡 <b>Marca:</b> {brand.upper()}

{brand_divider()}

⚡ Selecciona una opción:"""
    if update.message:
        await update.message.reply_text(text, parse_mode=ParseMode.HTML, reply_markup=kb_main(role, brand))
    else:
        await update.callback_query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=kb_main(role, brand))
    return K_MAIN

# =============================================================================
# HANDLER PRINCIPAL
# =============================================================================
async def button_handler(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    data = query.data
    user_id = query.from_user.id
    await query.answer()

    if user_id not in ADMIN_IDS and not is_admin(user_id):
        await query.answer("❌ Sin permisos", show_alert=True)
        return K_MAIN

    role = get_admin_role(user_id)
    brand = get_admin_brand(user_id)

    if data in ("k_back", "k_refresh"):
        return await cmd_start(update, context)

    # === USUARIOS ===
    elif data == "k_users":
        return await show_users_menu(update, context)
    elif data == "k_users_all":
        return await list_users(update, context, "all")
    elif data == "k_users_active":
        return await list_users(update, context, "active")
    elif data == "k_users_expiring":
        return await list_users(update, context, "expiring")
    elif data == "k_users_search":
        context.user_data["search_mode"] = True
        await query.edit_message_text(
            "🔍 <b>Buscar Usuario</b>\n" + brand_divider() + "\n\nEscribe el username o Telegram ID:",
            parse_mode=ParseMode.HTML,
            reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("🔙 Cancelar", callback_data="k_users")]])
        )
        return K_SEARCH
    elif data == "k_cleanup":
        return await cleanup_expired(update, context)
    elif data.startswith("k_detail_"):
        return await show_user_detail(update, context, data[9:])
    elif data.startswith("k_config_"):
        return await show_user_config(update, context, data[9:])
    elif data.startswith("k_extend_"):
        return await show_extend(update, context, data[9:])
    elif data.startswith("k_reduce_"):
        return await show_reduce(update, context, data[9:])
    elif data.startswith("k_ext"):
        rest = data[5:]
        sep = rest.index("_")
        return await do_extend(update, context, rest[sep+1:], int(rest[:sep]))
    elif data.startswith("k_red"):
        rest = data[5:]
        sep = rest.index("_")
        return await do_reduce(update, context, rest[sep+1:], int(rest[:sep]))
    elif data.startswith("k_delete_"):
        return await do_delete(update, context, data[9:])
    elif data.startswith("k_devmenu_"):
        return await show_extend_devices(update, context, data[10:])
    elif data.startswith("k_dev"):
        rest = data[5:]
        sep = rest.index("_")
        return await do_extend_devices(update, context, rest[sep+1:], int(rest[:sep]))

    # === REALTIME ===
    elif data == "k_realtime":
        return await show_realtime(update, context)

    # === CREAR CUENTA — FLOW: Operator → ConnType → Days → Profiles → Mode → Confirm ===
    elif data == "k_create":
        return await show_create_menu(update, context)
    elif data.startswith("k_op_"):
        context.user_data["op"] = data[5:]
        return await show_conn_types(update, context)
    elif data == "k_back_op":
        return await show_create_menu(update, context)
    elif data.startswith("k_conn_"):
        context.user_data["conn_type"] = data[6:]
        return await show_operator_config(update, context)
    elif data == "k_back_conn":
        return await show_conn_types(update, context)
    elif data.startswith("k_days_"):
        context.user_data["days"] = int(data[7:])
        return await show_profiles(update, context)
    elif data.startswith("k_prof_"):
        context.user_data["profiles"] = int(data[7:])
        context.user_data["plan_type"] = "premium"
        return await show_create_mode(update, context)
    elif data == "k_mode_auto":
        context.user_data["cred_mode"] = "auto"
        return await show_confirm(update, context)
    elif data == "k_mode_manual":
        context.user_data["cred_mode"] = "manual"
        return await ask_manual_username(update, context)
    elif data == "k_mode_hwid":
        context.user_data["cred_mode"] = "hwid"
        return await ask_hwid(update, context)
    elif data == "k_confirm":
        return await do_create(update, context)

    # === STATS ===
    elif data == "k_stats":
        return await show_stats(update, context)

    return K_MAIN

# =============================================================================
# USUARIOS - MENU
# =============================================================================
async def show_users_menu(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    user_id = query.from_user.id
    brand = get_admin_brand(user_id)
    stats = db.fetchone("""
        SELECT
            COUNT(*) as total,
            SUM(CASE WHEN status='active' AND expires_at >= date('now') THEN 1 ELSE 0 END) as active,
            SUM(CASE WHEN status='expired' OR expires_at < date('now') THEN 1 ELSE 0 END) as expired,
            SUM(CASE WHEN expires_at BETWEEN date('now') AND date('now', '+3 days') AND status='active' THEN 1 ELSE 0 END) as expiring
        FROM system_users WHERE brand=?
    """, (brand,))
    text = f"""🌐 <b>USUARIOS KLEPERNET</b>
{brand_divider()}

┌────────────────────────────┐
│ 📊 Resumen de la marca    │
├────────────────────────────┤
│ 👥 Total: <b>{stats['total'] or 0}</b>
│ ✅ Activos: <b>{stats['active'] or 0}</b>
│ ❌ Expirados: <b>{stats['expired'] or 0}</b>
│ ⏰ Por expirar (3d): <b>{stats['expiring'] or 0}</b>
└────────────────────────────┘

⚡ Selecciona una opción:"""
    await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=kb_users())
    return K_USERS_MENU

# =============================================================================
# USUARIOS - LISTAR
# =============================================================================
async def list_users(update: Update, context: ContextTypes.DEFAULT_TYPE, filter_type: str) -> int:
    query = update.callback_query
    user_id = query.from_user.id
    brand = get_admin_brand(user_id)
    if filter_type == "all":
        rows = db.fetchall("SELECT * FROM system_users WHERE brand=? ORDER BY created_at DESC LIMIT 30", (brand,))
        title = "TODOS"
    elif filter_type == "active":
        rows = db.fetchall("SELECT * FROM system_users WHERE brand=? AND status='active' AND expires_at >= date('now') ORDER BY expires_at DESC LIMIT 30", (brand,))
        title = "ACTIVOS"
    else:
        rows = db.fetchall("SELECT * FROM system_users WHERE brand=? AND status='active' AND expires_at BETWEEN date('now') AND date('now', '+3 days') ORDER BY expires_at ASC LIMIT 30", (brand,))
        title = "POR EXPIRAR"

    text = f"🌐 <b>USUARIOS KLEPERNET ({title})</b>\n{brand_divider()}\n\n"
    if not rows:
        text += "📭 Sin usuarios registrados.\n"
        await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=kb_users())
    else:
        text += "Selecciona un usuario para ver detalle:\n"
        await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=kb_user_list(rows, brand))
    return K_USERS_MENU

# =============================================================================
# USUARIOS - DETALLE
# =============================================================================
async def show_user_detail(update: Update, context: ContextTypes.DEFAULT_TYPE, username: str) -> int:
    query = update.callback_query
    brand = get_admin_brand(query.from_user.id)
    row = db.fetchone("SELECT * FROM system_users WHERE username=?", (username,))
    if not row:
        await query.edit_message_text("❌ Usuario no encontrado.", reply_markup=kb_users())
        return K_USERS_MENU

    try:
        days = (datetime.date.fromisoformat(row['expires_at']) - datetime.date.today()).days
        days_icon = "✅" if days > 3 else "⚠️" if days > 0 else "❌"
    except:
        days = "?"
        days_icon = "❓"

    status = "🟢 ACTIVO" if row['status'] == 'active' and days_icon != "❌" else "🔴 EXPIRADO"
    trial_val = row['trial'] if 'trial' in row.keys() else 0
    trial = "\U0001f381 SI" if trial_val else "NO"

    op = row['operator']
    op_cfg = OPERATORS.get(op, {})
    op_flag = op_cfg.get('flag', '')
    conn_type = row['conn_type'] if 'conn_type' in row.keys() else None
    conn_label = ""
    if conn_type:
        for ct in op_cfg.get('connection_types', []):
            if ct['key'] == conn_type:
                conn_label = ct['label']
                break

    text = f"""🌐 <b>DETALLE - KLEPERNET</b>
{brand_divider()}

┌────────────────────────────┐
│ 👤 <b>Usuario:</b> <code>{row['username']}</code>
│ 🔑 <b>Password:</b> <code>{row['password']}</code>
├────────────────────────────┤
│ 📡 <b>Operador:</b> {op_flag} {row['operator']}
"""
    if conn_label:
        text += f"│ 🔗 <b>Tipo:</b> {conn_label}\n"
    hwid_val = row['hwid'] if 'hwid' in row.keys() else None
    if hwid_val:
        text += f"│ 📱 <b>HWID:</b> <code>{hwid_val}</code>\n"
    text += f"""│ 📊 <b>Estado:</b> {status}
│ 📅 <b>Expira:</b> {row['expires_at']}
│ ⏰ <b>Días restantes:</b> {days_icon} {days}
│ 👤 <b>Dispositivos:</b> {row['max_logins']}
│ 🎁 <b>Trial:</b> {trial}
├────────────────────────────┤
│ 🏷️ <b>Marca:</b> {brand.upper()}
│ 📝 <b>Creado:</b> {row['created_at'] if 'created_at' in row.keys() else 'N/A'}
└────────────────────────────┘

⚡ Selecciona acción:"""
    await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=kb_user_detail(username))
    return K_USER_DETAIL

# =============================================================================
# USUARIOS - CONFIG SSH
# =============================================================================
async def show_user_config(update: Update, context: ContextTypes.DEFAULT_TYPE, username: str) -> int:
    query = update.callback_query
    row = db.fetchone("SELECT * FROM system_users WHERE username=?", (username,))
    if not row:
        await query.edit_message_text("❌ Usuario no encontrado.", reply_markup=kb_users())
        return K_USERS_MENU

    conn_type = row['conn_type'] if 'conn_type' in row.keys() else None
    hwid_val = row['hwid'] if 'hwid' in row.keys() else None
    config_text = format_user_config(
        row['username'], row['password'], row['operator'],
        "N/A", row['max_logins'], row['expires_at'], conn_type=conn_type, hwid=hwid_val
    )
    await query.edit_message_text(config_text, parse_mode=ParseMode.HTML, reply_markup=kb_user_detail(username))
    return K_USER_CONFIG

# =============================================================================
# USUARIOS EN TIEMPO REAL
# =============================================================================
async def show_realtime(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    user_id = query.from_user.id
    brand = get_admin_brand(user_id)

    await query.edit_message_text(
        "🟢 <b>Buscando usuarios conectados...</b>\n" + brand_divider() + "\n⏳ Consultando servidor VPS...",
        parse_mode=ParseMode.HTML
    )

    all_brand_users = db.fetchall(
        "SELECT username, password, operator, expires_at, max_logins, status FROM system_users WHERE brand=?",
        (brand,)
    )
    db_usernames = {r['username']: r for r in all_brand_users}
    brand_user_list = [r['username'] for r in all_brand_users if r['status'] == 'active']
    connected = get_active_connections(brand_users=brand_user_list)
    connected_set = {c['user'] for c in connected}
    connected_map = {c['user']: c for c in connected}

    brand_connected = []
    for r in all_brand_users:
        username = r['username']
        is_connected = username in connected_set
        conn_info = connected_map.get(username, {})
        try:
            days = (datetime.date.fromisoformat(r['expires_at']) - datetime.date.today()).days
        except:
            days = 0
        status_icon = "🟢" if is_connected else "⚪"
        brand_connected.append({
            'user': username, 'password': r['password'], 'operator': r['operator'],
            'ip': conn_info.get('ip', '--'), 'connected': is_connected,
            'status_icon': status_icon, 'max_logins': r['max_logins'], 'days': days,
            'expires': r['expires_at'], 'sessions': conn_info.get('sessions', 0),
            'bytes_total': conn_info.get('bytes_total', 0),
            'is_connected': conn_info.get('connected', False),
        })

    def _fmt_bytes(b):
        if b >= 1073741824: return f"{b/1073741824:.2f} GB"
        elif b >= 1048576: return f"{b/1048576:.1f} MB"
        elif b >= 1024: return f"{b/1024:.1f} KB"
        return f"{b} B"

    text = "🟢 <b>USUARIOS EN TIEMPO REAL</b>\n" + brand_divider()
    if not brand_connected:
        text += "\n📭 No hay usuarios registrados."
    else:
        for conn in brand_connected:
            icon = conn['status_icon']
            user = conn['user']
            op = conn['operator']
            bw = _fmt_bytes(conn['bytes_total'])
            is_on = conn.get('is_connected', False)
            sessions = conn.get('sessions', 0)
            if is_on:
                text += f"\n{icon} <b>{user}</b>"
                text += f"\n   📍 {op} | {sessions} sesion(es)"
                text += f"\n   📦 Consumo: {bw} (acumulado)"
                text += f"\n   ⏱ {conn['days']}d restantes"
            else:
                days_str = f"{conn['days']}d" if conn['days'] > 0 else "VENCIDO"
                bw_extra = f" | {bw}" if conn['bytes_total'] > 0 else ""
                text += f"\n{icon} <code>{user}</code> | {op} | {days_str}{bw_extra}"

    text += f"\n\n{brand_divider()}"
    active_count = sum(1 for c in brand_connected if c.get('is_connected', False))
    total_bw = sum(c['bytes_total'] for c in brand_connected)
    text += f"\n🎯 CONECTADOS: {active_count}/{len(brand_connected)}"
    text += f" | 📦 Total: {_fmt_bytes(total_bw)}"

    kb = InlineKeyboardMarkup([
        [InlineKeyboardButton("🔄 Actualizar", callback_data="k_realtime")],
        [InlineKeyboardButton("🔙 Volver", callback_data="k_back")],
    ])
    await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=kb)
    return K_REALTIME

# =============================================================================
# CREAR CUENTA — STEP 1: Select Operator
# =============================================================================
async def show_create_menu(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    text = f"""🌐 <b>CREAR CUENTA - KLEPERNET</b>
{brand_divider()}

📡 Selecciona el operador:"""
    await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=kb_create_ops())
    return K_CREATE_OP

# =============================================================================
# CREAR CUENTA — STEP 2: Select Connection Type
# =============================================================================
async def show_conn_types(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    op_code = context.user_data["op"]
    op = OPERATORS.get(op_code, {})
    ct_list = op.get('connection_types', [])

    # If only 1 connection type, skip selection
    if len(ct_list) == 1:
        context.user_data["conn_type"] = ct_list[0]['key']
        return await show_operator_config(update, context)

    text = f"""🌐 <b>TIPO DE CONEXIÓN — {op.get('flag', '')} {op.get('name', op_code)}</b>
{brand_divider()}

📡 Selecciona el tipo de conexión:"""
    await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=kb_create_conn_types(op_code))
    return K_CREATE_CONN_TYPE

# =============================================================================
# CREAR CUENTA — STEP 3: Show operator config info
# =============================================================================
async def show_operator_config(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    op_code = context.user_data["op"]
    conn_type = context.user_data.get("conn_type")
    op = OPERATORS.get(op_code, {})

    # Find connection type config
    ct_config = None
    if conn_type:
        for ct in op.get('connection_types', []):
            if ct['key'] == conn_type:
                ct_config = ct
                break

    text = f"""🌐 <b>CONFIG — {op.get('flag', '')} {op.get('name', op_code)}</b>
{brand_divider()}

┌────────────────────────────┐
│ 📡 <b>Operador:</b> {op.get('name', op_code)}
│ 🏳️ <b>País:</b> {op.get('flag', '')} {op.get('country', 'co').upper()}
"""
    if ct_config:
        text += f"│ 🔗 <b>Tipo:</b> {ct_config.get('label', 'N/A')}\n"
        text += f"│ 🌐 <b>Puerto:</b> {ct_config.get('port', 'N/A')}\n"
        text += f"│ ⚙️ <b>Protocolo:</b> {ct_config.get('protocol', 'N/A')}\n"
        if ct_config.get('snis'):
            text += f"│ 🔒 <b>SNI:</b> {', '.join(ct_config['snis'])}\n"
        if ct_config.get('ssh_field'):
            text += f"│ 📡 <b>SSH Field:</b> <code>{ct_config['ssh_field']}</code>\n"
        if ct_config.get('v2ray_host'):
            text += f"│ 🌐 <b>V2Ray Host:</b> <code>{ct_config['v2ray_host']}</code>\n"
    else:
        text += f"│ ⚙️ <b>Protocolo:</b> {op.get('protocol', 'N/A')}\n"

    text += f"""└────────────────────────────┘

{brand_divider()}
⏰ Selecciona días de vigencia:"""

    await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=kb_create_days())
    return K_CREATE_DAYS

# =============================================================================
# CREAR CUENTA — STEP 4: Select Profiles
# =============================================================================
async def show_profiles(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    op_code = context.user_data["op"]
    days = context.user_data["days"]
    op = OPERATORS.get(op_code, {})
    conn_type = context.user_data.get("conn_type", "")
    ct_label = ""
    for ct in op.get('connection_types', []):
        if ct['key'] == conn_type:
            ct_label = ct.get('label', '')
            break

    text = f"""🌐 <b>CREAR CUENTA - KLEPERNET</b>
{brand_divider()}

📡 Operador: <b>{op.get('flag', '')} {op.get('name', op_code)}</b>
🔗 Tipo: <b>{ct_label or 'N/A'}</b>
⏰ Días: <b>{days}</b>
🏷️ Marca: <b>{BRAND_NAME.upper()}</b>

👤 Selecciona dispositivos (perfiles):"""
    await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=kb_create_profiles())
    return K_CREATE_PROFILES

# =============================================================================
# CREAR CUENTA — STEP 5: Credential Mode
# =============================================================================
async def show_create_mode(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    op_code = context.user_data["op"]
    days = context.user_data["days"]
    profiles = context.user_data["profiles"]
    op = OPERATORS.get(op_code, {})
    prof_text = str(profiles) if profiles < 999 else "Ilimitado"

    text = (
        "🌐 <b>CREAR CUENTA SSH - KLEPERNET</b>\n"
        + brand_divider() + "\n\n"
        f"📡 Operador: <b>{op.get('flag', '')} {op.get('name', op_code)}</b>\n"
        f"⏰ Días: <b>{days}</b>\n"
        f"👤 Dispositivos: <b>{prof_text}</b>\n\n"
        "🔑 <b>Como deseas generar las credenciales?</b>"
    )
    await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=kb_create_mode())
    return K_CREATE_MODE

async def ask_manual_username(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    text = (
        "🌐 <b>CREAR CUENTA - USUARIO MANUAL</b>\n"
        + brand_divider() + "\n\n"
        "👤 <b>Escribe el nombre de usuario</b> que deseas asignar:\n\n"
        "📝 Ejemplo: <code>juan_01</code>, <code>cliente23</code>, <code>karla_tigo</code>\n\n"
        "⚠️ Sin espacios, solo letras, numeros y guion bajo"
    )
    await query.edit_message_text(text, parse_mode=ParseMode.HTML)
    return K_CREATE_USER

async def ask_manual_password(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    username = update.message.text.strip().replace(" ", "")
    if not re.match(r'^[a-zA-Z0-9_-]+$', username) or len(username) < 3:
        await update.message.reply_text(
            "❌ <b>Usuario invalido</b>\n\nMinimo 3 caracteres, sin espacios.\nSolo: letras, numeros, guion bajo, guion.\n\nIntenta de nuevo:",
            parse_mode=ParseMode.HTML)
        return K_CREATE_USER
    existing = db.fetchone("SELECT username FROM system_users WHERE username=?", (username,))
    if existing:
        await update.message.reply_text(
            f"❌ <b>El usuario '{username}' ya existe</b>\n\nEscribe otro nombre de usuario:",
            parse_mode=ParseMode.HTML)
        return K_CREATE_USER
    context.user_data["manual_username"] = username
    text = (
        "🌐 <b>CREAR CUENTA - PASSWORD MANUAL</b>\n"
        + brand_divider() + "\n\n"
        f"👤 Usuario: <b>{username}</b>\n\n"
        "🔑 <b>Escribe la contrasena</b> que deseas asignar:\n\n"
        "📝 Ejemplo: <code>MiClave123</code>, <code>juan2026</code>, <code>KleperNet$$</code>\n\n"
        "⚠️ Minimo 6 caracteres"
    )
    await update.message.reply_text(text, parse_mode=ParseMode.HTML)
    return K_CREATE_PASS

async def confirm_manual_creds(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    password = update.message.text.strip()
    if len(password) < 6:
        await update.message.reply_text("❌ <b>Contrasena muy corta</b> (minimo 6 caracteres)\n\nEscribe una contrasena mas larga:", parse_mode=ParseMode.HTML)
        return K_CREATE_PASS
    context.user_data["manual_password"] = password
    username = context.user_data["manual_username"]
    return await _show_confirm_from_message(update, context, username, password)

async def ask_hwid(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    text = (
        "🔐 <b>CREAR CUENTA - CON HWID</b>\n"
        + brand_divider() + "\n\n"
        "📱 <b>Pega el HWID del dispositivo</b> del cliente (HTTP Custom).\n\n"
        "🔎 El cliente lo obtiene en la app:\n"
        "HTTP Custom → Ajustes → HWID / ID del dispositivo\n\n"
        "📝 Ejemplo: <code>a1b2c3d4e5f60718</code>\n\n"
        "⚠️ La cuenta quedara asociada a ese dispositivo.\n"
        "💡 Para cancelar: /cancelar"
    )
    await query.edit_message_text(text, parse_mode=ParseMode.HTML)
    return K_CREATE_HWID

async def confirm_hwid(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    hwid = update.message.text.strip()
    if not re.match(r'^[A-Za-z0-9_:.-]+$', hwid) or len(hwid) < 4 or len(hwid) > 64:
        await update.message.reply_text(
            "❌ <b>HWID invalido</b>\n\n"
            "Minimo 4 caracteres, maximo 64.\n"
            "Solo letras, numeros, guion bajo, dos puntos, punto y guion.\n\n"
            "Intenta de nuevo:",
            parse_mode=ParseMode.HTML)
        return K_CREATE_HWID
    context.user_data["hwid"] = hwid
    return await _show_confirm_from_hwid(update, context, hwid)

async def _show_confirm_from_hwid(update: Update, context: ContextTypes.DEFAULT_TYPE, hwid: str) -> int:
    op_code = context.user_data["op"]
    days = context.user_data["days"]
    profiles = context.user_data["profiles"]
    conn_type = context.user_data.get("conn_type", "")
    op = OPERATORS.get(op_code, {})
    prof_text = str(profiles) if profiles < 999 else "Ilimitado"
    ct_label = ""
    for ct in op.get('connection_types', []):
        if ct['key'] == conn_type:
            ct_label = ct.get('label', '')
            break

    text = (
        "🌐 <b>CONFIRMAR CREACION - KLEPERNET</b>\n"
        + brand_divider() + "\n\n"
        "┌────────────────────────────┐\n"
        "│ 🎯 Modo: <b>CON HWID</b>\n"
        f"│ 📱 HWID: <code>{hwid}</code>\n"
        f"│ 📡 Operador: <b>{op.get('flag', '')} {op.get('name', op_code)}</b>\n"
        f"│ 🔗 Tipo: <b>{ct_label or 'N/A'}</b>\n"
        f"│ ⏰ Dias: <b>{days}</b>\n"
        f"│ 👤 Dispositivos: <b>{prof_text}</b>\n"
        f"│ 🏷️ Marca: <b>{BRAND_NAME.upper()}</b>\n"
        "└────────────────────────────┘\n\n"
        "⚠️ Se creara la cuenta en el servidor VPS.\n\n"
        "⚡ Confirma la creacion:"
    )
    await update.message.reply_text(text, parse_mode=ParseMode.HTML, reply_markup=kb_confirm())
    return K_CREATE_CONFIRM

async def _show_confirm_from_message(update, context, username, password):
    op_code = context.user_data["op"]
    days = context.user_data["days"]
    profiles = context.user_data["profiles"]
    conn_type = context.user_data.get("conn_type", "")
    op = OPERATORS.get(op_code, {})
    prof_text = str(profiles) if profiles < 999 else "Ilimitado"
    ct_label = ""
    for ct in op.get('connection_types', []):
        if ct['key'] == conn_type:
            ct_label = ct.get('label', '')
            break

    text = (
        "🌐 <b>CONFIRMAR CREACION - KLEPERNET</b>\n"
        + brand_divider() + "\n\n"
        "┌────────────────────────────┐\n"
        f"│ 👤 Usuario: <b>{username}</b>\n"
        f"│ 🔑 Contrasena: <b>{password}</b>\n"
        "│ 🎯 Modo: <b>MANUAL</b>\n"
        f"│ 📡 Operador: <b>{op.get('flag', '')} {op.get('name', op_code)}</b>\n"
        f"│ 🔗 Tipo: <b>{ct_label or 'N/A'}</b>\n"
        f"│ ⏰ Dias: <b>{days}</b>\n"
        f"│ 👤 Dispositivos: <b>{prof_text}</b>\n"
        f"│ 🏷️ Marca: <b>{BRAND_NAME.upper()}</b>\n"
        "└────────────────────────────┘\n\n"
        "⚠️ Se creara la cuenta en el servidor VPS.\n\n"
        "⚡ Confirma la creacion:"
    )
    await update.message.reply_text(text, parse_mode=ParseMode.HTML, reply_markup=kb_confirm())
    return K_CREATE_CONFIRM

# =============================================================================
# CREAR CUENTA — STEP 6: Confirm
# =============================================================================
async def show_confirm(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    op_code = context.user_data.get("op", "unknown")
    days = context.user_data["days"]
    profiles = context.user_data["profiles"]
    conn_type = context.user_data.get("conn_type", "")
    op = OPERATORS.get(op_code, {})
    prof_text = str(profiles) if profiles < 999 else "Ilimitado"
    ct_label = ""
    for ct in op.get('connection_types', []):
        if ct['key'] == conn_type:
            ct_label = ct.get('label', '')
            break

    cred_mode = context.user_data.get("cred_mode", "auto")
    if cred_mode == "manual":
        cred_user = context.user_data.get("manual_username", "N/A")
        cred_pass = context.user_data.get("manual_password", "N/A")
        cred_info = f"| 👤 Usuario: <b>{cred_user}</b>\n| 🔑 Contrasena: <b>{cred_pass}</b>\n| 🎯 Modo: <b>MANUAL</b>\n|"
    else:
        cred_info = "| 🎯 Modo: <b>AUTOMATICO</b>\n|"

    text = f"""🌐 <b>CONFIRMAR CREACION - KLEPERNET</b>
{brand_divider()}

┌────────────────────────────┐
{cred_info}
| 📡 Operador: <b>{op.get('flag', '')} {op.get('name', op_code)}</b>
| 🔗 Tipo: <b>{ct_label or 'N/A'}</b>
| ⏰ Dias: <b>{days}</b>
| 👤 Dispositivos: <b>{prof_text}</b>
| 🏷️ Marca: <b>{BRAND_NAME.upper()}</b>
└────────────────────────────┘

⚠️ Se creara la cuenta en el servidor VPS.

⚡ Confirma la creacion:"""
    await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=kb_confirm())
    return K_CREATE_CONFIRM

# =============================================================================
# CREAR CUENTA — EXECUTE
# =============================================================================
async def do_create(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    admin_id = query.from_user.id
    op_code = context.user_data["op"]
    days = context.user_data["days"]
    profiles = context.user_data["profiles"]
    conn_type = context.user_data.get("conn_type")
    custom_user = context.user_data.get("manual_username")
    custom_pass = context.user_data.get("manual_password")
    hwid = context.user_data.get("hwid")

    await query.edit_message_text(
        "🌐 <b>CREANDO CUENTA SSH...</b>\n" + brand_divider() + "\n⏳ Procesando en el servidor VPS...",
        parse_mode=ParseMode.HTML
    )

    try:
        from ssh_utils import create_ssh_account
        plan_type = context.user_data.get('plan_type', 'free')
        result = await create_ssh_account(admin_id, op_code, days, profiles, brand=BRAND_NAME, plan_type=plan_type, custom_username=custom_user, custom_password=custom_pass, hwid=hwid)
    except Exception as e:
        result = {"success": False, "error": str(e)}

    if result.get("success"):
        # Store conn_type in DB if column exists
        if conn_type:
            try:
                db.execute("UPDATE system_users SET conn_type=? WHERE username=?", (conn_type, result['username']))
                db.commit()
            except:
                pass

        # Update port in DB to match selected connection type
        op = OPERATORS.get(op_code, {})
        ct_config = None
        if conn_type:
            for ct in op.get('connection_types', []):
                if ct['key'] == conn_type:
                    ct_config = ct
                    break
        if ct_config and ct_config.get('port'):
            try:
                db.execute("UPDATE system_users SET port=? WHERE username=?", (ct_config['port'], result['username']))
                db.commit()
            except:
                pass

        config_text = format_user_config(
            result['username'], result['password'], op_code,
            result['days'], result['max_logins'], result['expires_at'],
            conn_type=conn_type, hwid=hwid
        )
        log_audit(admin_id, "klepernet_create", f"user={result['username']} op={op_code} days={days} conn={conn_type}")

        kb = InlineKeyboardMarkup([
            [InlineKeyboardButton("✅ Crear Otra", callback_data="k_create")],
            [InlineKeyboardButton("👥 Ver Usuarios", callback_data="k_users")],
            [InlineKeyboardButton("🏠 Menú Principal", callback_data="k_back")],
        ])

        # Regenerate HTML banners
        try:
            import subprocess as _sp
            _sp.run("python3 /root/movivip_bots/gen_banners.py", shell=True, capture_output=True, timeout=30)
        except:
            pass

        await query.edit_message_text(
            f"✅ <b>CUENTA CREADA EXITOSAMENTE</b>\n{brand_divider()}\n\n{config_text}",
            parse_mode=ParseMode.HTML, reply_markup=kb
        )
    else:
        text = f"""❌ <b>ERROR AL CREAR CUENTA</b>
{brand_divider()}

Detalle: <code>{result.get('error', 'Desconocido')}</code>"""
        await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=kb_main(get_admin_role(admin_id), BRAND_NAME))

    return K_MAIN

# =============================================================================
# EXTENDER / REDUCIR / ELIMINAR
# =============================================================================
async def show_extend(update: Update, context: ContextTypes.DEFAULT_TYPE, username: str) -> int:
    query = update.callback_query
    row = db.fetchone("SELECT * FROM system_users WHERE username=?", (username,))
    if not row:
        await query.edit_message_text("❌ No encontrado.", reply_markup=kb_users())
        return K_USERS_MENU
    text = f"""🌐 <b>EXTENDER - {username}</b>
{brand_divider()}

📅 Expira actualmente: <b>{row['expires_at']}</b>

⏰ Cuantos días quieres agregar?"""
    await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=kb_extend(username))
    return K_EXTEND

async def do_extend(update: Update, context: ContextTypes.DEFAULT_TYPE, username: str, days: int) -> int:
    query = update.callback_query
    try:
        import sqlite3 as _s3
        _db = _s3.connect(DB_PATH)
        _db.row_factory = _s3.Row
        row = _db.execute("SELECT * FROM system_users WHERE username=?", (username,)).fetchone()
        if not row:
            _db.close()
            await query.edit_message_text("❌ No encontrado.", reply_markup=kb_users())
            return K_USERS_MENU
        old_exp = row['expires_at']
        try:
            new_expire = datetime.date.fromisoformat(old_exp) + datetime.timedelta(days=days)
        except:
            new_expire = datetime.date.today() + datetime.timedelta(days=days)
        _db.execute("UPDATE system_users SET expires_at=?, status='active' WHERE username=?", (str(new_expire), username))
        _db.commit()
        _db.close()
    except Exception as e:
        logging.error(f"[do_extend] ERROR: {e}")
    try:
        import subprocess as _sp
        _sp.run(f"usermod -e {new_expire} {username}", shell=True, capture_output=True, timeout=10)
    except Exception as e2:
        logging.error(f"[do_extend] VPS usermod error: {e2}")
    text = f"✅ <b>EXTENSI\u00d3N APLICADA</b>\n{brand_divider()}\n\n👤 Usuario: <code>{username}</code>\n⏰ D\u00edas agregados: <b>+{days}</b>\n📅 Nueva expiraci\u00f3n: <b>{new_expire}</b>"
    await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=kb_user_detail(username))
    log_audit(query.from_user.id, "klepernet_extend", f"user={username} +{days}d")
    return K_USER_DETAIL

async def show_reduce(update: Update, context: ContextTypes.DEFAULT_TYPE, username: str) -> int:
    query = update.callback_query
    row = db.fetchone("SELECT * FROM system_users WHERE username=?", (username,))
    if not row:
        await query.edit_message_text("❌ No encontrado.", reply_markup=kb_users())
        return K_USERS_MENU
    text = f"""🌐 <b>REDUCIR - {username}</b>
{brand_divider()}

📅 Expira actualmente: <b>{row['expires_at']}</b>

⏰ Cuantos días quieres quitar?"""
    await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=kb_reduce(username))
    return K_REDUCE

async def show_extend_devices(update: Update, context: ContextTypes.DEFAULT_TYPE, username: str) -> int:
    query = update.callback_query
    row = db.fetchone("SELECT * FROM system_users WHERE username=?", (username,))
    if not row:
        await query.edit_message_text("❌ No encontrado.", reply_markup=kb_users())
        return K_USERS_MENU
    current = row['max_logins'] if 'max_logins' in row.keys() else 1
    text = f"📱 <b>DISPOSITIVOS - {username}</b>\n{brand_divider()}\n\n👤 Dispositivos actuales: <b>{current}</b>\n\nCuantos dispositivos quieres agregar?"
    await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=kb_extend_devices(username))
    return K_EXTEND_DEVICES

async def do_extend_devices(update: Update, context: ContextTypes.DEFAULT_TYPE, username: str, add: int) -> int:
    query = update.callback_query
    try:
        import sqlite3 as _sqlite3
        _db = _sqlite3.connect(DB_PATH)
        _db.row_factory = _sqlite3.Row
        row = _db.execute("SELECT * FROM system_users WHERE username=?", (username,)).fetchone()
        if not row:
            _db.close()
            await query.edit_message_text("❌ No encontrado.", reply_markup=kb_users())
            return K_USERS_MENU
        current = row['max_logins'] if 'max_logins' in row.keys() else 1
        new_max = current + add
        _db.execute("UPDATE system_users SET max_logins=? WHERE username=?", (new_max, username))
        _db.commit()
        _db.close()
    except Exception as e:
        logging.error(f"[do_extend_devices] DB ERROR: {e}")
    try:
        import subprocess as _sp
        _sp.run(f"sed -i '/^{username}:/d' /etc/security/limits.conf", shell=True, capture_output=True, timeout=5)
        _sp.run(f"echo '{username} hard maxlogins {new_max}' >> /etc/security/limits.conf", shell=True, capture_output=True, timeout=5)
    except Exception as e2:
        logging.error(f"[do_extend_devices] VPS limits.conf error: {e2}")
    text = f"✅ <b>DISPOSITIVOS ACTUALIZADOS</b>\n{brand_divider()}\n\n👤 Usuario: <code>{username}</code>\n📱 Dispositivos: <b>{current} \u2192 {new_max}</b>"
    await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=kb_user_detail(username))
    return K_USER_DETAIL

async def do_reduce(update: Update, context: ContextTypes.DEFAULT_TYPE, username: str, days: int) -> int:
    query = update.callback_query
    new_expire = datetime.date.today()
    try:
        import sqlite3 as _sqlite3
        _db = _sqlite3.connect(DB_PATH)
        _db.row_factory = _sqlite3.Row
        row = _db.execute("SELECT * FROM system_users WHERE username=?", (username,)).fetchone()
        if not row:
            _db.close()
            await query.edit_message_text("❌ No encontrado.", reply_markup=kb_users())
            return K_USERS_MENU
        old_expire = row['expires_at']
        try:
            new_expire = datetime.date.fromisoformat(old_expire) - datetime.timedelta(days=days)
            if new_expire < datetime.date.today():
                new_expire = datetime.date.today()
        except:
            new_expire = datetime.date.today()
        _db.execute("UPDATE system_users SET expires_at=? WHERE username=?", (str(new_expire), username))
        _db.commit()
        _db.close()
    except Exception as e:
        logging.error(f"[do_reduce] ERROR: {e}")
    try:
        import subprocess as _sp
        _sp.run(f"usermod -e {new_expire} {username}", shell=True, capture_output=True, timeout=10)
    except Exception as e2:
        logging.error(f"[do_reduce] VPS usermod error: {e2}")
    text = f"✅ <b>REDUCCI\u00d3N APLICADA</b>\n{brand_divider()}\n\n👤 Usuario: <code>{username}</code>\n⏰ D\u00edas quitados: <b>-{days}</b>\n📅 Nueva expiraci\u00f3n: <b>{new_expire}</b>"
    await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=kb_user_detail(username))
    log_audit(query.from_user.id, "klepernet_reduce", f"user={username} -{days}d")
    return K_USER_DETAIL

async def do_delete(update: Update, context: ContextTypes.DEFAULT_TYPE, username: str) -> int:
    query = update.callback_query
    user_id = query.from_user.id
    logging.info(f"[do_delete] CALLED: user={username} admin={user_id}")

    vps_ok = False
    vps_msg = ""
    try:
        _ssh = paramiko.SSHClient()
        _ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        _ssh.connect(VPS_HOST, username=VPS_USER, password=VPS_PASS, timeout=10)
        _ssh.exec_command(f"pkill -9 -u {username}")
        _ssh.exec_command(f"pkill -9 -f 'sshd: {username}'")
        import time as _t
        _t.sleep(1)
        cmds = [
            f"userdel -r {username} 2>&1",
            f"sed -i '/^{username}:/d' /etc/security/limits.conf 2>&1",
            f"rm -f /etc/ssh/banners/{username}.html 2>&1",
            f"sed -i '/Match User {username}/,/Banner/d' /etc/ssh/sshd_config 2>&1",
            "systemctl reload sshd 2>&1",
        ]
        for cmd in cmds:
            _, stdout, stderr = _ssh.exec_command(cmd, timeout=10)
            out = stdout.read().decode().strip()
            err = stderr.read().decode().strip()
            logging.info(f"[do_delete] VPS cmd: {cmd}")
            if out: logging.info(f"[do_delete] stdout: {out}")
            if err: logging.info(f"[do_delete] stderr: {err}")
        _ssh.close()
        vps_ok = True
        vps_msg = "\n⚙️ SSH eliminado del VPS"
    except Exception as e:
        logging.error(f"[do_delete] VPS delete error: {e}")
        vps_msg = f"\n⚠️ Error VPS: {e}"

    try:
        import sqlite3 as _sqlite3
        _db = _sqlite3.connect(DB_PATH)
        _db.execute("DELETE FROM system_users WHERE username=?", (username,))
        _db.commit()
        logging.info(f"[do_delete] DB delete OK for {username}")
        _db.close()
    except Exception as e:
        logging.error(f"[do_delete] DB delete error: {e}")

    log_audit(user_id, "klepernet_delete", f"user={username}")
    text = f"🗑 <b>USUARIO ELIMINADO</b>\n{brand_divider()}\n\n👤 <code>{username}</code> eliminado de {brand.upper()}.{vps_msg}"
    await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=kb_users())
    return K_USERS_MENU

async def cleanup_expired(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    user_id = query.from_user.id
    brand = get_admin_brand(user_id)
    expired = db.fetchall(
        "SELECT username FROM system_users WHERE brand=? AND (status='expired' OR expires_at < date('now'))",
        (brand,))
    count = 0
    for row in expired:
        try:
            _ssh2 = paramiko.SSHClient()
            _ssh2.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            _ssh2.connect(VPS_HOST, username=VPS_USER, password=VPS_PASS, timeout=10)
            _ssh2.exec_command(f"userdel -f {row['username']}")
            _ssh2.exec_command(f"rm -f /etc/ssh/banners/{row['username']}.html")
            _ssh2.close()
        except:
            pass
        count += 1
    db.execute("UPDATE system_users SET status='expired' WHERE brand=? AND (status='expired' OR expires_at < date('now'))", (brand,))
    log_audit(user_id, "klepernet_cleanup", f"removed={count}")
    await query.edit_message_text(f"🧹 <b>LIMPIEZA COMPLETADA</b>\n{brand_divider()}\n\n✅ {count} usuarios expirados eliminados de {brand.upper()}.", parse_mode=ParseMode.HTML, reply_markup=kb_users())
    return K_USERS_MENU

# =============================================================================
# BUSCAR
# =============================================================================
async def text_handler(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    if context.user_data.get("search_mode"):
        context.user_data["search_mode"] = False
        return await do_search(update, context)
    return K_MAIN

async def do_search(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    text = update.message.text.strip()
    user_id = update.effective_user.id
    brand = get_admin_brand(user_id)
    if text.isdigit():
        rows = db.fetchall("SELECT * FROM system_users WHERE brand=? AND (username=? OR tg_id=?)", (brand, text, int(text)))
    else:
        rows = db.fetchall("SELECT * FROM system_users WHERE brand=? AND username LIKE ?", (brand, f"%{text}%"))
    result_text = f"🔍 <b>BUSCAR: {text}</b>\n{brand_divider()}\n\n"
    if not rows:
        result_text += "📭 Sin resultados."
    else:
        for i, r in enumerate(rows, 1):
            try:
                days = (datetime.date.fromisoformat(r['expires_at']) - datetime.date.today()).days
                days_icon = "✅" if days > 3 else "⚠️" if days > 0 else "❌"
            except:
                days_icon = "❓"
                days = "?"
            result_text += f"👤 <b>{i}. {r['username']}</b>\n   🔑 {r['password']} | 📡 {r['operator']}\n   {days_icon} {days}d | 👤 {r['max_logins']} disp\n\n"
    await update.message.reply_text(result_text, parse_mode=ParseMode.HTML, reply_markup=kb_users())
    return K_USERS_MENU

# =============================================================================
# ESTADISTICAS - VPS REAL-TIME
# =============================================================================
async def show_stats(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    user_id = query.from_user.id
    brand = get_admin_brand(user_id)

    await query.edit_message_text("📊 <b>Cargando estadísticas del VPS...</b>\n" + brand_divider() + "\n⏳ Consultando servidor...", parse_mode=ParseMode.HTML)

    try:
        stats = db.fetchone("""
            SELECT
                (SELECT COUNT(*) FROM system_users WHERE brand=?) as total,
                (SELECT COUNT(*) FROM system_users WHERE brand=? AND status='active' AND expires_at >= date('now')) as active,
                (SELECT COUNT(*) FROM system_users WHERE brand=? AND status='active' AND expires_at < date('now')) as expired,
                (SELECT COUNT(*) FROM system_users WHERE brand=? AND status='active' AND expires_at BETWEEN date('now') AND date('now', '+3 days')) as expiring,
                (SELECT COUNT(*) FROM system_users WHERE brand=? AND trial=1) as trials
        """, (brand, brand, brand, brand, brand))
    except Exception as e:
        logger.error(f"DB stats error: {e}")
        stats = {'total': 0, 'active': 0, 'expired': 0, 'expiring': 0, 'trials': 0}

    try:
        per_op = db.fetchall(
            "SELECT operator, COUNT(*) as cnt FROM system_users WHERE brand=? AND status='active' GROUP BY operator",
            (brand,))
    except:
        per_op = []

    try:
        vps = get_vps_stats()
    except Exception as e:
        logger.error(f"VPS stats error: {e}")
        vps = {'cpu': 'Error', 'ram': 'Error', 'disk': 'Error', 'uptime': 'Error', 'load': 'Error', 'net_in': 'Error', 'net_out': 'Error', 'ssh_sessions': '0', 'services_up': '0', 'vps_users': '0'}

    text = f"""🌐 <b>ESTADO VPS - KLEPERNET</b>
{brand_divider()}

┌────────────────────────────┐
│ 🖥 <b>ESTADO DEL SERVIDOR</b>
├────────────────────────────┤
│ 🧠 CPU: <b>{vps['cpu']}%</b>
│ 🟢 RAM: <b>{vps['ram']}</b>
│ 💾 Disco: <b>{vps['disk']}</b>
│ ⏱ Uptime: <b>{vps['uptime']}</b>
│ ⚖️ Load: <b>{vps['load']}</b>
│ 📥 Net In: <b>{vps['net_in']}</b>
│ 📤 Net Out: <b>{vps['net_out']}</b>
│ 🔌 SSH Sessions: <b>{vps['ssh_sessions']}</b>
│ ⚙️ Services Up: <b>{vps['services_up']}</b>
│ 👤 VPS Users: <b>{vps['vps_users']}</b>
└────────────────────────────┘

┌────────────────────────────┐
│ 📊 <b>USUARIOS {brand.upper()}</b>
├────────────────────────────┤
│ 👥 Total: <b>{stats['total'] or 0}</b>
│ ✅ Activos: <b>{stats['active'] or 0}</b>
│ ❌ Expirados: <b>{stats['expired'] or 0}</b>
│ ⏰ Por expirar: <b>{stats['expiring'] or 0}</b>
│ 🎁 Trials: <b>{stats['trials'] or 0}</b>
└────────────────────────────┘"""

    if per_op:
        text += "\n\n┌────────────────────────────┐\n│ 📡 <b>POR OPERADOR</b>\n├────────────────────────────┤\n"
        for r in per_op:
            op_cfg = OPERATORS.get(r['operator'], {})
            flag = op_cfg.get('flag', '')
            text += f"│ {flag} {r['operator'].upper()}: <b>{r['cnt']}</b>\n"
        text += "└────────────────────────────┘"

    kb = InlineKeyboardMarkup([
        [InlineKeyboardButton("🔄 Actualizar Stats", callback_data="k_stats")],
        [InlineKeyboardButton("🔙 Volver", callback_data="k_back")],
    ])
    await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=kb)
    return K_MAIN

# =============================================================================
# IMPORTS + MAIN
# =============================================================================
from ssh_utils import create_ssh_account, delete_ssh_on_vps

async def post_init(application: Application):
    await application.bot.set_my_commands([BotCommand("start", "Panel KleperNet")])
    # Sembrar el administrador autorizado (config.ADMIN_IDS) en la tabla admins.
    # Garantiza que la ID del dueno funcione aunque la DB arranque vacia.
    try:
        for admin_id in ADMIN_IDS:
            db.execute(
                "INSERT OR IGNORE INTO admins (tg_id, added_by, role, brand, permissions, is_active) "
                "VALUES (?, 0, 'superadmin', ?, '[\"all\"]', 1)",
                (int(admin_id), MY_BRAND))
            db.commit()
    except Exception as e:
        logger.error(f"Seed admin error: {e}")
    logger.info("KleperNet Admin Bot v5 started!")

async def error_handler(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    logging.error(f"[ERROR] Exception while handling an update: {context.error}", exc_info=context.error)
    if update and update.callback_query:
        try:
            await update.callback_query.answer("❌ Error procesando. Intenta de nuevo.", show_alert=True)
        except:
            pass

def main():
    application = (
        Application.builder()
        .token(ADMIN_BOT_TOKEN)
        .post_init(post_init)
        .build()
    )

    conv = ConversationHandler(
        entry_points=[CommandHandler("start", cmd_start)],
        states={
            K_MAIN: [CallbackQueryHandler(button_handler)],
            K_USERS_MENU: [
                CallbackQueryHandler(button_handler),
                MessageHandler(filters.TEXT & ~filters.COMMAND, text_handler)
            ],
            K_USER_DETAIL: [CallbackQueryHandler(button_handler)],
            K_USER_CONFIG: [CallbackQueryHandler(button_handler)],
            K_CREATE_OP: [CallbackQueryHandler(button_handler)],
            K_CREATE_CONN_TYPE: [CallbackQueryHandler(button_handler)],
            K_CREATE_DAYS: [CallbackQueryHandler(button_handler)],
            K_CREATE_PROFILES: [CallbackQueryHandler(button_handler)],
            K_CREATE_MODE: [CallbackQueryHandler(button_handler)],
            K_CREATE_USER: [MessageHandler(filters.TEXT & ~filters.COMMAND, ask_manual_password)],
            K_CREATE_PASS: [MessageHandler(filters.TEXT & ~filters.COMMAND, confirm_manual_creds)],
            K_CREATE_HWID: [MessageHandler(filters.TEXT & ~filters.COMMAND, confirm_hwid)],
            K_CREATE_CONFIRM: [CallbackQueryHandler(button_handler)],
            K_SEARCH: [
                CallbackQueryHandler(button_handler),
                MessageHandler(filters.TEXT & ~filters.COMMAND, text_handler)
            ],
            K_EXTEND: [CallbackQueryHandler(button_handler)],
            K_REDUCE: [CallbackQueryHandler(button_handler)],
            K_EXTEND_DEVICES: [CallbackQueryHandler(button_handler)],
            K_REALTIME: [CallbackQueryHandler(button_handler)],
        },
        fallbacks=[CommandHandler("start", cmd_start)],
        per_message=False,
    )

    application.add_handler(conv)
    application.add_error_handler(error_handler)
    application.run_polling(drop_pending_updates=True)

if __name__ == "__main__":
    main()
