import pythonDaq
import time
import struct
import os
import sys
import getopt

def main(argv):
   outputfile = ''
   try:
      opts, args = getopt.getopt(argv,"ho:")
   except getopt.GetoptError:
      print 'nwfScan -o <base filename for output>'
      sys.exit(2)
   for opt, arg in opts:
      if opt == '-h':
         print 'nwfScan -o <base filename for output>'
         sys.exit()
      elif opt in ("-o", "--ofile"):
         outputfile = arg

   pythonDaq.daqOpen("epix",1)

   framesPerSetting = 25
   
   #Turn on pulser
   pythonDaq.daqSetConfig("digFpga:epix100pAsic:Test","False")
   #Loop over all other settings
#   for pulser_setting in range(0,500,10):
   for pulser_setting in [0]:
      pythonDaq.daqSetConfig("digFpga:epix100pAsic:Pulser",str(pulser_setting));
      pulser_setting_readable = 'z';
      for acq_setting in range(125,6375,125):
         pythonDaq.daqSetConfig("digFpga:asicAcqWidth",str(acq_setting));
         #pythonDaq.daqSetConfig("digFpga:asicR0ToAsicAcq",str(acq_setting));
         acq_setting_readable = '%02d' % (acq_setting / 125);
#         for filter_dac_setting in range(0,64,4):
         for filter_dac_setting in [0]:
            pythonDaq.daqSetConfig("digFpga:epix100pAsic:FilterDac",str(filter_dac_setting));
            filter_dac_setting_readable = '%02d' % (filter_dac_setting / 4);
            this_filename = outputfile+"P"+str(pulser_setting_readable)+"D"+str(acq_setting_readable)+"F"+str(filter_dac_setting_readable)+".bin"
            pythonDaq.daqSendCommand("PrepForRead","");
            pythonDaq.daqOpenData(this_filename);
            for frame in range (0,framesPerSetting):
               pythonDaq.daqSendCommand("SoftwareTrigger","");
            pythonDaq.daqCloseData(this_filename);

if __name__ == "__main__":
   main(sys.argv[1:])
          


