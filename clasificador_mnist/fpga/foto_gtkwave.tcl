# foto_gtkwave.tcl — GTKWave saca solo las tres fotos del banco tb_stream78 y se cierra.
#   gtkwave -S foto_gtkwave.tcl out/stream78.vcd stream78.gtkw
# Los instantes salen de la simulacion con DIV=8, que es determinista: en la VM caen igual.
set d [file normalize out]
# A · la corrida entera
gtkwave::/Time/Zoom/Zoom_Full
gtkwave::/File/Print_To_File PDF {A4 (210mm x 297mm)} Visible $d/foto_A_corrida.pdf
# B · un pixel entrando por la UART (el byte 400)
gtkwave::setZoomRangeTimes 327475000 328575000
gtkwave::/File/Print_To_File PDF {A4 (210mm x 297mm)} Visible $d/foto_B_byte.pdf
# C · el primer veredicto: frame_done -> done -> byte de respuesta
gtkwave::setZoomRangeTimes 639755000 649435000
gtkwave::/File/Print_To_File PDF {A4 (210mm x 297mm)} Visible $d/foto_C_veredicto.pdf
gtkwave::/File/Quit
