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
            NAN    : out std_logic;
            BUSY   : out std_logic
        );
    end component FMAC16;

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

    component HOUSEKEEPER is
        PORT ( 
            HK_CLK              : IN  STD_LOGIC;
            HK_RST              : IN  STD_LOGIC;
            COLD_START          : IN  STD_LOGIC;
            PF_LOW              : IN  STD_LOGIC_VECTOR(9 DOWNTO 0);
            XNEVER_BADDR        : IN  STD_LOGIC_VECTOR(9 DOWNTO 0);      
            XNEVER_HADDR        : IN  STD_LOGIC_VECTOR(9 DOWNTO 0);
            MEM_ADDRB           : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
            MEM_DOB             : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
            ID_REG_RD_ADDR_0    : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
            ID_REG_RD_ADDR_1    : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
            ID_REG_WR_ADDR      : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
            CTRL_REGSPACE_WR_EN : OUT STD_LOGIC;
            CTRL_REGSPACE_MUX   : OUT STD_LOGIC;
            CTRL_MEM_WE         : OUT STD_LOGIC;
            CTRL_FMAC_MUX       : OUT STD_LOGIC;
            CTRL_FMAC_START     : OUT STD_LOGIC;
            CTRL_FMAC_OPC       : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
            CTRL_IS_COMP        : OUT STD_LOGIC;
            CTRL_GEN_SPIKE      : OUT STD_LOGIC;
            CTRL_SET_REF        : OUT STD_LOGIC;
            CTRL_PROG_DONE      : OUT STD_LOGIC;
            EX_BRANCH_TAKEN     : IN  STD_LOGIC;
            EX_BRANCH_TARGET    : IN  STD_LOGIC_VECTOR(9 DOWNTO 0);
            STALL_PIPELINE      : IN  STD_LOGIC;
            MEM_VIOLATION       : OUT STD_LOGIC
        );
    END component;

    component COMP is
        Port (
            N0    : in std_logic_vector(15 downto 0);
            N1    : in std_logic_vector(15 downto 0);
            GREAT : out std_logic;
            LESS  : out std_logic;
            EQUAL : out std_logic
        );
    end component COMP;

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

    -- =========================================================================
    -- PIPELINE REGISTERS
    -- =========================================================================
    type T_ID_EX is record
        PC          : unsigned(9 downto 0);
        RD_ADDR_0   : std_logic_vector(2 downto 0);
        RD_ADDR_1   : std_logic_vector(2 downto 0);
        OP1         : std_logic_vector(15 downto 0);
        OP2         : std_logic_vector(15 downto 0);
        IMM_ADDR    : unsigned(9 downto 0);
        IMM_OFFSET  : unsigned(9 downto 0); 
        WR_ADDR     : std_logic_vector(2 downto 0);
        OPCODE      : std_logic_vector(3 downto 0);
        REG_WE      : std_logic;
        REG_MUX     : std_logic;
        MEM_WE      : std_logic;
        FMAC_START  : std_logic;
        FMAC_OPC    : std_logic_vector(1 downto 0);
        GEN_SPIKE   : std_logic;
        SET_REF     : std_logic;
        REF_VAL     : std_logic_vector(7 downto 0);
        PROG_DONE   : std_logic;
    end record;
    signal REG_ID_EX : T_ID_EX;

    type T_EX_MEM is record
        MEM_ADDR    : std_logic_vector(9 downto 0);
        STORE_DATA  : std_logic_vector(15 downto 0);
        WR_ADDR     : std_logic_vector(2 downto 0);
        REG_WE      : std_logic;
        REG_MUX     : std_logic;
        MEM_WE      : std_logic;
        GEN_SPIKE   : std_logic;
        SET_REF     : std_logic;
        REF_VAL     : std_logic_vector(7 downto 0);
        PROG_DONE   : std_logic;
    end record;
    signal REG_EX_MEM : T_EX_MEM;

    type T_MEM_WB is record
        MEM_RDATA   : std_logic_vector(15 downto 0);
        WR_ADDR     : std_logic_vector(2 downto 0);
        REG_WE      : std_logic;
        REG_MUX     : std_logic;
        GEN_SPIKE   : std_logic;
        SET_REF     : std_logic;
        REF_VAL     : std_logic_vector(7 downto 0);
        PROG_DONE   : std_logic;
    end record;
    signal REG_MEM_WB : T_MEM_WB;

    signal ID_INSTR             : std_logic_vector(15 downto 0);
    signal ID_PC                : unsigned(9 downto 0);
    signal HK_RD_ADDR_0         : std_logic_vector(2 downto 0);
    signal HK_RD_ADDR_1         : std_logic_vector(2 downto 0);
    signal HK_WR_ADDR           : std_logic_vector(2 downto 0);
    signal CTRL_REG_WE          : std_logic;
    signal CTRL_REG_MUX         : std_logic;
    signal CTRL_MEM_WE          : std_logic;
    signal CTRL_FMAC_START      : std_logic;
    signal CTRL_FMAC_OPC        : std_logic_vector(1 downto 0);
    signal CTRL_IS_COMP         : std_logic;
    signal CTRL_GEN_SPIKE       : std_logic;
    signal CTRL_SET_REF         : std_logic;
    signal CTRL_PROG_DONE       : std_logic;
    
    signal STALL_HAZARD         : std_logic;
    signal STALL_SIG            : std_logic;

    -- SKID BUFFER
    signal SKID_REG             : std_logic_vector(15 downto 0);
    signal SKID_VALID           : std_logic;

    -- FORWARDING SIGNALS
    signal EX_OP1               : std_logic_vector(15 downto 0);
    signal EX_OP2               : std_logic_vector(15 downto 0);

    -- BRANCHING AND FLAG REGISTERS
    signal FLAG_LESS            : std_logic;
    signal FLAG_EQUAL           : std_logic;
    signal FLAG_GREAT           : std_logic;

    signal BRANCH_TAKEN_EX      : std_logic;
    signal BRANCH_TARGET_EX     : std_logic_vector(9 downto 0);
    signal COMP_GR, COMP_LE, COMP_EQ : std_logic;
    
    signal FMAC_BUSY_SIG        : std_logic;
    signal FMAC16_ACC           : std_logic_vector(15 downto 0);
    signal FMAC16_A             : std_logic_vector(15 downto 0);
    signal FMAC16_B             : std_logic_vector(15 downto 0);
    signal FMAC16_START_FINAL   : std_logic;
    
    signal REG_DOUT_0           : std_logic_vector(15 downto 0);
    signal REG_DOUT_1           : std_logic_vector(15 downto 0);
    signal WB_FINAL_DATA        : std_logic_vector(15 downto 0);

    signal HP_OUT_REG           : std_logic_vector(15 downto 0);
    signal PARTIAL_CURRENT_MUX  : std_logic;
    signal REFRACTORY_FLAG      : std_logic;

    signal HK_BRAM_ADDRB        : std_logic_vector(9 downto 0);
    signal BRAM_ADDRB           : std_logic_vector(9 downto 0);
    signal BRAM_DOB             : std_logic_vector(15 downto 0);
    signal BRAM_ADDRA           : std_logic_vector(9 downto 0);
    signal BRAM_DIA             : std_logic_vector(15 downto 0);
    signal BRAM_DOA             : std_logic_vector(15 downto 0);
    signal BRAM_WEA             : std_logic_vector(1 downto 0);
    signal BRAM_ENA             : std_logic;

    signal UPD_LAST_SPIKE_TIME  : signed(7 downto 0);
    signal REFRACTORY_REG       : std_logic_vector(7 downto 0);

    signal LATCH_SPIKE_OUT      : std_logic := '0';
    signal LATCH_FINISHED       : std_logic := '0';
    signal SPK_VLD_PULSE        : std_logic := '0';

