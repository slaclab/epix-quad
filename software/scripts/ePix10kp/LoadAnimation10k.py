import pythonDaq
import time
import struct
import os
import sys
import getopt
import time

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

   pythonDaq.daqOpen("epix",1)

   while(1):
      defaultTest = "False"
      defaultMask = "False"
      defaultG    = "False"
      defaultGA   = "False"

      WriteMatrix(pythonDaq, defaultTest, defaultMask, defaultG, defaultGA)
   
      pixelTest = "True"
      pixelMask = "False"
      pixelG    = "False"
      pixelGA   = "False"

      curRow = 47;
      curCol = 24;
      curPulser = 0;

      #Turn on pulser in high resolution mode
      pythonDaq.daqSetConfig("digFpga:epix10kpAsic:Test","True")
      pythonDaq.daqSetConfig("digFpga:epix10kpAsic:HrTest","True")
      pythonDaq.daqSetConfig("digFpga:epix10kpAsic:ATest","False")

      while (curRow > 23):
         pythonDaq.daqSetConfig("digFpga:epix10kpAsic:Pulser",str(curPulser))
         #First clear the matrix
         WriteMatrix(pythonDaq, defaultTest, defaultMask, defaultG, defaultGA)
         #Write individual pixel
         WritePixel(pythonDaq,curRow,curCol,pixelTest,pixelMask,pixelG,pixelGA);
         #Take a frame
         pythonDaq.daqSendCommand("SoftwareTrigger","")
         #increment row
         curRow -= 1
         #increment pulser
         curPulser += 2
         #pause for a moment so the ami can keep up
         time.sleep(0.1)
   
      midRow = curRow
      midCol = curCol
   
      #Clear the matrix before the next part
      WriteMatrix(pythonDaq, defaultTest, defaultMask, defaultG, defaultGA)
      pythonDaq.daqSetConfig("digFpga:epix10kpAsic:HrTest","False")
      #Starburst out in 4 directions
      for n in range(1,24):
         pythonDaq.daqSetConfig("digFpga:epix10kpAsic:Pulser",str(curPulser))
         midTest = "False"
         midMask = "True"
         midG    = "False"
         midGA   = "True"
         WritePixel(pythonDaq,curRow,curCol,midTest,midMask,midG,midGA)
         outTest = "True"
         outMask = "False"
         outG    = "False"
         outGA   = "False"
         WritePixel(pythonDaq,midRow+n,midCol+n,outTest,outMask,outG,outGA)
         WritePixel(pythonDaq,midRow-n,midCol-n,outTest,outMask,outG,outGA)
         WritePixel(pythonDaq,midRow+n,midCol-n,outTest,outMask,outG,outGA)
         WritePixel(pythonDaq,midRow-n,midCol+n,outTest,outMask,outG,outGA)
         #Take a frame
         pythonDaq.daqSendCommand("SoftwareTrigger","")
         #Increment pulser
         curPulser += 30
         #Pause 
         #time.sleep(0.2)

      #Step through rows one at a time
      curRow = 0
      pythonDaq.daqSetConfig("digFpga:epix10kpAsic:HrTest","True")
      pythonDaq.daqSetConfig("digFpga:epix10kpAsic:ATest","True")
      pythonDaq.daqSetConfig("digFpga:epix10kpAsic:Test","True")
      pythonDaq.daqSetConfig("digFpga:epix10kpAsic:PulserR","True")
      pythonDaq.daqSetConfig("digFpga:epix10kpAsic:PulserR","False")
      while(curRow < 48):
         WriteMatrix(pythonDaq, defaultTest, defaultMask, defaultG, defaultGA)
         WriteRow(pythonDaq,curRow,"True",defaultMask,defaultG,defaultGA)
         WriteCol(pythonDaq,curRow,"True",defaultMask,defaultG,defaultGA)
         pythonDaq.daqSendCommand("SoftwareTrigger","")
         curRow += 1
         time.sleep(0.5)

if __name__ == "__main__":
   main(sys.argv[1:])
          


