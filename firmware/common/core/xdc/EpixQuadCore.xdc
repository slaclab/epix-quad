##############################################################################
## This file is part of 'Epix Quad Firmware'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'LZ Test Stand Firmware', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

############################
## Pinout Configuration   ##
############################

set_property PACKAGE_PIN AD6 [get_ports {pgpClkP}]
set_property PACKAGE_PIN AD5 [get_ports {pgpClkN}]
set_property PACKAGE_PIN AG4 [get_ports pgpTxP]
set_property PACKAGE_PIN AG3 [get_ports pgpTxN]
set_property PACKAGE_PIN AH2 [get_ports pgpRxP]
set_property PACKAGE_PIN AH1 [get_ports pgpRxN]

##########################
## Timing Constraints   ##
##########################

create_clock -name pgpClkP   -period 6.400 [get_ports {pgpClkP}]

set_clock_groups -asynchronous \
   -group [get_clocks -include_generated_clocks {pgpClkP}] 