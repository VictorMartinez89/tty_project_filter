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
