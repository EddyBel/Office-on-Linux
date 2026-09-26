#!/usr/bin/env bash

# ============================================================
# Microsoft Office 365 - Bottle preconstruido
#
# Debian / Ubuntu + Wine + Wine32 + DXVK
#
# Instalación por usuario
#
# Compatibilidad:
#
#   Debian / Ubuntu y derivados compatibles
#
# Requisitos:
#
#   - Arquitectura x86_64 / amd64
#   - Soporte i386 habilitable
#   - Wine64
#   - Wine32
#   - Winetricks
#   - Vulkan x86_64
#   - Vulkan i386
#   - Vulkan funcional
#   - Samba / Winbind
#   - Zenity
#   - Fontconfig
#
# Bottle:
#
#   ~/.Microsoft_Office_365
#
# El Bottle es un prefijo Wine32:
#
#   #arch=win32
#
# El instalador utiliza checkpoints persistentes para poder
# continuar una instalación interrumpida.
#
# Estado:
#
#   ~/.local/state/office365-installer/progress
#
# ============================================================

set -Eeuo pipefail


# ============================================================
# 0. Configuración
# ============================================================

# La carpeta del instalador, no el directorio desde donde
# fue ejecutado.
readonly SOURCE_DIR="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &&
    pwd
)"

readonly LOCAL_ARCHIVE_ENGLISH="$SOURCE_DIR/MSO365-English-.tar.zst"
readonly LOCAL_ARCHIVE_SHORT="$SOURCE_DIR/MSO365-EN.tar.zst"

readonly DOWNLOAD_URL="https://github.com/EddyBel/Office-on-Linux/releases/download/office365-fedora-44/MSO365-EN.tar.zst"
readonly DOWNLOAD_ARCHIVE="$SOURCE_DIR/MSO365-EN.tar.zst"

ARCHIVE=""

readonly BOTTLE_DIR="$SOURCE_DIR/MSO365-English-"
readonly SOURCE_BOTTLE="$BOTTLE_DIR/.Microsoft_Office_365"

readonly WINEPREFIX_PATH="$HOME/.Microsoft_Office_365"

readonly INSTALL_USER="$(id -un)"
readonly INSTALL_GROUP="$(id -gn)"

readonly WINE_USER="crossover"

readonly LOCAL_BIN="$HOME/.local/bin"
readonly APPLICATIONS_DIR="$HOME/.local/share/applications"
readonly ICONS_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
readonly OFFICE_FONT_DIR="$HOME/.local/share/fonts/Office365"

readonly STATE_DIR="$HOME/.local/state/office365-installer"
readonly STATE_FILE="$STATE_DIR/progress"

readonly WORD_EXE="$WINEPREFIX_PATH/drive_c/Program Files/Microsoft Office/root/Office16/WINWORD.EXE"

CURRENT_STEP="inicio"

mkdir -p "$STATE_DIR"


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
    echo
    exit 1
}


# ============================================================
# Checkpoints
# ============================================================

step_done() {
    local step="$1"

    grep -qxF "$step" "$STATE_FILE" 2>/dev/null
}


mark_step_done() {
    local step="$1"

    touch "$STATE_FILE"

    if ! step_done "$step"; then
        echo "$step" >> "$STATE_FILE"
    fi
}


start_step() {
    local step="$1"
    local description="$2"

    CURRENT_STEP="$step"

    if step_done "$step"; then
        ok "Omitiendo etapa completada: $description"
        return 1
    fi

    echo
    echo "============================================================"
    echo " ETAPA: $step"
    echo " $description"
    echo "============================================================"
    echo

    return 0
}


complete_step() {
    local step="$1"
    local description="$2"

    mark_step_done "$step"

    CURRENT_STEP="$step"

    ok "$description"
    ok "Checkpoint guardado: $step"
}


cleanup_on_interrupt() {
    local exit_code=$?

    echo
    echo "============================================================"
    echo " Instalación interrumpida"
    echo "============================================================"
    echo
    echo "Última etapa:"
    echo
    echo "  $CURRENT_STEP"
    echo
    echo "El progreso completado se guardó en:"
    echo
    echo "  $STATE_FILE"
    echo
    echo "Puedes volver a ejecutar:"
    echo
    echo "  ./install.sh"
    echo
    echo "El instalador continuará desde la última etapa"
    echo "completada correctamente."
    echo

    exit "$exit_code"
}

trap cleanup_on_interrupt INT TERM


# ============================================================
# Validación de wrappers existentes
#
# Comprueba que los launchers generados por versiones
# anteriores del instalador sigan siendo compatibles con
# la implementación actual.
# ============================================================

