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

## Control de versiones de la plantilla

La carpeta de la plantilla **no vive en este repositorio** —es material de la Facultad con tu texto
volcado dentro— así que lleva su **propio git local**, creado el 21-sep-2026:

    cd ~/UN/Tesis_Final_1/Plantilla_Tesis_Trabajo_Final_UNAL_2023
    git log --oneline

Su `.gitignore` descarta los subproductos de LaTeX (`*.aux`, `*.log`, `*.toc`…) y los `.bak` que
deja `integrar.py`. **Commitear ahí antes de cada tanda de cambios en Overleaf.**

### La regla que evita que las dos copias se separen

| qué cambias | dónde lo cambias |
|---|---|
| **contenido** (texto, cifras, figuras) | los `.md` de este repositorio, y luego `integrar.py` |
| **formato** (márgenes, estilos, portada) | la plantilla, en Overleaf o en local |

Si editas texto en los dos sitios, se separan y **no hay forma automática de volver a juntarlos**.

### Sincronizar con Overleaf

⚠️ **El git de Overleaf es función de pago.** Antes de nada, comprobar en
`overleaf.com/user/subscription` si la Universidad Nacional da acceso institucional con el correo
`@unal.edu.co`; muchas universidades lo tienen.

**Con acceso.** Generar un testigo en *Account Settings → Git integration → Generate token* y
clonar el proyecto **en una carpeta aparte**, no sobre ésta:

    git clone https://git.overleaf.com/6ab189a4bc63f7b23d543ddf ~/UN/Tesis_Final_1/overleaf
    # usuario: git   ·   contraseña: el testigo

Después se copian los ficheros de la plantilla local a esa carpeta, se commitea y se empuja. Así el
historial de Overleaf queda limpio y no hay que fusionar dos historias sin antepasado común, que es
donde esto suele romperse.

**Sin acceso.** El camino manual funciona igual de bien para lo que hace falta:

- **subir:** en Overleaf, *Menu → Upload* o arrastrar los ficheros cambiados;
- **bajar:** *Menu → Download → Source*, descomprimir sobre la carpeta local y `git commit`.

Lo importante no es el mecanismo sino **commitear en local antes y después de cada tanda**, que es lo
que da a dónde volver.
