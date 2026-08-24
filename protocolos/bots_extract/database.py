"""
MOVIVIP NETWORK v2.0 - Database Models
SQLite3 con esquema completo para users, system_users, ads, operators, etc.
"""

import sqlite3
import json
import os
from datetime import datetime, date, timedelta
from typing import Optional, List, Dict, Any
from dataclasses import dataclass
from contextlib import contextmanager
import threading

DB_PATH = "/root/movivip.db"
DB_LOCK = threading.Lock()

SCHEMA = """
-- USUARIOS DE TELEGRAM (clientes finales)
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tg_id INTEGER UNIQUE NOT NULL,
    username TEXT,
    first_name TEXT,
    last_name TEXT,
    language_code TEXT DEFAULT 'es',
    is_banned INTEGER DEFAULT 0,
    is_premium INTEGER DEFAULT 0,
    referrer_id INTEGER,
    referral_code TEXT UNIQUE,
    total_referrals INTEGER DEFAULT 0,
    balance_cop INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_activity TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- CUENTAS SSH CREADAS (system_users = cuentas VPN/SSH)
CREATE TABLE IF NOT EXISTS system_users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tg_id INTEGER NOT NULL,              -- Dueño (cliente)
    username TEXT UNIQUE NOT NULL,       -- Usuario SSH
    password TEXT NOT NULL,              -- Contraseña SSH
    operator TEXT NOT NULL,              -- movistar, tigo, claro, wom
    brand TEXT DEFAULT 'movivip',        -- marca: movivip, klepernet, etc.
    expires_at TEXT NOT NULL,            -- YYYY-MM-DD
    status TEXT DEFAULT 'active',        -- active, expired, banned, suspended
    trial INTEGER DEFAULT 0,             -- 1 = trial, 0 = pagado
    max_logins INTEGER DEFAULT 1,        -- Perfiles/dispositivos simultáneos (1-999)
    current_logins INTEGER DEFAULT 0,    -- Sesiones activas actuales
    last_ip TEXT,                        -- Última IP conectada
    last_login TIMESTAMP,
    total_bytes_up INTEGER DEFAULT 0,    -- Tráfico subida
    total_bytes_down INTEGER DEFAULT 0,  -- Tráfico bajada
    monthly_bytes_up INTEGER DEFAULT 0,
    monthly_bytes_down INTEGER DEFAULT 0,
    port_limit INTEGER DEFAULT 0,        -- 0 = solo puerto operador, 1 = todos
    allowed_ports TEXT,                  -- JSON array de puertos permitidos
    config_mode TEXT DEFAULT 'normal',   -- normal, udp, slowdns, ws
    server_type TEXT DEFAULT 'vps',      -- vps, dedicated, cloud
    nickname TEXT,                       -- Apodo personalizado
    email TEXT,
    hwid TEXT DEFAULT '',                -- HWID del dispositivo (HTTP Custom) - creado con HWID
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (tg_id) REFERENCES users(tg_id),
    FOREIGN KEY (brand) REFERENCES brands(name)
);

-- ÓRDENES / COMPRAS
CREATE TABLE IF NOT EXISTS orders (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tg_id INTEGER NOT NULL,
    sysuser_id INTEGER,
    operator TEXT NOT NULL,
    brand TEXT DEFAULT 'movivip',
    days INTEGER NOT NULL,
    profiles INTEGER DEFAULT 1,
    amount_cop INTEGER NOT NULL,
    amount_usd REAL,
    status TEXT DEFAULT 'pending',       -- pending, paid, failed, refunded, completed
    payment_method TEXT,                 -- mp, nequi, daviplata, binance, crypto, manual
    payment_id TEXT,                     -- ID de mercado pago / tx hash
    comprobante TEXT,                    -- Foto comprobante (file_id)
    buyer_confirmed INTEGER DEFAULT 0,
    admin_confirmed INTEGER DEFAULT 0,
    config_mode TEXT DEFAULT 'normal',
    xui_uuid TEXT,                       -- UUID de X-UI si aplica
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    FOREIGN KEY (tg_id) REFERENCES users(tg_id),
    FOREIGN KEY (sysuser_id) REFERENCES system_users(id)
);

-- ADMINISTRADORES Y PROVEEDORES
CREATE TABLE IF NOT EXISTS admins (
    tg_id INTEGER PRIMARY KEY,
    added_by INTEGER NOT NULL,
    role TEXT DEFAULT 'provider',        -- admin, superadmin, provider, reseller
    brand TEXT DEFAULT 'movivip',
    permissions TEXT,                    -- JSON array: ["users","orders","stats","ads","broadcast"]
    max_users INTEGER DEFAULT 100,       -- Límite de usuarios que puede crear
    users_created INTEGER DEFAULT 0,
    commission_pct REAL DEFAULT 0,       -- % comisión sobre ventas
    password_hash TEXT,                  -- Para login web panel
    banner_template TEXT,                -- Template banner personalizado
    is_active INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (brand) REFERENCES brands(name)
);

-- MARCAS / BRANDS (White-label)
CREATE TABLE IF NOT EXISTS brands (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL,           -- slug: movivip, klepernet, netuno
    display_name TEXT NOT NULL,          -- "⭐ MoviVIP Network"
    website TEXT,
    whatsapp TEXT,
    phone TEXT,
    telegram TEXT,
    youtube TEXT,
    primary_color TEXT DEFAULT '#FFD700',
    secondary_color TEXT DEFAULT '#00BFFF',
    welcome_message TEXT,
    banner_template TEXT,
    is_active INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- OPERADORES Y PUERTOS
CREATE TABLE IF NOT EXISTS operators (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT UNIQUE NOT NULL,           -- movistar, tigo, claro, wom
    name TEXT NOT NULL,                  -- MOVISTAR
    allowed_ports TEXT NOT NULL,         -- JSON array: [443, 8443]
    blocked_ports TEXT,                  -- JSON array
    default_port INTEGER,
    protocols TEXT,                      -- JSON array: ["SSL", "STUNNEL"]
    description TEXT,
    is_active INTEGER DEFAULT 1,
    sort_order INTEGER DEFAULT 0
);

-- ANUNCIOS / ADS (Sistema de anuncios obligatorios)
CREATE TABLE IF NOT EXISTS ad_campaigns (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    adsgram_id TEXT UNIQUE,              -- ID de AdsGram
    title TEXT NOT NULL,
    text TEXT,
    image_url TEXT,
    video_url TEXT,
    landing_url TEXT,
    cta_text TEXT DEFAULT 'Ver video',
    ad_type TEXT DEFAULT 'rewarded',     -- rewarded, video, interstitial, task
    bonus_days INTEGER DEFAULT 0,        -- Días extra si es rewarded
    duration_seconds INTEGER DEFAULT 30,
    target_countries TEXT,               -- JSON array: ["CO", "VE", "EC"]
    target_platforms TEXT,               -- JSON array: ["android", "ios"]
    min_cpm_usd REAL DEFAULT 0.5,
    daily_budget_usd REAL DEFAULT 10,
    total_budget_usd REAL DEFAULT 100,
    status TEXT DEFAULT 'active',        -- active, paused, completed, rejected
    impressions INTEGER DEFAULT 0,
    clicks INTEGER DEFAULT 0,
    completions INTEGER DEFAULT 0,
    spent_usd REAL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP
);

-- HISTORIAL DE ANUNCIOS VISTOS POR USUARIO
CREATE TABLE IF NOT EXISTS user_ad_views (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tg_id INTEGER NOT NULL,
    campaign_id INTEGER NOT NULL,
    ad_type TEXT NOT NULL,
    watched_seconds INTEGER DEFAULT 0,
    completed INTEGER DEFAULT 0,
    rewarded INTEGER DEFAULT 0,
    bonus_days INTEGER DEFAULT 0,
    ip TEXT,
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (tg_id) REFERENCES users(tg_id),
    FOREIGN KEY (campaign_id) REFERENCES ad_campaigns(id)
);

-- SNI / DOMAINS PARA CADA OPERADOR
CREATE TABLE IF NOT EXISTS operator_snis (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    operator TEXT NOT NULL,
    sni TEXT NOT NULL,
    cdn_provider TEXT,                   -- cloudflare, cloudfront, aws
    is_active INTEGER DEFAULT 1,
    priority INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (operator) REFERENCES operators(code)
);

-- PLANTILLAS HANDSHAKE / PAYLOADS
CREATE TABLE IF NOT EXISTS hc_templates (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    operator TEXT NOT NULL,
    name TEXT NOT NULL,
    config_text TEXT NOT NULL,
    encrypt_key TEXT,
    is_default INTEGER DEFAULT 0,
    is_active INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (operator) REFERENCES operators(code)
);

-- TICKETS DE SOPORTE
CREATE TABLE IF NOT EXISTS support_tickets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tg_id INTEGER NOT NULL,
    username TEXT,
    subject TEXT,
    message TEXT,
    status TEXT DEFAULT 'open',          -- open, in_progress, closed
    priority TEXT DEFAULT 'normal',      -- low, normal, high, urgent
    assigned_admin INTEGER,
    response TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    closed_at TIMESTAMP,
    FOREIGN KEY (tg_id) REFERENCES users(tg_id),
    FOREIGN KEY (assigned_admin) REFERENCES admins(tg_id)
);

-- PROMOCIONES / CUPONES
CREATE TABLE IF NOT EXISTS promos (
    code TEXT PRIMARY KEY,
    tipo TEXT NOT NULL,                  -- days, profiles, discount, trial
    valor INTEGER NOT NULL,
    perfiles INTEGER DEFAULT 1,
    usos_max INTEGER DEFAULT 100,
    usos_actual INTEGER DEFAULT 0,
    activo INTEGER DEFAULT 1,
    creado_por INTEGER,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_expiracion TIMESTAMP,
    max_uses_per_user INTEGER DEFAULT 1,
    perfil INTEGER DEFAULT 1
);

-- CONFIGURACIÓN GLOBAL
CREATE TABLE IF NOT EXISTS config (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    description TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- LOGS DE AUDITORÍA
CREATE TABLE IF NOT EXISTS audit_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tg_id INTEGER,
    action TEXT NOT NULL,
    details TEXT,
    ip TEXT,
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- LOGS DE DEBUG (recopilación detallada para troubleshooting)
CREATE TABLE IF NOT EXISTS debug_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tg_id INTEGER,
    username TEXT,
    module TEXT NOT NULL,          -- admin_bot, user_bot, database
    function TEXT NOT NULL,        -- nombre de la función
    action TEXT NOT NULL,          -- create_user, button_handler, etc
    state TEXT,                    -- estado de conversación
    status TEXT DEFAULT 'info',    -- info, warning, error, critical
    message TEXT,                  -- mensaje descriptivo
    context TEXT,                  -- JSON con datos adicionales
    duration_ms INTEGER,           -- tiempo de ejecución
    error_trace TEXT,              -- traceback si hay error
    ip TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_debug_logs_tgid ON debug_logs(tg_id);
CREATE INDEX IF NOT EXISTS idx_debug_logs_action ON debug_logs(action);
CREATE INDEX IF NOT EXISTS idx_debug_logs_status ON debug_logs(status);
CREATE INDEX IF NOT EXISTS idx_debug_logs_created ON debug_logs(created_at);

-- ÍNDICES PARA PERFORMANCE
CREATE INDEX IF NOT EXISTS idx_system_users_tgid ON system_users(tg_id);
CREATE INDEX IF NOT EXISTS idx_system_users_status ON system_users(status);
CREATE INDEX IF NOT EXISTS idx_system_users_operator ON system_users(operator);
CREATE INDEX IF NOT EXISTS idx_system_users_expires ON system_users(expires_at);
CREATE INDEX IF NOT EXISTS idx_orders_tgid ON orders(tg_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_user_ad_views_tgid ON user_ad_views(tg_id);
CREATE INDEX IF NOT EXISTS idx_user_ad_views_campaign ON user_ad_views(campaign_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_tgid ON audit_logs(tg_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);
"""

