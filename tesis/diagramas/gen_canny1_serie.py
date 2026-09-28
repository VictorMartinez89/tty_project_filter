# gen_canny1_serie.py — la serie de diagramas de la §4.3.2: de los puertos a las cajas de canny1_top.v y
# de linebuf3x3.v. El código de cada figura se lee de Verilog_Repo/canny1, así que no puede desviarse.
import os
from dio import Diagrama, mono, AZUL, ROJO, MORADO, GRIS

R = os.path.expanduser("~/Verilog_Repo/canny1/")
TOP = open(R + "canny1_top.v").read().split("\n")
LB = open(R + "linebuf3x3.v").read().split("\n")
def lineas(src, a, b):                       # líneas a..b, numeradas desde 1, como en el editor
    return "\n".join(src[a - 1:b])
LILA, ROSA = "#ece6f7", "#ffffff"
V = f"dashed=1;strokeColor={MORADO};fontColor={MORADO};"

# ---------------------------------------------------------------- 1 · canny1_top: entradas y salidas
d = Diagrama("canny1_top_puertos", 1560, 520)
d.texto("<b>canny1_top</b> · entradas y salidas", 20, 10, 1500, 36, fs=20, extra="align=center;")
d.codigo(lineas(TOP, 5, 14), 20, 70, 700, 215, titulo="canny1_top.v, líneas 5-14")
m = d.caja(mono("<b>canny1_top</b>", 16), 1040, 70, 300, 400, "#f7f7f7", GRIS,
           extra="verticalAlign=top;spacingTop=10;")
ent = [("clk", "1", "reloj"), ("reset", "1", "síncrono, activo alto"), ("in_valid", "1", "hay píxel"),
       ("in_pix[7:0]", "8", "el píxel, en gris"), ("thr_hi[7:0]", "8", "umbral alto: borde fuerte"),
       ("thr_lo[7:0]", "8", "umbral bajo: borde débil")]
for k, (n, bits, com) in enumerate(ent):
    y = 120 + k * 55
    p = d.pin(n, 820, y, 140)
    d.flecha(p, m, bits, extra=f"exitX=1;exitY=0.5;entryX=0;entryY={(y + 13 - 70) / 400:.4f};")
    d.texto(com, 1050, y, 160, 26, fs=11, extra="align=left;fontColor=#555555;")
sal = [("out_valid", "1", "hay salida"), ("out_pix[7:0]", "8", "FF borde · 00 plano")]
for k, (n, bits, com) in enumerate(sal):
    y = 230 + k * 70
    p = d.pin(n, 1420, y, 130)
    d.flecha(m, p, bits, extra=f"exitX=1;exitY={(y + 13 - 70) / 400:.4f};entryX=0;entryY=0.5;")
    d.texto(com, 1180, y, 150, 26, fs=11, extra="align=right;fontColor=#555555;")
d.texto("Seis entradas y dos salidas: el píxel entra de a uno con <span style='font-family:Courier New'>in_valid</span>, "
        "y sale de a uno con <span style='font-family:Courier New'>out_valid</span>, ocho ciclos después. "
        "Los dos umbrales son entradas: en la cadena los fija quien lo instancia.",
        20, 300, 700, 80, fs=13, extra="align=left;fontColor=#444444;")
d.guardar("canny1_1_puertos.drawio")

# ---------------------------------------------------------------- 2 · etapas 1 y 2
d = Diagrama("canny1_etapas12", 2150, 800)
d.texto("<b>canny1_top</b> · etapas 1 y 2: del píxel a la clase, con dos <span style='font-family:Courier New'>linebuf3x3</span>",
        20, 10, 1900, 36, fs=20, extra="align=center;")
pp = d.pin("in_pix[7:0]", 20, 175, 120); pv = d.pin("in_valid", 20, 125, 120)
W, H, Y, X0, G = 140, 110, 140, 180, 58
spec = [("<b>linebuf3x3 LBG</b><br>" + mono("W=60 · DW=8"), LILA, MORADO),
        ("<b>gsum[11:0]</b><br>" + mono("1 2 1<br>2 4 2<br>1 2 1"), ROSA, ROJO),
        ("<b>gout[7:0]</b><br>" + mono("gsum[11:4]") + "<br>÷16", ROSA, ROJO),
        ("<b>linebuf3x3 LBS</b><br>" + mono("W=60 · DW=8"), LILA, MORADO),
        ("<b>gxp gxn<br>gyp gyn</b><br>" + mono("[10:0]") + "<br>sumas 1-2-1", ROSA, ROJO),
        ("<b>agx agy</b><br>" + mono("[10:0]") + "<br>|resta| sin signo", ROSA, ROJO),
        ("<b>mag12</b><br>" + mono("agx+agy") + "<br>" + mono("[11:0]"), ROSA, ROJO),
        ("<b>mag[7:0]</b><br>satura<br>a 255", ROSA, ROJO),
        ("<b>cls_in[1:0]</b><br>2 fuerte<br>1 débil · 0 nada", ROSA, ROJO)]
