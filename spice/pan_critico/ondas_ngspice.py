#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ondas_ngspice.py — las ondas del camino crítico dibujadas POR NGSPICE.

No usa matplotlib: el gráfico lo produce el propio simulador con `hardcopy`, que
es el plotter nativo de ngspice.  Se emite en SVG y se convierte a PNG para el
cuaderno.  Diez trazas de las ~37 del camino, escalonadas 2 V para que no se
solapen: se ve el frente de onda descender de una etapa a la siguiente.
"""
import os, re, subprocess
import gen_camino as G

CH = {"pan_sobel": "/Users/vic/utm-share/asic_pan_sobel/results_final/signoff/31-rcx_sta.max.rpt",
      "pan_canny": "/Users/vic/utm-share/asic_pan_canny/results_final/signoff/31-rcx_sta.max.rpt"}
SALTO = 2.0          # voltios de separación entre trazas
N_TRAZAS = 10

sub = G.leer_subckts(G.PDK)
for nom, rpt in CH.items():
    cam, _ = G.leer_camino(rpt, 0)
    f = "%s_hc.spice" % nom
    inf = G.generar(cam, sub, f, rpt, con_cap=True, slew_real=True)
    n = inf["n"]
    sel = [round(i * n / (N_TRAZAS - 1)) for i in range(N_TRAZAS)]
    sel = sorted(set(min(s, n) for s in sel))
    # v(nXXX) + desplazamiento, para escalonarlas
    tr = " ".join("v(n%03d)+%g" % (k, (len(sel) - 1 - i) * SALTO)
                  for i, k in enumerate(sel))
    s = open(f).read()
    s = s.replace('wrdata perfil.dat', '* (el volcado de texto no hace falta aquí)\n*wrdata perfil.dat')
    s = s.replace(".endc",
                  "set hcopydevtype = svg\n"
                  "set hcopypscolor = 1\n"
                  "set nolegend = 0\n"
                  'hardcopy %s_ng.svg %s\n'
                  '  + xlabel tiempo ylabel voltios\n'
                  '  + title %s_camino_critico_%d_etapas_ngspice_sky130\n'
                  ".endc" % (nom, tr, nom, n))
    open(f, "w").write(s)
    r = subprocess.run(["ngspice", "-b", f], capture_output=True, text=True)
    ok = os.path.exists("%s_ng.svg" % nom)
    print("%s: %d etapas · trazas en %s · SVG %s"
          % (nom, n, sel, "OK" if ok else "NO -> " + r.stdout[-200:]))
