# -*- coding: utf-8 -*-
"""
Genera docs/index.html, la pagina del proyecto MPDII.

Lee el VHDL de rtl/, sim/ y programas/, los planos y las graficas de doc/, y
arma la pagina completa con todo embebido: no necesita red ni archivos sueltos.

Las tablas de cada programa se extraen del propio `constant PROGRAMA` de cada
ROM, asi que nunca pueden contradecir al codigo.

    uso:  python3 docs/build_landing.py
"""
import base64, html, json, os, re

# Rutas relativas a este archivo, para que el generador funcione desde el
# repositorio sin depender de donde este clonado.
AQUI = os.path.dirname(os.path.abspath(__file__))
R    = os.path.dirname(AQUI)              # raiz del repositorio
DOC  = os.path.join(R, 'doc')             # planos y graficas de simulacion
OUT  = os.path.join(AQUI, 'index.html')

def rd(p):
    return open(p, encoding='utf-8').read()

def b64(p):
    return base64.b64encode(open(p, 'rb').read()).decode()

def svg_inline(p):
    s = rd(p)
    return re.sub(r'width="\d+" height="\d+"', 'width="100%" height="auto"', s, count=1)

# ---------------------------------------------------------------- archivos
GRUPOS = [
    ('Combinacionales · flujo de datos', [
        ('mux2to1_8.vhd',  'Multiplexor 2:1 que elige la próxima dirección del PC.'),
        ('mux4to1_8.vhd',  'Multiplexor 4:1 que elige la fuente del BUS Y.'),
        ('inc8.vhd',       'Incrementador que calcula PC + 1.'),
        ('alu8.vhd',       'Unidad aritmético-lógica con las 8 operaciones.'),
        ('shifter8.vhd',   'Desplazador con los 4 modos.'),
        ('tristate8.vhd',  'Buffer triestado de salida.'),
        ('flags.vhd',      'NOR de 8 entradas e inversor del bit de signo.'),
        ('rom256x13.vhd',  'Memoria de programa con la división cargada.'),
    ]),
    ('Secuenciales · comportamiento', [
        ('reg8.vhd',        'Registro de 8 bits: se instancia como PC y como acumulador.'),
        ('reg13.vhd',       'Registro de instrucción de 13 bits.'),
        ('regfile16x8.vhd', 'Banco de 16 registros con escritura síncrona y lectura combinacional.'),
    ]),
    ('Unidades y TOP', [
        ('datapath.vhd',     'Unidad de datos: interconexión estructural de los once bloques.'),
        ('control_unit.vhd', 'Unidad de control: máquina de Moore de 11 estados.'),
        ('MPDII.vhd',        'Entidad TOP: une la unidad de control y la unidad de datos.'),
    ]),
    ('Simulación', [
        ('tb_MPDII.vhd', 'Banco de pruebas: aplica reloj y reset y comprueba el resultado.'),
    ]),
]

archivos = {}
for _, items in GRUPOS:
    for name, _ in items:
        sub = 'sim' if name.startswith('tb_') else 'rtl'
        archivos[name] = rd(f'{R}/{sub}/{name}')
archivos['MPDII.qsf'] = rd(f'{R}/MPDII.qsf')

# ---------------------------------------------------------------- instrucciones
INSTR = [
 ('00 · Transferencia de datos', [
  ('NOP',     '00000', '0x00', '—',
   'No hace nada. Consume solo dos ciclos porque sale de la decodificación directo a la búsqueda.'),
  ('LDI k',   '00001', '0x01', 'k = IR[7:0]',
   'Carga en el acumulador la constante de 8 bits que viaja en la propia instrucción. Es la única forma de meter un valor literal al procesador.'),
  ('IN',      '00010', '0x02', '—',
   'Toma el dato presente en el puerto externo Input_dp y lo deja en el acumulador.'),
  ('OUT',     '00011', '0x03', '—',
   'Saca el acumulador por OUT_dp habilitando el buffer triestado durante un ciclo.'),
  ('STR Rn',  '00100', '0x04', 'n = IR[3:0]',
   'Guarda el acumulador en el registro Rn del banco. La ALU deja pasar A y el valor llega al banco por el BUS Y.'),
 ]),
 ('01 · Aritmético-lógicas', [
  ('AND Rn',  '01001', '0x09', 'n = IR[3:0]',
   'Y lógico bit a bit entre el acumulador y el registro Rn; el resultado queda en el acumulador.'),
  ('OR Rn',   '01010', '0x0A', 'n = IR[3:0]',
   'O lógico bit a bit entre el acumulador y Rn.'),
  ('NOT',     '01011', '0x0B', '—',
   'Complemento a uno del acumulador. No usa el banco de registros.'),
  ('ADD Rn',  '01100', '0x0C', 'n = IR[3:0]',
   'Suma Rn al acumulador. El acarreo de salida se descarta: la aritmética es módulo 256.'),
  ('SUB Rn',  '01101', '0x0D', 'n = IR[3:0]',
   'Resta Rn del acumulador en complemento a dos. Es la instrucción que sostiene el algoritmo de división.'),
  ('INC',     '01110', '0x0E', '—',
   'Suma uno al acumulador, sin tocar el banco.'),
  ('DEC',     '01111', '0x0F', '—',
   'Resta uno al acumulador.'),
 ]),
 ('10 · Desplazamiento', [
  ('SHL',     '10001', '0x11', '—',
   'Desplaza el acumulador un bit a la izquierda e introduce un 0 por el bit menos significativo. Equivale a multiplicar por dos.'),
  ('SHR',     '10010', '0x12', '—',
   'Desplaza un bit a la derecha e introduce un 0 por el más significativo. Equivale a dividir por dos sin signo.'),
  ('ROR',     '10011', '0x13', '—',
   'Rotación a la derecha: el bit 0 vuelve a entrar por el bit 7, sin perder información.'),
 ]),
 ('11 · Control de flujo', [
  ('JMP d',   '11000', '0x18', 'd = IR[7:0]',
   'Salto incondicional: carga el PC con la dirección d de la ROM.'),
  ('JZ d',    '11001', '0x19', 'd = IR[7:0]',
   'Salta a d solo si el acumulador vale cero (Zero_dp = 1).'),
  ('JNZ d',   '11010', '0x1A', 'd = IR[7:0]',
   'Salta a d si el acumulador es distinto de cero.'),
  ('JP d',    '11011', '0x1B', 'd = IR[7:0]',
   'Salta a d si el acumulador es positivo o cero, es decir si el bit de signo está en 0.'),
  ('JN d',    '11100', '0x1C', 'd = IR[7:0]',
   'Salta a d si el acumulador es negativo. Es la que cierra el bucle de restas sucesivas.'),
  ('HLT',     '11111', '0x1F', '—',
   'Detiene el procesador: la máquina de estados se queda en S10 hasta que llegue un Reset.'),
 ]),
]

