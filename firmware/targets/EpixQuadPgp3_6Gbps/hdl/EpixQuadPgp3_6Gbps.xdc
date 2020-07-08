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

create_clock -name adc0DClk -period 2.850 [get_ports {adcDClkP[0]}]
create_clock -name adc1DClk -period 2.850 [get_ports {adcDClkP[1]}]
create_clock -name adc2DClk -period 2.850 [get_ports {adcDClkP[2]}]
create_clock -name adc3DClk -period 2.850 [get_ports {adcDClkP[3]}]
create_clock -name adc4DClk -period 2.850 [get_ports {adcDClkP[4]}]
create_clock -name adc5DClk -period 2.850 [get_ports {adcDClkP[5]}]
create_clock -name adc6DClk -period 2.850 [get_ports {adcDClkP[6]}]
create_clock -name adc7DClk -period 2.850 [get_ports {adcDClkP[7]}]
create_clock -name adc8DClk -period 2.850 [get_ports {adcDClkP[8]}]
create_clock -name adc9DClk -period 2.850 [get_ports {adcDClkP[9]}]

create_generated_clock -name sysClk    [get_pins {U_CORE/U_PGP/G_PGPv3.U_PGP/U_PLL1/MmcmGen.U_Mmcm/CLKOUT0}]

create_clock -name pgp3PhyRxClk -period 5.280 [get_pins {U_CORE/U_PGP/G_PGPv3.U_PGP/G_PGP.U_PGP/U_Pgp3GthUsIpWrapper_1/GEN_6G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp6G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_channel_container[2].gen_enabled_channel.gthe3_channel_wrapper_inst/channel_inst/gthe3_channel_gen.gen_gthe3_channel_inst[0].GTHE3_CHANNEL_PRIM_INST/RXOUTCLK}]
create_clock -name pgp3PhyTxClk -period 5.280 [get_pins {U_CORE/U_PGP/G_PGPv3.U_PGP/G_PGP.U_PGP/U_Pgp3GthUsIpWrapper_1/GEN_6G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp6G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_channel_container[2].gen_enabled_channel.gthe3_channel_wrapper_inst/channel_inst/gthe3_channel_gen.gen_gthe3_channel_inst[0].GTHE3_CHANNEL_PRIM_INST/TXOUTCLK}]
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks {pgpClkP}] -group [get_clocks -include_generated_clocks {pgp3PhyTxClk}] -group [get_clocks -include_generated_clocks {pgp3PhyRxClk}]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins U_CORE/U_PGP/G_PGPv3.U_PGP/G_PGP.U_PGP/U_Pgp3GthUsIpWrapper_1/GEN_6G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp6G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_tx_user_clocking_internal.gen_single_instance.gtwiz_userclk_tx_inst/gen_gtwiz_userclk_tx_main.bufg_gt_usrclk2_inst/O]] -group [get_clocks -of_objects [get_pins U_CORE/U_PGP/G_PGPv3.U_PGP/G_PGP.U_PGP/U_Pgp3GthUsIpWrapper_1/GEN_6G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp6G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_rx_user_clocking_internal.gen_single_instance.gtwiz_userclk_rx_inst/gen_gtwiz_userclk_rx_main.bufg_gt_usrclk2_inst/O]]

set_clock_groups -asynchronous \
   -group [get_clocks -include_generated_clocks {pgpClkP}] \
   -group [get_clocks -include_generated_clocks {ddrClkP}] \
   -group [get_clocks -include_generated_clocks {sysClk}] \
   -group [get_clocks -include_generated_clocks {adc0DClk}] \
   -group [get_clocks -include_generated_clocks {adc1DClk}] \
   -group [get_clocks -include_generated_clocks {adc2DClk}] \
   -group [get_clocks -include_generated_clocks {adc3DClk}] \
   -group [get_clocks -include_generated_clocks {adc4DClk}] \
   -group [get_clocks -include_generated_clocks {adc5DClk}] \
   -group [get_clocks -include_generated_clocks {adc6DClk}] \
   -group [get_clocks -include_generated_clocks {adc7DClk}] \
   -group [get_clocks -include_generated_clocks {adc8DClk}] \
   -group [get_clocks -include_generated_clocks {adc9DClk}]

