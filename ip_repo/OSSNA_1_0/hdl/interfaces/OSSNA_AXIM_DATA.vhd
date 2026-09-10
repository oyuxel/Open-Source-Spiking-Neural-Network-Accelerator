library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity OSSNA_AXIM_DATA is
	generic (
		outstanding_limit           : integer  := 16 ;
        MAX_TARGET_FIFO_DWIDTH      : integer  := 16;
        MAX_TARGET_BRAM_DWIDTH      : integer  := 32;
        MAX_TARGET_BRAM_AWIDTH      : integer  := 12;

		C_M_TARGET_SLAVE_BASE_ADDR	: std_logic_vector	:= x"40000000";
		C_M_AXI_BURST_LEN	        : integer	:= 16;
		C_M_AXI_ID_WIDTH	        : integer	:= 1;
		C_M_AXI_ADDR_WIDTH	        : integer	:= 32;
		C_M_AXI_DATA_WIDTH	        : integer	:= 32;
		C_M_AXI_AWUSER_WIDTH	    : integer	:= 0;
		C_M_AXI_ARUSER_WIDTH	    : integer	:= 0;
		C_M_AXI_WUSER_WIDTH	        : integer	:= 0;
		C_M_AXI_RUSER_WIDTH	        : integer	:= 0;
		C_M_AXI_BUSER_WIDTH	        : integer	:= 0
	);
	port (
   
        -- DMA_CNTRL(0) -> START READ
        -- DMA_CNTRL(1) -> START WRITE
        -- DMA_CNTRL(2) -> DMA SOFT RESET 

        DMA_START_READ                 : in  std_logic;  
        DMA_START_WRITE                : in  std_logic;  
        DMA_RESET_SOFT                 : in  std_logic;  
        TARGET_SELECT                  : in  std_logic;                     -- 0: BRAM     , 1: FIFO
        FIFO_TYPE                      : in  std_logic;                     -- 0: Standart , 1: FWFT
        BYTE_PER_WORD                  : in  std_logic_vector(31 downto 0);  
        TOTAL_BYTES                    : in  std_logic_vector(31 downto 0);
        TOTAL_WORDS                    : in  std_logic_vector(31 downto 0); 

        BRAM_READ_DELAY                : in  std_logic_vector(31 downto 0); 

        BRAM_BASEADDR                  : in  std_logic_vector(31 downto 0);
        DDR_BASEADDR                   : in  std_logic_vector(31 downto 0);

        TARGET_READ_DONE               : out std_logic;
        TARGET_WRITE_DONE              : out std_logic;
        TARGET_READ_ERROR              : out std_logic;
        TARGET_WRITE_ERROR             : out std_logic;

        BRAM_ADDR                      : out std_logic_vector(MAX_TARGET_BRAM_AWIDTH-1 downto 0);
        BRAM_DIN                       : out std_logic_vector(MAX_TARGET_BRAM_DWIDTH-1 downto 0); 
        BRAM_WE                        : out std_logic;
        BRAM_DOUT                      : in  std_logic_vector(MAX_TARGET_BRAM_DWIDTH-1 downto 0);
            
        FIFO_WREN                      : out std_logic;
        FIFO_DIN                       : out std_logic_vector(MAX_TARGET_FIFO_DWIDTH-1 downto 0);
        FIFO_RDEN                      : out std_logic;
        FIFO_DOUT                      : in  std_logic_vector(MAX_TARGET_FIFO_DWIDTH-1 downto 0);

        FIFO_EMPTY                     : in  std_logic; 
        FIFO_FULL                      : in  std_logic;

		m_axi_aclk	    : in  std_logic;
		m_axi_aresetn   : in  std_logic;
		m_axi_awid	    : out std_logic_vector(c_m_axi_id_width-1 downto 0);
		m_axi_awaddr	: out std_logic_vector(c_m_axi_addr_width-1 downto 0);
		m_axi_awlen	    : out std_logic_vector(7 downto 0);
		m_axi_awsize	: out std_logic_vector(2 downto 0);
		m_axi_awburst	: out std_logic_vector(1 downto 0);
		m_axi_awlock	: out std_logic;
		m_axi_awcache	: out std_logic_vector(3 downto 0);
		m_axi_awprot	: out std_logic_vector(2 downto 0);
		m_axi_awqos	    : out std_logic_vector(3 downto 0);
		m_axi_awuser	: out std_logic_vector(c_m_axi_awuser_width-1 downto 0);
		m_axi_awvalid	: out std_logic;
		m_axi_awready	: in  std_logic;
		m_axi_wdata	    : out std_logic_vector(c_m_axi_data_width-1 downto 0);
		m_axi_wstrb	    : out std_logic_vector(c_m_axi_data_width/8-1 downto 0);
		m_axi_wlast	    : out std_logic;
		m_axi_wuser	    : out std_logic_vector(c_m_axi_wuser_width-1 downto 0);
		m_axi_wvalid	: out std_logic;
		m_axi_wready	: in  std_logic;
		m_axi_bid	    : in  std_logic_vector(c_m_axi_id_width-1 downto 0);
		m_axi_bresp	    : in  std_logic_vector(1 downto 0);
		m_axi_buser	    : in  std_logic_vector(c_m_axi_buser_width-1 downto 0);
		m_axi_bvalid	: in  std_logic;
		m_axi_bready	: out std_logic;
		m_axi_arid	    : out std_logic_vector(c_m_axi_id_width-1 downto 0);
		m_axi_araddr	: out std_logic_vector(c_m_axi_addr_width-1 downto 0);
		m_axi_arlen	    : out std_logic_vector(7 downto 0);
		m_axi_arsize	: out std_logic_vector(2 downto 0);
		m_axi_arburst	: out std_logic_vector(1 downto 0);
		m_axi_arlock	: out std_logic;
		m_axi_arcache	: out std_logic_vector(3 downto 0);
		m_axi_arprot	: out std_logic_vector(2 downto 0);
		m_axi_arqos	    : out std_logic_vector(3 downto 0);
		m_axi_aruser	: out std_logic_vector(c_m_axi_aruser_width-1 downto 0);
		m_axi_arvalid	: out std_logic;
		m_axi_arready	: in  std_logic;
		m_axi_rid	    : in  std_logic_vector(c_m_axi_id_width-1 downto 0);
		m_axi_rdata	    : in  std_logic_vector(c_m_axi_data_width-1 downto 0);
		m_axi_rresp	    : in  std_logic_vector(1 downto 0);                 
		m_axi_rlast	    : in  std_logic;
		m_axi_ruser	    : in  std_logic_vector(c_m_axi_ruser_width-1 downto 0);
		m_axi_rvalid	: in  std_logic;
		m_axi_rready	: out std_logic
	);
end OSSNA_AXIM_DATA;

