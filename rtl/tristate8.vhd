--------------------------------------------------------------------------------
-- Proyecto : MPDII - Microprocesador didactico de 8 bits
-- Modulo   : tristate8  -  Buffer triestado de salida de 8 bits
-- Tipo     : Circuito COMBINACIONAL  ->  descripcion por FLUJO DE DATOS
--------------------------------------------------------------------------------
-- Conecta el BUS Y con el puerto OUT_dp del microprocesador.
-- Con en = '0' la salida queda en alta impedancia, de modo que el valor solo
-- es valido durante el estado S4 (ejecucion de la instruccion OUT).
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity tristate8 is
    port (
        d  : in  std_logic_vector(7 downto 0);  -- BUS Y
        en : in  std_logic;                     -- OUT_En
        y  : out std_logic_vector(7 downto 0)   -- OUT_dp
    );
end entity tristate8;

architecture dataflow of tristate8 is
begin

    y <= d when en = '1' else "ZZZZZZZZ";

end architecture dataflow;
