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

## Cómo aplicar la plantilla de la Facultad

1. Buscar la plantilla en la galería de Overleaf, o pedirla en la Facultad.
2. Crear el proyecto **desde la plantilla**, no desde el zip.
3. Copiar el **cuerpo** de `tesis.tex` —lo que va entre `\begin{document}` y `\end{document}`—
   dentro del documento de la plantilla. **No se copia el preámbulo**: el de la plantilla manda.
4. La numeración de capítulos y secciones va **escrita a mano en los títulos** («5.2 Resultados en
   FPGA») y el preámbulo generado desactiva la de LaTeX con
   `\setcounter{secnumdepth}{-\maxdimen}`. Si la plantilla numera por su cuenta, hay que elegir:
   o se quita esa línea y se borran los números de los títulos, o se conserva tal cual.

## Si algo no compila

Lo más probable son los acentos o las tablas anchas. El `.tex` se genera con `pandoc`, que usa
`\toprule`/`\midrule` (paquete **booktabs**) y `\passthrough` para el código en línea; los dos
vienen en el preámbulo generado y hay que asegurarse de que la plantilla también los carga.
