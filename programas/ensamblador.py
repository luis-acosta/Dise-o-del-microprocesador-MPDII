# -*- coding: utf-8 -*-
"""
Ensamblador minimo para el MPDII.

Traduce un programa escrito con mnemonicos y etiquetas a la constante
`PROGRAMA` de rom256x13.vhd, resolviendo las direcciones de salto solo.
Asi no hay que llevar la cuenta de las direcciones a mano, que es la fuente
de error mas comun al escribir estos programas.

Uso:
    from ensamblador import ensamblar, escribir_rom
    palabras = ensamblar(FUENTE)
    escribir_rom('rom256x13_x.vhd', palabras, cabecera=...)

Formato de cada linea del programa:
    ('ETIQUETA:', None, '')          -> define una etiqueta
    ('LDI', 240, 'comentario')       -> instruccion con operando inmediato
    ('AND', 'R1', 'comentario')      -> instruccion con registro
    ('JNZ', 'ERROR', 'comentario')   -> salto a etiqueta
    ('NOT', None, 'comentario')      -> instruccion sin operando
    ('.org', 120, '')                -> continuar ensamblando en esa direccion
"""

OPCODES = {
    'NOP': 0b00000, 'LDI': 0b00001, 'IN':  0b00010, 'OUT': 0b00011,
    'STR': 0b00100,
    'PASA': 0b01000,                      # paso directo de A (reservado)
    'AND': 0b01001, 'OR':  0b01010, 'NOT': 0b01011, 'ADD': 0b01100,
    'SUB': 0b01101, 'INC': 0b01110, 'DEC': 0b01111,
    'SHL': 0b10001, 'SHR': 0b10010, 'ROR': 0b10011,
    'JMP': 0b11000, 'JZ':  0b11001, 'JNZ': 0b11010, 'JP':  0b11011,
    'JN':  0b11100, 'HLT': 0b11111,
}

SIN_OPERANDO = {'NOP', 'IN', 'OUT', 'NOT', 'INC', 'DEC', 'SHL', 'SHR',
                'ROR', 'HLT', 'PASA'}
CON_REGISTRO = {'STR', 'AND', 'OR', 'ADD', 'SUB'}
CON_SALTO    = {'JMP', 'JZ', 'JNZ', 'JP', 'JN'}


def ensamblar(fuente):
    """Devuelve {direccion: (palabra13, mnemonico, operando, comentario)}."""
    # --- primera pasada: posiciones y etiquetas
    etiquetas, pc, plan = {}, 0, []
    for mnem, oper, com in fuente:
        if mnem == '.org':
            pc = int(oper)
            continue
        if mnem.endswith(':'):
            etiquetas[mnem[:-1]] = pc
            continue
        plan.append((pc, mnem, oper, com))
        pc += 1

    # --- segunda pasada: codificar
    salida = {}
    for dirn, mnem, oper, com in plan:
        if mnem not in OPCODES:
            raise ValueError('mnemonico desconocido: %r' % mnem)
        cop = OPCODES[mnem]

        if mnem in SIN_OPERANDO:
            if oper not in (None, ''):
                raise ValueError('%s no lleva operando (dir %d)' % (mnem, dirn))
            val = 0
            texto = ''
        elif mnem in CON_REGISTRO:
            if not (isinstance(oper, str) and oper.upper().startswith('R')):
                raise ValueError('%s necesita un registro Rn (dir %d)' % (mnem, dirn))
            val = int(oper[1:])
            if not 0 <= val <= 15:
                raise ValueError('registro fuera de rango: %s' % oper)
            texto = oper.upper()
        elif mnem in CON_SALTO:
            if isinstance(oper, str):
                if oper not in etiquetas:
                    raise ValueError('etiqueta no definida: %r' % oper)
                val = etiquetas[oper]
            else:
                val = int(oper)
            texto = str(val)
        else:                                    # LDI
            val = int(oper)
            texto = str(val)

        if not 0 <= val <= 255:
            raise ValueError('operando fuera de rango en dir %d: %r' % (dirn, oper))
        if dirn in salida:
            raise ValueError('dos instrucciones en la direccion %d' % dirn)

        palabra = format(cop, '05b') + format(val, '08b')
        salida[dirn] = (palabra, mnem, texto, com)

    return salida, etiquetas


def bloque_constante(palabras):
    """Genera el texto del constant PROGRAMA listo para pegar en el .vhd."""
    lineas = ['    constant PROGRAMA : rom_array := (',
              '        --   dir            codigo          instruccion']
    for dirn in sorted(palabras):
        pal, mnem, oper, com = palabras[dirn]
        instr = (mnem + ' ' + oper).strip()
        izq = '        %-3d=> "%s",' % (dirn, pal)
        lineas.append('%-38s-- %02d  %-11s %s' % (izq, dirn, instr, com))
    lineas.append("        others => (others => '0')  -- resto de la memoria: NOP")
    lineas.append('    );')
    return '\n'.join(lineas)


PLANTILLA = '''%(cabecera)s

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rom256x13 is
    port (
        addr : in  std_logic_vector(7 downto 0);   -- salida del PC
        q    : out std_logic_vector(12 downto 0)   -- palabra de instruccion
    );
end entity rom256x13;

architecture dataflow of rom256x13 is

    type rom_array is array (0 to 255) of std_logic_vector(12 downto 0);

%(constante)s

begin

    -- Lectura puramente combinacional.
    q <= PROGRAMA(to_integer(unsigned(addr)));

end architecture dataflow;
'''


def escribir_rom(ruta, palabras, cabecera):
    texto = PLANTILLA % {'cabecera': cabecera.rstrip(),
                         'constante': bloque_constante(palabras)}
    open(ruta, 'w', encoding='utf-8').write(texto)
    return texto
