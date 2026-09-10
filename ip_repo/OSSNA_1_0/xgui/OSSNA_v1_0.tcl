
# Loading additional proc with user specified bodies to compute parameter values.
source [file join [file dirname [file dirname [info script]]] gui/OSSNA_v1_0.gtcl]

# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  ipgui::add_page $IPINST -name "Page 0"

  set CROSSBAR_MATRIX_DIMENSIONS [ipgui::add_param $IPINST -name "CROSSBAR_MATRIX_DIMENSIONS" -widget comboBox]
  set_property tooltip {The dimensions of the crossbar matrix determine the maximum number of spikes and neurons that can be processed in parallel at a single timestep. The crossbar is in the form of a square matrix.} ${CROSSBAR_MATRIX_DIMENSIONS}
  set SYNAPSE_MEM_DEPTH [ipgui::add_param $IPINST -name "SYNAPSE_MEM_DEPTH"]
  set_property tooltip {The synapse memory depth determines the maximum number of synapses that can be processed within a column of the crossbar.} ${SYNAPSE_MEM_DEPTH}
  ipgui::add_param $IPINST -name "NEURAL_MEM_DEPTH"
  set LEARNING_ENGINE_LUT_DEPTH [ipgui::add_param $IPINST -name "LEARNING_ENGINE_LUT_DEPTH" -widget comboBox]
  set_property tooltip {LUT depth for Learning Engines. Must be multiple of 256.} ${LEARNING_ENGINE_LUT_DEPTH}
  ipgui::add_param $IPINST -name "SPIKE_GENERATOR_BUFFER_DEPTH"
  ipgui::add_param $IPINST -name "C_AXIM_DATA_DATA_WIDTH" -widget comboBox
  set MAX_NEURONS [ipgui::add_param $IPINST -name "MAX_NEURONS"]
  set_property tooltip {The maximum number of neurons that can be processed in a single timestep.} ${MAX_NEURONS}
  set MAX_SYNAPSES [ipgui::add_param $IPINST -name "MAX_SYNAPSES"]
  set_property tooltip {The maximum number of synapses for the largest SNN network that can be processed by the hardware.} ${MAX_SYNAPSES}
  set DSP_UTIL [ipgui::add_param $IPINST -name "DSP_UTIL"]
  set_property tooltip {The amount of DSP48 resources required by the processor.} ${DSP_UTIL}
  set BRAM_UTIL [ipgui::add_param $IPINST -name "BRAM_UTIL"]
  set_property tooltip {The amount of BRAM required by the processor.} ${BRAM_UTIL}

}

proc update_PARAM_VALUE.BRAM_UTIL { PARAM_VALUE.BRAM_UTIL PARAM_VALUE.CROSSBAR_MATRIX_DIMENSIONS PARAM_VALUE.SYNAPSE_MEM_DEPTH PARAM_VALUE.NEURAL_MEM_DEPTH PARAM_VALUE.SPIKE_GENERATOR_BUFFER_DEPTH } {
	# Procedure called to update BRAM_UTIL when any of the dependent parameters in the arguments change
	
	set BRAM_UTIL ${PARAM_VALUE.BRAM_UTIL}
	set CROSSBAR_MATRIX_DIMENSIONS ${PARAM_VALUE.CROSSBAR_MATRIX_DIMENSIONS}
	set SYNAPSE_MEM_DEPTH ${PARAM_VALUE.SYNAPSE_MEM_DEPTH}
	set NEURAL_MEM_DEPTH ${PARAM_VALUE.NEURAL_MEM_DEPTH}
	set SPIKE_GENERATOR_BUFFER_DEPTH ${PARAM_VALUE.SPIKE_GENERATOR_BUFFER_DEPTH}
	set values(CROSSBAR_MATRIX_DIMENSIONS) [get_property value $CROSSBAR_MATRIX_DIMENSIONS]
	set values(SYNAPSE_MEM_DEPTH) [get_property value $SYNAPSE_MEM_DEPTH]
	set values(NEURAL_MEM_DEPTH) [get_property value $NEURAL_MEM_DEPTH]
	set values(SPIKE_GENERATOR_BUFFER_DEPTH) [get_property value $SPIKE_GENERATOR_BUFFER_DEPTH]
	set_property value [gen_USERPARAMETER_BRAM_UTIL_VALUE $values(CROSSBAR_MATRIX_DIMENSIONS) $values(SYNAPSE_MEM_DEPTH) $values(NEURAL_MEM_DEPTH) $values(SPIKE_GENERATOR_BUFFER_DEPTH)] $BRAM_UTIL
}

