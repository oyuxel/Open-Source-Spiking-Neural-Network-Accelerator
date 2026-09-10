LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

ENTITY NMC_LOC_REGSPACE IS
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
END NMC_LOC_REGSPACE;

ARCHITECTURE SUMMER_WINE OF NMC_LOC_REGSPACE IS

    type ram_type is array (7 downto 0) of std_logic_vector (15 downto 0);
    signal REGSPACE : ram_type;

    attribute RAM_STYLE : string;
    attribute RAM_STYLE of REGSPACE: signal is "DISTRIBUTED";

    signal DOUT_0_REG : STD_LOGIC_VECTOR(15 DOWNTO 0);
    signal DOUT_1_REG : STD_LOGIC_VECTOR(15 DOWNTO 0);

    BEGIN

    WRCNTRL : process (CLK) begin

        if (rising_edge(CLK)) then
            if (WR_EN = '1') then
                REGSPACE(to_integer(unsigned(WR_ADDR))) <= DATA_IN;
            end if;
        end if;

    end process WRCNTRL;

    DOUT_0 <= REGSPACE(to_integer(unsigned(RD_ADDR_0)));
    DOUT_1 <= REGSPACE(to_integer(unsigned(RD_ADDR_1)));

--    OUTPUT_REGS : process (CLK) begin
--
--        if (rising_edge(CLK)) then
--        
--            DOUT_0 <= DOUT_0_REG;
--            DOUT_1 <= DOUT_1_REG;
--
--        end if;
--
--    end process OUTPUT_REGS;

   
END ARCHITECTURE SUMMER_WINE;