--------------------------------------------------------------------------------
-- Proyecto : MPDII - Microprocesador didactico de 8 bits
-- Modulo   : tb_rotacion  -  Banco de pruebas del programa de rotacion
--------------------------------------------------------------------------------
-- Compila este banco de pruebas junto con programas/rom256x13_rotacion.vhd en
-- lugar de rtl/rom256x13.vhd.
--
-- Captura cada valor que el procesador saca por OUT_dp y comprueba que
-- recorre las ocho posiciones del bit en el orden que produce ROR:
--
--   0x01, 0x80, 0x40, 0x20, 0x10, 0x08, 0x04, 0x02, y vuelta a empezar.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_rotacion is
end entity tb_rotacion;

architecture sim of tb_rotacion is

    component MPDII is
        port (clk          : in  std_logic;
              reset        : in  std_logic;
              Input_dp     : in  std_logic_vector(7 downto 0);
              OUT_dp       : out std_logic_vector(7 downto 0);
              TEST_PC      : out std_logic_vector(7 downto 0);
              TEST_ROM     : out std_logic_vector(12 downto 0);
              TEST_COP     : out std_logic_vector(4 downto 0);
              TEST_Mux_dp  : out std_logic_vector(7 downto 0);
              TEST_Acc     : out std_logic_vector(7 downto 0);
              TEST_RF      : out std_logic_vector(7 downto 0);
              TEST_ALU     : out std_logic_vector(7 downto 0);
              TEST_Shifter : out std_logic_vector(7 downto 0);
              TEST_Zero_dp : out std_logic;
              TEST_OUT_En  : out std_logic);
    end component;

    constant T_CLK : time := 20 ns;          -- 50 MHz

    -- Secuencia esperada: una vuelta completa mas el primer valor de la segunda
    type patron_array is array (0 to 8) of integer;
    constant ESPERADO : patron_array :=
        (16#01#, 16#80#, 16#40#, 16#20#, 16#10#, 16#08#, 16#04#, 16#02#, 16#01#);

    signal clk      : std_logic := '0';
    signal reset    : std_logic := '1';
    signal Input_dp : std_logic_vector(7 downto 0) := (others => '0');
    signal OUT_dp   : std_logic_vector(7 downto 0);

    signal TEST_PC      : std_logic_vector(7 downto 0);
    signal TEST_ROM     : std_logic_vector(12 downto 0);
    signal TEST_COP     : std_logic_vector(4 downto 0);
    signal TEST_Mux_dp  : std_logic_vector(7 downto 0);
    signal TEST_Acc     : std_logic_vector(7 downto 0);
    signal TEST_RF      : std_logic_vector(7 downto 0);
    signal TEST_ALU     : std_logic_vector(7 downto 0);
    signal TEST_Shifter : std_logic_vector(7 downto 0);
    signal TEST_Zero_dp : std_logic;
    signal TEST_OUT_En  : std_logic;

    signal n_salidas : integer := 0;
    signal errores   : integer := 0;
    signal fin_sim   : boolean := false;

    function val (v : std_logic_vector) return integer is
    begin
        if Is_X(v) then return -1; else return to_integer(unsigned(v)); end if;
    end function val;

    -- Imprime un vector de 8 bits en binario, para ver el uno moverse.
    function bin (v : std_logic_vector(7 downto 0)) return string is
        variable r : string(1 to 8);
    begin
        for i in 0 to 7 loop
            if v(7 - i) = '1' then r(i + 1) := '1'; else r(i + 1) := '0'; end if;
        end loop;
        return r;
    end function bin;

begin

    UUT : MPDII
        port map (clk          => clk,
                  reset        => reset,
                  Input_dp     => Input_dp,
                  OUT_dp       => OUT_dp,
                  TEST_PC      => TEST_PC,
                  TEST_ROM     => TEST_ROM,
                  TEST_COP     => TEST_COP,
                  TEST_Mux_dp  => TEST_Mux_dp,
                  TEST_Acc     => TEST_Acc,
                  TEST_RF      => TEST_RF,
                  TEST_ALU     => TEST_ALU,
                  TEST_Shifter => TEST_Shifter,
                  TEST_Zero_dp => TEST_Zero_dp,
                  TEST_OUT_En  => TEST_OUT_En);

    RELOJ : process
    begin
        while not fin_sim loop
            clk <= '0';  wait for T_CLK / 2;
            clk <= '1';  wait for T_CLK / 2;
        end loop;
        wait;
    end process RELOJ;

    ----------------------------------------------------------------------------
    -- Captura y comprobacion de cada salida
    ----------------------------------------------------------------------------
    CAPTURA : process (clk)
    begin
        if rising_edge(clk) then
            if TEST_OUT_En = '1' and OUT_dp /= "ZZZZZZZZ" then
                if n_salidas <= ESPERADO'high then
                    report "rotacion " & integer'image(n_salidas) &
                           ":  OUT_dp = " & bin(OUT_dp) &
                           "   = " & integer'image(val(OUT_dp)) & " decimal";
                    if val(OUT_dp) /= ESPERADO(n_salidas) then
                        report "   FALLO: se esperaba " &
                               integer'image(ESPERADO(n_salidas))
                            severity error;
                        errores <= errores + 1;
                    end if;
                end if;
                n_salidas <= n_salidas + 1;
            end if;
        end if;
    end process CAPTURA;

    ESTIMULOS : process
    begin
        reset <= '1';
        wait for 3 * T_CLK;
        reset <= '0';

        -- Cada rotacion ocupa 18 ciclos; se dejan correr unas catorce.
        wait for 260 * T_CLK;

        assert n_salidas > ESPERADO'high
            report "FALLO: solo hubo " & integer'image(n_salidas) & " salidas"
            severity failure;

        assert errores = 0
            report "FALLO: la secuencia de rotacion no es la esperada"
            severity failure;

        report "===========================================";
        report "  PRUEBA SUPERADA: el 1 recorrio las 8 posiciones";
        report "  salidas observadas: " & integer'image(n_salidas);
        report "===========================================";

        fin_sim <= true;
        wait;
    end process ESTIMULOS;

end architecture sim;