office_wrappers_current() {

    local launcher

    # --------------------------------------------------------
    # Wrapper de limpieza
    # --------------------------------------------------------

    if [[ ! -x "$LOCAL_BIN/limpiar_office-wine365.sh" ]]; then
        return 1
    fi


    # --------------------------------------------------------
    # Wrappers principales
    # --------------------------------------------------------

    for launcher in \
        "$LOCAL_BIN/word365.sh" \
        "$LOCAL_BIN/excel365.sh" \
        "$LOCAL_BIN/powerpoint365.sh" \
        "$LOCAL_BIN/access365.sh" \
        "$LOCAL_BIN/outlook365.sh" \
        "$LOCAL_BIN/publisher365.sh"
    do

        [[ -x "$launcher" ]] || return 1


        # ----------------------------------------------------
        # Debe utilizar Wine32.
        # ----------------------------------------------------

        grep -q 'wine32' "$launcher" || return 1


        # ----------------------------------------------------
        # No debe utilizar el comando genérico "wine".
        # ----------------------------------------------------

        if grep -En \
            '(^|[[:space:]])wine([[:space:]]|$)' \
            "$launcher" \
            >/dev/null
        then
            return 1
        fi


        # ----------------------------------------------------
        # Debe contener el wrapper de limpieza.
        # ----------------------------------------------------

        grep -Eq \
            'limpiar_office-wine365\.sh' \
            "$launcher" \
            || return 1


        # ----------------------------------------------------
        # Debe ejecutarlo en modo automático/silencioso.
        #
        # Se permite:
        #
        #   --silent
        #   --auto
        #
        # y se toleran comillas alrededor del path.
        # ----------------------------------------------------

        grep -Eq \
            'limpiar_office-wine365\.sh["'\'']?[[:space:]]+--(silent|auto)' \
            "$launcher" \
            || return 1

    done

    return 0
}


invalidate_stale_wrapper_steps() {

    local wrapper_checkpoint_exists=0

    if [[ -f "$STATE_FILE" ]]; then

        for step in \
            25-original-launchers \
            26-cleanup-wrapper \
            27-office-wrappers \
            28-wrapper-validation \
            29-wine32-validation
        do

            if step_done "$step"; then
                wrapper_checkpoint_exists=1
                break
            fi

        done

    fi


    # --------------------------------------------------------
    # Si no hay checkpoints relacionados y tampoco existen
    # wrappers, no hay nada que invalidar.
    # --------------------------------------------------------

    if (( wrapper_checkpoint_exists == 0 )) &&
       [[ ! -e "$LOCAL_BIN/word365.sh" ]] &&
       [[ ! -e "$LOCAL_BIN/excel365.sh" ]] &&
       [[ ! -e "$LOCAL_BIN/powerpoint365.sh" ]] &&
       [[ ! -e "$LOCAL_BIN/access365.sh" ]] &&
       [[ ! -e "$LOCAL_BIN/outlook365.sh" ]] &&
       [[ ! -e "$LOCAL_BIN/publisher365.sh" ]] &&
       [[ ! -e "$LOCAL_BIN/limpiar_office-wine365.sh" ]]
    then
        return 0
    fi


    # --------------------------------------------------------
    # Si todos los wrappers actuales son correctos, conservar
    # los checkpoints.
    # --------------------------------------------------------

    if office_wrappers_current; then

        ok "Wrappers Office existentes están actualizados."

        return 0

    fi


    # --------------------------------------------------------
    # Hay wrappers antiguos o incompletos.
    # --------------------------------------------------------

    warn "Se detectaron wrappers Office antiguos o incompletos."
    warn "Se invalidarán las etapas de generación de launchers."


    if [[ -f "$STATE_FILE" ]]; then

        sed -i \
            -e '/^25-original-launchers$/d' \
            -e '/^26-cleanup-wrapper$/d' \
            -e '/^27-office-wrappers$/d' \
            -e '/^28-wrapper-validation$/d' \
            -e '/^29-wine32-validation$/d' \
            "$STATE_FILE"

    fi

    ok "Etapas de wrappers invalidadas."

}


# ============================================================
# Invalidar wrappers antiguos antes de procesar checkpoints
# ============================================================

invalidate_stale_wrapper_steps


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

    case "${ID:-}" in

        debian|ubuntu)
            ;;

        *)
            if [[ "${ID_LIKE:-}" == *debian* ]]; then
                :
            else
                die "Este instalador está diseñado para Debian,
Ubuntu y sistemas derivados compatibles.

Sistema detectado:

  ${PRETTY_NAME:-desconocido}"
            fi
            ;;

    esac

    DISTRO_ID="${ID:-unknown}"
    DISTRO_VERSION="${VERSION_ID:-unknown}"
    DISTRO_NAME="${PRETTY_NAME:-$DISTRO_ID $DISTRO_VERSION}"

    ok "Sistema Debian/Ubuntu detectado:"
    echo "    $DISTRO_NAME"

    complete_step \
        "02-system" \
        "Sistema operativo compatible."

