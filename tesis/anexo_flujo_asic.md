# Anexo E. Instalación del flujo ASIC

> Este anexo describe cómo se montó el entorno con el que se obtuvieron todos los resultados de
> silicio de este trabajo. **No reproduce las órdenes**: para eso están las dos guías del grupo de las
> que parte —el manual del flujo ASIC de J. Ruiz [Ruiz] y las notas de la asignatura de VLSI del
> director [Camargo, VLSI]—. Lo que aquí se describe es qué hace cada paso, qué necesita y dónde falla,
> que es lo que esas guías no pueden decir porque suponen que todo saldrá bien.
>
> El orden es el de la documentación de partida. Se conserva a propósito: **las dependencias siguen
> ese orden**, y saltárselo obliga a volver atrás.

## E.1 Yosys

Yosys es el sintetizador: el programa que convierte la descripción en Verilog en una red de puertas
lógicas. Es la primera pieza del flujo y la que determina qué se puede escribir en el RTL, porque
soporta Verilog-2005 y no el subconjunto completo de SystemVerilog.

Se obtiene clonando su repositorio y compilándolo. El paso laborioso no es la compilación sino lo que
la precede: hace falta instalar antes el compilador de C++, el generador de analizadores sintácticos
y el de analizadores léxicos, las bibliotecas de desarrollo de Tcl, de lectura de línea de órdenes,
de interfaz con funciones externas y de compresión, tres bibliotecas de Boost —sistema, Python y
sistema de ficheros— y las herramientas de dibujo de grafos con las que Yosys representa los
circuitos. Son catorce paquetes, y **ninguno de ellos aparece en el mensaje de error hasta que la
compilación llega al punto en que lo necesita**. Antes de compilar hay que seleccionar además la
variante del compilador que se va a usar.

**Instalación:**

```
git clone https://github.com/YosysHQ/yosys.git
cd yosys
sudo apt install make
sudo apt-get install build-essential clang bison flex \
    libreadline-dev gawk tcl-dev libffi-dev git \
    graphviz xdot pkg-config python3 libboost-system-dev \
    libboost-python-dev libboost-filesystem-dev zlib1g-dev
make config-gcc
make
sudo make install
```

## E.2 Icarus Verilog

Icarus Verilog es el compilador y simulador de Verilog con el que se ejecuta todo el banco de pruebas
de este trabajo. Se instala con una sola orden del gestor de paquetes de la distribución.

Merece una nota que no está en las guías: **Icarus rechaza identificadores no declarados, y Yosys
no**. Verilog-2005 permite crear implícitamente un cable de un bit ante un nombre desconocido, de modo
que una errata en un identificador produce en síntesis un circuito distinto del pretendido, en
silencio. Compilar con Icarus aunque el destino sea la síntesis funciona, por tanto, como un
verificador gratuito de erratas.

**Instalación:**

```
sudo apt-get install iverilog
```

## E.3 GTKWave

GTKWave es el visor de formas de onda: lee los ficheros de volcado que produce Icarus y permite
inspeccionar señal por señal qué hizo el circuito en cada ciclo. Se instala igual que el anterior,
con una orden del gestor de paquetes.

Es la herramienta con la que se resolvieron la mayor parte de las discrepancias contra el modelo de
referencia, y conviene subrayar por qué: un banco de pruebas dice *si* el resultado difiere; el visor
de ondas dice *cuándo* empezó a diferir, que es la pregunta que lleva a la causa.

**Instalación:**

```
sudo apt install gtkwave
```

## E.4 ngspice

ngspice es el simulador SPICE de código abierto, y se usa para la verificación eléctrica: comprobar,
a nivel de transistor y no de puerta lógica, cómo se comporta realmente un camino crítico.

