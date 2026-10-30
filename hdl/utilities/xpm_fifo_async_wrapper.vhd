library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library xpm;
use xpm.vcomponents.all;

entity xpm_fifo_async_wrapper is
    generic (
        FIFO_MEMORY_TYPE    : string  := "auto";    
        FIFO_WRITE_DEPTH    : integer := 2048;      
        WRITE_DATA_WIDTH    : integer := 32;        
        READ_DATA_WIDTH     : integer := 32;        
        READ_MODE           : string  := "std";     
        FIFO_READ_LATENCY   : integer := 1;         
        PROG_EMPTY_THRESH   : integer := 10;        
        PROG_FULL_THRESH    : integer := 10;        
        WR_DATA_COUNT_WIDTH : integer := 1;         
        RD_DATA_COUNT_WIDTH : integer := 1;         
        CDC_SYNC_STAGES     : integer := 2;         
        RELATED_CLOCKS      : integer := 0;         
        CASCADE_HEIGHT      : integer := 0;         
        DOUT_RESET_VALUE    : string  := "0";       
        ECC_MODE            : string  := "no_ecc";  
        FULL_RESET_VALUE    : integer := 0;         
        SIM_ASSERT_CHK      : integer := 0;         
        USE_ADV_FEATURES    : string  := "0707";    
        WAKEUP_TIME         : integer := 0          
    );
    port (
        rst           : in  std_logic;
        sleep         : in  std_logic := '0';
        wr_clk        : in  std_logic;
        wr_en         : in  std_logic;
        din           : in  std_logic_vector(WRITE_DATA_WIDTH - 1 downto 0);
        full          : out std_logic;
        almost_full   : out std_logic;
        prog_full     : out std_logic;
        overflow      : out std_logic;
        wr_ack        : out std_logic;
        wr_rst_busy   : out std_logic;
        wr_data_count : out std_logic_vector(WR_DATA_COUNT_WIDTH - 1 downto 0);
        rd_clk        : in  std_logic;
        rd_en         : in  std_logic;
        dout          : out std_logic_vector(READ_DATA_WIDTH - 1 downto 0);
        empty         : out std_logic;
        almost_empty  : out std_logic;
        prog_empty    : out std_logic;
        underflow     : out std_logic;
        data_valid    : out std_logic;
        rd_rst_busy   : out std_logic;
        rd_data_count : out std_logic_vector(RD_DATA_COUNT_WIDTH - 1 downto 0);
        injectsbiterr : in  std_logic := '0';
        injectdbiterr : in  std_logic := '0';
        sbiterr       : out std_logic;
        dbiterr       : out std_logic
    );
end entity xpm_fifo_async_wrapper;

architecture rtl of xpm_fifo_async_wrapper is
begin

    xpm_fifo_async_inst : xpm_fifo_async
    generic map (
        CASCADE_HEIGHT      => CASCADE_HEIGHT,
        CDC_SYNC_STAGES     => CDC_SYNC_STAGES,
        DOUT_RESET_VALUE    => DOUT_RESET_VALUE,
        ECC_MODE            => ECC_MODE,
        EN_SIM_ASSERT_ERR   => "warning",
        FIFO_MEMORY_TYPE    => FIFO_MEMORY_TYPE,
        FIFO_READ_LATENCY   => FIFO_READ_LATENCY,
        FIFO_WRITE_DEPTH    => FIFO_WRITE_DEPTH,
        FULL_RESET_VALUE    => FULL_RESET_VALUE,
        PROG_EMPTY_THRESH   => PROG_EMPTY_THRESH,
        PROG_FULL_THRESH    => PROG_FULL_THRESH,
        RD_DATA_COUNT_WIDTH => RD_DATA_COUNT_WIDTH,
        READ_DATA_WIDTH     => READ_DATA_WIDTH,
        READ_MODE           => READ_MODE,
        RELATED_CLOCKS      => RELATED_CLOCKS,
        SIM_ASSERT_CHK      => SIM_ASSERT_CHK,
        USE_ADV_FEATURES    => USE_ADV_FEATURES,
        WAKEUP_TIME         => WAKEUP_TIME,
        WRITE_DATA_WIDTH    => WRITE_DATA_WIDTH,
        WR_DATA_COUNT_WIDTH => WR_DATA_COUNT_WIDTH
    )
    port map (
        rst           => rst,
        sleep         => sleep,
        
        wr_clk        => wr_clk,
        wr_en         => wr_en,
        din           => din,
        full          => full,
        almost_full   => almost_full,
        prog_full     => prog_full,
        overflow      => overflow,
        wr_ack        => wr_ack,
        wr_rst_busy   => wr_rst_busy,
        wr_data_count => wr_data_count,
        
        rd_clk        => rd_clk,
        rd_en         => rd_en,
        dout          => dout,
        empty         => empty,
        almost_empty  => almost_empty,
        prog_empty    => prog_empty,
        underflow     => underflow,
        data_valid    => data_valid,
        rd_rst_busy   => rd_rst_busy,
        rd_data_count => rd_data_count,
        
        injectsbiterr => injectsbiterr,
        injectdbiterr => injectdbiterr,
        sbiterr       => sbiterr,
        dbiterr       => dbiterr
    );

end architecture rtl;