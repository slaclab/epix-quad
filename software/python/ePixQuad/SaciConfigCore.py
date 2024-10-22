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
import os
import numpy as np
import json
import time as ti
import rogue.interfaces.memory as rim

try:
    from PyQt5.QtWidgets import *
    from PyQt5.QtCore import *
    from PyQt5.QtGui import *
except ImportError:
    from PyQt4.QtCore import *
    from PyQt4.QtGui import *


class SaciConfigCore(pr.Device):
    def __init__(self, simSpeedup=False, **kwargs):
        """Create SaciConfigCore"""
        super().__init__(description='Readout Core Regsisters', **kwargs)

        self.simSpeedup = simSpeedup

        # Creation. memBase is either the register bus server (srp, rce mapped memory, etc) or the device which
        # contains this object. In most cases the parent and memBase are the same but they can be
        # different in more complex bus structures. They will also be different for the top most node.
        # The setMemBase call can be used to update the memBase for this Device. All sub-devices and local
        # blocks will be updated.

        #############################################
        # Create block / variable combinations
        #############################################

        # Setup registers & variables

        self.add(pr.RemoteVariable(
            name='ConfWrReq',
            description='Request Config Write to ASICs',
            offset=0x00800000,
            bitSize=1,
            bitOffset=0,
            base=pr.Bool,
            mode='RW',
            verify=False,
        ))

        self.add(pr.RemoteVariable(
            name='ConfRdReq',
            description='Request Config Read from ASICs',
            offset=0x00800004,
            bitSize=1,
            bitOffset=0,
            base=pr.Bool,
            mode='RW',
            verify=False,
        ))

        self.add(pr.RemoteVariable(
            name='ConfSel',
            description='Select ASICs bit mask',
            offset=0x00800008,
            bitSize=16,
            bitOffset=0,
            base=pr.UInt,
            mode='RW',
        ))

        self.add(pr.RemoteVariable(
            name='ConfDoneAll',
            description='All ASICs configuration done',
            offset=0x0080000C,
            bitSize=1,
            bitOffset=0,
            base=pr.Bool,
            mode='RO',
        ))

        self.add(pr.RemoteVariable(
            name='ConfFail',
            description='ASIC failed bit mask',
            offset=0x00800010,
            bitSize=16,
            bitOffset=0,
            base=pr.UInt,
            mode='RO',
        ))

        for i in range(16):
            self.add(pr.RemoteVariable(
                name=('MaxFreqConfAsic[%d]' % i),
                description=('Most frequent configuration ASIC[%d]' % i),
                offset=0x00800020 + i * 4,
                bitSize=4,
                bitOffset=0,
                base=pr.UInt,
                mode='RO',
            ))

        #####################################
        # Create commands
        #####################################
        self.add(pr.Command(
            name='SetAsicsMatrix',
            description='Configure all ASICs matrix',
            function=self.setAsicsMatrix,
            value='',
        ))

        # A command has an associated function. The function can be a series of
        # python commands in a string. Function calls are executed in the command scope
        # the passed arg is available as 'arg'. Use 'dev' to get to device scope.
        # A command can also be a call to a local function with local scope.
        # The command object and the arg are passed

    # acelerated matrix configuration command
    def setAsicsMatrix(self, dev, cmd, arg):
        """SetAsicsMatrix command function"""

        print(f'setAsicsMatrix dev {dev} cmd {cmd} arg {arg[:16]}')

        # simulation only test
        if self.simSpeedup:
            # write memory
            for asic in range(0, 16):
                #memArray = [0x22222120, 0x22222222, 0x22242223, 0x22222222]
                memArray = [0x82888180, 0x88888888, 0x88848883, 0x88888888]
                self._setError(0)
#                self._rawTxnChunker(
#                    offset=(
#                        asic * 0x80000),
#                    data=memArray,
#                    base=pr.UInt,
#                    stride=4,
#                    wordBitSize=32,
#                    txnType=rim.Write,
#                    numWords=len(memArray))
                ldata = np.array(memArray,dtype=np.uint32).tobytes()
                self._reqTransaction( asic*0x80000, ldata, len(ldata), 0,
                                      rim.Write)
                self._waitTransaction(0)
            # request config write to ASICs and wait for completion
            self.ConfSel.set(0xffff)
            self.ConfWrReq.set(True)
            while self.ConfDoneAll.get() != True:
                ti.sleep(1)
            return

        shape = (16, 178, 192)
        if ',' in arg:
            arr = np.array(json.loads(arg), dtype=np.uint8)
            if np.shape(arr) == shape[3 - len(np.shape(arr)):]:
                matrixCfg = np.broadcast_to(arr, shape)
            else:
                print('Input array dimensions {} mismatch {}'.format(np.shape(arr), shape))
                return
        else:
            if len(arg) > 0:
                self.filename = arg
            else:
                self.filename = QFileDialog.getOpenFileName(
                    self.root.guiTop, 'Open File', '', 'csv file (*.csv);; Any (*.*)')[0]

            # write csv to memory
            if os.path.splitext(self.filename)[1] == '.csv':
                arr = np.genfromtxt(self.filename, delimiter=',')
                if np.shape(arr) == shape[3 - len(np.shape(arr)):]:
                    matrixCfg = np.broadcast_to(arr, shape)
                else:
                    print('Input array dimensions {} mismatch {}'.format(np.shape(arr), shape))
                    return

        print('Writing matrix element (0,0,0)={}'.format(matrixCfg[0][0][0]))

        for asic in range(0, 16):
            # writing to address zero resets statistics counters
            # must always start writing config data from adress zero
            memAddr = 0
            memArray = []
            for x in range(0, 177):
                for y in range(0, 192):
                    if memAddr % 8 == 0:
                        memData = 0
                    memData = memData | ((int(matrixCfg[asic][x][y]) & 0xF) << ((memAddr % 8) * 4))
                    if memAddr % 8 == 7:
                        #self._rawWrite((asic*0x80000)+int(memAddr/8)*4, memData)
                        memArray.append(memData)
                        #print('BRAM[0x%X] = 0x%X'%((asic*0x80000)+int(memAddr/8)*4, memData))

                    memAddr = memAddr + 1

            # make sure to send a big chunk of data avoiding slow 32 bit transactions
            # self._setError(0)
#            self._rawTxnChunker(
#                offset=(
#                    asic * 0x80000),
#                data=memArray,
#                base=pr.UInt,
#                stride=4,
#                wordBitSize=32,
#                txnType=rim.Write,
#                numWords=len(memArray))
            ldata = np.array(memArray,dtype=np.uint32).tobytes()
            self._reqTransaction( asic*0x80000, ldata, len(ldata), 0,
                                  rim.Write)
            self._waitTransaction(0)

        # request config write to ASICs and wait for completion
        self.ConfSel.set(0xffff)
        self.ConfWrReq.set(True)
        while self.ConfDoneAll.get() != True:
            ti.sleep(1)

    @staticmethod
    def frequencyConverter(self):
        def func(dev, var):
            return '{:.3f} kHz'.format(1 / (self.clkPeriod * self._count(var.dependencies)) * 1e-3)
        return func
