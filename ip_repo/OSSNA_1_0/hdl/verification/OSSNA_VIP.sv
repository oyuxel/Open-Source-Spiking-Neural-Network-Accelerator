`timescale 1ns / 1ps

module OSSNA_VIP();

    import axi_vip_pkg::*;
    import OSSNA_TEST_TOP_axi_vip_0_0_pkg::*; 
    import OSSNA_TEST_TOP_axi_vip_1_0_pkg::*; 
    import ossna_reg_pkg::*; 

    OSSNA_TEST_TOP_axi_vip_0_0_mst_t     axil_controls;
    OSSNA_TEST_TOP_axi_vip_1_0_slv_mem_t axim_data;

    logic axil_controls_aclk    = 1'b0;
    logic axim_data_aclk        = 1'b0;
    logic axil_controls_aresetn = 1'b0;
    logic axim_data_aresetn     = 1'b0;

    event vip_ready;

    `ifndef CTRL_IF_PATH
      `define CTRL_IF_PATH  OSSNA_VIP.DUT.OSSNA_TEST_TOP_i.controls_vip.inst.IF
    `endif
    `ifndef DATA_IF_PATH
      `define DATA_IF_PATH  OSSNA_VIP.DUT.OSSNA_TEST_TOP_i.data_vip.inst.IF
    `endif

    always #5 axil_controls_aclk  = ~axil_controls_aclk;
    always #5 axim_data_aclk      = ~axim_data_aclk;

    `include "ossna_axil_tasks.sv"

    initial begin
        $display("[%0t] Open-Source Spiking Neural Network Accelerator Verification IP", $time);
        $display("[%0t] INFO: monitoring resets...", $time);
        $monitor("[%0t] axil_controls_aresetn=%0b axim_data_aresetn=%0b", $time, axil_controls_aresetn, axim_data_aresetn);
    end

    initial begin
        axil_controls_aresetn = 1'b0;
        axim_data_aresetn     = 1'b0;
        repeat (20) @(posedge axil_controls_aclk);
        @(posedge axil_controls_aclk);
        axil_controls_aresetn = 1'b1;
        axim_data_aresetn     = 1'b1;
    end

    initial begin
        axil_controls = new("axil_controls", `CTRL_IF_PATH);
        axim_data     = new("axim_data", `DATA_IF_PATH);

        axil_controls.start_master();
        axim_data.start_slave();

        $display("[%0t] VIP: Configuring memory model response delays...", $time);
        
        axim_data.mem_model.set_bresp_delay_range(10, 50);
        axim_data.mem_model.set_inter_beat_gap_delay_policy(XIL_AXI_MEMORY_DELAY_RANDOM);
        axim_data.mem_model.set_default_memory_value(8'h00);
        
        $display("[%0t] VIP: Write response backpressure enabled successfully.", $time);

        -> vip_ready;
    end

    initial begin
        bit [31:0] rand_val32;
        bit [15:0] rand_val16;
        bit [15:0] s8_golden_data [1331];
        bit [15:0] s8_read_data;
        int        s8_mismatches;
        int        s8_matches;

        @vip_ready;
        @(posedge axil_controls_aresetn);
        repeat (10) @(posedge axil_controls_aclk);

        $display("[%0t] [TEST_FLOW] Starting tests...", $time);

        GetHardwareInfo();

        SetNMCXNeverBoundaries(10'd512, 10'd1023);

        ResetProcessor(31);

        D2SReset(3);

        D2S("poisson", 32'd200, 32'hA5A5_1234, 32'd1000);

        ExternalMemoryAccess(.synaptic("enabled"), .nmc("enabled"));

        $display("\n[%0t] [SCENARIO_1] Preloading 997 32-bit random words to ZYNQ DDR for Slave 0 FIFO...", $time);
        for (int i = 0; i < 997; i++) begin
            rand_val32 = $urandom();
            backdoor_mem_write_32(32'h1000_0000 + (i * 4), rand_val32);
        end

        $display("[%0t] [SCENARIO_1] Initiating DMARead (ZYNQ DDR -> PL Slave 0 FIFO)...", $time);
        DMARead(32'h1000_0000, 32'h0000_0000, 32'd3988, 32'd997, 32'd4, 32'd1, 32'd0, 1'b1, 1'b0);

        $display("\n[%0t] [SCENARIO_2] Preloading 1331 16-bit random words to ZYNQ DDR for Slave 8 BRAM...", $time);
        for (int i = 0; i < 1331; i++) begin
            rand_val16 = $urandom();
            s8_golden_data[i] = rand_val16;
            backdoor_mem_write_16(32'h2000_0000 + (i * 2), rand_val16);
        end

        $display("[%0t] [SCENARIO_2] Initiating DMARead (ZYNQ DDR -> PL Slave 8 BRAM)...", $time);
        DMARead(32'h2000_0000, 32'h0000_0000, 32'd2662, 32'd1331, 32'd2, 32'd1, 32'd8, 1'b0, 1'b0);

        $display("[%0t] [SCENARIO_2] Initiating DMAWrite (PL Slave 8 BRAM -> ZYNQ DDR)...", $time);
        DMAWrite(32'h3000_0000, 32'h0000_0000, 32'd2662, 32'd1331, 32'd2, 32'd1, 32'd8, 1'b0, 1'b0);

        $display("[%0t] [SCOREBOARD] Verifying Slave 8 BRAM data written back to DDR...", $time);
        s8_mismatches = 0;
        s8_matches    = 0;

        for (int i = 0; i < 1331; i++) begin
            backdoor_mem_read_16(32'h3000_0000 + (i * 2), s8_read_data);

            if (s8_read_data !== s8_golden_data[i]) begin
                s8_mismatches++;
                $error("[%0t] [SCOREBOARD_FAIL] Index %0d Mismatch! Expected: 0x%04h, Received: 0x%04h", 
                       $time, i, s8_golden_data[i], s8_read_data);
            end else begin
                s8_matches++;
            end
        end

        if (s8_mismatches == 0) begin
            $display("[%0t] [SCOREBOARD_SUCCESS] All %0d words in Slave 8 BRAM matched perfectly!", $time, s8_matches);
        end else begin
            $error("[%0t] [SCOREBOARD_SUMMARY] Total Matches: %0d, Total Mismatches: %0d!", $time, s8_matches, s8_mismatches);
        end

        #100;
        $display("[%0t] [TEST_FLOW] All tests finished successfully.", $time);
        $finish;
    end

    OSSNA_TEST_TOP_wrapper DUT
   (.axil_controls_aclk(axil_controls_aclk),
    .axil_controls_aresetn(axil_controls_aresetn),
    .axim_data_aclk(axim_data_aclk),
    .axim_data_aresetn(axim_data_aresetn));

endmodule