#!/usr/bin/env bash

# ============================================================
# Microsoft Office 365 - Desinstalador
#
# Arch Linux
#
# Elimina:
#   - Bottle de Office 365
#   - Wrappers
#   - Launchers .desktop
#   - Iconos
#   - Fuentes de Office
#   - Estado del instalador
#   - Configuración MIME asociada
#
# NO elimina:
#   - Wine / wine32
#   - Winetricks
#   - DXVK global
#   - Vulkan
#   - Multilib
#   - Dependencias del sistema
#   - Paquetes AUR
#
# Instalación por usuario
# ============================================================

set -Eeuo pipefail

# ------------------------------------------------------------
# Configuración
# ------------------------------------------------------------

WINEPREFIX_PATH="$HOME/.Microsoft_Office_365"

LOCAL_BIN="$HOME/.local/bin"
APPLICATIONS_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
OFFICE_FONTS_DIR="$HOME/.local/share/fonts/Office365"

STATE_DIR="$HOME/.local/state/office365-arch-installer"

CLEANUP_WRAPPER="$LOCAL_BIN/office365-cleanup"

# ------------------------------------------------------------
# Colores
# ------------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ------------------------------------------------------------
# Funciones
# ------------------------------------------------------------

log() {
    printf '%b\n' "${BLUE}[INFO]${NC} $*"
}

success() {
    printf '%b\n' "${GREEN}[OK]${NC} $*"
}

warning() {
    printf '%b\n' "${YELLOW}[WARN]${NC} $*"
}

error() {
    printf '%b\n' "${RED}[ERROR]${NC} $*" >&2
}

die() {
    error "$*"
    exit 1
}

confirm() {
    local answer

    printf '\n'
    printf '%b' "${YELLOW}¿Continuar con la desinstalación? [y/N]: ${NC}"
    read -r answer

    case "$answer" in
        y|Y|yes|YES|Yes)
            return 0
            ;;
        *)
            log "Desinstalación cancelada."
            exit 0
            ;;
    esac
}

remove_path() {
    local path="$1"
    local description="$2"

    if [[ -e "$path" || -L "$path" ]]; then
        log "Eliminando $description:"
        printf '       %s\n' "$path"

        rm -rf -- "$path"

        success "$description eliminado."
    else
        log "$description no existe."
    fi
}

# ------------------------------------------------------------
# Validaciones
# ------------------------------------------------------------

[[ "$(uname -m)" == "x86_64" ]] || \
    die "Este desinstalador requiere un sistema x86_64."

if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
else
    die "No se pudo detectar el sistema operativo."
fi

if [[ "${ID:-}" != "arch" ]]; then
    warning "El sistema detectado no parece ser Arch Linux."
    printf '       ID detectado: %s\n' "${ID:-desconocido}"
    printf '\n'
fi

# ------------------------------------------------------------
# Confirmación
# ------------------------------------------------------------

printf '\n'
printf '%b\n' "${CYAN}============================================================${NC}"
printf '%b\n' "${CYAN} Microsoft Office 365 - Desinstalador${NC}"
printf '%b\n' "${CYAN} Arch Linux${NC}"
printf '%b\n' "${CYAN}============================================================${NC}"
printf '\n'

printf '%b\n' "Se eliminarán los componentes de Office 365 instalados"
printf '%b\n' "para el usuario actual:"
printf '\n'

printf '  • Bottle:       %s\n' "$WINEPREFIX_PATH"
printf '  • Wrappers:     %s\n' "$LOCAL_BIN"
printf '  • Launchers:    %s\n' "$APPLICATIONS_DIR"
printf '  • Iconos:       %s\n' "$ICON_DIR"
printf '  • Fuentes:      %s\n' "$OFFICE_FONTS_DIR"
printf '  • Estado:       %s\n' "$STATE_DIR"
printf '\n'

printf '%b\n' "${YELLOW}Los paquetes globales de Wine, wine32, Winetricks,"
printf '%b\n' "DXVK, Vulkan y multilib NO serán eliminados.${NC}"
printf '\n'

confirm

# ------------------------------------------------------------
# 1. Cerrar procesos de Office/Wine
# ------------------------------------------------------------

log "Buscando procesos de Office 365..."

