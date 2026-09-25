# Diagnóstico y reparación de la interfaz gráfica mediante DXVK

## 1. Alcance

Durante el análisis dinámico del Bottle `MSO365-English-`, Microsoft Word consiguió iniciar mediante `wine32`, pero su interfaz gráfica no se renderizaba correctamente.

El síntoma inicial fue:

```text
WINWORD.EXE
    ↓
El proceso inicia
    ↓
Se crea la ventana
    ↓
La ventana aparece completamente blanca
    ↓
Word muestra:

"There is insufficient memory or disk space.
Word cannot display the requested font."
```

La prueba se realizó en una máquina de laboratorio con:

```text
Fedora 44
Wine 11.0 Staging
Wine32
Bottle #arch=win32
```

El objetivo de esta etapa fue determinar si el problema estaba relacionado con:

* aceleración gráfica de Microsoft Office;
* fuentes;
* GDI/Wine;
* Wayland;
* WineD3D;
* Direct3D/DXGI;
* o el backend gráfico utilizado por Wine.

Finalmente se realizó una comparación entre el estado original y el mismo Bottle utilizando DXVK.

> **Alcance:** esta etapa documenta el diagnóstico y la reparación de la interfaz gráfica. No constituye una auditoría completa de seguridad ni analiza nuevamente el subsistema de licenciamiento.

---

# 2. Condiciones iniciales

La sesión gráfica del laboratorio utilizaba Wayland:

```bash
echo "XDG_SESSION_TYPE=$XDG_SESSION_TYPE"
echo "DISPLAY=$DISPLAY"
echo "WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
```

Resultado:

```text
XDG_SESSION_TYPE=wayland
DISPLAY=:0
WAYLAND_DISPLAY=wayland-1
```

La máquina virtual disponía de una GPU Intel UHD Graphics 620 expuesta mediante Vulkan.

La información relevante de:

```bash
vulkaninfo --summary 2>/dev/null | head -80
```

incluyó:

```text
Vulkan Instance Version: 1.4.341

GPU0:
    apiVersion         = 1.4.354
    driverVersion      = 26.2.3
    vendorID            = 0x8086
    deviceID            = 0x5917
    deviceType         = PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU
    deviceName         = Intel(R) UHD Graphics 620 (KBL GT2)
    driverID            = DRIVER_ID_INTEL_OPEN_SOURCE_MESA
    driverName          = Intel open-source Mesa driver
    driverInfo          = Mesa 26.2.3
```

También apareció:

```text
GPU1:
    deviceType         = PHYSICAL_DEVICE_TYPE_CPU
    deviceName         = llvmpipe (LLVM 22.1.8, 256 bits)
    driverID            = DRIVER_ID_MESA_LLVMPIPE
```

Por tanto, la máquina disponía tanto de un dispositivo Intel real expuesto a la VM como de un renderizador de software Mesa.

La presencia de `llvmpipe` no implica que Word estuviera utilizándolo; únicamente indica que estaba disponible como dispositivo Vulkan.

---

# 3. Síntoma inicial

El Bottle:

```text
~/.Microsoft_Office_365
```

era un prefix `win32`.

Microsoft Word iniciaba mediante:

```bash
WINEPREFIX="$HOME/.Microsoft_Office_365" \
wine32 \
"$HOME/.Microsoft_Office_365/drive_c/Program Files/Microsoft Office/root/Office16/WINWORD.EXE"
```

Sin embargo, la interfaz aparecía completamente blanca.

Word mostraba además:

```text
There is insufficient memory or disk space.
Word cannot display the requested font.
```

El problema no impedía completamente la creación del proceso, pero sí impedía obtener una interfaz gráfica utilizable.

---

# 4. Primera hipótesis: aceleración gráfica de Office

Como primer experimento se modificó la configuración de gráficos de Microsoft Office:

```text
HKCU\Software\Microsoft\Office\16.0\Common\Graphics
    DisableHardwareAcceleration = 1
```

Se verificó mediante:

```bash
WINEPREFIX="$HOME/.Microsoft_Office_365" \
wine32 reg query \
'HKCU\Software\Microsoft\Office\16.0\Common\Graphics'
```

Resultado:

```text
HKEY_CURRENT_USER\Software\Microsoft\Office\16.0\Common\Graphics
    DisableHardwareAcceleration    REG_DWORD    0x1
```

