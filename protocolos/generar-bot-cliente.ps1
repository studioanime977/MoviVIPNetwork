# =============================================================================
# GENERADOR DE BOT ADMIN POR CLIENTE — MoviVIP License System
# Produce un paquete GENÉRICO listo para el VPS del cliente: toda la
# configuracion (tokens, VPS, dominios, branding) se centraliza en config.py
# que el cliente edita con SUS datos. El generador solo inyecta marca y
# limites del plan contratado (basico/premium/platino/vitalicio).
#
# ⚠️ ESTE ARCHIVO VIVE EN EL REPO PUBLICO (protocolos/). NO contiene
#    credenciales reales por defecto — pasalas por parametro en cada uso.
#
# USO (vendedor):
#   .\generar-bot-cliente.ps1 -Cliente "netfast" -AdminToken "123:ABC" `
#       -VpsHost "1.2.3.4" -VpsPass "rootpass" -VpsSubdominio "netfast.servegame.com" `
#       -DominioMain "netfast.uk" `
#       -XrayPubKey "..." -XrayShortId "..." -XraySni "www.microsoft.com" `
#       -AdminIds "123456789,987654321" -Plan "premium"
#
# SALIDA: .\entregas\<cliente>\ (relativo a la carpeta protocolos)
# =============================================================================

param(
    [Parameter(Mandatory = $true)][string]$Cliente,
    [string]$AdminToken = "",
    [string]$NotifToken = "",
    [string]$NotifChannelId = "***REMOVED_CHANNEL_ID***",
    [string]$NotifGroupId = "***REMOVED_GROUP_ID***",
    [string]$VpsHost = "IP_DEL_VPS",
    [string]$VpsPass = "PASS_ROOT_DEL_VPS",
    [string]$VpsSubdominio = "vps.cliente.uk",
    [string]$DominioMain = "cliente.uk",
    [string]$XrayPubKey = "",
    [string]$XrayShortId = "",
    [string]$XraySni = "www.microsoft.com",
    [string]$AdminIds = "TU_ID_TELEGRAM",
    [ValidateSet("basico", "premium", "platino", "vitalicio")][string]$Plan = "basico"
)

$ErrorActionPreference = "Stop"

# Ruta del extract: primero la copia local del vendedor con los datos REALES
# (fuera del repo público), luego la plantilla pública sanitizada del repo.
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$extract = "C:\Users\ADMIN\AppData\Local\Temp\opencode\bots_extract"
if (-not (Test-Path $extract)) {
    $extract = Join-Path $scriptDir "bots_extract"
    if (-not (Test-Path $extract)) {
        throw "No existe el extract de plantillas en la ruta local del vendedor ni en $scriptDir\bots_extract."
    }
}
$outRoot = Join-Path $scriptDir "entregas"
$outDir = Join-Path $outRoot $Cliente

# =============================================================================
# REGLA COMERCIAL: el BOT solo se entrega en planes PREMIUM/PLATINO/VITALICIO.
# El plan BASICO (bronce) recibe SOLO el script multi-protocolo (scrip vps todo).
# =============================================================================
if ($Plan -eq "basico") {    Write-Host ""
    Write-Host "  ==================================================" -ForegroundColor Red
    Write-Host "   PLAN BASICO (BRONCE) = SOLO MULTI-SCRIPT" -ForegroundColor Red
    Write-Host "  ==================================================" -ForegroundColor Red
    Write-Host "   El bot admin/user es EXCLUSIVO de planes:" -ForegroundColor Yellow
    Write-Host "     - PREMIUM   (15 dias, 5 dispositivos)" -ForegroundColor Yellow
    Write-Host "     - PLATINO   (30 dias, 10 dispositivos)" -ForegroundColor Yellow
    Write-Host "     - VITALICIO (de por vida, 10 dispositivos)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   Para BRONCE entrega el script multi-protocolo de:" -ForegroundColor Green
    Write-Host "     C:\Users\ADMIN\Desktop\vps\scrip vps todo" -ForegroundColor Green
    Write-Host "   (MoviVIP Network - todos los protocolos VPN)" -ForegroundColor Green
    Write-Host "  ==================================================" -ForegroundColor Red
    Write-Host ""
    throw "Plan BASICO no genera bot. El bronce es solo el script multi-protocolo."
}

# =============================================================================
# PLAN LIMITS
# =============================================================================
$planLimits = @{
    basico    = @{ max_devices = 2;  allow_v2ray = $false; max_days = 7;  label = "BASICO" }
    premium   = @{ max_devices = 5;  allow_v2ray = $true;  max_days = 15; label = "PREMIUM" }
    platino   = @{ max_devices = 10; allow_v2ray = $true;  max_days = 30; label = "PLATINO" }
    vitalicio = @{ max_devices = 10; allow_v2ray = $true;  max_days = 30; label = "VITALICIO" }
}
$lim = $planLimits[$Plan]
$maxDev = $lim.max_devices
$allowV2ray = if ($lim.allow_v2ray) { "True" } else { "False" }

