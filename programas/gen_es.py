# -*- coding: utf-8 -*-
"""Genera rom256x13_es.vhd: autodiagnostico de las instrucciones IN y OUT."""
from ensamblador import ensamblar, escribir_rom

# R1 = valor que se espera leer      R2 = temporal para la ruta completa


def prueba_in(marca, esperado, nota):
    return [('LDI', esperado, 'valor que el banco va a presentar'),
            ('STR', 'R1', ''),
            ('IN', None, nota),
            ('SUB', 'R1', 'lo leido menos lo esperado'),
            ('JNZ', 'ERROR', 'si no da cero, IN fallo'),
            ('LDI', marca, ''),
            ('OUT', None, 'marca %d' % marca)]


FUENTE = []
FUENTE += prueba_in(1, 90,  'leer 01011010')
FUENTE += prueba_in(2, 165, 'leer 10100101  (complemento del anterior)')
FUENTE += prueba_in(3, 0,   'leer 00000000  (todos los bits a cero)')
FUENTE += prueba_in(4, 255, 'leer 11111111  (todos los bits a uno)')

# Prueba 5: ruta completa IN -> BUS Y -> banco -> ALU -> BUS Y -> acumulador
FUENTE += [('LDI', 60, 'quinta lectura'), ('STR', 'R1', ''),
           ('IN',  None, 'Input_dp -> acumulador'),
           ('STR', 'R2', 'acumulador -> banco de registros'),
           ('LDI', 0, ''),
           ('ADD', 'R2', 'banco -> entrada B de la ALU -> acumulador'),
           ('SUB', 'R1', 'comparar con lo esperado'),
           ('JNZ', 'ERROR', ''),
           ('LDI', 5, ''), ('OUT', None, 'marca 5')]

# Pruebas 6 a 9: patrones de bits por OUT_dp
FUENTE += [('LDI', 0,   ''), ('OUT', None, 'OUT de 00000000'),
           ('LDI', 255, ''), ('OUT', None, 'OUT de 11111111'),
           ('LDI', 85,  ''), ('OUT', None, 'OUT de 01010101'),
           ('LDI', 170, ''), ('OUT', None, 'OUT de 10101010')]

FUENTE += [('LDI', 200, 'FIN: 0xC8'), ('OUT', None, 'todas las pruebas pasaron'),
           ('HLT', None, '')]

FUENTE += [('.org', 120, ''), ('ERROR:', None, ''),
           ('LDI', 238, 'MANEJADOR DE ERROR: 0xEE'), ('OUT', None, 'senal de fallo'),
           ('HLT', None, '')]

CABECERA = '''--------------------------------------------------------------------------------
-- Proyecto : MPDII - Microprocesador didactico de 8 bits
-- Modulo   : rom256x13  -  VARIANTE: prueba de las instrucciones IN y OUT
-- Tipo     : Circuito COMBINACIONAL  ->  descripcion por FLUJO DE DATOS
--------------------------------------------------------------------------------
-- ARCHIVO GENERADO por programas/gen_es.py usando programas/ensamblador.py.
-- No editar a mano: cambiar el generador y volver a ejecutarlo.
--
-- ATENCION: declara la MISMA entidad que rtl/rom256x13.vhd.  Usa uno u otro.
--------------------------------------------------------------------------------
-- PROGRAMA:  autodiagnostico de la entrada y la salida del microprocesador.
--------------------------------------------------------------------------------
--   Secuencia correcta por OUT_dp:
--       1, 2, 3, 4, 5, 0, 255, 85, 170, 200
--
--   Los cuatro primeros son marcas de las pruebas de IN, el quinto marca la
--   ruta completa, los cuatro siguientes son patrones de bits que prueban
--   OUT, y el 200 (0xC8) es la marca de "todo correcto".  Si aparece un 238
--   alguna prueba fallo.
--
-- ESTE PROGRAMA SI NECESITA EL BANCO DE PRUEBAS
--   A diferencia de los diagnosticos de la ALU y de los saltos, aqui el
--   procesador no puede fabricar sus propios estimulos: IN depende de lo que
--   haya fuera.  El banco tb_es.vhd presenta los valores en el orden que el
--   programa espera, cambiandolos justo despues de cada lectura.
--
-- QUE PRUEBA CADA UNA
--    1   IN lee 90  = 01011010
--    2   IN lee 165 = 10100101   complemento del anterior
--    3   IN lee 0   = 00000000   todos los bits a cero
--    4   IN lee 255 = 11111111   todos los bits a uno
--    5   ruta completa: IN -> BUS Y -> banco -> ALU -> BUS Y -> acumulador
--    6   OUT de 00000000
--    7   OUT de 11111111
--    8   OUT de 01010101
--    9   OUT de 10101010
--
--   POR QUE ESOS VALORES.  Las lecturas 1 y 2 son complementarias: entre las
--   dos obligan a cada uno de los ocho bits de entrada a valer 0 una vez y 1
--   la otra, asi que un bit pegado se delata.  Las lecturas 3 y 4 repiten la
--   idea en bloque.  En la salida, 01010101 y 10101010 hacen lo mismo con el
--   camino de OUT_dp y ademas detectan un cortocircuito entre bits vecinos,
--   porque ningun par contiguo vale lo mismo.
--
--   La prueba 5 es la unica que recorre el camino entero del dato: entra por
--   Input_dp, cruza el multiplexor hasta el BUS Y, se guarda en el banco de
--   registros, vuelve a salir por la entrada B de la ALU y regresa al
--   acumulador.  Si cualquiera de esos tramos corta, falla aqui.
--
--   OUT no necesita prueba aparte: cada una de las diez marcas ES una
--   instruccion OUT, asi que si la secuencia llega completa, OUT funciona.
--   Las pruebas 6 a 9 anaden lo que las marcas no cubren, que son los
--   patrones de bits extremos.
--
-- REGISTROS
--   R1 = valor esperado en cada lectura      R2 = temporal de la prueba 5
--------------------------------------------------------------------------------'''

palabras, etiquetas = ensamblar(FUENTE)
escribir_rom('rom256x13_es.vhd', palabras, CABECERA)
print('instrucciones:', len(palabras))
print('ultima direccion del programa:', max(d for d in palabras if d < 100))
print('lecturas IN que el banco debe alimentar: 90, 165, 0, 255, 60')
