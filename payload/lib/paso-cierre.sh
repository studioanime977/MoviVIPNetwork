#!/usr/bin/env bash
# ============================================================================
# PASO: CIERRE Y RESUMEN
# Permisos, launchers, ficheros, iptables, aviso de Fail2Ban, monitoreo,
# limpieza del banner retirado y resumen final.
# ============================================================================
set -uo pipefail

# ---------------------------------------------------------------------------
# 1. Permisos del directorio
# ---------------------------------------------------------------------------
cierre_permisos() {
    run_cmd "Estableciendo permisos del directorio" "$LINENO" "chmod -R 777 /etc/movivip"
}

# ---------------------------------------------------------------------------
# 2. Launchers (menu, protocolos, herramientas, usuarios)
# ---------------------------------------------------------------------------
cierre_launchers() {
    run_cmd "Creando comandos de menú (launchers seguros)" "$LINENO" \
        "mkdir -p /usr/local/bin && \
         for L in menu protocolos herramientas usuarios; do \
             cp -f \"/etc/movivip/launchers/\$L\" \"/usr/local/bin/\$L\" 2>/dev/null && chmod +x \"/usr/local/bin/\$L\"; \
         done; \
         if [ ! -x /usr/local/bin/menu ]; then \
             printf '#!/bin/bash\nexec bash /etc/movivip/lib/launch.sh /etc/movivip/menu.sh \"\$@\"\n' > /usr/local/bin/menu; \
             chmod +x /usr/local/bin/menu; \
         fi"
}

# ---------------------------------------------------------------------------
# 3. Ficheros desde payload (fix CRLF, verificación crítica)
# ---------------------------------------------------------------------------
cierre_ficheros() {
    run_cmd "Fix CRLF en scripts" "$LINENO" "find /etc/movivip -name '*.sh' -type f -exec sed -i 's/\r$//' {} + 2>/dev/null"
    # El guard compilado entra en la lista de criticos y se comprueba tambien
    # que sea ejecutable. Antes esta lista exigia lib/licguard.sh, que era
    # justo el fichero que el gate dejo de usar: verificar que estuviera
    # presente solo demostraba que el administrador no lo habia borrado, no
    # que la puerta real siguiera en su sitio. Lo que importa es que exista
    # /usr/local/bin/movivip-guard con permiso de ejecucion, porque ahi esta
    # la puerta que los 107 scripts del panel llaman.
    run_cmd "Verificando archivos críticos" "$LINENO" \
        "for f in /etc/movivip/install.sh /etc/movivip/lib/mvui.sh /etc/movivip/lib/plancheck.sh /usr/local/bin/movivip-guard; do \
             [[ -f \"\$f\" ]] || { echo \"FALTA: \$f\"; exit 1; }; \
         done; \
         [[ -x /usr/local/bin/movivip-guard ]] || { echo \"movivip-guard no es ejecutable\"; exit 1; }"
}

# ---------------------------------------------------------------------------
# 4. Iptables finales
# ---------------------------------------------------------------------------
cierre_iptables() {
    # /etc/iptables no viene en una Ubuntu recien instalada: la redireccion
    # fallaba con "No such file or directory" y el paso se marcaba como FALLO
    # aunque iptables funcionase. paso-sistema.sh:146 ya creaba el directorio;
    # aqui faltaba. Mismo patron que ahi.
    run_cmd "Guardando reglas iptables finales" "$LINENO" \
        "mkdir -p /etc/iptables; iptables-save > /etc/iptables/rules.v4"
}

