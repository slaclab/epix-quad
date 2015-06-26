import pythonDaq
import time
import struct
import os
import sys
import getopt

def main(argv):
   inputfile = ''
   try:
      opts, args = getopt.getopt(argv,"hi:")
   except getopt.GetoptError:
      print 'LoadPixelMap -i <input tab separated pixel map>'
      sys.exit(2)
   for opt, arg in opts:
      if opt == '-h':
         print 'LoadPixelMap -i <input tab separated pixel map>'
         sys.exit()
      elif opt in ("-i", "--ifile"):
         inputfile = arg

   pythonDaq.daqOpen("epix",1)

   print 'Loading pixel map from file: "', inputfile
   logo_in = open(inputfile,"r")
   lines = logo_in.readlines()
   if lines.__len__() != 352:
      print 'Input file only had ', lines.__len__() ,' lines'
      sys.exit(2)
   else:      
      pythonDaq.daqSendCommand("PrepForRead","");
      pythonDaq.daqWriteRegister("digFpga(0):epix100aAsic(3)","PrepareMultiConfig",0x0)
      for row in range(0,lines.__len__()):
         this_line = lines[row]
         this_line.rstrip()
         this_data = this_line.split();
         for col in range(0,this_data.__len__()):
            data = 0x0
            if this_data[col] == '1':
               data = 0x0
            else:
               data = 0x1
            bankToWrite = col/96;
            if (bankToWrite == 0):
               colToWrite = 0x700 + col%96;
            elif (bankToWrite == 1):
               colToWrite = 0x680 + col%96;
            elif (bankToWrite == 2):
               colToWrite = 0x580 + col%96;
            elif (bankToWrite == 3):
               colToWrite = 0x380 + col%96;
            else:
               print "ERROR"

            if (bankToWrite != 1):
               continue

            pythonDaq.daqWriteRegister("digFpga(0):epix100aAsic(3)","RowCounter",row)
            pythonDaq.daqWriteRegister("digFpga(0):epix100aAsic(3)","ColCounter",colToWrite)
            pythonDaq.daqWriteRegister("digFpga(0):epix100aAsic(3)","WritePixelData",data)

#   for i in range(0,96):
#      pythonDaq.daqWriteRegister("digFpga(0):epix100aAsic(3)","PrepareMultiConfig",0x0)
#      pythonDaq.daqWriteRegister("digFpga(0):epix100aAsic(3)","RowCounter",80)
            
   print 'Sending prepare for readout'
   pythonDaq.daqSendCommand("PrepForRead","");

if __name__ == "__main__":
   main(sys.argv[1:])
          


