library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
Library UNISIM;
use UNISIM.vcomponents.all;

entity XBAR_PRIMITIVE_2x4 is
  Generic(
          SPIKE_PIPELINE_REGS  : integer range 0 to 1:= 1;
          OUTPUT_PIPELINE_REGS : integer range 0 to 1:= 1;
          ROW_1_PIPELINE_REGS  : integer range 0 to 1:= 1;
          ROW_2_PIPELINE_REGS  : integer range 0 to 1:= 1
        );
  Port ( 
        XBAR_CLK     : in  std_logic;
        XBAR_CLR     : in  std_logic;
        SPIKE_IN_0   : in  std_logic;
        SPIKE_IN_1   : in  std_logic;
        ROW0_CE      : in  std_logic;
        ROW1_CE      : in  std_logic;
        W00          : in  std_logic_vector(7  downto 0);
        W01          : in  std_logic_vector(7  downto 0);
        W02          : in  std_logic_vector(7  downto 0);
        W03          : in  std_logic_vector(7  downto 0);
        W10          : in  std_logic_vector(7  downto 0);
        W11          : in  std_logic_vector(7  downto 0);
        W12          : in  std_logic_vector(7  downto 0);
        W13          : in  std_logic_vector(7  downto 0);
        PE_OUT_0     : out std_logic_vector(15  downto 0);
        PE_OUT_1     : out std_logic_vector(15  downto 0);
        PE_OUT_2     : out std_logic_vector(15  downto 0);
        PE_OUT_3     : out std_logic_vector(15  downto 0)
        );
end XBAR_PRIMITIVE_2x4;

architecture bonfire of XBAR_PRIMITIVE_2x4 is

    signal EXT_WEIGHT_IN_0  : std_logic_vector(11 downto 0);
    signal EXT_WEIGHT_IN_1  : std_logic_vector(11 downto 0);
    signal EXT_WEIGHT_IN_2  : std_logic_vector(11 downto 0);
    signal EXT_WEIGHT_IN_3  : std_logic_vector(11 downto 0);

    signal EXT_PE_IN_0  : std_logic_vector(11 downto 0);
    signal EXT_PE_IN_1  : std_logic_vector(11 downto 0);
    signal EXT_PE_IN_2  : std_logic_vector(11 downto 0);
    signal EXT_PE_IN_3  : std_logic_vector(11 downto 0);

    -- DSP48E1 Control Signals

    constant CEAD          : std_logic:='0';  -- 1-bit input: Clock enable input for ADREG
    constant CEALUMODE     : std_logic:='1';  -- 1-bit input: Clock enable input for ALUMODE
    constant CEC           : std_logic:='1';  -- 1-bit input: Clock enable input for CREG
    constant CECARRYIN     : std_logic:='0';  -- 1-bit input: Clock enable input for CARRYINREG
    constant CECTRL        : std_logic:='1';  -- 1-bit input: Clock enable input for OPMODEREG and CARRYINSELREG
    constant CED           : std_logic:='0';  -- 1-bit input: Clock enable input for DREG
    constant CEINMODE      : std_logic:='0';  -- 1-bit input: Clock enable input for INMODEREG
    constant CEM           : std_logic:='0';  -- 1-bit input: Clock enable input for MREG
    constant CEP           : std_logic:='1';  -- 1-bit input: Clock enable input for PREG

    signal A             : std_logic_vector(29 downto 0); -- 30-bit input: A data input
    signal B             : std_logic_vector(17 downto 0); -- 18-bit input: B data input
    signal C             : std_logic_vector(47 downto 0); -- 48-bit input: C data input
    constant D           : std_logic_vector(24 downto 0) := (others=>'0'); -- 25-bit input: D data input
    signal P             : std_logic_vector(47 downto 0); -- 48-bit output: P data output
    signal OPMODE        : std_logic_vector(6 downto 0);  -- OPMODE

