library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity INTERRUPT_CONTROLLER is
    Port ( 
            CLK                       : in  std_logic;
            RST                       : in  std_logic;
            CLEAR_INTERRUPT           : in  std_logic_vector(7 downto 0);
            -- Interrupt Pins
            GLOBAL_TIMESTEP_PULSE     : in  std_logic;
            MATH_ERROR                : in  std_logic;
            MEMORY_CROSSOVER          : in  std_logic;
            D2S_CONVERSION_DONE       : in  std_logic;
            DMA_READ_DONE             : in  std_logic;
            DMA_READ_ERROR            : in  std_logic;
            DMA_WRITE_DONE            : in  std_logic;
            DMA_WRITE_ERROR           : in  std_logic;
            -- Interrupt Active
            ACTIVE_INTERRUPTS         : in  std_logic_vector(7 downto 0);
            -- Conditions
            TIMESTEP_COUNTER_LIMIT    : in  std_logic_vector(31 downto 0);
            -- Interrupt type register
            INTERRUPT_TYPE            : out std_logic_vector(7 downto 0);
            -- Core Timestep Loop Breakswitch
            TIMESTEP_LOOP_BREAK       : out std_logic;
            -- Interrupt Out
            INTERRUPT                 : out std_logic

    );
end INTERRUPT_CONTROLLER;

architecture Behavioral of INTERRUPT_CONTROLLER is

    signal REG_GLOBAL_TIMESTEP_PULSE     : std_logic;
    signal REG_MATH_ERROR                : std_logic;
    signal REG_MEMORY_CROSSOVER          : std_logic;
    signal REG_D2S_CONVERSION_DONE       : std_logic;
    signal REG_DMA_READ_DONE             : std_logic;
    signal REG_DMA_READ_ERROR            : std_logic;
    signal REG_DMA_WRITE_DONE            : std_logic;
    signal REG_DMA_WRITE_ERROR           : std_logic;

    signal REG_INTERRUPT_TYPE            : std_logic_vector(7 downto 0);

    signal TIMESTEP_COUNTER : unsigned(31 downto 0);

    signal TIMESTEP_COUNTER_LIMIT_USGN : unsigned(31 downto 0);

    type INTERRUPT_STATES is (IDLE,CAUGHT);
    signal MATH_ERROR_INTERRUPT : INTERRUPT_STATES;
    signal MEMORY_CROSSOVER_INTERRUPT : INTERRUPT_STATES;
    signal D2S_CONVERSION_DONE_INTERRUPT : INTERRUPT_STATES;
    signal DMA_READ_DONE_INTERRUPT : INTERRUPT_STATES;
    signal DMA_READ_ERROR_INTERRUPT : INTERRUPT_STATES;
    signal DMA_WRITE_DONE_INTERRUPT : INTERRUPT_STATES;
    signal DMA_WRITE_ERROR_INTERRUPT : INTERRUPT_STATES;

    type TIMESTEP_INTERRUPT_STATES is (IDLE,INCR,CAUGHT);
    signal TIMESTEP_INTERRUPT_STATE : TIMESTEP_INTERRUPT_STATES;

    signal D2S_TIMESTEP_LOOP_BREAK : std_logic;
    signal TIMESTEP_COUNTER_TIMESTEP_LOOP_BREAK : std_logic;

