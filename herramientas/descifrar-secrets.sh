#!/bin/bash
# =============================================================
#  MOVIVIP — DESCIFRAR SECRETS PARA GITHUB
#  -------------------------------------------------------------
#  Desencripta archivos .enc con la master key para que el bot
#  generador de keys pueda funcionar en el VPS.
#
#  Los archivos desencriptados se guardan temporalmente y se
#  borran automaticamente despues de usar.
#
#  USO:
#    source /etc/movivip/descifrar-secrets.sh              # carga funciones
#    descifrar_secrets                                      # desencripta todo
#    # Ahora las variables $FB_API_KEY, $FB_AUTH_EMAIL, etc. estan disponibles
#    limpiar_secrets                                        # borra temporales
#
#  USO EN BOT:
#    source /etc/movivip/descifrar-secrets.sh
#    descifrar_secrets
#    # ... usar las variables ...
#    limpiar_secrets
#
#  ALMACENAMIENTO DE LA MASTER KEY (3 opciones, en orden de prioridad):
#    1. Variable de entorno: MOVIVIP_MASTER_KEY
#    2. Archivo: /etc/movivip/.master-key
#    3. Parametro: descifrar_secrets "mi-master-key"
# =============================================================

# ================= RUTAS =================
SECRETS_DIR="/etc/movivip/secrets"
ENCRYPTED_DIR="$SECRETS_DIR/encrypted"
DECRYPTED_DIR="/tmp/.movivip-secrets-$$"
MASTER_KEY_FILE="/etc/movivip/.master-key"

# ================= COLORES =================
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

# ================= OBTENER MASTER KEY =================
obtener_master_key() {
    # 1) Parametro directo
    if [[ -n "${1:-}" ]]; then
        echo "$1"
        return 0
    fi

    # 2) Variable de entorno
    if [[ -n "${MOVIVIP_MASTER_KEY:-}" ]]; then
        echo "$MOVIVIP_MASTER_KEY"
        return 0
    fi

    # 3) Archivo .master-key
    if [[ -f "$MASTER_KEY_FILE" ]]; then
        cat "$MASTER_KEY_FILE" | tr -d '\n\r'
        return 0
    fi

    # 4) Pedir al usuario
    echo -e "${YELLOW}  Ingrese la Master Key para descifrar los secrets:${NC}"
    read -s -p "  Master Key: " MASTER_INPUT
    echo ""
    if [[ -n "$MASTER_INPUT" ]]; then
        echo "$MASTER_INPUT"
        return 0
    fi

    return 1
}

# ================= DESCIFRAR UN ARCHIVO =================
descifrar_archivo() {
    local archivo_enc="$1"
    local master_key="$2"
    local salida="${3:-}"

    if [[ ! -f "$archivo_enc" ]]; then
        echo -e "${RED}  [ERR] Archivo no encontrado: $archivo_enc${NC}"
        return 1
    fi

    # Nombre de salida por defecto (quita .enc)
    if [[ -z "$salida" ]]; then
        salida=$(basename "$archivo_enc" .enc)
    fi

    local ruta_salida="$DECRYPTED_DIR/$salida"

    # OpenSSL AES-256-CBC con PBKDF2 (misma config que encriptar-secrets.ps1)
    openssl enc -d -aes-256-cbc -pbkdf2 -iter 10000 \
        -in "$archivo_enc" \
        -out "$ruta_salida" \
        -pass "pass:$master_key" 2>/dev/null

    if [[ $? -ne 0 ]]; then
        echo -e "${RED}  [ERR] Fallo al descifrar: $archivo_enc${NC}"
        echo -e "${YELLOW}  [!] Verifica que la master key sea correcta.${NC}"
        rm -f "$ruta_salida"
        return 1
    fi

    echo "$ruta_salida"
    return 0
}

