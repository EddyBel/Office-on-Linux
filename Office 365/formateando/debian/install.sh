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
#   - Samba Winbind
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

readonly INSTALL_USER="$(id -un)"
readonly INSTALL_GROUP="$(id -gn)"

readonly WINE_USER="crossover"

readonly LOCAL_BIN="$HOME/.local/bin"
readonly APPLICATIONS_DIR="$HOME/.local/share/applications"
readonly ICONS_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
readonly OFFICE_FONT_DIR="$HOME/.local/share/fonts/Office365"

readonly WORD_EXE="$WINEPREFIX_PATH/drive_c/Program Files/Microsoft Office/root/Office16/WINWORD.EXE"


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
# 1. No ejecutar como root
# ============================================================

if [[ "$EUID" -eq 0 ]]; then
    die "No ejecutes este instalador con sudo.

Ejecuta:

  ./install-office365-debian.sh

El instalador solicitará sudo cuando sea necesario."
fi


# ============================================================
# 2. Comprobar sistema operativo
# ============================================================

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


# ============================================================
# 3. Comprobar arquitectura
# ============================================================

log "Comprobando arquitectura..."

MACHINE_ARCH="$(dpkg --print-architecture)"

if [[ "$MACHINE_ARCH" != "amd64" ]]; then
    die "Este Bottle requiere un sistema x86_64 / amd64.

Arquitectura detectada:

  $MACHINE_ARCH"
fi

ok "Arquitectura amd64."


# ============================================================
# 4. Comprobar APT
# ============================================================

log "Comprobando gestor de paquetes..."

command -v apt-get >/dev/null 2>&1 \
    || die "No se encontró apt-get."

command -v dpkg >/dev/null 2>&1 \
    || die "No se encontró dpkg."

ok "APT disponible."


# ============================================================
# 5. Habilitar arquitectura i386
# ============================================================

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


# ============================================================
# 6. Actualizar índices APT
# ============================================================

log "Actualizando índices de paquetes..."

sudo apt-get update

ok "Índices APT actualizados."


# ============================================================
# 7. Comprobar archivo TAR / descargar si es necesario
# ============================================================

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
        log "Instalando curl mediante APT..."

        sudo apt-get install -y curl

        if command -v curl >/dev/null 2>&1; then
            DOWNLOAD_TOOL="curl"
        fi

    fi

    [[ -n "$DOWNLOAD_TOOL" ]] \
        || die "No fue posible encontrar ni instalar una
herramienta de descarga."

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

                die "No fue posible descargar el Bottle."

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

                die "No fue posible descargar el Bottle."

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


# ============================================================
# 8. No sobrescribir instalaciones existentes
# ============================================================

if [[ -e "$WINEPREFIX_PATH" ]]; then

    die "Ya existe el Bottle:

  $WINEPREFIX_PATH

Por seguridad este instalador no sobrescribe instalaciones
existentes."

fi


# ============================================================
# 9. No sobrescribir extracción existente
# ============================================================

if [[ -e "$BOTTLE_DIR" ]]; then

    die "Ya existe el directorio:

  $BOTTLE_DIR

Elimina o mueve ese directorio antes de continuar."

fi


# ============================================================
# 10. Instalar dependencias Debian / Ubuntu
# ============================================================

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

ok "Dependencias instaladas."


# ============================================================
# 11. Comprobar Wine
# ============================================================

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


# ============================================================
# 12. Comprobar Winetricks
# ============================================================

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


# ============================================================
# 13. Comprobar Vulkan
# ============================================================

log "Comprobando Vulkan..."

command -v vulkaninfo >/dev/null 2>&1 \
    || die "No se encontró vulkaninfo."

VULKAN_SUMMARY="$(
    vulkaninfo --summary 2>/dev/null || true
)"

if [[ -z "$VULKAN_SUMMARY" ]]; then

    die "Vulkan no respondió correctamente.

DXVK requiere un controlador Vulkan funcional."

fi

echo "$VULKAN_SUMMARY" \
    | grep -E 'deviceName|driverName|driverInfo' \
    | head -20 \
    || true

ok "Vulkan responde correctamente."


# ============================================================
# 14. Comprobar herramientas de integración
# ============================================================

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


# ============================================================
# 15. Extraer Bottle
# ============================================================

log "Extrayendo Bottle..."

tar \
    -I zstd \
    -xf "$ARCHIVE" \
    -C "$SOURCE_DIR"

[[ -d "$SOURCE_BOTTLE" ]] \
    || die "No se encontró el Bottle esperado:

  $SOURCE_BOTTLE"

ok "Bottle extraído correctamente."


# ============================================================
# 16. Instalar Bottle
# ============================================================

log "Copiando Bottle a:

  $WINEPREFIX_PATH"

cp -a \
    "$SOURCE_BOTTLE" \
    "$WINEPREFIX_PATH"

ok "Bottle copiado."


# ============================================================
# 17. Corregir propietario y permisos
# ============================================================

log "Corrigiendo propietario y permisos..."

chown -R \
    "$INSTALL_USER:$INSTALL_GROUP" \
    "$WINEPREFIX_PATH"

chmod -R \
    u+rwX \
    "$WINEPREFIX_PATH"

ok "Propietario y permisos corregidos."


# ============================================================
# 18. Comprobar arquitectura del Bottle
# ============================================================

log "Comprobando arquitectura del Bottle..."

if ! grep -q '^#arch=win32$' \
    "$WINEPREFIX_PATH/system.reg"
then

    die "El Bottle no es un prefijo Wine32 reconocido.

Se esperaba:

  #arch=win32"

