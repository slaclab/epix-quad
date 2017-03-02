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


# Create the PGP interfaces

vcReg = [rogue.hardware.pgp.PgpCard('/dev/pgpcard_0',i,0) for i in range(2)] # Registers
vcData = [rogue.hardware.pgp.PgpCard('/dev/pgpcard_0',i,1) for i in range(2)] # Data
vcTrigger = vcReg[0]


#print("")
#print("PGP Card Version: %x" % (vcReg.getInfo().version))

# Create and Connect SRPv0 to VC0 
srp = [rogue.protocols.srp.SrpV0() for i in range(2)]

for i in range(2):
    pyrogue.streamConnectBiDir(vcReg[i] ,srp[i])
    pyrogue.streamConnect(vcData[i], dataWriter.getChannel(i))
    
dbgSrp = rogue.interfaces.stream.Slave()
dbgSrp.setDebug(10, "SRP")
#pyrogue.streamTap(srp, dbgSrp)

for i in range(2):
    dbgData = rogue.interfaces.stream.Slave()
    dbgData.setDebug(30, "DATA[{}]".format(i))
    pyrogue.streamTap(vcData[i], dbgData)
    parser = coulter.CoulterFrameParser()
    pyrogue.streamTap(vcData[i], parser)
    


# Instantiate top and pass stream and srp configurations
coulterDaq = coulter.CoulterRoot(pgp=vcReg, srp=srp, trig=vcTrigger, dataWriter=dataWriter)
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
