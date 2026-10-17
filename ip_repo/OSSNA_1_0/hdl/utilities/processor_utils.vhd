library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package processor_utils is
function FindMax (val1 : integer;val2 : integer;val3 : integer)return integer;

type SYNAPTICMEMDATA is array (natural range <>) of std_logic_vector(15 downto 0);
type SYNAPTICMEMADDR is array (natural range <>) of std_logic_vector(31 downto 0);

type PARAMMEMDATA is array (natural range <>) of std_logic_vector(31 downto 0);
type PARAMMEMADDR is array (natural range <>) of std_logic_vector(31 downto 0);

type LASTSTIME      is array (natural range <>) of STD_LOGIC_VECTOR(7  DOWNTO 0);   
type SYNQFACTOR     is array (natural range <>) of STD_LOGIC_VECTOR(15 DOWNTO 0);   
type PROGRAMFLOWLOW is array (natural range <>) of STD_LOGIC_VECTOR(9  DOWNTO 0);   
type NPARAMDATA     is array (natural range <>) of STD_LOGIC_VECTOR(15 DOWNTO 0);   
type NPARAMADDR     is array (natural range <>) of STD_LOGIC_VECTOR(9  DOWNTO 0);   
type REFDURATION    is array (natural range <>) of std_logic_vector(7  downto 0);   
type LEARNLUTLOW    is array (natural range <>) of std_logic_vector(15 downto 0);   

type COLUMNSTARTADDR is array (natural range <>) of  std_logic_vector(31 downto 0);

end processor_utils;

package body processor_utils is

function FindMax (
    val1 : integer;
    val2 : integer;
    val3 : integer
) return integer is
begin
    if val1 >= val2 and val1 >= val3 then
        return val1;
    elsif val2 >= val3 then
        return val2;
    else
        return val3;
    end if;
end function FindMax;

end package body processor_utils;
