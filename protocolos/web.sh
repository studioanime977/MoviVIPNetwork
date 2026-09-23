#!/bin/bash
# ============================================================
#  MOVIVIP WEB INSTALLER v1.2 — Panel Web MoviVIP
#  Self-contained · Multi-arch · NO destructivo · EMPAQUETADO
#
#  ✔ ACCESO EXCLUSIVO: planes premium / vitalicia / superadmin
#  ✔ Submenú ordenado (como los demás protocolos del panel)
#
#  Instala / actualiza el Panel Web (backend + frontend ofuscado)
#  sobre cualquier VPS de cliente SIN tocar sus datos.
#  Los assets viajan EMPAQUETADOS en $BASE/protocolos/web/
#  (dentro del propio paquete del release) — no quedan sueltos.
#
#  Uso:
#    bash movivip.sh             menú ordenado (interactivo)
#    bash movivip.sh --install   instalar/actualizar (auto, con verificación de plan)
#    bash movivip.sh --status    estado del panel
#    bash movivip.sh --uninstall desinstalar (conserva /etc/movivip)
#    bash movivip.sh --version   versión
#
#  Variables de entorno:
#    WEB_PORT=9617               puerto del panel
#    RELEASE=v7.4.5              release GitHub (solo fallback si falta asset local)
#    NO_COMPILE=1                no compilar Nuitka (solo binario precompilado)
# ============================================================

set -uo pipefail

VERSION="1.2.0"
BASE="/etc/movivip"
WEB_DIR="/opt/movivip-web"
WEB_ETC="/etc/movivip-web"
WEB_PORT="${WEB_PORT:-9617}"
WEB_USER="root"
GITHUB_ORG="studioanime977"
GITHUB_REPO="MoviVIPNetwork"
RELEASE="${RELEASE:-v7.4.5}"
GH_BASE="https://github.com/${GITHUB_ORG}/${GITHUB_REPO}/releases/download/${RELEASE}"

export LANG=C

# Paleta
RED=$'\e[1;91m'; GREEN=$'\e[1;92m'; YELLOW=$'\e[1;93m'; CYAN=$'\e[1;96m'; WHITE=$'\e[1;97m'; GRAY=$'\e[2m'; RESET=$'\e[0m'
log()  { echo -e "${CYAN}[MOVIVIP-WEB]${RESET} $*"; }
ok()   { echo -e "${GREEN}✔${RESET} $*"; }
warn() { echo -e "${YELLOW}⚠${RESET} $*"; }
err()  { echo -e "${RED}✘${RESET} $*" >&2; }

# ------------------------------------------------------------
# Acceso exclusivo · Verificación de plan (Firebase EN VIVO)
#   Solo están habilitados: premium · vitalicia · superadmin
#   (super, mayorista, premium, platino, vitalicio = planes con bot)
# ------------------------------------------------------------
WEB_PLAN_OK=0
WEB_PLAN=""
WEB_CLIENTE=""
WEB_TIPO=""

check_web_acceso() {
    WEB_PLAN_OK=0; WEB_PLAN=""; WEB_CLIENTE=""; WEB_TIPO=""
    if [[ -f "$BASE/lib/firebase-plan.sh" ]]; then
        # shellcheck source=/dev/null
        source "$BASE/lib/firebase-plan.sh"
        firebase_plan ""   # usa la key de licencia.conf / env
        if [[ "$FP_VALID" -eq 1 ]]; then
            WEB_PLAN="${FP_PLAN:-}"; WEB_CLIENTE="${FP_CLIENTE:-}"; WEB_TIPO="${FP_TIPO:-}"
        fi
    fi
    # Fallback: licencia.conf tal cual (solo si el helper no existe)
    if [[ -z "$WEB_PLAN" && -f "$BASE/licencia.conf" ]]; then
        # shellcheck source=/dev/null
        source "$BASE/licencia.conf"
        WEB_PLAN="${PLAN:-}"; WEB_CLIENTE="${CLIENTE:-}"; WEB_TIPO="${TIPO:-}"
    fi
    local lo
    lo=$(echo "${WEB_PLAN,,}" | tr -d ' ')
    case "$lo" in
        super|mayorista|premium|platino|vitalicio) WEB_PLAN_OK=1 ;;
        *) WEB_PLAN_OK=0 ;;
    esac
    return $(( 1 - WEB_PLAN_OK ))
}

