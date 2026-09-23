#!/bin/bash

# ── i18n shim (auto) ───────────────────────────────
if ! declare -F trx >/dev/null 2>&1; then trx() { printf '%s' "$1"; }; fi
# ─────────────────────────────────────────────────────────

# ═══════════════════════════════════════════════════════
# HCR MANAGER — HTTP(S) SSH Relay  (estilo MoviVIP)
# ═══════════════════════════════════════════════════════
# • Relé de OpenSSH (127.0.0.1:22) sobre HTTP (HTTP Core Relay)
# • HCR corre en PLAIN interno (127.0.0.1:8880)
# • El handshake TLS lo hace HAPROXY (443, yha.pem, SNI "hcr")
#   → app SSL/TLS 443 con SNI hcr → haproxy → HCR plain → SSH 22
# ═══════════════════════════════════════════════════════

BASE="/etc/movivip"
CONFIG="$BASE/config.conf"

source "$CONFIG"

# 🌐 Multi-idioma
if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)"
fi
if [[ -f "$BASE/languages/protocols.sh" ]]; then
    source "$BASE/languages/protocols.sh"
fi

CYAN="${MV_CYN:-\e[1;96m}"
GREEN="${MV_GRN:-\e[1;92m}"
RED="${MV_RED:-\e[1;91m}"
WHITE="${MV_WHT:-\e[1;97m}"
YELLOW="${MV_YLW:-\e[1;93m}"
GRAY="${MV_DIM:-\e[1;90m}"
RESET="${MV_R:-\e[0m}"

SERVICE="hcr"
BIN="/usr/local/bin/hcr"
HCR_PORT="${HCR_PORT:-8880}"          # puerto interno PLAIN
HCR_TRANSPORT="${HCR_TRANSPORT:-plain}"  # haproxy hace el TLS
HCR_TARGET="${HCR_TARGET:-127.0.0.1:22}"
HCR_SNI="${HCR_SNI:-hcr}"             # SNI que enruta haproxy → hcr
HAPROXY_CFG="/etc/haproxy/haproxy.cfg"

# ── Detección de arquitectura (multi-arch: amd64/arm64/armv7/386) ──
detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64)            echo "amd64" ;;
        aarch64|arm64)           echo "arm64" ;;
        armv7l|armv7|armhf)      echo "armv7" ;;
        i386|i686|x86|i486|i586) echo "386" ;;
        *)                       echo "amd64" ;;
    esac
}
HCR_ARCH="$(detect_arch)"

# Navegación con flechitas
[[ -f "$BASE/lib/nav.sh" ]] && source "$BASE/lib/nav.sh"

# Sistema de animación/progreso + detección de estado
[[ -f "$BASE/lib/anim.sh" ]] && source "$BASE/lib/anim.sh"

_hcr_vps_ip() {
    local IP
    IP=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
    [[ -z "$IP" ]] && IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    echo "${IP:-127.0.0.1}"
}

# ── Buscar el binario correcto para la arquitectura del VPS ──
_hcr_has_bin() {
    [[ -x "$BIN" ]] && return 0
    local pkg_dir="$BASE/protocolos" repo_dir="/root/scrip_vps_todo/protocolos"
    local src
    # 1) Binario específico de la arquitectura (hcr-amd64, hcr-arm64, hcr-armv7, hcr-386)
    for src in "$pkg_dir/hcr-$HCR_ARCH" "$repo_dir/hcr-$HCR_ARCH"; do
        if [[ -f "$src" ]]; then
            cp "$src" "$BIN" && chmod +x "$BIN" && return 0
        fi
    done
    # 2) Binario genérico del paquete (alias — actualmente amd64)
    for src in "$pkg_dir/hcr" "$repo_dir/hcr"; do
        if [[ -f "$src" ]]; then
            cp "$src" "$BIN" && chmod +x "$BIN" && return 0
        fi
    done
    return 1
}

