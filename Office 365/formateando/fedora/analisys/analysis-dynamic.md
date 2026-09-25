# Análisis dinámico del Bottle preconstruido

## 1. Alcance

Después del análisis estático del archivo `MSO365-English-.tar.zst`, se realizó una prueba dinámica controlada sobre una máquina virtual de laboratorio.

El objetivo fue observar el comportamiento real del Bottle durante la ejecución de Microsoft Word, con especial atención a:

* procesos creados;
* DLLs cargadas;
* interacción con el subsistema de licenciamiento;
* componentes `sppc`, `sppcs`, `OSPPC.DLL` y `ohook`;
* integración entre Wine, Office y el sistema Linux;
* posibles ejecuciones de herramientas externas;
* comportamiento gráfico;
* indicios que justificaran una investigación adicional.

La prueba se realizó sobre Fedora 44 utilizando Wine 11.0 Staging y las bibliotecas de 32 bits necesarias.

La ejecución se mantuvo inicialmente sin modificar manualmente el contenido del Bottle, con el propósito de observar su comportamiento lo más cercano posible a su estado preconstruido.

> **Nota:** esta prueba no constituye una auditoría completa de seguridad ni permite certificar la integridad del Bottle. Los resultados describen únicamente el comportamiento observado durante las pruebas realizadas.

---

## 2. Preparación del laboratorio

El archivo fue extraído desde el directorio de trabajo:

```bash
mkdir -p lab
tar -I zstd -xf "MSO365-English-.tar.zst" -C lab
```

La estructura obtenida fue:

```text
lab/
└── MSO365-English-/
    ├── .Microsoft_Office_365/
    ├── Desktops/
    ├── Fuentes Office365/
    ├── Office365Icons/
    └── Wrappers/
```

El Bottle se encontraba inicialmente en:

```text
lab/MSO365-English-/.Microsoft_Office_365
```

y posteriormente fue colocado en:

```text
~/.Microsoft_Office_365
```

---

## 3. Identificación de arquitectura

Antes de iniciar Microsoft Office se verificó la arquitectura del prefix y de varios ejecutables.

### 3.1 Prefix de Wine

El archivo `system.reg` contiene:

```text
#arch=win32
```

lo que identifica el prefix como `win32`.

### 3.2 Componentes internos de Wine

```bash
file "$HOME/.Microsoft_Office_365/drive_c/windows/explorer.exe"
```

Resultado:

```text
PE32 executable for WINE (GUI), Intel i386, 15 sections
```

También:

```bash
file "$HOME/.Microsoft_Office_365/drive_c/windows/system32/kernel32.dll"
```

Resultado:

```text
PE32 executable for WINE (DLL), Intel i386, 17 sections
```

### 3.3 Microsoft Office

Word:

```bash
file "$HOME/.Microsoft_Office_365/drive_c/Program Files/Microsoft Office/root/Office16/WINWORD.EXE"
```

```text
PE32 executable for MS Windows 6.01 (GUI), Intel i386, 6 sections
```

Excel:

```bash
file "$HOME/.Microsoft_Office_365/drive_c/Program Files/Microsoft Office/root/Office16/EXCEL.EXE"
```

```text
PE32 executable for MS Windows 6.01 (GUI), Intel i386, 6 sections
```

PowerPoint:

```bash
file "$HOME/.Microsoft_Office_365/drive_c/Program Files/Microsoft Office/root/Office16/POWERPNT.EXE"
```

```text
PE32 executable for MS Windows 6.01 (GUI), Intel i386, 6 sections
```

La inspección del resto de ejecutables principales de `Office16` mostró igualmente binarios `PE32 / Intel i386`.

Por tanto, tanto el prefix como los componentes principales de Office corresponden a una instalación de 32 bits.

---

# 4. Primer intento de ejecución mediante `wine`

La primera ejecución se realizó utilizando el comando genérico:

```bash
WINEPREFIX="$HOME/.Microsoft_Office_365" \
wine "$HOME/.Microsoft_Office_365/drive_c/Program Files/Microsoft Office/root/Office16/WINWORD.EXE"
```

Wine respondió:

```text
wine: '/home/eduardo/.Microsoft_Office_365' is a 32-bit installation, it cannot support 64-bit applications.
```

El mismo comportamiento se observó al intentar ejecutar:

```text
WINWORD.EXE
EXCEL.EXE
POWERPNT.EXE
cmd.exe
winecfg
```

Esto inicialmente parecía contradictorio, ya que los ejecutables habían sido identificados como `PE32 / i386`.

Se verificó la existencia del loader de 32 bits:

```bash
which wine32
```

Resultado:

```text
/usr/bin/wine32
```

Y:

```bash
file /usr/bin/wine32
```

Resultado:

```text
ELF 32-bit LSB executable, Intel i386
```

La evidencia indicó que el problema estaba relacionado con la selección del loader utilizado para el prefix `win32`, no con la arquitectura de Microsoft Office.

---

# 5. Ejecución mediante `wine32`

Se repitió la prueba utilizando explícitamente el loader de 32 bits:

```bash
WINEPREFIX="$HOME/.Microsoft_Office_365" \
wine32 cmd.exe /c ver
```

En esta ocasión el prefix pudo ejecutarse correctamente.

La salida terminó indicando:

```text
Microsoft Windows 6.1.7601
```

Durante la inicialización aparecieron numerosos mensajes:

```text
fixme:
stub
semi-stub
not implemented
```

También se observaron mensajes relacionados con componentes de kernel/GUI de Windows:

```text
err:ntoskrnl:ServiceMain Failed to load L"C:\\windows\\system32\\win32k.sys"
err:ntoskrnl:ServiceMain Failed to load L"C:\\windows\\system32\\drivers\\dxgkrnl.sys"
err:ntoskrnl:ServiceMain Failed to load L"C:\\windows\\system32\\drivers\\dxgmms1.sys"
```

Estos mensajes son compatibles con funcionalidades que Wine implementa parcialmente y, por sí mismos, no constituyen evidencia de comportamiento malicioso.

Durante la inicialización también se observó:

```text
regsvr32: Successfully unregistered DLL 'C:\windows\\Microsoft.NET\Framework\v4.0.30319\diasymreader.dll'
```

Este evento ocurrió durante la inicialización del entorno Wine/.NET y no fue asociado con una actividad externa.

### Resultado

```text
Prefix win32
    └── funcional mediante wine32
```

---

# 6. Ejecución instrumentada de Microsoft Word

Una vez confirmado que el prefix podía ejecutarse mediante `wine32`, se inició Microsoft Word bajo instrumentación:

```bash
WINEPREFIX="$HOME/.Microsoft_Office_365" \
WINEDEBUG=+loaddll,-fixme-all \
strace -ff -tt -s 200 \
  -e trace=%file,%process,%network \
  -o "$HOME/forense-trace/word" \
  wine32 \
  "$HOME/.Microsoft_Office_365/drive_c/Program Files/Microsoft Office/root/Office16/WINWORD.EXE"
```

La ejecución generó numerosos archivos de traza:

```text
word.11552
word.11553
word.11554
word.11561
word.11562
...
word.12559
```

El archivo principal alcanzó aproximadamente:

```text
128 MB
```

además de múltiples archivos correspondientes a procesos hijos.

Esto confirma que la ejecución alcanzó una fase sustancial de inicialización de Word y de sus componentes auxiliares.

---

# 7. Estado visual de Microsoft Word

Word llegó a crear su ventana, pero la interfaz se mostró completamente blanca.

El entorno gráfico se verificó mediante:

```bash
echo "XDG_SESSION_TYPE=$XDG_SESSION_TYPE"
echo "WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
echo "DISPLAY=$DISPLAY"
```

Resultado:

```text
XDG_SESSION_TYPE=wayland
WAYLAND_DISPLAY=wayland-1
DISPLAY=:0
```

El comportamiento se consideró provisionalmente un problema de compatibilidad gráfica entre Microsoft Office, Wine y la sesión gráfica utilizada en el laboratorio.

No se utilizó este comportamiento visual como indicador de actividad maliciosa.

