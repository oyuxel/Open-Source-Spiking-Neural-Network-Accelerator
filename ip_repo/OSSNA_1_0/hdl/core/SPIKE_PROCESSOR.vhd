-- Needs at least VHDL 2008. This IP can not be synthesized with earlier VHDL versions

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.crossbar_utils.all;
use work.processor_primitives.all;
use work.processor_utils.all;


entity SPIKE_PROCESSOR is
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
            -- NETWORK START ADDRESS
            NETWORK_START_ADDRESS       : in  std_logic_vector(31 downto 0);
            TIMESTEP_STARTED            : in  std_logic;
            TIMESTEP_COMPLETED          : out std_logic;
            DISABLE_LEARNING_ENGINES    : in  std_logic;
            -- SPIKE_BUFFERS CONTROL (MAIN OR AUX)
            SPIKEVECTOR_IN              : in  std_logic_vector(CROSSBAR_ROW_WIDTH-1 downto 0); 
            SPIKEVECTOR_VLD_IN          : in  std_logic;           
            SPIKEVECTOR_OUT             : out std_logic_vector(CROSSBAR_ROW_WIDTH-1 downto 0); 
            SPIKEVECTOR_VLD_OUT         : out std_logic;                     
            READ_MAIN_SPIKE_BUFFER      : out std_logic;
            READ_CIRCULAR_BUFFER        : out std_logic;
            READ_AUX_BUFFER             : out std_logic;
            -- EVENT ACCEPTANCE
            EVENT_ACCEPT                : out std_logic;
            -- SYNAPSE RECYCLE OR EXTERNAL ACCESS
            SYNAPSE_ROUTE               : in  std_logic; -- 00: Recycle, 01: In, 10: Out
            -- SYNAPSE MEMORY INTERFACE SELECTION
            SYNAPTIC_MEM_DIN            : in  SYNAPTICMEMDATA(0 to CROSSBAR_COL_WIDTH-1);
            SYNAPTIC_MEM_DADDR          : in  SYNAPTICMEMADDR(0 to CROSSBAR_COL_WIDTH-1);
            SYNAPTIC_MEM_EN             : in  std_logic_vector(0 to CROSSBAR_COL_WIDTH-1);
            SYNAPTIC_MEM_WREN           : in  std_logic_vector(0 to CROSSBAR_COL_WIDTH-1);
            SYNAPTIC_MEM_DOUT           : out SYNAPTICMEMDATA(0 to CROSSBAR_COL_WIDTH-1);
            -- NMC MEMORY BOUNDARY REGISTERS
            NMC_XNEVER_BASE             : in  std_logic_vector(9 downto 0);
            NMC_XNEVER_HIGH             : in  std_logic_vector(9 downto 0);
            -- NMC PROGRAMMING INTERFACE TIED TO ALL NMC UNITS
            NMC_PMODE_SWITCH            : in  std_logic;  -- 0 : NMC Memory ports are tied to Neural Memory Ports, 1 : NMC Memory External Access
            NMC_NPARAM_DATA             : in  STD_LOGIC_VECTOR(15 DOWNTO 0);
            NMC_NPARAM_ADDR             : in  STD_LOGIC_VECTOR(9  DOWNTO 0);
            NMC_PROG_MEM_PORTA_EN       : in  std_logic;
            NMC_PROG_MEM_PORTA_WEN      : in  std_logic;
            -- SPIKE OUTPUTS
            NMC_SPIKE_OUT               : out std_logic_vector(0 to CROSSBAR_COL_WIDTH-1 );
            NMC_SPIKE_OUT_VLD           : out std_logic_vector(0 to CROSSBAR_COL_WIDTH-1 );
            NMC_WR_OUT_BUFFER           : out std_logic;
            NMC_WR_AUX_BUFFER           : out std_logic;
             -- ULEARN LUT TIED TO ALL LEARNING ENGINES
            LEARN_LUT_DIN               : in  std_logic_vector(7 downto 0);
            LEARN_LUT_ADDR              : in  std_logic_vector(clogb2(LEARNING_ENGINE_LUT_DEPTH)-1 downto 0)   ;
            LEARN_LUT_EN                : in  std_logic;
            -- PARAMETER MEMORY INTERFACE SELECTION
            PARAM_MEM_DIN               : in  PARAMMEMDATA(0 to CROSSBAR_COL_WIDTH-1);
            PARAM_MEM_DADDR             : in  PARAMMEMADDR(0 to CROSSBAR_COL_WIDTH-1);
            PARAM_MEM_EN                : in  std_logic_vector(0 to CROSSBAR_COL_WIDTH-1); 
            PARAM_MEM_WREN              : in  std_logic_vector(0 to CROSSBAR_COL_WIDTH-1); 
            PARAM_MEM_DOUT              : out PARAMMEMDATA(0 to CROSSBAR_COL_WIDTH-1);
            -- ERROR FLAGS
            NMC_MATH_ERROR_VEC          : out std_logic; 
            NMC_MEM_VIOLATION_VEC       : out std_logic
            
          );
end SPIKE_PROCESSOR;

