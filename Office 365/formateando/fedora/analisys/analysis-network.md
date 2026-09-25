# Análisis dinámico de red de Excel y acceso a plantillas online

## 1. Alcance

Esta etapa analiza el comportamiento de red de Microsoft Excel durante una operación legítima de acceso y descarga de plantillas online.

El objetivo fue determinar:

1. Si Excel genera conexiones de red por sí mismo.
2. En qué momento aparecen dichas conexiones.
3. Qué direcciones IP son contactadas.
4. Qué nombres de host están asociados a las conexiones TLS.
5. Si los destinos observados son coherentes con servicios utilizados por Microsoft Office y Microsoft 365.
6. Si durante la operación aparecen conexiones hacia dominios que no estén relacionados de forma evidente con la funcionalidad probada.

La prueba se realizó sobre el Bottle preconstruido de Microsoft Office 365 utilizado en las etapas anteriores.

> Esta prueba analiza únicamente el comportamiento observado durante una operación concreta. No constituye una auditoría completa de red ni una certificación de seguridad del Bottle.

---

## 2. Entorno de prueba

La prueba se realizó en el siguiente entorno:

| Componente              | Configuración   |
| ----------------------- | --------------- |
| Sistema operativo       | Fedora 44       |
| Wine                    | 11.0 Staging    |
| Arquitectura del Bottle | Wine32 / win32  |
| Aplicación              | Microsoft Excel |
| Interfaz de red         | `wlp3s0`        |
| IP local observada      | `192.168.1.89`  |
| Transporte              | TCP             |
| Cifrado                 | TLS             |
| Puerto utilizado        | TCP/443         |
| Captura                 | `tcpdump`       |
| Análisis TLS            | `tshark`        |

La operación analizada consistió en acceder desde Excel a una plantilla online y descargarla correctamente.

---

## 3. Estado inicial de la red

Antes de realizar la operación se comprobaron los sockets activos asociados con Excel y Wine:

```bash
sudo ss -tpn \
  | grep -E 'EXCEL|wineserver'
```

No se observó ninguna conexión activa de Excel en ese momento.

También se realizó una comprobación específica de conexiones HTTPS:

```bash
sudo lsof -nP -iTCP:443 \
  | grep -E 'EXCEL|wineserver'
```

Tampoco se encontraron conexiones HTTPS activas.

Este comportamiento es compatible con una aplicación que establece conexiones cuando una determinada función online las necesita, en lugar de mantener necesariamente una conexión HTTPS permanente durante toda la ejecución.

---

## 4. Primera observación: conexiones durante la descarga de una plantilla

Durante una prueba anterior de descarga de una plantilla de tipo:

```text
Diagrama de Gantt
```

se observó una conexión TCP establecida:

```text
192.168.1.89:60788
        ↓
52.110.19.33:443
```

La conexión estaba asociada con:

```text
EXCEL.EXE
PID 49504
```

y también aparecía:

```text
wineserver
PID 46521
```

Durante la misma operación se observaron conexiones adicionales:

```text
192.168.1.89:56358 → 23.204.136.106:443
192.168.1.89:56360 → 23.204.136.106:443
192.168.1.89:56362 → 23.204.136.106:443
```

Las conexiones estaban asociadas con `EXCEL.EXE`.

Esto permitió establecer una primera correlación temporal:

```text
Excel iniciado
    ↓
sin conexión HTTPS activa
    ↓
usuario selecciona una plantilla online
    ↓
aparecen nuevas conexiones HTTPS
    ↓
la plantilla se descarga
```

La identificación basada únicamente en direcciones IP, sin embargo, no permite determinar con suficiente confianza qué servicio se encuentra detrás de cada dirección.

Por este motivo se realizó una segunda captura utilizando `tcpdump` y posteriormente se analizaron los handshakes TLS para obtener el SNI.

---

## 5. Captura completa del tráfico HTTPS

