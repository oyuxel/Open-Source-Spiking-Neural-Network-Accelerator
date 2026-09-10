# ossna/dma.py

import time
import numpy as np
from pynq import allocate
from .registers import Regs, DmaCtrlMask, DmaStatMask
from .slaves import SlaveDescriptor, TargetType, FifoType, AccessType

DEFAULT_DMA_TIMEOUT = 10.0

def _get_dtype(byte_per_word: int):
    if byte_per_word == 1:
        return np.uint8
    elif byte_per_word == 2:
        return np.uint16
    else:
        return np.uint32

class DmaController:
    def __init__(self, driver):
        self.driver = driver

    def soft_reset(self):
        self.driver.set_bits(Regs.ADDR_DMA_CTRL, DmaCtrlMask.RESET_SOFT_MASK)
        self.driver.read32(Regs.ADDR_DMA_CTRL)
        self.driver.clear_bits(Regs.ADDR_DMA_CTRL, DmaCtrlMask.RESET_SOFT_MASK)

    def _resolve_slave(self, slave_id_or_desc) -> SlaveDescriptor:
        if isinstance(slave_id_or_desc, SlaveDescriptor):
            return slave_id_or_desc
        if not hasattr(self.driver, "slaves") or self.driver.slaves is None:
            raise RuntimeError("Slave registry is not initialized! Call 'core.autorecognize()' first.")
        return self.driver.slaves.get(int(slave_id_or_desc))

    def write(self, slave, data, bram_addr: int = 0, timeout_sec: float = DEFAULT_DMA_TIMEOUT):
        self.soft_reset()

        s = self._resolve_slave(slave)

        if not s.is_writable():
            raise PermissionError(f"[DMA ERROR] Slave {s.id} ({s.name}) is READ-ONLY! Write operation aborted.")

        total_words = len(data)
        if s.target == TargetType.BRAM and s.depth_words > 0:
            if (bram_addr + total_words) > s.depth_words:
                raise OverflowError(
                    f"[DMA ERROR] Data size exceeds BRAM boundary! "
                    f"Target offset: {bram_addr + total_words}, Max depth: {s.depth_words} words."
                )

        target_dtype = _get_dtype(s.byte_per_word)
        is_temp_buffer = False

        if hasattr(data, "device_address"):
            tx_buf = data
        else:
            is_temp_buffer = True
            tx_buf = allocate(shape=(total_words,), dtype=target_dtype)
            tx_buf[:] = data

        ctrl_base = ((int(s.fifo_type.value) << DmaCtrlMask.FIFO_TYPE_SHIFT) & DmaCtrlMask.FIFO_TYPE_MASK) | \
                    ((int(s.target.value) << DmaCtrlMask.TARGET_SELECT_SHIFT) & DmaCtrlMask.TARGET_SELECT_MASK)

        try:
            tx_buf.sync_to_device()
            total_bytes = total_words * s.byte_per_word

            self.driver.write32(Regs.ADDR_SELECT_SLAVE,    s.id)
            self.driver.write32(Regs.ADDR_BYTE_PER_WORD,   s.byte_per_word)
            self.driver.write32(Regs.ADDR_TOTAL_BYTES,     total_bytes)
            self.driver.write32(Regs.ADDR_TOTAL_WORDS,     total_words)
            self.driver.write32(Regs.ADDR_BRAM_READ_DELAY, s.bram_read_delay)
            self.driver.write32(Regs.ADDR_BRAM_BASEADDR,   bram_addr)
            self.driver.write32(Regs.ADDR_DDR_BASEADDR,    tx_buf.device_address)

            self.driver.write32(Regs.ADDR_DMA_CTRL, ctrl_base | DmaCtrlMask.START_READ_MASK)

            start_time = time.time()
            status_val = 0
            while True:
                status_val = self.driver.read32(Regs.ADDR_DMA_STATUS)
                
                if status_val & DmaStatMask.READ_DONE_MASK:
                    break
                    
                if status_val & DmaStatMask.READ_ERR_MASK:
                    raise RuntimeError(f"[DMA ERROR] AXI Read Error on Slave {s.id} ({s.name})! Status=0x{status_val:08X}")
                
                if (time.time() - start_time) > timeout_sec:
                    raise TimeoutError(
                        f"[DMA TIMEOUT] Write to Slave {s.id} ({s.name}) exceeded {timeout_sec}s! "
                        f"Hardware did not assert DONE. Status=0x{status_val:08X}"
                    )

        finally:
            self.driver.write32(Regs.ADDR_DMA_CTRL, ctrl_base)
            if is_temp_buffer:
                tx_buf.close()

    def read(self, slave, count: int, bram_addr: int = 0, timeout_sec: float = DEFAULT_DMA_TIMEOUT) -> np.ndarray:
        self.soft_reset()

        s = self._resolve_slave(slave)

        if not s.is_readable():
            raise PermissionError(f"[DMA ERROR] Slave {s.id} ({s.name}) is WRITE-ONLY! Read operation aborted.")

        total_words = int(count)
        total_bytes = total_words * s.byte_per_word
        target_dtype = _get_dtype(s.byte_per_word)

        rx_buf = allocate(shape=(total_words,), dtype=target_dtype)

        ctrl_base = ((int(s.fifo_type.value) << DmaCtrlMask.FIFO_TYPE_SHIFT) & DmaCtrlMask.FIFO_TYPE_MASK) | \
                    ((int(s.target.value) << DmaCtrlMask.TARGET_SELECT_SHIFT) & DmaCtrlMask.TARGET_SELECT_MASK)

        try:
            self.driver.write32(Regs.ADDR_SELECT_SLAVE,    s.id)
            self.driver.write32(Regs.ADDR_BYTE_PER_WORD,   s.byte_per_word)
            self.driver.write32(Regs.ADDR_TOTAL_BYTES,     total_bytes)
            self.driver.write32(Regs.ADDR_TOTAL_WORDS,     total_words)
            self.driver.write32(Regs.ADDR_BRAM_READ_DELAY, s.bram_read_delay)
            self.driver.write32(Regs.ADDR_BRAM_BASEADDR,   bram_addr)
            self.driver.write32(Regs.ADDR_DDR_BASEADDR,    rx_buf.device_address)

            self.driver.write32(Regs.ADDR_DMA_CTRL, ctrl_base | DmaCtrlMask.START_WRITE_MASK)

            start_time = time.time()
            status_val = 0
            while True:
                status_val = self.driver.read32(Regs.ADDR_DMA_STATUS)
                
                if status_val & DmaStatMask.WRITE_DONE_MASK:
                    break
                    
                if status_val & DmaStatMask.WRITE_ERR_MASK:
                    raise RuntimeError(f"[DMA ERROR] AXI Write Error on Slave {s.id} ({s.name})! Status=0x{status_val:08X}")
                
                if (time.time() - start_time) > timeout_sec:
                    raise TimeoutError(
                        f"[DMA TIMEOUT] Read from Slave {s.id} ({s.name}) exceeded {timeout_sec}s! "
                        f"Hardware did not assert DONE. Status=0x{status_val:08X}"
                    )

            rx_buf.sync_from_device()
            result_data = np.copy(rx_buf)
            return result_data

        finally:
            self.driver.write32(Regs.ADDR_DMA_CTRL, ctrl_base)
            rx_buf.close()