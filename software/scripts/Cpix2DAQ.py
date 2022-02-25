#!/usr/bin/env python3
#-----------------------------------------------------------------------------
# Title      : CPix2 board instance
#-----------------------------------------------------------------------------
# File       : epix100aDAQ.py evolved from evalBoard.py
# Author     : Ryan Herbst, rherbst@slac.stanford.edu
# Modified by: Dionisio Doering
# Created    : 2016-09-29
# Last update: 2017-02-01
#-----------------------------------------------------------------------------
# Description:
# Rogue interface to CPix2 board
#-----------------------------------------------------------------------------
# This file is part of the rogue_example software. It is subject to 
# the license terms in the LICENSE.txt file found in the top-level directory 
# of this distribution and at: 
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
# No part of the rogue_example software, including this file, may be 
# copied, modified, propagated, or distributed except according to the terms 
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------
import rogue.hardware.pgp
import pyrogue.utilities.prbs
import pyrogue.utilities.fileio

import pyrogue as pr
import pyrogue.interfaces.simulation
import pyrogue.gui
import surf
import threading
import signal
import atexit
import yaml
import time
import argparse
import sys
import testBridge
import ePixViewer as vi
import ePixFpga as fpga

try:
    from PyQt5.QtWidgets import *
    from PyQt5.QtCore    import *
    from PyQt5.QtGui     import *
except ImportError:
    from PyQt4.QtCore    import *
    from PyQt4.QtGui     import *


#################################################################

# Set the argument parser
parser = argparse.ArgumentParser()

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
    default  = True,
    help     = "Start viewer",
)  

parser.add_argument(
    "--gui", 
    type     = argBool,
    required = False,
    default  = True,
    help     = "Start GUI",
)  


parser.add_argument(
    "--type", 
    type     = str,
    required = False,
    default  = 'pgp-gen3',
    help     = "PGP hardware type: pgp-gen3, kcu1500 or simulation",
)  

parser.add_argument(
    "--pgp", 
    type     = str,
    required = False,
    default  = '/dev/pgpcard_0',
    help     = "PGP devide (default /dev/pgpcard_0)",
)  

parser.add_argument(
    "--l", 
    type     = int,
    required = False,
    default  = 0,
    help     = "PGP lane number [0 ~ 3]",
)

# Get the arguments
args = parser.parse_args()

#################################################################

#############################################
# Define if the GUI is started (1 starts it)
START_GUI = args.gui
START_VIEWER = args.viewer
#############################################

if ( args.type == 'pgp-gen3' ):
    # Create the PGP interfaces for ePix camera
    pgpVc0 = rogue.hardware.pgp.PgpCard(args.pgp,args.l,0) # Data & cmds
    pgpVc1 = rogue.hardware.pgp.PgpCard(args.pgp,args.l,1) # Registers for ePix board
    pgpVc2 = rogue.hardware.pgp.PgpCard(args.pgp,args.l,2) # PseudoScope
    pgpVc3 = rogue.hardware.pgp.PgpCard(args.pgp,args.l,3) # Monitoring (Slow ADC)
    print("PGP Card Version: %x" % (pgpVc0.getInfo().version))
elif ( args.type == 'kcu1500' ):
    # Create the PGP interfaces for ePix hr camera
    pgpVc0 = rogue.hardware.axi.AxiStreamDma(args.pgp,32*args.l+0,True) # Data & cmds
    pgpVc1 = rogue.hardware.axi.AxiStreamDma(args.pgp,32*args.l+1,True) # Registers for ePix board
    pgpVc2 = rogue.hardware.axi.AxiStreamDma(args.pgp,32*args.l+2,True) # PseudoScope
    pgpVc3 = rogue.hardware.axi.AxiStreamDma(args.pgp,32*args.l+3,True) # Monitoring (Slow ADC)  
