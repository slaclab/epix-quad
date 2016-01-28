## User Debug Script

## Open the run
open_run synth_1

### Configure the Core
#set ilaName u_ila_0
##set ilaName1 u_ila_1
#CreateDebugCore ${ilaName}
##CreateDebugCore ${ilaName1}
#
### Increase the record depth
#set_property C_DATA_DEPTH 2048 [get_debug_cores ${ilaName}]
##set_property C_DATA_DEPTH 2048 [get_debug_cores ${ilaName1}]
#
#############################################################################
#############################################################################
#############################################################################
#
### Core debug signals
##SetDebugCoreClk ${ilaName} {U_EpixCore/coreClk}
#SetDebugCoreClk ${ilaName} {sysClk}
#ConfigProbe ${ilaName} {asicD10bit[0]*}
#ConfigProbe ${ilaName} {resync[0]*}
#ConfigProbe ${ilaName} {sync[0]*}
#ConfigProbe ${ilaName} {delay[0]*}
#ConfigProbe ${ilaName} {oosync_cnt[0]*}
#ConfigProbe ${ilaName} {sync_cnt[0]*}
#ConfigProbe ${ilaName} {asicD8bit[0]*}
#ConfigProbe ${ilaName} {asicD8bitK[0]*}
#ConfigProbe ${ilaName} {asicD8bitCErr[0]*}
#ConfigProbe ${ilaName} {asicD8bitDErr[0]*}
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