# ---------------------------------------------------------------------------
# 5. Fail2Ban (opcional: lo decide el administrador)
# ---------------------------------------------------------------------------
cierre_fail2ban() {
    # Antes este bloque instalaba y arrancaba fail2ban sin preguntar:
    #   timeout 120 bash .../fail2ban.sh --install
    #   systemctl enable fail2ban ; systemctl restart fail2ban
    #
    # Dos fallos silenciosos en tres lineas. fail2ban.sh ignoraba los
    # argumentos y abria su menu interactivo, asi que el primer comando se
    # comia los 120s del timeout hasta que lo mataba, arrastrando el resto
    # del cierre. Despues se hacia "enable" y "restart" de un paquete que
    # quiza no estaba instalado: los dos errores se comian su propia salida y
    # el instalador seguia hasta el resumen de exito.
    #
    # Ademas, activar baneos sin permiso del dueno del servidor no
    # corresponde: fail2ban bloquea IPs con iptables y una lista blanca mal
    # escrita deja fuera al propio administrador. Se informa y el panel ofrece
    # la instalacion, que ademas anade la IP actual a la lista blanca.
    mv_fase "Fail2Ban (opcional)"
    mv_detalle "Fail2Ban NO se instala de forma automatica."
    mv_detalle ""
    mv_detalle "  Que hace: servicio que vigila el registro de acceso y, tras varios"
    mv_detalle "  intentos fallidos, bloquea la IP con iptables. Protege SSH,"
    mv_detalle "  Dropbear y los accesos web frente a la fuerza bruta."
    mv_detalle ""
    mv_detalle "  Por que no se fuerza: si la lista blanca de IPs queda mal puesta,"
    mv_detalle "  el servidor puede rechazar tu propio acceso. Instalar un sistema"
    mv_detalle "  de baneos es decision de quien administra el servidor."
    mv_detalle ""
    mv_detalle "  Para instalarlo, managing:"
    mv_detalle "      menu  ->  Herramientas  ->  Fail2Ban"
    mv_detalle "  o directamente:"
    mv_detalle "      bash /etc/movivip/herramientas/fail2ban.sh"
    mv_detalle ""
    mv_detalle "  Tambien puedes desinstalarlo por completo desde ahi si lo quieres"
    mv_detalle "  quitar del sistema."
}

# ---------------------------------------------------------------------------
# 6. Monitoreo de red (snapshot + cron)
# ---------------------------------------------------------------------------
cierre_monitoreo_red() {
    run_cmd "Ejecutando snapshot inicial" "$LINENO" \
        "mkdir -p /etc/movivip/sistema; \
         chmod +x /etc/movivip/herramientas/network_snapshot.sh; \
         rm -f /etc/movivip/sistema/network_state.conf; \
         bash /etc/movivip/herramientas/network_snapshot.sh"
    run_cmd "Configurando cron network_snapshot" "$LINENO" \
        "(crontab -l 2>/dev/null | grep -v 'network_snapshot'; \
         echo '* * * * * bash /etc/movivip/herramientas/network_snapshot.sh >/dev/null 2>&1') | crontab -"
}

# ---------------------------------------------------------------------------
# 7. Monitoreo de usuarios (online.sh + cron)
# ---------------------------------------------------------------------------
cierre_monitoreo_usuarios() {
    run_cmd "Ejecutando online.sh inicial" "$LINENO" \
        "mkdir -p /etc/movivip/sistema; \
         chmod +x /etc/movivip/usuarios/online.sh; \
         bash /etc/movivip/usuarios/online.sh --quiet"
    run_cmd "Creando archivo de límites de conexiones" "$LINENO" \
        "mkdir -p /etc/movivip/sistema; touch /etc/movivip/sistema/limites_conexiones.conf"
    run_cmd "Configurando cron online.sh" "$LINENO" \
        "(crontab -l 2>/dev/null | grep -v 'online.sh --quiet'; \
         echo '*/2 * * * * bash /etc/movivip/usuarios/online.sh --quiet >/dev/null 2>&1') | crontab -"
}

