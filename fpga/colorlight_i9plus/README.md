# FPGA prototipo — Colorlight i9+ v6.1 (Xilinx Artix-7 `XC7A50T-FGG484`)

Prototipo en FPGA del SoC RISC-V + filtro (Sobel/Canny) con cámara **OV7670**.
Toolchain **openXC7** (`yosys` + `nextpnr-xilinx` + `prjxray`), programar con **openocd + CH347**.
Referencia de la placa: https://github.com/wuxx/Colorlight-FPGA-Projects

> ⚠️ **No es una iCESugar.** Es Colorlight (Xilinx Artix-7), no Lattice. El RTL (tu Verilog)
> porta igual; cambian la síntesis, los *constraints* de pines y el I/O.

## ⚠️ Problema de arquitectura (arm64 vs amd64)
El instalador de openXC7 baja un **snap de amd64**; si tu máquina es **arm64** falla:
`snap "openxc7" ... (amd64) are incompatible with this system (arm64)`.

Opciones:
- **A (recomendada): PC/VM Linux x86-64.** El snap instala directo; síntesis + programación USB funcionan. El Mac arm64 sirve para escribir/simular RTL (`yosys`/`iverilog`/`cocotb`), pero la síntesis/programación de esta placa pide x86-64 Linux.
- **B: Docker `--platform linux/amd64`** (QEMU) para *sintetizar* — pero programar por USB/CH347 desde Docker en Mac es complicado.
- **C: compilar `nextpnr-xilinx` + `prjxray` de fuente para arm64** (pesado: la chipdb del XC7A50T es grande).

> Programar la placa (openocd+CH347) necesita **USB físico** → hazlo en un Linux **local**.

## Blinky (primer paso: validar toolchain + placa)
Archivos aquí: `blinky.v` (LED parpadea), `colorlight_i9plus.xdc` (clk K4, LED A18), `Makefile` (referencia).

Lo más seguro: copia `blinky.v` y `colorlight_i9plus.xdc` dentro de
`demo-projects/blinky-colorlight-i9plus/` (de wuxx, ya configurado para esta placa) y:
```bash
make                                  # genera el bitstream con openXC7
# primera vez: desbloquear la flash
ch347prog-sram unlock_flash_xc7a50t.bit
ch347prog-sram  top.bit               # a SRAM (volátil, rápido para probar)
ch347prog-flash top.bit               # a SPI-Flash (persistente)
```
Si el LED (D2) parpadea ~0.75 Hz → toolchain + placa OK.

## Pines clave (de la placa)
| Señal | Pin FPGA |
|---|---|
| clk 25 MHz | K4 |
| LED D2 | A18 |
| SPI-Flash CS/MISO/MOSI/SCK | T19 / R22 / P22 / L12 |
| SDRAM (M12L64322A 8MB) | CLK E14, A0–A10, DQ0–31, RAS A14, CAS D14, WE D17… |
| Ethernet x2 (B50612D) | (ver schematic) |

## Siguientes pasos
1. **SoC**: `.xdc` que mapee tu `femto` + `peripheral_sobel` (clk K4, reset, UART a 2 GPIO, LED A18).
2. **Cámara OV7670**: módulo Verilog (config SCCB/I²C + captura `PCLK/HREF/VSYNC/D[7:0]`) → stream que alimenta el filtro.
   - El conector de 200 pines lleva sobre todo **SDRAM + Ethernet**. Para la cámara hay que usar pines **libres** (p.ej. **repurpose** de los pines de Ethernet si no usas red), verificando contra el schematic para no chocar con SDRAM.
3. **Salida**: sin HDMI/VGA → guardar el frame filtrado en **SDRAM** y leer por **Ethernet/UART**, o un display SPI por GPIO.
