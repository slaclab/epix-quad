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

# Custom run control
class MyRunControl(pyrogue.RunControl):
   def __init__(self,name):
      pyrogue.RunControl.__init__(self,name,'Run Controller')
      self._thread = None

      self.runRate.enum = {1:'1 Hz', 10:'10 Hz', 30:'30 Hz'}

   def _setRunState(self,dev,var,value):
      if self._runState != value:
         self._runState = value

         if self._runState == 'Running':
            self._thread = threading.Thread(target=self._run)
            self._thread.start()
         else:
            self._thread.join()
            self._thread = None

   def _run(self):
      self._runCount = 0
      self._last = int(time.time())

      while (self._runState == 'Running'):
         delay = 1.0 / ({value: key for key,value in self.runRate.enum.iteritems()}[self._runRate])
         time.sleep(delay)
         # Add command here
         #ExampleCommand: self._root.ssiPrbsTx.oneShot()

         self._runCount += 1
         if self._last != int(time.time()):
             self._last = int(time.time())
             self.runCount._updated()

# Set base
coulterDaq = pyrogue.Root('CoulterDaq','Coulter Data Acquisition')

# Run control
febBoard.add(MyRunControl('runControl'))

# File writer
dataWriter = pyrogue.utilities.fileio.StreamWriter('dataWriter')
febBoard.add(dataWriter)

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

# Add registers
coulterDaq.add(coulter.Coulter(memBase=srp,offset=0x0))

# Create GUI
appTop = PyQt4.QtGui.QApplication(sys.argv)
guiTop = pyrogue.gui.GuiTop('CoulterGui')
guiTop.addTree(coulterDaq)

# Run gui
appTop.exec_()

# Stop mesh after gui exits
coulterDaq.stop()
