#!/usr/bin/env bash

# ============================================================
# Microsoft Office 365 - Uninstaller
#
# Debian / Ubuntu + Wine + Wine32 + DXVK
#
# Elimina:
#
#   ~/.Microsoft_Office_365
#   ~/.local/bin/*365.sh
#   ~/.local/bin/limpiar_office-wine365.sh
#   ~/.local/share/applications/*365.desktop
#   ~/.local/share/icons/hicolor/256x256/apps/*365.svg
#   ~/.local/share/fonts/Office365
#   ~/.local/state/office365-installer
#
# También elimina del directorio actual:
#
#   MSO365-EN.tar.zst
#   MSO365-English-.tar.zst
#   MSO365-English-
#
# NO elimina:
#
#   Wine
#   Wine32
#   Wine64
#   Winetricks
#   Vulkan
#   Samba / Winbind
#   paquetes APT
#   configuraciones generales de Wine
#
# Uso:
#
#   ./uninstall.sh
#
# Sin confirmación:
#
#   ./uninstall.sh --yes
#
# Mantener el archivo descargado:
#
#   ./uninstall.sh --keep-archive
#
# ============================================================

set -Eeuo pipefail


# ============================================================
# Configuración
# ============================================================

readonly SOURCE_DIR="$(pwd)"

readonly WINEPREFIX_PATH="$HOME/.Microsoft_Office_365"

readonly LOCAL_ARCHIVE_ENGLISH="$SOURCE_DIR/MSO365-English-.tar.zst"
readonly LOCAL_ARCHIVE_SHORT="$SOURCE_DIR/MSO365-EN.tar.zst"

readonly BOTTLE_DIR="$SOURCE_DIR/MSO365-English-"

readonly LOCAL_BIN="$HOME/.local/bin"

readonly APPLICATIONS_DIR="$HOME/.local/share/applications"

readonly ICONS_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"

readonly OFFICE_FONT_DIR="$HOME/.local/share/fonts/Office365"

readonly STATE_DIR="$HOME/.local/state/office365-installer"

readonly STATE_FILE="$STATE_DIR/progress"

readonly HCOLOR_ICON_DIR="$HOME/.local/share/icons/hicolor"

readonly MIME_FILES=(
    "$HOME/.config/mimeapps.list"
    "$HOME/.local/share/applications/mimeapps.list"
)

KEEP_ARCHIVE=0
ASSUME_YES=0


# ============================================================
# Colores / mensajes
# ============================================================

log() {
    echo
    echo "[INFO] $*"
}

ok() {
    echo "[ OK ] $*"
}

warn() {
    echo "[WARN] $*" >&2
}

die() {
    echo
    echo "[ERROR] $*" >&2
    echo
    exit 1
}


# ============================================================
# Ayuda
# ============================================================

show_help() {
    cat <<EOF

Microsoft Office 365 - Uninstaller

Uso:

  ./uninstall.sh

Opciones:

  --yes
      No solicitar confirmación.

  --keep-archive
      No eliminar los archivos .tar.zst descargados.

  --help
      Mostrar esta ayuda.

Ejemplos:

  ./uninstall.sh
  ./uninstall.sh --yes
  ./uninstall.sh --yes --keep-archive

EOF
}


# ============================================================
# Argumentos
# ============================================================

for arg in "$@"; do
    case "$arg" in

        --yes)
            ASSUME_YES=1
            ;;

        --keep-archive)
            KEEP_ARCHIVE=1
            ;;

        --help|-h)
            show_help
            exit 0
            ;;

        *)
            die "Argumento desconocido:

  $arg

Usa:

  ./uninstall.sh --help"
            ;;

    esac
done


# ============================================================
# No ejecutar como root
# ============================================================

if [[ "$EUID" -eq 0 ]]; then
    die "No ejecutes este desinstalador como root.

Ejecuta:

  ./uninstall.sh"
fi


# ============================================================
# Confirmación
# ============================================================

echo
echo "============================================================"
echo " Microsoft Office 365 - Desinstalador"
echo "============================================================"
echo

echo "Este proceso eliminará:"
echo

echo "  Wine prefix:"
echo "    $WINEPREFIX_PATH"
echo

echo "  Launchers:"
echo "    $LOCAL_BIN/*365.sh"
echo "    $LOCAL_BIN/limpiar_office-wine365.sh"
echo

