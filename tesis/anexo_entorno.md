# Anexo A. El entorno de trabajo: dos máquinas y una frontera

> **Estado:** borrador 1, escrito el 2026-09-21.
> Este anexo documenta la infraestructura sobre la que se produjo todo el trabajo. Se incluye porque
> es **ingeniería real que el cuerpo del documento no muestra**: la §3.7 la resume en un párrafo, y
> ese párrafo esconde tanto el reparto de herramientas como una clase de error que costó horas.

## A.1 Por qué dos máquinas

El flujo completo —del modelo en Python al GDSII firmado— no se ejecuta en un solo sitio. La razón no
es de conveniencia sino de disponibilidad: **parte de las herramientas no existe compiladas para la
arquitectura del equipo principal**, y otra parte depende de un contenedor que sólo corre sobre
Linux.

El reparto resultante es el siguiente, y conviene tenerlo escrito porque determina dónde se reproduce
cada resultado de este documento:

| Etapa | Herramienta | Dónde corre |
|---|---|---|
| Modelo de referencia | Python, NumPy | equipo principal |
| Simulación RTL y verificación | Icarus Verilog, cocotb | equipo principal |
| Síntesis lógica | yosys | equipo principal |
| Simulación eléctrica | NGSpice | equipo principal |
| Esquemáticos RTL | yosys + netlistsvg | equipo principal |
| **Emplazamiento y ruteo en FPGA** | nextpnr-ice40, icepack | **máquina virtual** |
| **Flujo completo a ASIC** | OpenLane sobre Docker | **máquina virtual** |
| **Extracción de celdas, DRC, LVS** | Magic, Netgen | **máquina virtual** |
| **Análisis estático de tiempos** | OpenSTA | **máquina virtual** |
| **Visualización de layout** | KLayout con interfaz gráfica | **máquina virtual** |
| Grabación del *bitstream* | copia al volumen de la tarjeta | equipo principal |

La consecuencia práctica es que **un resultado de silicio no se puede reproducir sin la máquina
virtual**, mientras que toda la verificación funcional y eléctrica sí se reproduce en el equipo
principal. Esa asimetría condiciona qué partes de este trabajo son fácilmente auditables por un
tercero.

## A.2 La frontera, y cómo se cruza

Las dos máquinas comparten un directorio mediante **virtiofs**, montado en rutas distintas a cada
lado:

```
equipo principal :  ~/utm-share
máquina virtual  :  /mnt/share/utm-share
```

Sobre esa frontera cruzan tres clases de objeto, en direcciones distintas:

- **Hacia la máquina virtual:** fuentes RTL, ficheros de configuración del flujo y guiones de
  ejecución.
- **Hacia el equipo principal:** reportes de firma, ficheros de métricas, extracciones de parásitos y
  planos comprimidos.
- **En ninguna dirección:** los directorios de ejecución completos, que ocupan cientos de megabytes
  por diseño y se archivan localmente en cada máquina.

## A.3 Una clase de error que conviene documentar

La frontera no es transparente, y su opacidad produce un error con una firma característica: **la
herramienta lee una versión del fichero distinta de la que se escribió**.

Durante el desarrollo se corrigió un defecto en un fuente Verilog, se verificó la corrección en el
equipo principal —contenido y suma de comprobación— y se copió al directorio compartido. La máquina
virtual, sin embargo, siguió sirviendo el contenido anterior. El flujo falló **dos veces seguidas con
el mismo error ya corregido** antes de que se comprobara el fichero en su destino final.

La causa es la caché de lectura del sistema de ficheros compartido. El procedimiento que la evita es
elemental y se adoptó como regla:

1. Copiar a una **ruta nueva** en lugar de sobrescribir la existente: un camino distinto no tiene
   caché previa.
2. Comprobar el fichero **desde la máquina que lo va a leer**, no desde la que lo escribió.
3. Comprobarlo **en su destino final**, no en el directorio compartido — es decir, ya dentro del
   árbol de trabajo de la herramienta.

> Formulada como principio: **verificar el fichero donde la herramienta va a leerlo, no donde uno lo
> escribió.** Es el mismo razonamiento de la §3.6 aplicado a la infraestructura: el instrumento —aquí,
> el canal entre las dos máquinas— también puede mentir, y también hay que verificarlo antes de
> confiar en lo que entrega.

## A.4 Otras asimetrías anotadas

Se listan porque cada una costó tiempo al descubrirse:

- **La ruta de instalación no es la que se supone.** El flujo a ASIC no reside en el directorio de
  inicio sino varios niveles más abajo, y el kit de diseño tampoco está donde su documentación
  sugiere. Un guion que asuma las rutas canónicas falla sin explicar por qué.
- **Las capturas de layout requieren interfaz gráfica.** En modo desatendido, y sin encontrar el
  fichero de propiedades de capas, el visor produce una imagen uniforme e inservible. La limitación
  es del modo de invocación, no de la herramienta, y las figuras de este documento se obtuvieron con
  la interfaz.
- **El contenedor del flujo a ASIC reescribe el directorio de inicio**, de modo que las operaciones
  que dependen de rutas absolutas del anfitrión —fotografías, visualización— deben ejecutarse fuera
  de él.
- **El simulador de FPGA no dispone de visor de formas de onda funcional en el equipo principal**, por
  lo que la inspección de ondas se realiza en la máquina virtual sobre los ficheros generados en el
  principal.

## A.5 Reproducibilidad

Todo lo necesario para reproducir los resultados de este documento está versionado, con dos
excepciones declaradas:

- **Los planos completos** —GDSII, DEF, vistas de Magic y extracciones de parásitos— ocupan varios
  cientos de megabytes por circuito y viven fuera del repositorio, en un archivo local descrito por
  su propio índice. En el repositorio quedan las fuentes, los abstractos de celda, los reportes de
  firma y los ficheros de métricas.
- **Los conjuntos de datos de entrenamiento y prueba** se descargan con un guion incluido, en lugar
  de versionarse.

Los guiones de cada figura y de cada tabla están en el repositorio junto al capítulo que los usa, de
modo que cualquier cifra de este documento puede rastrearse hasta el comando que la produjo.
