# gen_pines_a_cajas_serie.py — «De los pines a las cajas» para los cuatro diseños en la iCESugar, con el
# estilo de fig_pines_a_cajas (el del Sobel): módulo top, dominio clk arriba, dominio cam_pclk abajo, el
# framebuffer como cruce entre los dos, y los pines del .pcf probado (scl 27 / sda 26, desde el 22-jul).
# Los nombres y los umbrales salen de los tops que corrieron en la placa:
#   Sobel      ~/utm-share/cam_sobel_display.v   (mag > 90)
#   Canny      ~/utm-share/cam_canny2_display.v  (fuerte > 50, débil > 20)
#   transitivo Verilog_Repo/fpga/share/femto_canny_transitivo/cam_trans_display.v  (60 / 30)
#   SoC        Verilog_Repo/fpga/share/femto_sobel/cam_femto_display.v  (umbral del CPU)
from dio import Diagrama, AZUL

GRIS_T, VERDE, VERDE_B = "#666666", "#dff0d8", "#4a8a3f"
AZ_F, AZ_B, NA_F, NA_B = "#eef4fb", "#4a7ebb", "#fdf3e8", "#c47f2a"
F = "fontFamily=Helvetica;"


def det(tit, lineas, fs=13):
    s = f"<b style='font-size:{fs}px'>{tit}</b>"
    for l in lineas:
        s += f"<br><span style='font-size:10.5px;color:#777777'>{l}</span>"
    return s


def marco(d, x, y, w, h, tit, relleno, borde, dash=True, fs=14):
    return d.v(tit, x, y, w, h, f"rounded=1;arcSize=3;html=1;whiteSpace=wrap;align=left;verticalAlign=top;"
               f"spacingLeft=14;spacingTop=6;fontSize={fs};fontStyle=1;fontColor={borde};fillColor={relleno};"
               f"strokeColor={borde};strokeWidth=1.6;{'dashed=1;' if dash else ''}{F}")


def caja(d, x, y, w, h, tit, lineas=(), relleno="#ffffff", borde="#333333", fs=13):
    return d.v(det(tit, lineas, fs), x, y, w, h, f"rounded=1;arcSize=6;html=1;whiteSpace=wrap;fillColor={relleno};"
               f"strokeColor={borde};strokeWidth=1.6;{F}")


def linea(d, a, b, lab="", extra="", pts=()):
    return d.flecha(a, b, lab, extra="strokeColor=#444444;strokeWidth=1.8;fontFamily=Helvetica;fontSize=11;"
                    "endSize=8;" + extra, pts=pts, fs=11)


