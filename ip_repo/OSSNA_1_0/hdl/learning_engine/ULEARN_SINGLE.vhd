
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

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

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.nmemportdef.all;

-- New fully pipelined architecture.

entity ULEARN_SINGLE is
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
end ULEARN_SINGLE;

architecture society of ULEARN_SINGLE is				

    type RAM is array (LUT_DEPTH-1 downto 0) of std_logic_vector(7 downto 0);
    signal ULEARN_LUT : RAM;
    
    attribute ram_style : string;
    attribute ram_style of ULEARN_LUT : signal is LUT_TYPE;
    
    signal WMAX : signed(8 downto 0);
    signal WMIN : signed(8 downto 0);
    
    signal PTRESH : signed(7 downto 0);
                
    signal WRADDRSTART : integer range 0 to SYNAPSE_MEM_DEPTH-1;      
    
    signal COEFF_INT   : integer range -256 to 255;  
    signal SYNAPSE_INT : integer range -256 to 255;  
    
    signal COEFF_INT_1   : integer range -512 to 511;  
    signal COEFF_INT_2   : integer range -256 to 255;  
    signal SYNAPSE_INT_1 : integer range -256 to 255;  
    signal LR_INT : integer range -256 to 255;  
            
    signal WNEW : integer range -256 to 255;      
    signal WNEW_P1 : integer range -256 to 255;      
          
    signal WMAX_INT : integer;    
    signal WMIN_INT : integer;    
    signal LUT_LOW_INT : integer;    
    
    signal SKIP_SYNAPSE_P0 : std_logic;
    signal SKIP_SYNAPSE_P1 : std_logic;
    signal SKIP_SYNAPSE_P2 : std_logic;
        
    signal POST_SYNAPTIC_FLAG : std_logic;
    
    signal WC_COEFF   : signed(7 downto 0);
    
    constant POST_SYNAPTIC_TRACE_OFFSET : integer := 128;
    
    signal SYN_P0 : std_logic_vector(7 downto 0);
    signal TMP_P0 : std_logic_vector(7 downto 0);

    signal SYN_P1 : std_logic_vector(7 downto 0);
    signal TMP_P1 : std_logic_vector(7 downto 0);

    signal SYN_P2 : std_logic_vector(7 downto 0);
    signal TMP_P2 : std_logic_vector(7 downto 0);

    signal SYN_P3 : std_logic_vector(7 downto 0);
    signal TMP_P3 : std_logic_vector(7 downto 0);

    signal TMP_P4 : std_logic_vector(7 downto 0);
    signal TMP_P5 : std_logic_vector(7 downto 0);
    
    signal TMP_P6 : std_logic_vector(7 downto 0);
    
    signal TMP_P7 : std_logic_vector(7 downto 0);
    
    signal TMP_P8 : std_logic_vector(7 downto 0);
    signal SYN_P8 : std_logic_vector(7 downto 0);
   
    signal VLD_DLY_1  : std_logic;
    signal VLD_DLY_2  : std_logic;
    signal VLD_DLY_3  : std_logic;
    signal VLD_DLY_4  : std_logic;
    signal VLD_DLY_5  : std_logic;
    signal VLD_DLY_6  : std_logic;
    signal VLD_DLY_7  : std_logic;
    signal VLD_DLY_8  : std_logic;
    signal VLD_DLY_9  : std_logic;
    signal VLD_DLY_10  : std_logic;

    
