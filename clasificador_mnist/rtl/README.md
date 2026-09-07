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

## ⚠️ Estado de la verificación: NO pasa todavía

El diseño **elabora, sintetiza sin latches y simula** —entra una imagen, sale un dígito— pero el
histograma que produce el RTL **todavía no coincide** con el golden de Python. Al alinear por el
mejor desplazamiento, la magnitud coincide en ~420 de 576 píxeles.

Lo que ya se descartó, y lo que falta:
- ✅ **El mapeo de orientaciones es correcto** — los bins vacíos y el bin 5 coinciden exactamente.
- ✅ **Bug encontrado y corregido:** `LBS` estaba instanciado con `.W(W-2)`. El `linebuf3x3` emite
  una salida por cada entrada (no descarta el borde), así que la segunda etapa sigue viendo filas
  de `W`. Corregido a `.W(W)`.
- ✅ **`clr` separado de `reset`**, para poder limpiar el histograma entre pasadas conservando los
  line-buffers cargados (la imagen se manda dos veces, como en las Partes 29-35).
- ❌ **Falta:** la alineación exacta entre el raster del RTL y el área `valid` de 24×24 del golden.
  Barriendo `LAT` no aparece un desplazamiento que dé coincidencia exacta, así que queda al menos
  una diferencia más, probablemente en el borde del raster o en el truncamiento del Gaussiano.

**Hasta que esto cierre, los números de área son válidos pero la precisión del RTL no está
verificada.** La cifra de 91.0 % es del modelo de Python, no del hardware.

## Correcciones que este trabajo trae a la Parte 170

1. **La orientación por `atan2` no es implementable barata.** El RTL usa el **octante**
   —`{sgn(Gy), sgn(Gx), |Gy|>|Gx|}`, tres comparaciones y cero multiplicaciones—. Con esa
   cuantización, re-entrenado: **94.6 % float y 91.0 % a 4 bits**, no el 94.2 % reportado.
2. **Los pesos no cuestan flip-flops** si van en ROM. La fórmula `10·D·β` de la Parte 170 sobreestima.
