# Planos de los dos reconocedores en Tiny Tapeout (IHP SG13G2)

Capturas del visor GDS de Tiny Tapeout, lanza **IHP26b**, flujo **LibreLane 3.0.5**.
Los archivos se llamaron `pan_*` en el escritorio pero son los proyectos de Tiny Tapeout
`tt_mnist_sobel` y `tt_mnist_canny` —sin camara y sin CPU—, NO los chips `pan_sobel` /
`pan_canny` de sky130, que llevan las dos cosas.

| archivo | que muestra |
|---|---|
| `tt_mnist_sobel_capas.png`  | Sobel, vista de capas de metal (MET1–MET5 en color) |
| `tt_mnist_sobel_celdas.png` | Sobel, vista de celdas + registro del sistema (116 314 FET) |
| `tt_mnist_canny_capas.png`  | Canny, vista de capas de metal |
| `tt_mnist_canny_celdas.png` | Canny, vista de celdas, con los pines a 0x7F |

Las dos franjas de 8x2 mosaicos se ven como tres racimos de logica separados por los
canales de alimentacion verticales. El de la derecha queda vacio en el Sobel y lleno en
el Canny: son los 1 402 celdas de diferencia.
