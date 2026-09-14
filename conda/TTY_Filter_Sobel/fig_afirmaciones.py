# === Cuaderno 2 · figura 23: todas las afirmaciones contra el piso de ruido ===
#   sigma = 1.32 pp, medida por validacion cruzada de 10 pliegues (§19).
import numpy as np, matplotlib.pyplot as plt
from matplotlib.patches import Patch

SIG = 1.32
A = [  # (seccion, afirmacion, diferencia en pp, nota)
 ("§12", "umbral por software vs fijo, con ruido severo",  27.27, ""),
 ("§6",  "Canny vs Sobel con luz lateral (simulado)",      17.30, ""),
 ("§6",  "Canny vs Sobel con ruido de sensor (simulado)",  15.90, "el Canny PIERDE"),
 ("§9",  "placa: Canny vs Sobel",                           6.90, ""),
 ("§18", "SoC+Canny vs Transitivo",                         2.70, ""),
 ("§8",  "Canny vs Sobel en la cámara real",                2.40, "un solo par válido"),
 ("§15", "el mejor y el peor de cuatro front-ends",         2.30, ""),
 ("§3",  "Canny vs Sobel, umbral del Sobel barrido",        1.44, ""),
 ("§18", "SoC+Canny vs Sobel",                              1.42, ""),
 ("§3",  "Canny vs Sobel a igual área",                     0.75, ""),
]
fig, ax = plt.subplots(figsize=(13.4, 6.6))
ys = np.arange(len(A))[::-1]
for (sec, txt, d, nota), yy in zip(A, ys):
    supera = d > 2*SIG
    col = "#2e7d32" if supera else "#c62828"
    ax.barh(yy, d, color=col, alpha=.85, height=.62, ec="#37474f", lw=.7, zorder=3)
    ax.text(-0.45, yy, f"{sec}  {txt}", ha="right", va="center", fontsize=9.0,
            color="#263238" if supera else "#78909c")
    et = f"{d:.2f} pp  =  {d/SIG:.1f} σ"
    if nota: et += f"   ({nota})"
    ax.text(d+0.45, yy, et, va="center", fontsize=8.4, weight="bold", color=col)

ax.axvline(SIG,   color="#ef6c00", lw=1.5, ls=":",  zorder=4)
ax.axvline(2*SIG, color="#ef6c00", lw=2.2, ls="--", zorder=4)
ax.text(2*SIG+0.3, len(A)+0.85, "2σ = 2.64 pp  ·  el umbral para afirmar", fontsize=9.4,
        color="#ef6c00", weight="bold", va="center")
ax.text(SIG, -0.92, "σ = 1.32", fontsize=8.0, color="#ef6c00", ha="center")
ax.axvspan(0, 2*SIG, color="#ffebee", alpha=.55, zorder=0)

ax.set_xlim(0, 31); ax.set_ylim(-1.3, len(A)+1.3)
ax.set_yticks([]); ax.set_xlabel("diferencia medida  (puntos porcentuales de exactitud)", fontsize=10)
ax.grid(axis="x", alpha=.28, zorder=1)
for s in ("top", "right", "left"): ax.spines[s].set_visible(False)
ax.legend(handles=[Patch(fc="#2e7d32", alpha=.85, label="supera 2σ  →  se afirma"),
                   Patch(fc="#c62828", alpha=.85, label="dentro del ruido  →  NO se afirma")],
          fontsize=9.0, loc="lower right", framealpha=.95)
ax.set_title("TODAS LAS AFIRMACIONES DEL CUADERNO 2, CONTRA EL PISO DE RUIDO\n"
             "σ = 1.32 pp, medida por validación cruzada de 10 pliegues sobre las 60 000 (§19)",
             fontsize=12.4, weight="bold", pad=14, linespacing=1.6)
fig.text(.5, -.015, "las cuatro de abajo son las comparaciones Canny-vs-Sobel en exactitud: "
         "NINGUNA alcanza · las de arriba son condiciones de operación y decisiones de "
         "arquitectura, y todas alcanzan con holgura",
         ha="center", fontsize=9.0, color="#546e7a", style="italic")
plt.savefig("fig_afirmaciones.png", dpi=140, bbox_inches="tight")
print(f"supera 2σ: {sum(1 for a in A if a[2]>2*SIG)}/{len(A)}")
