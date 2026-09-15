#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""gen_camino.py — construye un banco de NGSpice para el CAMINO CRÍTICO de un chip.

Por qué esto y no el chip entero: `pan_sobel` tiene ~125 000 transistores, cifra
perfectamente simulable (esta misma tesis simuló `femto`, de 121 310). Lo que lo
hace inviable es el TIEMPO: para que el clasificador vea sus 784 píxeles hay que
meterle un cuadro VGA completo, 633 800 ciclos = 6.34 ms, treinta y dos veces más
de lo que se simuló de `femto`. Semanas de máquina.

El camino crítico, en cambio, son unas 40 celdas —unos 400 transistores— y responde
la pregunta que de verdad importa de una firma: **¿dijo la verdad el analizador
estático de tiempos?** El STA suma retardos tabulados celda por celda; SPICE
resuelve las ecuaciones del transistor. Que coincidan no es trivial.

  python3 gen_camino.py <reporte_sta.rpt> <salida.spice> [--path N]

El banco se AUTO-VERIFICA: si la sensibilización del camino estuviera mal, la
salida final no conmutaría y `.meas` devolvería «failed». Eso es una comprobación,
no un fallo silencioso.
"""
import os
import re
import sys

PDK = os.path.expanduser("~/.volare/sky130A/libs.ref/sky130_fd_sc_hd/spice/sky130_fd_sc_hd.spice")
LIB = os.path.expanduser("~/.volare/sky130A/libs.tech/ngspice/sky130.lib.spice")
PRE = "sky130_fd_sc_hd__"


# --------------------------------------------------------------------------
# 1 · el camino, leído del reporte de OpenSTA
# --------------------------------------------------------------------------
def leer_camino(rpt, cual=None):
    """Devuelve la etapa de arranque y las celdas del camino de DATOS más lento
    que empiece en un biestable. Descarta la cola de árbol de reloj que el
    reporte añade para mostrar la llegada del reloj al destino."""
    L = open(rpt, errors="ignore").read().split("\n")
    ini = [i for i, l in enumerate(L) if l.startswith("Startpoint:")]
    pat = re.compile(r"\s([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+([v^])\s+(\S+)/(\S+)\s+\((sky130_\S+)\)")
    SAL = ("X", "Y", "Q", "Q_N")

    cands = []
    for a, b in zip(ini, ini[1:] + [len(L)]):
        blk = L[a:b]
        if "flip-flop" not in blk[0]:
            continue                                   # sólo registro a registro
        # el camino de DATOS acaba en «data arrival time»; lo que sigue es el
        # árbol de reloj del destino, que no es camino combinacional
        fin = [i for i, l in enumerate(blk) if "data arrival time" in l]
        if not fin:
            continue
        slk = [l for l in blk if "slack" in l]
        if not slk:
            continue
        arranque = blk[0].split(": ", 1)[1].split()[0]
        # las lineas de net traen el fanout y la capacitancia REAL del cable:
        #    "     4    0.02                           _11526_ (net)"
        red = re.compile(r"^\s+(\d+)\s+([\d.]+)\s+\S+\s+\(net\)")
        fil = []
        for l in blk[:fin[0]]:
            m = pat.search(l)
            if m:
                fil.append(dict(slew=float(m[1]), d=float(m[2]), t=float(m[3]),
                                borde=m[4], inst=m[5], pin=m[6],
                                tipo=m[7].replace(PRE, ""), fo=0, cap=0.0))
                continue
            n = red.match(l)
            if n and fil:
                fil[-1]["fo"] = int(n[1])
                fil[-1]["cap"] = float(n[2])      # pF
        # el dato nace en la salida Q del biestable de arranque
        q = [i for i, f in enumerate(fil) if f["inst"] == arranque and f["pin"] in SAL]
        if not q:
            continue
        fil = fil[q[0]:]
        # emparejar: cada celda da una línea de pin de ENTRADA y otra de SALIDA
        etapas = []
        for i, f in enumerate(fil):
            if f["pin"] not in SAL:
                continue
            ent = None
            if i and fil[i - 1]["inst"] == f["inst"]:
                ent = fil[i - 1]["pin"]
            etapas.append(dict(f, pin_ent=ent, pin_sal=f["pin"]))
        slack = float(re.search(r"(-?\d+\.\d+)\s+slack", slk[-1]).group(1))
        cands.append(dict(arranque=arranque, etapas=etapas, slack=slack,
                          retardo=etapas[-1]["t"] - etapas[0]["t"] + etapas[0]["d"]))

    cands.sort(key=lambda c: -c["retardo"])
    return cands[cual or 0], len(cands)


# --------------------------------------------------------------------------
# 2 · los subcircuitos del PDK: de ahí sale el orden de pines, no se adivina
# --------------------------------------------------------------------------
def leer_subckts(path):
    d = {}
    for l in open(path, errors="ignore"):
        if l.startswith(".subckt " + PRE):
            p = l.split()
            d[p[1].replace(PRE, "")] = p[2:]
    return d


ALIM = {"VGND", "VNB", "VPB", "VPWR"}


def sensibilizar(tipo, pin_camino, pines, b_ent=None, b_sal=None):
    """Valor lógico al que hay que atar cada entrada LATERAL para que el camino
    quede transparente. Devuelve {pin: 0|1}.

    Nomenclatura de sky130_fd_sc_hd:
      aN1N2...o[i]  -> grupos AND (A de N1 pines, B de N2, ...) unidos por OR
      oN1N2...a[i]  -> grupos OR unidos por AND
      una `b` tras un dígito marca que ese grupo lleva una entrada negada (`_N`)
    Para dejar pasar el pin del grupo G: en `a..o` los demás de G a 1 y los otros
    grupos a 0; en `o..a` al revés. Un pin `_N` invierte el valor que le toca.
    """
    ent = [p for p in pines if p not in ALIM and p not in ("X", "Y", "Q", "Q_N")]
    otras = [p for p in ent if p != pin_camino]
    base = re.sub(r"_\d+$", "", tipo)
    v = {}

    def poner(p, val):
        v[p] = 1 - val if p.endswith("_N") else val

    # --- puertas simples ---------------------------------------------------
    if base.startswith(("buf", "inv", "clkbuf", "clkinv", "dly", "dfxtp", "dfrtp",
                        "conb", "einv", "ebuf")):
        return {}
    if base.startswith(("and", "nand")):
        for p in otras:
            poner(p, 1)
        return v
    if base.startswith(("or", "nor")):
        for p in otras:
            poner(p, 0)
        return v
    if base.startswith(("xor", "xnor")):
        # La lateral de un XOR no sólo deja pasar el camino: ELIGE EL SENTIDO del
        # flanco.  xor2: X=A^B  -> B=0 conserva el borde, B=1 lo invierte.
        #          xnor2: Y=!(A^B) -> al revés.
        # En CMOS subir y bajar no cuestan lo mismo, así que hay que reproducir el
        # borde que el STA declara o se mide la transición equivocada.
        igual = (b_ent == b_sal) if (b_ent and b_sal) else True
        lat = (0 if igual else 1) if base.startswith("xor") else (1 if igual else 0)
        for p in otras:
            poner(p, lat)
        return v
    if base.startswith("mux2"):
        # pines A0 A1 S: el selector elige de qué rama viene el camino
        if pin_camino == "S":
            return {"A0": 0, "A1": 1}
        return {"S": 1 if pin_camino == "A1" else 0,
                "A0" if pin_camino == "A1" else "A1": 0}

    # --- familias AOI / OAI ------------------------------------------------
    m = re.match(r"^([ao])((?:\d+b?)+)([ao])(i?)$", base)
    if not m:
        raise ValueError("no sé sensibilizar %s (pin %s)" % (tipo, pin_camino))
    prim = m.group(1)                       # 'a' = grupos AND ; 'o' = grupos OR
    tam = [int(x) for x in re.findall(r"\d", m.group(2))]
    grupo = {}                              # pin -> letra de grupo
    for letra, n in zip("ABCDEF", tam):
        for k in range(1, n + 1):
            for cand in ("%s%d" % (letra, k), "%s%d_N" % (letra, k),
                         letra, letra + "_N"):
                if cand in ent:
                    grupo[cand] = letra
                    break
    if pin_camino not in grupo:
        raise ValueError("pin %s no encaja en los grupos de %s" % (pin_camino, tipo))
    g = grupo[pin_camino]
    dentro, fuera = (1, 0) if prim == "a" else (0, 1)
    for p in otras:
        poner(p, dentro if grupo.get(p) == g else fuera)
    return v


# --------------------------------------------------------------------------
# 3 · el banco
# --------------------------------------------------------------------------
def generar(cam, sub, salida, rpt, con_cap=True, slew_real=True):
    et = cam["etapas"]
    logica = et[1:]                          # la etapa 0 es el clk->Q del biestable
    clkq = et[0]["d"]                        # retardo de reloj a dato del biestable
    tr = et[0]["slew"]                       # y el flanco con que entrega ese dato
    lin, avisos = [], []
    lin += ["* Camino crítico de %s — generado por gen_camino.py" % os.path.basename(rpt),
            "* %d etapas de lógica · el STA predice %.3f ns de reloj a dato"
            % (len(logica), cam["retardo"]),
            "*",
            '.include "%s"' % PDK,
            '.lib "%s" tt' % LIB,
            "",
            ".param VDD=1.8",
            "Vdd  VPWR 0 {VDD}",
            "Vss  VGND 0 0",
            "* pozos: VPB al positivo, VNB al negativo",
            "Vone ALTO 0 {VDD}",
            "Vzer BAJO 0 0",
            "",
            "* estímulo. El STA no parte de un flanco ideal: la primera etapa recibe",
            "* una transición de %.3f ns, y un flanco lento se propaga como retardo",
            "* a lo largo de toda la cadena. Con slew_real=False se usa un flanco",
            "* de 20 ps, para poder medir cuánto aporta ese solo factor.",
            ("Vin  n000 0 PWL(0 0 1n 0 %gn {VDD})" if et[0]["borde"] == "^" else
             "Vin  n000 0 PWL(0 {VDD} 1n {VDD} %gn 0)")
            % (1 + (tr if slew_real else 0.02)),
            ""]

    nodo = "n000"
    for k, f in enumerate(logica):
        tipo, pin = f["tipo"], f["pin_ent"]
        if tipo not in sub:
            avisos.append("falta el subckt de %s" % tipo)
            continue
        pines = sub[tipo]
        sal = f["pin_sal"]
        try:
            b_ent = logica[k - 1]["borde"] if k else et[0]["borde"]
            lat = sensibilizar(tipo, pin, pines, b_ent, f["borde"])
        except ValueError as e:
            avisos.append(str(e))
            lat = {}
        sig = "n%03d" % (k + 1)
        con = []
        for p in pines:
            if p == "VPWR":
                con.append("VPWR")
            elif p in ("VGND", "VNB"):
                con.append("VGND")
            elif p == "VPB":
                con.append("VPWR")
            elif p == sal:
                con.append(sig)
            elif p == pin:
                con.append(nodo)
            elif p in lat:
                con.append("ALTO" if lat[p] else "BAJO")
            else:
                con.append("BAJO")
                avisos.append("%s/%s sin valor asignado -> a 0" % (f["inst"], p))
        lin.append("X%-3d %s %s%s   $ %s  STA %.3f ns"
                   % (k, " ".join(con), PRE, tipo, f["inst"], f["d"]))
        # la capacitancia que el reporte post-extraccion atribuye a ESTE nodo:
        # es la carga de cable + fanout que la etapa tiene que mover de verdad
        if con_cap and f.get("cap"):
            lin.append("C%-3d %s 0 %gp   $ fanout %d" % (k, sig, f["cap"], f["fo"]))
        nodo = sig

    ult = nodo
    lin += ["",
            "* la ultima etapa ya lleva su C del reporte; nada mas que anadir",
            "",
            ".tran 1p %.0fn" % (cam["retardo"] * 2 + 4),
            "* CROSS, no RISE: el camino puede arrancar con flanco de bajada",
            ".meas tran t_in  WHEN v(n000)={VDD/2} CROSS=1",
            ".meas tran t_out WHEN v(%s)={VDD/2} CROSS=1" % ult,
            ".meas tran retardo PARAM='t_out-t_in'",
            ".control",
            "run",
            "* el perfil nodo a nodo: permite ver DONDE se pierde el tiempo",
            "wrdata perfil.dat " + " ".join("v(n%03d)" % i for i in range(len(logica) + 1)),
            ".endc",
            ".end", ""]
    open(salida, "w").write("\n".join(lin))
    return dict(n=len(logica), ult=ult, avisos=avisos, clkq=clkq, tr=tr)


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    rpt, out = sys.argv[1], sys.argv[2]
    cual = int(sys.argv[sys.argv.index("--path") + 1]) if "--path" in sys.argv else 0
    cam, n = leer_camino(rpt, cual)
    sub = leer_subckts(PDK)
    ne, ult, avisos = generar(cam, sub, out, rpt)
    print("%d caminos registro-a-registro en el reporte; se toma el más lento" % n)
    print("  arranque : %s" % cam["arranque"])
    print("  etapas   : %d celdas de lógica" % ne)
    print("  STA      : %.3f ns de reloj a dato (holgura declarada %.2f ns)"
          % (cam["retardo"], cam["slack"]))
    print("  banco    : %s  (nodo final %s)" % (out, ult))
    if avisos:
        print("\n  AVISOS (%d):" % len(avisos))
        for a in sorted(set(avisos)):
            print("    · %s" % a)
