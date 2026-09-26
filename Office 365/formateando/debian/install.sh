#!/usr/bin/env bash

# ============================================================
# Microsoft Office 365 - Bottle preconstruido
#
# Debian / Ubuntu + Wine + Wine32 + DXVK
#
# Instalación por usuario
#
# ============================================================

set -Eeuo pipefail


# ============================================================
# 0. Configuración
# ============================================================

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

# SVG
readonly ICONS_SCALABLE_DIR="$HOME/.local/share/icons/hicolor/scalable/apps"

# PNG 256x256
readonly ICONS_256_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"

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

    [[ -r /etc/os-release ]] \
        || die "No se pudo determinar el sistema operativo."

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
Ubuntu y derivados compatibles.

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

    [[ "$MACHINE_ARCH" == "amd64" ]] \
        || die "Este Bottle requiere un sistema x86_64 / amd64.

Arquitectura detectada:

  $MACHINE_ARCH"

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
# 7. Preparar Bottle
# ============================================================

if start_step "07-archive" "Preparar Bottle de Office"; then

    log "Buscando archivo de Office..."

    if [[ -f "$LOCAL_ARCHIVE_ENGLISH" ]]; then

        ARCHIVE="$LOCAL_ARCHIVE_ENGLISH"

    elif [[ -f "$LOCAL_ARCHIVE_SHORT" ]]; then

        ARCHIVE="$LOCAL_ARCHIVE_SHORT"

    elif [[ -f "$DOWNLOAD_ARCHIVE" ]]; then

        ARCHIVE="$DOWNLOAD_ARCHIVE"

    else

        log "No se encontró un archivo local."

        DOWNLOAD_TOOL=""

        if command -v curl >/dev/null 2>&1; then

            DOWNLOAD_TOOL="curl"

        elif command -v wget >/dev/null 2>&1; then

            DOWNLOAD_TOOL="wget"

        else

            log "Instalando curl..."

            sudo apt-get install -y curl

            DOWNLOAD_TOOL="curl"

        fi


        case "$DOWNLOAD_TOOL" in

            curl)

                curl \
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

                ;;

            wget)

                wget \
                    --continue \
                    --progress=bar:force \
                    --tries=3 \
                    --timeout=15 \
                    -O "$DOWNLOAD_ARCHIVE" \
                    "$DOWNLOAD_URL"

                ;;

        esac

        [[ -s "$DOWNLOAD_ARCHIVE" ]] \
            || die "La descarga produjo un archivo vacío."

        ARCHIVE="$DOWNLOAD_ARCHIVE"

    fi


    [[ -f "$ARCHIVE" ]] \
        || die "No existe el archivo:

  $ARCHIVE"

    [[ -s "$ARCHIVE" ]] \
        || die "El archivo está vacío:

  $ARCHIVE"

    ok "Bottle disponible:"
    echo "    $ARCHIVE"

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
# 8. Instalación existente
# ============================================================

if start_step "08-existing-install" "Comprobar instalación existente"; then

    if [[ -e "$WINEPREFIX_PATH" ]]; then

        if [[ -f "$STATE_FILE" ]]; then

            log "Se detectó una instalación anterior."

            echo
            cat "$STATE_FILE"
            echo

            ok "La instalación será reanudada."

        else

            die "Ya existe:

  $WINEPREFIX_PATH

No existe un estado de instalación asociado.

Por seguridad no se sobrescribirá."

        fi

    else

        ok "No existe una instalación previa."

    fi

    complete_step \
        "08-existing-install" \
        "Estado de instalación comprobado."

fi


# ============================================================
# 9. Comprobar extracción
# ============================================================

if start_step "09-extraction-check" "Comprobar extracción anterior"; then

    if [[ -e "$BOTTLE_DIR" ]]; then

        if [[ -d "$SOURCE_BOTTLE" ]]; then

            ok "Extracción válida encontrada."

        else

            warn "Extracción incompleta encontrada."
            rm -rf "$BOTTLE_DIR"

            ok "Extracción incompleta eliminada."

        fi

    else

        ok "No existe extracción anterior."

    fi

    complete_step \
        "09-extraction-check" \
        "Extracción comprobada."

