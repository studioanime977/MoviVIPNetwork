<div align="center">

<img src="assets/logo.png" alt="MoviVIP Network" width="280"/>

<br/>
<br/>

# MoviVIP Network Setupâ„¢

### Instalador unificado para servidores VPN/VPS
### Automatizado Â· Firmado Â· Cifrado Â· Multi-Protocolo

<br/>

<p>
  <img src="https://img.shields.io/badge/Go-1.22+-00ADD8?style=for-the-badge&logo=go&logoColor=white" alt="Go"/>
  <img src="https://img.shields.io/badge/Ubuntu-20.04%2B%20|%20Debian%2011%2B-E95420?style=for-the-badge&logo=ubuntu&logoColor=white" alt="OS"/>
  <img src="https://img.shields.io/badge/Arch-x86__64%20|%20ARM64-FF6B6B?style=for-the-badge&logo=arm&logoColor=white" alt="Arch"/>
</p>
<p>
  <img src="https://img.shields.io/badge/Telegram-Soporte%2024%2F7-2CA5E0?style=for-the-badge&logo=telegram&logoColor=white" alt="Telegram"/>
  <img src="https://img.shields.io/badge/Licencia-Propietaria-EF4444?style=for-the-badge&logo=lock&logoColor=white" alt="License"/>
  <img src="https://img.shields.io/badge/Protocolos-26%20incluidos-8B5CF6?style=for-the-badge&logo=shield&logoColor=white" alt="Protocols"/>
</p>
<p>
  <img src="https://img.shields.io/badge/AES--256--GCM-Cifrado%20RAM-10B981?style=for-the-badge&logo=gnuprivacyguard&logoColor=white" alt="AES"/>
  <img src="https://img.shields.io/badge/Ed25519-Firma%20Digital-F59E0B?style=for-the-badge&logo=gnuprivacyguard&logoColor=white" alt="Ed25519"/>
  <img src="https://img.shields.io/badge/HWID-Licencia%20Vinculada-6366F1?style=for-the-badge&logo=fingerprint&logoColor=white" alt="HWID"/>
</p>

<br/>

> **Convierte cualquier VPS limpio en un servidor VPN empresarial operativo en minutos.**
> Instalador Ãºnico firmado Â· Payload cifrado en RAM Â· Licencia criptogrÃ¡fica obligatoria

<br/>

