--------------------------------------------------------------------------------
-- Proyecto : MPDII - Microprocesador didactico de 8 bits
-- Modulo   : rom256x13  -  Memoria de programa, 256 palabras de 13 bits
-- Tipo     : Circuito COMBINACIONAL  ->  descripcion por FLUJO DE DATOS
--------------------------------------------------------------------------------
-- Lectura asincrona: la palabra sale en cuanto cambia la direccion (el PC).
-- El registro de instruccion la captura en el flanco que termina el estado S0.
--
-- FORMATO DE LA PALABRA
--   bits 12..8 : codigo de operacion (COP)
--   bits  7..0 : operando  (direccion de salto / constante / numero de registro)
--
--------------------------------------------------------------------------------
-- PROGRAMA CARGADO:  DIVISION ENTERA POR RESTAS SUCESIVAS   15 / 3 = 5
--------------------------------------------------------------------------------
-- Registros usados:  R1 = dividendo   R2 = divisor   R3 = cociente
--
--  Dir  Instruccion   Codificacion         Comentario
--  ---  ------------  -------------------  -------------------------------------
--  00   LDI 15        00001 00001111  10F  Acc <- 15
--  01   STR R1        00100 00000001  401  R1  <- 15        (dividendo)
--  02   LDI 3         00001 00000011  103  Acc <- 3
--  03   STR R2        00100 00000010  402  R2  <- 3         (divisor)
--  04   LDI 0         00001 00000000  100  Acc <- 0
--  05   STR R3        00100 00000011  403  R3  <- 0         (cociente)
--  --- BUCLE ---------------------------------------------------------------
--  06   LDI 0         00001 00000000  100  Acc <- 0
--  07   ADD R1        01100 00000001  C01  Acc <- R1
--  08   SUB R2        01101 00000010  D02  Acc <- R1 - R2
--  09   JN  16        11100 00010000  1C10 si Acc < 0 -> no cabe, ir a FIN
--  10   STR R1        00100 00000001  401  R1  <- Acc       (resto parcial)
--  11   LDI 0         00001 00000000  100  Acc <- 0
--  12   ADD R3        01100 00000011  C03  Acc <- R3
--  13   INC           01110 00000000  E00  Acc <- R3 + 1
--  14   STR R3        00100 00000011  403  R3  <- cociente
--  15   JMP 6         11000 00000110  1806 repetir el bucle
--  --- FIN -----------------------------------------------------------------
--  16   LDI 0         00001 00000000  100  Acc <- 0
--  17   ADD R3        01100 00000011  C03  Acc <- cociente  (= 5)
--  18   OUT           00011 00000000  300  OUT_dp <- Acc
--  19   HLT           11111 00000000  1F00 detener
--
-- Traza esperada:  15-3=12 (R3=1), 12-3=9 (2), 9-3=6 (3), 6-3=3 (4),
--                  3-3=0 (5), 0-3=-3 < 0 -> salir.   Resultado = 5.
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
        0  => "0000100001111",   -- 00  LDI 15
        1  => "0010000000001",   -- 01  STR R1
        2  => "0000100000011",   -- 02  LDI 3
        3  => "0010000000010",   -- 03  STR R2
        4  => "0000100000000",   -- 04  LDI 0
        5  => "0010000000011",   -- 05  STR R3
        6  => "0000100000000",   -- 06  LDI 0        <-- BUCLE
        7  => "0110000000001",   -- 07  ADD R1
        8  => "0110100000010",   -- 08  SUB R2
        9  => "1110000010000",   -- 09  JN  16
        10 => "0010000000001",   -- 10  STR R1
        11 => "0000100000000",   -- 11  LDI 0
        12 => "0110000000011",   -- 12  ADD R3
        13 => "0111000000000",   -- 13  INC
        14 => "0010000000011",   -- 14  STR R3
        15 => "1100000000110",   -- 15  JMP 6
        16 => "0000100000000",   -- 16  LDI 0        <-- FIN
        17 => "0110000000011",   -- 17  ADD R3
        18 => "0001100000000",   -- 18  OUT
        19 => "1111100000000",   -- 19  HLT
        others => (others => '0')  -- resto de la memoria: NOP
    );

begin

    -- Lectura puramente combinacional.
    q <= PROGRAMA(to_integer(unsigned(addr)));

end architecture dataflow;
