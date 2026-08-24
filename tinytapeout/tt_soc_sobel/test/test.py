# cocotb test para tt_um_soc_sobel_vic (SoC RISC-V + Sobel, ROM interna).
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles

def bit(sig, i):
    """Bit i de una senal, como '0', '1' o 'x' (no resuelto).
    Al arrancar las salidas valen X y cocotb 2.x revienta con int(): por eso se lee como texto."""
    s = str(sig.value)
    c = s[len(s) - 1 - i]
    return c if c in "01" else "x"


@cocotb.test()
async def test_soc_sobel_boots_and_streams(dut):
    dut._log.info("Arrancando test del SoC + Sobel")
    cocotb.start_soon(Clock(dut.clk, 100, units="ns").start())   # 10 MHz
    dut.ena.value = 1; dut.ui_in.value = 0; dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 8)
    dut.rst_n.value = 1
    # el CPU arranca de la ROM y escribe el periferico -> cpu_wrote_filter = uio_out[2]
    booted = False
    for _ in range(300):
        await RisingEdge(dut.clk)
        if bit(dut.uio_out, 2) == "1":
            booted = True; break
    assert booted, "el CPU no configuro el filtro (cpu_wrote_filter nunca subio)"
    dut._log.info("SoC arranco: cpu_wrote_filter=1")
    # ahora stream de pixeles
    seen_valid = 0
    for i in range(600):
        dut.uio_in.value = 1            # in_valid (bit0)
        dut.ui_in.value = (i * 37) & 0xFF
        await RisingEdge(dut.clk)
        if bit(dut.uio_out, 1) == "1":         # out_valid = uio_out[1]
            seen_valid += 1
    dut._log.info(f"out_valid pulses: {seen_valid}")
    assert seen_valid > 0, "no salio ningun out_valid"