echo "  Archivos .desktop:"
echo "    $APPLICATIONS_DIR/*365.desktop"
echo

echo "  Iconos:"
echo "    $ICONS_DIR/*365.svg"
echo

echo "  Fuentes:"
echo "    $OFFICE_FONT_DIR"
echo

echo "  Estado:"
echo "    $STATE_DIR"
echo

if [[ "$KEEP_ARCHIVE" -eq 0 ]]; then
    echo "  Archivos descargados:"
    echo "    $LOCAL_ARCHIVE_SHORT"
    echo "    $LOCAL_ARCHIVE_ENGLISH"
    echo

    echo "  Extracción:"
    echo "    $BOTTLE_DIR"
else
    echo "  Los archivos .tar.zst serán CONSERVADOS."
fi

echo

if [[ "$ASSUME_YES" -eq 0 ]]; then

    read -r -p "¿Continuar con la desinstalación? [y/N] " answer

    case "$answer" in
        y|Y|yes|YES|s|S|si|SI)
            ;;
        *)
            echo
            echo "Desinstalación cancelada."
            exit 0
            ;;
    esac

fi


# ============================================================
# Cerrar Wine / Office
# ============================================================

log "Cerrando procesos de Wine / Microsoft Office..."

WINESERVER_BIN="$(command -v wineserver || true)"

if [[ -n "$WINESERVER_BIN" ]]; then

    if [[ -d "$WINEPREFIX_PATH" ]]; then

        WINEPREFIX="$WINEPREFIX_PATH" \
            "$WINESERVER_BIN" -k \
            >/dev/null 2>&1 \
            || true

        sleep 1

        WINEPREFIX="$WINEPREFIX_PATH" \
            "$WINESERVER_BIN" -w \
            >/dev/null 2>&1 \
            || true

    fi

fi

# Procesos específicos de Office.
for exe in \
    WINWORD.EXE \
    EXCEL.EXE \
    POWERPNT.EXE \
    OUTLOOK.EXE \
    MSACCESS.EXE \
    MSPUB.EXE \
    OFFICEC2RCLIENT.EXE \
    OSPPSVC.EXE \
    OfficeClickToRun.exe
do
    pkill -9 -f "$exe" 2>/dev/null || true
done

ok "Procesos de Office cerrados."


# ============================================================
# Eliminar Wine prefix
# ============================================================

if [[ -e "$WINEPREFIX_PATH" ]]; then

    log "Eliminando Wine prefix..."

    rm -rf "$WINEPREFIX_PATH"

    if [[ -e "$WINEPREFIX_PATH" ]]; then
        die "No se pudo eliminar:

  $WINEPREFIX_PATH"
    fi

    ok "Wine prefix eliminado."

else

    ok "Wine prefix no encontrado."

fi


# ============================================================
# Eliminar launchers
# ============================================================

log "Eliminando launchers..."

OFFICE_LAUNCHERS=(
    "$LOCAL_BIN/word365.sh"
    "$LOCAL_BIN/excel365.sh"
    "$LOCAL_BIN/powerpoint365.sh"
    "$LOCAL_BIN/access365.sh"
    "$LOCAL_BIN/outlook365.sh"
    "$LOCAL_BIN/publisher365.sh"
    "$LOCAL_BIN/limpiar_office-wine365.sh"
)

for launcher in "${OFFICE_LAUNCHERS[@]}"; do

    if [[ -e "$launcher" ]]; then
        rm -f "$launcher"
        ok "Eliminado: $launcher"
    fi

done


# ============================================================
# Eliminar archivos .desktop
# ============================================================

log "Eliminando accesos del menú..."

shopt -s nullglob

DESKTOP_FILES=(
    "$APPLICATIONS_DIR/word365.desktop"
    "$APPLICATIONS_DIR/excel365.desktop"
    "$APPLICATIONS_DIR/powerpoint365.desktop"
    "$APPLICATIONS_DIR/access365.desktop"
    "$APPLICATIONS_DIR/outlook365.desktop"
    "$APPLICATIONS_DIR/publisher365.desktop"
)

for desktop in "${DESKTOP_FILES[@]}"; do

    if [[ -e "$desktop" ]]; then
        rm -f "$desktop"
        ok "Eliminado: $desktop"
    fi

done


# ============================================================
# Eliminar iconos
# ============================================================

log "Eliminando iconos..."

