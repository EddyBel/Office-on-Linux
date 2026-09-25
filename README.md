# Office on Linux

> Una colección organizada de métodos, guías, configuraciones, scripts y recursos de instalación para ejecutar Microsoft Office en Linux.

**office-on-linux** es un repositorio dedicado a recopilar, documentar, adaptar y validar diferentes métodos para instalar y ejecutar Microsoft Office en Linux.

El objetivo no es desarrollar un reemplazo para Microsoft Office ni redistribuir software de Microsoft, sino proporcionar un espacio centralizado y reproducible donde los usuarios de Linux puedan encontrar **métodos de instalación documentados, configuraciones necesarias, archivos de apoyo, información de compatibilidad y consideraciones de seguridad**.

---

## ¿Qué es este proyecto?

Ejecutar Microsoft Office en Linux puede requerir enfoques considerablemente diferentes dependiendo de la versión de Office, la distribución de Linux, la versión de Wine, la arquitectura, la pila gráfica y los componentes adicionales de compatibilidad involucrados.

La información sobre estos métodos suele estar distribuida entre foros, videos, repositorios, scripts y guías individuales.

**office-on-linux** busca reunir esta información en un repositorio estructurado.

El proyecto puede contener:

* Guías de instalación
* Configuraciones de Wine y prefijos de Wine
* Configuraciones de Bottles
* Procedimientos con Winetricks
* Scripts de instalación y herramientas auxiliares
* Entornos preconfigurados cuando su redistribución esté legalmente permitida
* Archivos de configuración
* Notas de compatibilidad
* Información para solucionar problemas
* Checksums y metadatos de archivos
* Referencias a los métodos y autores originales
* Notas sobre seguridad y procedencia
* Configuraciones probadas para distribuciones específicas de Linux

Cada método se documenta de acuerdo con lo que realmente fue probado, en lugar de asumir que un procedimiento funcionará universalmente en todas las distribuciones de Linux.

---

## Filosofía del proyecto

El proyecto sigue algunos principios:

### 1. Documentar antes de automatizar

Un método de instalación debe ser comprensible antes de convertirse en un script automatizado.

Los scripts tienen como objetivo reproducir procedimientos documentados, no ocultar lo que están haciendo.

### 2. Verificar lo que se pueda verificar

Siempre que sea posible, los métodos se prueban en un entorno definido.

Una guía debe distinguir entre:

* **Probado**
* **Probado parcialmente**
* **Reportado por fuentes externas**
* **No probado**
* **Conocido por no funcionar**
* **Desconocido**

Que un método funcione en un sistema no significa que funcionará en todas las instalaciones de Linux.

### 3. Preservar la procedencia

Cuando un método proviene de otra persona, proyecto, video, repositorio o guía, se debe identificar la fuente original.

Las adaptaciones deben distinguir claramente entre:

> **Método / fuente original**

y

> **Modificaciones, adaptaciones y pruebas realizadas por office-on-linux**

El repositorio busca preservar la atribución y evitar presentar como trabajo original procedimientos que ya habían sido publicados previamente.

### 4. La seguridad es importante

Ejecutar software de Windows mediante Wine no lo hace automáticamente seguro.

Un prefijo de Wine puede contener:

* Ejecutables de Windows
* DLLs
* Scripts
* Instaladores
* Archivos de configuración
* Componentes descargados
* Credenciales o datos de aplicaciones
* Componentes de compatibilidad de terceros

Por esta razón, el proyecto documenta la **procedencia de los archivos de instalación y configuraciones siempre que sea posible**, junto con las consideraciones de seguridad relevantes.

---

# Seguridad

La seguridad es una parte importante de este proyecto.

El repositorio puede contener o hacer referencia a scripts, configuraciones de Wine, instaladores, archivos comprimidos, DLLs y entornos preconfigurados provenientes de diferentes fuentes.

### Wine no es un sandbox de seguridad

Un prefijo de Wine no debe considerarse automáticamente como una máquina virtual aislada.

Las aplicaciones de Wine pueden interactuar potencialmente con partes del entorno de Linux dependiendo de su configuración.

