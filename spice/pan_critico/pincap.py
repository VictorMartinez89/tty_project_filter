#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""pincap.py — la capacitancia de entrada que DECLARA la Liberty contra la que
TIENE el netlist esquemático del PDK.

Es la comprobación directa de por qué SPICE sale más rápido que la tabla en una
celda aislada.  Si la biblioteca se caracterizó sobre el layout extraído y el
`.subckt` que le damos a SPICE es el esquemático, la diferencia tiene que
aparecer aquí: en el silicio, al pin de una celda le cuelga la puerta del
transistor MÁS el metal, el contacto y la difusión que el dibujo añade.

Medida en SPICE: se mete al pin una rampa lenta de 0 a VDD y se integra la
corriente que entra.  C = Q/VDD.  No hay modelo ni supuesto: es la carga que hay
que meter para subir ese nodo.

    python3 pincap.py                  # las celdas del camino crítico
    python3 pincap.py or4b_1 B
"""
import os
import re
import subprocess
import sys

import celda as C
import gen_camino as G

VDD = 1.8
INC = {}        # celda -> netlist a incluir; lo llena --pex


def liberty_cap(cel, pin):
    """el valor `capacitance` que la biblioteca declara para ese pin de entrada."""
    txt = open(C.LIBERTY, errors="ignore").read()
    m = re.search(r'\n\s*cell\s*\(\s*"?sky130_fd_sc_hd__%s"?\s*\)\s*\{' % re.escape(cel), txt)
    blo = C._bloque(txt, txt.index("{", m.start()))
    pm = re.search(r'\n\s*pin\s*\(\s*"?%s"?\s*\)\s*\{' % re.escape(pin), blo)
    if not pm:
        return None
    pb = C._bloque(blo, blo.index("{", pm.start()))
    if not re.search(r'direction\s*:\s*"?input"?', pb):
        return None
    cm = re.search(r'\n\s*capacitance\s*:\s*([\d.eE+-]+)', pb)
    return float(cm.group(1)) if cm else None


def spice_cap(cel, pin, sub, tmp="pincap.spice"):
    """C = Q/VDD, con Q integrada de la corriente que entra al pin."""
    pines = sub[cel]
    con = []
    for p in pines:
        con.append("VPWR" if p in ("VPWR", "VPB") else
                   "VGND" if p in ("VGND", "VNB") else
                   "ent" if p == pin else "BAJO")
    L = ['.include "%s"' % INC.get(cel, G.PDK), '.lib "%s" tt' % G.LIB,
         ".param VDD=%g" % VDD,
         "Vdd VPWR 0 {VDD}", "Vss VGND 0 0", "Vzer BAJO 0 0",
         # rampa MUY lenta: asi la corriente es la de carga del nodo y no la de
         # conmutacion de la celda, que se integra igual pero vuelve a salir
         "Vin ent 0 PWL(0 0 1n 0 101n {VDD})",
         "X0 %s %s%s" % (" ".join(con), G.PRE, cel),
         ".tran 10p 120n",
         ".meas tran q INTEG i(Vin) FROM=1n TO=101n",
         ".end", ""]
    open(tmp, "w").write("\n".join(L))
    o = subprocess.run(["ngspice", "-b", tmp], capture_output=True, text=True).stdout
    m = re.search(r"^q\s*=\s*(\S+)", o, re.M)
    return abs(float(m.group(1))) / VDD * 1e12 if m else None   # -> pF


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
        casos = [(sys.argv[1], sys.argv[2])]
    else:
        RPT = RPT_ARG or ("/Users/vic/utm-share/asic_pan_sobel/results_final/"
                          "signoff/31-rcx_sta.max.rpt")
        cam, _ = G.leer_camino(RPT, 0)
        vistas, casos = set(), []
        for f in cam["etapas"][1:]:
            k = (f["tipo"], f["pin_ent"])
            if f.get("pin_ent") and k not in vistas:
                vistas.add(k); casos.append(k)

    print("%-14s %-5s %10s %10s %7s" % ("celda", "pin", "Liberty", "esquema", "L/E"))
    tl = te = 0.0
    for cel, pin in casos:
        lib, spi = liberty_cap(cel, pin), spice_cap(cel, pin, sub)
        if not (lib and spi):
            continue
        tl += lib; te += spi
        print("%-14s %-5s %10.5f %10.5f %7.2f" % (cel, pin, lib, spi, lib / spi))
    print("%-14s %-5s %10.5f %10.5f %7.2f" % ("MEDIA", "", tl / len(casos),
                                              te / len(casos), tl / te))
