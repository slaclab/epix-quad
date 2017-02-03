#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue AXI Version Module
#-----------------------------------------------------------------------------
# File       : from pyrogue/devices/axi_version.py
# Author     : originally from Ryan Herbst, rherbst@slac.stanford.edu
#            : adapted by Dionisio Doering
# Created    : 2016-09-29
# Last update: 2017-01-31
#-----------------------------------------------------------------------------
# Description:
# PyRogue AXI Version Module for ePix100a
# for genDAQ compatibility check software/deviceLib/Epix100aAsic.cpp
#-----------------------------------------------------------------------------
# This file is part of the rogue software platform. It is subject to 
# the license terms in the LICENSE.txt file found in the top-level directory 
# of this distribution and at: 
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
# No part of the rogue software platform, including this file, may be 
# copied, modified, propagated, or distributed except according to the terms 
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------
import pyrogue
import collections

def create(name='Epix100aAsic', offset=0, memBase=None, hidden=False, enabled=True):
    """Create the axiVersion device for ePix100aAsic"""

    #In order to easely compare GedDAQ address map with the eprix rogue address map 
    #it is defined the addrSize variable
    addrSize = 4	

    # Creation. memBase is either the register bus server (srp, rce mapped memory, etc) or the device which
    # contains this object. In most cases the parent and memBase are the same but they can be 
    # different in more complex bus structures. They will also be different for the top most node.
    # The setMemBase call can be used to update the memBase for this Device. All sub-devices and local
    # blocks will be updated.
    dev = pyrogue.Device(name=name, memBase=memBase, offset=offset, hidden=hidden, size=0x1000,
                         description='AXI-Lite based common version block', enabled=enabled)

    #############################################
    # Create block / variable combinations
    #############################################

    # Next create a list of variables associated with this block.
    # base has two functions. If base = 'string' then the block is treated as a string (see BuildStamp)
    # otherwise the value is retrieved or set using:
    # setUInt(self.bitOffset,self.bitSize,value) or getUInt(self.bitOffset,self.bitSize)
    # otherwise base is used by a higher level interface (GUI, etc) to determine display mode
    # Allowed modes are RO, WO, RW or SL. SL indicates registers can be written but only
    # when executing commands (not accessed during writeAll and writeStale calls
    #Setup registers & variables
    dev.add(pyrogue.Variable(name='CmdPrepForRead', description='ePix Prepare For Readout',
                             offset=0x00*addrSize, bitSize=32, bitOffset=0, base='hex', mode='RO'))

    # Example of using setFunction and getFunction. setFunction and getFunctions are defined in the class
    # at the bottom. getFunction is defined as a series of python calls. When using the defined
    # function the scope is relative to the location of the function defintion. A pointer to the variable
    # and passed value are provided as args. See UserConstants below for an alernative method.
    dev.add(pyrogue.Variable(name='MonostPulser', description='MonostPulser',
                             offset=0x00001001*addrSize, bitSize=32, bitOffset=0, base='hex', mode='RW'))

    dev.add(pyrogue.Variable(name='PixelDummy', description='PixelDummy',
                             offset=0x00001002*addrSize, bitSize=32, bitOffset=0, base='hex', mode='RW'))

    dev.add(pyrogue.Variable(name='Config3', description='Config3',
                             offset=0x00001003*addrSize, bitSize=32, bitOffset=0, base='hex', mode='RW'))

    dev.add(pyrogue.Variable(name='Config4', description='Config4',
                             offset=0x00001004*addrSize, bitSize=32, bitOffset=0, base='hex', mode='RW'))

    dev.add(pyrogue.Variable(name='PulserDac', description='PulserDac',
                             offset=0x00001005*addrSize, bitSize=32, bitOffset=0, base='hex', mode='RW'))

    dev.add(pyrogue.Variable(name='Config6', description='Config6',
                             offset=0x00001006*addrSize, bitSize=32, bitOffset=0, base='hex', mode='RW'))

    dev.add(pyrogue.Variable(name='VRef', description='VRef',
                             offset=0x00001007*addrSize, bitSize=32, bitOffset=0, base='hex', mode='RW'))

    dev.add(pyrogue.Variable(name='Config8', description='Config8',
                             offset=0x00001008*addrSize, bitSize=32, bitOffset=0, base='hex', mode='RW'))

    dev.add(pyrogue.Variable(name='Config9', description='Config9',
                             offset=0x00001009*addrSize, bitSize=32, bitOffset=0, base='hex', mode='RW'))

    dev.add(pyrogue.Variable(name='Config10', description='Config10',
                             offset=0x0000100A*addrSize, bitSize=32, bitOffset=0, base='hex', mode='RW'))

    dev.add(pyrogue.Variable(name='Config11', description='Config11',
                             offset=0x0000100B*addrSize, bitSize=32, bitOffset=0, base='hex', mode='RW'))

    dev.add(pyrogue.Variable(name='Config12', description='Config12',
                             offset=0x0000100C*addrSize, bitSize=32, bitOffset=0, base='hex', mode='RW'))

    dev.add(pyrogue.Variable(name='Config13', description='Config13',
                             offset=0x0000100D*addrSize, bitSize=32, bitOffset=0, base='hex', mode='RW'))

    dev.add(pyrogue.Variable(name='Config14', description='Config14',
                             offset=0x0000100E*addrSize, bitSize=32, bitOffset=0, base='hex', mode='RW'))

    dev.add(pyrogue.Variable(name='Config15', description='Config15',
                             offset=0x0000100F*addrSize, bitSize=32, bitOffset=0, base='hex', mode='RW'))

    dev.add(pyrogue.Variable(name='Config16', description='Config16',
                             offset=0x00001010*addrSize, bitSize=32, bitOffset=0, base='hex', mode='RW'))

    dev.add(pyrogue.Variable(name='RowStartAddr', description='RowStartAddr',
                             offset=0x00001011*addrSize, bitSize=32, bitOffset=0, base='hex', mode='RW'))

    dev.add(pyrogue.Variable(name='RowStopAddr', description='RowStopAddr',
                             offset=0x00001012*addrSize, bitSize=32, bitOffset=0, base='hex', mode='RW'))

    dev.add(pyrogue.Variable(name='ColStartAddr', description='ColStartAddr',
                             offset=0x00001013*addrSize, bitSize=32, bitOffset=0, base='hex', mode='RW'))

    dev.add(pyrogue.Variable(name='ColStopAddr', description='ColStopAddr',
                             offset=0x00001014*addrSize, bitSize=32, bitOffset=0, base='hex', mode='RW'))

    dev.add(pyrogue.Variable(name='ChipId', description='ChipId',
                             offset=0x00001015*addrSize, bitSize=32, bitOffset=0, base='hex', mode='RW'))

    dev.add(pyrogue.Variable(name='Config22', description='Config22',
                             offset=0x00001016*addrSize, bitSize=32, bitOffset=0, base='hex', mode='RW'))

    dev.add(pyrogue.Variable(name='Config23', description='Config23',
                             offset=0x00001017*addrSize, bitSize=32, bitOffset=0, base='hex', mode='RW'))

    dev.add(pyrogue.Variable(name='Config24', description='Config24',
                             offset=0x00001018*addrSize, bitSize=32, bitOffset=0, base='hex', mode='RW'))

    dev.add(pyrogue.Variable(name='Config25', description='Config25',
                             offset=0x00001019*addrSize, bitSize=32, bitOffset=0, base='hex', mode='RW'))

    dev.add(pyrogue.Variable(name='RowCounter', description='RowCounter',
                             offset=0x00006011*addrSize, bitSize=32, bitOffset=0, base='hex', mode='RW'))

    dev.add(pyrogue.Variable(name='ColCounter', description='ColCounter',
                             offset=0x00006013*addrSize, bitSize=32, bitOffset=0, base='hex', mode='RW'))

    dev.add(pyrogue.Variable(name='WriteRowData', description='WriteRowData',
                             offset=0x00002000*addrSize, bitSize=32, bitOffset=0, base='hex', mode='RW'))

    dev.add(pyrogue.Variable(name='WriteColData', description='WriteColData',
                             offset=0x00003000*addrSize, bitSize=32, bitOffset=0, base='hex', mode='RW'))

    dev.add(pyrogue.Variable(name='WriteMatrixData', description='WriteMatrixData',
                             offset=0x00004000*addrSize, bitSize=32, bitOffset=0, base='hex', mode='RW'))

    dev.add(pyrogue.Variable(name='WritePixelData', description='WritePixelData',
                             offset=0x00005000*addrSize, bitSize=32, bitOffset=0, base='hex', mode='RW'))

    dev.add(pyrogue.Variable(name='PrepareWriteChipIdA', description='PrepareWriteChipIdA',
                             offset=0x00007000*addrSize, bitSize=32, bitOffset=0, base='hex', mode='RW'))

    dev.add(pyrogue.Variable(name='PrepareWriteChipIdB', description='PrepareWriteChipIdB',
                             offset=0x00007015*addrSize, bitSize=32, bitOffset=0, base='hex', mode='RW'))

    dev.add(pyrogue.Variable(name='PrepareMultiConfig', description='PrepareMultiConfig',
                             offset=0x00008000*addrSize, bitSize=32, bitOffset=0, base='hex', mode='RW'))




    # Here we define MasterReset as mode 'SL' this will ensure it does not get written during
    # writeAll and writeStale commands
