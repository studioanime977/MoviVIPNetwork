<div align="center">

# 🌐 MoviVIP Network Setup™
### *Instalador unificado para servidores VPN/VPS — Automatizado, firmado y cifrado*

[![Go Version](https://img.shields.io/badge/Go-1.22+-00ADD8?style=for-the-badge&logo=go&logoColor=white)](https://golang.org)
[![OS Support](https://img.shields.io/badge/OS-Ubuntu%2020.04%2B%20%7C%20Debian%2011%2B-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)](https://ubuntu.com)
[![Architecture](https://img.shields.io/badge/Arch-x86__64%20%7C%20ARM64-FF6B6B?style=for-the-badge&logo=arm&logoColor=white)](#-compatibilidad-y-requisitos)
[![Telegram Support](https://img.shields.io/badge/Telegram-24%2F7%20Support-2CA5E0?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/MoviVIP)
[![License: CC0-1.0](https://img.shields.io/badge/License-CC0--1.0-lightgrey?style=for-the-badge&logo=creativecommons&logoColor=white)](#-licencia-cc0-10---dominio-público)
[![Repository](https://img.shields.io/badge/Repo-MOVIVIPNETWORK%2Fmovivip--setup-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/MOVIVIPNETWORK/movivip-setup)

<p align="center">
  <b>Convierte un VPS limpio en un servidor VPN operativo en minutos.</b><br>
  <i>Instalador único firmado, payload cifrado, licencia criptográfica obligatoria.</i>
</p>

[🚀 Instalación Rápida](#-instalación-rápida) •
[✅ Qué incluye](#-qué-incluye) •
[🛡️ Protocolos](#-matriz-de-protocolos-soportados) •
[💎 Planes](#-planes-y-licenciamiento) •
[📜 Legal](#-términos-legales-y-licencia) •
[📞 Soporte](#-soporte-y-canales-oficiales)

</div>

---

## 🎯 ¿Qué es MoviVIP Network Setup?

**MoviVIP Network Setup** es un instalador unificado que convierte un VPS limpio (Ubuntu/Debian) en un servidor VPN completamente configurado y seguro. Un solo archivo `.sh` por arquitectura contiene todo lo necesario: verificador de firma, payload protegido, validador de licencia y módulos de configuración.

- **Un solo archivo** por arquitectura (`setup-amd64.sh`, `setup-arm64.sh`)
- **Integridad verificada** — firma digital antes de ejecutar
- **Payload protegido** — sin exposición en disco
- **Validación de arquitectura** — rechaza binarios incompatibles
- **Licencia obligatoria** — validación criptográfica antes de instalar

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
| **Protocolos VPN** | 26 protocolos (ver matriz completa abajo) |
| **Paneles** | Panel web, Bot Telegram, 3X-UI (XRay), Webmin |
| **Infraestructura** | Balanceador, túneles, DNS, optimización de red |
| **Gestión usuarios** | Cuentas con límites por plan |
| **Monitoreo** | Snapshots de red, consumo por usuario, alertas |
| **Seguridad** | Fail2ban, firewall persistente, banner SSH, rotación logs |

---

## 🛡️ Matriz de Protocolos Soportados (26 protocolos)

| # | Protocolo | Categoría |
|---|-----------|-----------|
| 01 | OpenSSH | Acceso seguro |
| 02 | ZiVPN | VPN propietaria |
| 03 | Dropbear | SSH ligero |
| 04 | SSL/TLS | Túnel seguro |
| 05 | BadVPN | UDP Gateway |
| 06 | UDP Custom | UDP propietario |
| 07 | SlowDNS | DNS Tunnel |
| 08 | Xray/V2Ray | VMess/VLESS/Reality |
| 09 | Hysteria | QUIC/UDP |
| 10 | WireGuard | VPN kernel |
| 11 | DTunnel | Túnel propietario |
| 12 | SystemDNS | DNS personalizado |
| 13 | Squid | Proxy HTTP/HTTPS |
| 14 | Webmin | Panel admin web |
| 15 | Bot Telegram | Automatización |
| 16 | SSH-XHTTP | SSH sobre HTTP |
| 17 | BHTTP v2 | HTTP binario |
| 18 | BTUN | Túnel binario |
| 19 | Shadowsocks | Proxy cifrado |
| 20 | Payload | Módulo propietario |
| 21 | OpenVPN | VPN estándar |
| 22 | SOCKS5 | Proxy SOCKS |
| 23 | HCR Relay | Relay propietario |
| 24 | Web MoviVIP | Panel web oficial |
| 25 | 3X-UI Panel | Panel XRay |
| 26 | Reiniciar | Utilidad sistema |

> Total: **26 módulos** entre protocolos, paneles y utilidades.

---

## 🏗️ Arquitectura

Instalador único por arquitectura que integra:

- **Verificador de integridad** — Firma digital antes de ejecutar
- **Payload protegido** — Sin exposición de componentes en disco
- **Validador de licencia** — Criptografía de curva elíptica + HWID
- **Módulos independientes** — Cada protocolo/panel con su gate de licencia

---

## 💻 Compatibilidad y Requisitos

| Componente | Mínimo | Recomendado |
|------------|--------|-------------|
| **SO** | Ubuntu 20.04+ · Debian 11+ | Ubuntu 22.04/24.04 LTS · Debian 12 |
| **Arquitectura** | x86_64 / amd64 · ARM64 / aarch64 | — |
| **Virtualización** | KVM / Hardware dedicado | KVM |
| **CPU** | 1 vCPU | 2+ vCPU |
| **RAM** | 512 MB | 1–2 GB |
| **Disco** | 5 GB SSD | 15+ GB NVMe |
| **Acceso** | Usuario `root` | Usuario `root` |

### Cloud probados
- ✅ Oracle Cloud (A1/Flex ARM64)
- ✅ AWS Graviton (ARM64)
- ✅ Google Cloud (ARM64/x86)
- ✅ Azure (ARM64/x86)
- ✅ DigitalOcean, Vultr, Hetzner, Contabo (x86_64 KVM)

> ⚠️ No soportado: ARMv7 / i386 / OpenVZ / LXC

---

## 💎 Planes y Licenciamiento

| Característica | 🥉 Bronze / Standard | 🥈 Premium + | 🥇 Provider / Admin |
|----------------|---------------------|--------------|---------------------|
| Protocolos base | ✅ | ✅ | ✅ |
| WebSocket + SlowDNS/VayDNS | ✅ | ✅ | ✅ |
| Gestor usuarios CLI | ✅ | ✅ | ✅ |
| Bot Telegram | ❌ | ✅ | ✅ |
| Webmin | ❌ | ✅ | ✅ |
| 3X-UI Panel (XRay) | ❌ | ❌ | ✅ |
| Web MoviVIP (FastAPI) | ❌ | ❌ | ✅ |
| Optimización kernel (BBR/FQ/MTU) | ❌ | ❌ | ✅ |
| Firewall avanzado / Anti-DDoS | ❌ | ❌ | ✅ |
| Facturación / Revendedores | ❌ | ❌ | ✅ |

> Licencia validada criptográficamente antes de instalar. Sin claves en texto plano.

---

## 🛠️ Post-instalación

```bash
menu
# o directamente
bash /etc/movivip/menu.sh
```

| Comando | Descripción |
|---------|-------------|
| `menu` | Panel principal interactivo |
| `protocolos` | Gestión de protocolos VPN |
| `usuarios` | Gestión de usuarios y cuentas |
| `herramientas` | Diagnóstico, test velocidad, Fail2ban |

---

## 🔍 Verificación de Integridad

```bash
git clone https://github.com/MOVIVIPNETWORK/movivip-setup
cd movivip-setup

# Verificar firma del commit oficial
git log -1 --format="%an <%ae> %G?"
# MoviVIP Network <vipnetworkmovi@gmail.com> G

# Verificar SHA256 (comparar con https://t.me/MoviVIPNetwork)
sha256sum setup-amd64.sh
```

---

## ❓ Preguntas Frecuentes

<details>
<summary><b>¿Puedo mover mi licencia a otro servidor?</b></summary>
<br>
Licencias vinculadas al HWID del servidor activo. Migraciones autorizadas: contacta a <a href="https://t.me/MoviVIP">Soporte Oficial</a>.
</details>

<details>
<summary><b>¿El instalador toca mi puerto SSH actual?</b></summary>
<br>
No. Preserva tu puerto SSH y añade puertos de multiplexación sin interrumpir tu sesión.
</details>

<details>
<summary><b>¿Cómo se actualiza el sistema?</b></summary>
<br>
Sincronización automática cada 48h. Forzar: <code>menu → Herramientas → Actualizar Sistema</code>.
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

Distribución fuera del repo oficial **será perseguida legalmente (DMCA, derechos de autor, secreto comercial).**

### 🔒 Políticas de Seguridad

- Validación HWID — licencia vinculada a hardware
- Firma criptográfica — integridad y autoría verificables
- Licencia ligada a hardware — no transferible
- Payload protegido — sin exposición en disco
- Rotación de claves y revocación automática
- Auditoría con logs firmados
- Baneos automáticos ante bypass/licencia inválida/manipulación

### 📋 Términos y Condiciones

1. **Licencia personal e intransferible** — vinculada a identidad y hardware
2. **Uso autorizado únicamente** — solo titular en servidores de su propiedad
3. **Una licencia = una instancia activa** — concurrencia revoca licencia
4. **Sin garantía** — software "TAL CUAL"
5. **Límite de responsabilidad** — sin daños indirectos, incidentales, pérdida de datos
6. **Cumplimiento legal** — responsable de leyes locales VPN/cifrado/telecom
7. **Actualizaciones obligatorias** — auto-actualización cada 48h
8. **Soporte solo a licencias válidas** — canales oficiales únicamente

### ⚠️ Penalizaciones

| Infracción | Penalización |
|------------|--------------|
| Distribución no autorizada | Revocación inmediata + permanente + acción legal (DMCA, secreto comercial) |
| Ingeniería inversa / bypass | Bloqueo permanente HWID + clave + acción legal |
| Reventa / compartición | Revocación inmediata + lista negra + indemnización |
| Modificación / bypass firma | Bloqueo permanente + acción legal |
| Distribución en forks/mirrors no autorizados | DMCA takedown + daños + honorarios |
| Uso ilegal | Terminación + reporte a autoridades |

### 🛡️ Repositorio Oficial

| Estado | Repositorio |
|--------|-------------|
| ✅ **OFICIAL** | `https://github.com/MOVIVIPNETWORK/movivip-setup` |
| ❌ **NO AUTORIZADO** | Cualquier fork, mirror, re-upload o derivado |

### 🔒 Adquisición de Licencia

| Canal | Disponibilidad |
|-------|----------------|
| **Telegram (24/7)** | https://t.me/MoviVIP |
| **Email** | vipnetworkmovi@gmail.com |
| **Web** | https://movivip-network.web.app/ |

> ⚠️ **No compres a revendedores, bots, canales no oficiales, Discord, foros o marketplaces.** Licencias de terceros **no activan**, no tienen soporte y **serán revocadas sin reembolso**.

### ✅ Verificación de Autenticidad

```bash
git clone https://github.com/MOVIVIPNETWORK/movivip-setup
cd movivip-setup
git log -1 --format="%an <%ae> %G?"
# MoviVIP Network <vipnetworkmovi@gmail.com> G
sha256sum setup-amd64.sh
# Comparar con https://t.me/MoviVIPNetwork
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

## 📄 Licencia

Este repositorio (documentación, scripts de ejemplo, configuraciones) bajo **CC0-1.0 (Dominio Público)** — uso libre, incluso comercial.

> **Nota**: CC0-1.0 aplica **solo a archivos de este repositorio público**. El **software propietario MoviVIP Network Setup** (binarios, payloads, validadores, esquemas criptográficos) **NO está bajo CC0** y sigue siendo propietario con todos los derechos reservados.

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

**MoviVIP Network** — Infraestructura VPN profesional, automatizada y segura.  
Desarrollado por [MoviVIP Network](https://movivip-network.web.app/) · Soporte: [@MoviVIP](https://t.me/MoviVIP)  
© 2024-2025 MoviVIP Network. Todos los derechos reservados.