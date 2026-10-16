library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.crossbar_utils.all;
use work.processor_utils.all;

package processor_primitives is

component NMC is
    Port ( 
            NMC_CLK                    : in  std_logic; 
            NMC_STATE_RST              : in  std_logic; 
            FMAC_EXTERNAL_RST          : in  std_logic;
            NMC_HARD_RST               : in  std_logic; 
            NMC_LAUNCH                 : in  std_logic;
            PARTIAL_CURRENT_IN         : in  std_logic_vector(15 downto 0); 
            PARTIAL_CURRENT_VLD        : in  std_logic;
            CURRENT_SWITCH_CHANNEL     : in  std_logic; 
            CURRENT_RESET_CHANNEL      : in  std_logic; 
            CURRENT_CHANNEL_SWITCHED   : out std_logic; 
            CURRENT_RESOURCES_RELEASED : out std_logic;
            NMC_XNEVER_REGION_BASEADDR : in  std_logic_vector(9 downto 0);
            NMC_XNEVER_REGION_HIGHADDR : in  std_logic_vector(9 downto 0);
            NMODEL_LAST_SPIKE_TIME     : in  STD_LOGIC_VECTOR(7  DOWNTO 0); 
            NMODEL_SYN_QFACTOR         : in  STD_LOGIC_VECTOR(15 DOWNTO 0); 
            NMODEL_PF_LOW_ADDR         : in  STD_LOGIC_VECTOR(9  DOWNTO 0); 
            NMODEL_REFRACTORY_DUR      : in  std_logic_vector(7  downto 0);
            NMODEL_NEW_SPIKE_TIME      : out std_logic_vector(7  downto 0);
            NMODEL_NEW_REFRACTORY_DUR  : OUT std_logic_vector(7  downto 0);
            NMODEL_SPIKE_OUT           : out std_logic; 
            NMODEL_SPIKE_OUT_VLD       : out std_logic; 
            NMC_MEM_PORTA_EN           : in  STD_LOGIC;
            NMC_MEM_PORTA_WEN          : in  STD_LOGIC;
            NMC_MEM_PORTA_DIN          : in  STD_LOGIC_VECTOR(15 DOWNTO 0);
            NMC_MEM_PORTA_ADDR         : in  STD_LOGIC_VECTOR(9  DOWNTO 0);
            NMC_MEM_PORTB_EXT_ACCESS   : in  std_logic;
            NMC_MEM_PORTB_ADDR         : in  std_logic_vector(9 downto 0);
            NMC_MEM_PORTB_DOUT         : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
            NMODEL_FINISHED            : out std_logic;
            NMC_MATH_ERROR             : out std_logic;
            NMC_MEMORY_VIOLATION       : out std_logic
    );
end component NMC;

component AUTO_RAM_INSTANCE is
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

end component AUTO_RAM_INSTANCE;

