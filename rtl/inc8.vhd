--------------------------------------------------------------------------------
-- Proyecto : MPDII - Microprocesador didactico de 8 bits
-- Modulo   : inc8  -  Incrementador de 8 bits (+1)
-- Tipo     : Circuito COMBINACIONAL  ->  descripcion por FLUJO DE DATOS
--------------------------------------------------------------------------------
-- Calcula PC + 1 para la ejecucion secuencial del programa.
-- El desbordamiento se descarta: de 255 pasa a 0 (aritmetica modulo 256).
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity inc8 is
    port (
        d : in  std_logic_vector(7 downto 0);
        q : out std_logic_vector(7 downto 0)
    );
end entity inc8;

architecture dataflow of inc8 is
begin

    q <= std_logic_vector(unsigned(d) + 1);

end architecture dataflow;
