#!/usr/bin/env python3
"""bloques.py — diagramas de bloques del camino de datos, en la paleta de Xilinx ISE.

Los cuatro disenos de esta familia son MONOLITICOS: toda la logica vive en el modulo
top, sin submodulos que agrupar. Por eso su esquematico RTL automatico sale de 41 000 px
de ancho y es ilegible. Estos diagramas son DIBUJO DELIBERADO, no salida de yosys, y el
pie de figura debe decirlo.

Las etapas y los pines NO son de memoria: se extrajeron del RTL (puertos del `module`,
`always @(posedge ...)` para los dominios, e instancias para las cajas con nombre).
"""
NEGRO, VERDE, ROJO, CIAN, AMBAR = "#000000", "#00C853", "#FF1F1F", "#00E5FF", "#FFB300"
F = 'font-family="JetBrains Mono,Courier New,monospace"'

def svg(nom, titulo, entradas, salidas, etapas, notas, W=1380, H=520):
    o = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}"'
         f' role="img" aria-label="Diagrama de bloques de {nom}">',
         f'<rect width="{W}" height="{H}" fill="{NEGRO}"/>',
         f'<rect x="8" y="8" width="{W-16}" height="{H-16}" fill="none" stroke="{CIAN}" stroke-width="1.6"/>',
         f'<text x="{W//2}" y="26" text-anchor="middle" fill="{CIAN}" font-size="12" {F}>{titulo}</text>',
         f'<text x="{W//2}" y="{H-12}" text-anchor="middle" fill="{CIAN}" font-size="12" {F}>{titulo}</text>']

    # --- pines de entrada, a la izquierda: triangulo + etiqueta, como en ISE ---
    y0, dy = 66, 26
    for i, (p, dom) in enumerate(entradas):
        y = y0 + i*dy
        col = AMBAR if dom == "pclk" else VERDE
        o.append(f'<polygon points="106,{y-6} 120,{y} 106,{y+6}" fill="none" stroke="{col}" stroke-width="1.3"/>')
        o.append(f'<text x="102" y="{y+3.5}" text-anchor="end" fill="{col}" font-size="10" {F}>{p}</text>')
        o.append(f'<line x1="120" y1="{y}" x2="196" y2="{y}" stroke="{ROJO}" stroke-width="1.2"/>')
    for i, (p, dom) in enumerate(salidas):
        y = y0 + i*dy
        col = AMBAR if dom == "pclk" else VERDE
        o.append(f'<polygon points="{W-120},{y-6} {W-106},{y} {W-120},{y+6}" fill="none" stroke="{col}" stroke-width="1.3"/>')
        o.append(f'<text x="{W-102}" y="{y+3.5}" fill="{col}" font-size="10" {F}>{p}</text>')
        o.append(f'<line x1="{W-150}" y1="{y}" x2="{W-120}" y2="{y}" stroke="{ROJO}" stroke-width="1.2"/>')

    # --- las cajas del camino de datos ---
    for (x, y, w, h, tit, sub, dom, marco) in etapas:
        col = AMBAR if dom == "pclk" else (CIAN if marco else VERDE)
        gw = 2 if marco else 1.4
        o.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="none" stroke="{col}" stroke-width="{gw}"/>')
        o.append(f'<text x="{x+w/2}" y="{y+h/2-2}" text-anchor="middle" fill="{col}" font-size="11" {F}>{tit}</text>')
        if sub:
            o.append(f'<text x="{x+w/2}" y="{y+h/2+13}" text-anchor="middle" fill="{col}" font-size="9" opacity=".8" {F}>{sub}</text>')

    for (x1, y1, x2, y2, et) in notas:
        o.append(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{ROJO}" stroke-width="1.3"/>')
        o.append(f'<polygon points="{x2-7},{y2-4} {x2},{y2} {x2-7},{y2+4}" fill="{ROJO}"/>')
        if et:
            o.append(f'<text x="{(x1+x2)/2}" y="{y1-6}" text-anchor="middle" fill="{ROJO}" font-size="9" opacity=".9" {F}>{et}</text>')
    o.append('</svg>')
    open(nom, "w").write("\n".join(o))
    return nom
