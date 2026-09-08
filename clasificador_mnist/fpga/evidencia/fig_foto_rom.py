# === Parte 184 (ter): la placa que produjo la captura, encendida ===
# El LED verde es cfg_done: el bitstream mnist_uart.bin cargado y corriendo.
# (Vale recordar la leccion del .pcf: con led_r/led_g cruzados este mismo LED
#  encendia rojo con una configuracion perfectamente correcta.)
import matplotlib.pyplot as plt, matplotlib.image as mpimg
B = "../../clasificador_mnist/fpga/evidencia/"
fig, ax = plt.subplots(1, 2, figsize=(8.4, 7.4))
for a, f, t in zip(ax, ["foto_rom_web_a.jpg", "foto_rom_web_b.jpg"],
                   ["iCESugar v1.5 — LED verde = cfg_done",
                    "el mismo montaje, con el cableado del PMOD"]):
    a.imshow(mpimg.imread(B + f)); a.axis("off"); a.set_title(t, fontsize=9)
fig.suptitle("La iCE40UP5K corriendo mnist_uart.bin: los 10 dígitos de MNIST\n"
             "viven en el bitstream y el resultado sale por el UART del USB-C",
             fontsize=10.5, y=0.985)
plt.tight_layout(rect=[0, 0, 1, 0.955])
plt.savefig(B + "fig_foto_rom.png", dpi=85)
plt.show()
