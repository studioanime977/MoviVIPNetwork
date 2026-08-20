# -*- coding: utf-8 -*-
"""{BRAND_NAME} Admin Bot v5 â€” Full operator integration with connection types + V2Ray support
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
 K_CREATE_HWID, K_ZIPVPN_INPUT, K_XRAY_INPUT,
 K_XRAY_ADD_INPUT, K_XRAY_ADD_MENU, K_ZIPVPN_ADD_MENU,
 K_SSH_DETAIL, K_SSH_RENEW, K_SSH_EDIT_LIMIT) = range(27)

# =============================================================================
# OPERATOR CONFIGS â€” Full integration (matches user_bot.py OPERATORS)
# =============================================================================
OPERATORS = {
    # â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    # COLOMBIA OPERATORS (payload/SNI ocultos al usuario)
    # â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    "movistar": {
        "name": "Movistar", "icon": "ðŸ“±", "flag": "ðŸ‡¨ðŸ‡´",
        "desc": "SSH / V2Ray", "country": "co",
        "connection_types": [
            {"key": "ssh_sni", "label": "ðŸ”’ SSH + SNI", "port": 443, "protocol": "ssh+ssl",
             "snis": ["m.nequi.co", "epayco.co"], "ssh_field": f"{VPS_SUBDOMAIN}:443"},
            {"key": "ssh_payload", "label": "ðŸ“¦ SSH + Payload", "port": 80, "protocol": "ssh+payload",
             "ssh_field": f"{VPS_SUBDOMAIN}:80",
             "payload": "HTTP/2.0 200[crlf]Host:[random=chaparrita.colochita.org;about.meituan.com;tv.kankan.com;store.steampowered.com;map.baidu.com;list.tmall.com;yandex.com;qzone.qq.com;v.qq.com;y.qq.com;www.bb.com.br;ok.ru;www.dropbox.com;www.epicgames.com;youku.com;sll.zc.qq.com;www.tiktok.com;tidal.com;www.funk.com;gsuite.google.com;www.voxer.com]\\n200 Connection established\\nProxy-Connection: close\\nConnection-Keep-true\\nControl-Cache: no-cache\\nContent-Length: 9999999999999999999\\nUser-Agent: Yes \\nContent-Encoding: 88888888\\nContent-Language: 00000000\\nContent-Length: 55555555\\nContent-Location:33333333[crlf]"},
            {"key": "v2ray", "label": "âš¡ V2Ray (VMess/VLESS/Trojan)", "port": 443, "protocol": "v2ray",
             "v2ray_host": "m.nequi.co"},
        ],
        "ports": [443],
        "ssh_field": f"{VPS_SUBDOMAIN}:443",
        "protocol": "ssh+ssl",
        "snis": ["m.nequi.co", "epayco.co"],
    },
    "tigo": {
        "name": "Tigo", "icon": "ðŸ“¡", "flag": "ðŸ‡¨ðŸ‡´",
        "desc": "SSH / V2Ray", "country": "co",
        "connection_types": [
            {"key": "ssh_sni_normal", "label": "ðŸ”’ SSH Normal + SNI (Puerto 7300)", "port": 7300, "protocol": "ssh+ssl",
              "ssh_field": f"{VPS_SUBDOMAIN}:1-7300", "snis": [VPS_SUBDOMAIN]},
            {"key": "ssh_sni_gaming", "label": "ðŸŽ® SSH Gaming + SNI (Puerto 9900)", "port": 9900, "protocol": "ssh+ssl",
              "ssh_field": f"{VPS_SUBDOMAIN}:1-9900", "snis": [VPS_SUBDOMAIN]},
            {"key": "ssh_payload", "label": "ðŸ“¦ SSH + Payload (Puerto 80)", "port": 80, "protocol": "ssh+payload",
             "ssh_field": f"{VPS_SUBDOMAIN}:80",
             "payload": f"GET / HTTP/1.1[crlf]Host:sdk.iad-03.braze.com[crlf][crlf]CF-RAY / HTTP/1.1[crlf]Host: {CLOUDFLARE_DOMAIN}[crlf]Upgrade: websocket[crlf]Connection: Keep-Alive[crlf]User-Agent: [ua][crlf]Upgrade: websocket[crlf][crlf]"},
            {"key": "v2ray", "label": "âš¡ V2Ray (VMess/VLESS/Trojan)", "port": 443, "protocol": "v2ray",
             "v2ray_host": CLOUDFLARE_DOMAIN},
        ],
        "ports": [7300, 9900, 80, 443],
        "ssh_field_gaming": f"{VPS_SUBDOMAIN}:1-9900",
        "ssh_field_normal": f"{VPS_SUBDOMAIN}:1-7300",
        "protocol": "ssh+ssl",
        "snis": [VPS_SUBDOMAIN],
    },
    "claro": {
        "name": "Claro", "icon": "ðŸ”´", "flag": "ðŸ‡¨ðŸ‡´",
        "desc": "HTTP / Payload", "country": "co",
        "connection_types": [
            {"key": "ssh_payload_1", "label": "ðŸ“¦ SSH+PAYLOAD 1", "port": 80, "protocol": "ssh+payload",
             "ssh_field": "redmas.com.co:80",
             "payload": "PUT / HTTP/1.1[crlf]Host: redmas.com.co[crlf]Content-Length: 0[crlf]Connection: keep-alive[crlf][crlf][split]GET /keving1 HTTP/1.1[crlf]Host: dhn9bf23fb9nc.cloudfront.net[crlf]Origin: https://redmas.com.co[crlf]Connection: Upgrade[crlf]Upgrade: websocket[crlf][crlf]"},
            {"key": "ssh_payload_2", "label": "ðŸ“¦ SSH+PAYLOAD 2", "port": 80, "protocol": "ssh+payload",
             "ssh_field": "redmas.com.co:80",
             "payload": "PUT / HTTP/1.1[crlf]Host: redmas.com.co[crlf]Content-Length: 0[crlf]Connection: keep-alive[crlf][crlf][split]GET / HTTP/1.1[crlf]Host: d1ep95smqw703x.cloudfront.net[crlf]Origin: https://redmas.com.co[crlf]Connection: Upgrade[crlf]Upgrade: websocket[crlf][crlf]"},
            {"key": "ssh_payload_3", "label": "ðŸ“¦ SSH+PAYLOAD 3", "port": 80, "protocol": "ssh+payload",
             "ssh_field": "redmas.com.co:80",
             "payload": "PUT / HTTP/1.1[crlf]Host: redmas.com.co[crlf]Content-Length: 0[crlf]Connection: keep-alive[crlf][crlf][split]GET / HTTP/1.1[crlf]Host: d3cdy6viklzpq1.cloudfront.net[crlf]Origin: https://redmas.com.co[crlf]Connection: Upgrade[crlf]Upgrade: websocket[crlf][crlf]"},
        ],
        "ports": [80],
        "ssh_field": "redmas.com.co:80",
        "protocol": "ssh+payload",
        "payload": "PUT / HTTP/1.1[crlf]Host: redmas.com.co[crlf]Content-Length: 0[crlf]Connection: keep-alive[crlf][crlf][split]GET /keving1 HTTP/1.1[crlf]Host: dhn9bf23fb9nc.cloudfront.net[crlf]Origin: https://redmas.com.co[crlf]Connection: Upgrade[crlf]Upgrade: websocket[crlf][crlf]",
    },
    "wom": {
        "name": "WOM", "icon": "ðŸŸ£", "flag": "ðŸ‡¨ðŸ‡´",
        "desc": "HTTP / WebSocket", "country": "co",
        "connection_types": [
            {"key": "ssh_payload", "label": "ðŸ“¦ SSH + Payload", "port": 80, "protocol": "ssh+payload",
             "ssh_field": "atlaq.com:80",
             "payload": f"GET / HTTP/1.1[crlf]Host: {CLOUDFLARE_DOMAIN}[crlf]Connection: Upgrade[crlf]Upgrade: websocket[crlf][crlf]"},
        ],
        "ports": [80],
        "ssh_field": "atlaq.com:80",
        "protocol": "ssh+payload",
        "payload": f"GET / HTTP/1.1[crlf]Host: {CLOUDFLARE_DOMAIN}[crlf]Connection: Upgrade[crlf]Upgrade: websocket[crlf][crlf]",
    },
    "virgin": {
        "name": "Virgin", "icon": "ðŸ“¶", "flag": "ðŸ‡¨ðŸ‡´",
        "desc": "V2Ray Puerto 80/8080", "country": "co",
        "connection_types": [
            {"key": "v2ray_80", "label": "âš¡ V2Ray VMess WS (Puerto 80)", "port": 80, "protocol": "v2ray",
             "v2ray_server": VPS_SUBDOMAIN, "v2ray_port": 80,
             "v2ray_host": "activate.virginmobile.sa", "v2ray_path": "/EkV578gv/"},
            {"key": "v2ray_8080", "label": "âš¡ V2Ray VMess WS (Puerto 8080)", "port": 8080, "protocol": "v2ray",
             "v2ray_server": VPS_SUBDOMAIN, "v2ray_port": 8080,
             "v2ray_host": "activate.virginmobile.sa", "v2ray_path": "/EkV578gv/"},
        ],
        "ports": [80, 8080],
        "protocol": "v2ray",
    },
    # â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    # ARGENTINA â€” SSH + Payload (HTTP Injector)
    # â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    "claro_ar": {
        "name": "Claro", "icon": "ðŸ”´", "flag": "ðŸ‡¦ðŸ‡·",
        "desc": "SSH / Payload", "country": "ar",
        "connection_types": [
            {"key": "ssh_payload_rexo", "label": "ðŸ“¦ Payload â€” rexo.personal.com.ar", "port": 80, "protocol": "ssh+payload",
             "ssh_field": "rexo.personal.com.ar:80",
             "payload": "GET / HTTP/1.3[crlf]Host: rexo.personal.com.ar[crlf][crlf][split][crlf][split]GETT / HTTP/1.1[crlf]Host: ssh.ethiodragon.sbs[crlf]Connection: Keep-Alive[crlf]Upgrade: websocket[crlf][crlf]"},
            {"key": "ssh_payload_recargas", "label": "ðŸ“¦ Payload â€” recargas.personal.com.ar", "port": 80, "protocol": "ssh+payload",
             "ssh_field": "recargas.personal.com.ar:80",
             "payload": "PUT / HTTP/1.1[crlf]Host: recargas.personal.com.ar[crlf]Content-Length:0[crlf]Connection: keep-alive[crlf][crlf][split]GET / HTTP/1.1[crlf]Host: dsjoq17p4x2nh.cloudfront.net[crlf]Connection: Upgrade[crlf]Upgrade: websocket[crlf][crlf]"},
            {"key": "ssh_payload_agresources", "label": "ðŸ“¦ Payload â€” agresources.personal.com.ar", "port": 80, "protocol": "ssh+payload",
             "ssh_field": "agresources.personal.com.ar:80",
             "payload": "GET / HTTP/1.1[crlf]Host: agresources.personal.com.ar[crlf]Connection: Upgrade[crlf]Upgrade: websocket[crlf][crlf]"},
            {"key": "ssh_payload_acl", "label": "ðŸ“¦ Payload ACL â€” CloudFront", "port": 80, "protocol": "ssh+payload",
             "ssh_field": "rexo.personal.com.ar:80",
             "payload": "ACL / HTTP/1.3[crlf]Host: rexo.personal.com.ar[crlf][crlf][split][crlf][split]X / HTTP/1.2[crlf]Host: rexo.personal.com.ar[crlf][crlf]GET / HTTP/1.1[crlf]Host: dsjoq17p4x2nh.cloudfront.net[crlf]Upgrade: websocket[crlf]Connection: Upgrade[crlf][crlf]"},
            {"key": "ssh_payload_head", "label": "ðŸ“¦ Payload HEAD â€” CloudFront", "port": 80, "protocol": "ssh+payload",
             "ssh_field": "recargas.personal.com.ar:80",
             "payload": "HEAD / HTTP/1.1[crlf]Host: recargas.personal.com.ar[crlf][crlf][split][crlf][crlf]GET- / HTTP/1.1[crlf]Host: recargas.personal.com.ar[crlf][crlf]GET / HTTP/1.1[crlf]Host: d21lf41zo8xgdz.cloudfront.net[crlf]Connection: Upgrade[crlf]Upgrade: websocket[crlf]User-Agent: Googlebot/2.1 (+http://www.google.com/bot.html)[crlf][crlf][split]"},
            {"key": "ssh_payload_head_rotate", "label": "ðŸ“¦ Payload HEAD Rotate", "port": 80, "protocol": "ssh+payload",
             "ssh_field": "agresources.personal.com.ar:80",
             "payload": "HEAD / HTTP/1.1[crlf]Host: agresources.personal.com.ar[crlf][crlf][split][crlf][crlf]GET- / HTTP/1.1[crlf]Host: agresources.personal.com.ar[crlf][crlf]GET /speedfree HTTP/1.1[crlf]Host: d21s96hnt304wx.cloudfront.net[crlf]Connection: Upgrade[crlf]Upgrade: websocket[crlf]User-Agent: Googlebot/2.1 (+http://www.google.com/bot.html)[crlf][crlf][split]"},
            {"key": "ssh_payload_copy", "label": "ðŸ“¦ Payload COPY â€” CloudFront", "port": 80, "protocol": "ssh+payload",
             "ssh_field": "rexo.personal.com.ar:80",
             "payload": "COPY / HTTP/1.3[crlf]Host: rexo.personal.com.ar[crlf][crlf][split][crlf][split]X / HTTP/1.2[crlf]Host: rexo.personal.com.ar[crlf][crlf]GET / HTTP/1.1[crlf]Host: dhn9bf23fb9nc.cloudfront.net[crlf]Upgrade: websocket[crlf]Connection: Upgrade[crlf][crlf]"},
        ],
        "ports": [80],
        "ssh_field": "rexo.personal.com.ar:80",
        "protocol": "ssh+payload",
    },
    # â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    # PERU â€” SSH + SSL / Payload + HTTP Tweak
    # â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    "bintel": {
        "name": "Bitel", "icon": "ðŸ“¶", "flag": "ðŸ‡µðŸ‡ª",
        "desc": "SSH SSL / HTTP Tweak", "country": "pe",
        "connection_types": [
            {"key": "ssh_sni", "label": "ðŸ”’ SSH + SNI (Bitel Bintel)", "port": 443, "protocol": "ssh+ssl",
             "snis": ["wap.bitel.pe"], "ssh_field": f"{VPS_SUBDOMAIN}:443"},
        ],
        "ports": [443],
        "ssh_field": f"{VPS_SUBDOMAIN}:443",
        "protocol": "ssh+ssl",
        "snis": ["wap.bitel.pe"],
    },
    "entel": {
        "name": "Entel", "icon": "ðŸŸ¢", "flag": "ðŸ‡µðŸ‡ª",
        "desc": "SSH Payload / HTTP Tweak", "country": "pe",
        "connection_types": [
            {"key": "ssh_payload", "label": "ðŸ“¦ SSH + Payload (Entel)", "port": 80, "protocol": "ssh+payload",
             "ssh_field": f"{VPS_SUBDOMAIN}:80",
             "payload": "ACL / [split]HTTP/1.1 [lf]Host: [host][crlf]Connection:[lf]Upgrade: Websocket[crlf][crlf]"},
        ],
        "ports": [80],
        "ssh_field": f"{VPS_SUBDOMAIN}:80",
        "protocol": "ssh+payload",
        "payload": "ACL / [split]HTTP/1.1 [lf]Host: [host][crlf]Connection:[lf]Upgrade: Websocket[crlf][crlf]",
    },
    # â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    # EL SALVADOR â€” SSH + Payload + SlowDNS
    # â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    "claro_sv": {
        "name": "Claro", "icon": "ðŸ”´", "flag": "ðŸ‡¸ðŸ‡»",
        "desc": "SSH / Payload / SlowDNS", "country": "sv",
        "connection_types": [
            {"key": "ssh_payload_true", "label": "ðŸ“¦ Payload â€” pay.true.org", "port": 80, "protocol": "ssh+payload",
             "ssh_field": "pay.true.org:443",
             "payload": "PUT / HTTP/1.1[crlf]Host: pay.true.org[crlf]Expect: 300-continue[lf][lf][split][lf][lf]GET / HTTP/1.1[lf]Host: flarenew.ultranet.space[lf]Expect: 300-continue[lf]Connection: Upgrade[lf]Upgrade: websocket[lf]User-Agent: Googlebot/2.1 (+http://www.google.com/bot.html)[lf][lf]"},
            {"key": "ssh_payload_flarenew", "label": "ðŸ“¦ Payload â€” flarenew.ultranet.space", "port": 80, "protocol": "ssh+payload",
             "ssh_field": "flarenew.ultranet.space:443",
             "payload": "GET / HTTP/1.1[lf]Host: flarenew.ultranet.space[lf]Connection: Upgrade[lf]Upgrade: websocket[lf]Response: 200 OK[lf]Content-Length: 300000000[lf]X-Powered-By: Sh401[lf][lf]"},
            {"key": "slowdns", "label": "ðŸ”Œ SlowDNS â€” dnsnew.ultranet.space", "port": 5300, "protocol": "slowdns",
             "ssh_field": "dnsnew.ultranet.space:5300@lusbin:7777",
             "slowdns_nameserver": "dnsnew.ultranet.space",
             "slowdns_key": "9dbbfb7374360504a22e71b8ffda2c9c3c8ee62283d171fef9d881bd6b51b605",
             "slowdns_server": "8.8.8.8"},
        ],
        "ports": [80, 5300],
        "ssh_field": "pay.true.org:443",
        "protocol": "ssh+payload",
    },
    # â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    # INDIA â€” SSH + Payload (WebSocket Upgrade)
    # â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    "airtel": {
        "name": "Airtel", "icon": "ðŸŸ¡", "flag": "ðŸ‡®ðŸ‡³",
        "desc": "SSH + Payload (WebSocket Upgrade)", "country": "in",
        "connection_types": [
            {"key": "ssh_payload_ws1", "label": "ðŸ“¦ SSH + WebSocket Upgrade", "port": 80, "protocol": "ssh+payload",
             "ssh_field": f"{VPS_SUBDOMAIN}:80",
             "payload": "GET / HTTP/1.1[crlf]Host: [host][crlf]Connection: Upgrade[crlf]Upgrade: w[lf]ebsocket[crlf][crlf]"},
            {"key": "ssh_sni", "label": "ðŸ”’ SSH + SNI (SSL)", "port": 443, "protocol": "ssh+ssl",
             "snis": [VPS_SUBDOMAIN], "ssh_field": f"{VPS_SUBDOMAIN}:443"},
        ],
        "ports": [80, 443],
        "ssh_field": f"{VPS_SUBDOMAIN}:80",
        "protocol": "ssh+payload",
        "payload": "GET / HTTP/1.1[crlf]Host: [host][crlf]Connection: Upgrade[crlf]Upgrade: w[lf]ebsocket[crlf][crlf]",
    },
}


# =============================================================================
# PLAN LIMITS - PREMIUM (inyectado por generador - NO EDITAR)
# =============================================================================
def _apply_plan_limits():
    global OPERATORS, MAX_DEVICES
    MAX_DEVICES = 5
    if True:
        # Plan con V2Ray habilitado
        pass
    else:
        # Plan sin V2Ray: filtrar connection_types v2ray de todos los operadores
        for _op in OPERATORS.values():
            _op["connection_types"] = [ct for ct in _op.get("connection_types", []) if ct.get("protocol") != "v2ray"]
        OPERATORS = {k: v for k, v in OPERATORS.items() if v.get("connection_types")}
_apply_plan_limits()

# =============================================================================
# V2RAY LINK GENERATORS
# =============================================================================
def _get_xray_uuid(username):
    """Generate deterministic UUID for a user (uuid5-based)."""
    return str(uuid_mod.uuid5(uuid_mod.NAMESPACE_URL, f"{MY_BRAND}-{username}"))

def generate_vmess_link(uuid_val, domain, port=443, path="/vmess", remark=BRAND_NAME, host=None, sni=None):
    """Generate vmess:// share link."""
    config = {
        "v": "2", "ps": remark, "add": domain, "port": str(port),
        "id": uuid_val, "aid": "0", "net": "ws", "type": "none",
        "host": host or domain, "path": path, "tls": "tls",
        "sni": sni or domain, "scy": "auto", "alpn": ""
    }
    return "vmess://" + base64.b64encode(json.dumps(config, separators=(",", ":")).encode()).decode()

