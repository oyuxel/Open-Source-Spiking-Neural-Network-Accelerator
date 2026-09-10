library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity SS_2_HP is
    Port(
        CLK     : in  std_logic;
        RST     : in  std_logic;
        SS_IN   : in  std_logic_vector(15 downto 0);
        HP_OUT  : out std_logic_vector(15 downto 0);
        START   : in  std_logic;
        DONE    : out std_logic
    );
end entity SS_2_HP;

architecture california_dreamin of SS_2_HP is
    signal sign_indicator : std_logic;
    signal twos_comp      : unsigned(15 downto 0);
    signal normal         : unsigned(15 downto 0);
    signal proc           : unsigned(15 downto 0);
    signal FPSIGN         : std_logic;
    signal FPEXP_S1       : integer range -15 to 16 := 0;
    signal FPEXP          : std_logic_vector(4 downto 0);
    signal FPMANT         : std_logic_vector(9 downto 0);
    constant LOWLIM       : integer := -14;
    constant EXPBIAS      : integer := 15;
    signal BITCOUNTER     : integer range 0 to 15;
    type STATES is (IDLE, TAKE, BREW, SEND);
    signal SS_2_HP_STATE  : STATES := IDLE;

begin

    process(CLK) begin
        if rising_edge(CLK) then
            if RST = '1' then
                SS_2_HP_STATE <= IDLE;
                DONE <= '0';
                BITCOUNTER <= 0;
                sign_indicator <= '0';
                FPSIGN <= '0';
                twos_comp <= (others=>'0');
                normal <= (others=>'0');
                proc <= (others=>'0');
                FPEXP_S1 <= 0;
                FPEXP <= (others=>'0');
                FPMANT <= (others=>'0');
            else
                case SS_2_HP_STATE is
                    when IDLE =>
                        DONE <= '0';
                        BITCOUNTER <= 0;
                        if START = '1' then
                            SS_2_HP_STATE <= TAKE;
                            if SS_IN(15) = '1' then
                                sign_indicator <= '1';
                                twos_comp <= unsigned(not SS_IN) + 1;  -- Two's complement for negative numbers
                            else
                                sign_indicator <= '0';
                                normal <= unsigned(SS_IN);
                            end if;
                        end if;
                    when TAKE =>
                        if sign_indicator = '1' then
                            proc <= twos_comp;
                        else
                            proc <= normal;
                        end if;
                        SS_2_HP_STATE <= BREW;
                        FPEXP_S1 <= 15; -- Bias of 15 for half-precision
                    when BREW =>
                        FPSIGN <= sign_indicator;
                        if proc(15) = '1' then
                            FPEXP <= std_logic_vector(to_unsigned(FPEXP_S1 + EXPBIAS, 5));
                            FPMANT <= std_logic_vector(proc(14 downto 5));
                            SS_2_HP_STATE <= SEND;
                        elsif proc = 0 then
                            FPEXP <= (others=>'0');
                            FPMANT <= (others=>'0');
                            SS_2_HP_STATE <= SEND;
                        else
                            proc <= shift_left(proc,1);
                            BITCOUNTER <= BITCOUNTER + 1;
                            FPEXP_S1 <= FPEXP_S1 - 1;
                        end if;
                    when SEND =>
                        HP_OUT <= FPSIGN & FPEXP & FPMANT;
                        DONE <= '1';
                        SS_2_HP_STATE <= IDLE;
                end case;
            end if;
        end if;
    end process;

end architecture california_dreamin;
