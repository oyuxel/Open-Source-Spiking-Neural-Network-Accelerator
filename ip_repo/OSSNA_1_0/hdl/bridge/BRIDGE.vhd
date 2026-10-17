library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.crossbar_utils.all;

entity BRIDGE is
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
        EVENT_ACCEPTANCE             : out std_logic;
        EVENT_DETECT                 : in  std_logic;
 
        READ_MAIN_SPIKE_BUFFER       : out std_logic;
        READ_CIRCULAR_BUFFER         : out std_logic;
        READ_AUX_BUFFER              : out std_logic;
        WRITE_OUTBUFFER              : out std_logic;
        WRITE_AUXBUFFER              : out std_logic;
 
        SYNAPTIC_MEM_RDADDR          : out std_logic_vector(clogb2(SYNAPSE_MEM_DEPTH)-1 downto 0);
        SYNAPTIC_MEM_WRADDR          : out std_logic_vector(clogb2(SYNAPSE_MEM_DEPTH)-1 downto 0);
 
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
        PARAMETER_MEM_RSTA           : out std_logic;
        PARAMETER_MEM_DOUTA          : in  std_logic_vector(31 downto 0);
        PARAMETER_MEM_DINA           : out std_logic_vector(31 downto 0)
    );
end BRIDGE;

