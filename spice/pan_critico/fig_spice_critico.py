# fig_spice_critico.py — la verificación eléctrica del camino crítico de los dos
# «Pan Hablas en MNIST».  Datos de spice/pan_critico/ (gen_camino.py + spef.py +
# correr.py + celda.py + pincap.py), ngspice sobre sky130_fd_sc_hd, esquina tt,
# 1.8 V, 25 °C, contra la Liberty tt_025C_1v80.
#
# VERSIÓN 3 (15-sep-2026).  La v1 atribuía por eliminación a la RESISTENCIA del
# cable los ~4 ns que SPICE no reproducía; medida, aporta 0.017 ns.  La v2 los
# atribuyó al modelo de celda —el `.spice` del PDK es el ESQUEMÁTICO, sin un solo
# parásito—.  Ésta lo comprueba: se extrajeron con Magic las 46 celdas del camino
# desde su layout, y con ellas la discrepancia de capacitancia desaparece.
import numpy as np
import matplotlib.pyplot as plt

plt.rcParams["figure.dpi"] = 120

# --- lo medido -------------------------------------------------------------
# A..E  las variantes de la cadena (correr.py)
# LIB   la tabla Liberty sumada celda a celda      (celda.py)
# ESQ   ngspice sobre el netlist ESQUEMÁTICO del PDK      (celda.py)
# PEX   ngspice sobre el netlist EXTRAÍDO del layout      (celda.py --pex)
# PL/PE la capacitancia de pin, Liberty y netlist         (pincap.py)
S = dict(nom="pan_sobel", n=37, A=4.646, D=7.620, E=9.694, STA=12.230,
         LIB=11.687, ESQ=8.919, PEX=11.159, R=0.017,
         PL=0.00238, PE_ESQ=0.00183, PE_PEX=0.00243)
C = dict(nom="pan_canny", n=36, A=4.424, D=7.043, E=8.962, STA=9.890,
         LIB=9.454, ESQ=7.273, PEX=8.924, R=0.020,
         PL=0.00271, PE_ESQ=0.00213, PE_PEX=0.00274)

def reparto(c):
    """Los cinco sumandos en que se descompone lo que predice el STA.  Cada uno es
    la diferencia entre dos bancos que sólo se distinguen en una cosa."""
    return [("puertas",                                   c["A"]),
            ("cable, fanout, flanco y RC del SPEF",       c["D"] - c["A"]),
            ("parásitos de celda, extraídos del layout",  c["E"] - c["D"]),
            ("lo que aún no se reproduce",                c["LIB"] - c["E"]),
            ("redondeo del reporte",                      c["STA"] - c["LIB"])]

COL = ["#4c72b0", "#2a9d8f", "#c44e52", "#ff7f0e", "#9467bd"]
ANTES, DESPUES = "#c44e52", "#2a9d8f"
FONDO = "white"

fig = plt.figure(figsize=(15.5, 9))
gs = fig.add_gridspec(2, 3, height_ratios=[1, 1], hspace=.46, wspace=.32)

# --- A · por qué el camino crítico y no el chip entero ---------------------
ax = fig.add_subplot(gs[0, 0])
ax.axis("off")
ax.set_title("A · Por qué no el chip entero", fontsize=11.5, loc="left")
ax.text(0, .95,
        "El TAMAÑO no es el problema:\n"
        "   pan_sobel   116 314 FET\n"
        "   femto       121 310 FET  ← ya simulado\n"
        "                            en esta tesis\n\n"
        "El problema es el TIEMPO. Para que el\n"
        "clasificador vea sus 784 píxeles hay que\n"
        "meterle un cuadro VGA entero:\n\n"
        "   1 cuadro      633 800 ciclos = 6.34 ms\n"
        "   femto corrió                   0.20 ms\n"
        "                                  ────────\n"
        "                                    32×\n\n"
        "Semanas de máquina. El camino crítico,\n"
        "en cambio, son 37 celdas.",
        va="top", family="monospace", fontsize=9.3, linespacing=1.5)