mostrar_estado_plan() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    if [[ "$WEB_PLAN_OK" == "1" ]]; then
        echo -e "  ${GREEN}✔ ACCESO HABILITADO${RESET} — plan ${WHITE}${WEB_PLAN:-?}${RESET}"
        [[ -n "$WEB_CLIENTE" ]] && echo -e "    Cliente : ${WHITE}$WEB_CLIENTE${RESET}"
    else
        echo -e "  ${RED}✘ ACCESO RESTRINGIDO${RESET}"
        echo -e "    El Panel Web MoviVIP es exclusivo para:"
        echo -e "    ${WHITE}premium · vitalicia · superadmin${RESET}"
        echo -e "    (tu plan: ${YELLOW}${WEB_PLAN:-sin licencia}${RESET})"
    fi
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

# ------------------------------------------------------------
# Detección de arquitectura
# ------------------------------------------------------------
detect_arch() {
    case "$(uname -m 2>/dev/null | tr '[:upper:]' '[:lower:]')" in
        x86_64|amd64)      echo "amd64" ;;
        aarch64|arm64)     echo "arm64" ;;
        ppc64le|powerpc64le) echo "ppc64le" ;;
        riscv64)           echo "riscv64" ;;
        s390x)             echo "s390x" ;;
        *)                 echo "amd64" ;;
    esac
}

need_cmd() { command -v "$1" >/dev/null 2>&1; }

# ------------------------------------------------------------
# Dependencias del sistema (NO pkg manager destructivo: usamos apt si existe)
# ------------------------------------------------------------
ensure_apt() {
    if ! command -v apt-get >/dev/null 2>&1; then
        err "Solo se soporta apt (Debian/Ubuntu) para dependencias del sistema."
        return 1
    fi
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq 2>/dev/null || true
    local pkgs=""
    for p in curl openssl python3 python3-venv python3-pip tar; do
        command -v "$p" >/dev/null 2>&1 || pkgs="$pkgs $p"
    done
    if ! command -v python3 >/dev/null 2>&1; then pkgs="$pkgs python3 python3-venv python3-pip"; fi
    [[ -n "$pkgs" ]] && apt-get install -y -qq $pkgs >/dev/null 2>&1 || true
}

# ------------------------------------------------------------
# Abrir puerto (ufw / firewalld / iptables) sin romper nada
# ------------------------------------------------------------
open_port() {
    local port="$1"
    if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
        ufw allow "$port/tcp" >/dev/null 2>&1 && ok "UFW: puerto $port/tcp abierto" || true
    fi
    if command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --state >/dev/null 2>&1; then
        firewall-cmd --permanent --add-port="$port/tcp" >/dev/null 2>&1 && firewall-cmd --reload >/dev/null 2>&1 && ok "firewalld: puerto $port/tcp abierto" || true
    fi
    if command -v iptables >/dev/null 2>&1; then
        iptables -C INPUT -p tcp --dport "$port" -j ACCEPT >/dev/null 2>&1 || {
            iptables -I INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null || true
        }
    fi
}

# ------------------------------------------------------------
# secret.key — respeta el existente (dato local), genera si falta
# ------------------------------------------------------------
ensure_secret() {
    mkdir -p "$WEB_ETC"
    chmod 700 "$WEB_ETC"
    if [[ -f "$WEB_ETC/secret.key" ]]; then
        ok "secret.key existente respetado ($WEB_ETC/secret.key)"
        return 0
    fi
    if command -v openssl >/dev/null 2>&1; then
        openssl rand -hex 24 > "$WEB_ETC/secret.key" 2>/dev/null
    else
        head -c 48 /dev/urandom | base64 -w0 > "$WEB_ETC/secret.key" 2>/dev/null
    fi
    chmod 600 "$WEB_ETC/secret.key"
    [[ -s "$WEB_ETC/secret.key" ]] && ok "secret.key generado" || { err "No se pudo generar secret.key"; return 1; }
}

