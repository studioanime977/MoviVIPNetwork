#!/bin/bash

#=========================================================
#   MOVIVIP NETWORK — ACTUALIZADOR PREMIUM v5.0
#   Actualiza scripts + aplica iptables gaming DSCP
#   Solo funciona con licencia activa
#=========================================================

BASE="/etc/movivip"
CONFIG="$BASE/config.conf"
LICENCIA="$BASE/licencia.conf"
COMMIT_HASH_FILE="$BASE/.last_commit_hash"

# Cargar idiomas
if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)"
fi

RESET="\e[0m"; RED="\e[1;91m"; GREEN="\e[1;92m"; GOLD="\e[1;93m"
BLUE="\e[1;94m"; MAGENTA="\e[1;95m"; CYAN="\e[1;96m"; WHITE="\e[1;97m"; GRAY="\e[1;90m"

W=58
TOP(){ printf "${CYAN}╔"; printf '═%.0s' $(seq 1 $W); printf "╗${RESET}\n"; }
MID(){ printf "${CYAN}╠"; printf '═%.0s' $(seq 1 $W); printf "╣${RESET}\n"; }
BOT(){ printf "${CYAN}╚"; printf '═%.0s' $(seq 1 $W); printf "╝${RESET}\n"; }
ROW(){ printf "${CYAN}║${RESET} %-56s${CYAN}║${RESET}\n" "$1"; }
ROWC(){ printf "${CYAN}║${RESET} %b%*s${CYAN}║${RESET}\n" "$1" $(( 56 - $(echo -ne "$1" | sed 's/\x1b\[[0-9;]*m//g' | wc -c) )) ""; }

REPO="https://github.com/studioanime977/MoviVIPNetwork.git"
SCRIPTS_DIR="/etc/movivip"
BACKUP_DIR="/etc/movivip/backups/$(date +%Y%m%d_%H%M%S)"
TEMP_DIR="/tmp/movivip-update-$$"

#==============================
# [0] VERIFICAR LICENCIA
#==============================

check_license() {
    # Sin archivo de licencia
    if [[ ! -f "$LICENCIA" ]]; then
        return 1
    fi

    source "$LICENCIA" 2>/dev/null

    # Sin key
    [[ -z "$KEY" ]] && return 1

    # LICENCIA_ACTIVA explicitamente false
    [[ "$LICENCIA_ACTIVA" == "false" ]] && return 1

    # Verificar expiración (expira=0 = vitalicia)
    if [[ "$EXPIRA" != "0" && -n "$EXPIRA" ]]; then
        EXPIRA_TS=$(date -d "$EXPIRA" +%s 2>/dev/null || echo 0)
        NOW_TS=$(date +%s)
        if [[ $EXPIRA_TS -gt 0 && $NOW_TS -gt $EXPIRA_TS ]]; then
            return 1
        fi
    fi

    # Validación online contra Firebase (fail-open para updater local)
    FB_BASE="movivip-network-default-rtdb.firebaseio.com"
    FB_PATH="licencias_movivip/$KEY"
    FB_URL="https://${FB_BASE}/${FB_PATH}.json"

    FB_DATA=$(curl -fsSL --max-time 5 "$FB_URL" 2>/dev/null)
    if [[ -n "$FB_DATA" ]]; then
        # Verificar campo activa
        FB_ACTIVA=$(echo "$FB_DATA" | grep -o '"activa":[[:space:]]*true' | head -1)
        [[ -z "$FB_ACTIVA" ]] && return 1

        # Verificar expiración de Firebase
        FB_EXPIRA=$(echo "$FB_DATA" | grep -o '"expira":[[:space:]]*"[^"]*"' | cut -d'"' -f4)
        if [[ -n "$FB_EXPIRA" && "$FB_EXPIRA" != "0" ]]; then
            FB_EXPIRA_TS=$(date -d "$FB_EXPIRA" +%s 2>/dev/null || echo 0)
            NOW_TS=$(date +%s)
            [[ $FB_EXPIRA_TS -gt 0 && $NOW_TS -gt $FB_EXPIRA_TS ]] && return 1
        fi
    fi

    return 0
}

