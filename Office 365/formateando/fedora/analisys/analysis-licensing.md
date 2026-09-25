# Análisis de licenciamiento, SPP y `ohook`

## 1. Alcance

Como parte del análisis estático del Bottle:

```text
MSO365-English-.tar.zst
```

se realizó una revisión específica de los componentes relacionados con el sistema de licenciamiento de Microsoft Office.

Esta investigación se centró en:

* el archivo `hosts` incluido en el Bottle;
* la configuración `Software\Wine\DllOverrides`;
* la entrada `"sppc"="disable"`;
* los componentes `sppc.dll` y `sppcs.dll`;
* los componentes incluidos en `ohook`;
* las interfaces de licenciamiento utilizadas por dichos componentes;
* posibles indicadores de comunicación externa o ejecución de código ajena a su función declarada.

El análisis fue realizado exclusivamente de forma estática. **No se ejecutaron binarios, scripts ni el Bottle durante esta etapa.**

---

# 2. Análisis del archivo `hosts`

Primero se comprobó si el Bottle incluía un archivo `hosts` propio:

```bash
tar -I zstd -tf ./MSO365-English-.tar.zst \
| grep -E '/etc/hosts$|/hosts$'
```

El resultado fue:

```text
MSO365-English-/.Microsoft_Office_365/drive_c/windows/system32/drivers/etc/hosts
```

El archivo fue extraído directamente desde el TAR:

```bash
tar -I zstd -xOf ./MSO365-English-.tar.zst \
'MSO365-English-/.Microsoft_Office_365/drive_c/windows/system32/drivers/etc/hosts'
```

Contenido observado:

```text
# 127.0.0.1 localhost
```

No se identificaron entradas correspondientes a dominios de Microsoft ni redirecciones de dominios relacionados con la activación.

En particular, no se encontró una entrada como:

```text
0.0.0.0 ols.officeapps.live.com
```

ni:

```text
127.0.0.1 ols.officeapps.live.com
```

### Interpretación

El Bottle contiene un archivo `hosts` personalizado, pero el contenido analizado **no muestra evidencia de que se utilice para bloquear o redirigir servidores de Microsoft**.

Esto es relevante porque `ohook` contempla mecanismos de modificación del comportamiento de activación que pueden complementarse con cambios en `hosts`. Sin embargo, ese mecanismo concreto no se observó en este Bottle.

### Resultado

**🟢 Sin evidencia de bloqueo de dominios de activación mediante `hosts`.**

---

# 3. Configuración `Wine\DllOverrides`

Se inspeccionó la sección correspondiente del registro de Wine:

```bash
sed -n '9420,9510p' ./registry-analysis/user.reg
```

La sección identificada fue:

```text
[Software\\Wine\\DllOverrides] 1770526955
```

Dentro de ella aparecen diversas configuraciones habituales de DLL de Wine, entre ellas:

```text
"crypt32"="native, builtin"
"mshtml"="native, builtin"
"msi"="builtin"
"msvcp140"="native,builtin"
"msvcrt40"="native, builtin"
"msxml6"="native, builtin"
"ole32"="builtin"
"oleaut32"="builtin"
"rpcrt4"="builtin"
"secur32"="native, builtin"
"softpub"="native, builtin"
"sppc"="disable"
"urlmon"="native, builtin"
"wininet"="builtin"
"wintrust"="native, builtin"
```

La entrada de especial interés es:

```text
"sppc"="disable"
```

### Interpretación

La entrada se encuentra directamente dentro de:

```text
Software\Wine\DllOverrides
```

Por lo tanto, no corresponde simplemente a una cadena encontrada dentro de un ejecutable.

Se trata de una configuración del Bottle que indica a Wine que el DLL denominado:

```text
sppc
```

debe ser deshabilitado mediante el mecanismo de `DllOverrides`.

Este dato adquiere importancia al compararlo con los archivos presentes en:

```text
drive_c/windows/system32/
```

y:

```text
drive_c/ohook/
```

---

# 4. Inventario de componentes SPP

Se realizó una búsqueda dentro del archivo comprimido:

```bash
tar -I zstd -tvf ./MSO365-English-.tar.zst \
| grep -Ei '/(sppc|sppcs|sppcplus|sppc32|sppc64)(\.dll)?$'
```

Entre los resultados se identificaron:

```text
drive_c/ohook/sppc32.dll
drive_c/ohook/sppc64.dll
```

Además de múltiples copias de:

```text
sppcs.dll
```

dentro de las rutas correspondientes a Microsoft Office.

También se identificó:

```text
drive_c/windows/system32/sppc.dll
```

Los tamaños y fechas observados fueron:

| Componente            |        Tamaño | Fecha observada  |
| --------------------- | ------------: | ---------------- |
| `ohook/sppc32.dll`    |   9,216 bytes | 2026-02-07 23:10 |
| `ohook/sppc64.dll`    |   9,216 bytes | 2026-02-07 23:10 |
| `system32/sppc.dll`   | 108,582 bytes | 2026-02-07 23:47 |
| `Office.../sppcs.dll` | 179,800 bytes | 2025-11-24 14:56 |

Las copias de `sppcs.dll` aparecen distribuidas en diferentes ubicaciones de Office Click-to-Run.

---

# 5. Diferenciación entre `sppc.dll`, `sppcs.dll` y `ohook`

Es importante no tratar todos los archivos con nombres similares como si fueran el mismo componente.

En el Bottle se identifican al menos tres grupos funcionalmente diferentes:

### `system32/sppc.dll`

Ubicado en:

```text
drive_c/windows/system32/sppc.dll
```

Fue identificado mediante sus cadenas como un componente builtin de Wine/CrossOver.

### `sppcs.dll`

Ubicado dentro de diferentes directorios de Microsoft Office:

```text
OfficeSoftwareProtectionPlatform/
Microsoft Office/Office16/
Microsoft Office/root/Office16/
```

Forma parte de la infraestructura de protección/licenciamiento utilizada por Office.

### `ohook/sppc32.dll` y `ohook/sppc64.dll`

Ubicados en:

```text
drive_c/ohook/
```

Son componentes adicionales asociados al mecanismo `ohook` y no deben confundirse con el `sppc.dll` builtin de Wine.

Esta distinción es fundamental para interpretar correctamente el Bottle.

---

# 6. Extracción controlada

Se extrajeron individualmente los siguientes componentes:

```bash
mkdir -p ./ohook-analysis/current
```

```bash
tar -I zstd -xOf ./MSO365-English-.tar.zst \
'MSO365-English-/.Microsoft_Office_365/drive_c/windows/system32/sppc.dll' \
> ./ohook-analysis/current/sppc.dll
```

```bash
tar -I zstd -xOf ./MSO365-English-.tar.zst \
'MSO365-English-/.Microsoft_Office_365/drive_c/ohook/sppc32.dll' \
> ./ohook-analysis/current/sppc32.dll
```

```bash
tar -I zstd -xOf ./MSO365-English-.tar.zst \
'MSO365-English-/.Microsoft_Office_365/drive_c/ohook/sppc64.dll' \
> ./ohook-analysis/current/sppc64.dll
```

Ninguno de los archivos fue ejecutado.

La identificación mediante `file` produjo:

```text
./ohook-analysis/current/sppc32.dll:
PE32 executable for MS Windows 6.00 (DLL),
Intel i386 (stripped to external PDB), 7 sections

./ohook-analysis/current/sppc64.dll:
PE32+ executable for MS Windows 6.00 (DLL),
x86-64 (stripped to external PDB), 7 sections

./ohook-analysis/current/sppc.dll:
PE32 executable for WINE (DLL),
Intel i386, 16 sections
```

---

# 7. Hashes de los componentes

Se calcularon hashes SHA-256 para conservar una identificación reproducible de los archivos analizados:

```bash
sha256sum ./ohook-analysis/current/*
```

Resultados obtenidos:

```text
7a0203c7f92568c82cda14a3cc58e04308e90281282741f6feddf3a283f0b290  sppc32.dll
30f2651daae68e2f3c9faec1d2c9621f3ba514764425691508bf661d4652847b  sppc64.dll
ad44099e192274ba6567cc59f3ff5acab3139c7e0dc47e3ce9b06a0402f50182  sppc.dll
```

Los hashes muestran que `sppc.dll` y los componentes de `ohook` son binarios diferentes.

Por tanto, `system32/sppc.dll` no es simplemente una copia renombrada de `ohook/sppc32.dll` o `ohook/sppc64.dll`.

---

# 8. Identificación de `system32/sppc.dll`

Se realizó una búsqueda estática de cadenas:

```bash
strings -a ./ohook-analysis/current/sppc.dll \
| grep -Ei 'wine|sppc|license|licens|office|microsoft|kernel32|advapi|rpc|http|url|CreateProcess'
```

Entre los resultados más relevantes aparecen:

```text
Wine builtin DLL
sppc.dll
```

También se identificó:

```text
../winecx/dlls/sppc/sppc.c
/home/formateando/wine32-build
```

Además aparecen múltiples interfaces relacionadas con Software Licensing:

```text
SLpGetLicenseAcquisitionInfo
SLGetActiveLicenseInfo
SLGetLicense
SLGetLicenseFileId
SLGetLicenseInformation
SLInstallLicense
SLUninstallLicense
SLGetLicensingStatusInformation
```

También aparecen estados relacionados con licenciamiento:

```text
SL_LICENSING_STATUS_UNLICENSED
SL_LICENSING_STATUS_LICENSED
SL_LICENSING_STATUS_IN_GRACE_PERIOD
SL_LICENSING_STATUS_NOTIFICATION
```

Y numerosos stubs de Wine, incluyendo referencias como:

```text
___wine_stub_SLCallServer
___wine_stub_SLGetActiveLicenseInfo
___wine_stub_SLGetLicense
___wine_stub_SLInstallLicense
___wine_stub_SLUninstallLicense
___wine_stub_SLSetCurrentProductKey
___wine_stub_SLReArm
```

### Interpretación

La evidencia identifica `system32/sppc.dll` como una implementación builtin de Wine/CrossOver relacionada con las APIs de Software Licensing de Windows.

La referencia:

```text
../winecx/dlls/sppc/sppc.c
```

es particularmente relevante porque indica que el componente procede de un árbol de código relacionado con `winecx`, utilizado por CrossOver.

La ruta:

```text
/home/formateando/wine32-build
```

proporciona además información sobre el entorno utilizado para generar ese binario.

Por sí mismo, `system32/sppc.dll` **no debe clasificarse como malware ni como un activador externo**.

### Resultado

**🟢 Componente coherente con Wine/CrossOver.**

---

# 9. Análisis de `ohook/sppc32.dll` y `sppc64.dll`

Los dos DLL incluidos en:

```text
drive_c/ohook/
```

fueron analizados mediante inspección de cadenas.

Se encontraron numerosas referencias a interfaces del sistema de licenciamiento SPP, entre ellas:

```text
SPPCS.SLCallServer
SPPCS.SLClose
SPPCS.SLConsumeRight
SPPCS.SLDepositMigrationBlob
SPPCS.SLDepositOfflineConfirmationId
SPPCS.SLGetActiveLicenseInfo
SPPCS.SLGetApplicationInformation
SPPCS.SLGetApplicationPolicy
SPPCS.SLGetAuthenticationResult
SPPCS.SLGetGenuineInformation
SPPCS.SLGetInstalledProductKeyIds
SPPCS.SLGetLicense
SPPCS.SLGetLicenseFileId
SPPCS.SLGetLicenseInformation
SPPCS.SLGetPKeyId
SPPCS.SLGetPKeyInformation
SPPCS.SLGetPolicyInformation
SPPCS.SLGetProductSkuInformation
SPPCS.SLGetServiceInformation
SPPCS.SLInstallLicense
SPPCS.SLInstallProofOfPurchase
SPPCS.SLIsGenuineLocalEx
SPPCS.SLLoadApplicationPolicies
SPPCS.SLPersistApplicationPolicies
SPPCS.SLPersistRTSPayloadOverride
SPPCS.SLReArm
SPPCS.SLRegisterEvent
SPPCS.SLRegisterPlugin
SPPCS.SLSetAuthenticationData
SPPCS.SLSetCurrentProductKey
SPPCS.SLSetGenuineInformation
SPPCS.SLUninstallLicense
SPPCS.SLUnloadApplicationPolicies
SPPCS.SLUnregisterPlugin
```

También se identificaron interfaces de nivel inferior relacionadas con activación y validación:

```text
SPPCS.SLpAuthenticateGenuineTicketResponse
SPPCS.SLpBeginGenuineTicketTransaction
SPPCS.SLpClearActivationInProgress
SPPCS.SLpDepositDownlevelGenuineTicket
SPPCS.SLpDepositTokenActivationResponse
SPPCS.SLpGenerateTokenActivationChallenge
SPPCS.SLpGetGenuineBlob
SPPCS.SLpGetGenuineLocal
SPPCS.SLpGetLicenseAcquisitionInfo
SPPCS.SLpGetMSPidInformation
SPPCS.SLpGetMachineUGUID
SPPCS.SLpGetTokenActivationGrantInfo
SPPCS.SLpIAActivateProduct
SPPCS.SLpIsCurrentInstalledProductKeyDefaultKey
SPPCS.SLpVLActivateProduct
```

Los binarios también contienen referencias a:

```text
sppcs.dll
KERNEL32.dll
```

### Indicadores no observados

En la búsqueda realizada no aparecieron referencias textuales evidentes a:

```text
powershell
cmd.exe
WinExec
ShellExecute
URLDownload
InternetOpen
InternetConnect
```