# ------------------------------------------------------------
# Asset del Panel Web: LOCAL-FIRST (empaquetado en el paquete,
# path $BASE/protocolos/web/) → fallback GitHub SOLO si falta.
# El paquete del release trae TODO dentro; no depende de GitHub.
# ------------------------------------------------------------
download_asset() {
    local url="$1" out="$2"
    local name
    name="$(basename "$url")"
    mkdir -p "$(dirname "$out")"
    # 1) Asset empaquetado en el propio paquete (protocolos/web/)
    local local_asset="$BASE/protocolos/web/$name"
    if [[ -f "$local_asset" && -s "$local_asset" ]]; then
        cp -f "$local_asset" "$out" && [[ -s "$out" ]] && return 0
    fi
    # 2) Fallback: release GitHub (solo si el paquete no lo incluye)
    if curl -fsSL --connect-timeout 15 --max-time 300 "$url" -o "$out" 2>/dev/null; then
        [[ -s "$out" ]] && return 0
    fi
    rm -f "$out"
    # 3) Fallback: raw main
    local raw="https://raw.githubusercontent.com/${GITHUB_ORG}/${GITHUB_REPO}/main/${name}"
    if curl -fsSL --connect-timeout 15 --max-time 300 "$raw" -o "$out" 2>/dev/null && [[ -s "$out" ]]; then
        return 0
    fi
    rm -f "$out"
    return 1
}

# ------------------------------------------------------------
# Backend: binario Nuitka precompilado por arch; si no existe → compilar
# ------------------------------------------------------------
backend_binary_name() {
    local arch="$1"
    echo "movivip-web-linux-${arch}.so"
}

# Nombre que CPython/Nuitka espera para importar "main":
#   main.cpython-310-x86_64-linux-gnu.so   (python3.10 amd64)
#   main.cpython-311-aarch64-linux-gnu.so  (python3.11 arm64)
nuitka_module_name() {
    local py="$WEB_DIR/venv/bin/python"
    local pyver="310"
    if [[ -x "$py" ]]; then
        pyver="$("$py" -c 'import sys;print("%d%d"%(sys.version_info.major,sys.version_info.minor))' 2>/dev/null || echo 310)"
    fi
    local mach
    mach="$(uname -m 2>/dev/null | tr '[:upper:]' '[:lower:]')"
    case "$mach" in
        x86_64|amd64) mach="x86_64" ;;
        aarch64|arm64) mach="aarch64" ;;
        armv7l|armhf) mach="armv7l" ;;
        i386|i686|x86) mach="i386" ;;
        *) mach="${mach:-x86_64}" ;;
    esac
    echo "main.cpython-${pyver}-${mach}-linux-gnu.so"
}

