
--                                            NMC OPCODES (4-BIT)
--   _______________________________________________________________________________________________________________________________
--   |      CODE                 |   ASM    |    BIN    |    SYNTAX (x: Register (3-Bits), M:Memory(x:MEM ADDR))    |    Cycles     |        
--   |---------------------------|----------|-----------|-----------------------------------------------------------|---------------|
--   |  RESERVED                 |   ---    |    0000   |                           ----                            |      ---      |
--   |  LOAD  WORD               |   LW     |    0001   |                        lw x1,M(x)                         |       4       |
--   |  STORE WORD               |   SW     |    0010   |                        sw x1,M(x)                         |       3       |
--   |  GET ACCUMMULATOR         |   GACC   |    0011   |                          gacc x1                          |       5       |
--   |  FP16 MULTIPLY-ACCUMULATE |   FMAC   |    0100   |                       fmac   x1,x2                        |       4       |
--   |  FP16 MULTIPLY-SUBTRACT   |   SMAC   |    0101   |                       smac   x1,x2                        |       4       |
--   |  CLEAR ACCUMMULATOR       |   CACC   |    0110   |                     FMAC_OPC <= "10"                      |       1       |
--   |  COMPARE                  |   COMP   |    0111   |                        comp x1,x2                         |       1       |
--   |  BRANCH-IF-LESS           |   BIL    |    1000   |                     bil LESS_FLAG,PC_INC                  |       1       |
--   |  BRANCH-IF-EQUAL          |   BIE    |    1001   |                     bie EQUAL_FLAG,PC_INC                 |       1       |
--   |  BRANCH-IF-GREAT          |   BIG    |    1010   |                     big GREAT_FLAG,PC_INC                 |       1       |
--   |  SEND SPIKE               |   SPK    |    1011   |            NMC_NMODEL_SPIKE_OUT <= '1', R_LST = 0         |       1       |
--   |  RESERVED                 |   ---    |    1100   |                           ----                            |      ---      |   
--   |  PROGRAM FLOW COMPLT      |   RETURN |    1101   |                       NMC_DONE <= '1'                     |       1       |
--   |  SET REFRACTORY PERIOD    |   STRF   |    1110   |          NMC_NMODEL_REF_PERIOD <= NMODEL_REF_PERIOD       |       1       |
--   |  RESERVED                 |   ---    |    1111   |                           ----                            |      ---      |
--   |___________________________|__________|___________|___________________________________________________________|_______________|   
--                
--
--   EXAMPLES FOR ALL TYPES OF INSTRUCTIONS 
--   ____________________________________________________________________________________________________________________________________________
--   | ASM          | BINARY(TRUE FORM)           | EXPLANATION                                                                                  |
--   |______________|_____________________________|______________________________________________________________________________________________|
--   | lw,x4,X"123" | "0001"&"100"&"001111011"    | Read memory address 'NMC_XNEVER_REGION_BASEADDR+123' and write the data to x4 register       |
--   | sw,x2,X"242" | "0010"&"010"&"011110010"    | Read register x2 and write its data to memory location 'NMC_XNEVER_REGION_BASEADDR+242'      |
--   | gacc,x5      | "0011"&"101"&"XXXXXXXXX"    | Save the accumulator value to the x5 register                                                |
--   | fmac,x2,x3   | "0100"&"XXXXXX"&"010"&"011" | Multiply x2,x3 and add the result to the accummulator                                        |
--   | smac,x2,x3   | "0101"&"XXXXXX"&"010"&"011" | Multiply x2,x3 and subtract the result from the accummulator                                 |
--   | cacc         | "0110"&"XXXXXXXXXXXX"       | Clear the accummulator                                                                       |
--   | comp,x2,x4   | "0111"&"XXXXXX"&"010"&"100" | Compare x2 register value to x4 register value                                               |
--   | bil,"14"     | "1000"&"XX"&"0000001110"    | Increment program counter by 14 if less flag is HIGH                                         |
--   | bie,"14"     | "1001"&"XX"&"0000001110"    | Increment program counter by 14 if equal flag is HIGH                                        |
--   | big,"14"     | "1010"&"XX"&"0000001110"    | Increment program counter by 14 if great flag is HIGH                                        |
--   | spk          | "1011"&"XXXXXXXXXXXX"       | Creates a spike message via setting NMC_NMODEL_SPIKE_OUT flag HIGH                           |
--   | return       | "1101"&"XXXXXXXXXXXX"       | Finishes the program. Raises the NMC_DONE flag.                                              |
--   | strf,"27"    | "1110"&"XXXX"&"00011011"    | Sets refractory period for 27 timesteps. When LAST_SPIKE_TIME equal to 27 in                 |
--   |              |                             | further iterations after refractory, refractory register asserts to zero automatically.      |
--   |______________|_____________________________|______________________________________________________________________________________________|
--              REG_STACK
--    GPR  : GENERAL PURPOSE REGISTER
--    UD   : USER DEFINED
--   ____________________________________________________
--   |  ADDR   |   TYPE   |  VAL(HEX)                    |
--   |---------|----------|------------------------------|
--   |  x0     |  GPR     |    UD                        |
--   |  x1     |  GPR     |    UD                        |  
--   |  x2     |  GPR     |    UD                        |
--   |  x3     |  GPR     |    UD                        |
--   |  x4     |  GPR     |    UD                        |
--   |  x5     |  GPR     |    UD                        |
--   |  x6     |  GPR     |    UD                        |
--   |  x7     |  GPR     |    UD                        |
--   |_________|__________|______________________________|


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
Library UNISIM;
use UNISIM.vcomponents.all;
Library UNIMACRO;
use UNIMACRO.vcomponents.all;

