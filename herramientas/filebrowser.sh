#!/bin/bash
#==================================================
# MoviVIP Network Premium v5.7 - FILE BROWSER WEB
# Gestor de archivos web oficial (filebrowser/filebrowser, Go)
#   · Binario único, sin dependencias
#   · Servicio systemd · puerto configurable
#   · Usuario admin con password aleatoria segura
#   · Alcance: /root + /home (raíz configurable)
#==================================================

BASE="/etc/movivip"
CONFIG="$BASE/config.conf"
[[ -f "$CONFIG" ]] && source "$CONFIG"

FB_BIN="/usr/local/bin/filebrowser"
FB_DIR="/etc/filebrowser"
FB_DB="$FB_DIR/filebrowser.db"
FB_SVC="movivip-filebrowser"
FB_PORT="${FB_PORT:-8095}"
FB_ROOT="${FB_ROOT:-/}"

CYAN="\e[1;96m"; GREEN="\e[1;92m"; RED="\e[1;91m"
GOLD="\e[1;93m"; MAGENTA="\e[1;95m"; WHITE="\e[1;97m"; GRAY="\e[1;90m"; RESET="\e[0m"

fb_installed(){ [[ -x "$FB_BIN" && -f "$FB_DB" ]]; }

arch_bin(){
    case "$(uname -m)" in
        x86_64) echo "linux-amd64" ;;
        aarch64|arm64) echo "linux-arm64" ;;
        armv7l) echo "linux-armv7" ;;
        *) echo "linux-amd64" ;;
    esac
}

