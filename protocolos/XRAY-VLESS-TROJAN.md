# 📡 V2RAY / XRAY — VMess · VLESS · Trojan
### Guía de despliegue completa — MoviVIP Network

> Documento de referencia para **instalar, habilitar y abrir** todo lo necesario
> para que las cuentas **VMess**, **VLESS** y **Trojan** funcionen (navegación
> real a internet) en un VPS con arquitectura **Xray (interno) + HAProxy (TLS)**.
>
> Versionado en el repo para que el despliegue sea **reproducible desde cero**.

---

## 1. Arquitectura

```
          CLIENTE (v2rayN/v2rayNG/nekoray)
                     │  vmess:// , vless:// , trojan://  (puerto 443 / 8443, TLS)
                     ▼
        ┌───────────────────────────────┐
        │  HAProxy  (TLS termination)   │  binds :80 :443 :8080 :8443  (cert yha.pem)
        │  Termina TLS (WS) y enruta por path
        └───┬──────────┬──────────┬─────┘
 path /vmess     /vless     /trojan-ws
        ▼           ▼           ▼
   ┌─────────┐ ┌─────────┐ ┌─────────┐
   │ Xray    │ │ Xray    │ │ Xray    │   inbounds INTERNOS en 127.0.0.1
   │ 10002   │ │ 10003   │ │ 10004   │   (NO expuestos, solo HAProxy les habla)
   │ VMess   │ │ VLESS   │ │ Trojan  │
   └─────────┘ └─────────┘ └─────────┘
        └───────────┬───────────┘
                    ▼
          SALIDA A INTERNET (freedom + NAT MASQUERADE)
```

| Protocolo | Inbound Xray (interno) | Path WS | Backend HAProxy |
|-----------|------------------------|---------|-----------------|
| **VMess** | `127.0.0.1:10002` | `/vmess` | `vmess_backend` |
| **VLESS** | `127.0.0.1:10003` | `/vless` | `vless_backend` |
| **Trojan** | `127.0.0.1:10004` | `/trojan-ws` | `trojan_backend` |

> ⚠️ Los inbounds de Xray escuchan **solo en `127.0.0.1`** (no expuestos).
> El puerto que va en los links de cliente es el de **HAProxy** (`443`/`8443`),
> **no** el 10002/10003/10004.

---

## 2. Qué se INSTALA

| Paquete/Componente | Motivo |
|--------------------|--------|
| **Xray Core** (`/usr/local/bin/xray`) | Motor de proxy (VMess/VLESS/Trojan). Script oficial: `bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install` |
| **HAProxy** (`/etc/haproxy/`) | Terminación TLS y enrutado por path a los inbounds internos |
| **openssl** | Generar/leer certificado y calcular hash `pinnedPeerCertSha256` |
| **jq** | Inyección/lectura idempotente de clientes en `config.json` |
| **curl / wget / unzip / socat / cron / bash-completion** | Dependencias base de MoviVIP |

Instalación vía el gestor: `install_xray()` en `protocolos/v2ray.sh`.

---

## 3. Qué se HABILITA / CONFIGURA

| Ítem | Acción | Dónde |
|------|--------|-------|
| **Servicio xray** | `systemctl enable xray` + `Restart=always` | `ensure_xray_resilience()` |
| **Servicio haproxy** | `systemctl enable haproxy` | instalador MoviVIP |
| **Forwarding IP** | `net.ipv4.ip_forward = 1` | `install_xray()` |
| **NAT (salida a internet)** | `iptables -t nat -A POSTROUTING -o <DEV> -j MASQUERADE` | `install_xray()` |
| **Inbounds VMess/VLESS/Trojan** en `config.json` | `127.0.0.1:10002/10003/10004` (creados automáticamente si faltan) | `ensure_xray_inbounds_vless_trojan()` |
| **Backends + ACLs HAProxy** vless/trojan | `acl_path_vless/trojan` + `use_backend vless/trojan_backend` | `ensure_haproxy_xray_backends()` |
| **Bind 8443 en HAProxy** | `bind *:8443 ssl crt /etc/haproxy/yha.pem` | `ensure_haproxy_xray_ports()` |
| **Cron verificación de límites** (cada 2 min) | `v2ray.sh --check-limits` | `install_xray()` |

> Las funciones `ensure_*` son **idempotentes**: si los inbounds/backends ya
> existen, no hacen nada.
> - Xray: `ensure_xray_inbounds_vless_trojan()`
> - HAProxy: `ensure_haproxy_xray_backends()` y `ensure_haproxy_xray_ports()`
>
> Se ejecutan en `install_xray` y al **crear cuentas VLESS/Trojan**, así un VPS
> queda reproducible sin intervención manual.

---

## 4. Qué se ABRE (puertos / firewall)

### Puertos TCP que deben quedar abiertos en el firewall del VPS

| Puerto | Servicio | Descripción |
|--------|----------|-------------|
| **80** | HAProxy | HTTP (VMess/VLESS/Trojan sin TLS — WebSocket) |
| **443** | HAProxy | HTTPS (TLS principal) |
| **8080** | HAProxy | HTTPS alternativo |
| **8443** | HAProxy | **TLS alternativo** (recomendado para estos test) |
| 10002/10003/10004 | Xray | **internos** — solo `127.0.0.1`, NO abrir al exterior |

