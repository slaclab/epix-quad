//-----------------------------------------------------------------------------
// File          : TixelPAsic.cpp
// Author        : Maciej Kwiatkowski  <mkwiatko@slac.stanford.edu>
// Created       : 06/06/2013
// Project       : TIXEL Prototype ASIC
//-----------------------------------------------------------------------------
// Description :
// Epix ASIC container
//-----------------------------------------------------------------------------
// Copyright (c) 2013 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 03/07/2016: created
//-----------------------------------------------------------------------------
#include <TixelPAsic.h>
#include <Register.h>
#include <Variable.h>
#include <Command.h>
#include <sstream>
#include <iostream>
#include <string>
#include <iomanip>
using namespace std;

// Constructor
TixelPAsic::TixelPAsic ( uint destination, uint baseAddress, uint index, Device *parent, uint addrSize ) : 
                     Device(destination,baseAddress,"TixelPAsic",index,parent) {

   // Description
   desc_    = "Tixel ASIC Object.";

   // ASIC Address Space
   // Addr[11:0]  = Address
   // Addr[18:12] = CMD
   // Addr[21:20] = Chip

   // CMD = 0, Addr = 0  : Prepare for readout
   addRegister(new Register("CmdPrepForRead", baseAddress_ + addrSize*0x00000000, 1));
   addCommand(new Command("PrepForRead"));
   getCommand("PrepForRead")->setDescription("Tixel Prepare For Readout");

   //Registers
   // CMD = 1, Addr = 1  to Addr = 16
   addRegister(new Register("Config1", baseAddress_ + addrSize*0x00001001, 1));
   addRegister(new Register("Config2", baseAddress_ + addrSize*0x00001002, 1));
   addRegister(new Register("Config3", baseAddress_ + addrSize*0x00001003, 1));
   addRegister(new Register("Config4", baseAddress_ + addrSize*0x00001004, 1));
   addRegister(new Register("Config5", baseAddress_ + addrSize*0x00001005, 1));
   addRegister(new Register("Config6", baseAddress_ + addrSize*0x00001006, 1));
   addRegister(new Register("Config7", baseAddress_ + addrSize*0x00001007, 1));
   addRegister(new Register("Config8", baseAddress_ + addrSize*0x00001008, 1));
   addRegister(new Register("Config9", baseAddress_ + addrSize*0x00001009, 1));
   addRegister(new Register("Config10", baseAddress_ + addrSize*0x0000100a, 1));
   addRegister(new Register("Config11", baseAddress_ + addrSize*0x0000100b, 1));
   addRegister(new Register("Config12", baseAddress_ + addrSize*0x0000100c, 1));
   addRegister(new Register("Config13", baseAddress_ + addrSize*0x0000100d, 1));
   addRegister(new Register("Config14", baseAddress_ + addrSize*0x0000100e, 1));
   addRegister(new Register("Config15", baseAddress_ + addrSize*0x0000100f, 1));
   addRegister(new Register("Config16", baseAddress_ + addrSize*0x00001010, 1));
   
   //Variables
   addVariable(new Variable("RowStart", Variable::Configuration));
   getVariable("RowStart")->setDescription("RowStart");
   getVariable("RowStart")->setRange(0,0xFF);
   
   addVariable(new Variable("RowStop", Variable::Configuration));
   getVariable("RowStop")->setDescription("RowStop");
   getVariable("RowStop")->setRange(0,0xFF);
   
   addVariable(new Variable("ColumnStart", Variable::Configuration));
   getVariable("ColumnStart")->setDescription("ColumnStart");
   getVariable("ColumnStart")->setRange(0,0xFF);
   
   addVariable(new Variable("StartPixel", Variable::Configuration));
   getVariable("StartPixel")->setDescription("StartPixel");
   getVariable("StartPixel")->setRange(0,0xFFFF);
   
   addVariable(new Variable("TpsDacGain", Variable::Configuration));
   getVariable("TpsDacGain")->setDescription("TpsDacGain");
   getVariable("TpsDacGain")->setRange(0,0x3);
   
   addVariable(new Variable("TpsDac", Variable::Configuration));
   getVariable("TpsDac")->setDescription("TpsDac");
   getVariable("TpsDac")->setRange(0,0x3F);
   
   addVariable(new Variable("TpsGr", Variable::Configuration));
   getVariable("TpsGr")->setDescription("TpsGr");
   getVariable("TpsGr")->setRange(0,0xF);
   
   addVariable(new Variable("TpsMux", Variable::Configuration));
   getVariable("TpsMux")->setDescription("Analog Test Point Multiplexer");
   vector<string> tpsMuxNames;
   tpsMuxNames.resize(16);
   tpsMuxNames[0]  = "in";
   tpsMuxNames[1]  = "fin";
   tpsMuxNames[2]  = "fo";
   tpsMuxNames[3]  = "abus";
   tpsMuxNames[4]  = "cdso3";
   tpsMuxNames[5]  = "bgr2V";
   tpsMuxNames[6]  = "bgr2Vd";
   tpsMuxNames[7]  = "vxComp";
   tpsMuxNames[8]  = "vcmi";
   tpsMuxNames[9]  = "pixVref";
   tpsMuxNames[10] = "vTestBe";
   tpsMuxNames[11] = "pixVctrl";
   tpsMuxNames[12] = "testLine";
   tpsMuxNames[13] = "ptat";
   tpsMuxNames[14] = "empty0";
   tpsMuxNames[15] = "empty1";
   getVariable("TpsMux")->setEnums(tpsMuxNames);
   
   addVariable(new Variable("BiasTpsBuffer", Variable::Configuration));
   getVariable("BiasTpsBuffer")->setDescription("BiasTpsBuffer");
   getVariable("BiasTpsBuffer")->setRange(0,0x7);
   
   addVariable(new Variable("BiasTps", Variable::Configuration));
   getVariable("BiasTps")->setDescription("BiasTps");
   getVariable("BiasTps")->setRange(0,0x7);
   
   addVariable(new Variable("BiasTpsDac", Variable::Configuration));
   getVariable("BiasTpsDac")->setDescription("BiasTpsDac");
   getVariable("BiasTpsDac")->setRange(0,0x7);
   
   addVariable(new Variable("DacComparator", Variable::Configuration));
   getVariable("DacComparator")->setDescription("DacComparator");
   getVariable("DacComparator")->setRange(0,0x3F);
   
   addVariable(new Variable("BiasComparator", Variable::Configuration));
   getVariable("BiasComparator")->setDescription("BiasComparator");
   getVariable("BiasComparator")->setRange(0,0x7);
   
   addVariable(new Variable("Preamp", Variable::Configuration));
   getVariable("Preamp")->setDescription("Preamp");
   getVariable("Preamp")->setRange(0,0x7);
   
   addVariable(new Variable("BiasDac", Variable::Configuration));
   getVariable("BiasDac")->setDescription("BiasDac");
   getVariable("BiasDac")->setRange(0,0x7);
   
   addVariable(new Variable("BgrCtrlDacTps", Variable::Configuration));
   getVariable("BgrCtrlDacTps")->setDescription("BgrCtrlDacTps");
   getVariable("BgrCtrlDacTps")->setRange(0,0x3);
   
   addVariable(new Variable("BgrCtrlDacComp", Variable::Configuration));
   getVariable("BgrCtrlDacComp")->setDescription("BgrCtrlDacComp");
   getVariable("BgrCtrlDacComp")->setRange(0,0x3);
   
   addVariable(new Variable("DacComparatorGain", Variable::Configuration));
   getVariable("DacComparatorGain")->setDescription("DacComparatorGain");
   getVariable("DacComparatorGain")->setRange(0,0x3);
   
   addVariable(new Variable("Ppbit", Variable::Configuration));
   getVariable("Ppbit")->setDescription("Ppbit");
   getVariable("Ppbit")->setTrueFalse();
   
   addVariable(new Variable("TestBe", Variable::Configuration));
   getVariable("TestBe")->setDescription("TestBe");
   getVariable("TestBe")->setTrueFalse();
   
   addVariable(new Variable("DelExec", Variable::Configuration));
   getVariable("DelExec")->setDescription("DelExec");
   getVariable("DelExec")->setTrueFalse();
   
   addVariable(new Variable("DelCCKreg", Variable::Configuration));
   getVariable("DelCCKreg")->setDescription("DelCCKreg");
   getVariable("DelCCKreg")->setTrueFalse();
   
   addVariable(new Variable("syncExten", Variable::Configuration));
   getVariable("syncExten")->setDescription("syncExten");
   getVariable("syncExten")->setTrueFalse();
   
   addVariable(new Variable("syncRoleSel", Variable::Configuration));
   getVariable("syncRoleSel")->setDescription("syncRoleSel");
   getVariable("syncRoleSel")->setTrueFalse();
   
   addVariable(new Variable("hdrMode", Variable::Configuration));
   getVariable("hdrMode")->setDescription("hdrMode");
   getVariable("hdrMode")->setTrueFalse();
   
   addVariable(new Variable("acqRowlastEn", Variable::Configuration));
   getVariable("acqRowlastEn")->setDescription("acqRowlastEn");
   getVariable("acqRowlastEn")->setTrueFalse();
   
   addVariable(new Variable("DM1en", Variable::Configuration));
   getVariable("DM1en")->setDescription("DM1en");
   getVariable("DM1en")->setTrueFalse();
   
   addVariable(new Variable("DM2en", Variable::Configuration));
   getVariable("DM2en")->setDescription("DM2en");
   getVariable("DM2en")->setTrueFalse();
   
   addVariable(new Variable("DigROdisable", Variable::Configuration));
   getVariable("DigROdisable")->setDescription("DigROdisable");
   getVariable("DigROdisable")->setTrueFalse();
   
   addVariable(new Variable("pllReset", Variable::Configuration));
   getVariable("pllReset")->setDescription("pllReset");
   getVariable("pllReset")->setTrueFalse();
   
   addVariable(new Variable("pllItune", Variable::Configuration));
   getVariable("pllItune")->setDescription("pllItune");
   getVariable("pllItune")->setRange(0,0x7);
   
   addVariable(new Variable("pllKvco", Variable::Configuration));
   getVariable("pllKvco")->setDescription("pllKvco");
   getVariable("pllKvco")->setRange(0,0x7);
   
   addVariable(new Variable("pllFilter1", Variable::Configuration));
   getVariable("pllFilter1")->setDescription("pllFilter1");
   getVariable("pllFilter1")->setRange(0,0x7);
   
   addVariable(new Variable("pllFilter2", Variable::Configuration));
   getVariable("pllFilter2")->setDescription("pllFilter2");
   getVariable("pllFilter2")->setRange(0,0x7);
   
   addVariable(new Variable("pllOutDivider", Variable::Configuration));
   getVariable("pllOutDivider")->setDescription("pllOutDivider");
   getVariable("pllOutDivider")->setRange(0,0x3);
   
   addVariable(new Variable("pllROReset", Variable::Configuration));
   getVariable("pllROReset")->setDescription("pllROReset");
   getVariable("pllROReset")->setTrueFalse();
   
   addVariable(new Variable("pllROItune", Variable::Configuration));
   getVariable("pllROItune")->setDescription("pllROItune");
   getVariable("pllROItune")->setRange(0,0x7);
   
   addVariable(new Variable("pllROKvco", Variable::Configuration));
   getVariable("pllROKvco")->setDescription("pllROKvco");
   getVariable("pllROKvco")->setRange(0,0x7);
   
   addVariable(new Variable("pllROFilter1", Variable::Configuration));
   getVariable("pllROFilter1")->setDescription("pllROFilter1");
   getVariable("pllROFilter1")->setRange(0,0x7);
   
   addVariable(new Variable("pllROFilter2", Variable::Configuration));
   getVariable("pllROFilter2")->setDescription("pllROFilter2");
   getVariable("pllROFilter2")->setRange(0,0x7);
   
   addVariable(new Variable("pllROoutDivider", Variable::Configuration));
   getVariable("pllROoutDivider")->setDescription("pllROoutDivider");
   getVariable("pllROoutDivider")->setRange(0,0x7);
   
   addVariable(new Variable("dllGlobalCalib", Variable::Configuration));
   getVariable("dllGlobalCalib")->setDescription("dllGlobalCalib");
   getVariable("dllGlobalCalib")->setRange(0,0x7);
   
   addVariable(new Variable("dllCalibrationRang", Variable::Configuration));
   getVariable("dllCalibrationRang")->setDescription("dllCalibrationRang");
   getVariable("dllCalibrationRang")->setRange(0,0x7);
   
   addVariable(new Variable("DllCpBias", Variable::Configuration));
   getVariable("DllCpBias")->setDescription("DllCpBias");
   getVariable("DllCpBias")->setRange(0,0x7);
   
   addVariable(new Variable("DllAlockRen", Variable::Configuration));
   getVariable("DllAlockRen")->setDescription("DllAlockRen");
   getVariable("DllAlockRen")->setTrueFalse();
   
   addVariable(new Variable("DllReset", Variable::Configuration));
   getVariable("DllReset")->setDescription("DllReset");
   getVariable("DllReset")->setTrueFalse();
   
   addVariable(new Variable("DllDACvctrlEn", Variable::Configuration));
   getVariable("DllDACvctrlEn")->setDescription("DllDACvctrlEn");
   getVariable("DllDACvctrlEn")->setTrueFalse();
   
   addVariable(new Variable("DllBiasDisable", Variable::Configuration));
   getVariable("DllBiasDisable")->setDescription("DllBiasDisable");
   getVariable("DllBiasDisable")->setTrueFalse();
   
   addVariable(new Variable("delayCellTestCalib", Variable::Configuration));
   getVariable("delayCellTestCalib")->setDescription("delayCellTestCalib");
   getVariable("delayCellTestCalib")->setRange(0,0x7);
   
   addVariable(new Variable("BiasVthCalibStepSize", Variable::Configuration));
   getVariable("BiasVthCalibStepSize")->setDescription("BiasVthCalibStepSize");
   getVariable("BiasVthCalibStepSize")->setRange(0,0x3);
   
   addVariable(new Variable("BiasVthCalibStepGlob", Variable::Configuration));
   getVariable("BiasVthCalibStepGlob")->setDescription("BiasVthCalibStepGlob");
   getVariable("BiasVthCalibStepGlob")->setRange(0,0x7);
   
   addVariable(new Variable("BiasVthCalibTail", Variable::Configuration));
   getVariable("BiasVthCalibTail")->setDescription("BiasVthCalibTail");
   getVariable("BiasVthCalibTail")->setRange(0,0x7);
   
   addVariable(new Variable("GlobalCounterStart", Variable::Configuration));
   getVariable("GlobalCounterStart")->setDescription("GlobalCounterStart");
   getVariable("GlobalCounterStart")->setRange(0,0xFF);
   
   addVariable(new Variable("ROslvdsBit", Variable::Configuration));
   getVariable("ROslvdsBit")->setDescription("ROslvdsBit");
   getVariable("ROslvdsBit")->setTrueFalse();
   
   addVariable(new Variable("REFslvdsBit", Variable::Configuration));
   getVariable("REFslvdsBit")->setDescription("REFslvdsBit");
   getVariable("REFslvdsBit")->setTrueFalse();
   
   addVariable(new Variable("emphBc", Variable::Configuration));
   getVariable("emphBc")->setDescription("emphBc");
   getVariable("emphBc")->setRange(0,0x7);
   
   addVariable(new Variable("emphBd", Variable::Configuration));
   getVariable("emphBd")->setDescription("emphBd");
   getVariable("emphBd")->setRange(0,0x7);
   
   addVariable(new Variable("DM1Sel", Variable::Configuration));
   getVariable("DM1Sel")->setDescription("Digital Monitor 1 Select");
   vector<string> dm1;
   dm1.resize(16);
   dm1[0]  = "Clk";
   dm1[1]  = "Exec";
   dm1[2]  = "RoRst";
   dm1[3]  = "empty0";
   dm1[4]  = "empty1";
   dm1[5]  = "empty2";
   dm1[6]  = "Addr0";
   dm1[7]  = "Addr1";
   dm1[8]  = "Addr2";
   dm1[9]  = "Addr3";
   dm1[10] = "Addr4";
   dm1[11] = "Cmd0";
   dm1[12] = "Cmd1";
   dm1[13] = "Cmd2";
   dm1[14] = "Cmd3";
   dm1[15] = "empty4";
   getVariable("DM1Sel")->setEnums(dm1);
   
   addVariable(new Variable("DM2Sel", Variable::Configuration));
   getVariable("DM2Sel")->setDescription("Digital Monitor 2 Select");
   vector<string> dm2;
   dm2.resize(16);
   dm2[0]  = "Clk";
   dm2[1]  = "Exec";
   dm2[2]  = "RoRst";
   dm2[3]  = "Ack";
   dm2[4]  = "isEn";
   dm2[5]  = "ROWclk";
   dm2[6]  = "Db0";
   dm2[7]  = "Db1";
   dm2[8]  = "Db2";
   dm2[9]  = "Db3";
   dm2[10] = "Db4";
   dm2[11] = "Db5";
   dm2[12] = "Db6";
   dm2[13] = "Db7";
   dm2[14] = "AddrMat";
   dm2[15] = "config";
   getVariable("DM2Sel")->setEnums(dm2);
   
   addVariable(new Variable("DacDllGain", Variable::Configuration));
   getVariable("DacDllGain")->setDescription("DacDllGain");
   getVariable("DacDllGain")->setRange(0,0x3);
   
   addVariable(new Variable("DacDll", Variable::Configuration));
   getVariable("DacDll")->setDescription("DacDll");
   getVariable("DacDll")->setRange(0,0x3F);
   
   addVariable(new Variable("DacTestlineGain", Variable::Configuration));
   getVariable("DacTestlineGain")->setDescription("DacTestlineGain");
   getVariable("DacTestlineGain")->setRange(0,0x3);
   
   addVariable(new Variable("DacTestline", Variable::Configuration));
   getVariable("DacTestline")->setDescription("DacTestline");
   getVariable("DacTestline")->setRange(0,0x3F);
   
   addVariable(new Variable("DacpfaCompGain", Variable::Configuration));
   getVariable("DacpfaCompGain")->setDescription("DacpfaCompGain");
   getVariable("DacpfaCompGain")->setRange(0,0x3);
   
   addVariable(new Variable("DacpfaComp", Variable::Configuration));
   getVariable("DacpfaComp")->setDescription("DacpfaComp");
   getVariable("DacpfaComp")->setRange(0,0x3F);
   
   addVariable(new Variable("LinearDecay", Variable::Configuration));
   getVariable("LinearDecay")->setDescription("LinearDecay");
   getVariable("LinearDecay")->setRange(0,0x7);
   
   addVariable(new Variable("BGRctrlDACdll", Variable::Configuration));
   getVariable("BGRctrlDACdll")->setDescription("BGRctrlDACdll");
   getVariable("BGRctrlDACdll")->setRange(0,0x3);
   
   addVariable(new Variable("BGRctrlDACtestine", Variable::Configuration));
   getVariable("BGRctrlDACtestine")->setDescription("BGRctrlDACtestine");
   getVariable("BGRctrlDACtestine")->setRange(0,0x3);
   
   addVariable(new Variable("BGRctrlDACpfaComp", Variable::Configuration));
   getVariable("BGRctrlDACpfaComp")->setDescription("BGRctrlDACpfaComp");
   getVariable("BGRctrlDACpfaComp")->setRange(0,0x3);

   // CMD = 6, Addr = 17 : Row counter[8:0]
   addRegister(new Register("RowCounter", baseAddress_ + addrSize*0x00006011, 1));

   addVariable(new Variable("RowCounter", Variable::Configuration));
   getVariable("RowCounter")->setDescription("");
   getVariable("RowCounter")->setRange(0,0x1FF);
   //Writes to the row counter are special.. require a prepare for readout first
   addCommand(new Command("WriteRowCounter"));
   getCommand("WriteRowCounter")->setDescription("Special command to write row counter");

   // CMD = 6, Addr = 19 : Bank select [3:0] & Col counter[6:0]
   addRegister(new Register("ColCounter", baseAddress_ + addrSize*0x00006013, 1));

   addVariable(new Variable("ColCounter", Variable::Configuration));
   getVariable("ColCounter")->setDescription("");
   getVariable("ColCounter")->setRange(0,0x7F);

   addVariable(new Variable("BankSelect", Variable::Configuration));
   getVariable("BankSelect")->setDescription("Active low bank select bit mask");
   getVariable("BankSelect")->setRange(0,0xF);

   // CMD = 2, Addr = X  : Write Row with data
   addRegister(new Register("WriteRowData", baseAddress_ + addrSize*0x00002000, 1));
   addCommand(new Command("WriteRowData"));
   getCommand("WriteRowData")->setDescription("Write PixelTest and PixelMask to selected row");

   // CMD = 3, Addr = X  : Write Column with data
   addRegister(new Register("WriteColData", baseAddress_ + addrSize*0x00003000, 1));

   // CMD = 4, Addr = X  : Write Matrix with data
   addRegister(new Register("WriteMatrixData", baseAddress_ + addrSize*0x00004000, 1));
   addCommand(new Command("WriteMatrixData"));
   getCommand("WriteMatrixData")->setDescription("Write PixelTest and PixelMask to all pixels");

   // CMD = 5, Addr = X  : Read/Write Pixel with data
   addRegister(new Register("WritePixelData", baseAddress_ + addrSize*0x00005000, 1));
   addCommand(new Command("WritePixelData"));
   getCommand("WritePixelData")->setDescription("Write PixelTest and PixelMask to current pixel only");
   // Dummy command to enable reading of pixels (register is same as WritePixelData)
   addCommand(new Command("ReadPixelData"));
   getCommand("ReadPixelData")->setDescription("Read PixelTest and PixelMask from current pixel only");

   // CMD = 7, Addr = X  : Prepare to write chip ID
   addRegister(new Register("PrepareWriteChipIdA", baseAddress_ + addrSize*0x00007000, 1));
   addRegister(new Register("PrepareWriteChipIdB", baseAddress_ + addrSize*0x00007015, 1));

   // CMD = 8, Addr = X  : Prepare for row/column/matrix configuration
   addRegister(new Register("PrepareMultiConfig", baseAddress_ + addrSize*0x00008000, 1));

   // Pixel Configuration
   //                    : Bit 0 = Test
   //                    : Bit 1 = Test
   addVariable(new Variable("PixelMask", Variable::Configuration));
   getVariable("PixelMask")->setDescription("Dummy Pixel Mask");
   getVariable("PixelMask")->setTrueFalse();

   addVariable(new Variable("PixelTest", Variable::Configuration));
   getVariable("PixelTest")->setDescription("Dummy Pixel Test");
   getVariable("PixelTest")->setTrueFalse();

   // To Write a single pixel:
      // CMD = 6, Addr = 17 : Row start address[9:0]
      // CMD = 6, Addr = 19 : Col start address[9:0]
      // CMD = 5, Addr = X  : Read/Write Pixel

   // Configure entire matrix
      // CMD = 8, Addr = X  : Prepare for row/column/matrix configuration
      // CMD = 4, Addr = X  : Write Matrix With passed data

   // Configure row 
      // CMD = 8, Addr = X  : Prepare for row/column/matrix configuration
      // CMD = 6, Addr = 17 : Row start address[9:0]
      // CMD = 2, Addr = X  : Write Row with Data

   // Configure col 
      // CMD = 8, Addr = X  : Prepare for row/column/matrix configuration
      // CMD = 6, Addr = 19 : Col start address[9:0]
      // CMD = 3, Addr = X  : Write Col with Data

   setInt("Enabled",0);  
}

