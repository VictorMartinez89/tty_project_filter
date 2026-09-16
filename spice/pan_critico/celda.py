#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""celda.py — una celda sola: lo que dice su tabla Liberty contra lo que dice SPICE.

Por qué hace falta.  En §33 la cadena de 37 etapas simulada en SPICE daba 8.2 ns
donde el analizador estático predecía 12.2, y la explicación que quedaba por
eliminación era la RESISTENCIA del cable.  Pero el propio reporte del STA reparte
esos 12.22 ns como 12.18 de CELDA y 0.04 de cable: la interconexión no puede ser.

Este banco aísla la pregunta.  Coge UNA celda, el mismo arco que el reporte
recorre, la misma pendiente de entrada y la misma capacitancia de salida, y
pregunta lo mismo dos veces:

  · a la tabla Liberty  -> interpolando `cell_rise`/`cell_fall` como hace OpenSTA
  · a NGSpice           -> resolviendo los transistores del `.subckt` del PDK

Las dos a tt, 25 °C, 1.80 V; retardo al 50 % y pendiente 20-80 %, que es como la
biblioteca declara medirlos.  Si la tabla y SPICE discrepan en una celda AISLADA,
la diferencia no esta en como se armo la cadena: esta en el modelo de celda.

    python3 celda.py                 # las celdas del camino critico
    python3 celda.py or4b_1 A X 0.14 0.010
