# ossna/network_compiler.py

import os
import math
import numpy as np
from typing import Dict, List, Optional
from .registers import Regs, CoreCfgMask, CoreResetMask
from .nmc_compiler import NMCCompiler, HalfPrecision2Bin
from .nmc_assembler import NModelAssembler
from .synapse import SynapseCompiler
from .network import Network, Layer

# =============================================================================
# BRIDGE MICROCODE OPCODES & CONTROL FLAGS
# =============================================================================
OP_SSSDSYNQ        = 0x1
OP_SYNLOW          = 0x2
OP_SYNHIGH         = 0x3
OP_PFLOWRFPLST     = 0x4
OP_NPADDRDATA      = 0x5
OP_ULEARNPARAMS    = 0x6
OP_TABLELOW        = 0x7
OP_ULEARNLOWSYN    = 0x8
OP_ULEARNHIGHSYN   = 0x9
OP_ENDFLOW         = 0xA

# ENDFLOW Control Flags [4:0]
ENDFLOW_NEXT_NEURON            = 1 << 0  # Bit 0: Next neuron in column
ENDFLOW_BARRIER_SYNC           = 1 << 1  # Bit 1: Remainder / Dummy barrier wait
ENDFLOW_START_LEARNING         = 1 << 2  # Bit 2: Inference done -> Start STDP
ENDFLOW_SKIP_LEARNING_TIMESTEP = 1 << 3  # Bit 3: Inference done -> Skip STDP -> Next timestep
ENDFLOW_TIMESTEP_UPDATE        = 1 << 4  # Bit 4: Global timestep complete


# =============================================================================
# COMPILED ARTIFACT CLASS (DEPLOYMENT & SIMULATION ARTIFACT)
# =============================================================================
class CompiledNetwork:
    """
    Holds the complete compilation artifacts ready for:
    1) Direct 64-bit DMA flashing to PYNQ PL BRAMs
    2) Direct SystemVerilog $readmemh simulation file export
    """
    def __init__(self, hw_info: dict):
        self.hw_info = hw_info
        self.register_config: Dict[int, int] = {}
        self.slave_payloads: Dict[int, np.ndarray] = {}
        
        # Shortcuts
        self.nmc_microcode: Optional[np.ndarray] = None   # Slave 4
        self.stdp_lut: Optional[np.ndarray] = None        # Slave 5
        self.synapse_payloads: Dict[int, np.ndarray] = {} # Slaves 6..21
        self.neural_payloads: Dict[int, np.ndarray] = {}  # Slaves 22..37

    def save(self, filepath: str):
        """Saves all compilation artifacts as a compressed binary bundle."""
        bundle = {
            "reg_addrs": np.array(list(self.register_config.keys()), dtype=np.uint32),
            "reg_vals":  np.array(list(self.register_config.values()), dtype=np.uint32),
            **{f"slave_{k}": v for k, v in self.slave_payloads.items()}
        }
        np.savez_compressed(filepath, **bundle)
        print(f"[COMPILER ARTIFACT] Saved binary deployment bundle to '{filepath}'.")

    def export_simulation_files(self, output_dir: str):
        """
        Exports clean .mem ASCII HEX files for ModelSim / Vivado Simulator ($readmemh).
        """
        os.makedirs(output_dir, exist_ok=True)
        print(f"\n[EXPORT] Exporting SystemVerilog $readmemh simulation files to: {output_dir}")

        # 1. NMC Program Memory (Slave 4: 16-bit HEX)
        if 4 in self.slave_payloads:
            with open(os.path.join(output_dir, "slave_4_nmc_program.mem"), "w") as f:
                for val in self.slave_payloads[4]:
                    f.write(f"{val:04X}\n")

        # 2. STDP Learning LUT (Slave 5: 8-bit HEX)
        if 5 in self.slave_payloads:
            with open(os.path.join(output_dir, "slave_5_learning_lut.mem"), "w") as f:
                for val in self.slave_payloads[5]:
                    f.write(f"{val:02X}\n")

        # 3. Synapse BRAMs (Slaves 6..21: 16-bit HEX)
        for c in range(self.hw_info["crossbar_col"]):
            s_id = 6 + c
            if s_id in self.slave_payloads:
                with open(os.path.join(output_dir, f"slave_{s_id}_synapse_c{c}.mem"), "w") as f:
                    for val in self.slave_payloads[s_id]:
                        f.write(f"{val:04X}\n")

        # 4. Neural / Bridge BRAMs (Slaves 22..37: 32-bit HEX)
        neural_base = 6 + self.hw_info["crossbar_col"]
        for c in range(self.hw_info["crossbar_col"]):
            s_id = neural_base + c
            if s_id in self.slave_payloads:
                with open(os.path.join(output_dir, f"slave_{s_id}_neural_bridge_c{c}.mem"), "w") as f:
                    for val in self.slave_payloads[s_id]:
                        f.write(f"{val:08X}\n")

        print("[EXPORT COMPLETE] All SystemVerilog simulation files generated successfully.")