proc validate_PARAM_VALUE.BRAM_UTIL { PARAM_VALUE.BRAM_UTIL } {
	# Procedure called to validate BRAM_UTIL
	return true
}

proc update_PARAM_VALUE.DSP_UTIL { PARAM_VALUE.DSP_UTIL PARAM_VALUE.CROSSBAR_MATRIX_DIMENSIONS } {
	# Procedure called to update DSP_UTIL when any of the dependent parameters in the arguments change
	
	set DSP_UTIL ${PARAM_VALUE.DSP_UTIL}
	set CROSSBAR_MATRIX_DIMENSIONS ${PARAM_VALUE.CROSSBAR_MATRIX_DIMENSIONS}
	set values(CROSSBAR_MATRIX_DIMENSIONS) [get_property value $CROSSBAR_MATRIX_DIMENSIONS]
	set_property value [gen_USERPARAMETER_DSP_UTIL_VALUE $values(CROSSBAR_MATRIX_DIMENSIONS)] $DSP_UTIL
}

proc validate_PARAM_VALUE.DSP_UTIL { PARAM_VALUE.DSP_UTIL } {
	# Procedure called to validate DSP_UTIL
	return true
}

proc update_PARAM_VALUE.MAX_NEURONS { PARAM_VALUE.MAX_NEURONS PARAM_VALUE.CROSSBAR_MATRIX_DIMENSIONS PARAM_VALUE.NEURAL_MEM_DEPTH } {
	# Procedure called to update MAX_NEURONS when any of the dependent parameters in the arguments change
	
	set MAX_NEURONS ${PARAM_VALUE.MAX_NEURONS}
	set CROSSBAR_MATRIX_DIMENSIONS ${PARAM_VALUE.CROSSBAR_MATRIX_DIMENSIONS}
	set NEURAL_MEM_DEPTH ${PARAM_VALUE.NEURAL_MEM_DEPTH}
	set values(CROSSBAR_MATRIX_DIMENSIONS) [get_property value $CROSSBAR_MATRIX_DIMENSIONS]
	set values(NEURAL_MEM_DEPTH) [get_property value $NEURAL_MEM_DEPTH]
	set_property value [gen_USERPARAMETER_MAX_NEURONS_VALUE $values(CROSSBAR_MATRIX_DIMENSIONS) $values(NEURAL_MEM_DEPTH)] $MAX_NEURONS
}

proc validate_PARAM_VALUE.MAX_NEURONS { PARAM_VALUE.MAX_NEURONS } {
	# Procedure called to validate MAX_NEURONS
	return true
}

proc update_PARAM_VALUE.MAX_SYNAPSES { PARAM_VALUE.MAX_SYNAPSES PARAM_VALUE.CROSSBAR_MATRIX_DIMENSIONS PARAM_VALUE.SYNAPSE_MEM_DEPTH } {
	# Procedure called to update MAX_SYNAPSES when any of the dependent parameters in the arguments change
	
	set MAX_SYNAPSES ${PARAM_VALUE.MAX_SYNAPSES}
	set CROSSBAR_MATRIX_DIMENSIONS ${PARAM_VALUE.CROSSBAR_MATRIX_DIMENSIONS}
	set SYNAPSE_MEM_DEPTH ${PARAM_VALUE.SYNAPSE_MEM_DEPTH}
	set values(CROSSBAR_MATRIX_DIMENSIONS) [get_property value $CROSSBAR_MATRIX_DIMENSIONS]
	set values(SYNAPSE_MEM_DEPTH) [get_property value $SYNAPSE_MEM_DEPTH]
	set_property value [gen_USERPARAMETER_MAX_SYNAPSES_VALUE $values(CROSSBAR_MATRIX_DIMENSIONS) $values(SYNAPSE_MEM_DEPTH)] $MAX_SYNAPSES
}

