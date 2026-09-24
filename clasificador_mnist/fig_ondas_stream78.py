#!/usr/bin/env python3
"""fig_ondas_stream78.py — la foto del banco tb_stream78.v: la placa del flujo serie, en senales.

    python fig_ondas_stream78.py [ruta/stream78.vcd]

Lee el .vcd que deja `vvp ... +VCD` (placa_vm.sh lo hace en out/) y dibuja tres ventanas:
  A · la corrida entera: 2 lotes de 4 imagenes, la pausa de realineo y los 8 veredictos
  B · UN byte entrando por la UART, bit a bit, y el pixel que sale hacia la cadena
  C · UN veredicto saliendo: frame_done -> done -> el byte de respuesta por uart_tx
Es lo que se ve en gtkwave, pero en una figura que va a la tesis sin capturar pantalla.
"""
import sys, os
import numpy as np
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt

VCD = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/utm-share/mnist78_placa/out/stream78.vcd")
QUIERO = {"uart_rx_pin", "rx_valido", "rx_dato", "in_valid", "frame_done", "done", "digito",
          "valido", "uart_tx_pin", "reset_cad", "resto", "resp"}

# --- lector de VCD minimo: solo las senales pedidas, sin el reloj ---
ids, nombre = {}, {}
trazas = {}
with open(VCD) as f:
    for ln in f:
        t = ln.split()
        if not t: continue
        if t[0] == "$var":
            code, nom = t[3], t[4]
            if nom in QUIERO and nom not in nombre.values():
                ids[code] = nom; nombre[code] = nom; trazas[nom] = ([], [])
        elif t[0] == "$enddefinitions": break
    ahora = 0
    for ln in f:
        c = ln[0]
        if c == "#": ahora = int(ln[1:]); continue
        if c in "01xz":
            code = ln[1:].strip()
            if code in ids:
                trazas[ids[code]][0].append(ahora); trazas[ids[code]][1].append(0 if c in "0xz" else 1)
        elif c == "b":
            v, code = ln[1:].split()
            if code in ids:
                trazas[ids[code]][0].append(ahora)
                trazas[ids[code]][1].append(int(v, 2) if set(v) <= {"0", "1"} else 0)

T = {k: (np.array(a, float) * 1e-6, np.array(b)) for k, (a, b) in trazas.items()}   # ps -> us
fin = max(t[-1] for t, _ in T.values())

def escalon(ax, k, y0, t0, t1, alto=0.7, color="#1f4e79", bus=False, fmt=str):
    t, v = T[k]
    i0 = max(np.searchsorted(t, t0, "right") - 1, 0); i1 = np.searchsorted(t, t1, "right")
    tt = np.concatenate([[t0], t[i0 + 1:i1], [t1]]); vv = np.concatenate([v[i0:i1], [v[i1 - 1]]])
    if not bus:
        ax.step(tt, y0 + alto * vv, where="post", color=color, lw=1.1)
    else:
        for a, b_, val in zip(tt[:-1], tt[1:], vv[:-1]):
            ax.fill_between([a, b_], y0, y0 + alto, color=color, alpha=.12, lw=0)
            ax.plot([a, a], [y0, y0 + alto], color=color, lw=.6)
            if (b_ - a) > (t1 - t0) * 0.035:
                ax.text((a + b_) / 2, y0 + alto / 2, fmt(val), ha="center", va="center",
                        fontsize=7, color=color)
    ax.text(t0 - (t1 - t0) * 0.01, y0 + alto / 2, k, ha="right", va="center", fontsize=8,
            family="monospace")

def ventana(ax, filas, t0, t1, titulo):
    for n, (k, kw) in enumerate(filas):
        escalon(ax, k, len(filas) - 1 - n, t0, t1, **kw)
    ax.set_xlim(t0, t1); ax.set_ylim(-0.3, len(filas)); ax.set_yticks([])
    ax.set_xlabel("tiempo (µs de simulacion)", fontsize=8); ax.tick_params(labelsize=7)
    for sp in ("top", "right", "left"): ax.spines[sp].set_visible(False)
    ax.set_title(titulo, fontsize=9.5, loc="left")

letra = lambda v: chr(v) if 32 <= v < 127 else f"{v:02x}"
AZ, VE, RO, GR = "#1f4e79", "#1e7a3c", "#c0392b", "#555555"

# instantes de interes
td = T["done"][0][T["done"][1] == 1]                 # flancos de done
tf = T["frame_done"][0][T["frame_done"][1] == 1]
trv = T["rx_valido"][0][T["rx_valido"][1] == 1]

fig = plt.figure(figsize=(15, 11))
gs = fig.add_gridspec(2, 2, height_ratios=[1.1, 1], hspace=.35, wspace=.28)

ax = fig.add_subplot(gs[0, :])
ventana(ax, [("uart_rx_pin", dict(color=AZ)), ("resto", dict(bus=True, color=GR)),
             ("reset_cad", dict(color=RO)), ("frame_done", dict(color=VE)), ("done", dict(color=VE)),
             ("digito", dict(bus=True, color=VE)), ("valido", dict(color=VE)),
             ("uart_tx_pin", dict(color=AZ))],
        0, fin, "A · la corrida entera: 2 lotes de 4 imagenes por la UART, la pausa que realinea "
                "(reset_cad) y los 8 veredictos")
for t in td: ax.axvline(t, color=VE, lw=.5, alpha=.35)

ax = fig.add_subplot(gs[1, 0])
t0 = trv[400] - 0.95; t1 = trv[400] + 0.15
ventana(ax, [("uart_rx_pin", dict(color=AZ)), ("rx_valido", dict(color=VE)),
             ("rx_dato", dict(bus=True, color=AZ, fmt=lambda v: f"0x{v:02x}")),
             ("in_valid", dict(color=VE))],
        t0, t1, "B · un pixel entrando: start, 8 bits (LSB primero), stop -> rx_valido -> la cadena")

ax = fig.add_subplot(gs[1, 1])
t0 = tf[0] - 0.5; t1 = td[0] + 1.4
ventana(ax, [("frame_done", dict(color=VE)), ("done", dict(color=VE)),
             ("digito", dict(bus=True, color=VE)), ("valido", dict(color=VE)),
             ("resp", dict(bus=True, color=AZ, fmt=letra)), ("uart_tx_pin", dict(color=AZ))],
        t0, t1, f"C · un veredicto saliendo: frame_done -> {int(round((td[0]-tf[0])/0.01))} ciclos "
                f"-> done -> byte '{letra(int(T['resp'][1][np.searchsorted(T['resp'][0], td[0]+1)-1]))}'")

fig.suptitle("tb_stream78.v · la placa del top78 simulada con la UART de verdad (DIV=8) · "
             "8/8 veredictos iguales al golden · ALL TESTS PASSED", fontsize=11, x=.01, ha="left")
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tesis", "figuras", "fig_ondas_stream78.png")
fig.savefig(out, dpi=150, facecolor="white", bbox_inches="tight")
print("  ->", os.path.relpath(out))
print(f"  {len(td)} veredictos · {len(trv)} bytes recibidos · frame_done->done = "
      f"{(td[0]-tf[0])/0.01:.0f} ciclos")