clear
TOP
printf "${CYAN}║${RESET}  ${GOLD}🛡️  MoviVIP Network${RESET}  ${WHITE}ACTUALIZADOR v${VERSION:-$(cat "$BASE/version.txt" 2>/dev/null || echo "6.0")}${RESET}${CYAN}             ║${RESET}\n"
printf "${CYAN}║${RESET}  ${GRAY}movivip-network.web.app${RESET}  ${GRAY}·${RESET}  ${WHITE}${PROTO_LIVE:-Última versión}${RESET}${CYAN}                ║${RESET}\n"
MID
echo ""

# Verificar licencia
if ! check_license; then
    ROWC "${RED}✗ LICENCIA NO VÁLIDA O VENCIDA${RESET}"
    ROWC "${GRAY}El updater requiere licencia activa${RESET}"
    echo ""
    ROWC "${WHITE}Versión actual: ${GOLD}$(cat "$BASE/version.txt" 2>/dev/null || echo '?')${RESET}"
    echo ""
    ROWC "${CYAN}Contacta para adquirir licencia:${RESET}"
    ROW " "
    ROWC "${WHITE}📢 Canal oficial ....... t.me/MoviVIPNetwork${RESET}"
    ROWC "${WHITE}👥 Grupo oficial ........ t.me/MoviVIPNet${RESET}"
    ROWC "${GREEN}💬 Soporte directo ...... @MoviVIP  (t.me/MoviVIP)${RESET}"
    ROWC "${WHITE}🌐 Sitio web ............ https://movivip-network.web.app${RESET}"
    ROWC "${WHITE}📱 WhatsApp ............. +57 311 700 8185${RESET}"
    BOT
    echo ""
    read -rp "$(echo -e "${CYAN}   Enter para volver${RESET}")" _
    [[ -f "$BASE/menu.sh" ]] && exec bash "$BASE/menu.sh" || exit 1
fi

#==============================
# [1] VERIFICAR CONEXIÓN
#==============================

printf "${CYAN}║${RESET} ${GOLD}[1/6]${RESET} Verificando conexión...${CYAN}%*s║${RESET}\n" $(( W - 30 )) ""

if ! curl -fsSL --max-time 5 https://github.com &>/dev/null; then
    ROWC "${RED}✗ Sin conexión a internet${RESET}"
    BOT
    exit 1
fi
ROWC "${GREEN}✓ Conexión establecida${RESET}"

#==============================
# [2] VERIFICAR VERSIÓN
#==============================

printf "${CYAN}║${RESET} ${GOLD}[2/6]${RESET} Verificando versión...${CYAN}%*s║${RESET}\n" $(( W - 27 )) ""

LOCAL_VER=$(tr -d ' \n' < "$BASE/version.txt" 2>/dev/null || echo "0")
REMOTE_VER=$(curl -fsSL --max-time 5 "https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/version.txt" 2>/dev/null | tr -d ' \n')

if [[ -z "$REMOTE_VER" ]]; then
    ROWC "${RED}✗ No se pudo verificar versión remota${RESET}"
    BOT
    exit 1
fi

# Verificar commit hash (detecta cambios aunque version.txt no cambie)
REMOTE_SHA=$(curl -fsSL --max-time 8 "https://api.github.com/repos/studioanime977/MoviVIPNetwork/commits/main" 2>/dev/null \
    | grep -o '"sha":"[a-f0-9]*"' | head -1 | cut -d'"' -f4)
LOCAL_SHA=""
[[ -f "$COMMIT_HASH_FILE" ]] && LOCAL_SHA=$(cat "$COMMIT_HASH_FILE" 2>/dev/null)

VERSION_CHANGED=false
COMMIT_CHANGED=false
if [[ "$LOCAL_VER" != "$REMOTE_VER" ]]; then VERSION_CHANGED=true; fi
if [[ -n "$REMOTE_SHA" && "$REMOTE_SHA" != "$LOCAL_SHA" ]]; then COMMIT_CHANGED=true; fi

if [[ "$VERSION_CHANGED" == "false" && "$COMMIT_CHANGED" == "false" ]]; then
    ROWC "${GREEN}✓ v${LOCAL_VER} — Ya estás actualizado${RESET}"
    BOT
    echo ""
    read -rp "$(echo -e "${CYAN}   Enter para volver${RESET}")" _
    exec bash "$BASE/menu.sh"
fi