A diferencia de las anteriores no se clona, sino que se descarga como archivo comprimido de una
versión concreta y se compila desde ahí. Su configuración pide explícitamente el soporte gráfico de
X y la biblioteca de lectura de línea de órdenes, y se acostumbra a construirlo en un subdirectorio
aparte del código fuente, de modo que los ficheros generados no se mezclen con los originales. Sus
dependencias son pocas: las herramientas básicas de compilación y la biblioteca de artefactos de
X11.

**Instalación:**

```
# dependencias
sudo apt-get install build-essential
sudo apt-get install libxaw7-dev

# compilacion, en un subdirectorio aparte
tar -zxvf ngspice-40.tar.gz
cd ngspice-40
mkdir release
cd release
../configure --with-x --with-readline=yes --disable-debug
make
sudo make install
```

## E.5 OpenSTA

OpenSTA es el analizador de tiempos estático: dado un circuito ya mapeado a puertas y una
descripción de sus restricciones temporales, dice si cierra a la frecuencia pedida y cuál es el
camino que menos margen tiene. Es la herramienta que produce las cifras de holgura que aparecen en
el Capítulo 5.

Se construye con CMake en lugar de con el sistema de configuración clásico, y necesita, además del
compilador y del intérprete de Tcl, el generador de interfaces entre lenguajes con el que expone sus
funciones a Tcl. Como en el caso de Yosys, la práctica sensata es instalar la lista completa de
dependencias antes de empezar.

**Instalación:**

```
sudo apt-get install cmake clang gcc tcl swig bison flex

git clone https://github.com/The-OpenROAD-Project/OpenSTA.git
cd OpenSTA
mkdir build
cd build
cmake ..
make
sudo make install
```

## E.6 Magic

Magic es la herramienta de diseño físico con la que se inspeccionan los planos, se generan las vistas
abstractas de celda y se extraen los parásitos que alimentan la verificación eléctrica. Procede de la
Universidad de California en Berkeley y es, con diferencia, la más exigente de instalar.

Su lista de dependencias es larga y heterogénea porque Magic dibuja: necesita el preprocesador de
macros, un intérprete de órdenes de la familia C, las cabeceras de desarrollo de X11, las de Tcl y
las de Tk, la biblioteca de dibujo vectorial, las de OpenGL y la de manejo de terminal. Sólo después
de eso se clona y se compila. **Es el punto del montaje donde más tiempo se pierde**, y la razón es
siempre la misma: el mensaje de error nombra un fichero de cabecera que falta, no el paquete que lo
contiene, de modo que hay que traducir de uno a otro.

**Instalación:**

```
sudo apt-get install m4 tcsh csh libx11-dev tcl-dev tk-dev \
    libcairo2-dev mesa-common-dev libglu1-mesa-dev libncurses-dev

git clone https://github.com/RTimothyEdwards/magic
cd magic
./configure
make
sudo make install
```

## E.7 OpenLane y Docker

OpenLane no es una herramienta sino una orquestación: recorre el camino completo desde el RTL hasta
el GDSII invocando por dentro a OpenROAD para el emplazamiento y el ruteo, a Yosys para la síntesis,
a Magic y a Netgen para la verificación física y a KLayout para las comprobaciones geométricas.

Poner de acuerdo todas esas piezas en versiones compatibles entre sí es exactamente el problema que
OpenLane resuelve distribuyéndose como imagen de contenedor. De ahí se sigue algo que conviene decir
con claridad: **Netgen y OpenROAD no se instalan nunca en este trabajo. Viven dentro de esa imagen**,
y de hecho no figuran entre las órdenes disponibles en la máquina anfitriona.

Docker, que es lo que ejecuta esa imagen, no se toma del repositorio de la distribución sino del del
propio proyecto, lo que obliga a registrar antes su clave de firma y su fuente de paquetes. Tras
instalarlo se comprueba con una imagen de prueba, y se añade el usuario al grupo correspondiente para
poder invocarlo sin privilegios de administrador; ese cambio **no surte efecto hasta reiniciar la
sesión**, y es causa habitual de confusión. Hecho todo eso, instalar OpenLane se reduce a clonar su
repositorio y lanzar su compilación, que en realidad descarga la imagen y ejecuta un diseño de prueba
para comprobar que el flujo entero funciona.

