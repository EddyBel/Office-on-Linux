#!/usr/bin/env bash

# ============================================================
# Microsoft Office 365 - Bottle preconstruido
#
# Arch Linux + Wine32 + DXVK
#
# Instalación por usuario
#
# Compatibilidad:
#
#   Arch Linux
#
#   El Bottle es un prefijo Wine32:
#
#       #arch=win32
#
#   Arch Linux utiliza actualmente Wine WoW64 como configuración
#   oficial. Este Bottle requiere un Wine32 real, por lo que
#   se utiliza el paquete wine32 de AUR cuando es necesario.
#
# Requisitos:
#
#   - Arch Linux
#   - multilib habilitado
#   - wine32
#   - winetricks
#   - Vulkan x86_64
#   - Vulkan i686 / lib32
#   - controlador Vulkan funcional
#   - Zenity
#   - Fontconfig
#   - Samba / Winbind
#
# Bottle:
#
#   ~/.Microsoft_Office_365
#
# Todas las aplicaciones de Office se ejecutan mediante:
#
#   wine32
#
# ============================================================

set -Eeuo pipefail


# ============================================================
# 0. Configuración
# ============================================================

readonly SOURCE_DIR="$(pwd)"

readonly LOCAL_ARCHIVE_ENGLISH="$SOURCE_DIR/MSO365-English-.tar.zst"
readonly LOCAL_ARCHIVE_SHORT="$SOURCE_DIR/MSO365-EN.tar.zst"

readonly DOWNLOAD_URL="https://github.com/EddyBel/Office-on-Linux/releases/download/office365-fedora-44/MSO365-EN.tar.zst"
readonly DOWNLOAD_ARCHIVE="$SOURCE_DIR/MSO365-EN.tar.zst"

ARCHIVE=""

readonly BOTTLE_DIR="$SOURCE_DIR/MSO365-English-"
readonly SOURCE_BOTTLE="$BOTTLE_DIR/.Microsoft_Office_365"

readonly WINEPREFIX_PATH="$HOME/.Microsoft_Office_365"

# En Arch el comando requerido es wine32.
readonly WINE32_BIN="wine32"

readonly INSTALL_USER="$(id -un)"
readonly INSTALL_GROUP="$(id -gn)"

readonly WINE_USER="crossover"

readonly LOCAL_BIN="$HOME/.local/bin"
readonly APPLICATIONS_DIR="$HOME/.local/share/applications"

# Mantener la misma estructura del instalador Fedora.
readonly ICONS_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"

readonly OFFICE_FONT_DIR="$HOME/.local/share/fonts/Office365"

readonly WORD_EXE="$WINEPREFIX_PATH/drive_c/Program Files/Microsoft Office/root/Office16/WINWORD.EXE"

# Estado de instalación.
readonly STATE_DIR="$HOME/.local/state/office365-arch-installer"
readonly STATE_FILE="$STATE_DIR/progress"


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
# Manejo de checkpoints
# ============================================================

init_state() {
    mkdir -p "$STATE_DIR"
    touch "$STATE_FILE"
}

step_done() {
    local step="$1"

    [[ -f "$STATE_FILE" ]] \
        && grep -qxF "$step" "$STATE_FILE"
}

mark_step_done() {
    local step="$1"

    init_state

    if ! step_done "$step"; then
        printf '%s\n' "$step" >> "$STATE_FILE"
    fi
}

start_step() {
    local step="$1"
    local description="$2"

    if step_done "$step"; then
        ok "Etapa $step ya completada: $description"
        return 1
    fi

    echo
    echo "============================================================"
    echo " Etapa $step"
    echo " $description"
    echo "============================================================"
    echo

    return 0
}

complete_step() {
    local step="$1"
    local description="$2"

    mark_step_done "$step"

    ok "$description"
}


# ============================================================
# 1. No ejecutar como root
# ============================================================

if [[ "$EUID" -eq 0 ]]; then
    die "No ejecutes este instalador con sudo.

Ejecuta:

  ./install.sh

El instalador solicitará sudo cuando sea necesario."
fi


# ============================================================
# 2. Comprobar sistema operativo
# ============================================================

if start_step "02-system" "Comprobar sistema operativo"; then

    log "Comprobando sistema operativo..."

    if [[ ! -r /etc/os-release ]]; then
        die "No se pudo determinar el sistema operativo.

No se encontró:

  /etc/os-release"
    fi

    # shellcheck disable=SC1091
    source /etc/os-release

    if [[ "${ID:-}" != "arch" ]]; then
        die "Este instalador está diseñado para Arch Linux.

Sistema detectado:

  ${PRETTY_NAME:-desconocido}

Este instalador no está diseñado para Fedora, Debian,
Ubuntu, Linux Mint u otras distribuciones."
    fi

    ARCH_VERSION="${BUILD_ID:-rolling}"
    ARCH_NAME="${PRETTY_NAME:-Arch Linux}"

    ok "Arch Linux detectado:"
    echo "    $ARCH_NAME"

    complete_step "02-system" "Sistema operativo verificado."

else

    source /etc/os-release

    ARCH_VERSION="${BUILD_ID:-rolling}"
    ARCH_NAME="${PRETTY_NAME:-Arch Linux}"

fi


# ============================================================
# 3. Comprobar Pacman
# ============================================================

if start_step "03-pacman" "Comprobar gestor de paquetes"; then

    log "Comprobando pacman..."

    command -v pacman >/dev/null 2>&1 \
        || die "No se encontró pacman.

Este instalador requiere el gestor de paquetes de Arch Linux."

    ok "Pacman disponible."

    complete_step "03-pacman" "Pacman disponible."

fi


# ============================================================
# 4. Comprobar multilib
# ============================================================

