import pythonDaq
import time
import struct
import os
import sys
import getopt

def main(argv):
   pythonDaq.daqOpen("epix",1)
   
   #pythonDaq.daqSetConfig("digFpga:AutoRunEnable","True");

   for asic in range(0,4):
      
      asicStr = "digFpga(0):CpixPAsic("+str(asic)+")";
      
      pythonDaq.daqWriteRegister(asicStr,"PrepareMultiConfig",0x0)
      pythonDaq.daqWriteRegister(asicStr,"WriteMatrixData",0x1)
      
      #for i in range(0,48):
      #   pythonDaq.daqWriteRegister(asicStr,"PrepareMultiConfig",0x0)
      #   pythonDaq.daqWriteRegister(asicStr,"ColCounter",i)
      #   pythonDaq.daqWriteRegister(asicStr,"WriteColData",0x1)
      
      pythonDaq.daqWriteRegister(asicStr,"CmdPrepForRead",0x0)
      
      #pythonDaq.daqWriteRegister(asicStr,"PrepareMultiConfig",0x0)
      #pythonDaq.daqWriteRegister(asicStr,"RowCounter",10)
      #pythonDaq.daqWriteRegister(asicStr,"ColCounter",10)
      #print "%x" % (pythonDaq.daqReadRegister(asicStr,"WriteColData"))
   
if __name__ == "__main__":
   main(sys.argv[1:])
          
