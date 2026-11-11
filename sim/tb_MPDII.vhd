--------------------------------------------------------------------------------
-- Proyecto : MPDII - Microprocesador didactico de 8 bits
-- Modulo   : tb_MPDII  -  Banco de pruebas del sistema completo
--------------------------------------------------------------------------------
-- Aplica reloj y reset, deja correr el programa de division cargado en la ROM
-- (15 / 3) y captura el valor que el microprocesador entrega por OUT_dp.
--
-- Como OUT_dp proviene de un buffer triestado, el valor solo esta presente
-- durante el ciclo en que la unidad de control activa OUT_En.  El proceso
-- CAPTURA lo retiene para poder comprobarlo al final.
--
-- Resultado esperado:  OUT_dp = x"05"
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_MPDII is
end entity tb_MPDII;

architecture sim of tb_MPDII is

    component MPDII is
        port (clk      : in  std_logic;
              reset    : in  std_logic;
              Input_dp : in  std_logic_vector(7 downto 0);
              OUT_dp   : out std_logic_vector(7 downto 0));
    end component;

    constant T_CLK : time := 20 ns;          -- 50 MHz

    signal clk      : std_logic := '0';
    signal reset    : std_logic := '1';
    signal Input_dp : std_logic_vector(7 downto 0) := (others => '0');
    signal OUT_dp   : std_logic_vector(7 downto 0);

    signal capturado : std_logic_vector(7 downto 0) := (others => '0');
    signal n_salidas : integer := 0;
    signal fin_sim   : boolean := false;

begin

    ----------------------------------------------------------------------------
    -- Unidad bajo prueba
    ----------------------------------------------------------------------------
    UUT : MPDII
        port map (clk => clk, reset => reset,
                  Input_dp => Input_dp, OUT_dp => OUT_dp);

    ----------------------------------------------------------------------------
    -- Generador de reloj
    ----------------------------------------------------------------------------
    RELOJ : process
    begin
        while not fin_sim loop
            clk <= '0';  wait for T_CLK / 2;
            clk <= '1';  wait for T_CLK / 2;
        end loop;
        wait;
    end process RELOJ;

    ----------------------------------------------------------------------------
    -- Captura del dato de salida mientras el buffer esta habilitado
    ----------------------------------------------------------------------------
    CAPTURA : process (clk)
    begin
        if rising_edge(clk) then
            if OUT_dp /= "ZZZZZZZZ" then
                capturado <= OUT_dp;
                n_salidas <= n_salidas + 1;
                report "OUT_dp = " & integer'image(to_integer(unsigned(OUT_dp)));
            end if;
        end if;
    end process CAPTURA;

    ----------------------------------------------------------------------------
    -- Estimulos y comprobacion
    ----------------------------------------------------------------------------
    ESTIMULOS : process
    begin
        -- Reset asincrono durante dos ciclos completos
        reset <= '1';
        wait for 3 * T_CLK;
        reset <= '0';

        -- El programa necesita 64 instrucciones x 3 ciclos = 192 ciclos.
        -- Se dejan 260 ciclos de margen.
        wait for 260 * T_CLK;

        ------------------------------------------------------------------------
        -- Comprobaciones
        ------------------------------------------------------------------------
        assert n_salidas > 0
            report "FALLO: el microprocesador nunca activo OUT_En"
            severity failure;

        assert capturado = x"05"
            report "FALLO: 15/3 debia dar 5 y se obtuvo " &
                   integer'image(to_integer(unsigned(capturado)))
            severity failure;

        report "===========================================";
        report "  PRUEBA SUPERADA:  15 / 3 = " &
               integer'image(to_integer(unsigned(capturado)));
        report "===========================================";

        fin_sim <= true;
        wait;
    end process ESTIMULOS;

end architecture sim;
