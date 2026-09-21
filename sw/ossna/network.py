# ossna/network.py

import math
import numpy as np
from typing import Union, List, Dict, Optional, Tuple

class InputEncoder:
    def __init__(self, mode: str = "poisson", time_window: int = 100, seed: int = 0x12345678, data_count: int = None):
        self.mode = mode.lower()
        if self.mode not in ["poisson", "latency"]:
            raise ValueError(f"Unsupported D2S mode '{mode}'! Allowed modes are 'poisson' or 'latency'.")
        self.time_window = int(time_window)
        self.seed = int(seed)
        self.data_count = data_count

    def encode(self, raw_features: np.ndarray) -> np.ndarray:
        features = np.clip(np.array(raw_features, dtype=np.float64), 0.0, 1.0)
        if self.mode == "poisson":
            ir_values = np.round(features * 0xFFFFFFFF)
            return ir_values.astype(np.uint32)
        elif self.mode == "latency":
            step_timings = np.round((1.0 - features) * (self.time_window - 1))
            ir_values = np.clip(step_timings, 0, self.time_window - 1)
            return ir_values.astype(np.uint32)

class Projection:
    def __init__(self, name: str, source, target, target_pin: str,
                 weights: np.ndarray, scheme: str = "dense",
                 input_slice: Optional[Tuple[int, int]] = None,
                 synapse_model=None, learning: bool = False,
                 learning_rate: float = 0.05,
                 pruning: bool = False, pruning_threshold: Optional[float] = None,
                 ignore_zero_synapses: bool = True,
                 w_min: float = 0.0, w_max: float = 127.0):
        self.name = name
        self.source = source
        self.target = target
        self.target_pin = target_pin
        self.input_slice = input_slice
        self.weights = weights
        self.scheme = scheme
        self.synapse_model = synapse_model
        self.learning = learning and (synapse_model is not None)
        self.learning_rate = float(learning_rate)
        self.pruning = pruning or (pruning_threshold is not None)
        self.pruning_threshold = pruning_threshold
        self.ignore_zero_synapses = ignore_zero_synapses
        self.w_min = float(w_min)
        self.w_max = float(w_max)

        weight_range = self.w_max - self.w_min
        self.q_factor = (weight_range / 255.0) if weight_range > 0 else (1.0 / 255.0)

class Layer:
    def __init__(self, name: str, size: int, neuron_model):
        self.name = name
        self.size = size
        self.neuron_model = neuron_model
        self.projections: List[Projection] = []

    def get_projection_for_pin(self, pin_name: str) -> Optional[Projection]:
        for proj in self.projections:
            if proj.target_pin == pin_name:
                return proj
        return None

