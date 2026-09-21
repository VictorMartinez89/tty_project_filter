# Esquemáticos RTL de los siete diseños

Dos clases de figura, y **conviene no confundirlas en el pie**:

## Generados del RTL (yosys + netlistsvg)
Salen del Verilog real: `generar.sh` los produce y `xilinx.py` los reviste con la paleta
del RTL Viewer de Xilinx ISE — fondo negro, marco cian, cajas verdes, nets rojas.

| fichero | diseño | tamaño | celdas |
|---|---|---:|---:|
| `sobel_top_x.svg` | filtro Sobel | 1 174 × 1 034 | 26 |
| `canny1_top_x.svg` | Canny 1-salto | 3 000 × 996 | 58 |
| `trans_x.svg` | motor de histéresis transitiva | 5 494 × 996 | 513 |

En el del Canny se ven **los tres `linebuf3x3`** en verde: son las tres líneas de retardo
que explican sus 8 ciclos de latencia (§5.5.2).

## Dibujados a propósito (diagramas de bloques)
| fichero | diseño |
|---|---|
| `bloq_vision_top.svg` | cámara + Sobel + framebuffer + pantalla |
| `bloq_vision_canny_top.svg` | ídem con Canny |
| `bloq_vision_sobel_mnist.svg` | cámara + Sobel + clasificador + pantalla |
| `bloq_vision_canny_mnist.svg` | ídem con Canny |

**Por qué estos no se generan:** son módulos MONOLÍTICOS —toda la lógica vive en el top,
sin submódulos que agrupar—, así que su esquemático automático da **41 114 × 31 705 px**
en el caso de `vision_top`: correcto y completamente ilegible. Xilinx ISE haría lo mismo.

Las etapas y los pines **no son de memoria**: se extrajeron del RTL (lista de puertos del
`module`, `always @(posedge ...)` para los dominios de reloj, e instancias para las cajas
con nombre). Se dibujan con `dibujar.py`.

**Código de color:** verde = dominio `clk`; **ámbar = dominio `cam_pclk`**, el de la cámara;
cian = submódulo con nombre propio o memoria. El cruce entre dominios está dibujado como
caja («cruce 2 FF»), porque es lógica real y no un detalle de presentación.

## Reproducir
    sh generar.sh        # los tres generados
    python3 dibujar.py   # los cuatro de bloques
Necesita `yosys` y `netlistsvg` (`npm install netlistsvg`).