# =============================================================================
# HELPERS
# =============================================================================
function Esc-Py([string]$s) {
    # Escapar valor para insertarlo como string literal Python
    return $s.Replace('\', '\\').Replace('"', '\"').Replace("`n", '\n').Replace("`r", '\r')
}
function Write-Utf8NoBom([string]$path, [string]$content) {
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
}
function Replace-Ordinal([string]$content, [string]$old, [string]$new) {
    if ($old -eq "") { return $content }
    return $content.Replace($old, $new)
}

# --- Branding común aplicable a cualquier contenido (orden: específico -> genérico)
#     Usa $clienteLo/$escSub/$escMain/$Cliente (se resuelven en tiempo de llamada)
function Apply-Branding([string]$content) {
    $c = $content
    $c = Replace-Ordinal $c "@MoviVIPUSERVPS_bot" "@${clienteLo}_bot"
    $c = Replace-Ordinal $c "@MOVIVIPNETWORK_SSH_BOT" "@${clienteLo}_ssh_bot"
    $c = Replace-Ordinal $c "https://t.me/MoviVIPNetwork" "https://t.me/${clienteLo}_network"
    $c = Replace-Ordinal $c "https://t.me/MoviVIPNet" "https://t.me/${clienteLo}_grupo"
    $c = Replace-Ordinal $c "https://t.me/MoviVIP" "https://t.me/$clienteLo"
    $c = Replace-Ordinal $c "@MoviVip_Network" "@${clienteLo}_network"
    $c = Replace-Ordinal $c "@MoviVIPNetwork" "@${clienteLo}_network"
    $c = Replace-Ordinal $c "@MoviVIPNet" "@${clienteLo}_grupo"
    $c = Replace-Ordinal $c "@MoviVIP" "@$clienteLo"
    $c = Replace-Ordinal $c "https://movivip-network.web.app/panel" "https://$escSub/panel"
    $c = Replace-Ordinal $c "https://movivip-network.web.app" "https://$escSub"
    $c = Replace-Ordinal $c "MoviVIP Network" "$Cliente Network"
    $c = Replace-Ordinal $c "MOVIVIP NETWORK" "$($Cliente.ToUpper()) NETWORK"
    $c = Replace-Ordinal $c "MOVIVIPNETWORK" "$($Cliente.ToUpper())NETWORK"
    $c = Replace-Ordinal $c "MoviVIP - " "$Cliente - "
    $c = Replace-Ordinal $c "MoviVIP SSH - " "$Cliente SSH - "
    # Residuales de marca: botones, remarks V2Ray, brand en DB, rutas
    $c = Replace-Ordinal $c "Canal MoviVIP" "Canal $Cliente"
    $c = Replace-Ordinal $c "Grupo MoviVIP" "Grupo $Cliente"
    $c = Replace-Ordinal $c "TUTORIALES MoviVIP" "TUTORIALES $Cliente"
    $c = Replace-Ordinal $c 'remark="MoviVIP"' "remark=`"$Cliente`""
    $c = Replace-Ordinal $c 'remark = "MoviVIP"' "remark = `"$Cliente`""
    $c = Replace-Ordinal $c "[movivip-network.web.app]" "[$escMain]"
    $c = Replace-Ordinal $c "brand='movivip'" "brand='$clienteLo'"
    $c = Replace-Ordinal $c "DEFAULT 'movivip'" "DEFAULT '$clienteLo'"
    $c = Replace-Ordinal $c '(brand_key or "movivip")' "(brand_key or `"$clienteLo`")"
    $c = Replace-Ordinal $c 'f"movivip-{username}"' "f`"$clienteLo-{username}`""
    $c = Replace-Ordinal $c 'f"movi_{user_id}_{suffix}"' "f`"$clienteLo_{user_id}_{suffix}`""
    $c = Replace-Ordinal $c "port, operator, 'movivip')" "port, operator, '$clienteLo')"
    $c = Replace-Ordinal $c "1, 'movivip', 'admin_bypass', ?)" "1, '$clienteLo', 'admin_bypass', ?)"
    $c = Replace-Ordinal $c 'DB_PATH = "/root/movivip.db"' "DB_PATH = `"/root/$clienteLo.db`""
    return $c
}

# =============================================================================
# VALIDACIONES — no permitir generar con placeholders del repo público
# =============================================================================
if ($VpsHost -like "*IP_DEL_VPS*" -or $VpsPass -like "*PASS_ROOT*" -or $AdminIds -like "*TU_ID*") {
    Write-Host ""
    Write-Host "  ==================================================" -ForegroundColor Red
    Write-Host "   FALTAN DATOS REALES DEL VPS/CLIENTE" -ForegroundColor Red
    Write-Host "  ==================================================" -ForegroundColor Red
    Write-Host "   Pasa por parametro: -VpsHost IP -VpsPass PASS -AdminIds ID" -ForegroundColor Yellow
    Write-Host "   (el repo publico no guarda credenciales por defecto)" -ForegroundColor Yellow
    Write-Host "  ==================================================" -ForegroundColor Red
    throw "Datos placeholder detectados. Proporciona credenciales reales."
}

# =============================================================================
# VALIDACIONES
# =============================================================================
if (-not (Test-Path $extract)) { throw "No existe el extract de plantillas: $extract" }
if (Test-Path $outDir) { Write-Host "AVISO: $outDir ya existe, se sobreescribira." -ForegroundColor Yellow }
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

# Limpieza de archivos obsoletos: elimina cualquier .py del paquete que ya no
# forme parte de la entrega (ej: ssh_banner_gen.py, gen_banners.py, global_bot.py) para que al
# regenerar nunca queden restos de versiones anteriores.
$paqueteActual = @("admin_bot.py","config.py","database.py","ssh_utils.py","notif_bot.py")
Get-ChildItem -Path $outDir -Filter "*.py" -File | Where-Object { $paqueteActual -notcontains $_.Name } | ForEach-Object {
    Remove-Item $_.FullName -Force
    Write-Host "  limpiado: $($_.Name)" -ForegroundColor DarkYellow
}

$escHost   = Esc-Py $VpsHost
$escPass   = Esc-Py $VpsPass
$escSub    = Esc-Py $VpsSubdominio
$escMain   = Esc-Py $DominioMain
$escPub    = Esc-Py $XrayPubKey
$escShort  = Esc-Py $XrayShortId
$escSni    = Esc-Py $XraySni
$escToken  = Esc-Py $AdminToken
# Token del bot de notificaciones: si no se pasa, aviso claro de que no puede
# compartir token con el admin (conflicto de getUpdates al correr juntos).
$escNotif  = Esc-Py $(if ($NotifToken) { $NotifToken } else { $AdminToken })
if (-not $NotifToken) {
    Write-Host "  AVISO: -NotifToken vacio — notif_bot.py usara el token del admin." -ForegroundColor Yellow
    Write-Host "         Si admin_bot y notif_bot corren juntos, usa un bot DISTINTO." -ForegroundColor Yellow
}
$clienteLo = $Cliente.ToLower()

Write-Host ""
Write-Host "  ==================================================" -ForegroundColor Cyan
Write-Host "   GENERANDO BOT PARA CLIENTE: $($Cliente.ToUpper())" -ForegroundColor Cyan
Write-Host "   Plan: $($lim.label) | Max dispositivos: $maxDev | V2Ray: $allowV2ray" -ForegroundColor Cyan
Write-Host "  ==================================================" -ForegroundColor Cyan

# =============================================================================
# 1) ADMIN BOT (plantilla klepernet -> admin_bot.py)
#    NOTA: tokens/VPS/Xray ahora vienen de config.py (unica fuente).
#    Aqui solo se aplican reemplazos de dominios y branding.
# =============================================================================
Write-Host "[1/6] admin_bot.py ..." -NoNewline
$admin = [System.IO.File]::ReadAllText((Join-Path $extract "admin_bot_klepernet.py"))

# Log path (usa BRAND_NAME dinamico desde config)
$admin = Replace-Ordinal $admin '/var/log/movivip_klepernet.log' "/var/log/movivip_$clienteLo.log"

# Reemplazos globales de dominios (plantilla real del vendedor)
$admin = Replace-Ordinal $admin "movisvip.servegame.com" $escSub
$admin = Replace-Ordinal $admin "movivipoppax.uk" $escMain
# Reemplazos de placeholders (plantilla publica sanitizada del repo)
$admin = Replace-Ordinal $admin "PONER_SUBDOMINIO_AQUI" $escSub
$admin = Replace-Ordinal $admin "PONER_DOMINIO_AQUI" $escMain

# Reemplazos globales de branding (marca del cliente)
$admin = Replace-Ordinal $admin "KLEPERNET" $Cliente.ToUpper()
$admin = Replace-Ordinal $admin "KleperNet" $Cliente
$admin = Replace-Ordinal $admin "klepernet" $clienteLo

# MAX_DEVICES segun plan — ya viene de config.py; solo se verifica que exista el bloque
# de PLAN LIMITS que filtra v2ray en OPERATORS segun el plan
$admin = Replace-Ordinal $admin 'MAX_DEVICES = 10' "MAX_DEVICES = $maxDev"

# Inyectar bloque de PLAN LIMITS despues del cierre del dict OPERATORS
$lines = $admin -split "`n"
$opIdx = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*OPERATORS = \{') { $opIdx = $i; break }
}
if ($opIdx -ge 0) {
    $closeIdx = -1
    for ($i = $opIdx + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -eq '}') { $closeIdx = $i; break }
    }
    if ($closeIdx -ge 0) {
        $planBlock = @"



# =============================================================================
# PLAN LIMITS - $($lim.label) (inyectado por generador - NO EDITAR)
# =============================================================================
def _apply_plan_limits():
    global OPERATORS, MAX_DEVICES
    MAX_DEVICES = $maxDev
    if ${allowV2ray}:
        # Plan con V2Ray habilitado
        pass
    else:
        # Plan sin V2Ray: filtrar connection_types v2ray de todos los operadores
        for _op in OPERATORS.values():
            _op["connection_types"] = [ct for ct in _op.get("connection_types", []) if ct.get("protocol") != "v2ray"]
        OPERATORS = {k: v for k, v in OPERATORS.items() if v.get("connection_types")}
_apply_plan_limits()
"@
        $before = ($lines[0..$closeIdx]) -join "`n"
        $after = ($lines[($closeIdx + 1)..($lines.Count - 1)]) -join "`n"
        $admin = $before + $planBlock + $after
    } else {
        Write-Host " AVISO: no se encontro cierre del dict OPERATORS, plan limits NO inyectado" -ForegroundColor Yellow
    }
} else {
    Write-Host " AVISO: no se encontro OPERATORS, plan limits NO inyectado" -ForegroundColor Yellow
}

