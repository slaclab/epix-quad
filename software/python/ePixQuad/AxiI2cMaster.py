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

class AxiI2cMaster(pr.Device):
   def __init__(self, **kwargs):
      """Create AxiI2cMaster"""
      super().__init__(description='I2C Master Regsisters', **kwargs)
      
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
         name       = 'i2cAddr',     
         description= 'i2cAddr',     
         offset     = 0x00000000, 
         bitSize    = 10, 
         bitOffset  = 0,  
         base       = pr.UInt, 
         mode       = 'RW',
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'tenbit',     
         description= 'tenbit',     
         offset     = 0x00000004, 
         bitSize    = 1, 
         bitOffset  = 0,  
         base       = pr.Bool, 
         mode       = 'RW',
      ))
      
      
      self.add(pr.RemoteVariable(
         name       = 'regAddr',     
         description= 'regAddr',     
         offset     = 0x00000008, 
         bitSize    = 32, 
         bitOffset  = 0,  
         base       = pr.UInt, 
         mode       = 'RW',
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'regWrData',     
         description= 'regWrData',     
         offset     = 0x0000000C, 
         bitSize    = 32, 
         bitOffset  = 0,  
         base       = pr.UInt, 
         mode       = 'RW',
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'regAddrSize',     
         description= 'regAddrSize',     
         offset     = 0x00000010, 
         bitSize    = 2, 
         bitOffset  = 0,  
         base       = pr.UInt, 
         mode       = 'RW',
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'regAddrSkip',     
         description= 'regAddrSkip',     
         offset     = 0x00000014, 
         bitSize    = 1, 
         bitOffset  = 0,  
         base       = pr.Bool, 
         mode       = 'RW',
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'regDataSize',     
         description= 'regDataSize',     
         offset     = 0x00000018, 
         bitSize    = 2, 
         bitOffset  = 0,  
         base       = pr.UInt, 
         mode       = 'RW',
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'endianness',     
         description= 'endianness',     
         offset     = 0x0000001C, 
         bitSize    = 1, 
         bitOffset  = 0,  
         base       = pr.Bool, 
         mode       = 'RW',
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'repeatStart',     
         description= 'repeatStart',     
         offset     = 0x00000020, 
         bitSize    = 1, 
         bitOffset  = 0,  
         base       = pr.Bool, 
         mode       = 'RW',
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'regOp',     
         description= 'regOp',     
         offset     = 0x00000024, 
         bitSize    = 1, 
         bitOffset  = 0,  
         base       = pr.Bool, 
         mode       = 'RW',
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'regReq',     
         description= 'regReq',     
         offset     = 0x00000028, 
         bitSize    = 1, 
         bitOffset  = 0,  
         base       = pr.Bool, 
         mode       = 'RW',
         verify     = False,
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'regRdData',     
         description= 'regRdData',     
         offset     = 0x0000002C, 
         bitSize    = 32, 
         bitOffset  = 0,  
         base       = pr.UInt, 
         mode       = 'RO',
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'regFail',     
         description= 'regFail',     
         offset     = 0x00000030, 
         bitSize    = 1, 
         bitOffset  = 0,  
         base       = pr.Bool, 
         mode       = 'RO',
         verify     = False,
      ))
      
      self.add(pr.RemoteVariable(
         name       = 'regFailCode',     
         description= 'regFailCode',     
         offset     = 0x00000034, 
         bitSize    = 8, 
         bitOffset  = 0,  
         base       = pr.UInt, 
         mode       = 'RO',
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
