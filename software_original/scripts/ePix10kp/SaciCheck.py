import pythonDaq
import time
import struct
import os
import sys
import getopt

def main(argv):
   inputfile = ''
   try:
      opts, args = getopt.getopt(argv,"hi:")
   except getopt.GetoptError:
      print 'LoadPixelMap -i <input tab separated pixel map>'
      sys.exit(2)
   for opt, arg in opts:
      if opt == '-h':
         print 'LoadPixelMap -i <input tab separated pixel map>'
         sys.exit()
      elif opt in ("-i", "--ifile"):
         inputfile = arg

   pythonDaq.daqOpen("epix",1)
   saciClk = 0
   print 'Setting saciClk to '+str(125.0/2**(saciClk+1))+ ' MHz'
   pythonDaq.daqSetConfig("digFpga:saciClkBit",str(saciClk))

   #for nTries in [1,10,100,1000,10000,100000]:
   while (1):
      for nTries in [1000]:
         badReads = 0
         start = time.time()
         for i in range(0,nTries):
            pulserVal = i%1024
            pythonDaq.daqSetConfig("digFpga:epix10kpAsic:Pulser",str(pulserVal))
            pulserValRead = int(pythonDaq.daqGetConfig("digFpga:epix10kpAsic:Pulser"))
            if (pulserVal != pulserValRead):
               print( str(pulserVal) + " != " + str(pulserValRead) )
               badReads += 1
         end = time.time()
         #print(str(badReads)+" / "+str(nTries)+ " bad reads.")
         #print str(end-start)
         print str(nTries)+"\t"+str(float(badReads)/float(nTries))+"\t"+str(end-start)
   #

if __name__ == "__main__":
   main(sys.argv[1:])
          


