#!/bin/sh
# placa_vm.sh — el top78 (97,22 %) para la iCESugar, alimentado por el puerto serie.
#   MARCA_PLACA78_23SEP_v2_POSTSYN
#
#   sh /mnt/share/utm-share/mnist78_placa/placa_vm.sh          # simula, sintetiza y empaqueta
#   sh /mnt/share/utm-share/mnist78_placa/placa_vm.sh ver      # ademas abre gtkwave
#
# Seis pasos, y cada uno PARA si el anterior no paso:
#   1. iverilog + vvp : el RTL con la UART de verdad, bit a bit, 2 lotes de 4 imagenes, contra
#                       el golden. Tiene que decir ALL TESTS PASSED. Deja out/stream78.vcd.
#   2. yosys          : tienen que salir 9 SB_RAM40_4K (si salen 7, la BRAM no se infirio).
#   3. nextpnr        : LC, frecuencia, y PASS a 12 MHz.
#   4. icepack        : out/mnist78_placa.bin
#   5. iverilog + vvp OTRA VEZ, pero sobre el NETLIST QUE SALIO DE YOSYS (celdas SB_* de la
#      iCE40), con 8 imagenes TRAMPA: las que cambiarian de veredicto si yosys hubiera roto los
#      3 bits bajos de los sesgos (yosys avisa "b_rom ... used but has no driver"). En el Mac
#      paso 8/8: el aviso es falso. Es la prueba que habria cazado el bug de thr_lo (§20.6).
#   6. GTKWave        : las tres fotos del banco, solas, a out/foto_*.pdf
#
#   sh placa_vm.sh foto    -> solo el paso 6 (si ya corrio lo demas)
#
# Grabar: copiar out/mnist78_placa.bin al disco iCELink (en el Mac aparece como /Volumes/iCELink).
# Probar: en el Mac, `python placa78.py` manda las 10 000 del test y compara con el golden.
set -e
AQUI="$(cd "$(dirname "$0")" && pwd)"; cd "$AQUI"; mkdir -p out
export PATH="$HOME/Documents/UN/oss-cad-suite/bin:$PATH"
RTL="rtl/fpga_mnist78_stream.v rtl/uart_rx.v rtl/uart_tx.v rtl/mnist_top78.v \
     rtl/mnist_feat16_mem.v rtl/mnist_clf78_x2.v rtl/linebuf3x3.v"

echo "=========================================================="
echo "  TOP78 EN LA PLACA · flujo serie · 97,22 %"
echo "=========================================================="
FALTA=0
for f in $RTL rtl/mnist_weights78_x2.vh sim/tb_stream78.v sim/img.hex sim/exp.hex \
         sim/trampa.hex sim/trampa_exp.hex mnist78_placa.pcf foto_gtkwave.tcl stream78.gtkw; do
    [ -f "$f" ] || { echo "  !! FALTA $f"; FALTA=1; }
done
[ "$FALTA" = 0 ] || { echo "  Copiar lo que falte desde el Mac a utm-share/mnist78_placa/"; exit 1; }
echo "  ficheros completos"

foto() {
    echo; echo "== 6/6 fotos de GTKWave"
    command -v gtkwave >/dev/null || { echo "  !! gtkwave no esta en el PATH"; return; }
    gtkwave -S foto_gtkwave.tcl out/stream78.vcd stream78.gtkw >out/gtkwave.log 2>&1 || true
    if ls out/foto_*.pdf >/dev/null 2>&1; then
        ls -la out/foto_*.pdf | awk '{printf "    %8s bytes  %s\n",$5,$9}'
    else
        echo "  !! no salieron los PDF (ver out/gtkwave.log)."
        echo "     Plan B: gtkwave out/stream78.vcd stream78.gtkw  y captura de pantalla"
    fi
}
if [ "$1" = "foto" ]; then foto; exit 0; fi