Write-Utf8NoBom (Join-Path $outDir "admin_bot.py") $admin
Write-Host " OK" -ForegroundColor Green

# =============================================================================
# 2) CONFIG.PY — UNICA FUENTE DE CONFIGURACION DEL CLIENTE
# =============================================================================
Write-Host "[2/6] config.py ..." -NoNewline
$cfg = [System.IO.File]::ReadAllText((Join-Path $extract "config.py"))
$cfg = Replace-Ordinal $cfg 'ADMIN_BOT_TOKEN = "PONER_TOKEN_ADMIN_AQUI"' "ADMIN_BOT_TOKEN = `"$escToken`""
$cfg = Replace-Ordinal $cfg 'ADMIN_IDS = [0]' "ADMIN_IDS = [$(($AdminIds -split ',' | ForEach-Object { $_.Trim() }) -join ', ')]"
$cfg = Replace-Ordinal $cfg 'NOTIF_BOT_TOKEN = ""' "NOTIF_BOT_TOKEN = `"$escNotif`""
$cfg = Replace-Ordinal $cfg 'NOTIF_CHANNEL_ID = -1000000000000' "NOTIF_CHANNEL_ID = $NotifChannelId"
$cfg = Replace-Ordinal $cfg 'NOTIF_GROUP_ID = -1000000000001' "NOTIF_GROUP_ID = $NotifGroupId"
$cfg = Replace-Ordinal $cfg 'VPS_HOST = "127.0.0.1"' "VPS_HOST = `"$escHost`""
$cfg = Replace-Ordinal $cfg 'VPS_PASSWORD = "PONER_PASSWORD_VPS_AQUI"' "VPS_PASSWORD = `"$escPass`""
$cfg = Replace-Ordinal $cfg 'VPS_SUBDOMAIN = "PONER_SUBDOMINIO_AQUI"' "VPS_SUBDOMAIN = `"$escSub`""
$cfg = Replace-Ordinal $cfg 'DOMAIN_MAIN = "PONER_DOMINIO_AQUI"' "DOMAIN_MAIN = `"$escMain`""
$cfg = Replace-Ordinal $cfg 'MINIAPP_BASE_URL = "http://127.0.0.1:5000"' "MINIAPP_BASE_URL = `"http://${escHost}:5000`""
$cfg = Replace-Ordinal $cfg 'XRAY_VPS_IP = "127.0.0.1"' "XRAY_VPS_IP = `"$escHost`""
$cfg = Replace-Ordinal $cfg 'XRAY_VLESS_REALITY_PUBKEY = "PONER_PUBKEY_AQUI"' "XRAY_VLESS_REALITY_PUBKEY = `"$escPub`""
$cfg = Replace-Ordinal $cfg 'XRAY_VLESS_REALITY_SHORTID = "PONER_SHORTID_AQUI"' "XRAY_VLESS_REALITY_SHORTID = `"$escShort`""
$cfg = Replace-Ordinal $cfg 'XRAY_VLESS_REALITY_SNI = "www.microsoft.com"' "XRAY_VLESS_REALITY_SNI = `"$escSni`""
$cfg = Replace-Ordinal $cfg 'MAX_DEVICES = 10' "MAX_DEVICES = $maxDev"
$cfg = Replace-Ordinal $cfg 'MAX_DAYS_CREATE = 30' "MAX_DAYS_CREATE = $($lim.max_days)"

