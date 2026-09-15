# fig_gds_pan_canny.py — el GDS de pan_canny abierto en KLayout, con las capas de sky130A.
# Capturas de la VM (asic/pan_sky130/fotos/). Recortadas al lienzo, a media resolución
# y cuantizadas a 64 colores: de 21 MB a 1.3 MB sin perder ninguna etiqueta de pin.
import matplotlib.pyplot as plt, matplotlib.image as mpimg
plt.rcParams["figure.dpi"] = 110
F = "/Users/vic/UN/Tesis/Repository/tty_project_filter/asic/pan_sky130/fotos/"
cap = [("pan_canny_die.png",  "el *die* completo"),
       ("pan_canny_zoom.png", "ampliación: las filas de celdas estándar")]
fig, axes = plt.subplots(1, 2, figsize=(16, 5.6))
for ax, (n, t) in zip(axes, cap):
    ax.imshow(mpimg.imread(F + n)); ax.set_axis_off(); ax.set_title(t, fontsize=10.5)
fig.suptitle("pan_canny en sky130 — el GDS que se enviaría a fabricación\n"
             "938×949 µm · 97 533 instancias · los pines dicen thr_hi_o y thr_lo_o: DOS umbrales",
             fontsize=12.5, y=1.02)
plt.tight_layout(); plt.savefig("fig_gds_pan_canny.png", dpi=110, bbox_inches="tight")
plt.show()
print("ok")