Aquí aparece la divergencia con las guías de partida. La orden que registra la fuente de paquetes de
Docker **declara explícitamente la arquitectura x86-64**, y la imagen del flujo hay que tomarla en su
variante para ARM de 64 bits. Es el punto exacto en que una guía escrita para otra máquina deja de
poder seguirse al pie de la letra.

**Instalación, en tres tiempos.** Primero las dependencias del flujo:

```
sudo apt-get update
sudo apt-get upgrade
sudo apt install -y build-essential python3 python3-venv python3-pip make git
```

Después Docker, desde el repositorio del propio proyecto:

```
sudo apt install apt-transport-https ca-certificates curl \
    software-properties-common

curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | sudo gpg --dearmor \
      -o /usr/share/keyrings/docker-archive-keyring.gpg

REPO="deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg]"
REPO="$REPO https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
echo "$REPO" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io

sudo docker run hello-world
sudo groupadd docker
sudo usermod -aG docker $USER
sudo reboot
# tras el reinicio, ya sin sudo:
docker run hello-world
```

> **En ARM, esa línea hay que cambiarla.** El campo `arch=amd64` declara la arquitectura de los
> paquetes que se van a descargar; en una máquina ARM de 64 bits debe decir `arch=arm64`, o el
> gestor de paquetes no encontrará nada que instalar. Es el primer punto en que las guías de partida
> dejan de poder seguirse al pie de la letra.

Y por último OpenLane, cuya compilación en realidad descarga la imagen y ejecuta un diseño de prueba:

```
cd $HOME
git clone https://github.com/The-OpenROAD-Project/OpenLane
cd OpenLane
make
make test
```

> La imagen que `make` descarga debe ser la de la arquitectura correcta. En este trabajo es la
> variante para ARM de 64 bits, y es la que aparece en la orden que levanta el contenedor.

## E.8 El kit de diseño: open_pdks y sky130

El kit de diseño es lo que convierte a todas las herramientas anteriores en algo capaz de producir un
circuito fabricable: contiene las reglas de diseño del proceso, los modelos eléctricos de los
dispositivos y la biblioteca de celdas estándar. Sin él, el flujo no tiene contra qué comprobar nada.

Se obtiene con open_pdks, que se clona, se configura pidiéndole explícitamente el proceso sky130 y se
compila. El resultado es el árbol de ficheros que todas las demás herramientas consultan, y es la
instalación más voluminosa de todo el entorno: ocupa del orden de veintiséis gigabytes, más que todas
las herramientas del flujo juntas.

En la práctica se acabó usando además un gestor de versiones de kit de diseño, que descarga una
compilación ya hecha —unos dos gigabytes— y permite fijar exactamente qué versión del proceso se usó
en cada circuito. Esa trazabilidad no es un lujo: **un cambio de versión del kit cambia las cifras de
área y de tiempos**, y sin poder nombrar la versión, las tablas del Capítulo 5 no serían
reproducibles.

**Instalación:**

```
git clone git://opencircuitdesign.com/open_pdks
cd open_pdks
./configure --enable-sky130-pdk
make
sudo make install
```

## E.9 Xyce

Xyce es un simulador de circuitos analógicos de alto rendimiento, y con él se hizo la
verificación eléctrica del camino crítico. Se construye mediante un guion de compilación publicado
por terceros que resuelve por dentro sus dependencias, y se instala en la jerarquía local del
sistema.

