--------------------------------------------------------------------------------
-- Proyecto : MPDII - Microprocesador didactico de 8 bits
-- Modulo   : tb_MPDII  -  Banco de pruebas del sistema completo
--------------------------------------------------------------------------------
-- Aplica reloj y reset, deja correr el programa de division cargado en la ROM
-- (15 / 3) y captura el valor que el microprocesador entrega por OUT_dp.
--
-- Ademas conecta los diez puertos TEST_* del TOP y los usa para imprimir una
-- traza del movimiento de los datos: cada vez que cambia el acumulador se
-- reporta en que direccion esta el programa, que instruccion se decodifico y
-- que hay en el BUS Y, en el banco de registros, en la ALU y en el desplazador.
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

    signal clk      : std_logic := '0';
    signal reset    : std_logic := '1';
    signal Input_dp : std_logic_vector(7 downto 0) := (others => '0');
    signal OUT_dp   : std_logic_vector(7 downto 0);

    -- Senales de prueba traidas del TOP
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

    -- Foto de los nodos combinacionales tomada en mitad de cada estado
    signal snap_pc   : std_logic_vector(7 downto 0);
    signal snap_cop  : std_logic_vector(4 downto 0);
    signal snap_busy : std_logic_vector(7 downto 0);
    signal snap_alu  : std_logic_vector(7 downto 0);
    signal snap_sh   : std_logic_vector(7 downto 0);
    signal snap_rf   : std_logic_vector(7 downto 0);

    ----------------------------------------------------------------------------
    -- Utilidades de impresion
    ----------------------------------------------------------------------------

    -- Convierte un vector a decimal; devuelve -1 si contiene valores
    -- indeterminados, para no ensuciar la traza durante el arranque.
    function val (v : std_logic_vector) return integer is
    begin
        if Is_X(v) then
            return -1;
        else
            return to_integer(unsigned(v));
        end if;
    end function val;

    function img (v : std_logic_vector) return string is
    begin
        return integer'image(val(v));
    end function img;

    -- Traduce el codigo de operacion a su mnemonico, en ancho fijo.
    function mnemonico (cop : std_logic_vector(4 downto 0)) return string is
    begin
        case cop is
            when "00000" => return "NOP";
            when "00001" => return "LDI";
            when "00010" => return "IN ";
            when "00011" => return "OUT";
            when "00100" => return "STR";
            when "01001" => return "AND";
            when "01010" => return "OR ";
            when "01011" => return "NOT";
            when "01100" => return "ADD";
            when "01101" => return "SUB";
            when "01110" => return "INC";
            when "01111" => return "DEC";
            when "10001" => return "SHL";
            when "10010" => return "SHR";
            when "10011" => return "ROR";
            when "11000" => return "JMP";
            when "11001" => return "JZ ";
            when "11010" => return "JNZ";
            when "11011" => return "JP ";
            when "11100" => return "JN ";
            when "11111" => return "HLT";
            when others  => return " ? ";
        end case;
    end function mnemonico;

begin

    ----------------------------------------------------------------------------
    -- Unidad bajo prueba
    ----------------------------------------------------------------------------
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
    -- Traza del movimiento de datos, construida con las senales TEST_*.
    --
    -- MUESTREO toma una foto de los nodos combinacionales en el flanco de
    -- BAJADA, es decir en mitad del estado, cuando los valores ya estan
    -- estables y todavia no han cambiado de estado.  TRAZA imprime esa foto
    -- en el flanco de SUBIDA siguiente, que es cuando el acumulador se carga.
    -- Asi cada linea muestra el dato que viajo por el bus y el valor que
    -- quedo guardado como consecuencia.
    ----------------------------------------------------------------------------
    MUESTREO : process (clk)
    begin
        if falling_edge(clk) then
            snap_pc   <= TEST_PC;
            snap_cop  <= TEST_COP;
            snap_busy <= TEST_Mux_dp;
            snap_alu  <= TEST_ALU;
            snap_sh   <= TEST_Shifter;
            snap_rf   <= TEST_RF;
        end if;
    end process MUESTREO;

    -- Se dispara en el instante en que el acumulador cambia, no en el flanco:
    -- asi la foto que se imprime es la del estado que provoco el cambio.
    -- PCsig es la direccion que el contador YA apunta (la siguiente), porque
    -- el PC se incrementa durante la busqueda, antes de la ejecucion.
    TRAZA : process
    begin
        wait on TEST_Acc;
        wait for 1 ns;          -- deja que las banderas combinacionales se asienten
        if reset = '0' and not Is_X(TEST_Acc) then
            report "PCsig=" & img(snap_pc) &
                   "  " & mnemonico(snap_cop) &
                   "  BusY="  & img(snap_busy) &
                   " -> Acc=" & img(TEST_Acc) &
                   "   | RF="   & img(snap_rf) &
                   "  ALU="     & img(snap_alu) &
                   "  Shift="   & img(snap_sh) &
                   "  Zero="    & std_logic'image(TEST_Zero_dp);
        end if;
    end process TRAZA;

    ----------------------------------------------------------------------------
    -- Captura del dato de salida mientras el buffer esta habilitado
    ----------------------------------------------------------------------------
    CAPTURA : process (clk)
    begin
        if rising_edge(clk) then
            if TEST_OUT_En = '1' and OUT_dp /= "ZZZZZZZZ" then
                capturado <= OUT_dp;
                n_salidas <= n_salidas + 1;
                report ">>> OUT_dp = " & img(OUT_dp) & "   (TEST_OUT_En activa)";
            end if;
        end if;
    end process CAPTURA;

    ----------------------------------------------------------------------------
    -- Estimulos y comprobacion
    ----------------------------------------------------------------------------
    ESTIMULOS : process
    begin
        -- Reset asincrono durante tres ciclos completos
        reset <= '1';
        wait for 3 * T_CLK;
        reset <= '0';

        -- Margen suficiente para el programa cargado en la ROM.
        wait for 260 * T_CLK;

        ------------------------------------------------------------------------
        -- Comprobaciones
        ------------------------------------------------------------------------
        assert n_salidas > 0
            report "FALLO: el microprocesador nunca activo OUT_En"
            severity failure;

        assert capturado = x"05"
            report "FALLO: 15/3 debia dar 5 y se obtuvo " & img(capturado)
            severity failure;

        report "===========================================";
        report "  PRUEBA SUPERADA:  15 / 3 = " & img(capturado);
        report "===========================================";

        fin_sim <= true;
        wait;
    end process ESTIMULOS;

end architecture sim;