else

    # shellcheck disable=SC1091
    source /etc/os-release

    DISTRO_ID="${ID:-unknown}"
    DISTRO_VERSION="${VERSION_ID:-unknown}"
    DISTRO_NAME="${PRETTY_NAME:-$DISTRO_ID $DISTRO_VERSION}"

fi


# ============================================================
# 3. Comprobar arquitectura
# ============================================================

if start_step "03-architecture" "Comprobar arquitectura"; then

    log "Comprobando arquitectura..."

    MACHINE_ARCH="$(dpkg --print-architecture)"

    if [[ "$MACHINE_ARCH" != "amd64" ]]; then

        die "Este Bottle requiere un sistema x86_64 / amd64.

Arquitectura detectada:

  $MACHINE_ARCH"

    fi

    ok "Arquitectura amd64."

    complete_step \
        "03-architecture" \
        "Arquitectura amd64 confirmada."

else

    MACHINE_ARCH="$(dpkg --print-architecture)"

fi


# ============================================================
# 4. Comprobar APT
# ============================================================

if start_step "04-apt" "Comprobar gestor de paquetes"; then

    log "Comprobando gestor de paquetes..."

    command -v apt-get >/dev/null 2>&1 \
        || die "No se encontró apt-get."

    command -v dpkg >/dev/null 2>&1 \
        || die "No se encontró dpkg."

    ok "APT disponible."

    complete_step \
        "04-apt" \
        "APT disponible."

fi


# ============================================================
# 5. Habilitar arquitectura i386
# ============================================================

if start_step "05-i386" "Habilitar arquitectura i386"; then

    log "Comprobando soporte i386..."

    if ! dpkg --print-foreign-architectures \
        | grep -qx 'i386'
    then

        log "La arquitectura i386 no está habilitada."

        sudo dpkg --add-architecture i386

        ok "Arquitectura i386 habilitada."

    else

        ok "Arquitectura i386 ya habilitada."

    fi

    complete_step \
        "05-i386" \
        "Soporte i386 configurado."

fi


# ============================================================
# 6. Actualizar índices APT
# ============================================================

if start_step "06-apt-update" "Actualizar índices APT"; then

    log "Actualizando índices de paquetes..."

    sudo apt-get update

    complete_step \
        "06-apt-update" \
        "Índices APT actualizados."

fi


# ============================================================
# 7. Comprobar Bottle / descarga
# ============================================================

if start_step "07-archive" "Preparar Bottle de Office"; then

    log "Buscando archivo de Office..."

    if [[ -f "$LOCAL_ARCHIVE_ENGLISH" ]]; then

        ARCHIVE="$LOCAL_ARCHIVE_ENGLISH"

        ok "Archivo local encontrado:"
        echo "    $ARCHIVE"

    elif [[ -f "$LOCAL_ARCHIVE_SHORT" ]]; then

        ARCHIVE="$LOCAL_ARCHIVE_SHORT"

        ok "Archivo local encontrado:"
        echo "    $ARCHIVE"

    elif [[ -f "$DOWNLOAD_ARCHIVE" ]]; then

        log "Se encontró una descarga anterior."

        ARCHIVE="$DOWNLOAD_ARCHIVE"

        ok "Se reutilizará el archivo descargado anteriormente:"
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
            log "Instalando curl mediante APT..."

            sudo apt-get install -y curl

            if command -v curl >/dev/null 2>&1; then
                DOWNLOAD_TOOL="curl"
            fi

        fi

        [[ -n "$DOWNLOAD_TOOL" ]] \
            || die "No fue posible encontrar ni instalar una herramienta de descarga."

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
                    --continue-at - \
                    --output "$DOWNLOAD_ARCHIVE" \
                    "$DOWNLOAD_URL"
                then

                    die "No fue posible descargar el Bottle.

Si la descarga quedó parcialmente descargada,
vuelve a ejecutar el instalador para intentar continuar."

                fi

                ;;

            wget)

                log "Descargando con wget..."

                if ! wget \
                    --continue \
                    --progress=bar:force \
                    --tries=3 \
                    --timeout=15 \
                    -O "$DOWNLOAD_ARCHIVE" \
                    "$DOWNLOAD_URL"
                then

                    die "No fue posible descargar el Bottle.

Si la descarga quedó parcialmente descargada,
vuelve a ejecutar el instalador para intentar continuar."

                fi

                ;;

        esac

        [[ -f "$DOWNLOAD_ARCHIVE" ]] \
            || die "La descarga terminó pero el archivo no existe."

        [[ -s "$DOWNLOAD_ARCHIVE" ]] \
            || die "La descarga produjo un archivo vacío."

        ARCHIVE="$DOWNLOAD_ARCHIVE"

        ok "Bottle descargado correctamente:"
        echo "    $ARCHIVE"

    fi

    [[ -f "$ARCHIVE" ]] \
        || die "No existe el archivo seleccionado:

  $ARCHIVE"

    [[ -s "$ARCHIVE" ]] \
        || die "El archivo del Bottle está vacío:

  $ARCHIVE"

    complete_step \
        "07-archive" \
        "Bottle disponible."

