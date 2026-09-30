# fig_4_sobel_rtl.py — copia de ~/utm-share/sim_sobel/render.py: entrada | modelo | núcleo RTL | cámara RTL,
# con rótulos en español y sin título interno (el pie de la tesis lo describe).
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _base_rtl_montaje import montaje
# out/monarch_core.hex de la share se sobrescribió (26-jul 14:41) después de hacer el montaje
# original; datos/sobel_monarch_core.hex es la salida de volver a correr tb_sobel_core.v
# (iverilog) sobre hex/monarch_60x80.hex, y es bit a bit igual al modelo.
AQUI = os.path.dirname(os.path.abspath(__file__))
montaje("sim_sobel", "{}_golden.hex", "{}_core.hex", "{}_cam.hex", "fig_4_sobel_rtl.png",
        core_override={"monarch": os.path.join(AQUI, "datos", "sobel_monarch_core.hex")})
