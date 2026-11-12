--------------------------------------------------------------------------------
-- Proyecto : MPDII - Microprocesador didactico de 8 bits
-- Modulo   : rom256x13  -  VARIANTE: cual de dos numeros leidos es el mayor
-- Tipo     : Circuito COMBINACIONAL  ->  descripcion por FLUJO DE DATOS
--------------------------------------------------------------------------------
-- ATENCION: este archivo declara la MISMA entidad que rtl/rom256x13.vhd.
-- Usa uno u otro, nunca los dos a la vez en el mismo proyecto de Quartus.
--------------------------------------------------------------------------------
-- PROGRAMA:  lee dos numeros por Input_dp y saca por OUT_dp el mayor.
--            Si son iguales saca ese mismo valor.
--------------------------------------------------------------------------------
-- Registros usados:  R1 = primer numero   R2 = segundo numero   R3 = el mayor
--
-- COMO SE COMPARA SIN INSTRUCCION DE COMPARACION
--   El procesador no tiene un CMP: la comparacion se hace restando y mirando
--   el signo del resultado.  Con Acc = B se ejecuta SUB R1, que deja B - A, y
--   despues JN decide:
--        B - A negativo  ->  A es el mayor
--        B - A >= 0      ->  B es el mayor (o son iguales)
--
--  Dir  Instruccion   Codificacion         Comentario
--  ---  ------------  -------------------  -------------------------------------
--  00   IN            00010 00000000  200  Acc <- Input_dp  (primer numero, A)
--  01   STR R1        00100 00000001  401  R1  <- A
--  --- RETARDO: ventana para cambiar Input_dp ------------------------------
--  02   LDI 100       00001 01100100  164  Acc <- 100
--  03   DEC           01111 00000000  F00  Acc <- Acc - 1    <-- bucle
--  04   JNZ 3         11010 00000011 1A03  repetir mientras Acc /= 0
--  --- SEGUNDA LECTURA -----------------------------------------------------
--  05   IN            00010 00000000  200  Acc <- Input_dp  (segundo numero, B)
--  06   STR R2        00100 00000010  402  R2  <- B   (el Acc sigue valiendo B)
--  --- COMPARACION ---------------------------------------------------------
--  07   SUB R1        01101 00000001  D01  Acc <- B - A
--  08   JN  12        11100 00001100 1C0C  si B - A < 0 -> A es mayor
--  --- B es el mayor (o son iguales) ---------------------------------------
--  09   LDI 0         00001 00000000  100  Acc <- 0
--  10   ADD R2        01100 00000010  C02  Acc <- B
--  11   JMP 14        11000 00001110 180E  saltar a la salida
--  --- A es el mayor -------------------------------------------------------
--  12   LDI 0         00001 00000000  100  Acc <- 0
--  13   ADD R1        01100 00000001  C01  Acc <- A
--  --- SALIDA --------------------------------------------------------------
--  14   STR R3        00100 00000011  403  R3 <- el mayor  (para poder verlo)
--  15   OUT           00011 00000000  300  OUT_dp <- el mayor
--  16   HLT           11111 00000000 1F00  detener
--
--------------------------------------------------------------------------------
-- NOTA IMPORTANTE - RANGO VALIDO: 0 a 127
--------------------------------------------------------------------------------
--   La bandera Positive_dp es simplemente NOT(Acc(7)), es decir el bit de
--   signo en complemento a dos, y la ALU no tiene bandera de acarreo.  Por eso
--   la resta solo sirve para comparar mientras la diferencia quepa en el rango
--   con signo, lo que se garantiza si los dos numeros son menores o iguales
--   que 127.
--
--   Con numeros mayores la comparacion falla.  Ejemplo: A = 10 y B = 200.
--   B - A = 190 = 10111110, cuyo bit 7 vale 1, asi que JN se toma y el
--   programa contestaria que A es el mayor, lo cual es falso.
--
--   Dos formas de blindarlo:
--     a) Recortar las entradas a 7 bits: cargar 127 en un registro y aplicar
--        AND despues de cada IN.  Cuesta cuatro instrucciones mas.
--     b) Anadir una bandera de acarreo a la unidad de datos y una instruccion
--        de salto que la consulte.  Eso ya es tocar el hardware.
--
-- NOTA - LECTURA DE DOS NUMEROS
--   La instruccion IN captura lo que haya en Input_dp en ese instante y no hay
--   senal de "dato listo", por eso el bucle de retardo de las direcciones 02 a
--   04 abre una ventana de unos 12 us para cambiar el valor de la entrada.
--
-- NOTA - INDICAR CUAL, EN LUGAR DEL VALOR
--   Este programa saca el valor del mayor.  Si lo que se quiere es saber cual
--   de los dos puertos gano, basta con reemplazar las direcciones 09-10 por
--   LDI 2 y las 12-13 por LDI 1: entonces OUT_dp dira "1" o "2".
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
        1  => "0010000000001",   -- 01  STR R1
        2  => "0000101100100",   -- 02  LDI 100     cuenta del retardo
        3  => "0111100000000",   -- 03  DEC         <-- bucle de retardo
        4  => "1101000000011",   -- 04  JNZ 3
        5  => "0001000000000",   -- 05  IN          Acc <- Input_dp (B)
        6  => "0010000000010",   -- 06  STR R2
        7  => "0110100000001",   -- 07  SUB R1      Acc <- B - A
        8  => "1110000001100",   -- 08  JN  12      si B-A < 0 -> A es mayor
        9  => "0000100000000",   -- 09  LDI 0       rama: B es el mayor
        10 => "0110000000010",   -- 10  ADD R2      Acc <- B
        11 => "1100000001110",   -- 11  JMP 14
        12 => "0000100000000",   -- 12  LDI 0       rama: A es el mayor
        13 => "0110000000001",   -- 13  ADD R1      Acc <- A
        14 => "0010000000011",   -- 14  STR R3      R3 <- el mayor
        15 => "0001100000000",   -- 15  OUT         OUT_dp <- el mayor
        16 => "1111100000000",   -- 16  HLT
        others => (others => '0')  -- resto de la memoria: NOP
    );

begin

    -- Lectura puramente combinacional.
    q <= PROGRAMA(to_integer(unsigned(addr)));

end architecture dataflow;