else

    if [[ -f "$LOCAL_ARCHIVE_ENGLISH" ]]; then

        ARCHIVE="$LOCAL_ARCHIVE_ENGLISH"

    elif [[ -f "$LOCAL_ARCHIVE_SHORT" ]]; then

        ARCHIVE="$LOCAL_ARCHIVE_SHORT"

    elif [[ -f "$DOWNLOAD_ARCHIVE" ]]; then

        ARCHIVE="$DOWNLOAD_ARCHIVE"

    else

        die "No se pudo recuperar el archivo del Bottle."

    fi

fi


# ============================================================
# 8. Detectar instalación interrumpida
# ============================================================

if start_step "08-existing-install" "Comprobar instalación existente"; then

    if [[ -e "$WINEPREFIX_PATH" ]]; then

        if [[ -f "$STATE_FILE" ]]; then

            log "Se detectó una instalación anterior."

            echo
            echo "Bottle:"
            echo "  $WINEPREFIX_PATH"
            echo
            echo "Estado guardado:"
            echo

            cat "$STATE_FILE"

            echo
            ok "La instalación será reanudada."

        else

            die "Ya existe el Bottle:

  $WINEPREFIX_PATH

No se encontró un estado de instalación asociado.

Por seguridad, este instalador no sobrescribirá
una instalación existente."

        fi

    else

        ok "No existe una instalación previa."

    fi

    complete_step \
        "08-existing-install" \
        "Estado de instalación comprobado."

fi


# ============================================================
# 9. Comprobar extracción existente
# ============================================================

if start_step "09-extraction-check" "Comprobar extracción anterior"; then

    if [[ -e "$BOTTLE_DIR" ]]; then

        if [[ -d "$SOURCE_BOTTLE" ]]; then

            ok "Se encontró una extracción válida anterior:"
            echo "    $SOURCE_BOTTLE"

        else

            warn "Se encontró una extracción incompleta:"
            echo "    $BOTTLE_DIR"

            log "Eliminando extracción incompleta..."

            rm -rf "$BOTTLE_DIR"

            ok "Extracción incompleta eliminada."

        fi

    else

        ok "No existe una extracción anterior."

    fi

    complete_step \
        "09-extraction-check" \
        "Extracción comprobada."

fi


# ============================================================
# 10. Instalar dependencias Debian / Ubuntu
# ============================================================

if start_step "10-dependencies" "Instalar dependencias Debian / Ubuntu"; then

    log "Instalando dependencias..."

    sudo apt-get install -y \
        ca-certificates \
        curl \
        wget \
        tar \
        zstd \
        fontconfig \
        xdg-utils \
        desktop-file-utils \
        zenity \
        samba \
        winbind \
        wine \
        wine64 \
        wine32 \
        winetricks \
        libvulkan1:amd64 \
        libvulkan1:i386 \
        vulkan-tools

    complete_step \
        "10-dependencies" \
        "Dependencias instaladas."

fi


# ============================================================
# 11. Comprobar Wine
# ============================================================

if start_step "11-wine" "Comprobar Wine32 y Wine64"; then

    log "Comprobando Wine..."

    WINE64_BIN="$(command -v wine64 || true)"
    WINE32_BIN="$(command -v wine32 || true)"

    [[ -n "$WINE64_BIN" ]] \
        || die "No se encontró wine64."

    [[ -n "$WINE32_BIN" ]] \
        || die "No se encontró wine32.

El Bottle requiere Wine32."

    WINE_VERSION="$(
        "$WINE32_BIN" --version 2>/dev/null || true
    )"

    [[ -n "$WINE_VERSION" ]] \
        || die "wine32 no pudo devolver su versión."

    echo "    $WINE_VERSION"

    ok "Wine32 disponible."

    complete_step \
        "11-wine" \
        "Wine32 y Wine64 disponibles."

else

    WINE64_BIN="$(command -v wine64 || true)"
    WINE32_BIN="$(command -v wine32 || true)"

    WINE_VERSION="$(
        "$WINE32_BIN" --version 2>/dev/null || true
    )"

fi


# ============================================================
# 12. Comprobar Winetricks
# ============================================================

if start_step "12-winetricks" "Comprobar Winetricks"; then

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
        "12-winetricks" \
        "Winetricks disponible."

fi


# ============================================================
# 13. Comprobar Vulkan
# ============================================================

