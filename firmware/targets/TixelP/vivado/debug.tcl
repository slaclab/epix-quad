## User Debug Script

## Open the run
open_run synth_1

## Configure the Core
set ilaName u_ila_0
#set ilaName1 u_ila_1
CreateDebugCore ${ilaName}
#CreateDebugCore ${ilaName1}

## Increase the record depth
set_property C_DATA_DEPTH 16384 [get_debug_cores ${ilaName}]
#set_property C_DATA_DEPTH 2048 [get_debug_cores ${ilaName1}]

############################################################################
############################################################################
############################################################################

## Core debug signals
#SetDebugCoreClk ${ilaName} {U_EpixCore/coreClk}
SetDebugCoreClk ${ilaName} {U_TixelCore/coreClk}
#SetDebugCoreClk ${ilaName1} {U_TixelCore/byteClk}

ConfigProbe ${ilaName} {U_TixelCore/iAsic01DM1}
ConfigProbe ${ilaName} {U_TixelCore/iAsic01DM2}
ConfigProbe ${ilaName} {U_TixelCore/iAsicR0}
ConfigProbe ${ilaName} {U_TixelCore/iAsicStart}
ConfigProbe ${ilaName} {U_TixelCore/iAsicTpulse}
ConfigProbe ${ilaName} {U_TixelCore/iAsicAcq}
ConfigProbe ${ilaName} {U_TixelCore/iAsicGrst}
ConfigProbe ${ilaName} {U_TixelCore/iAsicSync}
ConfigProbe ${ilaName} {U_TixelCore/iAsicPpmat}
ConfigProbe ${ilaName} {U_TixelCore/iAsicPPbe}

#ConfigProbe ${ilaName1} {U_TixelCore/dataOut[1][*]}
#ConfigProbe ${ilaName1} {U_TixelCore/dataKOut[1]}
#ConfigProbe ${ilaName1} {U_TixelCore/G_ASIC[1].U_AsicDeser/iserdese_out[*]}

############################################################################

## Delete the last unused port
delete_debug_port [get_debug_ports [GetCurrentProbe ${ilaName}]]
#delete_debug_port [get_debug_ports [GetCurrentProbe ${ilaName1}]]

## Write the port map file
##write_debug_probes -force ${PROJ_DIR}/debug/debug_probes.ltx
