# Diseño del microprocesador MPDII

Microprocesador didáctico de 8 bits descrito en VHDL, listo para abrir como
proyecto de **Quartus II**. Incluye la unidad de datos, la unidad de control,
un programa de prueba en la ROM y un banco de pruebas verificado.

Página del proyecto (características, diagramas, código y simulación):
**https://claude.ai/artifact/GBXXqLDZXWDjVDFSLgHFuY**

---

## Características

| | |
|---|---|
| Ancho de datos | 8 bits |
| Palabra de instrucción | 13 bits (5 de código de operación + 8 de operando) |
| Memoria de programa | ROM 256 × 13, lectura asíncrona |
| Registros | Acumulador de 8 bits + banco de 16 × 8 bits |
| ALU | 8 operaciones (paso, AND, OR, NOT, +, −, +1, −1) |
| Desplazador | 4 modos (paso, izquierda, derecha, rotación derecha) |
| Banderas | `Zero_dp`, `Positive_dp` (derivadas del acumulador) |
| Unidad de control | Máquina de Moore de 11 estados |
| Ciclos por instrucción | 3 (búsqueda · decodificación · ejecución); 2 para `NOP` |
| Juego de instrucciones | 22 instrucciones en 4 grupos |

---

## Estructura del repositorio

```
MPDII/
├── MPDII.qpf                 proyecto de Quartus II
├── MPDII.qsf                 asignaciones, archivos fuente y pines
├── rtl/
│   ├── mux2to1_8.vhd         combinacional · flujo de datos
│   ├── mux4to1_8.vhd         combinacional · flujo de datos
│   ├── inc8.vhd              combinacional · flujo de datos
│   ├── alu8.vhd              combinacional · flujo de datos
│   ├── shifter8.vhd          combinacional · flujo de datos
│   ├── tristate8.vhd         combinacional · flujo de datos
│   ├── flags.vhd             combinacional · flujo de datos
│   ├── rom256x13.vhd         combinacional · flujo de datos (programa)
│   ├── reg8.vhd              secuencial   · comportamiento
│   ├── reg13.vhd             secuencial   · comportamiento
│   ├── regfile16x8.vhd       secuencial   · comportamiento
│   ├── datapath.vhd          ESTRUCTURAL
│   ├── control_unit.vhd      comportamiento (FSM)
│   └── MPDII.vhd             ESTRUCTURAL (TOP)
└── sim/
    ├── tb_MPDII.vhd          banco de pruebas
    ├── run_ghdl.sh           simulación con GHDL
    └── plot_waves.py         genera las gráficas a partir del VCD
```

---

## Formato de instrucción

```
 12 11 10  9  8 | 7  6  5  4  3  2  1  0
 C4 C3 C2 C1 C0 | D7 D6 D5 D4 D3 D2 D1 D0
 \-- COD. OP --/  \----- Dir / operando ----/
```

El campo bajo cambia de significado según el grupo:

* **Salto** (`JMP`, `JZ`, `JNZ`, `JP`, `JN`) → `IR[7:0]` es la dirección de la ROM.
* **Inmediato** (`LDI`) → `IR[7:0]` es la constante.
* **Registro** (`STR`, `AND`, `OR`, `ADD`, `SUB`) → `IR[3:0]` es el registro R0–R15.

La codificación se eligió para que el decodificador sea mínimo:
`IR[12:11]` da el grupo, **`Sel_ALU = IR[10:8]`** en el grupo aritmético-lógico y
**`Sel_Shift = IR[9:8]`** en el grupo de desplazamiento.

---

## Juego de instrucciones

### Grupo 00 — Transferencia de datos

| Mnemónico | Cód. op. | Hex | Operación |
|---|---|---|---|
| `NOP`    | 00000 | 0x00 | ninguna |
| `LDI k`  | 00001 | 0x01 | `Acc ← k` |
| `IN`     | 00010 | 0x02 | `Acc ← Input_dp` |
| `OUT`    | 00011 | 0x03 | `OUT_dp ← Acc` |
| `STR Rn` | 00100 | 0x04 | `Rn ← Acc` |