create_generated_clock -name adcBitClk0R    [get_pins {U_CORE/U_AdcCore/G_AdcReadout[0].U_AdcReadout/U_AdcBitClkR/O}]
create_generated_clock -name adcBitClk0R    [get_pins {U_CORE/U_AdcCore/G_AdcReadout[0].U_AdcReadout/U_AdcBitClkR/O}]
create_generated_clock -name adcBitClk0RD4  [get_pins {U_CORE/U_AdcCore/G_AdcReadout[0].U_AdcReadout/U_AdcBitClkRD4/O}]
create_generated_clock -name adcBitClk1R    [get_pins {U_CORE/U_AdcCore/G_AdcReadout[1].U_AdcReadout/U_AdcBitClkR/O}]
create_generated_clock -name adcBitClk1RD4  [get_pins {U_CORE/U_AdcCore/G_AdcReadout[1].U_AdcReadout/U_AdcBitClkRD4/O}]
create_generated_clock -name adcBitClk2R    [get_pins {U_CORE/U_AdcCore/G_AdcReadout[2].U_AdcReadout/U_AdcBitClkR/O}]
create_generated_clock -name adcBitClk2RD4  [get_pins {U_CORE/U_AdcCore/G_AdcReadout[2].U_AdcReadout/U_AdcBitClkRD4/O}]
create_generated_clock -name adcBitClk3R    [get_pins {U_CORE/U_AdcCore/G_AdcReadout[3].U_AdcReadout/U_AdcBitClkR/O}]
create_generated_clock -name adcBitClk3RD4  [get_pins {U_CORE/U_AdcCore/G_AdcReadout[3].U_AdcReadout/U_AdcBitClkRD4/O}]
create_generated_clock -name adcBitClk4R    [get_pins {U_CORE/U_AdcCore/G_AdcReadout[4].U_AdcReadout/U_AdcBitClkR/O}]
create_generated_clock -name adcBitClk4RD4  [get_pins {U_CORE/U_AdcCore/G_AdcReadout[4].U_AdcReadout/U_AdcBitClkRD4/O}]
create_generated_clock -name adcBitClk5R    [get_pins {U_CORE/U_AdcCore/G_AdcReadout[5].U_AdcReadout/U_AdcBitClkR/O}]
create_generated_clock -name adcBitClk5RD4  [get_pins {U_CORE/U_AdcCore/G_AdcReadout[5].U_AdcReadout/U_AdcBitClkRD4/O}]
create_generated_clock -name adcBitClk6R    [get_pins {U_CORE/U_AdcCore/G_AdcReadout[6].U_AdcReadout/U_AdcBitClkR/O}]
create_generated_clock -name adcBitClk6RD4  [get_pins {U_CORE/U_AdcCore/G_AdcReadout[6].U_AdcReadout/U_AdcBitClkRD4/O}]
create_generated_clock -name adcBitClk7R    [get_pins {U_CORE/U_AdcCore/G_AdcReadout[7].U_AdcReadout/U_AdcBitClkR/O}]
create_generated_clock -name adcBitClk7RD4  [get_pins {U_CORE/U_AdcCore/G_AdcReadout[7].U_AdcReadout/U_AdcBitClkRD4/O}]
create_generated_clock -name adcBitClk8R    [get_pins {U_CORE/U_AdcCore/G_AdcReadout[8].U_AdcReadout/U_AdcBitClkR/O}]
create_generated_clock -name adcBitClk8RD4  [get_pins {U_CORE/U_AdcCore/G_AdcReadout[8].U_AdcReadout/U_AdcBitClkRD4/O}]
create_generated_clock -name adcBitClk9R    [get_pins {U_CORE/U_AdcCore/G_AdcReadout[9].U_AdcReadout/U_AdcBitClkR/O}]
create_generated_clock -name adcBitClk9RD4  [get_pins {U_CORE/U_AdcCore/G_AdcReadout[9].U_AdcReadout/U_AdcBitClkRD4/O}]

set_clock_groups -asynchronous \
   -group [get_clocks -include_generated_clocks {adc0DClk}] \
   -group [get_clocks -include_generated_clocks {adcBitClk0R}] \
   -group [get_clocks -include_generated_clocks {adcBitClk0RD4}] 
set_clock_groups -asynchronous \
   -group [get_clocks -include_generated_clocks {adc1DClk}] \
   -group [get_clocks -include_generated_clocks {adcBitClk1R}] \
   -group [get_clocks -include_generated_clocks {adcBitClk1RD4}] 
set_clock_groups -asynchronous \
   -group [get_clocks -include_generated_clocks {adc2DClk}] \
   -group [get_clocks -include_generated_clocks {adcBitClk2R}] \
   -group [get_clocks -include_generated_clocks {adcBitClk2RD4}] 
set_clock_groups -asynchronous \
   -group [get_clocks -include_generated_clocks {adc3DClk}] \
   -group [get_clocks -include_generated_clocks {adcBitClk3R}] \
   -group [get_clocks -include_generated_clocks {adcBitClk3RD4}] 
set_clock_groups -asynchronous \
   -group [get_clocks -include_generated_clocks {adc4DClk}] \
   -group [get_clocks -include_generated_clocks {adcBitClk4R}] \
   -group [get_clocks -include_generated_clocks {adcBitClk4RD4}] 
set_clock_groups -asynchronous \
   -group [get_clocks -include_generated_clocks {adc5DClk}] \
   -group [get_clocks -include_generated_clocks {adcBitClk5R}] \
   -group [get_clocks -include_generated_clocks {adcBitClk5RD4}] 
set_clock_groups -asynchronous \
   -group [get_clocks -include_generated_clocks {adc6DClk}] \
   -group [get_clocks -include_generated_clocks {adcBitClk6R}] \
   -group [get_clocks -include_generated_clocks {adcBitClk6RD4}] 
set_clock_groups -asynchronous \
   -group [get_clocks -include_generated_clocks {adc7DClk}] \
   -group [get_clocks -include_generated_clocks {adcBitClk7R}] \
   -group [get_clocks -include_generated_clocks {adcBitClk7RD4}] 
set_clock_groups -asynchronous \
   -group [get_clocks -include_generated_clocks {adc8DClk}] \
   -group [get_clocks -include_generated_clocks {adcBitClk8R}] \
   -group [get_clocks -include_generated_clocks {adcBitClk8RD4}] 
set_clock_groups -asynchronous \
   -group [get_clocks -include_generated_clocks {adc9DClk}] \
   -group [get_clocks -include_generated_clocks {adcBitClk9R}] \
   -group [get_clocks -include_generated_clocks {adcBitClk9RD4}] 



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

set_property -dict { PACKAGE_PIN J10  IOSTANDARD LVCMOS18 } [get_ports {envSck}]
set_property -dict { PACKAGE_PIN J11  IOSTANDARD LVCMOS18 } [get_ports {envCnv}]
set_property -dict { PACKAGE_PIN H12  IOSTANDARD LVCMOS18 } [get_ports {envDin}]
set_property -dict { PACKAGE_PIN H13  IOSTANDARD LVCMOS18 } [get_ports {envSdo}]

