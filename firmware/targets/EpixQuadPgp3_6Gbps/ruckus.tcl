# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load library modules
loadRuckusTcl $::env(PROJ_DIR)/../../submodules/surf
loadRuckusTcl $::env(PROJ_DIR)/../../common/EpixQuadCommon
loadRuckusTcl $::env(PROJ_DIR)/../../common/core
loadRuckusTcl $::env(PROJ_DIR)/../../common/common
loadRuckusTcl $::env(PROJ_DIR)/../../common/protocols

# Load local source Code and constraints
loadSource      -dir "$::DIR_PATH/hdl/"
loadConstraints -dir "$::DIR_PATH/hdl/"


