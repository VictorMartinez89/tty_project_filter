# RTL del clasificador de dígitos — `pixel → bordes → formas → dígito`

El clasificador de la Parte 170, escrito en Verilog y **medido con yosys**. Reusa el front-end de
la tesis (`linebuf3x3` → Gaussiano → Sobel → magnitud saturada → umbral) y le agrega dos piezas
nuevas: el histograma de orientaciones por zonas y el clasificador lineal.

| archivo | qué es |
|---|---|
| `mnist_feat.v` | front-end + 32 contadores (4 cuadrantes × 8 orientaciones) |
| `mnist_clf.v` | ROM de pesos + MAC serie (400 ciclos) + argmax |
| `mnist_top.v` | los dos juntos: entra el stream, sale el dígito |
| `mnist_weights.vh` | **generado** por `../entrenar_hw.py` — 400 pesos de 4 bits |
| `tb_mnist.v`, `verificar.py` | banco y comparación contra el golden — **ver estado abajo** |
| `medir.sh` | barrido de tamaño con yosys |

## Lo medido (yosys, celdas genéricas · factor a sky130 ×1.383)

| imagen | genéricas | flip-flops | sky130 est. | /tile en 8x2 |
|---|---:|---:|---:|---:|
| 28×28 | 7 237 | 1 515 | ~10 009 | **626** |
| 20×20 | 6 385 | 1 259 | ~8 830 | 552 |
| 16×16 | 5 850 | 1 117 | ~8 091 | 506 |

Reparto a 28×28: `mnist_feat` 2 025 · `linebuf3x3` ×2 3 126 · `mnist_clf` 2 086.

**Los pesos NO cuestan flip-flops.** Van en una ROM sintetizada (lógica combinacional), no en
registros. De los 1 515 flip-flops, ~896 son los dos line-buffers y 288 los contadores.

## ✅ Verificación: **200 de 200, bit a bit**

```
histograma identico: 200/200   ·   digito identico: 200/200
```

Los 32 contadores que produce el Verilog son **exactamente** los del golden de Python, imagen por
imagen, y el dígito también. Es la verificación de las Partes 29-35 aplicada al clasificador.

Y la precisión medida **sobre el RTL**, corriendo iverilog imagen por imagen:

| | 500 imágenes de test |
|---|---:|
| **RTL (iverilog)** | **89.6 %** |
| golden de Python, mismas 500 | 89.6 % |
| golden de Python, las 10 000 | 91.0 % |

**El hardware y el modelo dan lo mismo.** El 89.6 % contra 91.0 % es solo el submuestreo de 500
frente a 10 000, no una diferencia entre software y silicio.

### Los cuatro bugs que costó, y qué enseña cada uno

1. **`LBS` instanciado con `.W(W-2)`.** El `linebuf3x3` emite una salida por cada entrada —no
   descarta el borde—, así que la segunda etapa sigue viendo filas de `W`. → `.W(W)`.
2. **Faltaba un `clr` separado del `reset`.** La imagen se manda dos veces (los line-buffers
   arrancan vacíos); al empezar la segunda hay que poner el histograma en cero **conservando** las
   filas ya cargadas. Un `reset` a secas borraba las dos cosas.
3. **Faltaba una tercera pasada para DRENAR.** Como el linebuf emite una salida por entrada, las
   últimas muestras de un cuadro solo salen cuando entran los primeros píxeles del siguiente. Sin
   esa tercera pasada faltaban 2 muestras de 784 y `ult_pix` nunca disparaba.
4. **La latencia no es `2(W+1)` sino `2(W+2)`.** La Parte 168 midió `W+1` por etapa 3×3 —el
   desplazamiento de la *ventana*—, pero el `linebuf3x3` agrega además su propio pipeline interno.
   Calibrado contra el golden: **LAT = 60 para W=28**.
   > ⚠️ **Y esta es la trampa que casi se cuela:** con `LAT=58` el **total** de bordes era
   > **correcto** (229 = 229) y solo estaba mal la *distribución* por zonas. Un corrimiento no
   > cambia la suma. Verificar por totales habría dado "OK" con el diseño mal alineado.

## Correcciones que este trabajo trae a la Parte 170

1. **La orientación por `atan2` no es implementable barata.** El RTL usa el **octante**
   —`{sgn(Gy), sgn(Gx), |Gy|>|Gx|}`, tres comparaciones y cero multiplicaciones—. Con esa
   cuantización, re-entrenado: **94.6 % float y 91.0 % a 4 bits**, no el 94.2 % reportado.
2. **Los pesos no cuestan flip-flops** si van en ROM. La fórmula `10·D·β` de la Parte 170 sobreestima.