set_property -dict { PACKAGE_PIN AD8  IOSTANDARD LVCMOS25 PULLTYPE PULLUP } [get_ports {asicDmSn[3]}]
set_property -dict { PACKAGE_PIN AE13 IOSTANDARD LVCMOS25 PULLTYPE PULLUP } [get_ports {asicDmSn[2]}]
set_property -dict { PACKAGE_PIN AE12 IOSTANDARD LVCMOS25 PULLTYPE PULLUP } [get_ports {asicDmSn[1]}]
set_property -dict { PACKAGE_PIN AG12 IOSTANDARD LVCMOS25 PULLTYPE PULLUP } [get_ports {asicDmSn[0]}]

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

set_property -dict { PACKAGE_PIN M25  IOSTANDARD LVCMOS12 } [get_ports {dbgOut[0]}]
set_property -dict { PACKAGE_PIN M28  IOSTANDARD LVCMOS12 } [get_ports {dbgOut[1]}]
set_property -dict { PACKAGE_PIN L28  IOSTANDARD LVCMOS12 } [get_ports {dbgOut[2]}]

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

set_property PACKAGE_PIN H11   [get_ports {adcChP[0][0]}]
set_property PACKAGE_PIN J9    [get_ports {adcChP[0][1]}]
set_property PACKAGE_PIN G10   [get_ports {adcChP[0][2]}]
set_property PACKAGE_PIN F10   [get_ports {adcChP[0][3]}]
set_property PACKAGE_PIN J15   [get_ports {adcChP[0][4]}]
set_property PACKAGE_PIN H16   [get_ports {adcChP[0][5]}]
set_property PACKAGE_PIN H14   [get_ports {adcChP[0][6]}]
set_property PACKAGE_PIN F15   [get_ports {adcChP[0][7]}]

set_property PACKAGE_PIN A13   [get_ports {adcChP[1][0]}]
set_property PACKAGE_PIN A15   [get_ports {adcChP[1][1]}]
set_property PACKAGE_PIN E11   [get_ports {adcChP[1][2]}]
set_property PACKAGE_PIN D11   [get_ports {adcChP[1][3]}]
set_property PACKAGE_PIN D9    [get_ports {adcChP[1][4]}]
set_property PACKAGE_PIN C12   [get_ports {adcChP[1][5]}]
set_property PACKAGE_PIN B9    [get_ports {adcChP[1][6]}]
set_property PACKAGE_PIN B10   [get_ports {adcChP[1][7]}]

set_property PACKAGE_PIN V9    [get_ports {adcChP[2][0]}]
set_property PACKAGE_PIN U9    [get_ports {adcChP[2][1]}]
set_property PACKAGE_PIN T8    [get_ports {adcChP[2][2]}]
set_property PACKAGE_PIN R8    [get_ports {adcChP[2][3]}]
set_property PACKAGE_PIN R9    [get_ports {adcChP[2][4]}]
set_property PACKAGE_PIN R6    [get_ports {adcChP[2][5]}]
set_property PACKAGE_PIN N6    [get_ports {adcChP[2][6]}]
set_property PACKAGE_PIN N9    [get_ports {adcChP[2][7]}]

set_property PACKAGE_PIN K6    [get_ports {adcChP[3][0]}]
set_property PACKAGE_PIN J5    [get_ports {adcChP[3][1]}]
set_property PACKAGE_PIN N4    [get_ports {adcChP[3][2]}]
set_property PACKAGE_PIN M1    [get_ports {adcChP[3][3]}]
set_property PACKAGE_PIN M2    [get_ports {adcChP[3][4]}]
set_property PACKAGE_PIN L3    [get_ports {adcChP[3][5]}]
set_property PACKAGE_PIN K2    [get_ports {adcChP[3][6]}]
set_property PACKAGE_PIN J1    [get_ports {adcChP[3][7]}]

set_property PACKAGE_PIN G16   [get_ports {adcChP[4][0]}]
set_property PACKAGE_PIN F18   [get_ports {adcChP[4][1]}]
set_property PACKAGE_PIN F17   [get_ports {adcChP[4][2]}]
set_property PACKAGE_PIN E16   [get_ports {adcChP[4][3]}]
set_property PACKAGE_PIN C16   [get_ports {adcChP[4][4]}]
set_property PACKAGE_PIN B16   [get_ports {adcChP[4][5]}]
set_property PACKAGE_PIN A17   [get_ports {adcChP[4][6]}]
set_property PACKAGE_PIN B19   [get_ports {adcChP[4][7]}]

set_property PACKAGE_PIN A22   [get_ports {adcChP[5][0]}]
set_property PACKAGE_PIN D23   [get_ports {adcChP[5][1]}]
set_property PACKAGE_PIN J19   [get_ports {adcChP[5][2]}]
set_property PACKAGE_PIN J21   [get_ports {adcChP[5][3]}]
set_property PACKAGE_PIN H22   [get_ports {adcChP[5][4]}]
set_property PACKAGE_PIN G21   [get_ports {adcChP[5][5]}]
set_property PACKAGE_PIN E21   [get_ports {adcChP[5][6]}]
set_property PACKAGE_PIN G20   [get_ports {adcChP[5][7]}]

