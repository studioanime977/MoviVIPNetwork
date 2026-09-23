# -*- coding: utf-8 -*-
"""
MoviVIP Web Panel v2 — "Webmin style"
Panel de administración total del script MoviVIP desde navegador.
 - Dashboard con CPU funcional (delta /proc/stat)
 - Usuarios CRUD + plantilla de entrega completa (igual que add.sh real)
 - Protocolos (24) con consola interactiva en vivo (PTY + SSE)
 - Herramientas (28) con consola interactiva
 - Servicios, Logs, Historial, Terminal
Login exclusivo root (valida /etc/shadow con crypt).
"""
import os, re, json, time, signal, select, subprocess, threading, uuid, socket, glob
from datetime import datetime, timedelta
from collections import deque, OrderedDict
from pathlib import Path
import asyncio

import hmac, hashlib, base64, secrets
try:
    import crypt
except Exception:
    crypt = None

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse, StreamingResponse, FileResponse
from fastapi.staticfiles import StaticFiles
import uvicorn

# ═══════════════════════════════════════════════════════════
# CONFIG GENERAL
# ═══════════════════════════════════════════════════════════
BASE_MV = "/etc/movivip"
CONFIG_MV = f"{BASE_MV}/config.conf"
SYS_DIR = f"{BASE_MV}/sistema"
PANEL_DIR = "/opt/movivip-web"
DATA_DIR = f"{PANEL_DIR}/data"
LOG_FILE = f"{DATA_DIR}/panel.log"
HIST_FILE = f"{DATA_DIR}/historial.json"
SECRET_FILE = "/etc/movivip-web/secret.key"
PORT = int(os.environ.get("PORT", "9617"))

os.makedirs(DATA_DIR, exist_ok=True)
os.makedirs(f"{PANEL_DIR}/static", exist_ok=True)

APP_NAME = "MoviVIP Web Panel"
VERSION = "2.0.0"

# ═══════════════════════════════════════════════════════════
# LOG + HISTORIAL
# ═══════════════════════════════════════════════════════════
def _now(): return datetime.now().strftime("%Y-%m-%d %H:%M:%S")

def log(msg: str):
    try:
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(f"[{_now()}] {msg}\n")
    except Exception:
        pass

def hist(action: str, detail: str = ""):
    try:
        items = []
        if os.path.exists(HIST_FILE):
            with open(HIST_FILE, "r", encoding="utf-8") as f:
                items = json.load(f)
        items.append({"ts": _now(), "action": action, "detail": detail})
        items = items[-300:]
        with open(HIST_FILE, "w", encoding="utf-8") as f:
            json.dump(items, f, ensure_ascii=False, indent=1)
    except Exception:
        pass
    log(f"{action} {detail}".strip())

# ═══════════════════════════════════════════════════════════
# CONFIG MOVIVIP (config.conf)
# ═══════════════════════════════════════════════════════════
def load_conf() -> dict:
    """Parsea /etc/movivip/config.conf key=value (y otros conf de sistema)."""
    cfg = {}
    def _parse(path):
        if not os.path.exists(path):
            return
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith("#") or "=" not in line:
                        continue
                    k, v = line.split("=", 1)
                    cfg[k.strip()] = v.strip().strip('"').strip("'")
        except Exception:
            pass
    _parse(CONFIG_MV)
    _parse(f"{SYS_DIR}/limites_consumo.conf")
    return cfg

def read_kv(path: str) -> dict:
    cfg = {}
    if os.path.exists(path):
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as f:
                for line in f:
                    line = line.strip()
                    if line and "=" in line and not line.startswith("#"):
                        k, v = line.split("=", 1)
                        cfg[k.strip()] = v.strip()
        except Exception:
            pass
    return cfg

# ═══════════════════════════════════════════════════════════
# SH / SUBPROCESS HELPERS
# ═══════════════════════════════════════════════════════════
def sh(cmd, timeout=15):
    """Ejecuta comando, devuelve stdout (str), stderr capturado."""
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return (r.stdout or "").strip()
    except Exception:
        return ""

def sh_json(cmd, timeout=20):
    """Similar a sh() pero con distinción código salida para lógica booleana."""
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return r.returncode, (r.stdout or "").strip()
    except Exception as e:
        return -1, str(e)

# ═══════════════════════════════════════════════════════════
# AUTH — token HMAC, login root
# ═══════════════════════════════════════════════════════════
def get_secret() -> bytes:
    try:
        if os.path.exists(SECRET_FILE):
            with open(SECRET_FILE, "rb") as f:
                s = f.read().strip()
                if len(s) >= 16:
                    return s
        s = secrets.token_bytes(32)
        os.makedirs(os.path.dirname(SECRET_FILE), exist_ok=True)
        with open(SECRET_FILE, "wb") as f:
            f.write(s)
        os.chmod(SECRET_FILE, 0o600)
        return s
    except Exception:
        return b"movivip-panel-secret-fallback-2026"

def make_token() -> str:
    payload = f"{secrets.token_hex(8)}.{int(time.time()) + 43200}"
    sig = hmac.new(get_secret(), payload.encode(), hashlib.sha256).hexdigest()
    return base64.urlsafe_b64encode(f"{payload}.{sig}".encode()).decode()

def verify_token(tok: str) -> bool:
    try:
        data = base64.urlsafe_b64decode(tok.encode()).decode()
        payload, sig = data.rsplit(".", 1)
        exp = int(payload.split(".")[1])
        if time.time() > exp:
            return False
        expect = hmac.new(get_secret(), payload.encode(), hashlib.sha256).hexdigest()
        return hmac.compare_digest(expect, sig)
    except Exception:
        return False

