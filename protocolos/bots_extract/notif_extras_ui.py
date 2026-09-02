# -*- coding: utf-8 -*-
"""
MoviVIP Notif Bot — INTEGRADOR de extras al notif_bot.py existente.
Registra los handlers de:
  - Bienvenida editable (foto, texto, botones con emoji/link/ocultar)
  - Promos con plantilla/foto subible

Se llama desde el callback_handler del bot original:
    if data.startswith("bienvenida_") or data.startswith("promo_"):
        # delega aquí
"""
import logging
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import ContextTypes

import notif_extras

logger = logging.getLogger("notif_extras_ui")

# Estados simples (en context.user_data)
BIENVENIDA_EDITANDO = "bienv_edit"
PROMO_EDITANDO = "promo_edit"


# =============================================================================
# ENTRY: desde el panel /start
# =============================================================================
def get_panel_extra_kb():
    """Botones extra que se agregan al panel admin."""
    return [
        [InlineKeyboardButton("🎨 Bienvenida editable", callback_data="bienvenida_menu")],
        [InlineKeyboardButton("📢 Promos con foto", callback_data="promo_menu")],
    ]


# =============================================================================
# BIENVENIDA
# =============================================================================
async def show_bienvenida_menu(update: Update, context: ContextTypes.DEFAULT_TYPE):
    q = update.callback_query
    await q.answer()
    settings = notif_extras.get_welcome_settings()
    foto = "✅" if settings.get("foto_file_id") else "❌"
    # BUG 3 (fix): contar los botones que REALMENTE se muestran, usando la MISMA
    # lógica de get_welcome_buttons() (visible + texto no vacío + link). Antes se
    # contaban todos los "visible" aunque no tuvieran link/texto → "Botones visibles"
    # mal. Ahora es consistente con la vista previa real.
    _kb_filas = notif_extras.get_welcome_buttons()
    n_botones = sum(len(fila) for fila in _kb_filas)
    text = (
        "🎨 *Configuración de Bienvenida*\n"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        f"🖼️ Foto: {foto}\n"
        f"🔘 Botones visibles: {n_botones}\n\n"
        "Elige qué editar:"
    )
    kb = [
        [InlineKeyboardButton("🖼️ Enviar foto nueva", callback_data="bienvenida_foto")],
        [InlineKeyboardButton("📝 Editar texto", callback_data="bienvenida_texto")],
        [InlineKeyboardButton("🔘 Editar botones", callback_data="bienvenida_botones")],
        [InlineKeyboardButton("👁️ Ver vista previa", callback_data="bienvenida_preview")],
        [InlineKeyboardButton("⬅️ Volver", callback_data="dash")],
    ]
    try:
        await q.edit_message_text(text, parse_mode="Markdown", reply_markup=InlineKeyboardMarkup(kb))
    except Exception:
        await q.message.reply_text(text, parse_mode="Markdown", reply_markup=InlineKeyboardMarkup(kb))


async def bienvenida_set_foto(update: Update, context: ContextTypes.DEFAULT_TYPE):
    q = update.callback_query
    await q.answer()
    context.user_data[BIENVENIDA_EDITANDO] = "foto"
    await q.edit_message_text(
        "🖼️ *Enviar nueva foto de bienvenida*\n\n"
        "Envía la foto ahora. El bot la guardará como plantilla y la usará SIEMPRE en las bienvenidas.\n\n"
        "*(usa /cancelar_bienv para cancelar)*",
        parse_mode="Markdown")


async def bienvenida_set_texto(update: Update, context: ContextTypes.DEFAULT_TYPE):
    q = update.callback_query
    await q.answer()
    context.user_data[BIENVENIDA_EDITANDO] = "texto"
    await q.edit_message_text(
        "📝 *Editar texto de bienvenida*\n\n"
        "Envía el nuevo texto (HTML permitido: <b>, <i>, <code>).\n\n"
        "*(usa /cancelar_bienv para cancelar)*",
        parse_mode="Markdown")