set_property PACKAGE_PIN L22   [get_ports {adcChP[6][0]}]
set_property PACKAGE_PIN K23   [get_ports {adcChP[6][1]}]
set_property PACKAGE_PIN J23   [get_ports {adcChP[6][2]}]
set_property PACKAGE_PIN H24   [get_ports {adcChP[6][3]}]
set_property PACKAGE_PIN L25   [get_ports {adcChP[6][4]}]
set_property PACKAGE_PIN K27   [get_ports {adcChP[6][5]}]
set_property PACKAGE_PIN K26   [get_ports {adcChP[6][6]}]
set_property PACKAGE_PIN H27   [get_ports {adcChP[6][7]}]

set_property PACKAGE_PIN E27   [get_ports {adcChP[7][0]}]
set_property PACKAGE_PIN D24   [get_ports {adcChP[7][1]}]
set_property PACKAGE_PIN C28   [get_ports {adcChP[7][2]}]
set_property PACKAGE_PIN C26   [get_ports {adcChP[7][3]}]
set_property PACKAGE_PIN B26   [get_ports {adcChP[7][4]}]
set_property PACKAGE_PIN A27   [get_ports {adcChP[7][5]}]
set_property PACKAGE_PIN C24   [get_ports {adcChP[7][6]}]
set_property PACKAGE_PIN B25   [get_ports {adcChP[7][7]}]

set_property PACKAGE_PIN F2    [get_ports {adcChP[8][0]}]
set_property PACKAGE_PIN E1    [get_ports {adcChP[8][1]}]
set_property PACKAGE_PIN F3    [get_ports {adcChP[8][2]}]
set_property PACKAGE_PIN G4    [get_ports {adcChP[8][3]}]
set_property PACKAGE_PIN C1    [get_ports {adcChP[8][4]}]
set_property PACKAGE_PIN A2    [get_ports {adcChP[8][5]}]
set_property PACKAGE_PIN C2    [get_ports {adcChP[8][6]}]
set_property PACKAGE_PIN B4    [get_ports {adcChP[8][7]}]

set_property PACKAGE_PIN A8    [get_ports {adcChP[9][0]}]
set_property PACKAGE_PIN D8    [get_ports {adcChP[9][1]}]
set_property PACKAGE_PIN H8    [get_ports {adcChP[9][2]}]
set_property PACKAGE_PIN J6    [get_ports {adcChP[9][3]}]
set_property PACKAGE_PIN G7    [get_ports {adcChP[9][4]}]
set_property PACKAGE_PIN G5    [get_ports {adcChP[9][5]}]
set_property PACKAGE_PIN F7    [get_ports {adcChP[9][6]}]
set_property PACKAGE_PIN F8    [get_ports {adcChP[9][7]}]

set_property -dict { IOSTANDARD LVDS DIFF_TERM_ADV TERM_100 } [get_ports {adcChP[*][*]}]

set_property PACKAGE_PIN E13   [get_ports {adcFClkP[0]}]
set_property PACKAGE_PIN D14   [get_ports {adcFClkP[1]}]
set_property PACKAGE_PIN N8    [get_ports {adcFClkP[2]}]
set_property PACKAGE_PIN M5    [get_ports {adcFClkP[3]}]
set_property PACKAGE_PIN D18   [get_ports {adcFClkP[4]}]
set_property PACKAGE_PIN E20   [get_ports {adcFClkP[5]}]
set_property PACKAGE_PIN J25   [get_ports {adcFClkP[6]}]
set_property PACKAGE_PIN F24   [get_ports {adcFClkP[7]}]
set_property PACKAGE_PIN D3    [get_ports {adcFClkP[8]}]
set_property PACKAGE_PIN E5    [get_ports {adcFClkP[9]}]
set_property -dict { IOSTANDARD LVDS DIFF_TERM_ADV TERM_100 } [get_ports {adcFClkP[*]}]

set_property PACKAGE_PIN F13   [get_ports {adcDClkP[0]}]
set_property PACKAGE_PIN C14   [get_ports {adcDClkP[1]}]
set_property PACKAGE_PIN M7    [get_ports {adcDClkP[2]}]
set_property PACKAGE_PIN L8    [get_ports {adcDClkP[3]}]
set_property PACKAGE_PIN C18   [get_ports {adcDClkP[4]}]
set_property PACKAGE_PIN D21   [get_ports {adcDClkP[5]}]
set_property PACKAGE_PIN G25   [get_ports {adcDClkP[6]}]
set_property PACKAGE_PIN E25   [get_ports {adcDClkP[7]}]
set_property PACKAGE_PIN D4    [get_ports {adcDClkP[8]}]
set_property PACKAGE_PIN D6    [get_ports {adcDClkP[9]}]
set_property -dict { IOSTANDARD LVDS DIFF_TERM_ADV TERM_100 } [get_ports {adcDClkP[*]}]

set_property PACKAGE_PIN B15   [get_ports {adcClkP[0]}]
set_property PACKAGE_PIN K8    [get_ports {adcClkP[1]}]
set_property PACKAGE_PIN C22   [get_ports {adcClkP[2]}]
set_property PACKAGE_PIN F28   [get_ports {adcClkP[3]}]
set_property PACKAGE_PIN B6    [get_ports {adcClkP[4]}]
set_property -dict { IOSTANDARD LVDS } [get_ports {adcClkP[*]}]

set_property -dict { PACKAGE_PIN C7   IOSTANDARD LVCMOS18 } [get_ports {adcSclk[2]}]
set_property -dict { PACKAGE_PIN B20  IOSTANDARD LVCMOS18 } [get_ports {adcSclk[1]}]
set_property -dict { PACKAGE_PIN L9   IOSTANDARD LVCMOS18 } [get_ports {adcSclk[0]}]

