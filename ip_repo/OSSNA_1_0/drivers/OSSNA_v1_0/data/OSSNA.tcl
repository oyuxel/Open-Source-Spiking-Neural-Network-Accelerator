

proc generate {drv_handle} {
	xdefine_include_file $drv_handle "xparameters.h" "OSSNA" "NUM_INSTANCES" "DEVICE_ID"  "C_AXIL_CONTROLS_BASEADDR" "C_AXIL_CONTROLS_HIGHADDR"
}
