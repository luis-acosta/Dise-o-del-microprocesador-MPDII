--------------------------------------------------------------------------------
-- Proyecto : MPDII - Microprocesador didactico de 8 bits
-- Modulo   : tb_suma  -  Banco de pruebas del programa "suma de dos numeros"
--------------------------------------------------------------------------------
-- Compila este banco de pruebas junto con programas/rom256x13_suma.vhd en
-- lugar de rtl/rom256x13.vhd.
--
-- Presenta el primer sumando en Input_dp, espera a que el procesador lo lea,
-- cambia la entrada al segundo sumando durante el bucle de retardo y comprueba
-- que OUT_dp entrega la suma.
--
--   primer numero  = 25
--   segundo numero = 17
--   resultado esperado = 42  (x"2A")
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_suma is
end entity tb_suma;

architecture sim of tb_suma is

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

    constant NUM_A : integer := 25;          -- primer sumando
    constant NUM_B : integer := 17;          -- segundo sumando

    signal clk      : std_logic := '0';
    signal reset    : std_logic := '1';
    signal Input_dp : std_logic_vector(7 downto 0) := std_logic_vector(to_unsigned(NUM_A, 8));
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

    function img (v : std_logic_vector) return string is
    begin
        return integer'image(val(v));
    end function img;

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
    -- Avisa cada vez que el procesador ejecuta una instruccion IN
    ----------------------------------------------------------------------------
    VIGILA_IN : process (clk)
    begin
        if rising_edge(clk) then
            if TEST_COP = "00010" and not Is_X(Input_dp) then
                report "IN  leyendo Input_dp = " & img(Input_dp);
            end if;
        end if;
    end process VIGILA_IN;

    CAPTURA : process (clk)
    begin
        if rising_edge(clk) then
            if TEST_OUT_En = '1' and OUT_dp /= "ZZZZZZZZ" then
                capturado <= OUT_dp;
                n_salidas <= n_salidas + 1;
                report ">>> OUT_dp = " & img(OUT_dp);
            end if;
        end if;
    end process CAPTURA;

    ESTIMULOS : process
    begin
        -- Primer sumando presente desde el arranque
        Input_dp <= std_logic_vector(to_unsigned(NUM_A, 8));
        reset <= '1';
        wait for 3 * T_CLK;
        reset <= '0';

        -- El procesador lee el primer numero y entra al bucle de retardo,
        -- que dura unos 12 us.  Se cambia la entrada a mitad de esa ventana.
        wait for 300 * T_CLK;                       -- 6 us
        report "--- cambiando Input_dp a " & integer'image(NUM_B) & " ---";
        Input_dp <= std_logic_vector(to_unsigned(NUM_B, 8));

        -- Margen hasta que termine el retardo y ejecute la suma
        wait for 500 * T_CLK;

        assert n_salidas > 0
            report "FALLO: el microprocesador nunca activo OUT_En"
            severity failure;

        assert capturado = std_logic_vector(to_unsigned(NUM_A + NUM_B, 8))
            report "FALLO: " & integer'image(NUM_A) & " + " & integer'image(NUM_B) &
                   " debia dar " & integer'image(NUM_A + NUM_B) &
                   " y se obtuvo " & img(capturado)
            severity failure;

        report "===========================================";
        report "  PRUEBA SUPERADA:  " & integer'image(NUM_A) & " + " &
               integer'image(NUM_B) & " = " & img(capturado);
        report "===========================================";

        fin_sim <= true;
        wait;
    end process ESTIMULOS;

end architecture sim;
