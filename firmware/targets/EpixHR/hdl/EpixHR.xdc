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
create_clock -name pgpClk       -period  6.400 [get_pins {U_EpixHR/U_PgpFrontEnd/U_Pgp2bVarLatWrapper/Pgp2bGtp7VarLat_Inst/MuliLane_Inst/GTP7_CORE_GEN[0].Gtp7Core_Inst/gtpe2_i/TXOUTCLK}]
create_clock -name adcMonDoClkP -period  2.857 [get_ports {adcDoClkP[2]}]

create_generated_clock -name iDelayCtrlClk [get_pins {U_EpixHR/U_CoreClockGen/MmcmGen.U_Mmcm/CLKOUT4}]
create_generated_clock -name coreClk       [get_pins {U_EpixHR/U_CoreClockGen/MmcmGen.U_Mmcm/CLKOUT1}]
create_generated_clock -name bitClk        [get_pins {U_EpixHR/U_CoreClockGen/MmcmGen.U_Mmcm/CLKOUT0}]
create_generated_clock -name asicRdClk     [get_pins {U_EpixHR/U_CoreClockGen/MmcmGen.U_Mmcm/CLKOUT2}]
create_generated_clock -name asicRefClk    [get_pins {U_EpixHR/U_CoreClockGen/MmcmGen.U_Mmcm/CLKOUT3}]
create_generated_clock -name byteClk       [get_pins {U_EpixHR/U_BUFR/O}]
create_generated_clock -name progClk      [get_pins {U_EpixHR/U_Iprog7Series/DIVCLK_GEN.BUFR_ICPAPE2/O}]
create_generated_clock -name adcMonBitClkR [get_pins {U_EpixHR/U_MonAdcReadout/U_AdcBitClkR/O}]

set_clock_groups -asynchronous \
    -group [get_clocks -include_generated_clocks pgpClk] \
    -group [get_clocks -include_generated_clocks gtRefClk0P] \
    -group [get_clocks -include_generated_clocks coreClk] \
    -group [get_clocks -include_generated_clocks iDelayCtrlClk] \
    -group [get_clocks -include_generated_clocks bitClk] \
    -group [get_clocks -include_generated_clocks asicRdClk] \
    -group [get_clocks -include_generated_clocks asicRefClk] \
    -group [get_clocks -include_generated_clocks byteClk] \
    -group [get_clocks -include_generated_clocks adcMonDoClkP] \
    -group [get_clocks -include_generated_clocks adcMonBitClkR] \
    -group [get_clocks -include_generated_clocks progClk] 

#######################################
## Pin locations, IO standards, etc. ##
#######################################

# Boot Memory Port Mapping
set_property PACKAGE_PIN T19     [get_ports {bootCsL}]
set_property IOSTANDARD LVCMOS33 [get_ports {bootCsL}] 
set_property PACKAGE_PIN P22     [get_ports {bootMosi}]
set_property IOSTANDARD LVCMOS33 [get_ports {bootMosi}] 
set_property PACKAGE_PIN R22     [get_ports {bootMiso}]
set_property IOSTANDARD LVCMOS33 [get_ports {bootMiso}] 

set_property PACKAGE_PIN Y6  [get_ports {led[0]}]
set_property PACKAGE_PIN AA6 [get_ports {led[1]}]
set_property PACKAGE_PIN L5  [get_ports {led[2]}]
set_property PACKAGE_PIN L4  [get_ports {led[3]}]
set_property IOSTANDARD LVCMOS25 [get_ports {led[*]}]

set_property PACKAGE_PIN T18 [get_ports {powerGood}]
set_property IOSTANDARD LVCMOS33 [get_ports {powerGood}]

set_property PACKAGE_PIN  T16 [get_ports {analogCardDigPwrEn}]
set_property PACKAGE_PIN  U16 [get_ports {analogCardAnaPwrEn}]
set_property IOSTANDARD LVCMOS25 [get_ports {analogCard*PwrEn}]

set_property PACKAGE_PIN  P2  [get_ports {SYNC_ANA_DCDC}]
set_property IOSTANDARD LVCMOS25 [get_ports {SYNC_ANA_DCDC}]

set_property PACKAGE_PIN F6 [get_ports {gtRefClk0P}]
#set_property PACKAGE_PIN E6 [get_ports {gtRefClk0N}]