if start_step "04-multilib" "Comprobar repositorio multilib"; then

    log "Comprobando repositorio multilib..."

    if ! awk '
        /^\[multilib\]/ {
            found = 1
            next
        }

        found && /^Include[[:space:]]*=/ {
            active = 1
            exit
        }

        found && /^\[/ {
            exit
        }
    ' /etc/pacman.conf
    then

        die "El repositorio multilib no parece estar habilitado.

Este Bottle requiere Wine32 y bibliotecas de 32 bits.

Habilita en:

  /etc/pacman.conf

la sección:

  [multilib]
  Include = /etc/pacman.d/mirrorlist

Después ejecuta:

  sudo pacman -Syu

y vuelve a ejecutar este instalador."
    fi

    ok "Repositorio multilib habilitado."

    complete_step "04-multilib" "Repositorio multilib verificado."

fi


# ============================================================
# 5. Sincronizar repositorios
# ============================================================

if start_step "05-pacman-sync" "Sincronizar repositorios"; then

    log "Sincronizando repositorios de Arch Linux..."

    sudo pacman -Sy --needed

    ok "Repositorios sincronizados."

    complete_step "05-pacman-sync" "Repositorios sincronizados."

fi


# ============================================================
# 6. Comprobar archivo TAR / descargar
# ============================================================

if start_step "06-archive" "Localizar o descargar Bottle"; then

    log "Buscando archivo de Office..."

    if [[ -f "$LOCAL_ARCHIVE_ENGLISH" ]]; then

        ARCHIVE="$LOCAL_ARCHIVE_ENGLISH"

        ok "Archivo local encontrado:"
        echo "    $ARCHIVE"

    elif [[ -f "$LOCAL_ARCHIVE_SHORT" ]]; then

        ARCHIVE="$LOCAL_ARCHIVE_SHORT"

        ok "Archivo local encontrado:"
        echo "    $ARCHIVE"

    else

        log "No se encontró un archivo de Office local."

        echo
        echo "Se intentará descargar:"
        echo
        echo "  $DOWNLOAD_URL"
        echo

        DOWNLOAD_TOOL=""

        if command -v curl >/dev/null 2>&1; then

            DOWNLOAD_TOOL="curl"

        elif command -v wget >/dev/null 2>&1; then

            DOWNLOAD_TOOL="wget"

        else

            log "No se encontró curl ni wget."
            log "Instalando curl mediante Pacman..."

            sudo pacman -S --needed --noconfirm curl

            if command -v curl >/dev/null 2>&1; then
                DOWNLOAD_TOOL="curl"
            fi

        fi

        [[ -n "$DOWNLOAD_TOOL" ]] \
            || die "No fue posible encontrar ni instalar una herramienta
de descarga.

Se necesita:

  curl
  o
  wget"

        rm -f "$DOWNLOAD_ARCHIVE"

        case "$DOWNLOAD_TOOL" in

            curl)

                log "Descargando con curl..."

                if ! curl \
                    --fail \
                    --location \
                    --show-error \
                    --progress-bar \
                    --retry 3 \
                    --retry-delay 2 \
                    --connect-timeout 15 \
                    --output "$DOWNLOAD_ARCHIVE" \
                    "$DOWNLOAD_URL"
                then

                    rm -f "$DOWNLOAD_ARCHIVE"

                    die "No fue posible descargar el Bottle.

URL:

  $DOWNLOAD_URL"

                fi

                ;;

            wget)

                log "Descargando con wget..."

                if ! wget \
                    --progress=bar:force \
                    --tries=3 \
                    --timeout=15 \
                    -O "$DOWNLOAD_ARCHIVE" \
                    "$DOWNLOAD_URL"
                then

                    rm -f "$DOWNLOAD_ARCHIVE"

                    die "No fue posible descargar el Bottle.

URL:

  $DOWNLOAD_URL"

                fi

                ;;

            *)

                die "Herramienta de descarga desconocida:

  $DOWNLOAD_TOOL"

                ;;

        esac

        if [[ ! -f "$DOWNLOAD_ARCHIVE" ]]; then
            die "La descarga terminó pero no se encontró:

  $DOWNLOAD_ARCHIVE"
        fi

        if [[ ! -s "$DOWNLOAD_ARCHIVE" ]]; then
            rm -f "$DOWNLOAD_ARCHIVE"

            die "La descarga produjo un archivo vacío."
        fi

        ARCHIVE="$DOWNLOAD_ARCHIVE"

        ok "Bottle descargado correctamente:"
        echo "    $ARCHIVE"

    fi

    printf '%s\n' "$ARCHIVE" > "$STATE_DIR/archive"

    complete_step "06-archive" "Bottle localizado correctamente."

else

    if [[ -f "$STATE_DIR/archive" ]]; then
        ARCHIVE="$(cat "$STATE_DIR/archive")"
    fi

    if [[ -z "$ARCHIVE" || ! -f "$ARCHIVE" ]]; then

        die "La etapa de archivo aparece completada pero el archivo
del Bottle ya no existe.

Elimina el estado de instalación y vuelve a ejecutar:

  rm -rf \"$STATE_DIR\""

    fi

fi


# ============================================================
# 7. No sobrescribir instalación existente
# ============================================================

if start_step "07-existing-install" "Comprobar instalaciones existentes"; then

    if [[ -e "$WINEPREFIX_PATH" ]]; then

        if step_done "43-complete"; then

            ok "Microsoft Office 365 ya está instalado."

            echo
            echo "Bottle:"
            echo "  $WINEPREFIX_PATH"
            echo
            echo "Wrappers:"
            echo "  $LOCAL_BIN"
            echo
            echo "Aplicaciones:"
            echo "  $APPLICATIONS_DIR"
            echo

            exit 0

        fi

        die "Ya existe el Bottle:

  $WINEPREFIX_PATH

Pero no existe un checkpoint de instalación completada.

Por seguridad este instalador no sobrescribirá la instalación.

Si se trata de una instalación anterior que quieres eliminar:

  rm -rf \"$WINEPREFIX_PATH\"

Después elimina el estado:

  rm -rf \"$STATE_DIR\""

    fi

    complete_step \
        "07-existing-install" \
        "No existe una instalación previa que sobrescribir."

