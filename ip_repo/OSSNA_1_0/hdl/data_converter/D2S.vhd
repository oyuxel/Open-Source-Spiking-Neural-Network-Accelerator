library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
Library xpm;
use xpm.vcomponents.all;


entity D2S is
    Generic(
            MAX_ALLOWED_INWIDTH : natural := 2048;
            BUFPRIM             : string  := "BLOCK"; 
            CROSSBAR_WIDTH      : natural := 16
            );
    Port ( 
            D2S_RST        : in  std_logic;
            D2S_WCLK       : in  std_logic;
            D2S_RCLK       : in  std_logic;
            -- Conversion Mode and Working Mode
            CONVMODE       : in  std_logic_vector(1  downto 0); -- 00: Probabilistic, 01: Time-to-first-spike, 10: Reserved, 11: Reserved
            -- Timespan
            TIME_WIND      : in  std_logic_vector(31 downto 0);
            -- Poisson Coding Settings
            SEED           : in  std_logic_vector(31 downto 0);
            -- Data Input
            DATA_COUNT     : in  std_logic_vector(31 downto 0);
            DATA_IN        : in  std_logic_vector(31 downto 0);
            DATA_IN_VLD    : in  std_logic;
            -- Backpressure Input
            NEW_TIMESTEP   : in  std_logic;
            -- Serial Spike Output
            SPIKE_OUT      : out std_logic_vector(CROSSBAR_WIDTH-1 downto 0);
            SPIKE_VLD      : out std_logic;
            CONV_DONE      : out std_logic
        );
end D2S;

architecture forever_your_star of D2S is

    type DATARAM is array (0 to MAX_ALLOWED_INWIDTH-1) of unsigned(31 downto 0);

    signal DATA_RAM : DATARAM;

    signal DADDR : integer;

    signal DADDR_SYNC_INT : integer;

    signal DADDR_SLV : std_logic_vector(31 downto 0);
    signal DADDR_SLV_SYNC : std_logic_vector(31 downto 0);

    attribute RAM_STYLE : string;
    attribute RAM_STYLE of DATA_RAM : signal is BUFPRIM;

    constant PARTIAL_SPIKEVECTOR_LENGTH : integer := CROSSBAR_WIDTH;

    signal TIMESTEP            : unsigned(31 downto 0);

    signal SPIKE_VECTOR        : std_logic_vector(CROSSBAR_WIDTH-1 downto 0);
    signal SPIKE_VECTOR_VLD    : std_logic;

    signal RANDOM_VECTOR       : std_logic_vector(31 downto 0);
    signal RANDOM_VECTOR_UNSGN : unsigned(31 downto 0);

    type CONVERSION is (IDLE,PREP_TIMESTEP_VECTOR,SEND_TIMESTEP_VECTOR,WAIT_FOR_UPDATE,CHECK_TIMESTEP,DONE);
    signal CONVERSION_STATE : CONVERSION;

    signal SPIKE_INDEX : integer range 0 to CROSSBAR_WIDTH-1;
    signal MEM_OFFSET  : integer range 0 to MAX_ALLOWED_INWIDTH-1;

    type LFSR_STATES is (IDLE,LAUNCH);
    signal LFSR_STATE : LFSR_STATES;

    signal STOP_LFSR : std_logic;

    signal VLD_DLY_SYNC : std_logic;

    signal DATA_COUNT_INT : integer;

    signal TIME_WIND_INT : integer ;

    signal STALL_FLAG : std_logic;

    signal D2S_CONV_RST   : std_logic;

