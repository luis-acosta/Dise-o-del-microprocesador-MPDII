--------------------------------------------------------------------------------
-- Proyecto : MPDII - Microprocesador didactico de 8 bits
-- Modulo   : datapath  -  Unidad de datos completa
-- Tipo     : Descripcion ESTRUCTURAL (interconexion de componentes)
--------------------------------------------------------------------------------
-- Reune los once bloques de la hoja 2 del juego de planos:
--
--   U_MUXPC  mux2to1_8    U_PC    reg8         U_INC   inc8
--   U_ROM    rom256x13    U_IR    reg13        U_MUXY  mux4to1_8
--   U_ACC    reg8         U_RF    regfile16x8  U_ALU   alu8
--   U_SH     shifter8     U_OBUF  tristate8    U_FLAGS flags
--
-- CAMINO DE BUSQUEDA
--   PC -> ROM -> IR ;  PC+1 o IR[7:0] regresan al PC por el MUX_PC
--
-- CAMINO DE EJECUCION
--   MUX_Y -> BUS Y -> { acumulador, banco de registros, buffer de salida }
--   acumulador -> entrada A de la ALU   y   logica de banderas
--   banco      -> entrada B de la ALU
--   ALU -> desplazador ;  ambos regresan al MUX_Y
--
-- NOTA SOBRE RF_Addr
--   El numero de registro vive en IR[3:0], dentro de esta unidad, pero la
--   senal RF_Addr es un puerto de control.  Por eso IR[3:0] sale hacia la
--   unidad de control (puerto IR_low) y regresa como RF_Addr.  La unidad de
--   control solo lo reenvia de forma combinacional.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity datapath is
    port (
        ----------------------------------------------------------------------
        -- Senales del sistema
        ----------------------------------------------------------------------
        clk         : in  std_logic;
        reset       : in  std_logic;
        ----------------------------------------------------------------------
        -- Senales de control  (unidad de control  ->  unidad de datos)
        ----------------------------------------------------------------------
        PCload      : in  std_logic;
        INTmux      : in  std_logic;
        IRload      : in  std_logic;
        Muxsel_dp   : in  std_logic_vector(1 downto 0);
        Acc_Load    : in  std_logic;
        RF_load     : in  std_logic;
        RF_Addr     : in  std_logic_vector(3 downto 0);
        Sel_ALU     : in  std_logic_vector(2 downto 0);
        Sel_Shift   : in  std_logic_vector(1 downto 0);
        OUT_En      : in  std_logic;
        ----------------------------------------------------------------------
        -- Datos con el exterior
        ----------------------------------------------------------------------
        Input_dp    : in  std_logic_vector(7 downto 0);
        OUT_dp      : out std_logic_vector(7 downto 0);
        ----------------------------------------------------------------------
        -- Senales de estado  (unidad de datos  ->  unidad de control)
        ----------------------------------------------------------------------
        COP         : out std_logic_vector(4 downto 0);  -- IR[12:8]
        IR_low      : out std_logic_vector(3 downto 0);  -- IR[3:0]
        Zero_dp     : out std_logic;
        Positive_dp : out std_logic
    );
end entity datapath;

