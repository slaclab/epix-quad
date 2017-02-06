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
import pyrogue as pr
import collections

#import epix.Epix100aAsic

class Epix100aAsic(pr.Device):
    def __init__(self, **kwargs):
        """Create the axiVersion device for ePix100aAsic"""
        super().__init__(description='Epix100a Asic Configuration', **kwargs)


        #In order to easily compare GenDAQ address map with the ePrix rogue address map 
        #it is defined the addrSize variable
        addrSize = 4	

        # Creation. memBase is either the register bus server (srp, rce mapped memory, etc) or the device which
        # contains this object. In most cases the parent and memBase are the same but they can be 
        # different in more complex bus structures. They will also be different for the top most node.
        # The setMemBase call can be used to update the memBase for this Device. All sub-devices and local
        # blocks will be updated.

        #############################################
        # Create block / variable combinations
        #############################################
    
        
        #Setup registers & variables
                
        # CMD = 0, Addr = 0  : Prepare for readout
        self.add(pr.Command(name='CmdPrepForRead', description='ePix Prepare For Readout', 
                             offset=0x00000000*addrSize, bitSize=1, bitOffset=0, function=pr.Command.touch))
        
        # CMD = 1, Addr = 1  : Bits 2:0 - Pulser monostable bits
        #                      Bit  7   - Pulser sync bit
        self.add((pr.Variable(name='MonostPulser', description='MonoSt Pulser bits',   offset=0x00001001*addrSize, bitSize=3, bitOffset=0, base='hex', mode='RW'),
                 pr.Command( name='PulserSync',   description='Pulse on SYNC signal', offset=0x00001001*addrSize, bitSize=1, bitOffset=7, function=pr.Command.touch)))
        # CMD = 1, Addr = 2  : Pixel dummy, write data
        #                    : Bit 0 = Test
        #                    : Bit 1 = Test
        self.add(pr.Variable(name='PixelDummy', description='Pixel dummy, write data', offset=0x00001002*addrSize, bitSize=32, bitOffset=0, base='hex', mode='RW'))
        
        # TODO
        # check Variable("DummyMask") and Variable("DummyTest")
        # these variables don't seem to be needed in the rogue version of the software.

        # CMD = 1, Addr = 3  : Bits 9:0 = Pulser[9:0]
        #                    : Bit  10  = pbit
        #                    : Bit  11  = atest
        #                    : Bit  12  = test
        #                    : Bit  13  = sab_test
        #                    : Bit  14  = hrtest
        #                    : Bit  15  = PulserR
        self.add((
            pr.Variable(name='Pulser',   description='Config3', offset=0x00001003*addrSize, bitSize=10, bitOffset=0,  base='hex',  mode='RW'),
            pr.Variable(name='pbit',     description='Config3', offset=0x00001003*addrSize, bitSize=1,  bitOffset=10, base='bool', mode='RW'),
            pr.Variable(name='atest',    description='Config3', offset=0x00001003*addrSize, bitSize=1,  bitOffset=11, base='bool', mode='RW'),
            pr.Variable(name='test',     description='Config3', offset=0x00001003*addrSize, bitSize=1,  bitOffset=12, base='bool', mode='RW'),
            pr.Variable(name='sba_test', description='Config3', offset=0x00001003*addrSize, bitSize=1,  bitOffset=13, base='bool', mode='RW'),
            pr.Variable(name='hrtest',   description='Config3', offset=0x00001003*addrSize, bitSize=1,  bitOffset=14, base='bool', mode='RW'),
            pr.Variable(name='PulserR',  description='Config3', offset=0x00001003*addrSize, bitSize=1,  bitOffset=15, base='bool', mode='RW')))

        # CMD = 1, Addr = 4  : Bits 3:0 = DM1[3:0]
        #                    : Bits 7:4 = DM2[3:0]
        self.add(pr.Variable(name='Config4', description='Config4',offset=0x00001004*addrSize, bitSize=32, bitOffset=0, base='hex', mode='RW'))
        
        self.add(pr.Variable(name='DigMon1', base='enum', mode='RW', enum={0:'Clk', 1:'Exec', 2:'RoRst', 3:'Ack',
            4:'IsEn', 5:'RoWClk', 6:'Addr0', 7:'Addr1', 8:'Addr2', 9:'Addr3', 10:'Addr4', 11:'Cmd0', 12:'Cmd1',
            13:'Cmd2', 14:'Cmd3', 15:'Config'}, description='Run rate of the system.'))         

        self.add(pr.Variable(name='DigMon2', base='enum', mode='RW', enum={0:'Clk', 1:'Exec', 2:'RoRst', 3:'Ack',
            4:'IsEn', 5:'RoWClk', 6:'Db0', 7:'Db1', 8:'Db2', 9:'Db3', 10:'Db4', 11:'Db5', 12:'Db6', 13:'Db7',
            14:'AddrMot', 15:'Config'}, description='Run rate of the system.'))         
 
        # CMD = 1, Addr = 5  : Bits 2:0 = Pulser DAC[2:0]
        #                      Bits 7:4 = TPS_GR[3:0]
        self.add((
            pr.Variable(name='PulserDac', description='Pulser Dac', offset=0x00001005*addrSize, bitSize=3, bitOffset=0, base='hex', mode='RW'),
            pr.Variable(name='TpsGr',     description='',           offset=0x00001005*addrSize, bitSize=4, bitOffset=4, base='hex', mode='RW')))

        # CMD = 1, Addr = 6  : Bit  0   = DM1en
        #                    : Bit  1   = DM2en
        #                    : Bit  4   = SLVDSbit
        self.add((
            pr.Variable(name='Dm1En', description='Digital Monitor 1 Enable', offset=0x00001006*addrSize, bitSize=1, bitOffset=0, base='bool', mode='RW'),
            pr.Variable(name='Dm2En', description='Digital Monitor 1 Enable', offset=0x00001006*addrSize, bitSize=1, bitOffset=1, base='bool', mode='RW'),
            pr.Variable(name='SLVDSbit', description='',                      offset=0x00001006*addrSize, bitSize=1, bitOffset=4, base='bool', mode='RW')))
      
        # CMD = 1, Addr = 7  : Bit  5:0 = VREF[5:0]
        #                    : Bit  7:6 = VrefLow[1:0]
        self.add((
            pr.Variable(name='VRef',    description='Voltage Ref',                offset=0x00001007*addrSize, bitSize=6, bitOffset=0, base='hex', mode='RW'),
            pr.Variable(name='VRefLow', description='Voltage Ref for Extra Rows', offset=0x00001007*addrSize, bitSize=2, bitOffset=6, base='hex', mode='RW')))

        # CMD = 1, Addr = 8  : Bit  0   = TPS_tcomp
        #                    : Bit  4:1 = TPS_MUX[3:0]
        #                    : Bit  7:5 = RO_Monost[2:0]
        self.add((
            pr.Variable(name='TPS_tcomp',  description='', offset=0x00001008*addrSize, bitSize=1, bitOffset=0, base='bool', mode='RW'),
            pr.Variable(name='TPS_MUX',    description='', offset=0x00001008*addrSize, bitSize=4, bitOffset=1, base='hex',  mode='RW'),
            pr.Variable(name='TPS_Monost', description='', offset=0x00001008*addrSize, bitSize=3, bitOffset=5, base='hex',  mode='RW')))
        self.add(pr.Variable(name='TpsMux', base='enum', mode='RW', enum={0:'in', 1:'fin', 2:'fo', 3:'abus', 4:'cdso3', 5:'bgr_2V', 
             6:'bgr_2vd', 7:'vc_comp', 8:'vcmi', 9:'Pix_Vref', 10:'VtestBE', 11:'Pix_Vctrl', 12:'testline', 
             13:'Unused13', 14:'Unused14', 15:'Unused15'}, description='Analog Test Point Multiplexer'))         
       
        self.add(
            pr.Variable(name='RoMonost', description='', bitSize=8, bitOffset=0, base='hex',  mode='RW'))

        # CMD = 1, Addr = 9  : Bit  3:0 = S2D0_GR[3:0]
        #                    : Bit  7:4 = S2D1_GR[3:0]
        self.add((
            pr.Variable(name='S2d0Gr', description='', offset=0x00001009*addrSize, bitSize=4, bitOffset=0, base='hex', mode='RW'),
            pr.Variable(name='S2d1Gr', description='', offset=0x00001009*addrSize, bitSize=4, bitOffset=4, base='hex', mode='RW')))
  
        # CMD = 1, Addr = 10 : Bit  0   = PP_OCB_S2D
        #                    : Bit  3:1 = OCB[2:0]
        #                    : Bit  6:4 = Monost[2:0]
        #                    : Bit  7   = fastpp_enable
        self.add((
            pr.Variable(name='PpOcbS2d',     description='', offset=0x0000100A*addrSize, bitSize=1, bitOffset=0, base='bool', mode='RW'),
            pr.Variable(name='Ocb',          description='', offset=0x0000100A*addrSize, bitSize=3, bitOffset=1, base='hex',  mode='RW'),
            pr.Variable(name='Monost',       description='', offset=0x0000100A*addrSize, bitSize=3, bitOffset=4, base='hex',  mode='RW'),
            pr.Variable(name='FastppEnable', description='', offset=0x0000100A*addrSize, bitSize=1, bitOffset=7, base='bool', mode='RW')))
     
        # CMD = 1, Addr = 11 : Bit  2:0 = Preamp[2:0]
        #                    : Bit  5:3 = Pixel_CB[2:0]
        #                    : Bit  7:6 = Vld1_b[1:0]
        self.add((
            pr.Variable(name='Preamp',  description='', offset=0x0000100B*addrSize, bitSize=3, bitOffset=0, base='hex', mode='RW'),
            pr.Variable(name='PixelCb', description='', offset=0x0000100B*addrSize, bitSize=3, bitOffset=3, base='hex', mode='RW'),
            pr.Variable(name='Vld1_b',  description='', offset=0x0000100B*addrSize, bitSize=2, bitOffset=6, base='hex', mode='RW')))

        # CMD = 1, Addr = 12 : Bit  0   = S2D_tcomp
        #                    : Bit  6:1 = Filter_Dac[5:0]
        self.add((
            pr.Variable(name='S2dTComp',  description='', offset=0x0000100C*addrSize, bitSize=1, bitOffset=0, base='bool', mode='RW'),
            pr.Variable(name='FilterDac', description='', offset=0x0000100C*addrSize, bitSize=6, bitOffset=1, base='hex',  mode='RW')))

        # CMD = 1, Addr = 13 : Bit  1:0 = tc[1:0]
        #                    : Bit  4:2 = S2D[2:0]
        #                    : Bit  7:5 = S2D_DAC_BIAS[2:0]
        self.add((
            pr.Variable(name='TC',         description='', offset=0x0000100D*addrSize, bitSize=2, bitOffset=0, base='hex', mode='RW'),
            pr.Variable(name='S2d',        description='', offset=0x0000100D*addrSize, bitSize=3, bitOffset=2, base='hex', mode='RW'),
            pr.Variable(name='S2dDacBias', description='', offset=0x0000100D*addrSize, bitSize=3, bitOffset=5, base='hex', mode='RW')))

        # CMD = 1, Addr = 14 : Bit  1:0 = tps_tcDAC[1:0]
        #                    : Bit  7:2 = TPS_DAC[5:0]
        self.add((
            pr.Variable(name='TpsTcDac', description='', offset=0x0000100E*addrSize, bitSize=2, bitOffset=0, base='hex', mode='RW'),
            pr.Variable(name='TpsDac',   description='', offset=0x0000100E*addrSize, bitSize=6, bitOffset=2, base='hex', mode='RW')))

        # CMD = 1, Addr = 15 : Bit  1:0 = S2D0_tcDAC[1:0]
        #                    : Bit  7:2 = S2D0_DAC[5:0]
        self.add((
            pr.Variable(name='S2d0TcDac', description='', offset=0x0000100F*addrSize, bitSize=2, bitOffset=0, base='hex', mode='RW'),
            pr.Variable(name='S2d0Dac',   description='', offset=0x0000100F*addrSize, bitSize=6, bitOffset=2, base='hex', mode='RW')))

        # CMD = 1, Addr = 16 : Bit  0   = test_BE
        #                    : Bit  1   = is_en
        #                    : Bit  2   = delEXEC
        #                    : Bit  3   = delCCkreg
        #                    : Bit  4   = ro_rst_exten
        self.add((
            pr.Variable(name='TestBe',       description='', offset=0x00001010*addrSize, bitSize=1, bitOffset=0, base='bool', mode='RW'),
            pr.Variable(name='IsEn',         description='', offset=0x00001010*addrSize, bitSize=1, bitOffset=1, base='bool', mode='RW'),
            pr.Variable(name='DelExec',      description='', offset=0x00001010*addrSize, bitSize=1, bitOffset=2, base='bool', mode='RW'),
            pr.Variable(name='DelCckRef',    description='', offset=0x00001010*addrSize, bitSize=1, bitOffset=3, base='bool', mode='RW'),
            pr.Variable(name='ro_rst_exten', description='', offset=0x00001010*addrSize, bitSize=1, bitOffset=4, base='bool', mode='RW')))

        # CMD = 1, Addr = 17 : Row start  address[9:0]
        # CMD = 1, Addr = 18 : Row stop  address[9:0]
        # CMD = 1, Addr = 19 : Col start  address[9:0]
        # CMD = 1, Addr = 20 : Col stop  address[9:0]
        self.add((
            pr.Variable(name='RowStartAddr', description='RowStartAddr', offset=0x00001011*addrSize, bitSize=10, bitOffset=0, base='hex', mode='RW'),
            pr.Variable(name='RowStopAddr',  description='RowStopAddr',  offset=0x00001012*addrSize, bitSize=10, bitOffset=0, base='hex', mode='RW'),
            pr.Variable(name='ColStartAddr', description='ColStartAddr', offset=0x00001013*addrSize, bitSize=10, bitOffset=0, base='hex', mode='RW'),
            pr.Variable(name='ColStopAddr',  description='ColStopAddr',  offset=0x00001014*addrSize, bitSize=10, bitOffset=0, base='hex', mode='RW')))
   
        #  CMD = 1, Addr = 21 : Chip ID Read
        self.add(
            pr.Variable(name='ChipId', description='ChipId', offset=0x00001015*addrSize, bitSize=32, bitOffset=0, base='hex', mode='RW'))

        # CMD = 1, Addr = 22 : Bit  3:0 = S2D2GR[3:0]
        #                    : Bit  7:4 = S2D3GR[5:0] #TODO check it this is not 3:0??
        self.add((
            pr.Variable(name='S2d2Gr', description='', offset=0x00001016*addrSize, bitSize=4, bitOffset=0, base='hex', mode='RW'),
            pr.Variable(name='S2d3Gr', description='', offset=0x00001016*addrSize, bitSize=4, bitOffset=4, base='hex', mode='RW')))

        # CMD = 1, Addr = 23 : Bit  1:0 = S2D1_tcDAC[1:0]
        #                    : Bit  7:2 = S2D1_DAC[5:0]
        # CMD = 1, Addr = 24 : Bit  1:0 = S2D2_tcDAC[1:0]
        #                    : Bit  7:2 = S2D2_DAC[5:0]  
        # CMD = 1, Addr = 25 : Bit  1:0 = S2D3_tcDAC[1:0]
        #                    : Bit  7:2 = S2D3_DAC[5:0]
        self.add((
            pr.Variable(name='S2d1TcDac', description='', offset=0x00001017*addrSize, bitSize=2, bitOffset=0, base='hex', mode='RW'),
            pr.Variable(name='S2d1Dac',   description='', offset=0x00001017*addrSize, bitSize=6, bitOffset=2, base='hex', mode='RW'),
            pr.Variable(name='S2d2TcDac', description='', offset=0x00001018*addrSize, bitSize=2, bitOffset=0, base='hex', mode='RW'),
            pr.Variable(name='S2d2Dac',   description='', offset=0x00001018*addrSize, bitSize=6, bitOffset=2, base='hex', mode='RW'),
            pr.Variable(name='S2d3TcDac', description='', offset=0x00001019*addrSize, bitSize=2, bitOffset=0, base='hex', mode='RW'),
            pr.Variable(name='S2d3Dac',   description='', offset=0x00001019*addrSize, bitSize=6, bitOffset=2, base='hex', mode='RW')))

        # CMD = 6, Addr = 17 : Row counter[8:0]
        self.add((
            pr.Variable(name='RowCounter', description='RowCounter', bitSize=9, bitOffset=0, base='hex', mode='RW'),
            pr.Command( name='WriteRowCounter', description='Special command to write row counter', offset=0x00006011*addrSize, bitSize=9, bitOffset=0, function=self.fnWriteRowCounter)))

        # CMD = 6, Addr = 19 : Bank select [3:0] & Col counter[6:0]
        self.add((
            pr.Variable(name='ColCounter', description='',                                offset=0x00006013*addrSize, bitSize=9, bitOffset=0, base='hex', mode='RW'),
            pr.Variable(name='BankSelect', description='Active low bank select bit mask', offset=0x00006013*addrSize, bitSize=9, bitOffset=0, base='hex', mode='RW')))

        # CMD = 2, Addr = X  : Write Row with data
        self.add((
            pr.Command(name='WriteRowData',    description='Write PixelTest and PixelMask to selected row', offset=0x00002000*addrSize, bitSize=1, bitOffset=0, function=self.fnWriteRowData)))

        # CMD = 3, Addr = X  : Write Column with data
        self.add(
            pr.Variable(name='WriteColData',    description='', offset=0x00003000*addrSize, bitSize=32, bitOffset=0, base='hex', mode='RW'))

        # CMD = 4, Addr = X  : Write Matrix with data        
        self.add(    
            pr.Command(name='WriteMatrixData', description='Write PixelTest and PixelMask to all pixels', offset=0x00004000*addrSize, bitSize=1, bitOffset=0, function=self.fnWriteMatrixData))

        # CMD = 5, Addr = X  : Read/Write Pixel with data
        self.add((
            pr.Command(name='WritePixelData', description='Write PixelTest and PixelMask to current pixel only',  offset=0x00005000*addrSize, bitSize=32, bitOffset=0, function=self.fnWritePixelData),
            pr.Command(name='ReadPixelData',  description='Read PixelTest and PixelMask from current pixel only', offset=0x00005000*addrSize, bitSize=32, bitOffset=0, function=self.fnReadPixelData)))

        # CMD = 7, Addr = X  : Prepare to write chip ID
        self.add((
            pr.Variable(name='PrepareWriteChipIdA', description='PrepareWriteChipIdA', offset=0x00007000*addrSize, bitSize=32, bitOffset=0, base='hex', mode='RW'),
            pr.Variable(name='PrepareWriteChipIdB', description='PrepareWriteChipIdB', offset=0x00007015*addrSize, bitSize=32, bitOffset=0, base='hex', mode='RW')))
      
        # CMD = 8, Addr = X  : Prepare for row/column/matrix configuration
        self.add(
            pr.Variable(name='PrepareMultiConfig', description='PrepareMultiConfig', offset=0x00008000*addrSize, bitSize=32, bitOffset=0, base='hex', mode='RW'))

        # Pixel Configuration
        #                    : Bit 0 = Test
        #                    : Bit 1 = Test



        #####################################
        # Create commands
        #####################################

        # A command has an associated function. The function can be a series of
        # python commands in a string. Function calls are executed in the command scope
        # the passed arg is available as 'arg'. Use 'dev' to get to device scope.
        # A command can also be a call to a local function with local scope.
        # The command object and the arg are passed

        self.add(
            pr.Command(name='ClearMatrix',description='Clear configuration bits of all pixels', function=self.fnClearMatrix))

       

    def fnClearMatrix(dev,cmd,arg):
        """ClearMatrix command function"""
        reportCmd(dev,cmd,arg)
        for i in range (0, 96):
            self.PrepareMultiConfig.set(0)
            self.ColCounter.set(i)
            self.WriteColData.set(0)
        self.CmdPrepForRead.set(0)

    def fnWriteMatrixData(dev,cmd,arg):
        """WriteMatrixData command function"""
        reportCmd(dev,cmd,arg)
        self.PrepareMultiConfig.set(self.PrepareMultiConfig.get())
        self.PixelTest.set(self.PixelTest.get())
        self.PixelMask.set(self.PixelMask.get())
        self.CmdPrepForRead.set(self.CmdPrepForRead.get())

    def fnWriteRowCounter(dev,cmd,arg):
        """WriteRowCounter command function"""
        self.CmdPrepForRead.set(self.CmdPrepForRead.get())
        self.RowCounter.set(self.RowCounter.get())

    def fnWritePixelData(dev,cmd,arg):
        """WritePixelData command function"""
        self.PrepareMultiConfig.set(self.PrepareMultiConfig.get())
        self.RowCounter.set(self.RowCounter.get())
        self.ColCounter.set(self.ColCounter.get())
        self.BankSelect.set(self.BankSelect.get())
        self.PixelTest.set(self.PixelTest.get())
        self.PixelMask.set(self.PixelMask.get())

    def fnReadPixelData(dev,cmd,arg):
        """ReadPixelData command function"""
        self.PrepareMultiConfig.set(self.PrepareMultiConfig.get())
        self.RowCounter.set(self.RowCounter.get())
        self.ColCounter.set(self.ColCounter.get())
        self.BankSelect.set(self.BankSelect.get())
        self.PixelTest.get()
        self.PixelMask.get()

    def fnWriteRowData(dev,cmd,arg):
        """WriteRowData command function"""
        self.CmdPrepForRead.set(self.CmdPrepForRead.get())
        self.PrepareMultiConfig.set(self.PrepareMultiConfig.get())
        self.RowCounter.set(self.RowCounter.get())
        self.PixelTest.set(self.PixelTest.get())
        self.PixelMask.set(self.PixelMask.get())

    # standard way to report a command has been executed
    def reportCmd(dev,cmd,arg):
        """reportCmd command function"""
        "Enables to unify the console print out for all cmds"
        print("Command executed : ", cmd)

