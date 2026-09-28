# dio.py — mini-librería para escribir diagramas de draw.io desde Python (los de la §4.3.2).
from xml.sax.saxutils import quoteattr, escape

AZUL, ROJO, MORADO, GRIS = "#1f4e79", "#c0392b", "#6a4c93", "#555555"
MONO = "Courier New"


class Diagrama:
    def __init__(self, nombre, ancho, alto):
        self.nombre, self.ancho, self.alto = nombre, ancho, alto
        self.celdas, self.n = [], 1

    def _id(self):
        self.n += 1
        return f"c{self.n}"

    def v(self, txt, x, y, w, h, st):
        i = self._id()
        self.celdas.append(f'<mxCell id="{i}" value={quoteattr(txt)} style="{st}" vertex="1" parent="1">'
                           f'<mxGeometry x="{x}" y="{y}" width="{w}" height="{h}" as="geometry"/></mxCell>')
        return i

    def caja(self, txt, x, y, w, h, relleno="#ffffff", borde=AZUL, fs=13, extra=""):
        return self.v(txt, x, y, w, h, f"rounded=1;whiteSpace=wrap;html=1;fillColor={relleno};"
                      f"strokeColor={borde};strokeWidth=2;fontSize={fs};{extra}")

    def texto(self, txt, x, y, w, h, fs=13, extra=""):
        return self.v(txt, x, y, w, h, f"text;html=1;whiteSpace=wrap;fontSize={fs};{extra}")

    def pin(self, nombre, x, y, w=120, h=26, relleno=AZUL):
        return self.v(nombre, x, y, w, h, f"rounded=0;html=1;fillColor={relleno};strokeColor={relleno};"
                      f"fontColor=#ffffff;fontSize=12;fontStyle=1;fontFamily={MONO};")

    def codigo(self, fuente, x, y, w, h, fs=12, titulo=None):
        t = escape(fuente).replace(" ", "&nbsp;").replace("\n", "<br>")
        if titulo:
            t = f"<b>{escape(titulo)}</b><br>" + t
        return self.v(t, x, y, w, h, f"rounded=0;html=1;whiteSpace=nowrap;align=left;verticalAlign=top;"
                      f"spacingLeft=10;spacingTop=6;fontFamily={MONO};fontSize={fs};fillColor=#fbfbfb;"
                      f"strokeColor=#999999;")

    def flecha(self, a, b, lab="", extra="", pts=(), fs=11):
        i = self._id()
        P = "".join(f'<mxPoint x="{x}" y="{y}"/>' for x, y in pts)
        arr = f'<Array as="points">{P}</Array>' if pts else ""
        self.celdas.append(
            f'<mxCell id="{i}" value={quoteattr(lab)} style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;'
            f'endArrow=block;endFill=1;strokeWidth=1.8;fontSize={fs};fontFamily={MONO};'
            f'labelBackgroundColor=#ffffff;{extra}" edge="1" parent="1" source="{a}" target="{b}">'
            f'<mxGeometry relative="1" as="geometry">{arr}</mxGeometry></mxCell>')
        return i

    def guardar(self, ruta):
        xml = (f'<mxfile host="Claude"><diagram name="{self.nombre}" id="{self.nombre}">'
               f'<mxGraphModel dx="{self.ancho}" dy="{self.alto}" grid="0" gridSize="10" guides="1" page="1" '
               f'pageScale="1" pageWidth="{self.ancho}" pageHeight="{self.alto}" background="#ffffff" '
               f'math="0" shadow="0"><root><mxCell id="0"/><mxCell id="1" parent="0"/>'
               + "".join(self.celdas) + "</root></mxGraphModel></diagram></mxfile>")
        open(ruta, "w").write(xml)


def mono(s, fs=11):
    return f"<span style='font-family:{MONO};font-size:{fs}px'>{s}</span>"
