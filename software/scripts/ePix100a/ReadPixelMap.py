import pythonDaq
import time
import struct
import os
import sys
import getopt

def main(argv):
   inputfile = ''
   try:
      opts, args = getopt.getopt(argv,"ho:")
   except getopt.GetoptError:
      print 'ReadPixelMap -o <output pixel map>'
      sys.exit(2)
   for opt, arg in opts:
      if opt == '-h':
         print 'ReadPixelMap -i <output pixel map>'
         sys.exit()
      elif opt in ("-o", "--ofile"):
         outputfile = arg

   pythonDaq.daqOpen("epix",1)

   print 'Writing output bits to: "', outputfile
   file_out = open(outputfile,"w")
   pythonDaq.daqSendCommand("PrepForRead","");
   pythonDaq.daqWriteRegister("digFpga(0):epix100aAsic(3)","PrepareMultiConfig",0x0)
   for row in range(0,352):
      for col in range(0,96*4):
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

         pythonDaq.daqWriteRegister("digFpga(0):epix100aAsic(3)","RowCounter",row)
         pythonDaq.daqWriteRegister("digFpga(0):epix100aAsic(3)","ColCounter",colToWrite)
         dataRead = pythonDaq.daqReadRegister("digFpga(0):epix100aAsic(3)","WritePixelData")
         file_out.write(str(dataRead)+"\t")
      file_out.write("\n")

   print 'Sending prepare for readout'
   pythonDaq.daqSendCommand("PrepForRead","");

if __name__ == "__main__":
   main(sys.argv[1:])
          


