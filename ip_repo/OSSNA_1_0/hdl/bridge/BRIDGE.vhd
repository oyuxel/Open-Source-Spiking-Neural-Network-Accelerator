library ieee;
use ieee.std_logic_1164.all;

package nmemportdef is
    function clogb2 (depth: in natural) return integer;
end nmemportdef;

package body nmemportdef is

function clogb2( depth : natural) return integer is
variable temp    : integer := depth;
variable ret_val : integer := 0;
begin
    while temp > 1 loop
        ret_val := ret_val + 1;
        temp    := temp / 2;
    end loop;
    return ret_val;
end function;

end package body nmemportdef;

library ieee;
library work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.nmemportdef.all;

entity BRIDGE is
    Generic (
        NEURAL_MEM_DEPTH  : integer := 2048;    
        SYNAPSE_MEM_DEPTH : integer := 2048;
        ROW               : integer := 16             
        );
    Port(
        BRIDGE_CLK                 : in  std_logic;
        BRIDGE_RST                 : in  std_logic;
        NETWORK_LOW_ADDRESS        : in  std_logic_vector((clogb2(NEURAL_MEM_DEPTH)-1) downto 0);
        GT_START                   : in  std_logic;
        GT_COMPLETED               : out std_logic;
        SKIP_LEARNING_PROCESS      : in  std_logic;
        -- BRIDGE CONTROLS
        EVENT_ACCEPTANCE           : out std_logic;
        EVENT_DETECT               : in  std_logic;
        -- EVENT ACCEPTANCE
        READ_MAIN_SPIKE_BUFFER     : out std_logic;
        READ_CIRCULAR_BUFFER       : out std_logic;
        READ_AUX_BUFFER            : out std_logic;
        -- SPIKE DESTINATION
        WRITE_OUTBUFFER            : out std_logic;
        WRITE_AUXBUFFER            : out std_logic;
        -- SYNAPTIC MEMORY CONTROLS (PORT B)
        SYNAPTIC_MEM_RDADDR        : out std_logic_vector((clogb2(SYNAPSE_MEM_DEPTH)-1) downto 0);
        SYNAPTIC_MEM_ENABLE        : out std_logic;
        SYNAPTIC_MEM_WRADDR        : out std_logic_vector((clogb2(SYNAPSE_MEM_DEPTH)-1) downto 0);
        SYNAPTIC_MEM_WREN          : out std_logic;
        -- HYPERCOLUMN CONTROLS
        HALT_HYPERCOLUMN           : out std_logic;
        PRE_SYN_DATA_PULL          : out std_logic;
        DISABLE_COLUMN             : out std_logic;
        -- NMC CONTROLS
        NMC_STATE_RST              : out std_logic; 
        NMC_FMAC_RST               : out std_logic; 
        NMC_COLD_START             : out std_logic; 
        NMODEL_LAST_SPIKE_TIME     : out STD_LOGIC_VECTOR(7  DOWNTO 0); 
        NMODEL_SYN_QFACTOR         : out STD_LOGIC_VECTOR(15 DOWNTO 0); 
        NMODEL_PF_LOW_ADDR         : out STD_LOGIC_VECTOR(9  DOWNTO 0); 
        NMODEL_NPARAM_DATA         : out STD_LOGIC_VECTOR(15 DOWNTO 0);
        NMODEL_NPARAM_ADDR         : out STD_LOGIC_VECTOR(9  DOWNTO 0);
        NMODEL_REFRACTORY_DUR      : out std_logic_vector(7  downto 0);
        NMODEL_PROG_MEM_PORTA_EN   : out STD_LOGIC;
        NMODEL_PROG_MEM_PORTA_WEN  : out STD_LOGIC;
        R_NNMODEL_NEW_SPIKE_TIME   : in  std_logic_vector(7  downto 0);
        R_NMODEL_NPARAM_DATAOUT    : in  STD_LOGIC_VECTOR(15 DOWNTO 0);
        R_NMODEL_REFRACTORY_DUR    : in  std_logic_vector(7  downto 0);
        REDIST_NMODEL_PORTB_TKOVER : out std_logic;
        REDIST_NMODEL_DADDR        : out std_logic_vector(9 downto 0);
        NMC_NMODEL_FINISHED        : in  std_logic;
        -- SYNAPTIC RAM MANAGEMENT
        SYNMEM_PORTA_MUX           : out std_logic;
        -- ULEARN CONTROLS
        DISABLE_LENGINE            : out std_logic;
        ACTVATE_LENGINE            : out std_logic;
        LEARN_RST                  : out std_logic;
        SYNAPSE_PRUN               : out std_logic; -- 1-Bit
        PRUN_THRESH                : out std_logic_vector(7 downto 0); -- 8-Bit
        IGNORE_ZEROS               : out std_logic; -- 1-Bit
        IGNORE_SOFTLIM             : out std_logic; -- 1-Bit 
        LEARNING_RATE              : out std_logic_vector(7 downto 0); -- 8-Bit
        TABLE_LOW_ADDRESS          : out std_logic_vector(15 downto 0); -- 10-Bit
        NEURON_WMAX                : out std_logic_vector(7 downto 0); -- 8-Bit
        NEURON_WMIN                : out std_logic_vector(7 downto 0); -- 8-Bit
        NEURON_SPK_TIME            : out std_logic_vector(7 downto 0); -- 8-Bit
        -- NEURAL MEMORY INTERFACE
        addra                      : out std_logic_vector((clogb2(NEURAL_MEM_DEPTH)-1) downto 0); 
        wea                        : out std_logic;	                
        ena                        : out std_logic;                       			     
        rsta                       : out std_logic;                       			     
        douta                      : in  std_logic_vector(31 downto 0);            
        dina                       : out std_logic_vector(31 downto 0)            

        );
