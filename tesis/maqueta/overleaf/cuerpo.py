#!/usr/bin/env python3
"""cuerpo.py — extrae de tesis.tex SOLO lo que va entre \\begin{document} y
\\end{document}. Es lo unico que hay que llevar a la plantilla oficial de la
UNAL: su preambulo manda, y el de tesis.tex se descarta entero.

    python3 cuerpo.py tesis.tex cuerpo.tex
"""
import io, sys

src = sys.argv[1] if len(sys.argv) > 1 else "tesis.tex"
dst = sys.argv[2] if len(sys.argv) > 2 else "cuerpo.tex"
t = io.open(src, encoding="utf-8").read()

ini = t.find(r"\begin{document}")
fin = t.find(r"\end{document}")
if ini < 0 or fin < 0:
    sys.exit("!! no encuentro \\begin{document} / \\end{document} en " + src)
cuerpo = t[ini + len(r"\begin{document}"):fin].strip()

cab = (
    "% cuerpo.tex — generado por cuerpo.py, no editar a mano.\n"
    "%\n"
    "% Pegar DENTRO del \\begin{document} ... \\end{document} de la plantilla UNAL,\n"
    "% o dejarlo como fichero y llamarlo desde alli con:   \\input{cuerpo}\n"
    "%\n"
    "% EL PREAMBULO DE LA PLANTILLA MANDA: no copiar el de tesis.tex.\n"
    "% Si la plantilla numera capitulos por su cuenta, veras la numeracion\n"
    "% duplicada, porque aqui va escrita a mano en los titulos.\n\n")
io.open(dst, "w", encoding="utf-8").write(cab + cuerpo + "\n")
print(f"  cuerpo.tex · {len(cuerpo.split()):,} palabras · {cuerpo.count(chr(92)+'chapter{')} capitulos")
