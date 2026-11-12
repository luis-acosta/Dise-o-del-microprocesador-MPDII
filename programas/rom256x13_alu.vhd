--------------------------------------------------------------------------------
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
        0  => "0000101011010",        -- 00  LDI 90      resultado esperado
        1  => "0010000000010",        -- 01  STR R2      
        2  => "0000101011010",        -- 02  LDI 90      operando A -> acumulador
        3  => "0100000000000",        -- 03  PASA        Sel_ALU=000  paso directo de A
        4  => "0110100000010",        -- 04  SUB R2      resultado - esperado
        5  => "1101001111000",        -- 05  JNZ 120     si no es cero, la ALU fallo
        6  => "0000100000001",        -- 06  LDI 1       
        7  => "0001100000000",        -- 07  OUT         marca 1
        8  => "0000100111100",        -- 08  LDI 60      operando B
        9  => "0010000000001",        -- 09  STR R1      
        10 => "0000100110000",        -- 10  LDI 48      resultado esperado
        11 => "0010000000010",        -- 11  STR R2      
        12 => "0000111110000",        -- 12  LDI 240     operando A -> acumulador
        13 => "0100100000001",        -- 13  AND R1      Sel_ALU=001  11110000 AND 00111100
        14 => "0110100000010",        -- 14  SUB R2      resultado - esperado
        15 => "1101001111000",        -- 15  JNZ 120     si no es cero, la ALU fallo
        16 => "0000100000010",        -- 16  LDI 2       
        17 => "0001100000000",        -- 17  OUT         marca 2
        18 => "0000100001111",        -- 18  LDI 15      operando B
        19 => "0010000000001",        -- 19  STR R1      
        20 => "0000111111111",        -- 20  LDI 255     resultado esperado
        21 => "0010000000010",        -- 21  STR R2      
        22 => "0000111110000",        -- 22  LDI 240     operando A -> acumulador
        23 => "0101000000001",        -- 23  OR R1       Sel_ALU=010  11110000 OR  00001111
        24 => "0110100000010",        -- 24  SUB R2      resultado - esperado
        25 => "1101001111000",        -- 25  JNZ 120     si no es cero, la ALU fallo
        26 => "0000100000011",        -- 26  LDI 3       
        27 => "0001100000000",        -- 27  OUT         marca 3
        28 => "0000111110000",        -- 28  LDI 240     resultado esperado
        29 => "0010000000010",        -- 29  STR R2      
        30 => "0000100001111",        -- 30  LDI 15      operando A -> acumulador
        31 => "0101100000000",        -- 31  NOT         Sel_ALU=011  NOT 00001111
        32 => "0110100000010",        -- 32  SUB R2      resultado - esperado
        33 => "1101001111000",        -- 33  JNZ 120     si no es cero, la ALU fallo
        34 => "0000100000100",        -- 34  LDI 4       
        35 => "0001100000000",        -- 35  OUT         marca 4
        36 => "0000100011011",        -- 36  LDI 27      operando B
        37 => "0010000000001",        -- 37  STR R1      
        38 => "0000101111111",        -- 38  LDI 127     resultado esperado
        39 => "0010000000010",        -- 39  STR R2      
        40 => "0000101100100",        -- 40  LDI 100     operando A -> acumulador
        41 => "0110000000001",        -- 41  ADD R1      Sel_ALU=100  100 + 27
        42 => "0110100000010",        -- 42  SUB R2      resultado - esperado
        43 => "1101001111000",        -- 43  JNZ 120     si no es cero, la ALU fallo
        44 => "0000100000101",        -- 44  LDI 5       
        45 => "0001100000000",        -- 45  OUT         marca 5
        46 => "0000101100100",        -- 46  LDI 100     operando B
        47 => "0010000000001",        -- 47  STR R1      
        48 => "0000100101100",        -- 48  LDI 44      resultado esperado
        49 => "0010000000010",        -- 49  STR R2      
        50 => "0000111001000",        -- 50  LDI 200     operando A -> acumulador
        51 => "0110000000001",        -- 51  ADD R1      Sel_ALU=100  200+100=300 -> 44 (modulo 256)
        52 => "0110100000010",        -- 52  SUB R2      resultado - esperado
        53 => "1101001111000",        -- 53  JNZ 120     si no es cero, la ALU fallo
        54 => "0000100000110",        -- 54  LDI 6       
        55 => "0001100000000",        -- 55  OUT         marca 6
        56 => "0000100011011",        -- 56  LDI 27      operando B
        57 => "0010000000001",        -- 57  STR R1      
        58 => "0000101001001",        -- 58  LDI 73      resultado esperado
        59 => "0010000000010",        -- 59  STR R2      
        60 => "0000101100100",        -- 60  LDI 100     operando A -> acumulador
        61 => "0110100000001",        -- 61  SUB R1      Sel_ALU=101  100 - 27
        62 => "0110100000010",        -- 62  SUB R2      resultado - esperado
        63 => "1101001111000",        -- 63  JNZ 120     si no es cero, la ALU fallo
        64 => "0000100000111",        -- 64  LDI 7       
        65 => "0001100000000",        -- 65  OUT         marca 7
        66 => "0000100010100",        -- 66  LDI 20      operando B
        67 => "0010000000001",        -- 67  STR R1      
        68 => "0000111110110",        -- 68  LDI 246     resultado esperado
        69 => "0010000000010",        -- 69  STR R2      
        70 => "0000100001010",        -- 70  LDI 10      operando A -> acumulador
        71 => "0110100000001",        -- 71  SUB R1      Sel_ALU=101  10-20=-10 -> 246 (compl. a dos)
        72 => "0110100000010",        -- 72  SUB R2      resultado - esperado
        73 => "1101001111000",        -- 73  JNZ 120     si no es cero, la ALU fallo
        74 => "0000100001000",        -- 74  LDI 8       
        75 => "0001100000000",        -- 75  OUT         marca 8
        76 => "0000101100100",        -- 76  LDI 100     resultado esperado
        77 => "0010000000010",        -- 77  STR R2      
        78 => "0000101100011",        -- 78  LDI 99      operando A -> acumulador
        79 => "0111000000000",        -- 79  INC         Sel_ALU=110  99 + 1
        80 => "0110100000010",        -- 80  SUB R2      resultado - esperado
        81 => "1101001111000",        -- 81  JNZ 120     si no es cero, la ALU fallo
        82 => "0000100001001",        -- 82  LDI 9       
        83 => "0001100000000",        -- 83  OUT         marca 9
        84 => "0000101100011",        -- 84  LDI 99      resultado esperado
        85 => "0010000000010",        -- 85  STR R2      
        86 => "0000101100100",        -- 86  LDI 100     operando A -> acumulador
        87 => "0111100000000",        -- 87  DEC         Sel_ALU=111  100 - 1
        88 => "0110100000010",        -- 88  SUB R2      resultado - esperado
        89 => "1101001111000",        -- 89  JNZ 120     si no es cero, la ALU fallo
        90 => "0000100001010",        -- 90  LDI 10      
        91 => "0001100000000",        -- 91  OUT         marca 10
        92 => "0000110101010",        -- 92  LDI 170     FIN: 0xAA
        93 => "0001100000000",        -- 93  OUT         todas las pruebas pasaron
        94 => "1111100000000",        -- 94  HLT         
        120=> "0000111101110",        -- 120  LDI 238     MANEJADOR DE ERROR: 0xEE
        121=> "0001100000000",        -- 121  OUT         senal de fallo
        122=> "1111100000000",        -- 122  HLT         
        others => (others => '0')  -- resto de la memoria: NOP
    );

begin

    -- Lectura puramente combinacional.
    q <= PROGRAMA(to_integer(unsigned(addr)));

end architecture dataflow;
