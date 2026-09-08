#!/bin/bash

# ── i18n shim (auto) ───────────────────────────────
if ! declare -F trx >/dev/null 2>&1; then trx() { printf '%s' "$1"; }; fi
# ─────────────────────────────────────────────────────────

#==================================================
# MoviVIP Network Premium
# SOCKS5 Proxy Manager v1 (estilo MoviVIP)
# Servidor SOCKS5 con dante-server + usuarios del
# sistema (login con shell nologin).
#
# • Puerto   : TCP 1080 (configurable SOCKS5_PORT)
# • Método   : username (PAM del sistema)
# • Usuarios : cuentas Linux (useradd + chpasswd)
#==================================================

BASE="/etc/movivip"
CONFIG="$BASE/config.conf"

[[ -f "$CONFIG" ]] || {
    echo "❌ No existe $CONFIG"
    exit 1
}

source "$CONFIG"

# Cargar idioma
if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)"
fi

# Sistema de animación/progreso
[[ -f "$BASE/lib/anim.sh" ]] && source "$BASE/lib/anim.sh"

CYAN="\e[1;96m"
GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"
RESET="\e[0m"

SOCKS5_PORT="${SOCKS5_PORT:-1080}"
SOCKS5_USER_PREFIX="${SOCKS5_USER_PREFIX:-}"

# Detectar binario real de dante (Ubuntu 22.04+ usa danted; otros sockd)
SOCKS5_BIN=""
for B in danted sockd; do
    C=$(command -v "$B" 2>/dev/null) || continue
    SOCKS5_BIN="$C"
    break
done
[[ -z "$SOCKS5_BIN" && -x /usr/sbin/danted ]] && SOCKS5_BIN=/usr/sbin/danted
[[ -z "$SOCKS5_BIN" && -x /usr/sbin/sockd ]] && SOCKS5_BIN=/usr/sbin/sockd
SOCKS5_BIN="${SOCKS5_BIN:-/usr/sbin/danted}"

# Función: estado
STATE() { systemctl is-active --quiet "$1" && echo "${GREEN}🟢${RESET}" || echo "${RED}🔴${RESET}"; }

#==================================================
# Instalar dependencias
#==================================================

install_dependencies(){

    anim_step "$(trx 'Instalando dependencias')"
    anim_run "apt update" apt update -y
    anim_run "$(trx 'Instalar dante-server')" apt install -y dante-server

    if [[ -z "$SOCKS5_BIN" ]] || [[ ! -x "$SOCKS5_BIN" ]]; then
        echo "$(trx '❌ No se encontró dante (sockd/danted).')"
        return 1
    fi
    return 0
}

#==================================================
# Crear configuración dante
#==================================================

create_sockd_conf(){

    IFACE=$(ip route get 8.8.8.8 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')
    [[ -z "$IFACE" ]] && IFACE="eth0"
    EXTERNAL_IP=$(hostname -I | awk '{print $1}')

    mkdir -p /etc/dante
    cat > /etc/dante/sockd.conf <<CONFEOF
# MoviVIP Network — SOCKS5 (dante)
logoutput: /var/log/sockd.log
internal: $IFACE port = $SOCKS5_PORT
external: $IFACE

socksmethod: username
user.privileged: root
user.unprivileged: nobody
clientmethod: none

client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect error
}

socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    command: bind connect udpassociate
    log: connect disconnect error
}
CONFEOF

    chmod 644 /etc/dante/sockd.conf
}

#==================================================
# Abrir puertos
#==================================================

open_ports(){

    echo "$(trx '🛡 Abriendo puertos...')"

    iptables -C INPUT -p tcp --dport "$SOCKS5_PORT" -j ACCEPT 2>/dev/null \
        || iptables -A INPUT -p tcp --dport "$SOCKS5_PORT" -j ACCEPT

    if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
        ufw allow "$SOCKS5_PORT"/tcp >/dev/null 2>&1
    fi

    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4 2>/dev/null
}

#==================================================
# Crear/editar servicio systemd (fix dante)
#==================================================