architecture restless_and_wild of SPIKE_PROCESSOR is

    signal COLUMN_PRE_SYNAPTIC_DIN           : SYNAPTIC_DATA(0 to CROSSBAR_COL_WIDTH-1);
    signal COLUMN_PRE_SYN_DATA_PULL          : std_logic_vector(0 to CROSSBAR_COL_WIDTH-1);
    signal COLUMN_SYN_SUM_OUT                : SYNAPTIC_SUM(0 to CROSSBAR_COL_WIDTH-1);
    signal COLUMN_VECTOR_SYN_SUM_VALID       : std_logic_vector(0 to CROSSBAR_COL_WIDTH-1);
    signal COLUMN_POST_SYNAPTIC_DOUT         : SYNAPTIC_DATA(0 to CROSSBAR_COL_WIDTH-1);
    signal COLUMN_SYNAPSE_WRITE_ADDRESS      : SYNAPSE_ADDRESS(0 to CROSSBAR_COL_WIDTH-1);
    signal COLUMN_POST_SYNAPTIC_WREN         : std_logic_vector(0 to CROSSBAR_COL_WIDTH-1);
    signal CROSSBAR_VECTOR_RESET             : std_logic_vector(0 to CROSSBAR_COL_WIDTH-1);

    signal SYNAPTIC_MEMORY_ADDRA             : SYNAPSE_ADDRESS(0 to CROSSBAR_COL_WIDTH-1);    
    signal SYNAPTIC_MEMORY_ADDRB             : SYNAPSE_ADDRESS(0 to CROSSBAR_COL_WIDTH-1);       
    signal SYNAPTIC_MEMORY_DINA              : SYNAPTIC_DATA(0 to CROSSBAR_COL_WIDTH-1);	       
    signal SYNAPTIC_MEMORY_WEA               : std_logic_vector(0 to CROSSBAR_COL_WIDTH-1);                       			        
    signal SYNAPTIC_MEMORY_ENA               : std_logic_vector(0 to CROSSBAR_COL_WIDTH-1);                       			        
    signal SYNAPTIC_MEMORY_ENB               : std_logic_vector(0 to CROSSBAR_COL_WIDTH-1);                       			        
    signal SYNAPTIC_MEMORY_DOUTA             : SYNAPTIC_DATA(0 to CROSSBAR_COL_WIDTH-1);  			 
    signal SYNAPTIC_MEMORY_DOUTB             : SYNAPTIC_DATA(0 to CROSSBAR_COL_WIDTH-1); 

    signal SYNAPTIC_MEM_DIN_MUX              : SYNAPTICMEMDATA(0 to CROSSBAR_COL_WIDTH-1);
    signal SYNAPTIC_MEM_ADDR_MUX             : SYNAPTICMEMADDR(0 to CROSSBAR_COL_WIDTH-1);
    signal SYNAPTIC_MEM_EN_MUX               : std_logic_vector(0 to CROSSBAR_COL_WIDTH-1);            
    signal SYNAPTIC_MEM_WREN_MUX             : std_logic_vector(0 to CROSSBAR_COL_WIDTH-1); 

    signal BRIDGE_2_SYNAPTIC_MEM_ADDR        : SYNAPSE_ADDRESS(0 to CROSSBAR_COL_WIDTH-1);       
    signal BRIDGE_2_SYNAPTIC_MEM_EN          : std_logic_vector(0 to CROSSBAR_COL_WIDTH-1);    

    signal BRIDGE_SYNAPTIC_MEMORY_MUX        : std_logic_vector(0 to CROSSBAR_COL_WIDTH-1);       

    signal ULEARN_SYN_DOUT                   : SYNAPTICMEMDATA(0 to CROSSBAR_COL_WIDTH-1);

    signal CROSSBAR_SYNMEM_WRADDR            : SYNAPSE_ADDRESS(0 to CROSSBAR_COL_WIDTH-1);       
    signal ULEARN_SYNMEM_WRADDR              : SYNAPSE_ADDRESS(0 to CROSSBAR_COL_WIDTH-1);       

    signal ULEARN_SYN_DOUT_VLD               : std_logic_vector(0 to CROSSBAR_COL_WIDTH-1);  
    
    signal BRIDGE_2_PARAM_MEM_ADDR           : PARAMMEMADDR(0 to CROSSBAR_COL_WIDTH-1);       
    signal BRIDGE_2_PARAM_MEM_EN             : std_logic_vector(0 to CROSSBAR_COL_WIDTH-1);   
    signal BRIDGE_2_PARAM_MEM_WREN           : std_logic_vector(0 to CROSSBAR_COL_WIDTH-1); 
    signal BRIDGE_2_PARAM_MEM_DIN            : PARAMMEMDATA(0 to CROSSBAR_COL_WIDTH-1);       
    signal BRIDGE_2_PARAM_MEM_DOUT           : PARAMMEMDATA(0 to CROSSBAR_COL_WIDTH-1);      
    signal BRIDGE_2_PARAM_MEM_RST            : std_logic_vector(0 to CROSSBAR_COL_WIDTH-1); 
    
    signal BRIDGE_EVENT_ACCEPT               : std_logic_vector(0 to CROSSBAR_COL_WIDTH-1);
    signal BRIDGE_READ_MAIN_SPIKE_BUFFER     : std_logic_vector(0 to CROSSBAR_COL_WIDTH-1);
    signal BRIDGE_READ_CIRCULAR_BUFFER       : std_logic_vector(0 to CROSSBAR_COL_WIDTH-1);
    signal BRIDGE_READ_AUX_BUFFER            : std_logic_vector(0 to CROSSBAR_COL_WIDTH-1);

    signal BRIDGE_WRITE_OUTBUFFER            : std_logic_vector(0 to CROSSBAR_COL_WIDTH-1);
    signal BRIDGE_WRITE_AUXBUFFER            : std_logic_vector(0 to CROSSBAR_COL_WIDTH-1);

    signal BRIDGE_HALT_CROSSBAR              : std_logic_vector(0 to CROSSBAR_COL_WIDTH-1);

    signal BRIDGE_NMC_STATE_RST              : std_logic_vector(0 to CROSSBAR_COL_WIDTH-1); 
    signal BRIDGE_NMC_FMAC_RST               : std_logic_vector(0 to CROSSBAR_COL_WIDTH-1); 
    signal BRIDGE_NMC_COLD_START             : std_logic_vector(0 to CROSSBAR_COL_WIDTH-1); 
    signal BRIDGE_NMODEL_LAST_SPIKE_TIME     : LASTSTIME       (0 to CROSSBAR_COL_WIDTH-1); 
    signal BRIDGE_NMODEL_SYN_QFACTOR         : SYNQFACTOR      (0 to CROSSBAR_COL_WIDTH-1); 
    signal BRIDGE_NMODEL_PF_LOW_ADDR         : PROGRAMFLOWLOW  (0 to CROSSBAR_COL_WIDTH-1); 
    signal BRIDGE_NMODEL_NPARAM_DATA         : NPARAMDATA      (0 to CROSSBAR_COL_WIDTH-1);
    signal BRIDGE_NMODEL_NPARAM_ADDR         : NPARAMADDR      (0 to CROSSBAR_COL_WIDTH-1);
    signal BRIDGE_NMODEL_REFRACTORY_DUR      : REFDURATION     (0 to CROSSBAR_COL_WIDTH-1);
    signal BRIDGE_NMODEL_PROG_MEM_PORTA_EN   : std_logic_vector(0 to CROSSBAR_COL_WIDTH-1); 
    signal BRIDGE_NMODEL_PROG_MEM_PORTA_WEN  : std_logic_vector(0 to CROSSBAR_COL_WIDTH-1); 

    signal BRIDGE_R_NNMODEL_NEW_SPIKE_TIME   : LASTSTIME  (0 to CROSSBAR_COL_WIDTH-1); 
    signal BRIDGE_R_NMODEL_NPARAM_DATAOUT    : NPARAMDATA (0 to CROSSBAR_COL_WIDTH-1);
    signal BRIDGE_R_NMODEL_REFRACTORY_DUR    : REFDURATION(0 to CROSSBAR_COL_WIDTH-1);
    signal BRIDGE_REDIST_NMODEL_PORTB_TKOVER : std_logic_vector(0 to CROSSBAR_COL_WIDTH-1);
    signal BRIDGE_REDIST_NMODEL_DADDR        : NPARAMADDR      (0 to CROSSBAR_COL_WIDTH-1);
    signal BRIDGE_NMC_NMODEL_FINISHED        : std_logic_vector(0 to CROSSBAR_COL_WIDTH-1);
    
    signal ULEARN_ACTVATE_LENGINE            : std_logic_vector(0 to CROSSBAR_COL_WIDTH-1);
    signal ULEARN_LEARN_RST                  : std_logic_vector(0 to CROSSBAR_COL_WIDTH-1);
    signal ULEARN_SYNAPSE_PRUN               : std_logic_vector(0 to CROSSBAR_COL_WIDTH-1);
    signal ULEARN_PRUN_THRESH                : LASTSTIME(0 to CROSSBAR_COL_WIDTH-1);
    signal ULEARN_IGNORE_ZEROS               : std_logic_vector(0 to CROSSBAR_COL_WIDTH-1); 
    signal ULEARN_IGNORE_SOFTLIM             : std_logic_vector(0 to CROSSBAR_COL_WIDTH-1);  
    signal ULEARN_NEURON_WMAX                : LASTSTIME(0 to CROSSBAR_COL_WIDTH-1);
    signal ULEARN_NEURON_WMIN                : LASTSTIME(0 to CROSSBAR_COL_WIDTH-1);
    signal ULEARN_NEURON_SPK_TIME            : LASTSTIME(0 to CROSSBAR_COL_WIDTH-1);
    signal ULEARN_LUT_LOW_ADDRESS            : LEARNLUTLOW(0 to CROSSBAR_COL_WIDTH-1);
    signal ULEARN_LEARNING_RATE              : LASTSTIME(0 to CROSSBAR_COL_WIDTH-1);
    
    signal NMC_NMODEL_NPARAM_DATA            : NPARAMDATA      (0 to CROSSBAR_COL_WIDTH-1);
    signal NMC_NMODEL_NPARAM_ADDR            : NPARAMADDR      (0 to CROSSBAR_COL_WIDTH-1);
    signal NMC_NMODEL_PROG_MEM_PORTA_EN      : std_logic_vector(0 to CROSSBAR_COL_WIDTH-1); 
    signal NMC_NMODEL_PROG_MEM_PORTA_WEN     : std_logic_vector(0 to CROSSBAR_COL_WIDTH-1); 
    
    signal TIMESTEP_COMPLETED_VEC            : std_logic_vector(0 to CROSSBAR_COL_WIDTH-1); 
    signal BRIDGE_DISABLE_COLUMN             : std_logic_vector(0 to CROSSBAR_COL_WIDTH-1); 

    signal UNIFIED_TIMESTEP_STARTED          : std_logic;
    signal TIMESTEP_COMPLETED_REG            : std_logic;

    signal NMC_MATH_ERROR_VECTOR             : std_logic_vector(0 to CROSSBAR_COL_WIDTH-1); 
    signal NMC_MEM_VIOLATION_VECTOR          : std_logic_vector(0 to CROSSBAR_COL_WIDTH-1);

