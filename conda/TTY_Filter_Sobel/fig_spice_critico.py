# fig_spice_critico.py — la verificación eléctrica del camino crítico de pan_sobel.
# Datos de spice/pan_critico/ (gen_camino.py + correr.py + perfil.py), ngspice sobre
# los subcircuitos de sky130_fd_sc_hd, esquina tt, 1.8 V, 25 °C.
import numpy as np
import matplotlib.pyplot as plt

plt.rcParams["figure.dpi"] = 120

# --- lo medido -------------------------------------------------------------
A, B, C = 4.646, 8.159, 8.178     # puertas · +capacitancia · +flanco real
STA_LOG, CLKQ = 12.230, 0.430
# y el Canny, mismo procedimiento, 36 etapas
Ac, Bc, Cc, STAc = 4.424, 7.552, 7.588, 9.890
FRAME_VGA, FEMTO_US = 6.34e-3, 200e-6
FET_PAN, FET_FEMTO = 116314, 121310

fig = plt.figure(figsize=(15.5, 9))
gs = fig.add_gridspec(2, 3, height_ratios=[1, 1], hspace=.42, wspace=.32)

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
        "en cambio, son 37 celdas y 48 segundos.",
        va="top", family="monospace", fontsize=9.3, linespacing=1.5)

# --- B · el desglose -------------------------------------------------------
ax = fig.add_subplot(gs[0, 1:])
part = [("puertas", A, "#4c72b0"),
        ("carga de cable y fanout", B - A, "#55a868"),
        ("sentido del flanco", C - B, "#ff7f0e"),
        ("sin explicar", STA_LOG - C, "#c44e52")]
izq = 0
for i, (et, v, col) in enumerate(part):
    ax.barh(0, v, .5, left=izq, color=col)
    if v > .4:
        ax.text(izq + v / 2, 0, "%.2f" % v, ha="center", va="center",
                color="w", weight="bold", fontsize=12)
        ax.annotate("%s\n%.0f %%" % (et, 100 * v / STA_LOG),
                    xy=(izq + v / 2, .27), xytext=(izq + v / 2, .52),
                    ha="center", va="bottom", fontsize=9, color=col,
                    arrowprops=dict(arrowstyle="-", color=col, lw=.9))
    else:
        ax.annotate("%s · %.2f ns" % (et, v), xy=(izq + v / 2, -.27),
                    xytext=(izq + v / 2, -.52), ha="center", va="top",
                    fontsize=8.5, color=col,
                    arrowprops=dict(arrowstyle="-", color=col, lw=.9))
    izq += v
ax.barh(-.8, STA_LOG, .42, color="#999999")
ax.text(STA_LOG / 2, -.8, "lo que predice el analizador estático:  %.2f ns" % STA_LOG,
        ha="center", va="center", color="w", weight="bold", fontsize=10.5)
# y el Canny, para comparar
izq = 0
for et, v, col in [("", Ac, "#4c72b0"), ("", Bc - Ac, "#55a868"),
                   ("", Cc - Bc, "#ff7f0e"), ("", STAc - Cc, "#c44e52")]:
    ax.barh(-1.5, v, .42, left=izq, color=col, alpha=.75); izq += v
ax.text(STAc + .15, -1.5, "Canny · 36 celdas · STA %.2f ns · SPICE explica %.0f %%"
        % (STAc, 100 * Cc / STAc), va="center", fontsize=8.5)
ax.set_ylim(-2.0, 1.05); ax.set_yticks([0, -.8, -1.5])
ax.set_yticklabels(["SPICE\nSobel (37)", "STA\nSobel", "Sobel vs\nCANNY"], fontsize=9)
ax.set_xlabel("ns"); ax.set_xlim(0, STA_LOG * 1.02)
ax.set_title("B · De dónde sale cada nanosegundo del camino crítico de pan_sobel\n"
             "SPICE explica %.0f %% resolviendo el transistor; el resto vive en el SPEF"
             % (100 * C / STA_LOG), fontsize=11.5, loc="left")
for s in ("top", "right", "left"): ax.spines[s].set_visible(False)
ax.grid(axis="x", alpha=.25); ax.set_axisbelow(True)

# --- C · lo que NO era ------------------------------------------------------
ax = fig.add_subplot(gs[1, 0])
ax.axis("off")
ax.set_title("C · Dos hipótesis que la medida tumbó", fontsize=11.5, loc="left")
ax.text(0, .95,
        "1ª · «el flanco de entrada idealizado»\n"
        "   Se usó el slew real que declara el\n"
        "   reporte en vez de una rampa de 20 ps.\n"
        "   Aporta 0.019 ns — el 0.2 %. FALSA.\n\n"
        "2ª · «es la capacitancia de las nets\n"
        "      grandes»\n"
        "   correlación desviación–capacitancia\n"
        "            r = −0.15\n"
        "   correlación desviación–fanout\n"
        "            r = −0.06\n"
        "   Ninguna. No es carga. FALSA.\n\n"
        "Queda la RESISTENCIA del cable, que el\n"
        "reporte de texto no publica: vive en el\n"
        "SPEF, y el de pan_* no se conservó.",
        va="top", family="monospace", fontsize=9.3, linespacing=1.5)

# --- D · el hallazgo metodológico ------------------------------------------
ax = fig.add_subplot(gs[1, 1])
ax.bar(["antes", "después"], [14, 24], .5, color=["#c44e52", "#55a868"])
ax.axhline(37, color="k", ls="--", lw=1)
ax.text(.5, 37.6, "37 etapas", ha="center", fontsize=9)
for i, v in enumerate([14, 24]):
    ax.text(i, v / 2, "%d" % v, ha="center", va="center",
            color="w", weight="bold", fontsize=15)
ax.set_ylim(0, 42); ax.set_ylabel("bordes reproducidos")
ax.set_title("D · Sensibilizar no basta\n"
             "hay que reproducir el SENTIDO del flanco", fontsize=11.5, loc="left")
for s in ("top", "right"): ax.spines[s].set_visible(False)

# --- E · qué queda ----------------------------------------------------------
ax = fig.add_subplot(gs[1, 2])
ax.axis("off")
ax.set_title("E · Y una confirmación cruzada", fontsize=11.5, loc="left")
ax.text(0, .95,
        "El STA no exagera: SPICE reproduce\n"
        "%.0f %% (Sobel) y %.0f %% (Canny) de lo que\n"
        "aquél obtuvo sumando tablas. El resto\n"
        "no es discrepancia de modelo: es la R\n"
        "del cable, que no se le dio a SPICE.\n\n"
        "Y algo que no se buscaba. Camino\n"
        "crítico medido en sky130:\n"
        "   Sobel   %.2f ns\n"
        "   Canny   %.2f ns   ← MÁS CORTO\n\n"
        "La §31.4 concluyó lo mismo en IHP y\n"
        "sin CPU: el Canny reparte el trabajo\n"
        "en más etapas, así que su camino es\n"
        "más corto pese a tener más lógica.\n"
        "Dos procesos, dos diseños, lo mismo."
        % (100 * C / STA_LOG, 100 * Cc / STAc, STA_LOG, STAc),
        va="top", family="monospace", fontsize=9.3, linespacing=1.5)

fig.suptitle("§33 · Verificación eléctrica del camino crítico de «Pan Hablas en MNIST»\n"
             "ngspice sobre sky130_fd_sc_hd · esquina tt · 1.8 V · 25 °C · 37 celdas · 48 s de máquina",
             fontsize=13, y=1.0)
plt.savefig("fig_spice_critico.png", dpi=120, bbox_inches="tight")
plt.show()
print("ok")
