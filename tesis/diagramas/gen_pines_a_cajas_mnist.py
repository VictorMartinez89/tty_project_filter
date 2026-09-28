# gen_pines_a_cajas_mnist.py — «De los pines a las cajas» de los cinco reconocedores de la §6.3.
# Fuentes: Verilog_Repo/pan_sobel, pan_canny, vision_sobel_mnist, vision_canny_mnist y canny78/asic.
from dio import Diagrama
from pac_estilo import *


# ---------------------------------------------------------------- Pan Sobel / Pan Canny
def pan(nombre, modulo, soc_top, fw, umbr, feat, feat_l, clf, clf_l, obs):
    d = Diagrama(nombre, 1900, 900)
    titulo(d, f"De los pines a las cajas: {modulo}, el reconocedor con procesador",
           "Cámara OV7670 → ventana central de 28×28 → SoC Femto (el umbral lo escribe el programa) → "
           "bordes por zona y orientación → clasificador → 0..9 o NADA. Sin framebuffer y sin pantalla.")
    marco(d, 250, 100, 1400, 640, f"module {modulo}   —   {modulo}.v", "#fbfcfe", AZUL_M, dash=False)
    marco(d, 280, 142, 1340, 572, "un solo reloj:  pclk, el reloj de píxel de la cámara", AZ_F, AZ_B)
    cam = ext(d, 40, 440, 170, 200, "Cámara OV7670", ["fuera del chip", "pclk · href · sync", "pix_y[7:0] · pix_valid",
                                                      "(la luma ya extraída)"])
    win = caja(d, 305, 440, 215, 200, "cam_win28   WIN", ["ventana central 448 × 448", "bloques de 16 × 16 → 28 × 28",
                                                         "promedio: suma &gt;&gt; 8", "invertir = 1 (trazo claro)"])
    marco(d, 550, 180, 1050, 510, f"{soc_top}   CLF", "#ffffff", AZUL_M, fs=12)
    soc = caja(d, 580, 225, 330, 150, "soc_ctrl   SOC", ["FemtoRV32 + ROM de 7 instrucciones", "peripheral_filter en 0x0045",
                                                        f"el programa escribe {fw}", f"→ {umbr}"], "#e8f0fb", "#1f4e79")
    fe = caja(d, 580, 450, 330, 210, feat, feat_l, "#ffffff", ROJO)
    cl = caja(d, 1000, 450, 330, 210, clf, clf_l, "#ffffff", ROJO)
    ver = ext(d, 1700, 470, 175, 110, "Veredicto", ["done · digito[3:0]", "valido (0 = NADA)"])
    ob = ext(d, 1700, 250, 175, 100, "Observabilidad", obs)
    linea(d, cam, win, "", "exitX=1;exitY=0.5;entryX=0;entryY=0.5;")
    linea(d, win, fe, "w_valid, w_pix")
    linea(d, soc, fe, "umbral", "exitX=0.5;exitY=1;entryX=0.5;entryY=0;")
    linea(d, fe, cl, "32 contadores<br>n_bordes · frame_done")
    linea(d, cl, ver, "", "exitX=1;exitY=0.3;entryX=0;entryY=0.5;")
    linea(d, cl, fe, "clr ← done", "exitX=0.5;exitY=1;entryX=0.5;entryY=1;dashed=1;", pts=[(1165, 700), (745, 700)])
    linea(d, soc, ob, "", "exitX=1;exitY=0.5;entryX=0;entryY=0.5;")
    puertos(d, f"Los puertos de {modulo}", [
        "in      pclk,  reset,  href,  sync,  pix_y[7:0],  pix_valid",
        "out     done,  digito[3:0],  valido,  " + ",  ".join(o.replace(" · ", ",  ") for o in obs),
        "En silicio son pads del anillo de E/S. No hay .pcf ni segundo reloj: todo corre al ritmo de la cámara."])
    d.guardar(f"{nombre}.drawio")