Posteriormente se volvió a ejecutar Word:

```bash
WINEPREFIX="$HOME/.Microsoft_Office_365" \
WINEDEBUG=-all \
wine32 \
"$HOME/.Microsoft_Office_365/drive_c/Program Files/Microsoft Office/root/Office16/WINWORD.EXE"
```

El comportamiento no cambió:

```text
DisableHardwareAcceleration = 1
        ↓
Word continúa con interfaz blanca
        ↓
Error de fuente continúa presente
```

### Resultado

La desactivación de la aceleración gráfica de Office no solucionó el problema.

Esto no descarta que la configuración gráfica de Office participe en el comportamiento, pero demuestra que modificar únicamente esta opción no era suficiente para restaurar la interfaz.

---

# 5. Segunda hipótesis: ausencia o corrupción de fuentes

Debido al mensaje:

```text
Word cannot display the requested font
```

se investigó el contenido del directorio de fuentes del Bottle.

```bash
PREFIX="$HOME/.Microsoft_Office_365"

echo "=== Fonts dir ==="
ls -ld "$PREFIX/drive_c/windows/Fonts"

echo
echo "=== Font files ==="
find "$PREFIX/drive_c/windows/Fonts" -maxdepth 1 -type f \
  \( -iname '*.ttf' -o -iname '*.ttc' -o -iname '*.otf' -o -iname '*.fon' \) \
  | wc -l
```

Resultado:

```text
=== Fonts dir ===
drwxr-xr-x@ - eduardo  7 feb 23:57  /home/eduardo/.Microsoft_Office_365/drive_c/windows/Fonts

=== Font files ===
279
```

El Bottle contenía, por tanto, una cantidad considerable de fuentes.

Entre los archivos encontrados estaban:

```text
WINGDNG2.TTF
CONSOLAZ.TTF
CALISTB.TTF
andalemo.ttf
webdings.ttf
CONSTAN.TTF
HTOWERT.TTF
georgiab.ttf
seguisli.ttf
impact.ttf
ELEPHNTI.TTF
PAPYRUS.TTF
TEMPSITC.TTF
timesbi.ttf
times.ttf
DUBAI-REGULAR.TTF
BROADW.TTF
KUNSTLER.TTF
TCBI____.TTF
MSUIGHUB.TTF
SCHLBKI.TTF
seguihis.ttf
CENTURY.TTF
BOD_CB.TTF
FRABKIT.TTF
CAMBRIAB.TTF
arial.ttf
SCHLBKBI.TTF
```

Esto permitió descartar la hipótesis de que el Bottle simplemente careciera de fuentes.

---

# 6. Registro de fuentes de Windows

Se consultó:

```bash
WINEPREFIX="$HOME/.Microsoft_Office_365" \
wine32 reg query \
'HKLM\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
```

El registro contenía numerosas entradas.

Entre las familias principales se encontraban:

```text
Arial
Calibri
Calibri Light
Cambria
Segoe UI
Times New Roman
Tahoma
Trebuchet MS
Verdana
Courier New
```

Ejemplos:

```text
CALIBRI (TrueType)       REG_SZ    CALIBRI.TTF
Calibri Light (TrueType) REG_SZ    CalibriL.ttf
CAMBRIAB (TrueType)      REG_SZ    CAMBRIAB.TTF
CAMBRIAI (TrueType)      REG_SZ    CAMBRIAI.TTF
CAMBRIAZ (TrueType)      REG_SZ    CAMBRIAZ.TTF
Segoe UI                 REG_SZ    segoeui.ttf
Arial                    REG_SZ    arial.ttf
Times New Roman          REG_SZ    times.ttf
Tahoma                   REG_SZ    tahoma.ttf
```

Por tanto, tanto los archivos físicos como el registro del Bottle contenían las principales familias esperadas.

---

# 7. Corrección de una comprobación sensible a mayúsculas

Una comprobación inicial mediante:

```bash
test -f "$PREFIX/drive_c/windows/Fonts/$f"
```

produjo algunos falsos negativos:

```text
[MISSING] ARIAL.TTF
[MISSING] SEGOEUI.TTF
[MISSING] CAMBRIA.TTF
```

Posteriormente se comprobó que los archivos sí existían, pero utilizando una capitalización diferente:

```text
arial.ttf
segoeui.ttf
CAMBRIAB.TTF
```

Por este motivo se repitió la búsqueda utilizando `find` con `-iname`:

```bash
find "$FONTDIR" -maxdepth 1 -type f -iname "$pattern"
```

Para las familias relevantes se encontraron, entre otros:

```text
=== calibri* ===
CALIBRIB.TTF
CALIBRII.TTF
CalibriLI.ttf
CalibriL.ttf
CALIBRI.TTF
CALIBRIZ.TTF
```

```text
=== cambria* ===
CAMBRIAB.TTF
CAMBRIAI.TTF
CAMBRIAZ.TTF
```

```text
=== segoeui* ===
segoeuib.ttf
segoeuii.ttf
segoeuil.ttf
segoeuisl.ttf
SEGOEUISL.TTF
segoeui.ttf
segoeuiz.ttf
```

```text
=== arial* ===
arialbd.ttf
arialbi.ttf
ariali.ttf
ARIALNBI.TTF
ARIALNB.TTF
ARIALNI.TTF
ARIALN.TTF
arial.ttf
```

La familia:

```text
Aptos
```

no estaba presente.

La ausencia de Aptos se registró como una anomalía, pero no existía evidencia suficiente para considerarla la causa principal de la pantalla blanca.

---

# 8. Resolución mediante fontconfig

Se utilizó `fc-match` para comprobar cómo resolvía el sistema distintas familias:

```bash
for font in \
  Calibri \
  "Calibri Light" \
  "Calibri Bold" \
  Cambria \
  "Cambria Bold" \
  "Segoe UI" \
  Arial \
  "Times New Roman" \
  Aptos
do
    echo
    echo "=== $font ==="
    fc-match --format='family=%{family}\nstyle=%{style}\nfile=%{file}\n' "$font"
done
```

Algunos resultados fueron:

```text
=== Calibri ===
family=Calibri
style=Regular
file=/home/eduardo/.local/share/fonts/Office365/CALIBRI.TTF
```

```text
=== Segoe UI ===
family=Segoe UI
style=Regular,...
file=/home/eduardo/.local/share/fonts/Office365/segoeui.ttf
```

```text
=== Arial ===
family=Arial
style=Regular,...
file=/home/eduardo/.local/share/fonts/Office365/arial.ttf
```

```text
=== Times New Roman ===
family=Times New Roman
style=Regular,...
file=/home/eduardo/.local/share/fonts/Office365/times.ttf
```

Algunas variantes, como `Calibri Light`, `Calibri Bold`, `Cambria Bold` y `Aptos`, fueron resueltas por fontconfig hacia `Noto Sans`.

Esto demuestra que la resolución tipográfica no era completamente idéntica a un entorno Windows nativo, pero tampoco proporcionó evidencia suficiente para explicar por sí sola la interfaz completamente blanca.

---

# 9. Prueba directa del subsistema de fuentes de Wine

Se inició Word con depuración de fuentes:

```bash
rm -f /tmp/word-font.log

WINEPREFIX="$HOME/.Microsoft_Office_365" \
WINEDEBUG=+font,-fixme \
wine32 \
"$HOME/.Microsoft_Office_365/drive_c/Program Files/Microsoft Office/root/Office16/WINWORD.EXE" \
/a > /tmp/word-font.log 2>&1
```

Después se filtró:

```bash
grep -iE \
'font|freetype|not found|failed|missing|error' \
/tmp/word-font.log | tail -200
```

Entre las operaciones observadas aparecieron solicitudes de:

```text
System
Calibri
Tahoma
```

Por ejemplo:

```text
trace:font:NtGdiHfontCreate (...) L"Calibri" ... => 0x4a0a0128
trace:font:font_SelectFont L"Calibri" ...
```

y:

```text
trace:font:NtGdiHfontCreate (...) L"Tahoma" ...
trace:font:font_SelectFont L"Tahoma" ...
```

Esto confirmó que Wine estaba creando y seleccionando objetos GDI asociados con fuentes reales.

Por tanto:

```text
Subsistema de fuentes de Wine
        ↓
funcional
```

El mensaje de Word no podía atribuirse simplemente a una incapacidad general de Wine para cargar fuentes.

---

# 10. Prueba de Word en modo `/a`

Word también fue iniciado con:

```bash
WINEPREFIX="$HOME/.Microsoft_Office_365" \
WINEDEBUG=-all \
wine32 \
"$HOME/.Microsoft_Office_365/drive_c/Program Files/Microsoft Office/root/Office16/WINWORD.EXE" \
/a
```

El problema permaneció:

```text
There is insufficient memory or disk space.
Word cannot display the requested font.
```

y la ventana continuó completamente blanca.

La reproducción del problema utilizando `/a` permitió descartar como causa principal varios elementos habituales del perfil de Word, como configuraciones normales y complementos cargados durante un inicio convencional.

---

# 11. Referencias de fuentes rotas

Se exportó el registro de fuentes:

```bash
PREFIX="$HOME/.Microsoft_Office_365"

WINEPREFIX="$PREFIX" wine32 reg query \
'HKLM\Software\Microsoft\Windows NT\CurrentVersion\Fonts' \
> /tmp/wine-font-registry.txt 2>/dev/null
```

Posteriormente se comprobaron físicamente las referencias.

Se encontraron cuatro referencias registradas cuyos archivos no estaban presentes:

```text
Courier        REG_SZ    coure.fon
MS Sans Serif  REG_SZ    sserife.fon
MS Serif       REG_SZ    serife.fon
Small Fonts    REG_SZ    smalle.fon
```

Estas corresponden a fuentes bitmap antiguas de Windows.

El hallazgo demuestra que existen referencias tipográficas incompletas dentro del Bottle, pero no establece que estas cuatro fuentes sean responsables del fallo gráfico de Word.

---

# 12. Prueba comparativa con Notepad

Para determinar si el problema era general de Wine se ejecutó Notepad utilizando exactamente el mismo prefix y loader:

```bash
WINEPREFIX="$HOME/.Microsoft_Office_365" \
WINEDEBUG=-all \
wine32 notepad.exe
```

Notepad abrió y renderizó su ventana correctamente.

Esto permitió establecer una separación importante:

```text
Mismo Bottle
      │
      ├── Wine32                 → funciona
      ├── ventanas Win32         → funcionan
      ├── GDI                    → funciona
      ├── fuentes básicas       → funcionan
      └── Notepad               → funciona
       
      Microsoft Word            → interfaz blanca
```

Por tanto, el problema no correspondía a un fallo general de:

```text
Wine32
GDI
creación de ventanas
```

ni a una ausencia global de fuentes.

---

# 13. Prueba de Wayland

Debido a que la sesión utilizaba Wayland, se probó impedir explícitamente el driver Wayland de Wine:

```bash
WINEPREFIX="$HOME/.Microsoft_Office_365" \
WINEDLLOVERRIDES="winewayland.drv=" \
WINEDEBUG=-all \
wine32 \
"$HOME/.Microsoft_Office_365/drive_c/Program Files/Microsoft Office/root/Office16/WINWORD.EXE" \
/a
```

El resultado no cambió:

```text
Word
    ↓
error de fuente
    ↓
interfaz blanca
```

También se consideró utilizar únicamente `DISPLAY=:0` sin `WAYLAND_DISPLAY`, pero el comportamiento permaneció.

Por tanto, el driver Wayland no pudo identificarse como la causa principal del problema.

---

# 14. Investigación de Direct3D y DXGI

Después de descartar las hipótesis anteriores, la investigación se concentró en el renderizado de Office.

Word fue ejecutado con depuración específica:

```bash
WINEPREFIX="$HOME/.Microsoft_Office_365" \
WINEDEBUG=+d3d11,+dxgi,+d2d,+dcomp,-fixme-all \
wine32 \
"$HOME/.Microsoft_Office_365/drive_c/Program Files/Microsoft Office/root/Office16/WINWORD.EXE" \
/a > /tmp/word-d3d.log 2>&1
```

La salida fue analizada mediante:

```bash
grep -iE \
'err:|failed|not implemented|stub|shared|handle|swap|surface|device|composition|dcomp|d3d11|dxgi' \
/tmp/word-d3d.log | tail -250
```

Se observó actividad considerable en:

```text
DXGI
D3D11
D2D
DComp
```

Entre las secuencias repetidas apareció:

```text
trace:dxgi:dxgi_device_Release ...
```

junto con:

```text
trace:d3d11:d3d10_device_GetDeviceRemovedReason ...
```

La presencia de estas llamadas no demuestra por sí misma que hubiese ocurrido una pérdida real del dispositivo gráfico.

Sin embargo, confirmó que Word estaba utilizando intensivamente la ruta D3D11/DXGI y proporcionó una base para investigar el backend de renderizado.

---

# 15. Verificación de Vulkan

Antes de introducir un backend gráfico alternativo se verificó nuevamente el soporte Vulkan:

```bash
vulkaninfo --summary 2>/dev/null | head -80
```

La VM mostraba:

```text
Intel(R) UHD Graphics 620 (KBL GT2)
```

mediante:

```text
Intel open-source Mesa driver
Mesa 26.2.3
```

con soporte de:

```text
Vulkan 1.4.x
```

Por tanto, la máquina disponía del backend gráfico requerido para probar DXVK.

---

# 16. Copia de seguridad del Bottle

Antes de modificar las DLL gráficas se creó una copia completa del prefix:

```bash
cp -a --reflink=auto \
  "$HOME/.Microsoft_Office_365" \
  "$HOME/.Microsoft_Office_365.pre-dxvk"
```

La copia permitió mantener un estado de referencia para comparaciones posteriores.

Estado:

```text
Bottle original
    ↓
~/.Microsoft_Office_365.pre-dxvk
```

Bottle utilizado para la prueba:

```text
~/.Microsoft_Office_365
```

---

# 17. Primer intento de instalación de DXVK

Inicialmente se ejecutó:

```bash
WINEPREFIX="$HOME/.Microsoft_Office_365" \
winetricks dxvk
```

Winetricks intentó utilizar la ruta de Wine genérica y se encontró nuevamente con:

```text
wine: '/home/eduardo/.Microsoft_Office_365' is a 32-bit installation,
it cannot support 64-bit applications.
```

La instalación no era adecuada para este prefix porque el Bottle era estrictamente `win32` mientras el comando genérico estaba entrando por la ruta de Wine utilizada para el entorno WoW64.

---

# 18. Instalación correcta de DXVK para Wine32

Se repitió la instalación especificando explícitamente el loader:

```bash
WINEPREFIX="$HOME/.Microsoft_Office_365" \
WINE=wine32 \
winetricks dxvk
```

Winetricks identificó:

```text
winetricks 20260125
wine-11.0 (Staging)
WINEARCH=win32
```

La versión de DXVK descargada fue:

```text
dxvk-3.1.1.tar.gz
```

Tamaño observado:

```text
17.20M
```

Se instalaron las variantes x32:

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

El procedimiento registrado por Winetricks incluyó la colocación de:

```text
x32/dxgi.dll
x32/d3d8.dll
x32/d3d9.dll
x32/d3d10core.dll
x32/d3d11.dll
```

---

# 19. Verificación física de DXVK

Se comprobó el contenido del prefix:

```bash
find "$HOME/.Microsoft_Office_365/drive_c/windows/system32" \
  -maxdepth 1 -type f \
  \( -iname 'd3d11.dll' -o -iname 'dxgi.dll' -o -iname 'd3d10core.dll' \) \
  -printf '%f\n' | sort
```

Resultado:

```text
d3d10core.dll
d3d11.dll
dxgi.dll
```

Las DLL estaban físicamente presentes.

El resto de las DLL de DXVK instaladas correspondían a:

```text
d3d8.dll
d3d9.dll
```

---

# 20. Verificación de overrides

Se inspeccionó el registro del prefix:

```bash
grep -iE 'd3d11|dxgi|d3d10core' \
"$HOME/.Microsoft_Office_365/user.reg"
```

Se encontraron:

```text
"*d3d10core"="native"
"*d3d11"="native"
"*dxgi"="native"
```

Winetricks también había registrado overrides nativos para:

```text
dxgi
d3d8
d3d9
d3d10core
d3d11
```

Esto significa que Wine debía seleccionar las DLL nativas instaladas en el prefix en lugar de sus implementaciones integradas correspondientes.

---

# 21. Particularidad de `winecfg`

Al intentar ejecutar:

```bash
WINEPREFIX="$HOME/.Microsoft_Office_365" \
WINE=wine32 \
winecfg
```

se obtuvo nuevamente:

```text
wine: '/home/eduardo/.Microsoft_Office_365'
is a 32-bit installation,
it cannot support 64-bit applications.
```

Esto volvió a demostrar la particularidad de esta instalación:

```text
Bottle             = win32
Wine global        = entorno WoW64
wine               = no adecuado para este prefix
wine32             = loader utilizado para el prefix
```

A partir de este punto, las pruebas continuaron utilizando explícitamente:

```text
wine32
```

cuando se necesitaba ejecutar programas del Bottle.

---

# 22. Reinicio del wineserver

Antes de repetir la prueba se finalizó la instancia de Wine para evitar que Word reutilizara DLLs que hubiesen quedado previamente cargadas:

```bash
WINEPREFIX="$HOME/.Microsoft_Office_365" \
wine32 wineserver -k
```

Después se comprobó:

```bash
pgrep -af 'WINWORD|OfficeClickToRun|OSPPSVC|wineserver'
```

No permanecía una instancia anterior de `WINWORD.EXE`.

La infraestructura del Bottle podía continuar existiendo, incluyendo componentes como:

```text
wineserver
OfficeClickToRun.exe /service
```

La nueva ejecución de Word se realizó después de este reinicio.

---

# 23. Prueba A/B con DXVK

Finalmente se ejecutó Word nuevamente:

```bash
WINEPREFIX="$HOME/.Microsoft_Office_365" \
WINEDEBUG=-all \
wine32 \
"$HOME/.Microsoft_Office_365/drive_c/Program Files/Microsoft Office/root/Office16/WINWORD.EXE"
```

El resultado cambió de forma clara:

```text
Antes:

Word
    ↓
ventana blanca ❌


Después de DXVK:

Word
    ↓
interfaz gráfica renderizada correctamente ✅
```

No fue necesario reconstruir el Bottle ni cambiar la versión de Wine.

Este experimento constituye una comparación A/B dentro del mismo entorno general:

```text
                    Backend gráfico

Bottle + Wine32
       │
       ├── WineD3D
       │      └── Word → interfaz blanca
       │
       └── DXVK 3.1.1 x32
              └── Word → interfaz funcional
```

La modificación que produjo el cambio observable fue la introducción de DXVK y los correspondientes overrides nativos.

---

# 24. Configuración funcional obtenida

La configuración que permitió restaurar la interfaz quedó compuesta por:

```text
Fedora 44
Wine 11.0 Staging
Wine32
Bottle #arch=win32
DXVK 3.1.1 x32
```

DLL gráficas relevantes:

```text
~/.Microsoft_Office_365/drive_c/windows/system32/d3d8.dll
~/.Microsoft_Office_365/drive_c/windows/system32/d3d9.dll
~/.Microsoft_Office_365/drive_c/windows/system32/d3d10core.dll
~/.Microsoft_Office_365/drive_c/windows/system32/d3d11.dll
~/.Microsoft_Office_365/drive_c/windows/system32/dxgi.dll
```

Overrides:

```text
*d3d8       = native
*d3d9       = native
*d3d10core  = native
*d3d11      = native
*dxgi       = native
```

La configuración de Office utilizada durante el diagnóstico también contenía:

```text
HKCU\Software\Microsoft\Office\16.0\Common\Graphics
    DisableHardwareAcceleration = 1
```

La restauración de la interfaz se produjo después de introducir DXVK; la modificación de `DisableHardwareAcceleration` por sí sola no había solucionado el problema.

---

# 25. Aislamiento de la causa

La secuencia de pruebas permitió reducir progresivamente las hipótesis.

| Hipótesis                                           | Resultado                                     |
| --------------------------------------------------- | --------------------------------------------- |
| Ausencia general de fuentes                         | No confirmada                                 |
| Fuentes principales inexistentes                    | No confirmada                                 |
| Fallo general de fontconfig                         | No confirmado                                 |
| Fallo general de GDI/Wine                           | Descartado por prueba con Notepad             |
| Problema exclusivo de Word por configuración normal | No confirmado; `/a` reproduce el fallo        |
| Wayland como causa principal                        | No confirmado                                 |
| WineD3D / ruta D3D11-DXGI                           | Principal hipótesis experimental              |
| DXVK                                                | Primera modificación que restaura la interfaz |

El punto decisivo fue la prueba comparativa:

```text
Mismo Bottle
+
mismo Wine
+
mismo sistema
+
mismo Word

WineD3D → interfaz blanca
DXVK     → interfaz funcional
```

Esto proporciona evidencia experimental de que el backend gráfico tenía un papel determinante en el síntoma observado.

Debe evitarse, no obstante, convertir esta observación en una afirmación universal sobre todas las instalaciones de Office bajo Wine. El resultado demuestra el comportamiento de esta combinación concreta de:

```text
Fedora 44
Wine 11.0 Staging
Wine32
Bottle preconstruido
Intel UHD 620 / Mesa
```

---

# 26. El error de fuentes después de la reparación gráfica

La reparación de la interfaz debe separarse del mensaje:

```text
There is insufficient memory or disk space.
Word cannot display the requested font.
```

Durante el diagnóstico se confirmó que:

* el Bottle contiene numerosas fuentes;
* las principales familias de Office están presentes;
* Wine puede crear objetos GDI asociados a `Calibri` y `Tahoma`;
* Notepad puede renderizar correctamente;
* Word reproduce el problema incluso mediante `/a`.

Después de instalar DXVK, la interfaz gráfica de Word puede renderizarse correctamente.

Por ello, cualquier problema restante relacionado con:

```text
Word cannot display the requested font
```

debe investigarse como una cuestión independiente de tipografía/compatibilidad de Word.

No debe asumirse que la instalación de DXVK haya reparado las referencias de fuentes.

---

# 27. Estado final de la etapa

```text
[✓] Prefix win32 identificado
[✓] Word ejecuta mediante wine32
[✓] Vulkan disponible en la máquina
[✓] GPU Intel UHD 620 disponible
[✓] Notepad funciona en el mismo Bottle
[✓] GDI funciona
[✓] Fuentes principales presentes
[✓] Wine puede seleccionar fuentes de Office
[✓] Wayland no identificado como causa principal
[✓] DXVK 3.1.1 x32 instalado
[✓] DLLs D3D/DXGI de DXVK presentes
[✓] Overrides nativos configurados
[✓] wineserver reiniciado antes de la prueba final
[✓] Interfaz gráfica de Word restaurada
[⏳] Error "Word cannot display the requested font" pendiente
```

La copia del estado anterior a la instalación de DXVK permanece disponible en:

```text
~/.Microsoft_Office_365.pre-dxvk
```

---

# 28. Conclusión

El diagnóstico permitió determinar que el problema inicial de Microsoft Word no correspondía principalmente a una ausencia general de fuentes, un fallo general de GDI/Wine ni a la utilización de Wayland por sí sola.

La evidencia más significativa fue obtenida mediante una prueba A/B.

Con el Bottle original:

```text
Wine 11.0 Staging
+
Wine32
+
WineD3D
+
Microsoft Word
        ↓
interfaz completamente blanca
```

Después de instalar DXVK 3.1.1 para el prefix `win32`:

```text
Wine 11.0 Staging
+
Wine32
+
DXVK 3.1.1 x32
+
Microsoft Word
        ↓
interfaz gráfica funcional
```

La introducción de DXVK fue la primera modificación que produjo una corrección reproducible del problema visual dentro de este entorno de laboratorio.

Por tanto, para esta combinación concreta de hardware, sistema operativo, Wine y Bottle, la configuración gráfica funcional identificada es:

```text
Bottle #arch=win32
        ↓
wine32
        ↓
DXVK 3.1.1 x32
        ↓
d3d8/d3d9/d3d10core/d3d11/dxgi = native
        ↓
Microsoft Word
        ↓
interfaz gráfica funcional
```

Este resultado permite avanzar a la siguiente fase del análisis sin confundir el problema de renderizado con el problema independiente de las fuentes.

La existencia de referencias a fuentes `.fon` ausentes y la resolución incompleta de algunas familias continúan siendo hallazgos relevantes, pero requieren una investigación específica antes de atribuirles el mensaje de error de Word.

En consecuencia, el estado de esta etapa queda establecido como:

```text
Problema de renderizado gráfico
    → REPRODUCIDO
    → AISLADO EXPERIMENTALMENTE
    → DXVK IDENTIFICADO COMO SOLUCIÓN FUNCIONAL

Problema de fuentes de Word
    → PENDIENTE
    → NO ATRIBUIDO A DXVK
```
