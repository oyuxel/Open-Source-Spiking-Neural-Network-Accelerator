library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package crossbar_utils is

    function log2(n : integer) return integer;
    function clogb2 (depth: in natural) return integer;
    function XBARCount(rows : integer) return integer;
    type SYNAPTIC_DATA is array (natural range<>) of std_logic_vector(15 downto 0); 
    type SYNAPSE_ADDRESS is array (natural range<>) of std_logic_vector(31 downto 0);  
    type SYNAPTIC_SUM is array (natural range<>) of std_logic_vector(15 downto 0);  
    type XBAR_RES is array (natural range <>,natural range <>) of std_logic_vector(15 downto 0);
    type COLINTDOUT is array (natural range <>) of std_logic_vector(15 downto 0);
    type SYNCNTR is array (natural range <>) of integer;
    type COLADDR is array (natural range <>) of integer; 
    type PSYNCNT is array (natural range <>) of integer; 
    type SPKCYCLES is array (natural range <>) of integer;
    
end crossbar_utils;

package body crossbar_utils is

  function XBARCount(rows : integer) return integer is
        variable result : integer;
    begin
        assert rows >= 2
            report "Error: Input rows must be 2 or greater."
            severity failure;
    
        assert rows mod 2 = 0
            report "Error: Input rows must be a multiple of 2."
            severity failure;
        result := rows / 2;
        return result;
    end function;
    
    function clogb2(depth : natural) return integer is
        variable temp    : integer := depth;
        variable ret_val : integer := 0;
    begin
        while temp > 1 loop
            ret_val := ret_val + 1;
            temp    := temp / 2;
        end loop;
        return ret_val;
    end function;

    function log2(n : integer) return integer is
        variable result : integer := 0;
        variable value : integer := n;
    begin
        while value > 1 loop
            value := value / 2;
            result := result + 1;
        end loop;
        return result;
    end function;

end package body crossbar_utils;