pan("pac_pan_sobel", "pan_sobel", "soc_mnist_top", "0x5A00", "thr = 90",
    "mnist_feat   FEAT", ["Gaussiano 3×3 → Sobel 3×3", "|Gx|+|Gy| &gt; thr → borde", "octante: 3 comparaciones",
                          "4 zonas × 8 octantes", "= 32 contadores de 9 bits"],
    "mnist_clf   CLF", ["40 rasgos: 32 + 8 derivados", "400 pesos de 4 bits, ROM", "una MAC por ciclo, argmax",
                        "NADA si bordes ∉ [140, 430]", "o margen &lt; 30"],
    ["thr_usado[7:0]", "cpu_escribio"])
pan("pac_pan_canny", "pan_canny", "soc_mnist_canny_fw_top", "0x5A20", "thr_hi = 90, thr_lo = 32",
    "mnist_feat_canny   FEAT", ["Gaussiano → Sobel → doble umbral", "→ histéresis de un salto",
                                "{octante, clase} en 5 bits", "por la tercera ventana", "= 32 contadores de 9 bits"],
    "mnist_clf_canny_fw   CLF", ["40 rasgos: 32 + 8 derivados", "pesos entrenados con el Canny", "una MAC por ciclo, argmax",
                                 "NADA si bordes ∉ [174, 376]", "o margen &lt; 70"],
    ["thr_hi_o · thr_lo_o", "cpu_escribio"])