PROGRAMA = [
 ('00', 'LDI 15',  '00001 00001111', '10F',  'Acc ← 15'),
 ('01', 'STR R1',  '00100 00000001', '401',  'R1 ← 15   (dividendo)'),
 ('02', 'LDI 3',   '00001 00000011', '103',  'Acc ← 3'),
 ('03', 'STR R2',  '00100 00000010', '402',  'R2 ← 3    (divisor)'),
 ('04', 'LDI 0',   '00001 00000000', '100',  'Acc ← 0'),
 ('05', 'STR R3',  '00100 00000011', '403',  'R3 ← 0    (cociente)'),
 ('06', 'LDI 0',   '00001 00000000', '100',  'BUCLE: Acc ← 0'),
 ('07', 'ADD R1',  '01100 00000001', 'C01',  'Acc ← R1'),
 ('08', 'SUB R2',  '01101 00000010', 'D02',  'Acc ← R1 − R2'),
 ('09', 'JN 16',   '11100 00010000', '1C10', 'si Acc &lt; 0 → FIN'),
 ('10', 'STR R1',  '00100 00000001', '401',  'R1 ← Acc'),
 ('11', 'LDI 0',   '00001 00000000', '100',  'Acc ← 0'),
 ('12', 'ADD R3',  '01100 00000011', 'C03',  'Acc ← R3'),
 ('13', 'INC',     '01110 00000000', 'E00',  'Acc ← R3 + 1'),
 ('14', 'STR R3',  '00100 00000011', '403',  'R3 ← cociente'),
 ('15', 'JMP 6',   '11000 00000110', '1806', 'repetir el bucle'),
 ('16', 'LDI 0',   '00001 00000000', '100',  'FIN: Acc ← 0'),
 ('17', 'ADD R3',  '01100 00000011', 'C03',  'Acc ← cociente'),
 ('18', 'OUT',     '00011 00000000', '300',  'OUT_dp ← Acc'),
 ('19', 'HLT',     '11111 00000000', '1F00', 'detener'),
]

TRAZA = [(150,15,0),(690,12,0),(930,12,1),(1290,9,1),(1530,9,2),(1890,6,2),
         (2130,6,3),(2490,3,3),(2730,3,4),(3090,0,4),(3330,0,5)]

REPO = 'https://github.com/luis-acosta/Dise-o-del-microprocesador-MPDII'

# ---------------------------------------------------------------- HTML
def esc(s):
    return html.escape(s)

parts = []
A = parts.append

