# === Cuaderno 2 · figura 25: no era la histeresis, era el umbral ===
import numpy as np, matplotlib.pyplot as plt
from matplotlib.gridspec import GridSpec

# (umbral, dens_train%, limpio%, dens%, ruido0.6%, dens%, ruido1.0%, dens%)
SOB = np.array([[ 60,49.0,91.04,49.1,84.13,54.9,47.45,70.1],
                [ 80,47.4,92.25,47.5,90.71,49.0,67.16,59.6],
                [110,45.3,86.29,45.4,86.07,45.3,77.72,49.5],
                [140,43.2,86.80,43.3,86.31,43.0,83.44,44.2],
                [170,41.3,87.36,41.4,86.75,40.9,86.54,41.1]])
CAN = np.array([[ 60,60.3,92.63,60.4,69.50,79.7,49.70,93.9],
                [ 80,59.2,92.03,59.4,86.04,69.2,58.41,86.6],
                [110,58.2,92.49,58.3,89.70,62.2,71.73,74.6],
                [140,56.9,91.56,57.1,90.50,58.9,80.22,65.3],
                [170,56.0,92.62,56.2,92.33,57.1,90.21,60.4],
                [200,55.0,92.89,55.1,92.57,55.5,91.57,57.4]])
CS, CC = "#546e7a", "#2e7d32"

fig = plt.figure(figsize=(15.4, 6.4))
gs = GridSpec(1, 3, figure=fig, wspace=.27)

# ═══ A · exactitud con ruido severo ═══
ax = fig.add_subplot(gs[0, 0])
ax.plot(SOB[:,0], SOB[:,2], "o--", color=CS, lw=1.4, ms=5, alpha=.45, label="Sobel · limpio")
ax.plot(CAN[:,0], CAN[:,2], "s--", color=CC, lw=1.4, ms=5, alpha=.45, label="Canny · limpio")
ax.plot(SOB[:,0], SOB[:,6], "o-", color=CS, lw=2.6, ms=8, label="Sobel · ruido severo")
ax.plot(CAN[:,0], CAN[:,6], "s-", color=CC, lw=2.8, ms=8, label="Canny · ruido severo")
ax.set_xlabel("umbral  (thr  ·  thr_hi)", fontsize=9.6)
ax.set_ylabel("exactitud sobre las 10 000  (%)", fontsize=9.6)
ax.grid(alpha=.28); ax.legend(fontsize=8.0, loc="lower right", framealpha=.95)
ax.set_ylim(44, 96)
ax.set_title("A · Con ruido, LOS DOS se derrumban\nsi el umbral es bajo — y los dos se salvan\n"
             "si es alto.  El patrón es el MISMO.", fontsize=10.4, weight="bold", linespacing=1.5, pad=10)

# ═══ B · el mecanismo: la densidad ═══
ax = fig.add_subplot(gs[0, 1])
ax.plot(SOB[:,0], SOB[:,7]-SOB[:,3], "o-", color=CS, lw=2.6, ms=8, label="Sobel")
ax.plot(CAN[:,0], CAN[:,7]-CAN[:,3], "s-", color=CC, lw=2.8, ms=8, label="Canny 1-salto")
ax.axhline(0, color="#78909c", lw=1.0)
ax.set_xlabel("umbral", fontsize=9.6)
ax.set_ylabel("cuántos bordes de MÁS inventa el ruido  (pp)", fontsize=9.6)
ax.grid(alpha=.28); ax.legend(fontsize=8.6)
ax.set_title("B · El mecanismo: el ruido INUNDA\nel mapa cuando la vara está baja.\n"
             "El derrumbe sigue a esta curva.", fontsize=10.4, weight="bold", linespacing=1.5, pad=10)
ax.annotate("94 % del cuadro\nmarcado como borde", xy=(60, CAN[0,7]-CAN[0,3]), xytext=(88, 30),
            fontsize=7.8, color=CC, linespacing=1.4,
            arrowprops=dict(arrowstyle="->", color=CC, lw=1.1))

# ═══ C · lo que comparo la §6 ═══
ax = fig.add_subplot(gs[0, 2])
s6, c6 = SOB[2], CAN[2]           # los dos puntos de la §6: thr=110 en ambos
ax.scatter(SOB[:,3], SOB[:,6], s=95, color=CS, marker="o", zorder=3, label="Sobel")
ax.scatter(CAN[:,3], CAN[:,6], s=95, color=CC, marker="s", zorder=3, label="Canny 1-salto")
for row, c in ((SOB, CS), (CAN, CC)):
    ax.plot(row[:,3], row[:,6], "-", color=c, lw=1.4, alpha=.5, zorder=2)
    for r in row: ax.annotate(f"{int(r[0])}", (r[3], r[6]), textcoords="offset points",
                              xytext=(0,-13), ha="center", fontsize=7.0, color=c)
for p, c in ((s6, CS), (c6, CC)):
    ax.scatter([p[3]], [p[6]], s=330, facecolor="none", edgecolor="#c62828", lw=2.4, zorder=4)
ax.annotate("", xy=(c6[3], c6[6]), xytext=(s6[3], s6[6]),
            arrowprops=dict(arrowstyle="<->", color="#c62828", lw=2.0))
ax.text((s6[3]+c6[3])/2, (s6[6]+c6[6])/2 + 7.5, "lo que comparó la §6:\n"
        "el MISMO número de umbral\nen dos filtros donde no\nsignifica lo mismo",
        ha="center", fontsize=8.0, color="#c62828", weight="bold", linespacing=1.5)
ax.set_xlabel("densidad de bordes al entrenar  (%)", fontsize=9.6)
ax.set_ylabel("exactitud con ruido severo  (%)", fontsize=9.6)
ax.grid(alpha=.28); ax.legend(fontsize=8.6, loc="lower left")
ax.set_title("C · El error de la §6: comparar\nnúmeros de umbral iguales NO es\ncomparar a igual densidad.",
             fontsize=10.4, weight="bold", linespacing=1.5, pad=10)

fig.text(.5, -.045, "Cada filtro en SU mejor punto con ruido severo:  Sobel 86.54 %  ·  Canny 91.57 %  "
         "—  el Canny gana +5.03 pp, lo OPUESTO de lo que dice hoy la §6",
         ha="center", fontsize=10.6, weight="bold", color="#1b5e20")
fig.text(.5, -.085, "(los rangos de densidad ni se solapan: el Canny a CUALQUIER umbral marca más "
         "bordes que el Sobel a cualquiera — por eso el mismo número de umbral no es comparable)",
         ha="center", fontsize=9.0, color="#546e7a", style="italic")
plt.savefig("fig_ruido_umbral.png", dpi=140, bbox_inches="tight")
print("ok")