set_property -dict { PACKAGE_PIN B7   IOSTANDARD LVCMOS18 } [get_ports {adcSdio[2]}]
set_property -dict { PACKAGE_PIN B21  IOSTANDARD LVCMOS18 } [get_ports {adcSdio[1]}]
set_property -dict { PACKAGE_PIN K9   IOSTANDARD LVCMOS18 } [get_ports {adcSdio[0]}]

set_property -dict { PACKAGE_PIN H2   IOSTANDARD LVCMOS18 } [get_ports {adcCsb[9]}]
set_property -dict { PACKAGE_PIN G2   IOSTANDARD LVCMOS18 } [get_ports {adcCsb[8]}]
set_property -dict { PACKAGE_PIN H19  IOSTANDARD LVCMOS18 } [get_ports {adcCsb[7]}]
set_property -dict { PACKAGE_PIN G19  IOSTANDARD LVCMOS18 } [get_ports {adcCsb[6]}]
set_property -dict { PACKAGE_PIN H17  IOSTANDARD LVCMOS18 } [get_ports {adcCsb[5]}]
set_property -dict { PACKAGE_PIN H18  IOSTANDARD LVCMOS18 } [get_ports {adcCsb[4]}]
set_property -dict { PACKAGE_PIN W9   IOSTANDARD LVCMOS18 } [get_ports {adcCsb[3]}]
set_property -dict { PACKAGE_PIN W8   IOSTANDARD LVCMOS18 } [get_ports {adcCsb[2]}]
set_property -dict { PACKAGE_PIN AA8  IOSTANDARD LVCMOS18 } [get_ports {adcCsb[1]}]
set_property -dict { PACKAGE_PIN Y8   IOSTANDARD LVCMOS18 } [get_ports {adcCsb[0]}]


set_property LOC BUFGCE_X1Y74  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[0].U_AdcReadout/G_NO_MMCM.U_bitClkBufG}]
set_property LOC BUFGCE_DIV_X0Y11  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[0].U_AdcReadout/U_AdcBitClkR}]
set_property LOC BUFGCE_DIV_X0Y10  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[0].U_AdcReadout/U_AdcBitClkRD4}]

set_property LOC BUFGCE_X1Y81  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[1].U_AdcReadout/G_NO_MMCM.U_bitClkBufG}]
set_property LOC BUFGCE_DIV_X0Y9   [get_cells {U_CORE/U_AdcCore/G_AdcReadout[1].U_AdcReadout/U_AdcBitClkR}]
set_property LOC BUFGCE_DIV_X0Y8   [get_cells {U_CORE/U_AdcCore/G_AdcReadout[1].U_AdcReadout/U_AdcBitClkRD4}]

set_property LOC BUFGCE_X1Y61  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[2].U_AdcReadout/G_NO_MMCM.U_bitClkBufG}]
set_property LOC BUFGCE_DIV_X1Y15  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[2].U_AdcReadout/U_AdcBitClkR}]
set_property LOC BUFGCE_DIV_X1Y14  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[2].U_AdcReadout/U_AdcBitClkRD4}]

set_property LOC BUFGCE_X1Y58  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[3].U_AdcReadout/G_NO_MMCM.U_bitClkBufG}]
set_property LOC BUFGCE_DIV_X1Y13  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[3].U_AdcReadout/U_AdcBitClkR}]
set_property LOC BUFGCE_DIV_X1Y12  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[3].U_AdcReadout/U_AdcBitClkRD4}]

set_property LOC BUFGCE_X0Y87  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[4].U_AdcReadout/G_NO_MMCM.U_bitClkBufG}]
set_property LOC BUFGCE_DIV_X0Y15  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[4].U_AdcReadout/U_AdcBitClkR}]
set_property LOC BUFGCE_DIV_X0Y14  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[4].U_AdcReadout/U_AdcBitClkRD4}]

set_property LOC BUFGCE_X0Y86  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[5].U_AdcReadout/G_NO_MMCM.U_bitClkBufG}]
set_property LOC BUFGCE_DIV_X0Y13  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[5].U_AdcReadout/U_AdcBitClkR}]
set_property LOC BUFGCE_DIV_X0Y12  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[5].U_AdcReadout/U_AdcBitClkRD4}]

set_property LOC BUFGCE_X0Y51  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[6].U_AdcReadout/G_NO_MMCM.U_bitClkBufG}]
set_property LOC BUFGCE_DIV_X1Y19  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[6].U_AdcReadout/U_AdcBitClkR}]
set_property LOC BUFGCE_DIV_X1Y18  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[6].U_AdcReadout/U_AdcBitClkRD4}]

set_property LOC BUFGCE_X0Y56  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[7].U_AdcReadout/G_NO_MMCM.U_bitClkBufG}]
set_property LOC BUFGCE_DIV_X1Y17  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[7].U_AdcReadout/U_AdcBitClkR}]
set_property LOC BUFGCE_DIV_X1Y16  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[7].U_AdcReadout/U_AdcBitClkRD4}]

set_property LOC BUFGCE_X1Y116 [get_cells {U_CORE/U_AdcCore/G_AdcReadout[8].U_AdcReadout/G_NO_MMCM.U_bitClkBufG}]
set_property LOC BUFGCE_DIV_X0Y19  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[8].U_AdcReadout/U_AdcBitClkR}]
set_property LOC BUFGCE_DIV_X0Y18  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[8].U_AdcReadout/U_AdcBitClkRD4}]

set_property LOC BUFGCE_X1Y96  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[9].U_AdcReadout/G_NO_MMCM.U_bitClkBufG}]
set_property LOC BUFGCE_DIV_X1Y11  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[9].U_AdcReadout/U_AdcBitClkR}]
set_property LOC BUFGCE_DIV_X1Y1   [get_cells {U_CORE/U_AdcCore/G_AdcReadout[9].U_AdcReadout/U_AdcBitClkRD4}]