Por ejemplo, asignaciones de unidades de Wine como:

```text
Z: → /
```

pueden exponer el sistema de archivos de Linux a las aplicaciones de Windows.

Por esta razón, los métodos de este repositorio deben documentar las asignaciones del sistema de archivos y otras configuraciones relevantes para la seguridad cuando corresponda.

Para software de mayor riesgo o de origen no confiable, considera utilizar un usuario dedicado, un entorno aislado, una máquina virtual u otro mecanismo de contención apropiado.

---

# Bottles y prefijos de Wine preconfigurados

Algunos métodos de Office utilizan Bottles o prefijos de Wine preconfigurados.

Estos pueden ser convenientes porque evitan tener que reproducir un proceso de instalación largo, pero también introducen consideraciones adicionales de confianza.

Un archivo preconfigurado puede contener mucho más que la configuración necesaria para iniciar Office.

Por esta razón, los repositorios y releases que contengan estos recursos deberían documentar, siempre que sea posible:

```text
Fuente
Nombre del archivo
Tamaño del archivo
SHA-256
Versión de Office
Arquitectura de Wine
Versión de Wine
Componentes incluidos
Fecha de obtención
Fecha de prueba
```

Un checksum permite verificar que un archivo descargado no haya cambiado respecto al hash publicado.

Sin embargo:

> **Un checksum verifica la integridad del archivo respecto a un hash conocido. No demuestra que el archivo original sea confiable o esté libre de malware.**

---

# Microsoft Office y las licencias

Microsoft Office es software propietario.

Este repositorio **no reclama la propiedad de Microsoft Office, sus marcas comerciales, instaladores, binarios, DLLs u otros componentes propietarios**.

La existencia de documentación que describe cómo instalar o ejecutar Office en Linux no otorga una licencia de Microsoft Office.

Los usuarios son responsables de obtener el software de Microsoft por medios legítimos y de cumplir con los términos de licencia aplicables.

Cuando un método requiera archivos de instalación propietarios, dichos archivos deben ser obtenidos por el usuario desde una fuente apropiada, a menos que su redistribución esté explícitamente permitida.

---

# Métodos de terceros y atribución

Una parte importante del valor de este repositorio proviene de recopilar métodos que ya han sido desarrollados o documentados en otros lugares.

Cuando un procedimiento de instalación se basa en trabajo externo, el repositorio intenta identificar la fuente original.

El proyecto distingue entre:

```text
Método original
        ↓
Autor / proyecto / fuente externa
        ↓
Análisis
        ↓
Adaptación
        ↓
Pruebas
        ↓
Documentación de office-on-linux
```

Las adaptaciones pueden incluir cambios para:

* Diferentes distribuciones de Linux
* Diferentes versiones de Wine
* Diferentes arquitecturas de Wine
* Diferentes estructuras del sistema de archivos
* Diferentes pilas gráficas
* Diferentes paquetes de dependencias
* Diferentes entornos de escritorio
* Diferentes sistemas de launchers
* Mejoras de seguridad
* Reproducibilidad
* Solución de problemas y correcciones

Los autores externos conservan el crédito correspondiente por su trabajo original.

---

# Compatibilidad

La información de compatibilidad es específica del entorno.

Por ejemplo:

```text
Microsoft Office 365
        +
Wine 11.x
        +
Wine32
        +
DXVK
        +
Vulkan
        +
Mesa
        +
Intel UHD 620
```

representa un entorno específico que fue probado y no una garantía de compatibilidad universal.

Siempre que sea posible, los registros de compatibilidad deberían especificar:

| Componente          | Información                     |
| ------------------- | ------------------------------- |
| Distribución        | Distribución y versión de Linux |
| Arquitectura        | x86_64 / i686 / Win32 / Win64   |
| Versión de Office   | Versión/build de Office         |
| Wine                | Versión y rama de Wine          |
| Winetricks          | Versión                         |
| DXVK                | Versión                         |
| Controlador gráfico | Controlador / versión de Mesa   |
| GPU                 | Hardware probado                |
| Resultado           | Resultado de las pruebas        |
| Problemas conocidos | Problemas observados            |

