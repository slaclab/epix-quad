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
      
      #enable test in all pixels with trim = 7
      pythonDaq.daqWriteRegister(asicStr,"PrepareMultiConfig",0x0)
      pythonDaq.daqWriteRegister(asicStr,"WriteMatrixData",0x1D)
      pythonDaq.daqWriteRegister(asicStr,"CmdPrepForRead",0x0)
      
      #pythonDaq.daqWriteRegister(asicStr,"PrepareMultiConfig",0x0)
      #pythonDaq.daqWriteRegister(asicStr,"RowCounter", 0)
      #pythonDaq.daqWriteRegister(asicStr,"WriteRowData",0x1D)
      #
      #pythonDaq.daqWriteRegister(asicStr,"PrepareMultiConfig",0x0)
      #pythonDaq.daqWriteRegister(asicStr,"ColCounter", 0)
      #pythonDaq.daqWriteRegister(asicStr,"WriteColData",0x1D)
      
      
      # disable test in every second row and column and keep trim =7
      for i in range(0,24):
         
         pythonDaq.daqWriteRegister(asicStr,"PrepareMultiConfig",0x0)
         pythonDaq.daqWriteRegister(asicStr,"RowCounter", i*2+1)
         pythonDaq.daqWriteRegister(asicStr,"WriteRowData",0x1C)
         
         pythonDaq.daqWriteRegister(asicStr,"PrepareMultiConfig",0x0)
         pythonDaq.daqWriteRegister(asicStr,"ColCounter", i*2+1)
         pythonDaq.daqWriteRegister(asicStr,"WriteColData",0x1C)
         
         print " %d " %(i*2+1)
      
      pythonDaq.daqWriteRegister(asicStr,"CmdPrepForRead",0x0)
   
if __name__ == "__main__":
   main(sys.argv[1:])
   