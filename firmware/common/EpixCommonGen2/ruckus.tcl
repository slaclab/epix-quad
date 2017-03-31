# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load Source Code
loadSource -dir           "$::DIR_PATH/rtl/"
loadSource -sim_only -dir "$::DIR_PATH/tb/"

loadSource -path "$::DIR_PATH/ip/AxiDdrCtrl/AxiDdrCtrl.dcp"
# loadIpCore -path "$::DIR_PATH/ip/AxiDdrCtrl/AxiDdrCtrl.xci"
