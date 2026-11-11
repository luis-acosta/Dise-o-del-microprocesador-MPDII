# -*- coding: utf-8 -*-
"""Lee mpdii.vcd y genera las graficas de simulacion del MPDII."""
import re, json
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.ticker import MaxNLocator

VCD = 'mpdii.vcd'
DATA, CTRL, STAT, MUTED, INK = '#13395B', '#B45309', '#0F766E', '#64748B', '#0F172A'
GRID = '#E2E8F0'

# ------------------------------------------------------------------ parser
ids, scope, tscale = {}, [], 1.0
lines = open(VCD).read().splitlines()
i = 0
while i < len(lines):
    L = lines[i].strip()
    if L.startswith('$timescale'):
        m = re.search(r'(\d+)\s*(fs|ps|ns|us|ms)', L + lines[i + 1])
        tscale = int(m.group(1)) * {'fs': 1e-6, 'ps': 1e-3, 'ns': 1, 'us': 1e3, 'ms': 1e6}[m.group(2)]
    elif L.startswith('$scope'):
        scope.append(L.split()[2])
    elif L.startswith('$upscope'):
        scope.pop()
    elif L.startswith('$var'):
        p = L.split()
        sid, name = p[3], p[4].split('[')[0]
        ids[sid] = '.'.join(scope + [name])
    elif L.startswith('$enddefinitions'):
        i += 1
        break
    i += 1

waves = {v: [] for v in ids.values()}
t = 0
for L in lines[i:]:
    L = L.strip()
    if not L or L.startswith('$'):
        continue
    if L[0] == '#':
        t = int(L[1:]) * tscale
    elif L[0] in 'bB':
        val, sid = L[1:].split()
        waves[ids[sid]].append((t, val))
    elif L[0] == 'r':
        continue
    else:
        waves[ids[L[1:].strip()]].append((t, L[0]))


def num(v):
    try:
        return int(v, 2)
    except ValueError:
        return None


def series(path, as_int=True):
    w = waves.get(path, [])
    return [(t, num(v) if as_int else v) for t, v in w]


def value_at(path, t):
    last = None
    for tt, v in waves.get(path, []):
        if tt <= t:
            last = v
        else:
            break
    return last


def clip(data, t0, t1):
    """Recorta una serie a la ventana [t0,t1] conservando el valor previo."""
    out, prev = [], None
    for tt, v in data:
        if tt < t0:
            prev = v
        elif tt <= t1:
            if not out and prev is not None:
                out.append((t0, prev))
            out.append((tt, v))
    if not out:
        out = [(t0, prev if prev is not None else 0)]
    out.append((t1, out[-1][1]))
    return out


def step(ax, data, color, lw=1.8, scale=1.0, offset=0.0):
    xs, ys = [], []
    for tt, v in data:
        if v is None:
            v = 0
        xs.append(tt); ys.append(v * scale + offset)
    if xs:
        xs.append(xs[-1] + 1)
        ys.append(ys[-1])
    ax.step(xs, ys, where='post', color=color, lw=lw)
    return xs, ys


TB, DP, CU = 'tb_mpdii', 'tb_mpdii.uut.u_dp', 'tb_mpdii.uut.u_cu'
clk   = series(f'{TB}.clk')
rst   = series(f'{TB}.reset')
st    = series(f'{CU}.st_code')
pc    = series(f'{DP}.s_pc_q')
ir    = series(f'{DP}.s_ir_q')
acc   = series(f'{DP}.s_acc_q')
busy  = series(f'{DP}.s_busy')
outen = series(f'{CU}.out_en')
zero  = series(f'{DP}.zero_dp')
posf  = series(f'{DP}.positive_dp')
outdp = series(f'{TB}.out_dp', as_int=False)
rfld  = series(f'{CU}.rf_load')
rfad  = series(f'{CU}.rf_addr')

# ------------------------------------------------- reconstruir banco de registros
events = sorted({t for t, _ in clk} | {t for t, _ in rfld})
regs, hist = {n: 0 for n in range(16)}, []
prev_clk = '0'
for tt in events:
    c = value_at(f'{TB}.clk', tt)
    if prev_clk == '0' and c == '1':
        if value_at(f'{CU}.rf_load', tt) == '1':
            a = num(value_at(f'{CU}.rf_addr', tt) or '0') or 0
            d = num(value_at(f'{DP}.s_busy', tt) or '0')
            if d is not None:
                regs[a] = d
                hist.append((tt, dict(regs)))
    prev_clk = c if c in '01' else prev_clk

r1 = [(t, r[1]) for t, r in hist]
r3 = [(t, r[3]) for t, r in hist]
r1 = [(0, 0)] + r1
r3 = [(0, 0)] + r3

ESTADOS = ['S0', 'S1', 'S2', 'S3', 'S4', 'S5', 'S6', 'S7', 'S8', 'S9', 'S10']