#    dev.add(pyrogue.Variable(name='masterResetVar', description='Optional User Reset',
#                             offset=0x06*addrSize, bitSize=1, bitOffset=0, base='bool', mode='SL', hidden=True))

#    dev.add(pyrogue.Variable(name='fpgaReloadVar', description='Optional reload the FPGA from the attached PROM',
#                             offset=0x07*addrSize, bitSize=1, bitOffset=0, base='bool', mode='SL', hidden=True))

#    dev.add(pyrogue.Variable(name='fpgaReloadAddress', description='Reload start address',
#                             offset=0x08*addrSize, bitSize=32, bitOffset=0, base='hex', mode='RW'))

#    dev.add(pyrogue.Variable(name='counter', description='Free running counter', pollInterval=1,
#                             offset=0x09*addrSize, bitSize=32, bitOffset=0, base='hex', mode='RO'))

    # Bool is not used locally. Access will occur just as a uint or hex. The GUI will know how to display it.
#    dev.add(pyrogue.Variable(name='fpgaReloadHalt', description='Used to halt automatic reloads via AxiVersion',
#                             offset=0x0A*addrSize, bitSize=1, bitOffset=0, base='bool', mode='RW'))

#    dev.add(pyrogue.Variable(name='upTimeCnt', description='Number of seconds since reset', pollInterval=1,
#                             offset=0x2C, bitSize=32, bitOffset=0, base='uint', units="seconds", mode='RO'))

