
# daqHardReset          
# daqSoftReset          
# daqRefreshState       
# daqSetDefaults        
# daqLoadSettings       file
# daqSaveSettings       file
# daqOpenData           file
# daqCloseData          
# daqSetRunParameters   rate count
# daqSetRunState        state
# daqGetRunState        
# daqResetCounters      
# daqSendCommand        command
# daqReadStatus         
# daqGetStatus          variable
# daqReadConfig         
# daqVerifyConfig       
# daqSetConfig          variable arg
# daqGetConfig          variable
# daqGetSystemStatus    
# daqGetUserStatus      
# daqGetError           
# daqSendXml            xml_string
# daqDisableTimeout

import pythonDaq
import time
import struct
import os

def CalcMax():
   f = open("temp.bin","rb")
   try:
      for i in range(0, 2+9216+96):
         word = f.read(4)
      mean = 0
      sumsq = 0
      for i in range(0, 96):
         word = f.read(4)
         word = struct.unpack('I',word)
         mean += word[0]
         sumsq += word[0]*word[0]
#         print word[0]
      mean /= 96
      rms = pow( sumsq - mean*mean , 0.5)
   finally:
      f.close()
   return mean,rms

def CalcMin():
   f = open("temp.bin","rb")
   try:
      for i in range(0, 2+9216):
         word = f.read(4)
      mean = 0
      sumsq = 0
      for i in range(0, 96):
         word = f.read(4)
         word = struct.unpack('I',word)
         mean += word[0]
         sumsq += word[0]*word[0]
#         print word[0]
      mean /= 96
      rms = pow( sumsq - mean*mean , 0.5)
   finally:
      f.close()
   return mean,rms

def TakeFrame(adcmin, adcmax):
   if os.path.isfile("temp.bin"):
     os.remove("temp.bin")
   pythonDaq.daqOpenData("temp.bin")
   pythonDaq.daqSendCommand("SoftwareTrigger","")
   pythonDaq.daqCloseData()
   [min,min_rms] = CalcMin()
   [max,max_rms] = CalcMax()
   ctr = (max+min)/2
   dmin = min - adcmin
   dmax = max - adcmax
   dctr = ctr-(adcmax+adcmin)/2
   return max,min,max_rms,min_rms,ctr,dmin,dmax,dctr

def Center(s2d_dac_start,thresh):
   done = False
   s2d_dac = s2d_dac_start
   S2D_DAC_MAX = 32
   #Scan for closest value to zero
   min = 0;
   dac_at_min = 0;
   for s2d_dac in range(0,S2D_DAC_MAX):
      pythonDaq.daqSetConfig("digFpga:epixAsic:S2dDac",str(s2d_dac))
      [max,min,max_rms,min_rms,ctr,dmin,dmax,dctr] = TakeFrame(ADCmin,ADCmax)
      print "max = ",max
      print "min = ",min
      print "ctr = ",ctr
      print "dmin = ",dmin
      print "dmax = ",dmax
      print "dctr = ",dctr
      if (s2d_dac == 0):
         dac_at_min = s2d_dac
         min = abs(dctr)
      elif (abs(dctr) < min):
         dac_at_min = s2d_dac
         min = abs(dctr) 
      raw_input("...")
   return s2d_dac

def BruteForceSweep():
   S2D_DAC_MAX = 32
   S2D_GR_MAX  = 16
   BUFFER      = 100
   EFF_MAX     = 16383-BUFFER
   EFF_MIN     = 0+BUFFER
   first = True
   best_dac = 0
   best_gr = 0
   best_usable_range = 0
   for s2d_dac in range(0,S2D_DAC_MAX):
      for s2d_gr in range(0,S2D_GR_MAX):
         pythonDaq.daqSetConfig("digFpga:epixAsic:S2dDac",str(s2d_dac))
         pythonDaq.daqSetConfig("digFpga:epixAsic:S2dGr",str(s2d_gr))
         [max,min,max_rms,min_rms,ctr,dmin,dmax,dctr] = TakeFrame(EFF_MIN,EFF_MAX)
         this_high = max if max < EFF_MAX else EFF_MAX
         this_low  = min if min > EFF_MIN else EFF_MIN
         usable_range = this_high - this_low
         if (first or usable_range > best_usable_range):
            first = False
            best_usable_range = usable_range
            best_dac = s2d_dac
            best_gr  = s2d_gr
         print s2d_dac," ",s2d_gr," ",max," ",min," ",max_rms," ",min_rms
   return s2d_dac, s2d_gr


pythonDaq.daqOpen("epix",1)


#Defaults
S2D_GR = 3
S2D_DAC = 22
TH = 100
CTR_TH = 2
ADCmax = 16383 - TH
ADCmin = TH

S2D_GR = 4
S2D_DAC = 21

done = False

s2d_dac = 21
s2d_gr = 4
#pythonDaq.daqSetConfig("digFpga:epixAsic:S2dDac",str(s2d_dac))
#pythonDaq.daqSetConfig("digFpga:epixAsic:S2dGr",str(s2d_gr))
pythonDaq.daqSetConfig("digFpga:epixAsic:S2dDac",str(S2D_DAC))
pythonDaq.daqSetConfig("digFpga:epixAsic:S2dGr",str(S2D_GR))
#[max,min,max_rms,min_rms,ctr,dmin,dmax,dctr] = TakeFrame(ADCmin,ADCmax)
#print s2d_dac," ",s2d_gr," ",max," ",min

#Initial condition
#pythonDaq.daqSetConfig("digFpga:epixAsic:S2dDac",str(S2D_DAC))
#pythonDaq.daqSetConfig("digFpga:ePixAsic:S2dGr",str(S2D_GR))
#Take a frame
#S2D_DAC = 21
#S2D_GR = 4
#pythonDaq.daqSetConfig("digFpga:epixAsic:S2dDac",str(S2D_DAC))
#pythonDaq.daqSetConfig("digFpga:ePixAsic:S2dGr",str(S2D_GR))
#[max,min,ctr,dmin,dmax,dctr] = TakeFrame(ADCmin,ADCmax)
#print "max = ",max
#print "min = ",min
#print "ctr = ",ctr
#print "dmin = ",dmin
#print "dmax = ",dmax
#print "dctr = ",dctr
#[max,min,ctr,dmin,dmax,dctr] = TakeFrame(0,0)
#print "max = ",max
#print "min = ",min
#print "ctr = ",ctr
#print "dmin = ",dmin
#print "dmax = ",dmax
#print "dctr = ",dctr

#S2D_DAC = Center(S2D_DAC,CTR_TH)
#print "optimized s2d_dac = ",S2D_DAC
[S2D_DAC,S2D_GR] = BruteForceSweep()
#print "optimized s2d_dac, s2d_gr = ",S2D_DAC,",",S2D_GR


#while !done:
#   if !(Dmax > 0 && Dmin < 0):
#      while (Dmax > 0 && Dmin > 0) || (Dmin + Dmax) > 0:
#         S2D_DAC = S2D_DAC+1
#         TakeFrame()
#      while (Dmax < 0 && Dmin < 0) || (Dmin + Dmax) < 0:
#         S2D_DAC = S2D_DAC-1
#         TakeFrame()
#      S2D_GR = S2D_GR + 1
#      TakeFrame()
#   else:
#      done = True
#      S2D_GR = S2D_GR - 1

