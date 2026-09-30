# fig_4_trans_rtl.py — copia de ~/utm-share/sim_canny/render_trans.py: entrada | modelo | núcleo RTL | cámara RTL,
# con rótulos en español y sin título interno (el pie de la tesis lo describe).
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _base_rtl_montaje import montaje
montaje("sim_canny", "{}_trans_golden.hex", "{}_tcore.hex", "{}_tcam.hex", "fig_4_trans_rtl.png")