create_service(){

    # El paquete dante trae unidad nativa (danted.service o sockd.service);
    # desactivarla para usar nuestra unidad custom con la config MoviVIP.
    systemctl disable --now danted 2>/dev/null
    systemctl disable --now sockd 2>/dev/null
    systemctl stop sockd 2>/dev/null
    cat > /etc/systemd/system/sockd.service <<SVCEOF
[Unit]
Description=SOCKS server (dante) - MoviVIP
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=forking
PIDFile=/run/sockd.pid
ExecStart=${SOCKS5_BIN} -f /etc/dante/sockd.conf -p /run/sockd.pid -D
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SVCEOF

    systemctl daemon-reload
    systemctl enable sockd >/dev/null 2>&1
    echo "$(trx '✅ Servicio SOCKS5 creado.')"
}

#==================================================
# Gestión de usuarios (cuentas Linux nologin)
#==================================================

_socks5_exists_user(){
    id "$1" >/dev/null 2>&1
}

add_user(){
    local USER="${1:-}" PASS="${2:-}"
    [[ -z "$USER" ]] && {
        read -rp "$(trx '👤 Usuario: ')" USER
    }
    USER=$(echo "$USER" | tr -d ' /:')
    [[ -z "$USER" ]] && { echo "$(trx '❌ Usuario inválido.')"; return 1; }

    if _socks5_exists_user "$USER"; then
        echo -e "${YELLOW}⚠️  El usuario del sistema '$USER' ya existe.${RESET}"
        read -rp "$(trx '¿Eliminar y recrear? (s/n): ')" R
        [[ ! "$R" =~ ^[Ss]$ ]] && return 1
        userdel -f "$USER" >/dev/null 2>&1
    fi

    if [[ -z "$PASS" ]]; then
        read -rsp "$(trx '🔑 Contraseña: ')" PASS
        echo ""
        [[ -z "$PASS" ]] && { echo "$(trx '❌ Contraseña vacía.')"; return 1; }
    fi

    # Cuenta sin shell (solo SOCKS5), sin home ni login SSH
    useradd -M -s /usr/sbin/nologin "$USER" 2>/dev/null \
        || useradd -M -s /bin/false "$USER" 2>/dev/null \
        || { echo "$(trx '❌ No se pudo crear el usuario.')"; return 1; }
    echo "$USER:$PASS" | chpasswd

    echo ""
    echo -e "${GREEN}✅ Usuario SOCKS5 '$USER' creado.${RESET}"
    VPS_IP=$(hostname -I | awk '{print $1}')
    echo -e "📲 Conexión: ${WHITE}IP $VPS_IP · Puerto $SOCKS5_PORT · login ${USER}${RESET}"
    echo -e "   ${GRAY}Apps: HTTP Injector (proxy SOCKS5), Orbot, ProxyDroid, apps con proxy SOCKS.${RESET}"
    return 0
}

remove_user(){
    local USER="${1:-}"
    [[ -z "$USER" ]] && {
        read -rp "$(trx '👤 Usuario a eliminar: ')" USER
    }
    if ! _socks5_exists_user "$USER"; then
        echo -e "${YELLOW}⚠️  '$USER' no existe en el sistema.${RESET}"
        sleep 2
        return 1
    fi

    userdel -f "$USER" >/dev/null 2>&1
    echo -e "${GREEN}✅ Usuario SOCKS5 '$USER' eliminado.${RESET}"
    sleep 2
    return 0
}

list_users(){
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}         👥 USUARIOS SOCKS5${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    # Usuarios con shell nologin/false (los de SOCKS5)
    FOUND=0
    while IFS=: read -r U _ _ _ _ SH; do
        case "$SH" in
            /usr/sbin/nologin|/bin/false|/sbin/nologin)
                echo -e "  ${GREEN}●${RESET} $U"
                FOUND=$((FOUND+1))
                ;;
        esac
    done < /etc/passwd
    [[ "$FOUND" -eq 0 ]] && echo "$(trx 'No hay usuarios SOCKS5.')"
    echo ""
    read -n1 -r -p "$(trx 'Presione una tecla...')"
}

#==================================================
# Test funcional
#==================================================

test_socks5(){

    echo ""
    echo "$(trx '🧪 Verificando servidor SOCKS5...')"

    if systemctl is-active --quiet sockd; then
        echo "$(trx '✅ El servidor SOCKS5 está ACTIVO.')"
        return 0
    fi

    echo "$(trx '⚠️  SOCKS5 no está activo.')"
    journalctl -u sockd -n 15 --no-pager 2>/dev/null | tail -10
    return 1
}

