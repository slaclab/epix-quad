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

class RdoutCore(pr.Device):
   def __init__(self, **kwargs):
      """Create RdoutCore"""
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
         name       = 'RdoutEn',     
         description= 'Enable Readout',
         offset     = 0x00000000, 
         bitSize    = 1, 
         bitOffset  = 0,  
         base       = pr.Bool, 
         mode       = 'RW',
      ))   
      
      self.add(pr.RemoteVariable(
         name       = 'SeqCount',     
         description= 'Sequence Counter',     
         offset     = 0x00000004, 
         bitSize    = 32, 
         bitOffset  = 0,  
         base       = pr.UInt, 
         mode       = 'RO',
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'SeqCountReset',     
         description= 'Sequence Counter Reset',     
         offset     = 0x00000008, 
         bitSize    = 1, 
         bitOffset  = 0,  
         base       = pr.Bool, 
         mode       = 'RW',
      ))   
      
      self.add(pr.RemoteVariable(
         name       = 'AdcPipelineDelay',     
         description= 'ADC Sample Pipeline Delay',     
         offset     = 0x0000000C, 
         bitSize    = 32, 
         bitOffset  = 0,  
         base       = pr.UInt, 
         mode       = 'RW',
         verify     = False,
      ))
      
      for i in range(4):      
          self.add(pr.RemoteVariable(
                 name       = ('LineBufErr[%d]'%i),     
                 description= ('DPRAM Line Burrer [%d] Error Counter'%i),     
                 offset     = 0x00000010+i*4, 
                 bitSize    = 32, 
                 bitOffset  = 0,  
                 base       = pr.UInt, 
                 mode       = 'RO',
              ))
      
      self.add(pr.RemoteVariable(
         name       = 'TestData',     
         description= 'Enable Test Data',
         offset     = 0x00000020, 
         bitSize    = 1, 
         bitOffset  = 0,  
         base       = pr.Bool, 
         mode       = 'RW',
      ))   
      
      self.add(pr.RemoteVariable(
         name       = 'TxDelay',     
         description= 'Enable Test Data',
         offset     = 0x00000024, 
         bitSize    = 32, 
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
