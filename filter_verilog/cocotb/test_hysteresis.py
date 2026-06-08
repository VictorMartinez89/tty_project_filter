"""cocotb TB de canny_hysteresis_frame: histeresis TRANSITIVA completa.
Compara contra el golden Python (reconstruccion morfologica 8-conexa via scipy.label)."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge
import numpy as np
from scipy.ndimage import label

H = W = 16
def pack(mask):
    v = 0
    for r in range(H):
        for c in range(W):
            if mask[r, c]: v |= (1 << (r*W + c))
    return v
def unpack(val):
    m = np.zeros((H, W), int)
    for r in range(H):
        for c in range(W):
            if (val >> (r*W + c)) & 1: m[r, c] = 1
    return m
def hyst_full(strong, weak):                       # golden: 8-conexo transitivo
    lbl, _ = label(weak | strong, structure=np.ones((3, 3), int))
    keep = set(np.unique(lbl[strong > 0])) - {0}
    return np.isin(lbl, list(keep)).astype(int)

@cocotb.test()
async def hysteresis(dut):
    rng = np.random.default_rng(11)
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    dut.rst.value = 1; dut.start.value = 0; dut.strong_i.value = 0; dut.weak_i.value = 0
    await FallingEdge(dut.clk); await FallingEdge(dut.clk); dut.rst.value = 0

    total_fail = 0
    for t in range(5):
        strong = (rng.random((H, W)) < 0.04).astype(int)
        weak   = (rng.random((H, W)) < 0.35).astype(int) & (1 - strong)
        exp = hyst_full(strong, weak)
        dut.strong_i.value = pack(strong); dut.weak_i.value = pack(weak)
        await FallingEdge(dut.clk); dut.start.value = 1
        await FallingEdge(dut.clk); dut.start.value = 0
        passes = 0
        while int(dut.done.value) == 0:
            await RisingEdge(dut.clk); passes += 1
            if passes > H*W: break
        got = unpack(int(dut.edge_o.value))
        ok = int((got == exp).all()); total_fail += (0 if ok else 1)
        dut._log.info(f"test {t}: {'OK' if ok else 'FAIL'}  passes={passes}  "
                      f"strong={strong.sum()} weak={weak.sum()} edges={exp.sum()}")
    assert total_fail == 0, f"{total_fail} fallos vs golden transitivo"
    dut._log.info("CANNY HYSTERESIS FRAME (transitiva): ALL TESTS PASSED")
