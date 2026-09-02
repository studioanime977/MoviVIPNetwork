# -*- coding: utf-8 -*-
"""
MoviVIP Notif Bot — Extras: PROMOCIONES + BIENVENIDA EDITABLE + FOTO SIEMPRE
Módulo modular que se integra al notif_bot.py existente SIN simplificar/romper nada.

Añade:
  1. Tabla welcome_settings (foto file_id + botones editables)
  2. Tabla promos (texto + foto/plantilla subible + botón visible)
  3. get_welcome_keyboard_editable() — botones desde DB
  4. send_welcome_media() — SIEMPRE envía foto (arregla bug de las 2 primeras veces)
  5. Panel admin: editar bienvenida (foto + botones), gestionar promos con imagen
"""
import sqlite3
import json
import os
import logging

logger = logging.getLogger("notif_extras")

DB_PATH = os.environ.get("NOTIF_DB", "/root/movivip.db")


def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_notif_extras_db():
    conn = get_db()
    c = conn.cursor()
    # ------------------------------------------------------------------
    # CONFIG BIENVENIDA: foto (file_id) + texto + botones editable
    # ------------------------------------------------------------------
    c.execute("""
    CREATE TABLE IF NOT EXISTS welcome_settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        foto_file_id TEXT DEFAULT '',
        texto TEXT DEFAULT '',
        botones TEXT DEFAULT '[]',        -- JSON: [{text, emoji, link, visible}]
        updated_at TEXT DEFAULT (datetime('now'))
    )""")
    # Fila por defecto (id=1)
    c.execute("SELECT COUNT(*) FROM welcome_settings")
    if c.fetchone()[0] == 0:
        c.execute("INSERT INTO welcome_settings (id, foto_file_id, texto, botones) VALUES (1, '', '', '[]')")

    # ------------------------------------------------------------------
    # PROMOS: plantilla/foto subible + texto + botón + opciones
    # ------------------------------------------------------------------
    c.execute("""
    CREATE TABLE IF NOT EXISTS promos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        titulo TEXT DEFAULT '',
        texto TEXT DEFAULT '',
        foto_file_id TEXT DEFAULT '',
        boton_texto TEXT DEFAULT '',
        boton_link TEXT DEFAULT '',
        activa INTEGER DEFAULT 1,
        creado_en TEXT DEFAULT (datetime('now'))
    )""")
    conn.commit()
    conn.close()


# =============================================================================
# BIENVENIDA — SETTINGS
# =============================================================================
def get_welcome_settings():
    init_notif_extras_db()
    conn = get_db()
    c = conn.cursor()
    c.execute("SELECT * FROM welcome_settings WHERE id=1")
    r = c.fetchone()
    conn.close()
    if not r:
        return {"foto_file_id": "", "texto": "", "botones": []}
    try:
        botones = json.loads(r["botones"] or "[]")
    except Exception:
        botones = []
    return {"foto_file_id": r["foto_file_id"] or "", "texto": r["texto"] or "", "botones": botones}


def save_welcome_settings(foto_file_id=None, texto=None, botones=None):
    init_notif_extras_db()
    conn = get_db()
    c = conn.cursor()
    if foto_file_id is not None:
        c.execute("UPDATE welcome_settings SET foto_file_id=?, updated_at=datetime('now') WHERE id=1", (foto_file_id,))
    if texto is not None:
        c.execute("UPDATE welcome_settings SET texto=?, updated_at=datetime('now') WHERE id=1", (texto,))
    if botones is not None:
        c.execute("UPDATE welcome_settings SET botones=?, updated_at=datetime('now') WHERE id=1",
                  (json.dumps(botones, ensure_ascii=False),))
    conn.commit()
    conn.close()


def get_welcome_buttons():
    """Devuelve lista de botones {text, emoji, link, visible} de la DB."""
    settings = get_welcome_settings()
    botones = []
    for b in settings.get("botones", []):
        if not isinstance(b, dict):
            continue
        if not b.get("visible", True):
            continue
        text = (b.get("emoji", "") + " " + b.get("text", "")).strip()
        if not text or not b.get("link"):
            continue
        botones.append({"text": text, "url": b["link"]})
    # Agrupar de a 2 (filas)
    filas = []
    for i in range(0, len(botones), 2):
        filas.append(botones[i:i + 2])
    return filas