fi


# ============================================================
# 8. No sobrescribir extracción existente
# ============================================================

if start_step "08-existing-extraction" "Comprobar extracción previa"; then

    if [[ -e "$BOTTLE_DIR" ]]; then

        die "Ya existe el directorio:

  $BOTTLE_DIR

Elimina o mueve ese directorio antes de continuar."

    fi

    complete_step \
        "08-existing-extraction" \
        "No existe una extracción previa."

fi


# ============================================================
# 9. Comprobar tar y zstd
# ============================================================

if start_step "09-extraction-tools" "Comprobar herramientas de extracción"; then

    log "Comprobando herramientas de extracción..."

    command -v tar >/dev/null 2>&1 \
        || die "No se encontró tar."

    command -v zstd >/dev/null 2>&1 \
        || die "No se encontró zstd."

    ok "Herramientas de extracción disponibles."

    complete_step \
        "09-extraction-tools" \
        "Herramientas de extracción verificadas."

fi


# ============================================================
# 10. Extraer Bottle
# ============================================================

if start_step "10-extract" "Extraer Bottle"; then

    log "Extrayendo Bottle..."

    tar \
        -I zstd \
        -xf "$ARCHIVE" \
        -C "$SOURCE_DIR"

    [[ -d "$SOURCE_BOTTLE" ]] \
        || die "La extracción terminó pero no se encontró:

  $SOURCE_BOTTLE

El archivo TAR no contiene la estructura de Bottle esperada."

    ok "Bottle extraído correctamente."

    complete_step \
        "10-extract" \
        "Bottle extraído correctamente."

fi


# ============================================================
# 11. Instalar dependencias Arch
# ============================================================

if start_step "11-dependencies" "Instalar dependencias Arch"; then

    log "Instalando dependencias..."

    sudo pacman -S --needed --noconfirm \
        wine \
        winetricks \
        wine-mono \
        wine-gecko \
        vulkan-icd-loader \
        lib32-vulkan-icd-loader \
        vulkan-tools \
        mesa \
        lib32-mesa \
        samba \
        libwbclient \
        zenity \
        fontconfig \
        desktop-file-utils \
        gtk3 \
        zstd \
        curl

    ok "Dependencias Arch instaladas."

    complete_step \
        "11-dependencies" \
        "Dependencias Arch instaladas."

fi


# ============================================================
# 12. Comprobar Wine32
#
# IMPORTANTE:
#
# El paquete oficial wine de Arch utiliza actualmente el nuevo
# WoW64. Este Bottle requiere un ejecutable Wine32 real.
#
# Si existe yay o paru, se intenta instalar wine32 desde AUR.
# ============================================================

if start_step "12-wine32" "Comprobar Wine32"; then

    log "Comprobando Wine32..."

    if ! command -v "$WINE32_BIN" >/dev/null 2>&1; then

        warn "No se encontró wine32."

        AUR_HELPER=""

        if command -v yay >/dev/null 2>&1; then
            AUR_HELPER="yay"
        elif command -v paru >/dev/null 2>&1; then
            AUR_HELPER="paru"
        fi

        if [[ -n "$AUR_HELPER" ]]; then

            log "Se encontró el helper AUR: $AUR_HELPER"
            log "Instalando wine32 desde AUR..."

            "$AUR_HELPER" -S --needed wine32

        else

            die "No se encontró el ejecutable wine32.

El paquete oficial wine de Arch utiliza actualmente WoW64,
pero este Bottle necesita un Wine32 real.

Instala el paquete AUR:

  wine32

Puedes hacerlo mediante un helper como:

  yay -S wine32

o:

  paru -S wine32

Después vuelve a ejecutar este instalador."

        fi

    fi

    command -v "$WINE32_BIN" >/dev/null 2>&1 \
        || die "wine32 sigue sin estar disponible."

    WINE32_VERSION="$(
        "$WINE32_BIN" --version 2>/dev/null || true
    )"

    [[ -n "$WINE32_VERSION" ]] \
        || die "wine32 no pudo devolver su versión."

    echo "    $WINE32_VERSION"

    ok "Wine32 disponible."

    printf '%s\n' "$WINE32_VERSION" \
        > "$STATE_DIR/wine32-version"

    complete_step \
        "12-wine32" \
        "Wine32 disponible."

else

    if [[ -f "$STATE_DIR/wine32-version" ]]; then

        WINE32_VERSION="$(cat "$STATE_DIR/wine32-version")"

    else

        WINE32_VERSION="$(
            "$WINE32_BIN" --version 2>/dev/null || true
        )"

    fi

fi


# ============================================================
# 13. Comprobar Winetricks
# ============================================================

if start_step "13-winetricks" "Comprobar Winetricks"; then

    log "Comprobando Winetricks..."

    command -v winetricks >/dev/null 2>&1 \
        || die "No se encontró Winetricks."

    WINETRICKS_VERSION="$(
        winetricks --version 2>/dev/null || true
    )"

    if [[ -n "$WINETRICKS_VERSION" ]]; then
        echo "    Winetricks $WINETRICKS_VERSION"
    fi

    ok "Winetricks disponible."

    complete_step \
        "13-winetricks" \
        "Winetricks disponible."

fi


# ============================================================
# 14. Comprobar Vulkan
# ============================================================

if start_step "14-vulkan" "Comprobar Vulkan"; then

    log "Comprobando Vulkan..."

    command -v vulkaninfo >/dev/null 2>&1 \
        || die "No se encontró vulkaninfo.

Instala vulkan-tools."

    VULKAN_SUMMARY="$(
        vulkaninfo --summary 2>/dev/null || true
    )"

    if [[ -z "$VULKAN_SUMMARY" ]]; then

        die "Vulkan no respondió correctamente.

DXVK requiere un controlador Vulkan funcional.