begin

    REG_GLOBAL_TIMESTEP_PULSE     <= GLOBAL_TIMESTEP_PULSE and ACTIVE_INTERRUPTS(0);
    REG_MATH_ERROR                <= MATH_ERROR            and ACTIVE_INTERRUPTS(1);
    REG_MEMORY_CROSSOVER          <= MEMORY_CROSSOVER      and ACTIVE_INTERRUPTS(2);
    REG_D2S_CONVERSION_DONE       <= D2S_CONVERSION_DONE   and ACTIVE_INTERRUPTS(3);
    REG_DMA_READ_DONE             <= DMA_READ_DONE         and ACTIVE_INTERRUPTS(4);
    REG_DMA_READ_ERROR            <= DMA_READ_ERROR        and ACTIVE_INTERRUPTS(5);
    REG_DMA_WRITE_DONE            <= DMA_WRITE_DONE        and ACTIVE_INTERRUPTS(6);
    REG_DMA_WRITE_ERROR           <= DMA_WRITE_ERROR       and ACTIVE_INTERRUPTS(7);

    TIMESTEP_COUNTER_LIMIT_USGN <= unsigned(TIMESTEP_COUNTER_LIMIT);

    INTERRUPT_TYPE <= REG_INTERRUPT_TYPE;
    INTERRUPT <= or REG_INTERRUPT_TYPE;

    TIMESTEP_LOOP_BREAK <= D2S_TIMESTEP_LOOP_BREAK or TIMESTEP_COUNTER_TIMESTEP_LOOP_BREAK;

    TIMESTEP_PULSE_COUNTER_PROC : process(CLK) 
        begin
            if rising_edge(CLK) then
                if RST = '1' then
                    TIMESTEP_INTERRUPT_STATE <= IDLE;
                    TIMESTEP_COUNTER         <= (others=>'0') ;
                    REG_INTERRUPT_TYPE(0) <= '0'; 
                    TIMESTEP_COUNTER_TIMESTEP_LOOP_BREAK <= '0';
                else
                    case TIMESTEP_INTERRUPT_STATE is
                        when IDLE =>
                            REG_INTERRUPT_TYPE(0)                <= '0'; 
                            TIMESTEP_COUNTER_TIMESTEP_LOOP_BREAK <= '0';
                            if REG_GLOBAL_TIMESTEP_PULSE = '1' and TIMESTEP_COUNTER_LIMIT_USGN /= X"00000000" then
                                TIMESTEP_INTERRUPT_STATE <= INCR;
                            else
                                TIMESTEP_INTERRUPT_STATE <= IDLE;
                            end if;
                        when INCR =>
                            if REG_GLOBAL_TIMESTEP_PULSE = '0' then
                                TIMESTEP_COUNTER <= TIMESTEP_COUNTER + 1;
                                if TIMESTEP_COUNTER + 1 >= TIMESTEP_COUNTER_LIMIT_USGN then
                                    TIMESTEP_INTERRUPT_STATE <= CAUGHT;
                                else
                                    TIMESTEP_INTERRUPT_STATE <= IDLE;
                                end if;
                            end if;
                        when CAUGHT =>
                            REG_INTERRUPT_TYPE(0)                <= '1'; 
                            TIMESTEP_COUNTER_TIMESTEP_LOOP_BREAK <= '1';
                            if REG_GLOBAL_TIMESTEP_PULSE = '0' and CLEAR_INTERRUPT(0) = '1' then
                                TIMESTEP_INTERRUPT_STATE <= IDLE;
                                TIMESTEP_COUNTER <= (others=>'0');
                            else
                                TIMESTEP_INTERRUPT_STATE <= CAUGHT;
                            end if;
                        when others =>
                                NULL;
                    end case;
                end if;
            end if;
    end process TIMESTEP_PULSE_COUNTER_PROC;

    MATH_ERROR_PROC : process(CLK) 
        begin
            if rising_edge(CLK) then
                if RST = '1' then
                    MATH_ERROR_INTERRUPT <= IDLE;
                    REG_INTERRUPT_TYPE(1) <= '0'; 
                else
                    case MATH_ERROR_INTERRUPT is
                        when IDLE =>
                            REG_INTERRUPT_TYPE(1) <= '0'; 
                            if REG_MATH_ERROR = '1' then
                                MATH_ERROR_INTERRUPT <= CAUGHT;
                            else
                                MATH_ERROR_INTERRUPT <= IDLE;
                            end if;
                        when CAUGHT =>
                            REG_INTERRUPT_TYPE(1) <= '1'; 
                            if REG_MATH_ERROR = '0' and CLEAR_INTERRUPT(1) = '1' then
                                MATH_ERROR_INTERRUPT <= IDLE;
                            else
                                MATH_ERROR_INTERRUPT <= CAUGHT;
                            end if;
                        when others =>
                                    NULL;
                    end case;
                end if;
            end if;
    end process MATH_ERROR_PROC;

    MEMORY_CROSSOVER_PROC : process(CLK)
        begin
            if rising_edge(CLK) then
                if RST = '1' then
                    MEMORY_CROSSOVER_INTERRUPT <= IDLE;
                    REG_INTERRUPT_TYPE(2) <= '0'; 
                else
                    case MEMORY_CROSSOVER_INTERRUPT is
                        when IDLE =>
                            REG_INTERRUPT_TYPE(2) <= '0'; 
                            if REG_MEMORY_CROSSOVER = '1' then
                                MEMORY_CROSSOVER_INTERRUPT <= CAUGHT;
                            else
                                MEMORY_CROSSOVER_INTERRUPT <= IDLE;
                            end if;
                        when CAUGHT =>
                            REG_INTERRUPT_TYPE(2) <= '1'; 
                            if REG_MEMORY_CROSSOVER = '0' and CLEAR_INTERRUPT(2) = '1' then
                                MEMORY_CROSSOVER_INTERRUPT <= IDLE;
                            else
                                MEMORY_CROSSOVER_INTERRUPT <= CAUGHT;
                            end if;
                        when others =>
                                    NULL;
                    end case;
                end if;
            end if;
    end process MEMORY_CROSSOVER_PROC;

    D2S_CONVERSION_DONE_PROC : process(CLK)
        begin
            if rising_edge(CLK) then
                if RST = '1' then
                    D2S_CONVERSION_DONE_INTERRUPT <= IDLE;
                    REG_INTERRUPT_TYPE(3) <= '0'; 
                    D2S_TIMESTEP_LOOP_BREAK <= '0';
                else
                    case D2S_CONVERSION_DONE_INTERRUPT is
                        when IDLE =>
                            REG_INTERRUPT_TYPE(3)   <= '0'; 
                            D2S_TIMESTEP_LOOP_BREAK <= '0';
                            if REG_D2S_CONVERSION_DONE = '1' then
                                D2S_CONVERSION_DONE_INTERRUPT <= CAUGHT;
                            else
                                D2S_CONVERSION_DONE_INTERRUPT <= IDLE;
                            end if;
                        when CAUGHT =>
                            REG_INTERRUPT_TYPE(3)   <= '1'; 
                            D2S_TIMESTEP_LOOP_BREAK <= '1';
                            if REG_D2S_CONVERSION_DONE = '0' and CLEAR_INTERRUPT(3) = '1' then
                                D2S_CONVERSION_DONE_INTERRUPT <= IDLE;
                            else
                                D2S_CONVERSION_DONE_INTERRUPT <= CAUGHT;
                            end if;
                        when others =>
                                    NULL;
                    end case;
                end if;
            end if;
    end process D2S_CONVERSION_DONE_PROC;

    DMA_READ_DONE_PROC : process(CLK)
        begin
            if rising_edge(CLK) then
                if RST = '1' then
                    DMA_READ_DONE_INTERRUPT <= IDLE;
                    REG_INTERRUPT_TYPE(4) <= '0'; 
                else
                    case DMA_READ_DONE_INTERRUPT is
                        when IDLE =>
                            REG_INTERRUPT_TYPE(4) <= '0'; 
                            if REG_DMA_READ_DONE = '1' then
                                DMA_READ_DONE_INTERRUPT <= CAUGHT;
                            else
                                DMA_READ_DONE_INTERRUPT <= IDLE;
                            end if;
                        when CAUGHT =>
                            REG_INTERRUPT_TYPE(4) <= '1'; 
                            if REG_DMA_READ_DONE = '0' and CLEAR_INTERRUPT(4) = '1' then
                                DMA_READ_DONE_INTERRUPT <= IDLE;
                            else
                                DMA_READ_DONE_INTERRUPT <= CAUGHT;
                            end if;
                        when others =>
                                    NULL;
                    end case;
                end if;
            end if;
    end process DMA_READ_DONE_PROC;

    DMA_READ_ERROR_PROC : process(CLK)
        begin
            if rising_edge(CLK) then
                if RST = '1' then
                    DMA_READ_ERROR_INTERRUPT <= IDLE;
                    REG_INTERRUPT_TYPE(5) <= '0'; 
                else
                    case DMA_READ_ERROR_INTERRUPT is
                        when IDLE =>
                            REG_INTERRUPT_TYPE(5) <= '0'; 
                            if REG_DMA_READ_ERROR = '1' then
                                DMA_READ_ERROR_INTERRUPT <= CAUGHT;
                            else
                                DMA_READ_ERROR_INTERRUPT <= IDLE;
                            end if;
                        when CAUGHT =>
                            REG_INTERRUPT_TYPE(5) <= '1'; 
                            if REG_DMA_READ_ERROR = '0' and CLEAR_INTERRUPT(5) = '1' then
                                DMA_READ_ERROR_INTERRUPT <= IDLE;
                            else
                                DMA_READ_ERROR_INTERRUPT <= CAUGHT;
                            end if;
                        when others =>
                                    NULL;
                    end case;
                end if;
            end if;
    end process DMA_READ_ERROR_PROC;

    DMA_WRITE_DONE_PROC : process(CLK)
        begin
            if rising_edge(CLK) then
                if RST = '1' then
                    DMA_WRITE_DONE_INTERRUPT <= IDLE;
                    REG_INTERRUPT_TYPE(6) <= '0'; 
                else
                    case DMA_WRITE_DONE_INTERRUPT is
                        when IDLE =>
                            REG_INTERRUPT_TYPE(6) <= '0'; 
                            if REG_DMA_WRITE_DONE = '1' then
                                DMA_WRITE_DONE_INTERRUPT <= CAUGHT;
                            else
                                DMA_WRITE_DONE_INTERRUPT <= IDLE;
                            end if;
                        when CAUGHT =>
                            REG_INTERRUPT_TYPE(6) <= '1'; 
                            if REG_DMA_WRITE_DONE = '0' and CLEAR_INTERRUPT(6) = '1' then
                                DMA_WRITE_DONE_INTERRUPT <= IDLE;
                            else
                                DMA_WRITE_DONE_INTERRUPT <= CAUGHT;
                            end if;
                        when others =>
                                    NULL;
                    end case;
                end if;
            end if;
    end process DMA_WRITE_DONE_PROC;

    DMA_WRITE_ERROR_PROC : process(CLK)
        begin
            if rising_edge(CLK) then
                if RST = '1' then
                    DMA_WRITE_ERROR_INTERRUPT <= IDLE;
                    REG_INTERRUPT_TYPE(7) <= '0'; 
                else
                    case DMA_WRITE_ERROR_INTERRUPT is
                        when IDLE =>
                            REG_INTERRUPT_TYPE(7) <= '0'; 
                            if REG_DMA_WRITE_ERROR = '1' then
                                DMA_WRITE_ERROR_INTERRUPT <= CAUGHT;
                            else
                                DMA_WRITE_ERROR_INTERRUPT <= IDLE;
                            end if;
                        when CAUGHT =>
                            REG_INTERRUPT_TYPE(7) <= '1'; 
                            if REG_DMA_WRITE_ERROR = '0' and CLEAR_INTERRUPT(7) = '1' then
                                DMA_WRITE_ERROR_INTERRUPT <= IDLE;
                            else
                                DMA_WRITE_ERROR_INTERRUPT <= CAUGHT;
                            end if;
                        when others =>
                                    NULL;
                    end case;
                end if;
            end if;
    end process DMA_WRITE_ERROR_PROC;

end Behavioral;
