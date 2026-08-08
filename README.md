<div align="center">

# 🚀 MoviVIP Network — Multi Script Premium

### La Plataforma Definitiva de Gestión para VPS Ubuntu

**Instalación automática de protocolos VPN · Panel de control todo-en-uno · Seguridad de nivel enterprise · Monitoreo de consumo en tiempo real**

</div>

<br>

<p align="center">
  <img src="https://img.shields.io/badge/Versión-4.0.0-00BFFF?style=for-the-badge&logo=semver&logoColor=white">
  <img src="https://img.shields.io/badge/Ubuntu-22.04%20%7C%2024.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white">
  <img src="https://img.shields.io/badge/Arquitectura-x86_64%20%2F%20AMD64-4EAA25?style=for-the-badge&logo=linux&logoColor=white">
  <img src="https://img.shields.io/badge/Idioma-Bash%20%7C%20Python-3776AB?style=for-the-badge&logo=python&logoColor=white">
  <br>
  <img src="https://img.shields.io/github/stars/studioanime977/MoviVIPNetwork?style=for-the-badge&logo=github">
  <img src="https://img.shields.io/github/forks/studioanime977/MoviVIPNetwork?style=for-the-badge&logo=github">
  <img src="https://img.shields.io/github/license/studioanime977/MoviVIPNetwork?style=for-the-badge">
  <img src="https://img.shields.io/github/last-commit/studioanime977/MoviVIPNetwork?style=for-the-badge&logo=git">
</p>

---

## 📋 Tabla de Contenidos

