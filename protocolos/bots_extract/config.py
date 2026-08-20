"""
MoviVIP Network v3.0 - Configuration
Sistema de produccion SSH premium con Monetag + Firebase
"""

import os
import sqlite3

# =============================================================================
# BOT TOKENS
# =============================================================================
ADMIN_BOT_TOKEN = "PONER_TOKEN_ADMIN_AQUI"  # @TU_BOT_ADMIN (el generador lo reemplaza)

# =============================================================================
# ADMIN TELEGRAM IDS
# =============================================================================
ADMIN_IDS = [0]

# =============================================================================
# NOTIF BOT (notif_bot.py) — notificaciones a canal/grupo
# =============================================================================
# NOTIF_BOT_TOKEN DEBE ser un bot DISTINTO al admin (si son iguales no pueden
# correr juntos: telegram rechaza dos getUpdates con el mismo token).
NOTIF_BOT_TOKEN = ""                      # token del bot de notificaciones
NOTIF_CHANNEL_ID = -1000000000000         # ID numerico del canal (altas)
NOTIF_GROUP_ID = -1000000000001           # ID numerico del grupo de soporte

# =============================================================================
# MONETAG MINIAPP
# =============================================================================
# SDK: libtl.com — el generador reemplaza con los datos del cliente
MONETAG_ZONE_ID = "PONER_ZONE_ID_AQUI"
MONETAG_SDK_URL = "//libtl.com/sdk.js"
MONETAG_SDK_FUNC = "PONER_SDK_FUNC_AQUI"
MINIAPP_BASE_URL = "http://127.0.0.1:5000"

# =============================================================================
# VPS — EDITAR: host, usuario y password del VPS del CLIENTE
# =============================================================================
VPS_HOST = "127.0.0.1"
VPS_PORT = 22
VPS_USER = "root"
VPS_PASSWORD = "PONER_PASSWORD_VPS_AQUI"
SSH_HOST = "127.0.0.1"  # Localhost for SSH - bot runs on same VPS
VPS_SUBDOMAIN = "PONER_SUBDOMINIO_AQUI"  # Dominio/subdominio apuntando al VPS

# =============================================================================
# VPS / DOMINIOS — EDITAR: dominio base del cliente para SlowDNS/VayDNS/DNSTT
# =============================================================================
DOMAIN_MAIN = "PONER_DOMINIO_AQUI"  # Dominio principal (para ns1., t., d. subdominios)

# Cloudflare (SNI / SSL)
CLOUDFLARE_DOMAIN = DOMAIN_MAIN

# CloudFront CDN (HTTP / WebSocket) — el generador reemplaza con los del cliente
CDN_PRIMARY = "PONER_CDN_PRIMARY_AQUI"
CDN_SECONDARY = "PONER_CDN_SECONDARY_AQUI"
CDN_ALT = "PONER_CDN_ALT_AQUI"
CDN_EXTRA = "PONER_CDN_EXTRA_AQUI"

# SlowDNS — Puerto 5300 (key publica del VPS del cliente)
SLOWDNS_NS = f"ns1.{DOMAIN_MAIN}"
SLOWDNS_KEY = "PONER_SLOWDNS_KEY_AQUI"
SLOWDNS_PUB = "PONER_SLOWDNS_PUB_AQUI"
SLOWDNS_PORT = 5300

# VayDNS
VAYDNS_PORT = 5354
VAYDNS_DOMAIN = f"t.{DOMAIN_MAIN}"
VAYDNS_PUBKEY = "PONER_VAYDNS_PUBKEY_AQUI"

# DNSTT (SlowDNS v2)
DNSTT_PORT = 5355
DNSTT_DOMAIN = f"d.{DOMAIN_MAIN}"
DNSTT_PUBKEY = "PONER_DNSTT_PUBKEY_AQUI"

# =============================================================================
# MINIAPP / API — EDITAR: URL de la miniapp y del backend
# OPCIONAL: la Mini App (anuncios/store) es INDEPENDIENTE del bot. Cada
# cliente la activa por su cuenta. Si el cliente tiene su miniapp desplegada
# en su VPS (puerto 8448) queda lista; si no la tiene, dejar en blanco "".
# =============================================================================
MINIAPP_URL = f"https://{VPS_SUBDOMAIN}:8448"  # Si no hay miniapp: MINIAPP_URL = ""
API_URL = f"http://{VPS_HOST}:5000"

# =============================================================================
# FIREBASE — OPCIONAL, solo si el cliente activa SU miniapp con Firebase.
# Ningun bot del paquete la usa directamente; se deja None para que el
# cliente ponga sus propias credenciales si/solo si activa su miniapp.
# =============================================================================
FIREBASE_SERVICE_ACCOUNT = None  # <<< opcional: pegar aqui el service account del cliente

# =============================================================================
# =============================================================================
# ENLACE DE ATENCION - EDITAR: link del administrador al que se redirige al
# usuario para contratar o recibir atencion (el bot NO tiene metodos de pago).
# Ej: "https://wa.me/5730012345678" o "https://t.me/miusuario"
# =============================================================================
LINK_REDIREC = ""  # <<< enlace del administrador (editar desde menu.sh)
# =============================================================================
# TELEGRAM CHANNELS
# =============================================================================
MAIN_CHANNEL = "PONER_CANAL_AQUI"
SUPPORT_GROUP = "PONER_GRUPO_AQUI"