def generate_vless_link(uuid_val, domain, port=443, path="/vless", remark=BRAND_NAME, sni=None, host=None):
    """Generate vless:// share link."""
    params = (f"?type=ws&security=tls&sni={sni or domain}&path={path}"
              f"&host={host or domain}&encryption=none&flow=")
    return f"vless://{uuid_val}@{domain}:{port}{params}#{remark}"

def generate_trojan_link(password, domain, port=443, path="/trojan-ws", remark=BRAND_NAME, sni=None, host=None):
    """Generate trojan:// share link."""
    params = (f"?type=ws&security=tls&sni={sni or domain}&path={path}"
              f"&host={host or domain}")
    return f"trojan://{password}@{domain}:{port}{params}#{remark}"

def generate_vless_reality_link(uuid_val, domain, port=9443, remark=BRAND_NAME):
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
# FORMAT USER CONFIG â€” Full V2Ray + SSH support
# =============================================================================
def format_user_config(username, password, operator_code, days, profiles, expires, conn_type=None, hwid=None):
    """Format complete user config for display â€” cuenta SSH directa del VPS.
    Nota: los datos de operador (payloads/SNIs) se eliminaron del repo publico.
    El bot entrega la plantilla generica con los datos del VPS (plantilla-entrega-bot.txt)."""
    text = (
        f"â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—\n"
        f"â•‘  ðŸŒ {BRAND_NAME} NETWORK       â•‘\n"
        f"â•‘  Config SSH                 â•‘\n"
        f"â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•\n\n"
        f"ðŸ‘¤ <b>USUARIO:</b> <code>{username}</code>\n"
        f"ðŸ”‘ <b>PASS:</b> <code>{password}</code>\n"
    )
    if hwid:
        text += f"ðŸ“± <b>HWID:</b> <code>{hwid}</code>\n"
    text += (
        f"ðŸ“… <b>Expira:</b> {expires}\n"
        f"ðŸ“± <b>Perfiles:</b> {profiles}\n"
        f"â° <b>DÃ­as:</b> {days}\n\n"
        f"{'â”' * 28}\n\n"
        f"ðŸ–¥ <b>Servidor:</b> <code>{VPS_SUBDOMAIN}</code>\n"
        f"ðŸ“¡ <b>SSH Field:</b> <code>{VPS_SUBDOMAIN}@{username}:{password}</code>\n\n"
        f"ðŸ‘† <i>Copia los campos para usar en tu app VPN</i>"
    )

    return text

# =============================================================================
# BRANDING
# =============================================================================
def brand_header():
    return (
        "ðŸŒ <b>â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•</b>\n"
        "   <b>{BRAND_NAME} NETWORK</b>\n"
        "   Panel de Proveedor\n"
        "ðŸŒ <b>â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•</b>"
    )

def brand_divider():
    return "â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€"

# =============================================================================
# TECLADOS
# =============================================================================
COUNTRY_FLAGS = {'co': 'ðŸ‡¨ðŸ‡´', 'pe': 'ðŸ‡µðŸ‡ª', 'ar': 'ðŸ‡¦ðŸ‡·', 'sv': 'ðŸ‡¸ðŸ‡»', 'in': 'ðŸ‡®ðŸ‡³'}

def kb_main(role, brand):
    return InlineKeyboardMarkup([
        [InlineKeyboardButton("ðŸ‘¥ USUARIOS {BRAND_NAME}", callback_data="k_users")],
        [InlineKeyboardButton("ðŸŸ¢ Usuarios Conectados", callback_data="k_realtime")],
        [InlineKeyboardButton("âž• Crear Cuenta SSH", callback_data="k_create")],
        [InlineKeyboardButton("ðŸ‘¥ Cuentas SSH", callback_data="k_ssh")],
        [InlineKeyboardButton("ðŸ” ZipVPN Keys", callback_data="k_zipvpn")],
        [InlineKeyboardButton("ðŸŒ Xray Config", callback_data="k_xray")],
        [InlineKeyboardButton("ðŸ“Š Estado VPS", callback_data="k_stats")],
        [InlineKeyboardButton("ðŸ”‘ SlowDNS Key", callback_data="k_slowdns")],
        [InlineKeyboardButton("ðŸ”„ Refrescar", callback_data="k_refresh")],
    ])

def kb_user_list(rows, brand):
    buttons = []
    for r in rows:
        try:
            days = (datetime.date.fromisoformat(r['expires_at']) - datetime.date.today()).days
            icon = "âœ…" if days > 3 else "âš ï¸" if days > 0 else "âŒ"
        except:
            icon = "â“"
            days = "?"
        status = "ðŸŸ¢" if r['status'] == 'active' and icon != "âŒ" else "ðŸ”´"
        buttons.append([InlineKeyboardButton(
            f"{status} {r['username']} | {r['operator']} | {icon}{days}d",
            callback_data=f"k_detail_{r['username']}"
        )])
    buttons.append([InlineKeyboardButton("ðŸ”™ Volver", callback_data="k_users")])
    return InlineKeyboardMarkup(buttons)

def kb_users():
    return InlineKeyboardMarkup([
        [InlineKeyboardButton("ðŸ“‹ Todos", callback_data="k_users_all"),
         InlineKeyboardButton("âœ… Activos", callback_data="k_users_active")],
        [InlineKeyboardButton("â° Por Expirar", callback_data="k_users_expiring"),
         InlineKeyboardButton("ðŸ” Buscar", callback_data="k_users_search")],
        [InlineKeyboardButton("ðŸ§¹ Limpiar Expirados", callback_data="k_cleanup")],
        [InlineKeyboardButton("ðŸ”™ Volver", callback_data="k_back")],
    ])

