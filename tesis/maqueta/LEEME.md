# Maquetación

Junta los `tesis/*.md` en un solo documento y lo pasa por pandoc.

    bash tesis/maqueta/armar.sh

Deja en `salida/` (no versionado, se regenera): `tesis.md`, `tesis.docx`, `tesis.html`.

## Qué hace el guion, y por qué

**No toca los `.md` de `tesis/`.** Cada capítulo funciona como fichero suelto y así se queda.

El **capítulo 5 vive en seis ficheros** que usan `#` para lo que son *secciones* y no llevan
encabezado de capítulo. El guion les antepone `# 5. Resultados` y **degrada sus encabezados un
nivel** al vuelo. Lo mismo con los cuatro anexos, bajo un `# Anexos` común.

El orden es: portada y resumen → capítulos 1 a 7 → anexos A–D → bibliografía.

## Estado de la salida (21-sep-2026)

| | |
|---|---|
| Palabras | 26 867 |
| Capítulos (nivel 1) | 11 |
| Secciones · subsecciones | 64 · 65 |
| Tablas | 38 |
| Ecuaciones convertidas a Word | 9 |
| TeX sin convertir | **0** |
| **Figuras** | **0** ← ver abajo |

## Lo que falta

**Figuras: no hay ninguna.** Es la carencia real del documento. El material existe:

- `asic/esquematicos/*.svg` — siete esquemáticos RTL
- `spice/pan_critico/fig_spice_critico.py` — la figura de la §33 (camino crítico)
- `asic/balance/fig_sobel_vs_canny.py` — la figura del balance Sobel/Canny
- los dos cuadernos — fotos de *layout*, ondas de GTKWave, fotos de la pantalla

Para incrustarlas hace falta convertir los SVG a PNG, que **sí se puede en este Mac**:

    cairosvg asic/esquematicos/sobel_top_x.svg -o fig/sobel.png -s 2

**PDF: no se puede aquí.** No hay LaTeX instalado. Dos caminos:

- abrir el `.docx` en Word o LibreOffice y aplicar la plantilla de la Facultad — **es el camino
  recomendado**, porque la plantilla oficial no está en esta máquina y hay que conseguirla;
- o instalar BasicTeX y añadir `-o tesis.pdf --pdf-engine=xelatex` al guion.

## Figuras: el catálogo y la selección

`figuras/catalogar.py` recorre los dos cuadernos y lista **las 263 imágenes** que contienen —197 en
el primero, 66 en el segundo, 35,5 MB— con su sección, tipo, dimensiones y peso, en
`figuras/catalogo_figuras.tsv`.

`figuras/seleccion.tsv` elige dieciséis, repartidas por capítulo, y `figuras/extraer.py` las saca a
fichero. Pesan 4,6 MB en total.

### Dos advertencias que salieron al examinarlas

**La figura del balance Sobel/Canny contradice el texto.** `asic/balance/fig_sobel_vs_canny.py`
—y su PNG— traen las cifras anteriores al 21 de septiembre: «+121 % a +3 %», «655 contra 5 255
celdas» y «ocho veces más barato». El capítulo 6 dice ahora 123 % a 5 %, 972 contra 6 220 y «unas
seis veces», porque el recuento se homogeneizó a celdas emplazadas. **Hay que regenerar el `.py`
antes de incrustar esa figura**, o quedará desmintiendo al texto que acompaña.

**Y una etiqueta que engañaba.** La figura de los siete *layouts* no muestra siete de los dieciséis
circuitos de la tesis: son **los siete proyectos de Tiny Tapeout**, que es otro conjunto. Renombrada
a `fig_5_6_siete_chips_tinytapeout` para que no se use en el sitio equivocado.

### Las ocho insertadas, y las que se apartaron

Están en `tesis/figuras/` y el texto las referencia con ruta relativa, de modo que el `.docx`, el
`.html` y el paquete de Overleaf las incrustan solos.

| figura | dónde | qué muestra |
|---|---|---|
| 5.1 | §5.2.2 | el Sobel en vivo sobre seis escenas, fotografiado de la pantalla |
| 5.2 | §5.3.2 | acercamiento al GDSII del `canny1` en KLayout |
| 5.3 | §5.4.2 | el mismo acercamiento sobre el sistema de visión completo |
| 5.4 | §5.6.3 | el espacio de diseño del clasificador: precisión de peso contra número de zonas |
| 5.5 | §5.6.5 | la ventana de 28×28 entrando al extractor, en el simulador |
| 5.6 | §5.6.6 | la cadena completa en señales, con el procesador escribiendo el umbral |
| 5.7 | §5.6.6 | la tarjeta durante el ensayo de los diez dígitos grabados |
| 6.1 | §6.6 | el balance Sobel/Canny sobre seis parejas |

**Tres se apartaron, y conviene decir por qué:**

- **El barrido de degradación** (cuaderno 2, celda 10) muestra al Canny superando al Sobel por hasta
  17,3 puntos bajo iluminación despareja. **Es exactamente la afirmación que la §7.3 declara
  retractada**, porque comparaba dos puntos de operación y no dos filtros. Incluirla sin un marco muy
  explícito contradiría al propio documento.
- **Los nueve chips de Tiny Tapeout** (cuaderno 1, celda 510) ilustran algo que **la tesis no
  cuenta**: que existen nueve proyectos propios enviados. Hoy el documento sólo menciona Tiny Tapeout
  al hablar del trabajo de otros. O se añade el apartado, o la figura no tiene dónde ir. *(Y su
  título dice «siete»: son nueve, contando los dos de MNIST en IHP.)*
- **Las dos de la verificación eléctrica en SPICE** (celdas 118 y 121) no tienen sección donde
  entrar: **el Capítulo 5 no dedica ningún apartado al trabajo de la §33**, que sólo aparece
  mencionado en los capítulos 3, 6 y 7. Es un hueco del documento, no de las figuras.
