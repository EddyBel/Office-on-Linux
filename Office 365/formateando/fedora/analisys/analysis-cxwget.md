# Análisis estático de `cxwget.exe`

## 1. Alcance

Como parte del análisis estático del archivo:

```text
MSO365-English-.tar.zst
```

se examinó individualmente el ejecutable:

```text
.Microsoft_Office_365/drive_c/windows/system32/cxwget.exe
```

El objetivo fue determinar si `cxwget.exe` presenta características coherentes con una utilidad perteneciente al entorno Wine/CrossOver incluido en el Bottle.

El análisis se realizó exclusivamente mediante inspección estática. El ejecutable **no fue ejecutado**.

Las conclusiones de este documento se limitan al archivo analizado y no deben interpretarse como una certificación de seguridad del Bottle completo.

---

## 2. Extracción controlada

El ejecutable se extrajo directamente desde el archivo comprimido sin descomprimir ni ejecutar el resto del Bottle:

```bash
mkdir -p ./cxwget-analysis

tar -I zstd -xOf ./MSO365-English-.tar.zst \
  'MSO365-English-/.Microsoft_Office_365/drive_c/windows/system32/cxwget.exe' \
  > ./cxwget-analysis/cxwget.exe
```

Posteriormente se identificó el formato del archivo:

```bash
file ./cxwget-analysis/cxwget.exe
```

Resultado:

```text
PE32 executable for WINE (console), Intel i386
(stripped to external PDB), 6 sections
```

El archivo tiene un tamaño aproximado de 33 KB.

La información obtenida es consistente con un ejecutable PE de Windows de 32 bits diseñado para funcionar dentro de Wine.

### Resultado

**🟢 Coherente con un componente Wine/CrossOver.**

La ubicación dentro de:

```text
drive_c/windows/system32/
```

también resulta consistente con la estructura del Bottle.

Esta observación no demuestra por sí sola que el archivo sea auténtico, pero no se encontraron indicios que permitan clasificarlo como un ejecutable externo introducido arbitrariamente en el Bottle.

---

## 3. Identificación funcional mediante cadenas

La inspección de cadenas permitió encontrar información directamente relacionada con la función del ejecutable:

```text
Wine builtin DLL
cxwget

Usage: cxwget [--resolve-redir | --noui] url
or: cxwget url file

Connecting to host='%s' port=%d user='%s' pass='%s'

Unable to open the HTTP request
Unable to send the HTTP request

Unable to open the FTP request
```

También se identificaron referencias a funciones relacionadas con HTTP, FTP y manejo de URLs:

```text
HttpOpenRequestA
HttpQueryInfoA
HttpSendRequestA
InternetConnectA
InternetCrackUrlA
FtpFindFirstFileA
FtpOpenFileA
```

Estas referencias son coherentes con una utilidad destinada a realizar solicitudes HTTP/FTP y descargar recursos.

No se identificaron en la inspección realizada referencias evidentes a mecanismos externos de ejecución como:

```text
powershell
cmd.exe
wscript
cscript
URLDownload
WinExec
Shell
```

### Interpretación

La presencia de funcionalidad de red no constituye por sí misma un indicador de comportamiento malicioso. En este caso, dicha funcionalidad coincide directamente con la finalidad declarada por el propio ejecutable.

### Resultado

**🟢 Comportamiento aparente coherente con la función esperada.**

---

## 4. Estructura PE

Se inspeccionó la estructura PE mediante:

```bash
objdump -x ./cxwget-analysis/cxwget.exe | head -n 120
```

El archivo fue identificado como:

```text
pei-i386
PE32
i386
Windows CUI
```

La entrada de ejecución se encuentra en:

```text
AddressOfEntryPoint 00001ed0
```

Entre las características del encabezado PE se observaron:

```text
DYNAMIC_BASE
NX_COMPAT
```

Estas características corresponden a mecanismos de protección de memoria utilizados por aplicaciones Windows.

### Security Directory

El encabezado PE muestra:

```text
Entry 4 00000000 00000000 Security Directory
```

Por lo tanto, el archivo no contiene una firma Authenticode embebida.

La ausencia de una firma impide utilizar Authenticode como mecanismo de verificación de procedencia.

Sin embargo:

> La ausencia de firma digital no constituye evidencia de malware.

Simplemente significa que la autenticidad del binario no puede establecerse mediante una firma Microsoft válida.

---

## 5. Tabla de importaciones

La tabla de importaciones contiene, entre otras, referencias a:

```text
comctl32.dll
gdi32.dll
kernel32.dll
ntdll.dll
ucrtbase.dll
```

