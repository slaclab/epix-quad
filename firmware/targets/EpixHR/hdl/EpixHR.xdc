##############################################################################
## This file is part of 'EPIX Development Firmware'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'EPIX Development Firmware', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################
#######################################
## Timing Constraints                ##
#######################################

create_clock -name gtRefClk0P   -period  6.400 [get_ports gtRefClk0P]
create_clock -name pgpClk       -period  6.400 [get_pins {U_EpixHR/U_PgpFrontEnd/G_PGP.U_Pgp2bVarLatWrapper/Pgp2bGtp7VarLat_Inst/MuliLane_Inst/GTP7_CORE_GEN[0].Gtp7Core_Inst/gtpe2_i/TXOUTCLK}]
create_clock -name adcDoClkP    -period  2.857 [get_ports {adcDoClkP[2]}]

create_generated_clock -name iDelayCtrlClk [get_pins {U_EpixHR/U_CoreClockGen/MmcmGen.U_Mmcm/CLKOUT4}]
create_generated_clock -name coreClk       [get_pins {U_EpixHR/U_CoreClockGen/MmcmGen.U_Mmcm/CLKOUT1}]
create_generated_clock -name bitClk        [get_pins {U_EpixHR/U_CoreClockGen/MmcmGen.U_Mmcm/CLKOUT0}]
create_generated_clock -name asicRdClk     [get_pins {U_EpixHR/U_CoreClockGen/MmcmGen.U_Mmcm/CLKOUT2}]
create_generated_clock -name asicRefClk    [get_pins {U_EpixHR/U_CoreClockGen/MmcmGen.U_Mmcm/CLKOUT3}]
create_generated_clock -name byteClk       [get_pins {U_EpixHR/U_BUFR/O}]
create_generated_clock -name progClk      [get_pins {U_EpixHR/U_Iprog7Series/DIVCLK_GEN.BUFR_ICPAPE2/O}]
create_generated_clock -name adcMonBitClkR [get_pins {U_EpixHR/U_MonAdcReadout/U_AdcBitClkR/O}]

set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks pgpClk] -group [get_clocks -include_generated_clocks gtRefClk0P] -group [get_clocks -include_generated_clocks coreClk] -group [get_clocks -include_generated_clocks iDelayCtrlClk] -group [get_clocks -include_generated_clocks bitClk] -group [get_clocks -include_generated_clocks asicRdClk] -group [get_clocks -include_generated_clocks asicRefClk] -group [get_clocks -include_generated_clocks byteClk] -group [get_clocks -include_generated_clocks adcMonDoClkP] -group [get_clocks -include_generated_clocks adcMonBitClkR] -group [get_clocks -include_generated_clocks progClk]

#######################################
## Pin locations, IO standards, etc. ##
#######################################

# Boot Memory Port Mapping
set_property PACKAGE_PIN T19 [get_ports bootCsL]
set_property IOSTANDARD LVCMOS33 [get_ports bootCsL]
set_property PACKAGE_PIN P22 [get_ports bootMosi]
set_property IOSTANDARD LVCMOS33 [get_ports bootMosi]
set_property PACKAGE_PIN R22 [get_ports bootMiso]
set_property IOSTANDARD LVCMOS33 [get_ports bootMiso]

set_property PACKAGE_PIN Y6 [get_ports {led[0]}]
set_property PACKAGE_PIN AA6 [get_ports {led[1]}]
set_property PACKAGE_PIN L5 [get_ports {led[2]}]
set_property PACKAGE_PIN L4 [get_ports {led[3]}]
set_property IOSTANDARD LVCMOS25 [get_ports {led[*]}]

set_property PACKAGE_PIN T18 [get_ports powerGood]
set_property IOSTANDARD LVCMOS33 [get_ports powerGood]

set_property PACKAGE_PIN T16 [get_ports analogCardDigPwrEn]
set_property PACKAGE_PIN U16 [get_ports analogCardAnaPwrEn]
set_property IOSTANDARD LVCMOS25 [get_ports analogCard*PwrEn]

