library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.crossbar_utils.all;

library UNISIM;
use UNISIM.vcomponents.all;

entity ULEARN is
    Generic(
            LUT_DEPTH          : integer := 1024;
            SYNAPSE_MEM_DEPTH  : integer := 2048           
            );
    Port 
    ( 
        CLK                    : in  std_logic;
        RST                    : in  std_logic;
        CFG_WORD               : in  std_logic_vector(255 downto 0);
        NMODEL_SPIKE_TIME      : in  std_logic_vector(7 downto 0);  
        SYN_DATA_IN            : in  std_logic_vector(15 downto 0); 
        SYN_DIN_VLD            : in  std_logic;                    
        SYNAPSE_START_ADDRESS  : in  std_logic_vector((clogb2(SYNAPSE_MEM_DEPTH)-1) downto 0);  
        SYN_DATA_OUT           : out std_logic_vector(15 downto 0);
        SYN_DOUT_VLD           : out std_logic;                     
        SYNAPSE_WRITE_ADDRESS  : out std_logic_vector((clogb2(SYNAPSE_MEM_DEPTH)-1) downto 0);
        LUT_ADDR               : out std_logic_vector((clogb2(LUT_DEPTH)-1) downto 0);
        LUT_DOUT               : in  std_logic_vector(7 downto 0)  
    );
end ULEARN;

architecture rtl of ULEARN is

    constant MEMWIDTH : integer := clogb2(SYNAPSE_MEM_DEPTH);
    constant LUTWIDTH : integer := clogb2(LUT_DEPTH);

    signal DSP1_ALUMODE , DSP2_ALUMODE , DSP3_ALUMODE , DSP4_ALUMODE : std_logic_vector(3 downto 0);
    signal DSP1_INMODE  , DSP2_INMODE  , DSP3_INMODE  , DSP4_INMODE  : std_logic_vector(4 downto 0);
    signal DSP1_OPMODE  , DSP2_OPMODE  , DSP3_OPMODE  , DSP4_OPMODE  : std_logic_vector(6 downto 0);

    signal DSP1_A_MUX , DSP2_A_MUX , DSP3_A_MUX , DSP4_A_MUX : std_logic_vector(1 downto 0);
    signal DSP1_B_MUX , DSP2_B_MUX , DSP3_B_MUX , DSP4_B_MUX : std_logic_vector(1 downto 0);
    signal DSP1_C_MUX , DSP2_C_MUX , DSP3_C_MUX , DSP4_C_MUX : std_logic_vector(1 downto 0);
    signal DSP1_D_MUX , DSP2_D_MUX , DSP3_D_MUX , DSP4_D_MUX : std_logic_vector(1 downto 0);

    signal DSP1_A_IN , DSP2_A_IN , DSP3_A_IN , DSP4_A_IN : signed(29 downto 0);
    signal DSP1_B_IN , DSP2_B_IN , DSP3_B_IN , DSP4_B_IN : signed(17 downto 0);
    signal DSP1_C_IN , DSP2_C_IN , DSP3_C_IN , DSP4_C_IN : signed(47 downto 0);
    signal DSP1_D_IN , DSP2_D_IN , DSP3_D_IN , DSP4_D_IN : signed(24 downto 0);

    signal DSP1_C_IN_REG : signed(47 downto 0);
    signal DSP2_C_IN_REG : signed(47 downto 0);
    signal DSP3_C_IN_REG : signed(47 downto 0);
    signal DSP4_C_IN_REG : signed(47 downto 0);

    signal PCOUT_1_TO_2   : std_logic_vector(47 downto 0);
    signal PCOUT_3_TO_4   : std_logic_vector(47 downto 0);
  
    signal POUT_DSP2      : std_logic_vector(47 downto 0);
    signal POUT_DSP4      : std_logic_vector(47 downto 0);

    signal COEFF_0 , COEFF_1 , COEFF_2 , COEFF_3 : std_logic_vector(15 downto 0);

    signal TRACE_1_OP, TRACE_2_OP : std_logic_vector(2 downto 0);
    signal TRACE_1_CONST , TRACE_2_CONST : std_logic_vector(7 downto 0);

    signal LUT_BASE_ADDR : integer;

    signal LUT_ADDRESSING : std_logic_vector(2 downto 0);
    signal LUT_OFFSET_SIGNED : signed(LUTWIDTH-1 downto 0);

    signal TRACE_PRE : unsigned(7 downto 0);
    signal TRACE_POST , TRACE_POST_P0: unsigned(7 downto 0);

    signal WEIGHT   : signed(7 downto 0);

    type VALID_PIPELINE is array (0 to 15) of std_logic;
    signal VLD_PP : VALID_PIPELINE;

    signal WEIGHT_ALIGNED : signed(47 downto 0);

    signal COND_1_SEL     : std_logic_vector(3 downto 0);
    signal COND_2_SEL     : std_logic_vector(3 downto 0);
    signal OUT_SHIFT_VAL  : integer range 0 to 16;

    signal COND_1_COMB : std_logic;
    signal COND_2_COMB : std_logic;

    type WEIGHT_PIPELINE is array (0 to 15) of signed(7 downto 0);
    type TRACE_PIPELINE  is array (0 to 15) of unsigned(7 downto 0);
    
    signal WEIGHT_PP : WEIGHT_PIPELINE;
    signal TRACE_PRE_PP : TRACE_PIPELINE;

    type COND_PIPELINE is array (0 to 15) of std_logic;
    signal COND_1_PP : COND_PIPELINE;
    signal COND_2_PP : COND_PIPELINE;

    signal TRACE_1_CALC, TRACE_2_CALC : unsigned(7 downto 0);

    signal W_SELECTED : signed(47 downto 0);
    signal T_SELECTED : unsigned(7 downto 0);
    
    signal W_SHIFTED : signed(23 downto 0);
    signal W_INT8    : signed(7 downto 0);
    signal W_CLIPPED : signed(7 downto 0);

    signal SYNAPSE_START_ADDRESS_INT : integer;

