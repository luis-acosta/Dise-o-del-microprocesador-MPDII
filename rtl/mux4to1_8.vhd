--------------------------------------------------------------------------------
-- Proyecto : MPDII - Microprocesador didactico de 8 bits
-- Modulo   : mux4to1_8  -  Multiplexor 4:1 de 8 bits (MUX_Y)
-- Tipo     : Circuito COMBINACIONAL  ->  descripcion por FLUJO DE DATOS
--------------------------------------------------------------------------------
-- Selecciona la fuente del BUS Y, que alimenta al acumulador, al banco de
-- registros y al buffer triestado de salida:
--   "00" -> d0 : Input_dp    (dato externo)
--   "01" -> d1 : Shifter     (resultado desplazado)
--   "10" -> d2 : ALU         (resultado aritmetico-logico)
--   "11" -> d3 : IR[7:0]     (dato inmediato de la instruccion)
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity mux4to1_8 is
    port (
        d0  : in  std_logic_vector(7 downto 0);
        d1  : in  std_logic_vector(7 downto 0);
        d2  : in  std_logic_vector(7 downto 0);
        d3  : in  std_logic_vector(7 downto 0);
        sel : in  std_logic_vector(1 downto 0);  -- Muxsel_dp
        y   : out std_logic_vector(7 downto 0)
    );
end entity mux4to1_8;

architecture dataflow of mux4to1_8 is
begin

    -- Asignacion concurrente seleccionada.
    with sel select
        y <= d0 when "00",
             d1 when "01",
             d2 when "10",
             d3 when others;

end architecture dataflow;
