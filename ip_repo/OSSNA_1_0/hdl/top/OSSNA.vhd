library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.crossbar_utils.all;
use work.processor_primitives.all;
use work.processor_utils.all;
Library xpm;
use xpm.vcomponents.all;

entity OSSNA is
	generic (
		-- Users to add parameters here
        CROSSBAR_MATRIX_DIMENSIONS : integer := 16;
        SYNAPSE_MEM_DEPTH  : integer := 8192;
        NEURAL_MEM_DEPTH   : integer := 2048;
        LEARNING_ENGINE_LUT_DEPTH : integer := 2048;
        SPIKE_GENERATOR_BUFFER_DEPTH  : integer := 4096;
		-- User parameters ends
		-- Do not modify the parameters beyond this line


		-- Parameters of Axi Slave Bus Interface AXIL_CONTROLS
		C_AXIL_CONTROLS_DATA_WIDTH	: integer	:= 32;
		C_AXIL_CONTROLS_ADDR_WIDTH	: integer	:= 7;

		-- Parameters of Axi Master Bus Interface AXIM_DATA
		C_AXIM_DATA_TARGET_SLAVE_BASE_ADDR	: std_logic_vector	:= x"40000000";
		C_AXIM_DATA_BURST_LEN	: integer	:= 16;
		C_AXIM_DATA_ID_WIDTH	: integer	:= 1;
		C_AXIM_DATA_ADDR_WIDTH	: integer	:= 32;
		C_AXIM_DATA_DATA_WIDTH	: integer	:= 32;
		C_AXIM_DATA_AWUSER_WIDTH	: integer	:= 0;
		C_AXIM_DATA_ARUSER_WIDTH	: integer	:= 0;
		C_AXIM_DATA_WUSER_WIDTH	: integer	:= 0;
		C_AXIM_DATA_RUSER_WIDTH	: integer	:= 0;
		C_AXIM_DATA_BUSER_WIDTH	: integer	:= 0
	);
	port (
		-- Users to add ports here

		-- User ports ends
		-- Do not modify the ports beyond this line


		-- Ports of Axi Slave Bus Interface AXIL_CONTROLS
		axil_controls_aclk	: in std_logic;
		axil_controls_aresetn	: in std_logic;
		axil_controls_awaddr	: in std_logic_vector(C_AXIL_CONTROLS_ADDR_WIDTH-1 downto 0);
		axil_controls_awprot	: in std_logic_vector(2 downto 0);
		axil_controls_awvalid	: in std_logic;
		axil_controls_awready	: out std_logic;
		axil_controls_wdata	: in std_logic_vector(C_AXIL_CONTROLS_DATA_WIDTH-1 downto 0);
		axil_controls_wstrb	: in std_logic_vector((C_AXIL_CONTROLS_DATA_WIDTH/8)-1 downto 0);
		axil_controls_wvalid	: in std_logic;
		axil_controls_wready	: out std_logic;
		axil_controls_bresp	: out std_logic_vector(1 downto 0);
		axil_controls_bvalid	: out std_logic;
		axil_controls_bready	: in std_logic;
		axil_controls_araddr	: in std_logic_vector(C_AXIL_CONTROLS_ADDR_WIDTH-1 downto 0);
		axil_controls_arprot	: in std_logic_vector(2 downto 0);
		axil_controls_arvalid	: in std_logic;
		axil_controls_arready	: out std_logic;
		axil_controls_rdata	: out std_logic_vector(C_AXIL_CONTROLS_DATA_WIDTH-1 downto 0);
		axil_controls_rresp	: out std_logic_vector(1 downto 0);
		axil_controls_rvalid	: out std_logic;
		axil_controls_rready	: in std_logic;

		-- Ports of Axi Master Bus Interface AXIM_DATA
		axim_data_aclk	: in std_logic;
		axim_data_aresetn	: in std_logic;
		axim_data_awid	: out std_logic_vector(C_AXIM_DATA_ID_WIDTH-1 downto 0);
		axim_data_awaddr	: out std_logic_vector(C_AXIM_DATA_ADDR_WIDTH-1 downto 0);
		axim_data_awlen	: out std_logic_vector(7 downto 0);
		axim_data_awsize	: out std_logic_vector(2 downto 0);
		axim_data_awburst	: out std_logic_vector(1 downto 0);
		axim_data_awlock	: out std_logic;
		axim_data_awcache	: out std_logic_vector(3 downto 0);
		axim_data_awprot	: out std_logic_vector(2 downto 0);
		axim_data_awqos	: out std_logic_vector(3 downto 0);
		axim_data_awuser	: out std_logic_vector(C_AXIM_DATA_AWUSER_WIDTH-1 downto 0);
		axim_data_awvalid	: out std_logic;
		axim_data_awready	: in std_logic;
		axim_data_wdata	: out std_logic_vector(C_AXIM_DATA_DATA_WIDTH-1 downto 0);
		axim_data_wstrb	: out std_logic_vector(C_AXIM_DATA_DATA_WIDTH/8-1 downto 0);
		axim_data_wlast	: out std_logic;
		axim_data_wuser	: out std_logic_vector(C_AXIM_DATA_WUSER_WIDTH-1 downto 0);
		axim_data_wvalid	: out std_logic;
		axim_data_wready	: in std_logic;
		axim_data_bid	: in std_logic_vector(C_AXIM_DATA_ID_WIDTH-1 downto 0);
		axim_data_bresp	: in std_logic_vector(1 downto 0);
		axim_data_buser	: in std_logic_vector(C_AXIM_DATA_BUSER_WIDTH-1 downto 0);
		axim_data_bvalid	: in std_logic;
		axim_data_bready	: out std_logic;
		axim_data_arid	: out std_logic_vector(C_AXIM_DATA_ID_WIDTH-1 downto 0);
		axim_data_araddr	: out std_logic_vector(C_AXIM_DATA_ADDR_WIDTH-1 downto 0);
		axim_data_arlen	: out std_logic_vector(7 downto 0);
		axim_data_arsize	: out std_logic_vector(2 downto 0);
		axim_data_arburst	: out std_logic_vector(1 downto 0);
		axim_data_arlock	: out std_logic;
		axim_data_arcache	: out std_logic_vector(3 downto 0);
		axim_data_arprot	: out std_logic_vector(2 downto 0);
		axim_data_arqos	: out std_logic_vector(3 downto 0);
		axim_data_aruser	: out std_logic_vector(C_AXIM_DATA_ARUSER_WIDTH-1 downto 0);
		axim_data_arvalid	: out std_logic;
		axim_data_arready	: in std_logic;
		axim_data_rid	: in std_logic_vector(C_AXIM_DATA_ID_WIDTH-1 downto 0);
		axim_data_rdata	: in std_logic_vector(C_AXIM_DATA_DATA_WIDTH-1 downto 0);
		axim_data_rresp	: in std_logic_vector(1 downto 0);
		axim_data_rlast	: in std_logic;
		axim_data_ruser	: in std_logic_vector(C_AXIM_DATA_RUSER_WIDTH-1 downto 0);
		axim_data_rvalid	: in std_logic;
		axim_data_rready	: out std_logic
	);
end OSSNA;

