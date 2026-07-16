"""cocotb TB de ov7670_sccb: modela una OV7670 falsa (esclavo SCCB) que decodifica
las escrituras de 3 fases y verifica que la tabla de config se transmita bien.
Decodifica muestreando SIOD en cada flanco de subida de SIOC, y detecta START/STOP
(SIOD cambia mientras SIOC esta alto)."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

CAM_ADDR = 0x42
# misma tabla STARTER que ov7670_sccb.v (reg, valor)
ROM = [(0x12, 0x14), (0x40, 0xd0), (0x11, 0x01), (0x0C, 0x04), (0x3E, 0x19)]


def rd(sig):
    s = str(sig.value)          # '0','1','z','x'
    return 0 if s == '0' else 1  # open-drain soltado (z) -> pull-up -> 1


@cocotb.test()
async def sccb_config(dut):
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(5):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 1              # pulso de arranque (queda latcheado)

    txns = []                        # transacciones (id, reg, val) decodificadas
    bits, bytes_ = [], []
    in_txn = False
    prev_c, prev_d = 1, 1

    # DIV=30 quarters, 4 quarters/bit, 9 bits/byte, 3 bytes + start/stop + delay
    # por registro ~ 3600 ciclos; 5 registros ~ 18000. Damos margen.
    for _ in range(60000):
        await RisingEdge(dut.clk)
        c = rd(dut.sioc); d = rd(dut.siod)
        # START: SIOD 1->0 con SIOC alto
        if c == 1 and prev_c == 1 and prev_d == 1 and d == 0:
            in_txn = True; bits = []; bytes_ = []
        # STOP: SIOD 0->1 con SIOC alto
        elif c == 1 and prev_c == 1 and prev_d == 0 and d == 1:
            if in_txn and len(bytes_) == 3:
                txns.append(tuple(bytes_))
            in_txn = False
        # dato: muestrear SIOD en el flanco de subida de SIOC
        elif in_txn and prev_c == 0 and c == 1:
            bits.append(d)
            if len(bits) == 9:                       # 8 datos + 1 don't-care
                b = 0
                for k in range(8):
                    b = (b << 1) | bits[k]           # MSB primero
                bytes_.append(b); bits = []
        prev_c, prev_d = c, d
        if int(dut.done.value) == 1 and not in_txn:
            break

    dut._log.info(f"transacciones decodificadas: {len(txns)}")
    for i, tx in enumerate(txns):
        dut._log.info(f"  reg[{i}]: id=0x{tx[0]:02x} reg=0x{tx[1]:02x} val=0x{tx[2]:02x}")

    assert len(txns) == len(ROM), f"escrituras {len(txns)} != esperadas {len(ROM)}"
    for i, (reg, val) in enumerate(ROM):
        assert txns[i] == (CAM_ADDR, reg, val), \
            f"reg[{i}] hw={txns[i]} exp=(0x{CAM_ADDR:02x},0x{reg:02x},0x{val:02x})"
    dut._log.info("OV7670 SCCB: ALL TESTS PASSED (config transmitida OK)")
