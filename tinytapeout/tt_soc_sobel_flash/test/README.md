# Test — tt_um_soc_sobel_flash_vic

Simulacion con **cocotb** + Icarus Verilog.

```bash
rm -rf sim_build results.xml
make -B
```

Esta variante arranca desde una **flash SPI externa**, asi que sin un modelo de flash conectado el CPU
no ejecuta firmware. Lo que el test comprueba es el **arranque visto desde afuera**: que al salir del
reset el SoC baja `cs_n`, genera reloj SPI y envia el comando de lectura por MOSI — es decir, que va a
buscar su programa. Tambien verifica que `uio_oe` deja los pines en la direccion correcta.

Para una simulacion completa con firmware hay un banco propio con modelo de flash en el monorepo de la
tesis (`tb_flash.v` + `fw_sobel_flash.hex`).
