#!/usr/bin/env bash

# ============================================================
# Microsoft Office 365 - Bottle preconstruido
#
# Fedora + Wine + Wine32 + DXVK
#
# Instalación por usuario
#
# Validado originalmente sobre:
#
#   Fedora 44
#   Wine 11.0 Staging
#   Winetricks 20260125
#   DXVK 3.1.1
#   Mesa 26.2.3
#   Vulkan 1.4.x
#
# Compatibilidad:
#
#   Este instalador no requiere una versión específica
#   de Fedora.
#
#   Puede utilizarse en versiones de Fedora que dispongan
#   de las dependencias y capacidades necesarias:
#
#     - Wine x86_64
#     - Wine i686 / Wine32
#     - Winetricks
#     - Vulkan x86_64
#     - Vulkan i686
#     - Vulkan funcional
#     - Samba Winbind
#     - Zenity
#     - Fontconfig
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

# Se determinará dinámicamente durante la comprobación del TAR.
ARCHIVE=""

readonly BOTTLE_DIR="$SOURCE_DIR/MSO365-English-"
readonly SOURCE_BOTTLE="$BOTTLE_DIR/.Microsoft_Office_365"

readonly WINEPREFIX_PATH="$HOME/.Microsoft_Office_365"

readonly WINE32_BIN="wine32"

readonly INSTALL_USER="$(id -un)"
readonly INSTALL_GROUP="$(id -gn)"

readonly WINE_USER="crossover"

readonly LOCAL_BIN="$HOME/.local/bin"
readonly APPLICATIONS_DIR="$HOME/.local/share/applications"
readonly ICONS_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
readonly OFFICE_FONT_DIR="$HOME/.local/share/fonts/Office365"

readonly WINE_FONT_DIR="/usr/share/wine/fonts"

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

  ./install-office365-fedora.sh

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

if [[ "${ID:-}" != "fedora" ]]; then
    die "Este instalador está diseñado para Fedora.

Sistema detectado:

  ${PRETTY_NAME:-desconocido}

Este instalador no está diseñado para Debian, Ubuntu, Arch,
openSUSE u otras distribuciones."
fi

FEDORA_VERSION="${VERSION_ID:-unknown}"
FEDORA_NAME="${PRETTY_NAME:-Fedora $FEDORA_VERSION}"

ok "Fedora detectado:"
echo "    $FEDORA_NAME"


# ============================================================
# 3. Comprobar DNF
# ============================================================

log "Comprobando gestor de paquetes..."

command -v dnf >/dev/null 2>&1 \
    || die "No se encontró dnf.

Este instalador requiere el gestor de paquetes DNF de Fedora."

ok "DNF disponible."


# ============================================================
# 4. Comprobar archivo TAR / descargar si es necesario
# ============================================================

log "Buscando archivo de Office..."

# ------------------------------------------------------------
# Prioridad 1:
# MSO365-English-.tar.zst
# ------------------------------------------------------------

if [[ -f "$LOCAL_ARCHIVE_ENGLISH" ]]; then

    ARCHIVE="$LOCAL_ARCHIVE_ENGLISH"

    ok "Archivo local encontrado:"
    echo "    $ARCHIVE"

# ------------------------------------------------------------
# Prioridad 2:
# MSO365-EN.tar.zst
# ------------------------------------------------------------

elif [[ -f "$LOCAL_ARCHIVE_SHORT" ]]; then

    ARCHIVE="$LOCAL_ARCHIVE_SHORT"

    ok "Archivo local encontrado:"
    echo "    $ARCHIVE"

# ------------------------------------------------------------
# Prioridad 3:
# Descargar desde GitHub Releases
# ------------------------------------------------------------

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
        log "Instalando curl mediante DNF..."

        sudo dnf install -y curl

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

    # Evitar reutilizar accidentalmente un archivo incompleto.
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

    esac

    # --------------------------------------------------------
    # Validar descarga
    # --------------------------------------------------------

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


