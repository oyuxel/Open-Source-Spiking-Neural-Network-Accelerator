library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
Library UNISIM;
use UNISIM.vcomponents.all;

entity ULEARN_DATAFLOW is
Port(
    CLK, RST               : in  std_logic;
    CFG_WORD               : in  std_logic_vector(255 downto 0);
    START_LEARNING         : in  std_logic;                         
    NMODEL_SPIKE_TIME      : in  std_logic_vector(7 downto 0);  
    SYN_DATA_IN            : in  std_logic_vector(15 downto 0); 
    SYN_DIN_VLD            : in  std_logic;                     
    SYN_DATA_OUT           : out std_logic_vector(15 downto 0);
    SYN_DOUT_VLD           : out std_logic;                     
    LUT_MEM_ADDR           : out std_logic_vector(15 downto 0);
    LUT_MEM_DOUT           : in  std_logic_vector(7 downto 0)   
);
end ULEARN_DATAFLOW;

architecture resonance of ULEARN_DATAFLOW is

type t_delay_array is array (0 to 11) of signed(15 downto 0);
    signal w_pipe, t_pipe, lut_data_pipe : t_delay_array := (others => (others => '0'));
    signal vld_pipe, flag1_pipe, flag2_pipe : std_logic_vector(11 downto 0) := (others => '0');
    signal w_in : signed(7 downto 0);
    signal trace_pre_in, trace_post_in : unsigned(7 downto 0);

    pure function get_mux_val(sel: std_logic_vector(2 downto 0); w, t, lut, c1, c2, c3, c4: signed(15 downto 0)) return signed is
    begin
        case sel is
            when "000" => return to_signed(0, 16); when "001" => return w;
            when "010" => return t; when "011" => return lut;
            when "100" => return c1; when "101" => return c2;
            when "110" => return c3; when "111" => return c4;
            when others => return to_signed(0, 16);
        end case;
    end function;

    signal cfg_c1, cfg_c2, cfg_c3, cfg_c4, lut_op1, lut_op2, lut_offset : signed(15 downto 0);
    signal cfg_lut_center : unsigned(15 downto 0);        
    signal cfg_lut_op1_sel, cfg_lut_op2_sel, cfg_f1_src, cfg_f2_src : std_logic_vector(1 downto 0); 
    signal cfg_lut_is_sub, flag1_comb, flag2_comb : std_logic;                    
    signal cfg_f1_cond, cfg_f2_cond : std_logic_vector(2 downto 0);

    signal cfg_d1_d_sel, cfg_d1_a_sel, cfg_d1_b_sel, cfg_d1_c_sel : std_logic_vector(2 downto 0);
    signal cfg_d2_d_sel, cfg_d2_a_sel, cfg_d2_b_sel, cfg_d2_c_sel : std_logic_vector(2 downto 0);
    signal cfg_d3_d_sel, cfg_d3_a_sel, cfg_d3_b_sel, cfg_d3_c_sel : std_logic_vector(2 downto 0);
    signal cfg_d4_c_sel : std_logic_vector(2 downto 0);

    signal cfg_d1_opmode_t, cfg_d1_opmode_f, cfg_d2_opmode_t, cfg_d2_opmode_f, cfg_d3_opmode_t, cfg_d3_opmode_f, cfg_d4_opmode_t, cfg_d4_opmode_f : std_logic_vector(6 downto 0);
    signal cfg_d1_alumode_t, cfg_d1_alumode_f, cfg_d2_alumode_t, cfg_d2_alumode_f, cfg_d3_alumode_t, cfg_d3_alumode_f, cfg_d4_alumode_t, cfg_d4_alumode_f : std_logic_vector(3 downto 0);
    signal cfg_d1_inmode_t, cfg_d1_inmode_f, cfg_d2_inmode_t, cfg_d2_inmode_f, cfg_d3_inmode_t, cfg_d3_inmode_f : std_logic_vector(4 downto 0);

    signal dsp1_pcout, dsp2_pcout, dsp3_pcout, dsp4_p_out : std_logic_vector(47 downto 0);
    signal dsp1_d_in, dsp2_d_in, dsp3_d_in : std_logic_vector(24 downto 0);
    signal dsp1_a_in, dsp2_a_in, dsp3_a_in : std_logic_vector(29 downto 0);
    signal dsp1_b_in, dsp2_b_in, dsp3_b_in : std_logic_vector(17 downto 0);
    signal dsp1_c_in, dsp2_c_in, dsp3_c_in, dsp4_c_in : std_logic_vector(47 downto 0);
    signal dsp1_opmode_dyn, dsp2_opmode_dyn, dsp3_opmode_dyn, dsp4_opmode_dyn : std_logic_vector(6 downto 0);
    signal dsp1_alumode_dyn, dsp2_alumode_dyn, dsp3_alumode_dyn, dsp4_alumode_dyn : std_logic_vector(3 downto 0);
    signal dsp1_inmode_dyn, dsp2_inmode_dyn, dsp3_inmode_dyn : std_logic_vector(4 downto 0);