entity NMC is
    Port ( 
            NMC_CLK                     : in   std_logic; 
            NMC_STATE_RST               : in   std_logic; 
            FMAC_EXTERN_RST             : in   std_logic;
            NMC_HARD_RST                : in   std_logic; 
            NMC_COLD_START              : in   std_logic; 
            PARTIAL_CURRENT_RDY         : in   std_logic;
            NMC_XNEVER_REGION_BASEADDR  : in   std_logic_vector(9 downto 0);
            NMC_XNEVER_REGION_HIGHADDR  : in   std_logic_vector(9 downto 0);
            NMODEL_LAST_SPIKE_TIME      : in   STD_LOGIC_VECTOR(7  DOWNTO 0); 
            NMODEL_SYN_QFACTOR          : in   STD_LOGIC_VECTOR(15 DOWNTO 0); 
            NMODEL_PF_LOW_ADDR          : in   STD_LOGIC_VECTOR(9  DOWNTO 0); 
            NMODEL_NPARAM_DATA          : in   STD_LOGIC_VECTOR(15 DOWNTO 0);
            NMODEL_NPARAM_ADDR          : in   STD_LOGIC_VECTOR(9  DOWNTO 0);
            NMODEL_REFRACTORY_DUR       : in   std_logic_vector(7  downto 0);
            NMODEL_PROG_MEM_PORTA_EN    : in   STD_LOGIC;
            NMODEL_PROG_MEM_PORTA_WEN   : in   STD_LOGIC;
            NMC_NMODEL_PSUM_IN          : in   std_logic_vector(15 downto 0);
            NMC_NMODEL_SPIKE_OUT        : out  std_logic; 
            NMC_NMODEL_SPIKE_VLD        : out  std_logic; 
            R_NNMODEL_NEW_SPIKE_TIME    : out  std_logic_vector(7  downto 0);
            R_NMODEL_NPARAM_DATAOUT     : OUT  STD_LOGIC_VECTOR(15 DOWNTO 0);
            R_NMODEL_REFRACTORY_DUR     : OUT  std_logic_vector(7  downto 0);
            REDIST_NMODEL_PORTB_TKOVER  : in   std_logic;
            REDIST_NMODEL_DADDR         : in   std_logic_vector(9 downto 0);
            NMC_NMODEL_FINISHED         : out std_logic;
            NMC_MATH_ERROR              : out std_logic;
            NMC_MEMORY_VIOLATION        : out std_logic
    );
