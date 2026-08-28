#!/bin/bash
#==================================================
# MoviVIP Network
# Xray Manager
# Parte 1 - Instalación
#==================================================

GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
BLUE="\e[1;94m"
CYAN="\e[1;96m"
MAGENTA="\e[1;95m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"
RESET="\e[0m"

BASE="/etc/movivip"
CONFIG="$BASE/config.conf"

# Cargar funciones multi-distro
[[ -f "$BASE/functions/pkg.sh" ]] && source "$BASE/functions/pkg.sh"

# Cargar idioma
if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)"
fi

XRAY_DIR="/usr/local/etc/xray"
XRAY_CFG="$XRAY_DIR/config.json"
XRAY_LOG="/var/log/xray/access.log"

#==================================================
# Dependencias
#==================================================

install_xray_dependencies() {

    echo -e "${CYAN}➜ Actualizando repositorios...${RESET}"
    pkg_update

    echo -e "${CYAN}➜ Instalando dependencias...${RESET}"

    pkg_install curl wget unzip jq socat cron bash-completion

}

#==================================================
# Instalar Core
#==================================================

install_xray_core() {

    echo -e "${CYAN}➜ Descargando Xray Core...${RESET}"

    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

    if [[ $? != 0 ]]; then
        echo -e "${RED}✘ Error instalando Xray.${RESET}"
        return 1
    fi

    echo -e "${GREEN}✔ Xray instalado.${RESET}"

}

#==================================================
# Crear Directorios
#==================================================

create_xray_dirs() {

    mkdir -p "$XRAY_DIR"
    mkdir -p /var/log/xray

    touch "$XRAY_LOG"

}

#==================================================
# Configuración Base
#==================================================

create_xray_config() {

cat > "$XRAY_CFG" <<EOF
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/xray/access.log"
  },

  "api": {
    "tag": "api",
    "listen": "127.0.0.1:10085",
    "services": [
      "HandlerService",
      "LoggerService",
      "StatsService"
    ]
  },

  "stats": {},

  "policy": {
    "levels": {
      "0": {
        "statsUserUplink": true,
        "statsUserDownlink": true
      }
    },
    "system": {
      "statsInboundUplink": true,
      "statsInboundDownlink": true
    }
  },

  "inbounds": [

    {
      "tag": "vmess-in",
      "port": 10002,
      "listen": "127.0.0.1",
      "protocol": "vmess",

      "settings": {
        "clients": []
      },

      "streamSettings": {
        "network": "ws",

        "wsSettings": {
          "path": "/vmess"
        }
      },

      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls"
        ]
      }

    }

  ],

  "outbounds": [

    {
      "protocol":"freedom",
      "tag":"direct"
    },

    {
      "protocol":"blackhole",
      "tag":"block"
    }

  ],

  "routing": {
    "rules": [
      {
        "type": "field",
        "inboundTag": [
          "api"
        ],
        "outboundTag": "api"
      }
    ]
  }

}
EOF

}

#==================================================
# Migrar config existente a API de estadísticas
# (preserva los clientes ya creados con jq)
#==================================================

