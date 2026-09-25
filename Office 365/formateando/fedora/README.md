# Microsoft Office 365 — Bottle preconstruido para Fedora

> Adaptación y validación para Fedora de un método originalmente documentado por **Formateando** para Ubuntu, Linux Mint y Debian.

Este procedimiento documenta la instalación de un **Bottle preconstruido de Microsoft Office 365** en Fedora mediante Wine, utilizando un prefijo Wine32 y DXVK para el renderizado gráfico.

## Fuente original

El procedimiento en el que se basa esta adaptación fue publicado originalmente por el canal de YouTube **Formateando**:

**Formateando**
[Canal de YouTube — Formateando](https://www.youtube.com/@formateando?utm_source=chatgpt.com)

El trabajo original está orientado a entornos basados en **Ubuntu, Linux Mint y Debian**. Esta documentación toma dicho procedimiento como punto de partida y lo **analiza, modifica, adapta y valida específicamente para Fedora**.

> **Crédito:** La existencia y estructura general del método de instalación documentado aquí se basan en el trabajo público de **Formateando**. Las modificaciones, pruebas, correcciones y documentación específicas para Fedora corresponden a este proyecto.

La validación principal de esta adaptación se realizó sobre **Fedora 44**, aunque el procedimiento puede servir como referencia para otras versiones de Fedora que dispongan de las dependencias requeridas.

> **Nota:** Este repositorio no distribuye Microsoft Office ni pretende sustituir sus licencias. El Bottle, instaladores y demás componentes propietarios deben utilizarse de acuerdo con sus respectivas licencias y permisos de distribución.

---

## Estado

| Elemento                           | Estado                     |
| ---------------------------------- | -------------------------- |
| Fedora 44                          | ✅ Validado                 |
| Wine 11.0 Staging                  | ✅ Validado                 |
| Wine32                             | ✅ Validado                 |
| Winetricks 20260125                | ✅ Validado                 |
| DXVK 3.1.1                         | ✅ Validado                 |
| Vulkan 1.4.x                       | ✅ Validado                 |
| Mesa 26.2.3                        | ✅ Validado                 |
| Intel UHD Graphics 620             | ✅ Validado                 |
| Bottle Wine32                      | ✅ Validado                 |
| Microsoft Word                     | ✅ Probado                  |
| Microsoft Excel                    | ✅ Probado                  |
| Microsoft PowerPoint               | ✅ Probado                  |
| Microsoft Outlook                  | ✅ Probado                  |
| Microsoft Access                   | ✅ Probado                  |
| Microsoft Publisher                | ✅ Probado                  |
| Microsoft OneNote                  | ✅ Probado                  |
| Aceleración por hardware de Office | ✅ Habilitada               |
| Integración con menú de Fedora     | ✅ Probada                  |
| Asociaciones MIME                  | ✅ Configuradas             |
| Problemas de fuentes de Word       | ⚠️ Investigación pendiente |

---

# 1. Entorno de validación

La documentación fue desarrollada y probada principalmente sobre:

```text
Fedora 44

Wine 11.0 Staging

Wine32

Winetricks 20260125

DXVK 3.1.1

Mesa 26.2.3

Vulkan 1.4.x

Intel UHD Graphics 620
```

Fedora 44 proporciona los paquetes necesarios para el entorno Wine y Vulkan, incluyendo:

```text
wine.x86_64
wine.i686
wine-winefonts
winetricks
vulkan-loader.x86_64
vulkan-loader.i686
vulkan-tools
```

El Bottle utilizado tiene arquitectura:

```text
#arch=win32
```

Por esta razón, las aplicaciones de Office deben ejecutarse utilizando:

```bash
wine32
```

y no mediante el comando genérico:

```bash
wine
```

Durante la investigación, ejecutar el Bottle con `wine` produjo:

```text
wine: '/home/eduardo/.Microsoft_Office_365' is a 32-bit installation,
it cannot support 64-bit applications.
```

Mientras que `wine32` permitió ejecutar correctamente el mismo prefijo.

---

# 2. Objetivo de la adaptación

El objetivo de esta adaptación es trasladar el procedimiento original de **Formateando** a un entorno Fedora manteniendo el funcionamiento del Bottle, pero corrigiendo las diferencias encontradas entre ambos ecosistemas.

Los principales cambios realizados fueron:

* Instalación de dependencias mediante `dnf`.
* Instalación explícita de Wine x86_64 e i686.
* Uso consistente de `wine32`.
* Validación de la arquitectura `win32` del Bottle.
* Reconstrucción de `dosdevices`.
* Adaptación de los launchers.
* Adaptación de archivos `.desktop`.
* Instalación de fuentes mediante las rutas disponibles en Fedora.
* Instalación y validación de DXVK x32.
* Configuración de overrides de Direct3D.
* Verificación de Vulkan.
* Habilitación de aceleración por hardware de Office.
* Configuración de asociaciones MIME.
* Integración de las aplicaciones con el menú de Fedora.

---

# 3. Arquitectura del procedimiento

El procedimiento completo puede representarse de la siguiente manera:

```text
MSO365-English-.tar.zst

        │

        ├── extracción
        │
        ├── comprobación del sistema
        │
        ├── instalación Wine x86_64 + i686
        │
        ├── instalación Wine fonts
        │
        ├── instalación Vulkan
        │
        ├── instalación Winetricks
        │
        ├── instalación del Bottle
        │
        ├── comprobación #arch=win32
        │
        ├── reconstrucción de dosdevices
        │
        ├── instalación de fuentes
        │
        ├── reparación de fuentes bitmap Wine
        │
        ├── adaptación de launchers
        │       └── wine → wine32
        │
        ├── instalación de .desktop
        │       └── /opt/launchers → ~/.local/bin
        │
        ├── instalación de iconos
        │
        ├── instalación de DXVK x32
        │
        ├── overrides:
        │      d3d8
        │      d3d9
        │      d3d10core
        │      d3d11
        │      dxgi
        │
        ├── aceleración por hardware de Office
        │
        ├── actualización XDG
        │
        ├── asociaciones MIME
        │
        └── prueba final mediante wine32
```

---

# 4. Flujo de ejecución

Una vez instalada la integración con el escritorio, el flujo esperado desde el menú de Fedora es:

```text
Menú de aplicaciones
        ↓
word365.desktop
        ↓
~/.local/bin/word365.sh
        ↓
WINEPREFIX=~/.Microsoft_Office_365
        ↓
wine32
        ↓
WINWORD.EXE
        ↓
DXVK
        ↓
Vulkan
        ↓
Mesa
        ↓
GPU
        ↓
Microsoft Word
```

Durante la adaptación se detectó que tener `wine32` funcionando manualmente no era suficiente.

Los launchers podían funcionar desde la terminal mientras los archivos `.desktop` continuaban apuntando a rutas del Bottle original.

La versión adaptada corrige ambas capas.

---

# 5. Requisitos

Se requiere:

```text
Fedora

Internet

DNF

tar

zstd

Wine

Wine32

Winetricks

Vulkan
```

La validación principal corresponde a:

```text
Fedora 44
```

El archivo del Bottle debe encontrarse junto al instalador:

```text
.
├── MSO365-English-.tar.zst
└── install-office365-fedora.sh
```

El instalador debe ejecutarse como **usuario normal**.

No debe ejecutarse:

```bash
sudo ./install-office365-fedora.sh
```

Debe utilizarse:

```bash
./install-office365-fedora.sh
```

El script utilizará `sudo` únicamente cuando sea necesario para instalar paquetes mediante DNF.

---

# 6. Ubicación del Bottle

La instalación se realiza por usuario.

El Bottle queda ubicado en:

```text
~/.Microsoft_Office_365
```

Por ejemplo:

```text
/home/usuario/.Microsoft_Office_365
```

Esto evita instalar el entorno completo en una ubicación global y permite que cada usuario tenga su propio prefijo.

---

# 7. Instalación de dependencias

En Fedora se utilizan:

```bash
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
```

Después debe comprobarse:

```bash
wine32 --version
```

y:

```bash
vulkaninfo --summary
```

---

# 8. Wine32

El Bottle utilizado por este método contiene:

```text
#arch=win32
```

Por tanto, la ejecución correcta utiliza:

```bash
wine32
```

La configuración utilizada es:

```bash
export WINEPREFIX="$HOME/.Microsoft_Office_365"
export WINEARCH="win32"
```

No se recomienda cambiar este Bottle a un prefijo de otra arquitectura sin volver a validar el procedimiento.

---

# 9. Reconstrucción de `dosdevices`

El Bottle original utiliza las siguientes unidades:

```text
c: → ../drive_c
z: → /
d: → /media
e: → $HOME
```

La instalación recrea:

```text
~/.Microsoft_Office_365/dosdevices/
```

con las correspondientes asignaciones.

### Consideración de seguridad

Las unidades:

```text
z: → /
e: → $HOME
```

proporcionan al entorno Wine acceso amplio al sistema de archivos del sistema anfitrión.

Wine no debe considerarse un sandbox.

Esta configuración se mantiene por compatibilidad con el Bottle y debe tenerse en cuenta antes de ejecutar software no confiable dentro del prefijo.

---

# 10. Fuentes

Las fuentes incluidas en el paquete se instalan en:

```text
~/.local/share/fonts/Office365/
```

Se procesan archivos:

```text
.ttf
.ttc
.otf
```

y posteriormente se actualiza la caché:

```bash
fc-cache -f
```

---

# 11. Fuentes bitmap de Wine

Durante el análisis del Bottle se encontraron referencias a:

```text
coure.fon
sserife.fon
serife.fon
smalle.fon
```

El procedimiento adaptado comprueba las fuentes disponibles en:

```text
/usr/share/wine/fonts/
```

y copia las que estén disponibles hacia:

```text
C:\Windows\Fonts
```

dentro del Bottle.

Esto corrige parte de las diferencias encontradas entre el entorno original y Fedora.

---

# 12. Launchers

Los launchers se instalan en:

```text
~/.local/bin/
```

Entre ellos pueden encontrarse:

```text
word365.sh
excel365.sh
powerpoint365.sh
outlook365.sh
publisher365.sh
access365.sh
limpiar-office-wine365.sh
```

El cambio principal respecto al método original es que los launchers de Office utilizan:

```bash
wine32
```

en lugar de:

```bash
wine
```

La copia original del Bottle no se modifica directamente.

---

# 13. Archivos `.desktop`

El Bottle original utilizaba rutas como:

```text
/opt/launchers/
```

Esto no corresponde a una instalación por usuario.

La adaptación instala los launchers en:

```text
~/.local/bin/
```

y modifica los `.desktop` para utilizar la ruta correspondiente.

El flujo pasa a ser:

```text
.desktop
    ↓
~/.local/bin/word365.sh
    ↓
wine32
    ↓
Office
```

Los `.desktop` instalados se encuentran en:

```text
~/.local/share/applications/
```

---

# 14. Iconos

Los iconos se instalan en:

```text
~/.local/share/icons/hicolor/256x256/apps/
```

Después se actualizan las bases de datos correspondientes para que las aplicaciones puedan aparecer correctamente en el menú del escritorio.

---

# 15. Vulkan

DXVK requiere un entorno Vulkan funcional.

La instalación utiliza:

```bash
vulkaninfo --summary
```

para comprobar que Vulkan esté disponible.

En el entorno utilizado para la validación se detectó:

```text
GPU:

    Intel(R) UHD Graphics 620
```

junto con los controladores Mesa.

También puede aparecer:

```text
llvmpipe
```

como dispositivo de renderizado por software.

La presencia de `llvmpipe` no implica que DXVK esté utilizando necesariamente ese dispositivo; la GPU utilizada debe comprobarse mediante las herramientas disponibles en el sistema.

---

# 16. DXVK

Una de las diferencias fundamentales respecto al procedimiento inicial fue la necesidad de utilizar DXVK.

La configuración final utiliza:

```text
DXVK 3.1.1
```

para el Bottle Wine32.

La instalación se realiza mediante:

```bash
WINE=wine32 \
WINEPREFIX="$HOME/.Microsoft_Office_365" \
WINEARCH=win32 \
winetricks \
--unattended \
dxvk
```

Es importante utilizar:

```text
WINE=wine32
```

porque el Bottle es:

```text
#arch=win32
```

---

# 17. DLL de DXVK

Después de la instalación deben existir las siguientes DLL:

```text
d3d8.dll
d3d9.dll
d3d10core.dll
d3d11.dll
dxgi.dll
```

en:

```text
~/.Microsoft_Office_365/drive_c/windows/system32/
```

Pueden comprobarse mediante:

```bash
ls -lh \
"$HOME/.Microsoft_Office_365/drive_c/windows/system32/" \
{d3d8.dll,d3d9.dll,d3d10core.dll,d3d11.dll,dxgi.dll}
```

---

# 18. Overrides

La configuración final utiliza:

```text
d3d8       = native
d3d9       = native
d3d10core  = native
d3d11      = native
dxgi       = native
```

Pueden comprobarse mediante:

```bash
grep -iE \
'd3d8|d3d9|d3d10core|d3d11|dxgi' \
"$HOME/.Microsoft_Office_365/user.reg"
```

El resultado esperado contiene referencias equivalentes a:

```text
"*d3d8"="native"
"*d3d9"="native"
"*d3d10core"="native"
"*d3d11"="native"
"*dxgi"="native"
```

---

# 19. Problema gráfico encontrado

Durante las pruebas iniciales se observó una diferencia importante entre aplicaciones:

```text
Notepad

    ↓

Wine32

    ↓

Interfaz normal
```

mientras que Word presentaba:

```text
Word
    ↓
WineD3D
    ↓
Interfaz blanca
```

Después de incorporar DXVK:

```text
Word
    ↓
DXVK
    ↓
Vulkan
    ↓
GPU Intel
    ↓
Interfaz funcional
```

La configuración con DXVK permitió posteriormente abrir correctamente las principales aplicaciones encontradas en el Bottle.

---

# 20. Aceleración por hardware de Office

La versión adaptada mantiene habilitada la aceleración por hardware propia de Microsoft Office.

Se configura:

```text
HKCU\Software\Microsoft\Office\16.0\Common\Graphics
```

con:

```text
DisableHardwareAcceleration = 0
```

La configuración se aplica mediante:

```bash
wine32 reg add \
    'HKCU\Software\Microsoft\Office\16.0\Common\Graphics' \
    /v DisableHardwareAcceleration \
    /t REG_DWORD \
    /d 0 \
    /f
```

Posteriormente puede verificarse mediante:

```bash
WINEPREFIX="$HOME/.Microsoft_Office_365" \
wine32 reg query \
'HKCU\Software\Microsoft\Office\16.0\Common\Graphics'
```

El resultado esperado es:

```text
DisableHardwareAcceleration    REG_DWORD    0x0
```

Esto significa que Office no está configurado para deshabilitar su aceleración por hardware.

La configuración final es:

```text
Microsoft Office
       ↓
Hardware Acceleration
       ↓
Direct3D
       ↓
DXVK
       ↓
Vulkan
       ↓
Mesa
       ↓
GPU
```

---

# 21. Asociaciones MIME

La adaptación configura asociaciones para los formatos principales de Office.

Word:

```bash
xdg-mime default \
    word365.desktop \
    application/msword

xdg-mime default \
    word365.desktop \
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
```

Excel:

```bash
xdg-mime default \
    excel365.desktop \
    application/vnd.ms-excel

xdg-mime default \
    excel365.desktop \
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet

xdg-mime default \
    excel365.desktop \
    text/csv
```

PowerPoint:

```bash
xdg-mime default \
    powerpoint365.desktop \
    application/vnd.ms-powerpoint

xdg-mime default \
    powerpoint365.desktop \
    application/vnd.openxmlformats-officedocument.presentationml.presentation
```

Access:

```bash
xdg-mime default \
    access365.desktop \
    application/vnd.ms-access
```

Publisher:

```bash
xdg-mime default \
    publisher365.desktop \
    application/vnd.ms-publisher
```

---

# 22. Prueba manual

Word:

```bash
WINEPREFIX="$HOME/.Microsoft_Office_365" \
WINEARCH=win32 \
wine32 \
"$HOME/.Microsoft_Office_365/drive_c/Program Files/Microsoft Office/root/Office16/WINWORD.EXE"
```

Excel:

```bash
WINEPREFIX="$HOME/.Microsoft_Office_365" \
WINEARCH=win32 \
wine32 \
"$HOME/.Microsoft_Office_365/drive_c/Program Files/Microsoft Office/root/Office16/EXCEL.EXE"
```

PowerPoint:

```bash
WINEPREFIX="$HOME/.Microsoft_Office_365" \
WINEARCH=win32 \
wine32 \
"$HOME/.Microsoft_Office_365/drive_c/Program Files/Microsoft Office/root/Office16/POWERPNT.EXE"
```

Outlook:

```bash
WINEPREFIX="$HOME/.Microsoft_Office_365" \
WINEARCH=win32 \
wine32 \
"$HOME/.Microsoft_Office_365/drive_c/Program Files/Microsoft Office/root/Office16/OUTLOOK.EXE"
```

Access:

```bash
WINEPREFIX="$HOME/.Microsoft_Office_365" \
WINEARCH=win32 \
wine32 \
"$HOME/.Microsoft_Office_365/drive_c/Program Files/Microsoft Office/root/Office16/MSACCESS.EXE"
```

Publisher:

```bash
WINEPREFIX="$HOME/.Microsoft_Office_365" \
WINEARCH=win32 \
wine32 \
"$HOME/.Microsoft_Office_365/drive_c/Program Files/Microsoft Office/root/Office16/MSPUB.EXE"
```

OneNote:

```bash
WINEPREFIX="$HOME/.Microsoft_Office_365" \
WINEARCH=win32 \
wine32 \
"$HOME/.Microsoft_Office_365/drive_c/Program Files/Microsoft Office/root/Office16/ONENOTE.EXE"
```

---

# 23. Prueba desde el menú

Después de completar la instalación, las aplicaciones deben aparecer en el menú del escritorio:

```text
Microsoft Word 365

Microsoft Excel 365

Microsoft PowerPoint 365

Microsoft Outlook 365

Microsoft Access 365

Microsoft Publisher 365

Microsoft OneNote 365
```

El flujo de ejecución debe ser:

```text
Fedora
 ↓
Aplicación del menú
 ↓
.desktop
 ↓
~/.local/bin/*.sh
 ↓
wine32
 ↓
Wine32 Bottle
 ↓
Office
 ↓
DXVK
 ↓
Vulkan
 ↓
GPU
```

---

# 24. Diagnóstico

## Comprobar arquitectura

```bash
grep '^#arch=' \
    "$HOME/.Microsoft_Office_365/system.reg"
```

Debe devolver:

```text
#arch=win32
```

## Comprobar Wine32

```bash
wine32 --version
```

## Comprobar Vulkan

```bash
vulkaninfo --summary
```

## Comprobar DXVK

```bash
ls -lh \
"$HOME/.Microsoft_Office_365/drive_c/windows/system32/" \
{d3d8.dll,d3d9.dll,d3d10core.dll,d3d11.dll,dxgi.dll}
```

## Comprobar overrides

```bash
grep -iE \
'd3d8|d3d9|d3d10core|d3d11|dxgi' \
"$HOME/.Microsoft_Office_365/user.reg"
```

## Comprobar aceleración de Office

```bash
WINEPREFIX="$HOME/.Microsoft_Office_365" \
wine32 reg query \
'HKCU\Software\Microsoft\Office\16.0\Common\Graphics'
```

Debe aparecer:

```text
DisableHardwareAcceleration    REG_DWORD    0x0
```

## Comprobar launchers

```bash
grep -Hn 'wine32' \
"$HOME/.local/bin/"*365.sh
```

Para detectar llamadas al Wine genérico:

```bash
grep -HnE \
'(^|[[:space:]])wine([[:space:]]|$)' \
"$HOME/.local/bin/"*365.sh
```

El último comando no debería encontrar llamadas directas a:

```text
wine
```

## Comprobar `.desktop`

```bash
grep -Hn '^Exec=' \
"$HOME/.local/share/applications/"*365.desktop
```

Comprobar que no permanezcan rutas del Bottle original:

```bash
grep -Hn '/opt/launchers' \
"$HOME/.local/share/applications/"*365.desktop
```

El último comando debería devolver:

```text
ningún resultado
```

---

# 25. Uso de GPU

Para comprobar el entorno Vulkan:

```bash
vulkaninfo --summary
```

Para observar la actividad de la GPU Intel:

```bash
intel_gpu_top
```

Mientras Word, Excel u otra aplicación de Office está ejecutándose, `intel_gpu_top` permite observar la actividad de la GPU.

La actividad de GPU debe interpretarse junto con la configuración de DXVK y Vulkan; la ausencia de actividad en un instante concreto no constituye por sí sola una prueba de que la aceleración esté deshabilitada.

---

# 26. Problema de fuentes pendiente

Durante las pruebas se observó en Word el mensaje:

```text
There is insufficient memory or disk space.

Word cannot display the requested font.
```

El mensaje no se interpretó automáticamente como una falta real de memoria o almacenamiento.

El Bottle contiene aproximadamente:

```text
279 fuentes
```

y Wine puede cargar fuentes como:

```text
Calibri

Tahoma

System
```

También se detectaron referencias a fuentes bitmap que inicialmente no estaban presentes físicamente:

```text
coure.fon
sserife.fon
serife.fon
smalle.fon
```

La adaptación incorpora una comprobación y restauración de las fuentes disponibles de Wine.

Sin embargo, el problema específico de Word relacionado con la selección o renderizado de determinadas fuentes **no se considera completamente resuelto**.

Estado actual:

```text
Interfaz blanca de Word

    ↓

RESUELTO ✅
```

```text
DXVK

    ↓

FUNCIONAL ✅
```

```text
Aceleración de hardware de Office

    ↓

HABILITADA ✅
```

```text
"Word cannot display the requested font"

    ↓

INVESTIGACIÓN PENDIENTE ⚠️
```

---

# 27. Diferencias respecto al método original

Esta versión no es una copia directa del procedimiento original publicado por **Formateando**.

Las principales modificaciones realizadas para Fedora son:

| Componente            | Método original                 | Adaptación Fedora                  |
| --------------------- | ------------------------------- | ---------------------------------- |
| Gestor de paquetes    | APT                             | DNF                                |
| Wine                  | `wine`                          | `wine32`                           |
| Arquitectura          | No validada explícitamente      | `#arch=win32`                      |
| DXVK                  | Instalación genérica            | DXVK x32                           |
| Vulkan                | Dependiente del entorno         | Validado mediante `vulkaninfo`     |
| Launchers             | Rutas originales                | `~/.local/bin`                     |
| `.desktop`            | `/opt/launchers`                | Ruta XDG del usuario               |
| Fuentes               | Entorno Debian/Ubuntu           | Fuentes disponibles en Fedora      |
| Hardware acceleration | `DisableHardwareAcceleration=1` | `DisableHardwareAcceleration=0`    |
| Integración XDG       | Original                        | Adaptada a instalación por usuario |
| Validación            | Dependiente del método original | Pruebas específicas en Fedora 44   |

La tabla anterior distingue entre el procedimiento tomado como referencia y las modificaciones realizadas durante esta adaptación.

---

# 28. Seguridad y procedencia

Este método utiliza un Bottle preconstruido obtenido de un procedimiento de terceros.

Por ello, la documentación de este repositorio **no constituye una certificación de seguridad o integridad del Bottle**.

Durante el análisis pueden encontrarse componentes o modificaciones relacionados con el funcionamiento y activación de Microsoft Office.

El repositorio documenta principalmente:

```text
compatibilidad

reproducibilidad

configuración

adaptación a Fedora

renderizado gráfico

integración con el escritorio
```

y no garantiza:

```text
integridad del Bottle

ausencia de modificaciones

ausencia de malware

validez de una licencia de Office

seguridad del mecanismo de activación
```

Se recomienda revisar cualquier Bottle de terceros antes de ejecutarlo y utilizar entornos aislados cuando se esté investigando software cuya procedencia no haya sido verificada.

---

# 29. Procedencia y créditos

## Método original

**Formateando — instalación de Microsoft Office 365 en Ubuntu, Linux Mint y Debian**

Canal oficial:

[https://www.youtube.com/@formateando](https://www.youtube.com/@formateando?utm_source=chatgpt.com)

El procedimiento original, su investigación y la documentación publicada por **Formateando** constituyen la referencia inicial de esta adaptación.

## Adaptación

**office-linux-lab**

Esta versión fue:

* Analizada.
* Modificada.
* Adaptada a Fedora.
* Probada sobre Fedora 44.
* Ajustada para utilizar Wine32.
* Ajustada para utilizar DXVK x32.
* Integrada con el escritorio y el sistema MIME de Fedora.
* Documentada a partir de las pruebas realizadas en el entorno de validación indicado.

## Atribución

> **Este proyecto reconoce y da crédito a Formateando como autor de la documentación y procedimiento original en el que se basa esta adaptación.**
>
> La adaptación para Fedora, las modificaciones técnicas, las pruebas y la documentación específica de este repositorio corresponden a **office-linux-lab**.

---

# 30. Resultado final

La configuración validada queda:

```text
Fedora 44

    │

    ├── Wine 11.0 Staging
    ├── Wine x86_64
    ├── Wine i686
    ├── Wine32
    │
    ├── Bottle
    │     └── #arch=win32
    │
    ├── Vulkan
    │     └── Mesa
    │
    ├── DXVK 3.1.1 x32
    │     ├── d3d8
    │     ├── d3d9
    │     ├── d3d10core
    │     ├── d3d11
    │     └── dxgi
    │
    ├── Hardware Acceleration
    │     └── DisableHardwareAcceleration=0
    │
    └── Microsoft Office
          ├── Word
          ├── Excel
          ├── PowerPoint
          ├── Outlook
          ├── Access
          ├── Publisher
          └── OneNote
```

La cadena gráfica final es:

```text
Microsoft Office
       ↓
Office Hardware Acceleration
       ↓
Direct3D
       ↓
DXVK 3.1.1
       ↓
Vulkan
       ↓
Mesa
       ↓
GPU
```

Y la cadena de ejecución desde el escritorio:

```text
Fedora Application Menu
       ↓
.desktop
       ↓
~/.local/bin/*.sh
       ↓
wine32
       ↓
Wine32 Bottle
       ↓
Microsoft Office
```

---

## Licencia

La documentación y los scripts originales de este repositorio se distribuyen bajo la licencia indicada en la raíz del proyecto.

Microsoft Office, sus componentes propietarios, marcas, instaladores y demás software de terceros **no forman parte de la licencia de este repositorio** y permanecen sujetos a sus respectivas licencias y condiciones de uso.

## Créditos

Este proyecto está basado en el trabajo público de **Formateando** y reconoce expresamente su autoría sobre el procedimiento original.

**Fuente original:**
[Formateando — Canal de YouTube](https://www.youtube.com/@formateando?utm_source=chatgpt.com)

**Adaptación y validación para Fedora:**
`office-on-linux`

Las modificaciones, pruebas y documentación específicas para Fedora forman parte de esta adaptación.