end NMC;

architecture dance_me_to_the_end_of_love of NMC is

    component FMAC16 is
        Port(
            CLK    : in  std_logic;
            RST    : in  std_logic;
            START  : in  std_logic;
            A      : in  std_logic_vector(15 downto 0);
            B      : in  std_logic_vector(15 downto 0);
            ACC    : out std_logic_vector(15 downto 0);
            OPC    : in  std_logic_vector( 1 downto 0);
            NAN    : out std_logic
        );
    end component FMAC16;

    signal FMAC16_CLK    : std_logic;
    signal FMAC16_RST    : std_logic;
    signal FMAC16_START  : std_logic;
    signal FMAC16_A      : std_logic_vector(15 downto 0);
    signal FMAC16_B      : std_logic_vector(15 downto 0);
    signal FMAC16_A_S0   : std_logic_vector(15 downto 0);
    signal FMAC16_B_S0   : std_logic_vector(15 downto 0);
    signal FMAC16_ACC    : std_logic_vector(15 downto 0);
    signal FMAC16_OPC    : std_logic_vector( 1 downto 0);
    signal FMAC16_NAN    : std_logic;
    
    component NMC_LOC_REGSPACE IS
    PORT(
         RST       : IN  STD_LOGIC;   
         CLK       : IN  STD_LOGIC;
         RD_ADDR_0 : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);
         RD_ADDR_1 : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);
         WR_ADDR   : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);
         WR_EN     : IN  STD_LOGIC;
         DATA_IN   : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
         DOUT_0    : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
         DOUT_1    : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
        );
    END component;

    signal NMC_REGSPACE_RST       : STD_LOGIC;   
    signal NMC_REGSPACE_CLK       : STD_LOGIC;
    signal NMC_REGSPACE_RD_ADDR_0 : STD_LOGIC_VECTOR(2 DOWNTO 0);
    signal NMC_REGSPACE_RD_ADDR_1 : STD_LOGIC_VECTOR(2 DOWNTO 0);
    signal NMC_REGSPACE_WR_ADDR   : STD_LOGIC_VECTOR(2 DOWNTO 0);
    signal NMC_REGSPACE_WR_EN     : STD_LOGIC;
    signal NMC_REGSPACE_DATA_IN   : STD_LOGIC_VECTOR(15 DOWNTO 0);
    signal NMC_REGSPACE_DOUT_0    : STD_LOGIC_VECTOR(15 DOWNTO 0);
    signal NMC_REGSPACE_DOUT_1    : STD_LOGIC_VECTOR(15 DOWNTO 0);

    component HOUSEKEEPER is
        Port
            ( 
                HK_CLK              : in  std_logic;
                HK_RST              : in  std_logic;
                COLD_START          : in  std_logic;
                --
                PF_LOW              : in  std_logic_vector(9 downto 0);
                --
                XNEVER_BADDR        : in  std_logic_vector(9 downto 0);      
                XNEVER_HADDR        : in  std_logic_vector(9 downto 0);
                --
                REGSPACE_WR_EN      : out std_logic;
                REGSPACE_WR_ADDR    : out std_logic_vector(2 downto 0);
                REGSPACE_RD_ADDR_0  : out std_logic_vector(2 downto 0);
                REGSPACE_RD_ADDR_1  : out std_logic_vector(2 downto 0);
                REGSPACE_DIN_MUX    : out std_logic;
                --
                FMAC_MUX            : out std_logic;
                FMAC_START          : out std_logic;
                FMAC_OPC            : out std_logic_vector(1 downto 0);
                -- 
                EQ                  : in  std_logic;
                LE                  : in  std_logic;
                GR                  : in  std_logic;
                -- 
                MEM_ADDRB           : out std_logic_vector(9 downto 0);
                MEM_DOB             : in  std_logic_vector(15 downto 0);
                --
                MEM_WEA             : out std_logic;
                MEM_ADDRA           : out std_logic_vector(9 downto 0);
                --
                REF_DUR             : in  std_logic_vector(7 downto 0);
                NEW_REF_DUR         : out std_logic_vector(7 downto 0);
                --
                GENERATE_SPIKE      : out std_logic;
                SPK_VLD             : OUT STD_LOGIC;
                --
                -- 
                PROG_FLOW_COMPLETE  : out std_logic;
                --
                MEM_VIOLATION       : out std_logic
    
            );
    end component HOUSEKEEPER;
    
    component SS_2_HP is
    Port(
        CLK     : in  std_logic;
        RST     : in  std_logic;
        SS_IN   : in  std_logic_vector(15 downto 0); 
        HP_OUT  : out std_logic_vector(15 downto 0);
        START   : in  std_logic;
        DONE    : out std_logic
    );
    end component SS_2_HP;

    component COMP is --(NO?N1)
    Port (
            N0    : in std_logic_vector(15 downto 0);
            N1    : in std_logic_vector(15 downto 0);
            GREAT : out std_logic;
            LESS  : out std_logic;
            EQUAL : out std_logic
        );
    end component COMP;

    signal NMC_MEM_DOA      : std_logic_vector(15 downto 0);                  
    signal NMC_MEM_DOB      : std_logic_vector(15 downto 0);                  
    signal NMC_MEM_ADDRA    : std_logic_vector(9 downto 0);                   
    signal NMC_MEM_ADDRB    : std_logic_vector(9 downto 0);                   
    signal NMC_MEM_CLKA     : std_logic;                                      
    signal NMC_MEM_CLKB     : std_logic;                                      
    signal NMC_MEM_DIA      : std_logic_vector(15 downto 0);                  
    constant NMC_MEM_DIB    : std_logic_vector(15 downto 0) := (others=>'0'); 
    constant NMC_MEM_ENA    : std_logic := '1';                               
    constant NMC_MEM_ENB    : std_logic := '1';                               
    constant NMC_MEM_REGCEA : std_logic := '1';                               
    constant NMC_MEM_REGCEB : std_logic := '1';                               
    signal NMC_MEM_RSTA     : std_logic;                                      
    signal NMC_MEM_RSTB     : std_logic;                                      
    signal NMC_MEM_WEA      : std_logic_vector(1 downto 0);                   
    constant NMC_MEM_WEB    : std_logic_vector(1 downto 0) := (others=>'0');  

    signal HK_MEM_ADDRB    : std_logic_vector(9 downto 0); 

    signal REGSPACE_CONTROL_MUX : std_logic;
    signal FMAC16_PORT_MUX : std_logic;

    signal HK_XNEVER_BADDR : std_logic_vector(9 downto 0);      
    signal HK_XNEVER_HADDR : std_logic_vector(9 downto 0);

    signal HK_MEM_WEA     : std_logic;
    signal HK_MEM_ADDRA   : std_logic_vector(9 downto 0);

    signal COMP_EQ     : std_logic;
    signal COMP_LE     : std_logic;
    signal COMP_GR     : std_logic;

    signal GEN_SPK     : std_logic;

    signal PF_LOW_ADDR  : std_logic_vector(9 downto 0); 

    signal UPD_LAST_SPIKE_TIME : signed(7 downto 0);

    signal REG_NNMODEL_NEW_SPIKE_TIME : std_logic_vector(7  downto 0);
    signal REG_NMODEL_SYN_QFACTOR     : STD_LOGIC_VECTOR(15 DOWNTO 0); 
    signal REG_NMODEL_PF_LOW_ADDR     : STD_LOGIC_VECTOR(9  DOWNTO 0); 
    signal REG_NMODEL_NPARAM_DATAOUT  : STD_LOGIC_VECTOR(15 DOWNTO 0);
    signal REG_NMODEL_NPARAM_ADDROUT  : STD_LOGIC_VECTOR(9  DOWNTO 0);

    signal HP_OUT_REG                 : STD_LOGIC_VECTOR(15 DOWNTO 0);

    signal PARTIAL_CURRENT_MUX : std_logic;

    signal FMAC16_START_HK: std_logic;

    signal REFRACTORY_REGISTER       : std_logic_vector(7 downto 0);
    signal REFRACTORY_FLAG           : std_logic;

