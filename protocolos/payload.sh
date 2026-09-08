#!/bin/bash

# ── i18n shim (auto) ───────────────────────────────
if ! declare -F trx >/dev/null 2>&1; then trx() { printf '%s' "$1"; }; fi
# ─────────────────────────────────────────────────────────

#==================================================
# MoviVIP Network Premium
# Payload Servers Manager v1 (estilo MoviVIP)
# 5 túneles HTTP/GET (PDirect, PGet, POpen,
# PPriv, PPub) para apps HTTP Injector,
# SSH Direct, KPN Tunnels, etc.
#
# • Ports: PDirect 8083 · PGet 8799 · POpen 8082
#          PPriv 8084 · PPub 8085
# • Python 3 (scripts portados — Ubuntu 24.04)
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
RESET="\e[0m"

DIR="/etc/movivip/payload"
PAYDIR="$DIR/payloads"
PASS_FILE="$DIR/pwd.pwd"

PAY_PDIRECT="${PAY_PDIRECT:-8083}"
PAY_GET="${PAY_GET:-8799}"
PAY_OPEN="${PAY_OPEN:-8082}"
PAY_PRIV="${PAY_PRIV:-8084}"
PAY_PUB="${PAY_PUB:-8085}"
PAY_PASS="${PAY_PASS:-}"

KEY_NAME="server.key"
CERT_NAME="server.crt"
LE_DOMAIN="${LE_DOMAIN:-}"
NO_RESTART=""

# Función: estado
STATE() { systemctl is-active --quiet "$1" && echo "${GREEN}🟢${RESET}" || echo "${RED}🔴${RESET}"; }

#==================================================
# Instalar dependencias
#==================================================

install_dependencies(){

    anim_step "$(trx 'Instalando dependencias')"
    anim_run "apt update" apt update -y
    anim_run "$(trx 'Instalar python3')" apt install -y python3

    mkdir -p "$PAYDIR"

    if ! command -v python3 >/dev/null 2>&1; then
        echo "$(trx '❌ No se encontró python3.')"
        return 1
    fi
    return 0
}

#==================================================
# Instalar scripts (incluidos o fallback)
#==================================================

install_scripts(){

    for S in pdirect pget popen ppriv ppub; do
        for LOCAL_SRC in \
            "$BASE/protocolos/payload/$S.py" \
            "$(dirname "$(readlink -f "$0")")/$S.py" \
            "$(dirname "$(readlink -f "$0")")/payload/$S.py"
        do
            if [[ -f "$LOCAL_SRC" ]]; then
                cp -f "$LOCAL_SRC" "$PAYDIR/$S.py"
                break
            fi
        done
        if [[ ! -f "$PAYDIR/$S.py" ]]; then
            echo "$(trx '❌ No se encontró') $S.py $(trx 'en protocolos/payload/')"
            return 1
        fi
    done

    anim_run "$(trx 'Scripts instalados')" true
    return 0
}

#==================================================
# Crear credenciales PGet (pwd.pwd)
#==================================================

gen_passwords(){

    [[ -n "$PAY_PASS" ]] || PAY_PASS=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9')
    MASTER=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9')
    TEMP_PASS=$(openssl rand -base64 6 | tr -dc 'a-zA-Z0-9')

    cat > "$PASS_FILE" <<EOFPASS
PasswordSet
master=$MASTER
127.0.0.1:22=$TEMP_PASS
EOFPASS

    chmod 600 "$PASS_FILE"
}

#==================================================
# Crear servicios systemd (5 unidades)
#==================================================

