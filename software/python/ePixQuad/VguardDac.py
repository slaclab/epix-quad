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


class VguardDac(pr.Device):
    def __init__(self, **kwargs):
        """Create VguardDac"""
        super().__init__(description='Vguard DAC Regsisters', **kwargs)

        def getDacVolt(var):
            x = var.dependencies[0].value()
            return x / 65535.0 * 2.5 * (1 + 845.0 / 3000)

        def setDacVolt(deps):
            def setDacValue(value):
                rawVal = int(round(value * 65535.0 / (2.5 * (1 + 845.0 / 3000))))
                deps[0].set(rawVal)
            return setDacValue

        # Creation. memBase is either the register bus server (srp, rce mapped memory, etc) or the device which
        # contains this object. In most cases the parent and memBase are the same but they can be
        # different in more complex bus structures. They will also be different for the top most node.
        # The setMemBase call can be used to update the memBase for this Device. All sub-devices and local
        # blocks will be updated.

        #############################################
        # Create block / variable combinations
        #############################################

        self.add(pr.RemoteVariable(
            name='VguardDacRaw',
            description='Write DAC Register',
            offset=0x000000C0,
            bitSize=16,
            bitOffset=0,
            base=pr.UInt,
            mode='RW',
        ))

        self.add(pr.LinkVariable(
            name='VguardDacVolt',
            mode='RW',
            units='V',
            linkedGet=getDacVolt,
            linkedSet=setDacVolt([self.VguardDacRaw]),
            disp='{:1.5f}',
            dependencies=[self.VguardDacRaw],
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