Se inició una captura de tráfico TCP/443 mediante:

```bash
sudo tcpdump -i wlp3s0 -nn -s0 \
  -w /tmp/excel-template.pcap \
  'tcp port 443'
```

Durante la prueba continuaron apareciendo mensajes de compatibilidad de Wine, entre ellos:

```text
fixme:file:NtFsControlFile FSCTL_PIPE_IMPERSONATE:
impersonating self
```

Estos mensajes fueron tratados como ruido del entorno Wine. No se encontró una correlación directa entre dichos mensajes y las conexiones HTTPS observadas.

La captura finalizó con:

```text
203 packets captured
203 packets received by filter
0 packets dropped by kernel
```

Por tanto, durante esta captura no se reportaron paquetes descartados por el kernel.

La evidencia completa quedó almacenada en:

```text
/tmp/excel-template.pcap
```

---

## 6. Flujo TCP observado

Durante la operación se observó una sesión TCP completa hacia:

```text
52.110.19.33:443
```

El establecimiento de conexión comenzó con:

```text
10:57:53.243535
192.168.1.89:57666 >
52.110.19.33:443
Flags [S]
```

El servidor respondió:

```text
10:57:53.252011
52.110.19.33:443 >
192.168.1.89:57666
Flags [S.]
```

Posteriormente continuó el intercambio de datos:

```text
192.168.1.89:57666 >
52.110.19.33:443
Flags [P.]
length 234
```

El servidor respondió con múltiples segmentos, incluyendo longitudes observadas de:

```text
7000
1862
358
1626
44
842
3066
34
```

El flujo observado puede resumirse como:

```text
TCP SYN
    ↓
TCP SYN/ACK
    ↓
ACK
    ↓
intercambio de datos
    ↓
transferencia de contenido
```

Esto demuestra que la comunicación no correspondió únicamente a una consulta DNS ni a un intento de conexión fallido. Existió una sesión TCP establecida con intercambio posterior de datos.

---

## 7. Limitaciones de la captura TCP

La captura inicial permitió observar información como:

```text
IP origen
IP destino
puerto
dirección del flujo
timestamp
tamaño de los segmentos
```

Sin embargo, al utilizarse HTTPS, la captura no permitió obtener directamente:

```text
hostname
URL completa
ruta HTTP
cabeceras HTTP
contenido de la respuesta
archivo exacto descargado
```

Por esta razón se utilizó el handshake TLS para obtener el nombre de servidor anunciado mediante SNI.

---

## 8. Obtención del SNI mediante TLS

El archivo PCAP fue analizado con:

```bash
tshark -r /tmp/excel-template.pcap \
  -Y 'tls.handshake.type == 1' \
  -T fields \
  -e frame.time \
  -e ip.src \
  -e ip.dst \
  -e tls.handshake.extensions_server_name
```

Se identificaron los siguientes hostnames.

### 8.1 `odc.officeapps.live.com`

```text
2026-09-25T11:00:17.590520000-0600
192.168.1.89
52.110.19.33
odc.officeapps.live.com
```

### 8.2 `metadata.templates.cdn.office.net`

```text
2026-09-25T11:00:24.032649000-0600
192.168.1.89
23.200.40.142
metadata.templates.cdn.office.net
```

Se observó una segunda aparición del mismo destino:

```text
2026-09-25T11:00:24.032682000-0600
192.168.1.89
23.200.40.142
metadata.templates.cdn.office.net
```

### 8.3 `cdn.create.microsoft.com`

```text
2026-09-25T11:00:24.529082000-0600
192.168.1.89
23.204.136.101
cdn.create.microsoft.com
```

### 8.4 `createcatalog.public.onecdn.static.microsoft`

```text
2026-09-25T11:00:25.113790000-0600
192.168.1.89
23.204.136.124
createcatalog.public.onecdn.static.microsoft
```

La relación observada fue:

```text
192.168.1.89
    │
    ├── 52.110.19.33:443
    │      └── odc.officeapps.live.com
    │
    ├── 23.200.40.142:443
    │      └── metadata.templates.cdn.office.net
    │
    ├── 23.204.136.101:443
    │      └── cdn.create.microsoft.com
    │
    └── 23.204.136.124:443
           └── createcatalog.public.onecdn.static.microsoft
```

---

## 9. Correlación con la infraestructura de Microsoft

El SNI permite atribuir las conexiones observadas con mayor precisión que una dirección IP por sí sola.

En particular:

```text
52.110.19.33
    ↓
odc.officeapps.live.com
```

corresponde directamente al espacio de nombres utilizado por servicios de Office Online y Microsoft 365.

La dirección `52.110.19.33` también se encuentra dentro del rango `52.108.0.0/14` documentado por Microsoft para servicios relacionados con Office 365.

Los demás destinos observados utilizan espacios de nombres relacionados con:

```text
office.net
microsoft.com
static.microsoft
```

y aparecieron durante la operación específica de acceso a plantillas.

La evidencia obtenida, por tanto, es coherente con una comunicación de Excel hacia infraestructura utilizada por Microsoft para proporcionar contenido y servicios online de Office.

La identificación mediante SNI es particularmente útil en este caso porque las direcciones IP utilizadas por servicios cloud pueden ser compartidas o variar con el tiempo.

---

## 10. Correlación temporal

Los handshakes TLS observados ocurrieron en una ventana muy concreta:

```text
11:00:17.590520
    odc.officeapps.live.com

11:00:24.032649
    metadata.templates.cdn.office.net

11:00:24.529082
    cdn.create.microsoft.com

11:00:25.113790
    createcatalog.public.onecdn.static.microsoft
```

La actividad identificada se concentró aproximadamente entre:

```text
11:00:17 → 11:00:25
```

Es decir, en un intervalo de aproximadamente ocho segundos.

La secuencia temporal es compatible con varias operaciones relacionadas con el acceso a contenido online, por ejemplo:

```text
consulta de catálogo
        ↓
obtención de metadatos
        ↓
consulta de contenido
        ↓
obtención del recurso
```

No obstante, el orden funcional exacto de cada solicitud no puede determinarse únicamente a partir del SNI.

El contenido de las comunicaciones posteriores al handshake permanece cifrado mediante TLS.

---

## 11. Atribución de las conexiones a Excel

Durante una descarga activa se observó mediante `ss` una conexión de la forma:

```text
tcp ESTAB
192.168.1.89:60788
    →
52.110.19.33:443

users:
(
    ("EXCEL.EXE",pid=49504,fd=571),
    ("wineserver",pid=46521,fd=2562)
)
```

Esto proporciona la siguiente relación:

```text
socket
    ↓
EXCEL.EXE
    ↓
52.110.19.33:443
```

El hecho de que `wineserver` aparezca asociado al mismo socket no debe interpretarse como una segunda conexión independiente.

Es consistente con el modelo de ejecución de aplicaciones Windows mediante Wine, donde determinados recursos y operaciones de red pueden aparecer relacionados con el proceso de Wine además del proceso Windows que los utiliza.

La atribución a Excel se basa principalmente en la asociación directa observada entre el socket y `EXCEL.EXE`.

---

## 12. Actividad de Office Software Protection Platform

Durante la ejecución también aparecieron mensajes relacionados con:

```text
Office Software Protection Platform Service
```

Entre ellos:

```text
fixme:advapi:RegisterEventSourceW
((null),L"Office Software Protection Platform Service"): stub
```

seguidos de:

```text
fixme:advapi:ReportEventW
```

y:

```text
fixme:advapi:DeregisterEventSource
```

Esto demuestra actividad del componente de protección de software de Office dentro del Bottle.

Sin embargo, esta evidencia no permite afirmar que:

