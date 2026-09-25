# Análisis estático del Bottle de Microsoft Office 365

## 1. Alcance

Este documento describe el análisis estático realizado sobre un archivo preconfigurado de Microsoft Office 365 distribuido como un entorno de Wine/CrossOver.

El análisis se realizó con el objetivo de determinar:

* La naturaleza y estructura del archivo.
* Los componentes incluidos en el entorno.
* La procedencia aparente de sus componentes.
* La presencia de modificaciones adicionales a la instalación de Office.
* La existencia de mecanismos relacionados con activación o licenciamiento.
* La presencia de indicadores técnicos que justificaran una investigación adicional.
* Las limitaciones del análisis y los aspectos que permanecen sin verificar.

El análisis se realizó **sin ejecutar inicialmente los componentes desconocidos del archivo**, priorizando la inspección estática del contenido.

> **Importante:** este análisis no constituye una auditoría de seguridad completa ni permite garantizar que el archivo sea seguro. Las conclusiones se limitan a los componentes y características que fueron examinados.

---

## 2. Artefacto analizado

| Propiedad               | Información                              |
| ----------------------- | ---------------------------------------- |
| Archivo                 | `MSO365-English-.tar.zst`                |
| Tipo                    | Archivo TAR comprimido con Zstandard     |
| Tamaño aproximado       | 1.5 GB                                   |
| Contenido               | Entorno preconfigurado de Wine/CrossOver |
| Software principal      | Microsoft Office 365                     |
| Plataforma del análisis | Fedora Linux x86_64                      |
| Tipo de análisis        | Principalmente estático                  |

El archivo contiene un entorno completo de Wine/CrossOver y no únicamente un instalador de Microsoft Office.

---

## 3. Metodología

El análisis siguió un procedimiento progresivo:

```text
Identificación
      ↓
Inspección del archivo
      ↓
Inventario de contenido
      ↓
Identificación de componentes
      ↓
Extracción selectiva
      ↓
Análisis de binarios
      ↓
Análisis de imports/exports
      ↓
Análisis de strings
      ↓
Comprobación de firmas
      ↓
Evaluación de hallazgos
```

El objetivo fue evitar la ejecución innecesaria de componentes desconocidos durante las primeras etapas.

---

## 4. Identificación del archivo

Se obtuvo el hash SHA-256 del archivo:

```bash
sha256sum ./MSO365-English-.tar.zst
```

El tipo de archivo fue identificado mediante:

```bash
file ./MSO365-English-.tar.zst
```

El contenido fue inspeccionado sin extraerlo mediante:

```bash
tar -I zstd -tf ./MSO365-English-.tar.zst
```

Para obtener información detallada:

```bash
tar -I zstd -tvf ./MSO365-English-.tar.zst
```

Debido al volumen de información generado, el listado detallado puede dividirse en archivos más pequeños:

```bash
split -l 500 output-02-detailed.txt output-02-part-
```

---

## 5. Inventario inicial

El contenido del archivo mostró estructuras características de entornos Wine/CrossOver.

Entre ellas se identificaron directorios como:

```text
desktopdata/
desktopdata/cxassoc/
desktopdata/cxassoc/Scripts/
desktopdata/cxassoc/tagged_icons/
desktopdata/cxmenu/
desktopdata/cxmenu/Shortcuts/
desktopdata/cxmenu/Launchers/
```

También se identificaron componentes relacionados con Microsoft Office:

```text
Microsoft Office/
officeclicktorun.exe
integrator.exe
DeploymentConfig.0.xml
DeploymentConfig.2.xml
stream.x86.en-us.dat
v32_16.0.12527.22286.cab
```

El entorno contiene además información correspondiente a usuarios y configuraciones previamente existentes, incluyendo referencias a:

```text
crossover/
formateando/
```

La estructura observada es consistente con un **Bottle o prefijo de Wine/CrossOver previamente configurado**, en lugar de un instalador convencional de Office.

---

## 6. Evidencia de uso previo

Durante el inventario se encontraron archivos de registro cuyos nombres incluyen:

```text
LINUXMINT-20260207-2102a.log
LINUXMINT-20260207-2143a.log
```

Estos nombres contienen referencias a Linux Mint y a febrero de 2026.

Esto constituye un indicio de que el entorno fue generado o utilizado previamente en un sistema Linux Mint.

No debe interpretarse el nombre de estos archivos como prueba absoluta del sistema en el que se creó originalmente el Bottle, ya que los nombres de archivos pueden ser modificados. Sin embargo, son evidencia relevante sobre la procedencia aparente del entorno.

---

## 7. Identificación de componentes adicionales

