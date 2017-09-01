# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load library modules
loadRuckusTcl $::env(PROJ_DIR)/../../submodules/surf
loadRuckusTcl $::env(PROJ_DIR)/../../common/EpixCommonGen2
loadRuckusTcl $::env(PROJ_DIR)/../../common/CpixTixelCommon

# Set the top level synth_1 and sim_1
set_property top {TB_CpixCore} [get_filesets sim_1]

