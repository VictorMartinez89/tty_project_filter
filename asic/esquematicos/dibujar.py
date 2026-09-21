#!/usr/bin/env python3
"""dibujar.py — los cuatro diagramas de bloques, con el flujo LEIDO del RTL."""
from bloques import svg
CLK, P = "clk", "pclk"
IN  = [("clk", CLK), ("rst_n", CLK), ("cam_pclk", P), ("cam_href", P), ("cam_d[7:0]", P)]
OUT = [("cam_xclk", CLK), ("cam_scl", CLK), ("cam_sda_o", CLK), ("cam_sda_oe", CLK),
       ("tft_sck", CLK), ("tft_mosi", CLK), ("tft_cs", CLK), ("tft_dc", CLK), ("cfg_done", CLK)]
# cuatro columnas, dos carriles: el de imagen (arriba) y el de decision (abajo)
C1, C2, C3, C4, C5 = 210, 430, 650, 870, 1050   # C5 deja hueco a los pines de salida
AN, AL = 180, 58
def fl(x1,y1,x2,y2,et=""): return (x1,y1,x2,y2,et)

def vision(nom, tit, filtro, subf):
    et = [(C1,  70, AN, AL, "SCCB config", "FSM · 3 registros", CLK, False),
          (C1, 190, AN, AL, "captura",     "YUV422 -> luma",    P,   False),
          (C2, 190, AN, AL, "submuestreo", "640x480 -> 60x80",  P,   False),
          (C3, 190, AN, AL, filtro,        subf,                P,   False),
          (C4, 190, AN, AL, "framebuffer", "60x80x8b = 38 400 FF", P, True),
          (C4, 310, AN, AL, "color RGB565","gris",              CLK, False),
          (C5, 250, AN, AL, "FSM ILI9341", "+ SPI maestro",     CLK, False)]
    n = [fl(C1+AN,219,C2,219), fl(C2+AN,219,C3,219), fl(C3+AN,219,C4,219,"borde"),
         fl(C4+AN/2,248,C4+AN/2,310,"lee"), fl(C4+AN,339,C5+AN/2,308),
         fl(C5+AN,279,1215,279)]
    svg(nom, tit, IN, OUT, et, n); print("  ",nom)

def mnist(nom, tit, clf, subclf):
    et = [(C1,  70, AN, AL, "SCCB config", "FSM · 3 registros", CLK, False),
          (C1, 190, AN, AL, "captura",     "YUV422 -> luma",    P,   False),
          (C2, 190, AN, AL, "cam_win28",   "ventana 448 -> 28x28", P, True),
          (C3, 130, AN, AL, "framebuffer", "784 B = 6 272 FF",  P,   True),
          (C3, 250, AN, AL, clf,           subclf,              P,   True),
          (C4, 250, AN, AL, "cruce 2 FF",  "digito -> clk",     CLK, False),
          (C4, 370, AN, AL, "glifo",       "7 segmentos",       CLK, True),
          (C4, 130, AN, AL, "color RGB565","28x28 ampliado x8", CLK, False),
          (C5, 250, AN, AL, "FSM ILI9341", "+ SPI maestro",     CLK, False)]
    n = [fl(C1+AN,219,C2,219), fl(C2+AN,205,C3,159,"28x28"), fl(C2+AN,233,C3,279),
         fl(C3+AN,159,C4,159,"lee"), fl(C3+AN,279,C4,279,"digito"),
         fl(C4+AN/2,308,C4+AN/2,370), fl(C4+AN,159,C5+AN/2,248),
         fl(C4+AN,399,C5+AN/2,310), fl(C5+AN,279,1215,279)]
    svg(nom, tit, IN, OUT + [("hubo",CLK),("digito[3:0]",CLK)], et, n); print("  ",nom)

vision("bloq_vision_top.svg","vision_top:1","SOBEL 3x3","|Gx|+|Gy| · 1 line-buffer")
vision("bloq_vision_canny_top.svg","vision_canny_top:1","CANNY 1-salto","doble umbral · 3 line-buffers")
mnist("bloq_vision_sobel_mnist.svg","vision_sobel_mnist:1","mnist_top","Sobel · 32 contadores · 400 pesos")
mnist("bloq_vision_canny_mnist.svg","vision_canny_mnist:1","mnist_top_canny","Canny 110/40 · 400 pesos")