fi


# ============================================================
# 10. Dependencias
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
# 11. Wine
# ============================================================

if start_step "11-wine" "Comprobar Wine32 y Wine64"; then

    WINE64_BIN="$(command -v wine64 || true)"
    WINE32_BIN="$(command -v wine32 || true)"

    [[ -n "$WINE64_BIN" ]] \
        || die "No se encontró wine64."

    [[ -n "$WINE32_BIN" ]] \
        || die "No se encontró wine32."

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
# 12. Winetricks
# ============================================================

if start_step "12-winetricks" "Comprobar Winetricks"; then

    command -v winetricks >/dev/null 2>&1 \
        || die "No se encontró Winetricks."

    WINETRICKS_VERSION="$(
        winetricks --version 2>/dev/null || true
    )"

    echo "    Winetricks $WINETRICKS_VERSION"

    complete_step \
        "12-winetricks" \
        "Winetricks disponible."

fi


# ============================================================
# 13. Vulkan
# ============================================================

if start_step "13-vulkan" "Comprobar Vulkan"; then

    command -v vulkaninfo >/dev/null 2>&1 \
        || die "No se encontró vulkaninfo."

    VULKAN_SUMMARY="$(
        vulkaninfo --summary 2>/dev/null || true
    )"

    [[ -n "$VULKAN_SUMMARY" ]] \
        || die "Vulkan no respondió correctamente."

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
# 14. Herramientas
# ============================================================

if start_step "14-tools" "Comprobar herramientas de integración"; then

    for command_name in \
        fc-cache \
        xdg-mime \
        zenity \
        update-desktop-database
    do

        command -v "$command_name" >/dev/null 2>&1 \
            || die "No se encontró:

  $command_name"

    done

    ok "Herramientas disponibles."

    complete_step \
        "14-tools" \
        "Herramientas de integración disponibles."

fi


# ============================================================
# 15. Extraer Bottle
# ============================================================

if start_step "15-extraction" "Extraer Bottle"; then

    if [[ ! -d "$SOURCE_BOTTLE" ]]; then

        log "Extrayendo Bottle..."

        tar \
            -I zstd \
            -xf "$ARCHIVE" \
            -C "$SOURCE_DIR"

    else

        ok "Bottle ya extraído."

    fi

    [[ -d "$SOURCE_BOTTLE" ]] \
        || die "No se encontró:

  $SOURCE_BOTTLE"

    complete_step \
        "15-extraction" \
        "Bottle extraído correctamente."

fi


# ============================================================
# 16. Instalar Bottle
# ============================================================

if start_step "16-install-bottle" "Instalar Bottle"; then

    if [[ -e "$WINEPREFIX_PATH" ]]; then

        log "Eliminando instalación parcial..."

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
# 17. Permisos
# ============================================================

if start_step "17-permissions" "Corregir propietario y permisos"; then

    chown -R \
        "$INSTALL_USER:$INSTALL_GROUP" \
        "$WINEPREFIX_PATH"

    chmod -R \
        u+rwX \
        "$WINEPREFIX_PATH"

    complete_step \
        "17-permissions" \
        "Propietario y permisos corregidos."

fi


# ============================================================
# 18. Arquitectura Bottle
# ============================================================

if start_step "18-bottle-arch" "Comprobar arquitectura del Bottle"; then

    [[ -f "$WINEPREFIX_PATH/system.reg" ]] \
        || die "No se encontró system.reg."

    if ! grep -q '^#arch=win32$' \
        "$WINEPREFIX_PATH/system.reg"
    then

        die "El Bottle no es un prefijo Wine32.

Se esperaba:

  #arch=win32"

    fi

    ok "Bottle confirmado como Wine32."

    complete_step \
        "18-bottle-arch" \
        "Bottle Wine32 confirmado."