#    dev.add(pyrogue.Variable(name='deviceId', description='Device identification',
#                             offset=0x30, bitSize=32, bitOffset=0, base='hex', mode='RO'))

#    for i in range(0,64):
#
#        # Example of using setFunction and getFunction passed as strings. The scope is local to 
#        # the variable object with the passed value available as 'value' in the scope.
#        # The get function must set the 'value' variable as a result of the function.
#        dev.add(pyrogue.Variable(name='userConstant_%02i'%(i), description='Optional user input values',
#                                 offset=0x400+(i*4), bitSize=32, bitOffset=0, base='hex', mode='RW',
#                                 getFunction="""\
#                                             value = self._block.getUInt(self.bitOffset,self.bitSize)
#                                             """,
#                                 setFunction="""\
#                                             self._block.setUInt(self.bitOffset,self.bitSize,value)
#                                             """))

#    dev.add(pyrogue.Variable(name='UserConstants', description='User constants string',
#                             offset=0x100*addrSize, bitSize=256*8, bitOffset=0, base='string', mode='RO'))

#    dev.add(pyrogue.Variable(name='buildStamp', description='Firmware build string',
#                             offset=0x200*addrSize, bitSize=256*8, bitOffset=0, base='string', mode='RO'))

    #####################################
    # Create commands
    #####################################

    # A command has an associated function. The function can be a series of
    # python commands in a string. Function calls are executed in the command scope
    # the passed arg is available as 'arg'. Use 'dev' to get to device scope.
#    dev.add(pyrogue.Command(name='masterReset',description='Master Reset',
#                            function='dev.masterResetVar.post(1)'))
    dev.add(pyrogue.Command(name='ClearMatrix',description='Clear matrix',
                            function=cmdClearMatrix))

    dev.add(pyrogue.Command(name='PrepForRead',description='ePix prepare for readout',
                            function=fnPrepForRead))

#    dev.add(pyrogue.Command(name='cmdWriteMatrixData',description='Write matrix data',
#                            function=fnWriteMatrixData))

