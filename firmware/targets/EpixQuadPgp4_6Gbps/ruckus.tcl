# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load library modules
loadRuckusTcl $::env(PROJ_DIR)/../../submodules/surf
loadRuckusTcl $::env(PROJ_DIR)/../../common/EpixQuadCommon
loadRuckusTcl $::env(PROJ_DIR)/../../common/common

# Load local source Code and constraints
loadSource      -dir "$::DIR_PATH/hdl/"
loadConstraints -dir "$::DIR_PATH/hdl/"

loadSource -sim_only -dir "$::DIR_PATH/tb/"
set_property top {EpixQuad_tb} [get_filesets sim_1]