Durante el inventario se encontraron elementos que no forman parte de una instalación estándar de Office y que requieren consideración independiente.

El componente más relevante identificado fue:

```text
ohook/
```

Dentro de este directorio se encontraron:

```text
LICENSE
readme.md
sppc32.dll
sppc64.dll
sppcplus32.dll
sppcplus64.dll
```

También se encontraron wrappers específicos para las aplicaciones de Office:

```text
Wrappers/
├── excel365.sh
├── outlook365.sh
├── powerpoint365.sh
├── word365.sh
├── publisher365.sh
├── access365.sh
└── limpiar_office-wine365.sh
```

La presencia de estos archivos demuestra que el entorno incluye modificaciones y herramientas adicionales alrededor de la instalación de Office.

---

# 8. Componente `ohook`

## 8.1 Identificación

El archivo `readme.md` incluido junto con `ohook` describe el proyecto como un mecanismo destinado a realizar hooking sobre componentes relacionados con el sistema de licenciamiento de Microsoft Office.

La documentación incluida hace referencia a funciones de Software Licensing utilizadas por Office.

Entre las funciones identificadas se encuentran:

```text
SLGetLicensingStatusInformation
SLGetProductSkuInformation
SLGetLicense
SLGetLicenseInformation
SLInstallLicense
SLUninstallLicense
```

También se documentan mecanismos relacionados con la información del estado de activación.

---

## 8.2 Interpretación

La presencia de `ohook` permite establecer que el Bottle no corresponde a una instalación estándar de Microsoft Office.

El entorno contiene un componente de terceros diseñado para modificar o interceptar determinados comportamientos relacionados con el sistema de licenciamiento de Office.

Esto es relevante tanto desde el punto de vista de seguridad como desde el punto de vista legal y de licenciamiento.

Sin embargo:

> **La existencia de un mecanismo de modificación del licenciamiento no demuestra por sí misma que el componente sea malware.**

Para determinar si existe comportamiento malicioso sería necesario analizar el componente desde otras perspectivas y, potencialmente, realizar análisis dinámico controlado.

---

# 9. Extracción selectiva de los DLL

Para analizar los componentes de `ohook` sin ejecutar el Bottle completo, se extrajeron únicamente los cuatro DLL relevantes.

Se creó un directorio de análisis:

```bash
mkdir -p ./ohook-analysis
```

Posteriormente se extrajeron:

```text
sppc32.dll
sppc64.dll
sppcplus32.dll
sppcplus64.dll
```

La extracción se realizó directamente desde el archivo comprimido:

```bash
for f in \
  MSO365-English-/.Microsoft_Office_365/drive_c/ohook/sppc32.dll \
  MSO365-English-/.Microsoft_Office_365/drive_c/ohook/sppcplus32.dll \
  MSO365-English-/.Microsoft_Office_365/drive_c/ohook/sppcplus64.dll \
  MSO365-English-/.Microsoft_Office_365/drive_c/ohook/sppc64.dll
do
    name="$(basename "$f")"
    tar -I zstd -xOf ./MSO365-English-.tar.zst "$f" > "./ohook-analysis/$name"
done
```

Los archivos no fueron ejecutados durante esta etapa.

---

# 10. Identificación PE

Se utilizó:

```bash
file ./ohook-analysis/*.dll
```

Los resultados identificaron:

```text
sppc32.dll
PE32 executable for MS Windows 6.00 (DLL), Intel i386
```

```text
sppc64.dll
PE32+ executable for MS Windows 6.00 (DLL), x86-64
```

```text
sppcplus32.dll
PE32 executable for MS Windows 6.00 (DLL), Intel i386
```

```text
sppcplus64.dll
PE32+ executable for MS Windows 6.00 (DLL), x86-64
```

Las variantes `32` corresponden a binarios x86 y las variantes `64` a binarios x86-64.

Las variantes `plus` corresponden a una segunda variante funcional del componente.

---

# 11. Firmas digitales

Se comprobó la presencia de firmas Authenticode en los cuatro DLL.

Los resultados indicaron:

```text
No signature found
Unable to extract existing signature
```

La información de los encabezados PE también mostró un directorio de seguridad sin datos de firma.

Por tanto, los cuatro DLL analizados **no contienen una firma Authenticode incrustada**.

Esto impide tratarlos como binarios autenticados mediante una firma digital de Microsoft.

Sin embargo:

> **La ausencia de una firma digital no demuestra que un binario sea malicioso.**

Es compatible con un componente de terceros desarrollado y distribuido fuera de los mecanismos de firma de Microsoft.

---

# 12. Timestamps de los binarios

