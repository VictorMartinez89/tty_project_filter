# cocotb test para tt_um_canny1_vic (Tiny Tapeout).
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles

@cocotb.test()
async def test_canny1_stream(dut):
    dut._log.info("Arrancando test de Canny1")
    cocotb.start_soon(Clock(dut.clk, 100, units="ns").start())   # 10 MHz
    # reset
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)
    # stream de pixeles con in_valid = uio_in[0]
    seen_valid = 0
    for i in range(600):
        dut.uio_in.value = 1               # in_valid alto
        dut.ui_in.value = (i * 37) & 0xFF
        await RisingEdge(dut.clk)
        if (int(dut.uio_out.value) >> 1) & 1:   # out_valid = uio_out[1]
            seen_valid += 1
    dut._log.info(f"pulsos de out_valid: {seen_valid}")
    assert seen_valid > 0, "no salio ningun out_valid"
