# iCESugar v1.5 (Lattice iCE40UP5K-SG48) — prototipo FPGA: cámara OV7670 → filtro → LCD

Prototipo en FPGA de la tesis: **OV7670 → (Gaussian → Sobel → NMS → doble umbral → histéresis) → TFT LCD**.
Toolchain 100% libre, corre **nativo en arm64** (oss-cad-suite).

## Estructura

| Carpeta | Qué es |
|---|---|
| `src/` | **Fuentes de trabajo actuales** (lo que se sintetiza hoy). Incluye `cam_canny2_display.v` = Canny **Etapa 2a**. |
| `labs/` | **Los 17 laboratorios** — el registro experimental completo (documentado en el notebook, **Parte 19**). Cada carpeta guarda *su* versión de los archivos: por eso `cam_display.v` difiere entre `error/`, `intro-error2/` y `Muestra1/`. |
| `blinky.v`, `icesugar.pcf`, `Makefile` | bring-up mínimo (valida el toolchain) |

> Los artefactos de build (`*.json`, `*.asc`, `*.bin`, ~51 MB) **no se versionan**: se regeneran con yosys/nextpnr.

## Diseños principales (`src/`)

| Archivo | Qué hace | Estado |
|---|---|---|
| `cam_sobel_display.v` | cámara → submuestreo 60×80 → **Sobel 3×3** → LCD | ✅ anda en HW |
| `cam_canny_display.v` | + **Gaussian 3×3** → Sobel → **doble umbral** (Canny **Etapa 1**) | ✅ anda en HW |
| `cam_canny2_display.v` | + **histéresis de 1 salto** (Canny **Etapa 2a**) | ✅ sintetiza (+257 FF, +1 LUT) |
| `cam_sccb_id.v` | lee el **ID 0x76** de la cámara por SCCB (test de vida) | ✅ |
| `tft_test.v`, `tft_pattern.v`, `display_fb.v` | pantalla ILI9341 (SPI) + framebuffer | ✅ |

## Pineado autoritativo (`cam_display.pcf`)

El bitstream de cámara+LCD usa **estos** pines. El cableado **debe** coincidir con el PCF del `.bin` que se flashea:

```
clk=35   cam_xclk=2   SIOC(scl)=26   SIOD(sda)=27   cam_pclk=28   cam_href=32
cam_d[0..7] = 48, 46, 44, 43, 38, 34, 31, 42
tft_sck=37   tft_mosi=36   tft_cs=25   tft_dc=23
led_r/g/b = 39/40/41
```

⚠️ **Cuidado:** `labs/cam-ov7670-ID76/cam_sccb_id.pcf` **intercambia** SIOC=27 / SIOD=26 respecto de
`cam_display.pcf`. Si se flashea un bitstream y se cablea con el pineado del otro, **la cámara nunca
configura** (y no da error: simplemente el LED no se pone verde).

## Notas de diseño (aprendidas en el laboratorio)

- **PMOD limpios:** P2 y P3. P1 comparte pines con USB+UART; P4 con los switches SW[0..3].
- **Sin VSYNC:** el pin daba falso contacto → no se sincronizan cuadros. El puntero de escritura corre
  libre (buffer circular de 4800) y la imagen se **encuadra en la lectura** con `OFFSET`.
- **`OFFSET`** cambia con cada etapa del pipeline (más latencia ⇒ más desplazamiento):
  `cam_display`=2400 · `cam_sobel_display`=1920 · `cam_canny_display`=1800 · `cam_canny2_display`=1861.
  Si la imagen sale corrida, ajustar de a ~60.
- **El orden importa:** decimar a 60×80 **primero** y filtrar después. Al revés (filtrar full-res y
  luego decimar) **se pierden los bordes** (un borde mide 1 px; al quedarse con 1 de cada 10 columnas
  se descarta casi todo).
- **0 multiplicadores** (0 DSP) en toda la cadena: solo sumas y shifts.

## Construir y programar

```bash
yosys -p "synth_ice40 -top top -json out.json" src/cam_canny2_display.v
nextpnr-ice40 --up5k --package sg48 --pcf src/cam_display.pcf --json out.json --asc out.asc
icepack out.asc out.bin
# arrastrar out.bin al disco USB "iCELink"
```