El problema gráfico motivó posteriormente la investigación de las bibliotecas Direct3D, DXVK, WineD3D, OpenGL y Vulkan cargadas durante la ejecución.

---

# 8. Procesos creados durante la ejecución

Se inspeccionaron las llamadas `execve()` presentes en las trazas:

```bash
grep -hE 'execve\(' word.* | sort -u
```

La cadena principal observada fue:

```text
/usr/bin/wine32
        ↓
wine-preloader
        ↓
wineserver
        ↓
wineboot.exe --init
        ↓
winemenubuilder.exe
        ↓
services.exe
        ↓
winedevice.exe
        ↓
explorer.exe
        ↓
svchost.exe
        ↓
plugplay.exe
        ↓
OfficeClickToRun.exe /service
        ↓
rpcss.exe
        ↓
OSPPSVC.EXE
        ↓
svchost.exe
```

Entre los procesos directamente relacionados con Microsoft Office se observaron:

```text
C:\Program Files\Common Files\Microsoft Shared\ClickToRun\OfficeClickToRun.exe /service
```

y:

```text
C:\Program Files\Common Files\Microsoft Shared\OfficeSoftwareProtectionPlatform\OSPPSVC.EXE
```

Estos corresponden a componentes de Office relacionados con Click-to-Run y Software Protection Platform.

### 8.1 Herramientas Linux externas

En el inventario de `execve()` no se observaron ejecuciones de:

```text
bash
sh
curl
wget
python
perl
nc
ssh
```

ni de otras herramientas Linux de consola que, en este contexto, constituyeran por sí mismas un payload externo evidente.

Este resultado debe interpretarse como un hallazgo de esta ejecución concreta y no como una garantía de que el Bottle nunca pueda ejecutar dichos programas.

---

# 9. Integración con el escritorio Linux

La traza también mostró la ejecución de:

```text
/usr/bin/update-mime-database
/usr/bin/update-desktop-database
```

Antes de localizar los binarios se observaron intentos normales de resolución mediante `PATH`, incluyendo rutas como:

```text
/home/eduardo/.nvm/...
/home/eduardo/.opencode/bin/...
/usr/local/bin/...
/usr/bin/...
```

Finalmente se ejecutaron:

```text
/usr/bin/update-mime-database
/usr/bin/update-desktop-database
```

Este comportamiento es consistente con la integración de Wine y de las aplicaciones Windows con el entorno de escritorio Linux.

No se consideró un comportamiento sospechoso dentro del contexto de esta prueba.

---

# 10. DLLs nativas de Microsoft Office

Durante la ejecución se observaron cargas de DLL nativas del Bottle, entre ellas:

```text
C:\Program Files\Microsoft Office\root\Office16\msproof7.dll
C:\Program Files\Common Files\Microsoft Shared\PROOF\MSLID.DLL
C:\Program Files\Microsoft Office\Root\Office16\PROOF\msgrammar8.dll
```

Estos componentes están relacionados con funciones lingüísticas, corrección ortográfica y gramatical de Microsoft Office.

Su presencia confirma que Word estaba cargando componentes reales del contenido del Bottle y no únicamente iniciando el loader de Wine.

---

# 11. Verificación dinámica del subsistema de licenciamiento

Una de las principales preguntas de esta etapa era determinar qué componentes del subsistema de licenciamiento terminaban realmente cargados por `WINWORD.EXE`.

Con Word en ejecución se inspeccionó:

```bash
grep -iE 'sppc|osppc|sppcs|d3d|dxgi|wined3d|opengl|vulkan' \
    /proc/11552/maps
```

Entre las bibliotecas mapeadas aparecieron:

```text
/home/eduardo/.Microsoft_Office_365/drive_c/Program Files/Microsoft Office/root/Office16/sppcs.dll
```

y:

```text
/home/eduardo/.Microsoft_Office_365/drive_c/Program Files/Common Files/Microsoft Shared/OfficeSoftwareProtectionPlatform/OSPPC.DLL
```

La segunda ruta es especialmente relevante:

```text
Common Files/
Microsoft Shared/
OfficeSoftwareProtectionPlatform/
OSPPC.DLL
```

