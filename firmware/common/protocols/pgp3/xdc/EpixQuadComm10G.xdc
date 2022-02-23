##############################################################################
## This file is part of 'ePix Quad Firmware'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'LZ Test Stand Firmware', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################


create_clock -name pgp4PhyRxClk -period 3.200 [get_pins {U_CORE/GEN_V3/U_PGP/G_PGP.U_PGP/U_Pgp3GthUsIpWrapper_1/GEN_10G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp10G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_channel_container[2].gen_enabled_channel.gthe3_channel_wrapper_inst/channel_inst/gthe3_channel_gen.gen_gthe3_channel_inst[0].GTHE3_CHANNEL_PRIM_INST/rxoutclk_out}]

create_clock -name pgp4PhyTxClk -period 3.200 [get_pins {U_CORE/GEN_V3/U_PGP/G_PGP.U_PGP/U_Pgp3GthUsIpWrapper_1/GEN_10G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp10G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_channel_container[2].gen_enabled_channel.gthe3_channel_wrapper_inst/channel_inst/gthe3_channel_gen.gen_gthe3_channel_inst[0].GTHE3_CHANNEL_PRIM_INST/txoutclk_out}]

#set_clock_groups -asynchronous \
#    -group [get_clocks -of_objects [get_pins U_CORE/GEN_V3/U_PGP/G_PGP.U_PGP/U_Pgp3GthUsIpWrapper_1/GEN_10G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp10G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_tx_user_clocking_internal.gen_single_instance.gtwiz_userclk_tx_inst/gen_gtwiz_userclk_tx_main.bufg_gt_usrclk2_inst/O]] \
#    -group [get_clocks -of_objects [get_pins U_CORE/GEN_V3/U_PGP/G_PGP.U_PGP/U_Pgp3GthUsIpWrapper_1/GEN_10G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp10G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_rx_user_clocking_internal.gen_single_instance.gtwiz_userclk_rx_inst/gen_gtwiz_userclk_rx_main.bufg_gt_usrclk2_inst/O]]

set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks {pgp4PhyRxClk}] -group [get_clocks -include_generated_clocks {pgpClkP}] -group [get_clocks -include_generated_clocks {pgp4PhyTxClk}] -group [get_clocks -include_generated_clocks {pgpClkP}]
