#!/usr/bin/env python3
##############################################################################
## This file is part of 'EPIX'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'EPIX', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

import sys
import pyrogue as pr
import pyrogue.gui
import rogue
import argparse
import ePixQuad as quad
import ePixViewer as vi

# rogue.Logging.setLevel(rogue.Logging.Warning)
# rogue.Logging.setFilter("pyrogue.SrpV3",rogue.Logging.Debug)
# rogue.Logging.setLevel(rogue.Logging.Debug)

#################################################################

# Set the argument parser
parser = argparse.ArgumentParser()

# Mutually exclusive group for the card selection
group = parser.add_mutually_exclusive_group()

# Convert str to bool
argBool = lambda s: s.lower() in ['true', 't', 'yes', '1']

# Add arguments
parser.add_argument(
    "--pollEn", 
    type     = argBool,
    required = False,
    default  = False,
    help     = "Enable auto-polling",
) 

parser.add_argument(
    "--initRead", 
    type     = argBool,
    required = False,
    default  = False,
    help     = "Enable read all variables at start",
)  

parser.add_argument(
    "--viewer", 
    type     = argBool,
    required = False,
    default  = False,
    help     = "Start viewer",
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

parser.add_argument(
    "--l", 
    type     = int,
    required = True,
    help     = "PGP lane number [0 ~ 3]",
)

parser.add_argument(
    "--adcCalib", 
    type     = argBool,
    required = False,
    default  = False,
    help     = "Enable ADC calibration write to PROM. Can corrupt the FPGA's image potentially!",
)  

# Get the arguments
args = parser.parse_args()
print(args)
#################################################################


if args.pgp:
    device = '/dev/pgpcard_0'
else :
    device ='/dev/datadev_0'
print(device)
# Set base
base = quad.Top(hwType=args.type, dev=device, lane=args.l, promWrEn=args.adcCalib)

# Start the system
base.start(
#    pollEn   = args.pollEn,
#    initRead = args.initRead,
#    timeout  = 5.0,    
)

# Create GUI
appTop = pr.gui.application(sys.argv)
guiTop = pr.gui.GuiTop(group='rootMesh')
appTop.setStyle('Fusion')
guiTop.addTree(base)
guiTop.resize(600, 800)

base.guiTop = guiTop

# Viewer gui
if args.viewer:
   gui = vi.Window(cameraType = 'ePixQuad')
   gui.eventReader.frameIndex = 0
   #gui.eventReaderImage.VIEW_DATA_CHANNEL_ID = 0
   gui.setReadDelay(0)
   pyrogue.streamTap(base.pgpVc0, gui.eventReader) 
   pyrogue.streamTap(base.pgpVc2, gui.eventReaderScope)# PseudoScope
   pyrogue.streamTap(base.pgpVc3, gui.eventReaderMonitoring) # Slow Monitoring

print("Starting GUI...\n");

# Run GUI
appTop.exec_()    
    
# Close
base.stop()
exit()   
