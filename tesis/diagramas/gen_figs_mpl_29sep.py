#!/usr/bin/env python3
"""gen_figs_mpl_29sep.py — las tres figuras de matplotlib del cuaderno 1 (Partes 121, 130 y 157),
rehechas para la tesis tras el repaso del PDF (29-sep):
  fig_4_sobelcomp_diagrama.png  el bloque PMOD ya no toca el borde; tildes
  fig_4_vision_diagrama.png     la lectura del framebuffer (CDC) llega AL display: antes la flecha
                                «píxel» salía de la nada
  fig_5_vision_comparacion.png  la anotación del +0,29 mm² ya no se monta sobre la barra; mm²
Sin títulos: el pie de la tesis los da.   python tesis/diagramas/gen_figs_mpl_29sep.py"""
import os
import numpy as np
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch, Rectangle

FIG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "figuras")


def herramientas(ax):
    def box(x, y, w, h, t, fc, ec, fs=7.8, tc="#2d3436"):
        ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.05,rounding_size=0.10",
                                    lw=1.7, edgecolor=ec, facecolor=fc))
        ax.text(x + w / 2, y + h / 2, t, ha="center", va="center", fontsize=fs, fontweight="bold", color=tc)

    def ar(x1, y1, x2, y2, t="", c="#2d3436", cabeza=True, dy=0.22, fs=6.8, tc="#555"):
        ax.add_patch(FancyArrowPatch((x1, y1), (x2, y2), arrowstyle="-|>" if cabeza else "-",
                                     mutation_scale=13, lw=1.7, color=c))
        if t:
            ax.text((x1 + x2) / 2, (y1 + y2) / 2 + dy, t, ha="center", fontsize=fs, color=tc)
    return box, ar


def sobel_completo():
    fig, ax = plt.subplots(figsize=(13.1, 3.3)); ax.axis("off")
    ax.set_xlim(-0.1, 16.8); ax.set_ylim(0.3, 4.3)
    box, ar = herramientas(ax)
    box(0.2, 1.8, 2.1, 1.7, "OV7670\n(cámara)\n3,3 V", "#ffe8cc", "#e67e22", 7.6)
    box(2.8, 1.6, 2.7, 2.1, "cam_frontend\nSCCB + CDC + gris", "#d5f5e3", "#27ae60", 7.4)
    box(6.0, 1.75, 2.3, 1.8, "sobel_top\n|Gx|+|Gy|", "#d5f5e3", "#16a085", 7.6)
    box(8.8, 1.75, 2.4, 1.8, "framebuffer\n60×80\n(binario)", "#f9d7d2", "#c0392b", 7.4)
    box(11.7, 1.6, 2.6, 2.1, "lcd_ili9341\nSPI + ROM", "#d5f5e3", "#8e44ad", 7.4)
    box(14.8, 1.8, 1.8, 1.7, "PMOD\nTFTLCD\n3,3 V", "#ffe8cc", "#e67e22", 7.6)
    for x1, x2, t in [(2.3, 2.8, "D/PCLK"), (5.5, 6.0, "gris"), (8.3, 8.8, "out_pix"),
                      (11.2, 11.7, "pix_gray"), (14.3, 14.8, "SPI")]:
        ar(x1, 2.6, x2, 2.6, t, dy=0.4)
    ax.text(8.3, 0.8, "Un solo reloj (clk): el front-end sincroniza PCLK, HREF y VSYNC internamente (2 FF).",
            ha="center", fontsize=8.2, style="italic", color="#636e72")
    fig.savefig(f"{FIG}/fig_4_sobelcomp_diagrama.png", dpi=100, bbox_inches="tight", pad_inches=0.08)