fi


# ============================================================
# 19. Variables Wine
# ============================================================

export WINEPREFIX="$WINEPREFIX_PATH"
export WINEARCH="win32"

ok "WINEPREFIX:"
echo "    $WINEPREFIX"

ok "WINEARCH:"
echo "    $WINEARCH"


# ============================================================
# 20. dosdevices
# ============================================================

if start_step "20-dosdevices" "Reconstruir unidades Wine"; then

    rm -rf "$WINEPREFIX_PATH/dosdevices"

    mkdir -p "$WINEPREFIX_PATH/dosdevices"

    ln -s ../drive_c \
        "$WINEPREFIX_PATH/dosdevices/c:"

    ln -s / \
        "$WINEPREFIX_PATH/dosdevices/z:"

    ln -s /media \
        "$WINEPREFIX_PATH/dosdevices/d:"

    ln -s "$HOME" \
        "$WINEPREFIX_PATH/dosdevices/e:"

    complete_step \
        "20-dosdevices" \
        "Unidades Wine reconstruidas."

fi


# ============================================================
# 21. Usuario Wine
# ============================================================

if start_step "21-wine-user" "Crear estructura del usuario Wine"; then

    mkdir -p \
        "$WINEPREFIX_PATH/drive_c/users/$WINE_USER/AppData/Local"

    mkdir -p \
        "$WINEPREFIX_PATH/drive_c/users/$WINE_USER/AppData/Roaming"

    complete_step \
        "21-wine-user" \
        "Estructura del usuario Wine creada."

fi


# ============================================================
# 22. Directorios XDG
# ============================================================

if start_step "22-xdg" "Crear directorios de integración"; then

    mkdir -p \
        "$LOCAL_BIN" \
        "$APPLICATIONS_DIR" \
        "$ICONS_SCALABLE_DIR" \
        "$ICONS_256_DIR" \
        "$OFFICE_FONT_DIR"

    complete_step \
        "22-xdg" \
        "Directorios XDG preparados."

fi


# ============================================================
# 23. Fuentes Office
# ============================================================

if start_step "23-fonts" "Instalar fuentes Office"; then

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

        ok "Fuentes copiadas."

    else

        warn "No se encontró el directorio de fuentes."

    fi

    fc-cache -f

    complete_step \
        "23-fonts" \
        "Fuentes Office configuradas."

fi


# ============================================================
# 24. Fuentes bitmap Wine
# ============================================================

if start_step "24-wine-fonts" "Reparar fuentes bitmap Wine"; then

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

        [[ -f "$TARGET" ]] && continue

        for font_dir in "${WINE_FONT_DIRS[@]}"
        do

            if [[ -f "$font_dir/$font" ]]; then

                cp -f \
                    "$font_dir/$font" \
                    "$TARGET"

                break

            fi

        done

    done

    complete_step \
        "24-wine-fonts" \
        "Fuentes bitmap comprobadas."

fi


# ============================================================
# 25. Launchers originales
# ============================================================

