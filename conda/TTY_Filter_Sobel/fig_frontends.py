# === Cuaderno 2 · figura 17: los cinco front-ends como datapath ===
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch

G="#90a4ae"; GS="#546e7a"; C="#66bb6a"; CS="#1b5e20"; T="#c62828"
CPU="#f9a825"; MEM="#7e57c2"; NEU="#eceff1"

fig,ax=plt.subplots(figsize=(14.6,9.4)); ax.set_xlim(0,100); ax.set_ylim(-6,100); ax.axis("off")

def caja(x,y,w,h,txt,fc=NEU,ec="#37474f",fs=8,tc="#111",lw=1.2,ls="-"):
    ax.add_patch(FancyBboxPatch((x,y),w,h,boxstyle="round,pad=0.35",
                 fc=fc,ec=ec,lw=lw,ls=ls,zorder=2))
    ax.text(x+w/2,y+h/2,txt,ha="center",va="center",fontsize=fs,color=tc,zorder=3,linespacing=1.35)

def flecha(x1,y1,x2,y2,c="#37474f",lw=1.3,ls="-"):
    ax.add_patch(FancyArrowPatch((x1,y1),(x2,y2),arrowstyle="-|>",mutation_scale=11,
                 color=c,lw=lw,ls=ls,zorder=1))

# ---------- el esqueleto comun ----------
ax.text(50,97,"El esqueleto es el mismo para los cinco.  Lo único que cambia es la caja gris.",
        ha="center",fontsize=11.5,weight="bold",color="#111")
y=88.5
caja(1.5,y,11,6.5,"píxeles\nraster 8 bits",fc="#fff",fs=8)
caja(15,y,15,6.5,"F R O N T - E N D\n← acá está la diferencia",fc="#cfd8dc",fs=8.2,lw=2.2)
caja(32.5,y,14,6.5,"histograma\n4 zonas × 8 octantes\n= 32 contadores",fc="#fff",fs=7.6)
caja(49,y,14,6.5,"pirámide → 40 rasgos\nMAC 4 bits\n10 clases × 40",fc="#fff",fs=7.6)
caja(65.5,y,13,6.5,"argmax\n+ criterio NADA",fc="#fff",fs=8)
caja(81,y,12,6.5,"dígito 0–9\nó NADA",fc="#fff",fs=8.2,lw=1.8)
for a,b in [(12.5,15),(30,32.5),(46.5,49),(63,65.5),(78.5,81)]: flecha(a,y+3.2,b,y+3.2)
ax.plot([0.5,99.5],[85.5,85.5],color="#b0bec5",lw=1)

FIL=[
 ("Sobel",G,"36 730 celdas · 91.04 %"),
 ("SoC+Sobel",GS,"+ ~9 000 (CPU) · 91.03 %"),
 ("Canny 1-salto",C,"42 581 celdas · 92.03 %"),
 ("SoC+Canny1",CS,"+ CPU · 92.46 %\nel de la PLACA"),
 ("Transitivo",T,"137 092 celdas · 89.76 %"),
]
ys=[70.5,56.0,41.5,27.0,11.0]

