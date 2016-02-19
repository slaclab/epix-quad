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
      print 'args: -o <base filename for output>'
      sys.exit(2)
   for opt, arg in opts:
      if opt == '-h':
         print 'args: -o <base filename for output>'
         sys.exit()
      elif opt in ("-o", "--ofile"):
         outputfile = arg

   pythonDaq.daqOpen("epix",1)

   
   pythonDaq.daqOpenData(outputfile);

   pulser_setting = 0;
   pulserStep = 4;
   cycle = 0;
   total_cycles = 10;
   temp = 0;

   #General parameters
   pythonDaq.daqSetRunParameters("120Hz",pulserStep)
   pythonDaq.daqSetConfig("digFpga:epix100pAsic:ATest","True")

   while(cycle < total_cycles):
      #Turn on pulser
      pythonDaq.daqSetConfig("digFpga:epix100pAsic:Test","True")
      for i in range(0,pulserStep):
         pythonDaq.daqSendCommand("SoftwareTrigger","")
         time.sleep(0.002)
      pulser_setting = pulser_setting + pulserStep;
      if (pulser_setting > 1023):
         print "Finished cycle "+str(cycle)
         pulser_setting = 0
         cycle = cycle + 1
      #Turn off pulser
      pythonDaq.daqSetConfig("digFpga:epix100pAsic:Test","False")
      for i in range(0,pulserStep):
         pythonDaq.daqSendCommand("SoftwareTrigger","")
         time.sleep(0.002)
   
   pythonDaq.daqCloseData(outputfile)

if __name__ == "__main__":
   main(sys.argv[1:])
          