install_fb(){
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${MAGENTA}       📂 INSTALAR FILE BROWSER${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    read -rp " ► Puerto web [$FB_PORT]: " P
    [[ "$P" =~ ^[0-9]+$ ]] && (( P >= 1024 && P <= 65535 )) && FB_PORT=$P
    ss -tln | grep -q ":$FB_PORT " && {
        echo -e " ${RED}❌ Puerto $FB_PORT ya está en uso${RESET}"; sleep 3; return; }
    read -rp " ► Raíz visible [/ (todo el sistema) o /home (solo homes)]: " R
    [[ -d "$R" ]] && FB_ROOT="$R"

    echo -e "${GRAY} ⚙ Descargando binario...${RESET}"
    local VER URL TMP="/tmp/fb-install"
    rm -rf "$TMP"; mkdir -p "$TMP"
    VER=$(curl -4 -s --max-time 8 https://api.github.com/repos/filebrowser/filebrowser/releases/latest \
          | grep -oE '"tag_name": *"[^"]+"' | cut -d'"' -f4)
    [[ -z "$VER" ]] && VER="v2.32.0"
    URL="https://github.com/filebrowser/filebrowser/releases/download/${VER}/filebrowser-${VER}-$(arch_bin).tar.gz"
    curl -4 -L --max-time 120 -o "$TMP/fb.tgz" "$URL" || {
        echo -e "${RED}❌ Falló la descarga${RESET}"; sleep 3; return; }
    tar -xzf "$TMP/fb.tgz" -C "$TMP" || { echo -e "${RED}❌ tar falló${RESET}"; sleep 3; return; }
    install -m 0755 "$TMP"/filebrowser "$FB_BIN" 2>/dev/null || \
        mv "$TMP"/filebrowser "$FB_BIN"
    chmod +x "$FB_BIN"
    rm -rf "$TMP"

    mkdir -p "$FB_DIR"
    [[ -f "$FB_DB" ]] || filebrowser -d "$FB_DB" config init >/dev/null 2>&1
    filebrowser -d "$FB_DB" config set --address 0.0.0.0 --port "$FB_PORT" --root "$FB_ROOT" >/dev/null 2>&1

    FBPASS=$(tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 14)
    if filebrowser -d "$FB_DB" users ls 2>/dev/null | grep -q admin; then
        filebrowser -d "$FB_DB" users update admin --password "$FBPASS" >/dev/null 2>&1
    else
        filebrowser -d "$FB_DB" users add admin "$FBPASS" --perm.admin >/dev/null 2>&1
    fi

    cat > "/etc/systemd/system/${FB_SVC}.service" <<EOF
[Unit]
Description=MoviVIP File Browser Web
After=network.target

[Service]
Type=simple
User=root
ExecStart=${FB_BIN} -d ${FB_DB}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --now "$FB_SVC" >/dev/null 2>&1
    sed -i '/^FILEBROWSER=/d; /^FB_PORT=/d; /^FB_ROOT=/d' "$CONFIG"
    { echo "FILEBROWSER=ON"; echo "FB_PORT=$FB_PORT"; echo "FB_ROOT=$FB_ROOT"; } >> "$CONFIG"

    IP=$(curl -4 -s --max-time 5 ifconfig.me)
    echo ""
    echo -e " ${GREEN}✅ File Browser instalado${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "   URL      : ${WHITE}http://$IP:$FB_PORT${RESET}"
    echo -e "   Usuario  : ${WHITE}admin${RESET}"
    echo -e "   Password : ${GOLD}$FBPASS${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    read -n1 -r -p " Presione una tecla..."
}

uninstall_fb(){
    clear
    read -rp " ► Desinstalar File Browser? (s/N): " R
    [[ "$R" =~ ^[sS]$ ]] || return
    systemctl disable --now "$FB_SVC" 2>/dev/null
    rm -f "/etc/systemd/system/${FB_SVC}.service"
    systemctl daemon-reload
    rm -rf "$FB_DIR" "$FB_BIN"
    sed -i '/^FILEBROWSER=/d; /^FB_PORT=/d; /^FB_ROOT=/d' "$CONFIG"
    echo "FILEBROWSER=OFF" >> "$CONFIG"
    echo -e " ${GREEN}✅ File Browser desinstalado${RESET}"
    sleep 2
}

reset_pass(){
    fb_installed || return
    FBPASS=$(tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 14)
    filebrowser -d "$FB_DB" users update admin --password "$FBPASS" >/dev/null 2>&1
    systemctl restart "$FB_SVC"
    echo -e " Password admin nueva: ${GOLD}$FBPASS${RESET}"
    sleep 4
}

#──────────────────────────────────────────────
# MENÚ PRINCIPAL
#──────────────────────────────────────────────
while true
do
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${MAGENTA}         📂 FILE BROWSER WEB v5.7${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    if systemctl is-active --quiet "$FB_SVC" 2>/dev/null; then
        S="${GREEN}● ACTIVO${RESET} ${GRAY}[web $FB_PORT]${RESET}"
    elif fb_installed; then
        S="${RED}● DETENIDO${RESET}"
    else
        S="${GRAY}○ SIN INSTALAR${RESET}"
    fi

cat <<EOF

 $S

 [1] ➮ Instalar / Reconfigurar
 [2] ➮ Iniciar / Detener (toggle)
 [3] ➮ Estado del Servicio
 [4] ➮ Reset Password Admin
 [5] ➮ Desinstalar

 [0] ➮ Regresar

EOF
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    read -rp " ► Opcion: " OP
    case "$OP" in
        1) install_fb ;;
        2)
            systemctl is-active --quiet "$FB_SVC" && {
                systemctl stop "$FB_SVC"
                sed -i '/^FILEBROWSER=/d' "$CONFIG"; echo "FILEBROWSER=OFF" >> "$CONFIG"
                echo -e " ${GOLD}⚠ Detenido${RESET}"
            } || {
                fb_installed || { install_fb; continue; }
                systemctl start "$FB_SVC"
                sed -i '/^FILEBROWSER=/d' "$CONFIG"; echo "FILEBROWSER=ON" >> "$CONFIG"
                echo -e " ${GREEN}✅ Activo en puerto $FB_PORT${RESET}"
            }
            sleep 2 ;;
        3) systemctl status "$FB_SVC" --no-pager -l | head -12; echo ""; read -n1 -r -p " tecla..." ;;
        4) reset_pass ;;
        5) uninstall_fb ;;
        0) exec bash "$BASE/herramientas/menu.sh" ;;
        *) echo -e "${RED}❌ Opcion invalida.${RESET}"; sleep 1 ;;
    esac
done
