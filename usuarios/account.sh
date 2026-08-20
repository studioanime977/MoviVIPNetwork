#!/bin/bash
#==================================================
# MoviVIP Network - Account Management (Non-Interactive)
# Called by Telegram bot via SSH
# Usage: bash account.sh <action> [args...]
#
# Actions:
#   add <user> <pass> <days> <limit> <consumo_bytes> [gb_zipvpn]
#   delete <user> [pass]
#   list
#   get_config
#   zipvpn_add <password> <days> <gb_limit>
#   zipvpn_remove <password>
#   zipvpn_list
#   xray_add <username>
#   xray_remove <email>
#   xray_list
#   slowdns_key
#==================================================

BASE="/etc/movivip"
CONFIG="$BASE/config.conf"
XRAY_CFG="/usr/local/etc/xray/config.json"
ZIVPN_CFG="/etc/zivpn/config.json"
ZIVPN_EXP="/etc/zivpn/expira.conf"
ZIVPN_LIM="/etc/zivpn/limites.conf"
SLOWDNS_KEY="/etc/slowdns/server.pub"

[[ -f "$CONFIG" ]] && source "$CONFIG"

ACTION="$1"

#==================================================
# HELPER: safe jq+mv with chmod 644
# Usage: safe_jq_update FILE JQ_ARG1 JQ_ARG2 ... JQ_EXPR
# The LAST argument is always the jq expression
#==================================================
safe_jq_update() {
    local TARGET="$1"
    shift
    # All remaining args are jq args (--arg, expression, etc)
    local TMP=$(mktemp)
    jq "$@" "$TARGET" > "$TMP" 2>/dev/null
    if [[ $? -eq 0 ]] && [[ -s "$TMP" ]]; then
        mv -f "$TMP" "$TARGET"
        chmod 644 "$TARGET"
        return 0
    else
        rm -f "$TMP"
        return 1
    fi
}

#==================================================
# HELPER: safe file replace (conf files)
# Always replaces, even if result is empty
#==================================================
safe_conf_replace() {
    local TARGET="$1"
    local TMP="$2"
    if [[ -f "$TMP" ]]; then
        mv -f "$TMP" "$TARGET"
    fi
}

#==================================================
# ADD SSH USER (same flow as add.sh)
#==================================================
cmd_add() {
    local USER="$1"
    local PASS="$2"
    local DIAS="${3:-30}"
    local LIMITE="${4:-0}"
    local CONSUMO_BYTES="${5:-0}"
    local GB_ZIPVPN="${6:-0}"

    # Validate
    if [[ -z "$USER" || -z "$PASS" ]]; then
        echo "ERROR: user and password required"
        exit 1
    fi

    if id "$USER" &>/dev/null; then
        echo "ERROR: user already exists"
        exit 1
    fi

    # Calculate expiry date
    FECHA=$(date -d "+$DIAS days" +"%Y-%m-%d")

    # 1. Create user (same as add.sh)
    useradd -e "$FECHA" -M -s /usr/sbin/nologin "$USER"
    if [[ $? -ne 0 ]]; then
        echo "ERROR: useradd failed"
        exit 1
    fi

    # 2. Set password (same as add.sh: openssl passwd -6)
    HASH=$(openssl passwd -6 "$PASS" 2>/dev/null)
    usermod -p "$HASH" "$USER"
    if [[ $? -ne 0 ]]; then
        echo "ERROR: usermod failed"
        userdel -f "$USER" &>/dev/null
        exit 1
    fi

    # 3. Save data limit (same as add.sh)
    LIM_CONF="$BASE/sistema/limites_consumo.conf"
    mkdir -p "$BASE/sistema" 2>/dev/null
    touch "$LIM_CONF" 2>/dev/null
    grep -v "^$USER=" "$LIM_CONF" > "$LIM_CONF.tmp" 2>/dev/null
    safe_conf_replace "$LIM_CONF" "$LIM_CONF.tmp"
    echo "$USER=$CONSUMO_BYTES" >> "$LIM_CONF"

    # 4. Save connection limit (same as add.sh)
    CONN_LIM_CONF="$BASE/sistema/limites_conexiones.conf"
    touch "$CONN_LIM_CONF" 2>/dev/null
    grep -v "^$USER=" "$CONN_LIM_CONF" > "$CONN_LIM_CONF.tmp" 2>/dev/null
    safe_conf_replace "$CONN_LIM_CONF" "$CONN_LIM_CONF.tmp"
    echo "$USER=$LIMITE" >> "$CONN_LIM_CONF"

    # 5. Add to Xray (same as v2ray.sh create_vmess_user)
    cmd_xray_add "$USER"

    # 6. Add to ZipVPN with days and GB limit
    cmd_zipvpn_add "$PASS" "$DIAS" "$GB_ZIPVPN"

    # Output success with info
    echo "OK:$USER:$PASS:$FECHA:$LIMITE:$CONSUMO_BYTES"
}

