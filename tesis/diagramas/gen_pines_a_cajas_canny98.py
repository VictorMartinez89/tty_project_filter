# gen_pines_a_cajas_canny98.py — «De los pines a las cajas» de Canny-98 (mnist_top98 + mnist_clf98), el estilo común.
from dio import Diagrama
from pac_estilo import *
d = Diagrama("pac_canny98", 1900, 900)
titulo(d, "De los pines a las cajas: mnist_top98, el reconocedor Canny-98",
       "Píxel → Canny de un salto → 128 contadores → trasvase → 168 rasgos → capa oculta de 120 neuronas → capa de salida "
       "→ 0..9. Pesos en BRAM, activaciones en SPRAM: 98,45 %, 10 000 / 10 000 en la tarjeta.")
marco(d, 250, 100, 1400, 640, "module mnist_top98   —   mnist_top98.v", "#fbfcfe", AZUL_M, dash=False)
marco(d, 280, 142, 1340, 572, "un solo reloj:  clk", AZ_F, AZ_B)
ent = ext(d, 40, 300, 170, 230, "Entrada", ["clk · reset", "in_valid", "in_pix[7:0]", "thr_hi[7:0] = 90", "thr_lo[7:0] = 32"])
ver = ext(d, 1700, 330, 175, 120, "Veredicto", ["done", "digito[3:0]", "valido"])
marco(d, 305, 180, 330, 500, "mnist_feat16_mem   ext", "#ffffff", ROJO, fs=12)
e1 = caja(d, 325, 225, 290, 130, "El extractor de Canny-78", ["Canny de un salto, octante y zona", "tres linebuf3x3", "sin un cambio"])
e3 = mem(d, 325, 380, 290, 110, "128 contadores", ["16 zonas × 8 octantes", "en memoria síncrona"])
e4 = caja(d, 325, 520, 290, 60, "frame_done · n_bordes", [])
linea(d, e1, e3, "borde → cuenta"); linea(d, e3, e4, "")
tr = caja(d, 665, 330, 190, 170, "Trasvase", ["128 lecturas", "rd_clr vacía", "cada contador", "130 ciclos"], "#e8f0fb", "#1f4e79")
marco(d, 885, 180, 710, 500, "mnist_clf98   clf", "#ffffff", ROJO, fs=12)
fm = mem(d, 905, 225, 300, 110, "fmem: 168 rasgos", ["0..127 nivel 2 · 128..159 nivel 1", "160..167 nivel 0 (derivados)"])
l1 = caja(d, 905, 375, 300, 150, "Capa oculta · 120 neuronas", ["acc = b1[j] + suma W1[j][k] · f[k]", "h[j] = min(255, max(0, acc ≫ 2))",
                                                               "una MAC por ciclo: 120 × 171 ciclos"], "#ffffff", ROJO)
l2 = caja(d, 905, 555, 300, 105, "Capa de salida · argmax", ["s[c] = b2[c] + suma W2[c][j] · h[j]", "10 × 123 ciclos · el índice más bajo gana"],
          "#ffffff", ROJO)
wm = mem(d, 1250, 225, 320, 150, "wmem: 21 360 pesos de 4 bits", ["W1 en j·168 + k  ·  W2 en 20 160 + c·120 + j", "21 bloques SB_RAM40_4K",
                                                                  "inicializados desde canny98_w.hex"])
sp = caja(d, 1250, 420, 320, 105, "SB_SPRAM256KA  ·  h[0..119]", ["las 120 activaciones de 8 bits", "no necesita inicializarse"], "#fdf3e8", NA_B)
linea(d, ent, e1, "in_valid, in_pix,<br>thr_hi, thr_lo", "exitX=1;exitY=0.3;entryX=0;entryY=0.4;", pts=[(270, 369), (270, 277)])
linea(d, e4, tr, "frame_done", "exitX=1;exitY=0.5;entryX=0.3;entryY=1;", pts=[(722, 550)])
linea(d, e3, tr, "rd_a / rd_d", "exitX=1;exitY=0.4;entryX=0;entryY=0.4;")
linea(d, tr, fm, "wr_en, wr_addr,<br>wr_data", "exitX=1;exitY=0.3;entryX=0;entryY=0.5;", pts=[(870, 381), (870, 280)])
linea(d, fm, l1, "f[k]"); linea(d, l1, l2, "")
linea(d, wm, l1, "W1", "exitX=0;exitY=0.6;entryX=1;entryY=0.3;", pts=[(1222, 315), (1222, 420)])
linea(d, wm, l2, "W2", "exitX=0;exitY=0.85;entryX=1;entryY=0.4;", pts=[(1236, 352), (1236, 597)])
linea(d, l1, sp, "h8, escribe_h", "exitX=1;exitY=0.8;entryX=0;entryY=0.5;")
linea(d, sp, l2, "h[j]", "exitX=0.5;exitY=1;entryX=1;entryY=0.8;", pts=[(1410, 639)])
linea(d, e4, l2, "n_bordes", "exitX=0.5;exitY=1;entryX=0.5;entryY=1;dashed=1;", pts=[(470, 700), (1055, 700)])
linea(d, l2, ver, "", "exitX=1;exitY=0.2;entryX=0;entryY=0.5;", pts=[(1630, 576), (1630, 390)])
puertos(d, "Los puertos de mnist_top98", [
    "in      clk,  reset,  in_valid,  in_pix[7:0],  thr_hi[7:0],  thr_lo[7:0]",
    "out     done,  digito[3:0],  valido",
    "Los mismos que mnist_top78: en la tarjeta se cambió sólo el clasificador, y el puerto serie o la cámara quedan igual.",
    "<b>Todo el chip en la iCE40UP5K:</b> 2 380 celdas lógicas (45 %) · 30 / 30 BRAM · 1 / 4 SPRAM · 17,76 MHz · 21 992 ciclos por imagen"])
d.guardar("pac_canny98.drawio")
print("ok")
