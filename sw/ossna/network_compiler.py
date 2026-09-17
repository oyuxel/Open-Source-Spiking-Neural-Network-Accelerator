# ossna/network_compiler.py

import os
import math
import numpy as np
from typing import Dict, List, Optional
from .registers import Regs, CoreCfgMask, CoreResetMask
from .nmc_compiler import NMCCompiler, HalfPrecision2Bin
from .nmc_assembler import NModelAssembler
from .synapse import SynapseCompiler
from .network import Network, Layer, Projection

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

ENDFLOW_NEXT_NEURON            = 1 << 0
ENDFLOW_BARRIER_SYNC           = 1 << 1
ENDFLOW_START_LEARNING         = 1 << 2
ENDFLOW_SKIP_LEARNING_TIMESTEP = 1 << 3
ENDFLOW_TIMESTEP_UPDATE        = 1 << 4

class CompiledNetwork:
    def __init__(self, hw_info: dict):
        self.hw_info = hw_info
        self.register_config: Dict[int, int] = {}
        self.slave_payloads: Dict[int, np.ndarray] = {}
        
        self.verbose_nmc_asm: List[str] = []
        self.verbose_lut: List[str] = []
        self.verbose_synapses: Dict[int, List[str]] = {c: [] for c in range(hw_info["crossbar_col"])}
        self.verbose_neural: Dict[int, List[str]] = {c: [] for c in range(hw_info["crossbar_col"])}

        self.nmc_microcode: Optional[np.ndarray] = None
        self.stdp_lut: Optional[np.ndarray] = None
        self.synapse_payloads: Dict[int, np.ndarray] = {}
        self.neural_payloads: Dict[int, np.ndarray] = {}

    def save(self, filepath: str):
        bundle = {
            "reg_addrs": np.array(list(self.register_config.keys()), dtype=np.uint32),
            "reg_vals":  np.array(list(self.register_config.values()), dtype=np.uint32),
            **{f"slave_{k}": v for k, v in self.slave_payloads.items()}
        }
        np.savez_compressed(filepath, **bundle)
        print(f"[COMPILER ARTIFACT] Saved binary deployment bundle to '{filepath}'.")

    def export_simulation_files(self, output_dir: str):
        hex_dir = os.path.join(output_dir, "hex_mem_files")
        verb_dir = os.path.join(output_dir, "verbose_sim_files")
        os.makedirs(hex_dir, exist_ok=True)
        os.makedirs(verb_dir, exist_ok=True)

        print(f"\n[EXPORT] Exporting Simulation Files:")
        print(f"  -> HEX files for testbench: {hex_dir}")
        print(f"  -> Verbose TXT files for inspection: {verb_dir}")

        if 4 in self.slave_payloads:
            with open(os.path.join(hex_dir, "slave_4_nmc_program.mem"), "w") as f:
                for val in self.slave_payloads[4]: 
                    f.write(f"{val:04X}\n")
            
            with open(os.path.join(verb_dir, "nmc_program_verbose.txt"), "w") as f:
                f.write("=== NMC ASSEMBLY INSTRUCTIONS ===\n")
                f.write("\n".join(self.verbose_nmc_asm))

        if 5 in self.slave_payloads:
            with open(os.path.join(hex_dir, "slave_5_learning_lut.mem"), "w") as f:
                for val in self.slave_payloads[5]: 
                    f.write(f"{val:02X}\n")
            
            with open(os.path.join(verb_dir, "learning_lut_verbose.txt"), "w") as f:
                f.write("=== STDP LEARNING LUT VALUES ===\n")
                f.write("\n".join(self.verbose_lut))

        for c in range(self.hw_info["crossbar_col"]):
            s_id = 6 + c
            if s_id in self.slave_payloads:
                with open(os.path.join(hex_dir, f"slave_{s_id}_synapse_c{c}.mem"), "w") as f:
                    for val in self.slave_payloads[s_id]: 
                        f.write(f"{val:04X}\n")
                
                with open(os.path.join(verb_dir, f"synapse_c{c}_verbose.txt"), "w") as f:
                    f.write(f"=== SYNAPSE BRAM COLUMN {c} ===\n")
                    f.write("\n".join(self.verbose_synapses[c]))

        neural_base = 6 + self.hw_info["crossbar_col"]
        for c in range(self.hw_info["crossbar_col"]):
            s_id = neural_base + c
            if s_id in self.slave_payloads:
                with open(os.path.join(hex_dir, f"slave_{s_id}_neural_bridge_c{c}.mem"), "w") as f:
                    for val in self.slave_payloads[s_id]: 
                        f.write(f"{val:08X}\n")
                
                with open(os.path.join(verb_dir, f"neural_bridge_c{c}_verbose.txt"), "w") as f:
                    f.write(f"=== BRIDGE MICROCODES COLUMN {c} ===\n")
                    f.write("\n".join(self.verbose_neural[c]))

        print("[EXPORT COMPLETE] Both HEX and Verbose formats generated successfully.")


