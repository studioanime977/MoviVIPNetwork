<div align="center">

# 🌐 MoviVIP Network Setup™
### *Instalador unificado para servidores VPN/VPS — Automatizado, firmado y cifrado*

[![Go Version](https://img.shields.io/badge/Go-1.22+-00ADD8?style=for-the-badge&logo=go&logoColor=white)](https://golang.org)
[![OS Support](https://img.shields.io/badge/OS-Ubuntu%2020.04%2B%20%7C%20Debian%2011%2B-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)](https://ubuntu.com)
[![Architecture](https://img.shields.io/badge/Arch-x86__64%20%7C%20ARM64-FF6B6B?style=for-the-badge&logo=arm&logoColor=white)](#-compatibilidad-y-requisitos)
[![Security](https://img.shields.io/badge/Security-AES--256--GCM%20%2B%20Ed25519-2ea44f?style=for-the-badge&logo=vault&logoColor=white)](#-arquitectura-y-seguridad-criptográfica)
[![Telegram Support](https://img.shields.io/badge/Telegram-24%2F7%20Support-2CA5E0?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/MoviVIP)
[![License: CC0-1.0](https://img.shields.io/badge/License-CC0--1.0-lightgrey?style=for-the-badge&logo=creativecommons&logoColor=white)](#-licencia-cc0-10---dominio-público)
[![Repository](https://img.shields.io/badge/Repo-MOVIVIPNETWORK%2Fmovivip--setup-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/MOVIVIPNETWORK/movivip-setup)

<p align="center">
  <b>Convierte un VPS limpio en un servidor VPN operativo en minutos.</b><br>
  <i>Instalador único firmado (Ed25519), payload cifrado (AES-256-GCM), licencia criptográfica obligatoria.</i>
</p>

[🚀 Instalación Rápida](#-instalación-rápida) •
[✨ Qué incluye](#-qué-incluye) •
[🛡️ Protocolos](#-matriz-de-protocolos-soportados) •
[🏗️ Arquitectura](#-arquitectura-y-seguridad-criptográfica) •
[💎 Planes](#-planes-y-licenciamiento) •
[📜 Legal](#-términos-legales-y-licencia) •
[📞 Soporte](#-soporte-y-canales-oficiales)

</div>

---

## 🎯 ¿Qué es MoviVIP Network Setup?

**MoviVIP Network Setup** es un instalador unificado que convierte un VPS limpio (Ubuntu/Debian) en un servidor VPN completamente configurado y seguro. Un solo archivo `.sh` por arquitectura contiene todo lo necesario: stub verificador, payload cifrado, firma digital y validador de licencia.

```
┌─────────────────────────────────────────────────────────────┐
│                    setup-<arch>.sh (22 MB)                   │
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
- **Licencia obligatoria** — validación criptográfica (Ed25519 + HWID) antes de instalar

---

## ⚡ Instalación Rápida

### Opción A: Auto-detección (recomendado)
```bash
bash -c "$(wget -qO- https://github.com/MOVIVIPNETWORK/movivip-setup/raw/main/install-auto.sh)" TU_CLAVE
```
> Detecta arquitectura, descarga el instalador correcto y ejecuta.

### Opción B: Manual
```bash
# x86_64 (Intel/AMD — DigitalOcean, Vultr, Hetzner, Contabo, etc.)
wget https://github.com/MOVIVIPNETWORK/movivip-setup/raw/main/setup-amd64.sh
chmod +x setup-amd64.sh
bash setup-amd64.sh TU_CLAVE

# ARM64 (Oracle Cloud A1/Flex, AWS Graviton, Google Cloud ARM, Azure ARM)
wget https://github.com/MOVIVIPNETWORK/movivip-setup/raw/main/setup-arm64.sh
chmod +x setup-arm64.sh
bash setup-arm64.sh TU_CLAVE
```
> Reemplaza `TU_CLAVE` por la licencia provista por [Soporte Oficial](https://t.me/MoviVIP).

---

## ✅ Qué incluye

| Categoría | Detalle |
|-----------|---------|
| **Protocolos VPN** | SSH, Dropbear, SSL/TLS (Stunnel), WebSocket, V2Ray (VMess/VLESS), XRay (Reality/XTLS), WireGuard, OpenVPN, Shadowsocks, Trojan, Hysteria 2, SlowDNS, VayDNS, BadVPN (UDPGW), UDP Custom, ZiVPN |
| **Paneles** | Panel web FastAPI, Bot Telegram, 3X-UI (XRay), Webmin |
| **Infraestructura** | HAProxy, Stunnel, Cloudflare/SlowDNS/VayDNS, Fail2ban, optimización red (BBR, FQ, MTU) |
| **Gestión usuarios** | Cuentas SSH, VMess, VLESS, Trojan, ZiVPN con límites por plan |
| **Monitoreo** | Snapshots de red, consumo por usuario, alertas expiración |
| **Seguridad** | Fail2ban, firewall persistente (iptables), banner SSH, rotación logs |

---

## 🛡️ Matriz de Protocolos Soportados

| Protocolo | Transporte | Puertos típicos | Ofuscación / CDN |
|-----------|------------|-----------------|------------------|
| **SSH / Dropbear** | TCP | 22, 443, 2222 | Banner personalizado |
| **SSL / TLS (Stunnel)** | TLS 1.3 | 443, 444 | SNI spoofing |
| **SSH over WebSocket** | HTTP/1.1 + WS Upgrade | 80, 8080, 8880 | Cloudflare CDN |
| **V2Ray (VMess/VLESS)** | TCP / gRPC / WS | 443, 80, 8443 | TLS + WS + CDN |
| **XRay (Reality/XTLS)** | Direct / Vision / Reality | Dinámico | Camuflaje SNI real |
| **WireGuard** | UDP (kernel) | 51820 | MTU optimizado |
| **OpenVPN** | TCP / UDP | 1194, 443 | Certificados RSA/ECC |
| **Shadowsocks / Trojan** | TCP / TLS | 443, 8388 | Trojan-gRPC |
| **Hysteria 2** | QUIC / UDP | 443, 1080-65535 | Bypass congestión ISP |
| **SlowDNS / VayDNS** | DNS Tunnel (UDP 53) | 53, 5300 | Bypass redes cerradas |
| **BadVPN UDPGW** | UDP Forwarding | 7100, 7200, 7300 | Baja latencia (gaming/VoIP) |
| **UDP Custom / ZiVPN** | UDP ofuscado | Multi-puerto | Anti-DPI |

---

## 🏗️ Arquitectura y Seguridad Criptográfica

```
[ GitHub / CDN ] ──► Descarga setup-<arch>.sh (stub + payload + firma)
                              │
                              ▼
                    ┌───────────────────────┐
                    │     MoviVIP Go-Stub   │
                    │  (Ed25519 + HWID)     │
                    └───────────┬───────────┘
                                │  Verifica firma + licencia
                                ▼
                    ┌───────────────────────┐
                    │   In-Memory Decrypt   │  ◄── AES-256-GCM (claves solo en RAM)
                    │    (tmpfs montado)    │
                    └───────────┬───────────┘
                                │  Ejecuta componentes
         ┌──────────────────────┼──────────────────────┐
         ▼                      ▼                      ▼
┌───────────────┐      ┌───────────────┐      ┌───────────────┐
│ Network Stack │      │ Service Daemons│     │ Security Core │
│ BBR / MTU / FQ│      │ XRay/SSH/WS/  │     │ Fail2ban/UFW  │
└───────────────┘      └───────────────┘      └───────────────┘
```

### Estándares de seguridad

| Medida | Implementación |
|--------|----------------|
| **Validación HWID** | Licencia vinculada a hardware — anti-clonación |
| **Firma Ed25519** | Verificada antes de descomprimir cualquier bloque |
| **Cero residuos en disco** | Payload solo en `tmpfs` (RAM), purgado al finalizar |
| **Anti-tampering** | Detección de gdb, ptrace, modificaciones en caliente |
| **Cifrado payload** | AES-256-GCM — claves solo en memoria |

---

## 💻 Compatibilidad y Requisitos

| Componente | Mínimo | Recomendado |
|------------|--------|-------------|
| **SO** | Ubuntu 20.04+ · Debian 11+ | Ubuntu 22.04/24.04 LTS · Debian 12 |
| **Arquitectura** | x86_64 / amd64 · ARM64 / aarch64 | — |
| **Virtualización** | KVM / Hardware dedicado | KVM |
| **CPU** | 1 vCPU | 2+ vCPU (ARM64 Ampere / AMD EPYC) |
| **RAM** | 512 MB | 1–2 GB |
| **Disco** | 5 GB SSD | 15+ GB NVMe |
| **Acceso** | Usuario `root` | Usuario `root` |

### Cloud probados

| Proveedor | Arquitecturas validadas |
|-----------|-------------------------|
| Oracle Cloud | ARM64 (A1/Flex) ✅ |
| AWS Graviton | ARM64 ✅ |
| Google Cloud | ARM64 / x86_64 ✅ |
| Microsoft Azure | ARM64 / x86_64 ✅ |
| DigitalOcean / Vultr / Hetzner / Contabo | x86_64 ✅ |

> ⚠️ **No soportado**: ARMv7 / i386 / OpenVZ / LXC / contenedores sin KVM

---

## 💎 Planes y Licenciamiento

| Característica | 🥉 Bronze / Standard | 🥈 Premium + | 🥇 Provider / Admin |
|----------------|---------------------|--------------|---------------------|
| Protocolos base (SSH, SSL, Dropbear, BadVPN, SlowDNS, etc.) | ✅ | ✅ | ✅ |
| WebSocket Cloudflare + SlowDNS / VayDNS | ✅ | ✅ | ✅ |
| Gestor usuarios CLI (`usuarios`) | ✅ | ✅ | ✅ |
| Bot Telegram automatizado | ❌ | ✅ | ✅ |
| Webmin | ❌ | ✅ | ✅ |
| Panel 3X-UI (XRay / Reality / VLESS) | ❌ | ❌ | ✅ |
| Panel Web MoviVIP (FastAPI) | ❌ | ❌ | ✅ |
| Optimización kernel (BBR + FQ + MTU) | ❌ | ❌ | ✅ |
| Firewall Layer 7 / Anti-DDoS | ❌ | ❌ | ✅ |
| Facturación / Revendedores | ❌ | ❌ | ✅ |

> La licencia se valida **criptográficamente (Ed25519 + HWID)** antes de iniciar la instalación. No hay claves en texto plano ni archivos editables.

---

## 🛠️ Post-instalación

```bash
# Panel principal
menu

# O directamente
bash /etc/movivip/menu.sh
```

| Comando | Descripción |
|---------|-------------|
| `menu` | Panel principal interactivo |
| `protocolos` | Gestión de protocolos VPN |
| `usuarios` | Crear, listar, eliminar, monitorear clientes |
| `herramientas` | Diagnóstico, test velocidad, Fail2ban |

---

## 🔍 Verificación de Integridad y Autenticidad

```bash
# 1. Repositorio oficial
git clone https://github.com/MOVIVIPNETWORK/movivip-setup
cd movivip-setup

# 2. Verificar firma del commit oficial
git log -1 --format="%an <%ae> %G?"
# Salida esperada: MoviVIP Network <vipnetworkmovi@gmail.com> G

# 3. Verificar SHA256 del instalador
sha256sum setup-amd64.sh
# Comparar con hash publicado en https://t.me/MoviVIPNetwork
```

---

## ❓ Preguntas Frecuentes

<details>
<summary><b>¿Puedo mover mi licencia a otro servidor?</b></summary>
<br>
Las licencias están vinculadas al HWID del servidor activo. Para migraciones autorizadas, contacta a [Soporte Oficial](https://t.me/MoviVIP) para desvinculación formal.
</details>

<details>
<summary><b>¿El instalador toca mi puerto SSH actual?</b></summary>
<br>
No. Preserva tu puerto SSH y añade puertos de multiplexación (443, 80, 8080) sin interrumpir tu sesión activa.
</details>

<details>
<summary><b>¿Cómo se actualiza el sistema?</b></summary>
<br>
Sincronización automática cada 48h. Forzar actualización: `menu → Herramientas → Actualizar Sistema`.
</details>

---

## ⚖️ Términos Legales, Seguridad y Políticas

### 📜 Copyright y Propiedad Intelectual

**MoviVIP Network Setup** es software propietario de **MoviVIP Network**. Todos los derechos reservados.

```
© 2024-2025 MoviVIP Network. Todos los derechos reservados.
```

Está **estrictamente prohibido**:

- ❌ Descompilar, desensamblar, ingeniería inversa o recuperar código fuente
- ❌ Copiar, distribuir, sublicenciar, arrendar o transferir sin autorización escrita
- ❌ Modificar, adaptar, traducir o crear obras derivadas
- ❌ Eliminar/alterar avisos de copyright, marcas o avisos de licencia
- ❌ Usar el software para desarrollar productos competidores
- ❌ Publicar, compartir o filtrar claves de licencia, firmas o material criptográfico

### 🛡️ Repositorio Oficial y Autorizado

**Este repositorio (`MOVIVIPNETWORK/movivip-setup`) es el único origen autorizado.**

| Estado | Repositorio |
|--------|-------------|
| ✅ **OFICIAL** | `https://github.com/MOVIVIPNETWORK/movivip-setup` |
| ❌ **NO AUTORIZADO** | Cualquier fork, mirror, re-upload o derivado |

Cualquier distribución desde repos no autorizados, forks, mirrors, canales no oficiales, sitios de terceros o marketplaces **constitute distribución no autorizada** y será perseguida legalmente.

### 🔒 Políticas de Seguridad

| Política | Implementación |
|----------|----------------|
| Cifrado en reposo/tránsito | AES-256-GCM, TLS 1.3 + pinning |
| Firma criptográfica | Ed25519 — integridad y autoría |
| Licencia + HWID | Vinculada a hardware — no transferible |
| Sin secretos en disco | Payload solo en `tmpfs` (RAM) |
| Rotación de claves | Firmas rotables; revocación automática |
| Auditoría | Logs firmados (`/var/log/movivip-install.log`) |
| Baneos automáticos | Bypass, licencia inválida, manipulación → bloqueo permanente |

### 📋 Términos y Condiciones

Al usar **MoviVIP Network Setup**, aceptas:

1. **Licencia personal e intransferible** — Vinculada a identidad y hardware. No transferible, revendible ni compartible.
2. **Uso autorizado únicamente** — Solo el titular en servidores de su propiedad/control.
3. **Una licencia = una instancia activa** — Instalaciones concurrentes revocan la licencia.
4. **Sin garantía** — Software "TAL CUAL", sin garantías de comerciabilidad o idoneidad.
5. **Límite de responsabilidad** — Sin responsabilidad por daños indirectos, incidentales, pérdida de datos o lucro cesante.
6. **Cumplimiento legal** — Responsable de leyes locales sobre VPN, cifrado, telecomunicaciones.
7. **Actualizaciones obligatorias** — Auto-actualización cada 48h; deshabilitarla anula soporte.
8. **Soporte solo a licencias válidas** — Canales oficiales únicamente.

### ⚠️ Penalizaciones por Incumplimiento

| Infracción | Penalización |
|------------|--------------|
| Distribución no autorizada (repos, mirrors, leaks) | **Revocación inmediata + permanente** + acción legal (DMCA, derechos de autor, secreto comercial) |
| Ingeniería inversa / bypass de licencia | **Bloqueo permanente HWID + clave** + acción legal (Ley Secretos Comerciales, DMCA 1201) |
| Reventa / compartición de licencia | **Revocación inmediata** + lista negra + indemnización |
| Modificación / bypass firma / cifrado | **Bloqueo permanente** + acción legal |
| Distribución en repos/forks/mirrors no autorizados | **DMCA takedown inmediato** + daños + honorarios legales |
| Uso en actividades ilegales | **Terminación inmediata** + reporte a autoridades |

> **Ejemplo**: En 2024, sentencia favorable contra 3 actores distribuyendo builds modificados — $47,000 USD indemnización + bloqueo HWID permanente + cierre repos por GitHub (DMCA).

### 🛡️ Repositorio Oficial y Autorizado

| Estado | Repositorio |
|--------|-------------|
| ✅ **OFICIAL** | `https://github.com/MOVIVIPNETWORK/movivip-setup` |
| ❌ **NO AUTORIZADO** | Cualquier fork, mirror, re-upload o derivado |

Cualquier distribución fuera del repo oficial **será perseguida legalmente (DMCA, derechos de autor, secreto comercial).**

### 🔒 Adquisición de Licencia

**Solo canales oficiales:**

| Canal | Disponibilidad |
|-------|----------------|
| **Telegram (Soporte 24/7)** | https://t.me/MoviVIP |
| **Email** | vipnetworkmovi@gmail.com |
| **Web** | https://movivip-network.web.app/ |

> ⚠️ **No compres a revendedores, bots, canales no oficiales, Discord, foros o marketplaces.** Solo licencias emitidas directamente por MoviVIP Network son válidas. Licencias de terceros **no activan**, no tienen soporte y **serán revocadas sin reembolso**.

### ✅ Verificación de Autenticidad

```bash
# 1. Repositorio oficial
git clone https://github.com/MOVIVIPNETWORK/movivip-setup
cd movivip-setup

# 2. Verificar firma del commit
git log -1 --format="%an <%ae> %G?"
# Debe mostrar: MoviVIP Network <vipnetworkmovi@gmail.com> G

# 3. Verificar SHA256 (comparar con https://t.me/MoviVIPNetwork)
sha256sum setup-amd64.sh
```

---

## 📦 Archivos del Repositorio

| Archivo | Descripción |
|---------|-------------|
| `setup-amd64.sh` | Instalador x86_64 (22.9 MB) |
| `setup-arm64.sh` | Instalador ARM64 (22.5 MB) |
| `install-auto.sh` | Auto-detector de arquitectura |
| `VERSION` | Versión actual |

---

## 📞 Soporte y Comunidad

| Canal | Enlace |
|-------|--------|
| **Soporte oficial (licencias, soporte técnico)** | https://t.me/MoviVIP |
| **Canal principal (anuncios, hashes, updates)** | https://t.me/MoviVIPNetwork |
| **Grupo principal (comunidad)** | https://t.me/MoviVIPNet |
| **Web** | https://movivip-network.web.app/ |
| **Email** | vipnetworkmovi@gmail.com |

### Comunidad aliada
| Canal | Enlace |
|-------|--------|
| Canal FreeNetZone | https://t.me/FreeNetZonevip |
| Grupo FreeNetZone | https://t.me/FreeNetZonevips |

---

## 📄 Licencia

Este repositorio (documentación, scripts de instalación, configuraciones de ejemplo) se publica bajo **CC0-1.0 (Dominio Público)** — puedes copiar, modificar, distribuir y usar libremente, incluso comercialmente, sin pedir permiso.

> **Nota importante**: La licencia CC0-1.0 aplica **solo a los archivos de este repositorio público** (README, scripts de ejemplo, documentación). El **software propietario MoviVIP Network Setup** (binarios firmados, payloads cifrados, validadores de licencia, esquemas criptográficos) **NO está cubierto por CC0-1.0** y sigue siendo software propietario con todos los derechos reservados según los términos arriba descritos.

```
CC0 1.0 Universal (CC0 1.0) Public Domain Dedication
https://creativecommons.org/publicdomain/zero/1.0/
```

Referencia: [awesome-github-profile-readme / CC0-1.0](https://github.com/abhisheknaiidu/awesome-github-profile-readme/tree/main/CC0-1.0)

---

## 📦 Archivos del Repositorio

| Archivo | Descripción |
|---------|-------------|
| `setup-amd64.sh` | Instalador x86_64 (22.9 MB) |
| `setup-arm64.sh` | Instalador ARM64 (22.5 MB) |
| `install-auto.sh` | Auto-detector de arquitectura |
| `VERSION` | Versión actual |

---

## 📞 Soporte y Comunidad

| Canal | Enlace |
|-------|--------|
| **Soporte oficial (licencias, soporte técnico)** | https://t.me/MoviVIP |
| **Canal principal (anuncios, hashes, updates)** | https://t.me/MoviVIPNetwork |
| **Grupo principal (comunidad)** | https://t.me/MoviVIPNet |
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

**MoviVIP Network** — Infraestructura VPN profesional, automatizada y segura.  
Desarrollado por [MoviVIP Network](https://movivip-network.web.app/) · Soporte: [@MoviVIP](https://t.me/MoviVIP)  
© 2024-2025 MoviVIP Network. Todos los derechos reservados.