ICON_FILES=(
    "$ICONS_DIR/word365.svg"
    "$ICONS_DIR/excel365.svg"
    "$ICONS_DIR/powerpoint365.svg"
    "$ICONS_DIR/access365.svg"
    "$ICONS_DIR/outlook365.svg"
    "$ICONS_DIR/publisher365.svg"
)

for icon in "${ICON_FILES[@]}"; do

    if [[ -e "$icon" ]]; then
        rm -f "$icon"
        ok "Eliminado: $icon"
    fi

done


# ============================================================
# Eliminar fuentes Office
# ============================================================

if [[ -d "$OFFICE_FONT_DIR" ]]; then

    log "Eliminando fuentes Office..."

    rm -rf "$OFFICE_FONT_DIR"

    ok "Fuentes Office eliminadas."

else

    ok "No se encontró el directorio de fuentes Office."

fi


# ============================================================
# Actualizar fontconfig
# ============================================================

if command -v fc-cache >/dev/null 2>&1; then

    log "Actualizando caché de fuentes..."

    fc-cache -f \
        >/dev/null 2>&1 \
        || true

    ok "Caché de fuentes actualizado."

fi


# ============================================================
# Limpiar asociaciones MIME creadas por Office
#
# Solo elimina líneas cuyo valor utiliza nuestros .desktop.
# No elimina mimeapps.list completo.
# ============================================================

log "Limpiando asociaciones MIME de Office..."

for mime_file in "${MIME_FILES[@]}"; do

    if [[ ! -f "$mime_file" ]]; then
        continue
    fi

    TMP_FILE="${mime_file}.office365.tmp"

    awk '
        /^(application\/msword|application\/vnd\.openxmlformats-officedocument\.wordprocessingml\.document|application\/vnd\.ms-excel|application\/vnd\.openxmlformats-officedocument\.spreadsheetml\.sheet|text\/csv|application\/vnd\.ms-powerpoint|application\/vnd\.openxmlformats-officedocument\.presentationml\.presentation|application\/vnd\.ms-access|application\/vnd\.ms-publisher)=/ {
            if (
                $0 ~ /word365\.desktop/ ||
                $0 ~ /excel365\.desktop/ ||
                $0 ~ /powerpoint365\.desktop/ ||
                $0 ~ /access365\.desktop/ ||
                $0 ~ /outlook365\.desktop/ ||
                $0 ~ /publisher365\.desktop/
            ) {
                next
            }
        }

        {
            print
        }
    ' "$mime_file" > "$TMP_FILE"

    mv "$TMP_FILE" "$mime_file"

    ok "Asociaciones revisadas: $mime_file"

done


# ============================================================
# Actualizar base de datos del escritorio
# ============================================================

if command -v update-desktop-database >/dev/null 2>&1; then

    log "Actualizando base de datos del escritorio..."

    update-desktop-database \
        "$APPLICATIONS_DIR" \
        >/dev/null 2>&1 \
        || true

    ok "Base de datos del escritorio actualizada."

fi


# ============================================================
# Actualizar caché de iconos
# ============================================================

if command -v gtk-update-icon-cache >/dev/null 2>&1; then

    log "Actualizando caché de iconos..."

    gtk-update-icon-cache \
        "$HCOLOR_ICON_DIR" \
        >/dev/null 2>&1 \
        || true

    ok "Caché de iconos actualizado."

fi


# ============================================================
# Eliminar estado del instalador
# ============================================================

if [[ -d "$STATE_DIR" ]]; then

    log "Eliminando estado del instalador..."

    rm -rf "$STATE_DIR"

    ok "Estado del instalador eliminado."

else

    ok "No existe estado del instalador."

fi


# ============================================================
# Eliminar extracción del Bottle
# ============================================================

if [[ -d "$BOTTLE_DIR" ]]; then

    log "Eliminando Bottle extraído..."

    rm -rf "$BOTTLE_DIR"

    if [[ -e "$BOTTLE_DIR" ]]; then
        die "No se pudo eliminar:

  $BOTTLE_DIR"
    fi

    ok "Bottle extraído eliminado."

else

    ok "No existe extracción del Bottle."

fi


# ============================================================
# Eliminar archivos descargados
# ============================================================