office_processes=(
    "WINWORD.EXE"
    "EXCEL.EXE"
    "POWERPNT.EXE"
    "MSACCESS.EXE"
    "MSPUB.EXE"
    "OUTLOOK.EXE"
    "OfficeClickToRun.exe"
)

found_process=0

for process in "${office_processes[@]}"; do
    if pgrep -f "$process" >/dev/null 2>&1; then
        found_process=1
        warning "Proceso detectado: $process"
    fi
done

if [[ "$found_process" -eq 1 ]]; then
    printf '\n'
    printf '%b\n' "${YELLOW}Hay procesos de Office ejecutándose.${NC}"
    printf 'Se recomienda cerrarlos antes de continuar.\n'
    printf '\n'

    printf '%b' "${YELLOW}¿Intentar cerrarlos automáticamente? [y/N]: ${NC}"
    read -r answer

    case "$answer" in
        y|Y|yes|YES|Yes)
            log "Intentando cerrar procesos de Office..."

            for process in "${office_processes[@]}"; do
                pkill -f "$process" 2>/dev/null || true
            done

            sleep 2

            success "Procesos de Office finalizados."
            ;;
        *)
            warning "Se continuará sin cerrar procesos automáticamente."
            warning "La eliminación del Bottle puede fallar si Wine lo mantiene abierto."
            ;;
    esac
else
    success "No se encontraron procesos conocidos de Office."
fi

# ------------------------------------------------------------
# 2. Terminar wineserver del Bottle
# ------------------------------------------------------------

if [[ -d "$WINEPREFIX_PATH" ]]; then
    log "Intentando detener wineserver del Bottle..."

    if command -v wineboot >/dev/null 2>&1; then
        WINEPREFIX="$WINEPREFIX_PATH" \
        WINEARCH=win32 \
        wineboot -e 2>/dev/null || true
    fi

    if command -v wineserver >/dev/null 2>&1; then
        WINEPREFIX="$WINEPREFIX_PATH" \
        WINEARCH=win32 \
        wineserver -k 2>/dev/null || true
    elif command -v wine32 >/dev/null 2>&1; then
        WINEPREFIX="$WINEPREFIX_PATH" \
        WINEARCH=win32 \
        wine32 wineserver -k 2>/dev/null || true
    fi

    sleep 1
fi

# ------------------------------------------------------------
# 3. Eliminar Bottle
# ------------------------------------------------------------

printf '\n'
log "Eliminando Bottle de Microsoft Office 365..."

remove_path \
    "$WINEPREFIX_PATH" \
    "Bottle de Office 365"

# ------------------------------------------------------------
# 4. Eliminar wrappers
# ------------------------------------------------------------

printf '\n'
log "Eliminando wrappers..."

