# fig_4_trans_motor.py — copia de ~/utm-share/sim_canny/trans_wave_plot.py + vcd_wave.py (parser y
# dibujo), con textos en español y el eje de tiempo en microsegundos.
# CORRECCIÓN DE UNIDAD: el VCD (out/trans_wave.vcd, de tb_trans_wave.v con `timescale 1ns/1ps`)
# declara "$timescale 1ps": sus tiempos están en PICOsegundos. El dibujo original rotulaba "ns";
# aquí se divide entre 1e6 y se rotula en µs (el barrido completo del cuadro 60×80 dura ≈ 453 µs).
import os
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt

VCD = "/Users/vic/utm-share/sim_canny/out/trans_wave.vcd"
SALIDA = "/Users/vic/UN/Tesis/Repository/tty_project_filter/tesis/figuras/fig_4_trans_motor.png"
PS_POR_US = 1e6
# codificación de estados en hysteresis_frame_bram_sync.sv (S_CLR=0 ... S_DONE=5)
ESTADOS = {"0": "borrar", "1": "cargar", "2": "barrer", "3": "comprobar", "4": "leer", "5": "fin"}

def parse_vcd(path):
    sigs, name2id, cur_t, in_defs = {}, {}, 0, True
    with open(path) as f:
        for line in f:
            s = line.strip()
            if not s: continue
            if in_defs:
                if s.startswith('$timescale'):
                    pass
                if s.startswith('$var'):
                    p = s.split(); vid = p[3]
                    sigs[vid] = {'name': p[4], 'width': int(p[2]), 'tv': []}
                    name2id[p[4]] = vid
                elif s.startswith('$enddefinitions'):
                    in_defs = False
                continue
            c0 = s[0]
            if c0 == '#':
                cur_t = int(s[1:])
            elif c0 in '01xzXZ':
                vid = s[1:]
                if vid in sigs: sigs[vid]['tv'].append((cur_t, s[0]))
            elif c0 in 'bB':
                sp = s.split(); vid = sp[1]
                if vid in sigs: sigs[vid]['tv'].append((cur_t, sp[0][1:]))
    return sigs, name2id

def val_at(tv, t):
    v = None
    for (tt, vv) in tv:
        if tt <= t: v = vv
        else: break
    return v

def segs_in(tv, t0, t1):
    out, cur, ta = [], val_at(tv, t0), t0
    for (tt, vv) in tv:
        if tt <= t0: continue
        if tt >= t1: break
        out.append((ta, tt, cur)); ta = tt; cur = vv
    out.append((ta, t1, cur))
    return out

def rotulo_bus(nm, b):
    if b is None: return '?'
    if set(b) <= set('01'):
        v = format(int(b, 2), 'X')
        return ESTADOS.get(v, v) if nm == "state" else v
    return b

def draw(sigs, name2id, names, t0, t1, titulo, out_png):
    fig, ax = plt.subplots(figsize=(13, 0.42*len(names)+1.2))
    span = t1 - t0
    for row, nm in enumerate(names):
        y = (len(names)-1-row)
        sig = sigs[name2id[nm]]; segs = segs_in(sig['tv'], t0, t1)
        if sig['width'] == 1:
            xs, ys = [], []
            for (ta, tb, v) in segs:
                lvl = 0.8 if v == '1' else (0.0 if v == '0' else 0.4)
                xs += [ta, tb]; ys += [y+lvl, y+lvl]
            ax.step(xs, ys, where='post', color='#00b050', lw=1.1)
            ax.plot([t0, t1], [y, y], color='#dddddd', lw=0.4, zorder=0)
        else:
            for (ta, tb, v) in segs:
                ax.plot([ta, tb], [y+0.8, y+0.8], color='#0070c0', lw=1.0)
                ax.plot([ta, tb], [y+0.0, y+0.0], color='#0070c0', lw=1.0)
                ax.plot([ta, ta], [y+0.0, y+0.8], color='#0070c0', lw=0.7)
                if (tb-ta) > span*0.012:
                    ax.text((ta+tb)/2, y+0.4, rotulo_bus(nm, v), fontsize=7,
                            ha='center', va='center', color='#003366')
        ax.text(t0 - span*0.006, y+0.4, nm, fontsize=8, ha='right', va='center')
    ax.set_xlim(t0 - span*0.14, t1); ax.set_ylim(-0.3, len(names))
    ax.set_yticks([]); ax.set_xlabel("tiempo (µs)", fontsize=9)
    ax.set_title(titulo, fontsize=10)
    for sp in ('top', 'right', 'left'): ax.spines[sp].set_visible(False)
    fig.tight_layout(); fig.savefig(out_png, dpi=107, bbox_inches='tight')
    print("figura ->", out_png)

# comprobación de la unidad declarada en el VCD
with open(VCD) as f:
    cab = f.read(400)
assert "$timescale\n\t1ps" in cab, "el VCD ya no está en ps: revisar la escala"

sigs, n2i = parse_vcd(VCD)
for s in sigs.values():                                  # ps -> µs
    s['tv'] = [(t / PS_POR_US, v) for (t, v) in s['tv']]
tmax = max(t for s in sigs.values() for (t, _) in s['tv'])
names = ["state", "eng_load_ready", "eng_in_valid", "changed", "conf_c", "weak_c", "nb8", "newc",
         "eng_out_valid", "eng_edge", "eng_done"]
draw(sigs, n2i, [n for n in names if n in n2i], 0, tmax,
     "Motor de histéresis transitiva: borrar → cargar → [barrer ↔ comprobar] × N (changed = 1)"
     " → punto fijo (changed = 0) → leer → fin", SALIDA)
print(f"duración total simulada: {tmax:.1f} µs")