begin

CROSSBAR_VECTOR_RST_GEN : for i in 0 to CROSSBAR_COL_WIDTH-1 generate

    CROSSBAR_VECTOR_RESET(i) <= BRIDGE_HALT_CROSSBAR(i) or TIMESTEP_STARTED;

end generate CROSSBAR_VECTOR_RST_GEN;


    UNIFIED_TIMESTEP_STARTED <= TIMESTEP_STARTED or TIMESTEP_COMPLETED_REG;

    TIMESTEP_COMPLETED <= TIMESTEP_COMPLETED_REG;

CROSSBAR: CROSSBAR_FABRIC 
    Generic Map(
            ROW                             => CROSSBAR_ROW_WIDTH           ,
            COLUMN                          => CROSSBAR_COL_WIDTH           ,
            SYNAPSE_MEM_DEPTH               => SYNAPSE_MEM_DEPTH
            )
    Port Map(
            CB_CLK                          => SP_CLOCK,
            CB_VECTOR_RST                   => CROSSBAR_VECTOR_RESET,
            COLUMN_DISABLE_VECTOR           => BRIDGE_DISABLE_COLUMN   ,
            SPIKE_IN                        => SPIKEVECTOR_IN               ,   
            SPIKE_VLD                       => SPIKEVECTOR_VLD_IN           ,   
            SPIKE_OUT                       => SPIKEVECTOR_OUT              ,
            SPIKE_OUT_VLD                   => SPIKEVECTOR_VLD_OUT          ,
            COLUMN_PRE_SYNAPTIC_DIN         => COLUMN_PRE_SYNAPTIC_DIN      ,
            COLUMN_SYNAPSE_START_ADDRESS    => COLUMN_SYNAPSE_WRITE_ADDRESS ,
            PRE_SYN_DATA_PULL               => COLUMN_PRE_SYN_DATA_PULL     ,
            COLN_SYN_SUM_OUT                => COLUMN_SYN_SUM_OUT           ,
            COLN_VECTOR_SYN_SUM_VALID       => COLUMN_VECTOR_SYN_SUM_VALID  ,
            COLUMN_POST_SYNAPTIC_DOUT       => COLUMN_POST_SYNAPTIC_DOUT    ,
            COLUMN_SYNAPSE_WR_ADDRESS       => CROSSBAR_SYNMEM_WRADDR       ,
            COLUMN_POST_SYNAPTIC_WREN       => COLUMN_POST_SYNAPTIC_WREN    
        );

