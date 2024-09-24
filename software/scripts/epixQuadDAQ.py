#!/usr/bin/env python3
##############################################################################
# This file is part of 'EPIX'.
# It is subject to the license terms in the LICENSE.txt file found in the
# top-level directory of this distribution and at:
# https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of 'EPIX', including this file,
# may be copied, modified, propagated, or distributed except according to
# the terms contained in the LICENSE.txt file.
##############################################################################
import setupLibPaths

import sys
import pyrogue as pr
#import pyrogue.gui
import pyrogue.pydm
import rogue
import argparse
import ePixQuad as quad
import ePixViewer as vi


#rogue.Logging.setLevel(rogue.Logging.Error)
# rogue.Logging.setFilter("pyrogue.SrpV3",rogue.Logging.Debug)
# rogue.Logging.setLevel(rogue.Logging.Debug)

#################################################################

# Set the argument parser
parser = argparse.ArgumentParser()


# Convert str to bool
def argBool(s):
    return s.lower() in ['true', 't', 'yes', '1']


# Add arguments
parser.add_argument(
    "--pollEn",
    type=argBool,
    required=False,
    default=False,
    help="Enable auto-polling",
)

parser.add_argument(
    "--initRead",
    type=argBool,
    required=False,
    default=False,
    help="Enable read all variables at start",
)

parser.add_argument(
    "--viewer",
    type=argBool,
    required=False,
    default=False,
    help="Start viewer",
)

parser.add_argument(
    "--type",
    type=str,
    required=False,
    default='datadev',
    help="Data card type pgp3_cardG3, datadev or simulation)",
)

parser.add_argument(
    "--dev",
    type=str,
    required=False,
    default='/dev/datadev_0',
    help="Data card type pgp3_cardG3, datadev or simulation)",
)

parser.add_argument(
    "--l",
    type=int,
    required=True,
    help="PGP lane number [0 ~ 3]",
)

parser.add_argument(
    "--adcCalib",
    type=argBool,
    required=False,
    default=False,
    help="Enable ADC calibration write to PROM. Can corrupt the FPGA's image potentially!",
)

# Get the arguments
args = parser.parse_args()
print(args)
#################################################################

#appTop = pr.gui.application(sys.argv)

# Set base
with quad.Top(
    hwType=args.type,
    dev=args.dev,
    lane=args.l,
    promWrEn=args.adcCalib,
) as root:
#     pyrogue.waitCntrlC()
    if args.viewer:
        gui = vi.Window(cameraType='ePixQuad')
        gui.eventReader.frameIndex = 0
        #gui.eventReaderImage.VIEW_DATA_CHANNEL_ID = 0
        gui.setReadDelay(0)
        
        gui.eventReader << root.pgpVc0
        gui.eventReaderScope << root.pgpVc2
        gui.eventReaderMonitoring << root.pgpVc3
        #pyrogue.streamTap(root.pgpVc0, gui.eventReader)
        #pyrogue.streamTap(root.pgpVc2, gui.eventReaderScope)  # PseudoScope
        #pyrogue.streamTap(root.pgpVc3, gui.eventReaderMonitoring)  # Slow Monitoring
    
    print("Starting PyDM")
    pyrogue.pydm.runPyDM(
        serverList  = root.zmqServer.address,
        #sizeX=900,
        #sizeY=800,
    )
    print("After PyDM")

    pyrogue.waitCntrlC()
