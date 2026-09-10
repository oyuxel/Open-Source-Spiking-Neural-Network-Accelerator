task automatic axil_read(
    input  bit [31:0] addr,
    output bit [31:0] data
);
    axi_vip_pkg::xil_axi_resp_t resp;

    axil_controls.AXI4LITE_READ_BURST(
        addr,
        3'b000,
        data,
        resp
    );

    if (resp !== axi_vip_pkg::XIL_AXI_RESP_OKAY) begin
        $error("[%0t] [AXI_ERROR] Read error at address 0x%08h! Response: %s", 
               $time, addr, resp.name());
    end
endtask

task automatic axil_write(
    input bit [31:0] addr,
    input bit [31:0] data
);
    axi_vip_pkg::xil_axi_resp_t resp;

    axil_controls.AXI4LITE_WRITE_BURST(
        addr,
        3'b000,
        data,
        resp
    );

    if (resp !== axi_vip_pkg::XIL_AXI_RESP_OKAY) begin
        $error("[%0t] [AXI_ERROR] Write error at address 0x%08h! Response: %s", 
               $time, addr, resp.name());
    end
endtask

task automatic backdoor_mem_write_32(
    input bit [31:0] addr,
    input bit [31:0] data
);
    axim_data.mem_model.backdoor_memory_write(addr, data, 4'b1111);
endtask

task automatic backdoor_mem_write_16(
    input bit [31:0] addr,
    input bit [15:0] data
);
    bit [31:0] aligned_addr;
    bit [31:0] word_data;
    bit [3:0]  wstrb;

    aligned_addr = addr & ~32'd3;

    if (addr[1] == 1'b0) begin
        word_data = {16'h0000, data};
        wstrb     = 4'b0011;
    end else begin
        word_data = {data, 16'h0000};
        wstrb     = 4'b1100;
    end

    axim_data.mem_model.backdoor_memory_write(aligned_addr, word_data, wstrb);
endtask

task automatic backdoor_mem_read_16(
    input  bit [31:0] addr,
    output bit [15:0] data
);
    bit [31:0] aligned_addr;
    bit [31:0] full_word;

    aligned_addr = addr & ~32'd3;
    full_word    = axim_data.mem_model.backdoor_memory_read(aligned_addr);

    if (addr[1] == 1'b0) begin
        data = full_word[15:0];
    end else begin
        data = full_word[31:16];
    end
endtask

task automatic GetHardwareInfo();
    bit [31:0] reg0_param_mem;
    bit [31:0] reg1_syn_mem;
    bit [31:0] reg2_crossbar;
    bit [31:0] reg3_max_neurons;
    bit [31:0] reg4_lut_depth;
    bit [31:0] reg5_buf_depth;

    $display("\n[%0t] [INFO] Reading Hardware Configuration Registers...", $time);

    axil_read(ossna_reg_pkg::ADDR_TOTAL_PARAM_MEM,     reg0_param_mem);
    axil_read(ossna_reg_pkg::ADDR_TOTAL_SYN_MEM,       reg1_syn_mem);
    axil_read(ossna_reg_pkg::ADDR_CROSSBAR_DIMS,       reg2_crossbar);
    axil_read(ossna_reg_pkg::ADDR_MAX_NEURONS,         reg3_max_neurons);
    axil_read(ossna_reg_pkg::ADDR_LEARN_LUT_DEPTH,     reg4_lut_depth);
    axil_read(ossna_reg_pkg::ADDR_SPIKE_GEN_BUF_DEPTH, reg5_buf_depth);

    $display("");
    $display("Open-Source Spiking Neural Network Processor");
    $display("");
    $display("Total %0d bits of maximum neural memory.", reg0_param_mem);
    $display("Total %0d bits of maximum synaptic memory.", reg1_syn_mem);
    $display("Inference crossbar dimensions %0dx%0d.", reg2_crossbar, reg2_crossbar);
    $display("Maximum %0d number of neurons.", reg3_max_neurons);
    $display("Maximum %0d STDP engine LUT depth.", reg4_lut_depth);
    $display("Maximum %0d Data-2-Spike Converter buffer depth.", reg5_buf_depth);
    $display("");
endtask

task automatic SetNMCXNeverBoundaries(
    input bit [9:0] base_addr,
    input bit [9:0] high_addr
);
    bit [31:0] base_32;
    bit [31:0] high_32;
    bit [31:0] reg_val;

    if (high_addr < base_addr) begin
        $warning("[%0t] [CONFIG_WARN] NMC XNEVER High boundary (0x%03h) is smaller than Base boundary (0x%03h)!", 
                 $time, high_addr, base_addr);
    end

    base_32 = base_addr;
    high_32 = high_addr;

    reg_val = ((high_32 << ossna_reg_pkg::NMC_XNEVER_HIGH_SHIFT) & ossna_reg_pkg::NMC_XNEVER_HIGH_MASK) |
              ((base_32 << ossna_reg_pkg::NMC_XNEVER_BASE_SHIFT) & ossna_reg_pkg::NMC_XNEVER_BASE_MASK);

    axil_write(ossna_reg_pkg::ADDR_NMC_XNEVER, reg_val);

    $display("[%0t] [CONFIG] SetNMCXNeverBoundaries applied: BASE=0x%03h (%0d), HIGH=0x%03h (%0d)", 
             $time, base_addr, base_addr, high_addr, high_addr);
endtask

task automatic ResetProcessor(
    input int unsigned hold_cycles = 10
);
    bit [31:0] reset_val;

    reset_val = ossna_reg_pkg::SP_RESET_MASK         |
                ossna_reg_pkg::FLUSH_MAIN_BUF_MASK   |
                ossna_reg_pkg::FLUSH_AUX_BUF_MASK    |
                ossna_reg_pkg::FLUSH_CIRC_BUF_MASK   |
                ossna_reg_pkg::FLUSH_OUT_BUF_MASK;

    $display("[%0t] [RESET] Asserting Processor Soft Reset and Flushing all buffers...", $time);
    axil_write(ossna_reg_pkg::ADDR_CORE_RESET_FLUSH, reset_val);

    repeat (hold_cycles) @(posedge axil_controls_aclk);

    $display("[%0t] [RESET] Deasserting Processor Soft Reset and buffer flushes...", $time);
    axil_write(ossna_reg_pkg::ADDR_CORE_RESET_FLUSH, 32'h0000_0000);

    repeat (5) @(posedge axil_controls_aclk);
    $display("[%0t] [RESET] Processor reset sequence completed successfully.", $time);
endtask

task automatic DMASoftReset(
    input int unsigned hold_cycles = 5
);
    $display("[%0t] [DMA_RESET] Asserting DMA Soft Reset...", $time);
    axil_write(ossna_reg_pkg::ADDR_DMA_CTRL, ossna_reg_pkg::DMA_RESET_SOFT_MASK);
    repeat (hold_cycles) @(posedge axil_controls_aclk);
    axil_write(ossna_reg_pkg::ADDR_DMA_CTRL, 32'h0000_0000);
    repeat (5) @(posedge axil_controls_aclk);
    $display("[%0t] [DMA_RESET] DMA Soft Reset deasserted successfully.", $time);
endtask

task automatic DMARead(
    input bit [31:0] ddr_addr,
    input bit [31:0] bram_addr,
    input bit [31:0] total_bytes,
    input bit [31:0] total_words,
    input bit [31:0] byte_per_word = 32'd4,
    input bit [31:0] bram_delay    = 32'd1,
    input bit [31:0] slave_sel     = 32'd0,
    input bit        target_select = 1'b0,
    input bit        fifo_type     = 1'b0,
    input bit        do_soft_reset = 1'b1,
    input time       timeout_limit = 100ms
);
    bit [31:0] fifo_val;
    bit [31:0] target_val;
    bit [31:0] ctrl_base;
    bit [31:0] status_val;
    bit        done_flag;
    bit        err_flag;
    bit        timed_out;
    realtime   start_time;

    if (do_soft_reset) begin
        DMASoftReset(5);
    end

    fifo_val   = fifo_type;
    target_val = target_select;

    $display("[%0t] [DMA_READ] IP Master reading from ZYNQ DDR (0x%08h) -> PL Slave %0d (0x%08h), Bytes=%0d, Words=%0d, Target=%s, FIFO_Type=%s", 
             $time, ddr_addr, slave_sel, bram_addr, total_bytes, total_words, 
             target_select ? "FIFO" : "BRAM", fifo_type ? "FWFT" : "STANDARD");

    axil_write(ossna_reg_pkg::ADDR_SELECT_SLAVE,    slave_sel);
    axil_write(ossna_reg_pkg::ADDR_BYTE_PER_WORD,   byte_per_word);
    axil_write(ossna_reg_pkg::ADDR_TOTAL_BYTES,     total_bytes);
    axil_write(ossna_reg_pkg::ADDR_TOTAL_WORDS,     total_words);
    axil_write(ossna_reg_pkg::ADDR_BRAM_READ_DELAY, bram_delay);
    axil_write(ossna_reg_pkg::ADDR_BRAM_BASEADDR,   bram_addr);
    axil_write(ossna_reg_pkg::ADDR_DDR_BASEADDR,    ddr_addr);

    ctrl_base = (fifo_val   << ossna_reg_pkg::DMA_FIFO_TYPE_SHIFT) |
                (target_val << ossna_reg_pkg::DMA_TARGET_SELECT_SHIFT);

    $display("[%0t] [DMA_READ] Asserting and holding DMA_START_READ bit HIGH...", $time);
    axil_write(ossna_reg_pkg::ADDR_DMA_CTRL, ctrl_base | ossna_reg_pkg::DMA_START_READ_MASK);

    done_flag  = 1'b0;
    err_flag   = 1'b0;
    timed_out  = 1'b0;
    start_time = $realtime;

    while (!done_flag && !err_flag && !timed_out) begin
        axil_read(ossna_reg_pkg::ADDR_DMA_STATUS, status_val);

        done_flag = ((status_val & ossna_reg_pkg::DMA_STAT_READ_DONE_MASK) != 0);
        err_flag  = ((status_val & ossna_reg_pkg::DMA_STAT_READ_ERR_MASK) != 0);

        if (($realtime - start_time) >= timeout_limit) begin
            timed_out = 1'b1;
        end

        if (!done_flag && !err_flag && !timed_out) begin
            repeat (10) @(posedge axil_controls_aclk);
        end
    end

    $display("[%0t] [DMA_READ] Operation finished or terminated. Deasserting DMA_START_READ bit...", $time);
    axil_write(ossna_reg_pkg::ADDR_DMA_CTRL, ctrl_base);
    repeat (5) @(posedge axil_controls_aclk);

    if (err_flag) begin
        $error("[%0t] [DMA_READ_ERROR] Read failed! Status: 0x%08h (TARGET_READ_ERROR asserted)", 
               $time, status_val);
    end else if (timed_out) begin
        $error("[%0t] [DMA_TIMEOUT] Read timed out after %0t! Status: 0x%08h", 
               $time, timeout_limit, status_val);
    end else if (done_flag) begin
        $display("[%0t] [DMA_READ] Completed successfully. Status: 0x%08h", $time, status_val);
    end
endtask

task automatic DMAWrite(
    input bit [31:0] ddr_addr,
    input bit [31:0] bram_addr,
    input bit [31:0] total_bytes,
    input bit [31:0] total_words,
    input bit [31:0] byte_per_word = 32'd4,
    input bit [31:0] bram_delay    = 32'd1,
    input bit [31:0] slave_sel     = 32'd0,
    input bit        target_select = 1'b0,
    input bit        fifo_type     = 1'b0,
    input bit        do_soft_reset = 1'b1,
    input time       timeout_limit = 100ms
);
    bit [31:0] fifo_val;
    bit [31:0] target_val;
    bit [31:0] ctrl_base;
    bit [31:0] status_val;
    bit        done_flag;
    bit        err_flag;
    bit        timed_out;
    realtime   start_time;

    if (do_soft_reset) begin
        DMASoftReset(5);
    end

    fifo_val   = fifo_type;
    target_val = target_select;

    $display("[%0t] [DMA_WRITE] IP Master reading from PL Slave %0d (0x%08h) -> Writing to ZYNQ DDR (0x%08h), Bytes=%0d, Words=%0d, Target=%s, FIFO_Type=%s", 
             $time, slave_sel, bram_addr, ddr_addr, total_bytes, total_words, 
             target_select ? "FIFO" : "BRAM", fifo_type ? "FWFT" : "STANDARD");

    axil_write(ossna_reg_pkg::ADDR_SELECT_SLAVE,    slave_sel);
    axil_write(ossna_reg_pkg::ADDR_BYTE_PER_WORD,   byte_per_word);
    axil_write(ossna_reg_pkg::ADDR_TOTAL_BYTES,     total_bytes);
    axil_write(ossna_reg_pkg::ADDR_TOTAL_WORDS,     total_words);
    axil_write(ossna_reg_pkg::ADDR_BRAM_READ_DELAY, bram_delay);
    axil_write(ossna_reg_pkg::ADDR_BRAM_BASEADDR,   bram_addr);
    axil_write(ossna_reg_pkg::ADDR_DDR_BASEADDR,    ddr_addr);

    ctrl_base = (fifo_val   << ossna_reg_pkg::DMA_FIFO_TYPE_SHIFT) |
                (target_val << ossna_reg_pkg::DMA_TARGET_SELECT_SHIFT);

    $display("[%0t] [DMA_WRITE] Asserting and holding DMA_START_WRITE bit HIGH...", $time);
    axil_write(ossna_reg_pkg::ADDR_DMA_CTRL, ctrl_base | ossna_reg_pkg::DMA_START_WRITE_MASK);

    done_flag  = 1'b0;
    err_flag   = 1'b0;
    timed_out  = 1'b0;
    start_time = $realtime;

    while (!done_flag && !err_flag && !timed_out) begin
        axil_read(ossna_reg_pkg::ADDR_DMA_STATUS, status_val);

        done_flag = ((status_val & ossna_reg_pkg::DMA_STAT_WRITE_DONE_MASK) != 0);
        err_flag  = ((status_val & ossna_reg_pkg::DMA_STAT_WRITE_ERR_MASK) != 0);

        if (($realtime - start_time) >= timeout_limit) begin
            timed_out = 1'b1;
        end

        if (!done_flag && !err_flag && !timed_out) begin
            repeat (10) @(posedge axil_controls_aclk);
        end
    end

    $display("[%0t] [DMA_WRITE] Operation finished or terminated. Deasserting DMA_START_WRITE bit...", $time);
    axil_write(ossna_reg_pkg::ADDR_DMA_CTRL, ctrl_base);
    repeat (5) @(posedge axil_controls_aclk);

    if (err_flag) begin
        $error("[%0t] [DMA_WRITE_ERROR] Write failed! Status: 0x%08h (TARGET_WRITE_ERROR)", 
                   $time, status_val);
    end else if (timed_out) begin
        $error("[%0t] [DMA_TIMEOUT] Write timed out after %0t! Status: 0x%08h", 
                   $time, timeout_limit, status_val);
    end else if (done_flag) begin
        $display("[%0t] [DMA_WRITE] Completed successfully. Status: 0x%08h", $time, status_val);
    end
endtask

task automatic D2SReset(
    input int unsigned hold_cycles = 5
);
    bit [31:0] cur_val;

    $display("[%0t] [D2S_RESET] Reading current D2S control register...", $time);
    axil_read(ossna_reg_pkg::ADDR_D2S_CTRL, cur_val);

    $display("[%0t] [D2S_RESET] Asserting D2S_RESET bit (holding for %0d cycles)...", $time, hold_cycles);
    axil_write(ossna_reg_pkg::ADDR_D2S_CTRL, cur_val | ossna_reg_pkg::D2S_RESET_MASK);

    repeat (hold_cycles) @(posedge axil_controls_aclk);

    $display("[%0t] [D2S_RESET] Deasserting D2S_RESET bit...", $time);
    axil_write(ossna_reg_pkg::ADDR_D2S_CTRL, cur_val & ~ossna_reg_pkg::D2S_RESET_MASK);

    repeat (5) @(posedge axil_controls_aclk);
    $display("[%0t] [D2S_RESET] D2S Reset sequence completed successfully.", $time);
endtask

task automatic D2S(
    input string     conversion_mode,
    input bit [31:0] time_window,
    input bit [31:0] seed,
    input bit [31:0] data_count
);
    bit [1:0]  mode_bits;
    bit [31:0] mode_32;
    bit [31:0] reg15_val;
    bit        valid_mode;

    valid_mode = 1'b1;

    if (conversion_mode.tolower() == "poisson") begin
        mode_bits = 2'b00;
    end else if (conversion_mode.tolower() == "latency") begin
        mode_bits = 2'b01;
    end else begin
        valid_mode = 1'b0;
        $error("[%0t] [D2S_ERROR] Invalid conversion_mode '%s'! Allowed values are 'poisson' or 'latency'.", 
               $time, conversion_mode);
    end

    if (valid_mode) begin
        mode_32   = mode_bits;
        reg15_val = (mode_32 << ossna_reg_pkg::CONVMODE_SHIFT) & ossna_reg_pkg::CONVMODE_MASK;

        axil_write(ossna_reg_pkg::ADDR_D2S_CTRL,   reg15_val);
        axil_write(ossna_reg_pkg::ADDR_TIME_WIND,  time_window);
        axil_write(ossna_reg_pkg::ADDR_SEED,       seed);
        axil_write(ossna_reg_pkg::ADDR_DATA_COUNT, data_count);

        $display("[%0t] [D2S_CONFIG] D2S programmed: Mode=%s (0b%02b), TimeWindow=%0d, Seed=0x%08h, DataCount=%0d", 
                 $time, conversion_mode.toupper(), mode_bits, time_window, seed, data_count);
    end
endtask

task automatic ExternalMemoryAccess(
    input string synaptic = "disabled",
    input string nmc      = "disabled"
);
    bit        syn_bit;
    bit        nmc_bit;
    bit [31:0] syn_32;
    bit [31:0] nmc_32;
    bit [31:0] reg21_val;
    bit        valid_args;

    valid_args = 1'b1;

    if (synaptic.tolower() == "enabled") begin
        syn_bit = 1'b1;
    end else if (synaptic.tolower() == "disabled") begin
        syn_bit = 1'b0;
    end else begin
        valid_args = 1'b0;
        $error("[%0t] [EXT_MEM_ERROR] Invalid synaptic argument '%s'! Allowed: 'enabled' or 'disabled'.", 
               $time, synaptic);
    end

    if (nmc.tolower() == "enabled") begin
        nmc_bit = 1'b1;
    end else if (nmc.tolower() == "disabled") begin
        nmc_bit = 1'b0;
    end else begin
        valid_args = 1'b0;
        $error("[%0t] [EXT_MEM_ERROR] Invalid nmc argument '%s'! Allowed: 'enabled' or 'disabled'.", 
               $time, nmc);
    end

    if (valid_args) begin
        syn_32    = syn_bit;
        nmc_32    = nmc_bit;

        reg21_val = (syn_32 << ossna_reg_pkg::SYNAPSE_ROUTE_SHIFT) |
                    (nmc_32 << ossna_reg_pkg::NMC_PMODE_SWITCH_SHIFT);

        axil_write(ossna_reg_pkg::ADDR_CORE_ROUTING_CFG, reg21_val);

        $display("[%0t] [EXT_MEM_CFG] External memory access updated: SYNAPTIC=%s (bit0=%0b), NMC=%s (bit1=%0b) -> Reg Val: 0x%08h", 
                 $time, synaptic.toupper(), syn_bit, nmc.toupper(), nmc_bit, reg21_val);
    end
endtask