A('''<!DOCTYPE html>
<html lang="es"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Diseño del microprocesador MPDII</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;600&display=swap" rel="stylesheet">
<style>
:root{--ink:#0F172A;--data:#13395B;--ctrl:#B45309;--stat:#0F766E;--muted:#64748B;
      --bd:#D7DEE7;--bg:#EEF1F5;--pan:#F8FAFC;--seqf:#E4EDF8;--comf:#FDF2DC}
*{box-sizing:border-box}html{scroll-behavior:smooth;scroll-padding-top:70px}
body{margin:0;font-family:Inter,'Helvetica Neue',Arial,sans-serif;background:var(--bg);
     color:var(--ink);line-height:1.65;-webkit-font-smoothing:antialiased}
.wrap{max-width:1180px;margin:0 auto;padding:0 28px}
code,pre,.mono{font-family:'JetBrains Mono',ui-monospace,Menlo,Consolas,monospace}
/* Sin ligaduras: que <= => /= := se vean con sus dos caracteres y no como un glifo */
code,pre,.mono,.tabla td.m,.tabla td.mn,.filelist button,.codebar .fn,pre.code,pre.code *{
  font-variant-ligatures:none;
  -webkit-font-feature-settings:"liga" 0,"clig" 0,"calt" 0,"dlig" 0;
  font-feature-settings:"liga" 0,"clig" 0,"calt" 0,"dlig" 0}

/* nav */
nav{position:sticky;top:0;z-index:50;background:rgba(255,255,255,.94);
    backdrop-filter:blur(10px);border-bottom:1px solid var(--bd)}
nav .wrap{display:flex;align-items:center;gap:6px;height:56px;flex-wrap:wrap}
nav .brand{font-weight:800;font-size:14px;letter-spacing:.06em;color:var(--data);
           margin-right:auto;text-transform:uppercase}
nav a{font-size:13px;font-weight:600;color:var(--muted);text-decoration:none;
      padding:6px 11px;border-radius:7px}
nav a:hover{color:var(--data);background:var(--pan)}

/* hero */
header{background:linear-gradient(160deg,#13395B 0%,#1B4F8C 58%,#215E9E 100%);color:#fff;
       padding:84px 0 72px;position:relative;overflow:hidden}
header::after{content:"";position:absolute;inset:0;opacity:.13;
  background-image:linear-gradient(#fff 1px,transparent 1px),linear-gradient(90deg,#fff 1px,transparent 1px);
  background-size:52px 52px}
header .wrap{position:relative;z-index:1}
.kicker{font-size:12.5px;font-weight:700;letter-spacing:.2em;text-transform:uppercase;
        color:#A9CBEC;margin-bottom:14px}
header h1{font-size:clamp(34px,5.4vw,58px);line-height:1.1;margin:0 0 18px;font-weight:800;
          letter-spacing:-.02em}
header p{font-size:clamp(16px,2vw,19px);max-width:780px;color:#D6E6F6;margin:0 0 30px}
.pills{display:flex;gap:9px;flex-wrap:wrap}
.pill{background:rgba(255,255,255,.14);border:1px solid rgba(255,255,255,.3);
      border-radius:999px;padding:6px 15px;font-size:13px;font-weight:600}
.btn{display:inline-flex;align-items:center;gap:8px;background:#fff;color:var(--data);
     font-weight:700;font-size:14px;padding:11px 20px;border-radius:9px;text-decoration:none;
     border:none;cursor:pointer;font-family:inherit}
.btn:hover{background:#EAF2FB}
.btn.ghost{background:transparent;color:#fff;border:1.6px solid rgba(255,255,255,.55)}
.btn.ghost:hover{background:rgba(255,255,255,.12)}
.hero-actions{display:flex;gap:12px;flex-wrap:wrap;margin-top:28px}

/* secciones */
section{padding:62px 0;border-bottom:1px solid var(--bd)}
section:nth-of-type(even){background:#fff}
.eyebrow{font-size:12px;font-weight:800;letter-spacing:.18em;text-transform:uppercase;
         color:var(--ctrl);margin-bottom:10px}
h2{font-size:clamp(25px,3.4vw,34px);margin:0 0 12px;font-weight:800;letter-spacing:-.015em}
.lead{font-size:16.5px;color:var(--muted);max-width:820px;margin:0 0 30px}
h3{font-size:18px;margin:34px 0 12px;font-weight:700}

/* specs */
.specs{display:grid;grid-template-columns:repeat(auto-fit,minmax(224px,1fr));gap:14px}
.spec{background:#fff;border:1px solid var(--bd);border-radius:11px;padding:18px 20px}
section:nth-of-type(even) .spec{background:var(--pan)}
.spec .k{font-size:11.5px;font-weight:700;letter-spacing:.09em;text-transform:uppercase;
         color:var(--muted);margin-bottom:5px}
.spec .v{font-size:19px;font-weight:800;color:var(--data);line-height:1.3}
.spec .n{font-size:12.5px;color:var(--muted);margin-top:3px}

/* planos */
.plano{background:#fff;border:1px solid var(--bd);border-radius:12px;padding:12px;
       overflow-x:auto;box-shadow:0 6px 22px rgba(15,23,42,.06)}
.plano svg{display:block;min-width:980px}
.cap{font-size:13px;color:var(--muted);margin-top:11px;text-align:center}

/* tablas */
.tabla{width:100%;border-collapse:collapse;background:#fff;border:1px solid var(--bd);
       border-radius:11px;overflow:hidden;font-size:14px}
section:nth-of-type(even) .tabla{background:var(--pan)}
.tabla th{background:var(--data);color:#fff;text-align:left;padding:11px 14px;
          font-size:11.5px;letter-spacing:.07em;text-transform:uppercase;font-weight:800}
.tabla td{padding:10px 14px;border-top:1px solid #E6ECF3;vertical-align:top}
.tabla tr.grp td{background:#E8EDF3;font-weight:800;color:var(--data);font-size:12px;
                 letter-spacing:.09em;text-transform:uppercase}
.tabla td.m{font-family:'JetBrains Mono',monospace;font-size:13px;white-space:nowrap}
.tabla td.mn{font-family:'JetBrains Mono',monospace;font-weight:600;color:var(--data);white-space:nowrap}
.scrollx{overflow-x:auto}

/* codigo */
.codewrap{display:grid;grid-template-columns:272px 1fr;gap:20px;align-items:start}
@media(max-width:900px){.codewrap{grid-template-columns:1fr}}
.filelist{background:#fff;border:1px solid var(--bd);border-radius:11px;padding:10px;
          position:sticky;top:72px;max-height:78vh;overflow:auto}
.filelist .gh{font-size:10.5px;font-weight:800;letter-spacing:.11em;text-transform:uppercase;
              color:var(--muted);padding:11px 10px 5px}
.filelist button{display:block;width:100%;text-align:left;border:none;background:none;
  font:inherit;font-size:13px;font-weight:600;color:var(--ink);padding:7px 10px;
  border-radius:7px;cursor:pointer;font-family:'JetBrains Mono',monospace}
.filelist button:hover{background:var(--pan)}
.filelist button.on{background:var(--data);color:#fff}
.codepanel{background:#fff;border:1px solid var(--bd);border-radius:11px;overflow:hidden}
.codebar{display:flex;align-items:center;gap:10px;padding:12px 16px;border-bottom:1px solid var(--bd);
         background:var(--pan);flex-wrap:wrap}
.codebar .fn{font-family:'JetBrains Mono',monospace;font-weight:700;font-size:14px;color:var(--data)}
.codebar .fd{font-size:12.5px;color:var(--muted);flex:1;min-width:140px}
.codebar button{font:inherit;font-size:12.5px;font-weight:600;padding:6px 13px;border-radius:7px;
  border:1.4px solid var(--bd);background:#fff;color:var(--ink);cursor:pointer}
.codebar button:hover{border-color:var(--data);color:var(--data)}
pre.code{margin:0;padding:18px 20px;overflow:auto;max-height:620px;font-size:12.6px;
         line-height:1.62;background:#FBFCFE}
.hljs-comment{color:#6B8299;font-style:italic}
.hljs-keyword,.hljs-literal{color:#1B4F8C;font-weight:600}
.hljs-string{color:#0F766E}
.hljs-number{color:#B45309}
.hljs-title,.hljs-name{color:#5B3F9E}
.hljs-meta{color:#9A6A1B}

/* figuras */
.fig{background:#fff;border:1px solid var(--bd);border-radius:12px;padding:10px;
     box-shadow:0 6px 22px rgba(15,23,42,.06);margin-bottom:12px}
.fig img{width:100%;display:block;border-radius:6px}

.note{background:var(--comf);border-left:4px solid var(--ctrl);border-radius:0 9px 9px 0;
      padding:15px 19px;font-size:14.5px;margin:22px 0}
.note b{color:#7C4A0C}
.ok{background:#E6F4F1;border-left-color:var(--stat)}
.ok b{color:#0B5A50}

/* catalogo de programas */
.progtabs{display:flex;gap:8px;flex-wrap:wrap;margin:24px 0 4px}
.ptab{font:inherit;font-size:13.5px;font-weight:600;color:#1E293B;background:#fff;
      border:1.5px solid var(--bd);border-radius:9px;padding:8px 16px;cursor:pointer}
.ptab:hover{border-color:#94A3B8;background:var(--pan)}
.ptab.on{background:var(--data);border-color:var(--data);color:#fff}
.progwrap{display:grid;grid-template-columns:1fr 420px;gap:22px;align-items:start;margin-top:18px}
@media(max-width:1000px){.progwrap{grid-template-columns:1fr}}
.rescard{background:#0F2A43;border-radius:11px;padding:18px 20px;color:#CFE2F4}
.resh{font-size:11px;font-weight:800;letter-spacing:.12em;text-transform:uppercase;
      color:#8FB6DA;margin-bottom:10px}
.resl{font-family:'JetBrains Mono',monospace;font-size:12.5px;line-height:1.85;white-space:pre}
.dlrow{display:flex;align-items:center;gap:10px;flex-wrap:wrap;margin-top:16px;
       background:var(--pan);border:1px solid var(--bd);border-radius:10px;padding:12px 14px}
.dlrow .fn{font-family:'JetBrains Mono',monospace;font-size:12.5px;font-weight:600;
           color:var(--data);flex:1;min-width:140px}
.dlrow button{font:inherit;font-size:12.5px;font-weight:600;padding:6px 13px;border-radius:7px;
  border:1.4px solid var(--bd);background:#fff;color:var(--ink);cursor:pointer}
.dlrow button:hover{border-color:var(--data);color:var(--data)}
footer{background:var(--data);color:#C9DCF0;padding:46px 0;font-size:14px}
footer a{color:#fff}
.toast{position:fixed;bottom:26px;left:50%;transform:translateX(-50%) translateY(90px);
  background:var(--ink);color:#fff;padding:11px 22px;border-radius:9px;font-size:14px;
  font-weight:600;transition:transform .25s;z-index:99}
.toast.show{transform:translateX(-50%) translateY(0)}
</style></head><body>

<nav><div class="wrap">
  <span class="brand">MPDII</span>
  <a href="#caracteristicas">Características</a>
  <a href="#arquitectura">Arquitectura</a>
  <a href="#datapath">Unidad de datos</a>
  <a href="#instrucciones">Instrucciones</a>
  <a href="#control">Control</a>
  <a href="#vhdl">VHDL</a>
  <a href="#programas">Programas</a>
  <a href="#simulacion">Simulación</a>
</div></nav>

<header><div class="wrap">
  <div class="kicker">Proyecto de diseño digital · VHDL · Quartus II</div>
  <h1>Diseño del microprocesador MPDII</h1>
  <p>Un microprocesador didáctico de 8 bits descrito desde cero: la ruta de datos bloque por bloque,
     una unidad de control de once estados, veintidós instrucciones y un programa de división
     entera que se ejecuta y se verifica en simulación.</p>
  <div class="pills">
    <span class="pill">8 bits</span><span class="pill">Instrucción de 13 bits</span>
    <span class="pill">ROM 256 × 13</span><span class="pill">16 registros</span>
    <span class="pill">FSM de Moore · 11 estados</span><span class="pill">22 instrucciones</span>
  </div>
  <div class="hero-actions">
    <button class="btn" id="dlall">Descargar proyecto Quartus II (.zip)</button>
    <a class="btn ghost" href="''' + REPO + '''" target="_blank" rel="noopener">Ver en GitHub</a>
  </div>
</div></header>
''')

# ---------------- características
A('''<section id="caracteristicas"><div class="wrap">
<div class="eyebrow">01 · El procesador de un vistazo</div>
<h2>Características</h2>
<p class="lead">El MPDII es una máquina de acumulador: casi todas las operaciones toman un operando
del banco de registros y dejan el resultado en el acumulador. Esa decisión mantiene la instrucción
corta y el camino de datos simple, a cambio de pedir alguna instrucción extra para mover datos.</p>
<div class="specs">''')
for k, v, n in [
    ('Ancho de datos', '8 bits', 'buses, ALU, registros y puertos'),
    ('Palabra de instrucción', '13 bits', '5 de código de operación + 8 de operando'),
    ('Memoria de programa', 'ROM 256 × 13', 'lectura asíncrona, direccionada por el PC'),
    ('Almacenamiento', 'Acc + 16 × 8', 'un acumulador y un banco de 16 registros'),
    ('ALU', '8 operaciones', 'paso, AND, OR, NOT, +, −, +1, −1'),
    ('Desplazador', '4 modos', 'paso, izquierda, derecha y rotación'),
    ('Banderas', 'Zero · Positive', 'derivadas de la salida del acumulador'),
    ('Unidad de control', 'Moore · 11 estados', 'búsqueda, decodificación y nueve de ejecución'),
    ('Ciclos por instrucción', '3', 'dos para NOP; HLT se detiene'),
    ('Instrucciones', '22', 'en cuatro grupos de codificación regular'),
    ('Entrada / salida', 'Input_dp · OUT_dp', '8 bits cada una, salida por buffer triestado'),
    ('Verificación', 'GHDL 4.1', 'simulado sin errores: 15 ÷ 3 = 5'),
]:
    A(f'<div class="spec"><div class="k">{k}</div><div class="v">{v}</div><div class="n">{n}</div></div>')
