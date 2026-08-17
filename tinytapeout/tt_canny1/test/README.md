# Test — tt_um_canny1_vic

Simulacion rapida con iverilog:

```bash
iverilog -g2012 -o tb.out test/tb.v src/tt_um_canny1_vic.v src/canny1_top.v src/linebuf3x3.v
vvp tb.out          # genera tb.vcd -> abrir en GTKWave (out_valid = uio_out[1], uo_out)
```

Tiny Tapeout usa cocotb por defecto; este tb en Verilog es un chequeo minimo de humo.