elif ( args.type == 'simulation' ):
    pgpVc0 = pr.interfaces.simulation.StreamSim(host='localhost', dest=0, uid=2, ssi=True)
    pgpVc1 = pr.interfaces.simulation.StreamSim(host='localhost', dest=1, uid=2, ssi=True)
    pgpVc2 = pr.interfaces.simulation.StreamSim(host='localhost', dest=2, uid=2, ssi=True)
    pgpVc3 = pr.interfaces.simulation.StreamSim(host='localhost', dest=3, uid=2, ssi=True)      
else:
    raise ValueError("Invalid type (%s)" % (args.type) )


# Add data stream to file as channel 1
# File writer
dataWriter = pyrogue.utilities.fileio.StreamWriter(name = 'dataWriter')
pyrogue.streamConnect(pgpVc1, dataWriter.getChannel(0x1))
# Add pseudoscope to file writer
#pyrogue.streamConnect(pgpVc2, dataWriter.getChannel(0x2))
#pyrogue.streamConnect(pgpVc3, dataWriter.getChannel(0x3))

cmd = rogue.protocols.srp.Cmd()
pyrogue.streamConnect(cmd, pgpVc1)

# Create and Connect SRP to VC1 to send commands
srp = rogue.protocols.srp.SrpV0()
pyrogue.streamConnectBiDir(pgpVc0,srp)

            
##############################
# Set base
##############################
class EpixBoard(pyrogue.Root):
    def __init__(self, guiTop, cmd, dataWriter, srp, **kwargs):
        super().__init__(name = 'ePixBoard', description = 'Cpix2 Board', **kwargs)
        self.add(dataWriter)
        self.guiTop = guiTop

        # Add Devices
        self.add(fpga.Cpix2(name='Cpix2', offset=0, memBase=srp, hidden=False, enabled=True))

        @self.command()
        def Trigger():       
            self.Cpix2.Cpix2FpgaRegisters.EnSingleFrame.post(True)
            #pulserAmpliture = self.Cpix2.Cpix2Asic1.Pulser.get()
            #if pulserAmpliture == 1023:
            #    pulserAmpliture = 0
            #else:
            #    pulserAmpliture += 1
            #self.Cpix2.Cpix2Asic1.Pulser.set(pulserAmpliture)
            self.runControl.runCount.set(self.runControl.runCount.get()) 
            #print("run control", self.runControl.runCount.get())


        self.add(pyrogue.RunControl(name = 'runControl', description='Run Controller cPix2', cmd=self.Trigger, rates={1:'1 Hz', 2:'2 Hz', 4:'4 Hz', 8:'8 Hz', 10:'10 Hz', 30:'30 Hz', 60:'60 Hz', 120:'120 Hz'}))
        #set timeout value
        #self.setTimeout(10)

        


# Create GUI
appTop = QApplication(sys.argv)
guiTop = pyrogue.gui.GuiTop(group = 'Cpix2Gui')
ePixBoard = EpixBoard(guiTop, cmd, dataWriter, srp)
ePixBoard.start(pollEn=args.pollEn, initRead = args.initRead, timeout=3.0)
guiTop.addTree(ePixBoard)
guiTop.resize(1000,800)

# Viewer gui
if START_VIEWER:
   gui = vi.Window(cameraType = 'Cpix2')
   gui.eventReader.frameIndex = 0
   gui.setReadDelay(0)
   pyrogue.streamTap(pgpVc1, gui.eventReader)
   pyrogue.streamTap(pgpVc2, gui.eventReaderScope)# PseudoScope
   pyrogue.streamTap(pgpVc3, gui.eventReaderMonitoring) # Slow Monitoring
   #gui.cbdisplayImageEn.setChecked(START_VIEWER)

    

## Create mesh node (this is for remote control only, no data is shared with this)
#mNode = pyrogue.mesh.MeshNode('rogueEpix100a',iface='eth0',root=None)
#mNode.setNewTreeCb(guiTop.addTree)
#mNode.start()

# Run gui
if (START_GUI):
    appTop.exec_()

# Close window and stop polling
ePixBoard.stop()
exit()


