--------------------------------------------------------------------------------
-- Proyecto : MPDII - Microprocesador didactico de 8 bits
-- Modulo   : tb_multiplica  -  Banco de pruebas del programa de multiplicacion
--------------------------------------------------------------------------------
-- Compila este banco de pruebas junto con programas/rom256x13_multiplica.vhd en
-- lugar de rtl/rom256x13.vhd.
--
-- El programa termina en HLT, asi que cada producto necesita su propio reset.
-- El banco encadena cinco casos:
--
--   12 x  7  ->   84    caso tipico
--    5 x  3  ->   15    numeros pequenos
--    0 x  9  ->    0    multiplicando nulo
--    9 x  0  ->    0    multiplicador nulo: el bucle no se ejecuta
--   15 x 17  ->  255    el producto mas grande que cabe en 8 bits
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_multiplica is
end entity tb_multiplica;

architecture sim of tb_multiplica is

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
    constant N     : integer := 5;

    type vect is array (0 to N - 1) of integer;
    constant A_VAL : vect := ( 12,   5,   0,   9,  15);
    constant B_VAL : vect := (  7,   3,   9,   0,  17);
    constant ESPER : vect := ( 84,  15,   0,   0, 255);

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

    signal capturado : std_logic_vector(7 downto 0) := (others => '0');
    signal n_salidas : integer := 0;
    signal fin_sim   : boolean := false;

    function val (v : std_logic_vector) return integer is
    begin
        if Is_X(v) then return -1; else return to_integer(unsigned(v)); end if;
    end function val;

    function slv8 (x : integer) return std_logic_vector is
    begin
        return std_logic_vector(to_unsigned(x, 8));
    end function slv8;

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

    CAPTURA : process (clk)
    begin
        if rising_edge(clk) then
            if TEST_OUT_En = '1' and OUT_dp /= "ZZZZZZZZ" then
                capturado <= OUT_dp;
                n_salidas <= n_salidas + 1;
            end if;
        end if;
    end process CAPTURA;

    ESTIMULOS : process
        variable previas : integer;
    begin
        for k in 0 to N - 1 loop

            -- Primer numero presente antes de soltar el reset
            Input_dp <= slv8(A_VAL(k));
            reset    <= '1';
            wait for 3 * T_CLK;
            previas := n_salidas;
            reset    <= '0';

            -- El procesador lee A y entra al bucle de retardo (unos 12 us).
            -- Se cambia la entrada a mitad de esa ventana.
            wait for 300 * T_CLK;
            Input_dp <= slv8(B_VAL(k));

            -- Margen hasta que termine el retardo, multiplique y saque el dato.
            -- El bucle son 30 ciclos por vuelta y el peor caso son 17 vueltas.
            wait for 1200 * T_CLK;

            assert n_salidas > previas
                report "FALLO caso " & integer'image(k) &
                       ": el procesador nunca activo OUT_En"
                severity failure;

            report integer'image(A_VAL(k)) & " x " & integer'image(B_VAL(k)) &
                   "  =  " & integer'image(val(capturado)) &
                   "   (esperado " & integer'image(ESPER(k)) & ")";

            assert val(capturado) = ESPER(k)
                report "FALLO caso " & integer'image(k) &
                       ": se esperaba " & integer'image(ESPER(k)) &
                       " y se obtuvo " & integer'image(val(capturado))
                severity failure;

        end loop;

        report "===========================================";
        report "  PRUEBA SUPERADA: los " & integer'image(N) &
               " productos son correctos";
        report "===========================================";

        fin_sim <= true;
        wait;
    end process ESTIMULOS;

end architecture sim;
