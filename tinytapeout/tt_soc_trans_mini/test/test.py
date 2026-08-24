# cocotb test para tt_um_soc_trans_mini_vic (SoC RISC-V + motor transitivo 16x12).
#
# Comprueba las dos mitades del chip:
#   1) el CEREBRO: el CPU arranca de su ROM y configura el periferico (modo transitivo).
#   2) el MOTOR:   una cadena de debiles colgando de UN fuerte se salva ENTERA, que es
#      justamente lo que distingue a la histeresis transitiva de la de 1 salto.
import os

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles

H, W = 16, 12          # el frame del motor con CPU adentro (mas chico que el de 32x24 sin CPU)
NADA, DEBIL, FUERTE = 0, 1, 2

def bit(sig, i):
    """Bit i de una senal, como '0', '1' o 'x' (no resuelto)."""
    s = str(sig.value)
    c = s[len(s) - 1 - i]
    return c if c in "01" else "x"

@cocotb.test()
async def test_cpu_configura_y_motor_propaga(dut):
    dut._log.info(f"SoC + motor transitivo mini {H}x{W}")
    cocotb.start_soon(Clock(dut.clk, 100, units="ns").start())   # 10 MHz
    dut.ena.value = 1; dut.ui_in.value = 0; dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 8)
    dut.rst_n.value = 1

    # ---- 1) el cerebro: el CPU escribe el periferico ----
    booted = False
    for _ in range(300):
        await RisingEdge(dut.clk)
        if bit(dut.uio_out, 4) == "1":       # cpu_wrote_filter
            booted = True
            break
    assert booted, "el CPU no configuro el filtro (cpu_wrote_filter nunca subio)"
    await ClockCycles(dut.clk, 60)           # los umbrales llegan unas instrucciones despues

    if os.environ.get("GATES") != "yes":     # senales internas: no existen en el netlist aplanado
        modo = int(str(dut.user_project.u_soc.mode_o.value), 2)
        thr_hi = int(str(dut.user_project.u_soc.thr_hi_o.value), 2)
        thr_lo = int(str(dut.user_project.u_soc.thr_lo_o.value), 2)
        dut._log.info(f"el CPU fijo: modo={modo}, thr_hi={thr_hi}, thr_lo={thr_lo}")
        assert modo == 2, f"el CPU eligio modo {modo}, se esperaba 2 (transitivo)"
        assert (thr_hi, thr_lo) == (110, 70), f"umbrales {thr_hi}/{thr_lo}, se esperaban 110/70"
    else:
        dut._log.info("gate-level: se omite el chequeo de senales internas")

    # ---- 2) el motor: cargar un frame con UNA semilla y una cadena de debiles ----
    frame = [[NADA] * W for _ in range(H)]
    frame[8][1] = FUERTE
    for x in range(2, W - 1):
        frame[8][x] = DEBIL
    cadena = 1 + (W - 1 - 2)                 # el fuerte + los debiles encadenados

    listo = False
    for _ in range(5000):                    # el motor limpia el frame padded antes de pedir carga
        await RisingEdge(dut.clk)
        if bit(dut.uio_out, 3) == "1":       # load_ready
            listo = True
            break
    assert listo, "el motor nunca pidio la carga (load_ready)"

    for y in range(H):
        for x in range(W):
            dut.ui_in.value = frame[y][x]
            dut.uio_in.value = 1             # in_valid
            await RisingEdge(dut.clk)
    dut.uio_in.value = 0

    bordes, salidas, terminado = 0, 0, False
    for _ in range(200000):
        await RisingEdge(dut.clk)
        if bit(dut.uio_out, 1) == "1":       # out_valid
            salidas += 1
            if bit(dut.uo_out, 0) == "1":
                bordes += 1
        if bit(dut.uio_out, 2) == "1":       # done
            terminado = True
            break

    dut._log.info(f"done={terminado}  pixeles emitidos={salidas}  bordes={bordes} (cadena={cadena})")
    assert terminado, "el motor nunca dio done"
    assert bordes >= cadena, (f"solo {bordes} bordes: la histeresis no propago la cadena entera "
                              f"(se esperaban al menos {cadena})")
    dut._log.info("El CPU configuro el motor Y la cadena de debiles se salvo entera")
