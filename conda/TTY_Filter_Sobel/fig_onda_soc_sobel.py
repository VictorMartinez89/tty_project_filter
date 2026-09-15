# === Cuaderno 2 · figura 33: cámara + SoC + Sobel + clasificador, en señales ===
#   Dibujada desde out/soc_sobel.vcd, producido por iverilog en la VM Ubuntu.
import pickle, numpy as np, matplotlib.pyplot as plt
from matplotlib.gridspec import GridSpec

D="/Users/vic/utm-share/sim_cadenas_mnist/out"
TR, TFIN = pickle.load(open(f"{D}/ondas_soc_sobel.pkl","rb"))
SIG=[("reset","reset","#90a4ae",0), ("cpu_escribio","cpu_escribio","#f9a825",0),
     ("thr_usado","thr_usado","#ef6c00",1), ("href","href","#5c6bc0",0),
     ("py_valid","py_valid","#5c6bc0",0), ("w_valid","w_valid","#26a69a",0),
     ("w_pix","w_pix","#26a69a",1), ("w_fin","w_fin","#26a69a",0),
     ("done","done","#c62828",0), ("digito","digito","#c62828",1),
     ("valido","valido","#c62828",0)]

def escalon(ax,y,s,t0,t1,col,U,h=.66):
    tr=[(t,v) for t,v in TR.get(s,[]) if v is not None]
    if not tr: return
    ts=np.array([x[0] for x in tr]); vs=np.array([x[1] for x in tr])
    g=np.linspace(t0,t1,4000)
    v=vs[np.clip(np.searchsorted(ts,g,"right")-1,0,len(vs)-1)]
    ax.fill_between(g/U,y,y+h*v,step="post",color=col,alpha=.8,lw=0)
    ax.plot(g/U,y+h*v,drawstyle="steps-post",color=col,lw=1.0)
    if len(tr)<2000 and (t1-t0)/4000>20:
        for t,val in tr:
            if val==1 and t0<=t<=t1: ax.plot([t/U]*2,[y,y+h],color=col,lw=2.2,zorder=5)

def vector(ax,y,s,t0,t1,col,U,h=.66):
    tr=[(t,v) for t,v in TR.get(s,[]) if v is not None and t0<=t<=t1]
    pre=[v for t,v in TR.get(s,[]) if v is not None and t<=t0]
    seg=([(t0,pre[-1])] if pre else [(t0,0)])+tr+[(t1,None)]
    for (ta,va),(tb,_) in zip(seg,seg[1:]):
        if va is None: continue
        ax.add_patch(plt.Rectangle((ta/U,y),(tb-ta)/U,h,fc=col,alpha=.25,ec=col,lw=.8))
        if (tb-ta)/(t1-t0)>.09:
            ax.text((ta+tb)/2/U,y+h/2,str(va),ha="center",va="center",fontsize=8.4,
                    color="#111",weight="bold")

def panel(ax,t0,t1,U,ut,tit,sub):
    for k,(s,et,col,vec) in enumerate(SIG):
        y=len(SIG)-1-k
        (vector if vec else escalon)(ax,y,s,t0,t1,col,U)
        ax.text(t0/U-(t1-t0)/U*.015,y+.33,et,ha="right",va="center",fontsize=8.8,
                color=col,weight="bold")
        ax.axhline(y,color="#eceff1",lw=.6,zorder=0)
    ax.set_xlim(t0/U,t1/U); ax.set_ylim(-.5,len(SIG)+.05); ax.set_yticks([])
    ax.tick_params(labelsize=8.2); ax.set_xlabel(f"tiempo  ({ut})",fontsize=9.2)
    for s_ in ("top","right","left"): ax.spines[s_].set_visible(False)
    ax.set_title(tit+"\n"+sub,fontsize=10.6,weight="bold",pad=10,linespacing=1.5)

fig=plt.figure(figsize=(15.4,9.0))
gs=GridSpec(2,2,figure=fig,height_ratios=[1.25,1],hspace=.52,wspace=.16)

panel(fig.add_subplot(gs[0,:]),0,TFIN,1e9,"ms",
      "A · LA CADENA COMPLETA  ·  cámara → SoC + Sobel → clasificador  ·  19.0 ms",
      "el veredicto sale en el cuadro 1 con digito = 3 — CORRECTO — y NO cambia en el cuadro 2")

panel(fig.add_subplot(gs[1,0]),0,600000,1e3,"ns",
      "B · EL CPU REEMPLAZA EL UMBRAL",
      "thr_usado arranca en 110 (el valor por defecto del RTL) y a los 245 ns pasa a 90.\n"
      "cpu_escribio sube a los 145 ns, con el datapath todavía en reset")

T0,T1=6124735000,6764245000
axC=fig.add_subplot(gs[1,1])
panel(axC,T0-120000000,T1+120000000,1e6,"µs","C · EL VEREDICTO, Y SE SOSTIENE",
      "w_fin cierra el cuadro, 639.5 µs de MAC, y done sale con digito = 3.\n"
      "valido queda en 1 y ya no vuelve a bajar")
axC.annotate("",xy=(T1/1e6,-.35),xytext=(T0/1e6,-.35),
             arrowprops=dict(arrowstyle="<->",color="#c62828",lw=2.0))
axC.set_ylim(-1.25,len(SIG)+.05)
axC.text((T0+T1)/2/1e6,-.90,"639.5 µs · 400 MAC + argmax",ha="center",fontsize=9.2,
         color="#c62828",weight="bold")

fig.suptitle("LA CADENA CÁMARA → SoC + SOBEL → CLASIFICADOR, EN SEÑALES   ·   "
             "escena del dígito 3   ·   VCD de iverilog en la VM Ubuntu",
             fontsize=12.6,weight="bold",y=.985)
plt.savefig("fig_onda_soc_sobel.png",dpi=140,bbox_inches="tight")
print("ok")