end BRIDGE;

architecture crush_with_eyeliner of BRIDGE is

    type STATES is (SLEEP,SET_NETWORK_START_ADDRESS,LOAD_NEURON,INFERENCE,NEW_WAVE,SYNAPTIC_CURRENT_ACC,DARK_SIDE,NMC_STATE,BS2
                    ,SWAP,SWAPRFPLST,READNPARAMADDR,UPDATE_TIMESTEP,SHAPEUP,BS3,BS1,WAITNPARAMDATA,WAITNPARAMDATA1,WAITNPARAMDATA2
                    ,READNPARAMDATA,BREWNPARAM,LEARNING_PARAM_FETCH,UPDATE_SYNAPSES,POSTSYNDLY1,POSTSYNDLY2);
                    
    signal BRIDGE_STATE : STATES;
  
    constant SYNLOW               : std_logic_vector(3 downto 0) := "0001";
    constant SYNHIGH              : std_logic_vector(3 downto 0) := "0010";
    constant REFPLST              : std_logic_vector(3 downto 0) := "0011";
    constant PFLOWSYNQ            : std_logic_vector(3 downto 0) := "0100";
    constant NPADDRDATA           : std_logic_vector(3 downto 0) := "0101";
    constant ULEARNPARAMS         : std_logic_vector(3 downto 0) := "0110";
    constant TABLELOWLRATE        : std_logic_vector(3 downto 0) := "0111";
    constant ULEARNLOWSYNADDR     : std_logic_vector(3 downto 0) := "1000";
    constant ULEARNHIGHSYNADDR    : std_logic_vector(3 downto 0) := "1001";
    constant ENDFLOW              : std_logic_vector(3 downto 0) := "1010";

    -- SSSDSYNQ            "1"
    -- SYNHIGH "2"
    -- SYNLOW "3"
    -- PFLOWRFPLST "4"
    -- NPADDRDATA "5"
    -- ULEARNPARAMS "6"
    -- TABLELOWLRATE "7"
    -- ULEARNLOWSYNADDR "8"
    -- ULEARNHIGHSYNADDR "9"
    -- ENDFLOW "10"
    
    signal  MEMLOC                : integer;
    
    signal  DTYPE                 : std_logic_vector(3 downto 0);
    
    signal  NEURON_SPACE          : integer;
    signal  MEMORY_LATENCY        : integer;
        
    constant SYNAPSE_BATCH_SIZE   : integer := ROW;
    
    signal NEXT_IN_LINE           : std_logic_vector(2 downto 0);
    
    signal PULL_FIRST_BATCH       : std_logic;
    signal LAST_BATCH             : std_logic;    
    
    signal NEURON_LOADED          : std_logic;
    signal PULLSYNAPSES           : std_logic;
    
    signal SYNAPSES_LOADED        : std_logic;

    signal SYNAPSE_LOW_ADDRESS    : integer range 0 to SYNAPSE_MEM_DEPTH-1;
    signal SYNAPSE_HIGH_ADDRESS   : integer range 0 to SYNAPSE_MEM_DEPTH-1;
    signal SYNAPSE_LOCATION       : integer range 0 to SYNAPSE_MEM_DEPTH-1;
    signal SYNAPSE_LOCATION_PAST  : integer range 0 to SYNAPSE_MEM_DEPTH-1;
    signal SYNAPSE_LOCATION_PAST_2: integer range 0 to SYNAPSE_MEM_DEPTH-1;
    signal DLYCNTR                : integer range 0 to NEURAL_MEM_DEPTH-1;

    
    signal EVENT_ACCEPTANCE_REG   : std_logic;
    
    signal SYNAPSE_PULL_TIMEOUT   : integer;
    
    signal CURRENT_ACC_DLYCNTR    : integer;

    signal SWAP_DBUFFER           : std_logic_vector(15 downto 0);
    signal SWAP_ABUFFER           : std_logic_vector(9 downto 0);
       
    signal POSTSYNDLYCNTR         : integer;
    
