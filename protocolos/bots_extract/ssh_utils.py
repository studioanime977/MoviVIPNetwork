# -*- coding: utf-8 -*-
"""ssh_utils.py - Gestion de cuentas SSH en el VPS.

Modulo compartido por los bots del paquete (admin_bot, etc.).
Extraido de user_bot.py: create_ssh_account, create_ssh_on_vps,
delete_ssh_on_vps, _add_xray_client, _remove_xray_client_by_email,
run_vps_commands.
Toda la configuracion (tokens, VPS, branding, Xray, limites) se carga
desde config.py (unica fuente).
"""

import os
import sys
import json
import string
import random
import sqlite3
import logging
import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from config import (
    DB_PATH, OPERATOR_PORTS,
    SSH_HOST, VPS_PASSWORD,
    MY_BRAND, MAX_DEVICES,
    XRAY_CONFIG_PATH, XRAY_VLESS_REALITY_PORT,
)

logger = logging.getLogger("ssh_utils")

# Directorio del paquete (donde viven los bots en el VPS)
BOTS_DIR = str(Path(__file__).parent)


def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


# =============================================================================
# VPS OPS
# =============================================================================
def run_vps_commands(commands):
    try:
        import paramiko
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        client.connect(SSH_HOST, port=22, username='root', password=VPS_PASSWORD, timeout=15)
        results = []
        for cmd in commands:
            stdin, stdout, stderr = client.exec_command(cmd, timeout=10)
            out = stdout.read().decode('utf-8', errors='replace').strip()
            err = stderr.read().decode('utf-8', errors='replace').strip()
            results.append((cmd, out, err))
        client.close()
        return results
    except Exception as e:
        logger.error(f"VPS SSH error: {e}")
        return None


# =============================================================================
# XRAY - cliente (V2Ray share links)
# =============================================================================
def _add_xray_client(username):
    """Add user to ALL Xray inbounds by editing config.json directly.

    Pure Xray (no x-ui): we edit /usr/local/etc/xray/config.json
    and restart the xray service. No SQLite DB needed.
    """
    try:
        import paramiko as _p
        import uuid as _uuid_mod

        user_uuid = str(_uuid_mod.uuid5(_uuid_mod.NAMESPACE_URL, f"movivip-{username}"))
        email = f"{username}@{MY_BRAND}"

        _c = _p.SSHClient()
        _c.set_missing_host_key_policy(_p.AutoAddPolicy())
        _c.connect(SSH_HOST, port=22, username='root', password=VPS_PASSWORD, timeout=10)

        # Read current config
        stdin, stdout, stderr = _c.exec_command("cat /usr/local/etc/xray/config.json")
        config_str = stdout.read().decode().strip()
        if not config_str:
            raise Exception("Empty config.json")

        cfg = json.loads(config_str)
        added = 0

        for ib in cfg.get('inbounds', []):
            proto = ib.get('protocol', '')
            settings = ib.get('settings', {})
            clients = settings.get('clients', [])
            # Skip if already has this user
            if any(c.get('email') == email for c in clients):
                continue
            if proto == 'vmess':
                clients.append({'id': user_uuid, 'alterId': 0, 'email': email})
                added += 1
            elif proto == 'vless':
                clients.append({'id': user_uuid, 'email': email, 'flow': ''})
                added += 1
            elif proto == 'trojan':
                clients.append({'password': username, 'email': email})
                added += 1
            settings['clients'] = clients
            ib['settings'] = settings

        if added == 0:
            logger.info(f"Xray: {email} already exists in all inbounds, skipping")
            _c.close()
            return user_uuid

        # Write updated config via SFTP
        new_config_str = json.dumps(cfg, indent=2)
        sftp = _c.open_sftp()
        # Backup first
        try:
            sftp.stat("/usr/local/etc/xray/config.json.bak")
        except:
            pass  # No backup yet
        with sftp.open("/usr/local/etc/xray/config.json", 'w') as f:
            f.write(new_config_str)
        sftp.close()

        # Restart xray
        stdin, stdout, stderr = _c.exec_command("systemctl restart xray")
        import time as _t
        _t.sleep(3)

        # Verify xray is running
        stdin, stdout, stderr = _c.exec_command("pgrep -c xray")
        xray_count = stdout.read().decode().strip()
        logger.info(f"Xray added {email} to {added} inbounds, xray PIDs: {xray_count}")

        _c.close()
        return user_uuid
    except Exception as e:
        logger.error(f"_add_xray_client error: {e}")
        return None


def _remove_xray_client_by_email(email):
    """Remove Xray client by email pattern."""
    try:
        import paramiko as _p
        _c = _p.SSHClient()
        _c.set_missing_host_key_policy(_p.AutoAddPolicy())
        _c.connect(SSH_HOST, port=22, username='root', password=VPS_PASSWORD, timeout=10)

        stdin, stdout, stderr = _c.exec_command(f"cat {XRAY_CONFIG_PATH}")
        config = json.loads(stdout.read().decode('utf-8', errors='replace'))

        removed = False
        for inbound in config.get('inbounds', []):
            if inbound.get('port') == XRAY_VLESS_REALITY_PORT:
                clients = inbound.get('settings', {}).get('clients', [])
                new_clients = [c for c in clients if c.get('email') != email]
                if len(new_clients) != len(clients):
                    removed = True
                inbound['settings']['clients'] = new_clients
                break

        if removed:
            sftp = _c.open_sftp()
            with sftp.open(XRAY_CONFIG_PATH, 'w') as f:
                f.write(json.dumps(config, indent=2))
            sftp.close()
            _c.exec_command("systemctl restart xray")

        _c.close()
        return removed
    except Exception as e:
        logger.error(f"_remove_xray_client_by_email error: {e}")
        return False