### Grupo 01 — Aritmético-lógicas · `Sel_ALU = IR[10:8]`

| Mnemónico | Cód. op. | Hex | Operación |
|---|---|---|---|
| `AND Rn` | 01001 | 0x09 | `Acc ← Acc AND Rn` |
| `OR Rn`  | 01010 | 0x0A | `Acc ← Acc OR Rn` |
| `NOT`    | 01011 | 0x0B | `Acc ← NOT Acc` |
| `ADD Rn` | 01100 | 0x0C | `Acc ← Acc + Rn` |
| `SUB Rn` | 01101 | 0x0D | `Acc ← Acc − Rn` |
| `INC`    | 01110 | 0x0E | `Acc ← Acc + 1` |
| `DEC`    | 01111 | 0x0F | `Acc ← Acc − 1` |

### Grupo 10 — Desplazamiento · `Sel_Shift = IR[9:8]`

| Mnemónico | Cód. op. | Hex | Operación |
|---|---|---|---|
| `SHL` | 10001 | 0x11 | `Acc ← Acc << 1`, entra 0 |
| `SHR` | 10010 | 0x12 | `Acc ← Acc >> 1`, entra 0 |
| `ROR` | 10011 | 0x13 | rotación de `Acc` a la derecha |

### Grupo 11 — Control de flujo

| Mnemónico | Cód. op. | Hex | Operación |
|---|---|---|---|
| `JMP d` | 11000 | 0x18 | `PC ← d` |
| `JZ d`  | 11001 | 0x19 | salta si `Zero_dp = 1` |
| `JNZ d` | 11010 | 0x1A | salta si `Zero_dp = 0` |
| `JP d`  | 11011 | 0x1B | salta si `Positive_dp = 1` |
| `JN d`  | 11100 | 0x1C | salta si `Positive_dp = 0` |
| `HLT`   | 11111 | 0x1F | detiene la ejecución |

---

## Unidad de control — estados

| Estado | PCload | INTmux | IRload | Muxsel_dp | Acc_Load | RF_load | Sel_ALU | Sel_Shift | OUT_En | Siguiente |
|---|---|---|---|---|---|---|---|---|---|---|
| S0 FETCH | 1 | 0 | 1 | — | 0 | 0 | — | — | 0 | S1 |
| S1 DECOD | 0 | 0 | 0 | — | 0 | 0 | — | — | 0 | según `IR[12:8]` |
| S2 E_LDI | 0 | 0 | 0 | 11 | 1 | 0 | — | — | 0 | S0 |
| S3 E_IN | 0 | 0 | 0 | 00 | 1 | 0 | — | — | 0 | S0 |
| S4 E_OUT | 0 | 0 | 0 | 10 | 0 | 0 | 000 | — | 1 | S0 |
| S5 E_STR | 0 | 0 | 0 | 10 | 0 | 1 | 000 | — | 0 | S0 |
| S6 E_ALU | 0 | 0 | 0 | 10 | 1 | 0 | `IR[10:8]` | — | 0 | S0 |
| S7 E_SHIFT | 0 | 0 | 0 | 01 | 1 | 0 | 000 | `IR[9:8]` | 0 | S0 |
| S8 E_JMP | 1 | 1 | 0 | — | 0 | 0 | — | — | 0 | S0 |
| S9 E_Jcc | cond | 1 | 0 | — | 0 | 0 | — | — | 0 | S0 |
| S10 E_HLT | 0 | 0 | 0 | — | 0 | 0 | — | — | 0 | S10 |

`RF_Addr = IR[3:0]` en todos los estados.

---

## Programa cargado en la ROM — división entera 15 ÷ 3

El algoritmo resta el divisor al dividendo hasta que el resultado se vuelve
negativo, contando cuántas restas cupieron.

