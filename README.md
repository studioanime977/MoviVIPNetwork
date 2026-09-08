# MoviVIP Network

Panel de gestión y túneles VPN para Ubuntu 22.04 / 24.04.

## Instalación

```bash
# 1) Descargar el instalador desde la última release
curl -L -o install.sh https://github.com/studioanime977/MoviVIPNetwork/releases/latest/download/install.sh

# 2) (Recomendado) Verificar integridad
curl -L -o install.sh.sha256 https://github.com/studioanime977/MoviVIPNetwork/releases/latest/download/install.sh.sha256
sha256sum -c install.sh.sha256

# 3) Instalar
bash install.sh
```

## Actualizar

```bash
bash install.sh --update
```

## Verificar

```bash
bash install.sh --verify
```

## ¿De dónde salen los archivos?

- El instalador `install.sh` (con el código completo integrado y protegido) se publica en cada **GitHub Release**.
- Este repositorio solo contiene los **actualizadores** que descargan y verifican la última release:
  - `update.sh` — actualización manual
  - `auto-update.sh` — actualización automática (cron)
  - `updater.sh` — actualizador interno

## Repositorios

- **Store / Web:** movivip-network.web.app
- **Canal:** @MoviVIPNetwork