B = []
for k, (t, f, s) in enumerate(spec):
    B.append(d.caja(t, X0 + k * (W + G), Y, W, H, f, s, fs=12))
d.flecha(pp, B[0], "", extra="exitX=1;exitY=0.5;entryX=0;entryY=0.75;")
d.flecha(pv, B[0], "", extra="exitX=1;exitY=0.5;entryX=0;entryY=0.2;")
labs = ["gw00…gw22", "", "gout", "sw00…sw22", "", "", "", ""]
for k in range(8):
    d.flecha(B[k], B[k + 1], labs[k], fs=10)
xc = X0 + 8 * (W + G)
th = d.pin("thr_hi[7:0]", xc - 70, 285, 130); tl = d.pin("thr_lo[7:0]", xc + 70, 285, 130)
d.flecha(th, B[8], "", extra="exitX=0.5;exitY=0;entryX=0.3;entryY=1;")
d.flecha(tl, B[8], "", extra="exitX=0.5;exitY=0;entryX=0.7;entryY=1;")
out = d.pin("cls_in → LBC", xc + W + 40, Y + 42, 140, relleno="#888888")
d.flecha(B[8], out, "")
xs = lambda k: X0 + k * (W + G) + W / 2
d.flecha(B[0], B[3], "vg", extra=V + "exitX=0.5;exitY=0;entryX=0.5;entryY=0;", pts=[(xs(0), 95), (xs(3), 95)])
vsp = d.pin("vs → LBC", xc + W + 40, 70, 140, relleno=MORADO)
d.flecha(B[3], vsp, "vs", extra=V + "exitX=0.5;exitY=0;entryX=0;entryY=0.5;", pts=[(xs(3), 83)])
d.texto("<b>Etapa 1</b> · gaussiano", X0, 262, 3 * (W + G) - G, 22, fs=13, extra=f"align=center;fontColor={ROJO};")
d.texto("<b>Etapa 2</b> · Sobel y doble umbral", X0 + 3 * (W + G), 262, 4 * (W + G), 22, fs=13,
        extra=f"align=center;fontColor={ROJO};")
d.codigo(lineas(TOP, 15, 39), 20, 340, 2080, 420, fs=13, titulo="canny1_top.v, líneas 15-39")
d.guardar("canny1_2_etapas12.drawio")

# ---------------------------------------------------------------- 3 · etapa 3
d = Diagrama("canny1_etapa3", 1500, 860)
d.texto("<b>canny1_top</b> · etapa 3: la ventana de clases y la histéresis de un salto", 20, 10, 1460, 36, fs=20,
        extra="align=center;")
pc = d.pin("cls_in[1:0]", 20, 205, 120); pvs = d.pin("vs", 20, 150, 120, relleno=MORADO)
lbc = d.caja("<b>linebuf3x3 LBC</b><br>" + mono("W=60 · DW=2") + "<br>dos bits por píxel", 190, 150, 170, 110,
             LILA, MORADO)
d.flecha(pc, lbc, "", extra="exitX=1;exitY=0.5;entryX=0;entryY=0.75;")
d.flecha(pvs, lbc, "", extra=V + "exitX=1;exitY=0.5;entryX=0;entryY=0.2;")
grid = d.v("", 410, 90, 300, 190, "rounded=1;html=1;fillColor=#f5f0fb;strokeColor=#6a4c93;dashed=1;")
d.texto("la ventana de clases", 410, 62, 300, 24, fs=12, extra=f"align=center;fontColor={MORADO};")
cel = {}
for r in range(3):
    for c in range(3):
        n = f"cw{r}{c}"
        centro = (r, c) == (1, 1)
        cel[n] = d.v(n, 425 + c * 95, 105 + r * 57, 80, 44,
                     f"rounded=0;html=1;fontFamily=Courier New;fontSize=13;fontStyle=1;"
                     f"fillColor={'#f6d5d1' if centro else '#ffffff'};strokeColor={ROJO if centro else MORADO};"
                     f"strokeWidth={2 if centro else 1};")
d.flecha(lbc, grid, "cw00…cw22", fs=10)
anys = d.caja("<b>any_strong</b><br>algún vecino<br>" + mono("== 2") + " (fuerte)", 780, 90, 200, 90, ROSA, ROJO)
mux = d.caja("<b>edge_1hop</b><br>" + mono("cw11==2 → 1") + "<br>" + mono("cw11==1 → any_strong") + "<br>"
             + mono("si no → 0"), 780, 210, 200, 110, ROSA, ROJO)