Tampoco se identificaron en esta inspección cadenas HTTP o URLs concretas asociadas con una infraestructura externa.

### Interpretación

El conjunto de interfaces encontradas es coherente con el propósito declarado de `ohook`: intervenir en determinadas operaciones relacionadas con la infraestructura de licenciamiento de Office.

No se observaron mediante esta inspección estática indicadores evidentes de que estos DLL incorporen adicionalmente una función de descarga de payloads o ejecución de comandos.

Esta observación debe interpretarse con cautela. La ausencia de determinadas cadenas no demuestra que una funcionalidad no exista, ya que un binario puede resolver APIs dinámicamente, almacenar datos de otra forma o implementar funcionalidades que no sean visibles mediante una búsqueda simple de strings.

### Resultado

**🟡 Componente de licenciamiento modificado; no se identificaron indicadores adicionales evidentes de malware en la inspección realizada.**

---

# 10. Relación entre `sppc`, `sppcs` y `ohook`

La evidencia permite representar de forma simplificada la arquitectura observada:

```text
Microsoft Office
       │
       ▼
OfficeSoftwareProtectionPlatform
       │
       ▼
   sppcs.dll
       ▲
       │
       │
  interfaces SPP
       │
 ┌─────┴─────┐
 │           │
 ▼           ▼
ohook      Wine/CrossOver
 │              │
 ├─ sppc32.dll  └─ system32/sppc.dll
 └─ sppc64.dll
```

Paralelamente, Wine contiene la configuración:

```text
Software\Wine\DllOverrides

"sppc"="disable"
```

La combinación de estos elementos proporciona evidencia consistente de una modificación deliberada del tratamiento de `sppc` dentro del Bottle.

---

# 11. Significado de `sppc=disable`

La entrada:

```text
"sppc"="disable"
```

no debe interpretarse aisladamente como:

> "`sppc.dll` es malware."

Lo que demuestra es que el Bottle contiene una configuración específica de Wine destinada a modificar la forma en que se carga o utiliza ese DLL.

Al observar simultáneamente:

```text
drive_c/windows/system32/sppc.dll
```

y:

```text
drive_c/ohook/sppc32.dll
drive_c/ohook/sppc64.dll
```

la interpretación más consistente es que el entorno fue preparado para alterar el comportamiento habitual de la infraestructura SPP utilizada por Office.

Esta interpretación coincide además con la documentación incluida junto con `ohook`, donde se describe el mecanismo como una modificación de componentes relacionados con la activación de Office.

---

# 12. Ausencia de bloqueo mediante `hosts`

Un resultado importante de esta investigación es que no se encontró el mecanismo alternativo de bloqueo de servidores de activación mediante `hosts`.

El archivo contiene únicamente:

```text
# 127.0.0.1 localhost
```

dentro del contenido analizado.

Por lo tanto, no existe evidencia en este Bottle de una configuración equivalente a:

```text
0.0.0.0 ols.officeapps.live.com
```

Esto permite distinguir entre:

```text
modificación de SPP mediante DLL/hooking
```

y:

```text
bloqueo de servidores mediante hosts
```

El primer mecanismo sí está respaldado por la evidencia encontrada; el segundo no.

---

# 13. Indicadores que no se han encontrado

En las áreas examinadas hasta esta etapa no se encontró evidencia directa de:

* un servidor KMS externo configurado dentro de los componentes analizados;
* redirecciones de dominios de Microsoft mediante `hosts`;
* un payload de PowerShell;
* scripts destinados a descargar una carga externa;
* ejecución evidente de `cmd.exe`;
* funciones de descarga explícitas dentro de los DLL de `ohook` analizados;
* un ejecutable externo claramente identificado como malware;
* una relación evidente entre `ohook` y una infraestructura remota maliciosa.

Estos resultados reducen el conjunto de hipótesis posibles, pero **no constituyen una certificación de seguridad del Bottle completo**.

---

# 14. Distinción entre modificación de activación y malware

Uno de los objetivos principales de esta investigación es evitar mezclar dos conceptos diferentes.

## Modificación de licenciamiento

Está respaldada por múltiples evidencias independientes:

```text
drive_c/ohook/
```

```text
sppc32.dll
sppc64.dll
```

```text
"sppc"="disable"
```

y las interfaces de Software Licensing presentes en los DLL.

Por tanto, puede afirmarse que el Bottle contiene una **modificación deliberada relacionada con la activación/licenciamiento de Office**.

## Malware

En cambio, hasta esta etapa no se ha identificado un indicador directo que permita afirmar que `ohook` o los componentes analizados sean malware.