ensure_xray_api_config() {

    [[ -f "$XRAY_CFG" ]] || return 0

    command -v jq >/dev/null 2>&1 || return 0

    if jq -e '.api' "$XRAY_CFG" >/dev/null 2>&1; then
        return 0
    fi

    jq '
        .api = {"tag":"api","listen":"127.0.0.1:10085","services":["HandlerService","LoggerService","StatsService"]}
        | .stats = {}
        | .policy = {"levels":{"0":{"statsUserUplink":true,"statsUserDownlink":true}},"system":{"statsInboundUplink":true,"statsInboundDownlink":true}}
        | .routing = (.routing // {"rules":[]})
        | .routing.rules += [{"type":"field","inboundTag":["api"],"outboundTag":"api"}]
        | .inbounds[0].tag = "vmess-in"
    ' "$XRAY_CFG" > /tmp/xray.json 2>/dev/null

    if jq empty /tmp/xray.json >/dev/null 2>&1; then
        mv /tmp/xray.json "$XRAY_CFG"
        systemctl restart xray 2>/dev/null
    else
        rm -f /tmp/xray.json
    fi

}

#==================================================
# Resiliencia
#==================================================

ensure_xray_resilience() {

mkdir -p /etc/systemd/system/xray.service.d

cat >/etc/systemd/system/xray.service.d/10-resilience.conf <<EOF
[Unit]
After=network-online.target
Wants=network-online.target

[Service]
Restart=always
RestartSec=3
StartLimitIntervalSec=0
EOF

systemctl daemon-reload

systemctl enable xray >/dev/null 2>&1

}

#==================================================
# Reiniciar
#==================================================

restart_xray() {

    systemctl restart xray

    sleep 2

    if systemctl is-active --quiet xray
    then
        echo -e "${GREEN}✔ Xray iniciado correctamente.${RESET}"
    else
        echo -e "${RED}✘ No fue posible iniciar Xray.${RESET}"
    fi

}

#==================================================
# Garantizar binds de HAProxy para Xray
# (443/80/8080 ya existen; 8443 se agrega TLS)
#==================================================

ensure_haproxy_xray_ports() {

    command -v haproxy >/dev/null 2>&1 || return 0

    local HAPROXY_CFG="/etc/haproxy/haproxy.cfg"

    [[ -f "$HAPROXY_CFG" ]] || return 0

    if ! grep -q "bind \*:8443 ssl" "$HAPROXY_CFG" 2>/dev/null; then

        sed -i 's|    bind abns@haproxy-https accept-proxy ssl crt /etc/haproxy/yha.pem alpn h2,http/1.1 tfo|&\n    bind *:8443 ssl crt /etc/haproxy/yha.pem alpn h2,http/1.1 tfo|' "$HAPROXY_CFG"

        if haproxy -c -f "$HAPROXY_CFG" >/dev/null 2>&1; then
            systemctl reload haproxy 2>/dev/null
        else
            sed -i '/bind \*:8443 ssl/d' "$HAPROXY_CFG"
        fi

    fi

}

#==================================================
# Instalar
#==================================================

install_xray() {

    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}        INSTALANDO XRAY CORE${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    install_xray_dependencies || return

    # Abrir puertos 80/443/8080/8443 + NAT (salida a internet)
    if [[ -f "$BASE/herramientas/openports.sh" ]]; then
        source "$BASE/herramientas/openports.sh"
        open_ports "TCP:80,443,8080,8443"
    else
        sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1
        for P in 80 443 8080 8443; do
            iptables -C INPUT -p tcp --dport "$P" -j ACCEPT 2>/dev/null \
                || iptables -A INPUT -p tcp --dport "$P" -j ACCEPT
        done
        DEV=$(ip -4 route show default | awk '{print $5}' | head -1)
        [[ -n "$DEV" ]] && {
            iptables -t nat -C POSTROUTING -o "$DEV" -j MASQUERADE 2>/dev/null \
                || iptables -t nat -A POSTROUTING -o "$DEV" -j MASQUERADE
        }
    fi

    install_xray_core || return

    create_xray_dirs

    create_xray_config

    ensure_xray_api_config

    ensure_xray_resilience

    restart_xray

    # Cron de verificación de límites (cada 2 min)
    (crontab -l 2>/dev/null | grep -v "v2ray.sh --check-limits"; echo "*/2 * * * * bash /etc/movivip/protocolos/v2ray.sh --check-limits >/dev/null 2>&1") | crontab -

    if [[ -f "$CONFIG" ]]; then

        sed -i '/^XRAY=/d' "$CONFIG"

        echo "XRAY=ON" >> "$CONFIG"

        grep -q "^XRAY_PORT=" "$CONFIG" || echo "XRAY_PORT=443" >> "$CONFIG"

    fi

    ensure_haproxy_xray_ports

    echo
    echo -e "${GREEN}✔ Instalación completada.${RESET}"

}

#==================================================
# Desinstalar
#==================================================

remove_xray() {

    systemctl stop xray 2>/dev/null

    systemctl disable xray 2>/dev/null

    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove

    rm -rf "$XRAY_DIR"

    rm -rf /var/log/xray

    if [[ -f "$CONFIG" ]]; then

        sed -i '/^XRAY=/d' "$CONFIG"

        echo "XRAY=OFF" >> "$CONFIG"

    fi

    echo -e "${GREEN}✔ Xray eliminado.${RESET}"

}
#==================================================
# MoviVIP Network
# Xray Manager
# Parte 2 - Gestión de Usuarios VMess
#==================================================

#--------------------------------------------------
# Cargar Dominio
#--------------------------------------------------

load_domain() {

    [[ -f "$CONFIG" ]] && source "$CONFIG"

    DOMAIN="${SERVER_DOMAIN:-$DOMAIN}"

    XRAY_PORT="${XRAY_PORT:-443}"

    if [[ -z "$DOMAIN" && -f /etc/xray/domain ]]; then
        DOMAIN=$(cat /etc/xray/domain)
    fi

}

#--------------------------------------------------
# Verificar Config
#--------------------------------------------------

check_xray_config() {

    if [[ ! -f "$XRAY_CFG" ]]; then
        echo -e "${RED}✘ No existe config.json${RESET}"
        return 1
    fi

    command -v jq >/dev/null 2>&1 || {
        echo -e "${RED}✘ jq no está instalado.${RESET}"
        return 1
    }

}

#--------------------------------------------------
# Crear Usuario
#--------------------------------------------------

create_vmess_user() {

    check_xray_config || return

    load_domain

    echo
    read -rp "$(trx 'Usuario : ')" USERNAME
USERNAME=$(echo "$USERNAME" | xargs)

if [[ -z "$USERNAME" ]]; then
    echo -e "${RED}✘ Usuario inválido.${RESET}"
    return
fi

if vmess_user_exists "$USERNAME"; then
    echo -e "${RED}✘ El usuario ya existe.${RESET}"
    read -n1 -r -p "$(trx 'Presione cualquier tecla para continuar...')"
    return
fi

    UUID=$(cat /proc/sys/kernel/random/uuid)

    jq \
        --arg uuid "$UUID" \
        --arg email "$USERNAME" \
        '.inbounds[0].settings.clients +=
        [{
            "id":$uuid,
            "level":0,
            "email":$email
        }]' \
        "$XRAY_CFG" > /tmp/xray.json
        
if ! jq empty /tmp/xray.json >/dev/null 2>&1; then
    echo -e "${RED}✘ Error al generar config.json.${RESET}"
    rm -f /tmp/xray.json
    return
fi
    mv /tmp/xray.json "$XRAY_CFG"

    systemctl restart xray

    VMESS_UUID="$UUID"
    VMESS_USER="$USERNAME"

    echo
    echo -e "${GREEN}✔ Usuario creado correctamente.${RESET}"

}

#--------------------------------------------------
# Eliminar Usuario
#--------------------------------------------------

remove_vmess_user() {

    check_xray_config || return

    echo
    read -rp "$(trx 'Usuario : ')" USERNAME

    [[ -z "$USERNAME" ]] && return

    jq \
      --arg email "$USERNAME" \
      '.inbounds[0].settings.clients |=
      map(select(.email != $email))' \
      "$XRAY_CFG" > /tmp/xray.json

    mv /tmp/xray.json "$XRAY_CFG"

    # Limpiar puerto guardado del usuario eliminado
    sed -i "/^${USERNAME}=/d" "$XRAY_PORTS_FILE" 2>/dev/null

    # Limpiar límites y suspensiones
    sed -i "/^${USERNAME}=/d" "$XRAY_LIMITS_FILE" 2>/dev/null
    sed -i "/^${USERNAME}=/d" "$XRAY_SUSPEND_FILE" 2>/dev/null

    systemctl restart xray

    echo
    echo -e "${GREEN}✔ Usuario eliminado.${RESET}"

}

#--------------------------------------------------
# Buscar UUID
#--------------------------------------------------

get_vmess_uuid() {

    jq -r \
    --arg email "$1" \
    '.inbounds[0].settings.clients[]
    | select(.email==$email)
    | .id' \
    "$XRAY_CFG"

}

#--------------------------------------------------
# Puerto por usuario (archivo: sistema/xray_ports.conf)
#--------------------------------------------------

XRAY_PORTS_FILE="$BASE/sistema/xray_ports.conf"
XRAY_LIMITS_FILE="$BASE/sistema/xray_limites.conf"
XRAY_SUSPEND_FILE="$BASE/sistema/xray_suspendidos.conf"
XRAY_CORTES_LOG="$BASE/sistema/xray_cortes.log"

get_xray_port() {

    local USER="$1"
    local P

    P=$(grep -F "$USER=" "$XRAY_PORTS_FILE" 2>/dev/null | tail -1 | cut -d= -f2)

    echo "${P:-${XRAY_PORT:-443}}"

}

save_xray_port() {

    local USER="$1" PORT="$2"

    mkdir -p "$BASE/sistema"

    sed -i "/^${USER}=/d" "$XRAY_PORTS_FILE" 2>/dev/null

    echo "$USER=$PORT" >> "$XRAY_PORTS_FILE"

}

#--------------------------------------------------
# Límites por usuario: USUARIO=MAXCONN:MAXGB:MAXDIAS:FECHA
# (0 = ilimitado en conn/gb/dias)
#--------------------------------------------------

get_xray_limit() {

    # $1=usuario  $2=campo (conn|gb|dias|fecha)
    local USER="$1" FIELD="$2"
    local LINE
    local -a VALS

    LINE=$(grep -F "$USER=" "$XRAY_LIMITS_FILE" 2>/dev/null | tail -1)

    [[ -z "$LINE" ]] && { echo "0"; return; }

    IFS=':' read -r -a VALS <<< "${LINE#*=}"

    case "$FIELD" in
        conn)  echo "${VALS[0]:-0}" ;;
        gb)    echo "${VALS[1]:-0}" ;;
        dias)  echo "${VALS[2]:-0}" ;;
        fecha) echo "${VALS[3]:-$(date +%Y-%m-%d)}" ;;
        *)     echo "0" ;;
    esac

}

