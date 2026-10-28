-- Needs at least VHDL 2008. This IP can not be synthesized with earlier VHDL versions.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.crossbar_utils.all;
use work.processor_utils.all;

entity OSSNA_CORE is
    Generic (
        NEURAL_MEMORY_DEPTH   : integer := 1024;
        SYNAPTIC_MEMORY_DEPTH : integer := 8192;
        ULEARN_LUT_DEPTH      : integer := 2048;
        CROSSBAR_DIMENSION    : integer := 16
    );
    Port ( 
            CLK                              : in  std_logic; 
            RST                              : in  std_logic;
            NETWORK_START_ADDRESS            : in  std_logic_vector(31 downto 0);
            GLOBAL_TIMESTEP_START            : in  std_logic;
            GLOBAL_TIMESTEP_COMPLETE         : out std_logic;
            SPIKE_VECTOR_IN                  : in  std_logic_vector(CROSSBAR_DIMENSION-1 downto 0); 
            SPIKE_VECTOR_VLD_IN              : in  std_logic;           
            SPIKE_VECTOR_OUT                 : out std_logic_vector(CROSSBAR_DIMENSION-1 downto 0); 
            SPIKE_VECTOR_VLD_OUT             : out std_logic;  
            EVENT_ACCEPTANCE                 : out std_logic;
            EVENT_DETECT                     : in  std_logic;
            READ_MAIN_SPIKE_BUFFER           : out std_logic;
            READ_CIRCULAR_BUFFER             : out std_logic;
            READ_AUX_BUFFER                  : out std_logic;
            WRITE_OUT_BUFFER                 : out std_logic;
            WRITE_AUX_BUFFER                 : out std_logic;
            SYNAPTIC_MEMORY_PORTA_EXT_ACCESS : in  std_logic_vector(0 to CROSSBAR_DIMENSION-1);
            SYNAPTIC_MEMORY_PORTA_ADDR       : in  SYNAPTICMEMADDR(0 to CROSSBAR_DIMENSION-1);
            SYNAPTIC_MEMORY_PORTA_DIN        : in  SYNAPTICMEMDATA(0 to CROSSBAR_DIMENSION-1);
            SYNAPTIC_MEMORY_PORTA_WREN       : in  std_logic_vector(0 to CROSSBAR_DIMENSION-1); 
            SYNAPTIC_MEMORY_PORTA_DOUT       : out SYNAPTICMEMDATA(0 to CROSSBAR_DIMENSION-1);
            NEURAL_MEMORY_PORTB_ADDR         : in  NEURALMEMADDR(0 to CROSSBAR_DIMENSION-1);
            NEURAL_MEMORY_PORTB_DIN          : in  NEURALMEMDATA(0 to CROSSBAR_DIMENSION-1);
            NEURAL_MEMORY_PORTB_WREN         : in  std_logic_vector(0 to CROSSBAR_DIMENSION-1); 
            NEURAL_MEMORY_PORTB_DOUT         : out NEURALMEMDATA(0 to CROSSBAR_DIMENSION-1);
            NMC_MEMORY_PORTA_EXT_ACCESS      : in  std_logic;
            NMC_MEMORY_PORTA_EN              : in  STD_LOGIC;
            NMC_MEMORY_PORTA_ADDR            : in  STD_LOGIC_VECTOR(9  DOWNTO 0);
            NMC_MEMORY_PORTA_DIN             : in  STD_LOGIC_VECTOR(15 DOWNTO 0);
            NMC_MEMORY_PORTA_WREN            : in  STD_LOGIC;
            ULEARN_LUT_PORTA_EN              : in  STD_LOGIC;
            ULEARN_LUT_PORTA_ADDR            : in  std_logic_vector(clogb2(ULEARN_LUT_DEPTH)-1 downto 0);
            ULEARN_LUT_PORTA_DIN             : in  STD_LOGIC_VECTOR(7 DOWNTO 0);
            ULEARN_LUT_PORTA_WREN            : in  STD_LOGIC;
            NMC_XNEVER_BASEADDR              : in  std_logic_vector(9 downto 0);
            NMC_XNEVER_HIGHADDR              : in  std_logic_vector(9 downto 0);
            NMC_SPIKE_OUT                    : out std_logic_vector(0 to CROSSBAR_DIMENSION-1);
            NMC_SPIKE_OUT_VLD                : out std_logic;
            NMC_MATH_ERROR                   : out std_logic;
            NMC_MEMORY_VIOLATION             : out std_logic
        );
end OSSNA_CORE;