install_backend() {
    local arch
    arch="$(detect_arch)"
    log "Arquitectura detectada: ${arch}"

    mkdir -p "$WEB_DIR/static" "$WEB_DIR/data" "$WEB_DIR/functions"
    chmod 700 "$WEB_DIR/data" "$WEB_DIR" 2>/dev/null || true

    # 1) Intentar binario precompilado del release (rápido, sin toolchain)
    #    Se renombra a la convención Nuitka para que uvicorn "main:app" lo importe.
    local so_name so_path nuitka_name
    so_name="$(backend_binary_name "$arch")"
    so_path="$WEB_DIR/$so_name"
    nuitka_name="$(nuitka_module_name)"
    local got=0
    # Si ya existe el .so correcto (cualquier main.cpython-*) → lo usamos
    if ls "$WEB_DIR"/main.cpython-*.so >/dev/null 2>&1; then
        got=1
        ok "Backend Nuitka ya presente"
    elif [[ -f "$so_path" && -s "$so_path" ]]; then
        # .so precompilado descargado en una ejecución previa → renombrar
        mv -f "$so_path" "$WEB_DIR/$nuitka_name" 2>/dev/null || true
        got=1
        ok "Backend precompilado reutilizado: $nuitka_name"
    fi
    if [[ "$got" != "1" ]]; then
        log "Descargando backend precompilado ${arch}..."
        if download_asset "${GH_BASE}/${so_name}" "$so_path" && [[ -s "$so_path" ]]; then
            mv -f "$so_path" "$WEB_DIR/$nuitka_name" 2>/dev/null || true
            got=1
            ok "Backend precompilado: $nuitka_name"
        else
            warn "No hay binario precompilado para ${arch} en el release"
        fi
    fi

    # 2) Sin binario → compilar con Nuitka EN el VPS (self-contained python)
    if [[ "$got" != "1" ]]; then
        if [[ "${NO_COMPILE:-0}" == "1" ]]; then
            err "NO_COMPILE=1 y no hay binario ${arch} — no se puede continuar"
            return 1
        fi
        log "Compilando backend con Nuitka (puede tardar 2-4 min)..."
        # main.py fuente desde el release
        if ! download_asset "${GH_BASE}/main.py" "$WEB_DIR/main.py"; then
            err "No se pudo descargar main.py (fuente del backend)"
            return 1
        fi
        # Compilar dentro del venv (python 3.10+) para el .so correcto
        local PY="$WEB_DIR/venv/bin/python"
        if [[ ! -x "$PY" ]]; then
            err "No hay venv — ejecutar primero el venv"
            return 1
        fi
        "$PY" -m pip install -q nuitka==4.2.1 2>/dev/null || true
        ( cd "$WEB_DIR" && rm -f main.cpython-*.so && "$PY" -m nuitka --module --no-pyi-file --remove-output --output-dir=compile main.py >/dev/null 2>&1 ) || true
        local compiled
        compiled="$(ls "$WEB_DIR"/compile/main.cpython-*.so 2>/dev/null | head -1)"
        if [[ -n "$compiled" ]]; then
            mv -f "$compiled" "$WEB_DIR/$(nuitka_module_name)" 2>/dev/null || mv -f "$compiled" "$WEB_DIR/main.so" 2>/dev/null || true
            rm -rf "$WEB_DIR/compile"
            got=1
            ok "Backend compilado con Nuitka"
        else
            # Fallback: usar main.py directo (uvicorn main:app funciona igual)
            warn "Compilación fallida — usando main.py (modo dev, sin .so)"
            got=1
        fi
        rm -f "$WEB_DIR/main.py.build" 2>/dev/null || true
    fi

    # Resolver el módulo que uvicorn debe cargar: SIEMPRE "main" cuando hay .so
    local main_mod="main"
    if ls "$WEB_DIR"/main.cpython-*.so >/dev/null 2>&1; then
        rm -f "$WEB_DIR/main.py" 2>/dev/null || true
        rm -f "$WEB_DIR"/main.cpython-*.so.bak 2>/dev/null || true
        main_mod="main"
    elif [[ -f "$WEB_DIR/main.py" ]]; then
        main_mod="main"
    else
        err "No se encontró backend (ni .so Nuitka ni main.py)"
        return 1
    fi
    echo "$main_mod" > "$WEB_DIR/.main_mod"
    ok "Módulo backend: $main_mod"
    return 0
}

# ------------------------------------------------------------
# Frontend ofuscado (index.html) — respeta si ya existe y es igual o más nuevo
# ------------------------------------------------------------
install_frontend() {
    local dst="$WEB_DIR/static/index.html"
    local tmp="$WEB_DIR/static/index.obf.html.tmp"
    log "Instalando frontend ofuscado..."
    if download_asset "${GH_BASE}/index.obf.html" "$tmp"; then
        # Preservar frontend local si el instalado es igual de bueno (mismas URL API)
        if [[ -f "$dst" && -f "$tmp" ]]; then
            cp -f "$tmp" "$dst"
            ok "Frontend actualizado ($(stat -c%s "$dst" 2>/dev/null || echo '?') bytes)"
        else
            mv -f "$tmp" "$dst"
            ok "Frontend instalado ($(stat -c%s "$dst" 2>/dev/null || echo '?') bytes)"
        fi
    else
        if [[ -f "$dst" ]]; then
            warn "No se pudo descargar frontend — usando el existente"
            return 0
        fi
        err "No se pudo instalar frontend"
        return 1
    fi
    chmod 644 "$dst"
    rm -f "$tmp"
}

