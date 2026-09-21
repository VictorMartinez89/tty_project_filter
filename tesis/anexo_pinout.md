# Anexo C. Asignación de pines

> Fuente: `clasificador_mnist/fpga/mnist_cam.pcf` — el fichero **efectivamente grabado y verificado
> sobre la tarjeta**, no una transcripción.

## C.1 La tarjeta

Las implementaciones físicas se realizaron sobre una **iCESugar v1.5** con FPGA **iCE40UP5K**, una
cámara **OV7670** y una pantalla **TFT ILI9341** por SPI.

## C.2 Asignación

| Señal | Pin | Grupo |
|---|---:|---|
| `clk` | 35 | reloj de sistema |
| `cam_xclk` | 2 | cámara — reloj que se le entrega |
| `cam_scl` | 27 | cámara — reloj de configuración |
| `cam_sda` | 26 | cámara — dato de configuración |
| `cam_pclk` | 28 | cámara — reloj de píxel |
| `cam_href` | 32 | cámara — referencia de línea |
| `cam_d[0]` | 48 | cámara — bus de datos |
| `cam_d[1]` | 46 | |
| `cam_d[2]` | 44 | |
| `cam_d[3]` | 43 | |
| `cam_d[4]` | 38 | |
| `cam_d[5]` | 34 | |
| `cam_d[6]` | 31 | |
| `cam_d[7]` | 42 | |
| `tft_sck` | 37 | pantalla — reloj SPI |
| `tft_mosi` | 36 | pantalla — dato |
| `tft_cs` | 25 | pantalla — selección |
| `tft_dc` | 23 | pantalla — dato/comando |
| `led_r` | 39 | estado |
| `led_g` | 40 | |
| `led_b` | 41 | |

## C.3 Una advertencia que costó media hora

**Varios comentarios de cabecera de los fuentes de este trabajo contienen la asignación equivocada**
—concretamente, `cam_scl` y `cam_sda` aparecen intercambiados respecto de la tabla anterior— mientras
que el fichero de restricciones tiene la correcta.

El origen es trivial: el comentario se escribió de memoria y el fichero se ajustó por prueba. Pero la
consecuencia no lo es, porque al preparar un diseño nuevo la tentación es **transcribir** la
asignación desde el comentario en vez de **copiar** el fichero que ya funcionó. Hacerlo produjo, en
una ocasión, dos señales de estado cruzadas y media hora de diagnóstico de un circuito que estaba
bien.

> La regla adoptada: **el fichero de restricciones probado manda sobre cualquier comentario.** Al
> armar un diseño nuevo se copia, no se transcribe.

## C.4 El orden del bus de datos

Obsérvese que los ocho bits de la cámara **no ocupan pines consecutivos ni ordenados**: el bit 7 está
en el pin 42, entre el bit 3 (pin 43) y el bit 4 (pin 38). La asignación responde a la disposición
física del conector y no a ninguna lógica del diseño.

Esa irregularidad la hace especialmente propensa a errores de transcripción, y fue el objeto de uno
de los experimentos de diagnóstico del desarrollo: un diseño que hacía que la propia tarjeta
informara por el puerto serie qué bits del bus estaban permanentemente a un valor fijo, en lugar de
inferirlo observando la imagen.
