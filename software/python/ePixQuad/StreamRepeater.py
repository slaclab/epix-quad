#-----------------------------------------------------------------------------
# Title      : PyRogue base module - Data Receiver Device
#-----------------------------------------------------------------------------
# This file is part of the rogue software platform. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the rogue software platform, including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import rogue.interfaces.stream as ris
import pyrogue as pr
import time

class StreamRepeater(pr.Device,ris.Slave,ris.Master):
    def __init__(self,enableOnStart=True,**kwargs):

        pr.Device.__init__(self, **kwargs)
        ris.Slave.__init__(self)
        ris.Master.__init__(self)

        self._enableOnStart = enableOnStart

        self.add(pr.LocalVariable(
            name        = 'RxEnable',
            description = 'Frame Rx Enable',
            value       = True,
        ))

        self.add(pr.LocalVariable(
            name         = 'FrameCount',
            description  = 'Frame Rx Counter',
            value        = 0,
            pollInterval = 1,
        ))

        self.add(pr.LocalVariable(
            name         = 'ErrorCount',
            description  = 'Frame Error Counter',
            value        = 0,
            pollInterval = 1,
        ))

        self.add(pr.LocalVariable(
            name         = 'ByteCount',
            description  = 'Byte Rx Counter',
            value        = 0,
            pollInterval = 1,
        ))

    def countReset(self):
        self.FrameCount.set(0)
        self.ErrorCount.set(0)
        self.ByteCount.set(0)
        super().countReset()

    def _acceptFrame(self, frame):
        # Check for back pressuring condition
        while (self.RxEnable.value() is False):
            time.sleep(1.0)

        # Lock frame
        with frame.lock():

            # Drop errored frames
            if frame.getError() != 0:
                with self.ErrorCount.lock:
                    self.ErrorCount.set(self.ErrorCount.value() + 1, write=False)

                return

            with self.FrameCount.lock:
                self.FrameCount.set(self.FrameCount.value() + 1, write=False)

            with self.ByteCount.lock:
                self.ByteCount.set(self.ByteCount.value() + frame.getPayload(), write=False)

            # Repeat the data
            size = frame.getPayload()
            fullData = bytearray(size)
            frame.read(fullData,0)
            txFrame = self._reqFrame(size, True)
            txFrame.write(fullData,0)
            self._sendFrame(txFrame)

    def _start(self):
        super()._start()
        self.RxEnable.set(value=self._enableOnStart)

    def _stop(self):
        self.RxEnable.set(value=False)
        super()._stop()

    # source >> destination
    def __rshift__(self,other):
        pr.streamConnect(self,other)
        return other

    # destination << source
    def __lshift__(self,other):
        pr.streamConnect(other,self)
        return other
