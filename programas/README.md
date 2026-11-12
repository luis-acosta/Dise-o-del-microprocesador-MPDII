# Programas para el MPDII

Cada programa es una **versión completa de `rom256x13.vhd`**. Todos declaran la
misma entidad `rom256x13`, así que en el proyecto de Quartus debe haber **uno
solo a la vez**: quita `rtl/rom256x13.vhd` del proyecto y añade el que quieras
probar, o copia su bloque `constant PROGRAMA` sobre el del archivo original.

Verificar los nueve de una vez con GHDL:

```sh
cd programas
sh verificar_todo.sh
```

---

## Pruebas del microprocesador

Autodiagnósticos que ejercitan cada unidad. Sacan una marca numérica por cada
prueba superada; si aparece un `0xEE` (238) algo falló, y la última marca
correcta indica dónde. De los tres se comprobó que **detectan averías reales**,
inyectando un fallo a propósito en el hardware.

| Programa | Banco de pruebas | Qué comprueba |
|---|---|---|
| `rom256x13_saltos.vhd` | `tb_saltos.vhd` | `JMP`, `JZ`, `JNZ`, `JP`, `JN`, cada uno en el caso que salta y en el que no, más un salto hacia atrás |
| `rom256x13_alu.vhd` | `tb_alu.vhd` | Las ocho operaciones, incluidos el desbordamiento módulo 256 y el complemento a dos |
| `rom256x13_es.vhd` | `tb_es.vhd` | `IN` y `OUT` con patrones de bits complementarios, y la ruta completa del dato |

Los de saltos y ALU **no necesitan entradas**: fabrican sus propias condiciones
con `LDI`. El de entrada/salida sí, porque `IN` depende de lo que haya fuera.

---

## Aplicaciones

| Programa | Banco de pruebas | Qué hace | Limitación |
|---|---|---|---|
| `../rtl/rom256x13.vhd` | `../sim/tb_MPDII.vhd` | División entera por restas sucesivas, 15 ÷ 3 = 5 | — |
| `rom256x13_suma.vhd` | `tb_suma.vhd` | Lee dos números y los suma, 25 + 17 = 42 | Suma módulo 256 |
| `rom256x13_rotacion.vhd` | `tb_rotacion.vhd` | Un 1 recorre las ocho posiciones y sale en cada paso | 360 ns por paso: invisible al ojo |
| `rom256x13_mayor.vhd` | `tb_mayor.vhd` | Indica el mayor de dos números | Solo de 0 a 127 |
| `rom256x13_multiplica.vhd` | `tb_multiplica.vhd` | Multiplicación por sumas sucesivas | Producto ≤ 255; el tiempo crece con el multiplicador |
| `rom256x13_mult_shift.vhd` | `tb_mult_shift.vhd` | Multiplicación de desplazar y sumar, resultado de 16 bits en dos registros | Multiplicando ≤ 127 |

---

## El ensamblador

`ensamblador.py` traduce un programa escrito con mnemónicos y etiquetas a la
constante `PROGRAMA`, resolviendo las direcciones de salto solo. Escribir los
programas largos a mano es la fuente de error más común en este proyecto: basta
insertar una instrucción para que todos los saltos posteriores queden mal.

`gen_alu.py` y `gen_es.py` son los programas fuente legibles de los que salieron
las ROM correspondientes. Para cambiarlos, edita el generador y vuelve a
ejecutarlo:

```sh
cd programas
python3 gen_alu.py
```

Ejemplo del formato:

```python
FUENTE = [
    ('LDI', 90,      'valor esperado'),
    ('STR', 'R1',    ''),
    ('IN',  None,    'leer el puerto'),
    ('SUB', 'R1',    'comparar'),
    ('JNZ', 'ERROR', 'si no da cero, falló'),
    ('LDI', 1,       ''),
    ('OUT', None,    'marca 1'),
    ('.org', 120, ''), ('ERROR:', None, ''),
    ('LDI', 238, ''), ('OUT', None, ''), ('HLT', None, ''),
]
```

---

## Una red de seguridad que sale gratis

En todos los programas las direcciones libres de la ROM quedan en cero, que es
el código de `NOP`. Si por un fallo el contador de programa se escapara de la
zona útil, iría avanzando por esos `NOP` hasta caer en el manejador de error y
sacar `0xEE`, en lugar de quedarse colgado sin dar señal.
