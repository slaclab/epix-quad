//-----------------------------------------------------------------------------
// File          : DigFpga.cpp // Author        : Ryan Herbst  <rherbst@slac.stanford.edu>
// Created       : 06/07/2013
// Project       : Digital FPGA
//-----------------------------------------------------------------------------
// Description :
// Digital FPGA container
//-----------------------------------------------------------------------------
// Copyright (c) 2013 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 06/07/2013: created
//-----------------------------------------------------------------------------
#include <DigFpga.h>
#include <DigFpgaCpix.h>
#include <DigFpgaTixel.h>
#include <Epix100pAsic.h>
#include <Epix100aAsic.h>
#include <Epix10kpAsic.h>
#include <EpixSAsic.h>
#include <CpixPAsic.h>
#include <TixelPAsic.h>
#include <Ad9252.h>
#include <PseudoScope.h>
#include <Register.h>
#include <Variable.h>
#include <Command.h>
#include <sstream>
#include <iostream>
#include <string>
#include <iomanip>
#include "EpixUtility.h"
#include "math.h"
using namespace std;

#define HIDE_SCOPE 1
#define CLOCK_PERIOD_IN_US (0.010)

// Constructor
DigFpga::DigFpga ( uint destination, uint baseAddress, uint index, Device *parent, uint addrSize, EpixType epixType ) : 
                   Device(destination,0,"digFpga",index,parent) {
   stringstream tmp;
   uint         x;

   //Set ePix type
   epixType_ = epixType;
   baseAddress_ = baseAddress;
   
   // Description
   desc_ = "Digital FPGA Object.";

   // Setup registers & variables
   addRegister(new Register("Version", baseAddress_ + addrSize*0x00000000));
   addVariable(new Variable("Version", Variable::Status));
   getVariable("Version")->setDescription("FPGA version field");

   addRegister(new Register("RunTrigEnable", baseAddress_ + addrSize*0x00000001));
   addVariable(new Variable("RunTrigEnable", Variable::Configuration));
   getVariable("RunTrigEnable")->setDescription("Run Trigger Enable");
   getVariable("RunTrigEnable")->setTrueFalse();

   addRegister(new Register("RunTrigDelay", baseAddress_ + addrSize*0x00000002));
   addVariable(new Variable("RunTrigDelay", Variable::Configuration));
   getVariable("RunTrigDelay")->setDescription("Run Trigger Delay");
   getVariable("RunTrigDelay")->setRange(0,0x7FFFFFFF);

   addRegister(new Register("DaqTrigEnable", baseAddress_ + addrSize*0x00000003));
   addVariable(new Variable("DaqTrigEnable", Variable::Configuration));
   getVariable("DaqTrigEnable")->setDescription("Daq Trigger Enable");
   getVariable("DaqTrigEnable")->setTrueFalse();

   addRegister(new Register("DaqTrigDelay", baseAddress_ + addrSize*0x00000004));
   addVariable(new Variable("DaqTrigDelay", Variable::Configuration));
   getVariable("DaqTrigDelay")->setDescription("Daq Trigger Delay");
   getVariable("DaqTrigDelay")->setRange(0,0x7FFFFFFF);

   addRegister(new Register("AcqCount", baseAddress_ + addrSize*0x00000005));
   addVariable(new Variable("AcqCount", Variable::Status));
   getVariable("AcqCount")->setDescription("Acquisition Counter");

   addRegister(new Register("AcqCountReset", baseAddress_ + addrSize*0x00000006));

   addRegister(new Register("SeqCount", baseAddress_ + addrSize*0x0000000B));
   addVariable(new Variable("SeqCount", Variable::Status));
   getVariable("SeqCount")->setDescription("Sequence (Frame) Counter");

   addRegister(new Register("SeqCountReset", baseAddress_ + addrSize*0x0000000C));

   addRegister(new Register("asicMask", baseAddress_ + addrSize*0x0000000D));
   addVariable(new Variable("asicMask", Variable::Configuration));
   getVariable("asicMask")->setDescription("ASIC Mask (1-present, 0-not present)");
   getVariable("asicMask")->setRange(0,0xF);

   addRegister(new Register("DacSetting", baseAddress_ + addrSize*0x00000007));
   addVariable(new Variable("DacSetting", Variable::Configuration));
   getVariable("DacSetting")->setDescription("DAC Setting");
   getVariable("DacSetting")->setRange(0,0xFFFF);
   getVariable("DacSetting")->setComp(0,4.883e-5,0,"V");

   addRegister(new Register("PowerEnable", baseAddress_ + addrSize*0x00000008));

   addVariable(new Variable("AnalogPowerEnable", Variable::Configuration));
   getVariable("AnalogPowerEnable")->setDescription("Analog Power Enable");
   getVariable("AnalogPowerEnable")->setRange(0,0x1);

   addVariable(new Variable("DigitalPowerEnable", Variable::Configuration));
   getVariable("DigitalPowerEnable")->setDescription("Digital Power Enable");
   getVariable("DigitalPowerEnable")->setRange(0,0x1);
   
   addVariable(new Variable("FpgaOutputEnable", Variable::Configuration));
   getVariable("FpgaOutputEnable")->setDescription("Fpga Output Enable");
   getVariable("FpgaOutputEnable")->setRange(0,0x1);

   addRegister(new Register("IDelayCtrlRdy", baseAddress_ + addrSize*0x0000000A));
   addVariable(new Variable("IDelayCtrlRdy", Variable::Status));
   getVariable("IDelayCtrlRdy")->setDescription("Ready flag for IDELAYCTRL block");

   for (x=0; x < 3; x++) {
      tmp.str("");
      tmp << "Adc" << dec << x << "FrameDelay";
      addRegister(new Register(tmp.str(), baseAddress_ + addrSize*(0x00000060 + x)));
      addVariable(new Variable(tmp.str(), Variable::Configuration));
      getVariable(tmp.str())->setDescription(tmp.str());
      getVariable(tmp.str())->setRange(0,0x3F);
   }
   for (x=0; x < 8; x++) {
      tmp.str("");
      tmp << "Adc0Ch" << dec << x << "Delay";
      addRegister(new Register(tmp.str(), baseAddress_ + addrSize*(0x00000063 + x)));
      addVariable(new Variable(tmp.str(), Variable::Configuration));
      getVariable(tmp.str())->setDescription(tmp.str());
      getVariable(tmp.str())->setRange(0,0x3F);
   }
   for (x=0; x < 8; x++) {
      tmp.str("");
      tmp << "Adc1Ch" << dec << x << "Delay";
      addRegister(new Register(tmp.str(), baseAddress_ + addrSize*(0x0000006B + x)));
      addVariable(new Variable(tmp.str(), Variable::Configuration));
      getVariable(tmp.str())->setDescription(tmp.str());
      getVariable(tmp.str())->setRange(0,0x3F);
   }
   for (x=0; x < 4; x++) {
      tmp.str("");
      tmp << "Adc2Ch" << dec << x << "Delay";
      addRegister(new Register(tmp.str(), baseAddress_ + addrSize*(0x00000073 + x)));
      addVariable(new Variable(tmp.str(), Variable::Configuration));
      getVariable(tmp.str())->setDescription(tmp.str());
      getVariable(tmp.str())->setRange(0,0x3F);
   }

   addRegister(new Register("Startup",baseAddress_ + addrSize*0x00000080));
   addVariable(new Variable("RequestStartup", Variable::Configuration));
   addVariable(new Variable("StartupDone", Variable::Status));
   addVariable(new Variable("StartupFail", Variable::Status));
   getVariable("RequestStartup")->setDescription("Request startup sequence");
   getVariable("RequestStartup")->setTrueFalse();
   getVariable("StartupDone")->setDescription("Startup sequence done");
   getVariable("StartupDone")->setTrueFalse();
   getVariable("StartupFail")->setDescription("Startup sequence failed");
   getVariable("StartupFail")->setTrueFalse();

   // Setup registers & variables
   addRegister(new Register("BaseClock", baseAddress_ + addrSize*0x00000010));
   addVariable(new Variable("BaseClock", Variable::Status));
   getVariable("BaseClock")->setDescription("FPGA Base Clock Frequency"); 

   //Autotriggers
   addRegister(new Register("AutoRunEnable", baseAddress_ + addrSize*0x00000011));
   addVariable(new Variable("AutoRunEnable", Variable::Configuration));
   getVariable("AutoRunEnable")->setDescription("Auto Run Enable");
   getVariable("AutoRunEnable")->setTrueFalse();

   addRegister(new Register("AutoRunPeriod", baseAddress_ + addrSize*0x00000012));
   addVariable(new Variable("AutoRunPeriod", Variable::Configuration));
   getVariable("AutoRunPeriod")->setDescription("Auto Run Enable");
   getVariable("AutoRunPeriod")->setComp(0,0.000010,0,"ms");

   addRegister(new Register("AutoDaqEnable", baseAddress_ + addrSize*0x00000013));
   addVariable(new Variable("AutoDaqEnable", Variable::Configuration));
   getVariable("AutoDaqEnable")->setDescription("Auto Daq Enable");
   getVariable("AutoDaqEnable")->setTrueFalse();

   // Manual ASIC pin controls
   addRegister(new Register("AsicPins", baseAddress_ + addrSize*0x00000029));

   addVariable(new Variable("AsicGR", Variable::Configuration));
   getVariable("AsicGR")->setDescription("ASIC Global Reset");
   getVariable("AsicGR")->setRange(0,0x0001);
   addVariable(new Variable("AsicAcq", Variable::Configuration));
   getVariable("AsicAcq")->setDescription("ASIC Acq Signal");
   getVariable("AsicAcq")->setRange(0,0x0001);
   addVariable(new Variable("AsicR0", Variable::Configuration));
   getVariable("AsicR0")->setDescription("ASIC R0 Signal");
   getVariable("AsicR0")->setRange(0,0x0001);
   addVariable(new Variable("AsicPpmat", Variable::Configuration));
   getVariable("AsicPpmat")->setDescription("ASIC Ppmat Signal");
   getVariable("AsicPpmat")->setRange(0,0x0001);
   addVariable(new Variable("AsicPpbe", Variable::Configuration));
   getVariable("AsicPpbe")->setDescription("ASIC Ppbe Signal");
   getVariable("AsicPpbe")->setRange(0,0x0001);
   addVariable(new Variable("AsicRoClk", Variable::Configuration));
   getVariable("AsicRoClk")->setDescription("ASIC RO Clock Signal");
   getVariable("AsicRoClk")->setRange(0,0x0001);

   addRegister(new Register("AsicPinControl", baseAddress_ + addrSize*0x0000002A));

   addVariable(new Variable("AsicGRControl", Variable::Configuration));
   getVariable("AsicGRControl")->setDescription("Manual ASIC Global Reset Enabled");
   getVariable("AsicGRControl")->setRange(0,0x1);
   addVariable(new Variable("AsicAcqControl", Variable::Configuration));
   getVariable("AsicAcqControl")->setDescription("Manual ASIC Acq Enabled");
   getVariable("AsicAcqControl")->setRange(0,0x1);
   addVariable(new Variable("AsicR0Control", Variable::Configuration));
   getVariable("AsicR0Control")->setDescription("Manual ASIC R0 Enabled");
   getVariable("AsicR0Control")->setRange(0,0x1);
   addVariable(new Variable("AsicPpmatControl", Variable::Configuration));
   getVariable("AsicPpmatControl")->setDescription("Manual ASIC Ppmat Enabled");
   getVariable("AsicPpmatControl")->setRange(0,0x1);
   addVariable(new Variable("AsicPpbeControl", Variable::Configuration));
   getVariable("AsicPpbeControl")->setDescription("Manual ASIC Ppbe Enabled");
   getVariable("AsicPpbeControl")->setRange(0,0x1);
   addVariable(new Variable("AsicRoClkControl", Variable::Configuration));
   getVariable("AsicRoClkControl")->setDescription("Manual ASIC RO Clock Enabled");
   getVariable("AsicRoClkControl")->setRange(0,0x1);
   addVariable(new Variable("prepulseR0En", Variable::Configuration));
   getVariable("prepulseR0En")->setDescription("Prepulse R0 Enable");
   getVariable("prepulseR0En")->setRange(0,0x1);
   addVariable(new Variable("ADCTest", Variable::Configuration));
   getVariable("ADCTest")->setDescription("Enables manual test of ADC");
   getVariable("ADCTest")->setRange(0,0x1);
   addVariable(new Variable("TestPattern", Variable::Configuration));
   getVariable("TestPattern")->setDescription("Enables test pattern on data out");
   getVariable("TestPattern")->setRange(0,0x1);
   addVariable(new Variable("SyncMode", Variable::Configuration));
   getVariable("SyncMode")->setDescription("Use single ended Sync instead of SACI prep for readout");
   vector<string> syncMode;
   syncMode.resize(4);
   syncMode[0]  = "FixedLow";
   syncMode[1]  = "EndOfFrame";
   syncMode[2]  = "Adjustable";
   syncMode[3]  = "FixedHigh";
   getVariable("SyncMode")->setEnums(syncMode);
   
   addVariable(new Variable("AsicR0Mode", Variable::Configuration));
   getVariable("AsicR0Mode")->setDescription("0: time with R0 low minimized (ePix100p), 1: normal (ePix10k)");
   getVariable("AsicR0Mode")->setRange(0,0x1);
   
   //Old analog board slow ADC registers
   for (x=0; x < 8; x++) {
      tmp.str("");
      tmp << "AdcValue" << dec << setw(2) << setfill('0') << x;

      addRegister(new Register(tmp.str(), baseAddress_ + addrSize*(0x00000100 + x)));

      addVariable(new Variable(tmp.str(), Variable::Status));
      getVariable(tmp.str())->setDescription(tmp.str());
   }

   getVariable("AdcValue02")->setComp(0,2.5/4095.*3.0,0,"V (ana)");  //Analog Voltage
   getVariable("AdcValue03")->setComp(0,2.5/4095.*3.0,0,"V (dig)");  //Digital Voltage
   getVariable("AdcValue04")->setComp(0,-.0194,78.393,"C (ana)"); //ADC board temp
   getVariable("AdcValue06")->setComp(0,-.0154,43.973,"C (sb)"); //Strongback temp (standard 30k resistor)
   //getVariable("AdcValue06")->setComp(0,-0.009992,-27.94,"C (sb)"); //Strongback temp (special 1M resistor)
   getVariable("AdcValue07")->setComp(0,.0287,-23.5,"%RH"); //Relative humidity
   
   //New analog board slow ADC registers
   for (x=0; x < 9; x++) {
      tmp.str("");
      tmp << "Adc2Value" << dec << setw(2) << setfill('0') << x;

      addRegister(new Register(tmp.str(), baseAddress_ + addrSize*(0x00000110 + x)));

      addVariable(new Variable(tmp.str(), Variable::Status));
      getVariable(tmp.str())->setDescription(tmp.str());
   }
   getVariable("Adc2Value00")->setComp(0,2.5/16777215/0.0000255,0,"Ohm (Th0)");              //Thermistor 0
   getVariable("Adc2Value01")->setComp(0,2.5/16777215/0.0000255,0,"Ohm (Th1)");              //Thermistor 1
   getVariable("Adc2Value02")->setComp(0,.0000156/2.0,-23.8,"%RH");            //Humidity
   getVariable("Adc2Value03")->setComp(0,.0012682/2.0,0,"mA (2.5AV)");         //ASIC analog current
   getVariable("Adc2Value04")->setComp(0,.0006341/2.0,0,"mA (2.5DV)");         //ASIC digital current
   getVariable("Adc2Value05")->setComp(0,2.5/16777215,0,"mA (Iguard)");    //Vguard current
   getVariable("Adc2Value06")->setComp(0,5.0/16777215,0,"mA (Ibias)");    //Vbias current
   getVariable("Adc2Value07")->setComp(0,2.5/16777215.*3.0,0,"V (AVin)"); //Analog raw voltage
   getVariable("Adc2Value08")->setComp(0,2.5/16777215.*3.0,0,"V (DVin)"); //Digital raw voltage
   
   addRegister(new Register("EnvData00", baseAddress_ + addrSize*0x00000140));
   addVariable(new Variable("EnvData00", Variable::Status));
   getVariable("EnvData00")->setDescription("Thermistor0 temperature");
   getVariable("EnvData00")->setComp(0,.01,0,"C");
   
   addRegister(new Register("EnvData01", baseAddress_ + addrSize*0x00000141));
   addVariable(new Variable("EnvData01", Variable::Status));
   getVariable("EnvData01")->setDescription("Thermistor1 temperature");
   getVariable("EnvData01")->setComp(0,.01,0,"C");
   
   addRegister(new Register("EnvData02", baseAddress_ + addrSize*0x00000142));
   addVariable(new Variable("EnvData02", Variable::Status));
   getVariable("EnvData02")->setDescription("Humidity");
   getVariable("EnvData02")->setComp(0,.01,0,"%RH");
   
   addRegister(new Register("EnvData03", baseAddress_ + addrSize*0x00000143));
   addVariable(new Variable("EnvData03", Variable::Status));
   getVariable("EnvData03")->setDescription("ASIC analog current");
   getVariable("EnvData03")->setComp(0,1.0,0,"mA");
   
   addRegister(new Register("EnvData04", baseAddress_ + addrSize*0x00000144));
   addVariable(new Variable("EnvData04", Variable::Status));
   getVariable("EnvData04")->setDescription("ASIC digital current");
   getVariable("EnvData04")->setComp(0,1.0,0,"mA");
   
   addRegister(new Register("EnvData05", baseAddress_ + addrSize*0x00000145));
   addVariable(new Variable("EnvData05", Variable::Status));
   getVariable("EnvData05")->setDescription("Guard ring current");
   getVariable("EnvData05")->setComp(0,.001,0,"mA");
   
   addRegister(new Register("EnvData06", baseAddress_ + addrSize*0x00000146));
   addVariable(new Variable("EnvData06", Variable::Status));
   getVariable("EnvData06")->setDescription("Detector bias current");
   getVariable("EnvData06")->setComp(0,.001,0,"mA");
   
   addRegister(new Register("EnvData07", baseAddress_ + addrSize*0x00000147));
   addVariable(new Variable("EnvData07", Variable::Status));
   getVariable("EnvData07")->setDescription("Analog raw input voltage");
   getVariable("EnvData07")->setComp(0,.001,0,"V");
   
   addRegister(new Register("EnvData08", baseAddress_ + addrSize*0x00000148));
   addVariable(new Variable("EnvData08", Variable::Status));
   getVariable("EnvData08")->setDescription("Digital raw input voltage");
   getVariable("EnvData08")->setComp(0,.001,0,"V");
   
   // software calculated humidity on the cold side
   addVariable(new Variable("EnvData09", Variable::Status));
   getVariable("EnvData09")->setDescription("Recalculated humidity on the cold side");
   getVariable("EnvData09")->setComp(0,.01,0,"%RH");

   addRegister(new Register("StrongbackTemp", baseAddress_ + addrSize*0x00000106));
   addVariable(new Variable("StrongbackTemp", Variable::Status));
   getVariable("StrongbackTemp")->setDescription("Strongback temp in degrees C");

   addRegister(new Register("Humidity", baseAddress_ + addrSize*0x00000107));
   addVariable(new Variable("Humidity", Variable::Status));
   getVariable("Humidity")->setDescription("Humidity in percent RH");

   addRegister(new Register("doutPipelineDelay", baseAddress_ + addrSize*0x0000001F));
   addVariable(new Variable("doutPipelineDelay", Variable::Configuration));
   getVariable("doutPipelineDelay")->setDescription("Number of clock cycles to delay ASIC digital output bit");
   getVariable("doutPipelineDelay")->setRange(0,0xFF);

   addRegister(new Register("acqToAsicR0Delay", baseAddress_ + addrSize*0x00000020)); 
   addVariable(new Variable("acqToAsicR0Delay", Variable::Configuration));
   getVariable("acqToAsicR0Delay")->setDescription("");
   getVariable("acqToAsicR0Delay")->setRange(0,0x7FFFFFFF);
   getVariable("acqToAsicR0Delay")->setComp(0,CLOCK_PERIOD_IN_US,0,"us");

   addRegister(new Register("asicR0ToAsicAcq", baseAddress_ + addrSize*0x00000021));
   addVariable(new Variable("asicR0ToAsicAcq", Variable::Configuration));
   getVariable("asicR0ToAsicAcq")->setDescription("");
   getVariable("asicR0ToAsicAcq")->setRange(0,0x7FFFFFFF);
   getVariable("asicR0ToAsicAcq")->setComp(0,CLOCK_PERIOD_IN_US,0,"us");

   
   addRegister(new Register("asicAcqWidth", baseAddress_ + addrSize*0x00000022));
   addVariable(new Variable("asicAcqWidth", Variable::Configuration));
   getVariable("asicAcqWidth")->setDescription("");
   getVariable("asicAcqWidth")->setRange(0,0x7FFFFFFF);
   getVariable("asicAcqWidth")->setComp(0,CLOCK_PERIOD_IN_US,0,"us");

   addRegister(new Register("asicAcqLToPPmatL", baseAddress_ + addrSize*0x00000023));
   addVariable(new Variable("asicAcqLToPPmatL", Variable::Configuration));
   getVariable("asicAcqLToPPmatL")->setDescription("");
   getVariable("asicAcqLToPPmatL")->setRange(0,0x7FFFFFFF);
   getVariable("asicAcqLToPPmatL")->setComp(0,CLOCK_PERIOD_IN_US,0,"us");

   addRegister(new Register("asicRoClkHalfT", baseAddress_ + addrSize*0x00000024));
   addVariable(new Variable("asicRoClkHalfT", Variable::Configuration));
   getVariable("asicRoClkHalfT")->setDescription("");
   getVariable("asicRoClkHalfT")->setRange(0,0x7FFFFFFF);
//   getVariable("asicRoClkHalfT")->setComp(0,0,0,"MHz");

   addRegister(new Register("adcReadsPerPixel", baseAddress_ + addrSize*0x00000025));
   addVariable(new Variable("adcReadsPerPixel", Variable::Configuration));
   getVariable("adcReadsPerPixel")->setDescription("");
   getVariable("adcReadsPerPixel")->setRange(0,0x7FFFFFFF);

   addRegister(new Register("adcClkHalfT", baseAddress_ + addrSize*0x00000026));
   addVariable(new Variable("adcClkHalfT", Variable::Configuration));
   getVariable("adcClkHalfT")->setDescription("Half Period of ADC Clock");
   getVariable("adcClkHalfT")->setRange(0,0x7FFFFFFF);

   addRegister(new Register("totalPixelsToRead", baseAddress_ + addrSize*0x00000027));
   addVariable(new Variable("totalPixelsToRead", Variable::Configuration));
   getVariable("totalPixelsToRead")->setDescription("");
   getVariable("totalPixelsToRead")->setRange(0,0x7FFFFFFF);

   addRegister(new Register("saciClkBit", baseAddress_ + addrSize*0x00000028));
   addVariable(new Variable("saciClkBit", Variable::Configuration));
   getVariable("saciClkBit")->setDescription("100 MHz counter for SACI clock");
   getVariable("saciClkBit")->setRange(0,0x00FF);

   addRegister(new Register("asicR0Width", baseAddress_ + addrSize*0x0000002B));
   addVariable(new Variable("asicR0Width", Variable::Configuration));
   getVariable("asicR0Width")->setDescription("Width of R0 low pulse");
   getVariable("asicR0Width")->setRange(0,0x7FFFFFFF);
   getVariable("asicR0Width")->setComp(0,CLOCK_PERIOD_IN_US,0,"us");

   addRegister(new Register("adcPipelineDelay", baseAddress_ + addrSize*0x0000002C));
   addVariable(new Variable("adcPipelineDelay", Variable::Configuration));
   getVariable("adcPipelineDelay")->setDescription("Number of samples to delay ADC reads");
   getVariable("adcPipelineDelay")->setRange(0,0xFF);
   
   addRegister(new Register("adcPipelineDelayA0", baseAddress_ + addrSize*0x00000090));
   addVariable(new Variable("adcPipelineDelayA0", Variable::Configuration));
   getVariable("adcPipelineDelayA0")->setDescription("Number of samples to delay ADC reads of the ASIC0 channels");
   getVariable("adcPipelineDelayA0")->setRange(0,0xFF);
   
   addRegister(new Register("adcPipelineDelayA1", baseAddress_ + addrSize*0x00000091));
   addVariable(new Variable("adcPipelineDelayA1", Variable::Configuration));
   getVariable("adcPipelineDelayA1")->setDescription("Number of samples to delay ADC reads of the ASIC1 channels");
   getVariable("adcPipelineDelayA1")->setRange(0,0xFF);
   
   addRegister(new Register("adcPipelineDelayA2", baseAddress_ + addrSize*0x00000092));
   addVariable(new Variable("adcPipelineDelayA2", Variable::Configuration));
   getVariable("adcPipelineDelayA2")->setDescription("Number of samples to delay ADC reads of the ASIC2 channels");
   getVariable("adcPipelineDelayA2")->setRange(0,0xFF);
   
   addRegister(new Register("adcPipelineDelayA3", baseAddress_ + addrSize*0x00000093));
   addVariable(new Variable("adcPipelineDelayA3", Variable::Configuration));
   getVariable("adcPipelineDelayA3")->setDescription("Number of samples to delay ADC reads of the ASIC3 channels");
   getVariable("adcPipelineDelayA3")->setRange(0,0xFF);

   addRegister(new Register("syncSettings", baseAddress_ + addrSize*0x0000002D));
   addVariable(new Variable("syncWidth", Variable::Configuration));
   getVariable("syncWidth")->setDescription("Width of ASIC SYNC signal");
   getVariable("syncWidth")->setRange(0,0x7FFFFFFF);
   addVariable(new Variable("syncDelay", Variable::Configuration));
   getVariable("syncDelay")->setDescription("Delay of ASIC SYNC signal");
   getVariable("syncDelay")->setRange(0,0x7FFFFFFF);

   addRegister(new Register("prepulseR0Width", baseAddress_ + addrSize*0x0000002E));
   addVariable(new Variable("prepulseR0Width", Variable::Configuration));
   getVariable("prepulseR0Width")->setDescription("Width of R0 low prepulse");
   getVariable("prepulseR0Width")->setRange(0,0x7FFFFFFF);
   getVariable("prepulseR0Width")->setComp(0,CLOCK_PERIOD_IN_US,0,"us");

   addRegister(new Register("prepulseR0Delay", baseAddress_ + addrSize*0x0000002F));
   addVariable(new Variable("prepulseR0Delay", Variable::Configuration));
   getVariable("prepulseR0Delay")->setDescription("Delay of R0 low prepulse");
   getVariable("prepulseR0Delay")->setRange(0,0x7FFFFFFF);
   getVariable("prepulseR0Delay")->setComp(0,CLOCK_PERIOD_IN_US,0,"us");

   addRegister(new Register("asicPPmatToReadout", baseAddress_ + addrSize*0x0000003A));
   addVariable(new Variable("asicPPmatToReadout", Variable::Configuration));
   getVariable("asicPPmatToReadout")->setDescription("");
   getVariable("asicPPmatToReadout")->setRange(0,0x7FFFFFFF);
   getVariable("asicPPmatToReadout")->setComp(0,CLOCK_PERIOD_IN_US,0,"us");

   addRegister(new Register("tpsTiming", baseAddress_ + addrSize*0x00000040));
   addVariable(new Variable("tpsEdge", Variable::Configuration));
   getVariable("tpsEdge")->setDescription("Sync TPS to rising or falling edge of Acq");
   getVariable("tpsEdge")->setTrueFalse();
   addVariable(new Variable("tpsDelay", Variable::Configuration));
   getVariable("tpsDelay")->setDescription("Delay TPS signal");
   getVariable("tpsDelay")->setRange(0,0xFFFF);

   addRegister(new Register("digitalCardId0",baseAddress_ + addrSize*0x00000030));
   addRegister(new Register("digitalCardId1",baseAddress_ + addrSize*0x00000031));
   addVariable(new Variable("digitalCardId0", Variable::Status));
   addVariable(new Variable("digitalCardId1", Variable::Status));
   getVariable("digitalCardId0")->setDescription("Digital Card Serial Number (low 32 bits)");
   getVariable("digitalCardId1")->setDescription("Digital Card Serial Number (high 32 bits)");

   addRegister(new Register("analogCardId0",baseAddress_ + addrSize*0x00000032));
   addRegister(new Register("analogCardId1",baseAddress_ + addrSize*0x00000033));
   addVariable(new Variable("analogCardId0", Variable::Status));
   addVariable(new Variable("analogCardId1", Variable::Status));
   getVariable("analogCardId0")->setDescription("Analog Card Serial Number (low 32 bits)");
   getVariable("analogCardId1")->setDescription("Analog Card Serial Number (high 32 bits)");

   addRegister(new Register("carrierCardId0",baseAddress_ + addrSize*0x0000003B));
   addRegister(new Register("carrierCardId1",baseAddress_ + addrSize*0x0000003C));
   addVariable(new Variable("carrierCardId0", Variable::Status));
   addVariable(new Variable("carrierCardId1", Variable::Status));
   getVariable("carrierCardId0")->setDescription("Carrier Card Serial Number (low 32 bits)");
   getVariable("carrierCardId1")->setDescription("Carrier Card Serial Number (high 32 bits)");
   
   addRegister(new Register("pgpTrigEn", baseAddress_ + addrSize*0x0000003D));
   addVariable(new Variable("pgpTrigEn", Variable::Configuration));
   getVariable("pgpTrigEn")->setDescription("Set to enable triggering over PGP. Disables the TTL trigger input.");
   getVariable("pgpTrigEn")->setTrueFalse();
   
   addRegister(new Register("monStreamEn", baseAddress_ + addrSize*0x0000003E));
   addVariable(new Variable("monStreamEn", Variable::Configuration));
   getVariable("monStreamEn")->setDescription("Set to enable monitor data stream over PGP.");
   getVariable("monStreamEn")->setTrueFalse();
  
   addVariable(new Variable("analogCRC", Variable::Status)); 
   getVariable("analogCRC")->setTrueFalse();
   addVariable(new Variable("digitalCRC", Variable::Status)); 
   getVariable("digitalCRC")->setTrueFalse();
   addVariable(new Variable("carrierCRC", Variable::Status)); 
   getVariable("carrierCRC")->setTrueFalse();

   addRegister(new Register("EepromWriteAddr", baseAddress_ + addrSize*0x00000034));
   addVariable(new Variable("EepromWriteAddr", Variable::Configuration));
   getVariable("EepromWriteAddr")->setRange(0,0xF);
   addRegister(new Register("EepromDataIn0", baseAddress_ + addrSize*0x00000035));
   addVariable(new Variable("EepromDataIn0", Variable::Configuration));
   addRegister(new Register("EepromDataIn1", baseAddress_ + addrSize*0x00000036));
   addVariable(new Variable("EepromDataIn1", Variable::Configuration));
   addRegister(new Register("EepromReadAddr", baseAddress_ + addrSize*0x00000037));
   addVariable(new Variable("EepromReadAddr", Variable::Configuration));
   addVariable(new Variable("EepromAddr", Variable::Status));
	getVariable("EepromReadAddr")->setRange(0,0xF);
   addRegister(new Register("EepromDataOut0", baseAddress_ + addrSize*0x00000038));
   addVariable(new Variable("EepromDataOut0", Variable::Status));
	addRegister(new Register("EepromDataOut1", baseAddress_ + addrSize*0x00000039));
   addVariable(new Variable("EepromDataOut1", Variable::Status));  
   addCommand(new Command("MasterReset"));
   getCommand("MasterReset")->setDescription("Master Board Reset");

   addCommand(new Command("AcqCountReset"));
   getCommand("AcqCountReset")->setDescription("Acquisition Count Reset");

   addCommand(new Command("SeqCountReset"));
   getCommand("SeqCountReset")->setDescription("Sequence (frame) Count Reset");

   addCommand(new Command("EpixRun",0x0));
   getCommand("EpixRun")->setDescription("Sends a single software run command");

   addCommand(new Command("WriteData"));
   getCommand("WriteData")->setDescription("Write data to EEPROM");

   addCommand(new Command("ReadData"));
   getCommand("ReadData")->setDescription("Read data from EEPROM");
   
   addVariable(new Variable("ClearMatrixEnabled", Variable::Configuration));
   getVariable("ClearMatrixEnabled")->setTrueFalse();
   getVariable("ClearMatrixEnabled")->setDescription("Enable ClearMatrix command");
   addCommand(new Command("ClearMatrix"));
   getCommand("ClearMatrix")->setDescription("Clear configuration bits of all pixels in all ASICs");

   // Add sub-devices
   addDevice(new   PseudoScope(destination, baseAddress_ + 0x00000000*addrSize, 0, this, addrSize));
   addDevice(new   Ad9252(destination, baseAddress_ + 0x00008000*addrSize, 0, this, addrSize));
   addDevice(new   Ad9252(destination, baseAddress_ + 0x0000A000*addrSize, 1, this, addrSize));
   addDevice(new   Ad9252(destination, baseAddress_ + 0x0000C000*addrSize, 2, this, addrSize));
   if (epixType == EPIX100P) {
      addDevice(new Epix100pAsic(destination, baseAddress_ + 0x00800000*addrSize, 0, this, addrSize));
      addDevice(new Epix100pAsic(destination, baseAddress_ + 0x00900000*addrSize, 1, this, addrSize));
      addDevice(new Epix100pAsic(destination, baseAddress_ + 0x00A00000*addrSize, 2, this, addrSize));
      addDevice(new Epix100pAsic(destination, baseAddress_ + 0x00B00000*addrSize, 3, this, addrSize));
   } else if (epixType == EPIX100A) {
      addDevice(new Epix100aAsic(destination, baseAddress_ + 0x00800000*addrSize, 0, this, addrSize));
      addDevice(new Epix100aAsic(destination, baseAddress_ + 0x00900000*addrSize, 1, this, addrSize));
      addDevice(new Epix100aAsic(destination, baseAddress_ + 0x00A00000*addrSize, 2, this, addrSize));
      addDevice(new Epix100aAsic(destination, baseAddress_ + 0x00B00000*addrSize, 3, this, addrSize));
   } else if (epixType == EPIX10KP) {
      addDevice(new Epix10kpAsic(destination, baseAddress_ + 0x00800000*addrSize, 0, this, addrSize));
      addDevice(new Epix10kpAsic(destination, baseAddress_ + 0x00900000*addrSize, 1, this, addrSize));
      addDevice(new Epix10kpAsic(destination, baseAddress_ + 0x00A00000*addrSize, 2, this, addrSize));
      addDevice(new Epix10kpAsic(destination, baseAddress_ + 0x00B00000*addrSize, 3, this, addrSize));
   } else if (epixType == EPIXS) {
      addDevice(new EpixSAsic(destination, baseAddress_ + 0x00800000*addrSize, 0, this, addrSize));
      addDevice(new EpixSAsic(destination, baseAddress_ + 0x00900000*addrSize, 1, this, addrSize));
      addDevice(new EpixSAsic(destination, baseAddress_ + 0x00A00000*addrSize, 2, this, addrSize));
      addDevice(new EpixSAsic(destination, baseAddress_ + 0x00B00000*addrSize, 3, this, addrSize));
   } else if (epixType == CPIXP) {
      addDevice(new CpixPAsic(destination, baseAddress_ + 0x00800000*addrSize, 0, this, addrSize));
      addDevice(new CpixPAsic(destination, baseAddress_ + 0x00900000*addrSize, 1, this, addrSize));
      //CPIX specific FPGA registers
      addDevice(new DigFpgaCpix(destination, baseAddress_ + 0x01000000*addrSize, 0, this, addrSize));
   } else if (epixType == TIXELP) {
      addDevice(new TixelPAsic(destination, baseAddress_ + 0x00800000*addrSize, 0, this, addrSize));
      addDevice(new TixelPAsic(destination, baseAddress_ + 0x00900000*addrSize, 1, this, addrSize));
      //CPIX specific FPGA registers
      addDevice(new DigFpgaTixel(destination, baseAddress_ + 0x01000000*addrSize, 0, this, addrSize));
   }

   getVariable("Enabled")->setHidden(true);
}

