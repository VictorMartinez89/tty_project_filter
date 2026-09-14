# SoC RISC-V + clasificador MNIST, funcionando en la iCE40UP5K

Placa: iCESugar v1.5 (iCE40UP5K, SG48) · 2026-09-13
Bitstream: `mnist_soc.bin` (fpga_mnist_soc.v)
Puerto: /dev/cu.usbmodem11302 @ 115200 8N1

## Qué hay adentro del chip

    FemtoRV32 (RV32I) + ROM de 7 instrucciones + periferico 0x0045
        |
        |  thr = 90   <- lo escribe el CPU, NO esta cableado
        v
    rom_digitos (10 digitos de MNIST) -> mnist_feat -> mnist_clf -> UART

## Recursos (nextpnr)

    ICESTORM_LC   4670/5280   88 %
    ICESTORM_RAM    20/30     66 %
    ICESTORM_SPRAM   0/4       0 %      <- 128 KB sin usar
    clk_i (pin)    251.57 MHz  PASS
    clk (dividido)   8.97 MHz  PASS at 6.00 MHz

El reloj se divide a la mitad: con el CPU adentro el camino critico no cierra a 12 MHz
(8.89 MHz maximo). Esta demo no es de tiempo real, asi que 6 MHz sobran.

## Resultado

    0->0 o   1->1 o   2->0 X   3->2 X   4->4 o
    5->5 o   6->6 o   7->7 o   8->8 o   9->9 o     ->  8/10

Coincide EXACTAMENTE con la simulacion en iverilog del mismo diseno, incluido el error
NUEVO del 3.

## El detalle que prueba que el CPU hace algo

    Parte 184 (sin CPU, thr=60):  8/10, errores 2->0 y 3->8
    aca      (con CPU, thr=90):   8/10, errores 2->0 y 3->2

El error del 3 CAMBIO de 8 a 2. No es ruido: es el umbral que escribio el firmware
moviendo una decision del clasificador. Y la simulacion lo habia predicho antes de grabar.
