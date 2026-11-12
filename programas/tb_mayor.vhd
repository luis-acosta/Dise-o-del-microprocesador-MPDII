--------------------------------------------------------------------------------
-- Proyecto : MPDII - Microprocesador didactico de 8 bits
-- Modulo   : tb_mayor  -  Banco de pruebas del programa "cual es el mayor"
--------------------------------------------------------------------------------
-- Compila este banco de pruebas junto con programas/rom256x13_mayor.vhd en
-- lugar de rtl/rom256x13.vhd.
--
-- El programa termina en HLT, asi que cada comparacion necesita su propio
-- reset.  El banco encadena cuatro casos para cubrir las tres ramas:
--
--   A > B      (100, 37)   ->  100
--   A < B      ( 37, 100)  ->  100
--   A = B      ( 64,  64)  ->   64
--   limites    (127,   0)  ->  127
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_mayor is
end entity tb_mayor;

architecture sim of tb_mayor is

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
    constant N     : integer := 4;

    type vect is array (0 to N - 1) of integer;
    constant A_VAL : vect := (100,  37,  64, 127);
    constant B_VAL : vect := ( 37, 100,  64,   0);
    constant ESPER : vect := (100, 100,  64, 127);

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

            -- Margen hasta que termine el retardo, compare y saque el dato
            wait for 400 * T_CLK;

            assert n_salidas > previas
                report "FALLO caso " & integer'image(k) &
                       ": el procesador nunca activo OUT_En"
                severity failure;

            report "A=" & integer'image(A_VAL(k)) &
                   "  B=" & integer'image(B_VAL(k)) &
                   "  ->  mayor = " & integer'image(val(capturado)) &
                   "   (esperado " & integer'image(ESPER(k)) & ")";

            assert val(capturado) = ESPER(k)
                report "FALLO caso " & integer'image(k) &
                       ": se esperaba " & integer'image(ESPER(k)) &
                       " y se obtuvo " & integer'image(val(capturado))
                severity failure;

        end loop;

        report "===========================================";
        report "  PRUEBA SUPERADA: los " & integer'image(N) &
               " casos dieron el mayor correcto";
        report "===========================================";

        fin_sim <= true;
        wait;
    end process ESTIMULOS;

end architecture sim;
