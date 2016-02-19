import pythonDaq
import time
import struct
import os
import sys
import getopt

def main(argv):
   pythonDaq.daqOpen("epix",1)

   pythonDaq.daqSetConfig("digFpga:syncWidth",str(15000))

   for delay in range(0,11000,10):
      pythonDaq.daqSetConfig("digFpga:syncDelay",str(delay))
      pythonDaq.daqSendCommand("SoftwareTrigger","")


if __name__ == "__main__":
   main(sys.argv[1:])
          