La presencia de esta ruta en `/proc/<pid>/maps` constituye evidencia directa de que `OSPPC.DLL` fue cargada en el espacio de memoria del proceso observado.

Por tanto, el uso de este componente ya no se infiere únicamente a partir de la estructura estática del Bottle.

---

# 12. Bibliotecas gráficas observadas

La misma inspección mostró bibliotecas relacionadas con Direct3D, WineD3D, OpenGL y Vulkan:

```text
d3dcompiler_47.dll
wine-d3d10core.dll
d3d10_1.dll
opengl32.dll
wined3d.dll
dxgi.dll
d3d11.dll
libvulkan.so
libvulkan_intel.so
libvulkan_lvp.so
opengl32.so
```

Esto confirma la participación de las capas gráficas de Wine y del stack gráfico del sistema Linux durante la ejecución.

La presencia simultánea de estos componentes es consistente con el problema gráfico observado y justifica continuar la investigación de compatibilidad gráfica.

---

# 13. Inventario de `OSPPC.DLL` y `sppcs.dll`

Se realizó un inventario de los componentes del subsistema de protección:

```bash
find "$HOME/.Microsoft_Office_365/drive_c" \
  -type f \
  \( -iname 'OSPPC.DLL' -o -iname 'sppcs.dll' \) \
  -printf '%p -> %s bytes\n'
```

Se encontraron las siguientes variantes:

```text
Program Files/Common Files/Microsoft Shared/OfficeSoftwareProtectionPlatform/sppcs.dll
    179800 bytes

Program Files/Common Files/Microsoft Shared/OfficeSoftwareProtectionPlatform/OSPPC.DLL
    9216 bytes

Program Files/Microsoft Office/Office16/sppcs.dll
    179800 bytes

Program Files/Microsoft Office/Office16/OSPPC.DLL
    9216 bytes

Program Files/Microsoft Office/root/Office16/vfs/System/sppcs.dll
    179800 bytes

Program Files/Microsoft Office/root/Office16/vfs/System/OSPPC.DLL
    9216 bytes

Program Files/Microsoft Office/root/Office16/sppcs.dll
    179800 bytes

Program Files/Microsoft Office/root/vfs/SystemX86/sppcs.dll
    179800 bytes

Program Files/Microsoft Office/root/vfs/SystemX86/OSPPC.DLL
    9216 bytes
```

Se identificaron dos variantes de `OSPPC.DLL`.

### Variante A

Ruta:

```text
Program Files/Common Files/Microsoft Shared/OfficeSoftwareProtectionPlatform/OSPPC.DLL
```

SHA-256:

```text
1fb1fcc883eccd26c062f8c54174eea9541f0010efa8ba75cf722f97f587f208
```

### Variante B

Ruta:

```text
Program Files/Microsoft Office/root/vfs/SystemX86/OSPPC.DLL
```

SHA-256:

```text
1c9a877a70a07dec17b7826d1550b5a1622786ecea644931cb789f8130f8b0b0
```

Las demás copias correspondientes a la variante B presentaron el mismo SHA-256.

---

# 14. Comparación de las dos variantes de `OSPPC.DLL`

Se comparó la copia ubicada en `Common Files` con la copia ubicada en el árbol virtual de Office:

```bash
cmp -l \
"$HOME/.Microsoft_Office_365/drive_c/Program Files/Common Files/Microsoft Shared/OfficeSoftwareProtectionPlatform/OSPPC.DLL" \
"$HOME/.Microsoft_Office_365/drive_c/Program Files/Microsoft Office/root/vfs/SystemX86/OSPPC.DLL" |
wc -l
```

Resultado:

```text
8
```

Ambos archivos tienen:

```text
9216 bytes
```

Las diferencias fueron:

```text
137 312  53
138 266 153
139  44  17

217 265 223
218 223 374

2565 312  53
2566 266 153
2567  44  17
```

Los metadatos PE fueron examinados posteriormente.

### Variante A

```text
CheckSum        000093b5
Time/Date stamp 6924b6ca
```

### Variante B

```text
CheckSum        0000fc4c
Time/Date stamp 690f6b2b
```

