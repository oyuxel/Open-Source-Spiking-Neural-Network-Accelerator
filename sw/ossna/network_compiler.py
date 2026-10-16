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
OP_ULEARNCFGLOW    = 0x6
OP_ULEARNLOWSYN    = 0x7
OP_ULEARNHIGHSYN   = 0x8
OP_ENDFLOW         = 0xF

ENDFLOW_NEXT_NEURON   = 1 << 0
ENDFLOW_BARRIER_SYNC  = 1 << 1
ENDFLOW_LEARNING_EN   = 1 << 2
ENDFLOW_TIMESTEP_UP   = 1 << 3

class CompiledNetwork:
    def __init__(self, hw_info: dict):
        self.hw_info = hw_info
        self.register_config: Dict[int, int] = {}
        self.slave_payloads: Dict[int, np.ndarray] = {}
        
        self.xnever_base: int = 0
        self.xnever_high: int = 0
        self.shared_inputs_start: int = 0
        self.shared_inputs_end: int = 0

        self.verbose_nmc_asm: List[str] = []
        self.verbose_nmc_memory_map: List[str] = []
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
            "xnever_bounds": np.array([self.xnever_base, self.xnever_high], dtype=np.uint32),
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
                f.write("================================================================================\n")
                f.write("                    NMC MEMORY CONFIGURATION & XNEVER BOUNDARIES\n")
                f.write("================================================================================\n")
                f.write(f"XNEVER_BASE               : {self.xnever_base}\n")
                f.write(f"XNEVER_HIGH               : {self.xnever_high}\n")
                f.write(f"Executable Program Range  : M(0) to M({max(0, self.xnever_base - 1)})\n")
                f.write(f"Shared Input Scratchpad   : M({self.shared_inputs_start}) to M({self.shared_inputs_end - 1})\n")
                f.write(f"Footprints / Data Range   : M({self.shared_inputs_end}) to M({self.xnever_high - 1})\n")
                f.write(f"Total BRAM Memory Used    : {self.xnever_high} / 1024 words\n")
                f.write("================================================================================\n\n")
                f.write("=== NMC DISASSEMBLED INSTRUCTION TRACE ===\n")
                f.write("\n".join(self.verbose_nmc_asm))
                f.write("\n\n=== FULL NMC BRAM MEMORY MAP (0..1023) ===\n")
                f.write("\n".join(self.verbose_nmc_memory_map))

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
    def __init__(self, network: Network, hw_info, global_dt: float = 1.0):
        self.network = network
        
        self.network = network
        self.hw_info = hw_info.hw_info if hasattr(hw_info, "hw_info") else hw_info
        self.global_dt = global_dt 
            
        self.hw_info = hw_info
        self.num_cols = hw_info["crossbar_col"]
        self.syn_depth_per_col = hw_info["total_synapse_mem_words"] // self.num_cols
        self.param_depth_per_col = hw_info["total_param_mem_words"] // self.num_cols
        self.lut_depth = hw_info.get("learning_engine_lut_depth", 2048)

        self.syn_addr_mask = (1 << ((self.syn_depth_per_col - 1).bit_length())) - 1
        self.lut_addr_mask = (1 << ((self.lut_depth - 1).bit_length())) - 1

    def compile(self) -> CompiledNetwork:
        print("\n" + "="*80)
        print("  OSSNA NETWORK COMPILER: PROJECTION & MULTI-CHANNEL TARGETING")
        print("="*80)

        self.network.validate_hardware(self.hw_info)
        artifact = CompiledNetwork(self.hw_info)

        print("\n[STAGE 1] Calculating Dynamic XNEVER & Compiling NMC Memory Image...")
        unique_models = []
        max_inputs = 0
        total_prog_words = 0
        
        for layer in self.network.layers:
            m = layer.neuron_model
            m.dt = self.global_dt
            m_id = id(m)
            if m_id not in [x["id"] for x in unique_models]:
                dry_comp = NMCCompiler(m)
                dry_asm = dry_comp.compile()
                dry_bc = NModelAssembler(dry_asm)
                prog_len = len(dry_bc)
                
                inputs_len = len(m.Inputs)
                if inputs_len > max_inputs:
                    max_inputs = inputs_len
                    
                unique_models.append({
                    "id": m_id,
                    "model": m,
                    "prog_len": prog_len
                })
                total_prog_words += prog_len

        xnever_base = total_prog_words
        shared_inputs_start = xnever_base
        shared_inputs_end   = xnever_base + max_inputs
        current_footprint_offset = shared_inputs_end
        
        artifact.xnever_base = xnever_base
        artifact.shared_inputs_start = shared_inputs_start
        artifact.shared_inputs_end = shared_inputs_end

        print(f"  * Total Program Words      : {total_prog_words} words")
        print(f"  * Max Input Pins           : {max_inputs} pins")
        print(f"  * XNEVER_BASE              : {xnever_base}")

        nmc_bram_image = np.zeros(1024, dtype=np.uint16)
        artifact.verbose_nmc_memory_map = [f"ADDR {i:<4} | HEX: 0000 | (Empty)" for i in range(1024)]
        
        for i in range(max_inputs):
            in_addr = shared_inputs_start + i
            artifact.verbose_nmc_memory_map[in_addr] = f"ADDR {in_addr:<4} | HEX: 0000 | [SHARED INPUT {i}]"

        model_pflow_start = {}
        model_footprints = {}
        current_prog_ptr = 0

        for um in unique_models:
            m_id = um["id"]
            m = um["model"]
            
            nmc_comp = NMCCompiler(m, base_offset=current_footprint_offset, input_base=shared_inputs_start)
            asm_code = nmc_comp.compile()
            bytecode = NModelAssembler(asm_code)
            
            pflow_start = current_prog_ptr
            model_pflow_start[m_id] = pflow_start
            
            if (current_prog_ptr + len(bytecode)) > 1024:
                raise OverflowError("NMC Memory Overflows 1024 words!")
                
            nmc_bram_image[current_prog_ptr : current_prog_ptr + len(bytecode)] = bytecode
            
            artifact.verbose_nmc_asm.append(f"\n# --- Neuron Model (PFLOW Start: {pflow_start}) ---")
            asm_lines = asm_code.split("\n")
            for i, (asm, bc) in enumerate(zip(asm_lines, bytecode)):
                artifact.verbose_nmc_asm.append(f"ADDR {pflow_start + i:<4} | HEX: {bc:04X} | ASM: {asm}")
                artifact.verbose_nmc_memory_map[pflow_start + i] = f"ADDR {pflow_start + i:<4} | HEX: {bc:04X} | [PROGRAM] {asm}"

            current_prog_ptr += len(bytecode)

            model_footprints[m_id] = {
                "memory_map": nmc_comp.memory_map,
                "param_names": nmc_comp.param_names,
                "param_values": nmc_comp.param_values,
                "const_names": nmc_comp.const_names,
                "const_values": nmc_comp.const_values,
                "base_offset": current_footprint_offset
            }
            
            if "1.0" in nmc_comp.memory_map:
                a_1 = nmc_comp.memory_map["1.0"]
                fp16 = HalfPrecision2Bin(1.0)
                nmc_bram_image[a_1] = fp16
                artifact.verbose_nmc_memory_map[a_1] = f"ADDR {a_1:<4} | HEX: {fp16:04X} | [CONSTANT] 1.0"

            for c_name in nmc_comp.const_names:
                if c_name in nmc_comp.memory_map:
                    c_addr = nmc_comp.memory_map[c_name]
                    c_val = nmc_comp.const_values.get(c_name, 0.0)
                    fp16 = HalfPrecision2Bin(c_val)
                    nmc_bram_image[c_addr] = fp16
                    artifact.verbose_nmc_memory_map[c_addr] = f"ADDR {c_addr:<4} | HEX: {fp16:04X} | [CONSTANT] {c_name} = {c_val}"
            
            for c_name in nmc_comp.const_names:
                r_name = f"{c_name}_recip"
                if r_name in nmc_comp.memory_map:
                    r_addr = nmc_comp.memory_map[r_name]
                    c_val = nmc_comp.const_values.get(c_name, 0.0)
                    recip_val = 1.0 / c_val if c_val != 0 else 0.0
                    fp16 = HalfPrecision2Bin(recip_val)
                    nmc_bram_image[r_addr] = fp16
                    artifact.verbose_nmc_memory_map[r_addr] = f"ADDR {r_addr:<4} | HEX: {fp16:04X} | [CONSTANT] {r_name}"

            for p_name in nmc_comp.param_names:
                if p_name in nmc_comp.memory_map:
                    p_addr = nmc_comp.memory_map[p_name]
                    artifact.verbose_nmc_memory_map[p_addr] = f"ADDR {p_addr:<4} | HEX: 0000 | [DYNAMIC PARAM] {p_name}"

            current_footprint_offset = max(nmc_comp.memory_map.values()) + 1

        print("\n[STAGE 2] Compiling ULEARN VLIW & Plasticity Tables for Slave 5...")
        slave5_data = np.zeros(self.lut_depth, dtype=np.uint8)
        current_lut_ptr = 0
        proj_learning_info = {}
        processed_rules = {}

        for proj in self.network.projections:
            if proj.learning and proj.synapse_model is not None:
                s_model = proj.synapse_model
                has_multiplication = '*' in s_model.update_rule
                auto_shift = 8 if has_multiplication else 0
                rule_key = (id(s_model), round(proj.q_factor, 6), round(proj.w_min, 6), round(proj.w_max, 6), auto_shift)
                
                if rule_key not in processed_rules:
                    s_model.quant_factor = proj.q_factor
                    s_model.wmin = proj.w_min
                    s_model.wmax = proj.w_max
                    s_model.out_shift = auto_shift

                    s_model.correlation_step = self.global_dt

                    syn_comp = SynapseCompiler(s_model)
                    
                    syn_comp = SynapseCompiler(s_model)
                    lut_info = syn_comp.get_lut_array()
                    addr_min, addr_max = lut_info["address_limits"]
                    lut_size = addr_max - addr_min + 1
                    
                    if current_lut_ptr + lut_size > self.lut_depth:
                        raise MemoryError("Slave 5 LUT BRAM capacity exceeded.")
                        
                    center_offset = current_lut_ptr - addr_min
                    vliw_hex = syn_comp.compile_vliw(lut_center_addr=center_offset)
                    
                    lut_dict = lut_info["lut_data"]
                    for offset in range(addr_min, addr_max + 1):
                        bram_addr = center_offset + offset
                        val = lut_dict.get(offset, 0)
                        slave5_data[bram_addr] = val & 0xFF
                        
                    artifact.verbose_lut.append(f"\n# --- STDP Model: {proj.name} (Center Offset: {center_offset}) ---")
                    for offset in range(addr_min, addr_max + 1):
                        b_addr = center_offset + offset
                        v = slave5_data[b_addr]
                        int8_v = v if v < 128 else v - 256
                        artifact.verbose_lut.append(f"ADDR {b_addr:<4} | HEX: {v:02X} | INT8: {int8_v:>4} | Offset: {offset}")
                        
                    current_lut_ptr += lut_size
                    
                    if current_footprint_offset + 16 > 1024:
                        raise MemoryError("NMC BRAM Capacity exceeded while allocating VLIW words.")
                        
                    cfg_absolute_addr = current_footprint_offset
                    vliw_val = int(vliw_hex, 16)
                    
                    artifact.verbose_nmc_memory_map[cfg_absolute_addr] = f"\n# --- VLIW CFG_WORD for {proj.name} ---"
                    for i in range(16):
                        chunk = (vliw_val >> (i * 16)) & 0xFFFF
                        nmc_bram_image[cfg_absolute_addr + i] = chunk
                        artifact.verbose_nmc_memory_map[cfg_absolute_addr + i] = f"ADDR {cfg_absolute_addr + i:<4} | HEX: {chunk:04X} | VLIW CHUNK [{i}]"
                        
                    current_footprint_offset += 16
                    processed_rules[rule_key] = cfg_absolute_addr
                    
                proj_learning_info[proj.name] = processed_rules[rule_key]

        artifact.slave_payloads[5] = slave5_data
        artifact.stdp_lut = artifact.slave_payloads[5]
        
        xnever_high = current_footprint_offset
        artifact.xnever_high = xnever_high
        artifact.register_config[Regs.ADDR_NMC_XNEVER] = (xnever_high << 16) | (xnever_base & 0x3FF)
        artifact.slave_payloads[4] = nmc_bram_image
        artifact.nmc_microcode = artifact.slave_payloads[4]

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
                        artifact.verbose_neural[col].append(f"\n# --- Layer: {layer.name} | Neuron L-ID: {neuron_in_layer} ---")
                        
                        cmd_pflow = (OP_PFLOWRFPLST << 28) | ((pflow_start & 0x3FF) << 16) | (0x00 << 8) | 0xFF
                        neural_brams[col].append(cmd_pflow)
                        artifact.verbose_neural[col].append(f"HEX: {cmd_pflow:08X} | PFLOWRFPLST -> NMC Address: {pflow_start}")

                        ulearn_cmds_temp = []
                        ulearn_verbose_temp = []

                        for pin_idx, pin_name in enumerate(layer.neuron_model.Inputs):
                            proj = layer.get_projection_for_pin(pin_name)
                            if proj is None:
                                raise ValueError(f"No projection connected to pin '{pin_name}' in layer '{layer.name}'!")

                            w_raw = proj.weights[:, neuron_in_layer].astype(np.uint16)
                            w_packed = ((w_raw & 0xFF) << 8) | 0xFF

                            syn_low = syn_addr_ptrs[col]
                            syn_high = syn_low + len(w_packed) - 1
                            synapse_brams[col].extend(w_packed.tolist())
                            syn_addr_ptrs[col] = syn_high + 1

                            artifact.verbose_synapses[col].append(f"\n# --- Layer: {layer.name} | Channel: {pin_name} ---")
                            for offset, w_val in enumerate(w_raw):
                                artifact.verbose_synapses[col].append(f"ADDR {syn_low + offset:<4} | HEX: {w_packed[offset]:04X}")

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

                            artifact.verbose_neural[col].append(f"HEX: {cmd_sssd:08X} | SSSDSYNQ (Pin: {pin_name})")
                            artifact.verbose_neural[col].append(f"HEX: {cmd_synlow:08X} | SYNLOW   (Pin: {pin_name}) -> Addr: {syn_low}")
                            artifact.verbose_neural[col].append(f"HEX: {cmd_synhigh:08X} | SYNHIGH  (Pin: {pin_name}) -> Addr: {syn_high}")

                            if proj.learning and proj.synapse_model is not None:
                                cfg_addr = proj_learning_info[proj.name]
                                
                                cmd_cfg = (OP_ULEARNCFGLOW << 28) | (cfg_addr & 0x3FF)
                                cmd_ulow = (OP_ULEARNLOWSYN << 28) | (syn_low & self.syn_addr_mask)
                                cmd_uhigh = (OP_ULEARNHIGHSYN << 28) | (syn_high & self.syn_addr_mask)

                                ulearn_cmds_temp.append(cmd_cfg)
                                ulearn_cmds_temp.append(cmd_ulow)
                                ulearn_cmds_temp.append(cmd_uhigh)

                                ulearn_verbose_temp.append(f"HEX: {cmd_cfg:08X} | ULEARNCFGLOW (Pin: {pin_name}) -> CFG Addr: {cfg_addr}")
                                ulearn_verbose_temp.append(f"HEX: {cmd_ulow:08X} | ULEARNLOWSYN (Pin: {pin_name}) -> Addr: {syn_low}")
                                ulearn_verbose_temp.append(f"HEX: {cmd_uhigh:08X} | ULEARNHIGHSYN (Pin: {pin_name}) -> Addr: {syn_high}")

                        for p_name in footprint["param_names"]:
                            p_addr = footprint["memory_map"][p_name]
                            p_val  = footprint["param_values"].get(p_name, 0.0)
                            p_fp16 = HalfPrecision2Bin(p_val)
                            cmd_param = (OP_NPADDRDATA << 28) | ((p_addr & 0x3FF) << 16) | (p_fp16 & 0xFFFF)
                            neural_brams[col].append(cmd_param)
                            artifact.verbose_neural[col].append(f"HEX: {cmd_param:08X} | NPADDRDATA -> M({p_addr}) = {p_val}")

                        if ulearn_cmds_temp:
                            neural_brams[col].extend(ulearn_cmds_temp)
                            artifact.verbose_neural[col].extend(ulearn_verbose_temp)

                        end_flag = 0
                        if any(p.learning for p in layer.projections):
                            end_flag |= ENDFLOW_LEARNING_EN

                        if is_last_layer and is_last_pass_of_layer:
                            end_flag |= ENDFLOW_TIMESTEP_UP  
                        else:
                            end_flag |= ENDFLOW_NEXT_NEURON  

                        cmd_end = (OP_ENDFLOW << 28) | end_flag
                        neural_brams[col].append(cmd_end)
                        artifact.verbose_neural[col].append(f"HEX: {cmd_end:08X} | ENDFLOW")

                    else:
                        dummy_flag = ENDFLOW_BARRIER_SYNC  
                        if is_last_layer and is_last_pass_of_layer:
                            dummy_flag |= ENDFLOW_TIMESTEP_UP 
                        else:
                            dummy_flag |= ENDFLOW_NEXT_NEURON 
                        
                        cmd_dummy = (OP_ENDFLOW << 28) | dummy_flag
                        neural_brams[col].append(cmd_dummy)
                        artifact.verbose_neural[col].append(f"\n# --- Layer: {layer.name} | DUMMY/BARRIER ---")
                        artifact.verbose_neural[col].append(f"HEX: {cmd_dummy:08X} | ENDFLOW -> DUMMY BARRIER")

        neural_base = 6 + self.num_cols
        for c in range(self.num_cols):
            artifact.slave_payloads[6 + c] = np.array(synapse_brams[c], dtype=np.uint16)
            artifact.slave_payloads[neural_base + c] = np.array(neural_brams[c], dtype=np.uint32)
            
            artifact.synapse_payloads[c] = artifact.slave_payloads[6 + c]
            artifact.neural_payloads[c]  = artifact.slave_payloads[neural_base + c]

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