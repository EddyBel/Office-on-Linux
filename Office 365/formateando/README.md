# Microsoft Office 365 — Método Formateando

> Adaptación y documentación del método de **Formateando** para ejecutar Microsoft Office 365 mediante Wine/CrossOver en diferentes entornos Linux.

Esta carpeta contiene todo lo relacionado con el método de instalación de Microsoft Office 365 publicado originalmente por **Formateando**, incluyendo sus adaptaciones, pruebas de compatibilidad y análisis técnicos realizados por **Office on Linux**.

El objetivo es mantener el método original como referencia y, a partir de él, documentar las modificaciones necesarias para trasladar su configuración a diferentes distribuciones Linux.

---

# Sobre el método

El método utilizado como punto de partida fue desarrollado y publicado por:

**Formateando**

Canal original:

```text
https://www.youtube.com/@formateando
```

El procedimiento original utiliza un entorno preconfigurado de Microsoft Office 365 basado en Wine/CrossOver.

Conceptualmente:

```text
Método original de Formateando
             │
             ↓
     Bottle preconfigurado
             │
             ↓
      Microsoft Office 365
             │
             ↓
     Adaptación por entorno
             │
       ┌─────┼─────┐
       ↓     ↓     ↓
    Fedora Debian Arch
```

Este proyecto no considera que una adaptación para una distribución sea automáticamente válida para las demás.

Cada migración se prueba y documenta de forma independiente.

---

# Estructura

Esta carpeta se organiza alrededor de dos elementos principales:

```text
Formateando/
│
├── README.md
│
├── analysis/
│   ├── analysis.md
│   ├── analysis-cxwget.md
│   ├── analysis-licensing.md
│   ├── analysis-dxvk.md
│   ├── analysis-network.md
│   └── ...
│
├── Fedora/
│   └── ...
│
└── ...
```

## Directorios de plataformas

Cada carpeta de plataforma contiene la adaptación del método para un entorno Linux concreto.

Por ejemplo:

```text
Fedora/
```

contiene la adaptación realizada para Fedora.

En el futuro pueden incorporarse:

```text
Debian/
Ubuntu/
Linux-Mint/
Arch/
openSUSE/
...
```

La estructura y el contenido de cada adaptación pueden variar dependiendo de las necesidades de la distribución.

---

# Estado de las migraciones

La siguiente tabla se utilizará para registrar los sistemas a los que el método ha sido migrado y probado.

| Sistema    | Versión probada | Estado      | Arquitectura   | Notas                                                                                   |
| ---------- | --------------- | ----------- | -------------- | --------------------------------------------------------------------------------------- |
| **Fedora** | **Fedora 44**   | ✅ Probado   | Wine32 / win32 | Adaptación funcional del método, incluyendo DXVK y configuración específica para Fedora |
| Debian     | —               | ⏳ Pendiente | —              | —                                                                                       |
| Ubuntu     | —               | ⏳ Pendiente | —              | —                                                                                       |
| Linux Mint | —               | ⏳ Pendiente | —              | —                                                                                       |
| Arch Linux | —               | ⏳ Pendiente | —              | —                                                                                       |

> La tabla representa únicamente el estado de las migraciones documentadas en este repositorio. Un método reportado como funcional en una distribución no implica compatibilidad automática con otras.

---

# Fedora

La primera migración documentada corresponde a:

```text
Fedora 44
```

La adaptación fue probada utilizando:

```text
Fedora 44
Wine 11.0 Staging
Wine32
Winetricks 20260125
DXVK 3.1.1
Mesa 26.2.3
Vulkan 1.4.x
```

El Bottle utilizado corresponde a una instalación:

```text
Wine32
#arch=win32
```

Por esta razón, la adaptación utiliza explícitamente:

```bash
wine32
```

para ejecutar las aplicaciones del Bottle.

La adaptación también incorpora configuración específica para el entorno Fedora, incluyendo:

```text
Wine32
DXVK x32
Vulkan
fuentes
launchers
archivos .desktop
asociaciones MIME
integración con el escritorio
```

La documentación completa de esta adaptación se encuentra dentro de:

```text
Fedora/
```

---

# Aplicaciones probadas

Durante las pruebas realizadas sobre la adaptación Fedora se comprobó el inicio de las principales aplicaciones incluidas en el Bottle:

```text
[✓] Microsoft Word
[✓] Microsoft Excel
[✓] Microsoft PowerPoint
[✓] Microsoft Outlook
[✓] Microsoft Access
[✓] Microsoft Publisher
[✓] Microsoft OneNote
```

El hecho de que una aplicación pueda iniciarse no implica que todas sus funciones hayan sido validadas.

La compatibilidad debe entenderse en función de las pruebas concretas realizadas para cada aplicación.

---

# Análisis técnico

Además de las adaptaciones por distribución, esta carpeta contiene una serie de documentos de análisis realizados sobre el método y el Bottle.

Estos documentos se encuentran en:

```text
analysis/
```

El propósito de esta sección es permitir que cualquier persona interesada pueda revisar **qué se encontró durante las pruebas y cómo se llegó a las conclusiones documentadas**.

Actualmente pueden encontrarse análisis relacionados con:

```text
estructura del Bottle
componentes ejecutables
cxwget
licenciamiento
SPP / Office Software Protection Platform
ohook
Wine
DXVK
renderizado gráfico
actividad de red
```

---

# Documentos de análisis

## `analysis.md`

Análisis estático general del Bottle.

Incluye información sobre:

```text
estructura
archivos
componentes
ejecutables
DLL
metadatos
firmas
timestamps
strings
ohook
```

También documenta las limitaciones del análisis estático y qué conclusiones pueden o no extraerse de él.

---

## `analysis-cxwget.md`

Análisis específico de:

```text
cxwget.exe
```

El documento estudia su formato PE, strings, imports y comportamiento esperado como componente de Wine/CrossOver.

La finalidad es separar este ejecutable del resto del contenido del Bottle y analizarlo individualmente.

---

## `analysis-licensing.md`

Análisis de los componentes relacionados con el sistema de licenciamiento de Office.

Incluye:

```text
SPP
SPPCS
sppc.dll
ohook
DLL overrides
hosts
licensing catalogs
```

También diferencia entre los componentes propios de Wine/CrossOver y las modificaciones relacionadas con el comportamiento de licenciamiento.

---

## `analysis-dxvk.md`

Análisis del diagnóstico y reparación del problema gráfico encontrado durante la ejecución de Microsoft Word.

La prueba comparó:

```text
WineD3D
    ↓
Word → interfaz blanca
```

contra:

```text
DXVK 3.1.1
    ↓
Word → interfaz funcional
```

También documenta:

```text
Vulkan
Wine32
D3D11
DXGI
DXVK
font subsystem
Wayland
```

y las pruebas realizadas antes de determinar la corrección.

---

## `analysis-network.md`

Análisis dinámico de red realizado durante el acceso de Excel a plantillas online.

La prueba documenta:

```text
EXCEL.EXE
    ↓
TCP/443
    ↓
TLS
    ↓
SNI
    ↓
Microsoft Office / Microsoft 365 endpoints
```

Se incluye la captura PCAP utilizada durante la prueba y la identificación de los hostnames observados mediante TLS.

---

# Qué significan estos análisis

Los análisis no deben interpretarse como una certificación de seguridad del método.

Cada documento describe:

```text
qué se analizó
qué se observó
qué herramientas se utilizaron
qué evidencia se obtuvo
qué interpretación es compatible con esa evidencia
qué limitaciones existen
```

Por ejemplo:

```text
"No se observó X"
```

no debe interpretarse automáticamente como:

```text
"X no existe en todo el Bottle"
```

Las conclusiones están limitadas al alcance de cada prueba.

---

# Reproducibilidad

Siempre que sea posible, los análisis conservan:

```text
comandos utilizados
versiones
rutas
hashes
salidas relevantes
archivos de evidencia
```

Esto permite repetir las pruebas sobre el mismo Bottle o comparar posteriormente los resultados con nuevas versiones.

Las pruebas dinámicas deben considerarse dependientes del entorno.

Por ejemplo:

```text
Fedora 44
+
Wine 11.0 Staging
+
Wine32
+
DXVK 3.1.1
+
Mesa 26.2.3
```

no representa necesariamente el comportamiento que tendrá el mismo Bottle bajo otra combinación de:

```text
distribución
Wine
driver
GPU
Vulkan
DXVK
```

---

# Adaptaciones frente al método original

Las modificaciones realizadas durante una migración se documentan como parte de la adaptación y no como parte del procedimiento original.

Por ejemplo, para Fedora se realizaron modificaciones relacionadas con:

```text
APT
    ↓
DNF

wine
    ↓
wine32

rutas del sistema
    ↓
rutas XDG del usuario

configuración gráfica
    ↓
DXVK / Vulkan

integración global
    ↓
integración por usuario
```

Estas modificaciones corresponden a la adaptación realizada dentro de **Office on Linux**.

El método original de **Formateando** se mantiene como referencia independiente.

---

# Seguridad

El método utiliza un Bottle preconfigurado de terceros.

Esto significa que el contenido del Bottle debe considerarse independientemente de los scripts utilizados para instalarlo.

Un Wine Prefix puede contener:

```text
EXE
DLL
scripts
registro
fuentes
configuración
overrides
componentes de Office
```

Además, Wine no constituye un sandbox completo.

Por ello, los análisis incluidos aquí buscan proporcionar transparencia sobre el contenido y comportamiento observado, pero no sustituyen una auditoría de seguridad completa.

---

# Licenciamiento

Microsoft Office 365 es software propietario.

El método original y sus componentes pueden estar sujetos a diferentes licencias.

La documentación y las adaptaciones desarrolladas dentro de **Office on Linux** deben distinguirse del contenido original de terceros.

La existencia de esta documentación no concede ninguna licencia sobre Microsoft Office ni sobre sus componentes propietarios.

El usuario debe contar con los derechos, licencia, suscripción o autorización correspondientes para utilizar Microsoft Office.

---

# Créditos

## Método original

**Formateando**

Canal:

```text
https://www.youtube.com/@formateando
```

El método documentado en esta carpeta se basa en el trabajo público de Formateando.

Se reconoce expresamente su autoría y procedencia.

## Adaptaciones de Office on Linux

Las siguientes actividades corresponden a este proyecto:

```text
adaptación a distribuciones Linux
creación de instaladores
modificaciones de configuración
pruebas de compatibilidad
análisis estático
análisis dinámico
documentación
integración con el escritorio
```

Las adaptaciones no deben confundirse con el método original.

---

# Estado actual

Actualmente el método cuenta con una adaptación documentada y probada para:

```text
Fedora 44
```

La investigación y migración hacia otros entornos continuará conforme se realicen pruebas reproducibles.

La tabla de compatibilidad de este README será actualizada conforme se incorporen nuevas plataformas.

---

# Navegación

```text
Formateando/
│
├── README.md
│
├── analysis/
│   ├── analysis.md
│   ├── analysis-cxwget.md
│   ├── analysis-licensing.md
│   ├── analysis-dxvk.md
│   └── analysis-network.md
│
└── Fedora/
    └── README.md
```

Si quieres conocer el estado de una adaptación concreta, consulta su directorio.

Si quieres conocer los análisis realizados sobre el método y el Bottle, consulta:

```text
analysis/
```