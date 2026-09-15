# === Cuaderno 2 · figura 36: el MISMO reconocedor en FPGA y en ASIC ===
import numpy as np, matplotlib.pyplot as plt
from matplotlib.gridspec import GridSpec

fig = plt.figure(figsize=(14.8, 6.2))
gs = GridSpec(1, 3, figure=fig, width_ratios=[1, 1, 1.15], wspace=.34)

# ═══ A · ocupación relativa ═══
ax = fig.add_subplot(gs[0, 0])
D = [("iCE40UP5K\nSobel", 49, "#546e7a"), ("iCE40UP5K\nCanny", 50, "#90a4ae"),
     ("TT 8×2\nSobel", 77, "#1b5e20"), ("TT 8×2\nCanny", 84, "#66bb6a")]
b = ax.bar(range(4), [d[1] for d in D], color=[d[2] for d in D], ec="#37474f", lw=.9, width=.64)
for i,(n,v,c) in enumerate(D):
    ax.text(i, v+2, f"{v} %", ha="center", fontsize=11, weight="bold", color=c)
ax.axhline(100, color="#c62828", lw=2.0, ls="--")
ax.text(3.45, 102, "lleno", ha="right", fontsize=9, color="#c62828", weight="bold")
ax.set_xticks(range(4)); ax.set_xticklabels([d[0] for d in D], fontsize=8.8, linespacing=1.5)
ax.set_ylabel("ocupación del dispositivo (%)", fontsize=10); ax.set_ylim(0, 112)
ax.grid(axis="y", alpha=.28)
for s in ("top","right"): ax.spines[s].set_visible(False)
ax.set_title("A · El mismo circuito ocupa\nCASI EL DOBLE en el ASIC",
             fontsize=11.2, weight="bold", pad=12, linespacing=1.5)

# ═══ B · dónde van los line-buffers ═══
ax = fig.add_subplot(gs[0, 1]); ax.axis("off")
ax.set_xlim(0,10); ax.set_ylim(0,10)
ax.text(5, 9.4, "los line-buffers", ha="center", fontsize=11.2, weight="bold")
for y,tit,txt,col in ((6.2,"en la iCE40","van a BRAM\n4 bloques (Sobel)\n6 bloques (Canny)\n\nlos BRAM NO se\ncuentan en los 5 280 LC","#1565c0"),
                      (1.2,"en sky130","NO HAY BRAM\nse vuelven flip-flops\n448 bits (Sobel)\n588 bits (Canny)\n\ny pagan area","#c62828")):
    ax.add_patch(plt.Rectangle((.6,y),8.8,2.8,fc=col,alpha=.10,ec=col,lw=1.6))
    ax.text(5,y+2.42,tit,ha="center",fontsize=10.2,weight="bold",color=col)
    ax.text(5,y+1.05,txt,ha="center",va="center",fontsize=8.8,linespacing=1.55,color="#263238")
ax.annotate("", xy=(5,4.0), xytext=(5,5.9), arrowprops=dict(arrowstyle="-|>",color="#37474f",lw=2.2))
ax.text(5.3,4.9,"al pasar a ASIC",fontsize=8.6,color="#37474f",style="italic")
ax.set_title("B · Y ésa es la razón\nde la diferencia", fontsize=11.2, weight="bold",
             pad=12, linespacing=1.5)

# ═══ C · el tercer line-buffer, medido ═══
ax = fig.add_subplot(gs[0, 2])
REC = [("LUT4", 1666, 1705), ("flip-flops", 677, 747), ("BRAM ×100", 400, 600)]
x = np.arange(3); w = .36
ax.bar(x-w/2, [r[1] for r in REC], w, color="#546e7a", ec="#37474f", lw=.7, label="Sobel")
ax.bar(x+w/2, [r[2] for r in REC], w, color="#66bb6a", ec="#37474f", lw=.7, label="Canny 1-salto")
for i,(n,a,bb) in enumerate(REC):
    ax.text(i, max(a,bb)+45, f"+{bb-a}" if n!="BRAM ×100" else "+2 BRAM",
            ha="center", fontsize=9.4, weight="bold", color="#2e7d32")
ax.set_xticks(x); ax.set_xticklabels([r[0] for r in REC], fontsize=9.4)
ax.set_ylabel("recursos en la iCE40UP5K", fontsize=10)
ax.grid(axis="y", alpha=.28); ax.legend(fontsize=9)
for s in ("top","right"): ax.spines[s].set_visible(False)
ax.set_title("C · El Canny cuesta DOS BRAM más\n— es el tercer line-buffer de la §20.4",
             fontsize=11.2, weight="bold", pad=12, linespacing=1.5)

fig.text(.5, -.04, "El 8×2 son MOSAICOS DE SILICIO (1378 × 226 µm ≈ 0.31 mm²), no píxeles.  "
         "La imagen sigue siendo de 28 × 28 en los dos casos.",
         ha="center", fontsize=10.2, weight="bold", color="#263238")
plt.savefig("fig_fpga_vs_asic.png", dpi=140, bbox_inches="tight")
print("ok")