SYNAPTIC_MEMORY: for i in 0 to CROSSBAR_COL_WIDTH-1 generate

    MEM: AUTO_RAM_INSTANCE
    Generic Map(
                RAM_WIDTH       => 16                 ,
                RAM_DEPTH       => SYNAPSE_MEM_DEPTH  ,      
                RAM_PERFORMANCE => "LOW_LATENCY"      
                )
    Port Map(
                addra  => SYNAPTIC_MEMORY_ADDRA(i)(clogb2(SYNAPSE_MEM_DEPTH)-1 downto 0)    ,
                addrb  => SYNAPTIC_MEMORY_ADDRB(i)(clogb2(SYNAPSE_MEM_DEPTH)-1 downto 0)   ,
                dina   => SYNAPTIC_MEMORY_DINA(i)     ,
                dinb   => (others=>'0')               ,
                clka   => SP_CLOCK                    ,                      			       
                clkb   => SP_CLOCK                    ,                      			       
                wea    => SYNAPTIC_MEMORY_WEA(i)      ,
                web    => '0'                           ,
                ena    => SYNAPTIC_MEMORY_ENA(i)      ,
                enb    => SYNAPTIC_MEMORY_ENB(i)      ,
                rsta   => UNIFIED_TIMESTEP_STARTED            ,            
                rstb   => UNIFIED_TIMESTEP_STARTED            ,            
                regcea => '0'                         ,
                regceb => '0'                         ,
                douta  => SYNAPTIC_MEMORY_DOUTA(i)    ,
                doutb  => SYNAPTIC_MEMORY_DOUTB(i)
            );

