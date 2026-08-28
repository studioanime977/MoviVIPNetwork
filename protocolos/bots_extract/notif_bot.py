#!/usr/bin/env python3
"""
MoviVIP Notification Bot v4.0 — GRADE MILITAR
- Welcome with logo + inline buttons (links)
- Mention/tag detection → admin reports
- Admin panel with working callback buttons
- Full DB integration
- NEW: Multimedia support (GIFs, videos, photos from all users)
- NEW: Auto-ban by links/keywords/suspicious content
- NEW: Individual ban system (per-user, NOT group-wide)
- NEW: Admin ban panel (/ban, /unban, /banlist, /setbanduration)
- NEW: Auto-unban timer (1 week, 1 month, permanent)
"""
import os
import re
import sqlite3
import logging
import datetime
import sys
import io
import asyncio
from pathlib import Path
from functools import wraps

from telegram import (
    Update, InlineKeyboardButton, InlineKeyboardMarkup, ChatPermissions
)
from telegram.ext import (
    Application, CommandHandler, MessageHandler,
    CallbackQueryHandler, ContextTypes, filters, ChatMemberHandler,
    JobQueue
)
from telegram.constants import ParseMode

# =============================================================================
# CONFIG — token, canal, grupo y admin autorizado vienen de config.py
# (el generador los personaliza por cliente; NOTIF_BOT_TOKEN debe ser un bot
#  DISTINTO al admin para poder correr ambos procesos en paralelo)
# =============================================================================
sys.path.insert(0, str(Path(__file__).parent))
from config import (
    NOTIF_BOT_TOKEN as TOKEN,
    NOTIF_CHANNEL_ID as _CFG_CHANNEL_ID,
    NOTIF_GROUP_ID as _CFG_GROUP_ID,
    ADMIN_IDS,
    MY_BRAND,
)

BRAND = MY_BRAND  # marca del que configura el VPS (se inyecta en {brand})

# Auto-detect: these will be overridden from DB on startup
CHANNEL_ID = _CFG_CHANNEL_ID
GROUP_ID = _CFG_GROUP_ID

CHANNEL_LINK = "https://t.me/MoviVIPNetwork"
GROUP_LINK = "https://t.me/MoviVIPNet"
SSH_BOT = "@MOVIVIPNETWORK_SSH_BOT"
STORE_BOT = "@MoviVIPUSERVPS_bot"
LOGO_PATH = "/root/movivip_bots/logo.png"
DB_PATH = "/root/movivip.db"

# Imagenes configurables por el admin (se cargan con /set_welcome y /set_ad).
# Se guardan en la carpeta del bot en el VPS y cada carga NUEVA REEMPLAZA
# a la anterior (mismo nombre de archivo).
BOT_DIR = Path(__file__).parent
WELCOME_IMG = str(BOT_DIR / "welcome.jpg")   # imagen de bienvenida (jpg por defecto, puede ser .mp4)
AD_IMG = str(BOT_DIR / "ad.jpg")             # imagen de publicidad (jpg por defecto, puede ser .mp4)

# Plantillas de TEXTO configurables por el admin (se cargan con /set_welcome_text
# y /set_ad_text). Quien configura el VPS decide los precios, planes (3-7-15-30
# dias) y el formato. Se guardan en la carpeta del bot y cada carga NUEVA
# REEMPLAZA a la anterior.
WELCOME_TEXT_FILE = str(BOT_DIR / "welcome_text.txt")
AD_TEXT_FILE = str(BOT_DIR / "ad_text.txt")
RULES_FILE = str(BOT_DIR / "rules.txt")

# Texto de bienvenida por defecto (solo se usa si el admin NO ha cargado plantilla)
WELCOME_DEFAULT_TEXT = (
    "👑 *Bienvenido a {brand}!* 👑\n"
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
    "👋 Hola *{first_name}*!\n"
    "👤 Usuario: {username}\n"
    "🆔 ID Telegram: `{id}`\n"
    "📅 Se unio: {date}\n"
    "📍 Ubicacion: {source_emoji}\n\n"
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
    "📋 *REGLAS DEL GRUPO:*\n\n"
    "1️⃣ Respeta a todos los miembros\n"
    "2️⃣ No spam ni publicidad\n"
    "3️⃣ No compartir credenciales\n"
    "4️⃣ Usa los bots para tus cuentas\n"
    "5️⃣ Reporta con /report\n"
    "6️⃣ No cobrar por cuentas GRATIS\n\n"
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
    "⚡ *PLANES Y PRECIOS:*\n\n"
    "💰 Los planes y precios los publica\n"
    "el administrador.\n\n"
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
    "👇 *Usa los botones de abajo para acceder a todo*\n\n"
    "🙏 *Gracias por unirte!*"
)

# Texto de publicidad por defecto (solo se usa si el admin NO ha cargado plantilla)
PUBLICITY_TEXT = (
    "🔥 *{brand}* 🔥\n"
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
    "🚀 Velocidad extrema, configuracion incluida.\n"
    "💳 Planes y precios: consulta al administrador.\n\n"
    "💬 Escribenos ahora y activa tu plan hoy mismo!\n"
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
)

# =============================================================================
# ANTI-SPAM / AUTO-BAN SYSTEM — GRADE MILITAR
# =============================================================================
# Regular link patterns
LINK_PATTERNS = [
    r'https?://[^\s]+',                          # Any HTTP/HTTPS URL
    r't\.me/[^\s]+',                             # Telegram links
    r'bit\.ly/[^\s]+',                           # Bitly short links
    r'tinyurl\.com/[^\s]+',                      # TinyURL
    r'goo\.gl/[^\s]+',                           # Google short links
    r'is\.gd/[^\s]+',                            # is.gd
    r'vc\.ru/[^\s]+',                            # vc.ru
    r'discord\.gg/[^\s]+',                       # Discord invites
    r'discord\.com/invite/[^\s]+',               # Discord invites
    r'instagram\.com/[^\s]+',                    # Instagram links
    r'tiktok\.com/[^\s]+',                       # TikTok links
    r'youtube\.com/[^\s]+',                      # YouTube links
    r'youtu\.be/[^\s]+',                         # YouTube short
    r'wa\.me/[^\s]+',                            # WhatsApp links
    r'chat\.whatsapp\.com/[^\s]+',               # WhatsApp group invites
    r'vm\.tiktok\.com/[^\s]+',                   # TikTok video shares
    r'facebook\.com/[^\s]+',                     # Facebook links
    r'fb\.watch/[^\s]+',                         # Facebook watch
    r'twitter\.com/[^\s]+',                      # Twitter/X links
    r'x\.com/[^\s]+',                            # X/Twitter links
    r'linkedin\.com/[^\s]+',                     # LinkedIn
    r'pastebin\.com/[^\s]+',                     # Pastebin
    r'hastebin\.com/[^\s]+',                     # Hastebin
    r'[a-zA-Z0-9.-]+\.(com|net|org|info|xyz|top|buzz|link|click|club|online|site|web)/[^\s]*',  # Generic domains
]

# =============================================================================
# VPN PROTOCOL LINKS — encriptados/base64 (configs de Xray, V2Ray, etc.)
# Estos son los links que verdaderamente se usan para compartir configs VPN
# =============================================================================
VPN_PROTOCOL_PATTERNS = [
    # V2Ray / Xray
    r'vmess://[A-Za-z0-9+/=_\-]+',              # VMess (base64 JSON)
    r'vless://[^\s]+',                            # VLESS (uuid@server)
    r'trojan://[^\s]+',                           # Trojan (password@server)

    # Shadowsocks
    r'ss://[A-Za-z0-9+/=_\-]+',                  # Shadowsocks (base64)
    r'ssr://[A-Za-z0-9+/=_\-]+',                 # ShadowsocksR (base64)

    # Hysteria / TUIC
    r'hysteria://[^\s]+',                         # Hysteria v1
    r'hysteria2://[^\s]+',                        # Hysteria2
    r'hy2://[^\s]+',                              # Hysteria2 abreviado
    r'tuic://[^\s]+',                             # TUIC protocol

    # WireGuard / OpenVPN
    r'wg://[^\s]+',                               # WireGuard
    r'ovpn://[^\s]+',                             # OpenVPN

    # Otros protocolos
    r'tunnel://[^\s]+',                           # Tunnel
    r'gRPC://[^\s]+',                             # gRPC
    r'grpc://[^\s]+',                             # gRPC minuscula
    r'socks://[^\s]+',                            # SOCKS proxy
    r'http://127\.\d+\.\d+:\d+',                 # Localhost proxy (127.x.x.x:port)

    # Base64 encoded configs (las configs completas suelen ser base64 muy largo)
    r'[A-Za-z0-9+/]{100,}={0,2}',               # Base64 string largo (>100 chars = config)

    # Links cortos de sharing de configs
    r'https?://[^\s]*\?.*?(node|config|sub|subscribe|token)=[^\s]+',  # Subscription links
    r'https?://[^\s]*\.txt$',                    # .txt subscription links
    r'https?://[^\s]*\.yaml$',                   # .yaml config links
    r'https?://[^\s]*\.yml$',                    # .yml config links
    r'https?://[^\s]*\.json$',                   # .json config links
]

COMBINED_LINK_REGEX = re.compile('|'.join(LINK_PATTERNS), re.IGNORECASE)
VPN_LINK_REGEX = re.compile('|'.join(VPN_PROTOCOL_PATTERNS), re.IGNORECASE)

# Spanish spam keywords (high-confidence spam signals)
SPAM_KEYWORDS = [
    # VPN / proxy spam
    r'vpn\s+gratis', r'proxy\s+gratis', r'hotspot\s+shield', r'nordvpn',
    # Crypto scam
    r'bitcoin\s+gratis', r'criptomoneda\s+gratis', r'mining\s+gratis',
    r'invierte\s+ahora', r'duplica\s+tus', r'gana\s+dinero',
    # Adult / NSFW
    r'xxx', r'porn[oa]?', r'onlyfans', r'cams?\s+en\s+vida',
    r' contenido\s+adulto', r'18\+',
    # Phishing / scam
    r'ganaste\s+un?\s+premio', r'click\s+aqui', r'ver\s+ahora',
    r'no\s+te\s+pierdas', r'ultima\s+oportunidad',
    r'whatsapp\s+gratis', r'instagram\s+gratis',
    # Solicitation
    r'escribe\s+al\s+privado', r'mandame\s+mensaje',
    r'escríbeme\s+al\s+privado', r'escribeme\s+al\s+privado',
    r'contactame', r'contactame\s+por\s+privado',
    # Other spam
    r'follow\s+back', r'sigue\s+mi\s+cuenta',
    r'gratis\s+siempre', r'100%\s+gratis',
    r'abre\s+el\s+link', r'visita\s+mi\s+perfil',
]

SPAM_KEYWORDS_COMPILED = [re.compile(kw, re.IGNORECASE) for kw in SPAM_KEYWORDS]

# Suspicious patterns (phone numbers, @ mentions of other bots, etc.)
SUSPICIOUS_PATTERNS = [
    r'\+\d{7,15}',                               # Phone numbers (international)
    r'@\w+_bot\b',                               # Other bot mentions
    r'@\w+_channel\b',                           # Other channel mentions
    r'@\w+vpn',                                   # VPN bot mentions
]

SUSPICIOUS_COMPILED = [re.compile(p, re.IGNORECASE) for p in SUSPICIOUS_PATTERNS]

# Admin callback data prefixes for ban system
BAN_CALLBACK_PREFIX = "ban_"
UNBAN_CALLBACK_PREFIX = "unban_"

# Default ban durations (in seconds)
BAN_DURATIONS = {
    '1h': 3600,
    '6h': 21600,
    '12h': 43200,
    '1d': 86400,
    '3d': 259200,
    '1w': 604800,      # 1 week
    '2w': 1209600,     # 2 weeks
    '1m': 2592000,     # 1 month (30 days)
    'perm': None,       # Permanent
}

BAN_DURATION_LABELS = {
    '1h': '1 Hora',
    '6h': '6 Horas',
    '12h': '12 Horas',
    '1d': '1 Dia',
    '3d': '3 Dias',
    '1w': '1 Semana',
    '2w': '2 Semanas',
    '1m': '1 Mes',
    'perm': 'PERMANENTE',
}

# Pending ban actions: user_id -> {target_id, target_name, chat_id, reason}
AWAITING_BAN_REASON = {}
AWAITING_BAN_DURATION = {}

