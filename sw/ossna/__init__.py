# ossna/__init__.py

from .driver import OssnaDriver

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

from .slaves import (
    SlaveRegistry, 
    SlaveDescriptor, 
    AccessType, 
    TargetType, 
    FifoType
)
from .dma import DmaController

from .nmc_compiler import Neuron, NMCCompiler, HalfPrecision2Bin
from .nmc_assembler import NModelAssembler

from .synapse import Synapse, SynapseCompiler

from .network import Network, Layer, InputEncoder

from .network_compiler import NetworkCompiler, CompiledNetwork

__version__ = "0.2.0"

__all__ = [
    # Driver & Core
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
    
    # DMA & Slaves
    "SlaveRegistry", 
    "SlaveDescriptor", 
    "AccessType", 
    "TargetType", 
    "FifoType",
    "DmaController",
    
    # Neuron (NMC)
    "Neuron",
    "NMCCompiler",
    "HalfPrecision2Bin",
    "NModelAssembler",
    
    # Synapse (STDP)
    "Synapse",
    "SynapseCompiler",
    
    # Network
    "Network",
    "Layer",
    "InputEncoder",
    "NetworkCompiler", 
    "CompiledNetwork"
]