// Deconstructor
TixelPAsic::~TixelPAsic ( ) { }

// Method to process a command
void TixelPAsic::command ( string name, string arg) {
   stringstream tmp;

   // Command is local
   if ( name == "PrepForRead" ) {
      REGISTER_LOCK
      writeRegister(getRegister("CmdPrepForRead"),true,true);
      REGISTER_UNLOCK
   } else if ( name == "WriteMatrixData" ) {
      REGISTER_LOCK
      getRegister("WriteMatrixData")->set(getVariable("PixelTest")->getInt(),0,0x1);
      getRegister("WriteMatrixData")->set(getVariable("PixelMask")->getInt(),1,0x1);
      writeRegister(getRegister("PrepareMultiConfig"),true,true);
      writeRegister(getRegister("WriteMatrixData"),true,true);
      writeRegister(getRegister("CmdPrepForRead"),true,true);
      REGISTER_UNLOCK
   } else if ( name == "WriteRowCounter" ) {
      REGISTER_LOCK
      writeRegister(getRegister("CmdPrepForRead"),true,true);
      getRegister("RowCounter")->set(getVariable("RowCounter")->getInt(),0,0x1FF);
      writeRegister(getRegister("RowCounter"),true,true);
      REGISTER_UNLOCK
   } else if ( name == "WritePixelData" ) {
      REGISTER_LOCK
      getRegister("WritePixelData")->set(getVariable("PixelTest")->getInt(),0,0x1);
      getRegister("WritePixelData")->set(getVariable("PixelMask")->getInt(),1,0x1);
      writeRegister(getRegister("PrepareMultiConfig"),true,true);
      getRegister("RowCounter")->set(getVariable("RowCounter")->getInt(),0,0x1FF);
      writeRegister(getRegister("RowCounter"),true,true);
      getRegister("ColCounter")->set(getVariable("ColCounter")->getInt(),0,0x7F);
      getRegister("ColCounter")->set(getVariable("BankSelect")->getInt(),8,0xF);
      writeRegister(getRegister("ColCounter"),true,true);
      writeRegister(getRegister("WritePixelData"),true,true);
      REGISTER_UNLOCK
   } else if ( name == "ReadPixelData" ) {
      REGISTER_LOCK
      getRegister("WritePixelData")->set(getVariable("PixelTest")->getInt(),0,0x1);
      getRegister("WritePixelData")->set(getVariable("PixelMask")->getInt(),1,0x1);
      writeRegister(getRegister("PrepareMultiConfig"),true,true);
      getRegister("RowCounter")->set(getVariable("RowCounter")->getInt(),0,0x1FF);
      writeRegister(getRegister("RowCounter"),true,true);
      getRegister("ColCounter")->set(getVariable("ColCounter")->getInt(),0,0x7F);
      getRegister("ColCounter")->set(getVariable("BankSelect")->getInt(),8,0xF);
      writeRegister(getRegister("ColCounter"),true,true);
      readRegister(getRegister("WritePixelData")); 
      getVariable("PixelTest")->setInt(getRegister("WritePixelData")->get(0,0x1));
      getVariable("PixelMask")->setInt(getRegister("WritePixelData")->get(1,0x1));
      REGISTER_UNLOCK
   } else if ( name == "WriteRowData" ) {
      REGISTER_LOCK
      bool wait = true;
      writeRegister(getRegister("CmdPrepForRead"),true,wait);
      writeRegister(getRegister("PrepareMultiConfig"),true,wait);
      getRegister("RowCounter")->set(getVariable("RowCounter")->getInt(),0,0x1FF);
      writeRegister(getRegister("RowCounter"),true,wait);
      getRegister("WriteRowData")->set(getVariable("PixelTest")->getInt(),0,0x1);
      getRegister("WriteRowData")->set(getVariable("PixelMask")->getInt(),1,0x1);
      writeRegister(getRegister("WriteRowData"),true,wait);
      REGISTER_UNLOCK
   }
   else Device::command(name, arg);
}