architecture arch_imp of OSSNA is

	component OSSNA_AXIL_CONTROLS is
		generic (
        CROSSBAR_ROW_WIDTH  : integer := 32;
        CROSSBAR_COL_WIDTH  : integer := 32;
        SYNAPSE_MEM_DEPTH   : integer := 2048;
        NEURAL_MEM_DEPTH    : integer := 1024;
        LEARNING_ENGINE_LUT_DEPTH : integer := 2048;
        SPIKE_GENERATOR_BUFFER_DEPTH : integer := 2048;
		C_S_AXI_DATA_WIDTH	: integer	:= 32;
		C_S_AXI_ADDR_WIDTH	: integer	:= 7
		);
		port (
        DMA_START_READ                 : out  std_logic;  
        DMA_START_WRITE                : out  std_logic;  
        DMA_RESET_SOFT                 : out  std_logic;  
        TARGET_SELECT            : out std_logic;                    
        FIFO_TYPE                : out std_logic;                   
        BYTE_PER_WORD            : out std_logic_vector(31 downto 0);  
        TOTAL_BYTES              : out std_logic_vector(31 downto 0);
        TOTAL_WORDS              : out std_logic_vector(31 downto 0); 
        BRAM_READ_DELAY          : out std_logic_vector(31 downto 0); 
        BRAM_BASEADDR            : out std_logic_vector(31 downto 0);
        DDR_BASEADDR             : out std_logic_vector(31 downto 0);
        TARGET_READ_DONE         : in  std_logic;
        TARGET_WRITE_DONE        : in  std_logic;
        TARGET_READ_ERROR        : in  std_logic;
        TARGET_WRITE_ERROR       : in  std_logic;
		SELECT_SLAVE             : out std_logic_vector(31 downto 0);
        INPUT_SPIKE_MUX          : out std_logic;
        D2S_RESET                : out std_logic;
        CONVMODE                 : out std_logic_vector(1  downto 0);
        TIME_WIND                : out std_logic_vector(31 downto 0);
        SEED                     : out std_logic_vector(31 downto 0);
        DATA_COUNT               : out std_logic_vector(31 downto 0);
        CONV_DONE                : in  std_logic;
        SP_RESET                 : out std_logic;
        NETWORK_START_ADDRESS    : out std_logic_vector(31 downto 0);
        TIMESTEP_STARTED         : out std_logic;
        TIMESTEP_COMPLETED       : in  std_logic;
        DISABLE_LEARNING_ENGINES : out std_logic;
        SYNAPSE_ROUTE            : out std_logic; 
        NMC_XNEVER_BASE          : out std_logic_vector(9 downto 0);
        NMC_XNEVER_HIGH          : out std_logic_vector(9 downto 0);
        NMC_PMODE_SWITCH         : out std_logic;  
        NMC_MATH_ERROR_VEC       : in  std_logic; 
        NMC_MEM_VIOLATION_VEC    : in  std_logic;		
        FLUSH_MAIN_BUFFER        : out std_logic;
		FLUSH_AUX_BUFFER         : out std_logic;
		FLUSH_CIRCULAR_BUFFER    : out std_logic;
		FLUSH_OUT_BUFFER      	 : out std_logic;

        S_AXI_ACLK	: in std_logic;
		S_AXI_ARESETN	: in std_logic;
		S_AXI_AWADDR	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		S_AXI_AWPROT	: in std_logic_vector(2 downto 0);
		S_AXI_AWVALID	: in std_logic;
		S_AXI_AWREADY	: out std_logic;
		S_AXI_WDATA	: in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		S_AXI_WSTRB	: in std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
		S_AXI_WVALID	: in std_logic;
		S_AXI_WREADY	: out std_logic;
		S_AXI_BRESP	: out std_logic_vector(1 downto 0);
		S_AXI_BVALID	: out std_logic;
		S_AXI_BREADY	: in std_logic;
		S_AXI_ARADDR	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		S_AXI_ARPROT	: in std_logic_vector(2 downto 0);
		S_AXI_ARVALID	: in std_logic;
		S_AXI_ARREADY	: out std_logic;
		S_AXI_RDATA	: out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		S_AXI_RRESP	: out std_logic_vector(1 downto 0);
		S_AXI_RVALID	: out std_logic;
		S_AXI_RREADY	: in std_logic
		);
	end component OSSNA_AXIL_CONTROLS;

	component OSSNA_AXIM_DATA is
		generic (
		outstanding_limit           : integer  := 16 ;
        MAX_TARGET_FIFO_DWIDTH      : integer  := 16;
        MAX_TARGET_BRAM_DWIDTH      : integer  := 32;
        MAX_TARGET_BRAM_AWIDTH      : integer  := 12;

		C_M_TARGET_SLAVE_BASE_ADDR	: std_logic_vector	:= x"40000000";
		C_M_AXI_BURST_LEN	        : integer	:= 16;
		C_M_AXI_ID_WIDTH	        : integer	:= 1;
		C_M_AXI_ADDR_WIDTH	        : integer	:= 32;
		C_M_AXI_DATA_WIDTH	        : integer	:= 32;
		C_M_AXI_AWUSER_WIDTH	    : integer	:= 0;
		C_M_AXI_ARUSER_WIDTH	    : integer	:= 0;
		C_M_AXI_WUSER_WIDTH	        : integer	:= 0;
		C_M_AXI_RUSER_WIDTH	        : integer	:= 0;
		C_M_AXI_BUSER_WIDTH	        : integer	:= 0
	);
	port (
        DMA_START_READ                 : in  std_logic;  
        DMA_START_WRITE                : in  std_logic;  
        DMA_RESET_SOFT                 : in  std_logic;  
        TARGET_SELECT                  : in  std_logic;                     -- 0: BRAM     , 1: FIFO
        FIFO_TYPE                      : in  std_logic;                     -- 0: Standart , 1: FWFT
        BYTE_PER_WORD                  : in  std_logic_vector(31 downto 0);  
        TOTAL_BYTES                    : in  std_logic_vector(31 downto 0);
        TOTAL_WORDS                    : in  std_logic_vector(31 downto 0); 

        BRAM_READ_DELAY                : in  std_logic_vector(31 downto 0); 

        BRAM_BASEADDR                  : in  std_logic_vector(31 downto 0);
        DDR_BASEADDR                   : in  std_logic_vector(31 downto 0);

        TARGET_READ_DONE               : out std_logic;
        TARGET_WRITE_DONE              : out std_logic;
        TARGET_READ_ERROR              : out std_logic;
        TARGET_WRITE_ERROR             : out std_logic;

        BRAM_ADDR                      : out std_logic_vector(MAX_TARGET_BRAM_AWIDTH-1 downto 0);
        BRAM_DIN                       : out std_logic_vector(MAX_TARGET_BRAM_DWIDTH-1 downto 0); 
        BRAM_WE                        : out std_logic;
        BRAM_DOUT                      : in  std_logic_vector(MAX_TARGET_BRAM_DWIDTH-1 downto 0);
            
        FIFO_WREN                      : out std_logic;
        FIFO_DIN                       : out std_logic_vector(MAX_TARGET_FIFO_DWIDTH-1 downto 0);
        FIFO_RDEN                      : out std_logic;
        FIFO_DOUT                      : in  std_logic_vector(MAX_TARGET_FIFO_DWIDTH-1 downto 0);

        FIFO_EMPTY                     : in  std_logic; 
        FIFO_FULL                      : in  std_logic;

		m_axi_aclk	    : in  std_logic;
		m_axi_aresetn   : in  std_logic;
		m_axi_awid	    : out std_logic_vector(c_m_axi_id_width-1 downto 0);
		m_axi_awaddr	: out std_logic_vector(c_m_axi_addr_width-1 downto 0);
		m_axi_awlen	    : out std_logic_vector(7 downto 0);
		m_axi_awsize	: out std_logic_vector(2 downto 0);
		m_axi_awburst	: out std_logic_vector(1 downto 0);
		m_axi_awlock	: out std_logic;
		m_axi_awcache	: out std_logic_vector(3 downto 0);
		m_axi_awprot	: out std_logic_vector(2 downto 0);
		m_axi_awqos	    : out std_logic_vector(3 downto 0);
		m_axi_awuser	: out std_logic_vector(c_m_axi_awuser_width-1 downto 0);
		m_axi_awvalid	: out std_logic;
		m_axi_awready	: in  std_logic;
		m_axi_wdata	    : out std_logic_vector(c_m_axi_data_width-1 downto 0);
		m_axi_wstrb	    : out std_logic_vector(c_m_axi_data_width/8-1 downto 0);
		m_axi_wlast	    : out std_logic;
		m_axi_wuser	    : out std_logic_vector(c_m_axi_wuser_width-1 downto 0);
		m_axi_wvalid	: out std_logic;
		m_axi_wready	: in  std_logic;
		m_axi_bid	    : in  std_logic_vector(c_m_axi_id_width-1 downto 0);
		m_axi_bresp	    : in  std_logic_vector(1 downto 0);
		m_axi_buser	    : in  std_logic_vector(c_m_axi_buser_width-1 downto 0);
		m_axi_bvalid	: in  std_logic;
		m_axi_bready	: out std_logic;
		m_axi_arid	    : out std_logic_vector(c_m_axi_id_width-1 downto 0);
		m_axi_araddr	: out std_logic_vector(c_m_axi_addr_width-1 downto 0);
		m_axi_arlen	    : out std_logic_vector(7 downto 0);
		m_axi_arsize	: out std_logic_vector(2 downto 0);
		m_axi_arburst	: out std_logic_vector(1 downto 0);
		m_axi_arlock	: out std_logic;
		m_axi_arcache	: out std_logic_vector(3 downto 0);
		m_axi_arprot	: out std_logic_vector(2 downto 0);
		m_axi_arqos	    : out std_logic_vector(3 downto 0);
		m_axi_aruser	: out std_logic_vector(c_m_axi_aruser_width-1 downto 0);
		m_axi_arvalid	: out std_logic;
		m_axi_arready	: in  std_logic;
		m_axi_rid	    : in  std_logic_vector(c_m_axi_id_width-1 downto 0);
		m_axi_rdata	    : in  std_logic_vector(c_m_axi_data_width-1 downto 0);
		m_axi_rresp	    : in  std_logic_vector(1 downto 0);                 
		m_axi_rlast	    : in  std_logic;
		m_axi_ruser	    : in  std_logic_vector(c_m_axi_ruser_width-1 downto 0);
		m_axi_rvalid	: in  std_logic;
		m_axi_rready	: out std_logic
		);
	end component OSSNA_AXIM_DATA;

	signal CONTROLS_DMA_CNTRL          : std_logic_vector(3  downto 0);
    signal CONTROLS_DMA_START_READ     : std_logic;  
    signal CONTROLS_DMA_START_WRITE    : std_logic;  
    signal CONTROLS_DMA_RESET_SOFT     : std_logic;  
    signal CONTROLS_TARGET_SELECT      : std_logic;                  
    signal CONTROLS_FIFO_TYPE          : std_logic;                  
    signal CONTROLS_BYTE_PER_WORD      : std_logic_vector(31 downto 0);  
    signal CONTROLS_TOTAL_BYTES        : std_logic_vector(31 downto 0);
    signal CONTROLS_TOTAL_WORDS        : std_logic_vector(31 downto 0); 
    signal CONTROLS_BRAM_READ_DELAY    : std_logic_vector(31 downto 0); 
    signal CONTROLS_BRAM_BASEADDR      : std_logic_vector(31 downto 0);
    signal CONTROLS_DDR_BASEADDR       : std_logic_vector(31 downto 0);
    signal CONTROLS_TARGET_READ_DONE   : std_logic;
    signal CONTROLS_TARGET_WRITE_DONE  : std_logic;
    signal CONTROLS_TARGET_READ_ERROR  : std_logic;
    signal CONTROLS_TARGET_WRITE_ERROR : std_logic;
    signal CONTROLS_INPUT_SPIKE_MUX    : std_logic;

	component DATA_MUX is
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
        BRAM_ADDR                   : in   std_logic_vector(MAX_TARGET_BRAM_AWIDTH-1 downto 0);
        BRAM_DIN                    : in   std_logic_vector(MAX_TARGET_BRAM_DWIDTH-1 downto 0); 
        BRAM_WE                     : in   std_logic;
        BRAM_DOUT                   : out  std_logic_vector(MAX_TARGET_BRAM_DWIDTH-1 downto 0);
        FIFO_WREN                   : in   std_logic;
        FIFO_DIN                    : in   std_logic_vector(MAX_TARGET_FIFO_DWIDTH-1 downto 0);
        FIFO_RDEN                   : in   std_logic;
        FIFO_DOUT                   : out  std_logic_vector(MAX_TARGET_FIFO_DWIDTH-1 downto 0);
        FIFO_FULL                   : out  std_logic;
        FIFO_EMPTY                  : out  std_logic;
        SYNAPTIC_MEM_DIN            : out  SYNAPTICMEMDATA(0 to CROSSBAR_COL_WIDTH-1);
        SYNAPTIC_MEM_DADDR          : out  SYNAPTICMEMADDR(0 to CROSSBAR_COL_WIDTH-1);
        SYNAPTIC_MEM_EN             : out  std_logic_vector(0 to CROSSBAR_COL_WIDTH-1);
        SYNAPTIC_MEM_WREN           : out  std_logic_vector(0 to CROSSBAR_COL_WIDTH-1);
        SYNAPTIC_MEM_DOUT           : in   SYNAPTICMEMDATA(0 to CROSSBAR_COL_WIDTH-1);
        NMC_NPARAM_DATA             : out  STD_LOGIC_VECTOR(15 DOWNTO 0);
        NMC_NPARAM_ADDR             : out  STD_LOGIC_VECTOR(9  DOWNTO 0);
        NMC_PROG_MEM_PORTA_EN       : out  std_logic;
        NMC_PROG_MEM_PORTA_WEN      : out  std_logic;
        LEARN_LUT_DIN               : out  std_logic_vector(7 downto 0);
        LEARN_LUT_ADDR              : out  std_logic_vector(LENGINE_LUT_AWIDTH-1 downto 0);
        LEARN_LUT_EN                : out  std_logic;
        PARAM_MEM_DIN               : out  PARAMMEMDATA(0 to CROSSBAR_COL_WIDTH-1);
        PARAM_MEM_DADDR             : out  PARAMMEMADDR(0 to CROSSBAR_COL_WIDTH-1);
        PARAM_MEM_EN                : out  std_logic_vector(0 to CROSSBAR_COL_WIDTH-1); 
        PARAM_MEM_WREN              : out  std_logic_vector(0 to CROSSBAR_COL_WIDTH-1); 
        PARAM_MEM_DOUT              : in   PARAMMEMDATA(0 to CROSSBAR_COL_WIDTH-1);
        D2S_DATA_IN                 : out  std_logic_vector(31 downto 0);
        D2S_DATA_IN_VLD             : out  std_logic;
        INPUT_SPIKE_BUFFER_DIN      : out  std_logic_vector(CROSSBAR_ROW_WIDTH-1 downto 0);
        INPUT_SPIKE_BUFFER_WREN     : out  std_logic;
        INPUT_SPIKE_BUFFER_FULL     : in   std_logic;
        AUX_SPIKE_BUFFER_DIN        : out  std_logic_vector(CROSSBAR_ROW_WIDTH-1 downto 0);
        AUX_SPIKE_BUFFER_WREN       : out  std_logic;
        AUX_SPIKE_BUFFER_FULL       : in   std_logic;
        OUT_SPIKE_BUFFER_DOUT       : in   std_logic_vector(CROSSBAR_ROW_WIDTH-1 downto 0);
        OUT_SPIKE_BUFFER_RDEN       : out  std_logic;
        OUT_SPIKE_BUFFER_EMPTY      : in   std_logic 
        );
	end component DATA_MUX;

	constant MAX_BRAMDEPTH   : integer := FindMax(SYNAPSE_MEM_DEPTH,NEURAL_MEM_DEPTH,LEARNING_ENGINE_LUT_DEPTH);
	constant MAX_BRAM_AWIDTH : integer := clogb2(MAX_BRAMDEPTH);

    signal DATA_MUX_SELECT_SLAVE                : std_logic_vector(31 downto 0);
    signal DATA_MUX_BRAM_ADDR                   : std_logic_vector(MAX_BRAM_AWIDTH-1 downto 0);
    signal DATA_MUX_BRAM_DIN                    : std_logic_vector(31 downto 0); 
    signal DATA_MUX_BRAM_WE                     : std_logic;
    signal DATA_MUX_BRAM_DOUT                   : std_logic_vector(31 downto 0);
    signal DATA_MUX_FIFO_WREN                   : std_logic;
    signal DATA_MUX_FIFO_DIN                    : std_logic_vector(31 downto 0);
    signal DATA_MUX_FIFO_RDEN                   : std_logic;
    signal DATA_MUX_FIFO_DOUT                   : std_logic_vector(31 downto 0);
    signal DATA_MUX_FIFO_FULL                   : std_logic;
    signal DATA_MUX_FIFO_EMPTY                  : std_logic;
    signal DATA_MUX_SYNAPTIC_MEM_DIN            : SYNAPTICMEMDATA(0 to CROSSBAR_MATRIX_DIMENSIONS-1);
    signal DATA_MUX_SYNAPTIC_MEM_DADDR          : SYNAPTICMEMADDR(0 to CROSSBAR_MATRIX_DIMENSIONS-1);
    signal DATA_MUX_SYNAPTIC_MEM_EN             : std_logic_vector(0 to CROSSBAR_MATRIX_DIMENSIONS-1);
    signal DATA_MUX_SYNAPTIC_MEM_WREN           : std_logic_vector(0 to CROSSBAR_MATRIX_DIMENSIONS-1);
    signal DATA_MUX_SYNAPTIC_MEM_DOUT           : SYNAPTICMEMDATA(0 to CROSSBAR_MATRIX_DIMENSIONS-1);
    signal DATA_MUX_NMC_NPARAM_DATA             : STD_LOGIC_VECTOR(15 DOWNTO 0);
    signal DATA_MUX_NMC_NPARAM_ADDR             : STD_LOGIC_VECTOR(9  DOWNTO 0);
    signal DATA_MUX_NMC_PROG_MEM_PORTA_EN       : std_logic;
    signal DATA_MUX_NMC_PROG_MEM_PORTA_WEN      : std_logic;
    signal DATA_MUX_LEARN_LUT_DIN               : std_logic_vector(7 downto 0);
    signal DATA_MUX_LEARN_LUT_ADDR              : std_logic_vector(clogb2(LEARNING_ENGINE_LUT_DEPTH)-1 downto 0);
    signal DATA_MUX_LEARN_LUT_EN                : std_logic;
    signal DATA_MUX_PARAM_MEM_DIN               : PARAMMEMDATA(0 to CROSSBAR_MATRIX_DIMENSIONS-1);
    signal DATA_MUX_PARAM_MEM_DADDR             : PARAMMEMADDR(0 to CROSSBAR_MATRIX_DIMENSIONS-1);
    signal DATA_MUX_PARAM_MEM_EN                : std_logic_vector(0 to CROSSBAR_MATRIX_DIMENSIONS-1); 
    signal DATA_MUX_PARAM_MEM_WREN              : std_logic_vector(0 to CROSSBAR_MATRIX_DIMENSIONS-1); 
    signal DATA_MUX_PARAM_MEM_DOUT              : PARAMMEMDATA(0 to CROSSBAR_MATRIX_DIMENSIONS-1);
    signal DATA_MUX_D2S_DATA_IN                 : std_logic_vector(31 downto 0);
    signal DATA_MUX_D2S_DATA_IN_VLD             : std_logic;
    signal DATA_MUX_INPUT_SPIKE_BUFFER_DIN      : std_logic_vector(CROSSBAR_MATRIX_DIMENSIONS-1 downto 0);
    signal DATA_MUX_INPUT_SPIKE_BUFFER_WREN     : std_logic;
    signal DATA_MUX_INPUT_SPIKE_BUFFER_FULL     : std_logic;
    signal DATA_MUX_AUX_SPIKE_BUFFER_DIN        : std_logic_vector(CROSSBAR_MATRIX_DIMENSIONS-1 downto 0);
    signal DATA_MUX_AUX_SPIKE_BUFFER_WREN       : std_logic;
    signal DATA_MUX_AUX_SPIKE_BUFFER_FULL       : std_logic;
    signal DATA_MUX_OUT_SPIKE_BUFFER_DOUT       : std_logic_vector(CROSSBAR_MATRIX_DIMENSIONS-1 downto 0);
    signal DATA_MUX_OUT_SPIKE_BUFFER_RDEN       : std_logic;
    signal DATA_MUX_OUT_SPIKE_BUFFER_EMPTY      : std_logic;

	component SPIKE_PROCESSOR is
    Generic (
            CROSSBAR_ROW_WIDTH : integer := 16;
            CROSSBAR_COL_WIDTH : integer := 16;
            SYNAPSE_MEM_DEPTH  : integer := 8196;
            NEURAL_MEM_DEPTH   : integer := 1024;
            LEARNING_ENGINE_LUT_DEPTH : integer := 4096
            );
    Port ( 
            SP_CLOCK                    : in  std_logic;
            PARAMETER_MEM_RDCLK         : in  std_logic;
            SP_RESET                    : in  std_logic;
            NETWORK_START_ADDRESS       : in  std_logic_vector(31 downto 0);
            TIMESTEP_STARTED            : in  std_logic;
            TIMESTEP_COMPLETED          : out std_logic;
            DISABLE_LEARNING_ENGINES    : in  std_logic;
            SPIKEVECTOR_IN              : in  std_logic_vector(CROSSBAR_ROW_WIDTH-1 downto 0); 
            SPIKEVECTOR_VLD_IN          : in  std_logic;           
            SPIKEVECTOR_OUT             : out std_logic_vector(CROSSBAR_ROW_WIDTH-1 downto 0); 
            SPIKEVECTOR_VLD_OUT         : out std_logic;                     
            READ_MAIN_SPIKE_BUFFER      : out std_logic;
            READ_CIRCULAR_BUFFER        : out std_logic;
            EVENT_ACCEPT                : out std_logic;
            SYNAPSE_ROUTE               : in  std_logic; 
            SYNAPTIC_MEM_DIN            : in  SYNAPTICMEMDATA(0 to CROSSBAR_COL_WIDTH-1);
            SYNAPTIC_MEM_DADDR          : in  SYNAPTICMEMADDR(0 to CROSSBAR_COL_WIDTH-1);
            SYNAPTIC_MEM_EN             : in  std_logic_vector(0 to CROSSBAR_COL_WIDTH-1);
            SYNAPTIC_MEM_WREN           : in  std_logic_vector(0 to CROSSBAR_COL_WIDTH-1);
            SYNAPTIC_MEM_DOUT           : out SYNAPTICMEMDATA(0 to CROSSBAR_COL_WIDTH-1);
            NMC_XNEVER_BASE             : in  std_logic_vector(9 downto 0);
            NMC_XNEVER_HIGH             : in  std_logic_vector(9 downto 0);
            NMC_PMODE_SWITCH            : in  std_logic;  
            NMC_NPARAM_DATA             : in  STD_LOGIC_VECTOR(15 DOWNTO 0);
            NMC_NPARAM_ADDR             : in  STD_LOGIC_VECTOR(9  DOWNTO 0);
            NMC_PROG_MEM_PORTA_EN       : in  std_logic;
            NMC_PROG_MEM_PORTA_WEN      : in  std_logic;
            NMC_SPIKE_OUT               : out std_logic_vector(0 to CROSSBAR_COL_WIDTH-1 );
            NMC_SPIKE_OUT_VLD           : out std_logic_vector(0 to CROSSBAR_COL_WIDTH-1 );
            NMC_WR_OUT_BUFFER           : out std_logic;
            LEARN_LUT_DIN               : in  std_logic_vector(7 downto 0);
            LEARN_LUT_ADDR              : in  std_logic_vector(clogb2(LEARNING_ENGINE_LUT_DEPTH)-1 downto 0)   ;
            LEARN_LUT_EN                : in  std_logic;
            PARAM_MEM_DIN               : in  PARAMMEMDATA(0 to CROSSBAR_COL_WIDTH-1);
            PARAM_MEM_DADDR             : in  PARAMMEMADDR(0 to CROSSBAR_COL_WIDTH-1);
            PARAM_MEM_EN                : in  std_logic_vector(0 to CROSSBAR_COL_WIDTH-1); 
            PARAM_MEM_WREN              : in  std_logic_vector(0 to CROSSBAR_COL_WIDTH-1); 
            PARAM_MEM_DOUT              : out PARAMMEMDATA(0 to CROSSBAR_COL_WIDTH-1);
            NMC_MATH_ERROR_VEC          : out std_logic; 
            NMC_MEM_VIOLATION_VEC       : out std_logic
          );
	end component SPIKE_PROCESSOR;

    signal CORE_SP_RESET                    : std_logic;
    signal CORE_NETWORK_START_ADDRESS       : std_logic_vector(31 downto 0);
    signal CORE_TIMESTEP_STARTED            : std_logic;
    signal CORE_TIMESTEP_COMPLETED          : std_logic;
    signal CORE_DISABLE_LEARNING_ENGINES    : std_logic;
    signal CORE_SPIKEVECTOR_IN              : std_logic_vector(CROSSBAR_MATRIX_DIMENSIONS-1 downto 0); 
    signal CORE_SPIKEVECTOR_VLD_IN          : std_logic;           
    signal CORE_SPIKEVECTOR_OUT             : std_logic_vector(CROSSBAR_MATRIX_DIMENSIONS-1 downto 0); 
    signal CORE_SPIKEVECTOR_VLD_OUT         : std_logic;                     
    signal CORE_READ_MAIN_SPIKE_BUFFER      : std_logic;
    signal CORE_READ_CIRCULAR_BUFFER        : std_logic;
    signal CORE_EVENT_ACCEPT                : std_logic;
    signal CORE_SYNAPSE_ROUTE               : std_logic; 
    signal CORE_NMC_XNEVER_BASE             : std_logic_vector(9 downto 0);
    signal CORE_NMC_XNEVER_HIGH             : std_logic_vector(9 downto 0);
    signal CORE_NMC_PMODE_SWITCH            : std_logic;  
    signal CORE_NMC_SPIKE_OUT               : std_logic_vector(0 to CROSSBAR_MATRIX_DIMENSIONS-1 );
    signal CORE_NMC_SPIKE_OUT_VLD           : std_logic_vector(0 to CROSSBAR_MATRIX_DIMENSIONS-1 );
    signal CORE_NMC_WR_OUT_BUFFER           : std_logic;
    signal CORE_NMC_MATH_ERROR_VEC          : std_logic; 
    signal CORE_NMC_MEM_VIOLATION_VEC       : std_logic;

	component D2S is
    	Generic(
    	        MAX_ALLOWED_INWIDTH : natural := 2048;
    	        BUFPRIM             : string  := "BLOCK"; 
    	        CROSSBAR_WIDTH      : natural := 16
    	        );
    	Port ( 
    	        D2S_RST        : in  std_logic;
    	        D2S_WCLK       : in  std_logic;
    	        D2S_RCLK       : in  std_logic;
    	        CONVMODE       : in  std_logic_vector(1  downto 0); 
    	        TIME_WIND      : in  std_logic_vector(31 downto 0);
    	        SEED           : in  std_logic_vector(31 downto 0);
    	        DATA_COUNT     : in  std_logic_vector(31 downto 0);
    	        DATA_IN        : in  std_logic_vector(31 downto 0);
    	        DATA_IN_VLD    : in  std_logic;
    	        NEW_TIMESTEP   : in  std_logic;
    	        SPIKE_OUT      : out std_logic_vector(CROSSBAR_WIDTH-1 downto 0);
    	        SPIKE_VLD      : out std_logic;
    	        CONV_DONE      : out std_logic
    	    );
    end component D2S;

    signal D2S_D2S_RST        : std_logic;
    signal D2S_CONVMODE       : std_logic_vector(1  downto 0); 
    signal D2S_TIME_WIND      : std_logic_vector(31 downto 0);
    signal D2S_SEED           : std_logic_vector(31 downto 0);
    signal D2S_DATA_COUNT     : std_logic_vector(31 downto 0);
    signal D2S_DATA_IN        : std_logic_vector(31 downto 0);
    signal D2S_DATA_IN_VLD    : std_logic;
    signal D2S_NEW_TIMESTEP   : std_logic;
    signal D2S_SPIKE_OUT      : std_logic_vector(CROSSBAR_MATRIX_DIMENSIONS-1 downto 0);
    signal D2S_SPIKE_VLD      : std_logic;
    signal D2S_CONV_DONE      : std_logic;


    signal CONTROLS_FLUSH_MAIN_BUFFER        : std_logic;
	signal CONTROLS_FLUSH_AUX_BUFFER         : std_logic;
	signal CONTROLS_FLUSH_CIRCULAR_BUFFER    : std_logic;
	signal CONTROLS_FLUSH_OUT_BUFFER      	 : std_logic;

