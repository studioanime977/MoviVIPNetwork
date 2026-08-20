#!/bin/bash

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#
#            MoviVIP Network            #
#              ZIVPN AUTO INSTALLER            #
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#

BASE="/etc/movivip"
CONFIG="$BASE/config.conf"

# Cargar funciones multi-distro
[[ -f "$BASE/functions/pkg.sh" ]] && source "$BASE/functions/pkg.sh"

[[ -f "$CONFIG" ]] && source "$CONFIG"

# Cargar idioma
if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)"
fi

CYAN="\e[1;96m"
GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
WHITE="\e[1;97m"
BLUE="\e[1;94m"
MAGENTA="\e[1;95m"
RESET="\e[0m"

SERVICE="zivpn"

# Archivo de expiración de contraseñas: formato CONTRASEÑA|EPOCH (0 = ilimitado)
ZIVPN_EXP_FILE="/etc/zivpn/expira.conf"
ZIVPN_EXP_SCRIPT="/usr/local/bin/zivpn-expira.sh"

# Archivo de límites de tráfico: formato CONTRASEÑA|GB (0 = ilimitado)
ZIVPN_LIM_FILE="/etc/zivpn/limites.conf"
ZIVPN_LIM_SCRIPT="/usr/local/bin/zivpn-limite.sh"

line() {
    printf "${CYAN}%0.s═" {1..55}
    echo -e "${RESET}"
}

title() {
    clear
    line
    echo -e "${WHITE}           🚀 MoviVIP ZIVPN MANAGER${RESET}"
    line
}

ok() {
    echo -e "${GREEN}✔${RESET} $1"
}

error() {
    echo -e "${RED}✘${RESET} $1"
}

info() {
    echo -e "${CYAN}➜${RESET} $1"
}

warn() {
    echo -e "${YELLOW}⚠${RESET} $1"
}

pause() {
    echo
    read -n1 -rsp "Presione cualquier tecla para continuar..."
    echo
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#
#        BUSCAR PUERTO LIBRE AUTOMÁTICO        #
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#

ZPORT="5667"

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#
#           DETECTAR INTERFAZ DE RED           #
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#

get_network_interface() {

    local dev

    dev=$(ip route | awk '/default/ {print $5; exit}')

    [[ -z "$dev" ]] && \
    dev=$(ip link show up | awk -F': ' '/state UP/ && $2!="lo"{print $2;exit}')

    echo "$dev"
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#
#         COMPROBAR REQUISITOS DEL VPS         #
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#

check_system() {

    title

    info "Comprobando sistema..."

    [[ $EUID -ne 0 ]] && {
        error "Ejecute el script como root."
        pause
        return 1
    }

    command -v curl >/dev/null || {
        error "curl no está instalado."
        pause
        return 1
    }

    command -v openssl >/dev/null || {
        error "openssl no está instalado."
        pause
        return 1
    }

    ok "Sistema compatible."

}

install_zivpn() {

if systemctl is-active --quiet zivpn; then
    warn "ZiVPN ya esta instalado."
    pause
    return
fi
    title

    check_system || return

    PORT=$ZPORT

    echo
    info "Actualizando repositorios..."
    pkg_update

    echo
    info "Instalando dependencias..."

    pkg_install curl wget jq openssl iptables >/dev/null 2>&1
    ARCH=$(uname -m)
    if [[ "$ARCH" == "x86_64" || "$ARCH" == "i386" || "$ARCH" == "i686" ]]; then
        pkg_install libc6-i386 >/dev/null 2>&1
    fi

    sysctl -w net.ipv4.ip_forward=1 >/dev/null

    grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf || \
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

    ARCH=$(uname -m)

    case "$ARCH" in
        x86_64)
            BIN_URL="https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64"
        ;;
        aarch64|arm64)
            BIN_URL="https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-arm64"
        ;;
        *)
            error "Arquitectura no soportada: $ARCH"
            pause
            return
        ;;
    esac

    mkdir -p /etc/zivpn

    echo
    info "Descargando ZiVPN..."

    curl -L --retry 3 --connect-timeout 10 "$BIN_URL" -o /usr/local/bin/zivpn
if [[ $? -ne 0 ]]; then
    error "No se pudo descargar ZiVPN."
    pause
    return
fi
    chmod +x /usr/local/bin/zivpn

    [[ ! -x /usr/local/bin/zivpn ]] && {
        error "No fue posible descargar ZiVPN."
        pause
        return
    }

    echo
    info "Generando certificados SSL..."

    openssl req \
        -new \
        -newkey rsa:4096 \
        -nodes \
        -x509 \
        -days 3650 \
        -subj "/C=US/ST=CA/L=LA/O=ZiVPN/CN=zivpn" \
        -keyout /etc/zivpn/zivpn.key \
        -out /etc/zivpn/zivpn.crt