begin

    DSP1_OPMODE    <= CFG_WORD(6  downto  0); 
    DSP1_INMODE    <= CFG_WORD(11 downto  7); 
    DSP1_ALUMODE   <= CFG_WORD(15 downto 12);
  
    DSP2_OPMODE    <= CFG_WORD(22 downto 16); 
    DSP2_INMODE    <= CFG_WORD(27 downto 23); 
    DSP2_ALUMODE   <= CFG_WORD(31 downto 28);
  
    DSP3_OPMODE    <= CFG_WORD(38 downto 32); 
    DSP3_INMODE    <= CFG_WORD(43 downto 39); 
    DSP3_ALUMODE   <= CFG_WORD(47 downto 44);    
  
    DSP4_OPMODE    <= CFG_WORD(54 downto 48); 
    DSP4_INMODE    <= CFG_WORD(59 downto 55); 
    DSP4_ALUMODE   <= CFG_WORD(63 downto 60);

    DSP1_A_MUX     <= CFG_WORD(65 downto 64);
    DSP1_B_MUX     <= CFG_WORD(67 downto 66);
    DSP1_C_MUX     <= CFG_WORD(69 downto 68);
    DSP1_D_MUX     <= CFG_WORD(71 downto 70);

    DSP2_A_MUX     <= CFG_WORD(73 downto 72);
    DSP2_B_MUX     <= CFG_WORD(75 downto 74);
    DSP2_C_MUX     <= CFG_WORD(77 downto 76);
    DSP2_D_MUX     <= CFG_WORD(79 downto 78);

    DSP3_A_MUX     <= CFG_WORD(81 downto 80);
    DSP3_B_MUX     <= CFG_WORD(83 downto 82);
    DSP3_C_MUX     <= CFG_WORD(85 downto 84);
    DSP3_D_MUX     <= CFG_WORD(87 downto 86);

    DSP4_A_MUX     <= CFG_WORD(89 downto 88);
    DSP4_B_MUX     <= CFG_WORD(91 downto 90);
    DSP4_C_MUX     <= CFG_WORD(93 downto 92);
    DSP4_D_MUX     <= CFG_WORD(95 downto 94);

    COEFF_0        <= CFG_WORD(143 downto 128);
    COEFF_1        <= CFG_WORD(159 downto 144);
    COEFF_2        <= CFG_WORD(175 downto 160);
    COEFF_3        <= CFG_WORD(191 downto 176);

    TRACE_1_OP     <= CFG_WORD(194 downto 192);
    TRACE_1_CONST  <= CFG_WORD(202 downto 195);
    TRACE_2_OP     <= CFG_WORD(205 downto 203);
    TRACE_2_CONST  <= CFG_WORD(213 downto 206);

    LUT_BASE_ADDR  <= to_integer(unsigned(CFG_WORD(229 downto 214)));

    LUT_ADDRESSING <= CFG_WORD(232 downto 230);

    COND_1_SEL     <= CFG_WORD(236 downto 233); 
    COND_2_SEL     <= CFG_WORD(240 downto 237); 

    OUT_SHIFT_VAL  <= to_integer(unsigned(CFG_WORD(244 downto 241)));