- [✨ Descripción](#-descripción)
- [⚡ Características Principales](#-características-principales)
- [🛡️ Seguridad](#️-seguridad)
- [🌐 Protocolos Soportados](#-protocolos-soportados)
- [📦 Gestión de Usuarios](#-gestión-de-usuarios)
- [🖥️ Panel de Control](#️-panel-de-control)
- [📊 Monitoreo de Consumo](#-monitoreo-de-consumo)
- [🤖 Ecosistema de Bots](#-ecosistema-de-bots)
- [🚀 Instalación](#-instalación)
- [🔄 Actualización](#-actualización)
- [🏗️ Arquitectura del Sistema](#️-arquitectura-del-sistema)
- [📁 Estructura del Proyecto](#-estructura-del-proyecto)
- [✅ Compatibilidad](#-compatibilidad)
- [🔧 Solución de Errores](#-solución-de-errores)
- [📖 FAQ](#-faq)
- [📞 Soporte](#-soporte)
- [📄 Licencia](#-licencia)

---

## ✨ Descripción

**MoviVIP Network Multi Script Premium** es un **sistema de gestión integral para servidores VPS Ubuntu** diseñado para revendedores y operadores de servicios VPN que buscan una solución de **nivel profesional** sin complejidad.

Un **único instalador** despliega toda la infraestructura: protocolos de conexión, panel de administración, seguridad avanzada, gestión de usuarios y monitoreo de consumo — todo operado desde un **dashboard compacto en una sola pantalla**.

> 💡 **Diseñado para escalar**: de un solo VPS a una red completa de servidores con el mismo flujo de trabajo.

---

## ⚡ Características Principales

| Categoría | Característica |
|:---|:---|
| ⚙️ **Instalación** | Automática, con detección de actualización y restauración vía Git |
| 🔐 **Protocolos** | OpenSSH, Dropbear, SSL/TLS, BadVPN, UDP Custom, SlowDNS, V2Ray/Xray, WebSocket, SystemDNS, ZIPVPN |
| 🖥️ **Panel** | Dashboard premium compacto — 1 pantalla, navegación por menús numerados |
| 👥 **Usuarios** | Crear, editar, eliminar, bloquear, backup, banner personalizado, logs, lista en línea |
| 📊 **Consumo** | Velocidad en tiempo real, acumulado por usuario, límites configurables (GB) |
| 🛡️ **Seguridad** | Fail2ban, rkhunter, chkrootkit, lynis, firewall, protección anti-brute-force |
| 🔥 **Firewall** | Reglas persistentes, control de puertos, bloqueo de tráfico no deseado |
| 🚫 **Filtrado** | Bloqueo de anuncios y torrents integrado |
| ⚡ **Optimización** | Optimizador del sistema + limpieza de procesos colgados |
| 🔄 **Mantenimiento** | Reinicio de servicios, speedtest, cambio de contraseña root, info del VPS |
| 🤖 **Bots** | Ecosistema de bots Telegram (admin + notificaciones) con generador white-label |
| 📡 **Multi-SNI** | Configuración de SNIs desde base de datos centralizada |

---

## 🛡️ Seguridad

El instalador configura automáticamente una **capa de defensa de múltiples niveles**:

### 🔒 Fail2ban — Protección Anti Fuerza Bruta
- Monitorea **SSH y Dropbear**
- **3 intentos fallidos** → baneo por **1 hora**
- **Reincidencia** → baneo por **1 semana**
- Gestión completa desde el menú: ver IPs baneadas, desbanear, whitelist

### 🧬 Auditoría de Seguridad
| Herramienta | Función |
|:---|:---|
| **rkhunter** | Detecta rootkits y binarios alterados |
| **chkrootkit** | Detecta rootkits conocidos |
| **lynis** | Auditoría de hardening con índice de seguridad |

### 🛑 Firewall
- Reglas persistentes con control de puertos por protocolo
- Bloqueo de tráfico no deseado (torrents, anuncios)

---

## 🌐 Protocolos Soportados

| # | Protocolo | Descripción | Puerto (típico) |
|:---:|:---|:---|:---:|
| 1 | **OpenSSH** | Shell seguro estándar | 22 |
| 2 | **Dropbear** | SSH ligero de alto rendimiento | 143 |
| 3 | **SSL/TLS (Stunnel)** | Cifrado SSL sobre conexiones SSH | 443 |
| 4 | **WebSocket (SSH)** | Túnel SSH sobre WebSocket | 80 / 8080 |
| 5 | **ZIPVPN** | Proxy VPN comprimido | — |
| 6 | **BadVPN (UDPGW)** | Soporte de conexiones UDP | 7300 |
| 7 | **UDP Custom** | Túnel UDP personalizado | 9900 |
| 8 | **SlowDNS** | DNS tunneling (SlowDNS/Nameserver) | 5300 |
| 9 | **V2Ray / Xray** | VMess, VLESS, Trojan, Reality | 8443 / 9443 |
| 10 | **SystemDNS** | Servidor DNS del sistema | 53 |

> 🔧 Todos los protocolos se administran desde el menú principal: instalar, iniciar, detener y verificar estado de cada servicio.

---

## 📦 Gestión de Usuarios

| Comando / Opción | Función |
|:---|:---|
| ➕ **Agregar** | Crear usuario SSH con expiración y límite de dispositivos |
| 🆔 **Agregar con HWID** | Crear usuario vinculado a un dispositivo (licencia por hardware) |
| ✏️ **Editar** | Modificar días, límites y estado |
| 🚫 **Bloquear** | Suspender acceso al instante |
| 🗑️ **Eliminar** | Borrar cuenta y datos asociados |
| 💾 **Backup** | Respaldo completo de usuarios |
| 📋 **Listar** | Inventario completo con estado |
| 📈 **Log** | Historial de acciones y conexiones |
| 🎨 **Banner** | Mensaje personalizado al iniciar sesión |
| 🟢 **En línea** | Usuarios conectados en tiempo real con consumo |

---

## 🖥️ Panel de Control

Un **dashboard premium** tipo consola, compacto en una sola pantalla:

```
┌──────────────────────────────────────────────────────┐
│        🚀 MOVIVIP NETWORK — PREMIUM EDITION v4.0     │
│     Panel de Control · Alto Rendimiento y Seguridad  │
├──────────────────────────────────────────────────────┤
│  [01] Menú de Protocolos        [02] Menú de Usuarios │
│  [03] Herramientas              [04] Consumo de Red   │
│  [05] Seguridad / Auditoría     [06] Información VPS  │
│  [07] Firewall                  [08] Speedtest        │
│  [09] Reiniciar Servicios       [10] Cambiar Root Pass│
│  [11] Optimizar Sistema         [12] Actualizar       │
└──────────────────────────────────────────────────────┘
```

**Ejecutar el panel:**

```bash
menu
```

---

## 📊 Monitoreo de Consumo

Sistema de **monitoreo continuo** con base de datos automática:

- 📸 **Snapshot automático** cada minuto (cron + systemd)
- 🗄️ Base de datos en `/etc/movivip/sistema/network_state.conf`
- ⚡ Velocidad de red en **tiempo real** (Mbps)
- 📈 Consumo **acumulado** por usuario
- ⚠️ **Límites configurables** (GB) con alertas

**Configurar límites:**
```
Herramientas → [10] Consumo de Red → [3] Configurar límites (GB)
```

---

## 🤖 Ecosistema de Bots

Incluye un **ecosistema completo de bots de Telegram** para operar el servicio de forma automatizada:

| Componente | Función |
|:---|:---|
| **Bot Administrador** | Gestión completa de usuarios vía Telegram (crear, extender, reducir, configs) |
| **Bot de Notificaciones** | Altas de usuarios, publicidad y plantillas de bienvenida automáticas |
| **Generador White-Label** | `generar-bot-cliente.ps1` — genera un paquete de bots con la **marca del cliente** en minutos |
| **Base de datos compartida** | SQLite central con SNIs, operadores y configuración multi-bot |

> 🏷️ **White-Label**: cada cliente recibe su propio set de bots con su marca, su canal y su dominio.

---

## 🚀 Instalación

### Requisitos previos

| Requisito | Detalle |
|:---|:---|
| 🖥️ **Servidor** | VPS dedicado con acceso root |
| 🐧 **SO** | Ubuntu 22.04 LTS o 24.04 LTS |
| 🏗️ **Arquitectura** | x86_64 / AMD64 |
| 🌐 **Dominio** | DNS apuntando al VPS (para SSL/SlowDNS/WS) |

### Instalación desde cero

```bash
wget -qO- https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/install.sh | bash
```

O con curl:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/install.sh)
```

> ⚠️ **Nota**: ejecutar como **root**. El instalador detecta si ya existe una instalación y ofrece actualizarla automáticamente.

---

## 🔄 Actualización

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/update.sh)
```

El instalador detecta una instalación existente (`/etc/movivip/.git`), sincroniza con el repositorio y **restaura el sistema a la última versión estable** sin perder configuración.

---

## 🏗️ Arquitectura del Sistema

```
┌────────────────────────────────────────────────────────────────────┐
│                      MOVIVIP NETWORK (v4.0)                        │
├────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   ┌──────────────┐     ┌───────────────────┐     ┌──────────────┐  │
│   │  install.sh  │ ──▶ │   /etc/movivip    │ ──▶ │   menu.sh    │  │
│   │  bootstrap   │     │  (sistema+config) │     │  dashboard   │  │
│   └──────────────┘     └─────────┬─────────┘     └──────┬───────┘  │
│                                  │                       │          │
│   ┌──────────────────────────────┼───────────────────────┼────────┐ │
│   │  PROTOCOLOS                  │                       │        │ │
│   │  ┌───────────────────────────▼────┐   ┌──────────────▼──────┐ │ │
│   │  │  openssh · dropbear · ssl     │   │  USUARIOS            │ │ │
│   │  │  ws · zipvpn · badvpn         │   │  add · delete · edit │ │ │
│   │  │  udpcustom · slowdns          │   │  block · backup ·    │ │ │
│   │  │  v2ray · xray · systemdns     │   │  list · log · online │ │ │
│   │  └───────────────────────────────┘   │  add_hwid · hwid_list│ │ │
│   │                                      └──────────┬───────────┘ │ │
│   │  ┌───────────────────────────────┐              │             │ │
│   │  │  HERRAMIENTAS                 │   ┌──────────▼───────────┐ │ │
│   │  │  firewall · speedtest ·       │   │  SEGURIDAD           │ │ │
│   │  │  blockads · blocktorrent ·    │   │  fail2ban · rkhunter │ │ │
│   │  │  detalles · rootpass ·        │   │  chkrootkit · lynis  │ │ │
│   │  │  reiniciar · auditoria ·      │   │  firewall            │ │ │
│   │  │  optimizar · network_snapshot │   └──────────────────────┘ │ │
│   │  └───────────────────────────────┘                             │ │
│   └────────────────────────────────────────────────────────────────┘ │
│                                                                     │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │  ECOSISTEMA BOTS (Telegram)                                  │  │
│   │  admin_bot · notif_bot · ssh_utils · database (SQLite)      │  │
│   │  + generador white-label (generar-bot-cliente.ps1)          │  │
│   └──────────────────────────────────────────────────────────────┘  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 📁 Estructura del Proyecto

```
scrip vps todo/
├── install.sh                  # Instalador automático (bootstrap)
├── menu.sh                     # Panel de control principal
├── update.sh                   # Actualización vía Git
├── version.txt                 # Versión del sistema
├── herramientas/               # Herramientas del sistema
│   ├── firewall.sh             #   Reglas de firewall
│   ├── speedtest.sh            #   Test de velocidad
│   ├── blockads.sh             #   Bloqueo de anuncios
│   ├── blocktorrent.sh         #   Bloqueo de torrents
│   ├── fail2ban.sh             #   Protección anti brute-force
│   ├── auditoria.sh            #   Rkhunter + chkrootkit + lynis
│   ├── network_traffic.sh      #   Consumo de red en tiempo real
│   ├── network_snapshot.sh     #   Snapshot automático (cron)
│   ├── optimizar.sh            #   Optimización del sistema
│   ├── detalles.sh             #   Información del VPS
│   ├── rootpass.sh             #   Cambio de contraseña root
│   ├── reiniciar.sh            #   Reinicio de servicios
│   ├── archivoonline.sh        #   Archivos en línea
│   ├── change-domain           #   Cambio de dominio
│   ├── scanner.sh              #   Escáner de seguridad
│   └── menu.sh                 #   Menú de herramientas
├── protocolos/                 # Protocolos VPN
│   ├── openssh.sh              #   OpenSSH
│   ├── dropbear.sh             #   Dropbear
│   ├── ssl.sh                  #   SSL/TLS (Stunnel)
│   ├── onlineapp.sh            #   WebSocket SSH
│   ├── zipvpn.sh               #   ZIPVPN
│   ├── badvpn.sh               #   BadVPN / UDPGW
│   ├── udpcustom.sh            #   UDP Custom
│   ├── slowdns.sh              #   SlowDNS
│   ├── v2ray.sh                #   V2Ray / Xray
│   ├── systemdns.sh            #   SystemDNS
│   ├── checkuser.sh            #   Verificador de usuarios
│   ├── bot.sh                  #   Instalación de bots
│   ├── bots_extract/           #   Plantillas de bots (admin/notif/user)
│   ├── generar-bot-cliente.ps1 #   Generador white-label de bots
│   └── plantilla-entrega-bot.txt # Plantilla de entrega al cliente
└── usuarios/                   # Gestión de usuarios
    ├── add.sh                  #   Agregar usuario
    ├── add_hwid.sh             #   Agregar con HWID (licencia)
    ├── delete.sh               #   Eliminar usuario
    ├── edit.sh                 #   Editar usuario
    ├── block.sh                #   Bloquear usuario
    ├── list.sh                 #   Listar usuarios
    ├── log.sh                  #   Log de acciones
    ├── online.sh               #   Usuarios en línea + consumo
    ├── backup.sh               #   Backup de usuarios
    ├── banner.sh               #   Banner personalizado
    ├── hwid_list.sh            #   Lista de HWIDs
    └── menu.sh                 #   Menú de usuarios
```

---

## ✅ Compatibilidad

| Plataforma | Versión | Estado |
|:---|:---|:---:|
| 🐧 Ubuntu | 22.04 LTS | ✅ Soportado |
| 🐧 Ubuntu | 24.04 LTS | ✅ Soportado |
| 🏗️ Arquitectura | x86_64 / AMD64 | ✅ Soportado |
| 🖥️ VPS | Cualquier proveedor (DigitalOcean, Vultr, Contabo, OVH, etc.) | ✅ Soportado |

---

## 🔧 Solución de Errores

### ❌ Error de here-document / sintaxis

Si algún módulo muestra un error similar:

```text
warning: here-document delimited by end-of-file (wanted `EOF`)
syntax error: unexpected end of file
```

**Solución:**

```bash
sed -i 's/[[:space:]]*$//' /etc/movivip/protocolos/ssl.sh
bash -n /etc/movivip/protocolos/ssl.sh
```

> 💡 Si el problema ocurre en otro módulo, reemplaza `ssl.sh` por el nombre del script afectado. Si `bash -n` no muestra ningún mensaje, el script **no tiene errores de sintaxis**.

### ❌ El menú no abre

```bash
# Verifica que el sistema está instalado
ls -la /etc/movivip/config.conf

# Si no existe, ejecuta el instalador
bash install.sh
```

---

## 📖 FAQ

<details>
<summary><b>¿Puedo instalar en Debian o CentOS?</b></summary>
No. El sistema está optimizado exclusivamente para <b>Ubuntu 22.04 y 24.04</b> con arquitectura x86_64.
</details>

<details>
<summary><b>¿Cómo cambio el puerto de un protocolo?</b></summary>
Usa el menú de protocolos o edita la configuración en <code>/etc/movivip/config.conf</code> y reinicia el servicio.
</details>

<details>
<summary><b>¿La actualización pierde mis usuarios?</b></summary>
No. El sistema se actualiza vía Git preservando la configuración y los usuarios existentes.
</details>

<details>
<summary><b>¿Cómo protejo mi VPS de ataques de fuerza bruta?</b></summary>
El sistema instala <b>Fail2ban</b> automáticamente: 3 intentos fallidos = baneo 1h, reincidencia = 1 semana.
</details>

<details>
<summary><b>¿Puedo usar el generador de bots para mis clientes?</b></summary>
Sí. <code>generar-bot-cliente.ps1</code> genera un paquete completo de bots Telegram con la marca de tu cliente en minutos.
</details>

---

## 📞 Soporte

| Canal | Enlace |
|:---|:---|
| 📢 **Canal Telegram** | [t.me/MoviVIPNetwork](https://t.me/MoviVIPNetwork) |
| 👥 **Grupo Telegram** | [t.me/MoviVIPNet](https://t.me/MoviVIPNet) |
| 🌐 **Web** | [movivip-network.web.app](https://movivip-network.web.app/) |
| 💬 **Contacto** | [@MoviVIP](https://t.me/MoviVIP) |

---

## 📄 Licencia

Distribuido con fines de uso autorizado. La reventa o redistribución no autorizada del sistema completo está prohibida.

---

<div align="center">

**⭐ Si este proyecto te fue útil, no olvides darle una estrella** ⭐

<br>

*Hecho con dedicación para la comunidad MoviVIP Network* 💙

**© 2026 MoviVIP Network — Todos los derechos reservados**

</div>