# Branding del cliente (antes se inyectaba en admin_bot/user_bot; ahora en config.py)$cfg = Replace-Ordinal $cfg 'BRAND_NAME = "MoviVIP Network"' "BRAND_NAME = `"$Cliente Network`""
$cfg = Replace-Ordinal $cfg 'MY_BRAND = "movivip"' "MY_BRAND = `"$clienteLo`""
$cfg = Replace-Ordinal $cfg 'BRAND_BOT = "@MoviVIPUSERVPS_bot"' "BRAND_BOT = `"@${clienteLo}_bot`""
$cfg = Replace-Ordinal $cfg 'BRAND_PREMIUM = "https://t.me/MoviVIP"' "BRAND_PREMIUM = `"https://t.me/$clienteLo`""
$cfg = Replace-Ordinal $cfg 'BRAND_SUPPORT = "https://t.me/MoviVIP"' "BRAND_SUPPORT = `"https://t.me/${clienteLo}_soporte`""
$cfg = Replace-Ordinal $cfg 'BRAND_CHANNEL = "https://t.me/MoviVIPNetwork"' "BRAND_CHANNEL = `"https://t.me/${clienteLo}_network`""
$cfg = Replace-Ordinal $cfg 'BRAND_GROUP = "https://t.me/MoviVIPNet"' "BRAND_GROUP = `"https://t.me/${clienteLo}_grupo`""
$cfg = Replace-Ordinal $cfg 'BRAND_STORE = "https://movivip-network.web.app/panel"' "BRAND_STORE = `"https://$escSub/panel`""
$cfg = Replace-Ordinal $cfg 'BRAND_MINIAPP = "https://movisvip.servegame.com:8448"' "BRAND_MINIAPP = `"https://${escSub}:8448`""
$cfg = Replace-Ordinal $cfg 'MAIN_CHANNEL = "@MoviVIPNetwork"' ("MAIN_CHANNEL = `"@$($clienteLo)_network`"")
$cfg = Replace-Ordinal $cfg 'SUPPORT_GROUP = "@MoviVIPSoporte"' ("SUPPORT_GROUP = `"@${clienteLo}_soporte`"")

# Dominios (CLOUDFLARE, SLOWDNS, VAYDNS, DNSTT usan DOMAIN_MAIN como f-string)
$cfg = Replace-Ordinal $cfg "movisvip.servegame.com" $escSub
$cfg = Replace-Ordinal $cfg "movivipoppax.uk" $escMain
$cfg = Replace-Ordinal $cfg "PONER_SUBDOMINIO_AQUI" $escSub
$cfg = Replace-Ordinal $cfg "PONER_DOMINIO_AQUI" $escMain

# PLANS segun plan (reemplazar dict PLANS completo)
$oldPlans = @"
PLANS = {
    3: {"days": 3, "price": "Gratis", "max_devices": 1},
    7: {"days": 7, "price": "Gratis", "max_devices": 3},
    15: {"days": 15, "price": "Gratis", "max_devices": 5},
    30: {"days": 30, "price": "Gratis", "max_devices": 10},
}
"@
$newPlans = @"
PLANS = {
    3: {"days": 3, "price": "Gratis", "max_devices": 1},
    7: {"days": 7, "price": "Gratis", "max_devices": $(if ($maxDev -ge 3) {3} else {1})},
    15: {"days": 15, "price": "Gratis", "max_devices": $(if ($maxDev -ge 5) {5} else {2})},
    30: {"days": 30, "price": "Gratis", "max_devices": $maxDev},
}
"@
$cfg = Replace-Ordinal $cfg $oldPlans $newPlans

# Branding residual en config.py (header, comentarios de tokens, DB_PATH)
$cfg = Apply-Branding $cfg

Write-Utf8NoBom (Join-Path $outDir "config.py") $cfg
Write-Host " OK" -ForegroundColor Green

# =============================================================================
# 3) SSH_UTILS.PY — libreria compartida (create_ssh_account / delete_ssh_on_vps)
#    Reemplaza a user_bot.py como dependencia del admin_bot (sin pagos).
# =============================================================================
Write-Host "[3/6] ssh_utils.py ..." -NoNewline
$su = [System.IO.File]::ReadAllText((Join-Path $extract "ssh_utils.py"))
# Dominios y branding residuales (por si la plantilla lleva marcas del vendedor)
$su = Replace-Ordinal $su "movisvip.servegame.com" $escSub
$su = Replace-Ordinal $su "movivipoppax.uk" $escMain
$su = Replace-Ordinal $su "PONER_SUBDOMINIO_AQUI" $escSub
$su = Replace-Ordinal $su "PONER_DOMINIO_AQUI" $escMain
$su = Apply-Branding $su
Write-Utf8NoBom (Join-Path $outDir "ssh_utils.py") $su
Write-Host " OK" -ForegroundColor Green

# =============================================================================
# 4) NOTIF_BOT.PY — bot de notificaciones a canal/grupo (token propio)
#    Toda su config (token, canal, grupo, ADMIN_IDS) sale de config.py.
# =============================================================================
Write-Host "[4/6] notif_bot.py ..." -NoNewline
$nb = [System.IO.File]::ReadAllText((Join-Path $extract "notif_bot.py"))
$nb = Replace-Ordinal $nb "movisvip.servegame.com" $escSub
$nb = Replace-Ordinal $nb "movivipoppax.uk" $escMain
$nb = Replace-Ordinal $nb "PONER_SUBDOMINIO_AQUI" $escSub
$nb = Replace-Ordinal $nb "PONER_DOMINIO_AQUI" $escMain
$nb = Apply-Branding $nb
Write-Utf8NoBom (Join-Path $outDir "notif_bot.py") $nb
Write-Host " OK" -ForegroundColor Green

# =============================================================================
# 5) DEPENDENCIAS ADICIONALES (con branding del cliente)
# =============================================================================
Write-Host "[5/6] dependencias ..." -NoNewline

# (gen_banners.py eliminado - el banner SSH lo maneja insinue.net de forma global)

# database.py — brands del cliente + dominio VPS
$db = [System.IO.File]::ReadAllText((Join-Path $extract "database.py"))
$newBrandsBlock = @"
INITIAL_BRANDS = [
    ("$clienteLo", "$Cliente Network", "https://$escSub/panel", "", "", "@${clienteLo}_network", "", "#FFD700", "#00BFFF", "Bienvenido a $Cliente Network - Tu VPN Premium", None, 1),
]
"@
$db = [regex]::Replace($db, 'INITIAL_BRANDS = \[.*?\n\]', $newBrandsBlock, 'Singleline')
# Dominios del cliente en los defaults de la DB (vps_domain, slowdns_ns, vaydns_ns, dnstt_ns, cf_domain, operadores)
$db = Replace-Ordinal $db '("vps_domain", "movisvip.servegame.com", "Dominio principal VPS")' "(""vps_domain"", ""$escSub"", ""Dominio principal VPS"")"
$db = Replace-Ordinal $db '("vps_domain", "PONER_SUBDOMINIO_AQUI", "Dominio principal VPS")' "(""vps_domain"", ""$escSub"", ""Dominio principal VPS"")"
$db = Replace-Ordinal $db "movisvip.servegame.com" $escSub
$db = Replace-Ordinal $db "movivipoppax.uk" $escMain
$db = Replace-Ordinal $db "PONER_SUBDOMINIO_AQUI" $escSub
$db = Replace-Ordinal $db "PONER_DOMINIO_AQUI" $escMain
$db = Replace-Ordinal $db "brand TEXT DEFAULT 'movivip'," "brand TEXT DEFAULT '$clienteLo',"
$db = Replace-Ordinal $db "-- marca: movivip, klepernet, etc." "-- marca: $clienteLo (white-label del cliente)"
$db = Apply-Branding $db
Write-Utf8NoBom (Join-Path $outDir "database.py") $db

Write-Host " OK" -ForegroundColor Green

# =============================================================================
# 6) REQUIREMENTS + MENU.SH + DEPLOY.SH + LEEME
# =============================================================================
Write-Host "[6/6] deploy + docs ..." -NoNewline
$req = @"
python-telegram-bot==21.11.1
aiohttp
paramiko
bcrypt
requests
cryptography
flask
"@
Write-Utf8NoBom (Join-Path $outDir "requirements.txt") $req

# -----------------------------------------------------------------------------
# MENU.SH — Menu interactivo para el cliente en el VPS
#   - Ver como funciona el bot (flujo de redireccion) ANTES de activar
#   - Configurar enlace de redireccion (LINK_REDIREC)
#   - Configurar canal/grupo de notificaciones (notif_bot)
#   - Activar (requiere 4GB+ RAM) / desactivar / ver estado del bot
# -----------------------------------------------------------------------------
$menu = @"
#!/bin/bash
# =============================================================================
# MENU DE CONFIGURACION — Bot $($Cliente.ToUpper()) ($clienteLo)
# Ejecutar como root en el VPS del cliente:
#   bash menu.sh
# =============================================================================

CONF=/root/movivip_bots/$clienteLo/config.py
SERVICE_ADMIN=movivip-$clienteLo-admin
SERVICE_NOTIF=movivip-$clienteLo-notif

verde="\e[32m"; rojo="\e[31m"; amarillo="\e[33m"; cyan="\e[36m"; reset="\e[0m"

RAM_MB="`$(free -m | awk '/^Mem:/{print `$2}')"

# ---------------------------------------------------------------------------
leer_config() {
  LINK="`$(grep -oP '^LINK_REDIREC = \"\K[^\"]*' "`$CONF" 2>/dev/null || echo '')"
  CANAL="`$(grep -oP '^NOTIF_CHANNEL_ID = \K-?[0-9]+' "`$CONF" 2>/dev/null || echo '')"
  GRUPO="`$(grep -oP '^NOTIF_GROUP_ID = \K-?[0-9]+' "`$CONF" 2>/dev/null || echo '')"
}

flujo_descripcion() {
  echo -e "  ├─ 🔗 El cliente abre el bot, registra su usuario y elige plan/puerto."
  echo -e "  ├─ ⚡ El bot crea su cuenta SSH automaticamente y se la envia."
  echo -e "  ├─ 💬 Al final redirige al enlace de pago/activacion del dueno:"
  echo -e "  │     ${verde}`$LINK${reset}"
  echo -e "  └─ 📢 Las altas se notifican al canal/grupo del dueno (notif_bot)."
}

ver_flujo() {
  clear
  leer_config
  echo -e "${cyan}══════════════════════════════════════════════════════════${reset}"
  echo -e "${cyan}   BOT $($Cliente.ToUpper()) — COMO FUNCIONA EL BOT${reset}"
  echo -e "${cyan}══════════════════════════════════════════════════════════${reset}"
  echo -e "  ${amarillo}Enlace de redireccion:${reset} ${verde}`$LINK${reset}"
  echo ""
  echo -e "  ${cyan}FLUJO ACTUAL:${reset}"
  flujo_descripcion
  echo ""
  echo -e "  ${cyan}LO QUE EL BOT HACE (paso a paso):${reset}"
  echo -e "  1. El usuario abre el bot y registra su usuario (usuario/contraseña)."
  echo -e "  2. Elige pais, operador (Movistar/Claro/Virgin), plan (dias) y dispositivos."
  echo -e "  3. Elige puerto (SSH/SSL/TLS/UDP/Dropbear)."
  echo -e "  4. El bot crea su cuenta SSH automaticamente y se la envia."
  echo -e "  5. El bot le muestra el enlace de pago/activacion del dueno."
  echo -e "  6. Las altas se notifican al canal del dueno (notif_bot)."
  echo ""
  echo -e "  ${cyan}══════════════════════════════════════════════════════════${reset}"
  read -p "Presiona ENTER para volver al menu..."
}

configurar_enlace() {
  clear
  leer_config
  echo -e "${cyan}══════════════════════════════════════════════════════════${reset}"
  echo -e "${cyan}   ENLACE DE REDIRECCION (LINK_REDIREC)${reset}"
  echo -e "${cyan}══════════════════════════════════════════════════════════${reset}"
  echo -e "  Es el enlace (tu web, WhatsApp, Telegram o pasarela) al que el"
  echo -e "  bot redirige al cliente DESPUES de crear su cuenta SSH, para que"
  echo -e "  pague o active su servicio contigo."
  echo ""
  echo -e "  Actual: ${verde}`$LINK${reset}"
  echo -e "  (dejalo vacio y presiona ENTER para que el bot NO muestre enlace)"
  echo ""
  read -p "Nuevo enlace (ej: https://t.me/$clienteLo): " URL
  if [ -z "`$URL" ]; then
    sed -i "s|^LINK_REDIREC = .*|LINK_REDIREC = \"\"|" "`$CONF"
    echo -e "${amarillo}✓ Enlace oculto (LINK_REDIREC vacio)${reset}"
  else
    sed -i "s|^LINK_REDIREC = .*|LINK_REDIREC = \"`$URL\"|" "`$CONF"
    echo -e "${verde}✓ Enlace configurado: `$URL${reset}"
  fi
  echo -e "${amarillo}Reiniciando bot...${reset}"
  systemctl restart "`$SERVICE_ADMIN" 2>/dev/null && echo -e "${verde}✓ Bot reiniciado${reset}" || echo -e "${rojo}⚠️  No se pudo reiniciar (servicio inactivo?)${reset}"
  sleep 1
}

configurar_canal() {
  clear
  leer_config
  echo -e "${cyan}══════════════════════════════════════════════════════════${reset}"
  echo -e "${cyan}   CANAL / GRUPO DE NOTIFICACIONES (notif_bot)${reset}"
  echo -e "${cyan}══════════════════════════════════════════════════════════${reset}"
  echo -e "  El bot de notificaciones avisa en tu canal y grupo cada vez que"
  echo -e "  un cliente crea una cuenta SSH."
  echo ""
  echo -e "  Canal actual: ${verde}`$CANAL${reset}"
  echo -e "  Grupo actual: ${verde}`$GRUPO${reset}"
  echo -e "  Para obtener el ID numerico: añade a @RawDataBot al canal/grupo"
  echo -e "  y copia el 'chat id' que aparece (ej: -1001234567890)."
  echo ""
  read -p "Nuevo canal ID (o ENTER para dejarlo): " NCANAL
  if [ -n "`$NCANAL" ]; then
    sed -i "s|^NOTIF_CHANNEL_ID = .*|NOTIF_CHANNEL_ID = `$NCANAL|" "`$CONF"
    echo -e "${verde}✓ Canal actualizado: `$NCANAL${reset}"
  fi
  read -p "Nuevo grupo ID (o ENTER para dejarlo): " NGRUPO
  if [ -n "`$NGRUPO" ]; then
    sed -i "s|^NOTIF_GROUP_ID = .*|NOTIF_GROUP_ID = `$NGRUPO|" "`$CONF"
    echo -e "${verde}✓ Grupo actualizado: `$NGRUPO${reset}"
  fi
  echo -e "${amarillo}Reiniciando bot de notificaciones...${reset}"
  systemctl restart "`$SERVICE_NOTIF" 2>/dev/null && echo -e "${verde}✓ notif_bot reiniciado${reset}" || echo -e "${rojo}⚠️  No se pudo reiniciar (servicio inactivo?)${reset}"
  sleep 1
}

estado_bot() {
  clear
  echo -e "${cyan}══════════════════════════════════════════════════════════${reset}"
  echo -e "${cyan}   ESTADO DEL BOT $($Cliente.ToUpper())${reset}"
  echo -e "${cyan}══════════════════════════════════════════════════════════${reset}"
  for SVC in "`$SERVICE_ADMIN" "`$SERVICE_NOTIF"; do
    if systemctl is-active --quiet "`$SVC"; then
      echo -e "  `$SVC: ${verde}ACTIVO ✓${reset}"
    else
      echo -e "  `$SVC: ${rojo}INACTIVO ✗${reset}"
    fi
    systemctl is-enabled "`$SVC" >/dev/null 2>&1 && echo -e "  `$SVC inicio con el sistema: ${verde}SI${reset}" || echo -e "  `$SVC inicio con el sistema: ${rojo}NO${reset}"
    echo ""
    systemctl status "`$SVC" --no-pager -l 2>/dev/null | head -n 8
    echo ""
  done
  echo -e "  ${cyan}Ultimos logs (admin):${reset}"
  journalctl -u "`$SERVICE_ADMIN" --no-pager -n 8 2>/dev/null || true
  echo ""
  read -p "Presiona ENTER para volver..."
}

activar_bot() {
  if [ "`$RAM_MB" -lt 4096 ]; then
    echo -e "${rojo}✗ ERROR: se requieren minimo 4 GB de RAM para ACTIVAR el bot.${reset}"
    echo -e "${rojo}  RAM detectada: `$RAM_MB MB. Mejora el VPS y vuelve a intentar.${reset}"
    sleep 2
    return
  fi
  echo -e "${amarillo}Activando bot...${reset}"
  systemctl enable "`$SERVICE_ADMIN" "`$SERVICE_NOTIF" 2>/dev/null
  systemctl start "`$SERVICE_ADMIN" "`$SERVICE_NOTIF" 2>/dev/null
  sleep 2
  if systemctl is-active --quiet "`$SERVICE_ADMIN"; then
    echo -e "${verde}✓ Bot ADMIN ACTIVO y arrancando con el sistema${reset}"
  else
    echo -e "${rojo}⚠️  El bot admin no arranco. Revisa: journalctl -u `$SERVICE_ADMIN -n 30${reset}"
  fi
  if systemctl is-active --quiet "`$SERVICE_NOTIF"; then
    echo -e "${verde}✓ Bot NOTIF ACTIVO y arrancando con el sistema${reset}"
  else
    echo -e "${rojo}⚠️  El bot notif no arranco. Revisa: journalctl -u `$SERVICE_NOTIF -n 30${reset}"
  fi
  sleep 1
}

desactivar_bot() {
  echo -e "${amarillo}Desactivando bot...${reset}"
  systemctl disable "`$SERVICE_ADMIN" "`$SERVICE_NOTIF" 2>/dev/null
  systemctl stop "`$SERVICE_ADMIN" "`$SERVICE_NOTIF" 2>/dev/null
  echo -e "${verde}✓ Bot desactivado (no arranca con el sistema)${reset}"
  sleep 1
}

# ---------------------------------------------------------------------------
while true; do
  clear
  leer_config
  echo -e "${cyan}══════════════════════════════════════════════════════════${reset}"
  echo -e "${cyan}   MENU — BOT $($Cliente.ToUpper())${reset}"
  echo -e "${cyan}   Enlace: ${verde}`$LINK${reset}${cyan} | Canal: ${verde}`$CANAL${reset}"
  echo -e "${cyan}══════════════════════════════════════════════════════════${reset}"
  echo -e "  ${verde}1)${reset} Ver como funciona el bot (flujo actual) — antes de activar"
  echo -e "  ${verde}2)${reset} Configurar enlace de redireccion (LINK_REDIREC)"
  echo -e "  ${verde}3)${reset} Configurar canal/grupo de notificaciones"
  echo -e "  ${verde}4)${reset} Activar bot (requiere 4GB+ RAM)"
  echo -e "  ${verde}5)${reset} Desactivar bot"
  echo -e "  ${verde}6)${reset} Estado del bot y logs"
  echo -e "  ${rojo}0)${reset} Salir"
  echo ""
  read -p "Opcion: " opcion
  case "`$opcion" in
    1) ver_flujo ;;
    2) configurar_enlace ;;
    3) configurar_canal ;;
    4) activar_bot ;;
    5) desactivar_bot ;;
    6) estado_bot ;;
    0) clear; echo -e "${verde}Hasta luego!${reset}"; exit 0 ;;
    *) echo -e "${rojo}Opcion invalida${reset}"; sleep 1 ;;
  esac