# =============================================================================
# CREAR CUENTA SSH EN EL VPS
# =============================================================================
def create_ssh_on_vps(username, password, days, max_devices, port, operator, brand=None, plan_type='free'):
    expiry = (datetime.datetime.now() + datetime.timedelta(days=days)).strftime('%Y-%m-%d')
    port_name = str(port)

    commands = [
        # Create user with vpn-shell.sh (sleep infinity for tunnel)
        f"/usr/sbin/useradd -s /usr/local/bin/vpn-shell.sh -e {expiry} -m {username}",
        # Set password via chpasswd (full path required)
        f"echo '{username}:{password}' | /usr/sbin/chpasswd",
        # Limits via /etc/security/limits.d/ (not limits.conf)
        f"rm -f /etc/security/limits.d/{username}.conf",
        f"echo '{username} hard maxlogins {max_devices}' > /etc/security/limits.d/{username}.conf",
        # Add FULL Match block to vpn_banners.conf (like I6429310 - WORKING)
        # Sin Banner por usuario: el banner SSH lo maneja insinue.net de forma global (/etc/issue.net)
        f"grep -q 'Match User {username}' /etc/ssh/sshd_config.d/vpn_banners.conf 2>/dev/null || printf '\\nMatch User {username}\\n    AllowTcpForwarding yes\\n    PermitTunnel yes\\n    ForceCommand none\\n    X11Forwarding no\\n    MaxSessions 1\\n    ClientAliveInterval 60\\n    ClientAliveCountMax 3\\n' >> /etc/ssh/sshd_config.d/vpn_banners.conf",
        # Reload sshd to apply changes
        "systemctl reload sshd",
    ]
    results = run_vps_commands(commands)
    if results is None:
        return False

    # Check for useradd errors
    for cmd, out, err in results:
        if 'useradd' in cmd and err and 'already exists' in err:
            logger.error(f"User {username} already exists on VPS")
            return False

    logger.info(f"SSH created: {username} port={port} days={days} dev={max_devices}")

    # Add user to ALL Xray inbounds (V2Ray share links for v2rayNG/NekoBox)
    try:
        _add_xray_client(username)
    except Exception as e:
        logger.warning(f"Xray client add failed (non-fatal): {e}")

    # Banner global gestionado por insinue.net (/etc/issue.net) - no se generan banners por usuario

    return True


# =============================================================================
# ELIMINAR CUENTA SSH DEL VPS
# =============================================================================
def delete_ssh_on_vps(username):
    # Kill all processes first (userdel fails if user has active SSH sessions)
    try:
        import paramiko as _p
        _c = _p.SSHClient()
        _c.set_missing_host_key_policy(_p.AutoAddPolicy())
        _c.connect(SSH_HOST, port=22, username='root', password=VPS_PASSWORD, timeout=10)
        _c.exec_command(f"pkill -9 -u {username} 2>/dev/null")
        import time as _t; _t.sleep(1)
        _c.close()
    except Exception as e:
        logger.warning(f"pkill before delete warning: {e}")

    commands = [
        # Delete user and home directory
        f"/usr/sbin/userdel -r {username} 2>&1",
        # Remove limits.d file
        f"rm -f /etc/security/limits.d/{username}.conf",
        # Remove banner file (.txt)
        f"rm -f /etc/ssh/banners/{username}.txt",
        # Remove Match block from vpn_banners.conf (not sshd_config!)
        f"sed -i '/^Match User {username}$/,/^$/d' /etc/ssh/sshd_config.d/vpn_banners.conf 2>/dev/null",
        # Also clean main sshd_config in case old Match blocks exist there
        f"sed -i '/^Match User {username}$/,/^$/d' /etc/ssh/sshd_config 2>/dev/null",
        # Reload sshd to apply changes
        "systemctl reload sshd",
    ]
    results = run_vps_commands(commands)

    # Also remove Xray client by email
    try:
        _remove_xray_client_by_email(f"{username}@{MY_BRAND}")
    except Exception as e:
        logger.warning(f"Xray cleanup for {username} failed (non-critical): {e}")

    return results is not None


# =============================================================================
# API DE CREACION (compartida con los bots de administracion)
# =============================================================================
async def create_ssh_account(admin_id, operator, days, profiles,
                             brand='movivip', custom_username=None, custom_password=None, plan_type='free', hwid=None):
    """Create SSH account via VPS. Shared by admin bots."""
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
        else:
            chars = string.ascii_letters + string.digits
            password = ''.join(random.choice(chars) for _ in range(8))

        max_devices = min(profiles, MAX_DEVICES) if profiles < 999 else 999

        vps_ok = create_ssh_on_vps(username, password, days, max_devices, port, operator, brand, plan_type=plan_type)
        if not vps_ok:
            return {"success": False, "error": "Error al crear usuario en VPS"}

        expiry = (datetime.date.today() + datetime.timedelta(days=days)).isoformat()

        try:
            db = get_db()
            db.execute("""
                INSERT INTO system_users
                (tg_id, username, password, operator, brand, expires_at, status, max_logins, port, server_type, hwid)
                VALUES (?, ?, ?, ?, ?, ?, 'active', ?, ?, ?, ?)
            """, (admin_id, username, password, operator, brand, expiry, max_devices, port, plan_type, hwid or ''))
            db.commit()
            db.close()
        except Exception as e:
            logger.warning(f"DB insert system_users error: {e}")

        logger.info(f"Account created: {username} op={operator} days={days} dev={max_devices} port={port} brand={brand}")

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