save_xray_limits() {

    local USER="$1" MAXCONN="$2" MAXGB="$3" MAXDIAS="$4"
    local FECHA

    FECHA=$(date +%Y-%m-%d)

    mkdir -p "$BASE/sistema"

    sed -i "/^${USER}=/d" "$XRAY_LIMITS_FILE" 2>/dev/null

    echo "$USER=$MAXCONN:$MAXGB:${MAXDIAS:-0}:$FECHA" >> "$XRAY_LIMITS_FILE"

}

xray_dias_restantes() {

    # $1=usuario → días restantes (9999 = ilimitado)
    local USER="$1"
    local MAXDIAS FECHA_INI VENCE RESTANTES

    MAXDIAS=$(get_xray_limit "$USER" dias)
    FECHA_INI=$(get_xray_limit "$USER" fecha)

    [[ "$MAXDIAS" == "0" ]] && { echo "9999"; return; }

    VENCE=$(date -d "$FECHA_INI + $MAXDIAS days" +%Y-%m-%d 2>/dev/null)

    [[ -z "$VENCE" ]] && { echo "9999"; return; }

    RESTANTES=$(( ( $(date -d "$VENCE" +%s) - $(date +%s) ) / 86400 ))

    [[ "$RESTANTES" -lt 0 ]] && RESTANTES=0

    echo "$RESTANTES"

}

#--------------------------------------------------
# Listar Usuarios
#--------------------------------------------------

list_vmess_users() {

    check_xray_config || return

    echo
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${WHITE}                  👥 USUARIOS VMESS                        ${CYAN}║${RESET}"
    echo -e "${CYAN}╠════╦══════════════════════╦═══════════════════════════════╦════════╣${RESET}"

    printf "${CYAN}║${WHITE} %-2s ${CYAN}║${WHITE} %-20s ${CYAN}║${WHITE} %-29s ${CYAN}║${WHITE} %-6s ${CYAN}║${RESET}\n" "#" "USUARIO" "UUID" "PUERTO"

    echo -e "${CYAN}╠════╬══════════════════════╬═══════════════════════════════╬════════╣${RESET}"

    TOTAL=0

    while read -r USER
    do

        [[ -z "$USER" ]] && continue

        UUID=$(get_vmess_uuid "$USER")

        SHORT_UUID="${UUID:0:29}..."

        PORT_USER=$(get_xray_port "$USER")

        TOTAL=$((TOTAL+1))

        printf "${CYAN}║${GREEN} %-2s ${CYAN}║${WHITE} %-20s ${CYAN}║${YELLOW} %-29s ${CYAN}║${MAGENTA} %-6s ${CYAN}║${RESET}\n" \
            "$TOTAL" "$USER" "$SHORT_UUID" "$PORT_USER"

    done < <(
        jq -r '.inbounds[0].settings.clients[].email' "$XRAY_CFG"
    )

    if [[ "$TOTAL" == "0" ]]; then

        echo -e "${CYAN}║${RED}              NO EXISTEN USUARIOS REGISTRADOS              ${CYAN}║${RESET}"
        TOTAL=0

    fi

    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"
    printf "${CYAN}║${WHITE} Total de usuarios : ${GREEN}%-36s${CYAN}║${RESET}\n" "$TOTAL"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    echo
    read -n1 -r -p "$(trx 'Presione cualquier tecla para continuar...')"

}

#--------------------------------------------------
# Existe Usuario
#--------------------------------------------------

vmess_user_exists() {

    jq -e \
    --arg email "$1" \
    '.inbounds[0].settings.clients | any(.email == $email)' \
    "$XRAY_CFG" >/dev/null 2>&1

}
#==================================================
# MoviVIP Network
# Xray Manager
# Parte 3 - VMess Link e Información
#==================================================

#--------------------------------------------------
# Base64 sin saltos de línea
#--------------------------------------------------

base64_encode() {

    if base64 --help 2>/dev/null | grep -q "\-w"
    then
        base64 -w 0
    else
        base64 | tr -d '\n'
    fi

}

#--------------------------------------------------
# Generar Link VMess
#--------------------------------------------------

generate_vmess_link() {

    load_domain

    local USER="$1"
    local UUID="$2"
    local PORT="${3:-$(get_xray_port "$USER")}"
    local TLS="tls"
    local SNI="$DOMAIN"

    # 80 y 8080 son HTTP sin TLS → link sin TLS ni SNI
    if [[ "$PORT" == "80" || "$PORT" == "8080" ]]; then
        TLS=""
        SNI=""
    fi

cat <<EOF | base64_encode
{
  "v":"2",
  "ps":"$USER",
  "add":"$DOMAIN",
  "port":"$PORT",
  "id":"$UUID",
  "aid":"0",
  "scy":"auto",
  "net":"ws",
  "type":"none",
  "host":"$DOMAIN",
  "path":"/vmess",
  "tls":"$TLS",
  "sni":"$SNI",
  "alpn":""
}
EOF

}

#--------------------------------------------------
# Mostrar Usuario
#--------------------------------------------------

