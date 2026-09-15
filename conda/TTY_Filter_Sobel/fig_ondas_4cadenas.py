# === Cuaderno 2 · figura 28: las cuatro cadenas en el tiempo, y el primer cuadro que miente ===
#   Dibujado desde los .vcd que produjo iverilog en la VM Ubuntu.
import pickle, numpy as np, matplotlib.pyplot as plt

D = "/Users/vic/utm-share/sim_cadenas_mnist/out"
CAD = [("sobel","Sobel","#546e7a"), ("soc_sobel","SoC + Sobel","#37474f"),
       ("canny1","Canny 1-salto","#66bb6a"), ("soc_canny1","SoC + Canny1","#1b5e20")]
MS = 1e9

fig, ax = plt.subplots(figsize=(15.0, 7.4))
for k,(nom,tit,col) in enumerate(CAD):
    TR,TF = pickle.load(open(f"{D}/ondas_{nom}.pkl","rb"))
    y = (len(CAD)-1-k)*2.6
    ev = lambda s,val=1: [t for t,v in TR.get(s,[]) if v==val]

    ax.axhline(y, color="#eceff1", lw=.8, zorder=0)
    ax.text(-1.15, y+.75, tit, ha="right", va="center", fontsize=11, weight="bold", color=col)

    # los tres cuadros de camara
    for i,t in enumerate(ev("w_fin")):
        ax.plot([t/MS]*2, [y, y+1.5], color="#26a69a", lw=2.4, zorder=3)
        ax.text(t/MS, y+1.62, f"cuadro {i+1}", ha="center", fontsize=7.2, color="#00796b")

    # el veredicto en cada `done`
    dg = [(t,v) for t,v in TR.get("digito",[]) if v is not None]
    vl = [(t,v) for t,v in TR.get("valido",[]) if v is not None]
    for i,t in enumerate(ev("done")):
        d  = ([v for tt,v in dg if tt<=t] or [0])[-1]
        va = ([v for tt,v in vl if tt<=t] or [0])[-1]
        txt = str(d) if va else "NADA"
        ok  = (txt == "3")
        ax.plot([t/MS]*2, [y, y+1.5], color="#c62828", lw=2.4, zorder=3)
        ax.add_patch(plt.Rectangle((t/MS+.12, y+.15), 1.55, 1.15, fc="#2e7d32" if ok else "#c62828",
                     alpha=.9, ec="#37474f", lw=.7, zorder=4))
        ax.text(t/MS+.90, y+.72, txt, ha="center", va="center", fontsize=11, color="#fff",
                weight="bold", zorder=5)
        lat = (t - ev("w_fin")[i])/1e6
        ax.annotate("", xy=(t/MS, y+.05), xytext=(ev("w_fin")[i]/MS, y+.05),
                    arrowprops=dict(arrowstyle="<->", color="#90a4ae", lw=1.2))
        ax.text((t+ev("w_fin")[i])/2/MS, y-.30, f"{lat:.1f} µs", ha="center", fontsize=7.4,
                color="#607d8b")

ax.set_xlim(-3.1, 20.4); ax.set_ylim(-2.6, len(CAD)*2.6+.6)
ax.set_yticks([]); ax.set_xlabel("tiempo  (ms)", fontsize=10.5)
ax.tick_params(labelsize=9)
for s in ("top","right","left"): ax.spines[s].set_visible(False)
ax.set_title("LAS CUATRO CADENAS EN EL TIEMPO  ·  escena del dígito 3  ·  "
             "VCD de iverilog en la VM Ubuntu\n"
             "verde = w_fin (cuadro de cámara cerrado)   ·   rojo = done (veredicto)",
             fontsize=12.2, weight="bold", pad=14, linespacing=1.6)

ax.add_patch(plt.Rectangle((-2.9, -2.45), 22.9, 1.35, fc="#fff3e0", ec="#ffb74d", lw=1.1, zorder=2))
ax.text(8.5, -1.78, "EL PRIMER CUADRO MIENTE: los line-buffers arrancan vacíos.  El Sobel acierta igual "
        "desde el cuadro 1;\nel Canny contesta 5 y recién en el cuadro 2 SE RETRACTA — tiene TRES "
        "line-buffers, más estado que purgar.",
        ha="center", va="center", fontsize=9.0, color="#5d4037", zorder=3, linespacing=1.5)
plt.tight_layout()
plt.savefig("fig_ondas_4cadenas.png", dpi=140, bbox_inches="tight")
print("ok")
