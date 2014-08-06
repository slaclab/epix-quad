##-----------------------------------------------------------------------------
## File          : sim/Makefile
## Author        : Ryan Herbst  <rherbst@slac.stanford.edu>
## Created       : 04/16/2009
##-----------------------------------------------------------------------------
## Description :
## Makefile for simulation.
##-----------------------------------------------------------------------------
## Copyright (c) 2009 by SLAC. All rights reserved.
## Proprietary and confidential to SLAC.
##-----------------------------------------------------------------------------
## Modification history :
## 04/16/2009: created
##-----------------------------------------------------------------------------

# Set Default Output
SIM_DIR=$(PWD)/../../../build/EpixStartup

# Shared memory id. Changed this if you need to run multiple instances
# Resulting shared memory file is simlink_username_id
SHM_ID=1
SHM_NAME="epix"

# Set Top Level
#DIG_TOP=PseudoScopeTb
DIG_TOP=EpixStartupTb
#DIG_TOP=EpixAcqControlTb
#ANA_TOP=KpixSmallAnalogTb

# Set 64-bit mode
EN64=-full64

# HDL Source Files
HDL_SRC= $(PWD)/../../../common/StdLib/general/rtl/StdRtlPkg.vhd \
         $(PWD)/../../../common/VcLib/rtl/VcPkg.vhd \
         $(PWD)/../../../targets/EpixDigTest/Version.vhd \
         $(PWD)/../../EpixCommon/hdl/EpixTypes.vhd \
         $(PWD)/../hdl/JTAG_LOADER_6.vhd \
         $(PWD)/../hdl/kcpsm3.vhd \
         $(PWD)/../hdl/embedded_kcpsm3.vhd \
         $(PWD)/../hdl/EpixStartupCode.vhd \
         $(PWD)/../hdl/EpixStartup.vhd \
         $(PWD)/EpixStartupTb.vhd

# Targets
all:    dir env syn_setup rtl_src sim_dig

# Directory
dir:
	@mkdir -p $(SIM_DIR)

# RTL Files
rtl_src:
	@cd $(SIM_DIR); vhdlan $(EN64) $(HDL_SRC)

sim_dig:
	@cd $(SIM_DIR); vcs $(EN64) $(DIG_TOP) -parallel -cpp g++ -cc gcc -lrt -debug -time "ns" -time_res "1ps"

clean: 
	@rm -rf $(SIM_DIR)/*
	@rm -rf $(SIM_DIR)/.synopsys_vss.setup

# Create Synopsis Setup File
syn_setup:
	@rm -f $(SIM_DIR)/.synopsys_vss.setup
	@echo "UNISIM:$(XIL_SIMLIB)/unisim"                >  $(SIM_DIR)/.synopsys_vss.setup
	@echo "XILINXCORELIB:$(XIL_SIMLIB)/xilinxcorelib"  >> $(SIM_DIR)/.synopsys_vss.setup
	@echo "SIMPRIM:$(XIL_SIMLIB)/simprim"              >> $(SIM_DIR)/.synopsys_vss.setup
	@echo "UNIMACRO:$(XIL_SIMLIB)/unimacro"            >> $(SIM_DIR)/.synopsys_vss.setup

# Create setup env script
env:
	@rm -f $(SIM_DIR)/setup_env.csh
	@echo "limit stacksize 60000"                                 >> $(SIM_DIR)/setup_env.csh
	@echo "setenv LD_LIBRARY_PATH $(SIM_DIR):${LD_LIBRARY_PATH}"  >> $(SIM_DIR)/setup_env.csh

