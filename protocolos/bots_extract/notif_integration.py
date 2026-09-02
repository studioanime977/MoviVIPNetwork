# -*- coding: utf-8 -*-
"""
MoviVIP Notif Bot — INTEGRADOR DE MENSAJES (se importa desde notif_bot.py)
Maneja los mensajes que el admin envía DURANTE la edición de bienvenida/promos,
y los comandos /cancelar_bienv /cancelar_promo.

NO toca los handlers .HC: retorna silenciosamente cuando no hay edición activa.
"""
import logging
from telegram import Update
from telegram.ext import ContextTypes

import notif_extras_ui as ui

logger = logging.getLogger("notif_integration")


async def handle_extras_media(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Fotos que llegan mientras se edita bienvenida (foto nueva) o promo (foto)."""
    if not update.message or not update.message.photo:
        return
    try:
        # Probar en orden: edición de bienvenida → creación de promo → edición de promo
        if ui.is_handling_bienvenida(context):
            await ui.handle_bienvenida_message(update, context)
            return
        if ui.is_handling_promo(context):
            await ui.handle_promo_message(update, context)
            if not ui.is_handling_promo(context):
                await ui.handle_promo_edit_message(update, context)
            return
    except Exception as e:
        logger.error(f"handle_extras_media error: {e}")


async def handle_extras_text(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Textos que llegan mientras se edita bienvenida (texto/link botón) o promo."""
    if not update.message or not update.message.text:
        return
    try:
        if ui.is_handling_bienvenida(context):
            if await ui.handle_bienvenida_message(update, context):
                return
            if await ui.handle_bienvenida_boton_edit_message(update, context):
                return
            return  # estaba en edición pero el texto no aplicó → no pasar al bot .HC
        if ui.is_handling_promo(context):
            if await ui.handle_promo_message(update, context):
                return
            if await ui.handle_promo_edit_message(update, context):
                return
            return
    except Exception as e:
        logger.error(f"handle_extras_text error: {e}")


async def cmd_cancelar_bienv(update: Update, context: ContextTypes.DEFAULT_TYPE):
    context.user_data.pop("bienv_edit", None)
    context.user_data.pop("editando_boton_idx", None)
    context.user_data.pop("boton_nuevo_texto", None)
    await update.message.reply_text("❌ Edición de bienvenida cancelada.")


async def cmd_cancelar_promo(update: Update, context: ContextTypes.DEFAULT_TYPE):
    context.user_data.pop("promo_edit", None)
    context.user_data.pop("promo_texto", None)
    context.user_data.pop("promo_foto", None)
    context.user_data.pop("promo_boton_texto", None)
    await update.message.reply_text("❌ Creación de promo cancelada.")