# === Parte 188: el Canny 1-salto como front-end, y el ruido que decide ===
# Cada barra es el promedio de CINCO entrenamientos con semillas distintas; la barra de
# error es una sigma. Sin repetir el experimento no hay sigma, y sin sigma no hay conclusion.
import numpy as np
import matplotlib.pyplot as plt

d = np.load("../../clasificador_mnist/canny1_semillas.npz")
nom = ["Sobel thr=110  24x24", "Sobel thr=110  22x22*",
       "Canny1 hi=110 lo=40 22x22", "Canny1 hi=75 lo=25 22x22"]
et = ["Sobel\n24×24", "Sobel recortado\n22×22", "Canny1\nhi=110 lo=40", "Canny1\nhi=75 lo=25"]
col = ["#90a4ae", "#546e7a", "#2e7d32", "#66bb6a"]
q  = np.array([d[n][2] for n in nom]) * 100
sq = np.array([d[n][3] for n in nom]) * 100
f  = np.array([d[n][0] for n in nom]) * 100

fig, (a1, a2) = plt.subplots(1, 2, figsize=(12.6, 4.8))

x = np.arange(4)
a1.bar(x, q, yerr=sq, capsize=6, color=col, ec="#333", lw=.9, zorder=3)
a1.plot(x, f, "o--", c="#c62828", ms=7, zorder=4, label="float (sin cuantizar)")
for i in range(4):
    a1.text(i, q[i] - sq[i] - .55, f"{q[i]:.2f}\n±{sq[i]:.2f}", ha="center", va="top",
            fontsize=8.2, color="w", weight="bold")
    a1.text(i, f[i] + .18, f"{f[i]:.2f}", ha="center", fontsize=8, color="#c62828")
a1.set_xticks(x); a1.set_xticklabels(et, fontsize=8.5)
a1.set_ylim(88, 95.6); a1.set_ylabel("precisión sobre las 10 000 de test  %")
a1.set_title("A · Cuatro front-ends, cinco semillas cada uno\n"
             "barras = 4 bits (el hardware) · línea roja = float", fontsize=10.5)
a1.grid(axis="y", alpha=.3, zorder=0); a1.legend(fontsize=8, loc="upper left")
a1.text(1.5, 94.9, "en float son todos IGUALES → los rasgos tienen la misma información",
        ha="center", fontsize=7.8, style="italic", color="#c62828")

comp = [("Canny1 afinado\nvs Sobel SIN afinar\n(la comparación tramposa)", 3.20, None, "#c62828"),
        ("…con el umbral del\nSobel también barrido", 1.44, 1.03, "#ef6c00"),
        ("…y a IGUAL área\n(22×22 vs 22×22)", 0.75, 0.86, "#2e7d32")]
y = np.arange(3)[::-1]
a2.axvspan(-1.0, 0, color="#eceff1", zorder=0)
for i, (t, v, s, c) in enumerate(comp):
    yy = y[i]
    if s:
        a2.axhspan(yy-.34, yy+.34, xmin=0, xmax=1, color="none")
        a2.errorbar(v, yy, xerr=2*s, fmt="o", color=c, ms=11, capsize=7, lw=2.4, zorder=4)
        a2.text(v, yy+.30, f"{v:+.2f} %  ±2σ = {2*s:.2f}", ha="center", fontsize=8.6,
                color=c, weight="bold")
        if v < 2*s:
            a2.text(v, yy-.34, "la barra cruza el cero → NO se puede afirmar que gane",
                    ha="center", va="top", fontsize=7.6, style="italic", color=c)
    else:
        a2.plot(v, yy, "o", color=c, ms=11, zorder=4)
        a2.text(v, yy+.30, f"{v:+.2f} %", ha="center", fontsize=8.6, color=c, weight="bold")
        a2.text(v, yy-.34, "una sola medición:\nno tiene barra de error", ha="center",
                va="top", fontsize=7.6, style="italic", color=c)
    a2.text(-2.55, yy, t, ha="left", va="center", fontsize=8.3)
a2.axvline(0, c="#333", lw=1.4, zorder=3)
a2.text(.06, 2.66, "cero = ningún efecto", fontsize=7.6, color="#333")
a2.set_yticks([]); a2.set_xlim(-2.6, 4.0); a2.set_ylim(-.8, 2.9)
a2.set_xlabel("ventaja del Canny 1-salto sobre el Sobel  (puntos porcentuales, 4 bits)")
a2.set_title("B · Cómo se evapora una mejora cuando se agregan los controles",
             fontsize=10.5)
a2.grid(axis="x", alpha=.3, zorder=0)
plt.tight_layout()
plt.savefig("../../clasificador_mnist/fig_p188_canny.png", dpi=150)
plt.show()