d.flecha(grid, anys, "8 vecinos", extra="exitX=1;exitY=0.25;entryX=0;entryY=0.5;", fs=10)
d.flecha(grid, mux, "cw11", extra="exitX=0.5;exitY=1;entryX=0;entryY=0.75;", pts=[(560, 302)], fs=10)
d.flecha(anys, mux, "", extra="exitX=0.5;exitY=1;entryX=0.5;entryY=0;")
reg = d.caja("<b>registro de salida</b><br>" + mono("always @(posedge clk)") + "<br>" + mono("out_valid &lt;= vc") +
             "<br>" + mono("out_pix &lt;= edge_1hop ? FF : 00"), 1040, 180, 260, 120, "#eeeeee", GRIS)
d.flecha(mux, reg, "edge_1hop", fs=10)
d.flecha(lbc, reg, "vc", extra=V + "exitX=0.5;exitY=1;entryX=0.5;entryY=1;", pts=[(275, 350), (1170, 350)])
rs = d.pin("reset", 1250, 360, 100)
d.flecha(rs, reg, "", extra="exitX=0.5;exitY=0;entryX=0.8;entryY=1;strokeColor=#888888;")
ov = d.pin("out_valid", 1360, 200, 125); op = d.pin("out_pix[7:0]", 1360, 260, 125)
d.flecha(reg, ov, "", extra="exitX=1;exitY=0.25;entryX=0;entryY=0.5;")
d.flecha(reg, op, "", extra="exitX=1;exitY=0.75;entryX=0;entryY=0.5;")
d.codigo(lineas(TOP, 40, 57), 20, 420, 1460, 330, fs=13, titulo="canny1_top.v, líneas 40-57")
d.guardar("canny1_3_etapa3.drawio")

# ---------------------------------------------------------------- 4 · linebuf3x3: entradas y salidas
d = Diagrama("linebuf_puertos", 1560, 520)
d.texto("<b>linebuf3x3</b> · entradas y salidas", 20, 10, 1500, 36, fs=20, extra="align=center;")
d.codigo(lineas(LB, 8, 14), 20, 70, 720, 150, titulo="linebuf3x3.v, líneas 8-14")
m = d.caja(mono("<b>linebuf3x3</b>", 16) + "<br>" + mono("#(W, DW)", 13), 1000, 70, 220, 380, "#f7f7f7", MORADO,
           extra="verticalAlign=top;spacingTop=10;")
for k, (n, bits) in enumerate([("clk", "1"), ("in_valid", "1"), ("in_pix[DW-1:0]", "DW")]):
    y = 170 + k * 70
    p = d.pin(n, 790, y, 150)
    d.flecha(p, m, bits, extra=f"exitX=1;exitY=0.5;entryX=0;entryY={(y + 13 - 70) / 380:.4f};")
pv = d.pin("valid_o", 1290, 100, 100)
d.flecha(m, pv, "1", extra=f"exitX=1;exitY={(113 - 70) / 380:.4f};entryX=0;entryY=0.5;")
g = d.v("", 1280, 170, 260, 200, "rounded=1;html=1;fillColor=#f5f0fb;strokeColor=#6a4c93;dashed=1;")
filas = ["fila n−2", "fila n−1", "fila n"]
for r in range(3):
    for c in range(3):
        d.v(f"w{r}{c}", 1292 + c * 60, 190 + r * 58, 52, 34,
            f"rounded=0;html=1;fontFamily=Courier New;fontSize=12;fontStyle=1;fillColor=#ffffff;"
            f"strokeColor={ROJO if (r, c) == (1, 1) else MORADO};")
    d.texto(filas[r], 1470, 196 + r * 58, 80, 24, fs=11, extra="align=left;fontColor=#555555;")
d.flecha(m, g, "9 × DW", extra="exitX=1;exitY=0.62;entryX=0;entryY=0.5;")
d.texto("columnas: x−2 · x−1 · x", 1285, 375, 250, 22, fs=11, extra="align=center;fontColor=#555555;")
d.texto("Dos parámetros: <b>W</b>, los píxeles por fila (60 en <span style='font-family:Courier New'>canny1_top</span>), "
        "y <b>DW</b>, los bits de cada píxel (8 para gris, 2 para clases). Sale la ventana de 3×3 completa, "
        "con el centro en <span style='font-family:Courier New'>w11</span>.", 20, 260, 720, 80, fs=13,
        extra="align=left;fontColor=#444444;")
d.guardar("canny1_4_linebuf_puertos.drawio")