Los timestamps PE observados fueron aproximadamente:

```text
sppc32.dll      Tue Mar 12 05:54:22 2024
sppc64.dll      Tue Mar 12 05:54:23 2024
sppcplus32.dll  Tue Mar 12 05:54:23 2024
sppcplus64.dll  Tue Mar 12 05:54:24 2024
```

Los cuatro binarios presentan timestamps prácticamente consecutivos.

Esto es consistente con archivos pertenecientes a un mismo conjunto de compilación.

Los timestamps PE no deben considerarse una prueba criptográfica de procedencia, ya que pueden modificarse.

---

# 13. Análisis de strings

Se realizó una búsqueda estática de cadenas relacionadas con posibles capacidades de:

* comunicación de red;
* descarga de archivos;
* ejecución de procesos;
* PowerShell;
* `cmd.exe`;
* scripting de Windows;
* modificación de licencias.

Entre las cadenas buscadas se incluyeron:

```text
http
https
powershell
cmd.exe
wscript
cscript
CreateProcess
WinExec
URLDownload
Internet
registry
license
activation
office
```

Los DLL contenían numerosas referencias relacionadas con el sistema de licenciamiento, entre ellas:

```text
SLGetLicensingStatusInformation
SLGetProductSkuInformation
SLGetLicense
SLGetLicenseInformation
SLInstallLicense
SLUninstallLicense
SLpClearActivationInProgress
SLpDepositTokenActivationResponse
SLpGenerateTokenActivationChallenge
SLpGetTokenActivationGrantInfo
SLpSetActivationInProgress
```

No se observaron en estos cuatro DLL cadenas evidentes que indiquen directamente:

```text
HTTP/HTTPS
PowerShell
cmd.exe
URLDownload
CreateProcess
WinExec
```

### Interpretación

El conjunto de strings observado es coherente con la finalidad declarada del componente.

No obstante, el análisis de strings tiene limitaciones importantes. La ausencia de una cadena no demuestra que una funcionalidad no exista, ya que puede utilizarse resolución dinámica de APIs, código ofuscado, hashes de funciones u otros mecanismos.

Por ello, estos resultados deben considerarse **indicadores estáticos**, no una prueba definitiva de ausencia de determinadas capacidades.

---

# 14. Imports de `sppc32.dll`

Los imports identificados fueron:

```text
sppcs.dll
    SLGetLicensingStatusInformation
    SLGetProductSkuInformation
```

y:

```text
KERNEL32.dll
    LocalFree
```

Las dependencias observadas están relacionadas principalmente con el sistema de licenciamiento de Windows y la administración de memoria.

No se observaron imports directos de bibliotecas de red o de creación de procesos en el conjunto analizado.

---

# 15. Imports de `sppc64.dll`

El patrón observado fue equivalente al de la versión de 32 bits:

```text
sppcs.dll
    SLGetLicensingStatusInformation
    SLGetProductSkuInformation
```

y:

```text
KERNEL32.dll
    LocalFree
```

La versión x64 presenta, por tanto, una estructura de imports equivalente a la variante x86.

---

# 16. Imports de `sppcplus32.dll`

Los imports identificados fueron:

```text
sppcs.dll
    SLGetLicensingStatusInformation
    SLGetProductSkuInformation
```

y:

```text
ADVAPI32.dll
    RegCloseKey
```

La función adicional observada es:

```text
RegCloseKey
```

Esta función forma parte de la API de registro de Windows y se utiliza para cerrar una clave previamente abierta.

La presencia de este import, por sí sola, no constituye un indicador de comportamiento malicioso.

---

# 17. Imports de `sppcplus64.dll`

El patrón coincide con `sppcplus32.dll`:

```text
sppcs.dll
    SLGetLicensingStatusInformation
    SLGetProductSkuInformation
```

y:

```text
ADVAPI32.dll
    RegCloseKey
```

Las variantes `plus` de 32 y 64 bits presentan, por tanto, una estructura equivalente.

---

# 18. Hallazgos

A partir del análisis realizado pueden establecerse los siguientes hallazgos.

### Confirmado

El archivo analizado:

```text
MSO365-English-.tar.zst
```

contiene un entorno preconfigurado de Wine/CrossOver que incluye Microsoft Office.

El archivo no corresponde únicamente a un instalador de Microsoft Office.

El entorno contiene:

* componentes de Wine/CrossOver;
* configuraciones personalizadas;
* launchers y wrappers;
* archivos relacionados con Office;
* componentes adicionales de terceros.

Se identificó el componente:

```text
ohook
```

y cuatro DLL asociados:

```text
sppc32.dll
sppc64.dll
sppcplus32.dll
sppcplus64.dll
```

La documentación incluida con `ohook` indica que su finalidad está relacionada con la modificación/intercepción del sistema de licenciamiento de Office.

Los cuatro DLL analizados:

* son binarios PE válidos;
* incluyen variantes x86 y x86-64;
* no contienen firmas Authenticode;
* presentan timestamps PE muy próximos entre sí;
* importan funciones relacionadas con el sistema de licenciamiento;
* no mostraron strings evidentes asociados directamente con HTTP, PowerShell, `cmd.exe`, `CreateProcess` o `WinExec`.

---

# 19. Hallazgos no concluyentes

Los resultados anteriores **no permiten establecer que el Bottle completo sea seguro**.

Tampoco permiten establecer que el Bottle completo sea malicioso.

El análisis realizado hasta este punto se concentró principalmente en el componente `ohook` y en la estructura general del archivo.

Todavía deben analizarse otros componentes potencialmente relevantes.

Entre ellos:

```text
*.sh
*.bat
*.cmd
*.ps1
*.vbs
*.wsf
*.reg
*.exe
*.dll
*.msi
*.sys
```

También deben revisarse:

* scripts de instalación;
* wrappers;
* launchers;
* configuración de Wine/CrossOver;
* ejecutables fuera de las rutas habituales de Office;
* modificaciones del registro;
* configuración de red;
* mecanismos de persistencia;
* binarios modificados;
* componentes adicionales no relacionados directamente con Office.

---

# 20. Limitaciones del análisis

Este documento describe un análisis estático y progresivo.

No se realizaron, como parte de esta fase:

* análisis dinámico completo;
* captura de tráfico de red;
* ejecución instrumentada;
* sandboxing;
* comparación binaria completa contra una instalación oficial;
* análisis exhaustivo de todos los ejecutables del Bottle;
* auditoría completa de todos los scripts;
* análisis de comportamiento durante la activación de Office.

Por tanto, las conclusiones deben interpretarse dentro de este alcance.

En particular:

> **La ausencia de indicadores maliciosos en los componentes examinados no constituye una certificación de seguridad del archivo completo.**

---

# 21. Estado del análisis

| Área                                     | Estado     |
| ---------------------------------------- | ---------- |
| Identificación del archivo               | Completado |
| Inventario de contenido                  | Completado |
| Identificación del Bottle                | Completado |
| Identificación de `ohook`                | Completado |
| Análisis de los cuatro DLL de `ohook`    | Completado |
| Comprobación de firmas                   | Completado |
| Análisis básico de strings               | Completado |
| Análisis de imports                      | Completado |
| Análisis de wrappers                     | Pendiente  |
| Análisis de scripts                      | Pendiente  |
| Análisis de ejecutables restantes        | Pendiente  |
| Análisis de configuración Wine/CrossOver | Pendiente  |
| Análisis de red                          | Pendiente  |
| Comparación con instalación oficial      | Pendiente  |
| Análisis dinámico                        | Pendiente  |

---

# 22. Conclusión

El análisis permitió determinar que `MSO365-English-.tar.zst` contiene un entorno Wine/CrossOver previamente configurado para ejecutar Microsoft Office 365 y que dicho entorno incorpora componentes adicionales a la instalación estándar de Office.

El hallazgo principal es la inclusión de `ohook`, un componente de terceros destinado a intervenir en el sistema de licenciamiento de Office.

Los cuatro DLL analizados presentan características coherentes con esta finalidad y, durante el análisis estático realizado, no mostraron indicadores evidentes de funcionalidades de red, descarga o ejecución de procesos externos.

Sin embargo, estos resultados no son suficientes para considerar seguro el Bottle completo.

La evaluación debe continuar sobre los demás componentes del entorno antes de realizar una conclusión general sobre su seguridad.

Por esta razón, el proyecto trata este archivo como un **artefacto de terceros que requiere confianza informada**, y no como un instalador oficial o un componente cuya seguridad pueda asumirse.

---

## 23. Principio de análisis utilizado

La investigación de este método sigue el siguiente principio:

> **No ejecutar primero y preguntar después.**

Los componentes desconocidos deben, siempre que sea posible, identificarse e inspeccionarse antes de su ejecución.

El objetivo no es demostrar que un método de terceros sea seguro por defecto, sino proporcionar suficiente información para que sus componentes, procedencia, modificaciones y limitaciones puedan ser evaluados de manera transparente.

El análisis de seguridad es independiente de la adaptación técnica del método para Fedora: que una instalación funcione correctamente no implica que sus componentes de terceros deban considerarse confiables automáticamente.
