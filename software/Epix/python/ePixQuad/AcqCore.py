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

class AcqCore(pr.Device):
   def __init__(self, **kwargs):
      """Create AcqCore"""
      super().__init__(description='Acquisition Core Registers', **kwargs)
      
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
         name       = 'AcqCount',     
         description= 'Acquisition Cycles Counter',
         offset     = 0x00000000, 
         bitSize    = 32, 
         bitOffset  = 0,  
         base       = pr.UInt, 
         mode       = 'RO',
      ))
      
      
      self.add(pr.RemoteVariable(
         name       = 'AcqCountReset',     
         description= 'Acquisition Counter Reset Bit',
         offset     = 0x00000004, 
         bitSize    = 1, 
         bitOffset  = 0,  
         base       = pr.Bool, 
         mode       = 'RW',
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'AcqToAsicR0Delay',     
         description= 'Acqisition Trigger to ASIC R0 Delay',     
         offset     = 0x00000008, 
         bitSize    = 32, 
         bitOffset  = 0,  
         base       = pr.UInt, 
         mode       = 'RW',
      ))   

      self.add(pr.RemoteVariable(
         name       = 'AsicR0Width',     
         description= 'Asic R0 Width',     
         offset     = 0x0000000C, 
         bitSize    = 32, 
         bitOffset  = 0,  
         base       = pr.UInt, 
         mode       = 'RW',
      ))   
      
      self.add(pr.RemoteVariable(
         name       = 'AsicR0ToAsicAcq',     
         description= 'ASIC R0 to ASIC ACQ Delay',
         offset     = 0x00000010, 
         bitSize    = 32, 
         bitOffset  = 0,  
         base       = pr.UInt, 
         mode       = 'RW',
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'AsicAcqWidth',     
         description= 'ASIC ACQ Width',
         offset     = 0x00000014, 
         bitSize    = 32, 
         bitOffset  = 0,  
         base       = pr.UInt, 
         mode       = 'RW',
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'AsicAcqLToPPmatL',     
         description= 'ASIC ACQ to PPMAT Low Delay',
         offset     = 0x00000018, 
         bitSize    = 32, 
         bitOffset  = 0,  
         base       = pr.UInt, 
         mode       = 'RW',
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'AsicPpmatToReadout',     
         description= 'PPMAT Low Delay to ASIC Readout Delay',
         offset     = 0x0000001C, 
         bitSize    = 32, 
         bitOffset  = 0,  
         base       = pr.UInt, 
         mode       = 'RW',
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'AsicRoClkHalfT',     
         description= 'ASIC RoClk Half Period',
         offset     = 0x00000020, 
         bitSize    = 32, 
         bitOffset  = 0,  
         base       = pr.UInt, 
         mode       = 'RW',
         verify     = False,
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'AsicRoClkCount',     
         description= 'ASIC RoClk Cycles Count',
         offset     = 0x00000024, 
         bitSize    = 32, 
         bitOffset  = 0,  
         base       = pr.UInt, 
         mode       = 'RO',
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'AsicPreAcqTime',     
         description= 'Total Delay from Trigger to ASIC ACQ Pulse',
         offset     = 0x00000028, 
         bitSize    = 32, 
         bitOffset  = 0,  
         base       = pr.UInt, 
         mode       = 'RO',
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'AsicAcqForce',     
         description= 'Enable ASIC ACQ Forced Value',
         offset     = 0x0000002C, 
         bitSize    = 1, 
         bitOffset  = 0,  
         base       = pr.Bool, 
         mode       = 'RW',
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'AsicR0Force',     
         description= 'Enable ASIC R0 Forced Value',
         offset     = 0x0000002C, 
         bitSize    = 1, 
         bitOffset  = 1,  
         base       = pr.Bool, 
         mode       = 'RW',
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'AsicPpmatForce',     
         description= 'Enable ASIC PPMAT Forced Value',
         offset     = 0x0000002C, 
         bitSize    = 1, 
         bitOffset  = 2,  
         base       = pr.Bool, 
         mode       = 'RW',
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'AsicSyncForce',     
         description= 'Enable ASIC SYNC Forced Value',
         offset     = 0x0000002C, 
         bitSize    = 1, 
         bitOffset  = 3,  
         base       = pr.Bool, 
         mode       = 'RW',
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'AsicRoClkForce',     
         description= 'Enable ASIC RoClk Forced Value',
         offset     = 0x0000002C, 
         bitSize    = 1, 
         bitOffset  = 4,  
         base       = pr.Bool, 
         mode       = 'RW',
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'AsicAcqValue',     
         description= 'ASIC ACQ Forced Value',
         offset     = 0x00000030, 
         bitSize    = 1, 
         bitOffset  = 0,  
         base       = pr.Bool, 
         mode       = 'RW',
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'AsicR0Value',     
         description= 'ASIC R0 Forced Value',
         offset     = 0x00000030, 
         bitSize    = 1, 
         bitOffset  = 1,  
         base       = pr.Bool, 
         mode       = 'RW',
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'AsicPpmatValue',     
         description= 'ASIC PPMAT Forced Value',
         offset     = 0x00000030, 
         bitSize    = 1, 
         bitOffset  = 2,  
         base       = pr.Bool, 
         mode       = 'RW',
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'AsicSyncValue',     
         description= 'ASIC SYNC Forced Value',
         offset     = 0x00000030, 
         bitSize    = 1, 
         bitOffset  = 3,  
         base       = pr.Bool, 
         mode       = 'RW',
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'AsicRoClkValue',     
         description= 'ASIC RoClk Forced Value',
         offset     = 0x00000030, 
         bitSize    = 1, 
         bitOffset  = 4,  
         base       = pr.Bool, 
         mode       = 'RW',
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'DummyAcqEn',     
         description= 'Make one more dummy acq cycle to clear out any remaining charge',
         offset     = 0x00000100, 
         bitSize    = 1, 
         bitOffset  = 0,  
         base       = pr.Bool, 
         mode       = 'RW',
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'AsicSyncInjEn',     
         description= 'Enable Sync as Pulser Injection Trigger',
         offset     = 0x00000110, 
         bitSize    = 1, 
         bitOffset  = 0,  
         base       = pr.Bool, 
         mode       = 'RW',
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'AsicSyncInjDly',     
         description= 'Delay Sync in respect to Acq when used as Pulser Injection Trigger',
         offset     = 0x00000114, 
         bitSize    = 32, 
         bitOffset  = 0,  
         base       = pr.UInt, 
         mode       = 'RW',
      ))
      
      for i in range(3):      
         self.add(pr.RemoteVariable(
            name       = ('DbgOutSel[%d]'%i),
            description= ('Select debug signal on output[%d]'%i),
            offset     = (0x00000120+i*4), 
            bitSize    = 4, 
            bitOffset  = 0,  
            base       = pr.UInt, 
            mode       = 'RW',
         ))
      
      #####################################
      # Create commands
      #####################################
      
      # A command has an associated function. The function can be a series of
      # python commands in a string. Function calls are executed in the command scope
      # the passed arg is available as 'arg'. Use 'dev' to get to device scope.
      # A command can also be a call to a local function with local scope.
      # The command object and the arg are passed
   
   @staticmethod   
   def frequencyConverter(self):
      def func(dev, var):         
         return '{:.3f} kHz'.format(1/(self.clkPeriod * self._count(var.dependencies)) * 1e-3)
      return func
