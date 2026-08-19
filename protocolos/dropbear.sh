#!/bin/bash

#â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”#
#           MoviVIP Network             #
#             DROPBEAR MANAGER                 #
#â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”#

BASE="/etc/movivip"
CONFIG="$BASE/config.conf"

# Cargar funciones multi-distro
[[ -f "$BASE/functions/pkg.sh" ]] && source "$BASE/functions/pkg.sh"

[[ ! -f "$CONFIG" ]] && {
    echo "No se encontrÃ³ el archivo de configuraciÃ³n."
    exit 1
}

source "$CONFIG"

# ðŸŒ Multi-idioma
if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)"
fi
if [[ -f "$BASE/languages/protocols.sh" ]]; then
    source "$BASE/languages/protocols.sh"
fi

# ðŸ”‘ GATE DE LICENCIA â€” validaciÃ³n EN VIVO contra Firebase
bash /etc/movivip/check-licencia.sh || exit 1

#â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”#
#                  COLORES                     #
#â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”#

CYAN="\e[1;96m"
GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"
RESET="\e[0m"

SERVICE="dropbear_custom"

#â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”#
#                  FUNCIONES                   #
#â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”#

line() {
    echo -e "${CYAN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${RESET}"
}

ok() {
    echo -e "${GREEN}âœ” $1${RESET}"
}

error() {
    echo -e "${RED}âœ˜ $1${RESET}"
}

info() {
    echo -e "${CYAN}âžœ $1${RESET}"
}

pause() {
    echo ""
    read -n1 -r -p "Presione una tecla para continuar..."
}

#â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”#
#             OBTENER INFORMACIÃ“N              #
#â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”#

get_status() {

    if systemctl is-active --quiet "$SERVICE"; then
        STATUS="${GREEN}ðŸŸ¢ ACTIVO${RESET}"
    else
        STATUS="${RED}ðŸ”´ DETENIDO${RESET}"
    fi

}

get_ports() {

    PORTS=$(systemctl cat "$SERVICE" 2>/dev/null | \
        grep ExecStart | \
        grep -oP '(?<=-p )\d+' | \
        paste -sd "," -)

    [[ -z "$PORTS" ]] && PORTS="-"

}

#â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”#
#             INSTALAR DROPBEAR                #
#â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”#

install_dropbear() {

    clear
    line
    echo -e "${WHITE}        INSTALAR DROPBEAR${RESET}"
    line

    # Puertos predeterminados
    PORTS="90,143,109"

    IFS=',' read -ra PORT_ARRAY <<< "$PORTS"

    for PORT in "${PORT_ARRAY[@]}"; do

        if ss -lnt | awk '{print $4}' | grep -q ":$PORT$"; then
            error "El puerto $PORT ya estÃ¡ en uso."
            pause
            return
        fi

    done

    info "Actualizando repositorios..."
    pkg_update

    info "Instalando Dropbear..."
    pkg_install dropbear

    # Abrir puertos 90/143/109 TCP + NAT (salida a internet)
    if [[ -f "$BASE/herramientas/openports.sh" ]]; then
        source "$BASE/herramientas/openports.sh"
        open_ports "TCP:90,143,109"
    else
        sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1
        for P in 90 143 109; do
            iptables -C INPUT -p tcp --dport "$P" -j ACCEPT 2>/dev/null \
                || iptables -A INPUT -p tcp --dport "$P" -j ACCEPT
        done
        DEV=$(ip -4 route show default | awk '{print $5}' | head -1)
        [[ -n "$DEV" ]] && {
            iptables -t nat -C POSTROUTING -o "$DEV" -j MASQUERADE 2>/dev/null \
                || iptables -t nat -A POSTROUTING -o "$DEV" -j MASQUERADE
        }
    fi

    mkdir -p /etc/dropbear

    if [[ ! -f /etc/dropbear/dropbear_rsa_host_key ]]; then
        info "Generando llave RSA..."
        dropbearkey -t rsa \
            -f /etc/dropbear/dropbear_rsa_host_key
    fi

    if [[ ! -f /etc/dropbear/dropbear_ecdsa_host_key ]]; then
        info "Generando llave ECDSA..."
        dropbearkey -t ecdsa \
            -f /etc/dropbear/dropbear_ecdsa_host_key
    fi

   

    systemctl stop dropbear 2>/dev/null
    systemctl disable dropbear 2>/dev/null

    EXEC="/usr/sbin/dropbear -F"

    for PORT in "${PORT_ARRAY[@]}"; do
        EXEC="$EXEC -p $PORT"
    done

    EXEC="$EXEC -W 65536 -b /etc/issue.net"

cat > /etc/systemd/system/dropbear_custom.service <<EOF
[Unit]
Description=MoviVIP Dropbear Multi-Port
After=network.target

[Service]
Type=simple
ExecStart=$EXEC
Restart=always
RestartSec=3
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable dropbear_custom
    systemctl restart dropbear_custom

    if systemctl is-active --quiet dropbear_custom; then

        if grep -q "^DROPBEAR=" "$CONFIG"; then
            sed -i 's/^DROPBEAR=.*/DROPBEAR=ON/' "$CONFIG"
        else
            echo "DROPBEAR=ON" >> "$CONFIG"
        fi

        if grep -q "^DROPBEAR_PORT=" "$CONFIG"; then
            sed -i "s/^DROPBEAR_PORT=.*/DROPBEAR_PORT=\"$PORTS\"/" "$CONFIG"
        else
            echo "DROPBEAR_PORT=\"$PORTS\"" >> "$CONFIG"
        fi

        source "$CONFIG"

        line
        ok "Dropbear instalado correctamente."
        echo ""
        echo " Servicio : dropbear_custom"
        echo " Puertos  : $PORTS"
        echo " Banner   : $BANNER"
        line

    else

        error "No fue posible iniciar Dropbear."

    fi

    pause

}