#==================================================
# DELETE SSH USER (same flow as delete.sh)
#==================================================
cmd_delete() {
    local USER="$1"
    local PASS="$2"

    if [[ -z "$USER" ]]; then
        echo "ERROR: user required"
        exit 1
    fi

    if ! id "$USER" &>/dev/null; then
        echo "ERROR: user does not exist"
        exit 1
    fi

    # 1. Kill processes (same as delete.sh)
    pkill -u "$USER" &>/dev/null
    sleep 1

    # 2. Delete user (same as delete.sh: userdel -f)
    userdel -f "$USER" &>/dev/null

    # 3. Clean limit files (same as delete.sh)
    for F in "$BASE/sistema/limites_consumo.conf" "$BASE/sistema/limites_conexiones.conf"; do
        if [[ -f "$F" ]]; then
            grep -v "^$USER=" "$F" > "$F.tmp" 2>/dev/null
            safe_conf_replace "$F" "$F.tmp"
        fi
    done

    # 4. Remove from Xray
    cmd_xray_remove "${USER}@movivip"

    # 5. Remove from ZipVPN (using password if provided)
    if [[ -n "$PASS" ]]; then
        cmd_zipvpn_remove "$PASS"
    fi

    echo "OK:deleted:$USER"
}

#==================================================
# LIST SSH USERS
#==================================================
cmd_list() {
    local USERS=$(awk -F: '$3>=1000 && $1!="nobody"{print $1}' /etc/passwd)
    if [[ -z "$USERS" ]]; then
        echo "EMPTY"
        return
    fi

    while read -r USER; do
        FECHA=$(chage -l "$USER" 2>/dev/null | grep "Account expires" | cut -d: -f2 | xargs)
        echo "$USER|$FECHA"
    done <<< "$USERS"
}

#==================================================
# GET SERVER CONFIG
#==================================================
cmd_get_config() {
    local IP=$(curl -4 -s ifconfig.me 2>/dev/null)
    [[ -z "$IP" ]] && IP=$(hostname -I | awk '{print $1}')
    local HOST="${SERVER_DOMAIN:-$IP}"

    echo "IP=$IP"
    echo "DOMAIN=$HOST"
    echo "OPENSSH=${OPENSSH:-OFF}"
    echo "DROPBEAR=${DROPBEAR:-OFF}"
    echo "DROPBEAR_PORT=${DROPBEAR_PORT:-143}"
    echo "SSL=${SSL:-OFF}"
    echo "BADVPN=${BADVPN:-OFF}"
    echo "UDP_CUSTOM=${UDP_CUSTOM:-OFF}"
    echo "ZIPVPN=${ZIPVPN:-OFF}"
    echo "ZIPVPN_PORT=${ZIPVPN_PORT:-5667}"
    echo "WEBSOCKET=${WEBSOCKET:-OFF}"
    echo "SLOWDNS=${SLOWDNS:-OFF}"
    echo "SLOWDNS_NS=${SLOWDNS_NS:-}"
    echo "SLOWDNS_KEY=${SLOWDNS_KEY:-}"
    echo "SERVER_DOMAIN=${SERVER_DOMAIN:-}"
    echo "CLOUDFRONT_DOMAIN=${CLOUDFRONT_DOMAIN:-}"
}

