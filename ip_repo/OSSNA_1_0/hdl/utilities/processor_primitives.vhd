library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.crossbar_utils.all;
use work.processor_utils.all;

package processor_primitives is

component NMC is
    Port ( 
         NMC_CLK                     : IN  std_logic;
         NMC_STATE_RST               : IN  std_logic;
         FMAC_EXTERN_RST             : IN  std_logic;
         NMC_HARD_RST                : IN  std_logic;
         NMC_COLD_START              : IN  std_logic;
         PARTIAL_CURRENT_RDY         : IN  std_logic;
         CURRENT_SWITCH_CHANNEL      : IN  std_logic;
         CURRENT_RESET_CHANNEL       : IN  std_logic;
         CURRENT_CHANNEL_SWITCHED    : OUT std_logic;
         CURRENT_RESOURCES_RELEASED  : OUT std_logic;
         NMC_XNEVER_REGION_BASEADDR  : IN  std_logic_vector(9 downto 0);
         NMC_XNEVER_REGION_HIGHADDR  : IN  std_logic_vector(9 downto 0);
         NMODEL_LAST_SPIKE_TIME      : IN  std_logic_vector(7 downto 0);
         NMODEL_SYN_QFACTOR          : IN  std_logic_vector(15 downto 0);
         NMODEL_PF_LOW_ADDR          : IN  std_logic_vector(9 downto 0);
         NMODEL_NPARAM_DATA          : IN  std_logic_vector(15 downto 0);
         NMODEL_NPARAM_ADDR          : IN  std_logic_vector(9 downto 0);
         NMODEL_REFRACTORY_DUR       : IN  std_logic_vector(7 downto 0);
         NMODEL_PROG_MEM_PORTA_EN    : IN  std_logic;
         NMODEL_PROG_MEM_PORTA_WEN   : IN  std_logic;
         NMC_NMODEL_PSUM_IN          : IN  std_logic_vector(15 downto 0);
         REDIST_NMODEL_PORTB_TKOVER  : IN  std_logic;
         REDIST_NMODEL_DADDR         : IN  std_logic_vector(9 downto 0);
         NMC_NMODEL_SPIKE_OUT        : OUT std_logic;
         NMC_NMODEL_SPIKE_VLD        : OUT std_logic;
         R_NNMODEL_NEW_SPIKE_TIME    : OUT std_logic_vector(7 downto 0);
         R_NMODEL_NPARAM_DATAOUT     : OUT std_logic_vector(15 downto 0);
         R_NMODEL_REFRACTORY_DUR     : OUT std_logic_vector(7 downto 0);
         NMC_NMODEL_FINISHED         : OUT std_logic;
         NMC_MATH_ERROR              : OUT std_logic;
         NMC_MEMORY_VIOLATION        : OUT std_logic
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
        NEURAL_MEM_DEPTH  : integer := 2048;    
        SYNAPSE_MEM_DEPTH : integer := 2048;
        ROW               : integer := 16             
        );
    Port(
        BRIDGE_CLK                  : in  std_logic;
        BRIDGE_RST                  : in  std_logic;
        BARRIER_SYNC_IN             : in  std_logic;
        BARRIER_SYNC_OUT            : out std_logic;
        NETWORK_LOW_ADDRESS         : in  std_logic_vector(clogb2(NEURAL_MEM_DEPTH)-1 downto 0);
        GT_START                    : in  std_logic;
        GT_COMPLETED                : out std_logic;
        SKIP_LEARNING_PROCESS       : in  std_logic;
        EVENT_ACCEPTANCE            : out std_logic;
        EVENT_DETECT                : in  std_logic;

        READ_MAIN_SPIKE_BUFFER      : out std_logic;
        READ_CIRCULAR_BUFFER        : out std_logic;
        READ_AUX_BUFFER             : out std_logic;
        WRITE_OUTBUFFER             : out std_logic;
        WRITE_AUXBUFFER             : out std_logic;

        SYNAPTIC_MEM_RDADDR         : out std_logic_vector(clogb2(SYNAPSE_MEM_DEPTH)-1 downto 0);
        SYNAPTIC_MEM_ENABLE         : out std_logic;
        SYNAPTIC_MEM_WRADDR         : out std_logic_vector(clogb2(SYNAPSE_MEM_DEPTH)-1 downto 0);
        SYNAPTIC_MEM_WREN           : out std_logic;

        HALT_HYPERCOLUMN            : out std_logic;
        PRE_SYN_DATA_PULL           : out std_logic;
        DISABLE_COLUMN              : out std_logic;

        NMC_STATE_RST               : out std_logic;
        NMC_FMAC_RST                : out std_logic;
        NMC_COLD_START              : out std_logic;
        SWITCH_CHANNEL              : out std_logic;
        RESET_CHANNEL               : out std_logic;
        NMODEL_LAST_SPIKE_TIME      : out std_logic_vector(7 downto 0);
        NMODEL_SYN_QFACTOR          : out std_logic_vector(15 downto 0);
        NMODEL_PF_LOW_ADDR          : out std_logic_vector(9 downto 0);
        NMODEL_NPARAM_DATA          : out std_logic_vector(15 downto 0);
        NMODEL_NPARAM_ADDR          : out std_logic_vector(9 downto 0);
        NMODEL_REFRACTORY_DUR       : out std_logic_vector(7 downto 0);
        NMODEL_PROG_MEM_PORTA_EN    : out std_logic;
        NMODEL_PROG_MEM_PORTA_WEN   : out std_logic;

        R_NNMODEL_NEW_SPIKE_TIME    : in  std_logic_vector(7 downto 0);
        R_NMODEL_NPARAM_DATAOUT     : in  std_logic_vector(15 downto 0);
        R_NMODEL_REFRACTORY_DUR     : in  std_logic_vector(7 downto 0);
        REDIST_NMODEL_PORTB_TKOVER  : out std_logic;
        REDIST_NMODEL_DADDR         : out std_logic_vector(9 downto 0);
        NMC_NMODEL_FINISHED         : in  std_logic;

        SYNMEM_PORTA_MUX            : out std_logic;
        DISABLE_LENGINE             : out std_logic;
        ACTVATE_LENGINE             : out std_logic;
        LEARN_RST                   : out std_logic;
        SYNAPSE_PRUN                : out std_logic;
        PRUN_THRESH                 : out std_logic_vector(7 downto 0);
        IGNORE_ZEROS                : out std_logic;
        IGNORE_SOFTLIM              : out std_logic;
        LEARNING_RATE               : out std_logic_vector(7 downto 0);
        TABLE_LOW_ADDRESS           : out std_logic_vector(15 downto 0);
        NEURON_WMAX                 : out std_logic_vector(7 downto 0);
        NEURON_WMIN                 : out std_logic_vector(7 downto 0);
        NEURON_SPK_TIME             : out std_logic_vector(7 downto 0);

        addra                       : out std_logic_vector(clogb2(NEURAL_MEM_DEPTH)-1 downto 0);
        wea                         : out std_logic;
        ena                         : out std_logic;
        rsta                        : out std_logic;
        douta                       : in  std_logic_vector(31 downto 0);
        dina                        : out std_logic_vector(31 downto 0)       

        );