def frame(ax, t0, t1, label, ylab=''):
    ax.set_xlim(t0, t1)
    ax.grid(True, axis='both', color=GRID, lw=0.7)
    ax.set_axisbelow(True)
    ax.set_ylabel(label, rotation=0, ha='right', va='center',
                  fontsize=10.5, fontweight='bold', color=INK, labelpad=12)
    for s in ('top', 'right'):
        ax.spines[s].set_visible(False)
    for s in ('left', 'bottom'):
        ax.spines[s].set_color('#CBD5E1')
    ax.tick_params(labelsize=8.5, colors=MUTED)


# ============================================================ FIGURA 1
T0, T1 = 50, 560
fig, axs = plt.subplots(6, 1, figsize=(15, 8.2), sharex=True,
                        gridspec_kw={'height_ratios': [.7, .7, 1.1, 1, 1, 1], 'hspace': .32})
fig.patch.set_facecolor('white')

step(axs[0], clip(clk, T0, T1), INK, 1.4); frame(axs[0], T0, T1, 'clk'); axs[0].set_yticks([0, 1])
step(axs[1], clip(rst, T0, T1), CTRL, 1.8); frame(axs[1], T0, T1, 'reset'); axs[1].set_yticks([0, 1])
step(axs[2], clip(st, T0, T1), CTRL, 2.0); frame(axs[2], T0, T1, 'estado')
axs[2].set_yticks(range(11)); axs[2].set_yticklabels(ESTADOS, fontsize=7.5)
step(axs[3], clip(pc, T0, T1), DATA, 2.0); frame(axs[3], T0, T1, 'PC')
axs[3].yaxis.set_major_locator(MaxNLocator(integer=True, nbins=5)); axs[3].margins(y=.3)
step(axs[4], clip(ir, T0, T1), DATA, 2.0); frame(axs[4], T0, T1, 'IR')
axs[4].set_yticks([]); axs[4].margins(y=.35)
step(axs[5], clip(acc, T0, T1), STAT, 2.2); frame(axs[5], T0, T1, 'Acc'); axs[5].margins(y=.35)
axs[5].set_xlabel('tiempo [ns]', fontsize=10, color=MUTED)

for tt, v in ir:
    if T0 <= tt <= T1 and v:
        axs[4].annotate(f'{v:04X}', (tt, v), textcoords='offset points',
                        xytext=(3, 4), fontsize=7.5, color=DATA, fontweight='bold')
for tt, v in acc:
    if T0 <= tt <= T1 and v is not None:
        axs[5].annotate(str(v), (tt, v), textcoords='offset points',
                        xytext=(3, 4), fontsize=8, color=STAT, fontweight='bold')

fig.suptitle('Figura 1 · Ciclo de busqueda y ejecucion — arranque del programa',
             fontsize=14, fontweight='bold', color=INK, x=.09, ha='left', y=.975)
fig.text(.09, .935, 'Cada instruccion ocupa tres ciclos: S0 busqueda · S1 decodificacion · S2–S10 ejecucion',
         fontsize=10, color=MUTED, ha='left')
fig.tight_layout(rect=[0, 0, 1, .92])
fig.savefig('../../sim_fig1.png', dpi=130, facecolor='white')
plt.close(fig)

# ============================================================ FIGURA 2
T0, T1 = 0, 4200
fig, axs = plt.subplots(5, 1, figsize=(15, 7.6), sharex=True,
                        gridspec_kw={'height_ratios': [1, 1, 1, .7, .7], 'hspace': .32})
fig.patch.set_facecolor('white')

step(axs[0], r1, DATA, 2.2); frame(axs[0], T0, T1, 'R1\ndividendo')
step(axs[1], r3, CTRL, 2.2); frame(axs[1], T0, T1, 'R3\ncociente')
step(axs[2], acc, STAT, 1.6); frame(axs[2], T0, T1, 'Acc')
step(axs[3], zero, MUTED, 1.8); frame(axs[3], T0, T1, 'Zero_dp'); axs[3].set_yticks([0, 1])
step(axs[4], posf, MUTED, 1.8); frame(axs[4], T0, T1, 'Positive_dp'); axs[4].set_yticks([0, 1])
axs[4].set_xlabel('tiempo [ns]', fontsize=10, color=MUTED)

def anotar_cambios(ax, data, color):
    prev = None
    for tt, v in data:
        if v != prev:
            ax.annotate(str(v), (tt, v), textcoords='offset points', xytext=(5, 5),
                        fontsize=9, color=color, fontweight='bold')
            prev = v

