# Anexo D. Recetas del flujo a silicio

> Fuente: los ficheros `config.json` de los veinte directorios de diseño en sky130A.
> Esta tabla se generó leyéndolos, no transcribiéndolos.

## D.1 Qué se configura, y qué no

De los varios centenares de parámetros que admite el flujo, **sólo cinco se tocaron** en todo el
trabajo. El resto conserva su valor por omisión, y esa contención es deliberada: cada parámetro
modificado es una variable más que explicar si un resultado sale distinto del esperado.

| Parámetro | Qué controla |
|---|---|
| `CLOCK_PERIOD` | el periodo objetivo, en nanosegundos |
| `FP_CORE_UTIL` | la fracción del núcleo que se pretende llenar de celdas |
| `PL_TARGET_DENSITY` | la densidad objetivo del emplazador |
| `GRT_ALLOW_CONGESTION` | si se tolera congestión en el ruteo global |
| `FP_ASPECT_RATIO` | la proporción del dado |

## D.2 Las recetas empleadas

| Diseño | Periodo | Utilización | Densidad | Congestión |
|---|---:|---:|---:|:-:|
| `cam_frontend_top` | 20 ns | 40 % | 0,55 | — |
| `lcd_ili9341_top` | 20 ns | 40 % | 0,55 | — |
| `sobel_top` | 20 ns | 35 % | — | — |
| `canny1_top` | 20 ns | 35 % | 0,45 | — |
| `trans_engine_top` | 20 ns | 35 % | 0,45 | — |
| `soc_sobel_top` | 20 ns | 30 % | 0,40 | — |
| `soc_canny1_top` | 20 ns | 30 % | 0,40 | — |
| `soc_trans_top` | 20 ns | 18 % | 0,25 | sí |
| `vision_top` | 20 ns | 18 % | 0,25 | sí |
| `vision_canny_top` | 20 ns | 18 % | 0,25 | sí |
| `vision_sobel_mnist` | 20 ns | 18 % | 0,25 | sí |
| `vision_canny_mnist` | 20 ns | 18 % | 0,25 | sí |
| `pan_sobel` | **30 ns** | 22 % | 0,32 | sí |
| `pan_canny` | **30 ns** | 22 % | 0,32 | sí |
| `sobel_completo` | 20 ns | 15 % | 0,30 | sí |
| `canny1_completo` | 20 ns | 15 % | 0,20 | sí |
| `trans_completo` | 20 ns | 15 % | 0,20 | sí |
| `soc_sobel_completo` | **32 ns** | 15 % | 0,20 | sí |
| `soc_canny1_completo` | **36 ns** | 15 % | 0,20 | sí |
| `soc_trans_completo` | **36 ns** | 15 % | 0,20 | sí |

> **Veinte recetas, dieciséis circuitos.** La tabla tiene más filas que circuitos declara el
> Capítulo 7, y la diferencia merece explicarse. Los seis diseños terminados en `_completo` son una
> **segunda vía** hacia el mismo sistema: mientras los `vision_*` se obtuvieron **portando el diseño
> físicamente verificado en la FPGA**, los `_completo` se **ensamblaron a partir de los bloques
> reutilizables ya comprobados por separado** —front-end de cámara, filtro, controlador de pantalla—
> con un solo dominio de reloj en lugar de dos. Ambas vías se ejecutaron; sólo la primera se archivó
> con el expediente completo.
>
> De los seis, tres —`trans_completo`, `soc_canny1_completo` y `soc_trans_completo`— superaron las
> tres verificaciones de firma con cero observaciones, y otros dos conservan el GDSII, pero **ninguno
> reúne a la vez el GDSII y los tres informes** en el archivo curado. Por eso no se cuentan entre los
> dieciséis: el criterio para contar un circuito en este trabajo no es haberlo ejecutado, sino
> **poder mostrar el plano y las tres firmas juntos**. Se dejan en esta tabla porque sus recetas son
> parte de la evidencia del patrón que sigue, y porque omitirlos falsearía el recuento de intentos.

## D.3 El patrón que la tabla revela

Leída de arriba abajo, la tabla cuenta la historia del proyecto, y conviene señalarlo porque **ese
patrón es un resultado y no una casualidad**:

**La utilización desciende monótonamente con la complejidad del diseño**, del 40 % en los bloques de
interfaz al 15 % en los sistemas completos. No es una preferencia estética: es que un diseño con
mucha memoria en biestables y muchos cruces de dominio **no rutea** a densidad alta. La utilización
que cada diseño admite es, en sí misma, una medida indirecta de cuánta interconexión necesita.

**La tolerancia a congestión aparece exactamente donde aparece el framebuffer.** Todos los diseños
que la activan son los que almacenan un cuadro; ninguno de los que procesan en flujo la necesita. Es
la misma frontera que separa las dos familias en la §5.5 —por latencia— y en la §6.1 —por área—,
manifestada esta vez en el ruteo.

**El periodo sólo se relaja en los tres últimos.** Los tres llevan procesador *y* cadena completa, y
son los únicos a los que no se les pudo exigir 50 MHz. La §6.3 explica qué fija el reloj en cada
caso.

> Dicho de otro modo: **el mismo flujo, con el mismo kit y las mismas celdas, exige recetas cada vez
> más conservadoras a medida que el diseño almacena más estado.** El precio de la memoria no se
> manifiesta sólo en el resultado, sino también en el esfuerzo que cuesta obtenerlo.

## D.4 Sobre la elección de utilización

La utilización no es una restricción física sino un objetivo que el flujo intenta cumplir. Fijarla
baja produce un dado más grande con ruteo holgado; fijarla alta, uno más pequeño que puede no cerrar.

Durante el desarrollo se comprobó la relación de forma directa: un diseño cerrado al 18 % ocupa un
dado de 2,03 mm², mientras que el mismo diseño con una utilización del 35 % debería aproximarse a
1,20 mm². **La segunda cifra no está verificada**: el experimento quedó preparado y no llegó a
ejecutarse, y se anota aquí como tal para que no se lea como medida.

> La regla operativa que se siguió: **no se borra un resultado que cerró para intentar mejorarlo.**
> Un experimento de ajuste se lanza siempre con una etiqueta nueva, de modo que si el diseño apretado
> no cierra, el firmado anterior permanece intacto. Un circuito que cierra vale más que uno pequeño
> que no.
