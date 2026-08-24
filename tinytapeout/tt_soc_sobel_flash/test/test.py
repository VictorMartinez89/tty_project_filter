# cocotb test para tt_um_soc_sobel_flash_vic (SoC RISC-V + Sobel, arranque desde flash SPI externa).
#
# Este chip NO lleva ROM adentro: el CPU busca su firmware en una flash SPI de afuera, como un
# microcontrolador. Sin un modelo de flash conectado, el CPU no llega a ejecutar nada — pero SI
# se puede comprobar lo que define a esta variante: que al salir del reset el SoC empieza a
# hablarle a la flash (baja cs_n y mueve el reloj SPI). Eso es el arranque, observado desde afuera.
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles

def bit(sig, i):
    """Bit i de una senal, como '0', '1' o 'x' (no resuelto)."""
    s = str(sig.value)
    c = s[len(s) - 1 - i]
    return c if c in "01" else "x"

@cocotb.test()
async def test_arranca_a_leer_la_flash(dut):
    dut._log.info("Arrancando el SoC que bootea desde flash SPI")
    cocotb.start_soon(Clock(dut.clk, 100, units="ns").start())   # 10 MHz
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0            # miso en 0: no hay flash de verdad conectada
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 8)
    dut.rst_n.value = 1

    # uio_out[3] = flash_clk, [4] = flash_cs_n, [5] = flash_mosi
    cs_bajo, flancos_clk, mosi_activo = False, 0, False
    anterior = "x"
    for _ in range(2000):
        await RisingEdge(dut.clk)
        if bit(dut.uio_out, 4) == "0":
            cs_bajo = True
        actual = bit(dut.uio_out, 3)
        if actual == "1" and anterior == "0":
            flancos_clk += 1
        anterior = actual
        if bit(dut.uio_out, 5) == "1":
            mosi_activo = True

    dut._log.info(f"cs_n bajo={cs_bajo}  flancos de flash_clk={flancos_clk}  mosi activo={mosi_activo}")
    assert cs_bajo,        "el SoC nunca selecciono la flash (cs_n no bajo)"
    assert flancos_clk > 0, "el SoC nunca genero reloj SPI hacia la flash"
    assert mosi_activo,    "el SoC nunca envio el comando de lectura por MOSI"
    dut._log.info("El SoC arranca leyendo su firmware de la flash externa")

    # y los pines bidireccionales estan configurados como toca
    assert str(dut.uio_oe.value) == "00111110", f"uio_oe deberia ser 00111110, es {dut.uio_oe.value}"
