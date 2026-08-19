#!/bin/bash

BASE="/etc/movivip"

CYAN="\e[1;96m"
GREEN="\e[1;92m"
RED="\e[1;91m"
MAGENTA="\e[1;95m"
WHITE="\e[1;97m"
RESET="\e[0m"

abrir(){

read -rp "Puerto: " PORT

read -rp "Protocolo [tcp/udp/ambos]: " PROTO

PROTO=$(echo "$PROTO" | tr '[:upper:]' '[:lower:]')

case "$PROTO" in
tcp)
    iptables -C INPUT -p tcp --dport "$PORT" -j ACCEPT 2>/dev/null \
        || iptables -A INPUT -p tcp --dport "$PORT" -j ACCEPT
    ;;
udp)
    iptables -C INPUT -p udp --dport "$PORT" -j ACCEPT 2>/dev/null \
        || iptables -A INPUT -p udp --dport "$PORT" -j ACCEPT
    ;;
ambos|both)
    iptables -C INPUT -p tcp --dport "$PORT" -j ACCEPT 2>/dev/null \
        || iptables -A INPUT -p tcp --dport "$PORT" -j ACCEPT
    iptables -C INPUT -p udp --dport "$PORT" -j ACCEPT 2>/dev/null \
        || iptables -A INPUT -p udp --dport "$PORT" -j ACCEPT
    ;;
*)
    iptables -C INPUT -p tcp --dport "$PORT" -j ACCEPT 2>/dev/null \
        || iptables -A INPUT -p tcp --dport "$PORT" -j ACCEPT
    ;;
esac

if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
    ufw allow "$PORT/$PROTO" >/dev/null 2>&1
fi

echo ""
echo -e "${GREEN}âœ… Puerto $PORT ($PROTO) abierto.${RESET}"

sleep 2

}

cerrar(){

read -rp "Puerto: " PORT

read -rp "Protocolo [tcp/udp/ambos]: " PROTO

PROTO=$(echo "$PROTO" | tr '[:upper:]' '[:lower:]')

case "$PROTO" in
tcp)
    iptables -D INPUT -p tcp --dport "$PORT" -j ACCEPT 2>/dev/null
    ;;
udp)
    iptables -D INPUT -p udp --dport "$PORT" -j ACCEPT 2>/dev/null
    ;;
ambos|both|*)
    iptables -D INPUT -p tcp --dport "$PORT" -j ACCEPT 2>/dev/null
    iptables -D INPUT -p udp --dport "$PORT" -j ACCEPT 2>/dev/null
    ;;
esac

if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
    ufw delete allow "$PORT/$PROTO" >/dev/null 2>&1
fi

echo ""
echo -e "${GREEN}âœ… Puerto $PORT ($PROTO) cerrado.${RESET}"

sleep 2

}

estado(){

clear

echo -e "${CYAN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${RESET}"
echo -e "${MAGENTA}            ðŸ”¥ FIREWALL${RESET}"
echo -e "${CYAN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${RESET}"
echo ""

echo -e "${WHITE}ðŸ“‹ Reglas iptables INPUT:${RESET}"
echo ""

iptables -L INPUT -n --line-numbers 2>/dev/null | head -30

if command -v ufw >/dev/null 2>&1; then
    echo ""
    echo -e "${WHITE}ðŸ“‹ Estado UFW:${RESET}"
    echo ""
    ufw status numbered 2>/dev/null
fi

echo ""
read -n1 -r -p "Presione una tecla..."

}

while true
do

clear

echo -e "${CYAN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${RESET}"
echo -e "${MAGENTA}            ðŸ”¥ FIREWALL${RESET}"
echo -e "${CYAN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${RESET}"

echo ""
echo " [1] âž® Abrir Puerto"
echo " [2] âž® Cerrar Puerto"
echo " [3] âž® Estado Firewall"
echo ""
echo " [0] âž® Regresar"
echo ""

echo -e "${CYAN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${RESET}"

read -rp " â–º OpciÃ³n: " OP

case "$OP" in

1)
abrir
;;

2)
cerrar
;;

3)
estado
;;

0)
exec bash "$BASE/herramientas/menu.sh"
;;

*)
echo ""
echo -e "${RED}âŒ OpciÃ³n invÃ¡lida.${RESET}"
sleep 2
;;

esac

done
