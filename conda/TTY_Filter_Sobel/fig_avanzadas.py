# === Cuaderno 2 · figura 16: AUC/ROC, Brier, y el box-plot de 10 pliegues ===
import numpy as np, matplotlib.pyplot as plt
B="../../clasificador_mnist/"
d=np.load(B+"metricas_avanzadas.npz"); cv=np.load(B+"cv_exactitud.npz")
F=["Sobel","SoC+Sobel","Canny1","SoC+Canny1","Transitivo"]
COL={"Sobel":"#90a4ae","SoC+Sobel":"#546e7a","Canny1":"#66bb6a",
     "SoC+Canny1":"#1b5e20","Transitivo":"#c62828"}
res={n:d[f"{n}_res"] for n in F}      # auc, brier, r2

fig=plt.figure(figsize=(13.6,8.4)); gs=fig.add_gridspec(2,3,hspace=.34,wspace=.30)

# A · ROC uno-contra-el-resto (macro)
a=fig.add_subplot(gs[0,0])
for n in F:
    fpr,tpr=d[f"{n}_roc"]
    a.plot(fpr,tpr,c=COL[n],lw=1.8,label=f"{n}  {res[n][0]:.4f}")
a.plot([0,1],[0,1],"--",c="#bbb",lw=1)
a.set_xlim(0,.12); a.set_ylim(.86,1.005)
a.set_xlabel("tasa de falsos positivos"); a.set_ylabel("tasa de verdaderos positivos")
a.legend(fontsize=7,loc="lower right",title="AUC macro",title_fontsize=7.5)
a.grid(alpha=.3); a.set_title("A · ROC uno-contra-el-resto\n(ampliado en la esquina útil)",fontsize=10.5)

# B · AUC
b=fig.add_subplot(gs[0,1])
v=[res[n][0] for n in F]
bars=b.bar(range(5),v,color=[COL[n] for n in F],ec="#333")
for r,x in zip(bars,v): b.text(r.get_x()+r.get_width()/2,x+.00005,f"{x:.4f}",ha="center",fontsize=8)
b.set_xticks(range(5)); b.set_xticklabels(F,fontsize=7,rotation=20)
b.set_ylim(.9930,.9968); b.set_ylabel("AUC macro"); b.grid(axis="y",alpha=.3)
b.set_title("B · AUC: el transitivo ORDENA bien\n(pasa al SoC+Sobel)",fontsize=10.5)

# C · Brier
c=fig.add_subplot(gs[0,2])
v=[res[n][1] for n in F]
bars=c.bar(range(5),v,color=[COL[n] for n in F],ec="#333")
for r,x in zip(bars,v): c.text(r.get_x()+r.get_width()/2,x+.002,f"{x:.4f}",ha="center",fontsize=8)
c.set_xticks(range(5)); c.set_xticklabels(F,fontsize=7,rotation=20)
c.set_ylabel("Brier (menor = mejor)"); c.grid(axis="y",alpha=.3)
c.set_title("C · Brier: el transitivo está\nMAL CALIBRADO",fontsize=10.5)

# D · el box-plot que pidio: R2 por pliegue
dd=fig.add_subplot(gs[1,0])
datos=[d[f"{n}_cv"] for n in F]
bp=dd.boxplot(datos,labels=F,patch_artist=True,medianprops=dict(color="#111",lw=2))
for p,n in zip(bp["boxes"],F): p.set_facecolor(COL[n]); p.set_alpha(.8)
dd.set_ylabel("R² (Brier skill) por pliegue"); dd.grid(axis="y",alpha=.3)
dd.tick_params(axis="x",labelsize=7,rotation=20)
dd.set_title("D · R² · validación cruzada 10 pliegues\n(la línea es la mediana)",fontsize=10.5)

# E · el mismo box-plot sobre EXACTITUD, que es lo comparable
e=fig.add_subplot(gs[1,1])
datos=[cv[n] for n in F]
bp=e.boxplot(datos,labels=F,patch_artist=True,medianprops=dict(color="#111",lw=2))
for p,n in zip(bp["boxes"],F): p.set_facecolor(COL[n]); p.set_alpha(.8)
e.set_ylabel("exactitud por pliegue"); e.grid(axis="y",alpha=.3)
e.tick_params(axis="x",labelsize=7,rotation=20)
e.set_title("E · EXACTITUD · 10 pliegues\nlas cuatro primeras se SOLAPAN",fontsize=10.5)

# F · la sigma vieja contra la nueva
f=fig.add_subplot(gs[1,2])
s_v,s_n=0.74,np.mean([cv[n].std() for n in F])*100
f.bar([0,1],[s_v,s_n],color=["#90a4ae","#c62828"],ec="#333",width=.5)
f.text(0,s_v+.04,f"{s_v:.2f} pp",ha="center",fontsize=10)
f.text(1,s_n+.04,f"{s_n:.2f} pp",ha="center",fontsize=10,weight="bold")
f.set_xticks([0,1]); f.set_xticklabels(["5 semillas\n20 000","10 pliegues\n60 000"],fontsize=8.5)
f.set_ylabel("σ de la exactitud  (pp)"); f.set_ylim(0,1.8); f.grid(axis="y",alpha=.3)
f.set_title(f"F · El ruido real es {s_n/s_v:.1f}× mayor\nde lo que suponía el cuaderno",fontsize=10.5)
plt.savefig("fig_avanzadas.png",dpi=140,bbox_inches="tight")
plt.show()

print(f"{'front-end':<12}{'AUC':>9}{'Brier':>9}{'R2':>9}{'CV exactitud':>15}")
for n in F:
    print(f"{n:<12}{res[n][0]:>9.4f}{res[n][1]:>9.4f}{res[n][2]:>9.4f}"
          f"{np.median(cv[n]):>10.4f} ±{cv[n].std():.4f}")
print(f"\nsigma: 0.74 pp (5 semillas) -> {np.mean([cv[n].std() for n in F])*100:.2f} pp (10 pliegues)")