Hay aquí una trampa documentada en las notas de la asignatura y que conviene repetir, porque cuesta
tiempo y el síntoma no apunta a la causa: **Xyce puede no encontrar los ficheros del kit de diseño
porque la carpeta que open_pdks genera no se llama como Xyce espera**. La solución práctica es
renombrar esa carpeta —convirtiéndola de paso en oculta— de modo que los procesos que la necesitan
apunten al sitio correcto. El error que se ve, si no se hace, habla de ficheros de modelo ausentes y
no de un nombre de carpeta.

**Instalación:**

```
git clone https://github.com/ChipFlow/Xyce-build.git
cd Xyce-build/
./build.sh
sudo make install prefix=/usr/local
```

## E.10 El entorno de Tiny Tapeout

Reproducir exactamente el circuito que se envíe a fabricación exige algo distinto de instalar
herramientas: exige **reconstruir el entorno tal como estaba el día del envío**. Para eso hay un guion
que fija las versiones históricas del proyecto —una versión concreta del flujo, una del kit de
diseño, una de open_pdks y una de las herramientas de soporte— en lugar de tomar las más recientes.

Este guion está preparado para x86-64, lo que lo sitúa en el mismo caso descrito en E.7.

**Uso del guion.** Admite dos modos —dentro de contenedor o de forma nativa— y cuatro acciones.
Lo primero que conviene ejecutar es `info`, que no modifica nada:

```
./Docs/create_SDK_TinyTapeOut.sh docker info
./Docs/create_SDK_TinyTapeOut.sh native info
```

Preparar el entorno y ejecutar el endurecimiento completo:

```
./Docs/create_SDK_TinyTapeOut.sh docker all
./Docs/create_SDK_TinyTapeOut.sh native all
```

O separando la preparación de la ejecución, que es lo aconsejable la primera vez:

```
./Docs/create_SDK_TinyTapeOut.sh docker setup
./Docs/create_SDK_TinyTapeOut.sh docker run
```

Tres variables de entorno permiten cambiar dónde se instala, sobre qué copia del proyecto se
trabaja, y si el guion puede instalar dependencias del sistema por su cuenta:

```
TT_SDK_ROOT=/ruta/al/sdk ./Docs/create_SDK_TinyTapeOut.sh docker all
TT_PROJECT_DIR=/ruta/al/proyecto ./Docs/create_SDK_TinyTapeOut.sh docker run
TT_INSTALL_DEPS=0 ./Docs/create_SDK_TinyTapeOut.sh docker setup
```

Los resultados quedan bajo `~/ttsky25b-sdk/`, en un subdirectorio por modo.

## E.11 Simulación del netlist final

El último paso del entorno no sirve para construir un circuito sino para **comprobar el que se
fabricaría**. A partir del netlist posterior al emplazamiento y ruteo del circuito final, junto con
su banco de pruebas y sus reglas de compilación, se simula el diseño tal como quedó en silicio y no
tal como se describió en el RTL.

La compilación se hace activando las opciones que incluyen los pines de alimentación, que seleccionan
los modelos funcionales de las celdas y que fijan un retardo unitario por celda; el resultado se
vuelca a un fichero de ondas y se abre en el visor. La diferencia con simular el RTL es la que
justifica el paso: **aquí se simulan las celdas reales de la biblioteca, con su conectividad final**,
de modo que un error introducido durante la implementación física —y no presente en el código
original— tiene dónde aparecer.

Este trabajo no llegó a explotar ese paso, porque ninguno de sus circuitos ha sido fabricado todavía.
Se documenta aquí porque el entorno queda montado para hacerlo, y porque la documentación de partida
[Ruiz] recoge tres defectos en las interfaces serie del procesador que se localizaron exactamente
por esta vía: dos de ellos quedaban ocultos al simular contra los modelos de las memorias, y sólo
aparecieron al comparar esa simulación con el comportamiento del dispositivo físico. **Es un ejemplo
del mismo principio que atraviesa el Capítulo 3: un modelo que no puede fallar no está verificando
nada.**

**Instalación:**

```
cd tinytapeout
make tt_um_femto
```

