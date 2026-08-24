# cocotb test para tt_um_trans_mini_vic (motor transitivo 32x24, Tiny Tapeout).
#
# La prueba es la que define al filtro: una CADENA de pixeles debiles colgando de UN solo
# fuerte. La histeresis de 1 salto solo salvaria al vecino pegado; la transitiva salva
# la cadena ENTERA. Se comprueba que el motor emite mas bordes que la semilla sola.
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles

H, W = 32, 24          # el frame del motor "mini"
NADA, DEBIL, FUERTE = 0, 1, 2

def bit(sig, i):
    s = str(sig.value)
    c = s[len(s) - 1 - i]
    return c if c in "01" else "x"

@cocotb.test()
async def test_transitivo_salva_la_cadena(dut):
    dut._log.info(f"Motor transitivo mini {H}x{W}: cargando un frame de clase")
    cocotb.start_soon(Clock(dut.clk, 100, units="ns").start())   # 10 MHz
    dut.ena.value = 1; dut.ui_in.value = 0; dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 8)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 4)

    # frame: fila 10 = un FUERTE en la columna 2 y una cadena de DEBILes de la 3 a la 20
    frame = [[NADA] * W for _ in range(H)]
    frame[10][2] = FUERTE
    for x in range(3, 21):
        frame[10][x] = DEBIL
    cadena = 1 + 18                      # el fuerte + los 18 debiles encadenados

    # esperar a que el motor pida la carga. OJO: primero LIMPIA el frame padded
    # ((H+2)x(W+2) = 884 celdas), asi que tarda ~900 ciclos en llegar a S_LOAD.
    listo = False
    for _ in range(5000):
        await RisingEdge(dut.clk)
        if bit(dut.uio_out, 3) == "1":   # load_ready
            listo = True
            break
    assert listo, "el motor nunca pidio la carga (load_ready)"

    # cargar el frame entero, un pixel por ciclo
    for y in range(H):
        for x in range(W):
            dut.ui_in.value = frame[y][x]
            dut.uio_in.value = 1         # in_valid
            await RisingEdge(dut.clk)
    dut.uio_in.value = 0

    # el motor barre hasta el punto fijo y despues emite el mapa de bordes
    bordes, salidas, terminado = 0, 0, False
    for _ in range(200000):
        await RisingEdge(dut.clk)
        if bit(dut.uio_out, 1) == "1":   # out_valid
            salidas += 1
            if bit(dut.uo_out, 0) == "1":
                bordes += 1
        if bit(dut.uio_out, 2) == "1":   # done
            terminado = True
            break

    dut._log.info(f"done={terminado}  pixeles emitidos={salidas}  bordes={bordes} (cadena={cadena})")
    assert terminado, "el motor nunca dio done"
    assert bordes >= cadena, (f"solo {bordes} bordes: la histeresis no propago la cadena entera "
                              f"(se esperaban al menos {cadena})")
    dut._log.info("La cadena de debiles se salvo entera: eso es la histeresis TRANSITIVA")