# ── Insertar bloque HCR en haproxy — TODOS los frontends públicos ──
# enruta el SNI "hcr" en cualquier puerto que maneje haproxy (80/443/8080/8443, etc.)
_hcr_haproxy_configure() {
    cp "$HAPROXY_CFG" "${HAPROXY_CFG}.bak-hcr"
    # 1) Backend → HCR plain local (una sola vez)
    if ! grep -q 'backend hcr_backend' "$HAPROXY_CFG" 2>/dev/null; then
        cat >> "$HAPROXY_CFG" <<EOF

backend hcr_backend
    mode tcp
    server hcr_local 127.0.0.1:$HCR_PORT check
EOF
    fi
    # 2) Insertar ACL SNI + use_backend en CADA frontend con bind público
    #    (excluye binds internos abns@). Idempotente: no duplica si ya existe.
    local done_list
    done_list=$(awk '
        /^frontend /{fr=$2; acl=0}
        fr!="" && /acl acl_sni_hcr/{acl=1}
        /^backend /{if(fr!="" && acl) print fr; fr=""}
        END{if(fr!="" && acl) print fr}
    ' "$HAPROXY_CFG" | tr '\n' ' ')
    awk -v sni="$HCR_SNI" -v done="$done_list" '
        function is_done(f){ for(i in d) if(d[i]==f) return 1; return 0 }
        function emit(){ if(fr!="" && fpub && !fin && !is_done(fr)){
            print "    acl acl_sni_hcr req.ssl_sni -i " sni
            print "    use_backend hcr_backend if acl_sni_hcr"
            fin=1 } }
        BEGIN{ n=split(done, d, " ") }
        /^frontend /{ emit(); fr=$2; fpub=0; fin=0; print; next }
        fr!="" && /^[[:space:]]*bind/ && $0 !~ /abns@/ { fpub=1 }
        fr!="" && /^[[:space:]]*default_backend/ { emit() }
        /^backend /{ emit(); if($1=="backend") fr=""; print; next }
        { print }
        END{ emit() }
    ' "$HAPROXY_CFG" > "${HAPROXY_CFG}.hcr.new" && mv "${HAPROXY_CFG}.hcr.new" "$HAPROXY_CFG"
    haproxy -c -f "$HAPROXY_CFG" >/dev/null 2>&1 || { echo "$(trx '❌ haproxy.cfg inválido tras insertar HCR')"; mv "${HAPROXY_CFG}.bak-hcr" "$HAPROXY_CFG" 2>/dev/null; return 1; }
    systemctl reload haproxy 2>/dev/null || systemctl restart haproxy
    sleep 1
    return 0
}

# ── Revertir bloque HCR del haproxy ──
_hcr_haproxy_revert() {
    if grep -q 'backend hcr_backend' "$HAPROXY_CFG" 2>/dev/null; then
        cp "$HAPROXY_CFG" "${HAPROXY_CFG}.bak-hcr"
        sed -i '/acl acl_sni_hcr req.ssl_sni/d;/use_backend hcr_backend if acl_sni_hcr/d' "$HAPROXY_CFG"
        # Borrar bloque backend desde su cabecera hasta el próximo "backend " o fin
        awk '
            BEGIN{del=0}
            /^backend hcr_backend/{del=1; next}
            del && /^backend /{del=0}
            !del{print}
        ' "$HAPROXY_CFG" > "${HAPROXY_CFG}.tmp" && mv "${HAPROXY_CFG}.tmp" "$HAPROXY_CFG"
        haproxy -c -f "$HAPROXY_CFG" >/dev/null 2>&1 || { echo "$(trx '❌ haproxy.cfg inválido tras quitar HCR')"; return 1; }
        systemctl reload haproxy 2>/dev/null || systemctl restart haproxy
    fi
    return 0
}

install_hcr() {

clear
mv_brand_header "INSTALANDO HCR SSH RELAY"
anim_init 6

anim_step "Verificando binario (${HCR_ARCH})"
if ! _hcr_has_bin; then
    echo -e "${RED}❌ No se encontró el binario HCR para ${HCR_ARCH} en el paquete.${RESET}"
    echo -e "${GRAY}   Espere protocolos/hcr-${HCR_ARCH} o el genérico protocolos/hcr${RESET}"
    sleep 3
    return 1
fi

anim_step "Verificando haproxy"
if ! systemctl is-active --quiet haproxy; then
    echo -e "${RED}❌ haproxy no está activo — instale primero SSL/TLS (ssl.sh).${RESET}"
    sleep 3
    return 1
fi

# Abrir puerto interno (solo loopback, haproxy es quien publica)
anim_run "Abrir puerto interno" bash -c "iptables -C INPUT -p tcp --dport $HCR_PORT -s 127.0.0.1 -j ACCEPT 2>/dev/null || iptables -A INPUT -p tcp --dport $HCR_PORT -s 127.0.0.1 -j ACCEPT"

anim_step "Creando servicio HCR (plain interno)"

cat > /etc/systemd/system/$SERVICE.service <<EOF
[Unit]
Description=HCR HTTP(S) SSH Relay - MoviVIP (haproxy TLS)
After=network.target

[Service]
Type=simple
ExecStart=$BIN -listen 127.0.0.1:$HCR_PORT -transport $HCR_TRANSPORT -target $HCR_TARGET
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

anim_run "daemon-reload" systemctl daemon-reload
anim_run "Habilitar servicio" systemctl enable $SERVICE >/dev/null 2>&1
svc_restart_anim "$SERVICE" "Arrancando HCR Relay"

if ! systemctl is-active --quiet "$SERVICE"; then
    echo -e "${RED}❌ HCR no arrancó.${RESET}"
    journalctl -u $SERVICE -n 10 --no-pager 2>/dev/null | tail -5
    sleep 3
    return 1
fi

anim_step "Configurando haproxy (SNI $HCR_SNI → HCR)"
if ! _hcr_haproxy_configure; then
    systemctl stop $SERVICE 2>/dev/null
    return 1
fi

sed -i '/^HCR=/d' "$CONFIG"
echo "HCR=ON" >> "$CONFIG"
HCR="ON"

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}       ✅ HCR ACTIVADO (MoviVIP)${RESET}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo "🚀 Entrada pública : TCP (todos los puertos de haproxy: 80/443/8080/8443… TLS)"
echo "🔐 SNI            : $HCR_SNI"
echo "🔁 HCR interno    : 127.0.0.1:$HCR_PORT ($HCR_TRANSPORT · arch ${HCR_ARCH})"
echo "🎯 SSH objetivo   : $HCR_TARGET"
echo ""
echo "$(trx '📌 En la app usa:')"
echo "$(trx '   Método SSL/TLS + transporte HCR (HTTP Core Relay)')"
echo "   Host: $(_hcr_vps_ip) · Puerto: (cualquier puerto haproxy) · SNI: $HCR_SNI · User: (cuenta SSH)"
echo ""

sleep 3
}

