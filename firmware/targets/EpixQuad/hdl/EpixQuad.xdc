##############################################################################
## This file is part of 'LZ Test Stand Firmware'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'LZ Test Stand Firmware', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

##########################
## Timing Constraints   ##
##########################

create_clock -name pgpClkP   -period 6.400 [get_ports {pgpClkP}]
create_clock -name ddrClkP   -period 5.000 [get_ports {c0_sys_clk_p}]

create_generated_clock -name pgpClk    [get_pins {U_PGP/U_PLL0/PllGen.U_Pll/CLKOUT0}]
create_generated_clock -name sysClk    [get_pins {U_PGP/U_PLL1/MmcmGen.U_Mmcm/CLKOUT0}]
create_generated_clock -name ddrIntClk0 [get_pins {U_SystemCore/U_DDR/U_MigCore/inst/u_ddr4_infrastructure/gen_mmcme3.u_mmcme_adv_inst/CLKOUT0}]
create_generated_clock -name ddrIntClk1 [get_pins {U_SystemCore/U_DDR/U_MigCore/inst/u_ddr4_infrastructure/gen_mmcme3.u_mmcme_adv_inst/CLKOUT6}]

set_clock_groups -asynchronous \
   -group [get_clocks -include_generated_clocks {pgpClk}] \
   -group [get_clocks -include_generated_clocks {sysClk}] \
   -group [get_clocks -include_generated_clocks {pgpClkP}] \
   -group [get_clocks -include_generated_clocks {ddrClkP}] 


set_clock_groups -asynchronous -group [get_clocks {ddrIntClk0}] -group [get_clocks {ddrClkP}]
set_clock_groups -asynchronous -group [get_clocks {ddrIntClk1}] -group [get_clocks {ddrClkP}]

############################
## Pinout Configuration   ##
############################

set_property -dict { PACKAGE_PIN N15 IOSTANDARD ANALOG } [get_ports {vPIn}]

set_property PACKAGE_PIN AD6 [get_ports {pgpClkP}]
set_property PACKAGE_PIN AD5 [get_ports {pgpClkN}]
set_property PACKAGE_PIN AG4 [get_ports pgpTxP]
set_property PACKAGE_PIN AG3 [get_ports pgpTxN]
set_property PACKAGE_PIN AH2 [get_ports pgpRxP]
set_property PACKAGE_PIN AH1 [get_ports pgpRxN]

set_property -dict { PACKAGE_PIN H4   IOSTANDARD LVCMOS18 } [get_ports {dacScl}]
set_property -dict { PACKAGE_PIN H3   IOSTANDARD LVCMOS18 } [get_ports {dacSda}]
set_property -dict { PACKAGE_PIN D15  IOSTANDARD LVCMOS18 } [get_ports {monScl}]
set_property -dict { PACKAGE_PIN E15  IOSTANDARD LVCMOS18 } [get_ports {monSda}]
set_property -dict { PACKAGE_PIN AG15 IOSTANDARD LVCMOS25 } [get_ports {humScl}]
set_property -dict { PACKAGE_PIN AF15 IOSTANDARD LVCMOS25 } [get_ports {humSda}]
set_property -dict { PACKAGE_PIN AH13 IOSTANDARD LVCMOS25 } [get_ports {humRstN}]
set_property -dict { PACKAGE_PIN AE15 IOSTANDARD LVCMOS25 } [get_ports {humAlert}]

set_property -dict { PACKAGE_PIN AD8  IOSTANDARD LVCMOS25 } [get_ports {asicDmSn[3]}]
set_property -dict { PACKAGE_PIN AE13 IOSTANDARD LVCMOS25 } [get_ports {asicDmSn[2]}]
set_property -dict { PACKAGE_PIN AE12 IOSTANDARD LVCMOS25 } [get_ports {asicDmSn[1]}]
set_property -dict { PACKAGE_PIN AG12 IOSTANDARD LVCMOS25 } [get_ports {asicDmSn[0]}]

