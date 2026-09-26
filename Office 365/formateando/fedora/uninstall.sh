#!/usr/bin/env bash

# ============================================================
# Microsoft Office 365 - Desinstalador
#
# Fedora + Wine + Wine32 + DXVK
#
# Elimina únicamente la instalación de Office realizada por
# el instalador de este proyecto.
#
# NO elimina:
#
#   - Wine
#   - Wine32
#   - Winetricks
#   - DXVK del sistema
#   - Vulkan
#   - Dependencias Fedora
#   - Configuración general de Wine
#
# Elimina:
#
#   ~/.Microsoft_Office_365
#   ~/.local/bin/*365.sh
#   ~/.local/bin/limpiar_office-wine365.sh
#   ~/.local/share/applications/*365.desktop
#   ~/.local/share/icons/hicolor/256x256/apps/*365.svg
#   ~/.local/share/fonts/Office365
#   ~/.local/state/office365-fedora-installer
#
# ============================================================

set -Eeuo pipefail


# ============================================================
# Configuración
# ============================================================

readonly WINEPREFIX_PATH="$HOME/.Microsoft_Office_365"

readonly LOCAL_BIN="$HOME/.local/bin"
readonly APPLICATIONS_DIR="$HOME/.local/share/applications"
readonly ICONS_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
readonly OFFICE_FONT_DIR="$HOME/.local/share/fonts/Office365"

readonly STATE_DIR="$HOME/.local/state/office365-fedora-installer"
readonly STATE_FILE="$STATE_DIR/progress"

readonly CLEANUP_WRAPPER="$LOCAL_BIN/limpiar_office-wine365.sh"

readonly INSTALLER_WRAPPERS=(
    "$LOCAL_BIN/word365.sh"
    "$LOCAL_BIN/excel365.sh"
    "$LOCAL_BIN/powerpoint365.sh"
    "$LOCAL_BIN/access365.sh"
    "$LOCAL_BIN/outlook365.sh"
    "$LOCAL_BIN/publisher365.sh"
)


# ============================================================
# Funciones auxiliares
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
    exit 1
}


# ============================================================
# No ejecutar como root
# ============================================================

if [[ "$EUID" -eq 0 ]]; then

    die "No ejecutes este desinstalador con sudo.

Ejecuta:

  ./uninstall.sh

La instalación de Office es por usuario y se encuentra
dentro de tu HOME."

fi


# ============================================================
# Comprobar Fedora
# ============================================================

if [[ ! -r /etc/os-release ]]; then

    die "No se pudo determinar el sistema operativo.

No se encontró:

  /etc/os-release"

fi

# shellcheck disable=SC1091
source /etc/os-release

if [[ "${ID:-}" != "fedora" ]]; then

    warn "El sistema actual no parece ser Fedora."

    echo
    echo "Sistema detectado:"
    echo "  ${PRETTY_NAME:-desconocido}"
    echo

    read -r -p "¿Quieres continuar de todas formas? [y/N] " answer

    case "$answer" in
        y|Y|yes|YES)
            ;;
        *)
            echo
            echo "Desinstalación cancelada."
            exit 0
            ;;
    esac

fi


# ============================================================
# Detectar instalación
# ============================================================

log "Buscando instalación de Microsoft Office 365..."


FOUND_ITEMS=()

if [[ -e "$WINEPREFIX_PATH" ]]; then
    FOUND_ITEMS+=("$WINEPREFIX_PATH")
fi

for wrapper in "${INSTALLER_WRAPPERS[@]}"
do
    if [[ -e "$wrapper" ]]; then
        FOUND_ITEMS+=("$wrapper")
    fi
done

if [[ -e "$CLEANUP_WRAPPER" ]]; then
    FOUND_ITEMS+=("$CLEANUP_WRAPPER")
fi


shopt -s nullglob

DESKTOP_FILES=(
    "$APPLICATIONS_DIR/"*365.desktop
)

ICON_FILES=(
    "$ICONS_DIR/"*365.svg
)

shopt -u nullglob


for desktop in "${DESKTOP_FILES[@]}"
do
    FOUND_ITEMS+=("$desktop")
done

for icon in "${ICON_FILES[@]}"
do
    FOUND_ITEMS+=("$icon")
done

if [[ -d "$OFFICE_FONT_DIR" ]]; then
    FOUND_ITEMS+=("$OFFICE_FONT_DIR")
fi

if [[ -d "$STATE_DIR" ]]; then
    FOUND_ITEMS+=("$STATE_DIR")
fi


# ============================================================
# Si no hay nada instalado
# ============================================================

