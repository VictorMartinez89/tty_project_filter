---
title: "Diseño de un MicroControlador con arquitectura RISC-V"
subtitle: "Un SoC RISC-V con tres detectores de bordes y un clasificador de dígitos, del modelo de referencia al GDSII firmado"
author: "Victor Alfonso Martinez Solarte"
date: "Septiembre de 2026"
lang: es-CO
documentclass: report
toc: true
toc-depth: 3
numbersections: false
---

\newpage

# Resumen

Esta tesis lleva un sistema de visión desde el modelo de referencia en Python hasta el silicio
firmado, y usa ese recorrido para medir qué decide en la práctica si un algoritmo cabe en un circuito
integrado. La respuesta que sostienen los diseños implementados es que rara vez lo decide el
algoritmo: lo decide la memoria.

El sistema es un SoC RISC-V —FemtoRV32— que orquesta tres detectores de bordes sobre video en vivo de
una cámara OV7670: Sobel, Canny de un salto y Canny con histéresis transitiva resuelta por
reconstrucción morfológica. Sobre ese mismo front-end se construyó además un clasificador de dígitos
manuscritos, de modo que un solo camino de datos —ventana 3×3, acumulación y umbral— atiende un patrón
escrito a mano, uno buscado y uno aprendido.

Cada núcleo se verificó bit a bit contra el modelo de referencia, se integró físicamente en una FPGA
iCE40UP5K con cámara y pantalla, y se llevó a ASIC: diecisiete circuitos con GDSII firmado, quince en
sky130 con OpenLane y dos en IHP SG13G2 con LibreLane. El sistema completo —procesador, front-end
Canny y clasificador— reconoce nueve de cada diez dígitos manuscritos captados por la cámara sobre la
FPGA física, coincidiendo con lo que la simulación predecía.

Dos reconocedores llegan a silicio firmado. El de cuarenta rasgos alcanza **94,20 %** sobre las diez
mil imágenes de prueba de MNIST y cabe en ocho por dos tiles de **Tiny Tapeout**, listo para la
lanzadera abierta SKY26d. **Canny-78**, que elige 78 rasgos entre 128 contadores de orientación,
alcanza **97,22 %**, reproduce el modelo en la tarjeta imagen por imagen —diez mil de diez mil— y firma
en sky130 en 1,122 mm², o en 0,829 mm² con la memoria de rasgos recortada a lo que usa.

Las mediciones muestran que el sobrecoste en área del Canny frente al Sobel cae del 123 % al 3 %
según cuánto más haga el circuito, y que comprar robustez al umbral en el front-end cuesta unas seis
veces menos que comprarla con un procesador. Una verificación eléctrica del camino crítico en SPICE
atribuye la discrepancia con el analizador estático a los parásitos internos de la celda y no a la
resistencia de la interconexión. Ningún circuito ha sido fabricado todavía.

**Palabras clave:** RISC-V; FemtoRV32; detección de bordes; Sobel; Canny; reconstrucción morfológica;
clasificación de patrones; MNIST; FPGA; iCE40UP5K; ASIC; sky130; OpenLane; co-diseño hardware/software.

\newpage

# Abstract

This thesis carries a vision system from its Python reference model to signed-off silicon, and uses
that journey to measure what actually decides whether an algorithm fits on an integrated circuit. The
answer supported by the implemented designs is that the algorithm rarely decides it: memory does.

The system is a RISC-V SoC —FemtoRV32— orchestrating three edge detectors over live video from an
OV7670 camera: Sobel, single-pass Canny, and Canny with transitive hysteresis resolved by
morphological reconstruction. On top of that same front-end a handwritten-digit classifier was also
built, so that a single datapath —3×3 window, accumulation and threshold— serves a pattern that is
handwritten, one that is searched for, and one that is learned.

Each core was verified bit-exact against the reference model, integrated physically on an iCE40UP5K
FPGA with camera and display, and taken to ASIC: seventeen signed-off GDSII layouts, fifteen in sky130
with OpenLane and two in IHP SG13G2 with LibreLane. The complete system —processor, Canny front-end
and classifier— recognises nine out of ten handwritten digits captured by the camera on the physical
FPGA, matching what simulation had predicted.

Two recognisers reach signed-off silicon. The forty-feature one reaches **94.20 %** over the full
ten-thousand-image MNIST test set and fits in eight by two **Tiny Tapeout** tiles, ready for the
SKY26d open shuttle. **Canny-78**, which selects 78 features out of 128 orientation counters, reaches
**97.22 %**, reproduces the model on the board image by image —ten thousand out of ten thousand— and
signs off in sky130 at 1.122 mm², or 0.829 mm² with its feature memory trimmed to what it uses.

Measurements show that the Canny's area overhead against the Sobel falls from 123 % to 3 % depending
on how much more the circuit does, and that buying threshold robustness in the front-end costs about
six times less than buying it with a processor. An electrical verification of the critical path in
SPICE attributes the discrepancy with the static timing analyser to the cell's internal parasitics
rather than to interconnect resistance. No circuit has been fabricated yet.

**Keywords:** RISC-V; FemtoRV32; edge detection; Sobel; Canny; morphological reconstruction; pattern
classification; MNIST; FPGA; iCE40UP5K; ASIC; sky130; OpenLane; hardware/software co-design.

\newpage
