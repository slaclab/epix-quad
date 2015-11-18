## User Debug Script

## Open the run
open_run synth_1

## Configure the Core
set ilaName u_ila_0
#set ilaName1 u_ila_1
CreateDebugCore ${ilaName}
#CreateDebugCore ${ilaName1}

## Increase the record depth
set_property C_DATA_DEPTH 2048 [get_debug_cores ${ilaName}]
#set_property C_DATA_DEPTH 2048 [get_debug_cores ${ilaName1}]

############################################################################
############################################################################
############################################################################

## Core debug signals
#SetDebugCoreClk ${ilaName} {U_EpixCore/coreClk}
SetDebugCoreClk ${ilaName} {sampleClk}
ConfigProbe ${ilaName} {asicDout1}
#ConfigProbe ${ilaName} {asic01DM2}

#ConfigProbe ${ilaName} {U_EpixCore/U_PseudoScope/mAxisMaster*}
#ConfigProbe ${ilaName} {U_EpixCore/U_PseudoScope/mAxisSlave*}
#ConfigProbe ${ilaName} {U_EpixCore/U_PgpFrontEnd/U_Vc1AxiMasterRegisters/mAxiLiteWriteMaster*}
#ConfigProbe ${ilaName} {U_EpixCore/U_PgpFrontEnd/U_Vc1AxiMasterRegisters/mAxiLiteWriteSlave*}
#ConfigProbe ${ilaName} {U_EpixCore/U_PgpFrontEnd/U_Vc1AxiMasterRegisters/n_0_FSM_sequential_r[state][*]_i_1}
#ConfigProbe ${ilaName} {U_EpixCore/U_PgpFrontEnd/U_Vc1AxiMasterRegisters/*mFifoAxisMaster*}
#ConfigProbe ${ilaName} {U_EpixCore/U_PgpFrontEnd/U_Vc1AxiMasterRegisters/*mFifoAxisSlave*}
#ConfigProbe ${ilaName} {U_EpixCore/U_PgpFrontEnd/U_Vc1AxiMasterRegisters/*mFifoAxisCtrl*}
#ConfigProbe ${ilaName} {U_EpixCore/U_PgpFrontEnd/U_Vc1AxiMasterRegisters/*sFifoAxisMaster*}
#ConfigProbe ${ilaName} {U_EpixCore/U_PgpFrontEnd/U_Vc1AxiMasterRegisters/*sFifoAxisSlave*}
#ConfigProbe ${ilaName} {U_EpixCore/U_RegControl/v[saciSelIn][wrData]*}
#ConfigProbe ${ilaName} {U_EpixCore/U_RegControl/iSaciSelOut*}
#ConfigProbe ${ilaName} {U_EpixCore/U_RegControl/n_0_r_reg[saciState][*]}
#ConfigProbe ${ilaName} {U_EpixCore/U_RegControl/adcSpi*}
#ConfigProbe ${ilaName} {U_EpixCore/U_RegControl/U_AdcConfig/adc*}
#ConfigProbe ${ilaName} {U_EpixCore/U_RegControl/U_AdcConfig/sysClkEn}
#ConfigProbe ${ilaName} {U_EpixCore/U_RegControl/U_AdcConfig/sclk*}
#ConfigProbe ${ilaName} {U_EpixCore/acqBusy}
#ConfigProbe ${ilaName} {U_EpixCore/dataSend}
#ConfigProbe ${ilaName} {U_EpixCore/readDone}
#ConfigProbe ${ilaName} {U_EpixCore/userAxisMaster*}
#ConfigProbe ${ilaName} {U_EpixCore/U_AcqControl/curState*}
#ConfigProbe ${ilaName} {U_EpixCore/U_AcqControl/acqBusy}
#ConfigProbe ${ilaName} {U_EpixCore/U_AcqControl/acqStart}
#ConfigProbe ${ilaName} {U_EpixCore/U_ReadoutControl/r[state*}
#ConfigProbe ${ilaName} {U_EpixCore/U_ReadoutControl/acqBusy}
#ConfigProbe ${ilaName} {U_EpixCore/U_ReadoutControl/fifoEmptyAll}
#ConfigProbe ${ilaName} {U_EpixCore/U_ReadoutControl/adcFifoRdEn*}
#ConfigProbe ${ilaName} {U_EpixCore/U_ReadoutControl/adcFifoWrEn*}
#ConfigProbe ${ilaName} {U_EpixCore/U_ReadoutControl/adcValid*}
#ConfigProbe ${ilaName} {U_EpixCore/U_ReadoutControl/adcData[*}

## SACI debug
#SetDebugCoreClk ${ilaName} {U_EpixCore/U_RegControl/U_Saci/clk}
#ConfigProbe ${ilaName} {U_EpixCore/U_RegControl/U_Saci/saci*}
#ConfigProbe ${ilaName} {U_EpixCore/U_RegControl/iSaciSelOut*}
#ConfigProbe ${ilaName} {U_EpixCore/U_RegControl/*saciSelIn*}
#SetDebugCoreClk ${ilaName} {U_EpixCore/coreClk}
#ConfigProbe ${ilaName} {U_EpixCore/U_RegControl/*localMultiPix*}
#ConfigProbe ${ilaName} {U_EpixCore/U_RegControl/*globalMultiPix*}
#ConfigProbe ${ilaName} {U_EpixCore/U_RegControl/*axiWriteSlave*}

