# fig_4_canny_rtl.py — copia de ~/utm-share/sim_canny/render_canny.py: entrada | modelo | núcleo RTL | cámara RTL,
# con rótulos en español y sin título interno (el pie de la tesis lo describe).
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _base_rtl_montaje import montaje
montaje("sim_canny", "{}_canny_golden.hex", "{}_ccore.hex", "{}_ccam.hex", "fig_4_canny_rtl.png")
