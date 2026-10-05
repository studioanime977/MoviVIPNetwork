#!/usr/bin/env bash
# ============================================================================
# PASO: PROTOCOLOS
# Selección e instalación de protocolos. Cada protocolo ya incluye su
# licguard interno, pero aquí orquestamos el flujo de selección.
#
# Lo importante de este paso es que no mienta. Antes hacia:
#
#     bash "$script_path" --install || true
#     ...
#     mv_ok "Protocolos instalados"
#
# El "|| true" se comia cualquier fallo, el paso terminaba con 0 y el
# instalador entero se daba por bueno. Un cliente recibia "instalado
# correctamente" sin un solo protocolo funcionando, y no habia forma de saber
# cual habia fallado ni por que. Ahora cada protocolo deja su veredicto en
# lib/proto-registro.sh, el paso devuelve codigo distinto de 0 si algo quedo
# mal, y el resumen final lista la verdad.
# ============================================================================
set -uo pipefail

# Cargar gate de plan
if [[ -f "${BASE:-/etc/movivip}/lib/plancheck.sh" ]]; then
    # shellcheck source=/dev/null
    source "${BASE:-/etc/movivip}/lib/plancheck.sh"
fi

# nav.sh aporta nav_pick, el selector de dos columnas que usa el menu de
  # protocolos de mas abajo. Sin esto sale "nav_pick: command not found" y la
  # lista de protocolos no llega a mostrarse.
  if [[ -f "${BASE:-/etc/movivip}/lib/nav.sh" ]]; then
      # shellcheck source=/dev/null
      source "${BASE:-/etc/movivip}/lib/nav.sh"
  fi

  # Cargar el registro de protocolos. Si no esta, el paso no puede saber la
  # verdad, y es mejor decirlo que fingir: se avisa y se sigue, porque el
  # instalador tiene que ser utilizable aunque falte un fichero.
if [[ -f "${BASE:-/etc/movivip}/lib/proto-registro.sh" ]]; then
    # shellcheck source=/dev/null
    source "${BASE:-/etc/movivip}/lib/proto-registro.sh"
else
    _proto_sin_registro=1
fi

# ---------------------------------------------------------------------------
# Mapeo de protocolos disponibles (clave -> script en protocolos/)
#
# Solo se listan scripts que existen de verdad. Comprobarlo aqui evita el
# "Script no encontrado: dnstt.sh" que se llevaba un protocolo entero por
# delante: dnstt estaba en el mapa pero el fichero no existia nunca.
# bot, en cambio, si existe y es PREMIUM+, pero no estaba en el mapa, con lo
# cual era imposible instalarlo desde el instalador.
# ---------------------------------------------------------------------------
declare -A PROTO_SCRIPTS=(
    [badvpn]="badvpn.sh"
    [bhttp]="bhttp.sh"
    [bot]="bot.sh"
    [btun]="btun.sh"
    [dropbear]="dropbear.sh"
    [dtunnel]="dtunnel.sh"
    [hcr]="hcr.sh"
    [hysteria]="hysteria.sh"
    [openssh]="openssh.sh"
    [openvpn]="openvpn.sh"
    [shadowsocks]="shadowsocks.sh"
    [slowdns]="slowdns.sh"
    [socks5]="socks5.sh"
    [squid]="squid.sh"
    [ssl]="ssl.sh"
    [systemdns]="systemdns.sh"
    [udpcustom]="udpcustom.sh"
    [v2ray]="v2ray.sh"
    [web]="web.sh"
    [webmin]="webmin.sh"
    [wireguard]="wireguard.sh"
    [xhttp]="xhttp.sh"
    [xui]="xui.sh"
    [zipvpn]="zipvpn.sh"
)

# Protocolos que requieren plan PROVEEDOR/ADMIN (Facturación, 3X-UI, Web MoviVIP)
PROTO_PROVEEDOR=(wireguard web webmin xui)

# Protocolos que requieren plan PREMIUM+ (Bot, Webmin)
PROTO_PREMIUM=(bot webmin)

# ---------------------------------------------------------------------------
# Protocolos que no se pueden instalar solos: necesitan un dato del usuario
#
# Estos no son un fallo del script. Es que el instalador no tiene con quien
# preguntar, asi que se marcan "pendiente" y se reintentan al volver a ejecutar
# el instalador. Es justo el caso que se quejaba el usuario: se elegian todos,
# se paraban porque faltaban datos, y al repetir el instalador habia que
# empezar otra vez desde el principio.
#
# slowdns se comprueba de forma directa porque su propio script lo dice:
#     bash slowdns.sh --install [dominio-ns]
# Si no hay dominio, no hay nada que instalar y no tiene sentido ejecutarlo.
# ---------------------------------------------------------------------------
declare -A PROTO_DATOS=(
    [slowdns]="SLOWDNS_DOMAIN:dominio NS propio para SlowDNS"
)