component BRIDGE is
    Generic (
        NEURAL_MEM_DEPTH  : integer := 1024;
        SYNAPSE_MEM_DEPTH : integer := 8192;
        ROW               : integer := 16
    );
    Port (
        BRIDGE_CLK                   : in  std_logic;
        BRIDGE_RST                   : in  std_logic;
        BARRIER_SYNC_IN              : in  std_logic;
        BARRIER_SYNC_OUT             : out std_logic;
        NETWORK_LOW_ADDRESS          : in  std_logic_vector(clogb2(NEURAL_MEM_DEPTH)-1 downto 0);
        GT_START                     : in  std_logic;
        GT_COMPLETED                 : out std_logic;
        SKIP_LEARNING_PROCESS        : in  std_logic;
        EVENT_ACCEPTANCE             : out std_logic;
        EVENT_DETECT                 : in  std_logic;
 
        READ_MAIN_SPIKE_BUFFER       : out std_logic;
        READ_CIRCULAR_BUFFER         : out std_logic;
        READ_AUX_BUFFER              : out std_logic;
        WRITE_OUTBUFFER              : out std_logic;
        WRITE_AUXBUFFER              : out std_logic;
 
        SYNAPTIC_MEM_RDADDR          : out std_logic_vector(clogb2(SYNAPSE_MEM_DEPTH)-1 downto 0);
        SYNAPTIC_MEM_ENABLE          : out std_logic;
        SYNAPTIC_MEM_WRADDR          : out std_logic_vector(clogb2(SYNAPSE_MEM_DEPTH)-1 downto 0);
        SYNAPTIC_MEM_WREN            : out std_logic;
 
        SYNAPTIC_DATA_LOCK           : out std_logic;
        DISABLE_COLUMN               : out std_logic;
        TRACE_UPDATING               : in  std_logic;
 
        NMC_STATE_RST                : out std_logic;
        NMC_FMAC_RST                 : out std_logic;
        NMC_LAUNCH                   : out std_logic;
        CURRENT_SWITCH_CHANNEL       : out std_logic;
        CURRENT_RESET_CHANNEL        : out std_logic;
        CURRENT_CHANNEL_SWITCHED     : in  std_logic; 
        CURRENT_RESOURCES_RELEASED   : in  std_logic; 
 
        NMODEL_LAST_SPIKE_TIME       : out std_logic_vector(7 downto 0);
        NMODEL_SYN_QFACTOR           : out std_logic_vector(15 downto 0);
        NMODEL_PF_LOW_ADDR           : out std_logic_vector(9 downto 0);
        NMODEL_REFRACTORY_DUR        : out std_logic_vector(7 downto 0);
        NMODEL_NEW_SPIKE_TIME        : in  std_logic_vector(7 downto 0);
        NMODEL_NEW_REFRACTORY_DUR    : in  std_logic_vector(7 downto 0);

        NMC_MEM_PORTA_EN             : out std_logic;
        NMC_MEM_PORTA_WEN            : out std_logic;
        NMC_MEM_PORTA_DIN            : out std_logic_vector(15 downto 0);
        NMC_MEM_PORTA_ADDR           : out std_logic_vector(9 downto 0);
        NMC_MEM_PORTB_EXT_ACCESS     : out std_logic;
        NMC_MEM_PORTB_ADDR           : out std_logic_vector(9 downto 0);
        NMC_MEM_PORTB_DOUT           : in  std_logic_vector(15 downto 0);

        NMODEL_FINISHED              : in  std_logic;

        SYNAPTIC_MEM_PORTA_MUX       : out std_logic;
        ULEARN_RST                   : out std_logic;
        ULEARN_CFG_WORD              : out std_logic_vector(255 downto 0);
        ULEARN_SYN_DIN_VLD           : out std_logic;                    
        ULEARN_SYNAPSE_START_ADDRESS : out std_logic_vector((clogb2(SYNAPSE_MEM_DEPTH)-1) downto 0);  

        PARAMETER_MEM_ADDRA          : out std_logic_vector(clogb2(NEURAL_MEM_DEPTH)-1 downto 0);
        PARAMETER_MEM_WEA            : out std_logic;
        PARAMETER_MEM_ENA            : out std_logic;
        PARAMETER_MEM_RSTA           : out std_logic;
        PARAMETER_MEM_DOUTA          : in  std_logic_vector(31 downto 0);
        PARAMETER_MEM_DINA           : out std_logic_vector(31 downto 0)
    );
end component BRIDGE;

component ULEARN is
    Generic(
            LUT_DEPTH          : integer := 1024;
            SYNAPSE_MEM_DEPTH  : integer := 2048           
            );
    Port 
    ( 
        CLK                    : in  std_logic;
        RST                    : in  std_logic;
        CFG_WORD               : in  std_logic_vector(255 downto 0);
        NMODEL_SPIKE_TIME      : in  std_logic_vector(7 downto 0);  
        SYN_DATA_IN            : in  std_logic_vector(15 downto 0); 
        SYN_DIN_VLD            : in  std_logic;                    
        SYNAPSE_START_ADDRESS  : in  std_logic_vector((clogb2(SYNAPSE_MEM_DEPTH)-1) downto 0);  
        SYN_DATA_OUT           : out std_logic_vector(15 downto 0);
        SYN_DOUT_VLD           : out std_logic;                     
        SYNAPSE_WRITE_ADDRESS  : out std_logic_vector((clogb2(SYNAPSE_MEM_DEPTH)-1) downto 0);
        LUT_ADDR               : out std_logic_vector((clogb2(LUT_DEPTH)-1) downto 0);
        LUT_DOUT               : in  std_logic_vector(7 downto 0)  
    );