# --- B · el reparto, sin residuo, en los dos chips -------------------------
ax = fig.add_subplot(gs[0, 1:])
ALTO, YS = .40, {0: 0.0, 1: -1.0}
for fila, c in enumerate((S, C)):
    izq, r = 0.0, reparto(c)
    for i, (et, v) in enumerate(r):
        ax.barh(YS[fila], v, ALTO, left=izq, color=COL[i],
                edgecolor=FONDO, linewidth=1.6,
                label=et if fila == 0 else None)
        if v > .9:
            ax.text(izq + v / 2, YS[fila], "%.2f" % v, ha="center", va="center",
                    color="w", weight="bold", fontsize=11)
        izq += v
    ax.text(-.18, YS[fila], "%s\n%d etapas" % (c["nom"], c["n"]),
            ha="right", va="center", fontsize=9.5)
    ax.text(c["STA"] + .12, YS[fila], "STA  %.2f ns" % c["STA"],
            va="center", fontsize=9.5, weight="bold")
    hondo = -.24
    for i in (3, 4):                       # los estrechos, anotados y escalonados
        if r[i][1] <= .9:
            x = sum(v for _, v in r[:i]) + r[i][1] / 2
            ax.annotate("%.2f" % r[i][1], xy=(x, YS[fila] - ALTO / 2),
                        xytext=(x + .70 + (0 if hondo < -.3 else .55),
                                YS[fila] + hondo - ALTO / 2), ha="left",
                        va="top", fontsize=8.5, color=COL[i],
                        arrowprops=dict(arrowstyle="-", color=COL[i], lw=.9,
                                        shrinkA=0, shrinkB=1))
            hondo -= .24
xr = S["A"] + (S["D"] - S["A"]) / 2
ax.annotate("aquí vive la RESISTENCIA del cable,\nque era la hipótesis: 0.017 ns · el 0.1 %",
            xy=(xr, ALTO / 2), xytext=(xr, 1.00), ha="center", fontsize=8.8,
            color=COL[1], arrowprops=dict(arrowstyle="->", color=COL[1], lw=1))
ax.set_ylim(-2.45, 1.35); ax.set_yticks([])
ax.set_xlabel("ns"); ax.set_xlim(-2.6, S["STA"] * 1.10)
ax.set_xticks(range(0, int(S["STA"]) + 2, 2))
ax.set_title("B · De dónde sale cada nanosegundo, y ya sin residuo\n"
             "cada sumando es la diferencia entre dos bancos que sólo se "
             "distinguen en una cosa", fontsize=11.5, loc="left")
for s in ("top", "right", "left"): ax.spines[s].set_visible(False)
ax.grid(axis="x", alpha=.25); ax.set_axisbelow(True)
ax.legend(loc="lower left", bbox_to_anchor=(.0, .0), ncol=2,
          fontsize=8.4, frameon=False, handlelength=1.4, columnspacing=1.4)

# --- C · lo que NO era -----------------------------------------------------
ax = fig.add_subplot(gs[1, 0])
ax.axis("off")
ax.set_title("C · Tres hipótesis que la medida tumbó", fontsize=11.5, loc="left")
ax.text(0, .98,
        "1ª · «el flanco de entrada idealizado»\n"
        "   Se usó el slew real del reporte en\n"
        "   vez de una rampa de 20 ps.\n"
        "   Aporta 0.019 ns — el 0.2 %%. FALSA.\n\n"
        "2ª · «es la capacitancia de las nets\n"
        "      grandes»\n"
        "   correlación desviación–capacitancia\n"
        "            r = −0.15\n"
        "   correlación desviación–fanout\n"
        "            r = −0.06\n"
        "   Ninguna. No es carga. FALSA.\n\n"
        "3ª · «entonces es la RESISTENCIA»\n"
        "   Era la conclusión POR ELIMINACIÓN\n"
        "   de la primera versión de esta §.\n"
        "   Recuperado el SPEF, se midió:\n"
        "      topología real, R = 0   7.603 ns\n"
        "      topología real, con R   7.620 ns\n"
        "      aporte de la R          %.3f ns\n"
        "   El 0.1 %%. FALSA TAMBIÉN.\n\n"
        "Y el propio reporte del STA ya lo decía:\n"
        "   imputa a CELDA   12.18 ns\n"
        "   imputa a CABLE    0.04 ns" % S["R"],
        va="top", family="monospace", fontsize=8.6, linespacing=1.42)