def tarjeta(nombre, titulo, subtitulo, fichero, clk_extra, pipeline, led, puertos, salida_fb, pclk_extra=None):
    d = Diagrama(nombre, 1900, 900)
    d.texto(f"<b>{titulo}</b><br><span style='font-size:13px;color:#666666'>{subtitulo}</span>",
            40, 16, 1500, 56, fs=19, extra=F + "align=left;verticalAlign=top;")
    marco(d, 250, 100, 1400, 640, f"module top   —   {fichero}", "#fbfcfe", "#2f4f8f", dash=False)
    marco(d, 280, 142, 1340, 210, "dominio  clk", AZ_F, AZ_B)
    marco(d, 280, 452, 1340, 262, "dominio  cam_pclk", NA_F, NA_B)
    # externos
    k_clk = caja(d, 40, 200, 165, 60, "clk", ["pin 35"], "#ebebeb", GRIS_T)
    k_cam = caja(d, 40, 520, 165, 140, "Cámara OV7670", ["módulo externo"], VERDE, VERDE_B)
    k_tft = caja(d, 1700, 195, 175, 110, "Pantalla TFT", ["ILI9341"], VERDE, VERDE_B)
    k_led = caja(d, 1700, 395, 175, 90, "LED RGB", ["estado"], VERDE, VERDE_B)
    # dominio clk
    k_sccb = caja(d, 310, 195, 200, 110, "Configuración SCCB", ["escribe los registros", "de la cámara al arrancar"])
    k_ctl = caja(d, 1130, 195, 215, 110, "Controlador ILI9341", ["spi_start, spi_byte,", "spi_dcbit, spi_done"])
    k_rgb = caja(d, 1385, 195, 205, 110, "SB_RGBA_DRV", ["primitiva de la iCE40"] + led)
    extra_clk = clk_extra(d) if clk_extra else {}
    # framebuffer, el cruce de dominios
    k_fb = d.v(det("Frame buffer   fb[0:4799]   ·   60 × 80",
                   ["escribe @posedge cam_pclk   ·   lee @clk   —   CRUCE DE DOMINIOS"]),
               880, 370, 560, 64, f"rounded=1;arcSize=8;html=1;whiteSpace=wrap;fillColor=#fff3cd;"
               f"strokeColor=#b8860b;strokeWidth=1.6;{F}")
    # dominio cam_pclk: el cauce
    n = len(pipeline)
    x0, x1, gap = 305, 1595, 28
    w = (x1 - x0 - gap * (n - 1)) / n
    K = []
    for k, (t, ls, *_) in enumerate(pipeline):
        K.append(caja(d, round(x0 + k * (w + gap)), 505, round(w), 160, t, ls))
    if pclk_extra:
        pclk_extra(d, K)
    # conexiones
    linea(d, k_clk, k_sccb, "clk", "exitX=1;exitY=0.5;entryX=0;entryY=0.5;")
    linea(d, k_clk, k_cam, "cam_xclk · pin 2", "exitX=0.5;exitY=1;entryX=0.5;entryY=0;")
    linea(d, k_sccb, k_cam, "cam_scl · pin 27<br>cam_sda · pin 26 (inout)",
          "exitX=0;exitY=0.8;entryX=1;entryY=0.15;dashed=1;startArrow=block;startFill=1;", pts=[(230, 283), (230, 541)])
    linea(d, k_cam, K[0], "", "exitX=1;exitY=0.5;entryX=0;entryY=0.5;")
    d.texto("cam_pclk 28 · cam_href 32<br>cam_d[7:0] → 48 46 44 43 38 34 31 42", 20, 668, 300, 36, fs=11,
            extra=F + "align=left;")
    for k in range(n - 1):
        linea(d, K[k], K[k + 1], pipeline[k + 1][2] if len(pipeline[k + 1]) > 2 else "")
    linea(d, K[salida_fb[0]], k_fb, salida_fb[1], "exitX=0.5;exitY=0;entryX=0.8;entryY=1;")
    linea(d, k_fb, k_ctl, "fb_rd", "exitX=0.5;exitY=0;entryX=0.5;entryY=1;", pts=[(1160, 352), (1237, 352)])
    linea(d, k_ctl, k_tft, "tft_sck 37 · tft_mosi 36<br>tft_cs 25 · tft_dc 23",
          "exitX=0.5;exitY=0;entryX=0;entryY=0.3;", pts=[(1237, 170), (1660, 170), (1660, 228)])
    linea(d, k_rgb, k_led, "led_r 39 · led_g 40 · led_b 41", "exitX=0.5;exitY=1;entryX=0;entryY=0.5;",
          pts=[(1487, 440)])
    # puertos
    d.v("<b>Los 14 puertos de top</b><br>" + "<br>".join(puertos), 40, 760, 900, 120,
        f"rounded=1;arcSize=6;html=1;whiteSpace=wrap;align=left;verticalAlign=top;spacingLeft=14;spacingTop=8;"
        f"fontSize=11;fontColor=#555555;fillColor=#ffffff;strokeColor=#aaaaaa;{F}")
    d.guardar(f"{nombre}.drawio")
    return d, extra_clk


PUERTOS = ["in     clk,  cam_pclk,  cam_href,  cam_d[7:0]",
           "out    cam_xclk,  cam_scl,  tft_sck,  tft_mosi,  tft_cs,  tft_dc,  led_r,  led_g,  led_b",
           "inout  cam_sda",
           "cam_d[7:0]  →  pines 48  46  44  43  38  34  31  42"]
SUB = ("Submuestreo a 60 × 80", ["href_d, parity, curY,", "colkeep, rowkeep, fbx,", "waddr_wr"])

# ---------------------------------------------------------------- Sobel
tarjeta("pac_sobel", "De los pines a las cajas: iCESugar iCE40UP5K + filtro Sobel 3×3",
        "Cámara OV7670 → Sobel → pantalla ILI9341. Sin computador de por medio.", "cam_sobel_display.v", None,
        [SUB,
         ("Line buffers + ventana 3×3", ["dline1[0:59]  fila n−1", "dline2[0:59]  fila n−2", "t00 … t22  (9 taps)"], "píxel 8 bit"),
         ("Sobel 3×3", ["gxp, gxn, gyp, gyn  (1-2-1)", "agx = |gxp − gxn|", "agy = |gyp − gyn|"], "t00 … t22"),
         ("Magnitud y umbral", ["mag12 = agx + agy", "mag = saturada a 8 bit", "mag &gt; 90 ? FF : 00"], "agx, agy")],
        ["VERDE = cámara lista", "AZUL = latido"], PUERTOS, (3, "we, wadr, wdat"))

# ---------------------------------------------------------------- Canny de un salto
tarjeta("pac_canny", "De los pines a las cajas: iCESugar iCE40UP5K + filtro Canny de un salto",
        "Cámara OV7670 → Gaussiano 3×3 → Sobel 3×3 → doble umbral → histéresis → borde 0xFF / 0x00 → "
        "pantalla ILI9341. Sin computador de por medio.", "cam_canny2_display.v", None,
        [SUB,
         ("Gaussiano 3×3", ["gline1, gline2 [0:59]", "g00 … g22", "gout = gsum[11:4]  (÷16)"], "píxel 8 bit"),
         ("Sobel 3×3", ["sline1, sline2 [0:59]", "s00 … s22", "mag = sat(agx + agy)"], "gout"),
         ("Doble umbral", ["cls_in, 2 bits:", "mag &gt; 50 → 2 fuerte", "mag &gt; 20 → 1 débil"], "mag"),
         ("Histéresis de un salto", ["cline1, cline2 [0:59]  (2 bits)", "c00 … c22, any_strong", "edge_px ? FF : 00"], "cls_in")],
        ["VERDE = cámara lista", "AZUL = latido"], PUERTOS, (4, "we, wadr, wdat"))