"""
import os
import re
import subprocess
import sys

import gen_camino as G

LIBERTY = os.path.expanduser(
    "~/.volare/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib")
VDD = 1.8
INC = {}        # celda -> netlist a incluir; lo llena --pex


# --------------------------------------------------------------------------
# 1 · la tabla Liberty
# --------------------------------------------------------------------------
def _tabla(txt):
    """index_1 (pendientes), index_2 (cargas) y la matriz de valores."""
    i1 = re.search(r'index_1\s*\(\s*"([^"]*)"', txt)
    i2 = re.search(r'index_2\s*\(\s*"([^"]*)"', txt)
    vals = re.search(r'values\s*\((.*?)\)\s*;', txt, re.S)
    if not (i1 and i2 and vals):
        return None
    f = lambda s: [float(x) for x in s.replace("\\", " ").split(",") if x.strip()]
    filas = [f(m) for m in re.findall(r'"([^"]*)"', vals.group(1))]
    return f(i1.group(1)), f(i2.group(1)), filas


def _bloque(txt, i):
    """desde la llave que abre en `i` hasta la que la cierra."""
    n, j = 0, i
    while j < len(txt):
        if txt[j] == "{":
            n += 1
        elif txt[j] == "}":
            n -= 1
            if n == 0:
                return txt[i:j + 1]
        j += 1
    return txt[i:]


_CACHE = {}


def arcos(cel):
    """{(pin_sal, pin_ent): {'cell_rise':tabla, 'cell_fall':tabla, ...}}"""
    if cel in _CACHE:
        return _CACHE[cel]
    txt = open(LIBERTY, errors="ignore").read()
    m = re.search(r'\n\s*cell\s*\(\s*"?sky130_fd_sc_hd__%s"?\s*\)\s*\{' % re.escape(cel), txt)
    if not m:
        raise ValueError("no esta %s en la Liberty" % cel)
    blo = _bloque(txt, txt.index("{", m.start()))
    out = {}
    for pm in re.finditer(r'\n\s*pin\s*\(\s*"?(\w+)"?\s*\)\s*\{', blo):
        pin = pm.group(1)
        pb = _bloque(blo, blo.index("{", pm.start()))
        if not re.search(r'direction\s*:\s*"?output"?', pb):
            continue
        for tm in re.finditer(r'\n\s*timing\s*\(\s*\)\s*\{', pb):
            tb = _bloque(pb, pb.index("{", tm.start()))
            rp = re.search(r'related_pin\s*:\s*"?(\w+)"?', tb)
            if not rp:
                continue
            d = {}
            for k in ("cell_rise", "cell_fall", "rise_transition", "fall_transition"):
                km = re.search(r'\n\s*%s\s*\(' % k, tb)
                if km:
                    d[k] = _tabla(_bloque(tb, tb.index("{", km.start())))
            sm = re.search(r'timing_sense\s*:\s*"?(\w+)"?', tb)
            d["sense"] = sm.group(1) if sm else "combinational"
            out[(pin, rp.group(1))] = d
    _CACHE[cel] = out
    return out


def interp(tab, slew, carga):
    """bilineal sobre (pendiente, carga), extrapolando en los bordes — que es lo
    que hace OpenSTA cuando el punto cae fuera de la rejilla."""
    xs, ys, V = tab

    def lug(v, e):
        if len(e) == 1:
            return 0, 0.0
        i = max(0, min(len(e) - 2, next((k for k in range(len(e) - 1)
                                         if v <= e[k + 1]), len(e) - 2)))
        return i, (v - e[i]) / (e[i + 1] - e[i])

    i, a = lug(slew, xs)
    j, b = lug(carga, ys)
    v00, v01 = V[i][j], V[i][j + 1]
    v10, v11 = V[i + 1][j], V[i + 1][j + 1]
    return (v00 * (1 - a) * (1 - b) + v01 * (1 - a) * b +
            v10 * a * (1 - b) + v11 * a * b)


# --------------------------------------------------------------------------
# 2 · la misma pregunta, a NGSpice
# --------------------------------------------------------------------------
def spice(cel, pin_ent, pin_sal, slew, carga, sube, sub, tmp="una_celda.spice",
          b_ent=None, b_sal=None):
    """`slew` es 20-80 % (como la declara la Liberty), la rampa se ajusta a eso."""
    pines = sub[cel]
    # el sentido importa: en una XOR la lateral ELIGE la polaridad del flanco
    lat = G.sensibilizar(cel, pin_ent, pines, b_ent, b_sal)
    tr = max(slew / 0.6, 1e-3)            # 20-80 % -> 0-100 %
    con = []
    for p in pines:
        con.append("VPWR" if p in ("VPWR", "VPB") else
                   "VGND" if p in ("VGND", "VNB") else
                   "sal" if p == pin_sal else
                   "ent" if p == pin_ent else
                   ("ALTO" if lat.get(p, 0) else "BAJO"))
    L = ['.include "%s"' % INC.get(cel, G.PDK), '.lib "%s" tt' % G.LIB,
         ".param VDD=%g" % VDD,
         "Vdd VPWR 0 {VDD}", "Vss VGND 0 0",
         "Vone ALTO 0 {VDD}", "Vzer BAJO 0 0",
         ("Vin ent 0 PWL(0 0 1n 0 %gn {VDD})" if sube else
          "Vin ent 0 PWL(0 {VDD} 1n {VDD} %gn 0)") % (1 + tr),
         "X0 %s %s%s" % (" ".join(con), G.PRE, cel),
         "Cl sal 0 %gp" % max(carga, 1e-6),
         ".tran 0.2p 20n",
         ".meas tran tin  WHEN v(ent)={VDD/2} CROSS=1",
         ".meas tran tout WHEN v(sal)={VDD/2} CROSS=1",
         ".meas tran d PARAM='tout-tin'",
         ".meas tran s20 WHEN v(sal)={0.2*VDD} CROSS=1",
         ".meas tran s80 WHEN v(sal)={0.8*VDD} CROSS=1",
         ".end", ""]
    open(tmp, "w").write("\n".join(L))
    o = subprocess.run(["ngspice", "-b", tmp], capture_output=True, text=True).stdout
    g = lambda k: (lambda m: float(m.group(1)) if m and "fail" not in m.group(1) else None)(
        re.search(r"^%s\s*=\s*(\S+)" % k, o, re.M))
    d, a, b = g("d"), g("s20"), g("s80")
    return (d * 1e9 if d else None,
            abs(b - a) * 1e9 if a is not None and b is not None else None)


# --------------------------------------------------------------------------
def fuentes(pex):
    """Con --pex <dir>: un fichero .spice por celda, EXTRAIDO del layout con
    Magic (ver utm-share/extraer_celdas/).  Sin el: el `.spice` unico que el PDK
    distribuye, que es el ESQUEMATICO — transistores sin un solo parasito.

    Devuelve (subckts, {celda: fichero_a_incluir})."""
    if not pex:
        return G.leer_subckts(G.PDK), {}
    sub, inc = {}, {}
    for f in sorted(os.listdir(pex)):
        if not f.endswith(".spice"):
            continue
        ruta = os.path.join(pex, f)
        for cel, pines in G.leer_subckts(ruta).items():
            sub[cel] = pines
            inc[cel] = ruta
    print("netlists EXTRAIDOS: %d celdas de %s" % (len(sub), pex))
    return sub, inc


if __name__ == "__main__":
    # --rpt <reporte>: el mismo banco sobre otro chip
    # --pex <dir>   : usar los netlists extraidos del layout
    RPT_ARG, PEX = None, None
    if "--pex" in sys.argv:
        i = sys.argv.index("--pex")
        PEX = sys.argv[i + 1]
        del sys.argv[i:i + 2]
    if "--rpt" in sys.argv:
        i = sys.argv.index("--rpt")
        RPT_ARG = sys.argv[i + 1]
        del sys.argv[i:i + 2]

    sub, INC = fuentes(PEX)
    if len(sys.argv) > 2:
        cel, pe, ps, slew, car = (sys.argv[1], sys.argv[2], sys.argv[3],
                                  float(sys.argv[4]), float(sys.argv[5]))
        casos = [(cel, pe, ps, slew, car, True, None)]
    else:
        RPT = RPT_ARG or ("/Users/vic/utm-share/asic_pan_sobel/results_final/"
                          "signoff/31-rcx_sta.max.rpt")
        cam, _ = G.leer_camino(RPT, 0)
        casos = [(f["tipo"], f["pin_ent"], f["pin_sal"], f["slew_ent"], f["cap"],
                  f["borde"] == "^", f) for f in cam["etapas"][1:]
                 if f.get("pin_ent") and f.get("slew_ent") is not None]

    print("%-3s %-14s %-4s %6s %6s | %8s %8s %8s %7s"
          % ("#", "celda", "arco", "slew", "cap", "Liberty", "SPICE", "STA", "L/S"))
    tl = ts = tsta = 0.0
    for k, (cel, pe, ps, slew, car, sube, f) in enumerate(casos):
        try:
            arc = arcos(cel)[(ps, pe)]
        except (ValueError, KeyError):
            print("%-3d %-14s %-4s  (sin arco en la Liberty)" % (k, cel, pe))
            continue
        # la tabla la elige el flanco de SALIDA; el estimulo, el de ENTRADA
        tab = arc["cell_rise"] if sube else arc["cell_fall"]
        lib = interp(tab, slew, car)
        be = f["borde_ent"] if f else ("^" if sube else "v")
        spi, _ = spice(cel, pe, ps, slew, car, be == "^", sub,
                       b_ent=be, b_sal=(f["borde"] if f else None))
        sta = f["d"] if f else float("nan")
        tl += lib; ts += spi or 0; tsta += sta if f else 0
        print("%-3d %-14s %-4s %6.3f %6.3f | %8.3f %8.3f %8.3f %7s"
              % (k, cel, "%s→%s" % (pe, ps), slew, car, lib, spi or 0, sta,
                 "%.2f" % (lib / spi) if spi else "-"))
    print("%-3s %-14s %-4s %6s %6s | %8.3f %8.3f %8.3f %7.2f"
          % ("", "SUMA", "", "", "", tl, ts, tsta, tl / ts if ts else 0))
