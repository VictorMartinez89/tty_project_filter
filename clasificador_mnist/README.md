# Clasificador de dígitos sobre el front-end de la tesis

El experimento de las **Partes 170-173** del cuaderno: ¿cuánto cuesta, en silicio, reconocer un
dígito usando **el mismo front-end que ya corre en los diez chips** (Gaussiano 3×3 → Sobel →
`|Gx|+|Gy|` saturado a 8 bits → umbral → orientación)?

Encima de esas orientaciones va un **histograma por zonas en pirámide espacial** (Lazebnik, Schmid
y Ponce, *Beyond Bags of Features*, CVPR 2006) y un **clasificador lineal** con los pesos
cuantizados. Todo está implementado **dos veces**: en Python como golden, y en Verilog — y se
verifica que dan **exactamente** lo mismo.

## Cómo correrlo

```bash
bash correr_todo.sh          # de cero: MNIST, entrenamiento, RTL, verificación y figuras
```

> ⚠️ **Necesita el Python de conda** (`/opt/anaconda3`), que es el que trae `scikit-learn`. El de
> Homebrew no lo tiene y los scripts fallan con `ModuleNotFoundError`. `correr_todo.sh` fija el
> `PATH` por eso.

## Los archivos

| archivo | qué es |
|---|---|
| **`frente_golden.py`** | **el modelo golden del front-end, en un solo lugar** — todos lo importan |
| `entrenar_hw.py` | entrena con la aritmética del hardware y genera `rtl/mnist_weights.vh` |
| `piramide_mnist.py` | el barrido original pirámide × bits (los números de la Parte 170) |
| `figura_jerarquia.py` | la figura de las 4 capas × 10 dígitos, con el veredicto del RTL |
| `fig_piramide.py` | precisión vs flip-flops |
| `bajar_mnist.sh` | MNIST → `mnist.npz` (~11 MB, no se versiona) |
| `rtl/` | **el Verilog** — ver `rtl/README.md` |

`frente_golden.py` existe porque el front-end estaba **duplicado en cuatro scripts**, y dos de
ellos lo importaban con un `exec(open(...).read().split(...))`. Un cambio tenía que replicarse a
mano en todos: la receta perfecta para que el golden y el RTL se separen sin que nadie lo note.

## Los resultados

| | precisión sobre MNIST test |
|---|---:|
| **RTL en iverilog** (500 imágenes) | **89.6 %** |
| golden de Python, mismas 500 | 89.6 % |
| golden de Python, las 10 000 | 91.0 % |
| *(variante con `atan2`, no implementable barata)* | *94.2 %* |
| línea de base: 784 píxeles crudos + lineal | 91.9 %, con 7 840 pesos |

**Y el RTL da el mismo histograma que el golden, contador por contador, en 200 de 200 imágenes.**

Tamaño medido con yosys: **7 240 celdas genéricas → ~10 013 en sky130 → 626 celdas/tile** en un
proyecto de 8×2 tiles, contra las 1 023-1 183 que sí cerraron en el shuttle. **Cabe con holgura, a
28×28 completo.**
