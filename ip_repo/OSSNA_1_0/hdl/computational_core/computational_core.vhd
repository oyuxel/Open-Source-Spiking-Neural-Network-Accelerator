library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.crossbar_utils.all;
use work.processor_primitives.all;

entity COMPUTATIONAL_CORE is
    Generic (
        NEURAL_MEMORY_DEPTH   : integer := 1024;
        SYNAPTIC_MEMORY_DEPTH : integer := 8192;
        ULEARN_LUT_DEPTH      : integer := 2048;
        CROSSBAR_DIMENSION    : integer := 16
    );
    Port (  
        CORE_CLK                              : in  std_logic;
        CORE_RST                              : in  std_logic;
        -- Barrier Synchronization I/O
        CORE_BARRIER_SYNC_IN                  : in  std_logic;
        CORE_BARRIER_SYNC_OUT                 : out std_logic;
        -- Network Low Address
        CORE_NETWORK_LOW_ADDRESS              : in  std_logic_vector(clogb2(NEURAL_MEMORY_DEPTH)-1 downto 0);
        -- Global Timestep Controls
        GLOBAL_TIMESTEP_START                 : in  std_logic;
        GLOBAL_TIMESTEP_COMPLETE              : out std_logic;
        -- Spike Source Event Controls
        CORE_EVENT_ACCEPTANCE                 : out std_logic;
        CORE_EVENT_DETECT                     : in  std_logic;
        -- Spike Source Routing
        CORE_READ_MAIN_SPIKE_BUFFER           : out std_logic;
        CORE_READ_CIRCULAR_BUFFER             : out std_logic;
        CORE_READ_AUX_BUFFER                  : out std_logic;
        -- Spike Destination Routing
        CORE_WRITE_OUT_BUFFER                 : out std_logic;
        CORE_WRITE_AUX_BUFFER                 : out std_logic;
        -- Computational Core Synaptic Memory Controls & External Access
        CORE_SYNAPTIC_MEMORY_PORTA_EXT_ACCESS : in  std_logic;
        CORE_SYNAPTIC_MEMORY_PORTA_ADDR       : in  std_logic_vector(clogb2(SYNAPTIC_MEMORY_DEPTH)-1 downto 0);
        CORE_SYNAPTIC_MEMORY_PORTA_DIN        : in  std_logic_vector(15 downto 0);
        CORE_SYNAPTIC_MEMORY_PORTA_WREN       : in  std_logic;
        CORE_SYNAPTIC_MEMORY_PORTA_DOUT       : out std_logic_vector(15 downto 0);
        -- Computational Core Neural Memory External Access
        CORE_NEURAL_MEMORY_PORTB_ADDR         : in  std_logic_vector(clogb2(NEURAL_MEMORY_DEPTH)-1 downto 0);
        CORE_NEURAL_MEMORY_PORTB_DIN          : in  std_logic_vector(31 downto 0);
        CORE_NEURAL_MEMORY_PORTB_WREN         : in  std_logic;
        CORE_NEURAL_MEMORY_PORTB_DOUT         : out std_logic_vector(31 downto 0);
        -- Computational Core NMC Memory External Access
        CORE_NMC_MEMORY_PORTA_EXT_ACCESS      : in  std_logic;
        CORE_NMC_MEMORY_PORTA_EN              : in  STD_LOGIC;
        CORE_NMC_MEMORY_PORTA_ADDR            : in  STD_LOGIC_VECTOR(9  DOWNTO 0);
        CORE_NMC_MEMORY_PORTA_DIN             : in  STD_LOGIC_VECTOR(15 DOWNTO 0);
        CORE_NMC_MEMORY_PORTA_WREN            : in  STD_LOGIC;
        -- Computational Core ULEARN LUT External Access
        CORE_ULEARN_LUT_PORTA_EN              : in  STD_LOGIC;
        CORE_ULEARN_LUT_PORTA_ADDR            : in  std_logic_vector(clogb2(ULEARN_LUT_DEPTH)-1 downto 0);
        CORE_ULEARN_LUT_PORTA_DIN             : in  STD_LOGIC_VECTOR(7 DOWNTO 0);
        CORE_ULEARN_LUT_PORTA_WREN            : in  STD_LOGIC;
        -- Computational Core Crossbar Fabric I/O & Controls
        CROSSBAR_TRACE_UPDATING               : in  std_logic;
        CROSSBAR_DISABLE_COLUMN               : out std_logic;
        CORE_SYNAPTIC_DATA_OUT                : out std_logic_vector(15 downto 0);
        CORE_SYNAPTIC_DATA_START_ADDR         : out std_logic_vector(clogb2(SYNAPTIC_MEMORY_DEPTH)-1 downto 0);
        CORE_SYNAPTIC_DATA_LOCK               : out std_logic;
        CORE_SYNAPTIC_DATA_IN                 : in  std_logic_vector(15 downto 0);
        CORE_SYNAPTIC_DATA_WRITE_ADDR         : in  std_logic_vector(clogb2(SYNAPTIC_MEMORY_DEPTH)-1 downto 0);
        CORE_SYNAPTIC_DATA_WRITE_EN           : in  std_logic;
        CORE_PARTIAL_CURRENT_IN               : in  std_logic_vector(15 downto 0);
        CORE_PARTIAL_CURRENT_IN_VLD           : in  std_logic;
        -- Computational Core NMC I/O 
        CORE_NMC_XNEVER_BASEADDR              : in  std_logic_vector(9 downto 0);
        CORE_NMC_XNEVER_HIGHADDR              : in  std_logic_vector(9 downto 0);
        CORE_NMC_SPIKE_OUT                    : out std_logic;
        CORE_NMC_SPIKE_OUT_VLD                : out std_logic;
        CORE_NMC_SPIKE_OUT_LATCH              : in  std_logic;
        
        CORE_NMC_MATH_ERROR                   : out std_logic;
        CORE_NMC_MEMORY_VIOLATION             : out std_logic
        );
