LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY HOUSEKEEPER IS
    PORT
        ( 
            HK_CLK              : IN  STD_LOGIC;
            HK_RST              : IN  STD_LOGIC;
            --
            COLD_START          : IN  STD_LOGIC;
            --
            PF_LOW              : IN  STD_LOGIC_VECTOR(9 DOWNTO 0);
            --
            XNEVER_BADDR        : IN  STD_LOGIC_VECTOR(9 DOWNTO 0);      
            XNEVER_HADDR        : IN  STD_LOGIC_VECTOR(9 DOWNTO 0);
            --
            REGSPACE_WR_EN      : OUT STD_LOGIC;
            REGSPACE_WR_ADDR    : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
            REGSPACE_RD_ADDR_0  : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
            REGSPACE_RD_ADDR_1  : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
            REGSPACE_DIN_MUX    : OUT STD_LOGIC;
            --
            FMAC_MUX            : OUT STD_LOGIC;
            FMAC_START          : OUT STD_LOGIC;
            FMAC_OPC            : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
            -- 
            EQ                  : IN  STD_LOGIC;
            LE                  : IN  STD_LOGIC;
            GR                  : IN  STD_LOGIC;
            -- 
            MEM_ADDRB           : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
            MEM_DOB             : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
            --
            MEM_WEA             : OUT STD_LOGIC;
            MEM_ADDRA           : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
            --
            REF_DUR             : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
            NEW_REF_DUR         : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
            --
            GENERATE_SPIKE      : OUT STD_LOGIC;
            SPK_VLD             : OUT STD_LOGIC;
            --
            -- 
            PROG_FLOW_COMPLETE  : OUT STD_LOGIC;
            --
            MEM_VIOLATION       : OUT STD_LOGIC

        );
END HOUSEKEEPER;

ARCHITECTURE CRUEL_CRUEL_WORLD OF HOUSEKEEPER IS

    SIGNAL PC       : UNSIGNED(9 DOWNTO 0);

    SIGNAL XN_BADDR : UNSIGNED(9 DOWNTO 0);      
    SIGNAL XN_HADDR : UNSIGNED(9 DOWNTO 0);

    SIGNAL CURRENT_ADDRESS : UNSIGNED(9 DOWNTO 0);

    TYPE STATES IS (IDLE,LOAD_UP,I_F,I_D,LW,SW,GACC,FMAC,SMAC,CLRACC,COMP,BIL,BIE,BIG,SPK,STRF,RET);

    SIGNAL STATE : STATES;

    SIGNAL INST_COUNTER : INTEGER RANGE 0 TO 7;