Entre las funciones observadas de `kernel32.dll se encuentran:

```text
CloseHandle
CreateEventA
CreateFileA
CreateThread
DeleteFileA
GetLastError
GetModuleHandleA
GetModuleHandleW
GetProcAddress
GetProcessHeap
GetTickCount
HeapAlloc
HeapFree
HeapReAlloc
LoadLibraryA
MulDiv
OpenEventA
SetEvent
WaitForSingleObject
WriteFile
```

Estas APIs proporcionan capacidades normales para:

* gestión de archivos;
* administración de memoria;
* creación y sincronización de hilos;
* acceso a módulos;
* manejo de eventos;
* operaciones internas del proceso.

La presencia de estas funciones no constituye por sí misma un indicador de actividad maliciosa.

### Limitación

La extracción inicial de la tabla de importaciones no se completó debido a que la salida fue interrumpida al llegar a `ucrtbase.dll`.

Por este motivo, el inventario de imports se considera **parcial** y queda pendiente una extracción completa.

### Resultado

**🟡 Análisis parcial.**

No se observaron APIs claramente inesperadas en la sección examinada, pero el análisis no debe considerarse exhaustivo hasta completar la tabla.

---

## 6. Timestamp PE

El encabezado PE contiene:

```text
Time/Date Wed Dec 31 18:00:00 1969
```

Este valor no se considera una fecha de compilación confiable.

Puede corresponder a un timestamp neutralizado, artificial o generado mediante un proceso de compilación reproducible.

Por lo tanto, el timestamp:

* no se utiliza como evidencia de actividad maliciosa;
* no permite determinar de forma fiable cuándo fue compilado el archivo;
* no permite establecer su procedencia.

### Resultado

**⚪ Sin valor probatorio suficiente.**

---

# 7. Evaluación del componente

La evidencia recopilada hasta este punto presenta varias características coherentes entre sí:

| Característica                         | Resultado                      |
| -------------------------------------- | ------------------------------ |
| Formato PE de 32 bits                  | 🟢 Coherente                   |
| Ubicación en `windows/system32`        | 🟢 Coherente                   |
| Identificación como `Wine builtin DLL` | 🟢 Coherente                   |
| Nombre `cxwget`                        | 🟢 Coherente                   |
| Funciones HTTP/FTP                     | 🟢 Coherentes con su propósito |
| APIs de archivos/memoria/hilos         | 🟢 Normales                    |
| Firma Authenticode                     | ⚪ Ausente                      |
| Timestamp                              | ⚪ No confiable                 |
| Tabla completa de imports              | 🟡 Pendiente                   |

La combinación de estos elementos resulta compatible con una utilidad perteneciente al ecosistema Wine/CrossOver.

No se encontraron durante esta revisión indicadores directos que permitan clasificar `cxwget.exe` como un componente malicioso.

---

# 8. Relación con el análisis general del Bottle

El análisis de `cxwget.exe` debe interpretarse dentro del contexto del archivo completo:

```text
MSO365-English-.tar.zst
```

La presencia de `cxwget.exe` no constituye por sí misma un problema de seguridad.

De hecho, su ubicación, identificación interna y funcionalidad observada son consistentes con el resto de la infraestructura Wine/CrossOver encontrada en el Bottle.

Esto contrasta con otros componentes identificados durante la investigación, particularmente:

```text
drive_c/ohook/
```

cuyo propósito está relacionado con la modificación del comportamiento del sistema de licenciamiento de Office.

Por tanto, deben mantenerse separadas dos cuestiones:

1. **Procedencia y comportamiento del componente `cxwget.exe`.**
2. **Modificaciones realizadas al sistema de licenciamiento de Office.**

El análisis de `cxwget.exe` no modifica las conclusiones obtenidas anteriormente sobre `ohook`.

---

# 9. Limitaciones

El análisis realizado presenta las siguientes limitaciones:

* No se ejecutó el archivo.
* No se realizó análisis dinámico.
* No se realizó captura de tráfico de red.
* No se completó todavía la tabla completa de imports.
* No se comparó el hash con un binario oficial conocido.
* La ausencia de firma Authenticode impide verificar su procedencia mediante firma digital.
* El análisis de cadenas no garantiza la ausencia de funcionalidades no representadas como texto.
* La identificación como componente Wine/CrossOver no demuestra que el archivo provenga de una distribución oficial concreta.

Estas limitaciones deben conservarse explícitamente en la documentación para evitar interpretar el análisis como una certificación de seguridad.

---

# 10. Estado del análisis

### Estado actual

**🟢 Coherente con Wine/CrossOver**

No se identificaron indicadores directos de comportamiento malicioso en la evidencia examinada.

### Pendiente

Para aumentar la confianza en la identificación del componente se recomienda:

1. completar el inventario de imports;
2. calcular el SHA-256 del ejecutable;
3. localizar una versión conocida de `cxwget.exe` procedente de Wine/CrossOver;
4. comparar hashes y, cuando sea posible, estructura PE;
5. comparar las secciones del ejecutable con una versión de referencia;
6. documentar cualquier diferencia encontrada.

---

# 11. Conclusión

El análisis estático realizado sobre:

```text
cxwget.exe
```

muestra un perfil consistente con una utilidad de red perteneciente al entorno Wine/CrossOver.

La evidencia más relevante es:

* formato PE32 para x86;
* ubicación dentro de `windows/system32`;
* identificación interna como `Wine builtin DLL`;
* nombre y mensajes de uso coherentes con `cxwget`;
* presencia de funciones HTTP/FTP;
* ausencia de indicadores evidentes de PowerShell o ejecución externa en las cadenas examinadas;
* APIs de sistema compatibles con las operaciones esperadas;
* ausencia de firma Authenticode;
* timestamp PE no confiable.

Con la evidencia disponible, **no se han encontrado indicadores directos de comportamiento malicioso en `cxwget.exe`**.

Esta conclusión es específica del componente analizado y **no implica que el Bottle completo pueda considerarse seguro**.

La evaluación global debe continuar con el análisis de los registros de Wine, configuración de red, archivos de inicio, inventario completo de binarios y comparación de hashes.

---

## 12. Relación con la investigación principal

Este documento forma parte del análisis estático del método de Microsoft Office 365 basado en el Bottle distribuido originalmente por **Formateando**.

El objetivo de esta investigación es documentar qué contiene el entorno proporcionado, identificar modificaciones respecto a una instalación estándar y registrar tanto los componentes legítimos como aquellos que requieren atención adicional.

La metodología utilizada sigue el principio:

```text
extraer
    ↓
identificar
    ↓
inspeccionar
    ↓
comparar
    ↓
documentar
    ↓
concluir
```

El análisis permanece abierto hasta completar las áreas pendientes del Bottle.