# ---------------------------------------------------------------- Canny transitivo
def trans_extra(d, K):
    w = (1595 - 305 - 28 * 5) / 6
    xa = 305 + (w + 28) - 12; xb = 305 + 4 * (w + 28) + w + 12
    d.v("filter_multi_wh  FLT   ·   modo 2, umbrales 60 / 30", round(xa), 480, round(xb - xa), 198,
        f"rounded=1;arcSize=4;html=1;align=left;verticalAlign=top;spacingLeft=10;spacingTop=2;fontSize=12;"
        f"fontStyle=1;fontColor=#c0392b;fillColor=none;strokeColor=#c0392b;dashed=1;{F}")
tarjeta("pac_trans", "De los pines a las cajas: iCESugar iCE40UP5K + Canny transitivo",
        "Cámara OV7670 → Gaussiano → Sobel → doble umbral → cuadro de clases → motor a punto fijo → "
        "pantalla ILI9341. Sin computador de por medio.", "cam_trans_display.v", None,
        [SUB,
         ("Gaussiano, Sobel y clase", ["tres linebuf3x3:", "LBG, LBS, LBC", "cls_in, 2 bits"], "curY"),
         ("clsfb_spram", ["el cuadro de clases", "60 × 80 × 2 bits", "en SPRAM"], "cls_in"),
         ("Motor transitivo", ["hysteresis_frame_", "bram_sync  ENG", "barre hasta que", "nada cambia"], "cls_rd"),
         ("spram_fb", ["el mapa de bordes", "60 × 80 × 1 bit", "en SPRAM"], "eng_edge"),
         ("Control por cuadro", ["cst: FILL → DRAIN → GO", "→ WAIT → COPY → HOLD", "rd_bit ? FF : 00"], "rd_bit")],
        ["ROJO = motor barriendo", "VERDE = cámara lista", "AZUL = latido"], PUERTOS, (5, "fb_we, fb_wa, fb_wd"),
        pclk_extra=trans_extra)

# ---------------------------------------------------------------- SoC Femto + Sobel
def soc_extra(d):
    cpu = caja(d, 560, 190, 170, 120, "FemtoRV32", ["el procesador", "reset de encendido", "cpu_resetn"],
               "#e8f0fb", AZUL)
    ram = caja(d, 760, 180, 160, 64, "RAM 4 KB", ["4 BRAM · el firmware"])
    per = caja(d, 760, 256, 160, 76, "peripheral_filter", ["0x0045", "mode, thr_hi"])
    linea(d, cpu, ram, "", "exitX=1;exitY=0.3;entryX=0;entryY=0.5;startArrow=block;startFill=1;")
    linea(d, cpu, per, "cs_filter", "exitX=1;exitY=0.75;entryX=0;entryY=0.5;")
    cdc = caja(d, 950, 256, 150, 76, "CDC  2-FF", ["thi_p, mode_p", "clk → cam_pclk"], "#fff3cd", "#b8860b")
    linea(d, per, cdc, "flt_thi")
    SOC["cdc"] = cdc
    return {"cdc": cdc}
K3X = round(305 + 3 * ((1595 - 305 - 28 * 3) / 4 + 28) + ((1595 - 305 - 28 * 3) / 4) / 2)
SOC = {}
def soc_pclk(d, K):
    linea(d, SOC["cdc"], K[3], "thi_p", "exitX=0.5;exitY=1;entryX=0.25;entryY=0;", pts=[(1025, 352), (860, 352), (860, 485), (K3X - 75, 485)])
d, ex = tarjeta("pac_soc_sobel", "De los pines a las cajas: iCESugar iCE40UP5K + SoC Femto con filtro Sobel",
                "Cámara OV7670 → Sobel → pantalla ILI9341; el umbral lo escribe el FemtoRV32 en el periférico 0x0045.",
                "cam_femto_display.v", soc_extra,
                [SUB,
                 ("linebuf3x3  LB", ["en BRAM", "w00 … w22  (9 taps)", "lbv"], "lb_pix"),
                 ("Sobel 3×3", ["gxp, gxn, gyp, gyn  (1-2-1)", "agx = |gxp − gxn|", "agy = |gyp − gyn|"], "w00 … w22"),
                 ("Magnitud y umbral", ["mag = sat(agx + agy)", "mag &gt; thi_p ? FF : 00", "umbral del CPU (90)"], "agx, agy")],
                ["ROJO = el CPU escribió 0x0045", "VERDE = cámara lista", "AZUL = latido"], PUERTOS, (3, "we, wadr, wdat"),
                pclk_extra=soc_pclk)
print("ok")