async def bienvenida_edit_botones(update: Update, context: ContextTypes.DEFAULT_TYPE):
    q = update.callback_query
    await q.answer()
    settings = notif_extras.get_welcome_settings()
    botones = settings.get("botones", [])
    if not botones:
        text = "🔘 *No hay botones configurados.*"
        kb = [
            [InlineKeyboardButton("➕ Añadir botón", callback_data="bienvenida_boton_add")],
            [InlineKeyboardButton("⬅️ Volver", callback_data="bienvenida_menu")],
        ]
        await q.edit_message_text(text, parse_mode="Markdown", reply_markup=InlineKeyboardMarkup(kb))
        return

    text = "🔘 *Botones de bienvenida*\n\n"
    kb = []
    for i, b in enumerate(botones):
        vis = "👁️" if b.get("visible", True) else "🙈"
        emoji = b.get("emoji", "")
        txt = b.get("text", "")
        estado = "ON" if b.get("visible", True) else "OFF"
        text += f"• [{estado}] {vis} {emoji} {txt}\n"
        kb.append([
            InlineKeyboardButton(f"✏️ {emoji or '🔘'} {txt[:15]}", callback_data=f"bienv_btn_edit_{i}"),
            InlineKeyboardButton(f"{'🙈 Ocultar' if b.get('visible',True) else '👁️ Mostrar'}", callback_data=f"bienv_btn_toggle_{i}"),
        ])
    kb.append([InlineKeyboardButton("➕ Añadir botón", callback_data="bienvenida_boton_add")])
    kb.append([InlineKeyboardButton("⬅️ Volver", callback_data="bienvenida_menu")])
    await q.edit_message_text(text, parse_mode="Markdown", reply_markup=InlineKeyboardMarkup(kb))


async def bienvenida_boton_add(update: Update, context: ContextTypes.DEFAULT_TYPE):
    q = update.callback_query
    await q.answer()
    context.user_data[BIENVENIDA_EDITANDO] = "boton_nuevo_texto"
    await q.edit_message_text(
        "➕ *Añadir botón nuevo*\n\n"
        "1️⃣ *Texto del botón* (con emoji, ej: 🔑 Bot SSH):\n\n"
        "Envíalo ahora. *(usa /cancelar_bienv para cancelar)*",
        parse_mode="Markdown")


async def bienvenida_preview(update: Update, context: ContextTypes.DEFAULT_TYPE):
    q = update.callback_query
    await q.answer()
    settings = notif_extras.get_welcome_settings()
    texto = settings.get("texto") or "👑 *Bienvenido a MoviVIP Network!* 👑"
    filas = notif_extras.get_welcome_buttons()
    kb = InlineKeyboardMarkup(filas) if filas else None
    foto_id = settings.get("foto_file_id")
    try:
        if foto_id:
            await q.message.reply_photo(photo=foto_id, caption=texto, parse_mode="Markdown", reply_markup=kb)
        else:
            await q.message.reply_text(texto, parse_mode="Markdown", reply_markup=kb)
    except Exception as e:
        await q.message.reply_text(f"❌ Error preview: {e}\n\n{texto}", parse_mode="Markdown", reply_markup=kb)


