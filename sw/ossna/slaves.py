# ossna/slaves.py
from enum import Enum
from typing import Dict

class AccessType(Enum):
    WRITE_ONLY = "WO"  # DDR -> HW
    READ_ONLY  = "RO"  # HW -> DDR
    READ_WRITE = "RW"  # İki yönlü

class TargetType(Enum):
    BRAM = 0
    FIFO = 1

class FifoType(Enum):
    STANDARD = 0
    FWFT     = 1

class SlaveDescriptor:
    def __init__(self, slave_id: int, name: str, target: TargetType, 
                 access: AccessType, data_width: int, depth_words: int, 
                 bram_read_delay: int = 0, fifo_type: FifoType = FifoType.STANDARD):
        self.id = slave_id
        self.name = name
        self.target = target
        self.access = access
        self.data_width = data_width
        self.depth_words = depth_words
        self.bram_read_delay = bram_read_delay
        self.fifo_type = fifo_type

    @property
    def byte_per_word(self) -> int:
        """DMA ADDR_BYTE_PER_WORD registerı için bayt hesabı"""
        return max(1, (self.data_width + 7) // 8)

    def is_writable(self) -> bool:
        return self.access in (AccessType.WRITE_ONLY, AccessType.READ_WRITE)

    def is_readable(self) -> bool:
        return self.access in (AccessType.READ_ONLY, AccessType.READ_WRITE)


class SlaveRegistry:
    """Donanım özelliklerine göre dinamik olarak inşa edilen Slave Yöneticisi"""
    def __init__(self, hw_info: dict):
        self.hw_info = hw_info
        self.slaves: Dict[int, SlaveDescriptor] = {}
        self.syn_base = 6
        self.neural_base = 6 + self.hw_info["crossbar_col"]
        self._build_registry()

    def _build_registry(self):
        c_row = self.hw_info["crossbar_row"]
        c_col = self.hw_info["crossbar_col"]
        total_syn = self.hw_info["total_synapse_mem_words"]
        total_param = self.hw_info["total_param_mem_words"]
        lut_depth = self.hw_info["learning_engine_lut_depth"]

        # -------------------------------------------------------------
        # 1. SABİT SLAVELER (0 - 5)
        # -------------------------------------------------------------
        self.register(SlaveDescriptor(0, "D2S_CONVERTER", TargetType.FIFO, AccessType.WRITE_ONLY, 32, 0, fifo_type=FifoType.FWFT))
        self.register(SlaveDescriptor(1, "INPUT_SPIKE_BUF", TargetType.FIFO, AccessType.WRITE_ONLY, c_row, 0, fifo_type=FifoType.FWFT))
        self.register(SlaveDescriptor(2, "AUX_SPIKE_BUF", TargetType.FIFO, AccessType.WRITE_ONLY, c_row, 0, fifo_type=FifoType.FWFT))
        self.register(SlaveDescriptor(3, "OUTPUT_SPIKE_BUF", TargetType.FIFO, AccessType.READ_ONLY, c_row, 0, fifo_type=FifoType.FWFT))
        self.register(SlaveDescriptor(4, "NMC_PROG_MEM", TargetType.BRAM, AccessType.WRITE_ONLY, 16, 1024))
        self.register(SlaveDescriptor(5, "LEARNING_LUT", TargetType.BRAM, AccessType.WRITE_ONLY, 8, lut_depth))

        # -------------------------------------------------------------
        # 2. DİNAMİK SYNAPTIC MEMORIES (6 -> 6 + crossbar_col - 1)
        # -------------------------------------------------------------
        syn_depth = total_syn // c_col
        for c in range(c_col):
            s_id = self.syn_base + c
            self.register(SlaveDescriptor(
                slave_id=s_id,
                name=f"SYNAPSE_MEM_C{c}",
                target=TargetType.BRAM,
                access=AccessType.READ_WRITE,
                data_width=16,
                depth_words=syn_depth,
                bram_read_delay=1
            ))

        # -------------------------------------------------------------
        # 3. DİNAMİK NEURAL MEMORIES (6 + crossbar_col -> 6 + 2*crossbar_col - 1)
        # -------------------------------------------------------------
        param_depth = total_param // c_col
        for c in range(c_col):
            s_id = self.neural_base + c
            self.register(SlaveDescriptor(
                slave_id=s_id,
                name=f"NEURAL_MEM_C{c}",
                target=TargetType.BRAM,
                access=AccessType.READ_WRITE,
                data_width=32,
                depth_words=param_depth,
                bram_read_delay=1
            ))

    def register(self, desc: SlaveDescriptor):
        self.slaves[desc.id] = desc

    def get(self, slave_id: int) -> SlaveDescriptor:
        if slave_id not in self.slaves:
            raise KeyError(f"Tanımsız Slave ID: {slave_id}!")
        return self.slaves[slave_id]

    def synapse(self, col: int) -> int:
        """Sütun numarası verilen sinaps belleğinin slave ID'sini döndürür"""
        if not (0 <= col < self.hw_info["crossbar_col"]):
            raise IndexError(f"Geçersiz Synapse sütunu {col}! Sınır: 0-{self.hw_info['crossbar_col']-1}")
        return self.syn_base + col

    def neural(self, col: int) -> int:
        """Sütun numarası verilen nöron belleğinin slave ID'sini döndürür"""
        if not (0 <= col < self.hw_info["crossbar_col"]):
            raise IndexError(f"Geçersiz Neural sütunu {col}! Sınır: 0-{self.hw_info['crossbar_col']-1}")
        return self.neural_base + col

    def summary(self):
        """Prints a structured summary table of all registered memory-mapped slaves."""
        print("\n" + "="*85)
        print(f"{'ID':<4} | {'Slave Name':<18} | {'Target':<6} | {'Access':<6} | {'Width':<10} | {'Depth':<10} | {'Delay':<7}")
        print("="*85)
        for s_id in sorted(self.slaves.keys()):
            s = self.slaves[s_id]
            depth_str = str(s.depth_words) if s.depth_words > 0 else "FIFO"
            print(f"{s.id:<4} | {s.name:<18} | {s.target.name:<6} | {s.access.value:<6} | {s.data_width:<3}-bit    | {depth_str:<10} | {s.bram_read_delay} cycle")
        print("="*85)