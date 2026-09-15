# ossna/__init__.py

# 1. Donanım Sürücüsü (Driver)
from .driver import OssnaDriver

# 2. Register Haritası ve Maskeleri
from .registers import (
    Regs,
    DmaCtrlMask,
    DmaStatMask,
    D2SCtrlMask,
    CoreCfgMask,
    CoreExecMask,
    CoreResetMask,
    CoreStatMask
)

# 3. Nöron Derleyicisi (Compiler)
from .nmc_compiler import Neuron, NMCCompiler, HalfPrecision2Bin

# 4. Mikrokod Assembler (Assembler)
from .nmc_assembler import NModelAssembler

# sw/ossna/__init__.py içine ekleyin:
from .synapse import Synapse, SynapseCompiler

# __all__ listesine ekleyin:

# sw/ossna/__init__.py içine ekleyin:
from .slaves import (
    SlaveRegistry, 
    SlaveDescriptor, 
    AccessType, 
    TargetType, 
    FifoType
)

from .dma import DmaController

__version__ = "0.1.0"

__all__ = [
    # Driver
    "OssnaDriver",
    # Registers & Masks
    "Regs",
    "DmaCtrlMask",
    "DmaStatMask",
    "D2SCtrlMask",
    "CoreCfgMask",
    "CoreExecMask",
    "CoreResetMask",
    "CoreStatMask",
    # Compiler
    "Neuron",
    "NMCCompiler",
    "HalfPrecision2Bin",
    # Assembler
    "NModelAssembler",
    # STDP
    "Synapse", 
    "SynapseCompiler",
    # Slaves
    "SlaveRegistry", 
    "SlaveDescriptor", 
    "AccessType", 
    "TargetType", 
    "FifoType"
]