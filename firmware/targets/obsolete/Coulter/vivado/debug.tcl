##############################################################################
## This file is part of 'EPIX Development Firmware'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'EPIX Development Firmware', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################
## User Debug Script

## Open the run
open_run synth_1

## Configure the Core
set ilaName u_ila_0

CreateDebugCore ${ilaName}
##CreateDebugCore ${ilaName1}
#
### Increase the record depth
#set_property C_DATA_DEPTH 8192 [get_debug_cores ${ilaName}]
set_property C_DATA_DEPTH 16384 [get_debug_cores ${ilaName}]
##set_property C_DATA_DEPTH 2048 [get_debug_cores ${ilaName}]
#
#############################################################################
#############################################################################
#############################################################################
#
### Core debug signals
SetDebugCoreClk ${ilaName} {U_CoulterPgp_1/NO_SIM.FIXED_LATENCY_PGP.U_Pgp2bGtp7FixedLatWrapper_1/TX_CM_GEN.ClockManager7_TX/clkOut[0]}
#
###SACI Debug
ConfigProbe ${ilaName} {elineSdi_OBUF[0]}
ConfigProbe ${ilaName} {elineSen_OBUF[0]}
ConfigProbe ${ilaName} {elineSclk_OBUF[0]}
ConfigProbe ${ilaName} {elineRnW_OBUF[0]}
ConfigProbe ${ilaName} {p_0_in[0]}    
ConfigProbe ${ilaName} {elineSdi_OBUF[1]}
ConfigProbe ${ilaName} {elineSen_OBUF[1]}
ConfigProbe ${ilaName} {elineSclk_OBUF[1]}
ConfigProbe ${ilaName} {elineRnW_OBUF[1]}
ConfigProbe ${ilaName} {p_0_in[1]}    
#
###ADC Alignment Program Debug
##ConfigProbe ${ilaName} {U_EpixCore/U_EpixStartup/U_StartupPicoBlaze/address*}
##ConfigProbe ${ilaName} {U_EpixCore/U_EpixStartup/U_StartupPicoBlaze/instruction*}
##ConfigProbe ${ilaName} {U_EpixCore/U_EpixStartup/U_StartupPicoBlaze/bram_enable}
##ConfigProbe ${ilaName} {U_EpixCore/U_EpixStartup/adcSelect*}
##ConfigProbe ${ilaName} {U_EpixCore/U_EpixStartup/adcChSelect*}
##ConfigProbe ${ilaName} {U_EpixCore/U_EpixStartup/muxedAdcData*}
##ConfigProbe ${ilaName} {U_EpixCore/U_EpixStartup/muxedAdcValid*}
##ConfigProbe ${ilaName} {U_EpixCore/U_EpixStartup/adcValidCountReg*}
##ConfigProbe ${ilaName} {U_EpixCore/U_EpixStartup/adcMatchCountReg*}
#
##Bad frame debug
#ConfigProbe ${ilaName} {U_EpixCore/U_ReadoutControl/r[state][*]}
#ConfigProbe ${ilaName} {U_EpixCore/U_ReadoutControl/r[timeoutCnt][*]}
#ConfigProbe ${ilaName} {U_EpixCore/U_ReadoutControl/fifoEmptyAll}
#ConfigProbe ${ilaName} {U_EpixCore/acqBusy}
#ConfigProbe ${ilaName} {U_EpixCore/acqStart}
#ConfigProbe ${ilaName} {U_EpixCore/U_AcqControl/pixelCnt[*]}
#ConfigProbe ${ilaName} {U_EpixCore/U_AcqControl/curState[*]}
#
#
###Slow ADC debug
##ConfigProbe ${ilaName} {U_EpixCore/slowAdcRefClk*}
##ConfigProbe ${ilaName} {U_EpixCore/slowAdcSclk*}
##ConfigProbe ${ilaName} {U_EpixCore/slowAdcDin*}
###ConfigProbe ${ilaName} {U_EpixCore/slowAdcCsb*}
##ConfigProbe ${ilaName} {U_EpixCore/slowAdcDout*}
##ConfigProbe ${ilaName} {U_EpixCore/slowAdcDrdy*}
##ConfigProbe ${ilaName} {U_EpixCore/readDone*}
#
#
#############################################################################
#
### Delete the last unused port
delete_debug_port [get_debug_ports [GetCurrentProbe ${ilaName}]]
##delete_debug_port [get_debug_ports [GetCurrentProbe ${ilaName1}]]
#
### Write the port map file
write_debug_probes -force ${PROJ_DIR}/debug/debug_probes.ltx
#