begin

    EXT_WEIGHT_IN_0 <= W00(7)&W00(7)&W00(7)&W00(7)&W00;
    EXT_WEIGHT_IN_1 <= W01(7)&W01(7)&W01(7)&W01(7)&W01;
    EXT_WEIGHT_IN_2 <= W02(7)&W02(7)&W02(7)&W02(7)&W02;
    EXT_WEIGHT_IN_3 <= W03(7)&W03(7)&W03(7)&W03(7)&W03;

    EXT_PE_IN_0 <= W10(7)&W10(7)&W10(7)&W10(7)&W10;  
    EXT_PE_IN_1 <= W11(7)&W11(7)&W11(7)&W11(7)&W11; 
    EXT_PE_IN_2 <= W12(7)&W12(7)&W12(7)&W12(7)&W12; 
    EXT_PE_IN_3 <= W13(7)&W13(7)&W13(7)&W13(7)&W13; 

    C <= EXT_PE_IN_0 & EXT_PE_IN_1 & EXT_PE_IN_2 & EXT_PE_IN_3;
    A <= EXT_WEIGHT_IN_0 & EXT_WEIGHT_IN_1 & EXT_WEIGHT_IN_2(11 downto 6);
    B <= EXT_WEIGHT_IN_2(5 downto 0) & EXT_WEIGHT_IN_3;

    OPMODE(0) <= SPIKE_IN_0;
    OPMODE(1) <= SPIKE_IN_0;
    OPMODE(3 downto 2) <= (others=>'0');
    OPMODE(4) <= SPIKE_IN_1;
    OPMODE(5) <= SPIKE_IN_1;
    OPMODE(6) <= '0';
   
   PE_OUT_3 <= P(11)&P(11)&P(11)&P(11)&P(11 downto 0);
   PE_OUT_2 <= P(23)&P(23)&P(23)&P(23)&P(23 downto 12);
   PE_OUT_1 <= P(35)&P(35)&P(35)&P(35)&P(35 downto 24);
   PE_OUT_0 <= P(47)&P(47)&P(47)&P(47)&P(47 downto 36);

   DSP48E1_inst : DSP48E1
    generic map (
       -- Feature Control Attributes: Data Path Selection
       A_INPUT => "DIRECT",               -- Selects A input source, "DIRECT" (A port) or "CASCADE" (ACIN port)
       B_INPUT => "DIRECT",               -- Selects B input source, "DIRECT" (B port) or "CASCADE" (BCIN port)
       USE_DPORT => FALSE,                -- Select D port usage (TRUE or FALSE)
       USE_MULT => "NONE",                 -- Select multiplier usage ("MULTIPLY", "DYNAMIC", or "NONE")
       USE_SIMD => "FOUR12",               -- SIMD selection ("ONE48", "TWO24", "FOUR12")
       -- Pattern Detector Attributes: Pattern Detection Configuration
       AUTORESET_PATDET => "NO_RESET",    -- "NO_RESET", "RESET_MATCH", "RESET_NOT_MATCH" 
       MASK => X"3fffffffffff",           -- 48-bit mask value for pattern detect (1=ignore)
       PATTERN => X"000000000000",        -- 48-bit pattern match for pattern detect
       SEL_MASK => "MASK",                -- "C", "MASK", "ROUNDING_MODE1", "ROUNDING_MODE2" 
       SEL_PATTERN => "PATTERN",          -- Select pattern value ("PATTERN" or "C")
       USE_PATTERN_DETECT => "NO_PATDET", -- Enable pattern detect ("PATDET" or "NO_PATDET")
       -- Register Control Attributes: Pipeline Register Configuration
       ACASCREG => ROW_1_PIPELINE_REGS,                     -- Number of pipeline stages between A/ACIN and ACOUT (0, 1 or 2)
       ADREG => 0,                        -- Number of pipeline stages for pre-adder (0 or 1)
       ALUMODEREG => 1,                   -- Number of pipeline stages for ALUMODE (0 or 1)
       AREG => ROW_1_PIPELINE_REGS,       -- Number of pipeline stages for A (0, 1 or 2)
       BCASCREG => ROW_1_PIPELINE_REGS,                     -- Number of pipeline stages between B/BCIN and BCOUT (0, 1 or 2)
       BREG => ROW_1_PIPELINE_REGS,       -- Number of pipeline stages for B (0, 1 or 2)
       CARRYINREG => 0,                   -- Number of pipeline stages for CARRYIN (0 or 1)
       CARRYINSELREG => 0,                -- Number of pipeline stages for CARRYINSEL (0 or 1)
       CREG => ROW_2_PIPELINE_REGS,       -- Number of pipeline stages for C (0 or 1)
       DREG => 0,                         -- Number of pipeline stages for D (0 or 1)
       INMODEREG => 0,                    -- Number of pipeline stages for INMODE (0 or 1)
       MREG => 0,                         -- Number of multiplier pipeline stages (0 or 1)
       OPMODEREG => SPIKE_PIPELINE_REGS,  -- Number of pipeline stages for OPMODE (0 or 1)
       PREG => OUTPUT_PIPELINE_REGS       -- Number of pipeline stages for P (0 or 1)
    )
    port map (
       P => P,                           -- 48-bit output: Primary data output
       -- Cascade: 30-bit (each) input: Cascade Ports
       ACIN => (others=>'0'),                     -- 30-bit input: A cascade data input
       BCIN => (others=>'0'),                     -- 18-bit input: B cascade input
       CARRYCASCIN => '0',       -- 1-bit input: Cascade carry input
       MULTSIGNIN => '0',         -- 1-bit input: Multiplier sign input
       PCIN => (others=>'0'),                     -- 48-bit input: P cascade input
       -- Control: 4-bit (each) input: Control Inputs/Status Bits
       ALUMODE => (others=>'0'),               -- 4-bit input: ALU control input
       CARRYINSEL => (others=>'0'),         -- 3-bit input: Carry select input
       CLK => XBAR_CLK,                       -- 1-bit input: Clock input
       INMODE => (others=>'0'),                 -- 5-bit input: INMODE control input
       OPMODE => OPMODE,                 -- 7-bit input: Operation mode input
       -- Data: 30-bit (each) input: Data Ports
       A => A,                           -- 30-bit input: A data input
       B => B,                           -- 18-bit input: B data input
       C => C,                           -- 48-bit input: C data input
       CARRYIN => '0',               -- 1-bit input: Carry input signal
       D => D,                           -- 25-bit input: D data input
       -- Reset/Clock Enable: 1-bit (each) input: Reset/Clock Enable Inputs
       CEA1 => ROW0_CE,                     -- 1-bit input: Clock enable input for 1st stage AREG
       CEA2 => ROW0_CE,                     -- 1-bit input: Clock enable input for 2nd stage AREG
       CEAD => CEAD,                     -- 1-bit input: Clock enable input for ADREG
       CEALUMODE => CEALUMODE,           -- 1-bit input: Clock enable input for ALUMODE
       CEB1 => ROW0_CE,                     -- 1-bit input: Clock enable input for 1st stage BREG
       CEB2 => ROW0_CE,                     -- 1-bit input: Clock enable input for 2nd stage BREG
       CEC => ROW1_CE,                       -- 1-bit input: Clock enable input for CREG
       CECARRYIN => CECARRYIN,           -- 1-bit input: Clock enable input for CARRYINREG
       CECTRL => CECTRL,                 -- 1-bit input: Clock enable input for OPMODEREG and CARRYINSELREG
       CED => '0',                       -- 1-bit input: Clock enable input for DREG
       CEINMODE => CEINMODE,             -- 1-bit input: Clock enable input for INMODEREG
       CEM => CEM,                       -- 1-bit input: Clock enable input for MREG
       CEP => CEP,                       -- 1-bit input: Clock enable input for PREG
       RSTA => XBAR_CLR,                     -- 1-bit input: Reset input for AREG
       RSTALLCARRYIN => XBAR_CLR,   -- 1-bit input: Reset input for CARRYINREG
       RSTALUMODE => XBAR_CLR,         -- 1-bit input: Reset input for ALUMODEREG
       RSTB => XBAR_CLR,                     -- 1-bit input: Reset input for BREG
       RSTC => XBAR_CLR,                     -- 1-bit input: Reset input for CREG
       RSTCTRL => XBAR_CLR,               -- 1-bit input: Reset input for OPMODEREG and CARRYINSELREG
       RSTD => '0',                     -- 1-bit input: Reset input for DREG and ADREG
       RSTINMODE => XBAR_CLR,           -- 1-bit input: Reset input for INMODEREG
       RSTM => XBAR_CLR,                     -- 1-bit input: Reset input for MREG
       RSTP => XBAR_CLR                      -- 1-bit input: Reset input for PREG
    );
end bonfire;