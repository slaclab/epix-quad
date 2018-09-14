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

class PseudoScopeCore(pr.Device):
   def __init__(self, **kwargs):
      """Create PseudoScopeCore"""
      super().__init__(description='Pseudo Scope Regsisters', **kwargs)
      
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
         name       = 'Arm',     
         description= 'Pseudo Scope Arm',     
         offset     = 0x00000000, 
         bitSize    = 1, 
         bitOffset  = 0,  
         base       = pr.Bool, 
         mode       = 'RW',
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'Trig',     
         description= 'Pseudo Scope Trig',     
         offset     = 0x00000004, 
         bitSize    = 1, 
         bitOffset  = 0,  
         base       = pr.Bool, 
         mode       = 'RW',
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'ScopeEn',     
         description= 'Pseudo Scope Enable',     
         offset     = 0x00000008, 
         bitSize    = 1, 
         bitOffset  = 0,  
         base       = pr.Bool, 
         mode       = 'RW',
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'TrigEdge',     
         description= 'Trigger Edge Select',     
         offset     = 0x0000000C, 
         bitSize    = 1, 
         bitOffset  = 0,  
         base       = pr.Bool, 
         mode       = 'RW',
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'TrigChannel',     
         description= 'Trigger Channel Select',     
         offset     = 0x00000010, 
         bitSize    = 5, 
         bitOffset  = 0,  
         base       = pr.UInt, 
         mode       = 'RW',
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'TrigMode',     
         description= 'Trigger Mode Select',     
         offset     = 0x00000014, 
         bitSize    = 2, 
         bitOffset  = 0,  
         base       = pr.UInt, 
         mode       = 'RW',
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'TrigAdcThreshold',     
         description= 'ADC Threshold for Over Threshold Channel',     
         offset     = 0x00000018, 
         bitSize    = 16, 
         bitOffset  = 0,  
         base       = pr.UInt, 
         mode       = 'RW',
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'TrigHoldoff',     
         description= 'Trigger Holdoff',     
         offset     = 0x0000001C, 
         bitSize    = 13, 
         bitOffset  = 0,  
         base       = pr.UInt, 
         mode       = 'RW',
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'TrigOffset',     
         description= 'Trigger Offset',     
         offset     = 0x00000020, 
         bitSize    = 13, 
         bitOffset  = 0,  
         base       = pr.UInt, 
         mode       = 'RW',
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'TraceLength',     
         description= 'Trigger Data Size',     
         offset     = 0x00000024, 
         bitSize    = 13, 
         bitOffset  = 0,  
         base       = pr.UInt, 
         mode       = 'RW',
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'SkipSamples',     
         description= 'Skip Samples',     
         offset     = 0x00000028, 
         bitSize    = 13, 
         bitOffset  = 0,  
         base       = pr.UInt, 
         mode       = 'RW',
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'InChannelA',     
         description= 'Input Channel A Select',     
         offset     = 0x0000002C, 
         bitSize    = 7, 
         bitOffset  = 0,  
         base       = pr.UInt, 
         mode       = 'RW',
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'InChannelB',     
         description= 'Input Channel B Select',     
         offset     = 0x00000030, 
         bitSize    = 7, 
         bitOffset  = 0,  
         base       = pr.UInt, 
         mode       = 'RW',
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'TrigDelay',     
         description= 'Trigger Delay',     
         offset     = 0x00000034, 
         bitSize    = 13, 
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
