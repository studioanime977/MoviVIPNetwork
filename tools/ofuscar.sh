#!/bin/bash
#=========================================================
# MoviVIP Network — tools/ofuscar.sh v1.0
# Ofuscador de código estilo ADMRufu
#
#   bash ofuscar.sh            → ofusca /etc/movivip (con backup)
#   bash ofuscar.sh /ruta/dir  → ofusca otro directorio
#   bash ofuscar.sh --unpack   → restaura TODO desde el backup
#
# Qué hace:
#   • Comprime cada script (gzip) + codifica (base64)
#   • Lo envuelve en un stub mínimo ejecutable
#   • El código original queda ILEGIBLE en el VPS
#   • Backup completo en .pack-backup para revertir
#
# NO se tocan: config.conf, *.conf, languages/, lib/,
#               sistema/, backups/, licencias, .env-bot,
#               assets de bots y docs.
#=========================================================

set -u

MARKER="MOVIVIP-PACKED"
DIR="${1:-/etc/movivip}"
BACKUP="$DIR/.pack-backup"

if [[ "${1:-}" == "--unpack" ]]; then
    DIR="/etc/movivip"
    BACKUP="$DIR/.pack-backup"
    if [[ ! -d "$BACKUP" ]]; then
        echo "❌ No hay backup en $BACKUP"; exit 1
    fi
    echo -e "\e[1;92m↩ Restaurando scripts desde $BACKUP ...\e[0m"
    (cd "$BACKUP" && find . -type f -print0) | while IFS= read -r -d '' REL; do
        DEST="$DIR/${REL#./}"
        mkdir -p "$(dirname "$DEST")"
        cp "$BACKUP/$REL" "$DEST"
        chmod +x "$DEST" 2>/dev/null
    done
    echo -e "\e[1;92m✅ Restaurado. Los scripts vuelven a ser legibles.\e[0m"
    exit 0
fi

[[ -d "$DIR" ]] || { echo "❌ Directorio no existe: $DIR"; exit 1; }

# ── Exclusiones (glob patterns relativos a $DIR) ──
is_excluded() {
    local P="$1"          # ruta absoluta
    local REL="${P#$DIR/}"
    case "$REL" in
        config.conf|*.conf|version.txt|.env-bot|.master-key|licencia.conf) return 0 ;;
        languages/*|lib/*|sistema/*|backups/*|gate/*|logs/*|hwids/*)       return 0 ;;
        bots_extract/*|dev/*|tools/*|.pack-backup/*)                       return 0 ;;
        *.md|*.txt|*.py|*.ps1|*.svg|*.service|*.json|*.hwid|*.pub|*.key)   return 0 ;;
        install.sh|validar-licencia.sh|cambiar-licencia.sh|check-licencia.sh) return 0 ;;
        bot-generador.sh|setup-bot-generador.sh|descifrar-secrets.sh)      return 0 ;;
        protocolos/onlineapp)                                              return 0 ;;
    esac
    return 1
}

echo -e "\e[1;96m🛡 MoviVIP Pack — ofuscando $DIR\e[0m"
COUNT=0; SKIP=0

while IFS= read -r -d '' F; do
    # Saltar stubs ya empaquetados
    if head -n 2 "$F" 2>/dev/null | grep -q "$MARKER"; then
        SKIP=$((SKIP+1)); continue
    fi
    # Solo archivos ejecutables del panel (bash)
    HEAD=$(head -n 1 "$F" 2>/dev/null)
    [[ "$HEAD" == *"#!/bin/bash"* || "$HEAD" == *"#!/usr/bin/env bash"* ]] || { SKIP=$((SKIP+1)); continue; }
    is_excluded "$F" && { SKIP=$((SKIP+1)); continue; }

    REL="${F#$DIR/}"
    mkdir -p "$BACKUP/$(dirname "$REL")"
    cp "$F" "$BACKUP/$REL" 2>/dev/null

    B64=$(gzip -9 < "$F" | base64 -w0 2>/dev/null)
    [[ -z "$B64" ]] && { echo "⚠ gzip falló en $REL"; continue; }

    # Sin "exit $?": el stub debe ser seguro también cuando el archivo
    # se SOURCE-a (ej. functions/pkg.sh) — un exit mataría al padre.
    printf '#!/bin/bash\n# %s v1 — MoviVIP Network · codigo protegido\neval "$(echo %s | base64 -d | gunzip)"\n' \
        "$MARKER" "$B64" > "$F"
    chmod +x "$F"
    COUNT=$((COUNT+1))
done < <(find "$DIR" -type f -print0)

echo -e "\e[1;92m✅ $COUNT scripts ofuscados\e[0m \e[1;90m($SKIP omitidos)\e[0m"
echo -e "\e[1;90mBackup en: $BACKUP  → restaurar con: bash $0 --unpack\e[0m"