# =============================================================================
# BIENVENIDA — MEDIA SIEMPRE (arregla el bug de 2 fotos + caption > 1024)
# =============================================================================
# Límite de captions en Telegram: 1024 caracteres. El HTML premium de
# bienvenida supera ese límite, así que NO se puede usar como caption de foto.
# Solución (Fix JARVIS v4.1): se envía la foto con un caption CORTO y luego el
# mensaje HTML completo + botones como SEGUNDO mensaje. Esto garantiza que la
# imagen de bienvenida SIEMPRE se muestre (antes caía a "texto" por el error
# "Message caption is too long").
def _short_caption(texto, limite=900):
    """Devuelve un caption corto usable en foto/video (límite 1024 chars)."""
    if not texto:
        return "👑 MoviVIP Network"
    res = texto[:limite]
    # Cierra tags HTML que hayan quedado abiertos para evitar 'Can't parse entities'
    for tag in ["b", "i", "u", "code", "pre"]:
        if res.count(f"<{tag}>") > res.count(f"</{tag}>"):
            res += f"</{tag}>"
    return res


async def send_welcome_media_always(context, chat_id, caption=None, reply_markup=None):
    """
    Envía SIEMPRE la foto de bienvenida usando file_id guardado.
    Si no hay foto configurada, envía el logo por defecto.
    Fix v4.1: la foto se envía con caption CORTO y el texto HTML completo con
    botones va como SEGUNDO mensaje (evita 'Message caption is too long').
    """
    settings = get_welcome_settings()
    full_text = caption or settings.get("texto", "")
    foto_id = settings.get("foto_file_id", "")

    def _enviar_texto_html():
        """Envía el HTML completo + botones como mensaje separado."""
        if full_text:
            try:
                return context.bot.send_message(
                    chat_id=chat_id, text=full_text,
                    parse_mode="HTML", reply_markup=reply_markup)
            except Exception as e:
                logger.error(f"send_welcome_media texto error: {e}")
                # Fallback sin parse_mode si el HTML da error
                try:
                    return context.bot.send_message(
                        chat_id=chat_id, text=full_text, reply_markup=reply_markup)
                except Exception as e2:
                    logger.error(f"send_welcome_media texto fallback error: {e2}")

    short_cap = _short_caption(full_text)

    # 1) Foto desde DB (file_id persistente)
    if foto_id:
        try:
            await context.bot.send_photo(
                chat_id=chat_id, photo=foto_id,
                caption=short_cap, parse_mode="HTML")
            # Enviamos también el HTML completo + botones
            await _enviar_texto_html()
            return True, "foto_db"
        except Exception as e:
            logger.error(f"send_welcome_media foto_db error: {e}")

    # 2) Fallback: logo por defecto (si existe)
    logo_path = os.environ.get("NOTIF_LOGO", "/root/movivip_bots/logo.png")
    if os.path.exists(logo_path):
        try:
            with open(logo_path, "rb") as photo:
                await context.bot.send_photo(
                    chat_id=chat_id, photo=photo,
                    caption=short_cap, parse_mode="HTML")
            await _enviar_texto_html()
            return True, "logo"
        except Exception as e:
            logger.error(f"send_welcome_media logo error: {e}")

    # 3) Último fallback: solo texto (con botones)
    await context.bot.send_message(
        chat_id=chat_id, text=full_text,
        parse_mode="HTML", reply_markup=reply_markup)
    return True, "texto"


# =============================================================================
# PROMOS
# =============================================================================
def add_promo(titulo, texto, foto_file_id="", boton_texto="", boton_link=""):
    init_notif_extras_db()
    conn = get_db()
    c = conn.cursor()
    c.execute(
        "INSERT INTO promos (titulo, texto, foto_file_id, boton_texto, boton_link, activa) "
        "VALUES (?,?,?,?,?,1)",
        (titulo, texto, foto_file_id, boton_texto, boton_link))
    pid = c.lastrowid
    conn.commit()
    conn.close()
    return pid


