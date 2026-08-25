#!/usr/bin/env python3
# tabla_resultados_tt.py — arma la tabla comparativa y la grilla de layouts de los 7
# proyectos de Tiny Tapeout, a partir de lo que bajo bajar_resultados_tt.sh.
import csv, os
import matplotlib.pyplot as plt
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
RES  = os.path.join(AQUI, "resultados_tt")
PROY = [("tt_sobel_vic", "Sobel", "3x2"), ("tt_canny1_vic", "Canny1", "6x2"),
        ("tt_trans_mini_vic", "Transitivo 32x24", "6x2"),
        ("tt_soc_sobel_vic", "SoC + Sobel", "6x2"),
        ("tt_soc_sobel_flash_vic", "SoC + Sobel (flash)", "8x2"),
        ("tt_soc_canny1_vic", "SoC + Canny1", "8x2"),
        ("tt_soc_trans_mini_vic", "SoC + Transitivo 16x12", "8x2")]

def met(repo):
    d = {}
    p = os.path.join(RES, repo, "metrics.csv")
    if not os.path.exists(p): return d
    for fila in csv.reader(open(p)):
        if len(fila) >= 2: d[fila[0]] = fila[1]
    return d

def precheck_ok(repo):
    p = os.path.join(RES, repo, "precheck.md")
    if not os.path.exists(p): return "-"
    t = open(p).read()
    return f"{t.count('✅')}/{t.count('✅') + t.count('❌')}"

filas = []
for repo, etq, tiles in PROY:
    m = met(repo)
    g = lambda k, d="-": m.get(k, d)
    bbox = g("design__die__bbox", "0 0 0 0").split()
    ancho, alto = (float(bbox[2]), float(bbox[3])) if len(bbox) == 4 else (0, 0)
    filas.append(dict(
        etq=etq, tiles=tiles,
        area=f"{ancho:.0f}x{alto:.0f}",
        std=int(float(g("design__instance__count__stdcell", 0))),
        util=100 * float(g("design__instance__utilization", 0)),
        seq=int(float(g("design__instance__count__class:sequential_cell", 0))),
        comb=int(float(g("design__instance__count__class:multi_input_combinational_cell", 0))),
        fill=int(float(g("design__instance__count__class:fill_cell", 0))),
        tap=int(float(g("design__instance__count__class:tap_cell", 0))),
        clkb=int(float(g("design__instance__count__class:clock_buffer", 0))
                 + float(g("design__instance__count__class:clock_inverter", 0))),
        wl=int(float(g("route__wirelength__estimated", 0))),
        pw=1000 * float(g("power__total", 0)),
        pre=precheck_ok(repo)))

cab = f"{'PROYECTO':<24}{'tiles':>6}{'die (um)':>12}{'celdas':>8}{'util%':>7}{'flops':>7}{'comb':>7}{'fill':>7}{'tap':>6}{'clk':>5}{'wire(um)':>10}{'mW':>7}{'precheck':>10}"
print(cab); print("-" * len(cab))
for f in filas:
    print(f"{f['etq']:<24}{f['tiles']:>6}{f['area']:>12}{f['std']:>8}{f['util']:>7.1f}"
          f"{f['seq']:>7}{f['comb']:>7}{f['fill']:>7}{f['tap']:>6}{f['clkb']:>5}"
          f"{f['wl']:>10}{f['pw']:>7.2f}{f['pre']:>10}")

# --- grilla de los 7 layouts ---
fig, ejes = plt.subplots(7, 1, figsize=(13.0, 11.6))
for e, (repo, etq, tiles) in zip(ejes, PROY):
    p = os.path.join(RES, repo, "gds_render.png")
    if os.path.exists(p):
        e.imshow(Image.open(p).convert("RGB"), interpolation="bilinear", aspect="auto")
    m = met(repo)
    n = int(float(m.get("design__instance__count__stdcell", 0)))
    u = 100 * float(m.get("design__instance__utilization", 0))
    e.set_ylabel(f"{etq}\n{tiles}", fontsize=9, fontweight="bold", rotation=0,
                 ha="right", va="center", labelpad=8)
    e.text(0.998, 0.06, f"{n:,} celdas · util {u:.0f}%".replace(",", " "),
           transform=e.transAxes, ha="right", va="bottom", fontsize=8.4,
           color="white", fontweight="bold",
           bbox=dict(boxstyle="round,pad=0.25", fc="#00000099", ec="none"))
    e.set_xticks([]); e.set_yticks([])
fig.suptitle("Los 7 chips de esta tesis en Tiny Tapeout — el layout que sale de la nube\n"
             "(render del GDS firmado por el flujo del shuttle)", fontsize=12.4, fontweight="bold", y=0.995)
plt.tight_layout(rect=[0, 0, 1, 0.965])
plt.savefig(os.path.join(AQUI, "resultados_tt", "grilla_layouts.png"), dpi=125, bbox_inches="tight")
print("\n-> resultados_tt/grilla_layouts.png")
