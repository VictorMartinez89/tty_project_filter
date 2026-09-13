# === Cuaderno 2 · figura 9: qué compra el CPU — el umbral adaptativo ===
# El SoC no cambia el mapa de bordes (45 pares identicos, ya medido). Lo unico que agrega es
# escribir el umbral en tiempo de ejecucion. Esto mide cuanto vale eso.
import numpy as np, matplotlib.pyplot as plt
d = np.load("../../clasificador_mnist/soc_umbral.npz", allow_pickle=True)
R = d["res"]
modos = ["gradiente", "contraste", "ruido"]
tit = {"gradiente":"Iluminación despareja", "contraste":"Contraste bajo", "ruido":"Ruido del sensor"}

fig, ax = plt.subplots(1, 3, figsize=(13.6, 4.3), sharey=True)
for a, m in zip(ax, modos):
    f = np.array([(float(s), float(x), float(y)) for mm, s, x, y in R if mm == m])
    f = f[np.argsort(f[:,0])]
    s, fijo, adap = f[:,0], f[:,1]*100, f[:,2]*100
    a.plot(s, fijo, "o-", c="#546e7a", lw=2, ms=6, label="umbral FIJO (sin CPU)")
    a.plot(s, adap, "s-", c="#c62828", lw=2, ms=6, label="ADAPTATIVO (con CPU)")
    a.fill_between(s, fijo, adap, where=(adap>=fijo), color="#c62828", alpha=.16)
    a.fill_between(s, fijo, adap, where=(adap<fijo),  color="#546e7a", alpha=.16)
    # el punto de cruce
    cr = np.where(np.diff(np.sign(adap-fijo)))[0]
    if len(cr):
        k = cr[-1]; xc = s[k] + (s[k+1]-s[k])*abs(adap[k]-fijo[k])/(abs(adap[k]-fijo[k])+abs(adap[k+1]-fijo[k+1]))
        a.axvline(xc, c="#333", ls=":", lw=1.3)
        a.text(xc+.02, 52, f"cruce\n{xc:.2f}", fontsize=8, color="#333")
    a.set_title(f"{tit[m]}\npeor caso: {fijo.min():.0f} % → {adap[np.argmin(fijo)]:.0f} %", fontsize=10)
    a.set_xlabel("severidad de la degradación"); a.grid(alpha=.3)
ax[0].set_ylabel("exactitud sobre las 10 000  %"); ax[0].set_ylim(45, 95)
ax[0].legend(fontsize=8.5, loc="lower left")
fig.suptitle("El CPU no compra precisión: compra que el sistema no se derrumbe\n"
             "(rojo = el CPU ayuda · gris = el CPU estorba)", fontsize=11, y=1.04)
plt.tight_layout()
plt.savefig("fig_soc_umbral.png", dpi=140, bbox_inches="tight")
plt.show()

lim = d["limpio"]
print(f"MNIST limpio:  fijo {lim[0]:.2%}   adaptativo {lim[1]:.2%}   ({lim[1]-lim[0]:+.2%})")
print("\npeor caso de cada degradacion:")
for m in modos:
    f = np.array([(float(s), float(x), float(y)) for mm,s,x,y in R if mm==m])
    k = np.argmin(f[:,1])
    print(f"  {m:<11} sev {f[k,0]:.1f}:  fijo {f[k,1]:.2%}  ->  adaptativo {f[k,2]:.2%}"
          f"   ({f[k,2]-f[k,1]:+.2%})")
print("\npeor caso del ADAPTATIVO (donde el CPU estorba):")
for m in modos:
    f = np.array([(float(s), float(x), float(y)) for mm,s,x,y in R if mm==m])
    k = np.argmin(f[:,2]-f[:,1])
    print(f"  {m:<11} sev {f[k,0]:.1f}:  fijo {f[k,1]:.2%}  vs adaptativo {f[k,2]:.2%}"
          f"   ({f[k,2]-f[k,1]:+.2%})")
