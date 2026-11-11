--------------------------------------------------------------------------------
-- Proyecto : MPDII - Microprocesador didactico de 8 bits
-- Modulo   : MPDII  -  Entidad TOP del sistema
-- Tipo     : Descripcion ESTRUCTURAL
--------------------------------------------------------------------------------
-- Conecta los dos grandes bloques del sistema:
--
--      +----------------------+        10 senales / 17 bits        +------------+
--      |   control_unit       | --------- control ---------------> |  datapath  |
--      |   (comportamiento)   | <-------- estado -----------------  | (estructural)|
--      +----------------------+         4 senales / 11 bits        +------------+
--
-- Control  : PCload, INTmux, IRload, Muxsel_dp[1:0], Acc_Load, RF_load,
--            RF_Addr[3:0], Sel_ALU[2:0], Sel_Shift[1:0], OUT_En
-- Estado   : COP = IR[12:8], IR_low = IR[3:0], Zero_dp, Positive_dp
--
-- Puertos del sistema: clk y reset llegan a los dos bloques; Input_dp y
-- OUT_dp pertenecen a la unidad de datos, que es la que habla con el exterior.
--
-- SENALES DE PRUEBA
--   Los diez puertos TEST_* permiten seguir el movimiento de los datos dentro
--   del microprocesador sin abrir la jerarquia: siete vienen de nodos internos
--   de la unidad de datos y tres son copias de senales que ya cruzan entre las
--   dos unidades (COP, Zero_dp y OUT_En).  No alimentan ninguna logica, asi
--   que se pueden dejar sin conectar en la tarjeta sin alterar el diseno.
--
-- OUT_dp proviene de un buffer triestado: solo es valido mientras la unidad
-- de control mantiene OUT_En = '1' (estado S4).  Fuera de ese ciclo queda en
-- alta impedancia.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity MPDII is
    port (
        clk      : in  std_logic;
        reset    : in  std_logic;
        Input_dp : in  std_logic_vector(7 downto 0);
        OUT_dp   : out std_logic_vector(7 downto 0);
        --------------------------------------------------------------------
        -- SENALES DE PRUEBA  (observacion del interior del procesador)
        --------------------------------------------------------------------
        TEST_PC      : out std_logic_vector(7 downto 0);   -- contador de programa
        TEST_ROM     : out std_logic_vector(12 downto 0);  -- salida de la ROM
        TEST_COP     : out std_logic_vector(4 downto 0);   -- codigo de operacion IR[12:8]
        TEST_Mux_dp  : out std_logic_vector(7 downto 0);   -- salida del MUX_Y (BUS Y)
        TEST_Acc     : out std_logic_vector(7 downto 0);   -- salida del acumulador
        TEST_RF      : out std_logic_vector(7 downto 0);   -- salida del banco de registros
        TEST_ALU     : out std_logic_vector(7 downto 0);   -- salida de la ALU
        TEST_Shifter : out std_logic_vector(7 downto 0);   -- salida del desplazador
        TEST_Zero_dp : out std_logic;                      -- bandera de cero
        TEST_OUT_En  : out std_logic                       -- habilitacion del buffer de salida
    );
end entity MPDII;