begin

    -- =========================================================================
    -- A. HAZARD DETECTION (Load-Use Stall)
    -- =========================================================================
    PROCESS(REG_ID_EX, HK_RD_ADDR_0, HK_RD_ADDR_1)
    BEGIN
        IF (REG_ID_EX.REG_WE = '1' AND REG_ID_EX.REG_MUX = '0') THEN -- Önceki komut LW ise
            IF (REG_ID_EX.WR_ADDR = HK_RD_ADDR_0 OR REG_ID_EX.WR_ADDR = HK_RD_ADDR_1) THEN
                STALL_HAZARD <= '1';
            ELSE
                STALL_HAZARD <= '0';
            END IF;
        ELSE
            STALL_HAZARD <= '0';
        END IF;
    END PROCESS;

    STALL_SIG <= FMAC_BUSY_SIG OR STALL_HAZARD;

    -- =========================================================================
    -- SKID BUFFER PROCESS (Protects IF process)
    -- =========================================================================
    PROCESS(NMC_CLK)
    BEGIN
        IF rising_edge(NMC_CLK) THEN
            IF NMC_STATE_RST = '1' or BRANCH_TAKEN_EX = '1' or NMC_COLD_START = '1' THEN
                SKID_VALID <= '0';
                SKID_REG   <= (others => '0');
            ELSE
                IF STALL_SIG = '1' and SKID_VALID = '0' THEN
                    SKID_REG   <= ID_INSTR;
                    SKID_VALID <= '1';
                ELSIF STALL_SIG = '0' THEN
                    SKID_VALID <= '0';
                END IF;
            END IF;
        END IF;
    END PROCESS;

    ID_INSTR <= SKID_REG when SKID_VALID = '1' else BRAM_DOB;

    -- =========================================================================
    -- ID Stage Program Counter Track
    -- =========================================================================
    PROCESS(NMC_CLK)
    BEGIN
        IF rising_edge(NMC_CLK) THEN
            IF NMC_STATE_RST = '1' or NMC_COLD_START = '1' THEN
                ID_PC <= unsigned(NMODEL_PF_LOW_ADDR);
            ELSIF STALL_SIG = '0' THEN
                ID_PC <= unsigned(HK_BRAM_ADDRB);
            END IF;
        END IF;
    END PROCESS;

    -- =========================================================================
    -- 1. SS_2_HP Module
    -- =========================================================================
    TCAST : SS_2_HP
    Port Map(
        CLK     => NMC_CLK,
        RST     => NMC_STATE_RST,
        SS_IN   => NMC_NMODEL_PSUM_IN,
        HP_OUT  => HP_OUT_REG,
        START   => PARTIAL_CURRENT_RDY,
        DONE    => PARTIAL_CURRENT_MUX
    );

    -- =========================================================================
    -- 2. Law and order (HOUSEKEEPER)
    -- =========================================================================
    CONTROL_UNIT : HOUSEKEEPER
    PORT MAP ( 
        HK_CLK              => NMC_CLK,
        HK_RST              => NMC_STATE_RST,
        COLD_START          => NMC_COLD_START,
        PF_LOW              => NMODEL_PF_LOW_ADDR,
        XNEVER_BADDR        => NMC_XNEVER_REGION_BASEADDR,      
        XNEVER_HADDR        => NMC_XNEVER_REGION_HIGHADDR,
        MEM_ADDRB           => HK_BRAM_ADDRB,
        MEM_DOB             => ID_INSTR,
        ID_REG_RD_ADDR_0    => HK_RD_ADDR_0,
        ID_REG_RD_ADDR_1    => HK_RD_ADDR_1,
        ID_REG_WR_ADDR      => HK_WR_ADDR,
        CTRL_REGSPACE_WR_EN => CTRL_REG_WE,
        CTRL_REGSPACE_MUX   => CTRL_REG_MUX,
        CTRL_MEM_WE         => CTRL_MEM_WE,
        CTRL_FMAC_MUX       => open,
        CTRL_FMAC_START     => CTRL_FMAC_START,
        CTRL_FMAC_OPC       => CTRL_FMAC_OPC,
        CTRL_IS_COMP        => CTRL_IS_COMP,
        CTRL_GEN_SPIKE      => CTRL_GEN_SPIKE,
        CTRL_SET_REF        => CTRL_SET_REF,
        CTRL_PROG_DONE      => CTRL_PROG_DONE,
        EX_BRANCH_TAKEN     => BRANCH_TAKEN_EX,
        EX_BRANCH_TARGET    => BRANCH_TARGET_EX,
        STALL_PIPELINE      => STALL_SIG,
        MEM_VIOLATION       => NMC_MEMORY_VIOLATION
    );

    -- =========================================================================
    -- 3. REGISTER FILE
    -- =========================================================================
    REGS : NMC_LOC_REGSPACE
    PORT MAP (
        RST       => NMC_STATE_RST,
        CLK       => NMC_CLK,
        RD_ADDR_0 => HK_RD_ADDR_0,
        RD_ADDR_1 => HK_RD_ADDR_1,
        WR_ADDR   => REG_MEM_WB.WR_ADDR,
        WR_EN     => REG_MEM_WB.REG_WE,
        DATA_IN   => WB_FINAL_DATA,
        DOUT_0    => REG_DOUT_0,
        DOUT_1    => REG_DOUT_1
    );

    -- =========================================================================
    -- 4. ID / EX PIPELINE REGISTERS
    -- =========================================================================
    PROCESS(NMC_CLK)
    BEGIN
        IF rising_edge(NMC_CLK) THEN
            IF NMC_STATE_RST = '1' or BRANCH_TAKEN_EX = '1' or NMC_COLD_START = '1' THEN
                REG_ID_EX.REG_WE     <= '0';
                REG_ID_EX.MEM_WE     <= '0';
                REG_ID_EX.FMAC_START <= '0';
                REG_ID_EX.GEN_SPIKE  <= '0';
                REG_ID_EX.SET_REF    <= '0';
                REG_ID_EX.PROG_DONE  <= '0';
                REG_ID_EX.OPCODE     <= (others => '0');
                REG_ID_EX.RD_ADDR_0  <= (others => '0');
                REG_ID_EX.RD_ADDR_1  <= (others => '0');

            ELSIF FMAC_BUSY_SIG = '1' THEN
                REG_ID_EX <= REG_ID_EX;

            ELSIF STALL_HAZARD = '1' THEN
                REG_ID_EX.REG_WE     <= '0';
                REG_ID_EX.MEM_WE     <= '0';
                REG_ID_EX.FMAC_START <= '0';
                REG_ID_EX.GEN_SPIKE  <= '0';
                REG_ID_EX.SET_REF    <= '0';
                REG_ID_EX.PROG_DONE  <= '0';
                REG_ID_EX.OPCODE     <= (others => '0');
                REG_ID_EX.RD_ADDR_0  <= (others => '0');
                REG_ID_EX.RD_ADDR_1  <= (others => '0');

            ELSE
                REG_ID_EX.PC         <= ID_PC;
                REG_ID_EX.RD_ADDR_0  <= HK_RD_ADDR_0;
                REG_ID_EX.RD_ADDR_1  <= HK_RD_ADDR_1;
                REG_ID_EX.OP1        <= REG_DOUT_0;
                REG_ID_EX.OP2        <= REG_DOUT_1;
                REG_ID_EX.WR_ADDR    <= HK_WR_ADDR;
                REG_ID_EX.IMM_ADDR   <= unsigned(NMC_XNEVER_REGION_BASEADDR) + unsigned('0' & ID_INSTR(8 downto 0));
                REG_ID_EX.IMM_OFFSET <= unsigned('0' & ID_INSTR(8 downto 0));
                REG_ID_EX.OPCODE     <= ID_INSTR(15 downto 12);
                REG_ID_EX.REG_WE     <= CTRL_REG_WE;
                REG_ID_EX.REG_MUX    <= CTRL_REG_MUX;
                REG_ID_EX.MEM_WE     <= CTRL_MEM_WE;
                REG_ID_EX.FMAC_START <= CTRL_FMAC_START;
                REG_ID_EX.FMAC_OPC   <= CTRL_FMAC_OPC;
                REG_ID_EX.GEN_SPIKE  <= CTRL_GEN_SPIKE;
                REG_ID_EX.SET_REF    <= CTRL_SET_REF;
                REG_ID_EX.REF_VAL    <= ID_INSTR(7 downto 0);
                REG_ID_EX.PROG_DONE  <= CTRL_PROG_DONE;
            END IF;
        END IF;
    END PROCESS;

    -- =========================================================================
    -- 5. EX STAGE: Forwarding MUXes & COMP & DALLANMA
    -- =========================================================================
    PROCESS(REG_ID_EX, REG_EX_MEM, REG_MEM_WB, FMAC16_ACC, WB_FINAL_DATA)
    BEGIN
        IF (REG_EX_MEM.REG_WE = '1' AND REG_EX_MEM.WR_ADDR = REG_ID_EX.RD_ADDR_0) THEN
            IF REG_EX_MEM.REG_MUX = '1' THEN
                EX_OP1 <= FMAC16_ACC;
            ELSE
                EX_OP1 <= FMAC16_ACC;
            END IF;
        ELSIF (REG_MEM_WB.REG_WE = '1' AND REG_MEM_WB.WR_ADDR = REG_ID_EX.RD_ADDR_0) THEN
            EX_OP1 <= WB_FINAL_DATA;
        ELSE
            EX_OP1 <= REG_ID_EX.OP1;
        END IF;
    END PROCESS;

    PROCESS(REG_ID_EX, REG_EX_MEM, REG_MEM_WB, FMAC16_ACC, WB_FINAL_DATA)
    BEGIN
        IF (REG_EX_MEM.REG_WE = '1' AND REG_EX_MEM.WR_ADDR = REG_ID_EX.RD_ADDR_1) THEN
            IF REG_EX_MEM.REG_MUX = '1' THEN
                EX_OP2 <= FMAC16_ACC;
            ELSE
                EX_OP2 <= FMAC16_ACC;
            END IF;
        ELSIF (REG_MEM_WB.REG_WE = '1' AND REG_MEM_WB.WR_ADDR = REG_ID_EX.RD_ADDR_1) THEN
            EX_OP2 <= WB_FINAL_DATA;
        ELSE
            EX_OP2 <= REG_ID_EX.OP2;
        END IF;
    END PROCESS;

    COMPARATOR : COMP 
    PORT MAP (
        N0    => EX_OP1,
        N1    => EX_OP2,
        GREAT => COMP_GR,
        LESS  => COMP_LE,
        EQUAL => COMP_EQ
    );

    PROCESS(NMC_CLK)
    BEGIN
        IF rising_edge(NMC_CLK) THEN
            IF NMC_STATE_RST = '1' or NMC_COLD_START = '1' THEN
                FLAG_LESS  <= '0';
                FLAG_EQUAL <= '0';
                FLAG_GREAT <= '0';
            ELSIF REG_ID_EX.OPCODE = X"7" THEN 
                FLAG_LESS  <= COMP_LE;
                FLAG_EQUAL <= COMP_EQ;
                FLAG_GREAT <= COMP_GR;
            END IF;
        END IF;
    END PROCESS;

    -- PC-RELATIVE! PC + OFFSET!)
    PROCESS(REG_ID_EX, FLAG_LESS, FLAG_EQUAL, FLAG_GREAT)
    BEGIN
        BRANCH_TAKEN_EX  <= '0';
        
        BRANCH_TARGET_EX <= std_logic_vector(REG_ID_EX.PC + REG_ID_EX.IMM_OFFSET);

        CASE REG_ID_EX.OPCODE IS
            WHEN X"8" => if FLAG_LESS = '1'  then BRANCH_TAKEN_EX <= '1'; end if; -- BIL
            WHEN X"9" => if FLAG_EQUAL = '1' then BRANCH_TAKEN_EX <= '1'; end if; -- BIE
            WHEN X"A" => if FLAG_GREAT = '1' then BRANCH_TAKEN_EX <= '1'; end if; -- BIG
            WHEN OTHERS => BRANCH_TAKEN_EX <= '0';
        END CASE;
    END PROCESS;

    PROCESS(PARTIAL_CURRENT_MUX, REFRACTORY_FLAG, HP_OUT_REG, NMODEL_SYN_QFACTOR, REG_ID_EX, EX_OP1, EX_OP2)
    BEGIN
        if (PARTIAL_CURRENT_MUX = '1' and REFRACTORY_FLAG = '0') then
            FMAC16_A           <= HP_OUT_REG;
            FMAC16_B           <= NMODEL_SYN_QFACTOR;
            FMAC16_START_FINAL <= '1';
        else
            FMAC16_A           <= EX_OP1;
            FMAC16_B           <= EX_OP2;
            FMAC16_START_FINAL <= REG_ID_EX.FMAC_START;
        end if;
    END PROCESS;

    WORKHORSE : FMAC16
    PORT MAP (
        CLK   => NMC_CLK,
        RST   => FMAC_EXTERN_RST or REG_ID_EX.FMAC_OPC(1),
        START => FMAC16_START_FINAL,
        A     => FMAC16_A,
        B     => FMAC16_B,
        ACC   => FMAC16_ACC,
        OPC   => REG_ID_EX.FMAC_OPC,
        NAN   => NMC_MATH_ERROR,
        BUSY  => FMAC_BUSY_SIG
    );

    -- =========================================================================
    -- 6. EX / MEM REGISTERS
    -- =========================================================================
    PROCESS(NMC_CLK)
    BEGIN
        IF rising_edge(NMC_CLK) THEN
            IF NMC_STATE_RST = '1' or NMC_COLD_START = '1' THEN
                REG_EX_MEM.REG_WE    <= '0';
                REG_EX_MEM.MEM_WE    <= '0';
                REG_EX_MEM.GEN_SPIKE <= '0';
                REG_EX_MEM.SET_REF   <= '0';
                REG_EX_MEM.PROG_DONE <= '0';

            ELSIF FMAC_BUSY_SIG = '1' THEN
                REG_EX_MEM <= REG_EX_MEM;

            ELSE
                REG_EX_MEM.MEM_ADDR   <= std_logic_vector(REG_ID_EX.IMM_ADDR);
                REG_EX_MEM.STORE_DATA <= EX_OP2;
                REG_EX_MEM.WR_ADDR    <= REG_ID_EX.WR_ADDR;
                REG_EX_MEM.REG_WE     <= REG_ID_EX.REG_WE;
                REG_EX_MEM.REG_MUX    <= REG_ID_EX.REG_MUX;
                REG_EX_MEM.MEM_WE     <= REG_ID_EX.MEM_WE;
                REG_EX_MEM.GEN_SPIKE  <= REG_ID_EX.GEN_SPIKE;
                REG_EX_MEM.SET_REF    <= REG_ID_EX.SET_REF;
                REG_EX_MEM.REF_VAL    <= REG_ID_EX.REF_VAL;
                REG_EX_MEM.PROG_DONE  <= REG_ID_EX.PROG_DONE;
            END IF;
        END IF;
    END PROCESS;

    -- =========================================================================
    -- 7. MEMORY (BRAM) INTERFACE 
    -- =========================================================================
    BRAM_ADDRB <= REDIST_NMODEL_DADDR when REDIST_NMODEL_PORTB_TKOVER = '1' else
                  HK_BRAM_ADDRB;

    BRAM_ADDRA <= NMODEL_NPARAM_ADDR when NMODEL_PROG_MEM_PORTA_EN = '1' else
                  std_logic_vector(REG_ID_EX.IMM_ADDR);

    BRAM_DIA   <= NMODEL_NPARAM_DATA when NMODEL_PROG_MEM_PORTA_EN = '1' else
                  EX_OP2;

    BRAM_WEA   <= NMODEL_PROG_MEM_PORTA_WEN & NMODEL_PROG_MEM_PORTA_WEN when NMODEL_PROG_MEM_PORTA_EN = '1' else
                  REG_ID_EX.MEM_WE & REG_ID_EX.MEM_WE;

    BRAM_ENA   <= '1' when (NMODEL_PROG_MEM_PORTA_EN = '1' or 
                            STALL_SIG = '1' or 
                            REG_ID_EX.MEM_WE = '1' or 
                            (REG_ID_EX.REG_WE = '1' and REG_ID_EX.REG_MUX = '0') or
                            REG_EX_MEM.MEM_WE = '1' or
                            (REG_EX_MEM.REG_WE = '1' and REG_EX_MEM.REG_MUX = '0')) else '0';

    NMC_MAIN_MEMORY : BRAM_TDP_MACRO
    generic map (
        BRAM_SIZE     => "18Kb",
        DEVICE        => "7SERIES",
        DOA_REG       => 0,
        DOB_REG       => 0,
        WRITE_WIDTH_A => 16,
        READ_WIDTH_A  => 16,
        WRITE_WIDTH_B => 16,
        READ_WIDTH_B  => 16
    )
    port map (
        DOA     => BRAM_DOA,
        DOB     => BRAM_DOB,
        ADDRA   => BRAM_ADDRA,
        ADDRB   => BRAM_ADDRB,
        CLKA    => NMC_CLK,
        CLKB    => NMC_CLK,
        DIA     => BRAM_DIA,
        DIB     => (others => '0'),
        ENA     => BRAM_ENA,
        ENB     => '1',
        REGCEA  => '1',
        REGCEB  => '1',
        RSTA    => NMC_HARD_RST,
        RSTB    => NMC_HARD_RST,
        WEA     => BRAM_WEA,
        WEB     => "00"
    );

    -- =========================================================================
    -- 8. MEM / WB REGISTERS
    -- =========================================================================
    PROCESS(NMC_CLK)
    BEGIN
        IF rising_edge(NMC_CLK) THEN
            IF NMC_STATE_RST = '1' or NMC_COLD_START = '1' THEN
                REG_MEM_WB.REG_WE    <= '0';
                REG_MEM_WB.GEN_SPIKE <= '0';
                REG_MEM_WB.SET_REF   <= '0';
                REG_MEM_WB.PROG_DONE <= '0';
            ELSIF FMAC_BUSY_SIG = '1' THEN
                REG_MEM_WB <= REG_MEM_WB;
            ELSE
                REG_MEM_WB.MEM_RDATA <= BRAM_DOA;
                REG_MEM_WB.WR_ADDR   <= REG_EX_MEM.WR_ADDR;
                REG_MEM_WB.REG_WE    <= REG_EX_MEM.REG_WE;
                REG_MEM_WB.REG_MUX   <= REG_EX_MEM.REG_MUX;
                REG_MEM_WB.GEN_SPIKE <= REG_EX_MEM.GEN_SPIKE;
                REG_MEM_WB.SET_REF   <= REG_EX_MEM.SET_REF;
                REG_MEM_WB.REF_VAL   <= REG_EX_MEM.REF_VAL;
                REG_MEM_WB.PROG_DONE <= REG_EX_MEM.PROG_DONE;
            END IF;
        END IF;
    END PROCESS;

    -- =========================================================================
    -- 9. WB & SNN 
    -- =========================================================================
    WB_FINAL_DATA <= FMAC16_ACC when REG_MEM_WB.REG_MUX = '1' else
                     REG_MEM_WB.MEM_RDATA;

    PROCESS(NMC_CLK)
    BEGIN
        IF rising_edge(NMC_CLK) THEN
            IF NMC_STATE_RST = '1' THEN
                LATCH_SPIKE_OUT <= '0';
                LATCH_FINISHED  <= '0';
                SPK_VLD_PULSE   <= '0';
                REFRACTORY_REG  <= (others => '0');
            ELSE
                IF REG_MEM_WB.GEN_SPIKE = '1' THEN
                    LATCH_SPIKE_OUT <= '1';
                END IF;

                IF REG_MEM_WB.PROG_DONE = '1' THEN
                    LATCH_FINISHED <= '1';
                END IF;

                IF REG_MEM_WB.PROG_DONE = '1' AND LATCH_FINISHED = '0' THEN
                    SPK_VLD_PULSE <= '1';
                ELSE
                    SPK_VLD_PULSE <= '0';
                END IF;

                if (NMC_COLD_START = '1') then
                    REFRACTORY_REG <= NMODEL_REFRACTORY_DUR;
                elsif (REG_MEM_WB.SET_REF = '1') then
                    REFRACTORY_REG <= REG_MEM_WB.REF_VAL;
                elsif (REFRACTORY_REG /= X"00") then
                    REFRACTORY_REG <= std_logic_vector(unsigned(REFRACTORY_REG) - 1);
                end if;

                if (REG_MEM_WB.GEN_SPIKE = '1') then
                    UPD_LAST_SPIKE_TIME <= (others => '0');
                elsif (NMODEL_LAST_SPIKE_TIME >= X"7F") then
                    UPD_LAST_SPIKE_TIME <= X"7F";
                else
                    UPD_LAST_SPIKE_TIME <= signed(NMODEL_LAST_SPIKE_TIME) + 1;
                end if;
            END IF;
        END IF;
    END PROCESS;

    NMC_NMODEL_SPIKE_OUT <= LATCH_SPIKE_OUT;
    NMC_NMODEL_FINISHED  <= LATCH_FINISHED;
    NMC_NMODEL_SPIKE_VLD <= SPK_VLD_PULSE;

    REFRACTORY_FLAG <= '0' when REFRACTORY_REG = X"00" else '1';
    R_NNMODEL_NEW_SPIKE_TIME <= std_logic_vector(UPD_LAST_SPIKE_TIME);
    R_NMODEL_REFRACTORY_DUR  <= REFRACTORY_REG;
    R_NMODEL_NPARAM_DATAOUT  <= BRAM_DOB;

end dance_me_to_the_end_of_love;