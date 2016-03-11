//-----------------------------------------------------------------------------
// File          : CpixPAsic.cpp
// Author        : Maciej Kwiatkowski  <mkwiatko@slac.stanford.edu>
// Created       : 06/06/2013
// Project       : CPIX Prototype ASIC
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
#include <CpixPAsic.h>
#include <Register.h>
#include <Variable.h>
#include <Command.h>
#include <sstream>
#include <iostream>
#include <string>
#include <iomanip>
using namespace std;

// Constructor
CpixPAsic::CpixPAsic ( uint destination, uint baseAddress, uint index, Device *parent ) : 
                     Device(destination,baseAddress,"CpixPAsic",index,parent) {

   // Description
   desc_    = "Cpix ASIC Object.";

   // ASIC Address Space
   // Addr[11:0]  = Address
   // Addr[18:12] = CMD
   // Addr[21:20] = Chip

   // CMD = 0, Addr = 0  : Prepare for readout
   addRegister(new Register("CmdPrepForRead", baseAddress_ + 0x00000000, 1));
   addCommand(new Command("PrepForRead"));
   getCommand("PrepForRead")->setDescription("cPix Prepare For Readout");

   // CMD = 1, Addr = 1  : Bits 5:0 - Comparator Threshold 1 DAC
   //                      Bit  7   - Pulser sync bit
   addRegister(new Register("Config1", baseAddress_ + 0x00001001, 1));

   addVariable(new Variable("CompTh1DAC", Variable::Configuration));
   getVariable("CompTh1DAC")->setDescription("Comparator Threshold 1 DAC");
   getVariable("CompTh1DAC")->setRange(0,0x3F);
   addVariable(new Variable("PulserSync", Variable::Configuration));
   getVariable("PulserSync")->setDescription("Pulse on SYNC signal");
   getVariable("PulserSync")->setTrueFalse();

   // CMD = 1, Addr = 2  : Pll settings addr 2
   //                    : Bit 0    = PLL Reset (active high)
   //                    : Bit 3:1  = PLL Itune
   //                    : Bit 6:4  = PLL KVCO
   //                    : Bit 7    = PLL Filter 1
   
   addRegister(new Register("Config2", baseAddress_ + 0x00001002, 1));
   // CMD = 1, Addr = 15 : Pll settings addr 15
   //                    : Bit 1:0  = PLL Filter 1
   //                    : Bit 4:2  = PLL Filter 2
   //                    : Bit 7:5  = PLL Divider
   addRegister(new Register("Config15", baseAddress_ + 0x0000100F, 1));

   addVariable(new Variable("PllReset", Variable::Configuration));
   getVariable("PllReset")->setDescription("PLL Reset (active high)");
   getVariable("PllReset")->setTrueFalse();

   addVariable(new Variable("PllItune", Variable::Configuration));
   getVariable("PllItune")->setDescription("PLL Itune");
   getVariable("PllItune")->setRange(0,0x7);
   
   addVariable(new Variable("PllKVCO", Variable::Configuration));
   getVariable("PllKVCO")->setDescription("PLL KVCO");
   getVariable("PllKVCO")->setRange(0,0x7);
   
   addVariable(new Variable("PllFilter1", Variable::Configuration));
   getVariable("PllFilter1")->setDescription("PLL Filter 1");
   getVariable("PllFilter1")->setRange(0,0x7);
   
   addVariable(new Variable("PllFilter2", Variable::Configuration));
   getVariable("PllFilter2")->setDescription("PLL Filter 2");
   getVariable("PllFilter2")->setRange(0,0x7);
   
   addVariable(new Variable("PllDivider", Variable::Configuration));
   getVariable("PllDivider")->setDescription("PLL Divider");
   getVariable("PllDivider")->setRange(0,0x7);

   // CMD = 1, Addr = 3  : Bits 9:0 = Pulser[9:0]
   //                    : Bit  10  = pbit
   //                    : Bit  11  = atest
   //                    : Bit  12  = test
   //                    : Bit  13  = sab_test
   //                    : Bit  14  = hrtest
   //                    : Bit  15  = PulserR
   addRegister(new Register("Config3", baseAddress_ + 0x00001003, 1));

   addVariable(new Variable("Pulser", Variable::Configuration));
   getVariable("Pulser")->setDescription("Pulser bits");
   getVariable("Pulser")->setRange(0,0x3FF);

   addVariable(new Variable("PBit", Variable::Configuration));
   getVariable("PBit")->setDescription("PBit");
   getVariable("PBit")->setTrueFalse();

   addVariable(new Variable("ATest", Variable::Configuration));
   getVariable("ATest")->setDescription("ATest");
   getVariable("ATest")->setTrueFalse();

   addVariable(new Variable("Test", Variable::Configuration));
   getVariable("Test")->setDescription("Test");
   getVariable("Test")->setTrueFalse();

   addVariable(new Variable("SabTest", Variable::Configuration));
   getVariable("SabTest")->setDescription("SabTest");
   getVariable("SabTest")->setTrueFalse();

   addVariable(new Variable("HrTest", Variable::Configuration));
   getVariable("HrTest")->setDescription("HrTest");
   getVariable("HrTest")->setTrueFalse();

   addVariable(new Variable("PulserR", Variable::Configuration));
   getVariable("PulserR")->setDescription("Pulser bits");
   getVariable("PulserR")->setTrueFalse();

   // CMD = 1, Addr = 4  : Bits 3:0 = DM1[3:0]
   //                    : Bits 7:4 = DM2[3:0]
   addRegister(new Register("Config4", baseAddress_ + 0x00001004, 1));

   addVariable(new Variable("DigMon1", Variable::Configuration));
   getVariable("DigMon1")->setDescription("Digital Monitor 1 Select");
   vector<string> dm1;
   dm1.resize(16);
   dm1[0]  = "Clk";
   dm1[1]  = "Exec";
   dm1[2]  = "RoRst";
   dm1[3]  = "Ack";
   dm1[4]  = "DigRODis";
   dm1[5]  = "RoWClk";
   dm1[6]  = "Addr0";
   dm1[7]  = "Addr1";
   dm1[8]  = "Addr2";
   dm1[9]  = "Addr3";
   dm1[10] = "Addr4";
   dm1[11] = "Cmd0";
   dm1[12] = "Cmd1";
   dm1[13] = "Cmd2";
   dm1[14] = "Cmd3";
   dm1[15] = "Config";
   getVariable("DigMon1")->setEnums(dm1);

   addVariable(new Variable("DigMon2", Variable::Configuration));
   getVariable("DigMon2")->setDescription("Digital Monitor 2 Select");
   vector<string> dm2;
   dm2.resize(16);
   dm2[0]  = "Clk";
   dm2[1]  = "Exec";
   dm2[2]  = "RoRst";
   dm2[3]  = "Ack";
   dm2[4]  = "DigRODis";
   dm2[5]  = "RoWClk";
   dm2[6]  = "Db0";
   dm2[7]  = "Db1";
   dm2[8]  = "Db2";
   dm2[9]  = "Db3";
   dm2[10] = "Db4";
   dm2[11] = "Db5";
   dm2[12] = "Db6";
   dm2[13] = "Db7";
   dm2[14] = "AddrMot";
   dm2[15] = "Config";
   getVariable("DigMon2")->setEnums(dm2);

   // CMD = 1, Addr = 5  : Bits 2:0 = Pulser DAC
   //                      Bits 5:3 = MonoStPulser
   addRegister(new Register("Config5", baseAddress_ + 0x00001005, 1));

   addVariable(new Variable("PulserDac", Variable::Configuration));
   getVariable("PulserDac")->setDescription("Pulser DAC");
   getVariable("PulserDac")->setRange(0,0x7);

   addVariable(new Variable("MonoStPulser", Variable::Configuration));
   getVariable("MonoStPulser")->setDescription("MonoStPulser");
   getVariable("MonoStPulser")->setRange(0,0x7);

   // CMD = 1, Addr = 6  : Bit  0   = DM1en
   //                    : Bit  1   = DM2en
   //                    : Bit  4:2 = EmphBitDel
   //                    : Bit  7:5 = EmphBitCur
   addRegister(new Register("Config6", baseAddress_ + 0x00001006, 1));

   addVariable(new Variable("Dm1En", Variable::Configuration));
   getVariable("Dm1En")->setDescription("Digital Monitor 1 Enable");
   getVariable("Dm1En")->setTrueFalse();

   addVariable(new Variable("Dm2En", Variable::Configuration));
   getVariable("Dm2En")->setDescription("Digital Monitor 2 Enable");
   getVariable("Dm2En")->setTrueFalse();

   addVariable(new Variable("EmphBitDel", Variable::Configuration));
   getVariable("EmphBitDel")->setDescription("Emphasis Bit Delay");
   getVariable("EmphBitDel")->setRange(0,0x7);
   
   addVariable(new Variable("EmphBitCur", Variable::Configuration));
   getVariable("EmphBitCur")->setDescription("Emphasis Bit Current");
   getVariable("EmphBitCur")->setRange(0,0x7);

   // CMD = 1, Addr = 7  : Bit  5:0 = VREF[5:0]
   //                    : Bit  7:6 = VrefLow[1:0]
   addRegister(new Register("Config7", baseAddress_ + 0x00001007, 1));

   addVariable(new Variable("VRef", Variable::Configuration));
   getVariable("VRef")->setDescription("Voltage Ref");
   getVariable("VRef")->setRange(0,0x3F);

   addVariable(new Variable("VrefLow", Variable::Configuration));
   getVariable("VrefLow")->setDescription("Voltage Ref for Extra Rows");
   getVariable("VrefLow")->setRange(0,0x3);

   // CMD = 1, Addr = 8  : Bit  4:1 = TPS_MUX[3:0]
   //                    : Bit  7:5 = RO_Monost[2:0]
   addRegister(new Register("Config8", baseAddress_ + 0x00001008, 1));

   addVariable(new Variable("TpsMux", Variable::Configuration));
   getVariable("TpsMux")->setDescription("Analog Test Point Multiplexer");
   vector<string> tpsMuxNames;
   tpsMuxNames.resize(16);
   tpsMuxNames[0]  = "in";
   tpsMuxNames[1]  = "fin";
   tpsMuxNames[2]  = "fo";
   tpsMuxNames[3]  = "abus";
   tpsMuxNames[4]  = "cdso3";
   tpsMuxNames[5]  = "bgr_2V";
   tpsMuxNames[6]  = "bgr_2vd";
   tpsMuxNames[7]  = "vx_comp";
   tpsMuxNames[8]  = "vcmi";
   tpsMuxNames[9]  = "Pix_Vref";
   tpsMuxNames[10] = "VtestBE";
   tpsMuxNames[11] = "Pix_Vctrl";
   tpsMuxNames[12] = "testline";
   tpsMuxNames[13] = "Unused13";
   tpsMuxNames[14] = "Unused14";
   tpsMuxNames[15] = "Unused15";
   getVariable("TpsMux")->setEnums(tpsMuxNames);

   addVariable(new Variable("RoMonost", Variable::Configuration));
   getVariable("RoMonost")->setDescription("");
   getVariable("RoMonost")->setRange(0,7);

   // CMD = 1, Addr = 9  : Bit  3:0 = TpsGr
   //                    : Bit  5   = Couc
   //                    : Bit  6   = Ckc
   //                    : Bit  7   = Mod
   addRegister(new Register("Config9", baseAddress_ + 0x00001009, 1));

   addVariable(new Variable("TpsGr", Variable::Configuration));
   getVariable("TpsGr")->setDescription("Analog Test Point Output Dynamic Range");
   getVariable("TpsGr")->setRange(0,15);

   addVariable(new Variable("Couc", Variable::Configuration));
   getVariable("Couc")->setDescription("");
   getVariable("Couc")->setTrueFalse();
   
   addVariable(new Variable("Ckc", Variable::Configuration));
   getVariable("Ckc")->setDescription("");
   getVariable("Ckc")->setTrueFalse();
   
   addVariable(new Variable("Mod", Variable::Configuration));
   getVariable("Mod")->setDescription("");
   getVariable("Mod")->setTrueFalse();

   // CMD = 1, Addr = 10 : Bit  0   = PP_OCB_S2D
   //                    : Bit  3:1 = OCB[2:0]
   //                    : Bit  6:4 = Monost[2:0]
   //                    : Bit  7   = fastpp_enable
   addRegister(new Register("Config10", baseAddress_ + 0x0000100A, 1));

   addVariable(new Variable("PpOcbS2d", Variable::Configuration));
   getVariable("PpOcbS2d")->setDescription("");
   getVariable("PpOcbS2d")->setTrueFalse();

   addVariable(new Variable("Ocb", Variable::Configuration));
   getVariable("Ocb")->setDescription("");
   getVariable("Ocb")->setRange(0,7);

   addVariable(new Variable("Monost", Variable::Configuration));
   getVariable("Monost")->setDescription("");
   getVariable("Monost")->setRange(0,7);

   addVariable(new Variable("FastppEnable", Variable::Configuration));
   getVariable("FastppEnable")->setDescription("");
   getVariable("FastppEnable")->setTrueFalse();

   // CMD = 1, Addr = 11 : Bit  2:0 = Preamp[2:0]
   //                    : Bit  5:3 = Pixel_FB[2:0]
   //                    : Bit  7:6 = Vld1_b[1:0]
   addRegister(new Register("Config11", baseAddress_ + 0x0000100B, 1));

   addVariable(new Variable("Preamp", Variable::Configuration));
   getVariable("Preamp")->setDescription("");
   getVariable("Preamp")->setRange(0,7);

   addVariable(new Variable("PixelFb", Variable::Configuration));
   getVariable("PixelFb")->setDescription("");
   getVariable("PixelFb")->setRange(0,7);

   addVariable(new Variable("Vld1_b", Variable::Configuration));
   getVariable("Vld1_b")->setDescription("");
   getVariable("Vld1_b")->setRange(0,3);

   // CMD = 1, Addr = 12 : Bit  5:0 = CompTh2DAC
   //                    : Bit  7:6 = VTrimB
   addRegister(new Register("Config12", baseAddress_ + 0x0000100C, 1));
   
   addVariable(new Variable("CompTh2DAC", Variable::Configuration));
   getVariable("CompTh2DAC")->setDescription("Comparator Threshold 2 DAC");
   getVariable("CompTh2DAC")->setRange(0,0x3F);
   
   addVariable(new Variable("VTrimB", Variable::Configuration));
   getVariable("VTrimB")->setDescription("Pixel Threshold Trimming Current");
   getVariable("VTrimB")->setRange(0,0x3);

   // CMD = 1, Addr = 13 : Bit  1:0 = tc[1:0]
   //                    : Bit  4:2 = S2D[2:0]
   //                    : Bit  7:5 = S2D_DAC_BIAS[2:0]
   addRegister(new Register("Config13", baseAddress_ + 0x0000100D, 1));

   addVariable(new Variable("TC", Variable::Configuration));
   getVariable("TC")->setDescription("");
   getVariable("TC")->setRange(0,3);

   addVariable(new Variable("S2d", Variable::Configuration));
   getVariable("S2d")->setDescription("");
   getVariable("S2d")->setRange(0,7);

   addVariable(new Variable("S2dDacBias", Variable::Configuration));
   getVariable("S2dDacBias")->setDescription("");
   getVariable("S2dDacBias")->setRange(0,7);

   // CMD = 1, Addr = 14 : Bit  7:2 = TPS_DAC[5:0]
   addRegister(new Register("Config14", baseAddress_ + 0x0000100E, 1));

   addVariable(new Variable("TpsDac", Variable::Configuration));
   getVariable("TpsDac")->setDescription("");
   getVariable("TpsDac")->setRange(0,0x3F);

   // CMD = 1, Addr = 16 : Bit  0   = test_BE
   //                    : Bit  1   = DigR0_disable
   //                    : Bit  2   = delEXEC
   //                    : Bit  3   = delCCkreg
   //                    : Bit  4   = RORstEn
   //                    : Bit  5   = SLVDSbit
   //                    : Bit  6   = PixCountT
   //                    : Bit  7   = PixCountSel
   addRegister(new Register("Config16", baseAddress_ + 0x00001010, 1));

   addVariable(new Variable("TestBe", Variable::Configuration));
   getVariable("TestBe")->setDescription("");
   getVariable("TestBe")->setTrueFalse();

   addVariable(new Variable("DigRODis", Variable::Configuration));
   getVariable("DigRODis")->setDescription("");
   getVariable("DigRODis")->setTrueFalse();

   addVariable(new Variable("DelExec", Variable::Configuration));
   getVariable("DelExec")->setDescription("");
   getVariable("DelExec")->setTrueFalse();

   addVariable(new Variable("DelCckRef", Variable::Configuration));
   getVariable("DelCckRef")->setDescription("");
   getVariable("DelCckRef")->setTrueFalse();

   addVariable(new Variable("RORstEn", Variable::Configuration));
   getVariable("RORstEn")->setDescription("");
   getVariable("RORstEn")->setTrueFalse();
   
   addVariable(new Variable("SLVDSbit", Variable::Configuration));
   getVariable("SLVDSbit")->setDescription("Enable LVDS Termination");
   getVariable("SLVDSbit")->setTrueFalse();
   
   addVariable(new Variable("PixCountT", Variable::Configuration));
   getVariable("PixCountT")->setDescription("");
   getVariable("PixCountT")->setTrueFalse();
   
   addVariable(new Variable("PixCountSel", Variable::Configuration));
   getVariable("PixCountSel")->setDescription("");
   getVariable("PixCountSel")->setTrueFalse();

   // CMD = 1, Addr = 17 : Row start  address[9:0]
   addRegister(new Register("RowStartAddr", baseAddress_ + 0x00001011, 1));

   addVariable(new Variable("RowStartAddr", Variable::Configuration));
   getVariable("RowStartAddr")->setDescription("");
   getVariable("RowStartAddr")->setRange(0,0x2FF);

   // CMD = 1, Addr = 18 : Row stop  address[9:0]
   addRegister(new Register("RowStopAddr", baseAddress_ + 0x00001012, 1));

   addVariable(new Variable("RowStopAddr", Variable::Configuration));
   getVariable("RowStopAddr")->setDescription("");
   getVariable("RowStopAddr")->setRange(0,0x2FF);

   // CMD = 1, Addr = 19 : Col start  address[9:0]
   addRegister(new Register("ColStartAddr", baseAddress_ + 0x00001013, 1));

   addVariable(new Variable("ColStartAddr", Variable::Configuration));
   getVariable("ColStartAddr")->setDescription("");
   getVariable("ColStartAddr")->setRange(0,0x2FF);

   // CMD = 1, Addr = 20 : Col stop  address[9:0]
   addRegister(new Register("ColStopAddr", baseAddress_ + 0x00001014, 1));

   addVariable(new Variable("ColStopAddr", Variable::Configuration));
   getVariable("ColStopAddr")->setDescription("");
   getVariable("ColStopAddr")->setRange(0,0x2FF);
   
   // CMD = 1, Addr = 21 : Chip ID Read
   addRegister(new Register("ChipId", baseAddress_ + 0x00001015, 1));

   addVariable(new Variable("ChipId", Variable::Status));
   getVariable("ChipId")->setDescription("");



   // CMD = 6, Addr = 17 : Row counter[8:0]
   addRegister(new Register("RowCounter", baseAddress_ + 0x00006011, 1));

   addVariable(new Variable("RowCounter", Variable::Configuration));
   getVariable("RowCounter")->setDescription("");
   getVariable("RowCounter")->setRange(0,0x1FF);
   //Writes to the row counter are special.. require a prepare for readout first
   addCommand(new Command("WriteRowCounter"));
   getCommand("WriteRowCounter")->setDescription("Special command to write row counter");

   // CMD = 6, Addr = 19 : Bank select [3:0] & Col counter[6:0]
   addRegister(new Register("ColCounter", baseAddress_ + 0x00006013, 1));

   addVariable(new Variable("ColCounter", Variable::Configuration));
   getVariable("ColCounter")->setDescription("");
   getVariable("ColCounter")->setRange(0,0x7F);

   addVariable(new Variable("BankSelect", Variable::Configuration));
   getVariable("BankSelect")->setDescription("Active low bank select bit mask");
   getVariable("BankSelect")->setRange(0,0xF);

   // CMD = 2, Addr = X  : Write Row with data
   addRegister(new Register("WriteRowData", baseAddress_ + 0x00002000, 1));
   addCommand(new Command("WriteRowData"));
   getCommand("WriteRowData")->setDescription("Write PixelTest and PixelMask to selected row");

   // CMD = 3, Addr = X  : Write Column with data
   addRegister(new Register("WriteColData", baseAddress_ + 0x00003000, 1));

   // CMD = 4, Addr = X  : Write Matrix with data
   addRegister(new Register("WriteMatrixData", baseAddress_ + 0x00004000, 1));
   addCommand(new Command("WriteMatrixData"));
   getCommand("WriteMatrixData")->setDescription("Write PixelTest and PixelMask to all pixels");

   // CMD = 5, Addr = X  : Read/Write Pixel with data
   addRegister(new Register("WritePixelData", baseAddress_ + 0x00005000, 1));
   addCommand(new Command("WritePixelData"));
   getCommand("WritePixelData")->setDescription("Write PixelTest and PixelMask to current pixel only");
   // Dummy command to enable reading of pixels (register is same as WritePixelData)
   addCommand(new Command("ReadPixelData"));
   getCommand("ReadPixelData")->setDescription("Read PixelTest and PixelMask from current pixel only");

   // CMD = 7, Addr = X  : Prepare to write chip ID
   addRegister(new Register("PrepareWriteChipIdA", baseAddress_ + 0x00007000, 1));
   addRegister(new Register("PrepareWriteChipIdB", baseAddress_ + 0x00007015, 1));

   // CMD = 8, Addr = X  : Prepare for row/column/matrix configuration
   addRegister(new Register("PrepareMultiConfig", baseAddress_ + 0x00008000, 1));

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
CpixPAsic::~CpixPAsic ( ) { }

// Method to process a command
void CpixPAsic::command ( string name, string arg) {
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
void CpixPAsic::readStatus ( ) {
   REGISTER_LOCK

   // Read status register
   readRegister(getRegister("ChipId"));
   getVariable("ChipId")->setInt(getRegister("ChipId")->get());

   REGISTER_UNLOCK
}

// Method to read configuration registers and update variables
void CpixPAsic::readConfig ( ) {

   REGISTER_LOCK

   // CMD = 1, Addr = 1  : Bits 2:0 - Pulser monostable bits
   //                      Bit  7   - Pulser sync bit
   readRegister(getRegister("Config1"));
   getVariable("CompTh1DAC")->setInt(getRegister("Config1")->get(0,0x3F));
   getVariable("PulserSync")->setInt(getRegister("Config1")->get(7,0x1));

   // CMD = 1, Addr = 2  : Pll settings addr 2
   //                    : Bit 0    = PLL Reset (active high)
   //                    : Bit 3:1  = PLL Itune
   //                    : Bit 6:4  = PLL KVCO
   //                    : Bit 7    = PLL Filter 1
   readRegister(getRegister("Config2"));
   
   // CMD = 1, Addr = 15 : Pll settings addr 15
   //                    : Bit 1:0  = PLL Filter 1
   //                    : Bit 4:2  = PLL Filter 2
   //                    : Bit 7:5  = PLL Divider
   readRegister(getRegister("Config15"));
   
   getVariable("PllReset")->setInt(getRegister("Config2")->get(0,0x1));
   getVariable("PllItune")->setInt(getRegister("Config2")->get(1,0x7));
   getVariable("PllKVCO")->setInt(getRegister("Config2")->get(4,0x7));
   getVariable("PllFilter1")->setInt((getRegister("Config15")->get(0,0x3) << 2) | getRegister("Config2")->get(7,0x1));
   getVariable("PllFilter2")->setInt(getRegister("Config15")->get(2,0x7));
   getVariable("PllDivider")->setInt(getRegister("Config15")->get(5,0x7));

   // CMD = 1, Addr = 3  : Bits 9:0 = Pulser[9:0]
   //                    : Bit  10  = pbit
   //                    : Bit  11  = atest
   //                    : Bit  12  = test
   //                    : Bit  13  = sab_test
   //                    : Bit  14  = hrtest
   //                    : Bit  15  = PulserR
   readRegister(getRegister("Config3"));
   getVariable("Pulser")->setInt(getRegister("Config3")->get(0,0x3FF));
   getVariable("PBit")->setInt(getRegister("Config3")->get(10,0x1));
   getVariable("ATest")->setInt(getRegister("Config3")->get(11,0x1));
   getVariable("Test")->setInt(getRegister("Config3")->get(12,0x1));
   getVariable("SabTest")->setInt(getRegister("Config3")->get(13,0x1));
   getVariable("HrTest")->setInt(getRegister("Config3")->get(14,0x1));
   getVariable("PulserR")->setInt(getRegister("Config3")->get(15,0x1));

   // CMD = 1, Addr = 4  : Bits 3:0 = DM1[3:0]
   //                    : Bits 7:4 = DM2[3:0]
   readRegister(getRegister("Config4"));
   getVariable("DigMon1")->setInt(getRegister("Config4")->get(0,0xF));
   getVariable("DigMon2")->setInt(getRegister("Config4")->get(4,0xF));

   // CMD = 1, Addr = 5  : Bits 2:0 = Pulser DAC
   //                      Bits 5:3 = MonoStPulser
   readRegister(getRegister("Config5"));
   getVariable("PulserDac")->setInt(getRegister("Config5")->get(0,0x7));
   getVariable("MonoStPulser")->setInt(getRegister("Config5")->get(3,0x7));

   // CMD = 1, Addr = 6  : Bit  0   = DM1en
   //                    : Bit  1   = DM2en
   //                    : Bit  4:2 = EmphBitDel
   //                    : Bit  7:5 = EmphBitCur
   readRegister(getRegister("Config6"));
   getVariable("Dm1En")->setInt(getRegister("Config6")->get(0,0x1));
   getVariable("Dm2En")->setInt(getRegister("Config6")->get(1,0x1));
   getVariable("EmphBitDel")->setInt(getRegister("Config6")->get(2,0x7));
   getVariable("EmphBitCur")->setInt(getRegister("Config6")->get(5,0x7));

   // CMD = 1, Addr = 7  : Bit  5:0 = VREF[5:0]
   //                    : Bit  7:6 = VrefLow[1:0]
   readRegister(getRegister("Config7"));
   getVariable("VRef")->setInt(getRegister("Config7")->get(0,0x3F));
   getVariable("VrefLow")->setInt(getRegister("Config7")->get(6,0x3));

   // CMD = 1, Addr = 8  : Bit  4:1 = TPS_MUX[3:0]
   //                    : Bit  7:5 = TO_Monost[2:0]
   readRegister(getRegister("Config8"));
   getVariable("TpsMux")->setInt(getRegister("Config8")->get(1,0xf));
   getVariable("RoMonost")->setInt(getRegister("Config8")->get(5,0x7));

   // CMD = 1, Addr = 9  : Bit  3:0 = TpsGr
   //                    : Bit  5   = Couc
   //                    : Bit  6   = Ckc
   //                    : Bit  7   = Mod
   readRegister(getRegister("Config9"));
   getVariable("TpsGr")->setInt(getRegister("Config9")->get(0,0xf));
   getVariable("Couc")->setInt(getRegister("Config9")->get(5,0x1));
   getVariable("Ckc")->setInt(getRegister("Config9")->get(6,0x1));
   getVariable("Mod")->setInt(getRegister("Config9")->get(7,0x1));

   // CMD = 1, Addr = 10 : Bit  0   = PP_OCB_S2D
   //                    : Bit  3:1 = OCB[2:0]
   //                    : Bit  6:4 = Monost[2:0]
   //                    : Bit  7   = fastpp_enable
   readRegister(getRegister("Config10"));
   getVariable("PpOcbS2d")->setInt(getRegister("Config10")->get(0,0x1));
   getVariable("Ocb")->setInt(getRegister("Config10")->get(1,0x7));
   getVariable("Monost")->setInt(getRegister("Config10")->get(4,0x7));
   getVariable("FastppEnable")->setInt(getRegister("Config10")->get(7,0x1));

   // CMD = 1, Addr = 11 : Bit  2:0 = Preamp[2:0]
   //                    : Bit  5:3 = Pixel_FB[2:0]
   //                    : Bit  7:6 = Vld1_b[1:0]
   readRegister(getRegister("Config11"));
   getVariable("Preamp")->setInt(getRegister("Config11")->get(0,0x7));
   getVariable("PixelFb")->setInt(getRegister("Config11")->get(3,0x7));
   getVariable("Vld1_b")->setInt(getRegister("Config11")->get(6,0x3));

   // CMD = 1, Addr = 12 : Bit  5:0 = CompTh2DAC
   //                    : Bit  7:6 = VTrimB
   readRegister(getRegister("Config12"));
   getVariable("CompTh2DAC")->setInt(getRegister("Config12")->get(0,0x3F));
   getVariable("VTrimB")->setInt(getRegister("Config12")->get(6,0x3));

   // CMD = 1, Addr = 13 : Bit  1:0 = tc[1:0]
   //                    : Bit  4:2 = S2D[2:0]
   //                    : Bit  7:5 = S2D_DAC_BIAS[2:0]
   readRegister(getRegister("Config13"));
   getVariable("TC")->setInt(getRegister("Config13")->get(0,0x3));
   getVariable("S2d")->setInt(getRegister("Config13")->get(2,0x7));
   getVariable("S2dDacBias")->setInt(getRegister("Config13")->get(5,0x7));

   // CMD = 1, Addr = 14 : Bit  7:2 = TPS_DAC[5:0]
   readRegister(getRegister("Config14"));
   getVariable("TpsDac")->setInt(getRegister("Config14")->get(2,0x3F));

   // CMD = 1, Addr = 16 : Bit  0   = test_BE
   //                    : Bit  1   = DigR0_disable
   //                    : Bit  2   = delEXEC
   //                    : Bit  3   = delCCkreg
   //                    : Bit  4   = RORstEn
   //                    : Bit  5   = SLVDSbit
   //                    : Bit  6   = PixCountT
   //                    : Bit  7   = PixCountSel
   readRegister(getRegister("Config16"));
   getVariable("TestBe")->setInt(getRegister("Config16")->get(0,0x1));
   getVariable("DigRODis")->setInt(getRegister("Config16")->get(1,0x1));
   getVariable("DelExec")->setInt(getRegister("Config16")->get(2,0x1));
   getVariable("DelCckRef")->setInt(getRegister("Config16")->get(3,0x1));
   getVariable("RORstEn")->setInt(getRegister("Config16")->get(4,0x1));
   getVariable("SLVDSbit")->setInt(getRegister("Config16")->get(5,0x1));
   getVariable("PixCountT")->setInt(getRegister("Config16")->get(6,0x1));
   getVariable("PixCountSel")->setInt(getRegister("Config16")->get(7,0x1));

   // CMD = 1, Addr = 18 : Row stop  address[8:0]
   readRegister(getRegister("RowStopAddr"));
   getVariable("RowStopAddr")->setInt(getRegister("RowStopAddr")->get(0,0x1FF));

   // CMD = 1, Addr = 20 : Col stop  address[6:0]
   readRegister(getRegister("ColStopAddr"));
   getVariable("ColStopAddr")->setInt(getRegister("ColStopAddr")->get(0,0x7F));

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
void CpixPAsic::writeConfig ( bool force ) {

   REGISTER_LOCK

   // CMD = 1, Addr = 1  : Bits 2:0 - Pulser monostable bits
   //                      Bit  7   - Pulser sync bit
   getRegister("Config1")->set(getVariable("CompTh1DAC")->getInt(),0,0x3F);
   getRegister("Config1")->set(getVariable("PulserSync")->getInt(),7,0x1);
   writeRegister(getRegister("Config1"),force,true);

   // CMD = 1, Addr = 2  : Pll settings addr 2
   //                    : Bit 0    = PLL Reset (active high)
   //                    : Bit 3:1  = PLL Itune
   //                    : Bit 6:4  = PLL KVCO
   //                    : Bit 7    = PLL Filter 1
   getRegister("Config2")->set(getVariable("PllReset")->getInt(),0,0x1);
   getRegister("Config2")->set(getVariable("PllItune")->getInt(),1,0x7);
   getRegister("Config2")->set(getVariable("PllKVCO")->getInt(),4,0x7);
   getRegister("Config2")->set(getVariable("PllFilter1")->getInt(),7,0x1);
   writeRegister(getRegister("Config2"),force,true);
   
   // CMD = 1, Addr = 15 : Pll settings addr 15
   //                    : Bit 1:0  = PLL Filter 1
   //                    : Bit 4:2  = PLL Filter 2
   //                    : Bit 7:5  = PLL Divider
   getRegister("Config15")->set(getVariable("PllFilter1")->getInt(),0,0x3);
   getRegister("Config15")->set(getVariable("PllFilter2")->getInt(),2,0x7);
   getRegister("Config15")->set(getVariable("PllDivider")->getInt(),5,0x7);
   writeRegister(getRegister("Config15"),force,true);

   // CMD = 1, Addr = 3  : Bits 9:0 = Pulser[9:0]
   //                    : Bit  10  = pbit
   //                    : Bit  11  = atest
   //                    : Bit  12  = test
   //                    : Bit  13  = sab_test
   //                    : Bit  14  = hrtest
   //                    : Bit  15  = PulserR
   getRegister("Config3")->set(getVariable("Pulser")->getInt(),0,0x3FF);
   getRegister("Config3")->set(getVariable("PBit")->getInt(),10,0x1);
   getRegister("Config3")->set(getVariable("ATest")->getInt(),11,0x1);
   getRegister("Config3")->set(getVariable("Test")->getInt(),12,0x1);
   getRegister("Config3")->set(getVariable("SabTest")->getInt(),13,0x1);
   getRegister("Config3")->set(getVariable("HrTest")->getInt(),14,0x1);
   getRegister("Config3")->set(getVariable("PulserR")->getInt(),15,0x1);
   writeRegister(getRegister("Config3"),force,true);

   // CMD = 1, Addr = 4  : Bits 3:0 = DM1[3:0]
   //                    : Bits 7:4 = DM2[3:0]
   getRegister("Config4")->set(getVariable("DigMon1")->getInt(),0,0xF);
   getRegister("Config4")->set(getVariable("DigMon2")->getInt(),4,0xF);
   writeRegister(getRegister("Config4"),force,true);

   // CMD = 1, Addr = 5  : Bits 2:0 = Pulser DAC
   //                      Bits 5:3 = MonoStPulser
   getRegister("Config5")->set(getVariable("PulserDac")->getInt(),0,0x7);
   getRegister("Config5")->set(getVariable("MonoStPulser")->getInt(),3,0x7);
   writeRegister(getRegister("Config5"),force,true);

   // CMD = 1, Addr = 6  : Bit  0   = DM1en
   //                    : Bit  1   = DM2en
   //                    : Bit  4   = SLVDSbit
   getRegister("Config6")->set(getVariable("Dm1En")->getInt(),0,0x1);
   getRegister("Config6")->set(getVariable("Dm2En")->getInt(),1,0x1);
   getRegister("Config6")->set(getVariable("EmphBitDel")->getInt(),2,0x7);
   getRegister("Config6")->set(getVariable("EmphBitCur")->getInt(),5,0x7);
   writeRegister(getRegister("Config6"),force,true);

   // CMD = 1, Addr = 7  : Bit  5:0 = VREF[5:0]
   //                    : Bit  7:6 = VrefLow[1:0]
   getRegister("Config7")->set(getVariable("VRef")->getInt(),0,0x3F);
   getRegister("Config7")->set(getVariable("VrefLow")->getInt(),6,0x3);
   writeRegister(getRegister("Config7"),force,true);

   // CMD = 1, Addr = 8  : Bit  4:1 = TPS_MUX[3:0]
   //                    : Bit  7:5 = TO_Monost[2:0]
   getRegister("Config8")->set(getVariable("TpsMux")->getInt(),1,0xf);
   getRegister("Config8")->set(getVariable("RoMonost")->getInt(),5,0x7);
   writeRegister(getRegister("Config8"),force,true);

   // CMD = 1, Addr = 9  : Bit  3:0 = TpsGr
   //                    : Bit  5   = Couc
   //                    : Bit  6   = Ckc
   //                    : Bit  7   = Mod
   getRegister("Config9")->set(getVariable("TpsGr")->getInt(),0,0xf);
   getRegister("Config9")->set(getVariable("Couc")->getInt(),5,0x1);
   getRegister("Config9")->set(getVariable("Ckc")->getInt(),6,0x1);
   getRegister("Config9")->set(getVariable("Mod")->getInt(),7,0x1);
   writeRegister(getRegister("Config9"),force,true);

   // CMD = 1, Addr = 10 : Bit  0   = PP_OCB_S2D
   //                    : Bit  3:1 = OCB[2:0]
   //                    : Bit  6:4 = Monost[2:0]
   //                    : Bit  7   = fastpp_enable
   getRegister("Config10")->set(getVariable("PpOcbS2d")->getInt(),0,0x1);
   getRegister("Config10")->set(getVariable("Ocb")->getInt(),1,0x7);
   getRegister("Config10")->set(getVariable("Monost")->getInt(),4,0x7);
   getRegister("Config10")->set(getVariable("FastppEnable")->getInt(),7,0x1);
   writeRegister(getRegister("Config10"),force,true);

   // CMD = 1, Addr = 11 : Bit  2:0 = Preamp[2:0]
   //                    : Bit  5:3 = Pixel_FB[2:0]
   //                    : Bit  7:6 = Vld1_b[1:0]
   getRegister("Config11")->set(getVariable("Preamp")->getInt(),0,0x7);
   getRegister("Config11")->set(getVariable("PixelFb")->getInt(),3,0x7);
   getRegister("Config11")->set(getVariable("Vld1_b")->getInt(),6,0x3);
   writeRegister(getRegister("Config11"),force,true);

   // CMD = 1, Addr = 12 : Bit  5:0 = CompTh2DAC
   //                    : Bit  7:6 = VTrimB
   getRegister("Config12")->set(getVariable("CompTh2DAC")->getInt(),0,0x3F);
   getRegister("Config12")->set(getVariable("VTrimB")->getInt(),6,0x3);
   writeRegister(getRegister("Config12"),force,true);

   // CMD = 1, Addr = 13 : Bit  1:0 = tc[1:0]
   //                    : Bit  4:2 = S2D[2:0]
   //                    : Bit  7:5 = S2D_DAC_BIAS[2:0]
   getRegister("Config13")->set(getVariable("TC")->getInt(),0,0x3);
   getRegister("Config13")->set(getVariable("S2d")->getInt(),2,0x7);
   getRegister("Config13")->set(getVariable("S2dDacBias")->getInt(),5,0x7);
   writeRegister(getRegister("Config13"),force,true);

   // CMD = 1, Addr = 14 : Bit  7:2 = TPS_DAC[5:0]
   getRegister("Config14")->set(getVariable("TpsDac")->getInt(),2,0x3F);
   writeRegister(getRegister("Config14"),force,true);

   // CMD = 1, Addr = 16 : Bit  0   = test_BE
   //                    : Bit  1   = DigR0_disable
   //                    : Bit  2   = delEXEC
   //                    : Bit  3   = delCCkreg
   //                    : Bit  4   = RORstEn
   //                    : Bit  5   = SLVDSbit
   //                    : Bit  6   = PixCountT
   //                    : Bit  7   = PixCountSel
   getRegister("Config16")->set(getVariable("TestBe")->getInt(),0,0x1);
   getRegister("Config16")->set(getVariable("DigRODis")->getInt(),1,0x1);
   getRegister("Config16")->set(getVariable("DelExec")->getInt(),2,0x1);
   getRegister("Config16")->set(getVariable("DelCckRef")->getInt(),3,0x1);
   getRegister("Config16")->set(getVariable("RORstEn")->getInt(),4,0x1);
   getRegister("Config16")->set(getVariable("SLVDSbit")->getInt(),5,0x1);
   getRegister("Config16")->set(getVariable("PixCountT")->getInt(),6,0x1);
   getRegister("Config16")->set(getVariable("PixCountSel")->getInt(),7,0x1);
   writeRegister(getRegister("Config16"),force,true);

   // CMD = 1, Addr = 18 : Row stop  address[8:0]
   getRegister("RowStopAddr")->set(getVariable("RowStopAddr")->getInt(),0,0x1FF);
   writeRegister(getRegister("RowStopAddr"),force,true);

   // CMD = 1, Addr = 20 : Col stop  address[6:0]
   getRegister("ColStopAddr")->set(getVariable("ColStopAddr")->getInt(),0,0x7F);
   writeRegister(getRegister("ColStopAddr"),force,true);


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
void CpixPAsic::verifyConfig ( ) {

   REGISTER_LOCK

   verifyRegister(getRegister("Config1"),false,0xBF);
   verifyRegister(getRegister("Config2"),false,0xFF);
   verifyRegister(getRegister("Config3"),false,0xFFFF);
   verifyRegister(getRegister("Config4"),false,0xFF);
   verifyRegister(getRegister("Config5"),false,0x3F);
   verifyRegister(getRegister("Config6"),false,0xFF);
   verifyRegister(getRegister("Config7"),false,0xFF);
   verifyRegister(getRegister("Config8"),false,0xFE);
   verifyRegister(getRegister("Config9"),false,0xEF);
   verifyRegister(getRegister("Config10"),false,0xFF);
   verifyRegister(getRegister("Config11"),false,0xFF);
   verifyRegister(getRegister("Config12"),false,0xFF);
   verifyRegister(getRegister("Config13"),false,0xFF);
   verifyRegister(getRegister("Config14"),false,0xFC);
   verifyRegister(getRegister("Config15"),false,0xFF);
   verifyRegister(getRegister("Config16"),false,0xFF);
   verifyRegister(getRegister("RowStopAddr"),false,0xFF);
   verifyRegister(getRegister("ColStopAddr"),false,0xFF);
//   verifyRegister(getRegister("RowStartAddr"),false,0xFF);
//   verifyRegister(getRegister("ColStartAddr"),false,0xFF);

   REGISTER_UNLOCK
}