architecture structural of MPDII is

    ----------------------------------------------------------------------------
    -- Componentes
    ----------------------------------------------------------------------------
    component control_unit is
        port (clk, reset   : in  std_logic;
              COP          : in  std_logic_vector(4 downto 0);
              IR_low       : in  std_logic_vector(3 downto 0);
              Zero_dp      : in  std_logic;
              Positive_dp  : in  std_logic;
              PCload       : out std_logic;
              INTmux       : out std_logic;
              IRload       : out std_logic;
              Muxsel_dp    : out std_logic_vector(1 downto 0);
              Acc_Load     : out std_logic;
              RF_load      : out std_logic;
              RF_Addr      : out std_logic_vector(3 downto 0);
              Sel_ALU      : out std_logic_vector(2 downto 0);
              Sel_Shift    : out std_logic_vector(1 downto 0);
              OUT_En       : out std_logic);
    end component;

    component datapath is
        port (clk, reset   : in  std_logic;
              PCload       : in  std_logic;
              INTmux       : in  std_logic;
              IRload       : in  std_logic;
              Muxsel_dp    : in  std_logic_vector(1 downto 0);
              Acc_Load     : in  std_logic;
              RF_load      : in  std_logic;
              RF_Addr      : in  std_logic_vector(3 downto 0);
              Sel_ALU      : in  std_logic_vector(2 downto 0);
              Sel_Shift    : in  std_logic_vector(1 downto 0);
              OUT_En       : in  std_logic;
              Input_dp     : in  std_logic_vector(7 downto 0);
              OUT_dp       : out std_logic_vector(7 downto 0);
              COP          : out std_logic_vector(4 downto 0);
              IR_low       : out std_logic_vector(3 downto 0);
              Zero_dp      : out std_logic;
              Positive_dp  : out std_logic;
              TEST_PC      : out std_logic_vector(7 downto 0);
              TEST_ROM     : out std_logic_vector(12 downto 0);
              TEST_Mux_dp  : out std_logic_vector(7 downto 0);
              TEST_Acc     : out std_logic_vector(7 downto 0);
              TEST_RF      : out std_logic_vector(7 downto 0);
              TEST_ALU     : out std_logic_vector(7 downto 0);
              TEST_Shifter : out std_logic_vector(7 downto 0));
    end component;

    ----------------------------------------------------------------------------
    -- Bus de control  (UC -> UD)
    ----------------------------------------------------------------------------
    signal c_PCload    : std_logic;
    signal c_INTmux    : std_logic;
    signal c_IRload    : std_logic;
    signal c_Muxsel_dp : std_logic_vector(1 downto 0);
    signal c_Acc_Load  : std_logic;
    signal c_RF_load   : std_logic;
    signal c_RF_Addr   : std_logic_vector(3 downto 0);
    signal c_Sel_ALU   : std_logic_vector(2 downto 0);
    signal c_Sel_Shift : std_logic_vector(1 downto 0);
    signal c_OUT_En    : std_logic;

    ----------------------------------------------------------------------------
    -- Bus de estado  (UD -> UC)
    ----------------------------------------------------------------------------
    signal s_COP         : std_logic_vector(4 downto 0);
    signal s_IR_low      : std_logic_vector(3 downto 0);
    signal s_Zero_dp     : std_logic;
    signal s_Positive_dp : std_logic;

begin

    ----------------------------------------------------------------------------
    -- Unidad de control
    ----------------------------------------------------------------------------
    U_CU : control_unit
        port map (
            clk         => clk,
            reset       => reset,
            COP         => s_COP,
            IR_low      => s_IR_low,
            Zero_dp     => s_Zero_dp,
            Positive_dp => s_Positive_dp,
            PCload      => c_PCload,
            INTmux      => c_INTmux,
            IRload      => c_IRload,
            Muxsel_dp   => c_Muxsel_dp,
            Acc_Load    => c_Acc_Load,
            RF_load     => c_RF_load,
            RF_Addr     => c_RF_Addr,
            Sel_ALU     => c_Sel_ALU,
            Sel_Shift   => c_Sel_Shift,
            OUT_En      => c_OUT_En);

    ----------------------------------------------------------------------------
    -- Unidad de datos
    ----------------------------------------------------------------------------
    U_DP : datapath
        port map (
            clk         => clk,
            reset       => reset,
            PCload      => c_PCload,
            INTmux      => c_INTmux,
            IRload      => c_IRload,
            Muxsel_dp   => c_Muxsel_dp,
            Acc_Load    => c_Acc_Load,
            RF_load     => c_RF_load,
            RF_Addr     => c_RF_Addr,
            Sel_ALU     => c_Sel_ALU,
            Sel_Shift   => c_Sel_Shift,
            OUT_En      => c_OUT_En,
            Input_dp    => Input_dp,
            OUT_dp      => OUT_dp,
            COP         => s_COP,
            IR_low      => s_IR_low,
            Zero_dp     => s_Zero_dp,
            Positive_dp => s_Positive_dp,
            -- observacion
            TEST_PC      => TEST_PC,
            TEST_ROM     => TEST_ROM,
            TEST_Mux_dp  => TEST_Mux_dp,
            TEST_Acc     => TEST_Acc,
            TEST_RF      => TEST_RF,
            TEST_ALU     => TEST_ALU,
            TEST_Shifter => TEST_Shifter);

    ----------------------------------------------------------------------------
    -- Senales de prueba que ya cruzan entre las dos unidades: se copian al
    -- exterior sin pasar por logica adicional.
    ----------------------------------------------------------------------------
    TEST_COP     <= s_COP;        -- que instruccion esta decodificando la UC
    TEST_Zero_dp <= s_Zero_dp;    -- bandera que gobierna JZ y JNZ
    TEST_OUT_En  <= c_OUT_En;     -- marca el ciclo en que OUT_dp es valido

end architecture structural;