architecture moth_to_a_flame of OSSNA_CORE is

    signal CC_BARRIER_SYNC_OUT : std_logic_vector(0 to CROSSBAR_DIMENSION-1);

    signal CC_GLOBAL_TIMESTEP_COMPLETE : std_logic_vector(0 to CROSSBAR_DIMENSION-1);

    signal CC_CORE_EVENT_ACCEPTANCE : std_logic_vector(0 to CROSSBAR_DIMENSION-1);
    signal CC_CORE_EVENT_DETECT     : std_logic_vector(0 to CROSSBAR_DIMENSION-1);

    signal CC_CORE_READ_MAIN_SPIKE_BUFFER : std_logic_vector(0 to CROSSBAR_DIMENSION-1);
    signal CC_CORE_READ_CIRCULAR_BUFFER : std_logic_vector(0 to CROSSBAR_DIMENSION-1);
    signal CC_CORE_READ_AUX_BUFFER : std_logic_vector(0 to CROSSBAR_DIMENSION-1);      

    signal CC_CORE_WRITE_OUT_BUFFER : std_logic_vector(0 to CROSSBAR_DIMENSION-1); 
    signal CC_CORE_WRITE_AUX_BUFFER : std_logic_vector(0 to CROSSBAR_DIMENSION-1); 

    signal CC_CROSSBAR_TRACE_UPDATING : std_logic_vector(0 to CROSSBAR_DIMENSION-1); 
    signal CC_CROSSBAR_DISABLE_COLUMN : std_logic_vector(0 to CROSSBAR_DIMENSION-1); 

    signal CC_CORE_SYNAPTIC_DATA_OUT        : SYNAPTIC_DATA(0 to CROSSBAR_DIMENSION-1);
    signal CC_CORE_SYNAPTIC_DATA_START_ADDR : SYNAPSE_ADDRESS(0 to CROSSBAR_DIMENSION-1);
    signal CC_CORE_SYNAPTIC_DATA_LOCK       : std_logic_vector(0 to CROSSBAR_DIMENSION-1); 
    signal CC_CORE_SYNAPTIC_DATA_IN         : SYNAPTIC_DATA(0 to CROSSBAR_DIMENSION-1);
    signal CC_CORE_SYNAPTIC_DATA_WRITE_ADDR : SYNAPSE_ADDRESS(0 to CROSSBAR_DIMENSION-1);
    signal CC_CORE_SYNAPTIC_DATA_WRITE_EN   : std_logic_vector(0 to CROSSBAR_DIMENSION-1);  
    signal CC_CORE_PARTIAL_CURRENT_IN       : SYNAPTIC_SUM(0 to CROSSBAR_DIMENSION-1); 
    signal CC_CORE_PARTIAL_CURRENT_IN_VLD   : std_logic_vector(0 to CROSSBAR_DIMENSION-1);  

    signal CC_CORE_NMC_SPIKE_OUT     : std_logic_vector(0 to CROSSBAR_DIMENSION-1); 
    signal CC_CORE_NMC_SPIKE_OUT_VLD : std_logic_vector(0 to CROSSBAR_DIMENSION-1); 
        
    signal CC_CORE_NMC_MATH_ERROR       : std_logic_vector(0 to CROSSBAR_DIMENSION-1); 
    signal CC_CORE_NMC_MEMORY_VIOLATION : std_logic_vector(0 to CROSSBAR_DIMENSION-1); 

    signal CB_CB_VECTOR_RST : std_logic_vector(0 to CROSSBAR_DIMENSION-1); 

    signal BARRIER : std_logic;

    signal GLOBAL_TIMESTEP_LOOP : std_logic;

    signal ALL_SPIKES_ARRIVED     : std_logic_vector(0 to CROSSBAR_DIMENSION-1 );

    type SSTATES is (LISTENING,CATCHSPIKE);
      
    type SPIKE_STATES is array (0 to CROSSBAR_DIMENSION-1) of SSTATES; 
      
    signal SPIKE_STATE : SPIKE_STATES;

    constant ARRIVAL : std_logic_vector(0 to CROSSBAR_DIMENSION-1 ) := (others=>'1');

    signal SPIKE_SYNCHRONIZER : std_logic;

    type FIFOSTATES is (WAITINPUT,WRITEFIFO,ARRIVAL_CLEAR);
    signal FIFOSTATE : FIFOSTATES;

    signal CC_CORE_NMC_SPIKE_OUT_LATCH: std_logic;
    
