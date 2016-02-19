import pythonDaq
import time
import struct
import os
import sys
import getopt
import math

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

def WriteRow(pythonDaq, row, test, mask, G, GA):
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:RowCounter",str(row))
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:PixelTest",test)
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:PixelMask",mask)
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:PixelG",G)
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:PixelGA",GA)
   pythonDaq.daqSendCommand("WriteRowData","")
   pythonDaq.daqSendCommand("PrepForRead","")

def WriteCol(pythonDaq, col, test, mask, G, GA):
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:ColCounter",str(col))
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:PixelTest",test)
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:PixelMask",mask)
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:PixelG",G)
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:PixelGA",GA)
   pythonDaq.daqSendCommand("WriteColData","")
   pythonDaq.daqSendCommand("PrepForRead","")


def main(argv):
   outputfile = ''
   try:
      opts, args = getopt.getopt(argv,"ho:")
   except getopt.GetoptError:
      print '<script_name> -o <base filename for output>'
      sys.exit(2)
   for opt, arg in opts:
      if opt == '-h':
         print '<script_name> -o <base filename for output>'
         sys.exit()
      elif opt in ("-o", "--ofile"):
         outputfile = arg

   pythonDaq.daqOpen("epix",1)

   #Turn on pulser in autoscan mode
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:Test","True")
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:ATest","True")

   for defaultG in ("True","False"):
      for defaultGA in ("True","False"):

         #Only collect autoranging mode
         if (defaultG != "False" or defaultGA != "False"):
            continue;

         defaultTest = "False"
         defaultMask = "False"
         pixelTest = "True"
         pixelMask = "False"
         pixelG    = defaultG
         pixelGA   = defaultGA

         acqWidth    = 32500
         acqWidthStr = str(int(math.floor(acqWidth/125)))+"us"

         r0toAcq     = 3125

         Preamp      =  5
         FilterDac   =  8
         Vref        = 47
         Vld1_b      =  3
         S2dDac      = 22
         S2dGr       =  3
         CompTH_DAC  = 27
         CompEnOn    = "True"
         CompEn      = 0

         pythonDaq.daqSetConfig("digFpga:asicAcqWidth",str(acqWidth))
         pythonDaq.daqSetConfig("digFpga:epix10kpAsic:Preamp",str(Preamp))
         pythonDaq.daqSetConfig("digFpga:epix10kpAsic:FilterDac",str(FilterDac))
         pythonDaq.daqSetConfig("digFpga:epix10kpAsic:Vref",str(Vref))
         pythonDaq.daqSetConfig("digFpga:epix10kpAsic:Vld1_b",str(Vld1_b))
         pythonDaq.daqSetConfig("digFpga:epix10kpAsic:S2dDac",str(S2dDac))
         pythonDaq.daqSetConfig("digFpga:epix10kpAsic:S2dGr",str(S2dGr))
         pythonDaq.daqSetConfig("digFpga:epix10kpAsic:CompTH_DAC",str(CompTH_DAC))
         pythonDaq.daqSetConfig("digFpga:epix10kpAsic:CompEnOn",CompEnOn)
         pythonDaq.daqSetConfig("digFpga:epix10kpAsic:CompEn",str(CompEn))

         mode = "_undefined_"         

         for highResSetting in ("True","False"):
            #For high gain mode
            if (pixelG == "True" and pixelGA == "True"):
               mode = "_HG_"
               r0toAcq     = 7000
               if (highResSetting == "False"):
                  continue;
            #For low gain mode
            if (pixelG == "False" and pixelGA == "True"):
               mode = "_LG_"
               r0toAcq     = 7000
            #For forced switching mode
            if (pixelG == "True" and pixelGA == "False"):
               mode = "_FS_"
               r0toAcq     = 3125
            #For autoranging mode, do only high resolution
            if (pixelG == "False" and pixelGA == "False"):
               mode = "_AR_"
               r0toAcq     = 3125
               if (highResSetting == "False"):
                  continue;
            r0toAcqStr  = str(int(r0toAcq/125))+"us"

            #Set pulser resolution
            pythonDaq.daqSetConfig("digFpga:epix10kpAsic:HrTest",highResSetting)
            #Set distance from R0 to ACQ 
            pythonDaq.daqSetConfig("digFpga:asicR0ToAsicAcq",str(r0toAcq))

            for baseRow in range(0,6):
               #Reset the count before taking the next dataset
               pythonDaq.daqSetConfig("digFpga:epix10kpAsic:PulserR","True")
               pythonDaq.daqSetConfig("digFpga:epix10kpAsic:PulserR","False")
               WriteMatrix(pythonDaq, defaultTest, defaultMask, defaultG, defaultGA)
               for nrow in range(0,8):
                  thisRow = (baseRow%6)*8 + nrow
                  if (thisRow == 0):
                     WriteRow(pythonDaq,thisRow,"False","True",pixelG,pixelGA)
                  else:
                     WriteRow(pythonDaq,thisRow,pixelTest,pixelMask,pixelG,pixelGA)
               resSetting = "lr"
               if (highResSetting == "True"):
                  resSetting = "hr"
               this_filename = outputfile+mode+"acq"+acqWidthStr+"_r0toAcq"+r0toAcqStr+"_r"+str(baseRow)+"_"+resSetting+"_pulserscan.bin"
               print(this_filename)
               pythonDaq.daqOpenData(this_filename)
               for event in range(0,1024*5):
                  pythonDaq.daqSendCommand("SoftwareTrigger","")
                  time.sleep(0.025) 

#               pythonDaq.daqSetRunParameters("100Hz",1024*6)
#               pythonDaq.daqSetRunState("Running")
#               while(pythonDaq.daqGetStatus("Run State") == "Running"):
#                  time.sleep(0.5) 
#               time.sleep(80)

               pythonDaq.daqCloseData(this_filename)

#               time.sleep(10)

if __name__ == "__main__":
   main(sys.argv[1:])
          


