# Test — tt_um_soc_sobel_vic

**cocotb (estandar TT):** `cd test && make`. Verifica que el CPU arranque de la ROM y ponga
`cpu_wrote_filter` (uio_out[2]) en alto, y luego que salga `out_valid` (uio_out[1]) al meter pixeles.
