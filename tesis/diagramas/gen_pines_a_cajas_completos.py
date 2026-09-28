# gen_pines_a_cajas_completos.py — «De los pines a las cajas» de las dos cadenas completas para silicio,
# con el estilo de gen_pines_a_cajas_serie.py. Aquí no hay .pcf: los puertos son pads del anillo de E/S,
# y hay UN SOLO RELOJ (clk): cam_frontend_top sincroniza PCLK/HREF/VSYNC con dos biestables.
# Fuentes: Verilog_Repo/completos/canny1_completo/ y Verilog_Repo/completos/trans_completo/.
from dio import Diagrama

GRIS_T, VERDE, VERDE_B = "#666666", "#dff0d8", "#4a8a3f"
AZ_F, AZ_B = "#eef4fb", "#4a7ebb"
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


def fb(d, x, y, w, h, tit, lineas):
    return caja(d, x, y, w, h, tit, lineas, "#fff3cd", "#b8860b")


def linea(d, a, b, lab="", extra="", pts=()):
    return d.flecha(a, b, lab, extra="strokeColor=#444444;strokeWidth=1.8;fontFamily=Helvetica;fontSize=11;"
                    "endSize=8;" + extra, pts=pts, fs=11)


def base(nombre, titulo, subtitulo, modulo, fichero):
    d = Diagrama(nombre, 1900, 900)
    d.texto(f"<b>{titulo}</b><br><span style='font-size:13px;color:#666666'>{subtitulo}</span>",
            40, 16, 1600, 56, fs=19, extra=F + "align=left;verticalAlign=top;")
    marco(d, 250, 100, 1400, 640, f"module {modulo}   —   {fichero}", "#fbfcfe", "#2f4f8f", dash=False)
    marco(d, 280, 142, 1340, 572, "un solo reloj:  clk   (la cámara entra por 2 biestables de sincronización)",
          AZ_F, AZ_B)
    E = {}
    E["clk"] = caja(d, 40, 190, 165, 70, "clk · rst_n", ["reloj del sistema", "reinicio asíncrono"], "#ebebeb", GRIS_T)
    E["cam"] = caja(d, 40, 330, 165, 150, "Cámara OV7670", ["módulo externo"], VERDE, VERDE_B)
    E["tft"] = caja(d, 1700, 500, 175, 110, "Pantalla TFT", ["ILI9341"], VERDE, VERDE_B)
    E["est"] = caja(d, 1700, 190, 175, 80, "Estado", ["cfg_done ← ov7670_sccb", "init_done ← lcd_ili9341_top"], VERDE, VERDE_B)
    # cam_frontend_top
    marco(d, 300, 180, 580, 210, "cam_frontend_top   u_fe", "#ffffff", "#2f4f8f", fs=12)
    E["sccb"] = caja(d, 315, 215, 165, 150, "ov7670_sccb", ["configura la cámara", "al arrancar", "SIOD: dato + enable"])
    E["cap"] = caja(d, 495, 215, 185, 150, "ov7670_capture", ["genera cam_xclk", "PCLK/HREF/VSYNC → 2-FF", "2 bytes → RGB565"])
    E["gray"] = caja(d, 695, 215, 170, 150, "rgb565_to_gray", ["Y = (R + 2G + B) &gt;&gt; 2", "sin multiplicar", "gray, gray_valid"])
    linea(d, E["sccb"], E["cam"], "cam_sioc<br>cam_siod_o / _oe", "exitX=0;exitY=0.85;entryX=1;entryY=0.2;dashed=1;"
          "startArrow=block;startFill=1;", pts=[(240, 343), (240, 360)])
    linea(d, E["cam"], E["cap"], "cam_d[7:0] · cam_pclk<br>cam_href · cam_vsync", "exitX=1;exitY=0.45;entryX=0.62;entryY=1;",
          pts=[(610, 397)])
    linea(d, E["cap"], E["cam"], "cam_xclk", "exitX=0.8;exitY=1;entryX=1;entryY=0.83;", pts=[(643, 455)])
    linea(d, E["cap"], E["gray"], "px565")
    linea(d, E["clk"], E["sccb"], "clk", "exitX=1;exitY=0.5;entryX=0;entryY=0.2;", pts=[(260, 225), (260, 245)])
    return d, E


def lcd_y_lectura(d, E, fuente, nombre_fb):
    E["lec"] = caja(d, 1110, 500, 200, 150, "Lectura para la pantalla", ["xcol, ycol  (240 × 320)", "fx = xcol / 4, fy = ycol / 4",
                                                                        f"raddr = fy·60 + fx", f"{nombre_fb} → 0xFF / 0x00"])
    E["lcd"] = caja(d, 1340, 480, 260, 190, "lcd_ili9341_top   u_lcd", ["shifter SPI, modo 0", "ROM de comandos INIT y FRAME",
                                                                      "BOOT → INIT → FRAME → FILL", "gris → RGB565", "240 × 320 píxeles"])
    linea(d, fuente, E["lec"], "")
    linea(d, E["lec"], E["lcd"], "pix_gray = fb_rd", "exitX=1;exitY=0.35;entryX=0;entryY=0.35;")
    linea(d, E["lcd"], E["lec"], "pix_next, frame_start", "exitX=0;exitY=0.8;entryX=1;entryY=0.8;")
    linea(d, E["lcd"], E["tft"], "tft_sck · tft_mosi<br>tft_cs · tft_dc", "exitX=1;exitY=0.5;entryX=0;entryY=0.5;")
    linea(d, E["lcd"], E["est"], "init_done", "exitX=0.5;exitY=0;entryX=0;entryY=0.8;dashed=1;", pts=[(1470, 254)])


