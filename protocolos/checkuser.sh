#!/bin/bash      
      
#==================================================      
# MoviVIP Network      
# CheckUser      
#==================================================      
      
BASE="/etc/movivip"      

# Cargar idioma
if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)"
fi

GREEN="\e[1;92m"      
RED="\e[1;91m"      
YELLOW="\e[1;93m"      
BLUE="\e[1;94m"      
CYAN="\e[1;96m"      
MAGENTA="\e[1;95m"      
WHITE="\e[1;97m"      
RESET="\e[0m"      
      
check_installed() {      
    [[ -f /usr/lib/chall/chall.sh ]]      
}      
status_checkuser() {      
    if [[ -f /usr/lib/chall/chall.sh ]]; then      
        echo -e "${GREEN}🟢 ACTIVO${RESET}"      
    else      
        echo -e "${RED}🔴 OFF${RESET}"      
    fi      
}      
      #===============================
# ONLINE APP
#===============================

function onapp1() {
    clear
    echo -e "\n\033[1;32mINICIANDO O ONLINE APP... \033[0m"
    echo ""

    apt install apache2 -y > /dev/null 2>&1

    sed -i "s/Listen 80/Listen 8888/g" /etc/apache2/ports.conf >/dev/null 2>&1

    service apache2 restart

    rm -rf /var/www/html/server >/dev/null 2>&1
    mkdir -p /var/www/html/server >/dev/null 2>&1

    chmod +x "$BASE/protocolos/onlineapp"
screen -dmS onlineapp "$BASE/protocolos/onlineapp"
sleep 3

    if [[ $(grep -wc "onlineapp" /etc/autostart) = '0' ]]; then
        echo "ps x | grep '$BASE/protocolos/onlineapp' | grep -v grep >/dev/null || screen -dmS onlineapp $BASE/protocolos/onlineapp" >> /etc/autostart
    else
        sed -i '/onlineapp/d' /etc/autostart
        echo "ps x | grep '$BASE/protocolos/onlineapp' | grep -v grep >/dev/null || screen -dmS onlineapp $BASE/protocolos/onlineapp" >> /etc/autostart
    fi

    IP=$(wget -qO- ipv4.icanhazip.com)

    echo ""
    echo -e "\033[1;32mONLINE APP ATIVO!\033[0m"
    echo -e "\033[1;33mURL de Usuários Online:\033[0m"
    echo "http://$IP:8888/server/online"

    sleep 10
    
}

function onapp2() {
    clear
    echo -e "\n\033[1;31mPARANDO O ONLINE APP... \033[0m"
    echo ""

    fun_stponlineapp() {

        service apache2 stop >/dev/null 2>&1

        screen -S onlineapp -X quit >/dev/null 2>&1
        pkill -f "$BASE/protocolos/onlineapp" >/dev/null 2>&1

        screen -wipe >/dev/null 2>&1

        sed -i '/onlineapp/d' /etc/autostart

        rm -rf /var/www/html/server >/dev/null 2>&1
    }

    fun_stponlineapp
sleep 3

    echo ""
    echo -e "\033[1;31mONLINE APP PARADO!\033[0m"

    sleep 3
    
}

function onapp_ssh() {
    if pgrep -f "onlineapp" >/dev/null; then
        onapp2
    else
        onapp1
    fi
}

# Navegación con flechitas
[[ -f "$BASE/lib/nav.sh" ]] && source "$BASE/lib/nav.sh"

while true; do
    clear

    CHECKUSER_STATUS=$(status_checkuser)

    movivip_sub_header "🛡 MENÚ CHECKUSER"

    printf " Estado    : %b\n" "$CHECKUSER_STATUS"

    echo ""

    LBL=("CheckUser Multi-Apps" "CheckUser DTunnel" "CheckUser DTunnel-Go" "Online App")
    SEL=$(nav_pick "► Opción:" "${LBL[@]}" "↩ Regresar") || SEL=0
    [[ $SEL -eq 5 ]] && SEL=0
    OP="$SEL"

    case "$OP" in
      
        1|01)      
            if check_installed; then      
                chall      
            else      
                bash <(curl -sL https://raw.githubusercontent.com/PhoenixxZ2023/checkUser2024/main/instcheck.sh)      
                [[ -x "$(command -v chall)" ]] && chall      
            fi      
        ;;      
      
        2|02)      
            bash <(curl -sL https://raw.githubusercontent.com/PhoenixxZ2023/DTCheckUser/master/install.sh)      
        ;;      
      
        3|03)      
            bash <(curl -sL https://n9.cl/yo2nc)      
        ;;      
      
        4|04)      
    onapp_ssh     
;;      
      
        0|00)      
            exec bash "$BASE/protocolos/menu.sh"      
        ;;      
      
        *)      
            echo      
            echo -e "${RED}❌ Opción inválida.${RESET}"      
            sleep 2      
        ;;      
    esac      
done      
