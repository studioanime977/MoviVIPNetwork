# MoviVIP Network Setup

**Instalador unificado para servidores VPN/VPS** — Configuración automatizada, segura y lista para producción en un solo archivo.

---

## 🎯 ¿Qué hace?

Convierte un VPS limpio en un servidor VPN completamente operativo en minutos. Incluye:

- **Protocolos VPN**: SSH, SSL/TLS, WebSocket, V2Ray, XRay, WireGuard, OpenVPN, Shadowsocks, Trojan, Hysteria, SlowDNS, BadVPN, UDP Custom, ZiVPN, y más
- **Panel de gestión**: Panel web (FastAPI), Bot de Telegram, 3X-UI (XRay), Webmin
- **Infraestructura**: HAProxy, stunnel, Cloudflare/SlowDNS/VayDNS, Fail2ban, optimización de red (BBR, FQ, MTU)
- **Gestión de usuarios**: Cuentas SSH, VMess, VLESS, Trojan, ZiVPN con límites por plan
- **Monitoreo**: Snapshots de red, consumo por usuario, alertas de expiración
- **Seguridad**: Fail2ban, firewall persistente, banner SSH, rotación de logs

---

## 🏗️ Arquitectura

```
┌─────────────────────────────────────────────────────────────┐
│                    setup-<arch>.sh                           │
│  ┌─────────────┐  ┌──────────────────┐  ┌────────────────┐  │
│  │  Stub Go    │  │  Payload AES-GCM │  │ Firma Ed25519  │  │
│  │  (verifica, │  │  (scripts,       │  │  (integridad   │  │
│  │   descifra, │  │   binarios,      │  │   + autoría)   │  │
│  │   valida)   │  │   protocolos)    │  │                │  │
│  └─────────────┘  └──────────────────┘  └────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

- **Un solo archivo** por arquitectura (`setup-amd64.sh`, `setup-arm64.sh`)
- **Cifrado AES-256-GCM** — payload solo vive en memoria durante la instalación
- **Firma Ed25519** — integridad y autoría verificadas antes de ejecutar
- **Validación de arquitectura** — rechaza binarios incompatibles
- **Licencia obligatoria** — validación criptográfica antes de instalar

---

## 📋 Requisitos

| Componente | Mínimo |
|------------|--------|
| **SO** | Ubuntu 20.04+ · Debian 11+ |
| **Arquitectura** | x86_64 / amd64 · ARM64 / aarch64 |
| **Virtualización** | KVM (recomendado) |
| **Privilegios** | root |
| **Red** | Salida a Internet (GitHub, Cloudflare, firmador) |

### Cloud probados
- ✅ Oracle Cloud (A1/Flex ARM64)
- ✅ AWS Graviton (ARM64)
- ✅ Google Cloud (ARM64/x86)
- ✅ Azure (ARM64/x86)
- ✅ DigitalOcean, Vultr, Hetzner, Contabo (x86_64 KVM)

> ⚠️ No soportado: ARMv7 / i386 / OpenVZ / LXC

---

## 🚀 Instalación

### Opción A: Auto-detección (recomendado)
```bash
bash -c "$(wget -qO- https://github.com/MOVIVIPNETWORK/movivip-setup/raw/main/install-auto.sh)" TU_CLAVE
```
> Detecta arquitectura, descarga el instalador correcto y ejecuta.

### Opción B: Manual
```bash
# x86_64 (Intel/AMD)
wget https://github.com/MOVIVIPNETWORK/movivip-setup/raw/main/setup-amd64.sh
chmod +x setup-amd64.sh
bash setup-amd64.sh TU_CLAVE

# ARM64 (Oracle A1, AWS Graviton, etc.)
wget https://github.com/MOVIVIPNETWORK/movivip-setup/raw/main/setup-arm64.sh
chmod +x setup-arm64.sh
bash setup-arm64.sh TU_CLAVE
```

> Reemplaza `TU_CLAVE` por tu licencia MoviVIP.

---

## 🔐 Licencias y Planes

| Plan | Incluye |
|------|---------|
| **Bronze / Standard** | Protocolos base (SSH, SSL, Dropbear, BadVPN, SlowDNS, etc.) |
| **Premium +** | + Bot Telegram + Webmin |
| **Provider / Admin** | + Facturación + 3X-UI Panel + Web MoviVIP + Optimización de red (BBR/FQ/MTU) + Firewall avanzado |

> La licencia se valida **criptográficamente** (Ed25519) antes de iniciar la instalación. No hay claves en texto plano ni archivos de licencia locales editables.

---

## 🛠️ Post-instalación

```bash
# Acceder al panel principal
menu

# O directamente
bash /etc/movivip/menu.sh
```

### Comandos disponibles
| Comando | Descripción |
|---------|-------------|
| `menu` | Panel principal interactivo |
| `protocolos` | Gestión de protocolos VPN |
| `usuarios` | Gestión de usuarios y cuentas |
| `herramientas` | Utilidades de diagnóstico y red |

---

## 📞 Soporte y Comunidad

| Canal | Enlace |
|-------|--------|
| **Soporte oficial** | https://t.me/MoviVIP |
| **Canal principal** | https://t.me/MoviVIPNetwork |
| **Grupo principal** | https://t.me/MoviVIPNet |
| **Web** | https://movivip-network.web.app/ |
| **Email** | vipnetworkmovi@gmail.com |

### Comunidad aliada
| Canal | Enlace |
|-------|--------|
| Canal FreeNetZone | https://t.me/FreeNetZonevip |
| Grupo FreeNetZone | https://t.me/FreeNetZonevips |

---

## 📦 Archivos del Repositorio

| Archivo | Descripción |
|---------|-------------|
| `setup-amd64.sh` | Instalador x86_64 (22.9 MB) |
| `setup-arm64.sh` | Instalador ARM64 (22.5 MB) |
| `install-auto.sh` | Auto-detector de arquitectura |
| `VERSION` | Versión actual |

---

## ⚙️ Para Integradores

### Verificación de integridad (opcional)
```bash
# Descargar y verificar SHA256
wget https://github.com/MOVIVIPNETWORK/movivip-setup/raw/main/setup-amd64.sh.sha256
sha256sum -c setup-amd64.sh.sha256
```

### Variables de entorno (headless)
```bash
export SERVER_DOMAIN="panel.tudominio.com"
export CF_EMAIL="tu@email.com"
export CF_KEY="tu-cloudflare-api-key"
export PROTOCOLOS="badvpn,ssl,web,bot"
bash setup-amd64.sh TU_CLAVE
```

---

## ⚠️ Notas Importantes

- **No modifiques** los archivos `.sh` — están firmados y cifrados. Cualquier cambio invalida la firma.
- **No compartas** tu clave de licencia — es personal e intransferible.
- **Backups** — El sistema incluye respaldos automáticos (`/opt/depwise_bot/bot_data.json`).
- **Actualizaciones** — Ejecuta `auto-update.sh` o usa el cron configurado (cada 2 días).

---

**MoviVIP Network** — Infraestructura VPN profesional, automatizada y segura.  
Desarrollado por [MoviVIP Network](https://movivip-network.web.app/) · Soporte: [@MoviVIP](https://t.me/MoviVIP)