create_service(){

    SVC_UNIT_DIR=/etc/systemd/system

    cat > "$SVC_UNIT_DIR/payload-pdirect.service" <<SVCEOF
[Unit]
Description=MoviVIP Payload PDirect (HTTP Direct Tunnel)
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 $PAYDIR/pdirect.py -l 127.0.0.1:22 -p $PAY_PDIRECT -c $PAY_PASS -r 200 -t MoviVIP
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SVCEOF

    cat > "$SVC_UNIT_DIR/payload-pget.service" <<SVCEOF
[Unit]
Description=MoviVIP Payload PGet (HTTP GET Tunnel)
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 $PAYDIR/pget.py -b 0.0.0.0:$PAY_GET -p $PASS_FILE
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SVCEOF

    cat > "$SVC_UNIT_DIR/payload-popen.service" <<SVCEOF
[Unit]
Description=MoviVIP Payload POpen (Open Proxy Tunnel)
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 $PAYDIR/popen.py $PAY_OPEN
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SVCEOF

    cat > "$SVC_UNIT_DIR/payload-ppriv.service" <<SVCEOF
[Unit]
Description=MoviVIP Payload PPriv (Private Proxy Tunnel)
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 $PAYDIR/ppriv.py $PAY_PRIV MoviVIP 127.0.0.1
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SVCEOF

    cat > "$SVC_UNIT_DIR/payload-ppub.service" <<SVCEOF
[Unit]
Description=MoviVIP Payload PPub (Public Proxy Tunnel)
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 $PAYDIR/ppub.py $PAY_PUB MoviVIP
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SVCEOF

    systemctl daemon-reload

    for SVC in payload-pdirect payload-pget payload-popen payload-ppriv payload-ppub; do
        systemctl enable "$SVC" >/dev/null 2>&1
    done

    echo "$(trx '✅ 5 servicios Payload creados.')"
}

#==================================================
# Abrir puertos
#==================================================

open_ports(){

    echo "$(trx '🛡 Abriendo puertos...')"

    for P in "$PAY_PDIRECT" "$PAY_GET" "$PAY_OPEN" "$PAY_PRIV" "$PAY_PUB"; do
        iptables -C INPUT -p tcp --dport "$P" -j ACCEPT 2>/dev/null \
            || iptables -A INPUT -p tcp --dport "$P" -j ACCEPT
    done

    if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
        for P in "$PAY_PDIRECT" "$PAY_GET" "$PAY_OPEN" "$PAY_PRIV" "$PAY_PUB"; do
            ufw allow "$P"/tcp >/dev/null 2>&1
        done
    fi

    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4 2>/dev/null

}

#==================================================
# Test funcional
#==================================================

test_payload(){

    echo ""
    echo "$(trx '🧪 Verificando Payload servers...')"

    UP=0
    for SVC in payload-pdirect payload-pget payload-popen payload-ppriv payload-ppub; do
        systemctl is-active --quiet "$SVC" && UP=$((UP+1))
    done

    if [[ "$UP" -eq 5 ]]; then
        echo "$(trx '✅ Los 5 servidores Payload están activos.')"
        return 0
    fi

    echo "$(trx '⚠️  Solo') $UP/5 $(trx 'activos. Revisa journalctl -u payload-* -n 20.')"
    return 1
}

#==================================================
# Instalar Payload
#==================================================

