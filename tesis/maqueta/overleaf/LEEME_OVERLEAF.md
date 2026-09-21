# Llevar la tesis a Overleaf

## No importes el repositorio

Overleaf falla con *«tu repositorio de GitHub contiene archivos que superan el límite de 50 MB»*, y
tiene razón: el repositorio pesa **16 GB**, de los cuales 8,8 GB son 293 copias de seguridad del
cuaderno y 4,3 GB el historial de git. Nueve ficheros pasan de 50 MB, y el historial conserva otros
que ya se borraron —así que **purgar el árbol de trabajo no arreglaría la importación**.

**La tesis son 796 KB.** Overleaf no necesita ni uno de esos 16 GB.

## Lo que sí hay que hacer: subir un zip

    bash tesis/maqueta/armar.sh          # regenera tesis.md
    bash tesis/maqueta/overleaf/armar_zip.sh

Sale `tesis_overleaf.zip`. En Overleaf: **New Project → Upload Project** y se arrastra el zip.
Compila ahí mismo, que es lo que este Mac no puede hacer por no tener LaTeX.

## Por qué Overleaf resuelve los dos problemas pendientes

| Problema | Cómo lo resuelve |
|---|---|
| No hay LaTeX en el Mac, luego no hay PDF | Overleaf compila en su servidor |
| La plantilla de la Facultad no está en la máquina | Overleaf tiene plantillas de la Universidad Nacional en su galería |

## Cómo trabajar con la plantilla oficial

**La plantilla es el proyecto; este zip es sólo el contenido.** El orden correcto es abrir la
plantilla y meterle el contenido, nunca al revés.

> **Plantilla Tesis Trabajo Final UNAL 2023** — la mantiene la Dirección Nacional de Bibliotecas,
> cubre explícitamente Magíster, y trae márgenes, estilos y páginas de declaración oficiales.
> `overleaf.com/latex/templates/plantilla-tesis-trabajo-final-unal-2023/dpzjnmzwmmrg`

1. Abrir ese enlace y pulsar **Open as Template**. Eso crea *tu* proyecto con el formato ya puesto.
2. Descomprimir este zip y **arrastrar la carpeta `figuras/`** al panel de ficheros del proyecto.
3. Arrastrar también **`cuerpo.tex`**, que es el texto sin preámbulo. En el fichero principal de la
   plantilla, donde ésta pone el contenido de los capítulos, escribir una línea:

       \input{cuerpo}

   Y nada más. Si se prefiere no usar `\input`, se abre `cuerpo.tex` y se pega su contenido ahí
   mismo: es exactamente lo que va entre `\begin{document}` y `\end{document}`.

**Nunca se copia el preámbulo de `tesis.tex`.** El de la plantilla manda, y mezclarlos rompe el
formato oficial, que es justamente lo que se quería conservar.

### Dos cosas que hay que ajustar a mano

**La numeración.** Los números de capítulo y sección van **escritos dentro de los títulos**
(«5.2 Resultados en FPGA»), y el preámbulo generado desactiva la de LaTeX con
`\setcounter{secnumdepth}{-\maxdimen}`. Al usar la plantilla ese preámbulo se descarta, así que
**la plantilla numerará por su cuenta** y se verá «Capítulo 5 · 5.2 Resultados…». Se arregla de una
de dos formas, y conviene decidirlo antes de empezar:

- **dejar que numere LaTeX** —lo ortodoxo— borrando los números de los títulos de `cuerpo.tex`, o
- **conservar los manuales** añadiendo esa línea `\setcounter` al preámbulo de la plantilla.

**La tipografía.** Si se quiere la fuente oficial **Ancizar Sans**, hay que cambiar el compilador a
**XeLaTeX** o **LuaLaTeX** en *Menu → Compiler*. Con pdfLaTeX compila igual, pero con fuentes
estándar.

## Si algo no compila

Lo más probable son los acentos o las tablas anchas. El `.tex` se genera con `pandoc`, que usa
`\toprule`/`\midrule` (paquete **booktabs**) y `\passthrough` para el código en línea; los dos
vienen en el preámbulo generado y hay que asegurarse de que la plantilla también los carga.
