## User Debug Script

## Open the run
open_run synth_1

### Configure the Core
set ilaName u_ila_0
set ilaName1 u_ila_1
CreateDebugCore ${ilaName}
CreateDebugCore ${ilaName1}
#
### Increase the record depth
#set_property C_DATA_DEPTH 1024 [get_debug_cores ${ilaName}]
#set_property C_DATA_DEPTH 2048 [get_debug_cores ${ilaName}]
set_property C_DATA_DEPTH 16384 [get_debug_cores ${ilaName}]
set_property C_DATA_DEPTH 16384 [get_debug_cores ${ilaName1}]
#
#############################################################################
#############################################################################
#############################################################################
#
### Core debug signals
##SetDebugCoreClk ${ilaName} {U_EpixCore/coreClk}
#SetDebugCoreClk ${ilaName} {tixWrdClk}
SetDebugCoreClk ${ilaName} {U_CpixCore/coreClk}
SetDebugCoreClk ${ilaName1} {U_CpixCore/byteClk}

#ConfigProbe ${ilaName} {tixDecode_gen[0].tixDeser_i/delay_en}
#ConfigProbe ${ilaName} {tixDecode_gen[0].tixDeser_i/pattern_ok}
#ConfigProbe ${ilaName} {tixDecode_gen[0].tixDeser_i/iserdese_out[*]}
#ConfigProbe ${ilaName} {asicD8bit[0][*]}
#ConfigProbe ${ilaName} {asicD8bitK[0]}
#ConfigProbe ${ilaName} {asicD8bitCErr[0]}
#ConfigProbe ${ilaName} {asicD8bitDErr[0]}

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

##AXI crossbar
#ConfigProbe ${ilaName} {U_CpixCore/mAxiWriteMasters[0][awaddr][*]}
#ConfigProbe ${ilaName} {U_CpixCore/mAxiWriteMasters[0][wdata][*]}
#ConfigProbe ${ilaName} {U_CpixCore/mAxiWriteMasters[0][awvalid]}
#
#ConfigProbe ${ilaName} {U_CpixCore/mAxiWriteMasters[1][awaddr][*]}
#ConfigProbe ${ilaName} {U_CpixCore/mAxiWriteMasters[1][wdata][*]}
#ConfigProbe ${ilaName} {U_CpixCore/mAxiWriteMasters[1][awvalid]}
#
#ConfigProbe ${ilaName1} {U_CpixCore/sAxiWriteMaster[0][awaddr][*]}
#ConfigProbe ${ilaName1} {U_CpixCore/sAxiWriteMaster[0][wdata][*]}
#ConfigProbe ${ilaName1} {U_CpixCore/sAxiWriteMaster[0][awvalid]}

##DMs and ASIC pins
ConfigProbe ${ilaName} {U_CpixCore/iAsic01DM1}
ConfigProbe ${ilaName} {U_CpixCore/iAsic01DM2}
ConfigProbe ${ilaName} {U_CpixCore/iAsicEnA}
ConfigProbe ${ilaName} {U_CpixCore/iAsicEnB}
ConfigProbe ${ilaName} {U_CpixCore/iAsicR0}
ConfigProbe ${ilaName} {U_CpixCore/iAsicAcq}
ConfigProbe ${ilaName} {U_CpixCore/iAsicSRO}
ConfigProbe ${ilaName} {U_CpixCore/iAsicGrst}
ConfigProbe ${ilaName} {U_CpixCore/iAsicSync}
ConfigProbe ${ilaName} {U_CpixCore/iAsicPpmat}
ConfigProbe ${ilaName} {U_CpixCore/iAsicPPbe}
ConfigProbe ${ilaName} {U_CpixCore/saciPrepReadoutReq}
ConfigProbe ${ilaName} {U_CpixCore/saciPrepReadoutAck}
ConfigProbe ${ilaName} {U_CpixCore/cntAReadout}
ConfigProbe ${ilaName} {U_CpixCore/frameErr[0]}
ConfigProbe ${ilaName} {U_CpixCore/timeoutReq}
ConfigProbe ${ilaName1} {U_CpixCore/G_ASIC[0].U_ASIC_Framer/state[*]}
ConfigProbe ${ilaName1} {U_CpixCore/G_ASIC[0].U_ASIC_Framer/frameErrCntEn}

###ADC data
#ConfigProbe ${ilaName} {U_CpixCore/adcData[*][*]}
#ConfigProbe ${ilaName} {U_CpixCore/adcValid[*]}
#
#
#
#############################################################################
#
## Delete the last unused port
delete_debug_port [get_debug_ports [GetCurrentProbe ${ilaName}]]
delete_debug_port [get_debug_ports [GetCurrentProbe ${ilaName1}]]

## Write the port map file
write_debug_probes -force ${PROJ_DIR}/debug/debug_probes.ltx