# =============================================================================
# GESTIÓN DE MENSAJES DE BIENVENIDA (al recibir foto/texto del admin)
# =============================================================================
async def handle_bienvenida_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Procesa la foto o texto que el admin envía mientras edita bienvenida."""
    estado = context.user_data.get(BIENVENIDA_EDITANDO)
    if not estado:
        return False

    # Foto nueva
    if estado == "foto":
        if update.message.photo:
            file_id = update.message.photo[-1].file_id
            notif_extras.save_welcome_settings(foto_file_id=file_id)
            context.user_data.pop(BIENVENIDA_EDITANDO, None)
            await update.message.reply_text("✅ *Foto de bienvenida actualizada!*\nSe usará SIEMPRE en las bienvenidas.",
                                            parse_mode="Markdown")
            await show_bienvenida_menu(update, context)
            return True
        await update.message.reply_text("❌ Envía una foto (no otro tipo de archivo).")
        return True

    # Texto nuevo
    if estado == "texto":
        notif_extras.save_welcome_settings(texto=update.message.text)
        context.user_data.pop(BIENVENIDA_EDITANDO, None)
        await update.message.reply_text("✅ *Texto de bienvenida actualizado!*", parse_mode="Markdown")
        await show_bienvenida_menu(update, context)
        return True

    # Texto del botón nuevo
    if estado == "boton_nuevo_texto":
        context.user_data["boton_nuevo_texto"] = update.message.text
        context.user_data[BIENVENIDA_EDITANDO] = "boton_nuevo_link"
        await update.message.reply_text("2️⃣ *Link del botón* (URL, ej: https://t.me/MoviVIP):")
        return True

    if estado == "boton_nuevo_link":
        texto_btn = context.user_data.get("boton_nuevo_texto", "🔘 Botón")
        link = update.message.text.strip()
        settings = notif_extras.get_welcome_settings()
        botones = settings.get("botones", [])
        botones.append({"text": texto_btn, "emoji": "", "link": link, "visible": True})
        notif_extras.save_welcome_settings(botones=botones)
        context.user_data.pop(BIENVENIDA_EDITANDO, None)
        context.user_data.pop("boton_nuevo_texto", None)
        await update.message.reply_text("✅ *Botón añadido!*", parse_mode="Markdown")
        await bienvenida_edit_botones(update, context)
        return True

    return False


# =============================================================================
# CALLBACKS DE BOTONES (editar/ocultar)
# =============================================================================
async def handle_bienvenida_callback(update: Update, context: ContextTypes.DEFAULT_TYPE, data: str):
    q = update.callback_query
    settings = notif_extras.get_welcome_settings()
    botones = settings.get("botones", [])

    # Toggle visible
    if data.startswith("bienv_btn_toggle_"):
        i = int(data.split("_")[-1])
        if 0 <= i < len(botones):
            botones[i]["visible"] = not botones[i].get("visible", True)
            notif_extras.save_welcome_settings(botones=botones)
        await q.answer("✅ Actualizado")
        await bienvenida_edit_botones(update, context)
        return True

    # Editar botón (texto+emoji primero, luego link)
    if data.startswith("bienv_btn_edit_"):
        i = int(data.split("_")[-1])
        context.user_data["editando_boton_idx"] = i
        context.user_data[BIENVENIDA_EDITANDO] = "boton_edit_texto"
        b = botones[i] if 0 <= i < len(botones) else {}
        await q.answer()
        await q.edit_message_text(
            f"✏️ *Editar botón*\n\nActual: {b.get('emoji','')} {b.get('text','')}\n"
            f"Link: {b.get('link','')}\n\n"
            f"Envía el *nuevo texto con emoji* (ej: 🔑 Bot SSH),\n"
            f"o *0* para dejar igual:",
            parse_mode="Markdown")
        return True

    if data.startswith("bienv_btn_link_"):
        i = int(data.split("_")[-1])
        context.user_data["editando_boton_idx"] = i
        context.user_data[BIENVENIDA_EDITANDO] = "boton_edit_link"
        await q.answer()
        await q.edit_message_text(
            f"✏️ *Editar link del botón*\n\nEnvía el nuevo link,\n"
            f"o *0* para dejar igual:",
            parse_mode="Markdown")
        return True

    return False


async def handle_bienvenida_boton_edit_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Procesa texto del admin al editar un botón existente."""
    estado = context.user_data.get(BIENVENIDA_EDITANDO)
    if estado not in ("boton_edit_texto", "boton_edit_link"):
        return False

    idx = context.user_data.get("editando_boton_idx")
    settings = notif_extras.get_welcome_settings()
    botones = settings.get("botones", [])
    if idx is None or not (0 <= idx < len(botones)):
        context.user_data.pop(BIENVENIDA_EDITANDO, None)
        return False

    nuevo_valor = update.message.text.strip()
    b = botones[idx]
    if estado == "boton_edit_texto":
        if nuevo_valor != "0":
            b["text"] = nuevo_valor
        context.user_data[BIENVENIDA_EDITANDO] = "boton_edit_link"
        await update.message.reply_text(
            f"Link actual: {b.get('link','')}\n\n"
            f"Envía el *nuevo link*, o *0* para dejarlo igual:")
        notif_extras.save_welcome_settings(botones=botones)
        return True

    if estado == "boton_edit_link":
        if nuevo_valor != "0":
            b["link"] = nuevo_valor
        notif_extras.save_welcome_settings(botones=botones)
        context.user_data.pop(BIENVENIDA_EDITANDO, None)
        context.user_data.pop("editando_boton_idx", None)
        await update.message.reply_text("✅ *Botón actualizado!*", parse_mode="Markdown")
        await bienvenida_edit_botones(update, context)
        return True

    return False