---------------------------------- MAIN SPIKE BUFFER SIGNALS BEGIN -----------------------------------
------------------------------------------------------------------------------------------------------

      signal MAIN_SPIKE_BUFFER_DOUT  : std_logic_vector(CROSSBAR_MATRIX_DIMENSIONS-1 downto 0);
      signal PS_MAIN_SPIKE_BUFFER_DIN   : std_logic_vector(CROSSBAR_MATRIX_DIMENSIONS-1 downto 0);
      signal PL_MAIN_SPIKE_BUFFER_DIN   : std_logic_vector(CROSSBAR_MATRIX_DIMENSIONS-1 downto 0);
      signal MAIN_SPIKE_BUFFER_DIN   : std_logic_vector(CROSSBAR_MATRIX_DIMENSIONS-1 downto 0);
      signal MAIN_SPIKE_BUFFER_RDEN  : std_logic;
      signal MAIN_SPIKE_BUFFER_FULL  : std_logic;
      signal MAIN_SPIKE_BUFFER_EMPTY : std_logic;
      signal PS_MAIN_SPIKE_BUFFER_WREN  : std_logic;
      signal PL_MAIN_SPIKE_BUFFER_WREN  : std_logic;
      signal MAIN_SPIKE_BUFFER_WREN  : std_logic;