#==================================================
# Instalar SOCKS5
#==================================================

install_socks5(){

    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}        🐋 INSTALAR SOCKS5${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    anim_init 5
    anim_step "$(trx 'Instalando dependencias')"
    install_dependencies || return

    anim_step "$(trx 'Creando configuración dante')"
    create_sockd_conf

    anim_step "$(trx 'Creando servicio systemd')"
    create_service

    anim_step "$(trx 'Abriendo puertos')"
    open_ports

    echo ""
    anim_step "$(trx 'Iniciando servicio')"
    systemctl restart sockd
    svc_restart_anim "sockd" "$(trx 'Arrancando') sockd" 2>/dev/null

    if systemctl is-active --quiet sockd; then

        sed -i '/^SOCKS5=/d' "$CONFIG"
        echo "SOCKS5=ON" >> "$CONFIG"
        source "$CONFIG"

        VPS_IP=$(hostname -I | awk '{print $1}')

        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "$(trx '      ✅ SOCKS5 INSTALADO')"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "🌍 IP     : $VPS_IP"
        echo "🚀 Puerto : TCP $SOCKS5_PORT"
        echo "🔑 Auth   : usuario + contraseña"
        echo ""
        echo "$(trx '  Crea usuarios desde el menú:')"
        echo "  📌 Protocolos → SOCKS5 → [2] Agregar usuario"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
    else
        echo ""
        echo "$(trx '❌ Error iniciando SOCKS5')"
        journalctl -u sockd -n 15 --no-pager 2>/dev/null | tail -10
    fi

    sleep 4
}

#==================================================
# Eliminar SOCKS5
#==================================================

remove_socks5(){

    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}        🗑 ELIMINAR SOCKS5${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    read -rp "$(trx '¿Eliminar SOCKS5? (s/n): ')" R
    [[ ! "$R" =~ ^[Ss]$ ]] && return

    anim_step "$(trx 'Desinstalando SOCKS5')"

    anim_run "$(trx 'Detener servicio')" bash -c "systemctl stop sockd 2>/dev/null; systemctl disable sockd 2>/dev/null"
    anim_run "$(trx 'Eliminar unidad')" rm -f /etc/systemd/system/sockd.service
    anim_run "daemon-reload" systemctl daemon-reload

    iptables -D INPUT -p tcp --dport "$SOCKS5_PORT" -j ACCEPT 2>/dev/null

    # Eliminar usuarios SOCKS5 huérfanos (nologin/false)
    while IFS=: read -r U _ _ _ _ SH; do
        case "$SH" in
            /usr/sbin/nologin|/bin/false|/sbin/nologin)
                userdel -f "$U" >/dev/null 2>&1
                ;;
        esac
    done < /etc/passwd

    sed -i '/^SOCKS5=/d' "$CONFIG"
    echo "SOCKS5=OFF" >> "$CONFIG"

    source "$CONFIG"

    echo ""
    echo "$(trx '✅ SOCKS5 eliminado.')"
    sleep 3
}

#==================================================
# Reiniciar servicios
#==================================================

restart_socks5(){

    clear

    svc_restart_anim "sockd" "$(trx 'Reiniciando') sockd" 2>/dev/null

    sleep 2
    test_socks5
    sleep 3
}

#==================================================
# Estado
#==================================================

status_socks5(){

    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}         📊 ESTADO SOCKS5${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    echo -e "  $(STATE sockd) sockd (dante · TCP $SOCKS5_PORT)"

    echo ""
    echo "$(trx 'Puertos:')"
    ss -ltnp | grep ":$SOCKS5_PORT " || true

    echo ""
    echo "$(trx 'Usuarios SOCKS5:')"
    while IFS=: read -r U _ _ _ _ SH; do
        case "$SH" in
            /usr/sbin/nologin|/bin/false|/sbin/nologin) echo "  - $U" ;;
        esac
    done < /etc/passwd

    echo ""
    read -n1 -r -p "$(trx 'Presione una tecla...')"
}

#==================================================
# Datos de conexión
#==================================================

