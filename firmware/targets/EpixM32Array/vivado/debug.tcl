##############################################################################
## This file is part of 'EPIX Development Firmware'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'EPIX Development Firmware', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################
### User Debug Script
#
### Open the run
#open_run synth_1
#
### Configure the Core
#set ilaName u_ila_0
##set ilaName1 u_ila_1
#CreateDebugCore ${ilaName}
###CreateDebugCore ${ilaName1}
##
#### Increase the record depth
##set_property C_DATA_DEPTH 8192 [get_debug_cores ${ilaName}]
###set_property C_DATA_DEPTH 16384 [get_debug_cores ${ilaName}]
#set_property C_DATA_DEPTH 2048 [get_debug_cores ${ilaName}]
##
##############################################################################
##############################################################################
##############################################################################
##
#### Core debug signals
##SetDebugCoreClk ${ilaName} {U_EpixCore/coreClk}
#SetDebugCoreClk ${ilaName} {U_EpixCore/G_AdcReadout[0].U_AdcReadout/adcBitClkR}
##
#
#ConfigProbe ${ilaName} {U_EpixCore/G_AdcReadout[0].U_AdcReadout/adcFrame[*]}
#ConfigProbe ${ilaName} {U_EpixCore/G_AdcReadout[0].U_AdcReadout/adcR[slip]}
#ConfigProbe ${ilaName} {U_EpixCore/G_AdcReadout[0].U_AdcReadout/adcR[locked]}
#ConfigProbe ${ilaName} {U_EpixCore/G_AdcReadout[0].U_AdcReadout/adcR[count][*]}
#
##ConfigProbe ${ilaName} {U_EpixCore/G_AdcReadout[0].U_AdcReadout/curDelayFrame[*]}
##ConfigProbe ${ilaName} {U_EpixCore/G_AdcReadout[0].U_AdcReadout/curDelayData[*][*]}
##ConfigProbe ${ilaName} {U_EpixCore/G_AdcReadout[0].U_AdcReadout/lockedSync}
##ConfigProbe ${ilaName} {U_EpixCore/G_AdcReadout[0].U_AdcReadout/lockedFallCount[*]}
##ConfigProbe ${ilaName} {U_EpixCore/G_AdcReadout[0].U_AdcReadout/axilR[frameDelaySet]}
##ConfigProbe ${ilaName} {U_EpixCore/G_AdcReadout[0].U_AdcReadout/axilR[delay][*]}
##ConfigProbe ${ilaName} {U_EpixCore/G_AdcReadout[0].U_AdcReadout/axilR[dataDelaySet][*]}
#
#
####SACI Debug
###ConfigProbe ${ilaName} {U_EpixCore/U_RegControl/U_Saci/saciClk}
###ConfigProbe ${ilaName} {U_EpixCore/U_RegControl/U_Saci/saciSelL*}
###ConfigProbe ${ilaName} {U_EpixCore/U_RegControl/U_Saci/saciCmd}
###ConfigProbe ${ilaName} {U_EpixCore/U_RegControl/U_Saci/saciRsp}
###ConfigProbe ${ilaName} {U_EpixCore/U_RegControl/U_Saci/saciMasterOut*}
##
####ADC Alignment Program Debug
###ConfigProbe ${ilaName} {U_EpixCore/U_EpixStartup/U_StartupPicoBlaze/address*}
###ConfigProbe ${ilaName} {U_EpixCore/U_EpixStartup/U_StartupPicoBlaze/instruction*}
###ConfigProbe ${ilaName} {U_EpixCore/U_EpixStartup/U_StartupPicoBlaze/bram_enable}
###ConfigProbe ${ilaName} {U_EpixCore/U_EpixStartup/adcSelect*}
###ConfigProbe ${ilaName} {U_EpixCore/U_EpixStartup/adcChSelect*}
###ConfigProbe ${ilaName} {U_EpixCore/U_EpixStartup/muxedAdcData*}
###ConfigProbe ${ilaName} {U_EpixCore/U_EpixStartup/muxedAdcValid*}
###ConfigProbe ${ilaName} {U_EpixCore/U_EpixStartup/adcValidCountReg*}
###ConfigProbe ${ilaName} {U_EpixCore/U_EpixStartup/adcMatchCountReg*}
##
###Bad frame debug
##ConfigProbe ${ilaName} {U_EpixCore/U_ReadoutControl/r[state][*]}
##ConfigProbe ${ilaName} {U_EpixCore/U_ReadoutControl/r[timeoutCnt][*]}
##ConfigProbe ${ilaName} {U_EpixCore/U_ReadoutControl/fifoEmptyAll}
##ConfigProbe ${ilaName} {U_EpixCore/acqBusy}
##ConfigProbe ${ilaName} {U_EpixCore/acqStart}
##ConfigProbe ${ilaName} {U_EpixCore/U_AcqControl/pixelCnt[*]}
##ConfigProbe ${ilaName} {U_EpixCore/U_AcqControl/curState[*]}
##
##
####Slow ADC debug
###ConfigProbe ${ilaName} {U_EpixCore/slowAdcRefClk*}
###ConfigProbe ${ilaName} {U_EpixCore/slowAdcSclk*}
###ConfigProbe ${ilaName} {U_EpixCore/slowAdcDin*}
####ConfigProbe ${ilaName} {U_EpixCore/slowAdcCsb*}
###ConfigProbe ${ilaName} {U_EpixCore/slowAdcDout*}
###ConfigProbe ${ilaName} {U_EpixCore/slowAdcDrdy*}
###ConfigProbe ${ilaName} {U_EpixCore/readDone*}
##
##
##############################################################################
##
#### Delete the last unused port
#delete_debug_port [get_debug_ports [GetCurrentProbe ${ilaName}]]
###delete_debug_port [get_debug_ports [GetCurrentProbe ${ilaName1}]]
##
#### Write the port map file
#