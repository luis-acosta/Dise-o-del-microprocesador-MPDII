--------------------------------------------------------------------------------
-- Proyecto : MPDII - Microprocesador didactico de 8 bits
-- Modulo   : tb_mult_shift  -  Banco de pruebas del multiplicador de 16 bits
--------------------------------------------------------------------------------
-- Compila este banco junto con programas/rom256x13_mult_shift.vhd en lugar de
-- rtl/rom256x13.vhd.
--
-- El programa saca DOS valores por OUT_dp: primero la parte alta y despues la
-- parte baja.  El banco captura las dos, recompone el producto de 16 bits y lo
-- compara con A x B.
--
-- Casos:
--     12 x   7  ->     84    cabe en 8 bits
--    100 x 200  ->  20000    producto grande, usa las dos mitades
--    127 x 255  ->  32385    el maximo con A limitado a 127
--      0 x  99  ->      0    multiplicando nulo
--     37 x   0  ->      0    multiplicador nulo
--      1 x 255  ->    255    justo en el limite de la parte baja
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_mult_shift is
end entity tb_mult_shift;

architecture sim of tb_mult_shift is

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
    constant N     : integer := 6;

    type vect is array (0 to N - 1) of integer;
    constant A_VAL : vect := ( 12, 100, 127,   0,  37,   1);
    constant B_VAL : vect := (  7, 200, 255,  99,   0, 255);

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

    -- Las dos mitades, en el orden en que el programa las saca.
    -- Las escribe SOLO el proceso CAPTURA: en VHDL un signal no puede tener
    -- dos drivers.  ESTIMULOS avisa del cambio de corrida con 'corrida'.
    signal parte_alta : integer := -1;
    signal parte_baja : integer := -1;
    signal corrida    : integer := -1;
    signal n_salidas  : integer := 0;
    signal fin_sim    : boolean := false;

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

    ----------------------------------------------------------------------------
    -- La primera salida de cada corrida es la parte alta, la segunda la baja
    ----------------------------------------------------------------------------
    CAPTURA : process (clk)
        variable ult : integer := -1;   -- ultima corrida vista
        variable idx : integer := 0;    -- cuantas salidas van en esta corrida
    begin
        if rising_edge(clk) then
            -- al empezar una corrida nueva se limpian las capturas
            if corrida /= ult then
                ult := corrida;
                idx := 0;
                parte_alta <= -1;
                parte_baja <= -1;
            end if;
            if TEST_OUT_En = '1' and OUT_dp /= "ZZZZZZZZ" then
                if idx = 0 then
                    parte_alta <= val(OUT_dp);
                else
                    parte_baja <= val(OUT_dp);
                end if;
                idx := idx + 1;
                n_salidas <= n_salidas + 1;
            end if;
        end if;
    end process CAPTURA;

    ESTIMULOS : process
        variable esperado : integer;
        variable obtenido : integer;
    begin
        for k in 0 to N - 1 loop

            -- avisar a CAPTURA de que empieza una corrida nueva
            corrida    <= k;
            Input_dp   <= slv8(A_VAL(k));
            reset      <= '1';
            wait for 3 * T_CLK;
            reset      <= '0';

            -- el procesador lee A y entra al retardo; se cambia la entrada
            wait for 300 * T_CLK;
            Input_dp <= slv8(B_VAL(k));

            -- ocho vueltas de unos 31 instrucciones, mas el retardo
            wait for 1500 * T_CLK;

            assert parte_alta >= 0 and parte_baja >= 0
                report "FALLO caso " & integer'image(k) &
                       ": no llegaron las dos mitades"
                severity failure;

            esperado := A_VAL(k) * B_VAL(k);
            obtenido := parte_alta * 256 + parte_baja;

            report integer'image(A_VAL(k)) & " x " & integer'image(B_VAL(k)) &
                   "  ->  alta=" & integer'image(parte_alta) &
                   "  baja=" & integer'image(parte_baja) &
                   "  =  " & integer'image(obtenido) &
                   "   (esperado " & integer'image(esperado) & ")";

            assert obtenido = esperado
                report "FALLO caso " & integer'image(k) &
                       ": se esperaba " & integer'image(esperado) &
                       " y se obtuvo " & integer'image(obtenido)
                severity failure;

        end loop;

        report "===========================================";
        report "  PRUEBA SUPERADA: los " & integer'image(N) &
               " productos de 16 bits son correctos";
        report "===========================================";

        fin_sim <= true;
        wait;
    end process ESTIMULOS;

end architecture sim;
