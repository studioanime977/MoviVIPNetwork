#!/bin/bash

# ── i18n shim (auto) ───────────────────────────────
if ! declare -F trx >/dev/null 2>&1; then trx() { printf '%s' "$1"; }; fi
# ─────────────────────────────────────────────────────────

BASE="/etc/movivip"
CONFIG="$BASE/config.conf"

source "$CONFIG"

# Cargar idioma
if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)"
fi

CYAN="\e[1;96m"
GREEN="\e[1;92m"
RED="\e[1;91m"
WHITE="\e[1;97m"
RESET="\e[0m"

# Navegación con flechitas
[[ -f "$BASE/lib/nav.sh" ]] && source "$BASE/lib/nav.sh"

# Sistema de animación/progreso + detección de estado
[[ -f "$BASE/lib/anim.sh" ]] && source "$BASE/lib/anim.sh"

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#
#        MODO CLI (automatización/headless)      #
#  bash systemdns.sh --install | --remove |      #
#       --status | --restart                     #
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#
case "${1:-}" in
    --install)
        if [[ "$SYSTEMDNS" != "ON" ]]; then
            anim_step "Instalando System DNS"
            svc_restart_anim systemd-resolved "Arrancando systemd-resolved"
            sed -i 's/SYSTEMDNS=OFF/SYSTEMDNS=ON/' "$CONFIG"
            SYSTEMDNS=ON
            echo ""
            echo "$(trx '✅ System DNS instalado.')"
        else
            echo "$(trx '✅ System DNS ya estaba activo.')"
        fi
        exit 0
        ;;
    --remove)
        if [[ "$SYSTEMDNS" == "ON" ]]; then
            anim_step "Desinstalando System DNS"
            anim_run "Detener y deshabilitar" bash -c "systemctl stop systemd-resolved; systemctl disable systemd-resolved"
            sed -i 's/SYSTEMDNS=ON/SYSTEMDNS=OFF/' "$CONFIG"
            SYSTEMDNS=OFF
            echo ""
            echo "$(trx '✅ System DNS desinstalado.')"
        else
            echo "$(trx '⏭ System DNS ya estaba desactivado.')"
        fi
        exit 0
        ;;
    --status)
        echo "SYSTEMDNS=$SYSTEMDNS (config.conf)"
        if [[ "$SYSTEMDNS" == "ON" ]]; then
            systemctl status systemd-resolved --no-pager 2>&1 | head -15
        else
            echo "Servicio systemd-resolved: $(systemctl is-active systemd-resolved 2>/dev/null || echo unknown)"
        fi
        exit 0
        ;;
    --restart)
        svc_restart_anim systemd-resolved "Reiniciando systemd-resolved"
        exit 0
        ;;
    ""|*) ;;
esac

while true; do

clear

mv_header "🌐 System DNS Manager" "$(trx 'Resolución DNS · systemd-resolved')" "v6.2"
movivip_contacts 2>/dev/null || true

if [[ "$SYSTEMDNS" == "ON" ]]; then
    ESTADO="${GREEN}🟢 ACTIVO${RESET}"
else
    ESTADO="${RED}🔴 DESINSTALADO${RESET}"
fi

echo -e " Estado     : $ESTADO"
echo -e "$(trx ' Puerto     : 53')"
echo -e "$(trx ' Servicio   : systemd-resolved')"

echo ""

if [[ "$SYSTEMDNS" == "ON" ]]; then
    LBL=("Desinstalar System DNS" "Reiniciar Servicio" "Ver Estado")
else
    LBL=("Instalar System DNS")
fi
SEL=$(nav_pick "► Opción:" "${LBL[@]}" "↩ Regresar") || SEL=0
[[ $SEL -eq $((${#LBL[@]}+1)) ]] && SEL=0
OP="$SEL"

case "$OP" in

1)

if [[ "$SYSTEMDNS" == "ON" ]]; then

read -rp "$(trx '¿Desinstalar System DNS? (s/n): ')" R
[[ "$R" != "s" ]] && continue

anim_step "Desinstalando System DNS"
anim_run "Detener y deshabilitar" bash -c "systemctl stop systemd-resolved; systemctl disable systemd-resolved"

sed -i 's/SYSTEMDNS=ON/SYSTEMDNS=OFF/' "$CONFIG"
SYSTEMDNS=OFF

echo ""
echo "$(trx '✅ System DNS desinstalado.')"

sleep 2

else

anim_step "Instalando System DNS"
svc_restart_anim systemd-resolved "Arrancando systemd-resolved"

sed -i 's/SYSTEMDNS=OFF/SYSTEMDNS=ON/' "$CONFIG"
SYSTEMDNS=ON

echo ""
echo "$(trx '✅ System DNS instalado.')"

sleep 2

fi

;;

2)

if [[ "$SYSTEMDNS" == "ON" ]]; then

svc_restart_anim systemd-resolved "Reiniciando systemd-resolved"

echo ""
echo "$(trx '✅ Servicio reiniciado.')"

sleep 2

fi

;;

3)

if [[ "$SYSTEMDNS" == "ON" ]]; then

systemctl status systemd-resolved --no-pager

echo ""
read -n1 -r -p "$(trx 'Presione una tecla...')"

fi

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