end component ULEARN;

component CROSSBAR_FABRIC is
    Generic(
            ROW                : integer := 32   ;
            COLUMN             : integer := 32    ;
            SYNAPSE_MEM_DEPTH  : integer := 4096

            );
    Port (
            CB_CLK                   : in  std_logic;
            CB_VECTOR_RST            : in  std_logic_vector(0 to COLUMN-1);
            DISABLE_COLUMN           : in  std_logic_vector(0 to COLUMN-1);
            SPIKE_IN                 : in  std_logic_vector(ROW-1 downto 0);
            SPIKE_VLD                : in  std_logic;
            SPIKE_OUT                : out std_logic_vector(ROW-1 downto 0);
            SPIKE_OUT_VLD            : out std_logic;
            TRACE_UPDATING           : out std_logic;
            SYNAPTIC_DATA_IN         : in  SYNAPTIC_DATA(0 to COLUMN-1);
            SYNAPTIC_DATA_START_ADDR : in  SYNAPSE_ADDRESS(0 to COLUMN-1);
            SYNAPTIC_DATA_LOCK       : in  std_logic_vector(0 to COLUMN-1);
            PARTIAL_CURRENT_OUT      : out SYNAPTIC_SUM(0 to COLUMN-1);
            PARTIAL_CURRENT_OUT_VLD  : out std_logic_vector(0 to COLUMN-1);
            SYNAPTIC_DATA_OUT        : out SYNAPTIC_DATA(0 to COLUMN-1);
            SYNAPTIC_DATA_WRITE_ADDR : out SYNAPSE_ADDRESS(0 to COLUMN-1);
            SYNAPTIC_DATA_WRITE_EN   : out std_logic_vector(0 to COLUMN-1)
        );
end component CROSSBAR_FABRIC;

component or_reduce is
    generic (
        N : integer := 8  
    );
    port (
        A : in  STD_LOGIC_VECTOR(N-1 downto 0);
        Y : out STD_LOGIC 
    );
end component or_reduce;

component and_reduce is
    generic (
        N : integer := 8  
    );
    port (
        A : in  STD_LOGIC_VECTOR(N-1 downto 0);
        Y : out STD_LOGIC 
    );
end component and_reduce;

component Synapse_Dout_Mux is
	Generic (
		CROSSBAR_COL_WIDTH  : integer := 32
		);
    Port ( 
        SYNAPSE_MEM_SELECT   : in  std_logic_vector(clogb2(CROSSBAR_COL_WIDTH)-1 downto 0);
        SYNAPSE_MEM_DOUT     : in  SYNAPTICMEMDATA(0 to CROSSBAR_COL_WIDTH-1);
        MUXDOUT              : out std_logic_vector(15 downto 0)
        );
end component Synapse_Dout_Mux;

component Param_Dout_Mux is
	Generic (
		CROSSBAR_COL_WIDTH  : integer := 32
		);
    Port ( 
        PARAM_MEM_SELECT   : in  std_logic_vector(clogb2(CROSSBAR_COL_WIDTH)-1 downto 0);
        PARAM_MEM_DOUT     : in  PARAMMEMDATA(0 to CROSSBAR_COL_WIDTH-1);
        MUXDOUT            : out std_logic_vector(31 downto 0)
        );
end component Param_Dout_Mux;

component OUTFIFO is
    generic(
        RAMTYPE : string := "block";
        DEPTH : integer := 1024; 
        WIDTH : integer := 32   
    );
    port(
        wr_clk       : in  std_logic;
        rd_clk       : in  std_logic;
        rst       : in  std_logic;
        wr_en     : in  std_logic;
        rd_en     : in  std_logic;
        data_in   : in  std_logic_vector(WIDTH-1 downto 0);
        data_out  : out std_logic_vector(WIDTH-1 downto 0);
        full      : out std_logic;
        last      : out std_logic;
        empty     : out std_logic
    );
end component OUTFIFO;

end processor_primitives;