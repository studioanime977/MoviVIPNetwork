# -*- coding: utf-8 -*-
"""ssh_utils.py - VPS account management via account.sh.

All SSH/ZipVPN/Xray operations are delegated to /etc/movivip/usuarios/account.sh
on the VPS. This module is a thin wrapper that calls the script via SSH
and parses the output.

NO logic duplication. NO manual jq. NO manual useradd.
The bot calls the SAME scripts as the shell menu.
"""

import os
import sys
import json
import string
import random
import sqlite3
import logging
import datetime
import paramiko
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from config import (
    DB_PATH, OPERATOR_PORTS,
    SSH_HOST, VPS_PASSWORD,
    MY_BRAND, MAX_DEVICES,
)

logger = logging.getLogger("ssh_utils")

ACCOUNT_SCRIPT = "/etc/movivip/usuarios/account.sh"


# =============================================================================
# VPS EXECUTION
# =============================================================================
def _vps_exec(cmd, timeout=30):
    """Execute a command on VPS via SSH. Returns (stdout, stderr)."""
    try:
        c = paramiko.SSHClient()
        c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        c.connect(SSH_HOST, port=22, username='root', password=VPS_PASSWORD, timeout=15)
        stdin, stdout, stderr = c.exec_command(cmd, timeout=timeout)
        out = stdout.read().decode('utf-8', errors='replace').strip()
        err = stderr.read().decode('utf-8', errors='replace').strip()
        c.close()
        return out, err
    except Exception as e:
        logger.error(f"VPS exec error: {e}")
        return None, str(e)


def _vps_account(action, *args):
    """Call account.sh with action and args. Returns output string."""
    args_str = " ".join(str(a) for a in args if a is not None)
    cmd = f"bash {ACCOUNT_SCRIPT} {action} {args_str}"
    out, err = _vps_exec(cmd, timeout=30)
    if out is None:
        return f"ERROR: SSH connection failed: {err}"
    return out


# =============================================================================
# DATABASE
# =============================================================================
def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


# =============================================================================
# ACCOUNT OPERATIONS (all via account.sh)
# =============================================================================
def create_ssh_on_vps(username, password, days, max_devices, port, operator, brand=None, plan_type='free'):
    """Create SSH account via account.sh add_ssh (SSH + Xray ONLY, NO ZipVPN).

    Flow (handled by account.sh add_ssh):
    1. useradd -e DATE -M -s /usr/sbin/nologin USER
    2. openssl passwd -6 PASS → usermod -p HASH USER
    3. Save limits to limites_consumo.conf + limites_conexiones.conf
    4. Add to Xray config.json via jq → restart xray
    5. NO ZipVPN — sin restart zivpn
    """
    consumo_bytes = 0
    
    result = _vps_account("add_ssh", username, password, days, max_devices, consumo_bytes)
    
    if "ERROR" in result:
        logger.error(f"create_ssh_on_vps failed: {result}")
        return False
    
    if "already exists" in result:
        logger.error(f"User {username} already exists on VPS")
        return False
    
    logger.info(f"SSH created via account.sh add_ssh: {username} days={days} dev={max_devices}")
    return True


def delete_ssh_on_vps(username, password=None):
    """Delete SSH user via account.sh delete_ssh (SSH + Xray ONLY, NO ZipVPN).
    
    Flow (handled by account.sh delete_ssh):
    1. pkill -u USER
    2. userdel -f USER
    3. Clean limites_consumo.conf + limites_conexiones.conf
    4. Remove from Xray config.json → restart xray
    5. NO ZipVPN — sin restart zivpn
    """
    result = _vps_account("delete_ssh", username)
    
    if "ERROR" in result:
        logger.error(f"delete_ssh_on_vps failed: {result}")
        return False
    
    logger.info(f"SSH deleted via account.sh delete_ssh: {username}")
    return True


def list_vps_users():
    """List SSH users via account.sh list. Returns list of dicts."""
    result = _vps_account("list")
    if not result or "EMPTY" in result:
        return []
    
    users = []
    for line in result.splitlines():
        line = line.strip()
        if not line or '|' not in line:
            continue
        parts = line.split('|', 1)
        users.append({
            "username": parts[0],
            "expires": parts[1] if len(parts) > 1 else "",
        })
    return users