def get_promos(activa=None):
    init_notif_extras_db()
    conn = get_db()
    c = conn.cursor()
    if activa is not None:
        c.execute("SELECT * FROM promos WHERE activa=? ORDER BY creado_en DESC", (1 if activa else 0,))
    else:
        c.execute("SELECT * FROM promos ORDER BY creado_en DESC")
    rows = c.fetchall()
    conn.close()
    return [dict(r) for r in rows]


def get_promo(pid):
    init_notif_extras_db()
    conn = get_db()
    c = conn.cursor()
    c.execute("SELECT * FROM promos WHERE id=?", (pid,))
    r = c.fetchone()
    conn.close()
    return dict(r) if r else None


def update_promo(pid, **campos):
    permitidos = ["titulo", "texto", "foto_file_id", "boton_texto", "boton_link", "activa"]
    sets = []
    vals = []
    for k, v in campos.items():
        if k in permitidos:
            sets.append(f"{k}=?")
            vals.append(v)
    if not sets:
        return False
    vals.append(pid)
    conn = get_db()
    c = conn.cursor()
    c.execute(f"UPDATE promos SET {', '.join(sets)} WHERE id=?", vals)
    conn.commit()
    conn.close()
    return True


def delete_promo(pid):
    conn = get_db()
    c = conn.cursor()
    c.execute("DELETE FROM promos WHERE id=?", (pid,))
    conn.commit()
    conn.close()


async def enviar_promo(context, promo, chat_id):
    """Envía una promo a un chat (con foto si tiene, o texto si no).
    Fix v4.1: si la foto falla por caption >1024 (Message caption is too long),
    se envía la foto con caption corto y el texto completo con botón como 2º mensaje."""
    texto = promo.get("texto", "")
    if promo.get("boton_texto") and promo.get("boton_link"):
        from telegram import InlineKeyboardButton, InlineKeyboardMarkup
        kb = InlineKeyboardMarkup([[
            InlineKeyboardButton(promo["boton_texto"], url=promo["boton_link"])
        ]])
    else:
        kb = None

    if promo.get("foto_file_id"):
        try:
            # Foto con caption NO debe superar 1024 chars → se usa caption corto
            await context.bot.send_photo(chat_id=chat_id, photo=promo["foto_file_id"],
                                         caption=_short_caption(texto), parse_mode="HTML")
            # Texto completo + botón como segundo mensaje
            try:
                await context.bot.send_message(chat_id=chat_id, text=texto,
                                               parse_mode="HTML", reply_markup=kb)
            except Exception:
                try:
                    await context.bot.send_message(chat_id=chat_id, text=texto, reply_markup=kb)
                except Exception as e2:
                    logger.error(f"enviar_promo texto fallback error: {e2}")
            return True
        except Exception as e:
            logger.error(f"enviar_promo foto error: {e}")
    await context.bot.send_message(chat_id=chat_id, text=texto, parse_mode="HTML", reply_markup=kb)
    return True


# =============================================================================
# BUILDERS PARA PANEL (botones de admin)
# =============================================================================
def panel_bienvenida_kb():
    from telegram import InlineKeyboardButton, InlineKeyboardMarkup
    kb = [
        [InlineKeyboardButton("🖼️ Cambiar foto", callback_data="bienvenida_foto")],
        [InlineKeyboardButton("📝 Cambiar texto", callback_data="bienvenida_texto")],
        [InlineKeyboardButton("🔘 Editar botones", callback_data="bienvenida_botones")],
        [InlineKeyboardButton("👁️ Vista previa", callback_data="bienvenida_preview")],
        [InlineKeyboardButton("⬅️ Volver", callback_data="dash")],
    ]
    return InlineKeyboardMarkup(kb)


def panel_promos_kb():
    from telegram import InlineKeyboardButton, InlineKeyboardMarkup
    kb = [
        [InlineKeyboardButton("➕ Nueva promo", callback_data="promo_nueva")],
        [InlineKeyboardButton("📋 Listar promos", callback_data="promo_listar")],
        [InlineKeyboardButton("⬅️ Volver", callback_data="dash")],
    ]
    return InlineKeyboardMarkup(kb)


if __name__ == "__main__":
    init_notif_extras_db()
    print("Notif extras DB OK:", DB_PATH)