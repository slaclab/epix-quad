#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue AXI Version Module
#-----------------------------------------------------------------------------
# File       : 
# Author     : Maciej Kwiatkowski
# Created    : 2016-09-29
# Last update: 2017-01-31
#-----------------------------------------------------------------------------
# Description:
#-----------------------------------------------------------------------------
# This file is part of the rogue software platform. It is subject to 
# the license terms in the LICENSE.txt file found in the top-level directory 
# of this distribution and at: 
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
# No part of the rogue software platform, including this file, may be 
# copied, modified, propagated, or distributed except according to the terms 
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------
import pyrogue as pr
import collections
import os
import numpy as np
import time as ti

try:
    from PyQt5.QtWidgets import *
    from PyQt5.QtCore    import *
    from PyQt5.QtGui     import *
except ImportError:
    from PyQt4.QtCore    import *
    from PyQt4.QtGui     import *

class SaciConfigCore(pr.Device):
   def __init__(self, **kwargs):
      """Create SaciConfigCore"""
      super().__init__(description='Readout Core Regsisters', **kwargs)
      
      # Creation. memBase is either the register bus server (srp, rce mapped memory, etc) or the device which
      # contains this object. In most cases the parent and memBase are the same but they can be 
      # different in more complex bus structures. They will also be different for the top most node.
      # The setMemBase call can be used to update the memBase for this Device. All sub-devices and local
      # blocks will be updated.
      
      #############################################
      # Create block / variable combinations
      #############################################
      
      
      #Setup registers & variables
      
      self.add(pr.RemoteVariable(
         name       = 'ConfWrReq',     
         description= 'Request Config Write to ASICs',
         offset     = 0x00800000, 
         bitSize    = 1, 
         bitOffset  = 0,  
         base       = pr.Bool, 
         mode       = 'RW',
         verify     = False,
      ))   
      
      self.add(pr.RemoteVariable(
         name       = 'ConfRdReq',     
         description= 'Request Config Read from ASICs',
         offset     = 0x00800004, 
         bitSize    = 1, 
         bitOffset  = 0,  
         base       = pr.Bool, 
         mode       = 'RW',
         verify     = False,
      ))   
      
      self.add(pr.RemoteVariable(
         name       = 'ConfSel',     
         description= 'Select ASICs bit mask',     
         offset     = 0x00800008, 
         bitSize    = 16, 
         bitOffset  = 0,  
         base       = pr.UInt, 
         mode       = 'RW',
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'ConfDoneAll',     
         description= 'All ASICs configuration done',     
         offset     = 0x0080000C, 
         bitSize    = 1, 
         bitOffset  = 0,  
         base       = pr.Bool, 
         mode       = 'RO',
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'ConfFail',     
         description= 'ASIC failed bit mask',     
         offset     = 0x00800010, 
         bitSize    = 16, 
         bitOffset  = 0,  
         base       = pr.UInt, 
         mode       = 'RO',
      ))
      
      #####################################
      # Create commands
      #####################################
      self.add(pr.Command(
         name        = 'SetAsicsMatrix',
         description = 'Configure all ASICs matrix',
         function    = self.setAsicsMatrix,
      ))
      
      # A command has an associated function. The function can be a series of
      # python commands in a string. Function calls are executed in the command scope
      # the passed arg is available as 'arg'. Use 'dev' to get to device scope.
      # A command can also be a call to a local function with local scope.
      # The command object and the arg are passed
   
   def setAsicsMatrix(self, dev,cmd,arg):
      """SetAsicsMatrix command function"""
      if not isinstance(arg, str):
         arg = ''
      if len(arg) > 0:
         self.filename = arg
      else:
         self.filename = QFileDialog.getOpenFileName(self.root.guiTop, 'Open File', '', 'csv file (*.csv);; Any (*.*)')
      if os.path.splitext(self.filename)[1] == '.csv':
         matrixCfg = np.genfromtxt(self.filename, delimiter=',')
         if matrixCfg.shape == (178, 192):
            for asic in range (0, 16):
               memAddr = 0
               for x in range (0, 177):
                  for y in range (0, 192):
                     
                     if memAddr%8 == 0:
                        memData = 0
                     memData = memData | ( (int(matrixCfg[x][y]) & 0xF) << ((memAddr%8)*4) )
                     if memAddr%8 == 7:
                        self._rawWrite((asic*0x80000)+int(memAddr/8)*4, memData)
                        #print('BRAM[0x%X] = 0x%X'%((asic*0x80000)+int(memAddr/8)*4, memData))
                     
                     memAddr = memAddr + 1
               #self._rawWrite((asic*0x80000)+int(0)*4, 0x02000100)
               #self._rawWrite((asic*0x80000)+int(2)*4, 0x00040003)
            
            self.ConfSel.set(0xffff)
            self.ConfWrReq.set(True)
            while self.ConfDoneAll.get() != True:
               ti.sleep(1)
         else:
            print('csv file must be 192x178 pixels')
      else:
            print("Not csv file : ", self.filename)    
   
   @staticmethod   
   def frequencyConverter(self):
      def func(dev, var):         
         return '{:.3f} kHz'.format(1/(self.clkPeriod * self._count(var.dependencies)) * 1e-3)
      return func