def get_vps_config():
    """Get server config via account.sh get_config. Returns dict."""
    result = _vps_account("get_config")
    if not result:
        return {}
    
    config = {}
    for line in result.splitlines():
        line = line.strip()
        if '=' in line:
            key, _, value = line.partition('=')
            config[key.strip()] = value.strip()
    return config


# =============================================================================
# ZIPVPN OPERATIONS (all via account.sh)
# =============================================================================
def zipvpn_add(password, days=0, gb_limit=0):
    """Add ZipVPN password via account.sh zipvpn_add."""
    result = _vps_account("zipvpn_add", password, days, gb_limit)
    if "ERROR" in result:
        logger.error(f"zipvpn_add failed: {result}")
        return False
    logger.info(f"ZipVPN password added: days={days} gb={gb_limit}")
    return True


def zipvpn_remove(password):
    """Remove ZipVPN password via account.sh zipvpn_remove."""
    result = _vps_account("zipvpn_remove", password)
    if "ERROR" in result:
        logger.error(f"zipvpn_remove failed: {result}")
        return False
    logger.info(f"ZipVPN password removed")
    return True


def zipvpn_list():
    """List ZipVPN passwords via account.sh zipvpn_list. Returns list of dicts."""
    result = _vps_account("zipvpn_list")
    if not result or "ERROR" in result:
        return []
    
    users = []
    for line in result.splitlines():
        line = line.strip()
        if line.startswith("TOTAL="):
            continue
        if '|' not in line:
            continue
        # Parse: PASS=xxx|EXP=xxx|DAYS=xxx|GB=xxx
        data = {}
        for part in line.split('|'):
            if '=' in part:
                k, _, v = part.partition('=')
                data[k] = v
        
        password = data.get("PASS", "")
        if not password:
            continue
        
        days_left = data.get("DAYS", "0")
        active = days_left != "0"
        
        users.append({
            "password": password,
            "days_left": days_left,
            "active": active,
            "gb_limit": data.get("GB", "0"),
            "epoch": data.get("EXP", "0"),
        })
    
    return users


# =============================================================================
# XRAY OPERATIONS (all via account.sh)
# =============================================================================
def xray_add(username, client_id=None):
    """Add Xray client via account.sh xray_add."""
    if client_id:
        result = _vps_account("xray_add", username, client_id)
    else:
        result = _vps_account("xray_add", username)
    if "ERROR" in result:
        logger.error(f"xray_add failed: {result}")
        return None
    
    # Parse UUID from output: OK:xray_added:username:uuid
    parts = result.split(':')
    if len(parts) >= 4:
        return parts[3]  # UUID
    return "added"


def xray_remove(email):
    """Remove Xray client via account.sh xray_remove."""
    result = _vps_account("xray_remove", email)
    if "ERROR" in result:
        logger.error(f"xray_remove failed: {result}")
        return False
    return True


def xray_list():
    """List Xray clients via account.sh xray_list. Returns list of dicts."""
    result = _vps_account("xray_list")
    if not result or "ERROR" in result:
        return []
    
    clients = []
    for line in result.splitlines():
        line = line.strip()
        if '|' not in line:
            continue
        parts = line.split('|')
        if len(parts) >= 4:
            clients.append({
                "email": parts[0],
                "id": parts[1],
                "protocol": parts[2],
                "tag": parts[3],
            })
        elif len(parts) >= 2:
            clients.append({
                "email": parts[0],
                "id": parts[1],
                "protocol": "",
                "tag": "",
            })
    return clients


# =============================================================================
# SLOWDNS (via account.sh)
# =============================================================================
def get_slowdns_key():
    """Get SlowDNS public key via account.sh slowdns_key."""
    result = _vps_account("slowdns_key")
    if not result or "ERROR" in result:
        return None
    
    if result.startswith("KEY="):
        return result[4:]
    return None


# =============================================================================
# LIMITS — SSH consumption + ZipVPN GB
# =============================================================================
def get_user_limit(username):
    """Get current consumption limit in GB for a user. Returns float or 0=unlimited."""
    result = _vps_account("get_limit", username)
    if not result or "ERROR" in result:
        return 0
    try:
        parts = result.strip().split(":")
        if len(parts) == 2:
            return float(parts[1])
    except:
        pass
    return 0


def set_user_limit(username, gb_limit):
    """Set SSH consumption limit in GB. 0=unlimited. Returns True on success."""
    result = _vps_account("set_limit", username, gb_limit)
    return result and "OK:" in result