install_payload(){

    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}        🧩 INSTALAR PAYLOAD SERVERS${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    anim_init 6
    anim_step "$(trx 'Instalando dependencias')"
    install_dependencies || return

    anim_step "$(trx 'Copiando scripts Python')"
    install_scripts || return

    anim_step "$(trx 'Generando credenciales')"
    gen_passwords

    anim_step "$(trx 'Creando servicios')"
    create_service

    anim_step "$(trx 'Abriendo puertos')"
    open_ports

    echo ""
    anim_step "$(trx 'Iniciando servicios')"
    anim_run "daemon-reload" systemctl daemon-reload

    for SVC in payload-pdirect payload-pget payload-popen payload-ppriv payload-ppub; do
        svc_restart_anim "$SVC" "$(trx 'Arrancando') $SVC"
    done

    UP=0
    for SVC in payload-pdirect payload-pget payload-popen payload-ppriv payload-ppub; do
        systemctl is-active --quiet "$SVC" && UP=$((UP+1))
    done

    if [[ "$UP" -lt 5 ]]; then
        echo "$(trx '⚠️  Algunos servicios no iniciaron:')"
        for SVC in payload-pdirect payload-pget payload-popen payload-ppriv payload-ppub; do
            if ! systemctl is-active --quiet "$SVC"; then
                echo "   - $SVC"
                journalctl -u "$SVC" -n 10 --no-pager 2>/dev/null | tail -5
            fi
        done
        return 1
    fi

    test_payload

    sleep 3

    if [[ "$UP" -eq 5 ]]; then

        sed -i '/^PAYLOAD=/d' "$CONFIG"
        echo "PAYLOAD=ON" >> "$CONFIG"

        source "$CONFIG"

        VPS_IP=$(hostname -I | awk '{print $1}')

        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "$(trx '      ✅ PAYLOAD INSTALADO')"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "🌍 IP       : $VPS_IP"
        echo "🚀 PDirect  : $PAY_PDIRECT → 127.0.0.1:22"
        echo "🚀 PGet     : $PAY_GET"
        echo "🚀 POpen    : $PAY_OPEN"
        echo "🚀 PPriv    : $PAY_PRIV"
        echo "🚀 PPub     : $PAY_PUB"
        echo ""
        echo "$(trx '  Master PGet:')"
        if [[ -f "$PASS_FILE" ]]; then
            grep '^master=' "$PASS_FILE" | sed 's/master=/   master=/'
            grep '^127.0.0.1:22=' "$PASS_FILE" | sed 's/:22=/ -> 127.0.0.1:22 =/;s/^/   127.0.0.1:22 =/'
        fi
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "$(trx '  📱 APPS COMPATIBLES')"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "   ${GREEN}HTTP Injector / KPN Tunnels:${RESET}"
        echo "   Tipo    : $(trx 'túnel HTTP+SSH directo')"
        echo "   Host    : $VPS_IP · Puerto : $PAY_PDIRECT"
        echo "   Payload : GET / HTTP/1.1[crlf]Host: $VPS_IP[crlf][crlf]"
        echo ""
        echo "   ${GREEN}SSH Direct / SSH Tunnel:${RESET}"
        echo "   Host    : $VPS_IP · Puerto : $PAY_OPEN"
        echo ""
        echo "   ${GREEN}PGet (Injector con proxy):${RESET}"
        echo "   Host    : $VPS_IP · Puerto : $PAY_GET · usuario master"
        echo ""
        echo "$(trx '  Las apps requieren On-The-Go:')"
        echo "$(trx '  ACTIVADO y DNS/SNI en el payload.')"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

    else

        echo ""
        echo "$(trx '❌ Error iniciando Payload servers')"
        echo ""
        for SVC in payload-pdirect payload-pget payload-popen payload-ppriv payload-ppub; do
            systemctl status "$SVC" --no-pager 2>/dev/null | head -8
        done

    fi

    sleep 4
}

#==================================================
# Eliminar Payload
#==================================================

remove_payload(){

    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}        🗑 ELIMINAR PAYLOAD${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    read -rp "$(trx '¿Eliminar Payload servers? (s/n): ')" R
    [[ ! "$R" =~ ^[Ss]$ ]] && return

    anim_step "$(trx 'Desinstalando Payload')"

    for SVC in payload-pdirect payload-pget payload-popen payload-ppriv payload-ppub; do
        anim_run "$(trx 'Detener') $SVC" bash -c "systemctl stop $SVC 2>/dev/null; systemctl disable $SVC 2>/dev/null"
        anim_run "$(trx 'Eliminar') $SVC" rm -f "/etc/systemd/system/$SVC.service"
    done

    anim_run "$(trx 'Eliminar directorio')" rm -rf "$DIR"
    anim_run "daemon-reload" systemctl daemon-reload

    for P in "$PAY_PDIRECT" "$PAY_GET" "$PAY_OPEN" "$PAY_PRIV" "$PAY_PUB"; do
        iptables -D INPUT -p tcp --dport "$P" -j ACCEPT 2>/dev/null
    done

    sed -i '/^PAYLOAD=/d' "$CONFIG"
    echo "PAYLOAD=OFF" >> "$CONFIG"

    source "$CONFIG"

    echo ""
    echo "$(trx '✅ Payload eliminado.')"
    sleep 3
}

#==================================================
# Reiniciar servicios
#==================================================

