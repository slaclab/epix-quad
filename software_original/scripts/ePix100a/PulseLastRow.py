import pythonDaq
import time
import struct
import os
import sys
import getopt

def main(argv):
   pythonDaq.daqOpen("epix",1)

   pythonDaq.daqWriteRegister("digFpga(0):epix100aAsic(3)","PrepareMultiConfig",0x0)
   for row in [352]:
      for col in range(0,96):
         pythonDaq.daqWriteRegister("digFpga(0):epix100aAsic(3)","RowCounter",row)
         pythonDaq.daqWriteRegister("digFpga(0):epix100aAsic(3)","ColCounter",col)
         pythonDaq.daqWriteRegister("digFpga(0):epix100aAsic(3)","WritePixelData",0x1)
   pythonDaq.daqWriteRegister("digFpga(0):epix100aAsic(3)","CmdPrepForRead",0x0)

if __name__ == "__main__":
   main(sys.argv[1:])
          


