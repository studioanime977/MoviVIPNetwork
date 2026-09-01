#!/bin/bash

#=========================================================
#      MOVIVIP NETWORK - CAMBIAR DOMINIO (PARTE 1)
#=========================================================

BASE="/etc/movivip"
CONFIG="$BASE/config.conf"

# ── Cargar idioma + trx + diseño (imprescindible para trx / movivip_sub_header) ──
if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)"
fi
source "$BASE/lib/ui.sh" 2>/dev/null || true
source "$BASE/lib/nav.sh" 2>/dev/null || true

GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
CYAN="\e[1;96m"
WHITE="\e[1;97m"
RESET="\e[0m"

[[ $EUID -ne 0 ]] && {
    echo "$(trx 'Debe ejecutar como root.')"
    exit 1
}

[[ ! -f "$CONFIG" ]] && {
    echo "No existe config.conf"
    exit 1
}

source "$CONFIG"

clear

if declare -F mv_header >/dev/null 2>&1; then
    mv_header "$(trx '🌐 CAMBIAR DOMINIO')" "$(trx 'Gestión de Dominio · Panel MoviVIP')" "v6.2"
    movivip_contacts 2>/dev/null || true
elif declare -F movivip_sub_header >/dev/null 2>&1; then
    movivip_sub_header "$(trx '🌐 CAMBIAR DOMINIO')"
else
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${WHITE}║                 🌐 CAMBIAR DOMINIO                          ║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
fi
echo

CURRENT_DOMAIN="${SERVER_DOMAIN:-NO CONFIGURADO}"