def kb_user_detail(username):
    return InlineKeyboardMarkup([
        [InlineKeyboardButton("ðŸ“‹ Ver Config", callback_data=f"k_config_{username}")],
        [InlineKeyboardButton("â° Extender", callback_data=f"k_extend_{username}"),
         InlineKeyboardButton("ðŸ“‰ Reducir", callback_data=f"k_reduce_{username}")],
        [InlineKeyboardButton("ðŸ“± + Dispositivos", callback_data=f"k_devmenu_{username}"),
         InlineKeyboardButton("ðŸ—‘ Eliminar", callback_data=f"k_delete_{username}")],
        [InlineKeyboardButton("ðŸ”™ Volver", callback_data="k_users")],
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
        flag = COUNTRY_FLAGS.get(cty, 'ðŸŒŽ')
        country_name = {'co': 'Colombia', 'pe': 'PerÃº', 'in': 'India', 'ar': 'Argentina', 'sv': 'El Salvador'}.get(cty, cty)
        buttons.append([InlineKeyboardButton(f"â”€â”€â”€ {flag} {country_name} â”€â”€â”€", callback_data="knoop")])
        for code, cfg in countries[cty]:
            ct_count = len(cfg.get('connection_types', []))
            ct_text = f" ({ct_count} tipos)" if ct_count > 1 else ""
            buttons.append([InlineKeyboardButton(
                f"{cfg['flag']} {cfg['name']} {cfg['desc']}{ct_text}",
                callback_data=f"k_op_{code}"
            )])
    buttons.append([InlineKeyboardButton("ðŸ”™ Volver", callback_data="k_back")])
    return InlineKeyboardMarkup(buttons)

def kb_create_conn_types(operator_code):
    """Show connection types for selected operator"""
    op = OPERATORS.get(operator_code, {})
    buttons = []
    for ct in op.get('connection_types', []):
        proto_icon = "âš¡" if ct.get('protocol') == 'v2ray' else "ðŸ”Œ" if ct.get('protocol') == 'slowdns' else "ðŸ“¦"
        buttons.append([InlineKeyboardButton(
            f"{proto_icon} {ct['label']}",
            callback_data=f"k_conn_{ct['key']}"
        )])
    buttons.append([InlineKeyboardButton("ðŸ”™ Volver", callback_data="k_create")])
    return InlineKeyboardMarkup(buttons)

def kb_create_days():
    return InlineKeyboardMarkup([
        [InlineKeyboardButton("1ï¸âƒ£ 1 DÃ­a", callback_data="k_days_1"),
         InlineKeyboardButton("3ï¸âƒ£ 3 DÃ­as", callback_data="k_days_3"),
         InlineKeyboardButton("7ï¸âƒ£ 7 DÃ­as", callback_data="k_days_7")],
        [InlineKeyboardButton("1ï¸âƒ£5ï¸âƒ£ 15 DÃ­as", callback_data="k_days_15"),
         InlineKeyboardButton("3ï¸âƒ£0ï¸âƒ£ 30 DÃ­as", callback_data="k_days_30")],
        [InlineKeyboardButton("ðŸ”™ Volver", callback_data="k_back_op")],
    ])

def kb_create_profiles():
    return InlineKeyboardMarkup([
        [InlineKeyboardButton("1 Dispositivo", callback_data="k_prof_1"),
         InlineKeyboardButton("2 Dispositivos", callback_data="k_prof_2"),
         InlineKeyboardButton("3 Dispositivos", callback_data="k_prof_3")],
        [InlineKeyboardButton("5 Dispositivos", callback_data="k_prof_5"),
         InlineKeyboardButton("Ilimitado", callback_data="k_prof_999")],
        [InlineKeyboardButton("ðŸ”™ Volver", callback_data="k_back_conn")],
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
        [InlineKeyboardButton("âœ… CONFIRMAR CREACIÃ“N", callback_data="k_confirm")],
        [InlineKeyboardButton("âŒ Cancelar", callback_data="k_back")],
    ])

def kb_extend(username):
    return InlineKeyboardMarkup([
        [InlineKeyboardButton("+1 DÃ­a", callback_data=f"k_ext1_{username}"),
         InlineKeyboardButton("+3 DÃ­as", callback_data=f"k_ext3_{username}"),
         InlineKeyboardButton("+7 DÃ­as", callback_data=f"k_ext7_{username}")],
        [InlineKeyboardButton("+15 DÃ­as", callback_data=f"k_ext15_{username}"),
         InlineKeyboardButton("+30 DÃ­as", callback_data=f"k_ext30_{username}")],
        [InlineKeyboardButton("ðŸ”™ Volver", callback_data=f"k_detail_{username}")],
    ])

def kb_reduce(username):
    return InlineKeyboardMarkup([
        [InlineKeyboardButton("-1 DÃ­a", callback_data=f"k_red1_{username}"),
         InlineKeyboardButton("-3 DÃ­as", callback_data=f"k_red3_{username}"),
         InlineKeyboardButton("-7 DÃ­as", callback_data=f"k_red7_{username}")],
        [InlineKeyboardButton("ðŸ”™ Volver", callback_data=f"k_detail_{username}")],
    ])

def kb_extend_devices(username):
    return InlineKeyboardMarkup([
        [InlineKeyboardButton("+1", callback_data=f"k_dev1_{username}"),
         InlineKeyboardButton("+2", callback_data=f"k_dev2_{username}"),
         InlineKeyboardButton("+3", callback_data=f"k_dev3_{username}")],
        [InlineKeyboardButton("+5", callback_data=f"k_dev5_{username}"),
         InlineKeyboardButton("+10", callback_data=f"k_dev10_{username}")],
        [InlineKeyboardButton("ðŸ”™ Volver", callback_data=f"k_detail_{username}")],
    ])

# =============================================================================
# START
# =============================================================================
async def cmd_start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    user = update.effective_user
    user_id = user.id
    if user_id not in ADMIN_IDS and not is_admin(user_id):
        await update.message.reply_text("âŒ Sin permisos de acceso.")
        return K_MAIN
    role = get_admin_role(user_id)
    brand = get_admin_brand(user_id)
    text = f"""{brand_header()}

ðŸ‘¤ <b>Proveedor:</b> {user.first_name} (@{user.username or 'N/A'})
ðŸ·ï¸ <b>Rol:</b> {role.upper()}
ðŸ“¡ <b>Marca:</b> {brand.upper()}

{brand_divider()}

âš¡ Selecciona una opciÃ³n:"""
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
        await query.answer("âŒ Sin permisos", show_alert=True)
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
            "ðŸ” <b>Buscar Usuario</b>\n" + brand_divider() + "\n\nEscribe el username o Telegram ID:",
            parse_mode=ParseMode.HTML,
            reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("ðŸ”™ Cancelar", callback_data="k_users")]])
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

    # === CREAR CUENTA â€” FLOW: Operator â†’ ConnType â†’ Days â†’ Profiles â†’ Mode â†’ Confirm ===
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

    # === ZIPVPN ===
    elif data == "k_zipvpn":
        return await show_zipvpn_menu(update, context)
    elif data == "k_zipvpn_add":
        context.user_data["zipvpn_add_step"] = "password"
        context.user_data["zipvpn_add_data"] = {}
        await query.edit_message_text(
            f"ðŸ” <b>Agregar Clave ZipVPN</b>\n{brand_divider()}\n\n"
            "ðŸ“ Paso 1/3 â€” Envia la <b>contraseÃ±a</b> del cliente\n"
            "(ej: <code>mi_clave_123</code>):",
            parse_mode=ParseMode.HTML,
            reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("ðŸ”™ Cancelar", callback_data="k_zipvpn")]])
        )
        return K_ZIPVPN_ADD_MENU
    elif data == "k_zipvpn_del":
        context.user_data["zipvpn_mode"] = "del"
        await query.edit_message_text(
            "ðŸ” <b>Eliminar clave ZipVPN</b>\n" + brand_divider() + "\n\n"
            "Envia la clave que quieres eliminar de ZipVPN:",
            parse_mode=ParseMode.HTML,
            reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("ðŸ”™ Cancelar", callback_data="k_zipvpn")]])
        )
        return K_ZIPVPN_INPUT

    # === ZIPVPN ADD MULTI-STEP CALLBACKS ===
    elif data.startswith("k_zdays_") or data == "k_zconfirm":
        return await zipvpn_add_menu_handler(update, context)

    # === XRAY ===
    elif data == "k_xray":
        return await show_xray_menu(update, context)
    elif data == "k_xray_add":
        context.user_data["xray_add_step"] = "email"
        context.user_data["xray_add_data"] = {}
        await query.edit_message_text(
            f"ðŸŒ <b>Agregar Cliente Xray</b>\n{brand_divider()}\n\n"
            "ðŸ“ Paso 1/5 â€” Envia el <b>email/usuario</b> del cliente\n"
            "(ej: <code>juan_123</code> o escribe <code>auto</code>):",
            parse_mode=ParseMode.HTML,
            reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("ðŸ”™ Cancelar", callback_data="k_xray")]])
        )
        return K_XRAY_ADD_INPUT
    elif data == "k_xray_del":
        context.user_data["xray_mode"] = "del"
        await query.edit_message_text(
            f"ðŸŒ <b>Eliminar Cliente Xray</b>\n{brand_divider()}\n\n"
            "ðŸ“ Envia el <b>email</b> del cliente a eliminar:",
            parse_mode=ParseMode.HTML,
            reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("ðŸ”™ Cancelar", callback_data="k_xray")]])
        )
        return K_XRAY_INPUT
    elif data == "k_xray_copy":
        link = context.user_data.get("xray_link", "")
        if link:
            await query.answer(f"Link copiado!", show_alert=True)
            # Send as separate message for easy copy
            await context.bot.send_message(
                query.from_user.id,
                f"<code>{link}</code>",
                parse_mode=ParseMode.HTML)
        else:
            await query.answer("No hay link para copiar", show_alert=True)
        return K_MAIN

    # === XRAY ADD MULTI-STEP CALLBACKS ===
    elif data.startswith("k_xdays_") or data.startswith("k_xdev_") or data == "k_xconfirm":
        return await xray_add_menu_handler(update, context)

    elif data == "k_xray_restart":
        try:
            import asyncio
            loop = asyncio.get_event_loop()
            from ssh_utils import _vps_exec
            # Fix permissions before restart (mktemp creates 600 perms)
            await loop.run_in_executor(None, lambda: _vps_exec("chmod 644 /usr/local/etc/xray/config.json /etc/zivpn/config.json 2>/dev/null; systemctl restart xray; sleep 1; systemctl is-active xray"))
            await query.answer("âœ… Xray reiniciado", show_alert=True)
        except Exception as e:
            await query.answer(f"âŒ Error: {e}", show_alert=True)
        return K_MAIN

    # === SSH ACCOUNTS ===
    elif data == "k_ssh":
        return await show_ssh_menu(update, context)
    elif data.startswith("k_ssh_detail:"):
        return await show_ssh_detail(update, context)
    elif data.startswith("k_ssh_renew:"):
        return await show_ssh_renew(update, context)
    elif data.startswith("k_ssh_renew_go:"):
        return await do_ssh_renew(update, context)
    elif data.startswith("k_ssh_edit_limit:"):
        return await show_ssh_edit_limit(update, context)
    elif data.startswith("k_ssh_custom_limit:"):
        return await ssh_custom_limit_input(update, context)
    elif data.startswith("k_ssh_set_limit:"):
        return await do_ssh_set_limit(update, context)
    elif data.startswith("k_ssh_del:"):
        return await ssh_del_confirm(update, context)
    elif data == "k_ssh_del_go":
        return await ssh_del_go(update, context)

    # === SLOWDNS KEY ===
    elif data == "k_slowdns":
        return await show_slowdns_key(update, context)
    elif data == "k_slowdns_copy":
        key = context.user_data.get("slowdns_key", "")
        if key:
            await query.answer(f"Clave copiada!", show_alert=True)
        else:
            await query.answer("No hay clave disponible", show_alert=True)
        return K_MAIN

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
    text = f"""ðŸŒ <b>USUARIOS {BRAND_NAME}</b>
{brand_divider()}

â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
â”‚ ðŸ“Š Resumen de la marca    â”‚
â”œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¤
â”‚ ðŸ‘¥ Total: <b>{stats['total'] or 0}</b>
â”‚ âœ… Activos: <b>{stats['active'] or 0}</b>
â”‚ âŒ Expirados: <b>{stats['expired'] or 0}</b>
â”‚ â° Por expirar (3d): <b>{stats['expiring'] or 0}</b>
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜

âš¡ Selecciona una opciÃ³n:"""
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

    text = f"ðŸŒ <b>USUARIOS {BRAND_NAME} ({title})</b>\n{brand_divider()}\n\n"
    if not rows:
        text += "ðŸ“­ Sin usuarios registrados.\n"
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
        await query.edit_message_text("âŒ Usuario no encontrado.", reply_markup=kb_users())
        return K_USERS_MENU

    try:
        days = (datetime.date.fromisoformat(row['expires_at']) - datetime.date.today()).days
        days_icon = "âœ…" if days > 3 else "âš ï¸" if days > 0 else "âŒ"
    except:
        days = "?"
        days_icon = "â“"

    status = "ðŸŸ¢ ACTIVO" if row['status'] == 'active' and days_icon != "âŒ" else "ðŸ”´ EXPIRADO"
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

    text = f"""ðŸŒ <b>DETALLE - {BRAND_NAME}</b>
{brand_divider()}

â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
â”‚ ðŸ‘¤ <b>Usuario:</b> <code>{row['username']}</code>
â”‚ ðŸ”‘ <b>Password:</b> <code>{row['password']}</code>
â”œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¤
â”‚ ðŸ“¡ <b>Operador:</b> {op_flag} {row['operator']}
"""
    if conn_label:
        text += f"â”‚ ðŸ”— <b>Tipo:</b> {conn_label}\n"
    hwid_val = row['hwid'] if 'hwid' in row.keys() else None
    if hwid_val:
        text += f"â”‚ ðŸ“± <b>HWID:</b> <code>{hwid_val}</code>\n"
    text += f"""â”‚ ðŸ“Š <b>Estado:</b> {status}
â”‚ ðŸ“… <b>Expira:</b> {row['expires_at']}
â”‚ â° <b>DÃ­as restantes:</b> {days_icon} {days}
â”‚ ðŸ‘¤ <b>Dispositivos:</b> {row['max_logins']}
â”‚ ðŸŽ <b>Trial:</b> {trial}
â”œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¤
â”‚ ðŸ·ï¸ <b>Marca:</b> {brand.upper()}
â”‚ ðŸ“ <b>Creado:</b> {row['created_at'] if 'created_at' in row.keys() else 'N/A'}
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜

âš¡ Selecciona acciÃ³n:"""
    await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=kb_user_detail(username))
    return K_USER_DETAIL