# ---------------------------------------------------------------- 5 · linebuf3x3 por dentro
d = Diagrama("linebuf_dentro", 1500, 1000)
d.texto("<b>linebuf3x3</b> por dentro: dos filas en memoria y nueve registros de ventana", 20, 10, 1460, 36,
        fs=20, extra="align=center;")
d.v("", 150, 60, 560, 440, "rounded=1;html=1;fillColor=#eef4fb;strokeColor=#1f4e79;dashed=1;arcSize=3;")
d.texto("<b>etapa 1</b> · lectura síncrona y columna", 160, 470, 400, 24, fs=12, extra=f"align=left;fontColor={AZUL};")
d.v("", 730, 60, 520, 440, "rounded=1;html=1;fillColor=#fbf2ec;strokeColor=#c0392b;dashed=1;arcSize=3;")
d.texto("<b>etapa 2</b> · escritura de retorno y ventana", 740, 470, 400, 24, fs=12,
        extra=f"align=left;fontColor={ROJO};")
pin_ = d.pin("in_pix", 20, 332, 110); piv = d.pin("in_valid", 20, 432, 110)
lba = d.caja("<b>lb_a[0:W−1]</b><br>fila n−2", 180, 90, 170, 70, LILA, MORADO)
lbb = d.caja("<b>lb_b[0:W−1]</b><br>fila n−1", 180, 210, 170, 70, LILA, MORADO)
cx = d.caja("<b>x</b> · columna<br>" + mono("0 … W−1") + "<br>" + mono("xd &lt;= x"), 180, 360, 170, 60)
qa = d.caja(mono("<b>q_a</b>", 13), 470, 100, 110, 50); qb = d.caja(mono("<b>q_b</b>", 13), 470, 220, 110, 50)
cu = d.caja(mono("<b>cur</b>", 13), 470, 320, 110, 50); v1 = d.caja(mono("<b>v1</b>", 13), 470, 425, 110, 40)
d.flecha(lba, qa, "lb_a[x]", fs=10); d.flecha(lbb, qb, "lb_b[x]", fs=10)
d.flecha(pin_, cu, "", extra="exitX=1;exitY=0.5;entryX=0;entryY=0.5;")
d.flecha(piv, v1, "", extra="exitX=1;exitY=0.5;entryX=0;entryY=0.5;")
d.flecha(cx, lba, "x", extra="exitX=0;exitY=0.3;entryX=0;entryY=0.5;dashed=1;", pts=[(165, 378), (165, 125)], fs=10)
W_ = {}
for r in range(3):
    for c in range(3):
        n = f"w{r}{c}"
        W_[n] = d.v(n, 790 + (2 - c) * 120, 100 + r * 120, 80, 50,
                    f"rounded=0;html=1;fontFamily=Courier New;fontSize=13;fontStyle=1;fillColor=#ffffff;"
                    f"strokeColor={ROJO if (r, c) == (1, 1) else MORADO};strokeWidth=2;")
for r, src in enumerate([qa, qb, cu]):
    d.flecha(src, W_[f"w{r}2"], "", extra="exitX=1;exitY=0.5;entryX=0;entryY=0.5;")
    d.flecha(W_[f"w{r}2"], W_[f"w{r}1"], ""); d.flecha(W_[f"w{r}1"], W_[f"w{r}0"], "")
WB = "dashed=1;strokeColor=#e67e22;fontColor=#e67e22;"
d.flecha(qb, lba, "lb_a[xd] &lt;= q_b", extra=WB + "exitX=0.5;exitY=0;entryX=1;entryY=0.75;", pts=[(525, 190), (380, 190), (380, 142)], fs=10)
d.flecha(cu, lbb, "lb_b[xd] &lt;= cur", extra=WB + "exitX=0.5;exitY=1;entryX=1;entryY=0.75;", pts=[(525, 385), (400, 385), (400, 262)], fs=10)
vo = d.pin("valid_o", 1330, 432, 110)
d.flecha(v1, vo, "", extra="exitX=1;exitY=0.5;entryX=0;entryY=0.5;")
for r, t in enumerate(["fila n−2", "fila n−1", "fila n"]):
    d.texto(t, 1265, 112 + r * 120, 90, 24, fs=12, extra="align=left;fontColor=#555555;")
d.texto("En naranja, lo que se escribe de vuelta: la fila n−1 pasa a ser la n−2 y el píxel nuevo entra en la n−1. "
        "Dos memorias de W posiciones bastan para tener siempre las tres filas de la ventana.",
        150, 510, 1100, 44, fs=13, extra="align=left;fontColor=#444444;")
d.codigo(lineas(LB, 15, 39), 20, 565, 1460, 440, fs=13, titulo="linebuf3x3.v, líneas 15-39")
d.guardar("canny1_5_linebuf_dentro.drawio")
print("ok")