remove_hcr() {

clear

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}        ELIMINAR HCR SSH RELAY${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

read -rp "$(trx '¿Seguro que deseas eliminar HCR? (s/n): ')" R

if [[ "$R" =~ ^[Ss]$ ]]; then

anim_init 4
anim_step "Desinstalando HCR"
anim_run "Detener y deshabilitar servicio" bash -c "systemctl stop $SERVICE 2>/dev/null; systemctl disable $SERVICE 2>/dev/null"
anim_run "Quitar bloque haproxy" _hcr_haproxy_revert
anim_run "Eliminar archivos" bash -c "rm -f /etc/systemd/system/$SERVICE.service \"$BIN\"; rm -f /etc/haproxy/haproxy.cfg.bak-hcr"

anim_run "daemon-reload" systemctl daemon-reload

iptables -D INPUT -p tcp --dport "$HCR_PORT" -s 127.0.0.1 -j ACCEPT 2>/dev/null
sed -i '/^HCR=/d' "$CONFIG"
echo "HCR=OFF" >> "$CONFIG"
HCR="OFF"

echo ""
echo "$(trx '✅ HCR eliminado.')"

else
echo "$(trx '❌ Cancelado.')"
fi

sleep 3
}

restart_hcr() {
    clear
    svc_restart_anim "$SERVICE" "Reiniciando HCR Relay"
    sleep 2
}

status_hcr() {

clear

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}        ESTADO HCR SSH RELAY${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

systemctl status $SERVICE --no-pager

echo ""
echo "$(trx 'HCR interno (plain):')"
ss -ltnp | grep ":$HCR_PORT " || echo "$(trx 'No escuchando')"
echo ""
echo "$(trx 'Arquitectura del binario:')"
file "$BIN" 2>/dev/null || echo "hcr-${HCR_ARCH}"
echo ""
echo "$(trx 'Enrutamiento haproxy SNI (todos los frontends):')"
grep -n 'acl_sni_hcr\|use_backend hcr_backend' "$HAPROXY_CFG" 2>/dev/null | head -12
echo ""
echo "$(trx 'Backend haproxy (HCR local):')"
ss -ltnp | grep ":$HCR_PORT " || echo "$(trx 'HCR no escuchando')"

echo ""
read -n1 -r -p "$(trx 'Presione una tecla para continuar...')"
}