[ðŸš€ InstalaciÃ³n](#-instalaciÃ³n-rÃ¡pida) &nbsp;Â·&nbsp;
[âœ… QuÃ© incluye](#-quÃ©-incluye) &nbsp;Â·&nbsp;
[ðŸ›¡ï¸ Protocolos](#-matriz-de-protocolos) &nbsp;Â·&nbsp;
[ðŸ—ï¸ Arquitectura](#-arquitectura) &nbsp;Â·&nbsp;
[ðŸ’Ž Planes](#-planes-y-licenciamiento) &nbsp;Â·&nbsp;
[â“ FAQ](#-faq) &nbsp;Â·&nbsp;
[ðŸ“ž Soporte](#-soporte)

</div>

---

## ðŸ“– Tabla de Contenidos

<details>
<summary><b>Ver Ã­ndice completo</b></summary>
<br/>

- [ðŸŽ¯ Â¿QuÃ© es MoviVIP Network Setup?](#-quÃ©-es-movivip-network-setup)
- [âš¡ InstalaciÃ³n RÃ¡pida](#-instalaciÃ³n-rÃ¡pida)
- [âœ… QuÃ© incluye](#-quÃ©-incluye)
- [ðŸ›¡ï¸ Matriz de Protocolos (26)](#-matriz-de-protocolos)
- [ðŸ—ï¸ Arquitectura & Seguridad CriptogrÃ¡fica](#-arquitectura)
- [ðŸ’» Compatibilidad y Requisitos](#-compatibilidad-y-requisitos)
- [ðŸ’Ž Planes y Licenciamiento](#-planes-y-licenciamiento)
- [ðŸ› ï¸ Post-InstalaciÃ³n & CLI](#-post-instalaciÃ³n--cli)
- [ðŸ” VerificaciÃ³n de Integridad](#-verificaciÃ³n-de-integridad)
- [â“ FAQ](#-faq)
- [âš–ï¸ TÃ©rminos Legales](#-tÃ©rminos-legales)
- [ðŸ“¦ Archivos del Repositorio](#-archivos-del-repositorio)
- [ðŸ“ž Soporte y Comunidad](#-soporte)
- [ðŸ“„ Licencia](#-licencia)

</details>

---

## ðŸŽ¯ Â¿QuÃ© es MoviVIP Network Setup?

**MoviVIP Network Setup** es una soluciÃ³n de infraestructura de grado empresarial que automatiza por completo la transformaciÃ³n de un VPS limpio *(Ubuntu / Debian)* en un nodo VPN multi-protocolo, securizado y monitoreable desde un panel centralizado.

Un Ãºnico archivo `.sh` por arquitectura encapsula el ecosistema completo:

```
  setup-{arch}.sh
  â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
  â”‚  â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”   â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”  â”‚
  â”‚  â”‚     Go Stub Binary     â”‚   â”‚   Payload AES-256-GCM (RAM)  â”‚  â”‚
  â”‚  â”‚  â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€  â”‚   â”‚  â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€  â”‚  â”‚
  â”‚  â”‚  â€¢ Valida Arquitectura â”‚   â”‚  â€¢ Scripts de configuraciÃ³n  â”‚  â”‚
  â”‚  â”‚  â€¢ Verifica Ed25519    â”‚   â”‚  â€¢ Binarios de protocolos    â”‚  â”‚
  â”‚  â”‚  â€¢ Autentica HWID      â”‚   â”‚  â€¢ Paneles de gestiÃ³n        â”‚  â”‚
  â”‚  â”‚  â€¢ Gate de Licencia    â”‚   â”‚  â€¢ MÃ³dulos de seguridad      â”‚  â”‚
  â”‚  â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜   â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜  â”‚
  â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
```

| Principio | DescripciÃ³n |
|:---|:---|
| ðŸ” **Zero-Disk Exposure** | Payload descifrado solo en `tmpfs` RAM â€” sin residuos en disco |
| ðŸ›¡ï¸ **Ed25519 Signature** | VerificaciÃ³n criptogrÃ¡fica antes de ejecutar cualquier componente |
| ðŸ”— **HWID Binding** | Licencia vinculada a hardware â€” imposible clonar o transferir |
| âš¡ **Multi-Architecture** | Binario nativo para `x86_64` y `ARM64` â€” rendimiento mÃ¡ximo |
| ðŸ¤– **Fully Automated** | Sin configuraciÃ³n manual â€” detecciÃ³n y optimizaciÃ³n automÃ¡tica |

---

## âš¡ InstalaciÃ³n RÃ¡pida

> [!IMPORTANT]
> Requiere usuario **`root`** y acceso a internet. Reemplaza `TU_CLAVE` con tu licencia MoviVIP obtenida en [@MoviVIP](https://t.me/MoviVIP).

### ðŸš€ MÃ©todo 1 â€” One-Liner Auto-Detection *(Recomendado)*

```bash
bash -c "$(wget -qO- https://github.com/studioanime977/MoviVIPNetwork/raw/main/install-auto.sh)" TU_CLAVE
```

> Detecta la arquitectura del servidor, descarga el binario correcto y ejecuta la instalaciÃ³n automÃ¡ticamente.

---

### ðŸ“¦ MÃ©todo 2 â€” InstalaciÃ³n Manual por Arquitectura

<details>
<summary><b>ðŸ–¥ï¸ x86_64 â€” Intel / AMD &nbsp;Â·&nbsp; DigitalOcean Â· Vultr Â· Hetzner Â· Contabo Â· AWS EC2</b></summary>
<br/>

```bash
wget https://github.com/studioanime977/MoviVIPNetwork/raw/main/setup-amd64.sh
chmod +x setup-amd64.sh
bash setup-amd64.sh TU_CLAVE
```

</details>

<details>
<summary><b>ðŸ¦¾ ARM64 / aarch64 &nbsp;Â·&nbsp; Oracle Cloud A1/Flex Â· AWS Graviton Â· Google Cloud ARM Â· Azure ARM</b></summary>
<br/>

```bash
wget https://github.com/studioanime977/MoviVIPNetwork/raw/main/setup-arm64.sh
chmod +x setup-arm64.sh
bash setup-arm64.sh TU_CLAVE
```

</details>

<br/>

> [!TIP]
> Â¿No tienes licencia aÃºn? AdquiÃ©rela directamente en **[@MoviVIP](https://t.me/MoviVIP)** â€” Soporte 24/7 en Telegram.

---

## âœ… QuÃ© incluye

<table>
<tr>
<td valign="top" width="50%">

### ðŸ›¡ï¸ Protocolos & TÃºneles
- **26 mÃ³dulos** entre VPN, proxies y tÃºneles
- OpenSSH, Dropbear SSH, SSL/TLS, WebSocket
- XRay/V2Ray: VMess, VLESS, Reality, XTLS
- WireGuard *(kernel-level)*, OpenVPN
- Hysteria 2 *(QUIC/UDP â€” anti-censura)*
- SlowDNS, VayDNS, SystemDNS, ZiVPN, DTunnel
- Shadowsocks, SOCKS5, Squid HTTP/HTTPS
- BadVPN UDPGW, UDP Custom, HCR Relay
- SSH-XHTTP, BHTTP v2, BTUN

</td>
<td valign="top" width="50%">

### ðŸ–¥ï¸ Paneles & GestiÃ³n
- **Bot de Telegram** â€” creaciÃ³n/gestiÃ³n de usuarios
- **3X-UI Panel** â€” interfaz XRay multi-inbound
- **Web MoviVIP** *(FastAPI)* â€” panel web oficial
- **Webmin** â€” administraciÃ³n del servidor web
- **CLI nativo** â€” `menu`, `protocolos`, `usuarios`

### âš¡ Infraestructura & Seguridad
- HAProxy balanceador + multiplexaciÃ³n de puertos
- OptimizaciÃ³n TCP: BBR, FQ-Pacing, MTU dinÃ¡mico
- Fail2ban + Firewall persistente multi-capa
- Snapshots de red, monitoreo por usuario
- RotaciÃ³n de logs + alertas de expiraciÃ³n
- Cloudflare CDN bypass + VayDNS + SlowDNS

</td>
</tr>
</table>

---

## ðŸ›¡ï¸ Matriz de Protocolos

<div align="center">

| # | Protocolo | Tipo | Transporte | Anti-Censura |
|:--:|:---|:---|:---|:---:|
| `01` | **OpenSSH** | Acceso seguro | TCP | â€” |
| `02` | **Dropbear SSH** | SSH ligero | TCP | â€” |
| `03` | **SSL/TLS Tunnel** | TÃºnel cifrado | TLS 1.3 | âœ… |
| `04` | **WebSocket (WS)** | HTTP Upgrade | HTTP/1.1 + WS | âœ… CDN |
| `05` | **XRay / V2Ray** | VMess Â· VLESS Â· Reality | TCP / gRPC / WS | âœ… |
| `06` | **WireGuard** | VPN moderna | UDP Kernel | â€” |
| `07` | **OpenVPN** | VPN estÃ¡ndar | TCP + UDP | â€” |
| `08` | **Shadowsocks** | Proxy cifrado | TCP / TLS | âœ… |
| `09` | **Hysteria 2** | Ultra-rÃ¡pido QUIC | UDP / QUIC | âœ… |
| `10` | **SlowDNS** | DNS Tunnel | UDP 53 | âœ… |
| `11` | **VayDNS / SystemDNS** | DNS personalizado | UDP | âœ… |
| `12` | **ZiVPN** | VPN propietaria | UDP | âœ… |
| `13` | **DTunnel** | TÃºnel propietario | Binary | âœ… |
| `14` | **BadVPN UDPGW** | UDP Gateway | UDP Multi-port | â€” |
| `15` | **UDP Custom** | UDP propietario | Binary | âœ… |
| `16` | **SOCKS5** | Proxy estÃ¡ndar | TCP | â€” |
| `17` | **Squid** | Proxy HTTP/HTTPS | HTTP/CONNECT | â€” |
| `18` | **SSH-XHTTP** | SSH sobre HTTP | HTTP | âœ… |
| `19` | **BHTTP v2** | HTTP binario | Binary HTTP | âœ… |
| `20` | **BTUN** | TÃºnel binario | Binary | âœ… |
| `21` | **HCR Relay** | Relay propietario | TCP | âœ… |
| `22` | **Payload Module** | MÃ³dulo propietario | â€” | â€” |
| `23` | **Bot Telegram** | AutomatizaciÃ³n | HTTPS API | â€” |
| `24` | **3X-UI Panel** | Panel XRay | HTTP/HTTPS | â€” |
| `25` | **Web MoviVIP** | Panel oficial | HTTP/FastAPI | â€” |
| `26` | **Webmin** | Admin servidor | HTTPS | â€” |

</div>

> **26 mÃ³dulos totales**: protocolos de red, paneles de gestiÃ³n y utilidades de sistema.

---

## ðŸ—ï¸ Arquitectura

```
â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
â•‘            MOVIVIP NETWORK â€” FLOW DE INSTALACIÃ“N & SEGURIDAD            â•‘
â• â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•£
â•‘                                                                          â•‘
â•‘   [ USUARIO ]  â”€â”€â–º  bash setup-<arch>.sh  YOUR_LICENSE_KEY              â•‘
â•‘                                   â”‚                                      â•‘
â•‘                                   â–¼                                      â•‘
â•‘              â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”                      â•‘
â•‘              â”‚          Go Stub Binary            â”‚                      â•‘
â•‘              â”‚  â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”  â”‚                      â•‘
â•‘              â”‚  â”‚  1. Valida Arquitectura       â”‚  â”‚                      â•‘
â•‘              â”‚  â”‚  2. Verifica Firma Ed25519    â”‚  â”‚ â—„â”€â”€ Firma oficial    â•‘
â•‘              â”‚  â”‚  3. Autentica HWID            â”‚  â”‚ â—„â”€â”€ Hardware ID      â•‘
â•‘              â”‚  â”‚  4. Valida Licencia Cripto    â”‚  â”‚ â—„â”€â”€ Tu clave         â•‘
â•‘              â”‚  â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜  â”‚                      â•‘
â•‘              â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜                      â•‘
â•‘                                 â”‚ âœ… VerificaciÃ³n OK                     â•‘
â•‘                                 â–¼                                        â•‘
â•‘              â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”                      â•‘
â•‘              â”‚       Descifrado AES-256-GCM       â”‚                      â•‘
â•‘              â”‚   Payload â†’ memoria RAM (tmpfs)    â”‚ â—„â”€â”€ Zero disk write  â•‘
â•‘              â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜                      â•‘
â•‘                                 â”‚                                        â•‘
â•‘         â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”                   â•‘
â•‘         â–¼                       â–¼                    â–¼                   â•‘
â•‘  â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”    â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”   â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”       â•‘
â•‘  â”‚ 26 Protocol  â”‚    â”‚   Mgmt Suite      â”‚   â”‚  Kernel & Net    â”‚       â•‘
â•‘  â”‚   Modules    â”‚    â”‚  Bot Â· 3X-UI      â”‚   â”‚  BBR Â· FQ Â· MTU  â”‚       â•‘
â•‘  â”‚ VPNÂ·ProxyÂ·WS â”‚    â”‚  WebPanel Â· Webminâ”‚   â”‚  Fail2ban Â· UFW  â”‚       â•‘
â•‘  â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜    â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜   â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜       â•‘
â•‘                                 â”‚                                        â•‘
â•‘                                 â–¼                                        â•‘
â•‘              â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”                      â•‘
â•‘              â”‚     ðŸ—‘ï¸  Purga automÃ¡tica tmpfs      â”‚ â—„â”€â”€ Cero residuos   â•‘
â•‘              â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜                      â•‘
â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
```

### ðŸ” Routing de TrÃ¡fico

```mermaid
graph LR
    A[ðŸŒ TrÃ¡fico Entrante] --> B{HAProxy
Port Mux}
    B --> C[SSH/Dropbear
:22 Â· :443]
    B --> D[XRay/V2Ray
:443 Â· :80]
    B --> E[WireGuard
UDP :51820]
    B --> F[Hysteria 2
QUIC :443]
    B --> G[WebSocket
Cloudflare CDN]
    C --> H[ðŸ›¡ï¸ Fail2ban + UFW]
    D --> H
    E --> H
    F --> H
    G --> H
    H --> I[âœ… Servidor Seguro]
```

---

## ðŸ’» Compatibilidad y Requisitos

### ðŸ–¥ï¸ Sistemas Operativos

| DistribuciÃ³n | Versiones Soportadas | Estado |
|:---|:---|:---:|
| **Ubuntu** | `20.04 LTS` Â· `22.04 LTS` Â· `24.04 LTS` | âœ… Certificado |
| **Debian** | `11 Bullseye` Â· `12 Bookworm` | âœ… Certificado |
| **CentOS / RHEL** | Cualquier versiÃ³n | âŒ No soportado |
| **OpenVZ / LXC** | Cualquier versiÃ³n | âŒ No soportado |
| **ARMv7 / i386** | Cualquier versiÃ³n | âŒ No soportado |

### âš™ï¸ Especificaciones de Hardware

| ParÃ¡metro | MÃ­nimo | Recomendado |
|:---|:---|:---|
| **CPU** | 1 vCPU x86_64 Ã³ ARM64 | 2+ vCPU ARM64 Ampere / AMD EPYC |
| **RAM** | 512 MB | 1 â€“ 2 GB |
| **Disco** | 5 GB SSD | 15+ GB NVMe |
| **VirtualizaciÃ³n** | KVM | KVM |
| **Acceso** | `root` | `root` |
| **Red** | Salida a internet | Salida a internet |

### â˜ï¸ Cloud Providers Certificados

<div align="center">

| Provider | Arquitectura | Estado |
|:---|:---:|:---:|
| **Oracle Cloud** *(A1 Â· Flex)* | ARM64 | âœ… Certificado |
| **AWS Graviton** *(EC2)* | ARM64 | âœ… Certificado |
| **Google Cloud** *(GCE)* | ARM64 Â· x86_64 | âœ… Certificado |
| **Microsoft Azure** | ARM64 Â· x86_64 | âœ… Certificado |
| **DigitalOcean** | x86_64 KVM | âœ… Certificado |
| **Hetzner Cloud** | x86_64 KVM | âœ… Certificado |
| **Vultr** | x86_64 KVM | âœ… Certificado |
| **Contabo** | x86_64 KVM | âœ… Certificado |

</div>

---

## ðŸ’Ž Planes y Licenciamiento

<div align="center">

| MÃ³dulo / CaracterÃ­stica | ðŸ¥‰ Bronze Â· Standard | ðŸ¥ˆ Premium + | ðŸ¥‡ Provider Â· Admin |
|:---|:---:|:---:|:---:|
| OpenSSH Â· Dropbear Â· SSL/TLS | âœ… | âœ… | âœ… |
| BadVPN Â· UDP Custom Â· SlowDNS | âœ… | âœ… | âœ… |
| WebSocket + Cloudflare CDN | âœ… | âœ… | âœ… |
| VayDNS Â· ZiVPN Â· DTunnel | âœ… | âœ… | âœ… |
| Gestor de Usuarios CLI | âœ… | âœ… | âœ… |
| **Bot Telegram Automatizado** | âŒ | âœ… | âœ… |
| **Panel Webmin** | âŒ | âœ… | âœ… |
| **XRay Â· VMess Â· VLESS Â· Reality** | âŒ | âœ… | âœ… |
| **Hysteria 2 Â· WireGuard Â· OpenVPN** | âŒ | âœ… | âœ… |
| **3X-UI Panel (XTLS / Reality)** | âŒ | âŒ | âœ… |
| **Web MoviVIP (FastAPI)** | âŒ | âŒ | âœ… |
| **OptimizaciÃ³n Kernel** *(BBR Â· FQ Â· MTU)* | âŒ | âŒ | âœ… |
| **Firewall Avanzado Â· Anti-DDoS** | âŒ | âŒ | âœ… |
| **MÃ³dulo FacturaciÃ³n Â· Revendedores** | âŒ | âŒ | âœ… |
| **Shadowsocks Â· SOCKS5 Â· Squid** | âŒ | âŒ | âœ… |
| **HCR Relay Â· BHTTP v2 Â· BTUN** | âŒ | âŒ | âœ… |
| Soporte tÃ©cnico | EstÃ¡ndar | Prioritario | **Dedicado 1-a-1** |

</div>

> [!NOTE]
> La licencia se valida **criptogrÃ¡ficamente (Ed25519 + HWID)** antes de iniciar cualquier instalaciÃ³n.
> No existen claves en texto plano ni archivos de licencia editables localmente.

**âž¡ï¸ Adquiere tu licencia:** **[@MoviVIP](https://t.me/MoviVIP)** â€” disponibilidad 24/7

---

## ðŸ› ï¸ Post-InstalaciÃ³n & CLI

Tras completar la instalaciÃ³n, el sistema registra comandos nativos en tu entorno de shell:

```bash
menu       # Panel de control principal
```

```
â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
â•‘          MOVIVIP NETWORK MANAGER  Â·  v3.0  â„¢              â•‘
â•‘           Â© 2024-2025 MoviVIP Network                     â•‘
â• â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•£
â•‘  [1]  GestiÃ³n de Protocolos VPN                           â•‘
â•‘  [2]  GestiÃ³n de Usuarios & Cuentas                       â•‘
â•‘  [3]  Bot de Telegram & Alertas                           â•‘
â•‘  [4]  Panel Web & Certificados SSL Let's Encrypt          â•‘
â•‘  [5]  OptimizaciÃ³n de Red & Kernel (BBR/FQ/MTU)           â•‘
â•‘  [6]  DiagnÃ³stico Â· Logs en Vivo Â· Test de Velocidad      â•‘
â•‘  [7]  Backup & RestauraciÃ³n del Servidor                  â•‘
â•‘  [8]  Actualizar Sistema                                  â•‘
â•‘  [0]  Salir                                               â•‘
â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
```

| Comando | DescripciÃ³n |
|:---|:---|
| `menu` | Panel principal interactivo |
| `protocolos` | GestiÃ³n de daemons, puertos y certificados por protocolo |
| `usuarios` | Crear Â· listar Â· renovar Â· revocar cuentas VPN |
| `herramientas` | Test de velocidad Â· auditorÃ­a de puertos Â· estado Fail2ban |

---

## ðŸ” VerificaciÃ³n de Integridad

Antes de ejecutar cualquier instalador, verifica que proviene del repositorio oficial:

```bash
# 1. Clonar el repositorio oficial
git clone https://github.com/studioanime977/MoviVIPNetwork
cd movivip-setup

# 2. Verificar firma del commit â€” debe terminar en "G" (GPG verified)
git log -1 --format="%an <%ae> %G?"
# âœ… Esperado: MoviVIP Network <vipnetworkmovi@gmail.com> G

# 3. Verificar hash SHA-256 del instalador
sha256sum setup-amd64.sh   # Para x86_64
sha256sum setup-arm64.sh   # Para ARM64
# Compara con los hashes publicados en https://t.me/MoviVIPNetwork
```

> [!CAUTION]
> Si `git log` **no muestra `G`** al final, el commit **no estÃ¡ firmado por MoviVIP Network**.
> **No ejecutes ese instalador.** DescÃ¡rgalo Ãºnicamente desde el [repositorio oficial](https://github.com/studioanime977/MoviVIPNetwork).

---

## â“ FAQ

<details>
<summary><b>ðŸ’³ Â¿Puedo mover mi licencia a otro servidor?</b></summary>
<br/>

Las licencias estÃ¡n vinculadas al HWID del servidor activo. Para migraciones autorizadas, contacta al [Soporte Oficial](https://t.me/MoviVIP) â€” el equipo realiza el desvinculado y re-binding de forma manual y verificada.

</details>

<details>
<summary><b>ðŸ”Œ Â¿El instalador modifica o interrumpe mi sesiÃ³n SSH activa?</b></summary>
<br/>

No. El instalador preserva tu puerto SSH actual y aÃ±ade puertos de multiplexaciÃ³n adicionales (443, 80, 8080) **sin interrumpir tu sesiÃ³n remota activa**.

</details>

<details>
<summary><b>ðŸ”„ Â¿CÃ³mo se actualizan los protocolos y parches de seguridad?</b></summary>
<br/>

El sistema integra una sincronizaciÃ³n automÃ¡tica de firmas y binarios cada **48 horas**. Para forzar una actualizaciÃ³n manual: `menu â†’ [8] Actualizar Sistema`.

</details>

<details>
<summary><b>â±ï¸ Â¿CuÃ¡nto tiempo tarda la instalaciÃ³n completa?</b></summary>
<br/>

Dependiendo de la velocidad de red del VPS y el plan seleccionado, la instalaciÃ³n tÃ­pica lleva entre **3 y 8 minutos**.

</details>

<details>
<summary><b>ðŸ›¡ï¸ Â¿CÃ³mo sÃ© que el instalador no tiene backdoors?</b></summary>
<br/>

Cada instalador estÃ¡ firmado con **Ed25519** por MoviVIP Network. El stub Go verifica esta firma **antes** de descomprimir cualquier componente. El payload se ejecuta solo en RAM (`tmpfs`) y se purga automÃ¡ticamente al finalizar â€” sin escritura en disco. Puedes verificar la firma del commit con `git log` tal como se indica en la secciÃ³n de [VerificaciÃ³n de Integridad](#-verificaciÃ³n-de-integridad).

</details>

<details>
<summary><b>ðŸŒ Â¿Bypasea restricciones ISP / DPI?</b></summary>
<br/>

MoviVIP incluye protocolos anti-censura especÃ­ficos: **Hysteria 2**, **SlowDNS**, **ZiVPN**, **WebSocket+CDN** y **DTunnel**, diseÃ±ados para entornos con inspecciÃ³n profunda de paquetes (DPI) y restricciones ISP. La efectividad puede variar segÃºn el paÃ­s y el operador.

</details>

---

## âš–ï¸ TÃ©rminos Legales

### ðŸ“œ Copyright y Propiedad Intelectual

<div align="center">

```
â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
â•‘         Â© 2024â€“2025 MoviVIP Network                     â•‘
â•‘              Todos los derechos reservados              â•‘
â•‘                                                         â•‘
â•‘   Software propietario â€” Licencia requerida para uso    â•‘
â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
```

</div>

El cÃ³digo fuente, binarios, algoritmos criptogrÃ¡ficos, protocolos propietarios y la marca **MoviVIP** son propiedad exclusiva de **MoviVIP Network**.

**EstÃ¡ estrictamente prohibido:**

| âŒ ProhibiciÃ³n | Alcance |
|:---|:---|
| IngenierÃ­a inversa / descompilaciÃ³n | Binarios, stub, validadores, esquemas criptogrÃ¡ficos |
| DistribuciÃ³n no autorizada | Forks, mirrors, re-uploads, canales no oficiales |
| Reventa / comparticiÃ³n de licencias | Cualquier medio o canal |
| ModificaciÃ³n de binarios o bypass de firma | Cualquier componente del instalador |
| Desarrollo de productos competidores | Basados total o parcialmente en este software |
| FiltraciÃ³n de claves o material criptogrÃ¡fico | Cualquier canal pÃºblico o privado |

### ðŸ›¡ï¸ Repositorio Oficial

| Estado | URL |
|:---:|:---|
| âœ… **OFICIAL** | `https://github.com/studioanime977/MoviVIPNetwork` |
| âŒ **NO AUTORIZADO** | Cualquier fork, mirror, re-upload o repositorio derivado |

DistribuciÃ³n fuera del repo oficial **serÃ¡ perseguida legalmente (DMCA, derechos de autor, secreto comercial).**

### âš ï¸ Tabla de Penalizaciones

| InfracciÃ³n | Consecuencia Inmediata | AcciÃ³n Legal |
|:---|:---|:---|
| DistribuciÃ³n no autorizada | RevocaciÃ³n permanente de todas las licencias | DMCA Â· Secreto Comercial |
| IngenierÃ­a inversa / bypass | Bloqueo permanente HWID + clave | DMCA 1201 Â· Secretos Comerciales |
| Reventa / comparticiÃ³n | RevocaciÃ³n + lista negra + indemnizaciÃ³n | DaÃ±os y perjuicios |
| DistribuciÃ³n en forks / mirrors | RevocaciÃ³n + bloqueo inmediato | DMCA Takedown + honorarios |
| Uso en actividades ilegales | TerminaciÃ³n inmediata | Reporte a autoridades |

### ðŸ“‹ TÃ©rminos de Uso â€” Resumen

1. **Licencia personal e intransferible** â€” Vinculada a tu identidad y hardware del servidor
2. **Una licencia = una instancia activa** â€” Instalaciones concurrentes revocan la licencia automÃ¡ticamente
3. **Actualizaciones obligatorias** â€” Auto-actualizaciÃ³n cada 48h no puede desactivarse sin perder soporte
4. **Sin garantÃ­a implÃ­cita** â€” Software provisto "TAL CUAL"
5. **Cumplimiento legal** â€” Eres responsable de cumplir las leyes locales sobre VPN y cifrado

### ðŸ”’ AdquisiciÃ³n de Licencia Oficial

> [!WARNING]
> **No adquieras licencias a travÃ©s de revendedores, bots, canales no oficiales de Telegram, Discord, foros o marketplaces.**
> Las licencias de terceros **no activan el software**, no tienen soporte y **serÃ¡n revocadas sin reembolso**.

| Canal | DescripciÃ³n | Enlace |
|:---|:---|:---|
| ðŸ›¡ï¸ **Telegram Soporte** | AdquisiciÃ³n oficial 24/7 | [t.me/MoviVIP](https://t.me/MoviVIP) |
| âœ‰ï¸ **Email Corporativo** | Consultas y facturaciÃ³n | [vipnetworkmovi@gmail.com](mailto:vipnetworkmovi@gmail.com) |
| ðŸŒ **Sitio Web Oficial** | Portal de informaciÃ³n | [movivip-network.web.app](https://movivip-network.web.app/) |

---

## ðŸ“¦ Archivos del Repositorio

| Archivo | Arquitectura | TamaÃ±o | DescripciÃ³n |
|:---|:---:|:---:|:---|
| `setup-amd64.sh` | x86_64 | ~22.9 MB | Instalador completo para Intel / AMD |
| `setup-arm64.sh` | ARM64 | ~22.5 MB | Instalador completo para ARM64 / aarch64 |
| `install-auto.sh` | Universal | ~2 KB | Auto-detector de arquitectura + launcher |
| `VERSION` | â€” | â€” | VersiÃ³n actual del instalador |
| `assets/logo.png` | â€” | â€” | Logo oficial MoviVIP Network |

---

## ðŸ“ž Soporte

<div align="center">

| Canal | DescripciÃ³n | Enlace |
|:---|:---|:---:|
| ðŸ›¡ï¸ **Soporte Oficial** | Licencias Â· Soporte tÃ©cnico Â· MigraciÃ³n HWID | [**@MoviVIP**](https://t.me/MoviVIP) |
| ðŸ“¢ **Canal Principal** | Releases Â· Hashes SHA256 Â· Anuncios | [**@MoviVIPNetwork**](https://t.me/MoviVIPNetwork) |
| ðŸ‘¥ **Grupo Comunitario** | Comunidad de administradores y usuarios | [**@MoviVIPNet**](https://t.me/MoviVIPNet) |
| ðŸŒ **Sitio Web** | Portal oficial MoviVIP Network | [movivip-network.web.app](https://movivip-network.web.app/) |
| âœ‰ï¸ **Email** | Consultas corporativas y facturaciÃ³n | [vipnetworkmovi@gmail.com](mailto:vipnetworkmovi@gmail.com) |

<br/>

### ðŸ¤ Comunidad Aliada

[ðŸ“¢ Canal FreeNetZone](https://t.me/FreeNetZonevip) &nbsp;Â·&nbsp; [ðŸ‘¥ Grupo FreeNetZone](https://t.me/FreeNetZonevips)

</div>

---

## ðŸ“„ Licencia

La **documentaciÃ³n pÃºblica** de este repositorio *(README, scripts de ejemplo, configuraciones de referencia)* se distribuye bajo **CC0-1.0 â€” Dominio PÃºblico**.

```
CC0 1.0 Universal â€” Public Domain Dedication
https://creativecommons.org/publicdomain/zero/1.0/
```

> **âš ï¸ Importante**: CC0-1.0 aplica **Ãºnicamente** a los archivos de documentaciÃ³n de este repositorio pÃºblico.
> El **software propietario MoviVIP Network Setup** *(binarios, payloads, validadores, esquemas criptogrÃ¡ficos)*
> **NO estÃ¡ cubierto por CC0** y permanece como software propietario con todos los derechos reservados.

---

<div align="center">

<br/>

<img src="assets/logo.png" alt="MoviVIP Network" width="140"/>

<br/>

**MoviVIP Network** â€” *Tu Mundo Digital en Buenas Manos*

```
Â© 2024â€“2025 MoviVIP Network Â· Todos los derechos reservados
VPS Â· Servers Â· VPN Â· IngenierÃ­a de Sistemas
```

Soporte 24/7: [**@MoviVIP**](https://t.me/MoviVIP) Â· Canal oficial: [**@MoviVIPNetwork**](https://t.me/MoviVIPNetwork)

*Si este proyecto te fue Ãºtil, considera dejar una â­ en el repositorio.*

</div>