end generate SYNAPTIC_MEMORY;


SYNAPSE_MEMORY_ROUTING : for i in 0 to CROSSBAR_COL_WIDTH-1 generate
        
    MEMORY_ROUTING : process(SP_CLOCK)
    
            begin
                      
                if(rising_edge(SP_CLOCK)) then

                        if(SYNAPSE_ROUTE = '0') then
                        
                            SYNAPTIC_MEMORY_ADDRA(i)(clogb2(SYNAPSE_MEM_DEPTH)-1 downto 0)   <= SYNAPTIC_MEM_ADDR_MUX(i)(clogb2(SYNAPSE_MEM_DEPTH)-1 downto 0);
                            SYNAPTIC_MEMORY_DINA(i)    <= SYNAPTIC_MEM_DIN_MUX(i) ;
                            SYNAPTIC_MEMORY_WEA(i)     <= SYNAPTIC_MEM_WREN_MUX(i);
                            SYNAPTIC_MEMORY_ENA(i)     <= SYNAPTIC_MEM_EN_MUX(i)  ; 
             
                            COLUMN_PRE_SYNAPTIC_DIN(i) <= SYNAPTIC_MEMORY_DOUTB(i); 
                            
                            SYNAPTIC_MEMORY_ADDRB(i)(clogb2(SYNAPSE_MEM_DEPTH)-1 downto 0)   <= BRIDGE_2_SYNAPTIC_MEM_ADDR(i)(clogb2(SYNAPSE_MEM_DEPTH)-1 downto 0);
                            SYNAPTIC_MEMORY_ENB(i)     <= BRIDGE_2_SYNAPTIC_MEM_EN(i); 
     
                        else
                        
                            SYNAPTIC_MEMORY_ADDRA(i)(clogb2(SYNAPSE_MEM_DEPTH)-1 downto 0) <= SYNAPTIC_MEM_DADDR(i)(clogb2(SYNAPSE_MEM_DEPTH)-1 downto 0);
                            SYNAPTIC_MEMORY_DINA(i)  <= SYNAPTIC_MEM_DIN(i);
                            SYNAPTIC_MEMORY_WEA(i)   <= SYNAPTIC_MEM_WREN(i);
                            SYNAPTIC_MEMORY_ENA(i)   <= SYNAPTIC_MEM_EN(i);           
               
                        end if;
                        
                end if;
                            
    end process MEMORY_ROUTING;

end generate SYNAPSE_MEMORY_ROUTING;

NMC_MEMORY_MULTIPLEXER : for i in 0 to CROSSBAR_COL_WIDTH-1 generate

    NMC_EXTERNAL_ACCESS :  process(SP_CLOCK)
    
                        begin
                            
                            if(rising_edge(SP_CLOCK)) then
    
                               if(NMC_PMODE_SWITCH = '0') then
                               
                               
                                    NMC_NMODEL_NPARAM_DATA(i)          <= BRIDGE_NMODEL_NPARAM_DATA(i)          ;
                                    NMC_NMODEL_NPARAM_ADDR(i)          <= BRIDGE_NMODEL_NPARAM_ADDR(i)          ;
                                    NMC_NMODEL_PROG_MEM_PORTA_EN(i)    <= BRIDGE_NMODEL_PROG_MEM_PORTA_EN(i)    ;
                                    NMC_NMODEL_PROG_MEM_PORTA_WEN(i)   <= BRIDGE_NMODEL_PROG_MEM_PORTA_WEN(i)   ;

                               
                               else

                                    
                                    NMC_NMODEL_NPARAM_DATA(i)         <= NMC_NPARAM_DATA           ;
                                    NMC_NMODEL_NPARAM_ADDR(i)         <= NMC_NPARAM_ADDR           ;
                                    NMC_NMODEL_PROG_MEM_PORTA_EN(i)   <= NMC_PROG_MEM_PORTA_EN  ;
                                    NMC_NMODEL_PROG_MEM_PORTA_WEN(i)  <= NMC_PROG_MEM_PORTA_WEN ;
                    
                               end if;
                               
                             end if;
    
    end process NMC_EXTERNAL_ACCESS;
    
end generate NMC_MEMORY_MULTIPLEXER;

SYNAPTIC_MEMORY_MULTIPLEXER : for i in 0 to CROSSBAR_COL_WIDTH-1 generate
  
        SYNAPTIC_MEM_DIN_MUX(i)  <= COLUMN_POST_SYNAPTIC_DOUT(i)   when BRIDGE_SYNAPTIC_MEMORY_MUX(i) = '0' else
                                    ULEARN_SYN_DOUT(i);
                                   
        SYNAPTIC_MEM_ADDR_MUX(i) <= CROSSBAR_SYNMEM_WRADDR(i)    when BRIDGE_SYNAPTIC_MEMORY_MUX(i) = '0' else
                                    ULEARN_SYNMEM_WRADDR(i);                       
          
        SYNAPTIC_MEM_WREN_MUX(i) <= COLUMN_POST_SYNAPTIC_WREN(i) when BRIDGE_SYNAPTIC_MEMORY_MUX(i) = '0' else
                                    ULEARN_SYN_DOUT_VLD(i);
                                    
        SYNAPTIC_MEM_EN_MUX(i)   <= '1';
        
        SYNAPTIC_MEM_DOUT(i)     <= SYNAPTIC_MEMORY_DOUTA(i);

        
 end generate SYNAPTIC_MEMORY_MULTIPLEXER;
   

