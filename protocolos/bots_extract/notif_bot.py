#!/usr/bin/env python3
"""
MoviVIP Notification Bot v3.0
- Welcome with logo + inline buttons (links)
- Mention/tag detection → admin reports
- Admin panel with working callback buttons
- Full DB integration
"""
import os
import sqlite3
import logging
import datetime
import sys
import io
from pathlib import Path

from telegram import (
    Update, InlineKeyboardButton, InlineKeyboardMarkup
)
from telegram.ext import (
    Application, CommandHandler, MessageHandler,
    CallbackQueryHandler, ContextTypes, filters, ChatMemberHandler
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
    NOTIF_CHANNEL_ID as CHANNEL_ID,
    NOTIF_GROUP_ID as GROUP_ID,
    ADMIN_IDS,
    MY_BRAND,
)

BRAND = MY_BRAND  # marca del que configura el VPS (se inyecta en {brand})

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
WELCOME_IMG = str(BOT_DIR / "welcome.jpg")   # imagen de bienvenida (welcome)
AD_IMG = str(BOT_DIR / "ad.jpg")             # imagen de publicidad (anuncio)

# Plantillas de TEXTO configurables por el admin (se cargan con /set_welcome_text
# y /set_ad_text). Quien configura el VPS decide los precios, planes (3-7-15-30
# dias) y el formato. Se guardan en la carpeta del bot y cada carga NUEVA
# REEMPLAZA a la anterior.
WELCOME_TEXT_FILE = str(BOT_DIR / "welcome_text.txt")
AD_TEXT_FILE = str(BOT_DIR / "ad_text.txt")

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
# IMAGENES CONFIGURABLES (bienvenida / publicidad)
# ---------------------------------------------------------------------------
# user_id -> "welcome" | "ad"   (admin esperando a enviar una foto)
AWAITING_PHOTO = {}


async def _send_photo_or_text(context, chat_id, img_path, text, parse_mode=None, reply_markup=None):
    """Envia la imagen si existe; si no, envia solo el texto. Nunca rompe el flujo."""
    if img_path and os.path.exists(img_path):
        try:
            with open(img_path, 'rb') as photo:
                await context.bot.send_photo(
                    chat_id=chat_id, photo=photo, caption=text,
                    parse_mode=parse_mode or ParseMode.MARKDOWN,
                    reply_markup=reply_markup)
            return True
        except Exception as e:
            logger.warning(f"send_photo error ({img_path}): {e}")
    try:
        await context.bot.send_message(
            chat_id=chat_id, text=text,
            parse_mode=parse_mode or ParseMode.MARKDOWN,
            reply_markup=reply_markup)
        return True
    except Exception as e:
        logger.warning(f"send_message fallback error: {e}")
        return False


async def _save_photo(message, dest_path):
    """Descarga la foto del mensaje y SOBREESCRIBE el archivo (reemplaza a la anterior)."""
    if not message or not message.photo:
        return False
    photo_file = message.photo[-1].get_file()
    await photo_file.download_to_drive(custom_path=dest_path)
    return True


def _welcome_img_path():
    """Ruta de la imagen de bienvenida: la configurable primero, el logo como fallback."""
    if os.path.exists(WELCOME_IMG):
        return WELCOME_IMG
    return LOGO_PATH if os.path.exists(LOGO_PATH) else None