# ---------------------------------------------------------------- Visión Sobel / Canny MNIST
def vision(nombre, modulo, top, umbr):
    d = Diagrama(nombre, 1900, 900)
    titulo(d, f"De los pines a las cajas: {modulo}, el chip que ve, reconoce y muestra",
           "Cámara OV7670 → ventana de 28×28 → clasificador → pantalla ILI9341 con la ventana ampliada, "
           "el marco verde y el dígito en siete segmentos. Sin computador de por medio.")
    marco(d, 250, 100, 1400, 640, f"module {modulo}   —   {modulo}.v", "#fbfcfe", AZUL_M, dash=False)
    marco(d, 280, 142, 1340, 210, "dominio  clk", AZ_F, AZ_B)
    marco(d, 280, 452, 1340, 262, "dominio  cam_pclk", NA_F, NA_B)
    k_clk = caja(d, 40, 200, 165, 60, "clk · rst_n", ["reloj del sistema"], "#ebebeb", GRIS_T)
    cam = ext(d, 40, 520, 165, 140, "Cámara OV7670", ["módulo externo"])
    tft = ext(d, 1700, 195, 175, 110, "Pantalla TFT", ["ILI9341"])
    est = ext(d, 1700, 395, 175, 90, "Estado", ["cfg_done · hubo", "digito[3:0]"])
    sccb = caja(d, 310, 195, 200, 110, "Configuración SCCB", ["COM7, COM8, COM9", "cam_sda_o / _oe"])
    syn = caja(d, 560, 195, 190, 110, "Sincronizador", ["dig_s1 → dig_clk", "hubo_s1 → hubo_clk", "2 biestables"], "#fff3cd", "#b8860b")
    ctl = caja(d, 1060, 185, 290, 130, "Controlador ILI9341", ["filas 0-223: 28×28 ampliada ×8", "marco verde de 3 píxeles",
                                                             "filas 232-319: el dígito", "glifo de siete segmentos (glifo.v)"])
    fb = mem(d, 880, 370, 520, 64, "fb[0:783]   ·   28 × 28 × 8 bits", ["escribe @cam_pclk (w_pix)   ·   lee @clk   —   CRUCE DE DOMINIOS"])
    cap = caja(d, 305, 505, 230, 160, "Captura de la luma", ["parity: el 2.º byte de U Y V Y", "curY, py_valid"])
    win = caja(d, 565, 505, 230, 160, "cam_win28   WIN", ["ventana central 448 × 448", "→ 28 × 28, promedio", "invertir = 1"])
    clf = caja(d, 825, 505, 290, 160, f"{top}   CLF", ["extractor + clasificador", "de 40 rasgos, verificado", "bit a bit contra el modelo", umbr],
               "#ffffff", ROJO)
    dg = caja(d, 1145, 505, 200, 160, "dig_pclk · hubo", ["el último veredicto", "NADA → código 10", "(el glifo dibuja una raya)"])
    linea(d, k_clk, sccb, "clk", "exitX=1;exitY=0.5;entryX=0;entryY=0.5;")
    linea(d, k_clk, cam, "cam_xclk", "exitX=0.5;exitY=1;entryX=0.5;entryY=0;")
    linea(d, sccb, cam, "cam_scl<br>cam_sda_o / _oe", "exitX=0;exitY=0.8;entryX=1;entryY=0.15;dashed=1;startArrow=block;startFill=1;",
          pts=[(230, 283), (230, 541)])
    linea(d, cam, cap, "", "exitX=1;exitY=0.5;entryX=0;entryY=0.5;")
    d.texto("cam_pclk · cam_href<br>cam_d[7:0]", 40, 668, 220, 36, fs=11, extra=F + "align=left;")
    linea(d, cap, win, "curY")
    linea(d, win, clf, "w_valid, w_pix")
    linea(d, win, fb, "w_pix", "exitX=0.5;exitY=0;entryX=0.1;entryY=1;", pts=[(680, 470), (932, 470)])
    linea(d, clf, dg, "digito, valido")
    linea(d, dg, syn, "", "exitX=0.5;exitY=0;entryX=0.5;entryY=1;dashed=1;", pts=[(1245, 460), (1460, 460), (1460, 345), (655, 345)])
    linea(d, syn, ctl, "dig_clk, hubo_clk")
    linea(d, fb, ctl, "fb_rd", "exitX=0.6;exitY=0;entryX=0.5;entryY=1;")
    linea(d, ctl, tft, "tft_sck · tft_mosi<br>tft_cs · tft_dc", "exitX=1;exitY=0.5;entryX=0;entryY=0.5;")
    linea(d, syn, est, "digito", "exitX=0.5;exitY=0;entryX=1;entryY=0.5;dashed=1;", pts=[(655, 165), (1890, 165), (1890, 440)])
    puertos(d, f"Los puertos de {modulo}", [
        "in      clk,  rst_n,  cam_pclk,  cam_href,  cam_d[7:0]",
        "out     cam_xclk,  cam_scl,  cam_sda_o,  cam_sda_oe,  tft_sck,  tft_mosi,  tft_cs,  tft_dc,  cfg_done,  hubo,  digito[3:0]",
        "En silicio son pads del anillo de E/S; SIOD se parte en dato y habilitación y el triestado lo hace el pad."])
    d.guardar(f"{nombre}.drawio")


vision("pac_vision_sobel_mnist", "vision_sobel_mnist", "mnist_top", "umbral cableado: 60")
vision("pac_vision_canny_mnist", "vision_canny_mnist", "mnist_top_canny", "umbrales cableados: 110 / 40")


# ---------------------------------------------------------------- Canny-78
d = Diagrama("pac_canny78", 1900, 900)
titulo(d, "De los pines a las cajas: mnist_top78, el reconocedor Canny-78",
       "Píxel → Canny de un salto → 16 zonas × 8 octantes en memoria → trasvase → clasificador de 78 rasgos, "
       "dos clases por pasada → 0..9 o NADA. El mismo RTL en la tarjeta y en silicio.")