def vision_top():
    fig, ax = plt.subplots(figsize=(13.1, 5.3)); ax.axis("off")
    ax.set_xlim(0, 16); ax.set_ylim(0, 6.9)
    box, ar = herramientas(ax)
    ax.add_patch(Rectangle((2.7, 3.7), 7.1, 2.9, facecolor="#eaf4fb", edgecolor="#2980b9", lw=1.1,
                           linestyle=(0, (4, 3)), zorder=0))
    ax.text(6.2, 6.35, "dominio cam_pclk (cámara)", fontsize=8.0, color="#2471a3", fontweight="bold", ha="center")
    ax.add_patch(Rectangle((2.7, 0.5), 12.6, 2.7, facecolor="#eefaf1", edgecolor="#27ae60", lw=1.1,
                           linestyle=(0, (4, 3)), zorder=0))
    ax.text(5.6, 2.95, "dominio clk (sistema: SCCB + display)", fontsize=8.0, color="#1e8449",
            fontweight="bold", ha="center")
    box(0.2, 3.9, 2.2, 1.7, "OV7670\n(cámara)\n3,3 V", "#ffe8cc", "#e67e22", 8.0)
    box(2.9, 4.6, 2.1, 1.6, "captura +\nsubmuestreo\n60×80", "#d6eaf8", "#2980b9", 7.4)
    box(5.3, 4.6, 2.0, 1.6, "SOBEL 3×3\n(imagen chica)", "#d6eaf8", "#2980b9", 7.6)
    box(7.6, 4.2, 2.0, 2.0, "FRAMEBUFFER\n60×80×8\n~38 400 FF", "#f9d7d2", "#c0392b", 7.4, tc="#c0392b")
    box(2.9, 1.0, 2.1, 1.6, "SCCB master\n(config. cámara)", "#d5f5e3", "#27ae60", 7.6)
    box(10.0, 1.0, 2.6, 1.9, "display ILI9341\nSPI + FSM\n(BOOT/INIT/\nFRAME/FILL)", "#d5f5e3", "#27ae60", 7.4)
    box(13.1, 1.2, 2.0, 1.6, "PMOD\nTFTLCD\n3,3 V", "#ffe8cc", "#e67e22", 7.8)
    ar(2.4, 4.75, 2.9, 5.1, "D/PCLK")
    ar(5.0, 5.4, 5.3, 5.4)
    ar(7.3, 5.4, 7.6, 5.4, "borde")
    # la lectura del framebuffer cruza al dominio clk y ENTRA al display
    ar(8.6, 4.2, 8.6, 1.95, c="#c0392b", cabeza=False)
    ar(8.6, 1.95, 10.0, 1.95, "píxel", c="#c0392b", tc="#c0392b")
    ax.text(8.75, 3.45, "CDC: se lee con clk", fontsize=6.8, color="#c0392b", ha="left", fontweight="bold")
    ar(12.6, 2.0, 13.1, 2.0, "SPI")
    ar(3.95, 2.6, 3.95, 4.6, c="#27ae60")
    ax.text(4.15, 3.45, "SCL/SDA", fontsize=6.4, color="#1e8449", rotation=90, va="center")
    ax.text(8.0, 0.12, "Un solo chip: cámara → Sobel → framebuffer → pantalla. El framebuffer (~38 400 FF) "
            "fija el tamaño.", ha="center", fontsize=8.6, style="italic", color="#636e72")
    fig.savefig(f"{FIG}/fig_4_vision_diagrama.png", dpi=100, bbox_inches="tight", pad_inches=0.08)


def vision_comparacion():
    fig, (axL, axR) = plt.subplots(1, 2, figsize=(11.6, 4.3))
    labels = ["vision_top\n(Sobel)", "vision_canny\n(Canny 1-str)"]
    area = [1.75, 2.04]
    axL.bar(labels, area, color=["#0984e3", "#8e44ad"], edgecolor="#333", width=0.55)
    axL.set_ylabel("Área del dado (mm²)", fontsize=10)
    axL.set_title("Área: +0,29 mm² por el camino de datos Canny", fontsize=11, fontweight="bold")
    for i, a in enumerate(area):
        axL.text(i, a + 0.03, f"{a:.2f}".replace(".", ","), ha="center", fontsize=10, fontweight="bold")
    axL.annotate("+0,29 mm²\n(3 memorias de línea\nfrente a 1)", xy=(0.73, 2.04), xytext=(0.5, 2.3),
                 fontsize=8.2, color="#8e44ad", fontweight="bold", ha="center", va="center",
                 arrowprops=dict(arrowstyle="->", color="#8e44ad", lw=1.4))
    axL.set_ylim(0, 2.6)
    for s in ("top", "right"):
        axL.spines[s].set_visible(False)
    x = np.arange(2); w = 0.35
    cells = [35653, 41925]; power = [66.9, 90.9]
    ax2 = axR.twinx()
    axR.bar(x - w / 2, cells, w, color="#16a085", edgecolor="#333")
    ax2.bar(x + w / 2, power, w, color="#e67e22", edgecolor="#333")
    axR.set_xticks(x); axR.set_xticklabels(["Sobel", "Canny"], fontsize=9)
    axR.set_ylabel("Celdas", fontsize=9.5, color="#16a085")
    ax2.set_ylabel("Potencia típica (mW)", fontsize=9.5, color="#e67e22")
    axR.set_title("Celdas y potencia", fontsize=11, fontweight="bold")
    for i, c in enumerate(cells):
        axR.text(i - w / 2, c + 900, f"{c:,}".replace(",", " "), ha="center", fontsize=7.8, fontweight="bold")
    for i, p in enumerate(power):
        ax2.text(i + w / 2, p + 2, f"{p}".replace(".", ","), ha="center", fontsize=8, fontweight="bold", color="#b8600e")
    axR.set_ylim(0, 50000); ax2.set_ylim(0, 120)
    axR.spines["top"].set_visible(False); ax2.spines["top"].set_visible(False)
    plt.tight_layout()
    fig.savefig(f"{FIG}/fig_5_vision_comparacion.png", dpi=100)


if __name__ == "__main__":
    sobel_completo(); vision_top(); vision_comparacion()
    print("ok: fig_4_sobelcomp_diagrama, fig_4_vision_diagrama, fig_5_vision_comparacion")
