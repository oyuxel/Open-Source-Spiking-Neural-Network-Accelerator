library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use work.crossbar_utils.all;
use work.crossbar_primitives.all;

entity CROSSBAR_FABRIC is
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
            TRACE_BUSY                      : out std_logic;
            COLUMN_PRE_SYNAPTIC_DIN         : in  SYNAPTIC_DATA(0 to COLUMN-1);
            COLUMN_SYNAPSE_START_ADDRESS    : in  SYNAPSE_ADDRESS(0 to COLUMN-1);
            PRE_SYN_DATA_PULL               : in  std_logic_vector(0 to COLUMN-1);
            COLN_SYN_SUM_OUT                : out SYNAPTIC_SUM(0 to COLUMN-1);
            COLN_VECTOR_SYN_SUM_VALID       : out std_logic_vector(0 to COLUMN-1);
            COLUMN_POST_SYNAPTIC_DOUT       : out SYNAPTIC_DATA(0 to COLUMN-1);
            COLUMN_SYNAPSE_WR_ADDRESS       : out SYNAPSE_ADDRESS(0 to COLUMN-1);
            COLUMN_POST_SYNAPTIC_WREN       : out std_logic_vector(0 to COLUMN-1)
        );
end CROSSBAR_FABRIC;

architecture wind_of_change of CROSSBAR_FABRIC is

    signal COL_PARTIAL_SUM : XBAR_RES(0 to COLUMN-1,0 to XBARCount(ROW)-1);
   
    type COLSUM  is array (natural range <>) of std_logic_vector(16*XBARCount(ROW)-1 downto 0);

    signal COLUMN_SUM : COLSUM (0 to COLUMN-1);
    
    type RLSHREG is array (natural range <>) of std_logic_vector(0 to ROW-1);
    signal ROWLOCKSHREG    : RLSHREG(0 to COLUMN/4-1);

    constant SPIKECYCLELIM : integer := ROW;
    
    signal SPIKECYCLE      : SPKCYCLES(0 to COLUMN/4-1);
    
    signal COLUMN_INTERNAL_FIFO_WREN_DLY1 : std_logic_vector(0 to COLUMN-1);
    signal COLUMN_INTERNAL_FIFO_WREN_DLY2 : std_logic_vector(0 to COLUMN-1);
    signal COLUMN_INTERNAL_FIFO_WREN_DLY3 : std_logic_vector(0 to COLUMN-1);
    
    signal COLUMN_POST_SYNAPTIC_WREN_REG : std_logic_vector(0 to COLUMN-1);
    
    signal COLUMN_INTERNAL_FIFO_RDEN     : std_logic_vector(0 to COLUMN-1);
    
    signal COLUMN_INTERNAL_FIFO_DOUT     : COLINTDOUT(0 to COLUMN-1);
    
    type SPKDTA is array (0 to COLUMN-1) of std_logic_vector(ROW-1 downto 0);   
    signal SPIKEDATA : SPKDTA;
        
    signal SYNAPSE_COUNTER       : SYNCNTR(0 to COLUMN-1);
    signal SYNAPSE_COUNTER_LIM   : SYNCNTR(0 to COLUMN-1);
    signal SYNAPSE_COUNTER_LIM_1 : SYNCNTR(0 to COLUMN-1);
    
    signal INVERSE_SPIKEVECTOR : std_logic_vector(ROW-1 downto 0);
    
    signal COLUMN_ADDR: COLADDR(0 to COLUMN-1);
    
    constant SYNAPSELIM : integer := ROW-1;
        
    signal POSTSYN_COUNT : PSYNCNT(0 to COLUMN-1);

    signal ROWLOCK      : std_logic_vector(0 to COLUMN/4-1);
    signal ROWLOCK_DLY1 : std_logic_vector(0 to COLUMN/4-1);
    
    constant SUMDELAY : integer := log2(ROW)-1;
    
    type DLYCHAIN is array (0 to COLUMN-1) of std_logic_vector(0 to SUMDELAY);
    
    signal DELAYCHAIN : DLYCHAIN;
    
    signal SPIKE_VLD_D1 : std_logic_vector(0 to COLUMN-1);
    signal SPIKE_VLD_D2 : std_logic_vector(0 to COLUMN-1);
    signal SPIKE_VLD_D3 : std_logic_vector(0 to COLUMN-1);
    
    signal XBAR_GATED_CLR : std_logic_vector(0 to COLUMN/4-1);

    type POST_SYN_STATES is (IDLE,FIFO_RD);
    
    type COLSTATES is array (0 to COLUMN-1) of POST_SYN_STATES;
    signal COLUMN_STATE : COLSTATES;
    
    type EVENT_CHECK_STATES is (IDLE,TIMESTAMP_UPDATE);
   
    type ECSTATES is array (0 to COLUMN-1) of EVENT_CHECK_STATES;
    signal EVENT_CHECK_STATE : ECSTATES;
    
     signal DLY0_SPIKE_IN  : std_logic_vector(ROW-1 downto 0);
     signal DLY0_SPIKE_VLD : std_logic;
    
     signal DLY1_SPIKE_IN  : std_logic_vector(ROW-1 downto 0);
     signal DLY1_SPIKE_VLD : std_logic;
    
     signal DLY2_SPIKE_IN  : std_logic_vector(ROW-1 downto 0);
     signal DLY2_SPIKE_VLD : std_logic; 
     
     signal COLUMN_PRE_SYNAPTIC_DIN_DLY : SYNAPTIC_DATA(0 to COLUMN-1);

     signal TRACE_BUSY_VEC : std_logic_vector(ROW-1 downto 0); 

