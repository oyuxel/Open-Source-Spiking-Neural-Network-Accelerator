library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package crossbar_primitives is

component INTERNAL_FIFO is
    generic(
        DEPTH : integer := 16;  -- Depth of the FIFO
        WIDTH : integer := 16   -- Width of each data word
    );
    port(
        clk       : in  std_logic;
        rst       : in  std_logic;
        wr_en     : in  std_logic;
        rd_en     : in  std_logic;
        data_in   : in  std_logic_vector(WIDTH-1 downto 0);
        data_out  : out std_logic_vector(WIDTH-1 downto 0);
        full      : out std_logic;
        empty     : out std_logic
    );
end component INTERNAL_FIFO;

component Pipeline_Adder is
    generic (
        N : integer := 8 
    );
    port (
        CLK    : in  std_logic;
        RST    : in  std_logic;
        INPUT  : in  std_logic_vector(16*N-1 downto 0); 
        OUTPUT : out std_logic_vector(15 downto 0)
    );
end component Pipeline_Adder;

component XBAR_PRIMITIVE_2x4 is
  Generic(
          SPIKE_PIPELINE_REGS  : integer range 0 to 1:= 1;
          OUTPUT_PIPELINE_REGS : integer range 0 to 1:= 1;
          ROW_1_PIPELINE_REGS  : integer range 0 to 1:= 1;
          ROW_2_PIPELINE_REGS  : integer range 0 to 1:= 1
        );
  Port ( 
        XBAR_CLK     : in  std_logic;
        XBAR_CLR     : in  std_logic;
        SPIKE_IN_0   : in  std_logic;
        SPIKE_IN_1   : in  std_logic;
        ROW0_CE      : in  std_logic;
        ROW1_CE      : in  std_logic;
        W00          : in  std_logic_vector(7  downto 0);
        W01          : in  std_logic_vector(7  downto 0);
        W02          : in  std_logic_vector(7  downto 0);
        W03          : in  std_logic_vector(7  downto 0);
        W10          : in  std_logic_vector(7  downto 0);
        W11          : in  std_logic_vector(7  downto 0);
        W12          : in  std_logic_vector(7  downto 0);
        W13          : in  std_logic_vector(7  downto 0);
        PE_OUT_0     : out std_logic_vector(15  downto 0);
        PE_OUT_1     : out std_logic_vector(15  downto 0);
        PE_OUT_2     : out std_logic_vector(15  downto 0);
        PE_OUT_3     : out std_logic_vector(15  downto 0)
        );
end component XBAR_PRIMITIVE_2x4;

end crossbar_primitives;