begin

    -- Buffering

    DATA_COUNT_INT <= to_integer(unsigned(DATA_COUNT));

    TIME_WIND_INT <= to_integer(unsigned(TIME_WIND));

    BUFFERING : process(D2S_WCLK) begin

        if rising_edge(D2S_WCLK) then

            if D2S_RST = '1' then

                DADDR   <= 0 ;

            else

                if DATA_IN_VLD = '1' then

                    DATA_RAM(DADDR) <= unsigned(DATA_IN);
                    DADDR <= DADDR + 1;

                end if;

            end if;
    
        end if;

    end process BUFFERING;

    VLD_SYNC : xpm_cdc_single
        generic map (
                    DEST_SYNC_FF => 4,  
                    INIT_SYNC_FF => 0,  
                    SIM_ASSERT_CHK => 0,
                    SRC_INPUT_REG => 1  
                    )
        port map (
                    dest_out => VLD_DLY_SYNC, 
                    dest_clk => D2S_RCLK, 
                    src_clk  => D2S_WCLK,  
                    src_in   => DATA_IN_VLD      
                 );

    RST_SYNC : xpm_cdc_single
        generic map (
                    DEST_SYNC_FF => 4,  
                    INIT_SYNC_FF => 0,  
                    SIM_ASSERT_CHK => 0,
                    SRC_INPUT_REG => 1  
                    )
        port map (
                    dest_out => D2S_CONV_RST, 
                    dest_clk => D2S_RCLK, 
                    src_clk  => D2S_WCLK,  
                    src_in   => D2S_RST      
                 );

    DADDR_SLV <= std_logic_vector(to_unsigned(DADDR,DADDR_SLV'length));

    DADDR_SYNC : xpm_cdc_array_single
        generic map (
            DEST_SYNC_FF => 4,   
            INIT_SYNC_FF => 0,   
            SIM_ASSERT_CHK => 0, 
            SRC_INPUT_REG => 1,  
            WIDTH => 32          
            )
        port map (
            dest_out => DADDR_SLV_SYNC, 
            dest_clk => D2S_RCLK,       
            src_clk => D2S_WCLK,        
            src_in => DADDR_SLV         
       );

    DADDR_SYNC_INT <= to_integer(unsigned(DADDR_SLV_SYNC));

    -- Spike Vector Generation

    VECTOR_GEN : process(D2S_RCLK) begin

        if rising_edge(D2S_RCLK) then

            if D2S_CONV_RST = '1' then

                CONVERSION_STATE <= IDLE;

            else

                case CONVERSION_STATE is

                    when IDLE =>

                        if VLD_DLY_SYNC = '1' then

                            CONVERSION_STATE <= PREP_TIMESTEP_VECTOR;

                        else

                            CONVERSION_STATE <= IDLE;
                            TIMESTEP         <= (others=>'0');
                            SPIKE_VECTOR     <= (others=>'0');
                            SPIKE_INDEX      <= 0;
                            MEM_OFFSET       <= 0;
                            SPIKE_VECTOR_VLD <= '0';
                            STOP_LFSR        <= '0';
                            STALL_FLAG       <= '0';

                        end if;

                    when PREP_TIMESTEP_VECTOR =>

                        if MEM_OFFSET < DADDR_SYNC_INT then

                            if SPIKE_INDEX = PARTIAL_SPIKEVECTOR_LENGTH-1 or MEM_OFFSET = DATA_COUNT_INT-1 then

                                CONVERSION_STATE <= SEND_TIMESTEP_VECTOR;
                                SPIKE_VECTOR_VLD <= '1';

                            else

                                SPIKE_INDEX <= SPIKE_INDEX + 1;
                                MEM_OFFSET  <= MEM_OFFSET + 1;

                            end if;

                            if CONVMODE = B"00" then

                                if DATA_RAM(MEM_OFFSET) >= RANDOM_VECTOR_UNSGN then

                                    SPIKE_VECTOR(SPIKE_INDEX) <= '1';

                                else

                                    SPIKE_VECTOR(SPIKE_INDEX) <= '0';

                                end if;                            

                            elsif CONVMODE = B"01" then

                                if DATA_RAM(MEM_OFFSET) = TIMESTEP then

                                    SPIKE_VECTOR(SPIKE_INDEX) <= '1';

                                else

                                    SPIKE_VECTOR(SPIKE_INDEX) <= '0';

                                end if;

                            end if;

                            STALL_FLAG <= '0';

                        else
                            
                            STALL_FLAG <= '1';

                        end if;

                    when SEND_TIMESTEP_VECTOR =>

                        SPIKE_INDEX <= 0;

                        if MEM_OFFSET = DATA_COUNT_INT-1 then

                            CONVERSION_STATE <= WAIT_FOR_UPDATE;

                        else

                            CONVERSION_STATE   <= PREP_TIMESTEP_VECTOR;

                            if MEM_OFFSET < DATA_COUNT_INT-1 then

                                MEM_OFFSET <= MEM_OFFSET + 1;

                            end if;

                        end if;

                        SPIKE_VECTOR <= (others=>'0');
                        SPIKE_VECTOR_VLD <= '0';

                    when WAIT_FOR_UPDATE =>

                        if NEW_TIMESTEP = '1' then

                            CONVERSION_STATE   <= CHECK_TIMESTEP;

                        else

                            CONVERSION_STATE   <= WAIT_FOR_UPDATE;
                                
                        end if;

                    when CHECK_TIMESTEP =>

                        if TIMESTEP = TIME_WIND_INT - 1 then

                            CONVERSION_STATE   <= DONE;

                        else

                            CONVERSION_STATE <= PREP_TIMESTEP_VECTOR;
                            SPIKE_VECTOR     <= (others=>'0');
                            SPIKE_INDEX      <= 0;
                            MEM_OFFSET       <= 0;
                            SPIKE_VECTOR_VLD <= '0';
                            TIMESTEP         <= TIMESTEP + 1;

                        end if;

                    when DONE =>

                        CONV_DONE <= '1';
                        STOP_LFSR <= '1';

                    when others =>
                                    NULL;

                end case;

            end if;                

        end if;

    end process VECTOR_GEN;

    SPIKE_OUT <= SPIKE_VECTOR ; 
    SPIKE_VLD <= SPIKE_VECTOR_VLD ;

    -- LFSR

    LFSR : process(D2S_RCLK)

        begin

            if rising_edge(D2S_RCLK) then

                if (D2S_CONV_RST = '1') then

                    LFSR_STATE <= IDLE;

                else

                    case LFSR_STATE is

                        when IDLE =>

                            if CONVMODE = B"00" then

                                if VLD_DLY_SYNC = '1' then

                                    RANDOM_VECTOR <= SEED;
                                    LFSR_STATE    <= LAUNCH;

                                else
                                    
                                    LFSR_STATE    <= IDLE;                                    
                                
                                end if;

                            end if;

                        when LAUNCH =>

                            RANDOM_VECTOR(31 downto 1) <= RANDOM_VECTOR(30 downto 0) ;
                            RANDOM_VECTOR(0) <= not(RANDOM_VECTOR(31) XOR RANDOM_VECTOR(22) XOR RANDOM_VECTOR(2) XOR RANDOM_VECTOR(1));

                            if STOP_LFSR = '1' then

                                LFSR_STATE    <= IDLE;

                            else

                                LFSR_STATE    <= LAUNCH;

                            end if;

                        when others => 
                                    NULL;
                    end case;

              end if;

            end if;

    end process LFSR;

    RANDOM_VECTOR_UNSGN <= unsigned(RANDOM_VECTOR);

end forever_your_star;