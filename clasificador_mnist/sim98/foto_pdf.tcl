# foto_pdf.tcl — GTKWave saca solo las 4 vistas a PDF apaisado y se cierra.
set d [file normalize out]
set papel {A4 (11.68" x 8.26")}
foreach {n t0 t1} {A 0 1266000000  B 250800000 255600000  C 254700000 258300000  D 459800000 472400000} {
    gtkwave::setZoomRangeTimes $t0 $t1
    gtkwave::/File/Print_To_File PDF $papel Full $d/vista_$n.pdf
}
gtkwave::/File/Quit
