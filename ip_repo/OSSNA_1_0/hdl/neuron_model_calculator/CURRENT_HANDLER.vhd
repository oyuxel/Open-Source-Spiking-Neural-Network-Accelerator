library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity CURRENT_HANDLER is
    Port (
        CLK                 : in  std_logic;
        RST                 : in  std_logic; 
        
        SWITCH_CHANNEL      : in  std_logic; 
        RESET_CHANNEL       : in  std_logic; 
        CHANNEL_SWITCHED    : out std_logic; 
        
        XNEVER_BASE         : in  std_logic_vector(9 downto 0);

        RESOURCES_RELEASED  : out std_logic;
        
        FMAC_ACC            : in  std_logic_vector(15 downto 0); 
        FMAC_CLR            : out std_logic;                     
        
        BRAM_ADDRA          : out std_logic_vector(9 downto 0);
        BRAM_DIA            : out std_logic_vector(15 downto 0);
        BRAM_WEA            : out std_logic;
        BRAM_ENA            : out std_logic
    );
end entity CURRENT_HANDLER;

architecture dracula of CURRENT_HANDLER is

    type STATE_TYPE is (
        IDLE_ACCUMULATE,    
        WRITE_BRAM,         
        COMMIT_AND_ACK,     
        WAIT_SIGNAL_DROP    
    );

    signal STATE        : STATE_TYPE;
    signal WRITE_PTR    : unsigned(9 downto 0);
    signal IS_FINAL_CH  : std_logic;

begin

    PROCESS(CLK)
    BEGIN
        IF rising_edge(CLK) THEN

            IF RST = '1' THEN

                STATE              <= IDLE_ACCUMULATE;
                WRITE_PTR          <= unsigned(XNEVER_BASE);
                CHANNEL_SWITCHED   <= '0';
                RESOURCES_RELEASED <= '0'; 
                FMAC_CLR           <= '0';
                BRAM_ENA           <= '0';
                BRAM_WEA           <= '0';
                BRAM_ADDRA         <= (others => '0');
                BRAM_DIA           <= (others => '0');
                IS_FINAL_CH        <= '0';

            ELSE
                CASE STATE IS

                    WHEN IDLE_ACCUMULATE =>
                        CHANNEL_SWITCHED <= '0';
                        FMAC_CLR         <= '0';
                        BRAM_ENA         <= '0';
                        BRAM_WEA         <= '0';

                        IF RESET_CHANNEL = '1' THEN
                            IS_FINAL_CH        <= '1';
                            RESOURCES_RELEASED <= '0'; 
                            STATE              <= WRITE_BRAM;

                        ELSIF SWITCH_CHANNEL = '1' THEN
                            
                            IS_FINAL_CH        <= '0';
                            RESOURCES_RELEASED <= '0';
                            STATE              <= WRITE_BRAM;
                        END IF;

                    WHEN WRITE_BRAM =>
                        BRAM_ENA   <= '1';
                        BRAM_WEA   <= '1';
                        BRAM_ADDRA <= std_logic_vector(WRITE_PTR);
                        BRAM_DIA   <= FMAC_ACC; 
                        STATE      <= COMMIT_AND_ACK;

                    WHEN COMMIT_AND_ACK =>
                        BRAM_ENA <= '0';
                        BRAM_WEA <= '0';

                        FMAC_CLR <= '1';

                        CHANNEL_SWITCHED <= '1';

                        IF IS_FINAL_CH = '1' THEN
                            WRITE_PTR          <= unsigned(XNEVER_BASE);
                            RESOURCES_RELEASED <= '1';
                        ELSE
                            WRITE_PTR          <= WRITE_PTR + 1;
                            RESOURCES_RELEASED <= '0';
                        END IF;

                        STATE <= WAIT_SIGNAL_DROP;

                    WHEN WAIT_SIGNAL_DROP =>
                        CHANNEL_SWITCHED <= '0';
                        FMAC_CLR         <= '0';

                        IF SWITCH_CHANNEL = '0' AND RESET_CHANNEL = '0' THEN
                            STATE <= IDLE_ACCUMULATE;
                        END IF;

                    WHEN OTHERS =>
                        STATE <= IDLE_ACCUMULATE;

                END CASE;
            END IF;
        END IF;
    END PROCESS;

end architecture dracula;