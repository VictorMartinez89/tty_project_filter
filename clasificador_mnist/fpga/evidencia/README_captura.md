# Captura fisica del clasificador MNIST en la iCE40UP5K

Placa: iCESugar v1.5 (Lattice iCE40UP5K, SG48)
Bitstream: mnist_uart.bin  (fpga_mnist_top.v, demo ROM con bucle, PAUSA = 12e6 ciclos)
Puerto: /dev/cu.usbmodem1302 @ 115200 8N1
Duracion: 12 s  ->  460 bytes  ->  41 lineas bien formadas
Fecha: 2026-09-08

El diseno lleva 10 digitos de MNIST embebidos en el bitstream. Para cada uno
recorre el front-end (Sobel + octantes + piramide 2x2) y el clasificador lineal
(400 MAC en serie + argmax), y emite por UART una linea "e->p o" / "e->p X",
donde e es la etiqueta esperada y p la prediccion del circuito.

RESULTADO (cada digito repetido 3-6 veces, respuesta identica siempre):

  esperado  circuito
     0         0     ok
     1         1     ok
     2         0     ERROR
     3         8     ERROR
     4         4     ok
     5         5     ok
     6         6     ok
     7         7     ok
     8         8     ok
     9         9     ok

  8/10 aciertos.

Coincide EXACTAMENTE con la simulacion en iverilog del mismo RTL, incluidos
los dos errores. Reproducir los errores, y no solo los aciertos, es la prueba
fuerte: el silicio no esta "acertando por casualidad", esta ejecutando el
mismo modelo bit a bit.

Los dos fallos son coherentes con la matriz de confusion medida sobre las
10 000 imagenes de test: 2->0 y 3->8 son dos de los pares mas confundidos,
y 0 y 8 son las dos clases "iman" (recall alto, precision baja).

El archivo captura_uart_ice40up5k.txt es el flujo de bytes crudo, sin editar.
Los caracteres faltantes en algunas lineas son perdidas del CDC del USB, no
del circuito: ninguna linea bien formada contradice a otra.

---

## Evidencia visual del sistema completo (demo de camara)

- `foto_placa_icesugar.jpeg` / `foto_placa_web.jpg` — la iCESugar con el PMOD-TFTLCD v1.1.
  El recuadro verde delimita la ventana de 28x28 que se le entrega al clasificador; el digito
  naranja debajo es el veredicto que el propio circuito dibuja en la pantalla.
- `video_placa_icesugar.mp4` — 1.75 s del mismo montaje en funcionamiento.

Esto documenta la cadena COMPLETA en hardware: sensor OV7670 -> sincronizacion por href ->
Sobel -> magnitud -> octantes -> piramide 2x2 -> 32 contadores -> 400 MAC -> argmax -> ILI9341.
Sobre la exactitud frente a la camara vale lo medido en la Parte 181 (nivel de azar por
desplazamiento de dominio); esta evidencia prueba que el camino de datos funciona de punta a
punta, no que la clasificacion desde camara sea correcta.