cat >/etc/zivpn/config.json <<EOF
{
    "listen": ":$PORT",
    "cert": "/etc/zivpn/zivpn.crt",
    "key": "/etc/zivpn/zivpn.key",
    "max_conn": 0,
    "auth": {
        "mode": "passwords",
        "config": [
            "1"
        ]
    }
}
EOF

cat >/etc/systemd/system/zivpn.service <<EOF
[Unit]
Description=ZiVPN UDP Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/zivpn
ExecStart=/usr/local/bin/zivpn server -c /etc/zivpn/config.json
Restart=always
RestartSec=2
LimitNOFILE=1048576
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW

[Install]
WantedBy=multi-user.target
EOF

jq empty /etc/zivpn/config.json || {
    error "Error en config.json"
    pause
    return
}

chmod 600 /etc/zivpn/config.json
chmod 600 /etc/zivpn/zivpn.key
chmod 644 /etc/zivpn/zivpn.crt

    systemctl daemon-reload
    systemctl enable zivpn >/dev/null 2>&1
    systemctl restart zivpn

    configure_zivpn_firewall "$PORT"
if command -v netfilter-persistent >/dev/null 2>&1; then
    netfilter-persistent save >/dev/null 2>&1
elif command -v iptables-save >/dev/null 2>&1; then
    iptables-save >/etc/iptables.rules
fi
    if grep -q "^ZIPVPN=" "$CONFIG"; then
        sed -i 's/^ZIPVPN=.*/ZIPVPN=ON/' "$CONFIG"
    else
        echo "ZIPVPN=ON" >> "$CONFIG"
    fi

    if grep -q "^ZIPVPN_PORT=" "$CONFIG"; then
        sed -i "s/^ZIPVPN_PORT=.*/ZIPVPN_PORT=\"$PORT\"/" "$CONFIG"
    else
        echo "ZIPVPN_PORT=\"$PORT\"" >> "$CONFIG"
    fi

    source "$CONFIG"

    sleep 2

    if systemctl is-active --quiet zivpn; then

        title

        ok "ZiVPN instalado correctamente."

        echo
        echo " Servicio : zivpn"
        echo " Estado   : Activo"
        echo " Puerto   : $PORT"
        echo " Config   : /etc/zivpn/config.json"
        echo " SSL      : Habilitado"

    else

        error "El servicio no pudo iniciarse."

        journalctl -u zivpn --no-pager -n 20

    fi

    pause
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#
#           CONFIGURAR IPTABLES                #
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#

configure_zivpn_firewall() {

    local PORT="$1"

    info "Configurando firewall..."

    # Eliminar reglas anteriores de ZiVPN
    while iptables -t nat -C PREROUTING -p udp --dport 6000:19999 -j DNAT --to-destination ":$PORT" &>/dev/null; do
        iptables -t nat -D PREROUTING -p udp --dport 6000:19999 -j DNAT --to-destination ":$PORT"
    done

    while iptables -C INPUT -p udp --dport "$PORT" -j ACCEPT &>/dev/null; do
        iptables -D INPUT -p udp --dport "$PORT" -j ACCEPT
    done

    # Agregar DNAT en PREROUTING (INSERTAR en posicion 1 = al tope, antes de UDP Custom)
    iptables -t nat -I PREROUTING 1 \
        -p udp \
        --dport 6000:19999 \
        -j DNAT \
        --to-destination ":$PORT"

    # Abrir puerto 5667 en INPUT
    iptables -A INPUT \
        -p udp \
        --dport "$PORT" \
        -j ACCEPT

    ok "Firewall configurado correctamente."

}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#
#            REINICIAR SERVICIO                #
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#

restart_zivpn() {

    title

    info "Reiniciando ZiVPN..."

    systemctl restart zivpn

    sleep 2

    if systemctl is-active --quiet zivpn; then
        ok "Servicio reiniciado correctamente."
    else
        error "No fue posible reiniciar ZiVPN."
    fi

    pause

}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#
#               ESTADO DEL SERVICIO            #
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#

status_zivpn() {

    title

    if systemctl is-active --quiet zivpn; then
        STATUS="${GREEN}🟢 ACTIVO${RESET}"
    else
        STATUS="${RED}🔴 DETENIDO${RESET}"
    fi

    PORT="-"

    [[ -f /etc/zivpn/config.json ]] && \
    PORT=$(jq -r '.listen' /etc/zivpn/config.json | tr -d ':')

    echo
    echo -e " Estado     : $STATUS"
    echo -e " Servicio   : zivpn"
    echo -e " Puerto UDP : $PORT"
    echo

    line

    systemctl --no-pager --full status zivpn

    pause

}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#
#             DESINSTALAR ZIVPN                #
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#