// Method to read status registers and update variables
void TixelPAsic::readStatus ( ) {
   REGISTER_LOCK

   REGISTER_UNLOCK
}

// Method to read configuration registers and update variables
void TixelPAsic::readConfig ( ) {

   REGISTER_LOCK
   
   readRegister(getRegister("Config1"));
   getVariable("RowStart")->setInt(getRegister("Config1")->get(0,0xFF));

   readRegister(getRegister("Config2"));
   getVariable("RowStop")->setInt(getRegister("Config2")->get(0,0xFF));
   
   readRegister(getRegister("Config3"));
   getVariable("ColumnStart")->setInt(getRegister("Config3")->get(0,0xFF));
   
   readRegister(getRegister("Config4"));
   getVariable("StartPixel")->setInt(getRegister("Config4")->get(0,0xFFFF));
   
   readRegister(getRegister("Config5"));
   getVariable("TpsDacGain")->setInt(getRegister("Config5")->get(0,0x3));
   getVariable("TpsDac")->setInt(getRegister("Config5")->get(2,0x3F));
   getVariable("TpsGr")->setInt(getRegister("Config5")->get(8,0xF));
   getVariable("TpsMux")->setInt(getRegister("Config5")->get(12,0xF));
   
   readRegister(getRegister("Config6"));
   getVariable("BiasTpsBuffer")->setInt(getRegister("Config6")->get(0,0x7));
   getVariable("BiasTps")->setInt(getRegister("Config6")->get(3,0x7));
   getVariable("BiasTpsDac")->setInt(getRegister("Config6")->get(6,0x7));
   getVariable("DacComparator")->setInt(getRegister("Config6")->get(10,0x3F));
   
   readRegister(getRegister("Config7"));
   getVariable("BiasComparator")->setInt(getRegister("Config7")->get(0,0x7));
   getVariable("Preamp")->setInt(getRegister("Config7")->get(3,0x7));
   getVariable("BiasDac")->setInt(getRegister("Config7")->get(6,0x7));
   getVariable("BgrCtrlDacTps")->setInt(getRegister("Config7")->get(9,0x3));
   getVariable("BgrCtrlDacComp")->setInt(getRegister("Config7")->get(11,0x3));
   getVariable("DacComparatorGain")->setInt(getRegister("Config7")->get(13,0x3));
   
   readRegister(getRegister("Config8"));
   getVariable("Ppbit")->setInt(getRegister("Config8")->get(0,0x1));
   getVariable("TestBe")->setInt(getRegister("Config8")->get(1,0x1));
   getVariable("DelExec")->setInt(getRegister("Config8")->get(2,0x1));
   getVariable("DelCCKreg")->setInt(getRegister("Config8")->get(3,0x1));
   getVariable("syncExten")->setInt(getRegister("Config8")->get(4,0x1));
   getVariable("syncRoleSel")->setInt(getRegister("Config8")->get(5,0x1));
   getVariable("hdrMode")->setInt(getRegister("Config8")->get(6,0x1));
   getVariable("acqRowlastEn")->setInt(getRegister("Config8")->get(7,0x1));
   getVariable("DM1en")->setInt(getRegister("Config8")->get(8,0x1));
   getVariable("DM2en")->setInt(getRegister("Config8")->get(9,0x1));
   getVariable("DigROdisable")->setInt(getRegister("Config8")->get(10,0x1));
   
   readRegister(getRegister("Config9"));
   getVariable("pllReset")->setInt(getRegister("Config9")->get(0,0x1));
   getVariable("pllItune")->setInt(getRegister("Config9")->get(1,0x7));
   getVariable("pllKvco")->setInt(getRegister("Config9")->get(4,0x7));
   getVariable("pllFilter1")->setInt(getRegister("Config9")->get(7,0x7));
   getVariable("pllFilter2")->setInt(getRegister("Config9")->get(10,0x7));
   getVariable("pllOutDivider")->setInt(getRegister("Config9")->get(13,0x3));
   
   readRegister(getRegister("Config10"));
   getVariable("pllROReset")->setInt(getRegister("Config10")->get(0,0x1));
   getVariable("pllROItune")->setInt(getRegister("Config10")->get(1,0x7));
   getVariable("pllROKvco")->setInt(getRegister("Config10")->get(4,0x7));
   getVariable("pllROFilter1")->setInt(getRegister("Config10")->get(7,0x7));
   getVariable("pllROFilter2")->setInt(getRegister("Config10")->get(10,0x7));
   getVariable("pllROoutDivider")->setInt(getRegister("Config10")->get(13,0x7));
   
   readRegister(getRegister("Config11"));
   getVariable("dllGlobalCalib")->setInt(getRegister("Config11")->get(0,0x7));
   getVariable("dllCalibrationRang")->setInt(getRegister("Config11")->get(3,0x7));
   getVariable("DllCpBias")->setInt(getRegister("Config11")->get(6,0x7));
   getVariable("DllAlockRen")->setInt(getRegister("Config11")->get(9,0x1));
   getVariable("DllReset")->setInt(getRegister("Config11")->get(10,0x1));
   getVariable("DllDACvctrlEn")->setInt(getRegister("Config11")->get(11,0x1));
   getVariable("DllBiasDisable")->setInt(getRegister("Config11")->get(12,0x1));
   getVariable("delayCellTestCalib")->setInt(getRegister("Config11")->get(13,0x7));
   
   readRegister(getRegister("Config12"));
   getVariable("BiasVthCalibStepSize")->setInt(getRegister("Config12")->get(0,0x3));
   getVariable("BiasVthCalibStepGlob")->setInt(getRegister("Config12")->get(2,0x7));
   getVariable("BiasVthCalibTail")->setInt(getRegister("Config12")->get(5,0x7));
   getVariable("GlobalCounterStart")->setInt(getRegister("Config12")->get(8,0xFF));
   
   readRegister(getRegister("Config13"));
   getVariable("ROslvdsBit")->setInt(getRegister("Config13")->get(0,0x1));
   getVariable("REFslvdsBit")->setInt(getRegister("Config13")->get(1,0x1));
   getVariable("emphBc")->setInt(getRegister("Config13")->get(2,0x7));
   getVariable("emphBd")->setInt(getRegister("Config13")->get(5,0x7));
   getVariable("DM1Sel")->setInt(getRegister("Config13")->get(8,0xF));
   getVariable("DM2Sel")->setInt(getRegister("Config13")->get(12,0xF));
   
   readRegister(getRegister("Config14"));
   getVariable("DacDllGain")->setInt(getRegister("Config14")->get(0,0x3));
   getVariable("DacDll")->setInt(getRegister("Config14")->get(2,0x3F));
   getVariable("DacTestlineGain")->setInt(getRegister("Config14")->get(8,0x3));
   getVariable("DacTestline")->setInt(getRegister("Config14")->get(10,0x3F));
   
   readRegister(getRegister("Config15"));
   getVariable("DacpfaCompGain")->setInt(getRegister("Config15")->get(0,0x3));
   getVariable("DacpfaComp")->setInt(getRegister("Config15")->get(2,0x3F));
   
   readRegister(getRegister("Config16"));
   getVariable("LinearDecay")->setInt(getRegister("Config16")->get(0,0x7));
   getVariable("BGRctrlDACdll")->setInt(getRegister("Config16")->get(3,0x3));
   getVariable("BGRctrlDACtestine")->setInt(getRegister("Config16")->get(5,0x3));
   getVariable("BGRctrlDACpfaComp")->setInt(getRegister("Config16")->get(7,0x3));

   // CMD = 6, Addr = 17 : Row counter[8:0]
//   readRegister(getRegister("RowCounter"));
//   getVariable("RowCounter")->setInt(getRegister("RowCounter")->get(0,0x1FF));

   // CMD = 6, Addr = 19 : Col start address[6:0]
//   readRegister(getRegister("ColCounter"));
//   getVariable("ColCounter")->setInt(getRegister("ColCounter")->get(0,0x7F));

   // CMD = 5, Addr = X  : Read/Write Pixel with data
   readRegister(getRegister("WritePixelData"));
   getVariable("PixelTest")->setInt(getRegister("WritePixelData")->get(0,0x1));
   getVariable("PixelMask")->setInt(getRegister("WritePixelData")->get(1,0x1));

   REGISTER_UNLOCK
}

