# Integración en la plantilla oficial de la UNAL

    python3 tesis/maqueta/unal/integrar.py [ruta_de_la_plantilla]
    python3 tesis/maqueta/unal/a_bibtex.py tesis/bibliografia.md <plantilla>/Referencias.bib

Por omisión la plantilla se busca en
`~/UN/Tesis_Final_1/Plantilla_Tesis_Trabajo_Final_UNAL_2023`.

## Por qué no se usa `\input{cuerpo}`

**La plantilla ya trae un fichero por capítulo.** Lo natural es llenarlos, no meter un bloque
monolítico. El reparto:

| plantilla | contenido |
|---|---|
| `01Seccion01.tex` … `07Seccion07.tex` | los capítulos 1 a 7 |
| `05Seccion05.tex` | los **siete** ficheros del capítulo 5, fundidos y degradados un nivel |
| `08Apendice01.tex` | los cuatro anexos |
| `00ResumenAbstract.tex` | el resumen y el abstract |
| `00Figuras/` | las once figuras |
| `Referencias.bib` | las 47 entradas |

`0000.tex` **no se toca** salvo para comentar el andamiaje: `00Intrucciones`, `00Abreviaturas`,
`00HipotesisPlanteamiento` y `00Objetivos`, porque el planteamiento y los objetivos van en el
capítulo 1. Cada fichero sobrescrito deja un `.bak` la primera vez.

## Quién numera

**LaTeX.** El guion **quita los números escritos a mano** de los títulos («## 5.6.1 Arquitectura» →
«Arquitectura») y deja que la plantilla numere. Las referencias cruzadas del texto —«la §5.7», «la
§4.8»— siguen siendo válidas porque el orden se conserva.

## El estilo de citación, resuelto

La plantilla usa **`natbib` con `dtvstyle.bst`, que es autor-año**, no IEEE numérico. Las citas del
documento ya estaban escritas en ese formato, así que el guion las convierte de `[Mead y Conway
1980]` a `\citep{Mead1980}` — dieciséis en total, ninguna suelta.

## Lo que hay que revisar a mano

**`Referencias.bib` es una conversión aproximada.** Todas las entradas salen como `@misc` con autor,
título, año y nota. Para las que son artículo o libro conviene cambiar el tipo a `@article` o `@book`
y separar revista, volumen y páginas, que ahora quedan dentro del título o de la nota. Las claves sí
son limpias: `Mead1980`, `Canny1986`, `Vincent1993`, `Lazebnik2006`…
