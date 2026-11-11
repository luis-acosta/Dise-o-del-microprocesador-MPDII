--------------------------------------------------------------------------------
-- Proyecto : MPDII - Microprocesador didactico de 8 bits
-- Modulo   : reg8  -  Registro de 8 bits con carga sincrona y borrado asincrono
-- Tipo     : Circuito SECUENCIAL  ->  descripcion por COMPORTAMIENTO
--------------------------------------------------------------------------------
-- Se instancia dos veces en la unidad de datos:
--   U_PC   -> contador de programa   (load = PCload)
--   U_ACC  -> acumulador             (load = Acc_Load)
--
-- Comportamiento:
--   clr = '1'            -> q se borra inmediatamente (asincrono)
--   flanco de subida de clk con load = '1'  -> q toma el valor de d
--   en cualquier otro caso q conserva su valor
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity reg8 is
    port (
        clk  : in  std_logic;
        clr  : in  std_logic;                     -- Reset global
        load : in  std_logic;                     -- habilitacion de carga
        d    : in  std_logic_vector(7 downto 0);
        q    : out std_logic_vector(7 downto 0)
    );
end entity reg8;

architecture behavioral of reg8 is
begin

    process (clk, clr)
    begin
        if clr = '1' then
            q <= (others => '0');
        elsif rising_edge(clk) then
            if load = '1' then
                q <= d;
            end if;
        end if;
    end process;

end architecture behavioral;