// Method to write configuration registers
void TixelPAsic::writeConfig ( bool force ) {

   REGISTER_LOCK

   // CMD = 1, Addr = 1  : Bits 2:0 - Pulser monostable bits
   //                      Bit  7   - Pulser sync bit
   getRegister("Config1")->set(getVariable("RowStart")->getInt(),0,0xFF);
   writeRegister(getRegister("Config1"),force,true);
   
   getRegister("Config2")->set(getVariable("RowStop")->getInt(),0,0xFF);
   writeRegister(getRegister("Config2"),force,true);
   
   getRegister("Config3")->set(getVariable("ColumnStart")->getInt(),0,0xFF);
   writeRegister(getRegister("Config3"),force,true);
   
   getRegister("Config4")->set(getVariable("StartPixel")->getInt(),0,0xFFFF);
   writeRegister(getRegister("Config4"),force,true);
   
   getRegister("Config5")->set(getVariable("TpsDacGain")->getInt(),0,0x3);
   getRegister("Config5")->set(getVariable("TpsDac")->getInt(),2,0x3F);
   getRegister("Config5")->set(getVariable("TpsGr")->getInt(),8,0xF);
   getRegister("Config5")->set(getVariable("TpsMux")->getInt(),12,0xF);
   writeRegister(getRegister("Config5"),force,true);
   
   getRegister("Config6")->set(getVariable("BiasTpsBuffer")->getInt(),0,0x7);
   getRegister("Config6")->set(getVariable("BiasTps")->getInt(),3,0x7);
   getRegister("Config6")->set(getVariable("BiasTpsDac")->getInt(),6,0x7);
   getRegister("Config6")->set(getVariable("DacComparator")->getInt(),10,0x3F);
   writeRegister(getRegister("Config6"),force,true);
   
   getRegister("Config7")->set(getVariable("BiasComparator")->getInt(),0,0x7);
   getRegister("Config7")->set(getVariable("Preamp")->getInt(),3,0x7);
   getRegister("Config7")->set(getVariable("BiasDac")->getInt(),6,0x7);
   getRegister("Config7")->set(getVariable("BgrCtrlDacTps")->getInt(),9,0x3);
   getRegister("Config7")->set(getVariable("BgrCtrlDacComp")->getInt(),11,0x3);
   getRegister("Config7")->set(getVariable("DacComparatorGain")->getInt(),13,0x3);
   writeRegister(getRegister("Config7"),force,true);
   
   getRegister("Config8")->set(getVariable("Ppbit")->getInt(),0,0x1);
   getRegister("Config8")->set(getVariable("TestBe")->getInt(),1,0x1);
   getRegister("Config8")->set(getVariable("DelExec")->getInt(),2,0x1);
   getRegister("Config8")->set(getVariable("DelCCKreg")->getInt(),3,0x1);
   getRegister("Config8")->set(getVariable("syncExten")->getInt(),4,0x1);
   getRegister("Config8")->set(getVariable("syncRoleSel")->getInt(),5,0x1);
   getRegister("Config8")->set(getVariable("hdrMode")->getInt(),6,0x1);
   getRegister("Config8")->set(getVariable("acqRowlastEn")->getInt(),7,0x1);
   getRegister("Config8")->set(getVariable("DM1en")->getInt(),8,0x1);
   getRegister("Config8")->set(getVariable("DM2en")->getInt(),9,0x1);
   getRegister("Config8")->set(getVariable("DigROdisable")->getInt(),10,0x1);
   writeRegister(getRegister("Config8"),force,true);
   
   getRegister("Config9")->set(getVariable("pllReset")->getInt(),0,0x1);
   getRegister("Config9")->set(getVariable("pllItune")->getInt(),1,0x7);
   getRegister("Config9")->set(getVariable("pllKvco")->getInt(),4,0x7);
   getRegister("Config9")->set(getVariable("pllFilter1")->getInt(),7,0x7);
   getRegister("Config9")->set(getVariable("pllFilter2")->getInt(),10,0x7);
   getRegister("Config9")->set(getVariable("pllOutDivider")->getInt(),13,0x3);
   writeRegister(getRegister("Config9"),force,true);
   
   getRegister("Config10")->set(getVariable("pllROReset")->getInt(),0,0x1);
   getRegister("Config10")->set(getVariable("pllROItune")->getInt(),1,0x7);
   getRegister("Config10")->set(getVariable("pllROKvco")->getInt(),4,0x7);
   getRegister("Config10")->set(getVariable("pllROFilter1")->getInt(),7,0x7);
   getRegister("Config10")->set(getVariable("pllROFilter2")->getInt(),10,0x7);
   getRegister("Config10")->set(getVariable("pllROoutDivider")->getInt(),13,0x7);
   writeRegister(getRegister("Config10"),force,true);
   
   getRegister("Config11")->set(getVariable("dllGlobalCalib")->getInt(),0,0x7);
   getRegister("Config11")->set(getVariable("dllCalibrationRang")->getInt(),3,0x7);
   getRegister("Config11")->set(getVariable("DllCpBias")->getInt(),6,0x7);
   getRegister("Config11")->set(getVariable("DllAlockRen")->getInt(),9,0x1);
   getRegister("Config11")->set(getVariable("DllReset")->getInt(),10,0x1);
   getRegister("Config11")->set(getVariable("DllDACvctrlEn")->getInt(),11,0x1);
   getRegister("Config11")->set(getVariable("DllBiasDisable")->getInt(),12,0x1);
   getRegister("Config11")->set(getVariable("delayCellTestCalib")->getInt(),13,0x7);
   writeRegister(getRegister("Config11"),force,true);
   
   getRegister("Config12")->set(getVariable("BiasVthCalibStepSize")->getInt(),0,0x3);
   getRegister("Config12")->set(getVariable("BiasVthCalibStepGlob")->getInt(),2,0x7);
   getRegister("Config12")->set(getVariable("BiasVthCalibTail")->getInt(),5,0x7);
   getRegister("Config12")->set(getVariable("GlobalCounterStart")->getInt(),8,0xFF);
   writeRegister(getRegister("Config12"),force,true);
   
   getRegister("Config13")->set(getVariable("ROslvdsBit")->getInt(),0,0x1);
   getRegister("Config13")->set(getVariable("REFslvdsBit")->getInt(),1,0x1);
   getRegister("Config13")->set(getVariable("emphBc")->getInt(),2,0x7);
   getRegister("Config13")->set(getVariable("emphBd")->getInt(),5,0x7);
   getRegister("Config13")->set(getVariable("DM1Sel")->getInt(),8,0xF);
   getRegister("Config13")->set(getVariable("DM2Sel")->getInt(),12,0xF);
   writeRegister(getRegister("Config13"),force,true);
   
   getRegister("Config14")->set(getVariable("DacDllGain")->getInt(),0,0x3);
   getRegister("Config14")->set(getVariable("DacDll")->getInt(),2,0x3F);
   getRegister("Config14")->set(getVariable("DacTestlineGain")->getInt(),8,0x3);
   getRegister("Config14")->set(getVariable("DacTestline")->getInt(),10,0x3F);
   writeRegister(getRegister("Config14"),force,true);
   
   getRegister("Config15")->set(getVariable("DacpfaCompGain")->getInt(),0,0x3);
   getRegister("Config15")->set(getVariable("DacpfaComp")->getInt(),2,0x3F);
   writeRegister(getRegister("Config15"),force,true);
   
   getRegister("Config16")->set(getVariable("LinearDecay")->getInt(),0,0x7);
   getRegister("Config16")->set(getVariable("BGRctrlDACdll")->getInt(),3,0x3);
   getRegister("Config16")->set(getVariable("BGRctrlDACtestine")->getInt(),5,0x3);
   getRegister("Config16")->set(getVariable("BGRctrlDACpfaComp")->getInt(),7,0x3);
   writeRegister(getRegister("Config16"),force,true);

   // CMD = 6, Addr = 17 : Row start address[8:0]
//   getRegister("RowCounter")->set(getVariable("RowCounter")->getInt(),0,0x1FF);
//   writeRegister(getRegister("RowCounter"),force,true);

   // CMD = 6, Addr = 19 : Col start address[6:0]
   getRegister("ColCounter")->set(getVariable("ColCounter")->getInt(),0,0x7F);
   writeRegister(getRegister("ColCounter"),force,true);

   // CMD = 4, Addr = X  : Write Matrix With passed data
   getRegister("WriteMatrixData")->set(getVariable("PixelTest")->getInt(),0,0x1);
   getRegister("WriteMatrixData")->set(getVariable("PixelMask")->getInt(),1,0x1);

//   if ( force || getRegister("WriteMatrixData")->stale() ) {
//      writeRegister(getRegister("PrepareMultiConfig"),true);
//      writeRegister(getRegister("WriteMatrixData"),true);
//   }

   REGISTER_UNLOCK
}

