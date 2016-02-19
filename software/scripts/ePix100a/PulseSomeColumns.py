import pythonDaq
import time
import struct
import os
import sys
import getopt

def main(argv):
   pythonDaq.daqOpen("epix",1)

   for asic in range(0,4):
      for i in range(0,66):
         asicStr = "digFpga(0):epix100aAsic("+str(asic)+")";
         pythonDaq.daqWriteRegister(asicStr,"PrepareMultiConfig",0x0)
         pythonDaq.daqWriteRegister(asicStr,"ColCounter",i)
         pythonDaq.daqWriteRegister(asicStr,"WriteColData",0x1)
      pythonDaq.daqWriteRegister(asicStr,"CmdPrepForRead",0x0)
   

if __name__ == "__main__":
   main(sys.argv[1:])
          


