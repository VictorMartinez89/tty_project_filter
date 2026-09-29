# Prueba con cámara: 11 escenas × 3 respuestas = 33 intentos

Protocolo (Victor, 28-sep-2026): se muestra cada escena y se anotan las TRES respuestas que da la pantalla,
una por intento (quitar y volver a poner la hoja entre intentos). Lo ideal: la escena N → [N, N, N].

- Diseño en la placa: ______________  (Canny-78 / Canny-98)     md5 del .bin: ______________
- Fecha y hora: ______________   Luz: ______________   Distancia cámara-papel: ______ cm
- Papel: una hoja por dígito, marcador grueso, dígito de ~3/4 del alto del marco verde, cámara fija.

| escena | intento 1 | intento 2 | intento 3 | aciertos |
|---|---|---|---|---:|
| 1 | | | | |
| 2 | | | | |
| 3 | | | | |
| 4 | | | | |
| 5 | | | | |
| 6 | | | | |
| 7 | | | | |
| 8 | | | | |
| 9 | | | | |
| 0 | | | | |
| nada (hoja en blanco) | | | | |
| **total** | | | | **__ / 33** |

Cómo se lee (lo calcula `prueba_camara_33.py` al pasarle la tabla):
- El azar puro acierta 1 de 11 (9,1 %): unas 3 de 33.
- Con 33 intentos el margen es ancho: un 60 % medido significa, al 95 %, algo entre ~42 % y ~76 %.
- Se reportan también las respuestas «NADA» ante un dígito (el circuito se abstiene) aparte de los errores.
