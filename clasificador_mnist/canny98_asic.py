#!/usr/bin/env python3
"""canny98_asic.py — la versión de Canny-98 para silicio (sky130): rtl/mnist_clf98_asic.v y rtl/canny98_rom.vh.
Dos cambios frente a mnist_clf98.v (el de la placa, 10 000/10 000):
  1. la SPRAM no existe en sky130: las 120 activaciones van a un banco de registros con la MISMA temporización
     (se escribe con sp_we; si no se escribe, se lee y el dato sale un ciclo después, como DATAOUT);
  2. sin `initial $readmemh`: pesos y sesgos son funciones case (como mnist_weights78_x2.vh de Canny-78).
El resto del fichero es idéntico, línea por línea."""
import numpy as np, re
p = np.load("pesos_canny98_H120.npz"); W1, b1, W2, b2 = p["W1q"], p["b1i"], p["W2q"], p["b2i"]
H = W1.shape[0]
w = np.zeros(21504, dtype=np.int64); w[:H*168] = W1.reshape(-1); w[H*168:H*168+10*H] = W2.reshape(-1)
L = ["// canny98_rom.vh — GENERADO por canny98_asic.py desde pesos_canny98_H120.npz. Pesos de 4 bits y sesgos de 9,",
     "// en complemento a dos: W1 en j*168+k, W2 en 20160+c*120+j. Sustituye a los .hex de la version de la placa.",
     "function [3:0] w_rom(input [14:0] a);", "    case (a)"]
L += [f"        15'd{i}: w_rom = 4'h{int(x) & 0xF:x};" for i, x in enumerate(w) if x != 0]
L += ["        default: w_rom = 4'h0;", "    endcase", "endfunction",
      "function [8:0] b1_rom(input [6:0] j);", "    case (j)"]
L += [f"        7'd{i}: b1_rom = 9'h{int(x) & 0x1FF:03x};" for i, x in enumerate(b1)]
L += ["        default: b1_rom = 9'h000;", "    endcase", "endfunction",
      "function [8:0] b2_rom(input [3:0] c);", "    case (c)"]
L += [f"        4'd{i}: b2_rom = 9'h{int(x) & 0x1FF:03x};" for i, x in enumerate(b2)]
L += ["        default: b2_rom = 9'h000;", "    endcase", "endfunction", ""]
open("rtl/canny98_rom.vh", "w").write("\n".join(L))
s = open("rtl/mnist_clf98.v").read()
s = s.replace("module mnist_clf98 #(", "module mnist_clf98_asic #(", 1)
i = s.index("    // ---- las memorias de solo lectura: pesos y sesgos ----"); j = s.index("    // ---- fmem:")
s = s[:i] + ("    // ---- pesos y sesgos: funciones case (canny98_rom.vh); en silicio no hay BRAM que inicializar ----\n"
             "`include \"canny98_rom.vh\"\n\n") + s[j:]
s = s.replace("    always @(posedge clk) w_d <= wmem[w_a];", "    always @(posedge clk) w_d <= w_rom(w_a);")
i = s.index("    SB_SPRAM256KA HMEM ("); j = s.index(");", i) + 2
s = s[:i] + ("    // en sky130 no hay SPRAM: 128 x 8 bits en registros, con la misma temporizacion que DATAOUT\n"
             "    reg [7:0] hmem [0:127];\n    reg [7:0] hq;\n"
             "    always @(posedge clk) if (sp_we) hmem[sp_a[6:0]] <= sp_din[7:0]; else hq <= hmem[sp_a[6:0]];\n"
             "    assign sp_dout = {8'd0, hq};") + s[j:]
for a, b in [("{{(AW-9){b1mem[j][8]}}, b1mem[j]}", "$signed(b1_rom(j))"), ("{{(AW-9){b1mem[jn][8]}}, b1mem[jn]}", "$signed(b1_rom(jn))"),
             ("{{(AW-9){b2mem[c][8]}}, b2mem[c]}", "$signed(b2_rom(c))"), ("{{(AW-9){b2mem[cn][8]}}, b2mem[cn]}", "$signed(b2_rom(cn))")]:
    assert s.count(a) == 1, a; s = s.replace(a, b)
codigo = re.sub(r"//.*", "", s); assert "readmemh" not in codigo and "SB_SPRAM" not in codigo and "b1mem" not in codigo and "b2mem" not in codigo
open("rtl/mnist_clf98_asic.v", "w").write(s)
print("ok", len(L), "lineas en la ROM")
