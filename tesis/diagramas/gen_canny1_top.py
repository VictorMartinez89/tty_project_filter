# gen_canny1_top.py — genera canny1_top.drawio: «de los pines a las cajas» del modulo canny1_top.v
from xml.sax.saxutils import quoteattr
cells=[]; n=[1]
def nid(): n[0]+=1; return f"c{n[0]}"
def v(txt,x,y,w,h,st):
    i=nid(); cells.append(f'<mxCell id="{i}" value={quoteattr(txt)} style="{st}" vertex="1" parent="1"><mxGeometry x="{x}" y="{y}" width="{w}" height="{h}" as="geometry"/></mxCell>'); return i
def box(txt,x,y,w,h,fill,stroke,fs=13,extra=""):
    return v(txt,x,y,w,h,f"rounded=1;whiteSpace=wrap;html=1;fillColor={fill};strokeColor={stroke};strokeWidth=2;fontSize={fs};{extra}")
def text(txt,x,y,w,h,fs=13,extra=""):
    return v(txt,x,y,w,h,f"text;html=1;whiteSpace=wrap;fontSize={fs};{extra}")
def pin(name,x,y,w=120):
    return v(name,x,y,w,26,"rounded=0;html=1;fillColor=#1f4e79;strokeColor=#1f4e79;fontColor=#ffffff;fontSize=12;fontStyle=1;fontFamily=Courier New;")
def edge(a,b,lab="",extra="",pts=(),fs=11):
    i=nid(); P="".join(f'<mxPoint x="{x}" y="{y}"/>' for x,y in pts)
    cells.append(f'<mxCell id="{i}" value={quoteattr(lab)} style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;endArrow=block;endFill=1;strokeWidth=1.8;fontSize={fs};fontFamily=Courier New;labelBackgroundColor=#ffffff;{extra}" edge="1" parent="1" source="{a}" target="{b}"><mxGeometry relative="1" as="geometry">'+(f'<Array as="points">{P}</Array>' if pts else '')+'</mxGeometry></mxCell>'); return i
