# RISC-V + Canny 1-salto + clasificador MNIST en la iCE40UP5K

Placa: iCESugar v1.5 (iCE40UP5K, SG48) · 2026-09-14
Bitstream: `mnist_soc_canny.bin`
Recursos: 4 733/5 280 LC (89 %) · 22/30 BRAM · reloj dividido a 6 MHz (PASS, 8.74 MHz max)

## Adentro del chip

    FemtoRV32 + ROM de 7 instrucciones + periferico 0x0045
        |
        |  thr_hi=90  thr_lo=32   <- constante 0x5A20, el firmware del CANNY
        v
    10 digitos en ROM -> mnist_feat_canny -> mnist_clf_canny_fw -> UART

## Resultado

    0->0 o   1->1 o   2->2 o   3->2 X   4->4 o
    5->5 o   6->6 o   7->7 o   8->8 o   9->9 o      ->  9/10

Coincide EXACTAMENTE con la simulacion en iverilog, incluido el error del 3.

## Las tres versiones del mismo chip

    Parte 184  Sobel, sin CPU, thr=60      2->0 X  3->8 X  5->5 o    8/10
    §14        Sobel, con CPU, thr=90      2->0 X  3->2 X  5->5 o    8/10
    §18        CANNY, con CPU, 90/32       2->2 o  3->2 X  5->5 o    9/10

El Canny ARREGLA el 2, que es exactamente lo que la §15 predijo sobre 10 000 imagenes:
el digito 2 sube de F1 0.849 a 0.920 con este front-end. La estadistica senalo cual
de los diez digitos iba a mejorar, y el silicio lo mostro.

## El bug que se encontro en el camino

La primera version dio 8/10 en la placa y 9/10 en simulacion, con el 3 y el 5 distintos.
Causa: `thr_lo` se sacaba con una REFERENCIA JERARQUICA (`SOC.flt_tlo`) en vez de un puerto.

    iverilog: la resuelve        -> thr_lo = 32   (firmware corregido)
    yosys:    cable implicito    -> thr_lo = 0    (firmware degradado)

Las dos herramientas leyeron el mismo archivo y construyeron circuitos DISTINTOS. La
simulacion verificaba un circuito que no era el que se fabricaba. Arreglado con un
puerto (`thr_lo_o`): la placa paso a 9/10 y volvio a coincidir con la simulacion.
