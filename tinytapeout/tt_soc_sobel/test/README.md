# Test — tt_um_soc_sobel_vic

```bash
iverilog -g2012 -o tb.out test/tb.v src/tt_um_soc_sobel_vic.v src/soc_sobel_top.v \
    src/femtorv32_quark.v src/peripheral_filter.v src/linebuf3x3.v
vvp tb.out    # tb.vcd -> GTKWave: mira cpu_wrote_filter (uio_out[2]), out_valid (uio_out[1]), uo_out
```
El CPU arranca de ROM sintetizada; cpu_wrote_filter=1 confirma que corrio el firmware.