Las posiciones diferentes corresponden a metadatos PE, incluyendo timestamp, checksum y el timestamp asociado a la tabla de exportaciones.

Por lo tanto, las dos copias presentan diferencias binarias limitadas a metadatos observados en esta comparación.

Esto permite considerarlas variantes esencialmente equivalentes desde el punto de vista del código funcional observado, aunque no sean criptográficamente idénticas.

---

# 15. Comparación con `ohook/sppc32.dll`

Anteriormente se había identificado:

```text
.Microsoft_Office_365/drive_c/ohook/sppc32.dll
```

SHA-256:

```text
7a0203c7f92568c82cda14a3cc58e04308e90281282741f6feddf3a283f0b290
```

Tamaño:

```text
9216 bytes
```

Se comparó con:

```text
Program Files/Microsoft Office/root/vfs/SystemX86/OSPPC.DLL
```

mediante:

```bash
cmp -l \
".Microsoft_Office_365/drive_c/ohook/sppc32.dll" \
".Microsoft_Office_365/drive_c/Program Files/Microsoft Office/root/vfs/SystemX86/OSPPC.DLL" |
wc -l
```

Resultado:

```text
430
```

Esto representa aproximadamente el 4,66 % de las posiciones de bytes.

Sin embargo, el análisis estructural mostró coincidencias importantes:

```text
PE32 / i386
9216 bytes
7 secciones
67 exports
```

Ambos binarios importan:

```text
sppcs.dll
    SLGetLicensingStatusInformation
    SLGetProductSkuInformation

KERNEL32.dll
    LocalFree

SHLWAPI.dll
    StrStrNIW
```

También presentan el mismo conjunto general de exports relacionados con `SL*`.

Una característica particularmente relevante es la presencia de:

```text
SLGetLicensingStatusInformation
```

como función implementada localmente, mientras que gran parte de las demás funciones aparecen como forwarders hacia:

```text
SPPCS.<función>
```

Las diferencias observadas entre los binarios incluyen:

```text
timestamp
checksum
entry point
RVA de la función local
relocations
```

A pesar de estas diferencias, los strings funcionales y la estructura de imports/exports son fuertemente coincidentes.

### Interpretación

La evidencia es fuertemente consistente con que la `OSPPC.DLL` incluida en el árbol de Office sea una variante o recompilación estrechamente relacionada con el componente:

```text
ohook/sppc32.dll
```

No se afirma identidad criptográfica de origen porque los SHA-256 son diferentes y no se dispone del artefacto de compilación correspondiente.

---

# 16. Verificación de la `OSPPC.DLL` realmente utilizada por Word

La evidencia dinámica más importante se obtuvo directamente del proceso de Word:

```bash
grep -iE 'sppc|osppc|sppcs' /proc/11552/maps
```

Resultado relevante:

```text
6a130000-6a131000 ... /home/eduardo/.Microsoft_Office_365/drive_c/Program Files/Microsoft Office/root/Office16/sppcs.dll

6a170000-6a171000 ... /home/eduardo/.Microsoft_Office_365/drive_c/Program Files/Common Files/Microsoft Shared/OfficeSoftwareProtectionPlatform/OSPPC.DLL
```

Esto confirma dinámicamente que `WINWORD.EXE` tenía cargada:

```text
Common Files/Microsoft Shared/OfficeSoftwareProtectionPlatform/OSPPC.DLL
```

La observación es significativa porque establece una diferencia entre:

```text
archivo presente en el Bottle
```

y:

```text
archivo realmente utilizado durante la ejecución
```

En este caso existe evidencia directa para ambas cosas.

---

# 17. Modelo funcional provisional del subsistema SPP

La evidencia estática y dinámica obtenida permite representar provisionalmente la arquitectura observada como:

```text
                 WINWORD.EXE
                     │
                     ▼
        OSPPC.DLL de Office
                     │
                     ├── SLGetLicensingStatusInformation
                     │
                     ├── SLGetProductSkuInformation
                     │
                     └── otras APIs SL*
                     │
                     ▼
                  sppcs.dll
                     │
                     ▼
                 OSPPSVC.EXE
```

Paralelamente, Wine proporciona:

```text
WineCX
    └── system32/sppc.dll
```

