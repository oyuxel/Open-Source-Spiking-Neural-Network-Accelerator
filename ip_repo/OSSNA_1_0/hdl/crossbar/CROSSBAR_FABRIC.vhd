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
            CB_CLK                   : in  std_logic;
            CB_VECTOR_RST            : in  std_logic_vector(0 to COLUMN-1);
            DISABLE_COLUMN           : in  std_logic_vector(0 to COLUMN-1);
            SPIKE_IN                 : in  std_logic_vector(ROW-1 downto 0);
            SPIKE_VLD                : in  std_logic;
            SPIKE_OUT                : out std_logic_vector(ROW-1 downto 0);
            SPIKE_OUT_VLD            : out std_logic;
            TRACE_UPDATING           : out std_logic_vector(0 to COLUMN-1);
            SYNAPTIC_DATA_IN         : in  SYNAPTIC_DATA(0 to COLUMN-1);
            SYNAPTIC_DATA_START_ADDR : in  SYNAPSE_ADDRESS(0 to COLUMN-1);
            SYNAPTIC_DATA_LOCK       : in  std_logic_vector(0 to COLUMN-1);
            PARTIAL_CURRENT_OUT      : out SYNAPTIC_SUM(0 to COLUMN-1);
            PARTIAL_CURRENT_OUT_VLD  : out std_logic_vector(0 to COLUMN-1);
            SYNAPTIC_DATA_OUT        : out SYNAPTIC_DATA(0 to COLUMN-1);
            SYNAPTIC_DATA_WRITE_ADDR : out SYNAPSE_ADDRESS(0 to COLUMN-1);
            SYNAPTIC_DATA_WRITE_EN   : out std_logic_vector(0 to COLUMN-1)
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
            
    signal COLUMN_INTERNAL_FIFO_RDEN     : std_logic_vector(0 to COLUMN-1);
    
    signal COLUMN_INTERNAL_FIFO_DOUT     : COLINTDOUT(0 to COLUMN-1);
    
    type SPKDTA is array (0 to COLUMN-1) of std_logic_vector(ROW-1 downto 0);   
    signal SPIKEDATA : SPKDTA;
        
    signal SYNAPSE_COUNTER       : SYNCNTR(0 to COLUMN-1) := (others=>0);
    signal SYNAPSE_COUNTER_1       : SYNCNTR(0 to COLUMN-1) := (others=>0);
    signal SYNAPSE_COUNTER_2       : SYNCNTR(0 to COLUMN-1) := (others=>0);
    
    signal INVERSE_SPIKEVECTOR : std_logic_vector(ROW-1 downto 0);
    
    signal COLUMN_ADDR: COLADDR(0 to COLUMN-1);
            
    signal POSTSYN_COUNT : PSYNCNT(0 to COLUMN-1);

    signal ROWLOCK      : std_logic_vector(0 to COLUMN/4-1);
    
    constant SUMDELAY : integer := log2(ROW)-1;
    
    type DLYCHAIN is array (0 to COLUMN/4-1) of std_logic_vector(0 to SUMDELAY);
    
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

     signal TRACE_BUSY_VEC : std_logic_vector(0 to COLUMN-1); 

    signal LOCK_COUNT      : SYNCNTR(0 to COLUMN-1);
    signal LOCK_COUNT_SNAP : SYNCNTR(0 to COLUMN-1);