class Network:
    def __init__(self, input_size: int):
        self.input_size = int(input_size)
        self.layers: List[Layer] = []
        self.projections: List[Projection] = []
        self.encoder: Optional[InputEncoder] = None

    def set_input_encoder(self, mode: str = "poisson", time_window: int = 100, seed: int = 0x12345678):
        self.encoder = InputEncoder(mode=mode, time_window=time_window, seed=seed, data_count=self.input_size)

    def add_layer(self, name: str, size: int, neuron_model) -> Layer:
        layer = Layer(name=name, size=size, neuron_model=neuron_model)
        self.layers.append(layer)
        return layer

    def _create_weights(self, in_size: int, out_size: int, init_method, w_min: float, w_max: float, q_factor: float, connectivity) -> np.ndarray:
        if isinstance(init_method, np.ndarray):
            if init_method.shape != (in_size, out_size):
                raise ValueError(f"Weight matrix shape mismatch! Expected: ({in_size}, {out_size}), Got: {init_method.shape}")
            W_float = np.copy(init_method).astype(np.float64)
        elif init_method in ["all_to_all_except_self", "wta"]:
            val = float(w_min)
            W_float = np.full((in_size, out_size), fill_value=val, dtype=np.float64)
        elif init_method in ["uniform", "random"]:
            W_float = np.random.uniform(w_min, w_max, size=(in_size, out_size))
        elif init_method == "normal":
            mid = (w_max + w_min) / 2.0
            std = max(1e-4, (w_max - w_min) / 6.0)
            W_float = np.random.normal(mid, std, size=(in_size, out_size))
        elif init_method == "xavier":
            scale = np.sqrt(2.0 / (in_size + out_size)) * (w_max - w_min)
            W_float = np.random.uniform(w_min, min(w_max, w_min + scale), size=(in_size, out_size))
        elif isinstance(init_method, (int, float)):
            W_float = np.full((in_size, out_size), float(init_method), dtype=np.float64)
        else:
            raise ValueError(f"Unknown weight configuration: {init_method}")

        W_float = np.clip(W_float, w_min, w_max)
        W_int8 = np.clip(np.round(W_float / q_factor), -128, 127).astype(np.int8)

        if init_method in ["all_to_all_except_self", "wta"] and in_size == out_size:
            np.fill_diagonal(W_int8, 0)

        if isinstance(connectivity, (int, float)) and 0.0 < connectivity < 1.0:
            mask = np.random.rand(in_size, out_size) < connectivity
            W_int8 = W_int8 * mask

        return W_int8

    def add_projection(self, name: str, source: Union[str, Layer], target: Layer, target_pin: str,
                       input_slice: Optional[Tuple[int, int]] = None,
                       weights: Union[str, float, int, np.ndarray] = "uniform",
                       scheme: str = "dense",
                       synapse_model=None,
                       learning: bool = False, learning_rate: float = 0.05,
                       pruning: bool = False, pruning_threshold: Optional[float] = None,
                       ignore_zero_synapses: bool = True,
                       w_min: float = 0.0, w_max: float = 127.0) -> Projection:
        
        if target_pin not in target.neuron_model.Inputs:
            raise ValueError(
                f"[TOPOLOGY ERROR] Pin '{target_pin}' does not exist in target neuron model! "
                f"Available inputs in model: {target.neuron_model.Inputs}"
            )

        if isinstance(source, str) and source.lower() == "input":
            if input_slice is not None:
                start_idx, end_idx = input_slice
                if not (0 <= start_idx < end_idx <= self.input_size):
                    raise ValueError(f"Invalid input_slice {input_slice} for total input size {self.input_size}!")
                source_size = end_idx - start_idx
            else:
                source_size = self.input_size
                input_slice = (0, self.input_size)
        elif isinstance(source, Layer):
            source_size = source.size
        else:
            raise ValueError(f"Invalid source '{source}'! Must be 'input' or a Layer instance.")

        target_size = target.size

        weight_range = float(w_max) - float(w_min)
        q_factor = (weight_range / 255.0) if weight_range > 0 else (1.0 / 255.0)

        init_method = scheme if scheme in ["all_to_all_except_self", "wta"] else weights
        if scheme in ["all_to_all_except_self", "wta"] and isinstance(weights, (int, float)):
            w_min = float(weights)

        weight_matrix_int8 = self._create_weights(source_size, target_size, init_method, w_min, w_max, q_factor, connectivity="dense")

        proj = Projection(
            name=name,
            source=source,
            target=target,
            target_pin=target_pin,
            input_slice=input_slice,
            weights=weight_matrix_int8,
            scheme=scheme,
            synapse_model=synapse_model,
            learning=learning,
            learning_rate=learning_rate,
            pruning=pruning,
            pruning_threshold=pruning_threshold,
            ignore_zero_synapses=ignore_zero_synapses,
            w_min=w_min,
            w_max=w_max
        )

        target.projections.append(proj)
        self.projections.append(proj)
        return proj

    def validate_hardware(self, core_or_hw_info) -> bool:
        hw_info = core_or_hw_info.hw_info if hasattr(core_or_hw_info, "hw_info") else core_or_hw_info
        max_neurons = hw_info["max_supported_neurons"]
        crossbar_cols = hw_info["crossbar_col"]
        words_per_syn_col = hw_info["total_synapse_mem_words"] // crossbar_cols

        total_neurons = sum(l.size for l in self.layers)
        if total_neurons > max_neurons:
            raise ValueError(f"[HARDWARE ERROR] Total network neurons ({total_neurons}) exceeds limit ({max_neurons})!")

        for l in self.layers:
            k_virtual = math.ceil(l.size / crossbar_cols)
            total_inputs_for_layer = sum(p.weights.shape[0] for p in l.projections)
            synapses_needed = k_virtual * total_inputs_for_layer

            if synapses_needed > words_per_syn_col:
                raise OverflowError(
                    f"[HARDWARE ERROR] Layer '{l.name}' requires {synapses_needed} synapses per column, "
                    f"but hardware depth is {words_per_syn_col} words!"
                )

        print("[VALIDATION OK] Network topology and projections are 100% compatible with hardware constraints!")
        return True

    def save_checkpoint(self, filepath: str, core=None):
        checkpoint = {}
        if core is not None:
            print("[CHECKPOINT] Pulling live weights from hardware BRAM via DMA...")
            col_count = core.hw_info["crossbar_col"]
            for c in range(col_count):
                s_id = core.slaves.synapse(c)
                depth = core.slaves.get(s_id).depth_words
                packed_data = core.dma_read(slave=s_id, count=depth, bram_addr=0)
                weights_only = (packed_data >> 8).astype(np.int8)
                checkpoint[f"syn_col_{c}"] = weights_only
        else:
            for idx, p in enumerate(self.projections):
                checkpoint[f"proj_{idx}_{p.name}_weights"] = p.weights

        np.savez_compressed(filepath, **checkpoint)
        print(f"[CHECKPOINT] Network state saved successfully to '{filepath}'.")

    def load_checkpoint(self, filepath: str, core=None):
        data = np.load(filepath)
        if core is not None:
            print("[CHECKPOINT] Loading weights from disk and writing to PL BRAM via DMA...")
            col_count = core.hw_info["crossbar_col"]
            for c in range(col_count):
                key = f"syn_col_{c}"
                if key in data:
                    s_id = core.slaves.synapse(c)
                    w_raw = data[key]
                    packed = ((w_raw.astype(np.uint16) & 0xFF) << 8) | 0x7F
                    core.dma_write(slave=s_id, data=packed, bram_addr=0)
        else:
            for idx, p in enumerate(self.projections):
                key = f"proj_{idx}_{p.name}_weights"
                if key in data:
                    p.weights = data[key]
        print(f"[CHECKPOINT] Network state loaded successfully from '{filepath}'.")

    def summary(self):
        print("\n" + "="*125)
        print(f"{'Layer (Target)':<16} | {'Target Pin':<12} | {'Source':<16} | {'Synapses':<10} | {'Learning':<12} | {'Q_syn':<8} | {'Scheme [Wmin..Wmax]':<22}")
        print("="*125)
        total_synapses = 0
        total_neurons = sum(l.size for l in self.layers)

        for l in self.layers:
            for p in l.projections:
                syn_count = p.weights.shape[0] * p.weights.shape[1]
                total_synapses += syn_count
                if isinstance(p.source, str):
                    src_name = f"Input {p.input_slice}"
                else:
                    src_name = p.source.name
                learn_str = f"ON (η={p.learning_rate})" if p.learning else "OFF (Frozen)"
                scheme_str = f"{p.scheme} [{p.w_min:.1f}..{p.w_max:.1f}]"
                print(f"{l.name:<16} | {p.target_pin:<12} | {src_name:<16} | {syn_count:<10} | {learn_str:<12} | {p.q_factor:<8.4f} | {scheme_str:<22}")

        print("="*125)
        print(f"Total Neurons        : {total_neurons}")
        print(f"Total Synapses       : {total_synapses}")
        if self.encoder:
            print(f"D2S Encoder Mode     : {self.encoder.mode.upper()} (Time Window: {self.encoder.time_window} Timesteps)")
        print("="*125 + "\n")