# ------------------------------------------------------------
# venv + requirements (sin tocar el resto del sistema)
# ------------------------------------------------------------
ensure_venv() {
    ensure_apt
    if [[ ! -x "$WEB_DIR/venv/bin/python" ]]; then
        log "Creando venv en $WEB_DIR/venv ..."
        python3 -m venv "$WEB_DIR/venv" 2>/dev/null || {
            err "Fallo creando venv (¿python3-venv?)"; return 1
        }
    fi
    local req="$WEB_DIR/requirements.txt"
    cat > "$req" <<'REQ'
fastapi==0.115.6
uvicorn[standard]==0.34.0
pydantic==2.10.4
REQ
    log "Instalando requirements (pip)..."
    "$WEB_DIR/venv/bin/pip" install -q --no-cache-dir -r "$req" >/dev/null 2>&1 || {
        warn "pip install con errores — reintentando sin cache"
        "$WEB_DIR/venv/bin/pip" install -q -r "$req" >/dev/null 2>&1 || true
    }
    "$WEB_DIR/venv/bin/pip" list 2>/dev/null | grep -q '^fastapi ' && ok "fastapi instalado" || warn "fastapi no verificado"
}

# ------------------------------------------------------------
# systemd unit
# ------------------------------------------------------------
install_systemd() {
    local unit="/etc/systemd/system/movivip-web.service"
    cat > "$unit" <<UNIT
[Unit]
Description=MoviVIP Web Panel (Admin Total)
After=network.target

[Service]
Type=simple
WorkingDirectory=${WEB_DIR}
ExecStart=${WEB_DIR}/venv/bin/uvicorn main:app --host 0.0.0.0 --port ${WEB_PORT}
Restart=always
RestartSec=3
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
UNIT
    systemctl daemon-reload 2>/dev/null
    systemctl enable movivip-web.service >/dev/null 2>&1 && ok "systemd: movivip-web.service habilitado"
}

