library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- OPC
-- 00 : mac       ACC <-- ACC + A*B
-- 01 : smac      ACC <-- ACC - A*B (sign change)
-- 10 : clracc    ACC <-- X"000"


entity FMAC16 is
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
end entity;

architecture paint_it_black of fmac16 is

	function to_left(vec : unsigned) return integer is
        variable I : integer range 10 downto 0;
        begin
            I := 0;
            while vec(vec'left - I)='0' and I/=vec'left-vec'right loop
                I:= I+1;
            end loop;
            return I;
        end function;    

	signal ZERO_FLAG : std_logic;
	signal NAN_FLAG  : std_logic;

	signal MANTREG   : unsigned(21 downto 0);  
 	signal MANTREG_S1: unsigned(21 downto 0); 
    	signal MULTEXP   : unsigned(5 downto 0);   
	signal MULTEXP_S1: unsigned(5 downto 0); 
	signal MULTEXP_S2: unsigned(5 downto 0); 

	signal SIGN,ACSIGN,SUMSIGN	   : std_logic;
	signal MULTRESULT  : std_logic_vector(15 downto 0);
	signal ACCUMULATOR : unsigned(15 downto 0);

    signal SUMEXP                    : unsigned(4 downto 0);
    signal OP1MANT,OP2MANT,SUMMANT   : unsigned(11 downto 0);  
	signal OP1MANT_S1,OP2MANT_S1   	 : unsigned(11 downto 0); 
    signal DIF                       : unsigned(4 downto 0);
    signal EXP_1,EXP_2,MANT_1,MANT_2 : std_logic;

	type STATES is (IDLE,MULT_OPS,MULT_ALIGNMENT,MULT_FINAL_CUT,ADD_EXP_ASSIGNMENT,COMPARISON,ADD_MANTSHIFT,ADD_SUB,NORMALIZE,SIGNOUT);
	signal FMAC_STATE  : STATES;
	signal FMAC_NEXT   : STATES;
	signal sixBitVector              : std_logic_vector(5 downto 0);

	begin

	ACC <= std_logic_vector(ACCUMULATOR);
    NAN <= ACCUMULATOR(14) and ACCUMULATOR(13) and ACCUMULATOR(12) and ACCUMULATOR(11) and ACCUMULATOR(10);
	sixBitVector <= SIGN&ACSIGN&EXP_1&EXP_2&MANT_1&MANT_2;

	MAIN_STATE_MACHINE : process(CLK)

			variable val : integer range 0 to 10;

			begin
			
			if(rising_edge(CLK)) then

				if(RST = '1') then
					FMAC_NEXT <= IDLE;
					ACCUMULATOR <= (others=>'0');
				else

    			     case FMAC_NEXT is
    
    			     	when IDLE =>
    
    			     		if(START = '1') then
    
    			     			FMAC_NEXT  <= MULT_OPS;
    
    			     			if(OPC = "01") then
    			     				SIGN	   <=  not(A(15) xor B(15));
    			     			else
    			     				SIGN	   <=  A(15) xor B(15);
    			     			end if;
    
                         				MULTEXP    <= ('0'&unsigned(A(14 downto 10))) + ('0'&unsigned(B(14 downto 10)));
                         				MANTREG    <= ('1'&unsigned(A(9 downto 0))) * ('1'&unsigned(B(9 downto 0)));
    
    			     			if(A = X"0000" or B= X"0000") then
    
                         					ZERO_FLAG <= '1';
    
      			     	                else
    
                       						ZERO_FLAG <= '0';
    
         		     				end if;
    
    			     		else
    
    			     			FMAC_NEXT  <= IDLE;
    	 		     			ZERO_FLAG  <= '0';
    	 		     			NAN_FLAG   <= '0';
    	 		     			MANTREG    <= (others=>'0');  
     	 		     			MANTREG_S1 <= (others=>'0'); 
        	 	     			MULTEXP    <= (others=>'0');   
    	 		     			MULTEXP_S1 <= (others=>'0'); 
    	 		     			MULTEXP_S2 <= (others=>'0'); 
    	 		     			OP1MANT    <= (others=>'0'); 
    	 		     			OP2MANT    <= (others=>'0'); 
    	 		     			DIF        <= (others=>'0'); 
    	 		     			SIGN	   <= '0';
    			     			ACSIGN     <= '0';
    	 		     			MULTRESULT <= (others=>'0');
               	     		    EXP_1      <= '0';
                     			EXP_2      <= '0';
    			     			MANT_1 	   <= '0';
                     			MANT_2 	   <= '0';
                     			
    			     		end if;
    
    			     	when MULT_OPS =>
    
    			     		val := to_left(MANTREG(21 downto 11));
    
                     				if(MULTEXP < 14) then
    
                         				MULTEXP_S1 <= (others=>'0');
    
                     				else
    
                         				MULTEXP_S1 <= MULTEXP - "001110";
    
                     				end if;
    
    			     		FMAC_NEXT <= MULT_ALIGNMENT;
    
    			     	when MULT_ALIGNMENT =>
    
                            			if(MULTEXP_S1 = 0) then
    
                                 			MULTEXP_S2 <= MULTEXP_S1;
        
                             			else
        
                                 			MULTEXP_S2 <= MULTEXP_S1-val;
        
                             			end if;
    
                             			MANTREG_S1 <=shift_left(MANTREG,val);
    
    			     		FMAC_NEXT <= MULT_FINAL_CUT;
    
    			     	when MULT_FINAL_CUT => 
    
    			     		if(ZERO_FLAG = '0') then
    
                         				if (MANTREG_S1(10) = '0') then -- AUTOROUNDING
    
    			     				OP1MANT(9 downto 0) <= (MANTREG_S1(20 downto 11));
    							

                         				else
                             
    			     				OP1MANT(9 downto 0) <= (MANTREG_S1(20 downto 11)+1);
    
                         				end if;
    
    			     			OP1MANT(11 downto 10) <= "01";
    
    			     		else
    
    			     			OP1MANT <= (others=>'0');
    
    			     		end if;
    
					
    			     		OP2MANT(9 downto 0)   <= (ACCUMULATOR(9 downto 0));
    
    			     		if(ACCUMULATOR= X"0000") then
    
                             				OP2MANT(11 downto 10) <= "00";
    
                         			else
    
                             				OP2MANT(11 downto 10) <= "01";
    
                         			end if;
    
    			     		FMAC_NEXT <= COMPARISON;
    
    			     	when COMPARISON => 

						ACSIGN <= ACCUMULATOR(15);

						MULTRESULT <= SIGN & std_logic_vector(MULTEXP_S2(4 downto 0)) & std_logic_vector(OP1MANT(9 downto 0));
    			     		
                     				if(MULTEXP_S2(4 downto 0) > ACCUMULATOR(14 downto 10)) then
    
                         				SUMEXP <= MULTEXP_S2(4 downto 0);
                         				DIF    <= MULTEXP_S2(4 downto 0) - (ACCUMULATOR(14 downto 10));
    
    			     			         EXP_1 <= '1';
                     					EXP_2 <= '0';
    
                     				elsif(MULTEXP_S2(4 downto 0) < ACCUMULATOR(14 downto 10)) then
    
                         				SUMEXP <= (ACCUMULATOR(14 downto 10));
                         				DIF    <= (ACCUMULATOR(14 downto 10)) - MULTEXP_S2(4 downto 0);
    
    			     			        EXP_1 <= '0';
                     					EXP_2 <= '1';
    
                     				else 
    
                         				SUMEXP <= MULTEXP_S2(4 downto 0);
                         				DIF    <= (others=>'0');
    
    			     			        EXP_1 <= '0';
                     					EXP_2 <= '0';
    
                     				end if;
    
    
            	     			if(OP1MANT(9 downto 0) > ACCUMULATOR(9 downto 0)) then
    
                     					MANT_1 <= '1';
                     					MANT_2 <= '0';
    
            	     			elsif(OP1MANT(9 downto 0) < ACCUMULATOR(9 downto 0)) then
    
                     					MANT_1 <= '0';
                     					MANT_2 <= '1';
    
            	     			else
    
                     					MANT_1 <= '0';
                     					MANT_2 <= '0';
    
            	     			end if;
    
    			     		FMAC_NEXT <= ADD_MANTSHIFT;
    
    			     	when ADD_MANTSHIFT => 
    
               	     				if(EXP_1 ='1' and EXP_2 ='0') then
    
                             				OP2MANT_S1 <= shift_right(OP2MANT,to_integer(DIF));
                             				OP1MANT_S1 <= OP1MANT;
    
                     				elsif(EXP_1 ='0' and EXP_2 ='1') then
    
                             				OP1MANT_S1 <= shift_right(OP1MANT,to_integer(DIF));
                             				OP2MANT_S1 <= OP2MANT;
    
                     				else 
    
                             				OP1MANT_S1 <= OP1MANT;
                             				OP2MANT_S1 <= OP2MANT;
    
                     				end if;
    	
    			     		FMAC_NEXT <= ADD_SUB;
    
    			     	when ADD_SUB => 
    
            	     				if(sixBitVector(5)= sixBitVector(4)) then
    
                     					SUMMANT <= OP1MANT_S1 + OP2MANT_S1;
                     					SUMSIGN <= sixBitVector(4);
    
            	     				elsif(sixBitVector = B"010000" ) then 
      
            	     					SUMMANT <= (others=>'0');
            	     					SUMSIGN <= sixBitVector(5);
    
            	     				elsif(sixBitVector = B"010100" or sixBitVector = B"010101" or sixBitVector = B"010110" or sixBitVector = B"010001") then 
            	     					SUMMANT <= OP2MANT_S1 - OP1MANT_S1;
            	     					SUMSIGN <= sixBitVector(4);
    
            	     				elsif(sixBitVector = B"011000" or sixBitVector = B"011001" or sixBitVector = B"011010" or sixBitVector = B"010010") then 
            	     					SUMMANT <= OP1MANT_S1 - OP2MANT_S1;
            	     					SUMSIGN <= sixBitVector(5);
    
            	     				elsif(sixBitVector = B"100000" ) then 
            	     					SUMMANT <= (others=>'0');
            	     					SUMSIGN <= sixBitVector(4);
            
            	     				elsif(sixBitVector = B"100100" or sixBitVector = B"100101" or sixBitVector = B"100110" or sixBitVector = B"100001") then 
           		     					SUMMANT <= OP2MANT_S1 - OP1MANT_S1;
            	     					SUMSIGN <= sixBitVector(4);
    
            	     				elsif(sixBitVector = B"101000" or sixBitVector = B"101001" or sixBitVector = B"101010" or sixBitVector = B"100010" ) then 
            	     					SUMMANT <= OP1MANT_S1 - OP2MANT_S1;
            	     					SUMSIGN <= sixBitVector(5);
      
            	     				end if;
    
    			     		FMAC_NEXT <= NORMALIZE;
    
    			     	when NORMALIZE => 
    
                             if(SUMMANT(11) = '1') then
            
                                 ACCUMULATOR <= SUMSIGN & (SUMEXP+1) & (SUMMANT(10 downto 1));
            
                             elsif(SUMMANT(11 downto 10) = "01") then
            
                                 ACCUMULATOR <= SUMSIGN & (SUMEXP) & (SUMMANT(9 downto 0));
            
                             elsif(SUMMANT(11 downto 9) = "001") then
            
                                 ACCUMULATOR <= SUMSIGN & (SUMEXP-1) & (SUMMANT(8 downto 0))&'0';
            
                             elsif(SUMMANT(11 downto 8) = "0001") then
            
                                 ACCUMULATOR <= SUMSIGN & (SUMEXP-2) & (SUMMANT(7 downto 0))&"00";
            
                             elsif(SUMMANT(11 downto 7) = "00001") then
            
                                 ACCUMULATOR <= SUMSIGN & (SUMEXP-3) & (SUMMANT(6 downto 0))&"000";
            
                             elsif(SUMMANT(11 downto 6) = "000001") then
            
                                 ACCUMULATOR <= SUMSIGN & (SUMEXP-4) & (SUMMANT(5 downto 0))&"0000";
            
                             elsif(SUMMANT(11 downto 5) = "0000001") then
                             
                                 ACCUMULATOR <= SUMSIGN & (SUMEXP-5) & (SUMMANT(4 downto 0))&"00000";
                             
                             elsif(SUMMANT(11 downto 4) = "00000001") then
                             
                                 ACCUMULATOR <= SUMSIGN & (SUMEXP-6) & (SUMMANT(3 downto 0))&"000000";
                             
                             elsif(SUMMANT(11 downto 3) = "000000001") then
                             
                                 ACCUMULATOR <= SUMSIGN & (SUMEXP-7) & (SUMMANT(2 downto 0))&"0000000";
                             
                             elsif(SUMMANT(11 downto 2) = "0000000001") then
                             
                                 ACCUMULATOR <= SUMSIGN & (SUMEXP-8) & (SUMMANT(1 downto 0))&"00000000";
            
                             elsif(SUMMANT(11 downto 1) = "00000000001") then
                             
                                 ACCUMULATOR <= SUMSIGN & (SUMEXP-9) & SUMMANT(0)&"000000000";
            
                             elsif(SUMMANT(11 downto 0) = "000000000001") then
                             
                                 ACCUMULATOR <= SUMSIGN & (SUMEXP-10)&"0000000000";
                             
                             elsif(SUMMANT(11 downto 0) = "000000000000") then
                             
                                 ACCUMULATOR <= (others=>'0');
            
                             end if;
    
                             FMAC_NEXT <= IDLE;
    			     	
    
    			     	when others=> 
    			     			NULL;

			          end case;
			end if;
			
	end if;	

	end process MAIN_STATE_MACHINE;

end architecture paint_it_black;


--library ieee;
--use ieee.std_logic_1164.all;
--use ieee.numeric_std.all;
--
---- OPC
---- 00 : mac       ACC <-- ACC + A*B
---- 01 : smac      ACC <-- ACC - A*B (sign change)
---- 10 : clracc    ACC <-- X"000"
--
--
--entity FMAC16 is
--    Port(
--        CLK    : in  std_logic;
--        RST    : in  std_logic;
--	START  : in  std_logic;
--        A      : in  std_logic_vector(15 downto 0);
--        B      : in  std_logic_vector(15 downto 0);
--        ACC    : out std_logic_vector(15 downto 0);
--        OPC    : in  std_logic_vector( 1 downto 0);
--        NAN    : out std_logic
--    );
--end entity;
--
--architecture vrax of fmac16 is
--
--    signal tempsum      : std_logic_vector(15 downto 0);
--    signal tempsum_1    : std_logic_vector(15 downto 0);
--    signal tempsum_2    : std_logic_vector(15 downto 0);
--    signal tempsum_3    : std_logic_vector(15 downto 0);
--    signal tempsum_4    : std_logic_vector(15 downto 0);
--    signal tempsum_5    : std_logic_vector(15 downto 0);
--    signal tempmult     : std_logic_vector(15 downto 0);
--    signal tempA,tempB  : std_logic_vector(15 downto 0);
--    signal adderOP1     : std_logic_vector(15 downto 0);
--    signal mulNAN,addNAN: std_logic;
--    signal ACCREG       : std_logic_vector(15 downto 0);
--    signal START_1      : std_logic;
--    signal START_2      : std_logic;
--    signal START_3      : std_logic;
--    signal START_4      : std_logic;
--    signal START_5      : std_logic;
--    signal START_6      : std_logic;
--    signal START_7      : std_logic;
--    signal START_8      : std_logic;
--    signal START_9      : std_logic;
--    
--    component FP16ADD is
--        Port(
--             RST                : in  std_logic; -- ACTIVE LOW RST
--             CLK                : in  std_logic;
--             OP1                : in  std_logic_vector(15 downto 0);
--             OP2                : in  std_logic_vector(15 downto 0);
--             SUM                : out std_logic_vector(15 downto 0);
--             NAN                : out std_logic
--            );
--    end component FP16ADD;
--
--    component FP16MULT is
--        Port(
--             rst    : in  std_logic;  -- ACTIVE LOW SYNCHRONOUS RESET
--             clk    : in  std_logic;
--             OP1    : in  std_logic_vector(15 downto 0);
--             OP2    : in  std_logic_vector(15 downto 0);
--             MULT   : out std_logic_vector(15 downto 0);
--             NAN    : out std_logic
--            );
--    end component FP16MULT;
--
--begin
--
--    NAN <= mulNAN or addNAN;
--
--    tempA <= A when OPC = "00" else
--             A when OPC = "01" else
--             A when OPC = "10" else
--             (others=>'0');
--
--    tempB <= B when OPC = "00" else
--             (not B(15))&B(14 downto 0) when OPC = "01" else
--             B;
--
--    MULT_INIT :  FP16MULT
--        Port Map(
--                rst    => RST, 
--                clk    => CLK,
--                OP1    => tempA,
--                OP2    => tempB,
--                MULT   => tempmult,
--                NAN    => mulNAN
--                );
--
--
--    ADD_INIT :  FP16ADD
--        Port Map(
--                RST    => RST,            
--                CLK    => CLK,                     
--                OP1    => tempsum_4,           
--                OP2    => tempmult,           
--                SUM    => tempsum,           
--                NAN    => addNAN          
--                );
--
--  ACC <= ACCREG;
--
--    process(CLK) 
--
--	begin
--    
--		if(rising_edge(clk)) then
--
--			if(START_9 = '1') then
--
--				ACCREG <= tempsum;
--			else
--				ACCREG <= ACCREG;
--			end if;
--
--		end if;
--    end process;
--    
--    acc_cntrl : process(CLK)
--
--    begin
--
--        if(rising_edge(clk)) then
--
--         if(RST = '1') then
--
--		 tempsum_2  <= (others =>'0');
--		 tempsum_3  <= (others =>'0');
--		 tempsum_4  <= (others =>'0');
--		 START_1    <= '0';
--		 START_2    <= '0';
--		 START_3    <= '0';
--		 START_4    <= '0';
--		 START_5    <= '0';
--         START_6    <= '0';
--		 START_7    <= '0';
--		 START_8    <= '0';
--   		 START_9    <= '0';
--   		 
--	     else
--
--         tempsum_1  <= tempsum;
--		 tempsum_2  <= tempsum_1;
--		 tempsum_3  <= tempsum_2;
--		 tempsum_4  <= tempsum_3;
--
--         START_1  <= START;
--		 START_2  <= START_1;
--		 START_3  <= START_2;
--		 START_4  <= START_3;
--		 START_5  <= START_4;
--         START_6  <= START_5;
--		 START_7  <= START_6;
--		 START_8  <= START_7;
--         START_9  <= START_8;
--         
--         end if;
--
--        end if;
--
--    end process acc_cntrl;
--
--end architecture;