def puertos(d, modulo):
    d.v(f"<b>Los 18 puertos de {modulo}</b><br>"
        "in      clk,  rst_n,  cam_d[7:0],  cam_pclk,  cam_href,  cam_vsync<br>"
        "out     cam_xclk,  cam_sioc,  cam_siod_o,  cam_siod_oe,  tft_sck,  tft_mosi,  tft_cs,  tft_dc,  cfg_done,  init_done<br>"
        "En silicio no hay .pcf: cada puerto es un pad del anillo de E/S. SIOD se parte en dato y habilitación,"
        " y el triestado lo hace el pad.",
        40, 760, 1100, 110, f"rounded=1;arcSize=6;html=1;whiteSpace=wrap;align=left;verticalAlign=top;spacingLeft=14;"
        f"spacingTop=8;fontSize=11;fontColor=#555555;fillColor=#ffffff;strokeColor=#aaaaaa;{F}")


# ---------------------------------------------------------------- canny1_completo
d, E = base("pac_canny1_completo", "De los pines a las cajas: canny1_completo, la cadena del Canny de un salto para silicio",
            "Cámara OV7670 → gris → Gaussiano 3×3 → Sobel 3×3 → doble umbral → histéresis → framebuffer de 1 bit → "
            "pantalla ILI9341. Sin computador de por medio.", "canny1_completo", "canny1_completo.v")
can = caja(d, 920, 215, 330, 150, "canny1_top   u_can", ["Gaussiano 3×3 → Sobel 3×3", "→ doble umbral 90 / 40",
                                                          "→ histéresis de un salto", "tres linebuf3x3 (LBG, LBS, LBC)"],
           "#ffffff", "#c0392b")
linea(d, E["gray"], can, "gray, gray_valid")
f1 = fb(d, 830, 500, 240, 150, "fb[0:4799]   ·   60 × 80", ["1 bit por píxel", "fb[wadr] ← can_p[7]", "4 800 biestables, no 38 400",
                                                               "frame_start → wadr = 0"])
linea(d, can, f1, "can_v, can_p", "exitX=0.3;exitY=1;entryX=0.6;entryY=0;")
lcd_y_lectura(d, E, f1, "fb_rd_bit")
puertos(d, "canny1_completo")
d.guardar("pac_canny1_completo.drawio")

# ---------------------------------------------------------------- trans_completo
d, E = base("pac_trans_completo", "De los pines a las cajas: trans_completo, la cadena del Canny transitivo para silicio",
            "Cámara OV7670 → gris → Gaussiano → Sobel → doble umbral → cuadro de clases → motor a punto fijo → "
            "mapa de bordes → pantalla ILI9341. Sin computador de por medio.", "trans_completo", "trans_completo.v")
gc = caja(d, 920, 215, 250, 150, "grad_class_top   u_cg", ["Gaussiano 3×3 → Sobel 3×3", "→ doble umbral 110 / 70",
                                                            "→ clase de 2 bits", "cls_v, cls_p"], "#ffffff", "#c0392b")
linea(d, E["gray"], gc, "gray, gray_valid")
cf = fb(d, 1200, 215, 230, 150, "clsfb[0:4799]", ["60 × 80 × 2 bits", "escribe la cámara", "lee el motor (cls_rd)"])
linea(d, gc, cf, "cls_p")
pu = caja(d, 315, 500, 230, 150, "Puente FSM", ["E_RST → E_WLOAD", "→ E_LOAD → E_READ", "carga clsfb en el motor", "y vuelve a empezar"])
eng = caja(d, 570, 500, 235, 150, "trans_engine_top   ENG", ["hysteresis_frame_bram_sync", "barre el cuadro hasta que", "nada cambia (punto fijo)"],
           "#ffffff", "#c0392b")
linea(d, cf, pu, "cls_rd", "exitX=0.5;exitY=1;entryX=0.5;entryY=0;", pts=[(1315, 470), (430, 470)])
linea(d, pu, eng, "eng_class")
ef = fb(d, 830, 500, 240, 150, "edgefb[0:4799]   ·   60 × 80", ["1 bit por píxel", "escribe el motor (E_READ)", "lee la pantalla"])
linea(d, eng, ef, "eng_edge")
lcd_y_lectura(d, E, ef, "fb_rd_bit")
puertos(d, "trans_completo")
d.guardar("pac_trans_completo.drawio")
print("ok")