```
 Dir  Instrucción   Código              Comentario
 ---  ------------  ------------------  ----------------------------------
 00   LDI 15        00001 00001111  10F  Acc ← 15
 01   STR R1        00100 00000001  401  R1  ← 15   (dividendo)
 02   LDI 3         00001 00000011  103  Acc ← 3
 03   STR R2        00100 00000010  402  R2  ← 3    (divisor)
 04   LDI 0         00001 00000000  100  Acc ← 0
 05   STR R3        00100 00000011  403  R3  ← 0    (cociente)
 --- BUCLE -------------------------------------------------------------
 06   LDI 0         00001 00000000  100  Acc ← 0
 07   ADD R1        01100 00000001  C01  Acc ← R1
 08   SUB R2        01101 00000010  D02  Acc ← R1 − R2
 09   JN  16        11100 00010000 1C10  si Acc < 0 → FIN
 10   STR R1        00100 00000001  401  R1  ← Acc
 11   LDI 0         00001 00000000  100  Acc ← 0
 12   ADD R3        01100 00000011  C03  Acc ← R3
 13   INC           01110 00000000  E00  Acc ← R3 + 1
 14   STR R3        00100 00000011  403  R3  ← cociente
 15   JMP 6         11000 00000110 1806  repetir
 --- FIN ---------------------------------------------------------------
 16   LDI 0         00001 00000000  100  Acc ← 0
 17   ADD R3        01100 00000011  C03  Acc ← cociente
 18   OUT           00011 00000000  300  OUT_dp ← Acc
 19   HLT           11111 00000000 1F00  detener
```

Traza obtenida en simulación:

| t (ns) | R1 (dividendo) | R3 (cociente) |
|---|---|---|
| 150  | 15 | 0 |
| 690  | 12 | 0 |
| 930  | 12 | 1 |
| 1290 |  9 | 1 |
| 1530 |  9 | 2 |
| 1890 |  6 | 2 |
| 2130 |  6 | 3 |
| 2490 |  3 | 3 |
| 2730 |  3 | 4 |
| 3090 |  0 | 4 |
| 3330 |  0 | 5 |

En t = 3810 ns el procesador ejecuta `OUT` y entrega **`OUT_dp = 0x05`**.

---

## Señales de observación (`TEST_*`)

La entidad `MPDII` expone diez puertos de solo observación para seguir el
movimiento de los datos dentro del procesador. No alimentan ninguna lógica, así
que pueden dejarse sin conectar sin alterar el funcionamiento.

| Señal | Bits | Qué deja ver |
|---|---|---|
| `TEST_PC` | 8 | dirección de la instrucción que se está buscando |
| `TEST_ROM` | 13 | palabra de instrucción que entrega la ROM |
| `TEST_COP` | 5 | código de operación que decodifica la unidad de control |
| `TEST_Mux_dp` | 8 | dato que circula por el BUS Y |
| `TEST_Acc` | 8 | contenido del acumulador (entrada A de la ALU) |
| `TEST_RF` | 8 | registro seleccionado por `RF_Addr` (entrada B de la ALU) |
| `TEST_ALU` | 8 | resultado aritmético-lógico antes de desplazar |
| `TEST_Shifter` | 8 | resultado después del desplazador |
| `TEST_Zero_dp` | 1 | bandera de cero, gobierna `JZ` y `JNZ` |
| `TEST_OUT_En` | 1 | ciclo exacto en que `OUT_dp` es válido |

Siete salen de nodos internos de la unidad de datos; tres son copias de señales
que ya cruzaban entre las dos unidades. El banco de pruebas las usa para
imprimir una traza legible:

```
@531ns   PCsig=8   ADD  BusY=15  -> Acc=15  | RF=15  ALU=15  Shift=15  Zero='0'
@591ns   PCsig=9   SUB  BusY=12  -> Acc=12  | RF=3   ALU=12  Shift=12  Zero='0'
@3591ns  PCsig=9   SUB  BusY=253 -> Acc=253 | RF=3   ALU=253 Shift=253 Zero='0'
@3830ns  >>> OUT_dp = 5   (TEST_OUT_En activa)
```

`PCsig` es la dirección **siguiente**: el PC se incrementa durante la búsqueda,
antes de ejecutar.