if [[ "$VERSION_CHANGED" == "true" ]]; then
    ROWC "${WHITE}Local: ${GOLD}v${LOCAL_VER}${RESET}  →  Remota: ${GREEN}v${REMOTE_VER}${RESET}"
else
    ROWC "${WHITE}Versión: ${GOLD}v${LOCAL_VER}${RESET} (sin cambios) — ${GREEN}Hay cambios en el código${RESET}"
fi

#==============================
# [3] RESPALDAR
#==============================

printf "${CYAN}║${RESET} ${GOLD}[3/6]${RESET} Respaldando scripts...${CYAN}%*s║${RESET}\n" $(( W - 27 )) ""

mkdir -p "$BACKUP_DIR"
cp -r "$SCRIPTS_DIR"/* "$BACKUP_DIR/" 2>/dev/null
BACKUP_SIZE=$(du -sh "$BACKUP_DIR" 2>/dev/null | awk '{print $1}')
ROWC "${GREEN}✓ Respaldo (${BACKUP_SIZE:-?})${RESET}"

#==============================
# [4] DESCARGAR
#==============================

printf "${CYAN}║${RESET} ${GOLD}[4/6]${RESET} Descargando v${GREEN}${REMOTE_VER}${RESET}...${CYAN}%*s║${RESET}\n" $(( W - 30 - ${#REMOTE_VER} )) ""

rm -rf "$TEMP_DIR"
git clone --depth 1 "$REPO" "$TEMP_DIR" 2>/dev/null

if [[ ! -d "$TEMP_DIR" ]]; then
    ROWC "${RED}✗ Error de descarga — restaurando respaldo${RESET}"
    cp -r "$BACKUP_DIR"/* "$SCRIPTS_DIR/" 2>/dev/null
    BOT
    exit 1
fi

SCRIPTS_SRC=$(find "$TEMP_DIR" -name "install.sh" -type f -exec dirname {} \; 2>/dev/null | head -1)
if [[ -z "$SCRIPTS_SRC" ]]; then
    ROWC "${RED}✗ Scripts no encontrados en repositorio${RESET}"
    rm -rf "$TEMP_DIR"
    BOT
    exit 1
fi
ROWC "${GREEN}✓ Descarga completa${RESET}"

#==============================
# [5] ACTUALIZAR
#==============================

printf "${CYAN}║${RESET} ${GOLD}[5/6]${RESET} Actualizando...${CYAN}%*s║${RESET}\n" $(( W - 21 )) ""

UPDATED=0
SKIP_EXT=".md,.txt,.py,.sh.bak"
# Archivos/dirs que NUNCA se sobreescriben (contienen config local del bot)
SKIP_FILES="bot-generador.sh movivip-bot-generador.service setup-bot-generador.sh descifrar-secrets.sh"
for f in "$SCRIPTS_SRC"/*; do
    fname=$(basename "$f")
    [[ "$fname" == "config.conf" ]] && continue
    [[ "$fname" == "backups" ]] && continue
    [[ "$fname" == "SESSION-SUMMARY.md" ]] && continue
    [[ "$fname" == "PLAN-"* ]] && continue

    if [[ -d "$f" ]]; then
        mkdir -p "$SCRIPTS_DIR/$fname"
        # Para herramientas/: no sobreescribir archivos del bot
        if [[ "$fname" == "herramientas" ]]; then
            for sub in "$f"/*; do
                subname=$(basename "$sub")
                skip=false
                for sf in $SKIP_FILES; do
                    [[ "$subname" == "$sf" ]] && skip=true && break
                done
                if $skip; then
                    # Solo copiar si no existe en destino
                    [[ ! -e "$SCRIPTS_DIR/$fname/$subname" ]] && cp "$sub" "$SCRIPTS_DIR/$fname/" 2>/dev/null
                else
                    cp "$sub" "$SCRIPTS_DIR/$fname/" 2>/dev/null
                fi
            done
        else
            cp -r "$f"/* "$SCRIPTS_DIR/$fname/" 2>/dev/null
        fi
    else
        cp "$f" "$SCRIPTS_DIR/" 2>/dev/null
    fi
    UPDATED=$((UPDATED + 1))
done

echo "$REMOTE_VER" > "$SCRIPTS_DIR/version.txt"
# Guardar commit hash después de actualizar
[[ -n "$REMOTE_SHA" ]] && echo "$REMOTE_SHA" > "$COMMIT_HASH_FILE"
chmod -R +x "$SCRIPTS_DIR"/*.sh "$SCRIPTS_DIR"/lib/*.sh "$SCRIPTS_DIR"/protocolos/*.sh "$SCRIPTS_DIR"/herramientas/*.sh "$SCRIPTS_DIR"/usuarios/*.sh "$SCRIPTS_DIR"/languages/*.sh 2>/dev/null

# Fix CRLF from Windows — TODOS los .sh del sistema
find "$SCRIPTS_DIR" -name "*.sh" -type f -exec sed -i 's/\r$//' {} + 2>/dev/null
find "$SCRIPTS_DIR/herramientas" -name "*.sh" -type f -exec sed -i 's/\r$//' {} + 2>/dev/null

ROWC "${GREEN}✓ ${UPDATED} módulos actualizados${RESET}"

#==============================
# [6] IPTABLES GAMING
#==============================

printf "${CYAN}║${RESET} ${GOLD}[6/6]${RESET} Configurando iptables gaming...${CYAN}%*s║${RESET}\n" $(( W - 33 )) ""

IFACE=$(ip route get 8.8.8.8 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')
[[ -z "$IFACE" ]] && IFACE=$(ls /sys/class/net 2>/dev/null | grep -E '^(eth|ens|enp)' | head -n1)
IFACE="${IFACE:-eth0}"

DSCP_COUNT=0
for RULE in "7000:7999" "3478:3480" "8000:9000"; do
    if ! iptables -t mangle -C PREROUTING -p udp --dport "$RULE" -j DSCP --set-dscp-class af41 2>/dev/null; then
        iptables -t mangle -A PREROUTING -p udp --dport "$RULE" -j DSCP --set-dscp-class af41
        DSCP_COUNT=$((DSCP_COUNT + 1))
    fi
done

iptables -N MOVIVIP_OUT >/dev/null 2>&1
iptables -C OUTPUT -j MOVIVIP_OUT >/dev/null 2>&1 || iptables -I OUTPUT 1 -j MOVIVIP_OUT

mkdir -p /etc/iptables
iptables-save > /etc/iptables/rules.v4

ROWC "${GREEN}✓ iptables configurado${RESET}"

#==============================
# RESUMEN
#==============================

rm -rf "$TEMP_DIR"

echo ""
MID
printf "${CYAN}║${RESET}                                                          ${CYAN}║${RESET}\n"
printf "${CYAN}║${RESET}  ${GREEN}✓ ACTUALIZACIÓN COMPLETADA${RESET}                            ${CYAN}║${RESET}\n"
printf "${CYAN}║${RESET}                                                          ${CYAN}║${RESET}\n"
printf "${CYAN}║${RESET}  ${GRAY}Versión:${RESET}  ${GOLD}v${LOCAL_VER}${RESET} → ${GREEN}v${REMOTE_VER}${RESET}${CYAN}%*s║${RESET}\n" $(( W - 23 - ${#LOCAL_VER} - ${#REMOTE_VER} )) ""
printf "${CYAN}║${RESET}  ${GRAY}Módulos:${RESET}  ${WHITE}${UPDATED}${RESET}${CYAN}%*s║${RESET}\n" $(( W - 14 - ${#UPDATED} )) ""
printf "${CYAN}║${RESET}  ${GRAY}Respaldo:${RESET} ${WHITE}${BACKUP_SIZE:-?}${RESET}${CYAN}%*s║${RESET}\n" $(( W - 17 - ${#BACKUP_SIZE} )) ""
printf "${CYAN}║${RESET}                                                          ${CYAN}║${RESET}\n"
MID
printf "${CYAN}║${RESET}  ${GRAY}Restaurar:${RESET} ${WHITE}cp -r ${BACKUP_DIR}/* /etc/movivip/${RESET}${CYAN}%*s║${RESET}\n" $(( W - 8 - ${#BACKUP_DIR} )) ""
printf "${CYAN}║${RESET}                                                          ${CYAN}║${RESET}\n"
BOT

echo ""
read -rp "$(echo -e "${CYAN}   Enter para volver${RESET}")" _
exec bash "$BASE/menu.sh"