proc validate_PARAM_VALUE.MAX_SYNAPSES { PARAM_VALUE.MAX_SYNAPSES } {
	# Procedure called to validate MAX_SYNAPSES
	return true
}

proc update_PARAM_VALUE.CROSSBAR_MATRIX_DIMENSIONS { PARAM_VALUE.CROSSBAR_MATRIX_DIMENSIONS } {
	# Procedure called to update CROSSBAR_MATRIX_DIMENSIONS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.CROSSBAR_MATRIX_DIMENSIONS { PARAM_VALUE.CROSSBAR_MATRIX_DIMENSIONS } {
	# Procedure called to validate CROSSBAR_MATRIX_DIMENSIONS
	return true
}

proc update_PARAM_VALUE.LEARNING_ENGINE_LUT_DEPTH { PARAM_VALUE.LEARNING_ENGINE_LUT_DEPTH } {
	# Procedure called to update LEARNING_ENGINE_LUT_DEPTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.LEARNING_ENGINE_LUT_DEPTH { PARAM_VALUE.LEARNING_ENGINE_LUT_DEPTH } {
	# Procedure called to validate LEARNING_ENGINE_LUT_DEPTH
	return true
}

proc update_PARAM_VALUE.NEURAL_MEM_DEPTH { PARAM_VALUE.NEURAL_MEM_DEPTH } {
	# Procedure called to update NEURAL_MEM_DEPTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.NEURAL_MEM_DEPTH { PARAM_VALUE.NEURAL_MEM_DEPTH } {
	# Procedure called to validate NEURAL_MEM_DEPTH
	return true
}

proc update_PARAM_VALUE.SPIKE_GENERATOR_BUFFER_DEPTH { PARAM_VALUE.SPIKE_GENERATOR_BUFFER_DEPTH } {
	# Procedure called to update SPIKE_GENERATOR_BUFFER_DEPTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.SPIKE_GENERATOR_BUFFER_DEPTH { PARAM_VALUE.SPIKE_GENERATOR_BUFFER_DEPTH } {
	# Procedure called to validate SPIKE_GENERATOR_BUFFER_DEPTH
	return true
}

proc update_PARAM_VALUE.SYNAPSE_MEM_DEPTH { PARAM_VALUE.SYNAPSE_MEM_DEPTH } {
	# Procedure called to update SYNAPSE_MEM_DEPTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.SYNAPSE_MEM_DEPTH { PARAM_VALUE.SYNAPSE_MEM_DEPTH } {
	# Procedure called to validate SYNAPSE_MEM_DEPTH
	return true
}

proc update_PARAM_VALUE.C_AXIM_DATA_TARGET_SLAVE_BASE_ADDR { PARAM_VALUE.C_AXIM_DATA_TARGET_SLAVE_BASE_ADDR } {
	# Procedure called to update C_AXIM_DATA_TARGET_SLAVE_BASE_ADDR when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_AXIM_DATA_TARGET_SLAVE_BASE_ADDR { PARAM_VALUE.C_AXIM_DATA_TARGET_SLAVE_BASE_ADDR } {
	# Procedure called to validate C_AXIM_DATA_TARGET_SLAVE_BASE_ADDR
	return true
}

proc update_PARAM_VALUE.C_AXIM_DATA_BURST_LEN { PARAM_VALUE.C_AXIM_DATA_BURST_LEN } {
	# Procedure called to update C_AXIM_DATA_BURST_LEN when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_AXIM_DATA_BURST_LEN { PARAM_VALUE.C_AXIM_DATA_BURST_LEN } {
	# Procedure called to validate C_AXIM_DATA_BURST_LEN
	return true
}

proc update_PARAM_VALUE.C_AXIM_DATA_ID_WIDTH { PARAM_VALUE.C_AXIM_DATA_ID_WIDTH } {
	# Procedure called to update C_AXIM_DATA_ID_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_AXIM_DATA_ID_WIDTH { PARAM_VALUE.C_AXIM_DATA_ID_WIDTH } {
	# Procedure called to validate C_AXIM_DATA_ID_WIDTH
	return true
}

