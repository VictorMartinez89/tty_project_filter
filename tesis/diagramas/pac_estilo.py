# pac_estilo.py — el estilo común de los diagramas «De los pines a las cajas» (el de fig_pines_a_cajas).
from dio import Diagrama

GRIS_T, VERDE, VERDE_B = "#666666", "#dff0d8", "#4a8a3f"
AZ_F, AZ_B, NA_F, NA_B = "#eef4fb", "#4a7ebb", "#fdf3e8", "#c47f2a"
ROJO, AZUL_M = "#c0392b", "#2f4f8f"
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


def mem(d, x, y, w, h, tit, lineas):
    return caja(d, x, y, w, h, tit, lineas, "#fff3cd", "#b8860b")


def ext(d, x, y, w, h, tit, lineas):
    return caja(d, x, y, w, h, tit, lineas, VERDE, VERDE_B)


def linea(d, a, b, lab="", extra="", pts=()):
    return d.flecha(a, b, lab, extra="strokeColor=#444444;strokeWidth=1.8;fontFamily=Helvetica;fontSize=11;"
                    "endSize=8;" + extra, pts=pts, fs=11)


def titulo(d, t, sub):
    d.texto(f"<b>{t}</b><br><span style='font-size:13px;color:#666666'>{sub}</span>",
            40, 16, 1700, 56, fs=19, extra=F + "align=left;verticalAlign=top;")


def puertos(d, cab, lineas, y=760, w=1100):
    d.v(f"<b>{cab}</b><br>" + "<br>".join(lineas), 40, y, w, 110,
        f"rounded=1;arcSize=6;html=1;whiteSpace=wrap;align=left;verticalAlign=top;spacingLeft=14;spacingTop=8;"
        f"fontSize=11;fontColor=#555555;fillColor=#ffffff;strokeColor=#aaaaaa;{F}")