PUBLIC_IP=$(curl -4 -s https://api.ipify.org)

echo -e "${WHITE}Dominio actual : ${GREEN}$CURRENT_DOMAIN${RESET}"
echo -e "${WHITE}IP Pública     : ${GREEN}$PUBLIC_IP${RESET}"
echo

read -rp "$(trx 'Nuevo dominio: ')" NEWDOMAIN

[[ -z "$NEWDOMAIN" ]] && {
    echo
    echo -e "${RED}Debe ingresar un dominio.${RESET}"
    exit 1
}

#---------------------------------------------------------
# Validar formato
#---------------------------------------------------------

if ! [[ "$NEWDOMAIN" =~ ^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$ ]]; then

    echo
    echo -e "${RED}Formato de dominio inválido.${RESET}"
    exit 1

fi

echo
echo -e "${CYAN}Verificando DNS...${RESET}"

DOMAIN_IP=$(dig +short "$NEWDOMAIN" A | head -1)

if [[ -z "$DOMAIN_IP" ]]; then

    echo
    echo -e "${RED}El dominio no tiene un registro A.${RESET}"
    exit 1

fi

if [[ "$DOMAIN_IP" != "$PUBLIC_IP" ]]; then

    echo
    echo -e "${RED}El dominio no apunta a esta VPS.${RESET}"
    echo
    echo "IP VPS      : $PUBLIC_IP"
    echo "IP Dominio  : $DOMAIN_IP"
    exit 1

fi

#---------------------------------------------------------
# Backup
#---------------------------------------------------------

BACKUP="/etc/movivip/backup"

mkdir -p "$BACKUP"

DATE=$(date +%Y%m%d-%H%M%S)

cp "$CONFIG" "$BACKUP/config.conf.$DATE"

[[ -f /etc/xray/domain ]] && \
cp /etc/xray/domain "$BACKUP/domain.$DATE"

echo
echo -e "${GREEN}✔ Verificación completada.${RESET}"
echo -e "${GREEN}✔ Copias de seguridad creadas.${RESET}"

echo
echo -e "${YELLOW}Resumen:${RESET}"

echo "Dominio actual : $CURRENT_DOMAIN"
echo "Nuevo dominio  : $NEWDOMAIN"
echo "IP VPS         : $PUBLIC_IP"

echo
#---------------------------------------------------------
# CLOUDFRONT
#---------------------------------------------------------

CURRENT_CF="${CLOUDFRONT_DOMAIN:-NO CONFIGURADO}"
echo -e "${WHITE}Cloudfront actual : ${GREEN}$CURRENT_CF${RESET}"
echo
echo -e "${YELLOW}Si no usas Cloudfront, dejalo vacio.${RESET}"
read -rp "$(trx 'Cloudfront domain: ')" NEWCF

if [[ -n "$NEWCF" ]]; then
    if grep -q '^CLOUDFRONT_DOMAIN=' "$CONFIG"; then
        sed -i "s|^CLOUDFRONT_DOMAIN=.*|CLOUDFRONT_DOMAIN=\"$NEWCF\"|" "$CONFIG"
    else
        echo "CLOUDFRONT_DOMAIN=\"$NEWCF\"" >> "$CONFIG"
    fi
    echo -e "${GREEN}Cloudfront actualizado.${RESET}"
fi

echo
#---------------------------------------------------------
# NO-IP / DDNS (Dynamic DNS)
#---------------------------------------------------------

CURRENT_NOIP="${NOIP_DOMAIN:-NO CONFIGURADO}"
echo -e "${WHITE}No-IP actual : ${GREEN}$CURRENT_NOIP${RESET}"
echo
echo -e "${YELLOW}Si usas No-IP/DuckDNS/afraid.org, escribelo. Dejalo vacio si no.${RESET}"
echo -e "${YELLOW}(No se exige que apunte a esta IP: No-IP es dinamico)${RESET}"
read -rp "$(trx 'Dominio No-IP / DDNS: ')" NEWNOIP

if [[ -n "$NEWNOIP" ]]; then
    if grep -q '^NOIP_DOMAIN=' "$CONFIG"; then
        sed -i "s|^NOIP_DOMAIN=.*|NOIP_DOMAIN=\"$NEWNOIP\"|" "$CONFIG"
    else
        echo "NOIP_DOMAIN=\"$NEWNOIP\"" >> "$CONFIG"
    fi
    echo -e "${GREEN}✔ No-IP actualizado.${RESET}"
fi

echo
echo -e "${CYAN}Continúe con la Parte 2 para aplicar el cambio.${RESET}"
#=========================================================
# PARTE 2
# Aplicar cambio de dominio
#=========================================================

clear

if declare -F mv_header >/dev/null 2>&1; then
    mv_header "$(trx '✅ APLICANDO CAMBIOS')" "$(trx 'Guardando nueva configuración de dominio')" "v6.2"
    movivip_contacts 2>/dev/null || true
elif declare -F movivip_sub_header >/dev/null 2>&1; then
    movivip_sub_header "$(trx '✅ APLICANDO CAMBIOS')"
else
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${WHITE}║               APLICANDO CAMBIOS                             ║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
fi
echo

echo -e "${CYAN}Actualizando configuración...${RESET}"

#---------------------------------------------------------
# Guardar dominio en config.conf
#---------------------------------------------------------

if grep -q '^SERVER_DOMAIN=' "$CONFIG"; then
    sed -i "s|^SERVER_DOMAIN=.*|SERVER_DOMAIN=\"$NEWDOMAIN\"|" "$CONFIG"
else
    echo "SERVER_DOMAIN=\"$NEWDOMAIN\"" >> "$CONFIG"
fi

#---------------------------------------------------------
# Re-detectar Cloudflare (en vivo) y actualizar config.conf
#---------------------------------------------------------

NEW_CF_STATUS="OFF"
CF_NS=$(dig +short NS "$NEWDOMAIN" 2>/dev/null | grep -ci cloudflare)
[[ "$CF_NS" -gt 0 ]] && NEW_CF_STATUS="ON"

if grep -q '^CLOUDFLARE_STATUS=' "$CONFIG"; then
    sed -i "s|^CLOUDFLARE_STATUS=.*|CLOUDFLARE_STATUS=\"$NEW_CF_STATUS\"|" "$CONFIG"
else
    echo "CLOUDFLARE_STATUS=\"$NEW_CF_STATUS\"" >> "$CONFIG"
fi

[[ "$NEW_CF_STATUS" == "ON" ]] \
    && echo -e "${GREEN}✔ Cloudflare detectado (NS en vivo).${RESET}" \
    || echo -e "${YELLOW}ℹ️ Cloudflare no detectado en el nuevo dominio.${RESET}"

#---------------------------------------------------------
# Crear / actualizar dominio de Xray
#---------------------------------------------------------

mkdir -p /etc/xray
echo "$NEWDOMAIN" > /etc/xray/domain

echo -e "${GREEN}✔ Dominio actualizado.${RESET}"

#---------------------------------------------------------
# Reiniciar Xray
#---------------------------------------------------------

echo -ne "$(trx 'Reiniciando Xray... ')"

if systemctl restart xray 2>/dev/null; then
    echo -e "${GREEN}OK${RESET}"
else
    echo -e "${RED}ERROR${RESET}"
fi

#---------------------------------------------------------
# Validar HAProxy
#---------------------------------------------------------

echo -ne "$(trx 'Validando HAProxy... ')"

if haproxy -c -f /etc/haproxy/haproxy.cfg >/dev/null 2>&1; then
    echo -e "${GREEN}OK${RESET}"

    echo -ne "$(trx 'Reiniciando HAProxy... ')"

    if systemctl restart haproxy; then
        echo -e "${GREEN}OK${RESET}"
    else
        echo -e "${RED}ERROR${RESET}"
    fi

else
    echo -e "${RED}Configuración inválida${RESET}"
    exit 1
fi

#---------------------------------------------------------
# Verificar servicios
#---------------------------------------------------------

echo
echo "$(trx 'Estado de servicios:')"

systemctl is-active --quiet xray \
    && echo -e "Xray     : ${GREEN}ACTIVO${RESET}" \
    || echo -e "Xray     : ${RED}DETENIDO${RESET}"

systemctl is-active --quiet haproxy \
    && echo -e "HAProxy  : ${GREEN}ACTIVO${RESET}" \
    || echo -e "HAProxy  : ${RED}DETENIDO${RESET}"

echo

echo -e "${GREEN}═══════════════════════════════════════════════${RESET}"
echo -e "${GREEN}✔ Dominio cambiado correctamente.${RESET}"
echo -e "${GREEN}═══════════════════════════════════════════════${RESET}"

echo
echo "Dominio anterior : $CURRENT_DOMAIN"
echo "Nuevo dominio    : $NEWDOMAIN"

echo
read -n1 -s -r -p "$(trx 'Presione cualquier tecla para volver...')"

exec menu
