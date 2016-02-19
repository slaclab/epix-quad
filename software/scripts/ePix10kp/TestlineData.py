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

def EdgeSetting(trueFalseString):
   if (trueFalseString == "True"):
      return "rising"
   else:
      return "falling"


def main(argv):
   inputfile = ''
   try:
      opts, args = getopt.getopt(argv,"ho:")
   except getopt.GetoptError:
      print 'Please provide:  -o <output file base name>'
      sys.exit(2)
   for opt, arg in opts:
      if opt == '-h':
         print 'Please provide:  -o <output file base name>'
         sys.exit()
      elif opt in ("-o", "--ofile"):
         outputfile = arg

   pythonDaq.daqOpen("epix",1)

   r0ToAcq =  [1250, 7000]
   acqWidth = [7000, 7000]

   framesPerSetting = 1000
   logData = "True"

   for r0Settings in range(0,2):
      thisR0toAcq  = r0ToAcq[r0Settings]
      thisAcqWidth = acqWidth[r0Settings]
      pythonDaq.daqSetConfig("digFpga:asicR0ToAsicAcq",str(thisR0toAcq))
      pythonDaq.daqSetConfig("digFpga:asicAcqWidth",str(thisAcqWidth))

      for thisG in ("True","False"):
         for thisGA in ("True","False"):
            WriteMatrix(pythonDaq,"False","False",thisG,thisGA)

            for TpsMux in ("fo","abus"):
               edgeSetting = "True"
               if (TpsMux == "fo"):
                  edgeSetting = "True"
               if (TpsMux == "abus"):
                  edgeSetting = "False"

               pythonDaq.daqSetConfig("digFpga:tpsEdge",edgeSetting)
               pythonDaq.daqSetConfig("digFpga:epix10kpAsic:TpsMux",TpsMux)

               filename = outputfile+"_g"+Setting(thisG)+"_ga"+Setting(thisGA)+"_r0toAcq"+str(thisR0toAcq/125)+"us_acq"+str(thisAcqWidth/125)+"us_tpsOnAcq"+EdgeSetting(edgeSetting)+"_"+TpsMux+".bin"
               print(filename)
               Trigger(pythonDaq,framesPerSetting,logData,filename)

if __name__ == "__main__":
   main(sys.argv[1:])
          