set_property -dict { PACKAGE_PIN AG14 IOSTANDARD LVCMOS25 } [get_ports {asicAnaEn}]
set_property -dict { PACKAGE_PIN AH14 IOSTANDARD LVCMOS25 } [get_ports {asicDigEn}]
set_property -dict { PACKAGE_PIN AF13 IOSTANDARD LVCMOS25 } [get_ports {ddrVttEn}]
set_property -dict { PACKAGE_PIN M24  IOSTANDARD LVCMOS12 } [get_ports {ddrVttPok}]

set_property -dict { PACKAGE_PIN A24  IOSTANDARD LVCMOS18 } [get_ports {dcdcSync[0]}]
set_property -dict { PACKAGE_PIN D16  IOSTANDARD LVCMOS18 } [get_ports {dcdcSync[1]}]
set_property -dict { PACKAGE_PIN A20  IOSTANDARD LVCMOS18 } [get_ports {dcdcSync[2]}]
set_property -dict { PACKAGE_PIN E23  IOSTANDARD LVCMOS18 } [get_ports {dcdcSync[3]}]
set_property -dict { PACKAGE_PIN L24  IOSTANDARD LVCMOS18 } [get_ports {dcdcSync[4]}]
set_property -dict { PACKAGE_PIN L23  IOSTANDARD LVCMOS18 } [get_ports {dcdcSync[5]}]
set_property -dict { PACKAGE_PIN K21  IOSTANDARD LVCMOS18 } [get_ports {dcdcSync[6]}]
set_property -dict { PACKAGE_PIN K20  IOSTANDARD LVCMOS18 } [get_ports {dcdcSync[7]}]
set_property -dict { PACKAGE_PIN J28  IOSTANDARD LVCMOS18 } [get_ports {dcdcSync[8]}]
set_property -dict { PACKAGE_PIN D26  IOSTANDARD LVCMOS18 } [get_ports {dcdcSync[9]}]
set_property -dict { PACKAGE_PIN F27  IOSTANDARD LVCMOS18 } [get_ports {dcdcSync[10]}]

set_property -dict { PACKAGE_PIN AG24 IOSTANDARD LVCMOS25 } [get_ports {dcdcEn[3]}]
set_property -dict { PACKAGE_PIN AG21 IOSTANDARD LVCMOS25 } [get_ports {dcdcEn[2]}]
set_property -dict { PACKAGE_PIN AG22 IOSTANDARD LVCMOS25 } [get_ports {dcdcEn[1]}]
set_property -dict { PACKAGE_PIN AH22 IOSTANDARD LVCMOS25 } [get_ports {dcdcEn[0]}]

set_property -dict { PACKAGE_PIN M27  IOSTANDARD LVCMOS12 } [get_ports {tempAlertL}]