BEGIN

    XN_BADDR <= UNSIGNED(XNEVER_BADDR);      
    XN_HADDR <= UNSIGNED(XNEVER_HADDR);
 
    MEM_VIOLATION <= '1' WHEN CURRENT_ADDRESS > XN_HADDR ELSE
                     '0';


    MAIN_STATE_MACHINE : PROCESS(HK_CLK) BEGIN

                            IF(RISING_EDGE(HK_CLK)) THEN

                            IF(HK_RST = '1') THEN

                                STATE <= IDLE;

                            ELSE

                                CASE STATE IS

                                    WHEN IDLE =>

                                    REGSPACE_WR_EN      <= '0';
                                    REGSPACE_WR_ADDR    <= (OTHERS=>'0');
                                    REGSPACE_RD_ADDR_0  <= (OTHERS=>'0');
                                    REGSPACE_RD_ADDR_1  <= (OTHERS=>'0');
                                    REGSPACE_DIN_MUX    <= '0';
                                    FMAC_MUX            <= '0';
                                    FMAC_START          <= '0';
                                    FMAC_OPC            <= (OTHERS=>'0');
                                    MEM_ADDRB           <= (OTHERS=>'0');
                                    MEM_WEA             <= '0';
                                    MEM_ADDRA           <= (OTHERS=>'0');                         
                                    GENERATE_SPIKE      <= '0';
                                    PROG_FLOW_COMPLETE  <= '0';
                                    CURRENT_ADDRESS     <= (OTHERS=>'0');
                                    SPK_VLD             <= '0';

                                        IF(COLD_START = '1') THEN
                                        
                                            STATE <= LOAD_UP;
                                        
                                        ELSE
                                        
                                            STATE <= IDLE;
                                        
                                        END IF;

                                    WHEN LOAD_UP =>
  
                                        INST_COUNTER <= 0;
        
                                        PC <= UNSIGNED(PF_LOW);
                                        NEW_REF_DUR <= REF_DUR;
                                        STATE <= I_F;

                                    WHEN I_F =>

                                        IF(INST_COUNTER = 0) THEN

                                            INST_COUNTER <= INST_COUNTER + 1;
                                            MEM_ADDRB <= STD_LOGIC_VECTOR(PC);

                                        ELSIF(INST_COUNTER = 1) THEN

                                            INST_COUNTER <= INST_COUNTER + 1;

                                        ELSIF(INST_COUNTER = 2) THEN

                                            STATE <= I_D;
                                            INST_COUNTER <= 0;

                                        END IF;

                                    WHEN I_D => 

                                        IF(MEM_DOB(15 DOWNTO 12) = X"1") THEN

                                            STATE <= LW; -- LOAD WORD
                                            
                                            REGSPACE_WR_ADDR     <= MEM_DOB(11 DOWNTO 9);
                                            MEM_ADDRA            <= STD_LOGIC_VECTOR(XN_BADDR+UNSIGNED('0'&MEM_DOB(8 DOWNTO 0)));
                                            CURRENT_ADDRESS      <= XN_BADDR+UNSIGNED('0'&MEM_DOB(8 DOWNTO 0));
                                            REGSPACE_DIN_MUX     <= '0';
                                            REGSPACE_WR_EN       <= '1';

                                        ELSIF(MEM_DOB(15 DOWNTO 12) = X"2") THEN

                                            STATE <= SW; -- STORE WORD
                   
                                            REGSPACE_RD_ADDR_1   <= MEM_DOB(11 DOWNTO 9);
                                            MEM_ADDRA            <= STD_LOGIC_VECTOR(XN_BADDR+UNSIGNED('0'&MEM_DOB(8 DOWNTO 0)));
                                            CURRENT_ADDRESS      <= XN_BADDR+UNSIGNED('0'&MEM_DOB(8 DOWNTO 0));
                                            MEM_WEA              <= '1';
                                            REGSPACE_WR_EN       <= '0';

                                        ELSIF(MEM_DOB(15 DOWNTO 12) = X"3") THEN

                                            STATE <= GACC; -- GET ACCUMMULATOR
                                       
                                            REGSPACE_DIN_MUX     <= '1';
                                            REGSPACE_WR_EN       <= '0';
                                            REGSPACE_WR_ADDR     <= MEM_DOB(11 DOWNTO 9);
      
                                        ELSIF(MEM_DOB(15 DOWNTO 12) = X"4") THEN

                                            STATE <= FMAC; -- MULTIPLY-ADD
                                            FMAC_MUX    <= '1';
                                            REGSPACE_RD_ADDR_0 <= MEM_DOB(5 DOWNTO 3);
                                            REGSPACE_RD_ADDR_1 <= MEM_DOB(2 DOWNTO 0);
                                            REGSPACE_WR_EN       <= '0';

                                        ELSIF(MEM_DOB(15 DOWNTO 12) = X"5") THEN

                                            STATE <= SMAC; -- MULTIPLY-SUBTRACT
                                            FMAC_MUX    <= '1';
                                            REGSPACE_RD_ADDR_0 <= MEM_DOB(5 DOWNTO 3);
                                            REGSPACE_RD_ADDR_1 <= MEM_DOB(2 DOWNTO 0);
                                            REGSPACE_WR_EN       <= '0';

                                        ELSIF(MEM_DOB(15 DOWNTO 12) = X"6") THEN

                                            STATE <= CLRACC; -- CLEAR ACCUMMULATOR

                                            FMAC_OPC <= "10";
                                            REGSPACE_WR_EN       <= '0';

                                        ELSIF(MEM_DOB(15 DOWNTO 12) = X"7") THEN

                                            STATE <= COMP; -- COMPARE

                                            FMAC_MUX <= '0';
                                            REGSPACE_RD_ADDR_0 <= MEM_DOB(5 DOWNTO 3);
                                            REGSPACE_RD_ADDR_1 <= MEM_DOB(2 DOWNTO 0);
                                            REGSPACE_WR_EN     <= '0';

                                        ELSIF(MEM_DOB(15 DOWNTO 12) = X"8") THEN  -- BRANCH-IF-LESSER

                                            STATE <= BIL;

                                            IF(LE = '1') THEN

                                                PC <= PC + UNSIGNED(MEM_DOB(9 DOWNTO 0));
        
                                            ELSE

                                                PC <= PC + 1;
        
                                            END IF;
 
                                        ELSIF(MEM_DOB(15 DOWNTO 12) = X"9") THEN -- BRANCH-IF-EQUAL

                                            STATE <= BIE;

                                            IF(EQ = '1') THEN
        
                                                PC <= PC + UNSIGNED(MEM_DOB(9 DOWNTO 0));
        
                                            ELSE
        
                                                PC <= PC + 1;
        
                                            END IF;

                                        ELSIF(MEM_DOB(15 DOWNTO 12) = X"A") THEN -- BRANCH-IF-GREATER

                                            STATE <= BIG;

                                            IF(GR = '1') THEN

                                                PC <= PC + UNSIGNED(MEM_DOB(9 DOWNTO 0));
        
                                            ELSE

                                                PC <= PC + 1;
        
                                            END IF;        

                                        ELSIF(MEM_DOB(15 DOWNTO 12) = X"B") THEN -- GENERATE SPIKE

                                            STATE <= SPK;

                                            GENERATE_SPIKE <= '1';                                         

                                        ELSIF(MEM_DOB(15 DOWNTO 12) = X"D") THEN

                                            STATE <= RET; -- PROGRAM FLOW COMPLETED

                                        ELSIF(MEM_DOB(15 DOWNTO 12) = X"E") THEN

                                           STATE <= STRF; -- SET REFRACTORY PERIOD

                                           NEW_REF_DUR <= MEM_DOB(7 DOWNTO 0);

                                        ELSE
                                            
                                            STATE <= STATE;

                                        END IF;                                       

                                    WHEN LW    =>

                                        INST_COUNTER <= INST_COUNTER + 1;
                                        
                                        IF(INST_COUNTER = 3) THEN

                                            STATE <= I_F;
                                            REGSPACE_WR_EN       <= '0';

                                            INST_COUNTER <= 0;
                                            PC <= PC + 1;

                                        END IF;

                                    WHEN SW    =>

                                        INST_COUNTER <= INST_COUNTER + 1;

                                        IF(INST_COUNTER = 1) THEN

                                            STATE <= I_F;
                                            MEM_WEA <= '0';
                                            PC <= PC + 1;

                                            INST_COUNTER <= 0;

                                        END IF;

                                    WHEN GACC =>

                                        INST_COUNTER <= INST_COUNTER + 1;

                                        IF(INST_COUNTER = 3) THEN

                                            REGSPACE_WR_EN   <= '1';
                                        
                                        ELSIF(INST_COUNTER = 4) THEN

                                            REGSPACE_WR_EN   <= '0';
                                            INST_COUNTER   <= 0;
                                            PC <= PC + 1;
                                            STATE <= I_F;

                                        END IF;

                                    WHEN FMAC =>
                                    
                                        if(INST_COUNTER = 0) then
                                            FMAC_MUX    <= '0';

                                            FMAC_START  <= '1';
                                            FMAC_OPC    <= "00";
                                            
                                            INST_COUNTER <= INST_COUNTER + 1;
    
                                        elsif(INST_COUNTER = 1) then

                                            FMAC_START  <= '0';

                                            INST_COUNTER <= INST_COUNTER + 1;
                                            
                                        elsif(INST_COUNTER = 2) THEN
                                        
                                            INST_COUNTER <= INST_COUNTER + 1;
                                            
                                        elsif(INST_COUNTER = 3) THEN

                                            INST_COUNTER   <= 0;
                                            PC <= PC + 1;
                                            STATE <= I_F;

                                        END IF;

                                    WHEN SMAC =>
                                   
                                        if(INST_COUNTER = 0) then

                                            FMAC_MUX    <= '0';
                                            FMAC_START  <= '1';
                                            FMAC_OPC    <= "01";
                                            
                                            INST_COUNTER <= INST_COUNTER + 1;
    
                                        elsif(INST_COUNTER = 1) then

                                            FMAC_START  <= '0';

                                            INST_COUNTER <= INST_COUNTER + 1;
                                            
                                        elsif(INST_COUNTER = 2) THEN
                                        
                                            INST_COUNTER <= INST_COUNTER + 1;
                                            
                                        elsif(INST_COUNTER = 3) THEN

                                            INST_COUNTER   <= 0;
                                            PC <= PC + 1;
                                            STATE <= I_F;

                                        END IF;                                    

                                    WHEN CLRACC =>

                                        STATE <= I_F;
                                        FMAC_OPC <= "00";
                                        PC <= PC + 1;

                                    WHEN COMP =>
                                   
                                        STATE <= I_F;

                                        PC <= PC + 1;

                                    WHEN BIL =>

                                        STATE <= I_F;

                                    WHEN BIE =>

                                        STATE <= I_F;
                                    
                                    WHEN BIG =>

                                        STATE <= I_F;

                                    WHEN SPK =>

                                        STATE <= I_F;

                                        PC <= PC + 1;

                                    WHEN STRF =>
                                   
                                        STATE <= I_F;

                                        PC <= PC + 1;

                                    WHEN RET =>

                                        PROG_FLOW_COMPLETE <= '1';
                                        
                                        IF(INST_COUNTER = 0) THEN
                                        
                                            INST_COUNTER <= INST_COUNTER + 1;
                                            SPK_VLD <= '1';
                                            
                                        ELSIF(INST_COUNTER = 1) THEN
                                        
                                            INST_COUNTER <= INST_COUNTER + 1;
                                            SPK_VLD <= '0';
                                            
                                        END IF;

                                    WHEN OTHERS =>
                                                NULL;

                                END CASE;

                            END IF;

                            END IF;

    END PROCESS MAIN_STATE_MACHINE;

END CRUEL_CRUEL_WORLD;