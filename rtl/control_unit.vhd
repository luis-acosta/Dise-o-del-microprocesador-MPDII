--------------------------------------------------------------------------------
-- Proyecto : MPDII - Microprocesador didactico de 8 bits
-- Modulo   : control_unit  -  Unidad de control
-- Tipo     : Descripcion por COMPORTAMIENTO (maquina de estados de Moore)
--------------------------------------------------------------------------------
-- Once estados: uno de busqueda, uno de decodificacion y nueve de ejecucion.
-- Las salidas dependen unicamente del estado presente (Moore); el codigo de
-- operacion solo elige el estado y, en dos casos, alimenta directamente un
-- bus de control.
--
--   S0  FETCH    IRload, PCload, INTmux=0      IR <- ROM[PC] ; PC <- PC+1
--   S1  DECOD    --                            salto segun COP
--   S2  E_LDI    Muxsel_dp=11, Acc_Load
--   S3  E_IN     Muxsel_dp=00, Acc_Load
--   S4  E_OUT    Sel_ALU=000, Muxsel_dp=10, OUT_En
--   S5  E_STR    Sel_ALU=000, Muxsel_dp=10, RF_load
--   S6  E_ALU    Sel_ALU=COP(2:0), Muxsel_dp=10, Acc_Load
--   S7  E_SHIFT  Sel_Shift=COP(1:0), Sel_ALU=000, Muxsel_dp=01, Acc_Load
--   S8  E_JMP    INTmux=1, PCload
--   S9  E_Jcc    INTmux=1, PCload = condicion
--   S10 E_HLT    --                            permanece hasta Reset
--
-- APROVECHAMIENTO DE LA CODIFICACION
--   COP = IR[12:8].  En el grupo aritmetico-logico Sel_ALU = IR[10:8] y en el
--   grupo de desplazamiento Sel_Shift = IR[9:8], asi que esos dos buses salen
--   del propio codigo de operacion sin logica adicional.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity control_unit is
    port (
        clk         : in  std_logic;
        reset       : in  std_logic;
        ----------------------------------------------------------------------
        -- Senales de estado  (desde la unidad de datos)
        ----------------------------------------------------------------------
        COP         : in  std_logic_vector(4 downto 0);  -- IR[12:8]
        IR_low      : in  std_logic_vector(3 downto 0);  -- IR[3:0]
        Zero_dp     : in  std_logic;
        Positive_dp : in  std_logic;
        ----------------------------------------------------------------------
        -- Senales de control  (hacia la unidad de datos)
        ----------------------------------------------------------------------
        PCload      : out std_logic;
        INTmux      : out std_logic;
        IRload      : out std_logic;
        Muxsel_dp   : out std_logic_vector(1 downto 0);
        Acc_Load    : out std_logic;
        RF_load     : out std_logic;
        RF_Addr     : out std_logic_vector(3 downto 0);
        Sel_ALU     : out std_logic_vector(2 downto 0);
        Sel_Shift   : out std_logic_vector(1 downto 0);
        OUT_En      : out std_logic
    );
end entity control_unit;

architecture behavioral of control_unit is

    type state_t is (S0_FETCH, S1_DECOD, S2_LDI,  S3_IN,  S4_OUT, S5_STR,
                     S6_ALU,   S7_SHIFT, S8_JMP,  S9_JCC, S10_HLT);

    signal st   : state_t;   -- estado presente
    signal nx   : state_t;   -- proximo estado
    signal cond : std_logic; -- condicion evaluada para los saltos condicionales

    -- Copia codificada del estado, util para observar la simulacion.
    signal st_code : std_logic_vector(3 downto 0);