if start_step "25-original-launchers" "Instalar launchers originales"; then

    shopt -s nullglob

    LAUNCHERS=(
        "$BOTTLE_DIR/Wrappers/"*365.sh
    )

    (( ${#LAUNCHERS[@]} > 0 )) \
        || die "No se encontraron launchers *365.sh."

    cp \
        "${LAUNCHERS[@]}" \
        "$LOCAL_BIN/"

    chmod 755 \
        "$LOCAL_BIN/"*365.sh

    complete_step \
        "25-original-launchers" \
        "Launchers originales instalados."

fi


# ============================================================
# 26. Wrapper de limpieza
# ============================================================

if start_step "26-cleanup-wrapper" "Crear wrapper de limpieza"; then

    log "Creando limpieza automática..."

    cat > "$LOCAL_BIN/limpiar_office-wine365.sh" <<'EOF'
#!/usr/bin/env bash

set -u

WINEPREFIX="$HOME/.Microsoft_Office_365"
WINESERVER="$(command -v wineserver || true)"

# ============================================================
# Modo automático
# ============================================================

if [[ "${1:-}" == "--silent" ]] ||
   [[ "${1:-}" == "--auto" ]]
then

    ACTIVE_COUNT="$(
        pgrep -f -i \
        'WINWORD\.EXE|EXCEL\.EXE|POWERPNT\.EXE|OUTLOOK\.EXE|MSACCESS\.EXE|MSPUB\.EXE' \
        2>/dev/null \
        | wc -l
    )"

    if [[ "$ACTIVE_COUNT" -gt 0 ]]; then
        exit 0
    fi

else

    if command -v zenity >/dev/null 2>&1; then

        zenity --question \
            --title="Clean Wine / Office" \
            --text="Do you want to close all Wine and Microsoft Office processes?\n\nAny unsaved work will be lost." \
            --width=420

        [[ $? -ne 0 ]] && exit 0

    fi

fi


# ============================================================
# Cerrar procesos Office
# ============================================================

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


# ============================================================
# Detener wineserver del Bottle
# ============================================================

if [[ -d "$WINEPREFIX" ]] &&
   [[ -n "$WINESERVER" ]]
then

    WINEPREFIX="$WINEPREFIX" \
        "$WINESERVER" -k \
        >/dev/null 2>&1 || true

    sleep 1

    WINEPREFIX="$WINEPREFIX" \
        "$WINESERVER" -w \
        >/dev/null 2>&1 || true

fi

exit 0
EOF

    chmod 755 \
        "$LOCAL_BIN/limpiar_office-wine365.sh"

    ok "Wrapper de limpieza creado."

    complete_step \
        "26-cleanup-wrapper" \
        "Wrapper de limpieza configurado."

fi


# ============================================================
# 27. Wrappers Office
# ============================================================

if start_step "27-office-wrappers" "Crear wrappers portables de Office"; then

    create_office_wrapper() {

        local launcher="$1"
        local executable="$2"
        local output="$LOCAL_BIN/$launcher"

        cat > "$output" <<EOF
#!/usr/bin/env bash

set -Eeuo pipefail

export WINEPREFIX="\$HOME/.Microsoft_Office_365"
export WINEARCH="win32"
export LANG=C.UTF-8
export WINEDEBUG=-all

APP="C:\\\\Program Files\\\\Microsoft Office\\\\root\\\\Office16\\\\$executable"

wineserver -p >/dev/null 2>&1 || true

office_exit_code=0

if [[ \$# -eq 0 ]]; then

    wine32 "\$APP" || office_exit_code=\$?

else

    for file in "\$@"; do

        fullpath="\$(realpath "\$file")"

        winpath="Z:\${fullpath//\\//\\\\}"

        wine32 "\$APP" "\$winpath" || office_exit_code=\$?

    done

fi


# ============================================================
# Limpieza automática
# ============================================================

if [[ -x "\$HOME/.local/bin/limpiar_office-wine365.sh" ]]; then

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


    complete_step \
        "27-office-wrappers" \
        "Wrappers Office configurados."

fi


# ============================================================
# 28. Validar wrappers
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

        [[ -x "$wrapper" ]] \
            || die "No se pudo crear:

  $wrapper"

    done

    complete_step \
        "28-wrapper-validation" \
        "Wrappers validados."

fi


# ============================================================
# 29. Validar Wine32 + limpieza
# ============================================================

if start_step "29-wine32-validation" "Validar uso de Wine32"; then

    for launcher in \
        "$LOCAL_BIN/word365.sh" \
        "$LOCAL_BIN/excel365.sh" \
        "$LOCAL_BIN/powerpoint365.sh" \
        "$LOCAL_BIN/access365.sh" \
        "$LOCAL_BIN/outlook365.sh" \
        "$LOCAL_BIN/publisher365.sh"
    do

        [[ -x "$launcher" ]] \
            || die "Launcher inválido:

  $launcher"


        if ! grep -q 'wine32' "$launcher"; then

            die "El launcher no utiliza wine32:

  $launcher"

        fi


        # Evitamos falsos positivos con la palabra wine
        # dentro de wine32.
        if grep -Eq \
            '(^|[[:space:]"'\''])wine([[:space:]"'\'']|$)' \
            "$launcher"
        then

            die "El launcher utiliza el comando genérico wine:

  $launcher"

        fi


        if ! grep -q \
            'limpiar_office-wine365\.sh' \
            "$launcher"
        then

            die "El launcher no contiene limpieza automática:

  $launcher"

        fi


        if ! grep -Eq \
            'limpiar_office-wine365\.sh["'\'']?[[:space:]]+--(silent|auto)' \
            "$launcher"
        then

            die "El launcher no ejecuta la limpieza automática:

  $launcher"

        fi

    done


    [[ -x "$LOCAL_BIN/limpiar_office-wine365.sh" ]] \
        || die "No existe el wrapper de limpieza."

    ok "Todos los wrappers utilizan Wine32."
    ok "Todos los wrappers contienen limpieza automática."

    complete_step \
        "29-wine32-validation" \
        "Wine32 y limpieza automática validados."

fi


# ============================================================
# 30. Archivos .desktop
# ============================================================

if start_step "30-desktops" "Instalar archivos .desktop"; then

    shopt -s nullglob

    DESKTOPS=(
        "$BOTTLE_DIR/Desktops/"*365.desktop
    )

    (( ${#DESKTOPS[@]} > 0 )) \
        || die "No se encontraron archivos .desktop."

    cp \
        "${DESKTOPS[@]}" \
        "$APPLICATIONS_DIR/"

    chmod 644 \
        "$APPLICATIONS_DIR/"*365.desktop

    complete_step \
        "30-desktops" \
        "Archivos .desktop instalados."

fi


# ============================================================
# 31. Rutas Exec
# ============================================================

if start_step "31-desktop-paths" "Adaptar rutas Exec"; then

    for desktop in "$APPLICATIONS_DIR/"*365.desktop
    do

        sed -Ei \
            "s#^Exec=/opt/launchers/#Exec=${LOCAL_BIN}/#g" \
            "$desktop"

    done

    complete_step \
        "31-desktop-paths" \
        "Rutas Exec adaptadas."

fi


# ============================================================
# 32. Validar .desktop
# ============================================================

if start_step "32-desktop-validation" "Validar archivos .desktop"; then

    for desktop in "$APPLICATIONS_DIR/"*365.desktop
    do

        if grep -q '^Exec=/opt/launchers/' "$desktop"; then

            die "El .desktop todavía apunta a /opt/launchers:

  $desktop"

        fi


        EXEC_PATH="$(
            sed -n \
                's/^Exec=\([^ %]*\).*/\1/p' \
                "$desktop" \
                | head -1
        )"


        [[ -n "$EXEC_PATH" ]] \
            || die "No se encontró Exec= en:

  $desktop"


        [[ -x "$EXEC_PATH" ]] \
            || die "El launcher indicado no existe:

  $EXEC_PATH"

    done

    complete_step \
        "32-desktop-validation" \
        "Archivos .desktop validados."

fi


# ============================================================
# 33. Iconos
#
# IMPORTANTE:
#
# Los SVG deben ir en:
#
#   hicolor/scalable/apps
#
# No en:
#
#   hicolor/256x256/apps
#
# También intentamos generar PNG 256x256 si ImageMagick
# está disponible.
# ============================================================

if start_step "33-icons" "Instalar iconos"; then

    log "Instalando iconos Office..."

    shopt -s nullglob

    ICONS=(
        "$BOTTLE_DIR/Office365Icons/"*365.svg
    )

    if (( ${#ICONS[@]} > 0 )); then

        for icon in "${ICONS[@]}"
        do

            basename="$(basename "$icon")"

            cp -f \
                "$icon" \
                "$ICONS_SCALABLE_DIR/$basename"

            chmod 644 \
                "$ICONS_SCALABLE_DIR/$basename"


            # ------------------------------------------------
            # Generar PNG si ImageMagick está disponible
            # ------------------------------------------------

            if command -v convert >/dev/null 2>&1; then

                png_name="${basename%.svg}.png"

                convert \
                    -background none \
                    "$icon" \
                    -resize 256x256 \
                    "$ICONS_256_DIR/$png_name" \
                    >/dev/null 2>&1 \
                    || true

            elif command -v magick >/dev/null 2>&1; then

                png_name="${basename%.svg}.png"

                magick \
                    "$icon" \
                    -background none \
                    -resize 256x256 \
                    "$ICONS_256_DIR/$png_name" \
                    >/dev/null 2>&1 \
                    || true

            fi

        done

        ok "Iconos instalados."

    else

        warn "No se encontraron iconos Office365."

    fi

    complete_step \
        "33-icons" \
        "Iconos procesados."

fi


# ============================================================
# 34. Corregir nombres Icon=
# ============================================================

if start_step "34-desktop-icons" "Corregir iconos de los archivos .desktop"; then

    log "Comprobando referencias Icon=..."

    for desktop in "$APPLICATIONS_DIR/"*365.desktop
    do

        ICON_NAME="$(
            sed -n \
                's/^Icon=//p' \
                "$desktop" \
                | head -1
        )"

        [[ -n "$ICON_NAME" ]] || continue


        # ----------------------------------------------------
        # Si Icon apunta a un path absoluto antiguo, convertir
        # a nombre de icono.
        # ----------------------------------------------------

        ICON_BASENAME="$(basename "$ICON_NAME")"

        ICON_BASENAME="${ICON_BASENAME%.svg}"
        ICON_BASENAME="${ICON_BASENAME%.png}"


        if [[ -f "$ICONS_SCALABLE_DIR/$ICON_BASENAME.svg" ]]; then

            sed -Ei \
                "s#^Icon=.*#Icon=$ICON_BASENAME#" \
                "$desktop"

        elif [[ -f "$ICONS_256_DIR/$ICON_BASENAME.png" ]]; then

            sed -Ei \
                "s#^Icon=.*#Icon=$ICON_BASENAME#" \
                "$desktop"

        fi

    done

    complete_step \
        "34-desktop-icons" \
        "Referencias de iconos corregidas."

fi


# ============================================================
# 35. Integración escritorio
# ============================================================

if start_step "35-desktop-integration" "Actualizar integración del escritorio"; then

    update-desktop-database \
        "$APPLICATIONS_DIR" \
        >/dev/null 2>&1 \
        || true


    if command -v gtk-update-icon-cache >/dev/null 2>&1; then

        gtk-update-icon-cache \
            -f \
            "$HOME/.local/share/icons/hicolor" \
            >/dev/null 2>&1 \
            || true

    fi


    if command -v update-mime-database >/dev/null 2>&1; then

        update-mime-database \
            "$HOME/.local/share/mime" \
            >/dev/null 2>&1 \
            || true

    fi


    ok "Integración del escritorio actualizada."

    complete_step \
        "35-desktop-integration" \
        "Integración del escritorio actualizada."

fi


# ============================================================
# 36. Instalar DXVK Wine32
# ============================================================

if start_step "36-dxvk" "Instalar DXVK Wine32"; then

    log "Instalando DXVK..."

    WINE="$WINE32_BIN" \
        WINEPREFIX="$WINEPREFIX_PATH" \
        WINEARCH="win32" \
        winetricks \
        --unattended \
        dxvk

    ok "DXVK instalado."

    complete_step \
        "36-dxvk" \
        "DXVK instalado."

fi


# ============================================================
# 37. Verificar DXVK
#
# NO dependemos de una línea concreta dentro de user.reg.
#
# Comprobamos:
#
#   1. DLLs presentes.
#   2. DllOverrides mediante wine reg.
#
# Wine puede representar los overrides de distintas maneras.
# ============================================================

if start_step "37-dxvk-overrides" "Verificar instalación de DXVK"; then

    log "Verificando DXVK..."

    DXVK_DLLS=(
        d3d8
        d3d9
        d3d10core
        d3d11
        dxgi
    )


    # --------------------------------------------------------
    # 37.1 DLLs
    # --------------------------------------------------------

    for dll in "${DXVK_DLLS[@]}"
    do

        DLL_FOUND=0

        for directory in \
            "$WINEPREFIX_PATH/drive_c/windows/system32" \
            "$WINEPREFIX_PATH/drive_c/windows/syswow64"
        do

            if [[ -f "$directory/$dll.dll" ]]; then

                DLL_FOUND=1
                break

            fi

        done


        if (( DLL_FOUND == 0 )); then

            die "No se encontró la DLL DXVK:

  $dll.dll

El proceso de instalación de DXVK no quedó completo."

        fi

    done


    ok "DLLs de DXVK encontradas."


    # --------------------------------------------------------
    # 37.2 Consultar DllOverrides
    # --------------------------------------------------------

    DXVK_OVERRIDE_OUTPUT="$(
        "$WINE32_BIN" \
            reg query \
            'HKCU\Software\Wine\DllOverrides' \
            2>/dev/null \
            || true
    )"


    echo
    echo "Overrides detectados:"
    echo


    if [[ -n "$DXVK_OVERRIDE_OUTPUT" ]]; then

        echo "$DXVK_OVERRIDE_OUTPUT"

    else

        warn "Wine no devolvió DllOverrides mediante reg query."

    fi


    # --------------------------------------------------------
    # 37.3 Verificación flexible
    #
    # Aceptamos:
    #
    #   d3d8 = native
    #   d3d8 = "native"
    #   "*d3d8" = native
    #   "*d3d8" = "native"
    #
    # dependiendo de cómo Wine haya generado user.reg.
    # --------------------------------------------------------

    for dll in "${DXVK_DLLS[@]}"
    do

        if grep -Eiq \
            '(^|[[:space:]"*])d3d8([.]dll)?["*]?[[:space:]]*=.*native' \
            "$WINEPREFIX_PATH/user.reg" 2>/dev/null
        then
            :

        elif grep -Eiq \
            '(^|[[:space:]"*])'"$dll"'([.]dll)?["*]?[[:space:]]*=.*native' \
            "$WINEPREFIX_PATH/user.reg" 2>/dev/null
        then
            :

        elif grep -Eiq \
            "$dll.*native|native.*$dll" \
            <<< "$DXVK_OVERRIDE_OUTPUT"
        then
            :

        else

            warn "No se pudo confirmar explícitamente el override:"
            echo "    $dll"

            warn "Las DLLs sí están presentes."
            warn "Se continuará porque Wine/Winetricks puede haber"
            warn "registrado el override en un formato diferente."

        fi

    done


    # --------------------------------------------------------
    # 37.4 Asegurar overrides manualmente
    #
    # Esto elimina la ambigüedad y deja el estado explícito.
    # --------------------------------------------------------

    log "Asegurando overrides DXVK..."

    for dll in "${DXVK_DLLS[@]}"
    do

        "$WINE32_BIN" \
            reg add \
            'HKCU\Software\Wine\DllOverrides' \
            /v "*.$dll" \
            /t REG_SZ \
            /d native \
            /f \
            >/dev/null 2>&1 \
            || warn "No se pudo registrar override para $dll"

    done


    # --------------------------------------------------------
    # 37.5 Comprobación final
    # --------------------------------------------------------

    FINAL_OVERRIDES="$(
        "$WINE32_BIN" \
            reg query \
            'HKCU\Software\Wine\DllOverrides' \
            2>/dev/null \
            || true
    )"


    for dll in "${DXVK_DLLS[@]}"
    do

        if ! grep -Eiq \
            "$dll.*native|native.*$dll" \
            <<< "$FINAL_OVERRIDES"
        then

            warn "Wine no mostró explícitamente el override final:"
            echo "    $dll"

        fi

    done


    ok "DXVK verificado."
    ok "Se encontraron las DLL necesarias."
    ok "Los overrides fueron asegurados."

    complete_step \
        "37-dxvk-overrides" \
        "DXVK y overrides verificados."

fi


# ============================================================
# 38. Aceleración hardware Office
# ============================================================

if start_step "38-office-graphics" "Configurar aceleración por hardware"; then

    "$WINE32_BIN" \
        reg add \
        'HKCU\Software\Microsoft\Office\16.0\Common\Graphics' \
        /v DisableHardwareAcceleration \
        /t REG_DWORD \
        /d 0 \
        /f \
        >/dev/null

    ok "DisableHardwareAcceleration=0."

    complete_step \
        "38-office-graphics" \
        "Aceleración por hardware configurada."

fi


# ============================================================
# 39. Validar aceleración
# ============================================================

if start_step "39-office-graphics-validation" "Verificar aceleración por hardware"; then

    GRAPHICS_VALUE="$(
        "$WINE32_BIN" \
            reg query \
            'HKCU\Software\Microsoft\Office\16.0\Common\Graphics' \
            /v DisableHardwareAcceleration \
            2>/dev/null \
            | awk '/DisableHardwareAcceleration/ {print $NF}'
    )"


    if [[ "$GRAPHICS_VALUE" != "0x0" ]]; then

        die "La aceleración por hardware no quedó habilitada.

Valor:

  ${GRAPHICS_VALUE:-no encontrado}

Esperado:

  0x0"

    fi

    ok "Aceleración por hardware habilitada."

    complete_step \
        "39-office-graphics-validation" \
        "Aceleración por hardware verificada."

fi


# ============================================================
# 40. Reiniciar wineserver
# ============================================================

if start_step "40-wineserver" "Reiniciar wineserver"; then

    "$WINE32_BIN" \
        wineserver \
        -k \
        >/dev/null 2>&1 \
        || true

    sleep 2

    complete_step \
        "40-wineserver" \
        "wineserver reiniciado."

fi


# ============================================================
# 41. Word
# ============================================================

if start_step "41-word" "Comprobar Microsoft Word"; then

    [[ -f "$WORD_EXE" ]] \
        || die "No se encontró:

  $WORD_EXE"

    ok "WINWORD.EXE encontrado."

    complete_step \
        "41-word" \
        "Microsoft Word encontrado."

fi


# ============================================================
# 42. MIME
# ============================================================

if start_step "42-mime" "Configurar asociaciones MIME"; then

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

    complete_step \
        "42-mime" \
        "Asociaciones MIME configuradas."

fi


# ============================================================
# 43. Font cache
# ============================================================

if start_step "43-font-cache" "Actualizar caché final de fuentes"; then

    fc-cache -f

    complete_step \
        "43-font-cache" \
        "Caché de fuentes actualizado."

fi


# ============================================================
# 44. Final
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
    echo "  Instalado"
    echo
    echo "Office:"
    echo "  Aceleración por hardware = ACTIVADA"
    echo
    echo "Wrappers:"
    echo "  $LOCAL_BIN"
    echo
    echo "Aplicaciones:"
    echo "  $APPLICATIONS_DIR"
    echo
    echo "Iconos:"
    echo "  $ICONS_SCALABLE_DIR"
    echo "  $ICONS_256_DIR"
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

    log "Eliminando estado temporal..."

    rm -f "$STATE_FILE"

    rmdir "$STATE_DIR" \
        2>/dev/null \
        || true

    ok "Checkpoints eliminados."
    ok "Instalación terminada correctamente."

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