# MoviVIP Network - Multi Script Premium

<p align="center">
  <img src="https://img.shields.io/badge/Ubuntu-22.04%20%7C%2024.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white">
  <img src="https://img.shields.io/badge/Bash-Script-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white">
  <img src="https://img.shields.io/github/stars/studioanime977/MoviVIPNetwork?style=for-the-badge">
  <img src="https://img.shields.io/github/forks/studioanime977/MoviVIPNetwork?style=for-the-badge">
  <img src="https://img.shields.io/github/license/studioanime977/MoviVIPNetwork?style=for-the-badge">
</p>

<p align="center">
Administrador completo para VPS Ubuntu con instalacion automatica de protocolos VPN, herramientas y servicios desde un unico panel.
</p>

---

## Caracteristicas

- Instalacion automatica
- OpenSSH
- System DNS
- WebSocket
- ZIPVPN
- Dropbear
- SSL/TLS
- BadVPN
- UDP Custom
- V2Ray / Xray
- Firewall
- Speedtest
- Archivo Online
- Block Torrent
- Block Ads
- Reinicio de servicios
- Gestion de usuarios
- Cambio de contrasena Root
- Informacion del VPS
- Fail2ban (proteccion SSH / brute force)
- Auditoria de seguridad (rkhunter + chkrootkit + lynis)
- Consumo de red en tiempo real (base de datos automatica)

---

## Compatibilidad

- Ubuntu 22.04 LTS
- Ubuntu 24.04 LTS
- Arquitectura x86_64 / AMD64

---

## Instalacion

### Paso 1: Actualizar e instalar curl

Ejecuta el siguiente comando para actualizar la lista de paquetes e instalar curl:

```bash
apt update && apt install -y curl
```

### Paso 2: Ejecutar el script de instalacion nuevamente

Una vez finalizada la instalacion de curl, vuelve a ejecutar el comando original del script:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/install.sh)
```

---

## Acceder al Script

Una vez finalizada la instalacion, ejecuta:

```bash
menu
```

---

## Protocolos Disponibles

| Protocolo | Estado |
|-----------|:------:|
| OpenSSH | Disponible |
| System DNS | Disponible |
| WebSocket | Disponible |
| ZIPVPN | Disponible |
| Dropbear | Disponible |
| SSL/TLS | Disponible |
| BadVPN | Disponible |
| UDP Custom | Disponible |
| V2Ray / Xray | Disponible |
| SlowDNS | En desarrollo |

---

## Herramientas

- Firewall
- Speedtest
- Archivo Online
- Block Torrent
- Block Ads
- Reiniciar Servicios
- Informacion del VPS
- Cambiar contrasena Root
- Fail2ban: ver IPs baneadas, desbanear, whitelist
- Auditoria: escaneo completo de rootkits + hardening
- Consumo de Red: velocidad en tiempo real + acumulado + limites configurables

---

## Seguridad

El instalador configura automaticamente:

- **Fail2ban**: protege SSH y Dropbear contra ataques de fuerza bruta (3 intentos fallidos = baneo 1h, recidiva = 1 semana)
- **rkhunter**: detecta rootkits y binarios alterados
- **chkrootkit**: detecta rootkits conocidos
- **lynis**: auditoria de hardening con indice de seguridad
- **Monitoreo de consumo**: snapshot automatico cada minuto (cron + systemd), base de datos en `/etc/movivip/sistema/network_state.conf`

Los limites de consumo se configuran desde el menu:
`Herramientas → [10] Consumo de Red → [3] Configurar limites (GB)`

---

## Actualizar

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/update.sh)
```

---

## Solucion de errores

Si algun modulo muestra un error similar a:

```text
warning: here-document delimited by end-of-file (wanted `EOF`)
syntax error: unexpected end of file
```

Ejecuta:

```bash
sed -i 's/[[:space:]]*$//' /etc/movivip/protocolos/ssl.sh
bash -n /etc/movivip/protocolos/ssl.sh
```

Si el problema ocurre en otro modulo, reemplaza `ssl.sh` por el nombre correspondiente, por ejemplo:

```bash
sed -i 's/[[:space:]]*$//' /etc/movivip/protocolos/v2ray.sh
bash -n /etc/movivip/protocolos/v2ray.sh
```

Si `bash -n` no muestra ningun mensaje, el script no tiene errores de sintaxis.

---

## Soporte

- **Canal Telegram**: https://t.me/MoviVIPNetwork
- **Grupo Telegram**: https://t.me/MoviVIPNet
- **Web**: https://movivip-network.web.app/
- **Contacto**: @MoviVIP

---

<p align="center">
Hecho con dedicacion para la comunidad MoviVIP Network
</p>