Comprueba que tu GPU y su controlador Vulkan estén
correctamente configurados."

    fi

    echo "$VULKAN_SUMMARY" \
        | grep -E 'deviceName|driverName|driverInfo' \
        | head -20 \
        || true

    ok "Vulkan responde correctamente."

    complete_step \
        "14-vulkan" \
        "Vulkan verificado."

fi


# ============================================================
# 15. Comprobar herramientas de integración
# ============================================================

if start_step "15-integration-tools" "Comprobar herramientas de integración"; then

    log "Comprobando herramientas del sistema..."

    REQUIRED_COMMANDS=(
        fc-cache
        xdg-mime
        zenity
        update-desktop-database
    )

    for command_name in "${REQUIRED_COMMANDS[@]}"
    do

        if ! command -v "$command_name" >/dev/null 2>&1; then

            die "No se encontró el comando requerido:

  $command_name

Comprueba las dependencias de Arch Linux."

        fi

    done

    ok "Herramientas de integración disponibles."

    complete_step \
        "15-integration-tools" \
        "Herramientas de integración verificadas."

fi


# ============================================================
# 16. Instalar Bottle
# ============================================================

if start_step "16-install-bottle" "Instalar Bottle"; then

    log "Copiando Bottle a:

  $WINEPREFIX_PATH"

    cp -a \
        "$SOURCE_BOTTLE" \
        "$WINEPREFIX_PATH"

    ok "Bottle copiado."

    complete_step \
        "16-install-bottle" \
        "Bottle instalado."

fi


# ============================================================
# 17. Corregir propietario y permisos
# ============================================================

if start_step "17-permissions" "Corregir propietario y permisos"; then

    log "Corrigiendo propietario y permisos..."

    chown -R \
        "$INSTALL_USER:$INSTALL_GROUP" \
        "$WINEPREFIX_PATH"

    chmod -R \
        u+rwX \
        "$WINEPREFIX_PATH"

    ok "Propietario y permisos corregidos."

    complete_step \
        "17-permissions" \
        "Propietario y permisos configurados."

fi


# ============================================================
# 18. Comprobar arquitectura
# ============================================================

if start_step "18-architecture" "Comprobar arquitectura del Bottle"; then

    log "Comprobando arquitectura del Bottle..."

    if ! grep -q '^#arch=win32$' \
        "$WINEPREFIX_PATH/system.reg"
    then

        die "El Bottle no es un prefijo Wine32 reconocido.

Se esperaba:

  #arch=win32"

    fi

    ok "Bottle confirmado como Wine32 puro."

    complete_step \
        "18-architecture" \
        "Arquitectura Wine32 confirmada."

fi


# ============================================================
# 19. Configuración explícita Wine32
# ============================================================

if start_step "19-wine-environment" "Configurar entorno Wine32"; then

    export WINEPREFIX="$WINEPREFIX_PATH"
    export WINEARCH="win32"

    ok "WINEPREFIX y WINEARCH configurados."

    complete_step \
        "19-wine-environment" \
        "Entorno Wine32 configurado."

else

    export WINEPREFIX="$WINEPREFIX_PATH"
    export WINEARCH="win32"

fi


# ============================================================
# 20. Reconstruir dosdevices
# ============================================================

if start_step "20-dosdevices" "Reconstruir unidades Wine"; then

    log "Reconstruyendo unidades Wine..."

    rm -rf \
        "$WINEPREFIX_PATH/dosdevices"

    mkdir -p \
        "$WINEPREFIX_PATH/dosdevices"

    ln -s \
        ../drive_c \
        "$WINEPREFIX_PATH/dosdevices/c:"

    ln -s \
        / \
        "$WINEPREFIX_PATH/dosdevices/z:"

    ln -s \
        /media \
        "$WINEPREFIX_PATH/dosdevices/d:"

    ln -s \
        "$HOME" \
        "$WINEPREFIX_PATH/dosdevices/e:"

    ok "Unidades Wine reconstruidas."

    complete_step \
        "20-dosdevices" \
        "Unidades Wine configuradas."

fi


# ============================================================
# 21. Crear estructura del usuario Wine
# ============================================================

if start_step "21-wine-user" "Crear estructura del usuario Wine"; then

    log "Creando directorios del usuario Wine..."

    mkdir -p \
        "$WINEPREFIX_PATH/drive_c/users/$WINE_USER/AppData/Local"

    mkdir -p \
        "$WINEPREFIX_PATH/drive_c/users/$WINE_USER/AppData/Roaming"

    ok "Estructura del usuario creada."

    complete_step \
        "21-wine-user" \
        "Estructura del usuario Wine creada."

fi


# ============================================================
# 22. Crear directorios XDG
# ============================================================

if start_step "22-xdg" "Crear directorios XDG"; then

    log "Creando directorios de integración..."

    mkdir -p \
        "$LOCAL_BIN"

    mkdir -p \
        "$APPLICATIONS_DIR"

    mkdir -p \
        "$ICONS_DIR"

    mkdir -p \
        "$OFFICE_FONT_DIR"

    ok "Directorios XDG preparados."

    complete_step \
        "22-xdg" \
        "Directorios XDG preparados."

fi


# ============================================================
# 23. Instalar fuentes de Office
# ============================================================

if start_step "23-office-fonts" "Instalar fuentes de Office"; then

    log "Instalando fuentes incluidas en el Bottle..."

    SOURCE_FONT_DIR="$BOTTLE_DIR/Fuentes Office365"

    if [[ -d "$SOURCE_FONT_DIR" ]]; then

        find "$SOURCE_FONT_DIR" \
            -maxdepth 1 \
            -type f \
            \( \
                -iname '*.ttf' \
                -o -iname '*.ttc' \
                -o -iname '*.otf' \
            \) \
            -exec cp -f {} "$OFFICE_FONT_DIR/" \;

        ok "Fuentes de Office copiadas."

    else

        warn "No se encontró:

  $SOURCE_FONT_DIR

Se continuará sin fuentes adicionales del TAR."

    fi

    fc-cache -f

    ok "Caché de fuentes actualizado."

    complete_step \
        "23-office-fonts" \
        "Fuentes de Office configuradas."

