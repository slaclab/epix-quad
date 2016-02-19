import pythonDaq
import time
import struct
import os
import sys
import getopt

def main(argv):
   pythonDaq.daqOpen("epix",1)

#   pythonDaq.daqWriteRegister("digFpga(0):epix100aAsic(3)","PrepareMultiConfig",0x0)
#   pythonDaq.daqWriteRegister("digFpga(0):epix100aAsic(3)","ColCounter",0x680 + 80)
#   pythonDaq.daqWriteRegister("digFpga(0):epix100aAsic(3)","WriteColData",0x1)
#   pythonDaq.daqWriteRegister("digFpga(0):epix100aAsic(3)","CmdPrepForRead",0x0)

   pythonDaq.daqWriteRegister("digFpga(0):epix100aAsic(3)","PrepareMultiConfig",0x0)
   for i in range(0,352):
      pythonDaq.daqWriteRegister("digFpga(0):epix100aAsic(3)","RowCounter",i)
      pythonDaq.daqWriteRegister("digFpga(0):epix100aAsic(3)","ColCounter",0x680 + 23)
      pythonDaq.daqWriteRegister("digFpga(0):epix100aAsic(3)","WritePixelData",0x1)
   pythonDaq.daqWriteRegister("digFpga(0):epix100aAsic(3)","CmdPrepForRead",0x0)
   

if __name__ == "__main__":
   main(sys.argv[1:])
          


