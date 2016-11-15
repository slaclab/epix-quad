# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load Source Code
loadSource -path "$::DIR_PATH/Version.vhd"
loadSource -dir "$::DIR_PATH/hdl/"

# Load Constraints
loadConstraints -path "$::DIR_PATH/hdl/Coulter.xdc"