set_property -dict { PACKAGE_PIN AH9  IOSTANDARD LVCMOS25 } [get_ports {asicSaciResp[3]}]
set_property -dict { PACKAGE_PIN AH8  IOSTANDARD LVCMOS25 } [get_ports {asicSaciResp[2]}]
set_property -dict { PACKAGE_PIN AG11 IOSTANDARD LVCMOS25 } [get_ports {asicSaciResp[1]}]
set_property -dict { PACKAGE_PIN AH11 IOSTANDARD LVCMOS25 } [get_ports {asicSaciResp[0]}]
set_property -dict { PACKAGE_PIN AG16 IOSTANDARD LVCMOS25 } [get_ports {asicSaciClk[3]}]
set_property -dict { PACKAGE_PIN AH16 IOSTANDARD LVCMOS25 } [get_ports {asicSaciClk[2]}]
set_property -dict { PACKAGE_PIN AH21 IOSTANDARD LVCMOS25 } [get_ports {asicSaciClk[1]}]
set_property -dict { PACKAGE_PIN AD23 IOSTANDARD LVCMOS25 } [get_ports {asicSaciClk[0]}]
set_property -dict { PACKAGE_PIN AE23 IOSTANDARD LVCMOS25 } [get_ports {asicSaciCmd[3]}]
set_property -dict { PACKAGE_PIN AE21 IOSTANDARD LVCMOS25 } [get_ports {asicSaciCmd[2]}]
set_property -dict { PACKAGE_PIN AE22 IOSTANDARD LVCMOS25 } [get_ports {asicSaciCmd[1]}]
set_property -dict { PACKAGE_PIN AF24 IOSTANDARD LVCMOS25 } [get_ports {asicSaciCmd[0]}]
set_property -dict { PACKAGE_PIN AB19 IOSTANDARD LVCMOS25 } [get_ports {asicSaciSelL[15]}]
set_property -dict { PACKAGE_PIN AB20 IOSTANDARD LVCMOS25 } [get_ports {asicSaciSelL[14]}]
set_property -dict { PACKAGE_PIN Y19  IOSTANDARD LVCMOS25 } [get_ports {asicSaciSelL[13]}]
set_property -dict { PACKAGE_PIN AA19 IOSTANDARD LVCMOS25 } [get_ports {asicSaciSelL[12]}]
set_property -dict { PACKAGE_PIN Y18  IOSTANDARD LVCMOS25 } [get_ports {asicSaciSelL[11]}]
set_property -dict { PACKAGE_PIN AA18 IOSTANDARD LVCMOS25 } [get_ports {asicSaciSelL[10]}]
set_property -dict { PACKAGE_PIN AA17 IOSTANDARD LVCMOS25 } [get_ports {asicSaciSelL[9]}]
set_property -dict { PACKAGE_PIN AB17 IOSTANDARD LVCMOS25 } [get_ports {asicSaciSelL[8]}]
set_property -dict { PACKAGE_PIN Y16  IOSTANDARD LVCMOS25 } [get_ports {asicSaciSelL[7]}]
set_property -dict { PACKAGE_PIN Y17  IOSTANDARD LVCMOS25 } [get_ports {asicSaciSelL[6]}]
set_property -dict { PACKAGE_PIN AB16 IOSTANDARD LVCMOS25 } [get_ports {asicSaciSelL[5]}]
set_property -dict { PACKAGE_PIN AC16 IOSTANDARD LVCMOS25 } [get_ports {asicSaciSelL[4]}]
set_property -dict { PACKAGE_PIN AA15 IOSTANDARD LVCMOS25 } [get_ports {asicSaciSelL[3]}]
set_property -dict { PACKAGE_PIN AC21 IOSTANDARD LVCMOS25 } [get_ports {asicSaciSelL[2]}]
set_property -dict { PACKAGE_PIN AD21 IOSTANDARD LVCMOS25 } [get_ports {asicSaciSelL[1]}]
set_property -dict { PACKAGE_PIN AC19 IOSTANDARD LVCMOS25 } [get_ports {asicSaciSelL[0]}]
set_property -dict { PACKAGE_PIN AD19 IOSTANDARD LVCMOS25 } [get_ports {asicAcq[3]}]
set_property -dict { PACKAGE_PIN AD16 IOSTANDARD LVCMOS25 } [get_ports {asicAcq[2]}]
set_property -dict { PACKAGE_PIN AE16 IOSTANDARD LVCMOS25 } [get_ports {asicAcq[1]}]
set_property -dict { PACKAGE_PIN AC18 IOSTANDARD LVCMOS25 } [get_ports {asicAcq[0]}]
set_property -dict { PACKAGE_PIN AD18 IOSTANDARD LVCMOS25 } [get_ports {asicR0[3]}]
set_property -dict { PACKAGE_PIN AD20 IOSTANDARD LVCMOS25 } [get_ports {asicR0[2]}]
set_property -dict { PACKAGE_PIN AE20 IOSTANDARD LVCMOS25 } [get_ports {asicR0[1]}]
set_property -dict { PACKAGE_PIN AE17 IOSTANDARD LVCMOS25 } [get_ports {asicR0[0]}]
set_property -dict { PACKAGE_PIN AE18 IOSTANDARD LVCMOS25 } [get_ports {asicGr[3]}]
set_property -dict { PACKAGE_PIN AC17 IOSTANDARD LVCMOS25 } [get_ports {asicGr[2]}]
set_property -dict { PACKAGE_PIN AF17 IOSTANDARD LVCMOS25 } [get_ports {asicGr[1]}]
set_property -dict { PACKAGE_PIN AF18 IOSTANDARD LVCMOS25 } [get_ports {asicGr[0]}]
set_property -dict { PACKAGE_PIN AF19 IOSTANDARD LVCMOS25 } [get_ports {asicSync[3]}]
set_property -dict { PACKAGE_PIN AF20 IOSTANDARD LVCMOS25 } [get_ports {asicSync[2]}]
set_property -dict { PACKAGE_PIN AH18 IOSTANDARD LVCMOS25 } [get_ports {asicSync[1]}]
set_property -dict { PACKAGE_PIN AH19 IOSTANDARD LVCMOS25 } [get_ports {asicSync[0]}]
set_property -dict { PACKAGE_PIN AG19 IOSTANDARD LVCMOS25 } [get_ports {asicPpmat[3]}]
set_property -dict { PACKAGE_PIN AG20 IOSTANDARD LVCMOS25 } [get_ports {asicPpmat[2]}]
set_property -dict { PACKAGE_PIN AG17 IOSTANDARD LVCMOS25 } [get_ports {asicPpmat[1]}]
set_property -dict { PACKAGE_PIN AH17 IOSTANDARD LVCMOS25 } [get_ports {asicPpmat[0]}]

