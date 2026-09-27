#!/usr/bin/env python3
"""listado_verilog.py — prepara un fichero Verilog para imprimirlo en el Anexo G sin salirse de la
pagina (97 caracteres en \\small). No cambia el circuito: en Verilog un salto de linea es un espacio.
  - comentario de linea demasiado largo  -> se parte en varias lineas de comentario
  - codigo + comentario final demasiado largo -> el comentario sube a la linea anterior
  - codigo demasiado largo -> se parte entre dos sentencias ('; ') o dos argumentos (', ') o, en una suma, antes de un '+'"""
import textwrap
MAX = 97
def _partir_codigo(linea):
    ind = linea[:len(linea) - len(linea.lstrip())]; out = []; resto = linea
    while len(resto) > MAX:
        corte = resto.rfind("; ", 0, MAX - 2)
        sep = 1
        if corte < len(ind) + 8: corte = resto.rfind(", ", 0, MAX - 2)
        if corte < len(ind) + 8: corte, sep = resto.rfind(" + ", 0, MAX - 2), 0   # en una suma larga
        if corte < len(ind) + 8: corte, sep = resto.rfind(" : ", 0, MAX - 2), 0   # en un ?: encadenado
        assert corte > len(ind) + 8, "no se puede partir: " + linea
        out.append(resto[:corte + sep].rstrip()); resto = ind + "    " + resto[corte + 1:].lstrip()
    return out + [resto]
def listado(ruta):
    out = []
    for l in open(ruta).read().rstrip("\n").split("\n"):
        l = l.rstrip(); ind = l[:len(l) - len(l.lstrip())]
        if len(l) <= MAX and not (len(l) > 88 and l.lstrip().startswith("//")):
            out.append(l); continue
        if l.lstrip().startswith("//"):
            txt = l.lstrip()[2:].strip()
            for k, t in enumerate(textwrap.wrap(txt, 84 - len(ind))):
                out.append(f"{ind}// {t}" if k == 0 else f"{ind}//   {t}")
            continue
        i = l.find("//")
        if i > 0 and '"' not in l[:i]:
            codigo, com = l[:i].rstrip(), l[i + 2:].strip()
            for t in textwrap.wrap(com, 84 - len(ind)): out.append(f"{ind}// {t}")
            out.extend(_partir_codigo(codigo) if len(codigo) > MAX else [codigo])
        else:
            out.extend(_partir_codigo(l))
    assert all(len(x) <= MAX for x in out)
    return "\n".join(out)