proc update_PARAM_VALUE.C_AXIM_DATA_ADDR_WIDTH { PARAM_VALUE.C_AXIM_DATA_ADDR_WIDTH } {
	# Procedure called to update C_AXIM_DATA_ADDR_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_AXIM_DATA_ADDR_WIDTH { PARAM_VALUE.C_AXIM_DATA_ADDR_WIDTH } {
	# Procedure called to validate C_AXIM_DATA_ADDR_WIDTH
	return true
}

proc update_PARAM_VALUE.C_AXIM_DATA_DATA_WIDTH { PARAM_VALUE.C_AXIM_DATA_DATA_WIDTH } {
	# Procedure called to update C_AXIM_DATA_DATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_AXIM_DATA_DATA_WIDTH { PARAM_VALUE.C_AXIM_DATA_DATA_WIDTH } {
	# Procedure called to validate C_AXIM_DATA_DATA_WIDTH
	return true
}

proc update_PARAM_VALUE.C_AXIM_DATA_AWUSER_WIDTH { PARAM_VALUE.C_AXIM_DATA_AWUSER_WIDTH } {
	# Procedure called to update C_AXIM_DATA_AWUSER_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_AXIM_DATA_AWUSER_WIDTH { PARAM_VALUE.C_AXIM_DATA_AWUSER_WIDTH } {
	# Procedure called to validate C_AXIM_DATA_AWUSER_WIDTH
	return true
}

proc update_PARAM_VALUE.C_AXIM_DATA_ARUSER_WIDTH { PARAM_VALUE.C_AXIM_DATA_ARUSER_WIDTH } {
	# Procedure called to update C_AXIM_DATA_ARUSER_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_AXIM_DATA_ARUSER_WIDTH { PARAM_VALUE.C_AXIM_DATA_ARUSER_WIDTH } {
	# Procedure called to validate C_AXIM_DATA_ARUSER_WIDTH
	return true
}

proc update_PARAM_VALUE.C_AXIM_DATA_WUSER_WIDTH { PARAM_VALUE.C_AXIM_DATA_WUSER_WIDTH } {
	# Procedure called to update C_AXIM_DATA_WUSER_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_AXIM_DATA_WUSER_WIDTH { PARAM_VALUE.C_AXIM_DATA_WUSER_WIDTH } {
	# Procedure called to validate C_AXIM_DATA_WUSER_WIDTH
	return true
}

proc update_PARAM_VALUE.C_AXIM_DATA_RUSER_WIDTH { PARAM_VALUE.C_AXIM_DATA_RUSER_WIDTH } {
	# Procedure called to update C_AXIM_DATA_RUSER_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_AXIM_DATA_RUSER_WIDTH { PARAM_VALUE.C_AXIM_DATA_RUSER_WIDTH } {
	# Procedure called to validate C_AXIM_DATA_RUSER_WIDTH
	return true
}

proc update_PARAM_VALUE.C_AXIM_DATA_BUSER_WIDTH { PARAM_VALUE.C_AXIM_DATA_BUSER_WIDTH } {
	# Procedure called to update C_AXIM_DATA_BUSER_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_AXIM_DATA_BUSER_WIDTH { PARAM_VALUE.C_AXIM_DATA_BUSER_WIDTH } {
	# Procedure called to validate C_AXIM_DATA_BUSER_WIDTH
	return true
}

proc update_PARAM_VALUE.C_AXIL_CONTROLS_DATA_WIDTH { PARAM_VALUE.C_AXIL_CONTROLS_DATA_WIDTH } {
	# Procedure called to update C_AXIL_CONTROLS_DATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_AXIL_CONTROLS_DATA_WIDTH { PARAM_VALUE.C_AXIL_CONTROLS_DATA_WIDTH } {
	# Procedure called to validate C_AXIL_CONTROLS_DATA_WIDTH
	return true
}

proc update_PARAM_VALUE.C_AXIL_CONTROLS_ADDR_WIDTH { PARAM_VALUE.C_AXIL_CONTROLS_ADDR_WIDTH } {
	# Procedure called to update C_AXIL_CONTROLS_ADDR_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_AXIL_CONTROLS_ADDR_WIDTH { PARAM_VALUE.C_AXIL_CONTROLS_ADDR_WIDTH } {
	# Procedure called to validate C_AXIL_CONTROLS_ADDR_WIDTH
	return true
}