---------------------------------- MAIN SPIKE_BUFFER SIGNALS END -------------------------------------


      signal CIRCULAR_BUFFER_DOUT  : std_logic_vector(CROSSBAR_MATRIX_DIMENSIONS-1 downto 0);
      signal CIRCULAR_BUFFER_DIN   : std_logic_vector(CROSSBAR_MATRIX_DIMENSIONS-1 downto 0);
      signal CIRCULAR_BUFFER_RDEN  : std_logic;
      signal CIRCULAR_BUFFER_FULL  : std_logic;
      signal CIRCULAR_BUFFER_EMPTY : std_logic;
      signal CIRCULAR_BUFFER_WREN  : std_logic;

------------------------------------------------------------------------------------------------------

---------------------------------- OUT SPIKE BUFFER SIGNALS BEGIN -----------------------------------
------------------------------------------------------------------------------------------------------

      signal OUT_SPIKE_BUFFER_DIN   : std_logic_vector(CROSSBAR_MATRIX_DIMENSIONS-1 downto 0);
      signal OUT_SPIKE_BUFFER_FULL  : std_logic;
      signal OUT_SPIKE_BUFFER_EMPTY : std_logic;
      signal OUT_SPIKE_BUFFER_WREN  : std_logic;
      signal OUT_SPIKE_BUFFER_LAST : std_logic;

