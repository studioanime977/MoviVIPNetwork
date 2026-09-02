#!/usr/bin/env python3
"""
MoviVIP Notification Bot v4.0 — JARVIS PRODUCTION
- Welcome con VIDEO BIENVENIDA.mp4 + mensaje HTML MoviVIP (canal y grupo)
- ARCHIVOS .HC POR PAÍS con liberación condicionada a ver anuncios
- Mention/tag detection → admin reports
- Admin panel with working callback buttons
- Full DB integration
"""
import os
import json
import re
import secrets
import sqlite3
import logging
import datetime
import sys
import io
from pathlib import Path

from telegram import (
    Update, InlineKeyboardButton, InlineKeyboardMarkup, WebAppInfo
)
from telegram.helpers import escape_markdown
from telegram.ext import (
    Application, CommandHandler, MessageHandler,
    CallbackQueryHandler, ContextTypes, filters, ChatMemberHandler
)
from telegram.constants import ParseMode

# ═══════════════════════════════════════════════════════════════
# v5.0 — EXTRAS: BIENVENIDA EDITABLE + PROMOS CON FOTO
# Módulos en /opt/movivip-admin/notif (desplegados en Fase 5)
# ═══════════════════════════════════════════════════════════════
_EXTRAS_OK = False
try:
    _EXTRAS_PATH = "/opt/movivip-admin/notif"
    if os.path.isdir(_EXTRAS_PATH) and _EXTRAS_PATH not in sys.path:
        sys.path.insert(0, _EXTRAS_PATH)
    from notif_extras import (
        init_notif_extras_db, get_welcome_settings, save_welcome_settings,
        get_welcome_buttons, send_welcome_media_always,
    )
    from notif_extras_ui import (
        route as extras_route,
        handle_bienvenida_message,
        handle_bienvenida_boton_edit_message,
        handle_promo_message,
        handle_promo_edit_message,
        is_handling_bienvenida,
        is_handling_promo,
    )
    _EXTRAS_OK = True
except Exception as _e:
    logger = logging.getLogger("notif_bot")
    logger.warning(f"Módulos extras no disponibles (bienvenida editable/promos OFF): {_e}")
    # logger aún no definido en producción? sí: logging se importa en línea 15,
    # pero logger a nivel módulo se define más abajo en algunos bots. Usamos básico:
    logging.getLogger().warning(f"Extras notif OFF: {_e}")


def emd(text):
    """Escapa texto plano para ParseMode.MARKDOWN (v1). Previene
    'Can't parse entities' cuando el texto contiene * _ ` [ ] etc."""
    return escape_markdown(str(text), version=1)

# =============================================================================
# CONFIG
# =============================================================================
TOKEN = "***REMOVED_BOT_TOKEN***"
CHANNEL_ID = ***REMOVED_CHANNEL_ID***
GROUP_ID = ***REMOVED_GROUP_ID***
CHANNEL_LINK = "https://t.me/MoviVIPNetwork"
GROUP_LINK = "https://t.me/MoviVIPNet"
SSH_BOT = "@MOVIVIPNETWORK_SSH_BOT"
STORE_BOT = "@MoviVIPUSERVPS_bot"
LOGO_PATH = "/root/movivip_bots/logo.png"
DB_PATH = "/root/movivip.db"
ADMIN_IDS = [***REMOVED_ADMIN_ID***, ***REMOVED_ADMIN_ID***]

# ═══════════════════════════════════════════════════════════════
# v4.0 — VIDEO BIENVENIDA + ARCHIVOS .HC
# ═══════════════════════════════════════════════════════════════
VIDEO_PATH = "/root/movivip_bots/BIENVENIDA.mp4"
MINIAPP_URL = "https://movisvip.servegame.com:8448"
HC_FREE_DIR = "/root/hc_free"
HC_FREE_DATA_FILE = "/root/hc_free_data.json"
HC_ADS_REQUIRED = 5  # anuncios obligatorios antes de soltar el .hc

# Límite de entregas por defecto de un pool de archivos .HC (el admin puede
# cambiarlo al subir cada archivo). Ej: 20 = se entregan 20 archivos/usuarios
# como máximo por pool; al cumplirse, el admin recibe la notificación para
# crear archivos nuevos.
HC_DEFAULT_MAX_USERS = 20

COUNTRIES = {
    'co': {'name': 'Colombia', 'flag': '🇨🇴'},
    'ar': {'name': 'Argentina', 'flag': '🇦🇷'},
    'pe': {'name': 'Perú', 'flag': '🇵🇪'},
    'in': {'name': 'India', 'flag': '🇮🇳'},
    'sv': {'name': 'El Salvador', 'flag': '🇸🇻'},
    'mx': {'name': 'México', 'flag': '🇲🇽'},
    'br': {'name': 'Brasil', 'flag': '🇧🇷'},
    'cl': {'name': 'Chile', 'flag': '🇨🇱'},
    'ec': {'name': 'Ecuador', 'flag': '🇪🇨'},
    'other': {'name': 'Otros Países', 'flag': '🌎'},
}

# Operadoras de Colombia — el archivo .hc se asigna a una operadora
# por su NOMBRE (ej: "movistar_metodo1.hc", "tigo.hc", "claro.hc", "wom.hc")
CARRIERS_CO = {
    'movistar': {'name': 'Movistar', 'icon': '📱'},
    'tigo':     {'name': 'Tigo', 'icon': '📡'},
    'claro':    {'name': 'Claro', 'icon': '🔴'},
    'wom':      {'name': 'WOM', 'icon': '🟣'},
}


def get_carrier_from_name(file_name):
    """Detecta la operadora colombiana desde el nombre del archivo .hc."""
    n = (file_name or '').lower()
    for carrier in ['movistar', 'tigo', 'claro', 'wom']:
        if carrier in n:
            return carrier
    return None


def carrier_name(entry):
    """Nombre legible de la operadora de un entry .hc."""
    c = entry.get('carrier')
    if not c:
        c = get_carrier_from_name(entry.get('file_name', ''))
    if not c:
        return 'Otros'
    return CARRIERS_CO.get(c, {}).get('name', c)


# ═══════════════════════════════════════════════════════════════
# LABELS CON EMOJIS PARA ARCHIVOS .HC
# ═══════════════════════════════════════════════════════════════
EMOJI_RE = re.compile(
    r'[\U0001F000-\U0001FAFF\u2600-\u27BF\u2B00-\u2BFF\uFE0F\u2B50'
    r'\u2764\u2705\u2728\u274C\u274E\u2753\u2754\u2755\u2757\u2763'
    r'\u3030\u303D\u3297\u3299\u200D]'
)

# Banderas para códigos de país que pueden venir al FINAL del nombre del
# archivo (ej: "claro_ve.hc", "wom-PE.hc", "movistar ar.hc") y que no están
# en COUNTRIES. Los códigos de COUNTRIES se resuelven directo con su bandera.
COUNTRY_FLAGS_EXTRA = {
    've': '🇻🇪', 'bo': '🇧🇴', 'py': '🇵🇾', 'uy': '🇺🇾', 'cr': '🇨🇷',
    'gt': '🇬🇹', 'hn': '🇭🇳', 'ni': '🇳🇮', 'sv': '🇸🇻', 'do': '🇩🇴',
    'pa': '🇵🇦', 'cu': '🇨🇺', 'pr': '🇵🇷', 'us': '🇺🇸', 'es': '🇪🇸',
    'gb': '🇬🇧', 'de': '🇩🇪', 'fr': '🇫🇷', 'it': '🇮🇹', 'pt': '🇵🇹',
    'ca': '🇨🇦', 'mx': '🇲🇽',
}


def _contains_emoji(text):
    """True si el texto tiene al menos un emoji."""
    return bool(EMOJI_RE.search(text or ''))


def detect_country_flag_from_name(file_name):
    """Bandera del país si el nombre del archivo termina con un código
    de país (ej: "movistar_co.hc", "claro-PE.hc", "wom ar.hc" → 🇨🇴 🇵🇪 🇦🇷)."""
    base = (file_name or '').strip()
    base = os.path.splitext(base)[0]
    m = re.search(r'(?:^|[_\-.\s(])([a-zA-Z]{2})$', base)
    if not m:
        return None
    code = m.group(1).lower()
    if code in COUNTRIES and code != 'other':
        return COUNTRIES[code]['flag']
    return COUNTRY_FLAGS_EXTRA.get(code)


def build_hc_label(raw_name, carrier=None):
    """Label visible con emojis:
    1) Conserva los emojis del nombre original del archivo.
    2) Si el nombre termina con un código de país (co/pe/ar...) le añade su bandera.
    3) Si NO tiene ningún emoji, le antepone el emoji usual de la operadora
       (📱 Movistar / 📡 Tigo / 🔴 Claro / 🟣 WOM / 📶 Otros).
    """
    label = os.path.splitext(raw_name)[0].strip() or 'archivo'
    flag = detect_country_flag_from_name(raw_name)
    if flag:
        if flag not in label:
            label = f"{label} {flag}".strip()
        return label
    if not _contains_emoji(label):
        icon = '📶'
        if carrier:
            icon = CARRIERS_CO.get(carrier, {}).get('icon', '📶')
        label = f"{icon} {label}".strip()
    return label


SOCIAL = {
    'web': 'https://movivip-network.web.app',
    'tiktok': 'https://www.tiktok.com/@movi.vip.network',
    'youtube': 'https://www.youtube.com/@MoviVIPNetwork',
    'telegram_ch': 'https://t.me/MoviVIPNetwork',
    'telegram_group': 'https://t.me/MoviVIPNet',
    'whatsapp_ch': 'https://whatsapp.com/channel/0029Vao0aLj0uVJtDjHc7P24',
    'whatsapp_community': 'https://chat.whatsapp.com/KmEz5Jr8RrH8rN8LJQpZ8V',
    'whatsapp_personal': 'https://wa.me/573117008185',
}

OFFICIAL_MSG = (
    "⚠️ *COMUNICADO OFICIAL MoviVIP Network*\n"
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
    "🔒 Por seguridad, los servidores ahora duran *3 dias* debido a robo y venta de credenciales.\n\n"
    "📱 Solo conectan usuarios asignados por puerto (1 IP por cuenta).\n\n"
    "🤖 Crea tus usuarios en el bot SSH.\n\n"
    "💻 Hosts: *$43.000 COP* con configuracion incluida.\n\n"
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
)

# Logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.FileHandler("/var/log/movivip/notif_bot.log"),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger("NotifBot")

# =============================================================================
# DATABASE
# =============================================================================
def get_db():
    db = sqlite3.connect(DB_PATH, timeout=15)
    db.row_factory = sqlite3.Row
    try:
        db.execute("PRAGMA busy_timeout=15000")
    except Exception:
        pass
    return db

def init_notif_db():
    db = get_db()
    db.execute("""CREATE TABLE IF NOT EXISTS community_members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tg_id INTEGER UNIQUE,
        username TEXT,
        first_name TEXT,
        source TEXT,
        joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        is_active INTEGER DEFAULT 1
    )""")
    db.execute("""CREATE TABLE IF NOT EXISTS welcome_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tg_id INTEGER,
        username TEXT,
        first_name TEXT,
        source TEXT,
        chat_title TEXT,
        chat_id INTEGER,
        welcomed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )""")
    db.execute("""CREATE TABLE IF NOT EXISTS mention_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        reporter_id INTEGER,
        reporter_name TEXT,
        reporter_username TEXT,
        mentioned_by_id INTEGER,
        mentioned_by_name TEXT,
        message_text TEXT,
        chat_id INTEGER,
        chat_title TEXT,
        report_type TEXT DEFAULT 'mention',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )""")
    db.execute("""CREATE TABLE IF NOT EXISTS official_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sent_by INTEGER,
        target TEXT,
        success_count INTEGER DEFAULT 0,
        fail_count INTEGER DEFAULT 0,
        sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )""")
    db.execute("""CREATE TABLE IF NOT EXISTS hc_deliveries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        hc_file_id TEXT NOT NULL,
        hc_label TEXT,
        user_id INTEGER NOT NULL,
        user_name TEXT,
        received_at TEXT,
        screenshot_status TEXT DEFAULT 'pending',
        photo_count INTEGER DEFAULT 0,
        active INTEGER DEFAULT 1
    )""")
    db.execute("CREATE INDEX IF NOT EXISTS idx_hc_deliveries_user ON hc_deliveries(user_id)")
    hcd_cols = {row[1] for row in db.execute("PRAGMA table_info(hc_deliveries)").fetchall()}
    if 'days_choice' not in hcd_cols:
        db.execute("ALTER TABLE hc_deliveries ADD COLUMN days_choice INTEGER")
    if 'devices' not in hcd_cols:
        db.execute("ALTER TABLE hc_deliveries ADD COLUMN devices INTEGER DEFAULT 1")
    if 'expires_at' not in hcd_cols:
        db.execute("ALTER TABLE hc_deliveries ADD COLUMN expires_at TEXT")
    if 'renewed' not in hcd_cols:
        db.execute("ALTER TABLE hc_deliveries ADD COLUMN renewed INTEGER DEFAULT 0")
    if 'renewed_at' not in hcd_cols:
        db.execute("ALTER TABLE hc_deliveries ADD COLUMN renewed_at TEXT")
    if 'renew_prompted' not in hcd_cols:
        db.execute("ALTER TABLE hc_deliveries ADD COLUMN renew_prompted INTEGER DEFAULT 0")
    if 'country' not in hcd_cols:
        db.execute("ALTER TABLE hc_deliveries ADD COLUMN country TEXT DEFAULT ''")
    if 'carrier' not in hcd_cols:
        db.execute("ALTER TABLE hc_deliveries ADD COLUMN carrier TEXT DEFAULT ''")
    db.execute("CREATE INDEX IF NOT EXISTS idx_hc_deliveries_renew ON hc_deliveries(renewed, expires_at)")

    # ===== ADBLOCK / 3-STRIKE SYSTEM =====
    db.execute("""CREATE TABLE IF NOT EXISTS ad_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        token TEXT NOT NULL,
        event TEXT NOT NULL,          -- impression, complete, close, error, adblock_detected
        network TEXT DEFAULT 'monetag',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )""")
    db.execute("CREATE INDEX IF NOT EXISTS idx_ad_events_token ON ad_events(token)")
    db.execute("CREATE INDEX IF NOT EXISTS idx_ad_events_user ON ad_events(user_id)")

    db.execute("""CREATE TABLE IF NOT EXISTS adblock_strikes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER UNIQUE NOT NULL,
        username TEXT,
        first_name TEXT,
        strikes INTEGER DEFAULT 0,     -- 1, 2, 3
        status TEXT DEFAULT 'active',  -- active, banned, unbanned_conditional
        first_strike_at TIMESTAMP,
        last_strike_at TIMESTAMP,
        banned_at TIMESTAMP,
        unbanned_at TIMESTAMP,
        unbanned_by INTEGER,
        unban_reason TEXT,
        permanent_ban INTEGER DEFAULT 0
    )""")
    db.execute("CREATE INDEX IF NOT EXISTS idx_adblock_strikes_status ON adblock_strikes(status)")

    db.commit()
    db.close()
    logger.info("Database initialized")

def store_member(tg_id, username, first_name, source):
    try:
        db = get_db()
        existing = db.execute("SELECT id FROM community_members WHERE tg_id=?", (tg_id,)).fetchone()
        if existing:
            db.execute("UPDATE community_members SET is_active=1, username=?, first_name=? WHERE tg_id=?",
                       (username, first_name, tg_id))
        else:
            db.execute("INSERT OR IGNORE INTO community_members (tg_id, username, first_name, source) VALUES (?,?,?,?)",
                       (tg_id, username, first_name, source))
        db.commit()
        db.close()
    except Exception as e:
        logger.error(f"store_member: {e}")

def store_welcome(tg_id, username, first_name, source, chat_title, chat_id):
    try:
        db = get_db()
        db.execute("INSERT INTO welcome_log (tg_id, username, first_name, source, chat_title, chat_id) VALUES (?,?,?,?,?,?)",
                   (tg_id, username, first_name, source, chat_title, chat_id))
        db.commit()
        db.close()
    except Exception as e:
        logger.error(f"store_welcome: {e}")

def store_mention_report(reporter_id, reporter_name, reporter_username, message_text, chat_id, chat_title, report_type='mention'):
    try:
        db = get_db()
        db.execute(
            "INSERT INTO mention_reports (reporter_id, reporter_name, reporter_username, message_text, chat_id, chat_title, report_type) VALUES (?,?,?,?,?,?,?)",
            (reporter_id, reporter_name, reporter_username, message_text, chat_id, chat_title, report_type)
        )
        db.commit()
        db.close()
    except Exception as e:
        logger.error(f"store_mention_report: {e}")

