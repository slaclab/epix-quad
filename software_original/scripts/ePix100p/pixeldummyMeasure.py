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

   #Set pixel dummy
   pythonDaq.daqSetConfig("digFpga:epix100pAsic:DummyTest","False")
   pythonDaq.daqSetConfig("digFpga:epix100pAsic:DummyMask","True")
   #Set gain of test point system
   pythonDaq.daqSetConfig("digFpga:epix100pAsic:TpsGr","4")
   pythonDaq.daqSetConfig("digFpga:epix100pAsic:TpsDac","33")
   pythonDaq.daqSetConfig("digFpga:epix100pAsic:TpsTComp","True")
   #Set TPS as readout channel
   pythonDaq.daqSetConfig("digFpga:adcChannelToRead","16")
   #Set abus on TPS system
   pythonDaq.daqSetConfig("digFpga:epix100pAsic:TpsMux","3")

   outputfile = "temp.bin"

   #Measure temperature
   while(1):
      pythonDaq.daqReadStatus("")
      carrier_temp  = int(pythonDaq.daqGetStatus("digFpga(0):AdcValue04"),16)
      carrier_temp_conv = carrier_temp * carrier_temp * 6e-6 + carrier_temp * (-0.0489) + 112.26
      #Take one frame and grab the value
      pythonDaq.daqOpenData(outputfile);
      pythonDaq.daqSendCommand("SoftwareTrigger","");
      pythonDaq.daqCloseData(outputfile);
      fin = open(outputfile,"rb")
      fin_data = fin.read(4)
      fin_data = fin.read(4)
      fin_data = fin.read(4)
      abus = struct.unpack('I',fin_data)[0]
      fin.close()
      os.remove(outputfile)
      print str(carrier_temp)+"\t"+str(carrier_temp_conv)+"\t"+str(abus)
      time.sleep(0.05)
 
if __name__ == "__main__":
   main(sys.argv[1:])
          