PARAMETER_MEMORY : for i in 0 to CROSSBAR_COL_WIDTH-1 generate
           			     
    NEURAL_MEMORY: AUTO_RAM_INSTANCE 
    generic map (
        RAM_WIDTH       => 32,                
        RAM_DEPTH       => NEURAL_MEM_DEPTH, 
        RAM_PERFORMANCE => "LOW_LATENCY"   
        )
    port map(
            addra  => BRIDGE_2_PARAM_MEM_ADDR(i)(clogb2(NEURAL_MEM_DEPTH)-1 downto 0) ,
            addrb  => PARAM_MEM_DADDR(i)(clogb2(NEURAL_MEM_DEPTH)-1 downto 0)         ,
            dina   => BRIDGE_2_PARAM_MEM_DIN(i)  ,
            dinb   => PARAM_MEM_DIN(i)           ,
            clka   => SP_CLOCK                   ,  
            clkb   => PARAMETER_MEM_RDCLK        ,
            wea    => BRIDGE_2_PARAM_MEM_WREN(i) ,
            web    => PARAM_MEM_WREN(i)          ,
            ena    => BRIDGE_2_PARAM_MEM_EN(i)   ,
            enb    => PARAM_MEM_EN(i)            ,
            rsta   => UNIFIED_TIMESTEP_STARTED           , 
            rstb   => SP_RESET                   ,
            regcea => '0'                        ,
            regceb => '0'                        ,
            douta  => BRIDGE_2_PARAM_MEM_DOUT(i) ,
            doutb  => PARAM_MEM_DOUT(i)     
        );

end generate PARAMETER_MEMORY;

    EVENT_ACCEPT           <= and BRIDGE_EVENT_ACCEPT;
    READ_MAIN_SPIKE_BUFFER <= and BRIDGE_READ_MAIN_SPIKE_BUFFER; 
    READ_CIRCULAR_BUFFER   <= and BRIDGE_READ_CIRCULAR_BUFFER; 
    READ_AUX_BUFFER        <= and BRIDGE_READ_AUX_BUFFER; 
    NMC_WR_OUT_BUFFER      <= and BRIDGE_WRITE_OUTBUFFER; 
    
    TIMESTEP_COMPLETED_REG <= and TIMESTEP_COMPLETED_VEC; 

    NMC_MATH_ERROR_VEC     <= or NMC_MATH_ERROR_VECTOR;
    NMC_MEM_VIOLATION_VEC  <= or NMC_MEM_VIOLATION_VECTOR;

                
