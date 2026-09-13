#!/usr/bin/env python3
"""ver_vivo.py — visor EN VIVO de lo que captura la placa, para encuadrar sin adivinar.

Abre una ventana que muestra la ultima ventana de 28x28 recibida, ~5 por segundo, con un
diagnostico de encuadre encima. Se cierra con la 'q' o cerrando la ventana.

  Uso:  python3 ver_vivo.py
"""
import glob, re, sys
import numpy as np
import serial
import matplotlib
matplotlib.use("MacOSX" if sys.platform == "darwin" else "TkAgg")
import matplotlib.pyplot as plt

BAUD = 38400
p = sorted(glob.glob("/dev/cu.usbmodem*"))
if not p:
    raise SystemExit("no encuentro la placa")

fig, (a1, a2) = plt.subplots(1, 2, figsize=(9, 4.6))
im1 = a1.imshow(np.zeros((28, 28)), cmap="gray", vmin=0, vmax=255)
im2 = a2.imshow(np.zeros((28, 28)), cmap="gray", vmin=0, vmax=1)
a1.set_title("lo que ve el clasificador"); a2.set_title("trazo detectado")
for a in (a1, a2): a.axis("off")
txt = fig.text(.5, .03, "", ha="center", fontsize=10, family="monospace")
fig.suptitle("Encuadre en vivo — cerrá la ventana cuando esté listo", fontsize=11)
plt.tight_layout(rect=[0, .06, 1, 1])
plt.show(block=False)

buf = ""
with serial.Serial(p[0], BAUD, timeout=0.2) as s:
    s.reset_input_buffer()
    while plt.fignum_exists(fig.number):
        buf += s.read(4096).decode("ascii", errors="replace")
        if len(buf) > 40000: buf = buf[-20000:]
        m = list(re.finditer(r"IMG\n(.*?)END", buf, re.S))
        if m:
            fil = [l.split() for l in m[-1].group(1).strip().split("\n")]
            fil = [f for f in fil if len(f) == 28 and all(re.fullmatch(r"[0-9a-f]{2}", v) for v in f)]
            if len(fil) == 28:
                A = np.array([[int(v, 16) for v in f] for f in fil], float)
                tinta = A > A.mean() + 25
                ys, xs = np.nonzero(tinta)
                im1.set_data(A); im2.set_data(tinta)
                # CONTRASTE y NITIDEZ primero: sin estructura no tiene sentido hablar de
                # encuadre. La version anterior daba "CENTRADO ✓" sobre una mancha lisa
                # desenfocada, porque solo miraba donde habia brillo.
                contraste = A.std()
                nitidez = np.abs(np.diff(A, axis=0)).mean() + np.abs(np.diff(A, axis=1)).mean()
                d = []
                if contraste < 30:
                    d.append("SIN CONTRASTE: ¿hay un dígito? ¿tinta oscura sobre papel claro?")
                elif nitidez < 6:
                    d.append("DESENFOCADO: alejá el papel (la lente enfoca a ~20-30 cm)")
                elif len(ys) > 20:
                    cy, cx = ys.mean(), xs.mean()
                    ocupa = tinta.mean()
                    if ocupa < .12: d.append("MUY CHICO: acercá o dibujalo más grande")
                    elif ocupa > .45: d.append("MUY GRANDE: alejá")
                    else: d.append("tamaño OK")
                    if abs(cy-13.5) > 3.5: d.append("subí" if cy > 13.5 else "bajá")
                    if abs(cx-13.5) > 3.5: d.append("izquierda" if cx > 13.5 else "derecha")
                    if len(d) == 1: d.append("CENTRADO Y NÍTIDO ✓")
                else:
                    d.append("no separo el trazo del fondo")
                txt.set_text(f"contraste {contraste:5.1f} (>30)  nitidez {nitidez:5.1f} (>6)   "
                             + " · ".join(d))
            buf = buf[m[-1].end():]
        fig.canvas.draw_idle(); fig.canvas.flush_events()
        plt.pause(.01)
print("listo")