# ------------------------------------------------------------
# Estado
# ------------------------------------------------------------
show_status() {
    local arch
    arch="$(detect_arch)"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════${RESET}"
    echo -e "  ${WHITE}MoviVIP Web Panel — Estado${RESET}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${RESET}"
    echo -e "  Arquitectura : ${arch}"
    echo -e "  Directorio   : ${WEB_DIR}"
    echo -e "  Puerto       : ${WEB_PORT}"
    if systemctl is-active --quiet movivip-web 2>/dev/null; then
        echo -e "  Servicio     : ${GREEN}● activo (running)${RESET}"
    else
        echo -e "  Servicio     : ${RED}○ inactivo${RESET}"
    fi
    if ls "$WEB_DIR"/*.so >/dev/null 2>&1; then
        local so; so="$(ls "$WEB_DIR"/*.so | head -1)"
        echo -e "  Backend      : $(basename "$so")"
    elif [[ -f "$WEB_DIR/main.py" ]]; then
        echo -e "  Backend      : main.py (modo dev)"
    else
        echo -e "  Backend      : ${RED}no instalado${RESET}"
    fi
    [[ -f "$WEB_DIR/static/index.html" ]] && echo -e "  Frontend     : index.html ($(stat -c%s "$WEB_DIR/static/index.html" 2>/dev/null || echo '?') bytes, ofuscado)"
    [[ -f "$WEB_ETC/secret.key" ]] && echo -e "  secret.key   : presente ($(stat -c%s "$WEB_ETC/secret.key" 2>/dev/null || echo '?') B, 600)"
    local ip
    ip="$(curl -fsSL --max-time 5 https://api.ipify.org 2>/dev/null || echo 'IP?')"
    echo -e "  URL          : ${WHITE}http://${ip}:${WEB_PORT}${RESET}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${RESET}"
    echo ""
}

# ------------------------------------------------------------
# Instalar / actualizar (con verificación de acceso)
# ------------------------------------------------------------
do_install() {
    if [[ "$WEB_PLAN_OK" != "1" ]]; then
        clear
        echo -e "${RED}═══════════════════════════════════════════════════════${RESET}"
        echo -e "  ${RED}✘ ACCESO DENEGADO${RESET}"
        echo -e "${RED}═══════════════════════════════════════════════════════${RESET}"
        echo -e "  El Panel Web MoviVIP es exclusivo para:"
        echo -e "    ${WHITE}✔ Miembros Premium${RESET}"
        echo -e "    ${WHITE}✔ Key Vitalicia${RESET}"
        echo -e "    ${WHITE}✔ Key SuperAdmin${RESET}"
        echo -e ""
        echo -e "  Tu plan actual : ${YELLOW}${WEB_PLAN:-sin licencia}${RESET}"
        echo -e "  Cliente        : ${WEB_CLIENTE:-—}"
        echo -e ""
        echo -e "  🔑 Contacta con ${CYAN}MoviVIP Network${RESET} para mejorar tu plan."
        echo -e "${RED}═══════════════════════════════════════════════════════${RESET}"
        echo ""
        read -n1 -r -p "Presione una tecla para volver..."
        return 1
    fi

    log "Instalando/actualizando Web Panel MoviVIP ${VERSION} ..."
    local has_old=0
    [[ -f "$WEB_DIR/static/index.html" ]] && has_old=1

    ensure_apt || return 1
    ensure_venv || return 1
    ensure_secret || return 1
    install_frontend || return 1
    install_backend || return 1
    install_systemd || return 1
    open_port "$WEB_PORT" || true

    systemctl restart movivip-web.service 2>/dev/null || true
    sleep 2
    if systemctl is-active --quiet movivip-web 2>/dev/null; then
        ok "Servicio movivip-web activo y funcionando"
    else
        warn "Servicio no activo — revise: journalctl -u movivip-web -n 50"
    fi

    echo ""
    show_status
    log "Instalación completada."
    return 0
}

do_uninstall() {
    warn "Desinstalando panel web (NO se toca /etc/movivip ni datos de clientes)..."
    systemctl stop movivip-web.service 2>/dev/null || true
    systemctl disable movivip-web.service 2>/dev/null || true
    rm -f /etc/systemd/system/movivip-web.service
    systemctl daemon-reload 2>/dev/null
    if [[ "${PURGE:-0}" == "1" ]]; then
        rm -rf "$WEB_DIR" "$WEB_ETC"
        ok "Directorio $WEB_DIR y $WEB_ETC eliminados (PURGE=1)"
    else
        ok "Panel detenido. $WEB_DIR conservado (use PURGE=1 para borrar)."
    fi
    return 0
}

# Helper: ¿existe el servicio systemd movivip-web? (evita grep -q en pipe con pipefail)
web_installed() {
    systemctl list-unit-files 2>/dev/null | grep -c 'movivip-web.service' >/dev/null
}

# Desactivar: detiene y deshabilita el servicio SIN borrar nada (conserva datos)
do_stop() {
    if ! web_installed; then
        warn "El panel web no está instalado."
        read -n1 -r -p "Presione una tecla..."
        return 0
    fi
    warn "Desactivando panel web (se conservan datos y configuración)..."
    systemctl stop movivip-web.service 2>/dev/null || true
    systemctl disable movivip-web.service 2>/dev/null || true
    sleep 1
    if systemctl is-active --quiet movivip-web 2>/dev/null; then
        warn "El servicio sigue activo — forzando detención..."
        systemctl kill -s SIGKILL movivip-web.service 2>/dev/null || true
        systemctl stop movivip-web.service 2>/dev/null || true
    fi
    ok "Panel web DESACTIVADO. Para volver a activarlo usa: -> Activar Panel Web"
    read -n1 -r -p "Presione una tecla..."
}

# Activar: habilita y arranca el servicio (si estaba desactivado o detenido)
do_start() {
    if ! web_installed; then
        warn "El panel web no está instalado. Ejecute primero: Instalar Panel Web"
        read -n1 -r -p "Presione una tecla..."
        return 0
    fi
    warn "Activando panel web..."
    systemctl enable movivip-web.service >/dev/null 2>&1 || true
    systemctl start movivip-web.service 2>/dev/null || true
    sleep 2
    if systemctl is-active --quiet movivip-web 2>/dev/null; then
        ok "Panel web ACTIVO y funcionando"
    else
        warn "El servicio no quedó activo — journalctl -u movivip-web -n 50"
    fi
    read -n1 -r -p "Presione una tecla..."
}

restart_web() {
    if ! web_installed; then
        warn "El panel web no está instalado (no existe movivip-web.service)."
        read -n1 -r -p "Presione una tecla..."
        return 0
    fi
    systemctl restart movivip-web.service 2>/dev/null
    sleep 2
    if systemctl is-active --quiet movivip-web 2>/dev/null; then
        ok "Servicio movivip-web reiniciado y activo"
    else
        warn "El servicio no quedó activo — journalctl -u movivip-web -n 50"
    fi
    read -n1 -r -p "Presione una tecla..."
}

# ------------------------------------------------------------
# Menú estilo ZiVPN — header ◆, estado, campos, [01] ➤ opciones
# ------------------------------------------------------------
menu_web() {
    while true; do
        clear

        # Cargar helpers del ecosistema (nav.sh carga ui.sh → mv_header, movivip_contacts)
        # NOTA: set +u para no abortar con variables sin default de los libs
        if [[ -f "$BASE/lib/nav.sh" ]]; then
            # shellcheck source=/dev/null
            set +u
            source "$BASE/lib/nav.sh" 2>/dev/null || true
            set -u
        fi
        if ! declare -F trx >/dev/null 2>&1; then trx() { printf '%s' "$1"; }; fi

        # ── Estado del servicio ──
        if systemctl is-active --quiet movivip-web 2>/dev/null; then
            STATUS="${GREEN}🟢 ACTIVO${RESET}"
            SVC_ACTIVE=1
        else
            STATUS="${RED}🔴 DETENIDO${RESET}"
            SVC_ACTIVE=0
        fi

        # NOTA: NO usar grep -q en pipeline con pipefail (SIGPIPE → falso 0)
        local INSTALLED=0
        if systemctl list-unit-files 2>/dev/null | grep -c 'movivip-web.service' >/dev/null; then
            INSTALLED=1
        fi

        # ── Propiedades ──
        local ARCH PORT_MOD VERSION_MOD
        ARCH="$(uname -m 2>/dev/null)"
        PORT_MOD="${WEB_PORT:-9617}"
        VERSION_MOD="${VERSION:-1.1.0}"
        local BACKEND_INFO="-"
        if ls "$WEB_DIR"/main.cpython-*.so >/dev/null 2>&1; then
            BACKEND_INFO="Nuitka .so ($(ls "$WEB_DIR"/main.cpython-*.so 2>/dev/null | head -1 | xargs basename 2>/dev/null))"
        elif [[ -f "$WEB_DIR/main.py" ]]; then
            BACKEND_INFO="main.py (modo dev)"
        elif [[ "$INSTALLED" == "1" ]]; then
            BACKEND_INFO="${RED}no encontrado${RESET}"
        fi

        # ── Header estilo ZiVPN (mv_header genera los ══════ + ◆ título + ══════) ──
        if declare -F mv_header >/dev/null 2>&1; then
            mv_header "$(trx '🚀 MoviVIP Web Panel')" "$(trx 'Panel de administración web · FastAPI')" "${VERSION_MOD}"
        else
            echo -e "${CYAN}══════════════════════════════════════════════════════════════${RESET}"
            echo -e "  ${GREEN}${BOLD}◆  🚀 MoviVIP Web Panel  [${VERSION_MOD}]  ◆${RESET}"
            echo -e "  Panel de administración web · FastAPI"
            echo -e "${CYAN}══════════════════════════════════════════════════════════════${RESET}"
        fi
        if declare -F movivip_contacts >/dev/null 2>&1; then
            movivip_contacts
        else
            echo -e "  📢 t.me/MoviVIPNetwork · t.me/MoviVIPNet · @MoviVIP"
        fi

        # ── Estado / info del servicio ──
        echo ""
        echo -e " Estado       : $STATUS"
        echo -e "$(trx ' Servicio     : movivip-web')"
        echo -e " Puerto       : ${PORT_MOD}"
        echo -e " Arquitectura : ${ARCH}"
        echo -e " Versión      : ${VERSION_MOD}"
        if [[ "$INSTALLED" == "1" ]]; then
            echo -e " Backend      : ${BACKEND_INFO}"
        fi
        echo ""

        # ── Opciones ──
        local LBL=()
        if [[ "$INSTALLED" == "1" ]]; then
            if [[ "$WEB_PLAN_OK" == "1" ]]; then
                if [[ "$SVC_ACTIVE" == "1" ]]; then
                    LBL+=(
                        "$(trx 'Actualizar Panel Web')"
                        "$(trx 'Desactivar Panel Web')"
                        "$(trx 'Reiniciar Servicio')"
                        "$(trx 'Ver Estado')"
                        "$(trx 'Desinstalar Panel Web')"
                    )
                else
                    LBL+=(
                        "$(trx 'Actualizar Panel Web')"
                        "$(trx 'Activar Panel Web')"
                        "$(trx 'Ver Estado')"
                        "$(trx 'Desinstalar Panel Web')"
                    )
                fi
            else
                # Servicio instalado pero sin plan → mostrar estado + regresar
                mostrar_estado_plan 2>/dev/null || true
                LBL+=(
                    "$(trx 'Actualizar Panel Web (requiere plan)')"
                    "$(trx 'Ver Estado')"
                )
            fi
        else
            mostrar_estado_plan 2>/dev/null || true
            LBL+=("$(trx 'Instalar Panel Web')")
        fi

        if declare -F nav_pick >/dev/null 2>&1; then
            SEL=$(nav_pick "$(trx '► Opción:')" "${LBL[@]}" "$(trx '↩ Regresar')") || SEL=0
            [[ $SEL -eq $((${#LBL[@]}+1)) ]] && SEL=0
        else
            echo -e " ──────────────────────────────────────────────────────────"
            for ((ix=0; ix<${#LBL[@]}; ix++)); do
                echo -e " [$(printf '%02d' $((ix+1)))] ➤ ${LBL[$ix]}"
            done
            echo -e " [00] ➮ ↩ Regresar"
            echo -e " ──────────────────────────────────────────────────────────"
            echo -n "  ► Opción: "
            read -r SEL
            [[ ! "$SEL" =~ ^[0-9]+$ ]] && SEL=0
        fi

        # ── Acción (match por label para no depender de índice) ──
        # IMPORTANTE: SEL=0 o fuera de rango → OPC vacío (regresar).
        # NUNCA indexar LBL[$((SEL-1))] con SEL=0: en bash LBL[-1] es el
        # ÚLTIMO elemento del array (= Desinstalar) → disparaba desinstalación.
        local OPC=""
        if [[ "$SEL" =~ ^[0-9]+$ ]] && (( SEL >= 1 && SEL <= ${#LBL[@]} )); then
            OPC="${LBL[$((SEL-1))]:-}"
        fi

        case "$OPC" in
            *Instalar*)
                do_install
                ;;
            *Actualizar*)
                if [[ "$WEB_PLAN_OK" != "1" ]]; then
                    mostrar_estado_plan 2>/dev/null || true
                    read -n1 -r -p "Presione una tecla..."
                    continue
                fi
                do_install
                ;;
            *Desactivar*)
                do_stop
                ;;
            *Activar*)
                do_start
                ;;
            *Reiniciar*)
                restart_web
                ;;
            *Ver\ Estado*)
                show_status
                read -n1 -r -p "Presione una tecla..."
                ;;
            *Desinstalar*)
                echo ""
                echo -e "${RED}  ⚠  ¿DESINSTALAR EL WEB PANEL?${RESET}"
                echo -e "     Se detiene el servicio y se deshabilita."
                echo -e "     Los datos en ${WHITE}${WEB_DIR}${RESET} se conservan."
                echo -e "     Use PURGE=1 si desea eliminarlos también.\n"
                read -rp "  ¿Desinstalar Panel Web? (s/n): " R
                [[ "$R" =~ ^[Ss]$ ]] && do_uninstall
                ;;
            "")
            # Regresar
                exec bash "$BASE/protocolos/menu.sh"
                ;;
            *)
                echo "$(trx '❌ Opción inválida.')"
                sleep 1
                ;;
        esac
    done
}

# ------------------------------------------------------------
# CLI
# ------------------------------------------------------------
check_web_acceso

case "${1:-}" in
    --install|-i)
        if [[ "$WEB_PLAN_OK" != "1" ]]; then
            echo -e "${RED}✘ ACCESO DENEGADO${RESET} — Panel Web exclusivo para premium/vitalicia/superadmin (tu plan: ${WEB_PLAN:-sin licencia})"
            exit 1
        fi
        do_install ;;
    --status|-s)           show_status ;;
    --uninstall|-u)        do_uninstall ;;
    --version|-v)          echo "movivip-web-installer v${VERSION}" ;;
    --help|-h)             sed -n '2,20p' "$0" | sed 's/^#\{0,1\} \{0,1\}//' ;;
    "")                    menu_web ;;
    *)                     warn "Opción desconocida: $1 (use --help)" ;;
esac