BRIDGES : for i in 0 to CROSSBAR_COL_WIDTH-1 generate
    
    NMC_BRIDGE: BRIDGE
        Generic Map (
            NEURAL_MEM_DEPTH  => NEURAL_MEM_DEPTH,    
            SYNAPSE_MEM_DEPTH => SYNAPSE_MEM_DEPTH,    
            ROW               => CROSSBAR_ROW_WIDTH           
            )
        Port Map(
            BRIDGE_CLK                 => SP_CLOCK                              ,
            BRIDGE_RST                 => SP_RESET                              ,
            NETWORK_LOW_ADDRESS        => NETWORK_START_ADDRESS((clogb2(NEURAL_MEM_DEPTH)-1) downto 0), 
            GT_START                   => UNIFIED_TIMESTEP_STARTED                     ,
            GT_COMPLETED               => TIMESTEP_COMPLETED_VEC(i)               ,
            SKIP_LEARNING_PROCESS      => DISABLE_LEARNING_ENGINES              ,
            EVENT_DETECT               => SPIKEVECTOR_VLD_IN                    ,
            
            EVENT_ACCEPTANCE           => BRIDGE_EVENT_ACCEPT(i)                ,
        
            READ_MAIN_SPIKE_BUFFER     => BRIDGE_READ_MAIN_SPIKE_BUFFER(i)         ,
            READ_CIRCULAR_BUFFER       =>  BRIDGE_READ_CIRCULAR_BUFFER(i)           ,
            WRITE_OUTBUFFER            => BRIDGE_WRITE_OUTBUFFER(i)                ,

            SYNAPTIC_MEM_RDADDR        => BRIDGE_2_SYNAPTIC_MEM_ADDR(i)(clogb2(SYNAPSE_MEM_DEPTH)-1 downto 0)         ,
            SYNAPTIC_MEM_ENABLE        => BRIDGE_2_SYNAPTIC_MEM_EN(i)           ,
            
            SYNAPTIC_MEM_WRADDR        => COLUMN_SYNAPSE_WRITE_ADDRESS(i)(clogb2(SYNAPSE_MEM_DEPTH)-1 downto 0)          ,
            HALT_HYPERCOLUMN           => BRIDGE_HALT_CROSSBAR(i)               ,
            PRE_SYN_DATA_PULL          => COLUMN_PRE_SYN_DATA_PULL(i)           ,
            DISABLE_COLUMN             => BRIDGE_DISABLE_COLUMN(i)             ,
            
            NMC_STATE_RST              => BRIDGE_NMC_STATE_RST(i)               ,
            NMC_FMAC_RST               => BRIDGE_NMC_FMAC_RST(i)                ,
            NMC_COLD_START             => BRIDGE_NMC_COLD_START(i)              ,
            NMODEL_LAST_SPIKE_TIME     => BRIDGE_NMODEL_LAST_SPIKE_TIME(i)      ,
            NMODEL_SYN_QFACTOR         => BRIDGE_NMODEL_SYN_QFACTOR(i)          ,
            NMODEL_PF_LOW_ADDR         => BRIDGE_NMODEL_PF_LOW_ADDR(i)          ,
            NMODEL_NPARAM_DATA         => BRIDGE_NMODEL_NPARAM_DATA(i)          ,
            NMODEL_NPARAM_ADDR         => BRIDGE_NMODEL_NPARAM_ADDR(i)          ,
            NMODEL_REFRACTORY_DUR      => BRIDGE_NMODEL_REFRACTORY_DUR(i)       ,
            NMODEL_PROG_MEM_PORTA_EN   => BRIDGE_NMODEL_PROG_MEM_PORTA_EN(i)    ,
            NMODEL_PROG_MEM_PORTA_WEN  => BRIDGE_NMODEL_PROG_MEM_PORTA_WEN(i)   ,
            R_NNMODEL_NEW_SPIKE_TIME   => BRIDGE_R_NNMODEL_NEW_SPIKE_TIME(i)    ,
            R_NMODEL_NPARAM_DATAOUT    => BRIDGE_R_NMODEL_NPARAM_DATAOUT(i)     ,
            R_NMODEL_REFRACTORY_DUR    => BRIDGE_R_NMODEL_REFRACTORY_DUR(i)     ,
            REDIST_NMODEL_PORTB_TKOVER => BRIDGE_REDIST_NMODEL_PORTB_TKOVER(i)  ,
            REDIST_NMODEL_DADDR        => BRIDGE_REDIST_NMODEL_DADDR(i)         ,
            NMC_NMODEL_FINISHED        => BRIDGE_NMC_NMODEL_FINISHED(i)         ,
            SYNMEM_PORTA_MUX           => BRIDGE_SYNAPTIC_MEMORY_MUX(i)         ,
            ACTVATE_LENGINE            => ULEARN_ACTVATE_LENGINE(i)             ,
            LEARN_RST                  => ULEARN_LEARN_RST(i)                   ,
            SYNAPSE_PRUN               => ULEARN_SYNAPSE_PRUN(i)                ,
            PRUN_THRESH                => ULEARN_PRUN_THRESH(i)                 ,
            IGNORE_ZEROS               => ULEARN_IGNORE_ZEROS(i)                ,
            IGNORE_SOFTLIM             => ULEARN_IGNORE_SOFTLIM(i)              ,
            LEARNING_RATE              => ULEARN_LEARNING_RATE(i)               ,
            TABLE_LOW_ADDRESS          => ULEARN_LUT_LOW_ADDRESS(i)             ,
            NEURON_WMAX                => ULEARN_NEURON_WMAX(i)                 ,
            NEURON_WMIN                => ULEARN_NEURON_WMIN(i)                 ,
            NEURON_SPK_TIME            => ULEARN_NEURON_SPK_TIME(i)             ,
            addra                      => BRIDGE_2_PARAM_MEM_ADDR(i)(clogb2(NEURAL_MEM_DEPTH)-1 downto 0)            ,  
            wea                        => BRIDGE_2_PARAM_MEM_WREN(i)            ,  
            ena                        => BRIDGE_2_PARAM_MEM_EN(i)              ,  
            rsta                       => BRIDGE_2_PARAM_MEM_RST(i)             ,  
            douta                      => BRIDGE_2_PARAM_MEM_DOUT(i)            ,  
            dina                       => BRIDGE_2_PARAM_MEM_DIN(i)              
            );                                                                   
                                                                                 
end generate BRIDGES;

