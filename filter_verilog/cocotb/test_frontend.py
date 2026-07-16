"""cocotb TB de ov7670_frontend: una OV7670 FALSA maneja PCLK/HREF/VSYNC/D[7:0]
enviando una fila de pixeles RGB565 (2 bytes c/u); se verifica el stream de gris
contra el golden (misma luma sin multiplicar Y=(R+2G+B)>>2)."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge

# pixeles de prueba (r5, g6, b5)
PIXELS = [(31, 63, 31),  # blanco
          (0, 0, 0),      # negro
          (31, 0, 0),     # rojo
          (0, 63, 0),     # verde
          (0, 0, 31),     # azul
          (16, 32, 16)]   # gris medio


def gray_golden(r5, g6, b5):
    r8 = (r5 << 3) | (r5 >> 2)
    g8 = (g6 << 2) | (g6 >> 4)
    b8 = (b5 << 3) | (b5 >> 2)
    return (r8 + 2 * g8 + b8) >> 2


async def fake_camera(dut, pixels):
    dut.cam_pclk.value = 0; dut.cam_href.value = 0; dut.cam_vsync.value = 0; dut.cam_d.value = 0
    for _ in range(6):
        await FallingEdge(dut.sysclk)
    # frame start: pulso de VSYNC
    dut.cam_vsync.value = 1
    for _ in range(6):
        await FallingEdge(dut.sysclk)
    dut.cam_vsync.value = 0
    for _ in range(6):
        await FallingEdge(dut.sysclk)
    # linea activa: HREF alto (se sostiene unos ciclos para que el sync lo capte)
    dut.cam_href.value = 1
    for _ in range(8):
        await FallingEdge(dut.sysclk)
    for (r5, g6, b5) in pixels:
        b0 = ((r5 & 0x1f) << 3) | ((g6 >> 3) & 0x7)     # {R[4:0], G[5:3]}
        b1 = ((g6 & 0x7) << 5) | (b5 & 0x1f)            # {G[2:0], B[4:0]}
        for byte in (b0, b1):
            dut.cam_d.value = byte                      # dato estable con PCLK bajo
            await FallingEdge(dut.sysclk)
            await FallingEdge(dut.sysclk)
            dut.cam_pclk.value = 1                      # flanco de subida -> captura
            for _ in range(3):
                await FallingEdge(dut.sysclk)
            dut.cam_pclk.value = 0
            await FallingEdge(dut.sysclk)
    dut.cam_href.value = 0


@cocotb.test()
async def frontend_gray(dut):
    cocotb.start_soon(Clock(dut.sysclk, 20, units="ns").start())
    dut.rst_n.value = 0
    dut.cam_d.value = 0; dut.cam_pclk.value = 0; dut.cam_href.value = 0; dut.cam_vsync.value = 0
    for _ in range(5):
        await FallingEdge(dut.sysclk)
    dut.rst_n.value = 1

    exp = [gray_golden(*p) for p in PIXELS]
    cocotb.start_soon(fake_camera(dut, PIXELS))

    got = []
    for _ in range(4000):
        await RisingEdge(dut.sysclk)
        if int(dut.gray_valid.value) == 1:
            got.append(int(dut.gray.value))
        if len(got) >= len(PIXELS):
            break

    dut._log.info(f"gris capturado: {got}")
    dut._log.info(f"gris esperado : {exp}")
    assert got == exp, f"mismatch: got {got} exp {exp}"
    dut._log.info("OV7670 FRONTEND (SCCB + captura + RGB565->gris): ALL TESTS PASSED")
