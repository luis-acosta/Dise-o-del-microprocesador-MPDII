--------------------------------------------------------------------------------
-- Proyecto : MPDII - Microprocesador didactico de 8 bits
-- Modulo   : alu8  -  Unidad aritmetico-logica de 8 bits
-- Tipo     : Circuito COMBINACIONAL  ->  descripcion por FLUJO DE DATOS
--------------------------------------------------------------------------------
-- Entrada A : salida del acumulador
-- Entrada B : salida del banco de registros
--
--   Sel_ALU | Operacion
--   --------+------------------
--     000   | Pass through A
--     001   | A AND B
--     010   | A OR  B
--     011   | NOT A
--     100   | A + B
--     101   | A - B
--     110   | A + 1
--     111   | A - 1
--
-- La resta se realiza en complemento a dos: el bit 7 del resultado actua como
-- signo y es el que alimenta la bandera Positive_dp.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alu8 is
    port (
        a   : in  std_logic_vector(7 downto 0);  -- acumulador
        b   : in  std_logic_vector(7 downto 0);  -- banco de registros
        sel : in  std_logic_vector(2 downto 0);  -- Sel_ALU
        y   : out std_logic_vector(7 downto 0)
    );
end entity alu8;

architecture dataflow of alu8 is
begin

    with sel select
        y <= a                                           when "000",  -- paso directo
             (a and b)                                   when "001",  -- AND
             (a or  b)                                   when "010",  -- OR
             (not a)                                     when "011",  -- NOT
             std_logic_vector(unsigned(a) + unsigned(b)) when "100",  -- suma
             std_logic_vector(unsigned(a) - unsigned(b)) when "101",  -- resta
             std_logic_vector(unsigned(a) + 1)           when "110",  -- incremento
             std_logic_vector(unsigned(a) - 1)           when others; -- decremento

end architecture dataflow;
