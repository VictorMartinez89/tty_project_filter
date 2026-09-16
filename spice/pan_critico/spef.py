#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""spef.py — lee del fichero SPEF la red RC de unas nets concretas.

Por qué existe: el reporte de texto del STA publica de cada net una sola cifra,
la capacitancia TOTAL.  El analizador, en cambio, no trabaja con esa cifra: lee
el SPEF, que da la RESISTENCIA y la CAPACITANCIA de cada tramo de cable y cómo
están conectados entre sí.  En §33 SPICE recibió sólo la C y reprodujo dos
tercios del retardo; esto es lo que faltaba.

Formato (IEEE 1481-1999, tal como lo emite OpenRCX):

    *NAME_MAP
    *5 digito[1]                  <- los nombres van numerados
    ...
    *D_NET *5 0.000841854         <- net y su capacitancia total
    *CONN
    *P digito[1] O                <- puerto del chip
    *I *112797:X O *D sky130...   <- pin de instancia (I=entrada, O=salida)
    *CAP
    1 digito[1] 0.000420927       <- 3 campos: C a tierra de ese nodo
    3 digito[1] *17219:74 0       <- 4 campos: C de acoplamiento a OTRA net
    *RES
    1 *112797:X digito[1] 21.9768 <- R entre dos nodos de la net
    *END

Las de acoplamiento se aterrizan (sumadas al nodo local), que es lo que hace el
propio STA cuando no se le pide análisis de integridad de señal.

