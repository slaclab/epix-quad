import pythonDaq
import time
import struct
import os
import sys
import getopt

def main(argv):
   pythonDaq.daqOpen("epix",1)

   for i in range(0,51,2):
      pythonDaq.daqSetConfig("digFpga:epix100aAsic:FilterDac",str(i))
      pythonDaq.daqSendCommand("SoftwareTrigger","")

if __name__ == "__main__":
   main(sys.argv[1:])
          


