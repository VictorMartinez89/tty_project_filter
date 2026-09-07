#!/usr/bin/env python3
"""gen_rom_digitos.py — mete N digitos de MNIST en una ROM de Verilog.

La FPGA no tiene de donde leer imagenes, asi que los digitos de prueba van EN EL BITSTREAM.
Es el mismo truco de la ROM sintetizada del firmware (la leccion "el firmware no se carga solo"),
aplicado a los datos en vez de al codigo.
"""
import sys, os
import numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import frente_golden as fg

N = int(sys.argv[1]) if len(sys.argv) > 1 else 10
_, _, Xte, yte = fg.cargar_mnist(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "mnist.npz"))

# un ejemplar de cada digito 0..9 (los primeros del conjunto de prueba)
idx = [int(np.where(yte == k)[0][0]) for k in range(10)][:N]
imgs = Xte[idx]
etq = yte[idx]
PX = 28*28

with open("rom_digitos.v", "w") as f:
    f.write("// rom_digitos.v — GENERADO por gen_rom_digitos.py. No editar a mano.\n")
    f.write(f"//   {N} digitos de MNIST ({PX} pixeles cada uno) y sus etiquetas.\n")
    f.write(f"//   Indices en el conjunto de prueba: {idx}\n")
    f.write("`default_nettype none\n")
    f.write(f"module rom_digitos (\n    input  wire [{(N*PX-1).bit_length()-1}:0] addr,\n"
            f"    output wire [7:0] pix,\n    input  wire [3:0] sel,\n    output wire [3:0] etiqueta\n);\n")
    f.write(f"    localparam integer N_DIG = {N};\n    localparam integer PX = {PX};\n")
    f.write(f"    reg [7:0] mem [0:{N*PX-1}];\n    initial begin\n")
    for i, im in enumerate(imgs):
        f.write(f"        // digito {etq[i]} (test #{idx[i]})\n")
        v = im.ravel()
        for j in range(0, PX, 16):
            vals = ", ".join(f"8'h{x:02x}" for x in v[j:j+16])
            f.write(f"        {{mem[{i*PX+j}], " + "".join(f"mem[{i*PX+j+k}], " for k in range(1,15)) +
                    f"mem[{i*PX+j+15}]}} = {{{vals}}};\n")
    f.write("    end\n    assign pix = mem[addr];\n")
    f.write("    function [3:0] et; input [3:0] s; begin case (s)\n")
    for i, e in enumerate(etq):
        f.write(f"        4'd{i}: et = 4'd{e};\n")
    f.write("        default: et = 4'd0;\n    endcase end endfunction\n")
    f.write("    assign etiqueta = et(sel);\nendmodule\n`default_nettype wire\n")
print(f"-> rom_digitos.v  ({N} digitos, {N*PX} bytes = {N*PX*8} bits)")
print(f"   etiquetas: {list(etq)}")
