library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.processor_utils.all;

entity DATA_MUX is
    Generic (
        MAX_TARGET_FIFO_DWIDTH  : integer := 32;
        MAX_TARGET_BRAM_DWIDTH  : integer := 32;
        MAX_TARGET_BRAM_AWIDTH  : integer := 13;
        LENGINE_LUT_AWIDTH      : integer := 12;
        CROSSBAR_ROW_WIDTH      : integer := 16;
        CROSSBAR_COL_WIDTH      : integer := 16;
        SYNAPTIC_MEMORY_AWIDTH  : integer := 16;
        PARAMETER_MEMORY_AWIDTH : integer := 16
    );
    Port 
        ( 
        SELECT_SLAVE                : in   std_logic_vector(31 downto 0);
        -- DMA BRAM Port
        BRAM_ADDR                   : in   std_logic_vector(MAX_TARGET_BRAM_AWIDTH-1 downto 0);
        BRAM_DIN                    : in   std_logic_vector(MAX_TARGET_BRAM_DWIDTH-1 downto 0); 
        BRAM_WE                     : in   std_logic;
        BRAM_DOUT                   : out  std_logic_vector(MAX_TARGET_BRAM_DWIDTH-1 downto 0);
        -- DMA FIFO Port
        FIFO_WREN                   : in   std_logic;
        FIFO_DIN                    : in   std_logic_vector(MAX_TARGET_FIFO_DWIDTH-1 downto 0);
        FIFO_RDEN                   : in   std_logic;
        FIFO_DOUT                   : out  std_logic_vector(MAX_TARGET_FIFO_DWIDTH-1 downto 0);
        FIFO_FULL                   : out  std_logic;
        FIFO_EMPTY                  : out  std_logic;
        -- SYNAPSE MEMORY INTERFACE SELECTION
        SYNAPTIC_MEM_DIN            : out  SYNAPTICMEMDATA(0 to CROSSBAR_COL_WIDTH-1);
        SYNAPTIC_MEM_DADDR          : out  SYNAPTICMEMADDR(0 to CROSSBAR_COL_WIDTH-1);
        SYNAPTIC_MEM_EN             : out  std_logic_vector(0 to CROSSBAR_COL_WIDTH-1);
        SYNAPTIC_MEM_WREN           : out  std_logic_vector(0 to CROSSBAR_COL_WIDTH-1);
        SYNAPTIC_MEM_DOUT           : in   SYNAPTICMEMDATA(0 to CROSSBAR_COL_WIDTH-1);
        -- NMC PROGRAM MEMORY INTERFACE TIED TO ALL NMC UNITS
        NMC_NPARAM_DATA             : out  STD_LOGIC_VECTOR(15 DOWNTO 0);
        NMC_NPARAM_ADDR             : out  STD_LOGIC_VECTOR(9  DOWNTO 0);
        NMC_PROG_MEM_PORTA_EN       : out  std_logic;
        NMC_PROG_MEM_PORTA_WEN      : out  std_logic;
         -- ULEARN LUT TIED TO ALL LEARNING ENGINES
        LEARN_LUT_DIN               : out  std_logic_vector(7 downto 0);
        LEARN_LUT_ADDR              : out  std_logic_vector(LENGINE_LUT_AWIDTH-1 downto 0);
        LEARN_LUT_EN                : out  std_logic;
        -- PARAMETER MEMORY INTERFACE SELECTION
        PARAM_MEM_DIN               : out  PARAMMEMDATA(0 to CROSSBAR_COL_WIDTH-1);
        PARAM_MEM_DADDR             : out  PARAMMEMADDR(0 to CROSSBAR_COL_WIDTH-1);
        PARAM_MEM_EN                : out  std_logic_vector(0 to CROSSBAR_COL_WIDTH-1); 
        PARAM_MEM_WREN              : out  std_logic_vector(0 to CROSSBAR_COL_WIDTH-1); 
        PARAM_MEM_DOUT              : in   PARAMMEMDATA(0 to CROSSBAR_COL_WIDTH-1);
        -- D2S INPUT
        D2S_DATA_IN                 : out  std_logic_vector(31 downto 0);
        D2S_DATA_IN_VLD             : out  std_logic;
        -- INPUT SPIKE BUFFER INPUT
        INPUT_SPIKE_BUFFER_DIN      : out  std_logic_vector(CROSSBAR_ROW_WIDTH-1 downto 0);
        INPUT_SPIKE_BUFFER_WREN     : out  std_logic;
        INPUT_SPIKE_BUFFER_FULL     : in   std_logic;
        -- AUX SPIKE BUFFER INPUT
        AUX_SPIKE_BUFFER_DIN        : out  std_logic_vector(CROSSBAR_ROW_WIDTH-1 downto 0);
        AUX_SPIKE_BUFFER_WREN       : out  std_logic;
        AUX_SPIKE_BUFFER_FULL       : in   std_logic;
        -- OUT SPIKE BUFFER OUTPUT
        OUT_SPIKE_BUFFER_DOUT       : in   std_logic_vector(CROSSBAR_ROW_WIDTH-1 downto 0);
        OUT_SPIKE_BUFFER_RDEN       : out  std_logic;
        OUT_SPIKE_BUFFER_EMPTY      : in   std_logic -- Noktalı virgül kaldırıldı
        );
