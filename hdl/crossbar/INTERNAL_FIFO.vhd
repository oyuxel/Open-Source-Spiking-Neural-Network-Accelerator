library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity INTERNAL_FIFO is
    generic(
        DEPTH : integer := 16; 
        WIDTH : integer := 16   
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
end entity INTERNAL_FIFO;

architecture king_nothing of INTERNAL_FIFO is
    type memory_type is array (0 to DEPTH-1) of std_logic_vector(WIDTH-1 downto 0);
    signal memory     : memory_type;
    signal wr_pointer : integer range 0 to DEPTH-1 := 0;
    signal rd_pointer : integer range 0 to DEPTH-1 := 0;
    signal fifo_count : integer range 0 to DEPTH := 0;

    signal fifo_full  : std_logic;
    signal fifo_empty : std_logic;
    
    
    attribute RAM_STYLE : string;
    attribute RAM_STYLE of memory: signal is "distributed";

begin

    write_process : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                wr_pointer <= 0;
            elsif wr_en = '1' and fifo_full = '0' then
                memory(wr_pointer) <= data_in;
                wr_pointer <= (wr_pointer + 1) mod DEPTH;
            end if;
        end if;
    end process;

    read_process : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                rd_pointer <= 0;
                data_out <= (others => '0');
            elsif rd_en = '1' and fifo_empty = '0' then
                data_out <= memory(rd_pointer);
                rd_pointer <= (rd_pointer + 1) mod DEPTH;
            end if;
        end if;
    end process;

    count_process : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                fifo_count <= 0;
            else
                if (wr_en = '1' and fifo_full = '0') and (rd_en = '0' or fifo_empty = '1') then
                    fifo_count <= fifo_count + 1;
                elsif (rd_en = '1' and fifo_empty = '0') and (wr_en = '0' or fifo_full = '1') then
                    fifo_count <= fifo_count - 1;
                end if;
            end if;
        end if;
    end process;

    fifo_full  <= '1' when fifo_count = DEPTH else '0';
    fifo_empty <= '1' when fifo_count = 0 else '0';

    full <= fifo_full;
    empty <= fifo_empty;

end architecture king_nothing;