if (( ${#FOUND_ITEMS[@]} == 0 )); then

    echo
    echo "============================================================"
    echo " Microsoft Office 365 - No instalado"
    echo "============================================================"
    echo
    echo "No se encontró una instalación de Office realizada por"
    echo "este instalador."
    echo

    exit 0

fi


# ============================================================
# Mostrar elementos
# ============================================================

echo
echo "============================================================"
echo " Microsoft Office 365 - Desinstalador"
echo "============================================================"
echo
echo "Se eliminarán los siguientes elementos:"
echo

for item in "${FOUND_ITEMS[@]}"
do
    echo "  - $item"
done

echo
echo "NO se eliminarán las dependencias globales de Fedora:"
echo
echo "  Wine"
echo "  Wine32"
echo "  Winetricks"
echo "  Vulkan"
echo "  DXVK"
echo "  Samba Winbind"
echo
echo "Esto evita afectar otras aplicaciones Wine del sistema."
echo


# ============================================================
# Confirmación
# ============================================================

read -r -p "¿Deseas desinstalar Microsoft Office 365? [y/N] " answer

case "$answer" in

    y|Y|yes|YES)
        ;;

    *)
        echo
        echo "Desinstalación cancelada."
        exit 0
        ;;

esac


# ============================================================
# Segunda confirmación para el Bottle
# ============================================================

if [[ -d "$WINEPREFIX_PATH" ]]; then

    echo
    echo "ATENCIÓN:"
    echo
    echo "Se eliminará permanentemente el Bottle:"
    echo
    echo "  $WINEPREFIX_PATH"
    echo
    echo "Cualquier configuración o archivo almacenado dentro"
    echo "de este Bottle se perderá."
    echo

    read -r -p "Escribe 'DELETE' para confirmar: " confirmation

    if [[ "$confirmation" != "DELETE" ]]; then

        echo
        echo "Confirmación incorrecta."
        echo "Desinstalación cancelada."

        exit 0

    fi

fi


# ============================================================
# Cerrar procesos Office/Wine
# ============================================================

log "Comprobando procesos de Microsoft Office..."

ACTIVE_COUNT="$(
    pgrep -f -i \
        'WINWORD\.EXE|EXCEL\.EXE|POWERPNT\.EXE|OUTLOOK\.EXE|MSACCESS\.EXE|MSPUB\.EXE|OFFICEC2RCLIENT\.EXE|OfficeClickToRun\.exe' \
        2>/dev/null \
        | wc -l
)"

ACTIVE_COUNT="$(
    printf '%s' "$ACTIVE_COUNT" |
        tr -d '[:space:]'
)"

if [[ "$ACTIVE_COUNT" -gt 0 ]]; then

    warn "Se detectaron $ACTIVE_COUNT proceso(s) de Office."

    echo
    echo "Es necesario cerrarlos antes de continuar."
    echo

    read -r -p "¿Deseas forzar el cierre de Office? [y/N] " answer

    case "$answer" in

        y|Y|yes|YES)
            ;;

        *)
            echo
            echo "Desinstalación cancelada."
            echo "Cierra Microsoft Office y vuelve a ejecutar:"
            echo
            echo "  ./uninstall.sh"
            echo
            exit 0
            ;;

    esac


    log "Cerrando procesos de Office..."

    for exe in \
        EXCEL.EXE \
        WINWORD.EXE \
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

    sleep 1

    ok "Procesos de Office cerrados."

else

    ok "No hay aplicaciones de Office abiertas."

fi


# ============================================================
# Cerrar wineserver del Bottle
# ============================================================

if [[ -d "$WINEPREFIX_PATH" ]]; then

    log "Cerrando wineserver del Bottle..."

    if command -v wineserver >/dev/null 2>&1; then

        WINEPREFIX="$WINEPREFIX_PATH" \
            wineserver \
            -k \
            >/dev/null 2>&1 \
            || true

        WINEPREFIX="$WINEPREFIX_PATH" \
            wineserver \
            -w \
            >/dev/null 2>&1 \
            || true

    elif [[ -x /usr/bin/wineserver ]]; then

        WINEPREFIX="$WINEPREFIX_PATH" \
            /usr/bin/wineserver \
            -k \
            >/dev/null 2>&1 \
            || true

        WINEPREFIX="$WINEPREFIX_PATH" \
            /usr/bin/wineserver \
            -w \
            >/dev/null 2>&1 \
            || true

    fi

    ok "wineserver detenido."

fi


# ============================================================
# 1. Eliminar Bottle
# ============================================================

if [[ -e "$WINEPREFIX_PATH" ]]; then

    log "Eliminando Bottle..."

    rm -rf \
        "$WINEPREFIX_PATH"

    if [[ -e "$WINEPREFIX_PATH" ]]; then

        die "No se pudo eliminar:

  $WINEPREFIX_PATH"

    fi

    ok "Bottle eliminado."

else

    ok "Bottle no encontrado."

fi


# ============================================================
# 2. Eliminar wrappers
# ============================================================

log "Eliminando wrappers de Office..."

for wrapper in "${INSTALLER_WRAPPERS[@]}"
do

    if [[ -e "$wrapper" ]]; then

        rm -f "$wrapper"

        ok "Eliminado: $(basename "$wrapper")"

    fi

done


# ============================================================
# 3. Eliminar wrapper de limpieza
# ============================================================

if [[ -e "$CLEANUP_WRAPPER" ]]; then

    rm -f \
        "$CLEANUP_WRAPPER"

    ok "Wrapper de limpieza eliminado."

fi


# ============================================================
# 4. Eliminar accesos .desktop
# ============================================================

log "Eliminando accesos del menú..."

shopt -s nullglob