begin

    INVERSE_SPIKEVECTOR <= SPIKE_IN;

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
                       
                                            PARTIAL_CURRENT_OUT(k) <= (others=>'0');
                                            
                                        else
                                        
                                            PARTIAL_CURRENT_OUT(k) <= COL_PARTIAL_SUM(k,0);
                                            
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
                     OUTPUT => PARTIAL_CURRENT_OUT(k)
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

                                        COLUMN_PRE_SYNAPTIC_DIN_DLY <= SYNAPTIC_DATA_IN;
                                                 
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
    
        ROWLOCK(k) <= SYNAPTIC_DATA_LOCK(k*4) or SYNAPTIC_DATA_LOCK(1+k*4) or SYNAPTIC_DATA_LOCK(2+k*4) or SYNAPTIC_DATA_LOCK(3+k*4);
    
    end generate ROWLOCK_GENERATION;


    DELAY_CHAIN_GENERATION : for k in 0 to COLUMN/4-1 generate
    
        DELAY_CHAIN : process(CB_CLK) 
        
                    begin
                    
                    if(rising_edge(CB_CLK)) then
                    
                         if((CB_VECTOR_RST(4*k) or CB_VECTOR_RST(4*k+1) or CB_VECTOR_RST(4*k+2) or CB_VECTOR_RST(4*k+3)) = '1') then
                                    
                            PARTIAL_CURRENT_OUT_VLD(4*k)   <= '0';
                            PARTIAL_CURRENT_OUT_VLD(1+4*k) <= '0';
                            PARTIAL_CURRENT_OUT_VLD(2+4*k) <= '0';
                            PARTIAL_CURRENT_OUT_VLD(3+4*k) <= '0';

                            DELAYCHAIN(k) <= (others=>'0');
                                                                
                         else
                            
                             DELAYCHAIN(k)(0) <= SPIKE_VLD;
                             DELAYCHAIN(k)(1 to SUMDELAY) <= DELAYCHAIN(k)(0 to SUMDELAY-1);
                             
                             PARTIAL_CURRENT_OUT_VLD(4*k)   <= DELAYCHAIN(k)(SUMDELAY);
                             PARTIAL_CURRENT_OUT_VLD(1+4*k) <= DELAYCHAIN(k)(SUMDELAY);
                             PARTIAL_CURRENT_OUT_VLD(2+4*k) <= DELAYCHAIN(k)(SUMDELAY);
                             PARTIAL_CURRENT_OUT_VLD(3+4*k) <= DELAYCHAIN(k)(SUMDELAY);
                                                                                                                
                         end if;
                         
                         end if;
                    
        end process DELAY_CHAIN;
        
    
    end generate DELAY_CHAIN_GENERATION;

    SYNAPSE_COUNTER_GENERATION: for k in 0 to COLUMN-1 generate
        
        SYNAPSE_COUNT : process(CB_CLK)
            begin
                if rising_edge(CB_CLK) then
                    if(CB_VECTOR_RST(k) = '1') then
                        LOCK_COUNT(k)      <= 0;
                        LOCK_COUNT_SNAP(k) <= 0;
                    else
                        if(SPIKE_VLD = '1') then
                            LOCK_COUNT_SNAP(k) <= LOCK_COUNT(k);
                            LOCK_COUNT(k)      <= 0;
                        elsif(SYNAPTIC_DATA_LOCK(k) = '1') then
                            LOCK_COUNT(k) <= LOCK_COUNT(k) + 1;
                        end if;
                    end if;
                end if;
        end process SYNAPSE_COUNT;
    
    end generate SYNAPSE_COUNTER_GENERATION;    
    
    SPIKE_LATCH_GENERATION : for k in 0 to COLUMN/4-1 generate 
    
        SPIKE_LATCH : process(CB_CLK)
        
                      begin
                      
                            if(rising_edge(CB_CLK)) then
                                
                                    if((CB_VECTOR_RST(4*k) or CB_VECTOR_RST(4*k+1) or CB_VECTOR_RST(4*k+2) or CB_VECTOR_RST(4*k+3)) = '1') then
                                    
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
    
        SYNAPTIC_DATA_WRITE_ADDR(i)(clogb2(SYNAPSE_MEM_DEPTH)-1 downto 0) <= std_logic_vector(to_unsigned(COLUMN_ADDR(i),clogb2(SYNAPSE_MEM_DEPTH)));
        SYNAPTIC_DATA_WRITE_ADDR(i)(31 downto clogb2(SYNAPSE_MEM_DEPTH)) <= (others=>'0');
    
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
    
    POSTSYN_OUT_GEN : for i in 0 to COLUMN-1 generate

        POST_SYNAPTIC_OUT : process(CB_CLK)
        
            begin
                      
                if(rising_edge(CB_CLK)) then
                    
                        if(CB_VECTOR_RST(i) = '1') then
                        
                            COLUMN_STATE(i) <= IDLE;
                            COLUMN_INTERNAL_FIFO_RDEN(i)   <= '0';
                            SYNAPSE_COUNTER(i) <= 0;
                            TRACE_BUSY_VEC(i) <= '0';

                        else
                        
                            case COLUMN_STATE(i) is
                            
                                when IDLE => 
                        
                                    COLUMN_INTERNAL_FIFO_RDEN(i)   <= '0';
                                    SYNAPSE_COUNTER(i) <= 0;
                                    TRACE_BUSY_VEC(i) <= '0';
                                    
                                    if(SPIKE_VLD_D2(i) = '1' and DISABLE_COLUMN(i) = '0') then
                                        COLUMN_STATE(i) <= FIFO_RD;
                                        COLUMN_ADDR(i)  <= to_integer(unsigned(SYNAPTIC_DATA_START_ADDR(i)(clogb2(SYNAPSE_MEM_DEPTH)-1 downto 0)  )) ;
                                    else
                                        COLUMN_STATE(i) <= IDLE;
                                    end if;
                                    
                                when FIFO_RD =>
                                
                                    if(SYNAPSE_COUNTER(i) = LOCK_COUNT_SNAP(i)-1) then
                                    
                                         COLUMN_STATE(i) <= IDLE;
                                         
                                    else
                                    
                                        SYNAPSE_COUNTER(i) <= SYNAPSE_COUNTER(i) + 1;
                                        COLUMN_INTERNAL_FIFO_RDEN(i)    <= '1';
                                        TRACE_BUSY_VEC(i) <= '1';
                                        
                                    end if;
                              
                                when others =>
                                            
                                            NULL;
                                            
                            end case;

                            SYNAPTIC_DATA_WRITE_EN(i) <= COLUMN_INTERNAL_FIFO_RDEN(i);

                            if SYNAPTIC_DATA_WRITE_EN(i) = '1' then

                                COLUMN_ADDR(i) <= COLUMN_ADDR(i) + 1;

                            end if;

                            SYNAPSE_COUNTER_1(i) <= SYNAPSE_COUNTER(i);
                            SYNAPSE_COUNTER_2(i) <= SYNAPSE_COUNTER_1(i);
                        
                        end if;
                            
                end if;

        end process POST_SYNAPTIC_OUT;
    
  end generate POSTSYN_OUT_GEN;

  TRACE_UPDATING <= TRACE_BUSY_VEC;


    POSTSYN_OUT : for i in 0 to COLUMN-1 generate

        SYNAPTIC_DATA_OUT(i)(15 downto 8) <= COLUMN_INTERNAL_FIFO_DOUT(i)(15 downto 8);

        SYNAPTIC_DATA_OUT(i)(7  downto 0) <= (others=>'0') when SPIKEDATA(i)(SYNAPSE_COUNTER_2(i)) = '1' else
                                            COLUMN_INTERNAL_FIFO_DOUT(i)(7  downto 0);

    end generate POSTSYN_OUT;
   
   COLUMN_INTERNAL_FIFO_GEN : for k in 0 to COLUMN-1 generate
   
      COL_INTERNAL_FIFO : INTERNAL_FIFO 
           generic map ( 
               WIDTH      => 16,   
               DEPTH      => ROW+4  
               ) 
           port map ( 
               clk        => CB_CLK ,                     
               rst        => CB_VECTOR_RST(k) ,                     
               wr_en      => SYNAPTIC_DATA_LOCK(k) ,
               rd_en      => COLUMN_INTERNAL_FIFO_RDEN(k), 
               data_in    => SYNAPTIC_DATA_IN(k), 
               data_out   => COLUMN_INTERNAL_FIFO_DOUT(k)  
               );             
    
    end generate COLUMN_INTERNAL_FIFO_GEN;

end wind_of_change;