// Deconstructor
DigFpga::~DigFpga ( ) { }

// Method to process a command
void DigFpga::command ( string name, string arg) {
   stringstream tmp;

   // Command is local
   if ( name == "ClearMatrix" ) {
      if (epixType_ == EPIX100A) {
         if (getVariable("ClearMatrixEnabled")->getInt()) {
            device("epix100aAsic",0)->command("ClearMatrix","");
            device("epix100aAsic",1)->command("ClearMatrix","");
            device("epix100aAsic",2)->command("ClearMatrix","");
            device("epix100aAsic",3)->command("ClearMatrix","");
         }
      }
   }
   else if ( name == "MasterReset" ) {
      REGISTER_LOCK
      writeRegister(getRegister("Version"),true,false);
      REGISTER_UNLOCK
   }
   else if ( name == "AcqCountReset" ) {
      REGISTER_LOCK
      writeRegister(getRegister("AcqCountReset"),true,true);
      REGISTER_UNLOCK
   }
   else if ( name == "SeqCountReset" ) {
      REGISTER_LOCK
      writeRegister(getRegister("SeqCountReset"),true,true);
      REGISTER_UNLOCK
   }
   else if ( name == "WriteData" ) {
      REGISTER_LOCK
      writeRegister(getRegister("EepromDataIn0"),true,true);
      writeRegister(getRegister("EepromDataIn1"),true,true);
      writeRegister(getRegister("EepromWriteAddr"),true,true);
      REGISTER_UNLOCK
   }
   else if ( name == "ReadData" ) {
      REGISTER_LOCK
      writeRegister(getRegister("EepromReadAddr"),true,true);
      getVariable("EepromAddr")->setInt(getRegister("EepromReadAddr")->get()/8);
   	//readRegister(getRegister("EepromDataOut0"));
	   //readRegister(getRegister("EepromDataOut1"));
	   //getVariable("EepromDataOut0")->setInt(getRegister("EepromDataOut0")->get());
		//getVariable("EepromDataOut1")->setInt(getRegister("EepromDataOut1")->get());
      REGISTER_UNLOCK
   }
   
   else Device::command(name, arg);
}

