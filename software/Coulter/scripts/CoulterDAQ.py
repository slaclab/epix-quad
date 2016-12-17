#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue febBoard Module
#-----------------------------------------------------------------------------
# File       : febBoard.py
# Author     : Larry Ruckman <ruckman@slac.stanford.edu>
# Created    : 2016-11-09
# Last update: 2016-11-09
#-----------------------------------------------------------------------------
# Description:
# Rogue interface to FEB board
#-----------------------------------------------------------------------------
# This file is part of the ATLAS CHESS2 DEV. It is subject to 
# the license terms in the LICENSE.txt file found in the top-level directory 
# of this distribution and at: 
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
# No part of the ATLAS CHESS2 DEV, including this file, may be 
# copied, modified, propagated, or distributed except according to the terms 
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------
#import rogue.hardware.pgp
import rogue.interfaces.memory
import pyrogue.simulation
import pyrogue.utilities.fileio
import pyrogue.gui
import pyrogue.mesh
import pyrogue.epics
import coulter
import threading
import signal
import atexit
import yaml
import time
import sys
import PyQt4.QtGui
import PyQt4.QtCore



# File writer
dataWriter = pyrogue.utilities.fileio.StreamWriter('dataWriter')

#vcReg = pyrogue.simulation.StreamSim('localhost', 0, 1, ssi=True)
#vcData = pyrogue.simulation.StreamSim('localhost', 1, 1, ssi=True)
#vcTrigger = pyrogue.simulation.StreamSim('localhost', 4, 1, ssi=True)

# Create the PGP interfaces
vcReg = rogue.hardware.pgp.PgpCard('/dev/pgpcard_0',0,0) # Registers
vcData = rogue.hardware.pgp.PgpCard('/dev/pgpcard_0',0,1) # Data
vcTrigger = vcReg

#print("")
#print("PGP Card Version: %x" % (vcReg.getInfo().version))

# Create and Connect SRPv0 to VC0 
srp = rogue.protocols.srp.SrpV0()
#srp = rogue.interfaces.memory.Slave()
pyrogue.streamConnectBiDir(vcReg,srp)
dbg = rogue.interfaces.stream.Slave()
dbg.setDebug(10, "SRP")
pyrogue.streamTap(srp, dbg)

# Add data stream to file as channel 0
pyrogue.streamConnect(vcData, dataWriter.getChannel(0x0))

dbg2 = rogue.interfaces.stream.Slave()
dbg2.setDebug(12, "DATA")
pyrogue.streamTap(vcData, dbg2)


# Instantiate top and pass stream and srp configurations
coulterDaq = coulter.CoulterRoot(srp0=srp, trig=vcTrigger, dataWriter=dataWriter)
#coulterDaq.setTimeout(100000000)
#coulterDaq = pyrogue.Root(name="CoulterDaq", description="Coulter Data Acquisition")
#coulterDaq.add(coulter.CoulterRunControl(name="RunControl"))
#coulterDaq.add(coulter.Coulter(name="Coulter0"))
#coulterDaq.add(pyrogue.Device("Test"))

#mNode = pyrogue.mesh.MeshNode('MeshTest', root=coulterDaq, iface='eth1')
#mNode.start()

#epics = pyrogue.epics.EpicsCaServer('MeshTest', coulterDaq)
#epics.start()

# def stop():
#    mNode.stop()
#    evalBoard.stop()
#    exit()

# Create GUI
appTop = PyQt4.QtGui.QApplication(sys.argv)
guiTop = pyrogue.gui.GuiTop('CoulterGui')
guiTop.addTree(coulterDaq)
guiTop.resize(1000,1000)

# Run gui
appTop.exec_()

# Stop mesh after gui exits
coulterDaq.stop()