end component BRIDGE;

component ULEARN_SINGLE is
    Generic(
            LUT_TYPE           : string := "block" ;
            LUT_DEPTH          : integer := 1024;
            SYNAPSE_MEM_DEPTH  : integer := 2048           
            );
    Port 
    ( 
        ULEARN_RST             : in  std_logic;
        ULEARN_CLK             : in  std_logic;
        -- SYNAPTIC FIFO PORT  
        SYN_DATA_IN            : in  std_logic_vector(15 downto 0);
        SYN_DIN_VLD            : in  std_logic;
        SYNAPSE_START_ADDRESS  : in  std_logic_vector((clogb2(SYNAPSE_MEM_DEPTH)-1) downto 0);  
        SYN_DATA_OUT           : out std_logic_vector(15 downto 0);
        SYN_DOUT_VLD           : out std_logic;
        SYNAPSE_WRITE_ADDRESS  : out std_logic_vector((clogb2(SYNAPSE_MEM_DEPTH)-1) downto 0);  
        -- CONTROL SIGNAL
        SYNAPSE_PRUNING        : in  std_logic;
        PRUN_THRESHOLD         : in  std_logic_vector(7 downto 0);
        IGNORE_ZERO_SYNAPSES   : in  std_logic;  -- EXPERIMENTAL, CAREFUL WITH THIS.
        IGNORE_SOFTLIMITS      : in  std_logic;  -- EXPERIMENTAL, CAREFUL WITH THIS.
        LEARNING_RATE          : in  std_logic_vector(7 downto 0);
        LUT_LOW_ADDRESS        : in  std_logic_vector((clogb2(LUT_DEPTH)-1) downto 0);
        -- AXI4 LITE INTERFACE PORTS
        ULEARN_LUT_DIN         : in  std_logic_vector(7 downto 0);
        ULEARN_LUT_ADDR        : in  std_logic_vector((clogb2(LUT_DEPTH)-1) downto 0);
        ULEARN_LUT_EN          : in  std_logic;
        -- PARAMETER
        NMODEL_WMAX            : in  std_logic_vector(7 downto 0);
        NMODEL_WMIN            : in  std_logic_vector(7 downto 0);
        -- NMC PORT
        NMODEL_SPIKE_TIME      : in  std_logic_vector(7 downto 0)

    );
end component ULEARN_SINGLE;



component CROSSBAR_FABRIC is
    Generic(
            ROW                : integer := 32   ;
            COLUMN             : integer := 32    ;
            SYNAPSE_MEM_DEPTH  : integer := 4096

            );
    Port (
            CB_CLK                          : in  std_logic;
            CB_VECTOR_RST                   : in  std_logic_vector(0 to COLUMN-1);
            COLUMN_DISABLE_VECTOR           : in  std_logic_vector(0 to COLUMN-1);
            SPIKE_IN                        : in  std_logic_vector(ROW-1 downto 0);
            SPIKE_VLD                       : in  std_logic;
            SPIKE_OUT                       : out std_logic_vector(ROW-1 downto 0);
            SPIKE_OUT_VLD                   : out std_logic;
            COLUMN_PRE_SYNAPTIC_DIN         : in  SYNAPTIC_DATA(0 to COLUMN-1);
            COLUMN_SYNAPSE_START_ADDRESS    : in  SYNAPSE_ADDRESS(0 to COLUMN-1);
            PRE_SYN_DATA_PULL               : in  std_logic_vector(0 to COLUMN-1);
            COLN_SYN_SUM_OUT                : out SYNAPTIC_SUM(0 to COLUMN-1);
            COLN_VECTOR_SYN_SUM_VALID       : out std_logic_vector(0 to COLUMN-1);
            COLUMN_POST_SYNAPTIC_DOUT       : out SYNAPTIC_DATA(0 to COLUMN-1);
            COLUMN_SYNAPSE_WR_ADDRESS       : out SYNAPSE_ADDRESS(0 to COLUMN-1);
            COLUMN_POST_SYNAPTIC_WREN       : out std_logic_vector(0 to COLUMN-1)
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