// Method to read status registers and update variables
void DigFpga::readStatus ( ) {
   stringstream tmp;
   uint         x;

   REGISTER_LOCK

   readRegister(getRegister("Version"));
   getVariable("Version")->setInt(getRegister("Version")->get());

   readRegister(getRegister("BaseClock"));
   getVariable("BaseClock")->setInt(getRegister("BaseClock")->get());

   readRegister(getRegister("AcqCount"));
   getVariable("AcqCount")->setInt(getRegister("AcqCount")->get());

   readRegister(getRegister("SeqCount"));
   getVariable("SeqCount")->setInt(getRegister("SeqCount")->get());

   readRegister(getRegister("IDelayCtrlRdy"));
   getVariable("IDelayCtrlRdy")->setInt(getRegister("IDelayCtrlRdy")->get());

   readRegister(getRegister("Startup"));
   getVariable("StartupDone")->setInt(getRegister("Startup")->get(1,0x1));
   getVariable("StartupFail")->setInt(getRegister("Startup")->get(2,0x1));

   for (x=0; x < 8; x++) {
      tmp.str("");
      tmp << "AdcValue" << dec << setw(2) << setfill('0') << x;

      readRegister(getRegister(tmp.str()));
      getVariable(tmp.str())->setInt(getRegister(tmp.str())->get());
   }
   
   for (x=0; x < 9; x++) {
      tmp.str("");
      tmp << "Adc2Value" << dec << setw(2) << setfill('0') << x;

      readRegister(getRegister(tmp.str()));
      getVariable(tmp.str())->setInt(getRegister(tmp.str())->get());
   }
   
   for (x=0; x < 9; x++) {
      tmp.str("");
      tmp << "EnvData" << dec << setw(2) << setfill('0') << x;

      readRegister(getRegister(tmp.str()));
      getVariable(tmp.str())->setInt(getRegister(tmp.str())->get());
   }
   
   // software calculated humidity on the cold side
   double b=17.62;
   double c=243.12;
   double T1 = ((signed int)getRegister("EnvData01")->get())*0.01;
   double T2 = ((signed int)getRegister("EnvData00")->get())*0.01;
   double RH1 = (getRegister("EnvData02")->get())*0.0001;
   double RH2 = RH1 * exp( b*c * (T1-T2) / ((c+T1)*(c+T2)) );
   getVariable("EnvData09")->setInt((int)(RH2*10000.0));
   

   bool temp;
   readRegister(getRegister("digitalCardId0"));
   getVariable("digitalCardId0")->setInt(getRegister("digitalCardId0")->get());
   readRegister(getRegister("digitalCardId1"));
   getVariable("digitalCardId1")->setInt(getRegister("digitalCardId1")->get());
   temp = crc(getVariable("digitalCardId1")->getInt(),getVariable("digitalCardId0")->getInt());
   getVariable("digitalCRC")->setInt(temp);

   readRegister(getRegister("analogCardId0"));
   getVariable("analogCardId0")->setInt(getRegister("analogCardId0")->get());
   readRegister(getRegister("analogCardId1"));
   getVariable("analogCardId1")->setInt(getRegister("analogCardId1")->get());
   temp = crc(getVariable("analogCardId1")->getInt(),getVariable("analogCardId0")->getInt());
   getVariable("analogCRC")->setInt(temp);

   readRegister(getRegister("carrierCardId0"));
   getVariable("carrierCardId0")->setInt(getRegister("carrierCardId0")->get());
   readRegister(getRegister("carrierCardId1"));
   getVariable("carrierCardId1")->setInt(getRegister("carrierCardId1")->get());
   temp = crc(getVariable("carrierCardId1")->getInt(),getVariable("carrierCardId0")->getInt());
   getVariable("carrierCRC")->setInt(temp);
 

/*
   uint y;
   readRegister(getRegister("StrongbackTemp"));
   y=getRegister("StrongbackTemp")->get();
//   getVariable("StrongbackTemp")->setIntDec(.000006*y*y-.0489*y+112.26);
   static double cA = 3.3538646e-3;
   static double cB = 2.5654090e-4;
   static double cC = 1.9243889e-6;
   static double cD = 1.0969244e-7;
   static double cR25 = 10e3;
   static double cRdiv = 30e3; //Normal operation to -19 C
//   static double cRdiv = 1e6; //Special operation to -69 C
   static double cVref = 3.3;
   static double cVdac = 2.5;
   static double cMaxCnt = 4095.0;
   double Vtherm   = (double)y / cMaxCnt * cVdac;
   double res = cRdiv * Vtherm / (cVref - Vtherm);
   double rt_r25 = res / cR25;
   double log_rt_r25 = log(rt_r25);
   double Tinv = cA + cB * log_rt_r25 + cC * pow(log_rt_r25,2) + cD * pow(log_rt_r25,3);
//   Tinv = (1./Tinv) - 273.0;  //For reading in C
   Tinv = (1./Tinv); //For reading in K
   getVariable("StrongbackTemp")->setIntDec( (int) Tinv ); 
*/

   readRegister(getRegister("EepromDataOut0"));
   readRegister(getRegister("EepromDataOut1"));
   getVariable("EepromDataOut0")->setInt(getRegister("EepromDataOut0")->get());
getVariable("EepromDataOut1")->setInt(getRegister("EepromDataOut1")->get());
   // Sub devices
   REGISTER_UNLOCK
   Device::readStatus();
}

