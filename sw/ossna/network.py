# ossna/network.py

import math
import numpy as np
from typing import Union, List, Dict, Optional

# =============================================================================
# 1. INPUT ENCODER (D2S ENCODER & INTERMEDIATE REPRESENTATION)
# =============================================================================
class InputEncoder:
    """
    Encodes raw normalized inputs into the UINT32 Intermediate Representation (IR)
    required by the hardware Data-to-Spike (D2S) engine.
    """
    def __init__(self, mode: str = "poisson", time_window: int = 100, seed: int = 0x12345678, data_count: int = None):
        self.mode = mode.lower()
        if self.mode not in ["poisson", "latency"]:
            raise ValueError(f"Unsupported D2S mode '{mode}'! Allowed modes are 'poisson' or 'latency'.")
        self.time_window = int(time_window)
        self.seed = int(seed)
        self.data_count = data_count

    def encode(self, raw_features: np.ndarray) -> np.ndarray:
        """
        Converts normalized features in [0.0, 1.0] into a UINT32 IR stream for D2S.
        """
        features = np.clip(np.array(raw_features, dtype=np.float64), 0.0, 1.0)
        
        if self.mode == "poisson":
            ir_values = np.round(features * 0xFFFFFFFF)
            return ir_values.astype(np.uint32)
            
        elif self.mode == "latency":
            step_timings = np.round((1.0 - features) * (self.time_window - 1))
            ir_values = np.clip(step_timings, 0, self.time_window - 1)
            return ir_values.astype(np.uint32)


# =============================================================================
# 2. LAYER REPRESENTATION (ULEARN Parametreleri Entegre Edildi)
# =============================================================================
class Layer:
    """Represents a neuron population and its incoming synaptic projection."""
    def __init__(self, name: str, size: int, input_size: int,
                 neuron_model, synapse_model,
                 weights: np.ndarray, w_min: int = 0, w_max: int = 127,
                 lateral_inhibition: bool = False, lateral_weight: int = -120,
                 learning: bool = True, learning_rate: float = 0.05,
                 pruning: bool = False, pruning_threshold: Optional[float] = None,
                 ignore_zero_synapses: bool = True,
                 connectivity: Union[str, float] = "dense"):
        self.name = name
        self.size = size
        self.input_size = input_size
        self.neuron_model = neuron_model
        self.synapse_model = synapse_model
        self.weights = weights
        self.w_min = w_min
        self.w_max = w_max
        self.lateral_inhibition = lateral_inhibition
        self.lateral_weight = lateral_weight
        self.learning = learning
        self.learning_rate = float(learning_rate)
        # Eşik verilmişse budama otomatik açılır
        self.pruning = pruning or (pruning_threshold is not None)
        self.pruning_threshold = pruning_threshold
        self.ignore_zero_synapses = ignore_zero_synapses
        self.connectivity = connectivity


