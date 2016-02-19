import pythonDaq
import time
import struct
import os
import sys
import getopt

def main(argv):
   pythonDaq.daqOpen("epix",1)

   f = open('startupLog.txt', 'w')

   frameDelay = [0 for i in range(3)]
   dataDelay = [[0 for j in range(8)] for i in range(3)]
   
   for trial in range(0,100):
      pythonDaq.daqSetConfig("digFpga:RequestStartup","False")
      time.sleep(0.5)
      pythonDaq.daqSetConfig("digFpga:RequestStartup","True")
      time.sleep(20)
      pythonDaq.daqReadConfig("")
      pythonDaq.daqReadStatus("")
      done = pythonDaq.daqGetStatus("digFpga(0):StartupDone")
      fail = pythonDaq.daqGetStatus("digFpga(0):StartupFail")
      print "StartupDone = "+ str(done)
      print "StartupFail = "+ str(fail)
      for adc in range(0,3):
         frameStr = "digFpga:Adc"+str(adc)+"FrameDelay"
         frameDelay[adc] = pythonDaq.daqGetConfig(frameStr)
         print frameStr+" = "+str(frameDelay[adc])
         for ch in range(0,8):
            if (adc == 2 and ch >= 4):
               continue
            delayStr = "digFpga:Adc"+str(adc)+"Ch"+str(ch)+"Delay"
            dataDelay[adc][ch] = pythonDaq.daqGetConfig(delayStr)
            print delayStr+" = "+str(dataDelay[adc][ch])
      pythonDaq.daqSetConfig("digFpga:RequestStartup","False")

      f.write(str(int(done == "True"))+"\t")
      f.write(str(int(fail == "True"))+"\t")
      for adc in range(0,3):
         f.write(str(int(str(frameDelay[adc]),16))+"\t")
      for adc in range(0,3):
         for ch in range(0,8):
            f.write(str(int(str(dataDelay[adc][ch]),16))+"\t")
      f.write("\n")


if __name__ == "__main__":
   main(sys.argv[1:])
          