# =============================================================================
# PROMOS
# =============================================================================
async def show_promo_menu(update: Update, context: ContextTypes.DEFAULT_TYPE):
    q = update.callback_query
    await q.answer()
    promos = notif_extras.get_promos()
    text = "📢 *Promociones*\n"
    text += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
    if promos:
        for p in promos[:10]:
            activa = "🟢" if p["activa"] else "🔴"
            foto = "🖼️" if p.get("foto_file_id") else "📝"
            text += f"{activa} {foto} `{p['id']}` — {p['titulo'] or 'sin título'}\n"
    else:
        text += "No hay promos aún.\n"
    kb = [
        [InlineKeyboardButton("➕ Nueva promo", callback_data="promo_nueva")],
        [InlineKeyboardButton("📋 Gestionar (editar/enviar)", callback_data="promo_listar")],
        [InlineKeyboardButton("⬅️ Volver", callback_data="dash")],
    ]
    await q.edit_message_text(text, parse_mode="Markdown", reply_markup=InlineKeyboardMarkup(kb))


async def promo_nueva(update: Update, context: ContextTypes.DEFAULT_TYPE):
    q = update.callback_query
    await q.answer()
    context.user_data[PROMO_EDITANDO] = "nueva_texto"
    await q.edit_message_text(
        "➕ *Nueva promo*\n\n"
        "1️⃣ *Texto de la promo* (con HTML si quieres):\n\n"
        "Envíalo ahora. *(usa /cancelar_promo para cancelar)*",
        parse_mode="Markdown")


