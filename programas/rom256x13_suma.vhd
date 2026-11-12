--------------------------------------------------------------------------------
-- Proyecto : MPDII - Microprocesador didactico de 8 bits
-- Modulo   : rom256x13  -  VARIANTE: suma de dos numeros leidos por Input_dp
-- Tipo     : Circuito COMBINACIONAL  ->  descripcion por FLUJO DE DATOS
--------------------------------------------------------------------------------
-- ATENCION: este archivo declara la MISMA entidad que rtl/rom256x13.vhd.
-- Usa uno u otro, nunca los dos a la vez en el mismo proyecto de Quartus.
-- Para probarlo: quita rtl/rom256x13.vhd del proyecto y anade este en su lugar,
-- o copia solo el bloque "constant PROGRAMA" sobre el del archivo original.
--------------------------------------------------------------------------------
-- PROGRAMA:  OUT_dp  <-  primer numero  +  segundo numero
--------------------------------------------------------------------------------
-- Registros usados:  R1 = primer sumando   R2 = segundo sumando   R3 = suma
--
-- COMO SE LEEN DOS NUMEROS POR UN SOLO PUERTO
--   La unidad de datos no tiene ninguna senal de "dato listo": la instruccion
--   IN captura lo que haya en Input_dp en ese instante.  Como las dos lecturas
--   estarian separadas apenas 180 ns, entre ellas se coloca un bucle de
--   retardo que abre una ventana para cambiar el valor de la entrada.
--
--   El retardo es de RETARDO x 6 ciclos.  Con RETARDO = 100 y reloj de 50 MHz
--   la ventana dura unos 12 us, suficiente para un banco de pruebas o un
--   analizador logico.  Para que una persona alcance a mover los
--   interruptores hace falta mucho mas: ver la nota al final.
--
--  Dir  Instruccion   Codificacion         Comentario
--  ---  ------------  -------------------  -------------------------------------
--  00   IN            00010 00000000  200  Acc <- Input_dp   (primer numero)
--  01   STR R1        00100 00000001  401  R1  <- primer numero
--  --- RETARDO: ventana para cambiar Input_dp ------------------------------
--  02   LDI 100       00001 01100100  164  Acc <- 100        (cuenta atras)
--  03   DEC           01111 00000000  F00  Acc <- Acc - 1    <-- bucle
--  04   JNZ 3         11010 00000011 1A03  repetir mientras Acc /= 0
--  --- SEGUNDA LECTURA Y SUMA ----------------------------------------------
--  05   IN            00010 00000000  200  Acc <- Input_dp   (segundo numero)
--  06   STR R2        00100 00000010  402  R2  <- segundo numero
--  07   ADD R1        01100 00000001  C01  Acc <- segundo + primero
--  08   STR R3        00100 00000011  403  R3  <- suma
--  09   OUT           00011 00000000  300  OUT_dp <- suma
--  10   HLT           11111 00000000 1F00  detener
--
-- NOTA 1 - DESBORDAMIENTO
--   La ALU trabaja modulo 256 y no hay bandera de acarreo, asi que si la suma
--   pasa de 255 el resultado se envuelve.  Con sumandos de hasta 127 cada uno
--   el resultado siempre cabe.
--
-- NOTA 2 - RETARDO MAS LARGO
--   Un contador de 8 bits da como maximo 255 x 6 = 1530 ciclos (30 us).  Para
--   llegar a decimas de segundo hay que anidar dos contadores, por ejemplo
--   usando R4 como cuenta exterior y el acumulador como cuenta interior.
--   La alternativa limpia es usar Input_dp(7) como bit de "dato listo" y
--   sondearlo con AND + JZ, leyendo numeros de 7 bits por Input_dp(6..0).
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
        0  => "0001000000000",   -- 00  IN          Acc <- Input_dp (primero)
        1  => "0010000000001",   -- 01  STR R1
        2  => "0000101100100",   -- 02  LDI 100     cuenta del retardo
        3  => "0111100000000",   -- 03  DEC         <-- bucle de retardo
        4  => "1101000000011",   -- 04  JNZ 3
        5  => "0001000000000",   -- 05  IN          Acc <- Input_dp (segundo)
        6  => "0010000000010",   -- 06  STR R2
        7  => "0110000000001",   -- 07  ADD R1      Acc <- segundo + primero
        8  => "0010000000011",   -- 08  STR R3      R3  <- suma
        9  => "0001100000000",   -- 09  OUT         OUT_dp <- suma
        10 => "1111100000000",   -- 10  HLT
        others => (others => '0')  -- resto de la memoria: NOP
    );

begin

    -- Lectura puramente combinacional.
    q <= PROGRAMA(to_integer(unsigned(addr)));

end architecture dataflow;