set_property PACKAGE_PIN B4 [get_ports {gtDataTxP}]
set_property PACKAGE_PIN A4 [get_ports {gtDataTxN}]
set_property PACKAGE_PIN B8 [get_ports {gtDataRxP}]
set_property PACKAGE_PIN A8 [get_ports {gtDataRxN}]

set_property PACKAGE_PIN R16 [get_ports {sfpDisable}]
set_property IOSTANDARD LVCMOS33 [get_ports {sfpDisable}]

set_property PACKAGE_PIN  W17 [get_ports {vBiasDacSclk}]
set_property PACKAGE_PIN  V17 [get_ports {vBiasDacDin}]
set_property PACKAGE_PIN AA18 [get_ports {vBiasDacClrb}]
set_property PACKAGE_PIN AB18 [get_ports {vBiasDacCsb[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vBias*}] 
set_property PACKAGE_PIN AB7 [get_ports {vBiasDacCsb[4]}]
set_property IOSTANDARD LVCMOS25 [get_ports {vBiasDacCsb[4]}] 

set_property PACKAGE_PIN V15 [get_ports {vBiasDacCsb[2]}]
set_property PACKAGE_PIN U15 [get_ports {vBiasDacCsb[1]}]
set_property PACKAGE_PIN U7 [get_ports {vBiasDacCsb[3]}]
set_property IOSTANDARD LVCMOS25 [get_ports {vBiasDacCsb[1]}]
set_property IOSTANDARD LVCMOS25 [get_ports {vBiasDacCsb[2]}]  
set_property IOSTANDARD LVCMOS25 [get_ports {vBiasDacCsb[3]}] 

set_property PACKAGE_PIN V8 [get_ports {vWFDacCsL}]
set_property PACKAGE_PIN V9 [get_ports {vWFDacLdacL}]
set_property IOSTANDARD LVCMOS25 [get_ports {vWFDacCsL}]
set_property IOSTANDARD LVCMOS25 [get_ports {vWFDacLdacL}]  

set_property PACKAGE_PIN AB21 [get_ports {runTg}]
set_property PACKAGE_PIN  U20 [get_ports {daqTg}]
set_property PACKAGE_PIN  V20 [get_ports {mps}]
set_property PACKAGE_PIN AB22 [get_ports {tgOut}]
set_property IOSTANDARD LVCMOS33 [get_ports {runTg}]
set_property IOSTANDARD LVCMOS33 [get_ports {daqTg}]
set_property IOSTANDARD LVCMOS33 [get_ports {mps}]
set_property IOSTANDARD LVCMOS33 [get_ports {tgOut}]

set_property PACKAGE_PIN  P14 [get_ports {snIoAdcCard}]
set_property IOSTANDARD LVCMOS33 [get_ports {snIoAdcCard}]
set_property PULLUP true [get_ports {snIoAdcCard}]
set_property PACKAGE_PIN   W2 [get_ports {asic01DM1}]
set_property IOSTANDARD LVCMOS25 [get_ports {asic01DM1}]
set_property PULLUP true [get_ports {asic01DM1}]
set_property PACKAGE_PIN   Y2 [get_ports {asic01DM2}]
set_property IOSTANDARD LVCMOS25 [get_ports {asic01DM2}]
set_property PULLUP true [get_ports {asic01DM2}]
set_property PACKAGE_PIN  M5 [get_ports {snIoCarrier}]
set_property IOSTANDARD LVCMOS25 [get_ports {snIoCarrier}]
set_property PULLUP true [get_ports {snIoCarrier}]

set_property PACKAGE_PIN  V18 [get_ports {slowAdcSclk}]
set_property IOSTANDARD LVCMOS33 [get_ports {slowAdcSclk}]
set_property PACKAGE_PIN  V19 [get_ports {slowAdcDin}]
set_property IOSTANDARD LVCMOS33 [get_ports {slowAdcDin}]
set_property PACKAGE_PIN  Y19 [get_ports {slowAdcCsb}]
set_property IOSTANDARD LVCMOS33 [get_ports {slowAdcCsb}]
set_property PACKAGE_PIN  Y18 [get_ports {slowAdcRefClk}]
set_property IOSTANDARD LVCMOS33 [get_ports {slowAdcRefClk}]
set_property PACKAGE_PIN  Y17 [get_ports {slowAdcSync}] 
set_property IOSTANDARD LVCMOS25 [get_ports {slowAdcSync}]
set_property PACKAGE_PIN  Y16 [get_ports {slowAdcDrdy}]
set_property IOSTANDARD LVCMOS25 [get_ports {slowAdcDrdy}]
set_property PACKAGE_PIN  Y9  [get_ports {slowAdcDout}]
set_property IOSTANDARD LVCMOS25 [get_ports {slowAdcDout}]

set_property PACKAGE_PIN  Y12 [get_ports {adcSpiData}]
## set_property PULLUP TRUE [get_ports {adcSpiData}]
set_property PACKAGE_PIN  W16 [get_ports {adcSpiClk}]
#set_property PACKAGE_PIN  U15 [get_ports {adcSpiCsb[0]}]
#set_property PACKAGE_PIN  V15 [get_ports {adcSpiCsb[1]}]
set_property PACKAGE_PIN  W15 [get_ports {adcSpiCsb[2]}]
#set_property PACKAGE_PIN   U7 [get_ports {adcPdwn01}]
set_property PACKAGE_PIN   W9 [get_ports {adcPdwnMon}]
set_property IOSTANDARD LVCMOS25 [get_ports {adcSpi*}]
set_property IOSTANDARD LVCMOS25 [get_ports {adcPdwn*}]

set_property PACKAGE_PIN   U6 [get_ports {asicSaciCmd}]
set_property PACKAGE_PIN   V5 [get_ports {asicSaciClk}]
set_property PACKAGE_PIN AA16 [get_ports {asicSaciSel[0]}]
set_property PACKAGE_PIN AB13 [get_ports {asicSaciSel[1]}]
set_property PACKAGE_PIN  AB8 [get_ports {asicSaciRsp}]
set_property IOSTANDARD LVCMOS25 [get_ports {asicSaci*}]

set_property PACKAGE_PIN AB6 [get_ports {asicTpulse}]
set_property PACKAGE_PIN AA8 [get_ports {asicStart}]
set_property PACKAGE_PIN B1 [get_ports {asicPPbe}]
set_property IOSTANDARD LVCMOS25 [get_ports {asicTpulse}]
set_property IOSTANDARD LVCMOS25 [get_ports {asicStart}]
set_property IOSTANDARD LVCMOS25 [get_ports {asicPPbe}]

set_property PACKAGE_PIN AA13 [get_ports {asicSR0}]
set_property PACKAGE_PIN AB16 [get_ports {asicPpmat}]
set_property PACKAGE_PIN   R1 [get_ports {asicGlblRst}]
set_property PACKAGE_PIN  Y13 [get_ports {asicSync}]
set_property PACKAGE_PIN AB17 [get_ports {asicAcq}]
set_property PACKAGE_PIN  AB3 [get_ports {asicVid}]
set_property IOSTANDARD LVCMOS25 [get_ports {asicSR0}]
set_property IOSTANDARD LVCMOS25 [get_ports {asicPpmat}]
set_property IOSTANDARD LVCMOS25 [get_ports {asicGlblRst}]
set_property IOSTANDARD LVCMOS25 [get_ports {asicSync}]
set_property IOSTANDARD LVCMOS25 [get_ports {asicAcq}]
set_property IOSTANDARD LVCMOS25 [get_ports {asicVid}]

set_property PACKAGE_PIN   U2 [get_ports {asicDoutP[0]}]
set_property PACKAGE_PIN   V2 [get_ports {asicDoutM[0]}]
set_property PACKAGE_PIN   U3 [get_ports {asicDoutP[1]}]
set_property PACKAGE_PIN   V3 [get_ports {asicDoutM[1]}]
set_property IOSTANDARD LVDS_25 [get_ports {asicDoutP*}]
set_property DIFF_TERM true [get_ports {asicDoutP[*]}]

set_property PACKAGE_PIN   R3 [get_ports {asicRoClkP[0]}]
set_property PACKAGE_PIN   W1 [get_ports {asicRoClkP[1]}]
set_property IOSTANDARD LVDS_25 [get_ports {asicRoClk*}]

set_property PACKAGE_PIN   E1 [get_ports {asicRefClkP[0]}]
set_property PACKAGE_PIN   G1 [get_ports {asicRefClkP[1]}]
set_property IOSTANDARD LVDS_25 [get_ports {asicRefClk*}]

set_property PACKAGE_PIN   AB2 [get_ports {asicTsRst}]
set_property PACKAGE_PIN   AB5 [get_ports {asicTsAdcClk}]
set_property PACKAGE_PIN   AA5 [get_ports {asicTsShClk}]
set_property PACKAGE_PIN   M1  [get_ports {asicTsSync}]
set_property PACKAGE_PIN   W5  [get_ports {asicTsData[0]}]
set_property PACKAGE_PIN   W6  [get_ports {asicTsData[1]}]
set_property PACKAGE_PIN   T6  [get_ports {asicTsData[2]}]
set_property PACKAGE_PIN   R6  [get_ports {asicTsData[3]}]
set_property PACKAGE_PIN   V7  [get_ports {asicTsData[4]}]
set_property PACKAGE_PIN   W7  [get_ports {asicTsData[5]}]
set_property PACKAGE_PIN   B2  [get_ports {asicTsData[6]}]
set_property PACKAGE_PIN   C2  [get_ports {asicTsData[7]}]
set_property PACKAGE_PIN   E2  [get_ports {asicTsData[8]}]
set_property PACKAGE_PIN   D2  [get_ports {asicTsData[9]}]
set_property PACKAGE_PIN   F3  [get_ports {asicTsData[10]}]
set_property PACKAGE_PIN   E3  [get_ports {asicTsData[11]}]
set_property PACKAGE_PIN   G2  [get_ports {asicTsData[12]}]
set_property PACKAGE_PIN   H2  [get_ports {asicTsData[13]}]
set_property PACKAGE_PIN   H5  [get_ports {asicTsData[14]}]
set_property PACKAGE_PIN   J5  [get_ports {asicTsData[15]}]
set_property IOSTANDARD LVCMOS25 [get_ports {asicTs*}]

set_property PACKAGE_PIN  T14 [get_ports {adcClkP}]
set_property PACKAGE_PIN  T15 [get_ports {adcClkM}]   
set_property IOSTANDARD LVDS_25 [get_ports {adcClkP}]


set_property PACKAGE_PIN  V13 [get_ports {adcDoClkP}]   
set_property PACKAGE_PIN  V14 [get_ports {adcDoClkM}] 
set_property IOSTANDARD LVDS_25 [get_ports {adcDoClkP}]
set_property DIFF_TERM true [get_ports {adcDoClkP}]

set_property PACKAGE_PIN  W11 [get_ports {adcFrameClkP}]
set_property PACKAGE_PIN  W12 [get_ports {adcFrameClkM}]
set_property IOSTANDARD LVDS_25 [get_ports {adcFrameClkP}]
set_property DIFF_TERM true [get_ports {adcFrameClkP}]

set_property PACKAGE_PIN  V10 [get_ports {adcDoP[0]}]
set_property PACKAGE_PIN  W10 [get_ports {adcDoM[0]}]
set_property PACKAGE_PIN  AA9 [get_ports {adcDoP[1]}]
set_property PACKAGE_PIN AB10 [get_ports {adcDoM[1]}]
set_property PACKAGE_PIN  W14 [get_ports {adcDoP[2]}]
set_property PACKAGE_PIN  Y14 [get_ports {adcDoM[2]}]
set_property PACKAGE_PIN AA15 [get_ports {adcDoP[3]}]
set_property PACKAGE_PIN AB15 [get_ports {adcDoM[3]}]
set_property IOSTANDARD LVDS_25 [get_ports {adcDoP[0]}]
set_property DIFF_TERM true [get_ports {adcDoP[0]}]
set_property IOSTANDARD LVDS_25 [get_ports {adcDoP[1]}]
set_property DIFF_TERM true [get_ports {adcDoP[1]}]
set_property IOSTANDARD LVDS_25 [get_ports {adcDoP[2]}]
set_property DIFF_TERM true [get_ports {adcDoP[2]}]
set_property IOSTANDARD LVDS_25 [get_ports {adcDoP[3]}]
set_property DIFF_TERM true [get_ports {adcDoP[3]}]

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