end COMPUTATIONAL_CORE;

architecture Behavioral of COMPUTATIONAL_CORE is

    signal SYNAPTIC_MEMORY_ADDRA : std_logic_vector((clogb2(SYNAPTIC_MEMORY_DEPTH)-1) downto 0);
    signal SYNAPTIC_MEMORY_ADDRB : std_logic_vector((clogb2(SYNAPTIC_MEMORY_DEPTH)-1) downto 0);
    signal SYNAPTIC_MEMORY_DINA  : std_logic_vector(16-1 downto 0);		            
    signal SYNAPTIC_MEMORY_DINB  : std_logic_vector(16-1 downto 0);		                                			        
    signal SYNAPTIC_MEMORY_WEA   : std_logic;                       			        
    signal SYNAPTIC_MEMORY_WEB   : std_logic;                       			        
    signal SYNAPTIC_MEMORY_DOUTA : std_logic_vector(16-1 downto 0);   			        
    
    signal BRIDGE_SYNAPTIC_MEM_RDADDR   : std_logic_vector(clogb2(SYNAPTIC_MEMORY_DEPTH)-1 downto 0);

    signal BRIDGE_NMC_STATE_RST              : std_logic;
    signal BRIDGE_NMC_FMAC_RST               : std_logic;
    signal BRIDGE_NMC_LAUNCH                 : std_logic;
    signal BRIDGE_CURRENT_SWITCH_CHANNEL     : std_logic;
    signal BRIDGE_CURRENT_RESET_CHANNEL      : std_logic;
    signal BRIDGE_CURRENT_CHANNEL_SWITCHED   : std_logic; 
    signal BRIDGE_CURRENT_RESOURCES_RELEASED : std_logic; 
 
    signal BRIDGE_NMODEL_LAST_SPIKE_TIME       : std_logic_vector(7 downto 0);
    signal BRIDGE_NMODEL_SYN_QFACTOR           : std_logic_vector(15 downto 0);
    signal BRIDGE_NMODEL_PF_LOW_ADDR           : std_logic_vector(9 downto 0);
    signal BRIDGE_NMODEL_REFRACTORY_DUR        : std_logic_vector(7 downto 0);
    signal BRIDGE_NMODEL_NEW_SPIKE_TIME        : std_logic_vector(7 downto 0);
    signal BRIDGE_NMODEL_NEW_REFRACTORY_DUR    : std_logic_vector(7 downto 0);

    signal BRIDGE_NMC_MEM_PORTA_EN             : std_logic;
    signal BRIDGE_NMC_MEM_PORTA_WEN            : std_logic;
    signal BRIDGE_NMC_MEM_PORTA_DIN            : std_logic_vector(15 downto 0);
    signal BRIDGE_NMC_MEM_PORTA_ADDR           : std_logic_vector(9 downto 0);
    
    signal NMC_MEM_PORTA_EN                    : std_logic;
    signal NMC_MEM_PORTA_WEN                   : std_logic;
    signal NMC_MEM_PORTA_DIN                   : std_logic_vector(15 downto 0);
    signal NMC_MEM_PORTA_ADDR                  : std_logic_vector(9 downto 0);

    signal NEURAL_MEMORY_RST                   : std_logic;

    signal BRIDGE_NMC_MEM_PORTB_EXT_ACCESS     : std_logic;
    signal BRIDGE_NMC_MEM_PORTB_ADDR           : std_logic_vector(9 downto 0);
    signal BRIDGE_NMC_MEM_PORTB_DOUT           : std_logic_vector(15 downto 0);

    signal BRIDGE_NEURAL_MEM_ADDRA             : std_logic_vector(clogb2(NEURAL_MEMORY_DEPTH)-1 downto 0);
    signal BRIDGE_NEURAL_MEM_WEA               : std_logic;
    signal BRIDGE_NEURAL_MEM_RSTA              : std_logic;
    signal BRIDGE_NEURAL_MEM_DOUTA             : std_logic_vector(31 downto 0);
    signal BRIDGE_NEURAL_MEM_DINA              : std_logic_vector(31 downto 0);

    signal BRIDGE_NMODEL_FINISHED              : std_logic;
    signal BRIDGE_SYNAPTIC_MEM_PORTA_MUX       : std_logic;
    signal BRIDGE_ULEARN_RST                   : std_logic;
    signal BRIDGE_ULEARN_CFG_WORD              : std_logic_vector(255 downto 0);
    signal BRIDGE_ULEARN_SYN_DIN_VLD           : std_logic;                    
    signal BRIDGE_ULEARN_SYNAPSE_START_ADDRESS : std_logic_vector((clogb2(SYNAPTIC_MEMORY_DEPTH)-1) downto 0);

    signal ULEARN_LUT_MEM_ADDRB                : std_logic_vector(clogb2(ULEARN_LUT_DEPTH)-1 downto 0);
    signal ULEARN_LUT_MEM_DOUTB                : std_logic_vector(7 downto 0);

    signal ULEARN_SYN_DIN_VLD                   : std_logic;                    
    signal ULEARN_SYNAPSE_START_ADDRESS         : std_logic_vector((clogb2(SYNAPTIC_MEMORY_DEPTH)-1) downto 0);  
    signal ULEARN_SYN_DATA_OUT                  : std_logic_vector(15 downto 0);
    signal ULEARN_SYN_DOUT_VLD                  : std_logic;                     
    signal ULEARN_SYNAPSE_WRITE_ADDRESS         : std_logic_vector((clogb2(SYNAPTIC_MEMORY_DEPTH)-1) downto 0);