# ================= DESCIFRAR TODOS LOS SECRETS =================
descifrar_secrets() {
    local master_key="${1:-}"
    local key_source=""

    echo -e "${CYAN}  ═══ DESCIFRANDO SECRETS ═══${NC}"

    # Obtener master key
    if [[ -z "$master_key" ]]; then
        master_key=$(obtener_master_key)
        if [[ $? -ne 0 ]]; then
            echo -e "${RED}  [ERR] No se pudo obtener la master key.${NC}"
            return 1
        fi
    fi

    # Determinar fuente de la key
    if [[ -n "${MOVIVIP_MASTER_KEY:-}" ]]; then
        key_source="variable de entorno"
    elif [[ -f "$MASTER_KEY_FILE" ]]; then
        key_source="archivo .master-key"
    else
        key_source="ingresada manualmente"
    fi
    echo -e "${GREEN}  [OK] Master key cargada ($key_source)${NC}"

    # Crear directorio temporal
    mkdir -p "$DECRYPTED_DIR"
    chmod 700 "$DECRYPTED_DIR"

    # Buscar archivos .enc
    if [[ ! -d "$ENCRYPTED_DIR" ]]; then
        echo -e "${YELLOW}  [!] Directorio de secrets no encontrado: $ENCRYPTED_DIR${NC}"
        echo -e "${YELLOW}  [!] Ejecuta primero: mkdir -p $ENCRYPTED_DIR${NC}"
        return 1
    fi

    local archivos_encontrados=0
    local archivos_descifrados=0
    local errores=0

    for enc_file in "$ENCRYPTED_DIR"/*.enc; do
        [[ ! -f "$enc_file" ]] && continue
        archivos_encontrados=$((archivos_encontrados + 1))

        local nombre=$(basename "$enc_file" .enc)
        echo -ne "  Descifrando: $nombre..."

        local resultado=$(descifrar_archivo "$enc_file" "$master_key")
        if [[ $? -eq 0 && -f "$resultado" ]]; then
            echo -e " ${GREEN}OK${NC}"
            archivos_descifrados=$((archivos_descifrados + 1))
        else
            echo -e " ${RED}FALLO${NC}"
            errores=$((errores + 1))
        fi
    done

    if [[ $archivos_encontrados -eq 0 ]]; then
        echo -e "${YELLOW}  [!] No se encontraron archivos .enc en $ENCRYPTED_DIR${NC}"
        return 1
    fi

    echo -e "${GREEN}  [OK] $archivos_descifrados/$archivos_encontrados archivos descifrados${NC}"

    if [[ $errores -gt 0 ]]; then
        echo -e "${RED}  [!] $errores errores. Verifica la master key.${NC}"
        return 1
    fi

    # Cargar variables de entorno desde los archivos descifrados
    cargar_variables

    return 0
}

# ================= CARGAR VARIABLES DE ENTORNO =================
cargar_variables() {
    echo -e "${CYAN}  Cargando variables de entorno...${NC}"

    # Buscar config-generador.ps1 descifrado (lo parseamos a variables bash)
    local config_ps1="$DECRYPTED_DIR/config-generador.ps1"
    if [[ -f "$config_ps1" ]]; then
        # Extraer variables del formato PowerShell
        export FB_BASE=$(grep -oP '\$FB_BASE\s*=\s*"([^"]*)"' "$config_ps1" | head -1 | sed 's/.*"\(.*\)"/\1/')
        export FB_LICENCIAS=$(grep -oP '\$FB_LICENCIAS\s*=\s*"([^"]*)"' "$config_ps1" | head -1 | sed 's/.*"\(.*\)"/\1/')
        export FB_API_KEY=$(grep -oP '\$FB_API_KEY\s*=\s*"([^"]*)"' "$config_ps1" | head -1 | sed 's/.*"\(.*\)"/\1/')
        export FB_AUTH_EMAIL=$(grep -oP '\$FB_AUTH_EMAIL\s*=\s*"([^"]*)"' "$config_ps1" | head -1 | sed 's/.*"\(.*\)"/\1/')
        export FB_AUTH_PASS=$(grep -oP '\$FB_AUTH_PASS\s*=\s*"([^"]*)"' "$config_ps1" | head -1 | sed 's/.*"\(.*\)"/\1/')
        export MONEDA=$(grep -oP '\$MONEDA\s*=\s*"([^"]*)"' "$config_ps1" | head -1 | sed 's/.*"\(.*\)"/\1/')
        export DIAS_DEFAULT=$(grep -oP '\$DIAS_DEFAULT\s*=\s*(\d+)' "$config_ps1" | head -1 | sed 's/.*=\s*//')

        # Extraer precios del hashtable
        export PRECIO_BRONCE=$(grep -oP '"bronce"\s*=\s*(\d+)' "$config_ps1" | sed 's/.*=\s*//')
        export PRECIO_PREMIUM=$(grep -oP '"premium"\s*=\s*(\d+)' "$config_ps1" | sed 's/.*=\s*//')
        export PRECIO_PLATINO=$(grep -oP '"platino"\s*=\s*(\d+)' "$config_ps1" | sed 's/.*=\s*//')
        export PRECIO_VITALICIO=$(grep -oP '"vitalicio"\s*=\s*(\d+)' "$config_ps1" | sed 's/.*=\s*//')
        export PRECIO_MAYORISTA=$(grep -oP '"mayorista"\s*=\s*(\d+)' "$config_ps1" | sed 's/.*=\s*//')

        echo -e "${GREEN}  [OK] Variables Firebase cargadas${NC}"
    fi

    # Cargar otros .env descifrados
    for env_file in "$DECRYPTED_DIR"/*.env; do
        [[ ! -f "$env_file" ]] && continue
        while IFS='=' read -r key value; do
            [[ -z "$key" || "$key" =~ ^# ]] && continue
            export "$key=$value"
        done < "$env_file"
        echo -e "${GREEN}  [OK] $(basename "$env_file") cargado${NC}"
    done
}

# ================= GENERAR AUTH TOKEN DE FIREBASE =================
fb_auth_token() {
    if [[ -z "${FB_API_KEY:-}" || -z "${FB_AUTH_EMAIL:-}" || -z "${FB_AUTH_PASS:-}" ]]; then
        echo -e "${RED}  [ERR] Faltan variables FB_API_KEY, FB_AUTH_EMAIL, FB_AUTH_PASS${NC}"
        return 1
    fi

    local auth_url="https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$FB_API_KEY"
    local auth_resp
    auth_resp=$(curl -s --max-time 15 -X POST "$auth_url" \
        -H "Content-Type: application/json" \
        -d "{\"email\":\"$FB_AUTH_EMAIL\",\"password\":\"$FB_AUTH_PASS\",\"returnSecureToken\":true}" 2>/dev/null)

    if [[ $? -ne 0 || -z "$auth_resp" ]]; then
        echo -e "${RED}  [ERR] No se pudo conectar a Firebase Auth${NC}"
        return 1
    fi

    local id_token
    id_token=$(echo "$auth_resp" | grep -oP '"idToken"\s*:\s*"([^"]*)"' | sed 's/.*"\(.*\)"/\1/')

    if [[ -z "$id_token" ]]; then
        echo -e "${RED}  [ERR] Firebase Auth no devolvio token${NC}"
        return 1
    fi

    echo "$id_token"
    return 0
}

# ================= GENERAR KEY DE LICENCIA =================
generar_key() {
    local cliente="${1:-anonimo}"
    local plan="${2:-premium}"
    local dias="${3:-30}"

    echo -e "${CYAN}  Generando key para: $cliente ($plan, $dias dias)${NC}"

    # Generar KEY-XXXXXXXXXX (10 hex aleatorios)
    local hex=$(openssl rand -hex 5 | tr '[:lower:]' '[:upper:]')
    local key="KEY-$hex"

    # Calcular expiracion
    local ahora=$(date +%s)
    local expira=0
    if [[ "$plan" != "vitalicio" ]]; then
        expira=$((ahora + dias * 86400))
    fi

    # Precio segun plan
    local precio=0
    case "$plan" in
        bronce)    precio=${PRECIO_BRONCE:-10} ;;
        premium)   precio=${PRECIO_PREMIUM:-20} ;;
        platino)   precio=${PRECIO_PLATINO:-35} ;;
        vitalicio) precio=${PRECIO_VITALICIO:-60} ;;
        mayorista) precio=${PRECIO_MAYORISTA:-100} ;;
    esac

    # Obtener token de Firebase
    local token=$(fb_auth_token)
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}  [ERR] No se pudo autenticar en Firebase${NC}"
        return 1
    fi

    # Subir a Firebase
    local url="https://${FB_BASE}/${FB_LICENCIAS}/${key}.json?auth=$token"
    local body="{\"activa\":true,\"creada\":$ahora,\"expira\":$expira,\"cliente\":\"$cliente\",\"plan\":\"$plan\",\"precio\":$precio}"

    local resp
    resp=$(curl -s --max-time 20 -X PUT "$url" \
        -H "Content-Type: application/json" \
        -d "$body" 2>/dev/null)

    if [[ $? -ne 0 ]]; then
        echo -e "${RED}  [ERR] Fallo al subir a Firebase${NC}"
        return 1
    fi

    echo -e "${GREEN}  [OK] Key generada: $key${NC}"
    echo "$key"
    return 0
}

# ================= VERIFICAR KEY MAYORISTA =================
verificar_mayorista() {
    local key_mayorista="$1"

    if [[ -z "$key_mayorista" ]]; then
        return 1
    fi

    # Consultar Firebase (lectura publica, no necesita auth)
    local url="https://${FB_BASE}/maestros/${key_mayorista}.json"
    local resp
    resp=$(curl -s --max-time 10 "$url" 2>/dev/null)

    if [[ -z "$resp" || "$resp" == "null" ]]; then
        return 1
    fi

    # Verificar que este activa
    local activa
    activa=$(echo "$resp" | grep -oP '"activa"\s*:\s*(true|false)' | sed 's/.*:\s*//')
    [[ "$activa" == "true" ]] && return 0
    return 1
}