```text
OSPPSVC.EXE
```

haya generado las conexiones utilizadas para descargar las plantillas.

La atribución de la comunicación analizada a Excel procede de la observación independiente mediante `ss`, donde `EXCEL.EXE` apareció directamente asociado al socket TCP.

Por tanto, no debe confundirse:

```text
actividad del servicio de protección de Office
```

con:

```text
origen demostrado de las conexiones HTTPS de la prueba
```

---

## 13. Mensajes `FSCTL_PIPE_IMPERSONATE`

Durante la captura aparecieron repetidamente mensajes de Wine:

```text
fixme:file:NtFsControlFile
FSCTL_PIPE_IMPERSONATE:
impersonating self
```

Estos mensajes fueron observados mientras Excel y otros componentes de Office estaban ejecutándose.

No se estableció una correlación directa entre ellos y las conexiones HTTPS.

En el contexto de esta prueba fueron tratados como:

```text
mensajes de compatibilidad de Wine
```

y no como evidencia de una conexión remota, descarga independiente o ejecución de código.

---

## 14. De IPs aisladas a servicios identificables

La primera observación de red únicamente permitía establecer:

```text
52.110.19.33
23.204.136.106
```

Sin información adicional, esto no era suficiente para atribuir con confianza el tráfico a un servicio concreto.

El análisis posterior del SNI permitió obtener:

```text
52.110.19.33
    → odc.officeapps.live.com
```

```text
23.200.40.142
    → metadata.templates.cdn.office.net
```

```text
23.204.136.101
    → cdn.create.microsoft.com
```

```text
23.204.136.124
    → createcatalog.public.onecdn.static.microsoft
```

Por tanto, la evidencia pasó de:

```text
"Excel conecta a determinadas direcciones IP"
```

a:

```text
"Excel establece sesiones TLS cuyo SNI corresponde a
endpoints de la infraestructura de Microsoft relacionados
con Office y contenido online."
```

Esta segunda afirmación está mejor fundamentada porque incorpora información del propio protocolo TLS además de la dirección IP.

---

## 15. Ausencia de tráfico HTTP en texto plano

La operación observada utilizó:

```text
TCP
    ↓
443
    ↓
TLS
    ↓
HTTPS
```

Por ello, la captura pasiva permitió observar:

```text
IP
puerto
timestamp
SNI
dirección del flujo
tamaño aproximado de los segmentos
```

pero no permitió observar directamente:

```text
URL completa
cabeceras HTTP
parámetros HTTP
contenido de la plantilla
datos enviados dentro de TLS
```

La utilización de TLS limita deliberadamente la cantidad de información que puede obtenerse mediante una captura de red pasiva.

---

## 16. Qué demuestra y qué no demuestra el SNI

El SNI proporciona una identificación útil del hostname solicitado durante el establecimiento de TLS.

Por ejemplo:

```text
metadata.templates.cdn.office.net
```

permite establecer que el cliente inició una sesión TLS anunciando ese hostname.

Sin embargo, por sí solo no demuestra:

```text
qué archivo exacto fue descargado
qué parámetros fueron enviados
qué contenido se transmitió
qué datos del usuario fueron incluidos
```

Para responder esas preguntas sería necesaria instrumentación adicional, por ejemplo:

* análisis del proceso a nivel de aplicación;
* instrumentación del tráfico antes o después de TLS;
* análisis del propio cliente de Office;
* registros del sistema o de la aplicación;
* instrumentación específica de Wine.

Por tanto, el SNI debe utilizarse como evidencia de destino solicitado, no como una descripción completa del contenido de la comunicación.

---

## 17. Evaluación de la actividad observada

Durante esta operación concreta se observaron:

```text
Excel
    ↓
selección de plantilla online
    ↓
conexiones TCP
    ↓
TCP/443
    ↓
TLS
    ↓
endpoints asociados a Microsoft
    ↓
descarga exitosa
```