#â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”#
#            REINICIAR SERVICIO                #
#â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”#

restart_dropbear() {

    systemctl restart dropbear_custom

    if systemctl is-active --quiet dropbear_custom; then
        ok "Servicio reiniciado correctamente."
    else
        error "No fue posible reiniciar el servicio."
    fi

    pause

}

#â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”#
#             INFORMACIÃ“N COMPLETA             #
#â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”#

status_dropbear() {

    clear

    get_status
    get_ports

    line
    echo -e "${WHITE}          ESTADO DROPBEAR${RESET}"
    line

    echo "Estado      : $STATUS"
    echo "Servicio    : dropbear_custom"
    echo "Puertos     : $PORTS"
    echo "Banner      : /etc/issue.net"

    echo ""

    echo "Proceso"

    systemctl status dropbear_custom --no-pager -l

    pause

}
#â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”#
#            DESINSTALAR DROPBEAR              #
#â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”#

remove_dropbear() {

    clear
    line
    echo -e "${WHITE}       DESINSTALAR DROPBEAR${RESET}"
    line
    echo ""

    read -rp "Â¿Desea continuar? [s/N]: " R

    [[ ! "$R" =~ ^[Ss]$ ]] && return

    info "Deteniendo servicios..."

    systemctl stop dropbear_custom 2>/dev/null
    systemctl disable dropbear_custom 2>/dev/null

    systemctl stop dropbear 2>/dev/null
    systemctl disable dropbear 2>/dev/null

    info "Eliminando servicio personalizado..."

    rm -f /etc/systemd/system/dropbear_custom.service

    systemctl daemon-reload
    systemctl reset-failed

    info "Desinstalando paquete..."

    pkg_remove dropbear

    pkg_clean >/dev/null 2>&1

    info "Limpiando archivos..."

    rm -rf /etc/dropbear
    

    if grep -q "^DROPBEAR=" "$CONFIG"; then
        sed -i 's/^DROPBEAR=.*/DROPBEAR=OFF/' "$CONFIG"
    else
        echo "DROPBEAR=OFF" >> "$CONFIG"
    fi

    sed -i '/^DROPBEAR_PORT=/d' "$CONFIG"

    source "$CONFIG"

    line
    ok "Dropbear fue eliminado correctamente."
    line

    pause

}

#â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”#
#          VERIFICAR CONFIGURACIÃ“N             #
#â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”#

check_dropbear() {

    clear

    line
    echo -e "${WHITE}      DIAGNÃ“STICO DROPBEAR${RESET}"
    line

    echo ""

    if command -v dropbear >/dev/null 2>&1; then
        ok "Dropbear instalado"
    else
        error "Dropbear no instalado"
    fi

    if systemctl is-active --quiet dropbear_custom; then
        ok "Servicio activo"
    else
        error "Servicio detenido"
    fi

    if [[ -f /etc/systemd/system/dropbear_custom.service ]]; then
        ok "Servicio personalizado encontrado"
    else
        error "Servicio personalizado no existe"
    fi

    if [[ -f /etc/dropbear/dropbear_rsa_host_key ]]; then
        ok "Llave RSA encontrada"
    else
        error "Llave RSA inexistente"
    fi

    if [[ -f /etc/dropbear/dropbear_ecdsa_host_key ]]; then
        ok "Llave ECDSA encontrada"
    else
        error "Llave ECDSA inexistente"
    fi

    if [[ -f /etc/issue.net ]]; then
        ok "Banner encontrado"
    else
        error "Banner inexistente"
    fi

    echo ""
    info "Puertos escuchando"

    ss -lntp | grep dropbear

    pause

}

#â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”#
#          VER INFORMACIÃ“N DEL SISTEMA         #
#â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”#

system_info() {

    clear

    line
    echo -e "${WHITE}        INFORMACIÃ“N DEL SERVIDOR${RESET}"
    line

    echo ""

    echo "Hostname : $(hostname)"
    echo "Kernel   : $(uname -r)"
    echo "Sistema  : $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')"

    echo ""

    echo "IP Local"

    hostname -I

    echo ""

    echo "Uso de memoria"

    free -h

    echo ""

    echo "Espacio en disco"

    df -h /

    pause

}

#â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”#
#                  MENÃš                        #
#â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”#

while true; do

    clear

    get_status
    get_ports

    line
    echo -e "${WHITE}            ðŸ” DROPBEAR MANAGER${RESET}"
    line

    echo -e " Estado     : $STATUS"
    echo -e " Servicio   : $SERVICE"
    echo -e " Puertos    : $PORTS"
    echo -e " Instalado  : ${DROPBEAR:-OFF}"

    line

    if [[ "$DROPBEAR" == "ON" ]]; then

        cat <<EOF
 [1] Reinstalar Dropbear
 [2] Reiniciar Servicio
 [3] Estado del Servicio
 [4] DiagnÃ³stico
 [5] InformaciÃ³n del Servidor
 [6] Desinstalar Dropbear
 [0] Regresar
EOF

    else

        cat <<EOF
 [1] Instalar Dropbear
 [0] Regresar
EOF

    fi

    line

    read -rp " â–º OpciÃ³n: " OP

case "$OP" in

1)
    install_dropbear
;;

2)
    restart_dropbear
;;

3)
    status_dropbear
;;

4)
    check_dropbear
;;

5)
    system_info
;;

6)
    remove_dropbear
;;

0)
    exec bash "$BASE/protocolos/menu.sh"
;;

*)
    error "OpciÃ³n invÃ¡lida."
    sleep 2
;;

esac
done