# ================= LIMPIAR SECRETS TEMPORALES =================
limpiar_secrets() {
    if [[ -d "$DECRYPTED_DIR" ]]; then
        # Sobreescribir archivos antes de borrar (seguridad)
        find "$DECRYPTED_DIR" -type f -exec sh -c 'dd if=/dev/urandom of="$1" bs=1 count=$(stat -c%s "$1" 2>/dev/null || echo 1) conv=notrunc 2>/dev/null' _ {} \; 2>/dev/null
        rm -rf "$DECRYPTED_DIR"
        echo -e "${GREEN}  [OK] Secrets temporales eliminados${NC}"
    fi
}

# ================= INSTALAR MASTER KEY =================
instalar_master_key() {
    local key="${1:-}"

    if [[ -z "$key" ]]; then
        echo -e "${YELLOW}  Ingrese la Master Key para instalar en el VPS:${NC}"
        read -s -p "  Master Key: " key
        echo ""
    fi

    if [[ -z "$key" ]]; then
        echo -e "${RED}  [ERR] La master key no puede estar vacia.${NC}"
        return 1
    fi

    mkdir -p /etc/movivip
    echo -n "$key" > "$MASTER_KEY_FILE"
    chmod 600 "$MASTER_KEY_FILE"
    chown root:root "$MASTER_KEY_FILE"

    echo -e "${GREEN}  [OK] Master key instalada en $MASTER_KEY_FILE${NC}"
    echo -e "${YELLOW}  [!] Archivos .enc deben estar en: $ENCRYPTED_DIR${NC}"
    return 0
}

