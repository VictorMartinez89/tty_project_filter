"""cocotb testbench de STREAMING para nms_control (NMS con ventana deslizante 3x3).
Transmite un raster de (mag, dir) fila por fila, captura las salidas interiores y
las compara contra un golden en python (misma ventana 3x3 + nms_core).

Incluye un caso 'cresta vertical' para VER el adelgazamiento (banda ancha -> 1 px).
Convencion de direccion: 0=N 1=NE 2=E 3=SE 4=S 5=SW 6=W 7=NW
"""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge
import random

MAGW = 8
# dir -> (vecino a, vecino b) en ventana row-major w0..w8 (w4 = centro)
PAIRS = {0: (1, 7), 1: (2, 6), 2: (3, 5), 3: (0, 8),
         4: (1, 7), 5: (2, 6), 6: (3, 5), 7: (0, 8)}


def golden(mag, dr, H, W):
    """NMS por pixel interior, en orden raster; devuelve lista de (mag,keep,dir)."""
    outs = []
    for cr in range(1, H - 1):
        for cc in range(1, W - 1):
            win = [mag[cr - 1][cc - 1], mag[cr - 1][cc], mag[cr - 1][cc + 1],
                   mag[cr    ][cc - 1], mag[cr    ][cc], mag[cr    ][cc + 1],
                   mag[cr + 1][cc - 1], mag[cr + 1][cc], mag[cr + 1][cc + 1]]
            d = dr[cr][cc]; a, b = PAIRS[d]
            keep = 1 if (win[4] >= win[a] and win[4] >= win[b]) else 0
            outs.append((win[4] if keep else 0, keep, d))
    return outs


async def run_stream(dut, mag, dr, H, W):
    cocotb.start_soon(Clock(dut.clk_i, 10, units="ns").start())
    dut.nreset_i.value = 0
    dut.in_valid_i.value = 0
    dut.mag_i.value = 0
    dut.dir_i.value = 0
    await FallingEdge(dut.clk_i)
    dut.img_w_i.value = W
    dut.nreset_i.value = 1

    flat = [(mag[r][c], dr[r][c]) for r in range(H) for c in range(W)]
    got = []

    async def driver():
        for m, d in flat:
            await FallingEdge(dut.clk_i)
            dut.mag_i.value = int(m)
            dut.dir_i.value = int(d)
            dut.in_valid_i.value = 1
        await FallingEdge(dut.clk_i)
        dut.in_valid_i.value = 0

    cocotb.start_soon(driver())
    for _ in range(len(flat) + 8):
        await RisingEdge(dut.clk_i)
        if int(dut.out_valid_o.value) == 1:
            got.append((int(dut.mag_o.value),
                        int(dut.keep_o.value),
                        int(dut.dir_o.value)))
    return got


@cocotb.test()
async def nms_ctrl_ridge(dut):
    """Cresta vertical: perfil de magnitud con pico en la columna 4 + gradiente
    horizontal (dir=E). El NMS debe dejar SOLO la columna pico -> linea de 1 px."""
    H = W = 8
    prof = [max(0, 255 - abs(c - 4) * 40) for c in range(W)]     # pico en c=4
    mag = [[prof[c] for c in range(W)] for _ in range(H)]
    dr = [[2 for _ in range(W)] for _ in range(H)]              # 2 = E (horizontal)

    got = await run_stream(dut, mag, dr, H, W)
    exp = golden(mag, dr, H, W)
    assert got == exp, f"ridge mismatch:\n got {got}\n exp {exp}"

    IW = W - 2
    dut._log.info("ENTRADA mag (fila interior, igual en todas las filas):")
    dut._log.info("  " + " ".join(f"{prof[c + 1]:3d}" for c in range(IW)))
    dut._log.info("SALIDA keep (# = borde tras NMS, . = suprimido):")
    for r in range(H - 2):
        row = got[r * IW:(r + 1) * IW]
        dut._log.info("  " + " ".join("#" if k == 1 else "." for (_, k, _) in row))
    dut._log.info("nms_control ridge OK: banda ancha adelgazada a 1 px")


@cocotb.test()
async def nms_ctrl_random(dut):
    """Estres del windowing/alineacion: raster aleatorio de (mag,dir) 10x10."""
    random.seed(7)
    H = W = 10
    mag = [[random.randint(0, 255) for _ in range(W)] for _ in range(H)]
    dr = [[random.randint(0, 7) for _ in range(W)] for _ in range(H)]

    got = await run_stream(dut, mag, dr, H, W)
    exp = golden(mag, dr, H, W)
    assert len(got) == len(exp), f"conteo salidas {len(got)} != esperadas {len(exp)}"
    ok = sum(g == e for g, e in zip(got, exp))
    dut._log.info(f"nms_control random: {ok}/{len(exp)} OK")
    assert got == exp, "mismatch vs golden"
    dut._log.info("NMS CONTROL (cocotb streaming): ALL TESTS PASSED")