marco(d, 250, 100, 1400, 640, "module mnist_top78   —   mnist_top78.v", "#fbfcfe", AZUL_M, dash=False)
marco(d, 280, 142, 1340, 572, "un solo reloj:  clk", AZ_F, AZ_B)
ent = ext(d, 40, 300, 170, 230, "Entrada", ["clk · reset", "in_valid", "in_pix[7:0]", "thr_hi[7:0] = 90", "thr_lo[7:0] = 32"])
ver = ext(d, 1700, 330, 175, 120, "Veredicto", ["done", "digito[3:0]", "valido (0 = NADA)"])
marco(d, 305, 180, 420, 500, "mnist_feat16_mem   ext", "#ffffff", ROJO, fs=12)
e1 = caja(d, 330, 220, 370, 110, "Canny de un salto", ["Gaussiano → Sobel → doble umbral", "→ histéresis, tres linebuf3x3"])
e2 = caja(d, 330, 355, 370, 90, "Octante y zona", ["{sgn Gy, sgn Gx, |Gy| &gt; |Gx|}", "rejilla de 4 × 4 zonas sobre 28 × 28"])
e3 = mem(d, 330, 470, 370, 110, "128 contadores en memoria síncrona", ["16 zonas × 8 octantes × 9 bits", "leer uno cuesta 17 LUT, no 1 323",
                                                                      "borrado secuencial, un solo puerto"])
e4 = caja(d, 330, 600, 370, 60, "frame_done · n_bordes", [])
linea(d, e1, e2, ""); linea(d, e2, e3, "borde → cuenta"); linea(d, e3, e4, "")
tr = caja(d, 765, 330, 330, 200, "Trasvase", ["ts: T_IDLE → T_COPIA → T_ARR", "128 lecturas encadenadas:", "rd_a → rd_d → wr_addr",
                                              "rd_clr vacía cada contador", "130 ciclos; reanuda el extractor"], "#e8f0fb", "#1f4e79")
marco(d, 1130, 180, 460, 500, "mnist_clf78_x2   clf", "#ffffff", ROJO, fs=12)
c1 = mem(d, 1155, 220, 410, 120, "fmem: las 168 características", ["0..127   nivel 2: los contadores", "128..159   nivel 1: sumas de 4 zonas",
                                                                   "160..167   nivel 0: sumas de 16 zonas"])
c2 = caja(d, 1155, 365, 410, 120, "78 rasgos elegidos · 780 pesos de 4 bits", ["dos clases por pasada: una lectura del rasgo,",
                                                                                "los dos pesos en la misma palabra de 8 bits"])
c3 = caja(d, 1155, 510, 410, 130, "argmax y regla de rechazo", ["el mejor contra el segundo: margen", "densidad de bordes plausible",
                                                                 "si falla → valido = 0 (NADA)", "647 ciclos + 130 del trasvase = 777 &lt; 784"])
linea(d, c1, c2, ""); linea(d, c2, c3, "")
linea(d, ent, e1, "in_valid, in_pix,<br>thr_hi, thr_lo", "exitX=1;exitY=0.3;entryX=0;entryY=0.5;", pts=[(270, 369), (270, 275)])
linea(d, e4, tr, "frame_done", "exitX=1;exitY=0.5;entryX=0.3;entryY=1;", pts=[(864, 630)])
linea(d, e3, tr, "rd_a / rd_d, rd_clr", "exitX=1;exitY=0.3;entryX=0;entryY=0.6;")
linea(d, tr, c1, "wr_en, wr_addr, wr_data", "exitX=1;exitY=0.3;entryX=0;entryY=0.5;")
linea(d, tr, c3, "arranca", "exitX=1;exitY=0.85;entryX=0;entryY=0.5;")
linea(d, e4, c3, "n_bordes", "exitX=0.5;exitY=1;entryX=0.5;entryY=1;dashed=1;", pts=[(515, 700), (1360, 700)])
linea(d, c3, ver, "", "exitX=1;exitY=0.3;entryX=0;entryY=0.5;", pts=[(1640, 549), (1640, 390)])
puertos(d, "Los puertos de mnist_top78", [
    "in      clk,  reset,  in_valid,  in_pix[7:0],  thr_hi[7:0],  thr_lo[7:0]",
    "out     done,  digito[3:0],  valido",
    "El mismo fichero va a la tarjeta (con el puerto serie o con la cámara y la pantalla alrededor) y a sky130."])
d.guardar("pac_canny78.drawio")
print("ok")
