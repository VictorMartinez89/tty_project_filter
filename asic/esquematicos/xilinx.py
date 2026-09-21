#!/usr/bin/env python3
"""xilinx.py — reviste un SVG de netlistsvg con la paleta del RTL Viewer de Xilinx ISE.

El lenguaje visual de esas capturas es muy concreto y conviene respetarlo:
  · fondo NEGRO
  · marco exterior CIAN con el nombre del bloque arriba y abajo
  · cajas de modulo con borde VERDE y relleno negro
  · el "cobre" -las nets- en ROJO
  · etiquetas de pin en verde, pequenas y monoespaciadas
"""
import re, sys, os

NEGRO, VERDE, ROJO, CIAN = "#000000", "#00C853", "#FF1F1F", "#00E5FF"

CSS = """svg { stroke:%s; fill:none; }
text { fill:%s; stroke:none; font-size:9px; font-weight:500;
       font-family:"JetBrains Mono","Courier New",monospace; }
.nodelabel { text-anchor:middle; fill:%s; font-size:9.5px; }
.inputPortLabel { text-anchor:end; fill:%s; }
.outputPortLabel { text-anchor:start; fill:%s; }
.splitjoinBody { fill:%s; stroke:%s; }
circle, polygon, path, line { stroke:%s; }
""" % (ROJO, VERDE, VERDE, VERDE, VERDE, ROJO, ROJO, ROJO)

# yosys renombra los modulos con parametros a `$paramod$<sha1>\\nombre`; en un
# esquematico eso es ruido. Se recupera el nombre legible.
PARAMOD = re.compile(r'\$paramod\$?[0-9a-f]*\\?([A-Za-z_][A-Za-z0-9_]*)')

def revestir(src, dst, titulo):
    s = open(src).read()
    # OJO: hay que leer el width/height de la ETIQUETA RAIZ. Buscandolos en todo el
    # fichero, en canny1_top la regex cazaba los de un <rect> interno y el marco salia
    # de 82x136 con el dibujo entero desbordado fuera.
    raiz = s[:s.index('>', s.index('<svg')) + 1]
    mw = re.search(r'\bwidth="(\d+)"', raiz)
    mh = re.search(r'\bheight="(\d+)"', raiz)
    w, h = (int(mw.group(1)) if mw else 1200), (int(mh.group(1)) if mh else 900)
    MG, CAB = 26, 22                      # margen del marco y alto de la cabecera
    W, H = w + 2*MG, h + 2*MG + 2*CAB

    s = re.sub(r'<style>.*?</style>', '<style>%s</style>' % CSS, s, flags=re.S)
    s = re.sub(r'^<svg[^>]*>', '', s).rsplit('</svg>', 1)[0]
    # las cajas de celda: borde verde. netlistsvg las emite sin clase, se pintan por forma.
    # las cajas en verde: el atributo gana porque el CSS ya no toca `rect`
    s = s.replace('<rect', '<rect stroke="%s"' % VERDE)
    s = PARAMOD.sub(r'\1', s)                     # $paramod$a1b2\linebuf3x3 -> linebuf3x3
    s = s.replace('\\', '')

    esc = titulo.replace("&", "&amp;").replace("<", "&lt;")
    out = ['<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"',
           ' xmlns:s="https://github.com/nturley/netlistsvg" viewBox="0 0 %d %d"' % (W, H),
           ' width="%d" height="%d">' % (W, H),
           '<rect x="0" y="0" width="%d" height="%d" fill="%s" stroke="none"/>' % (W, H, NEGRO),
           # marco exterior cian, como el de las capturas de ISE
           '<rect x="8" y="8" width="%d" height="%d" fill="none" stroke="%s" stroke-width="1.6"/>'
           % (W-16, H-16, CIAN),
           '<text x="%d" y="26" text-anchor="middle" fill="%s" font-size="11.5"'
           ' font-family="JetBrains Mono,Courier New,monospace">%s</text>' % (W//2, CIAN, esc),
           '<text x="%d" y="%d" text-anchor="middle" fill="%s" font-size="11.5"'
           ' font-family="JetBrains Mono,Courier New,monospace">%s</text>' % (W//2, H-12, CIAN, esc),
           '<g transform="translate(%d,%d)">' % (MG, MG + CAB), s, '</g></svg>']
    open(dst, "w").write("\n".join(out))
    return W, H

if __name__ == "__main__":
    print(revestir(sys.argv[1], sys.argv[2], sys.argv[3]))