proc update_PARAM_VALUE.C_AXIL_CONTROLS_BASEADDR { PARAM_VALUE.C_AXIL_CONTROLS_BASEADDR } {
	# Procedure called to update C_AXIL_CONTROLS_BASEADDR when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_AXIL_CONTROLS_BASEADDR { PARAM_VALUE.C_AXIL_CONTROLS_BASEADDR } {
	# Procedure called to validate C_AXIL_CONTROLS_BASEADDR
	return true
}

proc update_PARAM_VALUE.C_AXIL_CONTROLS_HIGHADDR { PARAM_VALUE.C_AXIL_CONTROLS_HIGHADDR } {
	# Procedure called to update C_AXIL_CONTROLS_HIGHADDR when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_AXIL_CONTROLS_HIGHADDR { PARAM_VALUE.C_AXIL_CONTROLS_HIGHADDR } {
	# Procedure called to validate C_AXIL_CONTROLS_HIGHADDR
	return true
}


proc update_MODELPARAM_VALUE.C_AXIM_DATA_TARGET_SLAVE_BASE_ADDR { MODELPARAM_VALUE.C_AXIM_DATA_TARGET_SLAVE_BASE_ADDR PARAM_VALUE.C_AXIM_DATA_TARGET_SLAVE_BASE_ADDR } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_AXIM_DATA_TARGET_SLAVE_BASE_ADDR}] ${MODELPARAM_VALUE.C_AXIM_DATA_TARGET_SLAVE_BASE_ADDR}
}

proc update_MODELPARAM_VALUE.C_AXIM_DATA_BURST_LEN { MODELPARAM_VALUE.C_AXIM_DATA_BURST_LEN PARAM_VALUE.C_AXIM_DATA_BURST_LEN } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_AXIM_DATA_BURST_LEN}] ${MODELPARAM_VALUE.C_AXIM_DATA_BURST_LEN}
}

proc update_MODELPARAM_VALUE.C_AXIM_DATA_ID_WIDTH { MODELPARAM_VALUE.C_AXIM_DATA_ID_WIDTH PARAM_VALUE.C_AXIM_DATA_ID_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_AXIM_DATA_ID_WIDTH}] ${MODELPARAM_VALUE.C_AXIM_DATA_ID_WIDTH}
}

proc update_MODELPARAM_VALUE.C_AXIM_DATA_ADDR_WIDTH { MODELPARAM_VALUE.C_AXIM_DATA_ADDR_WIDTH PARAM_VALUE.C_AXIM_DATA_ADDR_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_AXIM_DATA_ADDR_WIDTH}] ${MODELPARAM_VALUE.C_AXIM_DATA_ADDR_WIDTH}
}

proc update_MODELPARAM_VALUE.C_AXIM_DATA_DATA_WIDTH { MODELPARAM_VALUE.C_AXIM_DATA_DATA_WIDTH PARAM_VALUE.C_AXIM_DATA_DATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_AXIM_DATA_DATA_WIDTH}] ${MODELPARAM_VALUE.C_AXIM_DATA_DATA_WIDTH}
}

proc update_MODELPARAM_VALUE.C_AXIM_DATA_AWUSER_WIDTH { MODELPARAM_VALUE.C_AXIM_DATA_AWUSER_WIDTH PARAM_VALUE.C_AXIM_DATA_AWUSER_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_AXIM_DATA_AWUSER_WIDTH}] ${MODELPARAM_VALUE.C_AXIM_DATA_AWUSER_WIDTH}
}

proc update_MODELPARAM_VALUE.C_AXIM_DATA_ARUSER_WIDTH { MODELPARAM_VALUE.C_AXIM_DATA_ARUSER_WIDTH PARAM_VALUE.C_AXIM_DATA_ARUSER_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_AXIM_DATA_ARUSER_WIDTH}] ${MODELPARAM_VALUE.C_AXIM_DATA_ARUSER_WIDTH}
}

