# canny78 — el chip 17: Canny-78 en sky130

Es **exactamente** el RTL que dio 10 000/10 000 en la iCESugar (§36.15 del cuaderno 2, §5.6.9 de la
tesis): `mnist_top78` + `mnist_feat16_mem` + `mnist_clf78_x2` + `linebuf3x3` + `mnist_weights78_x2.vh`,
tomados de `clasificador_mnist/rtl/`. Los md5 de `md5_fuentes.txt` se comprobaron contra el paquete de la
placa (`utm-share/mnist78_placa/rtl/`) el 24-sep.

- Tope `mnist_top78`: un pixel por ciclo, sale digito + rechazo. Un reloj, reset sincrono explicito.
- Auditoria FPGA→ASIC: sin `initial` ni `reg x = v`, sin primitivas Lattice, sin avisos de anchura.
  Las memorias arrancan sin inicializar; iverilog las arranca en X y la cadena dio 10000/10000.
- Config: 30 ns (33 MHz; en FPGA cierra a 16,45), `FP_CORE_UTIL` 30, `PL_TARGET_DENSITY` 0,40.
- Tamano esperado ~35 000 celdas sky130 (yosys generico x 1,383). **No cabe en Tiny Tapeout** (16 368
  maximo en 8x2): en ASIC las 9 BRAM de la FPGA se vuelven ~6 300 biestables.
- Se decidio con Victor NO recortar `fmem` (256x13 → 168x9 ahorraria ~8 000 celdas) para fabricar el mismo
  circuito que se verifico en la placa.

Preparar en la VM: `sh /mnt/share/utm-share/canny78_asic/preparar_canny78.sh`