done
"@
Write-Utf8NoBom (Join-Path $outDir "menu.sh") $menu

$deploy = @"
#!/bin/bash
# =============================================================================
# DEPLOY BOT $($Cliente.ToUpper()) — Plan $($lim.label)
# Ejecutar como root en el VPS del cliente.
#   bash deploy.sh
# =============================================================================
set -e
echo "=== Instalando bot $Cliente (plan $($lim.label)) ==="

# Requisito minimo: 4 GB de RAM para ACTIVAR el bot (admin + notif)
TOTAL_RAM_MB="`$(free -m | awk '/^Mem:/{print `$2}')"
echo "RAM detectada: `$TOTAL_RAM_MB MB"
if [ "`$TOTAL_RAM_MB" -lt 4096 ]; then
  echo ""
  echo "⚠️  Tu VPS tiene menos de 4 GB de RAM."
  echo "   Puedes INSTALAR, pero la ACTIVACION del bot quedara bloqueada"
  echo "   hasta tener 4GB+ (bash menu.sh lo valida)."
  echo ""
  read -p "¿Continuar con la instalacion? (s/N): " OK
  if [ "`$OK" != "s" ] && [ "`$OK" != "S" ]; then
    echo "Instalacion cancelada."
    exit 1
  fi
fi

apt-get update -y
apt-get install -y python3-pip python3-venv git
SCRIPT_DIR="`$(cd "`$(dirname "`${BASH_SOURCE[0]}")"; pwd)"
BOT_DIR=/root/movivip_bots/$clienteLo
mkdir -p "`$BOT_DIR"
cp -f "`$SCRIPT_DIR"/*.py "`$SCRIPT_DIR"/requirements.txt "`$SCRIPT_DIR"/menu.sh "`$BOT_DIR"/ 2>/dev/null || true
# Foto de marca del cliente (bot.jpg para welcome/perfil)
cp -f "`$SCRIPT_DIR"/bot.jpg "`$BOT_DIR"/ 2>/dev/null || true
cd "`$BOT_DIR"
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
cat > /etc/systemd/system/movivip-$clienteLo-admin.service <<'EOF'
[Unit]
Description=MoviVIP $Cliente Admin Bot
After=network.target

[Service]
WorkingDirectory=/root/movivip_bots/$clienteLo
ExecStart=/root/movivip_bots/$clienteLo/venv/bin/python admin_bot.py
Restart=always
RestartSec=5
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF
cat > /etc/systemd/system/movivip-$clienteLo-notif.service <<'EOF'
[Unit]
Description=MoviVIP $Cliente Notif Bot
After=network.target

[Service]
WorkingDirectory=/root/movivip_bots/$clienteLo
ExecStart=/root/movivip_bots/$clienteLo/venv/bin/python notif_bot.py
Restart=always
RestartSec=5
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable movivip-$clienteLo-admin movivip-$clienteLo-notif
systemctl restart movivip-$clienteLo-admin movivip-$clienteLo-notif
sleep 3
systemctl status movivip-$clienteLo-admin --no-pager || true
systemctl status movivip-$clienteLo-notif --no-pager || true
echo ""
echo "=== LISTO! Bots instalados. Revisa con: ==="
echo "   journalctl -u movivip-$clienteLo-admin -f"
echo "   journalctl -u movivip-$clienteLo-notif -f"
echo ""
echo "Para ACTIVAR el bot (con 4GB+ RAM): bash menu.sh"
"@
Write-Utf8NoBom (Join-Path $outDir "deploy.sh") $deploy

$leeme = @"
============================================================
  BOT ADMIN $($Cliente.ToUpper()) - MOVIVIP LICENSE SYSTEM
  Plan: $($lim.label) | Max dispositivos: $maxDev | V2Ray: $allowV2ray
  Generado: $(Get-Date -Format "yyyy-MM-dd HH:mm")
============================================================

ARCHIVOS DEL PAQUETE
--------------------
  config.py         -> UNICA configuracion: tokens, VPS, dominios, marca
  admin_bot.py      -> Bot de administracion (crear/extender/reducir cuentas)
  notif_bot.py      -> Bot de notificaciones (avisa altas en canal/grupo)
  ssh_utils.py      -> Libreria compartida (creacion de cuentas SSH)
  database.py       -> Base de datos SQLite (esquema)
  requirements.txt  -> Dependencias Python
  deploy.sh         -> Instalacion automatica en el VPS (1 comando)
  menu.sh           -> Menu del cliente: flujo, enlace, canal, activar bot

MENU DEL CLIENTE (DESPUES DE INSTALAR)
--------------------------------------
  Una vez instalado el bot, el cliente puede configurar TODO sin tocar codigo:
    bash menu.sh
  Desde el menu el cliente puede:
    - VER como funciona el bot (flujo paso a paso) ANTES de activarlo
    - Poner su enlace de redireccion (LINK_REDIREC) — donde el cliente paga
    - Configurar el canal/grupo donde el bot notifica las altas
    - Activar (requiere 4GB+ RAM) / desactivar / ver estado y logs
  El menu edita config.py en el VPS y reinicia los servicios automaticamente.

CONFIGURAR EL PAQUETE (ANTES DE SUBIR)
--------------------------------------
  Edita config.py con LOS DATOS DEL VPS DEL CLIENTE:
    - ADMIN_BOT_TOKEN                  -> token del bot admin (@BotFather)
    - NOTIF_BOT_TOKEN                  -> token del bot de notificaciones
       (DEBE ser un bot DISTINTO al admin; si usas el mismo, no corren juntos)
    - ADMIN_IDS                        -> ID numerico de Telegram del dueno
    - VPS_HOST / VPS_USER / VPS_PASSWORD -> acceso root del VPS del cliente
    - VPS_SUBDOMAIN                    -> subdominio que apunta al VPS (SSH)
    - DOMAIN_MAIN                      -> dominio base (SlowDNS/VayDNS/DNSTT)
    - XRAY_VLESS_REALITY_PUBKEY / SHORTID -> datos Reality del VPS del cliente
    - BRAND_* / MAIN_CHANNEL           -> canales y marca del cliente
    - LINK_REDIREC                     -> enlace al que el bot redirige al cliente
    - NOTIF_CHANNEL_ID / NOTIF_GROUP_ID -> canal/grupo de notificaciones

FLUJO DEL BOT (SIN PAGOS EMBEBIDOS)
-----------------------------------
  Este paquete NO cobra dentro del bot. Flujo:
    1. El cliente registra su usuario y elige operador/plan/puerto.
    2. El bot crea su cuenta SSH automaticamente y se la envia.
    3. El bot redirige al cliente a LINK_REDIREC (el enlace del dueno:
       su web, WhatsApp, Telegram o pasarela donde el cliente paga/activa).
    4. El bot de notificaciones avisa al canal/grupo del dueno cada alta.
  Cambiar el enlace o canal: bash menu.sh (en el VPS).

FOTOS Y DESCRIPCIONES DE MARCA (POR CLIENTE)
--------------------------------------------
  El bot usa fotos y textos de marca propios del cliente. Antes de subir,
  reemplaza los archivos de imagen en el paquete:
    - bot.jpg      -> foto de bienvenida y perfil del bot (welcome)
  Si no incluyes la foto, el bot envia los mensajes SIN imagen (no falla).
  Los textos/captions (welcome, "CREAR CUENTA SSH", "VELOCIDAD EXTREMA",
  ayuda, servidores, etc.) ya llevan el nombre "$Cliente Network"
  inyectado por el generador.

INSTALACION EN EL VPS DEL CLIENTE
---------------------------------
  1) Sube esta carpeta al VPS (raiz):
       scp -r /ruta/entregas/$clienteLo root@IP:/root/
  2) Conectate por SSH y ejecuta:
       cd /root/$clienteLo
       bash deploy.sh
  3) Los bots quedan instalados como servicios systemd:
       movivip-$clienteLo-admin
       movivip-$clienteLo-notif
  4) El CLIENTE configura su bot con el menu interactivo:
       bash menu.sh
     (flujo, enlace de redireccion, canal, activar/desactivar)
     IMPORTANTE: la ACTIVACION exige 4 GB+ de RAM en el VPS.
  5) Ver logs:
       journalctl -u movivip-$clienteLo-admin -f
       journalctl -u movivip-$clienteLo-notif -f

CONFIGURAR EL BOT EN TELEGRAM
-----------------------------
  - Crea el bot admin con @BotFather y pega su token en config.py -> ADMIN_BOT_TOKEN
  - Crea un SEGUNDO bot para notificaciones y pega su token en NOTIF_BOT_TOKEN
  - Añade el bot de notificaciones como admin del canal/grupo (sin derechos de post)
  - El dueno es el ADMIN_IDS en config.py (IDs numericos de Telegram)
  - Obtener tu ID: hablale a @userinfobot

LIMITES DEL PLAN $($lim.label)
------------------------------
  - Maximo $maxDev dispositivos/perfiles por cuenta
  - V2Ray/Reality: $(if ($lim.allow_v2ray) {"HABILITADO"} else {"DESHABILITADO"})
  - Maximo $($lim.max_days) dias por cuenta

IMPORTANTE (SEGURIDAD)
----------------------
  - ESTE PAQUETE CONTIENE CREDENCIALES (token, password VPS).
  - NUNCA lo subas a GitHub publico ni lo compartas.
  - Cambia el password VPS del cliente al entregar el sistema.
  - Actualizaciones: mientras la licencia este activa.
"@
Write-Utf8NoBom (Join-Path $outDir "LEEME.txt") $leeme

Write-Host " OK" -ForegroundColor Green

# =============================================================================
# RESUMEN
# =============================================================================
Write-Host ""
Write-Host "  ==================================================" -ForegroundColor Cyan
Write-Host "   PAQUETE GENERADO: $outDir" -ForegroundColor Cyan
Write-Host "   Cliente: $($Cliente.ToUpper()) | Plan: $($lim.label)" -ForegroundColor Cyan
Write-Host "   VPS: $VpsHost | Subdominio: $VpsSubdominio" -ForegroundColor Cyan
Write-Host "   AdminIDs: $AdminIds" -ForegroundColor Cyan
Write-Host "   NotifToken: $(if ($NotifToken) { $NotifToken } else { '= admin token (AVISO: usa bot distinto)' })" -ForegroundColor Cyan
Write-Host "   Canal/Grupo notif: $NotifChannelId / $NotifGroupId" -ForegroundColor Cyan
Write-Host "  ==================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Siguiente paso: subir carpeta al VPS y ejecutar: bash deploy.sh" -ForegroundColor Yellow