async def handle_promo_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Procesa mensajes del admin mientras crea una promo."""
    estado = context.user_data.get(PROMO_EDITANDO)
    if not estado:
        return False

    if estado == "nueva_texto":
        context.user_data["promo_texto"] = update.message.text
        context.user_data[PROMO_EDITANDO] = "nueva_foto"
        await update.message.reply_text(
            "2️⃣ *Foto/plantilla de la promo*\n\n"
            "Envía la foto (o escribe *0* para promo solo texto):")
        return True

    if estado == "nueva_foto":
        promo_texto = context.user_data.get("promo_texto", "")
        foto_id = ""
        if update.message.photo:
            foto_id = update.message.photo[-1].file_id
        elif update.message.text and update.message.text.strip() == "0":
            foto_id = ""
        else:
            await update.message.reply_text("❌ Envía una foto, o *0* para texto solo.")
            return True

        context.user_data["promo_foto"] = foto_id
        context.user_data[PROMO_EDITANDO] = "nueva_boton_texto"
        await update.message.reply_text(
            "3️⃣ *Texto del botón* (opcional, ej: 🛒 Comprar)\n"
            "Escribe *0* para sin botón:")
        return True

    if estado == "nueva_boton_texto":
        boton_texto = update.message.text.strip()
        if boton_texto == "0":
            boton_texto = ""
        context.user_data["promo_boton_texto"] = boton_texto
        if boton_texto:
            context.user_data[PROMO_EDITANDO] = "nueva_boton_link"
            await update.message.reply_text("4️⃣ *Link del botón* (URL):")
        else:
            # Guardar promo
            pid = notif_extras.add_promo(
                titulo="promo",
                texto=context.user_data.get("promo_texto", ""),
                foto_file_id=context.user_data.get("promo_foto", ""),
                boton_texto="",
                boton_link="")
            context.user_data.pop(PROMO_EDITANDO, None)
            await update.message.reply_text(f"✅ *Promo {pid} creada!*", parse_mode="Markdown")
            await show_promo_menu(update, context)
        return True

    if estado == "nueva_boton_link":
        boton_link = update.message.text.strip()
        pid = notif_extras.add_promo(
            titulo="promo",
            texto=context.user_data.get("promo_texto", ""),
            foto_file_id=context.user_data.get("promo_foto", ""),
            boton_texto=context.user_data.get("promo_boton_texto", ""),
            boton_link=boton_link)
        context.user_data.pop(PROMO_EDITANDO, None)
        await update.message.reply_text(f"✅ *Promo {pid} creada!*", parse_mode="Markdown")
        await show_promo_menu(update, context)
        return True

    return False


async def promo_listar(update: Update, context: ContextTypes.DEFAULT_TYPE):
    q = update.callback_query
    await q.answer()
    promos = notif_extras.get_promos()
    if not promos:
        await q.edit_message_text("📭 No hay promos.",
                                  reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("⬅️ Volver", callback_data="dash")]]))
        return
    kb = []
    for p in promos[:10]:
        kb.append([InlineKeyboardButton(
            f"{'🟢' if p['activa'] else '🔴'} #{p['id']} {p['titulo']}",
            callback_data=f"promo_sel_{p['id']}")])
    kb.append([InlineKeyboardButton("⬅️ Volver", callback_data="promo_menu")])
    await q.edit_message_text("📋 *Gestionar promos*\nElige una:", parse_mode="Markdown",
                              reply_markup=InlineKeyboardMarkup(kb))


async def promo_sel(update: Update, context: ContextTypes.DEFAULT_TYPE, pid: int):
    q = update.callback_query
    p = notif_extras.get_promo(pid)
    if not p:
        await q.answer("No existe")
        return
    estado = "🟢 Activa" if p["activa"] else "🔴 Inactiva"
    text = (
        f"📢 <b>Promo #{pid}</b>\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        f"{estado}\n"
        f"🖼️ Foto: {'✅' if p['foto_file_id'] else '❌'}\n"
        f"🔘 Botón: {p['boton_texto'] or '—'}\n\n"
        f"{p['texto'][:300]}"
    )
    kb = [
        [InlineKeyboardButton("📤 Enviar ahora", callback_data=f"promo_enviar_{pid}")],
        [InlineKeyboardButton("🖼️ Cambiar foto", callback_data=f"promo_foto_{pid}")],
        [InlineKeyboardButton("🔘 Editar botón", callback_data=f"promo_boton_{pid}")],
        [InlineKeyboardButton(f"{'🔴 Desactivar' if p['activa'] else '🟢 Activar'}", callback_data=f"promo_toggle_{pid}")],
        [InlineKeyboardButton("🗑️ Borrar", callback_data=f"promo_del_{pid}")],
        [InlineKeyboardButton("⬅️ Volver", callback_data="promo_listar")],
    ]
    try:
        await q.edit_message_text(text, parse_mode="HTML", reply_markup=InlineKeyboardMarkup(kb))
    except Exception:
        await q.message.reply_text(text, parse_mode="HTML", reply_markup=InlineKeyboardMarkup(kb))


async def promo_enviar(update: Update, context: ContextTypes.DEFAULT_TYPE, pid: int):
    q = update.callback_query
    p = notif_extras.get_promo(pid)
    if not p:
        await q.answer("No existe")
        return
    await q.answer("Enviando...")
    # Enviar al canal y grupo
    ok = 0
    fail = 0
    for chat_id in context.bot_data.get("notif_targets", []):
        try:
            await notif_extras.enviar_promo(context, p, chat_id)
            ok += 1
        except Exception as e:
            fail += 1
            logger.error(f"promo enviar {chat_id}: {e}")
    await q.message.reply_text(f"✅ Promo enviada: {ok} ok, {fail} fallidos.")


async def promo_foto(update: Update, context: ContextTypes.DEFAULT_TYPE, pid: int):
    q = update.callback_query
    await q.answer()
    context.user_data[PROMO_EDITANDO] = f"cambiar_foto_{pid}"
    await q.edit_message_text(f"🖼️ Envía la foto nueva para la promo #{pid}:\n(/cancelar_promo para cancelar)")


async def promo_boton(update: Update, context: ContextTypes.DEFAULT_TYPE, pid: int):
    q = update.callback_query
    await q.answer()
    context.user_data[PROMO_EDITANDO] = f"cambiar_boton_{pid}"
    await q.edit_message_text(f"🔘 Envía el texto del botón (o *0* para quitarlo):\n(/cancelar_promo para cancelar)",
                              parse_mode="Markdown")


async def handle_promo_edit_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Procesa mensajes del admin al editar promo existente."""
    estado = context.user_data.get(PROMO_EDITANDO) or ""
    if not estado.startswith("cambiar_"):
        return False
    pid = int(estado.split("_")[-1])

    if estado.startswith("cambiar_foto_"):
        if update.message.photo:
            notif_extras.update_promo(pid, foto_file_id=update.message.photo[-1].file_id)
            context.user_data.pop(PROMO_EDITANDO, None)
            await update.message.reply_text(f"✅ Foto promo #{pid} actualizada!")
            await promo_sel(update, context, pid)
            return True
        await update.message.reply_text("❌ Envía una foto.")
        return True

    if estado.startswith("cambiar_boton_"):
        txt = update.message.text.strip()
        if txt == "0":
            notif_extras.update_promo(pid, boton_texto="", boton_link="")
            context.user_data.pop(PROMO_EDITANDO, None)
            await update.message.reply_text(f"✅ Botón de promo #{pid} quitado.")
            await promo_sel(update, context, pid)
            return True
        context.user_data["promo_boton_edit_texto"] = txt
        context.user_data[PROMO_EDITANDO] = f"cambiar_boton_link_{pid}"
        await update.message.reply_text(f"Ahora el *link* del botón:")
        return True

    if estado.startswith("cambiar_boton_link_"):
        link = update.message.text.strip()
        texto_btn = context.user_data.get("promo_boton_edit_texto", "")
        notif_extras.update_promo(pid, boton_texto=texto_btn, boton_link=link)
        context.user_data.pop(PROMO_EDITANDO, None)
        context.user_data.pop("promo_boton_edit_texto", None)
        await update.message.reply_text(f"✅ Botón de promo #{pid} actualizado.")
        await promo_sel(update, context, pid)
        return True

    return False


