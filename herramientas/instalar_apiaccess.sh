#!/bin/bash
#=========================================================
# MoviVIP Network v6.0 — Gestor del motor apiAccess
# Instala/repara/verifica el daemon API (socket /tmp/admAPI.sock)
# que alimenta funciones avanzadas (bots Telegram, /hwid remoto).
#
# Binario vendido en:  $BASE/bin/apiAccess
# Librería vendida en: $BASE/bin/libstdc++.so.6.0.35 (fix GLIBCXX)
#=========================================================

BASE="${BASE:-/etc/movivip}"
BIN_SRC="$BASE/bin/apiAccess"
LIB_SRC="$BASE/bin/libstdc++.so.6.0.35"

# Colores (fallback si ui.sh no cargó)
MV_R="\e[0m"; MV_RED="\e[1;91m"; MV_GRN="\e[1;92m"; MV_GLD="\e[1;93m"
MV_CYN="\e[1;96m"; MV_WHT="\e[1;97m"; MV_DIM="\e[1;90m"
declare -F mv_line_thin >/dev/null 2>&1 && source "$BASE/lib/ui.sh" 2>/dev/null || true
source "$BASE/lib/nav.sh" 2>/dev/null || true

DEST_DIR="/root/ADMRufu/sbin"
DEST_BIN="$DEST_DIR/apiAccess"
LIBCXX_DIR="/opt/stdcxx/root/usr/lib/x86_64-linux-gnu"
SERVICE="/etc/systemd/system/apiAccess.service"
SOCK="/tmp/admAPI.sock"

api_ok(){
    [[ -S "$SOCK" ]] || return 1
    timeout 3 bash -c "echo '/help' | nc -U $SOCK 2>/dev/null" | grep -q "/" 
}

api_status(){
    if api_ok; then
        printf "${MV_GRN}[● ONLINE]${MV_R}"
    elif [[ -S "$SOCK" ]]; then
        printf "${MV_GLD}[◐ SOCKET]${MV_R}"
    else
        printf "${MV_RED}[○ OFFLINE]${MV_R}"
    fi
}

do_install(){
    clear
    declare -F mv_header >/dev/null 2>&1 && mv_header "API Access" "Motor de bots · socket admAPI" "v6.0" || \
        echo "$(trx '== INSTALADOR apiAccess ==')"

    # 1) Binario fuente
    if [[ ! -x "$BIN_SRC" ]]; then
        echo -e "${MV_RED}✗ No encuentro $BIN_SRC${MV_R}"
        echo -e "${MV_DIM}  El paquete debe incluir bin/apiAccess${MV_R}"
        return 1
    fi

    echo -e "${MV_CYN}▸${MV_R} ${MV_WHT}Instalando binario...${MV_R}"
    mkdir -p "$DEST_DIR"
    install -m 755 "$BIN_SRC" "$DEST_BIN"

    # 2) Fix GLIBCXX si hace falta
    if ldd "$DEST_BIN" 2>/dev/null | grep -q "GLIBCXX_3.4.29.*not found\|not found"; then
        echo -e "${MV_CYN}▸${MV_R} ${MV_WHT}Detectado GLIBCXX faltante → instalando libstdc++ vendida...${MV_R}"
        mkdir -p "$LIBCXX_DIR"
        [[ -f "$LIB_SRC" ]] && install -m 755 "$LIB_SRC" "$LIBCXX_DIR/" \
            && ln -sf "$LIBCXX_DIR/libstdc++.so.6.0.35" "$LIBCXX_DIR/libstdc++.so.6" \
            && ldconfig
    fi

    # 3) Servicio systemd
    echo -e "${MV_CYN}▸${MV_R} ${MV_WHT}Creando servicio systemd...${MV_R}"
    LD_LINE=""
    [[ -d "$LIBCXX_DIR" ]] && LD_LINE="Environment=\"LD_LIBRARY_PATH=$LIBCXX_DIR:/root/ADMRufu/lib\""
    printf '%s\n' \
"[Unit]" \
"Description=MoviVIP apiAccess Engine (admAPI socket)" \
"After=network.target" \
"" \
"[Service]" \
"Type=simple" \
"ExecStart=$DEST_BIN" \
"$LD_LINE" \
"Restart=on-failure" \
"RestartSec=5" \
"" \
"[Install]" \
"WantedBy=multi-user.target" > "$SERVICE"
    systemctl daemon-reload
    systemctl enable -q apiAccess 2>/dev/null

    # 4) Arrancar solo si hay licencia
    if [[ -f /etc/ADMRufuLIC ]]; then
        systemctl restart apiAccess
        sleep 2
        if api_ok; then
            echo -e "${MV_GRN}✔ Motor activo — socket respondiendo${MV_R}"
        else
            echo -e "${MV_GLD}⚠ Servicio iniciado pero socket aún no responde${MV_R}"
            echo -e "${MV_DIM}  Revisa: journalctl -u apiAccess -n 20${MV_R}"
        fi
    else
        echo -e "${MV_GLD}⚠ No existe /etc/ADMRufuLIC (licencia)${MV_R}"
        echo -e "${MV_DIM}  Sin licencia el motor arranca pero el socket no abre.${MV_R}"
        echo -e "${MV_DIM}  Servicio quedará habilitado para cuando exista licencia.${MV_R}"
    fi
    echo ""
    read -rp "$(echo -e "${MV_CYN}➜ ENTER para continuar${MV_R}")"
}

