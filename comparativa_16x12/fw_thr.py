#!/usr/bin/env python3
# fw_thr.py — recompila el firmware de los SoC para un par de umbrales nuevo.
#
#   Los tres filtros sueltos reciben los umbrales por PUERTOS: cambiarlos es un plusarg
#   del banco. Los tres SoC no: los llevan GRABADOS EN LA ROM sintetizada, en dos
#   instrucciones RISC-V. Recalibrar el filtro es, literalmente, recompilar software.
#
#   La palabra del periferico 0x0045 es  THR = {thr_hi[15:8], thr_lo[7:0]}, y el firmware
#   la arma con  lui x3,U  +  addi x3,x3,I  (addi extiende signo, por eso el +0x800).
#
#   Uso:  python3 fw_thr.py <hi> <lo>                 solo muestra las instrucciones
#         python3 fw_thr.py <hi> <lo> --patch <dir>   las escribe en los 3 soc_*_top.v
import re, sys

def lui_addi(valor, rd=3):
    bajo  = valor & 0xFFF
    imm12 = bajo - 0x1000 if bajo >= 0x800 else bajo      # addi extiende signo
    upper = (valor - imm12) >> 12                          # lo que debe dejar el lui
    lui   = ((upper & 0xFFFFF) << 12) | (rd << 7) | 0x37
    addi  = ((imm12 & 0xFFF) << 20) | (rd << 15) | (rd << 7) | 0x13
    assert ((upper << 12) + imm12) & 0xFFFFFFFF == valor, "el par lui/addi no reconstruye el valor"
    return lui, addi, upper, imm12

def parchar(path, hi, lo):
    v = (hi << 8) | lo
    lui, addi, U, I = lui_addi(v)
    s = open(path).read()
    s2 = re.sub(r"(3'd3: rom_q <= 32'h)[0-9a-f]{8}(;\s*//).*",
                lambda m: f"{m.group(1)}{lui:08x}{m.group(2)}  lui  x3,0x{U:X}", s)
    s2 = re.sub(r"(3'd4: rom_q <= 32'h)[0-9a-f]{8}(;\s*//).*",
                lambda m: f"{m.group(1)}{addi:08x}{m.group(2)} addi x3,x3,{I} -> x3=0x{v:04X}", s2)
    s2 = re.sub(r"(3'd5: rom_q <= 32'h0030a223;\s*//).*",
                lambda m: f"{m.group(1)} sw   x3,4(x1)   -> THR: thr_hi={hi}, thr_lo={lo}", s2)
    if s2 == s:
        raise SystemExit(f"!! no se pudo parchar {path}")
    open(path, "w").write(s2)
    return f"{path}: THR=0x{v:04X}  lui 32'h{lui:08x}  addi 32'h{addi:08x}"

if __name__ == "__main__":
    hi, lo = int(sys.argv[1]), int(sys.argv[2])
    if "--patch" in sys.argv:
        d = sys.argv[sys.argv.index("--patch") + 1]
        print(parchar(f"{d}/soc_sobel_top.v",  hi, 0))    # el Sobel tiene UN umbral: thr_lo=0
        print(parchar(f"{d}/soc_canny1_top.v", hi, lo))
        print(parchar(f"{d}/soc_trans_top.v",  hi, lo))
    else:
        lui, addi, U, I = lui_addi((hi << 8) | lo)
        print(f"THR = 0x{(hi<<8)|lo:04X}  (thr_hi={hi}, thr_lo={lo})")
        print(f"  lui  x3,0x{U:X}     -> 32'h{lui:08x}")
        print(f"  addi x3,x3,{I}   -> 32'h{addi:08x}")