set_property PACKAGE_PIN P2 [get_ports SYNC_ANA_DCDC]
set_property IOSTANDARD LVCMOS25 [get_ports SYNC_ANA_DCDC]

set_property PACKAGE_PIN F6 [get_ports gtRefClk0P]
#set_property PACKAGE_PIN E6 [get_ports {gtRefClk0N}]

set_property PACKAGE_PIN A8 [get_ports gtDataRxN]
set_property PACKAGE_PIN B8 [get_ports gtDataRxP]
set_property PACKAGE_PIN A4 [get_ports gtDataTxN]
set_property PACKAGE_PIN B4 [get_ports gtDataTxP]

set_property PACKAGE_PIN R16 [get_ports sfpDisable]
set_property IOSTANDARD LVCMOS33 [get_ports sfpDisable]

set_property PACKAGE_PIN W17 [get_ports vBiasDacSclk]
set_property PACKAGE_PIN V17 [get_ports vBiasDacDin]
set_property PACKAGE_PIN AA18 [get_ports vBiasDacClrb]
set_property PACKAGE_PIN AB18 [get_ports {vBiasDacCsb[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vBiasDacCsb[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports vBiasDacClrb]
set_property IOSTANDARD LVCMOS33 [get_ports vBiasDacDin]
set_property IOSTANDARD LVCMOS33 [get_ports vBiasDacSclk]
set_property PACKAGE_PIN AB7 [get_ports {vBiasDacCsb[4]}]
set_property IOSTANDARD LVCMOS25 [get_ports {vBiasDacCsb[4]}]

set_property PACKAGE_PIN V15 [get_ports {vBiasDacCsb[2]}]
set_property PACKAGE_PIN U15 [get_ports {vBiasDacCsb[1]}]
set_property PACKAGE_PIN U7 [get_ports {vBiasDacCsb[3]}]
set_property IOSTANDARD LVCMOS25 [get_ports {vBiasDacCsb[1]}]
set_property IOSTANDARD LVCMOS25 [get_ports {vBiasDacCsb[2]}]
set_property IOSTANDARD LVCMOS25 [get_ports {vBiasDacCsb[3]}]

set_property PACKAGE_PIN V8 [get_ports vWFDacCsL]
set_property PACKAGE_PIN V9 [get_ports vWFDacLdacL]
set_property IOSTANDARD LVCMOS25 [get_ports vWFDacCsL]
set_property IOSTANDARD LVCMOS25 [get_ports vWFDacLdacL]

set_property PACKAGE_PIN AB21 [get_ports runTg]
set_property PACKAGE_PIN U20 [get_ports daqTg]
set_property PACKAGE_PIN V20 [get_ports mps]
set_property PACKAGE_PIN AB22 [get_ports tgOut]
set_property IOSTANDARD LVCMOS33 [get_ports runTg]
set_property IOSTANDARD LVCMOS33 [get_ports daqTg]
set_property IOSTANDARD LVCMOS33 [get_ports mps]
set_property IOSTANDARD LVCMOS33 [get_ports tgOut]

set_property PACKAGE_PIN P14 [get_ports snIoAdcCard]
set_property IOSTANDARD LVCMOS33 [get_ports snIoAdcCard]
set_property PULLUP true [get_ports snIoAdcCard]
set_property PACKAGE_PIN W2 [get_ports asic01DM1]
set_property IOSTANDARD LVCMOS25 [get_ports asic01DM1]
set_property PULLUP true [get_ports asic01DM1]
set_property PACKAGE_PIN Y2 [get_ports asic01DM2]
set_property IOSTANDARD LVCMOS25 [get_ports asic01DM2]
set_property PULLUP true [get_ports asic01DM2]
set_property PACKAGE_PIN M5 [get_ports snIoCarrier]
set_property IOSTANDARD LVCMOS25 [get_ports snIoCarrier]
set_property PULLUP true [get_ports snIoCarrier]

set_property PACKAGE_PIN V18 [get_ports slowAdcSclk]
set_property IOSTANDARD LVCMOS33 [get_ports slowAdcSclk]
set_property PACKAGE_PIN V19 [get_ports slowAdcDin]
set_property IOSTANDARD LVCMOS33 [get_ports slowAdcDin]
set_property PACKAGE_PIN Y19 [get_ports slowAdcCsb]
set_property IOSTANDARD LVCMOS33 [get_ports slowAdcCsb]
set_property PACKAGE_PIN Y18 [get_ports slowAdcRefClk]
set_property IOSTANDARD LVCMOS33 [get_ports slowAdcRefClk]
set_property PACKAGE_PIN Y17 [get_ports slowAdcSync]
set_property IOSTANDARD LVCMOS25 [get_ports slowAdcSync]
set_property PACKAGE_PIN Y16 [get_ports slowAdcDrdy]
set_property IOSTANDARD LVCMOS25 [get_ports slowAdcDrdy]
set_property PACKAGE_PIN Y9 [get_ports slowAdcDout]
set_property IOSTANDARD LVCMOS25 [get_ports slowAdcDout]

set_property PACKAGE_PIN Y12 [get_ports adcSpiData]
## set_property PULLUP TRUE [get_ports {adcSpiData}]
set_property PACKAGE_PIN W16 [get_ports adcSpiClk]
#set_property PACKAGE_PIN  U15 [get_ports {adcSpiCsb[0]}]
#set_property PACKAGE_PIN  V15 [get_ports {adcSpiCsb[1]}]
set_property PACKAGE_PIN W15 [get_ports {adcSpiCsb[2]}]
#set_property PACKAGE_PIN   U7 [get_ports {adcPdwn01}]
set_property PACKAGE_PIN W9 [get_ports adcPdwnMon]
set_property IOSTANDARD LVCMOS25 [get_ports adcSpi*]
set_property IOSTANDARD LVCMOS25 [get_ports adcPdwn*]

set_property PACKAGE_PIN U6 [get_ports asicSaciCmd]
set_property PACKAGE_PIN V5 [get_ports asicSaciClk]
set_property PACKAGE_PIN AA16 [get_ports {asicSaciSel[0]}]
set_property PACKAGE_PIN AB13 [get_ports {asicSaciSel[1]}]
set_property PACKAGE_PIN AB8 [get_ports asicSaciRsp]
set_property IOSTANDARD LVCMOS25 [get_ports asicSaci*]

set_property PACKAGE_PIN AB6 [get_ports asicTpulse]
set_property PACKAGE_PIN AA8 [get_ports asicStart]
set_property PACKAGE_PIN B1 [get_ports asicPPbe]
set_property IOSTANDARD LVCMOS25 [get_ports asicTpulse]
set_property IOSTANDARD LVCMOS25 [get_ports asicStart]
set_property IOSTANDARD LVCMOS25 [get_ports asicPPbe]

set_property PACKAGE_PIN AA13 [get_ports asicSR0]
set_property PACKAGE_PIN AB16 [get_ports asicPpmat]
set_property PACKAGE_PIN R1 [get_ports asicGlblRst]
set_property PACKAGE_PIN Y13 [get_ports asicSync]
set_property PACKAGE_PIN AB17 [get_ports asicAcq]
set_property PACKAGE_PIN AB3 [get_ports asicVid]
set_property IOSTANDARD LVCMOS25 [get_ports asicSR0]
set_property IOSTANDARD LVCMOS25 [get_ports asicPpmat]
set_property IOSTANDARD LVCMOS25 [get_ports asicGlblRst]
set_property IOSTANDARD LVCMOS25 [get_ports asicSync]
set_property IOSTANDARD LVCMOS25 [get_ports asicAcq]
set_property IOSTANDARD LVCMOS25 [get_ports asicVid]

set_property PACKAGE_PIN U2 [get_ports {asicDoutP[0]}]
set_property PACKAGE_PIN V2 [get_ports {asicDoutM[0]}]
set_property PACKAGE_PIN U3 [get_ports {asicDoutP[1]}]
set_property PACKAGE_PIN V3 [get_ports {asicDoutM[1]}]
set_property IOSTANDARD LVDS_25 [get_ports asicDoutP*]
set_property DIFF_TERM true [get_ports {asicDoutP[*]}]
set_property DIFF_TERM TRUE [get_ports {asicDoutM[1]}]
set_property DIFF_TERM TRUE [get_ports {asicDoutM[0]}]

set_property IOSTANDARD LVDS_25 [get_ports asicRoClk*]
set_property PACKAGE_PIN W1 [get_ports {asicRoClkP[1]}]
set_property PACKAGE_PIN R3 [get_ports {asicRoClkP[0]}]

set_property IOSTANDARD LVDS_25 [get_ports asicRefClk*]
set_property PACKAGE_PIN G1 [get_ports {asicRefClkP[1]}]
set_property PACKAGE_PIN E1 [get_ports {asicRefClkP[0]}]

set_property PACKAGE_PIN AB2 [get_ports asicTsRst]
set_property PACKAGE_PIN AA5 [get_ports asicTsAdcClk]
set_property PACKAGE_PIN AB5 [get_ports asicTsShClk]
set_property PACKAGE_PIN M1 [get_ports asicTsSync]
set_property PACKAGE_PIN W5 [get_ports {asicTsData[0]}]
set_property PACKAGE_PIN W6 [get_ports {asicTsData[1]}]
set_property PACKAGE_PIN T6 [get_ports {asicTsData[2]}]
set_property PACKAGE_PIN R6 [get_ports {asicTsData[3]}]
set_property PACKAGE_PIN V7 [get_ports {asicTsData[4]}]
set_property PACKAGE_PIN W7 [get_ports {asicTsData[5]}]
set_property PACKAGE_PIN B2 [get_ports {asicTsData[6]}]
set_property PACKAGE_PIN C2 [get_ports {asicTsData[7]}]
set_property PACKAGE_PIN D2 [get_ports {asicTsData[8]}]
set_property PACKAGE_PIN E2 [get_ports {asicTsData[9]}]
set_property PACKAGE_PIN E3 [get_ports {asicTsData[10]}]
set_property PACKAGE_PIN F3 [get_ports {asicTsData[11]}]
set_property PACKAGE_PIN G2 [get_ports {asicTsData[12]}]
set_property PACKAGE_PIN H2 [get_ports {asicTsData[13]}]
set_property PACKAGE_PIN H5 [get_ports {asicTsData[14]}]
set_property PACKAGE_PIN J5 [get_ports {asicTsData[15]}]
set_property IOSTANDARD LVCMOS25 [get_ports asicTs*]

set_property IOSTANDARD LVDS_25 [get_ports adcClkP]
set_property PACKAGE_PIN T14 [get_ports adcClkP]
set_property PACKAGE_PIN T15 [get_ports adcClkM]


set_property PACKAGE_PIN V13 [get_ports adcDoClkP]
set_property PACKAGE_PIN V14 [get_ports adcDoClkM]
set_property IOSTANDARD LVDS_25 [get_ports adcDoClkP]
set_property DIFF_TERM TRUE [get_ports adcDoClkP]

set_property PACKAGE_PIN W11 [get_ports adcFrameClkP]
set_property PACKAGE_PIN W12 [get_ports adcFrameClkM]
set_property IOSTANDARD LVDS_25 [get_ports adcFrameClkP]
set_property DIFF_TERM TRUE [get_ports adcFrameClkP]

set_property PACKAGE_PIN V10 [get_ports {adcDoP[0]}]
set_property PACKAGE_PIN W10 [get_ports {adcDoM[0]}]
set_property PACKAGE_PIN AA9 [get_ports {adcDoP[1]}]
set_property PACKAGE_PIN AB10 [get_ports {adcDoM[1]}]
set_property PACKAGE_PIN W14 [get_ports {adcDoP[2]}]
set_property PACKAGE_PIN Y14 [get_ports {adcDoM[2]}]
set_property PACKAGE_PIN AA15 [get_ports {adcDoP[3]}]
set_property PACKAGE_PIN AB15 [get_ports {adcDoM[3]}]
set_property IOSTANDARD LVDS_25 [get_ports {adcDoP[0]}]
set_property DIFF_TERM TRUE [get_ports {adcDoP[0]}]
set_property IOSTANDARD LVDS_25 [get_ports {adcDoP[1]}]
set_property DIFF_TERM TRUE [get_ports {adcDoP[1]}]
set_property IOSTANDARD LVDS_25 [get_ports {adcDoP[2]}]
set_property DIFF_TERM TRUE [get_ports {adcDoP[2]}]
set_property IOSTANDARD LVDS_25 [get_ports {adcDoP[3]}]
set_property DIFF_TERM TRUE [get_ports {adcDoP[3]}]

#######################################
## Configuration properties          ##
#######################################
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR Yes [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE No [current_design]
set_property BITSTREAM.STARTUP.STARTUPCLK Cclk [current_design]

create_debug_core u_ila_1 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_1]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_1]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_1]
set_property C_DATA_DEPTH 2048 [get_debug_cores u_ila_1]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_1]
set_property C_INPUT_PIPE_STAGES 2 [get_debug_cores u_ila_1]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_1]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_1]
set_property port_width 1 [get_debug_ports u_ila_1/clk]
connect_debug_port u_ila_1/clk [get_nets [list U_EpixHR/coreClk]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe0]
set_property port_width 1 [get_debug_ports u_ila_1/probe0]
connect_debug_port u_ila_1/probe0 [get_nets [list U_EpixHR/iasicTsSync]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe1]
set_property port_width 16 [get_debug_ports u_ila_1/probe1]
connect_debug_port u_ila_1/probe1 [get_nets [list {U_EpixHR/iasicTsData[0]} {U_EpixHR/iasicTsData[1]} {U_EpixHR/iasicTsData[2]} {U_EpixHR/iasicTsData[3]} {U_EpixHR/iasicTsData[4]} {U_EpixHR/iasicTsData[5]} {U_EpixHR/iasicTsData[6]} {U_EpixHR/iasicTsData[7]} {U_EpixHR/iasicTsData[8]} {U_EpixHR/iasicTsData[9]} {U_EpixHR/iasicTsData[10]} {U_EpixHR/iasicTsData[11]} {U_EpixHR/iasicTsData[12]} {U_EpixHR/iasicTsData[13]} {U_EpixHR/iasicTsData[14]} {U_EpixHR/iasicTsData[15]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe2]
set_property port_width 1 [get_debug_ports u_ila_1/probe2]
connect_debug_port u_ila_1/probe2 [get_nets [list U_EpixHR/acqStart]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe3]
set_property port_width 1 [get_debug_ports u_ila_1/probe3]
connect_debug_port u_ila_1/probe3 [get_nets [list U_EpixHR/byteClk]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe4]
set_property port_width 272 [get_debug_ports u_ila_1/probe4]
connect_debug_port u_ila_1/probe4 [get_nets [list {U_EpixHR/U_AXI_TS_ExtClk/r[adcClk]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcClkHalfT][0]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcClkHalfT][1]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcClkHalfT][2]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcClkHalfT][3]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcClkHalfT][4]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcClkHalfT][5]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcClkHalfT][6]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcClkHalfT][7]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcClkHalfT][8]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcClkHalfT][9]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcClkHalfT][10]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcClkHalfT][11]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcClkHalfT][12]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcClkHalfT][13]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcClkHalfT][14]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcClkHalfT][15]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcClkHalfT][16]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcClkHalfT][17]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcClkHalfT][18]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcClkHalfT][19]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcClkHalfT][20]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcClkHalfT][21]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcClkHalfT][22]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcClkHalfT][23]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcClkHalfT][24]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcClkHalfT][25]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcClkHalfT][26]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcClkHalfT][27]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcClkHalfT][28]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcClkHalfT][29]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcClkHalfT][30]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcClkHalfT][31]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcCnt][0]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcCnt][1]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcCnt][2]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcCnt][3]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcCnt][4]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcCnt][5]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcCnt][6]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcCnt][7]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcCnt][8]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcCnt][9]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcCnt][10]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcCnt][11]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcCnt][12]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcCnt][13]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcCnt][14]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcCnt][15]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcCnt][16]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcCnt][17]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcCnt][18]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcCnt][19]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcCnt][20]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcCnt][21]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcCnt][22]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcCnt][23]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcCnt][24]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcCnt][25]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcCnt][26]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcCnt][27]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcCnt][28]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcCnt][29]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcCnt][30]} {U_EpixHR/U_AXI_TS_ExtClk/r[adcCnt][31]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRst]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstDelay][0]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstDelay][1]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstDelay][2]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstDelay][3]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstDelay][4]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstDelay][5]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstDelay][6]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstDelay][7]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstDelay][8]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstDelay][9]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstDelay][10]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstDelay][11]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstDelay][12]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstDelay][13]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstDelay][14]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstDelay][15]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstDelay][16]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstDelay][17]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstDelay][18]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstDelay][19]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstDelay][20]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstDelay][21]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstDelay][22]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstDelay][23]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstDelay][24]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstDelay][25]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstDelay][26]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstDelay][27]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstDelay][28]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstDelay][29]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstDelay][30]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstDelay][31]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstPolarity]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstWidth][0]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstWidth][1]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstWidth][2]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstWidth][3]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstWidth][4]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstWidth][5]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstWidth][6]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstWidth][7]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstWidth][8]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstWidth][9]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstWidth][10]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstWidth][11]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstWidth][12]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstWidth][13]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstWidth][14]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstWidth][15]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstWidth][16]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstWidth][17]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstWidth][18]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstWidth][19]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstWidth][20]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstWidth][21]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstWidth][22]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstWidth][23]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstWidth][24]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstWidth][25]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstWidth][26]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstWidth][27]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstWidth][28]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstWidth][29]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstWidth][30]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SDRstWidth][31]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClk]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkDelay][0]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkDelay][1]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkDelay][2]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkDelay][3]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkDelay][4]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkDelay][5]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkDelay][6]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkDelay][7]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkDelay][8]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkDelay][9]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkDelay][10]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkDelay][11]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkDelay][12]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkDelay][13]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkDelay][14]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkDelay][15]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkDelay][16]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkDelay][17]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkDelay][18]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkDelay][19]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkDelay][20]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkDelay][21]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkDelay][22]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkDelay][23]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkDelay][24]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkDelay][25]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkDelay][26]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkDelay][27]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkDelay][28]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkDelay][29]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkDelay][30]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkDelay][31]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkPolarity]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkWidth][0]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkWidth][1]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkWidth][2]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkWidth][3]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkWidth][4]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkWidth][5]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkWidth][6]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkWidth][7]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkWidth][8]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkWidth][9]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkWidth][10]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkWidth][11]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkWidth][12]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkWidth][13]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkWidth][14]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkWidth][15]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkWidth][16]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkWidth][17]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkWidth][18]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkWidth][19]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkWidth][20]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkWidth][21]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkWidth][22]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkWidth][23]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkWidth][24]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkWidth][25]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkWidth][26]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkWidth][27]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkWidth][28]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkWidth][29]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkWidth][30]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqReg][SHClkWidth][31]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqTimeCnt][0]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqTimeCnt][1]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqTimeCnt][2]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqTimeCnt][3]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqTimeCnt][4]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqTimeCnt][5]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqTimeCnt][6]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqTimeCnt][7]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqTimeCnt][8]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqTimeCnt][9]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqTimeCnt][10]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqTimeCnt][11]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqTimeCnt][12]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqTimeCnt][13]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqTimeCnt][14]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqTimeCnt][15]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqTimeCnt][16]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqTimeCnt][17]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqTimeCnt][18]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqTimeCnt][19]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqTimeCnt][20]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqTimeCnt][21]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqTimeCnt][22]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqTimeCnt][23]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqTimeCnt][24]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqTimeCnt][25]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqTimeCnt][26]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqTimeCnt][27]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqTimeCnt][28]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqTimeCnt][29]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqTimeCnt][30]} {U_EpixHR/U_AXI_TS_ExtClk/r[asicAcqTimeCnt][31]} {U_EpixHR/U_AXI_TS_ExtClk/r[axiReadSlave][arready]} {U_EpixHR/U_AXI_TS_ExtClk/r[axiReadSlave][rdata][0]} {U_EpixHR/U_AXI_TS_ExtClk/r[axiReadSlave][rdata][1]} {U_EpixHR/U_AXI_TS_ExtClk/r[axiReadSlave][rdata][2]} {U_EpixHR/U_AXI_TS_ExtClk/r[axiReadSlave][rdata][3]} {U_EpixHR/U_AXI_TS_ExtClk/r[axiReadSlave][rdata][4]} {U_EpixHR/U_AXI_TS_ExtClk/r[axiReadSlave][rdata][5]} {U_EpixHR/U_AXI_TS_ExtClk/r[axiReadSlave][rdata][6]} {U_EpixHR/U_AXI_TS_ExtClk/r[axiReadSlave][rdata][7]} {U_EpixHR/U_AXI_TS_ExtClk/r[axiReadSlave][rdata][8]} {U_EpixHR/U_AXI_TS_ExtClk/r[axiReadSlave][rdata][9]} {U_EpixHR/U_AXI_TS_ExtClk/r[axiReadSlave][rdata][10]} {U_EpixHR/U_AXI_TS_ExtClk/r[axiReadSlave][rdata][11]} {U_EpixHR/U_AXI_TS_ExtClk/r[axiReadSlave][rdata][12]} {U_EpixHR/U_AXI_TS_ExtClk/r[axiReadSlave][rdata][13]} {U_EpixHR/U_AXI_TS_ExtClk/r[axiReadSlave][rdata][14]} {U_EpixHR/U_AXI_TS_ExtClk/r[axiReadSlave][rdata][15]} {U_EpixHR/U_AXI_TS_ExtClk/r[axiReadSlave][rdata][16]} {U_EpixHR/U_AXI_TS_ExtClk/r[axiReadSlave][rdata][17]} {U_EpixHR/U_AXI_TS_ExtClk/r[axiReadSlave][rdata][18]} {U_EpixHR/U_AXI_TS_ExtClk/r[axiReadSlave][rdata][19]} {U_EpixHR/U_AXI_TS_ExtClk/r[axiReadSlave][rdata][20]} {U_EpixHR/U_AXI_TS_ExtClk/r[axiReadSlave][rdata][21]} {U_EpixHR/U_AXI_TS_ExtClk/r[axiReadSlave][rdata][22]} {U_EpixHR/U_AXI_TS_ExtClk/r[axiReadSlave][rdata][23]} {U_EpixHR/U_AXI_TS_ExtClk/r[axiReadSlave][rdata][24]} {U_EpixHR/U_AXI_TS_ExtClk/r[axiReadSlave][rdata][25]} {U_EpixHR/U_AXI_TS_ExtClk/r[axiReadSlave][rdata][26]} {U_EpixHR/U_AXI_TS_ExtClk/r[axiReadSlave][rdata][27]} {U_EpixHR/U_AXI_TS_ExtClk/r[axiReadSlave][rdata][28]} {U_EpixHR/U_AXI_TS_ExtClk/r[axiReadSlave][rdata][29]} {U_EpixHR/U_AXI_TS_ExtClk/r[axiReadSlave][rdata][30]} {U_EpixHR/U_AXI_TS_ExtClk/r[axiReadSlave][rdata][31]} {U_EpixHR/U_AXI_TS_ExtClk/r[axiReadSlave][rresp][0]} {U_EpixHR/U_AXI_TS_ExtClk/r[axiReadSlave][rresp][1]} {U_EpixHR/U_AXI_TS_ExtClk/r[axiReadSlave][rvalid]} {U_EpixHR/U_AXI_TS_ExtClk/r[axiWriteSlave][awready]} {U_EpixHR/U_AXI_TS_ExtClk/r[axiWriteSlave][bresp][0]} {U_EpixHR/U_AXI_TS_ExtClk/r[axiWriteSlave][bresp][1]} {U_EpixHR/U_AXI_TS_ExtClk/r[axiWriteSlave][bvalid]} {U_EpixHR/U_AXI_TS_ExtClk/r[axiWriteSlave][wready]} {U_EpixHR/U_AXI_TS_ExtClk/r[enWaveforms]} {U_EpixHR/U_AXI_TS_ExtClk/r[usrRst]}]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets u_ila_1_coreClk]
