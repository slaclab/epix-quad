import pythonDaq
import time
import struct
import os
import sys
import getopt

def main(argv):
   outputfile = ''
   outputfileTps = ''
   try:
      opts, args = getopt.getopt(argv,"ho:")
   except getopt.GetoptError:
      print 'testBackend -o <base filename for output>'
      sys.exit(2)
   for opt, arg in opts:
      if opt == '-h':
         print 'testBackend -o <base filename for output>'
         sys.exit()
      elif opt in ("-o", "--ofile"):
         outputfile = arg

   outputfileTps = outputfile+"Tps.bin"
   outputfile    = outputfile+".bin"

   pythonDaq.daqOpen("epix",1)

   #Enable test backend
   pythonDaq.daqSetConfig("digFpga:epixAsic:TestBe","True")
   #Disable IsEn (active low)
   pythonDaq.daqSetConfig("digFpga:epixAsic:IsEn","True")
   #Turn on pulser in manual mode
   pythonDaq.daqSetConfig("digFpga:epixAsic:Test","False")
   pythonDaq.daqSetConfig("digFpga:epixAsic:ATest","False")
   #Set manual ACQ control
#   pythonDaq.daqSetConfig("digFpga:AsicAcq","0")
#   pythonDaq.daqSetConfig("digFpga:AsicAcqControl","1")

   #Mask matrix
   pythonDaq.daqSetConfig("digFpga:epixAsic:PixelTest","False")
   pythonDaq.daqSetConfig("digFpga:epixAsic:PixelMask","True")
   pythonDaq.daqSendCommand("WriteMatrixData","")
   
   #Read out primary channel
   pythonDaq.daqSetConfig("digFpga:adcChannelToRead","0")
   pythonDaq.daqSetConfig("digFpga:epixAsic:S2dGr","0")
   pythonDaq.daqSetConfig("digFpga:epixAsic:RowCounter","96")
   pythonDaq.daqSetConfig("digFpga:epixAsic:PixelTest","True")
   pythonDaq.daqSetConfig("digFpga:epixAsic:PixelMask","False")
   pythonDaq.daqSendCommand("WriteRowData","")

   pythonDaq.daqOpenData(outputfile);
   for filter_dac_setting in range(0,64):
      pythonDaq.daqSetConfig("digFpga:epixAsic:FilterDac",str(filter_dac_setting))
      pythonDaq.daqSendCommand("SoftwareTrigger","")
   pythonDaq.daqCloseData(outputfile);

   #Set gain of test point system
   pythonDaq.daqSetConfig("digFpga:epixAsic:TpsGr","0")
   #Turn off temperature compensation on test point system
   pythonDaq.daqSetConfig("digFpga:epixAsic:TpsTComp","False")
   #Read out tps channel
   pythonDaq.daqSetConfig("digFpga:adcChannelToRead","16")
   pythonDaq.daqSetConfig("digFpga:epixAsic:TpsMux","10")
   #Open data file
   pythonDaq.daqOpenData(outputfileTps);
   for filter_dac_setting in range(0,64):
      pythonDaq.daqSetConfig("digFpga:epixAsic:FilterDac",str(filter_dac_setting))
      pythonDaq.daqSendCommand("SoftwareTrigger","")
   #Close the data file
   pythonDaq.daqCloseData(outputfileTps);

if __name__ == "__main__":
   main(sys.argv[1:])
          