Los diez puertos suman 68 bits y llevan el total a 86 pines. Caben en el MAX 10
10M08, pero no en los pines accesibles de una DE10-Lite: para hardware conviene
elegir un subconjunto o usar SignalTap.

---

## Dispositivo

El `MPDII.qsf` original apunta a Cyclone II (DE2). Para MAX 10 `10M08DAF484C8G`
(DE10-Lite) usa `MPDII_max10.qsf`: renómbralo a `MPDII.qsf` reemplazando el
anterior. Trae los pines comentados para que la compilación llegue hasta el
final; descoméntalos tras verificarlos contra el manual de tu tarjeta.

**Atención al reset:** los pulsadores `KEY` de la DE10-Lite son activos en bajo
y el puerto `reset` del MPDII es activo en alto. Conectarlo directo a `KEY0`
deja el procesador permanentemente en reset.

---

## Programas

La carpeta [`programas/`](programas/) trae nueve programas, cada uno como una
versión completa de `rom256x13.vhd`. Se dividen en dos grupos:

**Pruebas del microprocesador** — autodiagnósticos que ejercitan cada unidad y
avisan por la salida si algo falla:

| Programa | Qué comprueba |
|---|---|
| `rom256x13_saltos.vhd` | `JMP`, `JZ`, `JNZ`, `JP`, `JN`, cada uno en sus dos casos |
| `rom256x13_alu.vhd` | Las ocho operaciones, con desbordamiento y complemento a dos |
| `rom256x13_es.vhd` | `IN` y `OUT` con patrones de bits complementarios |

**Aplicaciones** — división, suma, rotación de un bit, comparación y dos
multiplicadores, uno por sumas sucesivas y otro de desplazar y sumar con
resultado de 16 bits.

Para verificar los nueve de una vez:

```sh
cd programas
sh verificar_todo.sh
```

```
PRUEBAS DEL MICROPROCESADOR
  OK     saltos          JMP JZ JNZ JP JN
  OK     ALU             las 8 operaciones
  OK     entrada/salida  IN y OUT

APLICACIONES
  OK     division        15 / 3 = 5
  OK     suma            25 + 17 = 42
  OK     rotacion        un 1 por 8 posiciones
  OK     mayor           comparacion
  OK     multiplicacion  sumas sucesivas
  OK     mult 16 bits    desplazar y sumar

Los nueve programas pasaron.
```

`programas/ensamblador.py` traduce mnemónicos y etiquetas a la constante
`PROGRAMA` resolviendo las direcciones de salto solo; ver
[`programas/README.md`](programas/README.md).

---

## Simulación

### Con ModelSim-Altera (desde Quartus II)

1. Abrir `MPDII.qpf`.
2. *Processing → Start → Start Analysis & Elaboration*.
3. *Tools → Run Simulation Tool → RTL Simulation*.

El banco de pruebas ya está declarado en el `.qsf` con 6 µs de duración.

### Con GHDL (libre)

```sh
cd sim
sh run_ghdl.sh
gtkwave build/mpdii.vcd
```

Salida esperada:

```
tb_MPDII.vhd:72:17:@3830ns:(report note): OUT_dp = 5
tb_MPDII.vhd:104:9:@5260ns:(report note):   PRUEBA SUPERADA:  15 / 3 = 5
```

Este diseño fue analizado, elaborado y simulado con **GHDL 4.1.0** en modo
`--std=93c` sin errores ni advertencias de síntesis.

---

## Nota sobre `OUT_dp`

La salida proviene de un buffer triestado, tal como aparece en el esquema de
la unidad de datos. El valor solo es válido durante el ciclo en que la unidad
de control activa `OUT_En` (estado S4); fuera de ese ciclo la salida queda en
alta impedancia.

Si se quiere que el resultado permanezca visible en los LED de la tarjeta,
basta con añadir un registro de salida de 8 bits cargado con `OUT_En`, o
mantener `OUT_En = '1'` también en el estado S10 (`HLT`).

---

## Licencia

Material didáctico de libre uso.
