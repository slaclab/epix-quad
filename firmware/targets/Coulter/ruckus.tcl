# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load library modules
loadRuckusTcl $::env(PROJ_DIR)/../../submodules/surf

# Load Source Code
loadSource -path "$::DIR_PATH/Version.vhd"
loadSource -dir "$::DIR_PATH/hdl/"
loadSource -sim_only -dir "$::DIR_PATH/sim/"

# Load Constraints
loadConstraints -path "$::DIR_PATH/hdl/Coulter.xdc"

set_property strategy Performance_Explore [get_runs impl_1]