begin

    ----------------------------------------------------------------------------
    -- Registro de estado
    ----------------------------------------------------------------------------
    REGISTRO_ESTADO : process (clk, reset)
    begin
        if reset = '1' then
            st <= S0_FETCH;
        elsif rising_edge(clk) then
            st <= nx;
        end if;
    end process REGISTRO_ESTADO;

    ----------------------------------------------------------------------------
    -- Logica de condicion de salto
    ----------------------------------------------------------------------------
    CONDICION : process (COP, Zero_dp, Positive_dp)
    begin
        case COP is
            when "11001" => cond <= Zero_dp;             -- JZ   salta si Acc = 0
            when "11010" => cond <= not Zero_dp;         -- JNZ  salta si Acc /= 0
            when "11011" => cond <= Positive_dp;         -- JP   salta si Acc >= 0
            when "11100" => cond <= not Positive_dp;     -- JN   salta si Acc < 0
            when others  => cond <= '0';
        end case;
    end process CONDICION;

    ----------------------------------------------------------------------------
    -- Logica de proximo estado  (decodificador del codigo de operacion)
    ----------------------------------------------------------------------------
    PROXIMO_ESTADO : process (st, COP)
    begin
        case st is

            when S0_FETCH =>
                nx <= S1_DECOD;

            when S1_DECOD =>
                if    COP = "00000" then nx <= S0_FETCH;   -- NOP, sin ejecucion
                elsif COP = "00001" then nx <= S2_LDI;
                elsif COP = "00010" then nx <= S3_IN;
                elsif COP = "00011" then nx <= S4_OUT;
                elsif COP = "00100" then nx <= S5_STR;
                elsif COP(4 downto 3) = "01" then nx <= S6_ALU;
                elsif COP(4 downto 3) = "10" then nx <= S7_SHIFT;
                elsif COP = "11000" then nx <= S8_JMP;
                elsif COP = "11001" or COP = "11010" or
                      COP = "11011" or COP = "11100" then nx <= S9_JCC;
                elsif COP = "11111" then nx <= S10_HLT;
                else                     nx <= S0_FETCH;   -- codigos no usados
                end if;

            when S10_HLT =>
                nx <= S10_HLT;                             -- se queda detenido

            when others =>
                nx <= S0_FETCH;                            -- S2 .. S9 duran un ciclo
        end case;
    end process PROXIMO_ESTADO;

    ----------------------------------------------------------------------------
    -- Logica de salida (Moore): solo depende del estado presente
    ----------------------------------------------------------------------------
    SALIDAS : process (st, COP, cond)
    begin
        -- Valores por defecto: ninguna senal activa.
        PCload    <= '0';
        INTmux    <= '0';
        IRload    <= '0';
        Muxsel_dp <= "00";
        Acc_Load  <= '0';
        RF_load   <= '0';
        Sel_ALU   <= "000";
        Sel_Shift <= "00";
        OUT_En    <= '0';

        case st is

            when S0_FETCH =>                       -- IR <- ROM[PC] ; PC <- PC+1
                IRload <= '1';
                PCload <= '1';
                INTmux <= '0';

            when S1_DECOD =>
                null;

            when S2_LDI =>                         -- Acc <- IR[7:0]
                Muxsel_dp <= "11";
                Acc_Load  <= '1';

            when S3_IN =>                          -- Acc <- Input_dp
                Muxsel_dp <= "00";
                Acc_Load  <= '1';

            when S4_OUT =>                         -- OUT_dp <- Acc
                Sel_ALU   <= "000";                -- la ALU deja pasar A
                Muxsel_dp <= "10";
                OUT_En    <= '1';

            when S5_STR =>                         -- Rn <- Acc
                Sel_ALU   <= "000";
                Muxsel_dp <= "10";
                RF_load   <= '1';

            when S6_ALU =>                         -- Acc <- Acc op Rn
                Sel_ALU   <= COP(2 downto 0);      -- = IR[10:8]
                Muxsel_dp <= "10";
                Acc_Load  <= '1';

            when S7_SHIFT =>                       -- Acc <- desplazar(Acc)
                Sel_ALU   <= "000";                -- la ALU deja pasar A
                Sel_Shift <= COP(1 downto 0);      -- = IR[9:8]
                Muxsel_dp <= "01";
                Acc_Load  <= '1';

            when S8_JMP =>                         -- PC <- IR[7:0]
                INTmux <= '1';
                PCload <= '1';

            when S9_JCC =>                         -- PC <- IR[7:0] si se cumple
                INTmux <= '1';
                PCload <= cond;

            when S10_HLT =>
                null;

        end case;
    end process SALIDAS;

    ----------------------------------------------------------------------------
    -- El numero de registro viaja del IR hasta el banco a traves de la UC.
    ----------------------------------------------------------------------------
    RF_Addr <= IR_low;

    -- Solo para observacion en simulacion.
    st_code <= std_logic_vector(to_unsigned(state_t'pos(st), 4));

end architecture behavioral;
