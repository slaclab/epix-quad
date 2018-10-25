#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue AXI Version Module
#-----------------------------------------------------------------------------
# File       : 
# Author     : Maciej Kwiatkowski
# Created    : 2016-09-29
# Last update: 2017-01-31
#-----------------------------------------------------------------------------
# Description:
#-----------------------------------------------------------------------------
# This file is part of the rogue software platform. It is subject to 
# the license terms in the LICENSE.txt file found in the top-level directory 
# of this distribution and at: 
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
# No part of the rogue software platform, including this file, may be 
# copied, modified, propagated, or distributed except according to the terms 
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------
import pyrogue as pr
import collections
import numpy as np

class EpixQuadMonitor(pr.Device):
   def __init__(self, **kwargs):
      """Create the configuration device for Monitoring Core data readout"""
      super().__init__(description='Temperature Sensors Registers', **kwargs)
      
      def getPwrCurr(var):
         x = var.dependencies[0].value()
         return x * 0.1024 / 4095 / 0.02
      
      def getPwrVin(var):
         x = var.dependencies[0].value()
         return x * 102.4 / 4095
      
      def getPwrTemp(var):
         x = var.dependencies[0].value()
         a = 130.0/(0.882-1.951)
         b = (0.882/0.0082)+100
         return x * 2.048 / 4095 * a + b
         
      def getShtHum(var):
         x = var.dependencies[0].value()
         return x / 65535.0 * 100.0
      
      def getShtTemp(var):
         x = var.dependencies[0].value()
         return x / 65535.0 * 175.0 - 45.0
      
      def getNctTemp(var):
         x = var.dependencies[0].value()
         y = var.dependencies[1].value()
         return x * 1.0 + (y >> 6) * 0.25
      
      def getNctTempLoc(var):
         x = var.dependencies[0].value()
         return x * 1.0 
      
      def getLt3086DoubleCurr(var):
         x = var.dependencies[0].value()
         # Imon = Iin / 1000
         # Rload = 330 ohm
         # ADC buffer gain x 2
         # Two parallel LDOs current x 2
         # returns current in A
         return x / 16383.0 * 2.5 / 330.0 * 1000
      
      def getLt3086SingleCurr(var):
         x = var.dependencies[0].value()
         # Imon = Iin / 1000
         # Rload = 330 ohm
         # ADC buffer gain x 2
         # One LDO current x 1
         # returns current in mA
         return x / 16383.0 * 2.5 / 330.0 * 1000000 / 2.0
      
      def getThermistorTemp(var):
         # resistor divider 100k and MC65F103B (Rt25=10k)
         # Vref 2.5V
         x = var.dependencies[0].value()
         if x != 0:
            Umeas = x / 16383.0 * 2.5
            Itherm = Umeas / 100000;
            Rtherm = (2.5 - Umeas) / Itherm;
            LnRtR25 = np.log(Rtherm/10000.0)
            TthermK = 1.0 / (3.3538646E-03 + 2.5654090E-04 * LnRtR25 + 1.9243889E-06 * (LnRtR25**2) + 1.0969244E-07 * (LnRtR25**3))
            return TthermK - 273.15
         else:
            return 0.0
      
      def getAnaTemp(var):
         x = var.dependencies[0].value()
         a = 130.0/(0.882-1.951)
         b = (0.882/0.0082)+100
         return x * 1.65 / 65535 * a + b
      
      def getLdoTemp(var):
         x = var.dependencies[0].value()
         return x * 1.65 / 65535 *100
      
      def getTrOptTemp(var):
         x = var.dependencies[0].value()
         return x * 1.0 / 256
      
      def getTrOptVolt(var):
         x = var.dependencies[0].value()
         return x * 0.0001
      
      def getTrOptPwr(var):
         x = var.dependencies[0].value()
         return x * 0.1
      
      # Creation. memBase is either the register bus server (srp, rce mapped memory, etc) or the device which
      # contains this object. In most cases the parent and memBase are the same but they can be 
      # different in more complex bus structures. They will also be different for the top most node.
      # The setMemBase call can be used to update the memBase for this Device. All sub-devices and local
      # blocks will be updated.
      
      #############################################
      # Create block / variable combinations
      #############################################
      
      
      #Setup registers & variables
      self.add((pr.RemoteVariable(name='MonitorEn',      description='Enable Monitor',              offset=0x00000000, bitSize=1,  bitOffset=0,  base=pr.Bool, mode='RW')))
      self.add((pr.RemoteVariable(name='MonitorStrEn',   description='Monitor Stream Enabled',      offset=0x00000004, bitSize=1,  bitOffset=0,  base=pr.Bool, mode='RO')))
      self.add((pr.RemoteVariable(name='TrigPrescaler',  description='Monitor Triggger Prescaler',  offset=0x00000008, bitSize=16, bitOffset=0,  base=pr.UInt, mode='RW')))
      self.add((pr.RemoteVariable(name='ShtError',       description='SHT31 Humidity Sensor Error', offset=0x0000000C, bitSize=16, bitOffset=0,  base=pr.UInt, mode='RO')))
      self.add((pr.RemoteVariable(name='ShtHumRaw',      description='SHT31 Humidity Value',        offset=0x00000010, bitSize=16, bitOffset=0,  base=pr.UInt, mode='RO')))
      self.add(pr.LinkVariable(
         name         = 'ShtHum', 
         mode         = 'RO', 
         units        = '%',
         linkedGet    = getShtHum,
         disp         = '{:1.2f}',
         dependencies = [self.ShtHumRaw],
      )) 
      self.add((pr.RemoteVariable(name='ShtTempRaw',     description='SHT31 Temperature Value',     offset=0x00000014, bitSize=16, bitOffset=0,  base=pr.UInt, mode='RO')))
      self.add(pr.LinkVariable(
         name         = 'ShtTemp', 
         mode         = 'RO', 
         units        = 'deg C',
         linkedGet    = getShtTemp,
         disp         = '{:1.2f}',
         dependencies = [self.ShtTempRaw],
      )) 
      self.add((pr.RemoteVariable(name='NctError',       description='NCT218 Temp. Sensor Error',   offset=0x00000018, bitSize=16, bitOffset=0,  base=pr.UInt, mode='RO')))
      self.add((pr.RemoteVariable(name='NctLocTempRaw',  description='NCT218 Local Temp.',          offset=0x0000001C, bitSize=8,  bitOffset=0,  base=pr.UInt, mode='RO')))
      self.add(pr.LinkVariable(
         name         = 'NctLocTemp', 
         mode         = 'RO', 
         units        = 'deg C',
         linkedGet    = getNctTempLoc,
         disp         = '{:1.2f}',
         dependencies = [self.NctLocTempRaw],
      )) 
      self.add((pr.RemoteVariable(name='NctRemTempLRaw', description='NCT218 Remote Temp. L Byte',  offset=0x00000020, bitSize=8,  bitOffset=0,  base=pr.UInt, mode='RO')))
      self.add((pr.RemoteVariable(name='NctRemTempHRaw', description='NCT218 Remote Temp. H Byte',  offset=0x00000024, bitSize=8,  bitOffset=0,  base=pr.UInt, mode='RO')))
      self.add(pr.LinkVariable(
         name         = 'NctRemTemp', 
         mode         = 'RO', 
         units        = 'deg C',
         linkedGet    = getNctTemp,
         disp         = '{:1.2f}',
         dependencies = [self.NctRemTempHRaw, self.NctRemTempLRaw],
      )) 
      
      for i in range(8):      
         self.add(pr.RemoteVariable(
            name       = ('AD7949DataRaw[%d]'%i),
            description= ('AD7949 Raw Data Channel [%d]'%i),
            offset     = (0x00000100+i*4), 
            bitSize    = 14, 
            bitOffset  = 0,  
            base       = pr.UInt, 
            mode       = 'RO',
         ))
      
      for i in range(4):
         self.add(pr.LinkVariable(
            name         = ('ASIC_A%d_2V5_Current'%i), 
            mode         = 'RO', 
            units        = 'A',
            linkedGet    = getLt3086DoubleCurr,
            disp         = '{:1.3f}',
            dependencies = [self.AD7949DataRaw[i]],
         )) 
      
      for i in range(2):
         self.add(pr.LinkVariable(
            name         = ('ASIC_D%d_2V5_Current'%i), 
            mode         = 'RO', 
            units        = 'mA',
            linkedGet    = getLt3086SingleCurr,
            disp         = '{:1.3f}',
            dependencies = [self.AD7949DataRaw[4+i]],
         )) 
      
      for i in range(2):
         self.add(pr.LinkVariable(
            name         = ('Therm%d_Temp'%i), 
            mode         = 'RO', 
            units        = 'deg C',
            linkedGet    = getThermistorTemp,
            disp         = '{:1.3f}',
            dependencies = [self.AD7949DataRaw[6+i]],
         )) 
      
      
      for i in range(6):      
         self.add(pr.RemoteVariable(
            name       = ('SensorRegRaw[%d]'%i),
            description= ('Sensor Raw Data Register [%d]'%i),
            offset     = (0x00000200+i*4), 
            bitSize    = 32, 
            bitOffset  = 0,  
            base       = pr.UInt, 
            mode       = 'RO',
            verify     = False,
         ))
      
      self.add(pr.LinkVariable(
         name         = 'PwrDigCurr', 
         mode         = 'RO', 
         units        = 'A',
         linkedGet    = getPwrCurr,
         disp         = '{:1.3f}',
         dependencies = [self.SensorRegRaw[0]],
      )) 
      
      self.add(pr.LinkVariable(
         name         = 'PwrDigVin', 
         mode         = 'RO', 
         units        = 'V',
         linkedGet    = getPwrVin,
         disp         = '{:1.3f}',
         dependencies = [self.SensorRegRaw[1]],
      )) 
      
      self.add(pr.LinkVariable(
         name         = 'PwrDigTemp', 
         mode         = 'RO', 
         units        = 'deg C',
         linkedGet    = getPwrTemp,
         disp         = '{:3.1f}',
         dependencies = [self.SensorRegRaw[2]],
      )) 
      
      self.add(pr.LinkVariable(
         name         = 'PwrAnaCurr', 
         mode         = 'RO', 
         units        = 'A',
         linkedGet    = getPwrCurr,
         disp         = '{:1.3f}',
         dependencies = [self.SensorRegRaw[3]],
      )) 
      
      self.add(pr.LinkVariable(
         name         = 'PwrAnaVin', 
         mode         = 'RO', 
         units        = 'V',
         linkedGet    = getPwrVin,
         disp         = '{:1.3f}',
         dependencies = [self.SensorRegRaw[4]],
      )) 
      
      self.add(pr.LinkVariable(
         name         = 'PwrAnaTemp', 
         mode         = 'RO', 
         units        = 'deg C',
         linkedGet    = getPwrTemp,
         disp         = '{:3.1f}',
         dependencies = [self.SensorRegRaw[5]],
      )) 
      
      for i in range(16):      
         i = i + 6
         self.add(pr.RemoteVariable(
            name       = ('SensorRegRaw[%d]'%i),
            description= ('Sensor Raw Data Register [%d]'%i),
            offset     = (0x00000200+i*4), 
            bitSize    = 32, 
            bitOffset  = 0,  
            base       = pr.UInt, 
            mode       = 'RO',
            verify     = False,
         ))
      
      
      LdoNames = [
         'A0+2_5V_H_Temp', 'A0+2_5V_L_Temp',
         'A1+2_5V_H_Temp', 'A1+2_5V_L_Temp',
         'A2+2_5V_H_Temp', 'A2+2_5V_L_Temp',
         'A3+2_5V_H_Temp', 'A3+2_5V_L_Temp',
         'D0+2_5V_Temp'  , 'D1+2_5V_Temp',
         'A0+1_8V_Temp'  , 'A1+1_8V_Temp',
         'A2+1_8V_Temp'
      ]
      
      for i in range(13):      
         self.add(pr.LinkVariable(
            name         = LdoNames[i], 
            mode         = 'RO', 
            units        = 'deg C',
            linkedGet    = getLdoTemp,
            disp         = '{:3.1f}',
            dependencies = [self.SensorRegRaw[i+6]],
         )) 
      
      self.add(pr.LinkVariable(
         name         = 'PcbAnaTemp0', 
         mode         = 'RO', 
         units        = 'deg C',
         linkedGet    = getAnaTemp,
         disp         = '{:3.1f}',
         dependencies = [self.SensorRegRaw[19]],
      )) 
      
      self.add(pr.LinkVariable(
         name         = 'PcbAnaTemp1', 
         mode         = 'RO', 
         units        = 'deg C',
         linkedGet    = getAnaTemp,
         disp         = '{:3.1f}',
         dependencies = [self.SensorRegRaw[20]],
      )) 
      
      self.add(pr.LinkVariable(
         name         = 'PcbAnaTemp2', 
         mode         = 'RO', 
         units        = 'deg C',
         linkedGet    = getAnaTemp,
         disp         = '{:3.1f}',
         dependencies = [self.SensorRegRaw[21]],
      )) 
      
      
      for i in range(4):      
         i = i + 22
         self.add(pr.RemoteVariable(
            name       = ('SensorRegRaw[%d]'%i),
            description= ('Sensor Raw Data Register [%d]'%i),
            offset     = (0x00000200+i*4), 
            bitSize    = 32, 
            bitOffset  = 0,  
            base       = pr.UInt, 
            mode       = 'RO',
            verify     = False,
         ))
      
      self.add(pr.LinkVariable(
         name         = 'TrOptTemp', 
         mode         = 'RO', 
         units        = 'deg C',
         linkedGet    = getTrOptTemp,
         disp         = '{:3.1f}',
         dependencies = [self.SensorRegRaw[22]],
      )) 
      
      self.add(pr.LinkVariable(
         name         = 'TrOptVcc', 
         mode         = 'RO', 
         units        = 'V',
         linkedGet    = getTrOptVolt,
         disp         = '{:3.1f}',
         dependencies = [self.SensorRegRaw[23]],
      )) 
      
      self.add(pr.LinkVariable(
         name         = 'TrOptTxPwr', 
         mode         = 'RO', 
         units        = 'uW',
         linkedGet    = getTrOptPwr,
         disp         = '{:3.1f}',
         dependencies = [self.SensorRegRaw[24]],
      )) 
      
      self.add(pr.LinkVariable(
         name         = 'TrOptRxPwr', 
         mode         = 'RO', 
         units        = 'uW',
         linkedGet    = getTrOptPwr,
         disp         = '{:3.1f}',
         dependencies = [self.SensorRegRaw[25]],
      )) 
      
      #####################################
      # Create commands
      #####################################
      
      # A command has an associated function. The function can be a series of
      # python commands in a string. Function calls are executed in the command scope
      # the passed arg is available as 'arg'. Use 'dev' to get to device scope.
      # A command can also be a call to a local function with local scope.
      # The command object and the arg are passed
   
   @staticmethod   
   def frequencyConverter(self):
      def func(dev, var):         
         return '{:.3f} kHz'.format(1/(self.clkPeriod * self._count(var.dependencies)) * 1e-3)
      return func