begin

    addra <= std_logic_vector(to_unsigned(MEMLOC,addra'length));
    DTYPE <= douta(31 downto 28);
    
    EVENT_ACCEPTANCE           <= EVENT_ACCEPTANCE_REG;
    
    SYNAPTIC_MEM_RDADDR        <= std_logic_vector(to_unsigned(SYNAPSE_LOCATION,SYNAPTIC_MEM_RDADDR'length));
    SYNAPTIC_MEM_WRADDR        <= std_logic_vector(to_unsigned(SYNAPSE_LOCATION_PAST_2,SYNAPTIC_MEM_WRADDR'length));


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
                        SYNAPTIC_MEM_ENABLE        <= '0'; 
                        SYNAPTIC_MEM_WREN          <= '0'; 
                        HALT_HYPERCOLUMN           <= '0'; 
                        PRE_SYN_DATA_PULL          <= '0'; 
                        DISABLE_COLUMN             <= '0'; 
                        NMC_STATE_RST              <= '1';  
                        NMC_FMAC_RST               <= '0';  
                        NMC_COLD_START             <= '0';  
                        NMODEL_LAST_SPIKE_TIME     <= (others=>'0');
                        NMODEL_SYN_QFACTOR         <= (others=>'0');
                        NMODEL_PF_LOW_ADDR         <= (others=>'0');
                        NMODEL_NPARAM_DATA         <= (others=>'0');
                        NMODEL_NPARAM_ADDR         <= (others=>'0');
                        NMODEL_REFRACTORY_DUR      <= (others=>'0');
                        NMODEL_PROG_MEM_PORTA_EN   <= '0'; 
                        NMODEL_PROG_MEM_PORTA_WEN  <= '0'; 
                        REDIST_NMODEL_PORTB_TKOVER <= '0'; 
                        REDIST_NMODEL_DADDR        <= (others=>'0');
                        SYNMEM_PORTA_MUX           <= '0'; 
                        ACTVATE_LENGINE            <= '0'; 
                        LEARN_RST                  <= '1'; 
                        SYNAPSE_PRUN               <= '0'; 
                        PRUN_THRESH                <= (others=>'0');
                        IGNORE_ZEROS               <= '0';  
                        IGNORE_SOFTLIM             <= '0';   
                        LEARNING_RATE              <= (others=>'0');
                        TABLE_LOW_ADDRESS          <= (others=>'0');
                        NEURON_WMAX                <= (others=>'0');
                        NEURON_WMIN                <= (others=>'0');
                        NEURON_SPK_TIME            <= (others=>'0');
                        wea                        <= '0';               
                        ena                        <= '1';                     			     
                        rsta                       <= '1';                     			     
                        dina                       <= (others=>'0');
                        
                        MEMLOC                     <= 0;
                        NEURON_SPACE               <= 0;
                        SYNAPSE_LOW_ADDRESS        <= 0;
                        SYNAPSE_HIGH_ADDRESS       <= 0;
                        MEMORY_LATENCY             <= 0;
                        
                        PULL_FIRST_BATCH           <= '0';
                        NEURON_LOADED              <= '0';
                        PULLSYNAPSES               <= '0';
                        
                        EVENT_ACCEPTANCE_REG       <= '0';
                        
                        SYNAPSE_PULL_TIMEOUT       <=  0;
                        
                        CURRENT_ACC_DLYCNTR        <=  0;
                        
                        POSTSYNDLYCNTR             <=  0;
                        
                        SYNAPSE_LOCATION           <=  0;
                        SYNAPSE_LOCATION_PAST_2    <=  0;
                        
                        
                        if GT_START = '1' then
                            BRIDGE_STATE <= SET_NETWORK_START_ADDRESS;
                        else
                            BRIDGE_STATE <= SLEEP;
                        end if;
                
                when SET_NETWORK_START_ADDRESS =>
                
                        MEMLOC <= to_integer(unsigned(NETWORK_LOW_ADDRESS));
                        BRIDGE_STATE <= LOAD_NEURON;
                
                when LOAD_NEURON =>
                
                        if DTYPE = SYNLOW then
                        
                            SYNAPSE_LOW_ADDRESS <= to_integer(unsigned(douta(15 downto 0)));
                            NMODEL_NPARAM_DATA  <= (others=>'0');
                            NMODEL_NPARAM_ADDR  <= (others=>'0');
                            NMODEL_PROG_MEM_PORTA_EN  <= '0';
                            NMODEL_PROG_MEM_PORTA_WEN <= '0';
                                                    
                            PULL_FIRST_BATCH           <= '0';
                            
                            if(MEMORY_LATENCY = 1) then
                                NEURON_SPACE   <= NEURON_SPACE + 1;
                                MEMLOC         <= MEMLOC + 1;
                                MEMORY_LATENCY <= 0;
                            else
                            
                                MEMORY_LATENCY <= MEMORY_LATENCY + 1;
                            end if;
                            
                        elsif DTYPE = ULEARNHIGHSYNADDR then

                            if(MEMORY_LATENCY = 1) then               
                                NEURON_SPACE <= NEURON_SPACE + 1;
                                MEMLOC       <= MEMLOC + 1;
                                MEMORY_LATENCY   <= 0;                
                            else 
                                MEMORY_LATENCY <= MEMORY_LATENCY + 1;
                            end if;  

                        elsif DTYPE = ULEARNLOWSYNADDR then

                            if(MEMORY_LATENCY = 1) then               
                                NEURON_SPACE <= NEURON_SPACE + 1;
                                MEMLOC       <= MEMLOC + 1;
                                MEMORY_LATENCY   <= 0;                
                            else 
                                MEMORY_LATENCY <= MEMORY_LATENCY + 1;
                            end if;  
                        
                        elsif DTYPE = SYNHIGH then
                        
                            SYNAPSE_HIGH_ADDRESS <= to_integer(unsigned(douta(15 downto 0)));   
                            NMC_FMAC_RST              <= '1';
                            PULL_FIRST_BATCH          <= '1';
                            READ_MAIN_SPIKE_BUFFER    <= douta(16) ;
                            READ_CIRCULAR_BUFFER      <= douta(17) ;
                            WRITE_OUTBUFFER           <= '1'; 
                            
                            if(MEMORY_LATENCY = 1) then
                                NEURON_SPACE   <= NEURON_SPACE + 1;
                                MEMLOC         <= MEMLOC + 1;
                                MEMORY_LATENCY <= 0;
                            else
                            
                                MEMORY_LATENCY <= MEMORY_LATENCY + 1;
                            end if;
                                                        
                        elsif DTYPE = REFPLST then  
                                           
                            NMODEL_LAST_SPIKE_TIME    <= douta(7  downto  0);
                            NMODEL_REFRACTORY_DUR     <= douta(15 downto  8);

                            NMC_FMAC_RST              <= '0';

                            if(MEMORY_LATENCY = 1) then
                                NEURON_SPACE <= NEURON_SPACE + 1;
                                MEMLOC      <= MEMLOC + 1;
                                MEMORY_LATENCY   <= 0;
                            else
                            
                                MEMORY_LATENCY <= MEMORY_LATENCY + 1;
                            end if;
                                
                        elsif DTYPE = PFLOWSYNQ then
                        
                            NMODEL_PF_LOW_ADDR        <= douta(25 downto 16);
                            NMODEL_SYN_QFACTOR        <= douta(15 downto  0);
                            NMODEL_PROG_MEM_PORTA_EN  <= '0';
                            NMODEL_PROG_MEM_PORTA_WEN <= '0';
                            NMODEL_NPARAM_DATA        <= (others=>'0');
                            NMODEL_NPARAM_ADDR        <= (others=>'0');
                            
                            if(MEMORY_LATENCY = 1) then
                                NEURON_SPACE <= NEURON_SPACE + 1;
                                MEMLOC       <= MEMLOC + 1;
                                MEMORY_LATENCY   <= 0;
                            else
                                MEMORY_LATENCY <= MEMORY_LATENCY + 1;
                            end if;

                        elsif DTYPE = ULEARNPARAMS then

                             if(MEMORY_LATENCY = 1) then
                                 NEURON_SPACE <= NEURON_SPACE + 1;
                                 MEMLOC       <= MEMLOC + 1;
                                 MEMORY_LATENCY   <= 0;
                             else
                                 MEMORY_LATENCY <= MEMORY_LATENCY + 1;
                             end if;
                        
                        elsif DTYPE = TABLELOWLRATE then  
                                 
                             if(MEMORY_LATENCY = 1) then
                                 NEURON_SPACE <= NEURON_SPACE + 1;
                                 MEMLOC       <= MEMLOC + 1;
                                 MEMORY_LATENCY   <= 0;
                             else
                                 MEMORY_LATENCY <= MEMORY_LATENCY + 1;
                             end if;         
                             
                        elsif DTYPE = NPADDRDATA then
                        
                            NMODEL_NPARAM_DATA        <= douta(15 downto 0);
                            NMODEL_NPARAM_ADDR        <= douta(25 downto 16);

                            NMODEL_PROG_MEM_PORTA_EN  <= '1';
                            NMODEL_PROG_MEM_PORTA_WEN <= '1';

                            if(MEMORY_LATENCY = 1) then               
                                NEURON_SPACE <= NEURON_SPACE + 1;
                                MEMLOC       <= MEMLOC + 1;
                                MEMORY_LATENCY   <= 0;                
                            else 
                                MEMORY_LATENCY <= MEMORY_LATENCY + 1;
                            end if;                        
                        
                        elsif DTYPE = ENDFLOW then
                        
                            NMODEL_PROG_MEM_PORTA_EN  <= '0';
                            NMODEL_PROG_MEM_PORTA_WEN <= '0';
                            ena                       <= '0';                                
                            MEMLOC                    <= MEMLOC;
                            NEURON_SPACE              <= NEURON_SPACE;
                            NEXT_IN_LINE              <= douta(2 downto 0);
                            NMODEL_NPARAM_DATA        <= (others=>'0');
                            NMODEL_NPARAM_ADDR        <= (others=>'0');
                            NEURON_LOADED             <= '1';
                                                    
                        end if;
                        
                         
                        if PULL_FIRST_BATCH = '1' and PULLSYNAPSES = '0' then
                          
                                PULLSYNAPSES        <= '1';
                                SYNAPSE_LOCATION    <=  SYNAPSE_LOW_ADDRESS;
                                SYNAPTIC_MEM_ENABLE <= '1';
                                SYNAPSES_LOADED     <= '0';
                                
                        end if;
                          
                        if(PULLSYNAPSES = '1') then
                         
                           if SYNAPSE_LOCATION = SYNAPSE_BATCH_SIZE + SYNAPSE_LOW_ADDRESS then 
                               PULLSYNAPSES          <= '0';
                               PULL_FIRST_BATCH      <= '0';
                               SYNAPSES_LOADED       <= '1';
                               LAST_BATCH            <= '0';
                               PRE_SYN_DATA_PULL     <= '0';
                           elsif SYNAPSE_LOCATION = SYNAPSE_HIGH_ADDRESS then 
                               PULLSYNAPSES          <= '0';
                               PULL_FIRST_BATCH      <= '0';
                               SYNAPSES_LOADED       <= '1';    
                               LAST_BATCH            <= '1';
                               PRE_SYN_DATA_PULL     <= '0'; 
                           else
                               SYNAPSE_LOCATION      <= SYNAPSE_LOCATION + 1;
                               PRE_SYN_DATA_PULL     <= '1';
                               SYNAPTIC_MEM_ENABLE   <= '1';
                               SYNAPSES_LOADED       <= '0';
                           end if;
                                                                              
                        end if;
                        
                        if(NEURON_LOADED = '1' and SYNAPSES_LOADED = '1') then
                        
                                BRIDGE_STATE            <= INFERENCE;
                                PULLSYNAPSES            <= '0';
                                PRE_SYN_DATA_PULL       <= '0';
                                NEURON_LOADED           <= '0';
                                SYNAPSES_LOADED         <= '0';
                                SYNAPSE_LOCATION_PAST_2 <= SYNAPSE_LOW_ADDRESS;
                                EVENT_ACCEPTANCE_REG    <= '1';

                        else
        
                            	BRIDGE_STATE          <= LOAD_NEURON;
                            	SYNAPSE_LOCATION_PAST <= SYNAPSE_LOCATION;

                        end if;                                                         
    
                when INFERENCE =>

                    if(EVENT_DETECT = '1' and EVENT_ACCEPTANCE_REG = '1' and LAST_BATCH = '0') then
                    
                       MEMORY_LATENCY          <= 0;                                      
                       SYNAPSE_LOCATION_PAST_2 <= SYNAPSE_LOCATION_PAST;
                       EVENT_ACCEPTANCE_REG    <= '0';
                       SYNAPTIC_MEM_WREN       <= '0';
                       PRE_SYN_DATA_PULL       <= '0';
                       BRIDGE_STATE            <= NEW_WAVE;
                    
                    elsif(EVENT_DETECT = '1' and EVENT_ACCEPTANCE_REG = '1' and LAST_BATCH = '1') then
                    
                        MEMORY_LATENCY        <= 0;                                      
                        PRE_SYN_DATA_PULL     <= '0';
                        SYNAPTIC_MEM_WREN     <= '0';
                        PULL_FIRST_BATCH      <= '0';
                        BRIDGE_STATE          <= SYNAPTIC_CURRENT_ACC;
                        EVENT_ACCEPTANCE_REG  <= '0';
                       
                    else
                    
                        BRIDGE_STATE <= INFERENCE;

                    end if;

        
                when DARK_SIDE =>
                
                    BRIDGE_STATE          <= INFERENCE;
                    EVENT_ACCEPTANCE_REG  <= '1';
                    PRE_SYN_DATA_PULL   <= '0';
                    
                when NEW_WAVE =>
                
                    --if( SYNAPSE_PULL_TIMEOUT = SYNAPSE_BATCH_SIZE) then
                    --
                    --    BRIDGE_STATE          <= DARK_SIDE;
                    --    SYNAPSE_PULL_TIMEOUT  <= 0;
                    --    PRE_SYN_DATA_PULL     <= '0';
                    --    
                    --else
                    --
                    --    SYNAPSE_PULL_TIMEOUT <= SYNAPSE_PULL_TIMEOUT +1;
                    --    
                    --end if;

                    if SYNAPSE_LOCATION = SYNAPSE_BATCH_SIZE + SYNAPSE_LOCATION_PAST then 

                        SYNAPTIC_MEM_WREN     <= '0';
                        PULL_FIRST_BATCH      <= '0';
                        SYNAPSE_LOCATION_PAST <= SYNAPSE_LOCATION;
                        LAST_BATCH            <= '0';
                        BRIDGE_STATE          <= DARK_SIDE;
                       -- PRE_SYN_DATA_PULL   <= '0';
                        
                    elsif SYNAPSE_LOCATION = SYNAPSE_HIGH_ADDRESS then 
                    
                         LAST_BATCH            <= '1';
                         SYNAPTIC_MEM_WREN     <= '0';
                         PULL_FIRST_BATCH   <= '0';
                         BRIDGE_STATE          <= DARK_SIDE;
                         --PRE_SYN_DATA_PULL   <= '0';

                    else
                        SYNAPSE_LOCATION    <= SYNAPSE_LOCATION + 1;
                        PRE_SYN_DATA_PULL   <= '1';
                        SYNAPTIC_MEM_ENABLE <= '1';
                        SYNAPTIC_MEM_WREN   <= '1';
                       
                    end if;

                when SYNAPTIC_CURRENT_ACC =>

                    if(CURRENT_ACC_DLYCNTR = ROW) then
                                                
                         BRIDGE_STATE  <= NMC_STATE;
                         EVENT_ACCEPTANCE_REG      <= '0';
                         NMC_COLD_START <= '1';
                         CURRENT_ACC_DLYCNTR <= 0;

                    elsif(CURRENT_ACC_DLYCNTR = ROW-2) then
                    
                        NMC_STATE_RST <= '0';
                        CURRENT_ACC_DLYCNTR <= CURRENT_ACC_DLYCNTR + 1; 

                    elsif(CURRENT_ACC_DLYCNTR = ROW-3) then
                    
                        NMC_STATE_RST <= '1';
                        CURRENT_ACC_DLYCNTR <= CURRENT_ACC_DLYCNTR + 1;

                    else
                    
                        CURRENT_ACC_DLYCNTR <= CURRENT_ACC_DLYCNTR + 1;
                        BRIDGE_STATE        <= SYNAPTIC_CURRENT_ACC;
                    end if;
                    
                when NMC_STATE =>
                
                    NMC_COLD_START <= '0';
                                                
                    if(NMC_NMODEL_FINISHED = '1') then
                        BRIDGE_STATE   <= BS2;
                        MEMLOC         <= MEMLOC - NEURON_SPACE;
                        ena            <= '1';
                        DLYCNTR        <=  0;
                        wea            <= '0';
                        MEMORY_LATENCY <=  0;
                        SWAP_DBUFFER   <= (others=>'0');
                        SWAP_ABUFFER   <= (others=>'0');
                    else
                        BRIDGE_STATE      <= NMC_STATE;
                    end if;                    

                when SWAP =>                         
                                                         
                    if DTYPE = REFPLST          then
                    
                        BRIDGE_STATE  <= SWAPRFPLST;

                    elsif DTYPE = NPADDRDATA   then
                    
                        BRIDGE_STATE  <= READNPARAMADDR;
                            
                    elsif DTYPE = ENDFLOW      then

                         MEMLOC       <= MEMLOC;
                         wea          <= '0';
                         
                         if(NEXT_IN_LINE = "000") then
                         
                            BRIDGE_STATE  <= UPDATE_TIMESTEP;                             
                         
                         elsif(NEXT_IN_LINE = "001") then
                         
                            BRIDGE_STATE  <= SHAPEUP;
                            MEMLOC        <= MEMLOC + 1;
                            NEURON_SPACE   <=  0;

                         elsif(NEXT_IN_LINE = "010") then
                         
                            SYNMEM_PORTA_MUX <= '1';
                            BRIDGE_STATE     <= BS3;
                            MEMLOC           <= 0;
                            ACTVATE_LENGINE  <= '0';

                         end if;
                         
                    else
                           wea          <= '0';
                           BRIDGE_STATE <= BS1;
                    end if;

                when SWAPRFPLST =>  
                
                    dina(31 downto 28) <= REFPLST;
                    dina(27 downto 16) <= (others=>'0');
                    dina(15 downto  8) <= R_NMODEL_REFRACTORY_DUR;
                    dina(7 downto   0) <= R_NNMODEL_NEW_SPIKE_TIME;
                    wea                <= '1';
                    BRIDGE_STATE  <= BS1;
                
                when READNPARAMADDR =>
                
                    REDIST_NMODEL_DADDR        <= douta(25 downto 16);
                    REDIST_NMODEL_PORTB_TKOVER <= '1';
                    SWAP_ABUFFER <= douta(25 downto 16);
                    BRIDGE_STATE  <= WAITNPARAMDATA;

                when WAITNPARAMDATA =>
                
                    BRIDGE_STATE  <= WAITNPARAMDATA1;

                when WAITNPARAMDATA1 =>
                
                    BRIDGE_STATE  <= WAITNPARAMDATA2;
                         
                when WAITNPARAMDATA2 =>
                
                    BRIDGE_STATE  <= READNPARAMDATA;                             

                when READNPARAMDATA =>
                
                    BRIDGE_STATE  <= BREWNPARAM;
                    SWAP_DBUFFER <= R_NMODEL_NPARAM_DATAOUT;

                when BREWNPARAM =>
                
                    dina(31 downto 28) <= NPADDRDATA;
                    dina(27 downto 26) <= (others=>'0');
                    dina(25 downto 16) <= SWAP_ABUFFER;
                    dina(15 downto  0) <= SWAP_DBUFFER;
                    wea                <= '1';
                    BRIDGE_STATE       <= BS1;
                                                     
                when BS1 =>
                
                    BRIDGE_STATE  <= BS2;
                    MEMLOC        <= MEMLOC + 1;
                    wea           <= '0';
                    REDIST_NMODEL_PORTB_TKOVER <= '0';
                           
                when BS2 =>
                
                    BRIDGE_STATE  <= SWAP;
                        
                when BS3 =>
                
                    if SKIP_LEARNING_PROCESS = '1' then
                
                        BRIDGE_STATE     <= UPDATE_TIMESTEP;
                        MEMLOC           <= to_integer(unsigned(NETWORK_LOW_ADDRESS));
                    
                    else
                    
                        BRIDGE_STATE     <= LEARNING_PARAM_FETCH;
                        MEMLOC           <= to_integer(unsigned(NETWORK_LOW_ADDRESS));
                    
                    end if;

                when SHAPEUP =>
                
                    BRIDGE_STATE  <= LOAD_NEURON;
                    NMC_COLD_START <= '0';
                    MEMORY_LATENCY <= 0;
         
                 when LEARNING_PARAM_FETCH =>  
                 
                    HALT_HYPERCOLUMN <= '1';
                    NMC_STATE_RST    <= '1';
                    SYNMEM_PORTA_MUX <= '1';
                    wea          <= '0';

                    if    DTYPE = SYNLOW       then
                    
                        if(MEMORY_LATENCY = 1) then
                            MEMLOC      <= MEMLOC + 1;
                            MEMORY_LATENCY   <= 0;
                        else
                        
                            MEMORY_LATENCY <= MEMORY_LATENCY + 1;
                        end if;

                    elsif DTYPE = SYNHIGH  then
                     
                        if(MEMORY_LATENCY = 1) then
                            MEMLOC      <= MEMLOC + 1;
                            MEMORY_LATENCY   <= 0;
                        else
                        
                            MEMORY_LATENCY <= MEMORY_LATENCY + 1;
                        end if;
                             
                    elsif DTYPE = REFPLST          then
                     
                        NEURON_SPK_TIME    <= douta(7  downto  0);

                        if(MEMORY_LATENCY = 1) then
                            MEMLOC      <= MEMLOC + 1;
                            MEMORY_LATENCY   <= 0;
                        else
                        
                            MEMORY_LATENCY <= MEMORY_LATENCY + 1;
                        end if;
             
                    elsif DTYPE = PFLOWSYNQ  then
                     
                        if(MEMORY_LATENCY = 1) then
                            MEMLOC      <= MEMLOC + 1;
                            MEMORY_LATENCY   <= 0;
                        else
                        
                            MEMORY_LATENCY <= MEMORY_LATENCY + 1;
                        end if;
 
                     elsif DTYPE = NPADDRDATA  then
                     
                        if(MEMORY_LATENCY = 1) then
                            MEMLOC      <= MEMLOC + 1;
                            MEMORY_LATENCY   <= 0;
                        else
                        
                            MEMORY_LATENCY <= MEMORY_LATENCY + 1;
                        end if;
             
                    elsif DTYPE = ULEARNPARAMS then
                             
                        SYNAPSE_PRUN               <= douta(26);
                        PRUN_THRESH                <= douta(7 downto  0);
                        IGNORE_ZEROS               <= douta(25);
                        IGNORE_SOFTLIM             <= douta(24);  
                        NEURON_WMAX                <= douta(23 downto 16);
                        NEURON_WMIN                <= douta(15 downto  8);

                        if(MEMORY_LATENCY = 1) then
                            MEMLOC           <= MEMLOC + 1;
                            MEMORY_LATENCY   <= 0;
                        else
                        
                            MEMORY_LATENCY <= MEMORY_LATENCY + 1;
      
                        end if;
           
                    elsif DTYPE = TABLELOWLRATE then  
                    
                        LEARNING_RATE     <= douta(7 downto 0);
                        TABLE_LOW_ADDRESS <= douta(23 downto 8);
                                 
                        if(MEMORY_LATENCY = 1) then
                            NEURON_SPACE <= NEURON_SPACE + 1;
                            MEMLOC       <= MEMLOC + 1;
                            MEMORY_LATENCY   <= 0;
                        else
                            MEMORY_LATENCY <= MEMORY_LATENCY + 1;
                        end if;    

                    elsif DTYPE = ULEARNLOWSYNADDR then  
                    
                        SYNAPSE_LOW_ADDRESS       <= to_integer(unsigned(douta(15 downto 0)));
                                 
                        if(MEMORY_LATENCY = 1) then
                        
                            NEURON_SPACE <= NEURON_SPACE + 1;
                            MEMLOC       <= MEMLOC + 1;
                            MEMORY_LATENCY   <= 0;
                        else
                            MEMORY_LATENCY <= MEMORY_LATENCY + 1;
                        end if; 

                    elsif DTYPE = ULEARNHIGHSYNADDR then  
                    
                        SYNAPSE_HIGH_ADDRESS      <= to_integer(unsigned(douta(15 downto 0)));
                        LEARN_RST                 <= '0';
                        
                        SYNAPSE_LOCATION          <= SYNAPSE_LOW_ADDRESS;
                        SYNAPSE_LOCATION_PAST_2   <= SYNAPSE_LOW_ADDRESS;
                        
                        --ACTVATE_LENGINE  <= '1'; 
                        MEMORY_LATENCY   <= 0;
                        BRIDGE_STATE     <= UPDATE_SYNAPSES;
                        
                        --if(MEMORY_LATENCY = 1) then
                        --
                        --    NEURON_SPACE <= NEURON_SPACE + 1;
                        --    MEMLOC       <= MEMLOC + 1;
                        --    ACTVATE_LENGINE  <= '1'; 
                        --    MEMORY_LATENCY   <= 0;
                        --    BRIDGE_STATE     <= UPDATE_SYNAPSES;
                        --else
                        --    MEMORY_LATENCY <= MEMORY_LATENCY + 1;
                        --end if; 
                                          
                    else

                        if(MEMORY_LATENCY = 1) then
                            MEMLOC      <= MEMLOC + 1;
                            MEMORY_LATENCY   <= 0;
                        else
                        
                            MEMORY_LATENCY <= MEMORY_LATENCY + 1;
                        end if;  
                                                           
                    end if;                       
                                 
                when POSTSYNDLY1 =>        
                
                   -- ACTVATE_LENGINE <= '0';
                                        
                    if(MEMORY_LATENCY = 1) then
                        MEMLOC           <= MEMLOC + 1;
                        MEMORY_LATENCY   <= 0;
                        ACTVATE_LENGINE <= '0';
                        BRIDGE_STATE     <= POSTSYNDLY2;
                        POSTSYNDLYCNTR   <= 0; 
                        
                    else
                    
                        MEMORY_LATENCY <= MEMORY_LATENCY + 1;
                    end if;  
                
                when POSTSYNDLY2 =>  
                                         
                    --ACTVATE_LENGINE <= '0';
    
                    if(POSTSYNDLYCNTR = 13) then
                                                     
                       if DTYPE = ULEARNPARAMS then
                       
                            BRIDGE_STATE  <= LEARNING_PARAM_FETCH;
                       
                       elsif DTYPE = ENDFLOW then
                       
                            if douta(2 downto 0) = "001" then
                                BRIDGE_STATE  <= LEARNING_PARAM_FETCH;
                            elsif douta(2 downto 0) = "010" then 
                                BRIDGE_STATE  <= UPDATE_TIMESTEP;
                            elsif douta(2 downto 0) = "010" then 
                                BRIDGE_STATE  <= UPDATE_TIMESTEP;                          
                            end if;
                       
                       end if;
                            
                    else
                    
                       POSTSYNDLYCNTR <= POSTSYNDLYCNTR + 1;
                    
                    end if;

                when UPDATE_SYNAPSES =>  
                
                        if(MEMORY_LATENCY = 1) then

                            ACTVATE_LENGINE  <= '1'; 
                            MEMORY_LATENCY   <= 0;
  
                        else
                            MEMORY_LATENCY <= MEMORY_LATENCY + 1;
                        end if; 

                    if SYNAPSE_LOCATION = SYNAPSE_HIGH_ADDRESS then 
                    
                         BRIDGE_STATE     <= POSTSYNDLY1;
                         POSTSYNDLYCNTR   <= 0;
                         MEMORY_LATENCY   <= 0;
                    else
                                            
                        SYNAPSE_LOCATION    <= SYNAPSE_LOCATION + 1;
                        SYNAPTIC_MEM_ENABLE <= '1';
                        
                    end if;
     
                when UPDATE_TIMESTEP =>
                
                     GT_COMPLETED <= '1';       
                     
                     if GT_START = '1' then
                        BRIDGE_STATE     <= SLEEP;
                     else
                        BRIDGE_STATE     <= UPDATE_TIMESTEP;
                     end if;
                
                when others =>
                                    NULL;                   
            end case;
        
        end if;
    
    end if;

end process MSM;
 

end crush_with_eyeliner;
