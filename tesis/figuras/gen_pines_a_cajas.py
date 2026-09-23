#!/usr/bin/env python3
"""gen_pines_a_cajas.py — genera la figura 'de los pines a las cajas' en SVG,
y de ahi PDF (para pdfLaTeX) y PNG.

    python3 gen_pines_a_cajas.py

Los datos salen del .pcf PROBADO (cam_sobel_display.pcf, 22-jul: scl=27, sda=26)
y de cam_sobel_display.v. NO de los comentarios de cabecera.
"""
import html, pathlib, subprocess, sys
import xml.etree.ElementTree as ET

W, H = 1700, 840
S = []
F = "DejaVu Sans, Helvetica, Arial, sans-serif"
def esc(t): return html.escape(str(t))

def caja(x, y, w, h, tit, det=(), fill="#ffffff", bor="#333333", fs=13, neg=False):
    S.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="7" fill="{fill}" '
             f'stroke="{bor}" stroke-width="1.6"/>')
    n = 1 + len(det)
    y0 = y + h/2 - (n-1)*8.5 + 4.5
    S.append(f'<text x="{x+w/2}" y="{y0}" font-family="{F}" font-size="{fs}" '
             f'font-weight="{"bold" if neg else "600"}" text-anchor="middle" '
             f'fill="#111111">{esc(tit)}</text>')
    for k, d in enumerate(det):
        S.append(f'<text x="{x+w/2}" y="{y0+17+k*15}" font-family="{F}" font-size="10.5" '
                 f'text-anchor="middle" fill="#777777">{esc(d)}</text>')

def marco(x, y, w, h, tit, fill, bor, dash="8 4", fs=14):
    S.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="9" fill="{fill}" '
             f'stroke="{bor}" stroke-width="1.6"'
             + (f' stroke-dasharray="{dash}"' if dash else '') + '/>')
    S.append(f'<text x="{x+16}" y="{y+23}" font-family="{F}" font-size="{fs}" '
             f'font-weight="bold" fill="{bor}">{esc(tit)}</text>')

def linea(pts, dash=False, ini=False, fin=True):
    d = " ".join(f"{a},{b}" for a, b in pts)
    m = (' marker-end="url(#pf)"' if fin else '') + (' marker-start="url(#pi)"' if ini else '')
    S.append(f'<polyline points="{d}" fill="none" stroke="#444444" stroke-width="1.8"'
             + (' stroke-dasharray="6 4"' if dash else '') + m + '/>')

def rotulo(x, y, ls, anc="middle"):
    ls = list(ls)
    an = max(len(l) for l in ls)*5.4 + 12
    ax = {"middle": x-an/2, "start": x-6, "end": x-an+6}[anc]
    S.append(f'<rect x="{ax}" y="{y-11}" width="{an}" height="{len(ls)*13+4}" rx="3" '
             f'fill="#ffffff" fill-opacity="0.92"/>')
    for k, l in enumerate(ls):
        S.append(f'<text x="{x}" y="{y+k*13}" font-family="{F}" font-size="10" '
                 f'text-anchor="{anc}" fill="#333333">{esc(l)}</text>')

# ---------------- titulo ----------------
S.append(f'<text x="40" y="44" font-family="{F}" font-size="19" font-weight="bold" '
         f'fill="#111111">De los pines a las cajas: iceSugar iCE40UP5K + filtro Sobel 3x3</text>')
S.append(f'<text x="40" y="68" font-family="{F}" font-size="13" fill="#666666">'
         f'Camara OV7670  ->  Sobel  ->  pantalla ILI9341. Sin computador de por medio.</text>')

# ---------------- estructura ----------------
marco(250, 108, 1150, 596, "module top   —   cam_sobel_display.v", "#fbfcfe", "#2f4f8f", dash="")
marco(280, 150, 1090, 190, "dominio  clk", "#eef4fb", "#4a7ebb")
marco(280, 430, 1090, 240, "dominio  cam_pclk", "#fdf3e8", "#c47f2a")

caja(40, 205, 165, 60, "clk", ("pin 35",), "#ebebeb", "#666666")
caja(40, 330, 165, 80, "LED RGB", ("estado",), "#dff0d8", "#4a8a3f")
caja(40, 495, 165, 130, "Camara OV7670", ("modulo externo",), "#dff0d8", "#4a8a3f")
caja(1455, 200, 175, 110, "Pantalla TFT", ("ILI9341",), "#dff0d8", "#4a8a3f")

caja(310, 200, 210, 110, "Configuracion SCCB",
     ("escribe los registros", "de la camara al arrancar"))
caja(1090, 200, 215, 110, "Controlador ILI9341",
     ("spi_start, spi_byte,", "spi_dcbit, spi_done"))