architecture je_pardonne of OSSNA_AXIM_DATA is

    signal START_READ     : std_logic;
    signal START_WRITE    : std_logic;
    signal DMA_SOFT_RESET : std_logic;

    constant AXI_DATA_WIDTH  : integer := C_M_AXI_DATA_WIDTH;
    signal BRAM_DELAY_LIM : integer;

    signal BRAM_DELAY_CNT : integer;

    -- DMA Signals & Constants Begin --

    signal MSM_WRITE_DONE : std_logic;
    signal MSM_READ_DONE  : std_logic;
						
	constant beatbytes : integer := c_m_axi_data_width/8;

	signal axi_arid	    :std_logic_vector(c_m_axi_id_width-1 downto 0) := (others=>'0');
	signal axi_araddr   :std_logic_vector(c_m_axi_addr_width-1 downto 0) := (others=>'0');
	signal axi_arlen	:std_logic_vector(7 downto 0) := (others=>'0');
	signal axi_arsize	:std_logic_vector(2 downto 0) := (others=>'0');
	signal axi_arburst	:std_logic_vector(1 downto 0) := (others=>'0');
	signal axi_arlock   :std_logic := '0';
	signal axi_arcache	:std_logic_vector(3 downto 0) := (others=>'0');
	signal axi_arprot 	:std_logic_vector(2 downto 0) := (others=>'0');
	signal axi_arqos	:std_logic_vector(3 downto 0) := (others=>'0');
	signal axi_aruser 	:std_logic_vector(c_m_axi_aruser_width-1 downto 0) := (others=>'0');
	signal axi_arvalid	:std_logic := '0';
	signal axi_rready	:std_logic := '0';

    signal read_outstanding_counter : unsigned(4 downto 0); 
	constant read_outstanding_limit : unsigned(4 downto 0) := to_unsigned(outstanding_limit,5);

	signal rd_traffic_full : std_logic;

	signal AXI_AWID		: std_logic_vector(C_M_AXI_ID_WIDTH-1 downto 0) := (others=>'0');
	signal AXI_AWADDR	: std_logic_vector(C_M_AXI_ADDR_WIDTH-1 downto 0) := (others=>'0');
	signal AXI_AWLEN	: std_logic_vector(7 downto 0) := (others=>'0');
	signal AXI_AWSIZE	: std_logic_vector(2 downto 0) := (others=>'0');
	signal AXI_AWBURST	: std_logic_vector(1 downto 0) := (others=>'0');
	signal AXI_AWLOCK	: std_logic := '0';
	signal AXI_AWCACHE	: std_logic_vector(3 downto 0) := (others=>'0');
	signal AXI_AWPROT	: std_logic_vector(2 downto 0) := (others=>'0');
	signal AXI_AWQOS	: std_logic_vector(3 downto 0) := (others=>'0');
	signal AXI_AWUSER	: std_logic_vector(C_M_AXI_AWUSER_WIDTH-1 downto 0) := (others=>'0');
	signal AXI_AWVALID	: std_logic := '0' ;
	signal AXI_WDATA	: std_logic_vector(C_M_AXI_DATA_WIDTH-1 downto 0) := (others=>'0');
	signal AXI_WSTRB	: std_logic_vector(C_M_AXI_DATA_WIDTH/8-1 downto 0) := (others=>'0');
	signal AXI_WLAST	: std_logic:= '0';
	signal AXI_WUSER	: std_logic_vector(C_M_AXI_WUSER_WIDTH-1 downto 0) := (others=>'0');
	signal AXI_WVALID	: std_logic:= '0';
	signal AXI_BREADY	: std_logic:= '0';

    signal LAST_WSTRB	: std_logic_vector(C_M_AXI_DATA_WIDTH/8-1 downto 0) := (others=>'0');

	signal   WRITE_OUTSTANDING_COUNTER : unsigned(4 downto 0); 
	constant WRITE_OUTSTANDING_LIMIT   : unsigned(4 downto 0) := to_unsigned(OUTSTANDING_LIMIT,5);

	signal WR_TRAFFIC_FULL : std_logic;

    constant FIFO_DEPTH : integer := 32; 
    type fifo_array_t is array (0 to FIFO_DEPTH-1) of std_logic_vector(C_M_AXI_DATA_WIDTH-1 downto 0);

    signal read_fifo             : fifo_array_t;
    signal read_fifo_wr_ptr      : integer range 0 to FIFO_DEPTH-1;
    signal read_fifo_rd_ptr      : integer range 0 to FIFO_DEPTH-1;
    signal read_fifo_count       : integer range 0 to FIFO_DEPTH;
    signal read_fifo_rd_en       : std_logic;
    signal read_fifo_wr_en       : std_logic;
    signal read_fifo_empty       : std_logic;
    signal read_fifo_almost_full : std_logic;
    signal read_fifo_data_in     : std_logic_vector(C_M_AXI_DATA_WIDTH-1 downto 0);
    signal read_fifo_data_out    : std_logic_vector(C_M_AXI_DATA_WIDTH-1 downto 0);

    type DMA_STATES is (IDLE,
                        SET_AXI_BURST_LENGTH_0,
                        SET_AXI_BURST_LENGTH_1,
                        SET_AXI_BURST_LENGTH_2,
                        SET_AXI_BURST_LENGTH_3,
                        SEND_AXI_ARVALID,
                        WAIT_AXI_RREADY,
                        WAIT_AXI_RDATA,
                        NEXT_READ_BURST,
                        NEXT_READ_BURST_VALID,
                        READ_CHANNEL_ERROR,
                        READ_CHANNEL_DONE,
                        SEND_AXI_AWVALID,
                        WAIT_AXI_WREADY,
                        SEND_AXI_WDATA,
                        SEND_AXI_WVALID,
                        SEND_AXI_BREADY,
                        NEXT_WRITE_BURST,
                        NEXT_WRITE_BURST_VALID,
                        WRITE_CHANNEL_ERROR,
                        WRITE_CHANNEL_DONE
                        );

    signal DMA_STATE : DMA_STATES;

    signal DDRADDR       : integer;
    signal BRAMADDR      : integer;
    signal BYTESPERWORD  : integer;
    signal TOTALBYTES    : integer;
    signal TOTALWORDS    : integer;

    -- DMA Signals & Constants End --

    -- Data Manager Signals & Constants Begin --

    type DATA_MANAGER_STATES is (IDLE,
                                WAIT_READ_FIFO,
                                READ_READ_FIFO,
                                BUFFER_RDATA,
                                DISMANTLE_RDATA,
                                NEXT_RDATA,
                                WRITE_WORD,
                                GET_BURST_WORD_COUNT_0,
                                GET_BURST_WORD_COUNT_1,
                                CALCULATE_REMAINING_WORDS,
                                READ_TARGET,
                                FETCH_TARGET_WORD,
                                WAIT_TARGET_DATA,
                                LATCH_WORD_DATA,
                                CLEAR_RDEN_AND_SEND,
                                WAIT_AXI_HANDSHAKE,
                                CHECK_REMAINING_WORDS,
                                CHECK_REMAINING_BURSTS,
                                COMPLETED
                                );

    signal DATA_MANAGER_STATE : DATA_MANAGER_STATES;

    signal TARGET_DIN_BUFFER : std_logic_vector(C_M_AXI_DATA_WIDTH-1 downto 0);

    signal word_rotator : integer;
    signal word_rotator_limit : integer;

    signal BRAM_ADDR_INT   : integer;

    signal BRAM_ADDR_DELAY : std_logic;

    signal MANAGER_TOTALWORDS : integer;

    signal req_beats   : integer;
    signal bytes_to_4k : integer;
    signal beats_to_4k : integer;

    signal current_burst_beats : integer;
    signal current_burst_bytes : integer;

    signal current_write_burst_words : integer;
    signal write_burst_word_counter : integer;

    signal WORDS_PER_BEAT : integer;

    signal BRAM_DOUT_BUFFER : std_logic_vector(MAX_TARGET_BRAM_DWIDTH-1 downto 0);
    signal FIFO_DOUT_BUFFER : std_logic_vector(MAX_TARGET_FIFO_DWIDTH-1 downto 0);

    signal AXI_WDATA_BUFFER : std_logic_vector(C_M_AXI_DATA_WIDTH-1 downto 0);
    signal AXI_WDATA_READY  : std_logic;

    signal SEND_LAST_BEAT : std_logic;

    signal OPERATION_DONE : std_logic;

    signal LAST_WSTRB_BITS : integer;

    signal last_burst_flag : std_logic;

    -- Data Manager Signals & Constants End --

    function calc_last_wstrb (
        wstrb_bits  : integer;
        wstrb_width : integer
    ) return std_logic_vector is
        variable v_wstrb : std_logic_vector(wstrb_width - 1 downto 0);
    begin
        if wstrb_bits = 0 then
            v_wstrb := (others => '1');
        else
            for i in 0 to wstrb_width - 1 loop
                if i < wstrb_bits then
                    v_wstrb(i) := '1';
                else
                    v_wstrb(i) := '0';
                end if;
            end loop;
        end if;

        return v_wstrb;
    end function calc_last_wstrb;
