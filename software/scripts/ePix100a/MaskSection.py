import pythonDaq
import time
import struct
import os
import sys
import getopt

def main(argv):
   pythonDaq.daqOpen("epix",1)

   for asic in range(0,4):
      asicStr = "digFpga(0):epix100aAsic("+str(asic)+")"
      for row in range(0,1):
         for col in range(0,96):
            pythonDaq.daqWriteRegister(asicStr,"PrepareMultiConfig",0x0)
            pythonDaq.daqWriteRegister(asicStr,"RowCounter",row)
            pythonDaq.daqWriteRegister(asicStr,"ColCounter",col)
            pythonDaq.daqWriteRegister(asicStr,"WritePixelData",0x2)
#      for row in range(320,330):
#         for col in range(70,80):
#            pythonDaq.daqWriteRegister(asicStr,"PrepareMultiConfig",0x0)
#            pythonDaq.daqWriteRegister(asicStr,"RowCounter",row)
#            pythonDaq.daqWriteRegister(asicStr,"ColCounter",col)
#            pythonDaq.daqWriteRegister(asicStr,"WritePixelData",0x1)
      pythonDaq.daqWriteRegister(asicStr,"CmdPrepForRead",0x0)
   
#   regOut = pythonDaq.daqReadRegister(asicStr,"ColStartAddr")
#   print "Register returned: " + str(regOut)

if __name__ == "__main__":
   main(sys.argv[1:])
          