#==================================================
# ZIPVPN - Add password (same as zipvpn.sh)
#==================================================
cmd_zipvpn_add() {
    local PASS="$1"
    local DIAS="${2:-0}"
    local GB="${3:-0}"

    if [[ -z "$PASS" ]]; then
        echo "ERROR: password required"
        exit 1
    fi

    # Check if already exists in config.json
    if jq -e --arg pass "$PASS" '.auth.config[] | select(.==$pass)' "$ZIVPN_CFG" >/dev/null 2>&1; then
        echo "EXISTS:$PASS"
        return
    fi

    # 1. Add to config.json (same as zipvpn.sh) — with safe_jq + chmod
    safe_jq_update "$ZIVPN_CFG" --arg pass "$PASS" '.auth.config += [$pass]'

    # 2. Add expiry (same as zipvpn.sh set_exp)
    if [[ "$DIAS" -gt 0 ]]; then
        EXP=$(date -d "+${DIAS} days" +%s)
    else
        EXP=0
    fi
    grep -v "^${PASS}|" "$ZIVPN_EXP" > /tmp/zivpn-exp.tmp 2>/dev/null
    echo "${PASS}|${EXP}" >> /tmp/zivpn-exp.tmp
    safe_conf_replace "$ZIVPN_EXP" /tmp/zivpn-exp.tmp

    # 3. Add limit (same as zipvpn.sh set_lim)
    grep -v "^${PASS}|" "$ZIVPN_LIM" > /tmp/zivpn-lim.tmp 2>/dev/null
    echo "${PASS}|${GB}" >> /tmp/zivpn-lim.tmp
    safe_conf_replace "$ZIVPN_LIM" /tmp/zivpn-lim.tmp

    # 4. Restart zivpn
    systemctl restart zivpn 2>/dev/null

    echo "OK:zipvpn_added:$PASS"
}

#==================================================
# ZIPVPN - Remove password (same as zipvpn.sh)
#==================================================
cmd_zipvpn_remove() {
    local PASS="$1"

    if [[ -z "$PASS" ]]; then
        echo "ERROR: password required"
        exit 1
    fi

    # 1. Remove from config.json — with safe_jq + chmod
    safe_jq_update "$ZIVPN_CFG" --arg pass "$PASS" '.auth.config |= map(select(. != $pass))'

    # 2. Remove from expira.conf
    awk -F'|' -v p="$PASS" '$1!=p' "$ZIVPN_EXP" > /tmp/zivpn-exp.tmp 2>/dev/null
    safe_conf_replace "$ZIVPN_EXP" /tmp/zivpn-exp.tmp

    # 3. Remove from limites.conf
    awk -F'|' -v p="$PASS" '$1!=p' "$ZIVPN_LIM" > /tmp/zivpn-lim.tmp 2>/dev/null
    safe_conf_replace "$ZIVPN_LIM" /tmp/zivpn-lim.tmp

    # 4. Restart
    systemctl restart zivpn 2>/dev/null

    echo "OK:zipvpn_removed:$PASS"
}

#==================================================
# ZIPVPN - List passwords (same as zipvpn.sh)
#==================================================
cmd_zipvpn_list() {
    if [[ ! -f "$ZIVPN_CFG" ]]; then
        echo "ERROR: zivpn not installed"
        exit 1
    fi

    local TOTAL=$(jq '.auth.config | length' "$ZIVPN_CFG")
    echo "TOTAL=$TOTAL"

    local NOW=$(date +%s)
    while IFS= read -r PASS; do
        [[ -z "$PASS" ]] && continue
        # Get expiry
        EXP=$(awk -F'|' -v p="$PASS" '$1==p{print $2; exit}' "$ZIVPN_EXP" 2>/dev/null)
        EXP=${EXP:-0}
        # Get limit
        LIM=$(awk -F'|' -v p="$PASS" '$1==p{print $2; exit}' "$ZIVPN_LIM" 2>/dev/null)
        LIM=${LIM:-0}
        # Calculate days left
        if [[ "$EXP" == "0" || "$EXP" == "" ]]; then
            DAYS_LEFT="0"
        elif [[ "$EXP" -gt "$NOW" ]]; then
            DAYS_LEFT=$(( (EXP - NOW) / 86400 ))
        else
            DAYS_LEFT="0"
        fi
        echo "PASS=$PASS|EXP=$EXP|DAYS=$DAYS_LEFT|GB=$LIM"
    done < <(jq -r '.auth.config[]' "$ZIVPN_CFG")
}