if [[ "$KEEP_ARCHIVE" -eq 0 ]]; then

    log "Eliminando archivos descargados..."

    ARCHIVES_REMOVED=0

    if [[ -f "$LOCAL_ARCHIVE_SHORT" ]]; then

        rm -f "$LOCAL_ARCHIVE_SHORT"

        ok "Eliminado:"
        echo "    $LOCAL_ARCHIVE_SHORT"

        ARCHIVES_REMOVED=1

    fi

    if [[ -f "$LOCAL_ARCHIVE_ENGLISH" ]]; then

        rm -f "$LOCAL_ARCHIVE_ENGLISH"

        ok "Eliminado:"
        echo "    $LOCAL_ARCHIVE_ENGLISH"

        ARCHIVES_REMOVED=1

    fi

    if [[ "$ARCHIVES_REMOVED" -eq 0 ]]; then
        ok "No se encontraron archivos descargados."
    fi

else

    ok "Archivos .tar.zst conservados."

fi


# ============================================================
# Limpiar directorios vacíos creados por el instalador
# ============================================================

log "Limpiando directorios vacíos..."

rmdir "$ICONS_DIR" 2>/dev/null || true
rmdir "$APPLICATIONS_DIR" 2>/dev/null || true
rmdir "$OFFICE_FONT_DIR" 2>/dev/null || true


# ============================================================
# Verificación final
# ============================================================

echo
echo "============================================================"
echo " Verificación"
echo "============================================================"
echo

REMAINING=0

check_removed() {

    local path="$1"

    if [[ -e "$path" ]]; then

        warn "Todavía existe:"
        echo "    $path"

        REMAINING=1

    fi

}

check_removed "$WINEPREFIX_PATH"

check_removed "$LOCAL_BIN/word365.sh"
check_removed "$LOCAL_BIN/excel365.sh"
check_removed "$LOCAL_BIN/powerpoint365.sh"
check_removed "$LOCAL_BIN/access365.sh"
check_removed "$LOCAL_BIN/outlook365.sh"
check_removed "$LOCAL_BIN/publisher365.sh"
check_removed "$LOCAL_BIN/limpiar_office-wine365.sh"

check_removed "$APPLICATIONS_DIR/word365.desktop"
check_removed "$APPLICATIONS_DIR/excel365.desktop"
check_removed "$APPLICATIONS_DIR/powerpoint365.desktop"
check_removed "$APPLICATIONS_DIR/access365.desktop"
check_removed "$APPLICATIONS_DIR/outlook365.desktop"
check_removed "$APPLICATIONS_DIR/publisher365.desktop"

check_removed "$ICONS_DIR/word365.svg"
check_removed "$ICONS_DIR/excel365.svg"
check_removed "$ICONS_DIR/powerpoint365.svg"
check_removed "$ICONS_DIR/access365.svg"
check_removed "$ICONS_DIR/outlook365.svg"
check_removed "$ICONS_DIR/publisher365.svg"

check_removed "$OFFICE_FONT_DIR"
check_removed "$STATE_DIR"
check_removed "$BOTTLE_DIR"

if [[ "$KEEP_ARCHIVE" -eq 0 ]]; then
    check_removed "$LOCAL_ARCHIVE_SHORT"
    check_removed "$LOCAL_ARCHIVE_ENGLISH"
fi


# ============================================================
# Resultado
# ============================================================

echo

if [[ "$REMAINING" -eq 0 ]]; then

    echo "============================================================"
    echo " Microsoft Office 365 - Desinstalación completada"
    echo "============================================================"
    echo

    echo "Se eliminó:"
    echo
    echo "  ✓ Wine prefix"
    echo "  ✓ Wrappers de Office"
    echo "  ✓ Accesos .desktop"
    echo "  ✓ Iconos"
    echo "  ✓ Fuentes Office"
    echo "  ✓ Estado del instalador"
    echo "  ✓ Bottle extraído"

    if [[ "$KEEP_ARCHIVE" -eq 0 ]]; then
        echo "  ✓ Archivos descargados"
    else
        echo "  - Archivos descargados conservados"
    fi

    echo
    echo "Los paquetes del sistema NO fueron modificados."
    echo
    echo "Wine, Wine32, Winetricks, Vulkan y demás dependencias"
    echo "continúan instalados en el sistema."
    echo

else

    echo "============================================================"
    echo " Desinstalación completada con advertencias"
    echo "============================================================"
    echo

    echo "Algunos archivos no pudieron eliminarse."
    echo "Revisa los elementos marcados anteriormente."
    echo

    exit 1

fi