architecture crush_with_eyeliner of BRIDGE is

    type STATES is (SLEEP,
                    SET_NETWORK_START_ADDRESS,
                    FETCH,
                    FETCH_DELAY,
                    DECODE,
                    PULLSYNAPSES,
                    CHECK_EVENT,
                    LAST_SYNAPSE_BATCH,
                    ACCUMMULATION_DELAY,
                    ENDFLOW_BRANCH,
                    BARRIER,
                    LAUNCH_NMC,
                    REWIND,
                    REWIND_READ_DELAY,
                    WAIT_NPARAM_DATA,
                    SWAP_NPARAM_DATA,
                    ASSEMBLE_ULEARN_WORD,
                    ULEARN_CFG_PART,
                    NMC_MEMORY_READ_DELAY,
                    RESET_ULEARN,
                    ULEARN_RST_DELAY,
                    LAUNCH_ULEARN,
                    GLOBAL_TIMESTEP
                    );
                    
    signal BRIDGE_STATE : STATES;

    constant SSSDSYNQ          : std_logic_vector := std_logic_vector(to_unsigned(1 ,4));
    constant SYNLOW            : std_logic_vector := std_logic_vector(to_unsigned(2 ,4));
    constant SYNHIGH           : std_logic_vector := std_logic_vector(to_unsigned(3 ,4));
    constant PFLOWRFPLST       : std_logic_vector := std_logic_vector(to_unsigned(4 ,4));
    constant NPADDRDATA        : std_logic_vector := std_logic_vector(to_unsigned(5 ,4));
    constant ULEARNCFGLOW      : std_logic_vector := std_logic_vector(to_unsigned(6 ,4));
    constant ULEARNLOWSYNADDR  : std_logic_vector := std_logic_vector(to_unsigned(7 ,4));
    constant ULEARNHIGHSYNADDR : std_logic_vector := std_logic_vector(to_unsigned(8 ,4));
    constant ENDFLOW           : std_logic_vector := std_logic_vector(to_unsigned(15,4));

    signal opcode              : std_logic_vector(3 downto 0);
    signal micro_addr          : std_logic_vector(27 downto 0);
    signal nmc_target_addr     : std_logic_vector(9 downto 0);
    signal fp16_data           : std_logic_vector(15 downto 0);
    signal src_main_en         : std_logic;
    signal src_circ_en         : std_logic;
    signal src_aux_en          : std_logic;
    signal dst_aux_en          : std_logic;
    signal dst_out_en          : std_logic;
    signal refractory_dur      : std_logic_vector(7 downto 0);
    signal last_spike_time     : std_logic_vector(7 downto 0);
    signal pruning_en          : std_logic;
    signal ignore_zeros_en     : std_logic;
    signal prun_threshold      : std_logic_vector(7 downto 0);
    signal learning_rate_sig   : std_logic_vector(7 downto 0);
    
    signal is_next_neuron      : std_logic;
    signal is_barrier_sync     : std_logic;
    signal is_timestep_upd     : std_logic;

    signal  MEMLOC                   : integer;
    signal  NEURON_SPACE             : integer;
    constant SYNAPSE_BATCH_SIZE      : integer := ROW;
    signal SYNAPSE_HIGH_ADDRESS      : integer range 0 to SYNAPSE_MEM_DEPTH-1;
    signal SYNAPSE_LOCATION          : integer range 0 to SYNAPSE_MEM_DEPTH-1;
    signal SYNAPSE_LOCATION_PAST_RD  : integer range 0 to SYNAPSE_MEM_DEPTH-1;
    signal SYNAPSE_LOCATION_PAST_WR  : integer range 0 to SYNAPSE_MEM_DEPTH-1;
    signal DLYCNTR                   : integer range 0 to NEURAL_MEM_DEPTH-1;
    signal CURRENT_ACC_DLYCNTR       : integer;

    constant SYNAPSE_ADDR_WIDTH : integer := clogb2(SYNAPSE_MEM_DEPTH);

    signal REWIND_FLAG : std_logic;

    signal ULEARN_HIGH_ADDR : integer;

    signal NEXT_NEURON_PRESENT    : std_logic;
    signal JUMP_BARRIER_STATE     : std_logic;
    signal UPDATE_GLOBAL_TIMESTEP : std_logic;

    signal ULEARN_CFG_WORD_BASE : integer range 0 to 1023;

    signal ULEARN_CFG_WORD_PCOUNTER : integer range 0 to 15;

    begin

    PARAMETER_MEM_ADDRA               <= std_logic_vector(to_unsigned(MEMLOC, PARAMETER_MEM_ADDRA'length));
    SYNAPTIC_MEM_RDADDR <= std_logic_vector(to_unsigned(SYNAPSE_LOCATION, SYNAPTIC_MEM_RDADDR'length));
    SYNAPTIC_MEM_WRADDR <= std_logic_vector(to_unsigned(SYNAPSE_LOCATION_PAST_WR, SYNAPTIC_MEM_WRADDR'length));

    opcode              <= PARAMETER_MEM_DOUTA(31 downto 28);
    micro_addr          <= PARAMETER_MEM_DOUTA(27 downto 0);
    nmc_target_addr     <= PARAMETER_MEM_DOUTA(25 downto 16);
    fp16_data           <= PARAMETER_MEM_DOUTA(15 downto 0);
    
    src_main_en         <= PARAMETER_MEM_DOUTA(20);
    src_circ_en         <= PARAMETER_MEM_DOUTA(19);
    src_aux_en          <= PARAMETER_MEM_DOUTA(18);
    dst_aux_en          <= PARAMETER_MEM_DOUTA(17);
    dst_out_en          <= PARAMETER_MEM_DOUTA(16);

    refractory_dur      <= PARAMETER_MEM_DOUTA(15 downto 8);
    last_spike_time     <= PARAMETER_MEM_DOUTA(7 downto 0);

    pruning_en          <= PARAMETER_MEM_DOUTA(17);
    ignore_zeros_en     <= PARAMETER_MEM_DOUTA(16);
    prun_threshold      <= PARAMETER_MEM_DOUTA(15 downto 8);
    learning_rate_sig   <= PARAMETER_MEM_DOUTA(7 downto 0);

    is_next_neuron      <= PARAMETER_MEM_DOUTA(0);
    is_barrier_sync     <= PARAMETER_MEM_DOUTA(1);
    is_timestep_upd     <= PARAMETER_MEM_DOUTA(3);

    MSM : process (BRIDGE_CLK) begin

        if rising_edge(BRIDGE_CLK) then
        
            if BRIDGE_RST = '1' then
            
                BRIDGE_STATE <= SLEEP;
            
            else
            
                case BRIDGE_STATE is
            
                    when SLEEP =>

                        GT_COMPLETED               <= '0'; 
                        READ_MAIN_SPIKE_BUFFER     <= '0'; 
                        READ_CIRCULAR_BUFFER       <= '0'; 
                        READ_AUX_BUFFER            <= '0';
                        WRITE_OUTBUFFER            <= '0'; 
                        WRITE_AUXBUFFER            <= '0';
                        SYNAPTIC_DATA_LOCK          <= '0'; 
                        DISABLE_COLUMN             <= '0'; 
                        NMC_STATE_RST              <= '1';  
                        NMC_FMAC_RST               <= '0';  
                        NMC_LAUNCH             <= '0';  
                        NMODEL_LAST_SPIKE_TIME     <= (others=>'0');
                        NMODEL_SYN_QFACTOR         <= (others=>'0');
                        NMODEL_PF_LOW_ADDR         <= (others=>'0');
                        NMC_MEM_PORTA_DIN         <= (others=>'0');
                        NMC_MEM_PORTA_ADDR         <= (others=>'0');
                        NMODEL_REFRACTORY_DUR      <= (others=>'0');
                        NMC_MEM_PORTA_EN   <= '0'; 
                        NMC_MEM_PORTA_WEN  <= '0'; 
                        NMC_MEM_PORTB_EXT_ACCESS <= '0'; 
                        NMC_MEM_PORTB_ADDR        <= (others=>'0');
                        SYNAPTIC_MEM_PORTA_MUX           <= '0'; 
                        ULEARN_RST                  <= '1'; 
                        PARAMETER_MEM_WEA                        <= '0';               
                        PARAMETER_MEM_RSTA                       <= '1';                     			     
                        PARAMETER_MEM_DINA                       <= (others=>'0');
                        MEMLOC                     <= 0;
                        NEURON_SPACE               <= 0;
                        SYNAPSE_HIGH_ADDRESS       <= 0;
                        CURRENT_ACC_DLYCNTR        <=  0;
                        SYNAPSE_LOCATION           <=  0;
                        SYNAPSE_LOCATION_PAST_RD   <=  0;
                        SYNAPSE_LOCATION_PAST_WR   <=  0;
                        REWIND_FLAG                <= '0';
                        NEXT_NEURON_PRESENT        <= '0';
                        JUMP_BARRIER_STATE         <= '0';
                        UPDATE_GLOBAL_TIMESTEP     <= '0';
                        BARRIER_SYNC_OUT           <= '0';
                        ULEARN_CFG_WORD         <= (others=>'0');
                        ULEARN_CFG_WORD_PCOUNTER   <= 0;                   
                        ULEARN_HIGH_ADDR           <= 0;
                        ULEARN_SYN_DIN_VLD <= '0';

                        if GT_START = '1' then
                            BRIDGE_STATE <= SET_NETWORK_START_ADDRESS;
                        else
                            BRIDGE_STATE <= SLEEP;
                        end if;

                    when SET_NETWORK_START_ADDRESS =>
                
                        MEMLOC <= to_integer(unsigned(NETWORK_LOW_ADDRESS));
                        NMC_STATE_RST              <= '0';
                        BRIDGE_STATE <= DECODE;

                    when FETCH =>

                        CURRENT_RESET_CHANNEL              <= '0';
                        CURRENT_SWITCH_CHANNEL             <= '0';
                        PARAMETER_MEM_WEA                        <= '0';
                        EVENT_ACCEPTANCE           <= '0';
                        NMC_MEM_PORTA_EN   <= '0';
                        NMC_MEM_PORTA_WEN  <= '0';
                        NMC_MEM_PORTB_EXT_ACCESS <= '0';
                        ULEARN_SYN_DIN_VLD          <= '0';

                        BRIDGE_STATE   <= FETCH_DELAY;

                        MEMLOC                 <= MEMLOC + 1;

                    when FETCH_DELAY =>

                        if REWIND_FLAG = '1' then

                            BRIDGE_STATE   <= REWIND;

                        else

                            BRIDGE_STATE   <= DECODE;

                        end if;

                    when DECODE =>

                        if opcode = SSSDSYNQ then

                            READ_MAIN_SPIKE_BUFFER <= src_main_en;
                            READ_CIRCULAR_BUFFER   <= src_circ_en;
                            READ_AUX_BUFFER        <= src_aux_en ;
                            WRITE_OUTBUFFER        <= dst_aux_en ;
                            WRITE_AUXBUFFER        <= dst_out_en ;
                            NMODEL_SYN_QFACTOR     <= fp16_data;
                            BRIDGE_STATE           <= FETCH;

                            NEURON_SPACE   <= NEURON_SPACE + 1;

                        elsif opcode = SYNLOW then

                            SYNAPSE_LOCATION    <= to_integer(unsigned(micro_addr(SYNAPSE_ADDR_WIDTH-1 downto 0)));
                            SYNAPSE_LOCATION_PAST_RD <= to_integer(unsigned(micro_addr(SYNAPSE_ADDR_WIDTH-1 downto 0)));
                            BRIDGE_STATE        <= FETCH;

                            NEURON_SPACE   <= NEURON_SPACE + 1;

                        elsif opcode = SYNHIGH then

                            SYNAPSE_HIGH_ADDRESS <= to_integer(unsigned(micro_addr(SYNAPSE_ADDR_WIDTH-1 downto 0)));
                            SYNAPTIC_MEM_PORTA_MUX     <= '0';
                            BRIDGE_STATE         <= PULLSYNAPSES;

                        elsif opcode = PFLOWRFPLST then

                            NMODEL_PF_LOW_ADDR     <= nmc_target_addr;
                            NMODEL_REFRACTORY_DUR  <= refractory_dur;
                            NMODEL_LAST_SPIKE_TIME <= last_spike_time;
                            BRIDGE_STATE           <= FETCH;

                            NEURON_SPACE   <= NEURON_SPACE + 1;

                        elsif opcode = NPADDRDATA then

                            NMC_MEM_PORTA_EN  <= '1';
                            NMC_MEM_PORTA_WEN <= '1';
                            NMC_MEM_PORTA_ADDR        <= nmc_target_addr;
                            NMC_MEM_PORTA_DIN        <= fp16_data;
                            BRIDGE_STATE              <= FETCH;

                            NEURON_SPACE   <= NEURON_SPACE + 1;

                        elsif opcode = ENDFLOW then

                            NEXT_NEURON_PRESENT    <= is_next_neuron  ;
                            JUMP_BARRIER_STATE     <= is_barrier_sync ;
                            UPDATE_GLOBAL_TIMESTEP <= is_timestep_upd ;
                            BRIDGE_STATE           <= ENDFLOW_BRANCH;

                            NEURON_SPACE   <= NEURON_SPACE + 1;

                        else
                            
                            BRIDGE_STATE <= FETCH;

                            NEURON_SPACE   <= NEURON_SPACE + 1;

                        end if;

                        when PULLSYNAPSES =>

                            EVENT_ACCEPTANCE <= '0';

                           if SYNAPSE_LOCATION = SYNAPSE_HIGH_ADDRESS then 

                                BRIDGE_STATE          <= LAST_SYNAPSE_BATCH;

                            elsif SYNAPSE_LOCATION = SYNAPSE_BATCH_SIZE + SYNAPSE_LOCATION_PAST_RD then 

                                SYNAPTIC_DATA_LOCK     <= '0';
                                BRIDGE_STATE          <= CHECK_EVENT;
                                
                            else

                                SYNAPSE_LOCATION    <= SYNAPSE_LOCATION + 1;
                                SYNAPTIC_DATA_LOCK   <= '1';
                       
                            end if;

                        when CHECK_EVENT =>

                            if EVENT_DETECT = '1' and TRACE_UPDATING = '0' then

                                EVENT_ACCEPTANCE <= '1';
                                BRIDGE_STATE     <= PULLSYNAPSES;
                                SYNAPSE_LOCATION_PAST_RD <= SYNAPSE_LOCATION;
                                SYNAPSE_LOCATION_PAST_WR <= SYNAPSE_LOCATION_PAST_RD;

                            else

                                EVENT_ACCEPTANCE <= '0';

                            end if;

                        when LAST_SYNAPSE_BATCH =>

                            SYNAPTIC_DATA_LOCK     <= '0';

                            if EVENT_DETECT = '1' and TRACE_UPDATING = '0'  then

                                EVENT_ACCEPTANCE <= '1';
                                BRIDGE_STATE     <= ACCUMMULATION_DELAY;
                                CURRENT_ACC_DLYCNTR <= 0;
                                SYNAPSE_LOCATION_PAST_RD <= SYNAPSE_LOCATION;
                                SYNAPSE_LOCATION_PAST_WR <= SYNAPSE_LOCATION_PAST_RD;

                            else

                                EVENT_ACCEPTANCE <= '0';

                            end if;

                        when ACCUMMULATION_DELAY =>

                            EVENT_ACCEPTANCE <= '0';

                            if CURRENT_ACC_DLYCNTR = SYNAPSE_BATCH_SIZE+5 then
                                
                                CURRENT_SWITCH_CHANNEL      <= '1';
                        
                                if CURRENT_CHANNEL_SWITCHED = '1' then
                                    BRIDGE_STATE  <= FETCH;
                                    
                                else
                                    BRIDGE_STATE  <= ACCUMMULATION_DELAY;
                                end if;
                            
                            else
                                
                                CURRENT_ACC_DLYCNTR <= CURRENT_ACC_DLYCNTR + 1;

                            end if;

                        when ENDFLOW_BRANCH => 

                            if JUMP_BARRIER_STATE = '1' then

                                BRIDGE_STATE     <= BARRIER;

                            else
                                
                                NMC_LAUNCH <= '1'; 
                                NMC_STATE_RST  <= '0';
                                NMC_FMAC_RST   <= '0';
                                CURRENT_RESET_CHANNEL  <= '1';

                                if CURRENT_RESOURCES_RELEASED = '1' then

                                    BRIDGE_STATE   <= LAUNCH_NMC;

                                end if;

                            end if;

                        when BARRIER => 

                            BARRIER_SYNC_OUT <= '1';
                            NMC_STATE_RST <= '0'; 

                            if BARRIER_SYNC_IN = '1' then

                                if NEXT_NEURON_PRESENT = '1' and UPDATE_GLOBAL_TIMESTEP = '0' then

                                    BRIDGE_STATE   <= FETCH;
                                    NEXT_NEURON_PRESENT <= '0';
                                    --NEURON_SPACE <= -1;
                                    NEURON_SPACE <= 0;

                                elsif NEXT_NEURON_PRESENT = '0' and UPDATE_GLOBAL_TIMESTEP = '1' then

                                    BRIDGE_STATE   <= GLOBAL_TIMESTEP;
                                    UPDATE_GLOBAL_TIMESTEP <= '0';

                                end if;

                                BARRIER_SYNC_OUT <= '0';

                            else
                                
                                BRIDGE_STATE   <= BARRIER;

                            end if;

                        when LAUNCH_NMC => 

                            NMC_LAUNCH <= '0'; 
                            CURRENT_RESET_CHANNEL  <= '0';
                            REWIND_FLAG    <= '1'; 

                            if NMODEL_FINISHED = '1' then

                                BRIDGE_STATE <= REWIND_READ_DELAY;
                                MEMLOC       <= MEMLOC - NEURON_SPACE;
                            
                            end if;

                        when REWIND_READ_DELAY => 

                            BRIDGE_STATE <= REWIND;

                        when REWIND =>

                            PARAMETER_MEM_WEA <= '0';

                            if opcode = PFLOWRFPLST then

                                PARAMETER_MEM_DINA         <= PARAMETER_MEM_DOUTA(31 downto 16) & NMODEL_NEW_REFRACTORY_DUR & NMODEL_NEW_SPIKE_TIME;
                                PARAMETER_MEM_WEA          <= '1';
                                BRIDGE_STATE <= FETCH;

                            elsif opcode = NPADDRDATA then

                                NMC_MEM_PORTB_EXT_ACCESS <= '1';
                                NMC_MEM_PORTB_ADDR        <= nmc_target_addr;
                                BRIDGE_STATE               <= WAIT_NPARAM_DATA;
                            
                            elsif opcode = ULEARNCFGLOW then

                                BRIDGE_STATE               <= ULEARN_CFG_PART;
                                NMC_MEM_PORTB_EXT_ACCESS <= '1';
                                ULEARN_CFG_WORD_BASE       <= to_integer(unsigned(micro_addr(9 downto 0)));
                                ULEARN_CFG_WORD_PCOUNTER   <= 0;

                            elsif opcode = ULEARNLOWSYNADDR then

                                SYNAPSE_LOCATION <= to_integer(unsigned(micro_addr(SYNAPSE_ADDR_WIDTH-1 downto 0)));
                                ULEARN_SYNAPSE_START_ADDRESS <= micro_addr(SYNAPSE_ADDR_WIDTH-1 downto 0);
                                BRIDGE_STATE    <= FETCH;

                            elsif opcode = ULEARNHIGHSYNADDR then

                                ULEARN_HIGH_ADDR <= to_integer(unsigned(micro_addr(SYNAPSE_ADDR_WIDTH-1 downto 0)));
                                BRIDGE_STATE     <= RESET_ULEARN;
                                ULEARN_RST        <= '1';
                                SYNAPTIC_MEM_PORTA_MUX <= '1';

                            elsif opcode = ENDFLOW then
    
                                BRIDGE_STATE <= BARRIER;
                                REWIND_FLAG  <= '0'; 
                                NMC_STATE_RST              <= '1'; 

                            else
                                
                                BRIDGE_STATE <= FETCH;

                            end if;

                        when WAIT_NPARAM_DATA =>

                            BRIDGE_STATE <= SWAP_NPARAM_DATA;

                        when SWAP_NPARAM_DATA =>

                            PARAMETER_MEM_DINA                       <= PARAMETER_MEM_DOUTA(31 downto 16) & NMC_MEM_PORTB_DOUT;
                            PARAMETER_MEM_WEA                        <= '1';
                            NMC_MEM_PORTB_EXT_ACCESS <= '0'; 
                            BRIDGE_STATE               <= FETCH;

                        when ASSEMBLE_ULEARN_WORD =>

                            if ULEARN_CFG_WORD_PCOUNTER = 15 then
                                BRIDGE_STATE <= FETCH;
                                ULEARN_CFG_WORD_PCOUNTER <= 0 ;
                            else
                                ULEARN_CFG_WORD_BASE <= ULEARN_CFG_WORD_BASE + 1; 
                                ULEARN_CFG_WORD_PCOUNTER <= ULEARN_CFG_WORD_PCOUNTER + 1;
                                BRIDGE_STATE <= ULEARN_CFG_PART;
                            end if;

                            ULEARN_CFG_WORD((ULEARN_CFG_WORD_PCOUNTER+1)*16-1 downto ULEARN_CFG_WORD_PCOUNTER*16) <= NMC_MEM_PORTB_DOUT;

                        when ULEARN_CFG_PART =>

                            NMC_MEM_PORTB_ADDR <= std_logic_vector(to_unsigned(ULEARN_CFG_WORD_BASE,10));
                            BRIDGE_STATE <= NMC_MEMORY_READ_DELAY;

                        when NMC_MEMORY_READ_DELAY => 

                            BRIDGE_STATE <= ASSEMBLE_ULEARN_WORD;

                        when RESET_ULEARN =>

                            BRIDGE_STATE <= ULEARN_RST_DELAY;
                            DISABLE_COLUMN <= '1';

                        when ULEARN_RST_DELAY =>
                            
                            ULEARN_RST <= '0';
                            BRIDGE_STATE <= LAUNCH_ULEARN;

                        when LAUNCH_ULEARN =>

                            ULEARN_SYN_DIN_VLD <= '1';
                            SYNAPSE_LOCATION <= SYNAPSE_LOCATION + 1;

                            if SYNAPSE_LOCATION = ULEARN_HIGH_ADDR then
                                BRIDGE_STATE <= FETCH;
                                DISABLE_COLUMN <= '0';
                            end if;

                        when GLOBAL_TIMESTEP =>

                            GT_COMPLETED <= '1';

                            if GT_START = '1' then

                                BRIDGE_STATE <= SLEEP;
                                
                            else

                                BRIDGE_STATE <= GLOBAL_TIMESTEP;
                                
                            end if;

                    when others =>
                                    NULL;   

                end case;

            end if;
            
        end if;

    end process MSM;

end crush_with_eyeliner;