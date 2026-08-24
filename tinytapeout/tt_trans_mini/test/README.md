# Test — tt_um_canny1_vic

**cocotb (estandar de Tiny Tapeout):**
```bash
cd test && make      # necesita cocotb + iverilog; corre test.py sobre tb.v
```
`test.py` mete un stream de pixeles y verifica que salga `out_valid` (uio_out[1]).

**iverilog directo (smoke test alternativo):** ver `tb.v` (wrapper) — para un tb con estimulo propio,
usa el patron del proyecto tt_soc_sobel.