echo; echo "== 1/6 simulacion (iverilog + vvp), la UART bit a bit"
iverilog -g2012 -Irtl -Ptb_stream78.DIV=8 -o out/sim.vvp sim/tb_stream78.v $RTL
( cd out && vvp -n sim.vvp +IN=../sim/img.hex +EXP=../sim/exp.hex +OUT=sim.out \
      +NB=4 +NLOT=2 +VCD ) | tee out/sim.log | grep -vE "^VCD info" | sed 's/^/    /'
grep -q "ALL TESTS PASSED" out/sim.log || { echo "  !! la simulacion NO paso: no se sintetiza"; exit 1; }
echo "    formas de onda: out/stream78.vcd  (gtkwave out/stream78.vcd stream78.gtkw)"

echo; echo "== 2/6 sintesis (yosys)"
yosys -p "read_verilog -sv -Irtl $RTL; synth_ice40 -top top -json out/placa.json" \
    > out/yosys.log 2>&1 || { echo "  !! fallo yosys"; grep -E "ERROR" out/yosys.log; exit 1; }
NRAM=$(awk '/Printing statistics/{f=1} f' out/yosys.log | grep -E "SB_RAM40_4K" | tail -1 | awk '{print $1}')
echo "    SB_RAM40_4K: $NRAM   (tienen que ser 9)"
[ "$NRAM" = 9 ] || { echo "  !! la BRAM no se infirio como se esperaba"; exit 1; }

echo; echo "== 3/6 place & route (nextpnr)"
nextpnr-ice40 --up5k --package sg48 --freq 12 --json out/placa.json \
    --pcf mnist78_placa.pcf --asc out/placa.asc > out/pnr.log 2>&1 \
    || { echo "  !! fallo nextpnr"; grep -E "ERROR" out/pnr.log | head; exit 1; }
grep -E "ICESTORM_LC|ICESTORM_RAM|SB_IO:" out/pnr.log | head -3 | sed 's/^Info: */    /'
grep -E "Max frequency" out/pnr.log | tail -1 | sed 's/^Info: */    /'

echo; echo "== 4/6 bitstream (icepack)"
icepack out/placa.asc out/mnist78_placa.bin
ls -la out/mnist78_placa.bin | awk '{printf "    %s bytes  %s\n",$5,$9}'
md5sum out/mnist78_placa.bin | sed 's/^/    md5 /'

echo; echo "== 5/6 simulacion POST-SINTESIS: el netlist de yosys, sobre 8 imagenes trampa (~1 min)"
yosys -q -p "read_verilog -sv -Irtl $RTL; chparam -set DIVISOR 8 -set IDLE 4000 top; \
             synth_ice40 -top top; write_verilog -noattr out/top_sintetizado.v" >out/yosys_post.log 2>&1
sed -e 's/top #(.DIVISOR(DIV), .IDLE(IDLE)) dut (/top dut (/' \
    -e '/dumpvars(1, tb_stream78.dut.CAD)/d' sim/tb_stream78.v > out/tb_post.v
iverilog -g2012 -o out/post.vvp out/tb_post.v out/top_sintetizado.v \
    "$(yosys-config --datdir)/ice40/cells_sim.v" 2>&1 | grep -i "error" || true
( cd out && vvp -n post.vvp +IN=../sim/trampa.hex +EXP=../sim/trampa_exp.hex +OUT=post.out \
      +NB=4 +NLOT=2 ) | tee out/post.log | grep -vE "^WARNING|VCD info" | sed 's/^/    /'
grep -q "ALL TESTS PASSED" out/post.log \
    || { echo "  !! el NETLIST no reproduce el golden: yosys construyo OTRO circuito. NO grabar."; exit 1; }

foto

echo
echo "  LISTO. Grabar: copiar out/mnist78_placa.bin al disco iCELink."
echo "  Despues, en el Mac:  cd ~/UN/Tesis/Repository/tty_project_filter/clasificador_mnist"
echo "                       /opt/anaconda3/bin/python placa78.py 20      # prueba corta"
echo "                       /opt/anaconda3/bin/python placa78.py         # las 10 000 (~12 min)"
[ "$1" = "ver" ] && { gtkwave out/stream78.vcd stream78.gtkw >/dev/null 2>&1 & }
exit 0