restart_payload(){

    clear

    for SVC in payload-pdirect payload-pget payload-popen payload-ppriv payload-ppub; do
        svc_restart_anim "$SVC" "$(trx 'Reiniciando') $SVC"
    done

    sleep 2
    test_payload
    sleep 3
}

#==================================================
# Estado
#==================================================

status_payload(){

    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}         📊 ESTADO PAYLOAD${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    for SVC in payload-pdirect payload-pget payload-popen payload-ppriv payload-ppub; do
        echo -e "  $(STATE "$SVC") $SVC"
    done

    echo ""
    echo "$(trx 'Puertos:')"
    ss -ltnp | grep -E ":$PAY_PDIRECT |:$PAY_GET |:$PAY_OPEN |:$PAY_PRIV |:$PAY_PUB " || true

    echo ""
    read -n1 -r -p "$(trx 'Presione una tecla...')"
}

#==================================================
# Datos de conexión
#==================================================

show_info(){

    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}         📱 DATOS PAYLOAD${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    VPS_IP=$(hostname -I | awk '{print $1}')

    echo "🌍 IP       : $VPS_IP"
    echo "🚀 PDirect  : $PAY_PDIRECT → 127.0.0.1:22 (pass: $PAY_PASS)"
    echo "🚀 PGet     : $PAY_GET"
    echo "🚀 POpen    : $PAY_OPEN"
    echo "🚀 PPriv    : $PAY_PRIV"
    echo "🚀 PPub     : $PAY_PUB"
    echo ""
    echo "🔑 Master PGet:"
    if [[ -f "$PASS_FILE" ]]; then
        grep '^master=' "$PASS_FILE" | sed 's/master=/- master=/'
        grep -E '^[0-9.]+:22=' "$PASS_FILE" | sed 's/:22=/:22 = /;s/^/- /'
    fi
    echo ""
    echo "📱 Payload sugerido (Injector):"
    echo "   GET / HTTP/1.1[crlf]Host: $VPS_IP[crlf][crlf]"

    echo ""
    read -n1 -r -p "$(trx 'Presione una tecla...')"
}

#==================================================
# Menú Principal
#==================================================

# Navegación con flechitas
[[ -f "$BASE/lib/nav.sh" ]] && source "$BASE/lib/nav.sh"

# ── CLI headless: bash payload.sh --install
if [[ "${1:-}" == "--install" ]]; then
    install_payload
    exit $?
fi

while true
do

    clear

    source "$CONFIG"

    UP=0
    for SVC in payload-pdirect payload-pget payload-popen payload-ppriv payload-ppub; do
        systemctl is-active --quiet "$SVC" && UP=$((UP+1))
    done

    if [[ "$UP" -eq 5 ]]; then
        STATUS="${GREEN}🟢 ACTIVO (5/5)${RESET}"
    elif [[ "$UP" -gt 0 ]]; then
        STATUS="${YELLOW}🟡 PARCIAL ($UP/5)${RESET}"
    else
        STATUS="${RED}🔴 DETENIDO${RESET}"
    fi

    mv_header "🧩 Payload Manager" "$(trx '5 servidores HTTP · 8082-8085/8799')" "v6.2"
    movivip_contacts 2>/dev/null || true

    echo -e " Estado      : $STATUS"

    echo ""

    if [[ "$PAYLOAD" == "ON" ]]; then
        LBL=("Desinstalar Payload" "Reiniciar Servicios" "Ver Estado" "Ver Datos de Conexión")
    else
        LBL=("Instalar Payload")
    fi
    SEL=$(nav_pick "► Opción:" "${LBL[@]}" "↩ Regresar") || SEL=0
    [[ $SEL -eq $((${#LBL[@]}+1)) ]] && SEL=0
    OP="$SEL"

    case "$OP" in

        1)
            if [[ "$PAYLOAD" == "ON" ]]; then
                remove_payload
            else
                install_payload
            fi
        ;;

        2)
            [[ "$PAYLOAD" == "ON" ]] && restart_payload
        ;;

        3)
            [[ "$PAYLOAD" == "ON" ]] && status_payload
        ;;

        4)
            [[ "$PAYLOAD" == "ON" ]] && show_info
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