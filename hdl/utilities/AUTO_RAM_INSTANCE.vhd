
--  Xilinx True Dual Port RAM Byte Write Read First with Dual Clock
--  This code implements a parameterizable true dual port memory (both ports can read and write).
--  The behavior of this RAM is when data is written, the prior memory contents at the write
--  address are presented on the output port.  If the output data is
--  not needed during writes or the last read value is desired to be retained,
--  it is suggested to use a no change RAM as it is more power efficient.
--  If a reset or enable is not necessary, it may be tied off or removed from the code.
 --  Modify the parameters for the desired RAM characteristics.

library ieee;
use ieee.std_logic_1164.all;

package ram_pkg is
    function clogb2 (depth: in natural) return integer;
end ram_pkg;

package body ram_pkg is

function clogb2( depth : natural) return integer is
variable temp    : integer := depth;
variable ret_val : integer := 0;
begin
    while temp > 1 loop
        ret_val := ret_val + 1;
        temp    := temp / 2;
    end loop;
    return ret_val;
end function;

end package body ram_pkg;


library ieee;
library work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ram_pkg.all;

entity AUTO_RAM_INSTANCE is
generic (
    RAM_WIDTH       : integer := 32;                      -- Specify RAM data width
    RAM_DEPTH       : integer := 2048  ;            -- Specify RAM depth (number of entries)
    RAM_PERFORMANCE : string  := "LOW_LATENCY"      -- Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
    );

port (
        addra : in std_logic_vector((clogb2(RAM_DEPTH)-1) downto 0);     -- Port A Address bus, width determined from RAM_DEPTH
        addrb : in std_logic_vector((clogb2(RAM_DEPTH)-1) downto 0);     -- Port B Address bus, width determined from RAM_DEPTH
        dina  : in std_logic_vector(RAM_WIDTH-1 downto 0);		                 -- Port A RAM input data
        dinb  : in std_logic_vector(RAM_WIDTH-1 downto 0);		                 -- Port B RAM input data
        clka  : in std_logic;                       			         -- Port A Clock
        clkb  : in std_logic;                       			         -- Port B Clock
        wea   : in std_logic;                       			         -- Port A Write enable
        web   : in std_logic;                       			         -- Port B Write enable
        ena   : in std_logic;                       			         -- Port A RAM Enable, for additional power savings, disable port when not in use
        enb   : in std_logic;                       			         -- Port B RAM Enable, for additional power savings, disable port when not in use
        rsta  : in std_logic;                       			         -- Port A Output reset (does not affect memory contents)
        rstb  : in std_logic;                       			         -- Port B Output reset (does not affect memory contents)
        regcea: in std_logic;                       			         -- Port A Output register enable
        regceb: in std_logic;                       			         -- Port B Output register enable
        douta : out std_logic_vector(RAM_WIDTH-1 downto 0);   			         --  Port A RAM output data
        doutb : out std_logic_vector(RAM_WIDTH-1 downto 0)  
    );

end AUTO_RAM_INSTANCE;


architecture the_passenger of AUTO_RAM_INSTANCE is

constant C_RAM_WIDTH : integer := RAM_WIDTH;
constant C_RAM_DEPTH : integer := RAM_DEPTH;
constant C_RAM_PERFORMANCE : string := RAM_PERFORMANCE;

signal douta_reg : std_logic_vector(C_RAM_WIDTH-1 downto 0) := (others => '0');
signal doutb_reg : std_logic_vector(C_RAM_WIDTH-1 downto 0) := (others => '0');

type ram_type is array (C_RAM_DEPTH-1 downto 0) of std_logic_vector (C_RAM_WIDTH-1 downto 0);          -- 2D Array Declaration for RAM signal

signal ram_data_a : std_logic_vector(C_RAM_WIDTH-1 downto 0) ;
signal ram_data_b : std_logic_vector(C_RAM_WIDTH-1 downto 0) ;

-- The folowing code either initializes the memory values to a specified file or to all zeros to match hardware

function init_from_file_or_zeroes(ramfile : string) return ram_type is
begin
        return (others => (others => '0'));
end;
-- Following code defines RAM

shared variable ram_name : ram_type := init_from_file_or_zeroes("ZEROES");

begin

