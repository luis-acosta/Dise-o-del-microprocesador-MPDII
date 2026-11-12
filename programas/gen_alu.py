# -*- coding: utf-8 -*-
"""Genera rom256x13_alu.vhd: autodiagnostico de las ocho operaciones de la ALU."""
from ensamblador import ensamblar, escribir_rom

# Cada prueba sigue el mismo patron:
#   cargar el operando del banco (si lo hay) y el valor esperado,
#   poner A en el acumulador, ejecutar la operacion,
#   restar el esperado -> debe dar cero, si no se va al manejador de error.
#
#   R1 = operando B (entrada B de la ALU)
#   R2 = valor esperado


def prueba(marca, op, a, b, esperado, nota):
    """Devuelve las lineas de una prueba. b = None para operaciones de un operando."""
    f = []
    if b is not None:
        f += [('LDI', b, 'operando B'), ('STR', 'R1', '')]
    f += [('LDI', esperado, 'resultado esperado'), ('STR', 'R2', ''),
          ('LDI', a, 'operando A -> acumulador')]
    f += [(op, 'R1' if b is not None else None, nota)]
    f += [('SUB', 'R2', 'resultado - esperado'),
          ('JNZ', 'ERROR', 'si no es cero, la ALU fallo'),
          ('LDI', marca, ''), ('OUT', None, 'marca %d' % marca)]
    return f


FUENTE = []
FUENTE += prueba(1,  'PASA', 90,  None, 90,  'Sel_ALU=000  paso directo de A')
FUENTE += prueba(2,  'AND',  240, 60,   48,  'Sel_ALU=001  11110000 AND 00111100')
FUENTE += prueba(3,  'OR',   240, 15,   255, 'Sel_ALU=010  11110000 OR  00001111')
FUENTE += prueba(4,  'NOT',  15,  None, 240, 'Sel_ALU=011  NOT 00001111')
FUENTE += prueba(5,  'ADD',  100, 27,   127, 'Sel_ALU=100  100 + 27')
FUENTE += prueba(6,  'ADD',  200, 100,  44,  'Sel_ALU=100  200+100=300 -> 44 (modulo 256)')
FUENTE += prueba(7,  'SUB',  100, 27,   73,  'Sel_ALU=101  100 - 27')
FUENTE += prueba(8,  'SUB',  10,  20,   246, 'Sel_ALU=101  10-20=-10 -> 246 (compl. a dos)')
FUENTE += prueba(9,  'INC',  99,  None, 100, 'Sel_ALU=110  99 + 1')
FUENTE += prueba(10, 'DEC',  100, None, 99,  'Sel_ALU=111  100 - 1')

FUENTE += [('LDI', 170, 'FIN: 0xAA'), ('OUT', None, 'todas las pruebas pasaron'),
           ('HLT', None, '')]

FUENTE += [('.org', 120, ''), ('ERROR:', None, ''),
           ('LDI', 238, 'MANEJADOR DE ERROR: 0xEE'), ('OUT', None, 'senal de fallo'),
           ('HLT', None, '')]

CABECERA = '''--------------------------------------------------------------------------------
-- Proyecto : MPDII - Microprocesador didactico de 8 bits
-- Modulo   : rom256x13  -  VARIANTE: prueba de las operaciones de la ALU
-- Tipo     : Circuito COMBINACIONAL  ->  descripcion por FLUJO DE DATOS
--------------------------------------------------------------------------------
-- ARCHIVO GENERADO por programas/gen_alu.py usando programas/ensamblador.py.
-- No editar a mano: cambiar el generador y volver a ejecutarlo.
--
-- ATENCION: declara la MISMA entidad que rtl/rom256x13.vhd.  Usa uno u otro.
--------------------------------------------------------------------------------
-- PROGRAMA:  autodiagnostico de las ocho operaciones de la ALU.
--------------------------------------------------------------------------------
-- No necesita entradas.  Ejecuta diez pruebas y saca por OUT_dp el numero de
-- cada una que pasa.  Si alguna falla salta al manejador de error y saca
-- 0xEE (238) antes de detenerse.
--
--   Secuencia correcta por OUT_dp:
--       1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 170
--
--   El 170 final (0xAA) es la marca de "todas las pruebas pasaron".  Si la
--   secuencia se corta y aparece un 238, el numero de la ultima marca
--   correcta indica que operacion fallo.
--
-- COMO SE COMPRUEBA UN RESULTADO SIN INSTRUCCION DE COMPARACION
--   El procesador no tiene CMP, asi que cada prueba resta el valor esperado
--   al resultado obtenido:  si la ALU calculo bien, la diferencia es cero y
--   Zero_dp se activa.  Un JNZ desvia al manejador de error cuando no lo es.
--   Esto apoya la prueba en SUB y en la bandera Zero_dp; si esas dos fallaran,
--   el programa lo delataria en la prueba 7 u 8.
--
-- QUE PRUEBA CADA UNA
--    1   Sel_ALU=000  paso directo de A      90 -> 90
--    2   Sel_ALU=001  AND                    240 AND 60  = 48
--    3   Sel_ALU=010  OR                     240 OR  15  = 255
--    4   Sel_ALU=011  NOT                    NOT 15      = 240
--    5   Sel_ALU=100  suma                   100 + 27    = 127
--    6   Sel_ALU=100  suma con desbordamiento 200 + 100  = 44
--    7   Sel_ALU=101  resta                  100 - 27    = 73
--    8   Sel_ALU=101  resta negativa         10 - 20     = 246
--    9   Sel_ALU=110  incremento             99 + 1      = 100
--   10   Sel_ALU=111  decremento             100 - 1     = 99
--
--   Las pruebas 6 y 8 son las interesantes: comprueban que la aritmetica es
--   modulo 256 y en complemento a dos, que es justo donde se esconden los
--   errores de una ALU.  200+100 debe dar 44, no 255 ni saturar; y 10-20 debe
--   dar 246, que es -10 en complemento a dos.
--
--   La prueba 1 usa el codigo de operacion 01000, reservado en el juego de
--   instrucciones: decodifica a Sel_ALU=000, el paso directo de A.  Es el
--   mismo camino que usan STR y OUT para sacar el acumulador al BUS Y, asi
--   que conviene comprobarlo explicitamente.
--
-- REGISTROS
--   R1 = operando B (entrada B de la ALU)      R2 = valor esperado
--
-- NOTA - LAS DIRECCIONES LIBRES QUEDAN EN NOP
--   Estan a cero, que es el codigo de NOP.  Si el contador de programa se
--   escapara de la zona util, avanzaria por esos NOP hasta caer en el
--   manejador de error de la direccion 120 y sacar 0xEE.
--------------------------------------------------------------------------------'''

palabras, etiquetas = ensamblar(FUENTE)
escribir_rom('rom256x13_alu.vhd', palabras, CABECERA)
print('instrucciones:', len(palabras))
print('etiquetas:', etiquetas)
print('ultima direccion usada:', max(d for d in palabras if d < 100))
