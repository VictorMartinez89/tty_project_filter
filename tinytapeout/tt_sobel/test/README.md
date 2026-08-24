# Test — tt_um_sobel_vic

Simulacion con **cocotb** + Icarus Verilog.

```bash
rm -rf sim_build results.xml     # el sim_build se comparte entre proyectos: limpiarlo al cambiar
make -B
```

El test alimenta una imagen sintetica de 60x12 con un **escalon de brillo** en la columna 30
(oscuro 20 / claro 200) y comprueba que:

1. salen pulsos de `out_valid` (`uio_out[1]`),
2. aparecen pixeles de **borde** (`uo_out == 0xFF`) donde esta el escalon,
3. **no** sale todo borde — o sea que el umbral (90) discrimina.

Las formas de onda quedan en `tb.vcd`.
