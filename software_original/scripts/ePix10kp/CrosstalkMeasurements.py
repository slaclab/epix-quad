import pythonDaq
import time
import struct
import os
import sys
import getopt

def WriteMatrix(pythonDaq, test, mask, G, GA):
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:PixelTest",test)
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:PixelMask",mask)
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:PixelG",G)
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:PixelGA",GA)
   pythonDaq.daqSendCommand("WriteMatrixData","")

def WritePixel(pythonDaq, row, col, test, mask, G, GA):
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:RowCounter",str(row))
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:ColCounter",str(col))
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:PixelTest",test)
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:PixelMask",mask)
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:PixelG",G)
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:PixelGA",GA)
   pythonDaq.daqSendCommand("WritePixelData","")
   pythonDaq.daqSendCommand("PrepForRead","")

def Trigger(pythonDaq,nTriggers,logData,filename):
   if (logData == "True"):
      pythonDaq.daqOpenData(filename)

   for frame in range(0,nTriggers):
      pythonDaq.daqSendCommand("SoftwareTrigger","")

   if (logData == "False"):
      pythonDaq.daqCloseData(filename)

def Setting(trueFalseString):
   if (trueFalseString == "True"):
      return str(1)
   else:
      return str(0)

def HrSetting(trueFalseString):
   if (trueFalseString == "True"):
      return "hr"
   else:
      return "lr"


def main(argv):
   inputfile = ''
   try:
      opts, args = getopt.getopt(argv,"hi:o:")
   except getopt.GetoptError:
      print 'Please provide:  -i <input tab separated pixel map> -o <output file base name>'
      sys.exit(2)
   for opt, arg in opts:
      if opt == '-h':
         print 'Please provide:  -i <input tab separated pixel map> -o <output file base name>'
         sys.exit()
      elif opt in ("-i", "--ifile"):
         inputfile = arg
      elif opt in ("-o", "--ofile"):
         outputfile = arg

   pythonDaq.daqOpen("epix",1)


   pixelG  = ["True", "False", "False"]
   pixelGA = ["True", "True", "False"]
   pulserSettings = [325, 1023, 1023]
   hrSettings = ["True", "False", "False"]

   framesPerSetting = 1000
   logData = "True"

   for i in range(0,3):
      thisPixelG  = pixelG[i]
      thisPixelGA = pixelGA[i]
      thisHrSetting = hrSettings[i]
      thisPulserSetting = pulserSettings[i]

      #Dark frames first - take 3
      # 1. Standard dark frame (test = 0, pixelTest = 0)
      # 2. Dark frame with (test = 1, pixelTest = 0, pulser = 0)
      # 3. Dark frame with (test = 1, pixelTest = 0, pulser = set value at measurement gain)
      WriteMatrix(pythonDaq,"False","False",thisPixelG,thisPixelGA)
            
      # 1. Standard dark frame (test = 0, pixelTest = 0)
      pythonDaq.daqSetConfig("digFpga:epix10kpAsic:Test","False")
      filename = outputfile+"_g"+Setting(thisPixelG)+"_ga"+Setting(thisPixelGA)+"_dark_test0.bin"
      print(filename)
      Trigger(pythonDaq,framesPerSetting,logData,filename)

      # 2. Dark frame with (test = 1, pixelTest = 0, pulser = 0)
      pythonDaq.daqSetConfig("digFpga:epix10kpAsic:Test","True")
      pythonDaq.daqSetConfig("digFpga:epix10kpAsic:HrTest","True")
      pythonDaq.daqSetConfig("digFpga:epix10kpAsic:Pulser",str(0))
      filename = outputfile+"_g"+Setting(thisPixelG)+"_ga"+Setting(thisPixelGA)+"_dark_test1_hr_pulser0"+".bin"
      print(filename)
      Trigger(pythonDaq,framesPerSetting,logData,filename)

      # 3. Dark frame with (test = 1, pixelTest = 0, pulser = nominal)
      pythonDaq.daqSetConfig("digFpga:epix10kpAsic:Test","True")
      pythonDaq.daqSetConfig("digFpga:epix10kpAsic:HrTest",thisHrSetting)
      pythonDaq.daqSetConfig("digFpga:epix10kpAsic:Pulser",str(thisPulserSetting))
      filename = outputfile+"_g"+Setting(thisPixelG)+"_ga"+Setting(thisPixelGA)+"_dark_test1_"+HrSetting(thisHrSetting)+"_pulser"+str(thisPulserSetting)+".bin"
      print(filename)
      Trigger(pythonDaq,framesPerSetting,logData,filename)

      # Next load up the pixel map for the crosstalk measurement
      logo_in = open(inputfile,"r")
      lines = logo_in.readlines()
      if lines.__len__() != 48:
         print 'Input file only had ', lines.__len__() ,' lines'
         sys.exit(2)
      else:      
         pythonDaq.daqSendCommand("PrepForRead","");
         for row in range(0,lines.__len__()):
            this_line = lines[row]
            this_line.rstrip()
            this_data = this_line.split();
            pythonDaq.daqSetConfig("digFpga:epix10kpAsic:RowCounter",str(row))
            pythonDaq.daqSendCommand("WriteRowCounter","");
            for col in range(0,this_data.__len__()):
               if this_data[col] == '1':
                  WritePixel(pythonDaq,str(row),str(col),"True","False",thisPixelG,thisPixelGA)
         pythonDaq.daqSendCommand("PrepForRead","");
      logo_in.close()

      #And take the crosstalk data
      pythonDaq.daqSetConfig("digFpga:epix10kpAsic:Test","True")
      pythonDaq.daqSetConfig("digFpga:epix10kpAsic:HrTest",thisHrSetting)
      pythonDaq.daqSetConfig("digFpga:epix10kpAsic:Pulser",str(thisPulserSetting))
      filename = outputfile+"_g"+Setting(thisPixelG)+"_ga"+Setting(thisPixelGA)+"_pulsed_test1_"+HrSetting(thisHrSetting)+"_pulser"+str(thisPulserSetting)+".bin"
      print(filename)
      Trigger(pythonDaq,framesPerSetting,logData,filename)
            

if __name__ == "__main__":
   main(sys.argv[1:])
          

