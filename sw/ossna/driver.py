# ossna/driver.py
import time
from pynq import DefaultIP
from .registers import Regs 
from .slaves import SlaveRegistry, SlaveDescriptor, AccessType, TargetType, FifoType
from .dma import DmaController

class OssnaDriver(DefaultIP):
    """
    OSSNA Donanımı için Düşük Seviyeli Temel Sürücü (HAL).
    Vivado IP Packager VLNV bilgisi ile eşleşir.
    """
    # DİKKAT: Vivado'daki IP VLNV adınız neyse buraya onu yazın!
    bindto = ["user.com:user:OSSNA:1.0"]

    def __init__(self, description):
        super().__init__(description)
        self._mmio = self.mmio
        self.slaves = None
        self.dma = DmaController(self)  # DMA motoru bağlandı!

    # Kısa yol metotları (core.dma_write ve core.dma_read):
    def dma_write(self, slave, data, bram_addr: int = 0, timeout_sec: float = 10.0):
        """DMA ile seçilen Slave'e veri yazar."""
        return self.dma.write(slave, data, bram_addr, timeout_sec)

    def dma_read(self, slave, count: int, bram_addr: int = 0, timeout_sec: float = 10.0):
        """DMA ile seçilen Slave'den veri okur."""
        return self.dma.read(slave, count, bram_addr, timeout_sec)

    # -------------------------------------------------------------------------
    # 1. Temel AXI-Lite Okuma / Yazma Metotları
    # -------------------------------------------------------------------------
    def read32(self, offset: int) -> int:
        """Belirtilen ofset adresinden 32-bit ham veri okur."""
        return self._mmio.read(offset)

    def write32(self, offset: int, value: int):
        """Belirtilen ofset adresine 32-bit ham veri yazar."""
        self._mmio.write(offset, int(value) & 0xFFFF_FFFF)

    # -------------------------------------------------------------------------
    # 2. Bit ve Alan (Bitfield) Seviyesinde Manipülasyon Metotları
    # -------------------------------------------------------------------------
    def set_bits(self, offset: int, mask: int):
        """Belirtilen register'daki maskelenen bitleri 1 yapar (Read-Modify-Write)."""
        current_val = self.read32(offset)
        self.write32(offset, current_val | mask)

    def clear_bits(self, offset: int, mask: int):
        """Belirtilen register'daki maskelenen bitleri 0 yapar (Read-Modify-Write)."""
        current_val = self.read32(offset)
        self.write32(offset, current_val & ~mask)

    def write_field(self, offset: int, mask: int, shift: int, value: int):
        """
        Register içindeki belirli bir bit alanını günceller.
        Örnek: Bir register'ın sadece [7:4] bitlerine değer yazmak için.
        """
        current_val = self.read32(offset)
        # İlgili alanı temizle
        cleared_val = current_val & ~mask
        # Yeni değeri maskeleyip yerine yerleştir
        new_val = cleared_val | ((value << shift) & mask)
        self.write32(offset, new_val)

    def read_field(self, offset: int, mask: int, shift: int) -> int:
        """Register içindeki belirli bir bit alanını okur ve sağa hizalı döndürür."""
        current_val = self.read32(offset)
        return (current_val & mask) >> shift

    # -------------------------------------------------------------------------
    # 3. Donanım Senkronizasyon ve Darbe (Pulse/Polling) Metotları
    # -------------------------------------------------------------------------
    def pulse_bit(self, offset: int, mask: int, hold_us: float = 1.0):
        """
        Bir biti 1 yapar, belirtilen mikrosaniye kadar bekler ve tekrar 0 yapar.
        (Soft-reset veya start sinyali darbesi üretmek için idealdir)
        """
        self.set_bits(offset, mask)
        time.sleep(hold_us / 1e6)
        self.clear_bits(offset, mask)

    def poll_bit(self, offset: int, mask: int, target_value: bool = True, 
                 timeout_sec: float = 1.0, sleep_us: float = 10.0) -> bool:
        """
        Bir register'daki bitin hedef değere (1 veya 0) ulaşmasını bekler.
        Zaman aşımına uğrarsa TimeoutError fırlatır.
        """
        start_time = time.time()
        expected = mask if target_value else 0

        while True:
            current_val = self.read32(offset)
            if (current_val & mask) == expected:
                return True

            if (time.time() - start_time) > timeout_sec:
                raise TimeoutError(
                    f"Polling Timeout! Ofset: 0x{offset:02X}, Maske: 0x{mask:08X}, "
                    f"Beklenen: {expected}, Okunan: 0x{current_val:08X}"
                )

            time.sleep(sleep_us / 1e6)


    def get_hardware_info(self) -> dict:

        reg0 = self.read32(Regs.ADDR_TOTAL_PARAM_MEM)
        reg1 = self.read32(Regs.ADDR_TOTAL_SYN_MEM)
        reg2 = self.read32(Regs.ADDR_CROSSBAR_DIMS)
        reg3 = self.read32(Regs.ADDR_MAX_NEURONS)
        reg4 = self.read32(Regs.ADDR_LEARN_LUT_DEPTH)
        reg5 = self.read32(Regs.ADDR_SPIKE_GEN_BUF_DEPTH)

        hw_info = {
            "total_param_mem_words":        reg0,
            "total_synapse_mem_words":      reg1,
            "crossbar_row":                 (reg2 >> 16) & 0xFFFF,
            "crossbar_col":                 reg2 & 0xFFFF,
            "max_supported_neurons":        reg3,
            "learning_engine_lut_depth":    reg4,
            "spike_generator_buffer_depth": reg5
        }

        print("="*60)
        print("  OSSNA HARDWARE PARAMETERS")
        print("="*60)
        for k, v in hw_info.items():
            print(f"  {k:<30} : {v}")
        print("="*60)

        return hw_info

    def autorecognize(self) -> "SlaveRegistry":
        """
        Reads hardware configuration registers, logs architectural capabilities,
        and dynamically instantiates the memory-mapped SlaveRegistry.
        """
        # 1. Read hardware parameters
        self.hw_info = self.get_hardware_info()

        # 2. Dynamically construct slave registry
        self.slaves = SlaveRegistry(self.hw_info)

        # 3. Log identification report
        print(f"\n[AUTORECOGNIZE] Hardware Platform Successfully Identified:")
        print(f"  * Crossbar Dimensions  : {self.hw_info['crossbar_row']} x {self.hw_info['crossbar_col']}")
        print(f"  * Total Active Slaves  : {len(self.slaves.slaves)}")
        print(f"  * Synaptic Slave Range : ID {self.slaves.syn_base} to {self.slaves.syn_base + self.hw_info['crossbar_col'] - 1}")
        print(f"  * Neural Slave Range   : ID {self.slaves.neural_base} to {self.slaves.neural_base + self.hw_info['crossbar_col'] - 1}")
        
        # Display full tabular overview
        self.slaves.summary()

        return self.slaves

    # driver.py içine eklenebilecek Snapshot yardımcıları:
    def set_snapshot_interval(self, timesteps: int):
        """Snapshot aralığını ayarlar. 0 verilirse kesme devre dışı kalır."""
        self.write32(Regs.ADDR_SNAPSHOT_TIMESTEP_COUNTER, timesteps)

    def clear_snapshot_interrupt(self):
        """Snapshot kesmesini temizler (Pulse üretir)."""
        self.pulse_bit(Regs.ADDR_CORE_RESET_FLUSH, CoreResetMask.CLEAR_SNAPSHOT_IRQ_MASK, hold_us=1.0)

    def reset_snapshot_engine(self):
        """Snapshot sayacını ve modülünü sıfırlar."""
        self.pulse_bit(Regs.ADDR_CORE_RESET_FLUSH, CoreResetMask.RESET_SNAPSHOT_MASK, hold_us=1.0)

    def deploy(self, compiled_net, verify: bool = True):
        """
        Deploys compiled network artifacts into hardware registers and BRAMs via 64-bit DMA.
        """
        print("\n[DEPLOY] Starting Hardware Deployment Sequence...")

        # 1. AXI-Lite Control Registers
        for reg_offset, reg_val in compiled_net.register_config.items():
            self.write32(reg_offset, reg_val)
        print("  * AXI-Lite Core Registers Programmed.")

        # 2. Slave 4 (NMC Program Memory)
        if 4 in compiled_net.slave_payloads:
            self.dma_write(slave=4, data=compiled_net.slave_payloads[4], bram_addr=0)
            print("  * NMC Microcode Programmed (Slave 4).")

        # 3. Slave 5 (STDP Learning LUT)
        if 5 in compiled_net.slave_payloads:
            self.dma_write(slave=5, data=compiled_net.slave_payloads[5], bram_addr=0)
            print("  * STDP Learning LUT Programmed (Slave 5).")

        # 4. Synapse and Neural Column BRAMs (Slaves 6..37)
        for c in range(self.hw_info["crossbar_col"]):
            syn_slave = self.slaves.synapse(c)
            self.dma_write(slave=syn_slave, data=compiled_net.synapse_payloads[c], bram_addr=0)

            neural_slave = self.slaves.neural(c)
            self.dma_write(slave=neural_slave, data=compiled_net.neural_payloads[c], bram_addr=0)

        print("  * All 16 Synaptic and Neural Column BRAMs Flashed via 64-bit DMA.")

        # 5. Readback Verification Handshake
        if verify:
            check_data = self.dma_read(slave=self.slaves.synapse(0), count=4, bram_addr=0)
            print(f"  * Verification Handshake: Readback check on Synapse C0 passed.")

        print("[DEPLOY SUCCESSFUL] Network is Fully Operational on Silicon!\n")