library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity FMAC16 is
    Port(
        CLK    : in  std_logic;
        RST    : in  std_logic;
        START  : in  std_logic;
        A      : in  std_logic_vector(15 downto 0);
        B      : in  std_logic_vector(15 downto 0);
        ACC    : out std_logic_vector(15 downto 0);
        OPC    : in  std_logic_vector( 1 downto 0);
        NAN    : out std_logic;
        BUSY   : out std_logic
    );
end entity;

architecture paint_it_black of FMAC16 is

    function to_left(vec : unsigned) return integer is
        variable I : integer range 10 downto 0;
    begin
        I := 0;
        while vec(vec'left - I)='0' and I /= (vec'left - vec'right) loop
            I := I + 1;
        end loop;
        return I;
    end function;

    signal S1_VALID      : std_logic := '0';
    signal S1_SIGN       : std_logic;
    signal S1_MULTEXP    : unsigned(5 downto 0);
    signal S1_MANT       : unsigned(21 downto 0);
    signal S1_ZERO       : std_logic;

    signal S2_VALID      : std_logic := '0';
    signal S2_SUMSIGN    : std_logic;
    signal S2_SUMEXP     : unsigned(4 downto 0);
    signal S2_SUMMANT    : unsigned(11 downto 0);

    signal ACCUMULATOR   : unsigned(15 downto 0) := (others => '0');
    signal BUSY_INTERNAL : std_logic := '0';

begin

    ACC <= std_logic_vector(ACCUMULATOR);
    NAN <= ACCUMULATOR(14) and ACCUMULATOR(13) and ACCUMULATOR(12) and ACCUMULATOR(11) and ACCUMULATOR(10);
    BUSY <= BUSY_INTERNAL;

    PROCESS(CLK)

        variable val_shift   : integer range 0 to 10;
        variable mant_shifted: unsigned(21 downto 0); 
        variable mult_exp_s1 : unsigned(5 downto 0);
        variable mult_exp_s2 : unsigned(5 downto 0);
        variable op1_mant    : unsigned(11 downto 0);
        variable op2_mant    : unsigned(11 downto 0);
        variable dif_exp     : unsigned(4 downto 0);
        variable op1_shifted : unsigned(11 downto 0);
        variable op2_shifted : unsigned(11 downto 0);
        variable ac_sign     : std_logic;
        
        variable lz : integer range 0 to 10;
    BEGIN
        IF rising_edge(CLK) THEN
            IF RST = '1' THEN
                ACCUMULATOR   <= (others => '0');
                S1_VALID      <= '0';
                S2_VALID      <= '0';
                BUSY_INTERNAL <= '0';
            ELSE

                IF OPC = "10" AND START = '1' THEN
                    ACCUMULATOR   <= (others => '0');
                    BUSY_INTERNAL <= '0';
                    S1_VALID      <= '0';
                    S2_VALID      <= '0';
                ELSE

                    IF START = '1' THEN
                        BUSY_INTERNAL <= '1';
                        S1_VALID      <= '1';

                        if OPC = "01" then
                            S1_SIGN <= not(A(15) xor B(15));
                        else
                            S1_SIGN <= A(15) xor B(15);
                        end if;

                        S1_MULTEXP <= ('0' & unsigned(A(14 downto 10))) + ('0' & unsigned(B(14 downto 10)));
                        S1_MANT    <= ('1' & unsigned(A(9 downto 0))) * ('1' & unsigned(B(9 downto 0)));

                        if (A(14 downto 0) = "000000000000000" or B(14 downto 0) = "000000000000000") then
                            S1_ZERO <= '1';
                        else
                            S1_ZERO <= '0';
                        end if;
                    ELSE
                        S1_VALID <= '0';
                    END IF;

                    IF S1_VALID = '1' THEN
                        S2_VALID <= '1';
                        
                        val_shift := to_left(S1_MANT(21 downto 11));
                        mant_shifted := shift_left(S1_MANT, val_shift);

                        if S1_MULTEXP < 14 then
                            mult_exp_s1 := (others => '0');
                        else
                            mult_exp_s1 := S1_MULTEXP - 14;
                        end if;

                        if mult_exp_s1 = 0 then
                            mult_exp_s2 := mult_exp_s1;
                        else
                            mult_exp_s2 := mult_exp_s1 - val_shift;
                        end if;

                        if S1_ZERO = '0' then
                            if mant_shifted(10) = '0' then
                                op1_mant := "01" & mant_shifted(20 downto 11);
                            else
                                op1_mant := "01" & (mant_shifted(20 downto 11) + 1);
                            end if;
                        else
                            op1_mant := (others => '0');
                            mult_exp_s2 := (others => '0');
                        end if;

                        if ACCUMULATOR(14 downto 0) = "000000000000000" then
                            op2_mant := (others => '0');
                            ac_sign  := '0';
                        else
                            op2_mant := "01" & ACCUMULATOR(9 downto 0);
                            ac_sign  := ACCUMULATOR(15);
                        end if;

                        if op1_mant = 0 then
                            S2_SUMEXP   <= ACCUMULATOR(14 downto 10);
                            op1_shifted := (others => '0');
                            op2_shifted := op2_mant;
                        elsif op2_mant = 0 then
                            S2_SUMEXP   <= mult_exp_s2(4 downto 0);
                            op1_shifted := op1_mant;
                            op2_shifted := (others => '0');
                        else
                            if mult_exp_s2(4 downto 0) > ACCUMULATOR(14 downto 10) then
                                S2_SUMEXP   <= mult_exp_s2(4 downto 0);
                                dif_exp     := mult_exp_s2(4 downto 0) - ACCUMULATOR(14 downto 10);
                                op2_shifted := shift_right(op2_mant, to_integer(dif_exp));
                                op1_shifted := op1_mant;
                            else
                                S2_SUMEXP   <= ACCUMULATOR(14 downto 10);
                                dif_exp     := ACCUMULATOR(14 downto 10) - mult_exp_s2(4 downto 0);
                                op1_shifted := shift_right(op1_mant, to_integer(dif_exp));
                                op2_shifted := op2_mant;
                            end if;
                        end if;

                        if S1_SIGN = ac_sign then
                            S2_SUMMANT <= op1_shifted + op2_shifted;
                            S2_SUMSIGN <= S1_SIGN;
                        else
                            if op1_shifted >= op2_shifted then
                                S2_SUMMANT <= op1_shifted - op2_shifted;
                                S2_SUMSIGN <= S1_SIGN;
                            else
                                S2_SUMMANT <= op2_shifted - op1_shifted;
                                S2_SUMSIGN <= ac_sign;
                            end if;
                        end if;
                    ELSE
                        S2_VALID <= '0';
                    END IF;

                    IF S2_VALID = '1' THEN
                        BUSY_INTERNAL <= '0';

                        if S2_SUMMANT(11) = '1' then
                            ACCUMULATOR <= S2_SUMSIGN & (S2_SUMEXP + 1) & S2_SUMMANT(10 downto 1);
                        elsif S2_SUMMANT(11 downto 10) = "01" then
                            ACCUMULATOR <= S2_SUMSIGN & S2_SUMEXP & S2_SUMMANT(9 downto 0);
                        elsif S2_SUMMANT = 0 then
                            ACCUMULATOR <= (others => '0');
                        else
                            lz := to_left(S2_SUMMANT(10 downto 0));
                            ACCUMULATOR <= S2_SUMSIGN & (S2_SUMEXP - lz) & shift_left(S2_SUMMANT(9 downto 0), lz);
                        end if;
                    END IF;

                END IF;
            END IF;
        END IF;
    END PROCESS;

end architecture paint_it_black;