remove_zivpn() {

    title

    warn "Se eliminará completamente ZiVPN."

    echo

    read -rp "¿Continuar? [s/N]: " R

    [[ ! "$R" =~ ^[Ss]$ ]] && return

    PORT=$(jq -r '.listen' /etc/zivpn/config.json 2>/dev/null | tr -d ':')

    systemctl stop zivpn 2>/dev/null
    systemctl disable zivpn 2>/dev/null

    rm -f /etc/systemd/system/zivpn.service
    rm -rf /etc/zivpn
    rm -f /usr/local/bin/zivpn

    if [[ -n "$PORT" && "$PORT" != "null" ]]; then
        while iptables -t nat -C PREROUTING -p udp --dport 6000:19999 -j DNAT --to-destination ":$PORT" &>/dev/null; do
            iptables -t nat -D PREROUTING -p udp --dport 6000:19999 -j DNAT --to-destination ":$PORT"
        done
        while iptables -C INPUT -p udp --dport "$PORT" -j ACCEPT &>/dev/null; do
            iptables -D INPUT -p udp --dport "$PORT" -j ACCEPT
        done
    fi

    systemctl daemon-reload
    systemctl reset-failed

    if grep -q "^ZIPVPN=" "$CONFIG"; then
        sed -i 's/^ZIPVPN=.*/ZIPVPN=OFF/' "$CONFIG"
    else
        echo "ZIPVPN=OFF" >> "$CONFIG"
    fi

    sed -i '/^ZIPVPN_PORT=/d' "$CONFIG"

    source "$CONFIG"

    echo

    ok "ZiVPN fue eliminado correctamente."

    pause

}
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#
#            AGREGAR CONTRASEÑA                #
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#

add_zivpn_password() {

    title

    [[ ! -f /etc/zivpn/config.json ]] && {
        error "ZiVPN no está instalado."
        pause
        return
    }

    read -rp "Ingrese la nueva contraseña: " PASS

    [[ -z "$PASS" ]] && {
        error "La contraseña no puede estar vacía."
        pause
        return
    }

    if jq -e --arg pass "$PASS" '.auth.config[] | select(.==$pass)' \
        /etc/zivpn/config.json >/dev/null; then

        error "La contraseña ya existe."
        pause
        return

    fi

    TMP=$(mktemp)

    jq --arg pass "$PASS" \
        '.auth.config += [$pass]' \
        /etc/zivpn/config.json > "$TMP"

    mv "$TMP" /etc/zivpn/config.json

    systemctl restart zivpn

    ok "Contraseña agregada correctamente."

    read -rp "Duración en días (Enter = ilimitado): " DIAS
    if [[ -n "$DIAS" && "$DIAS" =~ ^[0-9]+$ && "$DIAS" -gt 0 ]]; then
        EXP=$(date -d "+${DIAS} days" +%s)
        set_exp "$PASS" "$EXP"
        ok "Caducidad: $(fmt_exp "$EXP")"
    else
        set_exp "$PASS" "0"
    fi

    read -rp "Limite de trafico en GB (Enter = ilimitado): " GB
    if [[ -n "$GB" && "$GB" =~ ^[0-9]+$ && "$GB" -gt 0 ]]; then
        set_lim "$PASS" "$GB"
        ok "Limite: $GB GB"
    else
        set_lim "$PASS" "0"
    fi

    pause

}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#
#            ELIMINAR CONTRASEÑA               #
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#

