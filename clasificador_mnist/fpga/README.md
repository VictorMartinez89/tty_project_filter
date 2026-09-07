# El clasificador de dígitos en la FPGA

**Dos demos.** El segundo es el que se ve:

```bash
bash build_fpga.sh uart   # los 10 dígitos de la ROM, por el puerto serie
bash build_fpga.sh cam    # LA CÁMARA: escribí un dígito y miralo en el TFT
```

---

## 📷 Demo de cámara — `mnist_cam_display.v`

Escribís un dígito **grueso y oscuro sobre papel blanco**, lo ponés frente a la OV7670 llenando el
**marco verde**, y el TFT muestra el dígito reconocido en grande.

La pantalla tiene tres cosas:

| zona | qué es |
|---|---|
| 224×224 arriba | **lo que el clasificador ve de verdad**: las 28×28 ampliadas ×8 |
| marco verde de 3 px | la **guía de encuadre** |
| abajo | el dígito reconocido, en siete segmentos |

> ### 🎯 El marco no es adorno: es la solución al problema de MNIST
> MNIST viene **normalizado en tamaño y centrado por centro de masa**. Lo que ve una cámara no.
> En vez de normalizar en hardware —caro y frágil— se hace lo que hace un lector de QR: **se fija
> una ventana y el centrado lo hace la persona.** Es co-diseño en su forma más barata: mover un
> requisito del silicio a la interfaz de uso.

**Verificado en simulación con la cámara emulada** (`tb_cam_mnist.v` + `ov7670_model.v`), metiendo
cada dígito ampliado ×16 como si fuera papel frente al lente:

```
0->0 ok   3->3 ok   6->6 ok   9->9 ok
1->1 ok   4->4 ok   7->7 ok
2->6 X    5->5 ok   8->8 ok        9 de 10
```

Y la ventana de 28×28 que reconstruye desde la cámara es **idéntica al dígito original de MNIST**
—diferencia media 0.0—, así que la cadena `cámara → ventana` no pierde nada.

| recurso (demo de cámara) | usado | de | |
|---|---:|---:|---|
| LUT4 | **2 871** | 5 280 | **54 %** |
| BRAM | 6 | 30 | 20 % |
| DSP | 0 | 8 | |

---

## 📟 Demo de UART (el primero)

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