# --- D · la prueba: extraer las celdas del layout --------------------------
ax = fig.add_subplot(gs[1, 1])
et = ["retardo\nSobel", "retardo\nCanny", "C de pin\nSobel", "C de pin\nCanny"]
antes = [S["LIB"]/S["ESQ"], C["LIB"]/C["ESQ"], S["PL"]/S["PE_ESQ"], C["PL"]/C["PE_ESQ"]]
desp  = [S["LIB"]/S["PEX"], C["LIB"]/C["PEX"], S["PL"]/S["PE_PEX"], C["PL"]/C["PE_PEX"]]
y = np.arange(len(et))
ax.barh(y + .19, antes, .34, color=ANTES,   label="celda del ESQUEMÁTICO")
ax.barh(y - .19, desp,  .34, color=DESPUES, label="celda EXTRAÍDA del layout")
for i, (a, d) in enumerate(zip(antes, desp)):
    ax.text(a + .02, i + .19, "%.2f" % a, va="center", fontsize=9, color=ANTES)
    ax.text(d + .02, i - .19, "%.2f" % d, va="center", fontsize=9,
            color=DESPUES, weight="bold")
ax.axvline(1.0, color="k", ls="--", lw=1.1)
ax.set_yticks(y); ax.set_yticklabels(et, fontsize=9)
ax.set_xlim(0, 2.0); ax.set_xlabel("razón  Liberty / SPICE")
ax.set_ylim(len(et) - .5, -.95)          # hueco arriba para la nota y la leyenda
ax.text(.04, -.88, "trazos: 1.00 = acuerdo perfecto", fontsize=8.5, va="top")
ax.set_title("D · La prueba: extraer las 46 celdas\n"
             "del layout con Magic", fontsize=11.5, loc="left")
for s in ("top", "right"): ax.spines[s].set_visible(False)
ax.grid(axis="x", alpha=.25); ax.set_axisbelow(True)
ax.legend(fontsize=8.2, frameon=False, loc="upper right",
          bbox_to_anchor=(1.0, .99), handlelength=1.3)

# --- E · lo que queda ------------------------------------------------------
ax = fig.add_subplot(gs[1, 2])
ax.axis("off")
ax.set_title("E · Lo que cerró y lo que no", fontsize=11.5, loc="left")
ax.text(0, .98,
        "CERRÓ. La capacitancia de pin pasa de\n"
        "1.30 a %.2f: el layout extraído tiene\n"
        "incluso ALGO MÁS que la que la Liberty\n"
        "declara. La hipótesis está medida, no\n"
        "deducida.\n\n"
        "La extracción recupera el 81 %% (Sobel) y\n"
        "el 76 %% (Canny) del término de celda, y\n"
        "la cadena pasa de reproducir el 62 %% al\n"
        "%.0f %% en el Sobel y del 71 %% al %.0f %% en el\n"
        "Canny.\n\n"
        "NO CERRÓ, y se deja escrito:\n\n"
        "  · queda un 5 %% por celda (0.53 ns en\n"
        "    los DOS chips). Magic extrajo las\n"
        "    capacidades pero no las RESISTENCIAS\n"
        "    internas. Probable, no probado.\n\n"
        "  · la realimentación de pendientes se\n"
        "    volvió asimétrica: +1.47 ns en el\n"
        "    Sobel y −0.04 en el Canny. Sin\n"
        "    explicación. Se anota y ya.\n\n"
        "(Y sigue en pie §33.7: el banco sólo vale\n"
        "si reproduce el SENTIDO del flanco —14 de\n"
        "37 bordes coincidían antes de corregirlo,\n"
        "24 después.)"
        % (S["PL"]/S["PE_PEX"], 100*S["E"]/S["STA"], 100*C["E"]/C["STA"]),
        va="top", family="monospace", fontsize=8.4, linespacing=1.38)

fig.suptitle("§33 · Verificación eléctrica del camino crítico de «Pan Hablas en MNIST»\n"
             "ngspice sobre sky130_fd_sc_hd · tt · 1.8 V · 25 °C · la R del cable "
             "aporta el 0.1 %; los parásitos DENTRO de la celda, el 22 %",
             fontsize=13, y=1.0)
plt.savefig("fig_spice_critico.png", dpi=120, bbox_inches="tight")
plt.show()

# --- la cuenta, comprobada -------------------------------------------------
for c in (S, C):
    t = sum(v for _, v in reparto(c))
    print("%-10s  suma del reparto %.3f ns  ·  STA %.3f ns  ·  residuo %+.3f"
          % (c["nom"], t, c["STA"], t - c["STA"]))