hcr_help() {
    cat <<'EOH'
Uso: hcr.sh [--install|--remove|--status|--restart|--help]

  --install   Instala HCR (plain interno) y enruta el SNI "hcr" en TODOS los puertos de haproxy (80/443/8080/8443…)
  --remove    Desinstala HCR y revierte haproxy
  --status    Muestra estado
  --restart   Reinicia el servicio
  --help      Esta ayuda
EOH
}

# ── CLI headless ──
case "${1:-}" in
    --install)
        export MOVIVIP_CLI=1
        HCR_PORT="${HCR_PORT:-8880}"
        HCR_TRANSPORT="${HCR_TRANSPORT:-plain}"
        HCR_SNI="${HCR_SNI:-hcr}"
        install_hcr
        exit $?
        ;;
    --remove)
        HCR="ON"
        remove_hcr
        exit $?
        ;;
    --status)
        status_hcr
        exit 0
        ;;
    --restart)
        restart_hcr
        exit 0
        ;;
    --help|-h)
        hcr_help
        exit 0
        ;;
    "")
        ;;
    *)
        echo "$(trx '❌ Opción desconocida.')"
        hcr_help
        exit 1
        ;;
esac

# ── Menú interactivo ──
while true; do

clear

source "$CONFIG"

if [[ "$HCR" == "ON" ]]; then
    STATUS="${GREEN}🟢 ACTIVO${RESET}"
else
    STATUS="${RED}🔴 DESINSTALADO${RESET}"
fi

mv_header "🚀 HCR Relay" "$(trx 'HTTP Core Relay · haproxy multi-puerto TLS · SNI hcr')" "v1"
movivip_contacts 2>/dev/null || true

echo -e " Estado       : $STATUS"
echo -e " Entrada      : TCP (todos los puertos haproxy · SNI $HCR_SNI)"
echo -e " HCR interno  : 127.0.0.1:$HCR_PORT ($HCR_TRANSPORT)"
echo -e " Arquitectura : hcr-${HCR_ARCH} (amd64/arm64/armv7/386)"
echo -e " SSH objetivo : $HCR_TARGET"
echo ""

if [[ "$HCR" == "ON" ]]; then
    LBL=("Reinstalar HCR" "Reiniciar Servicio" "Ver Estado" "Ver Datos de Conexión" "Desinstalar")
else
    LBL=("Instalar HCR")
fi
SEL=$(nav_pick "► Opción:" "${LBL[@]}" "↩ Regresar") || SEL=0
[[ $SEL -eq $((${#LBL[@]}+1)) ]] && SEL=0
OP="$SEL"

case "$OP" in
1)
    install_hcr
    ;;
2)
    restart_hcr
    ;;
3)
    status_hcr
    ;;
4)
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}        📱 DATOS HCR (MoviVIP)${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    echo -e "${GREEN}📲 Cómo conectarse:${RESET}"
    echo -e "   Método     : SSL/TLS + transporte HCR (HTTP Core Relay)"
    echo -e "   Host       : $(_hcr_vps_ip)"
    echo -e "   Puerto     : (cualquier puerto haproxy: 80/443/8080/8443…)"
    echo -e "   SNI        : $HCR_SNI"
    echo -e "   User/Pass  : una cuenta SSH del sistema"
    echo ""
    echo -e "${GRAY}Nota: haproxy termina el TLS (cert yha.pem) y reenvía${RESET}"
    echo -e "${GRAY}descifrado a HCR plain ($HCR_PORT) → OpenSSH (22).${RESET}"
    echo -e "${GRAY}Las cuentas se crean igual que las SSH normales.${RESET}"
    echo ""
    read -n1 -r -p "$(trx 'Presione una tecla para continuar...')"
    ;;
5)
    remove_hcr
    ;;
0)
    exec bash "$BASE/protocolos/menu.sh"
    ;;
*)
    echo "$(trx '❌ Opción inválida.')"
    sleep 2
    ;;
esac

done