// Verify hardware state of configuration
void TixelPAsic::verifyConfig ( ) {

   REGISTER_LOCK

   //verifyRegister(getRegister("Config1"),false,0xFF);
   //verifyRegister(getRegister("Config2"),false,0xFF);
   //verifyRegister(getRegister("Config3"),false,0xFF);
   //verifyRegister(getRegister("Config4"),false,0xFFFF);
   verifyRegister(getRegister("Config5"),false,0xFFFF);
   verifyRegister(getRegister("Config6"),false,0xFDFF);
   verifyRegister(getRegister("Config7"),false,0x7FFF);
   verifyRegister(getRegister("Config8"),false,0x7FF);
   verifyRegister(getRegister("Config9"),false,0x7FFF);
   verifyRegister(getRegister("Config10"),false,0xFFFF);
   verifyRegister(getRegister("Config11"),false,0xFFFF);
   verifyRegister(getRegister("Config12"),false,0xFFFF);
   verifyRegister(getRegister("Config13"),false,0xFFFF);
   verifyRegister(getRegister("Config14"),false,0xFFFF);
   verifyRegister(getRegister("Config15"),false,0xFF);
   verifyRegister(getRegister("Config16"),false,0x1FF);
//   verifyRegister(getRegister("RowStartAddr"),false,0xFF);
//   verifyRegister(getRegister("ColStartAddr"),false,0xFF);

   REGISTER_UNLOCK
}

