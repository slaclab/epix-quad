##############################################################################
## This file is part of 'Example Project Firmware'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'Example Project Firmware', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

set_property PACKAGE_PIN F18 [get_ports {fmcLed[0]}]
set_property PACKAGE_PIN G18 [get_ports {fmcLed[1]}]
set_property PACKAGE_PIN E21 [get_ports {fmcLed[2]}]
set_property PACKAGE_PIN F21 [get_ports {fmcLed[3]}]
set_property IOSTANDARD LVCMOS25 [get_ports fmcLed*]

set_property PACKAGE_PIN A28 [get_ports {fmcSfpLossL[0]}]
set_property PACKAGE_PIN G27 [get_ports {fmcSfpLossL[1]}]
set_property PACKAGE_PIN D28 [get_ports {fmcSfpLossL[2]}]
set_property PACKAGE_PIN G28 [get_ports {fmcSfpLossL[3]}]
set_property IOSTANDARD LVCMOS25 [get_ports fmcSfpLossL*]

set_property PACKAGE_PIN E20 [get_ports {fmcTxFault[0]}]
set_property PACKAGE_PIN B28 [get_ports {fmcTxFault[1]}]
set_property PACKAGE_PIN C30 [get_ports {fmcTxFault[2]}]
set_property PACKAGE_PIN E28 [get_ports {fmcTxFault[3]}]
set_property IOSTANDARD LVCMOS25 [get_ports fmcTxFault*]

set_property PACKAGE_PIN F20 [get_ports {fmcSfpTxDisable[0]}]
set_property PACKAGE_PIN A26 [get_ports {fmcSfpTxDisable[1]}]
set_property PACKAGE_PIN D29 [get_ports {fmcSfpTxDisable[2]}]
set_property PACKAGE_PIN G30 [get_ports {fmcSfpTxDisable[3]}]
set_property IOSTANDARD LVCMOS25 [get_ports fmcSfpTxDisable*]

set_property PACKAGE_PIN C24 [get_ports {fmcSfpRateSel[0]}]
set_property PACKAGE_PIN F27 [get_ports {fmcSfpRateSel[1]}]
set_property PACKAGE_PIN E29 [get_ports {fmcSfpRateSel[2]}]
set_property PACKAGE_PIN F28 [get_ports {fmcSfpRateSel[3]}]
set_property IOSTANDARD LVCMOS25 [get_ports fmcSfpRateSel*]

set_property PACKAGE_PIN B24 [get_ports {fmcSfpModDef0[0]}]
set_property PACKAGE_PIN C29 [get_ports {fmcSfpModDef0[1]}]
set_property PACKAGE_PIN E30 [get_ports {fmcSfpModDef0[2]}]
set_property PACKAGE_PIN G29 [get_ports {fmcSfpModDef0[3]}]
set_property IOSTANDARD LVCMOS25 [get_ports fmcSfpModDef0*]

set_property PACKAGE_PIN AB7 [get_ports extRst]
set_property IOSTANDARD LVCMOS15 [get_ports extRst]

set_property PACKAGE_PIN AB8  [get_ports {led[0]}]
set_property PACKAGE_PIN AA8  [get_ports {led[1]}]
set_property PACKAGE_PIN AC9  [get_ports {led[2]}]
set_property PACKAGE_PIN AB9  [get_ports {led[3]}]
set_property IOSTANDARD LVCMOS15 [get_ports led[0]]
set_property IOSTANDARD LVCMOS15 [get_ports led[1]]
set_property IOSTANDARD LVCMOS15 [get_ports led[2]]
set_property IOSTANDARD LVCMOS15 [get_ports led[3]]

set_property PACKAGE_PIN AE26 [get_ports {led[4]}]
set_property PACKAGE_PIN G19  [get_ports {led[5]}]
set_property PACKAGE_PIN E18  [get_ports {led[6]}]
set_property PACKAGE_PIN F16  [get_ports {led[7]}]
set_property IOSTANDARD LVCMOS25 [get_ports led[4]]
set_property IOSTANDARD LVCMOS25 [get_ports led[5]]
set_property IOSTANDARD LVCMOS25 [get_ports led[6]]
set_property IOSTANDARD LVCMOS25 [get_ports led[7]]

set_property PACKAGE_PIN D2 [get_ports gtTxP[0]]
set_property PACKAGE_PIN D1 [get_ports gtTxN[0]]
set_property PACKAGE_PIN E4 [get_ports gtRxP[0]]
set_property PACKAGE_PIN E3 [get_ports gtRxN[0]]

set_property PACKAGE_PIN C4 [get_ports gtTxP[1]]
set_property PACKAGE_PIN C3 [get_ports gtTxN[1]]
set_property PACKAGE_PIN D6 [get_ports gtRxP[1]]
set_property PACKAGE_PIN D5 [get_ports gtRxN[1]]

set_property PACKAGE_PIN B2 [get_ports gtTxP[2]]
set_property PACKAGE_PIN B1 [get_ports gtTxN[2]]
set_property PACKAGE_PIN B6 [get_ports gtRxP[2]]
set_property PACKAGE_PIN B5 [get_ports gtRxN[2]]

set_property PACKAGE_PIN A4 [get_ports gtTxP[3]]
set_property PACKAGE_PIN A3 [get_ports gtTxN[3]]
set_property PACKAGE_PIN A8 [get_ports gtRxP[3]]
set_property PACKAGE_PIN A7 [get_ports gtRxN[3]]

set_property PACKAGE_PIN G8 [get_ports gtClkP]
set_property PACKAGE_PIN G7 [get_ports gtClkN]

# Timing Constraints 
create_clock -name gtClkP -period 8.000 [get_ports {gtClkP}]

create_generated_clock -name stableClk  [get_pins {U_IBUFDS/ODIV2}]
create_generated_clock -name clk        [get_pins {U_MMCM/MmcmGen.U_Mmcm/CLKOUT0}]
                               
# StdLib
set_property ASYNC_REG TRUE [get_cells -hierarchical *crossDomainSyncReg_reg*]

# .bit File Configuration
set_property BITSTREAM.CONFIG.CONFIGRATE 9 [current_design]  