# Datos iniciales — OPERADORES ELIMINADOS DEL REPO PUBLICO
# Los datos de operadores (payloads, SNIs, puertos) son exclusivos del vendedor
# y NO se publican. El bot crea cuentas SSH directas y entrega la plantilla
# generica con los datos del VPS del cliente.
INITIAL_OPERATORS = []

INITIAL_BRANDS = [
    ("PONER_BRAND_AQUI", "⭐ PONER_BRAND_AQUI Network", "https://PONER_WEB_AQUI/", "https://wa.me/PONER_WHATSAPP_AQUI", "PONER_WHATSAPP_AQUI", "@PONER_CANAL_AQUI", "https://www.youtube.com/@PONER_CANAL_AQUI", "#FFD700", "#00BFFF", "Bienvenido a PONER_BRAND_AQUI Network - Tu VPN Premium", None, 1),
    ("PONER_BRAND2_AQUI", "💠 PONER_BRAND2_AQUI", "https://PONER_WEB2_AQUI/", "https://wa.me/PONER_WHATSAPP2_AQUI", "PONER_WHATSAPP2_AQUI", "", "", "#FF6600", "#9933FF", "PONER_BRAND2_AQUI - Internet Ilimitado", None, 1),
]

INITIAL_CONFIG = [
    ("max_trial_days", "3", "Máximo días de prueba"),
    ("max_create_days", "30", "Máximo días al crear cuenta"),
    ("default_profiles", "1", "Perfiles por defecto"),
    ("ad_cooldown_seconds", "180", "Cooldown entre anuncios (segundos)"),
    ("ad_required_for_create", "1", "Anuncio obligatorio para crear cuenta"),
    ("ad_bonus_days", "1", "Días bonus por ver anuncio rewarded"),
    ("ssh_port_main", "22", "Puerto SSH principal"),
    ("ssh_port_dropbear", "143", "Puerto Dropbear"),
    ("ssh_port_ssl", "443", "Puerto SSL/Stunnel"),
    ("ssh_port_ws", "8080", "Puerto WebSocket"),
    ("vps_domain", "PONER_SUBDOMINIO_AQUI", "Dominio principal VPS"),
    ("cloudfront_domain", "PONER_CDN_PRIMARY_AQUI", "CloudFront CDN secundario"),
    ("cloudfront_domain2", "PONER_CDN_EXTRA_AQUI", "CloudFront CDN primario"),
    ("slowdns_ns", "ns1.PONER_DOMINIO_AQUI", "Nameserver SlowDNS"),
    ("slowdns_port", "5300", "Puerto SlowDNS"),
    ("slowdns_key", "PONER_SLOWDNS_KEY_AQUI", "Clave pública SlowDNS"),
    ("vaydns_ns", "t.PONER_DOMINIO_AQUI", "Nameserver VayDNS"),
    ("vaydns_port", "5354", "Puerto VayDNS"),
    ("vaydns_key", "PONER_VAYDNS_PUBKEY_AQUI", "Clave pública VayDNS"),
    ("dnstt_ns", "d.PONER_DOMINIO_AQUI", "Nameserver DNS-TT v2"),
    ("dnstt_port", "5355", "Puerto DNS-TT v2"),
    ("dnstt_key", "PONER_DNSTT_PUBKEY_AQUI", "Clave pública DNS-TT v2"),
    ("cf_domain", "PONER_DOMINIO_AQUI", "Dominio Cloudflare"),
]