for (nom,col,costo),yy in zip(FIL,ys):
    ax.add_patch(FancyBboxPatch((0.8,yy-1.2),98.4,11.2,boxstyle="round,pad=0.2",
                 fc=col,ec="none",alpha=.07,zorder=0))
    ax.text(1.6,yy+7.4,nom,fontsize=10.4,weight="bold",color=col)
    ax.text(1.6,yy+4.6,costo,fontsize=7.4,color="#455a64",va="top",linespacing=1.5)

    h=5.2; yb=yy+0.4
    caja(16,yb,10.5,h,"Gauss 3×3\n÷16 (shift)",fc="#fff",fs=7.2)
    caja(28.5,yb,11.5,h,"Sobel 3×3\n|Gx|+|Gy|, octante",fc="#fff",fs=7.2)
    flecha(14.5,yb+h/2,16,yb+h/2); flecha(26.5,yb+h/2,28.5,yb+h/2)

    if nom=="Sobel":
        caja(42,yb,13,h,"mag > thr\n(un umbral)",fc=col,fs=7.4,tc="#fff")
        flecha(40,yb+h/2,42,yb+h/2); flecha(55,yb+h/2,60,yb+h/2)
        caja(60,yb,13,h,"borde sí/no",fc="#fff",fs=7.6)
        caja(76.5,yb,22,h,"2 line-buffers · latencia 2(W+2) = 60\nTRANSMITE: decide en el píxel",fc="#eceff1",fs=7.2)
        ax.text(48.5,yb-1.9,"thr = 60 CABLEADO",ha="center",fontsize=7,color=col,weight="bold")

    if nom=="SoC+Sobel":
        caja(42,yb,13,h,"mag > thr\n(un umbral)",fc=col,fs=7.4,tc="#fff")
        flecha(40,yb+h/2,42,yb+h/2); flecha(55,yb+h/2,60,yb+h/2)
        caja(60,yb,13,h,"borde sí/no",fc="#fff",fs=7.6)
        caja(76.5,yb,22,h,"idéntico al Sobel + un RISC-V\nel umbral se volvió SOFTWARE",fc="#fff9c4",fs=7.2)
        caja(41,yb-6.6,15,5.0,"FemtoRV32\n7 instrucciones",fc=CPU,fs=7.4)
        flecha(48.5,yb-1.6,48.5,yb,c=CPU,lw=2.0)
        ax.text(57.5,yb-4.1,"escribe thr=90 en 0x0045",fontsize=7,color="#b28704",va="center")

    if nom=="Canny 1-salto":
        caja(42,yb,13,h,"doble umbral\n2 / 1 / 0",fc=col,fs=7.4,tc="#fff")
        caja(57.5,yb,15.5,h,"histéresis 1 salto\n3×3: ¿toca un fuerte?",fc=col,fs=7.2,tc="#fff")
        flecha(40,yb+h/2,42,yb+h/2); flecha(55,yb+h/2,57.5,yb+h/2)
        caja(76.5,yb,22,h,"3 line-buffers · latencia 3(W+2) = 90\nTRANSMITE igual: un salto es local",fc="#eceff1",fs=7.2)
        ax.text(48.5,yb-1.9,"hi=110 lo=40 CABLEADOS",ha="center",fontsize=7,color=col,weight="bold")

    if nom=="SoC+Canny1":
        caja(42,yb,13,h,"doble umbral\n2 / 1 / 0",fc=col,fs=7.4,tc="#fff")
        caja(57.5,yb,15.5,h,"histéresis 1 salto\n3×3: ¿toca un fuerte?",fc=col,fs=7.2,tc="#fff")
        flecha(40,yb+h/2,42,yb+h/2); flecha(55,yb+h/2,57.5,yb+h/2)
        caja(76.5,yb,22,h,"los DOS umbrales por software\n9/10 en silicio · gana AUC y Brier",fc="#fff9c4",fs=7.2,lw=1.8)
        caja(41,yb-6.6,15,5.0,"FemtoRV32\nmismo ROM",fc=CPU,fs=7.4)
        flecha(48.5,yb-1.6,48.5,yb,c=CPU,lw=2.0)
        ax.text(57.5,yb-4.1,"un word: {thr_hi=90, thr_lo=32}",fontsize=7,color="#b28704",va="center")

    if nom=="Transitivo":
        caja(42,yb,13,h,"doble umbral\n2 / 1 / 0",fc=col,fs=7.4,tc="#fff")
        flecha(40,yb+h/2,42,yb+h/2); flecha(55,yb+h/2,57.5,yb+h/2)
        caja(57.5,yb,15.5,h,"MARCO COMPLETO\nen BRAM  H×W",fc=MEM,fs=7.2,tc="#fff")
        caja(76.5,yb,22,h,"reconstrucción morfológica:\nbarre hasta PUNTO FIJO",fc="#ffcdd2",fs=7.2,lw=1.8)
        ax.add_patch(FancyArrowPatch((87.5,yb-0.3),(65.2,yb-0.3),arrowstyle="-|>",
                     mutation_scale=11,color=T,lw=1.8,
                     connectionstyle="arc3,rad=-0.40",zorder=4))
        ax.text(76.0,yb-5.4,"while (cambió) repetir  ←  NO TRANSMITE",ha="center",fontsize=8.0,
                color=T,weight="bold")

plt.savefig("fig_frontends.png",dpi=140,bbox_inches="tight")
print("ok")
