## Colorlight i9+ v6.1 -- Xilinx Artix-7 XC7A50T-FGG484
## Constraints minimas para blinky (reloj + LED).

## Reloj de 25 MHz
set_property -dict { PACKAGE_PIN K4  IOSTANDARD LVCMOS33 } [get_ports { clk }]
create_clock -period 40.000 -name sys_clk [get_ports { clk }]   ;# 25 MHz = 40 ns

## LED D2
set_property -dict { PACKAGE_PIN A18 IOSTANDARD LVCMOS33 } [get_ports { led }]