# =============================================================================
# NETWORK COMPILER ENGINE
# =============================================================================
class NetworkCompiler:
    """
    Translates a Network specification into Bridge microcodes, memory layouts,
    and AXI-Lite register configurations based on live hardware capabilities.
    """
    def __init__(self, network: Network, hw_info: dict):
        self.network = network
        self.hw_info = hw_info
        
        self.num_cols = hw_info["crossbar_col"]
        self.num_rows = hw_info["crossbar_row"]
        self.syn_depth_per_col = hw_info["total_synapse_mem_words"] // self.num_cols
        self.param_depth_per_col = hw_info["total_param_mem_words"] // self.num_cols
        self.lut_depth = hw_info["learning_engine_lut_depth"]

        # Dynamic Address Masks
        self.syn_addr_width = (self.syn_depth_per_col - 1).bit_length()
        self.syn_addr_mask = (1 << self.syn_addr_width) - 1
        
        self.lut_addr_width = (self.lut_depth - 1).bit_length()
        self.lut_addr_mask = (1 << self.lut_addr_width) - 1

    def compile(self) -> CompiledNetwork:
        print("\n" + "="*80)
        print("  OSSNA NETWORK COMPILER: HARDWARE-AWARE TARGETING")
        print("="*80)

        # 0. Early Hardware Validation
        self.network.validate_hardware(self.hw_info)
        artifact = CompiledNetwork(self.hw_info)

        # ---------------------------------------------------------------------
        # STAGE 1: DEDUP & COMPILE UNIQUE NEURON MODELS (SLAVE 4 - NMC PROGRAM)
        # ---------------------------------------------------------------------
        print("\n[STAGE 1] Compiling Unique Neuron Models for Slave 4 (NMC Program)...")
        model_pflow_start: Dict[id, int] = {}
        model_footprints: Dict[id, dict] = {}
        slave4_instructions: List[int] = []
        
        current_scratchpad_offset = 16  # Inputs occupy M(0..7), constants/params start at M(16)

        for layer in self.network.layers:
            m = layer.neuron_model
            m_id = id(m)
            if m_id not in model_pflow_start:
                # Compile NMC Assembly using base offset to prevent footprint collision
                nmc_comp = NMCCompiler(m, base_offset=current_scratchpad_offset)
                asm_code = nmc_comp.compile()
                bytecode = NModelAssembler(asm_code)
                
                # Record program start in Slave 4
                model_pflow_start[m_id] = len(slave4_instructions)
                slave4_instructions.extend(bytecode)
                
                # Record footprint memory map
                model_footprints[m_id] = {
                    "memory_map": nmc_comp.memory_map,
                    "param_names": nmc_comp.param_names,
                    "param_values": nmc_comp.param_values,
                    "base_offset": current_scratchpad_offset
                }
                
                print(f"  * Model '{m_id}' compiled: Start Address = {model_pflow_start[m_id]}, Scratchpad Base = M({current_scratchpad_offset})")
                current_scratchpad_offset += 16 # Advance scratchpad offset for next model

        artifact.slave_payloads[4] = np.array(slave4_instructions, dtype=np.uint16)
        artifact.nmc_microcode = artifact.slave_payloads[4]

        # ---------------------------------------------------------------------
        # STAGE 2: DEDUP & COMPILE UNIQUE STDP SYNAPSE MODELS (SLAVE 5 - LUT)
        # ---------------------------------------------------------------------
        print("\n[STAGE 2] Compiling STDP Plasticity Curves for Slave 5 (Learning LUT)...")
        synapse_table_starts: Dict[id, int] = {}
        slave5_data: List[int] = []

        for layer in self.network.layers:
            if layer.learning and layer.synapse_model is not None:
                s_model = layer.synapse_model
                s_id = id(s_model)
                if s_id not in synapse_table_starts:
                    syn_comp = SynapseCompiler(s_model)
                    lut_array = syn_comp.compile()
                    
                    synapse_table_starts[s_id] = len(slave5_data)
                    slave5_data.extend(lut_array)
                    print(f"  * STDP Model compiled: Slave 5 Offset = {synapse_table_starts[s_id]}")

        if len(slave5_data) > 0:
            artifact.slave_payloads[5] = np.array(slave5_data, dtype=np.uint8)
            artifact.stdp_lut = artifact.slave_payloads[5]

        # ---------------------------------------------------------------------
        # STAGE 3: TILING & BRIDGE MICROCODE GENERATION (SLAVES 6..37)
        # ---------------------------------------------------------------------
        print("\n[STAGE 3] Generating Column Tiling & Bridge Microcodes...")
        synapse_brams: List[List[int]] = [[] for _ in range(self.num_cols)]
        neural_brams:  List[List[int]] = [[] for _ in range(self.num_cols)]
        syn_addr_ptrs = [0] * self.num_cols

        for layer_idx, layer in enumerate(self.network.layers):
            is_first_layer = (layer_idx == 0)
            is_last_layer  = (layer_idx == len(self.network.layers) - 1)
            has_learning   = layer.learning and (layer.synapse_model is not None)
            
            num_passes = math.ceil(layer.size / self.num_cols)
            footprint = model_footprints[id(layer.neuron_model)]
            pflow_start = model_pflow_start[id(layer.neuron_model)]

            # Quantization Factor (Half-Precision FP16)
            q_factor_float = (layer.w_max - layer.w_min) / 255.0
            synq_fp16 = HalfPrecision2Bin(q_factor_float)

            for p_idx in range(num_passes):
                is_last_pass_of_layer = (p_idx == num_passes - 1)

                # --- Spike Routing Flags (SSSDSYNQ) ---
                if is_first_layer:
                    src_main = 1 if p_idx == 0 else 0
                    src_circ = 1 if p_idx > 0 else 0
                    src_aux  = 0
                else:
                    src_main = 0
                    src_aux  = 1 if p_idx == 0 else 0
                    src_circ = 1 if p_idx > 0 else 0

                dst_out = 1 if is_last_layer else 0
                dst_aux = 1 if (not is_last_layer or layer.lateral_inhibition) else 0

                sssd_flags = (src_main << 20) | (src_circ << 19) | (src_aux << 18) | (dst_aux << 17) | (dst_out << 16)
                cmd_sssd = (OP_SSSDSYNQ << 28) | sssd_flags | (synq_fp16 & 0xFFFF)

                for col in range(self.num_cols):
                    neuron_in_layer = p_idx * self.num_cols + col

                    # =========================================================
                    # A) REAL ACTIVE NEURON
                    # =========================================================
                    if neuron_in_layer < layer.size:
                        
                        # -----------------------------------------------------
                        # Format: [15:8] = Weight (INT8), [7:0] = Trace (0x7F = 127)
                        # -----------------------------------------------------
                        w_raw = layer.weights[:, neuron_in_layer].astype(np.uint16)
                        
                        w_packed = ((w_raw & 0xFF) << 8) | 0x7F
                        
                        syn_low = syn_addr_ptrs[col]
                        syn_high = syn_low + len(w_packed) - 1
                        
                        synapse_brams[col].extend(w_packed.tolist())
                        syn_addr_ptrs[col] = syn_high + 1

                        # -----------------------------------------------------
                        # 2. Bridge Microcode Stream
                        # -----------------------------------------------------
                        # 0x1: SSSDSYNQ
                        neural_brams[col].append(cmd_sssd)
                        # 0x2: SYNLOW
                        neural_brams[col].append((OP_SYNLOW << 28) | (syn_low & self.syn_addr_mask))
                        # 0x3: SYNHIGH
                        neural_brams[col].append((OP_SYNHIGH << 28) | (syn_high & self.syn_addr_mask))
                        # 0x4: PFLOWRFPLST
                        ref_period = 2
                        neural_brams[col].append((OP_PFLOWRFPLST << 28) | ((pflow_start & 0x3FF) << 16) | ((ref_period & 0xFF) << 8) | 0x7F)

                        # 0x5: NPADDRDATA (Dynamic Parameters)
                        for p_name in footprint["param_names"]:
                            p_addr = footprint["memory_map"][p_name]
                            p_val  = footprint["param_values"].get(p_name, 0.0)
                            p_fp16 = HalfPrecision2Bin(p_val)
                            neural_brams[col].append((OP_NPADDRDATA << 28) | ((p_addr & 0x3FF) << 16) | (p_fp16 & 0xFFFF))

                        # Target variable (e.g. v_next)
                        if "v_next" in footprint["memory_map"]:
                            v_next_addr = footprint["memory_map"]["v_next"]
                            neural_brams[col].append((OP_NPADDRDATA << 28) | ((v_next_addr & 0x3FF) << 16) | 0x0000)

                        # Plasticity Quad (0x6 .. 0x9) if learning is enabled
                        if has_learning:
                            # 0x6: ULEARNPARAMS
                            p_en = (1 << 17) if layer.pruning else 0
                            z_ig = (1 << 16) if layer.ignore_zero_synapses else 0
                            p_th = (int(layer.pruning_threshold) & 0xFF) << 8 if layer.pruning_threshold else 0
                            lr_b = int(round(layer.learning_rate * 256)) & 0xFF
                            neural_brams[col].append((OP_ULEARNPARAMS << 28) | p_en | z_ig | p_th | lr_b)

                            # 0x7: TABLELOW
                            tbl_start = synapse_table_starts[id(layer.synapse_model)]
                            neural_brams[col].append((OP_TABLELOW << 28) | (tbl_start & self.lut_addr_mask))

                            # 0x8: ULEARNLOWSYNADDR
                            neural_brams[col].append((OP_ULEARNLOWSYN << 28) | (syn_low & self.syn_addr_mask))

                            # 0x9: ULEARNHIGHSYNADDR
                            neural_brams[col].append((OP_ULEARNHIGHSYN << 28) | (syn_high & self.syn_addr_mask))

                        # 0xA: ENDFLOW Control
                        if is_last_layer and is_last_pass_of_layer:
                            end_flag = ENDFLOW_TIMESTEP_UPDATE
                        elif is_last_pass_of_layer:
                            end_flag = ENDFLOW_START_LEARNING if has_learning else ENDFLOW_SKIP_LEARNING_TIMESTEP
                        else:
                            end_flag = ENDFLOW_NEXT_NEURON

                        neural_brams[col].append((OP_ENDFLOW << 28) | end_flag)

                    # =========================================================
                    # B) REMAINDER / DUMMY COLUMN (BARRIER SYNCHRONIZATION)
                    # =========================================================
                    else:
                        # Emits single ENDFLOW with Barrier Sync bit enabled!
                        neural_brams[col].append((OP_ENDFLOW << 28) | ENDFLOW_BARRIER_SYNC)

        # ---------------------------------------------------------------------
        # STAGE 4: ARTIFACT PACKAGING
        # ---------------------------------------------------------------------
        neural_base = 6 + self.num_cols
        for c in range(self.num_cols):
            artifact.slave_payloads[6 + c] = np.array(synapse_brams[c], dtype=np.uint16)
            artifact.slave_payloads[neural_base + c] = np.array(neural_brams[c], dtype=np.uint32)
            
            artifact.synapse_payloads[c] = artifact.slave_payloads[6 + c]
            artifact.neural_payloads[c]  = artifact.slave_payloads[neural_base + c]

        # AXI-Lite Hardware Registers Configuration
        artifact.register_config[Regs.ADDR_NMC_XNEVER] = (current_scratchpad_offset << 16) | 0x0000
        artifact.register_config[Regs.ADDR_CORE_ROUTING_CFG] = CoreCfgMask.SYNAPSE_ROUTE_MASK

        if self.network.encoder is not None:
            enc = self.network.encoder
            conv_mode_bits = 0b00 if enc.mode == "poisson" else 0b01
            artifact.register_config[Regs.ADDR_D2S_CTRL]   = (conv_mode_bits << 1)
            artifact.register_config[Regs.ADDR_TIME_WIND]  = enc.time_window
            artifact.register_config[Regs.ADDR_SEED]       = enc.seed
            artifact.register_config[Regs.ADDR_DATA_COUNT] = enc.data_count

        print("\n[COMPILATION COMPLETE] Hardware binary artifacts generated successfully!")
        return artifact