import pythonDaq
import time
import struct
import os
import sys
import getopt

def main(argv):
   row  = 0
   col  = 0
   data = 0
   try:
      opts, args = getopt.getopt(argv,"hc:r:d:")
   except getopt.GetoptError:
      print 'LoadPixelMap -r <row> -c <col> -d <data>'
      sys.exit(2)
   for opt, arg in opts:
      if opt == '-h':
         print 'LoadPixelMap -r <row> -c <col> -d <data>'
         sys.exit()
      elif opt in ("-r", "--row"):
         row = int(arg)
      elif opt in ("-c", "--col"):
         col = int(arg)
      elif opt in ("-d", "--data"):
         data = int(arg)

   pythonDaq.daqOpen("epix",1)

   pythonDaq.daqSendCommand("PrepForRead","");
   pythonDaq.daqWriteRegister("digFpga(0):epix100aAsic(3)","PrepareMultiConfig",0x0)
   pythonDaq.daqWriteRegister("digFpga(0):epix100aAsic(3)","RowCounter",row)
   pythonDaq.daqWriteRegister("digFpga(0):epix100aAsic(3)","ColCounter",col)
   pythonDaq.daqWriteRegister("digFpga(0):epix100aAsic(3)","WritePixelData",data)

   print 'Sending prepare for readout'
   pythonDaq.daqSendCommand("PrepForRead","");

if __name__ == "__main__":
   main(sys.argv[1:])
          


