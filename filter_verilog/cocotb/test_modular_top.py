"""cocotb TB de canny_modular_top: cadena modular hasta la CLASE.
Encadena sobel_compass_control -> nms_control -> canny_grad_threshold_core y
compara la clase por pixel contra un golden COMPUESTO (compass o NMS o umbral)."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge
import numpy as np

LOW, HIGH = 40, 200
KER = {"N": [[1, 2, 1], [0, 0, 0], [-1, -2, -1]], "NE": [[2, 1, 0], [1, 0, -1], [0, -1, -2]],
       "E": [[1, 0, -1], [2, 0, -2], [1, 0, -1]], "SE": [[0, -1, -2], [1, 0, -1], [2, 1, 0]],
       "S": [[-1, -2, -1], [0, 0, 0], [1, 2, 1]], "SW": [[-2, -1, 0], [-1, 0, 1], [0, 1, 2]],
       "W": [[-1, 0, 1], [-2, 0, 2], [-1, 0, 1]], "NW": [[0, 1, 2], [-1, 0, 1], [-2, -1, 0]]}
ORDER = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
PAIRS = {0: (1, 7), 1: (2, 6), 2: (3, 5), 3: (0, 8), 4: (1, 7), 5: (2, 6), 6: (3, 5), 7: (0, 8)}


def compass(img):
    H, W = img.shape
    mag = np.zeros((H - 2, W - 2), int); dr = np.zeros((H - 2, W - 2), int)
    for cr in range(1, H - 1):
        for cc in range(1, W - 1):
            win = img[cr - 1:cr + 2, cc - 1:cc + 2]
            raw = [abs(int((win * np.array(KER[d])).sum())) for d in ORDER]
            d = int(np.argmax(raw)); dr[cr - 1, cc - 1] = d; mag[cr - 1, cc - 1] = min(255, raw[d])
    return mag, dr


def nms(mag, dr):
    h, w = mag.shape; out = np.zeros((h - 2, w - 2), int)
    for cr in range(1, h - 1):
        for cc in range(1, w - 1):
            win = mag[cr - 1:cr + 2, cc - 1:cc + 2].flatten()
            a, b = PAIRS[int(dr[cr, cc])]
            out[cr - 1, cc - 1] = win[4] if (win[4] >= win[a] and win[4] >= win[b]) else 0
    return out


def golden_class(img):
    m2 = nms(*compass(img))
    return np.where(m2 >= HIGH, 2, np.where(m2 >= LOW, 1, 0))


@cocotb.test()
async def modular_class(dut):
    rng = np.random.default_rng(3)
    H = W = 12
    img = rng.integers(0, 256, size=(H, W))
    exp = [int(x) for x in golden_class(img).flatten().tolist()]

    cocotb.start_soon(Clock(dut.clk_i, 10, units="ns").start())
    dut.nreset_i.value = 0; dut.px_valid_i.value = 0; dut.px_i.value = 0
    dut.low_i.value = LOW; dut.high_i.value = HIGH; dut.img_w_i.value = W
    await FallingEdge(dut.clk_i); dut.nreset_i.value = 1

    flat = img.flatten().tolist(); got = []

    async def drive():
        for px in flat:
            await FallingEdge(dut.clk_i); dut.px_i.value = int(px); dut.px_valid_i.value = 1
        await FallingEdge(dut.clk_i); dut.px_valid_i.value = 0

    cocotb.start_soon(drive())
    for _ in range(len(flat) + 16):
        await RisingEdge(dut.clk_i)
        if int(dut.out_valid_o.value) == 1:
            got.append(int(dut.class_o.value))

    assert len(got) == len(exp), f"salidas {len(got)} != esperadas {len(exp)}"
    ok = sum(g == e for g, e in zip(got, exp))
    dut._log.info(f"class {ok}/{len(exp)} ({100 * ok / len(exp):.1f}%)  "
                  f"clases={ {k: exp.count(k) for k in (0, 1, 2)} }")
    assert got == exp, "mismatch vs golden compuesto"
    dut._log.info("CANNY MODULAR TOP (compass->NMS->umbral): ALL TESTS PASSED")
