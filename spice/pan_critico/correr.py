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
import spef as S

PEX = None
if "--pex" in sys.argv:
    i = sys.argv.index("--pex"); PEX = sys.argv[i + 1]; del sys.argv[i:i + 2]

RPT = sys.argv[1] if len(sys.argv) > 1 else \
    "/Users/vic/utm-share/asic_pan_sobel/results_final/signoff/31-rcx_sta.max.rpt"
NOM = sys.argv[2] if len(sys.argv) > 2 else "pan_sobel"
CUAL = int(sys.argv[3]) if len(sys.argv) > 3 else 0

SPEF = sys.argv[4] if len(sys.argv) > 4 else \
    os.path.expanduser("~/ASIC_planos/%s/%s.spef" % (NOM, NOM))

cam, ncam = G.leer_camino(RPT, CUAL)
sub = G.leer_subckts(G.PDK)          # el esquematico, para las variantes A..D

# y, si se pide, el netlist EXTRAIDO del layout: una celda por fichero
sub_pex, inc = {}, {}
if PEX:
    for f in sorted(os.listdir(PEX)):
        if f.endswith(".spice"):
            ruta = os.path.join(PEX, f)
            for cel, pines in G.leer_subckts(ruta).items():
                sub_pex[cel], inc[cel] = pines, ruta
    falta = {e["tipo"] for e in cam["etapas"][1:]} - set(sub_pex)
    print("netlists EXTRAIDOS: %d celdas%s"
          % (len(sub_pex), ("  · FALTAN %s" % sorted(falta)) if falta else ""))

# la variante D necesita el SPEF: R y C de cada tramo de cable, que es lo que el
# STA leyo de verdad.  El reporte de texto solo publica la C total de cada net.
rc = None
if os.path.exists(SPEF):
    nets = [e.get("net") for e in cam["etapas"] if e.get("net")]
    rc = S.leer(SPEF, nets)
    nr = sum(1 for n in nets if rc.get(n, {}).get("res"))
    print("SPEF: %s  ->  %d de %d nets del camino con red RC" % (SPEF, nr, len(nets)))
else:
    print("SPEF ausente (%s): sin variante D" % SPEF)

VAR = [("A  puertas solas",              dict(con_cap=False, slew_real=False)),
       ("B  + capacitancia extraída",    dict(con_cap=True,  slew_real=False)),
       ("C  + flanco real de entrada",   dict(con_cap=True,  slew_real=True))]
if rc:
    VAR.append(("D0 topologia del SPEF, R=0",
                dict(con_cap=True, slew_real=True, rc=rc, con_r=False)))
    VAR.append(("D  + resistencia del cable (SPEF)",
                dict(con_cap=True, slew_real=True, rc=rc)))
if PEX and sub_pex:
    VAR.append(("E  + la celda EXTRAIDA del layout",
                dict(con_cap=True, slew_real=True, rc=rc, inc=inc)))

print("camino de %s: %s -> %d etapas" % (NOM, cam["arranque"], len(cam["etapas"]) - 1))
res = {}
for et, kw in VAR:
    f = "%s_%s.spice" % (NOM, et.split()[0])
    inf = G.generar(cam, sub_pex if kw.get("inc") else sub, f, RPT, **kw)
    out = subprocess.run(["ngspice", "-b", f], capture_output=True, text=True).stdout
    m = re.search(r"^retardo\s+=\s+(\S+)", out, re.M)
    r = float(m.group(1)) * 1e9 if m and "fail" not in m.group(1) else None
    res[et] = r
    print("  %-30s %s" % (et, ("%.3f ns" % r) if r else "NO CONMUTA (sensibilización mal)"))

sta_tot = cam["retardo"]; sta_log = sta_tot - inf["clkq"]
print("\n  el STA, para la misma lógica       %.3f ns" % sta_log)
print("  (+ %.3f ns de reloj a dato del biestable = %.3f ns de camino completo)"
      % (inf["clkq"], sta_tot))
ok = [res[e] for e, _ in VAR if res.get(e)]
if len(ok) >= 3:
    a, b, c = ok[:3]
    print("\n  desglose de los %.3f ns que predice el STA:" % sta_log)
    print("    puertas                    %6.3f ns   %4.1f %%" % (a, 100*a/sta_log))
    print("    carga de cable y fanout    %6.3f ns   %4.1f %%" % (b-a, 100*(b-a)/sta_log))
    print("    flanco de entrada          %6.3f ns   %4.1f %%" % (c-b, 100*(c-b)/sta_log))
    if len(ok) < 4:
        print("    ─────────────────────────────────────────────")
        print("    SPICE explica              %6.3f ns   %4.1f %%" % (c, 100*c/sta_log))
        print("    sin explicar (R del cable) %6.3f ns   %4.1f %%"
              % (sta_log-c, 100*(sta_log-c)/sta_log))
    else:
        d0, d = ok[3], ok[4] if len(ok) > 4 else ok[3]
        e = ok[5] if len(ok) > 5 else None
        print("    reparto real de la C        %6.3f ns   %4.1f %%   <- topologia SPEF"
              % (d0-c, 100*(d0-c)/sta_log))
        c = d0
        print("    resistencia del cable      %6.3f ns   %4.1f %%   <- del SPEF"
              % (d-c, 100*(d-c)/sta_log))
        if e:
            print("    la celda EXTRAIDA del layout %5.3f ns   %4.1f %%   <- parasitos"
                  " que el .spice del PDK no tiene" % (e-d, 100*(e-d)/sta_log))
        print("    ─────────────────────────────────────────────")
        fin = e or d
        print("    SPICE explica              %6.3f ns   %4.1f %%" % (fin, 100*fin/sta_log))
        print("    sin explicar               %6.3f ns   %4.1f %%"
              % (sta_log-fin, 100*(sta_log-fin)/sta_log))