# Protocolos cuyo fallo se clasifica como "pendiente" y no como error de
# instalacion, porque dependen de datos queTodavia no se han proporcionado.
PROTO_DATOS_DEPENDIENTES=(dtunnel slowdns)

# Contadores del paso, para el codigo de salida.
PROTO_N_INSTALADOS=0
PROTO_N_FALLOS=0
PROTO_N_PENDIENTES=0

# ----------------------------------------------------------------------------
# proto_registrar: guardar el veredicto, o avisar si el registro no esta
# ----------------------------------------------------------------------------
proto_registrar() {
    local proto="$1" estado="$2" detalle="${3:-}"
    if [[ "${_proto_sin_registro:-0}" == "1" ]]; then
        # Sin registro no hay persistencia, pero el paso sigue siendo util.
        case "$estado" in
            instalado) (( PROTO_N_INSTALADOS++ )) ;;
            fallo)     (( PROTO_N_FALLOS++ )) ;;
            pendiente) (( PROTO_N_PENDIENTES++ )) ;;
        esac
        return 0
    fi
    proto_reg_registrar "$proto" "$estado" "$detalle"
    case "$estado" in
        instalado) (( PROTO_N_INSTALADOS++ )) ;;
        fallo)     (( PROTO_N_FALLOS++ )) ;;
        pendiente) (( PROTO_N_PENDIENTES++ )) ;;
    esac
}

# ----------------------------------------------------------------------------
# proto_requiere_datos: cual es el dato que falta, o nada si esta todo
# ----------------------------------------------------------------------------
proto_requiere_datos() {
    local proto="$1" spec="${PROTO_DATOS[$proto]:-}"
    [[ -z "$spec" ]] && return 1
    local var="${spec%%:*}" desc="${spec#*:}"
    local valor="${!var:-}"
    if [[ -z "$valor" ]]; then
        printf '%s\n' "$desc"
        return 0
    fi
    return 1
}

# ----------------------------------------------------------------------------
# proto_depende_de_datos: true si este protocolo no se puede instalar sin que
# el usuario de un dato primero
# ----------------------------------------------------------------------------
proto_depende_de_datos() {
    local proto="$1" p
    for p in ${PROTO_DATOS_DEPENDIENTES[@]+"${PROTO_DATOS_DEPENDIENTES[@]}"}; do
        [[ "$proto" == "$p" ]] && return 0
    done
    return 1
}

# ---------------------------------------------------------------------------
# Verifica si un protocolo está disponible para el plan actual
# ---------------------------------------------------------------------------
proto_disponible() {
    local proto="$1"
    local script="${PROTO_SCRIPTS[$proto]:-}"
    if [[ -z "$script" ]]; then
        return 1
    fi
    
    # 1. Gate de proveedor/admin
    for p in "${PROTO_PROVEEDOR[@]}"; do
        if [[ "$proto" == "$p" ]]; then
            if declare -F es_proveedor >/dev/null 2>&1; then
                if ! es_proveedor; then
                    return 1
                fi
            fi
            return 0
        fi
    done
    
    # 2. Gate de premium+
    for p in "${PROTO_PREMIUM[@]}"; do
        if [[ "$proto" == "$p" ]]; then
            if declare -F es_premium >/dev/null 2>&1; then
                if ! es_premium && ! es_proveedor; then
                    return 1
                fi
            fi
            return 0
        fi
    done
    
    # 3. Protocolos básicos (bronze/standard)
    return 0
}

# ---------------------------------------------------------------------------
# Ejecuta la instalación de un protocolo
#
# Devuelve 0 solo si el script devolvio 0. Cualquier otra cosa se registra y se
# propaga: aqui no se traga ningun error.
# ----------------------------------------------------------------------------
proto_instalar() {
    local proto="$1"
    local script="${PROTO_SCRIPTS[$proto]:-}"
    if [[ -z "$script" ]]; then
        mv_error "Protocolo desconocido: $proto"
        proto_registrar "$proto" fallo "no esta en el mapa de protocolos"
        return 1
    fi
    local script_path="${BASE:-/etc/movivip}/protocolos/$script"
    if [[ ! -f "$script_path" ]]; then
        mv_error "Script no encontrado: $script_path"
        proto_registrar "$proto" fallo "falta el script $script"
        return 1
    fi

    # Si falta un dato conocido, no se ejecuta: se deja pendiente y se explica
    # cual. Ejecutar a ciegas solo produce un error confuso.
    local falta
    if falta="$(proto_requiere_datos "$proto")"; then
        mv_warn "$proto: falta ${falta}. Queda pendiente."
        mv_detalle "  Se instalara solo cuando ese dato este disponible."
        proto_registrar "$proto" pendiente "falta ${falta}"
        return 2
    fi

    mv_fase "Instalando $proto"
    local rc=0
    bash "$script_path" --install || rc=$?

    if (( rc == 0 )); then
        mv_ok "$proto"
        proto_registrar "$proto" instalado "ok"
        return 0
    fi

    # Un protocolo que depende de datos y falla no es un instalador roto: es un
    # dato que no se pudo pedir. Se marca pendiente para reintentarlo luego.
    if proto_depende_de_datos "$proto"; then
        mv_warn "$proto fallo (codigo $rc). Necesita datos que faltan."
        proto_registrar "$proto" pendiente "requiere datos, codigo $rc"
        return 2
    fi

    mv_error "$proto fallo (codigo $rc)"
    proto_registrar "$proto" fallo "codigo $rc"
    return 1
}

