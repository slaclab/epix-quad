#!/usr/bin/env python3
#-----------------------------------------------------------------------------
# This file is part of the rogue_example software. It is subject to 
# the license terms in the LICENSE.txt file found in the top-level directory 
# of this distribution and at: 
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
# No part of the rogue_example software, including this file, may be 
# copied, modified, propagated, or distributed except according to the terms 
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------


import sys
import rogue.utilities
import rogue.utilities.fileio
import rogue.interfaces.stream
import pyrogue    
import time

class EventReader(rogue.interfaces.stream.Slave):

    

    def __init__(self):
        rogue.interfaces.stream.Slave.__init__(self)
        self.enable = True
        self.numAcceptedFrames = 0
        self.lastFrame = rogue.interfaces.stream.Frame
	

    def _acceptFrame(self,frame):
        self.lastFrame = frame
        if self.enable:
            self.numAcceptedFrames += 1
            # Get the channel number
            chNum = (frame.getFlags() >> 24)
            print('-------- Frame ',self.numAcceptedFrames,'Channel',frame.getFlags() , ' Accepeted --------' , chNum)
            # Check if channel number is 0x1 (streaming data channel)
            if (chNum == 0x0) :
                print('-------- Event --------')
                # Collect the data
                p = bytearray(frame.getPayload())
                frame.read(p,0)
                cnt = 0
                while (cnt < len(p)):
                    value = 0
                    for x in range(0,4):
                        if (cnt < len(p)): 
                            value += (p[cnt] << (x*8))
                        cnt += 1
                    #print ('data[%d]: 0x%.8x' % ( (cnt/4), value ))
                print ('frame[%d]: %d' % ( (self.numAcceptedFrames), cnt ))        
                    
def main(arg):                
                
    # Create the objects            
    fileReader  = rogue.utilities.fileio.StreamReader()
    eventReader = EventReader()

    # Connect the fileReader to our event processor
    pyrogue.streamConnect(fileReader,eventReader)

    # Open the data file
    print('-------- Openning file --------')
    fileReader.open(arg)
    
    time.sleep(1)
    
if __name__ == '__main__':
    main(sys.argv[1])    
    