begin

    cfg_c1 <= signed(CFG_WORD(255 downto 240)); 
    cfg_c2 <= signed(CFG_WORD(239 downto 224));
    cfg_c3 <= signed(CFG_WORD(223 downto 208)); 
    cfg_c4 <= signed(CFG_WORD(207 downto 192));
    cfg_lut_center <= unsigned(CFG_WORD(191 downto 176)); 
    cfg_lut_op1_sel <= CFG_WORD(175 downto 174);
    cfg_lut_op2_sel <= CFG_WORD(173 downto 172); 
    cfg_lut_is_sub <= CFG_WORD(171);
    cfg_f1_src <= CFG_WORD(170 downto 169); 
    cfg_f1_cond <= CFG_WORD(168 downto 166);
    cfg_f2_src <= CFG_WORD(165 downto 164); 
    cfg_f2_cond <= CFG_WORD(163 downto 161);

    cfg_d1_d_sel <= CFG_WORD(160 downto 158);
    cfg_d1_a_sel <= CFG_WORD(157 downto 155); 
    cfg_d1_b_sel <= CFG_WORD(154 downto 152); 
    cfg_d1_c_sel <= CFG_WORD(151 downto 149);
    cfg_d1_opmode_t <= CFG_WORD(148 downto 142); 
    cfg_d1_opmode_f <= CFG_WORD(141 downto 135); 
    cfg_d1_alumode_t <= CFG_WORD(134 downto 131); 
    cfg_d1_alumode_f <= CFG_WORD(130 downto 127);
    cfg_d1_inmode_t <= CFG_WORD(126 downto 122); 
    cfg_d1_inmode_f <= CFG_WORD(121 downto 117);

    cfg_d2_d_sel <= CFG_WORD(116 downto 114); 
    cfg_d2_a_sel <= CFG_WORD(113 downto 111); 
    cfg_d2_b_sel <= CFG_WORD(110 downto 108); 
    cfg_d2_c_sel <= CFG_WORD(107 downto 105);
    cfg_d2_opmode_t <= CFG_WORD(104 downto 98); 
    cfg_d2_opmode_f <= CFG_WORD(97 downto 91); 
    cfg_d2_alumode_t <= CFG_WORD(90 downto 87); 
    cfg_d2_alumode_f <= CFG_WORD(86 downto 83);
    cfg_d2_inmode_t <= CFG_WORD(82 downto 78); 
    cfg_d2_inmode_f <= CFG_WORD(77 downto 73);

    cfg_d3_d_sel <= CFG_WORD(72 downto 70); 
    cfg_d3_a_sel <= CFG_WORD(69 downto 67); 
    cfg_d3_b_sel <= CFG_WORD(66 downto 64); 
    cfg_d3_c_sel <= CFG_WORD(63 downto 61);
    cfg_d3_opmode_t <= CFG_WORD(60 downto 54); 
    cfg_d3_opmode_f <= CFG_WORD(53 downto 47); 
    cfg_d3_alumode_t <= CFG_WORD(46 downto 43); 
    cfg_d3_alumode_f <= CFG_WORD(42 downto 39);
    cfg_d3_inmode_t <= CFG_WORD(38 downto 34); 
    cfg_d3_inmode_f <= CFG_WORD(33 downto 29);

    cfg_d4_c_sel <= CFG_WORD(28 downto 26); 
    cfg_d4_opmode_t <= CFG_WORD(25 downto 19); 
    cfg_d4_opmode_f <= CFG_WORD(18 downto 12); 
    cfg_d4_alumode_t <= CFG_WORD(11 downto 8); 
    cfg_d4_alumode_f <= CFG_WORD(7 downto 4);

    w_in <= signed(SYN_DATA_IN(15 downto 8)); 
    trace_pre_in <= unsigned(SYN_DATA_IN(7 downto 0)); 
    trace_post_in <= unsigned(NMODEL_SPIKE_TIME);

    PROCESS(w_in, trace_pre_in, trace_post_in, cfg_lut_op1_sel, cfg_lut_op2_sel)
    BEGIN
        CASE cfg_lut_op1_sel IS
            WHEN "01" => 
                lut_op1 <= resize(w_in, 16); 
            WHEN "10" => 
                lut_op1 <= signed(resize(trace_pre_in, 16)); 
            WHEN "11" => 
                lut_op1 <= signed(resize(trace_post_in, 16)); 
            WHEN OTHERS => 
                lut_op1 <= (others => '0');
        END CASE;
        CASE cfg_lut_op2_sel IS
            WHEN "01" => 
                lut_op2 <= resize(w_in, 16); 
            WHEN "10" => 
                lut_op2 <= signed(resize(trace_pre_in, 16)); 
            WHEN "11" => 
                lut_op2 <= signed(resize(trace_post_in, 16)); 
            WHEN OTHERS => 
                lut_op2 <= (others => '0');
        END CASE;
    END PROCESS;

    lut_offset <= (lut_op1 - lut_op2) when cfg_lut_is_sub = '1' else (lut_op1 + lut_op2);
    LUT_MEM_ADDR <= std_logic_vector(cfg_lut_center + unsigned(lut_offset));

    PROCESS(w_in, trace_pre_in, trace_post_in, cfg_f1_src, cfg_f1_cond, cfg_f2_src, cfg_f2_cond)
        variable src1_val, src2_val : signed(15 downto 0);
    BEGIN
        CASE cfg_f1_src IS
            WHEN "00" => 
                src1_val := signed(resize(trace_pre_in, 16)); 
            WHEN "01" => 
                src1_val := resize(w_in, 16); 
            WHEN "10" => 
                src1_val := signed(resize(trace_post_in, 16)); 
            WHEN OTHERS => 
                src1_val := (others => '0');
        END CASE;
        CASE cfg_f1_cond IS
            WHEN "000" => 
                if src1_val = 0 then 
                    flag1_comb <= '1'; 
                else 
                    flag1_comb <= '0'; 
                end if;   
            WHEN "001" => 
                if src1_val < 255 then 
                    flag1_comb <= '1'; 
                else 
                    flag1_comb <= '0'; 
                end if; 
            WHEN "010" => 
                if src1_val > 0 then 
                    flag1_comb <= '1'; 
                else 
                    flag1_comb <= '0'; 
                end if;   
            WHEN OTHERS => 
                flag1_comb <= '0';
        END CASE;
        
        CASE cfg_f2_src IS
            WHEN "00" => 
                src2_val := signed(resize(trace_pre_in, 16)); 
            WHEN "01" => 
                src2_val := resize(w_in, 16); 
            WHEN "10" => 
                src2_val := signed(resize(trace_post_in, 16)); 
            WHEN OTHERS => 
                src2_val := (others => '0');
        END CASE;
        CASE cfg_f2_cond IS
            WHEN "000" => 
                if src2_val = 0 then 
                    flag2_comb <= '1'; 
                else 
                    flag2_comb <= '0'; 
                end if;
            WHEN "001" => 
                if src2_val < 255 then 
                    flag2_comb <= '1'; 
                else 
                    flag2_comb <= '0'; 
                end if;
            WHEN "010" => 
                if src2_val > 0 then 
                    flag2_comb <= '1'; 
                else 
                    flag2_comb <= '0'; 
                end if;
            WHEN OTHERS => 
                flag2_comb <= '0';
        END CASE;
    END PROCESS;

    PROCESS(CLK)
    BEGIN
        IF rising_edge(CLK) THEN
            IF RST = '1' or START_LEARNING = '0' THEN
                vld_pipe <= (others => '0');
                lut_data_pipe <= (others => (others => '0'));
            ELSE
                vld_pipe(0) <= SYN_DIN_VLD;
                IF SYN_DIN_VLD = '1' THEN
                    w_pipe(0) <= resize(w_in, 16); 
                    t_pipe(0) <= signed(resize(trace_pre_in, 16));
                    flag1_pipe(0) <= flag1_comb; 
                    flag2_pipe(0) <= flag2_comb;
                END IF;

                lut_data_pipe(1) <= signed(resize(signed(LUT_MEM_DOUT), 16));
