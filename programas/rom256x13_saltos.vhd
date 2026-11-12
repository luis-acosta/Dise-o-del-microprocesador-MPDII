--------------------------------------------------------------------------------
-- Proyecto : MPDII - Microprocesador didactico de 8 bits
-- Modulo   : rom256x13  -  VARIANTE: prueba de las instrucciones de salto
-- Tipo     : Circuito COMBINACIONAL  ->  descripcion por FLUJO DE DATOS
--------------------------------------------------------------------------------
-- ATENCION: este archivo declara la MISMA entidad que rtl/rom256x13.vhd.
-- Usa uno u otro, nunca los dos a la vez en el mismo proyecto de Quartus.
--------------------------------------------------------------------------------
-- PROGRAMA:  autodiagnostico de las cinco instrucciones de salto.
--------------------------------------------------------------------------------
-- No necesita entradas: no lee Input_dp.  Ejecuta diez pruebas y saca por
-- OUT_dp el numero de cada prueba que pasa.  Si alguna falla, salta al
-- manejador de error y saca 0xEE (238) antes de detenerse.
--
--   Secuencia correcta por OUT_dp:
--       1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 170
--
--   El 170 final (0xAA, que en binario es 10101010) es la marca de "todas
--   las pruebas pasaron".  Si la secuencia se corta antes y aparece un 238,
--   el numero de la ultima marca correcta indica en que prueba fallo.
--
-- QUE PRUEBA CADA UNA
--   Cada salto condicional se prueba DOS veces: una en la que debe saltar y
--   otra en la que no debe hacerlo.  Probar solo el caso que salta dejaria
--   pasar un error en el que la condicion estuviera siempre activa.
--
--   1   JMP   salto incondicional hacia adelante
--   2   JZ    con Acc = 0      ->  debe saltar
--   3   JZ    con Acc = 5      ->  NO debe saltar
--   4   JNZ   con Acc = 5      ->  debe saltar
--   5   JNZ   con Acc = 0      ->  NO debe saltar
--   6   JP    con Acc = 5      ->  debe saltar     (bit 7 = 0)
--   7   JP    con Acc = 200    ->  NO debe saltar  (bit 7 = 1)
--   8   JN    con Acc = 200    ->  debe saltar
--   9   JN    con Acc = 5      ->  NO debe saltar
--  10   JNZ   hacia ATRAS: bucle que cuenta 3, 2, 1, 0 y sale
--
--   El valor 200 es 11001000: tiene el bit 7 en uno, asi que el procesador lo
--   interpreta como negativo en complemento a dos y Positive_dp vale 0.
--   La prueba 10 comprueba que un salto hacia una direccion MENOR funciona,
--   que es lo que sostiene cualquier bucle.
--
--  Dir  Instruccion   Codificacion         Comentario
--  ---  ------------  -------------------  -------------------------------------
--  --- PRUEBA 1: JMP incondicional -----------------------------------------
--  00   JMP 2         11000 00000010 1802  saltar por encima del error
--  01   JMP 90        11000 01011010 185A  ERROR: el JMP no salto
--  02   LDI 1         00001 00000001  101
--  03   OUT           00011 00000000  300  marca 1
--  --- PRUEBA 2: JZ con Acc = 0, debe saltar -------------------------------
--  04   LDI 0         00001 00000000  100  Zero_dp pasa a 1
--  05   JZ  7         11001 00000111 1907
--  06   JMP 90        11000 01011010 185A  ERROR: no salto debiendo
--  07   LDI 2         00001 00000010  102
--  08   OUT           00011 00000000  300  marca 2
--  --- PRUEBA 3: JZ con Acc = 5, NO debe saltar ----------------------------
--  09   LDI 5         00001 00000101  105  Zero_dp pasa a 0
--  10   JZ  90        11001 01011010 195A  si salta -> ERROR
--  11   LDI 3         00001 00000011  103
--  12   OUT           00011 00000000  300  marca 3
--  --- PRUEBA 4: JNZ con Acc = 5, debe saltar ------------------------------
--  13   LDI 5         00001 00000101  105
--  14   JNZ 16        11010 00010000 1A10
--  15   JMP 90        11000 01011010 185A  ERROR
--  16   LDI 4         00001 00000100  104
--  17   OUT           00011 00000000  300  marca 4
--  --- PRUEBA 5: JNZ con Acc = 0, NO debe saltar ---------------------------
--  18   LDI 0         00001 00000000  100
--  19   JNZ 90        11010 01011010 1A5A  si salta -> ERROR
--  20   LDI 5         00001 00000101  105
--  21   OUT           00011 00000000  300  marca 5
--  --- PRUEBA 6: JP con Acc = 5 (positivo), debe saltar --------------------
--  22   LDI 5         00001 00000101  105  Positive_dp pasa a 1
--  23   JP  25        11011 00011001 1B19
--  24   JMP 90        11000 01011010 185A  ERROR
--  25   LDI 6         00001 00000110  106
--  26   OUT           00011 00000000  300  marca 6
--  --- PRUEBA 7: JP con Acc = 200 (negativo), NO debe saltar ---------------
--  27   LDI 200       00001 11001000  1C8  bit 7 = 1 -> Positive_dp = 0
--  28   JP  90        11011 01011010 1B5A  si salta -> ERROR
--  29   LDI 7         00001 00000111  107
--  30   OUT           00011 00000000  300  marca 7
--  --- PRUEBA 8: JN con Acc = 200 (negativo), debe saltar ------------------
--  31   LDI 200       00001 11001000  1C8
--  32   JN  34        11100 00100010 1C22
--  33   JMP 90        11000 01011010 185A  ERROR
--  34   LDI 8         00001 00001000  108
--  35   OUT           00011 00000000  300  marca 8
--  --- PRUEBA 9: JN con Acc = 5 (positivo), NO debe saltar -----------------
--  36   LDI 5         00001 00000101  105
--  37   JN  90        11100 01011010 1C5A  si salta -> ERROR
--  38   LDI 9         00001 00001001  109
--  39   OUT           00011 00000000  300  marca 9
--  --- PRUEBA 10: JNZ hacia ATRAS, bucle de tres vueltas -------------------
--  40   LDI 3         00001 00000011  103  contador = 3
--  41   DEC           01111 00000000  F00  <-- destino del salto hacia atras
--  42   JNZ 41        11010 00101001 1A29  repetir mientras Acc /= 0
--  43   LDI 10        00001 00001010  10A
--  44   OUT           00011 00000000  300  marca 10: el bucle salio bien
--  --- FIN: todas las pruebas pasaron --------------------------------------
--  45   LDI 170       00001 10101010  1AA  0xAA = 10101010
--  46   OUT           00011 00000000  300  marca final
--  47   HLT           11111 00000000 1F00
--  --- MANEJADOR DE ERROR (direccion 90) -----------------------------------
--  90   LDI 238       00001 11101110  1EE  0xEE
--  91   OUT           00011 00000000  300  senal de fallo
--  92   HLT           11111 00000000 1F00
--
-- NOTA - LAS DIRECCIONES 48 A 89 QUEDAN EN NOP
--   Estan a cero, que es el codigo de NOP.  Si por un fallo el contador de
--   programa se escapara de la zona util, iria avanzando por esos NOP hasta
--   caer en el manejador de error de la direccion 90 y sacar 0xEE.  Es una
--   red de seguridad gratuita.
--
-- NOTA - POR QUE ESTE PROGRAMA NO USA Input_dp
--   Todas las condiciones se fabrican con LDI, asi que la prueba es
--   repetible y no depende de lo que haya en los interruptores.
--------------------------------------------------------------------------------

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

    constant PROGRAMA : rom_array := (
        --   dir            codigo          instruccion
        0  => "1100000000010",   -- 00  JMP 2       PRUEBA 1: salto incondicional
        1  => "1100001011010",   -- 01  JMP 90      ERROR: el JMP no salto
        2  => "0000100000001",   -- 02  LDI 1
        3  => "0001100000000",   -- 03  OUT         marca 1
        4  => "0000100000000",   -- 04  LDI 0       PRUEBA 2: JZ debe saltar
        5  => "1100100000111",   -- 05  JZ  7
        6  => "1100001011010",   -- 06  JMP 90      ERROR
        7  => "0000100000010",   -- 07  LDI 2
        8  => "0001100000000",   -- 08  OUT         marca 2
        9  => "0000100000101",   -- 09  LDI 5       PRUEBA 3: JZ NO debe saltar
        10 => "1100101011010",   -- 10  JZ  90      si salta -> ERROR
        11 => "0000100000011",   -- 11  LDI 3
        12 => "0001100000000",   -- 12  OUT         marca 3
        13 => "0000100000101",   -- 13  LDI 5       PRUEBA 4: JNZ debe saltar
        14 => "1101000010000",   -- 14  JNZ 16
        15 => "1100001011010",   -- 15  JMP 90      ERROR
        16 => "0000100000100",   -- 16  LDI 4
        17 => "0001100000000",   -- 17  OUT         marca 4
        18 => "0000100000000",   -- 18  LDI 0       PRUEBA 5: JNZ NO debe saltar
        19 => "1101001011010",   -- 19  JNZ 90      si salta -> ERROR
        20 => "0000100000101",   -- 20  LDI 5
        21 => "0001100000000",   -- 21  OUT         marca 5
        22 => "0000100000101",   -- 22  LDI 5       PRUEBA 6: JP debe saltar
        23 => "1101100011001",   -- 23  JP  25
        24 => "1100001011010",   -- 24  JMP 90      ERROR
        25 => "0000100000110",   -- 25  LDI 6
        26 => "0001100000000",   -- 26  OUT         marca 6
        27 => "0000111001000",   -- 27  LDI 200     PRUEBA 7: JP NO debe saltar
        28 => "1101101011010",   -- 28  JP  90      si salta -> ERROR
        29 => "0000100000111",   -- 29  LDI 7
        30 => "0001100000000",   -- 30  OUT         marca 7
        31 => "0000111001000",   -- 31  LDI 200     PRUEBA 8: JN debe saltar
        32 => "1110000100010",   -- 32  JN  34
        33 => "1100001011010",   -- 33  JMP 90      ERROR
        34 => "0000100001000",   -- 34  LDI 8
        35 => "0001100000000",   -- 35  OUT         marca 8
        36 => "0000100000101",   -- 36  LDI 5       PRUEBA 9: JN NO debe saltar
        37 => "1110001011010",   -- 37  JN  90      si salta -> ERROR
        38 => "0000100001001",   -- 38  LDI 9
        39 => "0001100000000",   -- 39  OUT         marca 9
        40 => "0000100000011",   -- 40  LDI 3       PRUEBA 10: salto hacia atras
        41 => "0111100000000",   -- 41  DEC         <-- destino del salto
        42 => "1101000101001",   -- 42  JNZ 41      bucle de tres vueltas
        43 => "0000100001010",   -- 43  LDI 10
        44 => "0001100000000",   -- 44  OUT         marca 10
        45 => "0000110101010",   -- 45  LDI 170     FIN: 0xAA
        46 => "0001100000000",   -- 46  OUT         todas las pruebas pasaron
        47 => "1111100000000",   -- 47  HLT
        90 => "0000111101110",   -- 90  LDI 238     MANEJADOR DE ERROR: 0xEE
        91 => "0001100000000",   -- 91  OUT
        92 => "1111100000000",   -- 92  HLT
        others => (others => '0')  -- resto de la memoria: NOP
    );

begin

    -- Lectura puramente combinacional.
    q <= PROGRAMA(to_integer(unsigned(addr)));

end architecture dataflow;