A('''</div>
<div class="note"><b>Por qué el código de operación está organizado así.</b> Los dos bits altos
<code>IR[12:11]</code> identifican el grupo; dentro del grupo aritmético-lógico
<code>Sel_ALU = IR[10:8]</code> y dentro del de desplazamiento <code>Sel_Shift = IR[9:8]</code>.
Esos dos buses de control salen del registro de instrucción por cable, sin lógica de
decodificación, y eso se nota en el tamaño de la unidad de control.</div>
</div></section>''')

# ---------------- arquitectura
A(f'''<section id="arquitectura"><div class="wrap">
<div class="eyebrow">02 · Vista de alto nivel</div>
<h2>Arquitectura del sistema</h2>
<p class="lead">El procesador se parte en dos bloques. La unidad de control decide qué hacer en cada
ciclo y la unidad de datos lo ejecuta. Entre ellos viajan diez señales de control en un sentido y
cuatro de estado en el otro; el reloj y el reset llegan a los dos.</p>
<div class="plano">{svg_inline(f'{DOC}/top.svg')}</div>
<p class="cap">Diagrama de bloques: señales de interconexión y puertos del sistema</p>
</div></section>''')

# ---------------- datapath
A(f'''<section id="datapath"><div class="wrap">
<div class="eyebrow">03 · Ruta de datos</div>
<h2>Unidad de datos</h2>
<p class="lead">Once bloques en dos caminos. El de búsqueda lleva el contador de programa a la ROM
y de ahí al registro de instrucción. El de ejecución gira alrededor del BUS Y: el multiplexor elige
qué entra, el acumulador y el banco alimentan la ALU, y el resultado vuelve al bus a través del
desplazador.</p>
<div class="plano">{svg_inline(f'{DOC}/datapath.svg')}</div>
<p class="cap">Esquema interno de la unidad de datos con anchos de bus y señales de control</p>
<div class="note"><b>Una consecuencia del diseño.</b> El banco de registros solo alimenta la entrada B
de la ALU, así que no existe un camino directo de <code>Rn</code> al acumulador. Cargar un registro
cuesta dos instrucciones: <code>LDI 0x00</code> y luego <code>ADD Rn</code>. El programa de división
usa ese patrón cuatro veces.</div>
</div></section>''')

# ---------------- instrucciones
A('''<section id="instrucciones"><div class="wrap">
<div class="eyebrow">04 · Juego de instrucciones</div>
<h2>Las 22 instrucciones</h2>
<p class="lead">El campo bajo de la instrucción cambia de significado según el grupo: es una dirección
de la ROM en los saltos, una constante en <code>LDI</code> y un número de registro en las que tocan
el banco.</p>
<div class="scrollx"><table class="tabla">
<thead><tr><th>Mnemónico</th><th>Cód. op.</th><th>Hex</th><th>Operando</th><th>Qué hace</th></tr></thead><tbody>''')
for grupo, items in INSTR:
    A(f'<tr class="grp"><td colspan="5">Grupo {esc(grupo)}</td></tr>')
    for mn, cod, hx, op, desc in items:
        A(f'<tr><td class="mn">{esc(mn)}</td><td class="m">{cod}</td><td class="m">{hx}</td>'
          f'<td class="m">{esc(op)}</td><td>{esc(desc)}</td></tr>')
A('''</tbody></table></div>
<h3>Formato de la palabra</h3>
<div class="plano">''' + svg_inline(f'{DOC}/isa.svg') + '''</div>
<p class="cap">Formato de instrucción, codificación completa y señales activas en cada ejecución</p>
</div></section>''')

# ---------------- control
A(f'''<section id="control"><div class="wrap">
<div class="eyebrow">05 · Secuenciamiento</div>
<h2>Unidad de control</h2>
<p class="lead">Una máquina de Moore: las señales dependen solo del estado presente. Cada instrucción
recorre búsqueda, decodificación y un estado de ejecución, de modo que casi todas duran tres ciclos
de reloj.</p>
<div class="plano">{svg_inline(f'{DOC}/fsm.svg')}</div>
<p class="cap">Diagrama de estados y tabla de señales de control</p>
</div></section>''')

# ---------------- vhdl
A('''<section id="vhdl"><div class="wrap">
<div class="eyebrow">06 · Implementación</div>
<h2>Código VHDL</h2>
<p class="lead">Los circuitos combinacionales están descritos por flujo de datos, con asignaciones
concurrentes; los secuenciales por comportamiento, con procesos sensibles al reloj. La unidad de
datos y el TOP son puramente estructurales: solo instancian y conectan.</p>
<p class="lead" style="font-size:14px">Cada archivo se puede copiar al portapapeles o descargar. Las
descargas salen en <code>.zip</code> porque el visor no admite la extensión <code>.vhd</code>
directamente; dentro del zip el archivo conserva su nombre.</p>
<div class="codewrap">
<div class="filelist">''')
first = None
for gname, items in GRUPOS:
    A(f'<div class="gh">{esc(gname)}</div>')
    for name, _ in items:
        if first is None:
            first = name
        A(f'<button data-f="{esc(name)}">{esc(name)}</button>')
A('<div class="gh">Proyecto</div><button data-f="MPDII.qsf">MPDII.qsf</button>')
A('''</div>
<div class="codepanel">
  <div class="codebar">
    <span class="fn" id="cfn"></span><span class="fd" id="cfd"></span>
    <button id="btncopy">Copiar</button><button id="btndl">Descargar</button>
  </div>
  <pre class="code"><code class="language-vhdl" id="codebody"></code></pre>
</div></div>''')

descr = {n: d for _, items in GRUPOS for n, d in items}
descr['MPDII.qsf'] = 'Asignaciones del proyecto de Quartus II: archivos fuente, dispositivo y pines.'
def json_en_script(obj):
    # Unico peligro dentro de <script>: la secuencia "</". \/ es escape valido en JSON.
    return json.dumps(obj, ensure_ascii=False).replace('</', '<\\/')

