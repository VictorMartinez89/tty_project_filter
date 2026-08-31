# Clasificador de dígitos sobre el front-end de la tesis

El experimento de la **Parte 170** del cuaderno: ¿cuánto cuesta, en flip-flops, reconocer un dígito
usando **el mismo front-end que ya corre en silicio** (Gaussiano 3×3 → Sobel → `|Gx|+|Gy|` saturado a
8 bits → umbral → 8 orientaciones)?

Encima de esas orientaciones va un **histograma por zonas en pirámide espacial** (Lazebnik, Schmid y
Ponce, *Beyond Bags of Features*, CVPR 2006) y un **clasificador lineal** cuyos pesos se cuantizan a
1/2/4/8 bits — que es exactamente lo que costarían en flip-flops si se guardaran en el chip.

## Correrlo

```bash
bash bajar_mnist.sh          # MNIST -> mnist.npz  (~11 MB, no se versiona)
python3 piramide_mnist.py    # la tabla precision x bits x nivel de piramide
python3 fig_piramide.py      # la figura precision vs flip-flops
```

Necesita `numpy` y `scikit-learn`. Corre en el Mac en ~20 s.

## El resultado

**400 pesos a 4 bits = 1 600 flip-flops → 94.2 %** sobre MNIST test. El presupuesto real de un proyecto
de 8x2 tiles son ~2 200 flip-flops (medido, Parte 167): **cabe**. Y le gana a los 784 píxeles crudos con
clasificador lineal (91.9 %, 7 840 pesos) usando **19.6× menos pesos**.

Detalle de método: la cuantización elige la escala por mínimo error cuadrático, no por el peso máximo.
Con la escala del máximo, un solo peso grande manda al resto a cero y la fila de 2 bits sale *peor* que
la de 1 bit — un artefacto, no un resultado.