# =============================================================================
# USUARIOS - CONFIG SSH
# =============================================================================
async def show_user_config(update: Update, context: ContextTypes.DEFAULT_TYPE, username: str) -> int:
    query = update.callback_query
    row = db.fetchone("SELECT * FROM system_users WHERE username=?", (username,))
    if not row:
        await query.edit_message_text("âŒ Usuario no encontrado.", reply_markup=kb_users())
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
        "ðŸŸ¢ <b>Buscando usuarios conectados...</b>\n" + brand_divider() + "\nâ³ Consultando servidor VPS...",
        parse_mode=ParseMode.HTML
    )

    try:
        import asyncio, re as _re
        loop = asyncio.get_event_loop()
        from ssh_utils import _vps_exec

        def _fmt_bytes(b):
            if b >= 1073741824: return f"{b/1073741824:.2f} GB"
            elif b >= 1048576: return f"{b/1048576:.1f} MB"
            elif b >= 1024: return f"{b/1024:.1f} KB"
            return f"{b} B"

        # â”€â”€ 1) SSH users connected â”€â”€
        ps_out, _ = await loop.run_in_executor(None, lambda: _vps_exec(
            "ps -eo args= 2>/dev/null | grep 'sshd:' | grep -v root | grep -v listener"
        ))
        ssh_users = {}
        for line in (ps_out or "").splitlines():
            m = _re.search(r'sshd:\s+(\S+)', line)
            if m:
                u = m.group(1)
                if u not in ('root', 'sshd', '[priv]'):
                    ssh_users[u] = ssh_users.get(u, 0) + 1

        # â”€â”€ 2) Protocol connections â”€â”€
        ss_out, _ = await loop.run_in_executor(None, lambda: _vps_exec(
            "ss -tnp 2>/dev/null | grep ESTAB"
        ))
        proto_counts = {"SSH": 0, "BadVPN": 0, "Xray": 0, "SlowDNS": 0, "UDP Custom": 0, "Otro": 0}
        for line in (ss_out or "").splitlines():
            if 'sshd' in line:
                proto_counts["SSH"] += 1
            elif 'badvpn' in line:
                proto_counts["BadVPN"] += 1
            elif 'xray' in line:
                proto_counts["Xray"] += 1
            elif 'slowdns' in line:
                proto_counts["SlowDNS"] += 1

        # â”€â”€ 3) Bandwidth per user (iptables uid-owner) â”€â”€
        live_bytes = {}
        bw_out, _ = await loop.run_in_executor(None, lambda: _vps_exec(
            "iptables -L OUTPUT -v -n 2>/dev/null | grep 'UID match' | head -50"
        ))
        for line in (bw_out or "").splitlines():
            match = _re.search(r'(\d+)\s+(\d+).*owner UID match (\d+)', line)
            if match:
                uid = int(match.group(3))
                uname_out, _ = await loop.run_in_executor(None, lambda uid=uid: _vps_exec(f"getent passwd {uid} | cut -d: -f1"))
                if uname_out and uname_out.strip():
                    live_bytes[uname_out.strip()] = int(match.group(2))

        # â”€â”€ 4) Consumption from online.sh data files â”€â”€
        cons_out, _ = await loop.run_in_executor(None, lambda: _vps_exec(
            "cat /etc/movivip/sistema/consumo_usuarios.conf 2>/dev/null"
        ))
        consumed = {}
        for line in (cons_out or "").splitlines():
            if '=' in line:
                parts = line.split('=', 1)
                try:
                    consumed[parts[0]] = int(parts[1])
                except:
                    pass

        # â”€â”€ 5) Limits â”€â”€
        lim_out, _ = await loop.run_in_executor(None, lambda: _vps_exec(
            "cat /etc/movivip/sistema/limites_consumo.conf 2>/dev/null"
        ))
        limits = {}
        for line in (lim_out or "").splitlines():
            if '=' in line:
                parts = line.split('=', 1)
                try:
                    limits[parts[0]] = int(parts[1])
                except:
                    pass

        # â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
        # SECTION 1: USUARIOS ONLINE
        # â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
        text = "ðŸŸ¢ <b>USUARIOS EN TIEMPO REAL</b>\n" + brand_divider()
        text += f"\nðŸ‘ <b>USUARIOS ONLINE</b>\n"

        all_online = list(ssh_users.keys())
        if all_online:
            for i, u in enumerate(all_online, 1):
                text += f"\n  ðŸŸ¢ <b>{u}</b> â€” {ssh_users[u]} conexiÃ³n(es)"
        else:
            text += "\n  âšª No hay usuarios conectados"

        text += f"\n\nðŸ“Š Usuarios Online: <b>{len(all_online)}</b>"

        # â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
        # SECTION 2: CONEXIONES POR PROTOCOLO
        # â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
        text += f"\n\nðŸŒ <b>PROTOCOLOS ACTIVOS</b>\n"
        active_protos = {k: v for k, v in proto_counts.items() if v > 0}
        if active_protos:
            proto_icons = {"SSH": "ðŸ”", "BadVPN": "âš¡", "Xray": "â˜ï¸", "SlowDNS": "ðŸŒŠ", "UDP Custom": "ðŸ“¦", "Otro": "â“"}
            for proto, count in active_protos.items():
                text += f"  {proto_icons.get(proto, 'â“')} {proto}: <b>{count}</b>\n"
        else:
            text += "  âšª Sin conexiones activas\n"

        total_conns = sum(proto_counts.values())
        text += f"  ðŸ“Š Total Conexiones: <b>{total_conns}</b>"

        # â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
        # SECTION 3: CONSUMO GB POR USUARIO
        # â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
        # Show all brand users with consumption
        all_brand_users = db.fetchall(
            "SELECT username, password, operator, expires_at, max_logins, status FROM system_users WHERE brand=?",
            (brand,)
        )

        if all_brand_users:
            text += f"\n\nðŸ“Š <b>CONSUMO POR USUARIO</b>\n"
            for r in all_brand_users:
                u = r['username']
                is_on = u in ssh_users
                icon = "ðŸŸ¢" if is_on else "âšª"
                total_b = consumed.get(u, 0) + live_bytes.get(u, 0)
                lim = limits.get(u, 0)
                lim_str = _fmt_bytes(lim) if lim > 0 else "â™¾"
                text += f"  {icon} <code>{u}</code> â€” {_fmt_bytes(total_b)} / {lim_str}\n"
        else:
            # If no brand users in DB, show all VPS users
            all_vps_users = set(list(ssh_users.keys()) + list(consumed.keys()) + list(live_bytes.keys()))
            if all_vps_users:
                text += f"\n\nðŸ“Š <b>CONSUMO POR USUARIO</b>\n"
                for u in sorted(all_vps_users):
                    is_on = u in ssh_users
                    icon = "ðŸŸ¢" if is_on else "âšª"
                    total_b = consumed.get(u, 0) + live_bytes.get(u, 0)
                    lim = limits.get(u, 0)
                    lim_str = _fmt_bytes(lim) if lim > 0 else "â™¾"
                    text += f"  {icon} <code>{u}</code> â€” {_fmt_bytes(total_b)} / {lim_str}\n"

        text += f"\n{brand_divider()}"
        text += f"\nðŸ• Actualizado: <b>{datetime.datetime.now().strftime('%d/%m/%Y %H:%M:%S')}</b>"

        kb = InlineKeyboardMarkup([
            [InlineKeyboardButton("ðŸ”„ Actualizar", callback_data="k_realtime")],
            [InlineKeyboardButton("ðŸ”™ Volver", callback_data="k_back")],
        ])
        await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=kb)

    except Exception as e:
        logger.error(f"Realtime error: {e}")
        await query.edit_message_text(
            f"âŒ Error obteniendo usuarios: <code>{e}</code>",
            parse_mode=ParseMode.HTML,
            reply_markup=InlineKeyboardMarkup([
                [InlineKeyboardButton("ðŸ”„ Reintentar", callback_data="k_realtime")],
                [InlineKeyboardButton("ðŸ”™ Volver", callback_data="k_back")]])
        )
    return K_REALTIME

# =============================================================================
# CREAR CUENTA â€” STEP 1: Select Operator
# =============================================================================
async def show_create_menu(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    text = f"""ðŸŒ <b>CREAR CUENTA - {BRAND_NAME}</b>
{brand_divider()}

ðŸ“¡ Selecciona el operador:"""
    await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=kb_create_ops())
    return K_CREATE_OP

# =============================================================================
# CREAR CUENTA â€” STEP 2: Select Connection Type
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

    text = f"""ðŸŒ <b>TIPO DE CONEXIÃ“N â€” {op.get('flag', '')} {op.get('name', op_code)}</b>
{brand_divider()}

ðŸ“¡ Selecciona el tipo de conexiÃ³n:"""
    await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=kb_create_conn_types(op_code))
    return K_CREATE_CONN_TYPE

# =============================================================================
# CREAR CUENTA â€” STEP 3: Show operator config info
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

    text = f"""ðŸŒ <b>CONFIG â€” {op.get('flag', '')} {op.get('name', op_code)}</b>
{brand_divider()}

â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
â”‚ ðŸ“¡ <b>Operador:</b> {op.get('name', op_code)}
â”‚ ðŸ³ï¸ <b>PaÃ­s:</b> {op.get('flag', '')} {op.get('country', 'co').upper()}
"""
    if ct_config:
        text += f"â”‚ ðŸ”— <b>Tipo:</b> {ct_config.get('label', 'N/A')}\n"
        text += f"â”‚ ðŸŒ <b>Puerto:</b> {ct_config.get('port', 'N/A')}\n"
        text += f"â”‚ âš™ï¸ <b>Protocolo:</b> {ct_config.get('protocol', 'N/A')}\n"
        # OCULTAR SNI/Payload para operadores de Colombia
        if op.get('country') != 'co':
            if ct_config.get('snis'):
                text += f"â”‚ ðŸ”’ <b>SNI:</b> {', '.join(ct_config['snis'])}\n"
            if ct_config.get('ssh_field'):
                text += f"â”‚ ðŸ“¡ <b>SSH Field:</b> <code>{ct_config['ssh_field']}</code>\n"
            if ct_config.get('v2ray_host'):
                text += f"â”‚ ðŸŒ <b>V2Ray Host:</b> <code>{ct_config['v2ray_host']}</code>\n"
            if ct_config.get('payload'):
                text += f"â”‚ ðŸ“¦ <b>Payload:</b> <code>âœ… Configurado</code>\n"
        else:
            # Para Colombia: solo mostrar info basica sin datos sensibles
            if ct_config.get('protocol') == 'v2ray':
                text += f"â”‚ ðŸŒ <b>V2Ray:</b> <code>âœ… Habilitado</code>\n"
            else:
                text += f"â”‚ ðŸ“¡ <b>ConexiÃ³n:</b> <code>Configurada</code>\n"
    else:
        text += f"â”‚ âš™ï¸ <b>Protocolo:</b> {op.get('protocol', 'N/A')}\n"

    text += f"""â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜

{brand_divider()}
â° Selecciona dÃ­as de vigencia:"""

    await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=kb_create_days())
    return K_CREATE_DAYS

# =============================================================================
# CREAR CUENTA â€” STEP 4: Select Profiles
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

    text = f"""ðŸŒ <b>CREAR CUENTA - {BRAND_NAME}</b>
{brand_divider()}

ðŸ“¡ Operador: <b>{op.get('flag', '')} {op.get('name', op_code)}</b>
ðŸ”— Tipo: <b>{ct_label or 'N/A'}</b>
â° DÃ­as: <b>{days}</b>
ðŸ·ï¸ Marca: <b>{BRAND_NAME.upper()}</b>

ðŸ‘¤ Selecciona dispositivos (perfiles):"""
    await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=kb_create_profiles())
    return K_CREATE_PROFILES

# =============================================================================
# CREAR CUENTA â€” STEP 5: Credential Mode
# =============================================================================
async def show_create_mode(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    op_code = context.user_data["op"]
    days = context.user_data["days"]
    profiles = context.user_data["profiles"]
    op = OPERATORS.get(op_code, {})
    prof_text = str(profiles) if profiles < 999 else "Ilimitado"

    text = (
        "ðŸŒ <b>CREAR CUENTA SSH - {BRAND_NAME}</b>\n"
        + brand_divider() + "\n\n"
        f"ðŸ“¡ Operador: <b>{op.get('flag', '')} {op.get('name', op_code)}</b>\n"
        f"â° DÃ­as: <b>{days}</b>\n"
        f"ðŸ‘¤ Dispositivos: <b>{prof_text}</b>\n\n"
        "ðŸ”‘ <b>Como deseas generar las credenciales?</b>"
    )
    await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=kb_create_mode())
    return K_CREATE_MODE