show_info(){

    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}         📱 DATOS SOCKS5${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    VPS_IP=$(hostname -I | awk '{print $1}')

    echo "🌍 IP     : $VPS_IP"
    echo "🚀 Puerto : TCP $SOCKS5_PORT"
    echo "🔑 Auth   : usuario + contraseña"
    echo ""
    echo "$(trx '  Configuración en apps:')"
    echo -e "   ${GREEN}HTTP Injector:${RESET} Proxy type: SOCKS5 · Host: $VPS_IP · Port: $SOCKS5_PORT"
    echo -e "   ${GREEN}ProxyDroid/Orbot:${RESET} SOCKS5 $VPS_IP:$SOCKS5_PORT (con login)"
    echo -e "   ${GREEN}Navegadores:${RESET} configuración de proxy SOCKS5 manual"
    echo ""
    echo "$(trx '  El tráfico NO va cifrado (solo autenticado).')"
    echo "$(trx '  Para cifrado usa OpenVPN, Shadowsocks o Trojan.')"

    echo ""
    read -n1 -r -p "$(trx 'Presione una tecla...')"
}

#==================================================
# Menú Principal
#==================================================

# Navegación con flechitas
[[ -f "$BASE/lib/nav.sh" ]] && source "$BASE/lib/nav.sh"

# ── CLI headless ──
case "${1:-}" in
    --install)
        INSTALL_HEADLESS=1
        ;;
    --add-user)
        add_user "$2" "$3"
        exit $?
        ;;
    --remove-user)
        remove_user "$2"
        exit $?
        ;;
    --list)
        list_users
        exit $?
        ;;
    --status)
        test_socks5
        exit $?
        ;;
esac

# Modo instalación headless (install.sh lo invoca: bash socks5.sh --install)
if [[ "${INSTALL_HEADLESS:-}" == "1" ]]; then
    install_dependencies || exit 1
    create_sockd_conf
    create_service
    open_ports
    systemctl restart sockd
    if systemctl is-active --quiet sockd; then
        sed -i '/^SOCKS5=/d' "$CONFIG"
        echo "SOCKS5=ON" >> "$CONFIG"
        exit 0
    fi
    exit 1
fi

while true
do

    clear

    source "$CONFIG"

    if systemctl is-active --quiet sockd; then
        STATUS="${GREEN}🟢 ACTIVO${RESET}"
    else
        STATUS="${RED}🔴 DETENIDO${RESET}"
    fi

    mv_header "🐋 SOCKS5" "$(trx 'Proxy SOCKS5 · dante-server · login')" "v1"
    movivip_contacts 2>/dev/null || true

    echo -e " Estado      : $STATUS"
    echo -e " Puerto      : TCP $SOCKS5_PORT"

    echo ""

    if [[ "$SOCKS5" == "ON" ]]; then
        LBL=("Desinstalar SOCKS5" "Agregar Usuario" "Eliminar Usuario" "Listar Usuarios" "Reiniciar Servicio" "Ver Estado" "Ver Datos de Conexión")
    else
        LBL=("Instalar SOCKS5")
    fi
    SEL=$(nav_pick "► Opción:" "${LBL[@]}" "↩ Regresar") || SEL=0
    [[ $SEL -eq $((${#LBL[@]}+1)) ]] && SEL=0
    OP="$SEL"

    case "$OP" in

        1)
            if [[ "$SOCKS5" == "ON" ]]; then
                remove_socks5
            else
                install_socks5
            fi
        ;;

        2)
            [[ "$SOCKS5" == "ON" ]] && add_user
        ;;

        3)
            [[ "$SOCKS5" == "ON" ]] && remove_user
        ;;

        4)
            [[ "$SOCKS5" == "ON" ]] && list_users
        ;;

        5)
            [[ "$SOCKS5" == "ON" ]] && restart_socks5
        ;;

        6)
            [[ "$SOCKS5" == "ON" ]] && status_socks5
        ;;

        7)
            [[ "$SOCKS5" == "ON" ]] && show_info
        ;;

        0)
            exec bash "$BASE/protocolos/menu.sh"
        ;;

        *)
            echo ""
            echo "$(trx '❌ Opción inválida.')"
            sleep 2
        ;;

    esac

done