Este archivo corresponde a la implementación de `sppc` proporcionada por WineCX.

El Bottle contiene además:

```text
C:\ohook\
    sppc32.dll
    sppc64.dll
    sppcplus32.dll
    sppcplus64.dll
```

Estos archivos corresponden al material asociado con el mecanismo `ohook` identificado durante el análisis estático.

---

# 18. Directorio `C:\ohook`

El Bottle incluye:

```text
C:\ohook\readme.md
```

La documentación incluida describe el funcionamiento del proyecto `ohook` y su interacción con los componentes del sistema de licenciamiento de Office.

Entre las instrucciones documentadas aparece una operación de sustitución de un componente `sppc`, por ejemplo:

```text
copy /y sppc64.dll "%programfiles%\Microsoft Office\root\vfs\System\sppc.dll"
```

La documentación también distingue entre:

```text
ohook
```

y:

```text
ohook+
```

y describe modificaciones relacionadas con comprobaciones de suscripción.

La presencia de `OSPPC.DLL` integrada dentro de las rutas de Office, junto con su similitud estructural con `ohook/sppc32.dll`, proporciona una explicación coherente para la existencia de una fase en la que el directorio `C:\ohook` funciona como material auxiliar.

La posterior eliminación de dicho directorio no constituye, por sí sola, evidencia de ocultación de malware.

---

# 19. Diferenciación entre `system32\sppc.dll`, `ohook\sppc32.dll` y `OSPPC.DLL`

Es importante no tratar todos los archivos con nombres similares como el mismo componente.

### `C:\Windows\System32\sppc.dll`

Fue identificado como:

```text
PE32 executable for WINE (DLL), Intel i386
```

Contiene referencias como:

```text
../winecx/dlls/sppc/sppc.c
../winecx/dlls/winecrt0/...
../winecx/include/wine
```

y símbolos del tipo:

```text
__wine_stub_SL...
```

Por tanto, corresponde a una implementación de `sppc` proporcionada por WineCX.

### `C:\ohook\sppc32.dll`

Es un binario PE32 de Windows incluido como parte del material de `ohook`.

### `OfficeSoftwareProtectionPlatform\OSPPC.DLL`

Es el componente de Office observado dinámicamente dentro de:

```text
Common Files/Microsoft Shared/OfficeSoftwareProtectionPlatform/
```

y fue cargado por `WINWORD.EXE`.

Por tanto, existen al menos tres componentes distintos relacionados con la misma familia funcional de APIs de licenciamiento:

```text
WineCX
    └── system32\sppc.dll

ohook
    └── ohook\sppc32.dll

Microsoft Office
    └── OfficeSoftwareProtectionPlatform\OSPPC.DLL
```

La similitud funcional no implica identidad de archivos.

---

# 20. Imports de `OSPPC.DLL`

La variante activa de `OSPPC.DLL` fue examinada mediante:

```bash
LC_ALL=C objdump -p \
"$HOME/.Microsoft_Office_365/drive_c/Program Files/Common Files/Microsoft Shared/OfficeSoftwareProtectionPlatform/OSPPC.DLL" |
grep -A20 -E 'DLL Name'
```

Se observaron los siguientes imports:

```text
DLL Name: sppcs.dll

SLGetLicensingStatusInformation
SLGetProductSkuInformation

DLL Name: KERNEL32.dll

LocalFree

DLL Name: SHLWAPI.dll

StrStrNIW
```

No se observaron imports directos de:

```text
WinHTTP
WinINet
URLDownloadToFile
CreateProcess
WinExec
ShellExecute
```

Esta información no demuestra que la DLL sea incapaz de realizar comunicaciones o resolver APIs dinámicamente. Sin embargo, la tabla de imports observada es coherente con una DLL pequeña especializada en la interacción con el subsistema SPP.

---

# 21. Estado de los procesos durante la prueba

Mientras Word permanecía abierto se verificaron los procesos relacionados:

```bash
ps -ef | grep -Ei 'WINWORD|wine' | grep -v grep
```

Entre los procesos observados:

```text
WINWORD.EXE
wineserver
winedevice.exe
```

