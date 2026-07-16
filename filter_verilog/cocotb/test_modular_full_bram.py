"""cocotb TB de canny_modular_full_bram: cadena modular COMPLETA con histeresis en BRAM.
gris -> compass -> NMS -> doble umbral -> hysteresis_frame_bram_sync (BRAM) -> stream borde.
Golden: clase compuesta + reconstruccion morfologica 8-conexa (scipy.label).

Secuencia: reset -> esperar load_ready (histeresis termino su CLR) -> streamear gris
-> capturar el stream de borde hasta done_o."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge
import numpy as np
from scipy.ndimage import label

LOW, HIGH = 40, 200
IH = IW = 12          # interior = H-4
H = W = IH + 4

KER = {"N": [[1, 2, 1], [0, 0, 0], [-1, -2, -1]], "NE": [[2, 1, 0], [1, 0, -1], [0, -1, -2]],
       "E": [[1, 0, -1], [2, 0, -2], [1, 0, -1]], "SE": [[0, -1, -2], [1, 0, -1], [2, 1, 0]],
       "S": [[-1, -2, -1], [0, 0, 0], [1, 2, 1]], "SW": [[-2, -1, 0], [-1, 0, 1], [0, 1, 2]],
       "W": [[-1, 0, 1], [-2, 0, 2], [-1, 0, 1]], "NW": [[0, 1, 2], [-1, 0, 1], [-2, -1, 0]]}
ORDER = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
PAIRS = {0: (1, 7), 1: (2, 6), 2: (3, 5), 3: (0, 8), 4: (1, 7), 5: (2, 6), 6: (3, 5), 7: (0, 8)}


def compass(img):
    Hh, Ww = img.shape
    mag = np.zeros((Hh - 2, Ww - 2), int); dr = np.zeros((Hh - 2, Ww - 2), int)
    for cr in range(1, Hh - 1):
        for cc in range(1, Ww - 1):
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


def hyst_full(strong, weak):
    lbl, _ = label(weak | strong, structure=np.ones((3, 3), int))
    keep = set(np.unique(lbl[strong > 0])) - {0}
    return np.isin(lbl, list(keep)).astype(int)


def golden_edge(img):
    cls = golden_class(img)
    return hyst_full((cls == 2).astype(int), (cls == 1).astype(int))


@cocotb.test()
async def modular_full_bram(dut):
    rng = np.random.default_rng(5)
    cocotb.start_soon(Clock(dut.clk_i, 10, units="ns").start())
    dut.low_i.value = LOW; dut.high_i.value = HIGH; dut.img_w_i.value = W

    # imagen 0 = estructurada (campo debil + escalon fuerte); 1-2 aleatorias
    ramp = np.zeros((H, W), int)
    for i in range(H):
        for j in range(W):
            ramp[i, j] = min(255, 8 * i + (170 if i >= 8 else 0))
    imgs = [ramp, rng.integers(0, 256, size=(H, W)), rng.integers(0, 256, size=(H, W))]

    fails = 0
    for t, img in enumerate(imgs):
        exp = golden_edge(img)
        cls = golden_class(img)
        nS = int((cls == 2).sum()); nW = int((cls == 1).sum())

        # reset
        dut.nreset_i.value = 0; dut.px_valid_i.value = 0; dut.px_i.value = 0
        await FallingEdge(dut.clk_i); await FallingEdge(dut.clk_i)
        dut.nreset_i.value = 1

        # esperar load_ready (la histeresis termino su CLR)
        for _ in range(8 * (IH + 2) * (IW + 2)):
            await RisingEdge(dut.clk_i)
            if int(dut.load_ready_o.value) == 1:
                break

        # streamear el gris
        flat = img.flatten().tolist()

        async def drive():
            for px in flat:
                await FallingEdge(dut.clk_i); dut.px_i.value = int(px); dut.px_valid_i.value = 1
            await FallingEdge(dut.clk_i); dut.px_valid_i.value = 0
        cocotb.start_soon(drive())

        # capturar el stream de borde hasta done_o
        got = []
        for _ in range(len(flat) + 400 * (IH * IW)):
            await RisingEdge(dut.clk_i)
            if int(dut.out_valid_o.value) == 1:
                got.append(int(dut.edge_o.value))
            if int(dut.done_o.value) == 1:
                break

        assert len(got) == IH * IW, f"img {t}: bordes {len(got)} != {IH*IW}"
        got = np.array(got).reshape(IH, IW)
        ok = int((got == exp).all()); fails += (0 if ok else 1)
        promoted = int(exp.sum()) - nS
        dut._log.info(f"img {t}: {'OK' if ok else 'FAIL'}  strong={nS} weak={nW}  "
                      f"edges_exp={int(exp.sum())} got={int(got.sum())}  (promovidos={promoted})")

    assert fails == 0, f"{fails} imagenes fallaron vs golden"
    dut._log.info("CANNY MODULAR FULL BRAM (cadena + histeresis BRAM): ALL TESTS PASSED")