#    dev.add(pyrogue.Command(name='WriteRowCounter',description='Write row counter',
#                            function=fnWriteRowCounter))

#    dev.add(pyrogue.Command(name='WritePixelData',description='Write pixel data',
#                            function=fnWritePixelData))

#    dev.add(pyrogue.Command(name='ReadPixelData',description='Read pixel data',
#                            function=fnReadPixelData))

#    dev.add(pyrogue.Command(name='WriteRowData',description='Write row data',
#                            function=fn))

 



    
    # A command can also be a call to a local function with local scope.
    # The command object and the arg are passed
#    dev.add(pyrogue.Command(name='fpgaReload',description='Reload FPGA',
#                            function=cmdFpgaReload))

#    dev.add(pyrogue.Command(name='counterReset',description='Counter Reset',
#                            function='dev.counter.post(0)'))

    # Example printing the arg and showing a larger block. The indentation will be adjusted.
#    dev.add(pyrogue.Command(name='testCommand',description='Test Command',
#                            function="""\
#                                     print("Someone executed the %s command" % (self.name))
#                                     print("The passed arg was %s" % (arg))
#                                     print("My device is %s" % (dev.name))
#                                     """))

    # Alternative function for CPSW compatability
    # Pass a dictionary of numbered variable, value pairs to generate a CPSW sequence
#    dev.add(pyrogue.Command(name='testCpsw',description='Test CPSW',
#                            function=collections.OrderedDict({ 'masterResetVar': 1,
#                                                               'usleep': 100,
#                                                               'counter': 1 })))

    # Overwrite reset calls with local functions
#    dev.setResetFunc(resetFunc)

    # Return the created device
    return dev




def cmdClearMatrix(dev,cmd,arg):
    """ClearMatrix command function"""
    reportCmd(dev,cmd,arg)
    for i in range (0, 96):
         dev.PrepareMultiConfig.set(0)
         dev.ColCounter.set(i)
         dev.WriteColData.set(0)
    dev.CmdPrepForRead.set(0)

def fnPrepForRead(dev,cmd,arg):
    """PrepForRead command function"""
    reportCmd(dev,cmd,arg)
    dev.CmdPrepForRead.set(dev.CmdPrepForRead.get())

def fnWriteMatrixData(dev,cmd,arg):
    """WriteMatrixData command function"""
    reportCmd(dev,cmd,arg)
    dev.WriteMatrixData.set(dev.WriteMatrixData.get())
    dev.WriteMatrixData.set(dev.WriteMatrixData.get())
    dev.WriteMatrixData.set(dev.WriteMatrixData.get())
    dev.WriteMatrixData.set(dev.WriteMatrixData.get())
    dev.WriteMatrixData.set(dev.WriteMatrixData.get())

def fnWriteRowCounter(dev,cmd,arg):
    """WriteRowCounter command function"""
    dev.WriteMatrixData.set(dev.WriteMatrixData.get())

def fnWritePixelData(dev,cmd,arg):
    """WritePixelData command function"""
    dev.WriteMatrixData.set(dev.WriteMatrixData.get())

def fnReadPixelData(dev,cmd,arg):
    """ReadPixelData command function"""
    dev.WriteMatrixData.set(dev.WriteMatrixData.get())

def fnWriteRowData(dev,cmd,arg):
    """WriteRowData command function"""
    dev.WriteMatrixData.set(dev.WriteMatrixData.get())

# standard way to report a command has been executed
def reportCmd(dev,cmd,arg):
    """reportCmd command function"""
    "Enables to unify the console print out for all cmds"
    print("Command executed : ", cmd)

#def cmdFpgaReload(dev,cmd,arg):
#    """Example command function"""
#    dev.fpgaReload.post(1)

#def setVariableExample(dev,var,value):
#    """Example set variable function"""
#    var._block.setUInt(var.bitOffset,var.bitSize,value)

#def getVariableExample(dev,var):
#    """Example get variable function"""
#    return(var._block.getUInt(var.bitOffset,var.bitSize))

#def resetFunc(dev,rstType):
#    """Application specific reset function"""
#    if rstType == 'soft':
#        dev.counter.set(0)
#    elif rstType == 'hard':
#        dev.masterResetVar.post(1)
#    elif rstType == 'count':
#        print('AxiVersion countReset')
#        dev.counter.set(0)

