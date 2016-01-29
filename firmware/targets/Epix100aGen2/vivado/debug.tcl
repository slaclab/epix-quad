## User Debug Script

## Open the run
open_run synth_1

## Configure the Core
#set ilaName u_ila_0
#set ilaName1 u_ila_1
#CreateDebugCore ${ilaName}
##CreateDebugCore ${ilaName1}
#
### Increase the record depth
#set_property C_DATA_DEPTH 8192 [get_debug_cores ${ilaName}]
##set_property C_DATA_DEPTH 16384 [get_debug_cores ${ilaName}]
##set_property C_DATA_DEPTH 2048 [get_debug_cores ${ilaName}]
#
#############################################################################
#############################################################################
#############################################################################
#
### Core debug signals
#SetDebugCoreClk ${ilaName} {U_EpixCore/coreClk}
#
##SACI Debug
#ConfigProbe ${ilaName} {U_EpixCore/U_RegControl/U_Saci/saciClk}
#ConfigProbe ${ilaName} {U_EpixCore/U_RegControl/U_Saci/saciSelL*}
#ConfigProbe ${ilaName} {U_EpixCore/U_RegControl/U_Saci/saciCmd}
#ConfigProbe ${ilaName} {U_EpixCore/U_RegControl/U_Saci/saciRsp}
#ConfigProbe ${ilaName} {U_EpixCore/U_RegControl/U_Saci/saciMasterOut*}
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
###ADC Data Debug
##ConfigProbe ${ilaName} {U_EpixCore/adcData[0]*}
##ConfigProbe ${ilaName} {U_EpixCore/adcValid[0]*}
##ConfigProbe ${ilaName} {U_EpixCore/adcData[4]*}
##ConfigProbe ${ilaName} {U_EpixCore/adcValid[4]*}
##ConfigProbe ${ilaName} {U_EpixCore/adcData[8]*}
##ConfigProbe ${ilaName} {U_EpixCore/adcValid[8]*}
##ConfigProbe ${ilaName} {U_EpixCore/adcData[12]*}
##ConfigProbe ${ilaName} {U_EpixCore/adcValid[12]*}
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
#delete_debug_port [get_debug_ports [GetCurrentProbe ${ilaName}]]
##delete_debug_port [get_debug_ports [GetCurrentProbe ${ilaName1}]]
#
### Write the port map file
#write_debug_probes -force ${PROJ_DIR}/debug/debug_probes.ltx
#