# Microsoft Office 365 — Métodos para Linux

> Colección de métodos, configuraciones, instaladores y documentación para ejecutar **Microsoft Office 365 en Linux** mediante Wine, Wine-based runners y tecnologías compatibles.

Este directorio reúne diferentes métodos desarrollados por terceros para ejecutar Microsoft Office 365 en Linux, junto con sus respectivas adaptaciones, pruebas y documentación.

El objetivo no es crear un único instalador universal, sino **recopilar, analizar, documentar y adaptar diferentes enfoques existentes** para que puedan ser reproducidos en distintos entornos Linux.

---

# ¿Qué encontrarás aquí?

Cada subdirectorio representa un **método, proyecto o autor de referencia** utilizado para ejecutar Microsoft Office 365.

Por ejemplo:

```text
Office365/
│
├── Formateando/
│   ├── README.md
│   ├── Fedora/
│   ├── Debian/
│   └── ...
│
├── OtroMetodo/
│   ├── README.md
│   └── ...
│
└── ...
```

La estructura puede crecer conforme se incorporen nuevos métodos.

La separación por método permite conservar:

```text
procedencia
    ↓
método original
    ↓
adaptaciones
    ↓
pruebas
    ↓
resultados
```

sin mezclar procedimientos que pueden utilizar arquitecturas, Bottles, versiones de Wine o mecanismos de instalación diferentes.

---

# Filosofía

Este directorio forma parte de **Office on Linux**, cuyo objetivo es recopilar y documentar métodos reproducibles para ejecutar Microsoft Office en Linux.

Cada método se trata como un caso independiente.

El flujo general es:

```text
Método original
      ↓
Análisis
      ↓
Reproducción
      ↓
Validación
      ↓
Adaptación
      ↓
Documentación
```

Cuando un método es modificado, se procura distinguir claramente entre:

```text
Trabajo original
        +
Adaptaciones de Office on Linux
        +
Resultados de nuestras pruebas
```

De esta forma, una adaptación no debe presentarse como si fuera el método original.

---

# Métodos

## Formateando

**Formateando** es una de las fuentes utilizadas para esta colección y constituye el origen del método de Office 365 basado en un Bottle preconfigurado que actualmente se está adaptando y documentando.

El método original está orientado principalmente a sistemas basados en:

```text
Ubuntu
Debian
Linux Mint
```

A partir de este procedimiento se han realizado pruebas y adaptaciones para otros entornos Linux.

Fuente original:

**Formateando — YouTube**

```text
https://www.youtube.com/@formateando
```

El método puede contener:

```text
Bottle / Wine Prefix
Microsoft Office 365
Wine32
configuración de Wine
fuentes
launchers
integración con el escritorio
componentes gráficos
```

Las adaptaciones realizadas dentro de Office on Linux se documentan separadamente del procedimiento original.

Consulta:

```text
Formateando/
└── README.md
```

para conocer el estado actual de este método.

---

# Organización de los métodos

Cada método puede tener una estructura interna diferente dependiendo de cómo fue desarrollado originalmente.

Una estructura posible es:

```text
<Metodo>/
│
├── README.md
│
├── Fedora/
│   ├── README.md
│   └── install.sh
│
├── Debian/
│   ├── README.md
│   └── install.sh
│
├── Arch/
│   ├── README.md
│   └── install.sh
│
├── docs/
│
└── analysis/
```

Sin embargo, esta estructura **no es obligatoria**.

Cada método debe conservar una organización que permita distinguir:

1. El procedimiento original.
2. Las modificaciones realizadas.
3. Los entornos probados.
4. Los resultados obtenidos.
5. Las limitaciones conocidas.

---

# Métodos y autores

Las carpetas de este directorio no representan necesariamente distribuciones Linux.

Representan principalmente:

```text
métodos
proyectos
autores
fuentes
```

Por ejemplo:

```text
Office365/
│
├── Formateando/
│
├── Proyecto-B/
│
├── Proyecto-C/
│
└── ...
```

Dentro de cada método pueden existir adaptaciones para diferentes distribuciones:

```text
Formateando/
│
├── Fedora/
├── Debian/
└── Arch/
```

Esto permite evitar una estructura en la que cada distribución parezca ser un método independiente cuando en realidad comparte el mismo procedimiento de origen.

---

# Adaptaciones por distribución

Un mismo método puede requerir modificaciones para funcionar en diferentes distribuciones.

Por ejemplo:

```text
Método original
      │
      ├── Fedora
      │
      ├── Debian / Ubuntu / Linux Mint
      │
      └── Arch Linux / derivadas
```

Estas diferencias pueden incluir:

```text
gestor de paquetes
Wine
Wine32
Winetricks
Vulkan
DXVK
bibliotecas de 32 bits
fuentes
rutas del sistema
integración XDG
launchers
```

Por este motivo, el hecho de que un método funcione en una distribución no implica automáticamente que funcione en otra.

---

# Estado de cada método

Cada método debe indicar claramente su estado.

Se pueden utilizar categorías como:

```text
Tested
```

Método probado directamente en el entorno indicado.

```text
Partially Tested
```

Algunos componentes fueron probados, pero no existe una validación completa.

```text
Reported
```

El funcionamiento está documentado por su autor u otras fuentes, pero todavía no ha sido reproducido por Office on Linux.

```text
Experimental
```

Se encuentra en proceso de adaptación o investigación.

```text
Known Failure
```

Existe una prueba reproducible que demuestra que el método o una parte concreta no funciona bajo determinadas condiciones.

```text
Unknown
```

Todavía no existe información suficiente para establecer su estado.

El estado siempre debe asociarse al entorno probado:

```text
Fedora 44 + Wine 11.0 Staging + Wine32
```

es diferente de:

```text
Ubuntu + Wine
```

y no deben mezclarse ambos resultados.

---

# Procedencia y atribución

Cada método conserva su procedencia.

Cuando un procedimiento proviene de un tercero, la documentación debe indicar:

```text
Autor / proyecto original
Fuente
Método original
Modificaciones realizadas
Pruebas realizadas
Resultados
```

Por ejemplo:

```text
Método original:
    Formateando

Adaptación:
    Office on Linux

Entorno probado:
    Fedora 44

Cambios:
    Wine32
    DXVK
    Vulkan
    integración XDG
    instalador Fedora
```

La adaptación no sustituye la autoría del método original.

---

# Análisis y documentación

Cuando sea posible, los métodos se acompañarán de documentación técnica.

Esta documentación puede incluir:

```text
analysis.md
analysis-*.md
security.md
compatibility.md
installation.md
```

Los análisis pueden estudiar aspectos como:

```text
estructura del Bottle
arquitectura Wine
DLL
configuración
registro
fuentes
componentes gráficos
licenciamiento
actividad de red
dependencias
```

El objetivo es que las conclusiones estén respaldadas por evidencia obtenida durante las pruebas.

---

# Seguridad

Los métodos incluidos aquí pueden utilizar:

```text
Wine
Bottles
CrossOver
scripts de terceros
Wine Prefixes preconfigurados
DLL modificadas
ejecutables Windows
componentes propietarios
```

Por lo tanto, **el hecho de que un método funcione no implica que sea seguro por defecto**.

Especialmente en el caso de Bottles o Wine Prefixes preconfigurados, es importante considerar que pueden contener ejecutables y configuraciones que no forman parte de una instalación limpia de Wine.

Cuando sea relevante, se documentará:

```text
procedencia
componentes
hashes
configuración
modificaciones
actividad de red
limitaciones del análisis
```

Los resultados de una prueba concreta no deben interpretarse automáticamente como una certificación de seguridad de todo el método.

---

# Licencias

Microsoft Office y Microsoft 365 son software propietario.

Los métodos recopilados aquí pueden contener componentes sujetos a diferentes licencias.

La licencia del repositorio **Office on Linux** no sustituye las licencias de:

```text
Microsoft
Wine
CrossOver
autores de scripts
proyectos de terceros
otros componentes incluidos
```

Cada método debe conservar y respetar la licencia y atribución de sus respectivos componentes.

