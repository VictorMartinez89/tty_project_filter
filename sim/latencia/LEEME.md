# Medición de latencia (§5.5 de la tesis)

Separa las dos magnitudes que el documento llamaba «latencia» y que difieren en un factor treinta.

- **Latencia de cauce** — primer `in_valid` → primer `out_valid`. Profundidad de la cadena de
  validez. El generador de ventana 3×3 **no espera a que se llenen sus líneas de retardo**, así que
  estas primeras salidas son válidas según la señal pero se calculan sobre el contenido inicial.
- **Primer píxel utilizable** — último ciclo cuya salida aún depende de ese contenido. No se estima
  con ninguna fórmula: las memorias arrancan sin inicializar y se busca la última salida indefinida.

## Cómo correrlo

Necesita `sobel_top.v`, `canny1_top.v` y `linebuf3x3.v` **con `W=60`** (los de
`comparativa_36x26/src/` vienen a `W=26`; basta `sed 's/\.W(26)/.W(60)/g'`).

    iverilog -g2012 -o lat.vvp -s tb_latencia_final \
        tb_latencia_final.v sobel_top.v canny1_top.v linebuf3x3.v
    vvp lat.vvp

## Resultado (21-sep-2026, imagen 60×80)

| filtro | etapas | cauce | primer píxel utilizable |
|---|---:|---:|---:|
| Sobel | 1 | 4 ciclos | **125** |
| Canny de un salto | 3 | 8 ciclos | **313** |

El Sobel da exactamente `2·(W+2) = 124` más uno. **El Canny no da el triple** —`6·(W+2)` serían
372— porque las tres etapas se llenan **solapadas**: cada una empieza a recibir datos en cuanto la
anterior empieza a producirlos. La tabla de la §5.5.4 usaba la fórmula y sobrestimaba un 20 %.
