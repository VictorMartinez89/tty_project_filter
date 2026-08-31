#!/usr/bin/env python3
# fig_sistema_embebido.py — el sistema embebido de la tesis, en sus dos versiones.
#
#   sistema_embebido_soc.py   -> cam_femto_display.v : con FemtoRV32 adentro (el umbral es software)
#   sistema_embebido_sin.py   -> cam_sobel_display.v : sin CPU (el umbral es una constante del RTL)
#
#   Las dos se dibujan con LAS MISMAS COORDENADAS a proposito: puestas una sobre otra en el
#   capitulo, lo unico que cambia de lugar es el bloque violeta. El camino de los pixeles -que es
#   el que hace el trabajo- es identico en las dos.
#   Leido de rtl_fisico/cam_femto_display.v, el que corre en la iCESugar.
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch, Rectangle

VIO, VIOF = "#8e44ad", "#f4ecf7"          # lo que agrega el SoC
DAT, DATF = "#c0392b", "#fdecea"          # camino de datos (pixeles)
NEU, NEUF = "#2c3e50", "#f4f6f7"

def dibujar(con_cpu, salida):
    fig, ax = plt.subplots(figsize=(15.4, 8.2)); ax.axis("off")
    ax.set_xlim(0, 17); ax.set_ylim(-0.55, 9.4)
    if con_cpu:
        titulo = ("Sistema embebido `cam_femto_display`: camara OV7670 -> Sobel -> TFT ILI9341, "
                  "con el FemtoRV32 eligiendo el filtro\n"
                  "iCE40UP5K (iCESugar) — dos dominios de reloj, y el CPU FUERA del camino de los pixeles")
    else:
        titulo = ("Sistema embebido `cam_sobel_display`: camara OV7670 -> Sobel -> TFT ILI9341, SIN procesador\n"
                  "iCE40UP5K (iCESugar) — el mismo camino de pixeles, con el umbral cableado en el RTL")
    ax.set_title(titulo, fontsize=12.6, fontweight="bold", pad=10)

    def box(x,y,w,h,t,fc,ec,fs=8.4,tc="#2d3436"):
        ax.add_patch(FancyBboxPatch((x,y),w,h,boxstyle="round,pad=0.05,rounding_size=0.10",
                     lw=1.7,edgecolor=ec,facecolor=fc,zorder=3))
        ax.text(x+w/2,y+h/2,t,ha="center",va="center",fontsize=fs,fontweight="bold",color=tc,zorder=4)
    def ar(x1,y1,x2,y2,t="",fs=7.2,c=NEU,lw=2.2,ls="-",dy=0.24,rad=0.0):
        ax.add_patch(FancyArrowPatch((x1,y1),(x2,y2),arrowstyle="-|>",mutation_scale=15,lw=lw,
                     color=c,linestyle=ls,zorder=5,connectionstyle=f"arc3,rad={rad}"))
        if t: ax.text((x1+x2)/2,(y1+y2)/2+dy,t,ha="center",fontsize=fs,color=c,fontweight="bold",zorder=6)

    # ---------- dominios de reloj (identicos en las dos versiones) ----------
    ax.add_patch(Rectangle((2.6,5.05),10.2,3.0,facecolor="#eaf4fb",edgecolor="#2980b9",
                           lw=1.2,linestyle=(0,(5,3)),zorder=0))
    ax.text(7.7,7.78,"dominio  cam_pclk  (el reloj de la camara: los pixeles llegan y NO esperan)",
            fontsize=9.0,color="#2471a3",fontweight="bold",ha="center",zorder=1)
    ax.add_patch(Rectangle((2.6,0.45),12.2,3.4,facecolor="#eefaf1",edgecolor="#27ae60",
                           lw=1.2,linestyle=(0,(5,3)),zorder=0))
    ax.text(8.7,3.55,"dominio  clk  (12 MHz del sistema: SCCB" + (" + CPU" if con_cpu else "") + " + display)",
            fontsize=9.0,color="#1e8449",fontweight="bold",ha="center",zorder=1)

    # ---------- camino de los pixeles: IDENTICO en las dos ----------
    box(0.15,5.5,2.2,1.9,"OV7670\ncamara\n\n8 bits + pclk\n+ href",NEUF,NEU,8.2)
    box(2.95,5.7,1.9,1.5,"submuestreo\n\n640x480\n-> 60x80",DATF,DAT)
    box(5.15,5.7,1.9,1.5,"linebuf3x3\n\nventana 3x3\nen BRAM",DATF,DAT)
    box(7.35,5.7,2.2,1.5,"Sobel 3x3\n\n|Gx| + |Gy|\nsaturado a 255",DATF,DAT)
    box(9.85,5.7,2.6,1.5,"umbral\n\nmag > thr_hi\n-> 0x00 / 0xFF",DATF,DAT)
    ar(2.35,6.45,2.95,6.45); ar(4.85,6.45,5.15,6.45); ar(7.05,6.45,7.35,6.45); ar(9.55,6.45,9.85,6.45)
    ax.text(2.65,6.98,"8 b/px",fontsize=7.2,color=DAT,ha="center",fontweight="bold")
    ax.text(11.15,5.42,"a la salida, 1 bit util por pixel",fontsize=7.6,color=DAT,ha="center",style="italic")

    # ---------- framebuffer: el puente entre relojes ----------
    box(13.05,4.15,1.75,3.4,"FRAME\nBUFFER\n\n60x80\nSPRAM\n\nescribe en\ncam_pclk\n\nlee en clk",
        "#fef5e7","#d68910",8.0,tc="#9c640c")
    ar(12.45,6.45,13.05,6.45,c=DAT); ar(13.9,4.15,13.9,2.95,c="#d68910",lw=2.2)

    # ---------- SCCB y display: identicos en las dos ----------
    box(0.15,1.25,2.2,1.9,"SCCB\n(I2C)\n\nCOM7=0x00\nCOM8=0xE7\nCOM9=0x18",NEUF,NEU,8.0)
    ar(1.25,3.15,1.25,5.5,"configura la camara\nal arrancar",c=NEU,lw=1.6,ls=(0,(4,2)),fs=7.0,dy=0.0)
    box(12.6,1.25,2.2,1.7,"driver TFT\nSPI\n\nlee fb\ny la manda",NEUF,NEU,8.2)
    box(15.15,1.4,1.7,1.4,"TFT\nILI9341\n\n240x320",NEUF,NEU,8.2)
    ar(14.8,2.1,15.15,2.1,c=NEU)

    # ---------- LA UNICA DIFERENCIA ----------
    if con_cpu:
        box(2.95,1.25,2.0,1.9,"FemtoRV32\n(RV32I quark)\n\n7 instrucciones\ndesde ROM",VIOF,VIO,8.4,tc=VIO)
        box(5.35,1.95,1.7,1.2,"RAM\n+ firmware\n.hex",VIOF,VIO,8.0,tc=VIO)
        box(5.35,0.70,1.7,1.0,"decoder\nmem_addr[31:16]\n== 0x0045",VIOF,VIO,7.4,tc=VIO)
        box(7.45,1.25,2.8,1.9,"peripheral_filter\n0x0045\n\n0x00 CTRL  mode/enable\n"
                              "0x04 THR   thr_hi/thr_lo\n0x08 STAT  (lectura)",VIOF,VIO,7.6,tc=VIO)
        ar(4.95,2.55,5.35,2.55,c=VIO,lw=1.8); ar(4.95,1.45,5.35,1.30,c=VIO,lw=1.8)
        ar(7.05,1.20,7.45,1.60,c=VIO,lw=1.8)
        ar(8.85,3.15,10.9,5.7,c=VIO,lw=2.4,ls=(0,(5,2)),rad=-0.18)
        ax.text(8.35,4.35,"thr_hi y mode cruzan al otro reloj\ncon 2 flip-flops (son casi-estaticos:\n"
                          "el CPU los fija una vez y no los toca mas)",
                fontsize=8.0,color=VIO,fontweight="bold",ha="right",va="center",zorder=6)
        pie = ("El CPU escribe DOS registros al arrancar y se aparta: los pixeles NUNCA pasan por su bus.\n"
               "Cambiar de filtro o de umbral es RECOMPILAR EL FIRMWARE, no volver a sintetizar.")
    else:
        box(7.45,1.55,2.8,1.3,"localparam THR = 90\n\nuna constante\nen el RTL",NEUF,"#7f8c8d",8.6,tc="#566573")
        ar(8.85,2.85,10.9,5.7,c="#7f8c8d",lw=2.4,ls=(0,(5,2)),rad=-0.18)
        ax.text(8.35,4.35,"el umbral entra cableado:\npara cambiarlo hay que volver a\nsintetizar y regrabar la FPGA",
                fontsize=8.0,color="#566573",fontweight="bold",ha="right",va="center",zorder=6)
        ax.add_patch(Rectangle((2.95,0.70),4.1,2.45,facecolor="none",edgecolor=VIO,lw=1.6,
                               linestyle=(0,(4,3)),zorder=2))
        ax.text(5.0,1.9,"aqui va el SoC\nen la otra version\n\n(FemtoRV32 + RAM +\ndecoder + periferico)",
                fontsize=8.4,color=VIO,fontweight="bold",ha="center",va="center",style="italic",zorder=3)
        pie = ("Mismo camino de pixeles, mismo resultado en la pantalla: los dos mapas de bordes son IDENTICOS pixel a pixel.\n"
               "Lo unico que cambia es de donde sale el umbral — y eso es exactamente lo que la tesis mide.")

    ax.text(8.5,-0.21,pie,fontsize=10.0,ha="center",va="center",fontweight="bold",
            color=VIO if con_cpu else "#566573",linespacing=1.5,zorder=6)
    ax.add_patch(Rectangle((1.3,-0.52),14.4,0.66,facecolor=VIOF if con_cpu else NEUF,
                           edgecolor=VIO if con_cpu else "#7f8c8d",lw=1.3,zorder=0))
    plt.tight_layout(); plt.savefig(salida, dpi=135, bbox_inches="tight"); plt.close(fig)
    print(f"-> {salida}")

dibujar(True,  "img/sistema_embebido_soc.png")
dibujar(False, "img/sistema_embebido_sin_cpu.png")
