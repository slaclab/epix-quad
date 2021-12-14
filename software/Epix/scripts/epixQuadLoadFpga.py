#!/usr/bin/env python3
#-----------------------------------------------------------------------------
# Title      : ePix 100a board instance
#-----------------------------------------------------------------------------
# File       : epix100aDAQ.py evolved from evalBoard.py
# Author     : Ryan Herbst, rherbst@slac.stanford.edu
# Modified by: Dionisio Doering
# Created    : 2016-09-29
# Last update: 2017-02-01
#-----------------------------------------------------------------------------
# Description:
# Rogue interface to ePix 100a board
#-----------------------------------------------------------------------------
# This file is part of the rogue_example software. It is subject to 
# the license terms in the LICENSE.txt file found in the top-level directory 
# of this distribution and at: 
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
# No part of the rogue_example software, including this file, may be 
# copied, modified, propagated, or distributed except according to the terms 
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import sys
import pyrogue as pr
import pyrogue.gui
import argparse
import time
import rogue.hardware
import ePixQuad as quad

#################################################################

# Set the argument parser
parser = argparse.ArgumentParser()

# Add arguments

# Convert str to bool
argBool = lambda s: s.lower() in ['true', 't', 'yes', '1']

# Mutually exclusive group for the card selection
group = parser.add_mutually_exclusive_group()

parser.add_argument(
    "--l", 
    type     = int,
    required = True,
    help     = "PGP lane number [0 ~ 3]",
)

parser.add_argument(
    "--mcs", 
    type     = str,
    required = True,
    help     = "path to mcs file",
)

parser.add_argument(
    "--type", 
    type     = str,
    required = False,
    default  = 'datadev',
    help     = "Data card type pgp3_cardG3, datadev or simulation)",
)  

group.add_argument(
    "--pgp", 
    type     = argBool,
    required = False,
    default  = '/dev/pgpcard_0',
    help     = "PGP devide (default /dev/pgpcard_0)",
)  

group.add_argument(
    "--dataDev",
    type      = argBool,
    required  = False,
    default   = '/dev/datadev_0',
    help      = 'Data dev card, for Pgp4'
)

# parser.add_argument(
#     "--pgp", 
#     type     = str,
#     required = False,
#     default  = '/dev/pgpcard_0',
#     help     = "PGP devide (default /dev/pgpcard_0)",
# )  

# Get the arguments
args = parser.parse_args()

if args.pgp:
    device = '/dev/pgpcard_0'
else :
    device ='/dev/datadev_0'
    
#################################################################

# Set base
base = quad.Top(
    hwType = args.type, 
    lane   = args.l,
    dev    = device,
)    

# Start the system
base.start(
    # pollEn   = False,
    # initRead = False,
)
    
# Create useful pointers
AxiVersion = base.AxiVersion
PROM       = base.CypressS25Fl

# disable and stop all internal ADC startup activity
base.SystemRegs.enable.set(True)
base.SystemRegs.AdcBypass.set(True)

print ( '###################################################')
print ( '#                 Old Firmware                    #')
print ( '###################################################')
AxiVersion.printStatus()

# Program the FPGA's PROM
PROM.LoadMcsFile(args.mcs)

# Check if PROM successfully programmed
if(PROM._progDone):
    print('\nReloading FPGA firmware from PROM ....')
    AxiVersion.FpgaReload()
    time.sleep(10)
    print('\nReloading FPGA done')

    print ( '###################################################')
    print ( '#                 New Firmware                    #')
    print ( '###################################################')
    AxiVersion.printStatus()
else:
    print('Failed to program FPGA')

# re-enable internal ADC startup
base.SystemRegs.AdcBypass.set(False)

base.stop()
exit()
