# === Cuaderno 2 · figura 23: todas las afirmaciones contra el piso de ruido ===
#   sigma = 1.32 pp, medida por validacion cruzada de 10 pliegues (§19).
#   Actualizada tras la §25 y la §26: las dos entradas de la §6 quedan RETRACTADAS
#   porque comparaban dos puntos de operacion distintos, no dos filtros.
import numpy as np, matplotlib.pyplot as plt
from matplotlib.patches import Patch

SIG = 1.32
# (seccion, afirmacion, pp, estado)   estado: ok / no / retract
A = [
 ("§12", "umbral por software vs fijo, Sobel con ruido severo", 27.27, "ok"),
 ("§26", "Canny SIN CPU vs Sobel SIN CPU, con ruido severo",    26.21, "ok"),
 ("§6",  "Canny vs Sobel con luz lateral",                      17.30, "retract"),
 ("§6",  "Canny vs Sobel con ruido de sensor",                  15.90, "retract"),
 ("§9",  "placa: Canny vs Sobel",                                6.90, "ok"),
 ("§25", "el UMBRAL mueve al Sobel",                             5.79, "ok"),
 ("§26", "cada filtro en su mejor punto, con ruido severo",      5.03, "ok"),
 ("§18", "SoC+Canny vs Transitivo",                              2.70, "ok"),
 ("§8",  "Canny vs Sobel en la cámara real",                     2.40, "no"),
 ("§15", "el mejor y el peor de cuatro front-ends",              2.30, "no"),
 ("§3",  "Canny vs Sobel, umbral del Sobel barrido",             1.44, "no"),
 ("§18", "SoC+Canny vs Sobel",                                   1.42, "no"),
 ("§26", "Canny SIN CPU vs Sobel CON CPU, con ruido severo",      1.06, "no"),
 ("§25", "el UMBRAL mueve al Canny",                             0.90, "no"),
 ("§3",  "Canny vs Sobel a igual área",                          0.75, "no"),
 ("§25", "el FILTRO, cada uno en su pico (limpio)",              0.38, "no"),
]
COL = {"ok":"#2e7d32", "no":"#c62828", "retract":"#9e9e9e"}

fig, ax = plt.subplots(figsize=(13.8, 8.2))
ys = np.arange(len(A))[::-1]
for (sec, txt, d, st), yy in zip(A, ys):
    c = COL[st]
    ax.barh(yy, d, color=c, alpha=.42 if st=="retract" else .85, height=.62,
            ec="#37474f", lw=.7, zorder=3, hatch="///" if st=="retract" else None)
    ax.text(-0.45, yy, f"{sec}  {txt}", ha="right", va="center", fontsize=8.6,
            color="#9e9e9e" if st=="retract" else ("#263238" if st=="ok" else "#78909c"))
    et = f"{d:.2f} pp = {d/SIG:.1f} σ"
    if st == "retract": et += "   ⚠ RETRACTADA (§26)"
    ax.text(d+0.45, yy, et, va="center", fontsize=8.2, weight="bold", color=c)

ax.axvline(SIG, color="#ef6c00", lw=1.5, ls=":", zorder=4)
ax.axvline(2*SIG, color="#ef6c00", lw=2.2, ls="--", zorder=4)
ax.text(2*SIG+0.3, len(A)+0.6, "2σ = 2.64 pp  ·  el umbral para afirmar", fontsize=9.4,
        color="#ef6c00", weight="bold", va="center")
ax.text(SIG, -1.05, "σ = 1.32", fontsize=8.0, color="#ef6c00", ha="center")
ax.axvspan(0, 2*SIG, color="#ffebee", alpha=.55, zorder=0)

ax.set_xlim(0, 33); ax.set_ylim(-1.5, len(A)+1.1)
ax.set_yticks([]); ax.set_xlabel("diferencia medida  (puntos porcentuales de exactitud)", fontsize=10)
ax.grid(axis="x", alpha=.28, zorder=1)
for s in ("top","right","left"): ax.spines[s].set_visible(False)
ax.legend(handles=[Patch(fc=COL["ok"], alpha=.85, label="supera 2σ  →  se afirma"),
                   Patch(fc=COL["no"], alpha=.85, label="dentro del ruido  →  NO se afirma"),
                   Patch(fc=COL["retract"], alpha=.42, hatch="///",
                         label="retractada: comparaba dos puntos de operación, no dos filtros")],
          fontsize=8.8, loc="lower right", framealpha=.96)
ax.set_title("TODAS LAS AFIRMACIONES DEL CUADERNO 2, CONTRA EL PISO DE RUIDO\n"
             "σ = 1.32 pp, por validación cruzada de 10 pliegues (§19)  ·  "
             "actualizada tras la §25 y la §26",
             fontsize=12.2, weight="bold", pad=14, linespacing=1.6)
fig.text(.5, -.015, "Lo que NO se pudo demostrar son diferencias entre FILTROS en exactitud.  "
         "Lo que SÍ, diferencias entre CONDICIONES, entre PUNTOS DE OPERACIÓN y entre ARQUITECTURAS.",
         ha="center", fontsize=10.2, weight="bold", color="#1b5e20")
plt.savefig("fig_afirmaciones.png", dpi=140, bbox_inches="tight")
n = {k: sum(1 for a in A if a[3]==k) for k in COL}
print(f"afirma {n['ok']} · no afirma {n['no']} · retractadas {n['retract']}")