# ADC0 CH0
set_property LOC BITSLICE_RX_TX_X1Y160  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[0].U_AdcReadout/GenData[0].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y160  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[0].U_AdcReadout/GenData[0].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC0 CH1
set_property LOC BITSLICE_RX_TX_X1Y162  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[0].U_AdcReadout/GenData[1].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y162  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[0].U_AdcReadout/GenData[1].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC0 CH2
set_property LOC BITSLICE_RX_TX_X1Y164  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[0].U_AdcReadout/GenData[2].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y164  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[0].U_AdcReadout/GenData[2].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC0 CH3
set_property LOC BITSLICE_RX_TX_X1Y166  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[0].U_AdcReadout/GenData[3].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y166  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[0].U_AdcReadout/GenData[3].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC0 CH4
set_property LOC BITSLICE_RX_TX_X1Y169  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[0].U_AdcReadout/GenData[4].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y169  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[0].U_AdcReadout/GenData[4].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC0 CH5
set_property LOC BITSLICE_RX_TX_X1Y171  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[0].U_AdcReadout/GenData[5].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y171  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[0].U_AdcReadout/GenData[5].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC0 CH6
set_property LOC BITSLICE_RX_TX_X1Y173  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[0].U_AdcReadout/GenData[6].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y173  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[0].U_AdcReadout/GenData[6].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC0 CH7
set_property LOC BITSLICE_RX_TX_X1Y175  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[0].U_AdcReadout/GenData[7].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y175  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[0].U_AdcReadout/GenData[7].U_DATA_DESERIALIZER/U_ISERDESE3_master}]

# ADC1 CH0
set_property LOC BITSLICE_RX_TX_X1Y190  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[1].U_AdcReadout/GenData[0].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y190  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[1].U_AdcReadout/GenData[0].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC1 CH1
set_property LOC BITSLICE_RX_TX_X1Y192  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[1].U_AdcReadout/GenData[1].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y192  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[1].U_AdcReadout/GenData[1].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC1 CH2
set_property LOC BITSLICE_RX_TX_X1Y195  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[1].U_AdcReadout/GenData[2].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y195  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[1].U_AdcReadout/GenData[2].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC1 CH3
set_property LOC BITSLICE_RX_TX_X1Y197  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[1].U_AdcReadout/GenData[3].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y197  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[1].U_AdcReadout/GenData[3].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC1 CH4
set_property LOC BITSLICE_RX_TX_X1Y199  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[1].U_AdcReadout/GenData[4].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y199  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[1].U_AdcReadout/GenData[4].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC1 CH5
set_property LOC BITSLICE_RX_TX_X1Y201  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[1].U_AdcReadout/GenData[5].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y201  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[1].U_AdcReadout/GenData[5].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC1 CH6
set_property LOC BITSLICE_RX_TX_X1Y203  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[1].U_AdcReadout/GenData[6].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y203  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[1].U_AdcReadout/GenData[6].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC1 CH7
set_property LOC BITSLICE_RX_TX_X1Y205  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[1].U_AdcReadout/GenData[7].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y205  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[1].U_AdcReadout/GenData[7].U_DATA_DESERIALIZER/U_ISERDESE3_master}]

# ADC2 CH0
set_property LOC BITSLICE_RX_TX_X1Y108  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[2].U_AdcReadout/GenData[0].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y108  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[2].U_AdcReadout/GenData[0].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC2 CH1
set_property LOC BITSLICE_RX_TX_X1Y110  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[2].U_AdcReadout/GenData[1].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y110  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[2].U_AdcReadout/GenData[1].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC2 CH2
set_property LOC BITSLICE_RX_TX_X1Y112  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[2].U_AdcReadout/GenData[2].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y112  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[2].U_AdcReadout/GenData[2].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC2 CH3
set_property LOC BITSLICE_RX_TX_X1Y114  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[2].U_AdcReadout/GenData[3].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y114  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[2].U_AdcReadout/GenData[3].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC2 CH4
set_property LOC BITSLICE_RX_TX_X1Y117  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[2].U_AdcReadout/GenData[4].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y117  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[2].U_AdcReadout/GenData[4].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC2 CH5
set_property LOC BITSLICE_RX_TX_X1Y119  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[2].U_AdcReadout/GenData[5].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y119  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[2].U_AdcReadout/GenData[5].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC2 CH6
set_property LOC BITSLICE_RX_TX_X1Y121  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[2].U_AdcReadout/GenData[6].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y121  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[2].U_AdcReadout/GenData[6].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC2 CH7
set_property LOC BITSLICE_RX_TX_X1Y123  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[2].U_AdcReadout/GenData[7].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y123  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[2].U_AdcReadout/GenData[7].U_DATA_DESERIALIZER/U_ISERDESE3_master}]