class NetworkCompiler:
    def __init__(self, network: Network, hw_info):
        self.network = network
        
        if hasattr(hw_info, "hw_info"):
            hw_info = hw_info.hw_info
            
        self.hw_info = hw_info
        self.num_cols = hw_info["crossbar_col"]
        self.syn_depth_per_col = hw_info["total_synapse_mem_words"] // self.num_cols
        self.param_depth_per_col = hw_info["total_param_mem_words"] // self.num_cols
        self.lut_depth = hw_info["learning_engine_lut_depth"]

        self.syn_addr_mask = (1 << ((self.syn_depth_per_col - 1).bit_length())) - 1
        self.lut_addr_mask = (1 << ((self.lut_depth - 1).bit_length())) - 1

    def compile(self) -> CompiledNetwork:
        print("\n" + "="*80)
        print("  OSSNA NETWORK COMPILER: PROJECTION & MULTI-CHANNEL TARGETING")
        print("="*80)

        self.network.validate_hardware(self.hw_info)
        artifact = CompiledNetwork(self.hw_info)

        print("\n[STAGE 1] Compiling Unique Neuron Models for Slave 4 (NMC Program)...")
        model_pflow_start = {}
        model_footprints = {}
        slave4_instructions = []
        current_scratchpad_offset = 16 

        for layer in self.network.layers:
            m = layer.neuron_model
            m_id = id(m)
            if m_id not in model_pflow_start:
                nmc_comp = NMCCompiler(m, base_offset=current_scratchpad_offset)
                asm_code = nmc_comp.compile()
                bytecode = NModelAssembler(asm_code)
                
                pflow_start = len(slave4_instructions)
                model_pflow_start[m_id] = pflow_start
                slave4_instructions.extend(bytecode)
                
                artifact.verbose_nmc_asm.append(f"\n# --- Neuron Model ({layer.name}, Base Offset: M({current_scratchpad_offset})) ---")
                asm_lines = asm_code.split("\n")
                for i, (asm, bc) in enumerate(zip(asm_lines, bytecode)):
                    artifact.verbose_nmc_asm.append(f"ADDR {pflow_start + i:<4} | HEX: {bc:04X} | ASM: {asm}")

                model_footprints[m_id] = {
                    "memory_map": nmc_comp.memory_map,
                    "param_names": nmc_comp.param_names,
                    "param_values": nmc_comp.param_values,
                    "base_offset": current_scratchpad_offset
                }
                current_scratchpad_offset += 16

        artifact.slave_payloads[4] = np.array(slave4_instructions, dtype=np.uint16)
        artifact.nmc_microcode = artifact.slave_payloads[4]

        print("\n[STAGE 2] Compiling STDP Plasticity Tables for Slave 5 (Learning LUT)...")
        synapse_table_starts = {}
        slave5_data = []

        for proj in self.network.projections:
            if proj.learning and proj.synapse_model is not None:
                s_model = proj.synapse_model
                table_key = (id(s_model), round(proj.q_factor, 6))
                if table_key not in synapse_table_starts:
                    syn_comp = SynapseCompiler(s_model)
                    lut_array = syn_comp.compile(q_factor=proj.q_factor)
                    
                    tbl_start = len(slave5_data)
                    synapse_table_starts[table_key] = tbl_start
                    slave5_data.extend(lut_array)
                    
                    artifact.verbose_lut.append(f"\n# --- STDP Model: {proj.name} (Q_syn={proj.q_factor:.6f}) ---")
                    for i, val in enumerate(lut_array):
                        phase = "LTP (Pre->Post)" if i < 128 else "LTD (Post->Pre)"
                        int8_val = val if val < 128 else val - 256
                        artifact.verbose_lut.append(f"ADDR {tbl_start + i:<4} | HEX: {val:02X} | Value: {int8_val:>4} | Phase: {phase}")

        if len(slave5_data) > 0:
            artifact.slave_payloads[5] = np.array(slave5_data, dtype=np.uint8)
            artifact.stdp_lut = artifact.slave_payloads[5]

        print("\n[STAGE 3] Generating Column Tiling & Multi-Channel Bridge Microcodes...")
        synapse_brams = [[] for _ in range(self.num_cols)]
        neural_brams  = [[] for _ in range(self.num_cols)]
        syn_addr_ptrs = [0] * self.num_cols

        for layer_idx, layer in enumerate(self.network.layers):
            is_first_layer = (layer_idx == 0)
            is_last_layer  = (layer_idx == len(self.network.layers) - 1)
            
            num_passes = math.ceil(layer.size / self.num_cols)
            footprint = model_footprints[id(layer.neuron_model)]
            pflow_start = model_pflow_start[id(layer.neuron_model)]

            for p_idx in range(num_passes):
                is_last_pass_of_layer = (p_idx == num_passes - 1)

                for col in range(self.num_cols):
                    neuron_in_layer = p_idx * self.num_cols + col
                    neuron_global_id = sum(l.size for l in self.network.layers[:layer_idx]) + neuron_in_layer

                    if neuron_in_layer < layer.size:
                        artifact.verbose_neural[col].append(f"\n# --- Layer: {layer.name} | Neuron L-ID: {neuron_in_layer} (Global ID: {neuron_global_id}) ---")
                        
                        proj_syn_bounds = {}

                        for pin_idx, pin_name in enumerate(layer.neuron_model.Inputs):
                            proj = layer.get_projection_for_pin(pin_name)
                            if proj is None:
                                raise ValueError(f"No projection connected to pin '{pin_name}' in layer '{layer.name}'!")

                            w_raw = proj.weights[:, neuron_in_layer].astype(np.uint16)
                            w_packed = ((w_raw & 0xFF) << 8) | 0x7F

                            syn_low = syn_addr_ptrs[col]
                            syn_high = syn_low + len(w_packed) - 1
                            synapse_brams[col].extend(w_packed.tolist())
                            syn_addr_ptrs[col] = syn_high + 1
                            proj_syn_bounds[proj.name] = (syn_low, syn_high)

                            artifact.verbose_synapses[col].append(
                                f"\n# --- Layer: {layer.name} | Neuron: {neuron_in_layer} | Channel: {pin_name} (Projection: {proj.name}) ---"
                            )
                            artifact.verbose_synapses[col].append(f"# BRAM Address Range: [{syn_low} .. {syn_high}] | Synapse Count: {len(w_packed)}")
                            for offset, w_val in enumerate(w_raw):
                                artifact.verbose_synapses[col].append(f"ADDR {syn_low + offset:<4} | HEX: {w_packed[offset]:04X} | Weight: {w_val & 0xFF:<4} | Trace: 127")

                            if proj.source == "input":
                                src_main = 1 if p_idx == 0 else 0
                                src_circ = 1 if p_idx > 0 else 0
                                src_aux  = 0
                            elif proj.source == layer:
                                src_main, src_circ, src_aux = 0, 0, 1
                            else:
                                src_main = 0
                                src_aux  = 1 if p_idx == 0 else 0
                                src_circ = 1 if p_idx > 0 else 0

                            dst_out = 1 if is_last_layer else 0
                            dst_aux = 1 if (not is_last_layer or any(p.source == layer for p in layer.projections)) else 0

                            synq_fp16 = HalfPrecision2Bin(proj.q_factor)

                            sssd_flags = (src_main << 20) | (src_circ << 19) | (src_aux << 18) | (dst_aux << 17) | (dst_out << 16)
                            cmd_sssd = (OP_SSSDSYNQ << 28) | sssd_flags | (synq_fp16 & 0xFFFF)
                            cmd_synlow = (OP_SYNLOW << 28) | (syn_low & self.syn_addr_mask)
                            cmd_synhigh = (OP_SYNHIGH << 28) | (syn_high & self.syn_addr_mask)

                            neural_brams[col].append(cmd_sssd)
                            neural_brams[col].append(cmd_synlow)
                            neural_brams[col].append(cmd_synhigh)

                            artifact.verbose_neural[col].append(f"HEX: {cmd_sssd:08X} | SSSDSYNQ (Pin: {pin_name}) -> Src_Main={src_main} Src_Circ={src_circ} Src_Aux={src_aux} | Dst_Out={dst_out} Dst_Aux={dst_aux} | Q_syn={proj.q_factor:.6f}")
                            artifact.verbose_neural[col].append(f"HEX: {cmd_synlow:08X} | SYNLOW   (Pin: {pin_name}) -> Address: {syn_low}")
                            artifact.verbose_neural[col].append(f"HEX: {cmd_synhigh:08X} | SYNHIGH  (Pin: {pin_name}) -> Address: {syn_high}")

                        ref_period = 2
                        cmd_pflow = (OP_PFLOWRFPLST << 28) | ((pflow_start & 0x3FF) << 16) | ((ref_period & 0xFF) << 8) | 0x7F
                        neural_brams[col].append(cmd_pflow)
                        artifact.verbose_neural[col].append(f"HEX: {cmd_pflow:08X} | PFLOWRFPLST -> NMC Address: {pflow_start}, Ref: {ref_period}, LastSpk: 127")

                        for p_name in footprint["param_names"]:
                            p_addr = footprint["memory_map"][p_name]
                            p_val  = footprint["param_values"].get(p_name, 0.0)
                            p_fp16 = HalfPrecision2Bin(p_val)
                            cmd_param = (OP_NPADDRDATA << 28) | ((p_addr & 0x3FF) << 16) | (p_fp16 & 0xFFFF)
                            neural_brams[col].append(cmd_param)
                            artifact.verbose_neural[col].append(f"HEX: {cmd_param:08X} | NPADDRDATA -> M({p_addr}) = {p_val} ({p_name})")

                        if "v_next" in footprint["memory_map"]:
                            v_next_addr = footprint["memory_map"]["v_next"]
                            cmd_vnext = (OP_NPADDRDATA << 28) | ((v_next_addr & 0x3FF) << 16) | 0x0000
                            neural_brams[col].append(cmd_vnext)
                            artifact.verbose_neural[col].append(f"HEX: {cmd_vnext:08X} | NPADDRDATA -> M({v_next_addr}) = 0.0 (v_next)")

                        has_any_learning = False
                        for proj in layer.projections:
                            if proj.learning and proj.synapse_model is not None:
                                has_any_learning = True
                                p_en = (1 << 17) if proj.pruning else 0
                                z_ig = (1 << 16) if proj.ignore_zero_synapses else 0
                                p_th = (int(proj.pruning_threshold) & 0xFF) << 8 if proj.pruning_threshold else 0
                                lr_b = int(round(proj.learning_rate * 256)) & 0xFF
                                cmd_lr = (OP_ULEARNPARAMS << 28) | p_en | z_ig | p_th | lr_b
                                
                                table_key = (id(proj.synapse_model), round(proj.q_factor, 6))
                                tbl_start = synapse_table_starts[table_key]
                                cmd_table = (OP_TABLELOW << 28) | (tbl_start & self.lut_addr_mask)

                                syn_l, syn_h = proj_syn_bounds[proj.name]
                                cmd_ulow = (OP_ULEARNLOWSYN << 28) | (syn_l & self.syn_addr_mask)
                                cmd_uhigh = (OP_ULEARNHIGHSYN << 28) | (syn_h & self.syn_addr_mask)

                                neural_brams[col].append(cmd_lr)
                                neural_brams[col].append(cmd_table)
                                neural_brams[col].append(cmd_ulow)
                                neural_brams[col].append(cmd_uhigh)

                                artifact.verbose_neural[col].append(f"HEX: {cmd_lr:08X} | ULEARNPARAMS (Pin: {proj.target_pin}) -> Prun={proj.pruning}, Ignore_Z={proj.ignore_zero_synapses}, LR={lr_b}/256")
                                artifact.verbose_neural[col].append(f"HEX: {cmd_table:08X} | TABLELOW (Pin: {proj.target_pin}) -> Address: {tbl_start}")
                                artifact.verbose_neural[col].append(f"HEX: {cmd_ulow:08X} | ULEARNLOWSYNADDR (Pin: {proj.target_pin}) -> Address: {syn_l}")
                                artifact.verbose_neural[col].append(f"HEX: {cmd_uhigh:08X} | ULEARNHIGHSYNADDR (Pin: {proj.target_pin}) -> Address: {syn_h}")

                        if has_any_learning:
                            end_flag = ENDFLOW_START_LEARNING
                        else:
                            if is_last_layer and is_last_pass_of_layer:
                                end_flag = ENDFLOW_TIMESTEP_UPDATE
                            elif is_last_pass_of_layer:
                                end_flag = ENDFLOW_SKIP_LEARNING_TIMESTEP
                            else:
                                end_flag = ENDFLOW_NEXT_NEURON

                        cmd_end = (OP_ENDFLOW << 28) | end_flag
                        neural_brams[col].append(cmd_end)
                        artifact.verbose_neural[col].append(f"HEX: {cmd_end:08X} | ENDFLOW -> Flag: {end_flag} (Complete)")

                    else:
                        cmd_dummy = (OP_ENDFLOW << 28) | ENDFLOW_BARRIER_SYNC
                        neural_brams[col].append(cmd_dummy)
                        artifact.verbose_neural[col].append(f"\n# --- Layer: {layer.name} | DUMMY/BARRIER ---")
                        artifact.verbose_neural[col].append(f"HEX: {cmd_dummy:08X} | ENDFLOW -> BARRIER SYNC (Waiting...)")

        neural_base = 6 + self.num_cols
        for c in range(self.num_cols):
            artifact.slave_payloads[6 + c] = np.array(synapse_brams[c], dtype=np.uint16)
            artifact.slave_payloads[neural_base + c] = np.array(neural_brams[c], dtype=np.uint32)
            
            artifact.synapse_payloads[c] = artifact.slave_payloads[6 + c]
            artifact.neural_payloads[c]  = artifact.slave_payloads[neural_base + c]

        artifact.register_config[Regs.ADDR_NMC_XNEVER] = (current_scratchpad_offset << 16) | 0x0000
        artifact.register_config[Regs.ADDR_CORE_ROUTING_CFG] = CoreCfgMask.SYNAPSE_ROUTE_MASK

        if self.network.encoder is not None:
            enc = self.network.encoder
            conv_mode_bits = 0b00 if enc.mode == "poisson" else 0b01
            artifact.register_config[Regs.ADDR_D2S_CTRL]   = (conv_mode_bits << 1)
            artifact.register_config[Regs.ADDR_TIME_WIND]  = enc.time_window
            artifact.register_config[Regs.ADDR_SEED]       = enc.seed
            artifact.register_config[Regs.ADDR_DATA_COUNT] = enc.data_count

        print("\n[COMPILATION COMPLETE] Hardware artifacts and verbose traces generated successfully!")
        return artifact