show_vmess_user() {

    load_domain

    local USER="$1"
    local UUID="$2"

    LINK="vmess://$(generate_vmess_link "$USER" "$UUID")"

    echo
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${WHITE}                 ✅ CUENTA VMESS CREADA                     ${CYAN}║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"

    printf "${CYAN}║${RESET} 👤 Usuario    ${WHITE}: %-40s${CYAN}║${RESET}\n" "$USER"
    printf "${CYAN}║${RESET} 🆔 UUID       ${WHITE}: %-40s${CYAN}║${RESET}\n" "$UUID"
    printf "${CYAN}║${RESET} 🌐 Dominio    ${WHITE}: %-40s${CYAN}║${RESET}\n" "$DOMAIN"

    local PORT="$(get_xray_port "$USER")"
    local SEC="TLS"
    [[ "$PORT" == "80" || "$PORT" == "8080" ]] && SEC="SIN TLS"

    printf "${CYAN}║${RESET} 🔒 Puerto     ${WHITE}: %-40s${CYAN}║${RESET}\n" "$PORT"
    printf "${CYAN}║${RESET} 🛡 Seguridad  ${WHITE}: %-40s${CYAN}║${RESET}\n" "$SEC"
    printf "${CYAN}║${RESET} 📡 Network    ${WHITE}: %-40s${CYAN}║${RESET}\n" "WebSocket"
    printf "${CYAN}║${RESET} 📂 Path       ${WHITE}: %-40s${CYAN}║${RESET}\n" "/vmess"

    # Límites: consumo, conexiones, días
    local MAXCONN="$(get_xray_limit "$USER" conn)"
    local MAXGB="$(get_xray_limit "$USER" gb)"
    local MAXDIAS="$(get_xray_limit "$USER" dias)"
    local TRAFFIC="$(get_user_traffic "$USER")"
    local GBU=$(awk -v b="$TRAFFIC" 'BEGIN{printf "%.2f", b/1073741824}')
    local DREST="∞"

    [[ "$MAXDIAS" != "0" ]] && DREST="$(xray_dias_restantes "$USER")"

    printf "${CYAN}║${RESET} 💾 Consumo    ${WHITE}: %-40s${CYAN}║${RESET}\n" "$GBU GB / $MAXGB GB"
    printf "${CYAN}║${RESET} 🔗 Conexiones ${WHITE}: %-40s${CYAN}║${RESET}\n" "máx $MAXCONN simultáneas (0=ilimitado)"
    printf "${CYAN}║${RESET} 📅 Días       ${WHITE}: %-40s${CYAN}║${RESET}\n" "$DREST restantes / $MAXDIAS"

    if grep -F "$USER=" "$XRAY_SUSPEND_FILE" >/dev/null 2>&1; then
        printf "${CYAN}║${RESET} ⛔ Estado     ${WHITE}: %-40s${CYAN}║${RESET}\n" "SUSPENDIDO"
    fi

    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${CYAN}║${YELLOW}                     🔗 ENLACE VMESS                        ${CYAN}║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"

    echo
    echo -e "${GREEN}$LINK${RESET}"
    echo

    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    echo
    read -n1 -r -p "$(trx 'Presione cualquier tecla para continuar...')"

}

#--------------------------------------------------
# Mostrar Usuario por Nombre
#--------------------------------------------------

show_vmess_account() {

    check_xray_config || return

    echo
    read -rp "$(trx 'Usuario : ')" USERNAME

    [[ -z "$USERNAME" ]] && return

    UUID=$(get_vmess_uuid "$USERNAME")

    if [[ -z "$UUID" ]]; then
        echo
        echo -e "${RED}✘ Usuario no encontrado.${RESET}"
        return
    fi

    show_vmess_user "$USERNAME" "$UUID"

}

#--------------------------------------------------
# Crear Cuenta Completa
#--------------------------------------------------

create_vmess_account() {

    # 1) Elegir puerto para este usuario
    echo
    echo -e "${CYAN}┌────────── PUERTO PARA ESTE USUARIO ──────────┐${RESET}"
    echo -e " ${GREEN}[1]${RESET} 🔒 Puerto 443  (TLS — recomendado)"
    echo -e " ${GREEN}[2]${RESET} 🌐 Puerto 80   (HTTP sin TLS)"
    echo -e " ${GREEN}[3]${RESET} 🚀 Puerto 8080 (HTTP sin TLS)"
    echo -e " ${GREEN}[4]${RESET} 🛡 Puerto 8443 (TLS alternativo)"
    echo -e " ${RED}[0]${RESET} ↩ Cancelar"
    echo -e "${CYAN}└──────────────────────────────────────────────┘${RESET}"
    echo
    read -rp "$(trx ' ► Puerto: ')" OP

    case "$OP" in
        1) NEW_PORT=443 ;;
        2) NEW_PORT=80 ;;
        3) NEW_PORT=8080 ;;
        4) NEW_PORT=8443 ;;
        0) return ;;
        *)
            echo
            echo "$(trx '❌ Opción inválida.')"
            sleep 2
            return
        ;;
    esac

    # 2) Límites para este usuario
    echo
    echo -e "${CYAN}┌────────────── LÍMITES DEL USUARIO ─────────────┐${RESET}"
    echo -e " ${GRAY}0 = sin límite${RESET}"
    echo -e "${CYAN}└─────────────────────────────────────────────────┘${RESET}"
    echo
    read -rp "$(trx 'Límite de conexiones simultáneas (0 = ilimitado): ')" NEW_CONN
    NEW_CONN=${NEW_CONN:-0}
    read -rp "$(trx 'Límite de consumo en GB (0 = ilimitado): ')" NEW_GB
    NEW_GB=${NEW_GB:-0}
    read -rp "$(trx 'Límite de días de vigencia (0 = ilimitado): ')" NEW_DAYS
    NEW_DAYS=${NEW_DAYS:-0}

    # 3) Crear usuario Xray
    create_vmess_user || return

    # 4) Guardar puerto y límites, generar link con ese puerto
    save_xray_port "$VMESS_USER" "$NEW_PORT"
    save_xray_limits "$VMESS_USER" "$NEW_CONN" "$NEW_GB" "$NEW_DAYS"

    load_domain
if [[ -z "$DOMAIN" ]]; then
    echo -e "${RED}✘ No hay dominio configurado.${RESET}"
    return
fi
    LINK="vmess://$(generate_vmess_link "$VMESS_USER" "$VMESS_UUID" "$NEW_PORT")"

    clear

    echo
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${WHITE}                 🎉 CUENTA VMESS CREADA EXITOSAMENTE              ${CYAN}║${RESET}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════╣${RESET}"

    printf "${CYAN}║${RESET} 👤 Usuario     ${WHITE}: %-42s${CYAN}║${RESET}\n" "$VMESS_USER"
    printf "${CYAN}║${RESET} 🆔 UUID        ${WHITE}: %-42s${CYAN}║${RESET}\n" "$VMESS_UUID"
    printf "${CYAN}║${RESET} 🌐 Dominio     ${WHITE}: %-42s${CYAN}║${RESET}\n" "$DOMAIN"

    local PORT="$(get_xray_port "$VMESS_USER")"
    local SEC="TLS"
    [[ "$PORT" == "80" || "$PORT" == "8080" ]] && SEC="SIN TLS"

    printf "${CYAN}║${RESET} 🔒 Puerto      ${WHITE}: %-42s${CYAN}║${RESET}\n" "$PORT"
    printf "${CYAN}║${RESET} 📡 Network     ${WHITE}: %-42s${CYAN}║${RESET}\n" "WebSocket"
    printf "${CYAN}║${RESET} 🛡 Seguridad   ${WHITE}: %-42s${CYAN}║${RESET}\n" "$SEC"
    printf "${CYAN}║${RESET} 📂 Path        ${WHITE}: %-42s${CYAN}║${RESET}\n" "/vmess"

    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${CYAN}║${YELLOW}                     🔗 ENLACE VMESS                              ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════╝${RESET}"

    echo
    echo -e "${GREEN}$LINK${RESET}"
    echo

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${GREEN}✔ La cuenta está lista para usar.${RESET}"
    echo -e "${GREEN}✔ Comparta el enlace VMess con el cliente.${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    echo
    read -n1 -r -p "$(trx 'Presione cualquier tecla para regresar al menú...')"

}