fi


# ============================================================
# 24. Reparar fuentes bitmap Wine
#
# En Arch las fuentes Wine pueden estar en distintas rutas
# dependiendo del paquete instalado.
# ============================================================

if start_step "24-wine-fonts" "Reparar fuentes bitmap Wine"; then

    log "Comprobando fuentes bitmap Wine..."

    WINE_FONT_DIRS=(
        "/usr/share/wine/fonts"
        "/usr/share/wine/wine/fonts"
    )

    for font in \
        coure.fon \
        sserife.fon \
        serife.fon \
        smalle.fon
    do

        TARGET="$WINEPREFIX_PATH/drive_c/windows/Fonts/$font"

        if [[ -f "$TARGET" ]]; then
            ok "$font ya existe."
            continue
        fi

        FOUND_SOURCE=""

        for font_dir in "${WINE_FONT_DIRS[@]}"
        do

            if [[ -f "$font_dir/$font" ]]; then
                FOUND_SOURCE="$font_dir/$font"
                break
            fi

        done

        if [[ -n "$FOUND_SOURCE" ]]; then

            cp -f \
                "$FOUND_SOURCE" \
                "$TARGET"

            ok "$font copiada desde $FOUND_SOURCE"

        else

            warn "No se encontró $font en las rutas conocidas."

        fi

    done

    complete_step \
        "24-wine-fonts" \
        "Fuentes bitmap Wine verificadas."

fi


# ============================================================
# 25. Instalar launchers originales
# ============================================================