caja(345, 480, 225, 150, "Submuestreo a 60 x 80",
     ("href_d, parity, curY,", "colkeep, rowkeep, fbx,", "waddr_wr"))
caja(600, 480, 235, 150, "Line buffers + ventana 3x3",
     ("dline1[0:59]  fila n-1", "dline2[0:59]  fila n-2", "t00 .. t22   (9 taps)"))
caja(865, 480, 225, 150, "Sobel 3x3",
     ("gxp, gxn, gyp, gyn  (1-2-1)", "agx = abs(gxp - gxn)", "agy = abs(gyp - gyn)"))
caja(1120, 480, 220, 150, "Magnitud y umbral",
     ("mag12 = agx + agy", "mag = saturada a 8 bit", "mag > 90 ? FF : 00"))

caja(830, 355, 475, 62, "Frame buffer   fb[0:4799]   ·   60 x 80",
     ("escribe @posedge cam_pclk   ·   lee @clk    —    CRUCE DE DOMINIOS",),
     "#fff3cd", "#b8860b", 13, neg=True)

# ---------------- conexiones ----------------
linea([(40, 235), (18, 235), (18, 560), (40, 560)]);  rotulo(24, 452, ["cam_xclk", "pin 2"], "start")
linea([(205, 235), (258, 235), (258, 255), (310, 255)]); rotulo(262, 224, ["clk"], "start")
linea([(310, 230), (228, 230), (228, 530), (205, 530)], dash=True, ini=True)
rotulo(238, 300, ["cam_scl  pin 27", "cam_sda  pin 26", "(inout)"], "start")
linea([(205, 590), (310, 590)]);            rotulo(160, 648, ["cam_pclk 28  ·  cam_href 32", "cam_d[7:0]  (8 pines)"], "start")
linea([(570, 555), (600, 555)]);            rotulo(585, 468, ["pixel 8b"])
linea([(835, 555), (865, 555)]);            rotulo(850, 468, ["t00..t22"])
linea([(1090, 555), (1120, 555)]);          rotulo(1105, 468, ["agx, agy"])
linea([(1230, 480), (1230, 417)]);          rotulo(1240, 452, ["we, wadr, wdat"], "start")
linea([(1197, 355), (1197, 310)]);          rotulo(1207, 337, ["fb_rd"], "start")
linea([(1305, 255), (1455, 255)]);          rotulo(1380, 232, ["tft_sck 37 · tft_mosi 36", "tft_cs 25 · tft_dc 23"])
linea([(250, 370), (205, 370)])
rotulo(268, 358, ["led_r 39 · led_g 40 · led_b 41", "(SB_RGBA_DRV)"], "start")

# ---------------- leyenda de puertos ----------------
caja(40, 714, 900, 108, "", (), "#ffffff", "#aaaaaa")
S.append(f'<text x="58" y="738" font-family="{F}" font-size="12" font-weight="bold" '
         f'fill="#111111">Los 14 puertos de top</text>')
for k, l in enumerate([
    "in      clk,  cam_pclk,  cam_href,  cam_d[7:0]",
    "out     cam_xclk,  cam_scl,  tft_sck,  tft_mosi,  tft_cs,  tft_dc,  led_r,  led_g,  led_b",
    "inout   cam_sda",
    "cam_d[7:0]  ->  pines 48  46  44  43  38  34  31  42"]):
    S.append(f'<text x="58" y="{758+k*16}" font-family="{F}" font-size="10.5" '
             f'fill="#666666">{esc(l)}</text>')

svg = (f'<?xml version="1.0" encoding="UTF-8"?>\n'
       f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
       f'viewBox="0 0 {W} {H}">\n<defs>\n'
       f'<marker id="pf" markerWidth="9" markerHeight="7" refX="8.5" refY="3.5" orient="auto">'
       f'<polygon points="0 0, 9 3.5, 0 7" fill="#444444"/></marker>\n'
       f'<marker id="pi" markerWidth="9" markerHeight="7" refX="0.5" refY="3.5" orient="auto">'
       f'<polygon points="9 0, 0 3.5, 9 7" fill="#444444"/></marker>\n</defs>\n'
       f'<rect width="{W}" height="{H}" fill="#ffffff"/>\n' + "\n".join(S) + "\n</svg>\n")

ET.fromstring(svg)                      # validar ANTES de escribir
pathlib.Path("fig_pines_a_cajas.svg").write_text(svg, encoding="utf-8")
print("  SVG validado y escrito")

import cairosvg
cairosvg.svg2pdf(url="fig_pines_a_cajas.svg", write_to="fig_pines_a_cajas.pdf")
cairosvg.svg2png(url="fig_pines_a_cajas.svg", write_to="fig_pines_a_cajas.png",
                 output_width=W*2, output_height=H*2)
print("  PDF y PNG generados")