if start_step "13-vulkan" "Comprobar Vulkan"; then

    log "Comprobando Vulkan..."

    command -v vulkaninfo >/dev/null 2>&1 \
        || die "No se encontró vulkaninfo."

    VULKAN_SUMMARY="$(
        vulkaninfo --summary 2>/dev/null || true
    )"

    if [[ -z "$VULKAN_SUMMARY" ]]; then

        die "Vulkan no respondió correctamente.

DXVK requiere un controlador Vulkan funcional.

Instala los controladores Vulkan apropiados para tu GPU,
incluyendo soporte de 32 bits."

    fi

    echo "$VULKAN_SUMMARY" \
        | grep -E 'deviceName|driverName|driverInfo' \
        | head -20 \
        || true

    ok "Vulkan responde correctamente."

    complete_step \
        "13-vulkan" \
        "Vulkan funcional."

fi


# ============================================================
# 14. Comprobar herramientas de integración
# ============================================================

if start_step "14-tools" "Comprobar herramientas de integración"; then

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

            die "No se encontró:

  $command_name"

        fi

    done

    ok "Herramientas de integración disponibles."

    complete_step \
        "14-tools" \
        "Herramientas de integración disponibles."

fi


# ============================================================
# 15. Extraer Bottle
# ============================================================

if start_step "15-extraction" "Extraer Bottle"; then

    log "Extrayendo Bottle..."

    if [[ -e "$BOTTLE_DIR" ]]; then

        warn "Se encontró una extracción anterior."

        if [[ -d "$SOURCE_BOTTLE" ]]; then

            ok "La extracción ya está completa."

        else

            log "La extracción anterior está incompleta."
            log "Eliminándola antes de reintentar..."

            rm -rf "$BOTTLE_DIR"

        fi

    fi

    if [[ ! -d "$SOURCE_BOTTLE" ]]; then

        tar \
            -I zstd \
            -xf "$ARCHIVE" \
            -C "$SOURCE_DIR"

    fi

    [[ -d "$SOURCE_BOTTLE" ]] \
        || die "No se encontró el Bottle esperado:

  $SOURCE_BOTTLE"

    complete_step \
        "15-extraction" \
        "Bottle extraído correctamente."

fi


# ============================================================
# 16. Instalar Bottle
# ============================================================

if start_step "16-install-bottle" "Instalar Bottle"; then

    log "Copiando Bottle a:

  $WINEPREFIX_PATH"

    if [[ -e "$WINEPREFIX_PATH" ]]; then

        log "Eliminando instalación parcial anterior..."

        rm -rf "$WINEPREFIX_PATH"

    fi

    cp -a \
        "$SOURCE_BOTTLE" \
        "$WINEPREFIX_PATH"

    [[ -d "$WINEPREFIX_PATH" ]] \
        || die "La copia del Bottle falló."

    complete_step \
        "16-install-bottle" \
        "Bottle copiado."

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
        "Propietario y permisos corregidos."

fi


# ============================================================
# 18. Comprobar arquitectura del Bottle
# ============================================================

if start_step "18-bottle-arch" "Comprobar arquitectura del Bottle"; then

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
        "18-bottle-arch" \
        "Bottle Wine32 confirmado."

fi


# ============================================================
# 19. Configuración Wine32
# ============================================================

export WINEPREFIX="$WINEPREFIX_PATH"
export WINEARCH="win32"

ok "WINEPREFIX:"
echo "    $WINEPREFIX"

ok "WINEARCH:"
echo "    $WINEARCH"


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
        "Unidades Wine reconstruidas."

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

if start_step "22-xdg" "Crear directorios de integración"; then

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
# 23. Instalar fuentes Office
# ============================================================

if start_step "23-fonts" "Instalar fuentes Office"; then

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

Se continuará sin fuentes adicionales."

    fi

    fc-cache -f

    ok "Caché de fuentes actualizado."

    complete_step \
        "23-fonts" \
        "Fuentes Office configuradas."

fi


# ============================================================
# 24. Reparar fuentes bitmap Wine
# ============================================================