// Method to read configuration registers and update variables
void DigFpga::readConfig ( ) {
   stringstream tmp;
   uint x;

   REGISTER_LOCK

   readRegister(getRegister("RunTrigEnable"));
   getVariable("RunTrigEnable")->setInt(getRegister("RunTrigEnable")->get(0,0x1));

   readRegister(getRegister("AutoRunEnable"));
   getVariable("AutoRunEnable")->setInt(getRegister("AutoRunEnable")->get(0,0x1));

   readRegister(getRegister("RunTrigDelay"));
   getVariable("RunTrigDelay")->setInt(getRegister("RunTrigDelay")->get());

   readRegister(getRegister("AutoRunPeriod"));
   getVariable("AutoRunPeriod")->setInt(getRegister("AutoRunPeriod")->get());

   readRegister(getRegister("DaqTrigEnable"));
   getVariable("DaqTrigEnable")->setInt(getRegister("DaqTrigEnable")->get(0,0x1));

   readRegister(getRegister("AutoDaqEnable"));
   getVariable("AutoDaqEnable")->setInt(getRegister("AutoDaqEnable")->get(0,0x1));

   readRegister(getRegister("DaqTrigDelay"));
   getVariable("DaqTrigDelay")->setInt(getRegister("DaqTrigDelay")->get());

   readRegister(getRegister("DacSetting"));
   getVariable("DacSetting")->setInt(getRegister("DacSetting")->get(0,0xFFFF));

   readRegister(getRegister("asicMask"));
   getVariable("asicMask")->setInt(getRegister("asicMask")->get(0,0xF));

   readRegister(getRegister("PowerEnable"));
   getVariable("FpgaOutputEnable")->setInt(getRegister("PowerEnable")->get(2,0x1));
   getVariable("AnalogPowerEnable")->setInt(getRegister("PowerEnable")->get(1,0x1));
   getVariable("DigitalPowerEnable")->setInt(getRegister("PowerEnable")->get(0,0x1));

   for (x = 0; x < 3; ++x) {
      tmp.str("");
      tmp << "Adc" << dec << x << "FrameDelay";
      readRegister(getRegister(tmp.str()));
      getVariable(tmp.str())->setInt(getRegister(tmp.str())->get(0,0x3f));
   }
   for (x = 0; x < 8; ++x) {
      tmp.str("");
      tmp << "Adc0Ch" << dec << x << "Delay";
      readRegister(getRegister(tmp.str()));
      getVariable(tmp.str())->setInt(getRegister(tmp.str())->get(0,0x3f));
   }
   for (x = 0; x < 8; ++x) {
      tmp.str("");
      tmp << "Adc1Ch" << dec << x << "Delay";
      readRegister(getRegister(tmp.str()));
      getVariable(tmp.str())->setInt(getRegister(tmp.str())->get(0,0x3f));
   }
   for (x = 0; x < 4; ++x) {
      tmp.str("");
      tmp << "Adc2Ch" << dec << x << "Delay";
      readRegister(getRegister(tmp.str()));
      getVariable(tmp.str())->setInt(getRegister(tmp.str())->get(0,0x3f));
   }

   readRegister(getRegister("Startup"));
   getVariable("RequestStartup")->setInt(getRegister("Startup")->get(0,0x1));

   readRegister(getRegister("AsicPins"));
   getVariable("AsicGR")->setInt(getRegister("AsicPins")->get(0,0x1));
   getVariable("AsicAcq")->setInt(getRegister("AsicPins")->get(1,0x1));
   getVariable("AsicR0")->setInt(getRegister("AsicPins")->get(2,0x1));
   getVariable("AsicPpmat")->setInt(getRegister("AsicPins")->get(3,0x1));
   getVariable("AsicPpbe")->setInt(getRegister("AsicPins")->get(4,0x1));
   getVariable("AsicRoClk")->setInt(getRegister("AsicPins")->get(5,0x1));

   readRegister(getRegister("AsicPinControl"));
   getVariable("AsicGRControl")->setInt(getRegister("AsicPinControl")->get(0,0x1));
   getVariable("AsicAcqControl")->setInt(getRegister("AsicPinControl")->get(1,0x1));
   getVariable("AsicR0Control")->setInt(getRegister("AsicPinControl")->get(2,0x1));
   getVariable("AsicPpmatControl")->setInt(getRegister("AsicPinControl")->get(3,0x1));
   getVariable("AsicPpbeControl")->setInt(getRegister("AsicPinControl")->get(4,0x1));
   getVariable("AsicRoClkControl")->setInt(getRegister("AsicPinControl")->get(5,0x1));
   getVariable("prepulseR0En")->setInt(getRegister("AsicPinControl")->get(6,0x1));
   getVariable("ADCTest")->setInt(getRegister("AsicPinControl")->get(7,0x1));
   getVariable("TestPattern")->setInt(getRegister("AsicPinControl")->get(8,0x1));
   getVariable("SyncMode")->setInt(getRegister("AsicPinControl")->get(9,0x3));
   getVariable("AsicR0Mode")->setInt(getRegister("AsicPinControl")->get(11,0x1));

   readRegister(getRegister("acqToAsicR0Delay"));
   getVariable("acqToAsicR0Delay")->setInt(getRegister("acqToAsicR0Delay")->get());

   readRegister(getRegister("asicR0ToAsicAcq"));
   getVariable("asicR0ToAsicAcq")->setInt(getRegister("asicR0ToAsicAcq")->get());

   readRegister(getRegister("asicAcqWidth"));
   getVariable("asicAcqWidth")->setInt(getRegister("asicAcqWidth")->get());

   readRegister(getRegister("asicAcqLToPPmatL"));
   getVariable("asicAcqLToPPmatL")->setInt(getRegister("asicAcqLToPPmatL")->get());

   readRegister(getRegister("asicRoClkHalfT"));
   getVariable("asicRoClkHalfT")->setInt(getRegister("asicRoClkHalfT")->get());

   readRegister(getRegister("adcReadsPerPixel"));
   getVariable("adcReadsPerPixel")->setInt(getRegister("adcReadsPerPixel")->get());

   readRegister(getRegister("totalPixelsToRead"));
   getVariable("totalPixelsToRead")->setInt(getRegister("totalPixelsToRead")->get());
   readRegister(getRegister("adcClkHalfT"));
   getVariable("adcClkHalfT")->setInt(getRegister("adcClkHalfT")->get());

   getVariable("EepromReadAddr")->setInt(getRegister("EepromReadAddr")->get()/8);

   getVariable("EepromWriteAddr")->setInt(getRegister("EepromWriteAddr")->get()/8);

   getVariable("EepromDataIn0")->setInt(getRegister("EepromDataIn0")->get());

   getVariable("EepromDataIn1")->setInt(getRegister("EepromDataIn1")->get());

   readRegister(getRegister("saciClkBit"));
   getVariable("saciClkBit")->setInt(getRegister("saciClkBit")->get(0,0xff));

   readRegister(getRegister("asicR0Width"));
   getVariable("asicR0Width")->setInt(getRegister("asicR0Width")->get());

   readRegister(getRegister("adcPipelineDelay"));
   getVariable("adcPipelineDelay")->setInt(getRegister("adcPipelineDelay")->get(0,0xFF));
   
   readRegister(getRegister("adcPipelineDelayA0"));
   getVariable("adcPipelineDelayA0")->setInt(getRegister("adcPipelineDelayA0")->get(0,0xFF));
   
   readRegister(getRegister("adcPipelineDelayA1"));
   getVariable("adcPipelineDelayA1")->setInt(getRegister("adcPipelineDelayA1")->get(0,0xFF));
   
   readRegister(getRegister("adcPipelineDelayA2"));
   getVariable("adcPipelineDelayA2")->setInt(getRegister("adcPipelineDelayA2")->get(0,0xFF));
   
   readRegister(getRegister("adcPipelineDelayA3"));
   getVariable("adcPipelineDelayA3")->setInt(getRegister("adcPipelineDelayA3")->get(0,0xFF));

   readRegister(getRegister("doutPipelineDelay"));
   getVariable("doutPipelineDelay")->setInt(getRegister("doutPipelineDelay")->get(0,0xFF));

   readRegister(getRegister("syncSettings"));
   getVariable("syncWidth")->setInt(getRegister("syncSettings")->get(0,0xFFFF));
   getVariable("syncDelay")->setInt(getRegister("syncSettings")->get(16,0xFFFF));

   readRegister(getRegister("prepulseR0Width"));
   getVariable("prepulseR0Width")->setInt(getRegister("prepulseR0Width")->get(0,0xFFFF));

   readRegister(getRegister("prepulseR0Delay"));
   getVariable("prepulseR0Delay")->setInt(getRegister("prepulseR0Delay")->get(0,0xFFFF));
   
   readRegister(getRegister("asicPPmatToReadout"));
   getVariable("asicPPmatToReadout")->setInt(getRegister("asicPPmatToReadout")->get(0,0xFFFF));

   readRegister(getRegister("tpsTiming"));
   getVariable("tpsDelay")->setInt(getRegister("tpsTiming")->get(0,0xFFFF));
   getVariable("tpsEdge")->setInt(getRegister("tpsTiming")->get(16,0x1));
   
   readRegister(getRegister("pgpTrigEn"));
   getVariable("pgpTrigEn")->setInt(getRegister("pgpTrigEn")->get(0,0x1));
   
   readRegister(getRegister("monStreamEn"));
   getVariable("monStreamEn")->setInt(getRegister("monStreamEn")->get(0,0x1));
   
   
   
 // Sub devices
   REGISTER_UNLOCK
   Device::readConfig();
}