Unidades: el fichero declara *C_UNIT 1 PF y *R_UNIT 1 OHM.  Se leen, no se
suponen.
"""
import re
import sys


def _map_nombres(fh):
    """*NAME_MAP: numero -> nombre.  Devuelve tambien el diccionario inverso."""
    num2nom = {}
    for l in fh:
        if l.startswith("*NAME_MAP"):
            break
    for l in fh:
        s = l.strip()
        if not s:
            continue
        if s.startswith(("*PORTS", "*D_NET", "*DEFINE")):
            break
        if s.startswith("*"):
            p = s.split()
            if len(p) >= 2 and p[0][1:].isdigit():
                num2nom[p[0][1:]] = p[1]
    return num2nom


def _local(n, cur):
    """¿Es `n` un nodo de ESTA net?  O es un nodo interno suyo (`net:idx`), o es
    uno de los pines que su seccion *CONN declara."""
    return (n.startswith(cur["nom"] + ":") or n == cur["nom"]
            or any(n == c[0] for c in cur["conn"]))


def _nodo(tok, num2nom):
    """`*112797:X` -> `_13638_:X` ;  `digito[1]` -> `digito[1]`."""
    if not tok.startswith("*"):
        return tok
    if ":" in tok:
        n, resto = tok[1:].split(":", 1)
        return "%s:%s" % (num2nom.get(n, "*" + n), resto)
    return num2nom.get(tok[1:], tok)


def leer(path, pedidas):
    """Devuelve {nombre_de_net: {'total':pF, 'cap':{nodo:pF}, 'res':[(a,b,ohm)],
    'conn':[(nodo,'I'|'O'|'P')]}} para las nets de `pedidas`."""
    pedidas = set(pedidas)
    fh = open(path, errors="ignore")

    cu, ru = 1.0, 1.0                      # factores a pF y a ohm
    fh.seek(0)
    for l in fh:
        if l.startswith("*C_UNIT"):
            v, u = l.split()[1:3]
            cu = float(v) * {"PF": 1.0, "FF": 1e-3, "NF": 1e3}[u.upper()]
        elif l.startswith("*R_UNIT"):
            v, u = l.split()[1:3]
            ru = float(v) * {"OHM": 1.0, "KOHM": 1e3}[u.upper()]
        elif l.startswith("*NAME_MAP"):
            break
    fh.seek(0)                     # _map_nombres vuelve a buscar la cabecera
    num2nom = _map_nombres(fh)
    nom2num = {v: k for k, v in num2nom.items()}
    # los numeros de las nets que nos interesan, para filtrar sin resolver todo
    quiero = {"*" + nom2num[n]: n for n in pedidas if n in nom2num}
    quiero.update({n: n for n in pedidas if n not in nom2num})   # nets sin mapear

    out = {}
    fh.seek(0)
    cur = None
    sec = None
    for l in fh:
        if l.startswith("*D_NET"):
            p = l.split()
            nom = quiero.get(p[1])
            cur = None
            if nom is not None:
                cur = out.setdefault(nom, dict(total=float(p[2]) * cu, cap={},
                                               res=[], conn=[], nom=nom))
            sec = None
            continue
        if cur is None:
            continue
        s = l.strip()
        if s.startswith("*END"):
            cur = None
            continue
        if s.startswith("*CONN"):
            sec = "conn"; continue
        if s.startswith("*CAP"):
            sec = "cap"; continue
        if s.startswith("*RES"):
            sec = "res"; continue
        p = s.split()
        if not p:
            continue
        if sec == "conn" and p[0] in ("*I", "*P"):
            cur["conn"].append((_nodo(p[1], num2nom), p[2]))
        elif sec == "cap":
            # 3 campos -> a tierra ; 4 -> acoplamiento (se aterriza)
            if len(p) == 3:
                n1, c = _nodo(p[1], num2nom), float(p[2]) * cu
                cur["cap"][n1] = cur["cap"].get(n1, 0.0) + c
            elif len(p) == 4:
                # acoplamiento.  OJO: el SPEF NO garantiza que el nodo local sea
                # el primero — en pan_sobel, 69 de las 88 entradas de `_11348_`
                # lo listan SEGUNDO.  Aterrizarlo en el nodo equivocado reparte
                # la C sobre nets ajenas y deja el arbol propio sin carga.
                n1, n2 = _nodo(p[1], num2nom), _nodo(p[2], num2nom)
                loc = n1 if _local(n1, cur) else (n2 if _local(n2, cur) else n1)
                cur["cap"][loc] = cur["cap"].get(loc, 0.0) + float(p[3]) * cu
        elif sec == "res" and len(p) == 4:
            cur["res"].append((_nodo(p[1], num2nom), _nodo(p[2], num2nom),
                               float(p[3]) * ru))
    return out


def elmore(red, drv, receptores):
    """Retardo de Elmore del arbol RC, del nodo `drv` a cada receptor (ns).

    Sirve de contraste independiente de SPICE: para un arbol RC, tau de un
    receptor es la suma sobre todas las resistencias del camino comun de
    R * (capacidad aguas abajo de esa R).
    """
    ady = {}
    for a, b, r in red["res"]:
        ady.setdefault(a, []).append((b, r))
        ady.setdefault(b, []).append((a, r))
    # arbol por anchura desde el driver
    padre, orden, vistos = {drv: None}, [drv], {drv}
    i = 0
    while i < len(orden):
        u = orden[i]; i += 1
        for v, r in ady.get(u, []):
            if v not in vistos:
                vistos.add(v); padre[v] = (u, r); orden.append(v)
    # capacidad aguas abajo, recorriendo en orden inverso
    cdown = {n: red["cap"].get(n, 0.0) for n in orden}
    for n in reversed(orden[1:]):
        cdown[padre[n][0]] += cdown[n]
    tau = {}
    for rec in receptores:
        if rec not in padre:
            tau[rec] = None
            continue
        t, n = 0.0, rec
        while padre.get(n):
            u, r = padre[n]
            t += r * cdown[n]          # ohm * pF = ps
            n = u
        tau[rec] = t * 1e-3            # -> ns
    return tau


if __name__ == "__main__":
    red = leer(sys.argv[1], sys.argv[2:])
    for n, d in red.items():
        print("%s  total %.5f pF  %d nodos  %d resistencias  conn %s"
              % (n, d["total"], len(d["cap"]), len(d["res"]), d["conn"][:4]))
        print("   suma de C del SPEF: %.5f pF" % sum(d["cap"].values()))
