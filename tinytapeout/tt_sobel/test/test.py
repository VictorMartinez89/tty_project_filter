# cocotb test para tt_um_sobel_vic (Tiny Tapeout).
# Comprueba dos cosas: que salen pulsos de out_valid, y que un borde sintetico
# (mitad oscura / mitad clara) produce pixeles de borde (0xFF) y zonas planas (0x00).
#
# Nota: al arrancar, las salidas valen X hasta que el pipeline se llena. cocotb 2.x
# lanza ValueError si se hace int() sobre una senal con X, asi que se leen como
# cadena de bits y se ignora lo que no sea 0/1.
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles

W = 60          # ancho de fila del datapath
FILAS = 12

def bit(sig, i):
    """Bit i de una senal, como '0', '1' o 'x' (no resuelto)."""
    s = str(sig.value)
    c = s[len(s) - 1 - i]
    return c if c in "01" else "x"

def byte(sig):
    """Valor entero de una senal de 8 bits, o None si tiene X."""
    s = str(sig.value)
    return int(s, 2) if set(s) <= {"0", "1"} else None

@cocotb.test()
async def test_sobel_stream(dut):
    dut._log.info("Arrancando test de Sobel")
    cocotb.start_soon(Clock(dut.clk, 100, units="ns").start())   # 10 MHz
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)

    # imagen sintetica: columnas 0..29 oscuras (20), 30..59 claras (200)
    # -> el borde vertical vive en la columna 30
    salidas, bordes, planos = 0, 0, 0
    for f in range(FILAS):
        for x in range(W):
            dut.uio_in.value = 1                      # in_valid alto
            dut.ui_in.value = 20 if x < W // 2 else 200
            await RisingEdge(dut.clk)
            if bit(dut.uio_out, 1) == "1":            # out_valid = uio_out[1]
                v = byte(dut.uo_out)
                if v is not None:
                    salidas += 1
                    if v == 0xFF: bordes += 1
                    elif v == 0x00: planos += 1

    dut._log.info(f"out_valid: {salidas} px  ->  {bordes} borde (0xFF), {planos} plano (0x00)")
    assert salidas > 0, "no salio ningun out_valid"
    assert bordes  > 0, "el escalon de brillo no produjo ningun borde"
    assert planos  > 0, "TODO salio borde: el umbral no esta discriminando"
