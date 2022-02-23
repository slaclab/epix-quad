#!/usr/bin/env python
# -----------------------------------------------------------------------------
# Title      : PyRogue AXI Version Module
# -----------------------------------------------------------------------------
# File       :
# Author     : Maciej Kwiatkowski
# Created    : 2016-09-29
# Last update: 2017-01-31
# -----------------------------------------------------------------------------
# Description:
# -----------------------------------------------------------------------------
# This file is part of the rogue software platform. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the rogue software platform, including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
# -----------------------------------------------------------------------------
import pyrogue as pr
import collections


class SystemRegs(pr.Device):
    def __init__(self, **kwargs):
        """Create SystemRegs"""
        super().__init__(description='System Regsisters', **kwargs)

        # Creation. memBase is either the register bus server (srp, rce mapped memory, etc) or the device which
        # contains this object. In most cases the parent and memBase are the same but they can be
        # different in more complex bus structures. They will also be different for the top most node.
        # The setMemBase call can be used to update the memBase for this Device. All sub-devices and local
        # blocks will be updated.

        def getPerMs(var):
            x = var.dependencies[0].value()
            return x / 100000.0

        def setPerMs(deps):
            def setMsValue(value):
                rawVal = int(round(value * 100000))
                deps[0].set(rawVal)
            return setMsValue

        def getFreqHz(var):
            x = var.dependencies[0].value()
            if x != 0:
                return 100000000.0 / x
            else:
                return 0.0

        def setFreqHz(deps):
            def setHzValue(value):
                rawVal = int(round((1.0 / value) * 100000000))
                deps[0].set(rawVal)
            return setHzValue

        #############################################
        # Create block / variable combinations
        #############################################

        # Setup registers & variables
        self.add(pr.RemoteVariable(
            name='UsrRst',
            description='User Reset',
            offset=0x00000000,
            bitSize=1,
            bitOffset=0,
            base=pr.UInt,
            mode='RW',
            verify=False,
        ))

        self.add(pr.RemoteVariable(
            name='TrigEn',
            description='Global Trigger Enable',
            offset=0x00000400,
            bitSize=1,
            bitOffset=0,
            base=pr.Bool,
            mode='RW',
        ))

        self.add(pr.RemoteVariable(
            name='TrigSrcSel',
            description='Trigger Source Select',
            offset=0x00000404,
            bitSize=2,
            bitOffset=0,
            base=pr.UInt,
            mode='RW',
        ))

        self.add(pr.RemoteVariable(
            name='TrigPeriodRst',
            description='Reset Trigger Period Counters',
            offset=0x00000410,
            bitSize=1,
            bitOffset=0,
            base=pr.Bool,
            mode='RW',
            verify=False,
        ))

        self.add(pr.RemoteVariable(
            name='TrigPeriod',
            description='Current Trigger Period',
            offset=0x00000414,
            bitSize=32,
            bitOffset=0,
            base=pr.UInt,
            mode='RO',
        ))

        self.add(pr.RemoteVariable(
            name='TrigPeriodMin',
            description='Minimum Trigger Period',
            offset=0x00000418,
            bitSize=32,
            bitOffset=0,
            base=pr.UInt,
            mode='RO',
        ))

        self.add(pr.RemoteVariable(
            name='TrigPeriodMax',
            description='Maximum Trigger Period',
            offset=0x0000041C,
            bitSize=32,
            bitOffset=0,
            base=pr.UInt,
            mode='RO',
        ))

        self.add(pr.RemoteVariable(
            name='AutoTrigEn',
            description='Auto Trigger Enable',
            offset=0x00000408,
            bitSize=1,
            bitOffset=0,
            base=pr.Bool,
            mode='RW',
        ))

        self.add(pr.RemoteVariable(
            name='AutoTrigPer',
            description='Auto Trigger Period',
            offset=0x0000040C,
            bitSize=32,
            bitOffset=0,
            base=pr.UInt,
            mode='RW',
        ))

        self.add(pr.LinkVariable(
            name='AutoTrigPerMs',
            mode='RW',
            units='ms',
            linkedGet=getPerMs,
            linkedSet=setPerMs([self.AutoTrigPer]),
            disp='{:1.5f}',
            dependencies=[self.AutoTrigPer],
        ))

        self.add(pr.LinkVariable(
            name='AutoTrigFreqHz',
            mode='RW',
            units='Hz',
            linkedGet=getFreqHz,
            linkedSet=setFreqHz([self.AutoTrigPer]),
            disp='{:1.1f}',
            dependencies=[self.AutoTrigPer],
        ))

        self.add(pr.RemoteVariable(
            name='DcDcEnable',
            description='Enable Analog DCDC Regulators',
            offset=0x00000004,
            bitSize=4,
            bitOffset=0,
            base=pr.UInt,
            mode='RW',
        ))

        self.add(pr.RemoteVariable(
            name='AsicAnaEn',
            description='Enable ASIC Analog Voltage',
            offset=0x00000008,
            bitSize=1,
            bitOffset=0,
            base=pr.Bool,
            mode='RW',
        ))

        self.add(pr.RemoteVariable(
            name='AsicDigEn',
            description='Enable ASIC Digital Voltage',
            offset=0x0000000C,
            bitSize=1,
            bitOffset=0,
            base=pr.Bool,
            mode='RW',
        ))

        self.add(pr.RemoteVariable(
            name='AdcClkRst',
            description='Reset ADC Deserializers',
            offset=0x00000500,
            bitSize=10,
            bitOffset=0,
            base=pr.UInt,
            mode='RW',
            verify=False,
        ))

        self.add(pr.RemoteVariable(
            name='AdcReqStart',
            description='Request ADC Startup',
            offset=0x00000504,
            bitSize=1,
            bitOffset=0,
            base=pr.Bool,
            mode='RW',
        ))

        self.add(pr.RemoteVariable(
            name='AdcReqTest',
            description='Request ADC Test',
            offset=0x00000508,
            bitSize=1,
            bitOffset=0,
            base=pr.Bool,
            mode='RW',
        ))

        self.add(pr.RemoteVariable(
            name='AdcTestDone',
            description='ADC Test Done Flag',
            offset=0x0000050C,
            bitSize=1,
            bitOffset=0,
            base=pr.Bool,
            mode='RW',
        ))

        self.add(pr.RemoteVariable(
            name='AdcTestFailed',
            description='ADC Test Failed Flag',
            offset=0x00000510,
            bitSize=1,
            bitOffset=0,
            base=pr.Bool,
            mode='RW',
        ))

        for i in range(10):
            self.add(pr.RemoteVariable(
                name=('Adc[%d]ChannelFail' % i),
                description=('ADC[%d] Failed Channel Flags' % i),
                offset=(0x00000514 + i * 4),
                bitSize=32,
                bitOffset=0,
                base=pr.UInt,
                mode='RW',
            ))

        self.add(pr.RemoteVariable(
            name='AdcBypass',
            description='Bypass ADC Startup',
            offset=0x00000540,
            bitSize=1,
            bitOffset=0,
            base=pr.Bool,
            mode='RW',
        ))

        self.add(pr.RemoteVariable(
            name='DdrVttEn',
            description='Enable DDR VTT Voltage',
            offset=0x00000010,
            bitSize=1,
            bitOffset=0,
            base=pr.Bool,
            mode='RW',
        ))

        self.add(pr.RemoteVariable(
            name='DdrVttPok',
            description='DDR VTT Power OK',
            offset=0x00000014,
            bitSize=1,
            bitOffset=0,
            base=pr.Bool,
            mode='RO',
        ))

        self.add(pr.RemoteVariable(
            name='TempAlert',
            description='Temperature Alert',
            offset=0x00000018,
            bitSize=1,
            bitOffset=0,
            base=pr.Bool,
            mode='RO',
        ))

        self.add(pr.RemoteVariable(
            name='TempFault',
            description='Temperature Fault',
            offset=0x0000001C,
            bitSize=1,
            bitOffset=0,
            base=pr.Bool,
            mode='RO',
        ))

        self.add(pr.RemoteVariable(
            name='LatchTempFault',
            description='Latch Temperature Fault',
            offset=0x00000020,
            bitSize=1,
            bitOffset=0,
            base=pr.Bool,
            mode='RW',
        ))

        for i in range(4):
            self.add(pr.RemoteVariable(
                name=('CarrierIdLow[%d]' % i),
                description=('Carrier[%d] ID Lower Word' % i),
                offset=(0x00000030 + i * 8),
                bitSize=32,
                bitOffset=0,
                base=pr.UInt,
                mode='RO',
            ))
            self.add(pr.RemoteVariable(
                name=('CarrierIdHigh[%d]' % i),
                description=('Carrier[%d] ID Upper Word' % i),
                offset=(0x00000034 + i * 8),
                bitSize=32,
                bitOffset=0,
                base=pr.UInt,
                mode='RO',
            ))

        self.add(pr.RemoteVariable(
            name='CarrierIdRst',
            description='Reset Carrier ID Readout',
            offset=0x00000024,
            bitSize=1,
            bitOffset=0,
            base=pr.Bool,
            mode='RW',
            verify=False,
        ))

        self.add(pr.RemoteVariable(
            name='AsicMask',
            description='Asic Bit Mask. Set by Microblaze ASIC Auto-detect Function.',
            offset=0x00000028,
            bitSize=32,
            bitOffset=0,
            base=pr.UInt,
            mode='RW',
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
            return '{:.3f} kHz'.format(1 / (self.clkPeriod * self._count(var.dependencies)) * 1e-3)
        return func
