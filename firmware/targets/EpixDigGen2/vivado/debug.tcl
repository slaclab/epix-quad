## User Debug Script

## Open the run
open_run synth_1

## Configure the Core
set ilaName u_ila_0
CreateDebugCore ${ilaName}

## Increase the record depth
set_property C_DATA_DEPTH 2048 [get_debug_cores ${ilaName}]

############################################################################
############################################################################
############################################################################

## TDC debug signals
SetDebugCoreClk ${ilaName} {U_PgpFrontEnd/pgpClk}
ConfigProbe ${ilaName} {U_PgpFrontEnd/pgpRxMasters*}
ConfigProbe ${ilaName} {U_PgpFrontEnd/pgpTxMasters*}

############################################################################

## Delete the last unused port
delete_debug_port [get_debug_ports [GetCurrentProbe ${ilaName}]]

## Write the port map file
write_debug_probes -force ${PROJ_DIR}/debug/debug_probes.ltx
