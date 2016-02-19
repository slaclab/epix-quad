import pythonDaq
import time
import struct
import os
import sys
import getopt

def main(argv):
   outputFile = '';
   try:
      opts, args = getopt.getopt(argv,"ho:");
   except getopt.GetoptError:
      print '<executable> -o <base filename for output>'
      sys.exit(2);
   for opt, arg in opts:
      if opt == '-h':
         print '<executable> -o <base filename for output>'
         sys.exit();
      elif opt in ("-o", "--ofile"):
         outputFile = arg;

   pythonDaq.daqOpen("epix",1);

   framesPerSetting = 300;

   pythonDaq.daqSetConfig("digFpga:asicMask","8");
   pythonDaq.daqSetConfig("digFpga:asicRoClkHalfT","12");
   pythonDaq.daqSetConfig("digFpga:saciClkBit","4");
   pythonDaq.daqSetConfig("digFpga:epix100pAsic:PixelMask","False");
   pythonDaq.daqSetConfig("digFpga:epix100pAsic:PixelTest","True");
   pythonDaq.daqSetConfig("digFpga:epix100pAsic:S2dTComp","False");
   pythonDaq.daqSendCommand("WriteMatrixData",""); 
   
#   for acqWidth in range(5000,25001,1250): #Step from 40 us to 200 us in 10 us increments
   for acqWidth in range(25000,25001,1250): #Step from 40 us to 200 us in 10 us increments
      #Set integration time
      pythonDaq.daqSetConfig("digFpga:asicAcqWidth",str(acqWidth));

      #DARK FRAME####
      pythonDaq.daqSetConfig("digFpga:epix100pAsic:Test","False");
      acqWidthString = '%03d' % (acqWidth/125);
      darkFilename   = outputFile+".acq"+str(acqWidthString)+".dark";

      pythonDaq.daqOpenData(darkFilename);
      pythonDaq.daqSetRunParameters("120Hz",framesPerSetting);
      pythonDaq.daqSetRunState("Running");
      while(pythonDaq.daqGetStatus("Run State") == "Running"):
         time.sleep(1);   
      time.sleep(10);
      pythonDaq.daqCloseData(darkFilename);
      ########

      #PULSER FRAME#######
      for pulserSetting in range(200,1001,200):
#      for pulserSetting in range(200,201,200):
         pulserString  = '%04d' % (pulserSetting);
         pulseFilename = outputFile+".acq"+str(acqWidthString)+".pulse"+str(pulserSetting);
         pythonDaq.daqSetConfig("digFpga:epix100pAsic:Pulser",str(pulserSetting));
         pythonDaq.daqSetConfig("digFpga:epix100pAsic:Test","True");

         pythonDaq.daqOpenData(pulseFilename);
         pythonDaq.daqSetRunParameters("120Hz",framesPerSetting);
         pythonDaq.daqSetRunState("Running");
         while(pythonDaq.daqGetStatus("Run State") == "Running"):
            time.sleep(1);   
         time.sleep(10);
         pythonDaq.daqCloseData(pulseFilename);
      ##########

if __name__ == "__main__":
   main(sys.argv[1:])
          


