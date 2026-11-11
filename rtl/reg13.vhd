--------------------------------------------------------------------------------
-- Proyecto : MPDII - Microprocesador didactico de 8 bits
-- Modulo   : reg13  -  Registro de instruccion (IR), 13 bits
-- Tipo     : Circuito SECUENCIAL  ->  descripcion por COMPORTAMIENTO
--------------------------------------------------------------------------------
-- Captura la palabra de instruccion entregada por la ROM durante el estado
-- de busqueda S0 (load = IRload).  El contenido se reparte asi:
--   q(12 downto 8) -> codigo de operacion (COP) hacia la unidad de control
--   q(7  downto 0) -> operando: direccion de salto, constante o registro
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity reg13 is
    port (
        clk  : in  std_logic;
        clr  : in  std_logic;                      -- Reset global
        load : in  std_logic;                      -- IRload
        d    : in  std_logic_vector(12 downto 0);  -- salida de la ROM
        q    : out std_logic_vector(12 downto 0)
    );
end entity reg13;

architecture behavioral of reg13 is
begin

    process (clk, clr)
    begin
        if clr = '1' then
            q <= (others => '0');          -- tras el reset el IR contiene NOP
        elsif rising_edge(clk) then
            if load = '1' then
                q <= d;
            end if;
        end if;
    end process;

end architecture behavioral;