fi

ok "Bottle confirmado como Wine32 puro."


# ============================================================
# 19. Configuración Wine32
# ============================================================

export WINEPREFIX="$WINEPREFIX_PATH"
export WINEARCH="win32"

ok "WINEPREFIX y WINEARCH configurados."


# ============================================================
# 20. Reconstruir dosdevices
# ============================================================

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


# ============================================================
# 21. Crear estructura del usuario Wine
# ============================================================

log "Creando directorios del usuario Wine..."

mkdir -p \
    "$WINEPREFIX_PATH/drive_c/users/$WINE_USER/AppData/Local"

mkdir -p \
    "$WINEPREFIX_PATH/drive_c/users/$WINE_USER/AppData/Roaming"

ok "Estructura del usuario creada."


# ============================================================
# 22. Crear directorios XDG
# ============================================================

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


# ============================================================
# 23. Instalar fuentes Office
# ============================================================

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


# ============================================================
# 24. Reparar fuentes bitmap Wine
# ============================================================

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


# ============================================================
# 25. Instalar launchers originales
# ============================================================

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


# ============================================================
# 26. Reemplazar wrappers por wrappers portables
# ============================================================

log "Configurando wrappers portables para esta instalación..."


# ------------------------------------------------------------
# Wrapper de limpieza
# ------------------------------------------------------------

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


# ------------------------------------------------------------
# Función para crear launchers Office
# ------------------------------------------------------------

create_office_wrapper() {

    local launcher="$1"
    local executable="$2"
    local output="$LOCAL_BIN/$launcher"

    cat > "$output" <<EOF
#!/bin/bash
set -e

export WINEPREFIX="\$HOME/.Microsoft_Office_365"
export LANG=C.UTF-8
export WINEDEBUG=-all

app="C:\\\\Program Files\\\\Microsoft Office\\\\root\\\\Office16\\\\$executable"

wineserver -p >/dev/null 2>&1 || true

if [ \$# -eq 0 ]; then

    wine32 "\$app"

else

    for file in "\$@"; do

        fullpath=\$(realpath "\$file")
        winpath="Z:\${fullpath//\\//\\\\}"

        wine32 "\$app" "\$winpath"

    done

fi

if [ -f "\$HOME/.local/bin/limpiar_office-wine365.sh" ]; then

    "\$HOME/.local/bin/limpiar_office-wine365.sh" --silent &

fi
EOF

    chmod 755 "$output"
}


# ============================================================
# 27. Crear los seis wrappers
# ============================================================

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


# ============================================================
# 28. Verificar wrappers
# ============================================================

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


# ============================================================
# 29. Validar wrappers
# ============================================================

log "Validando wrappers..."

for launcher in \
    "$LOCAL_BIN/word365.sh" \
    "$LOCAL_BIN/excel365.sh" \
    "$LOCAL_BIN/powerpoint365.sh" \
    "$LOCAL_BIN/access365.sh" \
    "$LOCAL_BIN/outlook365.sh" \
    "$LOCAL_BIN/publisher365.sh"
do

    if ! grep -q 'wine32' "$launcher"; then

        die "El launcher no contiene wine32:

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
        'limpiar_office-wine365.sh --silent' \
        "$launcher"
    then

        die "El launcher no contiene la limpieza automática:

  $launcher"

    fi

done

ok "Todos los wrappers utilizan wine32."


# ============================================================
# 30. Instalar archivos .desktop
# ============================================================

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


# ============================================================
# 31. Corregir rutas Exec
# ============================================================

log "Adaptando archivos .desktop..."

for desktop in "$APPLICATIONS_DIR/"*365.desktop
do

    sed -Ei \
        "s#^Exec=/opt/launchers/#Exec=${LOCAL_BIN}/#g" \
        "$desktop"

done


# ============================================================
# 32. Validar archivos .desktop
# ============================================================

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


# ============================================================
# 33. Instalar iconos
# ============================================================

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


# ============================================================
# 34. Actualizar integración del escritorio
# ============================================================

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


# ============================================================
# 35. Instalar DXVK x32
# ============================================================

log "Instalando DXVK para el Bottle Wine32..."

WINE="$WINE32_BIN" \
    WINEPREFIX="$WINEPREFIX_PATH" \
    WINEARCH="win32" \
    winetricks \
    --unattended \
    dxvk

ok "DXVK instalado."


# ============================================================
# 36. Verificar DLL de DXVK
# ============================================================

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


# ============================================================
# 37. Verificar overrides
# ============================================================

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


# ============================================================
# 38. Habilitar aceleración por hardware de Office
# ============================================================

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


# ============================================================
# 39. Verificar aceleración por hardware
# ============================================================

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


# ============================================================
# 40. Reiniciar wineserver
# ============================================================

log "Reiniciando wineserver..."

"$WINE32_BIN" \
    wineserver \
    -k \
    >/dev/null 2>&1 \
    || true

sleep 2

ok "wineserver reiniciado."


# ============================================================
# 41. Comprobar Microsoft Word
# ============================================================

log "Comprobando Microsoft Word..."

if [[ ! -f "$WORD_EXE" ]]; then

    die "No se encontró:

  $WORD_EXE"

fi

ok "WINWORD.EXE encontrado."


# ============================================================
# 42. Asociaciones MIME
# ============================================================

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


# ============================================================
# 43. Actualizar fontconfig
# ============================================================

log "Actualizando caché final de fuentes..."

fc-cache -f

ok "Caché final actualizado."


# ============================================================
# 44. Estado final
# ============================================================

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


# ============================================================
# 45. Prueba opcional de Word
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