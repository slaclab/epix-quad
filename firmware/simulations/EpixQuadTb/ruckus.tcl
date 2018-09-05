# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Check for version 2017.2 of Vivado
if { [VersionCheck 2017.2] < 0 } {
   exit -1
}

# Load submodules' code and constraints
loadRuckusTcl $::env(TOP_DIR)/submodules/surf
loadRuckusTcl $::env(TOP_DIR)/common/EpixQuadCommmon

# Load target's source code and constraints
loadSource -sim_only -dir "$::DIR_PATH/tb/"
loadSource -sim_only -dir "$::DIR_PATH/../../targets/EpixQuad/hdl/"

# Remove the .DCP and use the .XCI IP core instead
remove_files [get_files {MigCore.dcp}]
loadIpCore -path "$::env(TOP_DIR)/common/EpixQuadCommmon/ip/MigCore/MigCore.xci"

remove_files [get_files {AxiInterconnect.dcp}]
loadIpCore -path "$::env(TOP_DIR)/common/EpixQuadCommmon/ip/AxiInterconnnect/AxiInterconnect.xci"

remove_files [get_files {SysMonCore.dcp}]
loadIpCore -path "$::env(TOP_DIR)/common/EpixQuadCommmon/ip/SysMonCore/SysMonCore.xci"

# Set the top level synth_1 and sim_1
set_property top {MigCoreWrapper} [get_filesets sources_1]
set_property top {EpixQuadTb} [get_filesets sim_1]