Ejemplos:

```text
eduardo  11552 ... WINWORD.EXE
eduardo  11554 ... /usr/lib/wine-wow64/wine/../../../bin/wineserver
eduardo  11575 ... C:\windows\system32\winedevice.exe
eduardo  11643 ... C:\windows\system32\winedevice.exe
```

También se utilizó:

```bash
pgrep -af 'WINWORD|OSPPSVC|OfficeClickToRun|MSO'
```

y se observó:

```text
11552 WINWORD.EXE
11619 OfficeClickToRun.exe /service
```

Durante fases anteriores de la ejecución instrumentada también se observó:

```text
OSPPSVC.EXE
```

como proceso iniciado por el entorno de Office.

---

# 22. Resultados dinámicos

La ejecución permitió confirmar los siguientes comportamientos:

| Observación                                                                             | Estado                                        |
| --------------------------------------------------------------------------------------- | --------------------------------------------- |
| `WINWORD.EXE` se ejecuta mediante `wine32`                                              | 🟢 Confirmado                                 |
| Prefix `win32` funcional                                                                | 🟢 Confirmado                                 |
| `OfficeClickToRun.exe` ejecutado                                                        | 🟢 Confirmado                                 |
| `OSPPSVC.EXE` ejecutado durante la inicialización                                       | 🟢 Observado                                  |
| DLLs nativas de Office cargadas                                                         | 🟢 Confirmado                                 |
| `sppcs.dll` cargada por Word                                                            | 🟢 Confirmado                                 |
| `OSPPC.DLL` cargada por Word                                                            | 🟢 Confirmado                                 |
| `OSPPC.DLL` relacionada estructuralmente con `ohook/sppc32.dll`                         | 🟢 Evidencia fuerte                           |
| Herramientas Linux externas como `curl`, `wget` o `bash` observadas mediante `execve()` | 🟢 No observadas                              |
| Payload Linux externo evidente en la cadena de procesos                                 | 🟢 No observado                               |
| Interfaz gráfica de Word funcional                                                      | 🔴 No; pantalla blanca                        |
| Modificación del subsistema de licensing                                                | 🔴 Confirmada por evidencia previa y dinámica |
| Auditoría completa de tráfico de red                                                    | ⏳ Pendiente                                   |
| Inventario completo de cambios de filesystem                                            | ⏳ Pendiente                                   |
| Inventario completo de cambios de registro                                              | ⏳ Pendiente                                   |
| Persistencia                                                                            | ⏳ Pendiente                                   |

Los estados anteriores describen únicamente la evidencia disponible durante esta etapa.

---

# 23. Qué demuestra esta etapa

El análisis dinámico permitió pasar de varias inferencias estáticas a observaciones directamente verificadas durante la ejecución.

En particular, se confirmó que:

```text
WINWORD.EXE
    │
    ├── carga sppcs.dll
    │
    └── carga OSPPC.DLL
```

También se observó que el entorno de Office inicia componentes relacionados con:

```text
Click-to-Run
Software Protection Platform
```

La `OSPPC.DLL` cargada por Word pertenece además a una familia de binarios cuya estructura es fuertemente consistente con el material `ohook` incluido en el Bottle.

Por tanto, existe evidencia estática y dinámica que respalda la siguiente descripción:

```text
Bottle preconstruido
        │
        ├── Microsoft Office
        │
        ├── WineCX
        │
        └── modificación del subsistema de licensing mediante componentes asociados a ohook
```

---

# 24. Qué no demuestra esta etapa

Los resultados obtenidos no permiten afirmar que:

```text
el Bottle completo sea seguro
```

ni que:

```text
el Bottle completo contenga malware
```

Tampoco permiten concluir, únicamente a partir de esta prueba, que no exista:

* código malicioso en otros ejecutables;
* comportamiento activado únicamente bajo determinadas condiciones;
* comunicación con servidores específicos;
* mecanismos de persistencia;
* modificaciones adicionales del registro;
* archivos creados temporalmente y posteriormente eliminados;
* actividad de red que no haya sido caracterizada todavía.

La ausencia de procesos externos observados en esta sesión debe interpretarse como:

```text
no observado durante esta ejecución
```

y no como:

```text
imposible
```

---

# 25. Estado de la investigación

### 🟢 Confirmado

* El Bottle es `win32`.
* Microsoft Word es un ejecutable PE32/i386.
* El prefix requiere `wine32` para esta configuración.
* Word ejecuta componentes nativos de Microsoft Office.
* `OfficeClickToRun.exe` es ejecutado.
* `OSPPSVC.EXE` es observado durante la inicialización.
* `sppcs.dll` es cargada por Word.
* `OSPPC.DLL` es cargada por Word.
* La `OSPPC.DLL` activa está ubicada en el subsistema `OfficeSoftwareProtectionPlatform`.
* Las variantes examinadas de `OSPPC.DLL` son estructuralmente muy similares.
* Existe una relación estructural fuerte entre una variante de `OSPPC.DLL` y `ohook/sppc32.dll`.

### 🟡 Contexto necesario

* La ausencia de imports de red en `OSPPC.DLL` no descarta comunicaciones realizadas por otros componentes.
* La ausencia de `bash`, `curl`, `wget`, etc. en `execve()` corresponde únicamente a la ejecución observada.
* Los errores `fixme`, `stub` y `not implemented` de Wine no deben interpretarse automáticamente como fallos de seguridad.

### 🔴 Modificación confirmada

Existe evidencia suficiente, combinando el análisis estático previo con esta prueba dinámica, para confirmar que el Bottle incorpora una modificación deliberada del subsistema de licenciamiento de Microsoft Office asociada con `ohook`.

Esto constituye una característica relevante del método y debe documentarse explícitamente.

### ⏳ Pendiente

Todavía deben investigarse:

1. tráfico de red;
2. dominios y destinos consultados;
3. conexiones realizadas por `WINWORD.EXE`;
4. conexiones realizadas por `OSPPSVC.EXE`;
5. conexiones realizadas por `OfficeClickToRun.exe`;
6. cambios en el registro durante la sesión;
7. archivos creados, modificados y eliminados;
8. mecanismos de persistencia;
9. comportamiento después de cerrar Word;
10. comportamiento después de reiniciar el prefix.

---

# 26. Conclusión

La prueba dinámica permitió confirmar elementos que anteriormente solo podían inferirse mediante análisis estático.

La observación más relevante fue que `WINWORD.EXE` carga efectivamente:

```text
sppcs.dll
```

y:

```text
Common Files/Microsoft Shared/OfficeSoftwareProtectionPlatform/OSPPC.DLL
```

durante su ejecución.

La comparación de las distintas copias de `OSPPC.DLL` mostró variantes de `9216` bytes con diferencias limitadas en metadatos PE, mientras que la comparación con:

```text
ohook/sppc32.dll
```

mostró una diferencia de `430` posiciones de bytes, pero conservó una estructura de PE, imports y exports fuertemente coincidente.

Esto proporciona evidencia estática y dinámica fuerte de que el Bottle preconstruido contiene y utiliza una variante del mecanismo de modificación del licensing asociado con `ohook`.

Al mismo tiempo, durante la ejecución instrumentada no se observó una cadena de procesos Linux externa claramente ajena a Wine/Office ni ejecuciones de herramientas como:

```text
bash
sh
curl
wget
python
perl
nc
ssh
```

Esto no constituye una certificación de seguridad, sino únicamente el resultado de la ejecución observada.

La evidencia disponible permite separar dos cuestiones independientes:

```text
Modificación deliberada del subsistema de licensing
        → CONFIRMADA

Payload Linux arbitrario o malware genérico
        → NO DEMOSTRADO
```

La investigación permanece abierta.

El siguiente paso debe centrarse en el comportamiento que todavía no ha sido caracterizado: **tráfico de red, cambios de filesystem, modificaciones del registro, persistencia y actividad posterior al cierre de Word**.

Estas pruebas permitirán determinar qué comunicaciones realizan `WINWORD.EXE`, `OSPPSVC.EXE` y `OfficeClickToRun.exe`, qué recursos externos consultan y qué modificaciones permanecen después de finalizar la ejecución.