---

# Microsoft Office 365

Los métodos de esta sección están orientados a diferentes formas de ejecutar Microsoft Office 365 sobre Linux.

Las aplicaciones disponibles pueden incluir:

```text
Microsoft Word
Microsoft Excel
Microsoft PowerPoint
Microsoft Outlook
Microsoft Access
Microsoft Publisher
Microsoft OneNote
```

La disponibilidad y compatibilidad dependen del método y del entorno utilizado.

Por ejemplo:

```text
Método A
    ↓
Word ✓
Excel ✓
PowerPoint ✓

Método B
    ↓
Word ✓
Excel ?
PowerPoint ✗
```

Los resultados deben consultarse en la documentación correspondiente a cada método.

---

# No es un instalador oficial

Este directorio **no contiene un instalador oficial de Microsoft Office 365**.

Office on Linux no está afiliado, patrocinado ni respaldado por Microsoft.

Microsoft Office, Microsoft 365 y sus aplicaciones son productos y marcas de sus respectivos propietarios.

Los métodos aquí documentados utilizan tecnologías de compatibilidad o procedimientos de terceros para ejecutar el software en Linux.

---

# Licencias y activación

Esta colección no proporciona una licencia de Microsoft 365.

El usuario debe disponer de los derechos, licencia, suscripción o autorización necesarios para utilizar Microsoft Office.

La existencia de un método que permita ejecutar Office técnicamente en Linux no implica que proporcione una licencia válida ni que modifique las condiciones de uso del software.

---

# Contribuciones

Se pueden incorporar nuevos métodos siempre que sea posible documentar razonablemente su procedencia.

Una contribución debería incluir, cuando sea posible:

```text
Nombre del método
Autor / proyecto original
Fuente
Procedimiento
Entorno
Requisitos
Estado
Limitaciones
```

Si el método fue adaptado, debe indicarse claramente qué partes pertenecen al trabajo original y cuáles corresponden a la adaptación.

También son bienvenidos:

```text
correcciones
pruebas
compatibilidad
documentación
análisis de seguridad
nuevas distribuciones
nuevas versiones de Wine
```

---

# Estructura general

Actualmente, este directorio sigue el siguiente concepto:

```text
Office365/
│
├── README.md
│
├── <Metodo-1>/
│   ├── README.md
│   └── ...
│
├── <Metodo-2>/
│   ├── README.md
│   └── ...
│
└── <Metodo-3>/
    ├── README.md
    └── ...
```

Cada carpeta representa un método o fuente independiente.

La estructura interna de cada método queda definida por su propia documentación.

---

# Cómo utilizar este directorio

Si estás buscando una forma de ejecutar Office 365 en Linux:

### 1. Selecciona un método

Explora las carpetas disponibles:

```text
Office365/
├── Formateando/
├── ...
```

### 2. Lee el README del método

Revisa:

```text
requisitos
distribuciones compatibles
arquitectura
dependencias
estado
limitaciones
```

### 3. Selecciona tu entorno

Si el método tiene varias adaptaciones:

```text
Fedora
Debian / Ubuntu / Linux Mint
Arch Linux
```

elige la correspondiente a tu sistema.

### 4. Revisa el estado

Comprueba si el método está:

```text
Tested
Partially Tested
Reported
Experimental
Known Failure
Unknown
```

antes de utilizarlo.

### 5. Consulta la documentación técnica

Cuando exista, revisa los análisis disponibles para conocer:

```text
qué contiene el método
qué modificaciones utiliza
qué problemas fueron encontrados
qué pruebas fueron realizadas
```

---

# Créditos

Esta colección reconoce el trabajo de los autores y proyectos que desarrollaron originalmente los métodos recopilados.

Cada método debe mantener una atribución clara hacia su fuente original.

Para el método basado en el Bottle de Office 365 utilizado actualmente:

**Formateando**

Canal de YouTube:

```text
https://www.youtube.com/@formateando
```

Las adaptaciones, pruebas y documentación desarrolladas dentro de **Office on Linux** se identifican separadamente del trabajo original.