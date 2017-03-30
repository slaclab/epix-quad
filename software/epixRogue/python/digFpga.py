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
# for genDAQ compatibility check software/epix/DigFpga.cpp
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
import ePixAsics as epix

def create(name='DigFpga', offset=0, memBase=None, hidden=False, enabled=True):
    """Create the axiVersion device"""

    #In order to easely compare GedDAQ address map with the eprix rogue address map 
    #it is defined the addrSize variable
    addrSize = 4	

    # Creation. memBase is either the register bus server (srp, rce mapped memory, etc) or the device which
    # contains this object. In most cases the parent and memBase are the same but they can be 
    # different in more complex bus structures. They will also be different for the top most node.
    # The setMemBase call can be used to update the memBase for this Device. All sub-devices and local
    # blocks will be updated.
    dev = pr.Device(name=name, memBase=memBase, offset=offset, hidden=hidden, size=0x1000,
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
    dev.add(pr.Variable(name='Version',             description='FPGA firmware version number',                            offset=0x00000000*addrSize, bitSize=32, bitOffset=0, base='hex',  mode='RO'))
    dev.add(pr.Variable(name='RunTriggerEnable',    description='Enable external run trigger',                             offset=0x00000001*addrSize, bitSize=1,  bitOffset=0, base='bool', mode='RW'))
    dev.add(pr.Variable(name='RunTriggerDelay',     description='Run trigger delay',                                       offset=0x00000002*addrSize, bitSize=31, bitOffset=0, base='hex',  mode='RW'))
    dev.add(pr.Variable(name='DaqTriggerEnable',    description='Enable external run trigger',                             offset=0x00000003*addrSize, bitSize=1,  bitOffset=0, base='bool', mode='RW'))
    dev.add(pr.Variable(name='DaqTriggerDelay',     description='Run trigger delay',                                       offset=0x00000004*addrSize, bitSize=31, bitOffset=0, base='hex',  mode='RW'))
    dev.add(pr.Variable(name='AcqCount',            description='Acquisition counter',                                     offset=0x00000005*addrSize, bitSize=32, bitOffset=0, base='hex',  mode='RO'))
    dev.add(pr.Command( name='AcqCountReset',       description='Reset acquisition counter',                               offset=0x00000006*addrSize, bitSize=32, bitOffset=0, function=pr.Command.touchZero))
    dev.add(pr.Variable(name='DacData',             description='Sets analog DAC (MAX5443)',                               offset=0x00000007*addrSize, bitSize=16, bitOffset=0, base='hex',  mode='RW'))
    dev.add(pr.Variable(name='DigitalPowerEnable',  description='Digital power enable',                                    offset=0x00000008*addrSize, bitSize=1,  bitOffset=0, base='bool', mode='RW'))
    dev.add(pr.Variable(name='AnalogPowerEnable',   description='Analog power enable',                                     offset=0x00000008*addrSize, bitSize=1,  bitOffset=1, base='bool', mode='RW'))
    dev.add(pr.Variable(name='FpgaOutputEnable',    description='Fpga output enable',                                      offset=0x00000008*addrSize, bitSize=1,  bitOffset=2, base='bool', mode='RW'))
    dev.add(pr.Variable(name='IDelayCtrlRdy',       description='Ready flag for IDELAYCTRL block',                         offset=0x0000000A*addrSize, bitSize=32, bitOffset=0, base='hex',  mode='RW'))
    dev.add(pr.Variable(name='SeqCount',            description='Sequence (frame) Counter',                                offset=0x0000000B*addrSize, bitSize=32, bitOffset=0, base='hex',  mode='RO'))
    dev.add(pr.Command( name='SeqCountReset',       description='Reset (frame) counter',                                   offset=0x0000000C*addrSize, bitSize=32, bitOffset=0, function=pr.Command.touch))
    dev.add(pr.Variable(name='AsicMask',            description='ASIC mask bits for the SACI access',                      offset=0x0000000D*addrSize, bitSize=4,  bitOffset=0, base='hex',  mode='RW'))
    dev.add(pr.Variable(name='BaseClock',           description='FPGA base clock frequency',                               offset=0x00000010*addrSize, bitSize=32, bitOffset=0, base='hex',  mode='RO'))
    dev.add(pr.Variable(name='AutoRunEnable',       description='Enable auto run trigger',                                 offset=0x00000011*addrSize, bitSize=1,  bitOffset=0, base='bool', mode='RW'))
    dev.add(pr.Variable(name='AutoRunPeriod',       description='Auto run trigger period',                                 offset=0x00000012*addrSize, bitSize=32, bitOffset=0, base='hex',  mode='RW'))
    dev.add(pr.Variable(name='AutoDaqEnable',       description='Enable auto DAQ trigger',                                 offset=0x00000013*addrSize, bitSize=1,  bitOffset=0, base='bool', mode='RW'))
    dev.add(pr.Variable(name='OutPipelineDelay',    description='Number of clock cycles to delay ASIC digital output bit', offset=0x0000001F*addrSize, bitSize=8,  bitOffset=0, base='hex',  mode='RW'))
    dev.add(pr.Variable(name='AcqToAsicR0Delay',    description='Delay (in 10ns) between system acq and ASIC reset pulse', offset=0x00000020*addrSize, bitSize=31, bitOffset=0, base='hex',  mode='RW'))
    dev.add(pr.Variable(name='AsicR0ToAsicAcq',     description='Delay (in 10ns) between ASIC reset pulse and int. window',offset=0x00000021*addrSize, bitSize=31, bitOffset=0, base='hex',  mode='RW'))
    dev.add(pr.Variable(name='AsicAcqWidth',        description='Width (in 10ns) of ASIC acq signal',                      offset=0x00000022*addrSize, bitSize=31, bitOffset=0, base='hex',  mode='RW')) 
    dev.add(pr.Variable(name='AsicAcqLToPPmatL',    description='Delay (in 10ns) bet. ASIC acq drop and power pulse drop', offset=0x00000023*addrSize, bitSize=31, bitOffset=0, base='hex',  mode='RW'))
    dev.add(pr.Variable(name='AsicRoClkHalfT',      description='Width (in 10ns) of half of readout clock (10 = 5MHz)',    offset=0x00000024*addrSize, bitSize=31, bitOffset=0, base='hex',  mode='RW'))
    dev.add(pr.Variable(name='AdcReadsPerPixel',    description='Number of ADC samples to record for each ASIC',           offset=0x00000025*addrSize, bitSize=31, bitOffset=0, base='hex',  mode='RW'))  
    dev.add(pr.Variable(name='AdcClkHalfT',         description='Width (in 8ns) of half clock period of ADC',              offset=0x00000026*addrSize, bitSize=31, bitOffset=0, base='hex',  mode='RW'))
    dev.add(pr.Variable(name='TotalPixelsToRead',   description='Total numbers of pixels to be readout',                   offset=0x00000027*addrSize, bitSize=31, bitOffset=0, base='hex',  mode='RW'))
    dev.add(pr.Variable(name='AsicGR',              description='ASIC Global Reset',                                       offset=0x00000029*addrSize, bitSize=1,  bitOffset=0, base='bool', mode='RW'))
    dev.add(pr.Variable(name='AsicAcq',             description='ASIC Acq Signal',                                         offset=0x00000029*addrSize, bitSize=1,  bitOffset=1, base='bool', mode='RW'))
    dev.add(pr.Variable(name='AsicRO',              description='ASIC R0 Signal',                                          offset=0x00000029*addrSize, bitSize=1,  bitOffset=2, base='bool', mode='RW'))
    dev.add(pr.Variable(name='AsicPpmat',           description='ASIC Ppmat Signal',                                       offset=0x00000029*addrSize, bitSize=1,  bitOffset=3, base='bool', mode='RW'))
    dev.add(pr.Variable(name='AsicPpbe',            description='ASIC Ppbe Signal',                                        offset=0x00000029*addrSize, bitSize=1,  bitOffset=4, base='bool', mode='RW'))
    dev.add(pr.Variable(name='AsicRoClk',           description='ASIC RO Clock Signal',                                    offset=0x00000029*addrSize, bitSize=1,  bitOffset=5, base='bool', mode='RW'))
    dev.add(pr.Variable(name='AsicPinGRControl',    description='Manual ASIC Global Reset Enabled',                        offset=0x0000002A*addrSize, bitSize=1,  bitOffset=0, base='bool', mode='RW'))
    dev.add(pr.Variable(name='AsicPinAcqControl',   description='Manual ASIC Acq Enabled',                                 offset=0x0000002A*addrSize, bitSize=1,  bitOffset=1, base='bool', mode='RW'))
    dev.add(pr.Variable(name='AsicPinROControl',    description='Manual ASIC R0 Enabled',                                  offset=0x0000002A*addrSize, bitSize=1,  bitOffset=2, base='bool', mode='RW'))
    dev.add(pr.Variable(name='AsicPinPpmatControl', description='Manual ASIC Ppmat Enabled',                               offset=0x0000002A*addrSize, bitSize=1,  bitOffset=3, base='bool', mode='RW'))
    dev.add(pr.Variable(name='AsicPinPpbeControl',  description='Manual ASIC Ppbe Enabled',                                offset=0x0000002A*addrSize, bitSize=1,  bitOffset=4, base='bool', mode='RW'))
    dev.add(pr.Variable(name='AsicPinROClkControl', description='Manual ASIC RO Clock Enabled',                            offset=0x0000002A*addrSize, bitSize=1,  bitOffset=5, base='bool', mode='RW'))
    dev.add(pr.Variable(name='AdcStreamMode',       description='Enables manual test of ADC',                              offset=0x0000002A*addrSize, bitSize=1,  bitOffset=7, base='bool', mode='RW'))
    dev.add(pr.Variable(name='AdcPatternEnable',    description='Enables test pattern on data out',                        offset=0x0000002A*addrSize, bitSize=1,  bitOffset=8, base='bool', mode='RW'))
    dev.add(pr.Variable(name='AsicR0Width',         description='Width of R0 low pulse',                                   offset=0x0000002B*addrSize, bitSize=31, bitOffset=0, base='hex',  mode='RW'))
    dev.add(pr.Variable(name='DigitalCardId0',      description='Digital Card Serial Number (low 32 bits)',                offset=0x00000030*addrSize, bitSize=32, bitOffset=0, base='hex',  mode='RW'))
    dev.add(pr.Variable(name='DigitalCardId1',      description='Digital Card Serial Number (high 32 bits)',               offset=0x00000031*addrSize, bitSize=32, bitOffset=0, base='hex',  mode='RW'))
    dev.add(pr.Variable(name='AnalogCardId0',       description='Analog Card Serial Number (low 32 bits)',                 offset=0x00000032*addrSize, bitSize=32, bitOffset=0, base='hex',  mode='RW'))
    dev.add(pr.Variable(name='AnalogCardId1',       description='Analog Card Serial Number (high 32 bits)',                offset=0x00000033*addrSize, bitSize=32, bitOffset=0, base='hex',  mode='RW'))
    dev.add(pr.Variable(name='AsicPreAcqTime',      description='Sum of time delays leading to the ASIC ACQ pulse',        offset=0x00000039*addrSize, bitSize=32, bitOffset=0, base='hex',  mode='RO'))
    dev.add(pr.Variable(name='AsicPPmatToReadout',  description='Delay (in 10ns) between Ppmat pulse and readout',         offset=0x0000003A*addrSize, bitSize=31, bitOffset=0, base='hex',  mode='RW'))
    dev.add(pr.Variable(name='CarrierCardId0',      description='Carrier Card Serial Number (low 32 bits)',                offset=0x0000003B*addrSize, bitSize=32, bitOffset=0, base='hex',  mode='RO'))
    dev.add(pr.Variable(name='CarrierCardId1',      description='Carrier Card Serial Number (high 32 bits)',               offset=0x0000003C*addrSize, bitSize=32, bitOffset=0, base='hex',  mode='RO'))
    dev.add(pr.Variable(name='PgpTrigEn',           description='Set to enable triggering over PGP. Disables the TTL trigger input', offset=0x0000003D*addrSize, bitSize=1, bitOffset=0, base='bool', mode='RW'))
    dev.add(pr.Variable(name='MonStreamEn',         description='Set to enable monitor data stream over PGP',              offset=0x0000003E*addrSize, bitSize=1,  bitOffset=0, base='bool', mode='RW'))
    dev.add(pr.Variable(name='TpsTiming',           description='Delay TPS signal',                                        offset=0x00000040*addrSize, bitSize=16, bitOffset=0, base='hex',  mode='RW'))
    dev.add(pr.Variable(name='TpsEdge',             description='Sync TPS to rising or falling edge of Acq',               offset=0x00000040*addrSize, bitSize=1,  bitOffset=16,base='bool', mode='RW'))
    dev.add(pr.Variable(name='SwArmBit',            description='Software arm bit',                                        offset=0x00000050*addrSize, bitSize=1,  bitOffset=0, base='bool', mode='RW'))
    dev.add(pr.Variable(name='SwTrgBit',            description='Software trigger bit',                                    offset=0x00000051*addrSize, bitSize=1,  bitOffset=0, base='bool', mode='WO'))
    dev.add(pr.Variable(name='TriggerADCEn',        description='Trigger ADC enable',                                      offset=0x00000052*addrSize, bitSize=1,  bitOffset=0, base='bool', mode='RW'))
    dev.add(pr.Variable(name='TriggerADCTh',        description='Trigger ADC threshold',                                   offset=0x00000052*addrSize, bitSize=16, bitOffset=16,base='hex',  mode='RW'))
    dev.add(pr.Variable(name='TriggerADCMode',      description='Trigger ADC mode',                                        offset=0x00000052*addrSize, bitSize=2,  bitOffset=5, base='hex',  mode='RW'))
    dev.add(pr.Variable(name='TriggerADCChannel',   description='Trigger ADC channel',                                     offset=0x00000052*addrSize, bitSize=4,  bitOffset=2, base='hex',  mode='RW'))
    dev.add(pr.Variable(name='TriggerADCEdge',      description='Trigger ADC edge',                                        offset=0x00000052*addrSize, bitSize=1,  bitOffset=1, base='bool', mode='RW'))
    dev.add(pr.Variable(name='TriggerHoldOff',      description='Number of samples to wait after the trigger is armed',    offset=0x00000053*addrSize, bitSize=13, bitOffset=0, base='hex',  mode='RW'))
    dev.add(pr.Variable(name='TriggerTraceSkip',    description='Number of samples to skip before recording starts',       offset=0x00000054*addrSize, bitSize=13, bitOffset=13,base='hex',  mode='RW'))
    dev.add(pr.Variable(name='TriggerTraceLength',  description='Number of samples to record',                             offset=0x00000054*addrSize, bitSize=13, bitOffset=0, base='hex',  mode='RW'))
    dev.add(pr.Variable(name='InputChannelB',       description='Select input channel B',                                  offset=0x00000055*addrSize, bitSize=5,  bitOffset=5, base='hex',  mode='RW'))
    dev.add(pr.Variable(name='InputChannelA',       description='Select input channel A',                                  offset=0x00000055*addrSize, bitSize=5,  bitOffset=0, base='hex',  mode='RW'))
    dev.add(pr.Variable(name='RequestStartup',      description='Request startup sequence',                                offset=0x00000080*addrSize, bitSize=1,  bitOffset=0, base='bool', mode='RW'))
    dev.add(pr.Variable(name='StartupDone',         description='Startup sequence done',                                   offset=0x00000080*addrSize, bitSize=1,  bitOffset=1, base='bool', mode='RO'))
    dev.add(pr.Variable(name='StartupFail',         description='Startup sequence failed',                                 offset=0x00000080*addrSize, bitSize=1,  bitOffset=2, base='bool', mode='RO'))
    dev.add(pr.Variable(name='RequestConfDump',     description='Request Conf. Dump',                                      offset=0x00000081*addrSize, bitSize=1,  bitOffset=0, base='bool', mode='WO'))
    dev.add(pr.Variable(name='AdcPipelineDelayA0',  description='Number of samples to delay ADC reads of the ASIC0 chls',  offset=0x00000090*addrSize, bitSize=8,  bitOffset=0, base='hex',  mode='RW'))
    dev.add(pr.Variable(name='AdcPipelineDelayA1',  description='Number of samples to delay ADC reads of the ASIC1 chls',  offset=0x00000091*addrSize, bitSize=8,  bitOffset=0, base='hex',  mode='RW'))
    dev.add(pr.Variable(name='AdcPipelineDelayA2',  description='Number of samples to delay ADC reads of the ASIC2 chls',  offset=0x00000092*addrSize, bitSize=8,  bitOffset=0, base='hex',  mode='RW'))
    dev.add(pr.Variable(name='AdcPipelineDelayA3',  description='Number of samples to delay ADC reads of the ASIC3 chls',  offset=0x00000093*addrSize, bitSize=8,  bitOffset=0, base='hex',  mode='RW'))
    dev.add(pr.Variable(name='EnvData00',           description='Thermistor0 temperature',                                 offset=0x00000140*addrSize, bitSize=32, bitOffset=0, base='hex',  mode='RO'))
    dev.add(pr.Variable(name='EnvData01',           description='Thermistor1 temperature',                                 offset=0x00000141*addrSize, bitSize=32, bitOffset=0, base='hex',  mode='RO'))
    dev.add(pr.Variable(name='EnvData02',           description='Humidity',                                                offset=0x00000142*addrSize, bitSize=32, bitOffset=0, base='hex',  mode='RO'))
    dev.add(pr.Variable(name='EnvData03',           description='ASIC analog current',                                     offset=0x00000143*addrSize, bitSize=32, bitOffset=0, base='hex',  mode='RO'))
    dev.add(pr.Variable(name='EnvData04',           description='ASIC digital current',                                    offset=0x00000144*addrSize, bitSize=32, bitOffset=0, base='hex',  mode='RO'))
    dev.add(pr.Variable(name='EnvData05',           description='Guard ring current',                                      offset=0x00000145*addrSize, bitSize=32, bitOffset=0, base='hex',  mode='RO'))
    dev.add(pr.Variable(name='EnvData06',           description='Detector bias current',                                   offset=0x00000146*addrSize, bitSize=32, bitOffset=0, base='hex',  mode='RO'))
    dev.add(pr.Variable(name='EnvData07',           description='Analog raw input voltage',                                offset=0x00000147*addrSize, bitSize=32, bitOffset=0, base='hex',  mode='RO'))
    dev.add(pr.Variable(name='EnvData08',           description='Digital raw input voltage',                               offset=0x00000148*addrSize, bitSize=32, bitOffset=0, base='hex',  mode='RO'))

    #####################################
    # Create commands
    #####################################

    dev.add(pr.Command(name='masterReset',   description='Master Board Reset', function=pr.Command.postedTouch))
    dev.add(pr.Command(name='fpgaReload',    description='Reload FPGA',        function=cmdFpgaReload))
    dev.add(pr.Command(name='counterReset',  description='Counter Reset',      function='dev.counter.post(0)'))
    dev.add(pr.Command(name='testCpsw',      description='Test CPSW',          function=collections.OrderedDict({ 'masterResetVar': 1, 'usleep': 100, 'counter': 1 })))

    # Overwrite reset calls with local functions
    dev.setResetFunc(resetFunc)

    # Create subdevices
    dev.add(epix.Epix100aAsic(name='Epix100aAsic0', offset=0x00800000*addrSize, memBase=memBase, hidden=False, enabled=False))
    dev.add(epix.Epix100aAsic(name='Epix100aAsic1', offset=0x00900000*addrSize, memBase=memBase, hidden=False, enabled=False))
    dev.add(epix.Epix100aAsic(name='Epix100aAsic2', offset=0x00A00000*addrSize, memBase=memBase, hidden=False, enabled=False))
    dev.add(epix.Epix100aAsic(name='Epix100aAsic3', offset=0x00B00000*addrSize, memBase=memBase, hidden=False, enabled=False))

    #addDevice(new Pgp2bAxi(destination, baseAddress_ + 0x000C0000*addrSize,  0, this, addrSize)); 
    #addDevice(new AxiVersion(destination, baseAddress_ + 0x02000000*addrSize,  0, this, addrSize)); 
    #addDevice(new AxiMicronN25Q(destination, baseAddress_ + 0x03000000*addrSize, 0, this, addrSize)); 
    #addDevice(new LogMemory(destination, baseAddress_ + 0x09000000*addrSize, 0, this, addrSize)); 

    # Return the created device
    return dev



def cmdFpgaReload(dev,cmd,arg):
    """Example command function"""
    dev.Version.post(1)

#def setVariableExample(dev,var,value):
#    """Example set variable function"""
#    var._block.setUInt(var.bitOffset,var.bitSize,value)

#def getVariableExample(dev,var):
#    """Example get variable function"""
#    return(var._block.getUInt(var.bitOffset,var.bitSize))

def resetFunc(dev,rstType):
    """Application specific reset function"""
    if rstType == 'soft':
         print('AxiVersion countReset')
#        dev.counter.set(0)
    elif rstType == 'hard':
        dev.masterResetVar.post(1)
    elif rstType == 'count':
        print('AxiVersion countReset')
#        dev.counter.set(0)