# ================= SETUP INICIAL =================
setup_secrets() {
    echo -e "${CYAN}  ═══ SETUP DE SECRETS ═══${NC}"

    mkdir -p "$SECRETS_DIR"
    mkdir -p "$ENCRYPTED_DIR"
    chmod 700 "$SECRETS_DIR"

    # Verificar si ya hay master key
    if [[ -f "$MASTER_KEY_FILE" ]]; then
        echo -e "${GREEN}  [OK] Master key ya instalada${NC}"
    else
        echo -e "${YELLOW}  No hay master key instalada.${NC}"
        instalar_master_key
    fi

    echo ""
    echo -e "${CYAN}  Estructura creada:${NC}"
    echo -e "    $SECRETS_DIR/"
    echo -e "    $ENCRYPTED_DIR/   ← sube aqui los .enc desde tu PC"
    echo -e "    $MASTER_KEY_FILE  ← master key (chmod 600)"
    echo ""
    echo -e "${CYAN}  SIGUIENTE PASO:${NC}"
    echo -e "    1. En tu PC, ejecuta: encriptar-secrets.ps1"
    echo -e "    2. Sube los .enc al VPS:"
    echo -e "       scp *.enc root@VPS:$ENCRYPTED_DIR/"
    echo -e "    3. El bot los descifrara automaticamente"
}

# Si se ejecuta directamente (no se sourcea)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        --setup)
            setup_secrets
            ;;
        --install-key)
            instalar_master_key "${2:-}"
            ;;
        --descifrar)
            descifrar_secrets "${2:-}"
            limpiar_secrets
            ;;
        --test)
            descifrar_secrets "${2:-}"
            echo ""
            echo "FB_API_KEY: ${FB_API_KEY:-(no cargado)}"
            echo "FB_AUTH_EMAIL: ${FB_AUTH_EMAIL:-(no cargado)}"
            echo "FB_BASE: ${FB_BASE:-(no cargado)}"
            limpiar_secrets
            ;;
        *)
            echo "Uso: $0 {--setup|--install-key|--descifrar|--test}"
            echo ""
            echo "  --setup          Setup inicial del directorio de secrets"
            echo "  --install-key    Instalar la master key en el VPS"
            echo "  --descifrar      Descifrar todos los archivos .enc"
            echo "  --test           Descifrar y mostrar variables cargadas"
            ;;
    esac
fi