#--------------------------------------------------
# Exportar Link
#--------------------------------------------------

export_vmess_link() {

    check_xray_config || return

    echo
    read -rp "$(trx 'Usuario : ')" USERNAME

    [[ -z "$USERNAME" ]] && return

    UUID=$(get_vmess_uuid "$USERNAME")

    [[ -z "$UUID" ]] && {
        echo -e "${RED}✘ Usuario no encontrado.${RESET}"
        return
    }

    LINK="vmess://$(generate_vmess_link "$USERNAME" "$UUID")"

    echo "$LINK" >/tmp/vmess.txt

    echo
    echo -e "${GREEN}✔ Link exportado:${RESET}"
    echo "/tmp/vmess.txt"

}

#--------------------------------------------------
# Información del Servidor
#--------------------------------------------------

vmess_server_info() {

    load_domain

    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}         INFORMACIÓN VMESS${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    echo "Dominio : $DOMAIN"

    local PORT="${XRAY_PORT:-443}"
    local SEC="Sí"
    [[ "$PORT" == "80" || "$PORT" == "8080" ]] && SEC="No"

    echo "Puerto  : $PORT"
    echo "TLS     : $SEC"
    echo "$(trx 'Network : ws')"
    echo "$(trx 'Path    : /vmess')"
    echo "Host    : $DOMAIN"

    echo
read -n1 -r -p "$(trx 'Presione cualquier tecla para continuar...')"
}
#==================================================
# MoviVIP Network
# Xray Manager
# Parte 4 - Online, Estado y Menú
#==================================================

#--------------------------------------------------
# Usuarios Online
#--------------------------------------------------

xray_online_users() {

    if [[ ! -f "$XRAY_LOG" ]]; then
        echo
        echo -e "${RED}✘ No existe el access.log.${RESET}"
        return
    fi

    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}        USUARIOS EN LÍNEA${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo

    LIMIT=$(date -d "60 seconds ago" "+%Y/%m/%d %H:%M:%S")

    awk -v LIM="$LIMIT" '
    /email:/ {

        DATA=$1" "$2

        if(DATA>=LIM){

            split($0,a,"email: ")

            print a[2]

        }

    }' "$XRAY_LOG" | sort -u

    TOTAL=$(awk -v LIM="$LIMIT" '
    /email:/ {

        DATA=$1" "$2

        if(DATA>=LIM){

            split($0,a,"email: ")

            print a[2]

        }

    }' "$XRAY_LOG" | sort -u | wc -l)

    echo
    echo -e "${GREEN}Usuarios conectados:${RESET} $TOTAL"
    echo
echo
read -n1 -r -p "$(trx 'Presione cualquier tecla para continuar...')"
}

#--------------------------------------------------
# Reiniciar
#--------------------------------------------------

restart_xray_service() {

    echo

    systemctl restart xray

    sleep 2
if ! systemctl is-active --quiet xray; then
    echo -e "${RED}✘ Xray no pudo iniciarse.${RESET}"
    return
fi

    if systemctl is-active --quiet xray
    then
        echo -e "${GREEN}✔ Xray reiniciado correctamente.${RESET}"
    else
        echo -e "${RED}✘ Error al reiniciar Xray.${RESET}"
    fi

}

#--------------------------------------------------
# Estado
#--------------------------------------------------

xray_status() {

    source "$CONFIG" 2>/dev/null
    XRAY_PORT="${XRAY_PORT:-443}"

    echo

    if systemctl is-active --quiet xray; then
        STATUS="${GREEN}🟢 ACTIVO${RESET}"
    else
        STATUS="${RED}🔴 DETENIDO${RESET}"
    fi

    VERSION=$(xray version 2>/dev/null | head -1)
    VERSION=${VERSION:-NO INSTALADO}

    if xray run -test -config "$XRAY_CFG" >/dev/null 2>&1; then
        CONFIG_STATUS="${GREEN}🟢 CORRECTA${RESET}"
    else
        CONFIG_STATUS="${RED}🔴 ERROR${RESET}"
    fi

    if ss -lnt | grep -q ":10002 "; then
        PORT10002="${GREEN}🟢 ESCUCHANDO${RESET}"
    else
        PORT10002="${RED}🔴 CERRADO${RESET}"
    fi

    PORT_ENTRY="${XRAY_PORT:-443}"

    if ss -lnt | grep -q ":$PORT_ENTRY "; then
        PORT_ENTRY_STATUS="${GREEN}🟢 ESCUCHANDO${RESET}"
    else
        PORT_ENTRY_STATUS="${YELLOW}🟡 Gestionado por HAProxy${RESET}"
    fi

    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${WHITE}                 📊 ESTADO DEL SERVICIO XRAY              ${CYAN}║${RESET}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${RESET}"

    printf " %-18s %b\n" "Estado:" "$STATUS"
    printf " %-18s ${GREEN}%s${RESET}\n" "Versión:" "$VERSION"
    printf " %-18s %b\n" "Configuración:" "$CONFIG_STATUS"
    printf " %-18s %b\n" "Puerto $PORT_ENTRY:" "$PORT_ENTRY_STATUS"
    printf " %-18s %b\n" "Puerto 10002:" "$PORT10002"

    echo
    echo -e " ${GREEN}🟢${RESET} VMess ............... Disponible"
    echo -e " ${GREEN}🟢${RESET} WebSocket ........... Disponible"
    echo -e " ${GREEN}🟢${RESET} TLS ................. Disponible"
    echo -e " ${GREEN}🟢${RESET} JSON Config ......... Cargado"

    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${RESET}"

    echo
    read -n1 -r -p "$(trx 'Presione cualquier tecla para continuar...')"

}

#--------------------------------------------------
# Cambiar Puerto de Entrada (80/443/8080/8443)
#--------------------------------------------------

select_xray_port() {

    echo
    echo -e "${CYAN}┌────────────── PUERTO DE ENTRADA ──────────────┐${RESET}"
    echo -e " ${GREEN}[1]${RESET} 🔒 Puerto 443  (TLS — recomendado)"
    echo -e " ${GREEN}[2]${RESET} 🌐 Puerto 80   (HTTP sin TLS)"
    echo -e " ${GREEN}[3]${RESET} 🚀 Puerto 8080 (HTTP sin TLS)"
    echo -e " ${GREEN}[4]${RESET} 🛡 Puerto 8443 (TLS alternativo)"
    echo -e " ${GREEN}[0]${RESET} ↩ Cancelar"
    echo -e "${CYAN}└──────────────────────────────────────────────┘${RESET}"
    echo
    read -rp "$(trx ' ► Opción: ')" OPORT

    case "$OPORT" in
        1) NEW_PORT=443 ;;
        2) NEW_PORT=80 ;;
        3) NEW_PORT=8080 ;;
        4) NEW_PORT=8443 ;;
        0) return ;;
        *)
            echo
            echo "$(trx '❌ Opción inválida.')"
            sleep 2
            return
        ;;
    esac

    [[ -f "$CONFIG" ]] && {
        sed -i '/^XRAY_PORT=/d' "$CONFIG"
        echo "XRAY_PORT=$NEW_PORT" >> "$CONFIG"
    }

    XRAY_PORT=$NEW_PORT

    ensure_haproxy_xray_ports

    echo
    echo -e "${GREEN}✔ Puerto de entrada cambiado a: ${WHITE}$NEW_PORT${RESET}"

    if [[ "$NEW_PORT" == "80" || "$NEW_PORT" == "8080" ]]; then
        echo -e "${GOLD}⚠️  Los links se generarán SIN TLS (HTTP).${RESET}"
    fi

    echo -e "${GOLD}⚠️  Genere nuevamente los links de los usuarios para actualizar el puerto.${RESET}"

    echo
    read -n1 -r -p "$(trx 'Presione cualquier tecla para continuar...')"

}