end DATA_MUX;

architecture cherry_blossom of DATA_MUX is

    signal BRAM_DOUT_INTERNAL : std_logic_vector(MAX_TARGET_BRAM_DWIDTH-1 downto 0);

begin

    -- ==========================================
    -- 1. Data to Spike Converter (SELECT_SLAVE = 0)
    -- ==========================================
    D2S_DATA_IN_VLD <= FIFO_WREN             when SELECT_SLAVE = x"00000000" else '0';
    D2S_DATA_IN     <= FIFO_DIN(31 downto 0) when SELECT_SLAVE = x"00000000" else (others => '0');

    -- ==========================================
    -- 2. Input Spike Buffer (SELECT_SLAVE = 1)
    -- ==========================================
    INPUT_SPIKE_BUFFER_WREN <= FIFO_WREN when SELECT_SLAVE = x"00000001" else '0';
    INPUT_SPIKE_BUFFER_DIN  <= FIFO_DIN(CROSSBAR_ROW_WIDTH-1 downto 0) when SELECT_SLAVE = x"00000001" else (others => '0');

    -- ==========================================
    -- 3. Aux Spike Buffer (SELECT_SLAVE = 2)
    -- ==========================================
    AUX_SPIKE_BUFFER_WREN <= FIFO_WREN when SELECT_SLAVE = x"00000002" else '0';
    AUX_SPIKE_BUFFER_DIN  <= FIFO_DIN(CROSSBAR_ROW_WIDTH-1 downto 0) when SELECT_SLAVE = x"00000002" else (others => '0');

    FIFO_FULL <= INPUT_SPIKE_BUFFER_FULL when SELECT_SLAVE = x"00000001" else 
                 AUX_SPIKE_BUFFER_FULL   when SELECT_SLAVE = x"00000002" else '0';

    -- ==========================================
    -- 4. Out Spike Buffer (SELECT_SLAVE = 3)
    -- ==========================================
    OUT_SPIKE_BUFFER_RDEN <= FIFO_RDEN when SELECT_SLAVE = x"00000003" else '0';
    FIFO_EMPTY            <= OUT_SPIKE_BUFFER_EMPTY when SELECT_SLAVE = x"00000003" else '1'; 

    process(SELECT_SLAVE, OUT_SPIKE_BUFFER_DOUT)
    begin
        FIFO_DOUT <= (others => '0'); 
        if SELECT_SLAVE = x"00000003" then
            FIFO_DOUT(CROSSBAR_ROW_WIDTH-1 downto 0) <= OUT_SPIKE_BUFFER_DOUT;
        end if;
    end process;

    -- ==========================================
    -- 5. NMC (SELECT_SLAVE = 4)
    -- ==========================================
    NMC_NPARAM_DATA         <= BRAM_DIN(15 downto 0) when SELECT_SLAVE = x"00000004" else (others=>'0');
    NMC_NPARAM_ADDR         <= BRAM_ADDR(9 downto 0) when SELECT_SLAVE = x"00000004" else (others=>'0');
    NMC_PROG_MEM_PORTA_EN   <= '1'                   when SELECT_SLAVE = x"00000004" else '0';
    NMC_PROG_MEM_PORTA_WEN  <= BRAM_WE               when SELECT_SLAVE = x"00000004" else '0';

    -- ==========================================
    -- 6. LEARN LUT (SELECT_SLAVE = 5)
    -- ==========================================
    LEARN_LUT_DIN  <= BRAM_DIN(7 downto 0) when SELECT_SLAVE = x"00000005" else (others=>'0');
    LEARN_LUT_ADDR <= BRAM_ADDR(LENGINE_LUT_AWIDTH-1 downto 0) when SELECT_SLAVE = x"00000005" else (others=>'0');
    LEARN_LUT_EN   <= '1'                  when SELECT_SLAVE = x"00000005" else '0';

    BRAM_DOUT <= BRAM_DOUT_INTERNAL;

    -- =========================================================================
    -- 7. SYNAPTIC MEMORY & PARAMETER MEMORY DYNAMIC ROUTING PROCESS
    -- =========================================================================
    process(SELECT_SLAVE, BRAM_DIN, BRAM_ADDR, BRAM_WE, SYNAPTIC_MEM_DOUT, PARAM_MEM_DOUT)

        variable slave_idx : integer;

    begin

        SYNAPTIC_MEM_DIN   <= (others => (others => '0'));
        SYNAPTIC_MEM_DADDR <= (others => (others => '0'));
        SYNAPTIC_MEM_EN    <= (others => '0');
        SYNAPTIC_MEM_WREN  <= (others => '0');

        PARAM_MEM_DIN      <= (others => (others => '0'));
        PARAM_MEM_DADDR    <= (others => (others => '0'));
        PARAM_MEM_EN       <= (others => '0');
        PARAM_MEM_WREN     <= (others => '0');
        
        BRAM_DOUT_INTERNAL <= (others => '0');

        slave_idx := to_integer(unsigned(SELECT_SLAVE));

        if (slave_idx >= 6) and (slave_idx < 6 + CROSSBAR_COL_WIDTH) then

            for i in 0 to CROSSBAR_COL_WIDTH - 1 loop

                if (slave_idx = 6 + i) then

                    SYNAPTIC_MEM_DIN(i) <= BRAM_DIN(15 downto 0);
                    
                    SYNAPTIC_MEM_DADDR(i)(MAX_TARGET_BRAM_AWIDTH-1 downto 0) <= BRAM_ADDR;
                    
                    SYNAPTIC_MEM_EN(i)   <= '1';
                    SYNAPTIC_MEM_WREN(i) <= BRAM_WE;
                    
                    BRAM_DOUT_INTERNAL(15 downto 0) <= SYNAPTIC_MEM_DOUT(i);

                end if;

            end loop;

        elsif (slave_idx >= 6 + CROSSBAR_COL_WIDTH) and (slave_idx < 6 + 2*CROSSBAR_COL_WIDTH) then

            for i in 0 to CROSSBAR_COL_WIDTH - 1 loop

                if (slave_idx = 6 + CROSSBAR_COL_WIDTH + i) then

                    PARAM_MEM_DIN(i)(MAX_TARGET_BRAM_DWIDTH-1 downto 0) <= BRAM_DIN;
                    
                    PARAM_MEM_DADDR(i)(MAX_TARGET_BRAM_AWIDTH-1 downto 0) <= BRAM_ADDR;
                    
                    PARAM_MEM_EN(i)   <= '1';
                    PARAM_MEM_WREN(i) <= BRAM_WE;
                    
                    BRAM_DOUT_INTERNAL <= PARAM_MEM_DOUT(i)(MAX_TARGET_BRAM_DWIDTH-1 downto 0);

                end if;

            end loop;

        end if;

    end process;

end cherry_blossom;