# ============================================================
# 5. No sobrescribir instalaciones existentes
# ============================================================

if [[ -e "$WINEPREFIX_PATH" ]]; then
    die "Ya existe el Bottle:

  $WINEPREFIX_PATH

Por seguridad este instalador no sobrescribe instalaciones
existentes."
fi


# ============================================================
# 6. No sobrescribir extracción existente
# ============================================================

if [[ -e "$BOTTLE_DIR" ]]; then
    die "Ya existe el directorio:

  $BOTTLE_DIR

Elimina o mueve ese directorio antes de continuar."
fi


# ============================================================
# 7. Comprobar tar y zstd
# ============================================================

log "Comprobando herramientas de extracción..."

command -v tar >/dev/null 2>&1 \
    || die "No se encontró tar."

command -v zstd >/dev/null 2>&1 \
    || die "No se encontró zstd."

ok "Herramientas de extracción disponibles."


# ============================================================
# 8. Extraer el Bottle
# ============================================================

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


# ============================================================
# 9. Instalar dependencias Fedora
# ============================================================

log "Instalando dependencias..."

sudo dnf install -y \
    wine.x86_64 \
    wine.i686 \
    winetricks \
    wine-winefonts \
    vulkan-loader.x86_64 \
    vulkan-loader.i686 \
    vulkan-tools \
    samba-winbind \
    samba-winbind-clients \
    zenity

ok "Transacción de dependencias completada."


# ============================================================
# 10. Comprobar Wine32
# ============================================================

log "Comprobando Wine32..."

command -v "$WINE32_BIN" >/dev/null 2>&1 \
    || die "No se encontró wine32.

El sistema Fedora no proporciona un ejecutable wine32
funcional después de instalar Wine.

El Bottle requiere Wine32."

WINE32_VERSION="$(
    "$WINE32_BIN" --version 2>/dev/null || true
)"

[[ -n "$WINE32_VERSION" ]] \
    || die "wine32 no pudo devolver su versión."

echo "    $WINE32_VERSION"

ok "wine32 disponible."


# ============================================================
# 11. Comprobar Winetricks
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
# 12. Comprobar Vulkan
# ============================================================

log "Comprobando Vulkan..."

command -v vulkaninfo >/dev/null 2>&1 \
    || die "No se encontró vulkaninfo.

Instala el paquete vulkan-tools."

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


# ============================================================
# 13. Comprobar herramientas de integración
# ============================================================

log "Comprobando herramientas del sistema..."

REQUIRED_COMMANDS=(
    fc-cache
    xdg-mime
    zenity
)

for command_name in "${REQUIRED_COMMANDS[@]}"
do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        die "No se encontró el comando requerido:

  $command_name

Comprueba las dependencias de Fedora antes de continuar."
    fi
done

ok "Herramientas de integración disponibles."


# ============================================================
# 14. Instalar el Bottle
# ============================================================

log "Copiando Bottle a:

  $WINEPREFIX_PATH"

cp -a \
    "$SOURCE_BOTTLE" \
    "$WINEPREFIX_PATH"

ok "Bottle copiado."


# ============================================================
# 15. Corregir propietario y permisos
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
# 16. Comprobar arquitectura
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
# 17. Configuración explícita Wine32
# ============================================================

export WINEPREFIX="$WINEPREFIX_PATH"
export WINEARCH="win32"

ok "WINEPREFIX y WINEARCH configurados."


# ============================================================
# 18. Reconstruir dosdevices
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
# 19. Crear estructura del usuario Wine
# ============================================================

log "Creando directorios del usuario Wine..."

mkdir -p \
    "$WINEPREFIX_PATH/drive_c/users/$WINE_USER/AppData/Local"

mkdir -p \
    "$WINEPREFIX_PATH/drive_c/users/$WINE_USER/AppData/Roaming"

ok "Estructura del usuario creada."


# ============================================================
# 20. Crear directorios XDG
# ============================================================

log "Creando directorios de integración con Fedora..."

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
# 21. Instalar fuentes de Office
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