--  INPUT_DISMANTLE

    WEIGHT     <= signed(SYN_DATA_IN(15 downto 8));
    TRACE_PRE  <= unsigned(SYN_DATA_IN(7 downto 0));
    TRACE_POST <= unsigned(NMODEL_SPIKE_TIME);

    --CORRELATION ADDRESSING;

    LUT_OFFSET_SIGNED <=    signed(resize(TRACE_PRE, LUTWIDTH))                                        when LUT_ADDRESSING = "000" else
                            signed(resize(TRACE_POST, LUTWIDTH))                                       when LUT_ADDRESSING = "001" else
                            signed(resize(TRACE_POST, LUTWIDTH)) - signed(resize(TRACE_PRE, LUTWIDTH)) when LUT_ADDRESSING = "010" else
                            signed(resize(TRACE_PRE, LUTWIDTH)) - signed(resize(TRACE_POST, LUTWIDTH)) when LUT_ADDRESSING = "011" else
                            resize(WEIGHT, LUTWIDTH)                                                   when LUT_ADDRESSING = "100" else
                            signed(resize(TRACE_PRE, LUTWIDTH));

    LUT_ADDR <= std_logic_vector(to_unsigned(LUT_BASE_ADDR + to_integer(LUT_OFFSET_SIGNED), LUTWIDTH));

    -- CONDITION CHECKING

    COND_1_COMB <= 
        '1' when (COND_1_SEL = "0000" and LUT_OFFSET_SIGNED > 0 and SYN_DIN_VLD = '1') else
        '1' when (COND_1_SEL = "0001" and LUT_OFFSET_SIGNED = 0 and SYN_DIN_VLD = '1') else
        '1' when (COND_1_SEL = "0010" and LUT_OFFSET_SIGNED < 0 and SYN_DIN_VLD = '1') else
        '1' when (COND_1_SEL = "0011" and TRACE_PRE = 0 and SYN_DIN_VLD = '1') else
        '1' when (COND_1_SEL = "0100" and TRACE_POST = 0 and SYN_DIN_VLD = '1') else
        '1' when (COND_1_SEL = "0101" and SYN_DIN_VLD = '1') else
        '0';

    COND_2_COMB <= 
        '1' when (COND_2_SEL = "0000" and LUT_OFFSET_SIGNED > 0 and SYN_DIN_VLD = '1') else
        '1' when (COND_2_SEL = "0001" and LUT_OFFSET_SIGNED = 0 and SYN_DIN_VLD = '1') else
        '1' when (COND_2_SEL = "0010" and LUT_OFFSET_SIGNED < 0 and SYN_DIN_VLD = '1') else
        '1' when (COND_2_SEL = "0011" and TRACE_PRE = 0 and SYN_DIN_VLD = '1') else
        '1' when (COND_2_SEL = "0100" and TRACE_POST = 0 and SYN_DIN_VLD = '1') else
        '1' when (COND_2_SEL = "0101" and SYN_DIN_VLD = '1') else
        '0';

    VLD_PIPELINE : process(CLK)
    begin
        if rising_edge(CLK) then
            if RST = '1' then
                for k in 0 to 15 loop
                    VLD_PP(k)    <= '0';
                end loop;
            else
                VLD_PP(0) <= SYN_DIN_VLD;
                for k in 0 to 14 loop
                    VLD_PP(k+1) <= VLD_PP(k);
                end loop;
            end if;
        end if;
    end process VLD_PIPELINE;

    INPUT_PIPELINE : process(CLK)
    begin
        if rising_edge(CLK) then
            if RST = '1' then

                for k in 0 to 4 loop
                    WEIGHT_PP(k)    <=(others=>'0');
                end loop;

                for k in 0 to 8 loop
                    TRACE_PRE_PP(k) <= (others=>'0');
                end loop;

            else

                if SYN_DIN_VLD = '1' then
                    WEIGHT_PP(0)     <= WEIGHT;
                    TRACE_PRE_PP(0)  <= TRACE_PRE;
                --    TRACE_POST_P0    <= TRACE_POST;
                end if;