begin

    TCAST : SS_2_HP
    Port Map(
            CLK     => NMC_CLK             ,
            RST     => NMC_STATE_RST       ,
            SS_IN   => NMC_NMODEL_PSUM_IN  ,
            HP_OUT  => HP_OUT_REG          ,
            START   => PARTIAL_CURRENT_RDY ,
            DONE    => PARTIAL_CURRENT_MUX
        );


    FMAC16_INTF_PLINE : process(NMC_CLK) begin

                        if(rising_edge(NMC_CLK)) then

                            if(PARTIAL_CURRENT_MUX = '1' and REFRACTORY_FLAG = '0') then

                                FMAC16_A <= HP_OUT_REG ;
                                FMAC16_B <= REG_NMODEL_SYN_QFACTOR;

                            else

                                FMAC16_A <= FMAC16_A_S0 ;
                                FMAC16_B <= FMAC16_B_S0;
                                
                            end if;

                            if(PARTIAL_CURRENT_MUX = '1') then

                                FMAC16_START <= '1';

                            else

                                FMAC16_START <= FMAC16_START_HK;
                                
                            end if;

                        end if;

    end process FMAC16_INTF_PLINE;


FMAC16_CLK <= NMC_CLK;
FMAC16_RST <= FMAC16_OPC(1) or FMAC_EXTERN_RST;

    WORKHORSE : FMAC16
    Port Map(
            CLK   => FMAC16_CLK   ,
            RST   => FMAC16_RST   ,
            START => FMAC16_START ,
            A     => FMAC16_A     ,
            B     => FMAC16_B     ,
            ACC   => FMAC16_ACC   ,
            OPC   => FMAC16_OPC   ,
            NAN   => FMAC16_NAN   
        );

    NMC_MATH_ERROR <= FMAC16_NAN;

    NMC_REGSPACE_CLK <= NMC_CLK;
    NMC_REGSPACE_RST <= NMC_STATE_RST;

    REGS : NMC_LOC_REGSPACE
    PORT MAP(
             RST       => NMC_REGSPACE_RST      ,
             CLK       => NMC_REGSPACE_CLK      ,
             RD_ADDR_0 => NMC_REGSPACE_RD_ADDR_0,
             RD_ADDR_1 => NMC_REGSPACE_RD_ADDR_1,
             WR_ADDR   => NMC_REGSPACE_WR_ADDR  ,
             WR_EN     => NMC_REGSPACE_WR_EN    ,
             DATA_IN   => NMC_REGSPACE_DATA_IN  ,
             DOUT_0    => NMC_REGSPACE_DOUT_0   ,
             DOUT_1    => NMC_REGSPACE_DOUT_1   
            );

    COMPARATOR : COMP 
        Port Map (
                    N0    => NMC_REGSPACE_DOUT_0 ,
                    N1    => NMC_REGSPACE_DOUT_1 ,
                    GREAT => COMP_GR ,
                    LESS  => COMP_LE ,
                    EQUAL => COMP_EQ
                );

   NMC_MEM_CLKA <= NMC_CLK;
   NMC_MEM_CLKB <= NMC_CLK;
   NMC_MEM_RSTA <= NMC_HARD_RST ; 
   NMC_MEM_RSTB <= NMC_HARD_RST ; 

   NMC_MAIN_MEMORY : BRAM_TDP_MACRO
   generic map (
                BRAM_SIZE => "18Kb"           ,
                DEVICE => "7SERIES"           ,
                DOA_REG => 1                  , 
                DOB_REG => 1                  , 
                INIT_A => X"000000000"        , 
                INIT_B => X"000000000"        , 
                INIT_FILE => "NONE"           ,
                READ_WIDTH_A => 16            ,  
                READ_WIDTH_B => 16            ,  
                SIM_COLLISION_CHECK => "ALL"  , 
                SRVAL_A => X"000000000"       ,  
                SRVAL_B => X"000000000"       ,  
                WRITE_MODE_A => "WRITE_FIRST" , 
                WRITE_MODE_B => "WRITE_FIRST" , 
                WRITE_WIDTH_A => 16           , 
                WRITE_WIDTH_B => 16  
            )
   port map (
        DOA     => NMC_MEM_DOA     ,
        DOB     => NMC_MEM_DOB     ,
        ADDRA   => NMC_MEM_ADDRA   ,
        ADDRB   => NMC_MEM_ADDRB   ,
        CLKA    => NMC_MEM_CLKA    ,
        CLKB    => NMC_MEM_CLKB    ,
        DIA     => NMC_MEM_DIA     ,
        DIB     => NMC_MEM_DIB     ,
        ENA     => NMC_MEM_ENA     ,
        ENB     => NMC_MEM_ENB     ,
        REGCEA  => NMC_MEM_REGCEA  ,
        REGCEB  => NMC_MEM_REGCEB  ,
        RSTA    => NMC_MEM_RSTA    ,
        RSTB    => NMC_MEM_RSTB    ,
        WEA     => NMC_MEM_WEA     ,
        WEB     => NMC_MEM_WEB     
   );


    NMC_MEM_ADDRB <= REDIST_NMODEL_DADDR when REDIST_NMODEL_PORTB_TKOVER = '1' else
                     HK_MEM_ADDRB;

    NMC_MEM_DIA <= NMODEL_NPARAM_DATA when NMODEL_PROG_MEM_PORTA_EN = '1' else
                   NMC_REGSPACE_DOUT_1;       
   
    NMC_MEM_WEA <= NMODEL_PROG_MEM_PORTA_WEN & NMODEL_PROG_MEM_PORTA_WEN when NMODEL_PROG_MEM_PORTA_EN = '1' else
                   HK_MEM_WEA & HK_MEM_WEA;     
    
    NMC_MEM_ADDRA <= NMODEL_NPARAM_ADDR when NMODEL_PROG_MEM_PORTA_EN = '1' else
                     HK_MEM_ADDRA;  


   SPECIAL_REGS : process(NMC_CLK) begin

                    if(rising_edge(NMC_CLK)) then

                        HK_XNEVER_BADDR <= NMC_XNEVER_REGION_BASEADDR;
                        HK_XNEVER_HADDR <= NMC_XNEVER_REGION_HIGHADDR;
                        PF_LOW_ADDR     <= NMODEL_PF_LOW_ADDR;
                        REG_NNMODEL_NEW_SPIKE_TIME <= std_logic_vector(UPD_LAST_SPIKE_TIME) ;
                        REG_NMODEL_SYN_QFACTOR     <= NMODEL_SYN_QFACTOR     ; 
                        REG_NMODEL_PF_LOW_ADDR     <= NMODEL_PF_LOW_ADDR     ; 
                        REG_NMODEL_NPARAM_DATAOUT  <= NMC_MEM_DOB            ;
                        REG_NMODEL_NPARAM_ADDROUT  <= NMODEL_NPARAM_ADDR     ;

                    end if;

   end process SPECIAL_REGS;

    R_NNMODEL_NEW_SPIKE_TIME <= REG_NNMODEL_NEW_SPIKE_TIME;
    R_NMODEL_NPARAM_DATAOUT  <= REG_NMODEL_NPARAM_DATAOUT ;
   
   
   LAW_AND_ORDER :  HOUSEKEEPER
    Port Map
        ( 
            HK_CLK              => NMC_CLK,
            HK_RST              => NMC_STATE_RST,
            COLD_START          => NMC_COLD_START, 
            --
            PF_LOW              => PF_LOW_ADDR ,
            --
            XNEVER_BADDR        => HK_XNEVER_BADDR,     
            XNEVER_HADDR        => HK_XNEVER_HADDR,
            --
            REGSPACE_WR_EN      => NMC_REGSPACE_WR_EN ,
            REGSPACE_WR_ADDR    => NMC_REGSPACE_WR_ADDR, 
            REGSPACE_RD_ADDR_0  => NMC_REGSPACE_RD_ADDR_0  ,
            REGSPACE_RD_ADDR_1  => NMC_REGSPACE_RD_ADDR_1    ,
            REGSPACE_DIN_MUX    => REGSPACE_CONTROL_MUX  ,
            --
            FMAC_MUX            => FMAC16_PORT_MUX       ,
            FMAC_START          => FMAC16_START_HK       ,
            FMAC_OPC            => FMAC16_OPC            ,
            -- 
            EQ                  => COMP_EQ , 
            LE                  => COMP_LE ,
            GR                  => COMP_GR ,
            -- 
            MEM_ADDRB           => HK_MEM_ADDRB ,
            MEM_DOB             => NMC_MEM_DOB   ,
            --
            MEM_WEA             => HK_MEM_WEA   , 
            MEM_ADDRA           => HK_MEM_ADDRA ,
            --
            REF_DUR             => NMODEL_REFRACTORY_DUR ,
            NEW_REF_DUR         => REFRACTORY_REGISTER ,
            --
            GENERATE_SPIKE      => GEN_SPK ,
            SPK_VLD             => NMC_NMODEL_SPIKE_VLD ,
            --            -- 
            PROG_FLOW_COMPLETE  => NMC_NMODEL_FINISHED  ,
            --
            MEM_VIOLATION       => NMC_MEMORY_VIOLATION
        );

                                
        process(NMC_CLK) begin

            if(rising_edge(NMC_CLK)) then

                if(GEN_SPK = '1') then

                    UPD_LAST_SPIKE_TIME <= (others=>'0');

                else
                    
                    if(NMODEL_LAST_SPIKE_TIME >= X"7F") then

                        UPD_LAST_SPIKE_TIME <= X"7F";

                    else
                        
                        UPD_LAST_SPIKE_TIME <= signed(NMODEL_LAST_SPIKE_TIME)+"00000001";

                    end if;
                    
                end if;

            end if;

        end process;

        ------------------------------------

        -- REFRACTORY UPDATE 

        process(NMC_CLK) begin

            if(rising_edge(NMC_CLK)) then

                if(NMODEL_REFRACTORY_DUR = X"00") then

                    REFRACTORY_FLAG <= '0';

                else

                    REFRACTORY_FLAG <= '1';
                    
                end if;

            end if;

        end process;

        
        process(NMC_CLK) begin

            if(rising_edge(NMC_CLK)) then

                if(REFRACTORY_REGISTER = X"00") then

                    R_NMODEL_REFRACTORY_DUR <= (others=>'0');

                else

                    R_NMODEL_REFRACTORY_DUR <= std_logic_vector(signed(REFRACTORY_REGISTER) - "00000001");
                    
                end if;

            end if;

        end process;
        -------------------------------------

        -- MUX CONTROLS

        NMC_NMODEL_SPIKE_OUT <= GEN_SPK;

        NMC_REGSPACE_DATA_IN <= FMAC16_ACC when REGSPACE_CONTROL_MUX = '1' else
                                NMC_MEM_DOA;


        FMAC16_INTF_PLINE_1 : process(NMC_CLK) begin

                        if(rising_edge(NMC_CLK)) then

                            if(FMAC16_PORT_MUX = '1') then

                                FMAC16_A_S0 <= NMC_REGSPACE_DOUT_0;
                                FMAC16_B_S0 <= NMC_REGSPACE_DOUT_1;

                            else

                                FMAC16_A_S0 <= (others=>'0');
                                FMAC16_B_S0 <= (others=>'0');
                                
                            end if;

                        end if;

    end process FMAC16_INTF_PLINE_1;

end dance_me_to_the_end_of_love;
