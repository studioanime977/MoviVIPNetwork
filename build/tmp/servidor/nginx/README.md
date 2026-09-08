# MoviVIP — Nginx (Mini App de Telegram)

Configuración de **nginx** para la mini app de Telegram (panel web del bot
`@MovivipKeygen_bot`).

## Cadena de tráfico

```
Cliente (Telegram Mini App)
   │  https://bot.movivipoppax.uk
   ▼
HAProxy  :443   (bind *:443 — ACL por SNI bot.movivipoppax.uk)
   │  backend botweb / botweb_passthru  ->  127.0.0.1:4432
   ▼
nginx 127.0.0.1:4432  (SSL, server_name bot.movivipoppax.uk)
   │  proxy_pass
   ▼
Backend python 127.0.0.1:5081  (movivip-sshbot.service — lanza la mini app)
```

## Archivos

| Archivo | Ruta en servidor | Descripción |
|---------|------------------|-------------|
| `sites-available/movivip-miniapp` | `/etc/nginx/sites-available/movivip-miniapp` | **Config CORRECTA** (única). Define el server en `127.0.0.1:4432` → proxy a `5081`. |
| `sites-available/movivip-miniapp` (symlink) | `/etc/nginx/sites-enabled/movivip-miniapp` | Enlace activo a la config correcta. |
| `conf.d/botweb.conf.bak_dup` | `/etc/nginx/conf.d/botweb.conf.bak_dup` | **Respaldo del problema**: config duplicada que causaba conflicto. NO reactivar. |
| `fix-miniapp-nginx.sh` | — | Script replicable para aplicar/verificar el fix. |

## Problema corregido (2026-09-02)

**Síntoma:** `nginx.service` quedaba en `failed` y la mini app se caía.

**Causa raíz:** existían **dos configs que definían el mismo `server`** en el
puerto `127.0.0.1:4432` con el mismo `server_name`:

1. `sites-enabled/movivip-miniapp` (correcta, creada 2026-08-31 20:00)
2. `conf.d/botweb.conf` (duplicada, creada 2026-09-01 19:30 — cuando se tocó xray)

El duplicado generaba:
```
nginx: conflicting server name "bot.movivipoppax.uk" on 127.0.0.1:4432, ignored
nginx: bind() to 127.0.0.1:4432 failed (98: Address already in use)
```
Al reiniciar nginx no podía `bind()` el puerto (ocupado por procesos heredados)
→ el servicio quedaba en `failed`, y la mini app solo funcionaba por procesos
nginx zombies desde Aug 31 (frágil: se caía si morían).

**Solución aplicada:**
1. `mv /etc/nginx/conf.d/botweb.conf /etc/nginx/conf.d/botweb.conf.bak_dup`
2. Detener procesos nginx heredados (liberar puerto 4432)
3. `nginx -t` → OK
4. `systemctl enable --now nginx` → **active** (bajo systemd, robusto ante reboot)
5. Verificar: `/miniapp` responde **HTTP 200**

## Cómo replicar el fix

```bash
bash servidor/nginx/fix-miniapp-nginx.sh
```

O manualmente:
```bash
# 1. Respaldar el duplicado (si existe)
[ -f /etc/nginx/conf.d/botweb.conf ] && \
  mv /etc/nginx/conf.d/botweb.conf /etc/nginx/conf.d/botweb.conf.bak_dup

# 2. Asegurar la config correcta activa
ln -sf /etc/nginx/sites-available/movivip-miniapp /etc/nginx/sites-enabled/movivip-miniapp

# 3. Detener procesos heredados y arrancar limpio
systemctl stop nginx 2>/dev/null; pkill -9 nginx 2>/dev/null; sleep 1
nginx -t && systemctl enable --now nginx

# 4. Verificar
curl -sk --resolve bot.movivipoppax.uk:443:127.0.0.1 \
  https://bot.movivipoppax.uk/miniapp -o /dev/null -w '%{http_code}\n'
# Esperado: 200
```

## Notas

- La mini app (endpoint `/miniapp`) corre en el backend `movivip-sshbot.service`
  (puerto `5081`), NO en nginx directamente.
- El certificado SSL de nginx se renueva con certbot:
  `--webroot` / `--nginx` con el dominio `bot-movivipoppax.uk`.
- **Regla de oro:** nunca definir dos `server` en el mismo IP:puerto con el
  mismo `server_name`. La config correcta vive en `sites-available/`, no en `conf.d/`.