# =============================================================================
# BRANDING — EDITAR: marca del cliente (white-label)
# =============================================================================
BRAND_NAME = "PONER_MARCA_AQUI"
MY_BRAND = "PONER_MARCA_KEY_AQUI"  # Esta marca es la clave en DB (system_users.brand)
BRAND_BOT = "PONER_BOT_MARCA_AQUI"
BRAND_PREMIUM = ""
BRAND_SUPPORT = ""
BRAND_CHANNEL = ""
BRAND_GROUP = ""
BRAND_STORE = ""
BRAND_MINIAPP = ""

# =============================================================================
# DATABASE
# =============================================================================
DB_PATH = "/root/movivip.db"

# =============================================================================
# LOAD SNIs FROM DATABASE (shared across all bots via operator_snis table)
# =============================================================================
def load_snis_from_db():
    """Load SNIs from operator_snis table. Returns dict: {operator: [sni, ...]}"""
    try:
        conn = sqlite3.connect(DB_PATH)
        cur = conn.cursor()
        cur.execute("SELECT operator, sni FROM operator_snis WHERE is_active=1 ORDER BY operator, priority DESC")
        snis_db = {}
        for op, sni in cur.fetchall():
            if op not in snis_db:
                snis_db[op] = {"snis": [], "default": None}
            snis_db[op]["snis"].append(sni)
            if snis_db[op]["default"] is None:
                snis_db[op]["default"] = sni  # highest priority = default
        conn.close()
        return snis_db
    except Exception:
        return {}

def save_sni_to_db(operator, sni, cdn_provider="cloudflare", is_active=True, priority=0):
    """Add an SNI to operator_snis table."""
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        "INSERT OR REPLACE INTO operator_snis (operator, sni, cdn_provider, is_active, priority) VALUES (?, ?, ?, ?, ?)",
        (operator, sni, cdn_provider, 1 if is_active else 0, priority)
    )
    conn.commit()
    conn.close()

def remove_sni_from_db(operator, sni):
    """Remove an SNI from operator_snis table."""
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute("DELETE FROM operator_snis WHERE operator = ? AND sni = ?", (operator, sni))
    conn.commit()
    conn.close()

def get_snis_for_operator(operator):
    """Get SNIs list for a specific operator from DB."""
    snis_db = load_snis_from_db()
    if operator in snis_db:
        return snis_db[operator]["snis"]
    return []

# =============================================================================
# OPERATORS — ELIMINADO DEL REPO PUBLICO
# =============================================================================
# Los datos de operadores (payloads, SNIs, hosts, puertos por operador) son
# exclusivos del vendedor y NO se publican. El bot crea cuentas SSH directas y
# entrega la plantilla generica con los datos del VPS (plantilla-entrega-bot.txt).
# Los bots generados por generar-bot-cliente.ps1 usan la copia real en Temp.
OPERATORS = {}


# =============================================================================
# ALIASES FOR ADMIN BOT COMPATIBILITY
# =============================================================================
OPERATOR_PORTS = OPERATORS  # Alias for admin_bot_providers.py compatibility

# =============================================================================
# SNI Configuration — Loaded from database (shared across all bots)
# =============================================================================
SNI_CONFIG = load_snis_from_db()

def refresh_snis():
    """Reload SNIs from DB and update OPERATORS in-place. Call before account creation."""
    global SNI_CONFIG
    try:
        new_snis = load_snis_from_db()
        SNI_CONFIG = new_snis
        for op_key, op_data in OPERATORS.items():
            if op_key in new_snis:
                op_data["snis"] = new_snis[op_key]["snis"]
                op_data["sni_list"] = new_snis[op_key]["snis"]
            elif "snis" not in op_data:
                op_data["snis"] = []
                op_data["sni_list"] = []
        return True
    except Exception:
        return False

MAX_DAYS_CREATE = 30  # Maximum days for account creation

# =============================================================================
# PLANS
# =============================================================================
PLANS = {
    3: {"days": 3, "price": "Gratis", "max_devices": 1},
    7: {"days": 7, "price": "Gratis", "max_devices": 3},
    15: {"days": 15, "price": "Gratis", "max_devices": 5},
    30: {"days": 30, "price": "Gratis", "max_devices": 10},
}

MAX_DEVICES = 10
AD_COOLDOWN_SECONDS = 300  # 5 min between accounts

# =============================================================================
# V2Ray/Xray
# =============================================================================
XRAY_VPS_IP = "127.0.0.1"
XRAY_VLESS_REALITY_PORT = 9443
XRAY_VMESS_WS_PORT = 8443
XRAY_VLESS_REALITY_PUBKEY = "PONER_PUBKEY_AQUI"
XRAY_VLESS_REALITY_SHORTID = "PONER_SHORTID_AQUI"
XRAY_VLESS_REALITY_SNI = "www.microsoft.com"
XRAY_VMESS_WS_PATH = "/vmess"
XRAY_CONFIG_PATH = "/usr/local/etc/xray/config.json"

# =============================================================================
# SYSTEM PATHS
# =============================================================================
BANNERS_DIR = "/etc/ssh/banners"
VPN_SHELL = "/usr/local/bin/vpn-shell.sh"