---

# Reproducibilidad

El proyecto busca que los métodos que funcionan puedan reproducirse.

Un método de instalación útil debería responder idealmente a:

1. ¿Qué necesito?
2. ¿De dónde provienen los archivos?
3. ¿Qué versiones fueron probadas?
4. ¿Dónde deben colocarse los archivos?
5. ¿Qué comandos deben ejecutarse?
6. ¿Qué modifica el script?
7. ¿Cómo debería quedar el entorno resultante?
8. ¿Cómo puedo verificar que funcionó?
9. ¿Qué problemas ya se conocen?
10. ¿Qué consideraciones de seguridad existen?

El objetivo es hacer que el proceso sea comprensible, en lugar de simplemente proporcionar un script que funcione.

---

# Lo que este proyecto no es

**office-on-linux no es:**

* Un port de Microsoft Office para Linux
* Un reemplazo de Microsoft Office
* Un proyecto de Microsoft
* Un canal oficial de soporte de Microsoft
* Una garantía de que todas las versiones de Office funcionan en Linux
* Una garantía de que los archivos de instalación de terceros sean seguros
* Un repositorio de software de Microsoft no autorizado
* Un instalador automatizado universal

Es una **colección y documentación de métodos centrados en ejecutar Microsoft Office en entornos Linux**.

---

# Contribuciones

Las contribuciones son bienvenidas, especialmente:

* Nuevos métodos de instalación
* Reportes de compatibilidad
* Correcciones
* Adaptaciones específicas para distribuciones
* Observaciones de seguridad
* Mejores procedimientos de diagnóstico
* Mejoras en la documentación
* Reportes de reproducción

Cuando contribuyas con un método obtenido de una fuente externa, proporciona la fuente original siempre que sea posible.

La información útil incluye:

```text
Versión de Office:
Distribución de Linux:
Versión de la distribución:
Versión de Wine:
Arquitectura de Wine:
Versión de Winetricks:
Versión de DXVK:
GPU:
Controlador gráfico:
Resultado:
Problemas conocidos:
Fuente original:
Cambios realizados:
```

No subas archivos propietarios de Microsoft a menos que su redistribución esté explícitamente permitida.

---

# Estado del proyecto

Este repositorio es una colección en evolución de métodos de instalación.

Que un método esté marcado como **probado** significa que fue probado en un entorno específico y documentado. No significa que el método esté garantizado para funcionar en todos los sistemas Linux.

La compatibilidad puede cambiar debido a actualizaciones de:

* Distribuciones de Linux
* Wine
* DXVK
* Mesa
* Controladores Vulkan
* Office
* Componentes de Windows
* Entornos de escritorio
* Hardware

Por ello, los nuevos resultados de pruebas y la información de compatibilidad son contribuciones valiosas.

---

# Licencia

El código fuente, scripts y documentación propios del repositorio están licenciados de acuerdo con la licencia incluida en este repositorio.

Los materiales de terceros permanecen sujetos a sus respectivas licencias.

Microsoft Office, las marcas comerciales de Microsoft, los binarios propietarios, instaladores y demás propiedad intelectual de Microsoft **no son relicenciados por este repositorio**.

Consulta la documentación de cada método y la información de atribución de sus fuentes para conocer las licencias adicionales aplicables.

---

# Créditos

Este proyecto se basa en el trabajo de personas y comunidades que han documentado diferentes formas de ejecutar Microsoft Office en Linux.

Los métodos externos reciben crédito en su documentación correspondiente.

El proyecto **office-on-linux** es responsable de sus propias adaptaciones, pruebas, correcciones, organización y documentación cuando así se indique explícitamente.

---

## Aviso

Este proyecto se proporciona con fines de documentación e investigación.

Ejecutar software propietario de Windows en Linux puede implicar problemas de compatibilidad, software de terceros, acceso a la red, componentes propietarios y consideraciones relacionadas con licencias.

Revisa siempre los scripts y recursos de instalación antes de ejecutarlos, especialmente cuando provengan de terceros.
