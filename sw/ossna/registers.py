# ossna/registers.py

class Regs:
    """Register Adres Ofsetleri (Bayt cinsinden)"""
    # Donanım Konfigürasyon Bilgileri (Read-Only)
    ADDR_TOTAL_PARAM_MEM      = 0x00
    ADDR_TOTAL_SYN_MEM        = 0x04
    ADDR_CROSSBAR_DIMS        = 0x08
    ADDR_MAX_NEURONS          = 0x0C
    ADDR_LEARN_LUT_DEPTH      = 0x10
    ADDR_SPIKE_GEN_BUF_DEPTH  = 0x14

    # DMA Registerları
    ADDR_DMA_CTRL             = 0x18
    ADDR_SELECT_SLAVE         = 0x1C
    ADDR_BYTE_PER_WORD        = 0x20
    ADDR_TOTAL_BYTES          = 0x24
    ADDR_TOTAL_WORDS          = 0x28
    ADDR_BRAM_READ_DELAY      = 0x2C
    ADDR_BRAM_BASEADDR        = 0x30
    ADDR_DDR_BASEADDR         = 0x34
    ADDR_DMA_STATUS           = 0x38

    # D2S (Data-to-Spike) Registerları
    ADDR_D2S_CTRL             = 0x3C
    ADDR_CONVMODE             = 0x3C  # ADDR_D2S_CTRL ile aynı adres
    ADDR_TIME_WIND            = 0x40
    ADDR_SEED                 = 0x44
    ADDR_DATA_COUNT           = 0x48
    ADDR_CONV_STATUS          = 0x4C

    # Çekirdek (Core) Kontrol ve Durum Registerları
    ADDR_NMC_XNEVER           = 0x50
    ADDR_CORE_ROUTING_CFG     = 0x54
    ADDR_NET_START_ADDR       = 0x58
    ADDR_CORE_EXEC_CTRL       = 0x5C
    ADDR_CORE_RESET_FLUSH     = 0x60
    ADDR_CORE_STATUS          = 0x64


class DmaCtrlMask:
    RESET_SOFT_SHIFT          = 0
    RESET_SOFT_MASK           = 0x0000_0001

    START_READ_SHIFT          = 1
    START_READ_MASK           = 0x0000_0002

    START_WRITE_SHIFT         = 2
    START_WRITE_MASK          = 0x0000_0004

    TARGET_SELECT_SHIFT       = 3
    TARGET_SELECT_MASK        = 0x0000_0008

    FIFO_TYPE_SHIFT           = 4
    FIFO_TYPE_MASK            = 0x0000_0010


class DmaStatMask:
    READ_DONE_SHIFT           = 0
    READ_DONE_MASK            = 0x0000_0001

    WRITE_DONE_SHIFT          = 1
    WRITE_DONE_MASK           = 0x0000_0002

    READ_ERR_SHIFT            = 2
    READ_ERR_MASK             = 0x0000_0004

    WRITE_ERR_SHIFT           = 3
    WRITE_ERR_MASK            = 0x0000_0008


class D2SCtrlMask:
    RESET_SHIFT               = 0
    RESET_MASK                = 0x0000_0001

    CONVMODE_SHIFT            = 1
    CONVMODE_MASK             = 0x0000_0006

    DONE_SHIFT                = 0
    DONE_MASK                 = 0x0000_0001


class CoreCfgMask:
    NMC_XNEVER_BASE_SHIFT     = 0
    NMC_XNEVER_BASE_MASK      = 0x0000_03FF

    NMC_XNEVER_HIGH_SHIFT     = 16
    NMC_XNEVER_HIGH_MASK      = 0x03FF_0000

    SYNAPSE_ROUTE_SHIFT       = 0
    SYNAPSE_ROUTE_MASK        = 0x0000_0001

    NMC_PMODE_SWITCH_SHIFT    = 1
    NMC_PMODE_SWITCH_MASK     = 0x0000_0002


class CoreExecMask:
    DIS_LEARN_ENGINES_SHIFT   = 0
    DIS_LEARN_ENGINES_MASK    = 0x0000_0001

    INPUT_SPIKE_MUX_SHIFT     = 1
    INPUT_SPIKE_MUX_MASK      = 0x0000_0002

    TIMESTEP_STARTED_SHIFT    = 2
    TIMESTEP_STARTED_MASK     = 0x0000_0004


class CoreResetMask:
    SP_RESET_SHIFT            = 0
    SP_RESET_MASK             = 0x0000_0001

    FLUSH_MAIN_BUF_SHIFT      = 1
    FLUSH_MAIN_BUF_MASK       = 0x0000_0002

    FLUSH_AUX_BUF_SHIFT       = 2
    FLUSH_AUX_BUF_MASK        = 0x0000_0004

    FLUSH_CIRC_BUF_SHIFT      = 3
    FLUSH_CIRC_BUF_MASK       = 0x0000_0008

    FLUSH_OUT_BUF_SHIFT       = 4
    FLUSH_OUT_BUF_MASK        = 0x0000_0010


class CoreStatMask:
    TIMESTEP_DONE_SHIFT       = 0
    TIMESTEP_DONE_MASK        = 0x0000_0001

    MATH_ERR_SHIFT            = 1
    MATH_ERR_MASK             = 0x0000_0002

    MEM_VIOL_SHIFT            = 2
    MEM_VIOL_MASK             = 0x0000_0004