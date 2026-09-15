#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""correr.py — mide el camino crítico en SPICE y aísla de dónde sale cada
nanosegundo de diferencia con el analizador estático de tiempos.

Tres variantes del MISMO camino:
  A  cadena desnuda, flanco ideal      -> sólo las puertas
  B  + la capacitancia post-extracción -> + la carga de cable y fanout
  C  + el flanco real de entrada       -> + la degradación del frente de onda
"""
import os, re, subprocess, sys
import gen_camino as G

RPT = sys.argv[1] if len(sys.argv) > 1 else \
    "/Users/vic/utm-share/asic_pan_sobel/results_final/signoff/31-rcx_sta.max.rpt"
NOM = sys.argv[2] if len(sys.argv) > 2 else "pan_sobel"
CUAL = int(sys.argv[3]) if len(sys.argv) > 3 else 0

cam, ncam = G.leer_camino(RPT, CUAL)
sub = G.leer_subckts(G.PDK)

VAR = [("A  puertas solas",              dict(con_cap=False, slew_real=False)),
       ("B  + capacitancia extraída",    dict(con_cap=True,  slew_real=False)),
       ("C  + flanco real de entrada",   dict(con_cap=True,  slew_real=True))]

print("camino de %s: %s -> %d etapas" % (NOM, cam["arranque"], len(cam["etapas"]) - 1))
res = {}
for et, kw in VAR:
    f = "%s_%s.spice" % (NOM, et.split()[0])
    inf = G.generar(cam, sub, f, RPT, **kw)
    out = subprocess.run(["ngspice", "-b", f], capture_output=True, text=True).stdout
    m = re.search(r"^retardo\s+=\s+(\S+)", out, re.M)
    r = float(m.group(1)) * 1e9 if m and "fail" not in m.group(1) else None
    res[et] = r
    print("  %-30s %s" % (et, ("%.3f ns" % r) if r else "NO CONMUTA (sensibilización mal)"))

sta_tot = cam["retardo"]; sta_log = sta_tot - inf["clkq"]
print("\n  el STA, para la misma lógica       %.3f ns" % sta_log)
print("  (+ %.3f ns de reloj a dato del biestable = %.3f ns de camino completo)"
      % (inf["clkq"], sta_tot))
ok = [v for v in res.values() if v]
if len(ok) == 3:
    a, b, c = ok
    print("\n  desglose de los %.3f ns que predice el STA:" % sta_log)
    print("    puertas                    %6.3f ns   %4.1f %%" % (a, 100*a/sta_log))
    print("    carga de cable y fanout    %6.3f ns   %4.1f %%" % (b-a, 100*(b-a)/sta_log))
    print("    flanco de entrada          %6.3f ns   %4.1f %%" % (c-b, 100*(c-b)/sta_log))
    print("    ─────────────────────────────────────────────")
    print("    SPICE explica              %6.3f ns   %4.1f %%" % (c, 100*c/sta_log))
    print("    sin explicar (R del cable) %6.3f ns   %4.1f %%" % (sta_log-c, 100*(sta_log-c)/sta_log))