anotar_cambios(axs[0], r1, DATA)
anotar_cambios(axs[1], r3, CTRL)
t_neg = next((tt for tt, v in acc if v == 253), None)
if t_neg:
    axs[2].annotate('0 - 3 = -3\n0xFD en complemento a dos', (t_neg, 253),
                    textcoords='offset points', xytext=(-210, -14), fontsize=9.5,
                    color=STAT, fontweight='bold',
                    arrowprops=dict(arrowstyle='->', color=STAT, lw=1.4))
    for a in axs[3:]:
        a.axvline(t_neg, color=STAT, lw=1.1, ls='--', alpha=.65)
    axs[4].annotate('cae la bandera\ny termina el bucle', (t_neg, 0),
                    textcoords='offset points', xytext=(-180, 16), fontsize=9.5,
                    color=STAT, fontweight='bold')
for a in axs[:3]:
    a.margins(y=.3)

fig.suptitle('Figura 2 · Division por restas sucesivas — 15 / 3',
             fontsize=14, fontweight='bold', color=INK, x=.09, ha='left', y=.975)
fig.text(.09, .935, 'El dividendo R1 baja de 3 en 3 mientras el cociente R3 cuenta las restas; '
                    'Positive_dp cae cuando la resta se vuelve negativa y termina el bucle',
         fontsize=10, color=MUTED, ha='left')
fig.tight_layout(rect=[0, 0, 1, .92])
fig.savefig('../../sim_fig2.png', dpi=130, facecolor='white')
plt.close(fig)

# ============================================================ FIGURA 3
tout = next((t for t, v in outen if v == 1), 3800)
T0, T1 = tout - 220, tout + 260
fig, axs = plt.subplots(5, 1, figsize=(15, 6.6), sharex=True,
                        gridspec_kw={'height_ratios': [.7, 1.1, 1, .7, 1], 'hspace': .34})
fig.patch.set_facecolor('white')

step(axs[0], clip(clk, T0, T1), INK, 1.4); frame(axs[0], T0, T1, 'clk'); axs[0].set_yticks([0, 1])
step(axs[1], clip(st, T0, T1), CTRL, 2.0); frame(axs[1], T0, T1, 'estado')
axs[1].set_yticks(range(11)); axs[1].set_yticklabels(ESTADOS, fontsize=7.5)
step(axs[2], clip(busy, T0, T1), DATA, 2.2); frame(axs[2], T0, T1, 'BUS Y'); axs[2].margins(y=.4)
axs[2].annotate('BUS Y = 5  (la ALU deja pasar el acumulador)', (tout, 5),
                textcoords='offset points', xytext=(16, 2), fontsize=9.5,
                color=DATA, fontweight='bold')
step(axs[3], clip(outen, T0, T1), CTRL, 2.2); frame(axs[3], T0, T1, 'OUT_En'); axs[3].set_yticks([0, 1])

xs, ys, lab = [], [], []
for tt, v in clip(outdp, T0, T1):
    n = num(v)
    xs.append(tt); ys.append(n if n is not None else -1); lab.append(v)
xs.append(T1 + 50); ys.append(ys[-1] if ys else 0)
axs[4].step(xs, ys, where='post', color=STAT, lw=2.4)
frame(axs[4], T0, T1, 'OUT_dp')
axs[4].set_xlabel('tiempo [ns]', fontsize=10, color=MUTED)
axs[4].set_ylim(-2.5, 7)
axs[4].set_yticks([-1, 0, 5]); axs[4].set_yticklabels(['Z', '0', '5'])
axs[4].axhline(5, color=STAT, lw=.8, ls='--', alpha=.5)
axs[4].annotate('resultado = 5', (tout, 5), textcoords='offset points', xytext=(14, 6),
                fontsize=11, color=STAT, fontweight='bold')
for a in axs:
    a.axvspan(tout, tout + 20, color='#FDF2DC', zorder=0)

fig.suptitle('Figura 3 · Entrega del resultado por OUT_dp',
             fontsize=14, fontweight='bold', color=INK, x=.09, ha='left', y=.975)
fig.text(.09, .93, 'En el estado S4 la ALU deja pasar el acumulador al BUS Y y OUT_En habilita el buffer '
                   'triestado; fuera de ese ciclo la salida queda en alta impedancia',
         fontsize=10, color=MUTED, ha='left')
fig.tight_layout(rect=[0, 0, 1, .91])
fig.savefig('../../sim_fig3.png', dpi=130, facecolor='white')
plt.close(fig)

# ------------------------------------------------------------------ resumen
res = {'t_out_ns': tout,
       'resultado': num(value_at(f'{TB}.capturado', 6000)),
       'iteraciones': [(t, r[1], r[3]) for t, r in hist if r[1] != 15 or r[3] != 0],
       'R1_final': r1[-1][1], 'R3_final': r3[-1][1]}
print(json.dumps({'t_out_ns': res['t_out_ns'], 'resultado': res['resultado'],
                  'R1_final': res['R1_final'], 'R3_final': res['R3_final'],
                  'escrituras_banco': len(hist)}, indent=1))
print('traza (t, R1, R3):')
for t, r in hist:
    print(f'  {t:7.0f} ns   R1={r[1]:3d}   R3={r[3]:3d}')