proc update_MODELPARAM_VALUE.C_AXIM_DATA_WUSER_WIDTH { MODELPARAM_VALUE.C_AXIM_DATA_WUSER_WIDTH PARAM_VALUE.C_AXIM_DATA_WUSER_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_AXIM_DATA_WUSER_WIDTH}] ${MODELPARAM_VALUE.C_AXIM_DATA_WUSER_WIDTH}
}

proc update_MODELPARAM_VALUE.C_AXIM_DATA_RUSER_WIDTH { MODELPARAM_VALUE.C_AXIM_DATA_RUSER_WIDTH PARAM_VALUE.C_AXIM_DATA_RUSER_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_AXIM_DATA_RUSER_WIDTH}] ${MODELPARAM_VALUE.C_AXIM_DATA_RUSER_WIDTH}
}

proc update_MODELPARAM_VALUE.C_AXIM_DATA_BUSER_WIDTH { MODELPARAM_VALUE.C_AXIM_DATA_BUSER_WIDTH PARAM_VALUE.C_AXIM_DATA_BUSER_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_AXIM_DATA_BUSER_WIDTH}] ${MODELPARAM_VALUE.C_AXIM_DATA_BUSER_WIDTH}
}

proc update_MODELPARAM_VALUE.C_AXIL_CONTROLS_DATA_WIDTH { MODELPARAM_VALUE.C_AXIL_CONTROLS_DATA_WIDTH PARAM_VALUE.C_AXIL_CONTROLS_DATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_AXIL_CONTROLS_DATA_WIDTH}] ${MODELPARAM_VALUE.C_AXIL_CONTROLS_DATA_WIDTH}
}

proc update_MODELPARAM_VALUE.C_AXIL_CONTROLS_ADDR_WIDTH { MODELPARAM_VALUE.C_AXIL_CONTROLS_ADDR_WIDTH PARAM_VALUE.C_AXIL_CONTROLS_ADDR_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_AXIL_CONTROLS_ADDR_WIDTH}] ${MODELPARAM_VALUE.C_AXIL_CONTROLS_ADDR_WIDTH}
}

proc update_MODELPARAM_VALUE.CROSSBAR_MATRIX_DIMENSIONS { MODELPARAM_VALUE.CROSSBAR_MATRIX_DIMENSIONS PARAM_VALUE.CROSSBAR_MATRIX_DIMENSIONS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.CROSSBAR_MATRIX_DIMENSIONS}] ${MODELPARAM_VALUE.CROSSBAR_MATRIX_DIMENSIONS}
}

proc update_MODELPARAM_VALUE.SYNAPSE_MEM_DEPTH { MODELPARAM_VALUE.SYNAPSE_MEM_DEPTH PARAM_VALUE.SYNAPSE_MEM_DEPTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.SYNAPSE_MEM_DEPTH}] ${MODELPARAM_VALUE.SYNAPSE_MEM_DEPTH}
}

proc update_MODELPARAM_VALUE.NEURAL_MEM_DEPTH { MODELPARAM_VALUE.NEURAL_MEM_DEPTH PARAM_VALUE.NEURAL_MEM_DEPTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.NEURAL_MEM_DEPTH}] ${MODELPARAM_VALUE.NEURAL_MEM_DEPTH}
}

proc update_MODELPARAM_VALUE.LEARNING_ENGINE_LUT_DEPTH { MODELPARAM_VALUE.LEARNING_ENGINE_LUT_DEPTH PARAM_VALUE.LEARNING_ENGINE_LUT_DEPTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.LEARNING_ENGINE_LUT_DEPTH}] ${MODELPARAM_VALUE.LEARNING_ENGINE_LUT_DEPTH}
}

proc update_MODELPARAM_VALUE.SPIKE_GENERATOR_BUFFER_DEPTH { MODELPARAM_VALUE.SPIKE_GENERATOR_BUFFER_DEPTH PARAM_VALUE.SPIKE_GENERATOR_BUFFER_DEPTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.SPIKE_GENERATOR_BUFFER_DEPTH}] ${MODELPARAM_VALUE.SPIKE_GENERATOR_BUFFER_DEPTH}
}