Los hostnames identificados fueron:

```text
odc.officeapps.live.com
metadata.templates.cdn.office.net
cdn.create.microsoft.com
createcatalog.public.onecdn.static.microsoft
```

No se observó durante esta operación un hostname que proporcionara por sí mismo una señal clara de comunicación con infraestructura ajena a los servicios relacionados con Microsoft/Office.

Esto es compatible con el funcionamiento esperado de una aplicación de Office que accede a contenido online.

La observación, sin embargo, está limitada a la operación realizada y al tráfico capturado durante ella.

---

## 18. Consideraciones de seguridad

### 18.1 Excel realiza comunicaciones reales

La prueba demuestra dinámicamente que Excel no opera de forma completamente aislada de la red.

Al utilizar funciones online, como el acceso a plantillas, establece:

```text
conexiones TCP
        ↓
puerto 443
        ↓
TLS
        ↓
servicios externos
```

Esto es compatible con el funcionamiento de las características online de Microsoft Office y Microsoft 365.

---

### 18.2 Los destinos observados son coherentes con Office

Los cuatro hostnames identificados pertenecen a espacios de nombres asociados con Microsoft y servicios relacionados con Office:

```text
officeapps.live.com
office.net
microsoft.com
static.microsoft
```

En particular:

```text
odc.officeapps.live.com
```

proporciona una correlación directa con la infraestructura de Office Online publicada por Microsoft.

---

### 18.3 No se observó una conexión evidentemente ajena durante esta prueba

Durante la operación analizada no se observó:

```text
HTTP sin cifrar
FTP
SSH
conexiones hacia dominios evidentemente ajenos
```

Tampoco apareció durante esta captura un hostname que, por sí mismo, proporcionara una señal clara de comportamiento malicioso.

Esto debe interpretarse como:

```text
"No se observó tráfico evidentemente sospechoso durante esta operación"
```

y no como:

```text
"El Bottle completo es seguro"
```

---

## 19. Relación con las etapas anteriores

Esta evidencia debe interpretarse conjuntamente con las pruebas realizadas anteriormente.

El Bottle ya había demostrado que las principales aplicaciones de Office podían iniciarse:

```text
[✓] Word
[✓] Excel
[✓] PowerPoint
[✓] Outlook
[✓] Access
[✓] Publisher
[✓] OneNote
```

La etapa gráfica demostró una diferencia reproducible entre los backends gráficos:

```text
WineD3D
    ↓
Word → interfaz blanca

DXVK 3.1.1
    ↓
Word → interfaz funcional
```

La presente etapa añade evidencia sobre el comportamiento de red:

```text
Excel
    ↓
plantillas online
    ↓
HTTPS
    ↓
servicios de Microsoft
    ↓
contenido online
```

Por tanto, el Bottle no debe considerarse simplemente como un conjunto estático de archivos de Office.

Contiene una instalación funcional que puede interactuar con servicios externos cuando las funciones correspondientes son utilizadas.

---

## 20. Evidencia conservada

La captura completa de tráfico se almacenó como:

```text
/tmp/excel-template.pcap
```

El SNI fue extraído mediante:

```bash
tshark -r /tmp/excel-template.pcap \
  -Y 'tls.handshake.type == 1' \
  -T fields \
  -e frame.time \
  -e ip.src \
  -e ip.dst \
  -e tls.handshake.extensions_server_name
```

La captura debe conservarse junto con la fecha, hora y configuración de la prueba, ya que representa una observación dinámica correspondiente a un momento específico.

Para una investigación reproducible, es recomendable registrar adicionalmente:

```text
versión de Wine
versión de Office
versión del Bottle
interfaz de red
dirección IP local
fecha y hora
acción realizada dentro de Excel
hash del archivo PCAP
```

---

## 21. Resumen de evidencia