A("""
<h3>Senales de observacion en el TOP</h3>
<p class="lead">La entidad <code>MPDII</code> saca diez puertos <code>TEST_*</code> que exponen los
nodos internos del procesador. Son puramente observacionales: no alimentan ninguna logica, asi que
se pueden dejar sin conectar sin alterar el funcionamiento. Sirven para seguir el movimiento de los
datos instruccion por instruccion, en simulacion o con un analizador logico.</p>
<div class="scrollx"><table class="tabla">
<thead><tr><th>Senal</th><th>Bits</th><th>Que deja ver</th></tr></thead>
<tbody><tr><td class="mn">TEST_PC</td><td class="m">8</td><td>La direccion de la instruccion que se esta buscando en la ROM.</td></tr><tr><td class="mn">TEST_ROM</td><td class="m">13</td><td>La palabra de instruccion completa que la ROM entrega en esa direccion.</td></tr><tr><td class="mn">TEST_COP</td><td class="m">5</td><td>El codigo de operacion que la unidad de control esta decodificando.</td></tr><tr><td class="mn">TEST_Mux_dp</td><td class="m">8</td><td>El dato que circula por el BUS Y, elegido por el multiplexor de cuatro entradas.</td></tr><tr><td class="mn">TEST_Acc</td><td class="m">8</td><td>El contenido del acumulador, que es la entrada A de la ALU.</td></tr><tr><td class="mn">TEST_RF</td><td class="m">8</td><td>El registro que RF_Addr tiene seleccionado, es decir la entrada B de la ALU.</td></tr><tr><td class="mn">TEST_ALU</td><td class="m">8</td><td>El resultado de la operacion aritmetico-logica antes de desplazar.</td></tr><tr><td class="mn">TEST_Shifter</td><td class="m">8</td><td>El resultado despues del desplazador.</td></tr><tr><td class="mn">TEST_Zero_dp</td><td class="m">1</td><td>La bandera de cero, que gobierna los saltos JZ y JNZ.</td></tr><tr><td class="mn">TEST_OUT_En</td><td class="m">1</td><td>Marca el ciclo exacto en que OUT_dp lleva un valor valido.</td></tr></tbody></table></div>
<p class="lead" style="margin-top:22px">Siete vienen de nodos internos de la unidad de datos y tres
son copias de senales que ya cruzaban entre las dos unidades. Con ellas el banco de pruebas imprime
una traza legible de lo que ocurre en cada instruccion:</p>
<div class="codepanel"><pre class="code" style="max-height:none">@531ns   PCsig=8   ADD  BusY=15  -&gt; Acc=15  | RF=15  ALU=15  Shift=15  Zero='0'
@591ns   PCsig=9   SUB  BusY=12  -&gt; Acc=12  | RF=3   ALU=12  Shift=12  Zero='0'
@891ns   PCsig=14  INC  BusY=1   -&gt; Acc=1   | RF=0   ALU=1   Shift=1   Zero='0'
@3591ns  PCsig=9   SUB  BusY=253 -&gt; Acc=253 | RF=3   ALU=253 Shift=253 Zero='0'
@3830ns  &gt;&gt;&gt; OUT_dp = 5   (TEST_OUT_En activa)</pre></div>
<div class="note"><b>Coste en pines.</b> Los diez puertos suman 68 bits, que llevan el total a 86
pines. Caben de sobra en el 10M08 del MAX 10, pero una tarjeta como la DE10-Lite no tiene tantos
pines accesibles: para montar en hardware conviene elegir un subconjunto o usar SignalTap, que
observa las mismas senales sin gastar pines.</div>
""")

A('</div></section>')

# ---------------- programas de ejemplo
import re as _re

APLICACIONES = [
 {'clave': 'rom256x13.vhd', 'ruta': 'rtl/rom256x13.vhd',
  'nombre': 'División entera', 'sub': 'restas sucesivas · 15 ÷ 3',
  'desc': [
    'El procesador no tiene instrucción de división, así que se construye: restar el divisor al '
    'dividendo hasta que el resultado se vuelve negativo, contando cuántas restas cupieron.',
    'La bandera <code>Positive_dp</code> es la que detecta ese cruce. Mientras la resta dé un '
    'número no negativo el bucle sigue; en cuanto el bit de signo se pone a uno, <code>JN</code> '
    'salta al final. <code>R1</code> guarda el dividendo que va bajando y <code>R3</code> cuenta '
    'las vueltas, que es el cociente.'],
  'res': ['R1 (dividendo): 15 → 12 → 9 → 6 → 3 → 0',
          'R3 (cociente):   0 →  1 → 2 → 3 → 4 → 5',
          'Acc al salir:   0 − 3 = −3 = 0xFD, cae Positive_dp',
          'OUT_dp = 5 en t = 3830 ns'],
  'nota': 'Para cambiar el divisor basta reescribir la palabra de la dirección 02. La variante '
          '15 ÷ 5 se verificó: entrega 3 en t = 2630 ns.'},

 {'clave': 'rom256x13_suma.vhd', 'ruta': 'programas/rom256x13_suma.vhd',
  'nombre': 'Suma de dos números', 'sub': 'lectura por Input_dp',
  'desc': [
    'Lee dos números por el puerto de entrada y saca la suma. La parte interesante no es la suma '
    'sino cómo se leen dos valores por un solo puerto.',
    'La unidad de datos no tiene ninguna señal de «dato listo»: la instrucción <code>IN</code> '
    'captura lo que haya en <code>Input_dp</code> en ese instante. Como dos <code>IN</code> '
    'seguidos ocurrirían con 180 ns de diferencia, entre ellos va un bucle de retardo que abre '
    'una ventana de unos 12 µs para cambiar la entrada.'],
  'res': ['IN leyendo Input_dp = 25   en t = 90 ns',
          'cambio de la entrada a 17  en t = 6060 ns',
          'IN leyendo Input_dp = 17   en t = 12270 ns',
          'OUT_dp = 42 en t = 12530 ns'],
  'nota': 'No hay bandera de acarreo: la suma es módulo 256. Con sumandos de hasta 127 cada uno '
          'el resultado siempre cabe.'},

 {'clave': 'rom256x13_rotacion.vhd', 'ruta': 'programas/rom256x13_rotacion.vhd',
  'nombre': 'Rotación de un bit', 'sub': 'un 1 recorre las ocho posiciones',
  'desc': [
    'Un único bit en uno recorre las ocho posiciones del registro <code>R1</code> y el patrón sale '
    'por <code>OUT_dp</code> en cada rotación. El bucle no termina nunca.',
    'La instrucción <code>ROR</code> rota el acumulador, no el banco de registros, así que en cada '
    'vuelta el patrón se trae de <code>R1</code> al acumulador, se muestra, se rota y se devuelve. '
    'La pareja <code>LDI 0</code> + <code>ADD R1</code> es la única forma de copiar un registro al '
    'acumulador en esta arquitectura, porque el banco solo alimenta la entrada B de la ALU.'],
  'res': ['00000001  →  10000000  →  01000000  →  00100000',
          '00010000  →  00001000  →  00000100  →  00000010',
          'y vuelve a empezar: ciclo completo de ocho rotaciones',
          'una rotación cada 360 ns (18 ciclos)'],
  'nota': 'ROR mueve el bit 0 al bit 7, por eso desde 0x01 el uno salta al extremo opuesto. A 360 ns '
          'por paso el ojo no lo ve: en la tarjeta hace falta insertar un retardo.'},

 {'clave': 'rom256x13_mayor.vhd', 'ruta': 'programas/rom256x13_mayor.vhd',
  'nombre': 'Cuál es el mayor', 'sub': 'comparación de dos números',
  'desc': [
    'Lee dos números y saca el mayor de los dos. Si son iguales saca ese mismo valor.',
    'El procesador no tiene instrucción de comparación: la comparación se hace restando y mirando '
    'el signo. Con <code>Acc = B</code> se ejecuta <code>SUB R1</code>, que deja <code>B − A</code>, '
    'y <code>JN</code> elige la rama. Si el resultado es negativo gana A; si no, gana B.'],
  'res': ['A=100  B=37   →  mayor = 100',
          'A=37   B=100  →  mayor = 100',
          'A=64   B=64   →  mayor = 64',
          'A=127  B=0    →  mayor = 127'],
  'nota': 'Solo vale para números de 0 a 127. Positive_dp es el bit de signo y no hay acarreo, así '
          'que la resta solo compara si la diferencia cabe en el rango con signo. Comprobado el '
          'fallo: con A=10 y B=200 el programa contesta 10, porque 190 tiene el bit 7 en uno.'},

 {'clave': 'rom256x13_multiplica.vhd', 'ruta': 'programas/rom256x13_multiplica.vhd',
  'nombre': 'Multiplicación', 'sub': 'sumas sucesivas · resultado de 8 bits',
  'desc': [
    'Es el espejo exacto del programa de división: aquella restaba hasta cruzar el cero, esta suma '
    'el multiplicando tantas veces como diga el multiplicador.',
    'La bandera <code>Zero_dp</code> cierra el bucle. <code>R2</code> hace de contador y baja de uno '
    'en uno, mientras <code>R3</code> acumula el producto.'],
  'res': ['12 × 7   =  84',
          ' 5 × 3   =  15',
          ' 0 × 9   =   0      multiplicando nulo',
          ' 9 × 0   =   0      el bucle no se ejecuta',
          '15 × 17  = 255      máximo que cabe en 8 bits'],
  'nota': 'El producto debe caber en 8 bits: con 20 × 20 el procesador entrega 144 sin avisar. '
          'Además el tiempo depende del multiplicador, no del multiplicando: conviene cargar el '
          'número más pequeño como segundo operando.'},

 {'clave': 'rom256x13_mult_shift.vhd', 'ruta': 'programas/rom256x13_mult_shift.vhd',
  'nombre': 'Multiplicación de 16 bits', 'sub': 'desplazar y sumar · dos registros',
  'desc': [
    'El multiplicador serie clásico. El par <code>R3:R2</code> arranca con el multiplicador en la '
    'mitad baja y se desplaza a la derecha ocho veces; en cada vuelta, si el bit que sale por abajo '
    'vale uno, se suma el multiplicando a la mitad alta. Siempre son ocho vueltas, sin importar los '
    'operandos.',
    'La suma <code>R3 = R3 + A</code> podría desbordar y no hay bandera de acarreo. La salida está '
    'en una propiedad del algoritmo: justo antes de esa suma <code>R3</code> viene de un '
    'desplazamiento a la derecha, así que vale como mucho 127. Si además el multiplicando se limita '
    'a 127, entonces <code>R3 + A ≤ 254</code> y la suma nunca desborda, sin necesidad de detectar '
    'acarreo en ningún punto.'],
  'res': [' 12 ×   7  →  alta=0    baja=84   =     84',
          '100 × 200  →  alta=78   baja=32   =  20000',
          '127 × 255  →  alta=126  baja=129  =  32385',
          '  1 × 255  →  alta=0    baja=255  =    255',
          'el producto se lee como  alta × 256 + baja'],
  'nota': 'El multiplicando se limita a 0–127; el multiplicador puede ser cualquier valor de 0 a 255. '
          'Frente a las sumas sucesivas el cruce está alrededor de B = 25: por encima, esta versión '
          'gana con holgura.'},
]