architecture structural of datapath is

    ----------------------------------------------------------------------------
    -- Declaracion de componentes
    ----------------------------------------------------------------------------
    component mux2to1_8 is
        port (d0, d1 : in std_logic_vector(7 downto 0);
              sel     : in std_logic;
              y       : out std_logic_vector(7 downto 0));
    end component;

    component mux4to1_8 is
        port (d0, d1, d2, d3 : in std_logic_vector(7 downto 0);
              sel            : in std_logic_vector(1 downto 0);
              y              : out std_logic_vector(7 downto 0));
    end component;

    component reg8 is
        port (clk, clr, load : in std_logic;
              d : in  std_logic_vector(7 downto 0);
              q : out std_logic_vector(7 downto 0));
    end component;

    component reg13 is
        port (clk, clr, load : in std_logic;
              d : in  std_logic_vector(12 downto 0);
              q : out std_logic_vector(12 downto 0));
    end component;

    component inc8 is
        port (d : in  std_logic_vector(7 downto 0);
              q : out std_logic_vector(7 downto 0));
    end component;

    component rom256x13 is
        port (addr : in  std_logic_vector(7 downto 0);
              q    : out std_logic_vector(12 downto 0));
    end component;

    component regfile16x8 is
        port (clk  : in  std_logic;
              we   : in  std_logic;
              addr : in  std_logic_vector(3 downto 0);
              d    : in  std_logic_vector(7 downto 0);
              q    : out std_logic_vector(7 downto 0));
    end component;

    component alu8 is
        port (a, b : in  std_logic_vector(7 downto 0);
              sel  : in  std_logic_vector(2 downto 0);
              y    : out std_logic_vector(7 downto 0));
    end component;

    component shifter8 is
        port (d   : in  std_logic_vector(7 downto 0);
              sel : in  std_logic_vector(1 downto 0);
              y   : out std_logic_vector(7 downto 0));
    end component;

    component tristate8 is
        port (d  : in  std_logic_vector(7 downto 0);
              en : in  std_logic;
              y  : out std_logic_vector(7 downto 0));
    end component;

    component flags is
        port (d       : in  std_logic_vector(7 downto 0);
              zero    : out std_logic;
              positiv : out std_logic);
    end component;

    ----------------------------------------------------------------------------
    -- Senales internas
    ----------------------------------------------------------------------------
    signal s_muxpc_y : std_logic_vector(7 downto 0);   -- entrada del PC
    signal s_pc_q    : std_logic_vector(7 downto 0);   -- salida del PC
    signal s_inc_q   : std_logic_vector(7 downto 0);   -- PC + 1
    signal s_rom_q   : std_logic_vector(12 downto 0);  -- palabra leida de la ROM
    signal s_ir_q    : std_logic_vector(12 downto 0);  -- contenido del IR
    signal s_busy    : std_logic_vector(7 downto 0);   -- BUS Y
    signal s_acc_q   : std_logic_vector(7 downto 0);   -- salida del acumulador
    signal s_rf_q    : std_logic_vector(7 downto 0);   -- salida del banco
    signal s_alu_y   : std_logic_vector(7 downto 0);   -- salida de la ALU
    signal s_sh_y    : std_logic_vector(7 downto 0);   -- salida del desplazador

begin

    ----------------------------------------------------------------------------
    -- UNIDAD DE BUSQUEDA
    ----------------------------------------------------------------------------

    -- Elige entre PC+1 y la direccion de salto contenida en IR[7:0]
    U_MUXPC : mux2to1_8
        port map (d0  => s_inc_q,
                  d1  => s_ir_q(7 downto 0),
                  sel => INTmux,
                  y   => s_muxpc_y);

    -- Contador de programa
    U_PC : reg8
        port map (clk => clk, clr => reset, load => PCload,
                  d => s_muxpc_y, q => s_pc_q);

    -- Incrementador: alimenta la entrada 0 del MUX_PC
    U_INC : inc8
        port map (d => s_pc_q, q => s_inc_q);

    -- Memoria de programa, direccionada por el PC
    U_ROM : rom256x13
        port map (addr => s_pc_q, q => s_rom_q);

    -- Registro de instruccion
    U_IR : reg13
        port map (clk => clk, clr => reset, load => IRload,
                  d => s_rom_q, q => s_ir_q);

    -- Campos del IR que viajan hacia la unidad de control
    COP    <= s_ir_q(12 downto 8);
    IR_low <= s_ir_q(3 downto 0);

    ----------------------------------------------------------------------------
    -- UNIDAD DE EJECUCION
    ----------------------------------------------------------------------------

    -- Selector de la fuente del BUS Y
    U_MUXY : mux4to1_8
        port map (d0  => Input_dp,            -- "00"
                  d1  => s_sh_y,              -- "01"
                  d2  => s_alu_y,             -- "10"
                  d3  => s_ir_q(7 downto 0),  -- "11"
                  sel => Muxsel_dp,
                  y   => s_busy);

    -- Acumulador
    U_ACC : reg8
        port map (clk => clk, clr => reset, load => Acc_Load,
                  d => s_busy, q => s_acc_q);

    -- Banco de 16 registros
    U_RF : regfile16x8
        port map (clk => clk, we => RF_load, addr => RF_Addr,
                  d => s_busy, q => s_rf_q);

    -- ALU:  A = acumulador, B = banco de registros
    U_ALU : alu8
        port map (a => s_acc_q, b => s_rf_q, sel => Sel_ALU, y => s_alu_y);

    -- Desplazador en cascada con la ALU
    U_SH : shifter8
        port map (d => s_alu_y, sel => Sel_Shift, y => s_sh_y);

    -- Buffer triestado hacia el exterior
    U_OBUF : tristate8
        port map (d => s_busy, en => OUT_En, y => OUT_dp);

    -- Banderas tomadas de la salida del acumulador
    U_FLAGS : flags
        port map (d => s_acc_q, zero => Zero_dp, positiv => Positive_dp);

end architecture structural;
