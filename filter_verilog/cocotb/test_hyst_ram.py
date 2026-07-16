"""cocotb TB de hysteresis_frame_ram: histeresis TRANSITIVA sintetizable (RAM+barridos).
Carga clase por pixel (stream), espera done_o, captura el borde por pixel, y compara
contra el golden Python (reconstruccion morfologica 8-conexa via scipy.label)."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge
import numpy as np
from scipy.ndimage import label

H = W = 12          # = parametros por defecto del modulo


def hyst_full(strong, weak):                       # golden: 8-conexo transitivo
    lbl, _ = label(weak | strong, structure=np.ones((3, 3), int))
    keep = set(np.unique(lbl[strong > 0])) - {0}
    return np.isin(lbl, list(keep)).astype(int)


@cocotb.test()
async def hyst_ram(dut):
    rng = np.random.default_rng(11)
    cocotb.start_soon(Clock(dut.clk_i, 10, units="ns").start())

    fails = 0
    for t in range(6):
        strong = (rng.random((H, W)) < 0.04).astype(int)
        weak   = (rng.random((H, W)) < 0.35).astype(int) & (1 - strong)
        cls    = (2 * strong + 1 * weak).astype(int)      # 0/1/2 por pixel
        exp    = hyst_full(strong, weak)

        # reset
        dut.nreset_i.value = 0; dut.in_valid_i.value = 0; dut.class_i.value = 0
        await FallingEdge(dut.clk_i); await FallingEdge(dut.clk_i)
        dut.nreset_i.value = 1

        # esperar fin de CLR (load_ready)
        for _ in range(4 * (H + 2) * (W + 2)):
            await RisingEdge(dut.clk_i)
            if int(dut.load_ready_o.value) == 1:
                break

        # streamear la clase en orden raster
        flat = cls.flatten().tolist()

        async def drive():
            for v in flat:
                await FallingEdge(dut.clk_i)
                dut.class_i.value = int(v); dut.in_valid_i.value = 1
            await FallingEdge(dut.clk_i); dut.in_valid_i.value = 0
        cocotb.start_soon(drive())

        # capturar el borde durante READ hasta done_o
        got = []
        for _ in range(len(flat) + 400 * (H * W)):
            await RisingEdge(dut.clk_i)
            if int(dut.out_valid_o.value) == 1:
                got.append(int(dut.edge_o.value))
            if int(dut.done_o.value) == 1:
                break

        assert len(got) == H * W, f"test {t}: bordes {len(got)} != {H*W}"
        got = np.array(got).reshape(H, W)
        ok = int((got == exp).all()); fails += (0 if ok else 1)
        dut._log.info(f"test {t}: {'OK' if ok else 'FAIL'}  strong={int(strong.sum())} "
                      f"weak={int(weak.sum())} edges_exp={int(exp.sum())} edges_got={int(got.sum())}")

    assert fails == 0, f"{fails} fallos vs golden transitivo"
    dut._log.info("HYSTERESIS FRAME RAM (sintetizable, transitiva): ALL TESTS PASSED")