La funcionalidad observada está concentrada en interfaces relacionadas con el sistema de licenciamiento.

Por ello, las conclusiones deben mantenerse separadas:

> **La modificación del sistema de activación está confirmada. La presencia de malware no está demostrada por este análisis.**

---

# 15. Estado de la investigación

| Área                                           | Estado                                                 |
| ---------------------------------------------- | ------------------------------------------------------ |
| `hosts`                                        | 🟢 Revisado                                            |
| Bloqueo de dominios Microsoft mediante `hosts` | 🟢 No observado                                        |
| `Wine\DllOverrides`                            | 🟢 Revisado                                            |
| `"sppc"="disable"`                             | 🟢 Confirmado                                          |
| `system32/sppc.dll`                            | 🟢 Identificado como Wine/CrossOver                    |
| `sppcs.dll` de Office                          | 🟢 Identificado dentro de la infraestructura de Office |
| `ohook/sppc32.dll`                             | 🟢 Analizado                                           |
| `ohook/sppc64.dll`                             | 🟢 Analizado                                           |
| Interfaces de licenciamiento                   | 🟢 Identificadas                                       |
| Indicadores de PowerShell/CMD en `ohook`       | 🟢 No observados                                       |
| Indicadores HTTP/descarga en `ohook`           | 🟢 No observados en la inspección realizada            |
| KMS externo                                    | 🟡 Pendiente de revisión global                        |
| Registro completo de Wine                      | 🟡 En investigación                                    |
| Configuración de red global                    | ⏳ Pendiente                                            |
| Análisis dinámico                              | ⏳ Pendiente                                            |
| Comparación con componentes de referencia      | ⏳ Pendiente                                            |

---

# 16. Conclusión

La evidencia recopilada permite establecer con un alto nivel de confianza que el Bottle contiene una **modificación deliberada de la infraestructura de licenciamiento de Microsoft Office**.

La evidencia principal está formada por la combinación de:

```text
Software\Wine\DllOverrides
"sppc"="disable"
```

con:

```text
drive_c/ohook/sppc32.dll
drive_c/ohook/sppc64.dll
```

y las numerosas interfaces de Software Licensing identificadas dentro de dichos DLL.

Al mismo tiempo, el archivo:

```text
drive_c/windows/system32/sppc.dll
```

presenta características consistentes con una implementación builtin de Wine/CrossOver, incluyendo referencias a:

```text
Wine builtin DLL
../winecx/dlls/sppc/sppc.c
```

Por lo tanto, este componente no debe confundirse con `ohook`.

Tampoco se encontró evidencia de que el Bottle utilice el archivo `hosts` para bloquear `ols.officeapps.live.com` u otros dominios de Microsoft.

En los DLL de `ohook` examinados no se observaron indicadores textuales evidentes de PowerShell, `cmd.exe`, ejecución de procesos o descarga HTTP. Sin embargo, esta ausencia no permite descartar completamente funcionalidades no visibles mediante análisis de strings.

### Conclusión provisional

> **El Bottle analizado es un entorno Wine/CrossOver preconfigurado que contiene Microsoft Office y una modificación deliberada de su infraestructura de activación mediante `ohook`. La evidencia examinada hasta esta etapa no demuestra la presencia de malware, pero tampoco permite certificar la seguridad del Bottle completo.**

La investigación debe continuar con el análisis de la configuración completa de Wine, posibles entradas de persistencia, configuración de red, proxies, dominios externos, inventario completo de binarios y comparación con componentes de referencia.

---

# 17. Relación con la documentación del método

Este análisis forma parte de la documentación técnica del método de Microsoft Office 365 basado en el Bottle distribuido originalmente por **Formateando**.

El hallazgo de `ohook` debe reflejarse explícitamente en la documentación de instalación y seguridad del método.

En particular, el Bottle debe describirse como:

```text
Bottle preconfigurado de terceros
+
Microsoft Office
+
componentes Wine/CrossOver
+
modificación de la infraestructura de activación mediante ohook
```

y no como una instalación limpia de Microsoft Office.

La instalación del Bottle tampoco debe presentar la eliminación de `ohook` como una garantía de que se ha restaurado el mecanismo original de licenciamiento, ya que una modificación de este tipo puede involucrar componentes adicionales del registro o del entorno Wine.

Por esta razón, la documentación del método debe diferenciar claramente:

1. **instalación del Bottle;**
2. **configuración necesaria de Wine;**
3. **componentes de terceros incluidos en el Bottle;**
4. **modificaciones del sistema de licenciamiento;**
5. **consideraciones de seguridad y licencia;**
6. **adaptaciones realizadas posteriormente por Office on Linux.**