SOCIAL = {
    'web': 'https://movivip-network.web.app',
    'tiktok': 'https://www.tiktok.com/@movi.vip.network',
    'youtube': 'https://www.youtube.com/@MoviVIP',
    'telegram_ch': 'https://t.me/MoviVIPNetwork',
    'telegram_group': 'https://t.me/MoviVIPNet',
    'whatsapp_ch': 'https://whatsapp.com/channel/0029Vao0aLj0uVJtDjHc7P24',
    'whatsapp_community': 'https://chat.whatsapp.com/KmEz5Jr8RrH8rN8LJQpZ8V',
    'whatsapp_personal': 'https://wa.me/5730012345678',
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
    db = sqlite3.connect(DB_PATH)
    db.row_factory = sqlite3.Row
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
# BAN SYSTEM DB — GRADE MILITAR
# =============================================================================
def init_ban_db():
    """Initialize ban system tables."""
    db = get_db()
    db.execute("""CREATE TABLE IF NOT EXISTS user_bans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tg_id INTEGER NOT NULL,
        username TEXT,
        first_name TEXT,
        reason TEXT DEFAULT 'link_detected',
        ban_type TEXT DEFAULT 'auto',
        banned_by INTEGER,
        chat_id INTEGER,
        chat_title TEXT,
        duration_key TEXT DEFAULT 'perm',
        banned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        expires_at TIMESTAMP,
        is_active INTEGER DEFAULT 1,
        notes TEXT
    )""")
    db.execute("""CREATE TABLE IF NOT EXISTS ban_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tg_id INTEGER NOT NULL,
        username TEXT,
        action TEXT,
        reason TEXT,
        performed_by INTEGER,
        duration_key TEXT,
        chat_id INTEGER,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )""")
    db.execute("""CREATE TABLE IF NOT EXISTS user_media (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tg_id INTEGER NOT NULL,
        username TEXT,
        first_name TEXT,
        media_type TEXT,
        file_id TEXT,
        file_unique_id TEXT,
        caption TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )""")
    # === MULTI-TEMPLATE TABLES ===
    db.execute("""CREATE TABLE IF NOT EXISTS welcome_templates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        text TEXT NOT NULL,
        is_active INTEGER DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )""")
    db.execute("""CREATE TABLE IF NOT EXISTS ad_templates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        text TEXT NOT NULL,
        is_active INTEGER DEFAULT 0,
        image_file_id TEXT,
        image_type TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )""")
    # === BOT SETTINGS TABLE (media configs: ban media, etc.) ===
    db.execute("""CREATE TABLE IF NOT EXISTS bot_settings (
        key TEXT PRIMARY KEY,
        value TEXT,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )""")
    # === USER STRIKES TABLE (3-strike progressive system) ===
    db.execute("""CREATE TABLE IF NOT EXISTS user_strikes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tg_id INTEGER NOT NULL,
        chat_id INTEGER NOT NULL,
        strike_number INTEGER NOT NULL,
        reason TEXT,
        matched_content TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )""")
    # Track users warned after unban (first re-offense = warning only)
    db.execute("""CREATE TABLE IF NOT EXISTS user_unban_warnings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tg_id INTEGER NOT NULL,
        chat_id INTEGER NOT NULL,
        warned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(tg_id, chat_id)
    )""")
    # === MIGRATION: add image columns to existing ad_templates ===
    try:
        db.execute("ALTER TABLE ad_templates ADD COLUMN image_file_id TEXT")
    except:
        pass
    try:
        db.execute("ALTER TABLE ad_templates ADD COLUMN image_type TEXT")
    except:
        pass
    db.commit()
    db.close()
    logger.info("Ban system + user_media + templates + settings DB initialized")


def is_user_banned(tg_id, chat_id=None):
    """Check if a user is currently banned. Returns ban info dict or None."""
    db = get_db()
    query = (
        "SELECT * FROM user_bans WHERE tg_id=? AND is_active=1 "
        "AND (expires_at IS NULL OR expires_at > datetime('now'))"
    )
    params = [tg_id]
    if chat_id:
        query += " AND (chat_id=? OR chat_id IS NULL)"
        params.append(chat_id)
    query += " ORDER BY banned_at DESC LIMIT 1"
    row = db.execute(query, params).fetchone()
    db.close()
    if row:
        return dict(row)
    return None


def ban_user(tg_id, username, first_name, reason, ban_type, banned_by,
             chat_id, chat_title, duration_key='perm', notes=None):
    """Ban a user. Returns True if banned, False if already banned."""
    db = get_db()
    # Check if already banned
    existing = db.execute(
        "SELECT id FROM user_bans WHERE tg_id=? AND is_active=1 "
        "AND (expires_at IS NULL OR expires_at > datetime('now'))",
        (tg_id,)
    ).fetchone()
    if existing:
        db.close()
        return False

    # Calculate expires_at
    duration_secs = BAN_DURATIONS.get(duration_key)
    expires_at = None
    if duration_secs is not None:
        expires_at = (datetime.datetime.now() + datetime.timedelta(seconds=duration_secs)).strftime('%Y-%m-%d %H:%M:%S')

    db.execute(
        "INSERT INTO user_bans (tg_id, username, first_name, reason, ban_type, "
        "banned_by, chat_id, chat_title, duration_key, expires_at, notes) "
        "VALUES (?,?,?,?,?,?,?,?,?,?,?)",
        (tg_id, username, first_name, reason, ban_type, banned_by,
         chat_id, chat_title, duration_key, expires_at, notes)
    )
    # Log
    db.execute(
        "INSERT INTO ban_log (tg_id, username, action, reason, performed_by, duration_key, chat_id) "
        "VALUES (?,?,?,?,?,?,?)",
        (tg_id, username, 'ban', reason, banned_by, duration_key, chat_id)
    )
    db.commit()
    db.close()
    return True


def unban_user(tg_id, unbanned_by, reason='manual_unban'):
    """Unban a user. Returns True if unbanned."""
    db = get_db()
    db.execute(
        "UPDATE user_bans SET is_active=0 WHERE tg_id=? AND is_active=1",
        (tg_id,)
    )
    db.execute(
        "INSERT INTO ban_log (tg_id, action, reason, performed_by) VALUES (?,?,?,?)",
        (tg_id, 'unban', reason, unbanned_by)
    )
    db.commit()
    db.close()
    return True


def get_active_bans(limit=50):
    """Get all active bans."""
    db = get_db()
    rows = db.execute(
        "SELECT * FROM user_bans WHERE is_active=1 "
        "AND (expires_at IS NULL OR expires_at > datetime('now')) "
        "ORDER BY banned_at DESC LIMIT ?",
        (limit,)
    ).fetchall()
    db.close()
    return [dict(r) for r in rows]


def get_all_bans(limit=50):
    """Get all bans (active and expired)."""
    db = get_db()
    rows = db.execute(
        "SELECT * FROM user_bans ORDER BY banned_at DESC LIMIT ?",
        (limit,)
    ).fetchall()
    db.close()
    return [dict(r) for r in rows]


def cleanup_expired_bans():
    """Mark expired temporary bans as inactive. Returns count of unbanned."""
    db = get_db()
    result = db.execute(
        "UPDATE user_bans SET is_active=0 "
        "WHERE is_active=1 AND expires_at IS NOT NULL AND expires_at <= datetime('now')"
    )
    count = result.rowcount
    if count > 0:
        # Log the auto-unbans
        db.execute(
            "INSERT INTO ban_log (tg_id, action, reason, performed_by) "
            "SELECT tg_id, 'auto_unban', 'expired', 0 FROM user_bans "
            "WHERE is_active=0 AND expires_at IS NOT NULL AND expires_at <= datetime('now') "
            "AND id NOT IN (SELECT id FROM ban_log WHERE action='auto_unban' AND reason='expired')"
        )
    db.commit()
    db.close()
    if count > 0:
        logger.info(f"Auto-unbanned {count} expired bans")
    return count


def get_ban_stats():
    """Get ban statistics."""
    db = get_db()
    active = db.execute(
        "SELECT COUNT(*) FROM user_bans WHERE is_active=1 "
        "AND (expires_at IS NULL OR expires_at > datetime('now'))"
    ).fetchone()[0]
    permanent = db.execute(
        "SELECT COUNT(*) FROM user_bans WHERE is_active=1 AND duration_key='perm' "
        "AND (expires_at IS NULL OR expires_at > datetime('now'))"
    ).fetchone()[0]
    temporary = active - permanent
    total = db.execute("SELECT COUNT(*) FROM user_bans").fetchone()[0]
    total_logs = db.execute("SELECT COUNT(*) FROM ban_log").fetchone()[0]
    db.close()
    return {'active': active, 'permanent': permanent, 'temporary': temporary, 'total': total, 'total_logs': total_logs}


# =============================================================================
# USER STRIKES — progressive 3-strike system
# =============================================================================
def add_strike(tg_id, chat_id, reason, matched_content=None):
    """Add a strike to a user. Returns the new strike count."""
    db = get_db()
    # Get current strike count
    row = db.execute(
        "SELECT COUNT(*) FROM user_strikes WHERE tg_id=? AND chat_id=?",
        (tg_id, chat_id)
    ).fetchone()
    strike_count = row[0] + 1 if row else 1
    db.execute(
        "INSERT INTO user_strikes (tg_id, chat_id, strike_number, reason, matched_content) VALUES (?, ?, ?, ?, ?)",
        (tg_id, chat_id, strike_count, reason, matched_content)
    )
    db.commit()
    db.close()
    return strike_count


def get_strike_count(tg_id, chat_id):
    """Get current strike count for a user."""
    db = get_db()
    row = db.execute(
        "SELECT COUNT(*) FROM user_strikes WHERE tg_id=? AND chat_id=?",
        (tg_id, chat_id)
    ).fetchone()
    db.close()
    return row[0] if row else 0


def reset_strikes(tg_id, chat_id):
    """Reset all strikes for a user (used after manual unban)."""
    db = get_db()
    db.execute(
        "DELETE FROM user_strikes WHERE tg_id=? AND chat_id=?",
        (tg_id, chat_id)
    )
    db.commit()
    db.close()


def set_unban_warning(tg_id, chat_id):
    """Mark user as warned after unban (first re-offense = warning only)."""
    db = get_db()
    db.execute(
        "INSERT OR REPLACE INTO user_unban_warnings (tg_id, chat_id) VALUES (?, ?)",
        (tg_id, chat_id)
    )
    db.commit()
    db.close()


def has_unban_warning(tg_id, chat_id):
    """Check if user was warned after unban (and hasn't re-offended yet)."""
    db = get_db()
    row = db.execute(
        "SELECT 1 FROM user_unban_warnings WHERE tg_id=? AND chat_id=?",
        (tg_id, chat_id)
    ).fetchone()
    db.close()
    return row is not None


def clear_unban_warning(tg_id, chat_id):
    """Clear unban warning (user re-offended and was warned/kicked)."""
    db = get_db()
    db.execute(
        "DELETE FROM user_unban_warnings WHERE tg_id=? AND chat_id=?",
        (tg_id, chat_id)
    )
    db.commit()
    db.close()


# =============================================================================
# USER MEDIA STORAGE — media que los usuarios envian al bot (privado)
# =============================================================================
MEDIA_DIR = str(BOT_DIR / "user_media")
os.makedirs(MEDIA_DIR, exist_ok=True)


def store_user_media(tg_id, username, first_name, media_type, file_id, file_unique_id=None, caption=None):
    """Store media that a user sent to the bot (privately)."""
    try:
        db = get_db()
        db.execute(
            "INSERT INTO user_media (tg_id, username, first_name, media_type, file_id, file_unique_id, caption) "
            "VALUES (?,?,?,?,?,?,?)",
            (tg_id, username, first_name, media_type, file_id, file_unique_id, caption)
        )
        db.commit()
        db.close()
        return True
    except Exception as e:
        logger.error(f"store_user_media: {e}")
        return False


def get_user_last_media(tg_id):
    """Get the most recent media sent by a user to the bot. Returns dict or None."""
    db = get_db()
    row = db.execute(
        "SELECT * FROM user_media WHERE tg_id=? ORDER BY created_at DESC LIMIT 1",
        (tg_id,)
    ).fetchone()
    db.close()
    if row:
        return dict(row)
    return None


def get_user_media_count(tg_id):
    """Count how many media items a user has sent to the bot."""
    db = get_db()
    count = db.execute(
        "SELECT COUNT(*) FROM user_media WHERE tg_id=?",
        (tg_id,)
    ).fetchone()[0]
    db.close()
    return count


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


# ---------------------------------------------------------------------------
# LINK / SPAM DETECTION ENGINE — GRADE MILITAR
# ---------------------------------------------------------------------------
def detect_links_and_spam(text):
    """
    Analyze text for links (regular + VPN protocol links), spam keywords, and suspicious patterns.
    Returns (is_violation, reason, matched_content).
    Only fires for NON-ADMIN users.
    """
    if not text:
        return False, None, None

    text_clean = text.strip()

    # 1. Check for ANY regular link (http, t.me, bit.ly, etc.)
    link_match = COMBINED_LINK_REGEX.search(text_clean)
    if link_match:
        return True, 'link_detected', link_match.group(0)

    # 2. Check for VPN protocol links (vmess://, vless://, trojan://, ss://, etc.)
    vpn_match = VPN_LINK_REGEX.search(text_clean)
    if vpn_match:
        matched = vpn_match.group(0)
        # Determine specific VPN type for better logging
        vpn_type = 'vpn_config'
        if matched.startswith('vmess://'):
            vpn_type = 'vmess_config'
        elif matched.startswith('vless://'):
            vpn_type = 'vless_config'
        elif matched.startswith('trojan://'):
            vpn_type = 'trojan_config'
        elif matched.startswith('ss://'):
            vpn_type = 'shadowsocks_config'
        elif matched.startswith('ssr://'):
            vpn_type = 'shadowsocksr_config'
        elif matched.startswith('hysteria') or matched.startswith('hy2://'):
            vpn_type = 'hysteria_config'
        elif matched.startswith('tuic://'):
            vpn_type = 'tuic_config'
        elif len(matched) > 200:
            vpn_type = 'base64_config'
        return True, 'link_detected', f"[{vpn_type}] {matched[:200]}"

    # 3. Check for spam keywords
    for pattern in SPAM_KEYWORDS_COMPILED:
        kw_match = pattern.search(text_clean)
        if kw_match:
            return True, 'spam_keyword', kw_match.group(0)

    # 4. Check suspicious patterns (phone numbers, bot mentions)
    for pattern in SUSPICIOUS_COMPILED:
        susp_match = pattern.search(text_clean)
        if susp_match:
            return True, 'suspicious_pattern', susp_match.group(0)

    return False, None, None


async def _restrict_user(context, chat_id, user_id):
    """Restrict a user in a group: no text, no media, no stickers, no nothing.
    Only allows viewing messages (read-only)."""
    try:
        await context.bot.restrict_chat_member(
            chat_id=chat_id,
            user_id=user_id,
            permissions=ChatPermissions(
                can_send_messages=False,
                can_send_audios=False,
                can_send_documents=False,
                can_send_photos=False,
                can_send_videos=False,
                can_send_video_notes=False,
                can_send_voice_notes=False,
                can_send_polls=False,
                can_send_other_messages=False,
                can_add_web_page_previews=False,
                can_invite_users=False,
                can_change_info=False,
                can_pin_messages=False,
                can_manage_topics=False,
            )
        )
        return True
    except Exception as e:
        logger.error(f"restrict_user({user_id} in {chat_id}): {e}")
        return False


async def _unrestrict_user(context, chat_id, user_id):
    """Restore default permissions for a user (allow messages again).
    Also calls unban_chat_member as safety net in case user was kicked."""
    try:
        # First: unban in case they were kicked/banned (safe even if not banned)
        try:
            await context.bot.unban_chat_member(chat_id=chat_id, user_id=user_id)
        except:
            pass
        # Then: restore full permissions
        await context.bot.restrict_chat_member(
            chat_id=chat_id,
            user_id=user_id,
            permissions=ChatPermissions(
                can_send_messages=True,
                can_send_audios=True,
                can_send_documents=True,
                can_send_photos=True,
                can_send_videos=True,
                can_send_video_notes=True,
                can_send_voice_notes=True,
                can_send_polls=True,
                can_send_other_messages=True,
                can_add_web_page_previews=True,
                can_invite_users=True,
                can_change_info=False,
                can_pin_messages=False,
                can_manage_topics=False,
            )
        )
        return True
    except Exception as e:
        logger.error(f"unrestrict_user({user_id} in {chat_id}): {e}")
        return False


async def kick_user(context, chat_id, user_id):
    """Kick/expel a user from the group. They can rejoin via link unless banned."""
    try:
        # ban_chat_member kicks the user immediately
        await context.bot.ban_chat_member(chat_id=chat_id, user_id=user_id)
        # Immediately unban so they CAN rejoin if they want (just kicked, not banned)
        await asyncio.sleep(1)
        await context.bot.unban_chat_member(chat_id=chat_id, user_id=user_id)
        return True
    except Exception as e:
        logger.error(f"kick_user({user_id} in {chat_id}): {e}")
        return False


async def _notify_admin_of_auto_ban(context, user, chat, reason, matched, duration_key):
    """Send alert to admin when auto-ban triggers."""
    duration_label = BAN_DURATION_LABELS.get(duration_key, duration_key)
    username_str = f"@{user.username}" if user.username else "Sin username"
    reason_emoji = {
        'link_detected': '🔗',
        'spam_keyword': '🚫',
        'suspicious_pattern': '⚠️',
        'manual': '👮',
    }.get(reason, '⚠️')

    alert_text = (
        f"🚨 *AUTO-BAN ACTIVADO*\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        f"👤 *Usuario:* {user.first_name} ({username_str})\n"
        f"🆔 *ID:* `{user.id}`\n"
        f"📍 *Grupo:* {chat.title}\n"
        f"{reason_emoji} *Razon:* {reason}\n"
        f"🔍 *Detectado:* `{matched[:100]}`\n"
        f"⏰ *Duracion:* {duration_label}\n\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        f"✅ El usuario fue *silenciado* automaticamente.\n"
        f"🔓 /unban `{user.id}` — desbanear\n"
        f"📋 /banlist — ver baneados"
    )

    for admin_id in ADMIN_IDS:
        try:
            await context.bot.send_message(
                chat_id=admin_id,
                text=alert_text,
                parse_mode=ParseMode.MARKDOWN
            )
        except Exception as e:
            logger.error(f"Notify admin {admin_id} of auto-ban: {e}")


async def _post_ban_to_group(context, chat_id, user, reason, matched, duration_key, media=None):
    """
    Post ban notice in the group: first the user's media (if any), then the ban message.
    This is the CORE function — shows media + ban details in the group.
    """
    duration_label = BAN_DURATION_LABELS.get(duration_key, duration_key)
    username_str = f"@{user.username}" if user.username else "Sin username"
    now_str = datetime.datetime.now().strftime('%d/%m/%Y %H:%M:%S')

    reason_labels = {
        'link_detected': '🔗 Envio de enlaces prohibidos',
        'spam_keyword': '🚫 Palabras clave de spam detectadas',
        'suspicious_pattern': '⚠️ Contenido sospechoso',
        'forwarded_from_channel': '📨 Reenvio desde canal externo',
        'document_sent': '📎 Envio de archivos/documentos prohibido',
        'manual': '👮 Baneado por administrador',
    }
    reason_text = reason_labels.get(reason, f'⚠️ {reason}')

    # Get the specific rule violated
    rule_info = get_violation_rule(reason)
    rule_num = rule_info.get('rule_num', '?')
    rule_title = rule_info.get('rule_title', reason)
    rule_detail = rule_info.get('rule_detail', '')

    # Get full rules for the user
    full_rules = get_rules_text()

    # Truncate matched content for display
    matched_display = matched[:120] if matched else "N/A"

    ban_text = (
        f"🚨 *USUARIO BANEADO*\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        f"👤 *Usuario:* {user.first_name} ({username_str})\n"
        f"🆔 *ID Telegram:* `{user.id}`\n"
        f"📍 *Grupo:* {chat_id}\n\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        f"❌ *REGLA VIOLADA #{rule_num}*\n"
        f"📝 *{rule_title}*\n"
        f"📌 {rule_detail}\n"
        f"🔍 *Detectado:* `{matched_display}`\n\n"
        f"⏰ *Duracion del ban:* {duration_label}\n"
        f"🕐 *Fecha:* {now_str}\n\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        f"❌ *Este usuario ha sido silenciado automaticamente.*\n"
        f"🔒 No podra enviar mensajes, fotos, videos ni links.\n"
        f"🔓 Solo un administrador puede desbanearlo.\n\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    )

    # If user has media stored from the bot, send it first
    if media and media.get('file_id'):
        try:
            file_id = media['file_id']
            media_type = media.get('media_type', 'photo')
            caption_media = (
                f"📸 *Ultima media enviada por el usuario baneado*\n"
                f"👤 {user.first_name} ({username_str})\n"
                f"🆔 `{user.id}`"
            )

            if media_type == 'photo':
                await context.bot.send_photo(
                    chat_id=chat_id,
                    photo=file_id,
                    caption=caption_media,
                    parse_mode=ParseMode.MARKDOWN
                )
            elif media_type == 'video':
                await context.bot.send_video(
                    chat_id=chat_id,
                    video=file_id,
                    caption=caption_media,
                    parse_mode=ParseMode.MARKDOWN
                )
            elif media_type == 'animation':  # GIF
                await context.bot.send_animation(
                    chat_id=chat_id,
                    animation=file_id,
                    caption=caption_media,
                    parse_mode=ParseMode.MARKDOWN
                )
            elif media_type == 'document':
                await context.bot.send_document(
                    chat_id=chat_id,
                    document=file_id,
                    caption=caption_media,
                    parse_mode=ParseMode.MARKDOWN
                )
            else:
                # Fallback: try photo
                await context.bot.send_photo(
                    chat_id=chat_id,
                    photo=file_id,
                    caption=caption_media,
                    parse_mode=ParseMode.MARKDOWN
                )
        except Exception as e:
            logger.warning(f"Could not send user media to group: {e}")
            # If media fails, just send text ban message
            pass

    # Send the admin-configured BAN media (image/GIF/video/sticker set by admin)
    ban_file_id, ban_media_type = get_ban_media()
    if ban_file_id:
        try:
            if ban_media_type == 'photo':
                await context.bot.send_photo(
                    chat_id=chat_id,
                    photo=ban_file_id
                )
            elif ban_media_type == 'video':
                await context.bot.send_video(
                    chat_id=chat_id,
                    video=ban_file_id
                )
            elif ban_media_type == 'animation':
                await context.bot.send_animation(
                    chat_id=chat_id,
                    animation=ban_file_id
                )
            elif ban_media_type == 'sticker':
                await context.bot.send_sticker(
                    chat_id=chat_id,
                    sticker=ban_file_id
                )
            else:
                await context.bot.send_photo(
                    chat_id=chat_id,
                    photo=ban_file_id
                )
        except Exception as e:
            logger.warning(f"Could not send configured ban media: {e}")

    # Send the ban message
    try:
        await context.bot.send_message(
            chat_id=chat_id,
            text=ban_text,
            parse_mode=ParseMode.MARKDOWN
        )
    except Exception as e:
        logger.error(f"Post ban to group {chat_id}: {e}")
        # Fallback without markdown
        try:
            plain_text = ban_text.replace('*', '').replace('`', '')
            await context.bot.send_message(chat_id=chat_id, text=plain_text)
        except:
            pass


# ---------------------------------------------------------------------------
# PRIVATE MEDIA HANDLER — users send media to the bot in private chat
# ---------------------------------------------------------------------------
async def handle_private_media(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """
    Handle media sent to the bot in PRIVATE chat.
    - If admin is waiting for ban media → save as ban media config
    - Otherwise → stores the media so it can be shown if user gets banned
    """
    if not update.message:
        return

    # Only handle private chats (not groups)
    chat = update.effective_chat
    if chat.type != 'private':
        return

    user = update.effective_user
    if not user or user.is_bot:
        return

    # --- ADMIN: Ban media upload ---
    if is_admin(user.id) and AWAITING_BAN_MEDIA.get(user.id):
        media_type = None
        file_id = None
        if update.message.photo:
            media_type = 'photo'
            file_id = update.message.photo[-1].file_id
        elif update.message.video:
            media_type = 'video'
            file_id = update.message.video.file_id
        elif update.message.animation:
            media_type = 'animation'
            file_id = update.message.animation.file_id
        elif update.message.sticker:
            media_type = 'sticker'
            file_id = update.message.sticker.file_id
        else:
            # Invalid type — DON'T consume AWAITING, let user retry
            await update.message.reply_text(
                "❌ *Tipo no valido.*\n\n"
                "Solo se acepta:\n"
                "🖼️ Foto\n"
                "🎞️ GIF/Animation\n"
                "🎬 Video\n"
                "🏷️ Sticker\n\n"
                "Envia el tipo correcto o /cancel para salir.",
                parse_mode=ParseMode.MARKDOWN
            )
            return

        AWAITING_BAN_MEDIA.pop(user.id, None)  # Only consume on success
        set_ban_media(file_id, media_type)
        type_emoji = {'photo': '🖼️', 'video': '🎬', 'animation': '🎞️', 'sticker': '🏷️'}.get(media_type, '📎')
        await update.message.reply_text(
            f"✅ *IMAGEN DE BAN CONFIGURADA*\n"
            f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
            f"{type_emoji} Tipo: *{media_type}*\n"
            f"📁 ID guardado: `{file_id[:30]}...`\n\n"
            f"Ahora cuando alguien sea baneado,\n"
            f"esta imagen se enviara junto con el mensaje.\n\n"
            f"👁️ /preview — probar bienvenida\n"
            f"⚙️ /config — volver al panel",
            parse_mode=ParseMode.MARKDOWN,
            reply_markup=_config_menu_kb()
        )
        logger.info(f"Admin {user.id} configured ban media: {media_type}")
        return

    # --- ADMIN: Ad template image upload ---
    if is_admin(user.id) and AWAITING_AD_IMAGE.get(user.id):
        tpl_id = AWAITING_AD_IMAGE.pop(user.id)
        media_type = None
        file_id = None
        if update.message.photo:
            media_type = 'photo'
            file_id = update.message.photo[-1].file_id
        elif update.message.video:
            media_type = 'video'
            file_id = update.message.video.file_id
        elif update.message.animation:
            media_type = 'animation'
            file_id = update.message.animation.file_id
        elif update.message.sticker:
            media_type = 'sticker'
            file_id = update.message.sticker.file_id
        else:
            AWAITING_AD_IMAGE[user.id] = tpl_id  # re-set so user can retry
            await update.message.reply_text(
                "❌ *Tipo no valido.*\n\n"
                "Solo se acepta:\n"
                "🖼️ Foto\n"
                "🎞️ GIF/Animation\n"
                "🎬 Video\n"
                "🏷️ Sticker\n\n"
                "Envia el tipo correcto o /cancel para salir.",
                parse_mode=ParseMode.MARKDOWN
            )
            return

        update_template("ad_templates", tpl_id, image_file_id=file_id, image_type=media_type)
        type_emoji = {'photo': '🖼️', 'video': '🎬', 'animation': '🎞️', 'sticker': '🏷️'}.get(media_type, '📎')
        await update.message.reply_text(
            f"✅ *IMAGEN ASIGNADA A PLANTILLA #{tpl_id}*\n"
            f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
            f"{type_emoji} Tipo: *{media_type}*\n"
            f"📁 ID guardado: `{file_id[:30]}...`\n\n"
            f"Ahora al enviar publicidad,\n"
            f"esta imagen se enviara con el texto.\n\n"
            f"👁️ /preview — probar publicidad\n"
            f"⚙️ /config — volver al panel",
            parse_mode=ParseMode.MARKDOWN,
            reply_markup=_config_menu_kb()
        )
        logger.info(f"Admin {user.id} set image for ad template #{tpl_id}: {media_type}")
        return

    # Admin but not awaiting → skip
    if is_admin(user.id):
        return

    # Detect media type and file_id
    media_type = None
    file_id = None
    file_unique_id = None
    caption = update.message.caption or ""

    if update.message.photo:
        media_type = 'photo'
        file_id = update.message.photo[-1].file_id
        file_unique_id = update.message.photo[-1].file_unique_id
    elif update.message.video:
        media_type = 'video'
        file_id = update.message.video.file_id
        file_unique_id = update.message.video.file_unique_id
    elif update.message.animation:  # GIF
        media_type = 'animation'
        file_id = update.message.animation.file_id
        file_unique_id = update.message.animation.file_unique_id
    elif update.message.document:
        media_type = 'document'
        file_id = update.message.document.file_id
        file_unique_id = update.message.document.file_unique_id

    if not media_type or not file_id:
        return

    # Store in DB
    store_user_media(
        tg_id=user.id,
        username=user.username,
        first_name=user.first_name,
        media_type=media_type,
        file_id=file_id,
        file_unique_id=file_unique_id,
        caption=caption
    )

    logger.info(f"Private media stored: user {user.id} ({user.first_name}) -> {media_type}")

    # Confirm to user
    media_emojis = {
        'photo': '📸',
        'video': '🎬',
        'animation': '🎞️',
        'document': '📎',
    }
    emoji = media_emojis.get(media_type, '📁')
    try:
        await update.message.reply_text(
            f"{emoji} *Media recibida y guardada*\n\n"
            f"Tu {media_type} ha sido almacenada correctamente.\n"
            f"Si envias un link no autorizado en el grupo, esta imagen\n"
            f"se publicara junto con el aviso de ban.",
            parse_mode=ParseMode.MARKDOWN
        )
    except:
        pass


# ---------------------------------------------------------------------------
# PRIVATE TEXT HANDLER — respond to text from non-admin users in private chat
# ---------------------------------------------------------------------------
async def handle_private_text(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle text messages from non-admin users in private chat."""
    if not update.message or not update.message.text:
        return

    chat = update.effective_chat
    if chat.type != 'private':
        return

    user = update.effective_user
    if not user or user.is_bot:
        return

    if is_admin(user.id):
        return

    # Simple response for private chat
    try:
        await update.message.reply_text(
            "🤖 *MoviVIP Bot*\n\n"
            "Puedes enviarme *fotos, videos o GIFs* y seran guardados.\n\n"
            "⚠️ Si envias links no autorizados en el grupo, sera baneado\n"
            "y tu media se publicara como aviso.\n\n"
            "Si tienes dudas, contacta al administrador.",
            parse_mode=ParseMode.MARKDOWN
        )
    except:
        pass


# ---------------------------------------------------------------------------
# FILE BLOCKING HANDLER — no-admin users cannot send files/documents
# ---------------------------------------------------------------------------
async def enforce_no_files(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """
    BLOCK documents/files from non-admin users in groups.
    If a non-admin sends any file → AUTO-BAN immediately.
    """
    if not update.message:
        return
    detect_chat_id(update.effective_chat.id, update.effective_chat.type, getattr(update.effective_chat, 'title', None))

    msg = update.message
    user = update.effective_user
    chat = update.effective_chat

    if not user or user.is_bot:
        return

    # NEVER block admins
    if is_admin(user.id):
        return

    # Only block in groups
    if chat.type not in ('group', 'supergroup'):
        return

    # Check if already banned
    existing_ban = is_user_banned(user.id, chat.id)
    if existing_ban:
        try:
            await msg.delete()
        except:
            pass
        return

    # Check if message has a document/file
    has_file = bool(msg.document)
    file_name = msg.document.file_name if msg.document else "N/A"

    if not has_file:
        return

    # === AUTO-BAN FOR SENDING FILES ===
    logger.warning(f"FILE-BAN: user {user.id} ({user.first_name}) sent file '{file_name}' in {chat.title}")

    # Get user's last media from the bot (if any)
    user_media = get_user_last_media(user.id)

    # Ban in DB
    ban_user(
        tg_id=user.id,
        username=user.username,
        first_name=user.first_name,
        reason='document_sent',
        ban_type='auto',
        banned_by=0,
        chat_id=chat.id,
        chat_title=chat.title,
        duration_key=AUTO_BAN_DEFAULT_DURATION,
        notes=f"Sent file: {file_name}"
    )

    # Restrict in Telegram
    await _restrict_user(context, chat.id, user.id)

    # Delete the file
    try:
        await msg.delete()
    except Exception as e:
        logger.warning(f"Could not delete file message: {e}")

    # Post media + ban message in the group
    await _post_ban_to_group(context, chat.id, user, 'document_sent', file_name, AUTO_BAN_DEFAULT_DURATION, user_media)

    # Also notify admin
    await _notify_admin_of_auto_ban(context, user, chat, 'document_sent', file_name, AUTO_BAN_DEFAULT_DURATION)


# ---------------------------------------------------------------------------
# AUTO-BAN ENFORCEMENT HANDLER — intercept ALL messages in groups
# ---------------------------------------------------------------------------
# Default ban duration for auto-bans (change this to customize)
AUTO_BAN_DEFAULT_DURATION = 'perm'  # Options: '1h','6h','12h','1d','3d','1w','2w','1m','perm'

# Users who recently got banned — avoid spamming ban messages
_RECENTLY_BANNED_CACHE = set()


async def enforce_anti_spam(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """
    Main anti-spam handler. Runs on EVERY text/media message in groups.
    - Detects links, spam keywords, suspicious patterns
    - Auto-bans the user (individual, not group-wide)
    - Restricts them (can't send messages)
    - Notifies admin
    """
    if not update.message:
        return
    detect_chat_id(update.effective_chat.id, update.effective_chat.type, getattr(update.effective_chat, 'title', None))

    msg = update.message
    user = update.effective_user
    chat = update.effective_chat

    if not user or user.is_bot:
        return

    # NEVER ban admins
    if is_admin(user.id):
        return

    # Check if user is already banned
    existing_ban = is_user_banned(user.id, chat.id)
    if existing_ban:
        # User is banned but somehow still sending — restrict again
        if user.id not in _RECENTLY_BANNED_CACHE:
            await _restrict_user(context, chat.id, user.id)
            _RECENTLY_BANNED_CACHE.add(user.id)
            # Remove from cache after 60 seconds
            asyncio.get_event_loop().call_later(
                60, lambda: _RECENTLY_BANNED_CACHE.discard(user.id)
            )
        return

    # Get text content (text, caption, or file_name for documents)
    text = msg.text or msg.caption or ""

    # Also check for forwarded messages from channels (common spam vector)
    # python-telegram-bot v20+ uses forward_origin instead of forward_from_chat
    forward_origin = getattr(msg, 'forward_origin', None)
    if forward_origin is not None:
        origin_type = type(forward_origin).__name__
        # MessageOriginChannel or MessageOriginChat = forwarded from channel/group
        if origin_type in ('MessageOriginChannel', 'MessageOriginChat'):
            is_violation = True
            reason = 'forwarded_from_channel'
            matched = getattr(forward_origin, 'chat', None)
            matched = getattr(matched, 'title', None) or "Canal desconocido"
        else:
            # Forwarded from a user or unknown origin — still check text
            is_violation, reason, matched = detect_links_and_spam(text)
    else:
        # Check text content
        is_violation, reason, matched = detect_links_and_spam(text)

    # Also check for documents with suspicious names
    if not is_violation and msg.document:
        doc_name = msg.document.file_name or ""
        if doc_name:
            is_violation, reason, matched = detect_links_and_spam(doc_name)

    if not is_violation:
        return

    # === VIOLATION DETECTED — 3-STRIKE PROGRESSIVE SYSTEM ===
    logger.warning(f"VIOLATION: user {user.id} ({user.first_name}) in {chat.title}: {reason} -> {matched}")

    # Delete the offending message FIRST
    try:
        await msg.delete()
    except Exception as e:
        logger.warning(f"Could not delete spam message: {e}")

    # Check if user was recently unbanned (first re-offense = warning only)
    if has_unban_warning(user.id, chat.id):
        clear_unban_warning(user.id, chat.id)
        # This is their first offense after unban — WARNING ONLY
        rules = get_rules_text()
        warning_text = (
            f"⚠️ *ADVERTENCIA — DESPUES DE DESBANEO*\n"
            f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
            f"👤 {user.first_name} (`{user.id}`)\n"
            f"📝 Motivo: *{reason}*\n\n"
            f"📬 *REGLAS DEL GRUPO:*\n{rules}\n\n"
            f"🚨 *ATENCION:* Fuiste desbaneado recientemente.\n"
            f"Si vuelves a infringer seras *EXPULSADO del grupo*.\n\n"
            f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        )
        try:
            await context.bot.send_message(chat_id=chat.id, text=warning_text, parse_mode=ParseMode.MARKDOWN)
        except Exception as e:
            logger.warning(f"Could not send unban warning: {e}")
        logger.info(f"UNBAN WARNING: {user.id} warned after unban in {chat.title}")
        return

    # Add strike to DB
    strike_count = add_strike(user.id, chat.id, reason, matched[:200] if matched else None)

    if strike_count == 1:
        # === STRIKE 1: WARNING + RULES (no ban) ===
        rules = get_rules_text()
        warning_text = (
            f"⚠️ *ADVERTENCIA — Strike 1 de 3*\n"
            f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
            f"👤 {user.first_name} (`{user.id}`)\n"
            f"📝 Motivo: *{reason}*\n\n"
            f"📬 *REGLAS DEL GRUPO:*\n{rules}\n\n"
            f"⚠️ Tu proxima infraccion sera un *baneo temporal de 1 semana*.\n"
            f"🚫 La tercera infraccion sera *EXPULSADO del grupo*.\n\n"
            f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        )
        try:
            await context.bot.send_message(chat_id=chat.id, text=warning_text, parse_mode=ParseMode.MARKDOWN)
        except Exception as e:
            logger.warning(f"Could not send warning: {e}")
        logger.info(f"STRIKE 1: {user.id} warned in {chat.title}")

    elif strike_count == 2:
        # === STRIKE 2: 1 WEEK BAN ===
        duration_key = '1w'
        user_media = get_user_last_media(user.id)
        ban_user(
            tg_id=user.id, username=user.username, first_name=user.first_name,
            reason=reason, ban_type='auto', banned_by=0,
            chat_id=chat.id, chat_title=chat.title,
            duration_key=duration_key, notes=f"Strike 2: {matched[:200] if matched else ''}"
        )
        await _restrict_user(context, chat.id, user.id)
        await _post_ban_to_group(context, chat.id, user, reason, matched, duration_key, user_media)
        await _notify_admin_of_auto_ban(context, user, chat, reason, matched, duration_key)
        logger.info(f"STRIKE 2: {user.id} banned 1w in {chat.title}")

    else:
        # === STRIKE 3+: PERMANENT BAN + KICK FROM GROUP ===
        duration_key = 'perm'
        user_media = get_user_last_media(user.id)
        ban_user(
            tg_id=user.id, username=user.username, first_name=user.first_name,
            reason=reason, ban_type='auto', banned_by=0,
            chat_id=chat.id, chat_title=chat.title,
            duration_key=duration_key, notes=f"Strike {strike_count} PERMANENT+KICK: {matched[:200] if matched else ''}"
        )
        await _restrict_user(context, chat.id, user.id)
        # KICK from group (expel them)
        kicked = await kick_user(context, chat.id, user.id)
        await _post_ban_to_group(context, chat.id, user, reason, matched, duration_key, user_media)
        await _notify_admin_of_auto_ban(context, user, chat, reason, matched, duration_key)
        if kicked:
            logger.info(f"STRIKE {strike_count} KICKED: {user.id} expelled from {chat.title}")
        else:
            logger.info(f"STRIKE {strike_count} PERMANENT: {user.id} banned in {chat.title} (kick failed)")


# ---------------------------------------------------------------------------
# MULTIMEDIA HANDLER — allow GIFs, videos, photos from normal users
# (The original bot only handled admin photo uploads. This allows regular
#  users to send media while still checking for spam in captions.)
# ---------------------------------------------------------------------------
async def handle_user_media(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """
    Handle media (photos, videos, GIFs, documents) from ALL users.
    - Normal users: allowed to send media (check caption for spam)
    - Banned users: blocked
    - Admin: original behavior (set_welcome, set_ad, etc.)
    """
    if not update.message:
        return
    if update.effective_chat:
        detect_chat_id(update.effective_chat.id, update.effective_chat.type, getattr(update.effective_chat, 'title', None))

    user = update.effective_user
    chat = update.effective_chat

    if not user or user.is_bot:
        return

    # Admin media handling — already handled by handle_admin_photo
    if is_admin(user.id):
        return  # Let the existing admin handler deal with it

    # Check if banned
    existing_ban = is_user_banned(user.id, chat.id)
    if existing_ban:
        await _restrict_user(context, chat.id, user.id)
        try:
            await update.message.delete()
        except:
            pass
        return

    # Check caption for spam/links
    caption = update.message.caption or ""
    if caption:
        is_violation, reason, matched = detect_links_and_spam(caption)
        if is_violation:
            # Get user's last media from the bot (if any)
            user_media = get_user_last_media(user.id)

            # Auto-ban
            ban_user(
                tg_id=user.id,
                username=user.username,
                first_name=user.first_name,
                reason=reason,
                ban_type='auto',
                banned_by=0,
                chat_id=chat.id,
                chat_title=chat.title,
                duration_key=AUTO_BAN_DEFAULT_DURATION,
                notes=f"Caption spam: {matched[:200]}"
            )
            await _restrict_user(context, chat.id, user.id)

            # Delete the offending media message
            try:
                await update.message.delete()
            except:
                pass

            # Post media + ban message in the group
            await _post_ban_to_group(context, chat.id, user, reason, matched, AUTO_BAN_DEFAULT_DURATION, user_media)

            # Also notify admin privately
            await _notify_admin_of_auto_ban(context, user, chat, reason, matched, AUTO_BAN_DEFAULT_DURATION)
            return

    # Media is clean — let it through (no action needed, Telegram handles it)


# ---------------------------------------------------------------------------
# BAN CHECK ON JOIN — prevent banned users from rejoining and chatting
# ---------------------------------------------------------------------------
async def check_banned_member(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """When a new member joins, check if they're banned and restrict if so."""
    if not update.message or not update.message.new_chat_members:
        return

    for member in update.message.new_chat_members:
        if member.is_bot:
            continue

        existing_ban = is_user_banned(member.id)
        if existing_ban:
            await _restrict_user(context, update.effective_chat.id, member.id)
            logger.info(f"Banned user {member.id} ({member.first_name}) tried to join — restricted")

# ---------------------------------------------------------------------------
# IMAGENES CONFIGURABLES (bienvenida / publicidad)
# ---------------------------------------------------------------------------
# user_id -> "welcome" | "ad"   (admin esperando a enviar una foto)
AWAITING_PHOTO = {}


async def _send_media_or_text(context, chat_id, img_path, text, parse_mode=None, reply_markup=None):
    """Envia foto/video si existe; si no, solo texto. Nunca rompe el flujo."""
    if img_path and os.path.exists(img_path):
        try:
            with open(img_path, 'rb') as media:
                if img_path.lower().endswith('.mp4'):
                    await context.bot.send_video(
                        chat_id=chat_id, video=media, caption=text,
                        parse_mode=parse_mode or ParseMode.MARKDOWN,
                        reply_markup=reply_markup)
                else:
                    await context.bot.send_photo(
                        chat_id=chat_id, photo=media, caption=text,
                        parse_mode=parse_mode or ParseMode.MARKDOWN,
                        reply_markup=reply_markup)
            return True
        except Exception as e:
            logger.warning(f"send_media error ({img_path}): {e}")
    try:
        await context.bot.send_message(
            chat_id=chat_id, text=text,
            parse_mode=parse_mode or ParseMode.MARKDOWN,
            reply_markup=reply_markup)
        return True
    except Exception as e:
        logger.warning(f"send_message fallback error: {e}")
        return False


async def _save_media(message, dest_path):
    """Descarga foto o video del mensaje y SOBREESCRIBE el archivo."""
    if not message:
        return False
    if message.photo:
        media_file = await message.photo[-1].get_file()
        # Si es foto, guardar como .jpg
        if dest_path.endswith('.mp4'):
            dest_path = dest_path.replace('.mp4', '.jpg')
        await media_file.download_to_drive(custom_path=dest_path)
        return True
    elif message.video:
        media_file = await message.video.get_file()
        # Si es video, guardar como .mp4
        if dest_path.endswith('.jpg'):
            dest_path = dest_path.replace('.jpg', '.mp4')
        await media_file.download_to_drive(custom_path=dest_path)
        return True
    return False


def _welcome_img_path():
    """Ruta de la imagen de bienvenida: buscar .jpg y .mp4, luego logo como fallback."""
    jpg_path = str(BOT_DIR / "welcome.jpg")
    mp4_path = str(BOT_DIR / "welcome.mp4")
    if os.path.exists(mp4_path):
        return mp4_path
    if os.path.exists(jpg_path):
        return jpg_path
    return LOGO_PATH if os.path.exists(LOGO_PATH) else None


async def handle_admin_photo(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Admin envia una foto: se guarda como imagen de bienvenida o publicidad (reemplaza)."""
    if not update.message or not (update.message.photo or update.message.video):
        return
    user = update.effective_user
    if not is_admin(user.id):
        return

    kind = AWAITING_PHOTO.pop(user.id, None)
    caption = (update.message.caption or "").strip().lower()

    if not kind:
        if caption in ("welcome", "bienvenida", "bienvenido"):
            kind = "welcome"
        elif caption in ("ad", "publicidad", "anuncio", "promo"):
            kind = "ad"
    if not kind:
        return

    is_video = bool(update.message.video)
    media_type = "video" if is_video else "imagen"

    if kind == "welcome":
        dest = str(BOT_DIR / ("welcome.mp4" if is_video else "welcome.jpg"))
    else:
        dest = str(BOT_DIR / ("ad.mp4" if is_video else "ad.jpg"))

    try:
        await _save_media(update.message, dest)
    except Exception as e:
        logger.error(f"save {kind} {media_type}: {e}")
        await update.message.reply_text(f"❌ No pude guardar el {media_type}: {e}")
        return

    label = "BIENVENIDA" if kind == "welcome" else "PUBLICIDAD"
    logger.info(f"Admin {user.id} actualizo {media_type} de {kind} -> {dest}")
    await update.message.reply_text(
        f"✅ <b>{media_type.capitalize()} de {label} guardada</b>\n"
        f"📁 <code>{dest}</code>\n"
        f"↩️ La anterior fue REEMPLAZADA.\n\n"
        f"👁️ /preview - ver la bienvenida\n"
        f"📣 /send_ad - enviar la publicidad",
        parse_mode=ParseMode.HTML,
        reply_markup=_config_menu_kb())


async def cmd_set_welcome(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update.effective_user.id):
        return
    AWAITING_PHOTO[update.effective_user.id] = "welcome"
    await update.message.reply_text(
        "🖼️ Enviame la NUEVA imagen de bienvenida.\n"
        "Se guardara en el VPS y REEMPLAZARA a la anterior.")


async def cmd_set_ad(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update.effective_user.id):
        return
    AWAITING_PHOTO[update.effective_user.id] = "ad"
    await update.message.reply_text(
        "🖼️ Enviame la NUEVA imagen de publicidad.\n"
        "Se guardara en el VPS y REEMPLAZARA a la anterior.")


async def cmd_send_ad(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Envia la publicidad (imagen o texto) al canal y al grupo."""
    if not is_admin(update.effective_user.id):
        return
    await update.message.reply_text("📢 Enviando publicidad...")
    # Get active ad template with its own image
    tpl = get_active_ad_template_full()
    tpl_text = _fill_plantilla(tpl["text"], {"brand": BRAND}) if tpl else get_publicity_text()
    tpl_img = tpl["image_file_id"] if tpl and tpl.get("image_file_id") else AD_IMG
    success = 0
    for chat_id, name in [(CHANNEL_ID, "Canal"), (GROUP_ID, "Grupo")]:
        ok = await _send_media_or_text(context, chat_id, tpl_img, tpl_text)
        success += 1 if ok else 0
        logger.info(f"Ad enviado a {name}: ok={ok}")
    img_source = "plantilla" if tpl and tpl.get("image_file_id") else "global"
    await update.message.reply_text(
        f"✅ Publicidad enviada!\n"
        f"📊 Enviada: {success}/2\n"
        f"🖼️ Imagen: {img_source}")


# ---------------------------------------------------------------------------
# PLANTILLAS DE TEXTO (bienvenida / publicidad) — las define quien configura el VPS
# ---------------------------------------------------------------------------
# user_id -> "welcome" | "ad"   (admin esperando a enviar el texto de la plantilla)
AWAITING_TEXT = {}


def _read_plantilla(path, default_text):
    """Lee la plantilla guardada en el VPS; si no existe usa el texto por defecto."""
    try:
        if os.path.exists(path):
            with open(path, 'r', encoding='utf-8') as f:
                content = f.read().strip()
                if content:
                    return content
    except Exception as e:
        logger.warning(f"read plantilla {path}: {e}")
    return default_text


def _save_plantilla(path, text):
    """Guarda la plantilla en el VPS (SOBREESCRIBE = reemplaza a la anterior)."""
    with open(path, 'w', encoding='utf-8') as f:
        f.write(text.strip())


def _fill_plantilla(text, values):
    """Reemplaza placeholders {clave} de forma segura (no rompe si faltan o sobran)."""
    for key, val in values.items():
        text = text.replace("{" + key + "}", str(val))
    return text


def get_publicity_text():
    """Texto de publicidad: la plantilla activa del admin si existe, si no el default.
    La MARCA ({brand}) del que configura el VPS siempre se inyecta."""
    # Try active template from DB first
    active = get_active_ad_template()
    if active:
        return _fill_plantilla(active, {"brand": BRAND})
    return _fill_plantilla(_read_plantilla(AD_TEXT_FILE, PUBLICITY_TEXT), {"brand": BRAND})


# ---------------------------------------------------------------------------
# MULTI-TEMPLATE SYSTEM — DB-backed templates
# ---------------------------------------------------------------------------
def get_active_welcome_template():
    """Get the active welcome template text from DB. Returns None if no active template."""
    try:
        db = get_db()
        row = db.execute(
            "SELECT text FROM welcome_templates WHERE is_active=1 LIMIT 1"
        ).fetchone()
        db.close()
        return row[0] if row else None
    except Exception:
        return None

def get_active_ad_template():
    """Get the active ad template text from DB. Returns None if no active template."""
    try:
        db = get_db()
        row = db.execute(
            "SELECT text FROM ad_templates WHERE is_active=1 LIMIT 1"
        ).fetchone()
        db.close()
        return row[0] if row else None
    except Exception:
        return None

def get_active_ad_template_full():
    """Get the active ad template with image. Returns dict {text, image_file_id, image_type} or None."""
    try:
        db = get_db()
        row = db.execute(
            "SELECT text, image_file_id, image_type FROM ad_templates WHERE is_active=1 LIMIT 1"
        ).fetchone()
        db.close()
        if row:
            return {"text": row[0], "image_file_id": row[1], "image_type": row[2]}
        return None
    except Exception:
        return None

def list_templates(table):
    """List all templates from a table (welcome_templates or ad_templates)."""
    db = get_db()
    if table == "ad_templates":
        rows = db.execute(
            f"SELECT id, name, is_active, created_at FROM {table} ORDER BY id DESC"
        ).fetchall()
    else:
        rows = db.execute(
            f"SELECT id, name, is_active, created_at FROM {table} ORDER BY id DESC"
        ).fetchall()
    db.close()
    return rows

def get_template_by_id(table, template_id):
    """Get a single template by ID."""
    db = get_db()
    row = db.execute(
        f"SELECT id, name, text, is_active FROM {table} WHERE id=?", (template_id,)
    ).fetchone()
    db.close()
    return row

def save_template(table, name, text, set_active=False, image_file_id=None, image_type=None):
    """Insert a new template. If set_active, deactivate all others and activate this one."""
    db = get_db()
    if set_active:
        db.execute(f"UPDATE {table} SET is_active=0")
    cur = db.execute(
        f"INSERT INTO {table} (name, text, is_active, image_file_id, image_type) VALUES (?, ?, ?, ?, ?)",
        (name, text.strip(), 1 if set_active else 0, image_file_id, image_type)
    )
    db.commit()
    new_id = cur.lastrowid
    db.close()
    return new_id

def update_template(table, template_id, name=None, text=None, set_active=None, image_file_id=None, image_type=None):
    """Update a template's name, text, active status, or image."""
    db = get_db()
    updates = []
    params = []
    if name is not None:
        updates.append("name=?")
        params.append(name)
    if text is not None:
        updates.append("text=?")
        params.append(text.strip())
    if image_file_id is not None:
        updates.append("image_file_id=?")
        params.append(image_file_id)
    if image_type is not None:
        updates.append("image_type=?")
        params.append(image_type)
    if set_active is not None:
        if set_active:
            db.execute(f"UPDATE {table} SET is_active=0")
        updates.append("is_active=?")
        params.append(1 if set_active else 0)
    if updates:
        params.append(template_id)
        db.execute(f"UPDATE {table} SET {', '.join(updates)} WHERE id=?", params)
        db.commit()
    db.close()

def delete_template(table, template_id):
    """Delete a template by ID."""
    db = get_db()
    db.execute(f"DELETE FROM {table} WHERE id=?", (template_id,))
    db.commit()
    db.close()

def activate_template(table, template_id):
    """Activate a template (deactivate all others in same table)."""
    db = get_db()
    db.execute(f"UPDATE {table} SET is_active=0")
    db.execute(f"UPDATE {table} SET is_active=1 WHERE id=?", (template_id,))
    db.commit()
    db.close()


# ---------------------------------------------------------------------------
# BOT SETTINGS — media configs (ban_media, welcome_media, ad_media)
# ---------------------------------------------------------------------------
def get_setting(key, default=None):
    """Get a bot setting from DB."""
    try:
        db = get_db()
        row = db.execute("SELECT value FROM bot_settings WHERE key=?", (key,)).fetchone()
        db.close()
        return row[0] if row else default
    except Exception:
        return default

def set_setting(key, value):
    """Set a bot setting in DB (upsert)."""
    db = get_db()
    db.execute(
        "INSERT OR REPLACE INTO bot_settings (key, value, updated_at) VALUES (?, ?, CURRENT_TIMESTAMP)",
        (key, value)
    )
    db.commit()
    db.close()

def detect_chat_id(chat_id, chat_type, title=None):
    """Auto-detect and store group/channel IDs when bot receives messages."""
    global GROUP_ID, CHANNEL_ID
    if chat_type in ('group', 'supergroup') and GROUP_ID == _CFG_GROUP_ID:
        GROUP_ID = chat_id
        set_setting("detected_group_id", str(chat_id))
        if title:
            set_setting("detected_group_title", title)
        logger.info(f"Auto-detected GROUP: {chat_id} ({title})")
    elif chat_type == 'channel' and CHANNEL_ID == _CFG_CHANNEL_ID:
        CHANNEL_ID = chat_id
        set_setting("detected_channel_id", str(chat_id))
        if title:
            set_setting("detected_channel_title", title)
        logger.info(f"Auto-detected CHANNEL: {chat_id} ({title})")

def load_detected_ids():
    """Load auto-detected IDs from DB on startup."""
    global GROUP_ID, CHANNEL_ID
    g = get_setting("detected_group_id")
    c = get_setting("detected_channel_id")
    if g:
        GROUP_ID = int(g)
        logger.info(f"Loaded detected GROUP_ID: {GROUP_ID}")
    if c:
        CHANNEL_ID = int(c)
        logger.info(f"Loaded detected CHANNEL_ID: {CHANNEL_ID}")

def get_ban_media():
    """Get the configured ban media file_id and type. Returns (file_id, media_type) or (None, None)."""
    file_id = get_setting("ban_media_file_id")
    media_type = get_setting("ban_media_type")
    return file_id, media_type

def set_ban_media(file_id, media_type):
    """Set the ban media (photo, animation, video)."""
    set_setting("ban_media_file_id", file_id)
    set_setting("ban_media_type", media_type)


# ---------------------------------------------------------------------------
# REGLAS DEL GRUPO — configurables por el admin
# ---------------------------------------------------------------------------
DEFAULT_RULES = (
    "📋 *REGLAS DEL GRUPO*\n"
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
    "1️⃣ *No enviar links de ningun tipo*\n"
    "   Prohibidos: URLs, t.me, bit.ly, discord, archivos, etc.\n"
    "   ⛔ Sancion: BAN PERMANENTE\n\n"
    "2️⃣ *No enviar archivos ni documentos*\n"
    "   Prohibidos: .zip, .txt, .pdf, imagenes con links, configs, etc.\n"
    "   ⛔ Sancion: BAN PERMANENTE\n\n"
    "3️⃣ *No spam ni publicidad*\n"
    "   Prohibido: promocionar otros grupos, bots, canales, servicios.\n"
    "   ⛔ Sancion: BAN\n\n"
    "4️⃣ *No contenido adulto*\n"
    "   Prohibido: xxx, porn,-onlyfans, contenido 18+.\n"
    "   ⛔ Sancion: BAN PERMANENTE\n\n"
    "5️⃣ *No reenviar desde otros canales*\n"
    "   Prohibido: reenvios de canales/grupos externos.\n"
    "   ⛔ Sancion: BAN\n\n"
    "6️⃣ *No compartir credenciales*\n"
    "   Prohibido: cuentas, passwords, IPs, puertos.\n"
    "   ⛔ Sancion: BAN\n\n"
    "7️⃣ *Respeta a todos los miembros*\n"
    "   Prohibido: insultos, acoso, amenazas.\n"
    "   ⛔ Sancion: BAN\n\n"
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
    "⚠️ *La infraccion de cualquiera de estas reglas*\n"
    "resultara en un BAN automatico e inmediato.\n\n"
    "👑 *Solo el administrador puede desbanear.*\n"
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
)

# Mapeo de tipo de violacion a regla
VIOLATION_TO_RULE = {
    'link_detected': {
        'rule_num': '1',
        'rule_title': 'No enviar links de ningun tipo',
        'rule_detail': 'Prohibido: URLs, t.me, bit.ly, discord, etc.',
    },
    'spam_keyword': {
        'rule_num': '3',
        'rule_title': 'No spam ni publicidad',
        'rule_detail': 'Palabras clave de spam detectadas en tu mensaje.',
    },
    'suspicious_pattern': {
        'rule_num': '1',
        'rule_title': 'No enviar links ni contenido sospechoso',
        'rule_detail': 'Patron sospechoso detectado (telefono, otro bot, etc.).',
    },
    'forwarded_from_channel': {
        'rule_num': '5',
        'rule_title': 'No reenviar desde otros canales',
        'rule_detail': 'Reenvio desde canal/grupo externo detectado.',
    },
    'document_sent': {
        'rule_num': '2',
        'rule_title': 'No enviar archivos ni documentos',
        'rule_detail': 'Envio de archivo/documento detectado.',
    },
    'manual': {
        'rule_num': 'N/A',
        'rule_title': 'Baneado por administrador',
        'rule_detail': 'El administrador decidio banear este usuario.',
    },
}


def get_rules_text():
    """Get the group rules (admin-configured or default)."""
    return _read_plantilla(RULES_FILE, DEFAULT_RULES)


def get_violation_rule(violation_type):
    """Get the specific rule that was violated."""
    rule = VIOLATION_TO_RULE.get(violation_type, VIOLATION_TO_RULE.get('link_detected'))
    return rule


async def cmd_set_welcome_text(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Carga la plantilla de bienvenida. Uso: /set_welcome_text (y el texto en el
    siguiente mensaje) o /set_welcome_text <texto directo>."""
    if not is_admin(update.effective_user.id):
        return
    directo = " ".join(context.args or []).strip()
    if directo:
        try:
            _save_plantilla(WELCOME_TEXT_FILE, directo)
        except Exception as e:
            await update.message.reply_text(f"❌ No pude guardar: {e}")
            return
        await update.message.reply_text(
            f"✅ *Plantilla de BIENVENIDA guardada en el VPS*\n"
            f"📁 `{WELCOME_TEXT_FILE}`\n"
            f"↩️ La plantilla ANTERIOR fue REEMPLAZADA.\n\n"
            f"👁️ /preview para ver como queda",
            parse_mode=ParseMode.MARKDOWN)
        return
    AWAITING_TEXT[update.effective_user.id] = "welcome"
    await update.message.reply_text(
        "✍️ Enviame la NUEVA plantilla de bienvenida.\n\n"
        "Placeholders disponibles:\n"
        "`{first_name}`, `{username}`, `{id}`, `{date}`, `{source}`, `{source_emoji}`, `{brand}`\n\n"
        "📌 `{brand}` = la MARCA que pusiste en el config (ej: MoviVIP Network).\n"
        "📌 Los PLANES y PRECIOS los decides TU en este texto\n"
        "(pueden ir 3-7-15-30, solo 30, etc. — como quieras).\n"
        "Se guardara en el VPS y REEMPLAZARA a la anterior.",
        parse_mode=ParseMode.MARKDOWN)


async def cmd_set_ad_text(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Carga la plantilla de publicidad. Uso: /set_ad_text (y el texto en el
    siguiente mensaje) o /set_ad_text <texto directo>."""
    if not is_admin(update.effective_user.id):
        return
    directo = " ".join(context.args or []).strip()
    if directo:
        try:
            _save_plantilla(AD_TEXT_FILE, directo)
        except Exception as e:
            await update.message.reply_text(f"❌ No pude guardar: {e}")
            return
        await update.message.reply_text(
            f"✅ *Plantilla de PUBLICIDAD guardada en el VPS*\n"
            f"📁 `{AD_TEXT_FILE}`\n"
            f"↩️ La plantilla ANTERIOR fue REEMPLAZADA.\n\n"
            f"📣 /send_ad para enviarla",
            parse_mode=ParseMode.MARKDOWN)
        return
    AWAITING_TEXT[update.effective_user.id] = "ad"
    await update.message.reply_text(
        "✍️ Enviame la NUEVA plantilla de publicidad.\n\n"
        "📌 Usa `{brand}` para la MARCA del que configura el VPS.\n"
        "📌 LOS PLANES LOS ELIGES TU: pueden ir solo 30 dias, o 15 y 30,\n"
        "o 3-7-15-30... TU decides cuales van y el precio de cada uno.\n\n"
        "Se guardara en el VPS y REEMPLAZARA a la anterior.",
        parse_mode=ParseMode.MARKDOWN)


async def handle_admin_text(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Admin envia un texto: puede ser para:
    1. Nombre de nueva plantilla (AWAITING_TEMPLATE_NAME)
    2. Texto de nueva plantilla (AWAITING_TEMPLATE_TEXT)
    3. Plantilla legacy (AWAITING_TEXT) — compatibilidad
    4. Reglas (AWAITING_RULES)
    """
    if not update.message or not update.message.text:
        return
    user = update.effective_user
    if not is_admin(user.id):
        return

    # --- FLOW 1: Template name input ---
    tpl_kind = AWAITING_TEMPLATE_NAME.pop(user.id, None)
    if tpl_kind:
        name = update.message.text.strip()[:100]
        AWAITING_TEMPLATE_TEXT[user.id] = {"kind": tpl_kind, "name": name}
        label = "Bienvenida" if tpl_kind == "welcome" else "Publicidad"
        await update.message.reply_text(
            f"✅ Nombre: *{name}*\n\n"
            f"✍️ Ahora enviame el *TEXTO* de la plantilla de {label}.\n\n"
            f"Placeholders disponibles:\n"
            f"`{{first_name}}`, `{{username}}`, `{{id}}`, `{{date}}`, "
            f"`{{source}}`, `{{source_emoji}}`, `{{brand}}`",
            parse_mode=ParseMode.MARKDOWN
        )
        return

    # --- FLOW 2: Template text input ---
    tpl_data = AWAITING_TEMPLATE_TEXT.pop(user.id, None)
    if tpl_data:
        text = update.message.text.strip()
        table = "welcome_templates" if tpl_data["kind"] == "welcome" else "ad_templates"
        label = "BIENVENIDA" if tpl_data["kind"] == "welcome" else "PUBLICIDAD"
        # Check if first template -> auto activate
        existing = list_templates(table)
        set_active = len(existing) == 0
        new_id = save_template(table, tpl_data["name"], text, set_active=set_active)
        active_msg = "\n🟢 *Se activo automaticamente (es la primera plantilla).*" if set_active else ""
        await update.message.reply_text(
            f"✅ *Plantilla de {label} GUARDADA*\n\n"
            f"📌 Nombre: *{tpl_data['name']}*\n"
            f"🆔 ID: #{new_id}{active_msg}\n\n"
            f"👁️ Activa: {'🟢 SI' if set_active else '⚪ NO (usa /active para activarla)'}",
            parse_mode=ParseMode.MARKDOWN,
            reply_markup=_config_menu_kb()
        )
        return

    # --- FLOW 3: Legacy file-based template (compatibility) ---
    kind = AWAITING_TEXT.pop(user.id, None)
    if kind:
        dest = WELCOME_TEXT_FILE if kind == "welcome" else AD_TEXT_FILE
        try:
            _save_plantilla(dest, update.message.text)
        except Exception as e:
            logger.error(f"save {kind} text: {e}")
            await update.message.reply_text(f"❌ No pude guardar: {e}")
            return
        label = "BIENVENIDA" if kind == "welcome" else "PUBLICIDAD"
        logger.info(f"Admin {user.id} actualizo plantilla legacy de {kind}")
        await update.message.reply_text(
            f"✅ *Plantilla de {label} guardada en VPS*\n"
            f"📁 `{dest}`\n\n"
            f"💡 *Tip:* Ahora puedes usar el sistema de plantillas multiples\n"
            f"desde ⚙️ Config → Ver listas de plantillas.",
            parse_mode=ParseMode.MARKDOWN,
            reply_markup=_config_menu_kb())
        return


async def cmd_show_texts(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Muestra las plantillas actuales de bienvenida y publicidad."""
    if not is_admin(update.effective_user.id):
        return
    wt = _read_plantilla(WELCOME_TEXT_FILE, WELCOME_DEFAULT_TEXT)
    at = get_publicity_text()
    msg = (
        "📋 *PLANTILLAS ACTUALES*\n"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        f"🖼️ *BIENVENIDA* (`welcome_text.txt`):\n{wt}\n\n"
        f"📣 *PUBLICIDAD* (`ad_text.txt`):\n{at}\n\n"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        "💡 Cambialas con /set_welcome_text y /set_ad_text"
    )
    try:
        await update.message.reply_text(msg, parse_mode=ParseMode.MARKDOWN)
    except Exception:
        await update.message.reply_text(msg)


# ---------------------------------------------------------------------------
# PANEL DE CONFIGURACION (botones funcionales para imagenes + plantillas)
# ---------------------------------------------------------------------------
def _config_menu_kb():
    # Check if ban media is configured
    ban_file_id, _ = get_ban_media()
    ban_badge = "✅" if ban_file_id else "❌"
    return InlineKeyboardMarkup([
        [InlineKeyboardButton("🖼️ Imagen de BIENVENIDA", callback_data="cfg_welcome_img"),
         InlineKeyboardButton("🖼️ Imagen de PUBLICIDAD", callback_data="cfg_ad_img")],
        [InlineKeyboardButton(f"🚨 Imagen de BAN {ban_badge}", callback_data="cfg_ban_img")],
        [InlineKeyboardButton("📋 Bienvenidas (ver/agregar)", callback_data="tpl_welcome_list"),
         InlineKeyboardButton("📋 Publicidades (ver/agregar)", callback_data="tpl_ad_list")],
        [InlineKeyboardButton("📋 Ver Reglas", callback_data="rules_show"),
         InlineKeyboardButton("📝 Editar Reglas", callback_data="rules_edit")],
        [InlineKeyboardButton("📣 Enviar publicidad", callback_data="cfg_send_ad")],
        [InlineKeyboardButton("🔒 BANS", callback_data="banlist"),
         InlineKeyboardButton("📊 Ban Stats", callback_data="banstats")],
        [InlineKeyboardButton("🔙 Volver al panel", callback_data="cfg_back")],
    ])


CONFIG_MENU_TEXT = (
    "⚙️ *CONFIGURACION DEL BOT*\n"
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
    "🖼️ *Imagenes* — se guardan en el VPS\n"
    "y la nueva carga REEMPLAZA la anterior.\n\n"
    "✍️ *Plantillas de texto* — TU decides\n"
    "los planes (solo 30, 15 y 30, 3-7-15-30...)\n"
    "y el precio de cada uno.\n"
    "Usa `{{brand}}` para la marca del VPS.\n\n"
    "Selecciona una opcion:"
)


async def cmd_config(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Abre el panel de configuracion (imagenes + plantillas)."""
    if not is_admin(update.effective_user.id):
        return
    await update.message.reply_text(
        _fill_plantilla(CONFIG_MENU_TEXT, {"brand": BRAND}),
        parse_mode=ParseMode.MARKDOWN,
        reply_markup=_config_menu_kb())


async def _callback_cfg_menu(query, context):
    try:
        await query.edit_message_text(
            _fill_plantilla(CONFIG_MENU_TEXT, {"brand": BRAND}),
            parse_mode=ParseMode.MARKDOWN,
            reply_markup=_config_menu_kb())
    except Exception as e:
        logger.error(f"cfg menu: {e}")
        await query.message.reply_text(
            _fill_plantilla(CONFIG_MENU_TEXT, {"brand": BRAND}),
            parse_mode=ParseMode.MARKDOWN,
            reply_markup=_config_menu_kb())


async def _callback_cfg_ask_photo(query, context, kind):
    AWAITING_PHOTO[query.from_user.id] = kind
    if kind == "welcome":
        text = (
            "🖼️ *Imagen de BIENVENIDA*\n\n"
            "Enviame la NUEVA foto.\n"
            "Se guardara como `welcome.jpg` en el VPS\n"
            "y REEMPLAZARA a la anterior."
        )
    else:
        text = (
            "🖼️ *Imagen de PUBLICIDAD*\n\n"
            "Enviame la NUEVA foto.\n"
            "Se guardara como `ad.jpg` en el VPS\n"
            "y REEMPLAZARA a la anterior."
        )
    await query.edit_message_text(text, parse_mode=ParseMode.MARKDOWN)


async def _callback_cfg_ask_text(query, context, kind):
    AWAITING_TEXT[query.from_user.id] = kind
    if kind == "welcome":
        text = (
            "✍️ *Plantilla de BIENVENIDA*\n\n"
            "Enviame el NUEVO texto.\n\n"
            "Placeholders: `{first_name}`, `{username}`, `{id}`,\n"
            "`{date}`, `{source}`, `{source_emoji}`, `{brand}`\n\n"
            "Se guardara como `welcome_text.txt` en el VPS\n"
            "y REEMPLAZARA a la anterior."
        )
    else:
        text = (
            "✍️ *Plantilla de PUBLICIDAD*\n\n"
            "Enviame el NUEVO texto.\n\n"
            "TU decides los planes (solo 30, 15 y 30,\n"
            "3-7-15-30...) y el precio de cada uno.\n"
            "Usa `{brand}` para la marca del VPS.\n\n"
            "Se guardara como `ad_text.txt` en el VPS\n"
            "y REEMPLAZARA a la anterior."
        )
    await query.edit_message_text(text, parse_mode=ParseMode.MARKDOWN)


async def _callback_cfg_show_texts(query, context):
    wt = _read_plantilla(WELCOME_TEXT_FILE, WELCOME_DEFAULT_TEXT)
    at = get_publicity_text()
    msg = (
        "📋 *PLANTILLAS ACTUALES*\n"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        f"🖼️ *BIENVENIDA* (`welcome_text.txt`):\n{wt}\n\n"
        f"📣 *PUBLICIDAD* (`ad_text.txt`):\n{at}\n\n"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        "💡 Cambialas desde el panel de configuracion"
    )
    try:
        await query.message.reply_text(msg, parse_mode=ParseMode.MARKDOWN,
                                       reply_markup=_config_menu_kb())
    except Exception:
        await query.message.reply_text(msg, reply_markup=_config_menu_kb())


async def _callback_cfg_send_ad(query, context):
    await query.message.reply_text("📢 Enviando publicidad...")
    # Get active ad template with its own image
    tpl = get_active_ad_template_full()
    tpl_text = _fill_plantilla(tpl["text"], {"brand": BRAND}) if tpl else get_publicity_text()
    tpl_img = tpl["image_file_id"] if tpl and tpl.get("image_file_id") else AD_IMG
    success = 0
    for chat_id, name in [(CHANNEL_ID, "Canal"), (GROUP_ID, "Grupo")]:
        ok = await _send_media_or_text(context, chat_id, tpl_img, tpl_text)
        success += 1 if ok else 0
        logger.info(f"Ad enviado a {name}: ok={ok}")
    await query.message.reply_text(
        f"✅ Publicidad enviada!\n"
        f"📊 Enviada: {success}/2",
        reply_markup=_config_menu_kb())


# ---------------------------------------------------------------------------
# MULTI-TEMPLATE HANDLER — gestion de plantillas multiples
# ---------------------------------------------------------------------------
AWAITING_TEMPLATE_NAME = {}   # user_id -> "welcome" | "ad"
AWAITING_TEMPLATE_TEXT = {}   # user_id -> {"kind": "welcome"|"ad", "name": "..."}
AWAITING_BAN_MEDIA = {}      # user_id -> True (waiting for photo/video/GIF)
AWAITING_AD_IMAGE = {}       # user_id -> tpl_id (waiting for image for ad template)

async def _handle_template_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle all tpl_* callbacks for multi-template management."""
    query = update.callback_query
    await query.answer()
    data = query.data
    uid = query.from_user.id

    if not is_admin(uid):
        await query.edit_message_text("⛔ Solo el administrador puede gestionar plantillas.")
        return

    # --- LIST templates ---
    if data == "tpl_welcome_list":
        await _show_template_list(query, "welcome_templates", "Bienvenida")
    elif data == "tpl_ad_list":
        await _show_template_list(query, "ad_templates", "Publicidad")

    # --- ADD new template (ask name) ---
    elif data == "tpl_welcome_add":
        AWAITING_TEMPLATE_NAME[uid] = "welcome"
        await query.edit_message_text(
            "✏️ *NOMBRE de la nueva plantilla de bienvenida:*\n\n"
            "Ejemplo: `Bienvenida Normal`, `Bienvenida Promo`, `Black Friday`",
            parse_mode=ParseMode.MARKDOWN
        )
    elif data == "tpl_ad_add":
        AWAITING_TEMPLATE_NAME[uid] = "ad"
        await query.edit_message_text(
            "✏️ *NOMBRE de la nueva plantilla de publicidad:*\n\n"
            "Ejemplo: ` Promo Semanal`, `Navidades`, `Aniversario`",
            parse_mode=ParseMode.MARKDOWN
        )

    # --- ACTIVATE a template ---
    elif data.startswith("tpl_activate_"):
        parts = data.split("_")
        kind = parts[2]  # "welcome" or "ad"
        tpl_id = int(parts[3])
        table = "welcome_templates" if kind == "welcome" else "ad_templates"
        label = "Bienvenida" if kind == "welcome" else "Publicidad"
        activate_template(table, tpl_id)
        tpl = get_template_by_id(table, tpl_id)
        await query.edit_message_text(
            f"✅ *Plantilla ACTIVADA:*\n"
            f"📌 Nombre: {tpl[1] if tpl else '?'}\n"
            f"📋 Tipo: {label}\n\n"
            f"Ahora esta plantilla se usara para nuevos {label.lower()}s.",
            parse_mode=ParseMode.MARKDOWN,
            reply_markup=InlineKeyboardMarkup([
                [InlineKeyboardButton(f"📋 Ver {label}s", callback_data=f"tpl_{kind}_list")],
                [InlineKeyboardButton("🔙 Config", callback_data="cfg")],
            ])
        )

    # --- VIEW a template ---
    elif data.startswith("tpl_view_"):
        parts = data.split("_")
        kind = parts[2]
        tpl_id = int(parts[3])
        table = "welcome_templates" if kind == "welcome" else "ad_templates"
        label = "Bienvenida" if kind == "welcome" else "Publicidad"
        tpl = get_template_by_id(table, tpl_id)
        if not tpl:
            await query.edit_message_text("❌ Plantilla no encontrada.")
            return
        active_badge = "🟢 ACTIVA" if tpl[3] else "⚪ Inactiva"
        text_preview = tpl[2][:800] + ("..." if len(tpl[2]) > 800 else "")
        # Check image (tpl[4] = image_file_id, tpl[5] = image_type)
        has_image = bool(tpl[4]) if len(tpl) > 4 else False
        img_badge = f"🖼️ {tpl[5]}" if has_image and len(tpl) > 4 else "❌ Sin imagen"
        kb = [
            [InlineKeyboardButton("🟢 Activar", callback_data=f"tpl_activate_{kind}_{tpl_id}"),
             InlineKeyboardButton("🗑️ Eliminar", callback_data=f"tpl_delete_{kind}_{tpl_id}")],
        ]
        if kind == "ad":
            kb.append([InlineKeyboardButton(f"🖼️ Imagen: {tpl[5] if has_image else 'ninguna'}", callback_data=f"tpl_set_image_{kind}_{tpl_id}")])
        kb.append([InlineKeyboardButton(f"📋 Ver {label}s", callback_data=f"tpl_{kind}_list")])
        kb.append([InlineKeyboardButton("🔙 Config", callback_data="cfg")])
        await query.edit_message_text(
            f"📋 *PLANTILLA #{tpl_id}*\n"
            f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
            f"📌 Nombre: *{tpl[1]}*\n"
            f"📊 Estado: {active_badge}\n"
            f"🖼️ Imagen: {img_badge}\n\n"
            f"📝 *Texto:*\n{text_preview}\n\n"
            f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
            parse_mode=ParseMode.MARKDOWN,
            reply_markup=InlineKeyboardMarkup(kb)
        )

    # --- SET IMAGE for ad template ---
    elif data.startswith("tpl_set_image_"):
        parts = data.split("_")
        kind = parts[3]  # "welcome" or "ad"
        tpl_id = int(parts[4])
        table = "welcome_templates" if kind == "welcome" else "ad_templates"
        tpl = get_template_by_id(table, tpl_id)
        if not tpl:
            await query.edit_message_text("❌ Plantilla no encontrada.")
            return
        AWAITING_AD_IMAGE[uid] = tpl_id
        await query.edit_message_text(
            f"🖼️ *CONFIGURAR IMAGEN — Plantilla #{tpl_id}*\n"
            f"📌 Nombre: *{tpl[1]}*\n\n"
            f"Envia una imagen, GIF o video para esta plantilla.\n"
            f"Este medio se enviara junto con el texto de publicidad.\n\n"
            f"Envia /cancel para cancelar.",
            parse_mode=ParseMode.MARKDOWN
        )

    # --- DELETE a template ---
    elif data.startswith("tpl_delete_"):
        parts = data.split("_")
        kind = parts[2]
        tpl_id = int(parts[3])
        table = "welcome_templates" if kind == "welcome" else "ad_templates"
        label = "Bienvenida" if kind == "welcome" else "Publicidad"
        tpl = get_template_by_id(table, tpl_id)
        if not tpl:
            await query.edit_message_text("❌ Plantilla no encontrada.")
            return
        delete_template(table, tpl_id)
        await query.edit_message_text(
            f"🗑️ *Plantilla ELIMINADA:*\n"
            f"📌 Nombre: {tpl[1]}\n"
            f"📋 Tipo: {label}",
            parse_mode=ParseMode.MARKDOWN,
            reply_markup=InlineKeyboardMarkup([
                [InlineKeyboardButton(f"📋 Ver {label}s", callback_data=f"tpl_{kind}_list")],
                [InlineKeyboardButton("🔙 Config", callback_data="cfg")],
            ])
        )


async def _show_template_list(query, table, label):
    """Show a list of templates with buttons to view/activate/add."""
    templates = list_templates(table)
    kind = "welcome" if "welcome" in table else "ad"

    if not templates:
        kb = InlineKeyboardMarkup([
            [InlineKeyboardButton(f"➕ Crear primera {label}", callback_data=f"tpl_{kind}_add")],
            [InlineKeyboardButton("🔙 Config", callback_data="cfg")],
        ])
        await query.edit_message_text(
            f"📋 *{label.upper()}S*\n\n"
            f"No hay plantillas creadas aun.\n"
            f"crea la primera con el boton de abajo.",
            parse_mode=ParseMode.MARKDOWN,
            reply_markup=kb
        )
        return

    lines = [f"📋 *PLANTILLAS DE {label.upper()}*\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"]
    buttons = []
    for tpl_id, name, is_active, created in templates:
        badge = "🟢" if is_active else "⚪"
        lines.append(f"{badge} *#{tpl_id}* — {name}")
        buttons.append([InlineKeyboardButton(
            f"{badge} #{tpl_id} — {name}",
            callback_data=f"tpl_view_{kind}_{tpl_id}"
        )])

    buttons.append([InlineKeyboardButton("➕ Nueva plantilla", callback_data=f"tpl_{kind}_add")])
    buttons.append([InlineKeyboardButton("🔙 Config", callback_data="cfg")])

    lines.append(f"\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    lines.append(f"🟢 = Activa (se usa actualmente)")
    lines.append(f"⚪ = Inactiva")

    await query.edit_message_text(
        "\n".join(lines),
        parse_mode=ParseMode.MARKDOWN,
        reply_markup=InlineKeyboardMarkup(buttons)
    )


def get_welcome_keyboard():
    """Inline keyboard dinamica: SOLO aparecen los botones cuyo enlace
    este configurado (SSH_BOT/STORE_BOT/SOCIAL). Maximo 2 por fila."""
    botones = []
    if SSH_BOT:
        botones.append(("🔑 Bot SSH", f"https://t.me/{SSH_BOT.replace('@','')}"))
    if STORE_BOT:
        botones.append(("🛒 Bot Tienda", f"https://t.me/{STORE_BOT.replace('@','')}"))
    etiquetas = [
        ('web', "🌐 Web Oficial"),
        ('tiktok', "🎵 TikTok"),
        ('youtube', "📺 YouTube"),
        ('telegram_ch', "📢 Canal Telegram"),
        ('telegram_group', "💬 Grupo"),
        ('whatsapp_ch', "📱 WhatsApp Canal"),
        ('whatsapp_community', "👥 Comunidad WA"),
        ('whatsapp_personal', "📞 WA Personal"),
    ]
    for clave, texto in etiquetas:
        url = SOCIAL.get(clave)
        if url:
            botones.append((texto, url))
    filas = []
    for i in range(0, len(botones), 2):
        par = botones[i:i + 2]
        filas.append([InlineKeyboardButton(t, url=u) for t, u in par])
    return InlineKeyboardMarkup(filas)


def build_welcome_text(first_name, username, tg_id, source, join_date=None):
    """Build welcome text from the active DB template, or file, or default.
    Placeholders: {first_name}, {username}, {id}, {date}, {source}, {source_emoji}, {brand}."""
    if not join_date:
        join_date = datetime.datetime.now().strftime('%d/%m/%Y %H:%M')

    user_display = f"@{username}" if username else first_name or "Usuario"
    source_emoji = "📢 Canal" if source == "channel" else "💬 Grupo"

    # Priority: active DB template > file template > default
    plantilla = get_active_welcome_template()
    if not plantilla:
        plantilla = _read_plantilla(WELCOME_TEXT_FILE, WELCOME_DEFAULT_TEXT)
    return _fill_plantilla(plantilla, {
        "first_name": first_name or "Usuario",
        "username": user_display,
        "id": tg_id,
        "date": join_date,
        "source": source,
        "source_emoji": source_emoji,
        "brand": BRAND,
    })


# =============================================================================
# WELCOME HANDLER
# =============================================================================
async def welcome_new_member(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle new members in groups/channels."""
    if not update.message or not update.message.new_chat_members:
        return
    detect_chat_id(update.effective_chat.id, update.effective_chat.type, getattr(update.effective_chat, 'title', None))

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

        # Build text
        welcome_text = build_welcome_text(
            member.first_name, member.username, member.id, source, join_date
        )
        keyboard = get_welcome_keyboard()

        # Send welcome with logo + buttons
        try:
            welcome_img = _welcome_img_path()
            if welcome_img:
                with open(welcome_img, 'rb') as media:
                    if welcome_img.lower().endswith('.mp4'):
                        await context.bot.send_video(
                            chat_id=chat.id,
                            video=media,
                            caption=welcome_text,
                            parse_mode=ParseMode.MARKDOWN,
                            reply_markup=keyboard
                        )
                    else:
                        await context.bot.send_photo(
                            chat_id=chat.id,
                            photo=media,
                            caption=welcome_text,
                            parse_mode=ParseMode.MARKDOWN,
                            reply_markup=keyboard
                        )
            else:
                await context.bot.send_message(
                    chat_id=chat.id,
                    text=welcome_text,
                    parse_mode=ParseMode.MARKDOWN,
                    reply_markup=keyboard
                )
            logger.info(f"Welcome sent to {member.first_name} in {source}: {chat.title}")
        except Exception as e:
            logger.error(f"Welcome error: {e}")
            # Fallback: text only with buttons
            try:
                await context.bot.send_message(
                    chat_id=chat.id,
                    text=welcome_text,
                    parse_mode=ParseMode.MARKDOWN,
                    reply_markup=keyboard
                )
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
        detect_chat_id(result.chat.id, 'channel', getattr(result.chat, 'title', None))

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

            # Build welcome
            welcome_text = build_welcome_text(
                user.first_name, user.username, user.id, source, join_date
            )
            keyboard = get_welcome_keyboard()

            # Send welcome (send to the channel where they joined)
            try:
                if os.path.exists(LOGO_PATH):
                    with open(LOGO_PATH, 'rb') as photo:
                        await context.bot.send_photo(
                            chat_id=chat.id,
                            photo=photo,
                            caption=welcome_text,
                            parse_mode=ParseMode.MARKDOWN,
                            reply_markup=keyboard
                        )
                else:
                    await context.bot.send_message(
                        chat_id=chat.id,
                        text=welcome_text,
                        parse_mode=ParseMode.MARKDOWN,
                        reply_markup=keyboard
                    )
                logger.info(f"Channel welcome sent to {user.first_name} ({user.id})")
            except Exception as e:
                logger.error(f"Channel welcome send error: {e}")
    except Exception as e:
        logger.warning(f"channel_member_handler error: {e}")


# =============================================================================
# MENTION/TAG DETECTION
# =============================================================================
async def detect_mentions(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Detect mentions/tags and forward report to admin."""
    if not update.message:
        return
    detect_chat_id(update.effective_chat.id, update.effective_chat.type, getattr(update.effective_chat, 'title', None))

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
    """Bot start command with comprehensive admin panel."""
    if not is_admin(update.effective_user.id):
        await update.message.reply_text(
            "🤖 *MoviVIP Notification Bot*\n\n"
            "Soy el bot de notificaciones de MoviVIP Network.\n"
            "Recibo reportes y doy la bienvenida a nuevos miembros.\n\n"
            "📋 /rules — ver reglas del grupo\n"
            f"🌐 {SOCIAL['web']}",
            parse_mode=ParseMode.MARKDOWN
        )
        return

    kb = [
        # Row 1: Dashboard + Stats
        [InlineKeyboardButton("📊 Dashboard", callback_data="dash"),
         InlineKeyboardButton("📈 Stats", callback_data="stats")],
        # Row 2: Members + Reports
        [InlineKeyboardButton("👥 Members", callback_data="members"),
         InlineKeyboardButton("🔔 Reports", callback_data="reports")],
        # Row 3: Welcomes + DB
        [InlineKeyboardButton("📨 Welcomes", callback_data="welcomes"),
         InlineKeyboardButton("📋 Full DB", callback_data="fulldb")],
        # Row 4: BAN SYSTEM
        [InlineKeyboardButton("🔒 BANS (auto+manual)", callback_data="banlist"),
         InlineKeyboardButton("📊 Ban Stats", callback_data="banstats")],
        # Row 5: RULES
        [InlineKeyboardButton("📋 Ver Reglas", callback_data="rules_show"),
         InlineKeyboardButton("📝 Editar Reglas", callback_data="rules_edit")],
        # Row 6: Comunicados
        [InlineKeyboardButton("📢 Enviar Comunicado", callback_data="send_official")],
        # Row 7: CONFIG
        [InlineKeyboardButton("⚙️ CONFIG COMPLETA", callback_data="cfg")],
    ]

    await update.message.reply_text(
        f"👑 *MoviVIP Notif Bot v4.0 — GRADE MILITAR*\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        f"🔐 *PANEL DE ADMINISTRACION*\n\n"
        f"📊 *IDs Detectados:*\n"
        f"  Grupo: `{GROUP_ID}`\n"
        f"  Canal: `{CHANNEL_ID}`\n"
        f"  📝 /setgroup — configurar grupo\n"
        f"  📝 /setchannel — configurar canal\n\n"
        f"📊 *Datos:*\n"
        f"  Dashboard, Stats, Members, DB\n\n"
        f"🔒 *Sistema de Bans:*\n"
        f"  Auto-ban por links, VPN configs,\n"
        f"  spam, archivos. Ban manual por ID.\n"
        f"  Duracion: 1h hasta permanente.\n\n"
        f"📋 *Reglas:*\n"
        f"  Configura las reglas del grupo.\n"
        f"  Se muestran al usuario baneado.\n\n"
        f"📎 *Bloqueo de Archivos:*\n"
        f"  No-admin no puede enviar documentos.\n"
        f"  Ban inmediato si envia archivos.\n\n"
        f"🖼️ *Configuracion:*\n"
        f"  Imagenes, plantillas, textos.\n\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        f"🤖 *Anti-spam detecta:*\n"
        f"  URLs, vmess://, vless://, trojan://,\n"
        f"  ss://, ssr://, hysteria://, tuic://,\n"
        f"  configs base64, keywords spam.\n\n"
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
    """Preview welcome with logo + buttons."""
    if not is_admin(update.effective_user.id):
        return

    tg_id = update.effective_user.id
    first_name = update.effective_user.first_name
    username = update.effective_user.username
    join_date = datetime.datetime.now().strftime('%d/%m/%Y %H:%M')

    welcome_text = build_welcome_text(first_name, username, tg_id, "group", join_date)
    keyboard = get_welcome_keyboard()

    try:
        if os.path.exists(LOGO_PATH):
            with open(LOGO_PATH, 'rb') as photo:
                await context.bot.send_photo(
                    chat_id=update.effective_chat.id,
                    photo=photo,
                    caption=welcome_text,
                    parse_mode=ParseMode.MARKDOWN,
                    reply_markup=keyboard
                )
        else:
            await update.message.reply_text(welcome_text, parse_mode=ParseMode.MARKDOWN, reply_markup=keyboard)
    except Exception as e:
        logger.error(f"Preview error: {e}")
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
        f"👑 *MoviVIP Notif Bot v4.0 — GRADE MILITAR*\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        f"📊 /db - Base de datos\n"
        f"📈 /stats - Estadisticas\n"
        f"👥 /members - Miembros\n"
        f"🔔 /reports - Reportes\n"
        f"📨 /welcomes - Log bienvenidas\n"
        f"👁️ /preview - Preview welcome\n"
        f"📢 /official - Enviar comunicado\n\n"
        f"━━━━ *BANS* ━━━━\n"
        f"🔒 /ban <id> [duracion] - Banear usuario\n"
        f"🔓 /unban <id> - Desbanear usuario\n"
        f"📋 /banlist - Ver baneados activos\n"
        f"📊 /banstats - Estadisticas de bans\n\n"
        f"━━━━ *REGLAS* ━━━━\n"
        f"📋 /rules - ver reglas del grupo\n"
        f"📝 /setrules - configurar reglas\n"
        f"📤 /send_rules - enviar reglas al grupo\n\n"
        f"━━━━ *CONFIG* ━━━━\n"
        f"🖼️ /set_welcome - imagen de bienvenida\n"
        f"🖼️ /set_ad - imagen de publicidad\n"
        f"✍️ /set_welcome_text - plantilla bienvenida\n"
        f"✍️ /set_ad_text - plantilla publicidad\n"
        f"📣 /send_ad - enviar publicidad\n"
        f"📋 /show_texts - ver plantillas actuales\n"
        f"🚨 /set_ban_media - imagen de ban\n"
        f"🗑️ /remove_ban_media - quitar imagen ban\n"
        f"❌ /cancel - cancelar accion pendiente\n"
        f"⚙️ /config - PANEL CON BOTONES\n\n"
        f"━━━━ *ANTI-SPAM AUTOMATICO* ━━━━\n"
        f"🤖 El bot detecta *links, spam y keywords*\n"
        f"   y banea automaticamente al usuario.\n"
        f"🔒 Ban individual (no afecta al grupo)\n"
        f"⏰ Duracion configurable por admin\n\n"
        f"💡 En las plantillas usa {{brand}} para la marca.\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
        parse_mode=ParseMode.MARKDOWN)


# =============================================================================
# ADMIN BAN COMMANDS — GRADE MILITAR
# Solo el admin que configuro el bot (ADMIN_IDS) puede usar estos comandos
# =============================================================================
async def cmd_ban(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """
    Ban a user. Two ways to use:
    1. /ban <user_id> — ban by Telegram ID (prompts for duration)
    2. Reply to a message with /ban — bans that user
    3. /ban <user_id> <duration> — ban with specific duration
    Durations: 1h, 6h, 12h, 1d, 3d, 1w, 2w, 1m, perm
    """
    if not is_admin(update.effective_user.id):
        await update.message.reply_text("❌ Solo el administrador puede usar este comando.")
        return

    args = context.args or []
    target_id = None
    target_name = ""
    duration_key = None

    # Method 1: Reply to a message
    if update.message.reply_to_message:
        target_user = update.message.reply_to_message.from_user
        target_id = target_user.id
        target_name = f"{target_user.first_name} (@{target_user.username})" if target_user.username else target_user.first_name
        if args:
            duration_key = args[0].lower()
    # Method 2: /ban <user_id> [duration]
    elif args:
        try:
            target_id = int(args[0])
        except ValueError:
            await update.message.reply_text(
                "❌ Uso incorrecto.\n\n"
                "📋 *Formas de usar /ban:*\n"
                "1️⃣ Responde a un mensaje con `/ban`\n"
                "2️⃣ `/ban <user_id>`\n"
                "3️⃣ `/ban <user_id> <duracion>`\n\n"
                f"⏰ *Duraciones:* {', '.join(f'`{k}`' for k in BAN_DURATION_LABELS.keys())}",
                parse_mode=ParseMode.MARKDOWN
            )
            return
        if len(args) >= 2:
            duration_key = args[1].lower()
        target_name = f"ID {target_id}"
    else:
        await update.message.reply_text(
            "❌ *Uso:* `/ban <user_id> [duracion]`\n"
            "O responde a un mensaje con `/ban`\n\n"
            f"⏰ *Duraciones:* {', '.join(f'`{k}`' for k in BAN_DURATION_LABELS.keys())}",
            parse_mode=ParseMode.MARKDOWN
        )
        return

    if not target_id:
        await update.message.reply_text("❌ No se pudo identificar al usuario.")
        return

    # Never ban admins
    if target_id in ADMIN_IDS:
        await update.message.reply_text("❌ No puedes banear a otro administrador.")
        return

    # If no duration specified, show duration selection keyboard
    if not duration_key or duration_key not in BAN_DURATIONS:
        AWAITING_BAN_DURATION[update.effective_user.id] = {
            'target_id': target_id,
            'target_name': target_name,
            'chat_id': update.effective_chat.id,
        }
        kb_rows = []
        durations_list = list(BAN_DURATION_LABELS.items())
        for i in range(0, len(durations_list), 3):
            row = []
            for key, label in durations_list[i:i+3]:
                row.append(InlineKeyboardButton(
                    f"⏰ {label}",
                    callback_data=f"bansel_{key}_{target_id}"
                ))
            kb_rows.append(row)
        kb_rows.append([InlineKeyboardButton("❌ Cancelar", callback_data="bancancel")])

        await update.message.reply_text(
            f"🔒 *BANEAR USUARIO*\n"
            f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
            f"👤 *Usuario:* {target_name}\n"
            f"🆔 *ID:* `{target_id}`\n"
            f"📍 *Grupo:* {update.effective_chat.title}\n\n"
            f"⏰ Selecciona la *duracion del ban*:",
            parse_mode=ParseMode.MARKDOWN,
            reply_markup=InlineKeyboardMarkup(kb_rows)
        )
        return

    # Validate duration
    if duration_key not in BAN_DURATIONS:
        await update.message.reply_text(
            f"❌ Duracion invalida. Opciones: {', '.join(BAN_DURATION_LABELS.keys())}"
        )
        return

    # Execute ban
    duration_label = BAN_DURATION_LABELS.get(duration_key, duration_key)
    chat = update.effective_chat

    success = ban_user(
        tg_id=target_id,
        username=None,
        first_name=target_name,
        reason='manual',
        ban_type='manual',
        banned_by=update.effective_user.id,
        chat_id=chat.id,
        chat_title=chat.title,
        duration_key=duration_key,
        notes=f"Banned by admin {update.effective_user.id}"
    )

    if not success:
        await update.message.reply_text(
            f"⚠️ El usuario `{target_id}` ya esta baneado activamente.",
            parse_mode=ParseMode.MARKDOWN
        )
        return

    # Restrict in Telegram
    await _restrict_user(context, chat.id, target_id)

    # Notify
    await update.message.reply_text(
        f"🔒 *USUARIO BANNEADO*\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        f"👤 *Usuario:* {target_name}\n"
        f"🆔 *ID:* `{target_id}`\n"
        f"⏰ *Duracion:* {duration_label}\n"
        f"👮 *Banned por:* Admin\n"
        f"📍 *Grupo:* {chat.title}\n\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        f"🔓 Para desbanear: /unban `{target_id}`",
        parse_mode=ParseMode.MARKDOWN
    )

    logger.info(f"ADMIN BAN: {target_id} by {update.effective_user.id} for {duration_key} in {chat.title}")


async def cmd_unban(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """
    Unban a user. Two ways:
    1. /unban <user_id>
    2. Reply to a message with /unban
    """
    if not is_admin(update.effective_user.id):
        await update.message.reply_text("❌ Solo el administrador puede usar este comando.")
        return

    args = context.args or []
    target_id = None

    # Method 1: Reply
    if update.message.reply_to_message:
        target_id = update.message.reply_to_message.from_user.id
    # Method 2: /unban <user_id>
    elif args:
        try:
            target_id = int(args[0])
        except ValueError:
            await update.message.reply_text(
                "❌ Uso: `/unban <user_id>`\nO responde a un mensaje con `/unban`",
                parse_mode=ParseMode.MARKDOWN
            )
            return
    else:
        await update.message.reply_text(
            "❌ *Uso:* `/unban <user_id>`\nO responde a un mensaje con `/unban`",
            parse_mode=ParseMode.MARKDOWN
        )
        return

    if not target_id:
        await update.message.reply_text("❌ No se pudo identificar al usuario.")
        return

    # Unban in DB
    unban_user(target_id, update.effective_user.id, reason='manual_unban')

    # Reset strikes (clean slate)
    reset_strikes(target_id, update.effective_chat.id)

    # Mark as "recently unbanned" — first re-offense = warning only
    set_unban_warning(target_id, update.effective_chat.id)

    # Unrestrict in all known chats
    chat = update.effective_chat
    await _unrestrict_user(context, chat.id, target_id)

    await update.message.reply_text(
        f"🔓 *USUARIO DESBANEADO*\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        f"🆔 *ID:* `{target_id}`\n"
        f"📍 *Grupo:* {chat.title}\n"
        f"👮 *Desbanned por:* Admin\n"
        f"🔄 *Strikes:* reiniciados a 0\n\n"
        f"⚠️ Si vuelve a infringer recibira una *advertencia*.\n"
        f"🚨 Si persiste sera *EXPULSADO del grupo*.\n\n"
        f"✅ El usuario puede volver a escribir.",
        parse_mode=ParseMode.MARKDOWN
    )

    logger.info(f"ADMIN UNBAN: {target_id} by {update.effective_user.id} in {chat.title}")


# =============================================================================
# RULES COMMANDS — admin configura las reglas del grupo
# =============================================================================
AWAITING_RULES = {}


async def cmd_setrules(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """
    Set the group rules. Two ways:
    1. /setrules <rules text> — direct text
    2. /setrules — then send the rules in the next message
    """
    if not is_admin(update.effective_user.id):
        await update.message.reply_text("❌ Solo el administrador puede usar este comando.")
        return

    directo = " ".join(context.args or []).strip()
    if directo:
        try:
            _save_plantilla(RULES_FILE, directo)
        except Exception as e:
            await update.message.reply_text(f"❌ No pude guardar: {e}")
            return
        await update.message.reply_text(
            f"✅ *Reglas guardadas en el VPS*\n"
            f"📁 `{RULES_FILE}`\n"
            f"↩️ Las reglas ANTERIORES fueron REEMPLAZADAS.\n\n"
            f"👁️ /rules — ver las reglas actuales\n"
            f"📤 /send_rules — enviar reglas al grupo",
            parse_mode=ParseMode.MARKDOWN
        )
        return

    AWAITING_RULES[update.effective_user.id] = True
    await update.message.reply_text(
        "📋 *CONFIGURAR REGLAS DEL GRUPO*\n\n"
        "Enviame el texto con todas las reglas.\n"
        "Usa *negrita* para enfatizar, listas, emojis, etc.\n\n"
        "Ejemplo:\n"
        "1. No enviar links\n"
        "2. No spam\n"
        "3. No contenido adulto\n\n"
        "Las reglas anteriores seran REEMPLAZADAS.",
        parse_mode=ParseMode.MARKDOWN
    )


async def cmd_rules(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Show the current group rules. Everyone can see them."""
    rules = get_rules_text()
    try:
        await update.message.reply_text(rules, parse_mode=ParseMode.MARKDOWN)
    except Exception:
        await update.message.reply_text(rules)


async def cmd_send_rules(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Send the rules to the group and channel."""
    if not is_admin(update.effective_user.id):
        await update.message.reply_text("❌ Solo el administrador puede usar este comando.")
        return

    rules = get_rules_text()
    await update.message.reply_text("📋 Enviando reglas al grupo y canal...")

    success = 0
    for chat_id, name in [(GROUP_ID, "Grupo"), (CHANNEL_ID, "Canal")]:
        try:
            await context.bot.send_message(chat_id=chat_id, text=rules, parse_mode=ParseMode.MARKDOWN)
            success += 1
        except Exception as e:
            logger.error(f"Send rules to {name}: {e}")

    await update.message.reply_text(
        f"✅ Reglas enviadas!\n"
        f"📊 Enviadas: {success}/2"
    )


async def cmd_remove_ban_media(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Remove the configured ban media."""
    if not is_admin(update.effective_user.id):
        await update.message.reply_text("❌ Solo el administrador puede usar este comando.")
        return
    ban_file_id, ban_media_type = get_ban_media()
    if not ban_file_id:
        await update.message.reply_text(
            "ℹ️ No hay imagen de ban configurada.\n"
            "Usa /config → 🚨 Imagen de BAN para configurar una.",
            reply_markup=_config_menu_kb()
        )
        return
    set_setting("ban_media_file_id", None)
    set_setting("ban_media_type", None)
    await update.message.reply_text(
        f"✅ *Imagen de ban ELIMINADA*\n"
        f"🗑️ Tipo anterior: {ban_media_type}\n\n"
        f"Ahora solo se enviara el texto de ban.\n"
        f"Configura una nueva con /config → 🚨 Imagen de BAN",
        parse_mode=ParseMode.MARKDOWN,
        reply_markup=_config_menu_kb()
    )


async def cmd_cancel(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Cancel any pending admin action."""
    if not is_admin(update.effective_user.id):
        return
    uid = update.effective_user.id
    cleared = False
    for d in (AWAITING_TEXT, AWAITING_RULES, AWAITING_TEMPLATE_NAME, AWAITING_TEMPLATE_TEXT, AWAITING_BAN_MEDIA, AWAITING_AD_IMAGE):
        if uid in d:
            del d[uid]
            cleared = True
    if cleared:
        await update.message.reply_text(
            "✅ Accion cancelada.",
            reply_markup=_config_menu_kb()
        )
    else:
        await update.message.reply_text("ℹ️ No habia ninguna accion pendiente.")


async def handle_admin_rules_text(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Admin sends rules text after /setrules."""
    if not update.message or not update.message.text:
        return
    user = update.effective_user
    if not is_admin(user.id):
        return
    if not AWAITING_RULES.pop(user.id, None):
        return

    try:
        _save_plantilla(RULES_FILE, update.message.text)
    except Exception as e:
        await update.message.reply_text(f"❌ No pude guardar: {e}")
        return

    logger.info(f"Admin {user.id} updated rules -> {RULES_FILE}")
    await update.message.reply_text(
        f"✅ *Reglas guardadas en el VPS*\n"
        f"📁 `{RULES_FILE}`\n"
        f"↩️ Las reglas ANTERIORES fueron REEMPLAZADAS.\n\n"
        f"👁️ /rules — ver las reglas\n"
        f"📤 /send_rules — enviar al grupo",
        parse_mode=ParseMode.MARKDOWN
    )


async def cmd_banlist(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Show all active bans."""
    if not is_admin(update.effective_user.id):
        await update.message.reply_text("❌ Solo el administrador puede usar este comando.")
        return

    bans = get_active_bans(limit=30)
    stats = get_ban_stats()

    if not bans:
        await update.message.reply_text(
            "📋 *LISTA DE BANS*\n"
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
            "✅ No hay usuarios baneados actualmente.",
            parse_mode=ParseMode.MARKDOWN
        )
        return

    text = (
        f"📋 *LISTA DE BANS ACTIVOS*\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        f"🔒 Activos: {stats['active']} | ⏳ Temporales: {stats['temporary']} | "
        f"Permanentes: {stats['permanent']}\n\n"
    )

    kb = []
    for i, ban in enumerate(bans[:20], 1):
        uname = f"@{ban['username']}" if ban.get('username') else ban.get('first_name', 'N/A')
        dur = BAN_DURATION_LABELS.get(ban.get('duration_key', 'perm'), ban.get('duration_key', 'perm'))
        reason = ban.get('reason', 'N/A')
        expires = ban.get('expires_at', 'Nunca')
        banned_at = ban.get('banned_at', 'N/A')
        ban_type = "🤖 Auto" if ban.get('ban_type') == 'auto' else "👮 Manual"

        text += (
            f"{i}. {ban_type}\n"
            f"   👤 {uname} (`{ban['tg_id']}`)\n"
            f"   📍 {ban.get('chat_title', 'N/A')}\n"
            f"   📝 {reason}\n"
            f"   ⏰ {dur}"
        )
        if expires and expires != 'Nunca':
            text += f" | Expira: {expires}"
        text += f"\n   🕐 {banned_at}\n\n"

        # Add unban button for each user
        kb.append([InlineKeyboardButton(
            f"🔓 Desbanear {uname[:20]}",
            callback_data=f"unban_{ban['tg_id']}"
        )])

    kb.append([InlineKeyboardButton("🔄 Actualizar", callback_data="banlist")])
    try:
        await update.message.reply_text(text, parse_mode=ParseMode.MARKDOWN, reply_markup=InlineKeyboardMarkup(kb))
    except Exception:
        await update.message.reply_text(text, reply_markup=InlineKeyboardMarkup(kb))


async def cmd_banstats(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Show ban statistics."""
    if not is_admin(update.effective_user.id):
        await update.message.reply_text("❌ Solo el administrador puede usar este comando.")
        return

    stats = get_ban_stats()
    text = (
        f"📊 *ESTADISTICAS DE BANS*\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        f"🔒 *Activos:* {stats['active']}\n"
        f"   ⏳ Temporales: {stats['temporary']}\n"
        f"   🔴 Permanentes: {stats['permanent']}\n\n"
        f"📋 *Total historico:* {stats['total']}\n"
        f"📝 *Total acciones:* {stats['total_logs']}\n\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        f"⏰ *Duraciones disponibles:*\n"
    )
    for key, label in BAN_DURATION_LABELS.items():
        text += f"  • `{key}` — {label}\n"

    text += (
        f"\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        f"🤖 *Auto-ban por:* links, spam, keywords sospechosas\n"
        f"👮 *Ban manual:* /ban <user_id> [duracion]\n"
        f"🔓 *Desbanear:* /unban <user_id>\n"
        f"📋 *Lista:* /banlist"
    )
    try:
        await update.message.reply_text(text, parse_mode=ParseMode.MARKDOWN)
    except Exception:
        await update.message.reply_text(text)


# =============================================================================
# CALLBACK HANDLERS FOR BAN SYSTEM
# =============================================================================
async def callback_ban_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle ban-related callback buttons (duration selection, confirm, etc.)."""
    query = update.callback_query
    if not query:
        return

    if not is_admin(query.from_user.id):
        await query.answer("❌ No eres admin.", show_alert=True)
        return

    data = query.data
    await query.answer()

    try:
        # Duration selection: bansel_1w_123456789
        if data.startswith("bansel_"):
            parts = data.split("_", 2)
            if len(parts) < 3:
                return
            duration_key = parts[1]
            target_id = int(parts[2])

            if duration_key not in BAN_DURATIONS:
                await query.edit_message_text("❌ Duracion invalida.")
                return

            # Get pending ban info
            pending = AWAITING_BAN_DURATION.get(query.from_user.id, {})
            target_name = pending.get('target_name', f'ID {target_id}')
            chat_id = pending.get('chat_id', query.message.chat.id)

            # Execute ban
            duration_label = BAN_DURATION_LABELS.get(duration_key, duration_key)
            ban_user(
                tg_id=target_id,
                username=None,
                first_name=target_name,
                reason='manual',
                ban_type='manual',
                banned_by=query.from_user.id,
                chat_id=chat_id,
                chat_title=query.message.chat.title if query.message.chat else 'N/A',
                duration_key=duration_key,
                notes=f"Banned by admin via button"
            )

            # Restrict
            await _restrict_user(context, chat_id, target_id)

            # Clean up
            AWAITING_BAN_DURATION.pop(query.from_user.id, None)

            kb = [[InlineKeyboardButton("🔙 Volver", callback_data="dash")]]
            await query.edit_message_text(
                f"🔒 *USUARIO BANNEADO*\n"
                f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
                f"👤 *Usuario:* {target_name}\n"
                f"🆔 *ID:* `{target_id}`\n"
                f"⏰ *Duracion:* {duration_label}\n\n"
                f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
                f"🔓 Para desbanear: /unban `{target_id}`",
                parse_mode=ParseMode.MARKDOWN,
                reply_markup=InlineKeyboardMarkup(kb)
            )

        # Cancel ban
        elif data == "bancancel":
            AWAITING_BAN_DURATION.pop(query.from_user.id, None)
            await query.edit_message_text("❌ Ban cancelado.")

        # Ban list callback
        elif data == "banlist":
            bans = get_active_bans(limit=20)
            stats = get_ban_stats()
            if not bans:
                text = "📋 No hay usuarios baneados."
                kb = [[InlineKeyboardButton("🔄 Actualizar", callback_data="banlist")]]
            else:
                text = (
                    f"📋 *BANS ACTIVOS* ({stats['active']})\n"
                    f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
                )
                kb = []
                for i, ban in enumerate(bans[:15], 1):
                    uname = f"@{ban['username']}" if ban.get('username') else ban.get('first_name', 'N/A')
                    dur = BAN_DURATION_LABELS.get(ban.get('duration_key', 'perm'), 'N/A')
                    ban_type = "🤖" if ban.get('ban_type') == 'auto' else "👮"
                    text += f"{i}. {ban_type} {uname} (`{ban['tg_id']}`) — {dur}\n"
                    kb.append([InlineKeyboardButton(f"🔓 Desbanear {uname[:20]}", callback_data=f"unban_{ban['tg_id']}")])
                kb.append([InlineKeyboardButton("🔄 Actualizar", callback_data="banlist")])
            try:
                await query.edit_message_text(text, parse_mode=ParseMode.MARKDOWN, reply_markup=InlineKeyboardMarkup(kb))
            except Exception:
                await query.message.reply_text(text, parse_mode=ParseMode.MARKDOWN)

        # Unban from inline button
        elif data.startswith("unban_"):
            target_id = int(data.split("_")[1])
            # Unban in DB
            unban_user(target_id, query.from_user.id, reason='manual_unban')
            # Reset strikes (clean slate)
            reset_strikes(target_id, GROUP_ID)
            reset_strikes(target_id, CHANNEL_ID)
            # Mark as "recently unbanned" — first re-offense = warning only
            set_unban_warning(target_id, GROUP_ID)
            # Unrestrict in group (restrict/unban only works in supergroups, not channels)
            try:
                await _unrestrict_user(context, GROUP_ID, target_id)
            except:
                pass
            # Refresh banlist
            bans = get_active_bans(limit=20)
            stats = get_ban_stats()
            if not bans:
                text = "📋 No hay usuarios baneados."
                kb = [[InlineKeyboardButton("🔄 Actualizar", callback_data="banlist")]]
            else:
                text = (
                    f"📋 *BANS ACTIVOS* ({stats['active']})\n"
                    f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
                )
                kb = []
                for i, ban in enumerate(bans[:15], 1):
                    uname = f"@{ban['username']}" if ban.get('username') else ban.get('first_name', 'N/A')
                    dur = BAN_DURATION_LABELS.get(ban.get('duration_key', 'perm'), 'N/A')
                    ban_type = "🤖" if ban.get('ban_type') == 'auto' else "👮"
                    text += f"{i}. {ban_type} {uname} (`{ban['tg_id']}`) — {dur}\n"
                    kb.append([InlineKeyboardButton(f"🔓 Desbanear {uname[:20]}", callback_data=f"unban_{ban['tg_id']}")])
                kb.append([InlineKeyboardButton("🔄 Actualizar", callback_data="banlist")])
            await query.answer(f"🔓 Usuario {target_id} desbaneado")
            try:
                await query.edit_message_text(
                    f"🔓 *USUARIO DESBANEADO: `{target_id}`*\n\n{text}",
                    parse_mode=ParseMode.MARKDOWN,
                    reply_markup=InlineKeyboardMarkup(kb)
                )
            except Exception:
                await query.message.reply_text(f"🔓 Usuario `{target_id}` desbaneado.", parse_mode=ParseMode.MARKDOWN)

    except Exception as e:
        logger.error(f"Ban callback error: {e}")
        try:
            await query.message.reply_text(f"❌ Error: {e}")
        except:
            pass


# =============================================================================
# AUTO-UNBAN JOB — runs every 60 seconds
# =============================================================================
async def auto_unban_job(context: ContextTypes.DEFAULT_TYPE):
    """Periodic job to unban expired temporary bans and restore permissions."""
    count = cleanup_expired_bans()
    if count > 0:
        logger.info(f"Auto-unban job: freed {count} users")
        # Try to unrestrict them in known groups
        # (We unrestrict in GROUP_ID if available)
        if GROUP_ID:
            try:
                expired_bans = get_all_bans(limit=50)
                for ban in expired_bans:
                    if ban.get('is_active') == 0 and ban.get('expires_at'):
                        try:
                            await _unrestrict_user(context, GROUP_ID, ban['tg_id'])
                        except:
                            pass
            except Exception as e:
                logger.error(f"Auto-unban restrict cleanup: {e}")
async def callback_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle inline keyboard callbacks — ALL buttons work now."""
    query = update.callback_query

    if not is_admin(query.from_user.id):
        await query.answer("❌ No eres admin.", show_alert=True)
        return

    data = query.data
    uid = query.from_user.id

    # Answer the callback immediately (removes loading spinner)
    await query.answer()

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
        # --- Panel de configuracion (imagenes + plantillas) ---
        elif data == "cfg":
            await _callback_cfg_menu(query, context)
        elif data == "cfg_back":
            await _callback_cfg_menu(query, context)
        elif data == "cfg_welcome_img":
            await _callback_cfg_ask_photo(query, context, "welcome")
        elif data == "cfg_ad_img":
            await _callback_cfg_ask_photo(query, context, "ad")
        elif data == "cfg_ban_img":
            # Check if current ban media exists
            ban_file_id, ban_media_type = get_ban_media()
            current_info = ""
            if ban_file_id:
                current_info = f"\n📷 *Actual:* {ban_media_type}\n🗑️ Usa /remove_ban_media para quitarla\n"
            AWAITING_BAN_MEDIA[uid] = True
            await query.edit_message_text(
                f"🚨 *IMAGEN/GIF/VIDEO DE BAN*\n"
                f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
                f"Esta imagen se enviara junto con el mensaje de ban\n"
                f"cuando alguien infrinja las reglas.{current_info}\n"
                f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
                f"📸 *Envia ahora:* foto, GIF o video.\n"
                f"❌ /cancel — cancelar",
                parse_mode=ParseMode.MARKDOWN
            )
        elif data == "cfg_welcome_text":
            await _callback_cfg_ask_text(query, context, "welcome")
        elif data == "cfg_ad_text":
            await _callback_cfg_ask_text(query, context, "ad")
        elif data == "cfg_show_texts":
            await _callback_cfg_show_texts(query, context)
        elif data == "cfg_send_ad":
            await _callback_cfg_send_ad(query, context)
        # --- MULTI-TEMPLATE SYSTEM ---
        elif data.startswith("tpl_"):
            await _handle_template_callback(update, context)
            return
        # --- Panel de REGLAS ---
        elif data == "rules_show":
            rules = get_rules_text()
            kb = InlineKeyboardMarkup([
                [InlineKeyboardButton("📝 Editar Reglas", callback_data="rules_edit"),
                 InlineKeyboardButton("📤 Enviar al Grupo", callback_data="rules_send")],
                [InlineKeyboardButton("🔙 Volver", callback_data="cfg_back")],
            ])
            try:
                await query.edit_message_text(rules, parse_mode=ParseMode.MARKDOWN, reply_markup=kb)
            except Exception:
                await query.message.reply_text(rules, parse_mode=ParseMode.MARKDOWN, reply_markup=kb)
        elif data == "rules_edit":
            AWAITING_RULES[query.from_user.id] = True
            await query.edit_message_text(
                "📝 *EDITAR REGLAS DEL GRUPO*\n\n"
                "Enviame el texto con todas las reglas.\n"
                "Usa *negrita* para enfatizar, listas, emojis, etc.\n\n"
                "Ejemplo:\n"
                "1. No enviar links\n"
                "2. No spam\n"
                "3. No contenido adulto\n\n"
                "Las reglas anteriores seran REEMPLAZADAS.",
                parse_mode=ParseMode.MARKDOWN
            )
        elif data == "rules_send":
            rules = get_rules_text()
            success = 0
            for chat_id, name in [(GROUP_ID, "Grupo"), (CHANNEL_ID, "Canal")]:
                try:
                    await context.bot.send_message(chat_id=chat_id, text=rules, parse_mode=ParseMode.MARKDOWN)
                    success += 1
                except Exception as e:
                    logger.error(f"Send rules to {name}: {e}")
            kb = InlineKeyboardMarkup([
                [InlineKeyboardButton("🔙 Volver", callback_data="cfg_back")],
            ])
            await query.edit_message_text(
                f"✅ Reglas enviadas al grupo y canal!\n"
                f"📊 Enviadas: {success}/2",
                reply_markup=kb
            )
        # --- Panel de BANS ---
        elif data == "banlist":
            await callback_ban_handler(update, context)
            return
        elif data.startswith("bansel_") or data == "bancancel":
            await callback_ban_handler(update, context)
            return
        elif data.startswith("unban_"):
            await callback_ban_handler(update, context)
            return
        elif data == "banstats":
            # Show ban stats as callback
            stats = get_ban_stats()
            text = (
                f"📊 *ESTADISTICAS DE BANS*\n"
                f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
                f"🔒 *Activos:* {stats['active']}\n"
                f"   ⏳ Temporales: {stats['temporary']}\n"
                f"   🔴 Permanentes: {stats['permanent']}\n\n"
                f"📋 *Total historico:* {stats['total']}\n"
                f"📝 *Total acciones:* {stats['total_logs']}\n"
            )
            kb = InlineKeyboardMarkup([
                [InlineKeyboardButton("📋 Ver bans", callback_data="banlist"),
                 InlineKeyboardButton("🔄 Actualizar", callback_data="banstats")],
                [InlineKeyboardButton("📊 Dashboard", callback_data="dash")],
            ])
            try:
                await query.edit_message_text(text, parse_mode=ParseMode.MARKDOWN, reply_markup=kb)
            except Exception:
                await query.message.reply_text(text, parse_mode=ParseMode.MARKDOWN, reply_markup=kb)
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
    logger.info("Starting MoviVIP Notification Bot v4.0 — GRADE MILITAR...")

    init_notif_db()
    init_ban_db()
    load_detected_ids()

    app = Application.builder().token(TOKEN).build()

    # =========================================================================
    # COMMANDS — Admin panel
    # =========================================================================
    app.add_handler(CommandHandler("start", cmd_start))
    app.add_handler(CommandHandler("db", cmd_db))
    app.add_handler(CommandHandler("stats", cmd_stats))
    app.add_handler(CommandHandler("members", cmd_members))
    app.add_handler(CommandHandler("reports", cmd_reports))
    app.add_handler(CommandHandler("welcomes", cmd_welcome_log))
    app.add_handler(CommandHandler("welcome_preview", cmd_preview))
    app.add_handler(CommandHandler("preview", cmd_preview))
    app.add_handler(CommandHandler("official", cmd_send_official))
    app.add_handler(CommandHandler("set_welcome", cmd_set_welcome))
    app.add_handler(CommandHandler("set_ad", cmd_set_ad))
    app.add_handler(CommandHandler("send_ad", cmd_send_ad))
    app.add_handler(CommandHandler("publicidad", cmd_send_ad))
    app.add_handler(CommandHandler("set_welcome_text", cmd_set_welcome_text))
    app.add_handler(CommandHandler("set_ad_text", cmd_set_ad_text))
    app.add_handler(CommandHandler("show_texts", cmd_show_texts))
    app.add_handler(CommandHandler("config", cmd_config))
    app.add_handler(CommandHandler("help", cmd_help))

    # =========================================================================
    # BAN COMMANDS — Solo admin (ADMIN_IDS)
    # =========================================================================
    app.add_handler(CommandHandler("ban", cmd_ban))
    app.add_handler(CommandHandler("unban", cmd_unban))
    app.add_handler(CommandHandler("banlist", cmd_banlist))
    app.add_handler(CommandHandler("banstats", cmd_banstats))

    # =========================================================================
    # RULES COMMANDS — admin configura, todos pueden ver
    # =========================================================================
    app.add_handler(CommandHandler("setrules", cmd_setrules))
    app.add_handler(CommandHandler("rules", cmd_rules))
    app.add_handler(CommandHandler("send_rules", cmd_send_rules))
    app.add_handler(CommandHandler("remove_ban_media", cmd_remove_ban_media))
    app.add_handler(CommandHandler("cancel", cmd_cancel))

    # =========================================================================
    # AUTO-DETECT COMMANDS — admin configures group/channel IDs
    # =========================================================================
    @staticmethod
    async def cmd_setgroup(update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Set group ID manually. Usage: /setgroup <chat_id>"""
        if not is_admin(update.effective_user.id):
            return
        global GROUP_ID
        args = context.args or []
        if not args:
            # Auto-detect from current chat
            if update.effective_chat.type in ('group', 'supergroup'):
                GROUP_ID = update.effective_chat.id
                set_setting("detected_group_id", str(GROUP_ID))
                await update.message.reply_text(
                    f"✅ Grupo detectado automaticamente:\n"
                    f"🆔 `{GROUP_ID}`\n"
                    f"📛 {update.effective_chat.title}",
                    parse_mode=ParseMode.MARKDOWN
                )
            else:
                await update.message.reply_text(
                    "❌ Usa este comando desde el grupo, o proporciona el ID:\n"
                    "`/setgroup -1001234567890`",
                    parse_mode=ParseMode.MARKDOWN
                )
            return
        try:
            GROUP_ID = int(args[0])
            set_setting("detected_group_id", str(GROUP_ID))
            await update.message.reply_text(
                f"✅ Grupo configurado: `{GROUP_ID}`",
                parse_mode=ParseMode.MARKDOWN
            )
        except ValueError:
            await update.message.reply_text("❌ ID invalido. Ejemplo: `/setgroup -1001234567890`", parse_mode=ParseMode.MARKDOWN)

    @staticmethod
    async def cmd_setchannel(update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Set channel ID manually. Usage: /setchannel <chat_id>"""
        if not is_admin(update.effective_user.id):
            return
        global CHANNEL_ID
        args = context.args or []
        if not args:
            await update.message.reply_text(
                "❌ Proporciona el ID del canal:\n"
                "`/setchannel -1001234567890`",
                parse_mode=ParseMode.MARKDOWN
            )
            return
        try:
            CHANNEL_ID = int(args[0])
            set_setting("detected_channel_id", str(CHANNEL_ID))
            await update.message.reply_text(
                f"✅ Canal configurado: `{CHANNEL_ID}`",
                parse_mode=ParseMode.MARKDOWN
            )
        except ValueError:
            await update.message.reply_text("❌ ID invalido. Ejemplo: `/setchannel -1001234567890`", parse_mode=ParseMode.MARKDOWN)

    app.add_handler(CommandHandler("setgroup", cmd_setgroup))
    app.add_handler(CommandHandler("setchannel", cmd_setchannel))

    async def cmd_set_ban_media(update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Shortcut: ask admin to send ban media."""
        if not is_admin(update.effective_user.id):
            return
        ban_file_id, ban_media_type = get_ban_media()
        current_info = ""
        if ban_file_id:
            current_info = f"\n📷 *Actual:* {ban_media_type}\n🗑️ Usa /remove_ban_media para quitarla\n"
        AWAITING_BAN_MEDIA[update.effective_user.id] = True
        await update.message.reply_text(
            f"🚨 *IMAGEN/GIF/VIDEO DE BAN*\n"
            f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
            f"Esta imagen se enviara junto con el mensaje de ban\n"
            f"cuando alguien infrinja las reglas.{current_info}\n"
            f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
            f"📸 *Envia ahora:* foto, GIF o video.\n"
            f"❌ /cancel — cancelar",
            parse_mode=ParseMode.MARKDOWN
        )

    app.add_handler(CommandHandler("set_ban_media", cmd_set_ban_media))

    # =========================================================================
    # CALLBACKS — inline keyboards (admin + ban system)
    # =========================================================================
    app.add_handler(CallbackQueryHandler(callback_handler))

    # =========================================================================
    # WELCOME / LEAVE
    # =========================================================================
    app.add_handler(MessageHandler(filters.StatusUpdate.NEW_CHAT_MEMBERS, welcome_new_member))
    app.add_handler(MessageHandler(filters.StatusUpdate.LEFT_CHAT_MEMBER, welcome_left_member))

    # =========================================================================
    # CHANNEL SUBSCRIBER DETECTION
    # =========================================================================
    app.add_handler(ChatMemberHandler(channel_member_handler, ChatMemberHandler.CHAT_MEMBER))

    # =========================================================================
    # ADMIN TEXT (templates + rules) — PRIVATE CHATS ONLY so it doesn't block anti-spam
    # =========================================================================
    app.add_handler(MessageHandler(filters.ChatType.PRIVATE & filters.TEXT & ~filters.COMMAND, handle_admin_text))
    # Rules text input (admin sends rules after /setrules) — PRIVATE ONLY
    app.add_handler(MessageHandler(filters.ChatType.PRIVATE & filters.TEXT & ~filters.COMMAND, handle_admin_rules_text))

    # =========================================================================
    # ANTI-SPAM ENFORCEMENT — runs on ALL group text messages
    # Checks links, keywords, suspicious patterns → auto-ban
    # =========================================================================
    app.add_handler(MessageHandler(
        filters.ChatType.GROUPS & filters.TEXT & ~filters.COMMAND,
        enforce_anti_spam
    ))

    # =========================================================================
    # FILE BLOCKING — no-admin users cannot send documents in groups
    # =========================================================================
    app.add_handler(MessageHandler(
        filters.ChatType.GROUPS & filters.Document.ALL,
        enforce_no_files
    ))

    # =========================================================================
    # MENTIONS (reports) — group only
    # =========================================================================
    app.add_handler(MessageHandler(filters.ChatType.GROUPS & filters.TEXT, detect_mentions))

    # =========================================================================
    # PHOTOS FROM ADMIN (welcome/ad image upload) — PRIVATE CHATS ONLY
    # =========================================================================
    app.add_handler(MessageHandler(filters.ChatType.PRIVATE & filters.PHOTO, handle_admin_photo))

    # =========================================================================
    # MULTIMEDIA FROM ALL USERS — allow GIFs, videos, photos
    # Checks captions for spam. Registered AFTER admin photo handler.
    # =========================================================================
    app.add_handler(MessageHandler(filters.PHOTO | filters.VIDEO | filters.ANIMATION | filters.Document.ALL, handle_user_media))

    # =========================================================================
    # BAN CHECK ON JOIN — restrict banned users who try to rejoin
    # =========================================================================
    app.add_handler(MessageHandler(filters.StatusUpdate.NEW_CHAT_MEMBERS, check_banned_member))

    # =========================================================================
    # PRIVATE CHAT HANDLERS — users send media to the bot privately
    # =========================================================================
    # Private media (photos, videos, GIFs, docs, stickers) — stored for ban display
    app.add_handler(MessageHandler(
        filters.ChatType.PRIVATE & (filters.PHOTO | filters.VIDEO | filters.ANIMATION | filters.Document.ALL | filters.Sticker.ALL),
        handle_private_media
    ))
    # Private text — simple response
    app.add_handler(MessageHandler(
        filters.ChatType.PRIVATE & filters.TEXT & ~filters.COMMAND,
        handle_private_text
    ))

    # =========================================================================
    # AUTO-UNBAN BACKGROUND JOB — runs every 60 seconds
    # =========================================================================
    if app.job_queue:
        app.job_queue.run_repeating(
            auto_unban_job,
            interval=60,  # Check every 60 seconds
            first=10,     # First run after 10 seconds
            name="auto_unban_job"
        )
        logger.info("Auto-unban job scheduled (every 60s)")
    else:
        logger.warning("JobQueue not available — auto-unban will not run. Install python-telegram-ext[job-queue]")

    logger.info("Notification Bot v4.0 — GRADE MILITAR — running!")
    app.run_polling(drop_pending_updates=True)


if __name__ == '__main__':
    main()
