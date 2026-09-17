# ossna/synapse.py

import math
import numpy as np
from typing import Optional

class Synapse:

    def __init__(self, on_pre: str = None, on_post: str = None,
                 time_window_left: float = 50e-3, 
                 time_window_right: float = 50e-3, 
                 zero_point: float = 0.0, 
                 samples: int = 256):
        self.on_pre = on_pre if on_pre else "0.6*exp(t/50e-3)"
        self.on_post = on_post if on_post else "-0.6*exp(-t/50e-3)"
        self.time_window_left = time_window_left
        self.time_window_right = time_window_right
        self.zero_point = zero_point
        self.samples = samples


class SynapseCompiler:

    def __init__(self, synapse: Synapse):
        self.synapse = synapse
        self.lut_table = None
        self._natural_curve = None
        self._time_axis = None
        self.q_factor = None

    def _evaluate_expression(self, expr_str: str, t_values: np.ndarray) -> np.ndarray:
        safe_dict = {
            "t": t_values,
            "exp": np.exp,
            "sin": np.sin,
            "cos": np.cos,
            "abs": np.abs,
            "pi": np.pi,
            "e": np.e
        }
        try:
            result = eval(expr_str, {"__builtins__": None}, safe_dict)
            return np.array(result, dtype=np.float64)
        except Exception as e:
            raise ValueError(f"Synapse Formula Parsing Error: '{expr_str}' -> {e}")

    def compile(self, q_factor: Optional[float] = None, enforce_zero_point: bool = True) -> np.ndarray:

        half_samples = self.synapse.samples // 2  # 128 LTP, 128 LTD

        self.q_factor = float(q_factor) if q_factor is not None else (2.0 / 256.0)

        lhs_time = np.linspace(-self.synapse.time_window_left, self.synapse.zero_point, half_samples)
        rhs_time = np.linspace(self.synapse.zero_point, self.synapse.time_window_right, half_samples)

        lhs_vals = self._evaluate_expression(self.synapse.on_pre, lhs_time)
        rhs_vals = self._evaluate_expression(self.synapse.on_post, rhs_time)

        lhs_int8 = np.clip(np.round(lhs_vals / self.q_factor), -128, 127).astype(np.int8)
        rhs_int8 = np.clip(np.round(rhs_vals / self.q_factor), -128, 127).astype(np.int8)

        bram_ltp = np.flip(lhs_int8)
        bram_ltd = np.copy(rhs_int8)

        if enforce_zero_point:
            bram_ltp[0] = 0
            bram_ltd[0] = 0

        plot_lhs = np.flip(bram_ltp)
        plot_rhs = np.copy(bram_ltd)
        self._time_axis = np.concatenate((lhs_time * 1e3, rhs_time * 1e3))
        self._natural_curve = np.concatenate((plot_lhs, plot_rhs))

        bram_ordered = np.concatenate((bram_ltp, bram_ltd))
        self.lut_table = bram_ordered.astype(np.uint8)

        min_coeff = int(bram_ordered.astype(np.int8).min())
        max_coeff = int(bram_ordered.astype(np.int8).max())
        print(f"[SYNAPSE COMPILER] STDP LUT Compiled with Q_syn = {self.q_factor:.6f}:")
        print(f"  * Dynamic INT8 Range : Min = {min_coeff}, Max = {max_coeff}")
        print(f"  * Zero-Point (Δt=0)  : BRAM[0] = {bram_ordered[0]} (LTP=0), BRAM[128] = {bram_ordered[128]} (LTD=0)")
        print(f"  * Address Layout     : 128 LTP (Addr 0..127) + 128 LTD (Addr 128..255)")

        return self.lut_table

    def plot(self):
        try:
            import matplotlib.pyplot as plt
            if self.lut_table is None:
                self.compile()

            bram_int8 = self.lut_table.astype(np.int8)
            addresses = np.arange(256)

            fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(15, 5))

            ax1.plot(self._time_axis, self._natural_curve, 'b.-', label="STDP Response")
            ax1.axvline(0, color='k', linestyle='--', alpha=0.7)
            ax1.axhline(0, color='k', linestyle='--', alpha=0.7)
            ax1.grid(True)
            ax1.set_xlabel(r"$\Delta t = t_{post} - t_{pre}$ (ms)")
            ax1.set_ylabel("Weight Change ($\Delta w$) [INT8]")
            ax1.set_title(f"1. Physical Time-Domain Window (Q_syn={self.q_factor:.4f})\n(Zero update at Δt=0 enforced)")
            ax1.legend()

            ax2.plot(addresses[:128], bram_int8[:128], 'g.-', label="LTP Region (Addr 0..127)")
            ax2.plot(addresses[128:], bram_int8[128:], 'r.-', label="LTD Region (Addr 128..255)")
            ax2.axvline(127.5, color='k', linestyle='--', alpha=0.8, label="LTP / LTD Boundary")
            ax2.axhline(0, color='k', linestyle='--', alpha=0.5)
            ax2.grid(True)
            ax2.set_xlabel("BRAM LUT Address (0 to 255)")
            ax2.set_ylabel("Stored Coefficient [INT8]")
            ax2.set_title(f"2. Hardware BRAM Address Space (Slave 5 LUT)\nBRAM[0]=0, BRAM[128]=0")
            ax2.legend()

            plt.tight_layout()
            plt.show()
        except ImportError:
            print("Matplotlib not found.")