if start_step "24-wine-fonts" "Reparar fuentes bitmap Wine"; then

    log "Comprobando fuentes bitmap Wine..."

    WINE_FONT_DIRS=(
        "/usr/share/wine/fonts"
        "/usr/share/wine/wine/fonts"
        "/usr/share/wine-staging/fonts"
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

        SOURCE=""

        for font_dir in "${WINE_FONT_DIRS[@]}"
        do

            if [[ -f "$font_dir/$font" ]]; then

                SOURCE="$font_dir/$font"
                break

            fi

        done

        if [[ -n "$SOURCE" ]]; then

            cp -f \
                "$SOURCE" \
                "$TARGET"

            ok "$font copiada desde $SOURCE"

        else

            warn "No se encontró $font en las rutas conocidas."

        fi

    done

    complete_step \
        "24-wine-fonts" \
        "Fuentes bitmap comprobadas."

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
# 26. Wrapper de limpieza
# ============================================================

if start_step "26-cleanup-wrapper" "Crear wrapper de limpieza"; then

    log "Configurando wrapper de limpieza..."

    cat > "$LOCAL_BIN/limpiar_office-wine365.sh" <<'EOF'
#!/bin/bash

WINEPREFIX="$HOME/.Microsoft_Office_365"
WINESERVER="$(command -v wineserver || echo /usr/bin/wineserver)"

if [ "$1" = "--silent" ] || [ "$1" = "--auto" ]; then

    ACTIVE_COUNT=$(
        pgrep -f -i -c \
        'WINWORD\.EXE|EXCEL\.EXE|POWERPNT\.EXE|OUTLOOK\.EXE|MSACCESS\.EXE|MSPUB\.EXE' \
        || true
    )

    if [ "$ACTIVE_COUNT" -gt 0 ]; then
        exit 0
    fi

else

    zenity --question \
        --title="Clean Wine / Office" \
        --text="Do you want to close all Wine and Microsoft Office processes?\n\nAny unsaved work will be lost." \
        --width=420

    [ $? -ne 0 ] && exit 0

fi

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

if [ -d "$WINEPREFIX" ]; then

    WINEPREFIX="$WINEPREFIX" \
        "$WINESERVER" -k \
        2>/dev/null || true

    WINEPREFIX="$WINEPREFIX" \
        "$WINESERVER" -w \
        2>/dev/null || true

fi

exit 0
EOF

    chmod 755 \
        "$LOCAL_BIN/limpiar_office-wine365.sh"

    ok "Wrapper de limpieza configurado."

    complete_step \
        "26-cleanup-wrapper" \
        "Wrapper de limpieza configurado."

fi


# ============================================================
# 27. Crear wrappers Office
# ============================================================

if start_step "27-office-wrappers" "Crear wrappers portables de Office"; then

    log "Configurando wrappers portables..."


    create_office_wrapper() {

        local launcher="$1"
        local executable="$2"
        local output="$LOCAL_BIN/$launcher"

        cat > "$output" <<EOF
#!/bin/bash

set -Eeuo pipefail

export WINEPREFIX="\$HOME/.Microsoft_Office_365"
export WINEARCH="win32"
export LANG=C.UTF-8
export WINEDEBUG=-all

app="C:\\\\Program Files\\\\Microsoft Office\\\\root\\\\Office16\\\\$executable"

wineserver -p >/dev/null 2>&1 || true

office_exit_code=0

if [ \$# -eq 0 ]; then

    wine32 "\$app" || office_exit_code=\$?

else

    for file in "\$@"; do

        fullpath=\$(realpath "\$file")
        winpath="Z:\${fullpath//\\//\\\\}"

        wine32 "\$app" "\$winpath" || office_exit_code=\$?

    done

fi

# La limpieza DEBE ejecutarse aunque Office termine
# con un código de error.
if [ -x "\$HOME/.local/bin/limpiar_office-wine365.sh" ]; then

    "\$HOME/.local/bin/limpiar_office-wine365.sh" --silent &

fi

exit "\$office_exit_code"
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


    ok "Wrappers Office creados."

    complete_step \
        "27-office-wrappers" \
        "Wrappers Office configurados."

fi


# ============================================================
# 28. Verificar wrappers
# ============================================================

if start_step "28-wrapper-validation" "Validar wrappers"; then

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

            die "No se pudo crear:

  $wrapper"

        fi

    done

    ok "Wrappers completados."

    complete_step \
        "28-wrapper-validation" \
        "Wrappers validados."

fi


# ============================================================
# 29. Validar uso de Wine32
# ============================================================

if start_step "29-wine32-validation" "Validar uso de Wine32"; then

    log "Validando wrappers..."


    for launcher in \
        "$LOCAL_BIN/word365.sh" \
        "$LOCAL_BIN/excel365.sh" \
        "$LOCAL_BIN/powerpoint365.sh" \
        "$LOCAL_BIN/access365.sh" \
        "$LOCAL_BIN/outlook365.sh" \
        "$LOCAL_BIN/publisher365.sh"
    do

        if [[ ! -f "$launcher" ]]; then

            die "No existe el launcher:

  $launcher"

        fi


        if [[ ! -x "$launcher" ]]; then

            die "El launcher no es ejecutable:

  $launcher"

        fi


        # ----------------------------------------------------
        # Debe contener wine32.
        # ----------------------------------------------------

        if ! grep -q 'wine32' "$launcher"; then

            die "El launcher no contiene wine32:

  $launcher

Contenido actual:

------------------------------------------------------------
$(cat "$launcher")
------------------------------------------------------------"

        fi


        # ----------------------------------------------------
        # No debe utilizar el comando genérico wine.
        # ----------------------------------------------------

        if grep -En \
            '(^|[[:space:]])wine([[:space:]]|$)' \
            "$launcher" \
            >/dev/null
        then

            die "El launcher contiene una llamada al comando genérico wine:

  $launcher

Contenido actual:

------------------------------------------------------------
$(cat "$launcher")
------------------------------------------------------------"

        fi


        # ----------------------------------------------------
        # Debe contener el wrapper de limpieza.
        # ----------------------------------------------------

        if ! grep -Eq \
            'limpiar_office-wine365\.sh' \
            "$launcher"
        then

            die "El launcher no contiene el wrapper de limpieza automática:

  $launcher

Contenido actual:

------------------------------------------------------------
$(cat "$launcher")
------------------------------------------------------------"

        fi


        # ----------------------------------------------------
        # Debe ejecutarlo en modo automático/silencioso.
        #
        # Acepta:
        #
        #   --silent
        #   --auto
        #
        # y paths entre comillas.
        # ----------------------------------------------------

        if ! grep -Eq \
            'limpiar_office-wine365\.sh["'\'']?[[:space:]]+--(silent|auto)' \
            "$launcher"
        then

            die "El launcher no contiene una llamada automática
al wrapper de limpieza:

  $launcher

Contenido actual:

------------------------------------------------------------
$(cat "$launcher")
------------------------------------------------------------"

        fi

    done


    if [[ ! -x "$LOCAL_BIN/limpiar_office-wine365.sh" ]]; then

        die "No existe el wrapper de limpieza:

  $LOCAL_BIN/limpiar_office-wine365.sh"

    fi


    ok "Todos los wrappers utilizan wine32."
    ok "Todos los wrappers incluyen limpieza automática."

    complete_step \
        "29-wine32-validation" \
        "Uso de Wine32 y limpieza automática validados."

fi


# ============================================================
# 30. Instalar archivos .desktop
# ============================================================

if start_step "30-desktops" "Instalar archivos .desktop"; then

    log "Instalando accesos del menú..."

    shopt -s nullglob

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
        "30-desktops" \
        "Archivos .desktop instalados."

fi


# ============================================================
# 31. Corregir rutas Exec
# ============================================================

if start_step "31-desktop-paths" "Adaptar rutas Exec"; then

    log "Adaptando archivos .desktop..."

    for desktop in "$APPLICATIONS_DIR/"*365.desktop
    do

        sed -Ei \
            "s#^Exec=/opt/launchers/#Exec=${LOCAL_BIN}/#g" \
            "$desktop"

    done

    ok "Rutas Exec adaptadas."

    complete_step \
        "31-desktop-paths" \
        "Rutas de los accesos adaptadas."

fi


# ============================================================
# 32. Validar archivos .desktop
# ============================================================

if start_step "32-desktop-validation" "Validar archivos .desktop"; then

    log "Validando accesos del menú..."

    for desktop in "$APPLICATIONS_DIR/"*365.desktop
    do

        if grep -q '^Exec=/opt/launchers/' "$desktop"; then

            die "El archivo .desktop todavía apunta a /opt/launchers:

  $desktop"

        fi


        EXEC_PATH="$(
            sed -n \
                's/^Exec=\([^ %]*\).*/\1/p' \
                "$desktop" \
                | head -1
        )"


        if [[ -z "$EXEC_PATH" ]]; then

            die "No se encontró Exec= en:

  $desktop"

        fi


        if [[ ! -x "$EXEC_PATH" ]]; then

            die "El launcher indicado por el .desktop no existe
o no es ejecutable:

  $EXEC_PATH"

        fi

    done

    ok "Archivos .desktop correctamente vinculados."

    complete_step \
        "32-desktop-validation" \
        "Archivos .desktop validados."

fi


# ============================================================
# 33. Instalar iconos
# ============================================================

if start_step "33-icons" "Instalar iconos"; then

    log "Instalando iconos..."

    shopt -s nullglob

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
        "33-icons" \
        "Iconos procesados."

fi


# ============================================================
# 34. Actualizar integración del escritorio
# ============================================================

if start_step "34-desktop-integration" "Actualizar integración del escritorio"; then

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
        "34-desktop-integration" \
        "Integración del escritorio actualizada."

fi


# ============================================================
# 35. Instalar DXVK x32
# ============================================================

if start_step "35-dxvk" "Instalar DXVK Wine32"; then

    log "Instalando DXVK para el Bottle Wine32..."

    WINE="$WINE32_BIN" \
        WINEPREFIX="$WINEPREFIX_PATH" \
        WINEARCH="win32" \
        winetricks \
        --unattended \
        dxvk

    ok "DXVK instalado."

    complete_step \
        "35-dxvk" \
        "DXVK instalado."

fi


# ============================================================
# 36. Verificar DLL de DXVK
# ============================================================

if start_step "36-dxvk-dlls" "Verificar DLL de DXVK"; then

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
        "36-dxvk-dlls" \
        "DLL de DXVK verificadas."

fi


# ============================================================
# 37. Verificar overrides
# ============================================================

if start_step "37-dxvk-overrides" "Verificar overrides de DXVK"; then

    log "Verificando overrides de DXVK..."

    for dll in \
        d3d8 \
        d3d9 \
        d3d10core \
        d3d11 \
        dxgi
    do

        if ! grep -q \
            "\"*$dll\"=\"native\"" \
            "$WINEPREFIX_PATH/user.reg"
        then

            die "No se encontró el override nativo para:

  $dll"

        fi

    done

    ok "Overrides DXVK confirmados."

    complete_step \
        "37-dxvk-overrides" \
        "Overrides DXVK verificados."

fi


# ============================================================
# 38. Habilitar aceleración por hardware de Office
# ============================================================

if start_step "38-office-graphics" "Configurar aceleración por hardware"; then

    log "Habilitando aceleración por hardware de Office..."

    "$WINE32_BIN" \
        reg add \
        'HKCU\Software\Microsoft\Office\16.0\Common\Graphics' \
        /v DisableHardwareAcceleration \
        /t REG_DWORD \
        /d 0 \
        /f \
        >/dev/null

    ok "DisableHardwareAcceleration=0 configurado."

    complete_step \
        "38-office-graphics" \
        "Aceleración por hardware configurada."

fi


# ============================================================
# 39. Verificar aceleración por hardware
# ============================================================

if start_step "39-office-graphics-validation" "Verificar aceleración por hardware"; then

    log "Verificando aceleración por hardware de Office..."

    GRAPHICS_VALUE="$(
        "$WINE32_BIN" \
            reg query \
            'HKCU\Software\Microsoft\Office\16.0\Common\Graphics' \
            /v DisableHardwareAcceleration \
            2>/dev/null \
            | awk '/DisableHardwareAcceleration/ {print $NF}'
    )"

    if [[ "$GRAPHICS_VALUE" != "0x0" ]]; then

        die "La aceleración por hardware de Office no quedó habilitada.