Se continuará sin fuentes adicionales del TAR."
fi

fc-cache -f

ok "Caché de fuentes actualizado."


# ============================================================
# 22. Reparar fuentes bitmap Wine
# ============================================================

log "Comprobando fuentes bitmap Wine..."

for font in \
    coure.fon \
    sserife.fon \
    serife.fon \
    smalle.fon
do

    TARGET="$WINEPREFIX_PATH/drive_c/windows/Fonts/$font"
    SOURCE="$WINE_FONT_DIR/$font"

    if [[ -f "$TARGET" ]]; then
        ok "$font ya existe."
        continue
    fi

    if [[ -f "$SOURCE" ]]; then

        cp -f \
            "$SOURCE" \
            "$TARGET"

        ok "$font copiada desde $SOURCE"

    else

        warn "No se encontró $SOURCE"

    fi

done


# ============================================================
# 23. Instalar launchers
# ============================================================

log "Instalando launchers..."

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

ok "Launchers copiados."


# ============================================================
# 24. Adaptar launchers a Wine32
# ============================================================

log "Adaptando launchers para utilizar wine32..."

for launcher in "$LOCAL_BIN/"*365.sh
do

    sed -Ei \
        's/(^|[[:space:];&|()])wine([[:space:]]|$)/\1wine32\2/g' \
        "$launcher"

done

# Asegurar que los launchers tengan permisos de ejecución.
chmod 755 "$LOCAL_BIN/"*365.sh


# ============================================================
# 25. Validar launchers
# ============================================================

log "Validando launchers..."

for launcher in "$LOCAL_BIN/"*365.sh
do

    if grep -En \
        '(^|[[:space:]])wine([[:space:]]|$)' \
        "$launcher" \
        >/dev/null
    then

        die "El launcher todavía contiene una llamada al
comando genérico wine:

  $launcher"

    fi

done

ok "Los launchers de Office utilizan wine32."


# ============================================================
# 26. Instalar archivos .desktop
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
# 27. Corregir rutas Exec de los .desktop
# ============================================================

log "Adaptando archivos .desktop al entorno por usuario..."

for desktop in "$APPLICATIONS_DIR/"*365.desktop
do

    sed -Ei \
        "s#^Exec=/opt/launchers/#Exec=${LOCAL_BIN}/#g" \
        "$desktop"

done


# ============================================================
# 28. Validar archivos .desktop
# ============================================================

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


# ============================================================
# 29. Instalar iconos
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
# 30. Actualizar integración del escritorio
# ============================================================

log "Actualizando bases de datos del escritorio..."

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
# 31. Instalar DXVK x32
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
# 32. Verificar DLL de DXVK
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
# 33. Verificar overrides
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
# 34. Habilitar aceleración por hardware de Office
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
# 35. Verificar aceleración por hardware de Office
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
# 36. Reiniciar wineserver
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
# 37. Comprobar Microsoft Word
# ============================================================

log "Comprobando Microsoft Word..."

if [[ ! -f "$WORD_EXE" ]]; then

    die "No se encontró:

  $WORD_EXE"

fi

ok "WINWORD.EXE encontrado."


# ============================================================
# 38. Asociaciones MIME
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
# 39. Actualizar fontconfig
# ============================================================

log "Actualizando caché final de fuentes..."

fc-cache -f

ok "Caché final actualizado."


# ============================================================
# 40. Estado final
# ============================================================

echo
echo "============================================================"
echo " Microsoft Office 365 - Instalación completada"
echo "============================================================"
echo
echo "Sistema:"
echo "  $FEDORA_NAME"
echo
echo "Archivo utilizado:"
echo "  $ARCHIVE"
echo
echo "Compatibilidad:"
echo "  Fedora verificado por capacidades y dependencias"
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
echo "  Aceleración por hardware = ACTIVADA"
echo "  DisableHardwareAcceleration = 0"
echo
echo "Launchers:"
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
# 41. Prueba opcional de Word
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