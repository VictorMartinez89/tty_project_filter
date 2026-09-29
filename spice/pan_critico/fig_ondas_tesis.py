# Las ondas del camino crítico TAL COMO LAS DIBUJA NGSPICE.
# El gráfico no es de matplotlib: lo produjo el simulador con `hardcopy` en SVG
# (spice/pan_critico/ondas_ngspice.py). Aquí sólo se muestran las imágenes.
import matplotlib.pyplot as plt, matplotlib.image as mpimg
plt.rcParams["figure.dpi"] = 110
D = "/Users/vic/UN/Tesis/Repository/tty_project_filter/spice/pan_critico/"
cap = [("pan_sobel_ng.png", "pan_sobel \u00b7 37 etapas \u00b7 el \u00faltimo nodo cruza a ~8.2 ns"),
       ("pan_canny_ng.png", "pan_canny \u00b7 36 etapas \u00b7 el \u00faltimo nodo cruza a ~7.6 ns")]
fig, axes = plt.subplots(2, 1, figsize=(13, 16))
for ax, (n, t) in zip(axes, cap):
    ax.imshow(mpimg.imread(D + n)); ax.set_axis_off(); ax.set_title(t, fontsize=11.5)
plt.tight_layout(); plt.savefig("fig_5_9_spice_ondas.png", dpi=110, bbox_inches="tight")

print("ok")