if [[ -d "$LOCAL_BIN" ]]; then
    shopt -s nullglob

    wrappers=(
        "$LOCAL_BIN"/*365
        "$LOCAL_BIN"/office365-*
    )

    if [[ "${#wrappers[@]}" -gt 0 ]]; then
        for wrapper in "${wrappers[@]}"; do
            [[ -e "$wrapper" ]] || continue

            # Evitar borrar archivos arbitrarios que coincidan
            # accidentalmente. Solo scripts ejecutables relacionados
            # con Office 365.
            if [[ "$(basename "$wrapper")" =~ (office365|365) ]]; then
                rm -f -- "$wrapper"
                success "Eliminado: $wrapper"
            fi
        done
    else
        log "No se encontraron wrappers."
    fi

    shopt -u nullglob
fi

# ------------------------------------------------------------
# 5. Eliminar cleanup wrapper
# ------------------------------------------------------------

remove_path \
    "$CLEANUP_WRAPPER" \
    "Wrapper de limpieza automática"

# ------------------------------------------------------------
# 6. Eliminar archivos .desktop
# ------------------------------------------------------------

printf '\n'
log "Eliminando launchers .desktop..."

if [[ -d "$APPLICATIONS_DIR" ]]; then
    shopt -s nullglob

    desktop_files=(
        "$APPLICATIONS_DIR"/*365.desktop
    )

    if [[ "${#desktop_files[@]}" -gt 0 ]]; then
        for desktop in "${desktop_files[@]}"; do
            rm -f -- "$desktop"
            success "Eliminado: $desktop"
        done
    else
        log "No se encontraron launchers de Office 365."
    fi

    shopt -u nullglob
fi

# ------------------------------------------------------------
# 7. Eliminar iconos
# ------------------------------------------------------------

printf '\n'
log "Eliminando iconos de Office 365..."

if [[ -d "$ICON_DIR" ]]; then
    shopt -s nullglob

    icons=(
        "$ICON_DIR"/*365.svg
    )

    if [[ "${#icons[@]}" -gt 0 ]]; then
        for icon in "${icons[@]}"; do
            rm -f -- "$icon"
            success "Eliminado: $icon"
        done
    else
        log "No se encontraron iconos."
    fi

    shopt -u nullglob
fi

# ------------------------------------------------------------
# 8. Eliminar fuentes de Office
# ------------------------------------------------------------

printf '\n'
remove_path \
    "$OFFICE_FONTS_DIR" \
    "Fuentes de Microsoft Office"

# ------------------------------------------------------------
# 9. Eliminar estado del instalador
# ------------------------------------------------------------

printf '\n'
remove_path \
    "$STATE_DIR" \
    "Estado del instalador"

# ------------------------------------------------------------
# 10. Limpiar caché de fuentes
# ------------------------------------------------------------

printf '\n'
log "Actualizando caché de fuentes..."

if command -v fc-cache >/dev/null 2>&1; then
    fc-cache -f >/dev/null 2>&1 || true
    success "Caché de fuentes actualizada."
else
    warning "fc-cache no está disponible."
fi

# ------------------------------------------------------------
# 11. Actualizar base de datos de aplicaciones
# ------------------------------------------------------------

printf '\n'
log "Actualizando base de datos de aplicaciones..."

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$APPLICATIONS_DIR" >/dev/null 2>&1 || true
    success "Base de datos de aplicaciones actualizada."
else
    warning "update-desktop-database no está disponible."
fi

# ------------------------------------------------------------
# 12. Actualizar caché de iconos
# ------------------------------------------------------------

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    ICON_THEME_DIR="$HOME/.local/share/icons/hicolor"

    if [[ -d "$ICON_THEME_DIR" ]]; then
        gtk-update-icon-cache \
            -f \
            -t \
            "$ICON_THEME_DIR" \
            >/dev/null 2>&1 || true
    fi
fi

# ------------------------------------------------------------
# 13. Limpiar asociaciones MIME
# ------------------------------------------------------------

printf '\n'
log "Limpiando asociaciones MIME de Office..."

MIMEAPPS="$HOME/.config/mimeapps.list"

if [[ -f "$MIMEAPPS" ]]; then

    cp "$MIMEAPPS" "${MIMEAPPS}.office365-backup"

    sed -i \
        -E \
        '/(word|excel|powerpoint|access|publisher).*365\.desktop/d' \
        "$MIMEAPPS"

    success "Asociaciones MIME de Office eliminadas."
    log "Copia de seguridad creada:"
    printf '       %s\n' "${MIMEAPPS}.office365-backup"
else
    log "No existe ~/.config/mimeapps.list."
fi

# ------------------------------------------------------------
# 14. Limpiar directorios vacíos creados por la instalación
# ------------------------------------------------------------

printf '\n'
log "Limpiando directorios vacíos..."

rmdir "$OFFICE_FONTS_DIR" 2>/dev/null || true
rmdir "$ICON_DIR" 2>/dev/null || true

# Solo eliminar directorios padre si están completamente vacíos.
rmdir "$APPLICATIONS_DIR" 2>/dev/null || true
rmdir "$LOCAL_BIN" 2>/dev/null || true

# ------------------------------------------------------------
# 15. Resultado final
# ------------------------------------------------------------

printf '\n'
printf '%b\n' "${GREEN}============================================================${NC}"
printf '%b\n' "${GREEN} Desinstalación completada${NC}"
printf '%b\n' "${GREEN}============================================================${NC}"
printf '\n'

printf 'Se eliminaron los componentes de Office 365 instalados para:\n'
printf '  %s\n' "$HOME"
printf '\n'

printf '%b\n' "No se modificaron los paquetes globales del sistema:"
printf '  • Wine / wine32\n'
printf '  • Winetricks\n'
printf '  • DXVK\n'
printf '  • Vulkan\n'
printf '  • Multilib\n'
printf '  • Samba / Winbind\n'
printf '\n'

printf '%b\n' "${CYAN}Para volver a instalar Office 365, ejecuta nuevamente install.sh.${NC}"
printf '\n'