# ---------------------------------------------------------------------------
# 8. Banner SSH — retirado
# ---------------------------------------------------------------------------
# El instalador creaba /etc/issue.net con arte ASCII y lo cableaba en
# sshd_config y en /etc/default/dropbear. Ese bloque se ha eliminado del
# instalador: el banner ya no se escribe.
#
# No basta con dejar de escribirlo. En una reinstalacion o una actualizacion
# sobre un servidor que ya lo tenia, /etc/ssh/sshd_config y
# /etc/default/dropbear se quedan apuntando a un fichero que ya no existe:
# sshd avisa por consola en cada conexion ("Could not open banner") y
# dropbear, para el que -b no es opcional, sigue leyendo el valor viejo.
# Por eso el paso se conserva, pero solo para limpiar esas referencias.
cierre_banner_limpieza() {
    local sshd_cfg="/etc/ssh/sshd_config"
    local dj="/etc/default/dropbear"
    local bak cambia=0

    if grep -qE '^[[:space:]]*Banner[[:space:]]+/etc/issue\.net' "$sshd_cfg" 2>/dev/null; then
        bak="$sshd_cfg.movivip-bak"
        cp -a "$sshd_cfg" "$bak"
        sed -i -E '/^[[:space:]]*Banner[[:space:]]+\/etc\/issue\.net[[:space:]]*$/d' "$sshd_cfg"
        # Si el fichero queda invalido se restaura el original. Un
        # sshd_config roto significa que ssh no arranca, y no vale la pena
        # arriesgar el acceso al servidor por quitar una linea de banner.
        if sshd -t >/dev/null 2>&1; then
            rm -f "$bak"
            cambia=1
            mv_ok "Banner retirado de $sshd_cfg"
        else
            cp -a "$bak" "$sshd_cfg"
            rm -f "$bak"
            mv_error "sshd_config quedaria invalido al quitar el banner"
            mv_detalle "  Se ha restaurado el fichero original."
        fi
    fi

    if grep -qE '^[[:space:]]*DROPBEAR_BANNER=.*/etc/issue\.net' "$dj" 2>/dev/null; then
        sed -i -E '/^[[:space:]]*DROPBEAR_BANNER=.*\/etc\/issue\.net/d' "$dj"
        cambia=1
        mv_ok "Banner retirado de $dj"
    fi

    if [[ -e /etc/issue.net ]]; then
        rm -f /etc/issue.net
        cambia=1
        mv_ok "Fichero /etc/issue.net eliminado"
    fi

    if (( cambia )); then
        mv_detalle "SSH no se reinicia: el ajuste afecta a las conexiones siguientes."
        mv_detalle "Un reinicio fallido de ssh dejaria el servidor inalcanzable."
    fi
    return 0
}