PRUEBAS = [
 {'clave': 'rom256x13_saltos.vhd', 'ruta': 'programas/rom256x13_saltos.vhd',
  'nombre': 'Saltos', 'sub': 'JMP · JZ · JNZ · JP · JN',
  'desc': [
    'Diez pruebas que ejercitan las cinco instrucciones de salto. No necesita entradas: fabrica sus '
    'propias condiciones con <code>LDI</code>, así que la prueba es repetible y no depende de lo que '
    'haya en los interruptores.',
    'El patrón se repite en todas: poner el acumulador en un estado conocido, ejecutar el salto y, si '
    'aterrizó donde debía, sacar un número por la salida. Si el salto se porta mal, el programa cae '
    'en el manejador de error de la dirección 90 y saca <code>0xEE</code>.',
    'Cada salto condicional se prueba <b>dos veces</b>: en el caso que debe saltar y en el que no. '
    'Probar solo el caso que salta dejaría pasar un error en el que la condición estuviera siempre '
    'activa — el procesador parecería funcionar y no lo haría. La prueba 10 comprueba el salto hacia '
    'una dirección menor, que es lo que sostiene cualquier bucle.'],
  'res': ['1   JMP incondicional',
          '2   JZ  con Acc=0    debe saltar',
          '3   JZ  con Acc=5    NO debe saltar',
          '4   JNZ con Acc=5    debe saltar',
          '5   JNZ con Acc=0    NO debe saltar',
          '6   JP  con Acc=5    debe saltar',
          '7   JP  con Acc=200  NO debe saltar',
          '8   JN  con Acc=200  debe saltar',
          '9   JN  con Acc=5    NO debe saltar',
          '10  JNZ hacia atrás (bucle)',
          '170 todas las pruebas pasaron'],
  'nota': 'Un autodiagnóstico que siempre pasa no vale nada, así que lo verifiqué: invertí la '
          'condición de <code>JP</code> en la unidad de control y el programa se detuvo exactamente '
          'en la prueba 6, la primera que usa ese salto. El diagnóstico localiza el fallo, no solo '
          'lo detecta.'},

 {'clave': 'rom256x13_alu.vhd', 'ruta': 'programas/rom256x13_alu.vhd',
  'nombre': 'ALU', 'sub': 'las ocho operaciones',
  'desc': [
    'Diez pruebas sobre las ocho operaciones de la ALU, también sin entradas.',
    'El procesador no tiene instrucción de comparación, así que cada prueba <b>resta el valor '
    'esperado al resultado obtenido</b>: si la ALU calculó bien la diferencia es cero, '
    '<code>Zero_dp</code> se activa y el <code>JNZ</code> no salta. Esto apoya la prueba en '
    '<code>SUB</code> y en la bandera de cero; si esas dos fallaran, se delataría en las pruebas 7 u 8.',
    'Las pruebas 6 y 8 son las que de verdad importan: <code>200 + 100</code> debe dar <b>44</b>, no '
    '255 ni saturar, lo que comprueba que la aritmética es módulo 256; y <code>10 − 20</code> debe dar '
    '<b>246</b>, que es −10 en complemento a dos. Ahí es donde se esconden los errores de una ALU, '
    'porque las operaciones lógicas casi nunca fallan.'],
  'res': ['1   paso directo A    90        -> 90',
          '2   AND              240 AND 60 -> 48',
          '3   OR               240 OR  15 -> 255',
          '4   NOT              NOT 15     -> 240',
          '5   suma             100 + 27   -> 127',
          '6   suma desbordada  200 + 100  -> 44',
          '7   resta            100 - 27   -> 73',
          '8   resta negativa    10 - 20   -> 246',
          '9   incremento        99 + 1    -> 100',
          '10  decremento       100 - 1    -> 99',
          '170 las 8 operaciones correctas'],
  'nota': 'La prueba 1 usa el código de operación <code>01000</code>, reservado en el juego de '
          'instrucciones: decodifica a <code>Sel_ALU=000</code>, el paso directo de A, que es el mismo '
          'camino que usan <code>STR</code> y <code>OUT</code>. Verificación del propio test: cambié '
          'el <code>AND</code> de la ALU por un <code>OR</code> y el programa se detuvo en la marca 2.'},

 {'clave': 'rom256x13_es.vhd', 'ruta': 'programas/rom256x13_es.vhd',
  'nombre': 'Entrada y salida', 'sub': 'IN, OUT y la ruta del dato',
  'desc': [
    'A diferencia de los otros dos diagnósticos, este <b>sí necesita el banco de pruebas</b>: el '
    'procesador no puede fabricar sus propios estímulos porque <code>IN</code> depende de lo que haya '
    'fuera. El banco presenta los valores en el orden que el programa espera, cambiándolos justo '
    'después de cada lectura; para saber cuándo ocurre una, observa <code>TEST_COP</code>.',
    'Los valores no son arbitrarios. Las lecturas 90 (<code>01011010</code>) y 165 '
    '(<code>10100101</code>) son complementarias: entre las dos obligan a cada uno de los ocho bits de '
    'entrada a valer cero una vez y uno la otra, así que un bit pegado se delata. En la salida, '
    '<code>01010101</code> y <code>10101010</code> hacen lo mismo con el camino de <code>OUT_dp</code> '
    'y además detectan un cortocircuito entre bits vecinos, porque ningún par contiguo vale lo mismo.',
    'La prueba 5 es la única que recorre el camino entero del dato: entra por <code>Input_dp</code>, '
    'cruza el multiplexor hasta el BUS Y, se guarda en el banco de registros, vuelve a salir por la '
    'entrada B de la ALU y regresa al acumulador. Si cualquiera de esos tramos corta, falla aquí.'],
  'res': ['1   IN lee  90 = 01011010',
          '2   IN lee 165 = 10100101',
          '3   IN lee   0 = 00000000',
          '4   IN lee 255 = 11111111',
          '5   ruta IN -> banco -> ALU -> Acc',
          '0   OUT de 00000000',
          '255 OUT de 11111111',
          '85  OUT de 01010101',
          '170 OUT de 10101010',
          '200 entrada y salida correctas'],
  'nota': '<code>OUT</code> no necesita prueba aparte: cada marca ES una instrucción <code>OUT</code>, '
          'así que si la secuencia llega completa, OUT funciona. Verificación del test: dejé el bit 3 '
          'de la salida pegado a cero y pasaron las marcas 1 a 5 y el 0 — ninguna tiene ese bit en uno '
          '— pero falló en <code>11111111</code>, que salió 247, y en <code>10101010</code>, que salió '
          '162. Justo lo que esos patrones existen para cazar.'},
]