#--------------------------------------------------
# Menú
#--------------------------------------------------
#--------------------------------------------------
# Contar conexiones activas de un usuario (ventana 60s)
#--------------------------------------------------

count_user_conns() {

    # $1 = usuario → nº de conexiones en la ventana
    local USER="$1"

    grep "$(date -d "60 seconds ago" "+%Y/%m/%d %H:%M:%S")" "$XRAY_LOG" 2>/dev/null |
    grep "email:" |
    sed 's/.*email: //; s/ .*//' |
    grep -Fxc "$USER"

}

#--------------------------------------------------
# Consumo de un usuario (bytes, via API de Xray)
#--------------------------------------------------

get_user_traffic() {

    # $1 = usuario → bytes totales (downlink+uplink)
    local USER="$1" OUT

    OUT=$(xray api statsquery --server=127.0.0.1:10085 -pattern "user>>>$USER>>>traffic>>>" 2>/dev/null)

    echo "$OUT" | grep -o "Value: [0-9]*" | awk '{s+=$2} END{print s+0}'

}

#--------------------------------------------------
# Suspender usuario (guarda UUID para restaurar)
#--------------------------------------------------

suspend_xray_user() {

    local USER="$1" REASON="$2" UUID

    UUID=$(get_vmess_uuid "$USER")

    mkdir -p "$BASE/sistema"

    sed -i "/^${USER}=/d" "$XRAY_SUSPEND_FILE" 2>/dev/null

    echo "$USER=$UUID|$(date '+%Y-%m-%d %H:%M:%S')|$REASON" >> "$XRAY_SUSPEND_FILE"

    jq --arg email "$USER" '.inbounds[0].settings.clients |= map(select(.email != $email))' "$XRAY_CFG" > /tmp/xray.json

    mv /tmp/xray.json "$XRAY_CFG"

    systemctl restart xray 2>/dev/null

    echo "$(date '+%Y-%m-%d %H:%M:%S') SUSPENDIDO $USER por $REASON" >> "$XRAY_CORTES_LOG"

}

#--------------------------------------------------
# Reactivar usuario suspendido (mismo UUID)
#--------------------------------------------------

reactivate_xray_user() {

    local USER="$1" LINE UUID

    LINE=$(grep -F "$USER=" "$XRAY_SUSPEND_FILE" 2>/dev/null | tail -1)

    UUID="${LINE#*=}"
    UUID="${UUID%%|*}"

    [[ -z "$UUID" ]] && UUID=$(cat /proc/sys/kernel/random/uuid)

    sed -i "/^${USER}=/d" "$XRAY_SUSPEND_FILE" 2>/dev/null

    jq --arg uuid "$UUID" --arg email "$USER" \
        '.inbounds[0].settings.clients += [{"id":$uuid,"level":0,"email":$email}]' \
        "$XRAY_CFG" > /tmp/xray.json

    mv /tmp/xray.json "$XRAY_CFG"

    systemctl restart xray 2>/dev/null

    xray api statsreset --server=127.0.0.1:10085 -pattern "user>>>$USER>>>traffic>>>" >/dev/null 2>&1

    echo "$(date '+%Y-%m-%d %H:%M:%S') REACTIVADO $USER" >> "$XRAY_CORTES_LOG"

}

#--------------------------------------------------
# Verificador de límites (cron --check-limits)
#--------------------------------------------------

