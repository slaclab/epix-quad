## User Debug Script

## Open the run
open_run synth_1

#### Configure the Core
#set ilaName u_ila_0
###set ilaName1 u_ila_1
#CreateDebugCore ${ilaName}
###CreateDebugCore ${ilaName1}
##
#### Increase the record depth
#set_property C_DATA_DEPTH 8192 [get_debug_cores ${ilaName}]
##set_property C_DATA_DEPTH 16384 [get_debug_cores ${ilaName}]
###set_property C_DATA_DEPTH 2048 [get_debug_cores ${ilaName1}]
##
##############################################################################
##############################################################################
##############################################################################
##
#### Core debug signals
###SetDebugCoreClk ${ilaName} {U_EpixCore/coreClk}
##SetDebugCoreClk ${ilaName} {tixWrdClk}
#SetDebugCoreClk ${ilaName} {U_CpixCore/coreClk}
#
##ConfigProbe ${ilaName} {tixDecode_gen[0].tixDeser_i/delay_en}
##ConfigProbe ${ilaName} {tixDecode_gen[0].tixDeser_i/pattern_ok}
##ConfigProbe ${ilaName} {tixDecode_gen[0].tixDeser_i/iserdese_out[*]}
##ConfigProbe ${ilaName} {asicD8bit[0][*]}
##ConfigProbe ${ilaName} {asicD8bitK[0]}
##ConfigProbe ${ilaName} {asicD8bitCErr[0]}
##ConfigProbe ${ilaName} {asicD8bitDErr[0]}
#
##ADC Alignment Program Debug
#ConfigProbe ${ilaName} {U_CpixCore/U_EpixStartup/U_StartupPicoBlaze/address*}
#ConfigProbe ${ilaName} {U_CpixCore/U_EpixStartup/U_StartupPicoBlaze/instruction*}
#ConfigProbe ${ilaName} {U_CpixCore/U_EpixStartup/U_StartupPicoBlaze/bram_enable}
#ConfigProbe ${ilaName} {U_CpixCore/U_EpixStartup/adcSelect*}
#ConfigProbe ${ilaName} {U_CpixCore/U_EpixStartup/adcChSelect*}
#ConfigProbe ${ilaName} {U_CpixCore/U_EpixStartup/muxedAdcData*}
#ConfigProbe ${ilaName} {U_CpixCore/U_EpixStartup/muxedAdcValid*}
#ConfigProbe ${ilaName} {U_CpixCore/U_EpixStartup/adcValidCountReg*}
#ConfigProbe ${ilaName} {U_CpixCore/U_EpixStartup/adcMatchCountReg*}
#
##
##
##############################################################################
##
### Delete the last unused port
#delete_debug_port [get_debug_ports [GetCurrentProbe ${ilaName}]]
##delete_debug_port [get_debug_ports [GetCurrentProbe ${ilaName1}]]
#
### Write the port map file
#write_debug_probes -force ${PROJ_DIR}/debug/debug_probes.ltx
#