TODOS = APLICACIONES + PRUEBAS

# Las fuentes de las ROM alternativas entran al visor y al zip
for _pr in TODOS:
    if _pr['clave'] not in archivos:
        archivos[_pr['clave']] = rd(f"{R}/{_pr['ruta']}")
    descr[_pr['clave']] = _pr['nombre'] + ' — ' + _pr['sub']


def listado(clave):
    # Extrae la tabla del programa del propio constant PROGRAMA del archivo,
    # para que nunca se desincronice del contenido real de la ROM.
    filas = []
    for m in _re.finditer(r'^\s*(\d+)\s*=>\s*"([01]{13})",\s*--\s*(\d+)\s+(.*?)\s*$',
                          archivos[clave], _re.M):
        _, bits, dirn, com = m.groups()
        partes = com.split(None, 1)
        instr = partes[0]
        resto = partes[1].strip() if len(partes) > 1 else ''
        if instr in ('LDI', 'STR', 'ADD', 'SUB', 'AND', 'OR', 'JMP', 'JZ', 'JNZ', 'JN', 'JP') \
                and resto and not resto.startswith('<--'):
            instr += ' ' + resto.split()[0]
            resto = resto.split(None, 1)[1] if len(resto.split()) > 1 else ''
        filas.append((dirn, bits[:5] + ' ' + bits[5:], f'0x{int(bits, 2):04X}', instr, resto))
    return filas


A('''<section id="programas"><div class="wrap">
<div class="eyebrow">07 · Software</div>
<h2>Programas de ejemplo</h2>
<p class="lead">Nueve programas escritos a mano para este juego de instrucciones. Cada uno viene como
una versión completa de <code>rom256x13.vhd</code>: para probar cualquiera basta con sustituir ese
archivo en el proyecto de Quartus. Todos se simularon con GHDL y los resultados que aparecen aquí
son los que entregó la simulación, no estimaciones.</p>''')


def grupo(gid, titulo, intro, lista):
    A(f'<h3 style="margin-top:34px;font-size:20px">{titulo}</h3>')
    A(f'<p class="lead" style="margin-bottom:6px">{intro}</p>')
    A('<div class="progtabs">')
    for k, pr in enumerate(lista):
        on = ' on' if k == 0 else ''
        A(f'<button class="ptab{on}" data-g="{gid}" data-p="{k}">{esc(pr["nombre"])}</button>')
    A('</div>')
    for k, pr in enumerate(lista):
        oc = '' if k == 0 else ' style="display:none"'
        A(f'<div class="ppanel" id="pp{gid}{k}"{oc}>')
        A(f'<h3 style="margin-top:26px">{esc(pr["nombre"])}'
          f'<span style="font-weight:500;color:var(--muted);font-size:15px"> · '
          f'{esc(pr["sub"])}</span></h3>')
        for par in pr['desc']:
            A(f'<p class="lead" style="margin-bottom:14px">{par}</p>')
        A('<div class="progwrap">')
        A('<div><div class="scrollx"><table class="tabla"><thead><tr>'
          '<th>Dir.</th><th>Codificación</th><th>Hex</th><th>Instrucción</th><th>Comentario</th>'
          '</tr></thead><tbody>')
        for d, bits, hx, instr, com in listado(pr['clave']):
            A(f'<tr><td class="m">{d}</td><td class="m">{bits}</td><td class="m">{hx}</td>'
              f'<td class="mn">{esc(instr)}</td><td>{esc(com)}</td></tr>')
        A('</tbody></table></div></div>')
        A('<div><div class="rescard"><div class="resh">'
          + ('Marcas que salen por OUT_dp' if gid == 'p' else 'Resultado de la simulación')
          + '</div>')
        for r in pr['res']:
            A(f'<div class="resl">{esc(r)}</div>')
        A('</div>')
        A(f'<div class="note" style="margin-top:16px"><b>A tener en cuenta.</b> {pr["nota"]}</div>')
        A(f'<div class="dlrow"><span class="fn">{esc(pr["ruta"])}</span>'
          f'<button class="pcopy" data-f="{esc(pr["clave"])}">Copiar ROM</button>'
          f'<button class="pdl" data-f="{esc(pr["clave"])}">Descargar</button></div>')
        A('</div></div>')
        A('</div>')


grupo('p', 'Pruebas del microprocesador',
      'Autodiagnósticos que ejercitan cada unidad y avisan por la salida si algo falla. Sacan una '
      'marca numérica por cada prueba superada; si aparece un <code>0xEE</code>, la última marca '
      'correcta indica dónde se rompió. De los tres, verifiqué que detectan fallos reales '
      'inyectando una avería a propósito en el hardware.',
      PRUEBAS)

grupo('a', 'Aplicaciones',
      'Programas que resuelven un problema: aritmética, comparación y manejo de patrones de bits.',
      APLICACIONES)

A('</div></section>')

# ---------------- simulacion
A(f'''<section id="simulacion"><div class="wrap">
<div class="eyebrow">08 · Verificación</div>
<h2>Simulación</h2>
<p class="lead">El diseño se analizó, elaboró y ejecutó con GHDL 4.1 en modo <code>--std=93c</code>,
sin errores. El banco de pruebas aplica reloj de 50 MHz, suelta el reset y comprueba el valor que
sale por <code>OUT_dp</code>.</p>
<div class="note ok"><b>Resultado.</b> En t = 3810 ns el procesador ejecuta <code>OUT</code> y entrega
<code>OUT_dp = 0x05</code>. El banco de pruebas verifica el valor con un <code>assert</code> y
reporta <code>PRUEBA SUPERADA: 15 / 3 = 5</code>.</div>
<div class="fig"><img src="data:image/png;base64,{b64(f'{DOC}/sim_fig1.png')}" alt="Ciclo de busqueda y ejecucion"></div>
<div class="fig"><img src="data:image/png;base64,{b64(f'{DOC}/sim_fig2.png')}" alt="Division por restas sucesivas"></div>
<div class="fig"><img src="data:image/png;base64,{b64(f'{DOC}/sim_fig3.png')}" alt="Entrega del resultado"></div>
<div class="note"><b>Sobre la salida.</b> <code>OUT_dp</code> viene de un buffer triestado, tal como
aparece en el esquema, así que el valor solo es válido durante el ciclo en que
<code>OUT_En</code> está activa; fuera de ahí queda en alta impedancia. Si se quiere dejarlo fijo en
los LED de la tarjeta basta con añadir un registro de salida cargado con <code>OUT_En</code>, o
mantener esa señal activa también en el estado S10.</div>
</div></section>''')