--                for k in 0 to 14 loop
--                    WEIGHT_PP(k+1) <= WEIGHT_PP(k);
--                    TRACE_PRE_PP(k+1) <= TRACE_PRE_PP(k);
--                end loop;

                for k in 0 to 3 loop
                    WEIGHT_PP(k+1) <= WEIGHT_PP(k);
                end loop;
                for k in 0 to 7 loop
                    TRACE_PRE_PP(k+1) <= TRACE_PRE_PP(k);
                end loop;

            end if;
        end if;
    end process INPUT_PIPELINE;
    
    CONDITION_PIPELINE : process(CLK)
    begin
        if rising_edge(CLK) then
            if RST = '1' then
                for k in 0 to 15 loop
                    COND_1_PP(k) <= '0';
                    COND_2_PP(k) <= '0';
                end loop;
            else
                COND_1_PP(0) <= COND_1_COMB;
                COND_2_PP(0) <= COND_2_COMB;
                for k in 0 to 14 loop
                    COND_1_PP(k+1) <= COND_1_PP(k);
                    COND_2_PP(k+1) <= COND_2_PP(k);
                end loop;
            end if;
        end if;
    end process CONDITION_PIPELINE;

    C_PORT_ALIGNMENT : process(CLK)
    begin
        if rising_edge(CLK) then
            if RST = '1' then
                DSP1_C_IN_REG <= (others => '0');
                DSP2_C_IN_REG <= (others => '0');
                DSP3_C_IN_REG <= (others => '0');
                DSP4_C_IN_REG <= (others => '0');
            else
                DSP1_C_IN_REG <= DSP1_C_IN;
                DSP2_C_IN_REG <= DSP2_C_IN;
                DSP3_C_IN_REG <= DSP3_C_IN;
                DSP4_C_IN_REG <= DSP4_C_IN;
            end if;
        end if;
    end process C_PORT_ALIGNMENT;

    WEIGHT_ALIGNED <= shift_left(resize(WEIGHT_PP(0) , 48), OUT_SHIFT_VAL);

     -- ------------------------- DSP 1 MUX -------------------------
    DSP1_A_IN <= to_signed(1, 30)                when DSP1_A_MUX = B"00" else
                 resize(WEIGHT_PP(0) , 30)       when DSP1_A_MUX = B"01" else
                 resize(signed(COEFF_0), 30)     when DSP1_A_MUX = B"10" else
                 resize(signed(COEFF_1), 30);

    DSP1_B_IN <= to_signed(1, 18)                when DSP1_B_MUX = B"00" else
                 resize(WEIGHT_PP(0) , 18)       when DSP1_B_MUX = B"01" else
                 resize(signed(LUT_DOUT), 18)    when DSP1_B_MUX = B"10" else
                 resize(signed(COEFF_2), 18);

    DSP1_C_IN <= to_signed(0, 48)                when DSP1_C_MUX = B"00" else
                 WEIGHT_ALIGNED                  when DSP1_C_MUX = B"01" else
                 signed(resize(TRACE_PRE_PP(0) ,48)) when DSP1_C_MUX = B"10" else
                 resize(signed(COEFF_2), 48);

    DSP1_D_IN <= to_signed(1, 25)                when DSP1_D_MUX = B"00" else
                 resize(WEIGHT_PP(0) , 25)       when DSP1_D_MUX = B"01" else
                 resize(signed(COEFF_0), 25)     when DSP1_D_MUX = B"10" else
                 resize(signed(COEFF_1), 25);

    -- ------------------------- DSP 2 MUX -------------------------
    DSP2_A_IN <= to_signed(1, 30)                when DSP2_A_MUX = B"00" else
                 resize(WEIGHT_PP(0) , 30)           when DSP2_A_MUX = B"01" else
                 resize(signed(COEFF_0), 30)     when DSP2_A_MUX = B"10" else
                 resize(signed(COEFF_1), 30);

    DSP2_B_IN <= to_signed(1, 18)                when DSP2_B_MUX = B"00" else
                 resize(WEIGHT_PP(0) , 18)       when DSP2_B_MUX = B"01" else
                 resize(signed(LUT_DOUT), 18)    when DSP2_B_MUX = B"10" else
                 resize(signed(COEFF_2), 18);

    DSP2_C_IN <= to_signed(0, 48)                when DSP2_C_MUX = B"00" else
                 WEIGHT_ALIGNED                  when DSP2_C_MUX = B"01" else
                 signed(resize(TRACE_PRE_PP(0) ,48)) when DSP2_C_MUX = B"10" else
                 resize(signed(COEFF_2), 48);

    DSP2_D_IN <= to_signed(1, 25)                when DSP2_D_MUX = B"00" else
                 resize(WEIGHT_PP(0) , 25)       when DSP2_D_MUX = B"01" else
                 resize(signed(COEFF_0), 25)     when DSP2_D_MUX = B"10" else
                 resize(signed(COEFF_1), 25);

    -- ------------------------- DSP 3 MUX -------------------------
    DSP3_A_IN <= to_signed(1, 30)                when DSP3_A_MUX = B"00" else
                 resize(WEIGHT_PP(0) , 30)       when DSP3_A_MUX = B"01" else
                 resize(signed(COEFF_0), 30)     when DSP3_A_MUX = B"10" else
                 resize(signed(COEFF_1), 30);

    DSP3_B_IN <= to_signed(1, 18)                when DSP3_B_MUX = B"00" else
                 resize(WEIGHT_PP(0) , 18)       when DSP3_B_MUX = B"01" else
                 resize(signed(LUT_DOUT), 18)    when DSP3_B_MUX = B"10" else
                 resize(signed(COEFF_3), 18);

    DSP3_C_IN <= to_signed(0, 48)                when DSP3_C_MUX = B"00" else
                 WEIGHT_ALIGNED                  when DSP3_C_MUX = B"01" else
                 signed(resize(TRACE_PRE_PP(0) ,48)) when DSP3_C_MUX = B"10" else
                 resize(signed(COEFF_3), 48);

    DSP3_D_IN <= to_signed(1, 25)                when DSP3_D_MUX = B"00" else
                 resize(WEIGHT_PP(0) , 25)       when DSP3_D_MUX = B"01" else
                 resize(signed(COEFF_0), 25)     when DSP3_D_MUX = B"10" else
                 resize(signed(COEFF_1), 25);

    -- ------------------------- DSP 4 MUX -------------------------
    DSP4_A_IN <= to_signed(1, 30)                when DSP4_A_MUX = B"00" else
                 resize(WEIGHT_PP(0) , 30)           when DSP4_A_MUX = B"01" else
                 resize(signed(COEFF_0), 30)     when DSP4_A_MUX = B"10" else
                 resize(signed(COEFF_1), 30);

    DSP4_B_IN <= to_signed(1, 18)                when DSP4_B_MUX = B"00" else
                 resize(WEIGHT_PP(0) , 18)       when DSP4_B_MUX = B"01" else
                 resize(signed(LUT_DOUT), 18)    when DSP4_B_MUX = B"10" else
                 resize(signed(COEFF_3), 18);

    DSP4_C_IN <= to_signed(0, 48)                when DSP4_C_MUX = B"00" else
                 WEIGHT_ALIGNED                  when DSP4_C_MUX = B"01" else
                 signed(resize(TRACE_PRE_PP(0) ,48)) when DSP4_C_MUX = B"10" else
                 resize(signed(COEFF_3), 48);

    DSP4_D_IN <= to_signed(1, 25)                when DSP4_D_MUX = B"00" else
                 resize(WEIGHT_PP(0) , 25)       when DSP4_D_MUX = B"01" else
                 resize(signed(COEFF_0), 25)     when DSP4_D_MUX = B"10" else
                 resize(signed(COEFF_1), 25);

    DSP_1 : DSP48E1 
    generic map ( 
        USE_MULT => "DYNAMIC", 
        USE_SIMD => "ONE48", 
        USE_DPORT => TRUE,   
        A_INPUT => "DIRECT", 
        B_INPUT => "DIRECT", 
        AREG => 1, BREG => 1, CREG => 1, DREG => 1, MREG => 1, PREG => 1,
        ADREG => 1      
    )
    port map (
        CLK => CLK, 
        OPMODE => DSP1_OPMODE, INMODE => DSP1_INMODE, ALUMODE => DSP1_ALUMODE, 
        A => std_logic_vector(DSP1_A_IN), B => std_logic_vector(DSP1_B_IN), 
        C => std_logic_vector(DSP1_C_IN_REG), D => std_logic_vector(DSP1_D_IN), 
        PCOUT => PCOUT_1_TO_2, P => open,
        
        CEA1 => '0', CEA2 => '1', CEB1 => '0', CEB2 => '1', CEC => '1', CED => '1', 
        CEAD => '1', CEM => '1', CEP => '1', CEALUMODE => '1', CECTRL => '1', CEINMODE => '1', 
        RSTA => RST, RSTB => RST, RSTC => RST, RSTD => RST, RSTM => RST, RSTP => RST, 
        RSTALUMODE => RST, RSTCTRL => RST, RSTINMODE => RST, 
        
        CECARRYIN => '0', RSTALLCARRYIN => RST, CARRYIN => '0', CARRYCASCIN => '0', 
        MULTSIGNIN => '0', ACIN => (others => '0'), BCIN => (others => '0'), PCIN => (others => '0'), 
        CARRYINSEL => "000", ACOUT => open, BCOUT => open, CARRYCASCOUT => open, 
        MULTSIGNOUT => open, OVERFLOW => open, PATTERNBDETECT => open, PATTERNDETECT => open, 
        UNDERFLOW => open, CARRYOUT => open
    );

    DSP_2 : DSP48E1 
    generic map ( 
        USE_MULT => "DYNAMIC", 
        USE_SIMD => "ONE48", 
        USE_DPORT => TRUE,   
        A_INPUT => "DIRECT", 
        B_INPUT => "DIRECT", 
        AREG => 1, BREG => 1, CREG => 1, DREG => 1, MREG => 1, PREG => 1,
        ADREG => 1      
    )
    port map (
        CLK => CLK, 
        OPMODE => DSP2_OPMODE, INMODE => DSP2_INMODE, ALUMODE => DSP2_ALUMODE, 
        A => std_logic_vector(DSP2_A_IN), B => std_logic_vector(DSP2_B_IN), 
        C => std_logic_vector(DSP2_C_IN_REG), D => std_logic_vector(DSP2_D_IN), 
        PCIN => PCOUT_1_TO_2, P => POUT_DSP2, PCOUT => open, 
        
        CEA1 => '0', CEA2 => '1', CEB1 => '0', CEB2 => '1', CEC => '1', CED => '1', 
        CEAD => '1', CEM => '1', CEP => '1', CEALUMODE => '1', CECTRL => '1', CEINMODE => '1', 
        RSTA => RST, RSTB => RST, RSTC => RST, RSTD => RST, RSTM => RST, RSTP => RST, 
        RSTALUMODE => RST, RSTCTRL => RST, RSTINMODE => RST, 
        
        CECARRYIN => '0', RSTALLCARRYIN => RST, CARRYIN => '0', CARRYCASCIN => '0', 
        MULTSIGNIN => '0', ACIN => (others => '0'), BCIN => (others => '0'), 
        CARRYINSEL => "000", ACOUT => open, BCOUT => open, CARRYCASCOUT => open, 
        MULTSIGNOUT => open, OVERFLOW => open, PATTERNBDETECT => open, PATTERNDETECT => open, 
        UNDERFLOW => open, CARRYOUT => open
    );

    DSP_3 : DSP48E1 
    generic map ( 
        USE_MULT => "DYNAMIC", 
        USE_SIMD => "ONE48", 
        USE_DPORT => TRUE,  
        A_INPUT => "DIRECT", 
        B_INPUT => "DIRECT", 
        AREG => 1, BREG => 1, CREG => 1, DREG => 1, MREG => 1, PREG => 1,
        ADREG => 1      
    )
    port map (
        CLK => CLK, 
        OPMODE => DSP3_OPMODE, INMODE => DSP3_INMODE, ALUMODE => DSP3_ALUMODE, 
        A => std_logic_vector(DSP3_A_IN), B => std_logic_vector(DSP3_B_IN), 
        C => std_logic_vector(DSP3_C_IN_REG), D => std_logic_vector(DSP3_D_IN), 
        PCOUT => PCOUT_3_TO_4, P => open,
        
        CEA1 => '0', CEA2 => '1', CEB1 => '0', CEB2 => '1', CEC => '1', CED => '1', 
        CEAD => '1', CEM => '1', CEP => '1', CEALUMODE => '1', CECTRL => '1', CEINMODE => '1', 
        RSTA => RST, RSTB => RST, RSTC => RST, RSTD => RST, RSTM => RST, RSTP => RST, 
        RSTALUMODE => RST, RSTCTRL => RST, RSTINMODE => RST, 
        
        CECARRYIN => '0', RSTALLCARRYIN => RST, CARRYIN => '0', CARRYCASCIN => '0', 
        MULTSIGNIN => '0', ACIN => (others => '0'), BCIN => (others => '0'), PCIN => (others => '0'), 
        CARRYINSEL => "000", ACOUT => open, BCOUT => open, CARRYCASCOUT => open, 
        MULTSIGNOUT => open, OVERFLOW => open, PATTERNBDETECT => open, PATTERNDETECT => open, 
        UNDERFLOW => open, CARRYOUT => open
    );

    DSP_4 : DSP48E1 
    generic map ( 
        USE_MULT => "DYNAMIC", 
        USE_SIMD => "ONE48", 
        USE_DPORT => TRUE,   
        A_INPUT => "DIRECT", 
        B_INPUT => "DIRECT", 
        AREG => 1, BREG => 1, CREG => 1, DREG => 1, MREG => 1, PREG => 1,
        ADREG => 1      
    )
    port map (
        CLK => CLK, 
        OPMODE => DSP4_OPMODE, INMODE => DSP4_INMODE, ALUMODE => DSP4_ALUMODE, 
        PCIN => PCOUT_3_TO_4, A => std_logic_vector(DSP4_A_IN), B => std_logic_vector(DSP4_B_IN), 
        C => std_logic_vector(DSP4_C_IN_REG), D => std_logic_vector(DSP4_D_IN), 
        P => POUT_DSP4, PCOUT => open,
        
        CEA1 => '0', CEA2 => '1', CEB1 => '0', CEB2 => '1', CEC => '1', CED => '1', 
        CEAD => '1', CEM => '1', CEP => '1', CEALUMODE => '1', CECTRL => '1', CEINMODE => '1', 
        RSTA => RST, RSTB => RST, RSTC => RST, RSTD => RST, RSTM => RST, RSTP => RST, 
        RSTALUMODE => RST, RSTCTRL => RST, RSTINMODE => RST, 
        
        CECARRYIN => '0', RSTALLCARRYIN => RST, CARRYIN => '0', CARRYCASCIN => '0', 
        MULTSIGNIN => '0', ACIN => (others => '0'), BCIN => (others => '0'), 
        CARRYINSEL => "000", ACOUT => open, BCOUT => open, CARRYCASCOUT => open, 
        MULTSIGNOUT => open, OVERFLOW => open, PATTERNBDETECT => open, PATTERNDETECT => open, 
        UNDERFLOW => open, CARRYOUT => open
    );

    TRACE_CALC : process(CLK)
    begin
        if rising_edge(CLK) then

            if RST = '1' then

                TRACE_1_CALC <= (others=>'0');
                TRACE_2_CALC <= (others=>'0');

            else

                case TRACE_1_OP is
                    when B"001" =>
                        if resize(TRACE_PRE_PP(7), 9) + resize(unsigned(TRACE_1_CONST), 9) > 255 then
                            TRACE_1_CALC <= to_unsigned(255, 8);
                        else
                            TRACE_1_CALC <= TRACE_PRE_PP(7) + unsigned(TRACE_1_CONST);
                        end if;
                    when B"010" =>
                        if TRACE_PRE_PP(7) < unsigned(TRACE_1_CONST) then
                            TRACE_1_CALC <= to_unsigned(0, 8);
                        else
                            TRACE_1_CALC <= TRACE_PRE_PP(7) - unsigned(TRACE_1_CONST);
                        end if;
                    when B"011" =>
                        TRACE_1_CALC <= to_unsigned(0, 8);
                    when B"100" =>
                        TRACE_1_CALC <= to_unsigned(255, 8);
                    when others =>
                        TRACE_1_CALC <= TRACE_PRE_PP(7);
                end case;

                case TRACE_2_OP is
                    when B"001" =>
                        if resize(TRACE_PRE_PP(7), 9) + resize(unsigned(TRACE_2_CONST), 9) > 255 then
                            TRACE_2_CALC <= to_unsigned(255, 8);
                        else
                            TRACE_2_CALC <= TRACE_PRE_PP(7) + unsigned(TRACE_2_CONST);
                        end if;
                    when B"010" =>
                        if TRACE_PRE_PP(7) < unsigned(TRACE_2_CONST) then
                            TRACE_2_CALC <= to_unsigned(0, 8);
                        else
                            TRACE_2_CALC <= TRACE_PRE_PP(7) - unsigned(TRACE_2_CONST);
                        end if;
                    when B"011" =>
                        TRACE_2_CALC <= to_unsigned(0, 8);
                    when B"100" =>
                        TRACE_2_CALC <= to_unsigned(255, 8);
                    when others =>
                        TRACE_2_CALC <= TRACE_PRE_PP(7);
                end case;

            end if;

        end if;

    end process TRACE_CALC;

    FINAL_WP : process(CLK)
    begin
        if rising_edge(CLK) then

            if RST = '1' then

                W_SELECTED <= (others=>'0');
                W_SHIFTED  <= (others=>'0');
                W_INT8     <= (others=>'0');
                W_CLIPPED  <= (others=>'0');

            else

                if COND_1_PP(4) = '1' then
                    W_SELECTED <=  signed(POUT_DSP2);
                elsif  COND_2_PP(4) = '1' then
                    W_SELECTED <= signed(POUT_DSP4);
                else 
                    W_SELECTED <= resize(WEIGHT_PP(4), 48);
                end if;

                if COND_1_PP(5) = '0' and COND_2_PP(5) = '0' then
                    W_SHIFTED <= W_SELECTED(23 downto 0);
                else
                    W_SHIFTED <= shift_right(W_SELECTED(23 downto 0), OUT_SHIFT_VAL);
                end if;

               -- W_SHIFTED <= shift_right(W_SELECTED(23 downto 0), OUT_SHIFT_VAL);

                if W_SHIFTED > 127  then
                    W_INT8 <= to_signed(127, 8);
                elsif W_SHIFTED < -128 then
                    W_INT8 <= to_signed(-128, 8);
                else
                    W_INT8 <= W_SHIFTED(7 downto 0);
                end if;              

                if W_INT8 > signed(COEFF_0(7 downto 0)) then
                    W_CLIPPED <= signed(COEFF_0(7 downto 0));
                elsif W_INT8 < signed(COEFF_1(7 downto 0)) then
                    W_CLIPPED <= signed(COEFF_1(7 downto 0));
                else
                    W_CLIPPED <= W_INT8;
                end if;     

            end if;

        end if;

    end process FINAL_WP;

    T_SELECTED <= 
                TRACE_1_CALC          when COND_1_PP(8) = '1' else
                TRACE_2_CALC          when COND_2_PP(8) = '1' else
                to_unsigned(255, 8)   when TRACE_PRE_PP(8) = 255 else
                TRACE_PRE_PP(8) + 1; 


    SYN_DATA_OUT(15 downto 8) <= std_logic_vector(W_CLIPPED);
    SYN_DATA_OUT(7 downto 0) <= std_logic_vector(T_SELECTED);
    SYN_DOUT_VLD <= VLD_PP(8);

    SYNAPSE_WRITE_ADDRESS <= std_logic_vector(to_unsigned(SYNAPSE_START_ADDRESS_INT,MEMWIDTH));
    
    ADDR_COUNTER : process(clk)
        begin
            if rising_edge(CLK) then

                if RST = '1' then
                    SYNAPSE_START_ADDRESS_INT <= to_integer(unsigned(SYNAPSE_START_ADDRESS));
                else
                    if VLD_PP(8) = '1' then
                        SYNAPSE_START_ADDRESS_INT <= SYNAPSE_START_ADDRESS_INT + 1;
                    end if;
                end if;

            end if;
    end process ADDR_COUNTER;

end rtl;