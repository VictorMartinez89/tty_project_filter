# vision_top — dos relojes ASINCRONOS: clk (sistema: SCCB+display) y cam_pclk (camara: captura+Sobel+fb).
create_clock -name clk      -period 20.000 [get_ports {clk}]
create_clock -name cam_pclk -period 40.000 [get_ports {cam_pclk}]
# los dos dominios se cruzan solo por el framebuffer (async) -> no se analizan entre si
set_clock_groups -asynchronous -group [get_clocks {clk}] -group [get_clocks {cam_pclk}]
set_clock_uncertainty 0.25 [all_clocks]
set_input_delay  2.0 -clock clk [all_inputs]
set_output_delay 2.0 -clock clk [all_outputs]
