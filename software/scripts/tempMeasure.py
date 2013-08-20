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
      print 'tempMeasure -o <base filename for output>'
      sys.exit(2)
   for opt, arg in opts:
      if opt == '-h':
         print 'tempMeasure -o <base filename for output>'
         sys.exit()
      elif opt in ("-o", "--ofile"):
         outputfile = arg

   pythonDaq.daqOpen("epix",1)

   #Set gain of test point system
   pythonDaq.daqSetConfig("digFpga:epixAsic:TpsGr","13")
   pythonDaq.daqSetConfig("digFpga:epixAsic:TpsDac","63")
   pythonDaq.daqSetConfig("digFpga:epixAsic:TpsTComp","True")
   #Set TPS as readout channel
   pythonDaq.daqSetConfig("digFpga:adcChannelToRead","16")
   #Set temperature sensor to read on TPS system
   pythonDaq.daqSetConfig("digFpga:epixAsic:TpsMux","13")

   outputfile = "temp.bin"

   #Measure temperature
   while(1):
      pythonDaq.daqReadStatus("")
      carrier_temp  = int(pythonDaq.daqGetStatus("digFpga(0):AdcValue04"),16)
      adc_card_temp = int(pythonDaq.daqGetStatus("digFpga(0):AdcValue06"),16)
      carrier_temp_conv = carrier_temp * -0.0261 + 95.116
      adc_temp_conv = adc_card_temp * -0.0261 + 95.116
      #Take one frame and grab the value
      pythonDaq.daqOpenData(outputfile);
      pythonDaq.daqSendCommand("SoftwareTrigger","");
      pythonDaq.daqCloseData(outputfile);
      fin = open(outputfile,"rb")
      fin_data = fin.read(4)
      fin_data = fin.read(4)
      fin_data = fin.read(4)
      asic_temp = struct.unpack('I',fin_data)[0]
      fin.close()
      os.remove(outputfile)
      print str(carrier_temp)+"\t"+str(carrier_temp_conv)+"\t"+str(adc_card_temp)+"\t"+str(adc_temp_conv)+"\t"+str(asic_temp)
      time.sleep(0.05)
 
if __name__ == "__main__":
   main(sys.argv[1:])
          