process(clka)
begin
    if(clka'event and clka = '1') then
        if(ena = '1') then
            if(wea = '1') then
                ram_name(to_integer(unsigned(addra))) := dina;
                ram_data_a <= dina;
            else
                ram_data_a <= ram_name(to_integer(unsigned(addra)));
            end if;
        end if;
    end if;
end process;

process(clkb)
begin
    if(clkb'event and clkb = '1') then
        if(enb = '1') then
            if(web = '1') then
                ram_name(to_integer(unsigned(addrb))) := dinb;
                ram_data_b <= dinb;
            else
                ram_data_b <= ram_name(to_integer(unsigned(addrb)));
            end if;
        end if;
    end if;
end process;

--  Following code generates LOW_LATENCY (no output register)
--  Following is a 1 clock cycle read latency at the cost of a longer clock-to-out timing

no_output_register : if C_RAM_PERFORMANCE = "LOW_LATENCY" generate
    douta <= ram_data_a;
    doutb <= ram_data_b;
end generate;

--  Following code generates HIGH_PERFORMANCE (use output register)
--  Following is a 2 clock cycle read latency with improved clock-to-out timing

output_register : if C_RAM_PERFORMANCE = "HIGH_PERFORMANCE"  generate
process(clka)
begin
    if(clka'event and clka = '1') then
        if(rsta = '1') then
            douta_reg <= (others => '0');
        elsif(regcea = '1') then
            douta_reg <= ram_data_a;
        end if;
    end if;
end process;
douta <= douta_reg;

process(clkb)
begin
    if(clkb'event and clkb = '1') then
        if(rstb = '1') then
            doutb_reg <= (others => '0');
        elsif(regceb = '1') then
            doutb_reg <= ram_data_b;
        end if;
    end if;
end process;
doutb <= doutb_reg;

end generate;
end the_passenger;

-- The following is an instantiation template for xilinx_true_dual_port_read_first_byte_write_2_clock_ram
-- Component Declaration
-- Uncomment the below component declaration when using
--component xilinx_true_dual_port_read_first_byte_write_2_clock_ram is
-- generic (
-- NB_COL : integer,
-- COL_WIDTH : integer,
-- RAM_DEPTH : integer,
-- RAM_PERFORMANCE : string,
-- INIT_FILE : string
--);
--port
--(
-- addra : in std_logic_vector(clogb2(RAM_DEPTH)-1) downto 0);
-- addrb : in std_logic_vector(clogb2(RAM_DEPTH)-1) downto 0);
-- dina  : in std_logic_vector(NB_COL*COL_WIDTH-1 downto 0);
-- dinb  : in std_logic_vector(NB_COL*COL_WIDTH-1 downto 0);
-- clka  : in std_logic;
-- clkb  : in std_logic;
-- wea   : in std_logic_vector(NB_COL*COL_WIDTH-1 downto 0);
-- web   : in std_logic_vector(NB_COL*COL_WIDTH-1 downto 0);
-- ena   : in std_logic;
-- enb   : in std_logic;
-- rsta  : in std_logic;
-- rstb  : in std_logic;
-- regcea: in std_logic;
-- regceb: in std_logic;
-- douta : out std_logic_vector(NB_COL*COL_WIDTH-1 downto 0)
-- doutb : out std_logic_vector(NB_COL*COL_WIDTH-1 downto 0)
--);
--end component;

-- Instantiation
-- Uncomment the instantiation below when using
--<your_instance_name> : xilinx_true_dual_port_read_first_byte_write_2_clock_ram
--
-- generic map (
-- NB_COL => 4,
-- COL_WID => 8,
-- RAM_DEPTH => 1024,
-- RAM_PERFORMANCE => "HIGH_PERFORMANCE",
-- INIT_FILE => "" 
--)
--  port map  (
-- addra  => addra,
-- addrb  => addrb,
-- dina   => dina,
-- dinb   => dinb,
-- clka   => clka,
-- clkb   => clkb,
-- wea    => wea,
-- web    => web,
-- ena    => ena,
-- enb    => enb,
-- rsta   => rsta,
-- rstb   => rstb,
-- regcea => regcea,
-- regceb => regceb,
-- douta  => douta,
-- doutb  => doutb
--);
							
							