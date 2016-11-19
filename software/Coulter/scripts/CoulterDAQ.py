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
import rogue.hardware.pgp
import pyrogue.utilities.fileio
import pyrogue.gui
import coulter
import threading
import signal
import atexit
import yaml
import time
import sys
import PyQt4.QtGui



# File writer
dataWriter = pyrogue.utilities.fileio.StreamWriter('dataWriter')

# Create the PGP interfaces
pgpVc0 = rogue.hardware.pgp.PgpCard('/dev/pgpcard_0',0,0) # Registers
pgpVc1 = rogue.hardware.pgp.PgpCard('/dev/pgpcard_0',0,1) # Data

print("")
print("PGP Card Version: %x" % (pgpVc0.getInfo().version))

# Create and Connect SRPv0 to VC0
srp = rogue.protocols.srp.SrpV0()
pyrogue.streamConnectBiDir(pgpVc0,srp)

# Add data stream to file as channel 0
pyrogue.streamConnect(pgpVc1, dataWriter.getChannel(0x0))


# Instantiate top and pass stream and srp configurations
coulterDaq = coulter.CoulterRoot(srp0=srp, dataWriter=dataWriter)

# Create GUI
appTop = PyQt4.QtGui.QApplication(sys.argv)
guiTop = pyrogue.gui.GuiTop('CoulterGui')
guiTop.addTree(coulterDaq)

# Run gui
appTop.exec_()

# Stop mesh after gui exits
coulterDaq.stop()