set_property PACKAGE_PIN AH23  [get_ports {asicRoClkP[1]}]
set_property PACKAGE_PIN AF22  [get_ports {asicRoClkP[0]}]
set_property PACKAGE_PIN Y10   [get_ports {asicDoutP[15]}]
set_property PACKAGE_PIN AB10  [get_ports {asicDoutP[14]}]
set_property PACKAGE_PIN AC9   [get_ports {asicDoutP[13]}]
set_property PACKAGE_PIN AD11  [get_ports {asicDoutP[12]}]
set_property PACKAGE_PIN AB11  [get_ports {asicDoutP[11]}]
set_property PACKAGE_PIN Y12   [get_ports {asicDoutP[10]}]
set_property PACKAGE_PIN AA12  [get_ports {asicDoutP[9]}]
set_property PACKAGE_PIN Y13   [get_ports {asicDoutP[8]}]
set_property PACKAGE_PIN AB15  [get_ports {asicDoutP[7]}]
set_property PACKAGE_PIN AA14  [get_ports {asicDoutP[6]}]
set_property PACKAGE_PIN AD14  [get_ports {asicDoutP[5]}]
set_property PACKAGE_PIN AC13  [get_ports {asicDoutP[4]}]
set_property PACKAGE_PIN AF10  [get_ports {asicDoutP[3]}]
set_property PACKAGE_PIN AE11  [get_ports {asicDoutP[2]}]
set_property PACKAGE_PIN AE8   [get_ports {asicDoutP[1]}]
set_property PACKAGE_PIN AG10  [get_ports {asicDoutP[0]}]

set_property -dict { IOSTANDARD LVDS_25 DIFF_TERM_ADV TERM_100 } [get_ports {asicDoutP[*]}]
set_property -dict { IOSTANDARD LVDS_25 } [get_ports {asicRoClkP[*]}]



##########################
## Misc. Configurations ##
##########################

set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design] 
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR Yes [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 1 [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE No [current_design]

set_property CFGBVS         {VCCO} [current_design]
set_property CONFIG_VOLTAGE {3.3} [current_design]