check_xray_limits() {

    [[ -f "$XRAY_CFG" ]] || return 0

    [[ -f "$XRAY_LIMITS_FILE" ]] || return 0

    ensure_xray_api_config

    local USER MAXCONN MAXGB MAXDIAS CONNS TRAFFIC MAXBYTES REASON LINE

    while IFS= read -r LINE; do

        [[ -z "$LINE" || "$LINE" == \#* ]] && continue

        USER="${LINE%%=*}"

        [[ -z "$USER" ]] && continue

        # Ya suspendido → no repetir
        grep -F "$USER=" "$XRAY_SUSPEND_FILE" >/dev/null 2>&1 && continue

        MAXCONN=$(get_xray_limit "$USER" conn)
        MAXGB=$(get_xray_limit "$USER" gb)
        MAXDIAS=$(get_xray_limit "$USER" dias)

        REASON=""

        if [[ "$MAXCONN" != "0" ]]; then
            CONNS=$(count_user_conns "$USER")
            if [[ "$CONNS" -gt "$MAXCONN" ]]; then
                REASON="límite de conexiones (${CONNS}/${MAXCONN})"
            fi
        fi

        if [[ -z "$REASON" && "$MAXGB" != "0" ]]; then
            TRAFFIC=$(get_user_traffic "$USER")
            MAXBYTES=$((MAXGB * 1024 * 1024 * 1024))
            if [[ "$TRAFFIC" -gt "$MAXBYTES" ]]; then
                REASON="límite de consumo ($(awk -v b="$TRAFFIC" 'BEGIN{printf "%.2f", b/1073741824}') GB/${MAXGB} GB)"
            fi
        fi

        if [[ -z "$REASON" && "$MAXDIAS" != "0" ]]; then
            REST=$(xray_dias_restantes "$USER")
            if [[ "$REST" == "0" ]]; then
                REASON="límite de días (venció el $(date -d "$(get_xray_limit "$USER" fecha) + $MAXDIAS days" +%Y-%m-%d 2>/dev/null))"
            fi
        fi

        if [[ -n "$REASON" ]]; then
            suspend_xray_user "$USER" "$REASON"
        fi

    done < "$XRAY_LIMITS_FILE"

}

#--------------------------------------------------
# Mostrar Consumo y Límites por usuario
#--------------------------------------------------

show_xray_limits() {

    echo
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${WHITE}              📊 CONSUMO Y LÍMITES POR USUARIO               ${CYAN}║${RESET}"
    echo -e "${CYAN}╠════╦══════════════════════╦════════════╦════════╦════════╦══════════╣${RESET}"
    printf "${CYAN}║${WHITE} %-2s ${CYAN}║${WHITE} %-20s ${CYAN}║${WHITE} %-9s ${CYAN}║${WHITE} %-6s ${CYAN}║${WHITE} %-6s ${CYAN}║${WHITE} %-8s ${CYAN}║${RESET}\n" "#" "USUARIO" "USADO GB" "CONN" "DÍAS" "ESTADO"
    echo -e "${CYAN}╠════╬══════════════════════╬════════════╬════════╬════════╬══════════╣${RESET}"

    TOTAL=0

    while read -r USER; do

        [[ -z "$USER" ]] && continue

        MAXCONN=$(get_xray_limit "$USER" conn)
        MAXGB=$(get_xray_limit "$USER" gb)
        MAXDIAS=$(get_xray_limit "$USER" dias)

        TRAFFIC=$(get_user_traffic "$USER")
        GB=$(awk -v b="$TRAFFIC" 'BEGIN{printf "%.2f", b/1073741824}')

        if [[ "$MAXDIAS" != "0" ]]; then
            DREST="$(xray_dias_restantes "$USER")d"
        else
            DREST="∞"
        fi

        if grep -F "$USER=" "$XRAY_SUSPEND_FILE" >/dev/null 2>&1; then
            ESTADO="${RED}SUSPEND${RESET}"
        else
            ESTADO="${GREEN}OK${RESET}"
        fi

        TOTAL=$((TOTAL+1))

        printf "${CYAN}║${GREEN} %-2s ${CYAN}║${WHITE} %-20s ${CYAN}║${YELLOW} %-9s ${CYAN}║${MAGENTA} %-6s ${CYAN}║${BLUE} %-6s ${CYAN}║${WHITE} %-8s ${CYAN}║${RESET}\n" \
            "$TOTAL" "$USER" "$GB/${MAXGB}GB" "$MAXCONN" "$DREST" "$ESTADO"

    done < <(
        {
            jq -r '.inbounds[0].settings.clients[].email' "$XRAY_CFG" 2>/dev/null
            cut -d= -f1 "$XRAY_LIMITS_FILE" 2>/dev/null
        } | sort -u
    )

    if [[ "$TOTAL" == "0" ]]; then
        echo -e "${CYAN}║${RED}              NO HAY USUARIOS CON LÍMITES              ${CYAN}║${RESET}"
    fi

    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${CYAN}║${WHITE} CONN = conexiones simultáneas · DÍAS = vigencia restante${RESET}   ${CYAN}║${RESET}"
    echo -e "${CYAN}║${WHITE} 0 = sin límite · ∞ = ilimitado${RESET}                            ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    echo
    read -n1 -r -p "$(trx 'Presione cualquier tecla para continuar...')"

}

#--------------------------------------------------
# Reactivar usuario suspendido (menú interactivo)
#--------------------------------------------------

reactivate_menu() {

    echo
    echo -e "${CYAN}┌────────────── USUARIOS SUSPENDIDOS ──────────────┐${RESET}"

    if [[ ! -f "$XRAY_SUSPEND_FILE" || ! -s "$XRAY_SUSPEND_FILE" ]]; then
        echo -e " ${GREEN}✔ No hay usuarios suspendidos.${RESET}"
        echo -e "${CYAN}└────────────────────────────────────────────────┘${RESET}"
        echo
        read -n1 -r -p "$(trx 'Presione cualquier tecla para continuar...')"
        return
    fi

    echo -e " ${GOLD}0${RESET} ↩ Volver"

    IDX=0
    while IFS= read -r LINE; do
        [[ -z "$LINE" ]] && continue
        IDX=$((IDX+1))
        SUSP_USER="${LINE%%=*}"
        echo -e " ${GOLD}$IDX${RESET} ${WHITE}$SUSP_USER${RESET} — ${GRAY}${LINE#*=}${RESET}"
    done < "$XRAY_SUSPEND_FILE"

    echo -e "${CYAN}└────────────────────────────────────────────────┘${RESET}"
    echo
    read -rp "$(trx ' ► Opción: ')" OP

    [[ "$OP" == "0" ]] && return

    SELECTED=$(sed -n "${OP}p" "$XRAY_SUSPEND_FILE" 2>/dev/null | cut -d= -f1)

    if [[ -z "$SELECTED" ]]; then
        echo "$(trx '❌ Opción inválida.')"
        sleep 2
        return
    fi

    reactivate_xray_user "$SELECTED"

    echo
    echo -e "${GREEN}✔ Usuario ${WHITE}$SELECTED${GREEN} reactivado con su UUID anterior.${RESET}"
    echo -e "${GOLD}⚠️  El consumo se reinició a 0. Si sigue superando el límite, volverá a suspenderse.${RESET}"
    echo
    read -n1 -r -p "$(trx 'Presione cualquier tecla para continuar...')"

}

#--------------------------------------------------
# Menú
#--------------------------------------------------

xray_menu() {

# Navegación con flechitas
[[ -f "$BASE/lib/nav.sh" ]] && source "$BASE/lib/nav.sh"

while true
do

clear

source "$CONFIG" 2>/dev/null
load_domain
XRAY_PORT="${XRAY_PORT:-443}"

if systemctl is-active --quiet xray; then
    STATUS="${GREEN}🟢 ACTIVO${RESET}"
else
    STATUS="${RED}🔴 DESINSTALADO${RESET}"
fi

VERSION=$(xray version 2>/dev/null | head -1)
VERSION=${VERSION:-NO INSTALADO}

DOMAIN_SHOW="${DOMAIN:-${SERVER_DOMAIN:-NO CONFIGURADO}}"

TOTAL_USERS=0
ONLINE_USERS=0

if [[ -f "$XRAY_CFG" ]]; then
    TOTAL_USERS=$(jq '.inbounds[0].settings.clients | length' "$XRAY_CFG" 2>/dev/null)
fi

if [[ -f "$XRAY_LOG" ]]; then
    LIMIT=$(date -d "60 seconds ago" "+%Y/%m/%d %H:%M:%S")
    ONLINE_USERS=$(awk -v LIM="$LIMIT" '
    /email:/{
        DATA=$1" "$2
        if(DATA>=LIM){
            split($0,a,"email: ")
            print a[2]
        }
    }' "$XRAY_LOG" | sort -u | wc -l)
fi

movivip_sub_header "🚀 XRAY MANAGER v3.0"

echo -e "${CYAN}┌──────────────── INFORMACIÓN ────────────────┐${RESET}"
printf " ${WHITE}Estado      : %b\n" "$STATUS"
printf " ${WHITE}Dominio     : ${GREEN}%s${RESET}\n" "$DOMAIN_SHOW"
printf " ${WHITE}Protocolo   : ${GREEN}VMess + WebSocket + TLS${RESET}\n"
printf " ${WHITE}Puerto TLS  : ${GREEN}${XRAY_PORT}${RESET}\n"
printf " ${WHITE}Path        : ${GREEN}/vmess${RESET}\n"
printf " ${WHITE}Servicio    : ${GREEN}Xray Core${RESET}\n"
printf " ${WHITE}Versión     : ${GREEN}%s${RESET}\n" "$VERSION"
printf " ${WHITE}Usuarios    : ${GREEN}%s${RESET}\n" "$TOTAL_USERS"
printf " ${WHITE}Online      : ${GREEN}%s${RESET}\n" "$ONLINE_USERS"
echo -e "${CYAN}└─────────────────────────────────────────────┘${RESET}"

echo ""

if systemctl is-active --quiet xray; then
    LBL=("Crear Usuario VMess" "Eliminar Usuario" "Listar Usuarios" "Mostrar Cuenta" "Usuarios Online" "Información VMess" "Reiniciar Xray" "Estado del Servicio" "Reinstalar Xray" "Desinstalar Xray" "Cambiar Puerto (80/443/8080/8443)" "Consumo y Límites" "Reactivar Suspendido")
else
    LBL=("Instalar Xray Core")
fi
SEL=$(nav_pick "► Opción:" "${LBL[@]}" "↩ Regresar") || SEL=0
[[ $SEL -eq $((${#LBL[@]}+1)) ]] && SEL=0
opc="$SEL"

case "$opc" in

1)
if systemctl is-active --quiet xray; then
    create_vmess_account
else
    install_xray
fi
;;

2)
if systemctl is-active --quiet xray; then
    remove_vmess_user
else
    echo "$(trx '❌ Xray no está instalado.')"
    sleep 2
fi
;;

3)
if systemctl is-active --quiet xray; then
    list_vmess_users
else
    echo "$(trx '❌ Xray no está instalado.')"
    sleep 2
fi
;;

4)
if systemctl is-active --quiet xray; then
    show_vmess_account
else
    echo "$(trx '❌ Xray no está instalado.')"
    sleep 2
fi
;;

5)
if systemctl is-active --quiet xray; then
    xray_online_users
else
    echo "$(trx '❌ Xray no está instalado.')"
    sleep 2
fi
;;

6)
if systemctl is-active --quiet xray; then
    vmess_server_info
else
    echo "$(trx '❌ Xray no está instalado.')"
    sleep 2
fi
;;

7)
if systemctl is-active --quiet xray; then
    restart_xray_service
else
    echo "$(trx '❌ Xray no está instalado.')"
    sleep 2
fi
;;

8)
if systemctl is-active --quiet xray; then
    xray_status
else
    echo "$(trx '❌ Xray no está instalado.')"
    sleep 2
fi
;;

9)
if systemctl is-active --quiet xray; then
    install_xray