if start_step "25-original-launchers" "Instalar launchers originales"; then

    log "Instalando launchers originales..."

    shopt -s nullglob

    LAUNCHERS=(
        "$BOTTLE_DIR/Wrappers/"*365.sh
    )

    if (( ${#LAUNCHERS[@]} == 0 )); then
        die "No se encontraron launchers *365.sh."
    fi

    cp \
        "${LAUNCHERS[@]}" \
        "$LOCAL_BIN/"

    chmod 755 \
        "$LOCAL_BIN/"*365.sh

    ok "Launchers originales copiados."

    complete_step \
        "25-original-launchers" \
        "Launchers originales instalados."

fi


# ============================================================
# 26. Crear wrappers portables
# ============================================================

if start_step "26-portable-wrappers" "Crear wrappers portables"; then

    log "Configurando wrappers portables para Arch Linux..."


    # --------------------------------------------------------
    # Wrapper de limpieza
    # --------------------------------------------------------

    cat > "$LOCAL_BIN/limpiar_office-wine365.sh" <<'EOF'
#!/bin/bash

# ============================================================
# Microsoft Office 365 - Limpieza Wine
# ============================================================

WINEPREFIX="$HOME/.Microsoft_Office_365"
WINESERVER="$(command -v wineserver || echo /usr/bin/wineserver)"

# ------------------------------------------------------------
# Modo automático / silencioso
# ------------------------------------------------------------

if [[ "${1:-}" == "--silent" ]] || [[ "${1:-}" == "--auto" ]]; then

    ACTIVE_COUNT="$(
        pgrep -f -i \
            'WINWORD\.EXE|EXCEL\.EXE|POWERPNT\.EXE|OUTLOOK\.EXE|MSACCESS\.EXE|MSPUB\.EXE' \
            2>/dev/null \
            | wc -l
    )

    ACTIVE_COUNT="$(printf '%s' "$ACTIVE_COUNT" | tr -d '[:space:]')"

    if [[ "$ACTIVE_COUNT" -gt 0 ]]; then
        exit 0
    fi

else

    if ! zenity --question \
        --title="Clean Wine / Office" \
        --text="Do you want to close all Wine and Microsoft Office processes?\n\nAny unsaved work will be lost." \
        --width=420
    then
        exit 0
    fi

fi


# ------------------------------------------------------------
# Limpieza
# ------------------------------------------------------------

for exe in \
    EXCEL.EXE \
    WINWORD.EXE \
    POWERPNT.EXE \
    OUTLOOK.EXE \
    MSACCESS.EXE \
    MSPUB.EXE \
    OFFICEC2RCLIENT.EXE \
    OSPPSVC.EXE \
    plugplay.exe \
    rpcss.exe \
    services.exe \
    svchost.exe \
    explorer.exe \
    OfficeClickToRun.exe
do

    pkill -9 -f "$exe" 2>/dev/null || true

done


# ------------------------------------------------------------
# Cerrar Wine correctamente
# ------------------------------------------------------------

if [[ -d "$WINEPREFIX" ]]; then

    WINEPREFIX="$WINEPREFIX" \
        "$WINESERVER" \
        -k \
        2>/dev/null \
        || true

    WINEPREFIX="$WINEPREFIX" \
        "$WINESERVER" \
        -w \
        2>/dev/null \
        || true

fi

exit 0
EOF

    chmod 755 \
        "$LOCAL_BIN/limpiar_office-wine365.sh"


    # --------------------------------------------------------
    # Crear wrappers Office
    # --------------------------------------------------------

    create_office_wrapper() {

        local launcher="$1"
        local executable="$2"
        local output="$LOCAL_BIN/$launcher"

        cat > "$output" <<EOF
#!/bin/bash

set -e

export WINEPREFIX="\$HOME/.Microsoft_Office_365"
export WINEARCH="win32"
export LANG=C.UTF-8
export WINEDEBUG=-all

app="C:\\\\Program Files\\\\Microsoft Office\\\\root\\\\Office16\\\\$executable"

wineserver -p >/dev/null 2>&1 || true

if [[ \$# -eq 0 ]]; then

    wine32 "\$app"

else

    for file in "\$@"; do

        fullpath=\$(realpath "\$file")
        winpath="Z:\${fullpath//\\//\\\\}"

        wine32 "\$app" "\$winpath"

    done

fi


# ------------------------------------------------------------
# Limpieza automática
# ------------------------------------------------------------

if [[ -x "\$HOME/.local/bin/limpiar_office-wine365.sh" ]]; then

    "\$HOME/.local/bin/limpiar_office-wine365.sh" \
        --silent &

fi
EOF

        chmod 755 "$output"
    }


    create_office_wrapper \
        "word365.sh" \
        "WINWORD.EXE"

    create_office_wrapper \
        "excel365.sh" \
        "EXCEL.EXE"

    create_office_wrapper \
        "powerpoint365.sh" \
        "POWERPNT.EXE"

    create_office_wrapper \
        "access365.sh" \
        "MSACCESS.EXE"

    create_office_wrapper \
        "outlook365.sh" \
        "OUTLOOK.EXE"

    create_office_wrapper \
        "publisher365.sh" \
        "MSPUB.EXE"


    WRAPPERS=(
        "$LOCAL_BIN/word365.sh"
        "$LOCAL_BIN/excel365.sh"
        "$LOCAL_BIN/powerpoint365.sh"
        "$LOCAL_BIN/access365.sh"
        "$LOCAL_BIN/outlook365.sh"
        "$LOCAL_BIN/publisher365.sh"
        "$LOCAL_BIN/limpiar_office-wine365.sh"
    )

    for wrapper in "${WRAPPERS[@]}"
    do

        if [[ ! -x "$wrapper" ]]; then

            die "No se pudo crear el wrapper:

  $wrapper"

        fi

    done

    ok "Wrappers completados."

    complete_step \
        "26-portable-wrappers" \
        "Wrappers portables configurados."

fi


# ============================================================
# 27. Validar launchers
# ============================================================

if start_step "27-launcher-validation" "Validar launchers"; then

    log "Validando launchers..."

    for launcher in \
        "$LOCAL_BIN/word365.sh" \
        "$LOCAL_BIN/excel365.sh" \
        "$LOCAL_BIN/powerpoint365.sh" \
        "$LOCAL_BIN/access365.sh" \
        "$LOCAL_BIN/outlook365.sh" \
        "$LOCAL_BIN/publisher365.sh"
    do

        if ! grep -q 'wine32' "$launcher"; then

            die "El launcher no contiene una llamada a wine32:

  $launcher"

        fi

        if grep -En \
            '(^|[[:space:]])wine([[:space:]]|$)' \
            "$launcher" \
            >/dev/null
        then

            die "El launcher contiene una llamada al comando genérico wine:

  $launcher"

        fi

        if ! grep -q \
            'limpiar_office-wine365.sh' \
            "$launcher"
        then

            die "El launcher no contiene la limpieza automática:

  $launcher"

        fi

    done

    ok "Todos los wrappers utilizan wine32 y limpieza automática."

    complete_step \
        "27-launcher-validation" \
        "Launchers validados."

fi


# ============================================================
# 28. Instalar archivos .desktop
# ============================================================

if start_step "28-desktops" "Instalar accesos del menú"; then

    log "Instalando accesos del menú..."

    DESKTOPS=(
        "$BOTTLE_DIR/Desktops/"*365.desktop
    )

    if (( ${#DESKTOPS[@]} == 0 )); then
        die "No se encontraron archivos .desktop."
    fi

    cp \
        "${DESKTOPS[@]}" \
        "$APPLICATIONS_DIR/"

    chmod 644 \
        "$APPLICATIONS_DIR/"*365.desktop

    ok "Archivos .desktop copiados."

    complete_step \
        "28-desktops" \
        "Archivos .desktop instalados."

fi


# ============================================================
# 29. Corregir rutas Exec
# ============================================================

if start_step "29-desktop-paths" "Adaptar rutas Exec"; then

    log "Adaptando archivos .desktop al entorno por usuario..."

    for desktop in "$APPLICATIONS_DIR/"*365.desktop
    do

        sed -Ei \
            "s#^Exec=/opt/launchers/#Exec=${LOCAL_BIN}/#g" \
            "$desktop"

    done

    complete_step \
        "29-desktop-paths" \
        "Rutas Exec adaptadas."

fi


# ============================================================
# 30. Validar archivos .desktop
# ============================================================

if start_step "30-desktop-validation" "Validar accesos del menú"; then

    log "Validando accesos del menú..."

    for desktop in "$APPLICATIONS_DIR/"*365.desktop
    do

        if grep -q '^Exec=/opt/launchers/' "$desktop"; then

            die "El archivo .desktop todavía apunta a /opt/launchers:

  $desktop"

        fi

        EXEC_PATH="$(
            sed -n 's/^Exec=\([^ %]*\).*/\1/p' "$desktop" \
                | head -1
        )"

        if [[ -z "$EXEC_PATH" ]]; then

            die "No se encontró Exec= en:

  $desktop"

        fi

        if [[ ! -x "$EXEC_PATH" ]]; then

            die "El launcher indicado por el .desktop no existe
o no es ejecutable:

  $EXEC_PATH

Archivo:

  $desktop"

        fi

    done

    ok "Archivos .desktop correctamente vinculados."

    complete_step \
        "30-desktop-validation" \
        "Archivos .desktop validados."

fi


# ============================================================
# 31. Instalar iconos
# ============================================================

if start_step "31-icons" "Instalar iconos"; then

    log "Instalando iconos..."

    ICONS=(
        "$BOTTLE_DIR/Office365Icons/"*365.svg
    )

    if (( ${#ICONS[@]} > 0 )); then

        cp \
            "${ICONS[@]}" \
            "$ICONS_DIR/"

        chmod 644 \
            "$ICONS_DIR/"*365.svg

        ok "Iconos instalados."

    else

        warn "No se encontraron iconos Office365."

    fi

    complete_step \
        "31-icons" \
        "Iconos procesados."

fi


# ============================================================
# 32. Actualizar integración del escritorio
# ============================================================

if start_step "32-desktop-integration" "Actualizar integración del escritorio"; then

    log "Actualizando bases de datos del escritorio..."

    update-desktop-database \
        "$APPLICATIONS_DIR" \
        >/dev/null 2>&1 \
        || true

    if command -v gtk-update-icon-cache >/dev/null 2>&1; then

        gtk-update-icon-cache \
            "$HOME/.local/share/icons/hicolor" \
            >/dev/null 2>&1 \
            || true

    fi

    ok "Integración del escritorio actualizada."

    complete_step \
        "32-desktop-integration" \
        "Integración del escritorio actualizada."

fi


# ============================================================
# 33. Instalar DXVK x32
# ============================================================

if start_step "33-dxvk" "Instalar DXVK x32"; then

    log "Instalando DXVK para el Bottle Wine32..."

    WINE="$WINE32_BIN" \
        WINEPREFIX="$WINEPREFIX_PATH" \
        WINEARCH="win32" \
        winetricks \
        --unattended \
        dxvk

    ok "DXVK instalado."

    complete_step \
        "33-dxvk" \
        "DXVK x32 instalado."

fi


# ============================================================
# 34. Verificar DLL de DXVK
# ============================================================

if start_step "34-dxvk-dlls" "Verificar DLL de DXVK"; then

    log "Verificando DLL de DXVK..."

    DXVK_DLLS=(
        d3d8.dll
        d3d9.dll
        d3d10core.dll
        d3d11.dll
        dxgi.dll
    )

    for dll in "${DXVK_DLLS[@]}"
    do

        DLL_PATH="$WINEPREFIX_PATH/drive_c/windows/system32/$dll"

        if [[ ! -f "$DLL_PATH" ]]; then

            die "No se encontró:

  $DLL_PATH

La instalación de DXVK no quedó completa."

        fi

    done

    ok "DLL de DXVK x32 presentes."

    complete_step \
        "34-dxvk-dlls" \
        "DLL de DXVK verificadas."

fi


# ============================================================
# 35. Verificar overrides
# ============================================================

if start_step "35-dxvk-overrides" "Verificar overrides de DXVK"; then

    log "Verificando overrides de DXVK..."

    for dll in \
        d3d8 \
        d3d9 \
        d3d10core \
        d3d11 \
        dxgi
    do

        OVERRIDE_VALUE="$(
            awk -v dll="$dll" '
                tolower($1) == tolower("\"*" dll "\"=\"native\"") {
                    print "native"
                    exit
                }
                tolower($1) == tolower("\"*" dll "\"") &&
                tolower($2) == "native" {
                    print "native"
                    exit
                }
            ' "$WINEPREFIX_PATH/user.reg" 2>/dev/null || true
        )"

        if [[ "$OVERRIDE_VALUE" != "native" ]]; then

            if ! grep -Eiq \
                "\"\*?$dll\"=\"native\"|\"\\*$dll\"=\"native\"" \
                "$WINEPREFIX_PATH/user.reg"
            then

                die "No se encontró el override nativo para:

  $dll"

            fi

        fi

    done

    ok "Overrides DXVK confirmados."

    complete_step \
        "35-dxvk-overrides" \
        "Overrides DXVK verificados."

fi


# ============================================================
# 36. Configurar aceleración gráfica de Office
# ============================================================

if start_step "36-office-graphics" "Configurar aceleración de Office"; then

    log "Configurando aceleración gráfica de Office..."

    "$WINE32_BIN" \
        reg add \
        'HKCU\Software\Microsoft\Office\16.0\Common\Graphics' \
        /v DisableHardwareAcceleration \
        /t REG_DWORD \
        /d 0 \
        /f

    GRAPHICS_VERIFY_OUTPUT="$(
        "$WINE32_BIN" \
            reg query \
            'HKCU\Software\Microsoft\Office\16.0\Common\Graphics' \
            /v DisableHardwareAcceleration \
            2>/dev/null \
            || true
    )"

    GRAPHICS_VERIFY_VALUE="$(
        printf '%s\n' "$GRAPHICS_VERIFY_OUTPUT" |
            awk '
                /DisableHardwareAcceleration/ {
                    for (i = 1; i <= NF; i++) {
                        if ($i ~ /^0x[0-9a-fA-F]+$/) {
                            print tolower($i)
                            exit
                        }
                    }
                }
            ' |
            tr -d '[:space:]'
    )"

    if [[ "$GRAPHICS_VERIFY_VALUE" != "0x0" ]]; then

        die "Wine no confirmó correctamente la configuración gráfica.

Valor detectado:

  ${GRAPHICS_VERIFY_VALUE:-<vacío>}

Se esperaba:

  0x0"

    fi

    ok "DisableHardwareAcceleration = 0x0"
    ok "Office no tiene deshabilitada la aceleración por hardware."

    complete_step \
        "36-office-graphics" \
        "Configuración gráfica de Office establecida."

fi


# ============================================================
# 37. Verificar configuración gráfica
# ============================================================

if start_step "37-office-graphics-validation" "Verificar configuración gráfica"; then

    log "Verificando configuración gráfica de Office..."

    GRAPHICS_QUERY="$(
        "$WINE32_BIN" \
            reg query \
            'HKCU\Software\Microsoft\Office\16.0\Common\Graphics' \
            /v DisableHardwareAcceleration \
            2>/dev/null \
            || true
    )"

    echo
    echo "Registro de Office:"
    echo
    echo "$GRAPHICS_QUERY"
    echo

    GRAPHICS_VALUE="$(
        printf '%s\n' "$GRAPHICS_QUERY" |
            awk '
                /DisableHardwareAcceleration/ {
                    for (i = 1; i <= NF; i++) {
                        if ($i ~ /^0x[0-9a-fA-F]+$/) {
                            print tolower($i)
                            exit
                        }
                    }
                }
            ' |
            tr -d '[:space:]'
    )"

    if [[ "$GRAPHICS_VALUE" != "0x0" ]]; then

        die "La configuración de aceleración de Office no quedó
correctamente establecida.

Valor detectado:

  ${GRAPHICS_VALUE:-<vacío>}

Se esperaba:

  0x0"

    fi

    ok "DisableHardwareAcceleration = 0x0"
    ok "Office no tiene deshabilitada la aceleración por hardware."

    complete_step \
        "37-office-graphics-validation" \
        "Configuración gráfica verificada."

fi


# ============================================================
# 38. Reiniciar wineserver
# ============================================================

if start_step "38-wineserver" "Reiniciar wineserver"; then

    log "Reiniciando wineserver..."

    WINEPREFIX="$WINEPREFIX_PATH" \
        "$WINE32_BIN" \
        wineserver \
        -k \
        >/dev/null 2>&1 \
        || true

    sleep 2

    ok "wineserver reiniciado."

    complete_step \
        "38-wineserver" \
        "wineserver reiniciado."

fi


# ============================================================
# 39. Comprobar Microsoft Word
# ============================================================

if start_step "39-word" "Comprobar Microsoft Word"; then

    log "Comprobando Microsoft Word..."

    if [[ ! -f "$WORD_EXE" ]]; then

        die "No se encontró:

  $WORD_EXE"

    fi

    ok "WINWORD.EXE encontrado."

    complete_step \
        "39-word" \
        "Microsoft Word encontrado."

fi


# ============================================================
# 40. Asociaciones MIME
# ============================================================

if start_step "40-mime" "Configurar asociaciones MIME"; then

    log "Configurando asociaciones MIME..."

    xdg-mime default \
        word365.desktop \
        application/msword

    xdg-mime default \
        word365.desktop \
        application/vnd.openxmlformats-officedocument.wordprocessingml.document

    xdg-mime default \
        excel365.desktop \
        application/vnd.ms-excel

    xdg-mime default \
        excel365.desktop \
        application/vnd.openxmlformats-officedocument.spreadsheetml.sheet

    xdg-mime default \
        excel365.desktop \
        text/csv

    xdg-mime default \
        powerpoint365.desktop \
        application/vnd.ms-powerpoint

    xdg-mime default \
        powerpoint365.desktop \
        application/vnd.openxmlformats-officedocument.presentationml.presentation

    xdg-mime default \
        access365.desktop \
        application/vnd.ms-access

    xdg-mime default \
        publisher365.desktop \
        application/vnd.ms-publisher

    ok "Asociaciones MIME configuradas."

    complete_step \
        "40-mime" \
        "Asociaciones MIME configuradas."

fi


# ============================================================
# 41. Actualizar fontconfig
# ============================================================

if start_step "41-font-cache" "Actualizar caché de fuentes"; then

    log "Actualizando caché final de fuentes..."

    fc-cache -f

    ok "Caché final actualizado."

    complete_step \
        "41-font-cache" \
        "Caché final de fuentes actualizado."

fi


# ============================================================
# 42. Estado final
# ============================================================

if start_step "42-final" "Preparar resumen final"; then

    echo
    echo "============================================================"
    echo " Microsoft Office 365 - Instalación preparada"
    echo "============================================================"
    echo
    echo "Sistema:"
    echo "  $ARCH_NAME"
    echo
    echo "Archivo utilizado:"
    echo "  $ARCHIVE"
    echo
    echo "Wine:"
    echo "  $WINE32_VERSION"
    echo
    echo "Bottle:"
    echo "  $WINEPREFIX_PATH"
    echo
    echo "Arquitectura:"
    echo "  Wine32 (#arch=win32)"
    echo
    echo "DXVK:"
    echo "  Instalado con Wine32"
    echo "  d3d8       = native"
    echo "  d3d9       = native"
    echo "  d3d10core  = native"
    echo "  d3d11      = native"
    echo "  dxgi       = native"
    echo
    echo "Office:"
    echo "  Aceleración no deshabilitada"
    echo "  DisableHardwareAcceleration = 0"
    echo
    echo "Wrappers:"
    echo "  Completados y adaptados para esta máquina"
    echo "  $LOCAL_BIN"
    echo
    echo "Aplicaciones:"
    echo "  $APPLICATIONS_DIR"
    echo
    echo "Word:"
    echo "  $WORD_EXE"
    echo
    echo "Estado:"
    echo "  Checkpoints conservados en:"
    echo "  $STATE_FILE"
    echo
    echo "============================================================"
    echo

    complete_step \
        "42-final" \
        "Resumen final preparado."

fi


# ============================================================
# 43. Marcar instalación como completada
#
# IMPORTANTE:
#
# No eliminar STATE_FILE.
#
# El checkpoint permite que el instalador sepa que el Bottle
# pertenece a una instalación completada y evita que una futura
# ejecución intente sobrescribirlo.
# ============================================================

if start_step "43-complete" "Marcar instalación como completada"; then

    mark_step_done "43-complete"

    echo
    echo "============================================================"
    echo " Microsoft Office 365 - Instalación completada"
    echo "============================================================"
    echo
    echo "La instalación terminó correctamente."
    echo
    echo "Bottle:"
    echo "  $WINEPREFIX_PATH"
    echo
    echo "Wrappers:"
    echo "  $LOCAL_BIN"
    echo
    echo "Aplicaciones:"
    echo "  $APPLICATIONS_DIR"
    echo
    echo "Estado:"
    echo "  $STATE_FILE"
    echo
    echo "============================================================"
    echo

fi


# ============================================================
# 44. Prueba opcional de Word
#
# SKIP_WORD_TEST=1 permite terminar sin lanzar Word.
# ============================================================

if [[ "${SKIP_WORD_TEST:-0}" != "1" ]]; then

    log "Iniciando Microsoft Word..."

    exec \
        "$WINE32_BIN" \
        "$WORD_EXE"

else

    log "Prueba automática de Word omitida."

    echo
    echo "Para probar Word manualmente:"
    echo
    echo "  WINEPREFIX=\"$WINEPREFIX_PATH\" \\"
    echo "  WINEARCH=win32 \\"
    echo "  wine32 \\"
    echo "  \"$WORD_EXE\""
    echo

fi