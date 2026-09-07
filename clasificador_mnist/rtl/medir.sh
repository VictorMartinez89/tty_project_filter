#!/usr/bin/env bash
# medir.sh — celdas del clasificador a distintos tamanos de imagen (yosys, celdas genericas).
#   El factor a sky130 es x1.383, calibrado en la Parte 167 contra una corrida real del shuttle.
for hw in "$@"; do
  H=${hw%x*}; W=${hw#*x}
  sed -E "s/parameter integer H = [0-9]+, parameter integer W = [0-9]+/parameter integer H = $H, parameter integer W = $W/" mnist_top.v > /tmp/mt.v
  yosys -p "read_verilog linebuf3x3.v mnist_feat.v mnist_clf.v /tmp/mt.v; synth -top mnist_top; stat" > /tmp/s_$hw.log 2>&1
  # el ULTIMO bloque de stat es el total del top; sumar todos los bloques cuenta doble
  gen=$(awk '/^ +[0-9]+ cells$/{c=$1} END{print c}' /tmp/s_$hw.log)
  ff=$(awk '/=== design hierarchy ===/{n++} n==2' /tmp/s_$hw.log | awk '/\$_S?DFF/{s+=$1} END{print s+0}')
  python3 -c "
g=$gen; f=$ff; fin=round(g*1.383)
print(f'{'$hw':>8}  genericas {g:>6}  FF {f:>5}  ->  sky130 ~{fin:>6}  |  6x2(12t) {fin/12:>6.0f}/tile   8x2(16t) {fin/16:>6.0f}/tile')"
done
