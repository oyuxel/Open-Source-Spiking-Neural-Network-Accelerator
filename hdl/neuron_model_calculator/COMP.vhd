library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity COMP is --(NO?N1)
    Port (
            N0    : in std_logic_vector(15 downto 0);
            N1    : in std_logic_vector(15 downto 0);
            GREAT : out std_logic;
            LESS  : out std_logic;
            EQUAL : out std_logic
        );
end COMP;

architecture balls_to_the_wall of COMP is

    signal SN0,SN1         : std_logic;
    signal EXP_GREAT       : std_logic;
    signal EXP_EQUAL       : std_logic;
    signal EXP_LESS        : std_logic;
    signal MANT_GREAT      : std_logic;
    signal MANT_EQUAL      : std_logic;
    signal MANT_LESS       : std_logic;

    signal EIGHTBITS       : std_logic_vector(7 downto 0);

begin

    process(N0,N1) begin

        SN0 <= N0(15);
        SN1 <= N1(15);
        
        if(N0(14 downto 10) > N1(14 downto 10)) then
        
            EXP_GREAT <= '1';
            EXP_EQUAL <= '0';
            EXP_LESS  <= '0';
        
        elsif(N0(14 downto 10) = N1(14 downto 10)) then
            
            EXP_GREAT <= '0';
            EXP_EQUAL <= '1';
            EXP_LESS  <= '0';
        
        else

            EXP_GREAT <= '0';
            EXP_EQUAL <= '0';
            EXP_LESS  <= '1';
        
        end if;

        if(N0(9 downto 0) > N1(9 downto 0)) then
        
            MANT_GREAT <= '1';
            MANT_EQUAL <= '0';
            MANT_LESS  <= '0';
        
        elsif(N0(9 downto 0) = N1(9 downto 0)) then
            
            MANT_GREAT <= '0';
            MANT_EQUAL <= '1';
            MANT_LESS  <= '0';

        else
            
            MANT_GREAT <= '0';
            MANT_EQUAL <= '0';  
            MANT_LESS  <= '1';          
        
        end if;

    end process;
       
    EIGHTBITS <= SN0&SN1&EXP_GREAT&EXP_LESS&EXP_EQUAL&MANT_GREAT&MANT_LESS&MANT_EQUAL ; 

    process(EIGHTBITS) begin
        
        if(EIGHTBITS = "00001001") then
            GREAT <= '0';
            LESS  <= '0';
            EQUAL <= '1';
        elsif(EIGHTBITS = "00001010") then
            GREAT <= '0';
            LESS  <= '1';
            EQUAL <= '0';
        elsif(EIGHTBITS = "00001100") then
            GREAT <= '1';
            LESS  <= '0';
            EQUAL <= '0';
        elsif(EIGHTBITS = "00010001") then
            GREAT <= '0';
            LESS  <= '1';
            EQUAL <= '0';
        elsif(EIGHTBITS = "00010010") then
            GREAT <= '0';
            LESS  <= '1';
            EQUAL <= '0';
        elsif(EIGHTBITS = "00010100") then
            GREAT <= '0';
            LESS  <= '1';
            EQUAL <= '0';
        elsif(EIGHTBITS = "00100001") then
            GREAT <= '1';
            LESS  <= '0';
            EQUAL <= '0';
        elsif(EIGHTBITS = "00100010") then
            GREAT <= '1';
            LESS  <= '0';
            EQUAL <= '0';
        elsif(EIGHTBITS = "00100100") then
            GREAT <= '1';
            LESS  <= '0';
            EQUAL <= '0';
        elsif(EIGHTBITS = "11001001") then
            GREAT <= '0'; 
            LESS  <= '0';
            EQUAL <= '1';
        elsif(EIGHTBITS = "11001010") then
            GREAT <= '1'; 
            LESS  <= '0';
            EQUAL <= '0';
        elsif(EIGHTBITS = "11001100") then
            GREAT <= '0';
            LESS  <= '1';
            EQUAL <= '0';
        elsif(EIGHTBITS = "11010001") then
            GREAT <= '1'; 
            LESS  <= '0';
            EQUAL <= '0';
        elsif(EIGHTBITS = "11010010") then
            GREAT <= '1'; 
            LESS  <= '0';
            EQUAL <= '0';
        elsif(EIGHTBITS = "11010100") then
            GREAT <= '1'; 
            LESS  <= '0';
            EQUAL <= '0';
        elsif(EIGHTBITS = "11100001") then
            GREAT <= '0'; 
            LESS  <= '1';
            EQUAL <= '0';
        elsif(EIGHTBITS = "11100010") then
            GREAT <= '0'; 
            LESS  <= '1';
            EQUAL <= '0';
        elsif(EIGHTBITS = "11100100") then
            GREAT <= '0'; 
            LESS  <= '1';
            EQUAL <= '0';
        elsif(EIGHTBITS = "10001001")then
            GREAT <='0';
            LESS  <= '1';
            EQUAL <= '0';
        elsif(EIGHTBITS = "10001010")then
            GREAT <='0';
            LESS  <= '1';
            EQUAL <= '0';
        elsif(EIGHTBITS = "10001100")then
            GREAT <='0';
            LESS  <= '1';
            EQUAL <= '0';
        elsif(EIGHTBITS = "10010001")then
            GREAT <='0';
            LESS  <= '1';
            EQUAL <= '0';
        elsif(EIGHTBITS = "10010010")then
            GREAT <='0';
            LESS  <= '1';
            EQUAL <= '0';
        elsif(EIGHTBITS = "10010100")then
            GREAT <='0';
            LESS  <= '1';
            EQUAL <= '0';
        elsif(EIGHTBITS = "10100001")then
            GREAT <='0';
            LESS  <= '1';
            EQUAL <= '0';
        elsif(EIGHTBITS = "10100010")then
            GREAT <='0';
            LESS  <= '1';
            EQUAL <= '0';
        elsif(EIGHTBITS = "10100100")then
            GREAT <='0';
            LESS  <= '1';
            EQUAL <= '0';
		elsif(EIGHTBITS = "01001001") then
            GREAT <= '1';
            LESS  <= '0';
            EQUAL <= '0';
        elsif(EIGHTBITS = "01001010") then
            GREAT <= '1';
            LESS  <= '0';
            EQUAL <= '0';
        elsif(EIGHTBITS = "01001100") then
            GREAT <= '1';
            LESS  <= '0';
            EQUAL <= '0';
        elsif(EIGHTBITS = "01010001") then
            GREAT <= '1';
            LESS  <= '0';
            EQUAL <= '0';
        elsif(EIGHTBITS = "01010010") then
            GREAT <= '1';
            LESS  <= '0';
            EQUAL <= '0';
        elsif(EIGHTBITS = "01010100") then
            GREAT <= '1';
            LESS  <= '0';
            EQUAL <= '0';
        elsif(EIGHTBITS = "01100001") then
            GREAT <= '1';
            LESS  <= '0';
            EQUAL <= '0';
        elsif(EIGHTBITS = "01100010") then
            GREAT <= '1';
            LESS  <= '0';
            EQUAL <= '0';
        elsif(EIGHTBITS = "01100100") then
            GREAT <= '1';
            LESS  <= '0';
            EQUAL <= '0';
        end if;

    end process;

end balls_to_the_wall;
							

			
