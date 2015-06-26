import pythonDaq
import time
import struct
import os
import sys
import getopt

def main(argv):
   pythonDaq.daqOpen("epix",1)

#   for i in range(0,96):
#      pythonDaq.daqWriteRegister("digFpga(0):epix100aAsic(2)","PrepareMultiConfig",0x0)
#      pythonDaq.daqWriteRegister("digFpga(0):epix100aAsic(2)","ColCounter",i)
#      pythonDaq.daqWriteRegister("digFpga(0):epix100aAsic(2)","WriteColData",0x0)

   pythonDaq.daqWriteRegister("digFpga(0):epix100aAsic(2)","PrepareMultiConfig",0x0)
   pythonDaq.daqWriteRegister("digFpga(0):epix100aAsic(2)","ColCounter",23)
   pythonDaq.daqWriteRegister("digFpga(0):epix100aAsic(2)","WriteColData",0x1)

#   for i in range(0,96):
#      pythonDaq.daqWriteRegister("digFpga(0):epix100aAsic(2)","PrepareMultiConfig",0x0)
#      pythonDaq.daqWriteRegister("digFpga(0):epix100aAsic(2)","RowCounter",80)
#      pythonDaq.daqWriteRegister("digFpga(0):epix100aAsic(2)","ColCounter",i)
#      pythonDaq.daqWriteRegister("digFpga(0):epix100aAsic(2)","WritePixelData",0x1)
   
#   regOut = pythonDaq.daqReadRegister("digFpga(0):epix100aAsic(3)","ColStartAddr")
#   print "Register returned: " + str(regOut)

if __name__ == "__main__":
   main(sys.argv[1:])
          