Valor detectado:

  $GRAPHICS_VALUE

Se esperaba:

  0x0"

    fi

    ok "Aceleración por hardware de Office habilitada."

    complete_step \
        "39-office-graphics-validation" \
        "Aceleración por hardware verificada."

fi


# ============================================================
# 40. Reiniciar wineserver
# ============================================================

if start_step "40-wineserver" "Reiniciar wineserver"; then

    log "Reiniciando wineserver..."

    "$WINE32_BIN" \
        wineserver \
        -k \
        >/dev/null 2>&1 \
        || true

    sleep 2

    ok "wineserver reiniciado."

    complete_step \
        "40-wineserver" \
        "wineserver reiniciado."

fi


# ============================================================
# 41. Comprobar Microsoft Word
# ============================================================

if start_step "41-word" "Comprobar Microsoft Word"; then

    log "Comprobando Microsoft Word..."

    if [[ ! -f "$WORD_EXE" ]]; then

        die "No se encontró:

  $WORD_EXE"

    fi

    ok "WINWORD.EXE encontrado."

    complete_step \
        "41-word" \
        "Microsoft Word encontrado."

fi


# ============================================================
# 42. Asociaciones MIME
# ============================================================

if start_step "42-mime" "Configurar asociaciones MIME"; then

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
        "42-mime" \
        "Asociaciones MIME configuradas."