# ADC3 CH0
set_property LOC BITSLICE_RX_TX_X1Y138  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[3].U_AdcReadout/GenData[0].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y138  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[3].U_AdcReadout/GenData[0].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC3 CH1
set_property LOC BITSLICE_RX_TX_X1Y140  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[3].U_AdcReadout/GenData[1].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y140  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[3].U_AdcReadout/GenData[1].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC3 CH2
set_property LOC BITSLICE_RX_TX_X1Y143  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[3].U_AdcReadout/GenData[2].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y143  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[3].U_AdcReadout/GenData[2].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC3 CH3
set_property LOC BITSLICE_RX_TX_X1Y145  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[3].U_AdcReadout/GenData[3].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y145  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[3].U_AdcReadout/GenData[3].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC3 CH4
set_property LOC BITSLICE_RX_TX_X1Y147  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[3].U_AdcReadout/GenData[4].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y147  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[3].U_AdcReadout/GenData[4].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC3 CH5
set_property LOC BITSLICE_RX_TX_X1Y149  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[3].U_AdcReadout/GenData[5].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y149  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[3].U_AdcReadout/GenData[5].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC3 CH6
set_property LOC BITSLICE_RX_TX_X1Y151  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[3].U_AdcReadout/GenData[6].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y151  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[3].U_AdcReadout/GenData[6].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC3 CH7
set_property LOC BITSLICE_RX_TX_X1Y153  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[3].U_AdcReadout/GenData[7].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y153  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[3].U_AdcReadout/GenData[7].U_DATA_DESERIALIZER/U_ISERDESE3_master}]

# ADC4 CH0
set_property LOC BITSLICE_RX_TX_X0Y160  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[4].U_AdcReadout/GenData[0].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X0Y160  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[4].U_AdcReadout/GenData[0].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC4 CH1
set_property LOC BITSLICE_RX_TX_X0Y162  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[4].U_AdcReadout/GenData[1].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X0Y162  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[4].U_AdcReadout/GenData[1].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC4 CH2
set_property LOC BITSLICE_RX_TX_X0Y164  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[4].U_AdcReadout/GenData[2].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X0Y164  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[4].U_AdcReadout/GenData[2].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC4 CH3
set_property LOC BITSLICE_RX_TX_X0Y166  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[4].U_AdcReadout/GenData[3].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X0Y166  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[4].U_AdcReadout/GenData[3].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC4 CH4
set_property LOC BITSLICE_RX_TX_X0Y169  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[4].U_AdcReadout/GenData[4].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X0Y169  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[4].U_AdcReadout/GenData[4].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC4 CH5
set_property LOC BITSLICE_RX_TX_X0Y171  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[4].U_AdcReadout/GenData[5].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X0Y171  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[4].U_AdcReadout/GenData[5].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC4 CH6
set_property LOC BITSLICE_RX_TX_X0Y173  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[4].U_AdcReadout/GenData[6].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X0Y173  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[4].U_AdcReadout/GenData[6].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC4 CH7
set_property LOC BITSLICE_RX_TX_X0Y175  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[4].U_AdcReadout/GenData[7].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X0Y175  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[4].U_AdcReadout/GenData[7].U_DATA_DESERIALIZER/U_ISERDESE3_master}]

# ADC5 CH0
set_property LOC BITSLICE_RX_TX_X0Y190  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[5].U_AdcReadout/GenData[0].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X0Y190  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[5].U_AdcReadout/GenData[0].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC5 CH1
set_property LOC BITSLICE_RX_TX_X0Y192  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[5].U_AdcReadout/GenData[1].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X0Y192  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[5].U_AdcReadout/GenData[1].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC5 CH2
set_property LOC BITSLICE_RX_TX_X0Y195  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[5].U_AdcReadout/GenData[2].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X0Y195  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[5].U_AdcReadout/GenData[2].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC5 CH3
set_property LOC BITSLICE_RX_TX_X0Y197  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[5].U_AdcReadout/GenData[3].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X0Y197  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[5].U_AdcReadout/GenData[3].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC5 CH4
set_property LOC BITSLICE_RX_TX_X0Y199  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[5].U_AdcReadout/GenData[4].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X0Y199  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[5].U_AdcReadout/GenData[4].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC5 CH5
set_property LOC BITSLICE_RX_TX_X0Y201  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[5].U_AdcReadout/GenData[5].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X0Y201  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[5].U_AdcReadout/GenData[5].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC5 CH6
set_property LOC BITSLICE_RX_TX_X0Y203  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[5].U_AdcReadout/GenData[6].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X0Y203  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[5].U_AdcReadout/GenData[6].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC5 CH7
set_property LOC BITSLICE_RX_TX_X0Y205  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[5].U_AdcReadout/GenData[7].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X0Y205  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[5].U_AdcReadout/GenData[7].U_DATA_DESERIALIZER/U_ISERDESE3_master}]

# ADC6 CH0
set_property LOC BITSLICE_RX_TX_X0Y108  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[6].U_AdcReadout/GenData[0].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X0Y108  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[6].U_AdcReadout/GenData[0].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC6 CH1
set_property LOC BITSLICE_RX_TX_X0Y110  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[6].U_AdcReadout/GenData[1].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X0Y110  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[6].U_AdcReadout/GenData[1].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC6 CH2
set_property LOC BITSLICE_RX_TX_X0Y112  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[6].U_AdcReadout/GenData[2].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X0Y112  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[6].U_AdcReadout/GenData[2].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC6 CH3
set_property LOC BITSLICE_RX_TX_X0Y114  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[6].U_AdcReadout/GenData[3].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X0Y114  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[6].U_AdcReadout/GenData[3].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC6 CH4
set_property LOC BITSLICE_RX_TX_X0Y117  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[6].U_AdcReadout/GenData[4].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X0Y117  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[6].U_AdcReadout/GenData[4].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC6 CH5
set_property LOC BITSLICE_RX_TX_X0Y119  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[6].U_AdcReadout/GenData[5].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X0Y119  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[6].U_AdcReadout/GenData[5].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC6 CH6
set_property LOC BITSLICE_RX_TX_X0Y121  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[6].U_AdcReadout/GenData[6].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X0Y121  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[6].U_AdcReadout/GenData[6].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC6 CH7
set_property LOC BITSLICE_RX_TX_X0Y123  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[6].U_AdcReadout/GenData[7].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X0Y123  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[6].U_AdcReadout/GenData[7].U_DATA_DESERIALIZER/U_ISERDESE3_master}]