begin


    START_READ     <= DMA_START_READ;
    START_WRITE    <= DMA_START_WRITE;
    DMA_SOFT_RESET <= not DMA_RESET_SOFT;

    -- AXI Read Channel Begin -- 

	m_axi_arid	  <= axi_arid	 ;
	m_axi_araddr  <= axi_araddr  ;
	m_axi_arlen	  <= axi_arlen	 ;
	m_axi_arsize  <= axi_arsize	 ;
	m_axi_arburst <= axi_arburst ;
	m_axi_arlock  <= axi_arlock  ;
	m_axi_arcache <= axi_arcache ;
	m_axi_arprot  <= axi_arprot  ;
	m_axi_arqos	  <= axi_arqos	 ;
	m_axi_aruser  <= axi_aruser  ;
	m_axi_arvalid <= axi_arvalid ;
	m_axi_rready  <= axi_rready	 ; 

	axi_arsize  <= b"000" when beatbytes = 1   else
				   b"001" when beatbytes = 2   else
				   b"010" when beatbytes = 4   else	
				   b"011" when beatbytes = 8   else
				   b"100" when beatbytes = 16  else
				   b"101" when beatbytes = 32  else
				   b"110" when beatbytes = 64  else
				   b"111" when beatbytes = 128 else
				   b"000";

    rd_traffic_full <= '1' when read_outstanding_counter = read_outstanding_limit else
					   '0';

	read_outstand : process(m_axi_aclk) 
    begin
        if rising_edge(m_axi_aclk) then
            if m_axi_aresetn = '0' or DMA_SOFT_RESET = '0' then
                read_outstanding_counter <= (others=>'0');
            else
                if (axi_arvalid = '1' and m_axi_arready = '1') and not (m_axi_rvalid = '1' and axi_rready = '1' and m_axi_rlast = '1') then
                    read_outstanding_counter <= read_outstanding_counter + 1;
                elsif not (axi_arvalid = '1' and m_axi_arready = '1') and (m_axi_rvalid = '1' and axi_rready = '1' and m_axi_rlast = '1') then
                    read_outstanding_counter <= read_outstanding_counter - 1;
                end if;
            end if;
        end if;
    end process read_outstand;

	M_AXI_AWID		<= AXI_AWID		;
	M_AXI_AWADDR	<= AXI_AWADDR	;	
	M_AXI_AWLEN		<= AXI_AWLEN	;	
	M_AXI_AWSIZE	<= AXI_AWSIZE	;	
	M_AXI_AWBURST	<= AXI_AWBURST	;	
	M_AXI_AWLOCK	<= AXI_AWLOCK	;
	M_AXI_AWCACHE	<= AXI_AWCACHE	;	
	M_AXI_AWPROT	<= AXI_AWPROT	;
	M_AXI_AWQOS		<= AXI_AWQOS	;
	M_AXI_AWUSER	<= AXI_AWUSER	;
	M_AXI_AWVALID	<= AXI_AWVALID	;	
	M_AXI_WDATA		<= AXI_WDATA	;	
	M_AXI_WSTRB		<= AXI_WSTRB	;	
	M_AXI_WLAST		<= AXI_WLAST	;	
	M_AXI_WUSER		<= AXI_WUSER	;	
	M_AXI_WVALID	<= AXI_WVALID	;	
	M_AXI_BREADY	<= AXI_BREADY	;	

	AXI_AWCACHE  <= B"0011";

	AXI_AWPROT  <= B"000";
	AXI_AWQOS   <= (others=>'0');
	AXI_AWUSER  <= (others=>'0');
	AXI_AWLOCK  <= '0';


	AXI_AWSIZE    <= B"000" when BEATBYTES = 1   else
			   		 B"001" when BEATBYTES = 2   else
			   		 B"010" when BEATBYTES = 4   else	
			   		 B"011" when BEATBYTES = 8   else
			   		 B"100" when BEATBYTES = 16  else
			   		 B"101" when BEATBYTES = 32  else
			   		 B"110" when BEATBYTES = 64  else
			   		 B"111" when BEATBYTES = 128 else
			   		 B"000";

	WR_TRAFFIC_FULL <= '1' when WRITE_OUTSTANDING_COUNTER = WRITE_OUTSTANDING_LIMIT else
					   '0';

    WRITE_OUTSTAND : process(M_AXI_ACLK) 
    begin
        if rising_edge(M_AXI_ACLK) then
            if M_AXI_ARESETN = '0' then
                WRITE_OUTSTANDING_COUNTER <= (others=>'0');
            else
                if (AXI_AWVALID = '1' and M_AXI_AWREADY = '1') and not (M_AXI_BVALID = '1' and AXI_BREADY = '1') then
                    WRITE_OUTSTANDING_COUNTER <= WRITE_OUTSTANDING_COUNTER + 1;
                elsif not (AXI_AWVALID = '1' and M_AXI_AWREADY = '1') and (M_AXI_BVALID = '1' and AXI_BREADY = '1') then
                    WRITE_OUTSTANDING_COUNTER <= WRITE_OUTSTANDING_COUNTER - 1;
                end if;
            end if;
        end if;
    end process WRITE_OUTSTAND;

    SHALLOW_READ_FIFO : process(m_axi_aclk)
    begin
        if rising_edge(m_axi_aclk) then
            if m_axi_aresetn = '0' or DMA_SOFT_RESET = '0'  then
                read_fifo_wr_ptr   <= 0;
                read_fifo_rd_ptr   <= 0;
                read_fifo_count    <= 0;
                read_fifo          <= (others => (others => '0'));
                read_fifo_data_out <= (others=>'0');
            else
                if DMA_STATE = IDLE then
                    read_fifo_wr_ptr   <= 0;
                    read_fifo_rd_ptr   <= 0;
                    read_fifo_count    <= 0;
                else
                    if read_fifo_wr_en = '1' and read_fifo_count < FIFO_DEPTH then
                        read_fifo(read_fifo_wr_ptr) <= read_fifo_data_in;
                        read_fifo_wr_ptr <= (read_fifo_wr_ptr + 1) mod FIFO_DEPTH;
                    end if;

                    if read_fifo_rd_en = '1' and read_fifo_count > 0 then
                        read_fifo_rd_ptr <= (read_fifo_rd_ptr + 1) mod FIFO_DEPTH;
                        --read_fifo_data_out <= read_fifo(read_fifo_rd_ptr);
                    end if;

                    if (read_fifo_wr_en = '1' and read_fifo_count < FIFO_DEPTH) and not (read_fifo_rd_en = '1' and read_fifo_count > 0) then
                        read_fifo_count <= read_fifo_count + 1;
                    elsif not (read_fifo_wr_en = '1' and read_fifo_count < FIFO_DEPTH) and (read_fifo_rd_en = '1' and read_fifo_count > 0) then
                        read_fifo_count <= read_fifo_count - 1;
                    end if;
                end if;
            end if;
        end if;
    end process SHALLOW_READ_FIFO;

    read_fifo_empty <= '1' when read_fifo_count = 0 else 
                  '0';

    read_fifo_almost_full <= '1' when read_fifo_count >= 12 else 
                        '0';

    axi_rready <= (not read_fifo_almost_full) and (not FIFO_FULL);

    BYTESPERWORD  <= to_integer(unsigned(BYTE_PER_WORD));

    -- AXI Read Channel End -- 

    TARGET_READ_DONE  <= OPERATION_DONE and MSM_READ_DONE;
    TARGET_WRITE_DONE <= OPERATION_DONE and MSM_WRITE_DONE;
        
    DMA : process (m_axi_aclk) 

    begin

        if rising_edge(m_axi_aclk) then

            if m_axi_aresetn = '0' or DMA_SOFT_RESET = '0' then

                DMA_STATE <= IDLE;

            else

                case DMA_STATE is

                    when IDLE =>

                        DDRADDR       <= to_integer(unsigned(DDR_BASEADDR));
                        BRAMADDR      <= to_integer(unsigned(BRAM_BASEADDR));
                        TOTALBYTES    <= to_integer(unsigned(TOTAL_BYTES));

                        read_fifo_wr_en <= '0';

                        TARGET_WRITE_ERROR <= '0';
                        TARGET_READ_ERROR <= '0';

                        MSM_READ_DONE <= '0';
                        MSM_WRITE_DONE <= '0';

                        req_beats   <= 0;
                        bytes_to_4k <= 0;
                        beats_to_4k <= 0;

                        current_burst_beats <= 0;
                        current_burst_bytes <= 0;

                        axi_arid    <= (others=>'0');
                        axi_arlock  <= '0';
                        axi_arcache <= B"0011";
                        axi_arprot  <= B"000";
                        axi_arqos   <= (others=>'0');
                        axi_aruser  <= (others=>'0');
                        axi_arvalid <= '0';

                        AXI_AWID    <= (others=>'0');
                        AXI_AWADDR  <= (others=>'0');
                        AXI_AWVALID <= '0';
                        AXI_WSTRB   <= (others=>'1');
                        AXI_WLAST   <= '0';
                        AXI_WUSER   <= (others=>'0');
                        AXI_WVALID  <= '0';
                        AXI_BREADY  <= '0';
                        AXI_AWLEN   <= (others=>'0');   
                        
                        LAST_WSTRB <= (others=>'0'); 

                        read_fifo_data_in <= (others=>'0'); 

                        LAST_WSTRB_BITS <= 0;

                        last_burst_flag <= '0';

                        if START_READ = '0' and START_WRITE = '0' then

                            DMA_STATE <= IDLE;

                        else
                            
                            DMA_STATE <= SET_AXI_BURST_LENGTH_0;

                            LAST_WSTRB_BITS <= TOTALBYTES mod beatbytes;

                        end if;

                    when SET_AXI_BURST_LENGTH_0 =>

                        LAST_WSTRB <= calc_last_wstrb(LAST_WSTRB_BITS, beatbytes);

                        req_beats <= (TOTALBYTES + beatbytes - 1) / beatbytes;

                        bytes_to_4k <= 4096 - to_integer(unsigned(std_logic_vector(to_unsigned(DDRADDR, 32)(11 downto 0))));

                        DMA_STATE <= SET_AXI_BURST_LENGTH_1;

                    when SET_AXI_BURST_LENGTH_1 =>
      
                        beats_to_4k <= bytes_to_4k / beatbytes;

                        DMA_STATE <= SET_AXI_BURST_LENGTH_2;

                    when SET_AXI_BURST_LENGTH_2 =>
                        
                        if req_beats <= 256 and req_beats <= beats_to_4k then
                            current_burst_beats <= req_beats;
                            last_burst_flag <= '1';
                        elsif beats_to_4k <= 256 then
                            current_burst_beats <= beats_to_4k;
                        else
                            current_burst_beats <= 256;
                        end if;

                        DMA_STATE <= SET_AXI_BURST_LENGTH_3;

                    when SET_AXI_BURST_LENGTH_3 =>

                        current_burst_bytes <= current_burst_beats * beatbytes;

                        axi_araddr <= std_logic_vector(to_unsigned(DDRADDR,axi_araddr'length));
                        axi_arlen   <= std_logic_vector(to_unsigned(current_burst_beats - 1, 8));
                        axi_arburst <= "01"; 

                        axi_awaddr <= std_logic_vector(to_unsigned(DDRADDR,axi_awaddr'length));
                        axi_awlen   <= std_logic_vector(to_unsigned(current_burst_beats - 1, 8));
                        axi_awburst <= "01"; 

                        if START_READ = '1' and START_WRITE = '0' then

                            DMA_STATE <= SEND_AXI_ARVALID;

                        elsif START_READ = '0' and START_WRITE = '1' then

                            DMA_STATE <= SEND_AXI_AWVALID;

                        else
                            
                            DMA_STATE <= IDLE;

                        end if;

                    when SEND_AXI_ARVALID =>

                        if (rd_traffic_full = '0') then 

                            axi_arvalid <= '1';
                            DMA_STATE <= WAIT_AXI_RREADY;

                        else

                            axi_arvalid <= '0';
                            DMA_STATE <= SEND_AXI_ARVALID;	

                        end if;

                    when WAIT_AXI_RREADY =>

                        if m_axi_arready = '1' then

                            axi_arvalid <= '0';
                            DMA_STATE  <= WAIT_AXI_RDATA;

                        else

                            DMA_STATE <= WAIT_AXI_RREADY;

                        end if;

                    when WAIT_AXI_RDATA =>

                        read_fifo_wr_en <= '0';

                        if m_axi_rvalid = '1' and axi_rready = '1' then

                            read_fifo_data_in <= m_axi_rdata;
                            read_fifo_wr_en <= '1';

                            if m_axi_rlast = '1' then 

                                DMA_STATE <= NEXT_READ_BURST; 

                            elsif m_axi_rresp(1) = '1' then 
                            
                                DMA_STATE <= READ_CHANNEL_ERROR; 

                            end if;
                        
                        end if;

                    when NEXT_READ_BURST =>

                        read_fifo_wr_en <= '0';
                        DDRADDR  <= DDRADDR + current_burst_bytes;
                        TOTALBYTES <= TOTALBYTES - current_burst_bytes;
                        DMA_STATE  <= NEXT_READ_BURST_VALID;

                    when NEXT_READ_BURST_VALID =>

                        if TOTALBYTES > 0 then

                            DMA_STATE  <= SET_AXI_BURST_LENGTH_0;

                        else

                            DMA_STATE <= READ_CHANNEL_DONE; 

                        end if;

                    when READ_CHANNEL_ERROR =>

                        TARGET_WRITE_ERROR <= '1';

                        if START_READ = '0' and START_WRITE = '0' then
                            DMA_STATE <= IDLE;
                        else
                            DMA_STATE <= READ_CHANNEL_ERROR;
                        end if;

                    when READ_CHANNEL_DONE =>

                        MSM_READ_DONE <= '1';

                        if START_READ = '0' and START_WRITE = '0' then
                            DMA_STATE <= IDLE;
                        else
                            DMA_STATE <= READ_CHANNEL_DONE;
                        end if;

                    when SEND_AXI_AWVALID =>

                        AXI_BREADY  <= '0';

                        if (WR_TRAFFIC_FULL = '0') then 
                            AXI_AWVALID <= '1';
                            DMA_STATE <= WAIT_AXI_WREADY;
                        else
                            AXI_AWVALID <= '0';
                            DMA_STATE <= SEND_AXI_AWVALID;                                    
                        end if;

                    when WAIT_AXI_WREADY =>

                        if M_AXI_AWREADY = '1' then
                            AXI_AWVALID <= '0';
                            DMA_STATE <= SEND_AXI_WDATA;
                        else
                            DMA_STATE <= WAIT_AXI_WREADY;
                        end if;

                    when SEND_AXI_WDATA =>

                        AXI_BREADY <= '0';

                        if m_axi_bresp(1) = '1' then 
                            
                            AXI_WVALID <= '0';
                            AXI_WLAST  <= '0';
                            DMA_STATE  <= WRITE_CHANNEL_ERROR;

                        elsif AXI_WVALID = '0' then
                            if AXI_WDATA_READY = '1' then
                                AXI_WVALID <= '1';
                                AXI_WDATA  <= AXI_WDATA_BUFFER;
                                
                                if SEND_LAST_BEAT = '1' then
                                    AXI_WLAST <= '1';
                                    if last_burst_flag = '1' then
                                        AXI_WSTRB <= LAST_WSTRB;
                                    else
                                        AXI_WSTRB <= (others => '1');
                                    end if;
                                else
                                    AXI_WLAST <= '0';
                                    AXI_WSTRB <= (others => '1');
                                end if;
                            end if;
                        
                        else
                            if M_AXI_WREADY = '1' then
                                AXI_WVALID <= '0';
                                AXI_WLAST  <= '0';
                                
                                if SEND_LAST_BEAT = '1' then
                                    DMA_STATE <= SEND_AXI_BREADY;
                                else
                                    DMA_STATE <= SEND_AXI_WDATA;
                                end if;
                            end if;
                        end if;

                    when SEND_AXI_BREADY =>

                        AXI_WLAST <= '0';
                        AXI_BREADY <= '1';
                        AXI_WVALID  <= '0';

                        if m_axi_bvalid = '1' then

                            AXI_BREADY <= '0';
                            DMA_STATE <= NEXT_WRITE_BURST;
                                
                        end if;

                    when NEXT_WRITE_BURST =>

                        DDRADDR  <= DDRADDR + current_burst_bytes;
                        TOTALBYTES <= TOTALBYTES - current_burst_bytes;
                        DMA_STATE  <= NEXT_WRITE_BURST_VALID;

                    when NEXT_WRITE_BURST_VALID =>

                        if TOTALBYTES > 0 then

                            DMA_STATE  <= SET_AXI_BURST_LENGTH_0;

                        else

                            DMA_STATE <= WRITE_CHANNEL_DONE; 

                        end if;

                    when WRITE_CHANNEL_ERROR =>

                        TARGET_READ_ERROR <= '1';

                        if START_READ = '0' and START_WRITE = '0' then
                            DMA_STATE <= IDLE;
                        else
                            DMA_STATE <= WRITE_CHANNEL_ERROR;
                        end if;

                    when WRITE_CHANNEL_DONE =>

                        MSM_WRITE_DONE <= '1';

                        if START_READ = '0' and START_WRITE = '0' then
                            DMA_STATE <= IDLE;
                        else
                            DMA_STATE <= WRITE_CHANNEL_DONE;
                        end if;

                    when others =>
                        DMA_STATE <= IDLE;

                end case;

            end if;

        end if;

    end process DMA;

    DATA_MANAGER : process (m_axi_aclk) 
        variable v_din_buf     : std_logic_vector(127 downto 0);
        variable v_target_word : std_logic_vector(127 downto 0);
        variable v_source_word : std_logic_vector(127 downto 0);
        variable v_wdata_buf   : std_logic_vector(127 downto 0);
    begin

        if rising_edge(m_axi_aclk) then

            if m_axi_aresetn = '0' or DMA_SOFT_RESET = '0' then
                DATA_MANAGER_STATE <= IDLE;
                word_rotator       <= 0;
                word_rotator_limit <= 0;
                BRAM_ADDR_INT      <= 0;
                MANAGER_TOTALWORDS <= 0;
                FIFO_DIN           <= (others => '0');
                BRAM_DIN           <= (others => '0');
                TARGET_DIN_BUFFER  <= (others => '0');
                WORDS_PER_BEAT     <= 0;
                BRAM_DELAY_CNT     <= 0;
                OPERATION_DONE     <= '0';
                AXI_WDATA_READY    <= '0';
                OPERATION_DONE     <= '0';
                FIFO_RDEN          <= '0';
                FIFO_WREN          <= '0';
                read_fifo_rd_en    <= '0';
                BRAM_WE            <= '0';
                BRAM_ADDR_DELAY    <= '0';

                current_write_burst_words <= 0;
                write_burst_word_counter <= 0;

                SEND_LAST_BEAT <= '0';

            else

                FIFO_WREN       <= '0';
                read_fifo_rd_en <= '0';
                BRAM_WE         <= '0';
                

                case DATA_MANAGER_STATE is

                    when IDLE =>

                        word_rotator       <= 0;
                        word_rotator_limit <= 0;
                        
                        BRAM_ADDR_INT      <= to_integer(unsigned(BRAM_BASEADDR));

                        MANAGER_TOTALWORDS <= to_integer(unsigned(TOTAL_WORDS));

                        BRAM_DOUT_BUFFER <= (others=>'0');
                        FIFO_DOUT_BUFFER <= (others=>'0');                          

                        AXI_WDATA_READY <= '0';

                        OPERATION_DONE   <= '0';

                        if START_READ = '1' and START_WRITE = '0' then

                            if read_fifo_empty = '0' then
                                DATA_MANAGER_STATE <= READ_READ_FIFO;
                            else
                                DATA_MANAGER_STATE <= WAIT_READ_FIFO;
                            end if;

                        elsif START_READ = '0' and START_WRITE = '1' then 

                            DATA_MANAGER_STATE <= GET_BURST_WORD_COUNT_0;

                        else

                            DATA_MANAGER_STATE <= IDLE;

                        end if;

                    when WAIT_READ_FIFO =>

                        if read_fifo_empty = '0' then
                            DATA_MANAGER_STATE <= READ_READ_FIFO;
                        end if;

                    when READ_READ_FIFO =>

                        read_fifo_rd_en    <= '1';
                    
                        case C_M_AXI_DATA_WIDTH is
                            when 32 =>
                                case BYTESPERWORD is
                                    when 1      => word_rotator_limit <= 4;
                                    when 2      => word_rotator_limit <= 2;
                                    when 4      => word_rotator_limit <= 1;
                                    when others => word_rotator_limit <= 1;
                                end case;
                            when 64 =>
                                case BYTESPERWORD is
                                    when 1      => word_rotator_limit <= 8;
                                    when 2      => word_rotator_limit <= 4;
                                    when 4      => word_rotator_limit <= 2;
                                    when 8      => word_rotator_limit <= 1;
                                    when others => word_rotator_limit <= 1;
                                end case;
                            when 128 =>
                                case BYTESPERWORD is
                                    when 1      => word_rotator_limit <= 16;
                                    when 2      => word_rotator_limit <= 8;
                                    when 4      => word_rotator_limit <= 4;
                                    when 8      => word_rotator_limit <= 2;
                                    when 16     => word_rotator_limit <= 1;
                                    when others => word_rotator_limit <= 1;
                                end case;
                            when others =>
                                word_rotator_limit <= 1;
                        end case;
                    
                        DATA_MANAGER_STATE <= BUFFER_RDATA;

                    when BUFFER_RDATA =>      

                        TARGET_DIN_BUFFER  <= read_fifo(read_fifo_rd_ptr);
                        DATA_MANAGER_STATE <= DISMANTLE_RDATA;

                    when DISMANTLE_RDATA =>

                        v_din_buf := (others => '0');
                        v_din_buf(TARGET_DIN_BUFFER'range) := TARGET_DIN_BUFFER;
                        
                        v_target_word := (others => '0');

                        case C_M_AXI_DATA_WIDTH is
                            when 32 =>
                                case BYTESPERWORD is
                                    when 1 =>
                                        case word_rotator is
                                            when 0 => v_target_word(7 downto 0) := v_din_buf(7 downto 0);
                                            when 1 => v_target_word(7 downto 0) := v_din_buf(15 downto 8);
                                            when 2 => v_target_word(7 downto 0) := v_din_buf(23 downto 16);
                                            when 3 => v_target_word(7 downto 0) := v_din_buf(31 downto 24);
                                            when others => null;
                                        end case;
                                    when 2 =>
                                        case word_rotator is
                                            when 0 => v_target_word(15 downto 0) := v_din_buf(15 downto 0);
                                            when 1 => v_target_word(15 downto 0) := v_din_buf(31 downto 16);
                                            when others => null;
                                        end case;
                                    when 4 =>
                                        v_target_word(31 downto 0) := v_din_buf(31 downto 0);
                                    when others => null;
                                end case;

                            when 64 =>
                                case BYTESPERWORD is
                                    when 1 =>
                                        case word_rotator is
                                            when 0 => v_target_word(7 downto 0) := v_din_buf(7 downto 0);
                                            when 1 => v_target_word(7 downto 0) := v_din_buf(15 downto 8);
                                            when 2 => v_target_word(7 downto 0) := v_din_buf(23 downto 16);
                                            when 3 => v_target_word(7 downto 0) := v_din_buf(31 downto 24);
                                            when 4 => v_target_word(7 downto 0) := v_din_buf(39 downto 32);
                                            when 5 => v_target_word(7 downto 0) := v_din_buf(47 downto 40);
                                            when 6 => v_target_word(7 downto 0) := v_din_buf(55 downto 48);
                                            when 7 => v_target_word(7 downto 0) := v_din_buf(63 downto 56);
                                            when others => null;
                                        end case;
                                    when 2 =>
                                        case word_rotator is
                                            when 0 => v_target_word(15 downto 0) := v_din_buf(15 downto 0);
                                            when 1 => v_target_word(15 downto 0) := v_din_buf(31 downto 16);
                                            when 2 => v_target_word(15 downto 0) := v_din_buf(47 downto 32);
                                            when 3 => v_target_word(15 downto 0) := v_din_buf(63 downto 48);
                                            when others => null;
                                        end case;
                                    when 4 =>
                                        case word_rotator is
                                            when 0 => v_target_word(31 downto 0) := v_din_buf(31 downto 0);
                                            when 1 => v_target_word(31 downto 0) := v_din_buf(63 downto 32);
                                            when others => null;
                                        end case;
                                    when 8 =>
                                        v_target_word(63 downto 0) := v_din_buf(63 downto 0);
                                    when others => null;
                                end case;

                            when 128 =>
                                case BYTESPERWORD is
                                    when 1 =>
                                        case word_rotator is
                                            when 0  => v_target_word(7 downto 0) := v_din_buf(7 downto 0);
                                            when 1  => v_target_word(7 downto 0) := v_din_buf(15 downto 8);
                                            when 2  => v_target_word(7 downto 0) := v_din_buf(23 downto 16);
                                            when 3  => v_target_word(7 downto 0) := v_din_buf(31 downto 24);
                                            when 4  => v_target_word(7 downto 0) := v_din_buf(39 downto 32);
                                            when 5  => v_target_word(7 downto 0) := v_din_buf(47 downto 40);
                                            when 6  => v_target_word(7 downto 0) := v_din_buf(55 downto 48);
                                            when 7  => v_target_word(7 downto 0) := v_din_buf(63 downto 56);
                                            when 8  => v_target_word(7 downto 0) := v_din_buf(71 downto 64);
                                            when 9  => v_target_word(7 downto 0) := v_din_buf(79 downto 72);
                                            when 10 => v_target_word(7 downto 0) := v_din_buf(87 downto 80);
                                            when 11 => v_target_word(7 downto 0) := v_din_buf(95 downto 88);
                                            when 12 => v_target_word(7 downto 0) := v_din_buf(103 downto 96);
                                            when 13 => v_target_word(7 downto 0) := v_din_buf(111 downto 104);
                                            when 14 => v_target_word(7 downto 0) := v_din_buf(119 downto 112);
                                            when 15 => v_target_word(7 downto 0) := v_din_buf(127 downto 120);
                                            when others => null;
                                        end case;
                                    when 2 =>
                                        case word_rotator is
                                            when 0 => v_target_word(15 downto 0) := v_din_buf(15 downto 0);
                                            when 1 => v_target_word(15 downto 0) := v_din_buf(31 downto 16);
                                            when 2 => v_target_word(15 downto 0) := v_din_buf(47 downto 32);
                                            when 3 => v_target_word(15 downto 0) := v_din_buf(63 downto 48);
                                            when 4 => v_target_word(15 downto 0) := v_din_buf(79 downto 64);
                                            when 5 => v_target_word(15 downto 0) := v_din_buf(95 downto 80);
                                            when 6 => v_target_word(15 downto 0) := v_din_buf(111 downto 96);
                                            when 7 => v_target_word(15 downto 0) := v_din_buf(127 downto 112);
                                            when others => null;
                                        end case;
                                    when 4 =>
                                        case word_rotator is
                                            when 0 => v_target_word(31 downto 0) := v_din_buf(31 downto 0);
                                            when 1 => v_target_word(31 downto 0) := v_din_buf(63 downto 32);
                                            when 2 => v_target_word(31 downto 0) := v_din_buf(95 downto 64);
                                            when 3 => v_target_word(31 downto 0) := v_din_buf(127 downto 96);
                                            when others => null;
                                        end case;
                                    when 8 =>
                                        case word_rotator is
                                            when 0 => v_target_word(63 downto 0) := v_din_buf(63 downto 0);
                                            when 1 => v_target_word(63 downto 0) := v_din_buf(127 downto 64);
                                            when others => null;
                                        end case;
                                    when 16 =>
                                        v_target_word(127 downto 0) := v_din_buf(127 downto 0);
                                    when others => null;
                                end case;
                            when others => null;
                        end case;

                        if TARGET_SELECT = '1' then
                            FIFO_DIN  <= v_target_word(FIFO_DIN'range);
                            FIFO_WREN <= '1';
                        else
                            BRAM_DIN  <= v_target_word(BRAM_DIN'range);
                            BRAM_WE   <= '1';
                        end if;

                        DATA_MANAGER_STATE <= NEXT_RDATA;

                        if TARGET_SELECT = '0' and BRAM_ADDR_DELAY = '1' then
                            BRAM_ADDR_INT <= BRAM_ADDR_INT + 1;
                        end if;

                        if BRAM_ADDR_DELAY = '0' then
                            BRAM_ADDR_DELAY <= '1';
                        end if;

                    when NEXT_RDATA =>

                        if MANAGER_TOTALWORDS = 1 then

                            DATA_MANAGER_STATE <= COMPLETED;

                        else

                            MANAGER_TOTALWORDS <= MANAGER_TOTALWORDS - 1;

                            if word_rotator = word_rotator_limit - 1 then

                                word_rotator <= 0;
                                DATA_MANAGER_STATE <= WAIT_READ_FIFO;

                            elsif word_rotator = word_rotator_limit - 2 then

                                DATA_MANAGER_STATE <= DISMANTLE_RDATA;
                                word_rotator <= word_rotator + 1;

                            else     

                                DATA_MANAGER_STATE <= DISMANTLE_RDATA;
                                word_rotator <= word_rotator + 1;

                            end if;       

                        end if;

                    when GET_BURST_WORD_COUNT_0 =>

                        if DMA_STATE = SET_AXI_BURST_LENGTH_3 then

                            DATA_MANAGER_STATE <= GET_BURST_WORD_COUNT_1;

                        end if;

                    when GET_BURST_WORD_COUNT_1 =>

                        
                        case BYTESPERWORD is
                            when 1 =>
                                current_write_burst_words <= current_burst_bytes;
                            when 2 =>
                                current_write_burst_words <= to_integer(shift_right(to_unsigned(current_burst_bytes, 32), 1));
                            when 4 =>
                                current_write_burst_words <= to_integer(shift_right(to_unsigned(current_burst_bytes, 32), 2));
                            when 8 =>
                                current_write_burst_words <= to_integer(shift_right(to_unsigned(current_burst_bytes, 32), 3));
                            when 16 =>
                                current_write_burst_words <= to_integer(shift_right(to_unsigned(current_burst_bytes, 32), 4));
                            when others =>
                                current_write_burst_words <= current_burst_bytes;
                        end case;
                        
                        DATA_MANAGER_STATE <= CALCULATE_REMAINING_WORDS;

                    when CALCULATE_REMAINING_WORDS => 

                        MANAGER_TOTALWORDS <= MANAGER_TOTALWORDS - current_write_burst_words;
                        DATA_MANAGER_STATE <= READ_TARGET;
                                                 
                    when READ_TARGET =>

                        
                        
                        case C_M_AXI_DATA_WIDTH is
                            when 32 =>
                                case BYTESPERWORD is
                                    when 1      => word_rotator_limit <= 4;
                                    when 2      => word_rotator_limit <= 2;
                                    when 4      => word_rotator_limit <= 1;
                                    when others => word_rotator_limit <= 1;
                                end case;
                            when 64 =>
                                case BYTESPERWORD is
                                    when 1      => word_rotator_limit <= 8;
                                    when 2      => word_rotator_limit <= 4;
                                    when 4      => word_rotator_limit <= 2;
                                    when 8      => word_rotator_limit <= 1;
                                    when others => word_rotator_limit <= 1;
                                end case;
                            when 128 =>
                                case BYTESPERWORD is
                                    when 1      => word_rotator_limit <= 16;
                                    when 2      => word_rotator_limit <= 8;
                                    when 4      => word_rotator_limit <= 4;
                                    when 8      => word_rotator_limit <= 2;
                                    when 16     => word_rotator_limit <= 1;
                                    when others => word_rotator_limit <= 1;
                                end case;
                            when others =>
                                word_rotator_limit <= 1;
                        end case;
                        
                        word_rotator       <= 0;
                        BRAM_DELAY_LIM <= to_integer(unsigned(BRAM_READ_DELAY));
                        DATA_MANAGER_STATE <= FETCH_TARGET_WORD;

                    when FETCH_TARGET_WORD =>
                        
                        if TARGET_SELECT = '1' then
                            if FIFO_EMPTY = '0' then
                                if FIFO_TYPE = '0' then
                                    FIFO_RDEN <= '1';
                                    DATA_MANAGER_STATE <= WAIT_TARGET_DATA;
                                else
                                    DATA_MANAGER_STATE <= LATCH_WORD_DATA;
                                end if;
                            end if;
                        else
                            BRAM_DELAY_CNT <= 0;
                            DATA_MANAGER_STATE <= WAIT_TARGET_DATA;
                        end if;

                    when WAIT_TARGET_DATA =>

                        FIFO_RDEN <= '0';
                        
                        if TARGET_SELECT = '1' then
                            DATA_MANAGER_STATE <= LATCH_WORD_DATA;
                        else
                            if BRAM_DELAY_CNT = BRAM_DELAY_LIM - 1 then
                                DATA_MANAGER_STATE <= LATCH_WORD_DATA;
                                BRAM_DELAY_CNT     <= 0;
                            else
                                BRAM_DELAY_CNT <= BRAM_DELAY_CNT + 1;
                            end if;
                        end if;

                    when LATCH_WORD_DATA =>
                    
                        v_source_word := (others => '0');
                        if TARGET_SELECT = '1' then
                            v_source_word(FIFO_DOUT'range) := FIFO_DOUT;
                        else
                            v_source_word(BRAM_DOUT'range) := BRAM_DOUT;
                        end if;

                        v_wdata_buf := (others => '0');
                        v_wdata_buf(AXI_WDATA_BUFFER'range) := AXI_WDATA_BUFFER;

                        case C_M_AXI_DATA_WIDTH is
                            when 32 =>
                                case BYTESPERWORD is
                                    when 1 =>
                                        case word_rotator is
                                            when 0 => v_wdata_buf(7 downto 0)   := v_source_word(7 downto 0);
                                            when 1 => v_wdata_buf(15 downto 8)  := v_source_word(7 downto 0);
                                            when 2 => v_wdata_buf(23 downto 16) := v_source_word(7 downto 0);
                                            when 3 => v_wdata_buf(31 downto 24) := v_source_word(7 downto 0);
                                            when others => null;
                                        end case;
                                    when 2 =>
                                        case word_rotator is
                                            when 0 => v_wdata_buf(15 downto 0)  := v_source_word(15 downto 0);
                                            when 1 => v_wdata_buf(31 downto 16) := v_source_word(15 downto 0);
                                            when others => null;
                                        end case;
                                    when 4 =>
                                        v_wdata_buf(31 downto 0) := v_source_word(31 downto 0);
                                    when others => null;
                                end case;

                            when 64 =>
                                case BYTESPERWORD is
                                    when 1 =>
                                        case word_rotator is
                                            when 0 => v_wdata_buf(7 downto 0)   := v_source_word(7 downto 0);
                                            when 1 => v_wdata_buf(15 downto 8)  := v_source_word(7 downto 0);
                                            when 2 => v_wdata_buf(23 downto 16) := v_source_word(7 downto 0);
                                            when 3 => v_wdata_buf(31 downto 24) := v_source_word(7 downto 0);
                                            when 4 => v_wdata_buf(39 downto 32) := v_source_word(7 downto 0);
                                            when 5 => v_wdata_buf(47 downto 40) := v_source_word(7 downto 0);
                                            when 6 => v_wdata_buf(55 downto 48) := v_source_word(7 downto 0);
                                            when 7 => v_wdata_buf(63 downto 56) := v_source_word(7 downto 0);
                                            when others => null;
                                        end case;
                                    when 2 =>
                                        case word_rotator is
                                            when 0 => v_wdata_buf(15 downto 0)  := v_source_word(15 downto 0);
                                            when 1 => v_wdata_buf(31 downto 16) := v_source_word(15 downto 0);
                                            when 2 => v_wdata_buf(47 downto 32) := v_source_word(15 downto 0);
                                            when 3 => v_wdata_buf(63 downto 48) := v_source_word(15 downto 0);
                                            when others => null;
                                        end case;
                                    when 4 =>
                                        case word_rotator is
                                            when 0 => v_wdata_buf(31 downto 0)  := v_source_word(31 downto 0);
                                            when 1 => v_wdata_buf(63 downto 32) := v_source_word(31 downto 0);
                                            when others => null;
                                        end case;
                                    when 8 =>
                                        v_wdata_buf(63 downto 0) := v_source_word(63 downto 0);
                                    when others => null;
                                end case;

                            when 128 =>
                                case BYTESPERWORD is
                                    when 1 =>
                                        case word_rotator is
                                            when 0  => v_wdata_buf(7 downto 0)     := v_source_word(7 downto 0);
                                            when 1  => v_wdata_buf(15 downto 8)    := v_source_word(7 downto 0);
                                            when 2  => v_wdata_buf(23 downto 16)   := v_source_word(7 downto 0);
                                            when 3  => v_wdata_buf(31 downto 24)   := v_source_word(7 downto 0);
                                            when 4  => v_wdata_buf(39 downto 32)   := v_source_word(7 downto 0);
                                            when 5  => v_wdata_buf(47 downto 40)   := v_source_word(7 downto 0);
                                            when 6  => v_wdata_buf(55 downto 48)   := v_source_word(7 downto 0);
                                            when 7  => v_wdata_buf(63 downto 56)   := v_source_word(7 downto 0);
                                            when 8  => v_wdata_buf(71 downto 64)   := v_source_word(7 downto 0);
                                            when 9  => v_wdata_buf(79 downto 72)   := v_source_word(7 downto 0);
                                            when 10 => v_wdata_buf(87 downto 80)   := v_source_word(7 downto 0);
                                            when 11 => v_wdata_buf(95 downto 88)   := v_source_word(7 downto 0);
                                            when 12 => v_wdata_buf(103 downto 96)  := v_source_word(7 downto 0);
                                            when 13 => v_wdata_buf(111 downto 104) := v_source_word(7 downto 0);
                                            when 14 => v_wdata_buf(119 downto 112) := v_source_word(7 downto 0);
                                            when 15 => v_wdata_buf(127 downto 120) := v_source_word(7 downto 0);
                                            when others => null;
                                        end case;
                                    when 2 =>
                                        case word_rotator is
                                            when 0 => v_wdata_buf(15 downto 0)   := v_source_word(15 downto 0);
                                            when 1 => v_wdata_buf(31 downto 16)  := v_source_word(15 downto 0);
                                            when 2 => v_wdata_buf(47 downto 32)  := v_source_word(15 downto 0);
                                            when 3 => v_wdata_buf(63 downto 48)  := v_source_word(15 downto 0);
                                            when 4 => v_wdata_buf(79 downto 64)  := v_source_word(15 downto 0);
                                            when 5 => v_wdata_buf(95 downto 80)  := v_source_word(15 downto 0);
                                            when 6 => v_wdata_buf(111 downto 96) := v_source_word(15 downto 0);
                                            when 7 => v_wdata_buf(127 downto 112):= v_source_word(15 downto 0);
                                            when others => null;
                                        end case;
                                    when 4 =>
                                        case word_rotator is
                                            when 0 => v_wdata_buf(31 downto 0)   := v_source_word(31 downto 0);
                                            when 1 => v_wdata_buf(63 downto 32)  := v_source_word(31 downto 0);
                                            when 2 => v_wdata_buf(95 downto 64)  := v_source_word(31 downto 0);
                                            when 3 => v_wdata_buf(127 downto 96) := v_source_word(31 downto 0);
                                            when others => null;
                                        end case;
                                    when 8 =>
                                        case word_rotator is
                                            when 0 => v_wdata_buf(63 downto 0)   := v_source_word(63 downto 0);
                                            when 1 => v_wdata_buf(127 downto 64) := v_source_word(63 downto 0);
                                            when others => null;
                                        end case;
                                    when 16 =>
                                        v_wdata_buf(127 downto 0) := v_source_word(127 downto 0);
                                    when others => null;
                                end case;
                            when others => null;
                        end case;

                        AXI_WDATA_BUFFER <= v_wdata_buf(AXI_WDATA_BUFFER'range);

                        if TARGET_SELECT = '1' then
                            if FIFO_TYPE = '1' then
                                FIFO_RDEN <= '1';
                            end if;
                        else
                            BRAM_ADDR_INT <= BRAM_ADDR_INT + 1;
                        end if;

                        if current_write_burst_words > 0 then
                            current_write_burst_words <= current_write_burst_words - 1;
                        end if;

                        if word_rotator = word_rotator_limit - 1 then
                            word_rotator       <= 0;
                            DATA_MANAGER_STATE <= CLEAR_RDEN_AND_SEND;
                        else
                            word_rotator       <= word_rotator + 1;
                            DATA_MANAGER_STATE <= FETCH_TARGET_WORD; 
                        end if;

                        if current_write_burst_words = 1 then
                            SEND_LAST_BEAT <= '1';
                        end if;

                    when CLEAR_RDEN_AND_SEND =>

                        FIFO_RDEN          <= '0'; 
                        AXI_WDATA_READY    <= '1';
                        DATA_MANAGER_STATE <= WAIT_AXI_HANDSHAKE;

                    when WAIT_AXI_HANDSHAKE =>

                        if AXI_WVALID = '1' and M_AXI_WREADY = '1' then
                            AXI_WDATA_READY    <= '0';
                            DATA_MANAGER_STATE <= CHECK_REMAINING_WORDS;
                        end if;

                    when CHECK_REMAINING_WORDS =>

                        SEND_LAST_BEAT <= '0';

                        if current_write_burst_words > 0 then
                            DATA_MANAGER_STATE <= READ_TARGET;
                        else
                            DATA_MANAGER_STATE <= CHECK_REMAINING_BURSTS;
                        end if;

                    when CHECK_REMAINING_BURSTS =>

                        if MANAGER_TOTALWORDS > 0 then
                            DATA_MANAGER_STATE <= GET_BURST_WORD_COUNT_0;
                        else
                            DATA_MANAGER_STATE <= COMPLETED;
                        end if;

                    when COMPLETED =>

                        OPERATION_DONE  <= '1';

                        if START_READ = '0' and START_WRITE = '0' then
                            DATA_MANAGER_STATE <= IDLE;
                        else
                            DATA_MANAGER_STATE <= COMPLETED;
                        end if;

                    when others =>

                        DATA_MANAGER_STATE <= IDLE;

                end case;

            end if;

        end if;                         

    end process DATA_MANAGER;

    BRAM_ADDR  <= std_logic_vector(to_unsigned(BRAM_ADDR_INT,BRAM_ADDR'length));

end je_pardonne;
