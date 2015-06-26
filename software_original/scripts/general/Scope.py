import pythonDaq
import time
import struct
import os
import sys
import getopt
import time

def main(argv):

   pythonDaq.daqOpen("epix",1)

   pythonDaq.daqSetConfig("digFpga:ScopeEnable","1")           #1-bit
   pythonDaq.daqSetConfig("digFpga:ScopeTriggerEdge","1")      #1-bit
   pythonDaq.daqSetConfig("digFpga:ScopeTriggerChannel","0")   #4-bit
   pythonDaq.daqSetConfig("digFpga:ScopeTriggerMode","3")      #2-bit
   pythonDaq.daqSetConfig("digFpga:ScopeTriggerThreshold","0") #16-bit
   pythonDaq.daqSetConfig("digFpga:ScopeTriggerOffset","4000")  #13-bit
   pythonDaq.daqSetConfig("digFpga:ScopeTriggerHoldoff","0")   #13-bit
   pythonDaq.daqSetConfig("digFpga:ScopeTraceLength","8001")   #13-bit
   pythonDaq.daqSetConfig("digFpga:ScopeSkipSamples","0")      #13-bit
   pythonDaq.daqSetConfig("digFpga:ScopeInputChannelA","0")    #5-bit (0-19 available)
   pythonDaq.daqSetConfig("digFpga:ScopeInputChannelB","16")   #5-bit (0-19 available)

   #Arm the scope
   pythonDaq.daqSendCommand("digFpga:ScopeArm","");
   #Trigger the scope
   pythonDaq.daqSendCommand("digFpga:ScopeTrig","");


if __name__ == "__main__":
   main(sys.argv[1:])
          


