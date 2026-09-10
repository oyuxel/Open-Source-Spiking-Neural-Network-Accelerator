package ossna_reg_pkg;

    localparam int unsigned AXI_ADDR_WIDTH = 32;
    localparam int unsigned AXI_DATA_WIDTH = 32;
    localparam int unsigned REG_STRIDE     = 4;

    localparam bit [AXI_ADDR_WIDTH-1:0] ADDR_TOTAL_PARAM_MEM      = 32'h00;
    localparam bit [AXI_ADDR_WIDTH-1:0] ADDR_TOTAL_SYN_MEM        = 32'h04;
    localparam bit [AXI_ADDR_WIDTH-1:0] ADDR_CROSSBAR_DIMS        = 32'h08;
    localparam bit [AXI_ADDR_WIDTH-1:0] ADDR_MAX_NEURONS          = 32'h0C;
    localparam bit [AXI_ADDR_WIDTH-1:0] ADDR_LEARN_LUT_DEPTH      = 32'h10;
    localparam bit [AXI_ADDR_WIDTH-1:0] ADDR_SPIKE_GEN_BUF_DEPTH  = 32'h14;

    localparam bit [AXI_ADDR_WIDTH-1:0] ADDR_DMA_CTRL             = 32'h18;
    localparam bit [AXI_ADDR_WIDTH-1:0] ADDR_SELECT_SLAVE         = 32'h1C;
    localparam bit [AXI_ADDR_WIDTH-1:0] ADDR_BYTE_PER_WORD        = 32'h20;
    localparam bit [AXI_ADDR_WIDTH-1:0] ADDR_TOTAL_BYTES          = 32'h24;
    localparam bit [AXI_ADDR_WIDTH-1:0] ADDR_TOTAL_WORDS          = 32'h28;
    localparam bit [AXI_ADDR_WIDTH-1:0] ADDR_BRAM_READ_DELAY      = 32'h2C;
    localparam bit [AXI_ADDR_WIDTH-1:0] ADDR_BRAM_BASEADDR        = 32'h30;
    localparam bit [AXI_ADDR_WIDTH-1:0] ADDR_DDR_BASEADDR         = 32'h34;
    localparam bit [AXI_ADDR_WIDTH-1:0] ADDR_DMA_STATUS           = 32'h38;

    localparam int DMA_RESET_SOFT_SHIFT         = 0;
    localparam bit [31:0] DMA_RESET_SOFT_MASK   = 32'h0000_0001;

    localparam int DMA_START_READ_SHIFT         = 1;
    localparam bit [31:0] DMA_START_READ_MASK   = 32'h0000_0002;

    localparam int DMA_START_WRITE_SHIFT        = 2;
    localparam bit [31:0] DMA_START_WRITE_MASK  = 32'h0000_0004;

    localparam int DMA_TARGET_SELECT_SHIFT      = 3;
    localparam bit [31:0] DMA_TARGET_SELECT_MASK= 32'h0000_0008;

    localparam int DMA_FIFO_TYPE_SHIFT          = 4;
    localparam bit [31:0] DMA_FIFO_TYPE_MASK    = 32'h0000_0010;

    localparam int DMA_STAT_READ_DONE_SHIFT     = 0;
    localparam bit [31:0] DMA_STAT_READ_DONE_MASK  = 32'h0000_0001;

    localparam int DMA_STAT_WRITE_DONE_SHIFT    = 1;
    localparam bit [31:0] DMA_STAT_WRITE_DONE_MASK = 32'h0000_0002;

    localparam int DMA_STAT_READ_ERR_SHIFT      = 2;
    localparam bit [31:0] DMA_STAT_READ_ERR_MASK   = 32'h0000_0004;

    localparam int DMA_STAT_WRITE_ERR_SHIFT     = 3;
    localparam bit [31:0] DMA_STAT_WRITE_ERR_MASK  = 32'h0000_0008;

    localparam bit [AXI_ADDR_WIDTH-1:0] ADDR_D2S_CTRL             = 32'h3C;
    localparam bit [AXI_ADDR_WIDTH-1:0] ADDR_CONVMODE             = 32'h3C;
    localparam bit [AXI_ADDR_WIDTH-1:0] ADDR_TIME_WIND            = 32'h40;
    localparam bit [AXI_ADDR_WIDTH-1:0] ADDR_SEED                 = 32'h44;
    localparam bit [AXI_ADDR_WIDTH-1:0] ADDR_DATA_COUNT           = 32'h48;
    localparam bit [AXI_ADDR_WIDTH-1:0] ADDR_CONV_STATUS          = 32'h4C;

    localparam int D2S_RESET_SHIFT              = 0;
    localparam bit [31:0] D2S_RESET_MASK        = 32'h0000_0001;

    localparam int CONVMODE_SHIFT               = 1;
    localparam bit [31:0] CONVMODE_MASK         = 32'h0000_0006;

    localparam int CONV_DONE_SHIFT              = 0;
    localparam bit [31:0] CONV_DONE_MASK        = 32'h0000_0001;

    localparam bit [AXI_ADDR_WIDTH-1:0] ADDR_NMC_XNEVER           = 32'h50;
    localparam bit [AXI_ADDR_WIDTH-1:0] ADDR_CORE_ROUTING_CFG     = 32'h54;
    localparam bit [AXI_ADDR_WIDTH-1:0] ADDR_NET_START_ADDR       = 32'h58;
    localparam bit [AXI_ADDR_WIDTH-1:0] ADDR_CORE_EXEC_CTRL       = 32'h5C;
    localparam bit [AXI_ADDR_WIDTH-1:0] ADDR_CORE_RESET_FLUSH     = 32'h60;
    localparam bit [AXI_ADDR_WIDTH-1:0] ADDR_CORE_STATUS          = 32'h64;

    localparam int NMC_XNEVER_BASE_SHIFT        = 0;
    localparam bit [31:0] NMC_XNEVER_BASE_MASK  = 32'h0000_03FF;

    localparam int NMC_XNEVER_HIGH_SHIFT        = 16;
    localparam bit [31:0] NMC_XNEVER_HIGH_MASK  = 32'h03FF_0000;

    localparam int SYNAPSE_ROUTE_SHIFT          = 0;
    localparam bit [31:0] SYNAPSE_ROUTE_MASK    = 32'h0000_0001;

    localparam int NMC_PMODE_SWITCH_SHIFT       = 1;
    localparam bit [31:0] NMC_PMODE_SWITCH_MASK = 32'h0000_0002;

    localparam int DIS_LEARN_ENGINES_SHIFT      = 0;
    localparam bit [31:0] DIS_LEARN_ENGINES_MASK= 32'h0000_0001;

    localparam int INPUT_SPIKE_MUX_SHIFT        = 1;
    localparam bit [31:0] INPUT_SPIKE_MUX_MASK  = 32'h0000_0002;

    localparam int TIMESTEP_STARTED_SHIFT       = 2;
    localparam bit [31:0] TIMESTEP_STARTED_MASK = 32'h0000_0004;

    localparam int SP_RESET_SHIFT               = 0;
    localparam bit [31:0] SP_RESET_MASK         = 32'h0000_0001;

    localparam int FLUSH_MAIN_BUF_SHIFT         = 1;
    localparam bit [31:0] FLUSH_MAIN_BUF_MASK   = 32'h0000_0002;

    localparam int FLUSH_AUX_BUF_SHIFT          = 2;
    localparam bit [31:0] FLUSH_AUX_BUF_MASK    = 32'h0000_0004;

    localparam int FLUSH_CIRC_BUF_SHIFT         = 3;
    localparam bit [31:0] FLUSH_CIRC_BUF_MASK   = 32'h0000_0008;

    localparam int FLUSH_OUT_BUF_SHIFT          = 4;
    localparam bit [31:0] FLUSH_OUT_BUF_MASK    = 32'h0000_0010;

    localparam int CORE_STAT_TIMESTEP_DONE_SHIFT= 0;
    localparam bit [31:0] CORE_STAT_TIMESTEP_DONE_MASK = 32'h0000_0001;

    localparam int CORE_STAT_MATH_ERR_SHIFT     = 1;
    localparam bit [31:0] CORE_STAT_MATH_ERR_MASK      = 32'h0000_0002;

    localparam int CORE_STAT_MEM_VIOL_SHIFT     = 2;
    localparam bit [31:0] CORE_STAT_MEM_VIOL_MASK      = 32'h0000_0004;

endpackage : ossna_reg_pkg