fi
;;

10)
if systemctl is-active --quiet xray; then
    remove_xray
fi
;;

11)
if systemctl is-active --quiet xray; then
    select_xray_port
else
    echo "$(trx '❌ Xray no está instalado.')"
    sleep 2
fi
;;

12)
if systemctl is-active --quiet xray; then
    show_xray_limits
else
    echo "$(trx '❌ Xray no está instalado.')"
    sleep 2
fi
;;

13)
if systemctl is-active --quiet xray; then
    reactivate_menu
else
    echo "$(trx '❌ Xray no está instalado.')"
    sleep 2
fi
;;

0)
if [[ "$FROM_MAIN" == "1" ]]; then
    exec bash "$BASE/menu.sh"
else
    exec bash "$BASE/protocolos/menu.sh"
fi
;;

*)
echo
echo "$(trx '❌ Opción inválida.')"
sleep 2
;;

esac

done

}

#==================================================
# Inicio
#==================================================

# Modo headless para cron (verificación de límites)
if [[ "$1" == "--check-limits" ]]; then
    source "$CONFIG" 2>/dev/null
    XRAY_PORT="${XRAY_PORT:-443}"
    check_xray_limits
    exit 0
fi

# Modo headless: activar límites por usuario en un VPS ya instalado.
# 1) Migra config.json agregando la API de stats (preserva clientes existentes)
# 2) Instala el cron de verificación (cada 2 min)
# 3) Reinicia Xray para aplicar la API
if [[ "$1" == "--ensure-api" ]]; then
    source "$CONFIG" 2>/dev/null
    echo -e "${CYAN}  🔧 Activando límites por usuario en Xray...${RESET}"
    if ! ensure_xray_api_config; then
        echo -e "${RED}  ❌ No se pudo configurar la API de stats.${RESET}"
        exit 1
    fi
    (crontab -l 2>/dev/null | grep -v "v2ray.sh --check-limits"; echo "*/2 * * * * bash /etc/movivip/protocolos/v2ray.sh --check-limits >/dev/null 2>&1") | crontab -
    systemctl restart xray 2>/dev/null
    sleep 1
    if systemctl is-active --quiet xray; then
        echo -e "${GREEN}  ✅ Límites activados: API de stats + cron (cada 2 min).${RESET}"
        crontab -l | grep "check-limits"
    else
        echo -e "${RED}  ⚠️ Xray no reinició — revisa el servicio manualmente.${RESET}"
        exit 1
    fi
    exit 0
fi

xray_menu