---------------------------------- OUT SPIKE_BUFFER SIGNALS END -------------------------------------
------------------------------------------------------------------------------------------------------    

      signal NMC_SPIKE_OUT_LATCH    : std_logic_vector(0 to CROSSBAR_MATRIX_DIMENSIONS-1 );
      signal NMC_SPIKE_OUT_LATCH_DELAY    : std_logic_vector(0 to CROSSBAR_MATRIX_DIMENSIONS-1 );
      signal ALL_SPIKES_ARRIVED     : std_logic_vector(0 to CROSSBAR_MATRIX_DIMENSIONS-1 );

      type SSTATES is (LISTENING,CATCHSPIKE,HOLDSPIKE);
      
      type SPIKE_STATES is array (0 to CROSSBAR_MATRIX_DIMENSIONS-1) of SSTATES; 
      
      signal SPIKE_STATE : SPIKE_STATES;
      
      signal READFIFOSELECT : std_logic_vector(1 downto 0);
      
      type FIFOSTATES is (WAITINPUT,WRITE);
      signal FIFOSTATE : FIFOSTATES;

      constant ARRIVAL : std_logic_vector(0 to CROSSBAR_MATRIX_DIMENSIONS-1 ) := (others=>'1');
      
      signal SPIKE_SYNCHRONIZER : std_logic;
      signal WRITESPIKES : std_logic;
      signal AUTOUPDATE : std_logic;
------------------------------------------------------------------------------------------------------

      signal TMEUPDTCYCLE : std_logic_vector(15 downto 0);
      signal TMEUPDTCYCLELIM : integer;
      signal UPDCOUNTER   : integer;
      
      signal FIFOWRITEDLY : integer;


begin

OSSNA_CONTROLS : OSSNA_AXIL_CONTROLS
	generic map (
        CROSSBAR_ROW_WIDTH => CROSSBAR_MATRIX_DIMENSIONS,
        CROSSBAR_COL_WIDTH => CROSSBAR_MATRIX_DIMENSIONS,
        SYNAPSE_MEM_DEPTH  => SYNAPSE_MEM_DEPTH,
        NEURAL_MEM_DEPTH   => NEURAL_MEM_DEPTH,
        LEARNING_ENGINE_LUT_DEPTH => LEARNING_ENGINE_LUT_DEPTH,
        SPIKE_GENERATOR_BUFFER_DEPTH => SPIKE_GENERATOR_BUFFER_DEPTH,
		C_S_AXI_DATA_WIDTH	=> C_AXIL_CONTROLS_DATA_WIDTH,
		C_S_AXI_ADDR_WIDTH	=> C_AXIL_CONTROLS_ADDR_WIDTH
	)
	port map (
        DMA_START_READ           => CONTROLS_DMA_START_READ      ,
        DMA_START_WRITE          => CONTROLS_DMA_START_WRITE     ,
        DMA_RESET_SOFT           => CONTROLS_DMA_RESET_SOFT      ,
        TARGET_SELECT            => CONTROLS_TARGET_SELECT       ,
        FIFO_TYPE                => CONTROLS_FIFO_TYPE           ,
        BYTE_PER_WORD            => CONTROLS_BYTE_PER_WORD       ,  
        TOTAL_BYTES              => CONTROLS_TOTAL_BYTES         ,
        TOTAL_WORDS              => CONTROLS_TOTAL_WORDS         , 
        BRAM_READ_DELAY          => CONTROLS_BRAM_READ_DELAY     , 
        BRAM_BASEADDR            => CONTROLS_BRAM_BASEADDR       ,
        DDR_BASEADDR             => CONTROLS_DDR_BASEADDR        ,
        TARGET_READ_DONE         => CONTROLS_TARGET_READ_DONE    ,
        TARGET_WRITE_DONE        => CONTROLS_TARGET_WRITE_DONE   ,
        TARGET_READ_ERROR        => CONTROLS_TARGET_READ_ERROR   ,
        TARGET_WRITE_ERROR       => CONTROLS_TARGET_WRITE_ERROR  ,

		SELECT_SLAVE             => DATA_MUX_SELECT_SLAVE         ,

		INPUT_SPIKE_MUX          => CONTROLS_INPUT_SPIKE_MUX      ,

        D2S_RESET                => D2S_D2S_RST ,
        CONVMODE                 => D2S_CONVMODE ,
        TIME_WIND                => D2S_TIME_WIND ,
        SEED                     => D2S_SEED ,
        DATA_COUNT               => D2S_DATA_COUNT ,
        CONV_DONE                => D2S_CONV_DONE ,

        SP_RESET                 => CORE_SP_RESET                   ,
        NETWORK_START_ADDRESS    => CORE_NETWORK_START_ADDRESS      ,
        TIMESTEP_STARTED         => CORE_TIMESTEP_STARTED           ,
        TIMESTEP_COMPLETED       => CORE_TIMESTEP_COMPLETED         ,
        DISABLE_LEARNING_ENGINES => CORE_DISABLE_LEARNING_ENGINES   ,
        SYNAPSE_ROUTE            => CORE_SYNAPSE_ROUTE              ,
        NMC_XNEVER_BASE          => CORE_NMC_XNEVER_BASE            ,
        NMC_XNEVER_HIGH          => CORE_NMC_XNEVER_HIGH            ,
        NMC_PMODE_SWITCH         => CORE_NMC_PMODE_SWITCH           ,
        NMC_MATH_ERROR_VEC       => CORE_NMC_MATH_ERROR_VEC         ,
        NMC_MEM_VIOLATION_VEC    => CORE_NMC_MEM_VIOLATION_VEC      ,

        FLUSH_MAIN_BUFFER        => CONTROLS_FLUSH_MAIN_BUFFER      ,
		FLUSH_AUX_BUFFER         => CONTROLS_FLUSH_AUX_BUFFER       ,
		FLUSH_CIRCULAR_BUFFER    => CONTROLS_FLUSH_CIRCULAR_BUFFER  ,
		FLUSH_OUT_BUFFER      	 => CONTROLS_FLUSH_OUT_BUFFER      	,

		S_AXI_ACLK	=> axil_controls_aclk,
		S_AXI_ARESETN	=> axil_controls_aresetn,
		S_AXI_AWADDR	=> axil_controls_awaddr,
		S_AXI_AWPROT	=> axil_controls_awprot,
		S_AXI_AWVALID	=> axil_controls_awvalid,
		S_AXI_AWREADY	=> axil_controls_awready,
		S_AXI_WDATA	=> axil_controls_wdata,
		S_AXI_WSTRB	=> axil_controls_wstrb,
		S_AXI_WVALID	=> axil_controls_wvalid,
		S_AXI_WREADY	=> axil_controls_wready,
		S_AXI_BRESP	=> axil_controls_bresp,
		S_AXI_BVALID	=> axil_controls_bvalid,
		S_AXI_BREADY	=> axil_controls_bready,
		S_AXI_ARADDR	=> axil_controls_araddr,
		S_AXI_ARPROT	=> axil_controls_arprot,
		S_AXI_ARVALID	=> axil_controls_arvalid,
		S_AXI_ARREADY	=> axil_controls_arready,
		S_AXI_RDATA	=> axil_controls_rdata,
		S_AXI_RRESP	=> axil_controls_rresp,
		S_AXI_RVALID	=> axil_controls_rvalid,
		S_AXI_RREADY	=> axil_controls_rready
	);