NEURON_MODEL_CALCULATOR : for i in 0 to CROSSBAR_COL_WIDTH-1 generate
        
    NMC_UNIT : NMC 
        Port Map( 
                NMC_CLK                     => SP_CLOCK                             ,
                NMC_STATE_RST               => BRIDGE_NMC_STATE_RST(i)              ,
                FMAC_EXTERN_RST             => BRIDGE_NMC_FMAC_RST(i)               ,
                NMC_HARD_RST                => SP_RESET                             ,
                NMC_COLD_START              => BRIDGE_NMC_COLD_START(i)             ,
                PARTIAL_CURRENT_RDY         => COLUMN_VECTOR_SYN_SUM_VALID(i)       ,
                NMC_XNEVER_REGION_BASEADDR  => NMC_XNEVER_BASE                      ,
                NMC_XNEVER_REGION_HIGHADDR  => NMC_XNEVER_HIGH                      ,
                NMODEL_LAST_SPIKE_TIME      => BRIDGE_NMODEL_LAST_SPIKE_TIME(i)     ,
                NMODEL_SYN_QFACTOR          => BRIDGE_NMODEL_SYN_QFACTOR(i)         ,
                NMODEL_PF_LOW_ADDR          => BRIDGE_NMODEL_PF_LOW_ADDR(i)         ,
                NMODEL_NPARAM_DATA          => NMC_NMODEL_NPARAM_DATA(i)            ,
                NMODEL_NPARAM_ADDR          => NMC_NMODEL_NPARAM_ADDR(i)            ,
                NMODEL_REFRACTORY_DUR       => BRIDGE_NMODEL_REFRACTORY_DUR(i)      ,
                NMODEL_PROG_MEM_PORTA_EN    => NMC_NMODEL_PROG_MEM_PORTA_EN(i)      ,
                NMODEL_PROG_MEM_PORTA_WEN   => NMC_NMODEL_PROG_MEM_PORTA_WEN(i)     ,
                NMC_NMODEL_PSUM_IN          => COLUMN_SYN_SUM_OUT(i)                ,
                NMC_NMODEL_SPIKE_OUT        => NMC_SPIKE_OUT(i)                     ,
                NMC_NMODEL_SPIKE_VLD        => NMC_SPIKE_OUT_VLD(i)                 ,
                R_NNMODEL_NEW_SPIKE_TIME    => BRIDGE_R_NNMODEL_NEW_SPIKE_TIME(i)   ,
                R_NMODEL_NPARAM_DATAOUT     => BRIDGE_R_NMODEL_NPARAM_DATAOUT(i)    ,
                R_NMODEL_REFRACTORY_DUR     => BRIDGE_R_NMODEL_REFRACTORY_DUR(i)    ,
                REDIST_NMODEL_PORTB_TKOVER  => BRIDGE_REDIST_NMODEL_PORTB_TKOVER(i) ,
                REDIST_NMODEL_DADDR         => BRIDGE_REDIST_NMODEL_DADDR(i)        ,
                NMC_NMODEL_FINISHED         => BRIDGE_NMC_NMODEL_FINISHED(i)        ,
                NMC_MATH_ERROR              => NMC_MATH_ERROR_VECTOR(i)             ,
                NMC_MEMORY_VIOLATION        => NMC_MEM_VIOLATION_VECTOR(i)       
        );        

end generate NEURON_MODEL_CALCULATOR;


LEARNING_ENGINE : for i in 0 to CROSSBAR_COL_WIDTH-1 generate
        
    ULEARN : ULEARN_SINGLE
        Generic Map(
                LUT_TYPE => "block"        ,
                LUT_DEPTH => LEARNING_ENGINE_LUT_DEPTH           ,
                SYNAPSE_MEM_DEPTH => SYNAPSE_MEM_DEPTH               
                )
        Port Map 
        ( 
            ULEARN_RST            => ULEARN_LEARN_RST(i)          ,    
            ULEARN_CLK            => SP_CLOCK                     ,
            SYN_DATA_IN           => SYNAPTIC_MEMORY_DOUTB(i)     ,
            SYN_DIN_VLD           => ULEARN_ACTVATE_LENGINE(i)    ,
            SYNAPSE_START_ADDRESS => COLUMN_SYNAPSE_WRITE_ADDRESS(i)(clogb2(SYNAPSE_MEM_DEPTH)-1 downto 0) ,
            SYN_DATA_OUT          => ULEARN_SYN_DOUT(i)           ,
            SYN_DOUT_VLD          => ULEARN_SYN_DOUT_VLD(i)       ,
            SYNAPSE_WRITE_ADDRESS => ULEARN_SYNMEM_WRADDR(i)(clogb2(SYNAPSE_MEM_DEPTH)-1 downto 0)      ,
            SYNAPSE_PRUNING       => ULEARN_SYNAPSE_PRUN(i)       ,       
            PRUN_THRESHOLD        => ULEARN_PRUN_THRESH(i)        ,
            IGNORE_ZERO_SYNAPSES  => ULEARN_IGNORE_ZEROS(i)       ,
            IGNORE_SOFTLIMITS     => ULEARN_IGNORE_SOFTLIM(i)     ,
            LEARNING_RATE         => ULEARN_LEARNING_RATE(i)      ,
            LUT_LOW_ADDRESS       => ULEARN_LUT_LOW_ADDRESS(i)(clogb2(LEARNING_ENGINE_LUT_DEPTH)-1 downto 0)    ,
            ULEARN_LUT_DIN        => LEARN_LUT_DIN                ,
            ULEARN_LUT_ADDR       => LEARN_LUT_ADDR(clogb2(LEARNING_ENGINE_LUT_DEPTH)-1 downto 0)                 ,
            ULEARN_LUT_EN         => LEARN_LUT_EN                 ,
            NMODEL_WMAX           => ULEARN_NEURON_WMAX(i)        ,
            NMODEL_WMIN           => ULEARN_NEURON_WMIN(i)        ,
            NMODEL_SPIKE_TIME     => ULEARN_NEURON_SPK_TIME(i)    
        );


end generate LEARNING_ENGINE;

end restless_and_wild;