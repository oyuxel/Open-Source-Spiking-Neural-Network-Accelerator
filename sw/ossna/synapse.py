# ossna/synapse.py

import math
import numpy as np

class Synapse:
    """
    STDP (Spike-Timing-Dependent Plasticity) Model Tanımı.
    """
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
    """
    Synapse modelini 8-bit kuantalar ve BRAM adres sırasına (0..255) dizilmiş
    128 LTP + 128 LTD olmak üzere 256 baytlık donanım tablosu üretir.
    """
    def __init__(self, synapse: Synapse):
        self.synapse = synapse
        self.lut_table = None
        self._natural_curve = None
        self._time_axis = None

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

    def compile(self) -> np.ndarray:
        half_samples = self.synapse.samples // 2  # 128 LTP, 128 LTD

        # 1. Zaman uzaylarını oluştur
        lhs_time = np.linspace(-self.synapse.time_window_left, self.synapse.zero_point, half_samples)
        rhs_time = np.linspace(self.synapse.zero_point, self.synapse.time_window_right, half_samples)

        # 2. Denklemleri hesapla (LTP ve LTD)
        lhs_vals = self._evaluate_expression(self.synapse.on_pre, lhs_time)
        rhs_vals = self._evaluate_expression(self.synapse.on_post, rhs_time)

        # 3. Kuantalama (INT8: [-128, 127])
        q_factor = 2.0 / 256.0
        lhs_int8 = np.clip(np.round(lhs_vals / q_factor), -128, 127).astype(np.int8)
        rhs_int8 = np.clip(np.round(rhs_vals / q_factor), -128, 127).astype(np.int8)

        # Zaman grafiği için saf (doğal) eğri:
        self._time_axis = np.concatenate((lhs_time * 1e3, rhs_time * 1e3))
        self._natural_curve = np.concatenate((lhs_int8, rhs_int8))

        # 4. BRAM Donanım Adres Sıralaması:
        # BRAM Adres 0..127 (LTP): t=0 noktasından t=-50ms'ye doğru geriye sıralı
        # BRAM Adres 128..255 (LTD): t=0 noktasından t=+50ms'ye doğru ileriye sıralı
        bram_ltp = np.flip(lhs_int8) # Adres 0: t=0 (Tepe noktası)
        bram_ltd = rhs_int8         # Adres 128: t=0 (Tepe noktası)

        bram_ordered = np.concatenate((bram_ltp, bram_ltd))
        self.lut_table = bram_ordered.astype(np.uint8)

        print(f"[SYNAPSE COMPILER] STDP LUT Generated Successfully:")
        print(f"  * Total Samples      : {len(self.lut_table)} (128 LTP, 128 LTD)")
        print(f"  * Address 0..127     : LTP (Starts at peak Δt=0 -> decays to Δt=-50ms)")
        print(f"  * Address 128..255   : LTD (Starts at peak Δt=0 -> decays to Δt=+50ms)")

        return self.lut_table

    def plot(self):
        """İki ayrı grafik çizer: 1) Zamansal STDP Eğrisi, 2) Donanım BRAM Adres Haritası"""
        try:
            import matplotlib.pyplot as plt
            if self.lut_table is None:
                self.compile()

            bram_int8 = self.lut_table.astype(np.int8)
            addresses = np.arange(256)

            fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 5))

            # --- GRAFİK 1: Zamansal Öğrenme Penceresi ---
            ax1.plot(self._time_axis, self._natural_curve, 'b.-', label="STDP Response")
            ax1.axvline(0, color='k', linestyle='--', alpha=0.7)
            ax1.axhline(0, color='k', linestyle='--', alpha=0.7)
            ax1.grid(True)
            ax1.set_xlabel(r"$\Delta t = t_{post} - t_{pre}$ (ms)")
            ax1.set_ylabel("Weight Change ($\Delta w$) [INT8]")
            ax1.set_title("1. Physical Time-Domain Learning Window\n(Strongest change near Δt=0)")
            ax1.legend()

            # --- GRAFİK 2: Donanım BRAM Adres Uzayı (0..255) ---
            ax2.plot(addresses[:128], bram_int8[:128], 'g.-', label="LTP Region (Addr 0..127)")
            ax2.plot(addresses[128:], bram_int8[128:], 'r.-', label="LTD Region (Addr 128..255)")
            ax2.axvline(127.5, color='k', linestyle='--', alpha=0.8, label="LTP / LTD Boundary")
            ax2.axhline(0, color='k', linestyle='--', alpha=0.5)
            ax2.grid(True)
            ax2.set_xlabel("BRAM LUT Address (0 to 255)")
            ax2.set_ylabel("Stored Coefficient [INT8]")
            ax2.set_title("2. Hardware BRAM Address Space (Slave 5 LUT)\n(128 LTP + 128 LTD Samples)")
            ax2.legend()

            plt.tight_layout()
            plt.show()
        except ImportError:
            print("Matplotlib not found.")