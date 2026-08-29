# DEPLOY v5.2 — Flechitas TOTAL + Footer + Ofuscación segura — 21/Ago/2026

## VPS
- **IP**: [REDACTADO] — hostname `p.movivipoppax.uk`
- Acceso: por SSH con clave propia (credenciales NUNCA en el repo)
- Panel: `/etc/movivip/` · Backup pre-ofuscado: `/etc/movivip/.pack-backup` (sincronizado con v5.2)

## Estado FINAL (verificado en producción)
**Suite v5.3: 12 OK · 0 FAIL** — patrones inequívocos (`➤` selector nav_pick + `WhatsApp` footer):
openssh, systemdns, badvpn, udpcustom, dropbear, checkuser, ssl, slowdns, hysteria, v2ray, zipvpn, usuarios/menu.sh

## Desplegado al VPS (v5.1 + v5.2)
| Archivo | Cambio |
|---|---|
| `lib/nav.sh` | NUEVO — motor `nav_pick` (UI→stderr, resultado→stdout) + `movivip_footer` |
| `menu.sh` | Flechitas principal + [18] Soporte + salida con contactos |
| `protocolos/menu.sh` | Flechitas + footer + estados en vivo |
| `herramientas/menu.sh` | Flechitas + footer + [12]→usuarios/online.sh (monitor.sh eliminado) |
| `protocolos/{11}.sh` | **v5.2**: read→nav_pick (LBL+SEL), footer, source inline lib/nav.sh |
| `usuarios/menu.sh` | **v5.2**: ídem |
| `tools/ofuscar.sh` | Packer gzip+base64 (MARKER MOVIVIP-PACKED) + stub SIN `exit $?` |
| `updater.sh`, `auto-update.sh` | chmod incluye lib/*.sh |

## Ofuscación (estado final)
- Scripts empaquetados: los originales + los 12 v5.2 → todos con STUB SEGURO
- Stub termina sin `exit $?` (crítico: archivos que hacen `source` no matan al padre)
- Backup `.pack-backup` contiene las versiones PLAIN v5.2 de los 12 (fresco)
- Restaurar: `bash /etc/movivip/tools/ofuscar.sh --unpack`

## ⚠️ INCIDENTE RESUELTO (lección crítica)
El `--unpack` restauró backups v5.1 **pisando los 12 archivos v5.2** instalados después del primer pack.
Los tests daban falsos OK porque los patrones coincidían con el MENÚ IMPRINTO v5.1, no con el selector.
**Reglas aprendidas**:
1. Tras instalar versiones nuevas, PURGAR sus entradas obsoletas en `.pack-backup` antes de re-pack
2. Testear solo con patrones inequívocos del RUNTIME: `➤` (selector) y `WhatsApp` (footer)
3. Nunca confiar en grep de textos que también existen en menús impresos viejos

## Procedimiento de actualización (para futuros cambios)
```bash
# En VPS tras copiar archivos nuevos a sus destinos:
bash /etc/movivip/tools/ofuscar.sh /etc/movivip   # re-pack (salta ya-empaquetados por MARKER)
```
Si el archivo nuevo reemplaza a uno YA EMPAQUETADO viejo: borrar su entrada en
`.pack-backup` ANTES de instalar, para que ofuscar cree backup fresco.

## Lecciones técnicas
- Windows: escapar `$` vía PowerShell→ssh se rompe; subir script por scp y ejecutarlo
- PowerShell parsea `<` en comandos ssh → siempre script-file vía scp
- sshpass disponible en scoop para auth por contraseña
- Dashboard principal tarda ~12s (4× ss timeout 3): timeout ≥35 en tests del main menu
- Suite completa (~200s) excede límite tool (120s): lanzar con nohup background + poll
- Banner HTML del login SSH contamina toda salida → filtrar con grep de patrones propios
- nav_pick: UI por STDERR, resultado por STDOUT → seguro bajo `$()`

---

# DEPLOY v5.4 — Rediseño MoviVIP — 21/Ago/2026

## Objetivo (petición del usuario)
1. Contactos integrados ARRIBA (header), no footer abajo
2. Eliminar menú duplicado (catálogo impreso + selector dinámico)
3. Feedback visible al digitar números (buffer `[N]` en la línea de prompt)
4. Lista `[NN] ➮ Nombre` con cursor `➤` resaltando la línea activa

## Cambios (16 archivos)
| Archivo | Cambio |
|---|---|
| `lib/nav.sh` | `nav_pick` REESCRITO estilo MoviVIP: auto-numera `[01]➮`, último item `↩/Salir`→`[00]`, activo invertido cyan con `➤`, buffer tecleado `${BUF:+[BUF] }`, backspace, ancla `\033[s`; + `movivip_contacts()` + `movivip_sub_header "TITULO"` (separador+título+contactos+separador); footer SOLO pantallas de salida |
| `menu.sh` | Header con contactos inline (padding W-52/W-55); MENÚ estático [01]-[99] eliminado |
| `protocolos/menu.sh` | Catálogo numerado eliminado; estados ● compactos no-numerados; sub_header |
| `herramientas/menu.sh` | Box estático eliminado → sub_header + nav_pick |
| `usuarios/menu.sh` | Box estático eliminado → sub_header + RAM/CPU + nav_pick |
| `protocolos/{12}.sh` | Patrón unificado: `source lib/nav.sh` antes del while, `movivip_sub_header "EMOJI TITULO"` dentro del loop, cat EOF estático fuera, footer fuera, estados conservados |
| `protocolos/hysteria.sh` | + submenú interno `reconfigure_auth` convertido a nav_pick (read plano eliminado) |

## Verificación
- `bash -n`: 16/16 OK (en staging `/tmp/mv54` ANTES de instalar)
- Suite v5.4: **46 PASS · 0 FAIL** — por menú: `➤` presente, `[01]` presente, contactos presentes; global: cero `\[[0-9]\] ➮` single-digit residual
- Re-pack: 15 scripts ofuscados · `.pack-backup` purgado y regenerado (9 backups frescos)
- Scripts: `tools/vps-deploy-v54.sh`, `tools/vps-finish-v54.sh`, `tools/vps-test-v54.sh`

## Notas del deploy
- Primer intento abortó en verificación: check exigía sub_header en menu.sh principal (usa contactos INLINE) y detectó menú interno de hysteria → corregidos ambos
- Instalación es idempotente: los pasos 2-4 ya aplicados se mantuvieron; finish solo re-instaló hysteria + re-pack


## v5.5 — Dashboard unificado + menú 2 columnas (2026-08-21)

### Cambios
| Archivo | Cambio |
|---------|--------|
| `lib/nav.sh` | `nav_pick` con **2 columnas automáticas** (>9 items): izquierda 1..ROWS, derecha ROWS+1..N; item activo = barra `\e[1;30;106m` rellenada a COLW=34; teclas ←→ saltan ROWS; último item siempre `[00]` |
| `menu.sh` | Dashboard **sin box ╔═╗** → separadores ─── estilo selector (unificación visual, cero desbordes); marca centrada `🛡️ MoviVIP Network v5.0 🛡️` (doble escudo); PROTOCOLOS en 2 columnas **con puertos restaurados** ([22], [UDP 5667], [53/5300], [443], [7200,7300], [2100], Hysteria dinámico); subtítulo sin duplicar |
| `protocolos/menu.sh` | Estados en 2 columnas con helper `row2` + puertos completos |

### Bug clave encontrado
`local i=$1 LBL="${L[i-1]}"` en UNA línea → bash expande `${L[i-1]}` con `i` aún indefinida → índice `-1` = SIEMPRE el último elemento del array. Fix: separar `local i=$1` en su propia línea. Además los printf de `_np_item` deben ir `>&2` (nav_pick corre bajo `$()`).

### Verificación
- `bash -n`: 3/3 OK
- Suite: **46 PASS · 0 FAIL** (15 menús × selector/[01]/contactos)
- Deploy: `tools/vps-deploy-v55.sh` · purga `.pack-backup` de menu.sh y protocolos/menu.sh · nav.sh plano
- Re-pack: 2 scripts ofuscados, 198 omitidos


## v5.6 — Premium visual + puertos en selector + dominios No-IP/CloudFront (2026-08-21)

### Cambios
| Archivo | Cambio |
|---------|--------|
| `lib/nav.sh` | Reescrito limpio (UTF-8): hints de teclas bajo el prompt (`↑↓ mover · ←→ columna · números directos · ENTER elegir`), motor 2-columnas intacto |
| `protocolos/menu.sh` | **Puertos EN los items del selector**: `[01] ➮ ● 🔐 OpenSSH [22]` — estado ● + nombre + puerto integrado; eliminada tabla row2 duplicada |
| `menu.sh` | Dashboard premium: separadores jerárquicos (`═══` cyan arriba/abajo + `───` gris secciones), títulos `◆ 💻 SISTEMA / 🌐 RED / ⚙️ PROTOCOLOS / 🛡️ SEGURIDAD`, barra RAM/CPU dinámica (verde<60 · dorado<85 · rojo≥85), uptime compacto `22h10m`, fecha con segundos, badge `🟢 N online`, subtítulo sin duplicar |

### Dominios en sección RED (desde config.conf)
```
🏠 p.movivipoppax.uk · 🌍 freenetzone.servegame.com · ☁️ cloudfront...
```
- `SERVER_DOMAIN` siempre · `NOIP_DOMAIN` si definido · `CLOUDFRONT_DOMAIN` si definido

### Lección crítica
Parchear UTF-8 con `-replace` de PowerShell corrompe emojis/acentos y añade BOM → REESCRIBIR archivos completos con herramienta write, nunca regex-replace sobre contenido no-ASCII.

### Verificación
- Suite: **46 PASS · 0 FAIL** · deploy vps-deploy-v55.sh reutilizado · re-pack 2 scripts