OSSNA_DATA : OSSNA_AXIM_DATA
	generic map (
		outstanding_limit      => 16,
        MAX_TARGET_FIFO_DWIDTH => 32,
        MAX_TARGET_BRAM_DWIDTH => 32,
        MAX_TARGET_BRAM_AWIDTH => MAX_BRAM_AWIDTH ,
		C_M_TARGET_SLAVE_BASE_ADDR	=> C_AXIM_DATA_TARGET_SLAVE_BASE_ADDR,
		C_M_AXI_BURST_LEN	=> C_AXIM_DATA_BURST_LEN,
		C_M_AXI_ID_WIDTH	=> C_AXIM_DATA_ID_WIDTH,
		C_M_AXI_ADDR_WIDTH	=> C_AXIM_DATA_ADDR_WIDTH,
		C_M_AXI_DATA_WIDTH	=> C_AXIM_DATA_DATA_WIDTH,
		C_M_AXI_AWUSER_WIDTH	=> C_AXIM_DATA_AWUSER_WIDTH,
		C_M_AXI_ARUSER_WIDTH	=> C_AXIM_DATA_ARUSER_WIDTH,
		C_M_AXI_WUSER_WIDTH	=> C_AXIM_DATA_WUSER_WIDTH,
		C_M_AXI_RUSER_WIDTH	=> C_AXIM_DATA_RUSER_WIDTH,
		C_M_AXI_BUSER_WIDTH	=> C_AXIM_DATA_BUSER_WIDTH
	)
	port map (

        DMA_START_READ     => CONTROLS_DMA_START_READ      ,
        DMA_START_WRITE    => CONTROLS_DMA_START_WRITE     ,
        DMA_RESET_SOFT     => CONTROLS_DMA_RESET_SOFT      ,
        TARGET_SELECT      => CONTROLS_TARGET_SELECT       ,
        FIFO_TYPE          => CONTROLS_FIFO_TYPE           ,
        BYTE_PER_WORD      => CONTROLS_BYTE_PER_WORD       ,
        TOTAL_BYTES        => CONTROLS_TOTAL_BYTES         ,
        TOTAL_WORDS        => CONTROLS_TOTAL_WORDS         ,
        BRAM_READ_DELAY    => CONTROLS_BRAM_READ_DELAY     ,
        BRAM_BASEADDR      => CONTROLS_BRAM_BASEADDR       ,
        DDR_BASEADDR       => CONTROLS_DDR_BASEADDR        ,
        TARGET_READ_DONE   => CONTROLS_TARGET_READ_DONE    ,
        TARGET_WRITE_DONE  => CONTROLS_TARGET_WRITE_DONE   ,
        TARGET_READ_ERROR  => CONTROLS_TARGET_READ_ERROR   ,
        TARGET_WRITE_ERROR => CONTROLS_TARGET_WRITE_ERROR  ,

        BRAM_ADDR  => DATA_MUX_BRAM_ADDR    ,
        BRAM_DIN   => DATA_MUX_BRAM_DIN     ,
        BRAM_WE    => DATA_MUX_BRAM_WE      ,
        BRAM_DOUT  => DATA_MUX_BRAM_DOUT    ,
        FIFO_WREN  => DATA_MUX_FIFO_WREN    ,
        FIFO_DIN   => DATA_MUX_FIFO_DIN     ,
        FIFO_RDEN  => DATA_MUX_FIFO_RDEN    ,
        FIFO_DOUT  => DATA_MUX_FIFO_DOUT    ,
        FIFO_EMPTY => DATA_MUX_FIFO_EMPTY   ,
        FIFO_FULL  => DATA_MUX_FIFO_FULL    ,

		M_AXI_ACLK	=> axim_data_aclk,
		M_AXI_ARESETN	=> axim_data_aresetn,
		M_AXI_AWID	=> axim_data_awid,
		M_AXI_AWADDR	=> axim_data_awaddr,
		M_AXI_AWLEN	=> axim_data_awlen,
		M_AXI_AWSIZE	=> axim_data_awsize,
		M_AXI_AWBURST	=> axim_data_awburst,
		M_AXI_AWLOCK	=> axim_data_awlock,
		M_AXI_AWCACHE	=> axim_data_awcache,
		M_AXI_AWPROT	=> axim_data_awprot,
		M_AXI_AWQOS	=> axim_data_awqos,
		M_AXI_AWUSER	=> axim_data_awuser,
		M_AXI_AWVALID	=> axim_data_awvalid,
		M_AXI_AWREADY	=> axim_data_awready,
		M_AXI_WDATA	=> axim_data_wdata,
		M_AXI_WSTRB	=> axim_data_wstrb,
		M_AXI_WLAST	=> axim_data_wlast,
		M_AXI_WUSER	=> axim_data_wuser,
		M_AXI_WVALID	=> axim_data_wvalid,
		M_AXI_WREADY	=> axim_data_wready,
		M_AXI_BID	=> axim_data_bid,
		M_AXI_BRESP	=> axim_data_bresp,
		M_AXI_BUSER	=> axim_data_buser,
		M_AXI_BVALID	=> axim_data_bvalid,
		M_AXI_BREADY	=> axim_data_bready,
		M_AXI_ARID	=> axim_data_arid,
		M_AXI_ARADDR	=> axim_data_araddr,
		M_AXI_ARLEN	=> axim_data_arlen,
		M_AXI_ARSIZE	=> axim_data_arsize,
		M_AXI_ARBURST	=> axim_data_arburst,
		M_AXI_ARLOCK	=> axim_data_arlock,
		M_AXI_ARCACHE	=> axim_data_arcache,
		M_AXI_ARPROT	=> axim_data_arprot,
		M_AXI_ARQOS	=> axim_data_arqos,
		M_AXI_ARUSER	=> axim_data_aruser,
		M_AXI_ARVALID	=> axim_data_arvalid,
		M_AXI_ARREADY	=> axim_data_arready,
		M_AXI_RID	=> axim_data_rid,
		M_AXI_RDATA	=> axim_data_rdata,
		M_AXI_RRESP	=> axim_data_rresp,
		M_AXI_RLAST	=> axim_data_rlast,
		M_AXI_RUSER	=> axim_data_ruser,
		M_AXI_RVALID	=> axim_data_rvalid,
		M_AXI_RREADY	=> axim_data_rready
	);

	DMA_MUX : DATA_MUX 
    Generic Map(
        MAX_TARGET_FIFO_DWIDTH  => 32,
        MAX_TARGET_BRAM_DWIDTH  => 32,
        MAX_TARGET_BRAM_AWIDTH  => MAX_BRAM_AWIDTH,
        LENGINE_LUT_AWIDTH      => clogb2(LEARNING_ENGINE_LUT_DEPTH),
        CROSSBAR_ROW_WIDTH      => CROSSBAR_MATRIX_DIMENSIONS,
        CROSSBAR_COL_WIDTH      => CROSSBAR_MATRIX_DIMENSIONS,
        SYNAPTIC_MEMORY_AWIDTH  => clogb2(SYNAPSE_MEM_DEPTH),
        PARAMETER_MEMORY_AWIDTH => clogb2(NEURAL_MEM_DEPTH)
    )
    Port Map 
        ( 
        SELECT_SLAVE             => DATA_MUX_SELECT_SLAVE            ,
        BRAM_ADDR                => DATA_MUX_BRAM_ADDR               ,
        BRAM_DIN                 => DATA_MUX_BRAM_DIN                ,
        BRAM_WE                  => DATA_MUX_BRAM_WE                 ,
        BRAM_DOUT                => DATA_MUX_BRAM_DOUT               ,
        FIFO_WREN                => DATA_MUX_FIFO_WREN               ,
        FIFO_DIN                 => DATA_MUX_FIFO_DIN                ,
        FIFO_RDEN                => DATA_MUX_FIFO_RDEN               ,
        FIFO_DOUT                => DATA_MUX_FIFO_DOUT               ,
        FIFO_FULL                => DATA_MUX_FIFO_FULL               ,
        FIFO_EMPTY               => DATA_MUX_FIFO_EMPTY              ,
        SYNAPTIC_MEM_DIN         => DATA_MUX_SYNAPTIC_MEM_DIN        ,
        SYNAPTIC_MEM_DADDR       => DATA_MUX_SYNAPTIC_MEM_DADDR      ,
        SYNAPTIC_MEM_EN          => DATA_MUX_SYNAPTIC_MEM_EN         ,
        SYNAPTIC_MEM_WREN        => DATA_MUX_SYNAPTIC_MEM_WREN       ,
        SYNAPTIC_MEM_DOUT        => DATA_MUX_SYNAPTIC_MEM_DOUT       ,
        NMC_NPARAM_DATA          => DATA_MUX_NMC_NPARAM_DATA         ,
        NMC_NPARAM_ADDR          => DATA_MUX_NMC_NPARAM_ADDR         ,
        NMC_PROG_MEM_PORTA_EN    => DATA_MUX_NMC_PROG_MEM_PORTA_EN   ,
        NMC_PROG_MEM_PORTA_WEN   => DATA_MUX_NMC_PROG_MEM_PORTA_WEN  ,
        LEARN_LUT_DIN            => DATA_MUX_LEARN_LUT_DIN           ,
        LEARN_LUT_ADDR           => DATA_MUX_LEARN_LUT_ADDR          ,
        LEARN_LUT_EN             => DATA_MUX_LEARN_LUT_EN            ,
        PARAM_MEM_DIN            => DATA_MUX_PARAM_MEM_DIN           ,
        PARAM_MEM_DADDR          => DATA_MUX_PARAM_MEM_DADDR         ,
        PARAM_MEM_EN             => DATA_MUX_PARAM_MEM_EN            ,
        PARAM_MEM_WREN           => DATA_MUX_PARAM_MEM_WREN          ,
        PARAM_MEM_DOUT           => DATA_MUX_PARAM_MEM_DOUT          ,
        D2S_DATA_IN              => DATA_MUX_D2S_DATA_IN             ,
        D2S_DATA_IN_VLD          => DATA_MUX_D2S_DATA_IN_VLD         ,
        INPUT_SPIKE_BUFFER_DIN   => DATA_MUX_INPUT_SPIKE_BUFFER_DIN  ,
        INPUT_SPIKE_BUFFER_WREN  => DATA_MUX_INPUT_SPIKE_BUFFER_WREN ,
        INPUT_SPIKE_BUFFER_FULL  => DATA_MUX_INPUT_SPIKE_BUFFER_FULL ,
        AUX_SPIKE_BUFFER_DIN     => DATA_MUX_AUX_SPIKE_BUFFER_DIN    ,
        AUX_SPIKE_BUFFER_WREN    => DATA_MUX_AUX_SPIKE_BUFFER_WREN   ,
        AUX_SPIKE_BUFFER_FULL    => DATA_MUX_AUX_SPIKE_BUFFER_FULL   ,
        OUT_SPIKE_BUFFER_DOUT    => DATA_MUX_OUT_SPIKE_BUFFER_DOUT   ,
        OUT_SPIKE_BUFFER_RDEN    => DATA_MUX_OUT_SPIKE_BUFFER_RDEN   ,
        OUT_SPIKE_BUFFER_EMPTY   => DATA_MUX_OUT_SPIKE_BUFFER_EMPTY  
        );

	CORE_INIT : SPIKE_PROCESSOR
    Generic Map(
            CROSSBAR_ROW_WIDTH => CROSSBAR_MATRIX_DIMENSIONS ,
            CROSSBAR_COL_WIDTH => CROSSBAR_MATRIX_DIMENSIONS ,
            SYNAPSE_MEM_DEPTH  => SYNAPSE_MEM_DEPTH  ,
            NEURAL_MEM_DEPTH   => NEURAL_MEM_DEPTH   ,
            LEARNING_ENGINE_LUT_DEPTH => LEARNING_ENGINE_LUT_DEPTH
            )
    Port Map( 
            SP_CLOCK                    => axim_data_aclk ,
            PARAMETER_MEM_RDCLK         => axim_data_aclk ,
            SP_RESET                    => CORE_SP_RESET                   ,
            NETWORK_START_ADDRESS       => CORE_NETWORK_START_ADDRESS      ,
            TIMESTEP_STARTED            => CORE_TIMESTEP_STARTED           ,
            TIMESTEP_COMPLETED          => CORE_TIMESTEP_COMPLETED         ,
            DISABLE_LEARNING_ENGINES    => CORE_DISABLE_LEARNING_ENGINES   ,
            SPIKEVECTOR_IN              => CORE_SPIKEVECTOR_IN             ,
            SPIKEVECTOR_VLD_IN          => CORE_SPIKEVECTOR_VLD_IN         ,
            SPIKEVECTOR_OUT             => CORE_SPIKEVECTOR_OUT            ,
            SPIKEVECTOR_VLD_OUT         => CORE_SPIKEVECTOR_VLD_OUT        ,
            READ_MAIN_SPIKE_BUFFER      => CORE_READ_MAIN_SPIKE_BUFFER     ,
            READ_CIRCULAR_BUFFER        => CORE_READ_CIRCULAR_BUFFER       ,
            EVENT_ACCEPT                => CORE_EVENT_ACCEPT               ,
            SYNAPSE_ROUTE               => CORE_SYNAPSE_ROUTE              ,
            SYNAPTIC_MEM_DIN            => DATA_MUX_SYNAPTIC_MEM_DIN       ,
            SYNAPTIC_MEM_DADDR          => DATA_MUX_SYNAPTIC_MEM_DADDR     ,
            SYNAPTIC_MEM_EN             => DATA_MUX_SYNAPTIC_MEM_EN        ,
            SYNAPTIC_MEM_WREN           => DATA_MUX_SYNAPTIC_MEM_WREN      ,
            SYNAPTIC_MEM_DOUT           => DATA_MUX_SYNAPTIC_MEM_DOUT      ,
            NMC_XNEVER_BASE             => CORE_NMC_XNEVER_BASE            ,
            NMC_XNEVER_HIGH             => CORE_NMC_XNEVER_HIGH            ,
            NMC_PMODE_SWITCH            => CORE_NMC_PMODE_SWITCH           ,
            NMC_NPARAM_DATA             => DATA_MUX_NMC_NPARAM_DATA        ,
            NMC_NPARAM_ADDR             => DATA_MUX_NMC_NPARAM_ADDR        ,
            NMC_PROG_MEM_PORTA_EN       => DATA_MUX_NMC_PROG_MEM_PORTA_EN  ,
            NMC_PROG_MEM_PORTA_WEN      => DATA_MUX_NMC_PROG_MEM_PORTA_WEN ,
            NMC_SPIKE_OUT               => CORE_NMC_SPIKE_OUT              ,
            NMC_SPIKE_OUT_VLD           => CORE_NMC_SPIKE_OUT_VLD          ,
            NMC_WR_OUT_BUFFER           => CORE_NMC_WR_OUT_BUFFER          ,
            LEARN_LUT_DIN               => DATA_MUX_LEARN_LUT_DIN          ,
            LEARN_LUT_ADDR              => DATA_MUX_LEARN_LUT_ADDR         ,
            LEARN_LUT_EN                => DATA_MUX_LEARN_LUT_EN           ,
            PARAM_MEM_DIN               => DATA_MUX_PARAM_MEM_DIN          ,
            PARAM_MEM_DADDR             => DATA_MUX_PARAM_MEM_DADDR        ,
            PARAM_MEM_EN                => DATA_MUX_PARAM_MEM_EN           ,
            PARAM_MEM_WREN              => DATA_MUX_PARAM_MEM_WREN         ,
            PARAM_MEM_DOUT              => DATA_MUX_PARAM_MEM_DOUT         ,
            NMC_MATH_ERROR_VEC          => CORE_NMC_MATH_ERROR_VEC         ,
            NMC_MEM_VIOLATION_VEC       => CORE_NMC_MEM_VIOLATION_VEC     
          );

    DATA_CONVERTER : D2S
    	Generic Map(
    	        MAX_ALLOWED_INWIDTH => SPIKE_GENERATOR_BUFFER_DEPTH ,
    	        BUFPRIM             => "BLOCK", 
    	        CROSSBAR_WIDTH      => CROSSBAR_MATRIX_DIMENSIONS
    	        )
    	Port Map( 
    	        D2S_RST      => D2S_D2S_RST      ,
    	        D2S_WCLK     => axim_data_aclk   ,
    	        D2S_RCLK     => axim_data_aclk   ,
    	        CONVMODE     => D2S_CONVMODE     ,
    	        TIME_WIND    => D2S_TIME_WIND    ,
    	        SEED         => D2S_SEED         ,
    	        DATA_COUNT   => D2S_DATA_COUNT   ,
    	        DATA_IN      => DATA_MUX_D2S_DATA_IN      ,
    	        DATA_IN_VLD  => DATA_MUX_D2S_DATA_IN_VLD  ,
    	        NEW_TIMESTEP => D2S_NEW_TIMESTEP ,
    	        SPIKE_OUT    => D2S_SPIKE_OUT    ,
    	        SPIKE_VLD    => D2S_SPIKE_VLD    ,
    	        CONV_DONE    => D2S_CONV_DONE    
    	    );

    D2S_NEW_TIMESTEP <= CORE_TIMESTEP_COMPLETED;
 
 EVENT_SINK_PROCESS : process(axim_data_aclk)
 
    begin
    
        if(rising_edge(axim_data_aclk)) then
        
            if(CORE_SP_RESET = '1') then
            
                MAIN_SPIKE_BUFFER_RDEN  <= '0';
                CIRCULAR_BUFFER_RDEN    <= '0';
                
            else
                        
                if CORE_READ_MAIN_SPIKE_BUFFER = '1' and MAIN_SPIKE_BUFFER_EMPTY = '0' then
            
                    MAIN_SPIKE_BUFFER_RDEN <= MAIN_SPIKE_BUFFER_RDEN xor CORE_EVENT_ACCEPT;
                    
                else
                
                    MAIN_SPIKE_BUFFER_RDEN <= '0';
                
                end if;

                
                 if CORE_READ_CIRCULAR_BUFFER = '1' and CIRCULAR_BUFFER_EMPTY = '0' then
            
                    CIRCULAR_BUFFER_RDEN <= CIRCULAR_BUFFER_RDEN xor CORE_EVENT_ACCEPT;
                    
                else
                
                    CIRCULAR_BUFFER_RDEN <= '0';
                
                end if;               
                
 
            end if;
        
        end if;
    
 end process EVENT_SINK_PROCESS;
 
 READFIFOSELECT(0) <= CORE_READ_MAIN_SPIKE_BUFFER;
 READFIFOSELECT(1) <= CORE_READ_CIRCULAR_BUFFER;
 

 CORE_SPIKEVECTOR_VLD_IN <= MAIN_SPIKE_BUFFER_RDEN when READFIFOSELECT = "01" else
                            CIRCULAR_BUFFER_RDEN   when READFIFOSELECT = "10" else
                            '0';
 CORE_SPIKEVECTOR_IN     <= MAIN_SPIKE_BUFFER_DOUT when READFIFOSELECT = "01" else 
                            CIRCULAR_BUFFER_DOUT   when READFIFOSELECT = "10" else 
                            (others=>'0');

 MAIN_SPIKE_BUFFER : xpm_fifo_async
   generic map (
      CASCADE_HEIGHT      => 0,            -- DECIMAL
      CDC_SYNC_STAGES     => 2,           -- DECIMAL
      DOUT_RESET_VALUE    => "0",        -- String
      ECC_MODE            => "no_ecc",  -- String
      EN_SIM_ASSERT_ERR   => "warning", -- String
      FIFO_MEMORY_TYPE    => "auto",     -- String
      FIFO_READ_LATENCY   => 1,         -- DECIMAL
      FIFO_WRITE_DEPTH    => 8192,       -- DECIMAL
      FULL_RESET_VALUE    => 0,          -- DECIMAL
      PROG_EMPTY_THRESH   => 10,        -- DECIMAL
      PROG_FULL_THRESH    => 10,         -- DECIMAL
      RD_DATA_COUNT_WIDTH => 1,                     -- DECIMAL
      READ_DATA_WIDTH     => CROSSBAR_MATRIX_DIMENSIONS,  -- DECIMAL
      READ_MODE           => "fwft",             -- String
      RELATED_CLOCKS      => 0,            -- DECIMAL
      SIM_ASSERT_CHK      => 0,            -- DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      USE_ADV_FEATURES    => "0000",     -- String
      WAKEUP_TIME         => 0,               -- DECIMAL
      WRITE_DATA_WIDTH    => CROSSBAR_MATRIX_DIMENSIONS,         -- DECIMAL
      WR_DATA_COUNT_WIDTH => 1        -- DECIMAL
   )
   port map (
      dout          => MAIN_SPIKE_BUFFER_DOUT     ,                                                        
      empty         => MAIN_SPIKE_BUFFER_EMPTY    ,                 
      full          => MAIN_SPIKE_BUFFER_FULL     ,                   
      din           => MAIN_SPIKE_BUFFER_DIN      ,                     
      injectdbiterr => '0'                        , 
      injectsbiterr => '0'                        , 
      rd_clk        => axim_data_aclk             ,               
      rd_en         => MAIN_SPIKE_BUFFER_RDEN     ,                 
      rst           => CONTROLS_FLUSH_MAIN_BUFFER ,                     
      sleep         => '0'                        ,                 
      wr_clk        => axim_data_aclk              ,               
      wr_en         => MAIN_SPIKE_BUFFER_WREN                  
   );

    MAIN_SPIKE_BUFFER_DIN <= D2S_SPIKE_OUT when CONTROLS_INPUT_SPIKE_MUX = '0' else
                            DATA_MUX_INPUT_SPIKE_BUFFER_DIN;

    MAIN_SPIKE_BUFFER_WREN <= D2S_SPIKE_VLD when CONTROLS_INPUT_SPIKE_MUX = '0' else
                            DATA_MUX_INPUT_SPIKE_BUFFER_WREN;

    DATA_MUX_INPUT_SPIKE_BUFFER_FULL <= '0' when CONTROLS_INPUT_SPIKE_MUX = '0' else
                            MAIN_SPIKE_BUFFER_FULL;

 CIRCULAR_SPIKE_BUFFER : xpm_fifo_async
   generic map (
      CASCADE_HEIGHT => 0,            -- DECIMAL
      CDC_SYNC_STAGES => 2,           -- DECIMAL
      DOUT_RESET_VALUE => "0",        -- String
      ECC_MODE => "no_ecc",           -- String
      EN_SIM_ASSERT_ERR => "warning", -- String
      FIFO_MEMORY_TYPE => "auto",     -- String
      FIFO_READ_LATENCY => 1,         -- DECIMAL
      FIFO_WRITE_DEPTH => 2048,       -- DECIMAL
      FULL_RESET_VALUE => 0,          -- DECIMAL
      PROG_EMPTY_THRESH => 10,        -- DECIMAL
      PROG_FULL_THRESH => 10,         -- DECIMAL
      RD_DATA_COUNT_WIDTH => 1,       -- DECIMAL
      READ_DATA_WIDTH => CROSSBAR_MATRIX_DIMENSIONS,          -- DECIMAL
      READ_MODE => "fwft",             -- String
      RELATED_CLOCKS => 0,            -- DECIMAL
      SIM_ASSERT_CHK => 0,            -- DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      USE_ADV_FEATURES => "0000",     -- String
      WAKEUP_TIME => 0,               -- DECIMAL
      WRITE_DATA_WIDTH => CROSSBAR_MATRIX_DIMENSIONS,         -- DECIMAL
      WR_DATA_COUNT_WIDTH => 1        -- DECIMAL
   )
   port map (
      dout          => CIRCULAR_BUFFER_DOUT    ,                                                        
      empty         => CIRCULAR_BUFFER_EMPTY   ,                 
      full          => CIRCULAR_BUFFER_FULL    ,                   
      din           => CIRCULAR_BUFFER_DIN     ,                     
      injectdbiterr => '0'                       , 
      injectsbiterr => '0'                       , 
      rd_clk        => axim_data_aclk                ,               
      rd_en         => CIRCULAR_BUFFER_RDEN    ,                 
      rst           => CONTROLS_FLUSH_CIRCULAR_BUFFER   ,                     
      sleep         => '0'                       ,                 
      wr_clk        => axim_data_aclk                ,               
      wr_en         => CIRCULAR_BUFFER_WREN                  
   );

    CIRCULAR_BUFFER_DIN  <= CORE_SPIKEVECTOR_OUT    ;
    CIRCULAR_BUFFER_WREN <= CORE_SPIKEVECTOR_VLD_OUT;


    GENERATE_NMC_SPIKE_LATCH : for k in 0 to CROSSBAR_MATRIX_DIMENSIONS-1 generate

        NMC_SPIKE_HOOK : process(axim_data_aclk)
 
        begin
        
            if(rising_edge(axim_data_aclk)) then
            
                if(CORE_SP_RESET = '1') then
                
                    SPIKE_STATE(k) <= LISTENING ;
                
                else
                
                    case SPIKE_STATE(k) is
                    
                        when LISTENING  =>
                        
                            if(CORE_NMC_SPIKE_OUT_VLD(k) = '1') then
                            
                                SPIKE_STATE(k)         <=  CATCHSPIKE;
                                
                            else

                                SPIKE_STATE(k)         <=  LISTENING;
                                
                            end if;
                        
                        when CATCHSPIKE =>
                        
                            NMC_SPIKE_OUT_LATCH(k) <=  CORE_NMC_SPIKE_OUT(k);
                            ALL_SPIKES_ARRIVED(k)  <=  '1';
             
                            if (SPIKE_SYNCHRONIZER = '0') then
                                SPIKE_STATE(k)         <=  CATCHSPIKE;
                            else
                                SPIKE_STATE(k)         <=  LISTENING;
                                NMC_SPIKE_OUT_LATCH(k) <=  '0';
                                ALL_SPIKES_ARRIVED(k)  <=  '0';
                           
                            end if;
                                                
                        when others =>
                             SPIKE_STATE(k)         <=  LISTENING;
                             
                     end case;
                                          
                end if;
            end if;
        
        end process NMC_SPIKE_HOOK;
  
    end generate GENERATE_NMC_SPIKE_LATCH;

    LATCH_DELAY : process(axim_data_aclk)
    
        begin
            
                if(rising_edge(axim_data_aclk)) then
                
                    if(CORE_SP_RESET = '1') then
                    
                        NMC_SPIKE_OUT_LATCH_DELAY <= (others=>'0');
                        
                    else   
                    
                        NMC_SPIKE_OUT_LATCH_DELAY <= NMC_SPIKE_OUT_LATCH;
                    
                    end if;
                    
                end if; 
    
    end process LATCH_DELAY;

    FIFO_WRCNTROLS : process(axim_data_aclk)
    
        begin
            
                if(rising_edge(axim_data_aclk)) then
                
                    if(CORE_SP_RESET = '1') then
                    
                        FIFOSTATE <= WAITINPUT;
                        FIFOWRITEDLY <= 0;
                        
                    else
                    
                        case FIFOSTATE is
                        
                            when WAITINPUT =>
                            
                                SPIKE_SYNCHRONIZER <= '0';
                                WRITESPIKES        <= '0';
                                FIFOWRITEDLY       <= 0;
                                
                                if(ALL_SPIKES_ARRIVED = ARRIVAL) then
                                    FIFOSTATE <= WRITE;
                                else
                                    FIFOSTATE <= WAITINPUT;
                                end if;
                            
                            when WRITE =>
                                
                                if(FIFOWRITEDLY = 0) then
                                
                                    SPIKE_SYNCHRONIZER <= '1';
                                    WRITESPIKES        <= '1';
                                    
                                    FIFOWRITEDLY <= FIFOWRITEDLY + 1;
                                
                                elsif(FIFOWRITEDLY = 1) then
                                
                                    SPIKE_SYNCHRONIZER <= '0';
                                    WRITESPIKES        <= '0';
                                    FIFOSTATE          <= WAITINPUT;
                                    FIFOWRITEDLY       <= 0;

                                end if;

                            when others    =>
                                 FIFOSTATE <= WAITINPUT;
                        end case;
                    
                    end if;
                    
                 end if;
                 
     end process FIFO_WRCNTROLS;

      OUT_SPIKE_BUFFER_DIN(CROSSBAR_MATRIX_DIMENSIONS-1 downto 0)  <= NMC_SPIKE_OUT_LATCH_DELAY;

      OUT_SPIKE_BUFFER_WREN <= CORE_NMC_WR_OUT_BUFFER and WRITESPIKES ;

    
