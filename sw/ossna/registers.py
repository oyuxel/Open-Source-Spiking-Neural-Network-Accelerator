# ossna/registers.py

class Regs:
    """Register Adres Ofsetleri (Bayt cinsinden)"""
    # -------------------------------------------------------------------------
    # 1. Donanım Konfigürasyon Bilgileri (slv_reg0 - slv_reg5) [Read-Only]
    # -------------------------------------------------------------------------
    ADDR_TOTAL_PARAM_MEM          = 0x00  # slv_reg0
    ADDR_TOTAL_SYN_MEM            = 0x04  # slv_reg1
    ADDR_CROSSBAR_DIMS            = 0x08  # slv_reg2
    ADDR_MAX_NEURONS              = 0x0C  # slv_reg3
    ADDR_LEARN_LUT_DEPTH          = 0x10  # slv_reg4
    ADDR_SPIKE_GEN_BUF_DEPTH      = 0x14  # slv_reg5

    # -------------------------------------------------------------------------
    # 2. DMA Kontrol ve Durum Registerları (slv_reg6 - slv_reg14)
    # -------------------------------------------------------------------------
    ADDR_DMA_CTRL                 = 0x18  # slv_reg6
    ADDR_SELECT_SLAVE             = 0x1C  # slv_reg7
    ADDR_BYTE_PER_WORD            = 0x20  # slv_reg8
    ADDR_TOTAL_BYTES              = 0x24  # slv_reg9
    ADDR_TOTAL_WORDS              = 0x28  # slv_reg10
    ADDR_BRAM_READ_DELAY          = 0x2C  # slv_reg11
    ADDR_BRAM_BASEADDR            = 0x30  # slv_reg12
    ADDR_DDR_BASEADDR             = 0x34  # slv_reg13
    ADDR_DMA_STATUS               = 0x38  # slv_reg14

    # -------------------------------------------------------------------------
    # 3. Data-2-Spike (D2S) Registerları (slv_reg15 - slv_reg19)
    # -------------------------------------------------------------------------
    ADDR_D2S_CTRL                 = 0x3C  # slv_reg15
    ADDR_CONVMODE                 = 0x3C  # slv_reg15 (Aynı register içinde)
    ADDR_TIME_WIND                = 0x40  # slv_reg16
    ADDR_SEED                     = 0x44  # slv_reg17
    ADDR_DATA_COUNT               = 0x48  # slv_reg18
    ADDR_CONV_STATUS              = 0x4C  # slv_reg19

    # -------------------------------------------------------------------------
    # 4. Çekirdek (Core) ve Snapshot Registerları (slv_reg20 - slv_reg26)
    # -------------------------------------------------------------------------
    ADDR_NMC_XNEVER               = 0x50  # slv_reg20
    ADDR_CORE_ROUTING_CFG         = 0x54  # slv_reg21
    ADDR_NET_START_ADDR           = 0x58  # slv_reg22
    ADDR_CORE_EXEC_CTRL           = 0x5C  # slv_reg23
    ADDR_CORE_RESET_FLUSH         = 0x60  # slv_reg24 (Reset, Flush, Snapshot Clear/Reset)
    ADDR_CORE_STATUS              = 0x64  # slv_reg25 (Timestep Done, Math/Mem Error)
    ADDR_SNAPSHOT_TIMESTEP_COUNTER = 0x68 # slv_reg26 [YENİ] Hedef Timestep Sayacı


class DmaCtrlMask:
    RESET_SOFT_SHIFT              = 0
    RESET_SOFT_MASK               = 0x0000_0001

    START_READ_SHIFT              = 1
    START_READ_MASK               = 0x0000_0002

    START_WRITE_SHIFT             = 2
    START_WRITE_MASK              = 0x0000_0004

    TARGET_SELECT_SHIFT           = 3
    TARGET_SELECT_MASK            = 0x0000_0008

    FIFO_TYPE_SHIFT               = 4
    FIFO_TYPE_MASK                = 0x0000_0010


class DmaStatMask:
    READ_DONE_SHIFT               = 0
    READ_DONE_MASK                = 0x0000_0001

    WRITE_DONE_SHIFT              = 1
    WRITE_DONE_MASK               = 0x0000_0002

    READ_ERR_SHIFT                = 2
    READ_ERR_MASK                 = 0x0000_0004

    WRITE_ERR_SHIFT               = 3
    WRITE_ERR_MASK                = 0x0000_0008


class D2SCtrlMask:
    RESET_SHIFT                   = 0
    RESET_MASK                    = 0x0000_0001

    CONVMODE_SHIFT                = 1
    CONVMODE_MASK                 = 0x0000_0006

    DONE_SHIFT                    = 0
    DONE_MASK                     = 0x0000_0001


class CoreCfgMask:
    NMC_XNEVER_BASE_SHIFT         = 0
    NMC_XNEVER_BASE_MASK          = 0x0000_03FF

    NMC_XNEVER_HIGH_SHIFT         = 16
    NMC_XNEVER_HIGH_MASK          = 0x03FF_0000

    SYNAPSE_ROUTE_SHIFT           = 0
    SYNAPSE_ROUTE_MASK            = 0x0000_0001

    NMC_PMODE_SWITCH_SHIFT        = 1
    NMC_PMODE_SWITCH_MASK         = 0x0000_0002


class CoreExecMask:
    DIS_LEARN_ENGINES_SHIFT       = 0
    DIS_LEARN_ENGINES_MASK        = 0x0000_0001

    INPUT_SPIKE_MUX_SHIFT         = 1
    INPUT_SPIKE_MUX_MASK          = 0x0000_0002

    TIMESTEP_STARTED_SHIFT        = 2
    TIMESTEP_STARTED_MASK         = 0x0000_0004


class CoreResetMask:
    SP_RESET_SHIFT                = 0
    SP_RESET_MASK                 = 0x0000_0001

    FLUSH_MAIN_BUF_SHIFT          = 1
    FLUSH_MAIN_BUF_MASK           = 0x0000_0002

    FLUSH_AUX_BUF_SHIFT           = 2
    FLUSH_AUX_BUF_MASK            = 0x0000_0004

    FLUSH_CIRC_BUF_SHIFT          = 3
    FLUSH_CIRC_BUF_MASK           = 0x0000_0008

    FLUSH_OUT_BUF_SHIFT           = 4
    FLUSH_OUT_BUF_MASK            = 0x0000_0010

    # --- YENİ EKLENEN SNAPSHOT MASKELERİ (slv_reg24) ---
    CLEAR_SNAPSHOT_IRQ_SHIFT      = 5
    CLEAR_SNAPSHOT_IRQ_MASK       = 0x0000_0020  # Bit 5: Kesmeyi Temizle

    RESET_SNAPSHOT_SHIFT          = 6
    RESET_SNAPSHOT_MASK           = 0x0000_0040  # Bit 6: Snapshot Modülünü Resetle


class CoreStatMask:
    TIMESTEP_DONE_SHIFT           = 0
    TIMESTEP_DONE_MASK            = 0x0000_0001

    MATH_ERR_SHIFT                = 1
    MATH_ERR_MASK                 = 0x0000_0002

    MEM_VIOL_SHIFT                = 2
    MEM_VIOL_MASK                 = 0x0000_0004