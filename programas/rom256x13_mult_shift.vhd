--------------------------------------------------------------------------------
-- Proyecto : MPDII - Microprocesador didactico de 8 bits
-- Modulo   : rom256x13  -  VARIANTE: multiplicacion de desplazar y sumar
--                                    con resultado de 16 bits en dos registros
-- Tipo     : Circuito COMBINACIONAL  ->  descripcion por FLUJO DE DATOS
--------------------------------------------------------------------------------
-- ATENCION: este archivo declara la MISMA entidad que rtl/rom256x13.vhd.
-- Usa uno u otro, nunca los dos a la vez en el mismo proyecto de Quartus.
--------------------------------------------------------------------------------
-- PROGRAMA:  lee dos numeros por Input_dp, los multiplica por el metodo de
--            desplazar y sumar, guarda el producto de 16 bits en R3 (parte
--            alta) y R2 (parte baja), y saca los dos por OUT_dp: primero la
--            parte ALTA y despues la parte BAJA.
--------------------------------------------------------------------------------
-- Registros:  R1 = multiplicando A      R2 = parte BAJA del producto
--             R3 = parte ALTA           R4 = contador de 8 vueltas
--             R5 = bit que baja de R3 a R2    R6 = mascara 00000001
--
-- ALGORITMO
--   Es el multiplicador serie clasico.  El par R3:R2 arranca con el
--   multiplicador B en la mitad baja y se desplaza a la derecha ocho veces.
--   En cada vuelta, si el bit que sale por abajo vale 1, se suma A a la mitad
--   alta.  Al terminar, R3:R2 contiene el producto completo de 16 bits.
--
--       R3 = 0 ;  R2 = B
--       repetir 8 veces:
--           si R2(0) = 1 :  R3 = R3 + A
--           R2 = (R2 >> 1) con el bit 0 de R3 entrando por arriba
--           R3 =  R3 >> 1
--
--   Siempre son 8 vueltas, sin importar el valor de los operandos.  La version
--   de sumas sucesivas daba B vueltas, asi que esta gana en cuanto B pasa de 8.
--
--------------------------------------------------------------------------------
-- POR QUE EL MULTIPLICANDO SE LIMITA A 0..127
--------------------------------------------------------------------------------
--   La unica suma del algoritmo es R3 = R3 + A, y la ALU no tiene bandera de
--   acarreo: si esa suma pasara de 255 el acarreo se perderia en silencio y el
--   producto saldria mal.
--
--   Justo antes de la suma, R3 viene de un desplazamiento a la derecha, asi
--   que vale como mucho 127.  Si ademas A <= 127, entonces
--
--       R3 + A  <=  127 + 127  =  254  <  256
--
--   y la suma NUNCA desborda.  Con esa sola condicion el algoritmo es exacto
--   y no hace falta detectar acarreo en ningun momento.
--
--   El multiplicador B si puede ser cualquier valor de 0 a 255.
--   Producto maximo:  127 x 255 = 32385, que cabe de sobra en los 16 bits.
--
--   Si se necesitara A > 127 habria que detectar el acarreo a mano con la
--   logica de los bits de signo:
--       acarreo = (X7 AND Y7) OR ((X7 OR Y7) AND NOT S7)
--   lo que se puede armar con AND, OR, NOT y la mascara 0x80, a costa de unas
--   quince instrucciones extra por suma.
--
--------------------------------------------------------------------------------
--  Dir  Instruccion   Codificacion         Comentario
--  ---  ------------  -------------------  -------------------------------------
--  00   IN            00010 00000000  200  Acc <- Input_dp  (multiplicando A)
--  01   STR R1        00100 00000001  401  R1 <- A
--  02   LDI 100       00001 01100100  164  retardo
--  03   DEC           01111 00000000  F00  <-- bucle de retardo
--  04   JNZ 3         11010 00000011 1A03
--  05   IN            00010 00000000  200  Acc <- Input_dp  (multiplicador B)
--  06   STR R2        00100 00000010  402  R2 <- B   (parte baja inicial)
--  07   LDI 0         00001 00000000  100
--  08   STR R3        00100 00000011  403  R3 <- 0   (parte alta)
--  09   LDI 8         00001 00001000  108
--  10   STR R4        00100 00000100  404  R4 <- 8   (contador de vueltas)
--  11   LDI 1         00001 00000001  101
--  12   STR R6        00100 00000110  406  R6 <- 00000001  (mascara del bit 0)
--  --- BUCLE: mirar el bit que sale por abajo ------------------------------
--  13   LDI 0         00001 00000000  100  <-- BUCLE
--  14   ADD R2        01100 00000010  C02  Acc <- parte baja
--  15   AND R6        01001 00000110  906  Acc <- bit 0
--  16   JZ  21        11001 00010101 1915  si el bit es 0, no sumar
--  17   LDI 0         00001 00000000  100
--  18   ADD R3        01100 00000011  C03  Acc <- parte alta
--  19   ADD R1        01100 00000001  C01  Acc <- parte alta + A
--  20   STR R3        00100 00000011  403  R3 <- R3 + A
--  --- que bit baja de R3 a R2 --------------------------------------------
--  21   LDI 0         00001 00000000  100
--  22   ADD R3        01100 00000011  C03  Acc <- parte alta
--  23   AND R6        01001 00000110  906  Acc <- bit 0 de la parte alta
--  24   JZ  28        11001 00011100 191C  si es 0 -> no se inserta nada
--  25   LDI 128       00001 10000000  180  R5 <- 10000000
--  26   STR R5        00100 00000101  405
--  27   JMP 30        11000 00011110 181E
--  28   LDI 0         00001 00000000  100  R5 <- 00000000
--  29   STR R5        00100 00000101  405
--  --- parte baja: desplazar e insertar el bit -----------------------------
--  30   LDI 0         00001 00000000  100
--  31   ADD R2        01100 00000010  C02  Acc <- parte baja
--  32   SHR           10010 00000000 1200  Acc <- parte baja >> 1
--  33   OR  R5        01010 00000101  A05  insertar el bit por arriba
--  34   STR R2        00100 00000010  402  R2 actualizado
--  --- parte alta: desplazar -----------------------------------------------
--  35   LDI 0         00001 00000000  100
--  36   ADD R3        01100 00000011  C03
--  37   SHR           10010 00000000 1200  Acc <- parte alta >> 1
--  38   STR R3        00100 00000011  403  R3 actualizado
--  --- contador ------------------------------------------------------------
--  39   LDI 0         00001 00000000  100
--  40   ADD R4        01100 00000100  C04  Acc <- contador
--  41   DEC           01111 00000000  F00  contador - 1
--  42   STR R4        00100 00000100  404
--  43   JNZ 13        11010 00001101 1A0D  ocho vueltas en total
--  --- SALIDA: primero la parte ALTA, despues la BAJA ----------------------
--  44   LDI 0         00001 00000000  100
--  45   ADD R3        01100 00000011  C03  Acc <- parte ALTA
--  46   OUT           00011 00000000  300  OUT_dp <- parte alta
--  47   LDI 0         00001 00000000  100
--  48   ADD R2        01100 00000010  C02  Acc <- parte BAJA
--  49   OUT           00011 00000000  300  OUT_dp <- parte baja
--  50   HLT           11111 00000000 1F00  detener
--
-- COMO LEER EL RESULTADO
--   Las dos salidas llegan separadas por 6 ciclos (120 ns).  El valor final es
--       producto = parte_alta x 256 + parte_baja
--   Ejemplo:  100 x 200 = 20000 = 0x4E20  ->  parte alta 78, parte baja 32.
--
--   Como OUT_dp es triestado y solo vale durante el ciclo de cada OUT, para
--   verlas en hardware hay que registrarlas: dos registros de 8 bits cargados
--   en instantes distintos, o un unico registro mas un bit que diga cual mitad
--   esta presente.
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
        0  => "0001000000000",   -- 00  IN          Acc <- Input_dp (A)
        1  => "0010000000001",   -- 01  STR R1      multiplicando
        2  => "0000101100100",   -- 02  LDI 100     cuenta del retardo
        3  => "0111100000000",   -- 03  DEC         <-- bucle de retardo
        4  => "1101000000011",   -- 04  JNZ 3
        5  => "0001000000000",   -- 05  IN          Acc <- Input_dp (B)
        6  => "0010000000010",   -- 06  STR R2      parte baja <- B
        7  => "0000100000000",   -- 07  LDI 0
        8  => "0010000000011",   -- 08  STR R3      parte alta <- 0
        9  => "0000100001000",   -- 09  LDI 8
        10 => "0010000000100",   -- 10  STR R4      contador <- 8
        11 => "0000100000001",   -- 11  LDI 1
        12 => "0010000000110",   -- 12  STR R6      mascara 00000001
        13 => "0000100000000",   -- 13  LDI 0       <-- BUCLE
        14 => "0110000000010",   -- 14  ADD R2      Acc <- parte baja
        15 => "0100100000110",   -- 15  AND R6      Acc <- bit 0
        16 => "1100100010101",   -- 16  JZ  21      bit 0 = 0 -> no sumar
        17 => "0000100000000",   -- 17  LDI 0
        18 => "0110000000011",   -- 18  ADD R3      Acc <- parte alta
        19 => "0110000000001",   -- 19  ADD R1      Acc <- parte alta + A
        20 => "0010000000011",   -- 20  STR R3
        21 => "0000100000000",   -- 21  LDI 0
        22 => "0110000000011",   -- 22  ADD R3      Acc <- parte alta
        23 => "0100100000110",   -- 23  AND R6      Acc <- bit 0 de la parte alta
        24 => "1100100011100",   -- 24  JZ  28
        25 => "0000110000000",   -- 25  LDI 128
        26 => "0010000000101",   -- 26  STR R5      bit a insertar = 10000000
        27 => "1100000011110",   -- 27  JMP 30
        28 => "0000100000000",   -- 28  LDI 0
        29 => "0010000000101",   -- 29  STR R5      bit a insertar = 00000000
        30 => "0000100000000",   -- 30  LDI 0
        31 => "0110000000010",   -- 31  ADD R2      Acc <- parte baja
        32 => "1001000000000",   -- 32  SHR         parte baja >> 1
        33 => "0101000000101",   -- 33  OR  R5      insertar el bit por arriba
        34 => "0010000000010",   -- 34  STR R2
        35 => "0000100000000",   -- 35  LDI 0
        36 => "0110000000011",   -- 36  ADD R3
        37 => "1001000000000",   -- 37  SHR         parte alta >> 1
        38 => "0010000000011",   -- 38  STR R3
        39 => "0000100000000",   -- 39  LDI 0
        40 => "0110000000100",   -- 40  ADD R4      Acc <- contador
        41 => "0111100000000",   -- 41  DEC
        42 => "0010000000100",   -- 42  STR R4
        43 => "1101000001101",   -- 43  JNZ 13      ocho vueltas
        44 => "0000100000000",   -- 44  LDI 0       <-- SALIDA
        45 => "0110000000011",   -- 45  ADD R3      Acc <- parte ALTA
        46 => "0001100000000",   -- 46  OUT
        47 => "0000100000000",   -- 47  LDI 0
        48 => "0110000000010",   -- 48  ADD R2      Acc <- parte BAJA
        49 => "0001100000000",   -- 49  OUT
        50 => "1111100000000",   -- 50  HLT
        others => (others => '0')  -- resto de la memoria: NOP
    );

begin

    -- Lectura puramente combinacional.
    q <= PROGRAMA(to_integer(unsigned(addr)));

end architecture dataflow;
