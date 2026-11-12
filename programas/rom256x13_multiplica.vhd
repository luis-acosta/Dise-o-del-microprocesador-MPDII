--------------------------------------------------------------------------------
-- Proyecto : MPDII - Microprocesador didactico de 8 bits
-- Modulo   : rom256x13  -  VARIANTE: multiplicacion de dos numeros
-- Tipo     : Circuito COMBINACIONAL  ->  descripcion por FLUJO DE DATOS
--------------------------------------------------------------------------------
-- ATENCION: este archivo declara la MISMA entidad que rtl/rom256x13.vhd.
-- Usa uno u otro, nunca los dos a la vez en el mismo proyecto de Quartus.
--------------------------------------------------------------------------------
-- PROGRAMA:  lee dos numeros por Input_dp y saca por OUT_dp su producto.
--------------------------------------------------------------------------------
-- Registros usados:  R1 = multiplicando   R2 = contador   R3 = producto
--
-- ALGORITMO: MULTIPLICACION POR SUMAS SUCESIVAS
--   La ALU no multiplica, asi que el producto se construye sumando el
--   multiplicando tantas veces como indique el multiplicador:
--
--       producto = 0
--       mientras contador /= 0:
--           contador = contador - 1
--           producto = producto + multiplicando
--
--   Es el espejo del programa de division, que restaba hasta cruzar el cero.
--   La bandera Zero_dp es la que detecta el final del bucle.
--
--  Dir  Instruccion   Codificacion         Comentario
--  ---  ------------  -------------------  -------------------------------------
--  00   IN            00010 00000000  200  Acc <- Input_dp  (multiplicando A)
--  01   STR R1        00100 00000001  401  R1  <- A
--  --- RETARDO: ventana para cambiar Input_dp ------------------------------
--  02   LDI 100       00001 01100100  164  Acc <- 100
--  03   DEC           01111 00000000  F00  Acc <- Acc - 1    <-- bucle
--  04   JNZ 3         11010 00000011 1A03  repetir mientras Acc /= 0
--  --- SEGUNDA LECTURA E INICIALIZACION ------------------------------------
--  05   IN            00010 00000000  200  Acc <- Input_dp  (multiplicador B)
--  06   STR R2        00100 00000010  402  R2  <- B  (contador)
--  07   LDI 0         00001 00000000  100  Acc <- 0
--  08   STR R3        00100 00000011  403  R3  <- 0  (producto)
--  --- BUCLE DE SUMAS ------------------------------------------------------
--  09   LDI 0         00001 00000000  100  Acc <- 0          <-- BUCLE
--  10   ADD R2        01100 00000010  C02  Acc <- contador
--  11   JZ  19        11001 00010011 1913  si contador = 0 -> FIN
--  12   DEC           01111 00000000  F00  Acc <- contador - 1
--  13   STR R2        00100 00000010  402  guardar el contador
--  14   LDI 0         00001 00000000  100  Acc <- 0
--  15   ADD R3        01100 00000011  C03  Acc <- producto
--  16   ADD R1        01100 00000001  C01  Acc <- producto + A
--  17   STR R3        00100 00000011  403  guardar el producto
--  18   JMP 9         11000 00001001 1809  repetir
--  --- FIN -----------------------------------------------------------------
--  19   LDI 0         00001 00000000  100  Acc <- 0
--  20   ADD R3        01100 00000011  C03  Acc <- producto
--  21   OUT           00011 00000000  300  OUT_dp <- producto
--  22   HLT           11111 00000000 1F00  detener
--
-- EJEMPLO DE TRAZA  (A = 12, B = 7)
--   contador 7 6 5 4 3 2 1 0
--   producto 0 12 24 36 48 60 72 84   ->  OUT_dp = 84
--
--------------------------------------------------------------------------------
-- NOTA 1 - DESBORDAMIENTO: EL PRODUCTO DEBE CABER EN 8 BITS
--   La ALU trabaja modulo 256 y no hay bandera de acarreo, asi que el
--   resultado solo es correcto si A x B <= 255.  Con 20 x 20 = 400 el
--   procesador entregaria 144, que es 400 - 256, sin ninguna senal de error.
--   Para productos mayores haria falta un resultado de 16 bits, es decir dos
--   registros y un algoritmo que propague el acarreo a mano.
--
-- NOTA 2 - CUANTO TARDA
--   Cada vuelta del bucle son 10 instrucciones, o sea 30 ciclos.  El tiempo
--   total crece con el MULTIPLICADOR, no con el multiplicando: B = 7 tarda
--   210 ciclos y B = 200 tarda 6000.  Conviene cargar el numero mas pequeno
--   como segundo operando.
--
-- NOTA 3 - VERSION RAPIDA
--   El metodo clasico de desplazar y sumar daria siempre ocho vueltas en vez
--   de B, usando SHL para correr el multiplicando y revisando bit a bit el
--   multiplicador con AND.  Es mas rapido pero bastante mas largo de escribir,
--   y para un multiplicador pequeno las sumas sucesivas ganan.
--
-- NOTA - LECTURA DE DOS NUMEROS
--   La instruccion IN captura lo que haya en Input_dp en ese instante y no hay
--   senal de "dato listo", por eso el bucle de retardo de las direcciones 02 a
--   04 abre una ventana de unos 12 us para cambiar el valor de la entrada.
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
        6  => "0010000000010",   -- 06  STR R2      contador
        7  => "0000100000000",   -- 07  LDI 0
        8  => "0010000000011",   -- 08  STR R3      producto <- 0
        9  => "0000100000000",   -- 09  LDI 0       <-- BUCLE DE SUMAS
        10 => "0110000000010",   -- 10  ADD R2      Acc <- contador
        11 => "1100100010011",   -- 11  JZ  19      si contador = 0 -> FIN
        12 => "0111100000000",   -- 12  DEC         contador - 1
        13 => "0010000000010",   -- 13  STR R2
        14 => "0000100000000",   -- 14  LDI 0
        15 => "0110000000011",   -- 15  ADD R3      Acc <- producto
        16 => "0110000000001",   -- 16  ADD R1      Acc <- producto + A
        17 => "0010000000011",   -- 17  STR R3      guardar el producto
        18 => "1100000001001",   -- 18  JMP 9       repetir
        19 => "0000100000000",   -- 19  LDI 0       <-- FIN
        20 => "0110000000011",   -- 20  ADD R3      Acc <- producto
        21 => "0001100000000",   -- 21  OUT         OUT_dp <- producto
        22 => "1111100000000",   -- 22  HLT
        others => (others => '0')  -- resto de la memoria: NOP
    );

begin

    -- Lectura puramente combinacional.
    q <= PROGRAMA(to_integer(unsigned(addr)));

end architecture dataflow;
