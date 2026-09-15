#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""perfil.py — dónde se pierde el tiempo del camino crítico, etapa por etapa.

Compara, para CADA una de las 37 etapas, el retardo que el analizador estático
tomó de las tablas Liberty con el que SPICE obtiene resolviendo el transistor.
Si la discrepancia fuese uniforme apuntaría al modelo de celda; si se concentra
en unas pocas etapas, apunta a los parásitos de esas nets concretas.
"""
import re, subprocess, sys
import numpy as np
import gen_camino as G

RPT = "/Users/vic/utm-share/asic_pan_sobel/results_final/signoff/31-rcx_sta.max.rpt"
cam, _ = G.leer_camino(RPT, 0)
sub = G.leer_subckts(G.PDK)
inf = G.generar(cam, sub, "perfil.spice", RPT, con_cap=True, slew_real=True)
subprocess.run(["ngspice", "-b", "perfil.spice"], capture_output=True, text=True)

# ngspice escribe pares (tiempo, valor) por columna
d = np.loadtxt("perfil.dat")
t = d[:, 0] * 1e9
V = [d[:, 2 * i + 1] for i in range((d.shape[1]) // 2)]
VDD = 1.8

def cruce(v):
    """primer instante en que el nodo pasa por VDD/2"""
    s = np.sign(v - VDD / 2)
    k = np.nonzero(np.diff(s))[0]
    if not len(k):
        return None
    i = k[0]
    a, b = v[i] - VDD / 2, v[i + 1] - VDD / 2
    return t[i] + (t[i + 1] - t[i]) * (-a) / (b - a)

tc = [cruce(v) for v in V]
et = cam["etapas"][1:]
print("%-4s %-13s %-9s %7s %7s %8s %6s %5s" %
      ("#", "celda", "instancia", "STA", "SPICE", "delta", "cap", "fo"))
sta_a = spi_a = 0.0
filas = []
for k, f in enumerate(et):
    if tc[k] is None or tc[k + 1] is None:
        continue
    ds = f["d"]; dp = tc[k + 1] - tc[k]
    sta_a += ds; spi_a += dp
    filas.append((k, f["tipo"], f["inst"], ds, dp, ds - dp, f["cap"], f["fo"]))
    print("%-4d %-13s %-9s %7.3f %7.3f %8.3f %6.3f %5d"
          % (k, f["tipo"], f["inst"], ds, dp, ds - dp, f["cap"], f["fo"]))
print("%-4s %-13s %-9s %7.3f %7.3f %8.3f" % ("", "TOTAL", "", sta_a, spi_a, sta_a - spi_a))

dif = np.array([r[5] for r in filas])
cap = np.array([r[6] for r in filas]); fo = np.array([r[7] for r in filas])
print("\n--- ¿uniforme o concentrada? ---")
print("  diferencia por etapa: media %.3f ns · mediana %.3f · desv %.3f"
      % (dif.mean(), np.median(dif), dif.std()))
o = np.argsort(dif)[::-1]
print("  las 5 etapas que más se desvían:")
for i in o[:5]:
    r = filas[i]
    print("    %-13s %-9s STA %.3f  SPICE %.3f  delta %+.3f  cap %.3f pF  fanout %d"
          % (r[1], r[2], r[3], r[4], r[5], r[6], r[7]))
print("  las 5 que MENOS: %s" % ", ".join("%+.3f" % dif[i] for i in o[-5:]))
print("\n  correlación delta–capacitancia  r = %+.3f" % np.corrcoef(dif, cap)[0, 1])
print("  correlación delta–fanout        r = %+.3f" % np.corrcoef(dif, fo)[0, 1])
top5 = dif[o[:5]].sum()
print("\n  las 5 peores etapas acumulan %.3f ns de los %.3f de diferencia (%.0f %%)"
      % (top5, dif.sum(), 100 * top5 / dif.sum()))
