--------------------------------------------------------------------------------
-- Proyecto : MPDII - Microprocesador didactico de 8 bits
-- Modulo   : flags  -  Logica de banderas de estado
-- Tipo     : Circuito COMBINACIONAL  ->  descripcion por FLUJO DE DATOS
--------------------------------------------------------------------------------
-- Observa la salida del acumulador y genera las dos banderas que la unidad
-- de control usa para los saltos condicionales:
--
--   Zero_dp     = NOR de los 8 bits  ->  '1' cuando el acumulador vale 0
--   Positive_dp = NOT del bit 7      ->  '1' cuando el acumulador es >= 0
--                                        (complemento a dos)
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity flags is
    port (
        d        : in  std_logic_vector(7 downto 0);  -- salida del acumulador
        zero     : out std_logic;                     -- Zero_dp
        positiv  : out std_logic                      -- Positive_dp
    );
end entity flags;

architecture dataflow of flags is
begin

    -- Compuerta NOR de 8 entradas.
    zero <= not (d(7) or d(6) or d(5) or d(4) or
                 d(3) or d(2) or d(1) or d(0));

    -- Inversor sobre el bit mas significativo (bit de signo).
    positiv <= not d(7);

end architecture dataflow;
