export GIT_BYPASS = 0

# Define target output
target: prom

# Define target part
export PRJ_PART = XC7A200TSBG484-3

# Define Firmware Version Number
export PRJ_VERSION = 0xEA020006

# Define the Microblaze source path
export SDK_SRC_PATH = $(PROJ_DIR)/../../common/EpixCommonGen2/src/ePix100a

# Use top level makefile
include ../../submodules/ruckus/system_vivado.mk


#-------------------------------------------------------------------------------
#-- Revision History:
#-- 09/30/2015 (0xEA020000): Upper byte of version encodes the ASIC, 
#--                          second byte encodes the analog board version: 01 - gen1, 02 - gen2
#--                          Initial build on digital and analog cards generation 2
#-- 09/30/2015 (0xEA020001): First release of the EPIX100a firmware for the analog card gen2
#-- 02/23/2016 (0xEA020002): Fixed SACI reliability issues, ADC wrong default encoding, carier ID readout. 
#--                          Removed unused ASIC sync modes fixed random packet without data.
#-- 06/03/2016 (0xEA020003): Reduced SACI clock to 4.5MHz to avoid matrix setup issues
#-- 07/08/2016 (0xEA020004): Added optical/TTL trigger switch into the register space
#--                          Added monitoring data output stream via PGP VC3 and enable/disable input command on the same VC3
#--                          Added FPGA flash programming over the PGP
#--                          Old non AXIL components replaced by the new AXIL components
#--                          Picoblaze replaced by Microblaze with AXIL log memory
#-- 07/08/2016 (0xEA020005): New working copy version number (change date when released)
#--                          Instantiated new SACI controller with AXI lite slave bus
#--                          Two more AXI lite masters for SACI multi pixel interface and prepare for readout command
#--                          Added PGP monitoring registers module
#--                          Prepared DDR AXI controller. The onboard memory verified with Axi memory tester. DDR3 ready to be used.
#--               
#-- 08/07/2017 (0xEA020006): Changed it to git
#--                          Added ssiCmdMaster to VC2 (EuXFEL to separate data and cmd channels) and kept it on VC0 for compatibility with older software
#--                          
#--                          
#--                          
#--                          
#-------------------------------------------------------------------------------