class Database:
    def __init__(self, path: str = DB_PATH):
        self.path = path
        self._init_db()
    
    def _init_db(self):
        with self._get_conn() as conn:
            conn.executescript(SCHEMA)
            self._migrate(conn)
            self._seed_data(conn)

    def _migrate(self, conn: sqlite3.Connection):
        """Migraciones para bases existentes (columnas nuevas, etc.)."""
        try:
            cols = [r[1] for r in conn.execute("PRAGMA table_info(system_users)").fetchall()]
            if "hwid" not in cols:
                conn.execute("ALTER TABLE system_users ADD COLUMN hwid TEXT DEFAULT ''")
        except Exception:
            pass
    
    def _seed_data(self, conn: sqlite3.Connection):
        # Operadores
        for op in INITIAL_OPERATORS:
            conn.execute("""
                INSERT OR IGNORE INTO operators (code, name, allowed_ports, blocked_ports, default_port, protocols, description, is_active, sort_order)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, op)
        
        # Marcas
        for brand in INITIAL_BRANDS:
            conn.execute("""
                INSERT OR IGNORE INTO brands (name, display_name, website, whatsapp, phone, telegram, youtube, primary_color, secondary_color, welcome_message, banner_template, is_active)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, brand)
        
        # Config
        for cfg in INITIAL_CONFIG:
            conn.execute("INSERT OR IGNORE INTO config (key, value, description) VALUES (?, ?, ?)", cfg)
        
        conn.commit()
    
    @contextmanager
    def _get_conn(self):
        with DB_LOCK:
            conn = sqlite3.connect(self.path, timeout=30, check_same_thread=False)
            conn.row_factory = sqlite3.Row
            conn.execute("PRAGMA journal_mode=WAL")
            conn.execute("PRAGMA busy_timeout=30000")
            conn.execute("PRAGMA foreign_keys=ON")
            try:
                yield conn
                conn.commit()
            except Exception:
                conn.rollback()
                raise
            finally:
                conn.close()
    
    def execute(self, query: str, params: tuple = ()) -> sqlite3.Cursor:
        with self._get_conn() as conn:
            return conn.execute(query, params)
    
    def fetchone(self, query: str, params: tuple = ()) -> Optional[sqlite3.Row]:
        with self._get_conn() as conn:
            return conn.execute(query, params).fetchone()
    
    def fetchall(self, query: str, params: tuple = ()) -> List[sqlite3.Row]:
        with self._get_conn() as conn:
            return conn.execute(query, params).fetchall()
    
    def insert(self, query: str, params: tuple = ()) -> int:
        with self._get_conn() as conn:
            cur = conn.execute(query, params)
            return cur.lastrowid