begin

    CC_INST : for i in 0 to CROSSBAR_DIMENSION-1 generate

    CC : entity work.COMPUTATIONAL_CORE
    Generic Map(
        NEURAL_MEMORY_DEPTH   => NEURAL_MEMORY_DEPTH   ,
        SYNAPTIC_MEMORY_DEPTH => SYNAPTIC_MEMORY_DEPTH ,
        ULEARN_LUT_DEPTH      => ULEARN_LUT_DEPTH      ,
        CROSSBAR_DIMENSION    => CROSSBAR_DIMENSION    
    )
    Port Map(  
        CORE_CLK                              => CLK , 
        CORE_RST                              => RST , 
        -- Barrier Synchronization I/O
        CORE_BARRIER_SYNC_IN                  => BARRIER,
        CORE_BARRIER_SYNC_OUT                 => CC_BARRIER_SYNC_OUT(i),
        -- Network Low Address
        CORE_NETWORK_LOW_ADDRESS              => NETWORK_START_ADDRESS(clogb2(NEURAL_MEMORY_DEPTH)-1 downto 0),
        -- Global Timestep Controls
        GLOBAL_TIMESTEP_START                 => GLOBAL_TIMESTEP_LOOP,
        GLOBAL_TIMESTEP_COMPLETE              => CC_GLOBAL_TIMESTEP_COMPLETE(i),
        -- Spike Source Event Controls
        CORE_EVENT_ACCEPTANCE                 => CC_CORE_EVENT_ACCEPTANCE(i),
        CORE_EVENT_DETECT                     => CC_CORE_EVENT_DETECT(i),
        -- Spike Source Routing
        CORE_READ_MAIN_SPIKE_BUFFER           => CC_CORE_READ_MAIN_SPIKE_BUFFER(i), 
        CORE_READ_CIRCULAR_BUFFER             => CC_CORE_READ_CIRCULAR_BUFFER(i), 
        CORE_READ_AUX_BUFFER                  => CC_CORE_READ_AUX_BUFFER(i), 
        -- Spike Destination Routing
        CORE_WRITE_OUT_BUFFER                 => CC_CORE_WRITE_OUT_BUFFER(i),
        CORE_WRITE_AUX_BUFFER                 => CC_CORE_WRITE_AUX_BUFFER(i),
        -- Computational Core Synaptic Memory Controls & External Access
        CORE_SYNAPTIC_MEMORY_PORTA_EXT_ACCESS => SYNAPTIC_MEMORY_PORTA_EXT_ACCESS(i),
        CORE_SYNAPTIC_MEMORY_PORTA_ADDR       => SYNAPTIC_MEMORY_PORTA_ADDR(i)(clogb2(SYNAPTIC_MEMORY_DEPTH)-1 downto 0),
        CORE_SYNAPTIC_MEMORY_PORTA_DIN        => SYNAPTIC_MEMORY_PORTA_DIN(i),
        CORE_SYNAPTIC_MEMORY_PORTA_WREN       => SYNAPTIC_MEMORY_PORTA_WREN(i),
        CORE_SYNAPTIC_MEMORY_PORTA_DOUT       => SYNAPTIC_MEMORY_PORTA_DOUT(i),
        -- Computational Core Neural Memory External Access
        CORE_NEURAL_MEMORY_PORTB_ADDR         => NEURAL_MEMORY_PORTB_ADDR(i)(clogb2(NEURAL_MEMORY_DEPTH)-1 downto 0),
        CORE_NEURAL_MEMORY_PORTB_DIN          => NEURAL_MEMORY_PORTB_DIN(i),
        CORE_NEURAL_MEMORY_PORTB_WREN         => NEURAL_MEMORY_PORTB_WREN(i),
        CORE_NEURAL_MEMORY_PORTB_DOUT         => NEURAL_MEMORY_PORTB_DOUT(i),
        -- Computational Core NMC Memory External Access
        CORE_NMC_MEMORY_PORTA_EXT_ACCESS      => NMC_MEMORY_PORTA_EXT_ACCESS,
        CORE_NMC_MEMORY_PORTA_EN              => NMC_MEMORY_PORTA_EN,
        CORE_NMC_MEMORY_PORTA_ADDR            => NMC_MEMORY_PORTA_ADDR,
        CORE_NMC_MEMORY_PORTA_DIN             => NMC_MEMORY_PORTA_DIN,
        CORE_NMC_MEMORY_PORTA_WREN            => NMC_MEMORY_PORTA_WREN,
        -- Computational Core ULEARN LUT External Access
        CORE_ULEARN_LUT_PORTA_EN              => ULEARN_LUT_PORTA_EN,
        CORE_ULEARN_LUT_PORTA_ADDR            => ULEARN_LUT_PORTA_ADDR,
        CORE_ULEARN_LUT_PORTA_DIN             => ULEARN_LUT_PORTA_DIN,
        CORE_ULEARN_LUT_PORTA_WREN            => ULEARN_LUT_PORTA_WREN,
        -- Computational Core Crossbar Fabric I/O & Controls
        CROSSBAR_TRACE_UPDATING               => CC_CROSSBAR_TRACE_UPDATING(i),
        CROSSBAR_DISABLE_COLUMN               => CC_CROSSBAR_DISABLE_COLUMN(i),
        CORE_SYNAPTIC_DATA_OUT                => CC_CORE_SYNAPTIC_DATA_OUT(i),
        CORE_SYNAPTIC_DATA_START_ADDR         => CC_CORE_SYNAPTIC_DATA_START_ADDR(i)(clogb2(SYNAPTIC_MEMORY_DEPTH)-1 downto 0),
        CORE_SYNAPTIC_DATA_LOCK               => CC_CORE_SYNAPTIC_DATA_LOCK(i),
        CORE_SYNAPTIC_DATA_IN                 => CC_CORE_SYNAPTIC_DATA_IN(i),
        CORE_SYNAPTIC_DATA_WRITE_ADDR         => CC_CORE_SYNAPTIC_DATA_WRITE_ADDR(i)(clogb2(SYNAPTIC_MEMORY_DEPTH)-1 downto 0),
        CORE_SYNAPTIC_DATA_WRITE_EN           => CC_CORE_SYNAPTIC_DATA_WRITE_EN(i),
        CORE_PARTIAL_CURRENT_IN               => CC_CORE_PARTIAL_CURRENT_IN(i),
        CORE_PARTIAL_CURRENT_IN_VLD           => CC_CORE_PARTIAL_CURRENT_IN_VLD(i),
        -- Computational Core NMC I/O 
        CORE_NMC_XNEVER_BASEADDR              => NMC_XNEVER_BASEADDR,
        CORE_NMC_XNEVER_HIGHADDR              => NMC_XNEVER_HIGHADDR,
        CORE_NMC_SPIKE_OUT                    => CC_CORE_NMC_SPIKE_OUT(i),     
        CORE_NMC_SPIKE_OUT_VLD                => CC_CORE_NMC_SPIKE_OUT_VLD(i),
        CORE_NMC_SPIKE_OUT_LATCH              => CC_CORE_NMC_SPIKE_OUT_LATCH,
        
        CORE_NMC_MATH_ERROR                   => CC_CORE_NMC_MATH_ERROR(i),        
        CORE_NMC_MEMORY_VIOLATION             => CC_CORE_NMC_MEMORY_VIOLATION(i)  
        );

        CC_CORE_SYNAPTIC_DATA_START_ADDR(i)(31 downto clogb2(SYNAPTIC_MEMORY_DEPTH)) <= (others=>'0');
        CB_CB_VECTOR_RST(i) <= RST;

        CC_CORE_EVENT_DETECT(i) <= EVENT_DETECT;

    end generate CC_INST;

    CB_INST : entity work.CROSSBAR_FABRIC
    Generic Map(
            ROW               => CROSSBAR_DIMENSION,
            COLUMN            => CROSSBAR_DIMENSION,
            SYNAPSE_MEM_DEPTH => SYNAPTIC_MEMORY_DEPTH 
            )
    Port Map(
            CB_CLK                   => CLK ,
            CB_VECTOR_RST            => CB_CB_VECTOR_RST,
            DISABLE_COLUMN           => CC_CROSSBAR_DISABLE_COLUMN,
            SPIKE_IN                 => SPIKE_VECTOR_IN,
            SPIKE_VLD                => SPIKE_VECTOR_VLD_IN,
            SPIKE_OUT                => SPIKE_VECTOR_OUT,
            SPIKE_OUT_VLD            => SPIKE_VECTOR_VLD_OUT,
            TRACE_UPDATING           => CC_CROSSBAR_TRACE_UPDATING,
            SYNAPTIC_DATA_IN         => CC_CORE_SYNAPTIC_DATA_OUT,
            SYNAPTIC_DATA_START_ADDR => CC_CORE_SYNAPTIC_DATA_START_ADDR,
            SYNAPTIC_DATA_LOCK       => CC_CORE_SYNAPTIC_DATA_LOCK,
            PARTIAL_CURRENT_OUT      => CC_CORE_PARTIAL_CURRENT_IN,
            PARTIAL_CURRENT_OUT_VLD  => CC_CORE_PARTIAL_CURRENT_IN_VLD,
            SYNAPTIC_DATA_OUT        => CC_CORE_SYNAPTIC_DATA_IN,
            SYNAPTIC_DATA_WRITE_ADDR => CC_CORE_SYNAPTIC_DATA_WRITE_ADDR,
            SYNAPTIC_DATA_WRITE_EN   => CC_CORE_SYNAPTIC_DATA_WRITE_EN
        );

     GENERATE_NMC_SPIKE_LATCH : for k in 0 to CROSSBAR_DIMENSION-1 generate

    NMC_SPIKE_HOOK : process(CLK)
        begin
            if(rising_edge(CLK)) then
                if(RST = '1') then
                    SPIKE_STATE(k) <= LISTENING ;
                else
                    case SPIKE_STATE(k) is
                        when LISTENING  =>
                            NMC_SPIKE_OUT(k) <= '0';
                            if(CC_CORE_NMC_SPIKE_OUT_VLD(k) = '1') then
                                SPIKE_STATE(k)         <=  CATCHSPIKE;
                            else
                                SPIKE_STATE(k)         <=  LISTENING;
                            end if;
                        when CATCHSPIKE =>
                            NMC_SPIKE_OUT(k) <=  CC_CORE_NMC_SPIKE_OUT(k);
                            ALL_SPIKES_ARRIVED(k)  <=  '1';
                            if (SPIKE_SYNCHRONIZER = '0') then
                                SPIKE_STATE(k)         <=  CATCHSPIKE;
                            else
                                SPIKE_STATE(k)         <=  LISTENING;
                                NMC_SPIKE_OUT(k) <=  '0';
                                ALL_SPIKES_ARRIVED(k)  <=  '0';
                            end if;                   
                        when others =>
                             SPIKE_STATE(k)         <=  LISTENING;    
                     end case;                        
                end if;
            end if;
        end process NMC_SPIKE_HOOK;
    end generate GENERATE_NMC_SPIKE_LATCH;

    FIFO_WRCNTROLS : process(CLK)
        begin
            if(rising_edge(CLK)) then
                if(RST = '1') then
                    FIFOSTATE <= WAITINPUT;
                else
                    case FIFOSTATE is
                        when WAITINPUT =>
                            SPIKE_SYNCHRONIZER <= '0';
                            NMC_SPIKE_OUT_VLD <= '0';
                            if(ALL_SPIKES_ARRIVED = ARRIVAL) then
                                FIFOSTATE <= WRITEFIFO;
                            else
                                FIFOSTATE <= WAITINPUT;
                            end if;
                        when WRITEFIFO => 
                            SPIKE_SYNCHRONIZER <= '1';
                            NMC_SPIKE_OUT_VLD  <= '1';
                            FIFOSTATE <= ARRIVAL_CLEAR;  
                        when ARRIVAL_CLEAR =>
                            SPIKE_SYNCHRONIZER <= '0';
                            NMC_SPIKE_OUT_VLD <= '0';
                            FIFOSTATE <= WAITINPUT; 
                        when others    =>
                            FIFOSTATE <= WAITINPUT;
                        end case;
                    end if;  
                end if;    
    end process FIFO_WRCNTROLS;

    EVENT_ACCEPTANCE <= and CC_CORE_EVENT_ACCEPTANCE;
    READ_MAIN_SPIKE_BUFFER <= and CC_CORE_READ_MAIN_SPIKE_BUFFER;
    READ_CIRCULAR_BUFFER <= and CC_CORE_READ_CIRCULAR_BUFFER; 
    READ_AUX_BUFFER <= and CC_CORE_READ_AUX_BUFFER;
    WRITE_OUT_BUFFER <= and CC_CORE_WRITE_OUT_BUFFER;
    WRITE_AUX_BUFFER <= and CC_CORE_WRITE_AUX_BUFFER;

    CC_CORE_NMC_SPIKE_OUT_LATCH <= and ALL_SPIKES_ARRIVED;

    BARRIER <= and CC_BARRIER_SYNC_OUT;

   -- GLOBAL_TIMESTEP_LOOP <= (and CC_GLOBAL_TIMESTEP_COMPLETE) or GLOBAL_TIMESTEP_START;

    GLOBAL_TIMESTEP_LOOP <= GLOBAL_TIMESTEP_START;
    GLOBAL_TIMESTEP_COMPLETE <= (and CC_GLOBAL_TIMESTEP_COMPLETE);

    NMC_MATH_ERROR <= or CC_CORE_NMC_MATH_ERROR       ; 
    NMC_MEMORY_VIOLATION    <= or CC_CORE_NMC_MEMORY_VIOLATION ; 

end moth_to_a_flame;