begin

    GENERATE_INVERSE : for m in 0 to ROW-1 generate
    
        INVERSE_SPIKEVECTOR(m) <= SPIKE_IN(ROW-1-m);
     
    end generate GENERATE_INVERSE;

    XBAR_GATED_RESETS : for i in 0 to COLUMN/4-1 generate
    
        XBAR_GATED_CLR(i) <= CB_VECTOR_RST(4*i) or CB_VECTOR_RST(4*i+1) or CB_VECTOR_RST(4*i+2) or CB_VECTOR_RST(4*i+3) or SPIKE_VLD_D3(i);
    
    end generate XBAR_GATED_RESETS;
    
    CIRCULAR_BUFFER : process(CB_CLK) begin
    
        if rising_edge(CB_CLK) then
        
                DLY0_SPIKE_IN  <= SPIKE_IN   ; 
                DLY0_SPIKE_VLD <= SPIKE_VLD  ; 
                                    
                DLY1_SPIKE_IN  <= DLY0_SPIKE_IN  ;
                DLY1_SPIKE_VLD <= DLY0_SPIKE_VLD ;
                                    
                DLY2_SPIKE_IN  <= DLY1_SPIKE_IN ;
                DLY2_SPIKE_VLD <= DLY1_SPIKE_VLD;
           
                SPIKE_OUT     <= DLY2_SPIKE_IN  ;
                SPIKE_OUT_VLD <= DLY2_SPIKE_VLD ;
            
        end if;
    
    end process CIRCULAR_BUFFER;


    COLUMN_GENERATE : for k in 0 to COLUMN/4-1 generate
    
        ROW_GENERATE : for i in 0 to XBARCount(ROW)-1 generate
        
                FIRST_XBAR: if i=0  generate
        
                    XBAR_INST:  XBAR_PRIMITIVE_2x4
                        Generic Map (
                                    SPIKE_PIPELINE_REGS  => 1,
                                    OUTPUT_PIPELINE_REGS => 1,
                                    ROW_1_PIPELINE_REGS  => 1,
                                    ROW_2_PIPELINE_REGS  => 1
                                    )
                            Port Map( 
                                    XBAR_CLK     => CB_CLK                                        ,
                                    XBAR_CLR     => XBAR_GATED_CLR(k)                             ,
                                    SPIKE_IN_0   => INVERSE_SPIKEVECTOR(ROW-2)                    , 
                                    SPIKE_IN_1   => INVERSE_SPIKEVECTOR(ROW-1)                    , 
                                    ROW0_CE      => ROWLOCKSHREG(k)(ROW-2)                        ,
                                    ROW1_CE      => ROWLOCKSHREG(k)(ROW-1)                        ,
                                    W00          => COLUMN_PRE_SYNAPTIC_DIN_DLY(  k*4)(15 downto 8) ,
                                    W01          => COLUMN_PRE_SYNAPTIC_DIN_DLY(1+k*4)(15 downto 8) ,
                                    W02          => COLUMN_PRE_SYNAPTIC_DIN_DLY(2+k*4)(15 downto 8) ,
                                    W03          => COLUMN_PRE_SYNAPTIC_DIN_DLY(3+k*4)(15 downto 8) ,
                                    W10          => COLUMN_PRE_SYNAPTIC_DIN_DLY(  k*4)(15 downto 8) ,
                                    W11          => COLUMN_PRE_SYNAPTIC_DIN_DLY(1+k*4)(15 downto 8) ,
                                    W12          => COLUMN_PRE_SYNAPTIC_DIN_DLY(2+k*4)(15 downto 8) ,
                                    W13          => COLUMN_PRE_SYNAPTIC_DIN_DLY(3+k*4)(15 downto 8) ,
                                    PE_OUT_0     => COL_PARTIAL_SUM(  k*4, 0)                   ,
                                    PE_OUT_1     => COL_PARTIAL_SUM(1+k*4, 0)                   ,
                                    PE_OUT_2     => COL_PARTIAL_SUM(2+k*4, 0)                   ,
                                    PE_OUT_3     => COL_PARTIAL_SUM(3+k*4, 0)                    
                                    );
         
                end generate FIRST_XBAR;
        
                MID_XBAR: if i>0 generate
        
                    XBAR_INST:  XBAR_PRIMITIVE_2x4
                        Generic Map (
                                    SPIKE_PIPELINE_REGS  => 1,
                                    OUTPUT_PIPELINE_REGS => 1,
                                    ROW_1_PIPELINE_REGS  => 1,
                                    ROW_2_PIPELINE_REGS  => 1
                                    )
                            Port Map( 
                                    XBAR_CLK     => CB_CLK                                        ,
                                    XBAR_CLR     => XBAR_GATED_CLR(k)                             ,
                                    SPIKE_IN_0   => INVERSE_SPIKEVECTOR(ROW-2-2*i)                           ,  
                                    SPIKE_IN_1   => INVERSE_SPIKEVECTOR(ROW-1-2*i)                           ,  
                                    ROW0_CE      => ROWLOCKSHREG(k)(ROW-2-2*i)                    , 
                                    ROW1_CE      => ROWLOCKSHREG(k)(ROW-1-2*i)                    , 
                                    W00          => COLUMN_PRE_SYNAPTIC_DIN_DLY(  k*4)(15 downto 8) ,
                                    W01          => COLUMN_PRE_SYNAPTIC_DIN_DLY(1+k*4)(15 downto 8) ,
                                    W02          => COLUMN_PRE_SYNAPTIC_DIN_DLY(2+k*4)(15 downto 8) ,
                                    W03          => COLUMN_PRE_SYNAPTIC_DIN_DLY(3+k*4)(15 downto 8) ,
                                    W10          => COLUMN_PRE_SYNAPTIC_DIN_DLY(  k*4)(15 downto 8) ,
                                    W11          => COLUMN_PRE_SYNAPTIC_DIN_DLY(1+k*4)(15 downto 8) ,
                                    W12          => COLUMN_PRE_SYNAPTIC_DIN_DLY(2+k*4)(15 downto 8) ,
                                    W13          => COLUMN_PRE_SYNAPTIC_DIN_DLY(3+k*4)(15 downto 8) ,
                                    PE_OUT_0     => COL_PARTIAL_SUM(  k*4, i)                   ,
                                    PE_OUT_1     => COL_PARTIAL_SUM(1+k*4, i)                   ,
                                    PE_OUT_2     => COL_PARTIAL_SUM(2+k*4, i)                   ,
                                    PE_OUT_3     => COL_PARTIAL_SUM(3+k*4, i)                    
                                    );
         
                end generate MID_XBAR;
        
        end generate ROW_GENERATE;
        
    end generate COLUMN_GENERATE;

    SUMGEN0 : if ROW = 2 generate
    
        COLSUM_GENERATE : for k in 0 to COLUMN-1 generate
    
            SYNAPTIC_SUM : process(CB_CLK)
            
                            begin
                            
                                if(rising_edge(CB_CLK)) then
                                
                                        if(CB_VECTOR_RST(k) = '1') then
                       
                                            COLN_SYN_SUM_OUT(k) <= (others=>'0');
                                            
                                        else
                                        
                                            COLN_SYN_SUM_OUT(k) <= COL_PARTIAL_SUM(k,0);
                                            
                                        end if;      
    
                                end if;
                            
            end process SYNAPTIC_SUM;
            
        end generate COLSUM_GENERATE;
    
    end generate SUMGEN0;

    SUMGEN1 : if ROW>2  generate
    
        COLVEC_GEN : for k in 0 to COLUMN-1 generate
    
                VEC_GEN : for i in 0 to XBARCount(ROW)-1 generate
    
                      COLUMN_SUM(k)((i+1)*16-1 downto 16*i) <= COL_PARTIAL_SUM(k,i);

                end generate VEC_GEN;
                
        PP_ADDER_GEN : Pipeline_Adder 
            generic Map(
                         N => ROW /2 
                     )
             port Map(
                     CLK    => CB_CLK           ,
                     RST    => CB_VECTOR_RST(k) ,
                     INPUT  => COLUMN_SUM(k)    ,
                     OUTPUT => COLN_SYN_SUM_OUT(k)
                 );

        end generate COLVEC_GEN;
        
    end generate SUMGEN1;

    SPIKE_CYCLE_GENERATION : for k in 0 to COLUMN/4-1 generate
        
        SPIKECYCLES : process(CB_CLK)
            
                            begin
                            
                                if(rising_edge(CB_CLK)) then
                                
                                    if((CB_VECTOR_RST(4*k) or CB_VECTOR_RST(4*k+1) or CB_VECTOR_RST(4*k+2) or CB_VECTOR_RST(4*k+3)) = '1') then
                                    
                                            SPIKECYCLE(k)   <= 0;
                                            ROWLOCKSHREG(k) <= (others => '0');

                                            COLUMN_PRE_SYNAPTIC_DIN_DLY <= (others=>(others=>'0'));
                                    
                                    else

                                        COLUMN_PRE_SYNAPTIC_DIN_DLY <= COLUMN_PRE_SYNAPTIC_DIN;
                                                 
                                            if(ROWLOCK(k) = '1') then
                                                      
                                                if(SPIKECYCLE(k) = 0) then
                          
                                                    SPIKECYCLE(k) <= SPIKECYCLE(k) + 1;  
    
                                                    ROWLOCKSHREG(k)(0) <= '1';
                                                                                                
                                                elsif(SPIKECYCLE(k) > 0 and SPIKECYCLE(k) < SPIKECYCLELIM) then
                                                
                                                    ROWLOCKSHREG(k) <= '0'&ROWLOCKSHREG(k)(0 to ROW-2);
                                                    SPIKECYCLE(k) <= SPIKECYCLE(k) + 1;
                                                    
                                                else
                                                
                                                    ROWLOCKSHREG(k) <= (others=>'0');
                                                    SPIKECYCLE(k) <= 0;
                                                
                                                end if;
                                            
                                            else
                                                
                                                SPIKECYCLE(k) <= 0;
                                                ROWLOCKSHREG(k) <= (others => '0');                                         
                                            
                                            end if;  
                                         
                                    end if;
                                
                                end if;
                       
        end process SPIKECYCLES;
    
    end generate SPIKE_CYCLE_GENERATION;
    
 
    ROWLOCK_GENERATION : for k in 0 to COLUMN/4-1 generate
    
        ROWLOCK(k) <= PRE_SYN_DATA_PULL(k*4) or PRE_SYN_DATA_PULL(1+k*4) or PRE_SYN_DATA_PULL(2+k*4) or PRE_SYN_DATA_PULL(3+k*4);
    
    end generate ROWLOCK_GENERATION;


    DELAY_CHAIN_GENERATION : for k in 0 to COLUMN/4-1 generate
    
        DELAY_CHAIN : process(CB_CLK) 
        
                    begin
                    
                    if(rising_edge(CB_CLK)) then
                    
                         if((CB_VECTOR_RST(4*k) or CB_VECTOR_RST(4*k+1) or CB_VECTOR_RST(4*k+2) or CB_VECTOR_RST(4*k+3)) = '1') then
                                    
                            COLN_VECTOR_SYN_SUM_VALID(4*k)   <= '0';
                            COLN_VECTOR_SYN_SUM_VALID(1+4*k) <= '0';
                            COLN_VECTOR_SYN_SUM_VALID(2+4*k) <= '0';
                            COLN_VECTOR_SYN_SUM_VALID(3+4*k) <= '0';

                            COLUMN_INTERNAL_FIFO_WREN_DLY1(4*k)   <= '0';        
                            COLUMN_INTERNAL_FIFO_WREN_DLY1(1+4*k) <= '0';        
                            COLUMN_INTERNAL_FIFO_WREN_DLY1(2+4*k) <= '0';        
                            COLUMN_INTERNAL_FIFO_WREN_DLY1(3+4*k) <= '0';

                            COLUMN_INTERNAL_FIFO_WREN_DLY2(4*k)   <= '0';        
                            COLUMN_INTERNAL_FIFO_WREN_DLY2(1+4*k) <= '0';        
                            COLUMN_INTERNAL_FIFO_WREN_DLY2(2+4*k) <= '0';        
                            COLUMN_INTERNAL_FIFO_WREN_DLY2(3+4*k) <= '0';
                                                                
                         else
                            
                             DELAYCHAIN(4*k)(0) <= SPIKE_VLD;
                             DELAYCHAIN(4*k)(1 to SUMDELAY) <= DELAYCHAIN(4*k)(0 to SUMDELAY-1);
                             
                             DELAYCHAIN(1+4*k)(0) <= SPIKE_VLD;
                             DELAYCHAIN(1+4*k)(1 to SUMDELAY) <= DELAYCHAIN(1+4*k)(0 to SUMDELAY-1);
                             
                             DELAYCHAIN(2+4*k)(0) <= SPIKE_VLD;
                             DELAYCHAIN(2+4*k)(1 to SUMDELAY) <= DELAYCHAIN(2+4*k)(0 to SUMDELAY-1);
                             
                             DELAYCHAIN(3+4*k)(0) <= SPIKE_VLD;
                             DELAYCHAIN(3+4*k)(1 to SUMDELAY) <= DELAYCHAIN(3+4*k)(0 to SUMDELAY-1); 
                             
                             COLN_VECTOR_SYN_SUM_VALID(4*k)   <= DELAYCHAIN(k)(SUMDELAY);
                             COLN_VECTOR_SYN_SUM_VALID(1+4*k) <= DELAYCHAIN(k)(SUMDELAY);
                             COLN_VECTOR_SYN_SUM_VALID(2+4*k) <= DELAYCHAIN(k)(SUMDELAY);
                             COLN_VECTOR_SYN_SUM_VALID(3+4*k) <= DELAYCHAIN(k)(SUMDELAY);

                             COLUMN_INTERNAL_FIFO_WREN_DLY1(4*k)   <= PRE_SYN_DATA_PULL(4*k)  ;
                             COLUMN_INTERNAL_FIFO_WREN_DLY1(1+4*k) <= PRE_SYN_DATA_PULL(1+4*k);
                             COLUMN_INTERNAL_FIFO_WREN_DLY1(2+4*k) <= PRE_SYN_DATA_PULL(2+4*k);
                             COLUMN_INTERNAL_FIFO_WREN_DLY1(3+4*k) <= PRE_SYN_DATA_PULL(3+4*k);

                             COLUMN_INTERNAL_FIFO_WREN_DLY2(4*k)   <= COLUMN_INTERNAL_FIFO_WREN_DLY1(4*k)  ;
                             COLUMN_INTERNAL_FIFO_WREN_DLY2(1+4*k) <= COLUMN_INTERNAL_FIFO_WREN_DLY1(1+4*k);
                             COLUMN_INTERNAL_FIFO_WREN_DLY2(2+4*k) <= COLUMN_INTERNAL_FIFO_WREN_DLY1(2+4*k);
                             COLUMN_INTERNAL_FIFO_WREN_DLY2(3+4*k) <= COLUMN_INTERNAL_FIFO_WREN_DLY1(3+4*k);

                             COLUMN_INTERNAL_FIFO_WREN_DLY3(4*k)   <= COLUMN_INTERNAL_FIFO_WREN_DLY2(4*k)  ;
                             COLUMN_INTERNAL_FIFO_WREN_DLY3(1+4*k) <= COLUMN_INTERNAL_FIFO_WREN_DLY2(1+4*k);
                             COLUMN_INTERNAL_FIFO_WREN_DLY3(2+4*k) <= COLUMN_INTERNAL_FIFO_WREN_DLY2(2+4*k);
                             COLUMN_INTERNAL_FIFO_WREN_DLY3(3+4*k) <= COLUMN_INTERNAL_FIFO_WREN_DLY2(3+4*k);
                                                                                                                
                         end if;
                         
                         end if;
                    
        end process DELAY_CHAIN;
        
    
    end generate DELAY_CHAIN_GENERATION;

    SYNAPSE_COUNTER_GENERATION: for k in 0 to COLUMN-1 generate
        
        SYNAPSE_COUNT : process(CB_CLK)
        
                        begin
                                          
                            if(rising_edge(CB_CLK)) then
                                
                                    if(CB_VECTOR_RST(k) = '1') then
                                    
                                        SYNAPSE_COUNTER_LIM(k)   <= 0;
                                        SYNAPSE_COUNTER_LIM_1(k) <= 0;
                                        
                                    else
                                    
                                        if(COLUMN_INTERNAL_FIFO_WREN_DLY1(k) = '1') then
                                        
                                            SYNAPSE_COUNTER_LIM(k)   <= 0;
                                            
                                        end if;
                                       
                                        if(COLUMN_INTERNAL_FIFO_WREN_DLY2(k) = '1') then
                                        
                                            SYNAPSE_COUNTER_LIM(k) <= SYNAPSE_COUNTER_LIM(k) + 1;

                                        end if;

                                        if( SPIKE_VLD_D2(k) = '1') then
                                        
                                            SYNAPSE_COUNTER_LIM_1(k) <= SYNAPSE_COUNTER_LIM(k);

                                        end if;
                    
                                    end if;
                                    
                            end if;
                      
        end process SYNAPSE_COUNT;
    
    end generate SYNAPSE_COUNTER_GENERATION;    
    
    SPIKE_LATCH_GENERATION : for k in 0 to COLUMN/4-1 generate 
    
        SPIKE_LATCH : process(CB_CLK)
        
                      begin
                      
                            if(rising_edge(CB_CLK)) then
                                
                                    if(CB_VECTOR_RST(k*4) = '1') then
                                    
                                        SPIKEDATA(4*k)   <= (others=>'0');
                                        SPIKEDATA(4*k+1) <= (others=>'0');
                                        SPIKEDATA(4*k+2) <= (others=>'0');
                                        SPIKEDATA(4*k+3) <= (others=>'0');
                                    
                                    else
              
                                         if(SPIKE_VLD = '1') then
                                         
                                            SPIKEDATA(4*k)   <= INVERSE_SPIKEVECTOR;
                                            SPIKEDATA(4*k+1) <= INVERSE_SPIKEVECTOR;
                                            SPIKEDATA(4*k+2) <= INVERSE_SPIKEVECTOR;
                                            SPIKEDATA(4*k+3) <= INVERSE_SPIKEVECTOR;
                                            
                                         else
                                         
                                            SPIKEDATA(4*k)   <= SPIKEDATA(4*k);
                                            SPIKEDATA(4*k+1) <= SPIKEDATA(4*k+1);
                                            SPIKEDATA(4*k+2) <= SPIKEDATA(4*k+2);
                                            SPIKEDATA(4*k+3) <= SPIKEDATA(4*k+3);

                                         end if;                                                                      
                               
                                    end if;
                                
                                end if;
                    
        end process SPIKE_LATCH;
    
    end generate SPIKE_LATCH_GENERATION;
    
    GENERATE_MEMORY_INTERFACE : for i in 0 to COLUMN-1 generate
    
        COLUMN_SYNAPSE_WR_ADDRESS(i)(clogb2(SYNAPSE_MEM_DEPTH)-1 downto 0) <= std_logic_vector(to_unsigned(COLUMN_ADDR(i),clogb2(SYNAPSE_MEM_DEPTH)));
        COLUMN_SYNAPSE_WR_ADDRESS(i)(31 downto clogb2(SYNAPSE_MEM_DEPTH)) <= (others=>'0');
    
    end generate GENERATE_MEMORY_INTERFACE;
    
    GENERATE_VLD_DELAYCHAIN : for i in 0 to COLUMN-1 generate
          
        VLD_DELAY : process(CB_CLK)
        
                            begin
                            
                                if(rising_edge(CB_CLK)) then
                                
                                    if(CB_VECTOR_RST(i) = '1') then
                                    
                                        SPIKE_VLD_D1(i) <= '0';
                                        SPIKE_VLD_D2(i) <= '0';
                                        SPIKE_VLD_D3(i) <= '0';
                                
                                    else               
                                                                
                                        SPIKE_VLD_D1(i) <= SPIKE_VLD;
                                        SPIKE_VLD_D2(i) <= SPIKE_VLD_D1(i);
                                        SPIKE_VLD_D3(i) <= SPIKE_VLD_D2(i);
                                    
                                    end if;
                                
                                end if;
                           
        end process VLD_DELAY;

    end generate GENERATE_VLD_DELAYCHAIN;
    
    INTERNAL_FIFO_CONTROLS : for i in 0 to COLUMN-1 generate

        COLUMN_POST_SYNAPTIC_WREN(i) <= COLUMN_POST_SYNAPTIC_WREN_REG(i) ; 
        COLUMN_POST_SYNAPTIC_WREN(i) <= COLUMN_POST_SYNAPTIC_WREN_REG(i) ; 
        COLUMN_POST_SYNAPTIC_WREN(i) <= COLUMN_POST_SYNAPTIC_WREN_REG(i) ; 
        COLUMN_POST_SYNAPTIC_WREN(i) <= COLUMN_POST_SYNAPTIC_WREN_REG(i) ; 
    
    end generate INTERNAL_FIFO_CONTROLS;
    

    POSTSYN_OUT_GEN : for i in 0 to COLUMN-1 generate

        POST_SYNAPTIC_OUT : process(CB_CLK)
        
            begin
                      
                if(rising_edge(CB_CLK)) then
                    
                        if(CB_VECTOR_RST(i) = '1') then
                        
                            COLUMN_STATE(i) <= IDLE;
                            
                        else
                        
                            case COLUMN_STATE(i) is
                            
                                when IDLE => 
                        
                                    COLUMN_INTERNAL_FIFO_RDEN(i)   <= '0';
                                    SYNAPSE_COUNTER(i) <= 0;
                                    
                                    if(SPIKE_VLD = '1' and COLUMN_DISABLE_VECTOR(i) = '0') then
                                        COLUMN_STATE(i) <= FIFO_RD;
                                    else
                                        COLUMN_STATE(i) <= IDLE;
                                    end if;
                                    
                                when FIFO_RD =>
                                
                                    if(SYNAPSE_COUNTER(i) = ROW-1) then
                                    
                                         COLUMN_STATE(i) <= IDLE;
                                         
                                    else
                                    
                                        SYNAPSE_COUNTER(i) <= SYNAPSE_COUNTER(i) + 1;
                                        COLUMN_INTERNAL_FIFO_RDEN(i)    <= '1';
                                        
                                    end if;
                              
                                when others =>
                                            
                                            NULL;
                                            
                            end case;
                        
                        end if;
                            
                end if;

        end process POST_SYNAPTIC_OUT;
    
  end generate POSTSYN_OUT_GEN;

  TRACE_BUSY <= or TRACE_BUSY_VEC;
    
  EVENT_CHECK_GENERATION : for i in 0 to COLUMN-1 generate 
  
        EVENT_CHECK : process(CB_CLK)
        
                            begin
                      
                            if(rising_edge(CB_CLK)) then
                                
                                    if(CB_VECTOR_RST(i) = '1') then
                                    
                                        EVENT_CHECK_STATE(i) <= IDLE;
                                    
                                    else
                                    
                                        case EVENT_CHECK_STATE(i) is
                                     
                                            when IDLE =>
                                           
                                                COLUMN_POST_SYNAPTIC_DOUT(i)     <= (others=>'0');

                                                COLUMN_POST_SYNAPTIC_WREN_REG(i)    <= '0';
                                                

                                                POSTSYN_COUNT(i) <= 0;
                                                
                                                if(SPIKE_VLD_D2(i) = '1' and COLUMN_DISABLE_VECTOR(i) = '0') then
                                                    EVENT_CHECK_STATE(i) <= TIMESTAMP_UPDATE;
                                                    COLUMN_ADDR(i)   <= to_integer(unsigned(COLUMN_SYNAPSE_START_ADDRESS(i)(clogb2(SYNAPSE_MEM_DEPTH)-1 downto 0)  )) ; 
                                                    TRACE_BUSY_VEC(i) <= '1';
                                                else
                                                    EVENT_CHECK_STATE(i) <= IDLE;
                                                    TRACE_BUSY_VEC(i) <= '0';
                                                end if;
                                            
                                            when TIMESTAMP_UPDATE =>
                                                                                        
                                                if(POSTSYN_COUNT(i) = SYNAPSE_COUNTER_LIM_1(i)-1) then
                                                
                                                     EVENT_CHECK_STATE(i) <= IDLE;
                                                     POSTSYN_COUNT(i)   <= 0;
                                                else
                                                
                                                    POSTSYN_COUNT(i) <= POSTSYN_COUNT(i) + 1;
                                                    EVENT_CHECK_STATE(i) <= TIMESTAMP_UPDATE;
                                                    
                                                end if;
                                                
                                                COLUMN_POST_SYNAPTIC_WREN_REG(i)    <= '1';
                                                
                                                if(COLUMN_POST_SYNAPTIC_WREN_REG(i)  = '1') then
                                                
                                                    COLUMN_ADDR(i) <= COLUMN_ADDR(i) + 1;
                                                    
                                                else
                                                
                                                    COLUMN_ADDR(i) <= COLUMN_ADDR(i);
                                                    
                                                end if;
                                                                                            
     
                                                if(SPIKEDATA(i)(POSTSYN_COUNT(i)) = '1') then
                                                
                                                    COLUMN_POST_SYNAPTIC_DOUT(i)(15 downto 8) <= COLUMN_INTERNAL_FIFO_DOUT(i)(15 downto 8);
                                                    COLUMN_POST_SYNAPTIC_DOUT(i)(7  downto 0) <= (others=>'0');
  
                                                else
                                                
                                                    COLUMN_POST_SYNAPTIC_DOUT(i)(15 downto 8) <= COLUMN_INTERNAL_FIFO_DOUT(i)(15 downto 8);
                                                    COLUMN_POST_SYNAPTIC_DOUT(i)(7  downto 0) <= COLUMN_INTERNAL_FIFO_DOUT(i)(7  downto 0);                                              
                                                                                                
                                                end if;
                                                   
                                            
                                            when others => 
                                                        NULL;
                                                  
                                        end case;
                                    
                                    end if;
                                
                                end if;
                    
        end process EVENT_CHECK;  
    
   end generate EVENT_CHECK_GENERATION; 
   
   
   COLUMN_INTERNAL_FIFO_GEN : for k in 0 to COLUMN-1 generate
   
      COL_INTERNAL_FIFO : INTERNAL_FIFO 
           generic map ( 
               WIDTH      => 16,   
               DEPTH      => ROW+2  
               ) 
           port map ( 
               clk        => CB_CLK ,                     
               rst        => CB_VECTOR_RST(k) ,                     
               wr_en      => COLUMN_INTERNAL_FIFO_WREN_DLY1(k) ,
               rd_en      => COLUMN_INTERNAL_FIFO_RDEN(k), 
               data_in    => COLUMN_PRE_SYNAPTIC_DIN_DLY(k), 
               data_out   => COLUMN_INTERNAL_FIFO_DOUT(k)  
               );             
    
    end generate COLUMN_INTERNAL_FIFO_GEN;

end wind_of_change;