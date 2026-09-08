#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#  MOVIVIP RELEASE BUILDER v7.0 — SOLO LOCAL (NUNCA PUBLICAR)
#  Construye el artefacto de release protegido (self-extracting):
#    - Copia limpia del paquete (sin credenciales/secretos/docs)
#    - Ofusca TODOS los scripts (.sh y .py) con stub gzip+base64
#    - Empaqueta en tar.gz + base64 → dist/install.sh
#    - Genera dist/install.sh.sha256 + dist/VERSION
#
#  Uso:
#    bash build/make-release.sh                       # bump patch auto
#    bash build/make-release.sh --version 7.0.0       # versión fija
#    bash build/make-release.sh --no-lib              # no ofuscar lib/
#    bash build/make-release.sh --no-py               # no ofuscar .py
#    bash build/make-release.sh --keep                # conserva tmp/
# ═══════════════════════════════════════════════════════════════
set -u

ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$(dirname "$ROOT")"
STAGE="$ROOT/tmp"
BUNDLE="$ROOT/bundle"
OUT="$ROOT/dist"
KEEP_STAGE=0
OPT_LIB=1
OPT_PY=1
VERSION=""

for A in "$@"; do
    case "$A" in
        --version) ;;
        --version=*) VERSION="${A#*=}" ;;
        --no-lib) OPT_LIB=0 ;;
        --no-py)  OPT_PY=0 ;;
        --keep)   KEEP_STAGE=1 ;;
    esac
done

# versión --version 7.0.0 (siguiente arg)
if [[ "${1:-}" == "--version" ]]; then VERSION="${2:-}"; fi

MARKER="MOVIVIP-PACKED"
MARKER_PY="MOVIVIP-PACKED-PY"

say(){ printf '\033[1;96m[BUILD]\033[0m %s\n' "$*"; }
err(){ printf '\033[1;91m[BUILD][ERROR]\033[0m %s\n' "$*"; exit 1; }

command -v gzip >/dev/null || err "gzip no encontrado"
command -v base64 >/dev/null || err "base64 no encontrado"
command -v tar >/dev/null || err "tar no encontrado"
if command -v python3 >/dev/null 2>&1; then PYBIN="python3"; else PYBIN="py -3"; fi

# ────────────────────────────────────────────────────────────────
# 1) VERSIÓN
# ────────────────────────────────────────────────────────────────
ORIG_VER="$(tr -d ' \r\n' < "$SRC/version.txt" 2>/dev/null || echo 0.0.0)"
if [[ -z "$VERSION" ]]; then
    IFS='.' read -r V1 V2 V3 <<< "$ORIG_VER"
    V1=${V1:-0}; V2=${V2:-0}; V3=${V3:-0}
    VERSION="$V1.$V2.$((V3 + 1))"
fi
say "Versión del paquete: v$ORIG_VER → v$VERSION"

# ────────────────────────────────────────────────────────────────
# 2) COPIA LIMPIA (sin secretos / herramientas dev / docs)
# ────────────────────────────────────────────────────────────────
[[ $KEEP_STAGE -eq 0 ]] && rm -rf "$STAGE" "$BUNDLE"
mkdir -p "$STAGE" "$BUNDLE" "$OUT"