async def handle_promo_callback(update: Update, context: ContextTypes.DEFAULT_TYPE, data: str):
    if data == "promo_nueva":
        await promo_nueva(update, context)
        return True
    if data == "promo_listar":
        await promo_listar(update, context)
        return True
    if data.startswith("promo_sel_"):
        await promo_sel(update, context, int(data.split("_")[-1]))
        return True
    if data.startswith("promo_enviar_"):
        await promo_enviar(update, context, int(data.split("_")[-1]))
        return True
    if data.startswith("promo_foto_"):
        await promo_foto(update, context, int(data.split("_")[-1]))
        return True
    if data.startswith("promo_boton_"):
        await promo_boton(update, context, int(data.split("_")[-1]))
        return True
    if data.startswith("promo_toggle_"):
        pid = int(data.split("_")[-1])
        p = notif_extras.get_promo(pid)
        if p:
            notif_extras.update_promo(pid, activa=0 if p["activa"] else 1)
        await promo_sel(update, context, pid)
        return True
    if data.startswith("promo_del_"):
        pid = int(data.split("_")[-1])
        notif_extras.delete_promo(pid)
        await promo_listar(update, context)
        return True
    return False


# =============================================================================
# ROUTER PRINCIPAL (se llama desde callback_handler del bot original)
# =============================================================================
async def route(update: Update, context: ContextTypes.DEFAULT_TYPE, data: str) -> bool:
    """Devuelve True si manejó el callback."""
    if data == "bienvenida_menu":
        await show_bienvenida_menu(update, context)
        return True
    if data == "bienvenida_foto":
        await bienvenida_set_foto(update, context)
        return True
    if data == "bienvenida_texto":
        await bienvenida_set_texto(update, context)
        return True
    if data == "bienvenida_botones":
        await bienvenida_edit_botones(update, context)
        return True
    if data == "bienvenida_boton_add":
        await bienvenida_boton_add(update, context)
        return True
    if data == "bienvenida_preview":
        await bienvenida_preview(update, context)
        return True
    if data.startswith(("bienv_btn_", "bienv_btn_link_")):
        return await handle_bienvenida_callback(update, context, data)
    if data.startswith("promo_"):
        return await handle_promo_callback(update, context, data)
    return False


def is_handling_bienvenida(context) -> bool:
    return bool(context.user_data.get(BIENVENIDA_EDITANDO))


def is_handling_promo(context) -> bool:
    return bool(context.user_data.get(PROMO_EDITANDO))