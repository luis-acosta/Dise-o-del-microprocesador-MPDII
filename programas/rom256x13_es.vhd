--------------------------------------------------------------------------------
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
        0  => "0000101011010",        -- 00  LDI 90      valor que el banco va a presentar
        1  => "0010000000001",        -- 01  STR R1      
        2  => "0001000000000",        -- 02  IN          leer 01011010
        3  => "0110100000001",        -- 03  SUB R1      lo leido menos lo esperado
        4  => "1101001111000",        -- 04  JNZ 120     si no da cero, IN fallo
        5  => "0000100000001",        -- 05  LDI 1       
        6  => "0001100000000",        -- 06  OUT         marca 1
        7  => "0000110100101",        -- 07  LDI 165     valor que el banco va a presentar
        8  => "0010000000001",        -- 08  STR R1      
        9  => "0001000000000",        -- 09  IN          leer 10100101  (complemento del anterior)
        10 => "0110100000001",        -- 10  SUB R1      lo leido menos lo esperado
        11 => "1101001111000",        -- 11  JNZ 120     si no da cero, IN fallo
        12 => "0000100000010",        -- 12  LDI 2       
        13 => "0001100000000",        -- 13  OUT         marca 2
        14 => "0000100000000",        -- 14  LDI 0       valor que el banco va a presentar
        15 => "0010000000001",        -- 15  STR R1      
        16 => "0001000000000",        -- 16  IN          leer 00000000  (todos los bits a cero)
        17 => "0110100000001",        -- 17  SUB R1      lo leido menos lo esperado
        18 => "1101001111000",        -- 18  JNZ 120     si no da cero, IN fallo
        19 => "0000100000011",        -- 19  LDI 3       
        20 => "0001100000000",        -- 20  OUT         marca 3
        21 => "0000111111111",        -- 21  LDI 255     valor que el banco va a presentar
        22 => "0010000000001",        -- 22  STR R1      
        23 => "0001000000000",        -- 23  IN          leer 11111111  (todos los bits a uno)
        24 => "0110100000001",        -- 24  SUB R1      lo leido menos lo esperado
        25 => "1101001111000",        -- 25  JNZ 120     si no da cero, IN fallo
        26 => "0000100000100",        -- 26  LDI 4       
        27 => "0001100000000",        -- 27  OUT         marca 4
        28 => "0000100111100",        -- 28  LDI 60      quinta lectura
        29 => "0010000000001",        -- 29  STR R1      
        30 => "0001000000000",        -- 30  IN          Input_dp -> acumulador
        31 => "0010000000010",        -- 31  STR R2      acumulador -> banco de registros
        32 => "0000100000000",        -- 32  LDI 0       
        33 => "0110000000010",        -- 33  ADD R2      banco -> entrada B de la ALU -> acumulador
        34 => "0110100000001",        -- 34  SUB R1      comparar con lo esperado
        35 => "1101001111000",        -- 35  JNZ 120     
        36 => "0000100000101",        -- 36  LDI 5       
        37 => "0001100000000",        -- 37  OUT         marca 5
        38 => "0000100000000",        -- 38  LDI 0       
        39 => "0001100000000",        -- 39  OUT         OUT de 00000000
        40 => "0000111111111",        -- 40  LDI 255     
        41 => "0001100000000",        -- 41  OUT         OUT de 11111111
        42 => "0000101010101",        -- 42  LDI 85      
        43 => "0001100000000",        -- 43  OUT         OUT de 01010101
        44 => "0000110101010",        -- 44  LDI 170     
        45 => "0001100000000",        -- 45  OUT         OUT de 10101010
        46 => "0000111001000",        -- 46  LDI 200     FIN: 0xC8
        47 => "0001100000000",        -- 47  OUT         todas las pruebas pasaron
        48 => "1111100000000",        -- 48  HLT         
        120=> "0000111101110",        -- 120  LDI 238     MANEJADOR DE ERROR: 0xEE
        121=> "0001100000000",        -- 121  OUT         senal de fallo
        122=> "1111100000000",        -- 122  HLT         
        others => (others => '0')  -- resto de la memoria: NOP
    );

begin

    -- Lectura puramente combinacional.
    q <= PROGRAMA(to_integer(unsigned(addr)));

end architecture dataflow;