#==================================================
# XRAY - Add user (same as v2ray.sh create_vmess_user)
#==================================================
cmd_xray_add() {
    local USERNAME="$1"

    if [[ -z "$USERNAME" ]]; then
        echo "ERROR: username required"
        exit 1
    fi

    if [[ ! -f "$XRAY_CFG" ]]; then
        echo "ERROR: xray config not found"
        exit 1
    fi

    # Check if already exists
    if jq -e --arg email "${USERNAME}@movivip" '.inbounds[].settings.clients[]? | select(.email==$email)' "$XRAY_CFG" >/dev/null 2>&1; then
        echo "EXISTS:$USERNAME"
        return
    fi

    # Generate UUID (same as v2ray.sh)
    UUID=$(cat /proc/sys/kernel/random/uuid)

    # Add to ALL inbounds with safe_jq + chmod 644
    safe_jq_update "$XRAY_CFG" --arg uuid "$UUID" --arg email "${USERNAME}@movivip" \
        '.inbounds[].settings.clients += [{"id":$uuid,"level":0,"email":$email}]'

    if [[ $? -ne 0 ]]; then
        echo "ERROR: xray jq update failed"
        return 1
    fi

    # Restart xray
    systemctl restart xray 2>/dev/null

    echo "OK:xray_added:$USERNAME:$UUID"
}

#==================================================
# XRAY - Remove user (safe per-inbound removal)
#==================================================
cmd_xray_remove() {
    local EMAIL_RAW="$1"

    if [[ -z "$EMAIL_RAW" ]]; then
        echo "ERROR: email required"
        exit 1
    fi

    if [[ ! -f "$XRAY_CFG" ]]; then
        echo "ERROR: xray config not found"
        exit 1
    fi

    # Build both forms: bare and @movivip (to match whatever add used)
    local EMAIL_BARE="$(echo "$EMAIL_RAW" | sed 's/@movivip//g')"
    local EMAIL_FULL="${EMAIL_BARE}@movivip"

    # Remove from ALL inbounds — match both bare and @movivip forms
    safe_jq_update "$XRAY_CFG" --arg e1 "$EMAIL_BARE" --arg e2 "$EMAIL_FULL" \
        '.inbounds |= [.[] | if .settings.clients then .settings.clients = [.settings.clients[]? | select(.email != $e1 and .email != $e2)] else . end]'

    if [[ $? -ne 0 ]]; then
        echo "ERROR: xray jq remove failed"
        return 1
    fi

    # Restart xray
    systemctl restart xray 2>/dev/null

    echo "OK:xray_removed:$EMAIL_RAW"
}

#==================================================
# XRAY - List clients
#==================================================
cmd_xray_list() {
    if [[ ! -f "$XRAY_CFG" ]]; then
        echo "ERROR: xray config not found"
        exit 1
    fi

    jq -r '.inbounds[] | .tag as $tag | .protocol as $proto | .settings.clients[]? | "\(.email)|\(.id // .password // "")|\($proto)|\($tag)"' "$XRAY_CFG" 2>/dev/null
}

