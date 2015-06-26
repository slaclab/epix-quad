import pythonDaq
import time
import struct
import os
import sys
import getopt

def main(argv):

   pythonDaq.daqOpen("epix",1)

   pythonDaq.daqSetConfig("digFpga:asicR0ToAsicAcq",str(10000))
   pythonDaq.daqSetConfig("digFpga:asicAcqWidth",str(10000))
   for width in range(1,1000,3):
      #pythonDaq.daqSetConfig("digFpga:asicR0ToAsicAcq",str(width))
      #pythonDaq.daqSetConfig("digFpga:asicAcqWidth",str(width))
      pythonDaq.daqSetConfig("digFpga:asicR0Width",str(width))
      for events in range(0,10):
         pythonDaq.daqSendCommand("SoftwareTrigger","")
         time.sleep(0.01)

if __name__ == "__main__":
   main(sys.argv[1:])
          