M=lambda s:f"<span style='font-family:Courier New;font-size:11px'>{s}</span>"
text("<b>De los pines a las cajas</b> · <span style='font-family:Courier New'>canny1_top.v</span> por dentro: tres <span style='font-family:Courier New'>linebuf3x3</span> y la lógica entre ellas",40,20,1800,40,fs=21,extra="align=center;")
MX,MY,MW,MH=380,110,1210,660
box("module canny1_top",MX,MY,MW,MH,"#f7f7f7","#555555",16,"verticalAlign=bottom;align=right;spacingRight=14;spacingBottom=8;fontStyle=1;fontFamily=Courier New;dashed=1;arcSize=2;")
pclk=pin("clk",320,150); prst=pin("reset",320,200); pv=pin("in_valid",320,262); pp=pin("in_pix[7:0]",320,312)
phi=pin("thr_hi[7:0]",320,560); plo=pin("thr_lo[7:0]",320,610)
pov=pin("out_valid",1530,560); pop=pin("out_pix[7:0]",1530,610)
LB="#ece6f7"; LBs="#6a4c93"; C="#ffffff"; Cs="#c0392b"
W,H=200,120
lbg=box("<b>linebuf3x3 LBG</b><br>"+M("W=60 · DW=8")+"<br>ventana de 3×3 de in_pix",500,240,W,H,LB,LBs)
gau=box("<b>Gaussiano</b><br>"+M("gsum = gw00+(gw01&lt;&lt;1)+gw02<br>+(gw10&lt;&lt;1)+(gw11&lt;&lt;2)+…")+"<br>"+M("gout = gsum[11:4]")+" (÷16)",770,240,W+20,H,C,Cs)
lbs=box("<b>linebuf3x3 LBS</b><br>"+M("W=60 · DW=8")+"<br>ventana de 3×3 de gout",1050,240,W,H,LB,LBs)
sob=box("<b>Sobel</b><br>"+M("agx=|gxp−gxn|  agy=|gyp−gyn|")+"<br>"+M("mag = sat255(agx+agy)"),1290,240,W+60,H,C,Cs)
umb=box("<b>Doble umbral</b><br>"+M("cls_in = mag&gt;thr_hi ? 2<br>: mag&gt;thr_lo ? 1 : 0"),500,520,W+10,H,C,Cs)
lbc=box("<b>linebuf3x3 LBC</b><br>"+M("W=60 · DW=2")+"<br>ventana de 3×3 de clases",780,520,W,H,LB,LBs)
his=box("<b>Histéresis de un salto</b><br>"+M("any_strong = algún vecino == 2")+"<br>"+M("edge_1hop = cw11==2 ? 1<br>: cw11==1 ? any_strong : 0"),1010,520,W+60,H,C,Cs)
reg=box("<b>Registro de salida</b><br>"+M("always @(posedge clk)")+"<br>"+M("out_pix &lt;= edge_1hop ? FF : 00"),1295,520,W+10,H,"#eeeeee","#555555")
edge(pp,lbg,"",extra="exitX=1;exitY=0.5;entryX=0;entryY=0.6;")
edge(pv,lbg,"",extra="exitX=1;exitY=0.5;entryX=0;entryY=0.3;")
edge(lbg,gau,"gw00…gw22")
edge(gau,lbs,"gout[7:0]")
edge(lbs,sob,"sw00…sw22")
edge(sob,umb,"mag[7:0]",extra="exitX=0.5;exitY=1;entryX=0.5;entryY=0;",pts=[(1420,440),(605,440)])
edge(phi,umb,"",extra="exitX=1;exitY=0.5;entryX=0;entryY=0.45;")
edge(plo,umb,"",extra="exitX=1;exitY=0.5;entryX=0;entryY=0.75;")
edge(umb,lbc,"cls_in[1:0]")
edge(lbc,his,"cw00…cw22")
edge(his,reg,"edge_1hop")
edge(reg,pop,"",extra="exitX=1;exitY=0.75;entryX=0;entryY=0.5;")
edge(reg,pov,"",extra="exitX=1;exitY=0.35;entryX=0;entryY=0.5;")
V="dashed=1;strokeColor=#6a4c93;fontColor=#6a4c93;"
edge(lbg,lbs,"vg",extra=V+"exitX=0.5;exitY=0;entryX=0.5;entryY=0;",pts=[(600,200),(1150,200)])
edge(lbs,lbc,"vs",extra=V+"exitX=0.25;exitY=1;entryX=0.5;entryY=0;",pts=[(1100,470),(880,470)])
edge(lbc,reg,"vc",extra=V+"exitX=0.5;exitY=1;entryX=0.5;entryY=1;",pts=[(880,690),(1430,690)])
edge(prst,reg,"",extra="exitX=1;exitY=0.5;entryX=0.95;entryY=1;strokeColor=#888888;",pts=[(460,213),(460,740),(1505,740),(1505,650)])
text("clk llega a las tres <span style='font-family:Courier New'>linebuf3x3</span> y al registro de salida",520,150,420,24,fs=12,extra="align=left;fontColor=#555555;")
text("<b>Sin multiplicadores:</b> sólo <span style='font-family:Courier New'>+</span>, <span style='font-family:Courier New'>−</span>, <span style='font-family:Courier New'>&lt;&lt;</span> y comparaciones. Las cajas moradas son las <b>tres instancias del mismo</b> <span style='font-family:Courier New'>linebuf3x3</span> —dos filas guardadas cada una—; la de clases guarda <b>2 bits</b> por píxel. Las líneas moradas discontinuas son la cadena de validez: <span style='font-family:Courier New'>in_valid → vg → vs → vc → out_valid</span>.",40,790,1800,50,fs=13,extra="align=center;fontColor=#444444;")
xml=('<mxfile host="Claude"><diagram name="canny1_top" id="d2"><mxGraphModel dx="1900" dy="860" grid="0" gridSize="10" guides="1" page="1" pageScale="1" pageWidth="1900" pageHeight="860" background="#ffffff" math="0" shadow="0"><root><mxCell id="0"/><mxCell id="1" parent="0"/>'+"".join(cells)+'</root></mxGraphModel></diagram></mxfile>')
open('canny1_top.drawio','w').write(xml)