#==================================================
# SLOWDNS - Get public key
#==================================================
cmd_slowdns_key() {
    if [[ -f "$SLOWDNS_KEY" ]]; then
        local KEY=$(cat "$SLOWDNS_KEY" 2>/dev/null)
        if [[ -n "$KEY" && ${#KEY} -ge 32 ]]; then
            echo "KEY=$KEY"
        else
            echo "ERROR: key file empty or invalid"
        fi
    else
        echo "ERROR: slowdns key not found"
    fi
}

#==================================================
# MAIN DISPATCH
#==================================================
case "$ACTION" in
    add)
        cmd_add "$2" "$3" "$4" "$5" "$6" "$7"
        ;;
    delete)
        cmd_delete "$2" "$3"
        ;;
    list)
        cmd_list
        ;;
    get_config)
        cmd_get_config
        ;;
    zipvpn_add)
        cmd_zipvpn_add "$2" "$3" "$4"
        ;;
    zipvpn_remove)
        cmd_zipvpn_remove "$2"
        ;;
    zipvpn_list)
        cmd_zipvpn_list
        ;;
    xray_add)
        cmd_xray_add "$2"
        ;;
    xray_remove)
        cmd_xray_remove "$2"
        ;;
    xray_list)
        cmd_xray_list
        ;;
    slowdns_key)
        cmd_slowdns_key
        ;;
    set_limit)
        # set_limit <username> <gb_limit> — Edit SSH consumption limit (0=unlimited)
        _SL_USER="$2"
        _SL_GB="${3:-0}"
        _SL_BYTES=0
        if [[ "$_SL_GB" != "0" && -n "$_SL_GB" ]]; then
            _SL_BYTES=$(awk "BEGIN{printf \"%d\", $_SL_GB * 1073741824}")
        fi
        LIM_CONF="/etc/movivip/sistema/limites_consumo.conf"
        # Remove old entry if exists
        if [[ -f "$LIM_CONF" ]]; then
            grep -v "^${_SL_USER}=" "$LIM_CONF" > /tmp/lim_tmp 2>/dev/null
            mv /tmp/lim_tmp "$LIM_CONF"
        fi
        # Add new limit (0 = unlimited)
        echo "${_SL_USER}=${_SL_BYTES}" >> "$LIM_CONF"
        echo "OK:$_SL_USER:$_SL_GB"
        ;;
    get_limit)
        # get_limit <username> — Get current limit in GB
        _GL_USER="$2"
        LIM_CONF="/etc/movivip/sistema/limites_consumo.conf"
        _GL_BYTES=0
        if [[ -f "$LIM_CONF" ]]; then
            _GL_LINE=$(grep "^${_GL_USER}=" "$LIM_CONF" | tail -1)
            if [[ -n "$_GL_LINE" ]]; then
                _GL_BYTES=$(echo "$_GL_LINE" | cut -d= -f2)
            fi
        fi
        _GL_GB=0
        if [[ "$_GL_BYTES" != "0" && -n "$_GL_BYTES" ]]; then
            _GL_GB=$(awk "BEGIN{printf \"%.1f\", $_GL_BYTES / 1073741824}")
        fi
        echo "$_GL_USER:$_GL_GB"
        ;;
    zipvpn_set_limit)
        # zipvpn_set_limit <password> <gb_limit> — Edit ZipVPN GB limit (0=unlimited)
        _ZSL_PASS="$2"
        _ZSL_GB="${3:-0}"
        ZIVPN_LIM="/etc/zivpn/limites.conf"
        if [[ -f "$ZIVPN_LIM" ]]; then
            grep -v "^${_ZSL_PASS}|" "$ZIVPN_LIM" > /tmp/zivpn_lim_tmp 2>/dev/null
            mv /tmp/zivpn_lim_tmp "$ZIVPN_LIM"
        fi
        echo "${_ZSL_PASS}|${_ZSL_GB}" >> "$ZIVPN_LIM"
        echo "OK:$_ZSL_PASS:$_ZSL_GB"
        ;;
    *)
        echo "ERROR: unknown action: $ACTION"
        echo "Usage: account.sh <add|delete|list|get_config|zipvpn_add|zipvpn_remove|zipvpn_list|xray_add|xray_remove|xray_list|slowdns_key|set_limit|get_limit|zipvpn_set_limit>"
        exit 1
        ;;
esac