# =============================================================================
# HELPERS
# =============================================================================
ADMIN_USERNAMES = ['Aybolit2025', 'Aybolit']

def is_admin(user_id):
    if user_id in ADMIN_IDS:
        return True
    # Also check by DB admins table
    try:
        db = get_db()
        row = db.execute("SELECT tg_id FROM admins WHERE tg_id=?", (user_id,)).fetchone()
        db.close()
        if row:
            return True
    except:
        pass
    return False


# =============================================================================
# ADBLOCK / 3-STRIKE SYSTEM
# =============================================================================
def adblock_get_strike(user_id):
    """Obtiene info de strikes del usuario."""
    try:
        db = get_db()
        row = db.execute("SELECT * FROM adblock_strikes WHERE user_id=?", (user_id,)).fetchone()
        db.close()
        return row
    except Exception as e:
        logger.error(f"adblock_get_strike: {e}")
        return None

def adblock_add_strike(user_id, username, first_name):
    """Añade strike al usuario. Retorna (strikes, status, is_banned)."""
    try:
        db = get_db()
        row = db.execute("SELECT * FROM adblock_strikes WHERE user_id=?", (user_id,)).fetchone()
        now = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        
        if row:
            strikes = row['strikes'] + 1
            if strikes >= 3:
                status = 'banned'
                db.execute("""UPDATE adblock_strikes 
                    SET strikes=?, status=?, last_strike_at=?, banned_at=?, permanent_ban=?
                    WHERE user_id=?""",
                    (strikes, status, now, now, 1 if strikes >= 3 else 0, user_id))
            else:
                status = 'active'
                first_strike = row['first_strike_at'] or now
                db.execute("""UPDATE adblock_strikes 
                    SET strikes=?, status=?, first_strike_at=?, last_strike_at=?
                    WHERE user_id=?""",
                    (strikes, status, first_strike, now, user_id))
        else:
            strikes = 1
            status = 'active'
            db.execute("""INSERT INTO adblock_strikes 
                (user_id, username, first_name, strikes, status, first_strike_at, last_strike_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)""",
                (user_id, username, first_name, strikes, status, now, now))
        
        db.commit()
        db.close()
        
        # Si llegó a 3 → banear en user_bot también (via notificación)
        if strikes >= 3:
            logger.warning(f"USER BANNED (adblock 3 strikes): {user_id} @{username}")
            # Notificar al canal de admin
            try:
                send_notif_bot_msg(ADMIN_IDS[0], 
                    f"🚫 <b>BLOQUEO PERMANENTE - ADBLOCK</b>\n"
                    f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
                    f"👤 <b>Usuario:</b> {first_name or 'N/A'} (@{username or 'N/A'})\n"
                    f"🆔 <b>ID:</b> <code>{user_id}</code>\n"
                    f"⚠️ <b>3 strikes por adblock detectado</b>\n"
                    f"🕐 <b>Fecha:</b> {now}\n"
                    f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
                    f"🔒 Usuario bloqueado: NO puede crear SSH ni obtener .HC\n"
                    f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            except:
                pass
        
        return strikes, status, strikes >= 3
    except Exception as e:
        logger.error(f"adblock_add_strike: {e}")
        return 0, 'error', False

def adblock_unban(user_id, admin_id, reason="", conditional=True):
    """Desbanea usuario. conditional=True → 1 strike restante, si reincide = ban permanente."""
    try:
        db = get_db()
        row = db.execute("SELECT * FROM adblock_strikes WHERE user_id=?", (user_id,)).fetchone()
        if not row:
            db.close()
            return False, "Usuario no tiene strikes registrados"
        
        now = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        
        if conditional:
            # Unban condicional: strikes=1, status=unbanned_conditional
            # Si vuelve a fallar → permanent_ban=1
            db.execute("""UPDATE adblock_strikes 
                SET strikes=1, status='unbanned_conditional', unbanned_at=?, 
                    unbanned_by=?, unban_reason=?, permanent_ban=0
                WHERE user_id=?""",
                (now, admin_id, reason, user_id))
            msg = "Desbaneado CONDICIONAL (1 strike). Si reincide → BAN PERMANENTE."
        else:
            # Unban total: limpiar registro
            db.execute("DELETE FROM adblock_strikes WHERE user_id=?", (user_id,))
            msg = "Desbaneado TOTAL (registro eliminado)."
        
        db.commit()
        db.close()
        
        # Notificar al usuario
        try:
            send_telegram_msg(user_id,
                f"✅ <b>HAS SIDO DESBANEADO</b>\n"
                f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
                f"{msg}\n"
                f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
                f"🛡️ MOVIVIP NETWORK ⚡ 2026",
                parse_mode=ParseMode.HTML)
        except:
            pass
        
        return True, msg
    except Exception as e:
        logger.error(f"adblock_unban: {e}")
        return False, str(e)

def adblock_is_banned(user_id):
    """Verifica si usuario está baneado (no puede crear SSH ni .HC)."""
    try:
        db = get_db()
        row = db.execute("SELECT status, permanent_ban FROM adblock_strikes WHERE user_id=?", (user_id,)).fetchone()
        db.close()
        if row and row['status'] == 'banned':
            return True, row['permanent_ban'] == 1
        return False, False
    except:
        return False, False

def adblock_get_all_strikes(status=None):
    """Lista usuarios con strikes (para panel admin)."""
    try:
        db = get_db()
        if status:
            rows = db.execute("SELECT * FROM adblock_strikes WHERE status=? ORDER BY last_strike_at DESC", (status,)).fetchall()
        else:
            rows = db.execute("SELECT * FROM adblock_strikes ORDER BY last_strike_at DESC").fetchall()
        db.close()
        return rows
    except Exception as e:
        logger.error(f"adblock_get_all_strikes: {e}")
        return []


# =============================================================================
# ARCHIVOS .HC — Registro (formato compatible con vps_admin_bot)
# =============================================================================
def load_hc_data():
    """Load .hc registry: [{id, file_path, file_name, country, days,
                            created_at, expires_at, last_sent_at, send_count, active}]"""
    try:
        with open(HC_FREE_DATA_FILE, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception:
        return []

def save_hc_data(data):
    try:
        os.makedirs(HC_FREE_DIR, exist_ok=True)
        with open(HC_FREE_DATA_FILE, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        return True
    except Exception as e:
        logger.error(f"save_hc_data: {e}")
        return False

def get_hc_entries(country=None, active_only=True):
    data = load_hc_data()
    result = []
    for entry in data:
        if active_only and not entry.get('active', True):
            continue
        if country and entry.get('country') != country:
            continue
        result.append(entry)
    return result

def get_hc_entry(hc_id):
    for entry in load_hc_data():
        if str(entry.get('id')) == str(hc_id):
            return entry
    return None


def hc_pool_info(entry):
    """Devuelve (pool_total, max_users) para una entrada .HC.

    - Si el archivo tiene 'hc_user' definido → el pool agrupa TODOS los
      archivos activos con ese MISMO usuario SSH (ej: 3 archivos con el mismo
      user+pass comparten el límite).
    - Si no tiene 'hc_user' → el pool es solo ese archivo.
    """
    data = load_hc_data()
    max_users = int(entry.get('max_users') or HC_DEFAULT_MAX_USERS)
    hc_user = (entry.get('hc_user') or '').strip()
    if hc_user:
        total = sum(
            int(e.get('send_count', 0))
            for e in data
            if e.get('active', True) and (e.get('hc_user') or '').strip() == hc_user
        )
    else:
        total = int(entry.get('send_count', 0))
    return total, max_users


def hc_pool_exhausted(entry):
    """True si el pool de este archivo ya llegó a su límite de entregas."""
    total, max_users = hc_pool_info(entry)
    return total >= max_users


# =============================================================================
# BIENVENIDA v4.0 — VIDEO + MENSAJE HTML MOVIVIP
# =============================================================================
def build_movivip_html(first_name, username):
    """Mensaje de bienvenida MoviVIP Network PREMIUM (HTML nativo Telegram).
    Incluye: ID Telegram, hora de unión, servidores internacionales, features premium, botones completos."""
    user_display = f"@{username}" if username else first_name or "Usuario"
    nombre = first_name or "Usuario"
    join_date = datetime.datetime.now().strftime('%d/%m/%Y %H:%M')
    return (
        "⚡️ <b>MOVIVIP NETWORK</b> ⚡️\n"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        f"👤 <b>Nombre:</b> 👑 <b>MoviVIP Network | Servicios Digitales</b> 👑 🚀\n"
        f"🔗 <b>Usuario:</b> {user_display}\n"
        f"🆔 <b>ID Telegram:</b> <code>{username or 'N/A'}</code>\n"
        f"📅 <b>Se unió:</b> {join_date}\n\n"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        "🛡️ <b>REGLAS DE LA COMUNIDAD:</b>\n"
        "1️⃣ Respeta a todos los miembros\n"
        "2️⃣ No spam ni publicidad\n"
        "3️⃣ No compartir credenciales\n"
        "4️⃣ Usa los bots para tus cuentas\n"
        "5️⃣ Reporta cualquier abuso\n\n"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        "🛡️ ⚔️ <b>MOVIVIP NETWORK ⚔️ ALTO RENDIMIENTO & SEGURIDAD TOTAL</b> 🛡️\n"
        "🛡️ <b>MOVIVIP NETWORK - ESCUDO VIP</b> 🛡️\n"
        "🎖️ <b>MÁXIMA POTENCIA Y BLINDAJE DE RED</b> 🎖️\n"
        "🇨🇴 🇦🇷 🇲🇽 🇧🇷 <b>SERVIDORES INTERNACIONALES</b> 🇨🇱 🇵🇪 🇪🇨 🇻🇪\n"
        "⚡ <b>SISTEMA ÓPTIMO ACTIVO • NAVEGACIÓN LIBRE Y SEGURA</b>\n"
        "🔒 <b>INFRAESTRUCTURA EXCLUSIVA DE MOVIVIP NETWORK</b>\n\n"
        "💎 <b>¡PLANES Y ACCESOS ESPECIALES!</b>\n"
        "Consulta con soporte para obtener <b>BENEFICIOS EXCLUSIVOS</b>\n"
        "en tus próximas activaciones.\n\n"
        "★☆★ 🌎 <b>CANALES OFICIALES</b> 🌎 ★☆★\n"
        "🌐 <b>WEB:</b> <a href='https://movivip-network.web.app/'>[ PORTAL WEB ]</a>\n"
        "📢 <b>CANAL:</b> <a href='https://t.me/MoviVIPNetwork'>[ CANAL OFICIAL ]</a>\n"
        "👥 <b>GRUPO:</b> <a href='https://t.me/MoviVIPNet'>[ COMUNIDAD ]</a>\n\n"
        "📡 <b>ESTADO DEL SERVIDOR</b> 📡\n"
        "🇨🇴 <b>COLOMBIA</b> 🇦🇷 <b>ARGENTINA</b> 🇲🇽 <b>MÉXICO</b> 🇧🇷\n\n"
        "🛡️ <b>TIGO</b> 🛡️ <b>MOVISTAR</b> 🛡️ <b>WOM</b> 🛡️ <b>CLARO</b>\n"
        "⚔️ <b>VIRGIN (PRÓXIMAMENTE)</b> ⚔️\n\n"
        "📱⚙️ <b>DISEÑADO Y PROBADO PARA</b> ⚙️📱\n"
        "⚔️ <b>STREAMING 4K</b> ⚔️ <b>GAMING COMPETITIVO</b> ⚔️ <b>LIBRE NAVEGACIÓN</b>\n\n"
        "🛡️ <b>VENTAJAS DEL SERVICIO PREMIUM</b>\n"
        "⚡ VELOCIDAD LIBRE • SOPORTE TÉCNICO CONSTANTE\n"
        "🛡️ TÚNELES CIFRADOS DE ALTA RESISTENCIA\n\n"
        "🛡️ <b>VINCIT QUI PATITUR</b> 🛡️\n"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        "🇨🇴 🇦🇷 🇲🇽 🛡️ 🇧🇷 🇨🇱 🇵🇪\n"
        "🛡️ ⚔️ <b>MOVIVIP NETWORK</b> ⚔️ 🛡️\n"
        "🛡️ <b>ACCESO PROTEGIDO</b> 🛡️\n\n"
        "🤖 <b>BOT OFICIAL:</b> <a href='https://t.me/MoviVIP'>@MoviVIP</a>\n"
        "📲 <b>WHATSAPP:</b> <a href='https://chat.whatsapp.com/FXTTJXjsOyJKtJ7kkFbB5Y'>[ UNIRTE AL CHAT ]</a>\n"
        "👤 <b>ADMINISTRADOR:</b> <a href='https://t.me/MoviVIP'>@MoviVIP</a>\n\n"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        "🛡️ <b>Para adquirir tu cuenta premium usa este comando:</b> <code>/vip</code>\n"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        "<b>🛡️ MOVIVIP NETWORK ⚡ 2026 🛡️</b>"
    )

async def send_welcome_video(context, chat_id, first_name, username):
    """Envía el video BIENVENIDA.mp4 + mensaje HTML PREMIUM completo + botones (2 mensajes)."""
    keyboard = get_welcome_keyboard()
    html_text = build_movivip_html(first_name, username)

    # 1) Video con caption corto
    video_ok = False
    if os.path.exists(VIDEO_PATH):
        try:
            with open(VIDEO_PATH, 'rb') as video:
                await context.bot.send_video(
                    chat_id=chat_id,
                    video=video,
                    caption="⚡️ <b>MOVIVIP NETWORK</b> ⚡️\nBienvenido al mejor servicio VPN/SSH 🛡️",
                    parse_mode=ParseMode.HTML,
                    supports_streaming=True
                )
            video_ok = True
            logger.info(f"Video welcome sent to chat {chat_id}")
        except Exception as e:
            logger.error(f"Video welcome error: {e}")
    else:
        logger.warning(f"Video not found: {VIDEO_PATH}")

    # 2) Mensaje HTML PREMIUM completo + botones (siempre se envía)
    try:
        await context.bot.send_message(
            chat_id=chat_id,
            text=html_text,
            parse_mode=ParseMode.HTML,
            reply_markup=keyboard,
            disable_web_page_preview=True
        )
        logger.info(f"HTML premium welcome sent to chat {chat_id}")
        return True
    except Exception as e:
        logger.error(f"HTML welcome error: {e}")
        # Fallback sin botones
        try:
            await context.bot.send_message(chat_id=chat_id, text=html_text, parse_mode=ParseMode.HTML)
            return True
        except Exception as e2:
            logger.error(f"HTML welcome fallback error: {e2}")
            return False

def get_welcome_keyboard():
    """Inline keyboard with all links as buttons."""
    # v5.0: si el admin configuró botones editables (DB), usarlos;
    # si no hay ninguno configurado → teclado social por defecto.
    if _EXTRAS_OK:
        try:
            filas = get_welcome_buttons()
            if filas:
                return InlineKeyboardMarkup(filas)
        except Exception as e:
            logger.error(f"get_welcome_keyboard extras error: {e}")
    return InlineKeyboardMarkup([
        [
            InlineKeyboardButton("🔑 Bot SSH (con tienda)", url=f"https://t.me/{SSH_BOT.replace('@','')}"),
            InlineKeyboardButton("🌐 Web Oficial", url=SOCIAL['web']),
        ],
        [
            InlineKeyboardButton("🎵 TikTok", url=SOCIAL['tiktok']),
            InlineKeyboardButton("📺 YouTube", url=SOCIAL['youtube'])
        ],
        [
            InlineKeyboardButton("📢 Canal Telegram", url=SOCIAL['telegram_ch']),
            InlineKeyboardButton("💬 Grupo", url=SOCIAL['telegram_group'])
        ],
        [
            InlineKeyboardButton("📱 WhatsApp Canal", url=SOCIAL['whatsapp_ch']),
            InlineKeyboardButton("👥 Comunidad WA", url=SOCIAL['whatsapp_community'])
        ],
        [
            InlineKeyboardButton("📞 WA Personal +57 311 700 8185", url=SOCIAL['whatsapp_personal']),
            InlineKeyboardButton("🤖 Bot Compras @MoviVIP", url="https://t.me/MoviVIP")
        ],
    ])

def build_welcome_text(first_name, username, tg_id, source, join_date=None):
    """Build clean welcome text (links go in buttons, not inline)."""
    if not join_date:
        join_date = datetime.datetime.now().strftime('%d/%m/%Y %H:%M')

    user_display = f"@{username}" if username else first_name or "Usuario"
    source_emoji = "📢 Canal" if source == "channel" else "💬 Grupo"

    text = (
        f"👑 *Bienvenido a MoviVIP Network!* 👑\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        f"👋 Hola *{first_name or 'Usuario'}*!\n"
        f"👤 Usuario: {user_display}\n"
        f"🆔 ID Telegram: `{tg_id}`\n"
        f"📅 Se unio: {join_date}\n"
        f"📍 Ubicacion: {source_emoji}\n\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        f"📋 *REGLAS DEL GRUPO:*\n\n"
        f"1️⃣ Respeta a todos los miembros\n"
        f"2️⃣ No spam ni publicidad\n"
        f"3️⃣ No compartir credenciales\n"
        f"4️⃣ Usa los bots para tus cuentas\n"
        f"5️⃣ Reporta con /report\n"
        f"6️⃣ No cobrar por cuentas GRATIS\n\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        f"⚡ *COMUNICADO OFICIAL:*\n\n"
        f"⚠️ Servidores duran *3 dias* por seguridad.\n"
        f"🔒 1 IP por cuenta. Hosts *$43.000 COP*.\n\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        f"👇 *Usa los botones de abajo para acceder a todo*\n\n"
        f"🙏 *Gracias por unirte!*"
    )
    return text


# =============================================================================
# WELCOME HANDLER
# =============================================================================
async def welcome_new_member(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle new members in groups/channels."""
    if not update.message or not update.message.new_chat_members:
        return

    for member in update.message.new_chat_members:
        if member.is_bot:
            continue

        chat = update.effective_chat
        source = "channel" if chat.type == "channel" else "group"
        join_date = datetime.datetime.now().strftime('%d/%m/%Y %H:%M')

        # Store in DB
        store_member(member.id, member.username, member.first_name, source)
        store_welcome(member.id, member.username, member.first_name,
                      source, chat.title, chat.id)

        # v5.0: BIENVENIDA CON FOTO SIEMPRE (arregla bug: antes solo
        # se enviaba el video/logo las 2 primeras veces). Usa file_id
        # persistente de DB → funciona ilimitadamente, sin archivo local.
        welcome_sent = False
        if _EXTRAS_OK:
            try:
                settings = get_welcome_settings()
                if settings.get("foto_file_id"):
                    html_text = build_movivip_html(member.first_name, member.username)
                    keyboard = get_welcome_keyboard()
                    ok, modo = await send_welcome_media_always(
                        context, chat.id, caption=html_text, reply_markup=keyboard)
                    if ok:
                        welcome_sent = True
                        logger.info(f"Welcome (foto-DB/{modo}) sent to {member.first_name} in {source}: {chat.title}")
            except Exception as e:
                logger.error(f"Welcome foto-DB error: {e}")

        # v4.0 fallback: video BIENVENIDA.mp4 + mensaje HTML MoviVIP
        if not welcome_sent:
            try:
                await send_welcome_video(context, chat.id, member.first_name, member.username)
                logger.info(f"Welcome sent to {member.first_name} in {source}: {chat.title}")
            except Exception as e:
                logger.error(f"Welcome error: {e}")
            # Fallback: logo + texto
            try:
                welcome_text = build_welcome_text(
                    member.first_name, member.username, member.id, source, join_date
                )
                keyboard = get_welcome_keyboard()
                if os.path.exists(LOGO_PATH):
                    with open(LOGO_PATH, 'rb') as photo:
                        await context.bot.send_photo(
                            chat_id=chat.id, photo=photo, caption=welcome_text,
                            parse_mode=ParseMode.MARKDOWN, reply_markup=keyboard)
                else:
                    await context.bot.send_message(
                        chat_id=chat.id, text=welcome_text,
                        parse_mode=ParseMode.MARKDOWN, reply_markup=keyboard)
            except Exception as e2:
                logger.error(f"Welcome fallback error: {e2}")


async def welcome_left_member(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Track users leaving."""
    if not update.message or not update.message.left_chat_member:
        return
    member = update.message.left_chat_member
    if member.is_bot:
        return
    try:
        db = get_db()
        db.execute("UPDATE community_members SET is_active=0 WHERE tg_id=?", (member.id,))
        db.commit()
        db.close()
    except:
        pass
    logger.info(f"User left: {member.first_name} ({member.id})")


# =============================================================================
# CHANNEL SUBSCRIBER HANDLER (ChatMember updates)
# Telegram channels DO NOT emit new_chat_members messages.
# The only way to detect new subscribers is via ChatMemberHandler.
# =============================================================================
async def channel_member_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Detect new subscribers to @MoviVIPNetwork and send welcome."""
    try:
        result = update.chat_member
        if not result:
            return

        chat = result.chat
        # Only for the main channel @MoviVIPNetwork
        channel_clean = CHANNEL_LINK.replace("https://t.me/", "").lower()
        chat_uname = chat.username.lower() if chat.username else ""
        if chat_uname != channel_clean:
            return

        old_status = result.old_chat_member.status if result.old_chat_member else ""
        new_status = result.new_chat_member.status if result.new_chat_member else ""

        # User joined (was left/kicked, now member/admin)
        if old_status in ("left", "kicked") and new_status in ("member", "administrator"):
            user = result.new_chat_member.user
            if not user or user.is_bot:
                return

            from datetime import datetime
            join_date = datetime.now().strftime('%d/%m/%Y %H:%M')
            source = "channel"

            # Store in DB
            store_member(user.id, user.username, user.first_name, source)
            store_welcome(user.id, user.username, user.first_name, source, chat.title, chat.id)

            # v4.0: video BIENVENIDA.mp4 + mensaje HTML MoviVIP
            try:
                await send_welcome_video(context, chat.id, user.first_name, user.username)
                logger.info(f"Channel welcome sent to {user.first_name} ({user.id})")
            except Exception as e:
                logger.error(f"Channel welcome send error: {e}")
                try:
                    welcome_text = build_welcome_text(
                        user.first_name, user.username, user.id, source, join_date
                    )
                    keyboard = get_welcome_keyboard()
                    await context.bot.send_message(
                        chat_id=chat.id, text=welcome_text,
                        parse_mode=ParseMode.MARKDOWN, reply_markup=keyboard)
                except Exception as e2:
                    logger.error(f"Channel welcome fallback error: {e2}")
    except Exception as e:
        logger.warning(f"channel_member_handler error: {e}")


# =============================================================================
# MENTION/TAG DETECTION
# =============================================================================
async def detect_mentions(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Detect mentions/tags and forward report to admin."""
    if not update.message:
        return

    msg = update.message
    chat = update.effective_chat
    user = update.effective_user

    if chat.type not in ('group', 'supergroup'):
        return

    text = msg.text or msg.caption or ""
    if not text:
        return

    has_mention = False
    report_type = 'mention'
    report_detail = ''

    # Check @username mentions
    if msg.entities:
        for entity in msg.entities:
            if entity.type == 'mention':
                has_mention = True
                mentioned = text[entity.offset:entity.offset + entity.length]
                report_detail += f"{mentioned} "
            elif entity.type == 'text_mention':
                has_mention = True
                report_detail += f"@{entity.user.first_name} "

    # Check reply
    if msg.reply_to_message:
        has_mention = True
        report_type = 'reply_report'
        replied_user = msg.reply_to_message.from_user
        report_detail = f"Reply to @{replied_user.username or replied_user.first_name}"

    # Check #report or /report
    if text.lower().startswith(('#report', '/report', 'reportar', 'reporte')):
        has_mention = True
        report_type = 'formal_report'
        report_detail = text[:200]

    if not has_mention:
        return

    # Store
    store_mention_report(
        reporter_id=user.id,
        reporter_name=user.first_name or '',
        reporter_username=user.username or '',
        message_text=text[:500],
        chat_id=chat.id,
        chat_title=chat.title or '',
        report_type=report_type
    )

    # Forward to admin(s)
    for admin_id in ADMIN_IDS:
        try:
            forward_text = (
                f"🔔 *REPORTE - {report_type.upper()}*\n"
                f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
                f"📍 Grupo: *{chat.title}*\n"
                f"👤 De: *{user.first_name or 'Unknown'}* (@{user.username or 'N/A'})\n"
                f"🆔 ID: `{user.id}`\n"
                f"📝 Tipo: {report_type}\n\n"
                f"💬 *Detalles:*\n{report_detail}\n\n"
                f"📨 *Mensaje:*\n{text[:500]}\n\n"
                f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
                f"🕐 {datetime.datetime.now().strftime('%d/%m/%Y %H:%M:%S')}"
            )
            await context.bot.send_message(
                chat_id=admin_id,
                text=forward_text,
                parse_mode=ParseMode.MARKDOWN
            )
        except Exception as e:
            logger.error(f"Forward report to admin {admin_id}: {e}")

    logger.info(f"Report: {report_type} by {user.first_name} in {chat.title}")


# =============================================================================
# ADMIN COMMANDS
# =============================================================================
async def cmd_start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Bot start command with inline buttons."""
    if not is_admin(update.effective_user.id):
        kb = InlineKeyboardMarkup([
            [InlineKeyboardButton("📁 Archivos .HC", callback_data="hc_menu")],
            [InlineKeyboardButton("🔑 Bot SSH", url=f"https://t.me/{SSH_BOT.replace('@','')}"),
             InlineKeyboardButton("🛒 Bot Tienda", url=f"https://t.me/{STORE_BOT.replace('@','')}")],
        ])
        await update.message.reply_text(
            "🤖 *MoviVIP Network Bot*\n\n"
            "👑 Bienvenido a la comunidad!\n\n"
            "📁 Descarga archivos *config .HC* de tu país\n"
            "viendo unos segundos de anuncios.\n\n"
            f"🌐 {SOCIAL['web']}",
            parse_mode=ParseMode.MARKDOWN, reply_markup=kb)
        return

    kb = [
        [InlineKeyboardButton("📊 Dashboard", callback_data="dash"),
         InlineKeyboardButton("👥 Members", callback_data="members")],
        [InlineKeyboardButton("🔔 Reports", callback_data="reports"),
         InlineKeyboardButton("📨 Welcomes", callback_data="welcomes")],
        [InlineKeyboardButton("📋 Full DB", callback_data="fulldb"),
         InlineKeyboardButton("📈 Stats", callback_data="stats")],
        [InlineKeyboardButton("📢 Enviar Comunicado", callback_data="send_official")],
        [InlineKeyboardButton("📁 Gestión .HC", callback_data="hc_menu"),
         InlineKeyboardButton("📤 Subir .HC", callback_data="hc_admin_upload")],
        [InlineKeyboardButton("🛡️ Baneos / Adblock", callback_data="adblock_menu")],
    ]

    # v5.0 — extras (bienvenida editable + promos) si están desplegados
    if _EXTRAS_OK:
        try:
            from notif_extras_ui import get_panel_extra_kb
            kb.extend(get_panel_extra_kb())
        except Exception as e:
            logger.error(f"Extras panel kb error: {e}")

    await update.message.reply_text(
        f"👑 *MoviVIP Notif Bot v4.0*\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        f"🔐 Panel de Administracion\n\n"
        f"📊 Dashboard en tiempo real\n"
        f"👥 Base de datos completa\n"
        f"🔔 Reportes y menciones\n"
        f"📨 Log de bienvenidas\n"
        f"📁 Archivos .HC por país\n\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
        parse_mode=ParseMode.MARKDOWN,
        reply_markup=InlineKeyboardMarkup(kb))


async def cmd_db(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Show full DB summary."""
    if not is_admin(update.effective_user.id):
        return

    db = get_db()
    c = db.cursor()

    tables_info = []
    for table in ['community_members', 'welcome_log', 'mention_reports', 'ssh_accounts', 'admins', 'ad_log']:
        try:
            count = c.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
            tables_info.append(f"📋 {table}: {count}")
        except:
            tables_info.append(f"📋 {table}: -")

    active = c.execute("SELECT COUNT(*) FROM community_members WHERE is_active=1").fetchone()[0]
    total = c.execute("SELECT COUNT(*) FROM community_members").fetchone()[0]
    channel_count = c.execute("SELECT COUNT(*) FROM community_members WHERE source='channel'").fetchone()[0]
    group_count = c.execute("SELECT COUNT(*) FROM community_members WHERE source='group'").fetchone()[0]
    reports = c.execute("SELECT COUNT(*) FROM mention_reports").fetchone()[0]

    recent = c.execute(
        "SELECT username, first_name, source, joined_at FROM community_members ORDER BY joined_at DESC LIMIT 5"
    ).fetchall()

    recent_reports = c.execute(
        "SELECT reporter_name, report_type, chat_title, created_at FROM mention_reports ORDER BY created_at DESC LIMIT 5"
    ).fetchall()

    db.close()

    text = (
        f"📊 *BASE DE DATOS*\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        f"👥 Total: {total} | Activos: {active}\n"
        f"📢 Canal: {channel_count} | 💬 Grupo: {group_count}\n"
        f"🔔 Reportes: {reports}\n\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        f"📋 *TABLAS:*\n"
    )
    for t in tables_info:
        text += f"  {t}\n"

    text += f"\n📅 *ULTIMOS 5 MIEMBROS:*\n"
    for r in recent:
        uname = f"@{r['username']}" if r['username'] else r['first_name']
        text += f"  • {uname} ({r['source']})\n"

    if recent_reports:
        text += f"\n🔔 *ULTIMOS 5 REPORTES:*\n"
        for r in recent_reports:
            text += f"  • {r['reporter_name']} - {r['report_type']}\n"

    kb = [[InlineKeyboardButton("🔄 Actualizar", callback_data="dash")]]
    await update.message.reply_text(text, parse_mode=ParseMode.MARKDOWN, reply_markup=InlineKeyboardMarkup(kb))


async def cmd_stats(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Show statistics."""
    if not is_admin(update.effective_user.id):
        return

    db = get_db()
    c = db.cursor()

    total = c.execute("SELECT COUNT(*) FROM community_members").fetchone()[0]
    active = c.execute("SELECT COUNT(*) FROM community_members WHERE is_active=1").fetchone()[0]
    ch = c.execute("SELECT COUNT(*) FROM community_members WHERE source='channel' AND is_active=1").fetchone()[0]
    gr = c.execute("SELECT COUNT(*) FROM community_members WHERE source='group' AND is_active=1").fetchone()[0]
    welcomes = c.execute("SELECT COUNT(*) FROM welcome_log").fetchone()[0]
    reports = c.execute("SELECT COUNT(*) FROM mention_reports").fetchone()[0]

    today = datetime.datetime.now().strftime('%Y-%m-%d')
    joins_today = c.execute("SELECT COUNT(*) FROM community_members WHERE joined_at LIKE ?", (f"{today}%",)).fetchone()[0]

    week_ago = (datetime.datetime.now() - datetime.timedelta(days=7)).strftime('%Y-%m-%d')
    joins_week = c.execute("SELECT COUNT(*) FROM community_members WHERE joined_at >= ?", (week_ago,)).fetchone()[0]

    try:
        ssh_total = c.execute("SELECT COUNT(*) FROM ssh_accounts").fetchone()[0]
        ssh_active = c.execute("SELECT COUNT(*) FROM ssh_accounts WHERE is_active=1").fetchone()[0]
    except:
        ssh_total = ssh_active = 0

    db.close()

    text = (
        f"📈 *ESTADISTICAS*\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        f"👥 Total: {total} | Activos: {active}\n"
        f"📢 Canal: {ch} | 💬 Grupo: {gr}\n\n"
        f"📅 Hoy: {joins_today} | Semana: {joins_week}\n\n"
        f"📨 Bienvenidas: {welcomes}\n"
        f"🔔 Reportes: {reports}\n"
        f"🔑 SSH: {ssh_total} ({ssh_active} activas)\n\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    )
    kb = [[InlineKeyboardButton("🔄 Actualizar", callback_data="stats")]]
    await update.message.reply_text(text, parse_mode=ParseMode.MARKDOWN, reply_markup=InlineKeyboardMarkup(kb))


async def cmd_members(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Show members."""
    if not is_admin(update.effective_user.id):
        return

    db = get_db()
    members = db.execute(
        "SELECT tg_id, username, first_name, source, joined_at, is_active "
        "FROM community_members ORDER BY joined_at DESC LIMIT 30"
    ).fetchall()
    db.close()

    if not members:
        await update.message.reply_text("📭 No hay miembros registrados.")
        return

    text = f"👥 *MIEMBROS* ({len(members)} ultimos)\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
    for m in members:
        status = "🟢" if m['is_active'] else "🔴"
        uname = f"@{m['username']}" if m['username'] else m['first_name']
        src = "📢" if m['source'] == 'channel' else "💬"
        text += f"{status} {src} *{uname}*\n"

    kb = [[InlineKeyboardButton("🔄 Actualizar", callback_data="members")]]
    await update.message.reply_text(text, parse_mode=ParseMode.MARKDOWN, reply_markup=InlineKeyboardMarkup(kb))


async def cmd_reports(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Show reports."""
    if not is_admin(update.effective_user.id):
        return

    db = get_db()
    reports = db.execute(
        "SELECT reporter_name, report_type, chat_title, message_text, created_at "
        "FROM mention_reports ORDER BY created_at DESC LIMIT 15"
    ).fetchall()
    db.close()

    if not reports:
        await update.message.reply_text("📭 No hay reportes.")
        return

    text = f"🔔 *REPORTES* ({len(reports)})\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
    for r in reports:
        text += f"👤 {r['reporter_name']} | {r['report_type']}\n📍 {r['chat_title']}\n💬 {r['message_text'][:80]}\n🕐 {r['created_at']}\n\n"

    kb = [[InlineKeyboardButton("🔄 Actualizar", callback_data="reports")]]
    await update.message.reply_text(text, parse_mode=ParseMode.MARKDOWN, reply_markup=InlineKeyboardMarkup(kb))


async def cmd_welcome_log(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Show welcome log."""
    if not is_admin(update.effective_user.id):
        return

    db = get_db()
    rows = db.execute(
        "SELECT tg_id, username, first_name, source, chat_title, welcomed_at "
        "FROM welcome_log ORDER BY welcomed_at DESC LIMIT 15"
    ).fetchall()
    db.close()

    if not rows:
        await update.message.reply_text("📭 No hay bienvenidas registradas.")
        return

    text = f"📨 *BIENVENIDAS* ({len(rows)})\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
    for r in rows:
        uname = f"@{r['username']}" if r['username'] else r['first_name']
        src = "📢" if r['source'] == 'channel' else "💬"
        text += f"{src} *{uname}* → {r['chat_title']}\n🕐 {r['welcomed_at']}\n\n"

    kb = [[InlineKeyboardButton("🔄 Actualizar", callback_data="welcomes")]]
    await update.message.reply_text(text, parse_mode=ParseMode.MARKDOWN, reply_markup=InlineKeyboardMarkup(kb))


async def cmd_preview(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Preview welcome v4.0: video BIENVENIDA.mp4 + mensaje HTML."""
    if not is_admin(update.effective_user.id):
        return

    tg_id = update.effective_user.id
    first_name = update.effective_user.first_name
    username = update.effective_user.username

    try:
        await send_welcome_video(context, update.effective_chat.id, first_name, username)
        await update.message.reply_text("✅ Preview v4.0 enviado (video + HTML).")
    except Exception as e:
        logger.error(f"Preview v4 error: {e}")
        # Fallback a preview clásico con logo
        welcome_text = build_welcome_text(first_name, username, tg_id, "group")
        keyboard = get_welcome_keyboard()
        try:
            if os.path.exists(LOGO_PATH):
                with open(LOGO_PATH, 'rb') as photo:
                    await context.bot.send_photo(
                        chat_id=update.effective_chat.id,
                        photo=photo, caption=welcome_text,
                        parse_mode=ParseMode.MARKDOWN, reply_markup=keyboard)
            else:
                await update.message.reply_text(welcome_text, parse_mode=ParseMode.MARKDOWN, reply_markup=keyboard)
        except Exception as e2:
            logger.error(f"Preview fallback error: {e2}")
            await update.message.reply_text(welcome_text, parse_mode=ParseMode.MARKDOWN, reply_markup=keyboard)


async def cmd_send_official(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Send official message."""
    if not is_admin(update.effective_user.id):
        return

    await update.message.reply_text("📢 Enviando comunicado oficial...")

    success = 0
    fail = 0

    for chat_id, name in [(CHANNEL_ID, "Canal"), (GROUP_ID, "Grupo")]:
        try:
            await context.bot.send_message(chat_id=chat_id, text=OFFICIAL_MSG, parse_mode=ParseMode.MARKDOWN)
            success += 1
            logger.info(f"Official msg sent to {name}")
        except Exception as e:
            fail += 1
            logger.error(f"Official msg to {name}: {e}")

    try:
        db = get_db()
        db.execute("INSERT INTO official_messages (sent_by, target, success_count, fail_count) VALUES (?,?,?,?)",
                   (update.effective_user.id, 'both', success, fail))
        db.commit()
        db.close()
    except:
        pass

    await update.message.reply_text(f"✅ Comunicado enviado!\n📊 Exitosos: {success} | Fallidos: {fail}")


# =============================================================================
# ADBLOCK / 3-STRIKE ADMIN COMMANDS
# =============================================================================
async def cmd_adblock_list(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Admin: lista usuarios con strikes por adblock."""
    if not is_admin(update.effective_user.id):
        return
    
    rows = adblock_get_all_strikes()
    if not rows:
        await update.message.reply_text("📭 No hay usuarios con strikes.")
        return
    
    text = "🛡️ <b>USUARIOS CON STRIKES ADBLOCK</b>\n"
    text += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
    
    for r in rows[:30]:
        status_emoji = {
            'active': '⚠️',
            'banned': '🚫',
            'unbanned_conditional': '⏳',
        }.get(r['status'], '❓')
        
        perm = " 🔒 PERMANENTE" if r['permanent_ban'] else ""
        text += (
            f"{status_emoji} <b>Strike {r['strikes']}/3</b> {r['status'].upper()}{perm}\n"
            f"👤 {r['first_name'] or 'N/A'} (@{r['username'] or 'N/A'})\n"
            f"🆔 <code>{r['user_id']}</code>\n"
            f"📅 1er strike: {r['first_strike_at'] or 'N/A'}\n"
            f"📅 Último: {r['last_strike_at'] or 'N/A'}\n"
            f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        )
    
    if len(rows) > 30:
        text += f"\n<i>... y {len(rows) - 30} más</i>"
    
    await update.message.reply_text(text, parse_mode=ParseMode.HTML)


async def cmd_adblock_unban(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Admin: desbanea usuario. /adblock_unban <user_id> [conditional|total] [razón]"""
    if not is_admin(update.effective_user.id):
        return
    
    if not context.args:
        await update.message.reply_text(
            "❌ Uso: <code>/adblock_unban <user_id> [conditional|total] [razón]</code>\n\n"
            "<b>conditional</b> (default): 1 strike restante, si reincide → ban permanente\n"
            "<b>total</b>: elimina registro completamente",
            parse_mode=ParseMode.HTML)
        return
    
    try:
        user_id = int(context.args[0])
    except:
        await update.message.reply_text("❌ user_id inválido")
        return
    
    mode = 'conditional'
    reason = ""
    if len(context.args) >= 2:
        if context.args[1].lower() in ('total', 'conditional'):
            mode = context.args[1].lower()
        else:
            reason = ' '.join(context.args[1:])
    if len(context.args) >= 3:
        reason = ' '.join(context.args[2:])
    
    conditional = (mode == 'conditional')
    success, msg = adblock_unban(user_id, update.effective_user.id, reason, conditional)
    
    if success:
        await update.message.reply_text(f"✅ {msg}")
    else:
        await update.message.reply_text(f"❌ {msg}")


async def cmd_adblock_ban(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Admin: banea manualmente a un usuario (3 strikes directo). /adblock_ban <user_id> [razón]"""
    if not is_admin(update.effective_user.id):
        return
    
    if not context.args:
        await update.message.reply_text("❌ Uso: <code>/adblock_ban <user_id> [razón]</code>", parse_mode=ParseMode.HTML)
        return
    
    try:
        user_id = int(context.args[0])
    except:
        await update.message.reply_text("❌ user_id inválido")
        return
    
    reason = ' '.join(context.args[1:]) if len(context.args) > 1 else "Baneo manual por admin"
    
    # Añadir 3 strikes directo
    try:
        db = get_db()
        row = db.execute("SELECT username, first_name FROM community_members WHERE tg_id=?", (user_id,)).fetchone()
        username = row['username'] if row else ''
        first_name = row['first_name'] if row else ''
        now = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        
        db.execute("""INSERT OR REPLACE INTO adblock_strikes 
            (user_id, username, first_name, strikes, status, first_strike_at, last_strike_at, banned_at, permanent_ban, unban_reason)
            VALUES (?, ?, ?, 3, 'banned', ?, ?, ?, 1, ?)""",
            (user_id, username, first_name, now, now, now, reason))
        db.commit()
        db.close()
        
        # Notificar al usuario
        try:
            send_telegram_msg(user_id,
                f"🚫 <b>BLOQUEO PERMANENTE - ADBLOCK</b>\n"
                f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
                f"Has sido bloqueado por uso de bloqueador de anuncios.\n"
                f"Razón: {reason}\n\n"
                f"🔒 No puedes crear SSH ni obtener .HC.\n"
                f"Contacta a @MoviVIP si crees que es error.",
                parse_mode=ParseMode.HTML)
        except:
            pass
        
        await update.message.reply_text(f"✅ Usuario {user_id} baneado manualmente (3 strikes).")
    except Exception as e:
        await update.message.reply_text(f"❌ Error: {e}")


async def cmd_adblock_help(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Ayuda comandos adblock."""
    if not is_admin(update.effective_user.id):
        return
    
    await update.message.reply_text(
        "🛡️ <b>ADBLOCK / 3-STRIKE COMANDOS ADMIN</b>\n"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        "<b>/adblock_list</b> — Lista usuarios con strikes\n"
        "<b>/adblock_unban <user_id> [conditional|total] [razón]</b> — Desbanear\n"
        "  <i>conditional (default): 1 strike restante, reincidencia = ban permanente</i>\n"
        "  <i>total: elimina registro completo</i>\n"
        "<b>/adblock_ban <user_id> [razón]</b> — Banear manual (3 strikes)\n\n"
        "<b>Ejemplos:</b>\n"
        "<code>/adblock_unban 123456789 conditional Se portó bien</code>\n"
        "<code>/adblock_unban 123456789 total</code>\n"
        "<code>/adblock_ban 123456789 Adblock detectado</code>\n\n"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
        parse_mode=ParseMode.HTML)


async def cmd_help(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Help command."""
    if not is_admin(update.effective_user.id):
        await update.message.reply_text(
            "🤖 *MoviVIP Notification Bot*\n\n"
            "Notificaciones y reportes de MoviVIP Network.\n"
            f"🌐 {SOCIAL['web']}",
            parse_mode=ParseMode.MARKDOWN
        )
        return

    await update.message.reply_text(
        f"👑 *MoviVIP Notif Bot v4.0*\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        f"📊 /db - Base de datos\n"
        f"📈 /stats - Estadisticas\n"
        f"👥 /members - Miembros\n"
        f"🔔 /reports - Reportes\n"
        f"📨 /welcomes - Log bienvenidas\n"
        f"👁️ /preview - Preview welcome\n"
        f"📢 /official - Enviar comunicado\n\n"
        f"📁 *ARCHIVOS .HC:*\n"
        f"📥 /hc - Menú público por país\n"
        f"📤 /subirhc - Subir archivo\n"
        f"📋 /listhc - Listar archivos\n"
        f"🗑️ /delhc <id> - Desactivar archivo\n\n"
        f"❓ /help - Ayuda\n\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
        parse_mode=ParseMode.MARKDOWN)


# =============================================================================
# ARCHIVOS .HC — COMANDOS ADMIN (subir / listar / eliminar)
# =============================================================================
async def cmd_cancelar_hc(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Admin: cancela una subida .HC en curso."""
    if not is_admin(update.effective_user.id):
        return
    if context.user_data.pop('hc_upload', None):
        await update.message.reply_text("❌ Subida cancelada.")
    else:
        await update.message.reply_text("No hay ninguna subida en curso.")


async def handle_hc_days_text(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Admin: recibe texto durante la subida .HC (días / límite / usuario)."""
    user = update.effective_user
    if not user or not is_admin(user.id):
        return
    state = context.user_data.get('hc_upload')
    if not state:
        return

    step = state.get('step')
    if step == 'hc_user':
        await handle_hc_user_text(update, context)
        return
    if step == 'max_users_custom':
        await _handle_hc_max_users_custom_text(update, context)
        return
    if step == 'devices_pool_custom':
        await _handle_hc_devices_pool_custom_text(update, context)
        return
    if step != 'days_custom':
        return

    text = (update.message.text or '').strip()
    if not text.isdigit():
        await update.message.reply_text("❌ Escribe un número válido (1 a 90). Ej: 15")
        return
    days = max(1, min(int(text), 90))

    # Paso 5: preguntar el LÍMITE de usuarios del pool
    state = context.user_data.get('hc_upload')
    if not state:
        await update.message.reply_text("⏳ La subida expiró. Usa /subirhc de nuevo.")
        return
    state['days'] = days
    state['step'] = 'max_users'
    kb = [
        [InlineKeyboardButton("10", callback_data="hc_up_max_10"),
         InlineKeyboardButton("20", callback_data="hc_up_max_20"),
         InlineKeyboardButton("30", callback_data="hc_up_max_30")],
        [InlineKeyboardButton("50", callback_data="hc_up_max_50"),
         InlineKeyboardButton("100", callback_data="hc_up_max_100"),
         InlineKeyboardButton("✏️ Otro (escribe el número)", callback_data="hc_up_max_custom")],
        [InlineKeyboardButton("❌ Cancelar", callback_data="hc_up_cancel")],
    ]
    await update.message.reply_text(
        f"📄 *Archivo:* `{emd(state['label'])}`\n"
        f"📅 Días: *{days}*\n\n"
        "5️⃣ ¿Cuántos *usuarios (límite)* tiene este archivo?\n"
        "Es el tope de entregas del pool. Si varios archivos usan el "
        "MISMO usuario+pass, comparten este límite entre todos.\n\n"
        "Selecciona una opción o escribe el número:\n\n"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
        parse_mode=ParseMode.MARKDOWN, reply_markup=InlineKeyboardMarkup(kb))


async def _hc_max_users_chosen(query, context, value):
    """Paso 6: preguntar el usuario SSH (opcional) para agrupar el pool."""
    state = context.user_data.get('hc_upload')
    if not state or state.get('step') != 'max_users':
        await query.answer("⏳ La subida expiró. Vuelve a usar /subirhc.", show_alert=True)
        return
    if not is_admin(query.from_user.id):
        await query.answer("❌ No eres admin.", show_alert=True)
        return

    if value == 'custom':
        state['step'] = 'max_users_custom'
        await query.edit_message_text(
            f"✏️ Escribe el *límite de usuarios* (número):\n\n"
            f"📄 Archivo: `{emd(state['label'])}`\n"
            "❌ /cancelar_hc para cancelar",
            parse_mode=ParseMode.MARKDOWN)
        return

    try:
        max_users = max(1, int(value))
    except Exception:
        await query.answer("❌ Límite inválido.", show_alert=True)
        return
    state['max_users'] = max_users
    state['step'] = 'devices_pool'

    kb = [
        [InlineKeyboardButton("10", callback_data="hc_up_dev_10"),
         InlineKeyboardButton("25", callback_data="hc_up_dev_25"),
         InlineKeyboardButton("50", callback_data="hc_up_dev_50")],
        [InlineKeyboardButton("100", callback_data="hc_up_dev_100"),
         InlineKeyboardButton("250", callback_data="hc_up_dev_250"),
         InlineKeyboardButton("✏️ Otro (escribe el número)", callback_data="hc_up_dev_custom")],
        [InlineKeyboardButton("❌ Cancelar", callback_data="hc_up_cancel")],
    ]
    await query.edit_message_text(
        f"📄 *Archivo:* `{emd(state['label'])}`\n"
        f"📅 Días: *{state['days']}*\n"
        f"🔢 Límite de usuarios: *{max_users}*\n\n"
        "6️⃣ ¿Cuántos *dispositivos en total* soporta este archivo?\n"
        "Es el número de dispositivos (celulares/PC) disponibles en el pool. "
        "Cada entrega resta sus dispositivos de aquí. Te avisaré cuando queden "
        "*≤5 disponibles* para que subas archivos nuevos.\n\n"
        "Selecciona una opción o escribe el número:\n\n"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
        parse_mode=ParseMode.MARKDOWN, reply_markup=InlineKeyboardMarkup(kb))


async def _handle_hc_max_users_custom_text(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Admin: recibe el límite de usuarios escrito manualmente."""
    text = (update.message.text or '').strip()
    if not text.isdigit():
        await update.message.reply_text("❌ Escribe un número válido (mínimo 1). Ej: 25")
        return
    max_users = max(1, int(text))
    state = context.user_data.get('hc_upload')
    if not state:
        await update.message.reply_text("⏳ La subida expiró. Usa /subirhc de nuevo.")
        return
    state['max_users'] = max_users
    state['step'] = 'devices_pool'

    kb = [
        [InlineKeyboardButton("10", callback_data="hc_up_dev_10"),
         InlineKeyboardButton("25", callback_data="hc_up_dev_25"),
         InlineKeyboardButton("50", callback_data="hc_up_dev_50")],
        [InlineKeyboardButton("100", callback_data="hc_up_dev_100"),
         InlineKeyboardButton("250", callback_data="hc_up_dev_250"),
         InlineKeyboardButton("✏️ Otro (escribe el número)", callback_data="hc_up_dev_custom")],
        [InlineKeyboardButton("❌ Cancelar", callback_data="hc_up_cancel")],
    ]
    await update.message.reply_text(
        f"📄 *Archivo:* `{emd(state['label'])}`\n"
        f"📅 Días: *{state['days']}*\n"
        f"🔢 Límite de usuarios: *{max_users}*\n\n"
        "6️⃣ ¿Cuántos *dispositivos en total* soporta este archivo?\n"
        "Es el número de dispositivos (celulares/PC) disponibles en el pool. "
        "Cada entrega resta sus dispositivos de aquí. Te avisaré cuando queden "
        "*≤5 disponibles* para que subas archivos nuevos.\n\n"
        "Selecciona una opción o escribe el número:\n\n"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
        parse_mode=ParseMode.MARKDOWN, reply_markup=InlineKeyboardMarkup(kb))


async def _safe_edit(query, text, kb=None, context=None):
    """Edita con Markdown; si falla parse, reintenta sin formato."""
    try:
        await query.edit_message_text(
            text,
            parse_mode=ParseMode.MARKDOWN,
            reply_markup=InlineKeyboardMarkup(kb) if kb else None)
    except Exception as e:
        logger.warning(f"Markdown edit failed, retrying plain: {e}")
        try:
            await query.edit_message_text(
                text,
                parse_mode=None,
                reply_markup=InlineKeyboardMarkup(kb) if kb else None)
        except Exception as e2:
            logger.error(f"Plain edit also failed: {e2}")
            if context:
                await query.answer("❌ Error al actualizar mensaje.", show_alert=True)


async def _hc_devices_pool_chosen(query, context, value):
    """Paso 7: preguntar el usuario SSH (opcional) para agrupar el pool."""
    state = context.user_data.get('hc_upload')
    if not state or state.get('step') != 'devices_pool':
        await query.answer("⏳ La subida expiró. Vuelve a usar /subirhc.", show_alert=True)
        return
    if not is_admin(query.from_user.id):
        await query.answer("❌ No eres admin.", show_alert=True)
        return

    if value == 'custom':
        state['step'] = 'devices_pool_custom'
        await _safe_edit(query,
            f"✏️ Escribe el *total de dispositivos* (número):\n\n"
            f"📄 Archivo: `{emd(state['label'])}`\n"
            "❌ /cancelar_hc para cancelar",
            context=context)
        return

    try:
        devices_pool = max(1, int(value))
    except Exception:
        await query.answer("❌ Número inválido.", show_alert=True)
        return
    state['devices_pool'] = devices_pool
    state['step'] = 'hc_user'

    kb = [
        [InlineKeyboardButton("⏭️ Saltar (pool propio del archivo)", callback_data="hc_up_user_skip")],
        [InlineKeyboardButton("❌ Cancelar", callback_data="hc_up_cancel")],
    ]
    await _safe_edit(query,
        f"📄 *Archivo:* `{emd(state['label'])}`\n"
        f"📅 Días: *{state['days']}*\n"
        f"🔢 Límite de usuarios: *{state.get('max_users')}*\n"
        f"📱 Dispositivos (pool): *{devices_pool}*\n\n"
        "7️⃣ ¿Cuál es el *usuario SSH* de este archivo? *(opcional)*\n\n"
        "⚠️ *No se crea ningún usuario en el servidor.* Es solo para "
        "AGRUPAR el límite: si creas varios archivos con el *mismo usuario*, "
        "escríbelo aquí y compartirán el límite entre todos.\n"
        "Si no lo indicas, cada archivo tendrá su propio límite.\n\n"
        "Escríbelo aquí o toca *Saltar*:\n\n"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
        kb=kb, context=context)


async def _handle_hc_devices_pool_custom_text(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Admin: recibe el total de dispositivos escrito manualmente."""
    text = (update.message.text or '').strip()
    if not text.isdigit():
        await update.message.reply_text("❌ Escribe un número válido (mínimo 1). Ej: 120")
        return
    devices_pool = max(1, int(text))
    state = context.user_data.get('hc_upload')
    if not state:
        await update.message.reply_text("⏳ La subida expiró. Usa /subirhc de nuevo.")
        return
    state['devices_pool'] = devices_pool
    state['step'] = 'hc_user'

    kb = [
        [InlineKeyboardButton("⏭️ Saltar (pool propio del archivo)", callback_data="hc_up_user_skip")],
        [InlineKeyboardButton("❌ Cancelar", callback_data="hc_up_cancel")],
    ]
    text = (
        f"📄 *Archivo:* `{emd(state['label'])}`\n"
        f"📅 Días: *{state['days']}*\n"
        f"🔢 Límite de usuarios: *{state.get('max_users')}*\n"
        f"📱 Dispositivos (pool): *{devices_pool}*\n\n"
        "7️⃣ ¿Cuál es el *usuario SSH* de este archivo? *(opcional)*\n\n"
        "⚠️ *No se crea ningún usuario en el servidor.* Es solo para "
        "AGRUPAR el límite: si creas varios archivos con el *mismo usuario*, "
        "escríbelo aquí y compartirán el límite entre todos.\n"
        "Si no lo indicas, cada archivo tendrá su propio límite.\n\n"
        "Escríbelo aquí o toca *Saltar*:\n\n"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    try:
        await update.message.reply_text(text, parse_mode=ParseMode.MARKDOWN, reply_markup=InlineKeyboardMarkup(kb))
    except Exception as e:
        logger.warning(f"Markdown reply failed, retrying plain: {e}")
        await update.message.reply_text(text, parse_mode=None, reply_markup=InlineKeyboardMarkup(kb))


async def handle_hc_user_text(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Admin: recibe el usuario SSH escrito manualmente (o salta)."""
    user = update.effective_user
    if not user or not is_admin(user.id):
        return
    state = context.user_data.get('hc_upload')
    if not state or state.get('step') != 'hc_user':
        return

    hc_user = (update.message.text or '').strip()
    if len(hc_user) > 40:
        await update.message.reply_text("❌ Usuario demasiado largo (máx 40).")
        return
    state['hc_user'] = hc_user

    entry = await _finish_hc_upload(context, state.get('days') or 7)
    if not entry:
        await update.message.reply_text("⏳ La subida expiró. Usa /subirhc de nuevo.")
        return
    kb = [[InlineKeyboardButton("📁 Ver menú .HC", callback_data="hc_menu")]]
    text = (
        f"✅ *Archivo .HC guardado!*\n"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        f"📄 Nombre: `{emd(entry['label'])}`\n"
        f"📍 País: *{emd(COUNTRIES.get(entry['country'], {}).get('name', entry['country'].upper()))}*\n"
        f"📶 Operadora: *{emd(carrier_name(entry))}*\n"
        f"📅 Días: *{entry['days']}*\n"
        f"🔢 Límite: *{entry.get('max_users', HC_DEFAULT_MAX_USERS)} usuarios*\n"
        f"📱 Dispositivos (pool): *{entry.get('devices_pool', entry.get('max_users', HC_DEFAULT_MAX_USERS) * 5)}*"
        + (f"\n👤 Usuario SSH: `{emd(entry.get('hc_user', ''))}`" if entry.get('hc_user') else "")
        + f"\n📅 Expira: `{emd(entry['expires_at'])}`\n"
        f"🆔 ID: `{entry['id']}`\n\n"
        "Ya está disponible en el menú público /hc\n\n"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    try:
        await update.message.reply_text(text, parse_mode=ParseMode.MARKDOWN, reply_markup=InlineKeyboardMarkup(kb))
    except Exception as e:
        logger.warning(f"Markdown reply failed, retrying plain: {e}")
        await update.message.reply_text(text, parse_mode=None, reply_markup=InlineKeyboardMarkup(kb))


async def cmd_subirhc(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Admin: subir archivo .HC (paso 1: elegir país)."""
    if not is_admin(update.effective_user.id):
        return
    kb = []
    for code, info in COUNTRIES.items():
        kb.append([InlineKeyboardButton(
            f"{info['flag']} {info['name']}", callback_data=f"hc_up_{code}")])
    kb.append([InlineKeyboardButton("❌ Cancelar", callback_data="hc_up_cancel")])
    context.user_data['hc_upload'] = {'step': 'country'}
    await update.message.reply_text(
        "📤 *SUBIR ARCHIVO .HC*\n"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        "1️⃣ Selecciona el país del archivo:\n\n"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
        parse_mode=ParseMode.MARKDOWN, reply_markup=InlineKeyboardMarkup(kb))


async def _callback_hc_up(query, context, code):
    """Paso 2: preguntar la OPERADORA del archivo .hc."""
    context.user_data['hc_upload'] = {'step': 'carrier', 'country': code}
    name = COUNTRIES.get(code, {}).get('name', code.upper())
    kb = []
    for ccode, cinfo in CARRIERS_CO.items():
        kb.append([InlineKeyboardButton(
            f"{cinfo['icon']} {cinfo['name']}", callback_data=f"hc_up_carrier_{ccode}")])
    kb.append([InlineKeyboardButton(
        "📦 Otros / Sin operadora", callback_data="hc_up_carrier_otros")])
    kb.append([InlineKeyboardButton("🔙 Cambiar país", callback_data="hc_up_backcountry"),
               InlineKeyboardButton("❌ Cancelar", callback_data="hc_up_cancel")])
    await query.edit_message_text(
        f"📤 *SUBIR ARCHIVO .HC*\n"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        f"📍 País: *{name}*\n\n"
        "2️⃣ ¿A qué *operadora* pertenece el archivo?\n\n"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
        parse_mode=ParseMode.MARKDOWN, reply_markup=InlineKeyboardMarkup(kb))


async def _callback_hc_up_carrier(query, context, carrier):
    """Paso 3: pedir el documento .hc después de elegir operadora."""
    state = context.user_data.get('hc_upload')
    if not state or state.get('step') != 'carrier':
        await query.answer("⏳ La subida expiró. Usa /subirhc.", show_alert=True)
        return
    if not is_admin(query.from_user.id):
        await query.answer("❌ No eres admin.", show_alert=True)
        return

    state['step'] = 'doc'
    state['carrier'] = None if carrier == 'otros' else carrier
    name = COUNTRIES.get(state.get('country', 'co'), {}).get('name', '')
    carrier_name = 'Otros' if carrier == 'otros' else CARRIERS_CO.get(carrier, {}).get('name', carrier)
    await query.edit_message_text(
        f"📤 *SUBIR ARCHIVO .HC*\n"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        f"📍 País: *{emd(name)}*\n"
        f"📶 Operadora: *{emd(carrier_name)}*\n\n"
        "3️⃣ Envía el archivo *.hc* ahora\n"
        "(documento con extensión .hc)\n\n"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
        parse_mode=ParseMode.MARKDOWN)


async def _callback_hc_up_backcountry(query, context):
    """Vuelve al paso 1 (país) desde la selección de operadora."""
    context.user_data['hc_upload'] = {'step': 'country'}
    kb = []
    for code, info in COUNTRIES.items():
        kb.append([InlineKeyboardButton(
            f"{info['flag']} {info['name']}", callback_data=f"hc_up_{code}")])
    kb.append([InlineKeyboardButton("❌ Cancelar", callback_data="hc_up_cancel")])
    await query.edit_message_text(
        "📤 *SUBIR ARCHIVO .HC*\n"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        "1️⃣ Selecciona el país del archivo:\n\n"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
        parse_mode=ParseMode.MARKDOWN, reply_markup=InlineKeyboardMarkup(kb))


async def _callback_hc_up_quick(query, context, carrier):
    """Subida rápida (Colombia + operadora predefinida) desde la
    notificación de expiración. Pide directamente el documento .hc."""
    state = context.user_data.get('hc_upload')
    if state and state.get('step') not in (None, 'days', 'days_custom'):
        await query.answer("Ya tienes una subida en curso. Termínala o usa /cancelar_hc.", show_alert=True)
        return
    context.user_data['hc_upload'] = {
        'step': 'doc',
        'country': 'co',
        'carrier': None if carrier == 'otros' else carrier,
    }
    cname = 'Otros' if carrier == 'otros' else CARRIERS_CO.get(carrier, {}).get('name', carrier)
    await query.edit_message_text(
        f"📤 *SUBIR ARCHIVO .HC (rápido)*\n"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        f"📍 País: *Colombia*\n"
        f"📶 Operadora: *{emd(cname)}*\n\n"
        "3️⃣ Envía el archivo *.hc* ahora\n"
        "(documento con extensión .hc)\n\n"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
        parse_mode=ParseMode.MARKDOWN)


async def handle_hc_document(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Admin: recibe el documento .hc y lo registra con su país."""
    user = update.effective_user
    if not user or not is_admin(user.id):
        return
    state = context.user_data.get('hc_upload')
    if not state or state.get('step') != 'doc':
        return

    doc = update.message.document
    if not doc:
        return
    if not doc.file_name.lower().endswith('.hc'):
        await update.message.reply_text("❌ Solo se aceptan archivos con extensión *.hc*")
        return

    country = state.get('country', 'co')
    try:
        os.makedirs(HC_FREE_DIR, exist_ok=True)
        # Conserva emojis y caracteres unicode del nombre original;
        # solo se reemplazan separadores de ruta y caracteres de control
        safe = re.sub(r'[/\\\x00-\x1f\x7f]', '_', doc.file_name).strip()
        if not safe:
            safe = 'archivo.hc'
        if len(safe) > 120:
            safe = safe[-120:]
        safe_name = safe if safe.lower().endswith('.hc') else f"{safe}.hc"
        file_path = os.path.join(HC_FREE_DIR, safe_name)

        tg_file = await context.bot.get_file(doc.file_id)
        await tg_file.download_to_drive(file_path)
    except Exception as e:
        logger.error(f"HC document download error: {e}")
        await update.message.reply_text("❌ Error descargando el archivo. Intenta de nuevo.")
        return

    # Label visible con emojis: conserva los del nombre + bandera del país
    # si el nombre termina con un código (co/pe/ar...) + emoji usual de la
    # operadora si el nombre no tiene ningún emoji.
    label = build_hc_label(safe_name, state.get('carrier'))

    # Guardar en estado pendiente y PREGUNTAR los días
    context.user_data['hc_upload'] = {
        'step': 'days',
        'country': country,
        'carrier': state.get('carrier'),
        'file_path': file_path,
        'file_name': safe_name,
        'label': label,
    }

    carrier_name = 'Otros' if not state.get('carrier') else CARRIERS_CO.get(state.get('carrier'), {}).get('name', state.get('carrier'))
    kb = [
        [InlineKeyboardButton("1 día", callback_data="hc_up_days_1"),
         InlineKeyboardButton("3 días", callback_data="hc_up_days_3"),
         InlineKeyboardButton("7 días", callback_data="hc_up_days_7")],
        [InlineKeyboardButton("15 días", callback_data="hc_up_days_15"),
         InlineKeyboardButton("30 días", callback_data="hc_up_days_30"),
         InlineKeyboardButton("60 días", callback_data="hc_up_days_60")],
        [InlineKeyboardButton("90 días", callback_data="hc_up_days_90"),
         InlineKeyboardButton("✏️ Otro (escribe el número)", callback_data="hc_up_days_custom")],
        [InlineKeyboardButton("❌ Cancelar", callback_data="hc_up_cancel")],
    ]
    await update.message.reply_text(
        f"📄 *Archivo recibido:* `{emd(label)}`\n"
        f"📍 País: *{emd(COUNTRIES.get(country, {}).get('name', country.upper()))}*\n"
        f"📶 Operadora: *{emd(carrier_name)}*\n\n"
        "4️⃣ ¿Cuántos *días* de duración tendrá?\n"
        "Selecciona una opción o escribe el número exacto:\n\n"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
        parse_mode=ParseMode.MARKDOWN, reply_markup=InlineKeyboardMarkup(kb))


async def _finish_hc_upload(context, days: int):
    """Completa el registro del .HC pendiente con los días elegidos."""
    state = context.user_data.get('hc_upload')
    if not state or state.get('step') not in ('days', 'hc_user'):
        return None
    try:
        days = max(1, min(int(days), 90))
    except Exception:
        days = 7

    data = load_hc_data()
    new_id = max([e.get('id', 0) for e in data], default=0) + 1
    now = datetime.datetime.now()
    expiry = (now + datetime.timedelta(days=days)).strftime('%Y-%m-%d %H:%M:%S')

    # Límite de entregas del pool: el admin lo define al subir (default 20).
    # Si 'hc_user' está definido, TODOS los archivos con el MISMO usuario SSH
    # comparten un único pool contra 'max_users' (ej: 3 archivos con el mismo
    # user+pass → entre los 3 se entregan max_users personas en total).
    max_users = int(state.get('max_users') or HC_DEFAULT_MAX_USERS)
    hc_user = (state.get('hc_user') or '').strip()
    devices_pool = int(state.get('devices_pool') or max_users * 5)

    entry = {
        'id': new_id,
        'file_path': state['file_path'],
        'file_name': state['file_name'],
        'label': state['label'],
        'country': state['country'],
        'carrier': state.get('carrier'),
        'days': days,
        'max_users': max_users,
        'devices_pool': devices_pool,
        'devices_used': 0,
        'low_notified': False,
        'hc_user': hc_user,
        'created_at': now.strftime('%Y-%m-%d %H:%M:%S'),
        'expires_at': expiry,
        'last_sent_at': '',
        'send_count': 0,
        'active': True,
    }
    data.append(entry)
    save_hc_data(data)
    context.user_data.pop('hc_upload', None)
    return entry


def _parse_hc_expiry(s):
    """Parsea expires_at soportando formato con hora y solo fecha."""
    if not s:
        return None
    for fmt in ('%Y-%m-%d %H:%M:%S', '%Y-%m-%d %H:%M', '%Y-%m-%d'):
        try:
            dt = datetime.datetime.strptime(s, fmt)
            if fmt == '%Y-%m-%d':  # solo fecha → expira al final de ese día
                dt = dt.replace(hour=23, minute=59, second=59)
            return dt
        except Exception:
            continue
    return None


async def check_hc_expiry(context: ContextTypes.DEFAULT_TYPE):
    """Cada 30 min:
    1) Notifica al admin el MISMO DÍA que un archivo .HC vence (para subir
       los nuevos de esa operadora), con botón de subida rápida.
    2) ELIMINA de la VPS el archivo .HC una vez vencido y avisa."""
    now = datetime.datetime.now()
    today = now.date()
    data = load_hc_data()
    changed = False

    for e in data:
        if not e.get('active', True):
            continue
        expires = _parse_hc_expiry(e.get('expires_at'))
        if not expires:
            continue

        # 1) Notificar el mismo día de expiración (aún no vencido)
        if (expires.date() == today and expires > now
                and not e.get('expiry_notified')):
            e['expiry_notified'] = True
            changed = True
            label = e.get('label') or e.get('file_name', '')
            country_name = COUNTRIES.get(e.get('country', 'co'),
                                         {}).get('name', e.get('country', 'co'))
            c = e.get('carrier') or get_carrier_from_name(e.get('file_name', ''))
            carrier_name_txt = 'Otros' if not c else CARRIERS_CO.get(c, {}).get('name', c)
            kb = [[InlineKeyboardButton(
                f"📤 Subir nuevos de {carrier_name_txt}",
                callback_data=f"hc_up_quick_{c or 'otros'}")]]
            for admin_id in ADMIN_IDS:
                try:
                    await context.bot.send_message(
                        admin_id,
                        f"⚠️ *ARCHIVO .HC EXPIRA HOY*\n"
                        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
                        f"📄 Archivo: `{emd(label)}`\n"
                        f"📍 País: *{emd(country_name)}*\n"
                        f"📶 Operadora: *{emd(carrier_name_txt)}*\n"
                        f"🕐 Vence a las *{expires.strftime('%H:%M')}* "
                        f"({expires.strftime('%d/%m/%Y')})\n\n"
                        "Sube los archivos nuevos de esta operadora para "
                        "que no se quede sin stock.\n\n"
                        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
                        parse_mode=ParseMode.MARKDOWN,
                        reply_markup=InlineKeyboardMarkup(kb))
                except Exception as ex:
                    logger.error(f"HC expiry notify error: {ex}")

        # 2) Eliminar de la VPS si ya venció
        if expires <= now:
            fp = e.get('file_path', '')
            if fp and os.path.exists(fp):
                try:
                    os.remove(fp)
                    logger.info(f"HC removed expired file: {fp}")
                except Exception as ex:
                    logger.error(f"HC remove file error: {ex}")
            e['active'] = False
            e['removed_at'] = now.strftime('%Y-%m-%d %H:%M:%S')
            changed = True
            label = e.get('label') or e.get('file_name', '')
            for admin_id in ADMIN_IDS:
                try:
                    await context.bot.send_message(
                        admin_id,
                        f"🗑️ *ARCHIVO .HC ELIMINADO (vencido)*\n"
                        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
                        f"📄 Archivo: `{emd(label)}`\n"
                        f"📍 País: *{emd(COUNTRIES.get(e.get('country', 'co'), {}).get('name', e.get('country', 'co')))}*\n"
                        f"📶 Operadora: *{emd(carrier_name(e))}*\n\n"
                        "🗑️ Eliminado de la VPS.\n"
                        "Usa /subirhc para subir los nuevos.\n\n"
                        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
                        parse_mode=ParseMode.MARKDOWN)
                except Exception as ex:
                    logger.error(f"HC removed notify error: {ex}")

    if changed:
        save_hc_data(data)


async def _hc_days_chosen(query, context, days_str):
    """Callback: días elegidos → guarda el archivo y confirma."""
    state = context.user_data.get('hc_upload')
    if not state or state.get('step') != 'days':
        await query.answer("⏳ La subida expiró. Vuelve a usar /subirhc.", show_alert=True)
        return
    if not is_admin(query.from_user.id):
        await query.answer("❌ No eres admin.", show_alert=True)
        return

    if days_str == 'custom':
        context.user_data['hc_upload']['step'] = 'days_custom'
        await query.edit_message_text(
            f"✏️ Escribe el número de *días* (1 a 90):\n\n"
            f"📄 Archivo: `{emd(state['label'])}`\n"
            "❌ /cancelar_hc para cancelar",
            parse_mode=ParseMode.MARKDOWN)
        return

    try:
        days = int(days_str)
    except Exception:
        await query.answer("❌ Días inválidos.", show_alert=True)
        return

    # Paso 5: preguntar el LÍMITE de usuarios del pool
    state = context.user_data.get('hc_upload')
    if not state:
        await query.answer("⏳ La subida expiró.", show_alert=True)
        return
    state['days'] = days
    state['step'] = 'max_users'
    kb = [
        [InlineKeyboardButton("10", callback_data="hc_up_max_10"),
         InlineKeyboardButton("20", callback_data="hc_up_max_20"),
         InlineKeyboardButton("30", callback_data="hc_up_max_30")],
        [InlineKeyboardButton("50", callback_data="hc_up_max_50"),
         InlineKeyboardButton("100", callback_data="hc_up_max_100"),
         InlineKeyboardButton("✏️ Otro (escribe el número)", callback_data="hc_up_max_custom")],
        [InlineKeyboardButton("❌ Cancelar", callback_data="hc_up_cancel")],
    ]
    await query.edit_message_text(
        f"📄 *Archivo:* `{emd(state['label'])}`\n"
        f"📅 Días: *{days}*\n\n"
        "5️⃣ ¿Cuántos *usuarios (límite)* tiene este archivo?\n"
        "Es el tope de entregas del pool. Si varios archivos usan el "
        "MISMO usuario+pass, comparten este límite entre todos.\n\n"
        "Selecciona una opción o escribe el número:\n\n"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
        parse_mode=ParseMode.MARKDOWN, reply_markup=InlineKeyboardMarkup(kb))


async def cmd_listhc(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Admin: listar archivos .HC registrados."""
    if not is_admin(update.effective_user.id):
        return
    data = load_hc_data()
    if not data:
        await update.message.reply_text("📭 No hay archivos .HC registrados.")
        return
    text = f"📁 *ARCHIVOS .HC ({len(data)})*\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
    for e in data:
        active = "🟢" if e.get('active', True) else "🔴"
        cnt = COUNTRIES.get(e.get('country', 'co'), {}).get('flag', '🌎')
        sends = e.get('send_count', 0)
        pool_total, pool_max = hc_pool_info(e)
        pool_bar = "💥" if pool_total >= pool_max else f"{pool_total}/{pool_max}"
        user_txt = f"👤 {emd(e.get('hc_user', ''))} " if e.get('hc_user') else ""
        text += (f"{active} #{e['id']} `{emd(e.get('file_name', '?'))}` {cnt} "
                 f"📶 {emd(carrier_name(e))}\n"
                 f"  {user_txt}🎯 Pool: {pool_bar} | 📤 {sends} entregas | "
                 f"Exp: {emd(e.get('expires_at', '?'))}\n\n")
    kb = [[InlineKeyboardButton("📁 Menú .HC", callback_data="hc_menu")]]
    await update.message.reply_text(text, parse_mode=ParseMode.MARKDOWN,
                                    reply_markup=InlineKeyboardMarkup(kb))


async def cmd_delhc(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Admin: desactivar archivo .HC por ID."""
    if not is_admin(update.effective_user.id):
        return
    args = context.args
    if not args:
        await update.message.reply_text("Uso: /delhc <id>\nEjemplo: /delhc 3")
        return
    hc_id = args[0]
    data = load_hc_data()
    found = False
    for e in data:
        if str(e.get('id')) == str(hc_id):
            e['active'] = False
            found = True
            break
    if found:
        save_hc_data(data)
        await update.message.reply_text(f"✅ Archivo #{hc_id} desactivado.")
    else:
        await update.message.reply_text(f"❌ Archivo #{hc_id} no encontrado.")


# =============================================================================
# ENTREGAS .HC — historial + liberación de slots (admin)
# Cada entrega vive en hc_deliveries (movivip.db). El admin puede liberar el
# slot de un usuario (active=0) para que el archivo vuelva a entregarse.
# =============================================================================
def hc_release_delivery(dlv_id):
    """Marca active=0 una entrega y resta 1 al send_count del archivo (libera slot).

    Devuelve (hc_file_id, user_id) o (None, None) si no existe / ya liberada.
    """
    db = get_db()
    row = db.execute(
        "SELECT hc_file_id, user_id FROM hc_deliveries WHERE id=? AND active=1",
        (dlv_id,)).fetchone()
    if not row:
        db.close()
        return None, None
    db.execute("UPDATE hc_deliveries SET active=0 WHERE id=?", (dlv_id,))
    db.commit(); db.close()
    hc_file_id = row['hc_file_id']
    data = load_hc_data()
    for e in data:
        if str(e.get('id')) == str(hc_file_id) and int(e.get('send_count', 0)) > 0:
            e['send_count'] = int(e.get('send_count', 0)) - 1
            save_hc_data(data)
            break
    return hc_file_id, row['user_id']


async def cmd_hcentregas(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Admin: listar entregas .HC con estado de verificación (capturas)."""
    if not is_admin(update.effective_user.id):
        return
    args = context.args
    db = get_db()
    if args:
        rows = db.execute(
            "SELECT * FROM hc_deliveries WHERE hc_file_id=? ORDER BY id DESC LIMIT 30",
            (args[0],)).fetchall()
        title = f"📦 *ENTREGAS .HC — archivo #{emd(args[0])} ({len(rows)})*"
    else:
        rows = db.execute(
            "SELECT * FROM hc_deliveries ORDER BY id DESC LIMIT 30").fetchall()
        title = f"📦 *ENTREGAS .HC recientes ({len(rows)})*"
    db.close()
    if not rows:
        await update.message.reply_text("📭 No hay entregas .HC registradas.")
        return

    status_icon = {
        'pending': '⏳ Pendiente (0/2 capturas)',
        'screenshot1': '📸 Captura 1/2 recibida',
        'verified': '✅ Verificada (2/2)',
    }
    text = title + "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
    kb = []
    for r in rows:
        st = status_icon.get(r['screenshot_status'], r['screenshot_status'])
        act = "🟢" if r['active'] else "⚪"
        if r['active'] and r['renewed']:
            act = "♻️"
        elif not r['active']:
            act = "⚪"
        renew_txt = ""
        if r['renewed']:
            renew_txt = f"  ♻️ *Renovado* {r['renewed_at'] or ''}\n"
        text += (f"{act} #{r['id']} `{emd(r['hc_label'] or '?')}`\n"
                 f"  👤 {emd(r['user_name'] or str(r['user_id']))} (ID {r['user_id']})\n"
                 f"  📅 Días: {r['days_choice'] or '-'} · 📱 Disp: {r['devices'] or '-'}\n"
                 + (f"  ⏰ Expira: {r['expires_at'] or '-'}\n" if r['expires_at'] else "")
                 + renew_txt
                 + f"  🕐 {r['received_at']} | {st}\n\n")
        if r['active'] and r['screenshot_status'] != 'verified':
            kb.append([InlineKeyboardButton(
                f"❌ Liberar #{r['id']} (ID {r['user_id']})",
                callback_data=f"hc_rel:{r['id']}")])
    await update.message.reply_text(
        text, parse_mode=ParseMode.MARKDOWN,
        reply_markup=InlineKeyboardMarkup(kb) if kb else None)


async def cmd_hcliberar(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Admin: liberar el slot de una entrega .HC (la elimina del pool)."""
    if not is_admin(update.effective_user.id):
        return
    args = context.args
    if not args:
        await update.message.reply_text(
            "Uso: /hcliberar <id_entrega>\n"
            "El ID lo ves en /hcentregas (ej: #5).\n"
            "También puedes pulsar el botón ❌ Liberar de la lista.")
        return
    try:
        dlv_id = int(args[0])
    except ValueError:
        await update.message.reply_text("❌ ID inválido.")
        return
    hc_file_id, user_id = hc_release_delivery(dlv_id)
    if hc_file_id is None:
        await update.message.reply_text("❌ Entrega no encontrada o ya liberada.")
        return
    await update.message.reply_text(
        f"✅ *Slot liberado!*\n\n"
        f"Entrega #{dlv_id} (usuario `{user_id}`) desactivada.\n"
        f"El archivo `{hc_file_id}` recuperó 1 slot — "
        f"ya puede entregarse a otro usuario.\n\n"
        f"📊 Pool actualizado en hc_free_data.json.",
        parse_mode=ParseMode.MARKDOWN)


# =============================================================================
# ARCHIVOS .HC — SECCIÓN PÚBLICA (liberación con anuncios vía MiniApp)
# =============================================================================
async def cmd_hc(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Menú público de Archivos .HC por país."""
    kb = []
    for code, info in COUNTRIES.items():
        kb.append([InlineKeyboardButton(
            f"{info['flag']} {info['name']}", callback_data=f"hc_country_{code}")])
    kb.append([InlineKeyboardButton("❌ Cerrar", callback_data="hc_close")])
    await update.message.reply_text(
        "📁 *ARCHIVOS .HC — MoviVIP Network*\n"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        "Selecciona tu país para ver los archivos disponibles.\n\n"
        f"⚠️ Para liberar el archivo deberás ver *{HC_ADS_REQUIRED} anuncios*.\n\n"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
        parse_mode=ParseMode.MARKDOWN, reply_markup=InlineKeyboardMarkup(kb))


async def _callback_hc_menu(query, context):
    kb = []
    for code, info in COUNTRIES.items():
        kb.append([InlineKeyboardButton(
            f"{info['flag']} {info['name']}", callback_data=f"hc_country_{code}")])
    kb.append([InlineKeyboardButton("❌ Cerrar", callback_data="hc_close")])
    await query.edit_message_text(
        "📁 *ARCHIVOS .HC — MoviVIP Network*\n"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        "Selecciona tu país:\n\n"
        f"⚠️ Para liberar el archivo deberás ver *{HC_ADS_REQUIRED} anuncios*.\n\n"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
        parse_mode=ParseMode.MARKDOWN, reply_markup=InlineKeyboardMarkup(kb))


async def _callback_hc_country(query, context, code):
    entries = get_hc_entries(country=code)
    info = COUNTRIES.get(code, {'name': code.upper(), 'flag': '🌎'})

    # 🇨🇴 Colombia → submenú por OPERADORA (Movistar/Tigo/Claro/WOM)
    if code == 'co' and entries:
        kb = []
        for ccode, cinfo in CARRIERS_CO.items():
            count = sum(1 for e in entries
                        if get_carrier_from_name(e.get('file_name', '')) == ccode)
            if count:
                kb.append([InlineKeyboardButton(
                    f"{cinfo['icon']} {cinfo['name']} ({count})",
                    callback_data=f"hc_carrier_{ccode}")])
        others = sum(1 for e in entries
                     if get_carrier_from_name(e.get('file_name', '')) is None)
        if others:
            kb.append([InlineKeyboardButton(
                f"📦 Otros ({others})", callback_data="hc_carrier_otros")])
        kb.append([InlineKeyboardButton("🔙 Volver a Países", callback_data="hc_menu")])
        await query.edit_message_text(
            f"{info['flag']} *ARCHIVOS .HC — {info['name']}*\n"
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
            f"📄 Archivos disponibles: *{len(entries)}*\n"
            "Selecciona tu *operadora*:\n\n"
            "📶 Movistar (varios métodos) · Tigo · Claro · WOM\n\n"
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
            parse_mode=ParseMode.MARKDOWN, reply_markup=InlineKeyboardMarkup(kb))
        return

    await _show_hc_files(query, entries, info, "hc_menu")


async def _callback_hc_carrier(query, context, carrier):
    """Lista los .hc de una operadora colombiana."""
    entries = [e for e in get_hc_entries(country='co')
               if get_carrier_from_name(e.get('file_name', '')) == carrier]
    if carrier == 'otros':
        entries = [e for e in get_hc_entries(country='co')
                   if get_carrier_from_name(e.get('file_name', '')) is None]

    info = {'name': 'Colombia', 'flag': '🇨🇴'}
    cinfo = CARRIERS_CO.get(carrier, {'name': 'Otros', 'icon': '📦'})
    if entries:
        await _show_hc_files(
            query, entries,
            {'name': f"{info['name']} — {cinfo['name']}", 'flag': info['flag']},
            "hc_country_co")
    else:
        kb = [[InlineKeyboardButton("🔙 Volver", callback_data="hc_country_co")]]
        await query.edit_message_text(
            f"{info['flag']} *{cinfo['name']}*\n"
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
            f"📭 No hay archivos .HC de *{cinfo['name']}* todavía.\n\n"
            "Los archivos se actualizan constantemente. Vuelve pronto!\n\n"
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
            parse_mode=ParseMode.MARKDOWN, reply_markup=InlineKeyboardMarkup(kb))


async def _show_hc_files(query, entries, info, back_data):
    """Renderiza la lista de archivos .hc (compartido por país y operadora)."""
    # Ocultar archivos cuyo pool de entregas ya se agotó
    entries = [e for e in entries if not hc_pool_exhausted(e)]

    if not entries:
        kb = [[InlineKeyboardButton("🔙 Volver", callback_data=back_data)]]
        await query.edit_message_text(
            f"{info['flag']} *{info['name']}*\n"
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
            "📭 No hay archivos .HC disponibles.\n\n"
            "Los archivos se actualizan constantemente. Vuelve pronto!\n\n"
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
            parse_mode=ParseMode.MARKDOWN, reply_markup=InlineKeyboardMarkup(kb))
        return

    kb = []
    for e in entries:
        label = e.get('label') or (e.get('file_name') or f"Archivo #{e['id']}").replace('.hc', '')
        days = e.get('days', 7)
        kb.append([InlineKeyboardButton(
            f"📄 {label} — {days} días",
            callback_data=f"hc_file_{e['id']}")])
    kb.append([InlineKeyboardButton("🔙 Volver", callback_data=back_data)])

    await query.edit_message_text(
        f"{info['flag']} *ARCHIVOS .HC — {info['name']}*\n"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        f"📄 Archivos disponibles: *{len(entries)}*\n\n"
        "Selecciona uno para liberarlo:\n\n"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
        parse_mode=ParseMode.MARKDOWN, reply_markup=InlineKeyboardMarkup(kb))


async def _callback_hc_file(query, context, hc_id):
    entry = get_hc_entry(hc_id)
    if not entry or not entry.get('active', True):
        kb = [[InlineKeyboardButton("🔙 Volver", callback_data="hc_menu")]]
        await query.edit_message_text(
            "❌ *Archivo no disponible o expirado.*",
            parse_mode=ParseMode.MARKDOWN, reply_markup=InlineKeyboardMarkup(kb))
        return

    # Pool agotado → no se puede liberar este archivo
    if hc_pool_exhausted(entry):
        kb = [[InlineKeyboardButton("🔙 Volver", callback_data="hc_menu")]]
        await query.edit_message_text(
            "❌ *Este archivo ya llegó a su límite de entregas.*\n"
            "Prueba con otro archivo de la lista.",
            parse_mode=ParseMode.MARKDOWN, reply_markup=InlineKeyboardMarkup(kb))
        return

    user_id = query.from_user.id
    token = secrets.token_urlsafe(32)
    creation_params = json.dumps({
        'action': 'hc',
        'hc_file_id': str(entry['id']),
        'country': entry.get('country', 'co'),
        'ads': HC_ADS_REQUIRED,
    })

    db = get_db()
    db.execute("INSERT INTO ad_log (user_id, token, creation_params) VALUES (?, ?, ?)",
               (user_id, token, creation_params))
    db.commit(); db.close()

    ad_url = (f"{MINIAPP_URL}/?token={token}&ads={HC_ADS_REQUIRED}"
              f"&user_id={user_id}&hc=1&hc_id={entry['id']}")

    kb = InlineKeyboardMarkup([
        [InlineKeyboardButton("👁️ VER ANUNCIOS", web_app=WebAppInfo(url=ad_url))],
        [InlineKeyboardButton("🔙 Volver", callback_data="hc_menu")],
    ])

    label = entry.get('label') or (entry.get('file_name') or f"Archivo #{entry['id']}").replace('.hc', '')
    country_name = COUNTRIES.get(entry.get('country', 'co'), {}).get('name', 'Otros')

    await query.edit_message_text(
        f"📁 *LIBERAR ARCHIVO .HC*\n"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        f"📄 Archivo: *{label}*\n"
        f"📍 País: *{country_name}*\n\n"
        f"⚠️ *DEBES VER {HC_ADS_REQUIRED} ANUNCIOS*\n"
        "para liberar el archivo.\n\n"
        "1️⃣ Toca *VER ANUNCIOS*\n"
        "2️⃣ Completa los anuncios\n"
        "3️⃣ El archivo se envía automáticamente\n\n"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
        parse_mode=ParseMode.MARKDOWN, reply_markup=kb)


# =============================================================================
# CALLBACK HANDLER — FIXED: uses query.edit_message_text or query.message
# =============================================================================
async def callback_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle inline keyboard callbacks — rutas públicas (.HC) y admin."""
    query = update.callback_query
    data = query.data

    # Answer the callback immediately (removes loading spinner)
    await query.answer()

    # ═══ v5.0 — EXTRAS (bienvenida editable + promos) ═══
    if _EXTRAS_OK and (data.startswith("bienvenida_") or data.startswith("bienv_")
                       or data.startswith("promo_")):
        try:
            if await extras_route(update, context, data):
                return
        except Exception as e:
            logger.error(f"Extras callback error: {e}")

    # ═══ RUTAS PÚBLICAS — Archivos .HC (sin admin) ═══
    if data == "hc_menu":
        try:
            await _callback_hc_menu(query, context)
        except Exception as e:
            logger.error(f"HC menu error: {e}")
        return
    if data == "hc_close":
        try:
            await query.edit_message_text("👋 Hasta luego! Usa /hc para volver.")
        except Exception:
            pass
        return
    if data.startswith("hc_country_"):
        code = data.split("_", 2)[2]
        try:
            await _callback_hc_country(query, context, code)
        except Exception as e:
            logger.error(f"HC country error: {e}")
        return
    if data.startswith("hc_carrier_"):
        carrier = data.split("_", 2)[2]
        try:
            await _callback_hc_carrier(query, context, carrier)
        except Exception as e:
            logger.error(f"HC carrier error: {e}")
        return
    if data.startswith("hc_file_"):
        hc_id = data.split("_", 2)[2]
        try:
            await _callback_hc_file(query, context, hc_id)
        except Exception as e:
            logger.error(f"HC file error: {e}")
        return
    if data.startswith("hc_up_days_"):
        if not is_admin(query.from_user.id):
            await query.answer("❌ No eres admin.", show_alert=True)
            return
        days_str = data.split("_", 3)[3]
        try:
            await _hc_days_chosen(query, context, days_str)
        except Exception as e:
            logger.error(f"HC days error: {e}")
        return
    if data.startswith("hc_rel:"):
        if not is_admin(query.from_user.id):
            await query.answer("❌ No eres admin.", show_alert=True)
            return
        try:
            dlv_id = int(data.split(":", 1)[1])
            hc_file_id, user_id = hc_release_delivery(dlv_id)
            if hc_file_id is None:
                await query.answer("⚠️ Entrega ya liberada o no encontrada.")
                return
            await query.edit_message_text(
                f"✅ *Slot liberado!*\n\n"
                f"Entrega #{dlv_id} (usuario `{user_id}`) desactivada.\n"
                f"El archivo `{hc_file_id}` recuperó 1 slot.",
                parse_mode=ParseMode.MARKDOWN)
        except Exception as e:
            logger.error(f"hc_rel callback error: {e}")
            await query.answer("❌ Error al liberar.", show_alert=True)
        return
    if data.startswith("hc_up_max_"):
        if not is_admin(query.from_user.id):
            await query.answer("❌ No eres admin.", show_alert=True)
            return
        max_val = data.split("_", 3)[3]
        try:
            await _hc_max_users_chosen(query, context, max_val)
        except Exception as e:
            logger.error(f"HC max users error: {e}")
        return
    if data.startswith("hc_up_dev_"):
        if not is_admin(query.from_user.id):
            await query.answer("❌ No eres admin.", show_alert=True)
            return
        dev_val = data.split("_", 3)[3]
        try:
            await _hc_devices_pool_chosen(query, context, dev_val)
        except Exception as e:
            logger.error(f"HC devices pool error: {e}")
        return
    if data == "hc_up_user_skip":
        if not is_admin(query.from_user.id):
            await query.answer("❌ No eres admin.", show_alert=True)
            return
        state = context.user_data.get('hc_upload')
        if not state:
            await query.answer("⏳ La subida expiró.", show_alert=True)
            return
        state['hc_user'] = ''
        try:
            entry = await _finish_hc_upload(context, state.get('days') or 7)
            if not entry:
                await query.answer("⏳ La subida expiró.", show_alert=True)
                return
            kb = [[InlineKeyboardButton("📁 Ver menú .HC", callback_data="hc_menu"),
                  InlineKeyboardButton("🔄 Subir otro", callback_data="hc_up_restart")]]
            await query.edit_message_text(
                f"✅ *Archivo .HC guardado!*\n"
                "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
                f"📄 Nombre: `{emd(entry['label'])}`\n"
                f"📍 País: *{emd(COUNTRIES.get(entry['country'], {}).get('name', entry['country'].upper()))}*\n"
                f"📶 Operadora: *{emd(carrier_name(entry))}*\n"
                f"📅 Días: *{entry['days']}*\n"
                f"🔢 Límite: *{entry.get('max_users', HC_DEFAULT_MAX_USERS)} usuarios*\n"
                f"📱 Dispositivos (pool): *{entry.get('devices_pool', entry.get('max_users', HC_DEFAULT_MAX_USERS) * 5)}*\n"
                f"📅 Expira: `{emd(entry['expires_at'])}`\n"
                f"🆔 ID: `{entry['id']}`\n\n"
                "Ya está disponible en el menú público /hc\n\n"
                "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
                parse_mode=ParseMode.MARKDOWN, reply_markup=InlineKeyboardMarkup(kb))
        except Exception as e:
            logger.error(f"HC user skip error: {e}")
        return
    if data.startswith("hc_up_carrier_"):
        if not is_admin(query.from_user.id):
            await query.answer("❌ No eres admin.", show_alert=True)
            return
        carrier = data.split("_", 3)[3]
        try:
            await _callback_hc_up_carrier(query, context, carrier)
        except Exception as e:
            logger.error(f"HC upload carrier error: {e}")
        return
    if data == "hc_up_backcountry":
        if not is_admin(query.from_user.id):
            await query.answer("❌ No eres admin.", show_alert=True)
            return
        try:
            await _callback_hc_up_backcountry(query, context)
        except Exception as e:
            logger.error(f"HC backcountry error: {e}")
        return
    if data.startswith("hc_up_quick_"):
        if not is_admin(query.from_user.id):
            await query.answer("❌ No eres admin.", show_alert=True)
            return
        carrier = data.split("_", 3)[3]
        try:
            await _callback_hc_up_quick(query, context, carrier)
        except Exception as e:
            logger.error(f"HC quick upload error: {e}")
        return
    if data == "hc_up_restart":
        if not is_admin(query.from_user.id):
            await query.answer("❌ No eres admin.", show_alert=True)
            return
        context.user_data['hc_upload'] = {'step': 'country'}
        kb = []
        for code, info in COUNTRIES.items():
            kb.append([InlineKeyboardButton(
                f"{info['flag']} {info['name']}", callback_data=f"hc_up_{code}")])
        kb.append([InlineKeyboardButton("❌ Cancelar", callback_data="hc_up_cancel")])
        await query.edit_message_text(
            "📤 *SUBIR ARCHIVO .HC*\n"
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
            "1️⃣ Selecciona el país del archivo:\n\n"
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
            parse_mode=ParseMode.MARKDOWN, reply_markup=InlineKeyboardMarkup(kb))
        return
    if data.startswith("hc_up_"):
        code = data.split("_", 2)[2]
        if code == "cancel":
            context.user_data.pop('hc_upload', None)
            await query.edit_message_text("❌ Subida cancelada.")
            return
        if not is_admin(query.from_user.id):
            await query.answer("❌ No eres admin.", show_alert=True)
            return
        try:
            await _callback_hc_up(query, context, code)
        except Exception as e:
            logger.error(f"HC upload country error: {e}")
        return

    # ═══ RUTAS ADMIN ═══
    if not is_admin(query.from_user.id):
        await query.answer("❌ No eres admin.", show_alert=True)
        return

    try:
        if data == "dash":
            await _callback_db(query, context)
        elif data == "members":
            await _callback_members(query, context)
        elif data == "reports":
            await _callback_reports(query, context)
        elif data == "welcomes":
            await _callback_welcomes(query, context)
        elif data == "fulldb":
            await _callback_db(query, context)
        elif data == "stats":
            await _callback_stats(query, context)
        elif data == "send_official":
            await _callback_send_official(query, context)
        elif data == "hc_admin_upload":
            context.user_data['hc_upload'] = {'step': 'country'}
            kb = []
            for code, info in COUNTRIES.items():
                kb.append([InlineKeyboardButton(
                    f"{info['flag']} {info['name']}", callback_data=f"hc_up_{code}")])
            kb.append([InlineKeyboardButton("❌ Cancelar", callback_data="hc_up_cancel")])
            await query.edit_message_text(
                "📤 *SUBIR ARCHIVO .HC*\n"
                "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
                "1️⃣ Selecciona el país del archivo:\n\n"
                "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
                parse_mode=ParseMode.MARKDOWN, reply_markup=InlineKeyboardMarkup(kb))
        elif data == "adblock_menu":
            await _callback_adblock_menu(query, context)
        elif data.startswith("adblock_unban_"):
            await _callback_adblock_unban(query, context, data)
        elif data.startswith("adblock_ban_"):
            await _callback_adblock_ban(query, context, data)
    except Exception as e:
        logger.error(f"Callback error: {e}")
        try:
            await query.message.reply_text(f"❌ Error: {e}")
        except:
            pass


async def _callback_db(query, context):
    """DB button → edit message with DB info."""
    db = get_db()
    c = db.cursor()

    tables_info = []
    for table in ['community_members', 'welcome_log', 'mention_reports', 'ssh_accounts']:
        try:
            count = c.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
            tables_info.append(f"📋 {table}: {count}")
        except:
            tables_info.append(f"📋 {table}: -")

    active = c.execute("SELECT COUNT(*) FROM community_members WHERE is_active=1").fetchone()[0]
    total = c.execute("SELECT COUNT(*) FROM community_members").fetchone()[0]
    ch = c.execute("SELECT COUNT(*) FROM community_members WHERE source='channel'").fetchone()[0]
    gr = c.execute("SELECT COUNT(*) FROM community_members WHERE source='group'").fetchone()[0]
    reports = c.execute("SELECT COUNT(*) FROM mention_reports").fetchone()[0]

    recent = c.execute(
        "SELECT username, first_name, source FROM community_members ORDER BY joined_at DESC LIMIT 5"
    ).fetchall()

    db.close()

    text = (
        f"📊 *BASE DE DATOS*\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        f"👥 Total: {total} | Activos: {active}\n"
        f"📢 Canal: {ch} | 💬 Grupo: {gr}\n"
        f"🔔 Reportes: {reports}\n\n"
        f"📋 *TABLAS:*\n"
    )
    for t in tables_info:
        text += f"  {t}\n"

    text += f"\n📅 *ULTIMOS:*\n"
    for r in recent:
        uname = f"@{r['username']}" if r['username'] else r['first_name']
        text += f"  • {uname} ({r['source']})\n"

    kb = InlineKeyboardMarkup([
        [InlineKeyboardButton("🔄 Actualizar", callback_data="dash"),
         InlineKeyboardButton("📈 Stats", callback_data="stats")],
        [InlineKeyboardButton("👥 Members", callback_data="members"),
         InlineKeyboardButton("🔔 Reports", callback_data="reports")],
        [InlineKeyboardButton("🛡️ Adblock / 3-Strikes", callback_data="adblock_menu")],
    ])

    await query.edit_message_text(text, parse_mode=ParseMode.MARKDOWN, reply_markup=kb)


async def _callback_members(query, context):
    """Members button."""
    db = get_db()
    members = db.execute(
        "SELECT username, first_name, source, is_active "
        "FROM community_members ORDER BY joined_at DESC LIMIT 20"
    ).fetchall()
    db.close()

    text = f"👥 *MIEMBROS* ({len(members)})\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
    for m in members:
        status = "🟢" if m['is_active'] else "🔴"
        uname = f"@{m['username']}" if m['username'] else m['first_name']
        src = "📢" if m['source'] == 'channel' else "💬"
        text += f"{status} {src} *{uname}*\n"

    kb = InlineKeyboardMarkup([
        [InlineKeyboardButton("🔄 Actualizar", callback_data="members")],
        [InlineKeyboardButton("📊 Dashboard", callback_data="dash")],
    ])
    await query.edit_message_text(text, parse_mode=ParseMode.MARKDOWN, reply_markup=kb)


async def _callback_reports(query, context):
    """Reports button."""
    db = get_db()
    reports = db.execute(
        "SELECT reporter_name, report_type, chat_title, created_at "
        "FROM mention_reports ORDER BY created_at DESC LIMIT 10"
    ).fetchall()
    db.close()

    if not reports:
        text = "📭 No hay reportes."
    else:
        text = f"🔔 *REPORTES* ({len(reports)})\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        for r in reports:
            text += f"👤 {r['reporter_name']} | {r['report_type']}\n📍 {r['chat_title']}\n🕐 {r['created_at']}\n\n"

    kb = InlineKeyboardMarkup([
        [InlineKeyboardButton("🔄 Actualizar", callback_data="reports")],
        [InlineKeyboardButton("📊 Dashboard", callback_data="dash")],
    ])
    await query.edit_message_text(text, parse_mode=ParseMode.MARKDOWN, reply_markup=kb)


async def _callback_welcomes(query, context):
    """Welcomes button."""
    db = get_db()
    rows = db.execute(
        "SELECT username, first_name, source, chat_title, welcomed_at "
        "FROM welcome_log ORDER BY welcomed_at DESC LIMIT 10"
    ).fetchall()
    db.close()

    if not rows:
        text = "📭 No hay bienvenidas."
    else:
        text = f"📨 *BIENVENIDAS* ({len(rows)})\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        for r in rows:
            uname = f"@{r['username']}" if r['username'] else r['first_name']
            src = "📢" if r['source'] == 'channel' else "💬"
            text += f"{src} *{uname}* → {r['chat_title']}\n🕐 {r['welcomed_at']}\n\n"

    kb = InlineKeyboardMarkup([
        [InlineKeyboardButton("🔄 Actualizar", callback_data="welcomes")],
        [InlineKeyboardButton("📊 Dashboard", callback_data="dash")],
    ])
    await query.edit_message_text(text, parse_mode=ParseMode.MARKDOWN, reply_markup=kb)


# =============================================================================
# ADBLOCK / 3-STRIKE CALLBACKS
# =============================================================================
async def _callback_adblock_menu(query, context):
    """Menú principal de gestión adblock/3-strikes."""
    if not is_admin(query.from_user.id):
        await query.answer("❌ No eres admin.", show_alert=True)
        return
    
    rows = adblock_get_all_strikes()
    
    text = "🛡️ <b>GESTIÓN ADBLOCK / 3-STRIKES</b>\n"
    text += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
    
    if not rows:
        text += "📭 No hay usuarios con strikes registrados."
    else:
        text += f"📊 Total usuarios con strikes: <b>{len(rows)}</b>\n\n"
        
        # Separar por status
        banned = [r for r in rows if r['status'] == 'banned']
        active = [r for r in rows if r['status'] == 'active']
        conditional = [r for r in rows if r['status'] == 'unbanned_conditional']
        
        if banned:
            text += f"🚫 <b>BANEADOS ({len(banned)})</b>\n"
            for r in banned[:10]:
                perm = " 🔒" if r['permanent_ban'] else ""
                text += f"  🚫 <code>{r['user_id']}</code> @{r['username'] or 'N/A'} — {r['strikes']}/3{perm}\n"
            if len(banned) > 10:
                text += f"  <i>... y {len(banned) - 10} más</i>\n"
            text += "\n"
        
        if conditional:
            text += f"⏳ <b>CONDICIONALES ({len(conditional)})</b> — 1 strike, reincidencia = permaban\n"
            for r in conditional[:10]:
                text += f"  ⏳ <code>{r['user_id']}</code> @{r['username'] or 'N/A'} — {r['strikes']}/3\n"
            if len(conditional) > 10:
                text += f"  <i>... y {len(conditional) - 10} más</i>\n"
            text += "\n"
        
        if active:
            text += f"⚠️ <b>ACTIVOS ({len(active)})</b> — strikes sin banear\n"
            for r in active[:10]:
                text += f"  ⚠️ <code>{r['user_id']}</code> @{r['username'] or 'N/A'} — {r['strikes']}/3\n"
            if len(active) > 10:
                text += f"  <i>... y {len(active) - 10} más</i>\n"
            text += "\n"
    
    text += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    kb_rows = []
    if banned:
        for r in banned[:10]:
            kb_rows.append([InlineKeyboardButton(
                f"✅ Desbanear {r['first_name'] or r['username'] or r['user_id']} (condicional)",
                callback_data=f"adblock_unban_{r['user_id']}_conditional")])
    if conditional:
        for r in conditional[:10]:
            kb_rows.append([InlineKeyboardButton(
                f"✅ Desbanear {r['first_name'] or r['username'] or r['user_id']} (total)",
                callback_data=f"adblock_unban_{r['user_id']}_total")])
    
    kb_rows.append([InlineKeyboardButton("🔄 Actualizar", callback_data="adblock_menu")])
    kb_rows.append([InlineKeyboardButton("📊 Dashboard", callback_data="dash")])
    
    await query.edit_message_text(
        text, parse_mode=ParseMode.HTML, 
        reply_markup=InlineKeyboardMarkup(kb_rows))


async def _callback_adblock_unban(query, context, data):
    """Desbanea usuario desde botón. data: adblock_unban_<user_id>_<conditional|total>"""
    if not is_admin(query.from_user.id):
        await query.answer("❌ No eres admin.", show_alert=True)
        return
    
    try:
        parts = data.split("_")
        user_id = int(parts[2])
        mode = parts[3]  # conditional o total
        conditional = (mode == 'conditional')
        
        success, msg = adblock_unban(user_id, query.from_user.id, "Desbaneado desde panel admin", conditional)
        
        if success:
            await query.answer(f"✅ {msg}", show_alert=True)
            # Refrescar menú
            await _callback_adblock_menu(query, context)
        else:
            await query.answer(f"❌ {msg}", show_alert=True)
    except Exception as e:
        await query.answer(f"❌ Error: {e}", show_alert=True)


async def _callback_adblock_ban(query, context, data):
    """Banea manualmente desde botón. data: adblock_ban_<user_id>"""
    if not is_admin(query.from_user.id):
        await query.answer("❌ No eres admin.", show_alert=True)
        return
    
    try:
        user_id = int(data.split("_")[2])
        
        db = get_db()
        row = db.execute("SELECT username, first_name FROM community_members WHERE tg_id=?", (user_id,)).fetchone()
        username = row['username'] if row else ''
        first_name = row['first_name'] if row else ''
        now = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        
        db.execute("""INSERT OR REPLACE INTO adblock_strikes 
            (user_id, username, first_name, strikes, status, first_strike_at, last_strike_at, banned_at, permanent_ban, unban_reason)
            VALUES (?, ?, ?, 3, 'banned', ?, ?, ?, 1, ?)""",
            (user_id, username, first_name, now, now, now, "Ban manual desde panel admin"))
        db.commit()
        db.close()
        
        try:
            send_telegram_msg(user_id,
                f"🚫 <b>BLOQUEO PERMANENTE - ADBLOCK</b>\n"
                f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
                f"Has sido bloqueado por uso de bloqueador de anuncios.\n"
                f"Razón: Ban manual desde panel admin\n\n"
                f"🔒 No puedes crear SSH ni obtener .HC.\n"
                f"Contacta a @MoviVIP si crees que es error.",
                parse_mode=ParseMode.HTML)
        except:
            pass
        
        await query.answer(f"✅ Usuario {user_id} baneado (3 strikes)", show_alert=True)
        await _callback_adblock_menu(query, context)
        
    except Exception as e:
        await query.answer(f"❌ Error: {e}", show_alert=True)


async def _callback_stats(query, context):
    """Stats button."""
    db = get_db()
    c = db.cursor()

    total = c.execute("SELECT COUNT(*) FROM community_members").fetchone()[0]
    active = c.execute("SELECT COUNT(*) FROM community_members WHERE is_active=1").fetchone()[0]
    ch = c.execute("SELECT COUNT(*) FROM community_members WHERE source='channel' AND is_active=1").fetchone()[0]
    gr = c.execute("SELECT COUNT(*) FROM community_members WHERE source='group' AND is_active=1").fetchone()[0]
    welcomes = c.execute("SELECT COUNT(*) FROM welcome_log").fetchone()[0]
    reports = c.execute("SELECT COUNT(*) FROM mention_reports").fetchone()[0]

    today = datetime.datetime.now().strftime('%Y-%m-%d')
    joins_today = c.execute("SELECT COUNT(*) FROM community_members WHERE joined_at LIKE ?", (f"{today}%",)).fetchone()[0]

    week_ago = (datetime.datetime.now() - datetime.timedelta(days=7)).strftime('%Y-%m-%d')
    joins_week = c.execute("SELECT COUNT(*) FROM community_members WHERE joined_at >= ?", (week_ago,)).fetchone()[0]

    db.close()

    text = (
        f"📈 *ESTADISTICAS*\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        f"👥 Total: {total} | Activos: {active}\n"
        f"📢 Canal: {ch} | 💬 Grupo: {gr}\n\n"
        f"📅 Hoy: {joins_today} | Semana: {joins_week}\n\n"
        f"📨 Bienvenidas: {welcomes}\n"
        f"🔔 Reportes: {reports}\n\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    )
    kb = InlineKeyboardMarkup([
        [InlineKeyboardButton("🔄 Actualizar", callback_data="stats")],
        [InlineKeyboardButton("📊 Dashboard", callback_data="dash")],
    ])
    await query.edit_message_text(text, parse_mode=ParseMode.MARKDOWN, reply_markup=kb)


async def _callback_send_official(query, context):
    """Send official message via callback button."""
    await query.edit_message_text("📢 Enviando comunicado oficial...")

    success = 0
    fail = 0

    for chat_id, name in [(CHANNEL_ID, "Canal"), (GROUP_ID, "Grupo")]:
        try:
            await context.bot.send_message(chat_id=chat_id, text=OFFICIAL_MSG, parse_mode=ParseMode.MARKDOWN)
            success += 1
        except Exception as e:
            fail += 1
            logger.error(f"Official to {name}: {e}")

    try:
        db = get_db()
        db.execute("INSERT INTO official_messages (sent_by, target, success_count, fail_count) VALUES (?,?,?,?)",
                   (query.from_user.id, 'both', success, fail))
        db.commit()
        db.close()
    except:
        pass

    kb = InlineKeyboardMarkup([
        [InlineKeyboardButton("📊 Dashboard", callback_data="dash")],
    ])
    await query.edit_message_text(
        f"✅ Comunicado enviado!\n📊 Exitosos: {success} | Fallidos: {fail}",
        reply_markup=kb
    )


# =============================================================================
# MAIN
# =============================================================================
def main():
    logger.info("Starting MoviVIP Notification Bot v4.0...")

    init_notif_db()
    if not _EXTRAS_OK:
        pass
    else:
        try:
            init_notif_extras_db()
            logger.info("Extras DB inicializada (bienvenida editable + promos)")
        except Exception as e:
            logger.error(f"init_notif_extras_db error: {e}")

    app = (Application.builder().token(TOKEN)
           .connect_timeout(30).read_timeout(60).write_timeout(60).pool_timeout(30)
           .http_version("1.1")  # HTTP/2 se cuelga con la red lenta del VPS -> Telegram
           .get_updates_read_timeout(60)
           .get_updates_connect_timeout(30)
           .get_updates_pool_timeout(30)
           .get_updates_http_version("1.1")
           .build())

    # v4.1 — destinos para "Enviar promo ahora" (canal + grupo).
    # Sin esto, promo_enviar itera una lista vacía y nunca manda nada.
    app.bot_data["notif_targets"] = [CHANNEL_ID, GROUP_ID]

    # Commands
    app.add_handler(CommandHandler("start", cmd_start))
    app.add_handler(CommandHandler("db", cmd_db))
    app.add_handler(CommandHandler("stats", cmd_stats))
    app.add_handler(CommandHandler("members", cmd_members))
    app.add_handler(CommandHandler("reports", cmd_reports))
    app.add_handler(CommandHandler("welcomes", cmd_welcome_log))
    app.add_handler(CommandHandler("welcome_preview", cmd_preview))
    app.add_handler(CommandHandler("preview", cmd_preview))
    app.add_handler(CommandHandler("official", cmd_send_official))
    app.add_handler(CommandHandler("help", cmd_help))

    # Archivos .HC
    app.add_handler(CommandHandler("hc", cmd_hc))
    app.add_handler(CommandHandler("subirhc", cmd_subirhc))
    app.add_handler(CommandHandler("listhc", cmd_listhc))
    app.add_handler(CommandHandler("delhc", cmd_delhc))
    app.add_handler(CommandHandler("hcentregas", cmd_hcentregas))
    app.add_handler(CommandHandler("hcliberar", cmd_hcliberar))
    app.add_handler(CommandHandler("cancelar_hc", cmd_cancelar_hc))

    # ADBLOCK / 3-STRIKE
    app.add_handler(CommandHandler("adblock_list", cmd_adblock_list))
    app.add_handler(CommandHandler("adblock_unban", cmd_adblock_unban))
    app.add_handler(CommandHandler("adblock_ban", cmd_adblock_ban))
    app.add_handler(CommandHandler("adblock_help", cmd_adblock_help))

    # v5.0 — Extras: edición de bienvenida/promos (SE REGISTRAN ANTES que .HC
    # para interceptar textos/fotos del admin cuando hay edición activa)
    if _EXTRAS_OK:
        try:
            from notif_integration import (
                handle_extras_media, handle_extras_text,
                cmd_cancelar_bienv, cmd_cancelar_promo,
            )
            app.add_handler(CommandHandler("cancelar_bienv", cmd_cancelar_bienv))
            app.add_handler(CommandHandler("cancelar_promo", cmd_cancelar_promo))
            app.add_handler(MessageHandler(filters.PHOTO & filters.ChatType.PRIVATE, handle_extras_media))
            app.add_handler(MessageHandler(filters.TEXT & filters.ChatType.PRIVATE, handle_extras_text))
        except Exception as e:
            logger.error(f"Extras handlers error: {e}")

    app.add_handler(MessageHandler(filters.Document.ALL & filters.ChatType.PRIVATE, handle_hc_document))
    app.add_handler(MessageHandler(filters.TEXT & filters.ChatType.PRIVATE, handle_hc_days_text))

    # Callbacks
    app.add_handler(CallbackQueryHandler(callback_handler))

    # Expiración .HC: cada 30 min → notifica el día de vencimiento y elimina
    app.job_queue.run_repeating(check_hc_expiry, interval=1800, first=60)

    # Welcome
    app.add_handler(MessageHandler(filters.StatusUpdate.NEW_CHAT_MEMBERS, welcome_new_member))
    app.add_handler(MessageHandler(filters.StatusUpdate.LEFT_CHAT_MEMBER, welcome_left_member))

    # Channel subscriber detection (ChatMember updates — required for channels)
    app.add_handler(ChatMemberHandler(channel_member_handler, ChatMemberHandler.CHAT_MEMBER))

    # Mentions (group only)
    app.add_handler(MessageHandler(filters.ChatType.GROUPS & filters.TEXT, detect_mentions))

    logger.info("Notification Bot v4.1 running!")
    app.run_polling(
        drop_pending_updates=True,
        bootstrap_retries=5,
        allowed_updates=[
            "message",
            "callback_query",
            "chat_member",
            "my_chat_member",
            "new_chat_members",
            "left_chat_member",
        ],
    )


if __name__ == '__main__':
    main()