begin

    CORE_SYNAPTIC_MEMORY_INSTANCE : AUTO_RAM_INSTANCE
    generic map(
        RAM_WIDTH       => 16 ,
        RAM_DEPTH       => SYNAPTIC_MEMORY_DEPTH ,
        RAM_PERFORMANCE => "LOW_LATENCY"
        )
    port map(
        addra  => SYNAPTIC_MEMORY_ADDRA ,
        addrb  => SYNAPTIC_MEMORY_ADDRB ,
        dina   => SYNAPTIC_MEMORY_DINA  ,
        dinb   => SYNAPTIC_MEMORY_DINB  ,
        clka   => CORE_CLK ,
        clkb   => CORE_CLK ,
        wea    => SYNAPTIC_MEMORY_WEA ,
        web    => SYNAPTIC_MEMORY_WEB ,
        ena    => '1' ,
        enb    => '1' ,
        rsta   => CORE_RST,                       			        
        rstb   => CORE_RST,                       			        
        regcea => '1' ,                       			        
        regceb => '1' ,                       			        
        douta  => SYNAPTIC_MEMORY_DOUTA ,
        doutb  => open 
        );

    -- Synaptic Memory External Access Multiplexer

    SYNAPTIC_MEMORY_ADDRA <=    CORE_SYNAPTIC_MEMORY_PORTA_ADDR when CORE_SYNAPTIC_MEMORY_PORTA_EXT_ACCESS = '1' else
                                BRIDGE_SYNAPTIC_MEM_RDADDR;
    SYNAPTIC_MEMORY_DINA  <=    CORE_SYNAPTIC_MEMORY_PORTA_DIN when CORE_SYNAPTIC_MEMORY_PORTA_EXT_ACCESS = '1' else 
                                (others=>'0');
    SYNAPTIC_MEMORY_WEA   <=    CORE_SYNAPTIC_MEMORY_PORTA_WREN when CORE_SYNAPTIC_MEMORY_PORTA_EXT_ACCESS = '1' else 
                                '0';

    CORE_SYNAPTIC_MEMORY_PORTA_DOUT  <= SYNAPTIC_MEMORY_DOUTA;
    CORE_SYNAPTIC_DATA_OUT           <= SYNAPTIC_MEMORY_DOUTA;

    -- Synaptic Memory Internal Multiplexer

    SYNAPTIC_MEMORY_ADDRB   <=  CORE_SYNAPTIC_DATA_WRITE_ADDR when BRIDGE_SYNAPTIC_MEM_PORTA_MUX = '0' else
                                ULEARN_SYNAPSE_WRITE_ADDRESS;
    
    SYNAPTIC_MEMORY_WEB     <=  CORE_SYNAPTIC_DATA_WRITE_EN when BRIDGE_SYNAPTIC_MEM_PORTA_MUX = '0' else
                                ULEARN_SYN_DOUT_VLD;

    SYNAPTIC_MEMORY_DINB    <=  CORE_SYNAPTIC_DATA_IN when BRIDGE_SYNAPTIC_MEM_PORTA_MUX = '0' else
                                ULEARN_SYN_DATA_OUT;

    NEURAL_MEMORY_RST       <= CORE_RST or BRIDGE_NEURAL_MEM_RSTA;

    CORE_NEURAL_MEMORY_INSTANCE : AUTO_RAM_INSTANCE
    generic map(
        RAM_WIDTH       => 32 ,
        RAM_DEPTH       => NEURAL_MEMORY_DEPTH ,
        RAM_PERFORMANCE => "LOW_LATENCY"
        )
    port map(
        addra  => BRIDGE_NEURAL_MEM_ADDRA ,
        addrb  => CORE_NEURAL_MEMORY_PORTB_ADDR ,
        dina   => BRIDGE_NEURAL_MEM_DINA  ,
        dinb   => CORE_NEURAL_MEMORY_PORTB_DIN  ,
        clka   => CORE_CLK ,
        clkb   => CORE_CLK ,
        wea    => BRIDGE_NEURAL_MEM_WEA ,
        web    => CORE_NEURAL_MEMORY_PORTB_WREN ,
        ena    => '1' ,
        enb    => '1' ,
        rsta   => NEURAL_MEMORY_RST ,                      			        
        rstb   => CORE_RST,                       			        
        regcea => '1' ,                       			        
        regceb => '1' ,                       			        
        douta  => BRIDGE_NEURAL_MEM_DOUTA ,
        doutb  => CORE_NEURAL_MEMORY_PORTB_DOUT 
        );

    CORE_BRIDGE_INSTANCE : BRIDGE
    Generic Map(
        NEURAL_MEM_DEPTH  => NEURAL_MEMORY_DEPTH ,
        SYNAPSE_MEM_DEPTH => SYNAPTIC_MEMORY_DEPTH ,
        ROW               => CROSSBAR_DIMENSION
    )
    Port Map(
        BRIDGE_CLK                   => CORE_CLK ,
        BRIDGE_RST                   => CORE_RST ,
        BARRIER_SYNC_IN              => CORE_BARRIER_SYNC_IN ,
        BARRIER_SYNC_OUT             => CORE_BARRIER_SYNC_OUT ,
        NETWORK_LOW_ADDRESS          => CORE_NETWORK_LOW_ADDRESS ,
        GT_START                     => GLOBAL_TIMESTEP_START ,
        GT_COMPLETED                 => GLOBAL_TIMESTEP_COMPLETE ,
        EVENT_ACCEPTANCE             => CORE_EVENT_ACCEPTANCE ,
        EVENT_DETECT                 => CORE_EVENT_DETECT ,
 
        READ_MAIN_SPIKE_BUFFER       => CORE_READ_MAIN_SPIKE_BUFFER ,
        READ_CIRCULAR_BUFFER         => CORE_READ_CIRCULAR_BUFFER ,
        READ_AUX_BUFFER              => CORE_READ_AUX_BUFFER ,
        WRITE_OUTBUFFER              => CORE_WRITE_OUT_BUFFER ,
        WRITE_AUXBUFFER              => CORE_WRITE_AUX_BUFFER ,
 
        SYNAPTIC_MEM_RDADDR          => BRIDGE_SYNAPTIC_MEM_RDADDR   ,
        SYNAPTIC_MEM_WRADDR          => CORE_SYNAPTIC_DATA_START_ADDR   ,
 
        SYNAPTIC_DATA_LOCK           => CORE_SYNAPTIC_DATA_LOCK ,
        DISABLE_COLUMN               => CROSSBAR_DISABLE_COLUMN ,
        TRACE_UPDATING               => CROSSBAR_TRACE_UPDATING ,
 
        NMC_STATE_RST                => BRIDGE_NMC_STATE_RST              ,
        NMC_FMAC_RST                 => BRIDGE_NMC_FMAC_RST               ,
        NMC_LAUNCH                   => BRIDGE_NMC_LAUNCH                 ,
        CURRENT_SWITCH_CHANNEL       => BRIDGE_CURRENT_SWITCH_CHANNEL     ,
        CURRENT_RESET_CHANNEL        => BRIDGE_CURRENT_RESET_CHANNEL      ,
        CURRENT_CHANNEL_SWITCHED     => BRIDGE_CURRENT_CHANNEL_SWITCHED   , 
        CURRENT_RESOURCES_RELEASED   => BRIDGE_CURRENT_RESOURCES_RELEASED , 
 
        NMODEL_LAST_SPIKE_TIME       => BRIDGE_NMODEL_LAST_SPIKE_TIME      ,
        NMODEL_SYN_QFACTOR           => BRIDGE_NMODEL_SYN_QFACTOR          ,
        NMODEL_PF_LOW_ADDR           => BRIDGE_NMODEL_PF_LOW_ADDR          ,
        NMODEL_REFRACTORY_DUR        => BRIDGE_NMODEL_REFRACTORY_DUR       ,
        NMODEL_NEW_SPIKE_TIME        => BRIDGE_NMODEL_NEW_SPIKE_TIME       ,
        NMODEL_NEW_REFRACTORY_DUR    => BRIDGE_NMODEL_NEW_REFRACTORY_DUR   ,

        NMC_MEM_PORTA_EN             => BRIDGE_NMC_MEM_PORTA_EN             ,
        NMC_MEM_PORTA_WEN            => BRIDGE_NMC_MEM_PORTA_WEN            ,
        NMC_MEM_PORTA_DIN            => BRIDGE_NMC_MEM_PORTA_DIN            ,
        NMC_MEM_PORTA_ADDR           => BRIDGE_NMC_MEM_PORTA_ADDR           ,
        NMC_MEM_PORTB_EXT_ACCESS     => BRIDGE_NMC_MEM_PORTB_EXT_ACCESS     ,
        NMC_MEM_PORTB_ADDR           => BRIDGE_NMC_MEM_PORTB_ADDR           ,
        NMC_MEM_PORTB_DOUT           => BRIDGE_NMC_MEM_PORTB_DOUT           ,

        NMODEL_FINISHED              => BRIDGE_NMODEL_FINISHED ,
        NMC_OUTPUT_SPIKES_LATCH      => CORE_NMC_SPIKE_OUT_LATCH  ,

        SYNAPTIC_MEM_PORTA_MUX       => BRIDGE_SYNAPTIC_MEM_PORTA_MUX       ,
        ULEARN_RST                   => BRIDGE_ULEARN_RST                   ,
        ULEARN_CFG_WORD              => BRIDGE_ULEARN_CFG_WORD              ,
        ULEARN_SYN_DIN_VLD           => BRIDGE_ULEARN_SYN_DIN_VLD           ,
        ULEARN_SYNAPSE_START_ADDRESS => BRIDGE_ULEARN_SYNAPSE_START_ADDRESS , 

        PARAMETER_MEM_ADDRA          => BRIDGE_NEURAL_MEM_ADDRA ,
        PARAMETER_MEM_WEA            => BRIDGE_NEURAL_MEM_WEA   ,
        PARAMETER_MEM_RSTA           => BRIDGE_NEURAL_MEM_RSTA  ,
        PARAMETER_MEM_DOUTA          => BRIDGE_NEURAL_MEM_DOUTA ,
        PARAMETER_MEM_DINA           => BRIDGE_NEURAL_MEM_DINA  
    );
    
    NMC_MEM_PORTA_EN   <= CORE_NMC_MEMORY_PORTA_EN when CORE_NMC_MEMORY_PORTA_EXT_ACCESS = '1' else
                          BRIDGE_NMC_MEM_PORTA_EN;

    NMC_MEM_PORTA_WEN  <= CORE_NMC_MEMORY_PORTA_WREN when CORE_NMC_MEMORY_PORTA_EXT_ACCESS = '1' else
                          BRIDGE_NMC_MEM_PORTA_WEN;

    NMC_MEM_PORTA_DIN  <= CORE_NMC_MEMORY_PORTA_DIN when CORE_NMC_MEMORY_PORTA_EXT_ACCESS = '1' else     
                          BRIDGE_NMC_MEM_PORTA_DIN;

    NMC_MEM_PORTA_ADDR <= CORE_NMC_MEMORY_PORTA_ADDR when CORE_NMC_MEMORY_PORTA_EXT_ACCESS = '1' else
                          BRIDGE_NMC_MEM_PORTA_ADDR;

    CORE_NMC_INSTANCE : NMC
    Port Map( 
            NMC_CLK                    => CORE_CLK ,
            NMC_STATE_RST              => BRIDGE_NMC_STATE_RST              ,
            FMAC_EXTERNAL_RST          => BRIDGE_NMC_FMAC_RST               ,
            NMC_HARD_RST               => CORE_RST ,
            NMC_LAUNCH                 => BRIDGE_NMC_LAUNCH                 ,
            PARTIAL_CURRENT_IN         => CORE_PARTIAL_CURRENT_IN , 
            PARTIAL_CURRENT_VLD        => CORE_PARTIAL_CURRENT_IN_VLD ,
            CURRENT_SWITCH_CHANNEL     => BRIDGE_CURRENT_SWITCH_CHANNEL     , 
            CURRENT_RESET_CHANNEL      => BRIDGE_CURRENT_RESET_CHANNEL      , 
            CURRENT_CHANNEL_SWITCHED   => BRIDGE_CURRENT_CHANNEL_SWITCHED   , 
            CURRENT_RESOURCES_RELEASED => BRIDGE_CURRENT_RESOURCES_RELEASED ,
            NMC_XNEVER_REGION_BASEADDR => CORE_NMC_XNEVER_BASEADDR ,
            NMC_XNEVER_REGION_HIGHADDR => CORE_NMC_XNEVER_HIGHADDR ,
            NMODEL_LAST_SPIKE_TIME     => BRIDGE_NMODEL_LAST_SPIKE_TIME      ,
            NMODEL_SYN_QFACTOR         => BRIDGE_NMODEL_SYN_QFACTOR          ,
            NMODEL_PF_LOW_ADDR         => BRIDGE_NMODEL_PF_LOW_ADDR          ,
            NMODEL_REFRACTORY_DUR      => BRIDGE_NMODEL_REFRACTORY_DUR       ,
            NMODEL_NEW_SPIKE_TIME      => BRIDGE_NMODEL_NEW_SPIKE_TIME       ,
            NMODEL_NEW_REFRACTORY_DUR  => BRIDGE_NMODEL_NEW_REFRACTORY_DUR   ,
            NMODEL_SPIKE_OUT           => CORE_NMC_SPIKE_OUT ,
            NMODEL_SPIKE_OUT_VLD       => CORE_NMC_SPIKE_OUT_VLD ,
            NMC_MEM_PORTA_EN           => NMC_MEM_PORTA_EN             ,
            NMC_MEM_PORTA_WEN          => NMC_MEM_PORTA_WEN            ,
            NMC_MEM_PORTA_DIN          => NMC_MEM_PORTA_DIN            ,
            NMC_MEM_PORTA_ADDR         => NMC_MEM_PORTA_ADDR           ,
            NMC_MEM_PORTB_EXT_ACCESS   => BRIDGE_NMC_MEM_PORTB_EXT_ACCESS     ,
            NMC_MEM_PORTB_ADDR         => BRIDGE_NMC_MEM_PORTB_ADDR           ,
            NMC_MEM_PORTB_DOUT         => BRIDGE_NMC_MEM_PORTB_DOUT           ,
            NMODEL_FINISHED            => BRIDGE_NMODEL_FINISHED ,
            NMC_MATH_ERROR             => CORE_NMC_MATH_ERROR ,
            NMC_MEMORY_VIOLATION       => CORE_NMC_MEMORY_VIOLATION
    );

    CORE_ULEARN_LUT_INSTANCE : AUTO_RAM_INSTANCE
    generic map(
        RAM_WIDTH       => 8 ,
        RAM_DEPTH       => ULEARN_LUT_DEPTH ,
        RAM_PERFORMANCE => "LOW_LATENCY"
        )
    port map(
        addra  => CORE_ULEARN_LUT_PORTA_ADDR ,
        addrb  => ULEARN_LUT_MEM_ADDRB ,
        dina   => CORE_ULEARN_LUT_PORTA_DIN  ,
        dinb   => (others=>'0') ,
        clka   => CORE_CLK ,
        clkb   => CORE_CLK ,
        wea    => CORE_ULEARN_LUT_PORTA_WREN ,
        web    => '0' ,
        ena    => CORE_ULEARN_LUT_PORTA_EN ,
        enb    => '1' ,
        rsta   => CORE_RST,                       			        
        rstb   => CORE_RST,                       			        
        regcea => '1' ,                       			        
        regceb => '1' ,                       			        
        douta  => open ,
        doutb  => ULEARN_LUT_MEM_DOUTB 
        );

    CORE_ULEARN_INSTANCE : ULEARN
    Generic Map(
            LUT_DEPTH          => ULEARN_LUT_DEPTH     ,
            SYNAPSE_MEM_DEPTH  => SYNAPTIC_MEMORY_DEPTH        
            )
    Port Map
        ( 
        CLK                    => CORE_CLK ,
        RST                    => CORE_RST, 
        CFG_WORD               => BRIDGE_ULEARN_CFG_WORD ,
        NMODEL_SPIKE_TIME      => BRIDGE_NMODEL_NEW_SPIKE_TIME    ,  
        SYN_DATA_IN            => SYNAPTIC_MEMORY_DOUTA            ,
        SYN_DIN_VLD            => BRIDGE_ULEARN_SYN_DIN_VLD       ,
        SYNAPSE_START_ADDRESS  => BRIDGE_ULEARN_SYNAPSE_START_ADDRESS  , 
        SYN_DATA_OUT           => ULEARN_SYN_DATA_OUT           ,
        SYN_DOUT_VLD           => ULEARN_SYN_DOUT_VLD           ,
        SYNAPSE_WRITE_ADDRESS  => ULEARN_SYNAPSE_WRITE_ADDRESS  ,
        LUT_ADDR               => ULEARN_LUT_MEM_ADDRB ,
        LUT_DOUT               => ULEARN_LUT_MEM_DOUTB 
        );

end Behavioral;
