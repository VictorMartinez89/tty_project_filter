#!/usr/bin/env python3
"""prueba_camara_33.py — resultado de la prueba de 11 escenas x 3 intentos, con su intervalo de Wilson al 95 %.
Uso: python3 prueba_camara_33.py "1:1,1,7" "2:2,2,2" ... "nada:nada,nada,3"   (escena:resp1,resp2,resp3)"""
import sys, math
filas=[a.split(":") for a in sys.argv[1:]]
n=ok=abst=0
for esc,rs in filas:
    r=[x.strip().lower() for x in rs.split(",")]
    for x in r:
        n+=1; ok+= x==esc.strip().lower(); abst+= (x=="nada" and esc.strip().lower()!="nada")
    print(f"  {esc:>5}: {r}  -> {sum(x==esc.strip().lower() for x in r)}/3")
p=ok/n if n else 0; z=1.96
c=(p+z*z/(2*n))/(1+z*z/n); h=z*math.sqrt(p*(1-p)/n+z*z/(4*n*n))/(1+z*z/n)
print(f"\n  aciertos {ok}/{n} = {p:.1%}   IC95 % [{c-h:.1%}, {c+h:.1%}]   azar = 9,1 %   abstenciones ante un dígito: {abst}")