def check_root(user: str, password: str) -> bool:
    """True solo si user == 'root' y password valida contra /etc/shadow."""
    if user != "root":
        return False
    if not os.path.exists("/etc/shadow"):
        # entorno local (dev) — acceso raiz del sistema
        return True
    if crypt is None:
        return False
    try:
        with open("/etc/shadow", "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                parts = line.rstrip("\n").split(":")
                if parts[0] == "root":
                    h = parts[1]
                    if h in ("!", "*", ""):
                        return False
                    return crypt.crypt(password, h) == h
    except Exception:
        return False
    return False

async def guard(request: Request):
    auth = request.headers.get("Authorization", "")
    tok = auth.replace("Bearer ", "") if auth else ""
    if not tok or not verify_token(tok):
        raise AuthExc(401, "No autorizado")
    return True

class AuthExc(Exception):
    def __init__(self, code, msg):
        self.code = code; self.msg = msg

app = FastAPI(title=APP_NAME, docs_url=None, redoc_url=None, openapi_url=None)

@app.exception_handler(AuthExc)
async def auth_exc_handler(request, exc):
    return JSONResponse(status_code=exc.code, content={"error": exc.msg})

@app.middleware("http")
async def add_cors(request: Request, call_next):
    resp = await call_next(request)
    resp.headers["Access-Control-Allow-Origin"] = "*"
    resp.headers["Access-Control-Allow-Headers"] = "Authorization, Content-Type"
    resp.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
    return resp

# ═══════════════════════════════════════════════════════════
# METRICAS SISTEMA (CPU funcional)
# ═══════════════════════════════════════════════════════════
def _cpu_times():
    try:
        with open("/proc/stat") as f:
            parts = f.readline().split()[1:8]
        nums = [int(x) for x in parts]
        total = sum(nums)                # user nice system idle iowait irq softirq
        idle = nums[3] + nums[4]         # idle + iowait
        return idle, total
    except Exception:
        return 0, 0

def cpu_percent(duration=0.25):
    i1, t1 = _cpu_times()
    time.sleep(duration)
    i2, t2 = _cpu_times()
    d_idle, d_total = i2 - i1, t2 - t1
    if d_total <= 0:
        return 0.0
    return round(100.0 * (1.0 - d_idle / d_total), 1)

def get_metrics():
    # RAM
    try:
        with open("/proc/meminfo") as f:
            lines = f.readlines()
        def _memv(key):
            for ln in lines:
                if ln.startswith(key):
                    return int(ln.split()[1]) // 1024  # kB -> MiB
            return 0
        ram_total = _memv("MemTotal:"); ram_free = _memv("MemAvailable:")
        ram_used = max(0, ram_total - ram_free)
        ram_pct = round(ram_used * 100.0 / ram_total, 1) if ram_total else 0
    except Exception:
        ram_total = ram_used = ram_pct = 0
    # CPU modelo / núcleos
    cpu_model = ""
    cores = 0
    try:
        with open("/proc/cpuinfo") as f:
            for ln in f:
                if ln.startswith("model name") and not cpu_model:
                    cpu_model = ln.split(":", 1)[1].strip()
                if ln.startswith("processor"):
                    cores += 1
    except Exception:
        pass
    # Disco
    disk = {"total": "?", "used": "?", "pct": "?"}
    try:
        r = sh("df -h / | awk 'NR==2 {print $2\"|\"$3\"|\"$5}'")
        parts = r.split("|")
        if len(parts) == 3:
            disk = {"total": parts[0], "used": parts[1], "pct": parts[2]}
    except Exception:
        pass
    # Uptime
    try:
        with open("/proc/uptime") as f:
            up = float(f.read().split()[0])
        days = int(up // 86400); hrs = int((up % 86400) // 3600); mins = int((up % 3600) // 60)
        uptime_s = f"{days} días {hrs}h {mins}m"
    except Exception:
        uptime_s = "?"
    # Load
    load = "?"
    try:
        with open("/proc/loadavg") as f:
            load = " ".join(f.read().split()[:3])
    except Exception:
        pass
    # Procesos top
    procs = []
    try:
        r = subprocess.run(
            "ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu | head -12",
            shell=True, capture_output=True, text=True, timeout=10)
        for ln in (r.stdout or "").splitlines()[1:]:
            p = ln.split(None, 4)
            if len(p) == 5:
                procs.append({"pid": p[0], "user": p[1], "cpu": p[2], "mem": p[3], "cmd": p[4][:40]})
    except Exception:
        pass
    cpu_used = cpu_percent()
    return {
        "cpu_uso": f"{cpu_used}%", "cpu_pct": cpu_used, "cpu_model": cpu_model, "cpu_cores": cores,
        "ram_total": f"{ram_total}M", "ram_uso": f"{ram_used}M", "ram_pct": ram_pct,
        "ram_total_hr": sh("free -h | awk '/Mem:/ {print $2}'") or f"{ram_total}M",
        "ram_uso_hr": sh("free -h | awk '/Mem:/ {print $3}'") or f"{ram_used}M",
        "disco": disk, "uptime": uptime_s, "load": load, "procesos": procs,
    }

def get_host_info():
    ip = sh("hostname -I 2>/dev/null | awk '{print $1}'")
    if not ip:
        ip = sh("curl -4 -s --max-time 5 ifconfig.me 2>/dev/null") or "127.0.0.1"
    hostname = sh("hostname") or "?"
    os_name = sh("lsb_release -ds 2>/dev/null || . /etc/os-release && echo \"$PRETTY_NAME\"") or "Linux"
    kernel = sh("uname -r") or "?"
    arch = sh("uname -m") or "?"
    return {
        "ip": ip, "hostname": hostname, "os": os_name, "kernel": kernel, "arch": arch
    }

def _script_version(cfg=None):
    """Versión del multi-script MoviVIP: /etc/movivip/version.txt, fallback config.conf VERSION."""
    try:
        with open(f"{BASE_MV}/version.txt", "r", encoding="utf-8") as f:
            v = f.read().strip()
            if v:
                return v
    except Exception:
        pass
    if cfg and cfg.get("VERSION"):
        return str(cfg["VERSION"]).strip() or "?"
    return "?"

def _dominios(cfg):
    """Dominios configurados: Cloudflare (SERVER_DOMAIN), CloudFront (CLOUDFRONT_DOMAIN), DT DNS / No-IP (NOIP_DOMAIN)."""
    return [
        {"tipo": "cloudflare", "etiqueta": "Cloudflare", "icono": "☁️", "dominio": (cfg.get("SERVER_DOMAIN") or "").strip()},
        {"tipo": "cloudfront", "etiqueta": "CloudFront", "icono": "🎯", "dominio": (cfg.get("CLOUDFRONT_DOMAIN") or "").strip()},
        {"tipo": "dt-dns", "etiqueta": "DT DNS", "icono": "📡", "dominio": (cfg.get("NOIP_DOMAIN") or "").strip()},
    ]

def _xray_port_map():
    """Puerto → nombre de protocolo Xray (inbounds reales del config)."""
    out = {}
    try:
        with open("/usr/local/etc/xray/config.json", "r", encoding="utf-8") as f:
            cfg = json.load(f)
        for ib in cfg.get("inbounds", []):
            pr = ib.get("port")
            prot = ib.get("protocol")
            if pr:
                out[str(pr)] = ("Xray " + prot.upper()) if prot else "Xray"
    except Exception:
        pass
    return out

PROC_PROTO = [
    ("sshd", "OpenSSH"), ("dropbear", "Dropbear"), ("haproxy", "SSL/TLS"),
    ("stunnel", "SSL/TLS"), ("xray", "Xray"), ("zivpn", "ZiVPN"), ("udpgw", "BadVPN"), ("badvpn", "BadVPN"),
    ("udp-custom", "UDP Custom"), ("slowdns", "SlowDNS"), ("sockd", "SOCKS5"),
    ("btun", "BTUN"), ("ss-server", "Shadowsocks"), ("hysteria", "Hysteria"),
    ("payload", "Payload"), ("nginx", "Payload"), ("systemd-resolve", "SystemDNS"),
    ("dtunnel", "DTunnel"), ("hcr", "HCR Relay"), ("wireguard", "WireGuard"),
    ("wg-quick", "WireGuard"), ("openvpn", "OpenVPN"),
]

def _proto_for(port, proc, xports):
    if port in xports:
        return xports[port]
    for k, v in PROC_PROTO:
        if proc and k.lower() in proc.lower():
            return v
    static = {
        "22": "OpenSSH", "443": "SSL/TLS", "444": "SSL/TLS", "445": "SSL/TLS",
        "80": "Payload", "8080": "Payload", "8081": "Payload", "8082": "Payload",
        "8083": "Payload", "8084": "Payload", "8085": "Payload",
        "1080": "SOCKS5", "8388": "Shadowsocks", "20249": "Hysteria", "7900": "BTUN",
        "5667": "ZiVPN", "24075": "ZiVPN", "7200": "BadVPN", "7300": "BadVPN",
        "2100": "UDP Custom", "109": "Dropbear", "143": "Dropbear", "90": "Dropbear",
        "8799": "HCR Relay", "54321": "DTunnel", "9617": "Panel Web", "3306": "Panel Web",
    }
    return static.get(port, "")

def get_puertos():
    puertos = []
    try:
        r = subprocess.run("ss -tulnp 2>/dev/null", shell=True, capture_output=True, text=True, timeout=10)
        xports = _xray_port_map()
        seen = set()
        for ln in (r.stdout or "").splitlines():
            mm = re.search(r"^(udp|tcp)\s+\S+\s+\d+\s+\d+\s+(\S+):(\d+)\s+", ln)
            if not mm:
                continue
            addr, port = mm.group(2), mm.group(3)
            if addr.startswith("127.") or addr.startswith("::1"):
                continue
            um = re.search(r'"([^"]+)",pid=(\d+)', ln)
            proc = um.group(1) if um else "?"
            pid = um.group(2) if um else "?"
            k = (port, proc)
            if k in seen:
                continue
            seen.add(k)
            puertos.append({"port": port, "proc": proc, "pid": pid,
                            "proto": _proto_for(port, proc, xports)})
    except Exception:
        pass
    return sorted(puertos, key=lambda p: int(p["port"]) if p["port"].isdigit() else 99999)[:60]

# ═══════════════════════════════════════════════════════════
# USUARIOS
# ═══════════════════════════════════════════════════════════
def list_usuarios():
    usuarios = []
    try:
        with open("/etc/passwd", "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                p = line.rstrip("\n").split(":")
                if len(p) < 7:
                    continue
                try:
                    uid = int(p[2])
                except ValueError:
                    continue
                if uid >= 1000 and p[0] != "nobody":
                    usuarios.append({"user": p[0], "uid": uid, "shell": p[6]})
    except Exception:
        pass
    consumo = read_kv(f"{SYS_DIR}/consumo_usuarios.conf")
    limites = read_kv(f"{SYS_DIR}/limites_consumo.conf")
    connlim = read_kv(f"{SYS_DIR}/limites_conexiones.conf")

    for u in usuarios:
        u["expira"] = sh(f"chage -l {u['user']} 2>/dev/null | awk -F': ' '/Account expires/{{print $2}}'")
        estado = sh(f"passwd -S {u['user']} 2>/dev/null | awk '{{print $2}}'")
        u["estado"] = "Bloqueado" if estado == "L" else "Activo"
        consumo_b = consumo.get(u["user"], "0")
        try:
            cb = int(float(consumo_b))
        except Exception:
            cb = 0
        u["consumo_actual"] = fmt_bytes(cb)
        lim = limites.get(u["user"], "0")
        try:
            lim_b = int(float(lim))
        except Exception:
            lim_b = 0
        u["consumo_limite"] = "Ilimitado" if lim_b == 0 else fmt_bytes(lim_b)
        u["consumo_pct"] = round(cb * 100.0 / lim_b, 1) if lim_b and cb else 0
        cl = connlim.get(u["user"], "0")
        try:
            u["conn_limite"] = int(cl)
        except Exception:
            u["conn_limite"] = 0
        u["ultimo_acceso"] = sh(f"lastlog -u {u['user']} 2>/dev/null | tail -1 | awk '{{print $4\" \"$5\" \"$6}}'") or "nunca"
    usuarios.sort(key=lambda x: x["user"].lower())
    return usuarios

def exists_user(user: str) -> bool:
    code, _ = sh_json(f"id {user} 2>/dev/null")
    return code == 0

def fmt_bytes(b: int) -> str:
    b = float(b or 0)
    for unit in ["B", "KB", "MB", "GB", "TB", "PB"]:
        if b < 1024 or unit == "PB":
            return f"{b:.2f} {unit}" if unit != "B" else f"{int(b)} B"
        b /= 1024
    return f"{b:.2f} PB"

LIMIT_LABELS = {1: "100 GB", 2: "200 GB", 3: "500 GB", 4: "800 GB", 5: "1 TB", 6: "♾️ Ilimitado", 0: "♾️ Ilimitado"}
CONSUMO_BYTES = {1: 107374182400, 2: 214748364800, 3: 536870912000, 4: 858993459200, 5: 1099511627776, 6: 0, 0: 0}

def crear_usuario(user: str, password: str, dias: int = 30, limite: int = 0,
                  opc_consumo: int = 6, gb_bytes: int = 0):
    """Réplica exacta de usuarios/add.sh. Devuelve (ok, msg).
    dias<=0  → sin expiración (useradd sin -e + chage -E -1).
    gb_bytes>0 → escribe ese consumo límite directo en bytes (si no, usa niveles opc_consumo)."""
    if not user or not password:
        return False, "Usuario y contraseña requeridos"
    if exists_user(user):
        return False, "El usuario ya existe"
    if limite is None:
        limite = 0
    if opc_consumo not in CONSUMO_BYTES:
        opc_consumo = 6
    dias = int(dias or 0)
    # useradd (con expiración o sin ella)
    if dias > 0:
        fecha = (datetime.now() + timedelta(days=dias)).strftime("%Y-%m-%d")
        code, err = sh_json(f'useradd -e "{fecha}" -M -s /usr/sbin/nologin "{user}" 2>&1')
        if code != 0:
            return False, err or "Error al crear el usuario"
    else:
        code, err = sh_json(f'useradd -M -s /usr/sbin/nologin "{user}" 2>&1')
        if code != 0:
            return False, err or "Error al crear el usuario"
        sh_json(f'chage -E -1 "{user}" 2>/dev/null')
    # passwd sin PAM (openssl passwd -6)
    code, err = sh_json(f'HASH=$(openssl passwd -6 "{password}" 2>/dev/null); usermod -p "$HASH" "{user}" 2>&1')
    if code != 0:
        sh_json(f'userdel -f "{user}" 2>/dev/null')
        return False, err or "Error al establecer la contraseña"
    # límite consumo
    bytes_ = gb_bytes if gb_bytes and gb_bytes > 0 else CONSUMO_BYTES.get(opc_consumo, 0)
    _set_conf_line(f"{SYS_DIR}/limites_consumo.conf", user, str(bytes_))
    # límite conexiones
    _set_conf_line(f"{SYS_DIR}/limites_conexiones.conf", user, str(int(limite)))
    log(f"Usuario creado: {user} (dias={dias} lim={limite} consumo={opc_consumo} gb_bytes={gb_bytes})")
    return True, "ok"

def _set_conf_line(path: str, key: str, value: str):
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        lines = []
        if os.path.exists(path):
            with open(path, "r", encoding="utf-8", errors="replace") as f:
                lines = [l for l in f if not l.startswith(f"{key}=")]
        with open(path, "w", encoding="utf-8") as f:
            f.writelines(lines)
            f.write(f"{key}={value}\n")
    except Exception:
        pass

def bloquear_user(user: str):
    code, _ = sh_json(f'passwd -l "{user}" 2>&1')
    if code == 0:
        hist("bloquear", user)
    return code == 0

def desbloquear_user(user: str):
    code, _ = sh_json(f'passwd -u "{user}" 2>&1')
    if code == 0:
        hist("desbloquear", user)
    return code == 0

def renovar_user(user: str, dias: int):
    fecha = (datetime.now() + timedelta(days=int(dias))).strftime("%Y-%m-%d")
    code, _ = sh_json(f'chage -E "{fecha}" "{user}" 2>&1')
    if code == 0:
        hist("renovar", f"{user} +{dias}d")
    return code == 0

def eliminar_user(user: str):
    code, _ = sh_json(f'pkill -u "{user}" 2>/dev/null; userdel -f "{user}" 2>&1')
    for conf in ("limites_consumo.conf", "limites_conexiones.conf", "consumo_usuarios.conf"):
        _set_conf_line(f"{SYS_DIR}/{conf}", user, "")  # no-op para limpiar entrada
        _rm_line(f"{SYS_DIR}/{conf}", user)
    if code == 0:
        hist("eliminar", user)
    return code == 0

def _rm_line(path: str, key: str):
    try:
        if not os.path.exists(path):
            return
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            lines = [l for l in f if not l.startswith(f"{key}=")]
        with open(path, "w", encoding="utf-8") as f:
            f.writelines(lines)
    except Exception:
        pass

# ═══════════════════════════════════════════════════════════
# PLANTILLA DE ENTREGA (réplica de add.sh líneas 184-534)
# ═══════════════════════════════════════════════════════════
def build_plantilla(user: str, password: str, expira: str = "", limite: int = 0,
                    consumo_label: str = "♾️ Ilimitado", pkg: str = "") -> dict:
    cfg = load_conf()
    IP = get_host_info()["ip"]
    HOST = cfg.get("SERVER_DOMAIN") or IP
    FECHA_MOSTRAR = expira or (datetime.now() + timedelta(days=30)).strftime("%d/%m/%Y")
    LIMITE_MOSTRAR = "♾️ Ilimitado" if (limite is None or limite == 0) else f"{limite} Conexión(es)"
    CONSUMO_MOSTRAR = consumo_label

    # ...datos reales sistema
    metricas = get_metrics()

    # puertos por protocolo (como add.sh)
    def port_if(key, val, extra=""):
        return val if cfg.get(key) == "ON" else "✘"
    P = {}
    P["SSH"]     = port_if("OPENSSH", "22")
    P["DROPBEAR"]= port_if("DROPBEAR", cfg.get("DROPBEAR_PORT", "143"))
    P["SSL"]     = port_if("SSL", "80 | 443 | 8080 | 8443")
    P["BADVPN"]  = port_if("BADVPN", "1-7300")
    P["UDP"]     = port_if("UDP_CUSTOM", f"1-{cfg.get('UDP_CUSTOM_PORT', '2100')}")
    P["ZIP"]     = port_if("ZIPVPN", cfg.get("ZIPVPN_PORT", "24075"))
    P["HTTP"]    = port_if("WEBSOCKET", "80")
    P["WS"]      = port_if("WEBSOCKET", "8080")
    P["WSS"]     = port_if("WEBSOCKET", "8880")
    P["XRAY"]    = port_if("V2RAY", f'{cfg.get("XRAY_PORT", "443")} | 80 | 8080')
    P["HYSTERIA"]= port_if("HYSTERIA", cfg.get("HYSTERIA_PORT", "13901"))
    P["SQUID"]   = port_if("SQUID", cfg.get("SQUID_PORT", "3128"))
    P["WG"]      = port_if("WG", cfg.get("WG_PORT", "51820"))
    P["SYSTEMDNS"]= port_if("SYSTEMDNS", "53")
    P["XHTTP"]   = port_if("XHTTP", f'{cfg.get("XHTTP_PORT", "443")} | {cfg.get("XHTTP_PORT2", "8080")}')
    P["BHTTP"]   = port_if("BHTTP", f'{cfg.get("BHTTP_PORT", "80")} | {cfg.get("BHTTP_XPORT", "8443")}')
    P["BTUN"]    = port_if("BTUN", cfg.get("BTUN_PORT", "7900"))
    P["SS"]      = port_if("SHADOWSOCKS", cfg.get("SHADOWSOCKS_PORT", "8388"))
    P["PAYLOAD"] = port_if("PAYLOAD", cfg.get("PAYLOAD_PORT", "8082-8085"))
    P["OPENVPN"] = port_if("OPENVPN", cfg.get("OPENVPN_PORT", "1194"))
    P["SOCKS5"]  = port_if("SOCKS5", cfg.get("SOCKS5_PORT", "1080"))
    P["HCR"]     = port_if("HCR", f"443 (TLS · SNI {cfg.get('HCR_SNI', 'hcr')})")
    P["ONLINEAPP"]= port_if("ONLINEAPP", "8888")

    # datos específicos
    NS_DNS = cfg.get("SLOWDNS_NS") or (f"ns.{cfg['SERVER_DOMAIN']}" if cfg.get("SERVER_DOMAIN") else "")
    KEY_DNS = cfg.get("SLOWDNS_KEY") or ""
    if not NS_DNS and os.path.exists("/etc/slowdns/domain.conf"):
        NS_DNS = sh("head -1 /etc/slowdns/domain.conf 2>/dev/null")
    if not KEY_DNS and os.path.exists("/etc/slowdns/server.pub"):
        KEY_DNS = sh("cat /etc/slowdns/server.pub 2>/dev/null")
    NS_DNS = NS_DNS or "ns1.movivipoppax.uk"
    KEY_DNS = KEY_DNS or "No configurado"

    PAYLOAD_HOST = cfg.get("CLOUDFRONT_DOMAIN") or cfg.get("SERVER_DOMAIN") or IP

    DT_TOKEN = cfg.get("DTUNNEL_TOKEN", "")
    DT_PORT1 = ""; DT_PORT2 = ""
    if os.path.exists("/etc/proto-server/config.json"):
        DT_PORT1 = sh("grep -A3 '\"ssl\": true' /etc/proto-server/config.json 2>/dev/null | grep -oE '\"port\": *[0-9]+' | grep -oE '[0-9]+' | head -1")
        DT_PORT2 = sh("grep -A3 '\"ssl\": false' /etc/proto-server/config.json 2>/dev/null | grep -oE '\"port\": *[0-9]+' | grep -oE '[0-9]+' | head -1")
        DT_PORT1 = DT_PORT1 or "4443"; DT_PORT2 = DT_PORT2 or "8082"
    P_DTUNNEL = "" if not (DT_PORT1 and DT_PORT2) else f"{DT_PORT1} | {DT_PORT2}"

    HY_PASSWORD = cfg.get("HYSTERIA_AUTH", "")
    HY_OBFS = cfg.get("HYSTERIA_OBFS", "")

    WG_SERVER_PUB = sh("cat /etc/wireguard/server.pub 2>/dev/null") or sh("wg show wg0 public-key 2>/dev/null")

    BTUN_USER = ""; BTUN_PASS = ""
    if os.path.exists("/etc/btun/users"):
        bt = sh("head -n1 /etc/btun/users 2>/dev/null")
        if ":" in bt:
            BTUN_USER, BTUN_PASS = bt.split(":", 1)

    XHTTP_HOST_V = cfg.get("XHTTP_HOST") or cfg.get("SERVER_DOMAIN") or IP
    BHTTP_HOST_V = cfg.get("BHTTP_HOST") or cfg.get("SERVER_DOMAIN") or IP

    SS_URL = ""
    if cfg.get("SHADOWSOCKS") == "ON" and cfg.get("SS_PASSWORD"):
        SS_METHOD = "aes-256-gcm"
        SS_PORT = cfg.get("SS_PORT", "8388")
        SS_PASS = cfg.get("SS_PASSWORD", "")
        SS_B64 = base64.b64encode(f"{SS_METHOD}:{SS_PASS}@{IP}:{SS_PORT}".encode()).decode()
        SS_URL = f"ss://{SS_B64}#MoviVIP"

    PAY_MASTER = ""; PAY_TEMP = ""
    if os.path.exists("/etc/movivip/payload/pwd.pwd"):
        PAY_MASTER = sh("grep '^master=' /etc/movivip/payload/pwd.pwd 2>/dev/null | cut -d= -f2")
        PAY_TEMP = sh("grep -E '^[0-9.]+:22=' /etc/movivip/payload/pwd.pwd 2>/dev/null | cut -d= -f2")

    # ---------- ESTRUCTURA DE SECCIONES ----------
    info = [
        ("👤 Usuario", user), ("🔑 Contraseña", password),
        ("📅 Expira", FECHA_MOSTRAR), ("🌐 Límite", LIMITE_MOSTRAR),
        ("📊 Consumo Máx", CONSUMO_MOSTRAR),
    ]
    servidor = [
        ("🖥️ Servidor", cfg.get("SERVER_DOMAIN") or IP), ("📍 IP Principal", IP),
        ("💻 CPU", metricas["cpu_model"]), ("🔥 Uso CPU", metricas["cpu_uso"]),
        ("📊 RAM", f'{metricas["ram_uso_hr"]} ({metricas["ram_pct"]}%)'),
        ("💾 Disco", f'{metricas["disco"]["used"]} / {metricas["disco"]["total"]} ({metricas["disco"]["pct"]})'),
        ("⏱️ Uptime", metricas["uptime"]), ("📈 Carga", metricas["load"]),
    ]
    if cfg.get("CLOUDFRONT_DOMAIN"):
        servidor.append(("☁️ Cloudflare", cfg["CLOUDFRONT_DOMAIN"]))
    if cfg.get("NOIP_DOMAIN"):
        servidor.append(("📍 No-IP", cfg["NOIP_DOMAIN"]))

    puertos = []
    _pp = [
        ("🔑 SSH Directo", "SSH", P["SSH"]), ("🐻 Dropbear", "DROPBEAR", P["DROPBEAR"]),
        ("🔒 SSL/Stunnel", "SSL", P["SSL"]), ("🎮 BadVPN UDPGW", "BADVPN", P["BADVPN"]),
        ("⚡ UDP Custom", "UDP", P["UDP"]), ("📦 ZIPVPN", "ZIP", P["ZIP"]),
        ("🚀 v2ray (VLESS/VMess/Trojan)", "V2RAY", P["XRAY"]), ("🌀 Hysteria", "HYSTERIA", P["HYSTERIA"]),
        ("🦑 Squid Proxy", "SQUID", P["SQUID"]), ("🔗 WireGuard", "WG", P["WG"]),
        ("🌐 HTTP/PDirect3", "WEBSOCKET", P["HTTP"]), ("🌐 WebSocket WS", "WEBSOCKET", P["WS"]),
        ("🌐 WebSocket WSS", "WEBSOCKET", P["WSS"]),
        ("🐌 SlowDNS (NS/Key abajo)", "SLOWDNS", "DNS 53 / DNSTT 5300"),
        ("🧬 SystemDNS", "SYSTEMDNS", P["SYSTEMDNS"]), ("🚀 SSH-XHTTP", "XHTTP", P["XHTTP"]),
        ("📡 BHTTP v2", "BHTTP", P["BHTTP"]), ("🧵 BTUN", "BTUN", P["BTUN"]),
        ("🐋 Shadowsocks", "SHADOWSOCKS", P["SS"]), ("🧩 Payload", "PAYLOAD", P["PAYLOAD"]),
        ("🛡 OpenVPN", "OPENVPN", P["OPENVPN"]), ("🐋 SOCKS5 Proxy", "SOCKS5", P["SOCKS5"]),
        ("🚀 HCR Relay", "HCR", P["HCR"]),
        ("🤖 OnlineApp", "ONLINEAPP", f"http://{IP}:{P['ONLINEAPP']}/server/online"),
    ]
    for label, key, val in _pp:
        if val != "✘" and (key == "SLOWDNS" or cfg.get(key) == "ON"):
            puertos.append({"emoji": label.split(" ")[0], "label": label, "value": val})

    bloques = []
    if P_DTUNNEL:
        lines = [("Puertos", P_DTUNNEL)]
        if DT_TOKEN:
            lines.append(("Token", DT_TOKEN))
        bloques.append({"titulo": "🔌 DTUNNEL", "lineas": lines})
    if cfg.get("HYSTERIA") == "ON":
        lines = [("Puerto", P["HYSTERIA"])]
        if HY_PASSWORD: lines.append(("Contraseña", HY_PASSWORD))
        if HY_OBFS: lines.append(("Obfuscación", HY_OBFS))
        bloques.append({"titulo": "🌀 HYSTERIA", "lineas": lines})
    if cfg.get("WG") == "ON":
        lines = [("Puerto", P["WG"]), ("Network", "10.66.66.1/24")]
        if WG_SERVER_PUB: lines.append(("Server Public Key", WG_SERVER_PUB))
        bloques.append({"titulo": "🔗 WIREGUARD", "lineas": lines})
    if cfg.get("SYSTEMDNS") == "ON":
        bloques.append({"titulo": "🧬 SYSTEMDNS", "lineas": [("Puerto", "53"), ("Servicio", "systemd-resolved")]})
    if cfg.get("XHTTP") == "ON":
        bloques.append({"titulo": "🚀 SSH-XHTTP", "lineas": [
            ("Tipo", "SSH-XHTTP (Server publish)"), ("Servidor", f"{IP} · Puerto: {P['XHTTP']}"),
            ("SNI", XHTTP_HOST_V), ("Payload", "vacío (HTTP/2 directo)")]})
    if cfg.get("BHTTP") == "ON":
        bloques.append({"titulo": "📡 BHTTP v2", "lineas": [
            ("Tipo", "SSH-BHTTP v2 (Server publish)"),
            ("Servidor", f"{IP} · Puertos: {P['BHTTP']}"), ("Host/SNI", BHTTP_HOST_V),
            ("Payload", f"GET / HTTP/1.1[crlf]Host: {BHTTP_HOST_V}[crlf][crlf]")]})
    if cfg.get("BTUN") == "ON":
        lines = [("Modo", "VPN / Túnel (BTUN)"), ("Servidor", f"{IP} · Puerto: {P['BTUN']} (TCP+UDP)"),
                 ("Subred", "10.77.0.0/16")]
        if BTUN_USER: lines.append(("Usuario", BTUN_USER))
        if BTUN_PASS: lines.append(("Clave", BTUN_PASS))
        bloques.append({"titulo": "🧵 BTUN", "lineas": lines})
    if cfg.get("SHADOWSOCKS") == "ON":
        lines = [("Servidor", f"{IP}:{P['SS']}"), ("Método", "aes-256-gcm")]
        if cfg.get("SS_PASSWORD"): lines.append(("Clave", cfg["SS_PASSWORD"]))
        if SS_URL: lines.append(("URL", SS_URL))
        bloques.append({"titulo": "🐋 SHADOWSOCKS", "lineas": lines})
    if cfg.get("PAYLOAD") == "ON":
        lines = [
            ("PDirect", f'{cfg.get("PAY_PDIRECT", "8083")} (pass: {cfg.get("PAY_PASS", "—")})'),
            ("PGet/POpen/PPriv/PPub", f'{cfg.get("PAY_GET", "8799")} / {cfg.get("PAY_OPEN", "8082")} / {cfg.get("PAY_PRIV", "8084")} / {cfg.get("PAY_PUB", "8085")}')]
        if PAY_MASTER: lines.append(("Master PGet", PAY_MASTER))
        if PAY_TEMP: lines.append(("127.0.0.1:22", PAY_TEMP))
        lines.append(("Payload", f"GET / HTTP/1.1[crlf]Host: {IP}[crlf][crlf]"))
        bloques.append({"titulo": "🧩 PAYLOAD SERVERS", "lineas": lines})
    if cfg.get("OPENVPN") == "ON":
        bloques.append({"titulo": "🛡 OPENVPN", "lineas": [
            ("Servidor", f"{IP} · Puerto: UDP {P['OPENVPN']}"),
            ("Protocolo", "UDP · AES-256-CBC · SHA256"),
            ("Autenticación", "usuario + contraseña + certificado"),
            ("Apps", "OpenVPN Connect, KPN, HTTP Injector (OpenVPN)"),
            ("Importar", "archivo .ovpn del usuario (Protocolos → OpenVPN)")]})
    if cfg.get("SOCKS5") == "ON":
        bloques.append({"titulo": "🐋 SOCKS5 PROXY", "lineas": [
            ("Servidor", f"{IP} · Puerto: {P['SOCKS5']} (TCP)"),
            ("Autenticación", "usuario + contraseña (misma cuenta)"),
            ("Apps", "HTTP Injector (SOCKS5), Orbot, ProxyDroid"),
            ("Nota", "tráfico no cifrado, solo autenticado")]})
    if cfg.get("HCR") == "ON":
        bloques.append({"titulo": "🚀 HCR RELAY (HTTP CORE)", "lineas": [
            ("Método", "SSL/TLS + transporte HCR (HTTP Core Relay)"),
            ("Servidor", f'{cfg.get("SERVER_DOMAIN") or IP} · Puerto: 443 (TLS)'),
            ("SNI", cfg.get("HCR_SNI", "hcr")), ("User", user), ("Pass", password),
            ("App", "HTTP Custom (transporte HCR · SSL/TLS ON)")]})
    if cfg.get("ONLINEAPP") == "ON":
        bloques.append({"titulo": "🤖 ONLINEAPP (BOT GENERADOR)", "lineas": [
            ("URL", f"http://{IP}:{P['ONLINEAPP']}/server/online"),
            ("URL app", f"http://{IP}:{P['ONLINEAPP']}/server/online_app"),
            ("Nota", "genera cuentas SSH/túneles para tus clientes")]})

    payloads = [
        ("1. Normal WS (Puerto 80)", f"GET / HTTP/1.1[crlf]Host: {PAYLOAD_HOST}[crlf]Upgrade: websocket[crlf]Connection: Keep-Alive[crlf][crlf]"),
        ("2. WSS / TLS (Puerto 443 SNI)", f"GET wss://{PAYLOAD_HOST}/ HTTP/1.1[crlf]Host: {PAYLOAD_HOST}[crlf]Upgrade: Websocket[crlf]Connection: Keep-Alive[crlf][crlf]"),
        ("3. HTTP Injector (Modo SNI / Payload)", f"[method] [host_port] HTTP/1.1[crlf]Host: {PAYLOAD_HOST}[crlf]Upgrade: websocket[crlf]Connection: Keep-Alive[crlf][crlf]"),
    ]
    soporte = [
        ("📣 Canal", "@MoviVIPNetwork"), ("💬 Grupo", "@MoviVIPNet"),
        ("📍 Store", "movivip-network.web.app"), ("💬 Soporte", "@MoviVIP"),
    ]

    # texto plano (para copiar/descargar)
    txt = []
    txt.append("╔══════════════════════════════════════════╗")
    txt.append("          ◎ MoviVIP Network ◎")
    txt.append("       CUENTA SSH CREADA CON ÉXITO")
    txt.append("╚══════════════════════════════════════════╝")
    txt.append(""); txt.append("— INFORMACIÓN DE LA CUENTA —")
    for k, v in info: txt.append(f"{k:12}: {v}")
    txt.append(""); txt.append("— SERVIDOR —")
    for k, v in servidor: txt.append(f"{k:12}: {v}")
    txt.append(""); txt.append("— PUERTOS ACTIVOS (todos los protocolos) —")
    for p in puertos: txt.append(f"{p['emoji']} {p['label']}: ► {p['value']}")
    txt.append(""); txt.append("— SLOWDNS / NOIZ DNS —")
    txt.append(f"• NS: {NS_DNS}")
    txt.append(f"• Key: {KEY_DNS}")
    txt.append("• Puertos DNS: 53 / 5300")
    for b in bloques:
        txt.append(""); txt.append(f"— {b['titulo']} —")
        for k, v in b["lineas"]: txt.append(f"• {k}: {v}")
    txt.append(""); txt.append("🚀 PAYLOADS AVANZADOS CLOUDFLARE")
    for t, p in payloads:
        txt.append(f"{t}")
        txt.append(f"{p}")
    txt.append(""); txt.append("💬 SOPORTE")
    for k, v in soporte: txt.append(f"{k}: {v}")
    txt.append(""); txt.append("🙏 Gracias por ser parte de MoviVIP Network! 🔥")
    plantilla_txt = "\n".join(txt)

    return {
        "usuario": user, "informacion": info, "servidor": servidor, "puertos": puertos,
        "slowdns": {"ns": NS_DNS, "key": KEY_DNS, "puertos": "53 / 5300"},
        "bloques": bloques, "payloads": payloads, "soporte": soporte,
        "texto": plantilla_txt, "generada": _now(), "paquete": pkg,
    }

# ═══════════════════════════════════════════════════════════
# PROTOCOLOS (catálogo real del menú)
# ═══════════════════════════════════════════════════════════
PROTOCOLS = [
    {"slug": "openssh",  "nombre": "OpenSSH",      "emoji": "🔐", "key": "OPENSSH",    "svc": "ssh",                 "puertos": "22",             "script": "openssh.sh",    "desc": "Servidor SSH directo"},
    {"slug": "zipvpn",   "nombre": "ZiVPN",        "emoji": "📦", "key": "ZIPVPN",     "svc": "zivpn",               "puertos": "UDP 5667/24075", "script": "zipvpn.sh",     "desc": "Túnel ZIP-VPN"},
    {"slug": "dropbear", "nombre": "Dropbear",     "emoji": "🚪", "key": "DROPBEAR",   "svc": "dropbear_custom",     "puertos": "90,109,143",     "script": "dropbear.sh",   "desc": "SSH ligero Dropbear"},
    {"slug": "ssl",      "nombre": "SSL/TLS",      "emoji": "🔒", "key": "SSL",        "svc": "haproxy",             "puertos": "443",            "script": "ssl.sh",        "desc": "Stunnel/HAProxy SSL"},
    {"slug": "badvpn",   "nombre": "BadVPN",       "emoji": "⚡", "key": "BADVPN",     "svc": "badvpn-udpgw-7200",   "puertos": "7200,7300",      "script": "badvpn.sh",     "desc": "UDPGW BadVPN"},
    {"slug": "udpcustom","nombre": "UDP Custom",   "emoji": "🚀", "key": "UDP_CUSTOM", "svc": "udp-custom",          "puertos": "2100",           "script": "udpcustom.sh",  "desc": "Túnel UDP Custom"},
    {"slug": "slowdns",  "nombre": "SlowDNS",      "emoji": "🌐", "key": "SLOWDNS",    "svc": "slowdns",             "puertos": "53/5300",        "script": "slowdns.sh",    "desc": "DNS Túnel SlowDNS"},
    {"slug": "xray",     "nombre": "Xray",         "emoji": "☁️", "key": "V2RAY",      "svc": "xray",                "puertos": "443",            "script": "v2ray.sh",      "desc": "VMess/VLESS/Trojan"},
    {"slug": "hysteria", "nombre": "Hysteria",     "emoji": "🚀", "key": "HYSTERIA",   "svc": "hysteria1-server",    "puertos": "UDP 13901",      "script": "hysteria.sh",   "desc": "Proxy QUIC Hysteria"},
    {"slug": "wireguard","nombre": "WireGuard",    "emoji": "🛡", "key": "WG",         "svc": "wg-quick@wg0",        "puertos": "UDP 51820",      "script": "wireguard.sh",  "desc": "VPN WireGuard"},
    {"slug": "dtunnel",  "nombre": "DTunnel",      "emoji": "🛰", "key": "DTUNNEL",    "svc": "proto-server",        "puertos": "4443/8081",      "script": "dtunnel.sh",    "desc": "Túnel DTunnel (temurin)"},
    {"slug": "systemdns","nombre": "SystemDNS",    "emoji": "🌐", "key": "SYSTEMDNS",  "svc": "systemd-resolved",    "puertos": "53",             "script": "systemdns.sh",  "desc": "DNS del sistema"},
    {"slug": "squid",    "nombre": "Squid",        "emoji": "🌐", "key": "SQUID",      "svc": "squid",               "puertos": "3128",           "script": "squid.sh",      "desc": "Proxy Squid"},
    {"slug": "webmin",   "nombre": "Webmin",       "emoji": "🛠", "key": "WEBMIN",     "svc": "webmin",              "puertos": "10000",          "script": "webmin.sh",     "desc": "Webmin administrativo"},
    {"slug": "bot",      "nombre": "Bot Telegram", "emoji": "🤖", "key": "BOT",        "svc": "movivip-*-admin",     "puertos": "gestión",        "script": "bot.sh",        "desc": "Bot admin Telegram"},
    {"slug": "xhttp",    "nombre": "SSH-XHTTP",    "emoji": "🚀", "key": "XHTTP",      "svc": "xhttp",               "puertos": "443/8080",       "script": "xhttp.sh",      "desc": "Túnel XHTTP"},
    {"slug": "bhttp",    "nombre": "BHTTP v2",     "emoji": "📡", "key": "BHTTP",      "svc": "bhttp",               "puertos": "80/8443",        "script": "bhttp.sh",      "desc": "Túnel BHTTP v2"},
    {"slug": "btun",     "nombre": "BTUN",         "emoji": "🧵", "key": "BTUN",       "svc": "btun",                "puertos": "7300",           "script": "btun.sh",       "desc": "VPN/Túnel BTUN"},
    {"slug": "shadowsocks","nombre": "Shadowsocks","emoji": "🐋", "key": "SHADOWSOCKS","svc": "shadowsocks-libev-server@8388", "puertos": "8388", "script": "shadowsocks.sh", "desc": "Proxy cifrado SS"},
    {"slug": "payload",  "nombre": "Payload",      "emoji": "🧩", "key": "PAYLOAD",    "svc": "payload-pdirect",     "puertos": "8082-8085",      "script": "payload.sh",    "desc": "Payload servers"},
    {"slug": "openvpn",  "nombre": "OpenVPN",      "emoji": "🗝", "key": "OPENVPN",    "svc": "openvpn@server",      "puertos": "UDP 1194",       "script": "openvpn.sh",    "desc": "VPN OpenVPN"},
    {"slug": "socks5",   "nombre": "SOCKS5",       "emoji": "🕸", "key": "SOCKS5",     "svc": "sockd",               "puertos": "TCP 1080",       "script": "socks5.sh",     "desc": "Proxy SOCKS5"},
    {"slug": "hcr",      "nombre": "HCR Relay",    "emoji": "🧱", "key": "HCR",        "svc": "hcr",                 "puertos": "SNI hcr · 443⇄8880", "script": "hcr.sh", "desc": "HTTP Core Relay"},
]

def get_protocolos():
    cfg = load_conf()
    out = []
    for p in PROTOCOLS:
        conf = cfg.get(p["key"], "OFF")
        # exit codes de systemctl status: 0=active, 1=failed, 3=inactive, 4=no existe unidad
        code, _ = sh_json(f'systemctl status {p["svc"]} >/dev/null 2>&1', timeout=8)
        svc_exists = code != 4
        active = code == 0
        out.append({
            "slug": p["slug"], "nombre": p["nombre"], "emoji": p["emoji"],
            "key": p["key"], "conf": conf, "svc": p["svc"], "puertos": p["puertos"],
            "script": p["script"], "desc": p["desc"], "activo": active,
            "instalado": svc_exists or active, "script_path": f"{BASE_MV}/protocolos/{p['script']}",
        })
    return out

def get_herramientas():
    items = []
    names = ["blocktorrent","archivoonline","speedtest","detalles","blockads","rootpass",
             "scanner","fail2ban","auditoria","seguridad","firewall","openports","optimizar",
             "reiniciar","network_traffic","change-domain","ddos","setup-bot-generador",
             "generador-licencias","instalar_apiaccess","hwid_quota_monitor","monitorlive",
             "network_snapshot","filebrowser","checkuser","bot-generador","openports"]
    labels = {
        "blocktorrent": ("🧲", "Block Torrent"), "archivoonline": ("📤", "Archivo Online"),
        "speedtest": ("🚀", "Speedtest"), "detalles": ("ℹ️", "Detalles VPS"),
        "blockads": ("🚫", "Block Ads"), "rootpass": ("🔑", "Cambiar Contraseña Root"),
        "scanner": ("🕵", "Scanner host/dominio"), "fail2ban": ("🛡", "Fail2ban"),
        "auditoria": ("🔍", "Auditoría completa"), "seguridad": ("🐛", "Anti-Minero / Scan"),
        "firewall": ("🧱", "Firewall"), "openports": ("🔓", "Open Ports"),
        "optimizar": ("⚡", "Optimizar VPS"), "reiniciar": ("🔄", "Reiniciar Servicios"),
        "network_traffic": ("📊", "Consumo de Red"), "change-domain": ("🌐", "Cambiar Dominio"),
        "ddos": ("💣", "DDOS Test"), "setup-bot-generador": ("🎫", "Bot Generador"),
        "generador-licencias": ("🔑", "Generador de Licencias"),
        "instalar_apiaccess": ("🔌", "API Access"),
        "hwid_quota_monitor": ("📈", "HWID Quota Monitor"), "monitorlive": ("🖥", "Monitor Live"),
        "network_snapshot": ("📸", "Network Snapshot"), "filebrowser": ("🗂", "FileBrowser"),
        "checkuser": ("🔍", "CheckUser"), "bot-generador": ("🤖", "Bot Admin"),
    }
    for n in names:
        path = f"{BASE_MV}/herramientas/{n}.sh"
        emoji, label = labels.get(n, ("🛠", n))
        items.append({"slug": n, "nombre": label, "emoji": emoji, "path": path,
                      "existe": os.path.exists(path)})
    return items

# ═══════════════════════════════════════════════════════════
# CONEXIONES ACTIVAS (estadísticas usuarios conectados por protocolo)
# ═══════════════════════════════════════════════════════════
PLA = "/opt/movivip-web"
ONLINE_SH = "/etc/movivip/usuarios/online.sh"
def _strip_ansi(s):
    return re.sub(r"\x1b\[[0-9;]*m", "", s)

def _parse_online():
    """Ejecuta el online.sh del ecosistema (fuente oficial de usuarios online
    por protocolo). Devuelve dict o None si no se pudo parsear."""
    try:
        out = sh("bash " + ONLINE_SH + " 2>/dev/null </dev/null", timeout=20)
    except Exception:
        return None
    if not out:
        return None
    txt = _strip_ansi(out)
    lines = txt.splitlines()
    resumen, online, consumo = [], [], []
    in_net, in_online, in_consumo = False, False, False
    for ln in lines:
        s = ln.strip()
        if "CONEXIONES POR PROTOCOLO" in ln:
            in_net, in_online, in_consumo = True, False, False
            continue
        if "USUARIOS ONLINE" in ln.upper():
            in_net, in_online, in_consumo = False, True, False
            continue
        if "CONSUMO GB" in ln:
            in_net, in_online, in_consumo = False, False, True
            continue
        m = re.match(r"^(?:\[[\*X ]\]\s*)?(.+?)\s*\[([0-9,\s]+)\]\s*:\s*(\d+)\s*$", s)
        if in_net and m:
            nombre = m.group(1).strip()
            puertos = m.group(2).replace(" ", "")
            count = int(m.group(3))
            emoji = "📡"
            if "xray" in nombre.lower() or "v2ray" in nombre.lower():
                emoji = "☁️"
            elif "ssh" in nombre.lower() or "dropbear" in nombre.lower():
                emoji = "🔐"
            elif "udp" in nombre.lower() or "badvpn" in nombre.lower():
                emoji = "📶"
            elif "zip" in nombre.lower():
                emoji = "🔺"
            resumen.append({"slug": nombre.lower().replace(" ", "-").replace("/", "-"),
                            "nombre": nombre, "emoji": emoji, "conexiones": count,
                            "puertos": [int(x) for x in re.findall(r"\d+", puertos) or []],
                            "activo": count > 0})
            continue
        if in_online:
            m2 = re.match(r"^\|\s*(\d+)\s*\|\s*([^|]+?)\s*\|\s*(\d+)\s*\|$", s)
            if m2:
                online.append({"id": m2.group(1), "usuario": m2.group(2).strip(),
                               "conexiones": int(m2.group(3))})
                continue
            if "Online" in ln and ":" in ln:
                continue
        if in_consumo:
            m3 = re.match(r"^\|\s*(\d+)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|$", s)
            if m3 and "%" not in s:
                consumo.append({"id": m3.group(1), "usuario": m3.group(2).strip(),
                                "consumo": m3.group(3).strip(),
                                "limite": m3.group(4).strip(),
                                "pct": m3.group(5).strip()})
                continue
        if in_net and "Total Protocolos" in ln or "TOTAL GENERAL" in ln:
            continue
    if not resumen and not online and not consumo:
        return None
    return {"resumen": resumen, "online": online, "consumo": consumo}

def _xray_limites():
    """Lee el registro de límites de clientes Xray creados desde el panel."""
    out = []
    p = PLA + "/xray_limites.conf"
    if not os.path.exists(p):
        return out
    try:
        with open(p, encoding="utf-8") as f:
            for ln in f:
                ln = ln.strip()
                if not ln or ln.startswith("#"):
                    continue
                parts = ln.split("|")
                if len(parts) < 4:
                    continue
                user, exp, gb, mx = parts[0], parts[1], parts[2], parts[3]
                expira = datetime.fromtimestamp(float(exp)).strftime("%d/%m/%Y") if exp.isdigit() and float(exp) > 0 else "∞"
                out.append({"usuario": user, "expira": expira, "exp_ts": int(float(exp)) if exp.isdigit() else 0,
                            "consumo_gb": gb, "conexiones": mx})
    except Exception:
        pass
    return out

# Protocolos cuyo "crear credencial" = crear usuario SSH del sistema (mismo user + límites + plantilla).
# Incluye SOCKS5: dante usa PAM sobre la MISMA cuenta Linux (socksmethod: username).
SSH_PROTO = {"openssh": "OpenSSH", "dropbear": "Dropbear", "ssl": "SSL/TLS",
             "udpcustom": "UDP Custom", "slowdns": "SlowDNS",
             "xhttp": "SSH-XHTTP", "bhttp": "BHTTP v2", "socks5": "SOCKS5"}

def _lim_cred(tipo: str, identidad: str, exp_ts: int = 0, gb: str = "", conn: str = ""):
    """Escribe/actualiza un límite de credencial no-SSH (BTUN/ZiVPN) en credenciales_limites.conf."""
    p = PLA + "/credenciales_limites.conf"
    try:
        os.makedirs(PLA, exist_ok=True)
        lines = []
        if os.path.exists(p):
            with open(p, encoding="utf-8") as f:
                lines = [ln for ln in f if not ln.startswith(f"{tipo}|{identidad}|")]
        if exp_ts or gb or conn:
            lines.append(f"{tipo}|{identidad}|{exp_ts}|{gb or '∞'}|{conn or '∞'}\n")
        with open(p, "w", encoding="utf-8") as f:
            f.writelines(lines)
        os.chmod(p, 0o600)
    except Exception:
        pass

def _otras_limites():
    """Lee el registro de límites de credenciales no-SSH (BTUN/ZiVPN)."""
    out = []
    p = PLA + "/credenciales_limites.conf"
    if not os.path.exists(p):
        return out
    try:
        with open(p, encoding="utf-8") as f:
            for ln in f:
                ln = ln.strip()
                if not ln or ln.startswith("#"):
                    continue
                parts = ln.split("|")
                if len(parts) < 5:
                    continue
                tipo, ident, exp, gb, mx = parts[0], parts[1], parts[2], parts[3], parts[4]
                expira = datetime.fromtimestamp(float(exp)).strftime("%d/%m/%Y") if exp.isdigit() and float(exp) > 0 else "∞"
                out.append({"tipo": tipo, "identidad": ident, "expira": expira,
                            "exp_ts": int(float(exp)) if exp.isdigit() else 0,
                            "consumo_gb": gb, "conexiones": mx})
    except Exception:
        pass
    return out

def _ports_by_slug():
    """Mapa puerto -> slugs de protocolo según PROTOCOLS (aproximación estática)."""
    m = {}
    for p in PROTOCOLS:
        toks = re.findall(r"\d+", p["puertos"].replace("/", " ").replace(",", " ").replace("-", " ").replace("⇄", " "))
        for t in toks:
            m.setdefault(int(t), []).append(p["slug"])
    return m

def get_conexiones():
    """Usuarios/conexiones activas por protocolo (fuente: online.sh del ecosistema,
    con fallback a ss por puerto). Incluye usuarios online, consumo y límites Xray."""
    protocolos = get_protocolos()
    by_slug = {p["slug"]: p for p in protocolos}

    online_sh = _parse_online()          # fuente oficial (resumen por protocolo + online + consumo)

    if online_sh:
        resumen = []
        for r in online_sh["resumen"]:
            proto = by_slug.get(r["slug"], {})
            resumen.append({"slug": r["slug"], "nombre": r["nombre"], "emoji": r["emoji"],
                            "activo": bool(proto.get("activo", r["activo"])), "conexiones": r["conexiones"],
                            "puertos": r["puertos"]})
        return {"total": sum(r["conexiones"] for r in resumen),
                "resumen": resumen,
                "online": online_sh["online"],
                "consumo": online_sh["consumo"],
                "xray_limites": _xray_limites(),
                "otras_limites": _otras_limites(),
                "fuente": "online.sh",
                "sesiones": _who_sessions()}
    return {"total": 0, "resumen": [], "online": [], "consumo": [],
            "xray_limites": _xray_limites(), "otras_limites": _otras_limites(),
            "fuente": "ss", "sesiones": _who_sessions()}

def _who_sessions():
    sesiones = []
    for ln in sh("who 2>/dev/null", timeout=8).splitlines():
        f = ln.split()
        if len(f) >= 5:
            sesiones.append({"usuario": f[0], "tty": f[1], "fecha": " ".join(f[2:5]), "origen": " ".join(f[5:]) if len(f) > 5 else ""})
        elif len(f) >= 2:
            sesiones.append({"usuario": f[0], "tty": f[1], "fecha": "", "origen": ""})
    return sesiones

# ═══════════════════════════════════════════════════════════
# TERMINAL / PTY MANAGER (consola interactiva en vivo)
# ═══════════════════════════════════════════════════════════
class TermSession:
    MAX_BUF = 1_000_000
    def __init__(self, cmd, cwd=None):
        self.tid = uuid.uuid4().hex[:12]
        self.cmd = cmd
        self.buf = deque()
        self.buf_len = 0
        self.pos = 0            # offset total de lo leído
        self.master_fd = None
        self.proc = None
        self.done = False
        self.exit_code = None
        self.lock = threading.Lock()
        self.cwd = cwd or PANEL_DIR
        self._start()

    def _start(self):
        if not hasattr(os, "openpty"):
            raise RuntimeError("pty no disponible")
        master, slave = os.openpty()
        self.master_fd = master
        env = dict(os.environ)
        env["TERM"] = "xterm-256color"
        env["LANG"] = "C.UTF-8"
        self.proc = subprocess.Popen(
            ["bash", "-c", self.cmd], stdin=slave, stdout=slave, stderr=slave,
            cwd=self.cwd, env=env, start_new_session=True, close_fds=True)
        os.close(slave)
        threading.Thread(target=self._read_loop, daemon=True).start()

    def _read_loop(self):
        try:
            while True:
                r, _, _ = select.select([self.master_fd], [], [], 0.5)
                if r:
                    try:
                        data = os.read(self.master_fd, 8192)
                    except OSError:
                        break
                    if not data:
                        break
                    with self.lock:
                        self.buf.append(data)
                        self.buf_len += len(data)
                        self.pos += len(data)
                        while self.buf_len > self.MAX_BUF:
                            old = self.buf.popleft()
                            self.buf_len -= len(old)
                if self.proc.poll() is not None:
                    # drena lo que quede
                    while True:
                        try:
                            r, _, _ = select.select([self.master_fd], [], [], 0.3)
                            if not r:
                                break
                            data = os.read(self.master_fd, 8192)
                            if not data:
                                break
                            with self.lock:
                                self.buf.append(data); self.buf_len += len(data); self.pos += len(data)
                        except OSError:
                            break
                    break
        except Exception:
            pass
        self.done = True
        self.exit_code = self.proc.poll()

    def read_since(self, offset):
        """Devuelve (bytes_nuevos, new_offset, done, exit_code)."""
        with self.lock:
            # recomponer desde inicio hasta offset no trivial: simplificamos — enviar todo nuevo desde pos guardado
            data = b"".join(self.buf)
            total = self.buf_len
            if offset >= total:
                return b"", offset, self.done, self.exit_code
            return data[offset:], total, self.done, self.exit_code

    def write(self, data: str):
        if self.master_fd is None or (self.proc and self.proc.poll() is not None):
            return False
        try:
            os.write(self.master_fd, data.encode("utf-8", errors="replace"))
            return True
        except OSError:
            return False

    def stop(self):
        if self.proc and self.proc.poll() is None:
            try:
                os.killpg(self.proc.pid, signal.SIGTERM)
            except Exception:
                pass
            try:
                self.proc.wait(timeout=3)
            except Exception:
                try:
                    os.killpg(self.proc.pid, signal.SIGKILL)
                except Exception:
                    pass
        if self.master_fd is not None:
            try:
                os.close(self.master_fd)
            except Exception:
                pass

TERMS = {}
TERMS_LOCK = threading.Lock()

def new_term(cmd: str, cwd: str = None) -> dict:
    with TERMS_LOCK:
        # limpiar sesiones muertas
        dead = [t for t, s in TERMS.items() if s.done and s.proc and s.proc.poll() is not None]
        for t in dead:
            try: TERMS[t].stop()
            except Exception: pass
            del TERMS[t]
        s = TermSession(cmd, cwd)
        TERMS[s.tid] = s
        return {"tid": s.tid, "cmd": cmd}

# ═══════════════════════════════════════════════════════════
# API ROUTES
# ═══════════════════════════════════════════════════════════
@app.get("/api/health")
def health(): return {"ok": True, "app": APP_NAME, "version": VERSION, "time": _now()}

@app.post("/api/login")
async def login(req: Request):
    body = await req.json()
    user = str(body.get("user", ""))
    passw = str(body.get("password", ""))
    if not check_root(user, passw):
        return JSONResponse(status_code=401, content={"error": "Credenciales inválidas"})
    hist("login", "root")
    return {"token": make_token(), "user": "root", "app": APP_NAME, "version": VERSION}

@app.get("/api/dashboard")
async def api_dashboard(req: Request):
    await guard(req)
    cfg = load_conf()
    m = get_metrics()
    h = get_host_info()
    return {
        "metricas": m, "host": h,
        "usuarios_total": len(list_usuarios()),
        "protocolos": get_protocolos(),
        "puertos": get_puertos(),
        "version_script": _script_version(cfg),
        "dominio": cfg.get("SERVER_DOMAIN", ""),
        "dominios": _dominios(cfg),
        "actualizado": _now(),
    }

@app.get("/api/usuarios")
async def api_usuarios(req: Request):
    await guard(req)
    return list_usuarios()

@app.get("/api/conexiones")
async def api_conexiones(req: Request):
    await guard(req)
    return get_conexiones()

@app.post("/api/xray-limites/delete")
async def api_xray_limites_delete(req: Request):
    await guard(req)
    body = await req.json()
    user = (body.get("usuario") or "").strip()
    if not user:
        return JSONResponse(status_code=400, content={"error": "Falta el usuario"})
    p = PLA + "/xray_limites.conf"
    if os.path.exists(p):
        try:
            with open(p, encoding="utf-8") as f:
                lines = [ln for ln in f if not ln.startswith(f"{user}|")]
            with open(p, "w", encoding="utf-8") as f:
                f.writelines(lines)
            return {"ok": True, "usuario": user}
        except Exception as e:
            return JSONResponse(status_code=500, content={"error": str(e)})
    return {"ok": True, "usuario": user}

@app.post("/api/credenciales-limites/delete")
async def api_credenciales_limites_delete(req: Request):
    await guard(req)
    body = await req.json()
    tipo = (body.get("tipo") or "").strip()
    ident = (body.get("identidad") or "").strip()
    if not tipo or not ident:
        return JSONResponse(status_code=400, content={"error": "tipo e identidad requeridos"})
    p = PLA + "/credenciales_limites.conf"
    if os.path.exists(p):
        try:
            with open(p, encoding="utf-8") as f:
                lines = [ln for ln in f if not ln.startswith(f"{tipo}|{ident}|")]
            with open(p, "w", encoding="utf-8") as f:
                f.writelines(lines)
            return {"ok": True, "tipo": tipo, "identidad": ident}
        except Exception as e:
            return JSONResponse(status_code=500, content={"error": str(e)})
    return {"ok": True}

@app.get("/api/usuarios/{user}/plantilla")
async def api_plantilla(req: Request, user: str):
    await guard(req)
    u = next((x for x in list_usuarios() if x["user"] == user), None)
    if not u:
        return JSONResponse(status_code=404, content={"error": "Usuario no existe"})
    pkg = req.query_params.get("paquete", "")
    consumo_label = u.get("consumo_limite", "♾️ Ilimitado")
    limite = u.get("conn_limite", 0)
    return build_plantilla(user, "••••••••", u.get("expira", ""), limite, consumo_label, pkg=pkg)

@app.post("/api/usuarios")
async def api_crear(req: Request):
    await guard(req)
    body = await req.json()
    user = str(body.get("user", "")).strip().replace(" ", "_")
    password = str(body.get("password", ""))
    dias = int(body.get("dias", 30) or 30)
    limite = int(body.get("limite", 0) or 0)
    opc_consumo = int(body.get("consumo", 6) or 6)
    pkg = str(body.get("paquete", ""))
    if not re.match(r"^[a-zA-Z0-9_.-]+$", user or ""):
        return JSONResponse(status_code=400, content={"error": "Usuario inválido (letras, números, _, ., -)"})
    ok, msg = crear_usuario(user, password, dias, limite, opc_consumo)
    if not ok:
        return JSONResponse(status_code=409, content={"error": msg})
    hist("crear", f"{user} ({LIMIT_LABELS.get(opc_consumo, '?')})")
    consumo_label = LIMIT_LABELS.get(opc_consumo, "♾️ Ilimitado")
    plantilla = build_plantilla(user, password, "", limite, consumo_label, pkg=pkg)
    return {"ok": True, "user": user, "plantilla": plantilla}

@app.post("/api/usuarios/{user}/bloquear")
async def api_bloquear(req: Request, user: str):
    await guard(req)
    return {"ok": bloquear_user(user), "user": user}

@app.post("/api/usuarios/{user}/desbloquear")
async def api_desbloquear(req: Request, user: str):
    await guard(req)
    return {"ok": desbloquear_user(user), "user": user}

@app.post("/api/usuarios/{user}/renovar")
async def api_renovar(req: Request, user: str):
    await guard(req)
    body = await req.json()
    dias = int(body.get("dias", 30) or 30)
    return {"ok": renovar_user(user, dias), "user": user, "dias": dias}

@app.delete("/api/usuarios/{user}")
async def api_eliminar(req: Request, user: str):
    await guard(req)
    return {"ok": eliminar_user(user), "user": user}

@app.get("/api/protocolos")
async def api_protocolos(req: Request):
    await guard(req)
    return get_protocolos()

@app.post("/api/protocolos/reiniciar")
async def api_reiniciar_protocolos(req: Request):
    await guard(req)
    SERVICES = ["ssh","dropbear_custom","haproxy","udp-custom","slowdns","xray",
                "hysteria1-server","badvpn-udpgw-7200","badvpn-udpgw","wg-quick@wg0",
                "proto-server","zivpn","squid","webmin","xhttp","bhttp","btun","hcr",
                "payload-pdirect","payload-pget","payload-popen","payload-ppriv",
                "payload-ppub","shadowsocks-libev-server@8388","openvpn@server","sockd"]
    ok = fail = skip = 0
    det = []
    for svc in SERVICES:
        st = sh(f'systemctl status {svc} >/dev/null 2>&1; echo $?', timeout=8)
        if st == "4":
            skip += 1; continue
        if sh(f'systemctl restart {svc} 2>/dev/null && echo OK', timeout=30) == "OK":
            ok += 1; det.append(f"{svc}:OK")
        else:
            fail += 1; det.append(f"{svc}:FAIL")
    hist("reiniciar_protocolos", f"ok={ok} fail={fail} skip={skip}")
    return {"ok": ok, "fail": fail, "skip": skip, "detalle": det}

@app.get("/api/herramientas")
async def api_herramientas(req: Request):
    await guard(req)
    return get_herramientas()

@app.get("/api/servicios")
async def api_servicios(req: Request):
    await guard(req)
    servicios = []
    try:
        r = subprocess.run(
            "systemctl list-units --type=service --all --no-legend 2>/dev/null | awk '{print $1\"|\"$3\"|\"$4}'",
            shell=True, capture_output=True, text=True, timeout=15)
        for ln in (r.stdout or "").splitlines():
            p = ln.split("|")
            if len(p) == 3:
                servicios.append({"unit": p[0], "load": p[1], "activo": p[2]})
    except Exception:
        pass
    return servicios

@app.get("/api/logs")
async def api_logs(req: Request):
    await guard(req)
    files = []
    for d in [f"{BASE_MV}/logs", DATA_DIR]:
        if os.path.isdir(d):
            for f in sorted(glob.glob(f"{d}/*"), key=os.path.getmtime, reverse=True)[:40]:
                try:
                    size = os.path.getsize(f); mtime = time.strftime("%Y-%m-%d %H:%M", time.localtime(os.path.getmtime(f)))
                    files.append({"path": f, "name": os.path.basename(f), "size": size, "mtime": mtime})
                except Exception:
                    pass
    return files

@app.get("/api/logs/content")
async def api_log_content(req: Request):
    await guard(req)
    path = req.query_params.get("path", "")
    if not path or (".." in path):
        return JSONResponse(status_code=400, content={"error": "bad path"})
    if not path.startswith(BASE_MV) and not path.startswith(DATA_DIR):
        return JSONResponse(status_code=400, content={"error": "bad path"})
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            lines = f.readlines()
        return {"path": path, "tail": "".join(lines[-300:])}
    except Exception as e:
        return JSONResponse(status_code=500, content={"error": str(e)})

@app.get("/api/historial")
async def api_historial(req: Request):
    await guard(req)
    try:
        with open(HIST_FILE, "r", encoding="utf-8") as f:
            items = json.load(f)
        return list(reversed(items))
    except Exception:
        return []

@app.get("/api/panel-log")
async def api_panel_log(req: Request):
    await guard(req)
    if os.path.exists(LOG_FILE):
        with open(LOG_FILE, "r", encoding="utf-8", errors="replace") as f:
            return {"tail": "".join(f.readlines()[-400:])}
    return {"tail": ""}

# ---------- CREDENCIALES DE PROTOCOLOS ----------
# Crear/regenerar usuarios o contraseñas de cada protocolo SIN abrir su consola.
# Replica exacta de las rutinas reales de los scripts MoviVIP:
#   ss      → /etc/shadowsocks-libev/{puerto}.json + SS_PASSWORD en config.conf
#   hysteria→ /etc/hysteria/config.json (auth password + obfs) + config.conf
#   btun    → /etc/btun/users (usuario:clave, auth-file)
#   xray-*  → /usr/local/etc/xray/config.json (inbounds: 0=vmess,1=vless,2=trojan)
#   zivpn   → /etc/zivpn/config.json (.auth.config) + expira.conf/limites.conf
#   payload → /etc/movivip/payload/pwd.pwd (master + 127.0.0.1:22)

def gen_key(n=16):
    alpha = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    return "".join(secrets.choice(alpha) for _ in range(n))

def shq(s):
    return "'" + str(s).replace("'", "'\\''") + "'"

def safe_ident(s, extra=""):
    """Valida identificadores (usuario/email) para evitar injection shell."""
    import re as _re
    if not s or not _re.fullmatch(r"[A-Za-z0-9_" + extra + r"]{1,40}", s):
        return ""
    return s

def conf_set_kv(path, key, value):
    try:
        lines = []
        if os.path.exists(path):
            with open(path, "r", encoding="utf-8", errors="replace") as f:
                lines = f.readlines()
        found = False
        for i, ln in enumerate(lines):
            if ln.strip().startswith(key + "="):
                lines[i] = f"{key}={value}\n"
                found = True
                break
        if not found:
            if lines and not lines[-1].endswith("\n"):
                lines[-1] += "\n"
            lines.append(f"{key}={value}\n")
        with open(path, "w", encoding="utf-8") as f:
            f.writelines(lines)
        return True
    except Exception:
        return False

def ss_url_for(passw, port, ip):
    return f"ss://{base64.b64encode(f'aes-256-gcm:{passw}@{ip}:{port}'.encode()).decode()}#MoviVIP"

@app.get("/api/credenciales")
async def api_credenciales(req: Request):
    await guard(req)
    cfg = load_conf()
    ip = get_host_info()["ip"]
    out = {}
    # Shadowsocks
    ss_confs = glob.glob("/etc/shadowsocks-libev/*.json")
    ss_pass = cfg.get("SS_PASSWORD", "")
    ss_port = cfg.get("SS_PORT", "8388")
    for _c in ss_confs:
        try:
            _j = json.load(open(_c, encoding="utf-8"))
            ss_port = str(_j.get("server_port", ss_port))
            ss_pass = _j.get("password", ss_pass)
        except Exception:
            pass
    out["ss"] = {"instalado": bool(ss_confs), "puerto": ss_port, "clave": ss_pass,
                 "ss_url": ss_url_for(ss_pass, ss_port, ip) if ss_pass else ""}
    # Hysteria
    out["hysteria"] = {"instalado": os.path.exists("/etc/hysteria/config.json"),
                       "puerto": cfg.get("HYSTERIA_PORT", ""), "auth": cfg.get("HYSTERIA_AUTH", ""),
                       "obfs": cfg.get("HYSTERIA_OBFS", "")}
    # BTUN
    bt_users = []
    if os.path.exists("/etc/btun/users"):
        try:
            for ln in open("/etc/btun/users", encoding="utf-8", errors="replace"):
                ln = ln.strip()
                if ":" in ln and not ln.startswith("#"):
                    u, p = ln.split(":", 1)
                    bt_users.append({"usuario": u, "clave": p})
        except Exception:
            pass
    out["btun"] = {"instalado": bool(bt_users) or os.path.exists("/etc/btun/users"),
                   "puerto": cfg.get("BTUN_PORT", "7900"), "usuarios": bt_users}
    # Xray — detecta inbounds por protocolo real (no asume orden fijo 0/1/2)
    def _xray_idx(proto):
        o = sh(f"jq -r '.inbounds | to_entries[] | select(.value.protocol==\"{proto}\") | .key' {xc} 2>/dev/null")
        return o.splitlines()[0] if o.strip() else ""
    xc = "/usr/local/etc/xray/config.json"
    xray_inst = os.path.exists(xc)
    xr = {"instalado": xray_inst, "vless": [], "vmess": [], "trojan": [], "puertos": {}}
    if xray_inst:
        for t, proto in (("vmess", "vmess"), ("vless", "vless"), ("trojan", "trojan")):
            idx = _xray_idx(proto)
            if not idx:
                continue
            em = sh(f"jq -r '.inbounds[{idx}].settings.clients[]?.email // empty' {xc} 2>/dev/null")
            port = sh(f"jq -r '.inbounds[{idx}].port // empty' {xc} 2>/dev/null")
            xr[t] = [x for x in em.splitlines() if x]
            xr["puertos"][t] = port
    out["xray"] = xr
    # ZiVPN
    zc = "/etc/zivpn/config.json"
    ziv = {"instalado": os.path.exists(zc), "passwords": []}
    if os.path.exists(zc):
        pws = sh(f"jq -r '.auth.config[]? // empty' {zc} 2>/dev/null")
        ziv["passwords"] = [x for x in pws.splitlines() if x]
    out["zivpn"] = ziv
    # Payload
    pf = "/etc/movivip/payload/pwd.pwd"
    pay = {"instalado": os.path.exists(pf), "master": "", "temp": ""}
    if os.path.exists(pf):
        try:
            for ln in open(pf, encoding="utf-8", errors="replace"):
                ln = ln.strip()
                if ln.startswith("master="):
                    pay["master"] = ln.split("=", 1)[1]
                elif ln.startswith("127.0.0.1:22="):
                    pay["temp"] = ln.split("=", 1)[1]
        except Exception:
            pass
    out["payload"] = pay
    return out

@app.get("/api/globales-cred")
async def api_globales_cred(req: Request):
    """Credenciales GLOBALES del servidor (hysteria/shadowsocks/payload/badvpn).
    Son únicas por VPS — no por usuario. Solo lectura informativa."""
    await guard(req)
    ip = get_host_info()["ip"]
    out = {}
    # Hysteria (auth + obfs globales en config.json)
    hy = {"instalado": False, "puerto": "", "auth": "", "obfs": ""}
    if os.path.exists("/etc/hysteria/config.json"):
        try:
            j = json.load(open("/etc/hysteria/config.json", encoding="utf-8"))
            hy["instalado"] = True
            hy["puerto"] = str(j.get("listen", "")).lstrip(":")
            hy["auth"] = j.get("auth", {}).get("config", {}).get("password", "")
            hy["obfs"] = j.get("obfs", "")
        except Exception:
            pass
    out["hysteria"] = hy
    # Shadowsocks (puerto/clave globales)
    sso = {"instalado": False, "puerto": "", "clave": "", "metodo": "aes-256-gcm", "ss_url": ""}
    ss_confs = glob.glob("/etc/shadowsocks-libev/*.json")
    if ss_confs:
        try:
            j = json.load(open(ss_confs[0], encoding="utf-8"))
            sso["instalado"] = True
            sso["puerto"] = str(j.get("server_port", ""))
            sso["clave"] = j.get("password", "")
            sso["metodo"] = j.get("method", "aes-256-gcm")
            if sso["clave"]:
                sso["ss_url"] = ss_url_for(sso["clave"], sso["puerto"], ip)
        except Exception:
            pass
    out["shadowsocks"] = sso
    # Payload (master/temp globales)
    pf = "/etc/movivip/payload/pwd.pwd"
    pay = {"instalado": os.path.exists(pf), "modos": ["pdirect", "pget", "popen", "ppriv", "ppub"],
           "puertos": "8082-8085", "master": "", "temp": ""}
    if pay["instalado"]:
        try:
            for ln in open(pf, encoding="utf-8", errors="replace"):
                ln = ln.strip()
                if ln.startswith("master="):
                    pay["master"] = ln.split("=", 1)[1]
                elif ln.startswith("127.0.0.1:22="):
                    pay["temp"] = ln.split("=", 1)[1]
        except Exception:
            pass
    out["payload"] = pay
    # BadVPN (auxiliar, sin credencial)
    out["badvpn"] = {
        "instalado": sh("systemctl is-active badvpn-udpgw-7200 2>/dev/null") == "active"
                     or os.path.exists("/etc/systemd/system/badvpn-udpgw-7200.service"),
        "puertos": "7200 (VoIP) y 7300 (Juegos)",
        "nota": "UDPGW auxiliar — sin credencial propia. Acelera OpenVPN/SOCKS5/HCR."}
    return out

@app.post("/api/credenciales")
async def api_credenciales_create(req: Request):
    await guard(req)
    body = await req.json()
    proto = str(body.get("protocolo", "")).strip()
    user = safe_ident(str(body.get("user", "")).strip(), ".-")
    passw = str(body.get("pass", "")).strip()[:40]
    dias = str(body.get("dias", "")).strip()
    gb = str(body.get("gb", "")).strip()
    cfg = load_conf()
    ip = get_host_info()["ip"]

    # ── Shadowsocks: regenerar clave ──
    if proto == "ss":
        if not passw:
            passw = gen_key()
        if not passw.isalnum():
            return JSONResponse(status_code=400, content={"error": "Clave solo alfanumérica"})
        ss_confs = glob.glob("/etc/shadowsocks-libev/*.json")
        if not ss_confs:
            return JSONResponse(status_code=400, content={"error": "Shadowsocks no está instalado"})
        conf = ss_confs[0]
        try:
            with open(conf, "r", encoding="utf-8") as f:
                j = json.load(f)
            j["server_port"] = int(j.get("server_port", 8388))
            j["password"] = passw
            j["method"] = "aes-256-gcm"
            with open(conf, "w", encoding="utf-8") as f:
                json.dump(j, f, indent=2)
            os.chmod(conf, 0o644)
        except Exception as e:
            return JSONResponse(status_code=500, content={"error": f"config ss: {e}"})
        conf_set_kv(CONFIG_MV, "SS_PASSWORD", passw)
        sh(f"systemctl restart shadowsocks-libev-server@{j['server_port']}")
        hist("credenciales", "shadowsocks clave regenerada")
        return {"ok": True, "protocolo": "ss", "clave": passw,
                "puerto": str(j["server_port"]), "ss_url": ss_url_for(passw, str(j["server_port"]), ip)}

    # ── Hysteria: regenerar auth + obfs ──
    if proto == "hysteria":
        hc = "/etc/hysteria/config.json"
        if not os.path.exists(hc):
            return JSONResponse(status_code=400, content={"error": "Hysteria no está instalado"})
        auth = passw or gen_key()
        if not auth.isalnum():
            return JSONResponse(status_code=400, content={"error": "Auth solo alfanumérico"})
        obfs = gen_key()
        try:
            with open(hc, "r", encoding="utf-8") as f:
                j = json.load(f)
            if j.get("auth", {}).get("mode") == "password":
                j["auth"]["config"]["password"] = auth
            j["obfs"] = obfs
            with open(hc, "w", encoding="utf-8") as f:
                json.dump(j, f, indent=2)
        except Exception as e:
            return JSONResponse(status_code=500, content={"error": f"config hysteria: {e}"})
        conf_set_kv(CONFIG_MV, "HYSTERIA_AUTH", auth)
        conf_set_kv(CONFIG_MV, "HYSTERIA_OBFS", obfs)
        sh("systemctl restart hysteria1-server")
        hist("credenciales", "hysteria auth/obfs regenerados")
        return {"ok": True, "protocolo": "hysteria", "auth": auth, "obfs": obfs,
                "ip": ip, "puerto": cfg.get("HYSTERIA_PORT", "20249")}

    # ── BTUN: crear usuario:clave ──
    if proto == "btun":
        uf = "/etc/btun/users"
        if not user:
            return JSONResponse(status_code=400, content={"error": "Falta el usuario"})
        if not os.path.exists(uf):
            return JSONResponse(status_code=400, content={"error": "BTUN no está instalado"})
        try:
            existing = [ln.split(":", 1)[0] for ln in open(uf, encoding="utf-8", errors="replace") if ":" in ln]
        except Exception:
            existing = []
        if user in existing:
            return JSONResponse(status_code=400, content={"error": f"El usuario {user} ya existe en BTUN"})
        clave = passw or gen_key()
        if not clave.isalnum():
            return JSONResponse(status_code=400, content={"error": "Clave solo alfanumérica"})
        try:
            with open(uf, "a", encoding="utf-8") as f:
                f.write(f"{user}:{clave}\n")
            os.chmod(uf, 0o600)
        except Exception as e:
            return JSONResponse(status_code=500, content={"error": str(e)})
        sh("systemctl restart btun")
        _bt_dias = int(body.get("dias") or 0)
        if _bt_dias < 0 or _bt_dias > 3650:
            return JSONResponse(status_code=400, content={"error": "Días inválido (0 = sin expiración)"})
        _bt_gb = str(body.get("consumo_gb") or "").strip()
        _bt_conn = str(body.get("conexiones") or "").strip()
        _bt_exp = int(time.time()) + _bt_dias * 86400 if _bt_dias else 0
        _lim_cred("btun", user, _bt_exp, _bt_gb, _bt_conn)
        hist("credenciales", "btun usuario creado")
        return {"ok": True, "protocolo": "btun", "usuario": user, "clave": clave,
                "puerto": cfg.get("BTUN_PORT", "7900"),
                "expira": (datetime.fromtimestamp(_bt_exp).strftime("%d/%m/%Y") if _bt_exp else "∞"),
                "consumo_gb": _bt_gb or "∞", "conexiones": _bt_conn or "∞"}

    # ── Protocolos SSH/túnel: crean usuario del sistema con límites + plantilla ──
    if proto in SSH_PROTO:
        if not user:
            return JSONResponse(status_code=400, content={"error": "Falta el nombre de usuario SSH"})
        passw = passw or gen_key()
        dias_ssh = int(body.get("dias") or 0)
        gb_ssh = str(body.get("consumo_gb") or "").strip()
        conn_ssh = str(body.get("conexiones") or "").strip()
        if dias_ssh < 0 or dias_ssh > 3650:
            return JSONResponse(status_code=400, content={"error": "Días inválido (0 = sin expiración)"})
        if gb_ssh and not gb_ssh.isdigit():
            return JSONResponse(status_code=400, content={"error": "Consumo debe ser un número en GB"})
        if conn_ssh and not conn_ssh.isdigit():
            return JSONResponse(status_code=400, content={"error": "Conexiones debe ser un número"})
        gb_bytes = int(gb_ssh) * 1073741824 if gb_ssh and int(gb_ssh) > 0 else 0
        ok, msg = crear_usuario(user, passw, dias_ssh, int(conn_ssh or 0),
                                opc_consumo=6, gb_bytes=gb_bytes)
        if not ok:
            return JSONResponse(status_code=409, content={"error": msg})
        if proto == "socks5":
            sh("systemctl restart sockd 2>/dev/null || true")
        hist("credenciales", f"{proto} usuario creado {user}")
        ex = sh(f"chage -l {user} 2>/dev/null | awk -F': ' '/Account expires/{{print $2}}'")
        if ex and "never" in ex.lower():
            ex = ""
        ex = ex.strip() if ex else ""
        consumo_label = fmt_bytes(gb_bytes) if gb_bytes else "♾️ Ilimitado"
        pp = next((x for x in PROTOCOLS if x["slug"] == proto), None)
        plantilla = build_plantilla(user, passw, ex, int(conn_ssh or 0), consumo_label,
                                    pkg=str(body.get("paquete") or "").strip())
        return {"ok": True, "protocolo": proto, "usuario": user,
                "puertos": (pp or {}).get("puertos", ""),
                "expira": ex or "∞", "consumo_gb": gb_ssh or "∞",
                "conexiones": conn_ssh or "∞", "plantilla": plantilla}

    # ── Xray: crear cliente vless / vmess / trojan (inbound por protocolo real) ──
    if proto in ("xray-vless", "xray-vmess", "xray-trojan"):
        xc = "/usr/local/etc/xray/config.json"
        if not os.path.exists(xc):
            return JSONResponse(status_code=400, content={"error": "Xray no está instalado"})
        if not user:
            return JSONResponse(status_code=400, content={"error": "Falta el nombre del cliente"})
        dias = int(body.get("dias") or 0)
        consumo_gb = str(body.get("consumo_gb") or "").strip()
        con_max = str(body.get("conexiones") or "").strip()
        if dias < 0 or dias > 3650:
            return JSONResponse(status_code=400, content={"error": "Días inválido (0 = sin expiración)"})
        xp = proto.replace("xray-", "")  # vmess|vless|trojan
        idx = sh(f"jq -r '.inbounds | to_entries[] | select(.value.protocol==\"{xp}\") | .key' {xc} 2>/dev/null").splitlines()
        if not idx or not idx[0].strip():
            return JSONResponse(status_code=400, content={"error": f"El protocolo xray {xp} no está habilitado en este servidor"})
        idx = idx[0].strip()
        if sh(f"jq -e --arg email {shq(user)} '.inbounds[{idx}].settings.clients[]?|select(.email==$email)' {xc} >/dev/null 2>&1 && echo 1") == "1":
            return JSONResponse(status_code=400, content={"error": f"El cliente {user} ya existe en xray"})
        if xp == "trojan":
            secret = passw or gen_key()
            if not secret.isalnum():
                return JSONResponse(status_code=400, content={"error": "Password solo alfanumérico"})
            add_frag = '{"password":$secret,"level":0,"email":$email}'
        else:
            secret = sh("cat /proc/sys/kernel/random/uuid") or gen_key()
            add_frag = '{"id":$secret,"level":0,"email":$email}'
        tmp = "/tmp/xray-nc.json"
        cmd = f"jq --arg email {shq(user)} --arg secret {shq(secret)} '.inbounds[{idx}].settings.clients += [{add_frag}]' {xc} > {tmp}"
        code, err = sh_json(cmd)
        if code != 0:
            return JSONResponse(status_code=500, content={"error": err or "jq xray falló"})
        # validar la config ANTES de reemplazar (no romper un xray sano)
        vcode, verr = sh_json("/usr/local/bin/xray run -test -config " + tmp + " 2>&1 >/dev/null")
        if vcode != 0:
            sh(f"rm -f {tmp}")
            return JSONResponse(status_code=500, content={"error": f"Config xray nueva inválida (servicio xray ya estaba dañado): {verr[:180]}"})
        code, err = sh_json(f"mv {tmp} {xc}")
        if code != 0:
            return JSONResponse(status_code=500, content={"error": err or "no se pudo guardar config xray"})
        sh("systemctl restart xray")
        net = sh(f"jq -r '.inbounds[{idx}].streamSettings.network // \"tcp\"' {xc}")
        path = sh(f"jq -r '.inbounds[{idx}].streamSettings.{net}Settings.path // \"\"' {xc}")
        sec = sh(f"jq -r '.inbounds[{idx}].streamSettings.security // \"\"' {xc}")
        port = sh(f"jq -r '.inbounds[{idx}].port // empty' {xc}")
        if not port:
            sh(f"systemctl stop xray")
            return JSONResponse(status_code=500, content={"error": "inbound sin puerto: config xray inválida"})
        # registra límites (días/consumo/conexiones) en el conf del panel
        exp_ts = int(time.time()) + dias * 86400 if dias else 0
        try:
            os.makedirs(PLA, exist_ok=True)
            uf2 = PLA + "/xray_limites.conf"
            lim = ""
            if os.path.exists(uf2):
                with open(uf2, encoding="utf-8") as f:
                    lim = f.read()
            if exp_ts or consumo_gb or con_max:
                lim += f"{user}|{exp_ts}|{consumo_gb or '∞'}|{con_max or '∞'}\n"
                with open(uf2, "w", encoding="utf-8") as f:
                    f.write(lim)
                os.chmod(uf2, 0o600)
        except Exception:
            pass
        hist("credenciales", f"xray {xp} cliente creado")
        link = ""
        pathq = ("&path=" + path) if path else ""
        if xp == "vmess":
            vm = {"v": "2", "ps": user, "add": ip, "port": int(port), "id": secret, "aid": 0,
                  "net": net, "type": path and "ws" or "none", "host": "", "path": path, "tls": sec or ""}
            link = "vmess://" + base64.urlsafe_b64encode(json.dumps(vm, separators=(",", ":")).encode()).decode()
        elif xp == "vless":
            link = f"vless://{secret}@{ip}:{port}?type={net}&encryption=none{pathq}&security={sec or 'none'}#{user}"
        else:
            link = f"trojan://{secret}@{ip}:{port}?type={net}{pathq}&security=tls&sni={cfg.get('SERVER_DOMAIN', ip)}#{user}"
        return {"ok": True, "protocolo": proto, "usuario": user, "secreto": secret,
                "puerto": port, "network": net, "path": path, "tls": sec, "link": link, "ip": ip,
                "dias": dias, "expira": (datetime.fromtimestamp(exp_ts).strftime("%d/%m/%Y") if exp_ts else "∞"),
                "consumo_gb": consumo_gb or "∞", "conexiones": con_max or "∞"}

    # ── ZiVPN: agregar contraseña ──
    if proto == "zivpn":
        zc = "/etc/zivpn/config.json"
        if not os.path.exists(zc):
            return JSONResponse(status_code=400, content={"error": "ZiVPN no está instalado"})
        passw = passw or gen_key()
        if not passw.isalnum():
            return JSONResponse(status_code=400, content={"error": "Password solo alfanumérico"})
        gb = str(body.get("gb") or body.get("consumo_gb") or "").strip()
        dup = sh(f"jq -e --arg p {shq(passw)} '.auth.config[]?|select(.==$p)' {zc} >/dev/null 2>&1 && echo 1")
        if dup == "1":
            return JSONResponse(status_code=400, content={"error": "La contraseña ya existe en ZiVPN"})
        cmd = f"jq --arg p {shq(passw)} '.auth.config += [$p]' {zc} > /tmp/zivpn-nc.json && mv /tmp/zivpn-nc.json {zc}"
        code, err = sh_json(cmd)
        if code != 0:
            return JSONResponse(status_code=500, content={"error": err or "jq zivpn falló"})
        sh("systemctl restart zivpn")
        res = {"ok": True, "protocolo": "zivpn", "password": passw,
               "expira": "Ilimitado", "limite": "Ilimitado"}
        if dias and dias.isdigit() and int(dias) > 0:
            exp = int(time.time()) + int(dias) * 86400
            sh_json(f"awk -F'|' -v p={shq(passw)} '$1!=p' /etc/zivpn/expira.conf > /tmp/zivpn-exp.tmp 2>/dev/null; echo {shq(passw + '|' + str(exp))} >> /tmp/zivpn-exp.tmp; mv /tmp/zivpn-exp.tmp /etc/zivpn/expira.conf")
            res["expira"] = f"{dias} días"
        if gb and gb.isdigit() and int(gb) > 0:
            sh_json(f"awk -F'|' -v p={shq(passw)} '$1!=p' /etc/zivpn/limites.conf > /tmp/zivpn-lim.tmp 2>/dev/null; echo {shq(passw + '|' + gb)} >> /tmp/zivpn-lim.tmp; mv /tmp/zivpn-lim.tmp /etc/zivpn/limites.conf")
            res["limite"] = f"{gb} GB"
        conn = str(body.get("conexiones") or "").strip()
        exp_ts = int(time.time()) + int(dias) * 86400 if dias and dias.isdigit() and int(dias) > 0 else 0
        _lim_cred("zivpn", passw, exp_ts, gb if gb.isdigit() else "", conn)
        res["consumo_gb"] = gb or "∞"
        res["conexiones"] = conn or "∞"
        hist("credenciales", "zivpn password creada")
        return res

    # ── Payload: regenerar master y temp ──
    if proto == "payload":
        pf = "/etc/movivip/payload/pwd.pwd"
        if not os.path.exists(pf):
            return JSONResponse(status_code=400, content={"error": "Payload no está instalado"})
        master = gen_key()
        temp = gen_key(10)
        try:
            with open(pf, "w", encoding="utf-8") as f:
                f.write(f"PasswordSet\nmaster={master}\n127.0.0.1:22={temp}\n")
            os.chmod(pf, 0o600)
        except Exception as e:
            return JSONResponse(status_code=500, content={"error": str(e)})
        sh("systemctl restart payload-pget")
        hist("credenciales", "payload master regenerado")
        return {"ok": True, "protocolo": "payload", "master": master, "temp": temp}

    return JSONResponse(status_code=400, content={"error": "Protocolo de credenciales desconocido"})

# ---------- USUARIOS POR PROTOCOLO (listar/gestionar credenciales vivas) ----------
# Lista REAL de cada servicio: zivpn (auth.config), xray (inbounds clients), btun (users),
# ssh (cuentas Linux). Acciones: renovar / bloquear (suspende SIN borrar, restaurable) / eliminar.
SUSP_FILE = f"{DATA_DIR}/suspendidos.json"
ZIVPN_CFG = "/etc/zivpn/config.json"
ZIVPN_EXP = "/etc/zivpn/expira.conf"
ZIVPN_LIM = "/etc/zivpn/limites.conf"
XRAY_CFG = "/usr/local/etc/xray/config.json"
BTUN_CFG = "/etc/btun/users"
XRAY_LIM = PLA + "/xray_limites.conf"
CRED_LIM = PLA + "/credenciales_limites.conf"

def _rd_json(p):
    try:
        with open(p, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return None

def _wr_json(p, obj, chmod=0o600):
    tmp = p + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(obj, f, indent=2, ensure_ascii=False)
    os.chmod(tmp, chmod)
    os.replace(tmp, p)

def _lines_map(path, sep="|"):
    out = {}
    if os.path.exists(path):
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as f:
                for ln in f:
                    ln = ln.strip()
                    if not ln or ln.startswith("#") or sep not in ln:
                        continue
                    k, v = ln.split(sep, 1)
                    out[k.strip()] = v.strip()
        except Exception:
            pass
    return out

def _rm_line2(path, key, sep="|"):
    try:
        if not os.path.exists(path):
            return
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            lines = [ln for ln in f if not ln.startswith(f"{key}{sep}")]
        with open(path, "w", encoding="utf-8") as f:
            f.writelines(lines)
    except Exception:
        pass

def _suspendidos():
    d = _rd_json(SUSP_FILE) or {}
    d.setdefault("zivpn", [])
    d.setdefault("btun", {})
    d.setdefault("xray", {})   # {proto: {email: {"idx": n, "cliente": {...}}}}
    return d

def _save_suspendidos(d):
    try:
        os.makedirs(DATA_DIR, exist_ok=True)
        _wr_json(SUSP_FILE, d, 0o600)
    except Exception:
        pass

def _xray_inbound_idx(cfg, proto):
    for i, ib in enumerate(cfg.get("inbounds", [])):
        if ib.get("protocol") == proto:
            return i
    return -1

def _xray_lim_map():
    out = {}
    if os.path.exists(XRAY_LIM):
        try:
            with open(XRAY_LIM, encoding="utf-8", errors="replace") as f:
                for ln in f:
                    ln = ln.strip()
                    if not ln or ln.startswith("#"):
                        continue
                    p = ln.split("|")
                    if len(p) >= 4:
                        exp = int(float(p[1])) if p[1].isdigit() else 0
                        out[p[0]] = {"exp_ts": exp, "consumo_gb": p[2], "conexiones": p[3]}
        except Exception:
            pass
    return out

def _apply_xray(cfg):
    """Escribe config xray con validación previa (xray run -test). Devuelve (ok, err)."""
    tmp = "/tmp/xray-pu-tmp.json"
    try:
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(cfg, f, indent=2, ensure_ascii=False)
    except Exception as e:
        return False, str(e)
    vcode, verr = sh_json("/usr/local/bin/xray run -test -config " + tmp + " 2>&1 >/dev/null")
    if vcode != 0:
        sh(f"rm -f {tmp}")
        return False, (verr or "config xray inválida")[:180]
    try:
        os.replace(tmp, XRAY_CFG)
    except Exception as e:
        return False, str(e)
    sh("systemctl restart xray")
    return True, "ok"

@app.get("/api/protocolo-usuarios")
async def api_proto_usuarios(req: Request):
    await guard(req)
    proto = str(req.query_params.get("proto", "")).strip()
    now = int(time.time())
    # ── SSH-like (incluye SOCKS5): mismas cuentas Linux ──
    if proto in SSH_PROTO:
        us = [{"identidad": u["user"], "secreto": "", "tipo_secreto": "",
               "expira": u.get("expira", "") or "∞", "exp_ts": 0,
               "consumo_gb": u.get("consumo_limite", "∞"), "conexiones": str(u.get("conn_limite", 0) or 0),
               "estado": u.get("estado", "Activo"), "ultimo": u.get("ultimo_acceso", "")}
              for u in list_usuarios()]
        return {"proto": proto, "tipo": "ssh", "nombre": SSH_PROTO[proto], "instalado": True,
                "global": False, "usuarios": us}
    # ── Globales (única credencial del VPS) ──
    if proto in ("hysteria", "ss", "payload", "badvpn"):
        return {"proto": proto, "tipo": "global", "instalado": True, "global": True, "usuarios": [],
                "nota": "Credencial GLOBAL del servidor (única por VPS). Se regenera desde 🔑 Credenciales de protocolos."}
    # ── ZiVPN ──
    if proto == "zivpn":
        if not os.path.exists(ZIVPN_CFG):
            return {"proto": proto, "tipo": "zivpn", "instalado": False, "global": False, "usuarios": []}
        cfg = _rd_json(ZIVPN_CFG) or {}
        auth = cfg.get("auth", {}).get("config", [])
        if isinstance(auth, dict):
            auth = list(auth.values())
        exp = _lines_map(ZIVPN_EXP)
        lim = _lines_map(ZIVPN_LIM)
        cred = {x["identidad"]: x for x in _otras_limites() if x["tipo"] == "zivpn"}
        sus = set(_suspendidos().get("zivpn", []))
        us = []
        for p in auth:
            exp_ts = int(float(exp.get(p, "0"))) if exp.get(p, "").isdigit() else 0
            c = cred.get(p, {})
            if p in sus:
                estado = "Suspendido"
            elif exp_ts and exp_ts < now:
                estado = "Expirado"
            else:
                estado = "Activo"
            us.append({"identidad": p, "secreto": p, "tipo_secreto": "password",
                       "expira": datetime.fromtimestamp(exp_ts).strftime("%d/%m/%Y %H:%M") if exp_ts else "∞",
                       "exp_ts": exp_ts,
                       "consumo_gb": lim.get(p, c.get("consumo_gb", "∞")),
                       "conexiones": c.get("conexiones", "∞"), "estado": estado})
        us.sort(key=lambda x: x["estado"] != "Activo")
        return {"proto": proto, "tipo": "zivpn", "nombre": "ZiVPN", "instalado": True,
                "global": False, "usuarios": us}
    # ── Xray (vless/vmess/trojan) ──
    if proto in ("xray-vless", "xray-vmess", "xray-trojan"):
        xp = proto.replace("xray-", "")
        if not os.path.exists(XRAY_CFG):
            return {"proto": proto, "tipo": "xray", "instalado": False, "global": False, "usuarios": []}
        cfg = _rd_json(XRAY_CFG) or {}
        idx = _xray_inbound_idx(cfg, xp)
        if idx < 0:
            return {"proto": proto, "tipo": "xray", "instalado": False, "global": False, "usuarios": []}
        info = _xray_lim_map()
        sus = _suspendidos().get("xray", {}).get(proto, {})
        port = cfg["inbounds"][idx].get("port", "")
        us = []
        for cl in cfg["inbounds"][idx].get("settings", {}).get("clients", []):
            email = str(cl.get("email", "")).strip()
            if not email:
                continue
            l = info.get(email, {})
            exp_ts = l.get("exp_ts", 0)
            if email in sus:
                estado = "Suspendido"
            elif exp_ts and exp_ts < now:
                estado = "Expirado"
            else:
                estado = "Activo"
            secret = cl.get("id") or cl.get("password") or ""
            us.append({"identidad": email, "secreto": secret, "tipo_secreto": ("uuid" if xp != "trojan" else "password"),
                       "expira": datetime.fromtimestamp(exp_ts).strftime("%d/%m/%Y %H:%M") if exp_ts else "∞",
                       "exp_ts": exp_ts,
                       "consumo_gb": l.get("consumo_gb", "∞"), "conexiones": l.get("conexiones", "∞"),
                       "estado": estado, "puerto": port})
        us.sort(key=lambda x: x["estado"] != "Activo")
        return {"proto": proto, "tipo": "xray", "nombre": "Xray " + xp.upper(), "instalado": True,
                "global": False, "puerto": port, "usuarios": us}
    # ── BTUN ──
    if proto == "btun":
        if not os.path.exists(BTUN_CFG):
            return {"proto": proto, "tipo": "btun", "instalado": False, "global": False, "usuarios": []}
        cred = {x["identidad"]: x for x in _otras_limites() if x["tipo"] == "btun"}
        sus = _suspendidos().get("btun", {})
        us = []
        try:
            for ln in open(BTUN_CFG, encoding="utf-8", errors="replace"):
                ln = ln.strip()
                if ":" not in ln or ln.startswith("#"):
                    continue
                u, cl = ln.split(":", 1)
                c = cred.get(u, {})
                exp_ts = int(c.get("exp_ts", 0) or 0)
                if u in sus:
                    estado = "Suspendido"
                elif exp_ts and exp_ts < now:
                    estado = "Expirado"
                else:
                    estado = "Activo"
                us.append({"identidad": u, "secreto": cl, "tipo_secreto": "clave",
                           "expira": datetime.fromtimestamp(exp_ts).strftime("%d/%m/%Y %H:%M") if exp_ts else "∞",
                           "exp_ts": exp_ts,
                           "consumo_gb": c.get("consumo_gb", "∞"), "conexiones": c.get("conexiones", "∞"),
                           "estado": estado})
        except Exception:
            pass
        us.sort(key=lambda x: x["estado"] != "Activo")
        return {"proto": proto, "tipo": "btun", "nombre": "BTUN", "instalado": True,
                "global": False, "usuarios": us}
    return JSONResponse(status_code=400, content={"error": "protocolo no soportado para listado"})

@app.post("/api/protocolo-usuarios/renovar")
async def api_proto_renovar(req: Request):
    await guard(req)
    body = await req.json()
    proto = str(body.get("proto", "")).strip()
    ident = str(body.get("identidad", "")).strip()
    dias = int(body.get("dias", 30) or 30)
    if not ident or not safe_ident(ident, ".-"):
        return JSONResponse(status_code=400, content={"error": "Identidad inválida"})
    if dias < 1 or dias > 3650:
        return JSONResponse(status_code=400, content={"error": "Días inválido (1-3650)"})
    exp_ts = int(time.time()) + dias * 86400
    if proto == "zivpn":
        _rm_line2(ZIVPN_EXP, ident)
        try:
            with open(ZIVPN_EXP, "a", encoding="utf-8") as f:
                f.write(f"{ident}|{exp_ts}\n")
        except Exception as e:
            return JSONResponse(status_code=500, content={"error": str(e)})
        c = next((x for x in _otras_limites() if x["tipo"] == "zivpn" and x["identidad"] == ident), None)
        _lim_cred("zivpn", ident, exp_ts, (c or {}).get("consumo_gb", ""), (c or {}).get("conexiones", ""))
        hist("renovar", f"zivpn {ident} +{dias}d")
        return {"ok": True, "proto": proto, "identidad": ident, "expira": datetime.fromtimestamp(exp_ts).strftime("%d/%m/%Y %H:%M")}
    if proto in ("xray-vless", "xray-vmess", "xray-trojan"):
        info = _xray_lim_map()
        l = info.get(ident, {})
        try:
            os.makedirs(PLA, exist_ok=True)
            lines = []
            if os.path.exists(XRAY_LIM):
                with open(XRAY_LIM, encoding="utf-8") as f:
                    lines = [ln for ln in f if not ln.startswith(f"{ident}|")]
            lines.append(f"{ident}|{exp_ts}|{l.get('consumo_gb', '∞')}|{l.get('conexiones', '∞')}\n")
            with open(XRAY_LIM, "w", encoding="utf-8") as f:
                f.writelines(lines)
        except Exception as e:
            return JSONResponse(status_code=500, content={"error": str(e)})
        hist("renovar", f"{proto} {ident} +{dias}d")
        return {"ok": True, "proto": proto, "identidad": ident, "expira": datetime.fromtimestamp(exp_ts).strftime("%d/%m/%Y %H:%M")}
    if proto == "btun":
        c = next((x for x in _otras_limites() if x["tipo"] == "btun" and x["identidad"] == ident), None)
        _lim_cred("btun", ident, exp_ts, (c or {}).get("consumo_gb", ""), (c or {}).get("conexiones", ""))
        hist("renovar", f"btun {ident} +{dias}d")
        return {"ok": True, "proto": proto, "identidad": ident, "expira": datetime.fromtimestamp(exp_ts).strftime("%d/%m/%Y %H:%M")}
    return JSONResponse(status_code=400, content={"error": "protocolo no soportado para renovar"})

@app.post("/api/protocolo-usuarios/delete")
async def api_proto_delete(req: Request):
    await guard(req)
    body = await req.json()
    proto = str(body.get("proto", "")).strip()
    ident = str(body.get("identidad", "")).strip()
    if not ident or not safe_ident(ident, ".-"):
        return JSONResponse(status_code=400, content={"error": "Identidad inválida"})
    if proto == "zivpn":
        if not os.path.exists(ZIVPN_CFG):
            return JSONResponse(status_code=400, content={"error": "ZiVPN no está instalado"})
        cfg = _rd_json(ZIVPN_CFG) or {}
        auth = cfg.get("auth", {}).get("config", [])
        if ident not in auth:
            return JSONResponse(status_code=400, content={"error": "Password no encontrada en ZiVPN"})
        new_auth = [p for p in auth if p != ident]
        cfg["auth"]["config"] = new_auth
        try:
            with open(ZIVPN_CFG + ".tmp", "w", encoding="utf-8") as f:
                json.dump(cfg, f, indent=2, ensure_ascii=False)
            os.chmod(ZIVPN_CFG + ".tmp", 0o600)
            os.replace(ZIVPN_CFG + ".tmp", ZIVPN_CFG)
        except Exception as e:
            return JSONResponse(status_code=500, content={"error": f"config zivpn: {e}"})
        _rm_line2(ZIVPN_EXP, ident)
        _rm_line2(ZIVPN_LIM, ident)
        _lim_cred("zivpn", ident, 0, "", "")   # borra el registro
        sus = _suspendidos(); susp = sus.get("zivpn", [])
        if ident in susp:
            sus["zivpn"] = [p for p in susp if p != ident]; _save_suspendidos(sus)
        sh("systemctl restart zivpn")
        hist("credenciales_eliminar", f"zivpn {ident}")
        return {"ok": True, "proto": proto, "identidad": ident}
    if proto in ("xray-vless", "xray-vmess", "xray-trojan"):
        xp = proto.replace("xray-", "")
        if not os.path.exists(XRAY_CFG):
            return JSONResponse(status_code=400, content={"error": "Xray no está instalado"})
        cfg = _rd_json(XRAY_CFG) or {}
        idx = _xray_inbound_idx(cfg, xp)
        if idx < 0:
            return JSONResponse(status_code=400, content={"error": f"Inbound {xp} no existe"})
        clients = cfg["inbounds"][idx].get("settings", {}).get("clients", [])
        if not any(str(c.get("email", "")).strip() == ident for c in clients):
            return JSONResponse(status_code=400, content={"error": f"Cliente {ident} no existe en xray {xp}"})
        cfg["inbounds"][idx]["settings"]["clients"] = [c for c in clients if str(c.get("email", "")).strip() != ident]
        ok, err = _apply_xray(cfg)
        if not ok:
            return JSONResponse(status_code=500, content={"error": err or "no se pudo aplicar config xray"})
        _rm_line2(XRAY_LIM, ident)
        sus = _suspendidos(); sx = sus.get("xray", {}).get(proto, {})
        if ident in sx:
            del sx[ident]; _save_suspendidos(sus)
        hist("credenciales_eliminar", f"{proto} {ident}")
        return {"ok": True, "proto": proto, "identidad": ident}
    if proto == "btun":
        if not os.path.exists(BTUN_CFG):
            return JSONResponse(status_code=400, content={"error": "BTUN no está instalado"})
        try:
            lines = [ln for ln in open(BTUN_CFG, encoding="utf-8", errors="replace") if not ln.startswith(ident + ":")]
            with open(BTUN_CFG, "w", encoding="utf-8") as f:
                f.writelines(lines)
        except Exception as e:
            return JSONResponse(status_code=500, content={"error": str(e)})
        _lim_cred("btun", ident, 0, "", "")
        sus = _suspendidos(); sb = sus.get("btun", {})
        if ident in sb:
            del sb[ident]; _save_suspendidos(sus)
        sh("systemctl restart btun")
        hist("credenciales_eliminar", f"btun {ident}")
        return {"ok": True, "proto": proto, "identidad": ident}
    return JSONResponse(status_code=400, content={"error": "protocolo no soportado para eliminar"})

@app.post("/api/protocolo-usuarios/bloquear")
async def api_proto_bloquear(req: Request):
    await guard(req)
    body = await req.json()
    proto = str(body.get("proto", "")).strip()
    ident = str(body.get("identidad", "")).strip()
    if not ident or not safe_ident(ident, ".-"):
        return JSONResponse(status_code=400, content={"error": "Identidad inválida"})
    sus = _suspendidos()
    if proto == "zivpn":
        if not os.path.exists(ZIVPN_CFG):
            return JSONResponse(status_code=400, content={"error": "ZiVPN no está instalado"})
        cfg = _rd_json(ZIVPN_CFG) or {}
        auth = cfg.get("auth", {}).get("config", [])
        if ident not in auth:
            return JSONResponse(status_code=400, content={"error": "Password no encontrada en ZiVPN"})
        cfg["auth"]["config"] = [p for p in auth if p != ident]
        try:
            with open(ZIVPN_CFG + ".tmp", "w", encoding="utf-8") as f:
                json.dump(cfg, f, indent=2, ensure_ascii=False)
            os.chmod(ZIVPN_CFG + ".tmp", 0o600)
            os.replace(ZIVPN_CFG + ".tmp", ZIVPN_CFG)
        except Exception as e:
            return JSONResponse(status_code=500, content={"error": f"config zivpn: {e}"})
        if ident not in sus["zivpn"]:
            sus["zivpn"].append(ident)
        _save_suspendidos(sus)
        sh("systemctl restart zivpn")
        hist("bloquear", f"zivpn {ident}")
        return {"ok": True, "proto": proto, "identidad": ident, "estado": "Suspendido"}
    if proto in ("xray-vless", "xray-vmess", "xray-trojan"):
        xp = proto.replace("xray-", "")
        if not os.path.exists(XRAY_CFG):
            return JSONResponse(status_code=400, content={"error": "Xray no está instalado"})
        cfg = _rd_json(XRAY_CFG) or {}
        idx = _xray_inbound_idx(cfg, xp)
        if idx < 0:
            return JSONResponse(status_code=400, content={"error": f"Inbound {xp} no existe"})
        clients = cfg["inbounds"][idx].get("settings", {}).get("clients", [])
        target = None
        for c in clients:
            if str(c.get("email", "")).strip() == ident:
                target = c; break
        if target is None:
            return JSONResponse(status_code=400, content={"error": f"Cliente {ident} no existe en xray {xp}"})
        cfg["inbounds"][idx]["settings"]["clients"] = [c for c in clients if str(c.get("email", "")).strip() != ident]
        ok, err = _apply_xray(cfg)
        if not ok:
            return JSONResponse(status_code=500, content={"error": err or "no se pudo aplicar config xray"})
        sus["xray"].setdefault(proto, {})[ident] = {"idx": idx, "cliente": target}
        _save_suspendidos(sus)
        hist("bloquear", f"{proto} {ident}")
        return {"ok": True, "proto": proto, "identidad": ident, "estado": "Suspendido"}
    if proto == "btun":
        if not os.path.exists(BTUN_CFG):
            return JSONResponse(status_code=400, content={"error": "BTUN no está instalado"})
        found = None
        try:
            for ln in open(BTUN_CFG, encoding="utf-8", errors="replace"):
                if ln.startswith(ident + ":"):
                    found = ln.strip(); break
        except Exception:
            pass
        if not found:
            return JSONResponse(status_code=400, content={"error": f"Usuario {ident} no existe en BTUN"})
        try:
            lines = [ln for ln in open(BTUN_CFG, encoding="utf-8", errors="replace") if not ln.startswith(ident + ":")]
            with open(BTUN_CFG, "w", encoding="utf-8") as f:
                f.writelines(lines)
        except Exception as e:
            return JSONResponse(status_code=500, content={"error": str(e)})
        sus["btun"][ident] = found
        _save_suspendidos(sus)
        sh("systemctl restart btun")
        hist("bloquear", f"btun {ident}")
        return {"ok": True, "proto": proto, "identidad": ident, "estado": "Suspendido"}
    return JSONResponse(status_code=400, content={"error": "protocolo no soportado para bloquear"})

@app.post("/api/protocolo-usuarios/desbloquear")
async def api_proto_desbloquear(req: Request):
    await guard(req)
    body = await req.json()
    proto = str(body.get("proto", "")).strip()
    ident = str(body.get("identidad", "")).strip()
    if not ident or not safe_ident(ident, ".-"):
        return JSONResponse(status_code=400, content={"error": "Identidad inválida"})
    sus = _suspendidos()
    if proto == "zivpn":
        if ident not in sus.get("zivpn", []):
            return JSONResponse(status_code=400, content={"error": "La password no está suspendida"})
        cfg = _rd_json(ZIVPN_CFG) or {}
        auth = cfg.get("auth", {}).get("config", [])
        if ident not in auth:
            auth.append(ident)
            cfg["auth"]["config"] = auth
            try:
                with open(ZIVPN_CFG + ".tmp", "w", encoding="utf-8") as f:
                    json.dump(cfg, f, indent=2, ensure_ascii=False)
                os.chmod(ZIVPN_CFG + ".tmp", 0o600)
                os.replace(ZIVPN_CFG + ".tmp", ZIVPN_CFG)
            except Exception as e:
                return JSONResponse(status_code=500, content={"error": f"config zivpn: {e}"})
            sh("systemctl restart zivpn")
        sus["zivpn"] = [p for p in sus.get("zivpn", []) if p != ident]
        _save_suspendidos(sus)
        hist("desbloquear", f"zivpn {ident}")
        return {"ok": True, "proto": proto, "identidad": ident, "estado": "Activo"}
    if proto in ("xray-vless", "xray-vmess", "xray-trojan"):
        sx = sus.get("xray", {}).get(proto, {})
        if ident not in sx:
            return JSONResponse(status_code=400, content={"error": "El cliente no está suspendido"})
        cfg = _rd_json(XRAY_CFG) or {}
        idx = sx[ident].get("idx", -1)
        if idx < 0:
            idx = _xray_inbound_idx(cfg, proto.replace("xray-", ""))
        if idx < 0:
            return JSONResponse(status_code=400, content={"error": "Inbound no disponible"})
        clients = cfg["inbounds"][idx].get("settings", {}).get("clients", [])
        # no duplicar si por algún motivo ya existe
        if not any(str(c.get("email", "")).strip() == ident for c in clients):
            clients.append(sx[ident]["cliente"])
            cfg["inbounds"][idx]["settings"]["clients"] = clients
            ok, err = _apply_xray(cfg)
            if not ok:
                return JSONResponse(status_code=500, content={"error": err or "no se pudo aplicar config xray"})
        del sx[ident]
        _save_suspendidos(sus)
        hist("desbloquear", f"{proto} {ident}")
        return {"ok": True, "proto": proto, "identidad": ident, "estado": "Activo"}
    if proto == "btun":
        sb = sus.get("btun", {})
        if ident not in sb:
            return JSONResponse(status_code=400, content={"error": "El usuario no está suspendido"})
        try:
            with open(BTUN_CFG, "a", encoding="utf-8") as f:
                f.write(sb[ident] + "\n")
        except Exception as e:
            return JSONResponse(status_code=500, content={"error": str(e)})
        del sb[ident]
        _save_suspendidos(sus)
        sh("systemctl restart btun")
        hist("desbloquear", f"btun {ident}")
        return {"ok": True, "proto": proto, "identidad": ident, "estado": "Activo"}
    return JSONResponse(status_code=400, content={"error": "protocolo no soportado para desbloquear"})

# ---------- TERMINAL ----------
@app.post("/api/terminal/start")
async def api_term_start(req: Request):
    await guard(req)
    body = await req.json()
    cmd = str(body.get("cmd", "bash")).strip()
    cwd = str(body.get("cwd", PANEL_DIR)).strip()
    if not cmd:
        return JSONResponse(status_code=400, content={"error": "comando vacío"})
    try:
        info = new_term(cmd, cwd)
    except RuntimeError as e:
        return JSONResponse(status_code=500, content={"error": str(e)})
    hist("terminal", cmd[:120])
    return info

@app.post("/api/terminal/{tid}/input")
async def api_term_input(req: Request, tid: str):
    await guard(req)
    s = TERMS.get(tid)
    if not s:
        return JSONResponse(status_code=404, content={"error": "sesión no existe"})
    body = await req.json()
    data = str(body.get("data", ""))
    s.write(data)
    return {"ok": True}

@app.post("/api/terminal/{tid}/stop")
async def api_term_stop(req: Request, tid: str):
    await guard(req)
    s = TERMS.get(tid)
    if s:
        s.stop()
        TERMS.pop(tid, None)
    return {"ok": True}

async def _sse_term(tid: str, start_offset: int):
    s = None
    for _ in range(50):
        if tid in TERMS:
            s = TERMS[tid]; break
        await asyncio.sleep(0.1)
    if not s:
        yield "event: error\ndata: {\"msg\":\"sesión no encontrada\"}\n\n"
        return
    offset = start_offset
    last_done = False
    while True:
        data, offset, done, code = s.read_since(offset)
        if data:
            payload = json.dumps({"d": data.decode("utf-8", "replace"), "off": offset, "done": done, "code": code})
            yield f"data: {payload}\n\n"
        elif done and not last_done:
            last_done = True
            payload = json.dumps({"d": "", "off": offset, "done": True, "code": code})
            yield f"data: {payload}\n\n"
        if done and not data:
            break
        await asyncio.sleep(0.12)

@app.get("/api/terminal/{tid}/stream")
async def api_term_stream(req: Request, tid: str):
    await guard(req)
    offset = int(req.query_params.get("offset", "0") or 0)
    return StreamingResponse(
        _sse_term(tid, offset),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"})

# ---------- STATIC ----------
@app.get("/")
async def index(): return FileResponse(f"{PANEL_DIR}/static/index.html")

app.mount("/static", StaticFiles(directory=f"{PANEL_DIR}/static"), name="static")

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=PORT)