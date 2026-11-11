--------------------------------------------------------------------------------
-- Proyecto : MPDII - Microprocesador didactico de 8 bits
-- Modulo   : regfile16x8  -  Banco de 16 registros de 8 bits
-- Tipo     : Circuito SECUENCIAL  ->  descripcion por COMPORTAMIENTO
--------------------------------------------------------------------------------
-- Un solo puerto de direccion (addr = IR[3:0]) que sirve a la vez para:
--   * escritura sincrona    : en el flanco de clk cuando we = '1'
--   * lectura combinacional : q entrega siempre el contenido de mem(addr),
--                             que alimenta la entrada B de la ALU
--
-- No tiene borrado: el banco arranca en ceros y el programa lo inicializa.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity regfile16x8 is
    port (
        clk  : in  std_logic;
        we   : in  std_logic;                     -- RF_load
        addr : in  std_logic_vector(3 downto 0);  -- RF_Addr = IR[3:0]
        d    : in  std_logic_vector(7 downto 0);  -- BUS Y
        q    : out std_logic_vector(7 downto 0)   -- hacia la entrada B de la ALU
    );
end entity regfile16x8;

architecture behavioral of regfile16x8 is

    type   rf_array is array (0 to 15) of std_logic_vector(7 downto 0);
    signal mem : rf_array := (others => (others => '0'));

begin

    -- Escritura sincrona
    process (clk)
    begin
        if rising_edge(clk) then
            if we = '1' then
                mem(to_integer(unsigned(addr))) <= d;
            end if;
        end if;
    end process;

    -- Lectura combinacional (asincrona)
    q <= mem(to_integer(unsigned(addr)));

end architecture behavioral;