Comando usado por MoviVIP (vía `herramientas/openports.sh`):
```bash
open_ports "TCP:80,443,8080,8443"
```

Equivalente con iptables (si `openports.sh` no existe):
```bash
sysctl -w net.ipv4.ip_forward=1
for P in 80 443 8080 8443; do
    iptables -C INPUT -p tcp --dport "$P" -j ACCEPT 2>/dev/null \
        || iptables -A INPUT -p tcp --dport "$P" -j ACCEPT
done
DEV=$(ip -4 route show default | awk '{print $5}' | head -1)
[[ -n "$DEV" ]] && {
    iptables -t nat -C POSTROUTING -o "$DEV" -j MASQUERADE 2>/dev/null \
        || iptables -t nat -A POSTROUTING -o "$DEV" -j MASQUERADE
}
```

---

## 5. ⚠️ El fix clave: `pinnedPeerCertSha256` (Xray 26.x)

En **Xray 26.x** (probado en **26.3.27**) la opción `allowInsecure` **fue eliminada**
y reemplazada por **`pinnedPeerCertSha256`**.

### Error típico al usar `allowInsecure`
```
The feature "allowInsecure" has been removed and migrated to "pinnedPeerCertSha256"
```

### ⚠️ Detalle crítico que resolvimos
`pinnedPeerCertSha256` hashea el **CERTIFICADO LEAF completo en formato DER**,
**NO** la clave pública. Si hasheas la public key (`-pubkey`), aunque el hash
"parezca" coincidir, obtienes:
```
transport/internet/tls: peer cert is unrecognized (against pinnedPeerCertSha256)
```

### Comando CORRECTO (hash hex de 64 chars, minúsculas)
```bash
echo | timeout 10 openssl s_client -connect p.movivipoppax.uk:8443 \
    -servername p.movivipoppax.uk 2>/dev/null \
  | openssl x509 -outform der 2>/dev/null \
  | openssl dgst -sha256 2>/dev/null | awk '{print $2}'
```

### Ejemplo de config de cliente (JSON)
```json
"streamSettings": {
  "network": "ws",
  "security": "tls",
  "tlsSettings": {
    "serverName": "p.movivipoppax.uk",
    "pinnedPeerCertSha256": "<HASH_HEX_64>"
  },
  "wsSettings": { "path": "/vless", "headers": { "Host": "p.movivipoppax.uk" } }
}
```

> ⚠️ **NO usar base64** — Xray espera **hex (64 caracteres)**. Base64 produce el error
> `encoding/hex: invalid byte`. En la URI de suscripción de cliente, el parámetro
> equivalente es `pinnedsha256=<hex>`.

---

## 6. Links de cliente (formato)

| Protocolo | Link |
|-----------|------|
| **VMess** | `vmess://<base64url-sin-padding>` |
| **VLESS** | `vless://<UUID>@<DOM>:<PORT>?encryption=none&security=tls&type=ws&path=%2Fvless&host=<DOM>&sni=<DOM>#<usuario>` |
| **Trojan** | `trojan://<PASSWORD>@<DOM>:<PORT>?security=tls&type=ws&path=%2Ftrojan-ws&host=<DOM>&sni=<DOM>#<usuario>` |

> Para puertos 80/8080 (HTTP sin TLS) el link va **sin** `security=tls` ni `sni`.
> El generador está en `protocolos/v2ray.sh`: `generate_vmess_link()`,
> `generate_vless_link()`, `generate_trojan_link()`.

---

## 7. Verificación rápida (comandos)

```bash
# Servicios activos
systemctl is-active xray haproxy

# Inbounds Xray
jq -r '.inbounds[] | .protocol + " port=" + (.port|tostring) + " path=" + (.streamSettings.wsSettings.path // "-")' /usr/local/etc/xray/config.json

# Puertos escuchando (HAProxy 80/443/8080/8443; Xray interno 10002/3/4)
ss -ltnp | grep -E ':(80|443|8080|8443|10002|10003|10004) '

# Forwarding + NAT
cat /proc/sys/net/ipv4/ip_forward
iptables -t nat -L POSTROUTING -n
```

---

## 8. Estado validado (VPS MIAMI — test E2E real)

Prueba end-to-end ejecutada en `151.245.32.224` (Xray **26.3.27**):

| Protocolo | Conexión | Navegación a internet |
|-----------|----------|------------------------|
| **VMess** | ✅ | ✅ `CONECTA+NAVEGA` (IP saliente + HTTP 200 Cloudflare) |
| **VLESS** | ✅ | ✅ `CONECTA+NAVEGA` |
| **Trojan** | ✅ | ✅ `CONECTA+NAVEGA` |

Certificado HAProxy self-signed `CN=p.movivipoppax.uk` — hash leaf DER:
```
3d447d8b1b8a134d1cfe762b3685bdf7e038723df07e350ade0dccfe5989c1b8
```
*(el hash se regenera si se renueva el certificado)*