# ---------------------------------------------------------------------------
# Reintento: lo que quedo pendiente o fallo en una ejecucion anterior
#
# Es lo que hace que repetir el instalador continue donde se quedo en vez de
# empezar de cero. Solo se reintentan los que el plan actual permite.
# ---------------------------------------------------------------------------
proto_reanudar() {
    local pendientes
    pendientes="$(proto_reg_no_instalados)"
    [[ -z "$pendientes" ]] && return 0

    local lista=()
    local p
    while IFS= read -r p; do
        [[ -z "$p" ]] && continue
        proto_disponible "$p" && lista+=("$p")
    done <<< "$pendientes"

    (( ${#lista[@]} == 0 )) && return 0

    mv_fase "Reanudando instalacion anterior"
    mv_detalle "Protocolos pendientes de la ultima ejecucion: ${lista[*]}"
    for p in "${lista[@]}"; do
        # El resultado ya no importa aqui: se acumula en los contadores y lo
        # decide el codigo de salida de paso_protocolos.
        proto_instalar "$p" || true
    done
    return 0
}

# ---------------------------------------------------------------------------
# Instalacion en lote (modo headless: lista separada por comas, o "todos")
# ---------------------------------------------------------------------------
proto_instalar_lote() {
    local lista="$1"
    IFS=',' read -ra protos <<< "$lista"
    for proto in "${protos[@]}"; do
        proto="$(echo "$proto" | xargs)"  # trim
        if proto_disponible "$proto"; then
            proto_instalar "$proto" || true
        else
            mv_warn "Protocolo no disponible para tu plan: $proto"
            proto_registrar "$proto" omitido "requiere otro plan"
        fi
    done
}

# ---------------------------------------------------------------------------
# Modo "todos"
#
# Instala todo lo disponible. Los protocolos que necesitan un dato no se
# ejecutan a ciegas: quedan pendientes con el motivo, y el resumen final lo
# dice. Volver a ejecutar el instalador los reintenta solos.
# ---------------------------------------------------------------------------
proto_instalar_todos() {
    mv_fase "Instalando todos los protocolos disponibles"

    # Recorrer en orden estable: PROTO_SCRIPTS es asociativo y Bash no
    # garantiza el orden de las claves, asi que un "todos" podia instalar en
    # orden distinto en cada ejecucion.
    local orden=(badvpn bhttp bot btun dropbear dtunnel hcr hysteria openssh
                 openvpn shadowsocks slowdns socks5 squid ssl systemdns
                 udpcustom v2ray web webmin wireguard xhttp xui zipvpn)
    local proto
    for proto in "${orden[@]}"; do
        [[ -n "${PROTO_SCRIPTS[$proto]:-}" ]] || continue
        if proto_disponible "$proto"; then
            proto_instalar "$proto" || true
        else
            mv_warn "$proto: no disponible para tu plan"
            proto_registrar "$proto" omitido "requiere otro plan"
        fi
    done
}

# ---------------------------------------------------------------------------
# Menú interactivo de selección de protocolos
# ---------------------------------------------------------------------------
proto_menu_seleccion() {
    local disponibles=() etiquetas=()
    # RED solo la define lib/anim.sh, que este fichero no sourcea. Con
    # "set -u" (activo arriba) "$RED" a secas abortaba el instalador entero
    # al primer protocolo no disponible, en modo no interactivo o sin TTY.
    # Mismo patron que los 10 protocolos: valor por defecto vacio.
    local RED="${MV_RED:-$'\033[31m'}"
    local CYAN="${MV_CYN:-$'\033[36m'}"
    local GREEN="${MV_GRN:-$'\033[32m'}"
    local YELLOW="${MV_YLW:-$'\033[33m'}"
    local RESET="${MV_R:-$'\033[0m'}"
    for proto in "${!PROTO_SCRIPTS[@]}"; do
        if proto_disponible "$proto"; then
            disponibles+=("$proto")
            # Etiqueta con indicador de tier
            local label="$proto"
            for p in "${PROTO_PROVEEDOR[@]}"; do
                [[ "$proto" == "$p" ]] && label+=" ${CYAN}[PROVEEDOR]${RESET}"
            done
            for p in "${PROTO_PREMIUM[@]}"; do
                [[ "$proto" == "$p" ]] && label+=" ${GREEN}[PREMIUM+]${RESET}"
            done
            etiquetas+=("$label")
        else
            local label="$proto"
            for p in "${PROTO_PROVEEDOR[@]}"; do
                [[ "$proto" == "$p" ]] && label+=" ${RED}(requiere PROVEEDOR)${RESET}"
            done
            for p in "${PROTO_PREMIUM[@]}"; do
                [[ "$proto" == "$p" ]] && label+=" ${YELLOW}(requiere PREMIUM+)${RESET}"
            done
            etiquetas+=("$label")
        fi
    done

    # Los pendientes de una ejecucion anterior van primero: si el usuario vuelve
    # a ejecutar el instalador, lo que quiere es acabar lo que quedo a medias.
    local reabrir=()
    if declare -F proto_reg_no_instalados >/dev/null 2>&1; then
        local p
        while IFS= read -r p; do
            [[ -z "$p" ]] && continue
            proto_disponible "$p" || continue
            # Localizar su indice en la lista de disponibles.
            local i idx
            for i in "${!disponibles[@]}"; do
                if [[ "${disponibles[$i]}" == "$p" ]]; then
                    idx=$(( i + 1 ))
                    reabrir+=("$idx")
                fi
            done
        done < <(proto_reg_no_instalados)
        if (( ${#reabrir[@]} > 0 )); then
            mv_detalle "Pendientes de la ultima ejecucion: ${reabrir[*]}"
        fi
    fi

    local n_proto="${#etiquetas[@]}"
    etiquetas+=("Instalar todos los disponibles")
    local idx_todos=$(( n_proto + 1 ))
    etiquetas+=("Terminar seleccion")

    while true; do
        mv_fase "Seleccion de protocolos"
        local sel
        sel=$(nav_pick "Protocolos a instalar:" "${etiquetas[@]}") || return 1
        if (( sel == n_proto + 2 )); then
            break
        fi
        if (( sel == idx_todos )); then
            proto_instalar_todos
            continue
        fi
        local proto="${disponibles[sel-1]:-}"
        if [[ -n "$proto" ]]; then
            # Aqui antes habia un "|| true" que hacia el error invisible.
            proto_instalar "$proto" || true
        fi
    done
}

# ---------------------------------------------------------------------------
# Orquestador del paso protocolos
# ---------------------------------------------------------------------------
paso_protocolos() {
    mv_fase "Instalacion de protocolos"

    # Antes de nada: intentar cerrar lo que quedo a medias.
    proto_reanudar

    # Modo headless: PROTOCOLOS="badvpn,ssl,web" bash install.sh
    #              PROTOCOLOS="todos"          bash install.sh
    if [[ -n "${PROTOCOLOS:-}" ]]; then
        if [[ "${PROTOCOLOS//[[:space:]]/}" == "todos" ]]; then
            proto_instalar_todos
        else
            proto_instalar_lote "$PROTOCOLOS"
        fi
    else
        proto_menu_seleccion
    fi

    echo ""

    # Decir la verdad sobre lo que ha pasado, en vez de un "Protocolos
    # instalados" que no significaba nada.
    if declare -F proto_reg_cuenta >/dev/null 2>&1; then
        local inst="${PROTO_N_INSTALADOS}" fall="${PROTO_N_FALLOS}" pend="${PROTO_N_PENDIENTES}"
        if (( pend > 0 )); then
            mv_warn "Protocolos pendientes por falta de datos: $pend"
            local p
            while IFS= read -r p; do
                [[ -z "$p" ]] && continue
                mv_detalle "  - $p"
            done < <(proto_reg_por_estado pendiente)
            mv_detalle "  Vuelve a ejecutar el instalador para instalarlos."
        fi
        if (( fall > 0 )); then
            mv_error "Protocolos con fallo: $fall"
            local p
            while IFS= read -r p; do
                [[ -z "$p" ]] && continue
                mv_detalle "  - $p"
            done < <(proto_reg_por_estado fallo)
        fi
    fi

    # Con fallos o pendientes, este paso NO va bien. Antes devolvia 0 siempre y
    # por eso el instalador entero anunciaba exito sin tener nada.
    if (( PROTO_N_FALLOS > 0 )); then
        return 1
    fi

    mv_ok "Protocolos instalados: $PROTO_N_INSTALADOS"
    if (( PROTO_N_PENDIENTES > 0 )); then
        mv_detalle "Pendientes: $PROTO_N_PENDIENTES"
    fi
    return 0
}