shopt -s extglob dotglob
# Exclusión por nombre — herramientas de deploy contienen credenciales
EXCL_NAMES="tools|build|backups|\.pack-backup|logs|data|notas|session|\.git"
for E in "$SRC"/*; do
    N="$(basename "$E")"
    if [[ "$N" =~ ^($EXCL_NAMES)(/.*)?$ ]]; then
        say "excluido: $N"
        continue
    fi
    case "$N" in
        *.md|*.pem|*.key|*.pub|*.crt|*.log) say "excluido (sens/doc): $N"; continue ;;
        .movivip-check.sh|.gitignore)       say "excluido (dev): $N";      continue ;;
    esac
    cp -r "$E" "$STAGE/" 2>/dev/null || true
done
shopt -u extglob dotglob

# Post-copy: eliminar basura residua que se coló dentro de dirs
find "$STAGE" -name 'scp_err.txt' -delete 2>/dev/null
find "$STAGE" -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null
find "$STAGE" -name '*.pyc' -delete 2>/dev/null

[[ -d "$STAGE/protocolos" ]] || err "copia limpia incompleta (falta protocolos/)"

# ────────────────────────────────────────────────────────────────
# 3) ESCÁNER DE SECRETOS — NUNCA debe viajar el código fuente
# ────────────────────────────────────────────────────────────────
say "Escaneando secretos/credenciales..."
HITS=$(grep -rIlE "ghp_[A-Za-z0-9]{20,}|uDeUgllsCKRuapsagAoE|BEGIN (RSA |OPENSSH |EC )?PRIVATE KEY|root@82\.39" "$STAGE" 2>/dev/null)
if [[ -n "$HITS" ]]; then
    echo "  ⚠ Posibles secretos encontrados:"
    echo "$HITS" | sed 's/^/    /'
    err "Abortando: elimina los secretos del paquete antes de publicar"
fi

# ────────────────────────────────────────────────────────────────
# 4) OFUSCACIÓN MASIVA — .sh (stub bash) + .py (stub python)
# ────────────────────────────────────────────────────────────────
is_excluded() {
    local P="$1"
    local REL="${P#$STAGE/}"
    case "$REL" in
        config.conf|*.conf|version.txt|.env-bot|.master-key|licencia.conf) return 0 ;;
        languages/*|sistema/*|backups/*|gate/*|logs/*|hwids/*)            return 0 ;;
        bot-generador.sh|setup-bot-generador.sh|descifrar-secrets.sh)      return 0 ;;
        tools/*|dev/*|build/*|.pack-backup/*|bundle/*)                     return 0 ;;
        *.md|*.txt|*.ps1|*.svg|*.service|*.json|*.hwid|*.pub|*.key|*.pem|*.crt|*.log|*.tar|*.tgz) return 0 ;;
    esac
    return 1
}

OFUSC=0; SKIP=0
while IFS= read -r -d '' F; do
    head -n 2 "$F" 2>/dev/null | grep -q "$MARKER" && { SKIP=$((SKIP+1)); continue; }
    is_excluded "$F" && { SKIP=$((SKIP+1)); continue; }

    case "$F" in
        *.sh)
            HEAD=$(head -n 1 "$F" 2>/dev/null)
            [[ "$HEAD" == *"#!/bin/bash"* || "$HEAD" == *"#!/usr/bin/env bash"* || "$HEAD" == *"#!/bin/sh"* ]] || { SKIP=$((SKIP+1)); continue; }
            B64=$(gzip -9 < "$F" | base64 -w0 2>/dev/null)
            [[ -z "$B64" ]] && { err "gzip falló en $F"; }
            printf '#!/bin/bash\n# %s v1 — MoviVIP Network · codigo protegido\neval "$(echo %s | base64 -d | gunzip)"\n' "$MARKER" "$B64" > "$F"
            ;;
        *.py)
            [[ $OPT_PY -eq 0 ]] && { SKIP=$((SKIP+1)); continue; }
            # quitar BOM utf-8 antes de empaquetar
            if [[ "$(od -A n -t x1 -N 3 "$F" 2>/dev/null | tr -d ' \n')" == "efbbbf" ]]; then
                tail -c +4 "$F" > "$F.tmp" && mv "$F.tmp" "$F"
            fi
            B64=$(gzip -9 < "$F" | base64 -w0 2>/dev/null)
            [[ -z "$B64" ]] && { err "gzip falló en $F"; }
            printf '#!/usr/bin/env python3\n# %s v1 — MoviVIP Network · codigo protegido\nimport base64,gzip\nexec(gzip.decompress(base64.b64decode("%s")).decode("utf-8").lstrip("\\ufeff"))\n' "$MARKER_PY" "$B64" > "$F"
            ;;
        *)
            SKIP=$((SKIP+1)); continue ;;
    esac
    chmod +x "$F" 2>/dev/null
    OFUSC=$((OFUSC+1))
done < <(find "$STAGE" -type f -print0)

say "$OFUSC archivos ofuscados ($SKIP omitidos)"

# ────────────────────────────────────────────────────────────────
# 5) SMOKE TEST — stubs ejecutables y sintaxis del código real
# ────────────────────────────────────────────────────────────────
say "Smoke test: bash -n de todos los .sh del paquete..."
FAIL=0
while IFS= read -r -d '' F; do
    if ! bash -n "$F" 2>/dev/null; then
        echo "  FAIL sintaxis: $F"; FAIL=1
    fi
done < <(find "$STAGE" -name '*.sh' -type f -print0)
[[ $FAIL -eq 1 ]] && err "Smoke test de sintaxis falló"

if [[ $OPT_PY -eq 1 ]]; then
    say "Smoke test: sintaxis python de los .py ofuscados..."
    PYFAIL=0
    while IFS= read -r -d '' F; do
        $PYBIN - "$F" <<'PYTEST' 2>/dev/null || true
import sys, re, base64, gzip, ast
p = sys.argv[1]
s = open(p, encoding='utf-8', errors='replace').read()
m = re.search(r'b64decode\("([^"]+)"\)', s)
if not m:
    sys.exit(0)
src = gzip.decompress(base64.b64decode(m.group(1))).decode('utf-8')
try:
    ast.parse(src)
    print('  PY-OK', p.split('/')[-1])
except SyntaxError as e:
    print('  PY-FAIL', p, e)
    sys.exit(1)
PYTEST
        RC=$?
        [[ $RC -ne 0 && $RC -ne 2 ]] && PYFAIL=1
    done < <(find "$STAGE" -name '*.py' -type f -print0)
    if [[ $PYFAIL -eq 1 ]]; then
        echo "  [WARN] algunos .py no pasaron el parse (revisar)"
    fi
fi

# version.txt del paquete → versión nueva
echo "$VERSION" > "$STAGE/version.txt"

# ────────────────────────────────────────────────────────────────
# 6) EMPAQUETAR → BASE64 → SELF-EXTRACTING INSTALLER
# ────────────────────────────────────────────────────────────────
say "Empaquetando..."
(cd "$STAGE" && tar czf "$BUNDLE/movivip.tgz" .) 2>/dev/null || err "fallo tar"
PAYLOAD=$(base64 -w0 "$BUNDLE/movivip.tgz")
PKG_SHA=$(printf '%s' "$PAYLOAD" | sha256sum | cut -d' ' -f1)
PKG_BYTES=$(wc -c < "$BUNDLE/movivip.tgz")

{
    cat <<'HDR1'
#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#  MoviVIP Network — INSTALADOR SEGURO (self-extracting)
#  Paquete protegido · instalación/actualización vía release
#
#  Uso:
#    bash install.sh              → instalar (interactivo)
#    bash install.sh --update     → actualizar /etc/movivip (preserva datos)
#    bash install.sh --apply DIR  → desplegar paquete a DIR (pruebas)
#    bash install.sh --verify     → verificar integridad del paquete
# ═══════════════════════════════════════════════════════════════
set -u

MARKER="MOVIVIP-PACKED"
BASE="/etc/movivip"
HDR1
    printf 'VERSION="%s"\n' "$VERSION"
    printf 'PAYLOAD="%s"\n' "$PAYLOAD"
    printf 'EXPECT_SHA="%s"\n' "$PKG_SHA"
    cat <<'HDR4'
say(){ printf '\033[1;96m[MoviVIP]\033[0m %s\n' "$*"; }
die(){ printf '\033[1;91m[MoviVIP][ERROR]\033[0m %s\n' "$*"; exit 1; }

verify() {
    local got
    got=$(printf '%s' "$PAYLOAD" | sha256sum | cut -d' ' -f1)
    [[ "$got" == "$EXPECT_SHA" ]] || die "integridad del paquete NO verificada (got=$got)"
}

extract() {   # $1 = dir destino
    echo "$PAYLOAD" | base64 -d | tar xz -C "$1" 2>/dev/null || die "no se pudo extraer el paquete"
}

cmd_verify() {
    verify
    local T
    T="$(mktemp -d)"
    extract "$T"
    local TOTAL PC NTOTAL
    TOTAL=$(find "$T" -type f | wc -l)
    NTOTAL=$(grep -rl "$MARKER" "$T" 2>/dev/null | wc -l)
    say "✅ Paquete v$VERSION íntegro: $TOTAL archivos, $NTOTAL protegidos (ofuscados)"
    say "   SHA256 del payload: $EXPECT_SHA"
    say "   version: $(cat "$T/version.txt" 2>/dev/null)"
    say "   clave:   $(ls "$T" | tr '\n' ' ')"
    rm -rf "$T"
    return 0
}

cmd_update() {
    verify
    local TMPI EXTRA BK KEEP
    TMPI="$(mktemp -d)"
    EXTRA="$(mktemp -d)"
    extract "$TMPI" || die "extracción falló"

    mkdir -p "$BASE/backups" 2>/dev/null || die "no existe $BASE (usa: bash install.sh)"
    BK="$BASE/backups/release_$(date +%Y%m%d_%H%M%S).tar.gz"
    tar czf "$BK" -C /etc --exclude='movivip/logs' --exclude='movivip/backups' movivip 2>/dev/null
    say "💾 Backup pre-actualización: $BK"
    ls -1t "$BASE"/backups/release_*.tar.gz 2>/dev/null | tail -n +4 | xargs -r rm -f 2>/dev/null

    # Datos runtime que el paquete NUNCA debe pisar
    KEEP="$EXTRA/_datos_servidor.tar"
    tar cf "$KEEP" -C "$BASE" --ignore-failed-read \
        config.conf licencia.conf .last_commit_hash .env-bot .env \
        sistema/consumo_snapshots.conf sistema/consumo_usuarios.conf \
        sistema/limites_conexiones.conf sistema/limites_consumo.conf \
        sistema/network_state.conf sistema/xray_limites.conf sistema/xray_ports.conf \
        ddos/puertos.conf 2>/dev/null || true

    # Usuarios fuera de /etc/movivip (ZipVPN + Xray)
    if [[ -f /etc/zivpn/config.json ]]; then
        mkdir -p "$EXTRA/_usuarios"
        cp -f /etc/zivpn/config.json "$EXTRA/_usuarios/zivpn-config.json" 2>/dev/null
    fi
    if [[ -f /usr/local/etc/xray/config.json ]]; then
        mkdir -p "$EXTRA/_usuarios"
        cp -f /usr/local/etc/xray/config.json "$EXTRA/_usuarios/xray-config.json" 2>/dev/null
    fi

    # Aplicar paquete
    cp -rf "$TMPI"/. "$BASE"/ 2>/dev/null

    # Restaurar datos del servidor encima
    if [[ -f "$KEEP" ]]; then tar xf "$KEEP" -C "$BASE" 2>/dev/null || true; fi

    # Restaurar usuarios ZipVPN + Xray (solo si el nuevo viene sin usuarios)
    if [[ -f "$EXTRA/_usuarios/zivpn-config.json" ]]; then
        if [[ ! -f /etc/zivpn/config.json ]] \
            || [[ $(jq -r '[.auth.config[]?] | length' /etc/zivpn/config.json 2>/dev/null || echo 0) -le 1 ]] \
            && [[ $(jq -r '[.auth.config[]?] | length' "$EXTRA/_usuarios/zivpn-config.json" 2>/dev/null || echo 0) -gt 1 ]]; then
            mkdir -p /etc/zivpn 2>/dev/null
            cp -f "$EXTRA/_usuarios/zivpn-config.json" /etc/zivpn/config.json 2>/dev/null
            chmod 600 /etc/zivpn/config.json 2>/dev/null
            say "🔑 ZipVPN: usuarios preservados restaurados"
        fi
    fi
    if [[ -f "$EXTRA/_usuarios/xray-config.json" ]]; then
        if [[ ! -f /usr/local/etc/xray/config.json ]] \
            || [[ $(jq -r '[.inbounds[].settings.clients[]?] | length' /usr/local/etc/xray/config.json 2>/dev/null || echo 0) -eq 0 ]] \
            && [[ $(jq -r '[.inbounds[].settings.clients[]?] | length' "$EXTRA/_usuarios/xray-config.json" 2>/dev/null || echo 0) -gt 0 ]]; then
            mkdir -p /usr/local/etc/xray 2>/dev/null
            cp -f "$EXTRA/_usuarios/xray-config.json" /usr/local/etc/xray/config.json 2>/dev/null
            chmod 644 /usr/local/etc/xray/config.json 2>/dev/null
            say "🛰️ Xray: usuarios preservados restaurados"
        fi
    fi

    echo "$VERSION" > "$BASE/version.txt"
    chmod -R +x "$BASE" 2>/dev/null
    chmod 600 "$BASE/licencia.conf" "$BASE/config.conf" 2>/dev/null

    rm -rf "$TMPI" "$EXTRA"
    say "✅ Actualización completada: v$VERSION aplicada en $BASE"
    if [[ -f "$BASE/protocolos/v2ray.sh" ]]; then
        bash "$BASE/protocolos/v2ray.sh" --ensure-cleanup 2>/dev/null || true
    fi
    return 0
}

cmd_apply() {   # $1 = dir destino (pruebas)
    verify
    local DEST="$1"
    [[ -n "$DEST" ]] || die "usa: bash install.sh --apply DIR"
    mkdir -p "$DEST"
    extract "$DEST"
    chmod -R +x "$DEST" 2>/dev/null
    echo "$VERSION" > "$DEST/version.txt" 2>/dev/null || true
    say "✅ Paquete v$VERSION desplegado en $DEST"
    say "   archivos: $(find "$DEST" -type f | wc -l) · protegidos: $(grep -rl "$MARKER" "$DEST" 2>/dev/null | wc -l)"
    return 0
}

MODO="${1:-install}"
case "$MODO" in
    --verify) cmd_verify ;;
    --update) cmd_update ;;
    --apply)  cmd_apply "${2:-}" ;;
    *)
        verify
        local T
        T="$(mktemp -d)"
        extract "$T" || die "extracción falló"
        cd "$T" || die "no se pudo entrar al paquete"
        say "🚀 Iniciando instalador de MoviVIP v$VERSION (paquete protegido)"
        exec bash ./install.sh
        ;;
esac
HDR4
} > "$OUT/install.sh"

chmod +x "$OUT/install.sh"
# forzar LF (Windows puede inyectar CR)
sed -i 's/\r$//' "$OUT/install.sh" 2>/dev/null
bash -n "$OUT/install.sh" || err "el instalador generado tiene sintaxis inválida"
sha256sum "$OUT/install.sh" | awk '{print $1}' > "$OUT/install.sh.sha256"
echo "$VERSION" > "$OUT/VERSION"

say "── RELEASE LISTA ────────────────────────────────────────────"
say "OUT   : $OUT"
say "versión        : v$VERSION"
say "instalador     : install.sh      $(du -h "$OUT/install.sh" | cut -f1)"
say "sha256         : install.sh.sha256  ($(cat "$OUT/install.sh.sha256" | cut -c1-16)…)"
say "paquete tgz    : $(du -h "$BUNDLE/movivip.tgz" | cut -f1) ($PKG_BYTES bytes, sha256=$PKG_SHA)"
say "archivos       : $(find "$STAGE" -type f | wc -l) incl. $OFUSC ofuscados"
say "instalar fresh : bash install.sh"
say "actualizar     : bash install.sh --update"
say "verificar      : bash install.sh --verify"
say "▸ version.txt local del paquete SIN actualizar (hazlo en B2): v$(cat "$SRC/version.txt" 2>/dev/null)"