DESKTOP_FILES=(
    "$APPLICATIONS_DIR/"*365.desktop
)

shopt -u nullglob

for desktop in "${DESKTOP_FILES[@]}"
do

    rm -f "$desktop"

    ok "Eliminado: $(basename "$desktop")"

done


# ============================================================
# 5. Eliminar iconos
# ============================================================

log "Eliminando iconos de Office..."

shopt -s nullglob

ICON_FILES=(
    "$ICONS_DIR/"*365.svg
)

shopt -u nullglob

for icon in "${ICON_FILES[@]}"
do

    rm -f "$icon"

    ok "Eliminado: $(basename "$icon")"

done


# ============================================================
# 6. Actualizar integración del escritorio
# ============================================================

log "Actualizando integración del escritorio..."

if command -v update-desktop-database >/dev/null 2>&1; then

    update-desktop-database \
        "$APPLICATIONS_DIR" \
        >/dev/null 2>&1 \
        || true

fi

if command -v gtk-update-icon-cache >/dev/null 2>&1; then

    gtk-update-icon-cache \
        "$HOME/.local/share/icons/hicolor" \
        >/dev/null 2>&1 \
        || true

fi

ok "Integración del escritorio actualizada."


# ============================================================
# 7. Eliminar fuentes de Office
# ============================================================

if [[ -d "$OFFICE_FONT_DIR" ]]; then

    log "Eliminando fuentes instaladas por Office..."

    rm -rf \
        "$OFFICE_FONT_DIR"

    ok "Fuentes de Office eliminadas."

else

    ok "No se encontró el directorio de fuentes de Office."

fi


# ============================================================
# 8. Actualizar fontconfig
# ============================================================

if command -v fc-cache >/dev/null 2>&1; then

    log "Actualizando caché de fuentes..."

    fc-cache -f

    ok "Caché de fuentes actualizado."

fi


# ============================================================
# 9. Eliminar estado del instalador
# ============================================================

if [[ -d "$STATE_DIR" ]]; then

    log "Eliminando checkpoints del instalador..."

    rm -rf \
        "$STATE_DIR"

    if [[ -e "$STATE_DIR" ]]; then

        die "No se pudo eliminar el estado:

  $STATE_DIR"

    fi

    ok "Estado del instalador eliminado."

fi


# ============================================================
# 10. Limpiar directorios vacíos opcionales
# ============================================================

if [[ -d "$OFFICE_FONT_DIR" ]]; then
    rmdir "$OFFICE_FONT_DIR" 2>/dev/null || true
fi

if [[ -d "$APPLICATIONS_DIR" ]]; then
    rmdir "$APPLICATIONS_DIR" 2>/dev/null || true
fi

if [[ -d "$ICONS_DIR" ]]; then
    rmdir "$ICONS_DIR" 2>/dev/null || true
fi


# ============================================================
# 11. Verificación final
# ============================================================

log "Verificando desinstalación..."

REMAINING=0


if [[ -e "$WINEPREFIX_PATH" ]]; then

    warn "El Bottle todavía existe:"
    echo "  $WINEPREFIX_PATH"

    REMAINING=1

fi


for wrapper in "${INSTALLER_WRAPPERS[@]}"
do

    if [[ -e "$wrapper" ]]; then

        warn "Todavía existe:"
        echo "  $wrapper"

        REMAINING=1

    fi

done


if [[ -e "$CLEANUP_WRAPPER" ]]; then

    warn "Todavía existe:"
    echo "  $CLEANUP_WRAPPER"

    REMAINING=1

fi


shopt -s nullglob

REMAINING_DESKTOPS=(
    "$APPLICATIONS_DIR/"*365.desktop
)

REMAINING_ICONS=(
    "$ICONS_DIR/"*365.svg
)

shopt -u nullglob


if (( ${#REMAINING_DESKTOPS[@]} > 0 )); then

    warn "Todavía existen archivos .desktop de Office."

    REMAINING=1

fi


if (( ${#REMAINING_ICONS[@]} > 0 )); then

    warn "Todavía existen iconos de Office."

    REMAINING=1

fi


if [[ -d "$OFFICE_FONT_DIR" ]]; then

    warn "Todavía existe el directorio de fuentes de Office."

    REMAINING=1

fi


if [[ -d "$STATE_DIR" ]]; then

    warn "Todavía existe el estado del instalador."

    REMAINING=1

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
    echo "Se eliminó la instalación de Office 365 de este usuario."
    echo
    echo "Se conservaron las dependencias globales:"
    echo
    echo "  Wine"
    echo "  Wine32"
    echo "  Winetricks"
    echo "  Vulkan"
    echo "  DXVK"
    echo "  Samba Winbind"
    echo
    echo "Estas dependencias pueden seguir siendo utilizadas por"
    echo "otras aplicaciones."
    echo
    echo "============================================================"
    echo

else

    echo "============================================================"
    echo " Microsoft Office 365 - Desinstalación parcial"
    echo "============================================================"
    echo
    echo "Algunos elementos no pudieron eliminarse."
    echo
    echo "Revisa los avisos anteriores."
    echo
    echo "============================================================"
    echo

    exit 1

fi