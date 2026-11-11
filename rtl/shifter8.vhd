--------------------------------------------------------------------------------
-- Proyecto : MPDII - Microprocesador didactico de 8 bits
-- Modulo   : shifter8  -  Desplazador de 8 bits
-- Tipo     : Circuito COMBINACIONAL  ->  descripcion por FLUJO DE DATOS
--------------------------------------------------------------------------------
-- Recibe el resultado de la ALU y lo entrega desplazado al MUX_Y.
--
--   Sel_Shift | Operacion
--   ----------+-------------------------------
--      00     | Pass through
--      01     | Shift left  y rellena con 0
--      10     | Shift right y rellena con 0
--      11     | Rotate right
--
-- El desplazamiento se construye por reordenamiento de bits (concatenacion),
-- no requiere logica aritmetica.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity shifter8 is
    port (
        d   : in  std_logic_vector(7 downto 0);  -- salida de la ALU
        sel : in  std_logic_vector(1 downto 0);  -- Sel_Shift
        y   : out std_logic_vector(7 downto 0)
    );
end entity shifter8;

architecture dataflow of shifter8 is
begin

    with sel select
        y <= d                      when "00",   -- paso directo
             d(6 downto 0) & '0'    when "01",   -- izquierda, entra 0 por el LSB
             '0' & d(7 downto 1)    when "10",   -- derecha,   entra 0 por el MSB
             d(0) & d(7 downto 1)   when others; -- rotacion derecha: LSB -> MSB

end architecture dataflow;