// Method to write configuration registers
void DigFpga::writeConfig ( bool force ) {
   stringstream tmp;
   uint x;

   REGISTER_LOCK

   getRegister("DacSetting")->set(getVariable("DacSetting")->getInt(),0,0xFFFF);
   writeRegister(getRegister("DacSetting"),force);
   
   getRegister("asicMask")->set(getVariable("asicMask")->getInt(),0,0xF);
   writeRegister(getRegister("asicMask"),force);

   getRegister("PowerEnable")->set(getVariable("FpgaOutputEnable")->getInt(),2,0x1);
   getRegister("PowerEnable")->set(getVariable("AnalogPowerEnable")->getInt(),1,0x1);
   getRegister("PowerEnable")->set(getVariable("DigitalPowerEnable")->getInt(),0,0x1);
   writeRegister(getRegister("PowerEnable"),force);

   for (x = 0; x < 3; ++x) {
      tmp.str("");
      tmp << "Adc" << dec << x << "FrameDelay";
      getRegister(tmp.str())->set(getVariable(tmp.str())->getInt(),0,0x3F);
      writeRegister(getRegister(tmp.str()),force);
   }
   for (x = 0; x < 8; ++x) {
      tmp.str("");
      tmp << "Adc0Ch" << dec << x << "Delay";
      getRegister(tmp.str())->set(getVariable(tmp.str())->getInt(),0,0x3F);
      writeRegister(getRegister(tmp.str()),force);
   }
   for (x = 0; x < 8; ++x) {
      tmp.str("");
      tmp << "Adc1Ch" << dec << x << "Delay";
      getRegister(tmp.str())->set(getVariable(tmp.str())->getInt(),0,0x3F);
      writeRegister(getRegister(tmp.str()),force);
   }
   for (x = 0; x < 4; ++x) {
      tmp.str("");
      tmp << "Adc2Ch" << dec << x << "Delay";
      getRegister(tmp.str())->set(getVariable(tmp.str())->getInt(),0,0x3F);
      writeRegister(getRegister(tmp.str()),force);
   }

   getRegister("Startup")->set(getVariable("RequestStartup")->getInt(),0,0x1);
   writeRegister(getRegister("Startup"),force);

   getRegister("AsicPins")->set(getVariable("AsicGR")->getInt(),0,0x1);
   getRegister("AsicPins")->set(getVariable("AsicAcq")->getInt(),1,0x1);
   getRegister("AsicPins")->set(getVariable("AsicR0")->getInt(),2,0x1);
   getRegister("AsicPins")->set(getVariable("AsicPpmat")->getInt(),3,0x1);
   getRegister("AsicPins")->set(getVariable("AsicPpbe")->getInt(),4,0x1);
   getRegister("AsicPins")->set(getVariable("AsicRoClk")->getInt(),5,0x1);
   writeRegister(getRegister("AsicPins"),force);

   getRegister("AsicPinControl")->set(getVariable("AsicGRControl")->getInt(),0,0x1);
   getRegister("AsicPinControl")->set(getVariable("AsicAcqControl")->getInt(),1,0x1);
   getRegister("AsicPinControl")->set(getVariable("AsicR0Control")->getInt(),2,0x1);
   getRegister("AsicPinControl")->set(getVariable("AsicPpmatControl")->getInt(),3,0x1);
   getRegister("AsicPinControl")->set(getVariable("AsicPpbeControl")->getInt(),4,0x1);
   getRegister("AsicPinControl")->set(getVariable("AsicRoClkControl")->getInt(),5,0x1);
   getRegister("AsicPinControl")->set(getVariable("prepulseR0En")->getInt(),6,0x1);
   getRegister("AsicPinControl")->set(getVariable("ADCTest")->getInt(),7,0x1);
   getRegister("AsicPinControl")->set(getVariable("TestPattern")->getInt(),8,0x1);
   getRegister("AsicPinControl")->set(getVariable("SyncMode")->getInt(),9,0x3);
   getRegister("AsicPinControl")->set(getVariable("AsicR0Mode")->getInt(),11,0x1);
   writeRegister(getRegister("AsicPinControl"),force);

   getRegister("acqToAsicR0Delay")->set(getVariable("acqToAsicR0Delay")->getInt());
   writeRegister(getRegister("acqToAsicR0Delay"),force);

   getRegister("asicR0ToAsicAcq")->set(getVariable("asicR0ToAsicAcq")->getInt());
   writeRegister(getRegister("asicR0ToAsicAcq"),force);

   getRegister("asicAcqWidth")->set(getVariable("asicAcqWidth")->getInt());
   writeRegister(getRegister("asicAcqWidth"),force);

   getRegister("asicRoClkHalfT")->set(getVariable("asicRoClkHalfT")->getInt());
   writeRegister(getRegister("asicRoClkHalfT"),force);

   getRegister("asicAcqLToPPmatL")->set(getVariable("asicAcqLToPPmatL")->getInt());
   writeRegister(getRegister("asicAcqLToPPmatL"),force);

   getRegister("asicRoClkHalfT")->set(getVariable("asicRoClkHalfT")->getInt());
   writeRegister(getRegister("asicRoClkHalfT"),force);

   getRegister("totalPixelsToRead")->set(getVariable("totalPixelsToRead")->getInt());
   writeRegister(getRegister("totalPixelsToRead"),force);

   getRegister("adcReadsPerPixel")->set(getVariable("adcReadsPerPixel")->getInt());
   writeRegister(getRegister("adcReadsPerPixel"),force);

   getRegister("adcClkHalfT")->set(getVariable("adcClkHalfT")->getInt());
   writeRegister(getRegister("adcClkHalfT"),force);

   getRegister("EepromReadAddr")->set(8*getVariable("EepromReadAddr")->getInt());

   getRegister("EepromWriteAddr")->set(8*getVariable("EepromWriteAddr")->getInt());

   getRegister("EepromDataIn0")->set(getVariable("EepromDataIn0")->getInt());
  
   getRegister("EepromDataIn1")->set(getVariable("EepromDataIn1")->getInt());

   getRegister("saciClkBit")->set(getVariable("saciClkBit")->getInt(),0,0xff);
   writeRegister(getRegister("saciClkBit"),force);

   getRegister("asicR0Width")->set(getVariable("asicR0Width")->getInt());
   writeRegister(getRegister("asicR0Width"),force);

   getRegister("adcPipelineDelay")->set(getVariable("adcPipelineDelay")->getInt(),0,0xFF);
   writeRegister(getRegister("adcPipelineDelay"),force);
   
   getRegister("adcPipelineDelayA0")->set(getVariable("adcPipelineDelayA0")->getInt(),0,0xFF);
   writeRegister(getRegister("adcPipelineDelayA0"),force);
   
   getRegister("adcPipelineDelayA1")->set(getVariable("adcPipelineDelayA1")->getInt(),0,0xFF);
   writeRegister(getRegister("adcPipelineDelayA1"),force);
   
   getRegister("adcPipelineDelayA2")->set(getVariable("adcPipelineDelayA2")->getInt(),0,0xFF);
   writeRegister(getRegister("adcPipelineDelayA2"),force);
   
   getRegister("adcPipelineDelayA3")->set(getVariable("adcPipelineDelayA3")->getInt(),0,0xFF);
   writeRegister(getRegister("adcPipelineDelayA3"),force);

   getRegister("doutPipelineDelay")->set(getVariable("doutPipelineDelay")->getInt(),0,0xFF);
   writeRegister(getRegister("doutPipelineDelay"),force);

   getRegister("syncSettings")->set(getVariable("syncWidth")->getInt(),0,0xFFFF);
   getRegister("syncSettings")->set(getVariable("syncDelay")->getInt(),16,0xFFFF);
   writeRegister(getRegister("syncSettings"),force);

   getRegister("prepulseR0Width")->set(getVariable("prepulseR0Width")->getInt());
   writeRegister(getRegister("prepulseR0Width"),force);

   getRegister("prepulseR0Delay")->set(getVariable("prepulseR0Delay")->getInt());
   writeRegister(getRegister("prepulseR0Delay"),force);

   getRegister("asicPPmatToReadout")->set(getVariable("asicPPmatToReadout")->getInt());
   writeRegister(getRegister("asicPPmatToReadout"),force);

   getRegister("tpsTiming")->set(getVariable("tpsDelay")->getInt(),0,0xFFFF);
   getRegister("tpsTiming")->set(getVariable("tpsEdge")->getInt(),16,0x1);
   writeRegister(getRegister("tpsTiming"),force);
   
   getRegister("pgpTrigEn")->set(getVariable("pgpTrigEn")->getInt());
   writeRegister(getRegister("pgpTrigEn"),force);
   
   getRegister("monStreamEn")->set(getVariable("monStreamEn")->getInt());
   writeRegister(getRegister("monStreamEn"),force);
   

   //Trigger enables here so that all other registers are set before we start
   getRegister("RunTrigDelay")->set(getVariable("RunTrigDelay")->getInt());
   writeRegister(getRegister("RunTrigDelay"),force);

   getRegister("DaqTrigDelay")->set(getVariable("DaqTrigDelay")->getInt());
   writeRegister(getRegister("DaqTrigDelay"),force);

   getRegister("RunTrigEnable")->set(getVariable("RunTrigEnable")->getInt(),0,0x1);
   writeRegister(getRegister("RunTrigEnable"),force);

   getRegister("DaqTrigEnable")->set(getVariable("DaqTrigEnable")->getInt(),0,0x1);
   writeRegister(getRegister("DaqTrigEnable"),force);

   //Auto trigger settings
   getRegister("AutoRunPeriod")->set(getVariable("AutoRunPeriod")->getInt());
   writeRegister(getRegister("AutoRunPeriod"),force);

   getRegister("AutoRunEnable")->set(getVariable("AutoRunEnable")->getInt(),0,0x1);
   writeRegister(getRegister("AutoRunEnable"),force);

   getRegister("AutoDaqEnable")->set(getVariable("AutoDaqEnable")->getInt(),0,0x1);
   writeRegister(getRegister("AutoDaqEnable"),force);


  // Sub devices
   REGISTER_UNLOCK
   Device::writeConfig(force);
}