```text
============================================================
 EXCEL — ANÁLISIS DINÁMICO DE RED
============================================================

Fecha:
  25/09/2026

Ventana principal de actividad TLS:
  11:00:17 – 11:00:25

Interfaz:
  wlp3s0

IP local:
  192.168.1.89

Protocolos observados:
  TCP
  TLS
  HTTPS / 443

Paquetes:
  203 capturados
  203 recibidos
  0 descartados por kernel

Acción realizada:
  Acceso y descarga de una plantilla online desde Excel

Destinos identificados mediante SNI:

  52.110.19.33
      └── odc.officeapps.live.com

  23.200.40.142
      └── metadata.templates.cdn.office.net

  23.204.136.101
      └── cdn.create.microsoft.com

  23.204.136.124
      └── createcatalog.public.onecdn.static.microsoft

Atribución del socket:
  EXCEL.EXE

Resultado:
  Descarga de plantilla exitosa

Interpretación:
  La operación generó comunicaciones HTTPS reales
  hacia endpoints coherentes con servicios online
  de Microsoft Office/Microsoft 365.

Limitación:
  El contenido de las sesiones TLS no fue inspeccionado.

============================================================
```

---

## 22. Estado de la investigación

```text
[✓] Excel ejecuta correctamente
[✓] Excel puede acceder a funciones online
[✓] Se observaron conexiones TCP reales
[✓] Se observaron sesiones HTTPS/TLS
[✓] Se identificó EXCEL.EXE asociado a un socket
[✓] Se capturó tráfico mediante tcpdump
[✓] No hubo paquetes descartados por kernel
[✓] Se obtuvo SNI mediante tshark
[✓] Se identificaron endpoints relacionados con Microsoft
[✓] La plantilla se descargó correctamente
[ ] No se inspeccionó el contenido interno de TLS
[ ] No se determinó el archivo exacto transferido
[ ] No se realizó una auditoría completa de tráfico del Bottle
[ ] No se evaluaron todas las funciones online de Office
```

---

## 23. Conclusión

La prueba dinámica proporcionó evidencia reproducible de que Microsoft Excel, ejecutándose dentro del Bottle preconstruido, establece conexiones HTTPS reales cuando se utiliza la funcionalidad de plantillas online.

La primera observación mediante `ss` permitió relacionar una conexión TCP activa directamente con `EXCEL.EXE`. La captura posterior mediante `tcpdump` permitió conservar el tráfico completo de la prueba y verificar que existió una sesión TCP con intercambio de datos.

El análisis de los handshakes TLS mediante `tshark` permitió recuperar los siguientes nombres de servidor:

```text
odc.officeapps.live.com
metadata.templates.cdn.office.net
cdn.create.microsoft.com
createcatalog.public.onecdn.static.microsoft
```

Los destinos observados son coherentes con espacios de nombres e infraestructura utilizados por Microsoft para servicios relacionados con Office y contenido online.

No se observó durante esta operación un destino que proporcionara por sí mismo una señal clara de actividad maliciosa. Sin embargo, la ausencia de un destino evidentemente sospechoso en esta captura no permite extrapolar la conclusión a todo el Bottle ni a otras funciones de Office.

Asimismo, el SNI permite identificar el hostname solicitado durante el establecimiento de TLS, pero no revela por sí solo la URL completa, el contenido transferido, los parámetros enviados ni los datos incluidos dentro de la sesión cifrada.

Por tanto, la conclusión de esta etapa queda limitada a lo que puede demostrarse con la evidencia disponible:

```text
Excel
    ↓
función de plantillas online
    ↓
EXCEL.EXE
    ↓
TCP/443
    ↓
TLS
    ↓
endpoints asociados con Microsoft
    ↓
descarga exitosa
```

La prueba confirma que el Bottle mantiene capacidad de comunicación con servicios externos cuando Excel utiliza funcionalidades online y proporciona una base reproducible para continuar investigando el comportamiento de red de otros componentes de Microsoft Office.
