# El clasificador de dígitos en la FPGA

El mismo `mnist_top` verificado bit a bit contra el golden (Parte 174), ahora corriendo en la
**iCESugar v1.5 (iCE40UP5K)**. Los diez dígitos de prueba viajan **dentro del bitstream** —la FPGA
no tiene de dónde leer imágenes— y el resultado sale por **UART**.

## Qué se ve

Terminal serie a **115200 8N1**:

```
0->0 o
1->1 o
2->0 X
3->8 X
4->4 o
5->5 o
6->6 o
7->7 o
8->8 o
9->9 o
```

Y los LEDs: **verde** fijo cuando terminó la ronda, **rojo** parpadeando si hubo algún error,
**azul** de latido.

## Cómo construirlo

```bash
# EN LA VM UBUNTU (nextpnr no está en el Mac)
source ~/Documents/UN/oss-cad-suite/environment
cd /mnt/share/utm-share/fpga_mnist
bash build_fpga.sh
```

Después, copiar `mnist.bin` al disco **iCELink** (en el Mac, `/Volumes/iCELink`).

## Antes de grabar: simularlo

`tb_fpga.v` simula el diseño **completo** y **decodifica el UART**, así que se ve exactamente lo
que va a salir por el puerto serie sin tocar la placa:

```bash
iverilog -g2012 -I../rtl -o /tmp/fpga.vvp -s tb_fpga \
    tb_fpga.v rom_digitos.v uart_tx.v fpga_mnist_top.v \
    ../rtl/linebuf3x3.v ../rtl/mnist_feat.v ../rtl/mnist_clf.v ../rtl/mnist_top.v
vvp /tmp/fpga.vvp
```

## Lo que ocupa (yosys, `synth_ice40`)

| recurso | usado | disponible | |
|---|---:|---:|---|
| **LUT4** | **1 818** | 5 280 | **34 %** |
| **BRAM (4 kbit)** | **20** | 30 | **67 %** — 16 son la ROM de dígitos, 4 los line-buffers |
| flip-flops | ~740 | — | |
| DSP | **0** | 8 | los ocho quedan libres |

Los line-buffers se van **solos** a BRAM: no hizo falta pedirlo.

> **Nota sobre los DSP.** La iCE40UP5K trae 8 multiplicadores de 16×16 con acumulador de 32 bits,
> y este diseño **no usa ninguno** — el Sobel es shift-add y el MAC del clasificador es de 4×11
> bits, demasiado chico para que valga la pena. Es una diferencia real con el ASIC: en la FPGA el
> multiplicador ya está pagado y sobra; en sky130 hay que construirlo con celdas.

## Los archivos

| archivo | qué es |
|---|---|
| `gen_rom_digitos.py` | genera `rom_digitos.v` con 10 dígitos de MNIST |
| `rom_digitos.v` | **generado** — 7 840 bytes de imagen + las etiquetas |
| `uart_tx.v` | transmisor serie 8N1 |
| `fpga_mnist_top.v` | la FSM que recorre los dígitos y arma la línea de texto |
| `fpga_mnist.pcf` | pinout: clk=35, uart=6, LEDs 39/40/41 |
| `tb_fpga.v` | simulación completa con decodificador de UART |
| `build_fpga.sh` | yosys → nextpnr → icepack, **para la VM** |