// Verify hardware state of configuration
void DigFpga::verifyConfig ( ) {
   REGISTER_LOCK

   verifyRegister(getRegister("RunTrigEnable"));
   verifyRegister(getRegister("RunTrigDelay"));
   verifyRegister(getRegister("DaqTrigEnable"));
   verifyRegister(getRegister("DaqTrigDelay"));
   verifyRegister(getRegister("asicMask"));
   verifyRegister(getRegister("DacSetting"));
   verifyRegister(getRegister("PowerEnable"));
//   verifyRegister(getRegister("AdcFrameDelay"));
   verifyRegister(getRegister("AsicPins"));
   verifyRegister(getRegister("AsicPinControl"));
   verifyRegister(getRegister("doutPipelineDelay"));
   verifyRegister(getRegister("acqToAsicR0Delay"));
   verifyRegister(getRegister("asicR0ToAsicAcq"));
   verifyRegister(getRegister("asicAcqWidth"));
   verifyRegister(getRegister("asicAcqLToPPmatL"));
   verifyRegister(getRegister("asicRoClkHalfT"));
   verifyRegister(getRegister("adcReadsPerPixel"));
   verifyRegister(getRegister("adcClkHalfT"));
   verifyRegister(getRegister("totalPixelsToRead"));
   verifyRegister(getRegister("saciClkBit"));
   verifyRegister(getRegister("asicR0Width"));
   verifyRegister(getRegister("adcPipelineDelay"));
   verifyRegister(getRegister("adcPipelineDelayA0"));
   verifyRegister(getRegister("adcPipelineDelayA1"));
   verifyRegister(getRegister("adcPipelineDelayA2"));
   verifyRegister(getRegister("adcPipelineDelayA3"));
   verifyRegister(getRegister("syncSettings"));
   verifyRegister(getRegister("prepulseR0Width"));
   verifyRegister(getRegister("prepulseR0Delay"));
   verifyRegister(getRegister("asicPPmatToReadout"));
   verifyRegister(getRegister("pgpTrigEn"));
   verifyRegister(getRegister("monStreamEn"));
   REGISTER_UNLOCK
   Device::verifyConfig();
}