async def handle_admin_photo(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Admin envia una foto: se guarda como imagen de bienvenida o publicidad (reemplaza)."""
    if not update.message or not update.message.photo:
        return
    user = update.effective_user
    if not is_admin(user.id):
        return

    kind = AWAITING_PHOTO.pop(user.id, None)
    caption = (update.message.caption or "").strip().lower()

    # El admin tambien puede mandar la foto directo con un caption clave
    if not kind:
        if caption in ("welcome", "bienvenida", "bienvenido"):
            kind = "welcome"
        elif caption in ("ad", "publicidad", "anuncio", "promo"):
            kind = "ad"
    if not kind:
        return  # no es una carga de imagen — no molestar al admin

    dest = WELCOME_IMG if kind == "welcome" else AD_IMG
    try:
        await _save_photo(update.message, dest)
    except Exception as e:
        logger.error(f"save {kind} photo: {e}")
        await update.message.reply_text(f"❌ No pude guardar la imagen: {e}")
        return

    label = "BIENVENIDA" if kind == "welcome" else "PUBLICIDAD"
    logger.info(f"Admin {user.id} actualizo imagen de {kind} -> {dest}")
    await update.message.reply_text(
        f"✅ *Imagen de {label} guardada en el VPS*\n"
        f"📁 `{dest}`\n"
        f"↩️ La imagen ANTERIOR fue REEMPLAZADA.\n\n"
        f"👁️ /preview - ver la bienvenida\n"
        f"📣 /send_ad - enviar la publicidad",
        parse_mode=ParseMode.MARKDOWN,
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
    success = 0
    for chat_id, name in [(CHANNEL_ID, "Canal"), (GROUP_ID, "Grupo")]:
        ok = await _send_photo_or_text(context, chat_id, AD_IMG, get_publicity_text())
        success += 1 if ok else 0
        logger.info(f"Ad enviado a {name}: ok={ok}")
    await update.message.reply_text(
        f"✅ Publicidad enviada!\n"
        f"📊 Enviada: {success}/2\n"
        f"💡 Para cambiar la imagen: /set_ad\n"
        f"💡 Para cambiar el texto: /set_ad_text")


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
    """Texto de publicidad: la plantilla del admin si existe, si no el default.
    La MARCA ({brand}) del que configura el VPS siempre se inyecta."""
    return _fill_plantilla(_read_plantilla(AD_TEXT_FILE, PUBLICITY_TEXT), {"brand": BRAND})


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
    """Admin envia un texto: se guarda como plantilla de bienvenida o publicidad
    (solo actua si el admin pidio cargar una plantilla con /set_welcome_text o
    /set_ad_text; cualquier otro mensaje se ignora y sigue el flujo normal)."""
    if not update.message or not update.message.text:
        return
    user = update.effective_user
    if not is_admin(user.id):
        return
    kind = AWAITING_TEXT.pop(user.id, None)
    if not kind:
        return

    dest = WELCOME_TEXT_FILE if kind == "welcome" else AD_TEXT_FILE
    try:
        _save_plantilla(dest, update.message.text)
    except Exception as e:
        logger.error(f"save {kind} text: {e}")
        await update.message.reply_text(f"❌ No pude guardar la plantilla: {e}")
        return

    label = "BIENVENIDA" if kind == "welcome" else "PUBLICIDAD"
    logger.info(f"Admin {user.id} actualizo plantilla de {kind} -> {dest}")
    await update.message.reply_text(
        f"✅ *Plantilla de {label} guardada en el VPS*\n"
        f"📁 `{dest}`\n"
        f"↩️ La plantilla ANTERIOR fue REEMPLAZADA.\n\n"
        f"👁️ /preview - ver como queda la bienvenida\n"
        f"📣 /send_ad - enviar la publicidad",
        parse_mode=ParseMode.MARKDOWN,
        reply_markup=_config_menu_kb())


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
    return InlineKeyboardMarkup([
        [InlineKeyboardButton("🖼️ Imagen de BIENVENIDA", callback_data="cfg_welcome_img"),
         InlineKeyboardButton("🖼️ Imagen de PUBLICIDAD", callback_data="cfg_ad_img")],
        [InlineKeyboardButton("✍️ Plantilla de BIENVENIDA", callback_data="cfg_welcome_text"),
         InlineKeyboardButton("✍️ Plantilla de PUBLICIDAD", callback_data="cfg_ad_text")],
        [InlineKeyboardButton("📋 Ver plantillas actuales", callback_data="cfg_show_texts")],
        [InlineKeyboardButton("📣 Enviar publicidad", callback_data="cfg_send_ad")],
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
    success = 0
    for chat_id, name in [(CHANNEL_ID, "Canal"), (GROUP_ID, "Grupo")]:
        ok = await _send_photo_or_text(context, chat_id, AD_IMG, get_publicity_text())
        success += 1 if ok else 0
        logger.info(f"Ad enviado a {name}: ok={ok}")
    await query.message.reply_text(
        f"✅ Publicidad enviada!\n"
        f"📊 Enviada: {success}/2",
        reply_markup=_config_menu_kb())


def get_welcome_keyboard():
    """Inline keyboard with all links as buttons."""
    return InlineKeyboardMarkup([
        [
            InlineKeyboardButton("🔑 Bot SSH", url=f"https://t.me/{SSH_BOT.replace('@','')}"),
            InlineKeyboardButton("🛒 Bot Tienda", url=f"https://t.me/{STORE_BOT.replace('@','')}")
        ],
        [
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
        ],
        [
            InlineKeyboardButton("👥 Comunidad WA", url=SOCIAL['whatsapp_community']),
            InlineKeyboardButton("📞 WA Personal", url=SOCIAL['whatsapp_personal'])
        ],
    ])

def build_welcome_text(first_name, username, tg_id, source, join_date=None):
    """Build welcome text from the admin's template (welcome_text.txt) if loaded;
    falls back to the default template. Placeholders disponibles:
    {first_name}, {username}, {id}, {date}, {source}, {source_emoji}."""
    if not join_date:
        join_date = datetime.datetime.now().strftime('%d/%m/%Y %H:%M')

    user_display = f"@{username}" if username else first_name or "Usuario"
    source_emoji = "📢 Canal" if source == "channel" else "💬 Grupo"

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
                with open(welcome_img, 'rb') as photo:
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
        await update.message.reply_text(
            "🤖 *MoviVIP Notification Bot*\n\n"
            "Soy el bot de notificaciones de MoviVIP Network.\n"
            "Recibo reportes y doy la bienvenida a nuevos miembros.\n\n"
            f"🌐 {SOCIAL['web']}",
            parse_mode=ParseMode.MARKDOWN
        )
        return

    kb = [
        [InlineKeyboardButton("📊 Dashboard", callback_data="dash"),
         InlineKeyboardButton("👥 Members", callback_data="members")],
        [InlineKeyboardButton("🔔 Reports", callback_data="reports"),
         InlineKeyboardButton("📨 Welcomes", callback_data="welcomes")],
        [InlineKeyboardButton("📋 Full DB", callback_data="fulldb"),
         InlineKeyboardButton("📈 Stats", callback_data="stats")],
        [InlineKeyboardButton("📢 Enviar Comunicado", callback_data="send_official")],
        [InlineKeyboardButton("⚙️ Configuracion (imagenes + plantillas)", callback_data="cfg")],
    ]

    await update.message.reply_text(
        f"👑 *MoviVIP Notif Bot v3.0*\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        f"🔐 Panel de Administracion\n\n"
        f"📊 Dashboard en tiempo real\n"
        f"👥 Base de datos completa\n"
        f"🔔 Reportes y menciones\n"
        f"📨 Log de bienvenidas\n"
        f"⚙️ Configuracion de imagenes y plantillas\n\n"
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
        f"👑 *MoviVIP Notif Bot v3.0*\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        f"📊 /db - Base de datos\n"
        f"📈 /stats - Estadisticas\n"
        f"👥 /members - Miembros\n"
        f"🔔 /reports - Reportes\n"
        f"📨 /welcomes - Log bienvenidas\n"
        f"👁️ /preview - Preview welcome\n"
        f"📢 /official - Enviar comunicado\n"
        f"❓ /help - Ayuda\n\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        f"🖼️ *IMAGENES (reemplazan en el VPS):*\n"
        f"/set_welcome - cargar imagen de bienvenida\n"
        f"/set_ad - cargar imagen de publicidad\n\n"
        f"✍️ *PLANTILLAS DE TEXTO (reemplazan en el VPS):*\n"
        f"/set_welcome_text - plantilla de bienvenida\n"
        f"/set_ad_text - plantilla de publicidad\n"
        f"📣 /send_ad - enviar publicidad al canal/grupo\n"
        f"📋 /show_texts - ver plantillas actuales\n"
        f"⚙️ /config - PANEL CON BOTONES (imagenes + plantillas)\n\n"
        f"💡 En las plantillas usa {{brand}} para la marca\n"
        f"y define TU que planes y precios van (solo 30,\n"
        f"15 y 30, 3-7-15-30... como decidas).\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
        parse_mode=ParseMode.MARKDOWN)


# =============================================================================
# CALLBACK HANDLER — FIXED: uses query.edit_message_text or query.message
# =============================================================================
async def callback_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle inline keyboard callbacks — ALL buttons work now."""
    query = update.callback_query

    if not is_admin(query.from_user.id):
        await query.answer("❌ No eres admin.", show_alert=True)
        return

    data = query.data

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
        elif data == "cfg_welcome_text":
            await _callback_cfg_ask_text(query, context, "welcome")
        elif data == "cfg_ad_text":
            await _callback_cfg_ask_text(query, context, "ad")
        elif data == "cfg_show_texts":
            await _callback_cfg_show_texts(query, context)
        elif data == "cfg_send_ad":
            await _callback_cfg_send_ad(query, context)
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
    logger.info("Starting MoviVIP Notification Bot v3.0...")

    init_notif_db()

    app = Application.builder().token(TOKEN).build()

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
    app.add_handler(CommandHandler("set_welcome", cmd_set_welcome))
    app.add_handler(CommandHandler("set_ad", cmd_set_ad))
    app.add_handler(CommandHandler("send_ad", cmd_send_ad))
    app.add_handler(CommandHandler("publicidad", cmd_send_ad))
    app.add_handler(CommandHandler("set_welcome_text", cmd_set_welcome_text))
    app.add_handler(CommandHandler("set_ad_text", cmd_set_ad_text))
    app.add_handler(CommandHandler("show_texts", cmd_show_texts))
    app.add_handler(CommandHandler("config", cmd_config))
    app.add_handler(CommandHandler("help", cmd_help))

    # Callbacks
    app.add_handler(CallbackQueryHandler(callback_handler))

    # Welcome
    app.add_handler(MessageHandler(filters.StatusUpdate.NEW_CHAT_MEMBERS, welcome_new_member))
    app.add_handler(MessageHandler(filters.StatusUpdate.LEFT_CHAT_MEMBER, welcome_left_member))

    # Channel subscriber detection (ChatMember updates — required for channels)
    app.add_handler(ChatMemberHandler(channel_member_handler, ChatMemberHandler.CHAT_MEMBER))

    # Text from admin (welcome / publicity templates, replaces on VPS)
    # Registrado ANTES de detect_mentions para que el admin pueda cargar
    # plantillas tambien escribiendo dentro del grupo.
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_admin_text))

    # Mentions (group only)
    app.add_handler(MessageHandler(filters.ChatType.GROUPS & filters.TEXT, detect_mentions))

    # Photos from admin (welcome / publicity image upload, replaces on VPS)
    app.add_handler(MessageHandler(filters.PHOTO, handle_admin_photo))

    logger.info("Notification Bot v3.0 running!")
    app.run_polling(drop_pending_updates=True)


if __name__ == '__main__':
    main()
