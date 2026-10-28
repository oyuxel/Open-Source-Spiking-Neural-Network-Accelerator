library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity SNAPSHOT is
    Port 
        ( 
            SNP_CLK                : in  std_logic;
            SNP_RST                : in  std_logic;
            RELEASE_PROCESSOR      : in  std_logic;
            TIMESTEP_COUNTER       : in  std_logic_vector(31 downto 0);

            NMC_MATH_ERROR_OCCURED : out std_logic;
            NMC_MEMORY_VIOLATION   : out std_logic;

            GLOBAL_TIMESTEP_UPDATE : in  std_logic;

            MATH_ERROR             : in  std_logic;
            MEMORY_VIOLATION       : in  std_logic;

            SHUTDOWN_EVENT_ACCEPT  : out std_logic;
            INTERRUPT              : out std_logic
        );
end SNAPSHOT;

architecture Behavioral of SNAPSHOT is

    type SNP_STATES is (LISTENING,UPDATE_GLOBAL_TIMESTEP,STATE_CLEAR,CHECK_TIMESTEP_LIMIT,HALT_HARDWARE,NMC_ERROR,MEMORY_CROSSOVER);
    signal SNP_STATE : SNP_STATES;

    signal TIMESTEP_INT  : integer; 

    signal TIMESTEP_LIMIT : integer;

    type ERR_HOOK_STATES is (LISTENING,CATCH_MATH_ERROR,CATCH_MEM_CROSS,CO_ERROR);
    signal ERR_HOOK_STATE : ERR_HOOK_STATES;

begin

    ERR_HOOK : process (SNP_CLK) 
    
        begin

            if rising_edge(SNP_CLK) then

                if SNP_RST = '1' then

                    ERR_HOOK_STATE   <= LISTENING;

                    NMC_MATH_ERROR_OCCURED <= '0';
                    NMC_MEMORY_VIOLATION   <= '0';

                else

                    case ERR_HOOK_STATE is

                        when LISTENING =>

                            if MATH_ERROR = '1' and MEMORY_VIOLATION = '0' then

                                ERR_HOOK_STATE   <= CATCH_MATH_ERROR;

                            elsif MATH_ERROR = '0' and MEMORY_VIOLATION = '1' then

                                ERR_HOOK_STATE   <= CATCH_MEM_CROSS;

                            elsif MATH_ERROR = '1' and MEMORY_VIOLATION = '1' then 

                                ERR_HOOK_STATE   <= CO_ERROR;

                            else

                                ERR_HOOK_STATE   <= LISTENING;

                            end if;

                        when CATCH_MATH_ERROR =>

                            NMC_MATH_ERROR_OCCURED <= '1';

                        when CATCH_MEM_CROSS =>

                            NMC_MEMORY_VIOLATION   <= '1';

                        when CO_ERROR =>

                            NMC_MATH_ERROR_OCCURED <= '1';
                            NMC_MEMORY_VIOLATION   <= '1';

                        when others =>
                                        NULL;

                    end case;
                
                end if;

            end if;

    end process ERR_HOOK;

    TIMESTEP_LIMIT <= to_integer(unsigned(TIMESTEP_COUNTER));

    MSM : process (SNP_CLK) 
    
        begin

            if rising_edge(SNP_CLK) then

                if SNP_RST = '1' then

                    SNP_STATE <= LISTENING;

                    TIMESTEP_INT          <=  0 ;
                    SHUTDOWN_EVENT_ACCEPT <= '1';
                    INTERRUPT             <= '0';

                else

                    case SNP_STATE is

                        when LISTENING =>

                            SHUTDOWN_EVENT_ACCEPT <= '1';

                            if GLOBAL_TIMESTEP_UPDATE = '1' and TIMESTEP_LIMIT /= 0 then

                                SNP_STATE             <= UPDATE_GLOBAL_TIMESTEP;
                                SHUTDOWN_EVENT_ACCEPT <= '0';

                            else

                                SNP_STATE <= LISTENING;

                            end if;

                        when UPDATE_GLOBAL_TIMESTEP =>

                            TIMESTEP_INT <= TIMESTEP_INT + 1;
                            SNP_STATE    <= STATE_CLEAR;

                        when STATE_CLEAR => 

                            if GLOBAL_TIMESTEP_UPDATE = '0' then

                                SNP_STATE <= CHECK_TIMESTEP_LIMIT;

                            else
                                
                                SNP_STATE <= STATE_CLEAR;
                                                                
                            end if;
                    
                        when CHECK_TIMESTEP_LIMIT =>

                            if TIMESTEP_INT = TIMESTEP_LIMIT then

                                SNP_STATE             <= HALT_HARDWARE;
                                INTERRUPT             <= '1';

                            else

                                SHUTDOWN_EVENT_ACCEPT <= '1';
                                SNP_STATE             <= LISTENING;

                            end if;
                            
                        when HALT_HARDWARE => 

                            if RELEASE_PROCESSOR = '1' then

                                SNP_STATE <= LISTENING;
                                
                                SHUTDOWN_EVENT_ACCEPT <= '1';
                                INTERRUPT             <= '0';

                            else

                                SNP_STATE <= HALT_HARDWARE;
                            
                            end if;

                        when others =>
                                        NULL;

                    end case;

                end if;

            end if;

    end process MSM;

end Behavioral;