begin

    WMAX_INT <= to_integer(signed(NMODEL_WMAX));   
    WMIN_INT <= to_integer(signed(NMODEL_WMIN));   
    
    POST_SYNAPTIC_FLAG <= '1' when NMODEL_SPIKE_TIME = X"00" else
                          '0';

    LR_INT <= to_integer(unsigned(LEARNING_RATE));

    LUT_LOW_INT <= to_integer(unsigned(LUT_LOW_ADDRESS));

    LIMITS : process(ULEARN_CLK)
        begin
            if(rising_edge(ULEARN_CLK)) then
            
                if(ULEARN_RST = '1') then

                    WMAX    <= (others=>'0');
                    WMIN    <= (others=>'0');
                    PTRESH  <= (others=>'0');
                
                else
                        
                    WMAX   <= signed(NMODEL_WMAX(7)&NMODEL_WMAX);
                    WMIN   <= signed(NMODEL_WMIN(7)&NMODEL_WMIN);
                    PTRESH <= signed(PRUN_THRESHOLD);
                end if;
            
            end if;
    end process LIMITS;
    
    
    INPUT_PP : process(ULEARN_CLK)
        begin
            if(rising_edge(ULEARN_CLK)) then
            
                if(ULEARN_RST = '1') then

                    SYN_P0 <= (others=>'0');
                    TMP_P0 <= (others=>'0');
                
                else
                        
                    SYN_P0 <= SYN_DATA_IN(15 downto  8);
                    TMP_P0 <= SYN_DATA_IN(7  downto  0);
                    
                end if;
            
            end if;
    end process INPUT_PP;
        
    SOFTLIMPRECHECK : process(ULEARN_CLK)
        begin
            if(rising_edge(ULEARN_CLK)) then 
                if(ULEARN_RST = '1') then
                    SYN_P1 <= (others=>'0');
                    TMP_P1 <= (others=>'0');
                else
                    if(IGNORE_SOFTLIMITS='0') then
                        if(signed(SYN_P0) < WMIN(7 downto 0)) then                        
                            SYN_P1 <= std_logic_vector(WMIN(7 downto 0));
                            TMP_P1 <= TMP_P0;
                        elsif(signed(SYN_P0) > WMAX(7 downto 0)) then
                            SYN_P1 <= std_logic_vector(WMAX(7 downto 0));
                            TMP_P1 <= TMP_P0;
                        else
                            SYN_P1 <= SYN_P0;
                            TMP_P1 <= TMP_P0;
                        end if;
                    else
                        SYN_P1 <= SYN_P0;
                        TMP_P1 <= TMP_P0;
                    end if;
                end if;      
            end if;
    end process SOFTLIMPRECHECK;
    
    PRUNING : process(ULEARN_CLK)
            begin
            if(rising_edge(ULEARN_CLK)) then
                if(ULEARN_RST = '1') then
                   SYN_P2 <= (others=>'0');
                   TMP_P2 <= (others=>'0');
                else 
                    if(SYNAPSE_PRUNING = '1') then
                        if(signed(SYN_P1) < PTRESH) then
                            SYN_P2 <= (others=>'0');
                            TMP_P2 <= (others=>'0');
                        else
                            SYN_P2 <= SYN_P1;
                            TMP_P2 <= TMP_P1;
                        end if;                    
                    else
                        SYN_P2 <= SYN_P1;
                        TMP_P2 <= TMP_P1;
                    end if;
                end if;
            end if;
    end process PRUNING;
    
    SYNAPSE_CHECK : process(ULEARN_CLK)
        begin
            if(rising_edge(ULEARN_CLK)) then
                if(ULEARN_RST = '1') then
                    SKIP_SYNAPSE_P0 <= '0';
                else
                    if(IGNORE_ZERO_SYNAPSES='1') then
                        SKIP_SYNAPSE_P0 <= '0';
                    else
                        if(SYN_P2 = "00000000") then
                            SKIP_SYNAPSE_P0 <= '1';
                        else
                            SKIP_SYNAPSE_P0 <= '0';
                        end if;  
                    end if;
                end if;
            end if;
    end process SYNAPSE_CHECK; 
 
    SYNAPTIC_TRACE : process(ULEARN_CLK) 
        begin
            if(rising_edge(ULEARN_CLK)) then
                if(ULEARN_RST = '1') then      
                        WC_COEFF <= (others=>'0');  
                else
                    if POST_SYNAPTIC_FLAG = '1' then 
                        WC_COEFF <= signed(ULEARN_LUT(LUT_LOW_INT+to_integer(unsigned(TMP_P2))));        
                    else         
                        WC_COEFF <= signed(ULEARN_LUT(POST_SYNAPTIC_TRACE_OFFSET+to_integer(unsigned(NMODEL_SPIKE_TIME))+LUT_LOW_INT));      
                    end if;
                end if;        
            end if;
    end process SYNAPTIC_TRACE;  
    
    TYPECASTS: process(ULEARN_CLK)
        begin
            if(rising_edge(ULEARN_CLK)) then
                if(ULEARN_RST = '1') then
                    COEFF_INT   <= 0 ;
                    SYNAPSE_INT <= 0 ;   
                else
                    COEFF_INT   <= to_integer(WC_COEFF);
                    SYNAPSE_INT <= to_integer(signed(SYN_P3)) ;  
                end if;     
            end if;      
    end process TYPECASTS; 
    
    TRACE_CHECK : process(ULEARN_CLK)  
        begin
            if(rising_edge(ULEARN_CLK)) then
                if(ULEARN_RST = '1') then
                    
                    SYNAPSE_INT_1 <= 0;
                    COEFF_INT_1   <= 0;
                    
                else
                
                    SYNAPSE_INT_1 <= SYNAPSE_INT;
                
                    if POST_SYNAPTIC_FLAG = '1' then 
                    
                        if TMP_P4 = X"7F" then
                        
                            COEFF_INT_1 <= 0;  
                        
                        else
                    
                            COEFF_INT_1 <= COEFF_INT*LR_INT;        
                        
                        end if;  
                            
                    else
                    
                        if TMP_P4 = X"00" and NMODEL_SPIKE_TIME /= x"7F" then   -- Pre synaptic neuron fired and post synaptic trace is active.
                             
                            COEFF_INT_1 <= COEFF_INT*LR_INT;      
                            
                        elsif TMP_P4 = X"7F"  then         -- Pre Synaptic Trace died.
                        
                            COEFF_INT_1 <= 0; 
                        
                        elsif TMP_P4 /= X"7F" and NMODEL_SPIKE_TIME = x"7F" then -- Pre Synaptic Trace is active but post synaptic trace died.
                        
                            COEFF_INT_1 <= 0; 
                        
                        else
                        
                            COEFF_INT_1 <= 0; 
                        
                        end if;
                            
                    end if;
                    
                end if;            
            end if;        
    end process TRACE_CHECK;
    
    WEIGHT_CHANGE: process(ULEARN_CLK)
        begin
            if(rising_edge(ULEARN_CLK)) then
                if(ULEARN_RST = '1') then
                    WNEW <= 0 ;   
                else
                    if SKIP_SYNAPSE_P2 = '1' then
                       WNEW <= SYNAPSE_INT_1;
                    else                
                       WNEW <= SYNAPSE_INT_1 + COEFF_INT_1/256;
                    end if;
                end if;     
            end if;      
    end process WEIGHT_CHANGE;       
    
                        
    POST_SOFTLIMCHECK : process(ULEARN_CLK)
        begin
            if(rising_edge(ULEARN_CLK)) then
                if(ULEARN_RST = '1') then
                    WNEW_P1 <= 0;
                else                
                    if(IGNORE_SOFTLIMITS='0') then
                        if(WNEW < WMIN_INT) then                        
                            WNEW_P1 <= WMIN_INT;
                        elsif(WNEW > WMAX_INT) then
                            WNEW_P1 <= WMAX_INT;
                        else
                            WNEW_P1 <= WNEW;
                        end if;
                    else
                         WNEW_P1 <= WNEW;
                    end if;
                end if;     
            end if;      
    end process POST_SOFTLIMCHECK;  
    
    TRACE_INCREMENT_TYPECAST: process(ULEARN_CLK)
        begin
            if(rising_edge(ULEARN_CLK)) then
                if(ULEARN_RST = '1') then
                    TMP_P7 <= (others=>'0');
                    SYN_P8 <= (others=>'0');
                else                
                    SYN_P8 <= std_logic_vector(to_signed(WNEW_P1,SYN_P8'length));
                    if(TMP_P6 = X"7F") then
                        TMP_P7 <= X"7F";
                    else
                        TMP_P7 <= std_logic_vector(unsigned(TMP_P6)+1);
                    end if;
                end if;     
            end if;      
    end process TRACE_INCREMENT_TYPECAST; 

    OUTPUT_PP : process(ULEARN_CLK)
        begin
            if(rising_edge(ULEARN_CLK)) then
                if(ULEARN_RST = '1') then  
                    SYN_DATA_OUT <= (others=>'0');          
                else
                        SYN_DATA_OUT(15 downto  8) <= SYN_P8;
                        SYN_DATA_OUT(7  downto  0) <= TMP_P8;
                end if;
            end if;
    end process OUTPUT_PP;    
                        
    PIPELINE_STAGES : process(ULEARN_CLK)
        begin
            if(rising_edge(ULEARN_CLK)) then
                if(ULEARN_RST = '1') then
                    SYN_P3 <= (others=>'0');
                    TMP_P3 <= (others=>'0');
                    TMP_P4 <= (others=>'0');
                    TMP_P5 <= (others=>'0');
                    TMP_P6 <= (others=>'0');
                    TMP_P8 <= (others=>'0');
                    SKIP_SYNAPSE_P1 <= '0';
                else                
                    SYN_P3 <= SYN_P2;
                    TMP_P3 <= TMP_P2;
                    TMP_P4 <= TMP_P3;
                    TMP_P5 <= TMP_P4;
                    TMP_P6 <= TMP_P5;
                    
                    TMP_P8 <= TMP_P7;
                    
                    SKIP_SYNAPSE_P1 <= SKIP_SYNAPSE_P0;
                    SKIP_SYNAPSE_P2 <= SKIP_SYNAPSE_P1;
                    
                end if;     
            end if;      
    end process PIPELINE_STAGES; 
    
        VLD_DLY : process(ULEARN_CLK)
        begin
            if(rising_edge(ULEARN_CLK)) then
            
                if(ULEARN_RST = '1') then
                     VLD_DLY_1  <= '0';
                     VLD_DLY_2  <= '0';
                     VLD_DLY_3  <= '0';
                     VLD_DLY_4  <= '0';
                     VLD_DLY_5  <= '0';
                     VLD_DLY_6  <= '0';
                     VLD_DLY_7  <= '0';
                     VLD_DLY_8  <= '0';
                     VLD_DLY_9  <= '0';
                     VLD_DLY_10  <= '0';
                     SYN_DOUT_VLD <= '0';
                else
                
                     VLD_DLY_1  <= SYN_DIN_VLD;
                     VLD_DLY_2  <= VLD_DLY_1 ;
                     VLD_DLY_3  <= VLD_DLY_2 ;
                     VLD_DLY_4  <= VLD_DLY_3 ;
                     VLD_DLY_5  <= VLD_DLY_4 ;
                     VLD_DLY_6  <= VLD_DLY_5 ;
                     VLD_DLY_7  <= VLD_DLY_6 ;
                     VLD_DLY_8  <= VLD_DLY_7 ;
                     VLD_DLY_9  <= VLD_DLY_8 ;
                     VLD_DLY_10  <= VLD_DLY_9 ;
                     SYN_DOUT_VLD  <= VLD_DLY_9 ;

                end if;
            
            end if;
    end process VLD_DLY; 
    
    WRADDRCNTRLS : process(ULEARN_CLK)
        begin
            if(rising_edge(ULEARN_CLK)) then
                if(ULEARN_RST = '1') then
                    WRADDRSTART <= 0;
                else 
                    if(VLD_DLY_1 = '1' and VLD_DLY_2 = '0') then
                        WRADDRSTART <= to_integer(unsigned(SYNAPSE_START_ADDRESS));
                    end if;
                    if(VLD_DLY_10 = '1') then
                        WRADDRSTART <= WRADDRSTART + 1;
                    end if;
                end if;
            end if;
    end process WRADDRCNTRLS;
    
    SYNAPSE_WRITE_ADDRESS <= std_logic_vector(to_unsigned(WRADDRSTART,SYNAPSE_WRITE_ADDRESS'length));

    ULEARN_LUT_INIT : process(ULEARN_CLK)
        begin
            if(rising_edge(ULEARN_CLK)) then
                if(ULEARN_LUT_EN = '1') then
                    ULEARN_LUT(to_integer(unsigned(ULEARN_LUT_ADDR))) <= ULEARN_LUT_DIN;
                end if;
            end if;
    end process ULEARN_LUT_INIT;
    
    
    
    
end society;