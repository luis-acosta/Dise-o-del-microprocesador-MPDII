--------------------------------------------------------------------------------
-- Proyecto : MPDII - Microprocesador didactico de 8 bits
-- Modulo   : mux2to1_8  -  Multiplexor 2:1 de 8 bits (MUX_PC)
-- Tipo     : Circuito COMBINACIONAL  ->  descripcion por FLUJO DE DATOS
--------------------------------------------------------------------------------
-- Selecciona la proxima direccion del contador de programa:
--   sel = '0'  ->  d0  (PC + 1, ejecucion secuencial)
--   sel = '1'  ->  d1  (IR[7:0], direccion de salto)
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity mux2to1_8 is
    port (
        d0  : in  std_logic_vector(7 downto 0);  -- entrada 0
        d1  : in  std_logic_vector(7 downto 0);  -- entrada 1
        sel : in  std_logic;                     -- INTmux
        y   : out std_logic_vector(7 downto 0)   -- salida
    );
end entity mux2to1_8;

architecture dataflow of mux2to1_8 is
begin

    -- Asignacion condicional concurrente: una sola ecuacion, sin proceso.
    y <= d1 when sel = '1' else d0;

end architecture dataflow;