# =============================================================================
# 3. NETWORK CLASS
# =============================================================================
class Network:
    """
    SNN Network Topology Definition for the OSSNA Hardware Architecture.
    Does not compile; holds the pure network topology and parameters.
    """
    def __init__(self, input_size: int):
        self.input_size = int(input_size)
        self.layers: List[Layer] = []
        self.encoder: Optional[InputEncoder] = None

    # -------------------------------------------------------------------------
    # Feature 5: Input Encoding Setup (D2S Engine Integration)
    # -------------------------------------------------------------------------
    def set_input_encoder(self, mode: str = "poisson", time_window: int = 100, seed: int = 0x12345678):
        self.encoder = InputEncoder(mode=mode, time_window=time_window, seed=seed, data_count=self.input_size)

    # -------------------------------------------------------------------------
    # Features 2 & 3: Weight Initializers & Sparsity
    # -------------------------------------------------------------------------
    def _create_weights(self, in_size: int, out_size: int, init_method, w_min: int, w_max: int, connectivity) -> np.ndarray:
        if isinstance(init_method, np.ndarray):
            if init_method.shape != (in_size, out_size):
                raise ValueError(f"Weight matrix shape mismatch! Expected: ({in_size}, {out_size}), Got: {init_method.shape}")
            W = np.copy(init_method).astype(np.float64)
        elif init_method in ["uniform", "random"]:
            W = np.random.uniform(w_min, w_max, size=(in_size, out_size))
        elif init_method == "normal":
            mid = (w_max + w_min) / 2.0
            std = max(1.0, (w_max - w_min) / 6.0)
            W = np.random.normal(mid, std, size=(in_size, out_size))
        elif init_method == "xavier":
            scale = np.sqrt(2.0 / (in_size + out_size)) * (w_max - w_min)
            W = np.random.uniform(w_min, min(w_max, w_min + scale), size=(in_size, out_size))
        elif isinstance(init_method, (int, float)):
            W = np.full((in_size, out_size), float(init_method), dtype=np.float64)
        else:
            raise ValueError(f"Unknown weight initialization method '{init_method}'")

        W = np.clip(np.round(W), w_min, w_max)

        # Sparse Connectivity -> Unconnected synapses are strictly 0!
        if isinstance(connectivity, (int, float)) and 0.0 < connectivity < 1.0:
            mask = np.random.rand(in_size, out_size) < connectivity
            W = W * mask

        return W.astype(np.int32)

    # -------------------------------------------------------------------------
    # Layer Construction (ULEARN Parametreleri Eklendi)
    # -------------------------------------------------------------------------
    def add_layer(self, name: str, size: int, neuron_model, synapse_model=None,
                  weights: Union[str, float, np.ndarray] = "uniform",
                  w_min: int = 0, w_max: int = 127,
                  lateral_inhibition: bool = False, lateral_weight: int = -120,
                  learning: bool = True, learning_rate: float = 0.05,
                  pruning: bool = False, pruning_threshold: Optional[float] = None,
                  ignore_zero_synapses: bool = True,
                  connectivity: Union[str, float] = "dense") -> Layer:
        
        current_input_size = self.input_size if len(self.layers) == 0 else self.layers[-1].size

        weight_matrix = self._create_weights(current_input_size, size, weights, w_min, w_max, connectivity)

        layer = Layer(
            name=name,
            size=size,
            input_size=current_input_size,
            neuron_model=neuron_model,
            synapse_model=synapse_model,
            weights=weight_matrix,
            w_min=w_min,
            w_max=w_max,
            lateral_inhibition=lateral_inhibition,
            lateral_weight=lateral_weight,
            learning=learning,
            learning_rate=learning_rate,
            pruning=pruning,
            pruning_threshold=pruning_threshold,
            ignore_zero_synapses=ignore_zero_synapses,
            connectivity=connectivity
        )
        self.layers.append(layer)
        return layer

    # -------------------------------------------------------------------------
    # Feature 1: Hardware Pre-Validation
    # -------------------------------------------------------------------------
    def validate_hardware(self, core_or_hw_info) -> bool:
        hw_info = core_or_hw_info.hw_info if hasattr(core_or_hw_info, "hw_info") else core_or_hw_info

        max_neurons = hw_info["max_supported_neurons"]
        crossbar_cols = hw_info["crossbar_col"]
        words_per_syn_col = hw_info["total_synapse_mem_words"] // crossbar_cols

        total_neurons = sum(l.size for l in self.layers)
        if total_neurons > max_neurons:
            raise ValueError(f"[HARDWARE ERROR] Total network neurons ({total_neurons}) exceeds hardware limit ({max_neurons})!")

        for l in self.layers:
            k_virtual = math.ceil(l.size / crossbar_cols)
            synapses_needed = k_virtual * l.input_size

            if synapses_needed > words_per_syn_col:
                raise OverflowError(
                    f"[HARDWARE ERROR] Layer '{l.name}' requires {synapses_needed} synapses per column, "
                    f"but hardware column depth is {words_per_syn_col} words!"
                )

        print("[VALIDATION OK] Network topology is 100% compatible with hardware constraints!")
        return True

    # -------------------------------------------------------------------------
    # Feature 4: Checkpointing
    # -------------------------------------------------------------------------
    def save_checkpoint(self, filepath: str, core=None):
        checkpoint = {}
        if core is not None:
            print("[CHECKPOINT] Pulling live weights from hardware BRAM via DMA...")
            col_count = core.hw_info["crossbar_col"]
            for c in range(col_count):
                s_id = core.slaves.synapse(c)
                depth = core.slaves.get(s_id).depth_words
                checkpoint[f"syn_col_{c}"] = core.dma_read(slave=s_id, count=depth, bram_addr=0)
        else:
            for idx, l in enumerate(self.layers):
                checkpoint[f"layer_{idx}_{l.name}_weights"] = l.weights

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
                    weights_chunk = data[key]
                    core.dma_write(slave=s_id, data=weights_chunk, bram_addr=0)
        else:
            for idx, l in enumerate(self.layers):
                key = f"layer_{idx}_{l.name}_weights"
                if key in data:
                    l.weights = data[key]
        print(f"[CHECKPOINT] Network state loaded successfully from '{filepath}'.")

    # -------------------------------------------------------------------------
    # Feature 6: Architectural Summary Report
    # -------------------------------------------------------------------------
    def summary(self):
        print("\n" + "="*105)
        print(f"{'Layer Name':<18} | {'Input':<8} | {'Neurons':<8} | {'Synapses':<12} | {'Learning':<14} | {'Lateral Inh':<14} | {'Density':<10}")
        print("="*105)
        total_synapses = 0
        total_neurons = sum(l.size for l in self.layers)

        for l in self.layers:
            syn_count = l.input_size * l.size
            total_synapses += syn_count
            learning_str = f"ON (η={l.learning_rate})" if l.learning and l.synapse_model is not None else "OFF"
            lat_str = f"YES ({l.lateral_weight})" if l.lateral_inhibition else "NO"
            conn_str = f"Sparse({l.connectivity})" if isinstance(l.connectivity, float) else "Dense"

            print(f"{l.name:<18} | {l.input_size:<8} | {l.size:<8} | {syn_count:<12} | {learning_str:<14} | {lat_str:<14} | {conn_str:<10}")

        print("="*105)
        print(f"Total Neurons        : {total_neurons}")
        print(f"Total Synapses       : {total_synapses}")
        if self.encoder:
            print(f"D2S Encoder Mode     : {self.encoder.mode.upper()} (Time Window: {self.encoder.time_window} Timesteps)")
        print("="*105 + "\n")