async def ask_manual_username(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    text = (
        "ðŸŒ <b>CREAR CUENTA - USUARIO MANUAL</b>\n"
        + brand_divider() + "\n\n"
        "ðŸ‘¤ <b>Escribe el nombre de usuario</b> que deseas asignar:\n\n"
        "ðŸ“ Ejemplo: <code>juan_01</code>, <code>cliente23</code>, <code>karla_tigo</code>\n\n"
        "âš ï¸ Sin espacios, solo letras, numeros y guion bajo"
    )
    await query.edit_message_text(text, parse_mode=ParseMode.HTML)
    return K_CREATE_USER

async def ask_manual_password(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    username = update.message.text.strip().replace(" ", "")
    if not re.match(r'^[a-zA-Z0-9_-]+$', username) or len(username) < 3:
        await update.message.reply_text(
            "âŒ <b>Usuario invalido</b>\n\nMinimo 3 caracteres, sin espacios.\nSolo: letras, numeros, guion bajo, guion.\n\nIntenta de nuevo:",
            parse_mode=ParseMode.HTML)
        return K_CREATE_USER
    existing = db.fetchone("SELECT username FROM system_users WHERE username=?", (username,))
    if existing:
        await update.message.reply_text(
            f"âŒ <b>El usuario '{username}' ya existe</b>\n\nEscribe otro nombre de usuario:",
            parse_mode=ParseMode.HTML)
        return K_CREATE_USER
    context.user_data["manual_username"] = username
    text = (
        "ðŸŒ <b>CREAR CUENTA - PASSWORD MANUAL</b>\n"
        + brand_divider() + "\n\n"
        f"ðŸ‘¤ Usuario: <b>{username}</b>\n\n"
        "ðŸ”‘ <b>Escribe la contrasena</b> que deseas asignar:\n\n"
        "ðŸ“ Ejemplo: <code>MiClave123</code>, <code>juan2026</code>, <code>TuMarca123$</code>\n\n"
        "âš ï¸ Minimo 6 caracteres"
    )
    await update.message.reply_text(text, parse_mode=ParseMode.HTML)
    return K_CREATE_PASS

async def confirm_manual_creds(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    password = update.message.text.strip()
    if len(password) < 6:
        await update.message.reply_text("âŒ <b>Contrasena muy corta</b> (minimo 6 caracteres)\n\nEscribe una contrasena mas larga:", parse_mode=ParseMode.HTML)
        return K_CREATE_PASS
    context.user_data["manual_password"] = password
    username = context.user_data["manual_username"]
    return await _show_confirm_from_message(update, context, username, password)

async def ask_hwid(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    text = (
        "ðŸ” <b>CREAR CUENTA - CON HWID</b>\n"
        + brand_divider() + "\n\n"
        "ðŸ“± <b>Pega el HWID del dispositivo</b> del cliente (HTTP Custom).\n\n"
        "ðŸ”Ž El cliente lo obtiene en la app:\n"
        "HTTP Custom â†’ Ajustes â†’ HWID / ID del dispositivo\n\n"
        "ðŸ“ Ejemplo: <code>a1b2c3d4e5f60718</code>\n\n"
        "âš ï¸ La cuenta quedara asociada a ese dispositivo.\n"
        "ðŸ’¡ Para cancelar: /cancelar"
    )
    await query.edit_message_text(text, parse_mode=ParseMode.HTML)
    return K_CREATE_HWID

async def confirm_hwid(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    hwid = update.message.text.strip()
    if not re.match(r'^[A-Za-z0-9_:.-]+$', hwid) or len(hwid) < 4 or len(hwid) > 64:
        await update.message.reply_text(
            "âŒ <b>HWID invalido</b>\n\n"
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
        "ðŸŒ <b>CONFIRMAR CREACION - {BRAND_NAME}</b>\n"
        + brand_divider() + "\n\n"
        "â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”\n"
        "â”‚ ðŸŽ¯ Modo: <b>CON HWID</b>\n"
        f"â”‚ ðŸ“± HWID: <code>{hwid}</code>\n"
        f"â”‚ ðŸ“¡ Operador: <b>{op.get('flag', '')} {op.get('name', op_code)}</b>\n"
        f"â”‚ ðŸ”— Tipo: <b>{ct_label or 'N/A'}</b>\n"
        f"â”‚ â° Dias: <b>{days}</b>\n"
        f"â”‚ ðŸ‘¤ Dispositivos: <b>{prof_text}</b>\n"
        f"â”‚ ðŸ·ï¸ Marca: <b>{BRAND_NAME.upper()}</b>\n"
        "â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜\n\n"
        "âš ï¸ Se creara la cuenta en el servidor VPS.\n\n"
        "âš¡ Confirma la creacion:"
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
        "ðŸŒ <b>CONFIRMAR CREACION - {BRAND_NAME}</b>\n"
        + brand_divider() + "\n\n"
        "â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”\n"
        f"â”‚ ðŸ‘¤ Usuario: <b>{username}</b>\n"
        f"â”‚ ðŸ”‘ Contrasena: <b>{password}</b>\n"
        "â”‚ ðŸŽ¯ Modo: <b>MANUAL</b>\n"
        f"â”‚ ðŸ“¡ Operador: <b>{op.get('flag', '')} {op.get('name', op_code)}</b>\n"
        f"â”‚ ðŸ”— Tipo: <b>{ct_label or 'N/A'}</b>\n"
        f"â”‚ â° Dias: <b>{days}</b>\n"
        f"â”‚ ðŸ‘¤ Dispositivos: <b>{prof_text}</b>\n"
        f"â”‚ ðŸ·ï¸ Marca: <b>{BRAND_NAME.upper()}</b>\n"
        "â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜\n\n"
        "âš ï¸ Se creara la cuenta en el servidor VPS.\n\n"
        "âš¡ Confirma la creacion:"
    )
    await update.message.reply_text(text, parse_mode=ParseMode.HTML, reply_markup=kb_confirm())
    return K_CREATE_CONFIRM

# =============================================================================
# CREAR CUENTA â€” STEP 6: Confirm
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
        cred_info = f"| ðŸ‘¤ Usuario: <b>{cred_user}</b>\n| ðŸ”‘ Contrasena: <b>{cred_pass}</b>\n| ðŸŽ¯ Modo: <b>MANUAL</b>\n|"
    else:
        cred_info = "| ðŸŽ¯ Modo: <b>AUTOMATICO</b>\n|"

    text = f"""ðŸŒ <b>CONFIRMAR CREACION - {BRAND_NAME}</b>
{brand_divider()}

â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
{cred_info}
| ðŸ“¡ Operador: <b>{op.get('flag', '')} {op.get('name', op_code)}</b>
| ðŸ”— Tipo: <b>{ct_label or 'N/A'}</b>
| â° Dias: <b>{days}</b>
| ðŸ‘¤ Dispositivos: <b>{prof_text}</b>
| ðŸ·ï¸ Marca: <b>{BRAND_NAME.upper()}</b>
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜

âš ï¸ Se creara la cuenta en el servidor VPS.

âš¡ Confirma la creacion:"""
    await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=kb_confirm())
    return K_CREATE_CONFIRM

# =============================================================================
# CREAR CUENTA â€” EXECUTE
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
        "ðŸŒ <b>CREANDO CUENTA SSH...</b>\n" + brand_divider() + "\nâ³ Procesando en el servidor VPS...",
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
            [InlineKeyboardButton("âœ… Crear Otra", callback_data="k_create")],
            [InlineKeyboardButton("ðŸ‘¥ Ver Usuarios", callback_data="k_users")],
            [InlineKeyboardButton("ðŸ  MenÃº Principal", callback_data="k_back")],
        ])

        # Regenerate HTML banners
        try:
            import subprocess as _sp
            _sp.run("python3 /root/movivip_bots/gen_banners.py", shell=True, capture_output=True, timeout=30)
        except:
            pass

        await query.edit_message_text(
            f"âœ… <b>CUENTA CREADA EXITOSAMENTE</b>\n{brand_divider()}\n\n{config_text}",
            parse_mode=ParseMode.HTML, reply_markup=kb
        )
    else:
        text = f"""âŒ <b>ERROR AL CREAR CUENTA</b>
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
        await query.edit_message_text("âŒ No encontrado.", reply_markup=kb_users())
        return K_USERS_MENU
    text = f"""ðŸŒ <b>EXTENDER - {username}</b>
{brand_divider()}

ðŸ“… Expira actualmente: <b>{row['expires_at']}</b>

â° Cuantos dÃ­as quieres agregar?"""
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
            await query.edit_message_text("âŒ No encontrado.", reply_markup=kb_users())
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

    # Fix expiry on VPS via SSH
    try:
        import asyncio
        loop = asyncio.get_event_loop()
        from ssh_utils import _vps_exec
        await loop.run_in_executor(None, lambda: _vps_exec(f"usermod -e {new_expire} {username}"))
    except Exception as e2:
        logging.error(f"[do_extend] VPS usermod error: {e2}")

    text = f"âœ… <b>EXTENSIÃ“N APLICADA</b>\n{brand_divider()}\n\nðŸ‘¤ Usuario: <code>{username}</code>\nâ° DÃ­as agregados: <b>+{days}</b>\nðŸ“… Nueva expiraciÃ³n: <b>{new_expire}</b>"
    await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=kb_user_detail(username))
    log_audit(query.from_user.id, "klepernet_extend", f"user={username} +{days}d")
    return K_USER_DETAIL

async def show_reduce(update: Update, context: ContextTypes.DEFAULT_TYPE, username: str) -> int:
    query = update.callback_query
    row = db.fetchone("SELECT * FROM system_users WHERE username=?", (username,))
    if not row:
        await query.edit_message_text("âŒ No encontrado.", reply_markup=kb_users())
        return K_USERS_MENU
    text = f"""ðŸŒ <b>REDUCIR - {username}</b>
{brand_divider()}

ðŸ“… Expira actualmente: <b>{row['expires_at']}</b>

â° Cuantos dÃ­as quieres quitar?"""
    await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=kb_reduce(username))
    return K_REDUCE

async def show_extend_devices(update: Update, context: ContextTypes.DEFAULT_TYPE, username: str) -> int:
    query = update.callback_query
    row = db.fetchone("SELECT * FROM system_users WHERE username=?", (username,))
    if not row:
        await query.edit_message_text("âŒ No encontrado.", reply_markup=kb_users())
        return K_USERS_MENU
    current = row['max_logins'] if 'max_logins' in row.keys() else 1
    text = f"ðŸ“± <b>DISPOSITIVOS - {username}</b>\n{brand_divider()}\n\nðŸ‘¤ Dispositivos actuales: <b>{current}</b>\n\nCuantos dispositivos quieres agregar?"
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
            await query.edit_message_text("âŒ No encontrado.", reply_markup=kb_users())
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
    text = f"âœ… <b>DISPOSITIVOS ACTUALIZADOS</b>\n{brand_divider()}\n\nðŸ‘¤ Usuario: <code>{username}</code>\nðŸ“± Dispositivos: <b>{current} \u2192 {new_max}</b>"
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
            await query.edit_message_text("âŒ No encontrado.", reply_markup=kb_users())
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

    # Fix expiry on VPS via SSH
    try:
        import asyncio
        loop = asyncio.get_event_loop()
        from ssh_utils import _vps_exec
        await loop.run_in_executor(None, lambda: _vps_exec(f"usermod -e {new_expire} {username}"))
    except Exception as e2:
        logging.error(f"[do_reduce] VPS usermod error: {e2}")

    text = f"âœ… <b>REDUCCIÃ“N APLICADA</b>\n{brand_divider()}\n\nðŸ‘¤ Usuario: <code>{username}</code>\nâ° DÃ­as quitados: <b>-{days}</b>\nðŸ“… Nueva expiraciÃ³n: <b>{new_expire}</b>"
    await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=kb_user_detail(username))
    log_audit(query.from_user.id, "klepernet_reduce", f"user={username} -{days}d")
    return K_USER_DETAIL

async def do_delete(update: Update, context: ContextTypes.DEFAULT_TYPE, username: str) -> int:
    query = update.callback_query
    user_id = query.from_user.id
    logging.info(f"[do_delete] CALLED: user={username} admin={user_id}")

    # Look up password from DB before deleting
    password = None
    try:
        row = db.fetchone("SELECT password FROM system_users WHERE username=?", (username,))
        if row:
            password = row["password"]
    except:
        pass

    vps_msg = ""
    try:
        from ssh_utils import delete_ssh_on_vps
        loop = asyncio.get_event_loop()
        result = await loop.run_in_executor(None, lambda: delete_ssh_on_vps(username, password))
        if result:
            vps_msg = "\nâš™ï¸ SSH + ZipVPN + Xray eliminados del VPS"
        else:
            vps_msg = "\nâš ï¸ VPS: Eliminacion parcial"
    except Exception as e:
        logging.error(f"[do_delete] VPS delete error: {e}")
        vps_msg = f"\nâš ï¸ Error VPS: {e}"

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
    text = f"ðŸ—‘ <b>USUARIO ELIMINADO</b>\n{brand_divider()}\n\nðŸ‘¤ <code>{username}</code> eliminado de {brand.upper()}.{vps_msg}"
    await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=kb_users())
    return K_USERS_MENU

async def cleanup_expired(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    user_id = query.from_user.id
    brand = get_admin_brand(user_id)
    expired = db.fetchall(
        "SELECT username, password FROM system_users WHERE brand=? AND (status='expired' OR expires_at < date('now'))",
        (brand,))
    count = 0
    try:
        from ssh_utils import delete_ssh_on_vps
        loop = asyncio.get_event_loop()
        for row in expired:
            try:
                await loop.run_in_executor(None, lambda u=row, p=row['password']: delete_ssh_on_vps(u, p))
                count += 1
            except:
                count += 1  # Still count even if VPS fails
    except Exception as e:
        logging.error(f"[cleanup] Error: {e}")
        count = len(expired)
    db.execute("UPDATE system_users SET status='expired' WHERE brand=? AND (status='expired' OR expires_at < date('now'))", (brand,))
    log_audit(user_id, "klepernet_cleanup", f"removed={count}")
    await query.edit_message_text(f"ðŸ§¹ <b>LIMPIEZA COMPLETADA</b>\n{brand_divider()}\n\nâœ… {count} usuarios expirados eliminados de {brand.upper()}.", parse_mode=ParseMode.HTML, reply_markup=kb_users())
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
    result_text = f"ðŸ” <b>BUSCAR: {text}</b>\n{brand_divider()}\n\n"
    if not rows:
        result_text += "ðŸ“­ Sin resultados."
    else:
        for i, r in enumerate(rows, 1):
            try:
                days = (datetime.date.fromisoformat(r['expires_at']) - datetime.date.today()).days
                days_icon = "âœ…" if days > 3 else "âš ï¸" if days > 0 else "âŒ"
            except:
                days_icon = "â“"
                days = "?"
            result_text += f"ðŸ‘¤ <b>{i}. {r['username']}</b>\n   ðŸ”‘ {r['password']} | ðŸ“¡ {r['operator']}\n   {days_icon} {days}d | ðŸ‘¤ {r['max_logins']} disp\n\n"
    await update.message.reply_text(result_text, parse_mode=ParseMode.HTML, reply_markup=kb_users())
    return K_USERS_MENU

# =============================================================================
# SSH - MENU DE GESTION (listar + eliminar cuentas SSH)
# =============================================================================
async def show_ssh_menu(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Show SSH accounts list with detail buttons."""
    query = update.callback_query
    await query.answer()

    try:
        import asyncio
        loop = asyncio.get_event_loop()
        from ssh_utils import list_vps_users
        users = await loop.run_in_executor(None, list_vps_users)

        text = f"ðŸ‘¥ <b>Cuentas SSH</b>\n{brand_divider()}\n\n"

        if users:
            text += f"ðŸ“Š <b>Total:</b> {len(users)} cuentas\n\n"
            buttons = []
            for u in users[:15]:
                status = "âœ…" if u.get("expires", "") else "âŒ"
                exp = u.get("expires", "?")
                text += f"{status} <code>{u['username']}</code> â€” expira: {exp}\n"
                buttons.append([InlineKeyboardButton(
                    f"ðŸ‘¤ {u['username']}", callback_data=f"k_ssh_detail:{u['username']}")])
            if len(users) > 15:
                text += f"\n... y {len(users) - 15} mas"
        else:
            text += "ðŸ“­ <b>Sin cuentas SSH</b>\n"
            buttons = []

        buttons.append([InlineKeyboardButton("ðŸ”„ Actualizar", callback_data="k_ssh")])
        buttons.append([InlineKeyboardButton("ðŸ”™ Volver", callback_data="k_back")])

        await query.edit_message_text(text, parse_mode=ParseMode.HTML,
            reply_markup=InlineKeyboardMarkup(buttons))

    except Exception as e:
        logger.error(f"SSH menu error: {e}")
        await query.edit_message_text(f"âŒ Error: <code>{e}</code>", parse_mode=ParseMode.HTML,
            reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("ðŸ”™ Volver", callback_data="k_back")]]))

    return K_MAIN


async def ssh_del_confirm(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Confirm SSH account deletion (removes SSH + Xray + ZipVPN)."""
    query = update.callback_query
    username = query.data.split(":", 1)[1]
    context.user_data["ssh_del_user"] = username

    text = (
        f"âš ï¸ <b>Confirmar EliminaciÃ³n</b>\n{brand_divider()}\n\n"
        f"Vas a eliminar la cuenta SSH:\n"
        f"ðŸ‘¤ <code>{username}</code>\n\n"
        f"âš¡ Se eliminarÃ¡:\n"
        f"  ðŸ”¹ Cuenta SSH (user + procesos)\n"
        f"  ðŸ”¹ Cliente Xray\n"
        f"  ðŸ”¹ Clave ZipVPN\n"
        f"  ðŸ”¹ LÃ­mites de consumo\n\n"
        f"ðŸš¨ <b>ESTA ACCIÃ“N NO SE PUEDE DESHACER</b>")

    kb = InlineKeyboardMarkup([
        [InlineKeyboardButton(f"âœ… SÃ­, borrar {username}", callback_data="k_ssh_del_go"),
         InlineKeyboardButton("âŒ Cancelar", callback_data="k_ssh")]])

    await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=kb)
    return K_MAIN


async def ssh_del_go(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Execute SSH account deletion."""
    query = update.callback_query
    username = context.user_data.get("ssh_del_user", "")

    if not username:
        await query.answer("Error: usuario no encontrado", show_alert=True)
        return K_MAIN

    await query.edit_message_text(
        f"ðŸ”„ <b>Eliminando cuenta SSH...</b>\n{brand_divider()}\n\n"
        f"ðŸ‘¤ <code>{username}</code>\n"
        f"â³ Borrando SSH + Xray + ZipVPN...",
        parse_mode=ParseMode.HTML)

    try:
        import asyncio
        loop = asyncio.get_event_loop()
        from ssh_utils import delete_ssh_on_vps
        ok = await loop.run_in_executor(None, lambda: delete_ssh_on_vps(username))

        if ok:
            text = (
                f"âœ… <b>Cuenta Eliminada</b>\n{brand_divider()}\n\n"
                f"ðŸ‘¤ <code>{username}</code>\n\n"
                f"âš¡ Eliminado:\n"
                f"  âœ… Cuenta SSH\n"
                f"  âœ… Cliente Xray\n"
                f"  âœ… Clave ZipVPN\n"
                f"  âœ… LÃ­mites de consumo")
        else:
            text = f"âŒ Error al eliminar la cuenta <code>{username}</code>"

        kb = InlineKeyboardMarkup([
            [InlineKeyboardButton("ðŸ‘¥ Ver Cuentas", callback_data="k_ssh")],
            [InlineKeyboardButton("ðŸ  MenÃº", callback_data="k_back")]])

        await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=kb)

    except Exception as e:
        logger.error(f"SSH delete error: {e}")
        await query.edit_message_text(f"âŒ Error: <code>{e}</code>", parse_mode=ParseMode.HTML,
            reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("ðŸ”™ Volver", callback_data="k_ssh")]]))

    context.user_data.pop("ssh_del_user", None)
    return K_MAIN