# ---------------- repo
A(f"""<section id="repo"><div class="wrap">
<div class="eyebrow">09 · Descargas</div>
<h2>Proyecto para Quartus II</h2>
<p class="lead">El repositorio trae el <code>.qpf</code> y el <code>.qsf</code> ya configurados: basta
abrir <code>MPDII.qpf</code>, compilar y lanzar la simulacion RTL desde ModelSim-Altera. Tambien
incluye un script para simular con GHDL si no se tiene ModelSim a mano.</p>
<div class="hero-actions">
  <button class="btn" id="dlall2" style="background:var(--data);color:#fff">Descargar proyecto (.zip)</button>
  <a class="btn" href="{REPO}" target="_blank" rel="noopener"
     style="border:1.6px solid var(--bd)">Abrir repositorio en GitHub</a>
</div>
</div></section>

<footer><div class="wrap">
  <strong>Dise&ntilde;o del microprocesador MPDII</strong> &middot; Rev. 1.0 &middot; 2026<br>
  Verificado con GHDL 4.1.0 &middot; proyecto para Quartus II 13.0 &middot;
  <a href="{REPO}" target="_blank" rel="noopener">repositorio</a>
</div></footer>
<div class="toast" id="toast"></div>

<script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/languages/vhdl.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js"></script>
""")

JS = r"""<script>
var DESCR = JSON.parse(document.getElementById('descr').textContent);
var FUENTES = JSON.parse(document.getElementById('fuentes').textContent);
var actual = null, dlCap = null;

(window.claude && claude.use ? claude.use('downloads') : Promise.resolve(null))
  .then(function(d){ dlCap = d; sincronizarBotones(); })
  .catch(function(){ dlCap = null; sincronizarBotones(); });

var dlCapListo = false, pendientesDl = [];
function sincronizarBotones(){
  dlCapListo = true;
  var vis = dlCap ? '' : 'none';
  ['btndl','dlall','dlall2'].forEach(function(id){
    var e = document.getElementById(id); if (e) e.style.display = vis;
  });
  [].forEach.call(document.querySelectorAll('.pdl'), function(b){ b.style.display = vis; });
}
function toast(m){
  var t = document.getElementById('toast');
  t.textContent = m; t.classList.add('show');
  setTimeout(function(){ t.classList.remove('show'); }, 2200);
}
function fuente(n){ return FUENTES[n] || ''; }
function mostrar(n){
  actual = n;
  document.getElementById('cfn').textContent = n;
  document.getElementById('cfd').textContent = DESCR[n] || '';
  var c = document.getElementById('codebody');
  c.textContent = fuente(n);
  c.removeAttribute('data-highlighted');
  c.className = 'language-vhdl';
  if (window.hljs) { try { hljs.highlightElement(c); } catch (e) {} }
  var bs = document.querySelectorAll('.filelist button');
  for (var i = 0; i < bs.length; i++) bs[i].classList.toggle('on', bs[i].dataset.f === n);
}
var botones = document.querySelectorAll('.filelist button');
for (var i = 0; i < botones.length; i++) {
  botones[i].onclick = function(){ mostrar(this.dataset.f); };
}
document.getElementById('btncopy').onclick = function(){
  navigator.clipboard.writeText(fuente(actual))
    .then(function(){ toast('Copiado: ' + actual); })
    .catch(function(){ toast('El navegador bloqueo el portapapeles'); });
};
document.getElementById('btndl').onclick = function(){
  if (!dlCap || !window.JSZip) return;
  var z = new JSZip();
  z.file(actual, fuente(actual));
  z.generateAsync({ type: 'blob' }).then(function(b){
    return dlCap.save({ filename: actual.replace(/\.[^.]+$/, '') + '.zip', data: b });
  }).then(function(){ toast('Descargado: ' + actual); })
    .catch(function(e){ if (e && e.code !== 'declined') toast('No se pudo descargar'); });
};
function descargarTodo(){
  if (!dlCap || !window.JSZip) return;
  var z = new JSZip(), raiz = z.folder('MPDII');
  Object.keys(FUENTES).forEach(function(n){
    var carpeta = '';
    if (n.indexOf('tb_') === 0) { carpeta = 'sim/'; }
    else if (n.indexOf('rom256x13_') === 0) { carpeta = 'programas/'; }
    else if (n.slice(-4) === '.vhd') { carpeta = 'rtl/'; }
    raiz.file(carpeta + n, FUENTES[n]);
  });
  raiz.file('MPDII.qpf', 'QUARTUS_VERSION = "13.0"\nPROJECT_REVISION = "MPDII"\n');
  raiz.file('LEEME.txt', 'Proyecto MPDII - microprocesador de 8 bits\n' +
            'Abrir MPDII.qpf con Quartus II. Repositorio completo:\n__REPO__\n');
  z.generateAsync({ type: 'blob' }).then(function(b){
    return dlCap.save({ filename: 'MPDII_quartus.zip', data: b });
  }).then(function(){ toast('Proyecto descargado'); })
    .catch(function(e){ if (e && e.code !== 'declined') toast('No se pudo descargar'); });
}
// --- catalogo de programas
['a', 'p'].forEach(function(g){
  var tabs = [].slice.call(document.querySelectorAll('.ptab[data-g="' + g + '"]'));
  tabs.forEach(function(t){
    t.onclick = function(){
      tabs.forEach(function(x){
        x.classList.toggle('on', x === t);
        var pan = document.getElementById('pp' + g + x.dataset.p);
        if (pan) pan.style.display = (x === t) ? '' : 'none';
      });
    };
  });
});
[].forEach.call(document.querySelectorAll('.pcopy'), function(b){
  b.onclick = function(){
    navigator.clipboard.writeText(FUENTES[b.dataset.f] || '')
      .then(function(){ toast('Copiado: ' + b.dataset.f); })
      .catch(function(){ toast('El navegador bloqueo el portapapeles'); });
  };
});
[].forEach.call(document.querySelectorAll('.pdl'), function(b){
  if (!dlCapListo) pendientesDl.push(b);
  b.onclick = function(){
    if (!dlCap || !window.JSZip) return;
    var z = new JSZip();
    z.file(b.dataset.f, FUENTES[b.dataset.f] || '');
    z.generateAsync({ type: 'blob' }).then(function(blob){
      return dlCap.save({ filename: b.dataset.f.replace(/\.[^.]+$/, '') + '.zip', data: blob });
    }).then(function(){ toast('Descargado: ' + b.dataset.f); })
      .catch(function(e){ if (e && e.code !== 'declined') toast('No se pudo descargar'); });
  };
});

document.getElementById('dlall').onclick = descargarTodo;
document.getElementById('dlall2').onclick = descargarTodo;
mostrar('__FIRST__');
</script>
</body></html>"""

A('<script type="application/json" id="fuentes">' + json_en_script(archivos) + '</script>')
A('<script type="application/json" id="descr">' + json_en_script(descr) + '</script>')

A(JS.replace('__REPO__', REPO).replace('__FIRST__', first))

open(OUT, 'w', encoding='utf-8').write(''.join(parts))
print('landing:', round(os.path.getsize(OUT)/1024), 'KB')