do_stop_start(){
    local ACT="$1"
    clear
    if [[ "$ACT" == "stop" ]]; then
        systemctl stop apiAccess 2>/dev/null
        echo -e "${MV_GLD}⏸ apiAccess detenido${MV_R}"
    else
        [[ -f /etc/ADMRufuLIC ]] || { echo -e "${MV_RED}✗ Falta licencia /etc/ADMRufuLIC${MV_R}"; return 1; }
        systemctl restart apiAccess 2>/dev/null; sleep 2
        if api_ok; then echo -e "${MV_GRN}▶ Motor ONLINE${MV_R}"
        else echo -e "${MV_RED}✗ Socket sin respuesta tras restart${MV_R}"; fi
    fi
    sleep 1
}

do_uninstall(){
    clear
    read -rp "$(echo -e "${MV_RED}¿Eliminar motor apiAccess por completo? (s/N): ${MV_R}")" OK
    [[ "$OK" =~ ^[sS]$ ]] || return 0
    systemctl disable --now apiAccess 2>/dev/null
    rm -f "$SERVICE" "$SOCK"
    rm -rf "/root/ADMRufu"
    systemctl daemon-reload
    echo -e "${MV_GRN}✔ Motor eliminado (binario fuente intacto en $BASE/bin)${MV_R}"
    sleep 1
}

# ── Menú ──
while true; do
    clear
    declare -F mv_header >/dev/null 2>&1 && \
        mv_header "API Access" "Motor bots · /tmp/admAPI.sock" "v6.0" || \
        echo "$(trx '== GESTOR apiAccess ==')"
    ST=$(api_status)
    printf "\n   Estado actual: %b\n\n" "$ST"
    SEL=$(nav_pick "► Opción:" \
        "📦 Instalar / Reparar" \
        "▶ Iniciar / Reiniciar" \
        "⏸ Detener" \
        "🔍 Ver logs (journalctl)" \
        "🗑 Desinstalar" \
        "↩ Volver") || SEL=0
    case "$SEL" in
        1) do_install ;;
        2) do_stop_start start ;;
        3) do_stop_start stop ;;
        4) clear; journalctl -u apiAccess -n 30 --no-pager 2>/dev/null | tail -30; read -rp "$(trx '➜ ENTER ')" ;;
        5) do_uninstall ;;
        0|*) break ;;
    esac
done