# ADC7 CH0
set_property LOC BITSLICE_RX_TX_X0Y138  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[7].U_AdcReadout/GenData[0].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X0Y138  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[7].U_AdcReadout/GenData[0].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC7 CH1
set_property LOC BITSLICE_RX_TX_X0Y140  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[7].U_AdcReadout/GenData[1].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X0Y140  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[7].U_AdcReadout/GenData[1].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC7 CH2
set_property LOC BITSLICE_RX_TX_X0Y143  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[7].U_AdcReadout/GenData[2].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X0Y143  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[7].U_AdcReadout/GenData[2].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC7 CH3
set_property LOC BITSLICE_RX_TX_X0Y145  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[7].U_AdcReadout/GenData[3].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X0Y145  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[7].U_AdcReadout/GenData[3].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC7 CH4
set_property LOC BITSLICE_RX_TX_X0Y147  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[7].U_AdcReadout/GenData[4].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X0Y147  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[7].U_AdcReadout/GenData[4].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC7 CH5
set_property LOC BITSLICE_RX_TX_X0Y149  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[7].U_AdcReadout/GenData[5].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X0Y149  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[7].U_AdcReadout/GenData[5].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC7 CH6
set_property LOC BITSLICE_RX_TX_X0Y151  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[7].U_AdcReadout/GenData[6].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X0Y151  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[7].U_AdcReadout/GenData[6].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC7 CH7
set_property LOC BITSLICE_RX_TX_X0Y153  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[7].U_AdcReadout/GenData[7].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X0Y153  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[7].U_AdcReadout/GenData[7].U_DATA_DESERIALIZER/U_ISERDESE3_master}]

# ADC8 CH0
set_property LOC BITSLICE_RX_TX_X1Y212  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[8].U_AdcReadout/GenData[0].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y212  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[8].U_AdcReadout/GenData[0].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC8 CH1
set_property LOC BITSLICE_RX_TX_X1Y214  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[8].U_AdcReadout/GenData[1].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y214  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[8].U_AdcReadout/GenData[1].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC8 CH2
set_property LOC BITSLICE_RX_TX_X1Y216  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[8].U_AdcReadout/GenData[2].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y216  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[8].U_AdcReadout/GenData[2].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC8 CH3
set_property LOC BITSLICE_RX_TX_X1Y218  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[8].U_AdcReadout/GenData[3].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y218  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[8].U_AdcReadout/GenData[3].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC8 CH4
set_property LOC BITSLICE_RX_TX_X1Y221  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[8].U_AdcReadout/GenData[4].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y221  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[8].U_AdcReadout/GenData[4].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC8 CH5
set_property LOC BITSLICE_RX_TX_X1Y223  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[8].U_AdcReadout/GenData[5].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y223  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[8].U_AdcReadout/GenData[5].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC8 CH6
set_property LOC BITSLICE_RX_TX_X1Y225  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[8].U_AdcReadout/GenData[6].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y225  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[8].U_AdcReadout/GenData[6].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC8 CH7
set_property LOC BITSLICE_RX_TX_X1Y227  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[8].U_AdcReadout/GenData[7].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y227  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[8].U_AdcReadout/GenData[7].U_DATA_DESERIALIZER/U_ISERDESE3_master}]

# ADC9 CH0
set_property LOC BITSLICE_RX_TX_X1Y242  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[9].U_AdcReadout/GenData[0].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y242  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[9].U_AdcReadout/GenData[0].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC9 CH1
set_property LOC BITSLICE_RX_TX_X1Y244  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[9].U_AdcReadout/GenData[1].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y244  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[9].U_AdcReadout/GenData[1].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC9 CH2
set_property LOC BITSLICE_RX_TX_X1Y247  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[9].U_AdcReadout/GenData[2].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y247  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[9].U_AdcReadout/GenData[2].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC9 CH3
set_property LOC BITSLICE_RX_TX_X1Y249  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[9].U_AdcReadout/GenData[3].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y249  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[9].U_AdcReadout/GenData[3].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC9 CH4
set_property LOC BITSLICE_RX_TX_X1Y251  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[9].U_AdcReadout/GenData[4].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y251  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[9].U_AdcReadout/GenData[4].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC9 CH5
set_property LOC BITSLICE_RX_TX_X1Y253  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[9].U_AdcReadout/GenData[5].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y253  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[9].U_AdcReadout/GenData[5].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC9 CH6
set_property LOC BITSLICE_RX_TX_X1Y255  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[9].U_AdcReadout/GenData[6].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y255  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[9].U_AdcReadout/GenData[6].U_DATA_DESERIALIZER/U_ISERDESE3_master}]
# ADC9 CH7
set_property LOC BITSLICE_RX_TX_X1Y257  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[9].U_AdcReadout/GenData[7].U_DATA_DESERIALIZER/U_IDELAYE3_0}]
set_property LOC BITSLICE_RX_TX_X1Y257  [get_cells {U_CORE/U_AdcCore/G_AdcReadout[9].U_AdcReadout/GenData[7].U_DATA_DESERIALIZER/U_ISERDESE3_master}]


##########################
## Misc. Configurations ##
##########################

set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design] 
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR Yes [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 2 [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE No [current_design]

set_property CFGBVS         {VCCO} [current_design]
set_property CONFIG_VOLTAGE {3.3} [current_design]