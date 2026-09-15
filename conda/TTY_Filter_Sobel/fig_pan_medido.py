# === Cuaderno 2 · figura 38: Pan Hablas medido contra lo estimado ===
import numpy as np, matplotlib.pyplot as plt
from matplotlib.gridspec import GridSpec

GEN, SYN, COL, PRED = 13915, 16718, 19949, 27134
TECHO = 18820

fig = plt.figure(figsize=(14.8, 6.0))
gs = GridSpec(1, 2, figure=fig, width_ratios=[1, 1.15], wspace=.28)

# ═══ A · predicho contra medido ═══
ax = fig.add_subplot(gs[0, 0])
V = [("predije\n(×1.95)", PRED, "#c62828"), ("medido\ncolocadas", COL, "#2e7d32"),
     ("medido\nsíntesis", SYN, "#66bb6a"), ("yosys\ngenéricas", GEN, "#90a4ae")]
ax.bar(range(4), [v[1] for v in V], color=[v[2] for v in V], ec="#37474f", lw=.9, width=.62)
for i,(n,v,c) in enumerate(V):
    ax.text(i, v+600, f"{v:,}".replace(",", " "), ha="center", fontsize=10.5, weight="bold", color=c)
ax.annotate("", xy=(1,COL+1700), xytext=(0,PRED+1700),
            arrowprops=dict(arrowstyle="<->", color="#c62828", lw=2.2))
ax.text(.5, PRED+2600, "+36 % de error", ha="center", fontsize=10.6, weight="bold", color="#c62828")
ax.set_xticks(range(4)); ax.set_xticklabels([v[0] for v in V], fontsize=9, linespacing=1.5)
ax.set_ylabel("celdas sky130", fontsize=10.5); ax.set_ylim(0, 32500)
ax.grid(axis="y", alpha=.28)
for s in ("top","right"): ax.spines[s].set_visible(False)
ax.set_title("A · La estimación erró por 36 %\nel factor real es ×1.43, no ×1.95",
             fontsize=11.4, weight="bold", pad=12, linespacing=1.5)

# ═══ B · la cadena de factores ═══
ax = fig.add_subplot(gs[0, 1]); ax.axis("off")
ax.set_xlim(0,10); ax.set_ylim(0,10)
et = [(8.4,"yosys genéricas", f"{GEN:,}".replace(",", " "), "#90a4ae"),
      (5.6,"síntesis (OpenLane)", f"{SYN:,}".replace(",", " "), "#66bb6a"),
      (2.8,"colocadas (tras P&R)", f"{COL:,}".replace(",", " "), "#2e7d32")]
for y,n,v,c in et:
    ax.add_patch(plt.Rectangle((1.2,y-.55),7.6,1.5,fc=c,alpha=.13,ec=c,lw=1.6))
    ax.text(2.0,y+.2,n,fontsize=10,weight="bold",color=c,va="center")
    ax.text(8.3,y+.2,v,fontsize=11.5,weight="bold",color="#263238",ha="right",va="center")
for y0,y1,f,txt in ((8.4,5.6,"×1.20","el mapeo tecnológico"),
                    (5.6,2.8,"×1.19","buffers y sizing para cerrar timing")):
    ax.annotate("", xy=(5,y1+1.0), xytext=(5,y0-.6),
                arrowprops=dict(arrowstyle="-|>",color="#37474f",lw=2.0))
    ax.text(5.35,(y0+y1)/2+.15,f,fontsize=11,weight="bold",color="#c62828")
    ax.text(5.35,(y0+y1)/2-.45,txt,fontsize=8,color="#546e7a",style="italic")
ax.text(5,.9,"genéricas → colocadas  =  ×1.43",ha="center",fontsize=11.6,weight="bold",
        color="#263238",bbox=dict(fc="#fff3e0",ec="#ffb74d",lw=1.3,boxstyle="round,pad=0.5"))
ax.set_title("B · Y se descompone limpio\nel ×1.19 coincide con la §29.4",
             fontsize=11.4, weight="bold", pad=12, linespacing=1.5)

fig.text(.5, -.04, "El chip cierra a 30 ns con parásitos extraídos (spef_wns = 0.00), "
         "LVS 0, DRC 0, XOR 0, en 0.845 mm².",
         ha="center", fontsize=10.4, weight="bold", color="#1b5e20")
plt.savefig("fig_pan_medido.png", dpi=140, bbox_inches="tight")
print("ok")
