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
open_run synth_1
#
### Configure the Core
#set ilaName u_ila_0
###set ilaName1 u_ila_1
#CreateDebugCore ${ilaName}
####CreateDebugCore ${ilaName1}
###
##### Increase the record depth
###set_property C_DATA_DEPTH 8192 [get_debug_cores ${ilaName}]
##set_property C_DATA_DEPTH 16384 [get_debug_cores ${ilaName}]
#set_property C_DATA_DEPTH 2048 [get_debug_cores ${ilaName}]
###
###############################################################################
###############################################################################
###############################################################################
###
##### Core debug signals
#SetDebugCoreClk ${ilaName} {U_EpixCore/coreClk}
##SetDebugCoreClk ${ilaName} {U_EpixCore/G_AdcReadout[0].U_AdcReadout/adcBitClkR}
###
##
##ConfigProbe ${ilaName} {U_EpixCore/G_AdcReadout[0].U_AdcReadout/adcFrame[*]}
##ConfigProbe ${ilaName} {U_EpixCore/G_AdcReadout[0].U_AdcReadout/adcR[slip]}
##ConfigProbe ${ilaName} {U_EpixCore/G_AdcReadout[0].U_AdcReadout/adcR[locked]}
##ConfigProbe ${ilaName} {U_EpixCore/G_AdcReadout[0].U_AdcReadout/adcR[count][*]}
##
###ConfigProbe ${ilaName} {U_EpixCore/G_AdcReadout[0].U_AdcReadout/curDelayFrame[*]}
###ConfigProbe ${ilaName} {U_EpixCore/G_AdcReadout[0].U_AdcReadout/curDelayData[*][*]}
###ConfigProbe ${ilaName} {U_EpixCore/G_AdcReadout[0].U_AdcReadout/lockedSync}
###ConfigProbe ${ilaName} {U_EpixCore/G_AdcReadout[0].U_AdcReadout/lockedFallCount[*]}
###ConfigProbe ${ilaName} {U_EpixCore/G_AdcReadout[0].U_AdcReadout/axilR[frameDelaySet]}
###ConfigProbe ${ilaName} {U_EpixCore/G_AdcReadout[0].U_AdcReadout/axilR[delay][*]}
###ConfigProbe ${ilaName} {U_EpixCore/G_AdcReadout[0].U_AdcReadout/axilR[dataDelaySet][*]}
##
##
#####epix10ka Debug
#ConfigProbe ${ilaName} {iAsicDout[*]}
#ConfigProbe ${ilaName} {iAsicRoClk}
#
##ConfigProbe ${ilaName} {U_EpixCore/G_DOUT_EPIX10KA.U_DoutAsic/f[asicDout][*]}
##ConfigProbe ${ilaName} {U_EpixCore/G_DOUT_EPIX10KA.U_DoutAsic/f[state][*]}
##ConfigProbe ${ilaName} {U_EpixCore/G_DOUT_EPIX10KA.U_DoutAsic/f[stCnt][*]}
##ConfigProbe ${ilaName} {U_EpixCore/G_DOUT_EPIX10KA.U_DoutAsic/f[copyCnt][*]}
##ConfigProbe ${ilaName} {U_EpixCore/G_DOUT_EPIX10KA.U_DoutAsic/f[roClkRising][0]}
##ConfigProbe ${ilaName} {U_EpixCore/G_DOUT_EPIX10KA.U_DoutAsic/f[roClkRising][1]}
##ConfigProbe ${ilaName} {U_EpixCore/G_DOUT_EPIX10KA.U_DoutAsic/f[roClkRising][2]}
##ConfigProbe ${ilaName} {U_EpixCore/G_DOUT_EPIX10KA.U_DoutAsic/f[roClkRising][3]}
##ConfigProbe ${ilaName} {U_EpixCore/G_DOUT_EPIX10KA.U_DoutAsic/f[roClkRising][4]}
##ConfigProbe ${ilaName} {U_EpixCore/G_DOUT_EPIX10KA.U_DoutAsic/f[roClkRising][5]}
##ConfigProbe ${ilaName} {U_EpixCore/G_DOUT_EPIX10KA.U_DoutAsic/f[rowBuff][*][*]}
##ConfigProbe ${ilaName} {U_EpixCore/G_DOUT_EPIX10KA.U_DoutAsic/f[fifoIn][*]}
##ConfigProbe ${ilaName} {U_EpixCore/G_DOUT_EPIX10KA.U_DoutAsic/f[fifoWr][*]}
##ConfigProbe ${ilaName} {U_EpixCore/G_DOUT_EPIX10KA.U_DoutAsic/f[fifoRst]}
##ConfigProbe ${ilaName} {U_EpixCore/doutOut[*][*]}
##ConfigProbe ${ilaName} {U_EpixCore/doutRd[*]}
##ConfigProbe ${ilaName} {U_EpixCore/doutValid[*]}
##ConfigProbe ${ilaName} {U_EpixCore/U_ReadoutControl/adcFifoRdEn[*]}
##ConfigProbe ${ilaName} {U_EpixCore/U_ReadoutControl/adcFifoRdValid[*]}
##ConfigProbe ${ilaName} {U_EpixCore/U_ReadoutControl/r[state][*]}
##ConfigProbe ${ilaName} {U_EpixCore/U_ReadoutControl/r[chCnt][*]}
##
#
#
#
#####SACI Debug
##ConfigProbe ${ilaName} {U_EpixCore/iSaciSelL[*]}
##ConfigProbe ${ilaName} {U_EpixCore/iSaciClk}
##ConfigProbe ${ilaName} {U_EpixCore/iSaciCmd}
##ConfigProbe ${ilaName} {U_EpixCore/iSaciRsp}
###
#####ADC Alignment Program Debug
####ConfigProbe ${ilaName} {U_EpixCore/U_EpixStartup/U_StartupPicoBlaze/address*}
####ConfigProbe ${ilaName} {U_EpixCore/U_EpixStartup/U_StartupPicoBlaze/instruction*}
####ConfigProbe ${ilaName} {U_EpixCore/U_EpixStartup/U_StartupPicoBlaze/bram_enable}
####ConfigProbe ${ilaName} {U_EpixCore/U_EpixStartup/adcSelect*}
####ConfigProbe ${ilaName} {U_EpixCore/U_EpixStartup/adcChSelect*}
####ConfigProbe ${ilaName} {U_EpixCore/U_EpixStartup/muxedAdcData*}
####ConfigProbe ${ilaName} {U_EpixCore/U_EpixStartup/muxedAdcValid*}
####ConfigProbe ${ilaName} {U_EpixCore/U_EpixStartup/adcValidCountReg*}
####ConfigProbe ${ilaName} {U_EpixCore/U_EpixStartup/adcMatchCountReg*}
###
####Bad frame debug
##ConfigProbe ${ilaName} {U_EpixCore/U_ReadoutControl/r[state][*]}
##ConfigProbe ${ilaName} {U_EpixCore/U_ReadoutControl/r[timeoutCnt][*]}
##ConfigProbe ${ilaName} {U_EpixCore/U_ReadoutControl/fifoEmptyAll}
##ConfigProbe ${ilaName} {U_EpixCore/iAsicAcq}
##ConfigProbe ${ilaName} {U_EpixCore/acqBusy}
##ConfigProbe ${ilaName} {U_EpixCore/acqStart}
##ConfigProbe ${ilaName} {U_EpixCore/U_AcqControl/iReadValid}
##ConfigProbe ${ilaName} {U_EpixCore/U_AcqControl/pixelCnt[*]}
##ConfigProbe ${ilaName} {U_EpixCore/U_AcqControl/curState[*]}
###
###
#####Slow ADC debug
####ConfigProbe ${ilaName} {U_EpixCore/slowAdcRefClk*}
####ConfigProbe ${ilaName} {U_EpixCore/slowAdcSclk*}
####ConfigProbe ${ilaName} {U_EpixCore/slowAdcDin*}
#####ConfigProbe ${ilaName} {U_EpixCore/slowAdcCsb*}
####ConfigProbe ${ilaName} {U_EpixCore/slowAdcDout*}
####ConfigProbe ${ilaName} {U_EpixCore/slowAdcDrdy*}
####ConfigProbe ${ilaName} {U_EpixCore/readDone*}
###
###
###############################################################################
###
##### Delete the last unused port
#delete_debug_port [get_debug_ports [GetCurrentProbe ${ilaName}]]
####delete_debug_port [get_debug_ports [GetCurrentProbe ${ilaName1}]]
###
##### Write the port map file
##