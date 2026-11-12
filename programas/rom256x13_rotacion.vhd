--------------------------------------------------------------------------------
-- Proyecto : MPDII - Microprocesador didactico de 8 bits
-- Modulo   : rom256x13  -  VARIANTE: rotacion de un 1 con salida en cada paso
-- Tipo     : Circuito COMBINACIONAL  ->  descripcion por FLUJO DE DATOS
--------------------------------------------------------------------------------
-- ATENCION: este archivo declara la MISMA entidad que rtl/rom256x13.vhd.
-- Usa uno u otro, nunca los dos a la vez en el mismo proyecto de Quartus.
--------------------------------------------------------------------------------
-- PROGRAMA:  un unico bit en 1 recorre las ocho posiciones del registro R1 y
--            el patron sale por OUT_dp en cada rotacion.  No termina nunca.
--------------------------------------------------------------------------------
-- Registros usados:  R1 = patron que rota
--
-- COMO FUNCIONA
--   La instruccion ROR rota el ACUMULADOR, no el banco de registros, asi que
--   en cada vuelta el patron se trae de R1 al acumulador, se muestra, se rota
--   y se devuelve a R1.  El patron queda guardado en R1 entre vuelta y vuelta.
--
--   La pareja LDI 0 + ADD R1 es la forma de copiar un registro al acumulador:
--   el banco de registros solo alimenta la entrada B de la ALU, de modo que no
--   existe un camino directo de Rn al acumulador.
--
--  Dir  Instruccion   Codificacion         Comentario
--  ---  ------------  -------------------  -------------------------------------
--  00   LDI 1         00001 00000001  101  Acc <- 00000001
--  01   STR R1        00100 00000001  401  R1  <- patron inicial
--  --- BUCLE ---------------------------------------------------------------
--  02   LDI 0         00001 00000000  100  Acc <- 0
--  03   ADD R1        01100 00000001  C01  Acc <- patron guardado en R1
--  04   OUT           00011 00000000  300  OUT_dp <- patron
--  05   ROR           10011 00000000 1300  rotar una posicion a la derecha
--  06   STR R1        00100 00000001  401  R1  <- patron rotado
--  07   JMP 2         11000 00000010 1802  repetir para siempre
--
-- SECUENCIA QUE SALE POR OUT_dp
--   00000001  ->  10000000  ->  01000000  ->  00100000  ->  00010000
--      0x01         0x80         0x40         0x20         0x10
--   ->  00001000  ->  00000100  ->  00000010  ->  00000001  (se repite)
--         0x08         0x04         0x02         0x01
--
--   ROR mueve el bit 0 al bit 7, por eso desde 0x01 el uno salta al extremo
--   opuesto y desde ahi baja posicion a posicion.  El bucle son 6 instrucciones
--   (direcciones 02 a 07), o sea 18 ciclos = 360 ns por rotacion a 50 MHz.
--   La vuelta completa de ocho posiciones dura 144 ciclos, 2,88 us.
--
-- NOTA 1 - VELOCIDAD
--   Cada paso dura 18 ciclos, 360 ns a 50 MHz.  Es perfecto para simulacion o
--   para un analizador logico, pero el ojo no lo ve: en la tarjeta los ocho
--   LED pareceran encendidos a la vez y con poco brillo.  Para verlo hay que
--   insertar un retardo entre las direcciones 06 y 07, por ejemplo:
--        07   LDI 200    00001 11001000  1C8
--        08   DEC        01111 00000000  F00     <-- bucle de retardo
--        09   JNZ 8      11010 00001000 1A08
--        10   JMP 2      11000 00000010 1802
--   Aun asi un contador de 8 bits solo da 30 us; para decimas de segundo hay
--   que anidar dos contadores usando otro registro como cuenta exterior.
--
-- NOTA 2 - SALIDA TRIESTADA
--   OUT_dp solo es valido durante el ciclo en que OUT_En esta activa.  Para
--   sostener el patron en los LED hace falta un registro de salida cargado
--   con OUT_En.
--
-- NOTA 3 - ROTAR HACIA EL OTRO LADO
--   El desplazador no tiene rotacion a la izquierda.  Para que el uno recorra
--   en sentido contrario basta con reemplazar ROR por SHL (10001 00000000) y
--   volver a cargar 1 cuando el acumulador llegue a cero, usando JZ.
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
        0  => "0000100000001",   -- 00  LDI 1       Acc <- 00000001
        1  => "0010000000001",   -- 01  STR R1      patron inicial
        2  => "0000100000000",   -- 02  LDI 0       <-- BUCLE
        3  => "0110000000001",   -- 03  ADD R1      Acc <- patron
        4  => "0001100000000",   -- 04  OUT         mostrar el patron
        5  => "1001100000000",   -- 05  ROR         rotar a la derecha
        6  => "0010000000001",   -- 06  STR R1      guardar el patron rotado
        7  => "1100000000010",   -- 07  JMP 2       repetir
        others => (others => '0')  -- resto de la memoria: NOP
    );

begin

    -- Lectura puramente combinacional.
    q <= PROGRAMA(to_integer(unsigned(addr)));

end architecture dataflow;
