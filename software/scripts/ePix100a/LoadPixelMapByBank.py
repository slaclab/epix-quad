import pythonDaq
import time
import struct
import os
import sys
import getopt

def main(argv):
   inputfile = ''
   position = 0
   try:
      opts, args = getopt.getopt(argv,"hi:p:")
   except getopt.GetoptError:
      print 'LoadPixelMap -i <input tab separated pixel map> -p <asic position>'
      sys.exit(2)
   for opt, arg in opts:
      if opt == '-h':
         print 'LoadPixelMap -i <input tab separated pixel map> -p <asic position>'
         sys.exit()
      elif opt in ("-i", "--ifile"):
         inputfile = arg
      elif opt in ("-p", "--position"):
         position = arg

   pythonDaq.daqOpen("epix",1)

   print 'Loading pixel map from file: "', inputfile
   print 'Asic position: "', position
   logo_in = open(inputfile,"r")
   lines = logo_in.readlines()
   if lines.__len__() != 352:
      print 'Input file only had ', lines.__len__() ,' lines'
      sys.exit(2)
   else: 
      asicStr = "digFpga(0):epix100aAsic("+str(position)+")"
      pythonDaq.daqSendCommand("PrepForRead","");
      pythonDaq.daqWriteRegister(asicStr,"PrepareMultiConfig",0x0)
      for row in range(0,lines.__len__()):
         this_line = lines[row]
         this_line.rstrip()
         this_data = this_line.split();
#         pythonDaq.daqWriteRegister(asicStr,"RowCounter",row)  #Works here
         for col in range(0,96):
            pythonDaq.daqWriteRegister(asicStr,"RowCounter",row)  #Does it work here too?
            if this_data[0*96+col] == '1' or this_data[1*96+col] == '1' or this_data[2*96+col] == '1' or this_data[3*96+col] == '1':
               for bankToWrite in range(0,4):
                  data = 0x0
                  if this_data[bankToWrite*96+col] == '1':
                     data = 0x0
                  else:
                     data = 0x1
   
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

                  pythonDaq.daqWriteRegister(asicStr,"ColCounter",colToWrite)
                  pythonDaq.daqWriteRegister(asicStr,"WritePixelData",data)

   print 'Sending prepare for readout'
   pythonDaq.daqSendCommand("PrepForRead","");

if __name__ == "__main__":
   main(sys.argv[1:])
          