fi


# ============================================================
# 43. Actualizar fontconfig
# ============================================================

if start_step "43-font-cache" "Actualizar caché final de fuentes"; then

    log "Actualizando caché final de fuentes..."

    fc-cache -f

    ok "Caché final actualizado."

    complete_step \
        "43-font-cache" \
        "Caché de fuentes actualizado."

fi


# ============================================================
# 44. Estado final
# ============================================================

if start_step "44-final" "Finalizar instalación"; then

    mark_step_done "44-final"

    echo
    echo "============================================================"
    echo " Microsoft Office 365 - Instalación completada"
    echo "============================================================"
    echo
    echo "Sistema:"
    echo "  $DISTRO_NAME"
    echo
    echo "Archivo utilizado:"
    echo "  $ARCHIVE"
    echo
    echo "Wine:"
    echo "  $WINE_VERSION"
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
    echo "  Aceleración por hardware = ACTIVADA"
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
    echo "============================================================"
    echo

fi


# ============================================================
# 45. Limpiar checkpoints
# ============================================================

if step_done "44-final"; then

    log "Eliminando estado temporal de instalación..."

    rm -f "$STATE_FILE"

    rmdir "$STATE_DIR" 2>/dev/null || true

    ok "Checkpoints eliminados."
    ok "La instalación terminó correctamente."

fi


# ============================================================
# 46. Prueba opcional de Word
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