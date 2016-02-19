import pythonDaq
import time
import struct
import os
import sys
import getopt

def main(argv):
   pythonDaq.daqOpen("epix",1)

   baseRow = 5 
   baseCol = 15

   for row in [-1,0,1]:
      for col in [-1,0,1]:
         thisRow = baseRow + row
         thisCol = baseCol + col
         pythonDaq.daqWriteRegister("digFpga(0):epix100aAsic(3)","PrepareMultiConfig",0x0)
         pythonDaq.daqWriteRegister("digFpga(0):epix100aAsic(3)","RowCounter",thisRow)
         pythonDaq.daqWriteRegister("digFpga(0):epix100aAsic(3)","ColCounter",thisCol)
         pythonDaq.daqWriteRegister("digFpga(0):epix100aAsic(3)","WritePixelData",0x0)
   pythonDaq.daqWriteRegister("digFpga(0):epix100aAsic(3)","CmdPrepForRead",0x0)
   
#   regOut = pythonDaq.daqReadRegister("digFpga(0):epix100aAsic(3)","ColStartAddr")
#   print "Register returned: " + str(regOut)

if __name__ == "__main__":
   main(sys.argv[1:])
          