def get_zipvpn_limit(password):
    """Get current ZipVPN GB limit. Returns float or 0=unlimited."""
    out, _ = _vps_exec(f"grep '^{password}|' /etc/zivpn/limites.conf 2>/dev/null | cut -d'|' -f2")
    if out and out.strip():
        try:
            return float(out.strip())
        except:
            pass
    return 0


def set_zipvpn_limit(password, gb_limit):
    """Set ZipVPN GB limit. 0=unlimited. Returns True on success."""
    result = _vps_account("zipvpn_set_limit", password, gb_limit)
    return result and "OK:" in result


# =============================================================================
# HIGH-LEVEL API (used by admin_bot.py)
# =============================================================================
def derive_hwid_password(hwid):
    """Derive HWID password via VPS helper script."""
    result = _vps_exec(f"bash /etc/movivip/usuarios/hwid_derive.sh '{hwid}'")
    if result and result[0] and len(result[0]) == 14:
        return result[0]
    return None


def register_hwid_on_vps(username, hwid, password, days, max_devices):
    """Register HWID file on VPS."""
    try:
        expiry = (datetime.date.today() + datetime.timedelta(days=days)).isoformat()
        content = (
            "# MoviVIP Network - Usuario por HWID (v2)\n"
            f"USER: {username}\n"
            f"HWID: {hwid}\n"
            f"PASS: {password}\n"
            f"EXPIRE: {expiry}\n"
            f"MAXCONN: {max_devices}\n"
            f"CREATED: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n"
        )
        _vps_exec(f"mkdir -p /etc/movivip/hwids && cat > /etc/movivip/hwids/{username}.hwid <<'EOF'\n{content}EOF")
        logger.info(f"HWID registered: {username}")
    except Exception as e:
        logger.warning(f"register_hwid_on_vps error: {e}")


async def create_ssh_account(admin_id, operator, days, profiles,
                             brand='movivip', custom_username=None, custom_password=None, plan_type='free', hwid=None):
    """Create SSH account via VPS (SSH + Xray ONLY, NO ZipVPN). Shared by admin bots.
    
    ZipVPN is managed SEPARATELY via zipvpn_add().
    SSH, Xray, ZipVPN are 3 independent branches.
    """
    try:
        op_config = OPERATOR_PORTS.get(operator, {})
        ports = op_config.get('ports', [22])
        port = ports[0]

        if custom_username:
            username = custom_username
        else:
            prefix = brand[:4] if brand else "ssh"
            rand = ''.join(random.choice(string.ascii_lowercase + string.digits) for _ in range(6))
            username = f"{prefix}_{admin_id % 100000}_{rand[:4]}"

        if custom_password:
            password = custom_password
        elif hwid:
            password = derive_hwid_password(hwid)
            if not password:
                return {"success": False, "error": "No se pudo derivar contraseña HWID"}
        else:
            chars = string.ascii_letters + string.digits
            password = ''.join(random.choice(chars) for _ in range(8))

        max_devices = min(profiles, MAX_DEVICES) if profiles < 999 else 999

        vps_ok = create_ssh_on_vps(username, password, days, max_devices, port, operator, brand, plan_type=plan_type)
        if not vps_ok:
            return {"success": False, "error": "Error al crear usuario en VPS"}

        if hwid:
            register_hwid_on_vps(username, hwid, password, days, max_devices)

        expiry = (datetime.date.today() + datetime.timedelta(days=days)).isoformat()

        try:
            db = get_db()
            db.execute("""
                INSERT INTO system_users
                (tg_id, username, password, operator, brand, expires_at, status, max_logins, port_limit, server_type, hwid)
                VALUES (?, ?, ?, ?, ?, ?, 'active', ?, ?, ?, ?)
            """, (admin_id, username, password, operator, brand, expiry, max_devices, port, plan_type, hwid or ''))
            db.commit()
            db.close()
        except Exception as e:
            logger.warning(f"DB insert system_users error: {e}")

        return {
            "success": True,
            "username": username,
            "password": password,
            "days": days,
            "max_logins": max_devices,
            "port": port,
            "operator": operator,
            "brand": brand,
            "expires_at": expiry,
            "hwid": hwid or '',
        }

    except Exception as e:
        logger.error(f"create_ssh_account error: {e}")
        return {"success": False, "error": str(e)}
