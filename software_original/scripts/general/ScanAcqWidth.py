import pythonDaq
import time
import struct
import os
import sys
import getopt

def main(argv):

   pythonDaq.daqOpen("epix",1);

   framesPerSetting = 10;

#   pythonDaq.daqSetConfig("digFpga:RunTrigEnable","True");
#   pythonDaq.daqSetConfig("digFpga:DaqTrigEnable","True");

   filename_base = "data_rdpc84/20140417/AcqScan";

   for acqWidth in range(1,1000001,1000): 
#   for acqWidth in range(32500-10000,32500+10000,1250): #Step from 40 us to 2000 us in 10 us increments
      #Set integration time
      pythonDaq.daqSetConfig("digFpga:AutoDaqEnable","False");
#      filename = filename_base + str(acqWidth*0.008) + "us.bin";
#      pythonDaq.daqOpenData(filename);
      pythonDaq.daqSetConfig("digFpga:asicAcqWidth",str(acqWidth));
#      pythonDaq.daqSetConfig("digFpga:AutoDaqEnable","True");
#      print("Now running at: "+str(acqWidth*0.008)+"us");
      pythonDaq.daqSendCommand("SoftwareTrigger",""); 
      time.sleep(0.2);
#      pythonDaq.daqCloseData(filename);
      ##########

if __name__ == "__main__":
   main(sys.argv[1:])
          