# ---------------------------------------------------------------------------
# 9. Resumen final
# ---------------------------------------------------------------------------
cierre_resumen() {
    # Antes de pintar nada verde, comprobar que de verdad se ha hecho todo.
    #
    # Pasaba esto: paso_protocols no existia (typo de una letra) y se quedaba
    # en "command not found", el instalador no se enteraba, seguia adelante y
    # terminaba con un cartel de "Instalacion completada" y "MoviVIP Network
    # instalado correctamente". Sin un solo protocolo. Un cliente que paga
    # recibe "instalado correctamente" y no tiene nada, y lo peor es que ni
    # el usuario ni el soporte pueden saber si lo que fallo fue la red o fue
    # esto.
    #
    # Si algo no se completo, no se dice "instalado". Se dice que falta.
    local _incompleto=0 _p

    # Este bloque antes hacia "return 1" aqui mismo, y ahi estaba el fallo:
    # en cuanto un paso no se completaba, el cierre se cortaba ANTES del
    # resumen de protocolos. O sea, justo cuando mas falta hace saber que
    # protocols se quedaron fuera, el usuario se enteraba unicamente de
    # "pasos que no se completaron" y se quedaba sin el listado de
    # protocolos, que es lo que pedia y lo que necesita soporte para
    # diagnosticar.
    #
    # Ahora el estado se calcula aqui, pero no se corta nada: se imprime el
    # detalle completo y el fallo se devuelve al final.
    if ! mv_pasos_completos; then
        _incompleto=1
    fi

    # ------------------------------------------------------------------------
    # Resumen de protocolos
    #
    # Esto es lo que faltaba y lo que se venia quejando el usuario. El cierre decia
    # "MoviVIP Network instalado correctamente" y a continuacion cuatro lineas
    # de version, plan, directorio y comando. Ni un solo protocolo. Ni los que
    # funcionaron ni los que fallaron. El usuario no se enteraba de que le
    # faltaban cosas hasta que las buscaba, y el soporte tampoco tenia forma de
    # saber que habia fallado.
    #
    # Ahora se lee el registro que deja paso_protocolos y se lista cada
    # protocolo con su estado real.
    # ------------------------------------------------------------------------
    local _inst=0 _pend=0 _fall=0 _omit=0
    if declare -F proto_reg_cuenta >/dev/null 2>&1 &&
       declare -F proto_reg_listar >/dev/null 2>&1; then
        _inst=$(proto_reg_cuenta instalado)
        _pend=$(proto_reg_cuenta pendiente)
        _fall=$(proto_reg_cuenta fallo)
        _omit=$(proto_reg_cuenta omitido)
    fi

    if (( _incompleto )); then
        mv_fase "Instalación incompleta"
        mv_error "La instalación NO ha terminado bien"
    elif (( _pend > 0 )); then
        mv_fase "Instalado, con pendientes"
        mv_ok "MoviVIP Network instalado"
        mv_warn "$_pend protocolo(s) quedaron pendientes por falta de datos"
    else
        mv_fase "Instalación completada"
        mv_ok "MoviVIP Network instalado correctamente"
    fi
    echo ""

    # Los pasos que faltaron se listan DESPUES del encabezado, no antes, para
    # que el orden sea: que paso esta fallando -> que protocolos se quedaron
    # fuera -> datos de la instalacion.
    if (( _incompleto )); then
        mv_detalle "Pasos que no se completaron:"
        # Un paso puede entrar dos veces en FALTANTES: una por no estar en
        # OK y otra por estar en KO. Se imprime una sola vez.
        local _vistos=() _dup=0 _v
        for _p in ${MV_PASOS_FALTANTES[@]+"${MV_PASOS_FALTANTES[@]}"}; do
            _dup=0
            for _v in ${_vistos[@]+"${_vistos[@]}"}; do
                [[ "$_v" == "$_p" ]] && { _dup=1; break; }
            done
            (( _dup )) && continue
            _vistos+=("$_p")
            mv_detalle "  - $_p"
        done
        mv_detalle ""
        mv_detalle "El panel puede no funcionar. Revisa el log y no des por buena"
        mv_detalle "esta instalacion hasta resolverlo."
        echo ""
    fi

    # OJO: la variable se declara arriba como _fall (dos ele). Usar _fail
    # aqui rompia con "set -u" porque _fail nunca receives valor.
    if (( _inst + _pend + _fall + _omit > 0 )); then
        mv_dato "Protocolos"     "$_inst instalados"
        (( _pend > 0 )) && mv_dato "Pendientes"   "$_pend (necesitan datos)"
        (( _fall > 0 )) && mv_dato "Con fallo"    "$_fall"
        (( _omit > 0 )) && mv_dato "Omitidos"     "$_omit (requieren otro plan)"
        echo ""
        local _p _e _d
        while IFS=$'\t' read -r _p _e _d; do
            [[ -z "${_p:-}" ]] && continue
            case "$_e" in
                instalado) mv_ok     "  ${_p}" ;;
                pendiente) mv_warn   "  ${_p} - pendiente: ${_d:-faltan datos}" ;;
                fallo)     mv_error  "  ${_p} - fallo: ${_d:-sin detalle}" ;;
                omitido)   mv_detalle "  ${_p} - omitido: ${_d:-otro plan}" ;;
            esac
        done < <(proto_reg_listar)
        echo ""
    fi

    mv_dato "Versión"    "8.2.16"
    mv_dato "Plan"       "${LIC_PLAN:-desconocido}"
    # El dominio se muestra aqui para que quede claro que quedo registrado.
    # Si se perdio (config borrada, instalacion reanudada) se avisa en vez
    # de imprimir "desconocido" como si fuera un dato valido.
    if [[ -n "${SERVER_DOMAIN:-}" ]]; then
        mv_dato "Dominio"   "$SERVER_DOMAIN"
    else
        mv_warn "No hay dominio configurado: el panel no sera accesible"
    fi
    mv_dato "Directorio" "/etc/movivip"
    mv_dato "Comando"    "menu (o bash /etc/movivip/menu.sh)"
    echo ""
    mv_detalle "Ejecuta 'menu' para acceder al panel de control."
    mv_detalle "Logs de instalación: /var/log/movivip/instalacion.log"
    echo ""

    # Se devuelve el fallo al FINAL, con el resumen ya impreso. Antes se
    # retornaba aqui arriba y todo lo de abajo se perdia.
    (( _incompleto == 0 ))
}

# ---------------------------------------------------------------------------
# Orquestador del paso cierre
# ---------------------------------------------------------------------------
paso_cierre() {
    mv_fase "Finalizando instalación"

    cierre_permisos
    cierre_launchers
    cierre_ficheros
    cierre_iptables
    cierre_fail2ban
    cierre_monitoreo_red
    cierre_monitoreo_usuarios
    cierre_banner_limpieza
    cierre_resumen
}