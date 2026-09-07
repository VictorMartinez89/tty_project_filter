#!/usr/bin/env bash
# correr_todo.sh — todo el experimento del clasificador, de cero, en orden.
#
#   OJO CON EL PYTHON: hace falta el de conda (/opt/anaconda3), que es el que tiene
#   scikit-learn. El de Homebrew NO lo trae y los scripts fallan con ModuleNotFoundError.
#   Por eso aca se fija el PATH en vez de confiar en el que este activo.
set -e
export PATH=/opt/anaconda3/bin:/opt/homebrew/bin:$PATH
AQUI="$(cd "$(dirname "$0")" && pwd)"; cd "$AQUI"

python3 -c "import sklearn, numpy, matplotlib" 2>/dev/null || {
    echo "!! falta scikit-learn / numpy / matplotlib en este python ($(which python3))"
    echo "   usar el de conda:  export PATH=/opt/anaconda3/bin:\$PATH"; exit 1; }

echo "== 1/5  MNIST"
[ -f mnist.npz ] || bash bajar_mnist.sh

echo "== 2/5  el experimento original (atan2, los numeros de la Parte 170)"
python3 piramide_mnist.py

echo "== 3/5  entrenar con la aritmetica del hardware (octante) y exportar los pesos"
python3 entrenar_hw.py

echo "== 4/5  compilar el RTL y verificarlo contra el golden"
cd rtl && mkdir -p tmp
iverilog -g2012 -o tmp/sim.vvp -s tb_mnist tb_mnist.v mnist_feat.v mnist_clf.v linebuf3x3.v
python3 verificar.py 50
bash medir.sh 28x28 20x20 16x16
cd ..

echo "== 5/5  las figuras"
python3 fig_piramide.py
python3 figura_jerarquia.py
echo
echo "listo."