# Instancia global
db = Database()

# Helpers rápidos
def get_config(key: str, default: str = "") -> str:
    row = db.fetchone("SELECT value FROM config WHERE key=?", (key,))
    return row["value"] if row else default

def set_config(key: str, value: str):
    db.execute("INSERT OR REPLACE INTO config (key, value, updated_at) VALUES (?, ?, CURRENT_TIMESTAMP)", (key, value))

def is_admin(tg_id: int) -> bool:
    row = db.fetchone("SELECT 1 FROM admins WHERE tg_id=?", (tg_id,))
    return bool(row)

def get_admin_role(tg_id: int) -> Optional[str]:
    row = db.fetchone("SELECT role FROM admins WHERE tg_id=?", (tg_id,))
    return row["role"] if row else None

def get_admin_brand(tg_id: int) -> str:
    row = db.fetchone("SELECT brand FROM admins WHERE tg_id=?", (tg_id,))
    return row["brand"] if row else "movivip"

def has_permission(tg_id: int, perm: str) -> bool:
    row = db.fetchone("SELECT permissions FROM admins WHERE tg_id=?", (tg_id,))
    if not row or not row["permissions"]:
        return False
    try:
        perms = json.loads(row["permissions"])
        return perm in perms or "all" in perms
    except:
        return False

def log_audit(tg_id: int, action: str, details: str = "", ip: str = "", ua: str = ""):
    db.execute("INSERT INTO audit_logs (tg_id, action, details, ip, user_agent) VALUES (?, ?, ?, ?, ?)",
               (tg_id, action, details, ip, ua))

def log_debug(tg_id: int, module: str, function: str, action: str,
              message: str = "", state: str = "", status: str = "info",
              context: dict = None, duration_ms: int = 0,
              error_trace: str = "", username: str = ""):
    """Registra un evento de debug detallado para troubleshooting"""
    try:
        context_json = json.dumps(context) if context else ""
        db.execute("""
            INSERT INTO debug_logs (tg_id, username, module, function, action, state, status, message, context, duration_ms, error_trace)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (tg_id, username, module, function, action, state, status, message[:500], context_json[:2000], duration_ms, error_trace[:3000]))
    except Exception as e:
        # No fallar si no se puede loguear
        pass

# Inicializar al importar
if __name__ == "__main__":
    print("Database initialized successfully")
    # Verificar
    for row in db.fetchall("SELECT name FROM sqlite_master WHERE type='table'"):
        print(f"  Table: {row['name']}")