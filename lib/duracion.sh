#!/bin/bash
#====================================================================
# lib/duracion.sh — Duración días/horas/minutos
# Pregunta: 📅 Días · 🕐 Horas · ⏱ Minutos (Enter = por defecto)
# Exporta:
#   DUR_DIAS  DUR_HORAS  DUR_MIN
#   DUR_FECHA (YYYY-MM-DD HH:MM:SS)   DUR_FECHA_DIA (YYYY-MM-DD)
#   DUR_TS    (epoch)                 DUR_MOSTRAR (DD/MM/YYYY HH:MM)
# Uso:   mv_ask_duracion [días_default] && echo "$DUR_FECHA"
#        0/x en Días  = cancelar (devuelve 1)
#====================================================================
if ! declare -F trx >/dev/null 2>&1; then trx() { printf '%s' "$1"; }; fi

mv_ask_duracion() {
    local DEF_DIAS="${1:-30}"
    local DEF_HORAS="0" DEF_MIN="0"
    local _d _h _m _v

    # defaults de la casa
    # (pueden venir ya definidos por el llamador)
    ${DUR_DIAS:+:} 2>/dev/null || true

    echo
    echo -e "${YELLOW}⏳ $(trx 'Duración de la cuenta')${RESET}"
    echo -e "${GRAY}($(trx 'Enter = por defecto') · 0/x = $(trx 'Cancelar') en ${RESET}📅${GRAY})${RESET}"

    while true; do
        read -rp "$(echo -e "${GREEN}$(trx '📅 Días') [${DEF_DIAS}]: ${RESET}")" _d
        _d="${_d:-$DEF_DIAS}"
        if [[ "$_d" =~ ^[xX]$ ]] || [[ "$_d" =~ ^(0|salir|volver|atras|cancelar|menu|back|q)$ ]]; then
            echo -e "${YELLOW}← $(trx 'Cancelado')${RESET}"
            return 1
        fi
        if [[ ! "$_d" =~ ^[0-9]+$ ]] || (( _d > 3650 )); then
            echo -e "${RED}✖ $(trx 'Días inválido (0-3650)')${RESET}"
            continue
        fi
        break
    done

    read -rp "$(echo -e "${GREEN}$(trx '🕐 Horas') [${DEF_HORAS}]: ${RESET}")" _h
    _h="${_h:-$DEF_HORAS}"
    [[ "$_h" =~ ^[xXqQ]$ ]] && _h=0
    [[ ! "$_h" =~ ^[0-9]+$ ]] && { echo -e "${RED}✖ $(trx 'Horas inválidas → 0')${RESET}"; _h=0; }

    read -rp "$(echo -e "${GREEN}$(trx '⏱ Minutos') [${DEF_MIN}]: ${RESET}")" _m
    _m="${_m:-$DEF_MIN}"
    [[ "$_m" =~ ^[xXqQ]$ ]] && _m=0
    [[ ! "$_m" =~ ^[0-9]+$ ]] && { echo -e "${RED}✖ $(trx 'Minutos inválidos → 0')${RESET}"; _m=0; }

    # Totales
    DUR_DIAS="$_d"; DUR_HORAS="$_h"; DUR_MIN="$_m"
    DUR_FECHA=$(date -d "+${_d} days +${_h} hours +${_m} minutes" +"%Y-%m-%d %H:%M:%S" 2>/dev/null)
    [[ -z "$DUR_FECHA" ]] && DUR_FECHA=$(date -d "+${_d} days" +"%Y-%m-%d %H:%M:%S")
    DUR_FECHA_DIA=$(date -d "$DUR_FECHA" +"%Y-%m-%d" 2>/dev/null)
    DUR_TS=$(date -d "$DUR_FECHA" +%s 2>/dev/null)
    DUR_MOSTRAR=$(date -d "$DUR_FECHA" +"%d/%m/%Y %H:%M" 2>/dev/null)

    echo -e "${GRAY}   → $(trx 'Expira'):${RESET} ${CYAN}${DUR_MOSTRAR}${RESET}"
    return 0
}

# Guardar expiración exacta (USUARIO|EPOCH) para el verificador por minuto
mv_save_exp_exacta() {
    local U="$1" TS="$2"
    local CONF="${3:-/etc/movivip/sistema/expiraciones_exactas.conf}"
    [[ -z "$U" || -z "$TS" ]] && return 1
    mkdir -p "$(dirname "$CONF")" 2>/dev/null
    touch "$CONF" 2>/dev/null
    grep -v "^${U}|" "$CONF" > "$CONF.tmp" 2>/dev/null
    echo "${U}|${TS}" >> "$CONF.tmp"
    mv "$CONF.tmp" "$CONF" 2>/dev/null
    return 0
}

# Limpiar expiración exacta de un usuario
mv_clear_exp_exacta() {
    local U="$1"
    local CONF="${2:-/etc/movivip/sistema/expiraciones_exactas.conf}"
    [[ -f "$CONF" ]] && sed -i "/^${U}|/d" "$CONF" 2>/dev/null
    return 0
}