## ADC deserializer
#SetDebugCoreClk ${ilaName} {U_EpixCore/U_AdcReadout3x/GenAdc[0].U_AdcReadout/adcBitClkR}
#ConfigProbe ${ilaName} {U_EpixCore/U_AdcReadout3x/GenAdc[0].U_AdcReadout/*adcR*}
#ConfigProbe ${ilaName} {U_EpixCore/U_AdcReadout3x/GenAdc[0].U_AdcReadout/adcFrame*}

## PGP data path debug signals
#SetDebugCoreClk ${ilaName} {U_EpixCore/U_PgpFrontEnd/pgpClk}
#ConfigProbe ${ilaName} {U_EpixCore/U_PgpFrontEnd/pgpRxOut*}
#ConfigProbe ${ilaName} {U_EpixCore/U_TrigControl/pgpSideband*}
#ConfigProbe ${ilaName} {U_EpixCore/U_PgpFrontEnd/pgpTxMasters[1]*}
#ConfigProbe ${ilaName} {U_EpixCore/U_PgpFrontEnd/pgpTxSlaves[1]*}
#ConfigProbe ${ilaName} {U_EpixCore/U_PgpFrontEnd/pgpRxMasters[1]*}
#ConfigProbe ${ilaName} {U_EpixCore/U_PgpFrontEnd/pgpRxCtrl[1]*}
#ConfigProbe ${ilaName} {U_EpixCore/U_PgpFrontEnd/U_Pgp2bVarLatWrapper/Pgp2bGtp7VarLat_Inst/MuliLane_Inst/U_Pgp2bLane/U_TxEnGen.U_Pgp2bTx/locLinkReady}
#ConfigProbe ${ilaName} {U_EpixCore/U_PgpFrontEnd/U_Pgp2bVarLatWrapper/Pgp2bGtp7VarLat_Inst/MuliLane_Inst/U_Pgp2bLane/U_TxEnGen.U_Pgp2bTx/cell*}
#ConfigProbe ${ilaName} {U_EpixCore/U_PgpFrontEnd/U_Pgp2bVarLatWrapper/Pgp2bGtp7VarLat_Inst/MuliLane_Inst/U_Pgp2bLane/U_TxEnGen.U_Pgp2bTx/*gateRemPause*}
#ConfigProbe ${ilaName} {U_EpixCore/U_PgpFrontEnd/U_Pgp2bVarLatWrapper/Pgp2bGtp7VarLat_Inst/MuliLane_Inst/U_Pgp2bLane/U_TxEnGen.U_Pgp2bTx/locFifoStatus*}
#ConfigProbe ${ilaName1} {U_EpixCore/U_PgpFrontEnd/pgpRxMasters[1]*}
#ConfigProbe ${ilaName1} {U_EpixCore/U_PgpFrontEnd/pgpRxSlaves[1]*}
#ConfigProbe ${ilaName1} {U_EpixCore/U_PgpFrontEnd/U_Pgp2bVarLatWrapper/Pgp2bGtp7VarLat_Inst/MuliLane_Inst/U_Pgp2bLane/U_TxEnGen.U_Pgp2bTx/U_Pgp2bTxPhy/phyTxDataK*}
#ConfigProbe ${ilaName1} {U_EpixCore/U_PgpFrontEnd/U_Pgp2bVarLatWrapper/Pgp2bGtp7VarLat_Inst/MuliLane_Inst/U_Pgp2bLane/U_TxEnGen.U_Pgp2bTx/U_Pgp2bTxPhy/phyTxData*}

## ADC debug signals
#SetDebugCoreClk ${ilaName} {U_AdcReadout3x/GenAdc[0].U_AdcReadout/sysClk}
#ConfigProbe ${ilaName} {U_AdcReadout3x/GenAdc[0].U_AdcReadout/adcData[*][*]}
#ConfigProbe ${ilaName} {U_AdcReadout3x/GenAdc[1].U_AdcReadout/adcData[*][*]}
#ConfigProbe ${ilaName} {U_AdcReadout3x/U_AdcMon/adcData[*][*]}
#ConfigProbe ${ilaName} {U_AdcReadout3x/GenAdc[0].U_AdcReadout/v[slip]0_out*}
#ConfigProbe ${ilaName} {U_AdcReadout3x/GenAdc[1].U_AdcReadout/v[slip]0_out*}
#ConfigProbe ${ilaName} {U_AdcReadout3x/U_AdcMon/v[slip]0_out*}
#ConfigProbe ${ilaName} {U_AdcStream/r[*}

############################################################################

## Delete the last unused port
delete_debug_port [get_debug_ports [GetCurrentProbe ${ilaName}]]
#delete_debug_port [get_debug_ports [GetCurrentProbe ${ilaName1}]]

## Write the port map file
write_debug_probes -force ${PROJ_DIR}/debug/debug_probes.ltx