OUT_SPIKE_BUFFER :  xpm_fifo_async
   generic map (
      CASCADE_HEIGHT => 0,            -- DECIMAL
      CDC_SYNC_STAGES => 2,           -- DECIMAL
      DOUT_RESET_VALUE => "0",        -- String
      ECC_MODE => "no_ecc",           -- String
      EN_SIM_ASSERT_ERR => "warning", -- String
      FIFO_MEMORY_TYPE => "auto",     -- String
      FIFO_READ_LATENCY => 1,         -- DECIMAL
      FIFO_WRITE_DEPTH => 1024,       -- DECIMAL
      FULL_RESET_VALUE => 0,          -- DECIMAL
      PROG_EMPTY_THRESH => 10,        -- DECIMAL
      PROG_FULL_THRESH => 10,         -- DECIMAL
      RD_DATA_COUNT_WIDTH => 1,       -- DECIMAL
      READ_DATA_WIDTH => CROSSBAR_MATRIX_DIMENSIONS,          -- DECIMAL
      READ_MODE => "fwft",             -- String
      RELATED_CLOCKS => 0,            -- DECIMAL
      SIM_ASSERT_CHK => 0,            -- DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      USE_ADV_FEATURES => "0000",     -- String
      WAKEUP_TIME => 0,               -- DECIMAL
      WRITE_DATA_WIDTH => CROSSBAR_MATRIX_DIMENSIONS,         -- DECIMAL
      WR_DATA_COUNT_WIDTH => 1        -- DECIMAL
   )
   port map (
      dout          => DATA_MUX_OUT_SPIKE_BUFFER_DOUT    ,                                                        
      empty         => DATA_MUX_OUT_SPIKE_BUFFER_EMPTY   ,                 
      full          => OUT_SPIKE_BUFFER_FULL    ,                   
      din           => OUT_SPIKE_BUFFER_DIN     ,                     
      injectdbiterr => '0'                       , 
      injectsbiterr => '0'                       , 
      rd_clk        => axim_data_aclk                ,               
      rd_en         => DATA_MUX_OUT_SPIKE_BUFFER_RDEN    ,                 
      rst           => CONTROLS_FLUSH_OUT_BUFFER   ,                     
      sleep         => '0'                       ,                 
      wr_clk        => axim_data_aclk              ,               
      wr_en         => OUT_SPIKE_BUFFER_WREN                  
   );

end arch_imp;