# =============================================================================
# SSH - DETAIL + RENEW
# =============================================================================
async def show_ssh_detail(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Show SSH account detail with renew/delete options."""
    query = update.callback_query
    username = query.data.split(":", 1)[1]

    try:
        import asyncio
        loop = asyncio.get_event_loop()
        from ssh_utils import _vps_exec

        # Get info from VPS
        info_out, _ = await loop.run_in_executor(None, lambda: _vps_exec(
            f"getent passwd {username} | cut -d: -f8"
        ))
        exp_raw = (info_out or "").strip()

        # Get GB from ZipVPN limits
        gb_out, _ = await loop.run_in_executor(None, lambda: _vps_exec(
            f"grep '{username}' /etc/zivpn/limites.conf 2>/dev/null | cut -d'|' -f2"
        ))
        gb_zipvpn = (gb_out or "").strip()

        # Get SSH consumption limit
        from ssh_utils import get_user_limit
        gb_limit = await loop.run_in_executor(None, lambda: get_user_limit(username))

        text = (
            f"ðŸ‘¤ <b>CUENTA SSH â€” {username}</b>\n{brand_divider()}\n\n"
            f"ðŸ“… Expira: <code>{exp_raw or 'sin fecha'}</code>\n"
            f"ðŸ“¦ LÃ­mite GB (consumo): <b>{gb_limit if gb_limit > 0 else 'â™¾ Sin lÃ­mite'}</b>\n"
            f"ðŸ” ZipVPN GB: <b>{gb_zipvpn or '0 (sin lÃ­mite)'}</b>\n\n"
            f"âš¡ Selecciona una acciÃ³n:"
        )

        buttons = [
            [InlineKeyboardButton("ðŸ“¦ Editar lÃ­mite GB", callback_data=f"k_ssh_edit_limit:{username}")],
            [InlineKeyboardButton("ðŸ”„ Renovar dÃ­as", callback_data=f"k_ssh_renew:{username}")],
            [InlineKeyboardButton("âŒ Eliminar cuenta", callback_data=f"k_ssh_del:{username}")],
            [InlineKeyboardButton("ðŸ”™ Volver", callback_data="k_ssh")]
        ]

        await query.edit_message_text(text, parse_mode=ParseMode.HTML,
            reply_markup=InlineKeyboardMarkup(buttons))

    except Exception as e:
        logger.error(f"SSH detail error: {e}")
        await query.edit_message_text(f"âŒ Error: <code>{e}</code>", parse_mode=ParseMode.HTML,
            reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("ðŸ”™ Volver", callback_data="k_ssh")]]))

    return K_SSH_DETAIL


async def show_ssh_renew(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Show day options for SSH account renewal."""
    query = update.callback_query
    username = query.data.split(":", 1)[1]
    context.user_data["ssh_renew_user"] = username

    buttons = [
        [InlineKeyboardButton("+1 dÃ­a", callback_data=f"k_ssh_renew_go:{username}:1"),
         InlineKeyboardButton("+3 dÃ­as", callback_data=f"k_ssh_renew_go:{username}:3"),
         InlineKeyboardButton("+7 dÃ­as", callback_data=f"k_ssh_renew_go:{username}:7")],
        [InlineKeyboardButton("+15 dÃ­as", callback_data=f"k_ssh_renew_go:{username}:15"),
         InlineKeyboardButton("+30 dÃ­as", callback_data=f"k_ssh_renew_go:{username}:30")],
        [InlineKeyboardButton("ðŸ”™ Cancelar", callback_data=f"k_ssh_detail:{username}")]
    ]

    text = (
        f"ðŸ”„ <b>RENOVAR â€” {username}</b>\n{brand_divider()}\n\n"
        f"â° CuÃ¡ntos dÃ­as quieres agregar?"
    )

    await query.edit_message_text(text, parse_mode=ParseMode.HTML,
        reply_markup=InlineKeyboardMarkup(buttons))

    return K_SSH_RENEW


async def do_ssh_renew(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Execute SSH account renewal on VPS."""
    query = update.callback_query
    parts = query.data.split(":")
    username = parts[1]
    days = int(parts[2])

    try:
        import asyncio
        loop = asyncio.get_event_loop()
        from ssh_utils import _vps_exec

        # Get current expiry
        info_out, _ = await loop.run_in_executor(None, lambda: _vps_exec(
            f"getent passwd {username} | cut -d: -f8"
        ))
        exp_raw = (info_out or "").strip()

        # Calculate new expiry
        if exp_raw and len(exp_raw) == 10:
            import datetime
            old_date = datetime.date.fromisoformat(exp_raw)
            if old_date < datetime.date.today():
                new_date = datetime.date.today() + datetime.timedelta(days=days)
            else:
                new_date = old_date + datetime.timedelta(days=days)
        else:
            import datetime
            new_date = datetime.date.today() + datetime.timedelta(days=days)

        new_exp = str(new_date)

        # Update on VPS
        await loop.run_in_executor(None, lambda: _vps_exec(f"usermod -e {new_exp} {username}"))

        # Update in SQLite DB if user exists there
        try:
            db.execute("UPDATE system_users SET expires_at=?, status='active' WHERE username=?", (new_exp, username))
        except:
            pass

        text = (
            f"âœ… <b>CUENTA RENOVADA</b>\n{brand_divider()}\n\n"
            f"ðŸ‘¤ <code>{username}</code>\n"
            f"â° DÃ­as agregados: <b>+{days}</b>\n"
            f"ðŸ“… Nueva expiraciÃ³n: <b>{new_exp}</b>"
        )

        buttons = [
            [InlineKeyboardButton("ðŸ‘¤ Ver detalle", callback_data=f"k_ssh_detail:{username}")],
            [InlineKeyboardButton("ðŸ‘¥ Ver cuentas", callback_data="k_ssh")],
            [InlineKeyboardButton("ðŸ  MenÃº", callback_data="k_back")]
        ]

        await query.edit_message_text(text, parse_mode=ParseMode.HTML,
            reply_markup=InlineKeyboardMarkup(buttons))

        log_audit(query.from_user.id, "ssh_renew", f"user={username} +{days}d")

    except Exception as e:
        logger.error(f"SSH renew error: {e}")
        await query.edit_message_text(f"âŒ Error al renovar: <code>{e}</code>", parse_mode=ParseMode.HTML,
            reply_markup=InlineKeyboardMarkup([
                [InlineKeyboardButton("ðŸ”™ Volver", callback_data=f"k_ssh_detail:{username}")]
            ]))

    context.user_data.pop("ssh_renew_user", None)
    return K_MAIN


# =============================================================================
# SSH - EDIT GB LIMIT
# =============================================================================
async def show_ssh_edit_limit(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Show options for editing GB limit."""
    query = update.callback_query
    username = query.data.split(":", 1)[1]
    context.user_data["ssh_edit_limit_user"] = username

    buttons = [
        [InlineKeyboardButton("â™¾ Sin lÃ­mite", callback_data=f"k_ssh_set_limit:{username}:0")],
        [InlineKeyboardButton("1 GB", callback_data=f"k_ssh_set_limit:{username}:1"),
         InlineKeyboardButton("2 GB", callback_data=f"k_ssh_set_limit:{username}:2"),
         InlineKeyboardButton("3 GB", callback_data=f"k_ssh_set_limit:{username}:3")],
        [InlineKeyboardButton("5 GB", callback_data=f"k_ssh_set_limit:{username}:5"),
         InlineKeyboardButton("10 GB", callback_data=f"k_ssh_set_limit:{username}:10"),
         InlineKeyboardButton("15 GB", callback_data=f"k_ssh_set_limit:{username}:15")],
        [InlineKeyboardButton("20 GB", callback_data=f"k_ssh_set_limit:{username}:20"),
         InlineKeyboardButton("30 GB", callback_data=f"k_ssh_set_limit:{username}:30"),
         InlineKeyboardButton("50 GB", callback_data=f"k_ssh_set_limit:{username}:50")],
        [InlineKeyboardButton("âœï¸ Cantidad personalizada", callback_data=f"k_ssh_custom_limit:{username}")],
        [InlineKeyboardButton("ðŸ”™ Cancelar", callback_data=f"k_ssh_detail:{username}")]
    ]

    text = (
        f"ðŸ“¦ <b>EDITAR LÃMITE GB â€” {username}</b>\n{brand_divider()}\n\n"
        f"âš¡ Selecciona el nuevo lÃ­mite de consumo:"
    )

    await query.edit_message_text(text, parse_mode=ParseMode.HTML,
        reply_markup=InlineKeyboardMarkup(buttons))

    return K_SSH_EDIT_LIMIT


async def do_ssh_set_limit(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Execute GB limit change."""
    query = update.callback_query
    parts = query.data.split(":")
    username = parts[1]
    gb = int(parts[2])

    try:
        import asyncio
        loop = asyncio.get_event_loop()
        from ssh_utils import set_user_limit, set_zipvpn_limit

        # Set SSH consumption limit
        ok1 = await loop.run_in_executor(None, lambda: set_user_limit(username, gb))
        # Set ZipVPN limit too
        ok2 = await loop.run_in_executor(None, lambda: set_zipvpn_limit(username, gb))

        if gb > 0:
            gb_str = f"{gb} GB"
        else:
            gb_str = "â™¾ Sin lÃ­mite (ilimitado)"

        text = (
            f"âœ… <b>LÃMITE ACTUALIZADO</b>\n{brand_divider()}\n\n"
            f"ðŸ‘¤ <code>{username}</code>\n"
            f"ðŸ“¦ Nuevo lÃ­mite: <b>{gb_str}</b>\n\n"
            f"{'âœ… LÃ­mite SSH actualizado' if ok1 else 'âš ï¸ Error SSH'}\n"
            f"{'âœ… LÃ­mite ZipVPN actualizado' if ok2 else 'âš ï¸ Error ZipVPN'}"
        )

        buttons = [
            [InlineKeyboardButton("ðŸ‘¤ Ver detalle", callback_data=f"k_ssh_detail:{username}")],
            [InlineKeyboardButton("ðŸ‘¥ Ver cuentas", callback_data="k_ssh")],
            [InlineKeyboardButton("ðŸ  MenÃº", callback_data="k_back")]
        ]

        await query.edit_message_text(text, parse_mode=ParseMode.HTML,
            reply_markup=InlineKeyboardMarkup(buttons))

        log_audit(query.from_user.id, "ssh_set_limit", f"user={username} gb={gb}")

    except Exception as e:
        logger.error(f"SSH set limit error: {e}")
        await query.edit_message_text(f"âŒ Error: <code>{e}</code>", parse_mode=ParseMode.HTML,
            reply_markup=InlineKeyboardMarkup([
                [InlineKeyboardButton("ðŸ”™ Volver", callback_data=f"k_ssh_detail:{username}")]
            ]))

    return K_MAIN


async def ssh_custom_limit_input(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Handle custom GB limit text input."""
    query = update.callback_query
    username = query.data.split(":", 1)[1]
    context.user_data["ssh_edit_limit_user"] = username

    text = (
        f"âœï¸ <b>CANTIDAD PERSONALIZADA â€” {username}</b>\n{brand_divider()}\n\n"
        f"ðŸ“ Escribe la cantidad de GB:\n"
        f"   (ejemplo: <code>7.5</code> para 7.5 GB, o <code>0</code> para sin lÃ­mite)"
    )

    buttons = InlineKeyboardMarkup([
        [InlineKeyboardButton("âŒ Cancelar", callback_data=f"k_ssh_detail:{username}")]
    ])

    await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=buttons)

    return K_SSH_EDIT_LIMIT


async def ssh_custom_limit_save(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Save custom GB limit from text input."""
    text_input = update.message.text.strip()
    username = context.user_data.get("ssh_edit_limit_user", "")

    if not username:
        await update.message.reply_text("âŒ Error: usuario no encontrado.")
        return K_MAIN

    try:
        gb = float(text_input)
        if gb < 0:
            raise ValueError("negative")
    except ValueError:
        await update.message.reply_text(
            f"âŒ NÃºmero invÃ¡lido: <code>{text_input}</code>\n"
            f"Escribe un nÃºmero (ej: 5, 7.5, 0 para sin lÃ­mite):",
            parse_mode=ParseMode.HTML
        )
        return K_SSH_EDIT_LIMIT

    try:
        import asyncio
        loop = asyncio.get_event_loop()
        from ssh_utils import set_user_limit, set_zipvpn_limit

        gb_int = int(gb) if gb == int(gb) else gb
        ok1 = await loop.run_in_executor(None, lambda: set_user_limit(username, gb_int))
        ok2 = await loop.run_in_executor(None, lambda: set_zipvpn_limit(username, gb_int))

        gb_str = f"{gb_int} GB" if gb_int > 0 else "â™¾ Sin lÃ­mite"

        msg = (
            f"âœ… <b>LÃMITE ACTUALIZADO</b>\n\n"
            f"ðŸ‘¤ <code>{username}</code>\n"
            f"ðŸ“¦ Nuevo lÃ­mite: <b>{gb_str}</b>"
        )

        kb = InlineKeyboardMarkup([
            [InlineKeyboardButton("ðŸ‘¤ Ver detalle", callback_data=f"k_ssh_detail:{username}")],
            [InlineKeyboardButton("ðŸ‘¥ Ver cuentas", callback_data="k_ssh")],
            [InlineKeyboardButton("ðŸ  MenÃº", callback_data="k_back")]
        ])

        await update.message.reply_text(msg, parse_mode=ParseMode.HTML, reply_markup=kb)
        log_audit(update.effective_user.id, "ssh_set_limit", f"user={username} gb={gb_int}")

    except Exception as e:
        logger.error(f"SSH custom limit error: {e}")
        await update.message.reply_text(f"âŒ Error: <code>{e}</code>", parse_mode=ParseMode.HTML)

    return K_MAIN


# =============================================================================
# ZIPVPN - MENU DE GESTION
# =============================================================================
async def show_zipvpn_menu(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    user_id = query.from_user.id
    brand = get_admin_brand(user_id)

    await query.edit_message_text(
        f"ðŸ” <b>ZipVPN â€” Gestion de Claves</b>\n{brand_divider()}\n\n"
        "â³ Consultando claves en VPS...",
        parse_mode=ParseMode.HTML,
    )

    try:
        import functools
        loop = asyncio.get_event_loop()
        from ssh_utils import zipvpn_list
        users = await loop.run_in_executor(None, zipvpn_list)

        text = f"ðŸ” <b>ZipVPN â€” Claves Activas</b>\n{brand_divider()}\n\n"

        if users:
            text += f"ðŸ“Š <b>Total:</b> {len(users)} claves\n\n"
            for u in users[:20]:  # Max 20 shown
                status = "âœ…" if u.get('active', True) else "âŒ"
                days_left = u.get('days_left', '?')
                text += f"{status} <code>{u['password']}</code> â€” {days_left}d\n"
            if len(users) > 20:
                text += f"\n... y {len(users) - 20} mas"
        else:
            text += "ðŸ“­ No hay claves registradas\n\nLas claves se agregan automaticamente\nal crear cuentas SSH."

        kb = InlineKeyboardMarkup([
            [InlineKeyboardButton("âž• Agregar clave", callback_data="k_zipvpn_add"),
             InlineKeyboardButton("âž– Eliminar", callback_data="k_zipvpn_del")],
            [InlineKeyboardButton("ðŸ”„ Actualizar", callback_data="k_zipvpn")],
            [InlineKeyboardButton("ðŸ”™ Volver", callback_data="k_back")],
        ])

        await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=kb)

    except Exception as e:
        logger.error(f"ZipVPN menu error: {e}")
        await query.edit_message_text(
            f"ðŸ” <b>ZipVPN</b>\n{brand_divider()}\n\n"
            f"âŒ Error: <code>{e}</code>",
            parse_mode=ParseMode.HTML,
            reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("ðŸ”™ Volver", callback_data="k_back")]])
        )

    return K_MAIN

# =============================================================================
# ZIPVPN - PROCESAR INPUT (agregar/eliminar)
# =============================================================================
async def zipvpn_input_handler(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    text = update.message.text.strip()
    mode = context.user_data.get("zipvpn_mode", "add")

    try:
        import asyncio
        loop = asyncio.get_event_loop()
        if mode == "add":
            from ssh_utils import zipvpn_add
            # Agregar sin expiracion (0 dias = unlimited)
            result = await loop.run_in_executor(None, lambda: zipvpn_add(text, 0))
            if result:
                await update.message.reply_text(
                    f"âœ… Clave <code>{text}</code> agregada a ZipVPN\n"
                    f"â° Sin expiracion",
                    parse_mode=ParseMode.HTML,
                )
            else:
                await update.message.reply_text(f"âŒ Error al agregar la clave")
        else:
            from ssh_utils import zipvpn_remove
            result = await loop.run_in_executor(None, lambda: zipvpn_remove(text))
            if result:
                await update.message.reply_text(
                    f"âœ… Clave <code>{text}</code> eliminada de ZipVPN",
                    parse_mode=ParseMode.HTML,
                )
            else:
                await update.message.reply_text(f"âŒ Error al eliminar la clave")
    except Exception as e:
        await update.message.reply_text(f"âŒ Error: <code>{e}</code>", parse_mode=ParseMode.HTML)

    # Volver al menu
    context.user_data.pop("zipvpn_mode", None)
    return K_MAIN

# =============================================================================
# XRAY - MENU DE GESTION COMPLETA
# =============================================================================
async def show_xray_menu(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    user_id = query.from_user.id
    brand = get_admin_brand(user_id)

    try:
        import asyncio
        loop = asyncio.get_event_loop()
        from ssh_utils import xray_list
        clients = await loop.run_in_executor(None, xray_list)

        text = f"ðŸŒ <b>Xray â€” Panel de Control</b>\n{brand_divider()}\n\n"

        if clients:
            text += f"ðŸ“Š <b>Total:</b> {len(clients)} cliente(s)\n\n"
            # Group by protocol
            by_proto = {}
            for c in clients:
                p = c["protocol"]
                if p not in by_proto:
                    by_proto[p] = []
                by_proto[p].append(c)

            for proto, clist in by_proto.items():
                text += f"ðŸ“¡ <b>{proto.upper()}</b> ({len(clist)})\n"
                for c in clist[:10]:
                    email = c["email"]
                    cid = c["id"][:8] + "..."
                    text += f"  â€¢ <code>{email}</code> â†’ <code>{cid}</code>\n"
                if len(clist) > 10:
                    text += f"  ... y {len(clist) - 10} mas\n"
                text += "\n"
        else:
            text += "ðŸ“­ <b>Sin clientes Xray</b>\n\n"

        kb = InlineKeyboardMarkup([
            [InlineKeyboardButton("âž• Agregar Cliente Xray", callback_data="k_xray_add"),
             InlineKeyboardButton("âž– Eliminar Cliente", callback_data="k_xray_del")],
            [InlineKeyboardButton("ðŸ”„ Refrescar", callback_data="k_xray"),
             InlineKeyboardButton("ðŸ”„ Reiniciar Xray", callback_data="k_xray_restart")],
            [InlineKeyboardButton("ðŸ”™ Volver", callback_data="k_back")],
        ])

        await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=kb)

    except Exception as e:
        logger.error(f"Xray menu error: {e}")
        await query.edit_message_text(
            f"ðŸŒ <b>Xray</b>\n{brand_divider()}\n\n"
            f"âŒ Error: <code>{e}</code>",
            parse_mode=ParseMode.HTML,
            reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("ðŸ”™ Volver", callback_data="k_back")]])
        )

    return K_MAIN

# =============================================================================
# XRAY - INPUT HANDLER (add/remove client)
# =============================================================================
async def xray_input_handler(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    text = update.message.text.strip()
    mode = context.user_data.get("xray_mode")

    try:
        import asyncio
        loop = asyncio.get_event_loop()

        if mode == "add":
            # Determine email and UUID
            if text.lower() == "auto":
                import uuid
                email = f"User_{uuid.uuid4().hex[:6].upper()}"
                client_id = str(uuid.uuid4())
            else:
                email = text
                import uuid
                client_id = str(uuid.uuid4())

            from ssh_utils import xray_add
            result = await loop.run_in_executor(None, lambda: xray_add(email, client_id))
            if result:
                await update.message.reply_text(
                    f"âœ… <b>Cliente Xray agregado</b>\n\n"
                    f"ðŸ“§ Email: <code>{email}</code>\n"
                    f"ðŸ”‘ UUID: <code>{client_id}</code>\n\n"
                    f"ðŸ”„ Xray se reiniciara automaticamente.",
                    parse_mode=ParseMode.HTML,
                )
            else:
                await update.message.reply_text(f"âŒ Error al agregar cliente Xray")
        elif mode == "del":
            from ssh_utils import xray_remove
            result = await loop.run_in_executor(None, lambda: xray_remove(text))
            if result:
                await update.message.reply_text(
                    f"âœ… Cliente <code>{text}</code> eliminado de Xray",
                    parse_mode=ParseMode.HTML,
                )
            else:
                await update.message.reply_text(f"âŒ Error al eliminar cliente Xray")
    except Exception as e:
        await update.message.reply_text(f"âŒ Error: <code>{e}</code>", parse_mode=ParseMode.HTML)

    context.user_data.pop("xray_mode", None)
    return K_MAIN

# =============================================================================
# XRAY ADD - MULTI-STEP FLOW (email â†’ days â†’ devices â†’ GB â†’ confirm â†’ vmess link)
# =============================================================================
async def xray_add_input_handler(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Handle text input for Xray add flow (email, GB limit)."""
    text = update.message.text.strip()
    step = context.user_data.get("xray_add_step")
    data = context.user_data.get("xray_add_data", {})

    if step == "email":
        if text.lower() == "auto":
            import uuid as _uuid
            email = f"User_{_uuid.uuid4().hex[:6].upper()}"
        else:
            email = text
        data["email"] = email
        context.user_data["xray_add_data"] = data
        kb = InlineKeyboardMarkup([
            [InlineKeyboardButton("1ï¸âƒ£ 1 DÃ­a", callback_data="k_xdays_1"),
             InlineKeyboardButton("3ï¸âƒ£ 3 DÃ­as", callback_data="k_xdays_3"),
             InlineKeyboardButton("7ï¸âƒ£ 7 DÃ­as", callback_data="k_xdays_7")],
            [InlineKeyboardButton("1ï¸âƒ£5ï¸âƒ£ 15 DÃ­as", callback_data="k_xdays_15"),
             InlineKeyboardButton("3ï¸âƒ£0ï¸âƒ£ 30 DÃ­as", callback_data="k_xdays_30")],
            [InlineKeyboardButton("ðŸ”™ Cancelar", callback_data="k_xray")],
        ])
        await update.message.reply_text(
            f"ðŸŒ <b>Agregar Cliente Xray</b>\n{brand_divider()}\n\n"
            f"âœ… Email: <code>{email}</code>\n\n"
            f"ðŸ“ Paso 2/5 â€” Selecciona <b>dÃ­as de vigencia</b>:",
            parse_mode=ParseMode.HTML, reply_markup=kb)
        context.user_data["xray_add_step"] = "days"
        return K_XRAY_ADD_MENU

    elif step == "gb":
        try:
            gb = int(text)
        except:
            gb = 0
        data["gb"] = gb
        context.user_data["xray_add_data"] = data
        return await _xray_show_confirm(update, context, data)

    return K_XRAY_ADD_INPUT


async def xray_add_menu_handler(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Handle callback selections for Xray add flow."""
    query = update.callback_query
    d = query.data
    data = context.user_data.get("xray_add_data", {})

    if d.startswith("k_xdays_"):
        data["days"] = int(d[8:])
        context.user_data["xray_add_data"] = data
        kb = InlineKeyboardMarkup([
            [InlineKeyboardButton("1 Dispositivo", callback_data="k_xdev_1"),
             InlineKeyboardButton("2 Dispositivos", callback_data="k_xdev_2"),
             InlineKeyboardButton("3 Dispositivos", callback_data="k_xdev_3")],
            [InlineKeyboardButton("5 Dispositivos", callback_data="k_xdev_5")],
            [InlineKeyboardButton("ðŸ”™ Cancelar", callback_data="k_xray")],
        ])
        await query.edit_message_text(
            f"ðŸŒ <b>Agregar Cliente Xray</b>\n{brand_divider()}\n\n"
            f"âœ… Email: <code>{data.get('email','')}</code>\n"
            f"âœ… DÃ­as: <b>{data['days']}</b>\n\n"
            f"ðŸ“ Paso 3/5 â€” Selecciona <b>max dispositivos</b>:",
            parse_mode=ParseMode.HTML, reply_markup=kb)
        context.user_data["xray_add_step"] = "devices"
        return K_XRAY_ADD_MENU

    elif d.startswith("k_xdev_"):
        data["devices"] = int(d[7:])
        context.user_data["xray_add_data"] = data
        await query.edit_message_text(
            f"ðŸŒ <b>Agregar Cliente Xray</b>\n{brand_divider()}\n\n"
            f"âœ… Email: <code>{data.get('email','')}</code>\n"
            f"âœ… DÃ­as: <b>{data.get('days',0)}</b>\n"
            f"âœ… Dispositivos: <b>{data['devices']}</b>\n\n"
            f"ðŸ“ Paso 4/5 â€” Envia el <b>lÃ­mite de GB</b>\n"
            f"(escribe <code>0</code> para sin lÃ­mite):",
            parse_mode=ParseMode.HTML,
            reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("ðŸ”™ Cancelar", callback_data="k_xray")]]))
        context.user_data["xray_add_step"] = "gb"
        return K_XRAY_ADD_INPUT

    elif d == "k_xconfirm":
        return await _xray_do_create(update, context, data)

    elif d == "k_xray":
        context.user_data.pop("xray_add_step", None)
        context.user_data.pop("xray_add_data", None)
        return await show_xray_menu(update, context)

    return K_XRAY_ADD_MENU


async def _xray_show_confirm(update, context, data):
    """Show confirmation before creating Xray client."""
    query = update.callback_query
    gb_text = f"{data.get('gb',0)} GB" if data.get('gb',0) > 0 else "Sin lÃ­mite"
    text = (
        f"ðŸŒ <b>Confirmar Cliente Xray</b>\n{brand_divider()}\n\n"
        f"â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”\n"
        f"â”‚ ðŸ“§ Email: <code>{data.get('email','?')}</code>\n"
        f"â”‚ â° DÃ­as: <b>{data.get('days',7)}</b>\n"
        f"â”‚ ðŸ“± Dispositivos: <b>{data.get('devices',1)}</b>\n"
        f"â”‚ ðŸ“Š GB: <b>{gb_text}</b>\n"
        f"â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜\n\n"
        f"âš¡ Se crearÃ¡ SSH + ZipVPN + Xray\n"
        f"ðŸ”— Se generarÃ¡ link <code>vmess://</code>\n\n"
        f"Â¿Confirmar?")
    kb = InlineKeyboardMarkup([
        [InlineKeyboardButton("âœ… Confirmar", callback_data="k_xconfirm"),
         InlineKeyboardButton("âŒ Cancelar", callback_data="k_xray")]])
    if query:
        await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=kb)
    else:
        await update.message.reply_text(text, parse_mode=ParseMode.HTML, reply_markup=kb)
    return K_XRAY_ADD_MENU


async def _xray_do_create(update, context, data):
    """Execute Xray client creation with SSH + ZipVPN + vmess link."""
    query = update.callback_query
    await query.edit_message_text(
        f"ðŸŒ <b>Creando cliente Xray...</b>\n{brand_divider()}\n\nâ³ Configurando SSH + ZipVPN + Xray...",
        parse_mode=ParseMode.HTML)

    email = data.get("email", "")
    days = data.get("days", 7)
    devices = data.get("devices", 1)
    gb = data.get("gb", 0)

    import random, string
    password = ''.join(random.choices(string.ascii_letters + string.digits, k=12))

    try:
        import asyncio
        loop = asyncio.get_event_loop()

        from ssh_utils import create_ssh_on_vps
        ok = await loop.run_in_executor(None, lambda: create_ssh_on_vps(
            email, password, days, devices, 0, "xray", brand=MY_BRAND,
            plan_type="premium", gb_zipvpn=gb))

        if not ok:
            await query.edit_message_text("âŒ Error creando cuenta Xray", parse_mode=ParseMode.HTML,
                reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("ðŸ”™ Volver", callback_data="k_xray")]]))
            context.user_data.pop("xray_add_step", None)
            context.user_data.pop("xray_add_data", None)
            return K_MAIN

        from ssh_utils import _vps_exec
        uuid_out, _ = await loop.run_in_executor(None, lambda: _vps_exec(
            f"jq -r '.inbounds[].settings.clients[] | select(.email | startswith(\"{email}\")) | .id' /usr/local/etc/xray/config.json"))
        client_id = (uuid_out or "").strip() if uuid_out else ""

        from config import VPS_SUBDOMAIN
        import json, base64
        vmess_obj = {"v":"2","ps":f"{BRAND_NAME}-{email}","add":VPS_SUBDOMAIN,"port":"443",
                     "id":client_id,"aid":"0","scy":"auto","net":"ws","type":"none",
                     "host":VPS_SUBDOMAIN,"path":"/vmess","tls":"tls","sni":VPS_SUBDOMAIN,"fp":"chrome"}
        vmess_b64 = base64.b64encode(json.dumps(vmess_obj, separators=(',',':')).encode()).decode()
        vmess_link = f"vmess://{vmess_b64}"

        from datetime import datetime, timedelta
        exp_str = (datetime.now() + timedelta(days=days)).strftime("%d/%m/%Y")
        gb_text = f"{gb} GB" if gb > 0 else "Sin lÃ­mite"

        text = (
            f"âœ… <b>Cliente Xray Creado</b>\n{brand_divider()}\n\n"
            f"â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”\n"
            f"â”‚ ðŸ“§ Email: <code>{email}</code>\n"
            f"â”‚ ðŸ”‘ Pass: <code>{password}</code>\n"
            f"â”‚ ðŸ”‘ UUID: <code>{client_id}</code>\n"
            f"â”‚ â° Expira: <b>{exp_str}</b> ({days}d)\n"
            f"â”‚ ðŸ“± Dispositivos: <b>{devices}</b>\n"
            f"â”‚ ðŸ“Š GB: <b>{gb_text}</b>\n"
            f"â”‚ ðŸŒ Server: <code>{VPS_SUBDOMAIN}</code>\n"
            f"â”‚ ðŸ”Œ Puerto: <code>443</code>\n"
            f"â”‚ ðŸ”— Protocolo: <code>VMess WS TLS</code>\n"
            f"â”‚ ðŸ“ Path: <code>/vmess</code>\n"
            f"â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜\n\n"
            f"ðŸ”— <b>Link vmess://</b> (copia e importa):\n"
            f"<code>{vmess_link}</code>")

        kb = InlineKeyboardMarkup([
            [InlineKeyboardButton("ðŸ“‹ Copiar Link", callback_data="k_xray_copy")],
            [InlineKeyboardButton("ðŸŒ Ver en Xray", callback_data="k_xray")],
            [InlineKeyboardButton("ðŸ  MenÃº", callback_data="k_back")]])
        context.user_data["xray_link"] = vmess_link
        await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=kb)

    except Exception as e:
        logger.error(f"Xray create error: {e}")
        await query.edit_message_text(f"âŒ Error: <code>{e}</code>", parse_mode=ParseMode.HTML,
            reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("ðŸ”™ Volver", callback_data="k_xray")]]))

    context.user_data.pop("xray_add_step", None)
    context.user_data.pop("xray_add_data", None)
    return K_MAIN


# =============================================================================
# ZIPVPN ADD - MULTI-STEP FLOW (password â†’ days â†’ GB â†’ confirm)
# =============================================================================
async def zipvpn_add_menu_handler(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Handle ZipVPN add flow steps."""
    query = update.callback_query
    d = query.data
    data = context.user_data.get("zipvpn_add_data", {})
    step = context.user_data.get("zipvpn_add_step")

    # Text input steps (password, gb) are handled by zipvpn_add_text_handler
    if step == "password":
        # This shouldn't happen here (text goes to message handler)
        return K_ZIPVPN_ADD_MENU

    if d.startswith("k_zdays_"):
        data["days"] = int(d[8:])
        context.user_data["zipvpn_add_data"] = data
        await query.edit_message_text(
            f"ðŸ” <b>Agregar Clave ZipVPN</b>\n{brand_divider()}\n\n"
            f"âœ… ContraseÃ±a: <code>{data.get('password','')}</code>\n"
            f"âœ… DÃ­as: <b>{data['days']}</b>\n\n"
            f"ðŸ“ Paso 3/3 â€” Envia el <b>lÃ­mite de GB</b>\n"
            f"(escribe <code>0</code> para sin lÃ­mite):",
            parse_mode=ParseMode.HTML,
            reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("ðŸ”™ Cancelar", callback_data="k_zipvpn")]]))
        context.user_data["zipvpn_add_step"] = "gb"
        return K_ZIPVPN_ADD_MENU

    elif d == "k_zconfirm":
        return await _zipvpn_do_add(update, context, data)

    elif d == "k_zipvpn":
        context.user_data.pop("zipvpn_add_step", None)
        context.user_data.pop("zipvpn_add_data", None)
        return await show_zipvpn_menu(update, context)

    return K_ZIPVPN_ADD_MENU


async def zipvpn_add_text_handler(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Handle text input for ZipVPN add (password, GB)."""
    text = update.message.text.strip()
    step = context.user_data.get("zipvpn_add_step")
    data = context.user_data.get("zipvpn_add_data", {})

    if step == "password":
        data["password"] = text
        context.user_data["zipvpn_add_data"] = data
        kb = InlineKeyboardMarkup([
            [InlineKeyboardButton("1ï¸âƒ£ 1 DÃ­a", callback_data="k_zdays_1"),
             InlineKeyboardButton("3ï¸âƒ£ 3 DÃ­as", callback_data="k_zdays_3"),
             InlineKeyboardButton("7ï¸âƒ£ 7 DÃ­as", callback_data="k_zdays_7")],
            [InlineKeyboardButton("1ï¸âƒ£5ï¸âƒ£ 15 DÃ­as", callback_data="k_zdays_15"),
             InlineKeyboardButton("3ï¸âƒ£0ï¸âƒ£ 30 DÃ­as", callback_data="k_zdays_30")],
            [InlineKeyboardButton("ðŸ”™ Cancelar", callback_data="k_zipvpn")]])
        await update.message.reply_text(
            f"ðŸ” <b>Agregar Clave ZipVPN</b>\n{brand_divider()}\n\n"
            f"âœ… ContraseÃ±a: <code>{text}</code>\n\n"
            f"ðŸ“ Paso 2/3 â€” Selecciona <b>dÃ­as de vigencia</b>:",
            parse_mode=ParseMode.HTML, reply_markup=kb)
        context.user_data["zipvpn_add_step"] = "days"
        return K_ZIPVPN_ADD_MENU

    elif step == "gb":
        try:
            gb = int(text)
        except:
            gb = 0
        data["gb"] = gb
        context.user_data["zipvpn_add_data"] = data
        # Show confirm
        days = data.get("days", 7)
        gb_text = f"{gb} GB" if gb > 0 else "Sin lÃ­mite"
        kb = InlineKeyboardMarkup([
            [InlineKeyboardButton("âœ… Confirmar", callback_data="k_zconfirm"),
             InlineKeyboardButton("âŒ Cancelar", callback_data="k_zipvpn")]])
        await update.message.reply_text(
            f"ðŸ” <b>Confirmar Clave ZipVPN</b>\n{brand_divider()}\n\n"
            f"â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”\n"
            f"â”‚ ðŸ” ContraseÃ±a: <code>{data.get('password','')}</code>\n"
            f"â”‚ â° DÃ­as: <b>{days}</b>\n"
            f"â”‚ ðŸ“Š GB: <b>{gb_text}</b>\n"
            f"â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜\n\n"
            f"Â¿Confirmar?",
            parse_mode=ParseMode.HTML, reply_markup=kb)
        return K_ZIPVPN_ADD_MENU

    return K_ZIPVPN_ADD_MENU


async def _zipvpn_do_add(update, context, data):
    """Execute ZipVPN key addition."""
    query = update.callback_query
    password = data.get("password", "")
    days = data.get("days", 7)
    gb = data.get("gb", 0)

    await query.edit_message_text(
        f"ðŸ” <b>Agregando clave ZipVPN...</b>\n{brand_divider()}\nâ³ Configurando <code>{password}</code>...",
        parse_mode=ParseMode.HTML)

    try:
        import asyncio
        loop = asyncio.get_event_loop()
        from ssh_utils import zipvpn_add
        result = await loop.run_in_executor(None, lambda: zipvpn_add(password, days, gb))

        if result:
            from datetime import datetime, timedelta
            exp_str = (datetime.now() + timedelta(days=days)).strftime("%d/%m/%Y")
            gb_text = f"{gb} GB" if gb > 0 else "Sin lÃ­mite"
            text = (
                f"âœ… <b>Clave ZipVPN Agregada</b>\n{brand_divider()}\n\n"
                f"â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”\n"
                f"â”‚ ðŸ” ContraseÃ±a: <code>{password}</code>\n"
                f"â”‚ â° Expira: <b>{exp_str}</b> ({days}d)\n"
                f"â”‚ ðŸ“Š GB: <b>{gb_text}</b>\n"
                f"â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜\n\n"
                f"â„¹ï¸ Usa esta contraseÃ±a para conectarte\n"
                f"con el cliente ZipVPN (ZiVpn).")
        else:
            text = "âŒ Error al agregar la clave ZipVPN"

        kb = InlineKeyboardMarkup([
            [InlineKeyboardButton("ðŸ” Ver Claves", callback_data="k_zipvpn")],
            [InlineKeyboardButton("ðŸ  MenÃº", callback_data="k_back")]])
        await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=kb)

    except Exception as e:
        await query.edit_message_text(f"âŒ Error: <code>{e}</code>", parse_mode=ParseMode.HTML,
            reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("ðŸ”™ Volver", callback_data="k_zipvpn")]]))

    context.user_data.pop("zipvpn_add_step", None)
    context.user_data.pop("zipvpn_add_data", None)
    return K_MAIN

# =============================================================================
# SLOWDNS - MOSTRAR PUBLIC KEY
# =============================================================================
async def show_slowdns_key(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    user_id = query.from_user.id
    brand = get_admin_brand(user_id)

    await query.edit_message_text(
        f"ðŸ”‘ <b>Clave SlowDNS</b>\n{brand_divider()}\n\n"
        "â³ Consultando VPS...",
        parse_mode=ParseMode.HTML,
    )

    try:
        from ssh_utils import get_slowdns_key
        import asyncio

        loop = asyncio.get_event_loop()
        key = await loop.run_in_executor(None, get_slowdns_key)

        if key:
            text = (
                f"ðŸ”‘ <b>Clave Publica SlowDNS</b>\n{brand_divider()}\n\n"
                f"<code>{key}</code>\n\n"
                f"ðŸ“‹ Copia esta clave en tu cliente SlowDNS\n"
                f"o compartela con tus clientes para que se configuren."
            )
        else:
            text = (
                f"ðŸ”‘ <b>SlowDNS</b>\n{brand_divider()}\n\n"
                "âš ï¸ No se encontro la clave publica.\n\n"
                "SlowDNS podria no estar instalado en este VPS,\n"
                "o el archivo <code>/etc/slowdns/server.pub</code> no existe."
            )

        kb = InlineKeyboardMarkup([
            [InlineKeyboardButton("ðŸ“‹ Copiar clave", callback_data="k_slowdns_copy")],
            [InlineKeyboardButton("ðŸ”™ Volver", callback_data="k_back")],
        ])

        await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=kb)

        # Store key in context for copy button
        context.user_data["slowdns_key"] = key or ""

    except Exception as e:
        logger.error(f"SlowDNS key error: {e}")
        await query.edit_message_text(
            f"ðŸ”‘ <b>SlowDNS</b>\n{brand_divider()}\n\n"
            f"âŒ Error al consultar: <code>{e}</code>",
            parse_mode=ParseMode.HTML,
            reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("ðŸ”™ Volver", callback_data="k_back")]])
        )

    return K_MAIN

# =============================================================================
# ESTADISTICAS - VPS REAL-TIME
# =============================================================================
async def show_stats(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    user_id = query.from_user.id
    brand = get_admin_brand(user_id)

    await query.edit_message_text("ðŸ“Š <b>Cargando estadÃ­sticas del VPS...</b>\n" + brand_divider() + "\nâ³ Consultando servidor...", parse_mode=ParseMode.HTML)

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

    text = f"""ðŸŒ <b>ESTADO VPS - {BRAND_NAME}</b>
{brand_divider()}

â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
â”‚ ðŸ–¥ <b>ESTADO DEL SERVIDOR</b>
â”œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¤
â”‚ ðŸ§  CPU: <b>{vps['cpu']}%</b>
â”‚ ðŸŸ¢ RAM: <b>{vps['ram']}</b>
â”‚ ðŸ’¾ Disco: <b>{vps['disk']}</b>
â”‚ â± Uptime: <b>{vps['uptime']}</b>
â”‚ âš–ï¸ Load: <b>{vps['load']}</b>
â”‚ ðŸ“¥ Net In: <b>{vps['net_in']}</b>
â”‚ ðŸ“¤ Net Out: <b>{vps['net_out']}</b>
â”‚ ðŸ”Œ SSH Sessions: <b>{vps['ssh_sessions']}</b>
â”‚ âš™ï¸ Services Up: <b>{vps['services_up']}</b>
â”‚ ðŸ‘¤ VPS Users: <b>{vps['vps_users']}</b>
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜

â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
â”‚ ðŸ“Š <b>USUARIOS {brand.upper()}</b>
â”œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¤
â”‚ ðŸ‘¥ Total: <b>{stats['total'] or 0}</b>
â”‚ âœ… Activos: <b>{stats['active'] or 0}</b>
â”‚ âŒ Expirados: <b>{stats['expired'] or 0}</b>
â”‚ â° Por expirar: <b>{stats['expiring'] or 0}</b>
â”‚ ðŸŽ Trials: <b>{stats['trials'] or 0}</b>
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜"""

    if per_op:
        text += "\n\nâ”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”\nâ”‚ ðŸ“¡ <b>POR OPERADOR</b>\nâ”œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¤\n"
        for r in per_op:
            op_cfg = OPERATORS.get(r['operator'], {})
            flag = op_cfg.get('flag', '')
            text += f"â”‚ {flag} {r['operator'].upper()}: <b>{r['cnt']}</b>\n"
        text += "â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜"

    kb = InlineKeyboardMarkup([
        [InlineKeyboardButton("ðŸ”„ Actualizar Stats", callback_data="k_stats")],
        [InlineKeyboardButton("ðŸ”™ Volver", callback_data="k_back")],
    ])
    await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=kb)
    return K_MAIN

# =============================================================================
# IMPORTS + MAIN
# =============================================================================
from ssh_utils import create_ssh_account, delete_ssh_on_vps

async def post_init(application: Application):
    await application.bot.set_my_commands([BotCommand("start", "Panel {BRAND_NAME}")])
    # Sembrar el administrador autorizado (config.ADMIN_IDS) en la tabla admins.
    # Garantiza que la ID del dueno funcione aunque la DB arranque vacia.
    try:
        for admin_id in ADMIN_IDS:
            db.execute(
                "INSERT OR IGNORE INTO admins (tg_id, added_by, role, brand, permissions) "
                "VALUES (?, 0, 'superadmin', ?, '[\"all\"]')",
                (int(admin_id), MY_BRAND))
    except Exception as e:
        logger.error(f"Seed admin error: {e}")
    logger.info("{BRAND_NAME} Admin Bot v5 started!")

async def error_handler(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    logging.error(f"[ERROR] Exception while handling an update: {context.error}", exc_info=context.error)
    if update and update.callback_query:
        try:
            await update.callback_query.answer("âŒ Error procesando. Intenta de nuevo.", show_alert=True)
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
            K_ZIPVPN_INPUT: [MessageHandler(filters.TEXT & ~filters.COMMAND, zipvpn_input_handler)],
            K_XRAY_INPUT: [MessageHandler(filters.TEXT & ~filters.COMMAND, xray_input_handler)],
            K_XRAY_ADD_INPUT: [MessageHandler(filters.TEXT & ~filters.COMMAND, xray_add_input_handler)],
            K_XRAY_ADD_MENU: [CallbackQueryHandler(button_handler)],
            K_ZIPVPN_ADD_MENU: [
                CallbackQueryHandler(button_handler),
                MessageHandler(filters.TEXT & ~filters.COMMAND, zipvpn_add_text_handler)
            ],
            K_SSH_DETAIL: [CallbackQueryHandler(button_handler)],
            K_SSH_RENEW: [CallbackQueryHandler(button_handler)],
            K_SSH_EDIT_LIMIT: [
                CallbackQueryHandler(button_handler),
                MessageHandler(filters.TEXT & ~filters.COMMAND, ssh_custom_limit_save)
            ],
        },
        fallbacks=[CommandHandler("start", cmd_start)],
        per_message=False,
    )

    application.add_handler(conv)
    application.add_error_handler(error_handler)
    application.run_polling(drop_pending_updates=True)

if __name__ == "__main__":
    main()
