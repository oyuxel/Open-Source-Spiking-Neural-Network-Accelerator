LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY HOUSEKEEPER IS
    PORT
        ( 
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
END HOUSEKEEPER;

ARCHITECTURE PIPELINED_CONTROL OF HOUSEKEEPER IS
    SIGNAL PC          : UNSIGNED(9 DOWNTO 0);
    SIGNAL OPCODE      : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL RUNNING     : STD_LOGIC ;
BEGIN

    MEM_ADDRB <= STD_LOGIC_VECTOR(PC);
    OPCODE <= MEM_DOB(15 DOWNTO 12);
    MEM_VIOLATION <= '0'; 

    PC_PROCESS : PROCESS(HK_CLK) 
    BEGIN
        IF RISING_EDGE(HK_CLK) THEN
            IF HK_RST = '1' THEN
                PC <= (OTHERS => '0');
                RUNNING <= '0';
            ELSIF COLD_START = '1' THEN
                PC <= UNSIGNED(PF_LOW); 
                RUNNING <= '1';
            ELSIF RUNNING = '1' THEN
                IF OPCODE = X"D" THEN
                    RUNNING <= '0';
                END IF;

                IF EX_BRANCH_TAKEN = '1' THEN
                    PC <= UNSIGNED(EX_BRANCH_TARGET);
                ELSIF STALL_PIPELINE = '1' THEN
                    PC <= PC;
                ELSE
                    PC <= PC + 1;
                END IF;
            END IF;
        END IF;
    END PROCESS;

    DECODE_PROCESS : PROCESS(OPCODE, MEM_DOB, RUNNING)
    BEGIN
        ID_REG_RD_ADDR_0    <= (OTHERS => '0');
        ID_REG_RD_ADDR_1    <= (OTHERS => '0');
        ID_REG_WR_ADDR      <= (OTHERS => '0');
        CTRL_REGSPACE_WR_EN <= '0';
        CTRL_REGSPACE_MUX   <= '0';
        CTRL_MEM_WE         <= '0';
        CTRL_FMAC_MUX       <= '0';
        CTRL_FMAC_START     <= '0';
        CTRL_FMAC_OPC       <= "00";
        CTRL_IS_COMP        <= '0';
        CTRL_GEN_SPIKE      <= '0';
        CTRL_SET_REF        <= '0';
        CTRL_PROG_DONE      <= '0';

        IF RUNNING = '1' THEN
            CASE OPCODE IS
                WHEN X"1" => -- LW
                    ID_REG_WR_ADDR      <= MEM_DOB(11 DOWNTO 9);
                    CTRL_REGSPACE_MUX   <= '0'; 
                    CTRL_REGSPACE_WR_EN <= '1';
                WHEN X"2" => -- SW
                    ID_REG_RD_ADDR_1    <= MEM_DOB(11 DOWNTO 9);
                    CTRL_MEM_WE         <= '1';
                WHEN X"3" => -- GACC
                    ID_REG_WR_ADDR      <= MEM_DOB(11 DOWNTO 9);
                    CTRL_REGSPACE_MUX   <= '1'; 
                    CTRL_REGSPACE_WR_EN <= '1';
                WHEN X"4" => -- FMAC
                    ID_REG_RD_ADDR_0    <= MEM_DOB(5 DOWNTO 3);
                    ID_REG_RD_ADDR_1    <= MEM_DOB(2 DOWNTO 0);
                    CTRL_FMAC_MUX       <= '1';
                    CTRL_FMAC_START     <= '1';
                    CTRL_FMAC_OPC       <= "00";
                WHEN X"5" => -- SMAC
                    ID_REG_RD_ADDR_0    <= MEM_DOB(5 DOWNTO 3);
                    ID_REG_RD_ADDR_1    <= MEM_DOB(2 DOWNTO 0);
                    CTRL_FMAC_MUX       <= '1';
                    CTRL_FMAC_START     <= '1';
                    CTRL_FMAC_OPC       <= "01";
                WHEN X"6" => -- CLRACC
                    CTRL_FMAC_OPC       <= "10";
                    CTRL_FMAC_START     <= '1'; 
                WHEN X"7" => -- COMP
                    ID_REG_RD_ADDR_0    <= MEM_DOB(5 DOWNTO 3);
                    ID_REG_RD_ADDR_1    <= MEM_DOB(2 DOWNTO 0);
                    CTRL_IS_COMP        <= '1';
                WHEN X"B" => -- SPK
                    CTRL_GEN_SPIKE      <= '1';
                WHEN X"D" => -- RETURN
                    CTRL_PROG_DONE      <= '1';
                WHEN X"E" => -- STRF
                    CTRL_SET_REF        <= '1';
                WHEN OTHERS =>
                    NULL;
            END CASE;
        END IF;
    END PROCESS;

END PIPELINED_CONTROL;