remove_zivpn_password() {

    title

    [[ ! -f /etc/zivpn/config.json ]] && {
        error "ZiVPN no está instalado."
        pause
        return
    }

    mapfile -t PASSLIST < <(
        jq -r '.auth.config[]' /etc/zivpn/config.json
    )

    [[ ${#PASSLIST[@]} -eq 0 ]] && {
        error "No existen contraseñas registradas."
        pause
        return
    }

    echo

    for ((i=0;i<${#PASSLIST[@]};i++)); do
        printf " [%02d] %s\n" "$((i+1))" "${PASSLIST[$i]}"
    done

    echo

    read -rp "Seleccione una contraseña: " OP

    [[ ! "$OP" =~ ^[0-9]+$ ]] && {
        error "Opción inválida."
        pause
        return
    }

    INDEX=$((OP-1))

    [[ $INDEX -lt 0 || $INDEX -ge ${#PASSLIST[@]} ]] && {
        error "Opción inválida."
        pause
        return
    }

    PASS="${PASSLIST[$INDEX]}"

    TMP=$(mktemp)

    jq --arg pass "$PASS" \
        '.auth.config |= map(select(. != $pass))' \
        /etc/zivpn/config.json > "$TMP"

    mv "$TMP" /etc/zivpn/config.json

    awk -F"|" -v p="$PASS" '$1!=p' "$ZIVPN_EXP_FILE" > /tmp/zivpn-exp.tmp 2>/dev/null && mv /tmp/zivpn-exp.tmp "$ZIVPN_EXP_FILE"

    awk -F"|" -v p="$PASS" '$1!=p' "$ZIVPN_LIM_FILE" > /tmp/zivpn-lim.tmp 2>/dev/null && mv /tmp/zivpn-lim.tmp "$ZIVPN_LIM_FILE"

    systemctl restart zivpn

    ok "Contraseña eliminada correctamente."

    pause

}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#
#             LISTAR CONTRASEÑAS               #
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#

list_zivpn_passwords() {

    title

    [[ ! -f /etc/zivpn/config.json ]] && {
        error "ZiVPN no está instalado."
        pause
        return
    }

    echo

    TOTAL=$(jq '.auth.config | length' /etc/zivpn/config.json)

    echo " Total de contraseñas : $TOTAL"

    line

    mapfile -t PASSLIST < <(jq -r '.auth.config[]' /etc/zivpn/config.json)

    for ((i=0;i<${#PASSLIST[@]};i++)); do
        EXP=$(get_exp "${PASSLIST[$i]}")
        LIM=$(get_lim "${PASSLIST[$i]}")
        printf " %2d. %-25s -> Expira: %-17s | Limite: %s\n" "$((i+1))" "${PASSLIST[$i]}" "$(fmt_exp "$EXP")" "$(fmt_lim "$LIM")"
    done

    line

    pause

}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#
#         GESTIÓN DE CADUCIDADES                #
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#

fmt_exp() {
    local exp="$1"
    if [[ -z "$exp" || "$exp" == "0" ]]; then
        echo "Ilimitada"
    else
        date -d "@$exp" "+%Y-%m-%d %H:%M"
    fi
}

get_exp() {
    local pass="$1"
    awk -F"|" -v p="$pass" '$1==p {print $2; exit}' "$ZIVPN_EXP_FILE" 2>/dev/null
}

set_exp() {
    local pass="$1" exp="$2"
    [[ -f "$ZIVPN_EXP_FILE" ]] || touch "$ZIVPN_EXP_FILE"
    awk -F"|" -v p="$pass" '$1!=p' "$ZIVPN_EXP_FILE" > /tmp/zivpn-exp.tmp 2>/dev/null
    echo "${pass}|${exp}" >> /tmp/zivpn-exp.tmp
    mv /tmp/zivpn-exp.tmp "$ZIVPN_EXP_FILE"
}

setup_expiration() {
    [[ -x "$ZIVPN_EXP_SCRIPT" ]] && return 0
    cat > "$ZIVPN_EXP_SCRIPT" <<'SCRIPTEOF'
#!/bin/bash
# zivpn-expira.sh — elimina contraseñas vencidas automáticamente
EXP_FILE="/etc/zivpn/expira.conf"
CONFIG="/etc/zivpn/config.json"
NOW=$(date +%s)
[[ -f "$EXP_FILE" ]] || exit 0
CHANGED=0
while IFS='|' read -r PASS EXP; do
    [[ -z "$PASS" ]] && continue
    if [[ "$EXP" != "0" && -n "$EXP" && "$EXP" -le "$NOW" ]]; then
        jq --arg p "$PASS" '.auth.config |= map(select(. != $p))' "$CONFIG" > /tmp/zivpn-exp.json && mv /tmp/zivpn-exp.json "$CONFIG"
        awk -F'|' -v p="$PASS" '$1!=p' "$EXP_FILE" > /tmp/zivpn-exp.tmp && mv /tmp/zivpn-exp.tmp "$EXP_FILE"
        CHANGED=1
    fi
done < "$EXP_FILE"
[[ "$CHANGED" -eq 1 ]] && systemctl restart zivpn
exit 0
SCRIPTEOF
    chmod +x "$ZIVPN_EXP_SCRIPT"
    touch "$ZIVPN_EXP_FILE"
    ( crontab -l 2>/dev/null | grep -v "zivpn-expira" ; echo "* * * * * $ZIVPN_EXP_SCRIPT" ) | crontab -
}

clean_expired() {
    title
    [[ ! -f "$ZIVPN_EXP_FILE" ]] && {
        info "Sin archivo de expiraciones."
        pause
        return
    }
    NOW=$(date +%s)
    EXPIRADAS=0
    CHANGED=0
    while IFS='|' read -r PASS EXP; do
        [[ -z "$PASS" ]] && continue
        if [[ "$EXP" != "0" && -n "$EXP" && "$EXP" -le "$NOW" ]]; then
            jq --arg p "$PASS" '.auth.config |= map(select(. != $p))' /etc/zivpn/config.json > /tmp/zivpn-exp.json 2>/dev/null && mv /tmp/zivpn-exp.json /etc/zivpn/config.json
            awk -F'|' -v p="$PASS" '$1!=p' "$ZIVPN_EXP_FILE" > /tmp/zivpn-exp.tmp 2>/dev/null && mv /tmp/zivpn-exp.tmp "$ZIVPN_EXP_FILE"
            warn "Vencida eliminada: $PASS (expiraba $(fmt_exp "$EXP"))"
            EXPIRADAS=$((EXPIRADAS+1))
            CHANGED=1
        fi
    done < "$ZIVPN_EXP_FILE"
    [[ "$CHANGED" -eq 1 ]] && systemctl restart zivpn
    if [[ "$EXPIRADAS" -eq 0 ]]; then
        ok "No hay contraseñas vencidas."
    else
        ok "$EXPIRADAS contraseña(s) vencida(s) eliminadas."
    fi
    pause
}

expira_password() {
    title
    [[ ! -f /etc/zivpn/config.json ]] && {
        error "ZiVPN no está instalado."
        pause
        return
    }
    mapfile -t PASSLIST < <(jq -r '.auth.config[]' /etc/zivpn/config.json)
    [[ ${#PASSLIST[@]} -eq 0 ]] && {
        error "No existen contraseñas registradas."
        pause
        return
    }
    echo
    for ((i=0;i<${#PASSLIST[@]};i++)); do
        EXP=$(get_exp "${PASSLIST[$i]}")
        printf " [%02d] %-25s -> %s\n" "$((i+1))" "${PASSLIST[$i]}" "$(fmt_exp "$EXP")"
    done
    echo
    read -rp "Seleccione una contraseña: " OP
    [[ ! "$OP" =~ ^[0-9]+$ ]] && {
        error "Opción inválida."
        pause
        return
    }
    INDEX=$((OP-1))
    [[ $INDEX -lt 0 || $INDEX -ge ${#PASSLIST[@]} ]] && {
        error "Opción inválida."
        pause
        return
    }
    PASS="${PASSLIST[$INDEX]}"
    echo
    read -rp "Duración en días (Enter = ilimitado): " DIAS
    if [[ -z "$DIAS" || "$DIAS" == "0" ]]; then
        set_exp "$PASS" "0"
        ok "Contraseña '$PASS' sin caducidad (ilimitada)."
    elif [[ "$DIAS" =~ ^[0-9]+$ && "$DIAS" -gt 0 ]]; then
        EXP=$(date -d "+${DIAS} days" +%s)
        set_exp "$PASS" "$EXP"
        ok "Contraseña '$PASS' expirará el: $(fmt_exp "$EXP")"
    else
        error "Duración inválida."
    fi
    pause
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#
#               VER LOGS ZIVPN                 #
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#

#???????????????????????????????????????????????# 
#          GESTION DE LIMITES DE TRAFICO          #
#???????????????????????????????????????????????#

fmt_lim() {
    local lim="$1"
    if [[ -z "$lim" || "$lim" == "0" ]]; then
        echo "Ilimitado"
    else
        echo "$lim GB"
    fi
}

get_lim() {
    local pass="$1"
    awk -F"|" -v p="$pass" '$1==p {print $2; exit}' "$ZIVPN_LIM_FILE" 2>/dev/null
}

set_lim() {
    local pass="$1" lim="$2"
    [[ -f "$ZIVPN_LIM_FILE" ]] || touch "$ZIVPN_LIM_FILE"
    awk -F"|" -v p="$pass" '$1!=p' "$ZIVPN_LIM_FILE" > /tmp/zivpn-lim.tmp 2>/dev/null
    echo "${pass}|${lim}" >> /tmp/zivpn-lim.tmp
    mv /tmp/zivpn-lim.tmp "$ZIVPN_LIM_FILE"
}

# Cuota de bloqueo por dispositivo = limite minimo > 0 entre las contrasenas con limite
# (no hay API de stats por contrasena en udp-zivpn; el corte se aplica por IP)
cuota_activa() {
    local m=0
    [[ -f "$ZIVPN_LIM_FILE" ]] || { echo 0; return; }
    while IFS='|' read -r P L; do
        [[ -z "$P" ]] && continue
        if [[ "$L" =~ ^[0-9]+$ && "$L" -gt 0 ]]; then
            if [[ "$m" -eq 0 || "$L" -lt "$m" ]]; then m=$L; fi
        fi
    done < "$ZIVPN_LIM_FILE"
    echo "$m"
}

setup_limite() {
    [[ -x "$ZIVPN_LIM_SCRIPT" ]] && return 0
    cat > "$ZIVPN_LIM_SCRIPT" <<'SCRIPTEOF'
#!/bin/bash
# zivpn-limite.sh - control de trafico por IP para ZipVPN
# Sin API de stats por contrasena en udp-zivpn: se mide por IP conectada
# y se bloquea la IP que supera la cuota minima configurada.
CONF="/etc/zivpn/config.json"
LIM_FILE="/etc/zivpn/limites.conf"
CONS_FILE="/etc/zivpn/consumo.conf"
BLOQ_FILE="/etc/zivpn/bloqueadas.txt"
SNAP_FILE="/etc/zivpn/snapshot.conf"
LOG="/etc/zivpn/zivpn-limite.log"
PORT=$(jq -r '.listen' "$CONF" 2>/dev/null | tr -d ':')
[[ -z "$PORT" || "$PORT" == "null" ]] && exit 0

# Cuota minima > 0 configurada
CUOTA=0
[[ -f "$LIM_FILE" ]] && CUOTA=$(awk -F'|' '$2>0 && ($2<CUOTA || CUOTA==0){CUOTA=$2} END{print CUOTA+0}' "$LIM_FILE")
[[ "$CUOTA" -eq 0 ]] && exit 0

LIMIT_BYTES=$((CUOTA * 1073741824))

# Limpiar reglas DROP de IPs que ya no estan activas
if [[ -f "$BLOQ_FILE" ]]; then
    ACTIVE=$(conntrack -L -p udp --dport "$PORT" 2>/dev/null | grep -o 'src=[0-9.]*' | cut -d= -f2 | sort -u)
    while read -r IP; do
        [[ -z "$IP" ]] && continue
        if ! echo "$ACTIVE" | grep -qx "$IP"; then
            iptables -D INPUT -s "$IP" -j DROP 2>/dev/null
            iptables -D OUTPUT -d "$IP" -j DROP 2>/dev/null
            awk -v p="$IP" '$1!=p' "$BLOQ_FILE" > /tmp/zb.tmp 2>/dev/null && mv /tmp/zb.tmp "$BLOQ_FILE"
            rm -f "/etc/zivpn/consumo/$IP.txt"
            echo "$(date '+%F %T') desbloqueada $IP (desconectada)" >> "$LOG"
        fi
    done < "$BLOQ_FILE"
fi

# IPs activas conectadas al puerto
mapfile -t IPS < <(conntrack -L -p udp --dport "$PORT" 2>/dev/null | grep -o 'src=[0-9.]*' | cut -d= -f2 | sort -u)
[[ ${#IPS[@]} -eq 0 ]] && exit 0

touch "$SNAP_FILE" "$CONS_FILE"

for IP in "${IPS[@]}"; do
    # Contar si ya esta bloqueada
    if grep -qx "$IP" "$BLOQ_FILE" 2>/dev/null; then
        continue
    fi
    # Reglas contadoras (no cambian politica)
    iptables -C INPUT -s "$IP" -p udp --dport "$PORT" -j ACCEPT 2>/dev/null || iptables -I INPUT -s "$IP" -p udp --dport "$PORT" -j ACCEPT
    iptables -C OUTPUT -d "$IP" -j ACCEPT 2>/dev/null || iptables -I OUTPUT -d "$IP" -j ACCEPT
    # Bytes actuales
    CUR=$(iptables -L INPUT -v -x -n | awk -v ip="$IP" -v pt="$PORT" '$8==ip && $11=="dpt:"pt {s+=$2} END{print s+0}')
    CUR2=$(iptables -L OUTPUT -v -x -n | awk -v ip="$IP" '$7==ip {s+=$2} END{print s+0}')
    CUR=$((CUR + CUR2))
    # Snapshot previo
    PREV=$(awk -F'|' -v ip="$IP" '$1==ip {print $2; exit}' "$SNAP_FILE" 2>/dev/null)
    PREV=${PREV:-0}
    DELTA=$((CUR - PREV))
    [[ $DELTA -lt 0 ]] && DELTA=$((CUR))
    # Acumular
    ACC=$(awk -F'|' -v ip="$IP" '$1==ip {print $2; exit}' "$CONS_FILE" 2>/dev/null)
    ACC=${ACC:-0}
    NEW=$((ACC + DELTA))
    awk -F'|' -v ip="$IP" '$1!=ip' "$CONS_FILE" > /tmp/zc.tmp 2>/dev/null && echo "${IP}|${NEW}" >> /tmp/zc.tmp && mv /tmp/zc.tmp "$CONS_FILE"
    awk -F'|' -v ip="$IP" '$1!=ip' "$SNAP_FILE" > /tmp/zs.tmp 2>/dev/null && echo "${IP}|${CUR}" >> /tmp/zs.tmp && mv /tmp/zs.tmp "$SNAP_FILE"
    # Bloquear si supera la cuota
    if [[ "$NEW" -gt "$LIMIT_BYTES" ]]; then
        iptables -I INPUT -s "$IP" -j DROP 2>/dev/null
        iptables -I OUTPUT -d "$IP" -j DROP 2>/dev/null
        echo "$IP" >> "$BLOQ_FILE"
        GB=$(awk -v b="$NEW" 'BEGIN{printf "%.2f", b/1073741824}')
        echo "$(date '+%F %T') BLOQUEADA $IP por superar cuota ($GB GB / $CUOTA GB)" >> "$LOG"
    fi
done
exit 0
SCRIPTEOF
    chmod +x "$ZIVPN_LIM_SCRIPT"
    touch "$ZIVPN_LIM_FILE"
    if command -v conntrack >/dev/null 2>&1; then
        :
    else
        pkg_install conntrack >/dev/null 2>&1
    fi
    ( crontab -l 2>/dev/null | grep -v "zivpn-limite" ; echo "* * * * * $ZIVPN_LIM_SCRIPT" ) | crontab -
}

limita_password() {
    title
    [[ ! -f /etc/zivpn/config.json ]] && {
        error "ZiVPN no esta instalado."
        pause
        return
    }
    mapfile -t PASSLIST < <(jq -r '.auth.config[]' /etc/zivpn/config.json)
    [[ ${#PASSLIST[@]} -eq 0 ]] && {
        error "No existen contrasenas registradas."
        pause
        return
    }
    echo
    for ((i=0;i<${#PASSLIST[@]};i++)); do
        LIM=$(get_lim "${PASSLIST[$i]}")
        printf " [%02d] %-25s -> %s\n" "$((i+1))" "${PASSLIST[$i]}" "$(fmt_lim "$LIM")"
    done
    echo
    read -rp "Seleccione una contrasena: " OP
    [[ ! "$OP" =~ ^[0-9]+$ ]] && {
        error "Opcion invalida."
        pause
        return
    }
    INDEX=$((OP-1))
    [[ $INDEX -lt 0 || $INDEX -ge ${#PASSLIST[@]} ]] && {
        error "Opcion invalida."
        pause
        return
    }
    PASS="${PASSLIST[$INDEX]}"
    echo
    read -rp "Limite de trafico en GB (Enter = ilimitado): " GB
    if [[ -z "$GB" || "$GB" == "0" ]]; then
        set_lim "$PASS" "0"
        ok "Contrasena '$PASS' sin limite (ilimitada)."
    elif [[ "$GB" =~ ^[0-9]+$ && "$GB" -gt 0 ]]; then
        set_lim "$PASS" "$GB"
        ok "Contrasena '$PASS' limitada a $GB GB."
    else
        error "Limite invalido."
    fi
    pause
}

consumo_zivpn() {
    title
    [[ ! -f /etc/zivpn/config.json ]] && {
        error "ZiVPN no esta instalado."
        pause
        return
    }
    echo
    if [[ ! -f /etc/zivpn/consumo.conf ]]; then
        info "Sin registro de consumo todavia (el cron se ejecuta cada minuto)."
    else
        echo " Consumo acumulado por IP conectada:"
        echo
        printf " %-16s %-12s %s\n" "IP" "Consumo" "Estado"
        while IFS='|' read -r IP BYTES; do
            [[ -z "$IP" ]] && continue
            GB=$(awk -v b="$BYTES" 'BEGIN{printf "%.2f GB", b/1073741824}')
            ESTADO="activa"
            grep -qx "$IP" /etc/zivpn/bloqueadas.txt 2>/dev/null && ESTADO="BLOQUEADA"
            printf " %-16s %-12s %s\n" "$IP" "$GB" "$ESTADO"
        done < /etc/zivpn/consumo.conf
        echo
        if [[ -f /etc/zivpn/bloqueadas.txt ]] && [[ -s /etc/zivpn/bloqueadas.txt ]]; then
            read -rp "Desbloquear TODAS las IPs bloqueadas? [s/N]: " DESB
            if [[ "${DESB,,}" == "s" ]]; then
                while read -r IP; do
                    [[ -z "$IP" ]] && continue
                    iptables -D INPUT -s "$IP" -j DROP 2>/dev/null
                    iptables -D OUTPUT -d "$IP" -j DROP 2>/dev/null
                    awk -v p="$IP" '$1!=p' /etc/zivpn/consumo.conf > /tmp/zc.tmp 2>/dev/null && mv /tmp/zc.tmp /etc/zivpn/consumo.conf
                done < /etc/zivpn/bloqueadas.txt
                > /etc/zivpn/bloqueadas.txt
                ok "IPs desbloqueadas y consumo reiniciado."
            fi
        fi
        if [[ -f /etc/zivpn/zivpn-limite.log ]] && [[ -s /etc/zivpn/zivpn-limite.log ]]; then
            echo
            info "Ultimos bloqueos:"
            tail -5 /etc/zivpn/zivpn-limite.log
        fi
    fi
    pause
}

view_zivpn_logs() {

    title

    info "Últimos 50 registros del servicio"

    line

    journalctl -u zivpn --no-pager -n 50

    line

    pause

}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#
#             DIAGNÓSTICO ZIVPN                #
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#

check_zivpn() {

    title

    [[ -x /usr/local/bin/zivpn ]] \
        && ok "Binario ZiVPN" \
        || error "Binario ZiVPN"

    [[ -f /etc/zivpn/config.json ]] \
        && ok "Archivo config.json" \
        || error "Archivo config.json"

    [[ -f /etc/zivpn/zivpn.crt ]] \
        && ok "Certificado SSL" \
        || error "Certificado SSL"

    [[ -f /etc/zivpn/zivpn.key ]] \
        && ok "Llave privada" \
        || error "Llave privada"

    if systemctl is-active --quiet zivpn; then
        ok "Servicio ejecutándose"
    else
        error "Servicio detenido"
    fi

    PORT="-"

    [[ -f /etc/zivpn/config.json ]] && \
    PORT=$(jq -r '.listen' /etc/zivpn/config.json | tr -d ':')

    echo
    line
    echo "Puerto UDP : $PORT"
    echo "Proceso"
    line

    ss -lunp | grep "$PORT"

    line

    pause

}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#
#          INFORMACIÓN DEL SERVIDOR            #
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#

system_info() {

    title

    HOST=$(hostname)

    IP=$(curl -4 -s ipv4.icanhazip.com 2>/dev/null)

    OS=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')

    KERNEL=$(uname -r)

    UPTIME=$(uptime -p)

    RAM=$(free -h | awk '/Mem:/ {print $3" / "$2}')

    DISK=$(df -h / | awk 'NR==2 {print $3" / "$2" ("$5")"}')

    CPU=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | sed 's/^ //')

    CORES=$(nproc)

    echo
    echo " Hostname : $HOST"
    echo " Sistema  : $OS"
    echo " Kernel   : $KERNEL"
    echo " CPU      : $CPU"
    echo " Núcleos  : $CORES"
    echo " Memoria  : $RAM"
    echo " Disco    : $DISK"
    echo " Uptime   : $UPTIME"
    echo " IPv4     : ${IP:-No disponible}"

    line

    echo "Carga del sistema"

    uptime

    line

    pause

}
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#
#                 MENÚ PRINCIPAL               #
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#

while true; do

    setup_expiration

    setup_limite

    # Limpieza automática de contraseñas vencidas
    if [[ -f "$ZIVPN_EXP_FILE" ]]; then
        NOW=$(date +%s)
        while IFS='|' read -r PASS EXP; do
            [[ -z "$PASS" ]] && continue
            if [[ "$EXP" != "0" && -n "$EXP" && "$EXP" -le "$NOW" ]]; then
                jq --arg p "$PASS" '.auth.config |= map(select(. != $p))' /etc/zivpn/config.json > /tmp/zivpn-exp.json 2>/dev/null && mv /tmp/zivpn-exp.json /etc/zivpn/config.json
                awk -F'|' -v p="$PASS" '$1!=p' "$ZIVPN_EXP_FILE" > /tmp/zivpn-exp.tmp 2>/dev/null && mv /tmp/zivpn-exp.tmp "$ZIVPN_EXP_FILE"
                systemctl restart zivpn
            fi
        done < "$ZIVPN_EXP_FILE"
    fi

    title

    if systemctl is-active --quiet zivpn; then
        STATUS="${GREEN}🟢 ACTIVO${RESET}"
    else
        STATUS="${RED}🔴 DETENIDO${RESET}"
    fi

    if [[ -f /etc/zivpn/config.json ]]; then
        PORT=$(jq -r '.listen' /etc/zivpn/config.json | tr -d ':')
    else
        PORT="No instalado"
    fi

    VERSION="-"

    if [[ -x /usr/local/bin/zivpn ]]; then
        VERSION=$(/usr/local/bin/zivpn version 2>/dev/null | head -n1)
        [[ -z "$VERSION" ]] && VERSION="1.4.9"
    fi

    ARCH=$(uname -m)
printf "${CYAN}║${RESET} Estado       : %-29b ${CYAN}║${RESET}\n" "$STATUS"
printf "${CYAN}║${RESET} Servicio     : %-29s ${CYAN}║${RESET}\n" "zivpn"
printf "${CYAN}║${RESET} Puerto UDP   : %-29s ${CYAN}║${RESET}\n" "$PORT"
printf "${CYAN}║${RESET} Arquitectura : %-29s ${CYAN}║${RESET}\n" "$ARCH"
printf "${CYAN}║${RESET} Versión      : %-29s ${CYAN}║${RESET}\n" "$VERSION"
echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"

    echo

    if [[ "$ZIPVPN" == "ON" ]]; then

cat <<EOF
 [1] Reinstalar ZiVPN
 [2] Reiniciar Servicio
 [3] Estado del Servicio
 [4] Agregar Contraseña
 [5] Eliminar Contraseña
 [6] Listar Contraseñas
 [7] Asignar Caducidad
 [8] Eliminar Vencidas
 [9] Asignar Límite GB
 [10] Consumo y Bloqueos
 [11] Ver Logs
 [12] Diagnóstico
 [13] Información del Servidor
 [14] Desinstalar ZiVPN
 [0] Regresar
EOF

    else

cat <<EOF
 [1] Instalar ZiVPN
 [0] Regresar
EOF

    fi

    line

    read -rp "Seleccione una opción: " OP

    case "$OP" in

        1)
            install_zivpn
        ;;

        2)
            restart_zivpn
        ;;

        3)
            status_zivpn
        ;;

        4)
            add_zivpn_password
        ;;

        5)
            remove_zivpn_password
        ;;

        6)
            list_zivpn_passwords
        ;;

        7)
            expira_password
        ;;

        8)
            clean_expired
        ;;

        9)
            limita_password
        ;;

        10)
            consumo_zivpn
        ;;

        11)
            view_zivpn_logs
        ;;

        12)
            check_zivpn
        ;;

        13)
            system_info
        ;;

        14)
            remove_zivpn
        ;;

        0)
            if [[ "$FROM_MAIN" == "1" ]]; then
                exec bash "$BASE/menu.sh"
            else
                exec bash "$BASE/protocolos/menu.sh"
            fi
        ;;

        *)
            error "Opción inválida."
            sleep 2
        ;;

    esac

done