--
                for i in 0 to 9 loop
                    vld_pipe(i+1) <= vld_pipe(i); 
                    w_pipe(i+1) <= w_pipe(i); 
                    t_pipe(i+1) <= t_pipe(i);
                    flag1_pipe(i+1) <= flag1_pipe(i); 
                    flag2_pipe(i+1) <= flag2_pipe(i);
                    if i >= 1 then
                        lut_data_pipe(i+1) <= lut_data_pipe(i);
                    end if;
                end loop;
            END IF;
        END IF;
    END PROCESS;

    dsp1_d_in <= std_logic_vector(resize(get_mux_val(cfg_d1_d_sel, w_pipe(3), t_pipe(3), lut_data_pipe(3), cfg_c1, cfg_c2, cfg_c3, cfg_c4), 25));
    dsp1_a_in <= std_logic_vector(resize(get_mux_val(cfg_d1_a_sel, w_pipe(3), t_pipe(3), lut_data_pipe(3), cfg_c1, cfg_c2, cfg_c3, cfg_c4), 30));
    dsp1_b_in <= std_logic_vector(resize(get_mux_val(cfg_d1_b_sel, w_pipe(3), t_pipe(3), lut_data_pipe(3), cfg_c1, cfg_c2, cfg_c3, cfg_c4), 18));
    dsp1_c_in <= std_logic_vector(resize(get_mux_val(cfg_d1_c_sel, w_pipe(5), t_pipe(5), lut_data_pipe(5), cfg_c1, cfg_c2, cfg_c3, cfg_c4), 48));

    dsp1_inmode_dyn  <= cfg_d1_inmode_t  when flag1_pipe(3) = '1' else cfg_d1_inmode_f;
    dsp1_opmode_dyn  <= cfg_d1_opmode_t  when flag1_pipe(5) = '1' else cfg_d1_opmode_f;
    dsp1_alumode_dyn <= cfg_d1_alumode_t when flag1_pipe(5) = '1' else cfg_d1_alumode_f;

    DSP_1 : DSP48E1 
        generic map (USE_MULT => "DYNAMIC", 
                    USE_SIMD => "ONE48", 
                    USE_DPORT => TRUE,
                    AREG => 1, 
                    BREG => 2, 
                    CREG => 1, 
                    DREG => 1, 
                    ADREG => 1, 
                    MREG => 1, 
                    PREG => 1, 
                    A_INPUT => "DIRECT", 
                    B_INPUT => "DIRECT")
        port map (CLK => CLK, 
                OPMODE => dsp1_opmode_dyn, 
                ALUMODE => dsp1_alumode_dyn, 
                INMODE => dsp1_inmode_dyn, 
                D => dsp1_d_in, 
                A => dsp1_a_in, 
                B => dsp1_b_in, 
                C => dsp1_c_in, 
                PCOUT => dsp1_pcout, P => open, 
                CEA1 => '0', 
                CEA2 => '1', 
                CEB1 => '1', 
                CEB2 => '1', 
                CEC => '1', 
                CED => '1',
                CEAD => '1', 
                CEM => '1', 
                CEP => '1', 
                CEALUMODE => '1', 
                CECTRL => '1', 
                CEINMODE => '1', 
                CECARRYIN => '0', 
                RSTA => RST, 
                RSTB => RST, 
                RSTC => RST, 
                RSTD => RST, 
                RSTM => RST, 
                RSTP => RST, 
                RSTALUMODE => RST, 
                RSTCTRL => RST, 
                RSTINMODE => RST, 
                RSTALLCARRYIN => RST, 
                CARRYIN => '0', 
                CARRYCASCIN => '0', 
                MULTSIGNIN => '0', 
                ACIN => (others => '0'), 
                BCIN => (others => '0'), 
                PCIN => (others => '0'), 
                CARRYINSEL => "000", 
                ACOUT => open, 
                BCOUT => open, 
                CARRYCASCOUT => open, 
                MULTSIGNOUT => open, 
                OVERFLOW => open, 
                PATTERNBDETECT => open, 
                PATTERNDETECT => open, 
                UNDERFLOW => open, 
                CARRYOUT => open);

    dsp2_d_in <= std_logic_vector(resize(get_mux_val(cfg_d2_d_sel, w_pipe(4), t_pipe(4), lut_data_pipe(4), cfg_c1, cfg_c2, cfg_c3, cfg_c4), 25));
    dsp2_a_in <= std_logic_vector(resize(get_mux_val(cfg_d2_a_sel, w_pipe(4), t_pipe(4), lut_data_pipe(4), cfg_c1, cfg_c2, cfg_c3, cfg_c4), 30));
    dsp2_b_in <= std_logic_vector(resize(get_mux_val(cfg_d2_b_sel, w_pipe(4), t_pipe(4), lut_data_pipe(4), cfg_c1, cfg_c2, cfg_c3, cfg_c4), 18));
    dsp2_c_in <= std_logic_vector(resize(get_mux_val(cfg_d2_c_sel, w_pipe(6), t_pipe(6), lut_data_pipe(6), cfg_c1, cfg_c2, cfg_c3, cfg_c4), 48));

    dsp2_inmode_dyn  <= cfg_d2_inmode_t  when flag1_pipe(4) = '1' else cfg_d2_inmode_f;
    dsp2_opmode_dyn  <= cfg_d2_opmode_t  when flag1_pipe(6) = '1' else cfg_d2_opmode_f;
    dsp2_alumode_dyn <= cfg_d2_alumode_t when flag1_pipe(6) = '1' else cfg_d2_alumode_f;

    DSP_2 : DSP48E1 
        generic map (USE_MULT => "DYNAMIC", 
                    USE_SIMD => "ONE48", 
                    USE_DPORT => TRUE,
                    AREG => 1, 
                    BREG => 2, 
                    CREG => 1, 
                    DREG => 1, 
                    ADREG => 1, 
                    MREG => 1, 
                    PREG => 1, 
                    A_INPUT => "DIRECT", 
                    B_INPUT => "DIRECT")
        port map (CLK => CLK, 
                OPMODE => dsp2_opmode_dyn, 
                ALUMODE => dsp2_alumode_dyn, 
                INMODE => dsp2_inmode_dyn, 
                D => dsp2_d_in, 
                A => dsp2_a_in, 
                B => dsp2_b_in, 
                C => dsp2_c_in, 
                PCIN => dsp1_pcout, 
                PCOUT => dsp2_pcout, 
                P => open,
                CEA1 => '0', 
                CEA2 => '1', 
                CEB1 => '1', 
                CEB2 => '1', 
                CEC => '1', 
                CED => '1', 
                CEAD => '1', 
                CEM => '1', 
                CEP => '1', 
                CEALUMODE => '1', 
                CECTRL => '1', 
                CEINMODE => '1', 
                CECARRYIN => '0', 
                RSTA => RST, 
                RSTB => RST, 
                RSTC => RST, 
                RSTD => RST, 
                RSTM => RST, 
                RSTP => RST, 
                RSTALUMODE => RST, 
                RSTCTRL => RST, 
                RSTINMODE => RST, 
                RSTALLCARRYIN => RST, 
                CARRYIN => '0', 
                CARRYCASCIN => '0', 
                MULTSIGNIN => '0', 
                ACIN => (others => '0'), 
                BCIN => (others => '0'), 
                CARRYINSEL => "000", 
                ACOUT => open, 
                BCOUT => open, 
                CARRYCASCOUT => open, 
                MULTSIGNOUT => open, 
                OVERFLOW => open, 
                PATTERNBDETECT => open, 
                PATTERNDETECT => open, 
                UNDERFLOW => open, 
                CARRYOUT => open);

    dsp3_d_in <= std_logic_vector(resize(get_mux_val(cfg_d3_d_sel, w_pipe(5), t_pipe(5), lut_data_pipe(5), cfg_c1, cfg_c2, cfg_c3, cfg_c4), 25));
    dsp3_a_in <= std_logic_vector(resize(get_mux_val(cfg_d3_a_sel, w_pipe(5), t_pipe(5), lut_data_pipe(5), cfg_c1, cfg_c2, cfg_c3, cfg_c4), 30));
    dsp3_b_in <= std_logic_vector(resize(get_mux_val(cfg_d3_b_sel, w_pipe(5), t_pipe(5), lut_data_pipe(5), cfg_c1, cfg_c2, cfg_c3, cfg_c4), 18));
    dsp3_c_in <= std_logic_vector(resize(get_mux_val(cfg_d3_c_sel, w_pipe(7), t_pipe(7), lut_data_pipe(7), cfg_c1, cfg_c2, cfg_c3, cfg_c4), 48));

    dsp3_inmode_dyn  <= cfg_d3_inmode_t  when flag1_pipe(5) = '1' else cfg_d3_inmode_f;
    dsp3_opmode_dyn  <= cfg_d3_opmode_t  when flag1_pipe(7) = '1' else cfg_d3_opmode_f;
    dsp3_alumode_dyn <= cfg_d3_alumode_t when flag1_pipe(7) = '1' else cfg_d3_alumode_f;

    DSP_3 : DSP48E1 
        generic map (USE_MULT => "DYNAMIC", 
                    USE_SIMD => "ONE48", 
                    USE_DPORT => TRUE,
                    AREG => 1, 
                    BREG => 2, 
                    CREG => 1, 
                    DREG => 1, 
                    ADREG => 1, 
                    MREG => 1, 
                    PREG => 1, 
                    A_INPUT => "DIRECT", 
                    B_INPUT => "DIRECT")
        port map (CLK => CLK, 
                OPMODE => dsp3_opmode_dyn, 
                ALUMODE => dsp3_alumode_dyn, 
                INMODE => dsp3_inmode_dyn, 
                D => dsp3_d_in, 
                A => dsp3_a_in, 
                B => dsp3_b_in, 
                C => dsp3_c_in, 
                PCIN => dsp2_pcout, 
                PCOUT => dsp3_pcout, 
                P => open,
                CEA1 => '0', 
                CEA2 => '1', 
                CEB1 => '1', 
                CEB2 => '1', 
                CEC => '1', 
                CED => '1', 
                CEAD => '1', 
                CEM => '1', 
                CEP => '1', 
                CEALUMODE => '1', 
                CECTRL => '1', 
                CEINMODE => '1', 
                CECARRYIN => '0', 
                RSTA => RST, 
                RSTB => RST, 
                RSTC => RST, 
                RSTD => RST, 
                RSTM => RST, 
                RSTP => RST, 
                RSTALUMODE => RST, 
                RSTCTRL => RST, 
                RSTINMODE => RST, 
                RSTALLCARRYIN => RST, 
                CARRYIN => '0', 
                CARRYCASCIN => '0', 
                MULTSIGNIN => '0', 
                ACIN => (others => '0'), 
                BCIN => (others => '0'), 
                CARRYINSEL => "000", 
                ACOUT => open, 
                BCOUT => open, 
                CARRYCASCOUT => open, 
                MULTSIGNOUT => open, 
                OVERFLOW => open, 
                PATTERNBDETECT => open, 
                PATTERNDETECT => open, 
                UNDERFLOW => open, 
                CARRYOUT => open);

    PROCESS(cfg_d4_c_sel, w_pipe(9), t_pipe(9), lut_data_pipe(9), cfg_c1, cfg_c2, cfg_c3, cfg_c4)
        variable c_mux_out : signed(15 downto 0);
    BEGIN
        c_mux_out := get_mux_val(cfg_d4_c_sel, w_pipe(9), t_pipe(9), lut_data_pipe(9), cfg_c1, cfg_c2, cfg_c3, cfg_c4);
        dsp4_c_in(47 downto 24) <= std_logic_vector(resize(c_mux_out, 24)); 
        dsp4_c_in(23 downto  0) <= std_logic_vector(resize(t_pipe(9), 24)); 
    END PROCESS;

    dsp4_opmode_dyn  <= cfg_d4_opmode_t  when flag2_pipe(9) = '1' else cfg_d4_opmode_f;
    dsp4_alumode_dyn <= cfg_d4_alumode_t when flag2_pipe(9) = '1' else cfg_d4_alumode_f;

    DSP_4 : DSP48E1 
        generic map (USE_MULT => "NONE", USE_SIMD => "TWO24", AREG => 0, BREG => 0, CREG => 1, DREG => 0, MREG => 0, PREG => 1, ACASCREG => 0, BCASCREG => 0, A_INPUT => "DIRECT", B_INPUT => "DIRECT")
        port map (CLK => CLK, 
                OPMODE => dsp4_opmode_dyn, 
                ALUMODE => dsp4_alumode_dyn, 
                INMODE => (others => '0'), 
                D => (others => '0'), 
                A => (others => '0'), 
                B => (others => '0'), 
                C => dsp4_c_in,
                PCIN => dsp3_pcout, 
                P => dsp4_p_out, 
                PCOUT => open,
                CEA1 => '0', 
                CEA2 => '0', 
                CEB1 => '0', 
                CEB2 => '0', 
                CEC => '1', 
                CED => '0', 
                CEAD => '0', 
                CEM => '0', 
                CEP => '1', 
                CEALUMODE => '1', 
                CECTRL => '1', 
                CEINMODE => '0', 
                CECARRYIN => '0', 
                RSTA => RST, 
                RSTB => RST, 
                RSTC => RST, 
                RSTD => RST, 
                RSTM => RST, 
                RSTP => RST, 
                RSTALUMODE => RST, 
                RSTCTRL => RST, 
                RSTINMODE => RST, 
                RSTALLCARRYIN => RST, 
                CARRYIN => '0', 
                CARRYCASCIN => '0', 
                MULTSIGNIN => '0', 
                ACIN => (others => '0'), 
                BCIN => (others => '0'), 
                CARRYINSEL => "000", 
                ACOUT => open, 
                BCOUT => open, 
                CARRYCASCOUT => open, 
                MULTSIGNOUT => open, 
                OVERFLOW => open, 
                PATTERNBDETECT => open, 
                PATTERNDETECT => open, 
                UNDERFLOW => open, 
                CARRYOUT => open);

    PROCESS(CLK)
        variable w_candidate, t_candidate : signed(15 downto 0);
    BEGIN
        IF rising_edge(CLK) THEN
            IF RST = '1' or START_LEARNING = '0' THEN
                SYN_DOUT_VLD <= '0'; SYN_DATA_OUT <= (others => '0');
            ELSE
                SYN_DOUT_VLD <= vld_pipe(10);
                
                IF vld_pipe(10) = '1' THEN
                    w_candidate := signed(dsp4_p_out(15 downto 0)); 
                    
                    if flag2_pipe(10) = '1' then t_candidate := t_pipe(10) + 1;
                    else t_candidate := t_pipe(10); end if;

                    if w_candidate > cfg_c3 then w_candidate := cfg_c3;
                    elsif w_candidate < cfg_c4 then w_candidate := cfg_c4; end if;
                    if t_candidate > 255 then t_candidate := to_signed(255, 16); 
                    elsif t_candidate < 0 then t_candidate := (others => '0'); end if;

                    SYN_DATA_OUT(15 downto 8) <= std_logic_vector(w_candidate(7 downto 0));
                    SYN_DATA_OUT(7 downto 0)  <= std_logic_vector(t_candidate(7 downto 0));
                END IF;
            END IF;
        END IF;
    END PROCESS;

end resonance;