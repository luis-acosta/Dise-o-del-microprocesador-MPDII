--------------------------------------------------------------------------------
-- Proyecto : MPDII - Microprocesador didactico de 8 bits
-- Modulo   : tb_saltos  -  Banco de pruebas del autodiagnostico de saltos
--------------------------------------------------------------------------------
-- Compila este banco junto con programas/rom256x13_saltos.vhd en lugar de
-- rtl/rom256x13.vhd.
--
-- El programa no necesita entradas: fabrica sus propias condiciones con LDI.
-- El banco comprueba que la secuencia que sale por OUT_dp sea exactamente
--
--     1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 170
--
-- Si aparece un 238 (0xEE) alguna prueba fallo, y el numero de la ultima
-- marca correcta dice cual.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_saltos is
end entity tb_saltos;

architecture sim of tb_saltos is

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
    constant NMARCAS : integer := 11;

    type marca_array is array (0 to NMARCAS - 1) of integer;
    constant ESPERADO : marca_array := (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 170);

    type nombre_array is array (0 to NMARCAS - 1) of string(1 to 34);
    constant QUE_PRUEBA : nombre_array := (
        "JMP incondicional                 ",
        "JZ  con Acc=0   debe saltar       ",
        "JZ  con Acc=5   NO debe saltar    ",
        "JNZ con Acc=5   debe saltar       ",
        "JNZ con Acc=0   NO debe saltar    ",
        "JP  con Acc=5   debe saltar       ",
        "JP  con Acc=200 NO debe saltar    ",
        "JN  con Acc=200 debe saltar       ",
        "JN  con Acc=5   NO debe saltar    ",
        "JNZ hacia atras (bucle)           ",
        "FIN: todas las pruebas pasaron    ");

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

    signal n_marcas : integer := 0;
    signal errores  : integer := 0;
    signal fin_sim  : boolean := false;

    function val (v : std_logic_vector) return integer is
    begin
        if Is_X(v) then return -1; else return to_integer(unsigned(v)); end if;
    end function val;

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
    -- Cada salida es la marca de una prueba superada
    ----------------------------------------------------------------------------
    CAPTURA : process (clk)
    begin
        if rising_edge(clk) then
            if TEST_OUT_En = '1' and OUT_dp /= "ZZZZZZZZ" then
                if val(OUT_dp) = 238 then
                    report "0xEE: el programa salto al manejador de error" severity error;
                    errores <= errores + 1;
                elsif n_marcas < NMARCAS then
                    if val(OUT_dp) = ESPERADO(n_marcas) then
                        report "ok  marca " & integer'image(val(OUT_dp)) &
                               "   " & QUE_PRUEBA(n_marcas);
                    else
                        report "FALLO: se esperaba la marca " &
                               integer'image(ESPERADO(n_marcas)) & " y llego " &
                               integer'image(val(OUT_dp)) severity error;
                        errores <= errores + 1;
                    end if;
                else
                    report "FALLO: marca de mas, " & integer'image(val(OUT_dp))
                        severity error;
                    errores <= errores + 1;
                end if;
                n_marcas <= n_marcas + 1;
            end if;
        end if;
    end process CAPTURA;

    ESTIMULOS : process
    begin
        reset <= '1';
        wait for 3 * T_CLK;
        reset <= '0';

        -- El programa entero son unas 50 instrucciones; sobra con 300 ciclos.
        wait for 300 * T_CLK;

        assert n_marcas = NMARCAS
            report "FALLO: llegaron " & integer'image(n_marcas) &
                   " marcas y se esperaban " & integer'image(NMARCAS)
            severity failure;

        assert errores = 0
            report "FALLO: alguna instruccion de salto no se comporto como debia"
            severity failure;

        report "===========================================";
        report "  PRUEBA SUPERADA: las 5 instrucciones de salto";
        report "  funcionan en sus dos casos, y el salto hacia";
        report "  atras tambien.";
        report "===========================================";

        fin_sim <= true;
        wait;
    end process ESTIMULOS;

end architecture sim;
